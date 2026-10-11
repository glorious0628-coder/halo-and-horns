-- WeaponPose.luau (게임성 개발 1, SPEC A23-108 ③ "서기·걷기 때 무기 든 자세"; docs/design/class_grips_a23_108_2026-10-10.md):
-- a character holding a weapon (the server's WeaponModel, attribute Class) stands the way its class x faction holds it
-- (Config.ClassGrips[Config.ClassGripKey(class, faction)].Hold) - added on top of Roblox's idle / walk animation, on this
-- client, for the nearest MaxChars characters within Dist studs of the camera (phones: MaxTouch). While Fx plays an
-- attack / hurt clip on a character (Fx.Animating) the pose steps aside (the joints handed back) and eases back in
-- over FadeIn s after it. Walking keeps only Walk of the shoulders' forward raise (the walk swing still shows). The
-- joint writing follows Fx's procedural clips (PreSimulation, the Animator's pose of this frame as the base; a joint
-- the Animator left alone keeps the base it had). Bare hands (no WeaponModel) = no pose. Presentation only: Transform
-- never replicates, every client poses the characters it sees.
-- Public API: WeaponPose.Init(C), WeaponPose.Start(), WeaponPose.HoldFor(classId, faction) -> def? (pure),
-- WeaponPose.Angles(def, joint, weight, moving) -> { rx, ry, rz } in degrees (pure), WeaponPose.Step(dt).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local WeaponPose = {}
local C = nil
local TAG = "WeaponPose"

local T = {
	Dist = 120, -- studs from the camera
	MaxChars = 12, MaxTouch = 6,
	Pick = 0.5, -- s between picking the characters
	FadeIn = 0.15, -- s: the pose eases in (after an attack, a new weapon)
	MoveSpeed = 2, -- studs / s of flat speed = walking
	Model = "WeaponModel",
	-- R15 joint -> its child part and parent part (the same pairs as Fx MOTION.JOINT_PARTS / JOINT_PARENTS)
	Parts = { Waist = { "UpperTorso", "LowerTorso" }, Neck = { "Head", "UpperTorso" },
		RightShoulder = { "RightUpperArm", "UpperTorso" }, RightElbow = { "RightLowerArm", "RightUpperArm" },
		RightWrist = { "RightHand", "RightLowerArm" }, LeftShoulder = { "LeftUpperArm", "UpperTorso" },
		LeftElbow = { "LeftLowerArm", "LeftUpperArm" }, LeftWrist = { "LeftHand", "LeftLowerArm" } },
	Shoulders = { RightShoulder = true, LeftShoulder = true },
	-- two hands: the joints the solve reads / writes (joint -> { arm, solve key }), the R15 default grip spots
	-- (place rig: Left/RightGripAttachment (0, -0.158, 0)), the elbows' sides (torso space: down and out), the gap
	-- between the hands (their sizes along the handle + a pad, clamped by TwoHand.Gap or this)
	TwoJoints = { "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist" },
	TwoKeys = { RightShoulder = { "Right", "Shoulder" }, RightElbow = { "Right", "Elbow" }, RightWrist = { "Right", "Wrist" },
		LeftShoulder = { "Left", "Shoulder" }, LeftElbow = { "Left", "Elbow" }, LeftWrist = { "Left", "Wrist" } },
	RightGrip = Vector3.new(0, -0.158, 0), LeftGrip = Vector3.new(0, -0.158, 0),
	PoleRight = Vector3.new(0.7, -0.7, 0.2), Pole = Vector3.new(-0.7, -0.7, 0.2),
	Gap = { 0.45, 0.8 }, GapPad = 0.05,
	ProbeEvery = 2, -- s: Studio's GripProbe print (WeaponPose.ProbeStep: every frame measured, the worst printed)
}
local S = { Chars = {}, PickAt = -math.huge, Set = {}, Started = false } -- Chars[char] = { Joints, Base, Last, W, Key }

