-- QuestMarker.luau : the quest target marker (SPEC_ADDENDUM A23-36, user 2026-10-06: "퀘스트 장소를 이렇게 표시하자" -
-- a small floating diamond + "33m"). One marker at a time, for the pinned quest row's place:
--   source  : C.HUD.QuestTarget() -> QuestTarget.ForEntry result { Part, Position, Tag, Claim, ... } | nil (2 Hz;
--             nothing is drawn while HUD does not expose it)
--   colour  : in progress white, done and waiting for [Claim] light gold (검수 2026-10-06 "하늘색/흰색, 받기 금";
--             Config.UIArt.Colors MarkerGo / MarkerClaim tint the white IconQuestMarker art). White + the art's navy
--             rim keep >= 3:1 on every zone floor and sky (rubric 4); sky blue fell to 2.2:1 on dark meadow grass.
--   size    : the icon is 48 real px up to T.NearM metres, then smaller with the distance down to 32 px from T.FarM on
--             (검수 2026-10-06 48 px; 10/09: far looks far), the distance always 15 px (rubric >= 14 px); du = px / the
--             HUD's UIScale (T.Fit)
--   drawn   : in its own ScreenGui "QuestMarkerGui" just under MainGui (same inset / safe-area settings and UIScale, one
--             DisplayOrder lower), so it is always in front of the 3D world (never hidden behind a wall or a hill) and
--             the HUD stays on top of it. Placed every frame after the camera (BindToRenderStep).
--   on screen : the icon at the point above the target (part top + T.LiftFor(metres) studs: higher for far goals), the
--             distance "Nm" under it (metres = studs / 3.5, rounded); never on my character (head, body, halo / horns:
--             it rises just above them) or on a HUD block
--   off screen / behind the camera: the same icon + the arrow turned toward the target + the distance at the screen
--             edge, kept inside the screen minus T.Margin and pushed out of the HUD blocks of C.HUD.Layout.Rects (minimap
--             + quest lines, the plate + icon tiles, the top centre column, the combat cluster, [Menu]) and, on touch,
--             out of the thumbstick zone. Where the edge is all HUD (phones) it walks in along the ray to the spot
--             covering the least HUD, which rings my character.
--   near    : fades out inside T.FadeM metres, hidden inside T.HideM
--   hidden  : HUD.IsVisible() false, the world map / a panel / the opening open, no target, no character
-- (A world BillboardGui was tried first: AlwaysOnTop billboards do not show in Studio MCP screen captures, so the marker
-- could never be checked on the sheets; the screen-space marker looks the same and is checkable.)
-- Icon: Config.UIArt parts "IconQuestMarker" (white diamond, tinted by code) and "IconQuestMarkerArrow" (points up,
-- Rotation turns it) through UIKit.ArtImage when they exist, else the code fallbacks (a tinted Frame turned 45 degrees
-- with a navy rim and a white dot, a "▲" text; IMG-R4). The distance is UIKit's "Number" text style.
-- A thin dark halo (the same art, dark, half see-through, T.HaloPx larger) sits under the icon and the arrow so they keep
-- >= 3:1 next to bright lamps and on light grass (검수 2026-10-06).
-- Presentation only: every instance is Active = false and nothing is a button, so no input is ever sunk.
--
-- A23-68 #2 (user 2026-10-07 "그 자리 힌트"): game dev 1 points at the nearest slime of my first mission
-- (QuestMarker.Focus(model), picked again every 0.5 s; nil after the first kill): a smaller copy of the marker art
-- (T.FocusPx, white, no distance, no edge arrow) floats just over that monster's name tag (or its head when the tag is
-- off) and bobs a little (not with ReducedMotion). Hidden whenever the marker hides (HUD hidden, map / window /
-- opening), when the monster is gone or dead, and while it is off screen.
--
-- Public API: QuestMarker.Init(C), QuestMarker.Start(), QuestMarker.Refresh(), QuestMarker.IsShown(),
-- QuestMarker.Focus(model | nil), QuestMarker.Pulse() -> bool
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer

local QuestMarker = {}

local TAG = "QuestMarker"
local C = nil -- client registry (set in Init)
local UIKit = nil -- C.UIKit (set in Start)

