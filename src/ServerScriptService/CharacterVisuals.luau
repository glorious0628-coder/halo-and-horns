-- CharacterVisuals.luau : server-built character decorations. Nametag, faction mark (halo / horns / neutral gear), class weapon,
-- gold sack, grudge sack + ghost, rebirth aura, turncoat marks (cape / cracked halo / gray aura), wanted glow and
-- kaiju fire. Every piece is rebuilt on CharacterSpawned and when its watched attributes change.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local CharacterVisuals = {}

------------------------------------------------------------------ constants
local TAG = "CharacterVisuals"
local V = Config.Visuals

local NEUTRAL_ID = "Neutral"
-- CR-L44: "⚙" renders as a tofu box; a missing / empty / unsafe emblem falls back to "장"
local NEUTRAL_EMBLEM = (Config.Factions.Neutral and Config.Factions.Neutral.Emblem) or "장"
if type(NEUTRAL_EMBLEM) ~= "string" or NEUTRAL_EMBLEM == ""
	or (type(Util.GlyphSafe) == "function" and not Util.GlyphSafe(NEUTRAL_EMBLEM)) then
	NEUTRAL_EMBLEM = "장"
end
local MIN_TEXT_SIZE = (Config.UI and Config.UI.MinTextSize) or 11

local WOOD_COLOR = Color3.fromRGB(120, 85, 50)
local DARK_METAL = Color3.fromRGB(60, 60, 70)
local SACK_COLOR = Color3.fromRGB(150, 105, 55)
local SACK_KNOT_COLOR = Color3.fromRGB(110, 75, 40)
local GOLD_SPARK = Color3.fromRGB(255, 210, 60)
local GLOW_FILL = Color3.fromRGB(255, 40, 40)
local GLOW_OUTLINE = Color3.fromRGB(255, 0, 0)
local KAIJU_LIGHT = Color3.fromRGB(255, 60, 30)
local LINE2_COLOR = Color3.fromRGB(235, 235, 240)
local LINE3_COLOR = Color3.fromRGB(255, 70, 70)
local GHOST_TEXT = Color3.fromRGB(220, 170, 255)

local REFRESH_DEBOUNCE = 0.25

-- build order for a full refresh
local PIECE_ORDER = {
	"Nametag", "FactionMark", "WeaponModel", "GoldSack", "GrudgeSack", "GrudgeGhost",
	"RebirthAura", "MarkCape", "MarkHalo", "GrayAura", "WantedGlow", "KaijuFire",
}

-- attribute -> pieces to rebuild ("NametagOffset" = only move the nametag)
local WATCH = {
	Level = { "Nametag", "GoldSack", "GrudgeSack" },
	Class = { "Nametag", "WeaponModel" },
	Faction = { "Nametag", "FactionMark", "WeaponModel", "RebirthAura" },
	Honor = { "Nametag", "FactionMark" },
	Infamy = { "Nametag", "FactionMark" },
	Rebirths = { "Nametag", "RebirthAura" },
	WantedStars = { "Nametag", "WantedGlow" },
	Bounty = { "Nametag" },
	Rookie = { "Nametag" },
	BullyStacks = { "Nametag" },
	SessionTitle = { "Nametag" },
	Nickname = { "Nametag" },
	NicknameVerified = { "Nametag" },
	FallMarks = { "Nametag", "MarkCape", "GrayAura" },
	RedeemMarks = { "Nametag", "MarkHalo", "GrayAura" },
	VisualScale = { "NametagOffset" },
	WeaponTier = { "WeaponModel" },
	CarriedGold = { "GoldSack" },
	SackGold = { "GrudgeSack", "GrudgeGhost" },
	SackVictimName = { "GrudgeGhost" },
	KaijuState = { "WantedGlow", "KaijuFire" },
}

-- body parts whose replacement (e.g. R15 appearance loading) requires a rebuild
local BODY_PARTS = {
	Head = true, RightHand = true, ["Right Arm"] = true, LeftHand = true, ["Left Arm"] = true,
	UpperTorso = true, Torso = true, HumanoidRootPart = true,
}

------------------------------------------------------------------ state
local S = nil
local states = {} -- [Player] = { Conns, CharConns, Dirty, Queued, RefreshQueued }
local builtTier = setmetatable({}, { __mode = "k" }) -- [sack Model] = tier it was built for
local lastWarn = {}

------------------------------------------------------------------ helpers
local function warnThrottled(key, msg)
	local now = os.clock()
	local last = lastWarn[key]
	if last and now - last < 10 then return end
	lastWarn[key] = now
	Util.Warn(TAG, tostring(msg))
