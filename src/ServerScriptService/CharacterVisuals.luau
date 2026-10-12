-- CharacterVisuals.luau : server-built character decorations. Nametag, faction mark (halo / horns / neutral gear), class weapon,
-- gold sack, grudge sack + ghost, rebirth aura, turncoat marks (cape / cracked halo / gray aura), wanted glow and
-- kaiju fire. Every piece is rebuilt on CharacterSpawned and when its watched attributes change.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local CharacterVisuals = {}

------------------------------------------------------------------ constants
local TAG = "CharacterVisuals"
local V = Config.Visuals

local NEUTRAL_ID = "Neutral"
-- CR-L44: "⚙" renders as a tofu box; a missing / empty / unsafe emblem falls back to "A"
local NEUTRAL_EMBLEM = (Config.Factions.Neutral and Config.Factions.Neutral.Emblem) or "A"
if type(NEUTRAL_EMBLEM) ~= "string" or NEUTRAL_EMBLEM == ""
	or (type(Util.GlyphSafe) == "function" and not Util.GlyphSafe(NEUTRAL_EMBLEM)) then
	NEUTRAL_EMBLEM = "A"
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
	"RebirthAura", "MarkCape", "MarkHalo", "GrayAura", "WantedGlow", "KaijuFire", "EggStack",
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
	GraduateGraceUntil = { "Nametag" }, -- A23-18: "졸업 유예" while the graduation grace runs
	TitleSel = { "Nametag" }, -- BB16 selected title (e.g. A23-18 "베타 개척자")
	TitlesOwned = { "Nametag" }, -- BB16: the pioneer mark on the second line
	BullyStacks = { "Nametag" },
	Outlaw = { "Nametag" }, -- A23-23 this week's outlaw (RankingService)
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
	SackHeldUntil = { "GrudgeGhost" }, -- A23-18: the ghost glows hard while the victim holds the sack
	KaijuState = { "WantedGlow", "KaijuFire" },
	EggCarry = { "EggStack" }, -- A23-131: the golden eggs carried (GooseEggs)
}

-- A23-75 VIP crown before the name (이미지 개발 2026-10-08). The pass attribute is named by 게임성 개발 2
-- (Config.GamePasses.VIP.Attr, else PassVIP); the crown is Config.UIArt IconVipCrown once drawn, else the approved Crown.
-- The server only adds / removes it (ImageLabel VipCrown + UIPadding VipPad in Line1, hidden); every client sizes and
-- places it from its own TextBounds (ShopUI: the server cannot measure the client's rendered name - UiSandbox
-- 2026-10-08, the estimate put the crown over "[S")
local CROWN = {
	Attr = (type(Config.GamePasses) == "table" and type(Config.GamePasses.VIP) == "table"
		and type(Config.GamePasses.VIP.Attr) == "string" and Config.GamePasses.VIP.Attr) or "PassVIP",
	Art = { "IconVipCrown", "Crown" }, Aspect = 256 / 175,
}
WATCH[CROWN.Attr] = WATCH[CROWN.Attr] or { "Nametag" }
-- A23-75 / A23-77: the worn look recolours the rank mark (Config.LookThemes)
WATCH.LookOn = WATCH.LookOn or { "FactionMark" }

-- body parts whose replacement (e.g. R15 appearance loading) requires a rebuild
local BODY_PARTS = {
	Head = true, RightHand = true, ["Right Arm"] = true, LeftHand = true, ["Left Arm"] = true,
	UpperTorso = true, Torso = true, HumanoidRootPart = true,
}

