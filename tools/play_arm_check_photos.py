"""(tools/play_arm_check_photos.py) The user's "아바타 팔이 왜이럼?" check (게임성 개발 1 for 최종 검수, 2026-10-12): the
standing arms of every class x side in the main Studio test Play (메인 반영 1, own Play, the place's own avatar = the
user's), front + side while standing, front while walking, plus bare hands, a weapon swap (tier 3 -> 9) caught at once,
and after a respawn. Each shot logs the arm joints (Motor6D / AnimationConstraint: class, Transform angles), each hand's
place in the torso's space, the WeaponModel's children and the layered clothes (WrapLayer) count.
Usage: HH_MAIN_STUDIO=1 py tools/play_arm_check_photos.py [outdir-name]
Out: docs/art/verification_2026-10-12/main_apply/<outdir>/ (default arm_check) + log.txt"""
import base64
import io
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-12", "main_apply", sys.argv[1] if len(sys.argv) > 1 else "arm_check")
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
SETATTR = r"""
local p = game:GetService("Players"):GetPlayers()[1]
p:SetAttribute("%s", %s)
return "set %s"
"""
# the arms as they are this frame (client: the pose is client-side)
ARMS = r"""
local p = game:GetService("Players").LocalPlayer
local ch = p.Character
if not ch then return "no char" end
local out = {}
local wm = ch:FindFirstChild("WeaponModel")
local kids = {}
if wm then for _, k in wm:GetChildren() do table.insert(kids, k.ClassName .. ":" .. k.Name) end end
table.insert(out, "weapon=" .. (wm and (#kids .. "[" .. table.concat(kids, ",") .. "]") or "none"))
local hum = ch:FindFirstChildOfClass("Humanoid")
table.insert(out, "rig=" .. tostring(hum and hum.RigType.Name) .. " scale=" .. tostring(ch:GetScale()))
local wraps, acc = 0, 0
for _, d in ch:GetDescendants() do
	if d:IsA("WrapLayer") then wraps += 1 end
	if d:IsA("Accessory") then acc += 1 end
end
table.insert(out, "wraps=" .. wraps .. " accessories=" .. acc)
local animate = ch:FindFirstChild("Animate")
table.insert(out, "animate=" .. tostring(animate and animate.ClassName) .. (animate and animate:FindFirstChild("idle") and "(idle)" or ""))
local ut = ch:FindFirstChild("UpperTorso")
local pairsOf = { Shoulder = { "UpperArm", "UpperTorso" }, Elbow = { "LowerArm", "UpperArm" }, Wrist = { "Hand", "LowerArm" } }
for _, side in { "Right", "Left" } do
	for _, j in { "Shoulder", "Elbow", "Wrist" } do
		local pr = pairsOf[j]
		local part = ch:FindFirstChild(side .. pr[1])
		local parent = ch:FindFirstChild(pr[2] == "UpperTorso" and "UpperTorso" or side .. pr[2])
		local found = {}
		for _, holder in { part, parent } do
			if holder then
				for _, d in holder:GetChildren() do
					local hit = false
					if d:IsA("Motor6D") then hit = d.Part1 == part and d.Part0 == parent
					elseif d:IsA("AnimationConstraint") then
						hit = d.Attachment1 ~= nil and d.Attachment0 ~= nil and d.Attachment1.Parent == part and d.Attachment0.Parent == parent
					end
					if hit then
						local x, y, z = d.Transform:ToEulerAnglesXYZ()
						table.insert(found, string.format("%s%s(%d,%d,%d)", d.ClassName == "Motor6D" and "M" or "A", d.Enabled and "" or "-off",
							math.deg(x), math.deg(y), math.deg(z)))
					end
				end
			end
		end
		table.insert(out, side .. j .. "=" .. (#found > 0 and table.concat(found, "+") or "none"))
	end
	local hand = ch:FindFirstChild(side .. "Hand")
	if hand and ut then
		local r = ut.CFrame:PointToObjectSpace(hand.Position)
		table.insert(out, string.format("%sHand@torso=(%.2f,%.2f,%.2f)", side, r.X, r.Y, r.Z))
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
local pos = hrp.Position
local mode = "%s"
local dir = mode == "side" and hrp.CFrame.RightVector or hrp.CFrame.LookVector
local target = pos + Vector3.new(0, 0.2, 0)
local camPos = target + dir * 10
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
local p = game:GetService("Players").LocalPlayer
local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
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
KILL = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
if h then h.Health = 0 end
return "killed"
"""


