# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
# Still importable as a library ONLY because live tools import it (tools/monster_import_preflight.py,
# tools/test_weapon_motion.py, GLB audit tools). Never run it directly.
"""Restore lost static material/UV regions on a genuine rig, without new art.

Read-only by default. An explicit new build/ output creates a copy after every
source oriented triangle has a unique geometric match. Genuine rig positions,
skin weights, joints, bind matrices and animation data are retained. Original
reference UVs, corner normals, material regions and embedded images are restored.
No network, API calls, uploads, texture baking or source-file writes.
"""
from __future__ import annotations

if __name__ == "__main__":
    raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
from collections import Counter
import copy
import hashlib
import json
import math
from pathlib import Path
import struct

import numpy as np
from scipy.spatial import cKDTree

from constraints import RigError
from glb_io import accessor_values, image_bytes, read_glb, write_glb


ROOT = Path(__file__).resolve().parents[2]
FORMATS = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}
DIMENSIONS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def oriented_key(triangle):
    triangle = tuple(triangle)
    return min(triangle, triangle[1:] + triangle[:1], triangle[2:] + triangle[:2])


def identity_mesh_nodes(gltf, skinned):
    """Refuse unreviewed transforms rather than fitting them implicitly."""
    nodes = gltf.get("nodes", [])
    parents = {}
    for index, node in enumerate(nodes):
        for child in node.get("children", []):
            if child in parents:
                raise RigError("A node has multiple parents")
            parents[child] = index
    found = []
    for index, node in enumerate(nodes):
        if "mesh" not in node:
            continue
        if ("skin" in node) != skinned or node.get("weights"):
            raise RigError("Expected unchanged static reference / genuine skinned mesh")
        visited, current = set(), index
        while True:
            if current in visited:
                raise RigError("Node hierarchy has a cycle")
            visited.add(current)
            ancestor = nodes[current]
            if any(key in ancestor for key in ("matrix", "translation", "rotation", "scale")):
                raise RigError("Material recovery supports only verified identity mesh transforms")
            if current not in parents:
                break
            current = parents[current]
        found.append((index, node["mesh"]))
    if not found:
        raise RigError("No matching real mesh nodes")
    return found


def primitives(gltf, binary, skinned):
    rows = []
    for node, mesh_index in identity_mesh_nodes(gltf, skinned):
        for primitive_index, primitive in enumerate(gltf["meshes"][mesh_index]["primitives"]):
            if primitive.get("mode", 4) != 4 or primitive.get("targets") or primitive.get("extensions"):
                raise RigError("Only unchanged ordinary source triangles are supported")
            attributes = primitive["attributes"]
            if not {"POSITION", "NORMAL", "TEXCOORD_0"}.issubset(attributes):
                raise RigError("Original positions, normals and UVs are required")
            if skinned and not {"JOINTS_0", "WEIGHTS_0"}.issubset(attributes):
                raise RigError("Actual rig skin attributes are required")
            values = {name: accessor_values(gltf, binary, accessor) for name, accessor in attributes.items()}
            count = len(values["POSITION"])
            if any(len(array) != count for array in values.values()):
                raise RigError("Mismatched vertex attribute counts")
            if any(not math.isfinite(float(value)) for array in values.values() for row in array for value in row):
                raise RigError("Non-finite source vertex attribute")
            indices = [row[0] for row in accessor_values(gltf, binary, primitive["indices"])]
            if len(indices) % 3 or any(index < 0 or index >= count for index in indices):
                raise RigError("Invalid genuine source triangle indices")
            rows.append({"node": node, "mesh": mesh_index, "primitive": primitive_index,
                         "definition": primitive, "values": values,
                         "triangles": [tuple(indices[start:start + 3]) for start in range(0, len(indices), 3)]})
    return rows