-- 3rd idea round #6: an accessory on these head slots (or of AccessoryType Hat / Hair) lifts the halo / horns
local MARK_HEAD_SLOTS = { HatAttachment = true, HairAttachment = true }

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
-- UI round 2 #7: the game's fonts (Config.Fonts, A23-63); a font that cannot be made keeps GothamBold
local function tagFont(label, slot)
	label.Font = Enum.Font.GothamBold
	local fonts = Config.Fonts or {}
	local family = fonts[(fonts.Nametag or {})[slot] or "Body"]
	if type(family) ~= "string" then return end
	local ok, face = pcall(function()
		return Font.new(family, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	end)
	if ok and face then label.FontFace = face end
end

local function makeLine(name, order, height, maxSize, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, height)
	tagFont(l, name)
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

-- the crown art id and its size, or nil (no art = no crown, IMG-R4)
function CROWN.Part()
	local parts = type(Config.UIArt) == "table" and Config.UIArt.Parts or nil
	for _, key in CROWN.Art do
		local def = type(parts) == "table" and parts[key] or nil
		if type(def) == "table" and type(def.Id) == "string" and def.Id ~= "" then return def.Id, def.Size end
	end
	return nil
end

-- adds (hidden; the client fits it) or removes the crown in Line1; the art id follows Config, nothing else is rewritten
-- so a client's fit is never undone by a nametag refresh
function CROWN.Place(player, label)
	local crown, pad = label:FindFirstChild("VipCrown"), label:FindFirstChild("VipPad")
	local id, artSize = CROWN.Part()
	if player:GetAttribute(CROWN.Attr) ~= true or not id then
		if crown then crown:Destroy() end
		if pad then pad:Destroy() end
		return
	end
	if not pad then
		pad = Instance.new("UIPadding")
		pad.Name = "VipPad"
		pad.Parent = label
	end
	if not crown then
		crown = Instance.new("ImageLabel")
		crown.Name = "VipCrown"
		crown.BackgroundTransparency = 1
		crown.ScaleType = Enum.ScaleType.Fit
		crown.AnchorPoint = Vector2.new(1, 0.5)
		crown.Position = UDim2.new(0.5, 0, 0.5, -1)
		crown.Visible = false
		crown:SetAttribute("Aspect", typeof(artSize) == "Vector2" and artSize.Y > 0 and artSize.X / artSize.Y or CROWN.Aspect)
		crown.Parent = label
	end
	if crown.Image ~= id then crown.Image = id end
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
	-- user OK 2026-10-06: my own tag covered the middle of small screens; the HUD card shows level / class / status
	bb.PlayerToHideFrom = player

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
		attrStr(player, "SessionTitle", ""),
		attrStr(player, "TitleSel", "")
	)
	local line1 = "[" .. tostring(title) .. "] " .. Util.PlayerDisplayName(player)
	if f == NEUTRAL_ID then
		line1 = NEUTRAL_EMBLEM .. " " .. line1
	end

	local line2 = "Lv " .. level .. " · " .. Config.ClassName(classId, f)
	-- review 381f6a1: the beta pioneer title is a small mark here unless it is the selected (line 1) title
	local pioneer = Config.TitleDefs and Config.TitleDefs.BetaPioneer
	if pioneer and attrStr(player, "TitleSel", "") ~= "BetaPioneer"
		and table.find(string.split(attrStr(player, "TitlesOwned", ""), ","), "BetaPioneer") then
		line2 ..= " · " .. pioneer.Name
	end
	if rebirths > 0 then
		line2 ..= "  Rebirth " .. rebirths
	end
	local outlaw = player:GetAttribute("Outlaw") == true -- A23-23: shown even with the name hidden (BB37 is chat only)
	if player:GetAttribute("Rookie") == true and f ~= NEUTRAL_ID then
		line2 ..= "  Sprout Shield"
	elseif attrNum(player, "GraduateGraceUntil", 0) > Util.Now() and f ~= NEUTRAL_ID then
		line2 ..= "  Sprout Grace" -- A23-18 (the attribute goes back to 0 when the grace ends -> rebuilt)
	end

	local bits = {}
	local bully = math.floor(attrNum(player, "BullyStacks", 0))
	if bully > 0 then
		table.insert(bits, bully > 1 and ("Bully ×" .. bully) or "Bully")
	end
	local bounty = attrNum(player, "Bounty", 0)
	if bounty > 0 then
		local stars = math.clamp(math.floor(attrNum(player, "WantedStars", 0)), 0, Config.PvP.MaxStars)
		local starText = string.rep("★", stars)
		local b = "Bounty " .. Util.FormatNumber(bounty)
		table.insert(bits, starText ~= "" and (starText .. " " .. b) or b)
	end
	local line3 = table.concat(bits, "  ")

	local l1 = bb:FindFirstChild("Line1")
	local l2 = bb:FindFirstChild("Line2")
	local l3 = bb:FindFirstChild("Line3")
	if l1 then
		l1.Text = esc(line1)
		l1.TextColor3 = factionColor(f)
		CROWN.Place(player, l1)
	end
	if l2 then
		-- A23-23: a red "무법자" at the end of line 2 (RichText is on; the tag is fixed text, never player input)
		l2.Text = esc(line2) .. (outlaw and (' <font color="#FF4A4A">' .. Config.Ranking.Text.OutlawTag .. "</font>") or "")
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
-- 계급 장식 3D: the rank's imported halo / horns (Config.Visuals.MarkModels; a MeshPart, or the first mesh of a Model),
-- nil until it is in Studio
local function markTemplate(f, rank)
	local M = V.MarkModels
	local names = type(M) == "table" and M[f] or nil
	if type(names) ~= "table" or #names == 0 then return nil end
	local folder = ServerStorage:FindFirstChild(M.Folder or "MarkModels")
	local t = folder and folder:FindFirstChild(names[math.clamp(rank, 1, #names)])
	if t and t:IsA("Model") then t = t:FindFirstChildWhichIsA("BasePart", true) end
	return (t and t:IsA("BasePart")) and t or nil
end

-- 3rd idea round #6 (검수 2026-10-07): where the mark stands (head-space Y) = the head top, or the top of a hat / hair
-- accessory's handle when that is higher (an up-do or a cap hid R1 / R2), never more than MaxRise x k above the head top
local function markFloor(character, head, k)
	local top = head.Size.Y / 2
	local floor = top
	for _, acc in character:GetChildren() do
		local handle = acc:IsA("Accessory") and acc:FindFirstChild("Handle") or nil
		if handle and handle:IsA("BasePart") then
			local onHead = false
			for _, a in handle:GetChildren() do
				if a:IsA("Attachment") and MARK_HEAD_SLOTS[a.Name] then onHead = true end
			end
			if not onHead then
				local ok, kind = pcall(function() return acc.AccessoryType end)
				onHead = ok and (kind == Enum.AccessoryType.Hat or kind == Enum.AccessoryType.Hair)
			end
			if onHead then
				floor = math.max(floor, head.CFrame:PointToObjectSpace(handle.Position).Y + handle.Size.Y / 2)
			end
		end
	end
	return math.min(floor, top + (V.MarkModels.MaxRise or 1) * k)
end

-- A9-1 Neutral: a teal Neon gear 1.6 studs above the head = one thin Cylinder + two crossed Blocks (3 parts), fixed
-- size (does not grow with rank). It stands upright (faces front/back), so at a distance it reads differently from
-- the flat Halo disc, the Horns wedges and the bare None head.
-- 검수 10/11 (main photo: a big teal square floated 1.6 studs up and hid the 'Altar of Fate' sign; from the side a
-- pillar): GEAR.Size of the old size, sitting GEAR.Gap above the head top or the hat / hair on it (markFloor, like
-- the halo / horns models), until a 3D gear model exists (Config.Visuals.MarkModels.Neutral, art)
local GEAR = { Size = 0.55, Gap = 0.35 }
local function buildNeutralGear(head, sc, character)
	local color = factionColor(NEUTRAL_ID)
	sc *= GEAR.Size
	local k = math.max(0.25, head.Size.Y / ((V.MarkModels and V.MarkModels.HeadRef) or 1.2))
	local floor = character and markFloor(character, head, k) or head.Size.Y / 2
	local base = head.CFrame * CFrame.new(0, floor + GEAR.Gap * k + 0.55 * sc, 0)
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

-- A23-75 / A23-77: the worn look's Config.LookThemes entry when it belongs to my side (LookOn is written and checked by
-- the server), else nil
local function lookTheme(player, f)
	local id = attrStr(player, "LookOn", "")
	local t = id ~= "" and type(Config.LookThemes) == "table" and Config.LookThemes[id] or nil
	return (type(t) == "table" and t.Faction == f) and t or nil
end

-- the clone on the head: x head height / HeadRef (x RankScale), its bottom HaloGap above (halo) / HornsDepth into
-- (horns) the head top or the hat / hair on it (markFloor), turned by Yaw; halos keep the old disc's light, the top
-- rank sparkles. A worn look (theme) swaps the mesh's TextureID for the rank's and tints the light / sparkles
local function buildMarkModel(f, rank, head, template, character, theme)
	local M = V.MarkModels
	local k = math.max(0.25, head.Size.Y / (M.HeadRef or 1.2))
	local part = template:Clone()
	part.Name = f == "Halo" and "HaloModel" or "HornsModel"
	part.Size = template.Size * k * (type(M.RankScale) == "table" and tonumber(M.RankScale[rank]) or 1)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	if theme then
		local tex = theme[rank <= 2 and "R1R2" or ("R" .. rank)]
		if type(tex) == "string" and tex ~= "" and part:IsA("MeshPart") then part.TextureID = tex end
	end
	local lift = f == "Halo" and (M.HaloGap or 0.3) * k or -(M.HornsDepth or 0.06) * k
	part.CFrame = head.CFrame * CFrame.new(0, markFloor(character, head, k) + lift + part.Size.Y / 2, 0)
		* CFrame.Angles(0, math.rad(M.Yaw or 0), 0)
	if f == "Halo" and type(M.HaloLight) == "table" then
		addLight(part, theme and theme.Glow or Config.Factions.Halo.Color, (M.HaloLight.Range or 8) * k,
			M.HaloLight.Brightness or 1.2)
	end
	local glow = M.Glow
	if type(glow) == "table" and rank >= (glow.Rank or 5) then
		sparkle(part, theme and theme.Sparkle or glow[f] or Config.Factions[f].Color, glow.Rate or 5, (glow.Size or 0.25) * k)
	end
	return { part }
end

local function buildFactionMark(player, character)
	clearChild(character, "FactionMark")
	local f = getFaction(player)
	if f ~= "Halo" and f ~= "Horns" and f ~= NEUTRAL_ID then return end -- None: nothing
	local head = Util.FindPart(character, "Head")
	if not head then return end
	local sc = charScale(character)
	if f == NEUTRAL_ID then
		mount(newPiece("FactionMark"), buildNeutralGear(head, sc, character), character, head)
		return
	end
	local _, rank = Config.GetTitle(f, attrNum(player, "Honor", 0), attrNum(player, "Infamy", 0))
	rank = math.max(1, rank or 1)
	local template = markTemplate(f, rank)
	if template then
		mount(newPiece("FactionMark"), buildMarkModel(f, rank, head, template, character, lookTheme(player, f)), character,
			head)
		return
	end
	local scale = 1 + V.MarkScalePerRank * (rank - 1)

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

-- A23-108 고침 (검수 grip sheet 2026-10-10, user "검 말고는 다 이상한데"): every held weapon passes THROUGH the fist like
-- the sword - its long axis is the hand's -Z (the knuckle line), never the forearm (+Y, which ran staffs, hammers and
-- bows along the arm and turned them upside down in the Hold poses). With the forearm forward (ClassGrips Hold ~90
-- degrees) the axis points up. Hand = the share of the length below the hand (staffs 0.4, hammer / baton 0.3).
local function fist(grip)
	return grip * CFrame.Angles(-math.pi / 2, 0, 0) -- +Y = the hand's -Z, +Z = towards the elbow (the body)
end

-- A23-133 (user 10/11 "무기가 너무 길어서 잡는 위치가 이상해"; references docs/design/grip_reference_2026-10-11.md §5):
-- held lengths as a share of the avatar's height (the place's default R15 = 5.18 studs at scale 1). Config.Weapons Length
-- (3 .. 6.5) only orders the tiers; tierLen squeezes it into each kind's studs: the blade (a sword 0.75 .. 0.9 of the
-- height with its handle and guard - Roblox's Linked Sword is 4 studs, the gear swords' median 5), the bow (0.6 .. 0.95;
-- the gear bows' median 5.25). A23-142 (user 10/12 "마법봉 ... 아직도 길고 뭉툭해"): a staff is a SHARE of this avatar's
-- own height (0.65 .. 0.75 with its orb / flask / hook; STAFF below), not studs
local LEN = { From = { 3, 6.5 }, Blade = { 2.4, 3.1 }, Staff = { 0.65, 0.75 }, Bow = { 3.1, 4.9 } }
local function tierLen(w, to)
	local t = math.clamp(((tonumber(w.Length) or LEN.From[1]) - LEN.From[1]) / (LEN.From[2] - LEN.From[1]), 0, 1)
	return to[1] + (to[2] - to[1]) * t
end

local function buildSword(grip, sc, w, color)
	local L = grip * CFrame.Angles(-math.pi / 2, 0, 0) -- +Y of L points forward
	local handleLen = 1.2
	local bladeLen = tierLen(w, LEN.Blade)
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
		Name = "Blade", Size = Vector3.new(0.25, bladeLen, 0.6) * sc,
		Material = w.Material, Color = color,
		CFrame = L * CFrame.new(0, (handleLen / 2 + 0.25 + bladeLen / 2) * sc, 0),
	})
	return { handle, guard, blade }, blade