end

local function attrNum(player, name, default)
	local v = player:GetAttribute(name)
	if type(v) == "number" and v == v then return v end
	return default or 0
end

local function attrStr(player, name, default)
	local v = player:GetAttribute(name)
	if type(v) == "string" then return v end
	return default
end

local function getFaction(player)
	return attrStr(player, "Faction", "None")
end

local function getClass(player)
	local c = attrStr(player, "Class", "Warrior")
	if Config.Classes[c] then return c end
	return "Warrior"
end

-- A9-1: every faction colour (Neutral teal included) comes from Config, never a local constant
local function factionColor(f)
	local def = Config.Factions[f] or Config.Factions.None
	return (def and def.Color) or Color3.new(1, 1, 1)
end

local function charScale(character)
	local ok, sc = pcall(character.GetScale, character)
	if ok and type(sc) == "number" and sc > 0 then return sc end
	return 1
end

local function getRoot(character)
	local r = character:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then return r end
	return nil
end

local function clearChild(parent, name)
	if not parent then return end
	local old = parent:FindFirstChild(name)
	while old do
		old:Destroy()
		old = parent:FindFirstChild(name)
	end
end

local function esc(s)
	s = tostring(s)
	s = string.gsub(s, "&", "&amp;")
	s = string.gsub(s, "<", "&lt;")
	s = string.gsub(s, ">", "&gt;")
	s = string.gsub(s, "\"", "&quot;")
	s = string.gsub(s, "'", "&apos;")
	return s
end

-- accessory part: unanchored, massless, no collision / query / touch
local function accPart(props)
	local p = Instance.new(props.ClassName or "Part")
	if props.Shape then p.Shape = props.Shape end
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "ClassName" and k ~= "Parent" and k ~= "Shape" then
			p[k] = v
		end
	end
	return p
end

-- parents the piece model to the character, then welds every part to `base` at its current offset
local function mount(model, parts, character, base)
	for _, p in parts do
		p.Parent = model
	end
	model.Parent = character
	for _, p in parts do
		Util.Weld(base, p)
	end
end

local function newPiece(name)
	local m = Instance.new("Model")
	m.Name = name
	return m
end

local function addLight(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

local function sparkle(parent, color, rate, size)
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color)
	pe.Rate = rate
	pe.Lifetime = NumberRange.new(0.6, 1.0)
	pe.Speed = NumberRange.new(0.5, 2)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.LightEmission = 0.8
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	pe.Parent = parent
	return pe
end

------------------------------------------------------------------ Nametag
local function makeLine(name, order, height, maxSize, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, height)
	l.Font = Enum.Font.GothamBold
	l.RichText = true
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.35
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.Text = ""
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.MinTextSize = MIN_TEXT_SIZE
	c.Parent = l
	return l
end

local function nametagOffset(player)
	return Vector3.new(0, 2.6 * attrNum(player, "VisualScale", 1), 0)
end

local function createNametag(player)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Nametag"
	bb.Size = UDim2.fromOffset(240, 80)
	bb.StudsOffset = nametagOffset(player)
	bb.MaxDistance = V.NametagMaxDistance
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = bb

	makeLine("Line1", 1, 30, 22, Color3.new(1, 1, 1)).Parent = bb
	makeLine("Line2", 2, 24, 17, LINE2_COLOR).Parent = bb
	makeLine("Line3", 3, 24, 17, LINE3_COLOR).Parent = bb
	return bb
end

local function updateNametag(player, bb)
	local f = getFaction(player)
	local classId = getClass(player)
	local level = math.floor(attrNum(player, "Level", 1))
	local rebirths = math.floor(attrNum(player, "Rebirths", 0))

	local title = Config.DisplayTitle(
		f,
		attrNum(player, "Honor", 0),
		attrNum(player, "Infamy", 0),
		attrNum(player, "FallMarks", 0),
		attrNum(player, "RedeemMarks", 0),
		attrStr(player, "SessionTitle", "")
	)
	local line1 = "[" .. tostring(title) .. "] " .. Util.PlayerDisplayName(player)
	if f == NEUTRAL_ID then
		line1 = NEUTRAL_EMBLEM .. " " .. line1
	end

	local line2 = "Lv " .. level .. " · " .. Config.ClassName(classId, f)
	if rebirths > 0 then
		line2 ..= "  환생 " .. rebirths
	end
	if player:GetAttribute("Rookie") == true and f ~= NEUTRAL_ID then
		line2 ..= "  새싹 보호"
	end

	local bits = {}
	local bully = math.floor(attrNum(player, "BullyStacks", 0))
	if bully > 0 then
		table.insert(bits, bully > 1 and ("깡패 ×" .. bully) or "깡패")
	end
	local bounty = attrNum(player, "Bounty", 0)
	if bounty > 0 then
		local stars = math.clamp(math.floor(attrNum(player, "WantedStars", 0)), 0, Config.PvP.MaxStars)
		local starText = string.rep("★", stars)
		local b = "현상금 " .. Util.FormatNumber(bounty)
		table.insert(bits, starText ~= "" and (starText .. " " .. b) or b)
	end
	local line3 = table.concat(bits, "  ")

	local l1 = bb:FindFirstChild("Line1")
	local l2 = bb:FindFirstChild("Line2")
	local l3 = bb:FindFirstChild("Line3")
	if l1 then
		l1.Text = esc(line1)
		l1.TextColor3 = factionColor(f)
	end
	if l2 then
		l2.Text = esc(line2)
	end
	if l3 then
		l3.Text = esc(line3)
		l3.Visible = line3 ~= ""
	end
	bb.StudsOffset = nametagOffset(player)
