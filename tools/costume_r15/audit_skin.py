# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Read-only audit of genuine source skin regions and exact tied face patches.

This does not invent weights or geometry. Positive patches are measured from
the affine interpolation of the original bone weights on the original face.
No API, upload, Studio or Blender call is made.
"""
from __future__ import annotations

raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path

from constraints import PRIMARY, RigError, bone_regions, face_region, region_weights
from glb_io import accessor_values, read_glb


ROOT = Path(__file__).resolve().parents[2]


def clip_polygon(polygon, values):
    """Clip a barycentric convex polygon by one affine >= 0 half-plane."""
    result = []
    for first, second in zip(polygon, polygon[1:] + polygon[:1]):
        a = sum(x * y for x, y in zip(first, values))
        b = sum(x * y for x, y in zip(second, values))
        inside_a, inside_b = a >= 0, b >= 0
        if inside_a:
            result.append(first)
        if inside_a != inside_b:
            fraction = a / (a - b)
            result.append(tuple(x + (y - x) * fraction for x, y in zip(first, second)))
    return result


def area_ratio(polygon):
    if len(polygon) < 3:
        return 0.0
    return abs(sum(first[1] * second[2] - second[1] * first[2]
                   for first, second in zip(polygon, polygon[1:] + polygon[:1])))


def dominance_patch(weights, owner):
    regions = set.union(*(set(row) for row in weights))
    if owner not in regions:
        return []
    polygon = [(1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)]
    for competitor in sorted(regions - {owner}):
        coefficients = [row.get(owner, 0) - row.get(competitor, 0) for row in weights]
        # A whole-face equal field is ambiguous and cannot be claimed twice.
        if max(abs(value) for value in coefficients) <= 1e-14:
            raise RigError("Coincident skin-weight fields cannot select a unique surface owner")
        polygon = clip_polygon(polygon, coefficients)
        if not polygon:
            return []
    return polygon


def normalized(vector):
    length = math.sqrt(sum(value * value for value in vector))
    if length <= 1e-12:
        raise RigError("Zero interpolated normal")
    return [value / length for value in vector]


def subdivision_normal_error(normals, patches):
    """Measure shading-field change if an exporter normalizes new vertex normals.

    Exact raw linear normals reproduce the old field, but a normalizing exporter
    changes their magnitude before raster interpolation. This reports that risk
    instead of describing a surface-only subdivision as completely unchanged.
    """
    maximum_angle = 0.0
    for polygon in patches:
        for index in range(1, len(polygon) - 1):
            triangle = [polygon[0], polygon[index], polygon[index + 1]]
            emitted = [normalized([sum(bary[corner] * normals[corner][axis] for corner in range(3))
                                   for axis in range(3)]) for bary in triangle]
            for i in range(11):
                for j in range(11 - i):
                    local = [i / 10, j / 10, (10 - i - j) / 10]
                    bary = [sum(local[corner] * triangle[corner][axis] for corner in range(3)) for axis in range(3)]
                    expected = normalized([sum(bary[corner] * normals[corner][axis] for corner in range(3))
                                           for axis in range(3)])
                    actual = normalized([sum(local[corner] * emitted[corner][axis] for corner in range(3))
                                         for axis in range(3)])
                    maximum_angle = max(maximum_angle, math.degrees(math.acos(max(-1, min(1,
                                              sum(x * y for x, y in zip(expected, actual)))))))
    return maximum_angle


def audit(source, target="LeftLowerArm"):
    if target not in PRIMARY:
        raise RigError("Unknown R15 body region")
    source = Path(source).resolve()
    gltf, binary, original = read_glb(source)
    if len(gltf.get("skins", [])) != 1:
        raise RigError("One genuine source skin is required")
    nodes, skin = gltf["nodes"], gltf["skins"][0]
    joints = skin["joints"]
    if len(joints) != len(set(joints)):
        raise RigError("Duplicate skin joints")
    parents = {}
    for index, node in enumerate(nodes):
        for child in node.get("children", []):
            if child in parents:
                raise RigError("Multiple node parents")
            parents[child] = index
    ancestry = {nodes[index]["name"]: nodes[parents[index]]["name"]
                if index in parents and parents[index] in joints else None for index in joints}
    mapping, _ = bone_regions(ancestry)
    owner_counts, vertex_counts = Counter(), Counter()
    weighted, target_unique, touched_faces, positive_patches = 0, 0, 0, 0
    total_ratio, maximum_ratio, total_faces = 0.0, 0.0, 0
    best_vertex_margin = -math.inf
    exact_ties, ambiguous = [], 0
    for node in nodes:
        if "mesh" not in node:
            continue
        if node.get("skin") != 0:
            raise RigError("An unskinned or differently skinned mesh is present")
        for primitive_index, primitive in enumerate(gltf["meshes"][node["mesh"]]["primitives"]):
            if primitive.get("mode", 4) != 4 or "indices" not in primitive:
                raise RigError("Only original indexed triangles can be audited")
            attrs = primitive["attributes"]
            positions = accessor_values(gltf, binary, attrs["POSITION"])
            normals = accessor_values(gltf, binary, attrs["NORMAL"])
            uv = accessor_values(gltf, binary, attrs["TEXCOORD_0"])
            weight_sets = [(accessor_values(gltf, binary, index),
                            accessor_values(gltf, binary, attrs[name.replace("JOINTS_", "WEIGHTS_")]))
                           for name, index in attrs.items() if name.startswith("JOINTS_")]
            if not weight_sets or any(len(js) != len(positions) or len(ws) != len(positions) for js, ws in weight_sets):
                raise RigError("Missing or incompatible real skin weights")
            weights = []
            for vertex in range(len(positions)):
                pairs = []
                for joint_rows, weight_rows in weight_sets:
                    for joint, weight in zip(joint_rows[vertex], weight_rows[vertex]):
                        if not 0 <= joint < len(joints):
                            raise RigError("A weight references an invalid source bone")
                        pairs.append((nodes[joints[joint]]["name"], weight))
                row = region_weights(pairs, mapping)
                weights.append(row)
                maximum = max(row.values())
                winners = [region for region, weight in row.items() if maximum - weight <= 1e-8]
                if len(winners) == 1:
                    vertex_counts[winners[0]] += 1
                if row.get(target, 0) > 1e-8:
                    weighted += 1
                    target_unique += int(winners == [target])
                    best_vertex_margin = max(best_vertex_margin, row[target] - max(
                        (weight for region, weight in row.items() if region != target), default=0))
            indices = [row[0] for row in accessor_values(gltf, binary, primitive["indices"])]
            if len(indices) % 3 or any(not 0 <= index < len(weights) for index in indices):
                raise RigError("Invalid source triangles")
            for start in range(0, len(indices), 3):
                vertices = indices[start:start + 3]
                rows = [weights[index] for index in vertices]
                total_faces += 1
                try:
                    owner, _ = face_region(rows)
                except RigError as error:
                    owner, _ = face_region(rows, "parent-depth")  # Diagnostics only; never export this owner.
                    patches = [dominance_patch(rows, region) for region in sorted(set.union(*(set(row) for row in rows)))]
                    exact_ties.append({"node": node["name"], "primitive": primitive_index, "face": start // 3,
                                       "error": str(error), "weights": rows, "positions": [positions[i] for i in vertices],
                                       "uv": [uv[i] for i in vertices],
                                       "weight_patches": patches, "patch_area_sum": sum(map(area_ratio, patches)),
                                       "subdivision_normalization_error_degrees": subdivision_normal_error(
                                           [normals[i] for i in vertices], patches),
                                       "subdivision_exported": False})
                owner_counts[owner] += 1
                if any(row.get(target, 0) > 1e-8 for row in rows):
                    touched_faces += 1
                    try:
                        ratio = area_ratio(dominance_patch(rows, target))
                    except RigError:
                        ambiguous += 1
                        continue
                    if ratio > 1e-10:
                        positive_patches += 1
                        total_ratio += ratio
                        maximum_ratio = max(maximum_ratio, ratio)
    if source.read_bytes() != original:
        raise RigError("Source changed during read-only inspection")
    return {"schema": 1, "source": str(source), "source_sha256": hashlib.sha256(original).hexdigest(),
            "read_only": True, "api_called": False, "total_triangles": total_faces,
            "mean_face_owners_with_parent_depth_diagnostics_only": dict(owner_counts),
            "unique_vertex_dominance": dict(vertex_counts), "nonadjacent_exact_ties": exact_ties,
            "target": target, "target_weighted_vertices": weighted, "target_unique_vertices": target_unique,
            "target_best_vertex_dominance_margin": best_vertex_margin if math.isfinite(best_vertex_margin) else None,
            "target_touched_faces": touched_faces, "target_positive_area_patches": positive_patches,
            "target_patch_area_ratios_sum": total_ratio, "target_largest_area_ratio": maximum_ratio,
            "target_ambiguous_coincident_fields": ambiguous,
            "rig_ready_for_game": False, "geometry_or_weights_changed": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--region", choices=tuple(PRIMARY), default="LeftLowerArm")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = audit(args.source, args.region)
    if args.output:
        output = args.output.resolve()
        if ROOT / "build" not in output.parents or output.exists():
            raise RigError("Audit output must be a new file inside build/")
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
