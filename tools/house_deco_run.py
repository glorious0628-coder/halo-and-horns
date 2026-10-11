"""One house's Tripo decorations end to end (SPEC A23-125 step 1 -> 2), 이미지 생성 3, 10/11.

  py tools/house_deco_run.py <name> [--metal knocker,hinge] [--no-preview] [--size 1024]

  1. tools/house_deco.py      cut the Tripo HD pieces (tools/house_deco/<name>.json) + round / mirror fix + fit to the slots
     (+ tools/roof_fit.py for an octagonal dome)
  2. tools/piece_fix.py       slivers / crumbs out, tiles joined, each piece's own C/N/R/M maps
                              -> art/models/tripo/house_deco/<name>/
  3. tools/metal_ornaments.py the exact metal parts the Tripo piece is swapped for (--metal: item types of
                              build/skel_<name>_ornaments.json, default knocker; snapped onto the new leaf)
  4. tools/house_deco_place.py template copies (tower caps, lanterns) onto their slots, maps shared
  5. tools/glb_merge.py       -> art/models/tripo/house_deco/<name>/<name>_deco.glb (skeleton frame, origin = skeleton origin)
  6. tools/skeleton_preview.py  skeleton (cream) + decorations: build/deco/<name>/preview/ (front, q34, side, back, close-ups)
Blender: C:/Users/glori/Tools/blender-5.2.2-windows-x64/blender.exe (--background --factory-startup).
"""
import argparse
import json
import os
import subprocess
import sys

ROOT = os.environ.get("HH_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # HH_ROOT: run a private copy of tools/
TOOLS = os.path.dirname(os.path.abspath(__file__))
BL = r"C:\Users\glori\Tools\blender-5.2.2-windows-x64\blender.exe"
ap = argparse.ArgumentParser()
ap.add_argument("name")
ap.add_argument("--metal", default=None, help="item types for metal_ornaments (default: the params \"metal\" list)")
ap.add_argument("--no-preview", action="store_true")
ap.add_argument("--size", default="1024")
a = ap.parse_args()
N = a.name
B = os.path.join(ROOT, "build", "deco", N)
ART = os.path.join(ROOT, "art", "models", "tripo", "house_deco", N)
os.makedirs(B, exist_ok=True)
os.makedirs(ART, exist_ok=True)


def blender(script, *args):
    cmd = [BL, "--background", "--factory-startup", "--python", os.path.join(TOOLS, script), "--"] + list(args)
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    lines = [l for l in r.stdout.splitlines() if l.startswith("[") and not l.startswith("[gltf") or "Error" in l or "Traceback" in l]
    print("\n".join("  " + l for l in lines[-40:]), flush=True)
    if r.returncode != 0 or any("Traceback" in l for l in r.stdout.splitlines() + r.stderr.splitlines()):
        print(r.stderr[-3000:])
        sys.exit("[run] %s failed" % script)


raw = os.path.join(B, "deco_raw.glb")
rep = os.path.join(B, "deco_raw.json")
print("[run] 1 cut + fix", flush=True)
blender("house_deco.py", N, os.path.join(TOOLS, "house_deco", N + ".json"), raw, "--report", rep)
R = json.load(open(rep, encoding="utf-8"))
PRM = json.load(open(os.path.join(TOOLS, "house_deco", N + ".json"), encoding="utf-8"))
# name patterns for piece_fix --only: "_" first, or "Dome" would also hit "HaloDomeHouse_.."
dome_slot = PRM.get("dome", {}).get("slot", "Dome")
# leaf, caps, lanterns are rebuilt in house_deco (exact shapes, Tripo paint / size): only the dome + extras go through piece_fix
pieces = ["_" + dome_slot] + ["_" + e["name"] for e in PRM.get("extra", [])]
PR_BIG = ["_" + e["name"] for e in PRM.get("extra", []) if e.get("big")]
if "roof_fit" in R:                                         # octagonal dome: eaves onto the plan octagon, ribs on corners
    plan = os.path.join(B, "roof_plan.json")
    json.dump(R["roof_fit"]["plan"], open(plan, "w"), indent=1)
    raw2 = os.path.join(B, "deco_raw_roof.glb")
    print("[run] 1b roof_fit", flush=True)
    blender("roof_fit.py", raw, raw2, plan, "--name", R["roof_fit"]["name"], "--report", os.path.join(ART, "roof_fit_report.json"),
            "--corners", "radius")
    raw = raw2
fixed = os.path.join(B, "deco_fix.glb")
print("[run] 2 piece_fix", flush=True)
# Tripo's low-poly domes / leaves are made of long triangles: no sliver / pale cut (it made holes), crumbs still go
big = [p for p in pieces if p == "_" + dome_slot or p in PR_BIG]
small = [p for p in pieces if p not in big]
mid = os.path.join(B, "deco_fix_big.glb")
if dome_slot in R["pieces"] or "Dome" in R["pieces"] or PR_BIG:
    blender("piece_fix.py", raw, mid, ART, "--only", *big, "--size", a.size, "--force-size", "--sliver", "1e9", "--pale-area", "1e9")
else:
    mid = raw
if small:
    blender("piece_fix.py", mid, fixed, ART, "--only", *small, "--size", "512", "--sliver", "1e9", "--pale-area", "1e9")
else:
    import shutil
    shutil.copyfile(mid, fixed)
print("[run] 3 metal", flush=True)
orn = json.load(open(os.path.join(ROOT, "build", "skel_%s_ornaments.json" % N)))
want = [t for t in a.metal.split(",") if t] if a.metal is not None else PRM.get("metal", ["knocker"])
items = [dict(it) for it in orn["items"] if it["type"] in want]
hw = list(R.get("hardware_at", []))
for it in items:                       # knockers on the Tripo knocker spots (flattened paint under the exact ring)
    if it["type"] == "knocker" and hw:
        it["pos"] = hw.pop(0)
parts = [fixed]
if items:
    spec = os.path.join(B, "metal_spec.json")
    json.dump({"items": items}, open(spec, "w"), indent=1)
    metal = os.path.join(B, "metal.glb")
    single = "Leaf" in R["pieces"] and not R["pieces"]["Leaf"].get("double")
    blender("metal_ornaments.py", spec, metal, *(["--snap", fixed, "%s_Leaf" % N] if single else []))
    parts.append(metal)
placed = os.path.join(B, "deco_placed.glb")
print("[run] 4 place copies", flush=True)
blender("house_deco_place.py", fixed, rep, placed)
final = os.path.join(ART, N + "_deco.glb")
print("[run] 5 merge", flush=True)
blender("glb_merge.py", final, placed, *parts[1:])
if not a.no_preview:
    print("[run] 6 preview", flush=True)
    cams = json.load(open(os.path.join(ROOT, "build", "skel_%s_cams.json" % N)))
    camf = os.path.join(B, "cams_door.json")                       # the sheet uses front, 3/4 and the door close-up only
    json.dump({k: v for k, v in cams.items() if k == "close_door"}, open(camf, "w"), indent=1)
    blender("skeleton_preview.py", os.path.join(B, "preview"), "--parts", os.path.join(ROOT, "build", "skel_%s.json" % N),
            "--glb", final, "--cams", camf, "--marble", "cream", "--ortho", "30", "--cz", "12", "--views", "front,q34",
            "--px", "900")
print("[run] ok", final, flush=True)