end

local function buildNametag(player, character, force)
	local head = Util.FindPart(character, "Head")
	if not head then return end
	local bb = head:FindFirstChild("Nametag")
	if force or not (bb and bb:IsA("BillboardGui")) then
		clearChild(head, "Nametag")
		bb = createNametag(player)
		bb.Parent = head
	end
	updateNametag(player, bb)
end

local function updateNametagOffset(player, character)
	local head = Util.FindPart(character, "Head")
	local bb = head and head:FindFirstChild("Nametag")
	if bb and bb:IsA("BillboardGui") then
		bb.StudsOffset = nametagOffset(player)
	end
end

------------------------------------------------------------------ FactionMark (halo disc / horns / neutral gear)
-- A9-1 Neutral: a teal Neon gear 1.6 studs above the head = one thin Cylinder + two crossed Blocks (3 parts), fixed
-- size (does not grow with rank). It stands upright (faces front/back), so at a distance it reads differently from
-- the flat Halo disc, the Horns wedges and the bare None head.
local function buildNeutralGear(head, sc)
	local color = factionColor(NEUTRAL_ID)
	local base = head.CFrame * CFrame.new(0, 1.6 * sc, 0)
	local parts = {
		accPart({
			Name = "GearDisc",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.18, 1.1, 1.1) * sc,
			Material = Enum.Material.Neon,
			Color = color,
			CFrame = base * CFrame.Angles(0, math.pi / 2, 0), -- cylinder axis along the head's look direction
		}),
	}
	for k = 0, 1 do
		table.insert(parts, accPart({
			Name = "GearTeeth" .. (k + 1),
			Size = Vector3.new(1.5, 0.34, 0.14) * sc, -- sticks 0.2 out of the disc rim on both ends = 4 teeth
			Material = Enum.Material.Neon,
			Color = color,
			CFrame = base * CFrame.Angles(0, 0, math.rad(45 + 90 * k)),
		}))
	end
	return parts
end

local function buildFactionMark(player, character)
	clearChild(character, "FactionMark")
	local f = getFaction(player)
	if f ~= "Halo" and f ~= "Horns" and f ~= NEUTRAL_ID then return end -- None: nothing
	local head = Util.FindPart(character, "Head")
	if not head then return end
	local sc = charScale(character)
	if f == NEUTRAL_ID then
		mount(newPiece("FactionMark"), buildNeutralGear(head, sc), character, head)
		return
	end
	local _, rank = Config.GetTitle(f, attrNum(player, "Honor", 0), attrNum(player, "Infamy", 0))
	local scale = 1 + V.MarkScalePerRank * (math.max(1, rank or 1) - 1)

	local model = newPiece("FactionMark")
	local parts = {}
	if f == "Halo" then
		local disc = accPart({
			Name = "HaloDisc",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.15, 2.2 * scale, 2.2 * scale) * sc,
			Material = Enum.Material.Neon,
			Color = Config.Factions.Halo.Color,
			CFrame = head.CFrame * CFrame.new(0, 1.6 * sc, 0) * CFrame.Angles(0, 0, math.pi / 2), -- lying flat
		})
		addLight(disc, Config.Factions.Halo.Color, 8 * sc, 1.2)
		table.insert(parts, disc)
	else
		local h = 1.0 * scale * sc
		for side = -1, 1, 2 do
			local horn = accPart({
				ClassName = "WedgePart",
				Name = side < 0 and "HornL" or "HornR",
				Size = Vector3.new(0.4, 1.0 * scale, 0.6 * scale) * sc,
				Material = Enum.Material.Neon,
				Color = Config.Factions.Horns.Color,
				CFrame = head.CFrame
					* CFrame.new(side * head.Size.X * 0.32, head.Size.Y / 2 + h * 0.4, 0)
					* CFrame.Angles(0, 0, -side * math.rad(25)), -- tilted outward
			})
			table.insert(parts, horn)
		end
	end
	mount(model, parts, character, head)
