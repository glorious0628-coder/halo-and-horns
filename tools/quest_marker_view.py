"""
퀘스트 목표 마커(A23-36) 화면 확인: 연습 Studio(UiSandbox) Play에서 PC 1280x720·폰 749x361로 교차로·말랑 초원·호박밭·
유령 숲마다 마커를 앞(화면 안 = 공중 아이콘 + 거리)과 뒤(화면 밖 = 가장자리 아이콘 + 화살표)에 두고 찍는다. 초원에서는
받기(금색)도 찍는다. 마지막으로 미리보기 없이 실제 경로(첫 임무 수락 → 교차로에서 초원 쪽)를 찍는다.
마커 위치는 QuestMarker의 Studio 전용 속성 QuestMarkerPreview("x,y,z" / "x,y,z,claim")로 준다(게임에선 안 읽음).

각 캡처마다 마커 아이콘의 실제 px 크기(AbsoluteSize)와 화면 위치를 재고, 아이콘 둘레 바탕과의 대비(WCAG, 아이콘 3:1
기준 = 화면 검수 기준 4)를 PIL로 잰다. 결과: art/review/quest_marker_2026-10-06.jpg(시트) +
docs/art/verification_2026-10-06/quest_marker_view_2026-10-06.json, 원본 캡처는 build/quest_marker_view/.

  py tools/quest_marker_view.py [pc] [phone]
STUDIO_NAME은 UiSandbox로 고정(dv.sandbox가 먼저 확인). 끝나면(오류가 나도) Play를 멈추고 기기 흉내를 끈다.
"""

import base64
import io
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ["STUDIO_NAME"] = "UiSandbox"  # practice Studio only: forced before studio_mcp is imported (via device_view)
import device_view as dv  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "build", "quest_marker_view")
SHEET = os.path.join(ROOT, "art", "review", "quest_marker_2026-10-06.jpg")
REPORT = os.path.join(ROOT, "docs", "art", "verification_2026-10-06", "quest_marker_view_2026-10-06.json")

# zone: (stand x, z, facing yaw degrees: 0 = -Z, 90 = +X)
SPOTS = [
    ("Crossroads", (0, -20, 90)),
    ("SlimeMeadow", (300, 0, 90)),
    ("PumpkinPatch", (360, 205, 180)),
    ("HauntedHollow", (235, 240, 270)),
]

PLACE = r'''
local p = game.Players:GetPlayers()[1]
local hrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if not hrp then return "no character" end
local x, z, yaw = %f, %f, %f
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { p.Character }
local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
local y = hit and hit.Position.Y or 0
local fwd = Vector3.new(math.sin(math.rad(yaw)), 0, -math.cos(math.rad(yaw)))
local pos = Vector3.new(x, y + 3.5, z)
hrp.AssemblyLinearVelocity = Vector3.zero
hrp.CFrame = CFrame.lookAt(pos, pos + fwd)
return string.format("%%.1f,%%.1f,%%.1f|%%.3f,%%.3f", pos.X, y, pos.Z, fwd.X, fwd.Z)
'''

PIN = r'''
local RS = game:GetService("RunService")
local cam = workspace.CurrentCamera
local p = game.Players.LocalPlayer
local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if not hrp then return "no character" end
local fwd = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
fwd = fwd.Magnitude > 0.01 and fwd.Unit or Vector3.new(0, 0, -1)
local eye = hrp.Position - fwd * 16 + Vector3.new(0, 7, 0)
local look = hrp.Position + fwd * 20 + Vector3.new(0, 1, 0)
local cf = CFrame.lookAt(eye, look)
RS:UnbindFromRenderStep("QMViewPin")
RS:BindToRenderStep("QMViewPin", Enum.RenderPriority.Last.Value, function()
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = cf
end)
return "pinned"
'''