end

-- A23-142 (user 10/12 Play "마법봉 대가리를 거의 잡는 것 같고, 아직도 마법봉이 길고 뭉툭해"; references
-- docs/design/grip_reference_2026-10-11.md §5-7: a staff carried in one hand is held at its balance point, upright beside
-- the body, its foot off the ground): every staff (the Light Mage's, the Dark Mage's crook, the Alchemist's flask staff) is
-- LEN.Staff of the avatar's OWN height long, orb / flask / hook included (avatarHeight: the rig's head top over the ground;
-- Height when the rig cannot be read), the hand Grip of that length up from the foot (the middle wrap), and the orb never
-- closer to the hand than OrbClear (a bigger tier's orb shrinks to fit). The pose keeps the hand 2.56 .. 2.71 over the
-- ground (Config.ClassGrips), so the foot hangs about 0.9 .. 1.3 over it - the client only lifts the hand if the foot would
-- go into the ground (the WeaponModel's StaffCarry, WeaponPose.StaffStep). Studs here are the avatar's own (x sc later).
local STAFF = { Grip = 0.43, OrbClear = 1.2, Height = 5.18, Orb = 0.5, OrbPerTier = 0.05 }

-- the head's top over the ground (studs, this avatar's own size) at rest, from its R15 rig, or nil
local function avatarHeight(character)
	local ok, h = pcall(function()
		local hum = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		local lower, upper, head = character:FindFirstChild("LowerTorso"), character:FindFirstChild("UpperTorso"),
			character:FindFirstChild("Head")
		if not (hum and root and lower and upper and head) or hum.RigType ~= Enum.HumanoidRigType.R15 then return nil end
		local function at(part, name)
			local a = part:FindFirstChild(name)
			return a and a:IsA("Attachment") and a.Position or nil
		end
		local r0, r1 = at(root, "RootRigAttachment"), at(lower, "RootRigAttachment")
		local w0, w1 = at(lower, "WaistRigAttachment"), at(upper, "WaistRigAttachment")
		local n0, n1 = at(upper, "NeckRigAttachment"), at(head, "NeckRigAttachment")
		if not (r0 and r1 and w0 and w1 and n0 and n1) then return nil end
		local torso = hum.HipHeight + root.Size.Y / 2 + (r0.Y - r1.Y) + (w0.Y - w1.Y) -- UpperTorso centre over the ground
		return torso + (n0.Y - n1.Y) + head.Size.Y / 2
	end)
	return ok and type(h) == "number" and h == h and h > 0 and h or nil
end

-- a staff's whole length (unscaled studs: the shapes multiply by sc) for this avatar's height, and that height
local function staffLen(w, height, sc)
	local h = (type(height) == "number" and height > 0) and height / sc or STAFF.Height
	return h * tierLen(w, LEN.Staff), h
end

-- the orb's size: Orb + OrbPerTier x tier, smaller when its bottom would come nearer the hand than OrbClear (on the
-- default avatar; it grows and shrinks with the avatar's height h). The shape says how far under the staff's top the
-- orb's bottom hangs for a size d: a + b x d
local function staffOrb(tier, total, h, a, b)
	local room = total * (1 - STAFF.Grip) - STAFF.OrbClear * h / STAFF.Height - a
	-- C1: the Mythic tier 9 keeps tier 8's orb (math.min(tier, 8)); the hand room shrinks it as before
	return math.max(0.3, math.min(STAFF.Orb + STAFF.OrbPerTier * math.min(tier, 8), room / b))
end

local function buildStaff(grip, sc, w, color, tier, height)
	local total, h = staffLen(w, height, sc)
	local d = staffOrb(tier, total, h, 0, 1) -- the orb's top is the staff's top, its bottom d under it
	local shaftLen = total - d * 0.85
	local base = fist(grip) -- the shaft centreline passes through the actual hand grip
	local low = total * STAFF.Grip -- studs from the foot up to the hand
	local shaft = accPart({
		Name = "Shaft", Size = Vector3.new(0.25, shaftLen, 0.25) * sc,
		Material = Enum.Material.Wood, Color = WOOD_COLOR,
		CFrame = base * CFrame.new(0, (shaftLen / 2 - low) * sc, 0),
	})
	local collar = accPart({
		Name = "Collar", Size = Vector3.new(0.45, 0.3, 0.45) * sc,
		Material = w.Material, Color = color,
		CFrame = base * CFrame.new(0, (shaftLen - low - 0.05) * sc, 0),
	})
	local tip = accPart({
		Name = "Tip", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d) * sc,
		Material = Enum.Material.Neon, Color = color,
		CFrame = base * CFrame.new(0, (shaftLen - low + d * 0.35) * sc, 0),
	})
	addLight(tip, color, 8 * sc, 1.5)
	return { shaft, collar, tip }, tip
