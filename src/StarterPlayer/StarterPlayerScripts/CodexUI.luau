-- CodexUI.luau (게임성 개발 1, SPEC A23-153 "몬스터 도감 카드"; design docs/design/codex_cards_2026-10-12.md, server contract
-- docs/design/codex_cards_contract_2026-10-13.md - CodexService is the server's): the Monster Codex window and the card
-- moments. Presentation only: the server owns every card, kill, stage, reward and title.
--   Window (Panels "Codex", the HUD tile "Codex"): three page tabs (Config.Codex.Pages, named after their zones), the
--   page's cards as slots (a card not met yet = its monster's black silhouette) and the chosen card big: the monster in
--   3D (a ViewportFrame) that turns with the mouse or a drag - the card tilts - inside the stage rim (Card / Silver /
--   Gold Holo; the Gold Foil card once a golden one was beaten) with a soft sheen that follows the tilt (Silver, Holo,
--   Foil) and round sparkles (Holo, Foil; A23-153: never rays), its name, kills and next stage. A click or [Flip]
--   turns it over: the back = my side's line about it (Config.Codex.Lore), where it lives, what it drops, kills and the
--   first day ("Before the Codex" for a card made from an old save). [Auto tilt] sways it by itself.
--   Moments (c<-s "CodexUp", queued, one at a time, after the tutorial's first claim - UIKit.ShouldHoldBanners): a new
--   card / a Gold Foil card shows big in the middle and lights up from its silhouette, Silver / Gold Holo sway the card
--   and turn it into the next stage, the server's line under it; a page done / every card Gold Holo = the shared reward
--   popup. With the codex window open the card there is redrawn and the line is a toast. Config.Codex.ServerToast is
--   false: the lines come only from here.
--   Data: c<-s "Codex" { Cards, Glow } at join and on c->s "CodexOpen" (sent when the window opens, rate-limited).
-- The monster on a card: ReplicatedStorage.CodexModels.<kind> (the server's copies, when it sends them), else a live
-- monster of that kind in workspace.Monsters (copied once), else the approved IconMon<kind> picture, else "?".
-- Game text: English only (Config.Codex.Text = the server's words, Config.Codex.Screen.Text = this screen's).
-- Public API: CodexUI.Init(C), CodexUI.Start(), CodexUI.IsReady(), CodexUI.Open(arg?), CodexUI.OnCodex(payload),
-- CodexUI.OnUp(payload); pure: CodexUI.View(kind, card, faction, foil), CodexUI.Page(cards, i), CodexUI.Count(cards),
-- CodexUI.Drops(kind), CodexUI.Date(t), CodexUI.Tilt(x, y), CodexUI.Push(queue, payload), CodexUI.MomentOf(event),
-- CodexUI.Fit(radius, fov).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer

local CodexUI = {}
local C = nil
local TAG = "CodexUI"

-- layout (du) and motion
local L = {
	Window = "Codex", Width = 640, -- Panels FRAME.Pad 18 each side -> 604 du of content
	TabH = 40, Gap = 10, ButtonH = 34, ButtonW = 96,
	SlotW = 136, SlotH = 168, Columns = 2, -- the page's cards (four at most)
	RightW = 300, CardW = 230, CardH = 310, -- the big card's column and the card (fits a 440 du tall window)
	View = { Top = 0.11, H = 0.56 }, -- the 3D window on the card face (share of its height)
	Tilt = { Yaw = 28, Pitch = 14, Roll = 3, Ease = 10, Auto = 0.35, Sheen = 0.55 }, -- degrees, 1/s, turns/s, offset
	Flip = 0.12, -- s each half of a flip
	OpenGap = 1.2, -- s between two CodexOpen (Config.RateLimits.CodexOpen + a margin)
	Fov = 30, Margin = 1.12,
	Ambient = Color3.fromRGB(185, 185, 200), Light = Color3.fromRGB(255, 248, 235), LightDir = Vector3.new(-0.6, -1, -0.8),
	Silhouette = Color3.new(0, 0, 0), Lit = Color3.new(1, 1, 1),
	Card = Color3.fromRGB(16, 20, 40), -- the PanelCard fallback colour
	Moment = { W = 220, H = 300, Y = 0.42, In = 0.3, Evolve = 0.7, Out = 0.25, Retry = 0.5, Z = 60 },
	Sparkles = { { 0.18, 0.22 }, { 0.82, 0.18 }, { 0.12, 0.62 }, { 0.88, 0.58 }, { 0.5, 0.08 }, { 0.32, 0.78 } },
	-- what a copied monster loses (scripts, sounds, effects, its name tag / HP bar, movers, its rig's brain)
	Strip = { "LuaSourceContainer", "Sound", "ParticleEmitter", "Trail", "Beam", "BillboardGui", "SurfaceGui", "Highlight",
		"Fire", "Smoke", "Sparkles", "Light", "BodyMover", "Humanoid", "AnimationController", "Animator", "ProximityPrompt",
		"ClickDetector", "Explosion" },
	Events = { Card = "Reveal", Golden = "Reveal", Silver = "Evolve", Holo = "Evolve", Page = "Popup", Glow = "Popup" },
	Looks = { [0] = "None", "Card", "Silver", "Holo" },
}
local S = { Ready = false, Cards = {}, Glow = false, Got = false, Page = 1, Kind = nil, Back = false, Foil = false,
	Auto = false, OpenAt = -math.huge, Queue = {}, Busy = false }
local VIEW = { Root = nil, Kit = nil, Tabs = nil, Grid = nil, Big = nil, Buttons = nil, Count = nil, Conns = {} }
local MODEL = { Cache = {} }
local CARD = {}
local MOMENT = { Card = nil, Frame = nil, Conn = nil }

---------------------------------------------------------------------------------------------------- text (pure)
local function codex() return type(Config.Codex) == "table" and Config.Codex or {} end
local function screen() return type(codex().Screen) == "table" and codex().Screen or {} end

-- this screen's words (Config.Codex.Screen.Text[key], formatted)
local function tx(key, ...)
	local t = type(screen().Text) == "table" and screen().Text or {}
	local s = t[key]
	if type(s) ~= "string" then return "" end
	if select("#", ...) == 0 then return s end
	local ok, out = pcall(string.format, s, ...)
	return ok and out or s
end

local function int(v)
	v = tonumber(v)
	if not v or v ~= v or v == math.huge or v == -math.huge then return 0 end
	return math.max(0, math.floor(v))
end

local function cardOf(cards, kind)
	local e = type(cards) == "table" and cards[kind] or nil
	return type(e) == "table" and e or nil
end

-- the day of a card's first kill ("Oct 13, 2026"), "Before the Codex" for 0 / none (a card made from an old save)
function CodexUI.Date(t)
	t = int(t)
	if t <= 0 then
		local before = type(codex().Text) == "table" and codex().Text.Before or nil
		return type(before) == "string" and before or ""
	end
	local ok, d = pcall(os.date, "*t", t)
	if not ok or type(d) ~= "table" then return "" end
	local months = type(screen().Text) == "table" and screen().Text.Months or {}
	return string.format("%s %d, %d", tostring(months[d.month] or d.month), d.day, d.year)
end

-- the materials a kind drops (Config.Loot.Tables rows whose item is a Material), names in row order, once each
function CodexUI.Drops(kind)
	local loot = type(Config.Loot) == "table" and Config.Loot or {}
	local rows = type(loot.Tables) == "table" and loot.Tables[kind] or nil
	local items = type(loot.Items) == "table" and loot.Items or {}
	local out, seen = {}, {}
	for _, row in (type(rows) == "table" and rows or {}) do
		local id = type(row) == "table" and row.Item or nil
		local item = type(id) == "string" and items[id] or nil
		if type(item) == "table" and item.Kind == "Material" and not seen[id] then
			seen[id] = true
			table.insert(out, tostring(item.Name or id))
		end
	end
	return out
end

-- everything a card face / back shows (pure). card = the server's { Kills, Golden, Stage, First } or nil (not met);
-- faction = my side (the back's voice; None = Neutral); foil = show the Gold Foil card (only when it is owned)
function CodexUI.View(kind, card, faction, foil)
	local def = type(Config.MonsterTypes) == "table" and Config.MonsterTypes[kind] or nil
	def = type(def) == "table" and def or {}
	local text = type(codex().Text) == "table" and codex().Text or {}
	local stages = type(text.Stages) == "table" and text.Stages or {}
	local e = type(card) == "table" and card or nil
	local kills = e and int(e.Kills) or 0
	local stage = e and math.clamp(int(e.Stage), 0, 3) or 0
	if e and type(Config.CodexStage) == "function" then stage = math.max(stage, Config.CodexStage(kind, kills)) end
	local known = stage >= 1
	local canGold = type(Config.CodexCanGold) ~= "function" or Config.CodexCanGold(kind)
	local hasFoil = known and canGold and e ~= nil and int(e.Golden) >= 1
	local v = { Kind = kind, Known = known, Stage = stage, HasFoil = hasFoil, Foil = hasFoil and foil == true,
		Boss = def.Boss == true, Kills = kills }
	v.Look = v.Foil and "Foil" or L.Looks[stage] or "None"
	v.StageName = v.Foil and tostring(text.Foil or "") or (known and tostring(stages[stage] or "") or "")
	v.Name = known and tostring(def.Name or kind) or tx("Unknown")
	v.Short = known and tostring(def.Short or def.Name or kind) or tx("Unknown")
	v.KillsText = known and tx("Kills", Util.FormatInt(kills)) or tx("NotMet")
	local steps = type(Config.CodexSteps) == "function" and Config.CodexSteps(kind) or {}
	if not known then
		v.NextText = ""
	elseif stage >= #steps then
		v.NextText = tx("Top")
	else
		v.NextText = tx("NextAt", tostring(stages[stage + 1] or ""), Util.FormatInt(steps[stage + 1] or 0))
	end
	local side = (faction == "Halo" or faction == "Horns") and faction or "Neutral"
	local lore = type(codex().Lore) == "table" and codex().Lore[kind] or nil
	v.Lore = (known and type(lore) == "table") and tostring(lore[side] or lore.Neutral or "") or ""
	local zones = type(Config.Zones) == "table" and Config.Zones or {}
	local zone = type(def.Zone) == "string" and zones[def.Zone] or nil
	v.Where = known and tx("Where", tostring(type(zone) == "table" and zone.Name or def.Zone or "")) or ""
	v.Drops = known and CodexUI.Drops(kind) or {}
	v.DropsText = #v.Drops > 0 and tx("Drops", table.concat(v.Drops, " · ")) or ""
	v.FirstText = known and tx("First", CodexUI.Date(e and e.First)) or ""
	return v
end

-- a page (pure): its zone name, kinds and how many of them I have
function CodexUI.Page(cards, i)
	local pages = type(codex().Pages) == "table" and codex().Pages or {}
	local page = pages[i]
	if type(page) ~= "table" or type(page.Kinds) ~= "table" then return nil end
	local zones = type(Config.Zones) == "table" and Config.Zones or {}
	local zone = zones[page.Id]
	local owned = 0
	for _, kind in page.Kinds do
		if CodexUI.View(kind, cardOf(cards, kind)).Known then owned += 1 end
	end
	return { Index = i, Id = page.Id, Name = tostring(type(zone) == "table" and zone.Name or page.Id), Kinds = page.Kinds,
		Owned = owned, Total = #page.Kinds, Done = owned == #page.Kinds }
end

-- cards I have / all series-1 cards (pure)
function CodexUI.Count(cards)
	local order = type(codex().Order) == "table" and codex().Order or {}
	local owned = 0
	for _, kind in order do
		if CodexUI.View(kind, cardOf(cards, kind)).Known then owned += 1 end
	end
	return owned, #order
end

-- a tilt (pure): x, y in -1..1 each, kept inside the unit circle
function CodexUI.Tilt(x, y)
	x, y = math.clamp(tonumber(x) or 0, -1, 1), math.clamp(tonumber(y) or 0, -1, 1)
	local m = math.sqrt(x * x + y * y)
	if m > 1 then x, y = x / m, y / m end
	return x, y
end

-- how a CodexUp event shows (pure): "Reveal" (a new card / Gold Foil), "Evolve" (Silver / Gold Holo), "Popup" (a page
-- done / every card Gold Holo) or nil (not ours)
function CodexUI.MomentOf(event)
	return type(event) == "string" and L.Events[event] or nil
end

-- queues a CodexUp payload for its moment (pure): ours only, at most Config.Codex.Screen.Moment.Max waiting (the oldest
-- go). Returns the queue's length
function CodexUI.Push(queue, payload)
	if type(queue) ~= "table" or type(payload) ~= "table" or not CodexUI.MomentOf(payload.Event) then
		return type(queue) == "table" and #queue or 0
	end
	table.insert(queue, payload)
	local max = int(type(screen().Moment) == "table" and screen().Moment.Max or 8)
	while #queue > math.max(1, max) do table.remove(queue, 1) end
	return #queue
end

-- the camera's distance that fits a sphere of this radius in a view of fov degrees (pure)
function CodexUI.Fit(radius, fov)
	local half = math.rad(math.clamp(tonumber(fov) or L.Fov, 5, 120)) / 2
	return math.max(0.5, (tonumber(radius) or 1) / math.sin(half)) * L.Margin
end

---------------------------------------------------------------------------------------------------- models
-- a clean, still copy of a monster model for a ViewportFrame (or nil)
function MODEL.Clean(src)
	local was = src.Archivable
	local ok, copy = pcall(function()
		src.Archivable = true
		return src:Clone()
	end)
	pcall(function() src.Archivable = was end)
	if not ok or not copy then return nil end
	for _, d in copy:GetDescendants() do
		local gone = false
		for _, cls in L.Strip do
			if d:IsA(cls) then gone = true; break end
		end
		if not gone and d:IsA("Constraint") and not d:IsA("WeldConstraint") then gone = true end
		if gone then
			pcall(function() d:Destroy() end)
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	if copy:IsA("BasePart") then
		local m = Instance.new("Model")
		copy.Anchored = true
		copy.Parent = m
		copy = m
	end
	return copy
end

-- a live monster of this kind (not golden) in workspace.Monsters, or nil
function MODEL.Live(kind)
	local folder = workspace:FindFirstChild("Monsters")
	if not folder then return nil end
	for _, m in folder:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("MonsterKind") == kind and m:GetAttribute("Golden") ~= true then return m end
	end
	return nil
end

-- a fresh copy of the kind's model: the server's CodexModels, else a live one (cached once), else nil
function MODEL.Get(kind)
	local tpl = MODEL.Cache[kind]
	if not tpl then
		local folder = ReplicatedStorage:FindFirstChild("CodexModels")
		local src = folder and folder:FindFirstChild(kind) or nil
		if not src then src = MODEL.Live(kind) end
		tpl = src and MODEL.Clean(src) or nil
		MODEL.Cache[kind] = tpl
	end
	if not tpl then return nil end
	local ok, copy = pcall(function() return tpl:Clone() end)
	return ok and copy or nil
end

---------------------------------------------------------------------------------------------------- the card
local function kit() return C and C.UIKit or nil end

local function call(name, ...)
	local k = kit()
	if type(k) ~= "table" or type(k[name]) ~= "function" then return nil end
	local ok, a, b = pcall(k[name], ...)
	if ok then return a, b end
	return nil
end

local function text(props, light)
	local t = call(light and "LightText" or "InkText", props)
	if t then return t end
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = light and Color3.new(1, 1, 1) or Color3.fromRGB(66, 40, 18)
	l.Font = Enum.Font.GothamBold
	l.TextScaled = props.TextScaled == true
	for k, v in props do
		if k ~= "Parent" and k ~= "Title" and k ~= "Number" and k ~= "MaxTextSize" and k ~= "Color" then
			pcall(function() l[k] = v end)
		end
	end
	l.Parent = props.Parent
	return l
end

local function rimOf(look)
	local rims = type(screen().Rim) == "table" and screen().Rim or {}
	return typeof(rims[look]) == "Color3" and rims[look] or Color3.new(1, 1, 1)
end

-- a card (front + back) in parent; c = its parts and state. size = UDim2
function CARD.New(parent, size, z)
	z = z or 1
	local c = { Tilt = Vector2.zero, Want = Vector2.zero, Back = false, View = nil, Model = nil, Center = Vector3.zero,
		Front = Vector3.new(0, 0, -1), Radius = 2 }
	local holder = Instance.new("Frame")
	holder.Name = "CodexCard"
	holder.BackgroundTransparency = 1
	holder.Size = size
	holder.ZIndex = z
	holder.Active = true
	holder.Parent = parent
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundTransparency = 1
	face.ZIndex = z
	face.Parent = holder
	local function plate(name)
		local f = call("ArtFrame", "PanelCard", { Name = name, Size = UDim2.fromScale(1, 1), ZIndex = z }, { BackgroundColor3 = L.Card })
		if not f then
			f = Instance.new("Frame")
			f.Name = name
			f.Size = UDim2.fromScale(1, 1)
			f.BackgroundColor3 = L.Card
		end
		f.ZIndex = z
		f.Parent = face
		local rim = Instance.new("UIStroke")
		rim.Name = "Rim"
		rim.Thickness = 3
		rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rim.Parent = f
		local corner = f:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = f
		return f, rim
	end
	c.FrontPlate, c.FrontRim = plate("Front")
	c.BackPlate, c.BackRim = plate("Back")
	c.BackPlate.Visible = false
	-- the 3D window
	local view = Instance.new("ViewportFrame")
	view.Name = "Monster3D"
	view.BackgroundTransparency = 1
	view.AnchorPoint = Vector2.new(0.5, 0)
	view.Position = UDim2.fromScale(0.5, L.View.Top)
	view.Size = UDim2.fromScale(0.88, L.View.H)
	view.Ambient, view.LightColor, view.LightDirection = L.Ambient, L.Light, L.LightDir
	view.ZIndex = z + 1
	view.Parent = c.FrontPlate
	local camera = Instance.new("Camera")
	camera.FieldOfView = L.Fov
	camera.Parent = view
	view.CurrentCamera = camera
	local world = Instance.new("WorldModel")
	world.Parent = view
	c.ViewFrame, c.Camera, c.World = view, camera, world
	-- the picture / "?" when there is no model
	c.Icon = Instance.new("ImageLabel")
	c.Icon.Name = "Icon"
	c.Icon.BackgroundTransparency = 1
	c.Icon.ScaleType = Enum.ScaleType.Fit
	c.Icon.Size = UDim2.fromScale(1, 1)
	c.Icon.Visible = false
	c.Icon.ZIndex = z + 1
	c.Icon.Parent = view
	c.Q = text({ Name = "Unknown", Text = tx("Unknown"), Size = UDim2.fromScale(1, 1), TextScaled = true, MaxTextSize = 64,
		Title = true, ZIndex = z + 2, Visible = false, Parent = view }, true)
	-- the sheen (a soft band that follows the tilt; Silver / Holo / Foil) and the round sparkles
	local sheen = Instance.new("Frame")
	sheen.Name = "Sheen"
	sheen.BackgroundColor3 = Color3.new(1, 1, 1)
	sheen.BorderSizePixel = 0
	sheen.Size = UDim2.fromScale(1, 1)
	sheen.ZIndex = z + 3
	sheen.Visible = false
	sheen.Parent = c.FrontPlate
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 12)
	sc.Parent = sheen
	local grad = Instance.new("UIGradient")
	grad.Rotation = 25
	grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.38, 1),
		NumberSequenceKeypoint.new(0.5, 0.72), NumberSequenceKeypoint.new(0.62, 1), NumberSequenceKeypoint.new(1, 1) })
	grad.Parent = sheen
	c.Sheen, c.SheenGrad = sheen, grad
	c.Sparkles = {}
	for i, at in L.Sparkles do
		local s = call("ArtImage", "RewardSparkle", { Name = "Sparkle" .. i, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(at[1], at[2]), Size = UDim2.fromScale(0.09, 0.066), ZIndex = z + 4, Visible = false,
			Parent = c.FrontPlate })
		if s then table.insert(c.Sparkles, s) end
	end
	-- the words: the stage chip, the foil badge, name, kills, next
	local chip = call("ArtImage", "Chip", { Name = "StageChip", Position = UDim2.fromScale(0.05, 0.025),
		Size = UDim2.fromScale(0.5, 0.07), ZIndex = z + 2, Parent = c.FrontPlate })
	c.StageText = text({ Name = "Stage", Text = "", Position = UDim2.fromScale(0.05, 0.025), Size = UDim2.fromScale(0.5, 0.07),
		TextScaled = true, MaxTextSize = 16, ZIndex = z + 3, Parent = c.FrontPlate }, chip == nil)
	c.FoilBadge = call("ArtImage", "IconGoldenMon", { Name = "FoilBadge", AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.95, 0.02), Size = UDim2.fromScale(0.13, 0.095), ZIndex = z + 3, Visible = false,
		Parent = c.FrontPlate })
	c.NameText = text({ Name = "MonsterName", Text = "", Position = UDim2.fromScale(0.06, 0.69), Size = UDim2.fromScale(0.88, 0.09),
		TextScaled = true, MaxTextSize = 22, Title = true, ZIndex = z + 2, Parent = c.FrontPlate }, true)
	c.KillsText = text({ Name = "Kills", Text = "", Position = UDim2.fromScale(0.06, 0.79), Size = UDim2.fromScale(0.88, 0.07),
		TextScaled = true, MaxTextSize = 17, ZIndex = z + 2, Parent = c.FrontPlate }, true)
	c.NextText = text({ Name = "Next", Text = "", Position = UDim2.fromScale(0.06, 0.87), Size = UDim2.fromScale(0.88, 0.065),
		TextScaled = true, MaxTextSize = 15, ZIndex = z + 2, Parent = c.FrontPlate }, true)
	-- the back
	local lines = {}
	local y = 0.05
	for _, spec in { { "BackName", 0.09, 22, true }, { "Lore", 0.3, 17 }, { "Where", 0.1, 15 }, { "Drops", 0.14, 15 },
		{ "BackKills", 0.08, 15 }, { "First", 0.08, 15 } } do
		local l = text({ Name = spec[1], Text = "", Position = UDim2.fromScale(0.07, y), Size = UDim2.fromScale(0.86, spec[2]),
			TextScaled = true, TextWrapped = true, MaxTextSize = spec[3], Title = spec[4] == true, ZIndex = z + 2,
			Parent = c.BackPlate }, true)
		lines[spec[1]] = l
		y += spec[2] + 0.02
	end
	c.Lines = lines
	c.Holder, c.FaceFrame = holder, face
	return c
