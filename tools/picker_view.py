"""
진영·직업 고르기 새 그림(A23-57) 확인: 연습 Studio(UiSandbox) Play에서 기기마다
  1. 진영 고르기(빛·뿔 2장, Faction None)
  2. 직업 고르기 빛(남·여), 뿔(남·여)
을 찍고, 화면에 보이는 글자 칸이 다 들어갔는지(TextFits)와 카드 크기를 잰다.
결과: art/review/picker_view_2026-10-07.jpg + docs/art/verification_2026-10-07/picker_view_2026-10-07.json

  py tools/picker_view.py [pc] [phone] [844] [--tag hq]   (--tag: its own sheet / report names)
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
RAW = os.path.join(ROOT, "build", "picker_view")
SHEET = os.path.join(ROOT, "art", "review", "picker_view_2026-10-07.jpg")
REPORT = os.path.join(ROOT, "docs", "art", "verification_2026-10-07", "picker_view_2026-10-07.json")

# the player back to the first-join state the faction picker waits for (the opening counts as seen)
FRESH = r'''
local p = game.Players:GetPlayers()[1]
if not p then return "no player" end
for _ = 1, 40 do
	if p:GetAttribute("DataLoaded") == true then break end
	task.wait(0.25)
end
p:SetAttribute("IntroSeen", true)
p:SetAttribute("Faction", "None")
p:SetAttribute("ClassChosen", false)
p:LoadCharacter() -- a respawn ends a running opening (Intro.Start: CharacterAdded -> Finish)
return "fresh " .. tostring(p:GetAttribute("Faction"))
'''

# a faction picked, the class not yet (the class picker opens); gender = the picture set
SIDE = r'''
local p = game.Players:GetPlayers()[1]
p:SetAttribute("Faction", "%s")
p:SetAttribute("ClassChosen", false)
p:SetAttribute("CharacterGender", "%s")
return tostring(p:GetAttribute("Faction")) .. " " .. tostring(p:GetAttribute("CharacterGender"))
'''

# every visible text of the open picker: fits, size, words; the cards' boxes (screen px from the very top-left)
PROBE = r'''
local HttpService = game:GetService("HttpService")
local pg = game.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
local probe = pg:FindFirstChild("PVProbe")
if not probe then
	probe = Instance.new("ScreenGui")
	probe.Name, probe.IgnoreGuiInset, probe.ResetOnSpawn = "PVProbe", true, false
	pcall(function() probe.ScreenInsets = Enum.ScreenInsets.None end)
	probe.Parent = pg
	task.wait(0.1)
end
local o = probe.AbsolutePosition
local main = pg:FindFirstChild("MainGui")
local function shown(g)
	while g and g ~= main do
		if g:IsA("GuiObject") and not g.Visible then return false end
		g = g.Parent
	end
	return true
end
local out = { Screen = { probe.AbsoluteSize.X, probe.AbsoluteSize.Y }, Texts = {}, Cards = {} }
for _, name in { "FactionPicker", "ClassPicker" } do
	local root = main and main:FindFirstChild(name, true)
	if root and root:IsA("GuiObject") and root.Visible then
		out.Open = name
		for _, d in root:GetDescendants() do
			if d:IsA("TextLabel") and d.Text ~= "" and shown(d) and d.TextTransparency < 0.9 then
				table.insert(out.Texts, { Name = d.Name, Text = d.Text, Fits = d.TextFits,
					Px = math.floor(d.TextBounds.Y + 0.5), Box = { math.floor(d.AbsoluteSize.X), math.floor(d.AbsoluteSize.Y) } })
			elseif d:IsA("ImageLabel") and (d.Name == "Art" or d.Name == "Bg" or d.Name == "Character") and shown(d) then
				table.insert(out.Cards, { Name = d.Parent.Name .. "/" .. d.Name, Image = d.Image,
					Rect = { d.AbsolutePosition.X - o.X, d.AbsolutePosition.Y - o.Y, d.AbsoluteSize.X, d.AbsoluteSize.Y } })
			end
		end
	end
end
return HttpService:JSONEncode(out)
'''


def shot(c, dev, mode, rows):
    probe = json.loads(dv.luau(c, PROBE, "Client").strip())
    img = qv.grab(c, f"pv_{dev}_{mode}")
    path = os.path.join(RAW, f"{dev}_{mode}.png")
    if img:
        img.save(path)
    bad = [t for t in probe.get("Texts", []) if not t.get("Fits")]
    rows.append({"device": dev, "mode": mode, "file": os.path.relpath(path, ROOT).replace("\\", "/"), "probe": probe,
                 "notFitting": bad})
    print(dev, mode, "open", probe.get("Open"), "texts", len(probe.get("Texts", [])), "not fitting",
          [(t["Name"], t["Text"]) for t in bad][:6])


def run(c, devices, rows):
    os.makedirs(RAW, exist_ok=True)
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
        print(dev, dv.luau(c, FRESH, "Server").strip())
        time.sleep(4.5)
        shot(c, dev, "faction", rows)
        for side in ("Halo", "Horns"):
            for g in ("M", "F"):
                print(dev, dv.luau(c, SIDE % (side, g), "Server").strip())
                time.sleep(3.0)
                shot(c, dev, f"class_{side}_{g}", rows)


def sheet(rows):
    from PIL import Image, ImageDraw, ImageFont
    tiles = []
    for r in rows:
        f = os.path.join(ROOT, r["file"])
        if not os.path.exists(f):
            continue
        img = Image.open(f).convert("RGB")
        img = img.resize((640, int(640 * img.height / img.width)), Image.LANCZOS)
        d = ImageDraw.Draw(img)
        try:
            font = ImageFont.truetype("arial.ttf", 15)
        except OSError:
            font = ImageFont.load_default()
        d.rectangle([0, 0, 640, 20], fill=(16, 20, 40))
        d.text((5, 2), f'{r["device"]} {r["mode"]}  not fitting: {len(r["notFitting"])}', fill=(255, 255, 255), font=font)
        tiles.append(img)
    if not tiles:
        return None
    th = max(t.height for t in tiles)
    cols = 2
    out = Image.new("RGB", (cols * 640, ((len(tiles) + 1) // cols) * th), (0, 0, 0))
    for i, t in enumerate(tiles):
        out.paste(t, ((i % cols) * 640, (i // cols) * th))
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    out.save(SHEET, quality=86, optimize=True)
    return SHEET


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    devices = [a for a in sys.argv[1:] if a in dv.DEVICES] or ["pc", "phone"]
    if "--tag" in sys.argv:  # a later check keeps the committed evidence: its own sheet / report / raw folder
        global RAW, SHEET, REPORT
        tag = sys.argv[sys.argv.index("--tag") + 1]
        RAW = os.path.join(ROOT, "build", f"picker_view_{tag}")
        SHEET = os.path.join(ROOT, "art", "review", f"picker_view_{tag}_2026-10-07.jpg")
        REPORT = os.path.join(ROOT, "docs", "art", "verification_2026-10-07", f"picker_view_{tag}_2026-10-07.json")
    rows = []
    with dv.sandbox() as c:
        run(c, devices, rows)
    path = sheet(rows)
    report = {"tool": "tools/picker_view.py", "sheet": os.path.relpath(SHEET, ROOT).replace("\\", "/"), "rows": rows}
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print("sheet:", path, "report:", REPORT)


if __name__ == "__main__":
    main()
