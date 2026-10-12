"""Shadow-free 3D-render 4 views of one Halo-town prop (이미지 생성 3, 10/13; SPEC A23-150 1, A23-151; 최종 검수 queue).

  py tools/ns_draw.py <id> --front <old 2D> [--left <old>] [--right <old>] [--back <old>] [--faces front,left,right,back]
                      [--note "extra words for the object"] [--sheet-only]

Front first: ref1 = the old approved 2D (turned to a straight front view). Then each other face: ref1 = the old 2D of that
face (the viewpoint), ref2 = the NEW front (the look) - the direction is never written in words (10/12 test: words flipped
it), only "the same viewpoint as ref1". When a face has no old 2D, the prompt names the turn from ref1 = new front.
Prompts -> art/prompts/<id>_<face>_ns.txt, images -> art/out/s2/noshadow/<id>_<face>_ns.png through tools/codex_image.py
(the user's ChatGPT plan; exit 3 = usage over -> stop, Firefly High). Sheet old | new -> art/review/img3/noshadow/<id>_ns.jpg.
"""
import argparse
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIGHT = ("Keep the 3D look: real volume, rounded edges, soft gentle form shading so every shape reads as 3D, same smooth "
         "material as the ref. Lighting: soft, even studio light from all around (like a bright light box). NO cast shadows, "
         "NO shadow on the ground or floor, NO contact shadows, NO ambient-occlusion darkening in crevices, NO dark shadowed "
         "side, no strong glare highlights, no glowing light that lights the surroundings. Colours stay bright and true to the "
         "design. Plain light grey background, no floor. No text, no extra objects, no ray patterns. Kid-friendly. Square image.")
FRONT = ("ref1 is an approved design of a prop for a kid-friendly Roblox game.%s Redraw the SAME object exactly (same shapes, "
         "parts, count of ornaments, colours, proportions, materials) as a 3D-rendered toy-like object, seen straight-on from "
         "the FRONT at mid-height, perfectly centered, whole object in frame with a margin. If ref1 is angled or from above, turn "
         "it to a straight-on front view. " + LIGHT)
SIDE = ("ref1 shows the viewpoint: an older drawing of this object seen from one side. ref2 is the NEW approved front view of "
        "the object (the look to keep).%s Draw the SAME object as ref2 (same shapes, parts, colours, proportions, materials) "
        "seen from the same side as ref1, but as a strict elevation: camera level at mid-height, at a right angle to that side, "
        "no 3/4 angle and no top-down tilt even if ref1 has one; whole object centered, the same size and distance as ref2. "
        "Match ref2's look, not ref1's colours or shading. " + LIGHT)
TURN = {"left": "seen straight-on from its left side (90 degrees from ref1's front)",
        "right": "seen straight-on from its right side (90 degrees from ref1's front)",
        "back": "seen straight-on from the back (180 degrees from ref1's front)"}
NOOLD = ("ref1 is the new approved front view of an object for a kid-friendly Roblox game.%s Draw the SAME object exactly "
         "(same shapes, parts, colours, proportions, materials) as a 3D-rendered toy-like object %s, at mid-height, whole object "
         "in frame, centered, the same size and distance as ref1. " + LIGHT)

ap = argparse.ArgumentParser()
ap.add_argument("id")
for f in ("front", "left", "right", "back"):
    ap.add_argument("--" + f, default="")
ap.add_argument("--faces", default="front,left,right,back")
ap.add_argument("--note", default="")
ap.add_argument("--sheet-only", action="store_true")
a = ap.parse_args()
note = (" " + a.note.strip()) if a.note else ""
OUT = "art/out/s2/noshadow/%s_%%s_ns.png" % a.id
new_front = OUT % "front"
if not a.sheet_only:
    for face in a.faces.split(","):
        old = getattr(a, face)
        if face == "front":
            prompt, refs = FRONT % note, [old]
        elif old:
            prompt, refs = SIDE % note, [old, new_front]
        else:
            prompt, refs = NOOLD % (note, TURN[face]), [new_front]
        if len(prompt) > 1900:
            sys.exit("prompt too long")
        pf = "art/prompts/%s_%s_ns.txt" % (a.id, face)
        open(os.path.join(ROOT, pf), "w", encoding="utf-8", newline="\n").write(prompt)
        cmd = [sys.executable, os.path.join(ROOT, "tools", "codex_image.py"), "--prompt-file", pf, "--out", OUT % face]
        for r in refs:
            if not r or not os.path.isfile(os.path.join(ROOT, r)):
                sys.exit("missing ref %r for %s" % (r, face))
            cmd += ["--ref", r]
        print("[ns]", a.id, face, "refs", refs, flush=True)
        r = subprocess.run(cmd, cwd=ROOT)
        if r.returncode != 0:
            print("[ns] codex_image exit", r.returncode, "(3 = ChatGPT usage over -> Firefly High)", flush=True)
            sys.exit(r.returncode)

font = ImageFont.truetype("malgun.ttf", 18)
C = 300
faces = ["front", "left", "right", "back"]
S = Image.new("RGB", (40 + 4 * (C + 8), 64 + 2 * (C + 28)), (34, 34, 38))
d = ImageDraw.Draw(S)
d.text((8, 6), "%s — 옛 2D(위) | 새 그림자 없는 3D 렌더(아래)  앞·왼·오른·뒤" % a.id, fill=(240, 240, 240), font=font)
for j, face in enumerate(faces):
    for i, p in enumerate([getattr(a, face), OUT % face]):
        x, y = 40 + j * (C + 8), 40 + i * (C + 28)
        d.text((x, y), ("옛 " if i == 0 else "새 ") + face, fill=(255, 210, 120), font=font)
        fp = os.path.join(ROOT, p) if p else ""
        if fp and os.path.isfile(fp):
            im = Image.open(fp).convert("RGB")
            im.thumbnail((C, C))
            S.paste(im, (x, y + 24))
os.makedirs(os.path.join(ROOT, "art", "review", "img3", "noshadow"), exist_ok=True)
S.save(os.path.join(ROOT, "art", "review", "img3", "noshadow", "%s_ns.jpg" % a.id), quality=88)
print("[ns] sheet art/review/img3/noshadow/%s_ns.jpg" % a.id)
