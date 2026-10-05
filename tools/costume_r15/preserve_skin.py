# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
# Still importable as a library ONLY because live tools import it (tools/monster_import_preflight.py,
# tools/test_weapon_motion.py, GLB audit tools). Never run it directly.
"""Copy a genuine skin into an unregistered R15-proxy visual candidate.

Original geometry, UVs, normals, images, joints, weights and inverse binds are
never re-exported. Only bone/mesh node names and an exact scene-frame wrapper
change. Auxiliary source bones remain; this is not a native R15 avatar asset.
"""
from __future__ import annotations

if __name__ == "__main__":
    raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import copy
import hashlib
import json
from pathlib import Path

import numpy as np

from constraints import PRIMARY, RigError, bone_regions, normalized_bone
from glb_io import image_bytes, read_glb, view_bytes, write_glb
from restore_material_regions import primitives


ROOT = Path(__file__).resolve().parents[2]
PROXY_JOINT_TOLERANCE = 2e-6  # Original float32 Blender joint export, measured across all 14 actual skins.


def node_matrices(gltf):
    nodes = gltf.get("nodes", [])
    parents, local, world = {}, {}, {}
    for index, node in enumerate(nodes):
        for child in node.get("children", []):
            if child in parents or not isinstance(child, int) or not 0 <= child < len(nodes):
                raise RigError("Invalid or multiple source node parents")
            parents[child] = index
        if "matrix" in node:
            if any(key in node for key in ("translation", "rotation", "scale")):
                raise RigError("A source node mixes matrix and TRS")
            matrix = np.asarray(node["matrix"], dtype=float).reshape(4, 4, order="F")
        else:
            translation = np.asarray(node.get("translation", (0, 0, 0)), dtype=float)
            scale = np.asarray(node.get("scale", (1, 1, 1)), dtype=float)
            q = np.asarray(node.get("rotation", (0, 0, 0, 1)), dtype=float)
            if translation.shape != (3,) or scale.shape != (3,) or q.shape != (4,) or abs(np.dot(q, q) - 1) > 1e-5:
                raise RigError("Invalid actual source TRS/quaternion")
            x, y, z, w = q
            rotation = np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
                                 [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
                                 [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
            matrix = np.eye(4)
            matrix[:3, :3], matrix[:3, 3] = rotation @ np.diag(scale), translation
        if not np.isfinite(matrix).all() or np.max(np.abs(matrix[3] - (0, 0, 0, 1))) > 1e-6 or abs(np.linalg.det(matrix[:3, :3])) < 1e-12:
            raise RigError("Invalid singular/non-affine source node")
        local[index] = matrix
    def visit(index, ancestors):
        if index in ancestors:
            raise RigError("Cyclic actual source nodes")
        if index not in world:
            parent = visit(parents[index], ancestors | {index}) if index in parents else np.eye(4)
            world[index] = parent @ local[index]
        return world[index]
    for index in range(len(nodes)):
        visit(index, set())
    return parents, local, world


def inverse_binds(gltf, binary, skin):
    accessor = gltf["accessors"][skin["inverseBindMatrices"]]
    if accessor.get("componentType") != 5126 or accessor.get("type") != "MAT4" or accessor.get("sparse") or accessor.get("normalized"):
        raise RigError("Original float MAT4 inverse binds required")
    view, content = view_bytes(gltf, binary, accessor["bufferView"])
    count, start, stride = accessor["count"], accessor.get("byteOffset", 0), view.get("byteStride", 64)
    if count != len(skin["joints"]) or start < 0 or stride < 64 or start + (count - 1) * stride + 64 > len(content):
        raise RigError("Invalid actual inverse-bind array")
    return [np.frombuffer(content, dtype="<f4", count=16, offset=start+i*stride).astype(float).reshape(4, 4, order="F") for i in range(count)]


def similarity(source, target):
    source, target = np.asarray(source, float), np.asarray(target, float)
    first, second = source - source.mean(0), target - target.mean(0)
    u, singular, vt = np.linalg.svd(first.T @ second)
    rotation = vt.T @ u.T
    if np.linalg.det(rotation) < .99999:
        raise RigError("Proxy frame would reflect the original surface")
    scale = float(singular.sum() / np.square(first).sum())
    matrix = np.eye(4)
    matrix[:3, :3] = rotation * scale
    matrix[:3, 3] = target.mean(0) - matrix[:3, :3] @ source.mean(0)
    error = float(np.linalg.norm(source @ matrix[:3, :3].T + matrix[:3, 3] - target, axis=1).max())
    if not np.isfinite(matrix).all() or scale <= 0 or error > PROXY_JOINT_TOLERANCE:
        raise RigError("Existing exact R15 joints do not share a single source similarity frame")
    return matrix, error, scale


def package_surfaces(gltf, rows, split_material_surfaces, omit_unused_records):
    """Package active original primitives, without touching a geometry accessor.

    The three reviewed material-recovered rigs contain two original material
    primitives under one source node. Give each primitive its own visual mesh
    while retaining its original frame and skin. Unreferenced provider records
    may be omitted explicitly; the entire binary, including their bytes, stays.
    """
    result = copy.deepcopy(gltf)
    mesh_rows, seen, source_refs = [], set(), []
    if split_material_surfaces:
        if len(rows) != 2 or len({row["node"] for row in rows}) != 1:
            raise RigError("Material surface split requires exactly two reviewed primitives in one node")
        old_node = rows[0]["node"]
        for row in rows:
            material = gltf["materials"][row["definition"]["material"]]
            role = material.get("name")
            if role not in ("BodyMat", "HeadMat") or role in seen:
                raise RigError("Original BodyMat/HeadMat roles are not uniquely verified")
            seen.add(role)
            name = "CostumeSkin" + role.removesuffix("Mat")
            mesh = len(result["meshes"])
            result["meshes"].append({"name": name, "primitives": [copy.deepcopy(row["definition"])]})
            if row == rows[0]:
                node_index = old_node
            else:
                node_index = len(result["nodes"])
                result["nodes"].append(copy.deepcopy(gltf["nodes"][old_node]))
                for node in result["nodes"][:node_index]:
                    if old_node in node.get("children", []):
                        node["children"].append(node_index)
                for scene in result["scenes"]:
                    if old_node in scene["nodes"]:
                        scene["nodes"].append(node_index)
            result["nodes"][node_index].update(name=name, mesh=mesh)
            mesh_rows.append({"source_node": old_node, "source_name": gltf["nodes"][old_node].get("name"),
                "source_primitive": row["primitive"], "name": name, "mesh": mesh,
                "node": node_index})
            source_refs.append((row["definition"], result["meshes"][mesh]["primitives"][0]))
    else:
        for node_index in dict.fromkeys(row["node"] for row in rows):
            node = result["nodes"][node_index]
            old_name = node.get("name", "")
            if old_name not in ("Head", "Body"):
                raise RigError("Reviewed skin requires separate Head/Body or explicit material-surface splitting")
            name = "CostumeSkin" + old_name
            node["name"] = name
            result["meshes"][node["mesh"]]["name"] = name
            mesh_rows.append({"source_node": node_index, "source_name": old_name, "name": name,
                              "mesh": node["mesh"], "node": node_index})
            for row in rows:
                if row["node"] == node_index:
                    source_refs.append((row["definition"], result["meshes"][row["mesh"]]["primitives"][row["primitive"]]))
    if len(mesh_rows) != 2 or {row["name"] for row in mesh_rows} != {"CostumeSkinBody", "CostumeSkinHead"}:
        raise RigError("Exactly two original active body/head visual surfaces are required")
    active_materials = list(dict.fromkeys(old["material"] for old, _ in source_refs))
    material_map = {old: index for index, old in enumerate(active_materials)}
    active_textures, active_images = [], []
    for index in active_materials:
        material = gltf["materials"][index]
        pbr = material.get("pbrMetallicRoughness", {})
        if any(key in material for key in ("normalTexture", "occlusionTexture", "emissiveTexture", "extensions")) or "metallicRoughnessTexture" in pbr:
            raise RigError("The reviewed two-PNG pilot does not silently prune additional material maps")
        texture = pbr["baseColorTexture"]["index"]
        if texture not in active_textures:
            active_textures.append(texture)
        image = gltf["textures"][texture]["source"]
        if image not in active_images:
            active_images.append(image)
    if len(active_images) != 2:
        raise RigError("The reviewed original body/head PNG roles must remain distinct")
    if omit_unused_records:
        texture_map = {old: index for index, old in enumerate(active_textures)}
        image_map = {old: index for index, old in enumerate(active_images)}
        result["materials"] = [copy.deepcopy(gltf["materials"][index]) for index in active_materials]
        for material in result["materials"]:
            info = material["pbrMetallicRoughness"]["baseColorTexture"]
            info["index"] = texture_map[info["index"]]
        result["textures"] = [copy.deepcopy(gltf["textures"][index]) for index in active_textures]
        for texture in result["textures"]:
            texture["source"] = image_map[texture["source"]]
        result["images"] = [copy.deepcopy(gltf["images"][index]) for index in active_images]
        for _, primitive in source_refs:
            primitive["material"] = material_map[primitive["material"]]
        # Drop only unreferenced mesh definitions (the old combined prototype).
        active_meshes = [row["mesh"] for row in mesh_rows]
        selected = [result["meshes"][index] for index in active_meshes]
        for index, row in enumerate(mesh_rows):
            result["nodes"][row["node"]]["mesh"] = row["mesh"] = index
        result["meshes"] = selected
    for old, new in source_refs:
        if {key: value for key, value in old.items() if key != "material"} != {key: value for key, value in new.items() if key != "material"}:
            raise RigError("Original geometry/skin primitive references changed")
        old_material = copy.deepcopy(gltf["materials"][old["material"]])
        new_material = copy.deepcopy(result["materials"][new["material"]])
        old_texture = old_material["pbrMetallicRoughness"]["baseColorTexture"].pop("index")
        new_texture = new_material["pbrMetallicRoughness"]["baseColorTexture"].pop("index")
        if old_material != new_material:
            raise RigError("Original material shader properties changed")
        first, second = gltf["textures"][old_texture], result["textures"][new_texture]
        if {k: v for k, v in first.items() if k != "source"} != {k: v for k, v in second.items() if k != "source"}:
            raise RigError("Original texture sampler properties changed")
        if gltf["images"][first["source"]] != result["images"][second["source"]]:
            raise RigError("Original material image reference changed")
    return result, mesh_rows, active_images


def prepare(plan_path, output, split_material_surfaces=False, omit_unused_records=False):
    plan_path, output = Path(plan_path).resolve(), Path(output).resolve()
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    source = Path(plan["source"]).resolve()
    if ROOT / "build" not in output.parents or output.exists() or output.with_suffix(".skin.json").exists():
        raise RigError("A new skin candidate and audit inside build/ are required")
    gltf, binary, original = read_glb(source)
    source_sha = hashlib.sha256(original).hexdigest()
    if source_sha != plan["source_sha256"] or len(gltf.get("skins", [])) != 1:
        raise RigError("One unchanged actual source skin matching the plan is required")
    if plan.get("rig_origin") == "inferred_manual_candidate" or gltf.get("extras", {}).get("HHC_ManualBind"):
        raise RigError("This preservation tool does not replace manual inference")
    rows = primitives(gltf, binary, True)
    parents, local, world = node_matrices(gltf)
    skin = gltf["skins"][0]
    bones = skin["joints"]
    if len(set(bones)) != len(bones) or any(gltf["nodes"][row["node"]].get("skin") != 0 for row in rows):
        raise RigError("Ambiguous source skin joints/mesh references")
    source_names = {index: gltf["nodes"][index]["name"] for index in bones}
    if len(set(source_names.values())) != len(bones):
        raise RigError("Source bone names are not unique")
    def parent_bone(index):
        current = parents.get(index)
        while current is not None and current not in source_names:
            current = parents.get(current)
        return current
    name_parents = {name: source_names.get(parent_bone(index)) for index, name in source_names.items()}
    mapping, primary = bone_regions(name_parents)
    lookup = {name: index for index, name in source_names.items()}
    joints = {joint["part1"]: joint for joint in plan["joints"]}
    if set(joints) != set(PRIMARY):
        raise RigError("All 15 actual proxy joints are required")
    transform, joint_error, scale = similarity([world[lookup[primary[part]]][:3, 3] for part in PRIMARY],
                                              [joints[part]["joint_position"] for part in PRIMARY])
    if abs(scale - plan["uniform_scale"]) > 1e-5:
        raise RigError("Source and exact existing proxy scales disagree")
    binds = inverse_binds(gltf, binary, skin)
    bind_error = max(float(np.max(np.abs(world[index] @ bind - world[row["node"]])))
                     for index, bind in zip(bones, binds) for row in rows)
    if bind_error > 1e-5:
        raise RigError("Actual skin does not have the verified original rest bind")
    weight_error, used, multibone = 0., set(), 0
    for row in rows:
        for indices, weights in zip(row["values"]["JOINTS_0"], row["values"]["WEIGHTS_0"]):
            if any(not isinstance(index, int) or not 0 <= index < len(bones) for index in indices) or min(weights) < 0:
                raise RigError("Invalid source skin influence")
            weight_error = max(weight_error, abs(sum(weights) - 1))
            multibone += sum(weight > 1e-8 for weight in weights) > 1
            used.update(bones[index] for index, weight in zip(indices, weights) if weight > 1e-8)
    if weight_error > 1e-4:
        raise RigError("Source weights are not normalized; refusing reweighting")
    if split_material_surfaces:
        recovery = source.with_suffix(".recovery.json")
        if not recovery.exists() or json.loads(recovery.read_text(encoding="utf-8")).get("output_sha256") != source_sha:
            raise RigError("Material surface splitting requires the exact reviewed source recovery proof")
    result, mesh_rows, active_images = package_surfaces(gltf, rows, split_material_surfaces, omit_unused_records)
    bone_rows, names = [], set()
    for skin_index, index in enumerate(bones):
        old_name = source_names[index]
        principal = next((part for part, name in primary.items() if name == old_name), None)
        target = mapping.get(old_name)
        if target is None:
            if normalized_bone(old_name) != "root" or parent_bone(index) is not None:
                raise RigError("Auxiliary source bone has no verified proxy ancestry")
            target = "HumanoidRootPart"
        name = principal or "Aux_" + normalized_bone(old_name)
        if name in names:
            raise RigError("Mapped source bone names collide")
        names.add(name)
        result["nodes"][index]["name"] = name
        parent = parent_bone(index)
        bone_rows.append({"skin_index": skin_index, "source_node": index, "source_name": old_name,
            "name": name, "parent": source_names[parent] if parent is not None else None,
            "parent_name": next((part for part, old in primary.items() if old == source_names.get(parent)), None)
                           or ("Aux_" + normalized_bone(source_names[parent]) if parent is not None else None),
            "proxy_part": target, "principal": principal is not None, "weighted": index in used,
            "source_bind_world": world[index].flatten(order="F").tolist(),
            "game_bind_world": (transform @ world[index]).flatten(order="F").tolist()})
    for row in mesh_rows:
        row["source_world"] = world[row["source_node"]].flatten(order="F").tolist()
    scene = result["scenes"][result.get("scene", 0)]
    wrapper = len(result["nodes"])
    result["nodes"].append({"name": "CostumeSkinFrame", "children": list(scene["nodes"]),
                           "matrix": transform.flatten(order="F").tolist()})
    scene["nodes"] = [wrapper]
    candidate = {"schema": 1, "source": str(source), "source_sha256": source_sha,
        "proxy_plan": str(plan_path), "proxy_plan_sha256": hashlib.sha256(plan_path.read_bytes()).hexdigest(),
        "rig_origin": "preserved_source_skin_proxy_candidate", "rig_ready_for_game": False,
        "studio_motion_validated": False, "native_r15_asset_claimed": False,
        "source_to_game_affine": transform.flatten(order="F").tolist(), "uniform_scale": scale,
        "affine_layout": "gltf_column_major_16", "source_frame_policy": plan.get("source_frame_policy", "bones"),
        "maximum_proxy_joint_error": joint_error, "maximum_source_bind_error": bind_error,
        "proxy_joint_tolerance": PROXY_JOINT_TOLERANCE,
        "maximum_source_weight_sum_error": weight_error, "multiple_influence_vertices": multibone,
        "bones": bone_rows, "meshes": mesh_rows, "source_skin_bones": len(bones),
        "principal_r15_bones": 15, "original_triangles": sum(len(row["triangles"]) for row in rows),
        "estimated_assets": 1 + len(mesh_rows) + len(result.get("images", [])),
        "active_original_images": len(active_images), "material_surfaces_packaged": split_material_surfaces,
        "unused_metadata_records_omitted": omit_unused_records,
        "original_mesh_skin_accessors_binary_images_materials_preserved": True,
        "api_called": False, "uploads": 0,
        "limitations": ["The native importer must retain the original skin; a rigid R15 convert discards it.",
            "A separate 15-part R15 physics proxy must drive every actual imported Bone using the verified bind frame.",
            "Bones deform appearance only; collisions, weapons and expression attachment need actual proxy QA.",
            "Source weights may contain anatomical defects; continuous skin does not repair those weights."]}
    if candidate["estimated_assets"] > 10:
        raise RigError("The pilot exceeds the <=10 upload budget")
    result.setdefault("extras", {})["HHC_PreservedSkinCandidate"] = candidate
    if any(result[key] != gltf[key] for key in ("accessors", "bufferViews", "buffers", "skins")):
        raise RigError("Original surface/skin metadata changed")
    output.parent.mkdir(parents=True, exist_ok=True)
    write_glb(output, result, binary)
    checked, actual_binary, _ = read_glb(output)
    if actual_binary != binary or any(image_bytes(gltf, binary, gltf["images"][index]) !=
                                    image_bytes(checked, actual_binary, checked["images"][next(i for i, image in enumerate(checked["images"]) if image == gltf["images"][index])])
                                    for index in active_images):
        raise RigError("Original skin/image binary changed")
    candidate.update(output=str(output), output_sha256=hashlib.sha256(output.read_bytes()).hexdigest(),
                     source_file_unchanged=source.read_bytes() == original)
    output.with_suffix(".skin.json").write_text(json.dumps(candidate, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return candidate


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--split-material-surfaces", action="store_true")
    parser.add_argument("--omit-unused-records", action="store_true")
    args = parser.parse_args()
    result = prepare(args.plan, args.output, args.split_material_surfaces, args.omit_unused_records)
    print(json.dumps({key: result[key] for key in ("output", "output_sha256", "source_skin_bones", "principal_r15_bones",
        "original_triangles", "estimated_assets", "maximum_proxy_joint_error", "maximum_source_bind_error", "multiple_influence_vertices", "rig_ready_for_game")}, ensure_ascii=False))


if __name__ == "__main__":
    main()
