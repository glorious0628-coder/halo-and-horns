-- ChoiceCardUI.luau (게임성 개발 1, 2026-10-13; docs/design/gameplay_plan_2026-10-13.md 2-A #3, GDD §0 "every action tilts
-- toward angel or devil"): the ONE choice card window for both server cards, and the choice afterglow.
--   * ChoiceCard (contract docs/design/choice_card_server_2026-10-09.md): s->c Fx "Card" { Id, Kind, Title, Seconds?, Stat,
--     Good / Evil = { Label, Item?, Potion?, N?, Gold?, XP?, Score, Hint? } }, Fx "CardEnd" { Id, Side, ... };
--     c->s "CardAction" (id, "Good" | "Evil").
--   * The field boss finisher (FinisherService, docs/design/king_finisher_2026-10-08.md): s->c Fx "FinisherCard" { Id,
--     Kind, Seconds, Stat, Help = { Item, N, Score, Hint? }, Tickle = { Gold, Score, Hint? } }, Fx "FinisherEnd" { Id, Pick };
--     c->s "FinisherPick" (id, "Help" | "Tickle"). Its words: Config.Finisher.Cards[kind].Text (Title, Help, Tickle).
--   Both become one card model (ChoiceCardUI.FromCard / FromFinisher, pure) shown in the Panels window "ChoiceCard": the
--   card's title on the window ribbon, two option columns side by side (the story pick's approved kind / sneaky art button
--   with the wing / horns glyph, kit.ChoiceButton; under it what it gives and what it does to my score), a countdown for
--   a timed card. A pick fires the card's remote once and locks both buttons until the End (or Wait s, then unlocks);
--   the End closes the window (the server's own Notify line says what happened). A timed card opens at once (it is the
--   moment after a boss kill) and closes when its time is up; a saved card (no Seconds) opens on a calm screen (no
--   fight, not dead, no other window, PauseCard.Busy false) and a card closed by hand opens again after Screen.Later s.
--   No purchase prompt near the card (A23-79): this window has no shop link.
--   * Afterglow (A23-64 ②, Config.Afterglow): s->c Fx "Afterglow" { UserId, Side, Seconds, Private } -> round gold
--     sparkles (Good) or soft purple smoke puffs (Evil) at that player's feet for Seconds (no rays: user 10/07). A new
--     glow on the same player replaces the old one; the character's death / respawn ends it.
-- Game text: English only (A23-48): Config.ChoiceCard.Screen + the cards' own words. New look: none - the approved
-- Panels window, BtnKind / BtnSneaky + glyphs and UIKit.ArtBar only.
-- API: ChoiceCardUI.Init(C), ChoiceCardUI.Start(), ChoiceCardUI.Current() (the open card model or nil); pure:
-- ChoiceCardUI.FromCard(p, now), ChoiceCardUI.FromFinisher(p, now), ChoiceCardUI.RewardLine(r),
-- ChoiceCardUI.ScoreLine(stat, score, hint), ChoiceCardUI.CanShow(card, ctx).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer

local ChoiceCardUI = {}
local C = nil
local TAG = "ChoiceCardUI"

-- layout (du) and timing
local L = {
	Window = "ChoiceCard", Width = 640,
	ButtonH = 64, ColGap = 16, BarH = 12, BarW = 420,
	Wait = 3, -- s both buttons stay locked after a pick without an answer (then they unlock again)
	Poll = 1, -- s between the calm-screen checks of a waiting saved card
	FightCalm = 4, -- s after my last attack / hurt that still count as a fight (Panels B15)
	-- the afterglow (A23-64 ②): round gold sparkles / soft purple smoke at the feet, built-in particle textures only
	Glow = {
		Good = { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = Color3.fromRGB(255, 214, 90),
			Light = 1, Rate = 7, Life = { 0.9, 1.5 }, Speed = { 0.6, 1.4 }, Size = { 0.32, 0 }, Alpha = { 0.1, 1 },
			Rise = 1.2, Spread = 180 },
		Evil = { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = Color3.fromRGB(150, 92, 205),
			Light = 0.15, Rate = 3, Life = { 1.6, 2.4 }, Speed = { 0.3, 0.8 }, Size = { 0.9, 1.7 }, Alpha = { 0.55, 1 },
			Rise = 0.6, Spread = 180 },
		Fade = 2.5, -- s the last particles live after the glow stops
	},
}
-- S.Card = the card model waiting or open; S.SentAt = when its pick went out (-inf = none); S.LaterUntil = a card closed by
-- hand waits until then; S.Glows[userId] = { Emitter, Attachment, Ends }
local S = { Ready = false, Card = nil, Held = nil, SentAt = -math.huge, LaterUntil = 0, Opening = false, Glows = {} }
local VIEW = { Kit = nil, Buttons = nil, Bar = nil, SetBar = nil, Count = nil, Shown = false, Id = nil }

