"""Close-up cameras for the extra decorations (sign, shop window goods, roof glass) of tools/house_deco.py, 이미지 생성 3, 10/12.

  py tools/house_deco_closeups.py <name> [...]      -> build/deco/<name>/cams_extras.json, then renders with
  tools/skeleton_preview.py into build/deco/<name>/preview_extras/ (close_sign, close_shop, close_roof)
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BL = r"C:\Users\glori\Tools\blender-5.2.2-windows-x64\blender.exe"
for N in sys.argv[1:]:
    raw = json.load(open(os.path.join(ROOT, "build", "deco", N, "deco_raw.json"), encoding="utf-8"))
    parts = json.load(open(os.path.join(ROOT, "build", "skel_%s.json" % N)))
    yf = max(p["pos"][1] for p in parts if p["name"].startswith("front_")) + 0.4
    cams = {}
    sg = raw["pieces"].get("Sign")
    if sg:
        (x0, y0, z0), (x1, y1, z1) = sg["box"]
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        cams["close_sign"] = [[cx + 1.5, yf + 9.0, cz + 0.5], [cx, yf, cz], 42]
    if raw["pieces"].get("Display"):
        g = [p for p in parts if p["name"] == "Shop_Glass"]
        if g:
            gx, gy, gz = g[0]["pos"]
            cams["close_shop"] = [[gx + 1.0, gy + 8.0, gz + 1.0], [gx, gy, gz + 0.5], 45]
    if raw["pieces"].get("RoofGlass"):
        b = [p for p in parts if p["name"] == "Skylight_Base"]
        if b:
            bx, by, bz = b[0]["pos"]
            cams["close_roof"] = [[bx + 7.0, by + 11.0, bz + 7.0], [bx, by, bz + 1.5], 42]
    if not cams:
        print("[close] %s: nothing to shoot" % N)
        continue
    cf = os.path.join(ROOT, "build", "deco", N, "cams_extras.json")
    json.dump(cams, open(cf, "w"), indent=1)
    out = os.path.join(ROOT, "build", "deco", N, "preview_extras")
    r = subprocess.run([BL, "--background", "--factory-startup", "--python", os.path.join(ROOT, "tools", "skeleton_preview.py"), "--",
                        out, "--parts", os.path.join(ROOT, "build", "skel_%s.json" % N), "--glb",
                        os.path.join(ROOT, "art", "models", "tripo", "house_deco", N, N + "_deco.glb"), "--cams", cf, "--marble", "cream",
                        "--views", "front", "--px", "700"], capture_output=True, text=True, encoding="utf-8", errors="replace")
    print("[close] %s: %s -> %s" % (N, sorted(cams), out), flush=True)
