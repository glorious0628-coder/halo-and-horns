-- SettingsUI.luau : the BB3 settings window, BB15 help and the news window, added through Panels.Register (BB13); the
-- HUD [메뉴] fold shows their squares once they are registered (A23-40 정정: News · Travel · Help · Settings · [Menu]).
-- A23-48: the game shows English only (texts: Config.Settings.Window, Config.Help, Config.Settings.Text *En).
-- Settings (user 2026-10-06 정정): rows Change Class · Rebirth · Replay Opening · Hide my name · Vacation Bonus (while I
-- have vacation days) · Key Settings · Sound Effects · Screen Shake · Key Hints (keyboards), then the build / server
-- footer and "saving is off" (GameState SaveOK). The Nickname row stays here until the Character window (BB8) exists.
-- [Keys] tab: every live Keybinds action with its key button (capture 5 s: Keybinds.Capture swaps with the holder,
-- refuses Roblox keys) and [Clear]; [Default Keys]; touch-only devices get one line instead, a gamepad the fixed table.
-- Help: Config.Help.Topics (Controls built from my live keys) + "Meet the Guide Again" (the welcome lines read-only; the
-- real guide window only at TutorialStep 0). News: Config.Help.News.
-- The open tab and the guide page live here (rebuilds keep them); Cleanup ends a running key capture and flushes the
-- settings blob (BB2).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local SettingsUI = {}
local TAG = "SettingsUI"
local C = nil
local player = Players.LocalPlayer

local W = Config.Settings.Window
local ST = Config.Settings.Text
local KB = Config.Keybinds
-- module state: the open tab, the last open arg seen, the guide page, the running capture, live connections
local S = { Tab = "Main", LastArg = nil, Guide = false, Capture = nil, Conns = {} }
-- layout (canvas px; Panels' phone UIScale is 0.75, so 60 = 45 real px)
local L = { RowH = 68, BtnH = 56, BtnW = 140, SmallW = 64, TabH = 52, LabelSize = 20, NoteSize = 16, Gap = 8 }

------------------------------------------------------------------ helpers
local function settingsGet(key, default)
	local st = C and C.Settings
	if type(st) ~= "table" or type(st.Get) ~= "function" then return default end
	local ok, v = pcall(st.Get, key)
	if ok and v ~= nil then return v end
	return default
end

local function settingsSet(key, value)
	local st = C and C.Settings
	if type(st) ~= "table" or type(st.Set) ~= "function" then return false end
	local ok, res = pcall(st.Set, key, value)
	return ok and res == true
end

local function keybinds()
	local kb = C and C.Keybinds
	return type(kb) == "table" and kb or nil
end

local function panelsHas(id)
	local p = C and C.Panels
	return type(p) == "table" and type(p.Has) == "function" and p.Has(id) == true
end

-- 최종 검수 10/13 (API review): the Nickname row stays here until the Hero window can really open - it holds the name
-- (CharacterUI), but below Lv 2 every way into it is locked (the HUD's rule, Config.HudReveal.TileShows), so a new player
-- changes the name here. Pure: hasCharacter = the window is registered, level = my Level
function SettingsUI.NicknameRow(hasCharacter, level)
	return not hasCharacter or not Config.HudReveal.TileShows("Character", { Level = level })
end

local function corner(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = obj
end

local function list(parent, padding, horizontal)
	local l = Instance.new("UIListLayout")
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, padding or L.Gap)
	if horizontal then
		l.FillDirection = Enum.FillDirection.Horizontal
		l.HorizontalAlignment = Enum.HorizontalAlignment.Right
		l.VerticalAlignment = Enum.VerticalAlignment.Center
	else
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	l.Parent = parent
	return l
end

local function scroller(parent, name)
	local f = Instance.new("ScrollingFrame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Position = UDim2.fromOffset(0, L.TabH + 10)
	f.Size = UDim2.new(1, 0, 1, -(L.TabH + 10))
	f.CanvasSize = UDim2.new()
	f.AutomaticCanvasSize = Enum.AutomaticSize.Y
	f.ScrollingDirection = Enum.ScrollingDirection.Y
	f.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	f.ScrollBarThickness = 6
	list(f, L.Gap)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 2)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 2)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = f
	f.Parent = parent
	return f
end

-- one settings row: the name on the left, a right-aligned holder for its buttons
local function row(kit, parent, text)
	local r = Instance.new("Frame")
	r.Name = "Row"
	r.BackgroundColor3 = kit.Palette.Row
	r.BorderSizePixel = 0
	r.Size = UDim2.new(1, 0, 0, L.RowH)
	r.LayoutOrder = kit.NextOrder()
	corner(r, 10)
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(14, 0)
	label.Size = UDim2.new(0.5, -14, 1, 0)
	label.Font = kit.Theme.Font
	label.TextSize = L.LabelSize
	label.TextColor3 = kit.Theme.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = text
	label.Parent = r
	local holder = Instance.new("Frame")
	holder.Name = "Controls"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 0.5)
	holder.Position = UDim2.new(1, -8, 0.5, 0)
	holder.Size = UDim2.new(0.5, 0, 0, L.BtnH)
	list(holder, 6, true)
	holder.Parent = r
	r.Parent = parent
	return r, holder, label
