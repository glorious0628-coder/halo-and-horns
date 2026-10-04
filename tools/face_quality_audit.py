"""Read-only local texture/UV audit; diagnostic CG renders only under build/.

No Studio, upload, image-generation, or paid API calls. The script reads the
approved source assets, checks file hashes after the audit, and never rewrites
them. Raster output is an unlit software render of those unchanged assets.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import hashlib
import io
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "costume_r15"))
from glb_io import accessor_values, image_bytes, read_glb


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(path):
    gltf, binary, original = read_glb(path)
    images = []
    image_reports = []
    for index, row in enumerate(gltf.get("images", [])):
        payload = image_bytes(gltf, binary, row)
        image = Image.open(io.BytesIO(payload)).convert("RGB")
        images.append(np.asarray(image, dtype=np.float64) / 255.)
        image_reports.append({"index": index, "name": row.get("name"), "size": list(image.size),
                              "sha256": hashlib.sha256(payload).hexdigest(), "bytes": len(payload)})
    parents = {child: index for index, node in enumerate(gltf.get("nodes", []))
               for child in node.get("children", [])}

    def offset(index):
        node = gltf["nodes"][index]
        if any(key in node for key in ("matrix", "rotation", "scale")):
            raise ValueError("Raw/fixed density audit requires translation-only static sources")
        result = np.asarray(node.get("translation", (0, 0, 0)), dtype=np.float64)
        return result + offset(parents[index]) if index in parents else result

    points, uvs, textures, names = [], [], [], []
    for index, node in enumerate(gltf.get("nodes", [])):
        if "mesh" not in node:
            continue
        for primitive in gltf["meshes"][node["mesh"]]["primitives"]:
            if primitive.get("mode", 4) != 4:
                raise ValueError("Only triangles are supported")
            positions = np.asarray(accessor_values(gltf, binary, primitive["attributes"]["POSITION"]))
            coordinates = np.asarray(accessor_values(gltf, binary, primitive["attributes"]["TEXCOORD_0"]))
            indices = np.asarray(accessor_values(gltf, binary, primitive["indices"]), dtype=np.int64).reshape(-1, 3)
            material = gltf["materials"][primitive["material"]]
            texture = material["pbrMetallicRoughness"]["baseColorTexture"]
            if texture.get("texCoord", 0) != 0:
                raise ValueError("The actual TEXCOORD_0 source chart is required")
            image_index = gltf["textures"][texture["index"]]["source"]
            points.extend((positions + offset(index))[indices])
            uvs.extend(coordinates[indices])
            textures.extend([image_index] * len(indices))
            names.extend([node.get("name", "")] * len(indices))
    result = {"path": str(path), "sha256": hashlib.sha256(original).hexdigest(), "images": images,
              "image_reports": image_reports, "points": np.asarray(points), "uv": np.asarray(uvs),
              "textures": np.asarray(textures), "names": np.asarray(names)}
    return result


def footprint(model):
    uv = model["uv"]
    first, second = uv[:, 1] - uv[:, 0], uv[:, 2] - uv[:, 0]
    area = np.abs(first[:, 0] * second[:, 1] - first[:, 1] * second[:, 0]) / 2
    sizes = np.asarray([np.prod(row["size"]) for row in model["image_reports"]])
    return area * sizes[model["textures"]]


def bilinear(image, uv):
    height, width = image.shape[:2]
    # glTF texture UV origin is upper left. Sample texel centers, as a linear
    # sampler does. No PNG pixels are modified.
    x = np.clip(uv[:, 0] * width - .5, 0, width - 1)
    y = np.clip(uv[:, 1] * height - .5, 0, height - 1)
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    x1, y1 = np.minimum(x0 + 1, width - 1), np.minimum(y0 + 1, height - 1)
    dx, dy = (x - x0)[:, None], (y - y0)[:, None]
    return ((1-dy) * ((1-dx)*image[y0, x0] + dx*image[y0, x1])
            + dy * ((1-dx)*image[y1, x0] + dx*image[y1, x1]))


def front_render(model, size=768):
    points = model["points"]
    low, high = points.reshape(-1, 3).min(axis=0), points.reshape(-1, 3).max(axis=0)
    bottom = low[1] + .58 * (high[1] - low[1])
    scale = (high[1] - bottom) * 1.15
    center = np.array([(low[0] + high[0]) / 2, (bottom + high[1]) / 2])
    screen = (points[:, :, :2] - center) * size / scale
    screen[:, :, 0] += size / 2
    screen[:, :, 1] = size / 2 - screen[:, :, 1]
    depth = np.full((size, size), -np.inf)
    visible = np.full((size, size), -1, dtype=np.int32)
    output = np.full((size, size, 3), .82)
    for face, tri in enumerate(screen):
        min_x, max_x = max(0, int(np.floor(tri[:, 0].min()))), min(size-1, int(np.ceil(tri[:, 0].max())))
        min_y, max_y = max(0, int(np.floor(tri[:, 1].min()))), min(size-1, int(np.ceil(tri[:, 1].max())))
        if min_x > max_x or min_y > max_y:
            continue
        a, b, c = tri
        denominator = (b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(denominator) < 1e-12:
            continue
        yy, xx = np.mgrid[min_y:max_y+1, min_x:max_x+1]
        xx, yy = xx + .5, yy + .5
        wa = ((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/denominator
        wb = ((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/denominator
        wc = 1 - wa - wb
        z = wa*points[face, 0, 2]+wb*points[face, 1, 2]+wc*points[face, 2, 2]
        mask = (wa >= -1e-7) & (wb >= -1e-7) & (wc >= -1e-7)
        window = depth[min_y:max_y+1, min_x:max_x+1]
        mask &= z > window
        if not mask.any():
            continue
        window[mask] = z[mask]
        visible[min_y:max_y+1, min_x:max_x+1][mask] = face
        uv = (wa[mask, None]*model["uv"][face, 0]+wb[mask, None]*model["uv"][face, 1]
              +wc[mask, None]*model["uv"][face, 2])
        output[min_y:max_y+1, min_x:max_x+1][mask] = bilinear(model["images"][model["textures"][face]], uv)
    return output, visible


def mapping(raw, fixed):
    from scipy.spatial import cKDTree
    raw_points, raw_indices = np.unique(raw["points"].reshape(-1, 3), axis=0, return_inverse=True)
    error, indices = cKDTree(raw_points).query(fixed["points"].reshape(-1, 3))
    raw_faces = defaultdict(list)
    for index, tri in enumerate(raw_indices.reshape(-1, 3)):
        raw_faces[tuple(sorted(map(int, tri)))].append(index)
    matches = []
    for tri in indices.reshape(-1, 3):
        possible = raw_faces[tuple(sorted(map(int, tri)))]
        if len(possible) != 1:
            raise ValueError("Original triangle matching must be unique")
        matches.append(possible[0])
    return np.asarray(matches), float(error.max())


def uv_islands(model, faces):
    """Count islands joined by actual coincident geometry and UV edge pairs."""
    edges = defaultdict(list)
    parent = {int(face): int(face) for face in faces}

    def find(value):
        while parent[value] != value:
            parent[value] = parent[parent[value]]
            value = parent[value]
        return value

    for face in faces:
        for i, j in ((0, 1), (1, 2), (2, 0)):
            first = tuple(np.round(model["points"][face, i], 6))
            second = tuple(np.round(model["points"][face, j], 6))
            uv_first, uv_second = model["uv"][face, i], model["uv"][face, j]
            if first > second:
                first, second, uv_first, uv_second = second, first, uv_second, uv_first
            edges[(first, second)].append((int(face), uv_first, uv_second))
    joined = 0
    for rows in edges.values():
        for i, first in enumerate(rows):
            for second in rows[i+1:]:
                if np.max(np.abs(first[1]-second[1])) < 1e-6 and np.max(np.abs(first[2]-second[2])) < 1e-6:
                    a, b = find(first[0]), find(second[0])
                    if a != b:
                        parent[a] = b
                        joined += 1
    islands = defaultdict(list)
    for face in faces:
        islands[find(int(face))].append(int(face))
    return {"islands": len(islands), "triangle_count_per_island_percentiles": percentile([len(v) for v in islands.values()]),
            "largest_island_triangles": max(map(len, islands.values())) if islands else 0,
            "geometry_and_uv_edge_epsilon": 1e-6}


def percentile(values):
    return {str(p): float(np.percentile(values, p)) for p in (0, 10, 50, 90, 100)} if len(values) else {}


def inspect_expression_candidates(directory):
    result = []
    seen = set()
    for filename in ("face_union_mouth_winding_manifest_v1.json", "face_union_mouth_manifest_v1.json",
                     "face_union_manifest.json", "skin_expressions_manifest.json", "expressions_manifest.json"):
        manifest_path = directory / filename
        if not manifest_path.is_file():
            continue
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        asset = manifest.get("skin_asset") or manifest.get("head_asset")
        if not asset:
            continue
        path = Path(asset)
        path = path if path.is_absolute() else ROOT / path
        if path in seen or not path.is_file():
            continue
        seen.add(path)
        gltf, binary, original = read_glb(path)
        rows = []
        for row in gltf.get("images", []):
            payload = image_bytes(gltf, binary, row)
            rows.append({"name": row.get("name"), "size": list(Image.open(io.BytesIO(payload)).size),
                         "sha256": hashlib.sha256(payload).hexdigest()})
        neutral = next((record for record in manifest.get("records", []) if record.get("state") == "Neutral"), None)
        original_png = ROOT / neutral["png"] if neutral else None
        result.append({"glb": str(path), "sha256": hashlib.sha256(original).hexdigest(), "manifest": str(manifest_path),
                       "images": rows, "neutral_png_bytes_exact_in_glb": bool(original_png and original_png.is_file()
                             and digest(original_png) in {row["sha256"] for row in rows}),
                       "native_registration_asserted": False})
    return result


def region_report(raw, fixed, matches, faces, label):
    source, target = footprint(raw)[matches[faces]], footprint(fixed)[faces]
    valid = source > 1e-12
    ratio = target[valid] / source[valid]
    return {"label": label, "triangles": len(faces), "raw_texel_area_sum": float(source.sum()),
            "fixed_texel_area_sum": float(target.sum()), "fixed_to_raw_total_area_ratio": float(target.sum()/source.sum()) if source.sum() else None,
            "fixed_to_raw_linear_density_percentiles": percentile(np.sqrt(ratio)),
            "fixed_texels_per_triangle_percentiles": percentile(target),
            "raw_texels_per_triangle_percentiles": percentile(source)}


def audit(name, out, render):
    short = name.removeprefix("Costume_")
    raw_path = ROOT / "art/models/costume/raw" / ("C2k_"+short+".glb")
    fixed_path = ROOT / "art/models/costume/fixed" / ("Costume_"+short+".glb")
    raw, fixed = load(raw_path), load(fixed_path)
    matches, error = mapping(raw, fixed)
    if error > 1e-6 or len(raw["points"]) != len(fixed["points"]) or len(set(matches)) != len(raw["points"]):
        raise ValueError("The exact original/fixed triangle bijection did not pass")
    head = np.flatnonzero(fixed["names"] == "Head")
    result = {"avatar": "Costume_"+short, "raw": {"path": str(raw_path), "sha256": raw["sha256"], "images": raw["image_reports"]},
              "fixed": {"path": str(fixed_path), "sha256": fixed["sha256"], "images": fixed["image_reports"]},
              "triangles": len(fixed["points"]), "matching_raw_triangles": len(set(matches)), "maximum_world_position_error": error,
              "head_density": region_report(raw, fixed, matches, head, "entire fixed Head material surface"),
              "existing_pipeline": {"source_texture_interpolation": "Cubic", "bake_resolution": 1024, "bake_margin": 12,
                                    "pack_islands_margin": .004, "head_sharpen_amount": .9, "body_sharpen_amount": .6, "saturation_multiplier": 1.08},
              "paid_calls": 0, "uploads": 0, "studio_called": False, "source_assets_mutated": False}
    result["head_uv_islands"] = {"raw": uv_islands(raw, matches[head]), "fixed": uv_islands(fixed, head)}
    target_area = result["head_density"]["fixed_texel_area_sum"]
    result["head_true_triangle_uv_area_fraction_of_1024_atlas"] = target_area / (1024*1024)
    png_path = fixed_path.with_name(fixed_path.stem + "_head.png")
    result["fixed_head_external_png_matches_embedded_bytes"] = digest(png_path) in {row["sha256"] for row in fixed["image_reports"]}
    expression_dir = ROOT / "art/models/costume/expressions" / ("Costume_"+short)
    expression_pngs = list(expression_dir.glob("*_Expression_*_face.png"))
    result["expression_original_pngs"] = [{"path": str(p), "sha256": digest(p), "size": list(Image.open(p).size)} for p in expression_pngs]
    result["local_expression_candidates"] = inspect_expression_candidates(expression_dir)
    result["face_png_policy"] = "GPT source bytes inspected only; no sharpening, resampling or image edits in this audit"
    if render:
        raw_image, _ = front_render(raw)
        fixed_image, visible = front_render(fixed)
        for tag, img in (("raw_unlit", raw_image), ("fixed_unlit", fixed_image)):
            path = out / (short + "_" + tag + ".png")
            if path.exists():
                raise ValueError("Refuse to overwrite existing diagnostic render: "+str(path))
            Image.fromarray(np.clip(img*255+.5, 0, 255).astype(np.uint8)).save(path)
        result["diagnostic_renders"] = [str(out/(short+"_"+tag+".png")) for tag in ("raw_unlit", "fixed_unlit")]
        profile_path = expression_dir / "facial_profile.json"
        if profile_path.is_file():
            profile = json.loads(profile_path.read_text(encoding="utf-8"))
            result["profile_sha256"] = digest(profile_path)
            for key in ("eye_boxes", "brow_boxes"):
                mask = np.zeros(visible.shape, dtype=bool)
                for left, top, right, bottom in profile.get(key, []):
                    mask[int(top):int(bottom), int(left):int(right)] = True
                selected = np.unique(visible[mask & (visible >= 0)])
                selected = selected[np.isin(selected, head)]
                result[key+"_density"] = region_report(raw, fixed, matches, selected, "front-visible original source triangles in profile "+key+"; may include fringe")
        result["diagnostic_render_policy"] = "unchanged static source geometry and original baseColor, common 768px front camera, software z-buffer and bilinear sampler; not Native Roblox evidence"
    result["source_sha256_unchanged_after_audit"] = digest(raw_path) == raw["sha256"] and digest(fixed_path) == fixed["sha256"]
    if not result["source_sha256_unchanged_after_audit"]:
        raise ValueError("Source file changed during audit")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--avatars", nargs="+", default=[f+c+g for f in ("Halo","Horns","Neutral") for c in ("Warrior","Archer","Mage") for g in ("M","F")])
    parser.add_argument("--render", nargs="*", default=["HaloWarriorM", "HaloArcherM", "HornsMageF", "NeutralArcherF"])
    parser.add_argument("--output", type=Path, default=ROOT / "build/face_quality_audit_20261004/audit.json")
    args = parser.parse_args()
    output = args.output.resolve()
    allowed = (ROOT / "build/face_quality_audit_20261004").resolve()
    output.relative_to(allowed)
    if output.exists():
        raise ValueError("Refuse to overwrite existing report")
    output.parent.mkdir(parents=True, exist_ok=True)
    rows = [audit(name, output.parent, name.removeprefix("Costume_") in args.render) for name in args.avatars]
    report = {"schema": 1, "source_files_read_only": True, "studio_called": False, "uploads": 0, "paid_calls": 0,
              "actual_native_quality_verified": False, "rows": rows,
              "limitations": ["UV texel area quantifies available samples, not recovered detail or a universal visual-quality score.",
                              "The audit does not assert the actual Roblox download texture resolution.",
                              "Existing expression PNG byte preservation must be checked per final GLB; raw/fixed static density alone does not establish it.",
                              "Packed UV bake and sharpen cannot recover detail absent in the original GPT/Tripo source."]}
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"report": str(output), "avatars": len(rows), "source_files_read_only": True,
                      "head_linear_density_median_range": [min(row["head_density"]["fixed_to_raw_linear_density_percentiles"]["50"] for row in rows),
                                                           max(row["head_density"]["fixed_to_raw_linear_density_percentiles"]["50"] for row in rows)]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