---------------------------------------------------------------------------------------------------- text (pure)
local function screen() return type(Config.ChoiceCard) == "table" and type(Config.ChoiceCard.Screen) == "table"
	and Config.ChoiceCard.Screen or {} end
local function fin() return type(Config.Finisher) == "table" and Config.Finisher or {} end

local function fmt(s, ...)
	if type(s) ~= "string" then return "" end
	local ok, out = pcall(string.format, s, ...)
	return ok and out or s
end

local function int(v, default)
	v = tonumber(v)
	if not v or v ~= v or v == math.huge or v == -math.huge then return default or 0 end
	return math.floor(v)
end

local function itemName(id)
	local loot = type(Config.Loot) == "table" and Config.Loot or {}
	local def = type(loot.Items) == "table" and loot.Items[id] or nil
	if type(def) == "table" and type(def.Name) == "string" then return def.Name end
	local pot = type(loot.Text) == "table" and type(loot.Text.Potion) == "table" and loot.Text.Potion[id] or nil
	return type(pot) == "string" and pot or tostring(id)
end

local function bigNum(n)
	return (type(Util.FormatInt) == "function" and Util.FormatInt(n)) or tostring(n)
end

-- what an option gives: "+2 Jelly · +6 XP · +4 gold" (a part only when it is there)
function ChoiceCardUI.RewardLine(r)
	if type(r) ~= "table" then return "" end
	local sc, parts = screen(), {}
	local item = r.Item or r.Potion
	if type(item) == "string" and item ~= "" then
		table.insert(parts, fmt(sc.Item, math.max(1, int(r.N, 1)), itemName(item)))
	end
	if int(r.XP) > 0 then
		local cc = type(Config.ChoiceCard) == "table" and type(Config.ChoiceCard.Text) == "table" and Config.ChoiceCard.Text or {}
		table.insert(parts, fmt(cc.XP, bigNum(int(r.XP))))
	end
	if int(r.Gold) > 0 then table.insert(parts, fmt(sc.Gold, bigNum(int(r.Gold)))) end
	return table.concat(parts, " · ")
end

-- what an option does to my score: "Honor +1" / "Honor -1", else its hint line (Neutral / Full / Zero), else ""
function ChoiceCardUI.ScoreLine(stat, score, hint)
	local t = type(fin().Text) == "table" and fin().Text or {}
	score = int(score)
	if (stat == "Honor" or stat == "Infamy") and score ~= 0 then
		local names = type(screen().Stat) == "table" and screen().Stat or {}
		local name = type(names[stat]) == "string" and names[stat] or stat -- A23-166: the shown name, not the key
		return score > 0 and fmt(t.Score, name, score) or fmt(t.ScoreDown, name, -score)
	end
	if hint == "Neutral" then return t.HintNeutral or "" end
	if hint == "Full" then return t.HintFull or "" end
	if hint == "Zero" then return t.HintZero or "" end
	return ""
end

local function option(o, label, side, key)
	o = type(o) == "table" and o or {}
	return { Side = side, Key = key, Label = type(label) == "string" and label or "",
		Reward = { Item = o.Item, Potion = o.Potion, N = o.N, Gold = o.Gold, XP = o.XP },
		Score = int(o.Score), Hint = o.Hint }
end

-- now = os.clock() (timed cards end at now + Seconds); nil = not a card
function ChoiceCardUI.FromCard(p, now)
	if type(p) ~= "table" or type(p.Id) ~= "number" or type(p.Good) ~= "table" or type(p.Evil) ~= "table" then return nil end
	local secs = tonumber(p.Seconds)
	return { Src = "Card", Remote = "CardAction", Id = p.Id, Kind = p.Kind,
		Title = (type(p.Title) == "string" and p.Title ~= "") and p.Title or screen().Title or "",
		Stat = p.Stat, Ends = (secs and secs > 0) and (now or 0) + secs or nil, Seconds = secs,
		Good = option(p.Good, p.Good.Label, "Good", "Good"), Evil = option(p.Evil, p.Evil.Label, "Evil", "Evil") }
end