end

local function button(kit, holder, text, width, onClick, color, textColor)
	local b = kit.Button(holder, text, color or kit.Palette.Button, UDim2.fromOffset(width or L.BtnW, L.BtnH), onClick, textColor)
	b.TextSize = L.LabelSize
	return b
end

local function header(kit, parent, text)
	return kit.Text(parent, text, { Color = kit.Theme.Gold, Font = kit.Theme.Font, Size = 22 })
end

local function onOff(v)
	return v and W.On or W.Off
end

-- On = gold, Off = the plain button colour
local function paintToggle(kit, b, on)
	b.Text = onOff(on)
	kit.Paint(b, on and kit.Theme.Gold or kit.Palette.Button, on and kit.Palette.DarkText or kit.Theme.Text)
end

local function keyLabel(action)
	local kb = keybinds()
	local name = kb and kb.KeyName(action) or ""
	if name == "" then return W.None end
	return Config.KeyLabel(name, true)
end

local function disconnectAll()
	for _, c in S.Conns do
		pcall(function() c:Disconnect() end)
	end
	table.clear(S.Conns)
end

------------------------------------------------------------------ settings: main tab
local function buildMain(kit, frame)
	local refresh = {}

	local _, h = row(kit, frame, W.Class)
	button(kit, h, W.Open, nil, function() kit.Open("Class") end)

	local _, hr, lr = row(kit, frame, W.Rebirth)
	local rb = button(kit, hr, W.Open, nil, function() kit.Open("Rebirth") end)
	table.insert(refresh, function()
		local ready = kit.Num("Level") >= Config.RebirthLevel(kit.Num("Rebirths"))
		lr.Text = ready and W.RebirthReady or W.Rebirth
		kit.Paint(rb, ready and kit.Theme.Gold or kit.Palette.Button, ready and kit.Palette.DarkText or kit.Theme.Text)
	end)

	_, h = row(kit, frame, W.Intro)
	button(kit, h, W.Watch, nil, function()
		-- A23-9: replay only inside a town (safe and calm), never mid-fight
		local intro = C and C.Intro
		if kit.Attr("ZoneTown", false) ~= true or kit.IsDead() then
			kit.Toast(W.IntroUnsafe, "bad")
		elseif type(intro) == "table" and type(intro.Play) == "function" then
			kit.Close()
			intro.Play(true)
		end
	end)

	-- BB37 name hiding: the server keeps HideAnnounceName (SetAnnounceName); two notes say what it does not hide
	local _, hn = row(kit, frame, W.NameHide)
	local nb = button(kit, hn, W.Off, nil, function()
		kit.Fire("SetAnnounceName", kit.Attr("HideAnnounceName", false) ~= true)
	end)
	local notes = Config.Announce and Config.Announce.Text and Config.Announce.Text.SettingNotesEn
	for _, line in type(notes) == "table" and notes or {} do
		kit.Text(frame, "· " .. line, { Size = L.NoteSize, Color = kit.Theme.SubText })
	end
	table.insert(refresh, function() paintToggle(kit, nb, kit.Attr("HideAnnounceName", false) == true) end)

	if kit.Num("VacationDays") > 0 then
		_, h = row(kit, frame, W.Vacation)
		button(kit, h, W.Open, nil, function() kit.Open("Vacation") end, kit.Palette.Free)
	end
	if SettingsUI.NicknameRow(panelsHas("Character"), kit.Num("Level")) then
		_, h = row(kit, frame, W.Nickname)
		button(kit, h, W.Change, nil, function() kit.Open("Nickname") end)
	end

	_, h = row(kit, frame, W.Keys)
	button(kit, h, W.Open, nil, function() SettingsUI.ShowTab("Keys") end)

	-- 효과음 크기 / A23-100 음악 크기: 0 .. 1 in steps of 0.1 (Config.Settings.Defs.Sfx / Music); a click on the
	-- effects row previews the new volume (the music row is heard at once)
	for _, key in { "Sfx", "Music" } do
		local def = Config.Settings.Defs[key]
		if type(def) == "table" then
			local _, hs = row(kit, frame, ST[key .. "En"] or ST[key] or key)
			local function step(dir)
				local v = math.clamp((tonumber(settingsGet(key, 1)) or 1) + dir * def.Step, def.Min, def.Max)
				v = math.floor(v * 10 + 0.5) / 10
				settingsSet(key, v)
				local fx = C and C.Fx
				if key == "Sfx" and type(fx) == "table" and type(fx.PlaySound) == "function" then pcall(fx.PlaySound, "Click") end
			end
			button(kit, hs, "-", L.SmallW, function() step(-1) end)
			local valueBtn = Instance.new("TextLabel")
			valueBtn.Name = "Value"
			valueBtn.BackgroundTransparency = 1
			valueBtn.Size = UDim2.fromOffset(L.SmallW + 16, L.BtnH)
			valueBtn.Font = kit.Theme.Font
			valueBtn.TextSize = L.LabelSize
			valueBtn.TextColor3 = kit.Theme.Text
			valueBtn.LayoutOrder = kit.NextOrder()
			valueBtn.Parent = hs
			button(kit, hs, "+", L.SmallW, function() step(1) end)
			table.insert(refresh, function()
				local v = tonumber(settingsGet(key, 1)) or 1
				valueBtn.Text = string.format(W.SfxValue, math.floor(v * 100 + 0.5))
			end)
		end
	end

	local _, hk = row(kit, frame, ST.ShakeEn or ST.Shake)
	local sb = button(kit, hk, W.On, nil, function() settingsSet("Shake", settingsGet("Shake", true) == false) end)
	table.insert(refresh, function() paintToggle(kit, sb, settingsGet("Shake", true) ~= false) end)

	-- A23-105: rain / snow on or off (WeatherFx; the evening lamps stay - they are light, not an effect)
	local _, hw = row(kit, frame, ST.WeatherEn or ST.Weather)
	local wb = button(kit, hw, W.On, nil, function() settingsSet("Weather", settingsGet("Weather", true) == false) end)
	table.insert(refresh, function() paintToggle(kit, wb, settingsGet("Weather", true) ~= false) end)

	-- A23-65: Camera Follow (turns behind me while I walk) / Free; one button switches
	local _, hc = row(kit, frame, ST.CamEn or ST.Cam)
	local cb = button(kit, hc, "", nil, function()
		settingsSet("Cam", settingsGet("Cam", "Follow") == "Free" and "Follow" or "Free")
	end)
	table.insert(refresh, function()
		local v = settingsGet("Cam", "Follow") == "Free" and "Free" or "Follow"
		cb.Text = ST.Options[v .. "En"] or ST.Options[v] or v
	end)

	if UserInputService.KeyboardEnabled then
		local _, hb = row(kit, frame, ST.KeyBadgesEn or ST.KeyBadges)
		local kb = button(kit, hb, W.On, nil, function() settingsSet("KeyBadges", settingsGet("KeyBadges", true) == false) end)
		table.insert(refresh, function() paintToggle(kit, kb, settingsGet("KeyBadges", true) ~= false) end)
	end

	-- footer: build, place version, server, players; "saving is off" while the server runs without a DataStore
	local foot = kit.Text(frame, "", { Size = L.NoteSize, Color = kit.Theme.SubText, Align = Enum.TextXAlignment.Center })
	local saveOff = kit.Text(frame, W.SaveOff, { Size = L.NoteSize, Color = kit.Theme.Bad, Align = Enum.TextXAlignment.Center })
	table.insert(refresh, function()
		local job = game.JobId ~= "" and string.sub(game.JobId, 1, 8) or W.Studio
		foot.Text = string.format(W.Footer, tostring(Config.BuildLabel), game.PlaceVersion, job, #Players:GetPlayers(),
			Players.MaxPlayers)
		saveOff.Visible = kit.GameAttr("SaveOK") == false
	end)

	return function()
		for _, f in refresh do f() end
	end
