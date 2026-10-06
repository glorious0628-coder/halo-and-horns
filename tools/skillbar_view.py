"""
스킬 버튼 Q · Z · X(A23-49 SKL-4a, skill_kit §6) 확인: 연습 Studio(UiSandbox) Play에서 PC 1280x720 · 폰 749x361 · 844x390마다
  1. 기본(Lv1: Z·X 잠김, Q 준비) — Z·X는 플래그가 꺼져 있어 Studio 전용 속성 SkillBarPreview로 보이게 한다
  2. Lv10 + Q 재사용 2.4초 남음 + Z 준비 + X MP 모자람(로컬 속성만 바꿈, 서버 값은 그대로)
을 찍고, 버튼 셋의 실제 위치·크기와 서로·공격·자동·유령 버튼과의 간격을 잰다(원은 원으로).
결과: art/review/skillbar_2026-10-06.jpg + docs/art/verification_2026-10-06/skillbar_view_2026-10-06.json.

  py tools/skillbar_view.py [pc] [phone] [844]
STUDIO_NAME은 UiSandbox로 고정(dv.sandbox가 먼저 확인). 끝나면(오류가 나도) Play를 멈추고 기기 흉내를 끈다.
"""

import json
import math
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ["STUDIO_NAME"] = "UiSandbox"  # practice Studio only: forced before studio_mcp is imported (via device_view)
import device_view as dv  # noqa: E402
import quest_marker_view as qv  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "build", "skillbar_view")
SHEET = os.path.join(ROOT, "art", "review", "skillbar_2026-10-06.jpg")
REPORT = os.path.join(ROOT, "docs", "art", "verification_2026-10-06", "skillbar_view_2026-10-06.json")
# start = Lv1 (Z / X locked), busy = Lv10 + Q cooling, nomp = Lv10 + 5 MP (A23-60: the Q button dims, no MP number)
MODES = ["start", "busy", "nomp"]

SETUP = r'''
local p = game.Players.LocalPlayer
p:SetAttribute("SkillBarPreview", true)
local mode = "%s"
local now = workspace:GetServerTimeNow()
if mode == "busy" then
	p:SetAttribute("Level", 10)
	p:SetAttribute("SkillReadyAt", now + 2.4)
	p:SetAttribute("SkillReadyAtZ", 0)
	p:SetAttribute("SkillReadyAtX", 0)
	p:SetAttribute("Mana", 22)
elseif mode == "nomp" then
	p:SetAttribute("Level", 10)
	p:SetAttribute("SkillReadyAt", 0)
	p:SetAttribute("Mana", 5)
end
return tostring(p:GetAttribute("Level")) .. " mana " .. tostring(p:GetAttribute("Mana"))
'''

# the cluster's buttons in screen px from the very top-left (full-screen probe gui)
PROBE = r'''
local HttpService = game:GetService("HttpService")
local pg = game.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
local probe = pg:FindFirstChild("SBViewProbe")
if not probe then
	probe = Instance.new("ScreenGui")
	probe.Name, probe.IgnoreGuiInset, probe.ResetOnSpawn = "SBViewProbe", true, false
	pcall(function() probe.ScreenInsets = Enum.ScreenInsets.None end)
	probe.Parent = pg
	task.wait(0.1)
end
local o = probe.AbsolutePosition
local main = pg:FindFirstChild("MainGui")
local out = { Screen = { probe.AbsoluteSize.X, probe.AbsoluteSize.Y }, Buttons = {} }
local function add(name, g)
	if g and g:IsA("GuiObject") and g.Visible then
		out.Buttons[name] = { g.AbsolutePosition.X - o.X, g.AbsolutePosition.Y - o.Y, g.AbsoluteSize.X, g.AbsoluteSize.Y }
	end
end
local bar = main and main:FindFirstChild("SkillBar")
for _, s in { "Q", "Z", "X" } do add("skill" .. s, bar and bar:FindFirstChild("Skill" .. s)) end
local hud = main and main:FindFirstChild("HUD")
local btns = hud and hud:FindFirstChild("Buttons")
for _, n in { "Attack", "Auto", "Release" } do add(n, btns and btns:FindFirstChild(n)) end
local ghost = main and main:FindFirstChild("GrudgeGhost", true)
add("Ghost", ghost)
local states = {}
for _, s in { "Q", "Z", "X" } do
	local b = bar and bar:FindFirstChild("Skill" .. s)
	if b then
		local lock = b:FindFirstChild("Lock")
		local sec = b:FindFirstChild("Seconds", true)
		local mp = b:FindFirstChild("MP")
		states[s] = { Lock = lock and lock.Visible or false, Seconds = sec and sec.Visible and sec.Text or "",
			MPRed = mp and mp.BackgroundColor3.R > 0.7 or false, Visible = b.Visible }
	end
end
out.States = states
return HttpService:JSONEncode(out)
'''


