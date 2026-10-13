"""Monster Codex screen photos (SPEC A23-153, 게임성 개발 1 2026-10-13; CodexUI.luau): own test Play with a FRESH in-memory save,
in the practice Studio (default STUDIO_NAME=UiSandbox, after its src is synced) or the main Studio (HH_MAIN_STUDIO=1, 메인
반영 1 only). Halo Warrior, the tutorial claimed; the server's DebugCommand "Codex" gives the cards (Slime 12 = Card,
Slime Prince 150 = Silver, King Slime 31 = Gold Holo, Goblin 5 = Card). Until the server sends its own monster copies
(ReplicatedStorage.CodexModels) the script copies ServerStorage.CustomModels there for the photos (a test stand-in; the
log says which). Shots: 01 the window (page 1, Slime big), 02 the card tilted (Studio's own mouse on the card's right
edge), 03 [Auto tilt], 04 the back (a click on the card), 05 King Slime (Gold Holo), 06 page 2 (silhouettes), then the
moments with the window closed (DebugCommand "show:<kind>:<Event>"): 07/08 a new card (Goblin: silhouette -> card), 09/10
Silver -> Gold Holo (Slime), 11 a page done (the reward popup). Studio's own user_mouse_input only (no desktop mouse).
Usage: py tools/play_codex_photos.py [outdir-name]   (HH_MAIN_STUDIO=1 for the main Studio)
Out: docs/art/verification_2026-10-13/codex/<outdir>/ (default sandbox / main): NN_<name>.png, log.txt"""
import base64
import io
import os
import sys
import time

if os.environ.get("HH_MAIN_STUDIO") != "1":
    os.environ.setdefault("STUDIO_NAME", "UiSandbox")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402
from PIL import Image  # noqa: E402

TAG = sys.argv[1] if len(sys.argv) > 1 else ("main" if os.environ.get("HH_MAIN_STUDIO") == "1" else "sandbox")
OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-13", "codex", TAG)
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
for _, k in { "DataLoaded", "Faction", "Class", "ClassChosen", "Level", "CodexCards" } do table.insert(out, k .. "=" .. tostring(p:GetAttribute(k))) end
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
# the photos' stand-in for the server's monster copies (only when the server sent none)
MODELS = r"""
local RS, SS = game:GetService("ReplicatedStorage"), game:GetService("ServerStorage")
if RS:FindFirstChild("CodexModels") then return "CodexModels: the server's" end
local src = SS:FindFirstChild("CustomModels")
if not src then return "no CustomModels" end
local Config = require(RS.Shared.Config)
local folder = Instance.new("Folder")
folder.Name = "CodexModels"
local made = {}
for _, kind in Config.Codex.Order do
	local def = Config.MonsterTypes[kind] or {}
	local t = src:FindFirstChild(kind) or (def.ModelFrom and src:FindFirstChild(def.ModelFrom))
	if t then
		local ok, copy = pcall(function() return t:Clone() end)
		if ok and copy then
			for _, d in copy:GetDescendants() do
				if d:IsA("LuaSourceContainer") then d:Destroy() end
			end
			copy.Name = kind
			copy.Parent = folder
			table.insert(made, kind)
		end
	end
end
folder.Parent = RS
return "CodexModels (test stand-in): " .. table.concat(made, ",")
"""
OPEN = r"""
local p = game:GetService("Players"):GetPlayers()[1]
game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("OpenPanel"):FireClient(p, "Codex", %s)
return "open Codex"
"""
CLOSE = r"""
local p = game:GetService("Players").LocalPlayer
for _, d in p:FindFirstChildOfClass("PlayerGui"):GetDescendants() do
	if d.Name == "PanelsModal" and d:IsA("Frame") then d.Visible = false end
end
return "closed"
"""
PATH = r"""
local p = game:GetService("Players").LocalPlayer
local pg = p:FindFirstChildOfClass("PlayerGui")
local want, within = "%s", "%s"
for _, d in pg:GetDescendants() do
	if d:IsA("GuiObject") and d.Visible and d.Name == want and (within == "" or d:FindFirstAncestor(within)) then
		local full = d:GetFullName()
		return "LocalPlayer.PlayerGui" .. string.sub(full, #pg:GetFullName() + 1)
	end
end
return "none"
"""
# what the window / the moment shows (texts, the 3D views: a model? silhouette?)
LOOK = r"""
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local out = {}
for _, d in pg:GetDescendants() do
	if d:FindFirstAncestor("%s") then
		if d:IsA("TextLabel") and d.Visible and d.Text ~= "" then table.insert(out, d.Name .. ":" .. d.Text) end
		if d:IsA("ViewportFrame") and d.Name == "Monster3D" then
			local wm = d:FindFirstChildOfClass("WorldModel")
			local m = wm and wm:FindFirstChildOfClass("Model")
			table.insert(out, string.format("3D[%%s color=%%.0f size=%%dx%%d]", m and m.Name or "none", d.ImageColor3.R * 255,
				d.AbsoluteSize.X, d.AbsoluteSize.Y))
		end
	end
end
return table.concat(out, " | ")
"""
EDGE = r"""
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
for _, d in pg:GetDescendants() do
	if d.Name == "CodexCard" and d:FindFirstAncestor("Big") then
		local p, s = d.AbsolutePosition, d.AbsoluteSize
		return string.format("%%d,%%d", math.floor(p.X + s.X * %s), math.floor(p.Y + s.Y * %s))
	end
end
return "none"
"""


