"""Blender-only local preparation: a real Mixamo skin -> 15 rigid R15 pieces and actual bone joint positions.

blender --background --factory-startup --python tools/costume_r15/convert.py -- INPUT.glb OUT_DIR --height 5.5 [--dry]
No network, uploads, generation, rigging, UV packing, texture baking, or source-file writes.
"""

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import shutil
import sys
import tempfile

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from constraints import JOINTS, PRIMARY, RigError, adjacent_regions, bone_regions, face_region, region_weights, upload_batches
from glb_io import accessor_values, image_bytes, read_glb, view_bytes, write_glb

ROOT = Path(__file__).resolve().parents[2]


def preserve_images(path, source_images):
    """Replace exporter image bytes with the exact source bytes, without editing/re-encoding a face texture."""
    gltf, binary, _ = read_glb(path)
    images = gltf.get("images", [])
    replacements = {}
    for image in images:
        name = image.get("name")
        if name not in source_images:
            raise RigError(f"Exporter created an unrecognized/repacked image: {name}")
        content, mime = source_images[name]
        image_bytes(gltf, binary, image)
        index = image["bufferView"]
        if any(accessor.get("bufferView") == index for accessor in gltf.get("accessors", [])):
            raise RigError("Exporter shared an image buffer view with geometry")
        if index in replacements and replacements[index] != content:
            raise RigError("Exporter shared a buffer view between different source images")
        replacements[index] = content
        image["mimeType"] = mime
    # Rebuild views in place so preserving original image bytes does not retain a second, unused image copy.
    rebuilt = bytearray()
    for index, view in enumerate(gltf.get("bufferViews", [])):
        content = replacements[index] if index in replacements else view_bytes(gltf, binary, index)[1]
        rebuilt += b"\0" * (-len(rebuilt) % 4)
        view["byteOffset"], view["byteLength"] = len(rebuilt), len(content)
        rebuilt += content
    binary = bytes(rebuilt)
    gltf["buffers"][0]["byteLength"] = len(binary)
    write_glb(path, gltf, binary)
    return {image.get("name"): hashlib.sha256(image_bytes(gltf, binary, image)).hexdigest() for image in images}


def source_images(gltf, binary):
    original = {}
    for image in gltf.get("images", []):
        content = image_bytes(gltf, binary, image)
        original[hashlib.sha256(content).hexdigest()] = (content, image.get("mimeType", "image/png"))
    result = {}
    for image in bpy.data.images:
        packed = image.packed_file
        if not packed:
            continue
        content = bytes(packed.data)
        fingerprint = hashlib.sha256(content).hexdigest()
        if fingerprint in original:
            result[image.name] = original[fingerprint]
    if len({hashlib.sha256(item[0]).hexdigest() for item in result.values()}) != len(original):
        raise RigError("Could not verify the original embedded texture bytes")
    return result


def input_images(socket, seen=None):
    seen = set() if seen is None else seen
    images = set()
    for link in socket.links:
        node = link.from_node
        if node in seen:
            continue
        seen.add(node)
        if node.type == "TEX_IMAGE" and node.image:
            images.add(node.image.name)
        else:
            for child in node.inputs:
                images.update(input_images(child, seen))
    return images


