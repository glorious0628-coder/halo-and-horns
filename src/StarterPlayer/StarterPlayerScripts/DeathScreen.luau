-- DeathScreen.luau (게임성 개발 1, BB14 + SPEC A23-110 "짧게: KO!·쓰러뜨린 것·3-2-1, 팁 없음", 검수 2026-10-10): the knock-out
-- screen on this client. The server sends my own Fx "KO" { By = "Player" | "Kaiju" | "Monster" | "Fall" | "Other", Name,
-- Lost, Sack, RespawnIn, Tip? } (CombatService); this shows, over a dim screen: "KO!", who knocked me out
-- (Config.Death.Text: "Knocked out by King Slime" / "You fell"), what I lost (pouch gold / the Grudge Sack; else
-- "Nothing lost" - 검수 10/10, the first KO costs nothing) and "Back in 3 s" counting down. No tip line, no fun tip (A23-99: the KO is
-- information, not advice; the next step comes as a quest row - A23-110 "Buy a potion"). Not modal: input goes through
-- (the game ignores a dead character anyway); it closes when my next character comes, or RespawnIn + Linger s after it
-- opened. Presentation only.
-- A23-167 ③ (10/14): under what I lost, 'This run' = what this run gave me since my character came, one line each, only
-- what grew (XP, gold, items, Honor / Mischief): attribute snapshots (DeathScreen.Tally, gains only) + my Fx "Loot".
-- Public API: DeathScreen.Init(C), DeathScreen.Start(), DeathScreen.Lines(data, left, got?, faction?) -> { Title,
-- Cause?, Lost?, GotTitle?, Got1..4?, Back? } (pure), DeathScreen.TotalXP / Tally / GotLines (pure), DeathScreen.Flush(),
-- DeathScreen.ResetRun(), DeathScreen.Show(data) -> bool, DeathScreen.Hide(), DeathScreen.IsOpen(),
-- DeathScreen.Look(touch) -> sizes / MaxGot / Y, DeathScreen.BoxHeight(lines, look) (pure).
-- 최종 검수 10/14 (API review): the lines (KO! + 4 'This run' lines ~350 du) spilled out of a fixed 220 box; the box
-- is now the sum of its shown lines, and a phone (TouchEnabled: UIScale 0.75 at 361 px high) gets smaller lines, at
-- most 2 'This run' lines (XP and gold come first) and sits lower, so KO! clears the Roblox top bar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local DeathScreen = {}
local C = nil

-- 최종 검수 10/14 (A23-179: Roblox's automatic translation matches whole drawn sentences, so a line with a number or a
-- name stayed English): a sentence with %-slots by its table key (UIKit.Tx -> UIKit.Tr: the localization table by key;
-- English exactly as before); without UIKit (offline tests) string.format; a failed format = the words as they are
local function trx(t, key, ...)
	local f = type(t) == "table" and (t[key .. "En"] or t[key]) or nil
	if type(f) ~= "string" then return nil end
	local kit = C and C.UIKit
	if type(kit) == "table" and type(kit.Tx) == "function" then
		local ok, out = pcall(kit.Tx, t, key, ...)
		if ok and type(out) == "string" then return out end
	end
	local ok, out = pcall(string.format, f, ...)
	return ok and out or f
end
local TAG = "DeathScreen"
local LocalPlayer = Players.LocalPlayer

local D = type(Config.Death) == "table" and Config.Death or {}
local TX = type(D.Text) == "table" and D.Text or {}
local T = {
	Title = Config.ClientText.DeathScreen.Title, -- the words: Config.ClientText.DeathScreen
	Linger = 2, -- s after RespawnIn: closes even if no character came
	Tick = 0.25,
	SkipW = 220, SkipH = 44, -- 99N G: the 'Get up in town' button (du; 44 = the phone touch size)
	Dim = 0.45, -- the screen's dim (BackgroundTransparency)
	ZIndex = 60, -- under the opening / the pickers, over the HUD
	TitleSize = 72, CauseSize = 24, LostSize = 20, BackSize = 22, GotTitleSize = 20, GotSize = 18,
	Bad = Color3.fromRGB(255, 120, 110),
	Good = Color3.fromRGB(255, 228, 100), -- the 'This run' title (UIKit gold text)
	Pad = 6, -- UIListLayout gap between lines
	Y = 0.42, -- box centre (screen height)
	-- phone: every size >= its UIKit style floor at UIScale 0.75 (Title 22, Body 19, Number 16 du), so the label height
	-- (size + 8) holds the drawn text
	Touch = { TitleSize = 56, CauseSize = 20, LostSize = 19, BackSize = 18, GotTitleSize = 22, GotSize = 19, MaxGot = 2, Y = 0.5 },
}
local S = { Gui = nil, Labels = nil, OpenedAt = 0, RespawnIn = 3, Data = nil, Token = 0, Box = nil, Look = nil,
	ReviveAt = 0, Skip = nil, Prompts = setmetatable({}, { __mode = "k" }) }
