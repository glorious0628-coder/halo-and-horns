-- WeaponPose.luau (게임성 개발 1). A23-150 7 (user 10/12 night (가) "로블록스 기본 그대로"): standing and walking with a
-- weapon is Roblox's own tool hold now - the weapon is a Tool (CharacterVisuals: Handle + RightGripAttachment, Tool.Grip
-- from Config.WeaponGrips) and the default Animate plays toolnone (the right arm forward, the weapon upright). The old
-- per-class standing poses this module wrote (A23-108 Hold / OneHand / OffHand / TwoHand and the staff foot lift) are
-- gone: it never writes a joint. What stays is Studio's grip measurement for the photo checks (메인 반영 1 sets the
-- LocalPlayer attribute GripProbe = true): my own held weapon measured every frame on the real parts, one console line
-- per ProbeEvery s with this frame's value and the window's worst (walk / run / jump included).
-- Public API: WeaponPose.Init(C), WeaponPose.Start(), WeaponPose.Measure(char, model) -> { Right, Left }?,
-- WeaponPose.ProbeStep(player, now), WeaponPose.Step(dt).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local WeaponPose = {}
local TAG = "WeaponPose"

local T = {
	Model = "WeaponModel",
	ProbeEvery = 2, -- s: Studio's GripProbe print (every frame measured, the worst printed)
}
local S = { Probe = nil, Started = false }

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
	local me = Players.LocalPlayer
	if RunService:IsStudio() and me and me:GetAttribute("GripProbe") == true then
		local ok, err = pcall(WeaponPose.ProbeStep, me, os.clock())
		if not ok then Util.Warn(TAG, "probe failed: " .. tostring(err)) end
	end
end

function WeaponPose.Init(_registry) end

function WeaponPose.Start()
	if S.Started then return end
	S.Started = true
	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(WeaponPose.Step, dt)
		if not ok then Util.Warn(TAG, tostring(err)) end
	end)
end

return WeaponPose