end

------------------------------------------------------------------ WeaponModel
local function gripCFrame(hand, left)
	local att = hand:FindFirstChild(left and "LeftGripAttachment" or "RightGripAttachment")
	local pos
	if att and att:IsA("Attachment") then
		pos = att.WorldPosition
	else
		pos = (hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, 0)).Position
	end
	local rotation = hand.CFrame.Rotation
	-- Imported costume geometry can carry a verified axis bake (pilot Y180). Its wrist attachment
	-- restores the original bone frame; using the mesh's raw rotation turns the held weapon around.
	-- Personal avatar grips retain their existing frame.
	if hand:GetAttribute("HHC_SourcePart") == hand.Name then
		local wrist = hand:FindFirstChild(left and "LeftWristRigAttachment" or "RightWristRigAttachment")
		if wrist and wrist:IsA("Attachment") then rotation *= wrist.CFrame.Rotation end
	end
	return CFrame.new(pos) * rotation
end

local function buildSword(grip, sc, w, color)
	local L = grip * CFrame.Angles(-math.pi / 2, 0, 0) -- +Y of L points forward
	local handleLen = 1.2
	local handle = accPart({
		Name = "Handle", Size = Vector3.new(0.3, handleLen, 0.3) * sc,
		Material = Enum.Material.Wood, Color = WOOD_COLOR, CFrame = L,
	})
	local guard = accPart({
		Name = "Guard", Size = Vector3.new(1.2, 0.25, 0.4) * sc,
		Material = Enum.Material.Metal, Color = DARK_METAL,
		CFrame = L * CFrame.new(0, (handleLen / 2 + 0.125) * sc, 0),
	})
	local blade = accPart({
		Name = "Blade", Size = Vector3.new(0.25, w.Length, 0.6) * sc,
		Material = w.Material, Color = color,
		CFrame = L * CFrame.new(0, (handleLen / 2 + 0.25 + w.Length / 2) * sc, 0),
	})
	return { handle, guard, blade }, blade
end

local function buildStaff(grip, sc, w, color, tier)
	local shaftLen = w.Length + 1.5
	local base = grip -- the shaft centreline must pass through the actual hand grip
	local shaft = accPart({
		Name = "Shaft", Size = Vector3.new(0.3, shaftLen, 0.3) * sc,
		Material = Enum.Material.Wood, Color = WOOD_COLOR,
		CFrame = base * CFrame.new(0, (shaftLen / 2 - 1.0) * sc, 0),
	})
	local collar = accPart({
		Name = "Collar", Size = Vector3.new(0.45, 0.3, 0.45) * sc,
		Material = w.Material, Color = color,
		CFrame = base * CFrame.new(0, (shaftLen - 1.05) * sc, 0),
	})
	local d = 0.7 + 0.1 * tier
	local tip = accPart({
		Name = "Tip", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d) * sc,
		Material = Enum.Material.Neon, Color = color,
		CFrame = base * CFrame.new(0, (shaftLen - 1.0 + d * 0.35) * sc, 0),
	})
	addLight(tip, color, 8 * sc, 1.5)
	return { shaft, collar, tip }, tip
end