def correspondence(reference_gltf, reference_binary, rig_gltf, rig_binary, tolerance=2e-6):
    source = primitives(reference_gltf, reference_binary, False)
    rig = primitives(rig_gltf, rig_binary, True)
    if len({row["mesh"] for row in rig}) != 1 or len(rig) != 1:
        raise RigError("This recovery is restricted to a single merged genuine rig primitive")
    reference_points = np.concatenate([np.array(row["values"]["POSITION"], dtype=float) for row in source])
    rig_points = np.array(rig[0]["values"]["POSITION"], dtype=float)
    unique, inverse = np.unique(reference_points, axis=0, return_inverse=True)
    source_range, rig_range = np.ptp(unique, axis=0), np.ptp(rig_points, axis=0)
    if min(source_range) < 1e-8 or min(rig_range) < 1e-8:
        raise RigError("Degenerate original shape")
    axis_scales = rig_range / source_range
    if max(axis_scales) - min(axis_scales) > 1e-5:
        raise RigError("A common original uniform scale cannot explain the real rig")
    scale = float(np.mean(axis_scales))
    translation = (rig_points.min(0) + rig_points.max(0)) / 2 - scale * (unique.min(0) + unique.max(0)) / 2
    distance, nearest = cKDTree(unique * scale + translation).query(rig_points)
    if float(distance.max()) > tolerance:
        raise RigError("Original shape does not match the actual rig within tolerance")
    matched = unique[nearest]
    centered_source = matched - matched.mean(0)
    centered_rig = rig_points - rig_points.mean(0)
    scale = float((centered_source * centered_rig).sum() / (centered_source * centered_source).sum())
    translation = rig_points.mean(0) - scale * matched.mean(0)
    distance, nearest = cKDTree(unique * scale + translation).query(rig_points)
    if float(distance.max()) > tolerance or len(set(map(int, nearest))) != len(unique):
        raise RigError("Every original world point must occur in the actual rig")
    tree = cKDTree(unique * scale + translation)
    second, _ = tree.query(rig_points, k=2)
    if np.any(second[:, 1] <= tolerance):
        raise RigError("Ambiguous distinct original points within the matching tolerance")
    face_lookup, offset = {}, 0
    for row in source:
        row_ids = inverse[offset:offset + len(row["values"]["POSITION"])]
        for triangle in row["triangles"]:
            ids = tuple(int(row_ids[index]) for index in triangle)
            key = oriented_key(ids)
            if key in face_lookup or len(set(ids)) != 3:
                raise RigError("Ambiguous overlapping / degenerate original surface triangle")
            face_lookup[key] = (row, triangle, ids)
        offset += len(row["values"]["POSITION"])
    mapped = []
    matched_faces = Counter()
    for triangle in rig[0]["triangles"]:
        ids = tuple(int(nearest[index]) for index in triangle)
        key = oriented_key(ids)
        if key not in face_lookup:
            raise RigError("Rig triangle is absent or has reversed original winding")
        matched_faces[key] += 1
        source_row, source_triangle, source_ids = face_lookup[key]
        corners = [source_triangle[source_ids.index(identity)] for identity in ids]
        mapped.append((triangle, source_row, corners))
    if matched_faces != Counter({key: 1 for key in face_lookup}):
        raise RigError("Original triangle coverage changed or a rig face is duplicated")
    maximum_uv_error = max(abs(rig[0]["values"]["TEXCOORD_0"][vertex][axis] - source_row["values"]["TEXCOORD_0"][corner][axis])
                           for triangle, source_row, corners in mapped for vertex, corner in zip(triangle, corners) for axis in range(2))
    maximum_normal_error = max(abs(rig[0]["values"]["NORMAL"][vertex][axis] - source_row["values"]["NORMAL"][corner][axis])
                               for triangle, source_row, corners in mapped for vertex, corner in zip(triangle, corners) for axis in range(3))
    return rig[0], mapped, {"source_triangles": len(face_lookup), "rig_triangles": len(mapped),
        "unique_original_points": len(unique), "all_original_points_matched": True,
        "oriented_original_triangles_matched_exactly_once": True,
        "verified_uniform_scale": scale, "verified_translation": translation.tolist(),
        "maximum_shape_mapping_error": float(distance.max()), "shape_tolerance": tolerance,
        "maximum_original_uv_error_before_recovery": maximum_uv_error,
        "maximum_original_normal_error_before_recovery": maximum_normal_error}


