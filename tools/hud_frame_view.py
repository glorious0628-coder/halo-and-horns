"""
A23-74 HUD 틀 확인(검수 2026-10-07 고칠 것 4개: PC 물약 붙이기, 폰 749 Lv 글자, 힌트 말풍선 글자 잘림 "buttor",
폰 아래 묶음 가운데): 연습 Studio(UiSandbox) Play에서 기기(PC 1280x720 · 폰 749x361 · 844x390)마다
  lv1   : 진영 고른 직후(Lv 1) - 아래 가운데 묶음(얼굴 · Lv 줄 · HP|MP · XP · 아이콘 줄, PC는 물약 두 개가 줄 끝에 붙음)
  learn : Lv 5 - Q를 배우는 순간(빨간 알림 + Q 위 말풍선 PC "Press Q" / 폰 "Tap the new button")
  lv25  : Lv 25 - Q · Z · X 모두, 'Lv 25 · Power …' 줄이 바 위에서 넘치지 않는지
  atk   : HUD.Hint("Attack") 말풍선(Studio 전용 HintPreview: PC "Click to hit!", 폰 "Tap to hit!")
를 찍고 숫자로도 잰다: 말풍선 글자 TextBounds <= 글자 칸(안 잘림), Lv 줄 글자 <= 줄 칸, PC 물약과 아이콘 줄 사이(px),
폰 묶음의 왼쪽 여유(조이스틱 쉼 자리 0.2W부터)와 오른쪽 여유(고리 버튼까지), 0.3W 왼쪽 아래(조이스틱 자리)에 누르는 것 없음.
결과: build/hud_frame_view/<dev>_<view>.png, art/review/hud_frame_2026-10-07/sheet.jpg (+ 말풍선 · 아래 묶음 확대),
docs/art/verification_2026-10-07/hud_frame_2026-10-07.json

  py tools/hud_frame_view.py [pc] [phone] [844]
연습 Studio 전용(device_view.sandbox): 끝나면(오류가 나도) Play를 멈추고 기기 흉내를 끈다. 마우스 · 키보드 입력 없음.
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
RAW = os.path.join(ROOT, "build", "hud_frame_view")
OUT_DIR = os.path.join(ROOT, "art", "review", "hud_frame_2026-10-07")
REPORT = os.path.join(ROOT, "docs", "art", "verification_2026-10-07", "hud_frame_2026-10-07.json")

# the server's level (the client's HUD / SkillBar read the Level attribute; a slot opening while playing is the learn
# moment). DataLoaded / ClassChosen were set by device_view.PICK
LEVEL = r'''
local p = game.Players:GetPlayers()[1]
if not p then return "no player" end
p:SetAttribute("Level", %d)
p:SetAttribute("TutorialStep", 99) -- banners are not held (first [Claim] done)
return "level " .. tostring(p:GetAttribute("Level"))
'''

SET_ATTR = r'''
game.Players.LocalPlayer:SetAttribute("%s", %s)
return "%s"
'''

# what the screen shows (client, real px inside MainGui): hint bubbles with their text box and rendered bounds, the
# power line, the bottom-centre group, the combat buttons, the thumbstick / jump button of Roblox's TouchGui
PROBE = r'''
local HttpService = game:GetService("HttpService")
local lp = game.Players.LocalPlayer
local pg = lp:FindFirstChildOfClass("PlayerGui")
local main = pg and pg:FindFirstChild("MainGui")
if not main then return "{}" end
local sc = main:FindFirstChildOfClass("UIScale")
local origin = main.AbsolutePosition
local function shown(g)
	while g and g ~= pg do
		if g:IsA("GuiObject") and not g.Visible then return false end
		if g:IsA("LayerCollector") and not g.Enabled then return false end
		g = g.Parent
	end
	return true
end
local function rect(g)
	local p = g.AbsolutePosition - origin
	return { math.floor(p.X * 10 + 0.5) / 10, math.floor(p.Y * 10 + 0.5) / 10, math.floor(g.AbsoluteSize.X * 10 + 0.5) / 10,
		math.floor(g.AbsoluteSize.Y * 10 + 0.5) / 10 }
end
local out = { Scale = sc and sc.Scale or 1, W = main.AbsoluteSize.X, H = main.AbsoluteSize.Y,
	Level = lp:GetAttribute("Level"), Hints = {}, Tiles = {}, Items = {}, Touch = {} }
for _, d in main:GetDescendants() do
	if d:IsA("GuiObject") and shown(d) then
		local name = d.Name
		if name:sub(1, 4) == "Hint" and name ~= "HintGlow" then
			local t = d:FindFirstChild("Text")
			if t and t:IsA("TextLabel") then
				table.insert(out.Hints, { Name = name, Rect = rect(d), Text = t.Text, Box = rect(t),
					Bounds = { t.TextBounds.X, t.TextBounds.Y }, Fits = t.TextFits, Size = t.TextSize })
			end
		elseif name:sub(1, 4) == "Tile" and name ~= "TileMenu" and d:IsA("GuiButton") then -- [Menu] sits in the top bar
			table.insert(out.Tiles, { Name = name, Rect = rect(d) })
		elseif name == "Portrait" or name == "XPBar" or name == "HPBar" or name == "MPBar" or name == "HPPotion"
			or name == "MPPotion" or name == "Attack" or name == "Auto" or name == "SkillQ" or name == "SkillZ"
			or name == "SkillX" or name == "Menu" then
			out.Items[name] = out.Items[name] or rect(d)
		elseif name == "PowerLine" then
			local pw, pouch = d:FindFirstChild("Power"), d:FindFirstChild("Pouch")
			out.PowerLine = { Rect = rect(d), Text = pw and pw.Text or "", PowerRect = pw and rect(pw) or false,
				Bounds = pw and { pw.TextBounds.X, pw.TextBounds.Y } or false, Pouch = pouch and pouch.Visible and pouch.Text or false }
		elseif name == "Announce" or name == "BannerAlert" then
			local t = d:FindFirstChild("Text", true)
			out.Banner = { Rect = rect(d), Text = t and t:IsA("TextLabel") and t.Text or "" }
		end
	end
end
-- the war meter's bar row (the meter above its Info line, shields included) and every NEW! tag on screen
local war = main:FindFirstChild("WarMeter", true)
local info = war and war:FindFirstChild("Info")
if war and info and war:IsA("GuiObject") and info:IsA("GuiObject") then
	local r = rect(war)
	out.WarBar = { r[1], r[2], r[3], math.floor((info.AbsolutePosition.Y - war.AbsolutePosition.Y) * 10 + 0.5) / 10 }
end
out.NewTags = {}
for _, d in main:GetDescendants() do
	if d.Name == "NewTag" and d:IsA("GuiObject") and shown(d) then
		table.insert(out.NewTags, { Parent = d.Parent and d.Parent.Name or "", Rect = rect(d) })
	end
end
local touch = pg:FindFirstChild("TouchGui")
if touch then
	for _, d in touch:GetDescendants() do
		if d:IsA("GuiObject") and shown(d) and (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.AbsoluteSize.X > 10 then
			table.insert(out.Touch, { Name = d.Name, Rect = rect(d) })
		end
	end
end
return HttpService:JSONEncode(out)
'''

VIEWS = ["lv1", "learn", "lv25", "atk"]


def probe(c):
    raw = dv.luau(c, PROBE, "Client").strip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {"raw": raw[:300]}


def checks(dev, view, p):
    """named results from one probe (real px); True = passes"""
    res = {}
    for h in p.get("Hints", []):
        box, b = h["Box"], h["Bounds"]
        res[f'hint {h["Name"]} "{h["Text"]}" fits'] = bool(h.get("Fits")) and b[0] <= box[2] + 0.5 and b[1] <= box[3] + 0.5
    wb = p.get("WarBar")
    for t in p.get("NewTags", []):
        r = t["Rect"]
        clear = not wb or not (r[0] < wb[0] + wb[2] and r[0] + r[2] > wb[0] and r[1] < wb[1] + wb[3] and r[1] + r[3] > wb[1])
        res[f'NEW! tag on {t["Parent"]} clear of the war bar'] = clear
    pl = p.get("PowerLine")
    bars = [p.get("Items", {}).get(k) for k in ("HPBar", "MPBar", "XPBar")]
    if pl and pl.get("Bounds") and all(bars):
        right = max(r[0] + r[2] for r in bars)
        res[f'power line "{pl["Text"]}" inside the bars'] = pl["PowerRect"][0] + pl["Bounds"][0] <= right + 0.5
    items, tiles = p.get("Items", {}), p.get("Tiles", [])
    W = p.get("W", 0)
    if dev == "pc" and tiles and items.get("HPPotion"):
        last = max(t["Rect"][0] + t["Rect"][2] for t in tiles)
        gap = items["HPPotion"][0] - last
        res[f"pc potions attached to the tile row (gap {gap:.1f} px)"] = 0 <= gap <= 16
    if dev != "pc" and tiles and items.get("Portrait"):
        left = min([t["Rect"][0] for t in tiles] + [items["Portrait"][0]])
        right = max([t["Rect"][0] + t["Rect"][2] for t in tiles] + [items[k][0] + items[k][2] for k in ("HPBar", "MPBar",
                                                                                                        "XPBar") if items.get(k)])
        ring = [items[k] for k in ("HPPotion", "MPPotion", "Attack", "SkillQ", "SkillZ", "SkillX") if items.get(k)]
        # the ring buttons level with the bars and the row (HudLayout's limit: between the power line's top and the
        # row's bottom)
        top = pl["Rect"][1] if pl else items["Portrait"][1]
        row_bottom = max(t["Rect"][1] + t["Rect"][3] for t in tiles)
        level = [r for r in ring if r[1] < row_bottom and r[1] + r[3] > top]
        limit = min(r[0] for r in level) if level else W
        res[f"phone group right of 0.3 W (left {left:.1f}, 0.3W {0.3 * W:.1f})"] = left >= 0.3 * W - 1
        lr, rr = left - 0.2 * W, limit - right
        res[f"phone group centred between 0.2 W and the ring (left room {lr:.1f}, right room {rr:.1f} incl. gap)"] = \
            abs(lr - (rr - 8 * p.get("Scale", 1))) <= 3
    return res


def shot(c, dev, view, rows):
    img = qv.grab(c, f"hf_{dev}_{view}")
    path = os.path.join(RAW, f"{dev}_{view}.png")
    if img:
        img.save(path)
    p = probe(c)
    ck = checks(dev, view, p)
    rows.append({"device": dev, "view": view, "probe": p, "checks": ck, "capture": list(img.size) if img else None,
                 "file": os.path.relpath(path, ROOT).replace("\\", "/")})
    print(dev, view, json.dumps(ck, ensure_ascii=False))


def capture(devices):
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
            shot(c, dev, "lv1", rows)
            print(dev, dv.luau(c, LEVEL % 5, "Server").strip())
            time.sleep(1.6)
            shot(c, dev, "learn", rows)
            print(dev, dv.luau(c, LEVEL % 25, "Server").strip())
            time.sleep(2.0)
            shot(c, dev, "lv25", rows)
            print(dev, dv.luau(c, SET_ATTR % ("HintPreview", '"Attack"', "HintPreview"), "Client").strip())
            time.sleep(1.2)
            shot(c, dev, "atk", rows)
            dv.luau(c, SET_ATTR % ("HintPreview", '""', "HintPreview"), "Client")
    return rows


def scale_of(row):
    """capture px per MainGui real px"""
    cap, p = row.get("capture"), row["probe"]
    if not cap or not p.get("W"):
        return 1.0
    return cap[0] / p["W"]


def sheet(rows):
    from PIL import Image, ImageDraw
    os.makedirs(OUT_DIR, exist_ok=True)
    tiles, crops = [], []
    for r in rows:
        f = os.path.join(ROOT, r["file"])
        if not os.path.exists(f):
            continue
        im = Image.open(f).convert("RGB")
        k = scale_of(r)
        # 200% crops: every hint bubble with its button, and the bottom-centre group of the lv25 view
        for h in r["probe"].get("Hints", []):
            x, y, w, hh = h["Rect"]
            box = (max(0, int((x - 20) * k)), max(0, int((y - 20) * k)), min(im.width, int((x + w + 20) * k)),
                   min(im.height, int((y + hh + 90) * k)))
            cr = im.crop(box)
            cr = cr.resize((cr.width * 2, cr.height * 2), Image.LANCZOS)
            crops.append((f'{r["device"]} {r["view"]} {h["Name"]}', cr))
        if r["view"] == "lv25":
            items = r["probe"].get("Items", {})
            low = [v[1] for v in items.values() if v[1] > r["probe"].get("H", 0) * 0.45]
            if low:
                y0 = min(low) - 30
                cr = im.crop((0, max(0, int(y0 * k)), im.width, im.height))
                crops.append((f'{r["device"]} lv25 bottom', cr))
        tw = 640
        small = im.resize((tw, int(tw * im.height / im.width)), Image.LANCZOS)
        d = ImageDraw.Draw(small)
        d.rectangle([0, 0, tw, 18], fill=(16, 20, 40))
        bad = [n for n, ok in r["checks"].items() if not ok]
        d.text((5, 3), f'{r["device"]} {r["view"]}  checks {len(r["checks"]) - len(bad)}/{len(r["checks"])}'
                       + (f'  FAIL {bad[0][:60]}' if bad else ''), fill=(255, 80, 80) if bad else (255, 255, 0))
        tiles.append(small)
    if not tiles:
        return None
    cols = 2
    th = max(t.height for t in tiles)
    out = Image.new("RGB", (cols * 646, ((len(tiles) + cols - 1) // cols) * (th + 6)), (0, 0, 0))
    for i, t in enumerate(tiles):
        out.paste(t, ((i % cols) * 646, (i // cols) * (th + 6)))
    path = os.path.join(OUT_DIR, "sheet.jpg")
    out.save(path, quality=86, optimize=True)
    for i, (label, cr) in enumerate(crops):
        name = label.replace(" ", "_")
        cr.save(os.path.join(OUT_DIR, f"crop_{i:02d}_{name}.png"))
    return path


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    devices = [a for a in sys.argv[1:] if a in dv.DEVICES] or ["pc", "phone", "844"]
    rows = capture(devices)
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    failed = [(r["device"], r["view"], n) for r in rows for n, ok in r["checks"].items() if not ok]
    with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"tool": "tools/hud_frame_view.py", "failed": failed, "rows": rows}, f, ensure_ascii=False, indent=2)
    print("failed:", failed)
    print("sheet:", sheet(rows))


if __name__ == "__main__":
    main()
