-- BuffBar.luau (게임성 개발 4, 2026-10-12; SPEC A23-133 alchemy tonics, A23-130 no words): the running tonics as small tiles
-- above the HUD's power line, right edge on the MP bar's right edge (the end of the vitals row; UiSandbox 10/12: on the HP
-- bar's edge they hung between the two bars) - the HP bar's without an MP bar (C.HUD.Layout.Rects, the same logical units /
-- root as SkillBar and MiniMap: HUD calls BuffBar.Relayout after each layout pass).
--   tile    : the approved slot art SlotCommon (34 du; BagUI's code fallback without art) with the item icon in its Inner
--             box (Rect(76, 80, 436, 436) of 512), the name's first letter in the item's colour while the icon is not drawn,
--             and under it the time left "m:ss" (UIKit text style Number). NO words.
--   rows    : at most Config.Alchemy.MaxActive tiles, the soonest end first; hidden while none run or Config.Features.Tonics
--             is off (BuffService contract: the player attribute "Buff_<itemId>" = the SERVER time (workspace:GetServerTimeNow())
--             the tonic ends, 0 = not running).
-- Updates: GetAttributeChangedSignal for every Config.Alchemy.Tonics id + one 0.25 s loop for the timers. Start() runs once.
-- Public API: BuffBar.Init(C), BuffBar.Start(), BuffBar.Relayout(), BuffBar.Refresh(),
-- pure: BuffBar.Active(getAttr, now) -> { { Id, Ends, Left } } (soonest first, capped, ended ones dropped), BuffBar.Clock(seconds) -> "m:ss"
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local L10n = require(Shared:WaitForChild("L10n"))

local BuffBar = {}
local C = nil
local TAG = "BuffBar"
local LocalPlayer = Players.LocalPlayer

-- player text: only the clock's shape (A23-111, keys "BuffBar.TXT.<field>"); the bar has no words
local TXT = {
	Clock = "%d:%02d",
}
L10n.Register("BuffBar.TXT", TXT)

local T = {
	Tile = 34, -- du, the slot's side
	Gap = 6, -- du between two tiles
	CapGap = 2, CapH = 14, -- the time under a tile
	Above = 4, -- du above the power line
	Tick = 0.25, -- s between two timer updates
	WarnGap = 10, -- s: one warning line per kind at most this often (게임성 검수 10/12: an error in the loop came 4x a second)
	-- the slot parts' icon box (Config.UIArt SlotCommon ... Inner = Rect(76, 80, 436, 436) of 512), as in BagUI
	Inner = { X = 76 / 512, Y = 80 / 512, W = 360 / 512, H = 356 / 512 },
	Slot = "SlotCommon",
	Fill = Color3.fromRGB(16, 20, 40),
	Rim = Color3.fromRGB(60, 66, 96),
	White = Color3.new(1, 1, 1),
	Z = 2,
}

local S = { Built = false, Sig = nil, Tiles = {}, Anchor = nil, LayoutRef = nil, WarnAt = {} }
local ui = { Holder = nil }

---------------------------------------------------------------------------------------------------- pure helpers
local function num(v, d)
	v = tonumber(v)
	if v == nil or v ~= v or v == math.huge or v == -math.huge then return d end
	return v
end

local function tonicList()
	local a = Config.Alchemy
	return type(a) == "table" and type(a.Tonics) == "table" and a.Tonics or {}
end

local function maxActive()
	local a = Config.Alchemy
	return math.max(0, math.floor(num(type(a) == "table" and a.MaxActive, 2)))
end

-- whole seconds as m:ss: rounded up, never negative ("2:31", "0:45", "0:00")
function BuffBar.Clock(seconds)
	local s = math.max(0, math.ceil(num(seconds, 0)))
	return string.format(TXT.Clock, s // 60, s % 60)
end

-- the running tonics: getAttr(name) -> the attribute value, now = the server time. Soonest end first (a tie: by id), at most
-- MaxActive, ended ones (0 / past) dropped
function BuffBar.Active(getAttr, now)
	local out = {}
	if type(getAttr) ~= "function" then return out end
	local t = num(now, 0)
	for id in tonicList() do
		local ok, v = pcall(getAttr, "Buff_" .. id)
		local ends = ok and num(v, 0) or 0
		if ends > t then table.insert(out, { Id = id, Ends = ends, Left = ends - t }) end
	end
	table.sort(out, function(a, b)
		if a.Ends ~= b.Ends then return a.Ends < b.Ends end
		return a.Id < b.Id
	end)
	local cap = maxActive()
	while #out > cap do table.remove(out) end
	return out
end

local function on()
	return Config.FeatureOn("Tonics") and type(Config.Alchemy) == "table"
end

local function serverNow()
	local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
	return ok and type(t) == "number" and t or os.time()
end

local function tx(t, key)
	local ui2 = C and C.UIKit
	if type(ui2) == "table" and type(ui2.Tx) == "function" then
		local ok, s = pcall(ui2.Tx, t, key)
		if ok and type(s) == "string" then return s end
	end
	local s = t[key .. "En"] or t[key]
	return type(s) == "string" and s or ""
end

---------------------------------------------------------------------------------------------------- drawing
local function clearTiles()
	for _, tile in S.Tiles do
		if tile.Box then tile.Box:Destroy() end
		if tile.Time then tile.Time:Destroy() end
	end
	S.Tiles = {}
end

local function buildTile(entry, index)
	local kit = C.UIKit
	local holder = ui.Holder
	local def = type(Config.Loot) == "table" and Config.Loot.Items and Config.Loot.Items[entry.Id] or nil
	local x = (index - 1) * (T.Tile + T.Gap)
	local grades = type(Config.WeaponGrades) == "table" and Config.WeaponGrades or {}
	local rim = grades.Common and typeof(grades.Common.Color) == "Color3" and grades.Common.Color or T.Rim
	local box = kit.ArtFrame(T.Slot, { Name = "Tile_" .. entry.Id, Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(T.Tile, T.Tile), ZIndex = T.Z, Parent = holder },
		{ BackgroundColor3 = T.Fill, CornerRadius = UDim.new(0, 10), StrokeColor = rim, StrokeThickness = 2 })
	local z = (tonumber(box.ZIndex) or T.Z) + 1
	local props = { Name = "Icon", Position = UDim2.fromScale(T.Inner.X, T.Inner.Y), Size = UDim2.fromScale(T.Inner.W, T.Inner.H),
		ScaleType = Enum.ScaleType.Fit, ZIndex = z }
	local img = kit.ItemIcon(entry.Id, props)
	if img then
		img.Parent = box
	else
		-- the icon art is not drawn yet: the name's first letter in the item's colour (as BagUI's slot())
		local name = type(def) == "table" and tx(def, "Name") or entry.Id
		local letter = Instance.new("TextLabel")
		letter.Name = "Letter"
		letter.BackgroundTransparency = 1
		letter.AnchorPoint = Vector2.new(0.5, 0.5)
		letter.Position = UDim2.fromScale(0.5, 0.5)
		letter.Size = UDim2.fromScale(T.Inner.W, T.Inner.H)
		letter.TextSize = math.floor(T.Tile * 0.42)
		letter.TextWrapped = false
		letter.TextXAlignment = Enum.TextXAlignment.Center
		letter.Text = string.upper(string.match(name, "%w") or "?")
		letter.ZIndex = z
		letter.Parent = box
		if type(kit.StyleText) == "function" then pcall(kit.StyleText, letter, "Number") end
		letter.TextColor3 = (type(def) == "table" and typeof(def.Color) == "Color3") and def.Color or T.White
	end
	local clock = Instance.new("TextLabel")
	clock.Name = "Time_" .. entry.Id
	clock.BackgroundTransparency = 1
	clock.AnchorPoint = Vector2.new(0.5, 0)
	clock.Position = UDim2.fromOffset(x + T.Tile / 2, T.Tile + T.CapGap)
	clock.Size = UDim2.fromOffset(T.Tile + T.Gap, T.CapH)
	clock.TextSize = T.CapH
	clock.TextWrapped = false
	clock.TextXAlignment = Enum.TextXAlignment.Center
	clock.TextColor3 = T.White
	clock.Text = BuffBar.Clock(entry.Left)
	clock.ZIndex = z
	clock.Parent = holder
	if type(kit.StyleText) == "function" then pcall(kit.StyleText, clock, "Number") end
	S.Tiles[entry.Id] = { Box = box, Time = clock }
end

-- the HUD hides its root while a picker / the opening / loading shows: the tiles go with it
local function hudShown()
	local hud = C and C.HUD
	if type(hud) == "table" and type(hud.IsVisible) == "function" then
		local ok, v = pcall(hud.IsVisible)
		return ok and v == true
	end
	return true
end

-- redraws what changed: the tile set (when the running tonics change) and the times
function BuffBar.Refresh()
	if not S.Built or not ui.Holder then return end
	local list = {}
	if on() then
		list = BuffBar.Active(function(name) return LocalPlayer:GetAttribute(name) end, serverNow())
	end
	local ids = {}
	for _, e in list do table.insert(ids, e.Id) end
	local sig = table.concat(ids, ",")
	if sig ~= S.Sig then
		S.Sig = sig
		clearTiles()
		for i, e in list do buildTile(e, i) end
		local n = #list
		ui.Holder.Size = UDim2.fromOffset(math.max(0, n * T.Tile + (n - 1) * T.Gap), T.Tile + T.CapGap + T.CapH)
	end
	for _, e in list do
		local tile = S.Tiles[e.Id]
		local text = BuffBar.Clock(e.Left)
		if tile and tile.Time.Text ~= text then tile.Time.Text = text end
	end
	local show = #list > 0 and S.Anchor ~= nil and hudShown()
	if ui.Holder.Visible ~= show then ui.Holder.Visible = show end
end

-- re-reads C.HUD.Layout.Rects (HUD calls this right after each layout pass): the right edge = the MP bar's right edge
-- (the HP bar's without one), the bottom = 4 du above the power line. No usable rects = hidden
function BuffBar.Relayout()
	if not S.Built or not ui.Holder then return end
	local hud = C and C.HUD
	local layout = type(hud) == "table" and hud.Layout or nil
	S.LayoutRef = layout
	local rects = type(layout) == "table" and type(layout.Rects) == "table" and layout.Rects or nil
	local hp, pl = rects and rects.hp_bar, rects and rects.power_line
	local mp = rects and rects.mp_bar
	local edge = (type(mp) == "table" and tonumber(mp.X) and tonumber(mp.W)) and mp or hp
	if type(edge) == "table" and type(pl) == "table" and tonumber(edge.X) and tonumber(edge.W) and tonumber(pl.Y) then
		S.Anchor = { X = edge.X + edge.W, Y = pl.Y - T.Above }
		ui.Holder.Position = UDim2.fromOffset(S.Anchor.X, S.Anchor.Y)
	else
		S.Anchor = nil
	end
	BuffBar.Refresh()
end

---------------------------------------------------------------------------------------------------- start
-- one warning line per key at most every T.WarnGap s (the loop runs 4x a second)
local function warnOnce(key, msg)
	local now = os.clock()
	if (S.WarnAt[key] or -math.huge) + T.WarnGap > now then return end
	S.WarnAt[key] = now
	Util.Warn(TAG, msg)
end

local function loop()
	while true do
		if not on() then
			-- the switch is off: nothing to read or draw (a row left from before hides; it is built again when on)
			if ui.Holder and ui.Holder.Visible then ui.Holder.Visible = false end
			S.Sig = nil
		else
			local ok, err = pcall(function()
				local hud = C and C.HUD
				local layout = type(hud) == "table" and hud.Layout or nil
				if layout ~= S.LayoutRef then BuffBar.Relayout() end -- a layout made while this was not listening
				BuffBar.Refresh()
			end)
			if not ok then warnOnce("loop", "update error: " .. tostring(err)) end
		end
		task.wait(T.Tick)
	end
end

function BuffBar.Init(registry)
	C = registry
end

function BuffBar.Start()
	if S.Built then return end -- Start() runs once
	local kit = C and C.UIKit
	if type(kit) ~= "table" or not kit.Gui then
		Util.Warn(TAG, "UIKit is not initialized")
		return
	end
	local ok, err = pcall(function()
		local holder = Instance.new("Frame")
		holder.Name = "BuffBar"
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(1, 1)
		holder.Size = UDim2.fromOffset(0, T.Tile + T.CapGap + T.CapH)
		holder.ZIndex = T.Z
		holder.Active = false
		holder.Visible = false
		holder.Parent = kit.Gui
		ui.Holder = holder
		S.Built = true
	end)
	if not ok or not S.Built then
		Util.Warn(TAG, "build failed: " .. tostring(err))
		return
	end
	for id in tonicList() do
		if LocalPlayer then
			LocalPlayer:GetAttributeChangedSignal("Buff_" .. id):Connect(function()
				local okR, errR = pcall(BuffBar.Refresh)
				if not okR then warnOnce("refresh", "refresh error: " .. tostring(errR)) end
			end)
		end
	end
	BuffBar.Relayout()
	task.spawn(loop)
end

-- offline tests
BuffBar._T = { TXT = TXT, T = T, S = S, ui = ui }

return BuffBar