end

local function buildBow(grip, sc, w, color, scale, tilt)
	local H = tierLen(w, LEN.Bow) * (tonumber(scale) or 1) -- A23-108: the Shadow Hunter's short bow is smaller and held tilted
	local half = math.rad(50)
	local R = H / (2 * math.sin(half))
	local sag = R * (1 - math.cos(half))
	-- The centre/grip stays in the hand at every tier; lifting a long bow moved its arrow rest
	-- above the grip, so no arm pose could align the string hand, face and launch axis together.
	-- A23-108 고침: the riser through the fist (limbs up with the forearm forward), the string on the body side (+Z)
	local base = fist(grip) * CFrame.Angles(0, 0, math.rad(tonumber(tilt) or 0))
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

-- A23-39 pet tamer: a short taming baton in the right hand (code shape until the baton model is made)
local function buildBaton(grip, sc, w, color, tier)
	local shaftLen = 1.8
	local base, low = fist(grip), shaftLen * 0.3
	local shaft = accPart({
		Name = "Shaft", Size = Vector3.new(0.22, shaftLen, 0.22) * sc,
		Material = Enum.Material.Wood, Color = WOOD_COLOR,
		CFrame = base * CFrame.new(0, (shaftLen / 2 - low) * sc, 0),
	})
	local d = 0.35 + 0.04 * tier
	local tip = accPart({
		Name = "Tip", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d) * sc,
		Material = w.Material, Color = color,
		CFrame = base * CFrame.new(0, (shaftLen - low + d * 0.3) * sc, 0),
	})
	return { shaft, tip }, tip