-- the hold of a class x faction (pure): its own row, else the class's (a side not chosen)
function WeaponPose.HoldFor(classId, faction)
	local grips = type(Config.ClassGrips) == "table" and Config.ClassGrips or {}
	local key = type(Config.ClassGripKey) == "function" and Config.ClassGripKey(classId, faction) or nil
	local def = key and grips[key] or nil
	if type(def) ~= "table" and type(classId) == "string" then def = grips[classId .. "_Halo"] end
	return (type(def) == "table" and type(def.Hold) == "table") and def or nil
end

-- one joint's offset (pure, degrees): the hold x weight, the shoulders' forward raise x Walk while moving
function WeaponPose.Angles(def, joint, weight, moving)
	local a = type(def) == "table" and type(def.Hold) == "table" and def.Hold[joint] or nil
	if type(a) ~= "table" then return nil end
	local w = math.clamp(tonumber(weight) or 0, 0, 1)
	local rx = (tonumber(a[1]) or 0) * ((moving and T.Shoulders[joint]) and math.clamp(tonumber(def.Walk) or 1, 0, 1) or 1)
	return { rx * w, (tonumber(a[2]) or 0) * w, (tonumber(a[3]) or 0) * w }
end

local function same(a, b)
	return typeof(a) == "CFrame" and typeof(b) == "CFrame" and a.Position:FuzzyEq(b.Position, 1e-4)
		and a.LookVector:FuzzyEq(b.LookVector, 1e-4) and a.UpVector:FuzzyEq(b.UpVector, 1e-4)
end

