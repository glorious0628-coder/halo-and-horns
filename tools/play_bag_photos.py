"""H-1 bag window photos (게임성 개발 4): own test Play in the practice Studio with a FRESH in-memory save (ServerStorage
StudioFreshSave, Studio only; nothing is saved). Faction / class picked through the remotes, then the server's Studio
DebugCommand gives a few weapons / scrolls / materials / potions and gold, the I key (Keybinds Dispatch) opens the bag,
and the server's OpenPanel remote moves it between tabs / a scroll step (no mouse, no keyboard). A Settings echo turns
on the wide bag + the grade sort for the last photos. Probes (window size, cells, words) + photos at each step, the
console's errors, then Play stops (finally) and the fresh-save flag is cleared.
Usage: STUDIO_NAME=UiSandbox py tools/play_bag_photos.py [outdir-name]   (own test Play only: 최종 검수 approves first)
Out: docs/art/verification_2026-10-12/bag_ui/<outdir-name or pc>/"""
import base64
import io
import json
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-12", "bag_ui", sys.argv[1] if len(sys.argv) > 1 else "pc")
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
for _, k in { "DataLoaded", "Faction", "Class", "ClassChosen", "Level", "WeaponTier", "WeaponOwnedMask", "HPPotionCount",
	"MPPotionCount", "BankGold", "CarriedGold" } do
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

DISPATCH = r"""
local ps = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")
local kb = ps:FindFirstChild("Keybinds")
local d = kb and kb:FindFirstChild("Dispatch")
if not d then return "no dispatch" end
return tostring(d:Invoke({ KeyCode = Enum.KeyCode.%s }))
"""

OPEN = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
R:WaitForChild("OpenPanel"):FireClient(p, "Bag", %s)
return "opened the bag"
"""

# the server's settings echo (the client takes an echo with a Seq at least its newest): wide bag + grade sort
WIDE = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local s = Config.SanitizeSettings({ V = Config.Settings.Version, BagWide = %s, BagSort = "%s" })
R:WaitForChild("Settings"):FireClient(p, { Seq = 900000 + math.random(1, 9999), Settings = s })
return "settings BagWide=" .. tostring(s.BagWide) .. " BagSort=" .. s.BagSort
"""

# client: the open window, its size, the bag's cells / words, anything cut off
PROBE = r"""
local HttpService = game:GetService("HttpService")
local p = game:GetService("Players").LocalPlayer
local pg = p:FindFirstChildOfClass("PlayerGui")
local out = { Cells = 0, Empty = 0, Words = {}, Cut = {} }
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
	if string.sub(d.Name, 1, 5) == "Cell_" then out.Cells += 1 end
	if d.Name == "Empty" then out.Empty += 1 end
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
        gives = ['{ "Level", 20 }', '{ "WeaponOwnedMask", 75 }', '{ "HPPotionCount", 5 }', '{ "MPPotionCount", 3 }',
                 '{ "Gold", 1234 }'] + [f'{{ "Item", "{x}" }}' for x in
                 ("Enh70:3", "Enh30:1", "Move70:2", "Jelly:24", "Petal:6", "SlimeCore:3", "Bone:5", "KnightCrest:2",
                  "CaptainBadge:1", "GoblinTooth:9")]
        note("debug: " + lua(c, DEBUG % ", ".join(gives), "Server"))
        note(lua(c, FIRE % ("EquipWeapon", "2", "EquipWeapon"), "Client"))
        note("state: " + wait_state(c, lambda x: "WeaponTier=2" in x, 10, 0.5))
        time.sleep(1)
        note("I key: " + lua(c, DISPATCH % "I", "Client"))
        shot(c, "01_gear_narrow")
        shot(c, "02_gear_pick_t4", '{ Tab = "Gear", Select = "W:4" }')
        shot(c, "03_scrolls", '{ Tab = "Scroll" }')
        shot(c, "04_enhance_confirm", '{ Use = "Enh70", Tier = 2 }')
        shot(c, "05_use_potion", '{ Tab = "Use" }')
        shot(c, "06_materials", '{ Tab = "Material", Select = "I:Jelly" }')
        note(lua(c, WIDE % ("true", "Grade"), "Server"))
        time.sleep(1)
        shot(c, "07_materials_wide_grade", '{ Tab = "Material" }')
        shot(c, "08_gear_wide", '{ Tab = "Gear" }')
        note(lua(c, WIDE % ("false", "Default"), "Server"))
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
