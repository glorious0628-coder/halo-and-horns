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
-- DeathScreen.ResetRun(), DeathScreen.Show(data) -> bool, DeathScreen.Hide(), DeathScreen.IsOpen().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local DeathScreen = {}
local C = nil
local TAG = "DeathScreen"
local LocalPlayer = Players.LocalPlayer

local D = type(Config.Death) == "table" and Config.Death or {}
local TX = type(D.Text) == "table" and D.Text or {}
local T = {
	Title = "KO!",
	Linger = 2, -- s after RespawnIn: closes even if no character came
	Tick = 0.25,
	Dim = 0.45, -- the screen's dim (BackgroundTransparency)
	ZIndex = 60, -- under the opening / the pickers, over the HUD
	TitleSize = 72, CauseSize = 24, LostSize = 20, BackSize = 22, GotTitleSize = 20, GotSize = 18,
	Bad = Color3.fromRGB(255, 120, 110),
	Good = Color3.fromRGB(255, 228, 100), -- the 'This run' title (UIKit gold text)
}
local S = { Gui = nil, Labels = nil, OpenedAt = 0, RespawnIn = 3, Data = nil, Token = 0 }
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
		if w and n >= 1 then table.insert(out, Config.Plural(string.format(w, f and f(n) or n))) end
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
-- lines (A23-167 ③: GotTitle + Got1..GotN, none when nothing grew)
function DeathScreen.Lines(data, left, got, faction)
	data = type(data) == "table" and data or {}
	local out = { Title = T.Title }
	local by = data.By
	local name = type(data.Name) == "string" and data.Name ~= "" and data.Name or nil
	if (by == "Player" or by == "Kaiju" or by == "Monster") and name then
		local f = txt(by)
		out.Cause = f and string.format(f, name) or nil
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
		out.Lost = f and string.format(f, Util.FormatNumber(math.floor(lost))) or nil
	else
		out.Lost = txt("LostNone") -- 검수 10/10: the first KO (A23-110) says it cost nothing
	end
	local gotLines = DeathScreen.GotLines(got, faction)
	if #gotLines > 0 then
		out.GotTitle = txt("GotTitle")
		for i = 1, math.min(#gotLines, G.MaxGot) do out["Got" .. i] = gotLines[i] end
	end
	if type(left) == "number" and left > 0 then
		local f = txt("Respawn")
		out.Back = f and string.format(f, math.max(1, math.ceil(left))) or nil
	end
	return out
end

function DeathScreen.IsOpen()
	return S.Gui ~= nil and S.Gui.Parent ~= nil
end

function DeathScreen.Hide()
	S.Token += 1
	if S.Gui then
		pcall(function() S.Gui:Destroy() end)
	end
	S.Gui, S.Labels, S.Data = nil, nil, nil
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
	l.Parent = parent
	return l
end

local function paint()
	if not (S.Labels and S.Data) then return end
	local left = S.RespawnIn - (os.clock() - S.OpenedAt)
	local lines = DeathScreen.Lines(S.Data, left, G, S.Faction)
	for key, l in S.Labels do
		local text = lines[key]
		l.Text = text or ""
		l.Visible = text ~= nil
	end
end

-- shows the KO screen for one Fx "KO" packet; false without a place to draw
function DeathScreen.Show(data)
	local ui = kit()
	local root = ui and ui.Gui
	if typeof(root) ~= "Instance" then return false end
	DeathScreen.Hide()
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
	box.Position = UDim2.fromScale(0.5, 0.42)
	box.Size = UDim2.new(0.8, 0, 0, 220)
	box.ZIndex = T.ZIndex
	box.Parent = frame
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.Parent = box
	S.Labels = {
		Title = label(ui, box, "Title", T.TitleSize, "Title", 1),
		Cause = label(ui, box, "Cause", T.CauseSize, "Body", 2),
		Lost = label(ui, box, "Lost", T.LostSize, "Body", 3, T.Bad),
		GotTitle = label(ui, box, "GotTitle", T.GotTitleSize, "Title", 4, T.Good),
		Back = label(ui, box, "Back", T.BackSize, "Number", 10),
	}
	for i = 1, G.MaxGot do S.Labels["Got" .. i] = label(ui, box, "Got" .. i, T.GotSize, "Body", 4 + i) end
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
			if os.clock() - S.OpenedAt >= S.RespawnIn + T.Linger then
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
end

return DeathScreen