local function buildBow(grip, sc, w, color)
	local H = w.Length
	local half = math.rad(50)
	local R = H / (2 * math.sin(half))
	local sag = R * (1 - math.cos(half))
	-- The centre/grip stays in the hand at every tier; lifting a long bow moved its arrow rest
	-- above the grip, so no arm pose could align the string hand, face and launch axis together.
	local base = grip * CFrame.new(0, 0, -0.1 * sc)
	local segLen = math.max(0.9, 2 * R * math.sin(math.rad(10)) * 1.08)
	local parts = {}
	local main
	for k = 1, 5 do
		local phi = -half + (k - 0.5) * (2 * half / 5)
		local local3 = Vector3.new(0, R * math.sin(phi), -(R * math.cos(phi) - R * math.cos(half)) + sag)
		local seg = accPart({
			Name = "Arc" .. k, Size = Vector3.new(0.2, segLen, 0.2) * sc,
			Material = w.Material, Color = color,
			CFrame = base * CFrame.new(local3 * sc) * CFrame.Angles(phi, 0, 0),
		})
		table.insert(parts, seg)
		if k == 3 then main = seg end
	end
	local string_ = accPart({
		Name = "String", Size = Vector3.new(0.05, H, 0.05) * sc,
		Color = Color3.new(1, 1, 1),
		Transparency = 1, -- two strings share a movable nock for the right-hand draw
		CFrame = base * CFrame.new(0, 0, sag * sc),
	})
	table.insert(parts, string_)
	for _, spec in { { "BowTop", H / 2 }, { "BowBottom", -H / 2 }, { "BowNock", 0 } } do
		local att = Instance.new("Attachment")
		att.Name = spec[1]
		att.Position = Vector3.new(0, spec[2] * sc, 0)
		att.Parent = string_
	end
	for _, name in { "BowTop", "BowBottom" } do
		local beam = Instance.new("Beam")
		beam.Name = name .. "String"
		beam.Attachment0 = string_:FindFirstChild(name)
		beam.Attachment1 = string_:FindFirstChild("BowNock")
		beam.Width0 = 0.05 * sc
		beam.Width1 = 0.05 * sc
		beam.Color = ColorSequence.new(string_.Color)
		beam.FaceCamera = true
		beam.Parent = string_
	end
	return parts, main
end

local function buildWeapon(player, character)
	clearChild(character, "WeaponModel")
	local classId = getClass(player)
	local classDef = Config.Classes[classId] or Config.Classes.Warrior
	local left = classDef.Weapon == "Bow"
	local hand = left and Util.FindPart(character, "LeftHand", "Left Arm")
		or (not left and Util.FindPart(character, "RightHand", "Right Arm"))
	if not hand then return end
	local sc = charScale(character)
	local tier = math.clamp(math.floor(attrNum(player, "WeaponTier", 1)), 1, Config.MaxWeaponTier)
	local w = Config.Weapons[tier]
	local f = getFaction(player)
	local color = Config.WeaponColor(tier, f)
	local grip = gripCFrame(hand, left)

	local parts, main
	if classDef.Weapon == "Staff" then
		parts, main = buildStaff(grip, sc, w, color, tier)
	elseif classDef.Weapon == "Bow" then
		parts, main = buildBow(grip, sc, w, color)
	else
		parts, main = buildSword(grip, sc, w, color)
	end

	if tier >= 6 and main then
		local existing = main:FindFirstChildOfClass("PointLight")
		if existing then
			existing.Brightness = 2.5
			existing.Range = 12 * sc
		else
			addLight(main, color, 10 * sc, 2)
		end
	end
	if tier >= 7 and main then
		sparkle(main, color, 12, 0.35 * sc)
	end

	local model = newPiece("WeaponModel")
	model:SetAttribute("Class", classId)
	model:SetAttribute("GripHand", hand.Name)
	if main then
		local muzzle = Instance.new("Attachment")
		muzzle.Name = "AttackMuzzle"
		if classDef.Weapon == "Bow" then
			muzzle.Position = Vector3.new(0, 0, -0.18 * sc)
		elseif classDef.Weapon == "Staff" then
			muzzle.Position = Vector3.new(0, main.Size.Y * 0.5, 0)
		else
			muzzle.Position = Vector3.new(0, main.Size.Y * 0.5, 0)
		end
		muzzle.Parent = main
		-- Server-built attachment offsets survive both joint types and avoid reading a one-frame-old
		-- hand/weapon pair while their Transform batch is still waiting for the physics step.
		model:SetAttribute("HandMuzzle", hand.CFrame:ToObjectSpace(main.CFrame * muzzle.CFrame))
		if classDef.Weapon == "Bow" then
			for _, part in parts do
				local nock = part:FindFirstChild("BowNock")
				if nock then model:SetAttribute("HandBowRest", hand.CFrame:ToObjectSpace(part.CFrame * nock.CFrame)) end
			end
		end
	end
	mount(model, parts, character, hand)
end

