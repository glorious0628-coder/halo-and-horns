"""Weapon hold check (최종 검수 10/16, user "무기 드는 것 좀 자세히 봐달라고 해. 완전 이상해."; criteria
docs/design/grip_reference_2026-10-16.md §2): side x class x weapon tier (0 = bare hands) x stand / walk / attack, photos
front / side / back + per-frame numbers on the real parts. MY test Studio Play only (STUDIO_NAME / STUDIO_ID).
Usage: py grip1016.py [--sides Halo,Horns] [--classes Warrior,Mage,Archer] [--tiers 0,1,2,3] [--running] [--keep]
  --running: Play already runs (e.g. ch2_1016.py --keep before)"""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h1016 import Client, log, save_log, lua, key, shot, debug, scene, start_play, pick, stop_play, console_errors, close, GAME  # noqa: E402


def arg(name, default):
    return sys.argv[sys.argv.index(name) + 1].split(",") if name in sys.argv else default


SIDES = arg("--sides", ["Halo", "Horns"])
CLASSES = arg("--classes", ["Warrior", "Mage", "Archer"])
TIERS = [int(t) for t in arg("--tiers", ["0", "1", "2", "3"])]
OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-16", arg("--out", ["grip_check"])[0])
os.makedirs(OUT, exist_ok=True)

