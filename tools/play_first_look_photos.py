"""First-look fixes photos (fix/first-look-1, 게임성 개발 1, 2026-10-14) in the MAIN Studio (메인 반영 1 only,
HH_MAIN_STUDIO=1; own test Play with a FRESH in-memory save; no mouse / keyboard input - the [Menu] fold opens through
Keybinds.Dispatch; a phone run puts the device emulation back to default at the end, even after an error).
Halo Warrior, the tutorial's first claim done, then:
  01_town        in town, the [Menu] fold shut (only [Menu] rings while Gifts waits)
  02_fold_open   the fold open (PC: one line; the squares a little smaller when the row's overflow tile joins them; only
                 the Gifts square rings)
  03_out_of_town moved to the Slime Meadow (no status chips): the goose / king pill right under the war meter
10/14 (fix/menu-one-line, user: the PC fold was two lines and 'Monsters' read "Monster:"): the log also lists the
open fold's lines (y of each line: squares) and the row tiles, and every shown tile / square whose name does not fit
(TextFits false) - PC wants one fold line, Monsters in the bottom row, no cut names. 10/14 (2): only the MenuFold
squares count as fold lines (the empty "y2" line was another button); each name's px and room left are logged.
Usage: HH_MAIN_STUDIO=1 py tools/play_first_look_photos.py [phone]
Out: docs/art/verification_2026-10-14/menu_one_line/<dev>_<name>.png, log_<dev>.txt (the 10/14 first_look photos stay)"""
import base64
import io
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-14", "menu_one_line")
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
    time.sleep(1.0)
    res = c.call("screen_capture", {"capture_id": name})
    for part in res.get("content", []):
        if part.get("type") == "image":
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB").save(os.path.join(OUT, name + ".png"))
            note("saved " + name)
            return
    note("capture failed " + name)


SET_PHONE = r'''
local svc = game:GetService("StudioDeviceSimulatorService")
svc:SetDeviceAsync("samsung_galaxy_s22_ultra")
task.wait(0.3)
svc:SetResolutionAsync(749, 361)
task.wait(0.3)
svc:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.ActualResolution)
return svc:GetDeviceAsync()
'''
RESTORE = r'''
local svc = game:GetService("StudioDeviceSimulatorService")
if svc:GetDeviceAsync() ~= "default" then
	pcall(function() svc:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.FitToWindow) end)
	svc:StopSimulationAsync()
end
return svc:GetDeviceAsync()
'''
STATE = r'''
local p = game:GetService("Players"):GetPlayers()[1]
if not p then return "no player" end
local out = {}
for _, k in { "DataLoaded", "Faction", "ClassChosen", "TutorialStep", "AttendReady" } do table.insert(out, k .. "=" .. tostring(p:GetAttribute(k))) end
return table.concat(out, " ")
'''
FIRE = r'''
game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("%s"):FireServer(%s)
return "fired %s"
'''
CLAIMED = r'''
local p = game:GetService("Players"):GetPlayers()[1]
p:SetAttribute("TutorialStep", 99)
return "TutorialStep " .. tostring(p:GetAttribute("TutorialStep"))
'''
DISPATCH = r'''
local ps = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")
local kb = ps:FindFirstChild("Keybinds")
local d = kb and kb:FindFirstChild("Dispatch")
if not d then return "no dispatch" end
return tostring(d:Invoke({ KeyCode = Enum.KeyCode.%s }))
'''
MEADOW = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local z = Config.Zones and Config.Zones.SlimeMeadow
local c = z and (z.Center or z.Spawn)
if not (p and p.Character and typeof(c) == "Vector3") then return "no meadow centre" end
p.Character:PivotTo(CFrame.new(c + Vector3.new(0, 8, 0)))
return "moved to " .. tostring(c)
'''
CHIPS = r'''
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local out = {}
for _, d in pg:GetDescendants() do
	if (d.Name == "StatusChips" or d.Name == "GooseChip" or d.Name == "KingChip" or d.Name == "WarMeter") and d:IsA("GuiObject") then
		table.insert(out, d.Name .. (d.Visible and " y=" .. math.floor(d.AbsolutePosition.Y) .. " h=" .. math.floor(d.AbsoluteSize.Y) or " hidden"))
	end
