-- QuestTarget.luau : the ONE place that answers "where does the current quest step happen" (A23-36 quest marker,
-- MiniMap quest star, HUD guide beam). Pure resolution: reads Config, workspace.Map and the local player's attributes.
-- The only thing it ever creates is the invisible local anchor HUD already uses (workspace.HUDGuideAnchor_<key>); it is
-- looked up by name first, so HUD and QuestTarget never make two (HUD's localAnchor should call QuestTarget.Anchor).
-- Same parts / positions as HUD.luau findTravelTarget, L.MeadowTarget, L.BlacksmithTarget, L.StoryTap, L.PinnedTap and
-- refreshGuides:
--   travel to a zone : Crossroads pad Pad_<zone> -> gate Gate_<zone> -> anchor at the zone spawn (+3). From a faction
--                      town to the meadow: that island's bridge (Decor.Bridge_Halo / Bridge_Horns, L.MeadowTarget).
--                      From outside the Crossroads / faction towns the nearer of pad and gate (the pads stand in the
--                      Crossroads, so from the woods the meadow gate is the way, from a bridge the pad).
--   tutorial step 1/2 : the meadow (step 2 only while kills are left); nil inside the meadow
--   step 99           : visit / iron-gold goal -> the anvil (Crossroads); level goals -> the hunting zone
--   story Guide       : Blacksmith (anvil), SlimePond (pond spot), Fountain (CrownShard -> Fountain -> spot),
--                       Goose (GoosePerch -> Config.Goose.Position), OwnTown (Config.HomeZoneId), zone ids; other
--                       zones first route there with Travel. Talk / choice steps (Panel) have no place.
--   PumpkinPatch (A23-30, seasonal): outside the meadow -> Travel SlimeMeadow, in the meadow -> the south-end sign,
--                       in the passage -> the field centre, in the field -> nil; nil while the season is off.
--   HauntedHollow (A23-45, seasonal): west of the patch, its only way in is the gap in the patch's west fence: in the
--                       patch -> that gap, elsewhere -> the patch route, in the hollow -> nil.
-- Positions are studs. Nothing here yields; every Config read degrades to nil when a table is missing.
--
-- Public API (Init / Start are no-ops, so the module can be required directly or listed in ClientMain ORDER):
--   QuestTarget.Travel(zoneId, fromZone, pos?)        -> BasePart | nil
--   QuestTarget.Blacksmith()                          -> BasePart | nil
--   QuestTarget.Story(guide, fromZone, pos?, faction?) -> BasePart | Vector3 | nil
--   QuestTarget.ForEntry(entry, myZone?, faction?, pos?) -> { Part, Position, Tag, Label, Zone, Travel, Claim } | nil
--                                                        (Claim = the row is done and waits for [Claim]: QuestMarker gold)
--   QuestTarget.Anchor(key, position)                 -> BasePart (workspace.HUDGuideAnchor_<key>)
-- pos defaults to my character's position, myZone to the ZoneId attribute, faction to the Faction attribute.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local LocalPlayer = Players.LocalPlayer

local QuestTarget = {}

----------------------------------------------------------------- constants
local TUT = type(Config.Tutorial) == "table" and Config.Tutorial or {}
local TUT_STEPS = type(TUT.Steps) == "table" and TUT.Steps or {}
local STORY = type(Config.StoryQuests) == "table" and Config.StoryQuests or {}
local STORY_SPOTS = type(STORY.Landmarks) == "table" and STORY.Landmarks or {}
-- map v2 (A23-53): the Halloween path / gates / sign = MapBuilder PATCH and HOLLOW (Config.Map.Halloween)
local HW = type(Config.Map) == "table" and type(Config.Map.Halloween) == "table" and Config.Map.Halloween or {}
local HW_SIGN = typeof(HW.SignPos) == "Vector3" and HW.SignPos or Vector3.new(525, 0, 226)
local HW_PATH_X = tonumber(HW.PathX) or 535
local HW_GATE_Z = tonumber(HW.PatchGateZ) or 240

local K = {
	GuideZone = TUT.GuideZone or "SlimeMeadow", -- HUD TUT_GUIDE_ZONE
	GuideStep = TUT_STEPS.Guide or 1,
	QuestStep = TUT_STEPS.Quest or 2,
	ForgeStep = TUT_STEPS.Forge or 3, -- A23-74 weapon first: after [Accept], Otto's anvil before the meadow
	DoneStep = TUT_STEPS.Done or 99,
	QuestKills = tonumber(TUT.QuestKills) or 5,
	Town = "Crossroads", -- the anvil, the fountain and the goose perch stand here
	IronTier = 3, -- QuestService IRON_TIER (the "next goal" iron weapon)
	AnchorPrefix = "HUDGuideAnchor_", -- HUD localAnchor name
	Lift = Vector3.new(0, 3, 0), -- anchor above a zone spawn (HUD findTravelTarget)
	FountainLift = Vector3.new(0, 4, 0), -- HUD L.StoryTap fountain fallback anchor
	-- 검수 2026-10-08 (weapon-first photos): the marker's 'Forge' label sat on the anvil (2 studs up) and covered the
	-- nearby pads' '→ Goblin Woods (Lv 10+)' signs; the marker points at an anchor this far above the anvil instead
	SmithMarkLift = Vector3.new(0, 9, 0),
	DummyLift = Vector3.new(0, 8.5, 0), -- A23-221 ①: the mark over the big practice dummy's head (StoryNpcs Dummy 6.2 + head)
	SmithNear = 14, -- studs (flat) from the anvil: standing there, no 'Forge' marker - the anvil's own prompt is right in front
	-- (10/08 Play photo: seen from behind the anvil the mark lined up with the Goblin Woods pad sign)
	HomeBridge = { HaloTown = "Bridge_Halo", HornsTown = "Bridge_Horns" }, -- HUD HOME_BRIDGE
	PadFrom = { Crossroads = true, HaloTown = true, HornsTown = true }, -- pads first from these (HUD order)
	NearShare = 0.75, -- a Near step's spot counts as reached inside this share of its Radius
	NpcNear = 10, -- studs (flat) from a story NPC: no marker - its Talk prompt (Config.TownNpcs.PromptDistance) is right there
	-- the anvil from outside the Crossroads: true = route to the Crossroads (Travel); false = nil like HUD's beam,
	-- which only shows inside the Crossroads (refreshGuides)
	SmithFromAfar = true,
	-- 빛 마을 점검 #16 (2026-10-10): the zones that WALK to the Crossroads forge (the town bridges, the roads) get the
	-- mark over the anvil straight away; a trip to the Crossroads pointed at its spawn plaza and the distance jumped up
	-- at the bridge end. Other zones (the meadow, the woods, ...) still route to the Crossroads first
	SmithWalk = { Crossroads = true, HaloTown = true, HornsTown = true, Outskirts = true },
	-- A23-30 PumpkinPatch: = MapBuilder PATCH (the path x PathX, its sign, the north gate at PatchGateZ)
	Pumpkin = {
		Zone = "PumpkinPatch",
		Sign = HW_SIGN + Vector3.new(0, 3, 0), -- the sign at the path's meadow end (Map.Landmarks.PumpkinPatchSign)
		SignName = "PumpkinPatchSign",
		-- the path from the sign through the north gate: inside it the marker points into the field
		Passage = { MinX = HW_PATH_X - 9, MaxX = HW_PATH_X + 9, MinZ = HW_SIGN.Z - 4, MaxZ = HW_GATE_Z + 12 },
		Field = Vector3.new(535, 3, 335), -- used when Config.Zones.PumpkinPatch has no Center
		MeadowLand = "LandMeadow", -- Config.Map.Lands: counts as "in the meadow" even where ZoneId says Outskirts
	},
	-- A23-45 HauntedHollow: = MapBuilder HOLLOW (the gap in the patch's west fence = Config.Map.Halloween.HollowGate)
	Hollow = {
		Zone = "HauntedHollow",
		Gate = (typeof(HW.HollowGate) == "Vector3" and HW.HollowGate or Vector3.new(420, 0, 340)) + Vector3.new(0, 3, 0),
		PatchLand = "LandPumpkinPatch", -- Config.Map.Lands: counts as "in the patch" even where ZoneId says Outskirts
	},
}

-- player-facing labels (A23-48: English only, names from docs/design/glossary_en_2026-10-06.md; zone names come from
-- Config.Zones NameEn when it is there)
local TXT = Config.ClientText.QuestTarget -- the words: Config.ClientText.QuestTarget (moved 10/14)

----------------------------------------------------------------- state
local anchors = {} -- [key] = BasePart (workspace.HUDGuideAnchor_<key>)

----------------------------------------------------------------- helpers
local function attr(name, default)
	local v = LocalPlayer:GetAttribute(name)
	if v == nil then return default end
	return v
end

local function num(v, default)
	v = tonumber(v)
	if v == nil or v ~= v or v == math.huge or v == -math.huge then return default end
	return v
end

local function myFaction()
	local f = attr("Faction", "None")
	if type(f) ~= "string" or f == "" then return "None" end
	return f
end

local function myPos()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root.Position end
	return nil
end

local function zoneDef(zoneId)
	local zones = type(Config.Zones) == "table" and Config.Zones or {}
	local z = type(zoneId) == "string" and zones[zoneId] or nil
	return type(z) == "table" and z or nil
end

-- a seasonal zone exists only while its season is on (Config.ZoneAt)
local function zoneLive(z)
	if z.Season == nil then return true end
	if type(Config.SeasonOn) ~= "function" then return false end
	local ok, on = pcall(Config.SeasonOn, z.Season)
	return ok and on == true
end

local function zoneName(zoneId)
	local z = zoneDef(zoneId)
	if not z then return nil end
	if type(z.NameEn) == "string" and z.NameEn ~= "" then return z.NameEn end
	return type(z.Name) == "string" and z.Name or nil
end

local function insideRect(p, minX, maxX, minZ, maxZ)
	return p ~= nil and p.X >= minX and p.X <= maxX and p.Z >= minZ and p.Z <= maxZ
end

local function insideZone(p, z)
	if p == nil or typeof(z.Center) ~= "Vector3" or typeof(z.Size) ~= "Vector3" then return false end
	return math.abs(p.X - z.Center.X) <= z.Size.X / 2 and math.abs(p.Z - z.Center.Z) <= z.Size.Z / 2
end

local function flatDist(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- same as HUD resolvePart: BasePart, Model (PrimaryPart / first part), Attachment parent, else the first descendant part
local function resolvePart(target)
	if typeof(target) ~= "Instance" then return nil end
	if target:IsA("BasePart") then return target end
	if target:IsA("Model") then
		return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
	end
	if target:IsA("Attachment") and target.Parent and target.Parent:IsA("BasePart") then
		return target.Parent
	end
	return target:FindFirstChildWhichIsA("BasePart", true)
end

-- workspace.Map.<folder>.<name> (nil when any piece is missing)
local function mapChild(folder, name)
	local map = workspace:FindFirstChild("Map")
	local f = map and map:FindFirstChild(folder)
	return f and f:FindFirstChild(name) or nil
end

-- 빛 마을 점검 #52 (2026-10-10): a travel pad standing in `zone` that goes to `dest` (a Map.Pads child with attribute
-- TravelTo = dest - ZoneService hooks any such pad; the Halo plaza pads Pad_Halo_<dest> are placed by the world tool, not
-- by Config.Map.Pads), else nil. HUD (guides, pad glow) and the maps use it too
function QuestTarget.TownPad(zone, dest)
	if type(zone) ~= "string" or zone == "" or type(dest) ~= "string" or type(Config.ZoneAt) ~= "function" then return nil end
	local map = workspace:FindFirstChild("Map")
	local pads = map and map:FindFirstChild("Pads")
	if not pads then return nil end
	for _, p in pads:GetChildren() do
		-- 검수 10/10: BaseParts only - ZoneService connects only BasePart pads
		if p:IsA("BasePart") and p:GetAttribute("TravelTo") == dest then
			local z = Config.ZoneAt(p.Position)
			if type(z) == "table" and z.Id == zone then return p end
		end
	end
	return nil
end

-- 빛 마을 점검 #1 / #22 / #25 / #30 (2026-10-10): a story NPC in the world (dev3 TownNpcs: CollectionService tag
-- Config.StoryQuests.NpcTag, attribute NpcId) -> the part a marker floats over (its head, else its root), nil when absent
function QuestTarget.StoryNpc(npcId)
	if type(npcId) ~= "string" or npcId == "" then return nil end
	local tag = type(STORY.NpcTag) == "string" and STORY.NpcTag or "StoryNpc"
	local ok, list = pcall(function() return game:GetService("CollectionService"):GetTagged(tag) end)
	if not ok or type(list) ~= "table" then return nil end
	for _, m in list do
		if typeof(m) == "Instance" and m:GetAttribute("NpcId") == npcId and m:IsDescendantOf(workspace) then
			local head = m:FindFirstChild("Head")
			if head and head:IsA("BasePart") then return head end
			return resolvePart(m)
		end
	end
	return nil
end

----------------------------------------------------------------- anchors
-- local-only invisible anchor (HUD localAnchor): reuses HUD's part of the same name, else makes it once
function QuestTarget.Anchor(key, position)
	local a = anchors[key]
	if a and a.Parent then return a end
	local name = K.AnchorPrefix .. tostring(key)
	local found = workspace:FindFirstChild(name)
	if found and found:IsA("BasePart") then
		anchors[key] = found
		return found
	end
	a = Instance.new("Part")
	a.Name = name
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.CastShadow = false
	a.Transparency = 1
	a.Size = Vector3.new(1, 1, 1)
	a.Position = position
	a.Parent = workspace
	anchors[key] = a
	return a
end

----------------------------------------------------------------- travel
-- A23-30: meadow -> south-end sign -> passage -> field; nil in the field or while the season is off
local function pumpkinRoute(fromZone, pos)
	local P = K.Pumpkin
	local z = zoneDef(P.Zone)
	if not z or not zoneLive(z) then return nil end
	if fromZone == P.Zone or insideZone(pos, z) then return nil end
	local pass = P.Passage
	if insideRect(pos, pass.MinX, pass.MaxX, pass.MinZ, pass.MaxZ) then
		local field = typeof(z.Center) == "Vector3" and (z.Center + K.Lift) or P.Field
		return QuestTarget.Anchor("PumpkinField", field)
	end
	local inMeadow = fromZone == K.GuideZone
	if not inMeadow and pos then
		local lands = type(Config.Map) == "table" and type(Config.Map.Lands) == "table" and Config.Map.Lands or {}
		for _, l in lands do
			if type(l) == "table" and l.Name == P.MeadowLand
				and insideRect(pos, num(l.MinX, 0), num(l.MaxX, 0), num(l.MinZ, 0), num(l.MaxZ, 0)) then
				inMeadow = true
				break
			end
		end
	end
	if inMeadow then
		local sign = mapChild("Landmarks", P.SignName)
		local part = resolvePart(sign and (sign:FindFirstChild("Board") or sign))
		return part or QuestTarget.Anchor("PumpkinSign", P.Sign)
	end
	return QuestTarget.Travel(K.GuideZone, fromZone, pos)
end

-- Config.Map.Lands entry by name (nil when missing)
local function landRect(name)
	local lands = type(Config.Map) == "table" and type(Config.Map.Lands) == "table" and Config.Map.Lands or {}
	for _, l in lands do
		if type(l) == "table" and l.Name == name then return l end
	end
	return nil
end

-- A23-45: in the patch -> the gap in its west fence; elsewhere the patch route; nil in the hollow / out of season
local function hollowRoute(fromZone, pos)
	local H = K.Hollow
	local z = zoneDef(H.Zone)
	if not z or not zoneLive(z) then return nil end
	if fromZone == H.Zone or insideZone(pos, z) then return nil end
	local inPatch = fromZone == K.Pumpkin.Zone
	if not inPatch and pos then
		local l = landRect(H.PatchLand)
		inPatch = l ~= nil and insideRect(pos, num(l.MinX, 0), num(l.MaxX, 0), num(l.MinZ, 0), num(l.MaxZ, 0))
	end
	if inPatch then return QuestTarget.Anchor("HollowGate", H.Gate) end
	return pumpkinRoute(fromZone, pos)
end

-- the zone's Crossroads pad, its gate, else an anchor at its spawn (+3); see the header for the faction-town bridge
-- and the pad / gate choice. nil when fromZone already is zoneId or the zone does not exist (or is out of season).
function QuestTarget.Travel(zoneId, fromZone, pos)
	local z = zoneDef(zoneId)
	if not z or not zoneLive(z) then return nil end
	if type(fromZone) ~= "string" then fromZone = "" end
	if zoneId == K.Pumpkin.Zone then return pumpkinRoute(fromZone, pos or myPos()) end
	if zoneId == K.Hollow.Zone then return hollowRoute(fromZone, pos or myPos()) end
	if fromZone == zoneId then return nil end
	-- #52: a pad in the town I stand in that goes there (no bridge walk)
	if fromZone ~= K.Town then
		local townPad = QuestTarget.TownPad(fromZone, zoneId)
		if townPad then return townPad end
	end
	-- L.MeadowTarget: from a faction town the meadow beam first points at that island's bridge
	local bridge = zoneId == K.GuideZone and K.HomeBridge[fromZone] or nil
	if bridge then
		local part = resolvePart(mapChild("Decor", bridge))
		if part then return part end
	end
	local pad = resolvePart(mapChild("Pads", "Pad_" .. zoneId))
	local gate = resolvePart(mapChild("Gates", "Gate_" .. zoneId))
	if pad and gate and fromZone ~= "" and not K.PadFrom[fromZone] then
		pos = pos or myPos()
		if pos then
			return flatDist(pos, pad.Position) <= flatDist(pos, gate.Position) and pad or gate
		end
	end
	if pad or gate then return pad or gate end
	if typeof(z.Spawn) ~= "Vector3" then return nil end
	return QuestTarget.Anchor(zoneId, z.Spawn + K.Lift)
end

----------------------------------------------------------------- spots
-- L.BlacksmithTarget: the anvil of the artisan guild
function QuestTarget.Blacksmith()
	local guild = mapChild("Landmarks", "ArtisanGuild")
	local anvil = guild and guild:FindFirstChild("Anvil")
	return anvil and anvil:IsA("BasePart") and anvil or nil
end

-- L.StoryTap "Fountain": the shard in the fountain, the fountain itself, else the Config spot (+4)
local function fountainTarget()
	local shard = mapChild("Landmarks", "CrownShard")
	local part = shard and (shard:IsA("BasePart") and shard or shard:FindFirstChildWhichIsA("BasePart", true))
	if part then return part end
	local fountain = mapChild("Landmarks", "Fountain")
	if fountain then
		part = (fountain:IsA("BasePart") and fountain)
			or (fountain:IsA("Model") and fountain.PrimaryPart) or fountain:FindFirstChildWhichIsA("BasePart", true)
		if part then return part end
	end
	local spot = QuestTarget.StorySpot("Fountain")
	return spot and (spot + K.FountainLift) or nil
end

-- dev2-halo / 검수 10/10: the server's spot rule (Util.TaggedSpot): a part / model tagged Config.StoryQuests.LandmarkTag
-- with attribute Spot = key (in the world) wins over Config.StoryQuests.Landmarks[key], so a world marker moves the spot
-- for the server's Near checks and these guides at once. Never throws
function QuestTarget.StorySpot(key)
	if type(key) ~= "string" then return nil end
	local tag = STORY.LandmarkTag
	local okTag, tagged = false, nil
	if type(tag) == "string" then
		okTag, tagged = pcall(function() return game:GetService("CollectionService"):GetTagged(tag) end)
	end
	for _, inst in (okTag and type(tagged) == "table") and tagged or {} do
		local okPos, pos = pcall(function()
			if inst:GetAttribute("Spot") ~= key or not inst:IsDescendantOf(workspace) then return nil end
			if inst:IsA("Model") then return inst:GetPivot().Position end
			return inst.Position
		end)
		if okPos and typeof(pos) == "Vector3" then return pos end
	end
	local spot = STORY_SPOTS[key]
	return typeof(spot) == "Vector3" and spot or nil
end

-- the goose perch (MapBuilder GoosePerch), else Config.Goose.Position at hover height. A23-131 황금 알 줍기
-- (Config.Goose.Mode "Eggs", contract golden_egg_contract): carrying eggs -> my home (the nest / the cart,
-- Config.Goose.Egg.Home); the event on with empty hands -> the goose itself; between events -> my home, else the ring
-- centre (Config.Goose.Egg.Center, the fountain). A23-141: all of this only while I am in the Goose Square, else nil
local function gooseTarget()
	local goose = type(Config.Goose) == "table" and Config.Goose or {}
	if goose.Mode == "Eggs" then
		-- A23-141 Goose Square: the goose, the nest and the cart are only in the square (EggFx.Here); the real plaza has
		-- none, so outside it there is no target
		local eggFx = QuestTarget.Reg and QuestTarget.Reg.EggFx
		local sq = type(goose.Square) == "table" and goose.Square or {}
		local inSquare = type(eggFx) == "table" and type(eggFx.Here) == "function" and eggFx.Here()
			or (eggFx == nil and LocalPlayer:GetAttribute(type(sq.Attr) == "string" and sq.Attr or "InGooseSquare") == true)
		if not inSquare then return nil end
		local egg = type(goose.Egg) == "table" and goose.Egg or {}
		local gs = ReplicatedStorage:FindFirstChild("GameState")
		if gs and gs:GetAttribute("GooseActive") == true and num(LocalPlayer:GetAttribute("EggCarry"), 0) <= 0 then
			local fx = workspace:FindFirstChild("Effects")
			local g = fx and fx:FindFirstChild("GoldenGoose")
			local part = g and (g:IsA("Model") and g.PrimaryPart or g:FindFirstChildWhichIsA("BasePart", true))
			if part then return part end
		end
		-- the square's own Nest / Cart (workspace.GooseSquare) before Config.Goose.Egg.Home
		local home = type(eggFx) == "table" and type(eggFx.HomeFor) == "function" and eggFx.HomeFor(myFaction()) or nil
		if typeof(home) ~= "Vector3" then home = type(egg.Home) == "table" and egg.Home[myFaction()] or nil end
		if typeof(home) == "Vector3" then return home + K.Lift end
		return (typeof(egg.Center) == "Vector3" and egg.Center or Vector3.zero) + K.Lift
	end
	local perch = resolvePart(mapChild("Landmarks", "GoosePerch"))
	if perch then return perch end
	if typeof(goose.Position) ~= "Vector3" then return nil end
	return goose.Position + Vector3.new(0, num(goose.HoverHeight, 4), 0)
end

-- L.StoryTap "SlimePond": Config.StoryQuests.Landmarks.SlimePond (+3) = HUD STORY_SPOT
local function pondSpot()
	local spot = QuestTarget.StorySpot("SlimePond")
	return typeof(spot) == "Vector3" and (spot + K.Lift) or Vector3.new(290, 3, 150)
end

-- 빛 마을 점검 #17 / #21 / #29 (2026-10-10): a story Guide that is a Config.StoryQuests.Landmarks spot (WoodsGate,
-- HeroStatue, GoblinCamp1-3, LavaCrack, HaloBridge, ...; never a zone id; not one of the special guides) -> its spot
local function landmarkSpot(guide)
	if guide == "SlimePond" or guide == "Fountain" or guide == "Goose" or guide == "Blacksmith" or guide == "OwnTown"
		or guide == "PotionShop" or guide == "QuickSlot" or guide == "Bag" then
		return nil
	end
	return QuestTarget.StorySpot(guide)