def append_view(gltf, binary, content, target=None):
    binary += b"\0" * (-len(binary) % 4)
    view = {"buffer": 0, "byteOffset": len(binary), "byteLength": len(content)}
    if target:
        view["target"] = target
    index = len(gltf.setdefault("bufferViews", []))
    gltf["bufferViews"].append(view)
    return index, binary + content


def append_accessor(gltf, binary, values, component, kind, target):
    layout = struct.Struct("<" + FORMATS[component] * DIMENSIONS[kind])
    content = b"".join(layout.pack(*row) for row in values)
    view, binary = append_view(gltf, binary, content, target)
    definition = {"bufferView": view, "componentType": component, "count": len(values), "type": kind}
    if kind == "VEC3" and target == 34962:
        definition["min"] = [min(row[axis] for row in values) for axis in range(3)]
        definition["max"] = [max(row[axis] for row in values) for axis in range(3)]
    index = len(gltf.setdefault("accessors", []))
    gltf["accessors"].append(definition)
    return index, binary


def copy_original_materials(gltf, binary, reference, reference_binary):
    if reference.get("extensionsUsed") or reference.get("extensionsRequired"):
        raise RigError("Original material extensions require a separate preserving review")
    image_offset, texture_offset = len(gltf.get("images", [])), len(gltf.get("textures", []))
    sampler_offset, material_offset = len(gltf.get("samplers", [])), len(gltf.get("materials", []))
    gltf.setdefault("samplers", []).extend(copy.deepcopy(reference.get("samplers", [])))
    for image in reference.get("images", []):
        view, binary = append_view(gltf, binary, image_bytes(reference, reference_binary, image))
        copied = copy.deepcopy(image)
        copied["bufferView"] = view
        gltf.setdefault("images", []).append(copied)
    for texture in reference.get("textures", []):
        copied = copy.deepcopy(texture)
        if "extensions" in copied or "source" not in copied:
            raise RigError("Unsupported original texture reference")
        copied["source"] += image_offset
        if "sampler" in copied:
            copied["sampler"] += sampler_offset
        gltf.setdefault("textures", []).append(copied)
    def remap_textures(value):
        if isinstance(value, dict):
            for name, child in value.items():
                if name.endswith("Texture") and isinstance(child, dict) and "index" in child:
                    child["index"] += texture_offset
                remap_textures(child)
        elif isinstance(value, list):
            for child in value:
                remap_textures(child)
    for material in reference.get("materials", []):
        copied = copy.deepcopy(material)
        remap_textures(copied)
        gltf.setdefault("materials", []).append(copied)
    return material_offset, binary


