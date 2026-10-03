"""Plan/apply narrowly scoped facial skin repairs; no Studio or API calls.

Approved original facial UV triangle signatures identify the scope. The initial
policy removes arm/shoulder influences. The measured Head/neck policy also fixes
incorrect neck mixing above Head while preserving a narrow anatomical transition.
All original geometry/UV/PNG/rest matrices and binary bytes remain untouched;
new four-slot skin arrays are appended to a separate unregistered build copy.
"""
from __future__ import annotations

import argparse
import copy
import json
from collections import deque
from pathlib import Path
import struct

import numpy as np

from constraints import RigError
from correct_skin_weights import append_array, rows, sha
from glb_io import image_bytes, read_glb, write_glb
from preserve_skin import ROOT

BAD = {side + part for side in ("Left", "Right") for part in ("UpperArm", "LowerArm", "Hand")}
BAD |= {"Aux_leftshoulder", "Aux_rightshoulder"}
HEAD_NECK = {"Head", "Aux_neck", "UpperTorso"}


def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def build_output(path):
    path = Path(path).resolve()
    if path.exists() or ROOT / "build" not in path.parents:
        raise RigError("Use a new output inside build/; original and prepared sources are read only")
    return path


def uv_key(corners):
    return tuple(sorted((round(float(u), 6), round(1 - float(v), 6)) for u, v in corners))


def original_influences(joints, weights, names):
    if len(joints) != 4 or len(weights) != 4 or any(not np.isfinite(w) or w < 0 for w in weights):
        raise RigError("Exactly four finite original influences are required")
    if any(not isinstance(i, int) or isinstance(i, bool) or not 0 <= i < len(names) for i in joints):
        raise RigError("An original source joint index is invalid")
    original = {}
    for i, w in zip(joints, weights):
        if w > 0:
            original[i] = original.get(i, 0.) + w
    if not original or not np.isfinite(sum(original.values())):
        raise RigError("A finite positive original skin weight sum is required")
    if abs(sum(original.values()) - 1.) > 1e-4:
        raise RigError("The reviewed original skin influences must be normalized")
    return original


def redistribute(joints, weights, names):
    original = original_influences(joints, weights, names)
    bad_mass = sum(w for i, w in original.items() if names[i] in BAD)
    if bad_mass <= 1e-8:
        return None
    good_mass = sum(w for i, w in original.items() if names[i] in HEAD_NECK)
    if good_mass <= 1e-8 or not any(names[i] == "Head" and w > 1e-8 for i, w in original.items()):
        raise RigError("Reviewed face has no existing Head/neck basis; do not invent a target")
    corrected = [(i, w * (1 + bad_mass / good_mass) if names[i] in HEAD_NECK else w)
                 for i, w in original.items() if names[i] not in BAD]
    if len(corrected) > 4:
        raise RigError("No unrelated influence may be discarded")
    while len(corrected) < 4:
        corrected.append((0, 0.))
    new_joints = [i for i, _ in corrected]
    new_weights = list(struct.unpack("<4f", struct.pack("<4f", *(w for _, w in corrected))))
    if abs(sum(new_weights) - sum(weights)) > 1e-6:
        raise RigError("Facial correction changed the original weight sum")
    return {"new_joints": new_joints, "new_weights": new_weights, "removed_arm_shoulder_weight": bad_mass,
            "existing_head_neck_weight": good_mass}


