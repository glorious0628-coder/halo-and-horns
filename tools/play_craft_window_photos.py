"""③-3 craft window photos (게임성 개발 4): own test Play in the practice Studio with a FRESH in-memory save (ServerStorage
StudioFreshSave, Studio only; nothing is saved). Faction / class through the remotes (Halo Warrior: the artisan guild is
off in Config), then the server sets the player's Faction attribute to Neutral (a blacksmith for the window; the save
stays Halo), the server's Studio DebugCommand gives materials and gold, the server fires CraftInfo (craft Lv 1, then
Lv 5 with made counts) and OpenPanel("Craft", { Select = recipe }) picks each recipe (no mouse, no keyboard). Probes
(window size, rows, words, anything cut off) + photos at each step; an alchemist (no recipes yet) and a Halo player
(not an artisan); the console's errors, then Play stops (finally) and the fresh-save flag is cleared.
Then, only with --click: Studio's own input (user_mouse_input in my test Play, no desktop mouse) presses Forge once
(crafting is off on this server: Checking…, then Forge again after 3 s).
Usage: STUDIO_ID=<UiSandbox id> py tools/play_craft_window_photos.py [outdir-name] [--click]
       (own test Play only: 최종 검수 approves first)
Out: docs/art/verification_2026-10-12/craft_window/<outdir-name or pc>/"""
import base64
import io
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
CLICK = "--click" in sys.argv
OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-12", "craft_window", ARGS[0] if ARGS else "pc")
LOG = []


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def lua(c, code, dm):
    try:
        return text_of(c.call("execute_luau", {"code": code, "datamodel_type": dm}))
    except Exception as e:  # noqa: BLE001
        return "ERR " + str(e)[:200]


def note(msg):
    print(msg, flush=True)
    LOG.append(msg)


def save(c, name):
    res = c.call("screen_capture", {"capture_id": name})
    for part in res.get("content", []):
        if part.get("type") == "image":
            from PIL import Image
            os.makedirs(OUT, exist_ok=True)
            path = os.path.join(OUT, name + ".png")
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).save(path)
            note("saved " + path)
            return
    note("capture failed " + name)


STATE = r"""
local p = game:GetService("Players"):GetPlayers()[1]
if not p then return "no player" end
local out = {}
for _, k in { "DataLoaded", "Faction", "Class", "ClassChosen", "Level", "BankGold", "CarriedGold" } do
	table.insert(out, k .. "=" .. tostring(p:GetAttribute(k)))
end
return table.concat(out, " ")
"""

FIRE = r"""
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
R:WaitForChild("%s"):FireServer(%s)
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

# server: the player's attributes for the window (Faction / Class; the save is not touched)
ATTRS = r"""
local p = game:GetService("Players"):GetPlayers()[1]
p:SetAttribute("Faction", "%s")
p:SetAttribute("Class", "%s")
return "attrs " .. tostring(p:GetAttribute("Faction")) .. " " .. tostring(p:GetAttribute("Class"))
"""

INFO = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local r = R:FindFirstChild("CraftInfo")
if not r then return "no CraftInfo remote" end
r:FireClient(p, %s)
return "CraftInfo sent"
"""

