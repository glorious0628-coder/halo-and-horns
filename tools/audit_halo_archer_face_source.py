"""Read-only, reproducible HaloArcherM source/texel audit. No network or Studio.

Run with: py tools/audit_halo_archer_face_source.py
Only writes diagnostic JSON/crops to docs/art/verification_2026-10-04/face_sharpness_audit/.
Source PNG/GLB files are never modified. Crops use exact source pixels.
"""
from pathlib import Path
import hashlib
import io
import json
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/art/verification_2026-10-04/face_sharpness_audit"
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tools/costume_r15"))
from face_quality_audit import load, mapping, footprint
from glb_io import accessor_values, image_bytes, read_glb


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def area(poly):
    if len(poly) < 3:
        return 0.0
    a = np.asarray(poly, dtype=float)
    b = np.roll(a, -1, axis=0)
    return abs(float(np.sum(a[:, 0] * b[:, 1] - b[:, 0] * a[:, 1]))) / 2


def clipped(poly, box):
    current = list(poly)
    for axis, bound, direction in ((0, box[0], 1), (0, box[2], -1),
                                   (1, box[1], 1), (1, box[3], -1)):
        result = []
        if not current:
            break
        for p, q in zip(current, current[1:] + current[:1]):
            p_in = (p[axis] - bound) * direction >= 0
            q_in = (q[axis] - bound) * direction >= 0
            if p_in:
                result.append(p)
            if p_in != q_in:
                result.append(p + (q - p) * (bound - p[axis]) / (q[axis] - p[axis]))
        current = result
    return current