def wait_state(c, cond, timeout, every=1.0):
    t0, last = time.time(), ""
    while time.time() - t0 < timeout:
        last = lua(c, STATE, "Server")
        if cond(last):
            return last
        time.sleep(every)
    return last


def click(c, name, within="", wait=1.0):
    path = lua(c, PATH % (name, within), "Client")
    note(f"path {name}: {path}")
    if path.startswith("LocalPlayer."):
        r = c.call("user_mouse_input", {"datamodel_type": "Client", "actions": [
            {"action": "moveTo", "instance_path": path}, {"action": "mouseButtonClick", "mouse_button": "left"}]})
        note("mouse: " + text_of(r)[:150])
        time.sleep(wait)
        return True
    return False


def hover(c, fx, fy):
    at = lua(c, EDGE % (fx, fy), "Client")
    note(f"hover {fx},{fy}: {at}")
    if "," in at:
        x, y = (int(v) for v in at.split(","))
        r = c.call("user_mouse_input", {"datamodel_type": "Client", "actions": [{"action": "moveTo", "x": x, "y": y}]})
        note("mouse: " + text_of(r)[:150])
        time.sleep(0.8)


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
        time.sleep(20)
        note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        wait_state(c, lambda x: "Faction=Halo" in x, 20)
        note(lua(c, FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
        note("chosen: " + wait_state(c, lambda x: "ClassChosen=true" in x, 20))
        note(lua(c, FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
        time.sleep(3)
        note(lua(c, MODELS, "Server"))
        note("cards: " + lua(c, DEBUG % '{ "Codex", "Slime:12" }, { "Codex", "BigSlime:150" }, { "Codex", "SlimeKing:31" }, '
                                       '{ "Codex", "Goblin:5" }', "Server"))
        time.sleep(1.5)
        note("state: " + lua(c, STATE, "Server"))
        # the window
        note(lua(c, OPEN % "nil", "Server"))
        time.sleep(2.5)
        note("window: " + lua(c, LOOK % "PanelsModal", "Client"))
        save(c, "01_window_page1")
        hover(c, 0.95, 0.5)
        save(c, "02_card_tilted_right")
        click(c, "AutoTilt", "PanelsModal", wait=1.3)
        save(c, "03_auto_tilt")
        click(c, "AutoTilt", "PanelsModal", wait=0.5)
        click(c, "CodexCard", "Big", wait=0.8)
        note("back: " + lua(c, LOOK % "PanelsModal", "Client"))
        save(c, "04_card_back")
        click(c, "SlotSlimeKing", "PanelsModal", wait=1.0)
        note("king: " + lua(c, LOOK % "PanelsModal", "Client"))
        save(c, "05_king_slime_holo")
        note(lua(c, OPEN % '{ Kind = "Goblin" }', "Server"))
        time.sleep(1.5)
        save(c, "06_page2")
        note(lua(c, CLOSE, "Client"))
        time.sleep(1)
        # the moments
        note(lua(c, DEBUG % '{ "Codex", "show:Goblin:Card" }', "Server"))
        time.sleep(0.25)
        note("moment: " + lua(c, LOOK % "CodexMoment", "Client"))
        save(c, "07_moment_new_card_start")
        time.sleep(1.2)
        save(c, "08_moment_new_card_lit")
        time.sleep(3)
        note(lua(c, DEBUG % '{ "Codex", "show:Slime:Holo" }', "Server"))
        time.sleep(0.35)
        save(c, "09_moment_holo_start")
        time.sleep(0.9)
        note("moment: " + lua(c, LOOK % "CodexMoment", "Client"))
        save(c, "10_moment_holo_after")
        time.sleep(3.5)
        note(lua(c, DEBUG % '{ "Codex", "show:Slime:Page" }', "Server"))
        time.sleep(1.2)
        save(c, "11_page_popup")
        con = text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "infinite yield"))
                and "TexturePack" not in ln]
        note("console: " + "\n".join(errs[-20:]))
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
            note("play stopped")
        except Exception as e:  # noqa: BLE001
            note("stop failed " + str(e))
        time.sleep(2)
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
