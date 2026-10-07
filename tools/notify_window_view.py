"""
UI 2회차 #4 확인(검수 2026-10-07 "창이 열려 있으면 알림은 창 위 한 줄로"): 연습 Studio(UiSandbox) Play에서 기기(PC·폰)마다
  short : 짧은 창(물약 가게) + 작은 알림 2개 + 큰 알림 -> 창 위(또는 아래)에 한 줄만, 큰 알림도 그 한 줄로
  tall  : 긴 창(메뉴) + 작은 알림 -> 자리가 없으면 원래 줄에 한 줄
  vac   : 보너스 2일 + Vacation -> 보상 팝업(폰: 넓은 판, 첫 줄만, 리본 'Vacation Bonus' 한 줄)
  free  : 팝업을 닫은 뒤(창 없음) 알림 -> 원래 줄
결과: build/notify_window_view/<dev>_<view>.png, art/review/notify_window_2026-10-07.jpg,
docs/art/verification_2026-10-07/notify_window_2026-10-07.json

  py tools/notify_window_view.py [pc] [phone]
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
import window_audit_view as wa  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "build", "notify_window_view")
SHEET = os.path.join(ROOT, "art", "review", "notify_window_2026-10-07.jpg")
REPORT = os.path.join(ROOT, "docs", "art", "verification_2026-10-07", "notify_window_2026-10-07.json")

NOTIFY = r'''
local p = game.Players:GetPlayers()[1]
local RS = game:GetService("ReplicatedStorage")
p:SetAttribute("TutorialStep", 99) -- banners are not held (first [Claim] done)
local n = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Notify")
if not n then return "no Notify" end
%s
return "sent"
'''
THREE = '''n:FireClient(p, { Text = "Not enough gold.", Kind = "bad", Duration = 30 })
task.wait(0.2)
n:FireClient(p, { Text = "Daily quest done! +60 gold", Kind = "reward", Duration = 30 })
task.wait(0.2)
n:FireClient(p, { Text = "The Pumpkin King appeared in the Pumpkin Patch! Let's beat it together!", Kind = "announce", Duration = 30 })'''
ONE = '''n:FireClient(p, { Text = "You found a Slime Jelly!", Kind = "reward", Duration = 30 })'''

PROBE = r'''
local HttpService = game:GetService("HttpService")
local pg = game.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
local main = pg:FindFirstChild("MainGui")
local function rect(g)
	return { math.floor(g.AbsolutePosition.X), math.floor(g.AbsolutePosition.Y), math.floor(g.AbsoluteSize.X),
		math.floor(g.AbsoluteSize.Y) }
end
local out = { Toasts = {}, Window = nil, Banner = false }
local holder = main and main:FindFirstChild("Toasts")
for _, t in (holder and holder:GetChildren() or {}) do
	if t:IsA("Frame") and t.Name == "Toast" then
		local l = t:FindFirstChild("Text")
		table.insert(out.Toasts, { Rect = rect(t), Text = l and l.Text or "" })
	end
end
local modal = main and main:FindFirstChild("PanelsModal")
local win = modal and modal.Visible and modal:FindFirstChild("Window")
if win and win.Visible then out.Window = rect(win) end
local ann = main and main:FindFirstChild("Announce")
out.Banner = ann ~= nil and ann.Visible
local popup = main and main:FindFirstChild("RewardPopup")
local title = popup and popup:FindFirstChild("Title", true)
if title then out.PopupTitle = { Text = title.Text, Fits = title.TextFits, Rect = rect(title) } end
return HttpService:JSONEncode(out)
'''


def probe(c):
    raw = dv.luau(c, PROBE, "Client").strip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {"raw": raw[:300]}


def shot(c, dev, view, rows):
    img = qv.grab(c, f"nw_{dev}_{view}")
    path = os.path.join(RAW, f"{dev}_{view}.png")
    if img:
        img.save(path)
    p = probe(c)
    rows.append({"device": dev, "view": view, "probe": p, "file": os.path.relpath(path, ROOT).replace("\\", "/")})
    print(dev, view, json.dumps(p, ensure_ascii=False)[:300])


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
            print(dev, dv.luau(c, wa.OPEN % "PotionShop", "Server").strip())
            time.sleep(1.5)
            print(dev, dv.luau(c, NOTIFY % THREE, "Server").strip())
            time.sleep(1.5)
            shot(c, dev, "short", rows)
            print(dev, dv.luau(c, wa.OPEN % "Menu", "Server").strip())
            time.sleep(1.5)
            print(dev, dv.luau(c, NOTIFY % ONE, "Server").strip())
            time.sleep(1.2)
            shot(c, dev, "tall", rows)
            print(dev, dv.luau(c, wa.VACATION_SET, "Server").strip())
            time.sleep(0.5)
            print(dev, dv.luau(c, wa.OPEN % "Vacation", "Server").strip())  # the popup closes the menu first
            time.sleep(2.0)
            shot(c, dev, "vac", rows)
            print(dev, dv.luau(c, wa.CLOSE_REWARD, "Client").strip())
            print(dev, dv.luau(c, NOTIFY % ONE.replace("Slime Jelly", "Goblin Tooth"), "Server").strip())
            time.sleep(1.2)
            shot(c, dev, "free", rows)
    return rows


def sheet(rows):
    from PIL import Image, ImageDraw
    tiles = []
    for r in rows:
        f = os.path.join(ROOT, r["file"])
        if not os.path.exists(f):
            continue
        im = Image.open(f).convert("RGB")
        tw = 640
        im = im.resize((tw, int(tw * im.height / im.width)), Image.LANCZOS)
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, tw, 18], fill=(16, 20, 40))
        p = r["probe"]
        d.text((5, 3), f'{r["device"]} {r["view"]}  toasts {len(p.get("Toasts", []))}  window {p.get("Window")}  '
                       f'banner {p.get("Banner")}', fill=(255, 255, 0))
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
        json.dump({"tool": "tools/notify_window_view.py", "rows": rows}, f, ensure_ascii=False, indent=2)
    print("sheet:", sheet(rows))


if __name__ == "__main__":
    main()
