"""
A23-68 확인(사용자 2026-10-07 '초반 이탈 막기'): 연습 Studio(UiSandbox) Play에서 기기(PC·폰)마다
  fold     : 첫 [Claim] 전(TutorialStep 2) - 퀘스트 줄은 첫 임무 하나, 'Crown in · My pts' 줄·다음 이벤트 줄 없음, 큰 알림 보류
  hint_atk : HUD.Hint("Attack") - 공격 버튼 금빛 테 + 흔들림 + "Tap/Click to hit!" 말풍선 (Studio 전용 HintPreview)
  hint_q   : HUD.Hint("Q") - Q 금빛 테 + "Try your skill!"
  focus    : QuestMarker.Focus(가장 가까운 몬스터) - 이름표 위 작은 마름모 (Studio 전용 FocusPreview)
  unfold   : TutorialStep 99 - 숨긴 것들이 NEW! 표시와 함께 나타남(+0.8초), 보류한 큰 알림이 3초 뒤 나옴(+4.5초)
를 찍고 시트로 붙인다. 결과: build/rookie_hint_view/<dev>_<view>.png,
art/review/rookie_hint_2026-10-07.jpg + docs/art/verification_2026-10-07/rookie_hint_2026-10-07.json

  py tools/rookie_hint_view.py [pc] [phone]
연습 Studio 전용(device_view.sandbox): 끝나면(오류가 나도) Play를 멈추고 기기 흉내를 끈다. 마우스·키보드 입력 없음.
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
RAW = os.path.join(ROOT, "build", "rookie_hint_view")
SHEET = os.path.join(ROOT, "art", "review", "rookie_hint_2026-10-07.jpg")
REPORT = os.path.join(ROOT, "docs", "art", "verification_2026-10-07", "rookie_hint_2026-10-07.json")
VIEWS = ["fold", "hint_atk", "hint_q", "focus", "unfold", "unfold_late"]

# the first mission in progress (step 2), the other rows folded the way dev2's server marks them, the Pumpkin King out,
# one world banner that must wait
FOLD = r'''
local p = game.Players:GetPlayers()[1]
if not p then return "no player" end
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
p:SetAttribute("TutorialStep", 2)
local gs = RS:FindFirstChild("GameState")
if gs then
	gs:SetAttribute("PumpkinKingActive", true)
	gs:SetAttribute("PumpkinKingEndsAt", workspace:GetServerTimeNow() + 297)
end
local rows = {
	{ Id = "tutorial", Kind = "Tutorial", Pinned = true, TutorialStep = 2, Progress = 2, Target = 5, RewardGold = 150,
		RewardXP = 0, CanClaim = false, ShowProgress = true, Text = "Free the supply road · 5 slimes" },
	{ Id = "S0", Kind = "Sub", Text = "Learn your own fight", Progress = 0, Target = 1, Folded = true },
	{ Id = "d1", Kind = "Daily", Text = "Hit 4 monsters with a skill", Progress = 0, Target = 4, RewardGold = 60,
		RewardXP = 40, Slot = 1, Folded = true },
	{ Id = "d2", Kind = "Kill", Text = "Defeat 12 Goblins in the Wild Woods", Progress = 3, Target = 12, RewardGold = 80,
		RewardXP = 60, Unit = "Goblin", Slot = 2, Folded = true },
}
local remotes = RS:FindFirstChild("Remotes")
local q = remotes and remotes:FindFirstChild("Quests")
if q then q:FireClient(p, HttpService:JSONEncode(rows)) end
local n = remotes and remotes:FindFirstChild("Notify")
if n then n:FireClient(p, { Text = "The Pumpkin King appeared in the Pumpkin Patch! Let's beat it together!", Kind = "announce", Duration = 30 }) end
return "fold " .. tostring(p:GetAttribute("TutorialStep")) .. " quests " .. tostring(q ~= nil)
'''

# the first [Claim] happened: step 99, the rows come unfolded
UNFOLD = r'''
local p = game.Players:GetPlayers()[1]
if not p then return "no player" end
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
p:SetAttribute("TutorialStep", 99)
local rows = {
	{ Id = "tutorial", Kind = "Tutorial", Pinned = true, TutorialStep = 99, NextGoal = true, Progress = 0, Target = 1,
		RewardGold = 0, CanClaim = false, ShowProgress = false, Text = "Show the jelly to the smith" },
	{ Id = "S0", Kind = "Sub", Text = "Learn your own fight", Progress = 0, Target = 1 },
	{ Id = "d1", Kind = "Daily", Text = "Hit 4 monsters with a skill", Progress = 0, Target = 4, RewardGold = 60,
		RewardXP = 40, Slot = 1 },
	{ Id = "d2", Kind = "Kill", Text = "Defeat 12 Goblins in the Wild Woods", Progress = 3, Target = 12, RewardGold = 80,
		RewardXP = 60, Unit = "Goblin", Slot = 2 },
}
local remotes = RS:FindFirstChild("Remotes")
local q = remotes and remotes:FindFirstChild("Quests")
if q then q:FireClient(p, HttpService:JSONEncode(rows)) end
return "unfold " .. tostring(p:GetAttribute("TutorialStep"))
'''

# what the screen shows (client): quest lines, the war info line, the event chips, a banner, hints, focus, NEW! tags
PROBE = r'''
local HttpService = game:GetService("HttpService")
local pg = game.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
local main = pg:FindFirstChild("MainGui")
local function shown(g)
	while g and g ~= pg do
		if g:IsA("GuiObject") and not g.Visible then return false end
		if g:IsA("LayerCollector") and not g.Enabled then return false end
		g = g.Parent
	end
	return true
end
local function rect(g)
	return { math.floor(g.AbsolutePosition.X), math.floor(g.AbsolutePosition.Y), math.floor(g.AbsoluteSize.X),
		math.floor(g.AbsoluteSize.Y) }
end
local out = { Step = game.Players.LocalPlayer:GetAttribute("TutorialStep"), Lines = {}, NewTags = {}, Hints = {} }
local ql = main and main:FindFirstChild("QuestLines", true)
if ql then
	out.QuestLinesShown = shown(ql)
	for _, d in ql:GetDescendants() do
		if d:IsA("TextLabel") and shown(d) and d.Text ~= "" and d.AbsoluteSize.X > 4 then table.insert(out.Lines, d.Text) end
	end
end
local war = main and main:FindFirstChild("WarMeter", true)
local info = war and war:FindFirstChild("Info")
out.WarInfoShown = info ~= nil and shown(info)
local text = info and info:FindFirstChild("Text")
out.WarInfoText = text and text.Text or nil
for _, name in { "KingChip", "GooseChip" } do
	local chip = main and main:FindFirstChild(name, true)
	if chip then out[name] = shown(chip) end
end
local ann = main and main:FindFirstChild("Announce")
out.BannerShown = ann ~= nil and shown(ann) and ann.Visible
local at = ann and ann:FindFirstChild("Text")
out.BannerText = at and at.Text or nil
for _, d in (main and main:GetDescendants() or {}) do
	if d.Name == "NewTag" and d:IsA("GuiObject") and shown(d) then
		table.insert(out.NewTags, { Parent = d.Parent.Name, Rect = rect(d) })
	elseif (d.Name == "HintAttack" or d.Name == "HintQ") and d:IsA("GuiObject") and shown(d) then
		local t = d:FindFirstChild("Text")
		table.insert(out.Hints, { Name = d.Name, Rect = rect(d), Text = t and t.Text or "", TextFits = t and t.TextFits })
	elseif d.Name == "HintGlow" and d:IsA("GuiObject") and shown(d) then
		table.insert(out.Hints, { Name = "Glow:" .. d.Parent.Name, Rect = rect(d) })
	end
end
-- UI round 2: the minimap tap button covers the minimap (top object at its centre; both inset conventions)
local tap = main and main:FindFirstChild("MiniMapTap")
if tap then
	out.TapShown = shown(tap)
	local c = tap.AbsolutePosition + tap.AbsoluteSize / 2
	local inset = game:GetService("GuiService"):GetGuiInset()
	for _, dy in { 0, inset.Y } do
		local objs = pg:GetGuiObjectsAtPosition(c.X, c.Y + dy)
		-- the first object that takes input there (a button or an Active frame) is the one a tap reaches
		local input = "none"
		for _, o in objs do
			if o:IsA("GuiButton") or o.Active then
				input = o.Name
				break
			end
		end
		out["TapInput" .. dy] = input
	end
end
local qm = pg:FindFirstChild("QuestMarkerGui")
local focus = qm and qm:FindFirstChild("Focus")
out.Focus = focus and shown(focus) and rect(focus) or false
local mons = workspace:FindFirstChild("Monsters")
out.Monsters = mons and #mons:GetChildren() or 0
return HttpService:JSONEncode(out)
'''

# my own character next to the nearest living monster, the monster in front of the camera (client-owned character)
GO_NEAR = r'''
local lp = game.Players.LocalPlayer
local char = lp.Character
local root = char and char:FindFirstChild("HumanoidRootPart")
local folder = workspace:FindFirstChild("Monsters")
if not (root and folder) then return "no root / monsters" end
local best, bestD = nil, math.huge
for _, m in folder:GetChildren() do
	local hum = m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") or nil
	if hum and hum.Health > 0 and (m:GetAttribute("MonsterKind") == nil or tostring(m:GetAttribute("MonsterKind")):find("Slime")) then
		local d = (m:GetPivot().Position - root.Position).Magnitude
		if d < bestD then best, bestD = m, d end
	end
end
if not best then return "no monster" end
local cam = workspace.CurrentCamera
local look = cam.CFrame.LookVector
local flat = Vector3.new(look.X, 0, look.Z)
if flat.Magnitude < 0.1 then flat = Vector3.new(0, 0, -1) end
flat = flat.Unit
local target = best:GetPivot().Position
local pos = target - flat * 16 + Vector3.new(0, 3, 0)
char:PivotTo(CFrame.lookAt(pos, Vector3.new(target.X, pos.Y, target.Z)))
return "near " .. best.Name .. " " .. math.floor(bestD)
'''

SET_ATTR = r'''
game.Players.LocalPlayer:SetAttribute("%s", %s)
return "%s"
'''


def client_attr(c, name, lua_value):
    return dv.luau(c, SET_ATTR % (name, lua_value, name), "Client").strip()


def probe(c):
    raw = dv.luau(c, PROBE, "Client").strip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {"raw": raw[:300]}


def shot(c, dev, view, rows):
    img = qv.grab(c, f"rh_{dev}_{view}")
    path = os.path.join(RAW, f"{dev}_{view}.png")
    if img:
        img.save(path)
    p = probe(c)
    rows.append({"device": dev, "view": view, "probe": p, "file": os.path.relpath(path, ROOT).replace("\\", "/")})
    print(dev, view, json.dumps(p, ensure_ascii=False)[:400])


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
            print(dev, dv.luau(c, FOLD, "Server").strip())
            time.sleep(2.5)
            shot(c, dev, "fold", rows)
            print(dev, client_attr(c, "HintPreview", '"Attack"'))
            time.sleep(1.0)
            shot(c, dev, "hint_atk", rows)
            print(dev, client_attr(c, "HintPreview", '"Q"'))
            time.sleep(1.0)
            shot(c, dev, "hint_q", rows)
            print(dev, client_attr(c, "HintPreview", '""'))
            print(dev, dv.luau(c, GO_NEAR, "Client").strip())
            print(dev, client_attr(c, "FocusPreview", "true"))
            time.sleep(1.5)
            shot(c, dev, "focus", rows)
            print(dev, client_attr(c, "FocusPreview", "false"))
            print(dev, dv.luau(c, UNFOLD, "Server").strip())
            time.sleep(0.8)
            shot(c, dev, "unfold", rows)
            time.sleep(3.7)
            shot(c, dev, "unfold_late", rows)
    return rows


def crop_box(dev, view, im):
    """the part of the screen each view is about (None = the whole screen)"""
    w, h = im.size
    if view in ("hint_atk", "hint_q"):
        return (int(w * 0.62), int(h * 0.42), w, h) if dev == "pc" else (int(w * 0.45), int(h * 0.3), w, h)
    return None


def sheet(rows):
    from PIL import Image, ImageDraw
    tiles = []
    for r in rows:
        f = os.path.join(ROOT, r["file"])
        if not os.path.exists(f):
            continue
        im = Image.open(f).convert("RGB")
        box = crop_box(r["device"], r["view"], im)
        if box:
            im = im.crop(box)
        tw = 640
        im = im.resize((tw, int(tw * im.height / im.width)), Image.LANCZOS)
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, tw, 18], fill=(16, 20, 40))
        p = r["probe"]
        label = f'{r["device"]} {r["view"]}  step {p.get("Step")}  lines {len(p.get("Lines", []))}  ' \
                f'warInfo {p.get("WarInfoShown")}  NEW {len(p.get("NewTags", []))}  banner {p.get("BannerShown")}'
        d.text((5, 3), label, fill=(255, 255, 0))
        tiles.append(im)
    if not tiles:
        return None
    cols = 2
    th = max(t.height for t in tiles)
    out = Image.new("RGB", (cols * 646, ((len(tiles) + cols - 1) // cols) * (th + 6)), (0, 0, 0))
    for i, t in enumerate(tiles):
        out.paste(t, ((i % cols) * 646, (i // cols) * (th + 6)))
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    out.save(SHEET, quality=86, optimize=True)
    return SHEET


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    devices = [a for a in sys.argv[1:] if a in dv.DEVICES] or ["pc", "phone"]
    rows = capture(devices)
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"tool": "tools/rookie_hint_view.py", "rows": rows}, f, ensure_ascii=False, indent=2)
    print("sheet:", sheet(rows))


if __name__ == "__main__":
    main()