-- 메인 반영 10/10 (no pose seen): today's avatars may carry upgraded joints - an AnimationConstraint (Attachment0 on
-- the parent part, Attachment1 on the child) instead of the Motor6D - so both are found (the same pairs as Fx's clips)
local function joins(d, part, parent)
	if d:IsA("Motor6D") then return d.Enabled and d.Part1 == part and d.Part0 == parent end
	if d:IsA("AnimationConstraint") then
		local a0, a1 = d.Attachment0, d.Attachment1
		return d.Enabled and a0 ~= nil and a1 ~= nil and a1.Parent == part and a0.Parent == parent
	end
	return false
end

local function findJoint(char, joint)
	local pair = T.Parts[joint]
	local part, parent = char:FindFirstChild(pair[1]), char:FindFirstChild(pair[2])
	if not (part and parent) then return nil end
	local best = nil
	for _, holder in { part, parent } do
		for _, d in holder:GetChildren() do
			local ok, hit = pcall(joins, d, part, parent)
			if ok and hit then
				if d:IsA("AnimationConstraint") then return d end -- the upgraded joint is the one the Animator drives
				best = best or d
			end
		end
	end
	return best
end

-- hands every joint this module still holds back to the pose under it
local function release(st)
	for joint, m in st.Joints do
		local last, base = st.Last[joint], st.Base[joint]
		if m.Parent and last and base and same(m.Transform, last) then pcall(function() m.Transform = base end) end
	end
	table.clear(st.Last)
	table.clear(st.Base)
end

local function animating(char)
	local fx = C and C.Fx
	if type(fx) ~= "table" or type(fx.Animating) ~= "function" then return false end
	local ok, busy = pcall(fx.Animating, char)
	return ok and busy == true
end

-- the characters to pose now: holding a weapon, near the camera, the nearest first (mine always)
local function pick()
	local cam = workspace.CurrentCamera
	local at = cam and cam.CFrame.Position
	local me = Players.LocalPlayer and Players.LocalPlayer.Character
	local list = {}
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and char:FindFirstChild(T.Model) then
			local d = at and (root.Position - at).Magnitude or 0
			if char == me or d <= T.Dist then table.insert(list, { Char = char, D = char == me and -1 or d, Player = p }) end
		end
	end
	table.sort(list, function(a, b) return a.D < b.D end)
	local max = UserInputService.TouchEnabled and T.MaxTouch or T.MaxChars
	local set = {}
	for i = 1, math.min(max, #list) do set[list[i].Char] = list[i].Player end
	for char, st in S.Chars do
		if not set[char] then
			release(st)
			S.Chars[char] = nil
		end
	end
	S.Set = set
end

-- A23-108 two hands (검수 10/11; user 10/11 "대검을 잡는 게 이상한데? 손바닥 위에 올려놓은 느낌"; references in
-- docs/design/grip_reference_2026-10-11.md): the pose starts from the SWORD, not from arm angles. def.TwoHand =
-- { Hilt = the right grip point, Aim = the blade, in UpperTorso space; Gap = { min, max } studs between the two grip
-- points }. Both hands are solved onto the hilt with Fx's two-bone arm solver (this avatar's real bone lengths): each
-- hand's grip point (Left/RightGripAttachment, where a Roblox tool's handle runs) sits on the hilt line and the hand's
-- -Z (the axis a held weapon runs along, CharacterVisuals fist()) lies along the blade, its +Y (towards the wrist)
-- turned to its own shoulder, so the handle passes through both fists. The right hand leads (the weapon is welded to
-- it), the left one is Gap lower towards the pommel (the two hands side by side: their sizes along the handle). The
-- goals live in torso space and the arm joints are torso-relative, so walking / running / jumping (the Animator's arm
-- swing is replaced, not added) keeps both hands on the handle; a goal out of reach takes the closest reach that frame
-- (검수 10/11 walk photos: a dropped solve let the left hand hang for a frame).
function WeaponPose.TwoHandGoals(torso, th, rightGrip, leftGrip, rightShoulder, leftShoulder, gap)
	local aim = torso:VectorToWorldSpace(th.Aim.Unit)
	local hilt = torso * th.Hilt
	local function goal(point, gripPos, shoulder)
		local up = shoulder - point
		up -= aim * up:Dot(aim)
		if up.Magnitude < 1e-3 then up = torso.UpVector - aim * torso.UpVector:Dot(aim) end
		up = up.Unit
		local z = -aim
		return CFrame.new(point) * CFrame.fromMatrix(Vector3.zero, up:Cross(z), up, z) * CFrame.new(-gripPos)
	end
	return goal(hilt, rightGrip, rightShoulder), goal(hilt - aim * gap, leftGrip, leftShoulder), hilt, aim
end

local function gripOf(handPart, name, fallback)
	local a = handPart:FindFirstChild(name)
	return (a and a:IsA("Attachment")) and a.Position or fallback
end

function WeaponPose.TwoHand(char, st, def, model)
	local th, fx = def.TwoHand, C and C.Fx
	if typeof(th.Hilt) ~= "Vector3" or typeof(th.Aim) ~= "Vector3" then return false end
	if type(fx) ~= "table" or type(fx.SolveArm) ~= "function" or type(fx.ArmGeometry) ~= "function" then return false end
	local torsoPart, hand, leftHand = char:FindFirstChild("UpperTorso"), char:FindFirstChild("RightHand"), char:FindFirstChild("LeftHand")
	if not (torsoPart and hand and leftHand and model) then return false end
	for _, joint in T.TwoJoints do
		local m = st.Joints[joint]
		if not (m and m.Parent) then
			st.Joints[joint] = findJoint(char, joint)
			st.Base[joint], st.Last[joint] = nil, nil
		end
	end
	local right, left = fx.ArmGeometry(st, "Right"), fx.ArmGeometry(st, "Left")
	if not (right and left) then return false end
	local torso = torsoPart.CFrame
	local g = type(th.Gap) == "table" and th.Gap or T.Gap
	local gap = math.clamp((hand.Size.Z + leftHand.Size.Z) / 2 + T.GapPad, tonumber(g[1]) or 0.45, tonumber(g[2]) or 0.8)
	local rGoal, lGoal = WeaponPose.TwoHandGoals(torso, th, gripOf(hand, "RightGripAttachment", T.RightGrip),
		gripOf(leftHand, "LeftGripAttachment", T.LeftGrip), (torso * right.Shoulder.C0).Position,
		(torso * left.Shoulder.C0).Position, gap)
	local rPose = fx.SolveArm(right, torso, rGoal, torso:VectorToWorldSpace(T.PoleRight))
	local lPose = fx.SolveArm(left, torso, lGoal, torso:VectorToWorldSpace(T.Pole))
	if type(rPose) ~= "table" or type(lPose) ~= "table" then return false end
	local poses = { Right = rPose, Left = lPose }
	for joint, w in T.TwoKeys do
		local m, pose = st.Joints[joint], poses[w[1]]
		if m and pose and typeof(pose[w[2]]) == "CFrame" then
			local cur = m.Transform
			local last = st.Last[joint]
			local base = (last and same(cur, last)) and (st.Base[joint] or cur) or cur
			local out = base:Lerp(pose[w[2]], st.W)
			m.Transform = out
			st.Base[joint], st.Last[joint] = base, out
		end
	end
	return not (rPose.Clamped or lPose.Clamped)