end

-- puts the kind's monster in the 3D window (or its picture, or "?"); a card not met shows a black silhouette
function CARD.Mount(c, kind)
	for _, ch in c.World:GetChildren() do pcall(function() ch:Destroy() end) end
	c.Model, c.Kind = nil, kind
	local m = MODEL.Get(kind)
	if m then
		m.Parent = c.World
		local ok, cf, size = pcall(function() return m:GetBoundingBox() end)
		if ok and typeof(cf) == "CFrame" then
			c.Center, c.Radius = cf.Position, math.max(0.5, size.Magnitude / 2)
		end
		local okP, pivot = pcall(function() return m:GetPivot() end)
		c.Front = (okP and typeof(pivot) == "CFrame") and pivot.LookVector or Vector3.new(0, 0, -1)
		c.Model = m
	end
	local icon = (not m) and call("ArtId", "IconMon" .. tostring(kind)) or nil
	c.Icon.Image = icon or ""
	c.Icon.Visible = icon ~= nil
	c.Q.Visible = m == nil and icon == nil
	CARD.Aim(c)
end

-- the camera round the monster for the tilt (x = mouse right turns the card's right side away, y = mouse down)
function CARD.Aim(c)
	if not c.Model then return end
	local up = Vector3.yAxis
	local front = Vector3.new(c.Front.X, 0, c.Front.Z)
	front = front.Magnitude > 1e-3 and front.Unit or Vector3.new(0, 0, -1)
	local right = front:Cross(up)
	local yaw, pitch = math.rad(c.Tilt.X * L.Tilt.Yaw), math.rad(c.Tilt.Y * L.Tilt.Pitch + 8)
	local dir = CFrame.fromAxisAngle(up, yaw) * CFrame.fromAxisAngle(right, pitch) * front
	local dist = CodexUI.Fit(c.Radius, L.Fov)
	c.Camera.CFrame = CFrame.lookAt(c.Center + dir * dist, c.Center)
end

-- the tilt on screen: the camera, a small roll and the sheen's band
function CARD.Apply(c)
	CARD.Aim(c)
	c.FaceFrame.Rotation = c.Tilt.X * L.Tilt.Roll
	c.SheenGrad.Offset = Vector2.new(c.Tilt.X * L.Tilt.Sheen, c.Tilt.Y * L.Tilt.Sheen * 0.5)
end

-- draws a View (CodexUI.View) on the card
function CARD.Set(c, v)
	c.View = v
	if c.Kind ~= v.Kind or not c.Model then CARD.Mount(c, v.Kind) end -- (no model yet: look again)
	local rim = rimOf(v.Look)
	c.FrontRim.Color, c.BackRim.Color = rim, rim
	c.ViewFrame.ImageColor3 = v.Known and L.Lit or L.Silhouette
	c.Icon.ImageColor3 = v.Known and L.Lit or L.Silhouette
	local sheen = v.Look == "Silver" or v.Look == "Holo" or v.Look == "Foil"
	c.Sheen.Visible = sheen
	if v.Look == "Holo" then
		c.SheenGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 220)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(170, 230, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 160)) })
	elseif v.Look == "Foil" then
		c.SheenGrad.Color = ColorSequence.new(rimOf("Foil"))
	else
		c.SheenGrad.Color = ColorSequence.new(Color3.new(1, 1, 1))
	end
	local twinkle = v.Look == "Holo" or v.Look == "Foil"
	for _, s in c.Sparkles do s.Visible = twinkle end
	if c.FoilBadge then c.FoilBadge.Visible = v.Foil end
	c.StageText.Text = v.StageName
	c.NameText.Text = v.Name
	c.KillsText.Text = v.KillsText
	c.NextText.Text = v.NextText
	c.Lines.BackName.Text = v.Name
	c.Lines.Lore.Text = v.Lore
	c.Lines.Where.Text = v.Where
	c.Lines.Drops.Text = v.DropsText
	c.Lines.BackKills.Text = v.Known and v.KillsText or ""
	c.Lines.First.Text = v.FirstText
	CARD.Apply(c)
