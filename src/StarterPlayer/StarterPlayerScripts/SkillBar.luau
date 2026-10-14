-- SkillBar.luau : the three skill buttons Q · Z · X (SPEC_ADDENDUM A23-49, docs/design/skill_kit_beta_2026-10-06.md §6)
-- in the bottom-right combat cluster, on HudLayout's rects q / z / x (C.HUD.Layout, read again after every HUD layout pass
-- through SkillBar.Relayout).
--   look   : the round skill disc (Config.UIArt "BtnSkill<Faction>" when that art exists, else the approved "BtnSpecial"),
--            my kit's icon (Skill_<Kit>_<Slot>, ~74% of the disc; Blacksmith Q / Z use Warrior's, Alchemist Q / Z Mage's
--            in the beta); on PCs the name pill on the lower rim (NameEn) and the key badge (Keybinds.Label, keyboards
--            only); phones show the icon only (§6-2). A23-60 (user 2026-10-06): no MP number on the button - the MP cost
--            lives in the skill's description only
--   state  : cooling down = a dark radial sweep + whole seconds left (attributes SkillReadyAt / SkillReadyAtZ /
--            SkillReadyAtX), then a short white flash; MP short = the whole button dimmed (a press says "Not enough
--            MP"); A23-71 (user 2026-10-07 "스킬도 처음에는 없어야 돼"): a slot below its unlock level (Config.Skills.Unlock)
--            is not shown at all (its key says "Skills come at Lv N"); a slot whose flag is off (Config.Skills.ZEnabled /
--            XEnabled) stays hidden and keeps its rect free
--   learn  : the moment a slot unlocks while I play (not at a save load): "New skill! <name>" banner, the button pops in,
--            one line on it (PC "Press Q", phones "Tap the new button" - C.HUD.Hint) and the SkillLearn sound (PowerUp
--            until that file exists). Replaces A23-68 #2's "Try your skill!" after the first kill
--   input  : a press = SkillBar.Use(slot): one press, one cast. Inside the 0.5 s gap between casts one press waits in
--            line (white rim) and goes when the gap ends. Refused here (locked, cooling, MP) -> the button shakes and a
--            short word floats up. 2-C #8 (최종 검수 10/14): the server's answer Fx "SkillPress" { Slot, Result }
--            (SkillService) does the same for what only the server knows - "No target", "Can't hop here", "Too heavy to
--            jump!", its own cooldown / MP view ("Not ready" / "Not enough MP"), a switched-off slot ("Not now");
--            "Queued" says nothing. Words: Config.Skills.Text.
--   hop    : 2-C #8 prep (SKL-3 X Hop: archer X, tamer Big Boing; Config.Skills.XEnabled off until 10/20): the server's
--            Fx "Hop" { To, T } to the caster -> this client moves my own character to To (its ground height) along a low
--            arc over T s (the server allowed that one move: ZoneService.AllowMove); a far / broken To or a dead / new
--            character = no move. Q goes through HUD.Release (the live Release remote) until SkillService's UseSkill
--            remote exists; Z / X fire UseSkill(slot) (SKL-2). HUD's key dispatch sends SkillQ / SkillZ / SkillX here.
--   Studio : the local attribute SkillBarPreview = true shows Z / X with their flags off (UiSandbox captures only)
-- Presentation + input only: the server decides every cast (MP, cooldown, targets).
--
-- Public API: SkillBar.Init(C), SkillBar.Start(), SkillBar.Relayout(), SkillBar.Use(slot) -> bool, SkillBar.Owns(slot),
-- SkillBar.Button(slot) -> the button frame (A23-68 hints), SkillBar.Learn (test aid: the A23-71 learn moment)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer

local SkillBar = {}

local TAG = "SkillBar"
local C = nil -- client registry (set in Init)
local UIKit = nil -- C.UIKit (set in Start)

----------------------------------------------------------------- tuning
local IS_TOUCH = UserInputService.TouchEnabled -- the same rule as HUD (HudLayout's touch rects)
local T = {
	Slots = { "Q", "Z", "X" },
	Rect = { Q = "q", Z = "z", X = "x" }, -- HudLayout ids
	Ready = { Q = "SkillReadyAt", Z = "SkillReadyAtZ", X = "SkillReadyAtX" }, -- server attributes (os time)
	Flag = { Z = "ZEnabled", X = "XEnabled" }, -- Config.Skills flags (Q is always on)
	Unlock = { Q = 5, Z = 15, X = 25 }, -- A23-71; Config.Skills.Unlock wins when it is there
	-- dev2 (A23-71): the server's SkillSlots attribute (0-3, never goes down: a rebirth / a free class change back to Lv1
	-- keeps the skills) opens slot N when SkillSlots >= N; either it or the level opens a slot
	SlotIndex = { Q = 1, Z = 2, X = 3 },
	Action = { Q = "SkillQ", Z = "SkillZ", X = "SkillX" }, -- Keybinds actions
	Gap = 0.5, -- s: the global gap between two casts (one press waits in line)
	Tick = 0.1, -- s: cooldown sweep / seconds refresh
	Icon = 0.74, -- icon / disc (skill_kit §6-2)
	FaceX = 0.5, FaceY = 0.47, Face = 0.72, -- the disc's inner circle (scale of the button)
	Disc = "BtnSpecial", -- the approved skill disc (BtnSkill art)
	Rim = { Halo = "BtnSkillHalo", Horns = "BtnSkillHorns", Neutral = "BtnSkillNeutral" }, -- faction rims when drawn
	Sweep = 0.4, -- transparency of the cooldown shade
	Shake = { 7, -6, 4, -2, 0 }, -- degrees, one step each
	ShakeStep = 0.035,
	FloatTime = 0.7, -- s: the refusal word floats up and fades
	Flash = 0.28, -- s: the ready flash
	MinTap = 60, -- du (HudLayout MIN_TAP; the rects are already >= it on touch)
}
-- beta: the artisan kits reuse the base class's Q / Z art (skill_kit §7)
local REUSE = { Blacksmith = "Warrior", Alchemist = "Mage" }

local COL = {
	White = Color3.new(1, 1, 1),
	Black = Color3.new(0, 0, 0),
	Navy = Color3.fromRGB(26, 40, 79),
	Gold = Color3.fromRGB(240, 190, 60),
	Bad = Color3.fromRGB(225, 50, 50),
	Dim = Color3.fromRGB(150, 150, 160),
	Locked = Color3.fromRGB(105, 105, 118),
	Fallback = Color3.fromRGB(56, 144, 253), -- the disc when its art is missing (QuestBlue)
}

-- player-facing words (A23-48: English only, short for kids)
local TXT = {
	Default = { Q = "Skill", Z = "Skill 2", X = "Skill 3" }, -- until Config.Skills.Defs names the kit's skills
	Level = "Lv %d",
	Unlock = "Unlocks at Lv %d",
	NewSkill = "New skill! %s", -- A23-71 the learn moment
	LearnKey = "Press %s",
	LearnTouch = "Tap the new button",
	Later = "Skills come at Lv %d", -- a skill key pressed before the first skill
	-- A23-81 (user 2026-10-08): once, after the first skill is learned (keyboards): keys can be changed in Settings
	KeysTip = "Tip: You can change your keys in Settings!",
	KeysTipGo = "Open Settings",
}
-- A23-71 learn moment tuning
-- SoundDelay (sound_gaps A9): the learn sound comes this long after the level-up chime of the same level
local LEARN = { Banner = 3, Pop = 0.35, TellGap = 3, TellAt = -math.huge, SoundDelay = 1.1,
	TipSlot = "Q", TipAfterPress = 2.5, TipLate = 25, TipPending = false, -- A23-81 the keys tip
	-- 검수 10/09 (UI clutter review ④, "help only when stuck"): the "Press Q" line waits HintAfter s and shows only
	-- when the new skill was not used by then (HintWait[slot] = its line; SkillBar.Use clears it)
	HintAfter = 45, HintWait = {} }

----------------------------------------------------------------- state
local S = {
	built = false,
	gapUntil = 0, -- os.clock(): the next cast may go
	queued = nil, -- the slot waiting in line
	queueToken = 0,
	layoutRef = nil,
	lastWarnAt = -math.huge,
}
local ui = {} -- root, buttons = { [slot] = b }
-- 2-C #8: the server's refusal results -> Config.Skills.Text keys; HOP = the X hop move (Live = the running hop)
local PRESS = { Word = { Cooldown = "NotReady", NoMP = "NoMP", NoTarget = "NoTarget", TooHeavy = "TooHeavy",
	CantHop = "CantHop", Locked = "NotNow" } }
local HOP = { MaxDist = 16, Arc = 0.15, ArcMin = 0.8, ArcMax = 2, TMin = 0.1, TMax = 0.6, Ray = 12, Live = nil }
local acc = { Tick = 0 }

----------------------------------------------------------------- helpers
local function warnThrottled(msg)
	local now = os.clock()
	if now - S.lastWarnAt < 10 then return end
	S.lastWarnAt = now
	Util.Warn(TAG, msg)
end

local function guard(fn, what)
	local ok, err = pcall(fn)
	if not ok then warnThrottled(what .. " error: " .. tostring(err)) end
end

local function attr(name, default)
	local v = LocalPlayer:GetAttribute(name)
	if v == nil then return default end
	return v
end

local function num(name, default)
	local v = tonumber(attr(name, default))
	if v == nil or v ~= v then return default end
	return v
end

local function skills()
	return type(Config.Skills) == "table" and Config.Skills or {}
end

local function preview()
	return RunService:IsStudio() and attr("SkillBarPreview", false) == true
end

-- the slot is in the game today (Q always; Z / X behind their Config.Skills flags)
local function slotOn(slot)
	if slot == "Q" then return true end
	return skills()[T.Flag[slot]] == true or preview()
end

local function unlockLevel(slot)
	local u = skills().Unlock
	return math.floor(tonumber(type(u) == "table" and u[slot] or nil) or T.Unlock[slot] or 1)
end

local function myClass()
	local c = attr("Class", "Warrior")
	if type(c) ~= "string" or type(Config.Classes) ~= "table" or not Config.Classes[c] then return "Warrior" end
	return c
end

local function myFaction()
	local f = attr("Faction", "None")
	if type(f) ~= "string" or f == "" then return "None" end
	return f
end

-- the skill kit of my class in my faction (Config.SkillKit once SKL-1 adds it)
local function kitOf(class, faction)
	if type(Config.SkillKit) == "function" then
		local ok, k = pcall(Config.SkillKit, class, faction)
		if ok and type(k) == "string" and k ~= "" then return k end
	end
	if faction == "Neutral" then
		if type(Config.IsTamer) == "function" and Config.IsTamer(class, faction) then return "Tamer" end
		if class == "Warrior" then return "Blacksmith" end
		if class == "Mage" then return "Alchemist" end
	end
	return class
end

-- { MP, CD, Name } of a slot for my kit; Q falls back to Config.BasicSkill, names to TXT.Default
local function defOf(slot)
	local class, faction = myClass(), myFaction()
	local def = nil
	if type(Config.SkillDef) == "function" then
		local ok, d = pcall(Config.SkillDef, class, faction, slot)
		if ok and type(d) == "table" then def = d end
	end
	if not def then
		local defs = skills().Defs
		local kit = type(defs) == "table" and defs[kitOf(class, faction)] or nil
		def = type(kit) == "table" and type(kit[slot]) == "table" and kit[slot] or nil
	end
	local basic = type(Config.BasicSkill) == "table" and Config.BasicSkill or {}
	local out = {
		MP = tonumber(def and def.MP) or (slot == "Q" and tonumber(basic.ManaCost) or 0) or 0,
		CD = tonumber(def and def.CD) or (slot == "Q" and tonumber(basic.Cooldown) or 3) or 3,
		Name = def and def.NameEn or nil,
	}
	-- X: the faction's own name (Guardian Roar / Rage Roar ...)
	local fx = def and type(def[faction]) == "table" and def[faction] or nil
	if fx and type(fx.NameEn) == "string" then out.Name = fx.NameEn end
	if type(out.Name) ~= "string" or out.Name == "" then out.Name = TXT.Default[slot] end
	return out
end

local function iconKey(slot)
	if attr("ClassChosen", false) ~= true then return "Skill_Warrior_Q" end -- 그림체 #15: was the old winged IconSpecial
	-- skills18 (10/10): each class's own icon per faction first (Skill_<Class>_<Slot>_<Faction>, e.g. Skill_Mage_Z_Horns),
	-- then the kit icon (kept: the Artisan Guild borrows them)
	local own = "Skill_" .. myClass() .. "_" .. slot .. "_" .. myFaction()
	if UIKit.ArtId(own) then return own end
	local kit = kitOf(myClass(), myFaction())
	local key = "Skill_" .. kit .. "_" .. slot
	if UIKit.ArtId(key) then return key end
	local base = REUSE[kit]
	if base and UIKit.ArtId("Skill_" .. base .. "_" .. slot) then return "Skill_" .. base .. "_" .. slot end
	return "Skill_Warrior_Q"
end

local function discKey()
	local rim = T.Rim[myFaction()]
	if rim and UIKit.ArtId(rim) then return rim end
	return T.Disc
end

-- MainGui's UIScale
local function guiScale()
	local gui = UIKit and UIKit.Gui
	local sc = gui and gui:FindFirstChildOfClass("UIScale")
	return (sc and sc.Scale > 0) and sc.Scale or 1
end

----------------------------------------------------------------- building
local function corner(r)
	return UIKit.Create("UICorner", { CornerRadius = r or UDim.new(0.5, 0) })
end

-- a dark half disc inside a half-width clip; its UIGradient's sharp step turns to show / hide the wedge
local function sweepHalf(parent, right)
	-- the left clip is 1 px wider than half, so the two halves never leave a hairline gap down the middle; each shade is
	-- still exactly the face's circle (2 x the clip minus that px)
	local clip = UIKit.Create("Frame", {
		Name = right and "Right" or "Left",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromScale(right and 0.5 or 0, 0),
		Size = right and UDim2.fromScale(0.5, 1) or UDim2.new(0.5, 1, 1, 0),
		ZIndex = 4,
		Active = false,
		Parent = parent,
	})
	local disc = UIKit.Create("Frame", {
		Name = "Shade",
		BackgroundColor3 = COL.Black,
		BackgroundTransparency = T.Sweep,
		Position = right and UDim2.fromScale(-1, 0) or UDim2.fromScale(0, 0),
		Size = right and UDim2.fromScale(2, 1) or UDim2.new(2, -2, 1, 0),
		ZIndex = 4,
		Active = false,
		Parent = clip,
	}, { corner() })
	local grad = UIKit.Create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.499, 0),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = disc,
	})
	return grad