function ChoiceCardUI.FromFinisher(p, now)
	if type(p) ~= "table" or type(p.Id) ~= "number" or type(p.Help) ~= "table" or type(p.Tickle) ~= "table" then return nil end
	local cards = type(fin().Cards) == "table" and fin().Cards or {}
	local def = type(cards[p.Kind]) == "table" and cards[p.Kind] or {}
	local words = type(def.Text) == "table" and def.Text or {}
	local secs = tonumber(p.Seconds) or tonumber(fin().Seconds) or 10
	return { Src = "Finisher", Remote = "FinisherPick", Id = p.Id, Kind = p.Kind,
		Title = (type(words.Title) == "string" and words.Title) or screen().Title or "",
		Stat = p.Stat, Ends = (now or 0) + math.max(1, secs), Seconds = secs,
		Good = option(p.Help, words.Help, "Good", "Help"), Evil = option(p.Tickle, words.Tickle, "Evil", "Tickle") }
end

-- may the card's window open now? ctx = { Now, Dead, Fight, Busy, Window (the open Panels window id or nil), LaterUntil }
-- A timed card opens at once (only not while dead); a saved card waits for a calm screen and its Later time
function ChoiceCardUI.CanShow(card, ctx)
	if type(card) ~= "table" or type(ctx) ~= "table" then return false end
	if ctx.Window == L.Window then return false end -- already open
	if ctx.Dead then return false end
	if card.Ends then return (ctx.Now or 0) < card.Ends end
	if ctx.Fight or ctx.Busy or ctx.Window ~= nil then return false end
	return (ctx.Now or 0) >= (ctx.LaterUntil or 0)
end

---------------------------------------------------------------------------------------------------- the window
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

local function lock(on)
	local k = VIEW.Kit
	if not (k and VIEW.Buttons) then return end
	for _, b in VIEW.Buttons do pcall(k.SetEnabled, b, not on) end
end

local function pick(side)
	local card = S.Card
	if not card or VIEW.Id ~= card.Id then return end
	if os.clock() - S.SentAt < L.Wait then return end
	if card.Ends and os.clock() > card.Ends then return end
	local o = card[side]
	if type(o) ~= "table" then return end
	S.SentAt = os.clock()
	lock(true)
	local ok, err = pcall(function() Net.Get(card.Remote):FireServer(card.Id, o.Key) end)
	if not ok then Util.Warn(TAG, card.Remote .. ": " .. tostring(err)) end
end

local function column(k, row, card, side)
	local col = k.Column(row, 0.5, -L.ColGap / 2, 6)
	col.Name = side
	local o = card[side]
	local btn = k.ChoiceButton(col, side, o.Label, UDim2.new(1, 0, 0, L.ButtonH), function() pick(side) end)
	btn.Name = side .. "Button"
	local gives = ChoiceCardUI.RewardLine(o.Reward)
	if gives ~= "" then
		k.Text(col, gives, { Name = "Gives", Size = 18, Align = Enum.TextXAlignment.Center, Color = k.Theme.Gold })
	end
	local score = ChoiceCardUI.ScoreLine(card.Stat, o.Score, o.Hint)
	if score ~= "" then
		k.Text(col, score, { Name = "Score", Size = 16, Align = Enum.TextXAlignment.Center, Color = k.Theme.SubText })
	end
	return btn
end

-- the card in view is over (picked / time up): a held saved card comes back
local function resume()
	S.Card, S.Held = S.Held, nil
	S.SentAt = -math.huge
end

local function tick()
	local card = S.Card
	if not (VIEW.Shown and card and card.Ends) then return end
	local left = math.max(0, card.Ends - os.clock())
	if VIEW.SetBar then pcall(VIEW.SetBar, card.Seconds and card.Seconds > 0 and left / card.Seconds or 0) end
	if VIEW.Count then VIEW.Count.Text = fmt(screen().Seconds, math.ceil(left)) end
	if left <= 0 then
		resume()
		local p = panels()
		if p and windowOpen() == L.Window then pcall(p.Close) end
	end
end

local function build(parent, k)
	local card = S.Card
	VIEW.Kit, VIEW.Buttons, VIEW.Shown, VIEW.Id, VIEW.Bar, VIEW.SetBar, VIEW.Count = k, {}, true, card and card.Id,
		nil, nil, nil
	if not card then
		k.Text(parent, "", {})
		return nil
	end
	local row = k.Row(parent, 0, L.ColGap)
	row.Name = "Options"
	table.insert(VIEW.Buttons, column(k, row, card, "Good"))
	table.insert(VIEW.Buttons, column(k, row, card, "Evil"))
	if card.Ends then
		local bar = k.Row(parent, L.BarH + 26, 8)
		bar.Name = "Timer"
		local UIKit = C and C.UIKit
		if type(UIKit) == "table" and type(UIKit.ArtBar) == "function" then
			local ok, frame, set = pcall(UIKit.ArtBar, { Name = "TimeBar", Size = UDim2.fromOffset(L.BarW, L.BarH),
				Color = k.Theme.Gold, Parent = bar })
			if ok and frame then VIEW.Bar, VIEW.SetBar = frame, set end
		end
		VIEW.Count = k.Text(bar, "", { Name = "Seconds", Size = 18, Width = UDim2.fromOffset(60, 0),
			Align = Enum.TextXAlignment.Left, Color = k.Theme.Gold })
	end
	if os.clock() - S.SentAt < L.Wait then lock(true) end
	tick()
	return function() tick() end