end

-- shows the back (true) or the front; animated = a quick turn (squeeze, swap, open)
function CARD.Flip(c, back, animated)
	if c.Back == back then return end
	c.Back = back
	local function swap()
		c.FrontPlate.Visible = not back
		c.BackPlate.Visible = back
	end
	if not animated or call("ReducedMotion") then
		swap()
		return
	end
	local half = TweenInfo.new(L.Flip, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local tw = TweenService:Create(c.FaceFrame, half, { Size = UDim2.fromScale(0, 1) })
	tw.Completed:Connect(function()
		swap()
		TweenService:Create(c.FaceFrame, TweenInfo.new(L.Flip, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(1, 1) }):Play()
	end)
	tw:Play()
end

-- one frame of motion: the tilt eases to its goal (dt s)
function CARD.Step(c, dt)
	local k = 1 - math.exp(-L.Tilt.Ease * math.clamp(dt, 0, 0.1))
	c.Tilt = c.Tilt:Lerp(c.Want, k)
	CARD.Apply(c)
end

function CARD.Destroy(c)
	if c and c.Holder then pcall(function() c.Holder:Destroy() end) end
end

---------------------------------------------------------------------------------------------------- the window
local function faction()
	return LocalPlayer and LocalPlayer:GetAttribute("Faction") or nil
end

local function disconnect()
	for _, conn in VIEW.Conns do pcall(function() conn:Disconnect() end) end
	table.clear(VIEW.Conns)
end

local function fireOpen()
	if os.clock() - S.OpenAt < L.OpenGap then return end
	S.OpenAt = os.clock()
	pcall(function() Net.Get("CodexOpen"):FireServer() end)
end

local function viewOf(kind)
	return CodexUI.View(kind, cardOf(S.Cards, kind), faction(), S.Foil)
end

local drawWindow -- forward

local function pick(kind)
	if S.Kind ~= kind then S.Back, S.Foil = false, false end
	S.Kind = kind
	drawWindow()
end

local function slot(parent, kind, order)
	local v = CodexUI.View(kind, cardOf(S.Cards, kind), faction(), false)
	local btn, _ = call("ArtButton", v.Known and "SlotCommon" or "SlotEmpty", { Name = "Slot" .. kind, LayoutOrder = order,
		Size = UDim2.fromOffset(L.SlotW, L.SlotH) }, function() pick(kind) end)
	if not btn then
		btn = Instance.new("TextButton")
		btn.Name = "Slot" .. kind
		btn.Text = ""
		btn.LayoutOrder = order
		btn.Size = UDim2.fromOffset(L.SlotW, L.SlotH)
		btn.BackgroundColor3 = L.Card
		btn.Activated:Connect(function() pick(kind) end)
	end
	btn.Parent = parent
	local rim = Instance.new("UIStroke")
	rim.Name = "Rim"
	rim.Thickness = kind == S.Kind and 4 or 2
	rim.Color = kind == S.Kind and rimOf("Holo") or rimOf(v.Look)
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Parent = btn
	local mini = CARD.New(btn, UDim2.new(1, -10, 1, -40), btn.ZIndex + 1)
	mini.Holder.Position = UDim2.fromOffset(5, 5)
	mini.Holder.Active = false
	for _, n in { "StageChip", "Stage", "MonsterName", "Kills", "Next" } do
		local p = mini.FrontPlate:FindFirstChild(n)
		if p then p.Visible = false end
	end
	mini.ViewFrame.Position, mini.ViewFrame.Size = UDim2.fromScale(0.5, 0.05), UDim2.fromScale(0.9, 0.9)
	CARD.Set(mini, v)
	text({ Name = "SlotName", Text = v.Short, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -10, 0, 28), TextScaled = true, MaxTextSize = 15, ZIndex = btn.ZIndex + 2, Parent = btn }, true)
	return btn
