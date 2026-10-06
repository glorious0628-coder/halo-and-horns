"""
실시간 지도 회전(A23-51, 사용자 2026-10-06 "지도도 사용자가 가는 방향으로 회전해야 돼") 확인: 연습 Studio(UiSandbox) Play에서
캐릭터를 북·동·남·서로 돌려 세우고(서버에서 몸 방향만 바꿈) 1.5초 뒤 실시간 지도를 찍는다. 지도 판(Rot)이 캐릭터 방향만큼
돌고, 내 화살표(MapPlayerArrow, 진영 색)는 늘 위, 테두리 'N'이 북쪽을 따라 도는지 본다. 큰 지도(M) 화살표도 그림으로 바뀐 것을
같이 잰다.
결과: art/review/minimap_turn_2026-10-06.jpg + docs/art/verification_2026-10-06/minimap_turn_view_2026-10-06.json.

  py tools/minimap_turn_view.py [pc] [phone]
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
RAW = os.path.join(ROOT, "build", "minimap_turn_view")
SHEET = os.path.join(ROOT, "art", "review", "minimap_turn_2026-10-06.jpg")
REPORT = os.path.join(ROOT, "docs", "art", "verification_2026-10-06", "minimap_turn_view_2026-10-06.json")
YAWS = [("north", 0), ("east", 90), ("south", 180), ("west", 270)]

# the minimap root, its turning plate and my arrow (screen px from the very top-left, as in topbar_view)
PROBE = r'''
local HttpService = game:GetService("HttpService")
local pg = game.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
local probe = pg:FindFirstChild("MMViewProbe")
if not probe then
	probe = Instance.new("ScreenGui")
	probe.Name, probe.IgnoreGuiInset, probe.ResetOnSpawn = "MMViewProbe", true, false
	pcall(function() probe.ScreenInsets = Enum.ScreenInsets.None end)
	probe.Parent = pg
	task.wait(0.1)
end
local o = probe.AbsolutePosition
local main = pg:FindFirstChild("MainGui")
local root = main and main:FindFirstChild("MiniMap")
local out = { Screen = { probe.AbsoluteSize.X, probe.AbsoluteSize.Y } }
if root then
	out.Box = { root.AbsolutePosition.X - o.X, root.AbsolutePosition.Y - o.Y, root.AbsoluteSize.X, root.AbsoluteSize.Y }
	local rot = root:FindFirstChild("Rot", true)
	local me = root:FindFirstChild("Me", true)
	local north = root:FindFirstChild("North", true)
	out.Rot = rot and rot.Rotation or nil
	out.Me = me and { Class = me.ClassName, Rotation = me.Rotation, W = me.AbsoluteSize.X,
		Tint = me:IsA("ImageLabel") and { me.ImageColor3.R, me.ImageColor3.G, me.ImageColor3.B } or nil } or nil
	out.North = north and { north.AbsolutePosition.X - o.X + north.AbsoluteSize.X / 2, north.AbsolutePosition.Y - o.Y + north.AbsoluteSize.Y / 2 } or nil
end
local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
if hrp then
	local l = hrp.CFrame.LookVector
	out.Yaw = math.deg(math.atan2(l.X, -l.Z))
end
return HttpService:JSONEncode(out)
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
        for label, yaw in YAWS:
            print(dev, label, dv.luau(c, qv.PLACE % (300, 0, yaw), "Server").strip())
            time.sleep(1.8)  # the map eases (TurnEase 8/s: 99% after ~0.6 s)
            probe = json.loads(dv.luau(c, PROBE, "Client").strip())
            img = qv.grab(c, f"mm_{dev}_{label}")
            path = os.path.join(RAW, f"{dev}_{label}.png")
            if img:
                img.save(path)
            rows.append({"device": dev, "facing": label, "yaw": yaw, "file": os.path.relpath(path, ROOT).replace("\\", "/"),
                         "probe": probe})
            print(dev, label, "rot", probe.get("Rot"), "me", (probe.get("Me") or {}).get("Rotation"),
                  (probe.get("Me") or {}).get("Class"), "yaw", probe.get("Yaw"))


def sheet(rows):
    from PIL import Image, ImageDraw, ImageFont
    tiles = []
    for r in rows:
        p = r.get("probe") or {}
        f = os.path.join(ROOT, r["file"])
        if not os.path.exists(f) or not p.get("Box"):
            continue
        img = Image.open(f).convert("RGB")
        sw, sh = p["Screen"]
        sx, sy = img.width / sw, img.height / sh
        x, y, w, h = p["Box"]
        pad = w * 0.15
        crop = img.crop((int((x - pad) * sx), int((y - pad) * sy), int((x + w + pad) * sx), int((y + h + pad) * sy)))
        crop = crop.resize((300, int(300 * crop.height / max(1, crop.width))), Image.LANCZOS)
        d = ImageDraw.Draw(crop)
        try:
            font = ImageFont.truetype("arial.ttf", 15)
        except OSError:
            font = ImageFont.load_default()
        d.rectangle([0, 0, 300, 20], fill=(16, 20, 40))
        d.text((5, 2), f'{r["device"]} facing {r["facing"]}  map {p.get("Rot", 0):.0f}°', fill=(255, 255, 255), font=font)
        tiles.append(crop)
    if not tiles:
        return None
    cols = 4
    th = max(t.height for t in tiles)
    rows_n = (len(tiles) + cols - 1) // cols
    out = Image.new("RGB", (cols * 300, rows_n * th), (0, 0, 0))
    for i, t in enumerate(tiles):
        out.paste(t, ((i % cols) * 300, (i // cols) * th))
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    out.save(SHEET, quality=88, optimize=True)
    return SHEET


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    devices = [a for a in sys.argv[1:] if a in dv.DEVICES] or ["pc"]
    rows = []
    with dv.sandbox() as c:
        run(c, devices, rows)
    path = sheet(rows)
    checks = []
    for r in rows:
        p = r.get("probe") or {}
        rot, me = p.get("Rot"), (p.get("Me") or {})
        if rot is None:
            continue
        # the map is turned by -yaw (so the facing is up), my arrow stays at 0
        diff = ((rot + r["yaw"]) + 180) % 360 - 180
        checks.append({"device": r["device"], "facing": r["facing"], "mapTurnError": round(diff, 1),
                       "arrowRotation": me.get("Rotation"), "arrowArt": me.get("Class") == "ImageLabel",
                       "pass": abs(diff) <= 2 and abs(me.get("Rotation") or 0) <= 0.5})
    report = {"tool": "tools/minimap_turn_view.py", "sheet": "art/review/minimap_turn_2026-10-06.jpg", "checks": checks,
              "rows": rows}
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    for ch in checks:
        print(ch)
    print("sheet:", path, "report:", REPORT)


if __name__ == "__main__":
    main()