end

local function poseChar(char, player, dt)
	local st = S.Chars[char]
	if not st then
		st = { Joints = {}, Base = {}, Last = {}, W = 0 }
		S.Chars[char] = st
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local model = char:FindFirstChild(T.Model)
	if not char.Parent or not model or not hum or hum.Health <= 0 or hum.RigType ~= Enum.HumanoidRigType.R15 then
		release(st)
		st.W = 0
		return
	end
	if animating(char) then -- Fx's attack / hurt clip owns the joints now
		release(st)
		st.W = 0
		return
	end
	local def = WeaponPose.HoldFor(model:GetAttribute("Class") or player:GetAttribute("Class"), player:GetAttribute("Faction"))
	if not def then
		release(st)
		return
	end
	st.W = math.min(1, st.W + dt / T.FadeIn)
	local root = char:FindFirstChild("HumanoidRootPart")
	local v = root and root.AssemblyLinearVelocity or Vector3.zero
	local moving = Vector3.new(v.X, 0, v.Z).Magnitude > T.MoveSpeed
	for joint in def.Hold do
		local m = st.Joints[joint]
		if not (m and m.Parent) then
			m = findJoint(char, joint)
			st.Joints[joint] = m
			st.Base[joint], st.Last[joint] = nil, nil
		end
		local a = m and WeaponPose.Angles(def, joint, st.W, moving)
		if a then
			local cur = m.Transform
			local last = st.Last[joint]
			local base = (last and same(cur, last)) and (st.Base[joint] or cur) or cur
			local out = CFrame.Angles(math.rad(a[1]), math.rad(a[2]), math.rad(a[3])) * base
			m.Transform = out
			st.Base[joint], st.Last[joint] = base, out
		end
	end
	if type(def.TwoHand) == "table" then WeaponPose.TwoHand(char, st, def, model) end
end