------------------------------------------------------------------ sacks & ghost
local function sackSize(tier)
	local sizes = V.SackSizes
	return sizes[math.clamp(tier, 1, #sizes)]
end

local function buildGoldSack(player, character, force)
	local tier = Config.SackTier(attrNum(player, "CarriedGold", 0), attrNum(player, "Level", 1))
	local existing = character:FindFirstChild("GoldSack")
	if not force then
		if existing and builtTier[existing] == tier then return end
		if not existing and tier <= 0 then return end
	end
	clearChild(character, "GoldSack")
	if tier <= 0 then return end
	local torso = Util.FindPart(character, "UpperTorso", "Torso")
	if not torso then return end
	local sc = charScale(character)
	local d = sackSize(tier) * sc
	local ball = accPart({
		Name = "Sack", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d),
		Material = Enum.Material.Fabric, Color = SACK_COLOR,
		CFrame = torso.CFrame * CFrame.new(0, 0.15 * sc, torso.Size.Z / 2 + d * 0.42),
	})
	local k = d * 0.35
	local knot = accPart({
		Name = "Knot", Shape = Enum.PartType.Ball, Size = Vector3.new(k, k, k),
		Material = Enum.Material.Fabric, Color = SACK_KNOT_COLOR,
		CFrame = ball.CFrame * CFrame.new(0, d * 0.48, 0),
	})
	if tier >= 4 then
		sparkle(ball, GOLD_SPARK, 6, 0.3 * sc)
	end
	local model = newPiece("GoldSack")
	mount(model, { ball, knot }, character, torso)
	builtTier[model] = tier
end

local function buildGrudgeSack(player, character, force)
	local sackGold = attrNum(player, "SackGold", 0)
	local tier = 0
	if sackGold > 0 then
		tier = math.max(1, Config.SackTier(sackGold, attrNum(player, "Level", 1)))
	end
	local existing = character:FindFirstChild("GrudgeSack")
	if not force then
		if existing and builtTier[existing] == tier then return end
		if not existing and tier <= 0 then return end
	end
	clearChild(character, "GrudgeSack")
	if tier <= 0 then return end
	local torso = Util.FindPart(character, "UpperTorso", "Torso")
	if not torso then return end
	local sc = charScale(character)
	local d = sackSize(tier) * sc
	local ball = accPart({
		Name = "Sack", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d),
		Material = Enum.Material.Fabric, Color = V.GrudgeSackColor,
		CFrame = torso.CFrame * CFrame.new(0, -(0.6 * sc + d * 0.3), torso.Size.Z / 2 + d * 0.42),
	})
	sparkle(ball, V.GrudgeSackColor:Lerp(Color3.new(1, 1, 1), 0.25), 8, 0.35 * sc)
	local model = newPiece("GrudgeSack")
	mount(model, { ball }, character, torso)
	builtTier[model] = tier
end

local function buildGrudgeGhost(player, character)
	clearChild(character, "GrudgeGhost")
	if attrNum(player, "SackGold", 0) <= 0 then return end
	local head = Util.FindPart(character, "Head")
	if not head then return end
	local sc = charScale(character)
	local base = head.CFrame * CFrame.new(0, V.GhostHeight * sc, 0)
	local body = accPart({
		Name = "GhostBody", Size = Vector3.new(1.6, 2, 0.8) * sc,
		Material = Enum.Material.Neon, Color = V.GhostColor, Transparency = V.GhostTransparency,
		CFrame = base,
	})
	local ghostHead = accPart({
		Name = "GhostHead", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2) * sc,
		Material = Enum.Material.Neon, Color = V.GhostColor, Transparency = V.GhostTransparency,
		CFrame = base * CFrame.new(0, 1.6 * sc, 0),
	})

	local victim = attrStr(player, "SackVictimName", "")
	if victim == "" then victim = "누군가" end
	local bb = Instance.new("BillboardGui")
	bb.Name = "GhostLabel"
	bb.Size = UDim2.fromOffset(200, 28)
	bb.StudsOffset = Vector3.new(0, 1.3 * sc, 0)
	bb.MaxDistance = V.NametagMaxDistance
	bb.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = GHOST_TEXT
	label.TextStrokeTransparency = 0.3
	label.Text = victim .. "의 원한"
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 18
	c.MinTextSize = MIN_TEXT_SIZE
	c.Parent = label
	label.Parent = bb
	bb.Parent = ghostHead

	mount(newPiece("GrudgeGhost"), { body, ghostHead }, character, head)
end

------------------------------------------------------------------ auras & marks
local function auraEmitter(name, color, rate, lifetime, sc)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = name
	pe.Color = ColorSequence.new(color)
	pe.Rate = rate
	pe.Lifetime = NumberRange.new(lifetime)
	pe.LightEmission = 0.6
	pe.Speed = NumberRange.new(0.5, 1.5)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Acceleration = Vector3.new(0, 2, 0)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * sc), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	return pe
end