def anchored_redirect(joints, weights, names, point, anchor, connected_basis=False):
    """Approved facial surface above the measured neck anchor follows Head.

    Keep the existing neck mix below Head. One fifth of the measured Head-to-
    Aux_neck distance provides a continuous transition, rather than flattening
    vertices or extending a skin edit into the unreviewed neck/hair/garment.
    """
    point = np.asarray(point, dtype=float)
    head_position = np.asarray(anchor["head_position"], dtype=float)
    band = anchor["transition_band"]
    if (point.shape != (3,) or head_position.shape != (3,) or
            not np.isfinite(point).all() or not np.isfinite(head_position).all() or
            not np.isfinite(band) or band <= 0):
        raise RigError("Finite measured positions and a positive transition band are required")
    original = original_influences(joints, weights, names)
    amount = float(np.clip((point[1] - head_position[1]) / band, 0, 1))
    amount = amount * amount * (3 - 2 * amount)
    has_head = any(names[i] == "Head" and w > 1e-8 for i, w in original.items())
    if not has_head and any(names[i] in BAD for i in original):
        if not connected_basis or point[1] < head_position[1]:
            raise RigError("A missing original Head basis needs an explicitly reviewed connected above-joint surface")
        # Some original head/hair corners were wrongly bound entirely to an arm.
        # Their source triangles and measured anatomical joint, not a guessed
        # original influence, establish Head/Aux_neck on this reviewed surface.
        head, neck = names.index("Head"), names.index("Aux_neck")
        total = sum(weights)
        replacement = [total * amount, total * (1 - amount), 0., 0.]
        replacement = list(struct.unpack("<4f", struct.pack("<4f", *replacement)))
        if abs(sum(replacement) - total) > 1e-6:
            raise RigError("Connected Head/neck repair changed the original weight sum")
        return {"new_joints": [head, neck, 0, 0], "new_weights": replacement,
                "removed_arm_shoulder_weight": sum(w for i, w in original.items() if names[i] in BAD),
                "existing_head_neck_weight": sum(w for i, w in original.items() if names[i] in HEAD_NECK),
                "measured_head_transition_fraction": amount,
                "target_basis": "reviewed original above-joint connected anatomical head surface; original arm-only basis was invalid"}
    cleaned = redistribute(joints, weights, names)
    new_joints = cleaned["new_joints"] if cleaned else joints
    new_weights = cleaned["new_weights"] if cleaned else weights
    head = names.index("Head")
    values = {}
    for i, w in zip(new_joints, new_weights):
        if w > 0:
            values[i] = values.get(i, 0.) + w * (1 - amount)
    values[head] = values.get(head, 0.) + sum(weights) * amount
    values = {i: w for i, w in values.items() if w > 0}
    if len(values) > 4:
        raise RigError("Head transition cannot discard an unrelated original influence")
    pairs = list(values.items())
    while len(pairs) < 4:
        pairs.append((0, 0.))
    target_joints = [i for i, _ in pairs]
    target_weights = list(struct.unpack("<4f", struct.pack("<4f", *(w for _, w in pairs))))
    old = {}
    for i, w in zip(joints, weights):
        if w > 0:
            old[i] = old.get(i, 0.) + float(w)
    actual = {i: float(w) for i, w in zip(target_joints, target_weights) if w > 0}
    if old == actual:
        return None
    if abs(sum(target_weights) - sum(weights)) > 1e-6:
        raise RigError("Measured Head transition changed the original weight sum")
    return {"new_joints": target_joints, "new_weights": target_weights,
            "removed_arm_shoulder_weight": sum(w for i, w in zip(joints, weights) if names[i] in BAD),
            "existing_head_neck_weight": sum(w for i, w in zip(joints, weights) if names[i] in HEAD_NECK),
            "measured_head_transition_fraction": amount}


def coincident_key(row, vertex, names):
    values = row["values"]
    # Exact transformed position and influence values, not proximity, color,
    # material-wide ownership or a guessed anatomical box.
    influence = tuple(sorted((names[i], float(w)) for i, w in
                            zip(values["JOINTS_0"][vertex], values["WEIGHTS_0"][vertex]) if w > 0))
    return tuple(row["game_points"][vertex]), influence


