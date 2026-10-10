-- VitalsUI.luau : HP / MP bars beside the HUD portrait and the two potion buttons of the combat cluster (A23-26 HUD v2:
-- HUD places them from HudLayout rects through PlaceBars / PlacePotions), potion keys 1 / 2 (BB1 Keybinds).
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
	Level = true, -- Config.HudReveal: the potion pair from its level on
} }
local COL = { HP = Color3.fromRGB(239, 45, 51), MP = Color3.fromRGB(30, 171, 245), Dim = Color3.fromRGB(150, 150, 160) }
local ACTION = { HP = "PotionHP", MP = "PotionMP" } -- Config.Keybinds action of each potion button
-- the potion count on the BtnPotion socket (real px: box W x H at least, text Min..Max, outline thickness)
local COUNT_PX = { W = 24, H = 18, Min = 14, Max = 18, Outline = 1.5 }
-- UI round 2 #3 (검수 2026-10-07): with no potions the [Buy] press shows the way to the merchant (HUD.ShowGuide)
local WAY = { Label = "Potion shop", Gap = 1, At = -math.huge }

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
	if left > 0 then return count, tostring(math.ceil(left)) .. "s", false end
	if player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("ClassChosen") ~= true then return count, "Wait", false end
	if ui.Character ~= player.Character or not Util.IsAlive(player) then return count, "Revive", false end
	local kaiju = player:GetAttribute("KaijuState")
	if kaiju == "Active" or kaiju == "Siren" then return count, "Kaiju", false end
	if count <= 0 then return 0, Config.Vitals.MerchantEnabled == true and "Buy" or "Soon", false end
	if not canUse() then return count, "Wait", false end
	local humanoid = Util.GetHumanoid(player)
	local amount = kind == "HP" and humanoid.Health or finiteNumber(player:GetAttribute("Mana"), 0)
	local maximum = kind == "HP" and humanoid.MaxHealth or finiteNumber(player:GetAttribute("MaxMana"), Config.Vitals.MaxMana)
	if amount >= maximum then return count, "Full", false end
	return count, "Use", true
end

-- the beam to the potion merchant (workspace.Map.NPCs.<PotionMerchantName>) in the Crossroads, else to the way there
function WAY.Show()
	if os.clock() - WAY.At < WAY.Gap then return end
	WAY.At = os.clock()
	local hud, qt = C and C.HUD, C and C.QuestTarget
	if type(hud) ~= "table" or type(hud.ShowGuide) ~= "function" then return end
	local tune = Config.Vitals or {}
	local zone = player:GetAttribute("ZoneId")
	local target = nil
	if zone == "Crossroads" then
		local map = workspace:FindFirstChild("Map")
		local npcs = map and map:FindFirstChild("NPCs")
		local npc = npcs and npcs:FindFirstChild(tune.PotionMerchantName or "PotionMerchant")
		if npc and npc:IsA("Model") then
			target = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true)
		end
	elseif type(qt) == "table" and type(qt.Travel) == "function" then
		local ok, part = pcall(qt.Travel, "Crossroads", zone)
		if ok then target = part end
	end
	if typeof(target) == "Instance" and target:IsA("BasePart") then pcall(hud.ShowGuide, target, WAY.Label) end
end

local function requestPotion(kind)
	local count, label, available = potionState(kind)
	if not available then
		if count <= 0 and label == "Buy" then WAY.Show() end -- no potions: show the way to the merchant
		return
	end
	-- Display checks only: the server alone consumes stock, heals, charges MP and applies the deadline.
	Net.Get("UsePotion"):FireServer(kind)
end