end

local function cleanup()
	local card = S.Card
	-- closed by hand while a saved card still waits: it opens again later (a timed card just runs out)
	if card and not card.Ends and VIEW.Id == card.Id then
		S.LaterUntil = os.clock() + math.max(1, int(screen().Later, 30))
	end
	VIEW.Kit, VIEW.Buttons, VIEW.Bar, VIEW.SetBar, VIEW.Count, VIEW.Id = nil, nil, nil, nil, nil, nil
	VIEW.Shown = false
end

local function context()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local fx = C and C.Fx
	local last = type(fx) == "table" and fx.LastFightAt or nil
	local fight = (type(last) == "number" and os.clock() - last < L.FightCalm)
		or (tonumber(LocalPlayer:GetAttribute("InCombatUntil")) or 0) > Util.Now()
	local busy = false
	local pc = C and C.PauseCard
	if type(pc) == "table" and type(pc.Busy) == "function" then
		local ok, b = pcall(pc.Busy)
		busy = ok and b == true
	end
	return { Now = os.clock(), Dead = not hum or hum.Health <= 0, Fight = fight, Busy = busy, Window = windowOpen(),
		LaterUntil = S.LaterUntil }
end

local function tryShow()
	local card = S.Card
	if not S.Ready or not card or S.Opening then return end
	if card.Ends and os.clock() >= card.Ends then
		resume()
		card = S.Card
		if not card then return end
	end
	if not ChoiceCardUI.CanShow(card, context()) then return end
	local p = panels()
	if not p or type(p.Open) ~= "function" then return end
	S.Opening = true
	local ok, err = pcall(p.Open, L.Window)
	S.Opening = false
	if not ok then Util.Warn(TAG, "open failed: " .. tostring(err)) end
end

local function offer(card)
	if not card then return end
	-- the two servers are separate (a saved ChoiceCard card and a timed finisher card may both be open): a timed card
	-- over a waiting saved one holds that one back until the timed card is over
	local old = S.Card
	-- 최종 검수 10/14 (MINOR 1): a timed card still running (finisher 10 s, ShardBloom 120 s) stays on screen when the
	-- other server sends a card - drawing the new one closed the timed card and its server answered None (the gift was
	-- lost); the new card waits in S.Held (a newer card from the same server replaces a held one) until the timed card ends
	if old and old.Ends and os.clock() < old.Ends and old.Src ~= card.Src then
		S.Held = card
		return
	end
	if old and not old.Ends and card.Ends and old.Src ~= card.Src then
		S.Held = old
	elseif old and old.Src == card.Src then
		S.Held = (S.Held and S.Held.Src ~= card.Src) and S.Held or nil
	end
	S.Card, S.SentAt, S.LaterUntil = card, -math.huge, 0
	if VIEW.Shown then
		-- a new card while the window shows an old one: draw the new one
		local p = panels()
		if p then pcall(p.Close) end
	end
	tryShow()
end

local function ended(src, id)
	local held = S.Held
	if held and held.Src == src and held.Id == id then S.Held = nil return end
	local card = S.Card
	if not card or card.Src ~= src or card.Id ~= id then return end
	resume()
	if VIEW.Shown and VIEW.Id == id then
		local p = panels()
		if p then pcall(p.Close) end
	end
end

---------------------------------------------------------------------------------------------------- afterglow
local function stopGlow(userId)
	local g = S.Glows[userId]
	if not g then return end
	S.Glows[userId] = nil
	if g.Emitter and g.Emitter.Parent then g.Emitter.Enabled = false end
	local att = g.Attachment
	task.delay(L.Glow.Fade, function()
		if att and att.Parent then att:Destroy() end
	end)
end

