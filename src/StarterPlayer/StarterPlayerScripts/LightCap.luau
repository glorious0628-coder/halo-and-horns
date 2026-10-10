-- LightCap.luau (게임성 개발 1; 빛 마을 점검 #61, 2026-10-10): other players' character lights (CharacterVisuals'
-- halo / staff tip / tier PointLights, made on the server) pile up where many Halo players stand (their home town).
-- Every Every s this client keeps the lights of the nearest MaxOthers other characters (by distance to the camera) and
-- turns the rest off on this screen only (Enabled = false set locally; a light the server itself turned off is never
-- turned on - only the ones this module turned off come back). My own character's lights are never touched.
-- Assumes (검수 10/10 API review ④): the server never toggles a character light's Enabled after building it (it builds
-- lights on and rebuilds the model on a change); a server toggle on a light this module dimmed would replicate over ours.
-- Public API: LightCap.Init(C), LightCap.Start(), LightCap.Keep(list, max) -> { [key] = true } (pure: list = { { Key, D } },
-- the nearest `max`), LightCap.Pass() (one pass now).
local Players = game:GetService("Players")

local LightCap = {}

local T = {
	Every = 1, -- s between passes
	MaxOthers = 6, -- other characters whose lights stay on
}
local S = { Started = false, Off = setmetatable({}, { __mode = "k" }) } -- Off[light] = true: turned off here

-- the nearest `max` keys (pure)
function LightCap.Keep(list, max)
	table.sort(list, function(a, b) return a.D < b.D end)
	local out = {}
	for i, e in list do
		if i > max then break end
		out[e.Key] = true
	end
	return out
end

local function lightsOf(char)
	local out = {}
	for _, d in char:GetDescendants() do
		if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then table.insert(out, d) end
	end
	return out
end

-- one pass: the nearest MaxOthers other characters keep their lights; the rest are off on this screen
function LightCap.Pass()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position
	if not camPos then return end
	local me = Players.LocalPlayer
	local list = {}
	for _, p in Players:GetPlayers() do
		local char = p ~= me and p.Character or nil
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then table.insert(list, { Key = char, D = (root.Position - camPos).Magnitude }) end
	end
	local keep = LightCap.Keep(list, T.MaxOthers)
	for _, e in list do
		local on = keep[e.Key] == true
		for _, l in lightsOf(e.Key) do
			if not on and l.Enabled then
				l.Enabled = false
				S.Off[l] = true
			elseif on and S.Off[l] then
				l.Enabled = true
				S.Off[l] = nil
			end
		end
	end
end

function LightCap.Init(_registry) end

function LightCap.Start()
	if S.Started then return end
	S.Started = true
	task.spawn(function()
		while true do
			pcall(LightCap.Pass)
			task.wait(T.Every)
		end
	end)
end

return LightCap
