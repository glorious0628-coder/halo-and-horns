"""
Monster texture colour fix (A23-73 ④ colour + AO, 0 credits). Uses the shared tools as they are (tex_compare_render.py,
concept_cam_fit.py, tex_color_match.py) plus tools/img2/bake_ao_ground.py. Work dir: build/montex/<Kind>/ (git-ignored).

  py tools/img2/mon_tex.py extract [Kind ...]        textures out of the GLBs + in-game texture -> game_base.png, stats
  py tools/img2/mon_tex.py prep <Kind>                camera fit to the concept (cam.json) + renders of the current texture
  py tools/img2/mon_tex.py ao <Kind> [dist]           ground AO bake -> ao_ground.png (1024)
  py tools/img2/mon_tex.py fix <Kind> [--bands green,gold] [--ao-strength 0.45] [--headroom 0.83] [--value-mix 1.0]
                                     [--sat 1.0] [--label fix] [--base game_base.png] [--ao ao_ground.png]
        colour match to the concept (+ AO) -> <label>_cm.png, then 'headroom': if the 95th percentile of the brightest
        channel is above --headroom, the whole texture is scaled down to it, so the game light (meadow ~x1.2) does not
        clip it to a flat neon colour. --sat scales saturation after that. Output <label>.png (1024, upload size).
  py tools/img2/mon_tex.py render <Kind> <label> <texture.png>   renders match / game / back34 with that texture
  py tools/img2/mon_tex.py noback <Kind>              Slime/BigSlime: no AO + speck clean-up where the back face was erased
        -> ao_ground_nb.png, game_base_nb.png (then: fix ... --base game_base_nb.png --ao ao_ground_nb.png)

- Every GLB here faces +X in Blender (Tripo API): renders use --front +x, the camera grid is centred on az 90.
- BigSlime = the Slime cube mesh with a blue texture: it reuses the Slime camera (its 'concept' is the monster icon).
- Paths given to Blender are absolute (a bare relative path ends up under C:\\build\\).
"""
import io
import json
import os
import shutil
import struct
import subprocess
import sys

import cv2
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")).replace("\\", "/") + "/"
T = ROOT + "tools/"
OUT = ROOT + "build/montex/"
BL = r"C:\Users\glori\Tools\blender-5.2.2-windows-x64\blender.exe"
ENV = dict(os.environ, PYTHONIOENCODING="utf-8")
M = {  # kind: (glb, concept, in-game base texture or None = the GLB's own)
    "Slime": ("MonsterSlimeCube_raw.glb", "art/out/CON_SlimeCube.png", "art/models/tripo/MonsterSlimeCube_tex_noback.png"),
    "BigSlime": ("MonsterSlimeCube_raw.glb", "art/out/IconMonBigSlime_src.png", "art/models/tripo/BigSlimeCube_tex_blue_noback.png"),
    "PumpkinSlime": ("MonsterPumpkinSlime_raw.glb", "art/out/CON_PumpkinSlime.png", None),
    "LittleGhost": ("MonsterLittleGhost_raw.glb", "art/out/CON_LittleGhost.png", None),
    "GhostMinion": ("MonsterGhostMinion_raw.glb", "art/out/s2/CON_GhostMinion_A1_src.png", None),
    "GhostKing": ("MonsterGhostKing_raw.glb", "art/out/s2/CON_GhostKing_A2_src.png", None),
    "PumpkinKing": ("MonsterPumpkinKing_raw.glb", "art/out/CON_PumpkinKing.png", None),
    "PetBabySlime": ("PetBabySlime_raw.glb", "art/out/Pet_BabySlime.png", None),
}
sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def run(args, blender=False):
    cmd = ([BL, "--background", "--factory-startup", "--python-exit-code", "1", "--python", args[0], "--"] + args[1:]) if blender \
        else [sys.executable] + args
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", env=ENV)
    lines = [ln for ln in (r.stdout + r.stderr).splitlines() if ln.strip()]
    if r.returncode != 0:
        raise SystemExit("FAILED: " + " ".join(cmd) + "\n" + "\n".join(lines[-6:]))
    return lines


def glb_images(path):
    b = open(path, "rb").read()
    o, ch = 12, []
    while o < len(b):
        cl, ct = struct.unpack("<II", b[o:o + 8])
        ch.append((ct, o + 8, cl))
        o += 8 + cl
    j = json.loads(b[ch[0][1]:ch[0][1] + ch[0][2]])
    bs = next(c for c in ch if c[0] == 0x004E4942)[1]
    out = {}
    for mi, m in enumerate(j.get("materials", [])):
        pbr = m.get("pbrMetallicRoughness", {})
        for k, ref in {"base": pbr.get("baseColorTexture"), "mr": pbr.get("metallicRoughnessTexture"), "normal": m.get("normalTexture")}.items():
            if ref:
                bv = j["bufferViews"][j["images"][j["textures"][ref["index"]]["source"]]["bufferView"]]
                out[f"{k}{mi or ''}"] = Image.open(io.BytesIO(b[bs + bv.get("byteOffset", 0):bs + bv.get("byteOffset", 0) + bv["byteLength"]]))
        out[f"factors{mi or ''}"] = {"metal": pbr.get("metallicFactor", 1.0), "rough": pbr.get("roughnessFactor", 1.0)}
    return out