def uv_coverage(triangles, size):
    coverage = np.zeros((size, size), dtype=np.uint16)
    for a, b, c in triangles:
        low = np.maximum(0, np.floor(np.minimum(np.minimum(a, b), c)).astype(int))
        high = np.minimum(size - 1, np.ceil(np.maximum(np.maximum(a, b), c)).astype(int))
        if np.any(high < low):
            continue
        y, x = np.mgrid[low[1]:high[1]+1, low[0]:high[0]+1]
        x, y = x + .5, y + .5
        denominator = (b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(denominator) < 1e-12:
            continue
        wa = ((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(y-c[1]))/denominator
        wb = ((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(y-c[1]))/denominator
        coverage[low[1]:high[1]+1, low[0]:high[0]+1] += (
            (wa >= 0) & (wb >= 0) & (wa + wb <= 1)).astype(np.uint16)
    return coverage


def highlight_edges(path, rows, x0, x1):
    pixels = np.asarray(Image.open(path).convert("RGB"), dtype=float)
    result = []
    for y in rows:
        line = pixels[y, x0:x1] @ np.array([.2126, .7152, .0722])
        low, high = line.min(), line.max()
        thresholds = low + (high-low) * np.array([.2, .8])
        peak = int(np.argmax(line))
        crossings = []
        for level in thresholds:
            left = [i+(level-line[i])/(line[i+1]-line[i]) for i in range(peak)
                    if line[i] < level <= line[i+1]]
            right = [i+(level-line[i])/(line[i+1]-line[i]) for i in range(peak, len(line)-1)
                     if line[i] >= level > line[i+1]]
            crossings.append((max(left) if left else None, min(right) if right else None))
        if any(v is None for pair in crossings for v in pair):
            continue
        result.append({"row": y, "left_20_80_px": crossings[1][0]-crossings[0][0],
                       "right_80_20_px": crossings[0][1]-crossings[1][1]})
    widths = [r[key] for r in result for key in ("left_20_80_px", "right_80_20_px")]
    return {"rows": result, "x_range": [x0, x1], "median_transition_px": float(np.median(widths)),
            "min_transition_px": float(min(widths)), "max_transition_px": float(max(widths))}


def main():
    expression = ROOT / "art/models/costume/expressions/Costume_HaloArcherM"
    files = {
        "raw2k": ROOT / "art/models/costume/raw/C2k_HaloArcherM.glb",
        "fixed": ROOT / "art/models/costume/fixed/Costume_HaloArcherM.glb",
        "production": expression / "Costume_HaloArcherM_FaceUnionMouthRestored_v1.glb",
        "face1254": expression / "Costume_HaloArcherM_Expression_Neutral_face.png",
        "approved_D": ROOT / "art/out/Avatar_HaloArcherM_FullRedraw_D.png",
        "original_APose": ROOT / "art/out/APose_HaloArcherM.png",
        "profile": expression / "facial_profile.json",
        "provenance": expression / "face_union_provenance.json",
        "prompt": expression / "prompts/Neutral.txt",
    }
    neutral_metadata = json.loads(files["face1254"].with_suffix(".json").read_text(encoding="utf-8"))
    generated_source = Path(neutral_metadata["source"])
    if generated_source.exists():
        files["generated_source"] = generated_source
    hashes = {k: sha(p) for k, p in files.items()}
    raw, fixed = load(files["raw2k"]), load(files["fixed"])
    mapping_indices, position_error = mapping(raw, fixed)
    doc, blob, _ = read_glb(files["production"])
    face = next(m for m in doc["meshes"] if m["name"] == "FaceExpression")["primitives"][0]
    uv = np.asarray(accessor_values(doc, blob, face["attributes"]["TEXCOORD_0"]))
    indices = np.asarray(accessor_values(doc, blob, face["indices"]), dtype=int).reshape(-1, 3)
    selected_uv = uv[indices]
    pixel_triangles = selected_uv * 1254
    provenance = json.loads(files["provenance"].read_text(encoding="utf-8"))["triangles"]
    assert [r["expression_face_index"] for r in provenance] == list(range(len(indices)))
    assert np.array_equal(indices, np.asarray([r["original_vertex_indices"] for r in provenance]))
    signature = lambda tri: tuple(sorted(tuple(round(float(v), 6) for v in p) for p in tri))
    lookup = {}
    for i in np.flatnonzero(fixed["names"] == "Head"):
        key = signature(fixed["uv"][i])
        assert key not in lookup
        lookup[key] = i
    original_faces = np.asarray([lookup[signature(r["original_uv"])] for r in provenance])
    raw_area = footprint(raw)[mapping_indices[original_faces]]
    fixed_area = footprint(fixed)[original_faces]
    face_area = np.asarray([area(t) for t in pixel_triangles])
    profile = json.loads(files["profile"].read_text(encoding="utf-8"))
    regions = {"face": None, "highlight_roi": [744, 882, 785, 923], "mouth_roi": [570, 1030, 690, 1080]}
    for group in ("eye_boxes", "brow_boxes"):
        for i, box in enumerate(profile[group]):
            regions[f"{group}_{i}"] = (np.asarray(box) * 1254 / 768).tolist()
    region_results = {}
    for name, box in regions.items():
        fractions = np.ones(len(indices)) if box is None else np.asarray(
            [area(clipped(t, box)) for t in pixel_triangles]) / np.maximum(face_area, 1e-20)
        raw_sum, fixed_sum, face_sum = [float(np.sum(a * fractions)) for a in (raw_area, fixed_area, face_area)]
        region_results[name] = {"box_in_1254": box, "triangle_count": int(np.sum(fractions > 1e-9)),
            "raw2k_uv_area_px2": raw_sum, "fixed1024_uv_area_px2": fixed_sum,
            "face1254_uv_area_px2": face_sum, "fixed_to_raw_linear_density": float(np.sqrt(fixed_sum/raw_sum))}
    image_info = []
    for row in doc["images"]:
        data = image_bytes(doc, blob, row)
        image_info.append({"name": row.get("name"), "size": list(Image.open(io.BytesIO(data)).size),
                           "sha256": hashlib.sha256(data).hexdigest()})
    coverage = uv_coverage(pixel_triangles, 1254)
    OUT.mkdir(parents=True, exist_ok=True)
    crop_boxes = {"face1254": [695, 829, 924, 1020], "approved_D": [672, 536, 862, 691]}
    crop_records = []
    canvas = Image.new("RGB", (455, 231), "#eeeeee")
    draw = ImageDraw.Draw(canvas)
    x = 12
    for name, box in crop_boxes.items():
        crop = Image.open(files[name]).convert("RGB").crop(box)
        path = OUT / (name + "_eye_exact_pixels.png")
        crop.save(path)
        canvas.paste(crop, (x, 30))
        draw.text((x, 8), name, fill="black")
        x += crop.width + 12
        crop_records.append({"file": str(path.relative_to(ROOT)), "crop_box": box,
                             "source_sha256": hashes[name], "resampling": "none"})
    canvas.save(OUT / "source_eyes_native_pixels.png")
    result = {"schema": 1, "avatar": "HaloArcherM", "source_read_only": True,
        "inputs": {k: {"path": str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else str(p), "sha256": hashes[k]} for k, p in files.items()},
        "raw_embedded_images": raw["image_reports"],
        "fixed_embedded_images": fixed["image_reports"],
        "production_embedded_images": image_info,
        "raw_fixed_triangle_bijection": {"count": len(mapping_indices), "unique": len(set(mapping_indices)), "max_world_error": position_error},
        "provenance_order_and_original_triangle_indices_exact": True,
        "face_triangle_count": len(indices), "referenced_face_vertices": len(np.unique(indices)),
        "face_uv_pixel_bounds": [*pixel_triangles.reshape(-1,2).min(axis=0).tolist(), *pixel_triangles.reshape(-1,2).max(axis=0).tolist()],
        "face_pixel_union_at_texel_centers": int(np.sum(coverage > 0)),
        "face_overlap_pixels_at_texel_centers": int(np.sum(coverage > 1)),
        "face_union_fraction_of_png": float(np.mean(coverage > 0)),
        "regions": region_results,
        "source_equal_png": generated_source.exists() and hashes["generated_source"] == hashes["face1254"],
        "png_exact_in_glb": hashes["face1254"] in {r["sha256"] for r in image_info},
        "face_image_origin": "GPT edit of a Blender front projection; the prompt explicitly preserves both existing eyes.",
        "highlight_edge_20_80": {"current": highlight_edges(files["face1254"], range(900,907),743,786),
                                  "approved_D": highlight_edges(files["approved_D"], range(596,603),712,755)},
        "exact_pixel_crops": crop_records,
        "interpretation_ko": ["기존 3D에서 굽힌 흐린 눈을 GPT 표정 편집에서 그대로 보존하도록 지시했다.",
            "따라서 얼굴1254 PNG가 GPT 원본과 같다는 사실만으로 승인 원화의 선명한 눈을 사용했다고 볼 수 없다.",
            "승인 D의 눈·눈썹·입 원본 픽셀을 쓰려면 별도 UV를 정확히 재매핑해야 한다."],
        "limitations_ko": ["로컬 내장 텍스처 크기는 Roblox 원격 저장 원본 또는 현재 GPU mip 크기를 증명하지 않는다.",
            "UV 면적은 표면이 사용하는 텍셀 수용량이며 눈의 가로 길이나 복원된 정보량이 아니다.",
            "7개 줄의 하이라이트 경계 폭은 이 흰 반사점의 국소 수치이며 전체 화질 점수가 아니다."],
        "paid_calls": 0, "uploads": 0, "studio_called": False,
        "source_sha256_unchanged": all(sha(p) == hashes[k] for k, p in files.items())}
    assert result["source_sha256_unchanged"]
    (OUT / "source_audit.json").write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"path":str(OUT / "source_audit.json"), "face_region":region_results["face"],
                      "unique_face_pixels":result["face_pixel_union_at_texel_centers"],
                      "edge_medians": {k:v["median_transition_px"] for k,v in result["highlight_edge_20_80"].items()}}, ensure_ascii=False))


if __name__ == "__main__":
    main()
