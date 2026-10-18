"""Shared Luau snippets copied from grip1016.py (that file runs main() on import)."""
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