def hsv(rgb8):
    x = cv2.cvtColor(rgb8, cv2.COLOR_RGB2HSV_FULL).astype(np.float32)
    return x[..., 0] / 255 * 360, x[..., 1] / 255, x[..., 2] / 255


def concept_fg(rgb):
    c = 12
    corners = np.concatenate([rgb[:c, :c].reshape(-1, 3), rgb[:c, -c:].reshape(-1, 3), rgb[-c:, :c].reshape(-1, 3), rgb[-c:, -c:].reshape(-1, 3)])
    return np.abs(rgb.astype(np.int16) - np.median(corners, 0)).max(-1) > 14


def body_stats(rgb, mask):
    """Main body colour = the most common saturated 30-degree hue window."""
    h, s, v = hsv(rgb)
    sat = mask & (s > 0.2)
    if sat.sum() < 50:
        body = mask
        lo = -1
    else:
        hist = np.histogram(h[sat], bins=36, range=(0, 360))[0]
        k = int(np.argmax(np.convolve(np.r_[hist, hist[:2]], np.ones(3), "valid")[:36]))
        lo = (k * 10) % 360
        body = sat & (((h - lo) % 360) < 30)
    q = lambda a, p: round(float(np.percentile(a[body], p)), 2)
    return {"hue_window": lo, "H": round(float(np.median(h[body])), 1), "S": q(s, 50), "V": q(v, 50), "V10": q(v, 10), "V90": q(v, 90),
            "rgb": [int(x) for x in np.median(rgb[body], 0)], "share": round(float(body.sum() / max(mask.sum(), 1)), 2)}


def cmd_extract(kinds):
    for kind in kinds or list(M):
        glb, con, game = M[kind]
        d = OUT + kind + "/"
        os.makedirs(d, exist_ok=True)
        ims = glb_images(ROOT + "art/models/tripo/" + glb)
        for k, im in ims.items():
            if isinstance(im, Image.Image):
                im.convert("RGB").save(d + f"src_{k}.png")
        base = Image.open(ROOT + game).convert("RGB") if game else ims["base"].convert("RGB")
        base.save(d + "game_base.png")
        t = np.asarray(base)
        c = np.asarray(Image.open(ROOT + con).convert("RGB"))
        st = {"texture": body_stats(t, t.max(-1) > 20), "concept": body_stats(c, concept_fg(c)), "factors": ims.get("factors"),
              "game_tex_size": base.size}
        json.dump(st, open(d + "stats.json", "w"), indent=1)
        print(kind, json.dumps(st))


def cmd_prep(kind):
    glb, con, _ = M[kind]
    GLB, CON, W = ROOT + "art/models/tripo/" + glb, ROOT + con, OUT + kind + "/"
    cam = W + "cam.json"
    if kind == "BigSlime" and not os.path.exists(cam):
        shutil.copy(OUT + "Slime/cam.json", cam)
    if not os.path.exists(cam):
        run([T + "tex_compare_render.py", GLB, W, "fit", "--masks", W + "masks", "--mask-grid", "60:120:15,0:40:10,50"], blender=True)
        run([T + "concept_cam_fit.py", CON, W + "masks", cam])
        c0 = json.load(open(cam))
        g = f"{c0['az'] - 8:g}:{c0['az'] + 8:g}:4,{max(-5, c0['el'] - 6):g}:{c0['el'] + 6:g}:3,{c0['lens']:g}/{c0['lens'] * 1.5:g}"
        run([T + "tex_compare_render.py", GLB, W, "fit", "--masks", W + "masks2", "--mask-grid", g], blender=True)
        run([T + "concept_cam_fit.py", CON, W + "masks2", cam])
    print(kind, "camera", json.load(open(cam)), flush=True)
    cmd_render(kind, "now", W + "game_base.png")


def cmd_render(kind, label, tex):
    glb = M[kind][0]
    W = OUT + kind + "/"
    run([T + "tex_compare_render.py", ROOT + "art/models/tripo/" + glb, W + "r", label, "--cam", W + "cam.json", "--tex", os.path.abspath(tex),
         "--views", "match,game,back34", "--front", "+x"], blender=True)
    print(kind, "rendered", label, flush=True)


def cmd_ao(kind, dist="0.25"):
    W = OUT + kind + "/"
    print("\n".join(run([T + "img2/bake_ao_ground.py", ROOT + "art/models/tripo/" + M[kind][0], W + "ao_ground.png", "1024", "48", dist], blender=True)[-1:]))


