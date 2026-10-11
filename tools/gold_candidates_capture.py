"""Photograph the gold candidates built by tools/gold_candidates_test.luau (이미지 개발 2026-10-11).
  STUDIO_NAME=UiSandbox py tools/gold_candidates_capture.py   (UiSandbox open in Edit; build the boards first)
For each candidate key (BASE, A, B, C) it moves that candidate's parts to the middle of the SUN / SHADE boards (the other sets go
400 studs up), then screen_capture (camera_position / look_at_position) at 14:00 (sun + shade) and 20:30 (+ a warm PointLight).
Saves art/review/imgdev/goldcand/g3_<day|night>_<SUN|SHADE>_<key>.png (centre 960 px of the 1920x656 capture). Lighting is put back to 14:00.
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

KEYS = ["BASE", "A", "B", "C"]
LIGHT = """local L=game:GetService("Lighting")
L.ClockTime=%s
L.Brightness=1.76
L.Ambient=Color3.fromRGB(76,79,82)
L.OutdoorAmbient=Color3.fromRGB(101,108,112)
L.ExposureCompensation=-0.37
return "ok" """
PREP = """local root=workspace.GoldCandTest
for _,g in ipairs(root:GetDescendants()) do if g:IsA("SurfaceGui") then g:Destroy() end end
for _,p in ipairs(root:GetChildren()) do if p:IsA("BasePart") and not p:GetAttribute("O") then p:SetAttribute("O",p.CFrame) end end
return "prepped" """
FOCUS = """local root=workspace.GoldCandTest
local key="%s"
local CX={BASE=-24,A=-8,B=8,C=24}
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
        for t, tn in ((14, "day"), (20.5, "night")):
            lua(LIGHT % t)
            if tn == "night":
                lua(LAMP)
            for key in KEYS:
                cams = json.loads(lua(FOCUS % key))
                for b in ("SUN", "SHADE"):
                    if tn == "night" and b == "SHADE":
                        continue
                    shot(f"g3_{tn}_{b}_{key}", cams[b]["cam"], cams[b]["look"])
        lua('local f=workspace.GoldCandTest:FindFirstChild("NightLamp") if f then f:Destroy() end return 1')
        lua(LIGHT % 14)
    finally:
        c.close()


if __name__ == "__main__":
    main()
