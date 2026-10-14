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
-- 최종 검수 10/14 (walk photos: the swing threw the blade forward, the staff and the bow across the body): the holding
-- arm's animated swing is turned back at its wrist (Config.HoldPoses Counter, WeaponPose.Counter), and a joint the
-- animation did not write this frame starts from its last animated value (never our own output again: no build-up).
-- Public API: WeaponPose.Init(C), WeaponPose.Start(), WeaponPose.Measure(char, model) -> { Right, Left }?,
-- WeaponPose.ProbeStep(player, now), WeaponPose.Step(dt), WeaponPose.RestStep(now), WeaponPose.Want(kind, attacking),
-- WeaponPose.HoldOf(kind), WeaponPose.PoseFor(kind, walking) -> { [joint] = CFrame }, WeaponPose.PoseStep(),
-- WeaponPose.Counter(shoulder, elbow, k) -> CFrame, WeaponPose.BaseOf(motor) -> CFrame.
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
	Walking = 0.1, -- MoveDirection magnitude that counts as walking (the staff's WalkTilt)
	MemeLook = "MemeLook", MemeKind = "Sword", -- A23-186: the joke weapons' local look (a Model under the Tool), held like a sword
	Same = 1e-4, -- a motor still holding our last output (CFrame:FuzzyEq): the animation did not write it this frame
	-- the Motor6Ds of Config.HoldPoses: joint name -> the R15 part it sits in
	Joints = { RightShoulder = "RightUpperArm", RightElbow = "RightLowerArm", RightWrist = "RightHand",
		LeftShoulder = "LeftUpperArm", LeftElbow = "LeftLowerArm", LeftWrist = "LeftHand" },
}
local S = { Probe = nil, Started = false, Rest = setmetatable({}, { __mode = "k" }), RestAt = 0,
	Wrote = setmetatable({}, { __mode = "k" }) } -- motor -> { Out = what we wrote, Base = the animation's value under it }

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
	local holder = char:FindFirstChild(holdName)
	local handle = model:FindFirstChild("Handle")
	if not (holder and handle and handle:IsA("BasePart")) then return nil end
	local p0, dir = handle.Position, handle.CFrame.UpVector
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

-- (pure) the joint turns a resting `kind` adds (Config.HoldPoses[Hold], + WalkTilt while walking): { [joint] = CFrame }
function WeaponPose.PoseFor(kind, walking)
	local poses = Config.HoldPoses
	local hold = WeaponPose.HoldOf(kind)
	local pose = type(poses) == "table" and hold and poses[hold] or nil
	if type(pose) ~= "table" then return {} end
	local out = {}
	local function add(joint, a)
		if type(a) ~= "table" or not T.Joints[joint] then return end
		local cf = CFrame.Angles(math.rad(tonumber(a[1]) or 0), math.rad(tonumber(a[2]) or 0), math.rad(tonumber(a[3]) or 0))
		out[joint] = out[joint] and out[joint] * cf or cf
	end
	for joint, a in pose do
		if joint ~= "WalkTilt" and joint ~= "Counter" then add(joint, a) end
	end
	if walking and type(pose.WalkTilt) == "table" then
		for joint, a in pose.WalkTilt do add(joint, a) end
	end
	return out
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
				for _, tr in toolNoneTracks(char) do
					local w = rest and T.Low or 1
					-- SwordTest 10/14: to an attack at once (the swing grip comes with it - a fade showed the blade level for a
					-- moment with the arm still down); back to rest with the fade
					if math.abs(tr.WeightTarget - w) > 1e-3 then tr:AdjustWeight(w, rest and T.Fade or 0) end
				end
				-- the engine's RightGrip weld (C1 = the Tool.Grip it was made with): a client's Tool.Grip change does not reach
				-- the server-made weld (SwordTest Studio 10/14: the blade stayed level), so the weld's C1 itself turns (local)
				local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
				local weld = hand and hand:FindFirstChild("RightGrip")
				if WeaponPose.HoldOf(kind) == "Bow" then
					WeaponPose.BowRest(char, tool, handle, weld, rest)
				elseif weld and weld:IsA("JointInstance") and weld.Part1 == handle then
					local c1 = Config.WeaponGrip(kind, handle.Size.Y, rest and "Rest" or nil)
					if S.Rest[tool] ~= want or weld.C1 ~= c1 then
						weld.C1 = c1
					end
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
	elseif mine and mine.Enabled then -- an attack (or Fx's draw): back to the right grip once, Fx takes it from there
		mine.Enabled = false
		if rightOk and not fxOn then rightGrip.Enabled = true end
	end
end

-- A23-187: every frame after the animation, each resting character's joints get Config.HoldPoses' turns on top
-- (pure) the wrist turn that takes back k of the arm's animated swing: the shoulder's and the elbow's turn about X (the
-- forward / back swing of the walk / idle animation) summed, then -k of it about X
function WeaponPose.Counter(shoulder, elbow, k)
	local function swing(cf)
		if typeof(cf) ~= "CFrame" then return 0 end
		local x = cf:ToEulerAnglesXYZ()
		return x
	end
	return CFrame.Angles(-(tonumber(k) or 0) * (swing(shoulder) + swing(elbow)), 0, 0)
end

-- the animation's value of a motor this frame: its Transform, or - when the Transform is still exactly what we wrote last
-- frame (the animation does not key that joint) - the base we wrote it over
function WeaponPose.BaseOf(m)
	local w = S.Wrote[m]
	local now = m.Transform
	if w and now:FuzzyEq(w.Out, T.Same) then return w.Base end
	return now
end

function WeaponPose.PoseStep()
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local tool = char and char:FindFirstChild(T.Model)
		if tool and tool:IsA("Tool") and S.Rest[tool] == "Rest" then
			local hum = char:FindFirstChildOfClass("Humanoid")
			local walking = hum ~= nil and hum.MoveDirection.Magnitude > T.Walking
			local kind = WeaponPose.MemeOf(tonumber(p:GetAttribute("WeaponTier"))) and T.MemeKind or tool:GetAttribute("Kind")
			local function motor(joint)
				local part = char:FindFirstChild(T.Joints[joint] or "")
				local m = part and part:FindFirstChild(joint)
				return (m and m:IsA("Motor6D")) and m or nil
			end
			local turns = WeaponPose.PoseFor(kind, walking)
			-- the holding arm's swing taken back at its wrist (Config.HoldPoses Counter)
			local hold = WeaponPose.HoldOf(kind)
			local counter = hold and type(Config.HoldPoses) == "table" and type(Config.HoldPoses[hold]) == "table"
				and Config.HoldPoses[hold].Counter or nil
			if type(counter) == "table" and (counter.Arm == "Right" or counter.Arm == "Left") then
				local sh, el = motor(counter.Arm .. "Shoulder"), motor(counter.Arm .. "Elbow")
				if sh and el then
					local wrist = counter.Arm .. "Wrist"
					local back = WeaponPose.Counter(WeaponPose.BaseOf(sh), WeaponPose.BaseOf(el), counter.K)
					turns[wrist] = turns[wrist] and turns[wrist] * back or back
				end
			end
			for joint, cf in turns do
				local m = motor(joint)
				if m then
					local base = WeaponPose.BaseOf(m)
					local out = base * cf
					m.Transform = out
					S.Wrote[m] = { Out = out, Base = base }
				end
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
	RunService.Stepped:Connect(function()
		local ok, err = pcall(WeaponPose.PoseStep)
		if not ok then Util.Warn(TAG, "pose: " .. tostring(err)) end
	end)
end

return WeaponPose
