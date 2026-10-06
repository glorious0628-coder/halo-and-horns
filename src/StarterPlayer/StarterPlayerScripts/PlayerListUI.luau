-- PlayerListUI.luau : our own Tab player list (SPEC A23-26, A23-21 / BB12). Roblox's default list is switched off in
-- Start (T.DisableCoreList) and this overlay replaces it in the top-right corner, right under [메뉴] (A23-40 정정:
-- HUD.Layout.Rects.menu; right under the top bar until the HUD has laid out). Touch-only devices (no keyboard, so no Tab) keep
-- Roblox's list until the phone menu row that calls Toggle() exists (T.PhoneMenuRow; BB12 "폰은 Roblox 상단 목록").
-- Rows come from the server's leaderstats (PlayerService.buildLeaderstats: IntValues named Config.Leaderstats.Names[id]
-- for the ids in Config.Leaderstats.Columns, read by those names, never hard-coded), a faction colour dot (Faction
-- attribute) and the game nickname (Util.PlayerDisplayName: verified Nickname, else DisplayName). The Tab list never
-- hides names (BB37 setting note "같은 서버의 … Tab 목록은 숨길 수 없어요"), so HideAnnounceName does not apply here.
-- Sorted by power, then level, then name; my row has a gold rim on a brighter strip.
-- PC: visible while Tab is HELD (Tab is a Config.Keybinds Reserved key, so it is read from UserInputService directly).
-- Phone (later): a menu row calls PlayerListUI.Toggle() and the list shows a [닫기] pill.
-- Rows refresh at 2 Hz while shown, never while hidden. Display only; the server owns every value.
-- Public: PlayerListUI.Show(on) -> isOpen, PlayerListUI.Toggle() -> isOpen, PlayerListUI.IsOpen().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer

local PlayerListUI = {}

local C = nil -- client registry
local TAG = "PlayerListUI"
local IS_TOUCH = UserInputService.TouchEnabled

-- tuning, logical MainGui units (before its UIScale)
local T = {
	DisableCoreList = true, -- A23-26: Roblox's own player list is off; this list replaces it
	PhoneMenuRow = false, -- true in the same merge as the phone menu row (Toggle); until then touch-only keeps Roblox's list
	CoreTries = 10, -- SetCoreGuiEnabled can fail / be undone in the first frames: retry a few times
	CoreWait = 1,
	Refresh = 0.5, -- 2 Hz while shown
	Z = 80, -- above the HUD (5), Panels (50) and WorldMap (60); below toasts (95) and UIKit.Confirm (100)
	MaxW = 560,
	SideMargin = 20, -- width = min(MaxW, W - 2 * SideMargin)
	TopGap = 8, -- top = [메뉴]'s bottom + TopGap, right edge = [메뉴]'s (A23-40 정정); top-bar inset / scale + TopGap before
	MaxHFrac = 0.65, -- height <= 65% of the screen
	BottomMargin = 16,
	Pad = 18, -- inside the PanelCard rim
	TitleH = IS_TOUCH and 40 or 32,
	HeaderH = 24,
	Gap = 4,
	RowH = IS_TOUCH and 40 or 30, -- touch rows >= 40
	RowGap = 2,
	TitleText = 20,
	HeaderText = 14,
	Text = IS_TOUCH and 17 or 16,
	CellPad = 6, -- left / right margin inside a row
	Dot = 12,
	NameGap = 8, -- between the dot and the name
	ColGap = 6,
	ColW = { Power = 84, Level = 48, Rebirths = 48, Fame = 72, Gold = 84 }, -- unknown ids get ColDefault
	ColDefault = 64,
	PlainCols = { Level = true, Rebirths = true }, -- plain ints; the rest exact with separators (BB12 = HUD number)
	IntMaxLen = 9, -- "1,234,567"; anything longer falls back to Util.FormatNumber (K / M)
	SortBy = { "Power", "Level" }, -- descending, then the name
	ScrollBar = 6,
	CloseW = 72,
	CloseH = IS_TOUCH and 40 or 30,
	ZebraTransparency = 0.94, -- every second row: a faint light strip so long rows stay readable
	MineTransparency = 0.82, -- my row: brighter strip + gold rim
	MineStroke = 2, -- the rim is drawn outside the row: the list pads every side by this so the scroller never clips it
	RowCorner = 8,
}