end

-- A23-108 (docs/design/class_grips_a23_108_2026-10-10.md; game dev 1's proposal, game dev 3 checks): each class x side
-- holds its own weapon (Config.ClassGrips[...].Weapon). Code shapes until the P3 weapon models (Tripo) replace them.
-- (a table, not locals: buildWeapon finds them by kind; offline extracts of buildWeapon without it keep the old shapes)
local SHAPES = {}

-- A23-128 (user 2026-10-11 "한손검만"): the Berserker's dark ONE-hand sword (the great sword and its two-hand grip are
-- gone). Held like the Paladin's sword (buildSword: the handle centred on the right grip, the blade ahead along the
-- fist, the same size), but dark: a dark wrapped handle with a round pommel, a guard swept towards the blade in a V
-- and the blade shaded towards black (Shade of the way). Code shape until the P3 weapon models (Tripo) replace it.
function SHAPES.DarkSword(grip, sc, w, color)
	local D = { Handle = 1.2, Dark = Color3.fromRGB(34, 26, 34), Shade = 0.35, Sweep = 25 }
	local bladeLen = tierLen(w, LEN.Blade) -- A23-133: buildSword's blade
	local L = grip * CFrame.Angles(-math.pi / 2, 0, 0) -- +Y of L points forward (as buildSword)
	local parts = {}
	table.insert(parts, accPart({
		Name = "Handle", Size = Vector3.new(0.3, D.Handle, 0.3) * sc,
		Material = Enum.Material.Fabric, Color = D.Dark, CFrame = L,
	}))
	for _, s in { -1, 1 } do -- the two halves of the guard, their outer ends swept up towards the blade
		table.insert(parts, accPart({
			Name = "Guard", Size = Vector3.new(0.65, 0.22, 0.4) * sc,
			Material = Enum.Material.Metal, Color = DARK_METAL,
			CFrame = L * CFrame.new(s * 0.27 * sc, (D.Handle / 2 + 0.14) * sc, 0) * CFrame.Angles(0, 0, math.rad(s * D.Sweep)),
		}))
	end
	local blade = accPart({
		Name = "Blade", Size = Vector3.new(0.25, bladeLen, 0.6) * sc,
		Material = w.Material, Color = color:Lerp(D.Dark, D.Shade),
		CFrame = L * CFrame.new(0, (D.Handle / 2 + 0.25 + bladeLen / 2) * sc, 0),
	})
	table.insert(parts, blade)
	table.insert(parts, accPart({
		Name = "Pommel", Shape = Enum.PartType.Ball, Size = Vector3.new(0.36, 0.36, 0.36) * sc,
		Material = Enum.Material.Metal, Color = DARK_METAL,
		CFrame = L * CFrame.new(0, -(D.Handle / 2 + 0.1) * sc, 0),
	}))
	return parts, blade
