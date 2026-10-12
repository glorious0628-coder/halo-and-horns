"""팔 점검 (메인 반영 1, 2026-10-12): own test Play in the MAIN Studio (HH_MAIN_STUDIO=1), fresh in-memory save, MCP only (no mouse/keyboard).
Per class (Warrior, Mage): the character's values (Faction/Class/Level/WeaponTier, WeaponModel children, RigType, both arms'
Shoulder/Elbow/Wrist Motor6D Transform + C0 angles, WrapLayer count), front + side photos standing / walking, and one front photo
with the weapon taken away (a client-side hide of the weapon model, nothing saved).
Usage: HH_MAIN_STUDIO=1 py tools/play_arm_probe.py [outdir-name]   Out: docs/art/verification_2026-10-12/main_apply/<outdir>/"""
import base64
import io
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-12", "main_apply", sys.argv[1] if len(sys.argv) > 1 else "arm_probe")
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


def save(c, name, cam=None):
    args = {"capture_id": name}
    if cam and "|" in cam:
        a, b = cam.strip().split("|")
        args["camera_position"] = [float(v) for v in a.split(",")]
        args["look_at_position"] = [float(v) for v in b.split(",")]
    res = c.call("screen_capture", args)
    for part in res.get("content", []):
        if part.get("type") == "image":
            im = Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB")
            top = max(0, (im.height - 656) // 2)
            im.crop((0, top, im.width, top + min(656, im.height))).save(os.path.join(OUT, name + ".png"))
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
TELE = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local ch = p.Character
if not ch then return "no char" end
local spots = { Vector3.new(-50, 5, -60), Vector3.new(0, 5, -70), Vector3.new(50, 5, -25), Vector3.new(0, 5, 40) }
local best, bestN = spots[1], 1e9
for _, sp in spots do
	local op = OverlapParams.new()
	op.FilterDescendantsInstances = { ch }
	op.FilterType = Enum.RaycastFilterType.Exclude
	local n = 0
	for _, part in workspace:GetPartBoundsInBox(CFrame.new(sp.X, sp.Y + 2.5, sp.Z), Vector3.new(24, 5, 24), op) do
		if part.Name ~= "Terrain" and part.Transparency < 1 and part.Size.Y > 0.5 then n += 1 end
	end
	if n < bestN then best, bestN = sp, n end
end
ch:PivotTo(CFrame.new(best))
return "spot " .. tostring(best) .. " blockers=" .. bestN
"""
ANCH = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if hrp then hrp.Anchored = %s end
return "anchored %s"
"""
WALK = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
if h then h:Move(Vector3.new(0, 0, -1), true) end
return "walking"
"""
# client: the values (the player's own character in Studio's test Play)
PROBE = r"""
local Players = game:GetService("Players")
local p = Players.LocalPlayer
local ch = p.Character
if not ch then return "no char" end
local out = {}
local function add(s) table.insert(out, s) end
for _, k in { "Faction", "Class", "Level", "WeaponTier", "WeaponId", "Weapon", "EquippedWeapon" } do
	if p:GetAttribute(k) ~= nil then add(k .. "=" .. tostring(p:GetAttribute(k))) end
end
local hum = ch:FindFirstChildOfClass("Humanoid")
add("RigType=" .. tostring(hum and hum.RigType))
add("HipHeight=" .. tostring(hum and hum.HipHeight) .. " Scale: " .. (function()
	local s = {}
	for _, n in { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale", "BodyProportionScale" } do
		local v = hum and hum:FindFirstChild(n)
		if v then table.insert(s, n .. "=" .. string.format("%.2f", v.Value)) end
	end
	return table.concat(s, " ")
end)())
local wm = nil
for _, d in ch:GetChildren() do
	if string.find(d.Name, "Weapon") then wm = d end
end
if wm then
	local names = {}
	for _, d in wm:GetDescendants() do table.insert(names, d.Name .. "(" .. d.ClassName .. ")") end
	add("WeaponModel=" .. wm.Name .. " parent=" .. wm.Parent.Name .. " descendants=" .. #names .. ": " .. table.concat(names, ", ", 1, math.min(#names, 14)))
else
	add("WeaponModel=none; character children: " .. (function()
		local n = {}
		for _, d in ch:GetChildren() do table.insert(n, d.Name) end
		return table.concat(n, ",")
	end)())
end
local function ang(cf)
	local x, y, z = cf:ToEulerAnglesYXZ()
	return string.format("(%.0f,%.0f,%.0f)", math.deg(x), math.deg(y), math.deg(z))
end
for _, d in ch:GetDescendants() do
	if d:IsA("Motor6D") and (string.find(d.Name, "Shoulder") or string.find(d.Name, "Elbow") or string.find(d.Name, "Wrist")) then
		add(string.format("%s in %s: Part0=%s Part1=%s Transform=%s C0=%s C1=%s Part1.size=%s", d.Name, d.Parent.Name,
			tostring(d.Part0 and d.Part0.Name), tostring(d.Part1 and d.Part1.Name), ang(d.Transform), ang(d.C0), ang(d.C1), tostring(d.Part1 and d.Part1.Size)))
	end
end
local nm = 0
for _, d in ch:GetDescendants() do if d:IsA("Motor6D") then nm += 1 end end
add("Motor6D total=" .. nm)
local wl = 0
for _, d in ch:GetDescendants() do
	if d:IsA("WrapLayer") then wl += 1 end
end
add("WrapLayers=" .. wl)
local acc = 0
for _, d in ch:GetChildren() do if d:IsA("Accessory") then acc += 1 end end
add("Accessories=" .. acc)
return table.concat(out, "\n")
"""
CAM = r"""
local ch = game:GetService("Players").LocalPlayer.Character
local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
if not hrp then return "no char" end
local pos, look, right = hrp.Position, hrp.CFrame.LookVector, hrp.CFrame.RightVector
local target = pos + Vector3.new(0, -0.3, 0)
local camPos = (%s) + Vector3.new(0, -0.3, 0)
return string.format("%%f,%%f,%%f|%%f,%%f,%%f", camPos.X, camPos.Y, camPos.Z, target.X, target.Y, target.Z)
"""
HIDEW = r"""
local ch = game:GetService("Players").LocalPlayer.Character
local n = 0
for _, d in ch:GetChildren() do
	if string.find(d.Name, "Weapon") then
		for _, x in d:GetDescendants() do
			if x:IsA("BasePart") then x.LocalTransparencyModifier = 1; x.Transparency = 1; n += 1 end
		end
	end
end
return "hidden parts " .. n
"""


def wait_state(c, cond, timeout, every=1.0):
    t0, last = time.time(), ""
    while time.time() - t0 < timeout:
        last = lua(c, STATE, "Server")
        if cond(last):
            return last
        time.sleep(every)
    return last


def cam(c, where):
    return lua(c, CAM % where, "Client")


def shots(c, tag):
    note(f"== {tag} values ==")
    note(lua(c, PROBE, "Client"))
    note(lua(c, TELE, "Server"))
    note(lua(c, ANCH % ("true", "on"), "Server"))
    time.sleep(1.5)
    save(c, f"{tag}_stand_front", cam(c, "pos + look * 9"))
    save(c, f"{tag}_stand_side", cam(c, "pos + right * 9"))
    note(lua(c, ANCH % ("false", "off"), "Server"))
    note(lua(c, WALK, "Client"))
    time.sleep(0.9)
    save(c, f"{tag}_walk_front", cam(c, "pos + look * 9"))
    save(c, f"{tag}_walk_side", cam(c, "pos + right * 9"))
    note("walk values: " + lua(c, PROBE, "Client"))
    lua(c, 'local h = game:GetService("Players"):GetPlayers()[1].Character.Humanoid h:Move(Vector3.zero, true) return "stop"', "Server")
    note(lua(c, TELE, "Server"))
    note(lua(c, ANCH % ("true", "on"), "Server"))
    time.sleep(1)
    note(lua(c, HIDEW, "Client"))
    time.sleep(0.5)
    save(c, f"{tag}_noweapon_front", cam(c, "pos + look * 9"))
    note(lua(c, ANCH % ("false", "off"), "Server"))


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
        note("first values right after joining (no class yet):\n" + lua(c, PROBE, "Client"))
        for cls, tier in (("Warrior", 3), ("Mage", 3)):
            if cls == "Warrior":
                note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
                wait_state(c, lambda x: "Faction=Halo" in x, 20)
                note(lua(c, FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
                note("chosen: " + wait_state(c, lambda x: "ClassChosen=true" in x, 20))
                time.sleep(2)
                note("values right after choosing, weapon tier default:\n" + lua(c, PROBE, "Client"))
                note(lua(c, FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
                time.sleep(1)
            else:
                note(lua(c, DEBUG % '{ "Class", "Mage" }', "Server"))
                time.sleep(4)
            note("gear: " + lua(c, DEBUG % '{ "Level", 30 }, { "WeaponOwnedMask", 127 }', "Server"))
            time.sleep(1)
            note(lua(c, FIRE % ("EquipWeapon", str(tier), "EquipWeapon"), "Client"))
            time.sleep(3)
            note("state: " + lua(c, STATE, "Server"))
            shots(c, cls.lower())
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
