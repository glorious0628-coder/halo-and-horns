-- WeaponPose.luau (게임성 개발 1). A23-150 7 (user 10/12 night (가) "로블록스 기본 그대로"): standing and walking with a
-- weapon is Roblox's own tool hold now - the weapon is a Tool (CharacterVisuals: Handle + RightGripAttachment, Tool.Grip
-- from Config.WeaponGrips) and the default Animate plays toolnone (the right arm forward, the weapon upright). The old
-- per-class standing poses this module wrote (A23-108 Hold / OneHand / OffHand / TwoHand and the staff foot lift) are
-- gone: it never writes a joint. What stays is Studio's grip measurement for the photo checks (메인 반영 1 sets the
-- LocalPlayer attribute GripProbe = true): my own held weapon measured every frame on the real parts, one console line
-- per ProbeEvery s with this frame's value and the window's worst (walk / run / jump included).
-- 최종 검수 10/14 (user while playing: from behind, the swordsman held the blade straight up over the shoulder like a pole,
-- the fist on the guard): RestStep - on every character holding a sword (Config.WeaponGrips rows with Rest), while no
-- attack clip runs (Fx.AttackPlaying) the default Animate's toolnone track is faded to ~0 (the arm hangs with the idle /
-- walk animation) and the Tool.Grip turns to the row's Rest (the blade at the side, tip up and back); an attack brings
-- toolnone and the plain grip back, so the swing starts from the raised arm as before. Local only (every client does
-- it for every character); it still never writes a joint.
-- A23-187 (user 10/14: our own hold for every weapon): each Config.WeaponGrips row has Rest + Hold - Side (swords, hammer,
-- baton: down at the hip, the tip back and down), Staff (upright in one hand, the foot near the ground, tilted while
-- walking), Bow (hanging from the LEFT hand: a local weld "RestBow" on LeftGripAttachment while resting, the right grip off;
-- an attack gives it back to the right grip / Fx.bowHand). PoseStep adds Config.HoldPoses' joint turns (Motor6D.Transform,
-- every frame after the animation) to every resting character. Local only; the attack clips are untouched.
-- hold-pose-2 (최종 검수 10/15, Codex build/codex/hold_pose_advice.md): the holding arm's own animated swing is damped
-- (Config.HoldPoses Damp by the move state), Stand / Walk / Run / Air turns on top, the rest pose gives way to an attack
-- clip over HoldMotion In s and comes back over Out s (the grip's Rest <-> Turn on the same clock), toolnone stays down,
-- the bow stays in the LEFT hand; a joint the animation did not write starts from its last animated value (no build-up).
-- Public API: WeaponPose.Init(C), WeaponPose.Start(), WeaponPose.Measure(char, model) -> { Right, Left }?,
-- WeaponPose.ProbeStep(player, now), WeaponPose.Step(dt), WeaponPose.RestStep(now), WeaponPose.Want(kind, attacking),
-- WeaponPose.HoldOf(kind), WeaponPose.PoseFor(kind, w, state) -> { [joint] = CFrame }, WeaponPose.PoseStep(dt),
-- WeaponPose.Smooth(r), WeaponPose.Approach(x, want, dt, time), WeaponPose.MoveState(air, share),
-- WeaponPose.Compose(base, target, damp, s), WeaponPose.DampOf(pose, joint, state), WeaponPose.BaseOf(motor) -> CFrame.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local WeaponPose = {}
local TAG = "WeaponPose"
local C = nil

local T = {
	Model = "WeaponModel",
	ToolNone = "ToolNoneAnim", -- the default Animate's toolnone Animation
	Low = 0.001, Fade = 0.15, -- the faded toolnone weight / its fade time (s)
	RestEvery = 0.05, -- s between the hold checks
	ProbeEvery = 2, -- s: Studio's GripProbe print (every frame measured, the worst printed)
	RestBow = "RestBow", -- the local left-hand weld of a resting bow (A23-187)
	MemeLook = "MemeLook", MemeKind = "Sword", -- A23-186: the joke weapons' local look (a Model under the Tool), held like a sword
	Same = 1e-4, -- a motor still holding our last output (CFrame:FuzzyEq): the animation did not write it this frame
	-- the Motor6Ds of Config.HoldPoses: joint name -> the R15 part it sits in
	Joints = { RightShoulder = "RightUpperArm", RightElbow = "RightLowerArm", RightWrist = "RightHand",
		LeftShoulder = "LeftUpperArm", LeftElbow = "LeftLowerArm", LeftWrist = "LeftHand" },
	-- each joint's parent part (an upgraded avatar's AnimationConstraint is found by this part pair, like Fx)
	Parents = { RightShoulder = "UpperTorso", RightElbow = "RightUpperArm", RightWrist = "RightLowerArm",
		LeftShoulder = "UpperTorso", LeftElbow = "LeftUpperArm", LeftWrist = "LeftLowerArm" },
}
local S = { Probe = nil, Started = false, Rest = setmetatable({}, { __mode = "k" }), RestAt = 0,
	Wrote = setmetatable({}, { __mode = "k" }), -- motor -> { Out = what we wrote, Base = the animation's value under it }
	Char = setmetatable({}, { __mode = "k" }), -- character -> { R = the rest share 0..1, W = the walk blend 0..1 }
	Joint = setmetatable({}, { __mode = "k" }) } -- character -> { [joint name] = the Motor6D / AnimationConstraint }

-- per hand: dHand = the hand's centre to the weapon line, dGrip = its grip attachment to the line (the holding hand: 0 =
-- the Handle runs through the fist), axis = its held axis (-Z, the knuckle line) against the line, fore = the forearm
-- against the line (degrees, 0..90). The line = the weapon's Handle (its centre, its +Y). Also the grip point's share up
-- the Handle (point: Config.WeaponGrips Point) for the holding hand. Returns { Right = {..}, Left = {..} }
function WeaponPose.Measure(char, model)
	local function at(hand, att)
		local a = hand:FindFirstChild(att)
		return (a and a:IsA("Attachment")) and a.WorldPosition or hand.Position
	end
	-- the hand the server's Tool hangs on (CharacterVisuals GripHand: the right one; an archer's draw moves the bow)
	local holdName = model:GetAttribute("GripHand")
	holdName = (holdName == "LeftHand" or holdName == "RightHand") and holdName or "RightHand"
	-- hold-pose-2 (Codex ④): the hand whose weld is ON (a resting / drawn bow hangs on the left: RestBow / BowGrip)
	local left = char:FindFirstChild("LeftHand")
	for _, name in { T.RestBow, "BowGrip" } do
		local wl = left and left:FindFirstChild(name)
		if wl and wl:IsA("JointInstance") and wl.Enabled then holdName = "LeftHand" end
	end
	local holder = char:FindFirstChild(holdName)
	local handle = model:FindFirstChild("Handle")
	if not (holder and handle and handle:IsA("BasePart")) then return nil end
	local p0, dir = handle.Position, handle.CFrame.UpVector
	local function off(p)
		local v = p - p0
		return (v - dir * v:Dot(dir)).Magnitude
	end
	local function ang(v) -- (Codex ④: abs - the axis line, either way; the sign shows in the photos' handleAxis)
		return math.deg(math.acos(math.clamp(math.abs(v.Unit:Dot(dir)), 0, 1)))
	end
	local out = {}
	for _, side in { "Right", "Left" } do
		local hand, lower = char:FindFirstChild(side .. "Hand"), char:FindFirstChild(side .. "LowerArm")
		if hand and lower then
			local grip = at(hand, side .. "GripAttachment")
			out[side] = { dHand = off(hand.Position), dGrip = off(grip), axis = ang(hand.CFrame.LookVector),
				fore = ang(lower.CFrame.UpVector), Holds = hand == holder,
				point = (grip - p0):Dot(dir) / math.max(handle.Size.Y, 1e-3) + 0.5 }
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
	local parts = { string.format("[WeaponPose] probe %s %s frames=%d", tostring(key), tostring(model:GetAttribute("Kind")), P.N) }
	for _, side in { "Right", "Left" } do
		local v, w = m[side], P.Max[side]
		if v and w then
			table.insert(parts, string.format("%s%s dHand=%.2f(max %.2f) dGrip=%.2f(max %.2f) axis=%.0f(max %.0f) fore=%.0f(%.0f..%.0f)%s",
				side, v.Holds and "*" or "", v.dHand, w.dHand, v.dGrip, w.dGrip, v.axis, w.axis, v.fore, w.foreLo, w.foreHi,
				v.Holds and string.format(" point=%.2f", v.point) or ""))
		end
	end
	print(table.concat(parts, " | "))
	S.Probe = nil
end

function WeaponPose.Step(dt)
	local okR, errR = pcall(WeaponPose.RestStep, os.clock())
	if not okR then Util.Warn(TAG, "rest failed: " .. tostring(errR)) end
	local me = Players.LocalPlayer
	if RunService:IsStudio() and me and me:GetAttribute("GripProbe") == true then
		local ok, err = pcall(WeaponPose.ProbeStep, me, os.clock())
		if not ok then Util.Warn(TAG, "probe failed: " .. tostring(err)) end
	end
end

-- A23-186 (pure): the joke weapon a player holds (their WeaponTier = a Config.Weapons row with Meme) -> its key or nil
function WeaponPose.MemeOf(tier)
	local def = type(tier) == "number" and Config.Weapons[tier] or nil
	return type(def) == "table" and type(def.Meme) == "string" and def.Meme or nil
end

-- A23-186: the code-drawn joke look on this client (Config.WeaponMemeScreen.Look): the server's class-shaped parts hidden
-- here (LocalTransparencyModifier), our parts welded to the Handle along its length; gone when the weapon changes
function WeaponPose.MemeLook(tool, meme)
	local handle = tool:FindFirstChild("Handle")
	local look = tool:FindFirstChild(T.MemeLook)
	if look and look:GetAttribute("Meme") ~= meme then
		look:Destroy()
		look = nil
	end
	local spec = meme and type(Config.WeaponMemeScreen) == "table" and type(Config.WeaponMemeScreen.Look) == "table"
		and Config.WeaponMemeScreen.Look[meme] or nil
	for _, p in tool:GetDescendants() do
		if p:IsA("BasePart") and not (look and p:IsDescendantOf(look)) then p.LocalTransparencyModifier = spec and 1 or 0 end
	end
	if not (spec and handle and handle:IsA("BasePart")) or look then return look end
	look = Instance.new("Model")
	look.Name = T.MemeLook
	look:SetAttribute("Meme", meme)
	local len = handle.Size.Y
	local function part(name, def, offset)
		if type(def) ~= "table" then return end
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(def.Size[1], def.Size[2], def.Size[3])
		p.Color = Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3])
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, true, false
		p.CFrame = handle.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = handle, p
		weld.Parent = p
		p.Parent = look
	end
	if meme == "Pan" then
		part("Handle", spec.Handle, CFrame.new(0, -len / 2 + spec.Handle.Size[2] / 2, 0))
		part("Pan", spec.Pan, CFrame.new(0, len / 2 + spec.Pan.Size[2] / 2 - 0.3, 0))
	else
		part("Body", spec.Body, CFrame.new(0, len / 2, 0))
		part("Comb", spec.Comb, CFrame.new(0, len / 2 + spec.Body.Size[2] / 2, 0))
		part("Beak", spec.Beak, CFrame.new(0, len / 2 + spec.Body.Size[2] / 2 - 0.3, -spec.Body.Size[3] / 2))
	end
	look.Parent = tool
	return look
