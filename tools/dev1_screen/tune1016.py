"""Hold-pose tuning (grip_check #2 #4, build/codex/grip_r1.md targets) in MY test Play, through WeaponPose's Studio-only
Dev1Tune attribute (branch dev1-hold-angles synced into the test Studio first). Candidates are measured on the real parts
(staff tilt, the gap staff <-> upper arm, the hand's height, the elbow bend; the sword's walk tilt), the best is photographed.
Usage: py tune1016.py [--running] [--keep]"""
import itertools, json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h1016 import Client, log, save_log, lua, shot, debug, scene, start_play, pick, stop_play, close, GAME  # noqa: E402

OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-16", "hold_tune")
os.makedirs(OUT, exist_ok=True)

# per frame for `secs`: the held weapon's axis in the body frame, its gap to the holding upper arm (the shortest distance
# between the weapon's centre line and the upper arm's centre line, minus half the arm's thickness), the hand centre's
# height against the torso (0 = the LowerTorso centre (navel), 1 = the UpperTorso centre (low chest)), the elbow bend
M2 = r'''
local secs = %s
local RS = game:GetService("RunService")
local ch = game.Players.LocalPlayer.Character
local root, tool = ch:FindFirstChild("HumanoidRootPart"), ch:FindFirstChild("WeaponModel")
local handle = tool and tool:FindFirstChild("Handle")
if not (root and handle) then return "{\"err\":\"no weapon\"}" end
local side = "Right"
local lh = ch:FindFirstChild("LeftHand")
for _, nm in { "RestBow", "BowGrip" } do
	local w = lh and lh:FindFirstChild(nm)
	if w and w:IsA("JointInstance") and w.Enabled then side = "Left" end
end
local up, low, hand = ch:FindFirstChild(side .. "UpperArm"), ch:FindFirstChild(side .. "LowerArm"), ch:FindFirstChild(side .. "Hand")
local lt, ut = ch:FindFirstChild("LowerTorso"), ch:FindFirstChild("UpperTorso")
local function segDist(p1, d1, p2, d2) -- infinite weapon line vs the arm segment (p2 +- d2), the closest distance
	local best = math.huge
	for i = 0, 20 do
		local q = p2 + d2 * (i / 10 - 1)
		local v = q - p1
		best = math.min(best, (v - d1 * v:Dot(d1)).Magnitude)
	end
	return best
end
local acc = { n = 0, tilt = 0, fwd = 0, out = 0, gapMin = 99, hMin = 9, hMax = -9, bendMin = 999, bendMax = -1, swingMax = 0, d0 = nil, dHand = 0 }
local t0 = os.clock()
local conn
conn = RS.Heartbeat:Connect(function()
	local dir = handle.CFrame.UpVector
	local rc = root.CFrame
	local x, y, z = rc.RightVector:Dot(dir), rc.UpVector:Dot(dir), rc.LookVector:Dot(dir)
	acc.n += 1
	acc.tilt += math.deg(math.acos(math.clamp(math.abs(y), 0, 1)))
	acc.fwd += math.deg(math.atan2(z, y)) -- + = the tip forward
	acc.out += math.deg(math.atan2(side == "Right" and x or -x, y)) -- + = the tip out to the holding side
	if not acc.d0 then acc.d0 = dir end
	acc.swingMax = math.max(acc.swingMax, math.deg(math.acos(math.clamp(dir:Dot(acc.d0), -1, 1))))
	local gap = segDist(handle.Position, dir, up.Position, up.CFrame.UpVector * (up.Size.Y / 2)) - math.min(up.Size.X, up.Size.Z) / 2
	acc.gapMin = math.min(acc.gapMin, gap)
	local h = (hand.Position.Y - lt.Position.Y) / math.max(0.1, ut.Position.Y - lt.Position.Y)
	acc.hMin, acc.hMax = math.min(acc.hMin, h), math.max(acc.hMax, h)
	local bend = math.deg(math.acos(math.clamp(up.CFrame.UpVector:Dot(low.CFrame.UpVector), -1, 1)))
	acc.bendMin, acc.bendMax = math.min(acc.bendMin, bend), math.max(acc.bendMax, bend)
	local v = hand.Position - handle.Position
	acc.dHand = math.max(acc.dHand, (v - dir * v:Dot(dir)).Magnitude)
end)
task.wait(secs)
conn:Disconnect()
local n = math.max(1, acc.n)
local function r(v) return math.floor(v * 100 + 0.5) / 100 end
return game:GetService("HttpService"):JSONEncode({ n = acc.n, side = side, tilt = r(acc.tilt / n), fwd = r(acc.fwd / n), out = r(acc.out / n),
	gapMin = r(acc.gapMin), hand = { r(acc.hMin), r(acc.hMax) }, bend = { r(acc.bendMin), r(acc.bendMax) }, swing = r(acc.swingMax),
	dHand = r(acc.dHand), speed = r((root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude) })
'''
CAM = r'''
local RS = game:GetService("RunService")
local cam = workspace.CurrentCamera
pcall(function() RS:UnbindFromRenderStep("Dev1Tune") end)
RS:BindToRenderStep("Dev1Tune", Enum.RenderPriority.Last.Value + 70, function()
	local v = workspace:GetAttribute("Dev1Cam2")
	local ch = game.Players.LocalPlayer.Character
	local r = ch and ch:FindFirstChild("HumanoidRootPart")
	if not v or v == "" or not r then return end
	local flat = CFrame.lookAt(r.Position, r.Position + (r.CFrame.LookVector * Vector3.new(1, 0, 1)))
	local d = ({ front = Vector3.new(0, 0, -1), side = Vector3.new(1, 0, 0), back = Vector3.new(0, 0, 1), left = Vector3.new(-1, 0, 0) })[v]
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 45
	cam.CFrame = CFrame.lookAt(r.Position + flat:VectorToWorldSpace(d) * 7.5 + Vector3.new(0, 0.6, 0), r.Position + Vector3.new(0, 0.2, 0))
end)
return "cam"
'''
CAM_OFF = 'pcall(function() game:GetService("RunService"):UnbindFromRenderStep("Dev1Tune") end) workspace:SetAttribute("Dev1Cam2", nil) workspace:SetAttribute("Dev1Tune", nil) workspace.CurrentCamera.CameraType = Enum.CameraType.Custom workspace.CurrentCamera.FieldOfView = 70 return "off"'
WALK = 'local ch = game.Players.LocalPlayer.Character local h, r = ch:FindFirstChildOfClass("Humanoid"), ch.HumanoidRootPart h:MoveTo(r.Position + (r.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit * %s) return "w"'
HALT = 'local ch = game.Players.LocalPlayer.Character ch:FindFirstChildOfClass("Humanoid"):MoveTo(ch.HumanoidRootPart.Position) return "h"'


