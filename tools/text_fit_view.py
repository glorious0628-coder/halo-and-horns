"""
화면 글자 넘침 검사(이미지 개발, 2026-10-07 글꼴 A23-63 교체 확인): 연습 Studio(UiSandbox) Play에서 기기마다
  - 빛 진영·직업을 고르고, 호박 대왕 이벤트 진행 중(GameState PumpkinKingActive/EndsAt), 퀘스트 3줄(첫 임무 + 일일 2개,
    서버가 보내는 모양 그대로 Quests 원격), 알림(토스트 + 배너)을 띄운 뒤
  - PlayerGui 아래 화면에 보이는 모든 글자 칸(TextLabel / TextButton / TextBox)을 훑어 TextFits=false 이거나
    글자 크기(TextBounds)가 칸보다 큰 것(= 잘리거나 넘침)을 적고, 화면을 찍는다.
결과: art/review/text_fit_<tag>.jpg + docs/art/verification_2026-10-07/text_fit_<tag>.json, 원본 build/text_fit_view/.

  py tools/text_fit_view.py --tag after_font pc wide phone 844
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
RAW = os.path.join(ROOT, "build", "text_fit_view")
# extra screen: the wide but short PC window game dev 1 played in (1920x943, 2026-10-07 morning round)
DEVICES = dict(dv.DEVICES, wide=("hd_1080", 1920, 943))

SETUP = r'''
local p = game.Players:GetPlayers()[1]
if not p then return "no player" end
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
-- the Pumpkin King is out with 4:57 left
local gs = RS:FindFirstChild("GameState")
if gs then
	gs:SetAttribute("PumpkinKingActive", true)
	gs:SetAttribute("PumpkinKingEndsAt", workspace:GetServerTimeNow() + 297)
end
-- the quest list the server sends: the first mission in step 2 + two dailies
local rows = {
	{ Id = "tutorial", Kind = "Tutorial", Pinned = true, TutorialStep = 2, Progress = 1, Target = 5, RewardGold = 150,
		RewardXP = 0, CanClaim = true, ShowProgress = true, Text = "Free the supply road · 5 slimes" },
	{ Id = "d1", Kind = "Daily", Text = "Hit 4 monsters with a skill", Progress = 0, Target = 4, RewardGold = 60,
		RewardXP = 40, Slot = 1 },
	{ Id = "d2", Kind = "Kill", Text = "Defeat 12 Goblins in the Wild Woods", Progress = 3, Target = 12, RewardGold = 80,
		RewardXP = 60, Unit = "Goblin", Slot = 2 },
}
local q = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Quests")
if q then q:FireClient(p, HttpService:JSONEncode(rows)) end
local n = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Notify")
if n then
	n:FireClient(p, { Text = "The Pumpkin King appeared in the Pumpkin Patch! Let's beat it together!", Kind = "announce", Duration = 30 })
	n:FireClient(p, { Text = "Daily quest done! +60 gold · Check the board for more jobs.", Kind = "info", Duration = 30 })
end
return "setup " .. tostring(gs ~= nil) .. " " .. tostring(q ~= nil) .. " " .. tostring(n ~= nil)
'''

# every visible text box under PlayerGui (screen px from the very top-left); "bad" = does not fit
PROBE = r'''
local HttpService = game:GetService("HttpService")
local pg = game.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
local probe = pg:FindFirstChild("TFProbe")
if not probe then
	probe = Instance.new("ScreenGui")
	probe.Name, probe.IgnoreGuiInset, probe.ResetOnSpawn = "TFProbe", true, false
	pcall(function() probe.ScreenInsets = Enum.ScreenInsets.None end)
	probe.Parent = pg
	task.wait(0.1)
end
local o = probe.AbsolutePosition
local function shown(g)
	while g and g ~= pg do
		if g:IsA("GuiObject") and not g.Visible then return false end
		if g:IsA("LayerCollector") and not g.Enabled then return false end
		g = g.Parent
	end
	return true
end
local function path(g)
	local parts = {}
	while g and g ~= pg and #parts < 6 do
		table.insert(parts, 1, g.Name)
		g = g.Parent
	end
	return table.concat(parts, "/")
end
local out = { Screen = { probe.AbsoluteSize.X, probe.AbsoluteSize.Y }, Bad = {}, Count = 0 }
for _, d in pg:GetDescendants() do
	if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.Text ~= "" and d.TextTransparency < 0.95
		and shown(d) and d.AbsoluteSize.X > 2 and d.AbsoluteSize.Y > 2 and not d:FindFirstAncestorWhichIsA("BillboardGui") then
		out.Count += 1
		local b, s = d.TextBounds, d.AbsoluteSize
		local over = (b.X > s.X + 1.5) or (b.Y > s.Y + 1.5)
		if (not d.TextFits) or over then
			table.insert(out.Bad, { Path = path(d), Text = string.sub(d.Text, 1, 60), Fits = d.TextFits,
				Bounds = { math.floor(b.X), math.floor(b.Y) }, Size = { math.floor(s.X), math.floor(s.Y) },
				Pos = { math.floor(d.AbsolutePosition.X - o.X), math.floor(d.AbsolutePosition.Y - o.Y) },
				Font = d.FontFace.Family:match("([%w]+)%.json") or "?", TextSize = d.TextSize, Truncate = d.TextTruncate.Name })
		end
	end
end
return HttpService:JSONEncode(out)
'''


def run(c, devices, tag, rows):
    os.makedirs(RAW, exist_ok=True)
    for dev in devices:
        name, w, h = DEVICES[dev]
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
        print(dev, dv.luau(c, SETUP, "Server").strip())
        time.sleep(2.5)
        probe = json.loads(dv.luau(c, PROBE, "Client").strip())
        img = qv.grab(c, f"tf_{dev}_{tag}")
        path = os.path.join(RAW, f"{dev}_{tag}.png")
        if img:
            img.save(path)
        rows.append({"device": dev, "file": os.path.relpath(path, ROOT).replace("\\", "/"), "probe": probe})
        print(dev, "texts", probe.get("Count"), "bad", len(probe.get("Bad", [])))
        for b in probe.get("Bad", []):
            print("   ", b["Path"], repr(b["Text"]), "fits", b["Fits"], "bounds", b["Bounds"], "size", b["Size"], b["Font"], b["TextSize"])


def sheet(rows, out):
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
        screen = r["probe"].get("Screen") or [img.width, img.height]
        k = img.width / max(1, screen[0])
        d = ImageDraw.Draw(img)
        for b in r["probe"].get("Bad", []):
            x, y = b["Pos"]
            w, h = b["Size"]
            d.rectangle([x * k - 2, y * k - 2, (x + w) * k + 2, (y + h) * k + 2], outline=(255, 0, 255), width=max(2, int(2 * k)))
        img = img.resize((960, int(960 * img.height / img.width)), Image.LANCZOS)
        d = ImageDraw.Draw(img)
        d.rectangle([0, 0, 960, 22], fill=(16, 20, 40))
        d.text((6, 3), f'{r["device"]}  texts {r["probe"].get("Count")}  not fitting {len(r["probe"].get("Bad", []))} (magenta)',
               fill=(255, 255, 255), font=font)
        tiles.append(img)
    if not tiles:
        return None
    sheet_img = Image.new("RGB", (960, sum(t.height for t in tiles)), (0, 0, 0))
    y = 0
    for t in tiles:
        sheet_img.paste(t, (0, y))
        y += t.height
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet_img.save(out, quality=86, optimize=True)
    return out


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("devices", nargs="*")
    ap.add_argument("--tag", default="check")
    a = ap.parse_args()
    devices = [d for d in a.devices if d in DEVICES] or ["pc", "wide", "phone", "844"]
    rows = []
    with dv.sandbox() as c:
        run(c, devices, a.tag, rows)
    out = sheet(rows, os.path.join(ROOT, "art", "review", f"text_fit_{a.tag}.jpg"))
    rep = os.path.join(ROOT, "docs", "art", "verification_2026-10-07", f"text_fit_{a.tag}.json")
    os.makedirs(os.path.dirname(rep), exist_ok=True)
    with open(rep, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"tool": "tools/text_fit_view.py", "tag": a.tag, "rows": rows}, f, ensure_ascii=False, indent=2)
    print("sheet:", out, "report:", rep)


if __name__ == "__main__":
    main()