def cmd_noback(kind):
    """Slime cubes: the back face was erased from the texture (tools/back_face_erase.py) but its bumps are still in the
    mesh, so a baked AO would outline them again. Mask = where the in-game texture differs from the GLB's own texture
    (the erased eyes/blush), grown 18 px. Inside it: AO -> 1 (ao_ground_nb.png) and left-over dark specks are inpainted
    (game_base_nb.png). BigSlime uses the same mesh/UVs, so it borrows the Slime mask."""
    W = OUT + kind + "/"
    if kind == "BigSlime":
        m = np.asarray(Image.open(OUT + "Slime/noback_raw.png").convert("L")) > 127
    else:
        src = np.asarray(Image.open(W + "src_base.png").convert("RGB").resize((1024, 1024), Image.LANCZOS)).astype(int)
        gm = np.asarray(Image.open(W + "game_base.png").convert("RGB").resize((1024, 1024), Image.LANCZOS)).astype(int)
        m = cv2.morphologyEx((np.abs(src - gm).max(-1) > 40).astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)) > 0
    Image.fromarray((m * 255).astype(np.uint8)).save(W + "noback_raw.png")
    grown = cv2.dilate(m.astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (37, 37))) > 0
    Image.fromarray((grown * 255).astype(np.uint8)).save(W + "noback_mask.png")
    soft = cv2.GaussianBlur(grown.astype(np.float32), (0, 0), 4)
    ao = np.asarray(Image.open(W + "ao_ground.png").convert("L").resize((1024, 1024), Image.BILINEAR)).astype(np.float32) / 255
    Image.fromarray(((ao * (1 - soft) + soft) * 255 + 0.5).astype(np.uint8)).save(W + "ao_ground_nb.png")
    base = np.asarray(Image.open(W + "game_base.png").convert("RGB").resize((1024, 1024), Image.LANCZOS))
    lum = base.astype(np.float32).mean(-1)
    local = cv2.medianBlur(base, 15).astype(np.float32).mean(-1)
    h, sat_, _ = hsv(base)
    hmed = cv2.medianBlur(((h / 360) * 255).astype(np.uint8), 15).astype(np.float32) / 255 * 360
    off_hue = (np.abs((h - hmed + 180) % 360 - 180) > 25) & (sat_ > 0.15)  # left-over blush / mouth pink on the jelly
    specks = grown & ((lum < 0.8 * local) | off_hue)
    specks = cv2.dilate(specks.astype(np.uint8), np.ones((3, 3), np.uint8))
    Image.fromarray(cv2.inpaint(base, specks, 5, cv2.INPAINT_TELEA)).save(W + "game_base_nb.png")
    print(kind, "noback mask px", int(grown.sum()), "specks", int(specks.sum()), flush=True)


def cmd_fix(kind, opts):
    W = OUT + kind + "/"
    label = opts.get("label", "fix")
    cm = W + f"{label}_cm.png"
    base = W + opts.get("base", "game_base.png")
    args = [T + "tex_color_match.py", base, ROOT + M[kind][1], cm, "--bands", opts.get("bands", "gold,blue,red,green,purple"),
            "--value-mix", opts.get("value-mix", "1.0"), "--sharpen", "0", "--size", "1024"]
    ao = W + opts.get("ao", "ao_ground.png")
    if opts.get("ao-strength", "0.45") != "0" and os.path.exists(ao):
        args += ["--ao", ao, "--ao-strength", opts.get("ao-strength", "0.45")]
    for ln in run(args):
        print("  " + ln)
    rgb = np.asarray(Image.open(cm).convert("RGB")).astype(np.float32) / 255
    used = rgb.max(-1) > 0.08
    p95 = float(np.percentile(rgb.max(-1)[used], 95))
    head = float(opts.get("headroom", "1.0"))
    k = min(1.0, head / p95)
    rgb = rgb * k
    sat = float(opts.get("sat", "1.0"))
    if sat != 1.0:
        lum = (rgb * np.array([0.299, 0.587, 0.114], np.float32)).sum(-1, keepdims=True)
        rgb = lum + (rgb - lum) * sat
    out = Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8))
    out.save(W + f"{label}.png")
    t = np.asarray(out)
    c = np.asarray(Image.open(ROOT + M[kind][1]).convert("RGB"))
    st = {"headroom_scale": round(k, 3), "p95_before": round(p95, 3), "sat": sat, "fixed": body_stats(t, t.max(-1) > 20),
          "concept": body_stats(c, concept_fg(c))}
    json.dump(st, open(W + f"{label}_stats.json", "w"), indent=1)
    print(kind, label, json.dumps(st), flush=True)


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a:
        raise SystemExit(__doc__)
    if a[0] == "extract":
        cmd_extract(a[1:])
    elif a[0] == "prep":
        cmd_prep(a[1])
    elif a[0] == "ao":
        cmd_ao(a[1], *(a[2:3]))
    elif a[0] == "noback":
        cmd_noback(a[1])
    elif a[0] == "render":
        cmd_render(a[1], a[2], a[3])
    elif a[0] == "fix":
        o, i = {}, 2
        while i < len(a):
            o[a[i].lstrip("-")] = a[i + 1]
            i += 2
        cmd_fix(a[1], o)
    else:
        raise SystemExit(__doc__)
