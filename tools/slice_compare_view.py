"""
9조각 '가운데 2px 띠' 고침 전·후 비교(검수 2026-10-07): 연습 Studio(UiSandbox) Play에서 기기(PC·폰)마다
HUD(호박 대왕·퀘스트 3줄·알림) → 무기 상점 창 → 물약 상점 창 → 진영 고르기를 찍는다. 전(--tag before, 옛 Config)과
후(--tag after)를 따로 찍은 뒤 --sheet 로 나란히 붙인다.
결과: build/slice_compare/<tag>/<dev>_<view>.png, 시트 art/review/slice_compare_2026-10-07.jpg

  py tools/slice_compare_view.py --tag before pc phone
  py tools/slice_compare_view.py --tag after pc phone
  py tools/slice_compare_view.py --sheet
"""

import argparse
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ["STUDIO_NAME"] = "UiSandbox"  # practice Studio only: forced before studio_mcp is imported (via device_view)
import device_view as dv  # noqa: E402
import quest_marker_view as qv  # noqa: E402
import text_fit_view as tf  # noqa: E402
import picker_view as pv  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "build", "slice_compare")
SHEET = os.path.join(ROOT, "art", "review", "slice_compare_2026-10-07.jpg")
VIEWS = ["hud", "weapon", "potion", "faction"]

OPEN = r'''
local p = game.Players:GetPlayers()[1]
local r = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
r = r and r:FindFirstChild("OpenPanel")
if not (p and r) then return "no remote" end
r:FireClient(p, "%s")
return "open %s"
'''


def capture(tag, devices):
    out = os.path.join(RAW, tag)
    os.makedirs(out, exist_ok=True)
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
            print(dev, dv.luau(c, tf.SETUP, "Server").strip())
            time.sleep(2.5)
            shots = [("hud", None), ("weapon", "WeaponShop"), ("potion", "PotionShop")]
            for view, panel in shots:
                if panel:
                    print(dev, dv.luau(c, OPEN % (panel, panel), "Server").strip())
                    time.sleep(2)
                img = qv.grab(c, f"sc_{tag}_{dev}_{view}")
                if img:
                    img.save(os.path.join(out, f"{dev}_{view}.png"))
            print(dev, dv.luau(c, pv.FRESH, "Server").strip())
            time.sleep(4.5)
            img = qv.grab(c, f"sc_{tag}_{dev}_faction")
            if img:
                img.save(os.path.join(out, f"{dev}_faction.png"))


def sheet():
    from PIL import Image, ImageDraw
    rows = []
    for dev in ("pc", "phone"):
        for view in VIEWS:
            pair = []
            for tag in ("before", "after"):
                f = os.path.join(RAW, tag, f"{dev}_{view}.png")
                if os.path.exists(f):
                    im = Image.open(f).convert("RGB")
                    im = im.resize((640, int(640 * im.height / im.width)), Image.LANCZOS)
                    d = ImageDraw.Draw(im)
                    d.rectangle([0, 0, 640, 18], fill=(16, 20, 40))
                    d.text((5, 3), f"{dev} {view} - {tag}", fill=(255, 255, 0))
                    pair.append(im)
            if len(pair) == 2:
                row = Image.new("RGB", (1290, max(p.height for p in pair)), (0, 0, 0))
                row.paste(pair[0], (0, 0))
                row.paste(pair[1], (650, 0))
                rows.append(row)
    if not rows:
        return None
    out = Image.new("RGB", (1290, sum(r.height for r in rows) + 6 * len(rows)), (0, 0, 0))
    y = 0
    for r in rows:
        out.paste(r, (0, y))
        y += r.height + 6
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    out.save(SHEET, quality=84, optimize=True)
    return SHEET


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("devices", nargs="*")
    ap.add_argument("--tag")
    ap.add_argument("--sheet", action="store_true")
    a = ap.parse_args()
    if a.sheet:
        print("sheet:", sheet())
        return
    capture(a.tag, [d for d in a.devices if d in dv.DEVICES] or ["pc", "phone"])


if __name__ == "__main__":
    main()