def material_roles(material):
    if material is None or not material.use_nodes:
        return set()
    bsdf = next((node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED"), None)
    if not bsdf:
        raise RigError("Only the existing glTF Principled material is supported")
    if "Emission Color" in bsdf.inputs and input_images(bsdf.inputs["Emission Color"]):
        raise RigError("Emissive texture needs a separate Roblox material review")
    roles = set()
    for socket, role in (("Base Color", "ColorMap"), ("Normal", "NormalMap"), ("Metallic", "MetalnessMap"), ("Roughness", "RoughnessMap")):
        for image in input_images(bsdf.inputs[socket]):
            roles.add((image, role))
    return roles


def analyze_scene(height, nonadjacent_ties="refuse"):
    arms = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    if len(arms) != 1:
        raise RigError("A single real skinned armature is required; static GLBs are refused")
    arm = arms[0]
    # Blender's glTF importer adds a hidden Icosphere as a bone display shape.
    # Ignore only that explicitly referenced, non-exported helper, never an input's unskinned mesh.
    shapes = {bone.custom_shape for bone in arm.pose.bones if bone.custom_shape}
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and not
              (obj in shapes and obj.users_collection and all(collection.name == "glTF_not_exported" and
               collection.hide_render and collection.hide_viewport for collection in obj.users_collection))]
    if not meshes:
        raise RigError("The real armature has no skinned geometry")
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    parents = {bone.name: bone.parent.name if bone.parent else None for bone in arm.data.bones}
    mapping, primary = bone_regions(parents)
    positions = {part: arm.matrix_world @ arm.data.bones[bone].head_local for part, bone in primary.items()}
    origin = positions["LowerTorso"]
    right = positions["RightUpperArm"] - positions["LeftUpperArm"]
    up = positions["Head"] - origin
    if right.length < 1e-8 or up.length < 1e-8:
        raise RigError("Degenerate actual shoulder/head/hip positions")
    right.normalize()
    up -= right * up.dot(right)
    if up.length < 1e-8:
        raise RigError("Cannot establish an orthogonal frame from actual bones")
    up.normalize()
    back = right.cross(up).normalized()
    basis = Matrix((right, up, back))
    all_points = [obj.matrix_world @ vertex.co for obj in meshes for vertex in obj.data.vertices]
    ys = [(basis @ (point - origin)).y for point in all_points]
    source_height = max(ys) - min(ys)
    if source_height <= 1e-8:
        raise RigError("Zero model height")
    scale = height / source_height
    coordinate = Matrix.Diagonal(Vector((scale, scale, scale, 1.0))) @ basis.to_4x4() @ Matrix.Translation(-origin)
    # Roblox/glTF are Y up. Blender export_yup transforms (x, -z, y) back to (x, y, z).
    to_blender = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    faces = {part: [] for part in PRIMARY}
    points = {part: [] for part in PRIMARY}
    materials = {part: set() for part in PRIMARY}
    min_confidence, total_faces = 1.0, 0
    diagnostics = {"low_confidence_faces": 0, "parent_tie_faces": 0, "non_adjacent_exact_ties": 0, "non_adjacent_close_weights": 0, "examples": [], "exact_tie_examples": []}
    for obj in meshes:
        mods = [modifier for modifier in obj.modifiers if modifier.type == "ARMATURE"]
        if len(mods) != 1 or mods[0].object != arm:
            raise RigError(f"Unskinned/differently skinned mesh: {obj.name}")
        if any(modifier.type != "ARMATURE" for modifier in obj.modifiers):
            raise RigError(f"Unbaked geometry modifier: {obj.name}")
        if obj.data.shape_keys:
            raise RigError(f"Blend shapes need a separate dynamic-head pipeline: {obj.name}")
        group_names = {group.index: group.name for group in obj.vertex_groups}
        weights = [region_weights([(group_names[group.group], group.weight) for group in vertex.groups], mapping) for vertex in obj.data.vertices]
        for face in obj.data.polygons:
            if len(face.vertices) != 3:
                raise RigError("Expected the source GLB triangle topology")
            vertex_weights = [weights[index] for index in face.vertices]
            part, confidence = face_region(vertex_weights, nonadjacent_ties)
            scores = Counter()
            for index in face.vertices:
                for region, weight in weights[index].items():
                    scores[region] += weight / 3
            ordered = scores.most_common()
            low = confidence < 0.5
            tie = len(ordered) > 1 and ordered[0][1] - ordered[1][1] <= 1e-8
            nonadjacent_tie = False
            if tie:
                try:
                    face_region(vertex_weights)
                except RigError:
                    nonadjacent_tie = True
                    if len(diagnostics["exact_tie_examples"]) < 20:
                        diagnostics["exact_tie_examples"].append({"object": obj.name, "face": face.index, "chosen_part": part, "region_weights": dict(ordered)})
            distant = len(ordered) > 1 and ordered[1][1] >= 0.25 and ordered[0][1] - ordered[1][1] < 0.1 and not adjacent_regions(ordered[0][0], ordered[1][0])
            diagnostics["low_confidence_faces"] += low
            diagnostics["parent_tie_faces"] += tie
            diagnostics["non_adjacent_exact_ties"] += nonadjacent_tie
            diagnostics["non_adjacent_close_weights"] += distant
            if distant and len(diagnostics["examples"]) < 20:
                diagnostics["examples"].append({"object": obj.name, "face": face.index, "chosen_part": part, "region_weights": dict(ordered)})
            min_confidence = min(min_confidence, confidence)
            faces[part].append((obj, face.index))
            points[part].extend(coordinate @ (obj.matrix_world @ obj.data.vertices[index].co) for index in face.vertices)
            material = obj.data.materials[face.material_index] if len(obj.data.materials) else None
            materials[part].add(material)
            total_faces += 1
    centers, roles, fragments = {}, {}, {}
    for part in PRIMARY:
        if not faces[part]:
            raise RigError(f"Empty R15 region: {part}; no geometric substitute is created")
        low = Vector(tuple(min(point[axis] for point in points[part]) for axis in range(3)))
        high = Vector(tuple(max(point[axis] for point in points[part]) for axis in range(3)))
        if min(high - low) <= height * 1e-8:
            raise RigError(f"Degenerate R15 region: {part}")
        centers[part] = (low + high) * 0.5
        by_material = {}
        for obj, index in faces[part]:
            face = obj.data.polygons[index]
            material = obj.data.materials[face.material_index] if len(obj.data.materials) else None
            by_material.setdefault(material, []).append((obj, index))
        for index, (material, refs) in enumerate(sorted(by_material.items(), key=lambda item: (-len(item[1]), item[0].name if item[0] else "")), 1):
            mesh_name = part if index == 1 else f"{part}__Material{index:02d}"
            fragments[mesh_name] = {"part": part, "material": material.name if material else None, "faces": refs, "is_primary": index == 1}
            roles[mesh_name] = material_roles(material)
    return {"armature": arm, "meshes": meshes, "primary_bones": primary, "faces": faces, "centers": centers,
            "roles": roles, "coordinate": coordinate, "to_blender": to_blender, "bone_positions": positions,
            "scale": scale, "source_height": source_height, "total_faces": total_faces, "min_face_confidence": min_confidence,
            "fragments": fragments, "weight_diagnostics": diagnostics}


def make_piece(mesh_name, analysis):
    fragment = analysis["fragments"][mesh_name]
    part = fragment["part"]
    source_faces = {}
    for obj, index in fragment["faces"]:
        source_faces.setdefault(obj, set()).add(index)
    pieces = []
    original_uv = Counter()
    for source, kept in source_faces.items():
        for face in source.data.polygons:
            if face.index in kept:
                for layer in source.data.uv_layers:
                    original_uv[(layer.name, tuple(sorted(tuple(layer.data[index].uv) for index in face.loop_indices)))] += 1
        obj = source.copy()
        obj.data = source.data.copy()
        obj.parent = None
        obj.modifiers.clear()
        obj.vertex_groups.clear()
        bpy.context.scene.collection.objects.link(obj)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[face for face in bm.faces if face.index not in kept], context="FACES")
        bmesh.ops.delete(bm, geom=[vertex for vertex in bm.verts if not vertex.link_faces], context="VERTS")
        bm.to_mesh(obj.data)
        bm.free()
        # Prune unused material slots without baking or changing per-corner UVs.
        material = next(iter({source.data.materials[face.material_index] if len(source.data.materials) else None for face in source.data.polygons if face.index in kept}))
        obj.data.materials.clear()
        if material is not None:
            obj.data.materials.append(material)
        for face in obj.data.polygons:
            face.material_index = 0
        center = analysis["centers"][part]
        local_matrix = analysis["to_blender"] @ Matrix.Translation(-center) @ analysis["coordinate"] @ source.matrix_world
        obj.data.transform(local_matrix)
        obj.matrix_world = Matrix.Translation(analysis["to_blender"] @ center)
        pieces.append(obj)
    uv_sets = {tuple(layer.name for layer in obj.data.uv_layers) for obj in pieces}
    if len(uv_sets) != 1:
        raise RigError(f"Incompatible UV layer layouts in {part}; refusing a destructive merge")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in pieces:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = pieces[0]
    if len(pieces) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = mesh_name
    obj.data.name = mesh_name + "Mesh"
    copied_uv = Counter()
    for face in obj.data.polygons:
        for layer in obj.data.uv_layers:
            copied_uv[(layer.name, tuple(sorted(tuple(layer.data[index].uv) for index in face.loop_indices)))] += 1
    if copied_uv != original_uv:
        raise RigError(f"Original per-face UV coordinates changed in {part}")
    return obj


