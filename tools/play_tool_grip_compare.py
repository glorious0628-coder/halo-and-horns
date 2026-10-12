"""(tools/play_tool_grip_compare.py) A23-150 #7 (user 10/12 "무기 잡는 것도 골격을 로블록스 자체 무기로 시험해보고 그 위에
씌워야 될듯"): our hold (WeaponModel + WeaponPose) next to Roblox's own Tool grip on the same avatar, in the main Studio test
Play (메인 반영 1, own Play, the user's avatar). For the Paladin's sword, the Light Mage's staff and the Ranger's bow:
  A = ours as the game runs now; B = Roblox default: the WeaponModel taken off the character (so WeaponPose lets go), a
  Tool whose Handle is the weapon's long part (Handle / Shaft / the bow's main part) with the other parts welded on as they
  were, Tool.Grip = only the grip point's place on that part (no turn: Roblox's own orientation), equipped with
  Humanoid:EquipTool - the default Animate plays its tool hold. A Tool always goes in the RIGHT hand (the bow too).
Each: front + side standing, side walking. Out: a sheet per weapon (row A, row B) + log.txt with the arms' numbers.
Usage: HH_MAIN_STUDIO=1 py tools/play_tool_grip_compare.py [outdir-name]
Out: docs/art/verification_2026-10-12/main_apply/<outdir>/ (default tool_grip)"""
import base64
import io
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-12", "main_apply", sys.argv[1] if len(sys.argv) > 1 else "tool_grip")
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
            p = os.path.join(OUT, name + ".png")
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB").save(p)
            note("saved " + name)
            return p
    note("capture failed " + name)
    return None


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
# B: our WeaponModel -> a Roblox Tool (server). Handle = the long part; Grip = the grip point's place on it, no turn
TO_TOOL = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local ch = p.Character
local hum = ch and ch:FindFirstChildOfClass("Humanoid")
local wm = ch and ch:FindFirstChild("WeaponModel")
if not (hum and wm) then return "no weapon" end
local holdName = wm:GetAttribute("GripHand") or "RightHand"
local hand = ch:FindFirstChild(holdName)
local att = hand and hand:FindFirstChild((holdName == "LeftHand" and "Left" or "Right") .. "GripAttachment")
if not att then return "no grip attachment" end
local long = wm:FindFirstChild("Handle") or wm:FindFirstChild("Shaft")
if not long then
	for _, d in wm:GetChildren() do
		if d:IsA("BasePart") and (long == nil or d.Size.Magnitude > long.Size.Magnitude) then long = d end
	end
end
if not long then return "no long part" end
local gripWorld = att.WorldCFrame.Position
local tool = Instance.new("Tool")
tool.Name = "DefaultGripTest"
tool.CanBeDropped = false
tool.RequiresHandle = true
local handle = long:Clone()
handle.Name = "Handle"
for _, d in handle:GetChildren() do if d:IsA("WeldConstraint") or d:IsA("Weld") then d:Destroy() end end
handle.Anchored = false
handle.CanCollide = false
handle.Massless = true
handle.Parent = tool
local rel = long.CFrame:PointToObjectSpace(gripWorld)
tool.Grip = CFrame.new(rel)
local n = 0
for _, d in wm:GetChildren() do
	if d:IsA("BasePart") and d ~= long then
		local c = d:Clone()
		for _, w in c:GetChildren() do if w:IsA("WeldConstraint") or w:IsA("Weld") then w:Destroy() end end
		c.Anchored = false
		c.CanCollide = false
		c.Massless = true
		c.CFrame = handle.CFrame * long.CFrame:ToObjectSpace(d.CFrame)
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = handle, c
		w.Parent = c
		c.Parent = tool
		n += 1
	end