-- 99N G (dev2 ReviveService, 최종 검수 10/15): the friend-help words (Config.Revive.Text) and the prompt's name
local RV = type(Config.Revive) == "table" and Config.Revive or {}
local RX = type(RV.Text) == "table" and RV.Text or {}
-- A23-167 ③: what this run (since my character came) gave me - XP / gold / items / Honor or Mischief; Base = the last
-- attribute snapshot, Pending = a snapshot is waiting (Level + XP, Carried + Bank change one by one: read them together)
local G = { XP = 0, Gold = 0, Items = 0, Fame = 0, Base = nil, Pending = false, Wait = 0.3, MaxGot = 4 }

local function txt(key)
	local v = TX[key .. "En"] or TX[key]
	return type(v) == "string" and v or nil
end

-- A23-167 ③ (pure): all the XP from Lv1 to (level, xp)
function DeathScreen.TotalXP(level, xp)
	local t = 0
	for l = 1, math.clamp(math.floor(level) - 1, 0, 1000) do t += Config.XPToNext(l) end
	return t + math.max(0, xp)
end

-- A23-167 ③ (pure): adds what grew from snapshot `old` to `new` to `got` (only gains: spending, a deposit or the pouch
-- gold a KO costs never count; a side switch or a rebirth only starts a new base)
function DeathScreen.Tally(got, old, new)
	if type(old) ~= "table" or type(new) ~= "table" then return end
	if old.Faction ~= new.Faction or old.Rebirths ~= new.Rebirths then return end
	for _, k in { "XP", "Gold", "Fame" } do
		if type(old[k]) == "number" and type(new[k]) == "number" and new[k] > old[k] then got[k] += new[k] - old[k] end
	end
end

-- A23-167 ③ (pure): the 'This run' lines of `got` { XP, Gold, Items, Fame } for my side, only what grew
function DeathScreen.GotLines(got, faction)
	local out = {}
	if type(got) ~= "table" then return out end
	local function add(key, n, f)
		local w = txt(key)
		if w and n >= 1 then table.insert(out, Config.Plural(trx(TX, key, f and f(n) or n))) end
	end
	local fmt = function(n) return Util.FormatNumber(math.floor(n)) end
	add("GotXP", tonumber(got.XP) or 0, fmt)
	add("GotGold", tonumber(got.Gold) or 0, fmt)
	add("GotItems", math.floor(tonumber(got.Items) or 0), nil)
	local fameKey = faction == "Halo" and "GotHonor" or faction == "Horns" and "GotMischief" or nil
	if fameKey then add(fameKey, tonumber(got.Fame) or 0, fmt) end
	return out
end