def cframe(position):
    return list(position) + [1, 0, 0, 0, 1, 0, 0, 0, 1]


def verify_export(path, parts, objects):
    gltf, binary, _ = read_glb(path)
    mesh_nodes = [node for node in gltf.get("nodes", []) if "mesh" in node]
    if gltf.get("skins") or len(mesh_nodes) != len(parts) or {node.get("name") for node in mesh_nodes} != set(parts):
        raise RigError("Exporter changed body-part names/counts or kept a skin")
    triangles = 0
    for node in mesh_nodes:
        part = node["name"]
        obj = objects[part]
        if "rotation" in node or "scale" in node or "matrix" in node:
            raise RigError(f"Unexpected exported part transform: {part}")
        expected_translation = (obj.location.x, obj.location.z, -obj.location.y)
        if any(abs(actual - expected) > 1e-6 for actual, expected in zip(node.get("translation", (0, 0, 0)), expected_translation)):
            raise RigError(f"Exported part placement changed: {part}")
        primitives = gltf["meshes"][node["mesh"]].get("primitives", [])
        if len(primitives) != 1 or primitives[0].get("mode", 4) != 4:
            raise RigError(f"Exporter changed triangle/material topology: {part}")
        primitive = primitives[0]
        positions = accessor_values(gltf, binary, primitive["attributes"]["POSITION"])
        indices = [record[0] for record in accessor_values(gltf, binary, primitive["indices"])] if "indices" in primitive else list(range(len(positions)))
        if len(indices) % 3 or any(not 0 <= index < len(positions) for index in indices) or len(indices) != 3 * len(obj.data.polygons):
            raise RigError(f"Exported triangle coverage changed: {part}")
        triangles += len(indices) // 3
        for index, layer in enumerate(obj.data.uv_layers):
            attribute = "TEXCOORD_" + str(index)
            if attribute not in primitive["attributes"]:
                raise RigError(f"Exporter dropped original UV layer: {part}/{layer.name}")
            values = accessor_values(gltf, binary, primitive["attributes"][attribute])
            if len(values) != len(positions):
                raise RigError(f"Invalid exported UV vertex count: {part}")
            expected = Counter(tuple(sorted((round(layer.data[loop].uv.x, 6), round(1 - layer.data[loop].uv.y, 6)) for loop in face.loop_indices)) for face in obj.data.polygons)
            actual = Counter(tuple(sorted(tuple(round(component, 6) for component in values[vertex]) for vertex in indices[start:start + 3])) for start in range(0, len(indices), 3))
            if actual != expected:
                raise RigError(f"Exporter changed original per-face UVs: {part}/{layer.name}")
    return {"meshes": len(mesh_nodes), "triangles": triangles, "embedded_images": len(gltf.get("images", [])), "uv_verified": True}