end

-- the zone a story Guide happens in (L.StoryTap's target mapping)
local function guideZone(guide, faction)
	if guide == "OwnTown" then
		return type(Config.HomeZoneId) == "function" and Config.HomeZoneId(faction or myFaction()) or K.Town
	end
	if guide == "SlimePond" then return K.GuideZone end
	if guide == "Fountain" or guide == "Goose" or guide == "Blacksmith" or guide == "PotionShop" then return K.Town end
	local spot = landmarkSpot(guide)
	if spot and type(Config.ZoneAt) == "function" then
		local z = Config.ZoneAt(spot)
		return type(z) == "table" and z.Id or guide
	end
	return guide
end

-- the marker spot over the anvil (K.SmithMarkLift up), kept on the anvil if it moved; nil without an anvil
function QuestTarget.BlacksmithMark()
	local anvil = QuestTarget.Blacksmith()
	if not anvil then return nil end
	local a = QuestTarget.Anchor("SmithMark", anvil.Position + K.SmithMarkLift)
	a.Position = anvil.Position + K.SmithMarkLift
	return a
end

-- true when the anvil is a walk away from fromZone (K.SmithWalk): its mark, no trip
local function smithWalk(fromZone)
	return (fromZone == K.Town or K.SmithWalk[fromZone] == true) and QuestTarget.Blacksmith() ~= nil
end

local function smithFrom(fromZone, pos)
	if fromZone == K.Town or smithWalk(fromZone) then
		local anvil = QuestTarget.Blacksmith()
		if anvil and typeof(pos) == "Vector3" then
			local dx, dz = pos.X - anvil.Position.X, pos.Z - anvil.Position.Z
			if dx * dx + dz * dz <= K.SmithNear * K.SmithNear then return nil end
		end
		return QuestTarget.BlacksmithMark()
	end
	if not K.SmithFromAfar then return nil end
	return QuestTarget.Travel(K.Town, fromZone, pos)
end

-- where a story step's Guide points from fromZone: a travel target while I am in another zone, the spot inside it,
-- nil when there is nothing to point at (already in a plain zone guide's zone, unknown guide)
function QuestTarget.Story(guide, fromZone, pos, faction)
	if type(guide) ~= "string" or guide == "" then return nil end
	if type(fromZone) ~= "string" then fromZone = attr("ZoneId", "") end
	if guide == "Blacksmith" then return smithFrom(fromZone, pos) end
	-- A23-110 (dev3 KO1): "Buy a potion" -> the potion seller in the Crossroads (a trip there from elsewhere); the quick
	-- slot steps (Guide QuickSlot) have no place in the world (the row opens the bag); A23-127 (게임성 개발 2, M1_1's scroll
	-- step): Guide "Bag" neither (the row opens the bag on the scroll, the HUD's Bag tile glows)
	if guide == "QuickSlot" or guide == "Bag" then return nil end
	if guide == "PotionShop" then
		if fromZone ~= K.Town then return QuestTarget.Travel(K.Town, fromZone, pos) end
		local tune = type(Config.Vitals) == "table" and Config.Vitals or {}
		return resolvePart(mapChild("NPCs", tune.PotionMerchantName or "PotionMerchant"))
	end
	local zone = guideZone(guide, faction)
	if not zoneDef(zone) then return nil end
	local spot = landmarkSpot(guide)
	-- 검수 10/10: a landmark a walk away (both zones in K.SmithWalk, like the forge) -> the spot itself, no trip (a trip
	-- pointed at the Crossroads plaza / a gate and the distance jumped)
	if spot and fromZone ~= zone and K.SmithWalk[fromZone] == true and K.SmithWalk[zone] == true then fromZone = zone end
	if zone == K.Pumpkin.Zone or zone == K.Hollow.Zone or fromZone ~= zone then return QuestTarget.Travel(zone, fromZone, pos) end
	if guide == "SlimePond" then return pondSpot() end
	if guide == "Fountain" then return fountainTarget() end
	if guide == "Goose" then return gooseTarget() end
	if spot then -- a landmark spot in this zone (or a walk away): an anchor over it (K.Lift)
		local a = QuestTarget.Anchor("Spot_" .. guide, spot + K.Lift)
		a.Position = spot + K.Lift
		return a
	end
	return nil -- a plain zone guide: I am already there
end

----------------------------------------------------------------- quest rows
-- the step's objective (the faction variant first, e.g. M2_1 Neutral), for Near radii
local function stepObj(st, faction)
	local defs = type(STORY.Defs) == "table" and STORY.Defs or {}
	local def = defs[st.Id]
	local steps = type(def) == "table" and type(def.Steps) == "table" and def.Steps or nil
	local step = steps and steps[math.floor(num(st.St, 1))] or nil
	if type(step) ~= "table" then return nil end
	local variant = type(faction) == "string" and step[faction] or nil
	if type(variant) == "table" and type(variant.Obj) == "table" then return variant.Obj end
	return type(step.Obj) == "table" and step.Obj or nil
end

local function storyLabel(guide, zone)
	if guide == "Blacksmith" then return TXT.Blacksmith end
	if guide == "SlimePond" then return TXT.Pond end
	if guide == "Fountain" then
		local speakers = type(STORY.SpeakersEn) == "table" and STORY.SpeakersEn or {}
		return type(speakers.Fountain) == "string" and speakers.Fountain or TXT.Fountain
	end
	if guide == "Goose" then return TXT.Goose end
	if guide == "PotionShop" then return TXT.PotionShop end
	return zoneName(zone)
end

-- result table (nil when t resolves to nothing)
local function pack(t, tag, label, zone, travel)
	local part = typeof(t) == "Instance" and resolvePart(t) or nil
	local p = part and part.Position or (typeof(t) == "Vector3" and t or nil)
	if not p then return nil end
	return { Part = part, Position = p, Tag = tag, Label = label, Zone = zone, Travel = travel == true }
end

-- step 2 counts as "needs the meadow" only while kills are left (L.NeedsMeadowGuide)
local function needsMeadow(step, entry)
	if step == K.GuideStep then return true end
	if step ~= K.QuestStep then return false end
	local kills = num(attr("TutorialKills", nil), nil) or num(entry.Progress, 0)
	return kills < K.QuestKills
end

-- a talk step through a story NPC that stands in the world: the NPC (a trip to its zone from far; a walk away = the NPC
-- itself), nothing within NpcNear studs of it (its Talk prompt is right there); no NPC in the world = no place
local function npcEntry(st, myZone, pos)
	local part = QuestTarget.StoryNpc(st.Npc)
	if not part or type(Config.ZoneAt) ~= "function" then return nil end
	local z = Config.ZoneAt(part.Position)
	local zone = type(z) == "table" and z.Id or myZone
	local speakers = type(STORY.Speakers) == "table" and STORY.Speakers or {}
	local label = type(speakers[st.Npc]) == "string" and speakers[st.Npc] or zoneName(zone)
	if myZone ~= zone and not (K.SmithWalk[myZone] == true and K.SmithWalk[zone] == true) then
		return pack(QuestTarget.Travel(zone, myZone, pos), "story:npc", label, zone, true)
	end
	if pos and flatDist(pos, part.Position) <= K.NpcNear then return nil end
	return pack(part, "story:npc", label, zone, false)
end

local function storyEntry(st, myZone, faction, pos)
	-- 개발 2 dev2-offer-row: "Talk to <asker>" while the next main waits (Story.Offer, St = 1 is no step yet) = the way to her
	if st.Offer == true then
		return (type(st.Npc) == "string" and st.Npc ~= "") and npcEntry(st, myZone, pos) or nil
	end
	if st.Panel then -- a talk / choice card: no place, unless it is talked through a town NPC in the world
		if type(st.Npc) == "string" and st.Npc ~= "" then return npcEntry(st, myZone, pos) end
		return nil
	end
	local guide = st.Guide
	if type(guide) ~= "string" or guide == "" then return nil end
	local zone = guideZone(guide, faction)
	local t = QuestTarget.Story(guide, myZone, pos, faction)
	if t == nil then return nil end
	local walk = landmarkSpot(guide) ~= nil and K.SmithWalk[myZone] == true and K.SmithWalk[zone] == true
	local travel = (myZone ~= zone and not walk) or zone == K.Pumpkin.Zone or zone == K.Hollow.Zone
	local r = pack(t, "story:" .. guide, storyLabel(guide, zone), zone, travel)
	local obj = stepObj(st, faction)
	-- A23-222 (dev2-first12 M1_2): in the King's own zone the mark over the King's hill / the rematch spot says the King,
	-- not the zone I already stand in
	if r and not travel and type(obj) == "table" and (obj.Name == "FirstKO" or obj.Kind == "SlimeKing") then r.Label = TXT.King or r.Label end
	if not r or travel or not pos then return r end
	-- a Near step (pond slimes, the fountain) already happens inside its radius
	local radius = type(obj) == "table" and num(obj.Radius, nil) or nil
	if radius and flatDist(pos, r.Position) <= radius * K.NearShare then return nil end
	return r
end

-- the next-goal row that sends me to the anvil to BUY the iron weapon (HUD L.PinnedTap too). A23-127 (plan 10/13 §1-A #2):
-- never while the Forge sells no weapon (Config.WeaponShop.Buy = false: the "IronDrop" row leads to the meadow's King
-- Slime like a level goal); the server's GoalKind (A23-48) decides, the text search only for a row without one
function QuestTarget.IronGold(entry, level)
	if type(entry) ~= "table" or entry.NextGoal ~= true then return false end
	if type(Config.WeaponShop) == "table" and Config.WeaponShop.Buy == false then return false end
	if type(entry.GoalKind) == "string" then return entry.GoalKind == "IronGold" end
	local weapons = type(Config.Weapons) == "table" and Config.Weapons or {}
	local iron = weapons[K.IronTier]
	local text = type(entry.Text) == "string" and entry.Text or ""
	-- the Korean word or, since A23-48, "gold"
	return type(iron) == "table" and num(level, 1) >= num(iron.MinLevel, math.huge)
		and (string.find(text, "골드", 1, true) ~= nil or string.find(string.lower(text), "gold", 1, true) ~= nil)
end

-- A23-193: my side's skill teacher (SkillTeacher = its NpcId; the StoryNpc-tagged body) -> the body, its zone; nil = none
function QuestTarget.Teacher()
	local id = attr("SkillTeacher", "")
	if type(id) ~= "string" or id == "" then return nil, nil end
	local tag = type(STORY.NpcTag) == "string" and STORY.NpcTag or "StoryNpc"
	for _, m in CollectionService:GetTagged(tag) do
		if m:IsA("Model") and m:GetAttribute("NpcId") == id then
			local part = resolvePart(m)
			local z = part and type(Config.ZoneAt) == "function" and Config.ZoneAt(part.Position) or nil
			return m, type(z) == "table" and z.Id or nil
		end
	end
	return nil, nil
end

-- the row is done and waits for [Claim] (HUD refreshQuests canClaim)
local function claimable(entry)
	return entry.CanClaim == true and num(entry.Progress, 0) >= num(entry.Target, 1)
		and (entry.Pinned == true or entry.Kind == "Daily" or entry.Kind == "Sub")
end

-- the pinned / next-goal / story row's place (L.PinnedTap + refreshGuides), nil where nothing points anywhere:
-- step 0 (the guide talk), a talk / choice step, daily rows, or when I already stand where it happens
-- (the gold goal row = QuestTarget.IronGold, below)
local function placeFor(entry, myZone, faction, pos)
	if type(entry.Story) == "table" then return storyEntry(entry.Story, myZone, faction, pos) end
	if entry.Pinned ~= true then return nil end
	local step = num(entry.TutorialStep, -1)
	-- A23-221 ① (dev2-first12): the practice step -> its dummy (StoryNpcs draws it at the GuideSpot; a trip to its zone
	-- from elsewhere); the mark stands over the dummy's head
	if entry.Practice == true and type(entry.GuideSpot) == "string" then
		local spot = QuestTarget.StorySpot(entry.GuideSpot)
		if spot then
			local z = type(Config.ZoneAt) == "function" and Config.ZoneAt(spot) or nil
			local zone = type(z) == "table" and z.Id or myZone
			if zone == myZone then return pack(spot + K.DummyLift, "dummy:" .. entry.GuideSpot, TXT.Dummy or "Dummy", zone, false) end
			return pack(QuestTarget.Travel(zone, myZone, pos), "zone:" .. tostring(zone), zoneName(zone), zone, true)
		end
	end
	-- quest P1 ②: the first mission's guide / teacher with a body (GuideNpc) -> that NPC (a trip to its zone from elsewhere)
	if type(entry.GuideNpc) == "string" and entry.GuideNpc ~= "" then
		local body = QuestTarget.StoryNpc(entry.GuideNpc)
		local z = body and type(Config.ZoneAt) == "function" and Config.ZoneAt(body.Position) or nil
		local zone = type(z) == "table" and z.Id or nil
		local name = type(STORY.Speakers) == "table" and STORY.Speakers[entry.GuideNpc] or entry.GuideNpc
		if body and zone == myZone then return pack(body, "npc:" .. entry.GuideNpc, tostring(name), zone, false) end
		if body and zone then return pack(QuestTarget.Travel(zone, myZone, pos), "zone:" .. zone, zoneName(zone), zone, true) end
	end
	-- A23-74 weapon first: the Forge step points at the anvil (the Crossroads from elsewhere), whatever
	-- BlacksmithVisited says (an early visit before [Accept] already set it)
	if step == K.ForgeStep then
		return pack(smithFrom(myZone, pos), "blacksmith", TXT.Blacksmith, K.Town, not smithWalk(myZone))
	end
	if step == K.GuideStep or step == K.QuestStep then
		if not needsMeadow(step, entry) or myZone == K.GuideZone then return nil end
		return pack(QuestTarget.Travel(K.GuideZone, myZone, pos), "tutorial", zoneName(K.GuideZone), K.GuideZone, true)
	end
	if step ~= K.DoneStep then return nil end
	-- A23-193: "Learn a skill: meet <teacher>" (GoalKind SkillLearn) -> the teacher (a trip to its town from elsewhere)
	if entry.NextGoal == true and (entry.GoalKind == "SkillLearn" or entry.GoalKind == "SkillTest") then -- P1 ⑤: the test too
		local body, zone = QuestTarget.Teacher()
		zone = zone or (type(Config.HomeZoneId) == "function" and Config.HomeZoneId(faction)) or K.Town
		local name = type(Config.SkillTeacherName) == "function" and Config.SkillTeacherName(faction) or ""
		if body and myZone == zone then return pack(body, "teacher", name, zone, false) end
		if myZone == zone then return nil end
		return pack(QuestTarget.Travel(zone, myZone, pos), "zone:" .. tostring(zone), zoneName(zone), zone, true)
	end
	-- step 99: the blacksmith visit and the iron-weapon gold goal go to the anvil (L.PinnedTap -> doUpgrade)
	local level = math.floor(num(attr("Level", 1), 1))
	if entry.NextGoal ~= true or QuestTarget.IronGold(entry, level) then
		if entry.NextGoal ~= true and attr("BlacksmithVisited", false) == true then return nil end
		return pack(smithFrom(myZone, pos), "blacksmith", TXT.Blacksmith, K.Town, not smithWalk(myZone))
	end
	-- level goals: the zone I level up in (QuestZoneForLevel = the meadow below Lv10, like L.PinnedTap); A23-127: the
	-- "IronDrop" goal = the King Slime's meadow whatever my level (게임성 개발 2: Return.GoalZones.IronDrop the same)
	local zone = type(Config.QuestZoneForLevel) == "function" and Config.QuestZoneForLevel(level) or K.GuideZone
	if entry.GoalKind == "IronDrop" then zone = K.GuideZone end
	if myZone == zone then return nil end
	return pack(QuestTarget.Travel(zone, myZone, pos), "zone:" .. tostring(zone), zoneName(zone), zone, true)
end

function QuestTarget.ForEntry(entry, myZone, faction, pos)
	if type(entry) ~= "table" then return nil end
	if type(myZone) ~= "string" then myZone = attr("ZoneId", "") end
	if type(faction) ~= "string" or faction == "" then faction = myFaction() end
	local r = placeFor(entry, myZone, faction, pos or myPos())
	if r then r.Claim = claimable(entry) end
	return r
end

----------------------------------------------------------------- lifecycle (nothing to set up)
function QuestTarget.Init(registry) -- the registry only gives gooseTarget the EggFx module (A23-141)
	QuestTarget.Reg = registry
end

function QuestTarget.Start() end

return QuestTarget