end
wm.Parent = game:GetService("ServerStorage") -- off the character: WeaponPose lets go
tool.Parent = p:FindFirstChildOfClass("Backpack") or ch
hum:EquipTool(tool)
return string.format("tool on: handle=%s parts=%d grip=(%.2f,%.2f,%.2f) hand=%s", long.Name, n, rel.X, rel.Y, rel.Z, holdName)
"""
BACK = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local ch = p.Character
local hum = ch and ch:FindFirstChildOfClass("Humanoid")
if hum then hum:UnequipTools() end
for _, holder in { ch, p:FindFirstChildOfClass("Backpack") } do
	local t = holder and holder:FindFirstChild("DefaultGripTest")
	if t then t:Destroy() end
end
local wm = game:GetService("ServerStorage"):FindFirstChild("WeaponModel")
if wm then wm.Parent = ch end
return "ours back"
"""
ARMS = r"""
local ch = game:GetService("Players").LocalPlayer.Character
if not ch then return "no char" end
local ut = ch:FindFirstChild("UpperTorso")
local out = { "weaponModel=" .. tostring(ch:FindFirstChild("WeaponModel") ~= nil), "tool=" .. tostring(ch:FindFirstChildOfClass("Tool") ~= nil) }
for _, side in { "Right", "Left" } do
	local hand, upper = ch:FindFirstChild(side .. "Hand"), ch:FindFirstChild(side .. "UpperArm")
	if hand and ut then
		local r = ut.CFrame:PointToObjectSpace(hand.Position)
		table.insert(out, string.format("%sHand@torso=(%.2f,%.2f,%.2f)", side, r.X, r.Y, r.Z))
	end
	if upper and ut then
		local d = ut.CFrame:VectorToObjectSpace(-upper.CFrame.UpVector)
		table.insert(out, string.format("%sUpperArm dir=(%.2f,%.2f,%.2f)", side, d.X, d.Y, d.Z))
	end
end
return table.concat(out, " ")
"""
CAM = r"""
local p = game:GetService("Players").LocalPlayer
local ch = p.Character
local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
if not hrp then return "no char" end
for _, g in p:FindFirstChildOfClass("PlayerGui"):GetChildren() do
	if g:IsA("ScreenGui") then g.Enabled = false end
end
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
cam.FieldOfView = 40
local mode = "%s"
local dir = mode == "side" and hrp.CFrame.RightVector or hrp.CFrame.LookVector
local target = hrp.Position + Vector3.new(0, 0.4, 0)
local camPos = target + dir * 11
cam.CFrame = CFrame.lookAt(camPos, target)
return string.format("%%f,%%f,%%f|%%f,%%f,%%f", camPos.X, camPos.Y, camPos.Z, target.X, target.Y, target.Z)
"""
RESET = r"""
local p = game:GetService("Players").LocalPlayer
for _, g in p:FindFirstChildOfClass("PlayerGui"):GetChildren() do
	if g:IsA("ScreenGui") then g.Enabled = true end
end
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
return "reset"
"""
ANCH = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if hrp then hrp.Anchored = %s end
return "anchored %s"
"""
WALK = r"""
local h = game:GetService("Players").LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
if h then h:Move(Vector3.new(0, 0, %s), true) end
return "move %s"
"""
TELE = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local ch = p.Character
if not ch then return "no char" end
ch:PivotTo(CFrame.new(0, 5, -25))
return "spot"
"""


def wait_state(c, cond, timeout, every=1.0):
    t0, last = time.time(), ""
    while time.time() - t0 < timeout:
        last = lua(c, STATE, "Server")
        if cond(last):
            return last
        time.sleep(every)
    return last


def shot(c, name, mode):
    cam = lua(c, CAM % mode, "Client")
    time.sleep(1.2)
    note(f"{name}: " + lua(c, ARMS, "Client"))
    return save(c, name, cam)


def row(c, tag):
    out = []
    note(lua(c, ANCH % ("true", "on"), "Server"))
    time.sleep(1.5)
    out.append(shot(c, f"{tag}_front", "front"))
    out.append(shot(c, f"{tag}_side", "side"))
    note(lua(c, RESET, "Client"))
    note(lua(c, ANCH % ("false", "off"), "Server"))
    note(lua(c, WALK % ("-1", "on"), "Client"))
    time.sleep(0.8)
    out.append(shot(c, f"{tag}_walk", "side"))
    note(lua(c, WALK % ("0", "off"), "Client"))
    note(lua(c, RESET, "Client"))
    note(lua(c, TELE, "Server"))
    time.sleep(1)
    return out


def sheet(name, rows, labels):
    imgs = [[Image.open(p) for p in r if p] for r in rows]
    if not imgs or not imgs[0]:
        return
    w, h = imgs[0][0].size
    cw, ch = w // 2, h // 2
    out = Image.new("RGB", (cw * 3 + 120, ch * len(imgs)), (30, 30, 30))
    d = ImageDraw.Draw(out)
    for i, r in enumerate(imgs):
        d.text((10, i * ch + ch // 2), labels[i], fill=(255, 255, 255))
        for j, im in enumerate(r):
            out.paste(im.resize((cw, ch)), (120 + j * cw, i * ch))
    p = os.path.join(OUT, name + ".png")
    out.save(p)
    note("sheet " + p)


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
        time.sleep(1)
        note("gear: " + lua(c, DEBUG % '{ "Level", 30 }, { "WeaponOwnedMask", 511 }', "Server"))
        note(lua(c, TELE, "Server"))
        for tag, cls in (("sword", "Warrior"), ("staff", "Mage"), ("bow", "Archer")):
            note(f"set Halo {cls}: " + lua(c, DEBUG % f'{{ "Faction", "Halo" }}, {{ "Class", "{cls}" }}', "Server"))
            time.sleep(3)
            note(lua(c, FIRE % ("EquipWeapon", "3", "EquipWeapon"), "Client"))
            time.sleep(2.5)
            note("state: " + lua(c, STATE, "Server"))
            a = row(c, f"{tag}_A_ours")
            note(lua(c, TO_TOOL, "Server"))
            time.sleep(2)
            b = row(c, f"{tag}_B_roblox_tool")
            note(lua(c, BACK, "Server"))
            time.sleep(1.5)
            sheet(f"_sheet_{tag}", [a, b], ["A ours", "B Roblox Tool"])
        con = text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "infinite yield", "weaponpose"))]
        note("console: " + "\n".join(errs[-30:]))
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