local function buildRebirthAura(player, character)
	local root = getRoot(character)
	if not root then return end
	clearChild(root, "RebirthAura")
	local rebirths = attrNum(player, "Rebirths", 0)
	if rebirths < 1 then return end
	local color, bestMin, found = nil, -math.huge, false
	for _, a in Config.Rebirth.Auras do
		if rebirths >= a.Min and a.Min >= bestMin then
			bestMin = a.Min
			color = a.Color
			found = true
		end
	end
	if not found then return end
	if color == nil then color = factionColor(getFaction(player)) end
	auraEmitter("RebirthAura", color, 6, 1.2, charScale(character)).Parent = root
end

local function buildMarkCape(player, character)
	clearChild(character, "MarkCape")
	if attrNum(player, "FallMarks", 0) < 1 then return end
	local torso = Util.FindPart(character, "UpperTorso", "Torso")
	if not torso then return end
	local sc = charScale(character)
	local top = torso.CFrame * CFrame.new(0, torso.Size.Y / 2 - 0.1 * sc, torso.Size.Z / 2 + 0.08 * sc)
	local lengths = { 2.4, 1.8, 2.7 }
	local xs = { -0.6, 0, 0.6 }
	local parts = {}
	for i = 1, 3 do
		local len = lengths[i] * sc
		local cf = top
			* CFrame.new(xs[i] * sc, 0, 0)
			* CFrame.Angles(-math.rad(6 + i * 2), 0, math.rad((i - 2) * 4))
			* CFrame.new(0, -len / 2, 0)
		table.insert(parts, accPart({
			Name = "CapeStrip" .. i, Size = Vector3.new(0.62 * sc, len, 0.08 * sc),
			Material = Enum.Material.Fabric, Color = V.CapeColor, CFrame = cf,
		}))
	end
	mount(newPiece("MarkCape"), parts, character, torso)
end

local function buildMarkHalo(player, character)
	clearChild(character, "MarkHalo")
	if attrNum(player, "RedeemMarks", 0) < 1 then return end
	local head = Util.FindPart(character, "Head")
	if not head then return end
	local sc = charScale(character)
	local base = head.CFrame * CFrame.new(0, 2.4 * sc, 0)
	local R = 1.0 * sc
	local chord = 2 * R * math.sin(math.rad(35)) -- each segment spans ~70 deg, 20 deg gaps
	local parts = {}
	for k = 0, 3 do
		local theta = math.rad(k * 90 + 45)
		local tilt = (k % 2 == 0) and math.rad(7) or -math.rad(5) -- cracked look
		local cf = base * CFrame.Angles(0, -theta, 0) * CFrame.new(R, 0, 0) * CFrame.Angles(tilt, 0, 0)
		table.insert(parts, accPart({
			Name = "HaloShard" .. (k + 1), Size = Vector3.new(0.22 * sc, 0.14 * sc, chord),
			Material = Enum.Material.Neon, Color = V.CrackedHaloColor, CFrame = cf,
		}))
	end
	mount(newPiece("MarkHalo"), parts, character, head)
end

local function buildGrayAura(player, character)
	local root = getRoot(character)
	if not root then return end
	clearChild(root, "GrayAura")
	local minMarks = Config.Rebirth.GrayLegendMin
	if attrNum(player, "FallMarks", 0) >= minMarks and attrNum(player, "RedeemMarks", 0) >= minMarks then
		auraEmitter("GrayAura", V.GrayAuraColor, 8, 1.5, charScale(character)).Parent = root
	end
end

------------------------------------------------------------------ wanted glow & kaiju fire
local function buildWantedGlow(player, character)
	clearChild(character, "WantedGlow")
	local glow = attrNum(player, "WantedStars", 0) >= Config.PvP.GlowStars
		or attrStr(player, "KaijuState", "None") == "Active"
	if not glow then return end
	local h = Instance.new("Highlight")
	h.Name = "WantedGlow"
	h.FillColor = GLOW_FILL
	h.FillTransparency = 0.6
	h.OutlineColor = GLOW_OUTLINE
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = character
end

local function buildKaijuFire(player, character)
	local root = getRoot(character)
	if not root then return end
	clearChild(root, "KaijuFire")
	if attrStr(player, "KaijuState", "None") ~= "Active" then return end
	local sc = charScale(character)
	local att = Instance.new("Attachment")
	att.Name = "KaijuFire"
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Fire"
	pe.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 70)),
		ColorSequenceKeypoint.new(0.4, V.KaijuFireColor),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 20, 10)),
	})
	pe.Rate = 30
	pe.Lifetime = NumberRange.new(0.5, 1.0)
	pe.Speed = NumberRange.new(3, 6)
	pe.SpreadAngle = Vector2.new(30, 30)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Acceleration = Vector3.new(0, 8, 0)
	pe.LightEmission = 0.9
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.0 * sc), NumberSequenceKeypoint.new(1, 0.3 * sc) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	pe.Parent = att
	addLight(att, KAIJU_LIGHT, 18 * sc, 3)
	att.Parent = root