-- player-facing text (A23-48: English only)
local TXT = {
	Title = "Players %d",
	NameHeader = "Name",
	Missing = "-",
	Close = "Close",
}

-- Columns = { { Id, Name, W } } from Config.Leaderstats; Rows = pooled row widgets (reused on every refresh)
local S = { Open = false, Held = false, Token = 0, Started = false, Columns = {}, Rows = {}, WarnAt = -math.huge }
local ui = {} -- root, title, close, header, headerPad, list, listPad

----------------------------------------------------------------- helpers
local function warnThrottled(msg)
	local now = os.clock()
	if now - S.WarnAt < 10 then return end
	S.WarnAt = now
	Util.Warn(TAG, msg)
end

local function kit()
	local k = C and C.UIKit
	return type(k) == "table" and k or nil
end

local function themeColor(key, fallback)
	local k = kit()
	local c = k and type(k.Theme) == "table" and k.Theme[key]
	return typeof(c) == "Color3" and c or fallback
end

local function artColor(key, fallback)
	local k = kit()
	local c = k and type(k.ArtColors) == "table" and k.ArtColors[key]
	return typeof(c) == "Color3" and c or fallback
end

local function pickersOpen()
	for _, name in { "Intro", "FactionPicker", "ClassPicker" } do
		local m = C and C[name]
		if type(m) == "table" and type(m.IsOpen) == "function" then
			local ok, open = pcall(m.IsOpen)
			if ok and open then return true end
		end
	end
	return false
end

local function canOpen()
	return LocalPlayer:GetAttribute("DataLoaded") == true and not pickersOpen()
end

-- Halo / Horns / Neutral use the faction colours (UIKit.Theme reads them from Config); None and unknown = SubText
local function factionColor(id)
	if id == "Halo" or id == "Horns" or id == "Neutral" then
		local c = themeColor(id, nil)
		if c then return c end
	end
	return themeColor("SubText", Color3.fromRGB(200, 200, 210))
end

-- logical width / height of MainGui and its UIScale; HUD.Layout (read lazily) only while the gui has no size yet
local function view()
	local k = kit()
	local gui = k and k.Gui
	if not gui then return nil end
	local sc = gui:FindFirstChildOfClass("UIScale")
	local s = (sc and sc.Scale > 0) and sc.Scale or 1
	local abs = gui.AbsoluteSize
	if abs.X >= 10 and abs.Y >= 10 then return abs.X / s, abs.Y / s, s end
	local hud = C and C.HUD
	local lay = type(hud) == "table" and hud.Layout or nil
	if type(lay) == "table" and tonumber(lay.W) and tonumber(lay.H) then
		local ls = tonumber(lay.Scale) or s
		return tonumber(lay.W), tonumber(lay.H), ls > 0 and ls or s
	end
	return nil
end

-- top bar inset in real pixels (same fallback as UIKit / HUD, addendum H4)
local function insetY()
	local ok, topLeft = pcall(function()
		return GuiService:GetGuiInset()
	end)
	local y = (ok and typeof(topLeft) == "Vector2") and topLeft.Y or 0
	if y <= 0 then
		local UI = Config.UI or {}
		y = (UI.TopInsetFallback or 64) - (UI.TopInsetPad or 8)
	end
	return y
end

local function buildColumns()
	local LS = type(Config.Leaderstats) == "table" and Config.Leaderstats or {}
	local names = type(LS.Names) == "table" and LS.Names or {}
	local seen = {}
	S.Columns = {}
	for _, id in (type(LS.Columns) == "table" and LS.Columns or {}) do
		if type(id) == "string" and not seen[id] then
			seen[id] = true
			table.insert(S.Columns, { Id = id, Name = tostring(names[id] or id), W = T.ColW[id] or T.ColDefault })
		end
	end