def wait_state(c, cond, timeout, every=1.0):
    t0, last = time.time(), ""
    while time.time() - t0 < timeout:
        last = lua(c, STATE, "Server")
        if cond(last):
            return last
        time.sleep(every)
    return last


def shot(c, name, mode="front"):
    cam = lua(c, CAM % mode, "Client")
    time.sleep(1.2)
    note(f"{name} arms: " + lua(c, ARMS, "Client"))
    save(c, name, cam)


def stand(c, tag):
    note(lua(c, ANCH % ("true", "on"), "Server"))
    time.sleep(1.5)
    shot(c, f"{tag}_front", "front")
    shot(c, f"{tag}_side", "side")
    note(lua(c, RESET, "Client"))
    note(lua(c, ANCH % ("false", "off"), "Server"))


def walk(c, tag):
    note(lua(c, WALK % ("-1", "on"), "Client"))
    time.sleep(0.8)
    shot(c, f"{tag}_walk", "front")
    note(lua(c, WALK % ("0", "off"), "Client"))
    note(lua(c, RESET, "Client"))
    note(lua(c, TELE, "Server"))
    time.sleep(1)


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
        time.sleep(1)
        # 0. bare hands (Roblox's own idle, no WeaponPose): the reference
        note(lua(c, SETATTR % ("WeaponTier", "0", "WeaponTier 0"), "Server"))
        time.sleep(2)
        stand(c, "00_bare")
        # 1. every class x side, tier 3
        for cls in ("Warrior", "Mage", "Archer"):
            for fac in ("Halo", "Horns", "Neutral"):
                note(f"set {fac} {cls}: " + lua(c, DEBUG % f'{{ "Faction", "{fac}" }}, {{ "Class", "{cls}" }}', "Server"))
                time.sleep(3)
                note(lua(c, FIRE % ("EquipWeapon", "3", "EquipWeapon"), "Client"))
                time.sleep(2.5)
                note("state: " + lua(c, STATE, "Server"))
                tag = f"1_{cls.lower()}_{fac.lower()}"
                stand(c, tag)
                walk(c, tag)
        # 2. the weapon swap caught at once (Halo Warrior, tier 3 -> 9), then settled
        note(lua(c, DEBUG % '{ "Faction", "Halo" }, { "Class", "Warrior" }', "Server"))
        time.sleep(3)
        note(lua(c, FIRE % ("EquipWeapon", "3", "EquipWeapon"), "Client"))
        time.sleep(2.5)
        note(lua(c, ANCH % ("true", "on"), "Server"))
        note(lua(c, SETATTR % ("WeaponTier", "9", "WeaponTier 9"), "Server"))
        note("swap +0s arms: " + lua(c, ARMS, "Client"))
        cam = lua(c, CAM % "front", "Client")
        save(c, "2_swap_now", cam)
        time.sleep(2)
        note("swap +2s arms: " + lua(c, ARMS, "Client"))
        save(c, "2_swap_after", cam)
        note(lua(c, RESET, "Client"))
        note(lua(c, ANCH % ("false", "off"), "Server"))
        # 3. after a respawn
        note(lua(c, KILL, "Server"))
        time.sleep(9)
        note(lua(c, TELE, "Server"))
        time.sleep(2)
        stand(c, "3_respawn")
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
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh kept on"', "Edit"))
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
