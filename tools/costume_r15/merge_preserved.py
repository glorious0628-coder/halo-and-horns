# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Join static GLB object packaging without touching any geometry/image bytes.

No API, rigging, upload, Blender or Studio calls. A successful local merge does
not mean Tripo accepts the model, and does not create a playable R15 rig.
"""
from __future__ import annotations

raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import tempfile

from constraints import RigError
from glb_io import accessor_values, image_bytes, read_glb, write_glb


ROOT = Path(__file__).resolve().parents[2]


def packaging_merge(gltf, binary):
    """Only accept the exact flat, identity Head/Body layout of fixed sources.

    Combining two primitive lists retains their individual materials and all
    original accessors. It does not weld vertices, delete seams or change UVs.
    """
    if gltf.get("skins") or gltf.get("animations") or gltf.get("extensionsRequired") or gltf.get("extensions"):
        raise RigError("Only an unanimated, unskinned, extension-free static source is supported")
    nodes = gltf.get("nodes", [])
    meshes = gltf.get("meshes", [])
    scenes = gltf.get("scenes", [])
    if len(nodes) != 2 or len(meshes) != 2 or len(scenes) != 1 or gltf.get("scene", 0) != 0:
        raise RigError("Expected exactly the original Head/Body mesh objects in one scene")
    if sorted(scenes[0].get("nodes", [])) != [0, 1] or any(key not in ("name", "nodes", "extras") for key in scenes[0]):
        raise RigError("Unexpected scene references or metadata")
    if {node.get("name") for node in nodes} != {"Head", "Body"}:
        raise RigError("Original fixed Head/Body names are required")
    if any(set(node) - {"name", "mesh"} for node in nodes) or {node["mesh"] for node in nodes} != {0, 1}:
        raise RigError("Transforms/nested objects are refused; no placement is guessed")
    primitives, positions, triangles = [], [], 0
    for node in nodes:
        mesh = meshes[node["mesh"]]
        if set(mesh) - {"name", "primitives"} or not mesh.get("primitives"):
            raise RigError("Morphs or mesh-level extensions need separate review")
        for primitive in mesh["primitives"]:
            if primitive.get("mode", 4) != 4 or "indices" not in primitive or primitive.get("targets") or primitive.get("extensions"):
                raise RigError("Only original indexed triangles without morphs/extensions are supported")
            attrs = primitive.get("attributes", {})
            if "POSITION" not in attrs or "NORMAL" not in attrs or "TEXCOORD_0" not in attrs:
                raise RigError("Original positions, normals and UVs are required")
            if any(key.startswith(("JOINTS_", "WEIGHTS_")) for key in attrs):
                raise RigError("A hidden skin attribute is not a static source")
            vertices = accessor_values(gltf, binary, attrs["POSITION"])
            if any(len(accessor_values(gltf, binary, index)) != len(vertices) for index in attrs.values()):
                raise RigError("Original vertex attribute counts disagree")
            indices = [value[0] for value in accessor_values(gltf, binary, primitive["indices"])]
            if len(indices) % 3 or any(not 0 <= index < len(vertices) for index in indices):
                raise RigError("Invalid original triangle indices")
            positions.append(set(vertices))
            triangles += len(indices) // 3
            primitives.append(copy.deepcopy(primitive))
    result = copy.deepcopy(gltf)
    result["nodes"] = [{"name": "CostumePreserved", "mesh": 0}]
    result["meshes"] = [{"name": "CostumePreservedMesh", "primitives": primitives}]
    result["scenes"][0]["nodes"] = [0]
    # These reference arrays and the complete original binary buffer are kept.
    # Therefore per-corner attributes, material bindings and image bytes are exact.
    for key in ("buffers", "bufferViews", "accessors", "materials", "images", "textures", "samplers"):
        if result.get(key) != gltf.get(key):
            raise RigError("Original binary/material references changed")
    record = {"mesh_objects_before": 2, "mesh_objects_after": 1, "primitives": len(primitives),
              "triangles": triangles, "original_binary_sha256": hashlib.sha256(binary).hexdigest(),
              "texture_sha256": [hashlib.sha256(image_bytes(gltf, binary, image)).hexdigest()
                                  for image in gltf.get("images", [])],
              "exact_shared_positions_before": len(set.intersection(*positions)),
              "vertex_weld_performed": False, "topology_or_normals_changed": False,
              "texture_rebake": False, "uv_repack": False, "original_binary_bytes_preserved": True,
              "riggable": None, "rig_ready_for_game": False, "api_called": False,
              "note": "Packaging-only merge. Both accepted and rejected original models have Head/Body objects; acceptance is unknown."}
    return result, record


def write_candidate(source, destination):
    source = Path(source).resolve()
    destination = Path(destination).resolve()
    if ROOT / "build" not in destination.parents:
        raise RigError("Candidates may be written only to a new directory inside build/")
    if destination.exists():
        raise RigError("Existing output is never overwritten")
    gltf, binary, original = read_glb(source)
    candidate, record = packaging_merge(gltf, binary)
    record["source"] = str(source)
    record["source_sha256"] = hashlib.sha256(original).hexdigest()
    destination.parent.mkdir(parents=True, exist_ok=True)
    # All mutations go to a new staging directory. Source files are never written.
    with tempfile.TemporaryDirectory(prefix=".merge-preserved-", dir=destination.parent) as temporary:
        staging = Path(temporary)
        output = staging / "merged_preserved.glb"
        write_glb(output, candidate, binary)
        actual, actual_binary, actual_bytes = read_glb(output)
        if actual != candidate or actual_binary != binary or source.read_bytes() != original:
            raise RigError("Candidate round-trip or original-source preservation failed")
        record["candidate_sha256"] = hashlib.sha256(actual_bytes).hexdigest()
        (staging / "preservation.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        os.rename(staging, destination)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--output-directory", type=Path,
                        help="Write one new local candidate; omitted means read-only inspection")
    args = parser.parse_args()
    if args.output_directory:
        report = write_candidate(args.source, args.output_directory)
    else:
        gltf, binary, original = read_glb(args.source)
        _, report = packaging_merge(gltf, binary)
        report.update(source=str(args.source.resolve()), source_sha256=hashlib.sha256(original).hexdigest())
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