def tune(c, payload):
    return lua(c, 'workspace:SetAttribute("Dev1Tune", %s) return "set"' % json.dumps(json.dumps(payload) if payload else ""), "Client")


def m(c, secs):
    raw = lua(c, M2 % secs, "Client")
    try:
        return json.loads(raw)
    except Exception:  # noqa: BLE001
        return {"raw": raw[:300]}


def setup(c, side, cls, tier):
    log("scene", side, cls, tier, scene(c, {"Faction": side, "Class": cls, "Level": 30, "Tutorial": "Done", "Done": ["M1_1", "M1_3", "M1_4"],
                                             "At": "Zone:SlimeMeadow"}))
    debug(c, "WeaponOwnedMask", 7)
    debug(c, "WeaponTier", tier)
    time.sleep(3.5)
    close(c)


def photos(c, tag):
    for v in ("front", "side", "back"):
        lua(c, 'workspace:SetAttribute("Dev1Cam2", %s) return ""' % json.dumps(v), "Client")
        time.sleep(0.35)
        shot(c, os.path.join(OUT, f"{tag}_{v}.png"))
    lua(c, 'workspace:SetAttribute("Dev1Cam2", nil) return ""', "Client")


def walk_measure(c):
    lua(c, WALK % 70, "Client")
    time.sleep(0.4)
    r = m(c, 1.2)
    lua(c, 'workspace:SetAttribute("Dev1Cam2", "side") return ""', "Client")
    time.sleep(0.2)
    return r