def recover(reference_path, rig_path, output=None):
    reference_path, rig_path = Path(reference_path).resolve(), Path(rig_path).resolve()
    reference, reference_binary, reference_bytes = read_glb(reference_path)
    rig, binary, rig_bytes = read_glb(rig_path)
    row, matched, report = correspondence(reference, reference_binary, rig, binary)
    report.update({"schema": 1, "reference": str(reference_path), "rig": str(rig_path),
        "reference_sha256": hashlib.sha256(reference_bytes).hexdigest(), "rig_sha256": hashlib.sha256(rig_bytes).hexdigest(),
        "source_materials": [material.get("name") for material in reference.get("materials", [])],
        "source_material_triangle_counts": dict(Counter(reference["materials"][source_row["definition"]["material"]].get("name") for _, source_row, _ in matched)),
        "original_uv_recovery": True, "original_normal_recovery": True, "original_material_region_recovery": True,
        "skin_skeleton_animations_preserved": True, "texture_rebake": False, "uv_repack": False,
        "read_only": output is None, "api_called": False, "rig_ready_for_game": False})
    if output is None:
        return report
    output = Path(output).resolve()
    if ROOT / "build" not in output.parents or output.exists() or output.with_suffix(".recovery.json").exists():
        raise RigError("Recovery requires a new output and audit inside build/")
    result = copy.deepcopy(rig)
    material_offset, rebuilt = copy_original_materials(result, binary, reference, reference_binary)
    by_material = {}
    for triangle, source_row, corners in matched:
        material = source_row["definition"]["material"]
        group = by_material.setdefault(material, {"vertices": {}, "values": {name: [] for name in row["values"]}, "indices": []})
        for vertex, source_corner in zip(triangle, corners):
            original_uv = tuple(source_row["values"]["TEXCOORD_0"][source_corner])
            original_normal = tuple(source_row["values"]["NORMAL"][source_corner])
            key = (vertex, original_uv, original_normal)
            if key not in group["vertices"]:
                group["vertices"][key] = len(group["vertices"])
                for name, values in group["values"].items():
                    values.append(original_uv if name == "TEXCOORD_0" else original_normal if name == "NORMAL" else row["values"][name][vertex])
            group["indices"].append((group["vertices"][key],))
    restored = []
    for material, group in sorted(by_material.items()):
        primitive = {"attributes": {}, "material": material + material_offset, "mode": 4}
        for name, values in group["values"].items():
            template = rig["accessors"][row["definition"]["attributes"][name]]
            accessor, rebuilt = append_accessor(result, rebuilt, values, template["componentType"], template["type"], 34962)
            primitive["attributes"][name] = accessor
        primitive["indices"], rebuilt = append_accessor(result, rebuilt, group["indices"], 5125, "SCALAR", 34963)
        restored.append(primitive)
    result["meshes"][row["mesh"]]["primitives"] = restored
    result["buffers"][0]["byteLength"] = len(rebuilt)
    # Verify genuine rig geometry/skin per corner after restoring appearance.
    after = primitives(result, rebuilt, True)
    actual = Counter()
    for item in after:
        for triangle in item["triangles"]:
            corners = tuple(tuple((name, item["values"][name][vertex]) for name in sorted(row["values"]) if name not in ("TEXCOORD_0", "NORMAL")) for vertex in triangle)
            actual[oriented_key(corners)] += 1
    before = Counter(oriented_key(tuple(tuple((name, row["values"][name][vertex]) for name in sorted(row["values"]) if name not in ("TEXCOORD_0", "NORMAL")) for vertex in triangle)) for triangle in row["triangles"])
    if before != actual or not rebuilt.startswith(binary):
        raise RigError("Genuine rig position/weight triangle attributes changed")
    for key in ("nodes", "skins", "animations"):
        if result.get(key) != rig.get(key):
            raise RigError("Genuine rig skeleton / bind / animation data changed")
    expected_uv = Counter((reference["materials"][source_row["definition"]["material"]].get("name"),
        oriented_key(tuple((row["values"]["POSITION"][vertex], tuple(source_row["values"]["TEXCOORD_0"][corner]), tuple(source_row["values"]["NORMAL"][corner])) for vertex, corner in zip(triangle, corners))))
        for triangle, source_row, corners in matched)
    actual_uv = Counter()
    for item in after:
        material = result["materials"][item["definition"]["material"]].get("name")
        for triangle in item["triangles"]:
            actual_uv[(material, oriented_key(tuple((item["values"]["POSITION"][vertex], item["values"]["TEXCOORD_0"][vertex], item["values"]["NORMAL"][vertex]) for vertex in triangle)))] += 1
    if expected_uv != actual_uv:
        raise RigError("Recovered UV/normal/material corner coverage differs from original")
    for old, new in zip(reference["images"], result["images"][-len(reference["images"]):]):
        if image_bytes(reference, reference_binary, old) != image_bytes(result, rebuilt, new):
            raise RigError("Original embedded reference image changed")
    output.parent.mkdir(parents=True, exist_ok=True)
    write_glb(output, result, rebuilt)
    report.update({"output": str(output), "output_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "output_primitives": len(restored), "output_vertices": sum(len(group["vertices"]) for group in by_material.values()),
        "exact_rig_geometry_skin_corner_attributes_verified": True, "exact_original_uv_normal_material_corners_verified": True,
        "original_rig_binary_prefix_preserved": True, "original_reference_image_bytes_preserved": True,
        "source_files_unchanged": reference_path.read_bytes() == reference_bytes and rig_path.read_bytes() == rig_bytes})
    output.with_suffix(".recovery.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reference", type=Path)
    parser.add_argument("rig", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    print(json.dumps(recover(args.reference, args.rig, args.output), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
