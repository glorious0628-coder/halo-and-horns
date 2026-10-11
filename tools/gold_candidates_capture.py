"""Photograph the gold candidates built by tools/gold_candidates_test.luau (이미지 개발 2026-10-11).
  STUDIO_NAME=UiSandbox py tools/gold_candidates_capture.py   (UiSandbox open in Edit; build the boards first)
For each candidate key (BASE, A, B, C) it moves that candidate's parts to the middle of the SUN / SHADE boards (the other sets go
400 studs up), then screen_capture (camera_position / look_at_position) in the main Halo-town light (tools/halo_light_sim.luau, C2c day / night; sun + shade + a warm PointLight at night).
Saves art/review/imgdev/goldcand/g3_<day|night>_<SUN|SHADE>_<key>.png (centre 960 px of the 1920x656 capture). Lighting is restored by tools/halo_light_restore.luau; the values used go to goldcand/lighting.txt. Build the boards (gold_candidates_test.luau) AFTER the day light is set (the SUN board faces the sun direction at build time).
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

KEYS = ["BASE", "D", "E", "F", "H"]   # same order as CANDS in gold_candidates_test.luau
SIM = open(os.path.join(ROOT, "tools", "halo_light_sim.luau"), encoding="utf-8").read()
RESTORE = open(os.path.join(ROOT, "tools", "halo_light_restore.luau"), encoding="utf-8").read()
PREP = """local root=workspace.GoldCandTest
for _,g in ipairs(root:GetDescendants()) do if g:IsA("SurfaceGui") then g:Destroy() end end
for _,p in ipairs(root:GetChildren()) do if p:IsA("BasePart") and not p:GetAttribute("O") then p:SetAttribute("O",p.CFrame) end end
return "prepped" """
FOCUS = """local root=workspace.GoldCandTest
local key="%s"
local CX=%s
for _,p in ipairs(root:GetChildren()) do
  if p:IsA("BasePart") and p:GetAttribute("O") then
    local o=p:GetAttribute("O")
    local board=string.sub(p.Name,1,3)=="SUN" and "SUN" or "SHADE"
    local wall=root[board.."_Wall"]:GetAttribute("O")
    local k=string.match(p.Name,"^[A-Z]+_([A-Za-z]+)_")
    if p.Name==board.."_Wall" then p.CFrame=o
    elseif k==key then p.CFrame=wall*CFrame.new(-CX[key],0,0)*wall:ToObjectSpace(o)
    else p.CFrame=o*CFrame.new(0,400,0) end
  end
end
local out={}
for _,board in ipairs({"SUN","SHADE"}) do
  local base=root[board.."_Wall"]:GetAttribute("O")
  local cam=(base*CFrame.new(0,-1,-17)).Position
  local lk=(base*CFrame.new(0,-1,0)).Position
  out[board]={cam={cam.X,cam.Y,cam.Z},look={lk.X,lk.Y,lk.Z}}
end
return game:GetService("HttpService"):JSONEncode(out)"""
LAMP = """local root=workspace.GoldCandTest
local old=root:FindFirstChild("NightLamp") if old then old:Destroy() end
local p=Instance.new("Part") p.Name="NightLamp" p.Anchored=true p.CanCollide=false p.Transparency=1 p.Size=Vector3.one
p.CFrame=root.SUN_Wall:GetAttribute("O")*CFrame.new(0,3,-9) p.Parent=root
local l=Instance.new("PointLight") l.Color=Color3.fromRGB(255,214,150) l.Brightness=3 l.Range=40 l.Parent=p return 1"""


CX_LUA = "{" + ",".join(f"{k}={-8 * len(KEYS) + 16 * (i + 0.5)}" for i, k in enumerate(KEYS)) + "}"


def main():
    out_dir = os.path.join(ROOT, "art", "review", "imgdev", "goldcand")
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

        lua(PREP)
        lines = []
        for tn in ("day", "night"):
            lines.append(lua(SIM.replace('local CAND, PHASE = "%s", "%s"', 'local CAND, PHASE = "C2c", "' + tn + '"')))      # main Halo-town light (Neutral/Night x ZoneLook HaloTown C2c)
            if tn == "night":
                lua(LAMP)
            for key in KEYS:
                cams = json.loads(lua(FOCUS % (key, CX_LUA)))
                for b in ("SUN", "SHADE"):
                    if tn == "night" and b == "SHADE":
                        continue
                    shot(f"g3_{tn}_{b}_{key}", cams[b]["cam"], cams[b]["look"])
        lua('local f=workspace.GoldCandTest:FindFirstChild("NightLamp") if f then f:Destroy() end return 1')
        lines.append(lua(RESTORE))
        with open(os.path.join(out_dir, "lighting.txt"), "w", encoding="utf-8") as f:
            f.write(chr(10).join(lines) + chr(10))
    finally:
        c.close()


if __name__ == "__main__":
    main()