# target: ahead (on screen) or behind-left (off screen); claim -> gold
AIM = r'''
local p = game.Players.LocalPlayer
local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if not hrp then return "no character" end
local fwd = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
fwd = fwd.Unit
local right = Vector3.new(-fwd.Z, 0, fwd.X)
local mode = "%s"
local t
if mode == "ahead" then
	t = hrp.Position + fwd * 70 + right * 12
elseif mode == "edge" then
	t = hrp.Position - fwd * 60 - right * 45
else
	t = nil
end
if t then
	p:SetAttribute("QuestMarkerPreview", string.format("%%.1f,%%.1f,%%.1f%%s", t.X, t.Y, t.Z, "%s"))
else
	p:SetAttribute("QuestMarkerPreview", nil)
end
return tostring(p:GetAttribute("QuestMarkerPreview"))
'''

# where the marker is on screen (viewport px) and how big its icon is
MEASURE = r'''
local p = game.Players.LocalPlayer
local pg = p:FindFirstChildOfClass("PlayerGui")
local cam = workspace.CurrentCamera
local out = { Viewport = { cam.ViewportSize.X, cam.ViewportSize.Y } }
local gui = pg and pg:FindFirstChild("QuestMarkerGui")
local holder = gui and gui:FindFirstChild("QuestMarker")
if holder and holder.Visible then
	local box = holder:FindFirstChild("IconBox")
	local text = holder:FindFirstChild("Distance")
	local arrow = holder:FindFirstChild("Arrow")
	out.Kind = (arrow and arrow.Visible) and "edge" or "onscreen"
	-- the capture shows the whole device screen: measure against a full-screen probe gui (no inset, no safe area)
	local probe = pg:FindFirstChild("QMViewProbe")
	if not probe then
		probe = Instance.new("ScreenGui")
		probe.Name, probe.IgnoreGuiInset, probe.ResetOnSpawn = "QMViewProbe", true, false
		pcall(function() probe.ScreenInsets = Enum.ScreenInsets.None end)
		probe.Parent = pg
		task.wait(0.1)
	end
	local o = probe.AbsolutePosition
	out.Screen = { probe.AbsoluteSize.X, probe.AbsoluteSize.Y }
	out.Icon = box and { box.AbsolutePosition.X - o.X, box.AbsolutePosition.Y - o.Y, box.AbsoluteSize.X, box.AbsoluteSize.Y } or nil
	out.Arrow = arrow and arrow.Visible and { arrow.AbsoluteSize.X, arrow.AbsoluteSize.Y, arrow.Rotation } or nil
	out.Text = text and text.Text or nil
	out.TextPx = text and text.TextBounds.Y or nil
	local icon = box and box:FindFirstChildWhichIsA("GuiObject")
	if icon and icon:IsA("ImageLabel") then out.Tint = { icon.ImageColor3.R, icon.ImageColor3.G, icon.ImageColor3.B } end
	out.GuiOrigin = { o.X, o.Y }
end
local main = pg and pg:FindFirstChild("MainGui")
local sc = main and main:FindFirstChildOfClass("UIScale")
out.UIScale = sc and sc.Scale or nil
out.Zone = p:GetAttribute("ZoneId")
out.Clock = game:GetService("Lighting").ClockTime
return game:GetService("HttpService"):JSONEncode(out)
'''

TOPBAR = r'''
local gs = game:GetService("GuiService")
local tb = gs.TopbarInset
local tl, br = gs:GetGuiInset()
local cam = workspace.CurrentCamera
return string.format("TopbarInset min(%.1f,%.1f) max(%.1f,%.1f) h=%.1f | GuiInset tl(%.1f,%.1f) br(%.1f,%.1f) | viewport %dx%d",
	tb.Min.X, tb.Min.Y, tb.Max.X, tb.Max.Y, tb.Height, tl.X, tl.Y, br.X, br.Y, cam.ViewportSize.X, cam.ViewportSize.Y)
'''

