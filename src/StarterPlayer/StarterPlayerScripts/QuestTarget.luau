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

local K = {
	GuideZone = TUT.GuideZone or "SlimeMeadow", -- HUD TUT_GUIDE_ZONE
	GuideStep = TUT_STEPS.Guide or 1,
	QuestStep = TUT_STEPS.Quest or 2,
	DoneStep = TUT_STEPS.Done or 99,
	QuestKills = tonumber(TUT.QuestKills) or 5,
	Town = "Crossroads", -- the anvil, the fountain and the goose perch stand here
	IronTier = 3, -- QuestService IRON_TIER (the "next goal" iron weapon)
	AnchorPrefix = "HUDGuideAnchor_", -- HUD localAnchor name
	Lift = Vector3.new(0, 3, 0), -- anchor above a zone spawn (HUD findTravelTarget)
	FountainLift = Vector3.new(0, 4, 0), -- HUD L.StoryTap fountain fallback anchor
	HomeBridge = { HaloTown = "Bridge_Halo", HornsTown = "Bridge_Horns" }, -- HUD HOME_BRIDGE
	PadFrom = { Crossroads = true, HaloTown = true, HornsTown = true }, -- pads first from these (HUD order)
	NearShare = 0.75, -- a Near step's spot counts as reached inside this share of its Radius
	-- the anvil from outside the Crossroads: true = route to the Crossroads (Travel); false = nil like HUD's beam,
	-- which only shows inside the Crossroads (refreshGuides)
	SmithFromAfar = true,
	-- A23-30 PumpkinPatch: = MapBuilder PATCH (PathX 360 +- PassHalfW 9, PassFromZ 126 .. PassToZ 194, SignPos)
	Pumpkin = {
		Zone = "PumpkinPatch",
		Sign = Vector3.new(368, 3, 136), -- the meadow's south-end sign (Map.Landmarks.PumpkinPatchSign)
		SignName = "PumpkinPatchSign",
		Passage = { MinX = 351, MaxX = 369, MinZ = 126, MaxZ = 194 },
		Field = Vector3.new(360, 3, 235), -- used when Config.Zones.PumpkinPatch has no Center
		MeadowLand = "LandMeadow", -- Config.Map.Lands: counts as "in the meadow" even where ZoneId says Outskirts
	},
	-- A23-45 HauntedHollow: = MapBuilder HOLLOW (land x 160..280, z 185..295; WestGateZ 245 on the patch's west edge)
	Hollow = {
		Zone = "HauntedHollow",
		Gate = Vector3.new(280, 3, 245), -- the gap in the patch's west fence
		PatchLand = "LandPumpkinPatch", -- Config.Map.Lands: counts as "in the patch" even where ZoneId says Outskirts
	},
}

-- player-facing labels (A23-48: English only, names from docs/design/glossary_en_2026-10-06.md; zone names come from
-- Config.Zones NameEn when it is there)
local TXT = {
	Blacksmith = "Forge",
	Pond = "Slime Pond",
	Fountain = "Fountain",
	Goose = "Golden Goose Nest",
	PumpkinSign = "To the Pumpkin Patch",
}

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
	local spot = STORY_SPOTS.Fountain
	return typeof(spot) == "Vector3" and (spot + K.FountainLift) or nil
end

-- the goose perch (MapBuilder GoosePerch), else Config.Goose.Position at hover height
local function gooseTarget()
	local perch = resolvePart(mapChild("Landmarks", "GoosePerch"))
	if perch then return perch end
	local goose = type(Config.Goose) == "table" and Config.Goose or {}
	if typeof(goose.Position) ~= "Vector3" then return nil end
	return goose.Position + Vector3.new(0, num(goose.HoverHeight, 4), 0)
end

-- L.StoryTap "SlimePond": Config.StoryQuests.Landmarks.SlimePond (+3) = HUD STORY_SPOT
local function pondSpot()
	local spot = STORY_SPOTS.SlimePond
	return typeof(spot) == "Vector3" and (spot + K.Lift) or Vector3.new(280, 3, -45)
end

-- the zone a story Guide happens in (L.StoryTap's target mapping)
local function guideZone(guide, faction)
	if guide == "OwnTown" then
		return type(Config.HomeZoneId) == "function" and Config.HomeZoneId(faction or myFaction()) or K.Town
	end
	if guide == "SlimePond" then return K.GuideZone end
	if guide == "Fountain" or guide == "Goose" or guide == "Blacksmith" then return K.Town end
	return guide
end

local function smithFrom(fromZone, pos)
	if fromZone == K.Town then return QuestTarget.Blacksmith() end
	if not K.SmithFromAfar then return nil end
	return QuestTarget.Travel(K.Town, fromZone, pos)
end

-- where a story step's Guide points from fromZone: a travel target while I am in another zone, the spot inside it,
-- nil when there is nothing to point at (already in a plain zone guide's zone, unknown guide)
function QuestTarget.Story(guide, fromZone, pos, faction)
	if type(guide) ~= "string" or guide == "" then return nil end
	if type(fromZone) ~= "string" then fromZone = attr("ZoneId", "") end
	if guide == "Blacksmith" then return smithFrom(fromZone, pos) end
	local zone = guideZone(guide, faction)
	if not zoneDef(zone) then return nil end
	if zone == K.Pumpkin.Zone or zone == K.Hollow.Zone or fromZone ~= zone then return QuestTarget.Travel(zone, fromZone, pos) end
	if guide == "SlimePond" then return pondSpot() end
	if guide == "Fountain" then return fountainTarget() end
	if guide == "Goose" then return gooseTarget() end
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

local function storyEntry(st, myZone, faction, pos)
	if st.Panel then return nil end -- a talk / choice card: no place
	local guide = st.Guide
	if type(guide) ~= "string" or guide == "" then return nil end
	local zone = guideZone(guide, faction)
	local t = QuestTarget.Story(guide, myZone, pos, faction)
	if t == nil then return nil end
	local travel = myZone ~= zone or zone == K.Pumpkin.Zone or zone == K.Hollow.Zone
	local r = pack(t, "story:" .. guide, storyLabel(guide, zone), zone, travel)
	if not r or travel or not pos then return r end
	-- a Near step (pond slimes, the fountain) already happens inside its radius
	local obj = stepObj(st, faction)
	local radius = type(obj) == "table" and num(obj.Radius, nil) or nil
	if radius and flatDist(pos, r.Position) <= radius * K.NearShare then return nil end
	return r
end

-- the row is done and waits for [Claim] (HUD refreshQuests canClaim)
local function claimable(entry)
	return entry.CanClaim == true and num(entry.Progress, 0) >= num(entry.Target, 1)
		and (entry.Pinned == true or entry.Kind == "Daily" or entry.Kind == "Sub")
end

-- the pinned / next-goal / story row's place (L.PinnedTap + refreshGuides), nil where nothing points anywhere:
-- step 0 (the guide talk), a talk / choice step, daily rows, or when I already stand where it happens
local function placeFor(entry, myZone, faction, pos)
	if type(entry.Story) == "table" then return storyEntry(entry.Story, myZone, faction, pos) end
	if entry.Pinned ~= true then return nil end
	local step = num(entry.TutorialStep, -1)
	if step == K.GuideStep or step == K.QuestStep then
		if not needsMeadow(step, entry) or myZone == K.GuideZone then return nil end
		return pack(QuestTarget.Travel(K.GuideZone, myZone, pos), "tutorial", zoneName(K.GuideZone), K.GuideZone, true)
	end
	if step ~= K.DoneStep then return nil end
	-- step 99: the blacksmith visit and the iron-weapon gold goal go to the anvil (L.PinnedTap -> doUpgrade)
	local level = math.floor(num(attr("Level", 1), 1))
	local weapons = type(Config.Weapons) == "table" and Config.Weapons or {}
	local iron = weapons[K.IronTier]
	local text = type(entry.Text) == "string" and entry.Text or ""
	-- the gold goal row (HUD L.PinnedTap: the Korean word or, since A23-48, "gold")
	local ironGold = type(iron) == "table" and level >= num(iron.MinLevel, math.huge)
		and (string.find(text, "골드", 1, true) ~= nil or string.find(string.lower(text), "gold", 1, true) ~= nil)
	if entry.NextGoal ~= true or ironGold then
		if entry.NextGoal ~= true and attr("BlacksmithVisited", false) == true then return nil end
		return pack(smithFrom(myZone, pos), "blacksmith", TXT.Blacksmith, K.Town, myZone ~= K.Town)
	end
	-- level goals: the zone I level up in (QuestZoneForLevel = the meadow below Lv10, like L.PinnedTap)
	local zone = type(Config.QuestZoneForLevel) == "function" and Config.QuestZoneForLevel(level) or K.GuideZone
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
function QuestTarget.Init(_registry) end

function QuestTarget.Start() end

return QuestTarget
