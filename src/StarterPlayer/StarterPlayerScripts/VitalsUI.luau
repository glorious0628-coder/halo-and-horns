-- Approved UI_HUD_Vitals_A: HP/MP under XP, two potion buttons, quest block below them.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Util = require(ReplicatedStorage.Shared.Util)
local VitalsUI = {}
local C, UIKit = nil, nil
local player = Players.LocalPlayer
local ui = { Potions = {}, CharacterConnections = {}, HumanoidConnections = {}, WatchedAttributes = {
	Mana = true, MaxMana = true, HPPotionCount = true, MPPotionCount = true,
	HPPotionReadyAt = true, MPPotionReadyAt = true, ClassChosen = true, DataLoaded = true, KaijuState = true,
} }
local COL = { HP = Color3.fromRGB(239, 45, 51), MP = Color3.fromRGB(30, 171, 245) }
local ACTION = { HP = "PotionHP", MP = "PotionMP" } -- Config.Keybinds action of each potion button

local function canUse()
	if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true
		or player:GetAttribute("ClassChosen") ~= true or not Util.IsAlive(player) then return false end
	if ui.Character ~= player.Character or ui.Humanoid ~= Util.GetHumanoid(player) then return false end
	local kaiju = player:GetAttribute("KaijuState")
	if kaiju == "Active" or kaiju == "Siren" then return false end
	for _, name in { "Intro", "FactionPicker", "ClassPicker", "WorldMap", "Panels" } do
		local module = C[name]
		if module and type(module.IsOpen) == "function" then
			local ok, open = pcall(module.IsOpen)
			if not ok or open then return false end
		end
	end
	return true
end

local function finiteNumber(value, fallback)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge and value or fallback
end

local function potionState(kind)
	local count = Config.NormalizePotionCount(player:GetAttribute(kind .. "PotionCount"))
	local deadline = finiteNumber(player:GetAttribute(kind .. "PotionReadyAt"), 0)
	local left = math.max(0, deadline - workspace:GetServerTimeNow())
	-- Stock is shown in the title: even the narrow touch slot can show stock and the entire countdown.
	if left > 0 then return count, tostring(math.ceil(left)) .. "초", false end
	if player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("ClassChosen") ~= true then return count, "대기", false end
	if ui.Character ~= player.Character or not Util.IsAlive(player) then return count, "부활", false end
	local kaiju = player:GetAttribute("KaijuState")
	if kaiju == "Active" or kaiju == "Siren" then return count, "괴수", false end
	if count <= 0 then return 0, Config.Vitals.MerchantEnabled == true and "구매" or "준비 중", false end
	if not canUse() then return count, "대기", false end
	local humanoid = Util.GetHumanoid(player)
	local amount = kind == "HP" and humanoid.Health or finiteNumber(player:GetAttribute("Mana"), 0)
	local maximum = kind == "HP" and humanoid.MaxHealth or finiteNumber(player:GetAttribute("MaxMana"), Config.Vitals.MaxMana)
	if amount >= maximum then return count, "가득", false end
	return count, "사용", true
end

local function requestPotion(kind)
	local _, _, available = potionState(kind)
	if not available then return end
	-- Display checks only: the server alone consumes stock, heals, charges MP and applies the deadline.
	Net.Get("UsePotion"):FireServer(kind)
end

function VitalsUI.BuildStats(parent, x, width, touch)
	for i, kind in { "HP", "MP" } do
		local frame, set, text = UIKit.ArtBar({ Name = kind .. "Bar", Parent = parent,
			Position = UDim2.fromOffset(x, (touch and 36 or 66) + (i - 1) * (touch and 20 or 18)),
			Size = UDim2.fromOffset(width, touch and 18 or 16), Color = COL[kind], TextSize = touch and 15 or 12 })
		text.TextWrapped = false
		C.HUD.FitText(text, 11)
		ui[kind] = { Frame = frame, Set = set, Text = text }
	end
end

function VitalsUI.LayoutStats(y, height, gap)
	for i, kind in { "HP", "MP" } do
		local bar = ui[kind]
		if bar then
			bar.Frame.Position = UDim2.fromOffset(bar.Frame.Position.X.Offset, y + (i - 1) * (height + gap))
			bar.Frame.Size = UDim2.fromOffset(bar.Frame.Size.X.Offset, height)
		end
	end
	VitalsUI.LayoutPotions()
end