----------------------------------------------------------------- tuning (du = logical HUD units; px; studs)
local IS_TOUCH = UserInputService.TouchEnabled
local T = {
	TargetDt = 1 / 2, -- ask HUD for the target
	StudsPerMeter = 3.5, -- A23-36: metres = studs / 3.5, rounded
	PulseFrom = 1.7, PulseTime = 0.45, -- 빛 마을 점검 #20: a row tap pops the icon from this size back to 1 (s)
	FadeM = 10, -- starts fading inside this many metres...
	HideM = 6, -- ...and is gone inside this many
	Lift = 3, -- studs above the target part's top (or above a bare position)...
	-- 검수 10/09 (user photo: a 49m goal straight ahead floated on my halo, "too close"): ...plus LiftPerM studs per
	-- metre past NearM (at most LiftMax), so a far goal floats over the horizon
	LiftPerM = 0.15,
	LiftMax = 12,
	-- sizes in REAL screen px; du = px / UIScale (T.Fit)
	IconPx = 48, -- 검수 2026-10-06: 48 px - up to NearM metres away...
	IconFarPx = 32, -- ...then smaller with the distance, down to this from FarM metres on (검수 10/09: far looks far)
	NearM = 20,
	FarM = 60,
	ArrowPx = 24, -- the edge arrow at the 48 px icon (smaller with it, never under ArrowMinPx)
	ArrowMinPx = 18,
	-- my character on screen (studs around the HumanoidRootPart: half width, up to the halo / horns, down to the feet):
	-- the on-screen marker never sits on it (검수 10/09); skipped when the camera is this close (first person)
	Self = { HalfW = 1.8, Up = 4.6, Down = 3.2, MinCam = 3 },
	TextPx = 15, -- rubric: text over the 3D world >= 14 px
	TextWPx = 64, -- "123m" never clips
	HaloPx = 3, -- the dark halo is this much larger than the art (about 1.5 px on each side)
	HaloAlpha = 0.45, -- its transparency
	Margin = 48, -- kept from every screen edge (du)
	TopBar = 60, -- Roblox top bar: the indicator stays below it
	Pad = 6, -- kept between the indicator and a HUD block
	StickX = 0.4, -- touch thumbstick zone: x < StickX * W and y > H * StickTop
	StickTop = 1 / 3,
	WalkSteps = 16, -- crowded screens: spots tried along the ray between the edge and MinRing
	-- crowded screens: how much covering a rect counts (the notify column / chips are mostly see-through text)
	Weight = { notify = 0.2, chips = 0.6 },
	MinMove = 0.25, -- du: smaller moves are not written
	MinTurn = 1, -- degrees
	ArtKey = "IconQuestMarker",
	ArrowKey = "IconQuestMarkerArrow",
	-- A23-68 #2 focus (QuestMarker.Focus): real px size, gap over the monster's name tag, bob (px, Hz)
	FocusPx = 30,
	FocusGapPx = 4,
	FocusBobPx = 3,
	FocusHz = 1.1,
	Step = "QuestMarker", -- BindToRenderStep name (after the camera)
	WarnEvery = 10,
}
-- the indicator in du for the HUD's UIScale s and the icon's real px (T.IconPxFor; default IconPx): icon, arrow, label,
-- the footprint half-size around the icon centre (icon + arrow beside it + label under it) and the ring it never enters
-- around the screen centre (my character)
function T.Fit(s, px)
	px = px or T.IconPx
	T.Icon = math.ceil(px / s)
	T.Arrow = math.ceil(math.max(T.ArrowMinPx, T.ArrowPx * px / T.IconPx) / s)
	T.Text = math.ceil(T.TextPx / s)
	T.TextW = math.ceil(T.TextWPx / s)
	T.Halo = T.HaloPx / s
	T.HalfX = math.max(T.Icon / 2 + T.Arrow + 2, T.TextW / 2) + T.Pad
	T.HalfY = T.Icon / 2 + math.max(T.Arrow, T.Text + 4) + T.Pad
	T.MinRing = T.Icon + T.Arrow + 8
end
T.Fit(1)

-- the icon's real px for a goal `m` metres away (2 px steps, so a walk does not re-fit every frame) and the lift (studs)
function T.IconPxFor(m)
	local k = math.clamp((m - T.NearM) / math.max(1, T.FarM - T.NearM), 0, 1)
	return math.floor((T.IconPx + (T.IconFarPx - T.IconPx) * k) / 2 + 0.5) * 2
end

function T.LiftFor(m)
	return math.min(T.LiftMax, T.Lift + T.LiftPerM * math.max(0, m - T.NearM))
end

-- HUD layout B blocks the edge indicator stays out of (C.HUD.Layout.Rects ids, each group = one union box)
local AVOID = {
	{ "minimap", "quest" }, -- top-left minimap + quest lines
	{ "portrait", "hp_bar", "mp_bar", "power_line", "xp_bar", "tiles" }, -- the bottom-centre face / bars / icon row
	{ "war_meter", "chips", "event", "notify" }, -- top centre column
	{ "ghost", "q", "z", "x", "auto", "attack" }, -- bottom-right combat cluster (x: A23-49 SkillBar)
	{ "menu" }, -- [Menu] in the Roblox top bar's right end (A23-40 보강)
}
-- the potion pair (HudLayout 2026-10-07): PCs end the bottom-centre row with it, phones put it on the thumb ring
table.insert(IS_TOUCH and AVOID[4] or AVOID[2], "potions")

----------------------------------------------------------------- colours / text
local COL = {
	Go = Color3.fromRGB(255, 255, 255), -- in progress: white (ArtColors.MarkerGo, copied in at build)
	Claim = Color3.fromRGB(255, 228, 128), -- done, waiting for [Claim]: light gold (ArtColors.MarkerClaim)
	Rim = Color3.fromRGB(26, 40, 79), -- ArtColors.Navy: dark navy outline over 3D
	Dot = Color3.new(1, 1, 1),
	Halo = Color3.fromRGB(8, 12, 28), -- the dark halo under the art (never tinted)
}
local TXT = {
	Distance = "%dm",
	Arrow = "▲", -- points up at Rotation 0 (turned toward the target)
}

----------------------------------------------------------------- state
local S = {
	built = false,
	shown = false, -- the marker is showing (on screen or at the edge)
	target = nil, -- { Part, Position, Tag, Claim } from the last retarget
	claim = nil, -- the colour last written (true = gold)
	scale = nil, -- the UIScale T.Fit last sized the marker for
	iconPx = nil, -- ...and the icon's real px (T.IconPxFor)
	meters = nil, -- last written distance
	alpha = nil, -- last written fade (0..1)
	onScreen = nil,
	posX = nil, posY = nil, rot = nil, labelUp = nil,
	layoutRef = nil, layoutW = nil, layoutH = nil, qbRef = nil, -- the HUD.Layout the avoid boxes were built from
	avoid = {}, -- HUD block unions { { x0, y0, x1, y1 } } in du, inflated by the indicator's footprint
	edgeAvoid = {}, -- placeEdge's list: avoid + my character's box (refilled every frame)
	raw = {}, -- the single HUD rects (+ thumbstick zone), not inflated
	targetAcc = 0,
	lastWarnAt = -math.huge,
	focus = nil, -- A23-68 #2: the monster (Model / BasePart) QuestMarker.Focus points at
	focusBar = nil, -- its MonsterBar BillboardGui (name tag + HP bar), when it has one
	focusSize = nil, -- du the focus icon was last sized to
}
local ui = {} -- gui, scale, holder, iconBox, icon, iconHalo, arrow, arrowHalo, text
local fades = {} -- { { inst, prop, base } }
local tinted = {} -- { { inst, colour property } } recoloured by setTint

