-- Offline check of UIKit.FitText's pass scheduling (main Play 2026-10-08: "Maximum re-entrancy depth (80) exceeded
-- calling task.defer"). The runner (tools/test_fit_text.py) prepends FIT_SOURCE: UIKit.luau's FIT block and the whole
-- UIKit.FitText function, cut from the CURRENT source. Doubles: a frame / task scheduler that behaves like Roblox's
-- deferred mode (task.defer from inside a deferred resumption runs in the same cycle one level deeper; deeper than 80
-- is the engine's error), task.delay (next frame or later), deferred property-changed signals, a label whose
-- TextBounds follow its TextSize, Heartbeat, os.clock (1/60 s a frame). Every check is named; nothing is asserted.
-- No Studio or Roblox API calls.

local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if not ok then
		failed += 1
		print(("CHECK_FAIL %s :: %s"):format(name, tostring(detail or "")))
	end
end

----------------------------------------------------------------- scheduler doubles
local S = { Frame = 0, Clock = 0, Delayed = {}, Queue = {}, Depth = 0, MaxDepth = 0, Overflow = 0, Heartbeat = {} }
local function runDeferred()
	-- one resumption cycle: items queued while an item runs go one level deeper and run in the same cycle
	local i = 1
	while i <= #S.Queue do
		local item = S.Queue[i]
		i += 1
		if item.Depth > 80 then
			S.Overflow += 1
		else
			local saved = S.Depth
			S.Depth = item.Depth
			S.MaxDepth = math.max(S.MaxDepth, item.Depth)
			local ok, err = pcall(item.Fn, table.unpack(item.Args, 1, item.Args.n))
			if not ok then print("ITEM_ERROR " .. tostring(err)) end
			S.Depth = saved
		end
	end
	S.Queue = {}
end
local function defer(fn, ...)
	table.insert(S.Queue, { Fn = fn, Args = table.pack(...), Depth = S.Depth + 1 })
end
local task = {
	defer = defer,
	delay = function(t, fn, ...)
		table.insert(S.Delayed, { At = S.Clock + math.max(t or 0, 1 / 120), Fn = fn, Args = table.pack(...) })
	end,
	spawn = function(fn, ...) fn(...) end,
}
local function step()
	S.Frame += 1
	S.Clock += 1 / 60
	for _, fn in S.Heartbeat do fn() end
	local due, keep = {}, {}
	for _, d in S.Delayed do
		if d.At <= S.Clock + 1e-9 then table.insert(due, d) else table.insert(keep, d) end
	end
	S.Delayed = keep
	for _, d in due do
		S.Depth = 0
		defer(d.Fn, table.unpack(d.Args, 1, d.Args.n))
		runDeferred()
	end
	S.Depth = 0
	runDeferred()
end

local os = { clock = function() return S.Clock end }
local game = {
	GetService = function(_, name)
		assert(name == "RunService", name)
		return { Heartbeat = { Connect = function(_, fn) table.insert(S.Heartbeat, fn) return {} end } }
	end,
}
local Enum = { TextTruncate = { None = "None" } }
local MIN_TEXT_SIZE = 8
local Art = { TextFits = setmetatable({}, { __mode = "k" }), StyleFloor = {} }
local UIKit = {}
local function inheritedScale() return 1 end
function UIKit.MeasureRenderedText(_, size) return size, size, false, size end

----------------------------------------------------------------- label double
local function newSignal()
	local sig = { Fns = {} }
	function sig:Connect(fn)
		table.insert(self.Fns, fn)
		return { Disconnect = function() end }
	end
	return sig
end
local Vector2 = {}
Vector2.new = function(x, y) return { X = x, Y = y } end

-- props.Width(size) = the text's width at that size; props.Box(size) = the label's box (AutomaticSize-like feedback)
local function newLabel(props)
	local signals = {}
	local data = { TextSize = props.Start or 24, Text = props.Text or "Settings", TextWrapped = false, FontFace = {},
		TextScaled = true, TextTruncate = "AtEnd", ClipsDescendants = false, Parent = {} }
	local label = {}
	local function sig(name)
		signals[name] = signals[name] or newSignal()
		return signals[name]
	end
	local function fire(name)
		for _, fn in sig(name).Fns do defer(fn) end -- deferred signal behaviour
	end
	local function box()
		local w, h = props.Box(data.TextSize)
		return Vector2.new(w, h)
	end
	local meta = {
		__index = function(_, key)
			if key == "AbsoluteSize" then return box() end
			if key == "TextBounds" then return Vector2.new(props.Width(data.TextSize), data.TextSize) end
			if key == "GetPropertyChangedSignal" then return function(_, name) return sig(name) end end
			if key == "Destroying" then return sig("Destroying") end
			if key == "GetAttribute" then return function(_, name) return props.Attrs and props.Attrs[name] end end
			if key == "SetAttribute" then return function() end end
			if key == "FindFirstChild" or key == "FindFirstChildOfClass" then return function() return nil end end
			return data[key]
		end,
		__newindex = function(_, key, value)
			if data[key] == value then return end
			local oldBox = box()
			data[key] = value
			if key == "TextSize" then
				fire("TextSize")
				fire("TextBounds")
				local b = box()
				if b.X ~= oldBox.X or b.Y ~= oldBox.Y then fire("AbsoluteSize") end
			elseif key == "Text" then
				fire("Text")
				fire("TextBounds")
			end
		end,
	}
	setmetatable(label, meta)
	return label, data
end

----------------------------------------------------------------- the code under test
local env = setmetatable({ task = task, os = os, game = game, Enum = Enum, MIN_TEXT_SIZE = MIN_TEXT_SIZE, Art = Art,
	UIKit = UIKit, inheritedScale = inheritedScale, Vector2 = Vector2, math = math, pcall = pcall, type = type,
	tonumber = tonumber, table = table, setmetatable = setmetatable, print = print }, { __index = getfenv() })
local fn = assert(loadstring(FIT_SOURCE))
setfenv(fn, env)
fn()

-- passes are counted by wrapping each label's TextSize writes? simpler: count scheduler items per frame per label
local function framesUntilQuiet(limit)
	local n = 0
	repeat
		step()
		n += 1
	until (#S.Queue == 0 and #S.Delayed == 0) or n >= limit
	return n
end

-- 1. a normal label converges inside its box, no deep defer chain
do
	S.MaxDepth, S.Overflow = 0, 0
	local label, data = newLabel({ Start = 24, Width = function(size) return size * 8 end,
		Box = function() return 100, 30 end })
	UIKit.FitText(label, 8, 24)
	local n = framesUntilQuiet(240)
	check("normal: converges", data.TextSize * 8 <= 100, "size " .. tostring(data.TextSize))
	check("normal: settles within 30 frames", n <= 30, n .. " frames")
	check("normal: no defer overflow", S.Overflow == 0, S.Overflow)
	check("normal: shallow defer chain", S.MaxDepth <= 8, "depth " .. S.MaxDepth)
end

-- 2. a feedback label: its box grows with the text (AutomaticSize-like), so every size change starts a reset
do
	S.MaxDepth, S.Overflow = 0, 0
	local writes, perFrame, worst = 0, {}, 0
	local label, data = newLabel({ Start = 24, Width = function(size) return size * 9 end,
		Box = function(size) return 60 + size * 3, 30 end })
	UIKit.FitText(label, 8, 24)
	local last, lastWrite, longestGap = data.TextSize, S.Frame, 0
	for f = 1, 300 do
		step()
		if data.TextSize ~= last then
			writes += 1
			perFrame[S.Frame] = (perFrame[S.Frame] or 0) + 1
			worst = math.max(worst, perFrame[S.Frame])
			last = data.TextSize
			longestGap = math.max(longestGap, S.Frame - lastWrite)
			lastWrite = S.Frame
		end
	end
	check("feedback: no defer overflow (Roblox's 80-deep limit)", S.Overflow == 0, S.Overflow .. " items over 80")
	check("feedback: the chain stays shallow", S.MaxDepth <= 12, "depth " .. S.MaxDepth)
	check("feedback: at most 2 size writes a frame", worst <= 2, "worst " .. worst)
	check("feedback: it does not run every frame for 5 s", writes <= 200, writes .. " writes in 300 frames")
	-- the burst cap leaves quiet stretches (a capped burst waits for the next second)
	check("feedback: quiet stretches between bursts", longestGap >= 20, "longest quiet run " .. longestGap .. " frames")
	print(("FEEDBACK writes=%d worst=%d longestGap=%d depth=%d"):format(writes, worst, longestGap, S.MaxDepth))
	-- after a capped burst a settle pass still comes (the label is never left at a reset's maximum for good)
	local late = 0
	for _ = 1, 120 do
		local before = data.TextSize
		step()
		if data.TextSize ~= before then late += 1 end
	end
	check("feedback: a later pass still comes after the burst", late > 0, "no pass in 2 s")
end

-- 3. a real change later (new words) fits again
do
	local label, data = newLabel({ Start = 24, Width = function(size) return size * 6 end,
		Box = function() return 120, 30 end })
	UIKit.FitText(label, 8, 24)
	framesUntilQuiet(240)
	label.Text = "Change Class"
	data.Text = "Change Class"
	local wide = function(size) return size * 11 end
	setmetatable(label, getmetatable(label))
	-- the new words are wider: swap the width rule through the double
	local mt = getmetatable(label)
	local oldIndex = mt.__index
	mt.__index = function(t, key)
		if key == "TextBounds" then return Vector2.new(wide(data.TextSize), data.TextSize) end
		return oldIndex(t, key)
	end
	label.Text = "Change Class!"
	framesUntilQuiet(240)
	check("change: refits the wider words", wide(data.TextSize) <= 120, "size " .. tostring(data.TextSize))
end

-- 4. 10/14 (PC tile names): FitMinPx lowers a label's floor under MIN_TEXT_SIZE (the picker minimum 12 is a small
-- window's 9px / UIScale, which MIN_TEXT_SIZE used to cap - the constraint reads it as real px); PickerFitPaddingX keeps a margin
do
	local wide = function(size) return size * 10 end -- needs size <= 5 for a 56 px box less 6 px of margin
	local label, data = newLabel({ Start = 13, Width = wide, Box = function() return 56, 30 end,
		Attrs = { FitMinPx = 4, PickerFitPaddingX = 6 } })
	UIKit.FitText(label, 12, 13)
	framesUntilQuiet(240)
	check("floor: FitMinPx goes under MIN_TEXT_SIZE", data.TextSize < MIN_TEXT_SIZE and wide(data.TextSize) <= 50,
		"size " .. tostring(data.TextSize))
	local fit = Art.TextFits[label]
	check("floor: the picker minimum is the label's floor", fit and fit.Min == 4 and fit.FloorPx == 4, fit and fit.Min)
	local plain, pdata = newLabel({ Start = 13, Width = wide, Box = function() return 56, 30 end })
	UIKit.FitText(plain, 12, 13)
	framesUntilQuiet(240)
	check("floor: without it MIN_TEXT_SIZE stays the floor", pdata.TextSize == MIN_TEXT_SIZE, "size " .. tostring(pdata.TextSize))
	local pad, padData = newLabel({ Start = 13, Width = wide, Box = function() return 104, 30 end,
		Attrs = { FitMinPx = 4, PickerFitPaddingX = 6 } })
	UIKit.FitText(pad, 12, 13)
	framesUntilQuiet(240)
	check("margin: PickerFitPaddingX leaves room inside the box", wide(padData.TextSize) <= 98 and padData.TextSize >= 9,
		"size " .. tostring(padData.TextSize))
end

print(("FIT_SUMMARY checks=%d failed=%d"):format(checks, failed))
