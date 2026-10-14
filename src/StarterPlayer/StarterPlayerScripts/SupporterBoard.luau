-- SupporterBoard.luau (게임성 개발 1, SPEC A23-75 the VIP pass: "마을 후원자 게시판 이름"): every board part in the world
-- tagged "SupporterBoard" (CollectionService; placed by an Edit tool on a 3D notice board) shows the VIP supporters
-- the server lists in GameState attribute SupporterNames (게임성 개발 2: newline-separated DisplayNames, newest first, at
-- most 30, the same on every server). A SurfaceGui on the part's Front face in the bounty board's look (dark panel,
-- white letters, a gold title - MapBuilder ensureBoardGui), names in columns; it redraws when the list changes and when
-- a board streams in. Nothing to show = a short line inviting nobody to buy (no pressure, A23-75): "Thank you!"
-- Presentation only; the names come from the server.
-- Public API: SupporterBoard.Init(C), SupporterBoard.Start(), SupporterBoard.Names(raw) -> { name } (pure: cleaned,
-- at most Max), SupporterBoard.Rows(names) -> { row text } (three names a row), SupporterBoard.Text(names) -> the rows
-- joined by line breaks (pure; the offline test drives them).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local SupporterBoard = {}
local C = nil
local TAG = "SupporterBoard"

local T = {
	Tag = "SupporterBoard", -- CollectionService tag of the board parts
	Attr = "SupporterNames", -- GameState (dev2)
	Max = 30,
	NameMax = 20, -- characters shown of one name
	Gui = "SupporterGui",
	PPS = 40, -- canvas pixels per stud: the canvas keeps the face's shape (no stretched letters)
	Inset = { L = 0.08, R = 0.14 }, -- share of the width kept free (behind the posts; the right post + lantern hide more, 10/08 photo)
	MinRows = 5, -- a row is 1/max(rows, MinRows) of the names' height: a short list is not huge
	-- game text: English only (A23-48)
	Title = "Thank you, supporters!",
	Empty = "Thank you for playing!",
	Colors = { Panel = Color3.fromRGB(30, 25, 25), Text = Color3.fromRGB(255, 255, 255), Title = Color3.fromRGB(255, 210, 74) },
}
local S = { GameState = nil }

-- the server's list -> clean names (trimmed, no empty lines, no rich-text brackets, at most Max)
function SupporterBoard.Names(raw)
	local out = {}
	if type(raw) ~= "string" then return out end
	for line in string.gmatch(raw, "[^\n]+") do
		local name = string.gsub(string.gsub(line, "^%s+", ""), "%s+$", "")
		name = string.gsub(name, "[<>]", "")
		if name ~= "" then
			if utf8.len(name) and utf8.len(name) > T.NameMax then
				name = string.sub(name, 1, utf8.offset(name, T.NameMax + 1) - 1) .. "…"
			end
			table.insert(out, name)
			if #out >= T.Max then break end
		end
	end
	return out
end

-- the panel rows: the names three to a row, or the plain thank-you line
function SupporterBoard.Rows(names)
	if type(names) ~= "table" or #names == 0 then return { T.Empty } end
	local rows = {}
	for i = 1, #names, 3 do
		local cols = {}
		for j = i, math.min(i + 2, #names) do table.insert(cols, names[j]) end
		table.insert(rows, table.concat(cols, "    "))
	end
	return rows
end

-- the panel text (the rows, one per line)
function SupporterBoard.Text(names)
	return table.concat(SupporterBoard.Rows(names), "\n")
end

local function draw(part)
	if not (typeof(part) == "Instance" and part:IsA("BasePart")) then return end
	local gui = part:FindFirstChild(T.Gui)
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = T.Gui
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = T.PPS
		gui.LightInfluence = 0
		local panel = Instance.new("Frame")
		panel.Name = "Panel"
		panel.Size = UDim2.fromScale(1, 1)
		panel.BackgroundColor3 = T.Colors.Panel
		panel.BorderSizePixel = 0
		panel.Parent = gui
		-- the words keep Inset.L / Inset.R of the width free: the 3D board's posts stand in front of the face's edges
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1 - T.Inset.L - T.Inset.R, 0, 0, 40)
		title.Position = UDim2.new(T.Inset.L, 0, 0, 10)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextScaled = true
		title.TextColor3 = T.Colors.Title
		title.Text = T.Title
		title.Parent = panel
		-- one label per row (10/08: one wrapped label broke the rows, one unwrapped label shrank its lines to dots)
		local body = Instance.new("Frame")
		body.Name = "Names"
		body.Size = UDim2.new(1 - T.Inset.L - T.Inset.R, 0, 1, -66)
		body.Position = UDim2.new(T.Inset.L, 0, 0, 56)
		body.BackgroundTransparency = 1
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Vertical
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = body
		body.Parent = panel
		gui.Parent = part
	end
	local body = gui:FindFirstChild("Names", true)
	if not body then return end
	for _, ch in body:GetChildren() do
		if string.sub(ch.Name, 1, 3) == "Row" then ch:Destroy() end
	end
	local rows = SupporterBoard.Rows(SupporterBoard.Names(S.GameState and S.GameState:GetAttribute(T.Attr)))
	for i, text in rows do
		local row = Instance.new("TextLabel")
		row.Name = "Row" .. i
		row.LayoutOrder = i
		row.Size = UDim2.fromScale(1, 1 / math.max(#rows, T.MinRows))
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextColor3 = T.Colors.Text
		row.AutoLocalize = false -- A23-179: supporters' names stay as they are
		row.Text = text
		row.Parent = body
	end
end

local function redrawAll()
	for _, part in CollectionService:GetTagged(T.Tag) do
		local ok, err = pcall(draw, part)
		if not ok then Util.Warn(TAG, "draw failed: " .. tostring(err)) end
	end
end

function SupporterBoard.Init(registry)
	C = registry
end

function SupporterBoard.Start()
	task.spawn(function()
		local ok, gs = pcall(Net.GameState)
		if not ok or not gs then return end
		S.GameState = gs
		gs:GetAttributeChangedSignal(T.Attr):Connect(redrawAll)
		CollectionService:GetInstanceAddedSignal(T.Tag):Connect(function(part) pcall(draw, part) end)
		redrawAll()
	end)
end

return SupporterBoard
