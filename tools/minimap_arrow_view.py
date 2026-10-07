"""
미니맵 내 화살표 확인(A23-66, 2026-10-07): 연습 Studio(UiSandbox) Play에서 카메라를 한 방향에 고정하고 캐릭터만
앞·왼쪽·오른쪽·뒤로 돌려, 미니맵 가운데 화살표가 '^ < > v'로 도는지(Rotation 0 / -90 / 90 / 180), 지도는 카메라 방향이
위인 채 그대로인지, 'N'이 테두리에서 북쪽을 가리키는지 재고 미니맵을 확대해 찍는다. 빛(PC)·뿔(폰) 화살표 그림도 본다.
결과: art/review/minimap_arrow_2026-10-07.jpg + docs/art/verification_2026-10-07/minimap_arrow_2026-10-07.json

  py tools/minimap_arrow_view.py [pc] [phone]
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
RAW = os.path.join(ROOT, "build", "minimap_arrow_view")
SHEET = os.path.join(ROOT, "art", "review", "minimap_arrow_2026-10-07.jpg")
REPORT = os.path.join(ROOT, "docs", "art", "verification_2026-10-07", "minimap_arrow_2026-10-07.json")

# the character turned by `rel` degrees from the camera's (pinned) facing yaw 90 (= east), same spot
FACE = r'''
local p = game.Players:GetPlayers()[1]
local hrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if not hrp then return "no character" end
local yaw = math.rad(90 + %f)
local fwd = Vector3.new(math.sin(yaw), 0, -math.cos(yaw))
hrp.AssemblyLinearVelocity = Vector3.zero
hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + fwd)
return string.format("%%.2f,%%.2f", fwd.X, fwd.Z)
'''

PROBE = r'''
local pg = game.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
local main = pg:FindFirstChild("MainGui")
local mm = main and main:FindFirstChild("MiniMap", true)
local out = {}
if mm then
	local me = mm:FindFirstChild("Me", true)
	local rot = mm:FindFirstChild("Rot", true)
	local north = mm:FindFirstChild("North", true)
	local probe = pg:FindFirstChild("MAProbe")
	if not probe then
		probe = Instance.new("ScreenGui")
		probe.Name, probe.IgnoreGuiInset, probe.ResetOnSpawn = "MAProbe", true, false
		pcall(function() probe.ScreenInsets = Enum.ScreenInsets.None end)
		probe.Parent = pg
		task.wait(0.1)
	end
	local o = probe.AbsolutePosition
	out.Screen = { probe.AbsoluteSize.X, probe.AbsoluteSize.Y }
	out.Root = { mm.AbsolutePosition.X - o.X, mm.AbsolutePosition.Y - o.Y, mm.AbsoluteSize.X, mm.AbsoluteSize.Y }
	out.MeRot = me and me.Rotation
	out.MeImage = me and me:IsA("ImageLabel") and me.Image or nil
	out.MeTint = me and me:IsA("ImageLabel") and { math.floor(me.ImageColor3.R * 255), math.floor(me.ImageColor3.G * 255),
		math.floor(me.ImageColor3.B * 255) } or nil
	out.MapRot = rot and rot.Rotation
	if north then
		local c = mm.AbsolutePosition + mm.AbsoluteSize / 2
		local n = north.AbsolutePosition + north.AbsoluteSize / 2
		out.NorthDir = math.floor(math.deg(math.atan2(n.X - c.X, -(n.Y - c.Y))) + 0.5) -- clockwise from screen up
	end
end
local cam = workspace.CurrentCamera
local lv = cam.CFrame.LookVector
out.CamYaw = math.floor(math.deg(math.atan2(lv.X, -lv.Z)) + 0.5)
return game:GetService("HttpService"):JSONEncode(out)
'''

CASES = [("ahead", 0, 0), ("left", -90, -90), ("right", 90, 90), ("back", 180, 180)]


def wrap(a):
    return (a + 180) % 360 - 180


def run(c, dev, faction, rows):
    os.makedirs(RAW, exist_ok=True)
    name, w, h = dv.DEVICES[dev]
    dv.stop_play(c)
    print(dev, "device:", dv.luau(c, dv.SET_DEVICE % (name, w, h), "Edit").strip())
    c.call("start_stop_play", {"is_start": True})
    for _ in range(60):
        time.sleep(0.5)
        if "Client" in dv.state(c):
            break
    time.sleep(6)
    print(dev, "pick:", dv.luau(c, dv.PICK % faction, "Server").strip())
    time.sleep(5)
    print(dev, "place:", dv.luau(c, qv.PLACE % (20, -20, 90), "Server").strip())
    time.sleep(2)
    dv.luau(c, qv.PIN, "Client")  # the camera behind the character, looking east, fixed
    for label, rel, want in CASES:
        print(dev, label, dv.luau(c, FACE % rel, "Server").strip())
        time.sleep(1.8)  # the arrow eases (MeEase 12/s)
        probe = json.loads(dv.luau(c, PROBE, "Client").strip())
        img = qv.grab(c, f"ma_{dev}_{label}")
        path = os.path.join(RAW, f"{dev}_{label}.png")
        if img:
            img.save(path)
        me = probe.get("MeRot")
        ok_me = me is not None and abs(wrap(me - want)) <= 6
        # camera looks east (yaw 90): north is 90 deg counter-clockwise from screen up -> NorthDir about -90
        nd = probe.get("NorthDir")
        ok_n = nd is not None and abs(wrap(nd - wrap(-probe.get("CamYaw", 90)))) <= 8
        rows.append({"device": dev, "faction": faction, "case": label, "want": want, "probe": probe, "okArrow": ok_me,
                     "okNorth": ok_n, "file": os.path.relpath(path, ROOT).replace("\\", "/")})
        print(dev, label, "arrow", me, "want", want, "OK" if ok_me else "FAIL", "| north", nd, "OK" if ok_n else "FAIL",
              "| map", probe.get("MapRot"), "cam", probe.get("CamYaw"))
    dv.luau(c, 'game:GetService("RunService"):UnbindFromRenderStep("QMViewPin") return "ok"', "Client")


def sheet(rows):
    from PIL import Image, ImageDraw, ImageFont
    try:
        font = ImageFont.truetype("arial.ttf", 14)
    except OSError:
        font = ImageFont.load_default()
    tiles = []
    for r in rows:
        f = os.path.join(ROOT, r["file"])
        if not os.path.exists(f) or not r["probe"].get("Root"):
            continue
        img = Image.open(f).convert("RGB")
        k = img.width / max(1, r["probe"]["Screen"][0])
        x, y, w, h = (v * k for v in r["probe"]["Root"])
        crop = img.crop((int(x - 6 * k), int(y - 6 * k), int(x + w + 6 * k), int(y + h + 6 * k))).resize((240, 240))
        tile = Image.new("RGB", (240, 262), (16, 20, 40))
        tile.paste(crop, (0, 22))
        d = ImageDraw.Draw(tile)
        d.text((4, 3), f'{r["device"]} {r["faction"]} {r["case"]} {"OK" if r["okArrow"] and r["okNorth"] else "FAIL"}',
               fill=(255, 255, 255), font=font)
        tiles.append(tile)
    if not tiles:
        return None
    cols = 4
    out = Image.new("RGB", (cols * 240, ((len(tiles) + cols - 1) // cols) * 262), (0, 0, 0))
    for i, t in enumerate(tiles):
        out.paste(t, ((i % cols) * 240, (i // cols) * 262))
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    out.save(SHEET, quality=88)
    return SHEET


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    devices = [a for a in sys.argv[1:] if a in dv.DEVICES] or ["pc", "phone"]
    rows = []
    with dv.sandbox() as c:
        for dev in devices:
            run(c, dev, "Halo" if dev == "pc" else "Horns", rows)
    path = sheet(rows)
    passed = sum(1 for r in rows if r["okArrow"] and r["okNorth"])
    with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"tool": "tools/minimap_arrow_view.py", "passed": passed, "total": len(rows), "rows": rows}, f,
                  ensure_ascii=False, indent=2)
    print("sheet:", path, "report:", REPORT, "passed", passed, "/", len(rows))


if __name__ == "__main__":
    main()