end

drawWindow = function()
	local root, k = VIEW.Root, VIEW.Kit
	if not (root and root.Parent and k) then return end
	local pages = type(codex().Pages) == "table" and codex().Pages or {}
	S.Page = math.clamp(S.Page, 1, math.max(1, #pages))
	local page = CodexUI.Page(S.Cards, S.Page)
	if not page then return end
	if not S.Kind or codex().PageOf[S.Kind] ~= S.Page then S.Kind = page.Kinds[1] end
	-- tabs + count
	for i, b in VIEW.Tabs or {} do
		local on = i == S.Page
		pcall(k.Paint, b, on and k.Theme.Gold or k.Palette.Button, on and k.Palette.DarkText or k.Theme.Text)
	end
	local owned, total = CodexUI.Count(S.Cards)
	if VIEW.Count then VIEW.Count.Text = tx("Count", owned, total) end
	-- the slots
	for _, ch in VIEW.Grid:GetChildren() do
		if not ch:IsA("UIGridLayout") then ch:Destroy() end
	end
	for i, kind in page.Kinds do slot(VIEW.Grid, kind, i) end
	-- the big card
	local v = viewOf(S.Kind)
	if not v.HasFoil then S.Foil = false; v = viewOf(S.Kind) end
	CARD.Set(VIEW.Big, v)
	CARD.Flip(VIEW.Big, S.Back and v.Known, false)
	local b = VIEW.Buttons or {}
	if b.Flip then b.Flip.Visible = v.Known end
	if b.FlipText then b.FlipText.Text = S.Back and tx("Front") or tx("Flip") end
	if b.Foil then b.Foil.Visible = v.HasFoil end
	if b.FoilText then b.FoilText.Text = S.Foil and tx("ShowCard") or tx("ShowFoil") end
	if b.TiltText then b.TiltText.Text = tx("Tilt") end
end

local function button(parent, name, order, onClick)
	local b, label = call("ArtButton", "BtnSecondary", { Name = name, LayoutOrder = order, Text = "",
		Size = UDim2.fromOffset(L.ButtonW, L.ButtonH), TextSize = 16 }, onClick)
	if not b then
		b = Instance.new("TextButton")
		b.Name = name
		b.LayoutOrder = order
		b.Size = UDim2.fromOffset(L.ButtonW, L.ButtonH)
		b.Text = ""
		b.Activated:Connect(onClick)
		label = b
	end
	b.Parent = parent
	return b, label or b
end

-- the mouse / a finger over the big card -> its tilt goal; a short click / tap flips it
local function wireBig(c)
	local press = nil
	-- an input's screen point in the card's own space (a ScreenGui that ignores the top bar inset counts from the
	-- screen's very top; InputObject.Position does not)
	local function goal(input)
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		local gui = c.Holder:FindFirstAncestorWhichIsA("ScreenGui")
		if gui and gui.IgnoreGuiInset then
			local ok, inset = pcall(function() return game:GetService("GuiService"):GetGuiInset() end)
			if ok and typeof(inset) == "Vector2" then pos += inset end
		end
		local abs, at = c.Holder.AbsoluteSize, c.Holder.AbsolutePosition
		if abs.X <= 0 or abs.Y <= 0 then return end
		local x, y = CodexUI.Tilt((pos.X - at.X) / abs.X * 2 - 1, (pos.Y - at.Y) / abs.Y * 2 - 1)
		c.Want = Vector2.new(x, y)
	end
	table.insert(VIEW.Conns, c.Holder.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			press = { Input = input, At = os.clock(), Pos = input.Position }
		end
	end))
	table.insert(VIEW.Conns, c.Holder.InputChanged:Connect(function(input)
		if S.Auto then return end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseMovement or (t == Enum.UserInputType.Touch and press and input == press.Input) then
			goal(input)
		end
	end))
	table.insert(VIEW.Conns, c.Holder.MouseLeave:Connect(function()
		if not S.Auto then c.Want = Vector2.zero end
	end))
	table.insert(VIEW.Conns, UserInputService.InputEnded:Connect(function(input)
		if not press then return end
		local t = input.UserInputType
		if input == press.Input or t == Enum.UserInputType.MouseButton1 then
			local moved = (Vector2.new(input.Position.X, input.Position.Y) - Vector2.new(press.Pos.X, press.Pos.Y)).Magnitude
			local quick = os.clock() - press.At < 0.35 and moved < 12
			press = nil
			if t == Enum.UserInputType.Touch and not S.Auto then c.Want = Vector2.zero end
			if quick and c.View and c.View.Known then
				S.Back = not S.Back
				CARD.Flip(c, S.Back, true)
				drawWindow()
			end
		end
	end))
end

local function build(parent, k, arg)
	disconnect()
	VIEW.Root, VIEW.Kit = parent, k
	if type(arg) == "table" and type(arg.Kind) == "string" and codex().PageOf and codex().PageOf[arg.Kind] then
		S.Kind, S.Page, S.Back, S.Foil = arg.Kind, codex().PageOf[arg.Kind], false, false
	end
	fireOpen()
	-- tabs + count
	local bar = Instance.new("Frame")
	bar.Name = "Tabs"
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, 0, 0, L.TabH)
	bar.Parent = parent
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.Parent = bar
	VIEW.Tabs = {}
	local pages = type(codex().Pages) == "table" and codex().Pages or {}
	for i in pages do
		local p = CodexUI.Page(S.Cards, i)
		local b = k.Button(bar, p and p.Name or "", k.Palette.Button, UDim2.new(0, 132, 1, 0), function()
			S.Page, S.Kind, S.Back, S.Foil = i, nil, false, false
			drawWindow()
		end)
		b.LayoutOrder = i
		VIEW.Tabs[i] = b
	end
	VIEW.Count = text({ Name = "Count", Text = "", LayoutOrder = 99, Size = UDim2.new(0, 160, 1, 0), TextScaled = true,
		MaxTextSize = 18, TextXAlignment = Enum.TextXAlignment.Right, Parent = bar }, true)
	-- the slots
	local top = L.TabH + L.Gap
	local grid = Instance.new("Frame")
	grid.Name = "Cards"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(0, top)
	grid.Size = UDim2.new(0, L.SlotW * L.Columns + L.Gap * (L.Columns - 1), 1, -top)
	grid.Parent = parent
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(L.SlotW, L.SlotH)
	gl.CellPadding = UDim2.fromOffset(L.Gap, L.Gap)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid
	VIEW.Grid = grid
	-- the big card + its buttons
	local right = Instance.new("Frame")
	right.Name = "Big"
	right.BackgroundTransparency = 1
	right.Position = UDim2.new(1, -L.RightW, 0, top)
	right.Size = UDim2.new(0, L.RightW, 1, -top)
	right.Parent = parent
	VIEW.Big = CARD.New(right, UDim2.fromOffset(L.CardW, L.CardH), 5)
	VIEW.Big.Holder.AnchorPoint = Vector2.new(0.5, 0)
	VIEW.Big.Holder.Position = UDim2.fromScale(0.5, 0)
	wireBig(VIEW.Big)
	local row = Instance.new("Frame")
	row.Name = "Buttons"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, L.CardH + L.Gap)
	row.Size = UDim2.new(1, 0, 0, L.ButtonH)
	row.Parent = right
	local rl = Instance.new("UIListLayout")
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rl.Padding = UDim.new(0, 6)
	rl.SortOrder = Enum.SortOrder.LayoutOrder
	rl.Parent = row
	local b = {}
	b.Flip, b.FlipText = button(row, "Flip", 1, function()
		if not (VIEW.Big.View and VIEW.Big.View.Known) then return end
		S.Back = not S.Back
		CARD.Flip(VIEW.Big, S.Back, true)
		drawWindow()
	end)
	b.Tilt, b.TiltText = button(row, "AutoTilt", 2, function()
		S.Auto = not S.Auto
		if not S.Auto then VIEW.Big.Want = Vector2.zero end
	end)
	b.Foil, b.FoilText = button(row, "Foil", 3, function()
		S.Foil = not S.Foil
		drawWindow()
	end)
	VIEW.Buttons = b
	-- motion while open
	local t0 = os.clock()
	table.insert(VIEW.Conns, RunService.RenderStepped:Connect(function(dt)
		local c = VIEW.Big
		if not (c and c.Holder.Parent) then return end
		if S.Auto then
			local a = (os.clock() - t0) * L.Tilt.Auto * 2 * math.pi
			c.Want = Vector2.new(math.sin(a) * 0.85, math.cos(a * 0.7) * 0.5)
		end
		CARD.Step(c, dt)
	end))
	drawWindow()
	return nil