-- HP / MP bars (BarTrack art). Built at their v2 heights (the fill's rounded caps follow the build height); HUD places
-- them with PlaceBars. The text reads '82/152' (no 'HP': it is not mistaken for the potion).
function VitalsUI.BuildStats(parent, touch)
	for i, kind in { "HP", "MP" } do
		local frame, set, text = UIKit.ArtBar({ Name = kind .. "Bar", Parent = parent,
			Size = UDim2.fromOffset(touch and 200 or 262, (touch and 18 or 22) - (i - 1) * 3), Color = COL[kind],
			TextSize = touch and 15 or 12 })
		text.TextWrapped = false
		C.HUD.FitText(text, 11, nil, nil, true) -- 2026-10-08: real 11 px on small PC windows too (HudLayout's bar floor)
		ui[kind] = { Frame = frame, Set = set, Text = text }
	end
end

-- HUD v2: the bars on their HudLayout rects (logical units, HUD root space)
function VitalsUI.PlaceBars(hp, mp)
	for kind, r in { HP = hp, MP = mp } do
		local bar = ui[kind]
		if bar and r then
			bar.Frame.Position = UDim2.fromOffset(r.X, r.Y)
			bar.Frame.Size = UDim2.fromOffset(r.W, r.H)
		end
	end
end

-- potion text sizes follow the button size (count in the socket, status over the icon, key badge)
function VitalsUI.LayoutPotions()
	local scale = UIKit.Gui:FindFirstChildOfClass("UIScale")
	local s = scale and math.max(0.1, scale.Scale) or 1
	for _, potion in ui.Potions do
		local d = potion.Size or 72
		-- 이미지 개발 10/09 (main PC photo: the '0' was a ~9 px speck on the ring): the count box covers the socket and a
		-- little of the ring around it, at least COUNT_PX real px tall
		potion.Count.Size = UDim2.fromOffset(math.max(d * 0.5, math.ceil(COUNT_PX.W / s)),
			math.max(d * 0.38, math.ceil(COUNT_PX.H / s)))
		potion.Status.Size = UDim2.fromOffset(d * 0.86, math.max(d * 0.26, math.ceil(12 / s)))
		if potion.Key then
			local keyH = math.max(15, math.ceil((potion.Slot and 15 or 12) / s))
			potion.Key.Size = UDim2.fromOffset(keyH, keyH)
		end
	end
end

-- two round potion buttons (Firefly BtnPotion: navy disc, count socket bottom-right) left of the skill button: the potion
-- icon fills the face, the stock sits in the socket, a short status ('3초' / '가득' / '구매') shows over the icon only when
-- the potion cannot be drunk, the key badge (keyboards) sits bottom-left. HUD places the row with PlacePotions.
function VitalsUI.BuildPotions(parent, touch)
	local row = UIKit.Create("Frame", { Name = "Potions", BackgroundTransparency = 1,
		Size = UDim2.fromOffset(152, 72), Parent = parent })
	-- A23-109 (user 10/10 "물약은 빼야겠어 … 1·2·3은 가로로"): on PCs the pair are quick slots 1 and 2 - square slots
	-- (the MenuTile square, a little smaller than the menu tiles) in HudLayout's quick row, the slot number top-left;
	-- slot 3 is HUD's (QuickSlot3). Until 개발 1's quick slots take items, slot 1 = HP potion, slot 2 = MP potion
	local square = not touch
	for i, kind in { "HP", "MP" } do
		local button = UIKit.ArtButton(square and "MenuTile" or "BtnPotion", { Name = kind .. "Potion", Parent = row,
			AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(72, 72),
			ImageTransparency = square and 0.15 or nil }, function() -- 0.15 = HUD L.TileTint
			-- A23-109: once 개발 1's quick slots registered (HUD.OnQuickSlot), slots 1 and 2 belong to them
			local own = square and VitalsUI.QuickOwner()
			if own then own(i) else requestPotion(kind) end
		end,
			{ CornerRadius = square and UDim.new(0, 8) or UDim.new(0.5, 0), BackgroundTransparency = square and 0.25 or nil })
		if square then
			button:SetAttribute("QuickSlot", i)
			VitalsUI.QuickCooldown(button)
		end
		local icon = UIKit.ArtImage("IconPotion" .. kind, { Name = "Icon", Parent = button,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = square and UDim2.fromScale(0.5, 0.5) or UDim2.fromScale(0.48, 0.47),
			Size = square and UDim2.fromScale(0.66, 0.66) or UDim2.fromScale(0.56, 0.56), ZIndex = 3 })
		local count = UIKit.LightText({ Name = "Count", Parent = button, Text = "0",
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.82, 0.77), Size = UDim2.fromOffset(22, 18),
			TextScaled = true, Number = true, MaxTextSize = touch and 18 or 16, ZIndex = 5 })
		local status = UIKit.LightText({ Name = "Status", Parent = button, Text = "",
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(60, 18),
			TextScaled = true, Title = true, MaxTextSize = touch and 16 or 14, ZIndex = 6, Visible = false })
		C.HUD.FitText(count, COUNT_PX.Max, true, COUNT_PX.Min, true)
		-- a full dark outline (FitText's default is a faint 0.4 px one): the digit sits on the gold ring. UIKit's fit pass
		-- re-caps the stroke at PickerOutlineThickness on every pass, so the cap is raised too
		local countLine = count:FindFirstChild("Outline")
		if countLine and countLine:IsA("UIStroke") then
			count:SetAttribute("PickerOutlineThickness", COUNT_PX.Outline)
			countLine.Thickness, countLine.Transparency = COUNT_PX.Outline, 0
		end
		C.HUD.FitText(status, 12, true)
		local key = nil
		local kbm = C and C.Keybinds
		local showsKeys = UserInputService.KeyboardEnabled
		if type(kbm) == "table" and type(kbm.ShowsKeys) == "function" then showsKeys = kbm.ShowsKeys() end
		if showsKeys or square then -- review of 27246d1: the same rule as Keybinds / HUD (A23-109: PC slots always numbered)
			-- BB1: the badge shows the potion's current key (VitalsUI.RefreshKeys) and widens for "Ctrl" / "Num1"
			key = UIKit.LightText({ Name = "Key", Parent = button, Text = "", TextSize = 11, ZIndex = 6,
				AnchorPoint = square and Vector2.new(0, 0) or Vector2.new(0, 1),
				Position = square and UDim2.fromScale(0.06, 0.04) or UDim2.fromScale(0.04, 1), Size = UDim2.fromOffset(15, 15),
				AutomaticSize = Enum.AutomaticSize.X })
			if square then C.HUD.FitText(key, 13, true, 12, true) else C.HUD.FitText(key, 11) end -- A23-109: 12 px numbers
		end
		ui.Potions[kind] = { Button = button, Icon = icon, Count = count, Status = status, Key = key,
			Action = ACTION[kind], Size = 72, Slot = square and i or nil }
	end
	ui.Row = row
	VitalsUI.LayoutPotions()
	VitalsUI.RefreshKeys()
	if ui.Refresh then ui.Refresh() end
	return row
end

-- A23-109 quick slots: the handler 개발 1 registered with HUD.OnQuickSlot (nil = slots 1 / 2 are still the potions)
function VitalsUI.QuickOwner()
	local hud = C and C.HUD
	local get = type(hud) == "table" and hud.QuickHandler or nil
	return type(get) == "function" and get() or nil
end

-- A23-109: the cooldown cover of a quick slot - a dark Frame filling up from the bottom (개발 1 sets Size.Y / Visible)
function VitalsUI.QuickCooldown(button)
	local f = UIKit.Create("Frame", { Name = "Cooldown", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.fromRGB(10, 14, 30), BackgroundTransparency = 0.45,
		BorderSizePixel = 0, Visible = false, ZIndex = 4, Parent = button })
	UIKit.Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = f })
	return f