end

------------------------------------------------------------------ settings: keys tab
local function fillKeys(kit, frame)
	for _, ch in frame:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	local kb = keybinds()
	if not UserInputService.KeyboardEnabled or not kb then
		kit.Text(frame, W.NoKeyboard, { Size = L.LabelSize })
	else
		kit.Text(frame, W.KeysHint, { Size = L.NoteSize, Color = kit.Theme.SubText })
		for _, group in { "Combat", "Potion", "Window", "Other" } do
			local any = false
			for _, a in KB.Actions do
				if a.Group == group and kb.IsLive(a.Id) then
					if not any then
						header(kit, frame, W.Groups[group] or group)
						any = true
					end
					local _, h = row(kit, frame, a.LabelEn or a.Label)
					local keyBtn
					keyBtn = button(kit, h, keyLabel(a.Id), nil, function()
						if S.Capture == a.Id then
							kb.EndCapture("Cancel")
							return
						end
						S.Capture = a.Id
						keyBtn.Text = W.Press
						local ok = kb.Capture(a.Id, function()
							S.Capture = nil
							-- Set / Swap refill every row through Keybinds.Changed; this one shows its key again
							if keyBtn.Parent then keyBtn.Text = keyLabel(a.Id) end
						end)
						if not ok then
							S.Capture = nil
							keyBtn.Text = keyLabel(a.Id)
						end
					end)
					if kb.KeyName(a.Id) == "" then kit.Paint(keyBtn, kit.Theme.Gold, kit.Palette.DarkText) end
					if a.NoClear ~= true then
						button(kit, h, W.Clear, L.SmallW + 36, function()
							kb.EndCapture("Cancel")
							kb.Clear(a.Id)
						end)
					end
				end
			end
		end
		local reset = Instance.new("Frame")
		reset.BackgroundTransparency = 1
		reset.Size = UDim2.new(1, 0, 0, L.BtnH)
		reset.LayoutOrder = kit.NextOrder()
		local rl = list(reset, 0, true)
		rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		reset.Parent = frame
		button(kit, reset, W.Reset, 220, function()
			kit.Confirm(W.ResetTitle, W.ResetBody, W.ResetOk, function()
				kb.EndCapture("Cancel")
				kb.Reset()
			end)
		end)
	end
	-- A23-21: the pad layout is fixed in the beta (read-only)
	if UserInputService.GamepadEnabled then
		header(kit, frame, W.PadTitle)
		for _, a in KB.Actions do
			if type(a.Pad) == "string" and a.Pad ~= "" and (not kb or kb.IsLive(a.Id)) then
				kit.Text(frame, string.format("%s  ·  %s", a.LabelEn or a.Label, W.Pad[a.Pad] or a.Pad), { Size = L.NoteSize })
			end
		end
	end