-- what the screen says (pure): left = seconds until I am back (nil = no countdown line); got / faction = the 'This run'
-- lines (A23-167 ③: GotTitle + Got1..GotN, none when nothing grew); revive = seconds a friend may still help me up
-- (99N G: the 'A friend can help you up (N s)' line instead of the countdown)
function DeathScreen.Lines(data, left, got, faction, revive)
	data = type(data) == "table" and data or {}
	local out = { Title = T.Title }
	local by = data.By
	local name = type(data.Name) == "string" and data.Name ~= "" and data.Name or nil
	if (by == "Player" or by == "Kaiju" or by == "Monster") and name then
		local f = txt(by)
		out.Cause = f and trx(TX, by, name) or nil
	elseif by == "Fall" then
		out.Cause = txt("Fall")
	else
		out.Cause = txt("Other")
	end
	local lost = tonumber(data.Lost) or 0
	if data.Sack == true then
		out.Lost = txt("Sack")
	elseif lost >= 1 then
		local f = txt("Lost")
		out.Lost = f and trx(TX, "Lost", Util.FormatNumber(math.floor(lost))) or nil
	else
		out.Lost = txt("LostNone") -- 검수 10/10: the first KO (A23-110) says it cost nothing
	end
	local gotLines = DeathScreen.GotLines(got, faction)
	if #gotLines > 0 then
		out.GotTitle = txt("GotTitle")
		local maxGot = (S.Look and S.Look.MaxGot) or G.MaxGot
		for i = 1, math.min(#gotLines, maxGot) do out["Got" .. i] = gotLines[i] end
	end
	if type(revive) == "number" and revive > 0 and type(RX.Wait) == "string" then
		out.Revive = trx(RX, "Wait", math.max(1, math.ceil(revive)))
	elseif type(left) == "number" and left > 0 then
		local f = txt("Respawn")
		out.Back = f and trx(TX, "Respawn", math.max(1, math.ceil(left))) or nil
	end
	return out
end

-- 99N G: seconds a friend may still help me up (the server's ReviveUntil, else the Fx ReviveWait's own clock); 0 = none
function DeathScreen.ReviveLeft()
	local untilT = tonumber(LocalPlayer and LocalPlayer:GetAttribute("ReviveUntil")) or 0
	local left = 0
	if untilT > 0 then left = untilT - Util.Now() end
	return math.max(0, left, S.ReviveAt - os.clock())
end

-- 99N G: a friend's help prompt on a KO'd body shows only to my own side, never on my own body (the server refuses
-- the rest anyway: ReviveService)
function DeathScreen.PromptOn(side, ownerId, mySide, myId)
	return type(side) == "string" and side == mySide and ownerId ~= myId
end

function DeathScreen.FitPrompt(prompt)
	if not (typeof(prompt) == "Instance" and prompt:IsA("ProximityPrompt") and prompt.Name == RV.PromptName) then return end
	S.Prompts[prompt] = true
	local on = DeathScreen.PromptOn(prompt:GetAttribute("Side"), prompt:GetAttribute("ReviveUserId"),
		LocalPlayer and LocalPlayer:GetAttribute("Faction"), LocalPlayer and LocalPlayer.UserId)
	if prompt.Enabled ~= on then prompt.Enabled = on end
end

-- (pure) the sizes for a phone (touch == true) or a PC: TitleSize..GotSize, MaxGot, Y
function DeathScreen.Look(touch)
	local src = touch == true and T.Touch or T
	return { TitleSize = src.TitleSize, CauseSize = src.CauseSize, LostSize = src.LostSize, BackSize = src.BackSize,
		GotTitleSize = src.GotTitleSize, GotSize = src.GotSize, MaxGot = src.MaxGot or G.MaxGot, Y = src.Y or T.Y }
end

-- (pure) the box height for `lines` (DeathScreen.Lines): each shown line is its size + 8, with T.Pad between lines
function DeathScreen.BoxHeight(lines, look)
	if type(lines) ~= "table" or type(look) ~= "table" then return 0 end
	local h, n = 0, 0
	local function add(key, size)
		if type(lines[key]) == "string" then h += size + 8 n += 1 end
	end
	add("Title", look.TitleSize)
	add("Cause", look.CauseSize)
	add("Lost", look.LostSize)
	add("GotTitle", look.GotTitleSize)
	for i = 1, look.MaxGot do add("Got" .. i, look.GotSize) end
	add("Back", look.BackSize)
	add("Revive", look.BackSize)
	if type(lines.Revive) == "string" then h += T.SkipH + T.Pad end -- the 'Get up in town' button under it
	return h + math.max(0, n - 1) * T.Pad
end

function DeathScreen.IsOpen()
	return S.Gui ~= nil and S.Gui.Parent ~= nil
end

function DeathScreen.Hide()
	S.Token += 1
	if S.Gui then
		pcall(function() S.Gui:Destroy() end)
	end
	S.Gui, S.Labels, S.Data, S.Box, S.Look = nil, nil, nil, nil, nil
end

local function kit()
	local ui = C and C.UIKit
	return type(ui) == "table" and ui or nil
end

local function label(ui, parent, name, size, style, order, color)
	local l
	if ui and type(ui.StyledLabel) == "function" then
		local ok, made = pcall(ui.StyledLabel, { Name = name, Text = "", TextSize = size, Size = UDim2.new(1, 0, 0, size + 8),
			ZIndex = T.ZIndex + 1, LayoutOrder = order, TextWrapped = true }, style)
		if ok then l = made end
	end
	if not l then
		l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBlack
		l.TextSize = size
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextStrokeTransparency = 0.3
		l.Size = UDim2.new(1, 0, 0, size + 8)
		l.ZIndex = T.ZIndex + 1
		l.LayoutOrder = order
	end
	if color then l.TextColor3 = color end
	l.AutomaticSize = Enum.AutomaticSize.Y -- A23-179: a longer translation wraps to a second line inside the box
	l.Parent = parent
	return l
end

local function paint()
	if not (S.Labels and S.Data) then return end
	local left = S.RespawnIn - (os.clock() - S.OpenedAt)
	local lines = DeathScreen.Lines(S.Data, left, G, S.Faction, DeathScreen.ReviveLeft())
	if S.Skip then S.Skip.Visible = lines.Revive ~= nil end
	for key, l in S.Labels do
		local text = lines[key]
		l.Text = text or ""
		l.Visible = text ~= nil
	end
	if S.Box and S.Look then S.Box.Size = UDim2.new(0.8, 0, 0, DeathScreen.BoxHeight(lines, S.Look)) end
end

-- shows the KO screen for one Fx "KO" packet; false without a place to draw
function DeathScreen.Show(data)
	local ui = kit()
	local root = ui and ui.Gui
	if typeof(root) ~= "Instance" then return false end
	DeathScreen.Hide()
	local look = DeathScreen.Look(UserInputService.TouchEnabled == true)
	local frame = Instance.new("Frame")
	frame.Name = "DeathScreen"
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = T.Dim
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Active = false
	frame.ZIndex = T.ZIndex
	local box = Instance.new("Frame")
	box.Name = "Lines"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, look.Y)
	box.Size = UDim2.new(0.8, 0, 0, 0) -- paint() sets it to the shown lines
	box.AutomaticSize = Enum.AutomaticSize.Y -- A23-179: a translated line that wraps grows the box (never spills)
	box.ZIndex = T.ZIndex
	box.Parent = frame
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, T.Pad)
	list.Parent = box
	S.Labels = {
		Title = label(ui, box, "Title", look.TitleSize, "Title", 1),
		Cause = label(ui, box, "Cause", look.CauseSize, "Body", 2),
		Lost = label(ui, box, "Lost", look.LostSize, "Body", 3, T.Bad),
		GotTitle = label(ui, box, "GotTitle", look.GotTitleSize, "Title", 4, T.Good),
		Back = label(ui, box, "Back", look.BackSize, "Number", 10),
		Revive = label(ui, box, "Revive", look.BackSize, "Body", 11, T.Good),
	}
	-- 99N G: 'Get up in town' while a friend may help (c->s ReviveSkip); the only press on this screen
	S.Skip = nil
	if type(RX.Skip) == "string" and type(ui.ArtButton) == "function" then
		local okB, btn = pcall(ui.ArtButton, "BtnSecondary", { Name = "ReviveSkip", Text = RX.Skip, LayoutOrder = 12,
			Size = UDim2.fromOffset(T.SkipW, T.SkipH), ZIndex = T.ZIndex + 1, Visible = false, Parent = box }, function()
			local remote = Net.Get("ReviveSkip")
			if remote then remote:FireServer() end
		end)
		if okB and btn then S.Skip = btn end
	end
	for i = 1, look.MaxGot do S.Labels["Got" .. i] = label(ui, box, "Got" .. i, look.GotSize, "Body", 4 + i) end
	S.Box, S.Look = box, look
	DeathScreen.Flush() -- A23-167 ③: the last change before the KO counts
	S.Faction = G.Base and G.Base.Faction or nil
	S.Data = data
	S.RespawnIn = math.max(0, tonumber(type(data) == "table" and data.RespawnIn) or tonumber(Config.Player and Config.Player.RespawnTime) or 3)
	S.OpenedAt = os.clock()
	frame.Parent = root
	S.Gui = frame
	paint()
	-- a small pop of "KO!" (none with reduced motion)
	local reduced = ui and type(ui.ReducedMotion) == "function" and ui.ReducedMotion() == true
	if not reduced then
		local sc = Instance.new("UIScale")
		sc.Scale = 0.6
		sc.Parent = S.Labels.Title
		pcall(function()
			TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end)
	end
	S.Token += 1
	local token = S.Token
	task.spawn(function()
		while S.Token == token and DeathScreen.IsOpen() do
			paint()
			if os.clock() - S.OpenedAt >= S.RespawnIn + T.Linger and DeathScreen.ReviveLeft() <= 0 then
				DeathScreen.Hide()
				break
			end
			task.wait(T.Tick)
		end
	end)
	return true