def main():
    parser = argparse.ArgumentParser(description="실제 Mixamo 리깅 GLB만 R15 조각으로 준비해요.")
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--height", required=True, type=float, help="변환 후 전체 높이(스터드)")
    parser.add_argument("--dry", action="store_true")
    parser.add_argument("--nonadjacent-ties", choices=("refuse", "parent-depth"), default="refuse",
                        help="비인접 완전 동률을 별도 허용할 때만 실제 계층의 몸통 쪽 부위를 선택")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    input_path, output = args.input.resolve(), args.output.resolve()
    if not math.isfinite(args.height) or not 0.5 <= args.height <= 20:
        raise RigError("Height must be finite and within 0.5..20 studs")
    if input_path.suffix.lower() != ".glb" or not input_path.is_file():
        raise RigError("Input must be an existing GLB")
    if ROOT not in output.parents or output == input_path.parent or input_path.is_relative_to(output):
        raise RigError("Output must be a new project subdirectory separate from the source")
    if output.exists():
        raise RigError("Output already exists; existing files are never overwritten")
    gltf, binary, source_data = read_glb(input_path)
    if not gltf.get("skins"):
        raise RigError("GLB has no skin; no guessed joint positions or static-weld substitute is allowed")
    for image in gltf.get("images", []):
        image_bytes(gltf, binary, image)
    source_sha = hashlib.sha256(source_data).hexdigest()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(input_path))
    analysis = analyze_scene(args.height, args.nonadjacent_ties)
    textures = source_images(gltf, binary)
    parts = list(PRIMARY)
    mesh_names = list(analysis["fragments"])
    batches = upload_batches(mesh_names, analysis["roles"])
    centers = {**analysis["centers"], "HumanoidRootPart": Vector((0, 0, 0))}
    joints = []
    for name, parent, child, bone in JOINTS:
        actual = analysis["coordinate"] @ analysis["bone_positions"][child]
        joints.append({"name": name, "part0": parent, "part1": child,
                       "source_bone": analysis["primary_bones"][child],
                       "joint_position": list(actual), "C0": cframe(actual - centers[parent]), "C1": cframe(actual - centers[child])})
    plan = {"schema": 1, "dry_run": args.dry, "source": str(input_path), "source_sha256": source_sha,
            "output": str(output), "parts": [{"name": part, "triangles": len(analysis["faces"][part]), "CFrame": cframe(centers[part]),
                                               "meshes": [name for name, fragment in analysis["fragments"].items() if fragment["part"] == part]} for part in parts],
            "meshes": [{"name": name, "part": fragment["part"], "material": fragment["material"], "is_primary": fragment["is_primary"],
                        "triangles": len(fragment["faces"]), "CFrame": cframe(centers[fragment["part"]])} for name, fragment in analysis["fragments"].items()],
            "joints": joints, "batches": [{**batch, "file": f"batch_{index:02d}.glb"} for index, batch in enumerate(batches, 1)],
            "target_height_studs": args.height, "source_height": analysis["source_height"], "uniform_scale": analysis["scale"],
            "source_triangles": analysis["total_faces"], "minimum_face_confidence": analysis["min_face_confidence"],
            "partition_policy": "Maximum average original bone-region weight; connected exact ties choose the nearest parent; equal depth uses a stable name order.",
            "nonadjacent_ties": args.nonadjacent_ties,
            "weight_diagnostics": analysis["weight_diagnostics"],
            "auxiliary_mesh_policy": "Material fragments retain original UVs/images and must be welded only to their named, actual Motor6D-driven R15 part.",
            "root": {"name": "HumanoidRootPart", "CFrame": cframe(centers["HumanoidRootPart"]), "Size": [2, 2, 1]},
            "texture_rebake": False, "uv_repack": False, "original_texture_bytes_preserved": True,
            "rig_ready_for_game": False, "requires_studio_animation_validation": True,
            "limitations": ["Bone-weight maximum triangles become rigid parts; joint seams and non-adjacent low-confidence weights need motion QA.",
                            "Exact bone joint positions use canonical R15 axes; Mixamo bind-pose/roll versus default Animate is not yet verified.",
                            "No retargeting or geometry-based replacement is performed."]}
    if args.dry:
        print(json.dumps(plan, ensure_ascii=False, indent=2), flush=True)
        return
    output.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".costume-r15-", dir=output.parent))
    try:
        # Imported objects can already be called Head/Body. Release names in Blender memory only,
        # otherwise Blender appends .001 to an exported R15 part; the source file is untouched.
        for index, obj in enumerate(list(bpy.context.scene.objects)):
            obj.name = f"__costume_r15_source_{index:03d}"
        objects = {name: make_piece(name, analysis) for name in mesh_names}
        if sum(len(obj.data.polygons) for obj in objects.values()) != analysis["total_faces"]:
            raise RigError("Face coverage changed while splitting")
        for batch in plan["batches"]:
            bpy.ops.object.select_all(action="DESELECT")
            for part in batch["parts"]:
                objects[part].select_set(True)
            path = staging / batch["file"]
            bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                                      export_yup=True, export_animations=False, export_skins=False)
            batch["texture_sha256"] = preserve_images(path, textures)
            batch["export_validation"] = verify_export(path, batch["parts"], objects)
            actual_minimum = 1 + batch["export_validation"]["meshes"] + batch["export_validation"]["embedded_images"]
            if actual_minimum > batch["estimated_assets"] or actual_minimum > 10:
                raise RigError("Exporter exceeded the conservative upload budget")
            batch["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        if hashlib.sha256(input_path.read_bytes()).hexdigest() != source_sha:
            raise RigError("Source GLB changed during processing")
        (staging / "joints.json").write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding="utf-8")
        staging.rename(output)
        print(f"[costume_r15] prepared {len(parts)} parts / {len(batches)} batches: {output}", flush=True)
    except Exception:
        # Only remove our checked, fresh temporary directory; never the source or an existing output.
        if staging.parent == output.parent and staging.name.startswith(".costume-r15-"):
            shutil.rmtree(staging)
        raise


if __name__ == "__main__":
    try:
        main()
    except (RigError, ValueError, OSError) as error:
        print(f"[costume_r15] refused: {error}", file=sys.stderr, flush=True)
        sys.exit(2)