def connected_head_surface(source_rows, gltf, binary, face_vertices, head_y):
    """Follow original surface edges, seeded by the proven approved face.

    Exact positional duplicates weld UV seams. Edges may not cross the actual
    Head joint's Y plane, so this is not a material-wide reassignment. The plan
    still requires direct front/side region review before any derived copy.
    """
    graph, seeds = {}, set()
    for row in source_rows:
        if row["mesh_name"] != "CostumeSkinHead":
            continue
        points = row["game_points"]
        seeds.update(tuple(points[v]) for mesh, primitive, v in face_vertices
                     if (row["mesh"], row["primitive"]) == (mesh, primitive) and points[v][1] >= head_y)
        triangles = np.asarray(accessor_values_local(gltf, binary, row["definition"]["indices"]), dtype=int).reshape(-1, 3)
        for triangle in triangles:
            for a, b in ((triangle[0], triangle[1]), (triangle[1], triangle[2]), (triangle[2], triangle[0])):
                if points[a][1] < head_y or points[b][1] < head_y:
                    continue
                pa, pb = tuple(points[a]), tuple(points[b])
                graph.setdefault(pa, set()).add(pb)
                graph.setdefault(pb, set()).add(pa)
    if not seeds:
        raise RigError("The approved face has no vertex above the measured Head joint")
    reached, queue = set(seeds), deque(sorted(seeds))
    while queue:
        for point in sorted(graph.get(queue.popleft(), ())):
            if point not in reached:
                reached.add(point)
                queue.append(point)
    return reached, {"seed_position_count": len(seeds), "connected_position_count": len(reached),
                     "minimum_game_y": head_y, "source_surface": "CostumeSkinHead",
                     "connectivity": "original triangle edges and exactly equal source positions; no proximity threshold",
                     "bound_min": np.min(list(reached), axis=0).tolist(),
                     "bound_max": np.max(list(reached), axis=0).tolist()}


