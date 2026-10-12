"""거위 광장 photos (메인 반영 1, 2026-10-12): own test Play in the MAIN Studio (HH_MAIN_STUDIO=1) with a FRESH in-memory save.
Goose event started by DebugCommand "Goose": the HUD chip (Join), Join through the GooseSquare remote, inside the square, Leave visible. MCP only.
게임성 개발 1 10/12 (최종 검수): A23-68 folds the whole event strip until the first [Claim] (HUD.RookieFold), so the event
starts AFTER the tutorial is done (TutorialStep = Config.Tutorial.Steps.Done); a second short pass (05..07) keeps a
rookie in the tutorial: no Join outside (A23-68), but inside the square Leave + the egg bar show (fix/goose-rookie).
Usage: HH_MAIN_STUDIO=1 py tools/play_goose_square_photos.py [outdir-name]   Out: docs/art/verification_2026-10-12/main_apply/<outdir>/"""
import base64
import io
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-12", "main_apply", sys.argv[1] if len(sys.argv) > 1 else "goose_square")
os.makedirs(OUT, exist_ok=True)
LOG = []


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def lua(c, code, dm):
    try:
        return text_of(c.call("execute_luau", {"code": code, "datamodel_type": dm}))
    except Exception as e:  # noqa: BLE001
        return "ERR " + str(e)[:200]


def note(m):
    print(m, flush=True)
    LOG.append(m)


def save(c, name):
    res = c.call("screen_capture", {"capture_id": name})
    for part in res.get("content", []):
        if part.get("type") == "image":
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).save(os.path.join(OUT, name + ".png"))
            note("saved " + name)
            return
    note("capture failed " + name)


STATE = r"""
local p = game:GetService("Players"):GetPlayers()[1]
if not p then return "no player" end
local out = {}
for _, k in { "DataLoaded", "Faction", "Class", "ClassChosen", "Level", "WeaponTier" } do table.insert(out, k .. "=" .. tostring(p:GetAttribute(k))) end
return table.concat(out, " ")
"""
FIRE = r"""
game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("%s"):FireServer(%s)
return "fired %s"
"""
DEBUG = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local fn = game:GetService("ServerScriptService"):FindFirstChild("DebugCommand")
if not (p and fn) then return "no player / DebugCommand" end
local out = {}
for _, kv in { %s } do
	local ok, r = pcall(function() return fn:Invoke(p.Name, kv[1], kv[2]) end)
	table.insert(out, kv[1] .. "=" .. tostring(ok and r or ("ERR " .. tostring(r))))
end
return table.concat(out, " ")
"""
OPEN = r"""
local p = game:GetService("Players"):GetPlayers()[1]
game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("OpenPanel"):FireClient(p, "%s", %s)
return "open %s"
"""
CLOSE = r"""
local p = game:GetService("Players").LocalPlayer
for _, d in p:FindFirstChildOfClass("PlayerGui"):GetDescendants() do
	if d.Name == "PanelsModal" and d:IsA("Frame") then d.Visible = false end
