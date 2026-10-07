"""
미니맵 내 화살표 크기 비교(검수 2026-10-07 "빛·뿔 크기 같은 거 맞지?"): 연습 Studio(UiSandbox) Play에서 같은 기기·같은 자리로
빛 화살표, 뿔 화살표, 빛 +2du 안을 차례로 띄워 미니맵만 확대해 찍는다(PC 줄, 폰 줄).
결과: art/review/minimap_arrow_size_2026-10-07.jpg

  py tools/minimap_arrow_size.py
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
SHEET = os.path.join(ROOT, "art", "review", "minimap_arrow_size_2026-10-07.jpg")

FACTION = r'''
local p = game.Players:GetPlayers()[1]
p:SetAttribute("Faction", "%s")
return tostring(p:GetAttribute("Faction"))
'''

# my arrow: its size (+ extra du) and where the minimap is (screen px from the very top-left)
ME = r'''
local pg = game.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
local mm = pg:FindFirstChild("MainGui") and pg.MainGui:FindFirstChild("MiniMap", true)
local me = mm and mm:FindFirstChild("Me")
if not me then return "{}" end
local extra = %d
if extra ~= 0 then
	local base = me:GetAttribute("BaseW") or me.Size.X.Offset
	me:SetAttribute("BaseW", base)
	me.Size = UDim2.fromOffset(base + extra, base + extra)
elseif me:GetAttribute("BaseW") then
	me.Size = UDim2.fromOffset(me:GetAttribute("BaseW"), me:GetAttribute("BaseW"))
end
local probe = pg:FindFirstChild("ASProbe")
if not probe then
	probe = Instance.new("ScreenGui")
	probe.Name, probe.IgnoreGuiInset, probe.ResetOnSpawn = "ASProbe", true, false
	pcall(function() probe.ScreenInsets = Enum.ScreenInsets.None end)
	probe.Parent = pg
	task.wait(0.1)
end
local o = probe.AbsolutePosition
return game:GetService("HttpService"):JSONEncode({ Screen = { probe.AbsoluteSize.X, probe.AbsoluteSize.Y },
	Root = { mm.AbsolutePosition.X - o.X, mm.AbsolutePosition.Y - o.Y, mm.AbsoluteSize.X, mm.AbsoluteSize.Y },
	MePx = { me.AbsoluteSize.X, me.AbsoluteSize.Y }, Image = me.Image })
'''


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    from PIL import Image, ImageDraw
    rows = []
    with dv.sandbox() as c:
        for dev in ("pc", "phone"):
            name, w, h = dv.DEVICES[dev]
            dv.stop_play(c)
            dv.luau(c, dv.SET_DEVICE % (name, w, h), "Edit")
            c.call("start_stop_play", {"is_start": True})
            for _ in range(60):
                time.sleep(0.5)
                if "Client" in dv.state(c):
                    break
            time.sleep(6)
            dv.luau(c, dv.PICK % "Halo", "Server")
            time.sleep(5)
            dv.luau(c, qv.PLACE % (20, -20, 90), "Server")
            time.sleep(2)
            dv.luau(c, qv.PIN, "Client")
            tiles = []
            for label, faction, extra in (("Halo", "Halo", 0), ("Horns", "Horns", 0), ("Halo +2du", "Halo", 2)):
                dv.luau(c, FACTION % faction, "Server")
                time.sleep(1.5)
                info = json.loads(dv.luau(c, ME % extra, "Client").strip())
                img = qv.grab(c, f"as_{dev}_{label}")
                k = img.width / max(1, info["Screen"][0])
                x, y, bw, bh = (v * k for v in info["Root"])
                crop = img.crop((int(x), int(y), int(x + bw), int(y + bh))).resize((260, 260), Image.LANCZOS)
                tile = Image.new("RGB", (260, 282), (16, 20, 40))
                tile.paste(crop, (0, 22))
                ImageDraw.Draw(tile).text((5, 4), f"{dev} {label}  {info['MePx'][0]:.0f}px", fill=(255, 255, 255))
                tiles.append(tile)
                print(dev, label, info.get("MePx"))
            dv.luau(c, ME % 0, "Client")
            rows.append(tiles)
    sheet = Image.new("RGB", (3 * 260, 2 * 282), (0, 0, 0))
    for r, tiles in enumerate(rows):
        for i, t in enumerate(tiles):
            sheet.paste(t, (i * 260, r * 282))
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    sheet.save(SHEET, quality=90)
    print("sheet:", SHEET)


if __name__ == "__main__":
    main()