def proposal(manifest_path, report_path, policy="arms-proportional"):
    manifest_path, report_path = Path(manifest_path).resolve(), Path(report_path).resolve()
    manifest, report = load(manifest_path), load(report_path)
    if manifest.get("rig_origin") not in ("preserved_source_skin_proxy_candidate", "corrected_preserved_source_skin_proxy_candidate") or manifest.get("rig_ready_for_game") is not False:
        raise RigError("An unregistered original or expressly corrected source skin is required")
    source = Path(manifest["output"])
    if sha(source) != manifest["output_sha256"]:
        raise RigError("The source skin changed")
    proof = report["preserved_skin_coordinate_proof"]
    if proof["skin_sha256"] != sha(source) or report.get("original_sources_unchanged") is not True:
        raise RigError("Facial scope is not proven against this exact source skin")
    if proof["source_sidecar_sha256"] != sha(manifest_path):
        raise RigError("Facial source hierarchy/proxy metadata changed")
    if proof["source_skin_bones"] != 23 or proof["maximum_coordinate_error"] > 1e-5:
        raise RigError("Exact original 23-bone/UV coordinate proof is required")
    gltf, binary, _ = read_glb(source)
    indices = gltf["skins"][0]["joints"]
    names = [gltf["nodes"][i]["name"] for i in indices]
    if len(indices) != 23 or len(set(names)) != 23:
        raise RigError("Keep every principal and auxiliary source bone")
    if not {"Head", "Aux_neck"}.issubset(names):
        raise RigError("The retained anatomical Head and auxiliary neck are required")
    if policy not in ("arms-proportional", "head-neck-anchored", "head-surface-connected"):
        raise RigError("Unknown facial correction policy")
    anchor = None
    if policy in ("head-neck-anchored", "head-surface-connected"):
        bone_lookup = {b["name"]: b for b in manifest["bones"]}
        head = np.asarray(bone_lookup["Head"]["game_bind_world"]).reshape(4, 4).T[:3, 3]
        neck = np.asarray(bone_lookup["Aux_neck"]["game_bind_world"]).reshape(4, 4).T[:3, 3]
        length = float(np.linalg.norm(head - neck))
        if not np.isfinite(length) or length <= 1e-5:
            raise RigError("Measured source Head/neck anchors are degenerate")
        anchor = {"head_position": head.tolist(), "neck_position": neck.tolist(),
                  "measured_head_neck_distance": length, "transition_band": length * .2,
                  "coordinate_frame": "the existing canonical game Y-up source bind"}
    source_rows = rows(gltf, binary)
    wanted = {tuple(tuple(pair) for pair in signature) for signature in report["original_facial_uv_signatures"]}
    if not wanted:
        raise RigError("No approved original facial scope")
    found, face_vertices, face_triangles = set(), set(), []
    for row in source_rows:
        if row["mesh_name"] != "CostumeSkinHead":
            continue
        triangles = np.asarray(accessor_values_local(gltf, binary, row["definition"]["indices"]), dtype=int).reshape(-1, 3)
        for triangle_index, triangle in enumerate(triangles):
            key = uv_key(np.asarray(row["values"]["TEXCOORD_0"])[triangle])
            if key not in wanted:
                continue
            if key in found:
                raise RigError("Ambiguous original facial triangle")
            found.add(key)
            face_triangles.append({"mesh": row["mesh"], "primitive": row["primitive"],
                                   "triangle": triangle_index, "vertices": triangle.tolist(), "uv_signature": key})
            face_vertices.update((row["mesh"], row["primitive"], int(v)) for v in triangle)
    if found != wanted:
        raise RigError("An approved facial UV triangle is absent from the original source")
    face_keys = {coincident_key(row, v, names) for row in source_rows
                 for mesh, primitive, v in face_vertices if (row["mesh"], row["primitive"]) == (mesh, primitive)}
    connected, connectivity_proof = set(), None
    if policy == "head-surface-connected":
        connected, connectivity_proof = connected_head_surface(source_rows, gltf, binary, face_vertices,
                                                               anchor["head_position"][1])
    changes, counts = [], {"approved_face_vertices": 0, "exact_coincident_source_copies": 0}
    if connectivity_proof:
        counts["reviewed_connected_head_surface"] = 0
    for row in source_rows:
        used = {int(v) for v in np.asarray(accessor_values_local(gltf, binary, row["definition"]["indices"])).reshape(-1)}
        for vertex in sorted(used):
            identity = row["mesh"], row["primitive"], vertex
            direct = identity in face_vertices
            top_surface = tuple(row["game_points"][vertex]) in connected
            if not direct and not top_surface and coincident_key(row, vertex, names) not in face_keys:
                continue
            values = row["values"]
            old_joints, old_weights = list(values["JOINTS_0"][vertex]), list(values["WEIGHTS_0"][vertex])
            change = (anchored_redirect(old_joints, old_weights, names, row["game_points"][vertex], anchor,
                                       connected_basis=top_surface)
                      if anchor else redistribute(old_joints, old_weights, names))
            if change is None:
                continue
            region = ("approved_face_vertices" if direct else
                      "reviewed_connected_head_surface" if top_surface else "exact_coincident_source_copies")
            counts[region] += 1
            changes.append({"mesh": row["mesh"], "mesh_name": row["mesh_name"], "primitive": row["primitive"],
                            "vertex": vertex, "game_position": row["game_points"][vertex].tolist(),
                            "uv": list(values["TEXCOORD_0"][vertex]), "region": region,
                            "target": "measured_head_neck_transition" if connectivity_proof else "existing_head_neck_proportions", "old_joints": old_joints,
                            "old_weights": old_weights, **change})
    if not changes:
        raise RigError("No inappropriate original arm/shoulder influence in the reviewed face scope")
    result = {"schema": 1, "source_skin": str(source), "source_skin_sha256": sha(source),
            "source_manifest": str(manifest_path), "source_manifest_sha256": sha(manifest_path),
            "facial_scope_report": str(report_path), "facial_scope_report_sha256": sha(report_path),
            "bone_names": names, "original_facial_triangles": face_triangles, "region_counts": counts,
            "changes": changes, "policy": "Remove only arm/auxiliary-shoulder influence; preserve original Head/neck ratio and all other influences",
            "region_review_complete": False, "original_geometry_uv_normals_material_images_unchanged": True,
            "rig_ready_for_game": False, "api_calls": 0, "studio_calls": 0}
    if anchor:
        result.update(policy_name=policy, measured_head_neck_anchor=anchor,
                      policy="Approved facial surface above measured Head follows Head; retain source neck mixture below it with a narrow measured transition")
    if connectivity_proof:
        result.update(connected_head_surface_proof=connectivity_proof,
                      policy="Approved face plus reviewed connected original Head surface above the actual joint follows the measured Head/neck transition")
    return result


def accessor_values_local(gltf, binary, accessor):
    from glb_io import accessor_values
    return accessor_values(gltf, binary, accessor)


