"""
폰 [메뉴] 탭 확인(검수 2026-10-07: Roblox 위 버튼 줄 안의 [메뉴]는 탭이 닿지 않았음 → 터치에서는 아이콘 줄 오른쪽 끝):
연습 Studio(UiSandbox) Play, 폰 기기 흉내(749·844)에서 [메뉴] 위치를 재고, Studio MCP 마우스(기기 흉내에서는 탭)로
누른 뒤 펼침 칸이 열렸는지(펼침 사각형이 보이는 개수) 재고 앞·뒤를 찍는다. 다시 눌러 닫히는지도 본다.
결과: art/review/menu_tap_2026-10-07.jpg + docs/art/verification_2026-10-07/menu_tap_2026-10-07.json

  py tools/menu_tap_view.py [phone] [844]
내 연습 Play 안에서만 마우스를 쓴다(사용자 게임이 아님). 끝나면 Play를 멈추고 기기 흉내를 끈다.
주의(2026-10-07): 폰 기기 흉내에서는 MCP user_mouse_input의 위치가 맞지 않는다 - instance_path로 [메뉴]를 누르면
한 칸 왼쪽(지도)이 눌렸고, 좌표로는 아무것도 안 눌렸다. 그래서 탭 판정은 믿지 말고 [메뉴] 위치(위 버튼 줄 아래)와
PlayerGui:GetGuiObjectsAtPosition(가운데에 [메뉴] 말고 덮은 것이 없는지)로 본다. 진짜 탭은 폰/개발 1 Play에서.
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
RAW = os.path.join(ROOT, "build", "menu_tap_view")
SHEET = os.path.join(ROOT, "art", "review", "menu_tap_2026-10-07.jpg")
REPORT = os.path.join(ROOT, "docs", "art", "verification_2026-10-07", "menu_tap_2026-10-07.json")
MENU = "LocalPlayer.PlayerGui.MainGui.HUD.Buttons.TileMenu"

PROBE = r'''
local pg = game.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
local main = pg:FindFirstChild("MainGui")
local menu = main and main:FindFirstChild("TileMenu", true)
local fold = main and main:FindFirstChild("Fold", true)
local inset = game:GetService("GuiService"):GetGuiInset()
local out = { Inset = inset.Y }
if menu then
	out.Menu = { math.floor(menu.AbsolutePosition.X), math.floor(menu.AbsolutePosition.Y), math.floor(menu.AbsoluteSize.X),
		math.floor(menu.AbsoluteSize.Y) }
end
local shown = 0
if fold then
	for _, d in fold:GetDescendants() do
		if d:IsA("GuiButton") and d.Visible and d.AbsoluteSize.X > 4 then
			local p = d.AbsolutePosition - fold.AbsolutePosition
			if p.X >= -2 and p.X <= fold.AbsoluteSize.X then shown += 1 end
		end
	end
	out.FoldVisible = fold.Visible
end
out.FoldButtons = shown
return game:GetService("HttpService"):JSONEncode(out)
'''


def tap(c):
    return dv.text_of(c.call("user_mouse_input", {"datamodel_type": "Client", "actions": [
        {"action": "moveTo", "instance_path": MENU}, {"action": "mouseButtonClick", "mouse_button": "left"}]}))


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    devices = [a for a in sys.argv[1:] if a in dv.DEVICES] or ["phone", "844"]
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
            time.sleep(6)
            print(dev, "pick:", dv.luau(c, dv.PICK % "Halo", "Server").strip())
            time.sleep(5)
            for step in ("closed", "tap1", "tap2"):
                if step != "closed":
                    print(dev, step, tap(c)[:120])
                    time.sleep(1.2)
                probe = json.loads(dv.luau(c, PROBE, "Client").strip())
                img = qv.grab(c, f"mt_{dev}_{step}")
                path = os.path.join(RAW, f"{dev}_{step}.png")
                if img:
                    img.save(path)
                rows.append({"device": dev, "step": step, "probe": probe,
                             "file": os.path.relpath(path, ROOT).replace("\\", "/")})
                print(dev, step, probe)
    ok = []
    for dev in devices:
        r = {x["step"]: x["probe"] for x in rows if x["device"] == dev}
        below = r["closed"].get("Menu") and r["closed"]["Menu"][1] >= 0
        opened = r["tap1"].get("FoldButtons", 0) > r["closed"].get("FoldButtons", 0)
        closed = r["tap2"].get("FoldButtons", 0) <= r["closed"].get("FoldButtons", 0)
        ok.append({"device": dev, "menuBelowBar": bool(below), "tapOpens": opened, "tapCloses": closed})
    from PIL import Image, ImageDraw
    tiles = []
    for x in rows:
        f = os.path.join(ROOT, x["file"])
        if os.path.exists(f):
            im = Image.open(f).convert("RGB")
            im = im.resize((640, int(640 * im.height / im.width)))
            ImageDraw.Draw(im).text((6, 4), f'{x["device"]} {x["step"]} fold squares {x["probe"].get("FoldButtons")}',
                                   fill=(255, 255, 0))
            tiles.append(im)
    if tiles:
        cols = 3
        th = max(t.height for t in tiles)
        sheet = Image.new("RGB", (cols * 640, ((len(tiles) + cols - 1) // cols) * th))
        for i, t in enumerate(tiles):
            sheet.paste(t, ((i % cols) * 640, (i // cols) * th))
        sheet.save(SHEET, quality=86)
    with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"tool": "tools/menu_tap_view.py", "result": ok, "rows": rows}, f, ensure_ascii=False, indent=2)
    print("result:", ok, "sheet:", SHEET)


if __name__ == "__main__":
    main()
