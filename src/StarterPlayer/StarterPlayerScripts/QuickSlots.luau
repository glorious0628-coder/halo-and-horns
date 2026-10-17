-- QuickSlots.luau (게임성 개발 1, SPEC A23-109 "물약 원 2개 빼고 퀵슬롯 1·2·3 가로", user photo 2026-10-10): what the three
-- quick slots hold and do. The slots themselves (place, size, art, name tags) are 이미지 개발's HUD parts:
--   HUD.QuickSlots() -> { [i] = { Button, Icon, Count, Key, Cooldown, Status } }, HUD.OnQuickSlot(fn) -> fn(i) on a press.
-- Here: the contents (Config.QuickSlots: a new player's slots start empty - 검수 10/10 -; saved by the server -
-- 게임성 개발 2 - as the owner's attribute "QuickSlots" = "HP,MP," and changed with c->s SetQuickSlot(slot, item); until
-- that exists a change lasts this session only), using a slot (an item's Use: the potions go through VitalsUI's own
-- request = the existing UsePotion remote, so the server keeps every check), the keys (Keybinds PotionHP = 1, PotionMP =
-- 2, QuickSlot3 = 3 -> slot 1 / 2 / 3; VitalsUI leaves its potion keys to this module while it runs) and what each slot
-- shows every Poll s: the item's icon, its count, the cooldown filling up from the bottom, the key badge (Keybinds.Label),
-- an empty slot blank. The bag's quick items section (QuickSlots.BagRows) puts an item into slot 1 / 2 / 3.
-- Public API: QuickSlots.Init(C), QuickSlots.Start(), QuickSlots.Parse(attr) -> { item, item, item } (pure),
-- QuickSlots.Get() -> the three items, QuickSlots.Use(i) -> bool, QuickSlots.Set(i, item) -> bool, QuickSlots.Slot(i)
-- -> { Item, Def, Count, Left, Ready } (what slot i shows), QuickSlots.OwnsKeys() -> true, QuickSlots.Refresh(),
-- QuickSlots.BagRows(parent, kit) (the bag's quick items rows).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local QuickSlots = {}
local C = nil
local TAG = "QuickSlots"
local LocalPlayer = Players.LocalPlayer

local Q = type(Config.QuickSlots) == "table" and Config.QuickSlots or {}
local T = {
	Count = tonumber(Q.Count) or 3,
	Default = type(Q.Default) == "table" and Q.Default or { "", "", "" },
	Items = type(Q.Items) == "table" and Q.Items or {},
	Attr = type(Q.Attr) == "string" and Q.Attr or "QuickSlots",
	Remote = type(Q.Remote) == "string" and Q.Remote or "SetQuickSlot",
	Poll = 0.2,
	-- the key action of each slot (Config.Keybinds: the old potion keys 1 / 2 and the new 3)
	Actions = { "PotionHP", "PotionMP", "QuickSlot3" },
	Text = Config.ClientText.QuickSlots, -- the words: Config.ClientText.QuickSlots (moved 10/14)
}
-- Local = this session's own slots (no server yet, or a change the server has not answered within LocalWait s)
local S = { Local = nil, LocalAt = 0, LocalRemote = false, Started = false, Hooked = false }
T.LocalWait = 3
-- game play r8 (0 potions: the dimmed icon on the dark slot read as an empty slot): the icon stays clear, only the count
-- turns gray (ZeroCount); CountColor = each count label's own colour, given back when it has potions again
T.ZeroCount = Color3.fromRGB(150, 150, 160)
S.CountColor = setmetatable({}, { __mode = "k" })
T.KingWarn = { Share = 0.4, Stage = "Retry" } -- QuickSlots.KingWarnStep (the rematch King, 최종 검수 10/18)
T.Glow = { Color = Color3.fromRGB(255, 214, 72), Thick = 5, Time = 1.4, Pop = 1.15 } -- QuickSlots.Glow (after a KO)

local function num(v, d)
	v = tonumber(v)
	if v == nil or v ~= v or math.abs(v) == math.huge then return d end
	return v
end

-- the three items of a saved attribute "HP,MP," (pure): unknown or missing entries are empty, no attribute = Default
function QuickSlots.Parse(attr)
	local out = {}
	if type(attr) ~= "string" then
		for i = 1, T.Count do out[i] = type(T.Default[i]) == "string" and T.Default[i] or "" end
		return out
	end
	local parts = string.split(attr, ",")
	for i = 1, T.Count do
		local v = parts[i]
		out[i] = (type(v) == "string" and T.Items[v] ~= nil) and v or ""
	end
	return out
end

function QuickSlots.Get()
	if S.Local and (not S.LocalRemote or os.clock() - S.LocalAt < T.LocalWait) then return table.clone(S.Local) end
	return QuickSlots.Parse(LocalPlayer and LocalPlayer:GetAttribute(T.Attr))
end

-- what slot i shows now: its item, the item's def, its count, cooldown seconds left (and the full length), ready to use
function QuickSlots.Slot(i)
	local item = QuickSlots.Get()[i] or ""
	local def = T.Items[item]
	local out = { Item = item, Def = def, Count = 0, Left = 0, Length = 1, Ready = false }
	if type(def) ~= "table" or not LocalPlayer then return out end
	out.Count = math.max(0, math.floor(num(type(def.Stock) == "string" and LocalPlayer:GetAttribute(def.Stock), 0)))
	local readyAt = num(type(def.ReadyAt) == "string" and LocalPlayer:GetAttribute(def.ReadyAt), 0)
	out.Left = math.max(0, readyAt - Util.Now())
	out.Length = math.max(0.1, num(def.Cooldown, 10))
	out.Ready = out.Count > 0 and out.Left <= 0
	return out
end

-- use slot i (a press on it or its key): a potion goes through VitalsUI (the server checks); a PRESS (button = true) on
-- an empty slot opens the bag on its Use tab with the first potion picked - its [1] [2] [3] put it in a slot (game play
-- r6: nobody found how); its key does nothing
-- (pure) #9: an empty slot's key opens the bag like its button does when I hold a potion (else it does nothing)
function QuickSlots.EmptyOpens(button, potions)
	return button == true or (tonumber(potions) or 0) > 0
end

function QuickSlots.Use(i, button)
	local slot = QuickSlots.Slot(i)
	local def = slot.Def
	if type(def) ~= "table" then
		local potions = 0
		for _, item in T.Items do
			if type(item) == "table" and type(item.Stock) == "string" and LocalPlayer then
				potions += math.max(0, math.floor(num(LocalPlayer:GetAttribute(item.Stock), 0)))
			end
		end
		local panels = QuickSlots.EmptyOpens(button, potions) and C and C.Panels
		if type(panels) == "table" and type(panels.Open) == "function" then
			local order = type(Q.Order) == "table" and Q.Order or { "HP", "MP" }
			pcall(panels.Open, "Bag", { Tab = "Use", Select = "P:" .. tostring(order[1] or "HP") })
			return true
		end
		return false
	end
	if def.Use == "Potion" then
		local vitals = C and C.VitalsUI
		if type(vitals) == "table" and type(vitals.Request) == "function" then
			local ok, sent = pcall(vitals.Request, def.Kind)
			-- #8: a cooldown, a full bar, no potion ... = the slot shakes with the Deny sound (the key too)
			if ok and sent == false then QuickSlots.Refuse(i) end
			return ok and sent ~= false
		end
	end
	return false
end

-- put item ("" = empty) into slot i: the server saves it (SetQuickSlot) when that remote exists, else this session only;
-- the item already in another slot swaps with it (the server does the same)
function QuickSlots.Set(i, item)
	i = math.floor(num(i, 0))
	if i < 1 or i > T.Count or type(item) ~= "string" or (item ~= "" and T.Items[item] == nil) then return false end
	local cur = QuickSlots.Get()
	local from = item ~= "" and table.find(cur, item) or nil
	if from and from ~= i then cur[from] = cur[i] end
	cur[i] = item
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild(T.Remote)
	S.Local, S.LocalAt, S.LocalRemote = cur, os.clock(), false
	if remote and remote:IsA("RemoteEvent") then
		pcall(remote.FireServer, remote, i, item)
		S.LocalRemote = true -- shown at once; the server's attribute takes over when it answers (or after LocalWait s)
	end
	QuickSlots.Refresh()
	return true
end

function QuickSlots.OwnsKeys()
	return S.Started == true
end

local function hud(name, ...)
	local h = C and C.HUD
	if type(h) == "table" and type(h[name]) == "function" then
		local ok, res = pcall(h[name], ...)
		if ok then return res end
	end
	return nil
end

-- 세세한 게임성 #8 (detail_audit_2026-10-17, A23-196: a press that cannot work answers on the button): slot i shakes red
-- with the Deny sound (UIKit.Refuse)
function QuickSlots.Refuse(i)
	local slots = hud("QuickSlots")
	local w = type(slots) == "table" and slots[i] or nil
	local kit = C and C.UIKit
	if type(w) ~= "table" or not w.Button or type(kit) ~= "table" or type(kit.Refuse) ~= "function" then return false end
	return pcall(kit.Refuse, w.Button)
end


local function artId(key)
	local kit = C and C.UIKit
	if type(kit) ~= "table" or type(kit.ArtId) ~= "function" or type(key) ~= "string" then return "" end
	local ok, id = pcall(kit.ArtId, key)
	return (ok and type(id) == "string") and id or ""
end

-- fills the HUD's slot parts (icon, count, cooldown from the bottom, key badge; an empty slot blank)
function QuickSlots.Refresh()
	local slots = hud("QuickSlots")
	if type(slots) ~= "table" then return false end
	local keys = C and C.Keybinds
	for i = 1, T.Count do
		local w = slots[i]
		if type(w) == "table" then
			local s = QuickSlots.Slot(i)
			local def = s.Def
			pcall(function()
				-- game play r8 (slots 1 / 2 did nothing when empty): VitalsUI may have switched its potion squares off
				-- (Active / Disabled) before this module took them; every slot stays pressable (an empty one opens the bag)
				if w.Button then
					if w.Button.Active ~= true then w.Button.Active = true end
					if w.Button:GetAttribute("Disabled") == true then w.Button:SetAttribute("Disabled", false) end
				end
				if w.Icon then
					local id = def and artId(def.Icon) or ""
					if w.Icon.Image ~= id then w.Icon.Image = id end
					if w.Icon.ImageTransparency ~= 0 then w.Icon.ImageTransparency = 0 end
				end
				if w.Count then
					w.Count.Text = def and tostring(s.Count) or T.Text.Empty
					if S.CountColor[w.Count] == nil then S.CountColor[w.Count] = w.Count.TextColor3 or false end
					local own = S.CountColor[w.Count]
					local want = (def and s.Count <= 0) and T.ZeroCount or (own or nil)
					if want and w.Count.TextColor3 ~= want then w.Count.TextColor3 = want end
				end
				if w.Cooldown then
					local frac = (def and s.Left > 0) and math.clamp(s.Left / s.Length, 0, 1) or 0
					w.Cooldown.Visible = frac > 0
					w.Cooldown.Size = UDim2.new(1, 0, frac, 0)
				end
				if w.Status then w.Status.Visible = false end
				if w.Key and type(keys) == "table" and type(keys.Label) == "function" then
					local ok, label = pcall(keys.Label, T.Actions[i])
					if ok and type(label) == "string" then w.Key.Text = label end
				end
			end)
		end
	end
	return true
end

-- 최종 검수 10/18 (user: "물약 산 다음에 킹슬라임 잡을 때는 물약을 먹으면서 해야지"): in the rematch with MY King (the model
-- FirstKOService marks FirstKO = "Retry", OwnerUserId = me, alive) my HP going under KingWarn.Share of its max the first
-- time in that fight makes the HP potion slot shine once (QuickSlots.Glow: nothing without a potion; no text). Pure:
-- due when that King is out, not warned for it yet and hp < Share x max
function QuickSlots.KingWarnDue(king, warned, hp, maxHp)
	if king == nil or king == warned then return false end
	hp, maxHp = tonumber(hp), tonumber(maxHp)
	if not hp or not maxHp or maxHp <= 0 or hp <= 0 then return false end
	return hp < maxHp * T.KingWarn.Share
end

-- my living rematch King (workspace.Monsters), nil when none
function QuickSlots.MyRetryKing()
	local folder = workspace:FindFirstChild("Monsters")
	if not folder or not LocalPlayer then return nil end
	for _, m in folder:GetChildren() do
		if m:GetAttribute("FirstKO") == T.KingWarn.Stage and m:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
			local root = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
			if root and not root.Anchored then return m end -- an anchored root = it is dying (MonsterService)
		end
	end
	return nil
end

-- the poll's check: once per rematch King (S.KingWarned = that model)
function QuickSlots.KingWarnStep()
	local king = QuickSlots.MyRetryKing()
	local char = LocalPlayer and LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (king and hum) or not QuickSlots.KingWarnDue(king, S.KingWarned, hum.Health, hum.MaxHealth) then return false end
	S.KingWarned = king
	return QuickSlots.Glow()
end

-- 최종 검수 #1 (game play r5: KO'd, nothing said what helps): the first HP potion slot I hold a potion in shines once -
-- a gold rim that fades and a small pop (none with reduced motion); nothing without a potion. True when it shone
function QuickSlots.Glow()
	local slots = hud("QuickSlots")
	if type(slots) ~= "table" then return false end
	local pick = nil
	for i = 1, T.Count do
		local s = QuickSlots.Slot(i)
		if s.Def and s.Def.Kind == "HP" and s.Count > 0 then pick = i break end
	end
	local w = pick and slots[pick]
	local btn = type(w) == "table" and w.Button or nil
	if not (btn and btn:IsA("GuiObject")) then return false end
	local kit = C and C.UIKit
	if type(kit) == "table" and type(kit.ReducedMotion) == "function" and kit.ReducedMotion() then return true end
	local TweenService = game:GetService("TweenService")
	local rim = btn:FindFirstChild("KOGlow") or Instance.new("UIStroke")
	rim.Name = "KOGlow"
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Color, rim.Thickness, rim.Transparency, rim.Enabled = T.Glow.Color, T.Glow.Thick, 0, true
	rim.Parent = btn
	TweenService:Create(rim, TweenInfo.new(T.Glow.Time, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Transparency = 1, Thickness = 1 }):Play()
	local sc = btn:FindFirstChild("KOGlowPop") or Instance.new("UIScale")
	sc.Name, sc.Scale, sc.Parent = "KOGlowPop", 1, btn
	local up = TweenService:Create(sc, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = T.Glow.Pop })
	up.Completed:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	up:Play()
	task.delay(T.Glow.Time + 0.1, function() if rim.Parent then rim.Enabled = false end end)
	return true