end

------------------------------------------------------------------ dispatch
local BUILDERS = {
	Nametag = buildNametag,
	FactionMark = buildFactionMark,
	WeaponModel = buildWeapon,
	GoldSack = buildGoldSack,
	GrudgeSack = buildGrudgeSack,
	GrudgeGhost = buildGrudgeGhost,
	RebirthAura = buildRebirthAura,
	MarkCape = buildMarkCape,
	MarkHalo = buildMarkHalo,
	GrayAura = buildGrayAura,
	WantedGlow = buildWantedGlow,
	KaijuFire = buildKaijuFire,
}

local function buildPiece(player, character, piece, force)
	local fn = BUILDERS[piece]
	if not fn then return end
	local ok, err = pcall(fn, player, character, force)
	if not ok then
		warnThrottled(piece, piece .. " build failed for " .. player.Name .. ": " .. tostring(err))
	end
end

local function refreshAll(player)
	local character = Util.GetCharacter(player)
	if not character then return end
	for _, piece in PIECE_ORDER do
		buildPiece(player, character, piece, true)
	end
end

local function ensureState(player)
	local st = states[player]
	if not st then
		st = { Conns = {}, CharConns = {}, Dirty = {}, Queued = false, RefreshQueued = false }
		states[player] = st
	end
	return st
end

local function flush(player)
	local st = states[player]
	if not st then return end
	st.Queued = false
	local dirty = st.Dirty
	st.Dirty = {}
	if player.Parent == nil then return end
	local character = Util.GetCharacter(player)
	if not character then return end
	for _, piece in PIECE_ORDER do
		if dirty[piece] then
			buildPiece(player, character, piece, false)
		end
	end
	if dirty.NametagOffset and not dirty.Nametag then
		local ok, err = pcall(updateNametagOffset, player, character)
		if not ok then warnThrottled("NametagOffset", err) end
	end
end

local function markDirty(player, pieces)
	local st = states[player]
	if not st then return end
	for _, piece in pieces do
		st.Dirty[piece] = true
	end
	if not st.Queued then
		st.Queued = true
		task.defer(flush, player)
	end
end

-- debounced full rebuild (body parts swapped by appearance loading etc.)
local function requestRefresh(player)
	local st = states[player]
	if not st or st.RefreshQueued then return end
	st.RefreshQueued = true
	task.delay(REFRESH_DEBOUNCE, function()
		local cur = states[player]
		if not cur then return end
		cur.RefreshQueued = false
		if player.Parent then refreshAll(player) end
	end)
end

local function disconnectAll(list)
	for _, c in list do
		c:Disconnect()
	end
	table.clear(list)
end

local function onPlayerReady(player)
	local st = ensureState(player)
	disconnectAll(st.Conns)
	for attrName, pieces in WATCH do
		table.insert(st.Conns, player:GetAttributeChangedSignal(attrName):Connect(function()
			markDirty(player, pieces)
		end))
	end
	table.insert(st.Conns, player.CharacterAppearanceLoaded:Connect(function()
		requestRefresh(player)
	end))
end

local function onCharacterSpawned(player, character)
	if not player or player.Parent == nil or not character then return end
	local st = ensureState(player)
	disconnectAll(st.CharConns)
	table.insert(st.CharConns, character.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") and BODY_PARTS[child.Name] then
			requestRefresh(player)
		end
	end))
	refreshAll(player)
end

local function onPlayerLeaving(player)
	local st = states[player]
	if not st then return end
	states[player] = nil
	disconnectAll(st.Conns)
	disconnectAll(st.CharConns)
end

------------------------------------------------------------------ public
function CharacterVisuals.Refresh(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent == nil then return end
	refreshAll(player)
end

function CharacterVisuals.Init(registry)
	S = registry
	local PS = S.PlayerService
	if PS then
		PS.PlayerReady:Connect(function(player)
			onPlayerReady(player)
		end)
		PS.CharacterSpawned:Connect(function(player, character)
			onCharacterSpawned(player, character)
		end)
		PS.PlayerLeaving:Connect(function(player)
			onPlayerLeaving(player)
		end)
	else
		Util.Warn(TAG, "PlayerService missing; visuals disabled")
	end
	Players.PlayerRemoving:Connect(onPlayerLeaving)
end

function CharacterVisuals.Start()
	print("[CharacterVisuals] started")
end

return CharacterVisuals