----------------------------------------------------------------- helpers
local function warnThrottled(msg)
	local now = os.clock()
	if now - S.lastWarnAt < T.WarnEvery then return end
	S.lastWarnAt = now
	Util.Warn(TAG, msg)
end

local function guard(fn, what)
	local ok, err = pcall(fn)
	if not ok then warnThrottled(what .. " error: " .. tostring(err)) end
end

local function num(v)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return nil
end

local function moduleOpen(name)
	local m = C and C[name]
	if type(m) ~= "table" or type(m.IsOpen) ~= "function" then return false end
	local ok, open = pcall(m.IsOpen)
	return ok and open == true
end

local function hudShowing()
	local hud = C and C.HUD
	if type(hud) ~= "table" then return false end
	if type(hud.IsVisible) == "function" then
		local ok, visible = pcall(hud.IsVisible)
		return ok and visible == true
	end
	return LocalPlayer:GetAttribute("DataLoaded") == true
end

local function myRoot()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and root:IsA("BasePart") and root or nil
end

-- MainGui's UIScale (logical du -> px)
local function guiScale()
	local gui = UIKit and UIKit.Gui
	local sc = gui and gui:FindFirstChildOfClass("UIScale")
	local s = sc and num(sc.Scale) or nil
	if not s or s <= 0 then
		local layout = C and type(C.HUD) == "table" and C.HUD.Layout or nil
		s = type(layout) == "table" and num(layout.Scale) or 1
	end
	return (s and s > 0) and s or 1
end

-- records every fadeable property under root with its current value as the "fully shown" base
local function collectFades(root)
	local function add(inst)
		if inst:IsA("ImageLabel") then
			table.insert(fades, { inst, "ImageTransparency", inst.ImageTransparency })
		elseif inst:IsA("TextLabel") then
			table.insert(fades, { inst, "TextTransparency", inst.TextTransparency })
		elseif inst:IsA("UIStroke") then
			table.insert(fades, { inst, "Transparency", inst.Transparency })
		end
		if inst:IsA("GuiObject") and inst.BackgroundTransparency < 1 then
			table.insert(fades, { inst, "BackgroundTransparency", inst.BackgroundTransparency })
		end
	end
	add(root)
	for _, d in root:GetDescendants() do add(d) end
end

----------------------------------------------------------------- drawing
local function tint(inst, prop)
	table.insert(tinted, { inst, prop })
	return inst
end

-- the dark halo under an art image: the same image, dark, half see-through, one layer lower (sized by the caller)
local function halo(art)
	local h = art:Clone()
	h.Name = art.Name .. "Halo"
	h.ImageColor3 = COL.Halo
	h.ImageTransparency = T.HaloAlpha
	h.ZIndex = art.ZIndex - 1
	h.Parent = art.Parent
	return h
end

-- the marker icon filling `box`: the IconQuestMarker art tinted by state, else the code diamond (IMG-R4)
local function makeIcon(box)
	local art = UIKit.ArtImage(T.ArtKey, {
		Name = "Icon",
		Size = UDim2.fromScale(1, 1),
		ImageColor3 = COL.Go,
		ZIndex = 3,
		Active = false,
		Parent = box,
	})
	if art then
		ui.iconHalo = halo(art)
		ui.iconHalo.AnchorPoint = Vector2.new(0.5, 0.5)
		ui.iconHalo.Position = UDim2.fromScale(0.5, 0.5)
		ui.iconHalo.Size = UDim2.new(1, T.Halo, 1, T.Halo)
		return tint(art, "ImageColor3")
	end
	local diamond = UIKit.Create("Frame", {
		Name = "Diamond",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.66, 0.66), -- turned 45 degrees: the corners reach ~0.93 of the box
		Rotation = 45,
		BackgroundColor3 = COL.Go,
		ZIndex = 3,
		Active = false,
		Parent = box,
	}, {
		UIKit.Create("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIKit.Create("UIStroke", { Color = COL.Rim, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	UIKit.Create("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.34, 0.34),
		BackgroundColor3 = COL.Dot,
		ZIndex = 3,
		Active = false,
		Parent = diamond,
	}, {
		UIKit.Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})
	return tint(diamond, "BackgroundColor3")
end

-- the edge arrow: the IconQuestMarkerArrow art (points up), else a "▲" text (IMG-R4)
local function makeArrow(parent)
	local props = {
		Name = "Arrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(T.Arrow, T.Arrow),
		ImageColor3 = COL.Go,
		ZIndex = 4,
		Active = false,
		Visible = false,
		Parent = parent,
	}
	local art = UIKit.ArtImage(T.ArrowKey, props)
	if art then
		ui.arrowHalo = halo(art)
		ui.arrowHalo.Size = UDim2.fromOffset(T.Arrow + T.Halo, T.Arrow + T.Halo)
		return tint(art, "ImageColor3")
	end
	props.ImageColor3 = nil
	props.Text = TXT.Arrow
	props.TextSize = T.Arrow
	props.Color = COL.Go
	props.Outline = COL.Rim
	props.OutlineThickness = 2
	return tint(UIKit.LightText(props), "TextColor3")
end

-- the distance: UIKit's "Number" style over the 3D world (white -> cream, navy rim; A23-48 Fredoka One)
local function makeDistance(parent)
	local props = {
		Name = "Distance",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, T.Icon / 2 + T.Text / 2 + 2),
		Size = UDim2.fromOffset(T.TextW, T.Text + 2),
		TextSize = T.Text,
		ZIndex = 4,
		Active = false,
		Parent = parent,
	}
	if type(UIKit.StyledLabel) == "function" then return UIKit.StyledLabel(props, "Number") end
	props.Color = Color3.new(1, 1, 1)
	props.Outline = COL.Rim
	props.OutlineThickness = 2
	props.Number = true
	return UIKit.LightText(props)
end