def apply(plan_path, output, reviewed):
    plan_path, output = Path(plan_path).resolve(), build_output(output)
    if output.with_suffix(".skin.json").exists():
        raise RigError("The output sidecar already exists")
    document = load(plan_path)
    if not reviewed or document.get("region_review_complete") is not True or not document.get("reviewed_overlay_images"):
        raise RigError("Inspect exact selected facial vertices before applying a new copy")
    for image in document["reviewed_overlay_images"]:
        if sha(image["path"]) != image["sha256"]:
            raise RigError("A reviewed diagnostic image changed")
    expected = proposal(document["source_manifest"], document["facial_scope_report"], document.get("policy_name", "arms-proportional"))
    for key, value in expected.items():
        if key != "region_review_complete" and document.get(key) != json.loads(json.dumps(value)):
            raise RigError("Reviewed facial proposal changed: " + key)
    source = Path(document["source_skin"])
    original_gltf, original_binary, original_bytes = read_glb(source)
    gltf, binary = copy.deepcopy(original_gltf), original_binary
    changed = {}
    for change in document["changes"]:
        key = change["mesh"], change["primitive"]
        if key not in changed:
            primitive = gltf["meshes"][key[0]]["primitives"][key[1]]
            changed[key] = {attr: list(accessor_values_local(gltf, binary, primitive["attributes"][attr]))
                            for attr in ("JOINTS_0", "WEIGHTS_0")}
        changed[key]["JOINTS_0"][change["vertex"]] = change["new_joints"]
        changed[key]["WEIGHTS_0"][change["vertex"]] = change["new_weights"]
    for (mesh, primitive), attributes in changed.items():
        for attribute, component, fmt in (("JOINTS_0", 5123, "H"), ("WEIGHTS_0", 5126, "f")):
            accessor, binary = append_array(gltf, binary, attributes[attribute], fmt, component, "VEC4")
            gltf["meshes"][mesh]["primitives"][primitive]["attributes"][attribute] = accessor
    manifest = load(document["source_manifest"])
    parent_sha = sha(source)
    previous_plan = manifest.get("weight_correction_plan")
    previous_plan_sha = manifest.get("weight_correction_plan_sha256")
    baseline = manifest.get("original_benchmark_skin", str(source))
    baseline_sha = manifest.get("original_benchmark_skin_sha256", parent_sha)
    total_changes = manifest.get("changed_skin_vertices", 0) + len(document["changes"])
    all_regions = {**manifest.get("weight_correction_regions", {}), **document["region_counts"]}
    chain = manifest.get("weight_correction_chain", [])
    if previous_plan and not chain:
        chain = [{"path": previous_plan, "sha256": previous_plan_sha, "output_skin_sha256": parent_sha}]
    chain = chain + [{"path": str(plan_path), "sha256": sha(plan_path), "kind": "approved_face_head_neck_only"}]
    manifest.update(rig_origin="corrected_preserved_source_skin_proxy_candidate",
                    original_mesh_skin_accessors_binary_images_materials_preserved=False,
                    original_geometry_uv_normals_material_images_preserved=True, original_source_weights_exact=False,
                    original_binary_prefix_preserved=True, weight_correction_plan=str(plan_path),
                    weight_correction_plan_sha256=sha(plan_path), weight_correction_chain=chain,
                    original_benchmark_skin=baseline, original_benchmark_skin_sha256=baseline_sha,
                    parent_correction_skin=str(source), parent_correction_skin_sha256=parent_sha,
                    changed_facial_vertices=len(document["changes"]), changed_skin_vertices=total_changes,
                    changed_skin_vertices_this_stage=len(document["changes"]),
                    weight_correction_regions=all_regions, weight_correction_regions_this_stage=document["region_counts"],
                    output=str(output), rig_ready_for_game=False, studio_motion_validated=False)
    manifest.pop("output_sha256", None)
    gltf["buffers"][0]["byteLength"] = len(binary)
    gltf.setdefault("extras", {})["HHC_PreservedSkinCandidate"] = manifest
    output.parent.mkdir(parents=True, exist_ok=True)
    write_glb(output, gltf, binary)
    checked, actual_binary, _ = read_glb(output)
    if actual_binary[:len(original_binary)] != original_binary or source.read_bytes() != original_bytes:
        raise RigError("An original binary or source byte changed")
    for key in ("nodes", "skins", "materials", "textures", "images", "animations"):
        if checked.get(key) != original_gltf.get(key):
            raise RigError("Original hierarchy/rest/bind/material/image metadata changed")
    for mi, mesh in enumerate(original_gltf["meshes"]):
        for pi, old in enumerate(mesh["primitives"]):
            actual = checked["meshes"][mi]["primitives"][pi]
            for attribute, index in old["attributes"].items():
                if attribute not in ("JOINTS_0", "WEIGHTS_0") and actual["attributes"][attribute] != index:
                    raise RigError("A static original accessor changed")
            if old["indices"] != actual["indices"] or old["material"] != actual["material"]:
                raise RigError("An original surface or triangle changed")
            for attribute in ("JOINTS_0", "WEIGHTS_0"):
                actual_values = accessor_values_local(checked, actual_binary, actual["attributes"][attribute])
                expected_values = changed.get((mi, pi), {}).get(attribute,
                    accessor_values_local(original_gltf, original_binary, old["attributes"][attribute]))
                if [list(v) for v in actual_values] != [list(v) for v in expected_values]:
                    raise RigError("An unreviewed original influence changed")
    for old, actual in zip(original_gltf["images"], checked["images"]):
        if image_bytes(original_gltf, original_binary, old) != image_bytes(checked, actual_binary, actual):
            raise RigError("An original embedded texture byte changed")
    manifest.update(output_sha256=sha(output), source_file_unchanged=True)
    output.with_suffix(".skin.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    command = commands.add_parser("plan")
    command.add_argument("manifest", type=Path)
    command.add_argument("scope_report", type=Path)
    command.add_argument("output", type=Path)
    command.add_argument("--policy", choices=("arms-proportional", "head-neck-anchored", "head-surface-connected"), default="arms-proportional")
    execute = commands.add_parser("apply")
    execute.add_argument("plan", type=Path)
    execute.add_argument("output", type=Path)
    execute.add_argument("--reviewed", action="store_true")
    commands.add_parser("self-test", help="Check target proportions, unrelated influence retention, and invalid input rejection")
    args = parser.parse_args()
    if args.command == "self-test":
        names = ["Root", "Head", "Aux_neck", "UpperTorso", "LeftUpperArm", "Aux_rightshoulder", "Aux_spine"]
        result = redistribute([1, 2, 4, 6], [.2, .3, .4, .1], names)
        actual = {names[i]: w for i, w in zip(result["new_joints"], result["new_weights"]) if w > 0}
        assert set(actual) == {"Head", "Aux_neck", "Aux_spine"}
        assert abs(sum(actual.values()) - 1) < 1e-6
        assert abs(actual["Aux_spine"] - .1) < 1e-6
        assert abs(actual["Head"] / actual["Aux_neck"] - 2/3) < 1e-6
        assert result["removed_arm_shoulder_weight"] == .4
        result = redistribute([1, 2, 5, 0], [.2, .3, .5, 0], names)
        assert result["new_joints"][:2] == [1, 2]
        assert np.allclose(result["new_weights"], [.4, .6, 0, 0])
        assert redistribute([1, 0, 0, 0], [1., 0, 0, 0], names) is None
        invalid = [([1, 2, 4], [.2, .3, .5]), ([1, 2, 4, 0], [.2, .3, float("nan"), 0]),
                   ([1, 2, 4, 0], [.2, -.3, 1.1, 0]), ([1, 2, 99, 0], [.2, .3, .5, 0]),
                   ([True, 2, 4, 0], [.2, .3, .5, 0]), ([0, 0, 4, 0], [.2, .3, .5, 0]),
                   ([1, 2, 4, 0], [0., 0., 0., 0.]), ([1, 2, 4, 0], [.2, .3, .9, 0.])]
        for joints, weights in invalid:
            try:
                redistribute(joints, weights, names)
            except RigError:
                continue
            raise AssertionError("Invalid original face weights accepted")
        anchor = {"head_position": [0, 1, 0], "transition_band": .05}
        for point, wanted in (([0, 1.1, 0], 1), ([0, 1, 0], .36), ([0, 1.025, 0], .68)):
            result = anchored_redirect([1, 2, 4, 6], [.2, .3, .4, .1], names, point, anchor)
            values = {names[i]: w for i, w in zip(result["new_joints"], result["new_weights"]) if w > 0}
            assert abs(values["Head"] - wanted) < 1e-6
            assert abs(sum(values.values()) - 1) < 1e-6
        assert anchored_redirect([1, 0, 0, 0], [1., 0, 0, 0], names, [0, 1.1, 0], anchor) is None
        arm_only = anchored_redirect([4, 5, 0, 0], [.4, .6, 0, 0], names, [0, 1.1, 0], anchor, connected_basis=True)
        assert arm_only["new_weights"] == [1., 0., 0., 0.]
        half = anchored_redirect([4, 5, 0, 0], [.4, .6, 0, 0], names, [0, 1.025, 0], anchor, connected_basis=True)
        assert np.allclose(half["new_weights"], [.5, .5, 0, 0])
        for point, permission in (([0, 1.1, 0], False), ([0, .9, 0], True)):
            try:
                anchored_redirect([4, 5, 0, 0], [.4, .6, 0, 0], names, point, anchor, connected_basis=permission)
            except RigError:
                continue
            raise AssertionError("An unreviewed/misplaced arm-only source invented a Head basis")
        bad_anchors = [([0, float("nan"), 0], anchor), ([0, 1], anchor),
                       ([0, 1, 0], {"head_position": [0, float("inf"), 0], "transition_band": .05}),
                       ([0, 1, 0], {"head_position": [0, 1, 0], "transition_band": 0}),
                       ([0, 1, 0], {"head_position": [0, 1, 0], "transition_band": -.05}),
                       ([0, 1, 0], {"head_position": [0, 1, 0], "transition_band": float("nan")})]
        for point, invalid_anchor in bad_anchors:
            try:
                anchored_redirect([1, 2, 4, 6], [.2, .3, .4, .1], names, point, invalid_anchor)
            except RigError:
                continue
            raise AssertionError("Invalid measured Head transition accepted")
        points = np.asarray([[0, 2, 0], [1, 2, 0], [1, 1.5, 0], [0, .5, 0], [4, .5, 0],
                             [10, 2, 0], [11, 2, 0], [12, 2, 0]], dtype=float)
        blob = struct.pack("<12H", 0, 1, 2, 2, 3, 4, 5, 6, 7, 0, 1, 2)
        fixture = {"buffers": [{"byteLength": len(blob)}],
                   "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": 18},
                                   {"buffer": 0, "byteOffset": 18, "byteLength": 6}],
                   "accessors": [{"bufferView": 0, "componentType": 5123, "type": "SCALAR", "count": 9},
                                 {"bufferView": 1, "componentType": 5123, "type": "SCALAR", "count": 3}]}
        surfaces = [{"mesh_name": "CostumeSkinHead", "mesh": 0, "primitive": 0,
                     "game_points": points, "definition": {"indices": 0}},
                    {"mesh_name": "CostumeSkinHead", "mesh": 0, "primitive": 1,
                     "game_points": np.asarray([[0, 2, 0], [2, 3, 0], [2.1, 2.6, 0]]),
                     "definition": {"indices": 1}}]
        actual, proof = connected_head_surface(surfaces, fixture, blob, {(0, 0, 0)}, 1.)
        assert len(actual) == 5 and proof["connected_position_count"] == 5
        assert tuple(points[3]) not in actual and tuple(points[4]) not in actual
        assert tuple(points[5]) not in actual
        assert (2., 3., 0.) in actual  # Exact positional UV seam, different primitive.
        try:
            connected_head_surface(surfaces, fixture, blob, {(0, 0, 3)}, 1.)
        except RigError:
            pass
        else:
            raise AssertionError("A below-plane seed invented a connected head scope")
        print(json.dumps({"checks": 38, "passed": True, "studio_calls": 0, "api_calls": 0}))
    elif args.command == "plan":
        output = build_output(args.output)
        result = proposal(args.manifest, args.scope_report, args.policy)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"changes": len(result["changes"]), "scope_triangles": len(result["original_facial_triangles"]),
                          "regions": result["region_counts"], "ready": False}))
    else:
        result = apply(args.plan, args.output, args.reviewed)
        print(json.dumps({"changed_facial_vertices": result["changed_facial_vertices"], "ready": False}))


if __name__ == "__main__":
    main()
