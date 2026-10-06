"""
위 줄 맞추기(A23-40 보강, 사용자 2026-10-06 "메뉴 위치랑 가운데 바가 로블록스 기본 메뉴랑 위치가 같으면 좋겠어") 확인:
연습 Studio(UiSandbox) Play에서 PC 1280x720 · 폰 749x361 · 844x390마다
  1. Roblox 위 버튼(CoreGui의 위 줄 버튼)과 우리 [Menu]·전쟁 미터의 실제 위치·크기를 잰다
     (세로 가운데 차이, 높이 차이, 줄의 빈 칸 GuiService.TopbarInset 안인지),
  2. 화면을 찍고([Menu] 접힘), Studio MCP 마우스 입력으로 [Menu]를 눌러 펼친 화면도 찍는다(자기 테스트 Play 안에서만),
  3. 퀘스트 마커(QuestMarkerPreview)를 초원 앞쪽·받기 금으로 띄워 어두운 테두리(halo) 대비를 다시 잰다.
결과: art/review/topbar_2026-10-06.jpg(시트), docs/art/verification_2026-10-06/topbar_view_2026-10-06.json,
원본 build/topbar_view/.

  py tools/topbar_view.py [pc] [phone] [844]
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
RAW = os.path.join(ROOT, "build", "topbar_view")
SHEET = os.path.join(ROOT, "art", "review", "topbar_2026-10-06.jpg")
REPORT = os.path.join(ROOT, "docs", "art", "verification_2026-10-06", "topbar_view_2026-10-06.json")

# Roblox's top bar buttons (CoreGui) vs ours, all in screen px measured from the very top-left (a full-screen probe gui)
PROBE = r'''
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local lp = game.Players.LocalPlayer
local pg = lp:FindFirstChildOfClass("PlayerGui")
local probe = pg:FindFirstChild("TBViewProbe")
if not probe then
	probe = Instance.new("ScreenGui")
	probe.Name, probe.IgnoreGuiInset, probe.ResetOnSpawn = "TBViewProbe", true, false
	pcall(function() probe.ScreenInsets = Enum.ScreenInsets.None end)
	probe.Parent = pg
	task.wait(0.1)
end
local o = probe.AbsolutePosition
local function box(g)
	return { X = g.AbsolutePosition.X - o.X, Y = g.AbsolutePosition.Y - o.Y, W = g.AbsoluteSize.X, H = g.AbsoluteSize.Y }
end
local out = { Screen = { probe.AbsoluteSize.X, probe.AbsoluteSize.Y } }
local tb = GuiService.TopbarInset
out.TopbarInset = { tb.Min.X, tb.Min.Y, tb.Max.X, tb.Max.Y }
local tl = GuiService:GetGuiInset()
out.GuiInset = { tl.X, tl.Y }
local main = pg:FindFirstChild("MainGui")
if main then
	out.MainGui = box(main)
	local sc = main:FindFirstChildOfClass("UIScale")
	out.UIScale = sc and sc.Scale or 1
	local hud = main:FindFirstChild("HUD")
	local function find(name)
		local f = hud and hud:FindFirstChild(name, true)
		return f and f:IsA("GuiObject") and f.Visible and box(f) or nil
	end
	out.Menu = find("TileMenu")
	out.War = find("WarMeter")
	out.Chips = find("StatusChips")
end
-- Roblox's own buttons: visible GuiButtons / ImageLabels of CoreGui inside the top bar row, 24..64 px tall
local ok, err = pcall(function()
	local core = game:GetService("CoreGui")
	local list = {}
	for _, d in core:GetDescendants() do
		if d:IsA("GuiObject") and (d:IsA("GuiButton") or d:IsA("Frame") or d:IsA("ImageLabel")) and d.AbsoluteSize.Y >= 24
			and d.AbsoluteSize.Y <= 64 and d.AbsoluteSize.X >= 24 and d.AbsoluteSize.X <= 400 then
			local b = box(d)
			if b.Y >= -2 and b.Y + b.H <= tb.Max.Y + 8 and b.X < tb.Min.X + 4 then
				local visible = true
				local p = d
				while p and p ~= core do
					if p:IsA("GuiObject") and not p.Visible then visible = false break end
					if p:IsA("LayerCollector") and not p.Enabled then visible = false break end
					p = p.Parent
				end
				if visible then
					table.insert(list, { Path = d:GetFullName():sub(1, 120), Class = d.ClassName, X = b.X, Y = b.Y, W = b.W, H = b.H })
				end
			end
		end
	end
	out.RobloxButtons = list
end)
if not ok then out.CoreGuiError = tostring(err) end
return HttpService:JSONEncode(out)
'''


# after the click on [Menu]: is the fold frame open, how many squares show, and the war line's text
FOLD = r'''
local main = game.Players.LocalPlayer.PlayerGui:FindFirstChild("MainGui")
local fold = main and main:FindFirstChild("MenuFold", true)
local n = 0
if fold then
	for _, b in fold:GetChildren() do
		if b:IsA("GuiObject") and b.Visible then n += 1 end
	end
end
local war = main and main:FindFirstChild("WarMeter", true)
local line = war and war:FindFirstChild("Text", true)
return string.format("fold visible=%s squares=%d | war line '%s' fits=%s bounds=%.0f/%.0f", tostring(fold and fold.Visible), n,
	line and line.Text or "?", tostring(line and line.TextFits), line and line.TextBounds.X or -1, line and line.AbsoluteSize.X or -1)
'''


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
        print(dev, "pick:", dv.luau(c, dv.PICK % "Halo", "Server").strip())
        time.sleep(5)
        # the meadow (the war meter / chips over grass) facing the path; marker ahead in light gold (claim)
        print(dev, dv.luau(c, qv.PLACE % (300, 0, 90), "Server").strip())
        time.sleep(2.5)
        dv.luau(c, qv.PIN, "Client")
        dv.luau(c, qv.AIM % ("ahead", ",claim"), "Client")
        time.sleep(2.5)
        probe = json.loads(dv.luau(c, PROBE, "Client").strip())
        img = qv.grab(c, f"tb_{dev}_closed")
        path = os.path.join(RAW, f"{dev}_closed.png")
        if img:
            img.save(path)
        marker = json.loads(dv.luau(c, qv.MEASURE, "Client").strip())
        row = {"device": dev, "shot": "closed", "file": os.path.relpath(path, ROOT).replace("\\", "/"), "probe": probe,
               "marker": marker, "markerContrast": qv.measure_contrast(img, marker) if img else None}
        rows.append(row)
        print(dev, "closed:", json.dumps({k: probe.get(k) for k in ("TopbarInset", "Menu", "War")}),
              "buttons", len(probe.get("RobloxButtons") or []), "marker", (row["markerContrast"] or {}).get("best"))
        # a click on [Menu] folds the squares out (Studio MCP mouse input, own test Play only; the B key did not reach the
        # game through user_keyboard_input on 2026-10-06)
        try:
            menu_path = "LocalPlayer.PlayerGui.MainGui.HUD.Buttons.TileMenu"
            c.call("user_mouse_input", {"actions": [{"action": "moveTo", "instance_path": menu_path},
                                                    {"action": "mouseButtonClick", "mouse_button": "left"}]})
            time.sleep(1.2)
            img = qv.grab(c, f"tb_{dev}_open")
            path = os.path.join(RAW, f"{dev}_open.png")
            if img:
                img.save(path)
            fold = dv.luau(c, FOLD, "Client").strip()
            print(dev, "fold:", fold)
            rows.append({"device": dev, "shot": "open", "file": os.path.relpath(path, ROOT).replace("\\", "/"),
                         "fold": fold})
            c.call("user_mouse_input", {"actions": [{"action": "moveTo", "instance_path": menu_path},
                                                    {"action": "mouseButtonClick", "mouse_button": "left"}]})
        except Exception as e:  # noqa: BLE001 - the fold capture is a bonus; report and go on
            print(dev, "fold capture failed:", e)
        # the haunted hollow next to its lamps (the 2.94:1 spot of 61a1b43): the in-progress marker at the edge
        dv.luau(c, qv.PLACE % (235, 240, 270), "Server")
        time.sleep(2.5)
        dv.luau(c, qv.PIN, "Client")
        dv.luau(c, qv.AIM % ("edge", ""), "Client")
        time.sleep(2.5)
        img = qv.grab(c, f"tb_{dev}_hollow")
        path = os.path.join(RAW, f"{dev}_hollow_edge.png")
        if img:
            img.save(path)
        marker = json.loads(dv.luau(c, qv.MEASURE, "Client").strip())
        rows.append({"device": dev, "shot": "hollow_edge", "file": os.path.relpath(path, ROOT).replace("\\", "/"),
                     "marker": marker, "markerContrast": qv.measure_contrast(img, marker) if img else None})
        print(dev, "hollow edge marker", (rows[-1]["markerContrast"] or {}).get("best"))
        dv.luau(c, 'game.Players.LocalPlayer:SetAttribute("QuestMarkerPreview", nil) '
                   'game:GetService("RunService"):UnbindFromRenderStep("QMViewPin") return "ok"', "Client")


def summarise(rows):
    """per device: Roblox's button middle / height vs our [Menu] and war meter (screen px)"""
    out = []
    for r in rows:
        p = r.get("probe")
        if not p:
            continue
        btns = [b for b in (p.get("RobloxButtons") or []) if b["H"] >= 30]
        # the tallest-common button height among Roblox's own (the round menu / chat buttons)
        ref = None
        if btns:
            hs = sorted(round(b["H"]) for b in btns)
            ref_h = max(set(hs), key=hs.count)
            same = [b for b in btns if round(b["H"]) == ref_h]
            mid = sum(b["Y"] + b["H"] / 2 for b in same) / len(same)
            ref = {"H": ref_h, "Mid": round(mid, 2), "Count": len(same)}
        s = {"device": r["device"], "robloxButton": ref, "topbarInset": p.get("TopbarInset"), "guiInset": p.get("GuiInset")}
        for key in ("Menu", "War", "Chips"):
            b = p.get(key)
            if b:
                s[key] = {"X": round(b["X"], 1), "Y": round(b["Y"], 1), "W": round(b["W"], 1), "H": round(b["H"], 1),
                          "Mid": round(b["Y"] + b["H"] / 2, 2)}
                if ref and key != "Chips":
                    s[key]["MidDelta"] = round(b["Y"] + b["H"] / 2 - ref["Mid"], 2)
                    s[key]["HDelta"] = round(b["H"] - ref["H"], 2)
        s["markerContrast"] = r.get("markerContrast")
        out.append(s)
    return out