function VitalsUI.LayoutPotions()
	local scale = UIKit.Gui:FindFirstChildOfClass("UIScale")
	local s = scale and math.max(0.1, scale.Scale) or 1
	for _, potion in ui.Potions do
		local h = potion.Height
		local titleH = math.max(h * 0.4, math.ceil(12 / s))
		local statusH = math.max(h * 0.35, math.ceil(12 / s))
		local titleY = 6
		local statusY = math.max(h * 0.49, titleY + titleH + 1)
		if statusY + statusH > h - 4 then
			titleY = math.max(3, math.floor((h - titleH - statusH - 2) / 2))
			statusY = titleY + titleH + 1
		end
		potion.Title.Position = UDim2.fromOffset(potion.Left, titleY)
		potion.Title.Size = UDim2.fromOffset(potion.Width - potion.Left - 5, titleH)
		potion.Status.Position = UDim2.fromOffset(potion.Left, statusY)
		potion.Status.Size = UDim2.fromOffset(potion.Width - potion.Left - 5, statusH)
		if potion.Key then
			local keyH = math.max(15, math.ceil(12 / s))
			potion.Key.Size = UDim2.fromOffset(keyH, keyH)
		end
	end
end

function VitalsUI.BuildPotions(parent, width, height, touch)
	local row = UIKit.Create("Frame", { Name = "Potions", BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, height), Parent = parent })
	for i, kind in { "HP", "MP" } do
		local w = (width - 6) / 2
		local button = UIKit.ArtButton("PanelParchment", { Name = kind .. "Potion", Text = "", Parent = row,
			Position = UDim2.fromOffset((i - 1) * (w + 6), 0), Size = UDim2.fromOffset(w, height) }, function() requestPotion(kind) end)
		local iconSize = touch and 38 or 34
		local icon = UIKit.ArtImage("IconPotion" .. kind, { Name = "Icon", Parent = button,
			Position = UDim2.fromOffset(5, (height - iconSize) / 2), Size = UDim2.fromOffset(iconSize, iconSize) })
		local left = icon and iconSize + 8 or 6
		local title = UIKit.InkText({ Name = "Title", Parent = button, Text = kind .. "0개",
			Position = UDim2.fromOffset(left, 6), Size = UDim2.fromOffset(w - left - 5, height * 0.4),
			TextScaled = true, TextWrapped = false, MaxTextSize = touch and 16 or 14 })
		local status = UIKit.InkText({ Name = "Status", Parent = button, Text = "구매",
			Position = UDim2.fromOffset(left, height * 0.49), Size = UDim2.fromOffset(w - left - 5, height * 0.35),
			TextScaled = true, TextWrapped = false, MaxTextSize = touch and 15 or 12 })
		C.HUD.FitText(title, 12)
		C.HUD.FitText(status, 11)
		local key = nil
		local kbm = C and C.Keybinds
		local showsKeys = UserInputService.KeyboardEnabled
		if type(kbm) == "table" and type(kbm.ShowsKeys) == "function" then showsKeys = kbm.ShowsKeys() end
		if showsKeys then -- review of 27246d1: the same rule as Keybinds / HUD
			-- BB1: the badge shows the potion's current key (VitalsUI.RefreshKeys) and widens for "Ctrl" / "Num1"
			key = UIKit.InkText({ Name = "Key", Parent = button, Text = "", TextSize = 11,
				Position = UDim2.fromOffset(2, 0), Size = UDim2.fromOffset(15, 15), AutomaticSize = Enum.AutomaticSize.X })
			C.HUD.FitText(key, 11)
		end
		ui.Potions[kind] = { Button = button, Title = title, Status = status, Key = key, Action = ACTION[kind],
			Height = height, Width = w, Left = left }
	end
	VitalsUI.LayoutPotions()
	VitalsUI.RefreshKeys()
	if ui.Refresh then ui.Refresh() end
	return row
end

-- BB1: each potion badge shows its action's current key (Keybinds.Label); hidden while that action has no key or
-- Settings.KeyBadges is off. Runs on Keybinds.Changed and Settings.Changed.
function VitalsUI.RefreshKeys()
	local kb, st = C and C.Keybinds, C and C.Settings
	local badges = true
	if type(st) == "table" and type(st.Get) == "function" then
		local ok, v = pcall(st.Get, "KeyBadges")
		badges = not ok or v ~= false
	end
	for _, potion in ui.Potions do
		local key = potion.Key
		if key and key.Parent then
			local label, bound = "", false
			if type(kb) == "table" then
				local okL, text = pcall(kb.Label, potion.Action)
				local okK, name = pcall(kb.KeyName, potion.Action)
				label = okL and type(text) == "string" and text or ""
				bound = okK and type(name) == "string" and name ~= ""
			end
			key.Text = label
			key.Visible = badges and bound and label ~= ""
		end
	end
