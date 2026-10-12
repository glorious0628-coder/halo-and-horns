"""내 캐릭터 창 photos (메인 반영 1, 2026-10-12): own test Play in the MAIN Studio (HH_MAIN_STUDIO=1) with a FRESH in-memory save.
Lv1: HUD, a click on the Hero tile (locked: wiggle), Settings window; Lv30 tier 3: HUD, E key, Character [Gear] / [Stats] /
weapon list with [Equip] before + after, closed + reopened, Bag, Journal. Studio's own user_mouse_input only (no desktop mouse).
fix/hero-ui (최종 검수 10/13, ref_rpg_ui #1 #2 #5 #9 #7 #3): the Hero / Bag tile dot (a stronger owned weapon), the title
ribbon + next rank bar + 3D body under the gear cells, the Attack chip pressed (its sources), the body dragged (turned), the
Stats tab cards / chips, the locked titles grey, the weapon list's "Power +N" lines.
Usage: HH_MAIN_STUDIO=1 py tools/play_character_ui_photos.py [outdir-name]   Out: docs/art/verification_2026-10-12/main_apply/<outdir>/"""
import base64
import io
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-12", "main_apply", sys.argv[1] if len(sys.argv) > 1 else "charui")
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


DOTS = r"""
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local out = {}
for _, d in pg:GetDescendants() do
	if d.Name == "BetterDot" then table.insert(out, d.Parent.Name .. "=" .. tostring(d.Visible)) end
end
return "dots " .. table.concat(out, ",")
"""
BODY = r"""
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local inset = game:GetService("GuiService"):GetGuiInset()
for _, d in pg:GetDescendants() do
	if d.Name == "Body3D" and d:IsA("ViewportFrame") then
		local wm = d:FindFirstChildOfClass("WorldModel")
		local copy = wm and wm:FindFirstChild("PreviewCharacter")
		local parts, weapon, mark = 0, copy and copy:FindFirstChild("WeaponModel") ~= nil, copy and copy:FindFirstChild("FactionMark") ~= nil
		if copy then for _, x in copy:GetDescendants() do if x:IsA("BasePart") then parts += 1 end end end
		local c = d.AbsolutePosition + d.AbsoluteSize / 2
		return string.format("%d %d yaw=%s copy=%s parts=%d weapon=%s mark=%s size=%dx%d", math.floor(c.X), math.floor(c.Y + inset.Y),
			tostring(d:GetAttribute("Yaw")), tostring(copy ~= nil), parts, tostring(weapon), tostring(mark), d.AbsoluteSize.X, d.AbsoluteSize.Y)
	end
end
return "none"
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
        time.sleep(26)
        note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        wait_state(c, lambda x: "Faction=Halo" in x, 20)
        note(lua(c, FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
        note("chosen: " + wait_state(c, lambda x: "ClassChosen=true" in x, 20))
        note(lua(c, FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
        time.sleep(4)
        # 1. Lv1
        save(c, "01_lv1_hud")
        if click(c, "TileCharacter", wait=0.25):
            save(c, "02_lv1_hero_tile_click_wiggle")
        time.sleep(1)
        note("words after the Lv1 click: " + lua(c, WORDS, "Client"))
        note(lua(c, OPEN % ("Settings", "nil", "Settings"), "Server"))
        time.sleep(1.5)
        save(c, "03_lv1_settings")
        note("settings words: " + lua(c, WORDS, "Client"))
        note(lua(c, CLOSE, "Client"))
        # 2. Lv30 tier 3
        note("gear: " + lua(c, DEBUG % '{ "Level", 30 }, { "WeaponOwnedMask", 127 }', "Server"))
        time.sleep(1)
        note(lua(c, FIRE % ("EquipWeapon", "1", "EquipWeapon"), "Client"))
        time.sleep(2)
        time.sleep(5)  # the HUD's tile dot refreshes with the menu glow
        note(lua(c, DOTS, "Client"))
        save(c, "04_lv30_hud")
        note("E key: " + lua(c, DISPATCH % "E", "Client"))
        time.sleep(1.5)
        if "Hero" not in lua(c, WORDS, "Client"):
            note("E did not open; OpenPanel Character instead")
            note(lua(c, OPEN % ("Character", "nil", "Character"), "Server"))
            time.sleep(1.5)
        time.sleep(1.5)  # the 3D body copies me after a short wait
        save(c, "05_character_gear")
        note("gear words: " + lua(c, WORDS, "Client"))
        body = lua(c, BODY, "Client")
        note("body: " + body)
        # ref_rpg_ui #3: drag the body 160 px to the right (left button), it turns
        xy = body.split(" ")[:2]
        if len(xy) == 2 and xy[0].lstrip("-").isdigit():
            x, y = int(xy[0]), int(xy[1])
            r = c.call("user_mouse_input", {"datamodel_type": "Client", "actions": [
                {"action": "moveTo", "x": x, "y": y}, {"action": "mouseButtonDown", "mouse_button": "left"},
                {"action": "moveTo", "x": x + 80, "y": y}, {"action": "moveTo", "x": x + 160, "y": y},
                {"action": "mouseButtonUp", "mouse_button": "left"}]})
            note("drag: " + text_of(r)[:150])
            time.sleep(1)
            note("body after drag: " + lua(c, BODY, "Client"))
            save(c, "05b_body_turned")
        # ref_rpg_ui #1: the Attack chip shows where the number comes from
        if click(c, "Part_Attack", "PanelsModal"):
            save(c, "05c_power_why")
            note("why words: " + lua(c, WORDS, "Client"))
            click(c, "Part_Attack", "PanelsModal")
        note(lua(c, OPEN % ("Character", '{ Tab = "Stats" }', "Character Stats"), "Server"))
        time.sleep(1.5)
        save(c, "06_character_stats")
        note("stats words: " + lua(c, WORDS, "Client"))
        note(lua(c, OPEN % ("Character", '{ Tab = "Gear" }', "Character Gear"), "Server"))
        time.sleep(1.5)
        note("buttons: " + lua(c, BUTTONS % "PanelsModal", "Client"))
        click(c, "Cell_Weapon")
        save(c, "07_weapons_before_equip")
        note("weapon words: " + lua(c, WORDS, "Client"))
        note("buttons: " + lua(c, BUTTONS % "PanelsModal", "Client"))
        note("buttons now: " + lua(c, BUTTONS % "PanelsModal", "Client"))
        click(c, "Equip_3")
        time.sleep(1.5)
        note("after equip: " + lua(c, STATE, "Server"))
        save(c, "08_weapons_after_equip")
        note(lua(c, CLOSE, "Client"))
        time.sleep(0.8)
        save(c, "09_closed")
        note("E again: " + lua(c, DISPATCH % "E", "Client"))
        time.sleep(1.5)
        save(c, "10_reopened")
        note(lua(c, OPEN % ("Bag", '{ Tab = "Gear" }', "Bag"), "Server"))
        time.sleep(1.5)
        save(c, "11_bag")
        note(lua(c, OPEN % ("Journal", "nil", "Journal"), "Server"))
        time.sleep(1.5)
        save(c, "12_journal")
        con = text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "infinite yield")) and "TexturePack" not in ln]
        note("console: " + "\n".join(errs[-20:]))
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
            note("play stopped")
        except Exception as e:  # noqa: BLE001
            note("stop failed " + str(e))
        time.sleep(2)
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", nil) return "fresh off"', "Edit"))
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
