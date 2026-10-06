"""
알림 글자 잘림 + 작은 화면 HUD 확인(검수 2026-10-06): 연습 Studio(UiSandbox) Play에서 기기마다
  1. 진영을 고른 상태의 HUD
  2. 대왕 등장 공지(UIKit.Announce)와 M1_2 시작 알림(UIKit.Toast)을 띄운 화면
을 찍고, 공지 글자와 토스트 글자가 다 들어갔는지(TextFits, 줄 수), 퀘스트 줄과 얼굴·막대 묶음이 겹치는지 잰다.
결과: art/review/notify_view_2026-10-06.jpg + docs/art/verification_2026-10-06/notify_view_2026-10-06.json

  py tools/notify_view.py [pc655] [pc573] [phone667] [phone] [pc]
기기: pc655 = 655x340 PC 창(마우스), pc573 = 573x354 PC 창, phone667 = 667x375 폰(터치), phone = 749x361 폰, pc = 1280x720.
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
RAW = os.path.join(ROOT, "build", "notify_view")
SHEET = os.path.join(ROOT, "art", "review", "notify_view_2026-10-06.jpg")
REPORT = os.path.join(ROOT, "docs", "art", "verification_2026-10-06", "notify_view_2026-10-06.json")
DEVICES = {
    "pc655": ("hd_720", 655, 340),
    "pc573": ("hd_720", 573, 354),
    "phone667": ("iphone_13", 667, 375),
    "phone": ("samsung_galaxy_s22_ultra", 749, 361),
    "pc": ("hd_720", 1280, 720),
}
KING = "The Pumpkin King appeared in the Pumpkin Patch! Let's beat it together!"
START = "King Slimes full of shard dust roam the meadow."

# from the server, through the game's own Notify remote: execute_luau's client context gets its own module copies, so
# calling UIKit there would draw nothing (the banner waits while TutorialStep is 0: the first mission is accepted)
SHOW = r'''
local p = game.Players:GetPlayers()[1]
if not p then return "no player" end
p:SetAttribute("TutorialStep", 99)
local remote = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")
remote:FireClient(p, { Text = "%s", Kind = "announce", Duration = 30 })
remote:FireClient(p, { Text = "%s", Kind = "info", Duration = 30 })
return "shown"
'''

# full-screen probe: rects in screen px from the very top-left + text fit of the banner and the toasts
PROBE = r'''
local HttpService = game:GetService("HttpService")
local pg = game.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
local probe = pg:FindFirstChild("NVProbe")
if not probe then
	probe = Instance.new("ScreenGui")
	probe.Name, probe.IgnoreGuiInset, probe.ResetOnSpawn = "NVProbe", true, false
	pcall(function() probe.ScreenInsets = Enum.ScreenInsets.None end)
	probe.Parent = pg
	task.wait(0.1)
end
local o = probe.AbsolutePosition
local main = pg:FindFirstChild("MainGui")
local out = { Screen = { probe.AbsoluteSize.X, probe.AbsoluteSize.Y }, Touch = game:GetService("UserInputService").TouchEnabled,
	Rects = {}, Texts = {} }
local function rect(name, g)
	if g and g:IsA("GuiObject") and g.Visible then
		out.Rects[name] = { g.AbsolutePosition.X - o.X, g.AbsolutePosition.Y - o.Y, g.AbsoluteSize.X, g.AbsoluteSize.Y }
	end
end
local function text(name, l)
	if l and l:IsA("TextLabel") then
		out.Texts[name] = { Text = l.Text, Fits = l.TextFits, Box = { l.AbsoluteSize.X, l.AbsoluteSize.Y },
			Bounds = { l.TextBounds.X, l.TextBounds.Y }, Size = l.TextSize, Scaled = l.TextScaled }
	end
end
local ann = main and main:FindFirstChild("Announce")
rect("announce", ann)
text("announce", ann and ann:FindFirstChild("Text"))
local toasts = main and main:FindFirstChild("Toasts")
if toasts then
	local i = 0
	for _, t in toasts:GetChildren() do
		if t:IsA("Frame") then
			i += 1
			rect("toast" .. i, t)
			text("toast" .. i, t:FindFirstChild("Text"))
		end
	end
end
local hud = main and main:FindFirstChild("HUD")
for _, n in { "QuestLines", "Portrait", "PowerLine", "HpBar", "MpBar", "XpBar", "Tiles", "War", "Chips" } do
	rect(n, hud and hud:FindFirstChild(n, true))
end
-- every visible direct child of the HUD, for the overlap check when the names above differ
out.Hud = {}
for _, d in (hud and hud:GetChildren() or {}) do
	if d:IsA("GuiObject") and d.Visible then
		out.Hud[d.Name] = { d.AbsolutePosition.X - o.X, d.AbsolutePosition.Y - o.Y, d.AbsoluteSize.X, d.AbsoluteSize.Y }
	end
end
return HttpService:JSONEncode(out)
'''


def overlap(a, b):
    return not (a[0] + a[2] <= b[0] or b[0] + b[2] <= a[0] or a[1] + a[3] <= b[1] or b[1] + b[3] <= a[1])


def run(c, devices, rows):
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
        img = qv.grab(c, f"nv_{dev}_hud")
        if img:
            img.save(os.path.join(RAW, f"{dev}_hud.png"))
        print(dev, dv.luau(c, SHOW % (KING, START), "Server").strip())
        time.sleep(0.9)
        probe = json.loads(dv.luau(c, PROBE, "Client").strip())
        img = qv.grab(c, f"nv_{dev}_text")
        if img:
            img.save(os.path.join(RAW, f"{dev}_text.png"))
        r = probe.get("Rects", {})
        q = r.get("QuestLines")
        hits = [k for k in ("Portrait", "PowerLine", "HpBar", "MpBar", "XpBar", "Tiles") if q and r.get(k) and overlap(q, r[k])]
        rows.append({"device": dev, "probe": probe, "questOverlaps": hits,
                     "files": [f"build/notify_view/{dev}_hud.png", f"build/notify_view/{dev}_text.png"]})
        texts = probe.get("Texts", {})
        print(dev, "touch", probe.get("Touch"), "quest overlaps", hits,
              "| fits", {k: v.get("Fits") for k, v in texts.items()})


def sheet(rows):
    from PIL import Image, ImageDraw, ImageFont
    tiles = []
    for r in rows:
        for f in r["files"]:
            p = os.path.join(ROOT, f)
            if not os.path.exists(p):
                continue
            img = Image.open(p).convert("RGB")
            img = img.resize((640, int(640 * img.height / img.width)), Image.LANCZOS)
            d = ImageDraw.Draw(img)
            try:
                font = ImageFont.truetype("arial.ttf", 15)
            except OSError:
                font = ImageFont.load_default()
            d.rectangle([0, 0, 640, 20], fill=(16, 20, 40))
            fits = {k: v.get("Fits") for k, v in r["probe"].get("Texts", {}).items()}
            d.text((5, 2), f'{os.path.basename(f)[:-4]}  touch={r["probe"].get("Touch")}  quest overlaps={r["questOverlaps"]}  fits={fits}'[:110],
                   fill=(255, 255, 255), font=font)
            tiles.append(img)
    if not tiles:
        return None
    th = max(t.height for t in tiles)
    cols = 2
    out = Image.new("RGB", (cols * 640, ((len(tiles) + 1) // 2) * th), (0, 0, 0))
    for i, t in enumerate(tiles):
        out.paste(t, ((i % cols) * 640, (i // cols) * th))
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    out.save(SHEET, quality=86, optimize=True)
    return SHEET


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    devices = [a for a in sys.argv[1:] if a in DEVICES] or ["pc655", "phone667"]
    rows = []
    with dv.sandbox() as c:
        run(c, devices, rows)
    path = sheet(rows)
    report = {"tool": "tools/notify_view.py", "sheet": "art/review/notify_view_2026-10-06.jpg", "rows": rows,
              "texts": {"king": KING, "start": START}}
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print("sheet:", path, "report:", REPORT)


if __name__ == "__main__":
    main()
