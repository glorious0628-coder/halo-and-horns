"""Two original female archer static surfaces -> explicit inferred candidates.

Only local original-face ownership / measured landmark JSON is produced. The
chosen visual design, geometry, UVs, normals, material and images are untouched.
"""
import argparse
from collections import Counter
import hashlib
import io
import json
from pathlib import Path

from PIL import Image

from constraints import PRIMARY, RigError
from glb_io import accessor_values, image_bytes, read_glb
import manual_neutral


ROOT = Path(__file__).resolve().parents[2]
TUNING = {
    "HaloArcherF": {"neck": .605, "waist": .460, "hip": .395,
        "shoulder": (.134, .548), "elbow": (.193, .445), "wrist": (.239, .385),
        "hand_tip": (.277, .340), "leg_x": .102, "knee": .182, "ankle": .064,
        "head_plane": .616, "hair_y": .365, "hair_back": -.045,
        "reason": "원본 정면의 목 장식 아래·흰 소매 굴곡·가죽 장갑 시작·금색 무릎판·부츠 발등과 측면 실제 팔 단면을 읽은 추정 후보"},
    "HornsArcherF": {"neck": .602, "waist": .455, "hip": .375,
        "shoulder": (.130, .555), "elbow": (.190, .446), "wrist": (.239, .390),
        "hand_tip": (.267, .337), "leg_x": .109, "knee": .213, "ankle": .088,
        "head_plane": .613, "hair_y": .342, "hair_back": -.045,
        "reason": "원본 정면의 턱 아래 목·어깨 갑옷·빨간 팔 보호대·검은 장갑·무릎 보석·부츠 윗부분과 측면 실제 팔 단면을 읽은 추정 후보"},
}