end

-- leaderstats value of one column (nil when the folder / value is missing, e.g. a player still loading)
local function statValue(player, col)
	local folder = player:FindFirstChild("leaderstats")
	local v = folder and folder:FindFirstChild(col.Name)
	if v and v:IsA("ValueBase") then
		local n = tonumber(v.Value)
		if n and n == n and n > -math.huge and n < math.huge then return n end
	end
	return nil
end

-- Level / Rebirths plain; power / fame exact like the HUD's "전투력 25,488" (BB12: the same number), K / M if too long
local function formatValue(col, n)
	if n == nil then return TXT.Missing end
	if T.PlainCols[col.Id] then return tostring(math.floor(n)) end
	local s = Util.FormatInt(n)
	if #s > T.IntMaxLen then s = Util.FormatNumber(n) end
	return s
end

local function snapshot()
	local list = {}
	for _, p in Players:GetPlayers() do
		local ok, name = pcall(Util.PlayerDisplayName, p)
		name = (ok and type(name) == "string" and name ~= "") and name or p.DisplayName
		local e = { Player = p, Name = name, Key = string.lower(name), Faction = p:GetAttribute("Faction"), Values = {} }
		for _, col in S.Columns do
			e.Values[col.Id] = statValue(p, col)
		end
		table.insert(list, e)
	end
	table.sort(list, function(a, b)
		for _, id in T.SortBy do
			local va, vb = a.Values[id] or -1, b.Values[id] or -1
			if va ~= vb then return va > vb end
		end
		if a.Key ~= b.Key then return a.Key < b.Key end
		return a.Player.UserId < b.Player.UserId
	end)
	return list
end

----------------------------------------------------------------- widgets
-- right-aligned value columns (last column at the far right); returns cells by id and the width they take
local function placeColumns(parent, makeCell)
	local cells = {}
	local x = T.CellPad
	for i = #S.Columns, 1, -1 do
		local col = S.Columns[i]
		cells[col.Id] = makeCell(col, UDim2.new(1, -x, 0, 0), UDim2.new(0, col.W, 1, 0), parent)
		x += col.W + T.ColGap
	end
	return cells, x
end

local function nameX()
	return T.CellPad + T.Dot + T.NameGap
end

local function newRow(i)
	local k = kit()
	local row = k.Create("Frame", {
		Name = "Row",
		Size = UDim2.new(1, 0, 0, T.RowH),
		BackgroundColor3 = artColor("Light", Color3.new(1, 1, 1)),
		BackgroundTransparency = 1,
		LayoutOrder = i,
		Parent = ui.list,
	}, {
		{ "UICorner", { CornerRadius = UDim.new(0, T.RowCorner) } },
	})
	local stroke = k.Create("UIStroke", {
		Name = "Mine",
		Color = artColor("Gold", themeColor("Gold", Color3.fromRGB(240, 190, 60))),
		Thickness = T.MineStroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Enabled = false,
		Parent = row,
	})
	local dot = k.Create("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, T.CellPad, 0.5, 0),
		Size = UDim2.fromOffset(T.Dot, T.Dot),
		BackgroundColor3 = factionColor(nil),
		Parent = row,
	}, {
		{ "UICorner", { CornerRadius = UDim.new(0.5, 0) } },
		{ "UIStroke", { Color = artColor("TextOutline", Color3.fromRGB(34, 20, 10)), Thickness = 1 } },
	})
	local cells, used = placeColumns(row, function(_, pos, size, parent)
		return k.LightText({
			AnchorPoint = Vector2.new(1, 0),
			Position = pos,
			Size = size,
			TextSize = T.Text,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = TXT.Missing,
			Number = true,
			Parent = parent,
		})
	end)
	local name = k.LightText({
		Name = "PlayerName",
		Position = UDim2.fromOffset(nameX(), 0),
		Size = UDim2.new(1, -(nameX() + used), 1, 0),
		TextSize = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = row,
	})
	return { Frame = row, Stroke = stroke, Dot = dot, Name = name, Cells = cells }
