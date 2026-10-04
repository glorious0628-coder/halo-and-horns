"""Read-only quality evidence for the approved Sharp D Tripo source.

Inspect: py tools/approved_avatar_quality_check.py --model generation.glb
         [--rig rig.glb] --output build/sharp_d_quality_20261004/new-report.json
Render: Blender --background --factory-startup --python this-file --
        --blender-render source.glb --output build/sharp_d_quality_20261004/new-views

No network, Studio, paid calls, production writes, geometry/UV/PNG edits, or
texture downsampling. Embedded image extraction is a byte-for-byte copy. CG is
an offline render of an untouched GLB and never constitutes Native approval.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
from pathlib import Path
import struct
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
ALLOWED = (ROOT / "build/sharp_d_quality_20261004").resolve()
REFERENCE = ROOT / "art/out/APose_HaloArcherM_Sharp_D.png"
REFERENCE_SHA = "649ce86f007b2762e70bb1fc8d494351520de4f024d1a876c9225b94e6160b0a"
sys.path.insert(0, str(ROOT / "tools/costume_r15"))
from glb_io import image_bytes, read_glb, view_bytes


def sha_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha(path):
    return sha_bytes(Path(path).read_bytes())


def new_output(path):
    path = Path(path).resolve()
    path.relative_to(ALLOWED)
    if path.exists():
        raise ValueError("Refuse to overwrite existing quality evidence: " + str(path))
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def decode(gltf, binary, index):
    """Read glTF component data including normalized skin weights and MAT4."""
    import numpy as np
    row = gltf["accessors"][index]
    if row.get("sparse") or "bufferView" not in row:
        raise ValueError("Sparse or implicit accessor requires explicit independent QA")
    types = {5120: ("i1", 127), 5121: ("u1", 255), 5122: ("<i2", 32767),
             5123: ("<u2", 65535), 5125: ("<u4", 4294967295), 5126: ("<f4", None)}
    widths = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4,
              "MAT2": 4, "MAT3": 9, "MAT4": 16}
    dtype, maximum = types[row["componentType"]]
    width = widths[row["type"]]
    view, payload = view_bytes(gltf, binary, row["bufferView"])
    itemsize = np.dtype(dtype).itemsize
    stride = view.get("byteStride", itemsize * width)
    start, count = row.get("byteOffset", 0), row["count"]
    if stride < itemsize * width or start < 0 or count < 0:
        raise ValueError("Invalid accessor size")
    if count and start + (count - 1) * stride + itemsize * width > len(payload):
        raise ValueError("Accessor exceeds buffer view")
    result = np.ndarray((count, width), dtype=dtype, buffer=payload,
                        offset=start, strides=(stride, itemsize)).copy()
    if row.get("normalized"):
        if maximum is None:
            raise ValueError("Float accessor cannot be normalized")
        result = result.astype(np.float64) / maximum
        if row["componentType"] in (5120, 5122):
            result = np.maximum(result, -1)
    return result


def triangles(gltf, binary, primitive):
    import numpy as np
    count = gltf["accessors"][primitive["attributes"]["POSITION"]]["count"]
    indices = (decode(gltf, binary, primitive["indices"]).reshape(-1).astype(np.int64)
               if "indices" in primitive else np.arange(count, dtype=np.int64))
    if len(indices) and (indices.min() < 0 or indices.max() >= count):
        raise ValueError("Triangle indices exceed actual vertex count")
    mode = primitive.get("mode", 4)
    if mode == 4:
        if len(indices) % 3:
            raise ValueError("Triangle primitive has incomplete face")
        return indices.reshape(-1, 3)
    if mode == 5:
        rows = [(int(indices[i]), int(indices[i + 1]), int(indices[i + 2]))
                if i % 2 == 0 else (int(indices[i + 1]), int(indices[i]), int(indices[i + 2]))
                for i in range(max(0, len(indices) - 2))]
    elif mode == 6:
        rows = [(int(indices[0]), int(indices[i]), int(indices[i + 1]))
                for i in range(1, len(indices) - 1)]
    else:
        raise ValueError("Non-triangle mesh primitive requires separate QA")
    return np.asarray(rows, dtype=np.int64).reshape(-1, 3)


def material_slots(gltf, row):
    pbr = row.get("pbrMetallicRoughness", {})
    entries = {"baseColor": pbr.get("baseColorTexture"),
               "metallicRoughness": pbr.get("metallicRoughnessTexture"),
               "normal": row.get("normalTexture"), "occlusion": row.get("occlusionTexture"),
               "emissive": row.get("emissiveTexture")}
    slots = {}
    for label, entry in entries.items():
        if entry is not None:
            texture = gltf["textures"][entry["index"]]
            if "source" not in texture:
                raise ValueError("Texture extension-only source needs separate QA")
            slots[label] = {"texture": entry["index"], "image": texture["source"],
                            "texcoord": entry.get("texCoord", 0),
                            "sampler": texture.get("sampler"),
                            "texture_transform": entry.get("extensions", {}).get("KHR_texture_transform"),
                            "normal_scale": entry.get("scale", 1) if label == "normal" else None,
                            "occlusion_strength": entry.get("strength", 1) if label == "occlusion" else None}
    return slots


def inspect(path, extraction=None):
    import numpy as np
    from PIL import Image
    path = Path(path).resolve()
    gltf, binary, original = read_glb(path)
    images = []
    if extraction:
        extraction = new_output(extraction)
        extraction.mkdir()
    for index, row in enumerate(gltf.get("images", [])):
        payload = image_bytes(gltf, binary, row)
        with Image.open(io.BytesIO(payload)) as im:
            # Hash unchanged decoded samples in strips. Four 8K PBR maps must
            # never become simultaneous float64 arrays (several GB).
            pixel_digest = hashlib.sha256()
            for top in range(0, im.height, 256):
                strip = im.crop((0, top, im.width, min(top + 256, im.height)))
                pixel_digest.update(strip.convert("RGBA").tobytes())
            image = {"index": index, "name": row.get("name"), "mimeType": row.get("mimeType"),
                     "dimensions": list(im.size), "mode": im.mode, "encoded_bytes": len(payload),
                     "encoded_sha256": sha_bytes(payload), "rgba_pixels_sha256": pixel_digest.hexdigest(),
                     "downsampled_by_this_check": False}
            if extraction:
                ext = {"image/png": ".png", "image/jpeg": ".jpg", "image/webp": ".webp"}.get(row.get("mimeType"), ".image")
                target = extraction / ("image_" + str(index) + ext)
                target.write_bytes(payload)
                image["exact_extracted_path"] = target.as_posix()
                image["extraction_bytes_exact"] = sha(target) == image["encoded_sha256"]
        images.append(image)
    material_rows = []
    for index, material in enumerate(gltf.get("materials", [])):
        slots = material_slots(gltf, material)
        for slot in slots.values():
            slot["actual_image_dimensions"] = images[slot["image"]]["dimensions"]
            slot["actual_image_encoded_sha256"] = images[slot["image"]]["encoded_sha256"]
            slot["actual_image_rgba_pixels_sha256"] = images[slot["image"]]["rgba_pixels_sha256"]
        material_rows.append({"index": index, "name": material.get("name"), "slots": slots,
                              "pbr_json": material.get("pbrMetallicRoughness", {}),
                              "alphaMode": material.get("alphaMode", "OPAQUE"),
                              "doubleSided": material.get("doubleSided", False)})
    primitive_rows, count_per_mesh = [], {}
    for mesh_index, mesh in enumerate(gltf.get("meshes", [])):
        count_per_mesh[mesh_index] = 0
        for primitive_index, primitive in enumerate(mesh["primitives"]):
            attributes = primitive["attributes"]
            pos = decode(gltf, binary, attributes["POSITION"])
            faces = triangles(gltf, binary, primitive)
            count_per_mesh[mesh_index] += len(faces)
            attribute_reports = {}
            for semantic, accessor in attributes.items():
                values = decode(gltf, binary, accessor)
                attribute_reports[semantic] = {"accessor": accessor, "count": len(values),
                                                "components": values.shape[1],
                                                "finite": bool(np.isfinite(values).all()),
                                                "decoded_float64_sha256": sha_bytes(values.astype("<f8").tobytes())}
            row = {"mesh": mesh_index, "mesh_name": mesh.get("name"), "primitive": primitive_index,
                   "material": primitive.get("material"), "actual_triangles": len(faces),
                   "actual_vertices": len(pos), "attributes": attribute_reports,
                   "indices_decoded_sha256": sha_bytes(faces.astype("<i8").tobytes()),
                   "local_position_bounds": [pos.min(axis=0).tolist(), pos.max(axis=0).tolist()]}
            if "WEIGHTS_0" in attributes:
                weight = decode(gltf, binary, attributes["WEIGHTS_0"])
                joints = decode(gltf, binary, attributes["JOINTS_0"]) if "JOINTS_0" in attributes else None
                sums = weight.sum(axis=1)
                row["skin_weight_check"] = {"finite": bool(np.isfinite(weight).all()),
                                            "negative_weights": int((weight < 0).sum()),
                                            "zero_weight_vertices": int((sums <= 1e-8).sum()),
                                            "maximum_sum_error_from_one": float(np.max(np.abs(sums - 1))),
                                            "used_joint_indices": sorted(map(int, np.unique(joints[weight > 0]))) if joints is not None else None}
            primitive_rows.append(row)
    skin_rows = []
    for index, skin in enumerate(gltf.get("skins", [])):
        joints = skin.get("joints", [])
        names = [gltf["nodes"][node].get("name", "node_" + str(node)) for node in joints]
        inverse = decode(gltf, binary, skin["inverseBindMatrices"]) if "inverseBindMatrices" in skin else None
        skin_rows.append({"index": index, "name": skin.get("name"), "joint_count": len(joints),
                          "joint_nodes": joints, "joint_names": names,
                          "unique_joint_names": len(set(names)) == len(names),
                          "inverse_bind_matrix_count": gltf["accessors"][skin["inverseBindMatrices"]]["count"] if "inverseBindMatrices" in skin else None,
                          "inverse_bind_matrices_finite": bool(np.isfinite(inverse).all()) if inverse is not None else None,
                          "inverse_bind_count_matches_joints": len(inverse) == len(joints) if inverse is not None else None,
                          "head_joints": [name for name in names if "head" in name.lower()],
                          "hand_joints": [name for name in names if "hand" in name.lower()]})
    node_rows = []
    for node_index, node in enumerate(gltf.get("nodes", [])):
        if "mesh" not in node:
            continue
        entry = {"node": node_index, "name": node.get("name"), "mesh": node["mesh"],
                 "skin": node.get("skin"), "actual_instance_triangles": count_per_mesh[node["mesh"]]}
        if "skin" in node:
            joint_count = skin_rows[node["skin"]]["joint_count"]
            checks = [row.get("skin_weight_check") for row in primitive_rows if row["mesh"] == node["mesh"]]
            entry["all_primitives_have_skin_weights"] = all(check is not None for check in checks)
            entry["used_joint_indices_in_skin_range"] = all(check is not None and check["used_joint_indices"] is not None and all(0 <= x < joint_count for x in check["used_joint_indices"]) for check in checks)
        node_rows.append(entry)
    result = {"path": path.as_posix(), "sha256": sha_bytes(original), "bytes": len(original),
              "glb_asset": gltf.get("asset"), "extensionsUsed": gltf.get("extensionsUsed", []),
              "extensionsRequired": gltf.get("extensionsRequired", []), "images": images,
              "materials": material_rows, "samplers": gltf.get("samplers", []),
              "primitive_rows": primitive_rows, "mesh_nodes": node_rows, "skins": skin_rows,
              "actual_unique_mesh_triangles": sum(count_per_mesh.values()),
              "actual_instanced_triangles": sum(r["actual_instance_triangles"] for r in node_rows),
              "animation_count": len(gltf.get("animations", [])),
              "source_sha256_unchanged_after_inspection": sha(path) == sha_bytes(original)}
    if not result["source_sha256_unchanged_after_inspection"]:
        raise AssertionError("Source changed during inspection")
    return result


def compare_rig(source, rig):
    source_slots = [(m["index"], key, value) for m in source["materials"] for key, value in m["slots"].items()]
    rig_slots = [(m["index"], key, value) for m in rig["materials"] for key, value in m["slots"].items()]
    matches = []
    for material, key, value in source_slots:
        candidates = [(idx, slot) for idx, role, slot in rig_slots if role == key]
        exact_pixels = [(idx, slot) for idx, slot in candidates if slot["actual_image_rgba_pixels_sha256"] == value["actual_image_rgba_pixels_sha256"]]
        matches.append({"source_material": material, "role": key,
                        "source_dimensions": value["actual_image_dimensions"],
                        "source_encoded_sha256": value["actual_image_encoded_sha256"],
                        "matching_rig_material_indices": [idx for idx, _ in exact_pixels],
                        "pixel_exact_match_present": bool(exact_pixels),
                        "encoded_byte_exact_match_present": any(slot["actual_image_encoded_sha256"] == value["actual_image_encoded_sha256"] for _, slot in exact_pixels),
                        "matching_resolution_preserved": any(slot["actual_image_dimensions"] == value["actual_image_dimensions"] for _, slot in exact_pixels)})
    return {"source_sha256": source["sha256"], "rig_sha256": rig["sha256"],
            "source_triangles": source["actual_instanced_triangles"], "rig_triangles": rig["actual_instanced_triangles"],
            "triangle_count_preserved": source["actual_instanced_triangles"] == rig["actual_instanced_triangles"],
            "texture_role_matches": matches,
            "all_source_texture_pixels_exact_in_rig": bool(matches) and all(r["pixel_exact_match_present"] for r in matches),
            "all_source_texture_resolutions_preserved_in_rig": bool(matches) and all(r["matching_resolution_preserved"] for r in matches),
            "geometry_exact_claimed": False,
            "note": "Rigging can transform or reorganize topology. Counts alone do not prove geometry, UV, weights, or visual equivalence."}


def run_inspection(args):
    from PIL import Image
    output = new_output(args.output)
    if sha(REFERENCE) != REFERENCE_SHA:
        raise ValueError("Approved Sharp D PNG byte-exact SHA gate failed")
    models = [inspect(args.model, output.parent / (output.stem + "_generation_images") if args.extract else None)]
    if args.rig:
        models.append(inspect(args.rig, output.parent / (output.stem + "_rig_images") if args.extract else None))
    report = {"schema": 1, "source_png": {"path": REFERENCE.as_posix(), "sha256": REFERENCE_SHA,
                                            "dimensions": list(Image.open(REFERENCE).size), "expected_sha_gate_pass": True},
              "models": models, "generation_rig_comparison": compare_rig(*models) if len(models) == 2 else None,
              "actual_face_limit": args.face_limit,
              "generation_triangle_budget_pass": models[0]["actual_instanced_triangles"] <= args.face_limit,
              "actual_basecolor_8192_or_higher": all(min(slot["actual_image_dimensions"]) >= 8192 for m in models[0]["materials"] for role, slot in m["slots"].items() if role == "baseColor") and any("baseColor" in m["slots"] for m in models[0]["materials"]),
              "approval": {"source_design_approved": True, "final_mesh_visually_reviewed": False,
                            "native_qa_passed": False, "roblox_uploaded": False, "production_changed": False},
              "preservation": {"source_png_bytes_unchanged": sha(REFERENCE) == REFERENCE_SHA,
                               "source_models_unchanged": all(m["source_sha256_unchanged_after_inspection"] for m in models),
                               "local_texture_downsamples": 0, "local_geometry_uv_edits": 0,
                               "paid_api_calls": 0, "studio_calls": 0, "uploads": 0},
              "limitations": ["Extreme/8K request parameters are not substituted for actual embedded image dimensions.",
                              "A large image does not prove clean eye detail; direct frontal CG visual review is required.",
                              "Offline GLB checks do not establish Roblox effective download resolution or animation quality.",
                              "This report reads local files only; paid step/model/rigger metadata must be verified against CLI task records by the parent."]}
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"report": output.as_posix(), "triangles": [m["actual_instanced_triangles"] for m in models],
                      "image_dimensions": [[i["dimensions"] for i in m["images"]] for m in models],
                      "skin_joint_counts": [[s["joint_count"] for s in m["skins"]] for m in models],
                      "source_unchanged": report["preservation"]["source_models_unchanged"]}))


def run_render(args):
    """Render original baseColor in Blender; no image or mesh export/rebake."""
    import bpy
    from mathutils import Matrix, Vector
    output = new_output(args.output)
    source = Path(args.blender_render).resolve()
    original_sha = sha(source)
    source_gltf = read_glb(source)[0]
    original_mesh_node_names = {node["name"] for node in source_gltf.get("nodes", [])
                                if "mesh" in node and "name" in node}
    if sha(REFERENCE) != REFERENCE_SHA:
        raise ValueError("Approved Sharp D PNG SHA gate failed")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    bpy.context.view_layer.update()
    # Workbench uses the active image node. Explicitly select the connected
    # baseColor image in the temporary imported scene, so a normal/RM map cannot
    # accidentally be shown as the character's face. No source is exported.
    active_basecolors = []
    for material in bpy.data.materials:
        if not material.use_nodes:
            continue
        principled = next((node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED"), None)
        if principled is None:
            continue
        pending = [link.from_node for link in principled.inputs["Base Color"].links]
        seen, texture = set(), None
        while pending:
            node = pending.pop()
            if node.as_pointer() in seen:
                continue
            seen.add(node.as_pointer())
            if node.type == "TEX_IMAGE" and node.image:
                texture = node
                break
            pending.extend(link.from_node for socket in node.inputs for link in socket.links)
        if texture is not None:
            material.node_tree.nodes.active = texture
            active_basecolors.append({"material": material.name, "image": texture.image.name,
                                      "blender_loaded_dimensions": list(texture.image.size)})
    points = []
    depsgraph = bpy.context.evaluated_depsgraph_get()
    rendered_mesh_objects = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or obj.hide_render or (original_mesh_node_names and obj.name not in original_mesh_node_names):
            continue
        rendered_mesh_objects.append(obj.name)
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        used_vertices = {index for face in mesh.polygons for index in face.vertices}
        points.extend(evaluated.matrix_world @ mesh.vertices[index].co for index in used_vertices)
        evaluated.to_mesh_clear()
    if not points:
        raise ValueError("No rendered vertices")
    low = Vector([min(p[i] for p in points) for i in range(3)])
    high = Vector([max(p[i] for p in points) for i in range(3)])
    center = (low + high) / 2
    # Workbench texture mode samples the unchanged embedded baseColor. No PNG,
    # UV, material or GLB is rewritten. PBR parameters remain in inspection JSON.
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.background_type = "VIEWPORT"
    scene.display.shading.background_color = (.82, .82, .82)
    scene.display.shading.show_shadows = False
    scene.display.shading.show_cavity = False
    scene.display.shading.show_specular_highlight = False
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    camdata = bpy.data.cameras.new("ReadOnlyQualityCamera")
    camdata.type = "ORTHO"
    cam = bpy.data.objects.new("ReadOnlyQualityCamera", camdata)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    output.mkdir()
    records = []
    for label, backward in [("minus_y", Vector((0, -1, 0))), ("plus_y", Vector((0, 1, 0))),
                            ("minus_x", Vector((-1, 0, 0))), ("plus_x", Vector((1, 0, 0)))]:
        up = Vector((0, 0, 1))
        right = up.cross(backward).normalized()
        rotation = Matrix((right, up, backward)).transposed().to_euler()
        for region, fraction, width, height in [("full", 0, 1024, 1280), ("face", .60, 1536, 1536)]:
            target = center.copy()
            target.z = low.z + (fraction + 1) * (high.z - low.z) / 2
            visible_points = [p for p in points if p.z >= low.z + fraction * (high.z - low.z)]
            object_width = max(right.dot(p - target) for p in visible_points) - min(right.dot(p - target) for p in visible_points)
            object_height = (1 - fraction) * (high.z - low.z)
            camdata.ortho_scale = max(object_height, object_width / (width / height)) * 1.10
            cam.location = target + backward * max((high - low).length * 3, 10)
            cam.rotation_euler = rotation
            scene.render.resolution_x, scene.render.resolution_y = width, height
            image = output / (label + "_" + region + ".png")
            scene.render.filepath = str(image)
            bpy.ops.render.render(write_still=True)
            records.append({"view": label, "region": region, "render": image.as_posix(),
                            "render_sha256": sha(image), "dimensions": [width, height],
                            "source_glb": source.as_posix(), "source_sha256": original_sha,
                            "camera_location": list(cam.location), "camera_rotation": list(cam.rotation_euler),
                            "camera_scale": camdata.ortho_scale, "shading_policy": "original baseColor, Workbench FLAT texture; no PBR lighting/bloom; no rebake",
                            "directly_reviewed": False, "native_qa": False})
    if sha(source) != original_sha or sha(REFERENCE) != REFERENCE_SHA:
        raise AssertionError("Read-only CG changed source bytes")
    (output / "render_proof.json").write_text(json.dumps({"source_sha256": original_sha,
          "source_unchanged": True, "source_png_sha_gate_pass": True, "source_import_blender_version": bpy.app.version_string,
          "active_basecolor_images": active_basecolors,
          "camera_bounds": {"lower": list(low), "upper": list(high), "evaluated_rendered_faces_only": True},
          "camera_rendered_mesh_objects": rendered_mesh_objects,
          "source_glb_mesh_node_name_gate": sorted(original_mesh_node_names),
          "source_texture_downsamples": 0, "source_geometry_uv_edits": 0, "records": records,
          "uploads": 0, "studio_calls": 0, "native_qa_passed": False}, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"renders": len(records), "output": output.as_posix(), "source_sha256": original_sha}), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path)
    parser.add_argument("--rig", type=Path)
    parser.add_argument("--blender-render", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--extract", action="store_true", help="Byte-exact embedded image copies only")
    parser.add_argument("--face-limit", type=int, default=18000)
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    args = parser.parse_args(argv)
    if args.blender_render:
        if args.model or args.rig or args.extract:
            parser.error("Rendering and inspection are separate operations")
        run_render(args)
    else:
        if not args.model:
            parser.error("Inspection requires --model")
        run_inspection(args)


if __name__ == "__main__":
    main()