def sheet(rows):
    from PIL import Image, ImageDraw, ImageFont
    tiles = []
    tw = 960
    for r in rows:
        f = os.path.join(ROOT, r["file"])
        if not os.path.exists(f):
            continue
        img = Image.open(f).convert("RGB")
        t = img.resize((tw, int(img.height * tw / img.width)), Image.LANCZOS)
        d = ImageDraw.Draw(t)
        d.rectangle([0, 0, tw, 24], fill=(16, 20, 40))
        try:
            font = ImageFont.truetype("arial.ttf", 16)
        except OSError:
            font = ImageFont.load_default()
        d.text((8, 3), f'{r["device"]} {r["shot"]}', fill=(255, 255, 255), font=font)
        # 2x zoom of the top bar row
        bar = img.crop((0, 0, img.width, int(img.height * 0.16)))
        z = bar.resize((tw, int(bar.height * tw / bar.width)), Image.LANCZOS)
        both = Image.new("RGB", (tw, t.height + z.height + 4), (0, 0, 0))
        both.paste(t, (0, 0))
        both.paste(z, (0, t.height + 4))
        tiles.append(both)
    if not tiles:
        return None
    cols = 2
    rows_n = (len(tiles) + cols - 1) // cols
    th = max(x.height for x in tiles)
    out = Image.new("RGB", (cols * tw, rows_n * th), (0, 0, 0))
    for i, x in enumerate(tiles):
        out.paste(x, ((i % cols) * tw, (i // cols) * th))
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    out.save(SHEET, quality=86, optimize=True)
    return SHEET


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    devices = [a for a in sys.argv[1:] if a in dv.DEVICES] or ["pc", "phone", "844"]
    rows = []
    with dv.sandbox() as c:  # sandbox check first; Play stop + device reset at the end, also after an error
        run(c, devices, rows)
    summary = summarise(rows)
    path = sheet(rows)
    report = {"tool": "tools/topbar_view.py", "devices": devices, "sheet": "art/review/topbar_2026-10-06.jpg",
              "summary": summary, "rows": rows,
              "note": "screen px from the very top-left; robloxButton = the most common height among Roblox's own top bar "
                      "buttons (CoreGui) and their mean middle; MidDelta / HDelta = ours minus Roblox's"}
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    for s in summary:
        print(json.dumps({k: s.get(k) for k in ("device", "robloxButton", "Menu", "War")}, ensure_ascii=False))
    print("sheet:", path, "report:", REPORT)


if __name__ == "__main__":
    main()