end

local function fillRow(row, e, i)
	local mine = e.Player == LocalPlayer
	row.Frame.Visible = true
	row.Frame.LayoutOrder = i
	row.Frame.BackgroundTransparency = mine and T.MineTransparency or (i % 2 == 0 and T.ZebraTransparency or 1)
	row.Stroke.Enabled = mine
	row.Dot.BackgroundColor3 = factionColor(e.Faction)
	row.Name.Text = e.Name
	row.Name.TextColor3 = mine and artColor("GoldText", Color3.fromRGB(255, 228, 100)) or artColor("Light", Color3.new(1, 1, 1))
	for _, col in S.Columns do
		local cell = row.Cells[col.Id]
		if cell then cell.Text = formatValue(col, e.Values[col.Id]) end
	end
end

local function build()
	if ui.root and ui.root.Parent then return true end
	local k = kit()
	local gui = k and k.Gui
	if not gui then return false end

	-- approved PanelCard (navy, gold rim); code fallback when its id is missing (IMG-R4)
	local root = k.ArtFrame("PanelCard", {
		Name = "PlayerList",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -T.SideMargin, 0, 140),
		Size = UDim2.fromOffset(T.MaxW, 200),
		ZIndex = T.Z,
		Active = true, -- clicks on the list never reach the world (one-click attack)
		Visible = false,
	}, { CornerRadius = UDim.new(0, 14) })

	local titleRow = k.Create("Frame", {
		Name = "TitleRow",
		Position = UDim2.fromOffset(T.Pad, T.Pad),
		Size = UDim2.new(1, -T.Pad * 2, 0, T.TitleH),
		BackgroundTransparency = 1,
		Parent = root,
	})
	ui.title = k.LightText({
		Name = "Title",
		Size = UDim2.new(1, -(T.CloseW + 8), 1, 0),
		TextSize = T.TitleText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = string.format(TXT.Title, 0),
		Title = true,
		Parent = titleRow,
	})
	-- [닫기] only when opened by Show / Toggle (phone menu row); a held Tab closes on release
	ui.close = k.ArtButton("Pill", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(T.CloseW, T.CloseH),
		Text = TXT.Close,
		TextSize = 16,
		Visible = false,
		Parent = titleRow,
	}, function()
		PlayerListUI.Show(false)
	end)

	local headerTop = T.Pad + T.TitleH + T.Gap
	local header = k.Create("Frame", {
		Name = "Header",
		Position = UDim2.fromOffset(T.Pad, headerTop),
		Size = UDim2.new(1, -T.Pad * 2, 0, T.HeaderH),
		BackgroundTransparency = 1,
		Parent = root,
	})
	-- same left / right inset as the rows (rim room + scroll bar) so the columns stay aligned
	ui.headerPad = k.Create("UIPadding", {
		PaddingLeft = UDim.new(0, T.MineStroke),
		PaddingRight = UDim.new(0, T.MineStroke),
		Parent = header,
	})
	local subColor = artColor("LightSub", themeColor("SubText", Color3.fromRGB(200, 200, 210)))
	local _, used = placeColumns(header, function(col, pos, size, parent)
		return k.LightText({
			Name = col.Id,
			AnchorPoint = Vector2.new(1, 0),
			Position = pos,
			Size = size,
			TextSize = T.HeaderText,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = col.Name,
			Color = subColor,
			Parent = parent,
		})
	end)
	k.LightText({
		Name = "NameHeader",
		Position = UDim2.fromOffset(nameX(), 0),
		Size = UDim2.new(1, -(nameX() + used), 1, 0),
		TextSize = T.HeaderText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = TXT.NameHeader,
		Color = subColor,
		Parent = header,
	})

	local listTop = headerTop + T.HeaderH + T.Gap
	ui.list = k.Create("ScrollingFrame", {
		Name = "Rows",
		Position = UDim2.fromOffset(T.Pad, listTop),
		Size = UDim2.new(1, -T.Pad * 2, 1, -(listTop + T.Pad)),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = T.ScrollBar,
		ScrollBarImageColor3 = artColor("Gold", themeColor("Gold", Color3.fromRGB(240, 190, 60))),
		Parent = root,
	}, {
		{ "UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, T.RowGap) } },
	})
	-- the ScrollingFrame always clips: leave room on every side for my row's gold rim (UIStroke Border draws outside)
	ui.listPad = k.Create("UIPadding", {
		PaddingLeft = UDim.new(0, T.MineStroke),
		PaddingRight = UDim.new(0, T.MineStroke),
		PaddingTop = UDim.new(0, T.MineStroke),
		PaddingBottom = UDim.new(0, T.MineStroke),
		Parent = ui.list,
	})

	ui.root = root
	S.Rows = {}
	root.Parent = gui
	return true
end

----------------------------------------------------------------- layout / refresh
-- centred under the top bar; grows with the rows up to 65% of the screen, then the rows scroll
local function layout()
	local root = ui.root
	if not root then return end
	local W, H, s = view()
	if not W then return end
	local n = 0
	for _, row in S.Rows do
		if row.Frame.Visible then n += 1 end
	end
	local w = math.max(240, math.min(T.MaxW, W - T.SideMargin * 2))
	local top = insetY() / s + T.TopGap
	local right = T.SideMargin
	local hud = C and C.HUD
	local lay = type(hud) == "table" and type(hud.Layout) == "table" and hud.Layout or nil
	local m = lay and type(lay.Rects) == "table" and lay.Rects.menu or nil
	if type(m) == "table" and tonumber(m.Y) and tonumber(m.H) and tonumber(m.X) and tonumber(m.W) then
		top = m.Y + m.H + T.TopGap
		right = math.max(0, W - (m.X + m.W))
	end
	local chrome = T.Pad * 2 + T.TitleH + T.Gap + T.HeaderH + T.Gap
	local rim = T.MineStroke * 2 -- list padding top + bottom (room for my row's rim)
	local contentH = n * T.RowH + math.max(0, n - 1) * T.RowGap + rim
	local maxH = math.max(chrome + T.RowH + rim, math.min(H * T.MaxHFrac, H - top - T.BottomMargin))
	local h = math.min(maxH, chrome + math.max(contentH, T.RowH + rim))
	root.Size = UDim2.fromOffset(math.floor(w), math.floor(h))
	root.Position = UDim2.new(1, -math.floor(right), 0, math.floor(top))
	-- room for the scroll bar only while the rows scroll (never less than the rim); the header follows so the
	-- columns stay aligned
	local inset = UDim.new(0, math.max(T.MineStroke, contentH > h - chrome + 0.5 and T.ScrollBar + 4 or 0))
	ui.listPad.PaddingRight = inset
	ui.headerPad.PaddingRight = inset
end

local function refresh()
	if not S.Open or not ui.root then return end
	if not canOpen() then
		PlayerListUI.Show(false)
		return
	end
	local list = snapshot()
	ui.title.Text = string.format(TXT.Title, #list)
	for i, e in list do
		local row = S.Rows[i]
		if not row then
			row = newRow(i)
			S.Rows[i] = row
		end
		fillRow(row, e, i)
	end
	for i = #list + 1, #S.Rows do
		S.Rows[i].Frame.Visible = false
	end
	layout()
end

----------------------------------------------------------------- public
-- on = true opens (refused before DataLoaded / while a picker is open), false closes. Returns IsOpen().
function PlayerListUI.Show(on)
	if on ~= true then
		S.Held = false
		if not S.Open then return false end
		S.Open = false
		S.Token += 1 -- ends the refresh loop
		if ui.root then ui.root.Visible = false end
		return false
	end
	if not canOpen() then return S.Open end
	local okBuild, built = pcall(build)
	if not okBuild or not built then
		if not okBuild then warnThrottled("build failed: " .. tostring(built)) end
		return false
	end
	if ui.close then ui.close.Visible = not S.Held end
	if S.Open then return true end
	S.Open = true
	S.Token += 1
	local token = S.Token
	local ok, err = pcall(refresh)
	if not ok then warnThrottled("refresh error: " .. tostring(err)) end
	if not S.Open then return false end -- refresh may close it again
	ui.root.Visible = true
	task.spawn(function()
		while S.Open and S.Token == token do
			task.wait(T.Refresh)
			if not (S.Open and S.Token == token) then break end
			local okTick, errTick = pcall(refresh)
			if not okTick then warnThrottled("refresh error: " .. tostring(errTick)) end
		end
	end)
	return true
end

function PlayerListUI.Toggle()
	return PlayerListUI.Show(not S.Open)
end

function PlayerListUI.IsOpen()
	return S.Open
end

----------------------------------------------------------------- input
local function typing()
	if UserInputService:GetFocusedTextBox() ~= nil then return true end
	local kb = C and C.Keybinds
	if type(kb) == "table" and type(kb.IsCapturing) == "function" then
		local ok, capturing = pcall(kb.IsCapturing)
		if ok and capturing then return true end
	end
	return false
end

-- gameProcessed is not checked on purpose: Roblox may mark Tab processed (its own list binding), which would keep
-- this list shut. A focused TextBox (chat, settings) and the Esc menu still block it.
local function onInputBegan(input)
	if input.KeyCode ~= Enum.KeyCode.Tab or typing() then return end
	local menuOk, menuOpen = pcall(function()
		return GuiService.MenuIsOpen
	end)
	if menuOk and menuOpen then return end
	S.Held = true
	if not PlayerListUI.Show(true) then S.Held = false end
end

local function onInputEnded(input)
	if input.KeyCode ~= Enum.KeyCode.Tab then return end
	if S.Held then PlayerListUI.Show(false) end
end

-- A23-26: hide Roblox's player list (retried: the call can fail or be ignored while the CoreGui is still loading).
-- A touch-only device has no Tab key: it keeps Roblox's list until the phone menu row can open ours (T.PhoneMenuRow).
local function disableCoreList()
	if T.DisableCoreList ~= true then return end
	if IS_TOUCH and not UserInputService.KeyboardEnabled and T.PhoneMenuRow ~= true then return end
	task.spawn(function()
		for _ = 1, T.CoreTries do
			local ok = pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
			local okGet, enabled = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList)
			if ok and okGet and enabled == false then return end
			task.wait(T.CoreWait)
		end
		warnThrottled("could not hide the Roblox player list")
	end)
end

----------------------------------------------------------------- lifecycle
function PlayerListUI.Init(registry)
	C = registry
	buildColumns()
	local ok, err = pcall(build) -- UIKit.Init ran earlier (ORDER); Show() builds it later otherwise
	if not ok then warnThrottled("build failed: " .. tostring(err)) end
end

function PlayerListUI.Start()
	if S.Started then return end
	S.Started = true
	disableCoreList()

	UserInputService.InputBegan:Connect(function(input)
		local ok, err = pcall(onInputBegan, input)
		if not ok then warnThrottled("input error: " .. tostring(err)) end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local ok, err = pcall(onInputEnded, input)
		if not ok then warnThrottled("input error: " .. tostring(err)) end
	end)
	-- Tab released while the window was in the background never arrives
	UserInputService.WindowFocusReleased:Connect(function()
		PlayerListUI.Show(false)
	end)
	pcall(function()
		GuiService.MenuOpened:Connect(function()
			PlayerListUI.Show(false)
		end)
	end)

	-- follow viewport / UIScale changes while shown (rows themselves refresh in the 2 Hz loop)
	local k = kit()
	local gui = k and k.Gui
	if gui then
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if S.Open then pcall(layout) end
		end)
	end

	print("[PlayerListUI] started")
end

return PlayerListUI