end

-- (pure) a weapon kind's resting hold (Config.WeaponGrips Hold: "Side" / "Staff" / "Bow") or nil
function WeaponPose.HoldOf(kind)
	local rows = Config.WeaponGrips
	local row = type(rows) == "table" and type(kind) == "string" and rows[kind] or nil
	return type(row) == "table" and type(row.Rest) == "table" and type(row.Hold) == "string" and row.Hold or nil
end

-- hold-pose-2 (최종 검수 10/15, Codex build/codex/hold_pose_advice.md): (pure) smoothstep of a 0..1 share
function WeaponPose.Smooth(r)
	r = math.clamp(tonumber(r) or 0, 0, 1)
	return r * r * (3 - 2 * r)
end

-- (pure) x moved toward want by dt / time (linear; time <= 0 = at once)
function WeaponPose.Approach(x, want, dt, time)
	if not (tonumber(time) and time > 0) then return want end
	local step = dt / time
	if x < want then return math.min(want, x + step) end
	return math.max(want, x - step)
end

-- (pure) the move state: "Air" (jumping / falling), "Run" / "Walk" (the ground speed's share of WalkSpeed past
-- Config.HoldMotion RunAt / WalkAt) or "Stand"
function WeaponPose.MoveState(air, share)
	local HM = Config.HoldMotion or {}
	if air then return "Air" end
	share = tonumber(share) or 0
	if share >= (HM.RunAt or 0.75) then return "Run" end
	if share >= (HM.WalkAt or 0.08) then return "Walk" end
	return "Stand"