local function build()
	UIKit = C and C.UIKit
	assert(type(UIKit) == "table" and UIKit.Gui, "UIKit is not initialized")
	local main = UIKit.Gui
	local artCol = type(UIKit.ArtColors) == "table" and UIKit.ArtColors or {}
	if typeof(artCol.MarkerGo) == "Color3" then COL.Go = artCol.MarkerGo end
	if typeof(artCol.MarkerClaim) == "Color3" then COL.Claim = artCol.MarkerClaim end
	if typeof(artCol.Navy) == "Color3" then COL.Rim = artCol.Navy end

	-- the same screen space as MainGui (inset + safe area), one layer under it: the HUD draws over the marker
	local gui = Instance.new("ScreenGui")
	gui.Name = "QuestMarkerGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = main.IgnoreGuiInset
	gui.DisplayOrder = main.DisplayOrder - 1
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function()
		gui.ScreenInsets = main.ScreenInsets
	end)
	ui.gui = gui
	ui.scale = UIKit.Create("UIScale", { Scale = 1, Parent = gui })

	-- a 0x0 holder at the icon centre; children sit at offsets around it
	local holder = UIKit.Create("Frame", {
		Name = "QuestMarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Active = false,
		Visible = false,
		Parent = gui,
	})
	pcall(function()
		holder.Interactable = false -- never takes input (the thumbstick zone on phones)
	end)
	ui.holder = holder
	ui.iconBox = UIKit.Create("Frame", {
		Name = "IconBox",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(T.Icon, T.Icon),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Active = false,
		Parent = holder,
	})
	ui.icon = makeIcon(ui.iconBox)
	ui.arrow = makeArrow(holder)
	ui.text = makeDistance(holder)
	collectFades(holder)
	-- A23-68 #2 focus icon (its own holder: never faded / tinted with the marker)
	ui.focus = UIKit.Create("Frame", {
		Name = "Focus",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(T.FocusPx, T.FocusPx),
		BackgroundTransparency = 1,
		Active = false,
		Visible = false,
		Parent = gui,
	})
	pcall(function()
		ui.focus.Interactable = false
	end)
	local focusArt = UIKit.ArtImage(T.ArtKey, {
		Name = "Icon",
		Size = UDim2.fromScale(1, 1),
		ImageColor3 = COL.Go,
		ZIndex = 3,
		Active = false,
		Parent = ui.focus,
	})
	if focusArt then
		ui.focusHalo = halo(focusArt)
		ui.focusHalo.AnchorPoint = Vector2.new(0.5, 0.5)
		ui.focusHalo.Position = UDim2.fromScale(0.5, 0.5)
		ui.focusHalo.Size = UDim2.new(1, T.Halo, 1, T.Halo)
	else
		UIKit.Create("Frame", {
			Name = "Diamond",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.66, 0.66),
			Rotation = 45,
			BackgroundColor3 = COL.Go,
			ZIndex = 3,
			Active = false,
			Parent = ui.focus,
		}, {
			UIKit.Create("UICorner", { CornerRadius = UDim.new(0, 3) }),
			UIKit.Create("UIStroke", { Color = COL.Rim, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
	end
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
	gui.Parent = playerGui
	S.built = true
end

----------------------------------------------------------------- HUD blocks (C.HUD.Layout, read lazily)
-- S.avoid = union boxes of the AVOID groups inflated by the indicator's footprint, S.raw = every rect of those
-- groups on its own; both with the thumbstick zone on touch ({ x0, y0, x1, y1 } du). Rebuilt only when HUD made a
-- new Layout table, the screen size or the indicator's size changed.
local function readAvoid(W, H)
	local hud = C and C.HUD
	local layout = type(hud) == "table" and hud.Layout or nil -- a NEW table every HUD layout pass: never cached
	-- 이미지 개발 10/09 (main PC photo: the edge diamond sat on 'Quests (1) ▼'): the drawn quest tracker + head line
	-- (HUD.QuestBlock, a new table when it moves) runs lower than Rects.quest
	local qb = type(hud) == "table" and type(hud.QuestBlock) == "table" and hud.QuestBlock or nil
	if layout == S.layoutRef and W == S.layoutW and H == S.layoutH and qb == S.qbRef then return end
	S.layoutRef, S.layoutW, S.layoutH, S.qbRef = layout, W, H, qb
	local boxes, raw = {}, {}
	local rects = type(layout) == "table" and type(layout.Rects) == "table" and layout.Rects or nil
	if rects then
		for _, group in AVOID do
			local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
			for _, id in group do
				local r = rects[id]
				local x, y, w, h = nil, nil, nil, nil
				if type(r) == "table" then x, y, w, h = num(r.X), num(r.Y), num(r.W), num(r.H) end
				if x and y and w and h and w > 0 and h > 0 then
					x0, y0 = math.min(x0, x), math.min(y0, y)
					x1, y1 = math.max(x1, x + w), math.max(y1, y + h)
					table.insert(raw, { x, y, x + w, y + h, T.Weight[id] or 1 })
				end
			end
			if x1 > x0 then table.insert(boxes, { x0, y0, x1, y1 }) end
		end
	elseif type(layout) == "table" and num(layout.ClusterLeft) and num(layout.ClusterTop) then
		-- before HUD v2: only the bottom-right button cluster is published
		table.insert(boxes, { layout.ClusterLeft, layout.ClusterTop, W, H })
		table.insert(raw, { layout.ClusterLeft, layout.ClusterTop, W, H })
	end
	local qx, qy, qw, qh = nil, nil, nil, nil
	if qb then qx, qy, qw, qh = num(qb.X), num(qb.Y), num(qb.W), num(qb.H) end
	if qx and qy and qw and qh and qw > 0 and qh > 0 then
		table.insert(boxes, { qx, qy, qx + qw, qy + qh })
		table.insert(raw, { qx, qy, qx + qw, qy + qh, T.Weight.quest or 1 })
	end
	local hudCount = #boxes -- the HUD blocks only (the on-screen marker rises above them; not above the thumbstick zone)
	if IS_TOUCH then
		table.insert(boxes, { 0, H * T.StickTop, W * T.StickX, H })
		table.insert(raw, { 0, H * T.StickTop, W * T.StickX, H })
	end
	for _, b in boxes do
		b[1], b[2], b[3], b[4] = b[1] - T.HalfX, b[2] - T.HalfY, b[3] + T.HalfX, b[4] + T.HalfY
	end
	S.avoid, S.raw = boxes, raw
	S.hud = table.move(boxes, 1, hudCount, 1, {})
end

local function hitAny(px, py, list)
	for _, b in list do
		if px > b[1] and px < b[3] and py > b[2] and py < b[4] then return true end
	end
	return false
end

-- moves (px, py) out of every avoid box by the smallest step that stays inside the track box (a few passes, so a
-- point pushed from one block into another is pushed again); keeps the last spot when no exit fits
local function pushOut(px, py, box, avoid)
	for _ = 1, 3 do
		local moved = false
		for _, b in avoid do
			if px > b[1] and px < b[3] and py > b[2] and py < b[4] then
				local best, bx, by = math.huge, px, py
				for _, c in { { b[1], py }, { b[3], py }, { px, b[2] }, { px, b[4] } } do
					local cx = math.clamp(c[1], box[1], box[3])
					local cy = math.clamp(c[2], box[2], box[4])
					local inside = cx > b[1] and cx < b[3] and cy > b[2] and cy < b[4]
					local d = math.abs(cx - px) + math.abs(cy - py)
					if not inside and d < best then best, bx, by = d, cx, cy end
				end
				if best < math.huge then
					px, py, moved = bx, by, true
				end
			end
		end
		if not moved then break end
	end
	return px, py
end

-- du^2 of HUD the indicator would cover with its icon centre at (px, py) (the single rects, not inflated; `me` = my
-- character's raw box, counted like a HUD block)
local function overlap(px, py, me)
	local fx, fy = T.HalfX - T.Pad, T.HalfY - T.Pad
	local sum = 0
	for _, b in S.raw do
		local w = math.min(px + fx, b[3]) - math.max(px - fx, b[1])
		local h = math.min(py + fy, b[4]) - math.max(py - fy, b[2])
		if w > 0 and h > 0 then sum += w * h * (b[5] or 1) end
	end
	if me then
		local w = math.min(px + fx, me[3]) - math.max(px - fx, me[1])
		local h = math.min(py + fy, me[4]) - math.max(py - fy, me[2])
		if w > 0 and h > 0 then sum += w * h end
	end
	return sum
end

-- where the edge indicator goes for the ray (cx, cy) + (dx, dy) * t (t = the track-box edge):
-- 1. the edge point pushed out of the HUD blocks (`avoid`, default S.avoid); 2. crowded (phone) screens: the spot on the
-- ray, from the edge in to T.MinRing from the centre, that covers the least HUD (the outermost one on a tie: a clear
-- spot ends the walk); `me` = my character's raw box (검수 10/10: a goal behind me sat on my body at the bottom centre)
local function edgeSpot(cx, cy, dx, dy, t, box, avoid, me)
	avoid = avoid or S.avoid
	local px, py = pushOut(cx + dx * t, cy + dy * t, box, avoid)
	if not hitAny(px, py, avoid) then return px, py end
	local minR = math.min(t, T.MinRing)
	local bx, by, best = cx + dx * t, cy + dy * t, math.huge
	for k = 0, T.WalkSteps do
		local tk = t - (t - minR) * k / T.WalkSteps
		local qx, qy = cx + dx * tk, cy + dy * tk
		local a = overlap(qx, qy, me)
		if a < best - 1 then bx, by, best = qx, qy, a end
		if a <= 0 then break end
	end
	return bx, by
end

----------------------------------------------------------------- placing
-- the marker's du for the HUD's UIScale s and the icon's real px (default: the last one); a new size rebuilds the avoid
-- boxes and rewrites every position
local function fitScale(s, px)
	px = px or S.iconPx or T.IconPx
	if s == S.scale and px == S.iconPx then return end
	S.scale, S.iconPx = s, px
	T.Fit(s, px)
	ui.scale.Scale = s
	ui.iconBox.Size = UDim2.fromOffset(T.Icon, T.Icon)
	if ui.iconHalo then ui.iconHalo.Size = UDim2.new(1, T.Halo, 1, T.Halo) end
	ui.arrow.Size = UDim2.fromOffset(T.Arrow, T.Arrow)
	if ui.arrowHalo then ui.arrowHalo.Size = UDim2.fromOffset(T.Arrow + T.Halo, T.Arrow + T.Halo) end
	if ui.arrow:IsA("TextLabel") then ui.arrow.TextSize = T.Arrow end
	ui.text.Size = UDim2.fromOffset(T.TextW, T.Text + 2)
	ui.text.TextSize = T.Text
	S.layoutRef = false -- never equal to a Layout table or nil: readAvoid rebuilds
	S.posX, S.rot, S.labelUp = nil, nil, nil
end

-- white while in progress, light gold once the row waits for [Claim]
local function setTint(claim)
	if claim == S.claim then return end
	S.claim = claim
	local c = claim and COL.Claim or COL.Go
	for _, e in tinted do e[1][e[2]] = c end
end

local function setDistance(meters)
	if meters == S.meters then return end
	S.meters = meters
	ui.text.Text = string.format(TXT.Distance, meters)
end

local function setAlpha(a)
	if S.alpha and math.abs(S.alpha - a) < 0.02 then return end
	S.alpha = a
	for _, e in fades do
		local v = 1 - (1 - e[3]) * a
		if math.abs(e[1][e[2]] - v) > 0.01 then e[1][e[2]] = v end
	end
end

local function hideAll()
	if ui.holder and ui.holder.Visible then ui.holder.Visible = false end
	S.shown, S.onScreen = false, nil
end

-- the target and the top the marker floats over (live part position, so a moving target is followed); moveStep adds
-- the lift (T.LiftFor: it grows with the distance)
local function targetPoint()
	local t = S.target
	if not t then return nil, nil end
	local part = t.Part
	if part and part.Parent and part:IsA("BasePart") then
		local p = part.Position
		return p, p + Vector3.new(0, part.Size.Y / 2, 0)
	end
	local p = t.Position
	return p, p
end

-- 검수 10/09 (user photo: a 49m goal straight ahead drew its diamond on my halo): my character's box on screen (T.Self:
-- head, body, halo / horns), inflated by the indicator's footprint, { x0, y0, x1, y1 } du, and the same box not inflated;
-- nil in first person or when a corner is behind the camera
local function selfBox(cam, root, origin, s)
	local me = T.Self
	if (cam.CFrame.Position - root.Position).Magnitude < me.MinCam then return nil end
	local up = root.Position + Vector3.new(0, me.Up, 0)
	local down = root.Position - Vector3.new(0, me.Down, 0)
	local side = cam.CFrame.RightVector * me.HalfW
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for _, p in { up + side, up - side, down + side, down - side } do
		local sp = cam:WorldToScreenPoint(p)
		if sp.Z <= 0 then return nil end
		local x, y = (sp.X - origin.X) / s, (sp.Y - origin.Y) / s
		x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y)
	end
	return { x0 - T.HalfX, y0 - T.HalfY, x1 + T.HalfX, y1 + T.HalfY }, { x0, y0, x1, y1 }
end

local function moveTo(px, py)
	if not S.posX or math.abs(px - S.posX) >= T.MinMove or math.abs(py - S.posY) >= T.MinMove then
		S.posX, S.posY = px, py
		ui.holder.Position = UDim2.fromOffset(px, py)
	end
end

-- the distance under the icon, or above it while the edge arrow points down
local function labelAbove(up)
	if up == S.labelUp then return end
	S.labelUp = up
	local off = T.Icon / 2 + T.Text / 2 + 2
	ui.text.Position = UDim2.new(0.5, 0, 0.5, up and -off or off)
end

-- edge indicator: from the screen centre toward the target (camera space, so behind the camera works too), on the
-- track box, out of the HUD blocks; the arrow beside the icon points the way, the distance sits on the other side
local function placeEdge(cam, origin, s, W, H, lifted, root)
	local centre3 = cam:WorldToScreenPoint(cam.CFrame.Position + cam.CFrame.LookVector * 10)
	local cx, cy = (centre3.X - origin.X) / s, (centre3.Y - origin.Y) / s
	local rel = cam.CFrame:PointToObjectSpace(lifted)
	local dx, dy = rel.X, -rel.Y
	local len = math.sqrt(dx * dx + dy * dy)
	if len < 1e-3 then dx, dy, len = 0, 1, 1 end
	dx, dy = dx / len, dy / len

	-- the whole indicator (icon + the arrow beside it + the distance) stays on screen: the icon centre keeps at least its
	-- footprint from every edge (UiSandbox 2026-10-06: a 48 du margin left half the arrow outside on the left)
	local mx, my = math.max(T.Margin, T.HalfX), math.max(T.Margin, T.HalfY)
	local box = { mx, math.max(my, T.TopBar + T.HalfY), W - mx, H - my }
	if box[3] <= box[1] or box[4] <= box[2] then
		box = { W / 2, H / 2, W / 2, H / 2 } -- a tiny viewport: park it in the middle
	end
	cx, cy = math.clamp(cx, box[1], box[3]), math.clamp(cy, box[2], box[4])
	local tx = dx > 0 and (box[3] - cx) / dx or (dx < 0 and (box[1] - cx) / dx or math.huge)
	local ty = dy > 0 and (box[4] - cy) / dy or (dy < 0 and (box[2] - cy) / dy or math.huge)
	local t = math.max(0, math.min(tx, ty))
	readAvoid(W, H)
	-- 검수 10/10 (UiSandbox 991x451: a goal behind me put the indicator on my body at the bottom centre): my character's
	-- box joins the HUD blocks here too (S.edgeAvoid: S.avoid + it, refilled each frame)
	local me, meRaw = selfBox(cam, root, origin, s)
	local avoid = S.avoid
	if me then
		avoid = S.edgeAvoid
		table.clear(avoid)
		table.move(S.avoid, 1, #S.avoid, 1, avoid)
		table.insert(avoid, me)
	end
	local px, py = edgeSpot(cx, cy, dx, dy, t, box, avoid, meRaw)
	moveTo(px, py)
	local rot = math.deg(math.atan2(dx, -dy)) -- the arrow points up at Rotation 0; GUI rotation is clockwise
	if not S.rot or math.abs(rot - S.rot) >= T.MinTurn then
		S.rot = rot
		local r = T.Icon / 2 + T.Arrow / 2 + 1
		for _, a in { ui.arrow, ui.arrowHalo } do
			a.Rotation = rot
			a.Position = UDim2.new(0.5, dx * r, 0.5, dy * r)
		end
	end
	labelAbove(dy > 0.6) -- the arrow points down: the distance goes above the icon
end

-- an on-screen target behind a HUD block (hud = S.hud, the blocks inflated by the footprint): keep its column and rise
-- just above that block; 검수 10/09 (phone 09a / 10_crossroads: "23m" cut off above the screen's top edge over the
-- crown war bar) - a block with no room above it under the Roblox top bar (topY) sends the marker just below it
-- (kept above bottomY); once it went down it keeps going down past the next block, so two stacked blocks never send it
-- back and forth. Pure: the offline test runs it.
function QuestMarker.ClearOfHud(lx, ly, hud, topY, bottomY)
	hud = hud or {}
	local down = false
	for _ = 1, #hud + 1 do
		local hit = nil
		for _, b in hud do
			if lx > b[1] and lx < b[3] and ly > b[2] and ly < b[4] then
				hit = b
				break
			end
		end
		if not hit then break end
		if not down and hit[2] >= topY then
			ly = hit[2]
		else
			down = true
			ly = math.min(hit[4], bottomY)
		end
	end
	return ly
end

-- every frame after the camera: visibility, distance, fade, colour, on-screen spot or edge indicator
local function moveStep()
	local root = myRoot()
	local cam = workspace.CurrentCamera
	local gui = ui.gui
	local base, top = targetPoint()
	if not (root and cam and gui and gui.Parent and base) or not hudShowing() or moduleOpen("WorldMap")
		or moduleOpen("Panels") or moduleOpen("Intro") then
		hideAll()
		return
	end
	local meters = math.floor((base - root.Position).Magnitude / T.StudsPerMeter + 0.5)
	if meters <= T.HideM then
		hideAll()
		return
	end
	setDistance(meters)
	setAlpha(math.clamp((meters - T.HideM) / math.max(0.01, T.FadeM - T.HideM), 0, 1))
	setTint(S.target ~= nil and S.target.Claim == true)

	local s = guiScale()
	fitScale(s, T.IconPxFor(meters)) -- far goals draw a smaller icon (검수 10/09)
	local lifted = top + Vector3.new(0, T.LiftFor(meters), 0)
	local origin, size = gui.AbsolutePosition, gui.AbsoluteSize
	local W, H = size.X / s, size.Y / s
	-- on screen = in front of the camera and inside the gui box
	local sp = cam:WorldToScreenPoint(lifted)
	local lx, ly = (sp.X - origin.X) / s, (sp.Y - origin.Y) / s
	local onScreen = sp.Z > 0 and lx >= 0 and lx <= W and ly >= 0 and ly <= H
	if onScreen ~= S.onScreen then
		S.onScreen = onScreen
		ui.arrow.Visible = not onScreen
		if ui.arrowHalo then ui.arrowHalo.Visible = not onScreen end
		S.posX, S.rot, S.labelUp = nil, nil, nil -- the next placement writes everything
	end
	if onScreen then
		-- 2026-10-08 (main Studio phone: the marker and "19m" sat on "Lv 1 · 245"): a target behind a HUD block keeps its
		-- column but rises just above that block (S.hud = the HUD blocks inflated by the indicator's footprint)
		readAvoid(W, H)
		-- 검수 10/09: off my character first (same column, just above my halo / horns), then off the HUD blocks
		local me = selfBox(cam, root, origin, s)
		if me then ly = QuestMarker.ClearOfHud(lx, ly, { me }, T.TopBar + T.HalfY, H - T.HalfY) end
		ly = QuestMarker.ClearOfHud(lx, ly, S.hud, T.TopBar + T.HalfY, H - T.HalfY)
		moveTo(lx, ly)
		labelAbove(false)
	else
		placeEdge(cam, origin, s, W, H, lifted, root)
	end
	if not ui.holder.Visible then ui.holder.Visible = true end
	S.shown = true
end

-- Studio-only check hook (UiSandbox captures in every ZoneLook zone): the local attribute QuestMarkerPreview =
-- "x,y,z" (in progress) or "x,y,z,claim" (gold) replaces HUD's target; never read outside Studio
local function previewTarget()
	if not RunService:IsStudio() then return nil end
	local v = LocalPlayer:GetAttribute("QuestMarkerPreview")
	if type(v) ~= "string" or v == "" then return nil end
	local x, y, z, flag = string.match(v, "^%s*(%-?[%d%.]+)%s*,%s*(%-?[%d%.]+)%s*,%s*(%-?[%d%.]+)%s*,?%s*(%a*)")
	if not x then return nil end
	return { Position = Vector3.new(tonumber(x), tonumber(y), tonumber(z)), Tag = "preview", Claim = flag == "claim" }
end

-- Studio-only check hook (UiSandbox captures of A23-68 #2): the local attribute FocusPreview = true focuses the nearest
-- living monster (game dev 1's real picker chooses my quest's slimes); never read outside Studio
local function previewFocus()
	if not RunService:IsStudio() then return end
	local on = LocalPlayer:GetAttribute("FocusPreview") == true
	if not on then
		if S.focusPreview then QuestMarker.Focus(nil) end
		S.focusPreview = false
		return
	end
	S.focusPreview = true
	local root = myRoot()
	local folder = workspace:FindFirstChild("Monsters")
	if not (root and folder) then return end
	local best, bestD = nil, math.huge
	for _, m in folder:GetChildren() do
		local hum = m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") or nil
		local pivot = hum and hum.Health > 0 and m:GetPivot() or nil
		if pivot then
			local d = (pivot.Position - root.Position).Magnitude
			if d < bestD then best, bestD = m, d end
		end
	end
	QuestMarker.Focus(best)
end

-- 2 Hz: the pinned row's place from HUD (QuestTarget.ForEntry result)
local function retarget()
	local t = previewTarget()
	if t then
		S.target = t
		return
	end
	local hud = C and C.HUD
	if type(hud) == "table" and type(hud.QuestTarget) == "function" then
		local ok, r = pcall(hud.QuestTarget)
		if ok and type(r) == "table" and typeof(r.Position) == "Vector3" then
			local part = typeof(r.Part) == "Instance" and r.Part:IsA("BasePart") and r.Part or nil
			t = { Part = part, Position = r.Position, Tag = r.Tag, Claim = r.Claim == true }
		end
	end
	S.target = t
end

-- A23-68 #2: the focus monster's anchor in the world (its name tag's spot, or over its box) + the tag, nil when the
-- monster is gone, dead or leaving
local function focusPoint()
	local f = S.focus
	if typeof(f) ~= "Instance" or not f.Parent then return nil, nil end
	if f:IsA("Model") then
		local hum = f:FindFirstChildOfClass("Humanoid")
		if (hum and hum.Health <= 0) or f:GetAttribute("Leaving") == true then return nil, nil end
		local bb = S.focusBar
		local base = bb and bb.Parent
		if bb and bb.Parent and base:IsA("BasePart") and base:IsDescendantOf(f) then
			return base.Position + Vector3.new(0, bb.StudsOffset.Y, 0), bb
		end
		local cf, size = f:GetBoundingBox()
		return cf.Position + Vector3.new(0, size.Y / 2, 0), nil
	elseif f:IsA("BasePart") then
		return f.Position + Vector3.new(0, f.Size.Y / 2, 0), nil
	end
	return nil, nil
end

-- the bottom of the HUD's top rows (war meter, chips, next event; du): the focus icon never sits under them
local function topRowsBottom()
	local hud = C and C.HUD
	local layout = type(hud) == "table" and hud.Layout or nil
	local rects = type(layout) == "table" and layout.Rects or nil
	local bottom = 0
	for _, id in { "war_meter", "chips", "event" } do
		local r = type(rects) == "table" and rects[id] or nil
		if type(r) == "table" and num(r.Y) and num(r.H) then bottom = math.max(bottom, r.Y + r.H) end
	end
	return bottom
end

-- every frame: the focus icon over its monster (screen space: the gap over the name tag stays the same at any range)
local function focusStep()
	local holder = ui.focus
	if not holder then return end
	local cam = workspace.CurrentCamera
	local point, bb = focusPoint()
	if not (point and cam and ui.gui and ui.gui.Parent) or not hudShowing() or moduleOpen("WorldMap")
		or moduleOpen("Panels") or moduleOpen("Intro") then
		if holder.Visible then holder.Visible = false end
		return
	end
	local s = guiScale()
	fitScale(s) -- the gui's UIScale (also when the quest marker itself is hidden)
	local size = math.ceil(T.FocusPx / s)
	if size ~= S.focusSize then
		S.focusSize = size
		holder.Size = UDim2.fromOffset(size, size)
		if ui.focusHalo then ui.focusHalo.Size = UDim2.new(1, T.Halo, 1, T.Halo) end
	end
	local sp = cam:WorldToScreenPoint(point)
	local origin, gsize = ui.gui.AbsolutePosition, ui.gui.AbsoluteSize
	local W, H = gsize.X / s, gsize.Y / s
	local x, y = (sp.X - origin.X) / s, (sp.Y - origin.Y) / s
	if not (sp.Z > 0 and x >= 0 and x <= W and y >= 0 and y <= H) then
		if holder.Visible then holder.Visible = false end
		return
	end
	local tagHalf = (bb and bb.Enabled and bb.AbsoluteSize.Y > 0) and bb.AbsoluteSize.Y / 2 or 0
	local bob = 0
	if not UIKit.ReducedMotion() then bob = math.sin(os.clock() * math.pi * 2 * T.FocusHz) * T.FocusBobPx end
	local iy = y - (tagHalf + T.FocusGapPx + bob) / s
	-- a monster right in front of the camera lifts its name tag up under the HUD's top rows: then the icon sits just
	-- over its head instead, and hides when even that is up there (UiSandbox phone 2026-10-07: a big slime next to me)
	local top = topRowsBottom()
	if iy - size < top then
		local f = S.focus
		local headY, headX = nil, nil
		if f:IsA("Model") then
			local cf, box = f:GetBoundingBox()
			local hp = cam:WorldToScreenPoint(cf.Position + Vector3.new(0, box.Y / 2, 0))
			if hp.Z > 0 then headX, headY = (hp.X - origin.X) / s, (hp.Y - origin.Y - T.FocusGapPx - bob) / s end
		end
		if not headY or headY - size < top then
			if holder.Visible then holder.Visible = false end
			return
		end
		x, iy = headX, headY
	end
	holder.Position = UDim2.fromOffset(x, iy)
	if not holder.Visible then holder.Visible = true end
end

local function onRender(dt)
	S.targetAcc += dt
	if S.targetAcc >= T.TargetDt then
		S.targetAcc = 0
		guard(retarget, "retarget")
		guard(previewFocus, "focus preview")
	end
	guard(moveStep, "move")
	if S.focus ~= nil then guard(focusStep, "focus") elseif ui.focus and ui.focus.Visible then ui.focus.Visible = false end
end

----------------------------------------------------------------- public API
function QuestMarker.Init(registry)
	C = registry
end

function QuestMarker.Start()
	local ok, err = pcall(build)
	if not ok or not S.built then
		Util.Warn(TAG, "build failed: " .. tostring(err))
		return
	end
	RunService:BindToRenderStep(T.Step, Enum.RenderPriority.Camera.Value + 1, onRender)
	QuestMarker.Refresh()
	print("[QuestMarker] started")
end

-- asks HUD for the target now and places the marker at once (e.g. right after the quest list changed)
function QuestMarker.Refresh()
	if not S.built then return end
	S.targetAcc = 0
	guard(retarget, "retarget")
	guard(moveStep, "move")
end

function QuestMarker.IsShown()
	return S.shown == true
end

-- A23-68 #2: point the small focus icon at a monster (Model or BasePart), nil = off. The same target again is a no-op
function QuestMarker.Focus(target)
	if typeof(target) ~= "Instance" or not (target:IsA("Model") or target:IsA("BasePart")) then target = nil end
	if target == S.focus then return end
	S.focus = target
	S.focusBar = nil
	if target and target:IsA("Model") then
		local bb = target:FindFirstChild("MonsterBar", true)
		if bb and bb:IsA("BillboardGui") then S.focusBar = bb end
	end
	if target == nil and ui.focus then ui.focus.Visible = false end
end

-- 빛 마을 점검 #20 (2026-10-10): a tap on the pinned row whose place is already marked pops the icon once (grows,
-- then settles with a small overshoot; no text, nothing new on screen). ReducedMotion: no pop. False when the marker
-- is not shown
function QuestMarker.Pulse()
	if not (S.shown and ui.iconBox and ui.iconBox.Parent) then return false end
	if UIKit.ReducedMotion() then return true end
	local sc = ui.iconBox:FindFirstChild("PulseScale")
	if not sc then sc = UIKit.Create("UIScale", { Name = "PulseScale", Scale = 1, Parent = ui.iconBox }) end
	sc.Scale = T.PulseFrom
	game:GetService("TweenService"):Create(sc, TweenInfo.new(T.PulseTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }):Play()
	return true
end

return QuestMarker
