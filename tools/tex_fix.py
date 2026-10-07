"""
질감 고치기 한 번에(A23-73 기본 방법 후보): Tripo GLB + 고른 2D 시안 → ④ 색 손보기 + AO (+ ③ 앞면 투영) + ⑤ 금속·거칠기 맵 → 새 GLB.

  py tools/tex_fix.py <in.glb> <concept.png> <work_dir> <label> [--project] [--renders] [--gold 0.15,0.3]

순서(모두 0 크레딧):
  1. GLB에서 텍스처 꺼내기(base / mr)
  2. 2D 시안 각도 찾기(실루엣 거친 격자 → 고운 격자)        tex_compare_render.py --masks, concept_cam_fit.py
  3. AO 굽기 + 색 손보기 = <label>_m4ao.png                  bake_ao.py, tex_color_match.py
  4. 앞면 투영 굽기(항상 — 앞면 색 짝을 얻으려고) → 색은 ④(색 띠)·④'(앞면 짝, tex_pair_match.py) 중
     앞면에서 시안에 더 가까운 쪽(choice.json). --project 일 때만 앞면에 시안 그림을 덮는다 = <label>_m3.png
                                                                 concept_flow_warp.py, project_bake.py, project_mix.py
  5. 금속·거칠기 맵 = <label>_mr.png (+ _metal/_rough)        tex_mr_tune.py
  6. 새 GLB = <work_dir>/<label>_fixed.glb                       glb_replace_images.py
  --renders: 원본·④+AO·③을 같은 조명으로 찍기(<work_dir>/r) — tex_compare_sheet.py 로 시트를 만든다.
"""
import argparse
import io
import json
import os
import struct
import subprocess
import sys

from PIL import Image

BLENDER = r"C:\Users\glori\Tools\blender-5.2.2-windows-x64\blender.exe"
HERE = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser()
ap.add_argument("glb")
ap.add_argument("concept")
ap.add_argument("work")
ap.add_argument("label")
ap.add_argument("--project", action="store_true")
ap.add_argument("--renders", action="store_true")
ap.add_argument("--gold", default="0.15,0.3")
ap.add_argument("--flow", default="12,8")
a = ap.parse_args()
W = os.path.abspath(a.work)
os.makedirs(W, exist_ok=True)
L = a.label


def run(args, blender=False):
    if blender:
        cmd = [BLENDER, "--background", "--factory-startup", "--python", args[0], "--"] + args[1:]
    else:
        cmd = [sys.executable] + args
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    tail = [ln for ln in (r.stdout + r.stderr).splitlines() if ln.strip()][-3:]
    if r.returncode != 0:
        raise SystemExit("FAILED: " + " ".join(cmd) + "\n" + "\n".join(tail))
    return "\n".join(tail)


def t(name):
    return os.path.join(HERE, name)


# 1. textures out of the GLB
b = open(a.glb, "rb").read()
o, ch = 12, []
while o < len(b):
    cl, ct = struct.unpack("<II", b[o:o + 8])
    ch.append((ct, o + 8, cl))
    o += 8 + cl
j = json.loads(b[ch[0][1]:ch[0][1] + ch[0][2]])
bs = next(c for c in ch if c[0] == 0x004E4942)[1]
m = j["materials"][0]
for key, ti in (("base", m["pbrMetallicRoughness"]["baseColorTexture"]["index"]),
                ("mr", m["pbrMetallicRoughness"]["metallicRoughnessTexture"]["index"])):
    bv = j["bufferViews"][j["images"][j["textures"][ti]["source"]]["bufferView"]]
    Image.open(io.BytesIO(b[bs + bv.get("byteOffset", 0):bs + bv.get("byteOffset", 0) + bv["byteLength"]])).convert("RGB").save(os.path.join(W, f"src_{key}.png"))
print("1 textures", flush=True)

# 2. camera fit (coarse, then fine around the best)
cam = os.path.join(W, "cam.json")
if not os.path.exists(cam):
    run([t("tex_compare_render.py"), a.glb, W, "fit", "--masks", os.path.join(W, "masks"), "--mask-grid", "-30:30:10,0:40:5,35/65"], blender=True)
    run([t("concept_cam_fit.py"), a.concept, os.path.join(W, "masks"), cam])
    c0 = json.load(open(cam))
    g = f"{c0['az'] - 6:g}:{c0['az'] + 6:g}:3,{max(-5, c0['el'] - 4):g}:{c0['el'] + 4:g}:2,{c0['lens']:g}/{c0['lens'] * 1.4:g}/{max(30, c0['lens'] * 0.75):g}"
    run([t("tex_compare_render.py"), a.glb, W, "fit", "--masks", os.path.join(W, "masks2"), "--mask-grid", g], blender=True)
    print(run([t("concept_cam_fit.py"), a.concept, os.path.join(W, "masks2"), cam]).splitlines()[-1], flush=True)