end

local function cleanup()
	disconnect()
	VIEW.Root, VIEW.Kit, VIEW.Tabs, VIEW.Grid, VIEW.Big, VIEW.Buttons, VIEW.Count = nil, nil, nil, nil, nil, nil, nil
	S.Auto = false
end

local function windowOpen()
	return VIEW.Root ~= nil and VIEW.Root.Parent ~= nil
end

---------------------------------------------------------------------------------------------------- moments
local function quiet()
	if not LocalPlayer or LocalPlayer:GetAttribute("DataLoaded") ~= true then return false end
	local hold = call("ShouldHoldBanners")
	return hold ~= true
end

-- one moment: the card in the middle (Reveal: from its silhouette / its card to the foil; Evolve: the old stage sways
-- into the new one) with the line under it; done() when it has gone
function MOMENT.Card(payload, done)
	local k = kit()
	local gui = type(k) == "table" and k.Gui or nil
	local kind = payload.Kind
	if not (gui and type(kind) == "string") then done(); return end
	local reduced = call("ReducedMotion") == true
	local frame = Instance.new("Frame")
	frame.Name = "CodexMoment"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, L.Moment.Y)
	frame.Size = UDim2.fromOffset(L.Moment.W, L.Moment.H + 70)
	frame.ZIndex = L.Moment.Z
	frame.Parent = gui
	local pop = Instance.new("UIScale")
	pop.Scale = reduced and 1 or 0.6
	pop.Parent = frame
	local c = CARD.New(frame, UDim2.fromOffset(L.Moment.W, L.Moment.H), L.Moment.Z)
	local after = CodexUI.View(kind, payload.Card or cardOf(S.Cards, kind), faction(), payload.Event == "Golden")
	local before = table.clone(after)
	if payload.Event == "Card" then
		before = CodexUI.View(kind, nil, faction(), false)
	elseif payload.Event == "Golden" then
		before = CodexUI.View(kind, payload.Card or cardOf(S.Cards, kind), faction(), false)
	elseif payload.Event == "Silver" or payload.Event == "Holo" then
		local prev = table.clone(type(payload.Card) == "table" and payload.Card or (cardOf(S.Cards, kind) or {}))
		prev.Stage = math.max(1, int(after.Stage) - 1)
		prev.Kills = math.min(int(prev.Kills), (Config.CodexSteps(kind)[after.Stage] or 1) - 1)
		before = CodexUI.View(kind, prev, faction(), false)
	end
	CARD.Set(c, before)
	local line = text({ Name = "Line", Text = tostring(payload.Text or ""), AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, L.Moment.H + 8), Size = UDim2.new(1.6, 0, 0, 56), TextScaled = true, TextWrapped = true,
		MaxTextSize = 24, Title = true, ZIndex = L.Moment.Z + 5, Parent = frame }, true)
	local gone = false
	local function finish()
		if gone then return end
		gone = true
		if MOMENT.Conn then MOMENT.Conn:Disconnect(); MOMENT.Conn = nil end
		if reduced then
			frame:Destroy()
			done()
			return
		end
		local tw = TweenService:Create(pop, TweenInfo.new(L.Moment.Out), { Scale = 0.6 })
		TweenService:Create(line, TweenInfo.new(L.Moment.Out), { TextTransparency = 1 }):Play()
		tw.Completed:Connect(function()
			frame:Destroy()
			done()
		end)
		tw:Play()
	end
	c.Holder.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then finish() end
	end)
	MOMENT.Frame = frame
	local t0, swapped = os.clock(), false
	if not reduced then
		TweenService:Create(pop, TweenInfo.new(L.Moment.In, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		MOMENT.Conn = RunService.RenderStepped:Connect(function(dt)
			local t = os.clock() - t0 - L.Moment.In
			if t >= 0 and t <= L.Moment.Evolve then -- the sway: right, then back through the middle
				c.Want = Vector2.new(math.sin(t / L.Moment.Evolve * 2 * math.pi), 0.2)
				if not swapped and t >= L.Moment.Evolve / 2 then
					swapped = true
					CARD.Set(c, after)
				end
			else
				c.Want = Vector2.zero
			end
			CARD.Step(c, dt)
		end)
	else
		CARD.Set(c, after)
	end
	local hold = tonumber(type(screen().Moment) == "table" and screen().Moment.Hold) or 2.6
	task.delay(L.Moment.In + L.Moment.Evolve + hold, finish)
end

-- a page done / every card Gold Holo: the shared reward popup with the line; done() when it closes
function MOMENT.Popup(payload, done)
	local popup = call("RewardPopup", {
		Title = tostring(type(codex().Text) == "table" and codex().Text.Name or ""),
		Lines = { tostring(payload.Text or "") },
		Button = tx("Ok"),
		Faction = faction(),
	})
	local frame = type(popup) == "table" and popup.Frame or nil
	if not frame then
		call("Toast", tostring(payload.Text or ""), "reward")
		done()
		return
	end
	task.spawn(function()
		while frame.Parent do task.wait(0.25) end
		done()
	end)
end

-- shows the waiting moments one after another (on a quiet screen)
function MOMENT.Pump()
	if S.Busy or #S.Queue == 0 then return end
	if not quiet() then
		task.delay(L.Moment.Retry, MOMENT.Pump)
		return
	end
	local payload = table.remove(S.Queue, 1)
	S.Busy = true
	local function done()
		S.Busy = false
		MOMENT.Frame = nil
		task.defer(MOMENT.Pump)
	end
	local how = CodexUI.MomentOf(payload.Event)
	local ok, err = pcall(how == "Popup" and MOMENT.Popup or MOMENT.Card, payload, done)
	if not ok then
		Util.Warn(TAG, "moment failed: " .. tostring(err))
		done()
	end
end

---------------------------------------------------------------------------------------------------- data
function CodexUI.OnCodex(payload)
	if type(payload) ~= "table" then return end
	S.Cards = type(Config.SanitizeCodex) == "function" and Config.SanitizeCodex(payload.Cards) or {}
	S.Glow, S.Got = payload.Glow == true, true
	if windowOpen() then pcall(drawWindow) end
end

function CodexUI.OnUp(payload)
	if type(payload) ~= "table" or not CodexUI.MomentOf(payload.Event) then return end
	local kind = payload.Kind
	if type(kind) == "string" and type(payload.Card) == "table" and type(Config.SanitizeCodex) == "function" then
		local one = Config.SanitizeCodex({ [kind] = payload.Card })[kind]
		if one then S.Cards[kind] = one end
	end
	if windowOpen() and CodexUI.MomentOf(payload.Event) ~= "Popup" then
		if type(kind) == "string" and codex().PageOf and codex().PageOf[kind] then
			S.Page, S.Kind, S.Back = codex().PageOf[kind], kind, false
			S.Foil = payload.Event == "Golden"
		end
		pcall(drawWindow)
		call("Toast", tostring(payload.Text or ""), "reward")
		return
	end
	CodexUI.Push(S.Queue, payload)
	MOMENT.Pump()
end

---------------------------------------------------------------------------------------------------- lifecycle
function CodexUI.IsReady()
	return S.Ready
end

function CodexUI.Open(arg)
	local panels = C and C.Panels
	if not S.Ready or type(panels) ~= "table" or type(panels.Open) ~= "function" then return false end
	return (pcall(panels.Open, L.Window, arg))
end

CodexUI._T = { L = L, S = S, VIEW = VIEW, CARD = CARD, MODEL = MODEL, MOMENT = MOMENT } -- tools/test_codex_ui.py, the sandbox photo

function CodexUI.Init(registry)
	C = registry
	local panels = C and C.Panels
	if type(codex().Screen) ~= "table" or codex().Enabled == false then return end
	if type(panels) ~= "table" or type(panels.Register) ~= "function" then
		Util.Warn(TAG, "Panels.Register is missing; the codex window is off")
		return
	end
	S.Ready = panels.Register(L.Window, {
		Title = function()
			local t = type(codex().Text) == "table" and codex().Text.Name or nil
			return type(t) == "string" and t or ""
		end,
		FixedBody = true,
		Width = L.Width,
		Rebuild = { Faction = true },
		Build = build,
		Cleanup = cleanup,
	}) == true
end

function CodexUI.Start()
	if not S.Ready then return end
	task.spawn(function()
		local ok, err = pcall(function()
			Net.Get("Codex").OnClientEvent:Connect(function(payload)
				local fine, why = pcall(CodexUI.OnCodex, payload)
				if not fine then Util.Warn(TAG, "codex failed: " .. tostring(why)) end
			end)
			Net.Get("CodexUp").OnClientEvent:Connect(function(payload)
				local fine, why = pcall(CodexUI.OnUp, payload)
				if not fine then Util.Warn(TAG, "codex moment failed: " .. tostring(why)) end
			end)
		end)
		if not ok then Util.Warn(TAG, "remote hookup failed: " .. tostring(err)) end
	end)
end

return CodexUI
