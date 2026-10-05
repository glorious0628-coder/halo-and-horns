# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Bind approved static triangles to explicit inferred R15 landmarks offline.

The JSON supplies every original face owner and all 15 inferred joint positions.
This tool does not guess positions, design an avatar, alter any surface, upload,
or mark it playable. Original corner attributes/materials/images are retained.
"""
from __future__ import annotations

raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
from collections import Counter
import copy
import hashlib
import json
import math
from pathlib import Path
import re
import struct

from constraints import JOINTS, PARENTS, PRIMARY, RigError
from glb_io import image_bytes, read_glb, write_glb
from restore_material_regions import append_accessor, append_view, oriented_key, primitives


ROOT = Path(__file__).resolve().parents[2]


def face_counter(rows):
    result = Counter()
    for row in rows:
        material = row["definition"]["material"]
        for triangle in row["triangles"]:
            corners = tuple(tuple((name, row["values"][name][vertex]) for name in sorted(row["values"])) for vertex in triangle)
            result[(material, oriented_key(corners))] += 1
    return result


def validate_config(config, gltf, binary):
    if config.get("schema") != 1 or not re.fullmatch(r"Costume_[A-Za-z][A-Za-z0-9_]*", config.get("name", "")):
        raise RigError("A versioned named manual candidate is required")
    if config.get("coordinates") != "gltf_world_y_up" or config.get("rig_origin") != "inferred_manual_candidate" or config.get("rig_ready_for_game") is not False:
        raise RigError("Manual joints must be explicitly inferred and not game-ready")
    if gltf.get("skins") or gltf.get("animations"):
        raise RigError("Manual binding accepts only the unchanged static source")
    landmarks = config.get("landmarks", {})
    evidence = config.get("landmark_evidence", {})
    if set(landmarks) != set(PRIMARY) or set(evidence) != set(PRIMARY):
        raise RigError("All 15 manual landmarks and geometric evidence are required")
    for part, value in landmarks.items():
        if len(value) != 3 or any(not isinstance(axis, (int, float)) or not math.isfinite(axis) for axis in value) or not isinstance(evidence[part], str) or len(evidence[part]) < 12:
            raise RigError("Every inferred landmark needs finite actual coordinates and a reason")
    rows = primitives(gltf, binary, False)
    owners = {}
    for item in config.get("triangle_owners", []):
        key = (item["mesh"], item["primitive"])
        if key in owners:
            raise RigError("A source primitive is assigned twice")
        owners[key] = item["owners"]
    if set(owners) != {(row["mesh"], row["primitive"]) for row in rows}:
        raise RigError("Every original mesh primitive must be explicitly assigned")
    counts = Counter()
    for row in rows:
        selected = owners[(row["mesh"], row["primitive"])]
        if len(selected) != len(row["triangles"]) or any(owner not in PRIMARY for owner in selected):
            raise RigError("Each original triangle needs exactly one valid R15 owner")
        counts.update(selected)
    if set(counts) != set(PRIMARY):
        raise RigError("All 15 original surface regions must be nonempty")
    points = [point for row in rows for point in row["values"]["POSITION"]]
    lower = [min(point[axis] for point in points) for axis in range(3)]
    upper = [max(point[axis] for point in points) for axis in range(3)]
    height = upper[1] - lower[1]
    if height <= 1e-8:
        raise RigError("Zero-height source")
    for part, position in landmarks.items():
        if any(position[axis] < lower[axis] - height * .03 or position[axis] > upper[axis] + height * .03 for axis in range(3)):
            raise RigError("Inferred joint lies outside the measured original model")
        parent = PARENTS[part]
        if parent != "HumanoidRootPart" and math.dist(position, landmarks[parent]) < height * .001:
            raise RigError("Degenerate inferred parent/child joint positions")
    return rows, owners, counts


def bind(config_path, output):
    config_path, output = Path(config_path).resolve(), Path(output).resolve()
    config = json.loads(config_path.read_text(encoding="utf-8"))
    source = Path(config["source"])
    if not source.is_absolute():
        source = ROOT / source
    source = source.resolve()
    gltf, binary, original = read_glb(source)
    if hashlib.sha256(original).hexdigest() != config["source_sha256"]:
        raise RigError("The selected original static source changed")
    if ROOT / "build" not in output.parents or output.exists() or output.with_suffix(".binding.json").exists():
        raise RigError("Manual candidate requires a new output and audit inside build/")
    rows, owners, counts = validate_config(config, gltf, binary)
    result, rebuilt = copy.deepcopy(gltf), binary
    parts = list(PRIMARY)
    bone_index = {part: index for index, part in enumerate(parts)}
    joint_start = len(result["nodes"])
    for part in parts:
        position = config["landmarks"][part]
        parent = PARENTS[part]
        local = position if parent == "HumanoidRootPart" else [position[axis] - config["landmarks"][parent][axis] for axis in range(3)]
        node = {"name": "mixamorig:" + PRIMARY[part], "translation": local,
                "extras": {"HHC_ManualInferredJoint": True, "HHC_ManualPart": part}}
        children = [joint_start + bone_index[child] for child in parts if PARENTS[child] == part]
        if children:
            node["children"] = children
        result["nodes"].append(node)
    inverse_matrices = []
    for part in parts:
        x, y, z = config["landmarks"][part]
        inverse_matrices.append((1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -x, -y, -z, 1))
    view, rebuilt = append_view(result, rebuilt, b"".join(struct.pack("<16f", *matrix) for matrix in inverse_matrices))
    inverse_accessor = len(result["accessors"])
    result["accessors"].append({"bufferView": view, "componentType": 5126, "count": 15, "type": "MAT4"})
    result["skins"] = [{"name": config["name"] + "_InferredManualSkin", "skeleton": joint_start + bone_index["LowerTorso"],
                        "joints": list(range(joint_start, joint_start + 15)), "inverseBindMatrices": inverse_accessor}]
    for row in rows:
        values = {name: [] for name in row["values"]}
        values["JOINTS_0"], values["WEIGHTS_0"] = [], []
        indices, shared = [], {}
        for triangle, owner in zip(row["triangles"], owners[(row["mesh"], row["primitive"])]):
            for vertex in triangle:
                key = (vertex, owner)
                if key not in shared:
                    shared[key] = len(shared)
                    for name in row["values"]:
                        values[name].append(row["values"][name][vertex])
                    values["JOINTS_0"].append((bone_index[owner], 0, 0, 0))
                    values["WEIGHTS_0"].append((1.0, 0.0, 0.0, 0.0))
                indices.append((shared[key],))
        primitive = copy.deepcopy(row["definition"])
        primitive["attributes"] = {}
        for name, array in values.items():
            if name in ("JOINTS_0", "WEIGHTS_0"):
                component, kind = (5123 if name == "JOINTS_0" else 5126), "VEC4"
            else:
                template = gltf["accessors"][row["definition"]["attributes"][name]]
                component, kind = template["componentType"], template["type"]
            accessor, rebuilt = append_accessor(result, rebuilt, array, component, kind, 34962)
            primitive["attributes"][name] = accessor
        primitive["indices"], rebuilt = append_accessor(result, rebuilt, indices, 5125, "SCALAR", 34963)
        result["meshes"][row["mesh"]]["primitives"][row["primitive"]] = primitive
        result["nodes"][row["node"]]["skin"] = 0
    root = len(result["nodes"])
    mesh_nodes = list(dict.fromkeys(row["node"] for row in rows))
    result["nodes"].append({"name": config["name"] + "_ManualCandidate", "children": mesh_nodes + [joint_start + bone_index["LowerTorso"]]})
    result["scenes"] = [{"name": "ManualCandidate", "nodes": [root]}]
    result["scene"] = 0
    result["buffers"][0]["byteLength"] = len(rebuilt)
    provenance = {"rig_origin": "inferred_manual_candidate", "original_bones_claimed": False,
        "landmark_config": str(config_path), "landmark_config_sha256": hashlib.sha256(config_path.read_bytes()).hexdigest(),
        "source": str(source), "source_sha256": config["source_sha256"], "rig_ready_for_game": False,
        "all_original_triangles_assigned_once": True, "surface_or_uv_design_changed": False}
    result.setdefault("extras", {})["HHC_ManualBind"] = provenance
    after = primitives(result, rebuilt, True)
    without_skin = []
    for row in after:
        item = copy.deepcopy(row)
        item["values"].pop("JOINTS_0")
        item["values"].pop("WEIGHTS_0")
        without_skin.append(item)
    if face_counter(rows) != face_counter(without_skin) or not rebuilt.startswith(binary):
        raise RigError("A manual candidate changed an original face/UV/normal/material")
    for old, new in zip(gltf.get("images", []), result.get("images", [])):
        if image_bytes(gltf, binary, old) != image_bytes(result, rebuilt, new):
            raise RigError("An original static image changed")
    output.parent.mkdir(parents=True, exist_ok=True)
    write_glb(output, result, rebuilt)
    report = dict(provenance, output=str(output), output_sha256=hashlib.sha256(output.read_bytes()).hexdigest(),
        original_triangles=sum(counts.values()), original_face_counts=dict(counts), skin_joints=15,
        original_corner_position_normal_uv_material_verified=True, original_image_bytes_preserved=True,
        source_file_unchanged=source.read_bytes() == original, studio_motion_validated=False, api_called=False)
    output.with_suffix(".binding.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    print(json.dumps(bind(args.config, args.output), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