STAFF = []
for elbow, shz, rest, wrist in itertools.product((65, 80, 95), (8, 16), (0, 15, -15), (0, 15)):
    row = {"Arm": "Right", "Stand": {"RightShoulder": [0, 0, shz], "RightElbow": [elbow, 0, 0], "RightWrist": [wrist, 0, 0]},
           "Walk": {"RightShoulder": [0, 0, shz + 2], "RightElbow": [elbow, 0, 0], "RightWrist": [wrist, 0, 0]},
           "Run": {"RightShoulder": [0, 0, 4], "RightElbow": [8, 0, 0]}, "Air": {"RightElbow": [10, 0, 0]},
           "Damp": {"Stand": 0.85, "Walk": 0.95, "Run": 0.95, "Air": 0.97, "Lower": 0.98}}
    STAFF.append(({"elbow": elbow, "shz": shz, "rest": rest, "wrist": wrist},
                  {"HoldPoses": {"Staff": row}, "WeaponGrips": {k: {"Rest": [rest, 0, 0]} for k in ("Staff", "CrookStaff", "FlaskStaff")}}))


BOW = []
for elbow, rx, rz, plan in itertools.product((60, 80), (-60, -30, 0, 30, 60, 90), (-60, -30, 0, 30, 60), ("A", "B")):
    right = ({"RightShoulder": [25, 0, -8], "RightElbow": [55, 0, 0]} if plan == "A" else {"RightShoulder": [20, 0, -6], "RightElbow": [70, 0, 0]})
    stand = dict({"LeftShoulder": [10, 0, -12], "LeftElbow": [elbow, 0, 0], "LeftWrist": [0, 0, 0]}, **right)
    row = {"Arm": "Left", "Stand": stand, "Walk": stand, "Run": {"LeftShoulder": [0, 0, -4], "LeftElbow": [8, 0, 0]},
           "Air": {"LeftElbow": [10, 0, 0]}, "Damp": {"Stand": 0.85, "Walk": 0.95, "Run": 0.95, "Air": 0.97, "Lower": 0.98, "Free": 0.85}}
    BOW.append(({"plan": plan, "elbow": elbow, "rest": [rx, -90, rz]},
                {"HoldPoses": {"Bow": row}, "WeaponGrips": {k: {"Rest": [rx, -90, rz]} for k in ("Bow", "ShortBow")}}))


def score_bow(key, r):
    if "tilt" not in r:
        return 999
    lo, hi = r["hand"]
    s = max(0, 0.15 - r["gapMin"]) * 40 + max(0, -0.15 - lo) * 10 + max(0, hi - 0.9) * 10
    if key["plan"] == "A":  # the top end forward 25..40 and out 0..15
        s += abs(r["fwd"] - 32) + max(0, abs(r["out"] - 8) - 7)
    else:  # low across the body front: near horizontal
        s += abs(r["tilt"] - 80) * 0.7
    return round(s, 2)


def score_staff(r):
    if "tilt" not in r:
        return 999
    s = max(0, r["tilt"] - 8) * 2 + max(0, 0.15 - r["gapMin"]) * 40
    lo, hi = r["hand"]
    s += max(0, -0.1 - lo) * 10 + max(0, hi - 1.0) * 10  # the hand between the navel and the low chest
    b = (r["bend"][0] + r["bend"][1]) / 2
    s += max(0, 70 - b) * 0.3 + max(0, b - 100) * 0.3
    return round(s, 2)


