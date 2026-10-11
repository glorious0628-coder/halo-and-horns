"""Photograph the boards built by tools/marble_smooth_test.luau (이미지 개발 2026-10-11).
  STUDIO_NAME=UiSandbox py tools/marble_smooth_capture.py   (UiSandbox open in Edit; build the boards AFTER the day light is set)
Sets the main Halo-town light (tools/halo_light_sim.luau, C2c day / night; warm PointLight at night), photographs each column (PLAIN / BLOCK /
SMOOTH) on the SUN and SHADE boards by day and the SUN board at night, restores the light (tools/halo_light_restore.luau).
Saves art/review/imgdev/marblesmooth/m_<day|night>_<SUN|SHADE>_<key>.png (centre 960 px of the capture) and lighting.txt.
Needs the boards built first: the Luau returns the camera json; run it with `py tools/marble_smooth_capture.py --build` to do both steps.
"""
import base64
import io
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from PIL import Image  # noqa: E402
from studio_mcp import Client  # noqa: E402

SIM = open(os.path.join(ROOT, "tools", "halo_light_sim.luau"), encoding="utf-8").read()
RESTORE = open(os.path.join(ROOT, "tools", "halo_light_restore.luau"), encoding="utf-8").read()
BUILD = open(os.path.join(ROOT, "tools", "marble_smooth_test.luau"), encoding="utf-8").read()
LAMP = """local root=workspace.MarbleSmoothTest
local old=root:FindFirstChild("NightLamp") if old then old:Destroy() end
local p=Instance.new("Part") p.Name="NightLamp" p.Anchored=true p.CanCollide=false p.Transparency=1 p.Size=Vector3.one
p.CFrame=root.SUN_Wall.CFrame*CFrame.new(0,3,-9) p.Parent=root
local l=Instance.new("PointLight") l.Color=Color3.fromRGB(255,214,150) l.Brightness=3 l.Range=40 l.Parent=p return 1"""


def main():
    out_dir = os.path.join(ROOT, "art", "review", "imgdev", "marblesmooth")
    os.makedirs(out_dir, exist_ok=True)
    c = Client()
    c.start()
    try:
        def lua(code):
            r = c.call("execute_luau", {"code": code, "datamodel_type": "Edit"})
            return "".join(p.get("text", "") for p in r.get("content", []))

        def shot(name, cam, look):
            res = c.call("screen_capture", {"capture_id": name, "camera_position": cam, "look_at_position": look})
            for part in res.get("content", []):
                if part.get("type") == "image":
                    img = Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB")
                    w, h = img.size
                    img.crop((w // 2 - 480, 0, w // 2 + 480, h)).save(os.path.join(out_dir, name + ".png"))

        lines = []
        for tn in ("day", "night"):
            lines.append(lua(SIM.replace('local CAND, PHASE = "%s", "%s"', 'local CAND, PHASE = "C2c", "' + tn + '"')))
            if tn == "day":
                cams = json.loads(lua(BUILD.replace("__MODE__", "build"))[-20000:].strip().splitlines()[-1])
            if tn == "night":
                lua(LAMP)
            for board in ("SUN", "SHADE"):
                if tn == "night" and board == "SHADE":
                    continue
                for col in cams[board]:
                    shot(f"m_{tn}_{board}_{col['key']}", col["cam"], col["look"])
        lua('local f=workspace.MarbleSmoothTest:FindFirstChild("NightLamp") if f then f:Destroy() end return 1')
        lines.append(lua(RESTORE))
        with open(os.path.join(out_dir, "lighting.txt"), "w", encoding="utf-8") as f:
            f.write(chr(10).join(lines) + chr(10))
    finally:
        c.close()


if __name__ == "__main__":
    main()
