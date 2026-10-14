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
-- Public API: WeaponPose.Init(C), WeaponPose.Start(), WeaponPose.Measure(char, model) -> { Right, Left }?,
-- WeaponPose.ProbeStep(player, now), WeaponPose.Step(dt), WeaponPose.RestStep(now), WeaponPose.Want(kind, attacking).
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
	RestEvery = 0.1, -- s between the hold checks
	ProbeEvery = 2, -- s: Studio's GripProbe print (every frame measured, the worst printed)
}
local S = { Probe = nil, Started = false, Rest = setmetatable({}, { __mode = "k" }), RestAt = 0 }

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

-- (pure) what a held weapon of `kind` does now: "Rest" (a sword, no attack: the hanging hold), "Hold" (the plain grip and
-- toolnone) or nil (not a resting kind: Roblox's hold untouched)
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
			local want = WeaponPose.Want(kind, fxAttacking(char))
			local handle = tool:FindFirstChild("Handle")
			if want and handle and handle:IsA("BasePart") then
				local rest = want == "Rest"
				for _, tr in toolNoneTracks(char) do
					local w = rest and T.Low or 1
					if math.abs(tr.WeightTarget - w) > 1e-3 then tr:AdjustWeight(w, T.Fade) end
				end
				-- the engine's RightGrip weld (C1 = the Tool.Grip it was made with): a client's Tool.Grip change does not reach
				-- the server-made weld (SwordTest Studio 10/14: the blade stayed level), so the weld's C1 itself turns (local)
				local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
				local weld = hand and hand:FindFirstChild("RightGrip")
				if weld and weld:IsA("JointInstance") and weld.Part1 == handle then
					local c1 = Config.WeaponGrip(kind, handle.Size.Y, rest and "Rest" or nil)
					if S.Rest[tool] ~= want or weld.C1 ~= c1 then
						S.Rest[tool] = want
						weld.C1 = c1
					end
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
end

return WeaponPose