end

-- Blacksmith: a short smithing hammer (a wooden handle, a heavy metal head with a band in the tier colour)
function SHAPES.Hammer(grip, sc, w, color)
	local handleLen = 1.9
	local base, low = fist(grip), handleLen * 0.3 -- the hand on the lower third, the head up
	local handle = accPart({
		Name = "Handle", Size = Vector3.new(0.26, handleLen, 0.26) * sc,
		Material = Enum.Material.Wood, Color = WOOD_COLOR, CFrame = base * CFrame.new(0, (handleLen / 2 - low) * sc, 0),
	})
	local head = accPart({
		Name = "Head", Size = Vector3.new(1.1, 0.6, 0.6) * sc,
		Material = Enum.Material.Metal, Color = DARK_METAL, CFrame = base * CFrame.new(0, (handleLen - low) * sc, 0),
	})
	local band = accPart({
		Name = "Band", Size = Vector3.new(0.3, 0.64, 0.64) * sc,
		Material = w.Material, Color = color, CFrame = base * CFrame.new(0, (handleLen - low) * sc, 0),
	})
	return { handle, head, band }, head
end

-- Dark Mage: a crooked staff (the shaft, a hook bent over the top, the glowing orb hanging in the hook)
-- A23-142: the hook rises Hook over the shaft's top (the staff's top), the orb hangs under its end at OrbY.
-- 최종 검수 10/13 (side photo staff_front_v3f: the orb hid the Dark Mage's face): the hook bends AHEAD - the fist's -Z
-- (away from the shoulder) - not along its +X, which pointed back at the hunched head
function SHAPES.CrookStaff(grip, sc, w, color, tier, height)
	local K = { Hook = 0.5, OrbX = 0.55, OrbY = 0.1, Bend = -60 }
	local total, h = staffLen(w, height, sc)
	local shaftLen = total - K.Hook
	local base, low = fist(grip), total * STAFF.Grip
	local shaft = accPart({
		Name = "Shaft", Size = Vector3.new(0.28, shaftLen, 0.28) * sc,
		Material = Enum.Material.Wood, Color = Color3.fromRGB(70, 50, 60),
		CFrame = base * CFrame.new(0, (shaftLen / 2 - low) * sc, 0),
	})
	local top = base * CFrame.new(0, (shaftLen - low) * sc, 0)
	local hook = accPart({
		Name = "Hook", Size = Vector3.new(0.24, 0.9, 0.24) * sc,
		Material = Enum.Material.Wood, Color = Color3.fromRGB(70, 50, 60),
		CFrame = top * CFrame.Angles(math.rad(K.Bend), 0, 0) * CFrame.new(0, 0.4 * sc, 0),
	})
	local d = staffOrb(tier, total, h, K.Hook - K.OrbY, 0.5)
	local orb = accPart({
		Name = "Tip", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d) * sc,
		Material = Enum.Material.Neon, Color = color,
		CFrame = top * CFrame.new(0, K.OrbY * sc, -K.OrbX * sc),
	})
	addLight(orb, color, 8 * sc, 1.5)
	return { shaft, hook, orb }, orb
end