def main():
    c = Client()
    c.start()
    if "--running" not in sys.argv:
        start_play(c)
        log("pick:", pick(c, "Halo", "Mage"))
    res = {"staff": [], "sword": []}
    try:
        log(lua(c, CAM, "Client"))
        log("clock:", lua(c, 'return tostring(game.ServerScriptService.DebugCommand:Invoke("", "Clock", 13))', "Server"))
        setup(c, "Halo", "Mage", 1)
        tune(c, None)
        time.sleep(0.6)
        base = m(c, 0.6)
        log("staff now:", json.dumps(base), "score", score_staff(base))
        photos(c, "Halo_Mage_T1_now")
        for key, payload in STAFF:
            tune(c, payload)
            time.sleep(0.5)
            r = m(c, 0.4)
            res["staff"].append({"key": key, "m": r, "score": score_staff(r)})
        res["staff"].sort(key=lambda e: e["score"])
        for e in res["staff"][:5]:
            log("staff best:", json.dumps(e))
        best = next(p for k, p in STAFF if k == res["staff"][0]["key"])
        tune(c, best)
        time.sleep(0.6)
        photos(c, "Halo_Mage_T1_best")
        res["staffBestWalk"] = walk_measure(c)
        shot(c, os.path.join(OUT, "Halo_Mage_T1_best_walk_side.png"))
        lua(c, HALT, "Client")
        for tier in (3,):
            setup(c, "Halo", "Mage", tier)
            tune(c, best)
            time.sleep(0.6)
            res[f"staffBestT{tier}"] = m(c, 0.6)
            photos(c, f"Halo_Mage_T{tier}_best")
        setup(c, "Horns", "Mage", 2)
        tune(c, best)
        time.sleep(0.6)
        res["staffBestHornsT2"] = m(c, 0.6)
        photos(c, "Horns_Mage_T2_best")
        # the sword: the walk tilt with the standing turns while walking (A) / now (B)
        setup(c, "Halo", "Warrior", 1)
        tune(c, None)
        res["sword"].append({"key": "now", "walk": walk_measure(c)})
        lua(c, HALT, "Client")
        time.sleep(0.8)
        for wr in (-10, -4, 2):
            row = {"Arm": "Right", "Stand": {"RightShoulder": [10, 0, 14], "RightElbow": [30, 0, 0], "RightWrist": [-10, 0, -14]},
                   "Walk": {"RightShoulder": [10, 0, 16], "RightElbow": [30, 0, 0], "RightWrist": [wr, 0, -14]},
                   "Run": {"RightShoulder": [0, 0, 4], "RightElbow": [8, 0, 0]}, "Air": {"RightElbow": [10, 0, 0]},
                   "Damp": {"Stand": 0.85, "Walk": 0.95, "Run": 0.95, "Air": 0.97, "Lower": 0.98}}
            tune(c, {"HoldPoses": {"SwordReady": row}})
            time.sleep(0.4)
            w = walk_measure(c)
            res["sword"].append({"key": {"walkWrist": wr}, "walk": w})
            shot(c, os.path.join(OUT, f"Halo_Warrior_T1_walk_wrist{wr}_side.png"))
            lua(c, HALT, "Client")
            time.sleep(0.8)
        for e in res["sword"]:
            log("sword:", json.dumps(e))
        # the bow: the combat-ready idle, plans A (slanted forward) / B (low across the body)
        setup(c, "Halo", "Archer", 1)
        res["bow"] = []
        for key, payload in BOW:
            tune(c, payload)
            time.sleep(0.45)
            r = m(c, 0.35)
            res["bow"].append({"key": key, "m": r, "score": score_bow(key, r)})
        for plan in ("A", "B"):
            ranked = sorted((e for e in res["bow"] if e["key"]["plan"] == plan), key=lambda e: e["score"])
            for e in ranked[:3]:
                log("bow best", plan, json.dumps(e))
            best = next(p for k, p in BOW if k == ranked[0]["key"])
            tune(c, best)
            time.sleep(0.6)
            photos(c, f"Halo_Archer_T1_plan{plan}")
            res[f"bowBest{plan}"] = ranked[0]
        setup(c, "Horns", "Archer", 2)
        for plan in ("A", "B"):
            best = next(p for k, p in BOW if k == res[f"bowBest{plan}"]["key"])
            tune(c, best)
            time.sleep(0.6)
            photos(c, f"Horns_Archer_T2_plan{plan}")
    finally:
        try:
            log(lua(c, CAM_OFF, "Client"))
        except Exception:  # noqa: BLE001
            pass
        with open(os.path.join(OUT, "tune.json"), "w", encoding="utf-8") as f:
            json.dump(res, f, ensure_ascii=False, indent=1)
        if "--keep" not in sys.argv:
            stop_play(c)
        save_log(os.path.join(OUT, "tune_log.txt"))


if __name__ == "__main__":
    main()