# the camera: a render-step binding that follows the character's root by workspace attribute Dev1Cam (front / side / back)
CAM_ON = r'''
local RS = game:GetService("RunService")
local cam = workspace.CurrentCamera
pcall(function() RS:UnbindFromRenderStep("Dev1Cam") end)
RS:BindToRenderStep("Dev1Cam", Enum.RenderPriority.Last.Value + 50, function()
	local v = workspace:GetAttribute("Dev1Cam")
	local ch = game.Players.LocalPlayer.Character
	local r = ch and ch:FindFirstChild("HumanoidRootPart")
	if not v or v == "" or not r then return end
	local flat = CFrame.lookAt(r.Position, r.Position + (r.CFrame.LookVector * Vector3.new(1, 0, 1)))
	cam.CameraType = Enum.CameraType.Scriptable
	-- close-ups at the holding hand (handside / handfront): 4 studs away
	local tool = ch:FindFirstChild("WeaponModel")
	local hand = ch:FindFirstChild(tool and tool:GetAttribute("GripHand") or "RightHand")
	if (v == "handside" or v == "handfront") and hand then
		local d = v == "handfront" and Vector3.new(0, 0, -1) or Vector3.new(1, 0, 0)
		cam.FieldOfView = 40
		cam.CFrame = CFrame.lookAt(hand.Position + flat:VectorToWorldSpace(d) * 4 + Vector3.new(0, 0.3, 0), hand.Position)
		return
	end
	local off = ({ front = Vector3.new(0, 1.0, -8.5), side = Vector3.new(8.5, 1.0, 0), back = Vector3.new(0, 1.0, 8.5),
		left = Vector3.new(-8.5, 1.0, 0) })[v] or Vector3.new(0, 1.0, -8.5)
	cam.FieldOfView = 50
	cam.CFrame = CFrame.lookAt((flat * CFrame.new(off)).Position, r.Position + Vector3.new(0, 0.4, 0))
end)
return "cam on"
'''
CAM_OFF = r'''
pcall(function() game:GetService("RunService"):UnbindFromRenderStep("Dev1Cam") end)
workspace:SetAttribute("Dev1Cam", nil)
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
workspace.CurrentCamera.FieldOfView = 70
return "cam off"
'''
# per-frame numbers for `secs` (criteria C1..C8): the held weapon's Handle line against the holding hand, its direction in
# the body's frame, its swing, the body parts it passes through, its lowest point against the feet, the grip weld
MEASURE = r'''
local secs = %s
local RS = game:GetService("RunService")
local ch = game.Players.LocalPlayer.Character
local hum = ch and ch:FindFirstChildOfClass("Humanoid")
local root = ch and ch:FindFirstChild("HumanoidRootPart")
local model = ch and ch:FindFirstChild("WeaponModel")
if not (root and hum) then return "{\"err\":\"no character\"}" end
if not model then return "{\"bare\":true}" end
local body = {}
for _, n in { "Head", "UpperTorso", "LowerTorso", "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg",
	"LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" } do
	local p = ch:FindFirstChild(n)
	if p then table.insert(body, p) end
end
local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Include
op.FilterDescendantsInstances = body
local wparts = {}
for _, d in model:GetDescendants() do if d:IsA("BasePart") and d.Transparency < 0.95 then table.insert(wparts, d) end end
local R = { n = 0, dGripMax = 0, dGripSum = 0, axisMax = 0, foreMin = 180, pointMin = 9, pointMax = -9, hits = {},
	lowMin = 99, weldOff = 0, dirs = {}, holder = {} }
local function lineOff(p, p0, dir) local v = p - p0 return (v - dir * v:Dot(dir)).Magnitude end
local t0 = os.clock()
local conn
conn = RS.Heartbeat:Connect(function()
	local handle = model:FindFirstChild("Handle")
	if not handle then return end
	local holdName = model:GetAttribute("GripHand") or "RightHand"
	local lh = ch:FindFirstChild("LeftHand")
	for _, nm in { "RestBow", "BowGrip" } do
		local wl = lh and lh:FindFirstChild(nm)
		if wl and wl:IsA("JointInstance") and wl.Enabled then holdName = "LeftHand" end
	end
	local side = holdName == "LeftHand" and "Left" or "Right"
	local hand, lower = ch:FindFirstChild(side .. "Hand"), ch:FindFirstChild(side .. "LowerArm")
	if not (hand and lower) then return end
	R.holder[side] = (R.holder[side] or 0) + 1
	local att = hand:FindFirstChild(side .. "GripAttachment")
	local grip = att and att.WorldPosition or hand.Position
	local p0, dir = handle.Position, handle.CFrame.UpVector
	local dG = lineOff(grip, p0, dir)
	R.n += 1
	R.dGripMax = math.max(R.dGripMax, dG)
	R.dGripSum += dG
	R.axisMax = math.max(R.axisMax, math.deg(math.acos(math.clamp(math.abs(hand.CFrame.LookVector:Dot(dir)), 0, 1))))
	R.foreMin = math.min(R.foreMin, math.deg(math.acos(math.clamp(math.abs(lower.CFrame.UpVector:Dot(dir)), 0, 1))))
	local pt = (grip - p0):Dot(dir) / math.max(handle.Size.Y, 1e-3) + 0.5
	R.pointMin, R.pointMax = math.min(R.pointMin, pt), math.max(R.pointMax, pt)
	local rc = root.CFrame
	table.insert(R.dirs, { rc.RightVector:Dot(dir), rc.UpVector:Dot(dir), -rc.LookVector:Dot(dir) })
	local feet = root.Position.Y - root.Size.Y / 2 - hum.HipHeight
	for _, wp in wparts do
		for _, hit in workspace:GetPartsInPart(wp, op) do
			if not (hit == hand) then R.hits[hit.Name] = (R.hits[hit.Name] or 0) + 1 end
		end
		local lo = wp.Position.Y - (math.abs(wp.CFrame.RightVector.Y) * wp.Size.X + math.abs(wp.CFrame.UpVector.Y) * wp.Size.Y
			+ math.abs(wp.CFrame.LookVector.Y) * wp.Size.Z) / 2
		R.lowMin = math.min(R.lowMin, lo - feet)
	end
	local rg = hand:FindFirstChild("RightGrip") or (lh and (lh:FindFirstChild("RestBow") or lh:FindFirstChild("BowGrip")))
	if not (rg and rg.Enabled) and not ch:FindFirstChild("RightHand"):FindFirstChildWhichIsA("Weld") then R.weldOff += 1 end
end)
task.wait(secs)
conn:Disconnect()
-- the direction: mean (x = out to the right, y = up, z = forward) and the largest swing from it (degrees)
local mx, my, mz = 0, 0, 0
for _, d in R.dirs do mx += d[1] my += d[2] mz += d[3] end
local len = math.sqrt(mx * mx + my * my + mz * mz)
local swing = 0
if len > 0 then
	mx, my, mz = mx / len, my / len, mz / len
	for _, d in R.dirs do swing = math.max(swing, math.deg(math.acos(math.clamp(d[1] * mx + d[2] * my + d[3] * mz, -1, 1)))) end
end
local out = { kind = model:GetAttribute("Kind"), frames = R.n, holder = R.holder,
	dGripMax = math.floor(R.dGripMax * 100 + 0.5) / 100, dGripMean = R.n > 0 and math.floor(R.dGripSum / R.n * 100 + 0.5) / 100 or -1,
	axisMax = math.floor(R.axisMax + 0.5), foreMin = math.floor(R.foreMin + 0.5),
	point = { math.floor(R.pointMin * 100 + 0.5) / 100, math.floor(R.pointMax * 100 + 0.5) / 100 },
	dir = { out = math.floor(mx * 100 + 0.5) / 100, up = math.floor(my * 100 + 0.5) / 100, fwd = math.floor(mz * 100 + 0.5) / 100 },
	tilt = math.floor(math.deg(math.acos(math.clamp(math.abs(my), 0, 1))) + 0.5), swing = math.floor(swing + 0.5),
	hits = R.hits, lowAboveFeet = math.floor(R.lowMin * 100 + 0.5) / 100, weldOffFrames = R.weldOff,
	moving = math.floor((root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude * 10 + 0.5) / 10 }
return game:GetService("HttpService"):JSONEncode(out)
'''
WALK = r'''
local ch = game.Players.LocalPlayer.Character
local hum, r = ch:FindFirstChildOfClass("Humanoid"), ch:FindFirstChild("HumanoidRootPart")
local look = r.CFrame.LookVector * Vector3.new(1, 0, 1)
hum:MoveTo(r.Position + look.Unit * %s)
return "walking"
'''
HALT = r'''
local ch = game.Players.LocalPlayer.Character
local hum, r = ch:FindFirstChildOfClass("Humanoid"), ch:FindFirstChild("HumanoidRootPart")
hum:MoveTo(r.Position)
return "halt"
'''
FACE_SLIME = r'''
local p = game.Players:GetPlayers()[1]
local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
local best, bd
local f = workspace:FindFirstChild("Monsters")
for _, m in f and f:GetChildren() or {} do
	local mr = m:IsA("Model") and (m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart"))
	if mr and r then local d = (mr.Position - r.Position).Magnitude if not bd or d < bd then best, bd = mr, d end end
end
if not best then return "no monster" end
local dir = ((r.Position - best.Position) * Vector3.new(1, 0, 1)).Unit
local at = best.Position + dir * 6
r.CFrame = CFrame.lookAt(Vector3.new(at.X, r.Position.Y, at.Z), Vector3.new(best.Position.X, r.Position.Y, best.Position.Z))
return string.format("facing %s at %.1f", best.Parent and best.Parent.Name or "?", 6)
'''
VIEWS = ["front", "side", "back"]