end

local function refresh()
	local humanoid = Util.GetHumanoid(player)
	local hp, maxHP = humanoid and humanoid.Health or 0, humanoid and humanoid.MaxHealth or 1
	local mana = math.max(0, finiteNumber(player:GetAttribute("Mana"), 0))
	local maxMana = math.max(1, finiteNumber(player:GetAttribute("MaxMana"), Config.Vitals.MaxMana))
	for kind, values in { HP = { hp, maxHP }, MP = { mana, maxMana } } do
		local bar = ui[kind]
		if bar then
			bar.Set(values[1] / math.max(1, values[2]))
			bar.Text.Text = string.format("%s %d / %d", kind, math.ceil(values[1]), math.ceil(values[2]))
		end
		local potion = ui.Potions[kind]
		if potion then
			local count, status, available = potionState(kind)
			potion.Title.Text = kind .. tostring(count) .. "개"
			potion.Status.Text = status
			potion.Button.Active = available
			potion.Button:SetAttribute("Disabled", not available)
			if potion.Button:IsA("ImageButton") then
				potion.Button.ImageColor3 = not available and Color3.fromRGB(178, 174, 166) or Color3.new(1, 1, 1)
			end
		end
	end
end

ui.Refresh = function()
	local ok, err = pcall(refresh)
	if not ok then Util.Warn("VitalsUI", tostring(err)) end
end

local function clearConnections(list)
	for _, connection in list do connection:Disconnect() end
	table.clear(list)
end

local function bindHumanoid(humanoid)
	if ui.Humanoid == humanoid then return end
	clearConnections(ui.HumanoidConnections)
	ui.Humanoid = humanoid
	if humanoid then
		table.insert(ui.HumanoidConnections, humanoid.HealthChanged:Connect(ui.Refresh))
		table.insert(ui.HumanoidConnections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(ui.Refresh))
	end
	ui.Refresh()
end

local function bindCharacter(character)
	clearConnections(ui.CharacterConnections)
	ui.Character = character
	bindHumanoid(character and character:FindFirstChildOfClass("Humanoid") or nil)
	if not character then return end
	table.insert(ui.CharacterConnections, character.ChildAdded:Connect(function(child)
		if player.Character == character and child:IsA("Humanoid") then bindHumanoid(child) end
	end))
	table.insert(ui.CharacterConnections, character.ChildRemoved:Connect(function(child)
		if ui.Character == character and child == ui.Humanoid then bindHumanoid(nil) end
	end))
	table.insert(ui.CharacterConnections, character.AncestryChanged:Connect(ui.Refresh))
end

function VitalsUI.Init(registry)
	C, UIKit = registry, registry.UIKit
end

function VitalsUI.Start()
	if ui.Started then return end
	ui.Started = true
	-- This game equips custom Parts, so its potion shortcuts own 1/2 and its HP bar owns health display.
	local starterGui = game:GetService("StarterGui")
	pcall(starterGui.SetCoreGuiEnabled, starterGui, Enum.CoreGuiType.Backpack, false)
	pcall(starterGui.SetCoreGuiEnabled, starterGui, Enum.CoreGuiType.Health, false)
	-- BB1: the potion keys come from Keybinds (default 1 / 2); Keybinds forwards every key press (and Dispatch tests)
	local keys = C.Keybinds
	local began = type(keys) == "table" and type(keys.Began) == "table" and keys.Began or UserInputService.InputBegan
	began:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() or type(keys) ~= "table" or keys.IsCapturing() then return end
		local action = keys.ActionFor(input)
		if action == "PotionHP" then requestPotion("HP") end
		if action == "PotionMP" then requestPotion("MP") end
	end)
	-- BB1: the potion badges follow key changes and Settings.KeyBadges
	if type(keys) == "table" and type(keys.Changed) == "table" then keys.Changed:Connect(VitalsUI.RefreshKeys) end
	local st = C.Settings
	if type(st) == "table" and type(st.Changed) == "table" then st.Changed:Connect(VitalsUI.RefreshKeys) end
	VitalsUI.RefreshKeys()
	player.AttributeChanged:Connect(function(name)
		if ui.WatchedAttributes[name] then ui.Refresh() end
	end)
	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function(character)
		if ui.Character == character then bindCharacter(nil) end
	end)
	bindCharacter(player.Character)
	task.spawn(function()
		while true do
			ui.Refresh()
			task.wait(0.2)
		end
	end)
	print("[VitalsUI] started")
end

return VitalsUI
