"""
미니맵 퀘스트 목표 점 확인(검수 리뷰 8e89d2b ①, 2026-10-07): 연습 Studio(UiSandbox) Play에서 기기마다
  1. 빛 진영·직업을 고른 채 교차로에서 첫 임무를 받는다(RequestTutorial → AcceptTutorial; 막 고른 직후는 0단계(황금
     슬라임)라 길잡이가 임무를 안 주므로, 그때는 서버가 2단계에서 보내는 것과 같은 '0/5 진행 중' 줄을 보낸다)
     → 미니맵 마름모(가까움)가 흰색(MarkerGo)인지
  2. 서버가 '5/5 받기 대기' 목록을 Quests 원격으로 보낸다 → 금색(MarkerClaim)으로 바뀌는지
  3. 멀리 서서(가장자리 꺾쇠) 받기 대기 = 금색, 진행 중 목록을 다시 보내면 흰색으로 돌아오는지
를 재고 찍는다. 게임 코드는 그대로 쓰고(HUD.QuestTarget → MiniMap), 실제 서버 대신 보내는 것은 Quests 목록 한 줄뿐이다.
결과: art/review/minimap_quest_2026-10-07.jpg + docs/art/verification_2026-10-07/minimap_quest_2026-10-07.json,
원본 캡처는 build/minimap_quest_view/.

  py tools/minimap_quest_view.py [pc] [phone] [844]
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
RAW = os.path.join(ROOT, "build", "minimap_quest_view")
SHEET = os.path.join(ROOT, "art", "review", "minimap_quest_2026-10-07.jpg")
REPORT = os.path.join(ROOT, "docs", "art", "verification_2026-10-07", "minimap_quest_2026-10-07.json")

# MarkerGo / MarkerClaim (Config.UIArt.Colors, QuestMarker's colours) as 0-255
WHITE = (255, 255, 255)
GOLD = (255, 228, 128)

# the first-mission row the server sends in step 2 (QuestService tutorialEntry), progress and claim given
SEND = r'''
local p = game.Players:GetPlayers()[1]
local HttpService = game:GetService("HttpService")
local folder = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
local r = folder and folder:FindFirstChild("Quests")
if not (p and r) then return "no player or remote" end
local done = %s
local row = { Id = "tutorial", Kind = "Tutorial", Pinned = true, TutorialStep = 2, Progress = done and 5 or 0, Target = 5,
	RewardGold = 150, RewardXP = 0, CanClaim = true, ShowProgress = true,
	Text = done and "Supply road mission done! Press [Claim]." or "Free the supply road · 5 slimes" }
r:FireClient(p, HttpService:JSONEncode({ row }))
return "sent " .. (done and "claim" or "go")
'''

# the minimap root and both quest marks: shown (all parents visible), colour, screen rect (px from the top-left)
PROBE = r'''
local HttpService = game:GetService("HttpService")
local lp = game.Players.LocalPlayer
local pg = lp:FindFirstChildOfClass("PlayerGui")
local probe = pg:FindFirstChild("MMProbe")
if not probe then
	probe = Instance.new("ScreenGui")
	probe.Name, probe.IgnoreGuiInset, probe.ResetOnSpawn = "MMProbe", true, false
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
local function rect(g)
	return { math.floor(g.AbsolutePosition.X - o.X), math.floor(g.AbsolutePosition.Y - o.Y),
		math.floor(g.AbsoluteSize.X), math.floor(g.AbsoluteSize.Y) }
end
local out = { Screen = { probe.AbsoluteSize.X, probe.AbsoluteSize.Y }, Zone = lp:GetAttribute("ZoneId"),
	Step = lp:GetAttribute("TutorialStep") }
local mm = main and main:FindFirstChild("MiniMap", true)
if mm then
	out.Root = rect(mm)
	out.RootShown = shown(mm)
	for _, name in { "Quest", "QuestEdge" } do
		local g = mm:FindFirstChild(name, true)
		if g then
			local col = g:IsA("ImageLabel") and g.ImageColor3 or (g:IsA("TextLabel") and g.TextColor3) or nil
			out[name] = { Class = g.ClassName, Shown = shown(g), Rect = rect(g),
				Color = col and { math.floor(col.R * 255 + 0.5), math.floor(col.G * 255 + 0.5), math.floor(col.B * 255 + 0.5) } or nil }
		end
	end
end
return HttpService:JSONEncode(out)
'''


def near(col, want, tol=6):
    return isinstance(col, list) and len(col) == 3 and all(abs(a - b) <= tol for a, b in zip(col, want))


def shot(c, dev, mode, want, rows):
    probe = json.loads(dv.luau(c, PROBE, "Client").strip())
    img = qv.grab(c, f"mmq_{dev}_{mode}")
    path = os.path.join(RAW, f"{dev}_{mode}.png")
    if img:
        img.save(path)
    # the mark that should carry the colour: the diamond near, the edge chevron far
    mark = "QuestEdge" if mode.startswith("edge") else "Quest"
    m = probe.get(mark) or {}
    ok = bool(probe.get("RootShown")) and bool(m.get("Shown")) and near(m.get("Color"), want)
    rows.append({"device": dev, "mode": mode, "mark": mark, "want": list(want), "ok": ok,
                 "file": os.path.relpath(path, ROOT).replace("\\", "/"), "probe": probe})
    print(dev, mode, mark, "shown", m.get("Shown"), "color", m.get("Color"), "want", want, "OK" if ok else "FAIL",
          "| step", probe.get("Step"), "zone", probe.get("Zone"))


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
        # 1. the real path: stand in the Crossroads ~30 studs from the meadow pad, accept the first mission
        print(dev, "place:", dv.luau(c, qv.PLACE % (20, -20, 90), "Server").strip())
        time.sleep(2.5)
        real = dv.luau(c, qv.REAL, "Client").strip()
        print(dev, "real:", real)
        time.sleep(3)
        if not real.endswith("step=2"):
            # a fresh pick starts at step 0 (the golden slime): the guide does not hand out the mission yet, so send the
            # step-2 row the server sends after AcceptTutorial (same shape) - MiniMap reads it through HUD the same way
            print(dev, "step-2 row:", dv.luau(c, SEND % "false", "Server").strip())
            time.sleep(1.5)
        shot(c, dev, "near_go", WHITE, rows)
        # 2. the row waits for [Claim]
        print(dev, dv.luau(c, SEND % "true", "Server").strip())
        time.sleep(1.5)
        shot(c, dev, "near_claim", GOLD, rows)
        # 3. far away: the edge chevron, gold while claimable, white again in progress
        print(dev, "place:", dv.luau(c, qv.PLACE % (-95, 100, 90), "Server").strip())
        time.sleep(2.5)
        shot(c, dev, "edge_claim", GOLD, rows)
        print(dev, dv.luau(c, SEND % "false", "Server").strip())
        time.sleep(1.5)
        shot(c, dev, "edge_go", WHITE, rows)


def sheet(rows):
    from PIL import Image, ImageDraw, ImageFont
    try:
        font = ImageFont.truetype("arial.ttf", 15)
    except OSError:
        font = ImageFont.load_default()
    tiles = []
    for r in rows:
        f = os.path.join(ROOT, r["file"])
        if not os.path.exists(f):
            continue
        img = Image.open(f).convert("RGB")
        full = img.resize((560, int(560 * img.height / img.width)), Image.LANCZOS)
        root = r["probe"].get("Root")
        screen = r["probe"].get("Screen") or [img.width, img.height]
        crop = None
        if root:
            # the capture can be bigger than the device screen (2x on the phone): probe px -> capture px
            k = img.width / max(1, screen[0])
            x, y, cw, ch = (v * k for v in root)
            m = 6 * k
            box = (int(max(0, x - m)), int(max(0, y - m)), int(min(img.width, x + cw + m)), int(min(img.height, y + ch + m)))
            crop = img.crop(box)
            k = 300 / max(1, crop.height)
            crop = crop.resize((max(1, int(crop.width * k)), 300), Image.LANCZOS)
        tw = 560 + (crop.width + 8 if crop else 0)
        th = max(full.height, crop.height if crop else 0) + 22
        tile = Image.new("RGB", (tw, th), (16, 20, 40))
        tile.paste(full, (0, 22))
        if crop:
            tile.paste(crop, (568, 22))
        d = ImageDraw.Draw(tile)
        d.text((5, 3), f'{r["device"]} {r["mode"]}  {r["mark"]} {r["probe"].get(r["mark"], {}).get("Color")} '
                       f'want {r["want"]}  {"OK" if r["ok"] else "FAIL"}', fill=(255, 255, 255), font=font)
        tiles.append(tile)
    if not tiles:
        return None
    w = max(t.width for t in tiles)
    out = Image.new("RGB", (w, sum(t.height for t in tiles)), (0, 0, 0))
    y = 0
    for t in tiles:
        out.paste(t, (0, y))
        y += t.height
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    out.save(SHEET, quality=86, optimize=True)
    return SHEET


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    devices = [a for a in sys.argv[1:] if a in dv.DEVICES] or ["pc", "phone"]
    rows = []
    with dv.sandbox() as c:
        run(c, devices, rows)
    path = sheet(rows)
    report = {"tool": "tools/minimap_quest_view.py", "sheet": "art/review/minimap_quest_2026-10-07.jpg",
              "passed": sum(1 for r in rows if r["ok"]), "total": len(rows), "rows": rows}
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print("sheet:", path, "report:", REPORT, "passed", report["passed"], "/", report["total"])


if __name__ == "__main__":
    main()