local function glow(payload)
	local A = Config.Afterglow
	if type(A) ~= "table" or A.Enabled ~= true or type(payload) ~= "table" then return end
	local look = L.Glow[payload.Side]
	if type(look) ~= "table" then return end
	local who = type(payload.UserId) == "number" and Players:GetPlayerByUserId(payload.UserId) or nil
	local char = who and who.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and hum) then return end
	stopGlow(payload.UserId)
	local att = Instance.new("Attachment")
	att.Name = "AfterglowAt"
	-- at the feet: under the root by half its height and the hip height
	att.Position = Vector3.new(0, -(root.Size.Y / 2 + math.max(0, hum.HipHeight)) + 0.2, 0)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Afterglow"
	e.Texture = look.Texture
	e.Color = ColorSequence.new(look.Color)
	e.LightEmission = look.Light
	e.Rate = look.Rate
	e.Lifetime = NumberRange.new(look.Life[1], look.Life[2])
	e.Speed = NumberRange.new(look.Speed[1], look.Speed[2])
	e.SpreadAngle = Vector2.new(look.Spread, look.Spread)
	e.Acceleration = Vector3.new(0, look.Rise, 0)
	e.Size = NumberSequence.new(look.Size[1], look.Size[2])
	e.Transparency = NumberSequence.new(look.Alpha[1], look.Alpha[2])
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-30, 30)
	e.Shape = Enum.ParticleEmitterShape.Disc
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = att
	att.Parent = root
	local entry = { Emitter = e, Attachment = att }
	S.Glows[payload.UserId] = entry
	local seconds = math.max(1, tonumber(payload.Seconds) or tonumber(A.Seconds) or 60)
	task.delay(seconds, function()
		if S.Glows[payload.UserId] == entry then stopGlow(payload.UserId) end
	end)
	-- a death or a new character ends it (the attachment goes with the old body)
	att.AncestryChanged:Connect(function(_, parent)
		if parent == nil and S.Glows[payload.UserId] == entry then S.Glows[payload.UserId] = nil end
	end)
end

---------------------------------------------------------------------------------------------------- Fx
function ChoiceCardUI.OnFx(kind, data)
	if kind == "Card" then
		offer(ChoiceCardUI.FromCard(data, os.clock()))
	elseif kind == "FinisherCard" then
		offer(ChoiceCardUI.FromFinisher(data, os.clock()))
	elseif kind == "CardEnd" or kind == "FinisherEnd" then
		if type(data) == "table" and type(data.Id) == "number" then
			ended(kind == "CardEnd" and "Card" or "Finisher", data.Id)
		end
	elseif kind == "Afterglow" then
		glow(data)
	end
end

function ChoiceCardUI.Current()
	return S.Card
end

---------------------------------------------------------------------------------------------------- lifecycle
ChoiceCardUI._T = { L = L, S = S, VIEW = VIEW, Build = build, Cleanup = cleanup, Pick = pick, Offer = offer, Ended = ended,
	TryShow = tryShow, Glow = glow } -- tools/test_choice_card_ui.py

function ChoiceCardUI.Init(registry)
	C = registry
	local p = panels()
	if not p or type(p.Register) ~= "function" then
		Util.Warn(TAG, "Panels.Register is missing; the choice card window is off")
		return
	end
	S.Ready = p.Register(L.Window, {
		Title = function() return S.Card and S.Card.Title or screen().Title or "" end,
		Width = L.Width,
		Build = build,
		Cleanup = cleanup,
	}) == true
end

function ChoiceCardUI.Start()
	local ok, err = pcall(function()
		Net.Get("Fx").OnClientEvent:Connect(function(kind, data)
			local fine, e = pcall(ChoiceCardUI.OnFx, kind, data)
			if not fine then Util.Warn(TAG, "fx " .. tostring(kind) .. ": " .. tostring(e)) end
		end)
	end)
	if not ok then Util.Warn(TAG, "Fx listen failed: " .. tostring(err)) end
	if not S.Ready then return end
	-- the timed card's countdown while it shows
	RunService.Heartbeat:Connect(function()
		if VIEW.Shown and S.Card and S.Card.Ends then
			local fine, e = pcall(tick)
			if not fine then Util.Warn(TAG, "tick: " .. tostring(e)) end
		end
	end)
	-- a waiting saved card opens on a calm screen; a pick without an answer unlocks after L.Wait
	task.spawn(function()
		while true do
			task.wait(L.Poll)
			if S.Card and not VIEW.Shown then pcall(tryShow) end
			if VIEW.Shown and S.SentAt > -math.huge and os.clock() - S.SentAt >= L.Wait then
				S.SentAt = -math.huge
				lock(false)
			end
		end
	end)
end

return ChoiceCardUI
