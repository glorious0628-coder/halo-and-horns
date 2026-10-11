-- Ground.luau : the one walking-ground raycast for server and client (게임성 개발 1, 2026-10-11; rule = Config.Ground /
-- Config.GroundRoots: Terrain, workspace.Map.Ground, the bridges and every instance tagged Config.Ground.Tag
-- "WalkGround"). Clients: LandShadow, SkillFx, Fx. Servers (게임성 개발 2) may use the same Params() / Cast().
-- The params are rebuilt when a tagged instance comes or goes, when workspace.Map changes, or every Config.Ground.Refresh
-- s (a late MapBuilder pass). Water is NOT ignored (a hit on the sea reports Material Water).
-- Public API: Ground.Params() -> RaycastParams, Ground.Cast(pos, up, down) -> RaycastResult? (from pos + up studs
-- straight down `down` studs), Ground.Tag
local CollectionService = game:GetService("CollectionService")

local Config = require(script.Parent:WaitForChild("Config"))

local Ground = {}
local G = type(Config.Ground) == "table" and Config.Ground or {}
Ground.Tag = type(G.Tag) == "string" and G.Tag or "WalkGround"

local S = { Params = nil, Map = nil, At = -math.huge, Dirty = true, Hooked = false }

local function hook()
	if S.Hooked then return end
	S.Hooked = true
	pcall(function()
		local function dirty() S.Dirty = true end
		CollectionService:GetInstanceAddedSignal(Ground.Tag):Connect(dirty)
		CollectionService:GetInstanceRemovedSignal(Ground.Tag):Connect(dirty)
	end)
end

function Ground.Params()
	hook()
	local map = workspace:FindFirstChild("Map")
	local now = os.clock()
	if S.Params and not S.Dirty and map == S.Map and now - S.At < (tonumber(G.Refresh) or 5) then return S.Params end
	local tagged = {}
	pcall(function() tagged = CollectionService:GetTagged(Ground.Tag) end)
	local params = S.Params or RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.IgnoreWater = false
	params.FilterDescendantsInstances = Config.GroundRoots(workspace.Terrain, map, tagged)
	S.Params, S.Map, S.At, S.Dirty = params, map, now, false
	return params
end

function Ground.Cast(pos, up, down)
	return workspace:Raycast(pos + Vector3.new(0, up or 3, 0), Vector3.new(0, -(down or 80), 0), Ground.Params())
end

return Ground