-- Alchemist: 최종 검수 10/12 (the approved 2D art/out/s2/weapons_t13_4v/Weapon_Neutral_Alchemist_T1..T3_front: a staff
-- with a flask, the hand on its leather wrap) - a wooden staff like the Light Mage's, the wrap round the hand, a cradle of
-- two prongs at the top holding a round glass flask (the brew in the tier colour), its neck and cork above. A23-142: the
-- whole staff (cork included) LEN.Staff of the height, held at Grip, the flask's bottom OrbClear over the hand. Code shape
-- until the Tripo models (step 3) replace it.
function SHAPES.FlaskStaff(grip, sc, w, color, tier, height)
	local F = { Neck = 0.12, Cork = 0.1, Sit = 0.35, Wrap = 0.7, Prong = 0.5, Splay = 25,
		Leather = Color3.fromRGB(92, 58, 42), Brass = Color3.fromRGB(196, 152, 72), Glass = Color3.fromRGB(220, 235, 240) }
	local total, h = staffLen(w, height, sc)
	local d = staffOrb(tier, total, h, F.Neck + F.Cork, 1) -- the flask's bottom: d + the neck and cork under the top
	local shaftLen = total - d * (F.Sit + 0.5) - (F.Neck + F.Cork)
	local base, low = fist(grip), total * STAFF.Grip
	local parts = {}
	table.insert(parts, accPart({
		Name = "Shaft", Size = Vector3.new(0.25, shaftLen, 0.25) * sc,
		Material = Enum.Material.Wood, Color = WOOD_COLOR,
		CFrame = base * CFrame.new(0, (shaftLen / 2 - low) * sc, 0),
	}))
	table.insert(parts, accPart({ -- the leather wrap the fist holds (centred on the grip)
		Name = "Wrap", Size = Vector3.new(0.3, F.Wrap, 0.3) * sc,
		Material = Enum.Material.Fabric, Color = F.Leather, CFrame = base,
	}))
	local top = base * CFrame.new(0, (shaftLen - low) * sc, 0)
	for _, s in { -1, 1 } do -- the cradle's two prongs, splayed out round the flask
		table.insert(parts, accPart({
			Name = "Prong", Size = Vector3.new(0.1, F.Prong, 0.1) * sc,
			Material = Enum.Material.Metal, Color = F.Brass,
			CFrame = top * CFrame.new(s * 0.1 * sc, 0, 0) * CFrame.Angles(0, 0, math.rad(-s * F.Splay))
				* CFrame.new(0, F.Prong / 2 * sc, 0),
		}))
	end
	local flask = accPart({
		Name = "Flask", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d) * sc,
		Material = Enum.Material.Glass, Color = color, Transparency = 0.25,
		CFrame = top * CFrame.new(0, d * F.Sit * sc, 0),
	})
	table.insert(parts, flask)
	local neckAt = d * (F.Sit + 0.5) + F.Neck / 2 -- just over the flask's top
	table.insert(parts, accPart({
		Name = "Neck", Size = Vector3.new(0.2, F.Neck + 0.04, 0.2) * sc,
		Material = Enum.Material.Glass, Color = F.Glass, Transparency = 0.3,
		CFrame = top * CFrame.new(0, (neckAt - 0.02) * sc, 0),
	}))
	table.insert(parts, accPart({
		Name = "Cork", Size = Vector3.new(0.24, F.Cork, 0.24) * sc,
		Material = Enum.Material.Wood, Color = WOOD_COLOR,
		CFrame = top * CFrame.new(0, (neckAt + F.Neck / 2 + F.Cork / 2) * sc, 0),
	}))
	addLight(flask, color, 8 * sc, 1.2)
	return parts, flask
end

-- Shadow Hunter: the bow smaller and held tilted
function SHAPES.ShortBow(grip, sc, w, color)
	return buildBow(grip, sc, w, color, 0.75, 15)
end

local function buildWeapon(player, character)
	clearChild(character, "WeaponModel")
	-- A23-34: bare hands (tier 0) = nothing in the hands (the halo / horns stay)
	if Config.Weapons[math.floor(attrNum(player, "WeaponTier", 0))] == nil then return end
	local classId = getClass(player)
	local classDef = Config.Classes[classId] or Config.Classes.Warrior
	-- A23-39: the pet tamer (artisan Archer) holds a baton in the right hand, never a bow (guarded: some offline suites
	-- load only the Config weapon rows)
	-- A23-108: the weapon of this class x side (Config.ClassGrips); without a row the old rule
	local gkey = type(Config.ClassGripKey) == "function" and Config.ClassGripKey(classId, getFaction(player)) or nil
	local gdef = type(Config.ClassGrips) == "table" and gkey and Config.ClassGrips[gkey] or nil
	local kind = (type(gdef) == "table" and type(gdef.Weapon) == "string" and gdef.Weapon)
		or ((Config.IsTamer and Config.IsTamer(classId, getFaction(player))) and "Baton" or classDef.Weapon)
	local left = kind == "Bow" or kind == "ShortBow"
	local hand = left and Util.FindPart(character, "LeftHand", "Left Arm")
		or (not left and Util.FindPart(character, "RightHand", "Right Arm"))
	if not hand then return end
	local sc = charScale(character)
	local tier = math.clamp(math.floor(attrNum(player, "WeaponTier", 1)), 1, Config.MaxWeaponTier)
	local w = Config.Weapons[tier]
	local f = getFaction(player)
	local color = Config.WeaponColor(tier, f)
	local grip = gripCFrame(hand, left)
	-- A23-142: a staff's length follows this avatar's own height (nil = STAFF.Height x sc; offline extracts of buildWeapon
	-- without the helper keep that)
	local isStaff = kind == "Staff" or kind == "CrookStaff" or kind == "FlaskStaff"
	local staffHeight = (isStaff and type(avatarHeight) == "function") and avatarHeight(character) or nil

	local parts, main
	local shape = type(SHAPES) == "table" and SHAPES[kind] or nil
	if shape then
		parts, main = shape(grip, sc, w, color, tier, staffHeight)
	elseif kind == "Staff" then
		parts, main = buildStaff(grip, sc, w, color, tier, staffHeight)
	elseif kind == "Bow" then
		parts, main = buildBow(grip, sc, w, color)
	elseif kind == "Baton" then
		parts, main = buildBaton(grip, sc, w, color, tier)
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
	if isStaff then model:SetAttribute("StaffCarry", true) end -- A23-142: held off the ground (WeaponPose lifts, never lowers)
	if main then
		local muzzle = Instance.new("Attachment")
		muzzle.Name = "AttackMuzzle"
		if kind == "Bow" or kind == "ShortBow" then
			muzzle.Position = Vector3.new(0, 0, -0.18 * sc)
		elseif kind == "Staff" or kind == "Baton" then
			muzzle.Position = Vector3.new(0, main.Size.Y * 0.5, 0)
		else
			muzzle.Position = Vector3.new(0, main.Size.Y * 0.5, 0)
		end
		muzzle.Parent = main
		-- Server-built attachment offsets survive both joint types and avoid reading a one-frame-old
		-- hand/weapon pair while their Transform batch is still waiting for the physics step.
		model:SetAttribute("HandMuzzle", hand.CFrame:ToObjectSpace(main.CFrame * muzzle.CFrame))
		if kind == "Bow" or kind == "ShortBow" then -- both bows: Fx.archerPose needs HandBowRest (개발 3 check: the short bow lacked it)
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
	local held = attrNum(player, "SackHeldUntil", 0) > Util.Now()
	local transparency = held and 0.15 or V.GhostTransparency
	local body = accPart({
		Name = "GhostBody", Size = Vector3.new(1.6, 2, 0.8) * sc,
		Material = Enum.Material.Neon, Color = V.GhostColor, Transparency = transparency,
		CFrame = base,
	})
	local ghostHead = accPart({
		Name = "GhostHead", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2) * sc,
		Material = Enum.Material.Neon, Color = V.GhostColor, Transparency = transparency,
		CFrame = base * CFrame.new(0, 1.6 * sc, 0),
	})
	if held then -- A23-18 hold glow (existing ghost colour, brighter; no new art)
		local light = Instance.new("PointLight")
		light.Color = V.GhostColor
		light.Brightness = 4
		light.Range = 14 * sc
		light.Parent = body
	end

	local victim = attrStr(player, "SackVictimName", "")
	if victim == "" then victim = "Someone" end
	local bb = Instance.new("BillboardGui")
	bb.Name = "GhostLabel"
	bb.Size = UDim2.fromOffset(200, 28)
	bb.StudsOffset = Vector3.new(0, 1.3 * sc, 0)
	bb.MaxDistance = V.NametagMaxDistance
	bb.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	tagFont(label, "Ghost")
	label.TextScaled = true
	label.TextColor3 = GHOST_TEXT
	label.TextStrokeTransparency = 0.3
	label.Text = victim .. "'s grudge"
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