end

-- A23-167 ③: my attributes as one snapshot (XP = all of it from Lv1, Gold = pouch + vault, Fame = my side's score)
local function snapshot()
	local p = LocalPlayer
	if not (p and type(p.GetAttribute) == "function") then return nil end
	local function n(k)
		local v = tonumber(p:GetAttribute(k))
		return (v ~= nil and v == v and v ~= math.huge and v ~= -math.huge) and v or nil
	end
	local level, xp = n("Level"), n("XP")
	local f = p:GetAttribute("Faction")
	local fameKey = f == "Halo" and "Honor" or f == "Horns" and "Infamy" or nil
	local carried, bank = n("CarriedGold"), n("BankGold")
	return {
		XP = (level and xp) and DeathScreen.TotalXP(level, xp) or nil,
		Gold = (carried or bank) and (carried or 0) + (bank or 0) or nil,
		Fame = fameKey and n(fameKey) or nil,
		Faction = f, Rebirths = n("Rebirths"),
	}
end

-- reads the snapshot now and adds what grew since the last one
function DeathScreen.Flush()
	G.Pending = false
	local new = snapshot()
	if not new then return end
	DeathScreen.Tally(G, G.Base, new)
	G.Base = new
end

-- a new run (my character came): the tallies start again from now
function DeathScreen.ResetRun()
	G.XP, G.Gold, G.Items, G.Fame, G.Pending = 0, 0, 0, 0, false
	G.Base = snapshot()
end

-- one attribute changed: read them all a moment later (the server sets Level then XP, the pouch then the vault)
local function onAttr()
	if G.Pending then return end
	G.Pending = true
	task.delay(G.Wait, function()
		if G.Pending then DeathScreen.Flush() end
	end)
end

function DeathScreen.OnFx(kind, data)
	if kind == "Loot" then -- my drops (LootService sends them to me only): items / potions / weapons, N each
		for _, g in (type(data) == "table" and type(data.Items) == "table") and data.Items or {} do
			if type(g) == "table" then G.Items += math.max(1, math.floor(tonumber(g.N) or 1)) end
		end
		return false
	end
	if kind == "ReviveWait" then -- 99N G: a friend is near - the screen waits Sec more (ReviveUntil follows)
		S.ReviveAt = os.clock() + math.max(0, tonumber(type(data) == "table" and data.Sec) or 0)
		pcall(paint)
		return true
	end
	if kind == "Revived" then -- 99N G: one line who helped me up (the screen goes with my new character)
		S.ReviveAt = 0
		local by = type(data) == "table" and Players:GetPlayerByUserId(tonumber(data.By) or 0) or nil
		local ui = kit()
		if by and type(RX.HelpedBy) == "string" and ui and type(ui.Toast) == "function" then
			pcall(ui.Toast, trx(RX, "HelpedBy", by.DisplayName), "info", 3)
		end
		return true
	end
	if kind ~= "KO" then return false end
	if type(data) == "table" and data.UserId ~= nil and LocalPlayer and data.UserId ~= LocalPlayer.UserId then return false end
	local ok, shown = pcall(DeathScreen.Show, data)
	if not ok then Util.Warn(TAG, "show failed: " .. tostring(shown)) end
	return ok and shown == true
end

function DeathScreen.Init(registry)
	C = registry
end

function DeathScreen.Start()
	if LocalPlayer then
		LocalPlayer.CharacterAdded:Connect(function() DeathScreen.Hide() end) -- back on my feet
		LocalPlayer.CharacterAdded:Connect(function() DeathScreen.ResetRun() end) -- A23-167 ③: a new run
		if type(LocalPlayer.GetAttributeChangedSignal) == "function" then
			for _, k in { "Level", "XP", "CarriedGold", "BankGold", "Honor", "Infamy", "Faction", "Rebirths" } do
				LocalPlayer:GetAttributeChangedSignal(k):Connect(onAttr)
			end
		end
		DeathScreen.ResetRun()
	end
	task.spawn(function()
		local fx = Net.Get("Fx")
		if not fx then return end
		fx.OnClientEvent:Connect(function(kind, data) DeathScreen.OnFx(kind, data) end)
	end)
	-- 99N G: the friend-help prompts (on KO'd bodies) only for my side
	if type(RV.PromptName) == "string" and typeof(workspace) == "Instance" then
		workspace.DescendantAdded:Connect(function(d) pcall(DeathScreen.FitPrompt, d) end)
		for _, d in workspace:GetDescendants() do pcall(DeathScreen.FitPrompt, d) end
		if LocalPlayer and type(LocalPlayer.GetAttributeChangedSignal) == "function" then
			LocalPlayer:GetAttributeChangedSignal("Faction"):Connect(function()
				for prompt in S.Prompts do pcall(DeathScreen.FitPrompt, prompt) end
			end)
			LocalPlayer:GetAttributeChangedSignal("ReviveUntil"):Connect(function() pcall(paint) end)
		end
	end
end

return DeathScreen
