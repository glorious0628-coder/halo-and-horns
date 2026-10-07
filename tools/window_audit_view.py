"""
창 꾸미기 점검표(검수 2026-10-07, 사용자 'Vacation Bonus 창도 멋있게'): 연습 Studio(UiSandbox) Play에서 Panels의 모든 창과
팝업(확인 상자·알림)을 하나씩 열어 기기(PC·폰)마다 찍고, 창 안에서 보이는 것을 센다:
  Art   : 보이는 그림(ImageLabel / ImageButton)을 Config.UIArt.Parts 이름으로 (승인 그림인지)
  Code  : 그림 없이 코드로 칠한 면(배경이 보이는 Frame / TextButton …) - '코드 대체 모양'
  Buttons: 그림 버튼 / 코드 버튼 수
결과: build/window_audit/<dev>_<id>.png, art/review/window_audit_<dev>_2026-10-07.jpg,
docs/art/verification_2026-10-07/window_audit_2026-10-07.json (표는 docs/design/window_art_audit_2026-10-07.md에 손으로)

  py tools/window_audit_view.py [pc] [phone]
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
RAW = os.path.join(ROOT, "build", "window_audit")
SHEET = os.path.join(ROOT, "art", "review", "window_audit_%s_2026-10-07.jpg")
REPORT = os.path.join(ROOT, "docs", "art", "verification_2026-10-07", "window_audit_2026-10-07.json")

# Panels windows (BUILDERS + Panels.Register); Story first (it waits while another window is open)
WINDOWS = ["Story", "Welcome", "Menu", "Travel", "Class", "Rebirth", "Altar", "Items", "WeaponShop", "PotionShop",
           "Shop", "Vacation", "Settings", "Help", "News", "Nickname"]

OPEN = r'''
local p = game.Players:GetPlayers()[1]
local RS = game:GetService("ReplicatedStorage")
local r = RS:FindFirstChild("Remotes")
r = r and r:FindFirstChild("OpenPanel")
if not (p and r) then return "no remote" end
local id = "%s"
local arg = nil
if id == "Story" then
	local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
	local defs = Config.StoryQuests and Config.StoryQuests.Defs or {}
	local pick = nil
	for _, sid in Config.StoryQuests.Main or {} do
		local def = defs[sid]
		for st, step in (def and def.Steps or {}) do
			local obj = step.Obj
			if step.Panel and type(obj) == "table" and obj.Type == "Choice" then pick = { Id = sid, St = st, Var = "Default" }; break end
		end
		if pick then break end
	end
	if not pick then
		for sid, def in defs do
			for st, step in (def.Steps or {}) do
				if step.Panel then pick = { Id = sid, St = st, Var = "Default" }; break end
			end
			if pick then break end
		end
	end
	arg = pick
elseif id == "Welcome" then
	p:SetAttribute("TutorialStep", 0)
end
r:FireClient(p, id, arg)
return "open " .. id .. (arg and (" " .. arg.Id .. "/" .. tostring(arg.St)) or "")
'''

# notices + the confirm box (a UIKit copy: execute_luau gets its own module copies; same build code as the real one)
POPUPS = r'''
local p = game.Players.LocalPlayer
local pg = p:FindFirstChildOfClass("PlayerGui")
local main = pg:FindFirstChild("MainGui")
local kit = require(p:WaitForChild("PlayerScripts"):WaitForChild("UIKit"))
kit.Gui = main
local ok, err = pcall(kit.Confirm, "Change class?", "Your level and items stay. You can change again later.", "Change", nil)
return "confirm " .. tostring(ok) .. " " .. tostring(err)
'''

CLOSE_CONFIRM = r'''
local main = game.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui"):FindFirstChild("MainGui")
local c = main and main:FindFirstChild("ConfirmDialog")
if c then c:Destroy() end
return "closed"
'''

NOTICES = r'''
local p = game.Players:GetPlayers()[1]
local RS = game:GetService("ReplicatedStorage")
p:SetAttribute("TutorialStep", 99)
local n = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Notify")
if n then
	n:FireClient(p, { Text = "The Pumpkin King appeared in the Pumpkin Patch! Let's beat it together!", Kind = "announce", Duration = 30 })
	n:FireClient(p, { Text = "Daily quest done! +60 gold", Kind = "reward", Duration = 30 })
	n:FireClient(p, { Text = "Not enough gold.", Kind = "bad", Duration = 30 })
end
return "notices"
'''

# what one window / popup is made of (client)
PROBE = r'''
local HttpService = game:GetService("HttpService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local byId = {}
for name, def in (Config.UIArt and Config.UIArt.Parts or {}) do
	if type(def) == "table" and type(def.Id) == "string" then
		local n = string.match(def.Id, "%%d+")
		if n then byId[n] = name end
	end
end
local pg = game.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
local main = pg:FindFirstChild("MainGui")
local root = main and main:FindFirstChild("%s")
local function shown(g)
	while g and g ~= pg do
		if g:IsA("GuiObject") and not g.Visible then return false end
		if g:IsA("LayerCollector") and not g.Enabled then return false end
		g = g.Parent
	end
	return true
end
local out = { Root = root and root.Name or nil, Shown = root ~= nil and shown(root), Art = {}, Code = {},
	Buttons = { Art = 0, Code = 0 }, Window = nil }
if root and out.Shown then
	local win = root:FindFirstChild("Window") or root:FindFirstChild("NicknameWindow") or root:FindFirstChild("Box")
	if win then
		out.Window = { win.ClassName, math.floor(win.AbsoluteSize.X), math.floor(win.AbsoluteSize.Y) }
	end
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") and shown(d) and d.AbsoluteSize.X >= 6 and d.AbsoluteSize.Y >= 6 then
			local isImg = (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "" and d.ImageTransparency < 0.95
			if isImg then
				local n = string.match(d.Image, "rbxassetid://(%%d+)")
				local part = (n and byId[n]) or (string.find(d.Image, "rbxthumb", 1, true) and "Headshot") or ("other:" .. d.Image)
				out.Art[part] = (out.Art[part] or 0) + 1
			elseif d.BackgroundTransparency < 0.9 then
				local key = d.ClassName .. ":" .. d.Name
				out.Code[key] = (out.Code[key] or 0) + 1
			end
			if d:IsA("GuiButton") then
				local art = (d:IsA("ImageButton") and d.Image ~= "") or d:FindFirstChildWhichIsA("ImageLabel") ~= nil
				if art then out.Buttons.Art += 1 else out.Buttons.Code += 1 end
			end
		end
	end
end
return HttpService:JSONEncode(out)
'''


def probe(c, root_name):
    raw = dv.luau(c, PROBE % root_name, "Client").strip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {"raw": raw[:300]}


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
            for wid in WINDOWS:
                print(dev, dv.luau(c, OPEN % wid, "Server").strip())
                time.sleep(2.2)
                img = qv.grab(c, f"wa_{dev}_{wid}")
                path = os.path.join(RAW, f"{dev}_{wid}.png")
                if img:
                    img.save(path)
                p = probe(c, "PanelsModal")
                rows.append({"device": dev, "id": wid, "probe": p, "file": os.path.relpath(path, ROOT).replace("\\", "/")})
                print(dev, wid, json.dumps(p, ensure_ascii=False)[:300])
            # popups: the confirm box (over the last window), then the notices without a window
            print(dev, dv.luau(c, POPUPS, "Client").strip())
            time.sleep(1.2)
            img = qv.grab(c, f"wa_{dev}_Confirm")
            path = os.path.join(RAW, f"{dev}_Confirm.png")
            if img:
                img.save(path)
            rows.append({"device": dev, "id": "Confirm", "probe": probe(c, "ConfirmDialog"),
                         "file": os.path.relpath(path, ROOT).replace("\\", "/")})
            print(dev, dv.luau(c, CLOSE_CONFIRM, "Client").strip())
            print(dev, dv.luau(c, NOTICES, "Server").strip())
            time.sleep(1.5)
            img = qv.grab(c, f"wa_{dev}_Notices")
            path = os.path.join(RAW, f"{dev}_Notices.png")
            if img:
                img.save(path)
            rows.append({"device": dev, "id": "Notices", "probe": {},
                         "file": os.path.relpath(path, ROOT).replace("\\", "/")})
    return rows


def sheets(rows):
    from PIL import Image, ImageDraw
    out = []
    for dev in ("pc", "phone"):
        tiles = []
        for r in rows:
            if r["device"] != dev:
                continue
            f = os.path.join(ROOT, r["file"])
            if not os.path.exists(f):
                continue
            im = Image.open(f).convert("RGB")
            tw = 480
            im = im.resize((tw, int(tw * im.height / im.width)), Image.LANCZOS)
            d = ImageDraw.Draw(im)
            d.rectangle([0, 0, tw, 18], fill=(16, 20, 40))
            p = r["probe"]
            art = sum((p.get("Art") or {}).values())
            code = sum((p.get("Code") or {}).values())
            b = p.get("Buttons") or {}
            d.text((5, 3), f'{dev} {r["id"]}  art {art}  code {code}  btn art/code {b.get("Art", "-")}/{b.get("Code", "-")}',
                   fill=(255, 255, 0))
            tiles.append(im)
        if not tiles:
            continue
        cols = 3
        th = max(t.height for t in tiles)
        sheet = Image.new("RGB", (cols * 486, ((len(tiles) + cols - 1) // cols) * (th + 6)), (0, 0, 0))
        for i, t in enumerate(tiles):
            sheet.paste(t, ((i % cols) * 486, (i // cols) * (th + 6)))
        path = SHEET % dev
        os.makedirs(os.path.dirname(path), exist_ok=True)
        sheet.save(path, quality=84, optimize=True)
        out.append(path)
    return out


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    devices = [a for a in sys.argv[1:] if a in dv.DEVICES] or ["pc", "phone"]
    rows = capture(devices)
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"tool": "tools/window_audit_view.py", "rows": rows}, f, ensure_ascii=False, indent=2)
    print("sheets:", sheets(rows))


if __name__ == "__main__":
    main()
