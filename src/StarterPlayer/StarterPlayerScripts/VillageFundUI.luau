-- VillageFundUI.luau (게임성 개발 1, 2026-10-14; A23-178 B, user 10/14 "마을 기금은 좋아"): the village fund on this client.
-- Server contract: docs/design/village_fund_server_2026-10-14.md (VillageFundService, 게임성 개발 2) - §8 is this module:
--   1. My own town's fountain has the server's ProximityPrompt "FundPrompt" (Workspace.VillageFund.FundSpot_<side>;
--      G, a prompt button on phones; ActionText "" + attributes ActionKey / ObjectKey / Faction). This client writes its
--      words (the Config path in the key) and switches off every FundPrompt that is not my side's (Neutral / no side:
--      all off; the server ignores them anyway). The server answers a press - and every gift, done or not - with Net
--      "FundOpen" state = { Faction, Today, PerDay, Step, Gold, Can, Why, Week (the week number), Sum (my side's total),
--      Goals, Level } -> a small card (Panels window "VillageFund"): my side's line (Halo = Share / Horns = Show off),
--      "Today n/3", my gold, [Share 1,000 gold] / [Show off 1,000 gold] -> Net "FundGive":FireServer() (no arguments:
--      the server decides amount, side and count) and [Close]. A new FundOpen redraws the open card in place.
--   2. Not enough gold / 3 gifts today / the fund switched off: [Give] is greyed and one reason line shows (the
--      server's Why and its words Config.VillageFund.Text.Poor / .Full / .Closed).
--   3. Under the card: my side's weekly total bar with two marks (lanterns, fireworks); numbers = the GameState
--      attributes FundHalo / FundHorns (live while the card is open; the state's Sum until they come).
--   4. A town at level 1 (GameState FundLevelHalo / FundLevelHorns) gets lanterns (always on), at level 2 also fireworks at night
--      (GameState DayPhase "Night"): round soft glows, sparkles, stars and confetti only - nothing fans out as rays (user
--      10/07). Anyone who walks into that town sees them. Phones / "Screen Shake: Off" / Reduced Motion: fewer particles
--      (FountainFx's rule). Client-only parts (Anchored, no collision / queries / touch) in workspace "VillageFundFx".
-- Words: Config.VillageFund.Text (game dev 2's table: Title, Today, Poor, Full, Closed, [side].Give / .Prompt) +
-- Config.VillageFundScreen (this card's own extra words: Lead, Gold, Close, the bar).
-- New look: none - the Panels window, its kit buttons and UIKit.ArtBar; free Roblox particle textures only.
-- API: VillageFundUI.Init(C), VillageFundUI.Start(), VillageFundUI.State() (the last FundOpen state or nil); pure:
-- VillageFundUI.Reason(state), VillageFundUI.CardLines(state), VillageFundUI.BarParts(total, goals), VillageFundUI.Word(key),
-- VillageFundUI.PromptOn(promptSide, mySide), VillageFundUI.FxPlan(level, phase, phone, calm).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer

local VillageFundUI = {}
local C = nil
local TAG = "VillageFundUI"

-- layout (du), timing and the town glow
local L = {
	Window = "VillageFund", Width = 460,
	ButtonW = 190, ButtonH = 52, BarW = 380, BarH = 14, Gap = 12,
	Wait = 1, -- s [Give] stays locked after a press without an answer (the server's Rate)
	Away = 8, -- studs past the fountain's Radius that close the card
	Poll = 0.5, -- s between the card distance / fireworks / prompt checks
	Prompt = "FundPrompt",
	Folder = "VillageFundFx",
	Sides = { "Halo", "Horns" },
	Lantern = { Count = 8, PhoneCount = 4, Ring = 0.8, Up = 7, Range = 9, Brightness = 0.9, Rate = 3 },
	Firework = { Up = 30, Every = { 2.6, 4.2 }, PhoneEvery = { 5, 7 }, Stars = 36, Confetti = 24 },
	Tex = {
		Glow = "rbxasset://textures/particles/sparkles_main.dds", -- round soft sparkle (built in)
		Star = "rbxassetid://244221535", -- "Sparkles Particle" (Nanonauts, FountainFx's)
	},
}
local COL = {
	Halo = Color3.fromRGB(255, 214, 90), -- warm gold (FountainFx Halo)
	Horns = Color3.fromRGB(190, 110, 255), -- soft purple (ChoiceCard afterglow smoke)
	Bright = { Color3.fromRGB(255, 226, 140), Color3.fromRGB(255, 150, 200), Color3.fromRGB(140, 210, 255),
		Color3.fromRGB(170, 255, 170), Color3.fromRGB(210, 160, 255) },
}
-- State = the last FundOpen state; SentAt = when [Give] went out (-inf = none); Prompts = FundPrompt -> its side;
-- Towns[side] = { Folder, Level, Lights = {}, Burst = part?, NextBurst }; Emitters = { { Emitter, Rate, Kind } }
-- 최종 검수 10/14 FIX 1: Prompts is a STRONG table (a weak one let a prompt switched off before I picked a side drop
-- out, and it stayed off after the pick); gone prompts are dropped in applyPrompts
local S = { Ready = false, State = nil, SentAt = -math.huge, Prompts = {}, Towns = {},
	Emitters = {}, Rng = Random.new() }
local VIEW = { Shown = false }

local function fund() return type(Config.VillageFund) == "table" and Config.VillageFund or nil end
local function words() return type(Config.VillageFundScreen) == "table" and Config.VillageFundScreen or {} end
local function serverText()
	local f = fund()
	return (f and type(f.Text) == "table") and f.Text or {}
end
local function spot(side)
	local f = fund()
	local spots = f and type(f.Spots) == "table" and f.Spots or nil
	local s = spots and spots[side]
	return (type(s) == "table" and typeof(s.Pos) == "Vector3") and s or nil
end
-- the fountain spot's pivot: the server's Workspace.VillageFund.FundSpot_<side> part (the prompt sits Lift studs over the
-- pivot of the fountain model; 개발 2 07ca5b92), else Config Spots[side].Pos (the server's own fallback)
local function spotPos(sd)
	local sp = spot(sd)
	if not sp then return nil end
	local folder = workspace:FindFirstChild("VillageFund")
	local part = folder and folder:FindFirstChild("FundSpot_" .. sd)
	if part and part:IsA("BasePart") then
		return part.Position - Vector3.new(0, tonumber(sp.Lift) or 3, 0)
	end
	return sp.Pos
end

local function n(v, default)
	v = tonumber(v)
	return (v ~= nil and v == v and v ~= math.huge and v ~= -math.huge) and v or default
end
local function fmt(s, ...)
	if type(s) ~= "string" then return "" end
	local ok, out = pcall(string.format, s, ...)
	return ok and out or s
end
local function side(v) return (v == "Halo" or v == "Horns") and v or nil end

---------------------------------------------------------------------------------------------------- pure
-- why [Give] is off for this state: the server's Why ("Poor" / "Full" / "Closed") when it sends one, else worked out
-- here: "Full" (PerDay today - the stronger one), "Poor" (less gold than one gift), "Closed" (the server says Can =
-- false without a reason) or nil. ctx (this client, 최종 검수 10/14 MINOR ①) = { Dead, Far }: the server only takes a gift
-- from a living player inside Radius, so a knocked-out player reads "Closed" and one past Radius "Far" first
function VillageFundUI.Reason(state, ctx)
	if type(state) ~= "table" then return "Full" end
	if type(ctx) == "table" and ctx.Dead == true then return "Closed" end
	if type(ctx) == "table" and ctx.Far == true then return "Far" end
	if state.Why == "Poor" or state.Why == "Full" or state.Why == "Closed" then return state.Why end
	local f = fund() or {}
	local per, step = n(state.PerDay, n(f.PerDay, 3)), n(state.Step, n(f.Step, 1000))
	if n(state.Today, 0) >= per then return "Full" end
	if n(state.Gold, 0) < step then return "Poor" end
	if state.Can == false then return "Closed" end
	return nil
end

-- the card's words for a state (+ ctx, see Reason): { Lead, Today, Gold, Give, Reason?, CanGive }
function VillageFundUI.CardLines(state, ctx)
	state = type(state) == "table" and state or {}
	local f = fund() or {}
	local w = words()
	local my = side(state.Faction)
	local per, step = n(state.PerDay, n(f.PerDay, 3)), n(state.Step, n(f.Step, 1000))
	local t = serverText()
	local mine = type(t[my or ""]) == "table" and t[my or ""] or {}
	local lead = type(w.Lead) == "table" and w.Lead[my or ""] or nil
	local why = VillageFundUI.Reason(state, ctx)
	local reason = nil
	if why == "Poor" then
		reason = fmt(t.Poor, Util.FormatInt(step))
	elseif why == "Full" then
		reason = fmt(t.Full, per)
	elseif why == "Closed" then
		reason = fmt(t.Closed)
	elseif why == "Far" then
		reason = fmt(w.Far)
	end
	return {
		Lead = fmt(lead, math.max(1, math.floor(n(f.Points, 1)))),
		Today = fmt(t.Today, math.clamp(math.floor(n(state.Today, 0)), 0, per), per),
		Gold = fmt(w.Gold, Util.FormatInt(math.max(0, math.floor(n(state.Gold, 0))))),
		Give = fmt(mine.Give, Util.FormatInt(step)),
		Reason = (reason ~= nil and reason ~= "") and reason or nil,
		CanGive = my ~= nil and why == nil,
	}
end

-- the weekly bar for a side's total: Fill 0..1 of the fireworks goal, Mark = where the lantern goal sits, Level 0/1/2
function VillageFundUI.BarParts(total, goals)
	local f = fund() or {}
	goals = type(goals) == "table" and goals or (type(f.Goals) == "table" and f.Goals or {})
	local lan, fire = math.max(1, n(goals.Lanterns, 30000)), math.max(1, n(goals.Fireworks, 100000))
	if fire < lan then fire = lan end
	total = math.max(0, n(total, 0))
	return { Fill = math.clamp(total / fire, 0, 1), Mark = math.clamp(lan / fire, 0, 1), Lanterns = lan, Fireworks = fire,
		Level = total >= fire and 2 or total >= lan and 1 or 0 }
end

-- may this client use a fountain prompt of `promptSide`? only my own side's, never Neutral / no side
function VillageFundUI.PromptOn(promptSide, mySide)
	return side(mySide) ~= nil and side(promptSide) == side(mySide)
end

-- what a town shows: { Lanterns, Fireworks, Lights (lantern count), Mult (particle rate factor) }
function VillageFundUI.FxPlan(level, phase, phone, calm)
	level = math.floor(n(level, 0))
	local mult = 1
	if phone then mult *= 0.5 end
	if calm then mult *= 0.4 end
	return { Lanterns = level >= 1, Fireworks = level >= 2 and phase == "Night",
		Lights = phone and L.Lantern.PhoneCount or L.Lantern.Count, Mult = mult }
end

---------------------------------------------------------------------------------------------------- world reads
local function gameState()
	local ok, gs = pcall(function() return ReplicatedStorage:FindFirstChild("GameState") end)
	return ok and gs or nil
end

-- the fund attributes: the GameState folder (VillageFundService; Net.GameStateDefaults), else ReplicatedStorage itself
local function fundAttr(key)
	local gs = gameState()
	local v = gs and gs:GetAttribute(key)
	if v == nil then v = ReplicatedStorage:GetAttribute(key) end
	return v
end

local function phase()
	local gs = gameState()
	local p = gs and gs:GetAttribute("DayPhase")
	local preview = LocalPlayer and LocalPlayer:GetAttribute("DayPhasePreview") -- WeatherFx's Studio photo hook
	return type(preview) == "string" and preview or p
end

local function lowFx()
	local phone = UserInputService.TouchEnabled == true and UserInputService.KeyboardEnabled ~= true
	local calm = false
	local st = C and C.Settings
	if type(st) == "table" and type(st.Get) == "function" then
		local ok, v = pcall(st.Get, "Shake")
		calm = ok and v == false
	end
	local okRm, reduced = pcall(function() return GuiService.ReducedMotionEnabled end)
	return phone, calm or (okRm and reduced == true)
end

local function mySide() return side(LocalPlayer and LocalPlayer:GetAttribute("Faction")) end

local function rootPos()
	local char = LocalPlayer and LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

---------------------------------------------------------------------------------------------------- prompts
-- the side a FundPrompt belongs to: its "Faction" attribute (or its model's), else the nearest fountain spot
local function promptSide(p)
	local a = side(p:GetAttribute("Faction"))
	if a then return a end
	local m = p:FindFirstAncestorWhichIsA("Model")
	a = m and side(m:GetAttribute("Faction"))
	if a then return a end
	local parent = p.Parent
	local pos = parent and (parent:IsA("BasePart") and parent.Position or (parent:IsA("Attachment") and parent.WorldPosition))
	if typeof(pos) ~= "Vector3" then return nil end
	local best, bestD = nil, math.huge
	for _, sd in L.Sides do
		local sp, at = spot(sd), spotPos(sd)
		if sp and at then
			local d = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(at.X, 0, at.Z)).Magnitude
			if d < bestD and d <= n(sp.Radius, 16) * 3 then best, bestD = sd, d end
		end
	end
	return best
end

local function applyPrompts()
	local me = mySide()
	for p, sd in S.Prompts do
		if p.Parent then
			local on = VillageFundUI.PromptOn(sd, me)
			if p.Enabled ~= on then p.Enabled = on end
		else
			S.Prompts[p] = nil
		end
	end
end

-- a prompt word from its key: the Config path in the attribute ("Config.VillageFund.Text.Halo.Prompt"), "" if unknown
function VillageFundUI.Word(key)
	if type(key) ~= "string" or string.sub(key, 1, 7) ~= "Config." then return "" end
	local v = Config
	for part in string.gmatch(string.sub(key, 8), "[^%.]+") do
		if type(v) ~= "table" then return "" end
		v = v[part]
	end
	return type(v) == "string" and v or ""
end

local function consider(inst)
	if not (inst:IsA("ProximityPrompt") and inst.Name == L.Prompt) then return end
	local action, object = VillageFundUI.Word(inst:GetAttribute("ActionKey")), VillageFundUI.Word(inst:GetAttribute("ObjectKey"))
	if action ~= "" then inst.ActionText = action end
	if object ~= "" then inst.ObjectText = object end
	S.Prompts[inst] = promptSide(inst) or false
	local on = VillageFundUI.PromptOn(S.Prompts[inst], mySide())
	if inst.Enabled ~= on then inst.Enabled = on end
end

---------------------------------------------------------------------------------------------------- the card
local function panels()
	local p = C and C.Panels
	return type(p) == "table" and p or nil
end

local function windowOpen()
	local p = panels()
	if not p or type(p.CurrentId) ~= "function" then return nil end
	local ok, id = pcall(p.CurrentId)
	return ok and id or nil
end

local function closeCard()
	local p = panels()
	if p and windowOpen() == L.Window then pcall(p.Close) end
end

local function weekTotal(state)
	local my = side(state and state.Faction)
	local v = my and n(fundAttr("Fund" .. my), nil)
	return v or n(state and state.Sum, 0)
end

local function paintBar()
	local state = S.State
	if not (VIEW.Shown and state) then return end
	local bar = VillageFundUI.BarParts(weekTotal(state), state.Goals)
	if VIEW.SetBar then pcall(VIEW.SetBar, bar.Fill) end
	if VIEW.Mark then VIEW.Mark.Position = UDim2.new(bar.Mark, -1, 0, 0) end
	local w = words()
	if VIEW.Week then VIEW.Week.Text = fmt(w.Week, Util.FormatInt(math.floor(weekTotal(state)))) end
	if VIEW.Marks then
		VIEW.Marks.Text = fmt(w.Marks, w.Lanterns or "", Util.FormatInt(bar.Lanterns), w.Fireworks or "", Util.FormatInt(bar.Fireworks))
	end
end

-- this client's side of a gift: knocked out / past the fountain's Radius (the server refuses both)
local function cardCtx(state)
	local char = LocalPlayer and LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local ctx = { Dead = not (root and hum and hum.Health > 0), Far = false }
	local sd = side(state and state.Faction)
	local sp, at = sd and spot(sd), sd and spotPos(sd)
	if root and sp and at then
		ctx.Far = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(at.X, 0, at.Z)).Magnitude > n(sp.Radius, 16)
	end
	return ctx
end

-- the open card shows S.State (in place: a new FundOpen redraws the numbers)
local function paint()
	local state = S.State
	if not (VIEW.Shown and state) then return end
	local lines = VillageFundUI.CardLines(state, cardCtx(state))
	if VIEW.Lead then VIEW.Lead.Text = lines.Lead end
	if VIEW.Today then VIEW.Today.Text = lines.Today end
	if VIEW.Gold then VIEW.Gold.Text = lines.Gold end
	if VIEW.Reason then
		VIEW.Reason.Text = lines.Reason or ""
		VIEW.Reason.Visible = lines.Reason ~= nil
	end
	local k = VIEW.Kit
	if k and VIEW.Give then
		VIEW.Give.Text = lines.Give
		pcall(k.SetEnabled, VIEW.Give, lines.CanGive and os.clock() - S.SentAt >= L.Wait)
	end
	paintBar()
end

local function give()
	local state = S.State
	if not state or not VillageFundUI.CardLines(state, cardCtx(state)).CanGive then return end
	if os.clock() - S.SentAt < L.Wait then return end
	S.SentAt = os.clock()
	if VIEW.Kit and VIEW.Give then pcall(VIEW.Kit.SetEnabled, VIEW.Give, false) end
	local ok, err = pcall(function() Net.Get("FundGive"):FireServer() end)
	if not ok then Util.Warn(TAG, "FundGive: " .. tostring(err)) end
end

local function build(parent, k)
	VIEW.Kit, VIEW.Shown = k, true
	local w = words()
	local col = COL[side(S.State and S.State.Faction) or "Halo"]
	VIEW.Lead = k.Text(parent, "", { Name = "Lead", Size = 18, Align = Enum.TextXAlignment.Center })
	local info = k.Row(parent, 0, L.Gap * 2)
	info.Name = "Info"
	VIEW.Today = k.Text(info, "", { Name = "Today", Size = 18, Width = UDim2.new(0.5, -L.Gap, 0, 0),
		Align = Enum.TextXAlignment.Center, Color = k.Theme.Gold })
	VIEW.Gold = k.Text(info, "", { Name = "Gold", Size = 18, Width = UDim2.new(0.5, -L.Gap, 0, 0),
		Align = Enum.TextXAlignment.Center, Color = k.Theme.Gold })
	local buttons = k.Row(parent, L.ButtonH, L.Gap)
	buttons.Name = "Buttons"
	VIEW.Give = k.Button(buttons, "", k.Palette.Free, UDim2.fromOffset(L.ButtonW, L.ButtonH), give)
	VIEW.Give.Name = "GiveButton"
	local close = k.Button(buttons, w.Close or "Close", k.Palette.Button, UDim2.fromOffset(L.ButtonW, L.ButtonH), closeCard)
	close.Name = "CloseButton"
	VIEW.Reason = k.Text(parent, "", { Name = "Reason", Size = 16, Align = Enum.TextXAlignment.Center,
		Color = k.Theme.SubText })
	-- the weekly bar: my side's total toward the fireworks goal, a thin mark where the lanterns come
	VIEW.Week = k.Text(parent, "", { Name = "Week", Size = 16, Align = Enum.TextXAlignment.Center })
	local barRow = k.Row(parent, L.BarH + 4, 0)
	barRow.Name = "WeekBar"
	local UIKit = C and C.UIKit
	if type(UIKit) == "table" and type(UIKit.ArtBar) == "function" then
		local ok, frame, set = pcall(UIKit.ArtBar, { Name = "FundBar", Size = UDim2.fromOffset(L.BarW, L.BarH), Color = col,
			Parent = barRow })
		if ok and frame then
			VIEW.Bar, VIEW.SetBar = frame, set
			local mark = Instance.new("Frame")
			mark.Name = "LanternMark"
			mark.BorderSizePixel = 0
			mark.BackgroundColor3 = Color3.new(1, 1, 1)
			mark.Size = UDim2.new(0, 2, 1, 0)
			mark.ZIndex = (frame.ZIndex or 1) + 2
			mark.Parent = frame
			VIEW.Mark = mark
		end
	end
	VIEW.Marks = k.Text(parent, "", { Name = "Marks", Size = 14, Align = Enum.TextXAlignment.Center, Color = k.Theme.SubText })
	paint()
	return nil
end

local function cleanup()
	for key in VIEW do VIEW[key] = nil end
	VIEW.Shown = false
end

local function valid(state)
	return type(state) == "table" and side(state.Faction) ~= nil
end

function VillageFundUI.OnOpen(state)
	if not valid(state) then return false end
	S.State = state
	S.SentAt = -math.huge -- the answer came: [Give] may go again
	if VIEW.Shown then
		paint()
		return true
	end
	local p = panels()
	if not (S.Ready and p and type(p.Open) == "function") then return false end
	local ok, err = pcall(p.Open, L.Window)
	if not ok then Util.Warn(TAG, "open failed: " .. tostring(err)) end
	return ok
end

---------------------------------------------------------------------------------------------------- the town glow
local function emitter(parent, kind, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = kind
	for key, v in props do e[key] = v end
	e.Parent = parent
	table.insert(S.Emitters, { Emitter = e, Rate = props.Rate or 0, Kind = kind })
	return e
end

local function ghostPart(name, pos, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Position = pos
	p.Parent = parent
	return p
end

local function folder()
	local f = workspace:FindFirstChild(L.Folder)
	if not f then
		f = Instance.new("Folder")
		f.Name = L.Folder
		f.Parent = workspace
	end
	return f
end

local function clearTown(sd)
	local t = S.Towns[sd]
	if t and t.Folder then pcall(function() t.Folder:Destroy() end) end
	S.Towns[sd] = nil
	for i = #S.Emitters, 1, -1 do
		if not S.Emitters[i].Emitter.Parent then table.remove(S.Emitters, i) end
	end
end

-- lanterns: a ring of round soft glows over the fountain, each with one warm light
local function buildTown(sd, plan)
	local sp, base = spot(sd), spotPos(sd)
	if not (sp and base) then return end
	local f = Instance.new("Folder")
	f.Name = sd
	f.Parent = folder()
	local t = { Folder = f, Lights = plan.Lights, Burst = nil, NextBurst = 0, Base = base }
	S.Towns[sd] = t
	local r = n(sp.Radius, 16) * L.Lantern.Ring
	for i = 1, plan.Lights do
		local a = (i - 1) / plan.Lights * math.pi * 2
		local p = ghostPart("Lantern" .. i, base + Vector3.new(math.cos(a) * r, L.Lantern.Up, math.sin(a) * r), f)
		emitter(p, "Glow", { Texture = L.Tex.Glow, Color = ColorSequence.new(COL[sd]), LightEmission = 1,
			LightInfluence = 0, Rate = L.Lantern.Rate, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(0, 0.2),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.5, 1.3),
				NumberSequenceKeypoint.new(1, 0.9) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.25),
				NumberSequenceKeypoint.new(1, 1) }), LockedToPart = true, SpreadAngle = Vector2.new(0, 0) })
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Shadows = COL[sd], L.Lantern.Range, L.Lantern.Brightness, false
		light.Parent = p
	end
	-- fireworks: one high point; bursts are round puffs of stars and confetti (Emit only, no stream, no streaks)
	local b = ghostPart("Fireworks", base + Vector3.new(0, L.Firework.Up, 0), f)
	emitter(b, "Stars", { Texture = L.Tex.Glow, LightEmission = 1, LightInfluence = 0, Rate = 0,
		Lifetime = NumberRange.new(1.2, 1.9), Speed = NumberRange.new(8, 16), SpreadAngle = Vector2.new(180, 180),
		Drag = 3, Acceleration = Vector3.new(0, -5, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.2) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) })
	emitter(b, "Confetti", { Texture = L.Tex.Star, LightEmission = 0.6, LightInfluence = 0.2, Rate = 0,
		Lifetime = NumberRange.new(1.8, 2.6), Speed = NumberRange.new(5, 11), SpreadAngle = Vector2.new(180, 180),
		Drag = 2, Acceleration = Vector3.new(0, -7, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0.35) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.2),
			NumberSequenceKeypoint.new(1, 1) }) })
	t.Burst = b
end

local function applyRates(mult)
	for _, e in S.Emitters do
		if e.Emitter.Parent and e.Kind == "Glow" then e.Emitter.Rate = e.Rate * mult end
	end
end

local function burst(t, plan, now)
	local b = t.Burst
	if not (b and b.Parent) then return end
	local stars, confetti = b:FindFirstChild("Stars"), b:FindFirstChild("Confetti")
	local c1 = COL.Bright[S.Rng:NextInteger(1, #COL.Bright)]
	local c2 = COL.Bright[S.Rng:NextInteger(1, #COL.Bright)]
	if stars then
		stars.Color = ColorSequence.new(c1)
		stars:Emit(math.max(4, math.floor(L.Firework.Stars * plan.Mult)))
	end
	if confetti then
		confetti.Color = ColorSequence.new(c1, c2)
		confetti:Emit(math.max(3, math.floor(L.Firework.Confetti * plan.Mult)))
	end
	local every = plan.Mult < 1 and L.Firework.PhoneEvery or L.Firework.Every
	t.NextBurst = now + every[1] + S.Rng:NextNumber() * (every[2] - every[1])
end

-- one look at both towns: build / clear lanterns by level, fireworks bursts at night
local function townStep(now)
	local phone, calm = lowFx()
	local ph = phase()
	local mult = 1
	for _, sd in L.Sides do
		local plan = VillageFundUI.FxPlan(fundAttr("FundLevel" .. sd), ph, phone, calm)
		local t = S.Towns[sd]
		local at = spotPos(sd)
		if not plan.Lanterns or not at then
			if t then clearTown(sd) end
		else
			-- a new lantern count (phone) or the fountain spot moved (the server's part came / the map changed): rebuild
			if t and (t.Lights ~= plan.Lights or (t.Base and (t.Base - at).Magnitude > 1)) then
				clearTown(sd)
				t = nil
			end
			if not t then
				local ok, err = pcall(buildTown, sd, plan)
				if not ok then Util.Warn(TAG, "town glow " .. sd .. ": " .. tostring(err)) end
				t = S.Towns[sd]
			end
			if t and plan.Fireworks and now >= t.NextBurst then burst(t, plan, now) end
		end
		mult = plan.Mult
	end
	applyRates(mult)
end

-- the poll: the card closes when I walk away from my fountain; the towns follow their level
local function step(now)
	local state = S.State
	if VIEW.Shown and state then
		local sd = side(state.Faction) or ""
		local sp, at = spot(sd), spotPos(sd)
		local pos = rootPos()
		if sp and at and pos then
			local d = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(at.X, 0, at.Z)).Magnitude
			if d > n(sp.Radius, 16) + L.Away then closeCard() end
		end
		if VIEW.Shown and S.SentAt > -math.huge and now - S.SentAt >= L.Wait then
			S.SentAt = -math.huge
		end
		if VIEW.Shown then paint() end -- [Give] follows my distance / KO (MINOR ①)
	end
	townStep(now)
end

---------------------------------------------------------------------------------------------------- lifecycle
function VillageFundUI.State()
	return S.State
end

VillageFundUI._T = { L = L, S = S, VIEW = VIEW, Build = build, Cleanup = cleanup, Give = give, Step = step,
	Consider = consider, ApplyPrompts = applyPrompts, Paint = paint, PaintBar = paintBar } -- tools/test_village_fund_ui.py

function VillageFundUI.Init(registry)
	C = registry
	local p = panels()
	if not p or type(p.Register) ~= "function" then
		Util.Warn(TAG, "Panels.Register is missing; the village fund card is off")
		return
	end
	S.Ready = p.Register(L.Window, {
		Title = function() return fmt(serverText().Title) end,
		Width = L.Width,
		Build = build,
		Cleanup = cleanup,
	}) == true
end

function VillageFundUI.Start()
	local ok, err = pcall(function()
		Net.Get("FundOpen").OnClientEvent:Connect(function(state)
			local fine, e = pcall(VillageFundUI.OnOpen, state)
			if not fine then Util.Warn(TAG, "FundOpen: " .. tostring(e)) end
		end)
	end)
	if not ok then Util.Warn(TAG, "FundOpen listen failed: " .. tostring(err)) end
	-- the fountain prompts: only my side's stays on
	for _, d in workspace:GetDescendants() do pcall(consider, d) end
	workspace.DescendantAdded:Connect(function(d) pcall(consider, d) end)
	if LocalPlayer then
		LocalPlayer:GetAttributeChangedSignal("Faction"):Connect(function()
			-- FIX 1: look at every FundPrompt again (one missing from the table is found and set too)
			pcall(function() for _, d in workspace:GetDescendants() do consider(d) end end)
			pcall(applyPrompts)
			if S.State and side(S.State.Faction) ~= mySide() then closeCard() end
		end)
	end
	-- the weekly totals / levels: the open card's bar and the town glow follow them
	for _, sd in L.Sides do
		for _, key in { "Fund" .. sd, "FundLevel" .. sd } do
			pcall(function()
				ReplicatedStorage:GetAttributeChangedSignal(key):Connect(function() pcall(paintBar) end)
			end)
			task.spawn(function()
				local gs = ReplicatedStorage:WaitForChild("GameState", 30)
				if gs then gs:GetAttributeChangedSignal(key):Connect(function() pcall(paintBar) end) end
			end)
		end
	end
	task.spawn(function()
		while true do
			task.wait(L.Poll)
			local fine, e = pcall(step, os.clock())
			if not fine then Util.Warn(TAG, "step: " .. tostring(e)) end
		end
	end)
end

return VillageFundUI