end

------------------------------------------------------------------ settings window
local function paintTabs(kit, tabs)
	for id, b in tabs do
		local on = S.Tab == id
		kit.Paint(b, on and kit.Theme.Gold or kit.Palette.Button, on and kit.Palette.DarkText or kit.Theme.Text)
	end
end

local VIEW = { Tabs = nil, Frames = nil, Kit = nil } -- the built window's tab buttons and pages (nil while closed)

function SettingsUI.ShowTab(id)
	if id ~= "Main" and id ~= "Keys" then return end
	S.Tab = id
	if not VIEW.Frames then return end
	local kb = keybinds()
	if id ~= "Keys" and kb and S.Capture then kb.EndCapture("Cancel") end
	for k, f in VIEW.Frames do f.Visible = k == id end
	paintTabs(VIEW.Kit, VIEW.Tabs)
end

local function buildSettings(parent, kit, arg)
	if type(arg) == "table" and arg ~= S.LastArg then
		S.LastArg = arg
		if arg.Tab == "Keys" or arg.Tab == "Main" then S.Tab = arg.Tab end
	end
	local bar = Instance.new("Frame")
	bar.Name = "Tabs"
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, 0, 0, L.TabH)
	local bl = list(bar, 10, true)
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Left
	bar.Parent = parent
	VIEW.Kit = kit
	VIEW.Tabs = {
		Main = kit.Button(bar, W.TabMain, kit.Palette.Button, UDim2.new(0.5, -5, 1, 0), function() SettingsUI.ShowTab("Main") end),
		Keys = kit.Button(bar, W.TabKeys, kit.Palette.Button, UDim2.new(0.5, -5, 1, 0), function() SettingsUI.ShowTab("Keys") end),
	}
	VIEW.Frames = { Main = scroller(parent, "Main"), Keys = scroller(parent, "Keys") }
	local update = buildMain(kit, VIEW.Frames.Main)
	fillKeys(kit, VIEW.Frames.Keys)
	local kb = keybinds()
	if kb and type(kb.Changed) == "table" then
		table.insert(S.Conns, kb.Changed:Connect(function()
			if VIEW.Frames then fillKeys(kit, VIEW.Frames.Keys) end
		end))
	end
	SettingsUI.ShowTab(S.Tab)
	return update