def circle_gap(a, b):
    ax, ay, ar = a[0] + a[2] / 2, a[1] + a[3] / 2, min(a[2], a[3]) / 2
    bx, by, br = b[0] + b[2] / 2, b[1] + b[3] / 2, min(b[2], b[3]) / 2
    return math.hypot(ax - bx, ay - by) - ar - br


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
        print(dev, dv.luau(c, qv.PLACE % (300, 0, 90), "Server").strip())
        time.sleep(2)
        dv.luau(c, qv.PIN, "Client")
        for mode in MODES:
            print(dev, mode, dv.luau(c, SETUP % mode, "Client").strip())
            time.sleep(0.6)
            probe = json.loads(dv.luau(c, PROBE, "Client").strip())
            img = qv.grab(c, f"sb_{dev}_{mode}")
            path = os.path.join(RAW, f"{dev}_{mode}.png")
            if img:
                img.save(path)
            gaps = {}
            names = sorted(probe.get("Buttons", {}))
            for i, a in enumerate(names):
                for b in names[i + 1:]:
                    if "Release" in (a, b):
                        continue
                    gaps[f"{a}/{b}"] = round(circle_gap(probe["Buttons"][a], probe["Buttons"][b]), 1)
            rows.append({"device": dev, "mode": mode, "file": os.path.relpath(path, ROOT).replace("\\", "/"),
                         "probe": probe, "gaps": gaps, "minGap": min(gaps.values()) if gaps else None})
            print(dev, mode, "states", probe.get("States"), "min gap", rows[-1]["minGap"],
                  "release visible", "Release" in probe.get("Buttons", {}))
        dv.luau(c, 'game.Players.LocalPlayer:SetAttribute("SkillBarPreview", nil) '
                   'game:GetService("RunService"):UnbindFromRenderStep("QMViewPin") return "ok"', "Client")


def sheet(rows):
    from PIL import Image, ImageDraw, ImageFont
    tiles = []
    for r in rows:
        f = os.path.join(ROOT, r["file"])
        p = r.get("probe") or {}
        if not os.path.exists(f) or not p.get("Buttons"):
            continue
        img = Image.open(f).convert("RGB")
        sw, sh = p["Screen"]
        sx, sy = img.width / sw, img.height / sh
        xs = [b[0] for b in p["Buttons"].values()] + [b[0] + b[2] for b in p["Buttons"].values()]
        ys = [b[1] for b in p["Buttons"].values()] + [b[1] + b[3] for b in p["Buttons"].values()]
        pad = 20
        box = (int((min(xs) - pad) * sx), int((min(ys) - pad - 30) * sy), int(min(sw, max(xs) + pad) * sx),
               int(min(sh, max(ys) + pad) * sy))
        crop = img.crop(box)
        crop = crop.resize((520, int(520 * crop.height / max(1, crop.width))), Image.LANCZOS)
        d = ImageDraw.Draw(crop)
        try:
            font = ImageFont.truetype("arial.ttf", 15)
        except OSError:
            font = ImageFont.load_default()
        d.rectangle([0, 0, 520, 20], fill=(16, 20, 40))
        d.text((5, 2), f'{r["device"]} {r["mode"]}  min gap {r.get("minGap")} px', fill=(255, 255, 255), font=font)
        tiles.append(crop)
    if not tiles:
        return None
    cols = 2
    th = max(t.height for t in tiles)
    rows_n = (len(tiles) + cols - 1) // cols
    out = Image.new("RGB", (cols * 520, rows_n * th), (0, 0, 0))
    for i, t in enumerate(tiles):
        out.paste(t, ((i % cols) * 520, (i // cols) * th))
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    out.save(SHEET, quality=88, optimize=True)
    return SHEET


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    devices = [a for a in sys.argv[1:] if a in dv.DEVICES] or ["pc", "phone", "844"]
    modes = [a for a in sys.argv[1:] if a in ("start", "busy", "nomp")]
    if modes:
        MODES[:] = modes
    rows = []
    with dv.sandbox() as c:
        run(c, devices, rows)
    path = sheet(rows)
    report = {"tool": "tools/skillbar_view.py", "sheet": "art/review/skillbar_2026-10-06.jpg", "rows": rows,
              "note": "gaps = circle-to-circle px between the visible round buttons (screen px); 'busy' = Lv10, Q cooling "
                      "2.4 s, Z ready, X short of MP (local attributes only)"}
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print("sheet:", path, "report:", REPORT)


if __name__ == "__main__":
    main()