def cam(c, v):
    lua(c, 'workspace:SetAttribute("Dev1Cam", %s) return "ok"' % json.dumps(v), "Client")


def measure(c, secs):
    raw = lua(c, MEASURE % secs, "Client")
    try:
        return json.loads(raw)
    except Exception:  # noqa: BLE001
        return {"raw": raw[:300]}


def set_tier(c, t):
    if t == 0:
        r = debug(c, "LootReset", 0)
    else:
        debug(c, "WeaponOwnedMask", 7)
        r = debug(c, "WeaponTier", t)
    time.sleep(2.0)
    return r + " tier=" + lua(c, 'return tostring(game.Players:GetPlayers()[1]:GetAttribute("WeaponTier"))', "Server")


def run_combo(c, side, cls, t, results):
    tag = f"{side}_{cls}_T{t}"
    log("==", tag, set_tier(c, t))
    close(c)  # the Daily Gifts / any window over the photo
    time.sleep(1.0)
    res = {}
    # stand
    log(" ", lua(c, FACE_SLIME, "Server"))
    time.sleep(1.5)
    for v in VIEWS:
        cam(c, v)
        time.sleep(0.35)
        shot(c, os.path.join(OUT, f"{tag}_stand_{v}.png"))
    for v in ("handside", "handfront"):
        cam(c, v)
        time.sleep(0.35)
        shot(c, os.path.join(OUT, f"{tag}_stand_{v}.png"))
    res["stand"] = measure(c, 1.0)
    # walk: one long walk, measured WHILE moving, the three views and a 5-frame side strip on the way
    lua(c, WALK % 70, "Client")
    time.sleep(0.35)
    res["walk"] = measure(c, 1.0)
    for v in VIEWS:
        cam(c, v)
        time.sleep(0.2)
        shot(c, os.path.join(OUT, f"{tag}_walk_{v}.png"))
    cam(c, "side")
    for i in range(5):
        shot(c, os.path.join(OUT, f"{tag}_walkstrip_{i}.png"))
    lua(c, HALT, "Client")
    log(" ", lua(c, FACE_SLIME, "Server"))
    time.sleep(0.8)
    # attack: one F per view (~0.12 s in), a 5-frame side strip of one more swing, numbers over one more
    for v in VIEWS:
        cam(c, v)
        time.sleep(0.3)
        key(c, "F")
        time.sleep(0.12)
        shot(c, os.path.join(OUT, f"{tag}_attack_{v}.png"))
        time.sleep(0.9)
    cam(c, "side")
    time.sleep(0.3)
    key(c, "F")
    for i in range(5):
        shot(c, os.path.join(OUT, f"{tag}_attackstrip_{i}.png"))
    time.sleep(0.8)
    key(c, "F")
    res["attack"] = measure(c, 0.9)
    cam(c, "")
    results[tag] = res
    log(" ", tag, json.dumps(res, ensure_ascii=False))


