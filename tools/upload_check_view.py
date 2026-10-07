"""
올린 그림이 게임 안에서 보이는지 확인(이미지 개발, 2026-10-07): 연습 Studio(UiSandbox) Play(PC 1280x720)에서
  1. Config.UIArt.Parts의 키들을 밝은 판·어두운 판 위 ImageLabel로 띄워 찍고, 각 그림이 다 불러졌는지(IsLoaded) 잰다
  2. (선택) --at x,z,yaw 자리에 서서 바닥(지형 텍스처)을 찍는다
결과: art/review/<name>.jpg + docs/art/verification_2026-10-07/<name>.json

  py tools/upload_check_view.py --name upload_check_2026-10-07 JobBoard JobCard BtnKind BtnSneaky JobTag --at 0,400,180
STUDIO_NAME은 UiSandbox로 고정(dv.sandbox가 먼저 확인). 끝나면(오류가 나도) Play를 멈추고 기기 흉내를 끈다.
"""

import argparse
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ["STUDIO_NAME"] = "UiSandbox"  # practice Studio only: forced before studio_mcp is imported (via device_view)
import device_view as dv  # noqa: E402
import quest_marker_view as qv  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SHOW = r'''
local HttpService = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")
local lp = game.Players.LocalPlayer
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local parts = Config.UIArt and Config.UIArt.Parts or {}
local keys = HttpService:JSONDecode('%s')
local pg = lp:FindFirstChildOfClass("PlayerGui")
local old = pg:FindFirstChild("UploadCheck")
if old then old:Destroy() end
local sg = Instance.new("ScreenGui")
sg.Name, sg.ResetOnSpawn, sg.IgnoreGuiInset, sg.DisplayOrder = "UploadCheck", false, true, 100
sg.Parent = pg
local out = { Items = {} }
local W = 1280 / #keys
for i, key in keys do
	local def = parts[key]
	local id = type(def) == "table" and def.Id or ""
	for row, bg in { Color3.fromRGB(240, 240, 240), Color3.fromRGB(22, 24, 34) } do
		local f = Instance.new("Frame")
		f.BackgroundColor3, f.BorderSizePixel = bg, 0
		f.Position, f.Size = UDim2.fromOffset((i - 1) * W, 40 + (row - 1) * 330), UDim2.fromOffset(W, 320)
		f.Parent = sg
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency, img.Image, img.ScaleType = 1, id, Enum.ScaleType.Fit
		img.Position, img.Size = UDim2.fromOffset(8, 8), UDim2.new(1, -16, 1, -16)
		img.Parent = f
		if row == 1 then
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency, t.Text, t.TextSize, t.Font = 1, key, 16, Enum.Font.GothamBold
			t.Position, t.Size, t.TextColor3 = UDim2.fromOffset((i - 1) * W, 8), UDim2.fromOffset(W, 24), Color3.new(1, 1, 1)
			t.Parent = sg
			out.Items[key] = { Id = id, Label = img }
		end
	end
end
local labels = {}
for _, v in out.Items do table.insert(labels, v.Label) end
pcall(function() ContentProvider:PreloadAsync(labels) end)
task.wait(2)
for key, v in out.Items do
	out.Items[key] = { Id = v.Id, Loaded = v.Label.IsLoaded }
end
return HttpService:JSONEncode(out)
'''

HIDE = r'''
local pg = game.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
local g = pg and pg:FindFirstChild("UploadCheck")
if g then g:Destroy() end
return "hidden"
'''


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("keys", nargs="+")
    ap.add_argument("--name", required=True)
    ap.add_argument("--at", help="x,z,yaw to stand at for a floor shot")
    ap.add_argument("--faction", default="Horns")
    a = ap.parse_args()
    raw_dir = os.path.join(ROOT, "build", "upload_check")
    os.makedirs(raw_dir, exist_ok=True)
    shots, report = [], {"tool": "tools/upload_check_view.py", "keys": a.keys}
    with dv.sandbox() as c:
        dv.stop_play(c)
        print("device:", dv.luau(c, dv.SET_DEVICE % dv.DEVICES["pc"], "Edit").strip())
        c.call("start_stop_play", {"is_start": True})
        for _ in range(60):
            time.sleep(0.5)
            if "Client" in dv.state(c):
                break
        time.sleep(6)
        print("pick:", dv.luau(c, dv.PICK % a.faction, "Server").strip())
        time.sleep(5)
        res = json.loads(dv.luau(c, SHOW % json.dumps(a.keys), "Client").strip())
        report["images"] = res["Items"]
        print("images:", res["Items"])
        img = qv.grab(c, "upload_check_images")
        if img:
            p = os.path.join(raw_dir, "images.png")
            img.save(p)
            shots.append(p)
        dv.luau(c, HIDE, "Client")
        if a.at:
            x, z, yaw = (float(v) for v in a.at.split(","))
            print("place:", dv.luau(c, qv.PLACE % (x, z, yaw), "Server").strip())
            time.sleep(3)
            dv.luau(c, qv.PIN, "Client")
            time.sleep(1)
            img = qv.grab(c, "upload_check_floor")
            if img:
                p = os.path.join(raw_dir, "floor.png")
                img.save(p)
                shots.append(p)
            dv.luau(c, 'game:GetService("RunService"):UnbindFromRenderStep("QMViewPin") return "ok"', "Client")
    from PIL import Image
    tiles = [Image.open(p).convert("RGB") for p in shots]
    tiles = [t.resize((960, int(960 * t.height / t.width)), Image.LANCZOS) for t in tiles]
    sheet = Image.new("RGB", (960, sum(t.height for t in tiles)), (0, 0, 0))
    y = 0
    for t in tiles:
        sheet.paste(t, (0, y))
        y += t.height
    out = os.path.join(ROOT, "art", "review", a.name + ".jpg")
    sheet.save(out, quality=86, optimize=True)
    rep = os.path.join(ROOT, "docs", "art", "verification_2026-10-07", a.name + ".json")
    os.makedirs(os.path.dirname(rep), exist_ok=True)
    report["sheet"] = os.path.relpath(out, ROOT).replace("\\", "/")
    report["allLoaded"] = all(v.get("Loaded") for v in report["images"].values())
    with open(rep, "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print("sheet:", out, "report:", rep, "allLoaded", report["allLoaded"])


if __name__ == "__main__":
    main()