OPEN = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
R:WaitForChild("OpenPanel"):FireClient(p, "Craft", %s)
return "opened the craft window"
"""

# client: the input path of a named window object (for Studio's user_mouse_input in my own test Play)
PATH = r"""
local p = game:GetService("Players").LocalPlayer
for _, d in p:FindFirstChildOfClass("PlayerGui"):GetDescendants() do
	if d.Name == "%s" and d:IsA("GuiButton") and d:FindFirstAncestor("PanelsModal") then
		local full = d:GetFullName()
		local pg = p:FindFirstChildOfClass("PlayerGui"):GetFullName()
		return "LocalPlayer.PlayerGui" .. string.sub(full, #pg + 1)
	end
end
return "none"
"""

# client: the open window, its size, rows, words, anything cut off
PROBE = r"""
local HttpService = game:GetService("HttpService")
local p = game:GetService("Players").LocalPlayer
local pg = p:FindFirstChildOfClass("PlayerGui")
local out = { Rows = {}, Words = {}, Cut = {} }
local modal = nil
for _, d in pg:GetDescendants() do
	if d.Name == "PanelsModal" and d:IsA("Frame") then modal = d end
end
if not modal or not modal.Visible then return "no open window" end
local win = modal:FindFirstChild("Window")
out.Window = win and string.format("%.0fx%.0f px at %.0f,%.0f", win.AbsoluteSize.X, win.AbsoluteSize.Y, win.AbsolutePosition.X, win.AbsolutePosition.Y)
local cam = workspace.CurrentCamera
out.Viewport = string.format("%.0fx%.0f", cam.ViewportSize.X, cam.ViewportSize.Y)
local body = win and win:FindFirstChild("FixedBody")
for _, d in (body and body:GetDescendants() or {}) do
	if string.sub(d.Name, 1, 4) == "Row_" then table.insert(out.Rows, string.sub(d.Name, 5)) end
	if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and d.Visible then
		table.insert(out.Words, d.Name .. ":" .. d.Text)
		if d:IsA("TextLabel") and not d.TextFits then table.insert(out.Cut, d.Name .. ":" .. d.Text) end
	end
end
return HttpService:JSONEncode(out)
"""


def wait_state(c, cond, timeout, every=1.0):
    t0 = time.time()
    last = ""
    while time.time() - t0 < timeout:
        last = lua(c, STATE, "Server")
        if cond(last):
            return last
        time.sleep(every)
    return last


def shot(c, name, open_arg=None):
    if open_arg is not None:
        note(open_arg + " -> " + lua(c, OPEN % open_arg, "Server"))
    time.sleep(1.5)
    note(f"probe {name}: " + lua(c, PROBE, "Client"))
    save(c, name)


def click(c, name):
    path = lua(c, PATH % name, "Client")
    note(name + " path: " + path)
    if not path.startswith("LocalPlayer."):
        return False
    c.call("user_mouse_input", {"datamodel_type": "Client", "actions": [
        {"action": "moveTo", "instance_path": path}, {"action": "mouseButtonClick", "mouse_button": "left"}]})
    return True


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    c = Client()
    c.start()
    try:
        st = text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in st:
            sys.exit("not in Edit: " + st)
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
        c.call("start_stop_play", {"is_start": True})
        note("loaded: " + wait_state(c, lambda x: "DataLoaded=true" in x, 90, 2.0))
        time.sleep(26)  # the first-time opening plays (15-25 s)
        note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        wait_state(c, lambda x: "Faction=Halo" in x, 20)
        note(lua(c, FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
        note("chosen: " + wait_state(c, lambda x: "ClassChosen=true" in x, 20))
        time.sleep(3)
        gives = ['{ "Level", 10 }', '{ "Gold", 1234 }'] + [f'{{ "Item", "{x}" }}' for x in
                 ("Jelly:24", "Petal:2", "CopperOre:6", "SlimeCore:3", "Bone:5", "IronOre:3")]
        note("debug: " + lua(c, DEBUG % ", ".join(gives), "Server"))
        note(lua(c, ATTRS % ("Neutral", "Warrior"), "Server"))
        note(lua(c, INFO % '{ Role = "Smith", Lv = 1, XP = 10, Need = 40, Made = {} }', "Server"))
        time.sleep(1)
        note("state: " + lua(c, STATE, "Server"))
        shot(c, "01_smith_lv1_w1", "nil")
        shot(c, "02_w2_short_petal", '{ Select = "W2" }')
        shot(c, "03_w3_locked", '{ Select = "W3" }')
        note(lua(c, INFO % '{ Role = "Smith", Lv = 5, XP = 120, Need = 447, Made = { W1 = 2, W2 = 1 } }', "Server"))
        shot(c, "04_lv5_w3_open", '{ Select = "W3" }')
        shot(c, "05_w5_many_mats", '{ Select = "W5" }')
        shot(c, "06_w1_made", '{ Select = "W1" }')
        if CLICK and click(c, "Forge"):
            time.sleep(0.6)
            note("probe 07: " + lua(c, PROBE, "Client"))
            save(c, "07_forge_checking")
            time.sleep(3.5)
            note("probe 08: " + lua(c, PROBE, "Client"))
            save(c, "08_forge_back")
        note(lua(c, ATTRS % ("Neutral", "Mage"), "Server"))
        note(lua(c, INFO % '{ Role = "Alch", Lv = 1, XP = 0, Need = 40, Made = {} }', "Server"))
        shot(c, "09_alchemist_none", "nil")
        note(lua(c, ATTRS % ("Halo", "Warrior"), "Server"))
        shot(c, "10_halo_not_artisan", "nil")
        con = text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "warn", "infinite yield"))]
        note("console: " + "\n".join(errs[-30:]))
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
            note("play stopped")
        except Exception as e:  # noqa: BLE001
            note("stop failed " + str(e))
        time.sleep(2)
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", nil) return "fresh off"', "Edit"))
        os.makedirs(OUT, exist_ok=True)
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