end

-- (pure) the joint turns of a resting hold: Stand blended to Walk by w (0..1), then Run / Air on top in those states
-- -> { [joint] = CFrame }
function WeaponPose.PoseFor(kind, w, state)
	local poses = Config.HoldPoses
	local hold = WeaponPose.HoldOf(kind)
	local pose = type(poses) == "table" and hold and poses[hold] or nil
	if type(pose) ~= "table" then return {} end
	local function cf(a)
		if type(a) ~= "table" then return CFrame.identity end
		return CFrame.Angles(math.rad(tonumber(a[1]) or 0), math.rad(tonumber(a[2]) or 0), math.rad(tonumber(a[3]) or 0))
	end
	local out = {}
	local stand, walk = type(pose.Stand) == "table" and pose.Stand or {}, type(pose.Walk) == "table" and pose.Walk or {}
	for _, set in { stand, walk } do
		for joint in set do
			if T.Joints[joint] and not out[joint] then out[joint] = cf(stand[joint]):Lerp(cf(walk[joint]), math.clamp(w or 0, 0, 1)) end
		end
	end
	local extra = (state == "Run" or state == "Air") and pose[state] or nil
	for joint, a in type(extra) == "table" and extra or {} do
		if T.Joints[joint] then out[joint] = (out[joint] or CFrame.identity) * cf(a) end
	end
	return out
