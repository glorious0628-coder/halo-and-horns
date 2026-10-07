"""
오프닝(Intro) 폰 화면 확인(이미지 개발, 2026-10-07 사용자 지적: Skip 모서리 조각, 자막이 Skip 뒤로 들어감):
연습 Studio(UiSandbox) Play 시작 직후(새 데이터 = 오프닝이 돈다) 기기마다 몇 장 찍고, Skip 버튼과 자막의 화면 위치·
크기·글자 맞음(TextFits)·겹침을 잰다. Skip 둘레를 4배로 확대한 조각도 시트에 붙인다.
결과: art/review/intro_view_2026-10-07.jpg + docs/art/verification_2026-10-07/intro_view_2026-10-07.json

  py tools/intro_view.py [phone] [844] [pc]
STUDIO_NAME은 UiSandbox로 고정(dv.sandbox가 먼저 확인). 끝나면(오류가 나도) Play를 멈추고 기기 흉내를 끈다.
"""

import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ["STUDIO_NAME"] = "UiSandbox"  # practice Studio only: forced before studio_mcp is imported (via device_view)
import device_view as dv  # noqa: E402
import quest_marker_view as qv  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "build", "intro_view")
SHEET = os.path.join(ROOT, "art", "review", "intro_view_2026-10-07.jpg")
REPORT = os.path.join(ROOT, "docs", "art", "verification_2026-10-07", "intro_view_2026-10-07.json")

PROBE = r'''
local pg = game.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
local probe = pg:FindFirstChild("IVProbe")
if not probe then
	probe = Instance.new("ScreenGui")
	probe.Name, probe.IgnoreGuiInset, probe.ResetOnSpawn = "IVProbe", true, false
	pcall(function() probe.ScreenInsets = Enum.ScreenInsets.None end)
	probe.Parent = pg
	task.wait(0.1)
end
local o = probe.AbsolutePosition
local function rect(g)
	return { math.floor(g.AbsolutePosition.X - o.X), math.floor(g.AbsolutePosition.Y - o.Y), math.floor(g.AbsoluteSize.X),
		math.floor(g.AbsoluteSize.Y) }
end
local out = { Screen = { probe.AbsoluteSize.X, probe.AbsoluteSize.Y } }
for _, d in pg:GetDescendants() do
	if d.Name == "Skip" and d:IsA("GuiObject") and d.Visible then
		out.Skip = rect(d)
		out.SkipClass = d.ClassName
		out.SkipKids = {}
		for _, k in d:GetChildren() do
			table.insert(out.SkipKids, k.ClassName .. ":" .. k.Name)
		end
		if d:IsA("ImageButton") or d:IsA("ImageLabel") then
			out.SkipSlice = { d.ScaleType.Name, tostring(d.SliceCenter), d.SliceScale }
		end
	elseif d.Name == "Subtitle" and d:IsA("TextLabel") then
		out.Sub = rect(d)
		out.SubText = d.Text
		out.SubFits = d.TextFits
		out.SubBounds = { math.floor(d.TextBounds.X), math.floor(d.TextBounds.Y) }
	end
end
if out.Skip and out.Sub then
	local a, b = out.Skip, out.Sub
	local ix = math.max(0, math.min(a[1] + a[3], b[1] + b[3]) - math.max(a[1], b[1]))
	local iy = math.max(0, math.min(a[2] + a[4], b[2] + b[4]) - math.max(a[2], b[2]))
	out.Overlap = { ix, iy }
end
return game:GetService("HttpService"):JSONEncode(out)
'''


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    devices = [a for a in sys.argv[1:] if a in dv.DEVICES] or ["phone", "844", "pc"]
    os.makedirs(RAW, exist_ok=True)
    rows = []
    with dv.sandbox() as c:
        for dev in devices:
            name, w, h = dv.DEVICES[dev]
            dv.stop_play(c)
            print(dev, "device:", dv.luau(c, dv.SET_DEVICE % (name, w, h), "Edit").strip())
            c.call("start_stop_play", {"is_start": True})
            for _ in range(60):
                time.sleep(0.5)
                if "Client" in dv.state(c):
                    break
            for i, wait in enumerate((5.5, 4.0, 4.0)):
                time.sleep(wait)
                probe = json.loads(dv.luau(c, PROBE, "Client").strip())
                img = qv.grab(c, f"iv_{dev}_{i}")
                path = os.path.join(RAW, f"{dev}_{i}.png")
                if img:
                    img.save(path)
                rows.append({"device": dev, "shot": i, "probe": probe,
                             "file": os.path.relpath(path, ROOT).replace("\\", "/")})
                print(dev, i, "skip", probe.get("Skip"), "sub", probe.get("Sub"), repr(probe.get("SubText")),
                      "fits", probe.get("SubFits"), "overlap", probe.get("Overlap"))
            print(dev, "skip kids", rows[-1]["probe"].get("SkipKids"), rows[-1]["probe"].get("SkipSlice"))
    from PIL import Image, ImageDraw
    tiles = []
    for r in rows:
        f = os.path.join(ROOT, r["file"])
        if not os.path.exists(f):
            continue
        img = Image.open(f).convert("RGB")
        k = img.width / max(1, r["probe"].get("Screen", [img.width])[0])
        full = img.resize((640, int(640 * img.height / img.width)))
        tile = Image.new("RGB", (640 + 330, max(full.height, 170)), (16, 20, 40))
        tile.paste(full, (0, 0))
        sk = r["probe"].get("Skip")
        if sk:
            x, y, w, h = (v * k for v in sk)
            crop = img.crop((int(x - 8 * k), int(y - 8 * k), int(x + w + 8 * k), int(y + h + 8 * k)))
            z = 320 / max(1, crop.width)
            crop = crop.resize((320, max(1, int(crop.height * z))), Image.NEAREST)
            tile.paste(crop, (645, 5))
        d = ImageDraw.Draw(tile)
        d.text((5, 5), f'{r["device"]} #{r["shot"]} overlap {r["probe"].get("Overlap")}', fill=(255, 255, 0))
        tiles.append(tile)
    if tiles:
        sheet = Image.new("RGB", (tiles[0].width, sum(t.height for t in tiles)), (0, 0, 0))
        y = 0
        for t in tiles:
            sheet.paste(t, (0, y))
            y += t.height
        os.makedirs(os.path.dirname(SHEET), exist_ok=True)
        sheet.save(SHEET, quality=86)
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"tool": "tools/intro_view.py", "rows": rows}, f, ensure_ascii=False, indent=2)
    print("sheet:", SHEET, "report:", REPORT)


if __name__ == "__main__":
    main()