print("2 camera", json.load(open(cam)), flush=True)

# 3. AO + colour match
run([t("bake_ao.py"), a.glb, os.path.join(W, "ao.png"), "1024", "48", "0.12"], blender=True)
print(run([t("tex_color_match.py"), os.path.join(W, "src_base.png"), a.concept, os.path.join(W, f"{L}_m4ao.png"), "--ao", os.path.join(W, "ao.png"), "--ao-strength", "0.4"]), flush=True)
final_base = os.path.join(W, f"{L}_m4ao.png")
R = os.path.join(W, "r")

# 4. front projection; the colour fix under it is whichever of ④ (colour bands) / ④' (front pairs) lands closer to
#    the concept on the front texels (band ④ can push an already-close model the wrong way — brazier 2026-10-07)
choice = {"colour_fix": "band"}
if True:  # the projection bake also feeds the front colour pairs, so it runs even without --project (mixing only with --project)
    run([t("tex_compare_render.py"), a.glb, R, f"{L}_m4ao", "--cam", cam, "--tex", final_base, "--views", "match"], blender=True)
    mf, sm = a.flow.split(",")
    print(run([t("concept_flow_warp.py"), a.concept, cam, os.path.join(R, f"{L}_m4ao_match.png"), os.path.join(W, "cic.png"), "--max-flow", mf, "--smooth", sm]), flush=True)
    P = os.path.join(W, "proj")
    run([t("project_bake.py"), a.glb, cam, os.path.join(W, "cic.png"), P], blender=True)
    print(run([t("tex_pair_match.py"), os.path.join(W, "src_base.png"), P, os.path.join(W, f"{L}_pm.png"), "--ao", os.path.join(W, "ao.png")]).splitlines()[-1], flush=True)

    def pair_de(p):
        import cv2
        import numpy as np
        bimg = np.asarray(Image.open(p).convert("RGB"))
        sz = (bimg.shape[1], bimg.shape[0])
        c = np.asarray(Image.open(os.path.join(P, "proj_color.png")).convert("RGB").resize(sz))
        al = np.asarray(Image.open(os.path.join(P, "proj_alpha.png")).convert("L").resize(sz)) / 255
        v = np.asarray(Image.open(os.path.join(P, "proj_vis.png")).convert("L").resize(sz)) / 255
        v = v / np.percentile(v[v > 0.01], 99)
        m = (v > 0.7) & (al > 0.97)
        return float(np.median(np.linalg.norm(cv2.cvtColor(bimg, cv2.COLOR_RGB2LAB).astype(float) - cv2.cvtColor(c, cv2.COLOR_RGB2LAB).astype(float), axis=-1)[m]))

    scores = {"original": pair_de(os.path.join(W, "src_base.png")), "band": pair_de(final_base), "pair": pair_de(os.path.join(W, f"{L}_pm.png"))}
    best = "pair" if scores["pair"] <= scores["band"] else "band"
    choice = {"colour_fix": best, "front_pair_dE_median": {k: round(v, 1) for k, v in scores.items()}}
    print("4 colour fix", choice, flush=True)
    under = os.path.join(W, f"{L}_pm.png") if best == "pair" else final_base
    if a.project:
        print(run([t("project_mix.py"), under, P, os.path.join(W, f"{L}_m3.png"), "--vis", "0.45,0.8"]), flush=True)
        final_base = os.path.join(W, f"{L}_m3.png")
    else:
        final_base = under
choice["front_projection"] = bool(a.project)
json.dump(choice, open(os.path.join(W, "choice.json"), "w"), indent=1)

# 5. metal / roughness
print(run([t("tex_mr_tune.py"), final_base, os.path.join(W, "src_mr.png"), os.path.join(W, f"{L}_mr.png"), "--gold", a.gold]), flush=True)

# 6. new GLB
out_glb = os.path.join(W, f"{L}_fixed.glb")
print(run([t("glb_replace_images.py"), a.glb, out_glb, "--base", final_base, "--mr", os.path.join(W, f"{L}_mr.png")]), flush=True)

if a.renders:
    run([t("tex_compare_render.py"), a.glb, R, f"{L}_orig", "--cam", cam], blender=True)
    run([t("tex_compare_render.py"), out_glb, R, f"{L}_fixed", "--cam", cam], blender=True)
print("[tex_fix] ok", out_glb, json.dumps(choice), flush=True)