REAL = r'''
local p = game.Players.LocalPlayer
p:SetAttribute("QuestMarkerPreview", nil)
local net = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes", true)
local function fire(name)
	local r = game:GetService("ReplicatedStorage"):FindFirstChild(name, true)
	if r and r:IsA("RemoteEvent") then r:FireServer() return true end
	return false
end
local a = fire("RequestTutorial")
task.wait(0.6)
local b = fire("AcceptTutorial")
return tostring(a) .. "," .. tostring(b) .. " step=" .. tostring(p:GetAttribute("TutorialStep"))
'''


def grab(c, cap_id):
    from PIL import Image
    res = c.call("screen_capture", {"capture_id": cap_id})
    for part in res.get("content", []):
        if part.get("type") == "image":
            return Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB")
    return None


def lum(rgb):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = rgb
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def contrast(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def measure_contrast(img, m):
    """icon fill (centre 30%) and rim vs the ring of background just outside the icon box, in capture px"""
    if not m or not m.get("Icon"):
        return None
    vw, vh = m.get("Screen") or m["Viewport"]
    sx, sy = img.width / vw, img.height / vh
    x, y, w, h = m["Icon"]
    x0, y0, x1, y1 = x * sx, y * sy, (x + w) * sx, (y + h) * sy
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    px = img.load()

    def avg(points):
        pts = [px[int(a), int(b)] for a, b in points if 0 <= a < img.width and 0 <= b < img.height]
        if not pts:
            return None
        return tuple(sum(p[i] for p in pts) / len(pts) for i in range(3))
    fill = avg([(cx + dx, cy + dy) for dx in range(-int((x1 - x0) * 0.08), int((x1 - x0) * 0.08) + 1, 2)
                for dy in range(-int((y1 - y0) * 0.08), int((y1 - y0) * 0.08) + 1, 2)])
    pad = max(4, (x1 - x0) * 0.25)
    ring = []
    for k in range(0, 360, 6):
        import math
        a = math.radians(k)
        ring.append((cx + math.cos(a) * ((x1 - x0) / 2 + pad), cy + math.sin(a) * ((y1 - y0) / 2 + pad)))
    bg = avg(ring)
    if fill is None or bg is None:
        return None
    rim = (26, 40, 79)  # the art's navy outline
    return {"fill": [round(v) for v in fill], "background": [round(v) for v in bg],
            "fillVsBackground": round(contrast(fill, bg), 2), "rimVsBackground": round(contrast(rim, bg), 2),
            "best": round(max(contrast(fill, bg), contrast(rim, bg)), 2),
            # inside the icon: the fill against its own navy rim + dark halo (the shape reads on any background)
            "fillVsRim": round(contrast(fill, rim), 2)}


def shoot(c, dev, label, out, rows):
    time.sleep(2.2)
    m = None
    try:
        m = json.loads(dv.luau(c, MEASURE, "Client").strip())
    except Exception as e:  # noqa: BLE001
        print("measure failed:", e)
    img = grab(c, f"qm_{dev}_{label}")
    if img is None:
        print(label, "no capture")
        return
    path = os.path.join(out, f"{dev}_{label}.png")
    img.save(path)
    row = {"device": dev, "shot": label, "file": os.path.relpath(path, ROOT).replace("\\", "/"), "marker": m,
           "contrast": measure_contrast(img, m)}
    if m and m.get("Icon"):
        row["iconPx"] = [round(m["Icon"][2], 1), round(m["Icon"][3], 1)]
    rows.append(row)
    print(dev, label, row.get("iconPx"), (m or {}).get("Kind"), (m or {}).get("Text"),
          (row.get("contrast") or {}).get("best"))


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
        for zone, (x, z, yaw) in SPOTS:
            print(dev, zone, dv.luau(c, PLACE % (x, z, yaw), "Server").strip())
            time.sleep(2.5)  # ZoneService + ZoneLook settle
            dv.luau(c, PIN, "Client")
            dv.luau(c, AIM % ("ahead", ""), "Client")
            shoot(c, dev, f"{zone}_ahead", RAW, rows)
            dv.luau(c, AIM % ("edge", ""), "Client")
            shoot(c, dev, f"{zone}_edge", RAW, rows)
            if zone == "SlimeMeadow":
                dv.luau(c, AIM % ("ahead", ",claim"), "Client")
                shoot(c, dev, f"{zone}_claim", RAW, rows)
        # A23-40 보강 groundwork: the real Roblox top bar row on this device (GuiService.TopbarInset / GetGuiInset)
        print(dev, "topbar:", dv.luau(c, TOPBAR, "Client").strip())
        # the real path (no preview): accept the first mission in the Crossroads facing the meadow side
        x, z, yaw = SPOTS[0][1]
        dv.luau(c, PLACE % (x, z, yaw), "Server")
        time.sleep(2)
        dv.luau(c, PIN, "Client")
        print(dev, "real:", dv.luau(c, REAL, "Client").strip())
        time.sleep(3)
        shoot(c, dev, "real_step1", RAW, rows)
        dv.luau(c, 'game:GetService("RunService"):UnbindFromRenderStep("QMViewPin") return "ok"', "Client")


def sheet(rows):
    from PIL import Image, ImageDraw, ImageFont
    cols = 3
    tw = 640
    tiles = []
    for r in rows:
        img = Image.open(os.path.join(ROOT, r["file"])).convert("RGB")
        th = int(img.height * tw / img.width)
        t = img.resize((tw, th), Image.LANCZOS)
        d = ImageDraw.Draw(t)
        m = r.get("marker") or {}
        con = r.get("contrast") or {}
        cap = f'{r["device"]} {r["shot"]}  icon {r.get("iconPx")}px  {m.get("Kind")} {m.get("Text")}  contrast {con.get("best")}'
        d.rectangle([0, 0, tw, 22], fill=(16, 20, 40))
        try:
            font = ImageFont.truetype("arial.ttf", 15)
        except OSError:
            font = ImageFont.load_default()
        d.text((6, 3), cap, fill=(255, 255, 255), font=font)
        # 2x crop of the marker in the corner
        if m.get("Icon"):
            vw, vh = m.get("Screen") or m["Viewport"]
            sx = img.width / vw
            x, y, w, h = m["Icon"]
            cx, cy = (x + w / 2) * sx, (y + h / 2) * sx
            half = max(w, h) * sx * 1.1
            crop = img.crop((int(cx - half), int(cy - half), int(cx + half), int(cy + half)))
            crop = crop.resize((150, 150), Image.NEAREST)
            t.paste(crop, (tw - 154, 26))
            d.rectangle([tw - 155, 25, tw - 3, 177], outline=(255, 220, 80), width=2)
        tiles.append(t)
    if not tiles:
        return None
    th = max(t.height for t in tiles)
    rows_n = (len(tiles) + cols - 1) // cols
    out = Image.new("RGB", (cols * tw, rows_n * th), (0, 0, 0))
    for i, t in enumerate(tiles):
        out.paste(t, ((i % cols) * tw, (i // cols) * th))
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    out.save(SHEET, quality=86, optimize=True)
    return SHEET


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    devices = [a for a in sys.argv[1:] if a in dv.DEVICES] or ["pc", "phone"]
    rows = []
    with dv.sandbox() as c:  # sandbox check first; Play stop + device reset at the end, also after an error
        run(c, devices, rows)
    path = sheet(rows)
    minimum = min((min(r["iconPx"]) for r in rows if r.get("iconPx")), default=None)
    report = {"tool": "tools/quest_marker_view.py", "devices": devices, "sheet": SHEET.replace(ROOT, "").lstrip("\\/"),
              "minIconPx": minimum, "rows": rows,
              "note": "iconPx = the marker icon's AbsoluteSize (viewport px); contrast = WCAG ratio of the icon fill or "
                      "its navy rim against the ring just outside the icon (best of the two), target >= 3 (rubric 4)"}
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print("sheet:", path, "report:", REPORT, "min icon px:", minimum)


if __name__ == "__main__":
    main()
