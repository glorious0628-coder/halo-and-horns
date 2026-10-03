"""Read-only world-space triangle comparison of raw and fixed source GLBs.

An exact oriented triangle bijection after sub-micrometer float rounding shows
the existing fixed model uses the same surface; it does not prove riggability
or that two different texture layouts share the same UVs.
"""
from collections import Counter
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

from constraints import RigError
from glb_io import accessor_values, read_glb


ROOT = Path(__file__).resolve().parents[2]


def triangles(path):
    gltf, binary, original = read_glb(path)
    if gltf.get("skins") or gltf.get("animations"):
        raise RigError("Only the two existing static source surfaces can be compared")
    nodes = gltf.get("nodes", [])
    parents = {}
    for index, node in enumerate(nodes):
        for child in node.get("children", []):
            if child in parents:
                raise RigError("Multiple node parents")
            parents[child] = index
    def offset(index, visited=None):
        visited = set() if visited is None else set(visited)
        if index in visited:
            raise RigError("Cyclic source scene")
        visited.add(index)
        node = nodes[index]
        if any(key in node for key in ("matrix", "rotation", "scale")):
            raise RigError("Only the actual translation-only raw/fixed sources are supported")
        result = np.asarray(node.get("translation", (0, 0, 0)), dtype=np.float64)
        if result.shape != (3,) or not np.isfinite(result).all():
            raise RigError("Invalid actual source translation")
        return result + offset(parents[index], visited) if index in parents else result
    result = []
    for index, node in enumerate(nodes):
        if "mesh" not in node:
            continue
        for primitive in gltf["meshes"][node["mesh"]]["primitives"]:
            if primitive.get("mode", 4) != 4 or "indices" not in primitive:
                raise RigError("Only original indexed triangles are supported")
            points = np.asarray(accessor_values(gltf, binary, primitive["attributes"]["POSITION"]), dtype=np.float64)
            indices = np.asarray([row[0] for row in accessor_values(gltf, binary, primitive["indices"])], dtype=np.int64)
            if points.ndim != 2 or points.shape[1] != 3 or not np.isfinite(points).all() or len(indices) % 3:
                raise RigError("Invalid source geometry")
            if np.any(indices < 0) or np.any(indices >= len(points)):
                raise RigError("Invalid original triangle indices")
            result.extend((points + offset(index))[indices.reshape(-1, 3)])
    if not result:
        raise RigError("Empty source surface")
    return np.asarray(result), hashlib.sha256(original).hexdigest()


def oriented_counter(indices):
    return Counter(min(tuple(row[i:] + row[:i]) for i in range(3)) for tri in indices
                   for row in [[int(index) for index in tri]])


def nearest(source, target):
    try:
        from scipy.spatial import cKDTree
        distance, mapping = cKDTree(target).query(source)
        return distance, mapping
    except ImportError:
        distances, mappings = [], []
        for start in range(0, len(source), 128):
            squared = ((source[start:start + 128, None, :] - target[None, :, :]) ** 2).sum(axis=2)
            choice = squared.argmin(axis=1)
            mappings.extend(choice)
            distances.extend(np.sqrt(squared[np.arange(len(choice)), choice]))
        return np.asarray(distances), np.asarray(mappings)


def compare(fixed, raw, tolerance=1e-6):
    fixed, raw = Path(fixed).resolve(), Path(raw).resolve()
    first, first_sha = triangles(fixed)
    second, second_sha = triangles(raw)
    first_points, first_indices = np.unique(first.reshape(-1, 3), axis=0, return_inverse=True)
    second_points, second_indices = np.unique(second.reshape(-1, 3), axis=0, return_inverse=True)
    distances, mapping = nearest(second_points, first_points)
    bijective = len(first_points) == len(second_points) == len(set(map(int, mapping)))
    first_faces = oriented_counter(first_indices.reshape(-1, 3))
    second_faces = oriented_counter(mapping[second_indices].reshape(-1, 3))
    equal = first_faces == second_faces
    maximum_error = float(distances.max())
    return {"schema": 1, "fixed_source": str(fixed), "raw_source": str(raw),
            "fixed_sha256": first_sha, "raw_sha256": second_sha,
            "fixed_triangles": len(first), "raw_triangles": len(second),
            "fixed_unique_world_points": len(first_points), "raw_unique_world_points": len(second_points),
            "world_point_mapping_bijective": bijective, "maximum_world_position_error": maximum_error,
            "oriented_triangle_counters_equal": equal,
            "surface_preserved_within_tolerance": bijective and equal and maximum_error <= tolerance,
            "tolerance": tolerance, "actual_node_translation_applied": True,
            "texture_or_uv_equivalence_asserted": False, "read_only": True, "api_called": False,
            "riggable": None, "rig_ready_for_game": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fixed", type=Path)
    parser.add_argument("raw", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = compare(args.fixed, args.raw)
    if args.output:
        output = args.output.resolve()
        if ROOT / "build" not in output.parents or output.exists():
            raise RigError("Audit output must be a new file inside build/")
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