end

-- the bag's quick items section: one row per usable item (its icon, name and count) with [1] [2] [3]; the slot it is
-- in is lit, a press puts it there (again = takes it out)
function QuickSlots.BagRows(parent, kit)
	if typeof(parent) ~= "Instance" or type(kit) ~= "table" then return 0 end
	local cur = QuickSlots.Get()
	local n = 0
	local order = type(Q.Order) == "table" and Q.Order or {}
	for _, item in order do
		local def = T.Items[item]
		if type(def) == "table" then
			n += 1
			local count = math.max(0, math.floor(num(LocalPlayer and type(def.Stock) == "string" and LocalPlayer:GetAttribute(def.Stock), 0)))
			local row = Instance.new("Frame")
			row.Name = "QuickItem_" .. item
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 44)
			row.LayoutOrder = type(kit.NextOrder) == "function" and kit.NextOrder() or n
			local list = Instance.new("UIListLayout")
			list.FillDirection = Enum.FillDirection.Horizontal
			list.VerticalAlignment = Enum.VerticalAlignment.Center
			list.SortOrder = Enum.SortOrder.LayoutOrder
			list.Padding = UDim.new(0, 6)
			list.Parent = row
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.new(1, -3 * 52, 1, 0)
			label.Font = kit.Font or Enum.Font.Gotham
			label.TextSize = 18
			label.TextColor3 = (kit.Theme and kit.Theme.Text) or Color3.new(1, 1, 1)
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = string.format("%s ×%d", tostring(def.Name or item), count)
			label.LayoutOrder = 0
			label.Parent = row
			for i = 1, T.Count do
				local on = cur[i] == item
				local b = kit.Button(row, string.format(T.Text.Set, i), on and kit.Theme.Gold or kit.Palette.Button,
					UDim2.fromOffset(46, 38), function()
						QuickSlots.Set(i, on and "" or item)
						if type(kit.Rebuild) == "function" then kit.Rebuild(true) end
					end, on and kit.Palette.DarkText or nil)
				b.LayoutOrder = i
			end
			row.Parent = parent
		end
	end
	return n