def prepare(name):
    # Share the measured source-band sampler without editing its owned module.
    manual_neutral.TUNING[name] = TUNING[name]
    doc = manual_neutral.prepare(name)
    source = ROOT / doc["source"]
    gltf, binary, original = read_glb(source)
    height = doc["source_bounds"]["max"][1] - doc["source_bounds"]["min"][1]
    center = (doc["source_bounds"]["max"][0] + doc["source_bounds"]["min"][0]) / 2
    images = {}
    original_rows = []
    for assignment in doc["triangle_owners"]:
        primitive = gltf["meshes"][assignment["mesh"]]["primitives"][assignment["primitive"]]
        points = accessor_values(gltf, binary, primitive["attributes"]["POSITION"])
        uvs = accessor_values(gltf, binary, primitive["attributes"]["TEXCOORD_0"])
        indices = [row[0] for row in accessor_values(gltf, binary, primitive["indices"])]
        original_rows.append({"points": points, "indices": indices, "mesh": assignment["mesh"], "material": primitive["material"]})
        texture = gltf["materials"][primitive["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
        image_index = gltf["textures"][texture]["source"]
        if image_index not in images:
            images[image_index] = Image.open(io.BytesIO(image_bytes(gltf, binary, gltf["images"][image_index]))).convert("RGB")
        image = images[image_index]
        for ordinal, offset in enumerate(range(0, len(indices), 3)):
            triangle = indices[offset:offset + 3]
            centroid = [sum(points[index][axis] for index in triangle) / 3 for axis in range(3)]
            fraction = centroid[1] / height
            ax = abs(centroid[0] - center) / height
            side = "Left" if centroid[0] >= center else "Right"
            # Keep the complete glove/palm with its wrist, including fingers
            # curving slightly above the cuff's measured height.
            wrist_height = TUNING[name]["wrist"][1]
            if .305 < fraction < wrist_height + .025 and ax > .198 and centroid[2] > -.065 * height:
                assignment["owners"][ordinal] = side + "Hand"
            # The measured far-back volume is long hair, including dark baked
            # creases and the center of the hair. A brightness test alone cuts
            # false rectangular holes through that continuous source surface.
            if fraction > .255 and max(points[index][2] for index in triangle) < -.085 * height:
                assignment["owners"][ordinal] = "Head"
                continue
            if fraction <= .255 or centroid[2] >= -.070 * height or ax <= .070:
                continue
            uv = [sum(uvs[index][axis] for index in triangle) / 3 for axis in range(2)]
            pixel = image.getpixel((min(image.width - 1, max(0, round(uv[0] * (image.width - 1)))),
                                    min(image.height - 1, max(0, round(uv[1] * (image.height - 1))))))
            r, g, b = [channel / 255 for channel in pixel]
            hair = r > .64 and g > .48 and b > .35 if name == "HornsArcherF" else r > .64 and g > .50 and .28 < b < .87
            if hair:
                assignment["owners"][ordinal] = "Head"
    # Back hair must not skew a hidden arm center toward the back of the head.
    points = [point for row in original_rows for point in row["points"]]
    for part in doc["landmarks"]:
        if "Arm" not in part and "Hand" not in part:
            continue
        position = doc["landmarks"][part]
        samples = [point for point in points if abs(point[0] - position[0]) < .040 * height and
                   abs(point[1] - position[1]) < .013 * height and point[2] > -.065 * height]
        if len(samples) >= 4:
            z0 = manual_neutral.quantile([point[2] for point in samples], .05)
            z1 = manual_neutral.quantile([point[2] for point in samples], .95)
            position[2] = (z0 + z1) / 2
            doc["landmark_surface_support"][part]["front_limb_sample_count"] = len(samples)
            doc["landmark_surface_support"][part]["front_limb_depth_extents"] = [z0, z1]
            doc["landmark_evidence"][part] += " 측면 뒤머리와 구분하기 위해 앞쪽 실제 소매/장갑 단면만 깊이 중간값에 사용."
    coherence = manual_neutral.coherent_small_islands(original_rows, doc["triangle_owners"])
    doc["part_triangle_counts"] = dict(Counter(owner for row in doc["triangle_owners"] for owner in row["owners"]))
    if set(doc["part_triangle_counts"]) != set(PRIMARY):
        raise RigError("Original archer face ownership left an empty R15 region")
    doc["material_part_counts"] = {str(row["material"]): dict(Counter(assignment["owners"]))
                                  for row, assignment in zip(original_rows, doc["triangle_owners"])}
    doc["manual_archer_small_island_coherence"] = coherence
    doc["inference_reference_previews"] = ["build/manual_partition_audit/" + name + "_front.png", "build/manual_partition_audit/" + name + "_side.png"]
    doc["hair_assignment_policy"] = "Existing back/lateral light hair-colored source triangles down to measured hair ends join Head; whole glove/palm source triangles follow the wrist; no texture editing, geometry clipping or global HeadMat assignment."
    doc["rig_origin"] = "inferred_manual_candidate"
    doc["original_bones_claimed"] = False
    doc["rig_ready_for_game"] = False
    if source.read_bytes() != original:
        raise RigError("Original source changed")
    return doc


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("name", choices=list(TUNING))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--bind-continuous", nargs=2, metavar=("LANDMARKS", "GLB"),
                        help="Use the already reviewed inferred landmarks and original continuous surfaces")
    parser.add_argument("--canonical-height", type=float, default=5.5)
    args = parser.parse_args()
    if args.bind_continuous:
        config_path, output = (Path(value).resolve() for value in args.bind_continuous)
        config = json.loads(config_path.read_text(encoding="utf-8"))
        if config.get("name") != "Costume_" + args.name:
            raise RigError("The explicit archer name and reviewed inferred config must agree")
        manual_neutral.TUNING[args.name] = TUNING[args.name]
        manual_neutral.bind_continuous(config_path, output, args.canonical_height)
        return
    doc = prepare(args.name)
    if args.output:
        output = args.output.resolve()
        if ROOT / "build" not in output.parents or output.exists():
            raise RigError("Manual landmarks require a new file inside build/")
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"name": doc["name"], "inferred_joints": len(doc["landmarks"]),
        "triangles": doc["original_triangle_count"], "parts": doc["part_triangle_counts"],
        "rig_ready_for_game": False, "output": str(args.output) if args.output else None}, ensure_ascii=False))


if __name__ == "__main__":
    main()