end

local function cleanupSettings()
	local kb = keybinds()
	if kb and S.Capture then kb.EndCapture("Cancel") end
	S.Capture = nil
	disconnectAll()
	VIEW.Tabs, VIEW.Frames, VIEW.Kit = nil, nil, nil
	local st = C and C.Settings
	if type(st) == "table" and type(st.Flush) == "function" then pcall(st.Flush) end
end

------------------------------------------------------------------ help + news
local H = {}

-- the Controls topic from my live keys (touch-only: what the buttons do; a pad: the wired buttons)
function H.ControlLines()
	local help = Config.Help
	local kb = keybinds()
	if not UserInputService.KeyboardEnabled or not kb then return help.TouchLines end
	local lines = {}
	for _, group in { "Combat", "Potion", "Window", "Other" } do
		local parts = {}
		for _, a in KB.Actions do
			if a.Group == group and kb.IsLive(a.Id) and kb.KeyName(a.Id) ~= "" then
				table.insert(parts, string.format("%s %s", a.LabelEn or a.Label, keyLabel(a.Id)))
			end
		end
		if #parts > 0 then table.insert(lines, table.concat(parts, " · ")) end
	end
	table.insert(lines, help.CameraLine)
	if type(help.KeysTip) == "string" then table.insert(lines, help.KeysTip) end -- A23-81: the Lv5 tip again
	return lines
end

function H.Topic(kit, parent, title, lines)
	header(kit, parent, title)
	for _, line in lines do
		kit.Text(parent, "· " .. line, { Size = 18 })
	end
end

-- 'Meet the Guide Again' (BB15): the welcome lines of my side, read-only at any step; the real guide window (with its
-- accept button) only while the first mission was not taken (TutorialStep 0)
function H.BuildGuide(parent, kit)
	local help = Config.Help
	local row1 = Instance.new("Frame")
	row1.BackgroundTransparency = 1
	row1.Size = UDim2.new(1, 0, 0, L.BtnH)
	row1.LayoutOrder = kit.NextOrder()
	local rl = list(row1, 10, true)
	rl.HorizontalAlignment = Enum.HorizontalAlignment.Left
	row1.Parent = parent
	button(kit, row1, help.BackToHelp, 200, function() kit.Rebuild() end)
	local faction = kit.Attr("Faction", "None")
	local def = Config.Tutorial.Welcome[faction] or Config.Tutorial.Welcome.Halo
	header(kit, parent, def.NameEn or def.Name)
	for _, line in def.LinesEn or def.Lines do
		kit.Text(parent, line, { Size = 19 })
	end
	if kit.Num("TutorialStep") == 0 and kit.Attr("ClassChosen", false) == true then
		local row2 = Instance.new("Frame")
		row2.BackgroundTransparency = 1
		row2.Size = UDim2.new(1, 0, 0, L.BtnH)
		row2.LayoutOrder = kit.NextOrder()
		local rl2 = list(row2, 10, true)
		rl2.HorizontalAlignment = Enum.HorizontalAlignment.Center
		row2.Parent = parent
		button(kit, row2, help.TalkToGuide, 260, function() kit.Fire("RequestTutorial") end, kit.Theme.Gold, kit.Palette.DarkText)
	end