end

local function hook()
	if S.Hooked then return true end
	local h = C and C.HUD
	if type(h) ~= "table" or type(h.OnQuickSlot) ~= "function" then return false end
	local ok = pcall(h.OnQuickSlot, function(i) QuickSlots.Use(i, true) end)
	S.Hooked = ok
	return ok
end

function QuickSlots.Init(registry)
	C = registry
end

function QuickSlots.Start()
	if S.Started then return end
	S.Started = true
	-- keys 1 / 2 / 3 (Keybinds actions; VitalsUI leaves its potion keys to us: QuickSlots.OwnsKeys)
	local keys = C and C.Keybinds
	local began = type(keys) == "table" and type(keys.Began) == "table" and keys.Began or UserInputService.InputBegan
	began:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() or type(keys) ~= "table" then return end
		if type(keys.IsCapturing) == "function" and keys.IsCapturing() then return end
		local action = type(keys.ActionFor) == "function" and keys.ActionFor(input) or nil
		local i = action and table.find(T.Actions, action) or nil
		if i then QuickSlots.Use(i) end
	end)
	if LocalPlayer then
		LocalPlayer:GetAttributeChangedSignal(T.Attr):Connect(function()
			S.Local = nil
			QuickSlots.Refresh()
		end)
	end
	hook() -- the HUD's slots are built before us (ORDER); the loop below catches a later HUD
	task.spawn(function()
		while true do
			if not S.Hooked then hook() end
			local ok, err = pcall(QuickSlots.Refresh)
			if not ok then Util.Warn(TAG, "refresh failed: " .. tostring(err)) end
			local okK, errK = pcall(QuickSlots.KingWarnStep)
			if not okK then Util.Warn(TAG, "king warn failed: " .. tostring(errK)) end
			task.wait(T.Poll)
		end
	end)
end

return QuickSlots
