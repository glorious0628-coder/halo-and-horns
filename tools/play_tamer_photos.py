"""조련사 화면 photos (게임성 개발 4): own test Play in the practice Studio with a FRESH in-memory save (ServerStorage
StudioFreshSave, Studio only; nothing is saved). The Studio must hold a PHOTO-ONLY sync: this branch + 개발 3's
origin/dev3-tamer merged, with Config.Features NeutralFaction / Crafting / Research switched on in that throwaway tree
(never committed). Faction Neutral + class Archer (the pet tamer) through the remotes, the server's Studio DebugCommand
gives materials, Pet Treats and gold; the server fires TamerInfo (research points), a PetList with a summoned pet (Roll)
and a pet at the top level, and a CraftSession + CraftResult.Pet (the summon's line). OpenPanel("Craft" | "Pet") opens
the windows; Studio's own input (user_mouse_input in my test Play, no desktop mouse) presses the Research tab once.
Probes + photos at each step, the console's errors, then Play stops (finally) and the fresh-save flag is cleared.
Usage: STUDIO_ID=<UiSandbox id> py tools/play_tamer_photos.py [outdir-name]   (own test Play only: 최종 검수 approves first)
Out: docs/art/verification_2026-10-12/tamer/<outdir-name or pc>/"""
import base64
import io
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-12", "tamer", sys.argv[1] if len(sys.argv) > 1 else "pc")
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
for _, k in { "DataLoaded", "Faction", "Class", "ClassChosen", "EquippedPet", "PetLv", "PetRoll" } do
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

# server -> my client: a remote with a payload (TamerInfo / PetList / CraftSession / CraftResult / OpenPanel)
SEND = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local r = R:FindFirstChild("%s")
if not r then return "no remote %s" end
r:FireClient(p, %s)
return "sent %s"
"""

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

PROBE = r"""
local HttpService = game:GetService("HttpService")
local p = game:GetService("Players").LocalPlayer
local pg = p:FindFirstChildOfClass("PlayerGui")
local out = { Words = {}, Cut = {} }
local modal = nil
for _, d in pg:GetDescendants() do
	if d.Name == "PanelsModal" and d:IsA("Frame") then modal = d end
end
if not modal or not modal.Visible then
	local ring = pg:FindFirstChild("CraftRing", true)
	if ring then
		for _, d in ring:GetDescendants() do
			if d:IsA("TextLabel") and d.Text ~= "" then table.insert(out.Words, d.Name .. ":" .. d.Text) end
		end
		return "ring " .. HttpService:JSONEncode(out)
	end
	return "no open window"
end
local win = modal:FindFirstChild("Window")
out.Window = win and string.format("%.0fx%.0f px", win.AbsoluteSize.X, win.AbsoluteSize.Y)
for _, d in win:GetDescendants() do
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


def send(c, remote, payload):
    note(lua(c, SEND % (remote, remote, payload, remote), "Server"))


def shot(c, name, wait=1.5):
    time.sleep(wait)
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


STAGES = "Stages = { 50, 150, 400, 1000, 2500 }"


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
        note(lua(c, FIRE % ("ChooseFaction", '"Neutral"', "ChooseFaction"), "Client"))
        wait_state(c, lambda x: "Faction=Neutral" in x, 20)
        note(lua(c, FIRE % ("ChooseClass", '"Archer", "M"', "ChooseClass"), "Client"))
        note("chosen: " + wait_state(c, lambda x: "ClassChosen=true" in x, 20))
        time.sleep(3)
        gives = ['{ "Gold", 1234 }'] + [f'{{ "Item", "{x}" }}' for x in ("Jelly:40", "SlimeCore:6", "Petal:4", "PetTreat:3")]
        note("debug: " + lua(c, DEBUG % ", ".join(gives), "Server"))
        note("state: " + lua(c, STATE, "Server"))
        send(c, "TamerInfo", "{ Pts = { Slime = 120, Goblin = 40 }, Sum = {}, " + STAGES + " }")
        send(c, "OpenPanel", '"Craft"')
        shot(c, "01_tamer_make_tab")
        send(c, "OpenPanel", '"Craft", { Select = "S1" }')
        shot(c, "02_summon_research_short")
        send(c, "TamerInfo", "{ Pts = { Slime = 160, Goblin = 40 }, Sum = { Slime = 1 }, " + STAGES + " }")
        shot(c, "03_summon_research_ok")
        if click(c, "Tab_Research"):
            shot(c, "04_research_tab", 1.0)
        send(c, "PetList", '{ Equipped = "P1", List = { { Uid = "P1", Sp = "BabySlime", Lv = 3, XP = 10, Need = 45, Name = "", Lean = "",'
             ' Roll = { Spd = 8 } }, { Uid = "P2", Sp = "BabySlime", Lv = 10, XP = 0, Need = 0, Name = "Good Buddy", Lean = "Good" } } }')
        send(c, "OpenPanel", '"Pet"')
        shot(c, "05_pet_roll_feed")
        send(c, "CraftSession", '{ Id = 900, Recipe = "S1", Strikes = 5, Ring = 1.2, Rest = 0.35, StartAt = workspace:GetServerTimeNow() + 0.8 }')
        time.sleep(1.2)
        send(c, "CraftResult", '{ Id = 900, Recipe = "S1", Kind = "Pet", Plus = 2, Grades = {}, XP = 40, Lv = 1, LvUp = false,'
             ' Pet = { Uid = "P3", Species = "BabySlime", Spd = 9 } }')
        shot(c, "06_summon_result", 0.4)
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