-- A23-131 / A23-141: the golden eggs carried (EggCarry slots, 0..3) in a little basket on the back - not over the head,
-- where the name tag, the halo / horns and the VIP crown live (design 'gaps': head overlap). One Motor6D EggJoint
-- (upper torso -> EggBase) holds the stack; the client wobbles it through its Transform (golden_egg_contract §4).
-- Placeholder parts until the approved egg model (no light: up to 90 carried eggs in a full square)
local EGGS = { Egg = Color3.fromRGB(255, 196, 64), Basket = Color3.fromRGB(150, 105, 60), Size = 0.55, Gap = 0.45 }
local function buildEggStack(player, character, force)
	local n = math.clamp(math.floor(attrNum(player, "EggCarry", 0)), 0, 3)
	local existing = character:FindFirstChild("EggStack")
	if not force and existing and builtTier[existing] == n then return end
	clearChild(character, "EggStack")
	if n <= 0 then return end
	local torso = Util.FindPart(character, "UpperTorso", "Torso")
	if not torso then return end
	local sc = charScale(character)
	local baseCF = torso.CFrame * CFrame.new(0, 0.55 * sc, torso.Size.Z / 2 + 0.35 * sc)
	local base = accPart({ Name = "EggBase", Size = Vector3.new(0.9, 0.35, 0.6) * sc, Material = Enum.Material.WoodPlanks,
		Color = EGGS.Basket, CFrame = baseCF })
	local parts = { base }
	local d = EGGS.Size * sc
	for i = 1, n do
		table.insert(parts, accPart({ Name = "Egg" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d),
			Material = Enum.Material.SmoothPlastic, Color = EGGS.Egg,
			CFrame = baseCF * CFrame.new(0, 0.175 * sc + d * 0.5 + (i - 1) * EGGS.Gap * sc, 0) }))
	end
	local model = newPiece("EggStack")
	for _, part in parts do part.Parent = model end
	model.Parent = character
	local joint = Instance.new("Motor6D")
	joint.Name = "EggJoint"
	joint.Part0, joint.Part1 = torso, base
	joint.C0 = torso.CFrame:ToObjectSpace(baseCF)
	joint.Parent = base
	for i = 2, #parts do Util.Weld(base, parts[i]) end
	builtTier[model] = n
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
	EggStack = buildEggStack,
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
		elseif child:IsA("Accessory") then
			-- 3rd idea round #6: a hat / hair that arrives later lifts the halo / horns (once its weld has settled)
			task.delay(REFRESH_DEBOUNCE, markDirty, player, { "FactionMark" })
		end
	end))
	table.insert(st.CharConns, character.ChildRemoved:Connect(function(child)
		if child:IsA("Accessory") then markDirty(player, { "FactionMark" }) end
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
