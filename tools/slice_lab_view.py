"""
9조각(slice) 실험(이미지 개발, 2026-10-07): Roblox는 9조각을 작게 줄일 때 모서리 조각만 제대로 줄이고, 둥근 끝이
위·아래 '변' 조각에 걸리면 끝이 잘리거나 네모 조각이 생긴다(오프닝 Skip 알약). 그래서 FitHeight 부품마다
지금 값과 '가운데 2 px 띠' 값(Rect(x0, H/2-1, x1, H/2+1): 둥근 끝 전체가 모서리 조각에 들어감)을 같은 크기로
나란히 그려 연습 Studio(UiSandbox) Play에서 찍는다.
결과: art/review/slice_lab_2026-10-07.jpg + docs/art/verification_2026-10-07/slice_lab_2026-10-07.json

  py tools/slice_lab_view.py
STUDIO_NAME은 UiSandbox로 고정. 끝나면(오류가 나도) Play를 멈추고 기기 흉내를 끈다.
"""

import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ["STUDIO_NAME"] = "UiSandbox"  # practice Studio only: forced before studio_mcp is imported (via device_view)
import device_view as dv  # noqa: E402
import quest_marker_view as qv  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "Config.luau")
SHEET = os.path.join(ROOT, "art", "review", "slice_lab_2026-10-07.jpg")
REPORT = os.path.join(ROOT, "docs", "art", "verification_2026-10-07", "slice_lab_2026-10-07.json")
PART = re.compile(r'^\s*(\w+) = \{ Id = "(rbxassetid://\d+)", Size = Vector2\.new\((\d+), (\d+)\), '
                  r'Slice = Rect\.new\((\d+), (\d+), (\d+), (\d+)\), FitHeight = true')


def parts():
    out = []
    for line in open(CONFIG, encoding="utf-8"):
        m = PART.match(line)
        if m:
            name, aid, w, h, x0, y0, x1, y1 = m.groups()
            w, h, x0, y0, x1, y1 = map(int, (w, h, x0, y0, x1, y1))
            out.append({"Name": name, "Id": aid, "W": w, "H": h, "Now": [x0, y0, x1, y1],
                        "Band": [x0, h // 2 - 1, x1, h // 2 + 1]})
    return out


LAB = r'''
local HttpService = game:GetService("HttpService")
local list = HttpService:JSONDecode('%s')
local pg = game.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
local old = pg:FindFirstChild("SliceLab")
if old then old:Destroy() end
local sg = Instance.new("ScreenGui")
sg.Name, sg.ResetOnSpawn, sg.DisplayOrder, sg.IgnoreGuiInset = "SliceLab", false, 100, true
sg.Parent = pg
local bg = Instance.new("Frame")
bg.Size, bg.BackgroundColor3 = UDim2.fromScale(1, 1), Color3.fromRGB(40, 60, 90)
bg.Parent = sg
local col = 0
for i, p in list do
	local y = 6 + ((i - 1) %% 12) * 58
	local x0 = 6 + math.floor((i - 1) / 12) * 640
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency, t.TextColor3, t.TextSize, t.Font = 1, Color3.new(1, 1, 1), 13, Enum.Font.GothamBold
	t.Position, t.Size, t.Text = UDim2.fromOffset(x0, y), UDim2.fromOffset(110, 44), p.Name
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = bg
	for k, rect in { p.Now, p.Band } do
		for j, h in { 24, 44 } do
			local w = math.floor(h * 3.6)
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Image = p.Id
			img.ScaleType = Enum.ScaleType.Slice
			img.SliceCenter = Rect.new(rect[1], rect[2], rect[3], rect[4])
			img.SliceScale = h / p.H
			img.Size = UDim2.fromOffset(w, h)
			img.Position = UDim2.fromOffset(x0 + 112 + (k - 1) * 260 + (j - 1) * 92, y + (44 - h) / 2)
			if j == 2 then img.Position = UDim2.fromOffset(x0 + 112 + (k - 1) * 260 + 92, y) end
			img.Parent = bg
		end
	end
end
return "lab " .. #list
'''


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    plist = parts()
    print(len(plist), "parts:", [p["Name"] for p in plist])
    with dv.sandbox() as c:
        dv.stop_play(c)
        dv.luau(c, dv.SET_DEVICE % dv.DEVICES["pc"], "Edit")
        c.call("start_stop_play", {"is_start": True})
        for _ in range(60):
            time.sleep(0.5)
            if "Client" in dv.state(c):
                break
        time.sleep(4)
        print(dv.luau(c, LAB % json.dumps(plist), "Client").strip())
        time.sleep(3)
        img = qv.grab(c, "slice_lab")
    if img:
        os.makedirs(os.path.dirname(SHEET), exist_ok=True)
        img.convert("RGB").save(SHEET, quality=90)
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"tool": "tools/slice_lab_view.py", "columns": "name | now h24 | now h44 | band h24 | band h44",
                   "parts": plist}, f, ensure_ascii=False, indent=2)
    print("sheet:", SHEET)


if __name__ == "__main__":
    main()