end
return table.concat(out, " | ")
'''
FOLDINFO = r'''
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local lines, row, cut, px = {}, {}, {}, {}
for _, d in pg:GetDescendants() do
	local inFold = d.Parent and d.Parent.Name == "MenuFold" and string.match(d.Name, "^Fold") ~= nil
	local inRow = d.Parent and d.Parent.Name == "Buttons" and string.match(d.Name, "^Tile") ~= nil
	if d:IsA("GuiButton") and d.Visible and (inFold or inRow) then
		local shown, a = true, d
		while a and a:IsA("GuiObject") do
			if not a.Visible then shown = false break end
			a = a.Parent
		end
		local id = string.gsub(string.gsub(d.Name, "^Fold", ""), "^Tile", "")
		if shown and id ~= "" then
			if inFold then
				local y = tostring(math.floor(d.AbsolutePosition.Y + 0.5))
				lines[y] = (lines[y] or "") .. id .. " "
			elseif id ~= "Menu" then
				table.insert(row, id)
			end
			local lbl = d:FindFirstChild("Label")
			if lbl and lbl:IsA("TextLabel") and lbl.Visible then
				if lbl.TextFits == false then table.insert(cut, id .. "(" .. lbl.Text .. ")") end
				-- the name's rendered height (px) and its room left inside the label (px, both sides)
				table.insert(px, string.format("%s %.1fpx room %.1f", lbl.Text, lbl.TextBounds.Y / 1.25,
					lbl.AbsoluteSize.X - lbl.TextBounds.X))
			end
		end
	end
end
local out, n = {}, 0
for y, ids in lines do n += 1 table.insert(out, "y" .. y .. ": " .. ids) end
return "fold lines " .. n .. " | " .. table.concat(out, " | ") .. " || row: " .. table.concat(row, ",")
	.. " || cut names: " .. (#cut > 0 and table.concat(cut, ", ") or "none") .. " || names: " .. table.concat(px, "; ")
'''


def wait_state(c, cond, timeout, every=1.0):
    t0, last = time.time(), ""
    while time.time() - t0 < timeout:
        last = lua(c, STATE, "Server")
        if cond(last):
            return last
        time.sleep(every)
    return last


def run(c, dev):
    if dev == "phone":
        note("device: " + lua(c, SET_PHONE, "Edit"))
    note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
    c.call("start_stop_play", {"is_start": True})
    note("loaded: " + wait_state(c, lambda x: "DataLoaded=true" in x, 90, 2.0))
    time.sleep(15)
    note(lua(c, FIRE % ("IntroSeen", "", "IntroSeen"), "Client"))
    note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
    wait_state(c, lambda x: "Faction=Halo" in x, 20)
    note(lua(c, FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
    note("chosen: " + wait_state(c, lambda x: "ClassChosen=true" in x, 20))
    note(lua(c, FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
    time.sleep(2)
    note(lua(c, CLAIMED, "Server"))
    time.sleep(4)
    note("state: " + lua(c, STATE, "Server"))
    save(c, f"{dev}_01_town")
    note("B: " + lua(c, DISPATCH % "B", "Client"))
    time.sleep(1.0)
    note("fold: " + lua(c, FOLDINFO, "Client"))
    save(c, f"{dev}_02_fold_open")
    note("B: " + lua(c, DISPATCH % "B", "Client"))
    note(lua(c, MEADOW, "Server"))
    time.sleep(4)
    note("chips: " + lua(c, CHIPS, "Client"))
    save(c, f"{dev}_03_out_of_town")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(OUT, exist_ok=True)
    dev = "phone" if "phone" in sys.argv[1:] else "pc"
    c = Client()
    c.start()
    try:
        st = text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in st:
            sys.exit("not in Edit: " + st)
        try:
            run(c, dev)
        finally:
            try:
                c.call("start_stop_play", {"is_start": False})
                note("play stopped")
            except Exception as e:  # noqa: BLE001
                note("stop failed " + str(e))
    finally:
        if dev == "phone":
            time.sleep(3)
            note("device: " + lua(c, RESTORE, "Edit"))
        with open(os.path.join(OUT, f"log_{dev}.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
