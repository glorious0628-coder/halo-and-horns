-- StickerUI.luau : A23-143 chat stickers, the client side (게임성 개발 1; the server is 게임성 개발 2's MonetizationService).
-- A sticker = a picture over my head that everyone sees for Config.Stickers.Seconds (no text typed). The picker (key V,
-- Config.Keybinds "Stickers"; a phone button comes with the phone round A23-145) shows Config.Stickers.Order as art cells
-- (Config.UIArt.Parts Emo*, SlotCommon frames): the free ones (Config.StickerFree) always bright; the others need the
-- Sticker Pack pass (my PassStickers attribute) - locked = dimmed + IconLock, a press opens the Shop instead. A press on
-- an open one fires SendSticker(key) once (at most every Config.RateLimits.SendSticker s, checked here first: the server
-- drops anything else without a word) and closes the picker. The server's Fx "Sticker" { UserId, Key } draws the art over
-- that player's head (one at a time per player: a new one replaces it), a short pop in, a fade out. No words, no tips
-- (A23-130); only approved parts + UIKit fallbacks. Pure helpers (Rows, CanSend) are tested offline (tools/test_sticker_ui.py).
-- A23-144 (최종 검수 10/13): under the stickers, one row of chat bubble skins (BubbleUI.MyRows: my side's free one + the
-- pack's) - the worn one framed (Worn), a locked one dimmed with IconLock (a press opens the Shop), else BubbleUI.Pick.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local StickerUI = {}
local C = nil
local TAG = "StickerUI"
local LocalPlayer = Players.LocalPlayer

-- look and rules (du = MainGui units)
local L = {
	Action = "Stickers", -- Config.Keybinds id
	Remote = "SendSticker",
	Cols = 6, Cell = 58, Gap = 6, Pad = 12,
	Bottom = 150, -- the picker's bottom above the screen's bottom (over the skill bar)
	LockedFade = 0.5, -- a locked sticker's art transparency
	LockSize = 0.42, -- the lock badge (share of a cell), its upper right
	Head = { Size = 3, Up = 2.6, Range = 90 }, -- over-head: studs wide, studs over the head's centre, seen from
	Pop = 0.18, Fade = 0.35, -- s
	GapPad = 0.15, -- s over the server's rate limit
	BubbleGap = 14, -- du between the stickers and the bubble row
	WornColor = Color3.fromRGB(255, 214, 110), WornThick = 3, -- the worn bubble's frame
}
local S = { Open = false, LastAt = -math.huge, Gui = nil, Cells = {}, Heads = {} } -- Heads[userId] = { Gui, Token }

---------------------------------------------------------------------------------------------------- pure
-- the picker's rows: every sticker in order, { Key, Free, Locked } (locked = not free and no pass)
function StickerUI.Rows(hasPass)
	local rows = {}
	local order = type(Config.Stickers) == "table" and Config.Stickers.Order or {}
	for _, key in order do
		local free = type(Config.StickerFree) == "function" and Config.StickerFree(key) == true
		table.insert(rows, { Key = key, Free = free, Locked = not free and hasPass ~= true })
	end
	return rows
end

-- can I send this sticker now? ctx = { Pass, Now, LastAt, Alive }
function StickerUI.CanSend(key, ctx)
	ctx = type(ctx) == "table" and ctx or {}
	if type(Config.IsSticker) ~= "function" or not Config.IsSticker(key) then return false end
	if not (Config.StickerFree(key) or ctx.Pass == true) then return false end
	if ctx.Alive == false then return false end
	local gap = tonumber(type(Config.RateLimits) == "table" and Config.RateLimits.SendSticker) or 2
	return (tonumber(ctx.Now) or 0) - (tonumber(ctx.LastAt) or -math.huge) >= gap + L.GapPad
end

---------------------------------------------------------------------------------------------------- send
local function hasPass()
	local attr = type(Config.GamePasses) == "table" and type(Config.GamePasses.Stickers) == "table" and Config.GamePasses.Stickers.Attr
		or "PassStickers"
	return LocalPlayer:GetAttribute(attr) == true
end

function StickerUI.Send(key)
	local okA, alive = pcall(Util.IsAlive, LocalPlayer)
	local now = os.clock()
	if not StickerUI.CanSend(key, { Pass = hasPass(), Now = now, LastAt = S.LastAt, Alive = not okA or alive ~= false }) then
		return false
	end
	local ok = pcall(function() Net.Get(L.Remote):FireServer(key) end)
	if ok then S.LastAt = now end
	return ok
end

---------------------------------------------------------------------------------------------------- over the head
local function headOf(userId)
	local p = Players:GetPlayerByUserId(userId)
	local ch = p and p.Character
	return ch and (ch:FindFirstChild("Head") or ch:FindFirstChild("HumanoidRootPart")) or nil
end

function StickerUI.Show(userId, key)
	local kit = C and C.UIKit
	local head = headOf(userId)
	if not (head and type(kit) == "table" and type(kit.ArtImage) == "function") then return false end
	local rec = S.Heads[userId]
	if rec and rec.Gui then pcall(function() rec.Gui:Destroy() end) end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PlayerSticker"
	gui.Size = UDim2.fromScale(L.Head.Size, L.Head.Size)
	gui.StudsOffsetWorldSpace = Vector3.new(0, L.Head.Up, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = L.Head.Range
	gui.AlwaysOnTop = false
	gui.Adornee = head
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = holder
	local img = kit.ArtImage(key, { Name = "Art", Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Fit })
	if not img then
		gui:Destroy()
		return false
	end
	img.Parent = holder
	gui.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local token = (rec and rec.Token or 0) + 1
	S.Heads[userId] = { Gui = gui, Token = token }
	pcall(function()
		TweenService:Create(scale, TweenInfo.new(L.Pop, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	local secs = tonumber(type(Config.Stickers) == "table" and Config.Stickers.Seconds) or 3
	task.delay(secs, function()
		local now = S.Heads[userId]
		if not now or now.Token ~= token then return end
		pcall(function()
			TweenService:Create(img, TweenInfo.new(L.Fade), { ImageTransparency = 1 }):Play()
		end)
		task.delay(L.Fade, function()
			local still = S.Heads[userId]
			if still and still.Token == token then
				S.Heads[userId] = nil
				pcall(function() gui:Destroy() end)
			end
		end)
	end)
	return true
end

---------------------------------------------------------------------------------------------------- the picker
local function closePicker()
	S.Open = false
	if S.Gui then S.Gui.Visible = false end
end

local function openShop()
	local panels = C and C.Panels
	if type(panels) == "table" and type(panels.Open) == "function" then pcall(panels.Open, "Shop") end
end

local function bubbleUI()
	local b = C and C.BubbleUI
	return (type(b) == "table" and type(b.MyRows) == "function") and b or nil
end

local function paint()
	local pass = hasPass()
	for _, row in StickerUI.Rows(pass) do
		local cell = S.Cells[row.Key]
		if cell then
			if cell.Art then cell.Art.ImageTransparency = row.Locked and L.LockedFade or 0 end
			if cell.Lock then cell.Lock.Visible = row.Locked end
			cell.Locked = row.Locked
		end
	end
	local b = bubbleUI()
	local ok, rows = pcall(function() return b and b.MyRows() or {} end)
	for _, row in ok and rows or {} do
		local cell = S.Bubbles and S.Bubbles[row.Key]
		if cell then
			if cell.Art then
				if cell.Art:IsA("ImageLabel") then cell.Art.ImageTransparency = row.Locked and L.LockedFade or 0
				else cell.Art.BackgroundTransparency = row.Locked and L.LockedFade or 0 end
			end
			if cell.Lock then cell.Lock.Visible = row.Locked end
			if cell.Worn then cell.Worn.Enabled = row.Worn == true end
			cell.Locked = row.Locked
		end
	end
end

local function buildPicker()
	local kit = C and C.UIKit
	if type(kit) ~= "table" or not kit.Gui then return nil end
	local rows = StickerUI.Rows(hasPass())
	local cols = L.Cols
	local lines = math.ceil(#rows / cols)
	local b = bubbleUI()
	local okB, bubbles = pcall(function() return b and b.MyRows() or {} end)
	bubbles = okB and bubbles or {}
	local bcols = math.max(cols, #bubbles)
	local w = L.Pad * 2 + bcols * L.Cell + (bcols - 1) * L.Gap
	local h = L.Pad * 2 + lines * L.Cell + (lines - 1) * L.Gap + (#bubbles > 0 and (L.BubbleGap + L.Cell) or 0)
	local panel = kit.ArtFrame("PanelCard", {
		Name = "StickerPicker", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -L.Bottom),
		Size = UDim2.fromOffset(w, h), Visible = false, ZIndex = 40,
	}, { BackgroundColor3 = Color3.fromRGB(28, 32, 52), BackgroundTransparency = 0.1 })
	panel.Parent = kit.Gui
	for i, row in rows do
		local col, line = (i - 1) % cols, (i - 1) // cols
		local key = row.Key
		local btn = kit.ArtButton("SlotCommon", {
			Name = "Sticker_" .. key, Position = UDim2.fromOffset(L.Pad + col * (L.Cell + L.Gap), L.Pad + line * (L.Cell + L.Gap)),
			Size = UDim2.fromOffset(L.Cell, L.Cell), ZIndex = 41,
		}, function()
			local cell = S.Cells[key]
			if cell and cell.Locked then
				closePicker()
				openShop()
				return
			end
			if StickerUI.Send(key) then closePicker() end
		end, { BackgroundColor3 = Color3.fromRGB(46, 52, 80) })
		btn.Parent = panel
		local art = kit.ArtImage(key, { Name = "Art", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.82, 0.82), ScaleType = Enum.ScaleType.Fit, ZIndex = 42 })
		if art then art.Parent = btn end
		local lock = kit.ArtImage("IconLock", { Name = "Lock", AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.78, 0.22), Size = UDim2.fromScale(L.LockSize, L.LockSize), ZIndex = 43, Visible = false })
		if lock then lock.Parent = btn end
		S.Cells[key] = { Button = btn, Art = art, Lock = lock, Locked = row.Locked }
	end
	-- A23-144: the bubble row (art when uploaded, else the skin's colour as a small rounded bubble)
	S.Bubbles = {}
	local top = L.Pad + lines * L.Cell + (lines - 1) * L.Gap + L.BubbleGap
	for i, row in bubbles do
		local key = row.Key
		local btn = kit.ArtButton("SlotCommon", {
			Name = "Bubble_" .. key, Position = UDim2.fromOffset(L.Pad + (i - 1) * (L.Cell + L.Gap), top),
			Size = UDim2.fromOffset(L.Cell, L.Cell), ZIndex = 41,
		}, function()
			local cell = S.Bubbles[key]
			if cell and cell.Locked then
				closePicker()
				openShop()
				return
			end
			local ok, sent = pcall(b.Pick, key)
			if ok and sent then closePicker() end
		end, { BackgroundColor3 = Color3.fromRGB(46, 52, 80) })
		btn.Parent = panel
		local art = kit.ArtImage(key, { Name = "Art", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.78, 0.6), ScaleType = Enum.ScaleType.Fit, ZIndex = 42 })
		if not art and type(b.LookOf) == "function" then
			local look = b.LookOf(key)
			art = Instance.new("Frame")
			art.Name = "Art"
			art.AnchorPoint = Vector2.new(0.5, 0.5)
			art.Position = UDim2.fromScale(0.5, 0.5)
			art.Size = UDim2.fromScale(0.72, 0.48)
			art.BackgroundColor3 = look and look.Bg or Color3.new(1, 1, 1)
			art.ZIndex = 42
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.35, 0)
			corner.Parent = art
		end
		if art then art.Parent = btn end
		local lock = kit.ArtImage("IconLock", { Name = "Lock", AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.78, 0.22), Size = UDim2.fromScale(L.LockSize, L.LockSize), ZIndex = 43, Visible = false })
		if lock then lock.Parent = btn end
		local worn = Instance.new("UIStroke")
		worn.Name = "Worn"
		worn.Color = L.WornColor
		worn.Thickness = L.WornThick
		worn.Enabled = row.Worn == true
		worn.Parent = btn
		S.Bubbles[key] = { Button = btn, Art = art, Lock = lock, Worn = worn, Locked = row.Locked }
	end
	return panel
end

function StickerUI.Toggle()
	if S.Open then
		closePicker()
		return false
	end
	if not S.Gui then
		local ok, gui = pcall(buildPicker)
		if not ok then Util.Warn(TAG, "picker build failed: " .. tostring(gui)) end
		S.Gui = ok and gui or nil
	end
	if not S.Gui then return false end
	paint()
	S.Open = true
	S.Gui.Visible = true
	return true
end

function StickerUI.IsOpen()
	return S.Open
end

---------------------------------------------------------------------------------------------------- lifecycle
function StickerUI.Init(registry)
	C = registry
end

function StickerUI.Start()
	pcall(function()
		Net.Get("Fx").OnClientEvent:Connect(function(kind, data)
			if kind ~= "Sticker" or type(data) ~= "table" then return end
			if type(data.UserId) ~= "number" or not (type(Config.IsSticker) == "function" and Config.IsSticker(data.Key)) then return end
			pcall(StickerUI.Show, data.UserId, data.Key)
		end)
	end)
	local keys = C and C.Keybinds
	if type(keys) == "table" and type(keys.Began) == "table" then
		keys.Began:Connect(function(input, processed)
			if processed or keys.IsCapturing() or UserInputService:GetFocusedTextBox() then return end
			if keys.ActionFor(input) == L.Action then pcall(StickerUI.Toggle) end
		end)
	end
	-- the pass bought while the picker is open: unlock at once
	local attr = type(Config.GamePasses) == "table" and type(Config.GamePasses.Stickers) == "table" and Config.GamePasses.Stickers.Attr
		or "PassStickers"
	LocalPlayer:GetAttributeChangedSignal(attr):Connect(function()
		if S.Gui then pcall(paint) end
	end)
	for _, a in { "PassBubbles", "BubbleOn" } do -- A23-144: the bubble pack bought / my skin changed
		LocalPlayer:GetAttributeChangedSignal(a):Connect(function()
			if S.Gui then pcall(paint) end
		end)
	end
	Players.PlayerRemoving:Connect(function(p)
		local rec = S.Heads[p.UserId]
		if rec and rec.Gui then pcall(function() rec.Gui:Destroy() end) end
		S.Heads[p.UserId] = nil
	end)
end

-- offline tests
StickerUI._T = { L = L, S = S }

return StickerUI