end

-- the shade over the disc for `left` (0..1 of the cooldown still to go): the elapsed part (from 12 o'clock, clockwise)
-- is clear, the rest dark. A sharp-step gradient's dark side faces away from its axis; axis angle = elapsed + 180
local function setSweep(b, left)
	left = math.clamp(left, 0, 1)
	local full = left >= 0.999
	local shown = left > 0.001 and not full
	if b.Sweep.Visible ~= shown then b.Sweep.Visible = shown end
	if b.Full.Visible ~= full then b.Full.Visible = full end
	if not shown then return end
	local e = 360 * (1 - left)
	b.SweepR.Rotation = math.min(e, 180) + 180
	b.SweepL.Rotation = math.max(e, 180) + 180
end

local function smallLabel(props, style)
	props.BackgroundTransparency = 1
	props.Active = false
	if type(UIKit.StyledLabel) == "function" then return UIKit.StyledLabel(props, style) end
	props.TextColor3 = COL.White
	props.TextScaled = true
	return UIKit.Create("TextLabel", props)
end

local function buildButton(slot)
	local b = { Slot = slot }
	local holder = UIKit.Create("TextButton", {
		Name = "Skill" .. slot,
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(72, 72),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
		Parent = ui.root,
	}, { UIKit.Create("UIScale", { Name = "PressScale" }) })
	b.Holder = holder
	if type(UIKit.ButtonFeel) == "function" then UIKit.ButtonFeel(holder, { Fast = true }) end
	holder.Activated:Connect(function()
		SkillBar.Use(slot)
	end)

	b.Disc = UIKit.ArtFrame(discKey(), {
		Name = "Disc", Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = holder,
	}, { Color = COL.Fallback, BackgroundTransparency = 0.08, CornerRadius = UDim.new(0.5, 0), StrokeColor = COL.White,
		StrokeThickness = 4, StrokeTransparency = 0.35 })
	b.DiscKey = discKey()

	-- the face = a square on the disc's inner circle (BtnSpecial Inner 61,57 .. 450,425 of 512: centre 0.5 / 0.47, the
	-- shorter side 0.72): the cooldown shade and the seconds; the icon sits under it on the holder
	local face = UIKit.Create("Frame", {
		Name = "Face",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(T.FaceX, T.FaceY),
		Size = UDim2.fromScale(T.Face, T.Face),
		ZIndex = 4,
		Active = false,
		Parent = holder,
	})
	b.Face = face
	b.IconKey = nil
	b.Sweep = UIKit.Create("Frame", {
		Name = "Sweep", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4, Active = false,
		Visible = false, Parent = face,
	})
	b.SweepL = sweepHalf(b.Sweep, false)
	b.SweepR = sweepHalf(b.Sweep, true)
	b.Full = UIKit.Create("Frame", { -- the whole face shaded: one disc, no seam
		Name = "Full", BackgroundColor3 = COL.Black, BackgroundTransparency = T.Sweep, Size = UDim2.fromScale(1, 1),
		ZIndex = 4, Active = false, Visible = false, Parent = face,
	}, { corner() })
	b.Seconds = smallLabel({
		Name = "Seconds", Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.42), TextScaled = true, ZIndex = 6, Visible = false, Parent = face,
	}, "Number")

	-- locked: lock glyph (+ "Lv N"); without the GlyphLock art a code lock (white body + shackle ring, IMG-R4, review
	-- 8e89d2b ②: an empty id left a bare disc)
	b.Lock = UIKit.ArtImage("GlyphLock", {
		Name = "Lock", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(0.34, 0.34), ZIndex = 7, Visible = false, Active = false, Parent = holder,
	}) or UIKit.Create("Frame", {
		Name = "Lock", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(0.34, 0.34), BackgroundTransparency = 1, ZIndex = 7, Visible = false, Active = false,
		Parent = holder,
	}, {
		UIKit.Create("Frame", {
			Name = "Shackle", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.02),
			Size = UDim2.fromScale(0.56, 0.62), BackgroundTransparency = 1, ZIndex = 7, Active = false,
		}, {
			UIKit.Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			UIKit.Create("UIStroke", { Color = COL.White, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		}),
		UIKit.Create("Frame", {
			Name = "Body", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(0.86, 0.6), BackgroundColor3 = COL.White, ZIndex = 8, Active = false,
		}, {
			UIKit.Create("UICorner", { CornerRadius = UDim.new(0.18, 0) }),
			UIKit.Create("UIStroke", { Color = COL.Navy, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		}),
	})
	b.LockText = smallLabel({
		Name = "Level", Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.68),
		Size = UDim2.fromScale(0.66, 0.24), TextScaled = true, ZIndex = 7, Visible = false, Parent = holder,
	}, "Number")

	-- PCs: the name pill on the lower rim, the key badge in the lower right (keyboards). The pill reaches a little past
	-- the rim (like the tile captions) and its words take the 12 px Number floor, not the 16 px button floor: at 16 px
	-- "Shockwave" stood taller than the 16 px pill and was cut ("Shockwa", 2026-10-07), Z / X names are longer still
	if not IS_TOUCH then
		b.Pill = UIKit.Create("Frame", {
			Name = "Name", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.9),
			Size = UDim2.fromScale(1.2, 0.22), BackgroundColor3 = COL.Navy, BackgroundTransparency = 0.12, ZIndex = 7,
			Active = false, Parent = holder,
		}, { corner() })
		b.PillText = smallLabel({
			Name = "Text", Text = "", Position = UDim2.fromScale(0.04, 0), Size = UDim2.fromScale(0.92, 1),
			TextScaled = true, ZIndex = 8, Parent = b.Pill,
		}, "Number")
	end
	local kb = C and C.Keybinds
	local showKeys = type(kb) == "table" and type(kb.ShowsKeys) == "function" and kb.ShowsKeys() or false
	if showKeys then
		b.Key = smallLabel({
			Name = "Key", Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.3, 0.3), TextScaled = true, ZIndex = 9, Parent = holder,
		}, "Number")
	end

	-- queued press (white) / ready flash rim
	b.Ring = UIKit.Create("Frame", {
		Name = "Ring", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8, Active = false,
		Parent = holder,
	}, {
		corner(),
		UIKit.Create("UIStroke", { Name = "Stroke", Color = COL.White, Thickness = 3, Transparency = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	b.RingStroke = b.Ring:FindFirstChild("Stroke")

	-- the refusal word above the button
	b.Word = smallLabel({
		Name = "Word", Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, -0.05),
		Size = UDim2.fromScale(1.6, 0.3), TextScaled = true, ZIndex = 10, Visible = false, Parent = holder,
	}, "NameTag")
	ui.buttons[slot] = b
	return b
end

----------------------------------------------------------------- refresh
local function setIcon(b)
	local key = iconKey(b.Slot)
	if b.IconKey == key and b.Icon and b.Icon.Parent then return end
	b.IconKey = key
	if b.Icon then b.Icon:Destroy() end
	b.Icon = UIKit.ArtImage(key, {
		Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(T.FaceX, T.FaceY),
		Size = UDim2.fromScale(T.Icon, T.Icon), ZIndex = 3, Active = false, Parent = b.Holder,
	}) or UIKit.LightText({
		-- review 8e89d2b ② (IMG-R4): no icon art -> the slot's letter in the same place, never a bare disc
		Name = "Icon", Text = b.Slot, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(T.FaceX, T.FaceY),
		Size = UDim2.fromScale(T.Icon * 0.8, T.Icon * 0.8), TextScaled = true, ZIndex = 3, Active = false,
		Parent = b.Holder,
	})
end

-- the slot's live state: { On, Locked, Unlock, Left (s), Frac (0..1 of the cooldown still to go), MPShort, Def }
-- a player-facing skill word (Config.Skills.Text, A23-48 English); "" when the key is missing
local function skillWord(key)
	local t = type(Config.Skills) == "table" and Config.Skills.Text or nil
	local v = type(t) == "table" and t[key] or nil
	return type(v) == "string" and v or ""
end

local function stateOf(slot)
	local def = defOf(slot)
	local unlock = unlockLevel(slot)
	local level = math.floor(num("Level", 1))
	local locked = level < unlock
	local slots = attr("SkillSlots", nil)
	if locked and type(slots) == "number" and slots >= (T.SlotIndex[slot] or 99) then locked = false end
	local readyAt = num(T.Ready[slot], 0)
	local left = math.max(0, readyAt - Util.Now())
	return {
		On = slotOn(slot),
		Locked = locked,
		Unlock = unlock,
		Left = left,
		Frac = def.CD > 0 and math.clamp(left / def.CD, 0, 1) or 0,
		MPShort = num("Mana", 0) < def.MP,
		Def = def,
	}
end

local function paintButton(b)
	local st = stateOf(b.Slot)
	b.State = st
	local visible = st.On and not st.Locked -- A23-71: no locked slot on the screen
	if b.Holder.Visible ~= visible then b.Holder.Visible = visible end
	-- the learn moment: unlocked while I was already playing (a save loading past the level shows nothing)
	local live = LocalPlayer:GetAttribute("DataLoaded") == true and LocalPlayer:GetAttribute("ClassChosen") == true
	if visible and b.Live and b.WasLocked == true then LEARN.Show(b, st) end
	b.WasLocked = st.Locked
	b.Live = live
	if not visible then return end
	setIcon(b)
	local tint = (st.Locked and COL.Locked) or (st.MPShort and COL.Dim) or COL.White
	if b.Icon and b.Icon:IsA("ImageLabel") then
		b.Icon.ImageColor3 = tint
	elseif b.Icon and b.Icon:IsA("TextLabel") then
		b.Icon.TextColor3 = tint
	end
	if st.Locked then setSweep(b, 1) end -- the face stays shaded while locked (the 10 Hz tick leaves it alone)
	-- MP short: the whole button dims (A23-60: no MP number on it)
	if b.Disc and b.Disc:IsA("ImageLabel") then b.Disc.ImageColor3 = (st.MPShort and not st.Locked) and COL.Dim or COL.White end
	if b.Lock then b.Lock.Visible = st.Locked end
	if b.LockText then
		b.LockText.Visible = st.Locked
		b.LockText.Text = string.format(TXT.Level, st.Unlock)
	end
	if b.PillText then b.PillText.Text = st.Def.Name end
	if b.Pill then b.Pill.Visible = not st.Locked end
	if b.Key then
		-- only a key that works now (Keybinds.IsLive: SkillZ / SkillX are live once their flags are on), and only while
		-- Settings.KeyBadges ('Key hints') is on - A23-78: off by default, like the HUD and potion badges (검수 10/08)
		local kb, st = C and C.Keybinds, C and C.Settings
		local action = T.Action[b.Slot]
		local text, badges = "", true
		if type(st) == "table" and type(st.Get) == "function" then
			local okB, v = pcall(st.Get, "KeyBadges")
			badges = not okB or v ~= false
		end
		if type(kb) == "table" and type(kb.Label) == "function" and type(kb.IsLive) == "function" then
			local okLive, live = pcall(kb.IsLive, action)
			local okLabel, label = pcall(kb.Label, action)
			if okLive and live and okLabel and type(label) == "string" then text = label end
		end
		b.Key.Text = text
		b.Key.Visible = badges and text ~= ""
	end
	-- the disc art follows my faction's rim when that art exists
	local key = discKey()
	if key ~= b.DiscKey and b.Disc and b.Disc:IsA("ImageLabel") then
		local def = UIKit.ArtPart and UIKit.ArtPart(key)
		if def and def.Id then
			b.Disc.Image = def.Id
			b.DiscKey = key
		end
	end
end

local function flash(b)
	local s = b.RingStroke
	if not s then return end
	s.Color = COL.White
	s.Transparency = 0
	TweenService:Create(s, TweenInfo.new(T.Flash, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
end

-- 10 Hz: cooldown shade + seconds, the ready flash
local function tickButton(b)
	local st = b.State
	if not st or not st.On or st.Locked then return end
	local left = math.max(0, num(T.Ready[b.Slot], 0) - Util.Now())
	local frac = st.Def.CD > 0 and math.clamp(left / st.Def.CD, 0, 1) or 0
	setSweep(b, frac)
	local cooling = left > 0.05
	b.Seconds.Visible = cooling
	if cooling then b.Seconds.Text = tostring(math.ceil(left)) end
	if b.WasCooling and not cooling then
		flash(b)
		-- sound_gaps A10: the SkillReady blip (Fx's Click / our Tap until its file is uploaded)
		local audio = C and C.Audio
		local ok, played = false, false
		if type(audio) == "table" and type(audio.Play) == "function" then ok, played = pcall(audio.Play, "SkillReady") end
		local fx = C and C.Fx
		if not (ok and played) and type(fx) == "table" and type(fx.PlaySound) == "function" then pcall(fx.PlaySound, "Click") end
		guard(function() paintButton(b) end, "paint")
	end
	b.WasCooling = cooling
end

local function refreshAll()
	for _, slot in T.Slots do
		local b = ui.buttons[slot]
		if b then guard(function() paintButton(b) end, "paint " .. slot) end
	end
end

----------------------------------------------------------------- refusals / queue
local function shake(b, word)
	local h = b.Holder
	b.ShakeToken = (b.ShakeToken or 0) + 1
	local token = b.ShakeToken
	task.spawn(function()
		for _, deg in T.Shake do
			if b.ShakeToken ~= token then return end
			h.Rotation = deg
			task.wait(T.ShakeStep)
		end
	end)
	if word and word ~= "" then
		local w = b.Word
		w.Text = word
		w.Visible = true
		w.TextTransparency = 0
		w.Position = UDim2.fromScale(0.5, -0.05)
		local info = TweenInfo.new(T.FloatTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(w, info, { Position = UDim2.fromScale(0.5, -0.35), TextTransparency = 1 }):Play()
		local stroke = w:FindFirstChildWhichIsA("UIStroke")
		if stroke then
			stroke.Transparency = 0
			TweenService:Create(stroke, info, { Transparency = 1 }):Play()
		end
		task.delay(T.FloatTime, function()
			if b.ShakeToken == token then w.Visible = false end
		end)
	end
end

local function showQueue(slot, on)
	for s, b in ui.buttons do
		if b.RingStroke then
			local mine = on and s == slot
			b.RingStroke.Color = COL.White
			b.RingStroke.Transparency = mine and 0 or 1
		end
	end
end

local function remote(name)
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local r = folder and folder:FindFirstChild(name)
	return (r and r:IsA("RemoteEvent")) and r or nil
end

local function cast(slot)
	S.gapUntil = os.clock() + T.Gap
	if slot == "Q" then
		local hud = C and C.HUD
		if type(hud) == "table" and type(hud.Release) == "function" then
			guard(hud.Release, "release")
			return
		end
	end
	local r = remote("UseSkill") -- SKL-2 SkillService
	if r then
		r:FireServer(slot)
	elseif slot == "Q" then
		local rel = remote("Release")
		if rel then rel:FireServer() end
	end
end

-- after the gap: the press that waited in line goes (if it still may)
local function flushQueue()
	S.queueToken += 1
	local token = S.queueToken
	task.delay(math.max(0, S.gapUntil - os.clock()), function()
		if S.queueToken ~= token or not S.queued then return end
		local slot = S.queued
		S.queued = nil
		showQueue(slot, false)
		SkillBar.Use(slot)
	end)
end

----------------------------------------------------------------- layout
local function placeAll()
	local hud = C and C.HUD
	local layout = type(hud) == "table" and hud.Layout or nil
	local rects = type(layout) == "table" and type(layout.Rects) == "table" and layout.Rects or nil
	for _, slot in T.Slots do
		local b = ui.buttons[slot]
		local r = rects and rects[T.Rect[slot]] or nil
		if b and type(r) == "table" and tonumber(r.W) then
			b.Holder.Position = UDim2.fromOffset(r.X + r.W / 2, r.Y + r.H / 2)
			b.Holder.Size = UDim2.fromOffset(r.W, r.H)
		end
	end
	-- the words / pills keep a readable size on every UIScale (UIKit text styles floor them)
	local s = guiScale()
	for _, b in ui.buttons do
		if b.Word then b.Word.Size = UDim2.new(1.6, 0, 0, math.ceil(14 / s)) end
	end
end

----------------------------------------------------------------- A23-71 learn moment
function LEARN.Show(b, st)
	local slot = b.Slot
	if type(UIKit.Announce) == "function" then pcall(UIKit.Announce, string.format(TXT.NewSkill, st.Def.Name), LEARN.Banner) end
	-- the button pops in (no bounce with 'Screen shake' off)
	local reduced = type(UIKit.ReducedMotion) == "function" and UIKit.ReducedMotion()
	if not reduced then
		local scale = b.Holder:FindFirstChild("LearnPop") or Instance.new("UIScale")
		scale.Name = "LearnPop"
		scale.Scale = 0.2
		scale.Parent = b.Holder
		TweenService:Create(scale, TweenInfo.new(LEARN.Pop, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	-- one line on the new button: the key on keyboards, a tap on phones
	local line = TXT.LearnTouch
	if not IS_TOUCH then
		local kb = C and C.Keybinds
		local ok, label = false, nil
		if type(kb) == "table" and type(kb.Label) == "function" then ok, label = pcall(kb.Label, T.Action[slot]) end
		line = string.format(TXT.LearnKey, (ok and type(label) == "string" and label ~= "") and label or slot)
	end
	LEARN.HintWait[slot] = line
	task.delay(LEARN.HintAfter, LEARN.LateHint, slot)
	task.delay(LEARN.SoundDelay, LEARN.Sound)
	-- A23-81: the first skill (this moment comes once per account: the slot opens while I play) brings the keys tip on
	-- keyboards, after my first press of it, or TipLate s later if I never press
	if slot == LEARN.TipSlot and not IS_TOUCH then
		LEARN.TipPending = (Config.Nudges or {}).KeysTip ~= false -- 검수 10/09: the tip card is off (Config.Nudges.KeysTip)
		task.delay(LEARN.TipLate, LEARN.Tip)
	end
end

-- the learn line, HintAfter s after the learn moment, only if the skill is still unused
function LEARN.LateHint(slot)
	local line = LEARN.HintWait[slot]
	if not line then return end
	LEARN.HintWait[slot] = nil
	local hud = C and C.HUD
	if type(hud) == "table" and type(hud.Hint) == "function" then pcall(hud.Hint, slot, line) end
end

-- the keys tip (once): a calm card with [Open Settings] -> the Settings window's Keys tab (PauseCard waits for a free
-- screen; the same tip stays in Help)
function LEARN.Tip()
	if not LEARN.TipPending then return end
	LEARN.TipPending = false
	local card = C and C.PauseCard
	if type(card) == "table" and type(card.Show) == "function" then
		pcall(card.Show, "Tip", { Text = TXT.KeysTip, Go = { Text = TXT.KeysTipGo, Window = "Settings", Arg = { Tab = "Keys" } } })
	end
end

-- the SkillLearn sound (PowerUp until its file is uploaded)
function LEARN.Sound()
	local audio = C and C.Audio
	if type(audio) == "table" and type(audio.Play) == "function" then
		local ok, played = pcall(audio.Play, "SkillLearn")
		if not (ok and played) then pcall(audio.Play, "PowerUp") end
	end
end

-- a skill key before the first skill: one short toast now and then
function LEARN.Tell(level)
	if os.clock() - LEARN.TellAt < LEARN.TellGap then return end
	LEARN.TellAt = os.clock()
	if type(UIKit.Toast) == "function" then pcall(UIKit.Toast, string.format(TXT.Later, level), "info", 2.5) end
end

----------------------------------------------------------------- public API
function SkillBar.Owns(slot)
	return S.built and ui.buttons[slot] ~= nil
end

-- A23-68 #2: the slot's button frame (HUD.Hint hangs its ring / bubble on it), nil before the bar is built
function SkillBar.Button(slot)
	local b = S.built and ui.buttons[slot] or nil
	return b and b.Holder or nil
end

-- one press of a skill (button, key or pad). false when refused here (the button shook)
function SkillBar.Use(slot)
	local b = ui.buttons[slot]
	if not b then return false end
	if not b.Holder.Visible then
		local st = stateOf(slot)
		if st.On and st.Locked then LEARN.Tell(st.Unlock) end
		return false
	end
	LEARN.HintWait[slot] = nil -- used before the learn line came: it never comes
	local hud = C and C.HUD
	if type(hud) == "table" and type(hud.ClearHint) == "function" and type(hud.HintShown) == "function"
		and hud.HintShown(slot) then
		pcall(hud.ClearHint, slot) -- A23-68 #2: "Try your skill!" goes with the first press
	end
	if LEARN.TipPending and slot == LEARN.TipSlot then task.delay(LEARN.TipAfterPress, LEARN.Tip) end -- A23-81
	if type(hud) == "table" and type(hud.InputAllowed) == "function" then
		local ok, allowed = pcall(hud.InputAllowed)
		if ok and allowed == false then return false end
	end
	local st = stateOf(slot)
	b.State = st
	if st.Locked then
		shake(b, string.format(TXT.Unlock, st.Unlock))
		return false
	end
	if st.Left > 0.05 then
		shake(b, skillWord("NotReady"))
		return false
	end
	if st.MPShort then
		shake(b, skillWord("NoMP"))
		local audio = C and C.Audio -- the 'no' sound once Audio.luau exists (quality ideas ①)
		if type(audio) == "table" and type(audio.Play) == "function" then pcall(audio.Play, "No") end
		return false
	end
	if os.clock() < S.gapUntil then
		-- inside the gap between casts: this press waits in line (the newest one wins)
		S.queued = slot
		showQueue(slot, true)
		flushQueue()
		return true
	end
	cast(slot)
	return true
end

-- 2-C #8: the server's answer to my press (Fx "SkillPress"): a refusal shakes the button with its short word -> true
function SkillBar.OnPress(data)
	if type(data) ~= "table" or not ui.buttons then return false end
	local b = ui.buttons[data.Slot]
	local key = PRESS.Word[data.Result]
	if not (b and key) then return false end
	local word = skillWord(key)
	if data.Result == "Locked" then
		local st = stateOf(data.Slot)
		if st.Locked then word = string.format(TXT.Unlock, st.Unlock) end
	end
	if S.queued == data.Slot then -- the line waiting behind a refused press goes too
		S.queued = nil
		showQueue(data.Slot, false)
	end
	shake(b, word)
	if data.Result == "NoMP" then
		local audio = C and C.Audio
		if type(audio) == "table" and type(audio.Play) == "function" then pcall(audio.Play, "No") end
	end
	return true
end

-- 2-C #8 prep (pure): the landing height - To's ground plus how high my root stood over the ground I left (the
-- server's To keeps my root height on flat ground); no ground under one of them = To as it is
function SkillBar.HopLanding(from, to, groundFrom, groundTo)
	if type(groundFrom) == "number" and type(groundTo) == "number" then
		return Vector3.new(to.X, groundTo + math.clamp(from.Y - groundFrom, 0, 6), to.Z)
	end
	return to
end

-- (pure) the point at a (0..1) along a low arc from -> to, height h at the middle
function SkillBar.HopPoint(from, to, a, h)
	a = math.clamp(a, 0, 1)
	return Vector3.new(from.X + (to.X - from.X) * a, from.Y + (to.Y - from.Y) * a + 4 * h * a * (1 - a),
		from.Z + (to.Z - from.Z) * a)
end

local function groundY(pos, char)
	local ok, hit = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		return workspace:Raycast(pos + Vector3.new(0, HOP.Ray / 2, 0), Vector3.new(0, -HOP.Ray * 1.5, 0), params)
	end)
	return (ok and hit) and hit.Position.Y or nil
end

-- the server's Fx "Hop" { To, T }: my client moves my character there -> true when a hop started
function SkillBar.OnHop(data)
	if type(data) ~= "table" or typeof(data.To) ~= "Vector3" then return false end
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum and hum.Health > 0) then return false end
	local from = root.Position
	local flat = Vector3.new(data.To.X - from.X, 0, data.To.Z - from.Z).Magnitude
	if flat < 0.5 or flat > HOP.MaxDist then return false end
	local to = SkillBar.HopLanding(from, data.To, groundY(from, char), groundY(data.To, char))
	local t = math.clamp(tonumber(data.T) or 0.25, HOP.TMin, HOP.TMax)
	HOP.Live = { Char = char, Root = root, Hum = hum, From = from, To = to, Start = os.clock(), T = t,
		H = math.clamp(flat * HOP.Arc, HOP.ArcMin, HOP.ArcMax) }
	return true
end

-- one frame of the running hop (Heartbeat): the root follows the arc, keeps its facing; it ends at To, still
function SkillBar.HopStep(now)
	local h = HOP.Live
	if not h then return end
	if LocalPlayer.Character ~= h.Char or not h.Root.Parent or h.Hum.Health <= 0 then
		HOP.Live = nil
		return
	end
	local a = math.clamp((now - h.Start) / h.T, 0, 1)
	local p = SkillBar.HopPoint(h.From, h.To, a, h.H)
	h.Root.CFrame = h.Root.CFrame.Rotation + p
	if a >= 1 then
		h.Root.AssemblyLinearVelocity = Vector3.zero
		HOP.Live = nil
	end
end

function SkillBar.Relayout()
	if not S.built then return end
	guard(placeAll, "layout")
end

function SkillBar.Init(registry)
	C = registry
end

function SkillBar.Start()
	UIKit = C and C.UIKit
	if type(UIKit) ~= "table" or not UIKit.Gui then
		Util.Warn(TAG, "UIKit is not initialized")
		return
	end
	local ok, err = pcall(function()
		ui.buttons = {}
		ui.root = UIKit.Create("Frame", {
			Name = "SkillBar", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Active = false,
			Parent = UIKit.Gui,
		})
		pcall(function()
			ui.root.Interactable = true
		end)
		for _, slot in T.Slots do buildButton(slot) end
		S.built = true
	end)
	if not ok or not S.built then
		Util.Warn(TAG, "build failed: " .. tostring(err))
		return
	end
	-- the HUD root hides the bar with it (pickers, opening, loading)
	local function follow()
		local hud = C and C.HUD
		local shown = true
		if type(hud) == "table" and type(hud.IsVisible) == "function" then
			local okV, v = pcall(hud.IsVisible)
			shown = okV and v == true
		end
		if ui.root.Visible ~= shown then ui.root.Visible = shown end
	end
	UIKit.OnAttr({ "Mana", "MaxMana", "Level", "Class", "ClassChosen", "Faction", "SkillReadyAt", "SkillReadyAtZ",
		"SkillReadyAtX", "SkillBarPreview", "SkillSlots" }, refreshAll)
	-- 2-C #8: the server's press answers and the X hop (Fx; the Remotes folder comes from the server)
	task.spawn(function()
		local okFx, fx = pcall(function()
			local folder = ReplicatedStorage:WaitForChild("Remotes", 30)
			return folder and folder:WaitForChild("Fx", 30)
		end)
		if not (okFx and typeof(fx) == "Instance" and fx:IsA("RemoteEvent")) then return end
		fx.OnClientEvent:Connect(function(kind, data)
			if kind == "SkillPress" then
				guard(function() SkillBar.OnPress(data) end, "press")
			elseif kind == "Hop" then
				guard(function() SkillBar.OnHop(data) end, "hop")
			end
		end)
	end)
	RunService.Heartbeat:Connect(function()
		if HOP.Live then guard(function() SkillBar.HopStep(os.clock()) end, "hop step") end
	end)
	RunService.Heartbeat:Connect(function(dt)
		acc.Tick += dt
		if acc.Tick < T.Tick then return end
		acc.Tick = 0
		guard(follow, "visibility")
		if not ui.root.Visible then return end
		for _, b in ui.buttons do tickButton(b) end
		-- the HUD made a new layout (screen size, scale): follow it
		local hud = C and C.HUD
		local layout = type(hud) == "table" and hud.Layout or nil
		if layout ~= S.layoutRef then
			S.layoutRef = layout
			guard(placeAll, "layout")
		end
	end)
	refreshAll()
	SkillBar.Relayout()
	-- one Q button: HUD hides its own
	local hud = C and C.HUD
	if type(hud) == "table" and type(hud.SkillBarReady) == "function" then guard(hud.SkillBarReady, "hand-off") end
	UIKit.OnAttr({ "DataLoaded" }, refreshAll) -- the learn moment only starts once the save is in
	-- the key badges follow key changes and the 'Key hints' setting at once (VitalsUI.RefreshKeys does the same)
	for _, src in { C and C.Keybinds, C and C.Settings } do
		if type(src) == "table" and type(src.Changed) == "table" and type(src.Changed.Connect) == "function" then
			src.Changed:Connect(refreshAll)
		end
	end
	print("[SkillBar] started")
end

SkillBar.Learn = LEARN -- test aid
SkillBar._T = { PRESS = PRESS, HOP = HOP, S = S, ui = ui } -- tools/test_skill_press.py

return SkillBar