end
return "closed"
"""
DISPATCH = r"""
local ps = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")
local kb = ps:FindFirstChild("Keybinds")
local d = kb and kb:FindFirstChild("Dispatch")
if not d then return "no dispatch" end
return tostring(d:Invoke({ KeyCode = Enum.KeyCode.%s }))
"""
PATH = r"""
local p = game:GetService("Players").LocalPlayer
local pg = p:FindFirstChildOfClass("PlayerGui")
local want, within, contains = "%s", "%s", %s
for _, d in pg:GetDescendants() do
	if d:IsA("GuiButton") and d.Visible and ((not contains and d.Name == want) or (contains and string.find(d.Name, want)))
		and (within == "" or d:FindFirstAncestor(within)) then
		local full = d:GetFullName()
		local pgName = pg:GetFullName()
		return "LocalPlayer.PlayerGui" .. string.sub(full, #pgName + 1)
	end
end
return "none"
"""
BUTTONS = r"""
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local out = {}
for _, d in pg:GetDescendants() do
	if d:IsA("GuiButton") and d.Visible and d:FindFirstAncestor("%s") then table.insert(out, d.Name) end
end
return table.concat(out, ",")
"""
WORDS = r"""
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local out = {}
for _, d in pg:GetDescendants() do
	if d:IsA("TextLabel") and d.Visible and d.Text ~= "" and d:FindFirstAncestor("PanelsModal") then table.insert(out, d.Name .. ":" .. d.Text) end
end
return table.concat(out, " | ")
"""


CHAR = r"""
local ok, m = pcall(function() return require(game:GetService("Players").LocalPlayer.PlayerScripts:WaitForChild("CharacterUI")) end)
if not ok then return "require failed: " .. tostring(m) end
local ok2, r = pcall(function() return m.%s end)
return "ok=" .. tostring(ok2) .. " r=" .. tostring(r)
"""


def char(c, expr):
    r = lua(c, CHAR % expr, "Client")
    note(f"CharacterUI.{expr}: {r}")
    time.sleep(1.2)
    return r


def wait_state(c, cond, timeout, every=1.0):
    t0, last = time.time(), ""
    while time.time() - t0 < timeout:
        last = lua(c, STATE, "Server")
        if cond(last):
            return last
        time.sleep(every)
    return last


def click(c, name, within="", contains=False, wait=1.0):
    path = lua(c, PATH % (name, within, "true" if contains else "false"), "Client")
    note(f"path {name}: {path}")
    if path.startswith("LocalPlayer."):
        r1 = c.call("user_mouse_input", {"datamodel_type": "Client", "actions": [
            {"action": "moveTo", "instance_path": path}, {"action": "mouseButtonClick", "mouse_button": "left"}]})
        r2 = r1
        note("mouse: " + text_of(r1)[:150] + " / " + text_of(r2)[:150])
        time.sleep(wait)
        return True
    return False


TUTOR = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local fn = game:GetService("ServerScriptService"):FindFirstChild("DebugCommand")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local step = %s
if step == "done" then step = Config.Tutorial.Steps.Done end
local ok, r = pcall(function() return fn:Invoke(p.Name, "TutorialStep", step) end)
return "TutorialStep=" .. tostring(p:GetAttribute("TutorialStep")) .. " (" .. tostring(ok and r or r) .. ")"
"""
FOLD = r"""
local ok, hud = pcall(function() return require(game:GetService("Players").LocalPlayer.PlayerScripts:WaitForChild("HUD")) end)
local fold = ok and type(hud.RookieFold) == "function" and hud.RookieFold()
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local vis = {}
for _, d in pg:GetDescendants() do
	if (d.Name == "GooseChip" or d.Name == "GooseTug" or d.Name == "GooseSquareButton") and d:IsA("GuiObject") then
		table.insert(vis, d.Name .. "=" .. tostring(d.Visible))
	end
end
return "RookieFold=" .. tostring(fold) .. " " .. table.concat(vis, " ")
"""
HUDWORDS = r"""
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local out = {}
for _, d in pg:GetDescendants() do
	if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible and d.Text ~= "" and (string.find(d.Text, "Join") or string.find(d.Text, "Leave") or string.find(d.Text, "oose") or string.find(d.Text, "gg")) then
		local note = ""
		if d.Text == "Leave" or string.find(d.Text, "Leav") then
			local sc = d:FindFirstAncestorOfClass("ScreenGui")
			note = string.format("[abs=%dx%d at %d,%d textBounds=%dx%d screen=%s]", d.AbsoluteSize.X, d.AbsoluteSize.Y, d.AbsolutePosition.X, d.AbsolutePosition.Y,
				d.TextBounds.X, d.TextBounds.Y, tostring(sc and sc.AbsoluteSize))
		end
		table.insert(out, d.Name .. ":" .. d.Text .. note)
	end
end
return table.concat(out, " | ")
"""
GSQ = r"""
local out = {}
local m = workspace:FindFirstChild("GooseSquare")
if not m then return "GooseSquare: none" end
table.insert(out, "BuiltBy=" .. tostring(m:GetAttribute("BuiltBy")) .. " StandInFloor=" .. tostring(m:GetAttribute("StandInFloor")))
local n = 0
for _, d in m:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
		if n <= 60 then table.insert(out, string.format("%s pos=%s size=%s transp=%s collide=%s", d.Name, tostring(d.Position), tostring(d.Size), tostring(d.Transparency), tostring(d.CanCollide))) end
	end
end
table.insert(out, "parts=" .. n)
local kids = {}
for _, d in m:GetChildren() do table.insert(kids, d.Name .. "(" .. d.ClassName .. ")") end
table.insert(out, "children: " .. table.concat(kids, ", "))
return table.concat(out, "\n")
"""
CAMP = r"""
local cam = workspace.CurrentCamera
local lp = game.Players.LocalPlayer
local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
local L = game.Lighting
local out = {}
table.insert(out, "cam " .. tostring(cam.CameraType) .. " subject=" .. tostring(cam.CameraSubject and cam.CameraSubject:GetFullName()) .. " camPos=" .. tostring(cam.CFrame.Position) .. " focus=" .. tostring(cam.Focus.Position) .. " hrp=" .. tostring(hrp and hrp.Position))
table.insert(out, "fog start=" .. L.FogStart .. " end=" .. L.FogEnd .. " color=" .. tostring(L.FogColor) .. " brightness=" .. L.Brightness .. " exposure=" .. L.ExposureCompensation .. " clock=" .. L.ClockTime)
for _, e in L:GetChildren() do table.insert(out, "L " .. e.ClassName .. " " .. e.Name .. " " .. tostring(e:IsA("PostEffect") and e.Enabled)) end
for _, g in lp.PlayerGui:GetChildren() do
	if g:IsA("ScreenGui") and g.Enabled then
		for _, f in g:GetChildren() do
			if f:IsA("GuiObject") and f.Visible and f.AbsoluteSize.X > 1500 and f.BackgroundTransparency < 0.9 then
				table.insert(out, "full " .. g.Name .. " " .. f.Name .. " " .. f.BackgroundTransparency .. " " .. tostring(f.BackgroundColor3))
			end
		end
	end
end
return table.concat(out, "\n")
"""
ATTR = r"""
local p = game:GetService("Players").LocalPlayer
return "InGooseSquare=" .. tostring(p:GetAttribute("InGooseSquare")) .. " GooseJoinBlock=" .. tostring(p:GetAttribute("GooseJoinBlock"))
"""


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    c = Client()
    c.start()
    try:
        st = text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in st:
            sys.exit("not in Edit: " + st)
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
        note("EDIT state GooseSquare:\n" + lua(c, GSQ, "Edit"))
        c.call("start_stop_play", {"is_start": True})
        note("loaded: " + wait_state(c, lambda x: "DataLoaded=true" in x, 90, 2.0))
        time.sleep(26)
        note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        wait_state(c, lambda x: "Faction=Halo" in x, 20)
        note(lua(c, FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
        note("chosen: " + wait_state(c, lambda x: "ClassChosen=true" in x, 20))
        note(lua(c, FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
        note("level: " + lua(c, DEBUG % '{ "Level", 10 }', "Server"))
        note("tutorial done: " + lua(c, TUTOR % '"done"', "Server"))
        time.sleep(3)
        note("fold: " + lua(c, FOLD, "Client"))
        save(c, "00_before_event")
        note("goose: " + lua(c, DEBUG % '{ "Goose", true }', "Server"))
        time.sleep(4)
        save(c, "01_chip_join_button")
        note("words: " + lua(c, HUDWORDS, "Client"))
        note("fold: " + lua(c, FOLD, "Client"))
        note("join: " + lua(c, FIRE % ("GooseSquare", '"Join"', "GooseSquare Join"), "Client"))
        time.sleep(4)
        note("inside attr: " + lua(c, ATTR, "Client"))
        note("PLAY GooseSquare after Join:\n" + lua(c, GSQ, "Server"))
        note("CLIENT cam probe after Join:\n" + lua(c, CAMP, "Client"))
        save(c, "02_inside_square")
        time.sleep(3)
        save(c, "03_inside_square_leave_visible")
        note("words inside: " + lua(c, HUDWORDS, "Client"))
        note("leave: " + lua(c, FIRE % ("GooseSquare", '"Leave"', "GooseSquare Leave"), "Client"))
        time.sleep(4)
        note("inside attr after leave: " + lua(c, ATTR, "Client"))
        time.sleep(2)
        note("CLIENT cam probe 3 s after Leave:\n" + lua(c, CAMP, "Client"))
        save(c, "04_after_leave")
        # a rookie still in the tutorial (A23-68): no Join outside, but Leave + the egg bar inside
        note("rookie: " + lua(c, TUTOR % "0", "Server"))
        time.sleep(3)
        note("fold: " + lua(c, FOLD, "Client"))
        save(c, "05_rookie_outside_no_join")
        note("rookie join: " + lua(c, FIRE % ("GooseSquare", '"Join"', "GooseSquare Join"), "Client"))
        time.sleep(4)
        note("rookie inside attr: " + lua(c, ATTR, "Client"))
        note("fold: " + lua(c, FOLD, "Client"))
        save(c, "06_rookie_inside_leave")
        note("words rookie inside: " + lua(c, HUDWORDS, "Client"))
        note("rookie leave: " + lua(c, FIRE % ("GooseSquare", '"Leave"', "GooseSquare Leave"), "Client"))
        time.sleep(4)
        save(c, "07_rookie_after_leave")
        con = text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "infinite yield")) and "TexturePack" not in ln]
        note("goose warnings: " + "\n".join(ln for ln in text_of(c.call("get_console_output", {})).splitlines() if "GooseSquare" in ln or "GooseService" in ln)[-3000:])
        note("console: " + "\n".join(errs[-20:]))
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
            note("play stopped")
        except Exception as e:  # noqa: BLE001
            note("stop failed " + str(e))
        time.sleep(2)
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh kept on"', "Edit"))
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
