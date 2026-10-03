"""Explicit, reviewed hair/cape weight corrections on new local candidates.

The original GLB/binary prefix, geometry, UVs, normals, materials, embedded
images, rest nodes and bind matrices are retained. Only selected active skin
attributes are replaced with appended arrays; every change is recorded.
Planning is not approval. Inspect the region overlay before --reviewed apply.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import struct

import numpy as np

from constraints import RigError
from glb_io import accessor_values, image_bytes, read_glb, write_glb
from preserve_skin import ROOT, node_matrices

ARM_PARTS = {side + part for side in ("Left", "Right") for part in ("UpperArm", "LowerArm", "Hand")}
# Canonical rest coordinates measured from the approved source and pose images.
# Mesh identity plus a narrow posterior domain excludes face, glove and sleeve.
REGIONS = {
    "HornsMageF": [
        {"name": "posterior_hair", "mesh": "CostumeSkinHead", "min": [-1.55, .65, -.95],
         "max": [1.80, 2.95, 1.35], "target": "Head", "feather": .04, "transfer": "all",
         "exclude_box": {"min": [-.80, 1.30, -1.35], "max": [.95, 2.78, -.40]},
         "evidence": "Rear long hair and its connected side strands use the Head surface. Bounds extend past the actual strand tips; the separately measured anterior face volume is excluded."},
        {"name": "posterior_lower_hair", "mesh": "CostumeSkinBody", "min": [-1.65, -.45, -.10],
         "max": [1.95, 1.45, 1.60], "target": "Head", "feather": .025, "transfer": "all",
         "boxes": [{"min": [-1.65, -.45, .72], "max": [1.95, 1.45, 1.60]},
                   {"min": [-1.65, .65, -.10], "max": [1.95, 1.45, 1.60]},
                   {"min": [1.13, -.10, .25], "max": [1.95, 1.45, 1.60]},
                   {"min": [-1.65, -.10, .25], "max": [-1.10, 1.45, 1.60]}],
         "evidence": "Separate actual Body-only front/back/right/left views and original ray-hit faces identify the complete lower rear hair and lateral curls. Hair ray hits reach z 0.037 and y 0.43; the visible front sleeve lies at z -0.448 and is excluded. No material-wide reassignment is used."},
        {"name": "posterior_coat", "mesh": "CostumeSkinBody", "min": [-1.30, -1.50, -.80],
         "max": [1.45, 1.48, 1.60], "target": "UpperTorso", "feather": .035,
         "boxes": [{"min": [-.95, .35, .60], "max": [1.10, 1.48, 1.60]},
                   {"min": [-1.30, -1.50, .22], "max": [1.45, .65, 1.60]},
                   {"min": [-1.30, -1.50, -.80], "max": [1.45, -.30, 1.60]}],
         "exclude_boxes": [{"min": [-1.65, -.45, .72], "max": [1.95, 1.45, 1.60]},
                   {"min": [-1.65, .65, -.10], "max": [1.95, 1.45, 1.60]},
                   {"min": [1.13, -.10, .25], "max": [1.95, 1.45, 1.60]},
                   {"min": [-1.65, -.10, .25], "max": [-1.10, 1.45, 1.60]},
                   {"min": [-.62, -1.50, -.30], "max": [.62, -.45, .35]}],
         "evidence": "The central rear upper coat and rear lower coat tails are inspected separately; the two prisms exclude upper lateral sleeves and extend beyond the actual lower cloth edges."}],
    "HornsArcherM": [
        {"name": "posterior_cape", "mesh": "CostumeSkinBody", "min": [-1.55, -1.31, .23],
         "max": [1.47, 1.42, 1.45], "target": "UpperTorso", "feather": .015,
         "evidence": "Actual seeded cape UV charts span x -1.505..1.412, y -0.943..1.224, z 0.273..1.256. These posterior bounds include the complete cloth edges instead of fading inside the tips."}],
    "NeutralArcherF": [
        {"name": "posterior_right_braid", "mesh": "CostumeSkinBody", "min": [1.08, 1.25, -.10],
         "max": [2.20, 2.40, .70], "target": "Head", "feather": .025, "transfer": "all",
         "halfplane": {"normal": [1., .8, 0.], "minimum": 2.72},
         "evidence": "Original front/side ray hits identify the complete braid including the teal tie: front surfaces reach z 0.004, lateral corners x 2.076. A measured diagonal x+0.8*y >= 2.72 separates the downward/outward braid from the upward/inward sleeve. Per-texel brown gating was rejected because it disconnected the tie from the hair."}],
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def rows(gltf, binary):
    _, _, world = node_matrices(gltf)
    result = []
    for node_index, node in enumerate(gltf["nodes"]):
        if "mesh" not in node:
            continue
        if node.get("skin") != 0:
            raise RigError("Only the retained single original skin is supported")
        for primitive_index, primitive in enumerate(gltf["meshes"][node["mesh"]]["primitives"]):
            attrs = primitive["attributes"]
            if not {"POSITION", "TEXCOORD_0", "NORMAL", "JOINTS_0", "WEIGHTS_0"}.issubset(attrs):
                raise RigError("Required retained skin attributes are absent")
            values = {key: accessor_values(gltf, binary, value) for key, value in attrs.items()}
            points = np.c_[values["POSITION"], np.ones(len(values["POSITION"]))] @ world[node_index].T
            result.append({"node": node_index, "mesh": node["mesh"], "mesh_name": node["name"],
                "primitive": primitive_index, "definition": primitive, "values": values, "game_points": points[:, :3]})
    return result


def redirect(joints, weights, names, target, amount, transfer="arms"):
    """Transfer only the expressly reviewed influence domain."""
    if transfer not in ("arms", "all") or not 0 <= amount <= 1:
        raise RigError("Unknown influence transfer or invalid fraction")
    if len(joints) != 4 or len(weights) != 4 or any(not np.isfinite(w) or w < 0 for w in weights) or any(i < 0 or i >= len(names) for i in joints):
        raise RigError("The exact finite four source influences are required")
    target_index = names.index(target)
    accumulated = {}
    for index, weight in zip(joints, weights):
        if weight <= 0:
            continue
        moved = weight * amount if transfer == "all" or names[index] in ARM_PARTS else 0.
        accumulated[index] = accumulated.get(index, 0.) + weight - moved
        accumulated[target_index] = accumulated.get(target_index, 0.) + moved
    accumulated = {index: weight for index, weight in accumulated.items() if weight > 1e-12}
    if len(accumulated) > 4:
        raise RigError("Correction would require dropping an original non-arm influence")
    values = list(accumulated.items())
    while len(values) < 4:
        values.append((0, 0.))
    return [index for index, _ in values], [weight for _, weight in values]


def region_amount(point, region):
    boxes = region.get("boxes", [region])
    distances = [float(min(np.min(point-box["min"]), np.min(np.asarray(box["max"])-point)))
                 for box in boxes if np.all(point >= box["min"]) and np.all(point <= box["max"])]
    exclusions=region.get("exclude_boxes",[region["exclude_box"]] if region.get("exclude_box") else [])
    if not distances or any(np.all(point>=box["min"]) and np.all(point<=box["max"]) for box in exclusions):
        return 0.
    distance = max(distances)
    plane = region.get("halfplane")
    if plane:
        normal = np.asarray(plane["normal"])
        distance = min(distance, float((np.dot(normal, point)-plane["minimum"])/np.linalg.norm(normal)))
    amount = min(1., max(0., distance/region["feather"]))
    return amount*amount*(3-2*amount)


def vertex_proposal(joints, weights, names, point, region):
    transfer = region.get("transfer", "arms")
    if transfer == "arms" and sum(w for i,w in zip(joints,weights) if names[i] in ARM_PARTS) <= .05:
        return None
    amount = region_amount(point,region)
    if amount <= 1e-4:
        return None
    try:
        new_joints,new_weights = redirect(joints,weights,names,region["target"],amount,transfer)
    except RigError:
        # Four glTF slots cannot retain a fifth partial target influence.
        # A complete transfer removes the expressly selected old influence;
        # the exact fraction is still recorded before visual review.
        amount = 1.
        new_joints,new_weights = redirect(joints,weights,names,region["target"],amount,transfer)
    new_weights = list(struct.unpack("<4f",struct.pack("<4f",*new_weights)))
    if abs(sum(new_weights)-sum(weights)) > 1e-6:
        raise RigError("Correction changed the original weight sum")
    if list(joints) == new_joints and list(weights) == new_weights:
        return None
    return {"transfer":transfer,"transfer_fraction":amount,"new_joints":new_joints,"new_weights":new_weights}


def plan(manifest_path, name, output):
    manifest_path, output = manifest_path.resolve(), output.resolve()
    if name not in REGIONS or output.exists() or ROOT / "build" not in output.parents:
        raise RigError("Planning requires a supported name and a new build/ JSON")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    source = Path(manifest["output"])
    if manifest.get("rig_origin") != "preserved_source_skin_proxy_candidate" or sha(source) != manifest["output_sha256"]:
        raise RigError("The exact preserved source benchmark is required")
    gltf, binary, _ = read_glb(source)
    names = [gltf["nodes"][index]["name"] for index in gltf["skins"][0]["joints"]]
    changes, counts = [], {}
    for row in rows(gltf, binary):
        values = row["values"]
        for vertex, point in enumerate(row["game_points"]):
            old_joints, old_weights = values["JOINTS_0"][vertex], values["WEIGHTS_0"][vertex]
            hits = [region for region in REGIONS[name] if region["mesh"] == row["mesh_name"] and region_amount(point,region)>1e-4]
            if not hits:
                continue
            if len(hits) != 1:
                raise RigError("Two correction regions overlap")
            region = hits[0]
            proposal = vertex_proposal(old_joints,old_weights,names,point,region)
            if proposal is None:
                continue
            changes.append({"mesh": row["mesh"], "mesh_name": row["mesh_name"], "primitive": row["primitive"],
                "vertex": vertex, "game_position": point.tolist(), "uv": list(values["TEXCOORD_0"][vertex]),
                "region": region["name"], "target": region["target"], **proposal,
                "old_joints": list(old_joints), "old_weights": list(old_weights),
                })
            counts[region["name"]] = counts.get(region["name"], 0) + 1
    if set(counts) != {region["name"] for region in REGIONS[name]}:
        raise RigError("A reviewed region has no source arm influence")
    result = {"schema": 1, "name": name, "source_skin": str(source), "source_skin_sha256": sha(source),
        "source_manifest": str(manifest_path), "source_manifest_sha256": sha(manifest_path),
        "bone_names": names, "regions": REGIONS[name], "region_counts": counts, "changes": changes,
        "region_review_complete": False, "original_geometry_uv_normals_material_images_unchanged": True,
        "rig_ready_for_game": False, "api_calls": 0, "studio_calls": 0}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return result


def append_array(gltf, binary, values, fmt, component, kind):
    record = struct.Struct("<" + fmt * 4)
    payload = b"".join(record.pack(*row) for row in values)
    binary += b"\0" * (-len(binary) % 4)
    view = len(gltf["bufferViews"])
    gltf["bufferViews"].append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(payload), "target": 34962})
    accessor = len(gltf["accessors"])
    gltf["accessors"].append({"bufferView": view, "componentType": component, "count": len(values), "type": kind})
    return accessor, binary + payload


def apply(plan_path, output, reviewed):
    plan_path, output = plan_path.resolve(), output.resolve()
    document = json.loads(plan_path.read_text(encoding="utf-8"))
    if not reviewed or document.get("region_review_complete") is not True or not document.get("reviewed_overlay_images") or output.exists() or ROOT / "build" not in output.parents:
        raise RigError("Application requires an inspected overlay and a new build/ candidate")
    if document.get("regions") != REGIONS.get(document.get("name")):
        raise RigError("The proposal does not use the current inspected narrow regions")
    for image in document["reviewed_overlay_images"]:
        if sha(image["path"]) != image["sha256"]:
            raise RigError("An inspected overlay image changed")
    source, manifest_path = Path(document["source_skin"]), Path(document["source_manifest"])
    if sha(source) != document["source_skin_sha256"] or sha(manifest_path) != document["source_manifest_sha256"]:
        raise RigError("The exact reviewed benchmark changed")
    original_gltf, binary, original = read_glb(source)
    if document["bone_names"] != [original_gltf["nodes"][index]["name"] for index in original_gltf["skins"][0]["joints"]]:
        raise RigError("The exact retained source bone names changed")
    gltf = copy.deepcopy(original_gltf)
    original_binary = binary
    source_rows = {(row["mesh"], row["primitive"]): row for row in rows(gltf, binary)}
    changed = {}
    identities,counts = set(),{}
    for change in document["changes"]:
        key = change["mesh"], change["primitive"]
        if key not in source_rows:
            raise RigError("The reviewed vertex is not on an original source surface")
        row, vertex = source_rows[key], change["vertex"]
        if not isinstance(vertex,int) or not 0 <= vertex < len(row["values"]["POSITION"]):
            raise RigError("The reviewed original vertex index is invalid")
        identity = key + (vertex,)
        if identity in identities:
            raise RigError("A source vertex is changed twice")
        identities.add(identity)
        if list(row["values"]["JOINTS_0"][vertex]) != change["old_joints"] or list(row["values"]["WEIGHTS_0"][vertex]) != change["old_weights"]:
            raise RigError("Source vertex influences no longer match the reviewed ledger")
        if not np.allclose(row["game_points"][vertex], change["game_position"], rtol=0, atol=1e-10) or list(row["values"]["TEXCOORD_0"][vertex]) != change["uv"]:
            raise RigError("The explicitly reviewed vertex position/UV changed")
        regions = [r for r in document["regions"] if r["mesh"] == row["mesh_name"] and region_amount(row["game_points"][vertex],r)>1e-4]
        if len(regions)!=1 or change["mesh_name"]!=row["mesh_name"] or change["region"]!=regions[0]["name"] or change["target"]!=regions[0]["target"]:
            raise RigError("A changed vertex is outside its exact reviewed anatomical domain")
        expected = vertex_proposal(change["old_joints"],change["old_weights"],document["bone_names"],row["game_points"][vertex],regions[0])
        if expected is None or any(change.get(key,"arms" if key=="transfer" else None)!=value for key,value in expected.items()):
            raise RigError("The reviewed change does not match the selected source influences")
        counts[change["region"]]=counts.get(change["region"],0)+1
        if key not in changed:
            changed[key] = {attribute: list(row["values"][attribute]) for attribute in ("JOINTS_0", "WEIGHTS_0")}
        changed[key]["JOINTS_0"][vertex] = change["new_joints"]
        changed[key]["WEIGHTS_0"][vertex] = change["new_weights"]
    if not changed:
        raise RigError("No explicitly reviewed skin changes")
    if counts!=document["region_counts"]:
        raise RigError("Reviewed vertex counts disagree with the exact change ledger")
    for (mesh, primitive), values in changed.items():
        for attribute, component, fmt in (("JOINTS_0", 5123, "H"), ("WEIGHTS_0", 5126, "f")):
            accessor, binary = append_array(gltf, binary, values[attribute], fmt, component, "VEC4")
            gltf["meshes"][mesh]["primitives"][primitive]["attributes"][attribute] = accessor
    gltf["buffers"][0]["byteLength"] = len(binary)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest.update(rig_origin="corrected_preserved_source_skin_proxy_candidate",
        original_mesh_skin_accessors_binary_images_materials_preserved=False,
        original_geometry_uv_normals_material_images_preserved=True, original_source_weights_exact=False,
        original_binary_prefix_preserved=True, weight_correction_plan=str(plan_path),
        weight_correction_plan_sha256=sha(plan_path), original_benchmark_skin=str(source),
        original_benchmark_skin_sha256=sha(source), changed_skin_vertices=len(identities),
        weight_correction_regions=document["region_counts"], output=str(output), rig_ready_for_game=False)
    manifest.pop("output_sha256", None)
    gltf.setdefault("extras", {})["HHC_PreservedSkinCandidate"] = manifest
    output.parent.mkdir(parents=True, exist_ok=True)
    write_glb(output, gltf, binary)
    checked, actual_binary, _ = read_glb(output)
    if actual_binary[:len(original_binary)] != original_binary or source.read_bytes() != original:
        raise RigError("An original binary byte or benchmark file changed")
    for key in ("nodes", "skins", "materials", "textures", "images", "animations"):
        if checked.get(key) != original_gltf.get(key):
            raise RigError("Original rest hierarchy, bind, material or texture metadata changed")
    for row in source_rows.values():
        primitive = checked["meshes"][row["mesh"]]["primitives"][row["primitive"]]
        for attribute, accessor in row["definition"]["attributes"].items():
            if attribute not in ("JOINTS_0", "WEIGHTS_0") and primitive["attributes"][attribute] != accessor:
                raise RigError("An original static attribute changed")
        if primitive["indices"] != row["definition"]["indices"] or primitive["material"] != row["definition"]["material"]:
            raise RigError("An original triangle or material assignment changed")
    for old, actual in zip(original_gltf["images"], checked["images"]):
        if image_bytes(original_gltf, original_binary, old) != image_bytes(checked, actual_binary, actual):
            raise RigError("Original PNG bytes changed")
    manifest.update(output=str(output), output_sha256=sha(output), source_file_unchanged=True)
    output.with_suffix(".skin.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    proposal = commands.add_parser("plan")
    proposal.add_argument("manifest", type=Path)
    proposal.add_argument("name", choices=REGIONS)
    proposal.add_argument("output", type=Path)
    execute = commands.add_parser("apply")
    execute.add_argument("plan", type=Path)
    execute.add_argument("output", type=Path)
    execute.add_argument("--reviewed", action="store_true")
    args = parser.parse_args()
    result = plan(args.manifest, args.name, args.output) if args.command == "plan" else apply(args.plan, args.output, args.reviewed)
    print(json.dumps({key:result[key] for key in ("region_counts", "region_review_complete") if key in result}
        or {"output":result["output"],"changed_vertices":result["changed_skin_vertices"],"rig_ready_for_game":False}))


if __name__ == "__main__":
    main()