end

-- (pure) one joint's output: the animation's value `base`, damped by `damp` (1 = none of its own turn left), under the
-- rest turn `target`; s = how much of the rest pose shows (0 = the animation / an attack clip untouched)
function WeaponPose.Compose(base, target, damp, s)
	local rest = (target or CFrame.identity) * base:Lerp(CFrame.identity, math.clamp(tonumber(damp) or 0, 0, 1))
	return base:Lerp(rest, math.clamp(tonumber(s) or 0, 0, 1))
end

-- (pure) the damping of `joint` for a hold in `state`: its arm's shoulder Damp[state], its elbow / wrist Damp.Lower, the
-- other arm's joints Damp.Free (or 0)
function WeaponPose.DampOf(pose, joint, state)
	local d = type(pose) == "table" and type(pose.Damp) == "table" and pose.Damp or {}
	local arm = pose and pose.Arm
	if type(arm) ~= "string" then return 0 end
	if joint == arm .. "Shoulder" then return tonumber(d[state]) or 0 end
	if joint == arm .. "Elbow" or joint == arm .. "Wrist" then return tonumber(d.Lower) or 0 end
	return tonumber(d.Free) or 0
end

-- (pure) what a held weapon of `kind` does now: "Rest" (no attack: our hold), "Hold" (the plain grip and toolnone) or
-- nil (a kind without a resting hold: Roblox's hold untouched)
function WeaponPose.Want(kind, attacking)
	local rows = Config.WeaponGrips
	local row = type(rows) == "table" and type(kind) == "string" and rows[kind] or nil
	if type(row) ~= "table" or type(row.Rest) ~= "table" then return nil end
	return attacking and "Hold" or "Rest"
end

local function toolNoneTracks(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then return {} end
	local out = {}
	for _, tr in animator:GetPlayingAnimationTracks() do
		local a = tr.Animation
		if a and a.Name == T.ToolNone then table.insert(out, tr) end
	end
	return out
end

local function fxAttacking(char)
	local fx = C and C.Fx
	if type(fx) ~= "table" or type(fx.AttackPlaying) ~= "function" then return false end
	local ok, v = pcall(fx.AttackPlaying, char)
	return ok and v == true
end

-- every RestEvery s: each character's held sword rests (toolnone ~0, Grip Rest) or holds (toolnone 1, plain Grip)
function WeaponPose.RestStep(now)
	if now - S.RestAt < T.RestEvery then return end
	S.RestAt = now
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local tool = char and char:FindFirstChild(T.Model)
		if tool and tool:IsA("Tool") then
			local kind = tool:GetAttribute("Kind")
			-- A23-186: a joke weapon looks like itself here and is held like a sword
			local meme = WeaponPose.MemeOf(tonumber(p:GetAttribute("WeaponTier")))
			pcall(WeaponPose.MemeLook, tool, meme)
			if meme then kind = T.MemeKind end
			local want = WeaponPose.Want(kind, fxAttacking(char))
			local handle = tool:FindFirstChild("Handle")
			if want and handle and handle:IsA("BasePart") then
				local rest = want == "Rest"
				-- hold-pose-2 (Codex ③): toolnone stays down while a hold weapon is held - rest AND attack (the attack clips
				-- drive the arm; raising toolnone again made the hand and the blade jump apart at the start / end)
				for _, tr in toolNoneTracks(char) do
					if math.abs(tr.WeightTarget - T.Low) > 1e-3 then tr:AdjustWeight(T.Low, T.Fade) end
				end
				-- the grip's Rest <-> Turn goes with the pose's clock (PoseStep); the bow's left weld here
				if WeaponPose.HoldOf(kind) == "Bow" then
					local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
					WeaponPose.BowRest(char, tool, handle, hand and hand:FindFirstChild("RightGrip"), rest)
				end
				S.Rest[tool] = want
			end
		end
	end
end

-- A23-187 the bow at rest: hanging from the LEFT hand (a local weld on LeftGripAttachment, the right grip off). Never while
-- Fx's own draw weld ("BowGrip", an archer clip + its short hold) is on; an attack hands it back to the right grip once
function WeaponPose.BowRest(char, tool, handle, rightGrip, rest)
	local left = char:FindFirstChild("LeftHand")
	if not left then return end
	local mine = left:FindFirstChild(T.RestBow)
	local fxGrip = left:FindFirstChild("BowGrip")
	local fxOn = fxGrip and fxGrip:IsA("JointInstance") and fxGrip.Enabled and fxGrip.Part1 == handle
	local rightOk = rightGrip and rightGrip:IsA("JointInstance") and rightGrip.Part1 == handle
	if rest and not fxOn and rightOk then
		if not (mine and mine:IsA("Weld")) then
			mine = Instance.new("Weld")
			mine.Name = T.RestBow
			mine.Part0, mine.Part1 = left, handle
			local att = left:FindFirstChild("LeftGripAttachment")
			mine.C0 = (att and att:IsA("Attachment")) and att.CFrame or CFrame.new(0, -left.Size.Y / 2, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
			mine.Parent = left
		end
		mine.Part1 = handle
		mine.C1 = Config.WeaponGrip(tool:GetAttribute("Kind"), handle.Size.Y, "Rest")
		if rightGrip.Enabled then rightGrip.Enabled = false end
		if not mine.Enabled then mine.Enabled = true end
	elseif mine and mine.Enabled and fxOn then
		-- hold-pose-2 (Codex ④): the bow stays in the LEFT hand - an attack keeps the rest weld until Fx's own left grip
		-- (BowGrip) is on, never a frame back in the right hand
		mine.Enabled = false
	end
end

-- hold-pose-2 (HoldTest photos 10/15: the arms kept swinging - the avatar is joint-upgraded, its Motor6Ds are OFF and
-- AnimationConstraints drive the arms): the joint that really moves `joint` of `char` - an enabled Motor6D of that name
-- in its part, else an enabled AnimationConstraint joining the same two parts (Fx.findJoints' rule); cached per character
function WeaponPose.JointOf(char, joint)
	local cache = S.Joint[char]
	if not cache then
		cache = {}
		S.Joint[char] = cache
	end
	local j = cache[joint]
	if j and j.Parent and j.Enabled then return j end
	cache[joint] = nil
	local part = char:FindFirstChild(T.Joints[joint] or "")
	if not part then return nil end
	local m = part:FindFirstChild(joint)
	if m and m:IsA("Motor6D") and m.Enabled then
		cache[joint] = m
		return m
	end
	local parentName = T.Parents[joint]
	for _, d in char:GetDescendants() do
		if d:IsA("AnimationConstraint") and d.Enabled then
			local a0, a1 = d.Attachment0, d.Attachment1
			if a0 and a1 and a1.Parent == part and a0.Parent and a0.Parent.Name == parentName then
				cache[joint] = d
				return d
			end
		end
	end
	return nil
end

-- the animation's value of a motor this frame: its Transform, or - when the Transform is still exactly what we wrote last
-- frame (the animation does not key that joint) - the base we wrote it over
function WeaponPose.BaseOf(m)
	local w = S.Wrote[m]
	local now = m.Transform
	if w and now:FuzzyEq(w.Out, T.Same) then return w.Base end
	return now
end

-- A23-187 / hold-pose-2: every frame after the animation (Stepped), each character holding a hold weapon: its rest share
-- R (down over HoldMotion In s when an attack starts, back over Out after; smoothstep), its walk blend W (Blend s), then
-- per joint WeaponPose.Compose (the holding arm's own swing damped, the rest turns on top) - nothing written at R = 0
-- (the attack clip owns the arm); the grip's C1 = Turn -> Rest on the same share
function WeaponPose.PoseStep(dt)
	dt = math.clamp(tonumber(dt) or 1 / 60, 0, 0.1)
	local HM = Config.HoldMotion or {}
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local tool = char and char:FindFirstChild(T.Model)
		local kind = tool and tool:IsA("Tool") and (WeaponPose.MemeOf(tonumber(p:GetAttribute("WeaponTier"))) and T.MemeKind
			or tool:GetAttribute("Kind")) or nil
		local hold = kind and WeaponPose.HoldOf(kind)
		local pose = hold and type(Config.HoldPoses) == "table" and Config.HoldPoses[hold] or nil
		if type(pose) ~= "table" then
			if char then S.Char[char] = nil end
			continue
		end
		local st = S.Char[char]
		if not st then
			st = { R = 1, W = 0 }
			S.Char[char] = st
		end
		local attacking = fxAttacking(char)
		st.R = WeaponPose.Approach(st.R, attacking and 0 or 1, dt, attacking and (hold == "Bow" and HM.InBow or HM.In) or HM.Out)
		local share = WeaponPose.Smooth(st.R)
		local hum = char:FindFirstChildOfClass("Humanoid")
		local root = char:FindFirstChild("HumanoidRootPart")
		local state = "Stand"
		if hum and root then
			local v = root.AssemblyLinearVelocity
			local hs = hum:GetState()
			local air = hs == Enum.HumanoidStateType.Jumping or hs == Enum.HumanoidStateType.Freefall
			state = WeaponPose.MoveState(air, Vector3.new(v.X, 0, v.Z).Magnitude / math.max(1, hum.WalkSpeed))
		end
		st.W = WeaponPose.Approach(st.W, state == "Stand" and 0 or 1, dt, HM.Blend)
		-- the grip on the same clock (not the bow: it hangs on its own left weld)
		local handle = tool:FindFirstChild("Handle")
		local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
		local weld = hand and hand:FindFirstChild("RightGrip")
		if hold ~= "Bow" and handle and weld and weld:IsA("JointInstance") and weld.Part1 == handle then
			local c1 = Config.WeaponGrip(kind, handle.Size.Y):Lerp(Config.WeaponGrip(kind, handle.Size.Y, "Rest"), share)
			if not weld.C1:FuzzyEq(c1, T.Same) then weld.C1 = c1 end
		end
		if share <= 0 then continue end -- the attack clip owns the arm
		local function motor(joint) return WeaponPose.JointOf(char, joint) end
		local turns = WeaponPose.PoseFor(kind, st.W, state)
		local joints = {}
		for joint in turns do joints[joint] = true end
		for joint in T.Joints do
			if WeaponPose.DampOf(pose, joint, state) > 0 then joints[joint] = true end
		end
		for joint in joints do
			local m = motor(joint)
			if m then
				local base = WeaponPose.BaseOf(m)
				local out = WeaponPose.Compose(base, turns[joint], WeaponPose.DampOf(pose, joint, state), share)
				m.Transform = out
				S.Wrote[m] = { Out = out, Base = base }
			end
		end
	end
end

function WeaponPose.Init(registry)
	C = registry
end

function WeaponPose.Start()
	if S.Started then return end
	S.Started = true
	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(WeaponPose.Step, dt)
		if not ok then Util.Warn(TAG, tostring(err)) end
	end)
	-- A23-187: after the Animator wrote this frame's joints, before the physics step
	RunService.Stepped:Connect(function(_, dt)
		local ok, err = pcall(WeaponPose.PoseStep, dt)
		if not ok then Util.Warn(TAG, "pose: " .. tostring(err)) end
	end)
end

return WeaponPose
