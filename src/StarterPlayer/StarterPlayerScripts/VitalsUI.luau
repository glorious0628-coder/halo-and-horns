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
local ui = { Potions = {} }
local COL = { HP = Color3.fromRGB(239, 45, 51), MP = Color3.fromRGB(30, 171, 245) }

local function canUse()
	if player:GetAttribute("ClassChosen") ~= true or not Util.IsAlive(player) then return false end
	for _, name in { "FactionPicker", "ClassPicker", "WorldMap", "Panels" } do
		local module = C[name]
		if module and type(module.IsOpen) == "function" then
			local ok, open = pcall(module.IsOpen)
			if not ok or open then return false end
		end
	end
	return true
end

local function requestPotion(kind)
	if not canUse() then return end
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
		local title = UIKit.InkText({ Name = "Title", Parent = button, Text = kind .. " 물약",
			Position = UDim2.fromOffset(left, 6), Size = UDim2.fromOffset(w - left - 5, height * 0.4),
			TextScaled = true, TextWrapped = false, MaxTextSize = touch and 16 or 14 })
		local status = UIKit.InkText({ Name = "Status", Parent = button, Text = "사용 가능",
			Position = UDim2.fromOffset(left, height * 0.49), Size = UDim2.fromOffset(w - left - 5, height * 0.35),
			TextScaled = true, TextWrapped = false, MaxTextSize = touch and 15 or 12 })
		C.HUD.FitText(title, 12)
		C.HUD.FitText(status, 11)
		local key = nil
		if UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled then
			key = UIKit.InkText({ Name = "Key", Parent = button, Text = tostring(i), TextSize = 11,
				Position = UDim2.fromOffset(2, 0), Size = UDim2.fromOffset(15, 15) })
			C.HUD.FitText(key, 11)
		end
		ui.Potions[kind] = { Button = button, Title = title, Status = status, Key = key, Height = height, Width = w, Left = left }
	end
	VitalsUI.LayoutPotions()
	return row
end

local function refresh()
	local humanoid = Util.GetHumanoid(player)
	local hp, maxHP = humanoid and humanoid.Health or 0, humanoid and humanoid.MaxHealth or 1
	local mana = tonumber(player:GetAttribute("Mana")) or 0
	local maxMana = math.max(1, tonumber(player:GetAttribute("MaxMana")) or Config.Vitals.MaxMana)
	for kind, values in { HP = { hp, maxHP }, MP = { mana, maxMana } } do
		local bar = ui[kind]
		if bar then
			bar.Set(values[1] / math.max(1, values[2]))
			bar.Text.Text = string.format("%s %d / %d", kind, math.ceil(values[1]), math.ceil(values[2]))
		end
		local potion = ui.Potions[kind]
		if potion then
			local left = math.max(0, (tonumber(player:GetAttribute(kind .. "PotionReadyAt")) or 0) - workspace:GetServerTimeNow())
			potion.Status.Text = left > 0 and (tostring(math.ceil(left)) .. "초") or "사용 가능"
			if potion.Button:IsA("ImageButton") then
				potion.Button.ImageColor3 = left > 0 and Color3.fromRGB(178, 174, 166) or Color3.new(1, 1, 1)
			end
		end
	end
end

function VitalsUI.Init(registry)
	C, UIKit = registry, registry.UIKit
end

function VitalsUI.Start()
	-- This game equips custom Parts, so its potion shortcuts own 1/2 and its HP bar owns health display.
	local starterGui = game:GetService("StarterGui")
	pcall(starterGui.SetCoreGuiEnabled, starterGui, Enum.CoreGuiType.Backpack, false)
	pcall(starterGui.SetCoreGuiEnabled, starterGui, Enum.CoreGuiType.Health, false)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.One then requestPotion("HP") end
		if input.KeyCode == Enum.KeyCode.Two then requestPotion("MP") end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(refresh)
			if not ok then Util.Warn("VitalsUI", tostring(err)) end
			task.wait(0.2)
		end
	end)
	print("[VitalsUI] started")
end

return VitalsUI
