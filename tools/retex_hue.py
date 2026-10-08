"""
3D 모델 색 이동(0 크레딧, 그림체 흔들림 조사 2026-10-08): GLB(또는 PNG)의 기본색 텍스처에서 고른 색 범위만 목표 색으로 옮긴다.
무늬·명암은 그대로 두고(Lab 밝기 변화와 a·b 흔들림을 남김) 평균 색만 옮겨서, 같은 UV의 게임 MeshPart TextureID만 바꾸면 된다.

  py tools/retex_hue.py <in.glb|in.png> <out.png> --rule H0:H1:SMIN[-SMAX]:R,G,B[:K[:MASK]] [--rule ...] [--size 1024] [--glb out.glb]
                        [--vmin 0.12] [--feather 1.5] [--mask-out mask.png] [--all-bright F]

- --rule  H0:H1 = 색상 범위(도, 0~360, H0>H1이면 360을 넘어 감음), SMIN = 최소 채도(0~1, 'SMIN-SMAX'로 최대도), R,G,B = 목표 평균 색,
          K = 이동 세기(0~1, 기본 1), 6번째 칸 = UV 영역 마스크 PNG(tools/uv_region_mask.py; '!경로'면 그 밖만).
          규칙은 앞에서부터 차례로 — 먼저 잡힌 픽셀은 다음 규칙에서 빠진다.
- 고른 픽셀의 Lab 평균을 목표 Lab으로 옮긴다: a·b는 목표 + 원래 흔들림 × 0.45, 밝기는 평균 차만큼 더한다.
- --keep: 원래 a·b 흔들림을 얼마나 남길지(기본 0.45; 회색 돌처럼 색을 거의 없애려면 0.1~0.2).
- --vmin: 너무 어두운 픽셀(그림자 틈)은 고르지 않음. --feather: 마스크 가장자리를 부드럽게(픽셀).
- --all-bright F: 마지막에 그림 전체 밝기(Lab L)를 F배(몬스터 어두운 색 맵 밝히기, #35).
- --glb: 바꾼 그림을 넣은 새 GLB(모양·UV 그대로, tools/glb_replace_images.py 방식)도 저장 — 렌더 비교용.
출력 PNG는 --size 정사각(기본 1024, Roblox 최대)으로 줄인다. 원본 텍스처는 건드리지 않는다.
"""
import argparse
import io
import json
import os
import struct
import sys

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def read_glb(path):
    b = open(path, "rb").read()
    o, chunks = 12, []
    while o < len(b):
        cl, ct = struct.unpack("<II", b[o:o + 8])
        chunks.append((ct, b[o + 8:o + 8 + cl]))
        o += 8 + cl
    j = json.loads(chunks[0][1])
    binc = next(c for t, c in chunks if t == 0x004E4942)
    return j, binc


def base_image(path):
    if not path.lower().endswith(".glb"):
        return Image.open(path).convert("RGB")
    j, binc = read_glb(path)
    tex = j["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    img = j["images"][j["textures"][tex]["source"]]
    bv = j["bufferViews"][img["bufferView"]]
    o = bv.get("byteOffset", 0)
    return Image.open(io.BytesIO(binc[o:o + bv["byteLength"]])).convert("RGB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inp")
    ap.add_argument("out")
    ap.add_argument("--rule", action="append", default=[])
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--vmin", type=float, default=0.12)
    ap.add_argument("--feather", type=float, default=1.5)
    ap.add_argument("--mask-out")
    ap.add_argument("--all-bright", type=float, default=0.0)
    ap.add_argument("--keep", type=float, default=0.45)
    ap.add_argument("--glb")
    a = ap.parse_args()

    im = base_image(a.inp)
    src = np.asarray(im).astype(np.float32) / 255
    hsv = cv2.cvtColor(src, cv2.COLOR_RGB2HSV)  # float: H 0..360, S 0..1, V 0..1
    lab = cv2.cvtColor(src, cv2.COLOR_RGB2LAB)
    out = lab.copy()
    taken = np.zeros(src.shape[:2], bool)
    allmask = np.zeros(src.shape[:2], np.float32)
    report = []
    for r in a.rule:
        p = r.split(":")
        h0, h1 = float(p[0]), float(p[1])
        smin, smax = (float(x) for x in p[2].split("-")) if "-" in p[2] else (float(p[2]), 1.01)
        tgt = np.array([[[int(x) / 255 for x in p[3].split(",")]]], np.float32)
        k = float(p[4]) if len(p) > 4 and p[4] else 1.0
        region = None
        if len(p) > 5:  # UV region mask (tools/uv_region_mask.py): 'path' = only inside, '!path' = only outside
            inv = p[5].startswith("!")
            rm = Image.open(":".join(p[5:]).lstrip("!")).convert("L").resize((src.shape[1], src.shape[0]), Image.NEAREST)
            region = np.asarray(rm) > 127
            if inv:
                region = ~region
        h = hsv[..., 0]
        inh = (h >= h0) & (h <= h1) if h0 <= h1 else (h >= h0) | (h <= h1)
        m = inh & (hsv[..., 1] >= smin) & (hsv[..., 1] < smax) & (hsv[..., 2] >= a.vmin) & ~taken
        if region is not None:
            m &= region
        taken |= m
        n = int(m.sum())
        if n == 0:
            report.append({"rule": r, "pixels": 0})
            continue
        tl = cv2.cvtColor(tgt, cv2.COLOR_RGB2LAB)[0, 0]
        mean = lab[m].mean(0)
        soft = cv2.GaussianBlur(m.astype(np.float32), (0, 0), a.feather) if a.feather > 0 else m.astype(np.float32)
        soft = np.clip(soft * k, 0, 1)
        new = lab.copy()
        new[..., 0] = lab[..., 0] + (tl[0] - mean[0])
        new[..., 1] = tl[1] + (lab[..., 1] - mean[1]) * a.keep
        new[..., 2] = tl[2] + (lab[..., 2] - mean[2]) * a.keep
        out = out * (1 - soft[..., None]) + new * soft[..., None]
        allmask = np.maximum(allmask, soft)
        report.append({"rule": r, "pixels": n, "share": round(n / m.size, 4),
                       "from_rgb": [int(v) for v in (cv2.cvtColor(mean[None, None, :].astype(np.float32), cv2.COLOR_LAB2RGB)[0, 0] * 255)]})
    if a.all_bright:
        out[..., 0] = np.clip(out[..., 0] * a.all_bright, 0, 100)
    rgb = np.clip(cv2.cvtColor(out.astype(np.float32), cv2.COLOR_LAB2RGB), 0, 1)
    res = Image.fromarray((rgb * 255).astype(np.uint8))
    if a.size and res.size != (a.size, a.size):
        res = res.resize((a.size, a.size), Image.LANCZOS)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    res.save(a.out)
    if a.mask_out:
        Image.fromarray((allmask * 255).astype(np.uint8)).resize(res.size).save(a.mask_out)
    if a.glb:

        full = Image.fromarray((rgb * 255).astype(np.uint8))
        tmp = a.out + ".full.png"
        full.save(tmp)
        os.system('py "%s" "%s" "%s" --base "%s"' % (os.path.join(os.path.dirname(os.path.abspath(__file__)), "glb_replace_images.py"),
                                                       a.inp, a.glb, tmp))
        os.remove(tmp)
    print("[retex_hue]", json.dumps({"in": a.inp, "out": a.out, "size": res.size, "rules": report}, ensure_ascii=False))


main()