-- Studio only (검수 10/11 grip measurements; 메인 반영 sets the LocalPlayer attribute GripProbe = true): my own held
-- weapon measured EVERY FRAME on the real parts (the pose is client-side, the server never sees it), one console line
-- per ProbeEvery s with this frame's value and the window's worst (walk / run / jump included) - per hand: dHand = the
-- hand's centre to the weapon line, dGrip = its grip attachment to the line, axis = its held axis (-Z) against the
-- line, fore = the forearm against the line (degrees, 0..90). The line = the weapon's Handle part when it has one (two-
-- hand swords), else through the right grip along the right hand's -Z. Returns { Right = {..}, Left = {..} }
function WeaponPose.Measure(char, model)
	local function at(hand, att)
		local a = hand:FindFirstChild(att)
		return (a and a:IsA("Attachment")) and a.WorldPosition or hand.Position
	end
	local rh = char:FindFirstChild("RightHand")
	if not rh then return nil end
	local handle = model:FindFirstChild("Handle")
	local p0, dir
	if handle and handle:IsA("BasePart") then
		p0, dir = handle.Position, handle.CFrame.UpVector
	else
		p0, dir = at(rh, "RightGripAttachment"), rh.CFrame.LookVector
	end
	local function off(p)
		local v = p - p0
		return (v - dir * v:Dot(dir)).Magnitude
	end
	local function ang(v)
		return math.deg(math.acos(math.clamp(math.abs(v.Unit:Dot(dir)), 0, 1)))
	end
	local out = {}
	for _, side in { "Right", "Left" } do
		local hand, lower = char:FindFirstChild(side .. "Hand"), char:FindFirstChild(side .. "LowerArm")
		if hand and lower then
			out[side] = { dHand = off(hand.Position), dGrip = off(at(hand, side .. "GripAttachment")),
				axis = ang(hand.CFrame.LookVector), fore = ang(lower.CFrame.UpVector) }
		end
	end
	return out
end

function WeaponPose.ProbeStep(me, now)
	local char = me.Character
	local model = char and char:FindFirstChild(T.Model)
	if not model then return end
	local m = WeaponPose.Measure(char, model)
	if not m then return end
	local P = S.Probe or { Max = {}, N = 0, At = now }
	S.Probe = P
	P.N += 1
	for side, v in m do
		local w = P.Max[side] or { dHand = 0, dGrip = 0, axis = 0, foreLo = 90, foreHi = 0 }
		P.Max[side] = w
		w.dHand, w.dGrip, w.axis = math.max(w.dHand, v.dHand), math.max(w.dGrip, v.dGrip), math.max(w.axis, v.axis)
		w.foreLo, w.foreHi = math.min(w.foreLo, v.fore), math.max(w.foreHi, v.fore)
	end
	if now - P.At < T.ProbeEvery then return end
	local key = Config.ClassGripKey(model:GetAttribute("Class") or me:GetAttribute("Class"), me:GetAttribute("Faction"))
	local parts = { string.format("[WeaponPose] probe %s frames=%d", tostring(key), P.N) }
	for _, side in { "Right", "Left" } do
		local v, w = m[side], P.Max[side]
		if v and w then
			table.insert(parts, string.format("%s dHand=%.2f(max %.2f) dGrip=%.2f(max %.2f) axis=%.0f(max %.0f) fore=%.0f(%.0f..%.0f)",
				side, v.dHand, w.dHand, v.dGrip, w.dGrip, v.axis, w.axis, v.fore, w.foreLo, w.foreHi))
		end
	end
	print(table.concat(parts, " | "))
	S.Probe = nil
end

function WeaponPose.Step(dt)
	local now = os.clock()
	if now - S.PickAt >= T.Pick then
		S.PickAt = now
		pick()
	end
	local me = Players.LocalPlayer
	if RunService:IsStudio() and me and me:GetAttribute("GripProbe") == true then pcall(WeaponPose.ProbeStep, me, now) end
	for char, player in S.Set do
		local ok, err = pcall(poseChar, char, player, math.clamp(tonumber(dt) or 0, 0, 0.1))
		if not ok then
			Util.Warn(TAG, "pose failed: " .. tostring(err))
			S.Set[char] = nil
		end
	end
end

function WeaponPose.Init(registry)
	C = registry
end

function WeaponPose.Start()
	if S.Started then return end
	S.Started = true
	local sig = nil
	pcall(function() sig = RunService.PreSimulation end) -- right after the Animator, like Fx's clips
	sig = sig or RunService.Stepped
	sig:Connect(function(a, b)
		local dt = type(b) == "number" and b or a
		local ok, err = pcall(WeaponPose.Step, dt)
		if not ok then Util.Warn(TAG, tostring(err)) end
	end)
end

return WeaponPose