def main():
    c = Client()
    c.start()
    running = "--running" in sys.argv
    if not running:
        start_play(c)
        log("pick:", pick(c, SIDES[0], CLASSES[0]))
    results = {}
    try:
        log(lua(c, CAM_ON, "Client"))
        log("clock:", lua(c, 'return tostring(game.ServerScriptService.DebugCommand:Invoke("", "Clock", 13))', "Server"))
        for side in SIDES:
            for cls in CLASSES:
                log("scene:", scene(c, {"Faction": side, "Class": cls, "Level": 30, "Tutorial": "Done", "Done": ["M1_1", "M1_3", "M1_4"],
                                        "At": "Zone:SlimeMeadow", "Monsters": [{"Kind": "Slime", "N": 1, "Dist": 9, "Anchor": True}]}))
                time.sleep(2.5)
                debug(c, "Mana", 999)
                for t in TIERS:
                    if t == 0 and side != SIDES[0]:
                        continue  # bare hands: the same on every side
                    run_combo(c, side, cls, t, results)
                with open(os.path.join(OUT, "grip_numbers.json"), "w", encoding="utf-8") as f:
                    json.dump(results, f, ensure_ascii=False, indent=1)
        console_errors(c)
    finally:
        try:
            log(lua(c, CAM_OFF, "Client"))
        except Exception:  # noqa: BLE001
            pass
        if "--keep" not in sys.argv:
            stop_play(c)
        with open(os.path.join(OUT, "grip_numbers.json"), "w", encoding="utf-8") as f:
            json.dump(results, f, ensure_ascii=False, indent=1)
        save_log(os.path.join(OUT, "grip_log.txt"))


main()
