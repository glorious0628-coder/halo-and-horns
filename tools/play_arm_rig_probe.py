"""(tools/play_arm_rig_probe.py) 게임성 개발 1, 2026-10-12: why the held-weapon hand lands near the shoulder on the user's
avatar (arm_check2: every class's elbow bent ~100 deg, the hand ~0.6 x its torso-space goal). Main Studio test Play
(메인 반영 1, own Play, numbers only, 1 photo): Halo Warrior Lv30 tier 3, then reads on the CLIENT the right arm's three
joints (class, Attachment0 / Attachment1 names, parents, local positions), the arm part / UpperTorso sizes, the bone
lengths WeaponPose uses (Fx.ArmGeometry: L1 / L2), WeaponPose.BodyScale (|shoulder C0.X| / 0.972, clamped 0.6..1.4), the
row's goal (Hilt x k) and where the grip really is, all in UpperTorso space.
Usage: HH_MAIN_STUDIO=1 py tools/play_arm_rig_probe.py [outdir-name]
Out: docs/art/verification_2026-10-12/main_apply/<outdir>/ (default arm_rig) log.txt + front.png"""
import base64
import io
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-12", "main_apply", sys.argv[1] if len(sys.argv) > 1 else "arm_rig")
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
PROBE = r"""
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local p = Players.LocalPlayer
local ch = p.Character
if not ch then return "no char" end
local Config = require(RS.Shared.Config)
local out = {}
local function v3(v) return string.format("(%.3f,%.3f,%.3f)", v.X, v.Y, v.Z) end
local ut = ch:FindFirstChild("UpperTorso")
table.insert(out, "UpperTorso size=" .. v3(ut.Size))
for _, n in { "RightUpperArm", "RightLowerArm", "RightHand", "LowerTorso", "Head" } do
	local part = ch:FindFirstChild(n)
	if part then table.insert(out, n .. " size=" .. v3(part.Size)) end
end
local pairsOf = { RightShoulder = { "RightUpperArm", "UpperTorso" }, RightElbow = { "RightLowerArm", "RightUpperArm" },
	RightWrist = { "RightHand", "RightLowerArm" } }
local frames = {}
for _, j in { "RightShoulder", "RightElbow", "RightWrist" } do
	local part, parent = ch:FindFirstChild(pairsOf[j][1]), ch:FindFirstChild(pairsOf[j][2])
	for _, holder in { part, parent } do
		for _, d in holder:GetChildren() do
			if d:IsA("Motor6D") and d.Part1 == part and d.Part0 == parent then
				table.insert(out, string.format("%s Motor6D C0=%s C1=%s", j, v3(d.C0.Position), v3(d.C1.Position)))
				frames[j] = { C0 = d.C0, C1 = d.C1 }
			elseif d:IsA("AnimationConstraint") and d.Attachment0 and d.Attachment1 and d.Attachment1.Parent == part and d.Attachment0.Parent == parent then
				local a0, a1 = d.Attachment0, d.Attachment1
				table.insert(out, string.format("%s AnimationConstraint(%s) a0=%s/%s pos=%s rot=%s a1=%s/%s pos=%s", j, d.Name,
					a0.Parent.Name, a0.Name, v3(a0.Position), v3(Vector3.new(a0.CFrame:ToEulerAnglesXYZ()) * 57.2958),
					a1.Parent.Name, a1.Name, v3(a1.Position)))
				frames[j] = { C0 = a0.CFrame, C1 = a1.CFrame }
			end
		end
	end
end
-- the rig attachments by name (what the place rig calls the shoulder)
for _, holder in { ut, ch:FindFirstChild("RightUpperArm") } do
	for _, d in holder:GetChildren() do
		if d:IsA("Attachment") and string.find(d.Name, "Shoulder") then
			table.insert(out, string.format("attachment %s/%s pos=%s", holder.Name, d.Name, v3(d.Position)))
		end
	end
end
local s, e, w = frames.RightShoulder, frames.RightElbow, frames.RightWrist
if s and e and w then
	local upper = e.C0.Position - s.C1.Position
	local lower = w.C0.Position - e.C1.Position
	local k = math.clamp(math.abs(s.C0.Position.X) / 0.972, 0.6, 1.4)
	table.insert(out, string.format("L1=%.3f L2=%.3f BodyScale=%.3f (raw %.3f)", upper.Magnitude, lower.Magnitude, k, math.abs(s.C0.Position.X) / 0.972))
	local key = Config.ClassGripKey(p:GetAttribute("Class"), p:GetAttribute("Faction"))
	local row = Config.ClassGrips[key]
	if row and row.OneHand then
		local goal = row.OneHand.Hilt * k
		table.insert(out, string.format("%s Hilt=%s goal(x k)=%s shoulderPivot=%s", key, v3(row.OneHand.Hilt), v3(goal), v3(s.C0.Position)))
	end
end
local hand = ch:FindFirstChild("RightHand")
local ga = hand and hand:FindFirstChild("RightGripAttachment")
if ga then table.insert(out, "grip now @torso=" .. v3(ut.CFrame:PointToObjectSpace(ga.WorldPosition)) .. " gripAtt=" .. v3(ga.Position)) end
table.insert(out, "GetScale=" .. tostring(ch:GetScale()))
local hum = ch:FindFirstChildOfClass("Humanoid")
for _, n in { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "BodyTypeScale", "BodyProportionScale", "HeadScale" } do
	local v = hum and hum:FindFirstChild(n)
	if v then table.insert(out, n .. "=" .. string.format("%.2f", v.Value)) end
end
return table.concat(out, "\n")
"""


def wait_state(c, cond, timeout, every=1.0):
    t0, last = time.time(), ""
    while time.time() - t0 < timeout:
        last = lua(c, STATE, "Server")
        if cond(last):
            return last
        time.sleep(every)
    return last


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
        note(lua(c, FIRE % ("EquipWeapon", "3", "EquipWeapon"), "Client"))
        time.sleep(3)
        note("state: " + lua(c, STATE, "Server"))
        note("== warrior ==\n" + lua(c, PROBE, "Client"))
        note("mage: " + lua(c, DEBUG % '{ "Class", "Mage" }', "Server"))
        time.sleep(3)
        note(lua(c, FIRE % ("EquipWeapon", "3", "EquipWeapon"), "Client"))
        time.sleep(3)
        note("== mage ==\n" + lua(c, PROBE, "Client"))
        res = c.call("screen_capture", {"capture_id": "front"})
        for part in res.get("content", []):
            if part.get("type") == "image":
                Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB").save(os.path.join(OUT, "front.png"))
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