end

function H.BuildHelp(parent, kit)
	local help = Config.Help
	if S.Guide then -- one build only: any later rebuild or the next open shows the topics again
		S.Guide = false
		H.BuildGuide(parent, kit)
		return nil
	end
	for _, t in help.Topics do
		H.Topic(kit, parent, t.Title, t.Id == "Controls" and H.ControlLines() or t.Lines)
	end
	local row1 = Instance.new("Frame")
	row1.BackgroundTransparency = 1
	row1.Size = UDim2.new(1, 0, 0, L.BtnH)
	row1.LayoutOrder = kit.NextOrder()
	local rl = list(row1, 10, true)
	rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row1.Parent = parent
	button(kit, row1, help.GuideAgain, 280, function()
		S.Guide = true
		kit.Rebuild()
	end)
	-- A23-81: the keys tip's button again (keyboards): the Settings window on its Keys tab
	if UserInputService.KeyboardEnabled and type(help.KeysButton) == "string" then
		button(kit, row1, help.KeysButton, 200, function() kit.Open("Settings", { Tab = "Keys" }) end)
	end
	return nil
end

-- EG06 Goblin Notes (dev3 easter eggs, 검수 10/10 "News 줄만"): one line under the news, small and in its own colour,
-- new every KST week (Config.GoblinNote(Config.DayIndex(now))); no marker, no '!'
function H.GoblinLine(now)
	local notes, pick, day = Config.GoblinNotes, Config.GoblinNote, Config.DayIndex
	if type(notes) ~= "table" or type(pick) ~= "function" or type(day) ~= "function" then return nil end
	local ok, line = pcall(function() return pick(day(now)) end)
	if not ok or type(line) ~= "string" or line == "" then return nil end
	return (type(notes.Title) == "string" and notes.Title ~= "" and (notes.Title .. ": ") or "") .. line
end

function H.BuildNews(parent, kit)
	local help = Config.Help
	for _, block in help.News do
		H.Topic(kit, parent, block.Title, block.Lines)
	end
	local goblin = H.GoblinLine(os.time())
	if goblin then kit.Text(parent, goblin, { Name = "GoblinNote", Size = L.NoteSize, Color = kit.Theme.Gold or kit.Theme.SubText }) end
	return nil
end

------------------------------------------------------------------ lifecycle
function SettingsUI.Init(registry)
	C = registry
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.Register) ~= "function" then
		Util.Warn(TAG, "Panels.Register is missing; settings / help / news windows are off")
		return
	end
	panels.Register("Settings", {
		Title = W.Title,
		FixedBody = true,
		Rebuild = { VacationDays = true, DataLoaded = true, Level = true }, -- Level: the Nickname row moves to Hero at Lv 2
		Build = buildSettings,
		Cleanup = cleanupSettings,
	})
	if type(Config.Help) == "table" then
		panels.Register("Help", {
			Title = Config.Help.Title,
			Rebuild = { Faction = true, ClassChosen = true },
			Build = H.BuildHelp,
		})
		panels.Register("News", {
			Title = Config.Help.NewsTitle,
			Rebuild = false,
			Build = H.BuildNews,
		})
	end
end

-- A23-105: the saved 'Weather effects' value drives WeatherFx (now, and on every change / the server's first value)
function SettingsUI.ApplyWeather()
	local st, wx = C and C.Settings, C and C.WeatherFx
	if type(st) ~= "table" or type(st.Get) ~= "function" or type(wx) ~= "table" or type(wx.SetEnabled) ~= "function" then
		return false
	end
	local ok, v = pcall(st.Get, "Weather")
	pcall(wx.SetEnabled, not (ok and v == false))
	return true
end

function SettingsUI.Start()
	SettingsUI.ApplyWeather()
	local st = C and C.Settings
	if type(st) == "table" and type(st.Changed) == "table" and type(st.Changed.Connect) == "function" then
		st.Changed:Connect(function() SettingsUI.ApplyWeather() end)
	end
	print("[SettingsUI] started")
end

return SettingsUI