end

-- HUD v2: the pair on Rects.potions (logical units). rect.Cells = { HP = rect, MP = rect } (HudLayout 2026-10-07: each
-- button's own rect - phones put them on the thumb ring around the attack): each button centred in its cell; else two
-- square-sized cells split by rect.Gap, MP at the right edge
function VitalsUI.PlacePotions(rect)
	if not ui.Row or not rect then return end
	local gap = tonumber(rect.Gap) or 7.5
	local d = math.min(rect.H, (rect.W - gap) / 2)
	local cells = type(rect.Cells) == "table" and rect.Cells or nil
	ui.Row.Position = UDim2.fromOffset(rect.X, rect.Y)
	ui.Row.Size = UDim2.fromOffset(rect.W, rect.H)
	for i, kind in { "HP", "MP" } do
		local potion = ui.Potions[kind]
		local cell = cells and cells[kind]
		if potion and cell then
			local cd = math.min(cell.W, cell.H)
			potion.Button.Position = UDim2.fromOffset(cell.X + cell.W / 2 - rect.X, cell.Y + cell.H / 2 - rect.Y)
			potion.Button.Size = UDim2.fromOffset(cd, cd)
			potion.Size = cd
		elseif potion then
			local cx = rect.W - d / 2 - (2 - i) * (d + gap)
			potion.Button.Position = UDim2.fromOffset(cx, rect.H / 2)
			potion.Button.Size = UDim2.fromOffset(d, d)
			potion.Size = d
		end
	end
	VitalsUI.LayoutPotions()
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
			if potion.Slot then
				-- A23-109 PC quick slot: the slot number always shows (the bound key's name when it is not the number)
				key.Text = (bound and label ~= "") and label or tostring(potion.Slot)
				key.Visible = true
			else
				key.Text = label
				key.Visible = badges and bound and label ~= ""
			end
		end
	end
end

local function refresh()
	local humanoid = Util.GetHumanoid(player)
	local hp, maxHP = humanoid and humanoid.Health or 0, humanoid and humanoid.MaxHealth or 1
	local mana = math.max(0, finiteNumber(player:GetAttribute("Mana"), 0))
	local maxMana = math.max(1, finiteNumber(player:GetAttribute("MaxMana"), Config.Vitals.MaxMana))
	-- 검수 10/09 (UI clutter review ④): the pair comes when it is needed and then stays (Config.HudReveal)
	if ui.Row and not ui.PotionSeen then
		local held = potionState("HP") + potionState("MP")
		ui.PotionSeen = Config.HudReveal.Shows("Potions", { Level = player:GetAttribute("Level"), Potions = held,
			HP = hp, MaxHP = maxHP })
		if ui.Row.Visible ~= ui.PotionSeen then ui.Row.Visible = ui.PotionSeen end
	end
	for kind, values in { HP = { hp, maxHP }, MP = { mana, maxMana } } do
		local bar = ui[kind]
		if bar then
			bar.Set(values[1] / math.max(1, values[2]))
			bar.Text.Text = string.format("%d/%d", math.ceil(values[1]), math.ceil(values[2]))
		end
		local potion = ui.Potions[kind]
		if potion and potion.Slot and VitalsUI.QuickOwner() then potion = nil end -- 개발 1's quick slots fill it
		if potion then
			local count, status, available = potionState(kind)
			potion.Count.Text = tostring(count)
			potion.Status.Text = status
			-- ui_clutter_review ④ (검수 10/09): no 'Buy' / 'Full' words over the button - the potion picture + its count say
			-- it (0 = a dim potion); only the cooldown seconds stay as text. A full bar keeps the potion bright (nothing wrong)
			local cooling = string.match(status, "^%d+s$") ~= nil
			local dim = not available and (count <= 0 or cooling or status ~= "Full")
			potion.Status.Visible = cooling
			potion.Button.Active = available
			potion.Button:SetAttribute("Disabled", not available)
			if potion.Button:IsA("ImageButton") then
				potion.Button.ImageColor3 = dim and Color3.fromRGB(178, 174, 166) or Color3.new(1, 1, 1)
			end
			if potion.Icon then potion.Icon.ImageColor3 = dim and COL.Dim or Color3.new(1, 1, 1) end
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

-- A23-110 (dev3 KO1 "Buy a potion" row tap, HUD L.StoryTap): the way to the potion seller now
function VitalsUI.ShowShopWay()
	WAY.At = -math.huge
	WAY.Show()
	return true
end

-- A23-109: a quick slot's potion (QuickSlots.Use) - the same request as the potion button (the server checks)
function VitalsUI.Request(kind)
	if kind ~= "HP" and kind ~= "MP" then return false end
	requestPotion(kind)
	return true
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
		-- A23-109: with the quick slots running, keys 1 / 2 use slots 1 / 2 (QuickSlots.luau) - not here twice
		local quick = C.QuickSlots
		if type(quick) == "table" and type(quick.OwnsKeys) == "function" and quick.OwnsKeys() then return end
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
