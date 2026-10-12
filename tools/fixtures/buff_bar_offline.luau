-- Alchemy buff row (게임성 개발 4, 2026-10-12): runs the real Config.luau and the real BuffBar.luau (tools/test_buff_bar.py) on
-- small doubles: Players.LocalPlayer attributes + attribute signals, a recording Instance tree, UIKit art doubles, a fake
-- HUD.Layout, task.spawn / task.wait. Inputs: CONFIG_SOURCE, BUFF_SOURCE. Every check is named.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then
		print("CHECK_OK " .. name)
	else
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end

local vmt = {}
vmt.__index = vmt
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vmt) end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local base = { Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec },
	Color3 = { new = vec, fromRGB = vec, fromHSV = vec }, BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"),
	UDim2 = ctor("UDim2"), UDim = ctor("UDim"), NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"),
	ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"),
	Font = ctor("Font"), Enum = enum }
local cfgEnv = setmetatable(table.clone(base), { __index = getfenv() })
cfgEnv.workspace = { GetServerTimeNow = function() return 1790000000 end }
local fn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(fn, cfgEnv)
local Config = fn()

------------------------------------------------------------------ an Instance tree double
local omt = {}
local function newObj(class, props)
	local o = setmetatable({ __p = { ClassName = class, Name = class, Children = {}, ZIndex = 1, Visible = true } }, omt)
	for k, v in props or {} do o[k] = v end
	return o
end
omt.__index = function(o, k)
	local methods = {
		GetChildren = function(self) return table.clone(rawget(self, "__p").Children) end,
		Destroy = function(self)
			local p = rawget(self, "__p")
			if p.Parent then
				local kids = rawget(p.Parent, "__p").Children
				local i = table.find(kids, self)
				if i then table.remove(kids, i) end
			end
			p.Parent = nil
			p.Destroyed = true
		end,
		FindFirstChild = function(self, name)
			for _, ch in rawget(self, "__p").Children do if ch.Name == name then return ch end end
			return nil
		end,
	}
	if methods[k] then return methods[k] end
	return rawget(o, "__p")[k]
end
omt.__newindex = function(o, k, v)
	local p = rawget(o, "__p")
	if k == "Parent" then
		if p.Parent then
			local kids = rawget(p.Parent, "__p").Children
			local i = table.find(kids, o)
			if i then table.remove(kids, i) end
		end
		p.Parent = v
		if v then table.insert(rawget(v, "__p").Children, o) end
		return
	end
	p[k] = v
end
local function descendants(root, out)
	out = out or {}
	for _, ch in rawget(root, "__p").Children do
		table.insert(out, ch)
		descendants(ch, out)
	end
	return out
end
local function find(root, name)
	for _, d in descendants(root) do if d.Name == name then return d end end
	return nil
end
local function findAll(root, pat)
	local out = {}
	for _, d in descendants(root) do
		if type(d.Name) == "string" and string.find(d.Name, pat) then table.insert(out, d) end
	end
	return out
end

------------------------------------------------------------------ doubles
local NOW = 1000
local attrs = {}
local sigFns = {} -- [attribute name] = { fn, ... }
local sigNames = {}
local player = {
	GetAttribute = function(_, k) return attrs[k] end,
	GetAttributeChangedSignal = function(_, name)
		table.insert(sigNames, name)
		return { Connect = function(_, f)
			sigFns[name] = sigFns[name] or {}
			table.insert(sigFns[name], f)
			return { Disconnect = function() end }
		end }
	end,
}
local function fire(name)
	for _, f in sigFns[name] or {} do f() end
end
local warns = 0
local Util = { Warn = function(...) warns += 1 print("WARN", ...) end }
local L10nReg = {}
local L10n = { Register = function(path, t) L10nReg[path] = t return t end }
local shared = { WaitForChild = function(_, n) return n end }
local RS = { WaitForChild = function() return shared end }
local game = { GetService = function(_, n)
	if n == "Players" then return { LocalPlayer = player } end
	if n == "ReplicatedStorage" then return RS end
	return nil
end }
local mods = { Config = Config, Util = Util, L10n = L10n }

local spawned, waits, waitLimit = {}, {}, 2
local env = setmetatable(table.clone(base), { __index = getfenv() })
env.game, env.Instance = game, { new = function(c) return newObj(c) end }
env.require = function(n) return mods[n] end
env.workspace = { GetServerTimeNow = function() return NOW end }
local CLOCK = 1000
env.os = setmetatable({ clock = function() return CLOCK end }, { __index = os })
env.typeof = function(v)
	if getmetatable(v) == vmt then return "Color3" end
	return typeof(v)
end
env.task = {
	spawn = function(f, ...) table.insert(spawned, f) end,
	wait = function(t)
		table.insert(waits, t)
		if #waits >= waitLimit then error("stop the loop") end
		return t
	end,
}
local bf = assert(loadstring(BUFF_SOURCE, "=BuffBar"))
setfenv(bf, env)
local BuffBar = bf()
local T = BuffBar._T

local function artObj(class, name, props)
	local o = newObj(class, { Image = name })
	for k, v in props or {} do
		if k ~= "Parent" then o[k] = v end
	end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end
local artReady = false -- true: the item icons are drawn
local gui = newObj("Frame", { Name = "MainGui" })
local UIKit = {
	Gui = gui,
	ArtFrame = function(name, props, fb)
		local o = artObj("Frame", name, props)
		o.Fallback = fb
		return o
	end,
	ItemIcon = function(id, props)
		if not artReady then return nil end
		local o = artObj("ImageLabel", "Icon:" .. tostring(id), props)
		o.ItemId = id
		return o
	end,
	StyleText = function(l, style) l.Style = style end,
	Tx = function(t, key)
		local s = t[key .. "En"] or t[key]
		return type(s) == "string" and s or ""
	end,
}
local HUD = {
	Layout = { Rects = { hp_bar = { X = 100, Y = 500, W = 184, H = 20 }, power_line = { X = 100, Y = 470, W = 375, H = 16 } } },
	IsVisible = function() return true end,
}
local registry = { UIKit = UIKit, HUD = HUD }

------------------------------------------------------------------ 0. words and registration
check(L10nReg["BuffBar.TXT"] == T.TXT, "the text table is registered (L10n BuffBar.TXT)")
local keys = 0
for _ in T.TXT do keys += 1 end
check(keys == 1 and T.TXT.Clock == "%d:%02d", "no words: the one text is the clock's shape (A23-130)", keys)

------------------------------------------------------------------ 1. Clock
check(BuffBar.Clock(151) == "2:31", "Clock(151) = 2:31", BuffBar.Clock(151))
check(BuffBar.Clock(44.2) == "0:45", "Clock rounds up: 44.2 s = 0:45", BuffBar.Clock(44.2))
check(BuffBar.Clock(180) == "3:00", "Clock(180) = 3:00", BuffBar.Clock(180))
check(BuffBar.Clock(59.01) == "1:00", "Clock(59.01) = 1:00", BuffBar.Clock(59.01))
check(BuffBar.Clock(0) == "0:00" and BuffBar.Clock(-5) == "0:00" and BuffBar.Clock(nil) == "0:00", "never negative: 0, -5, nil = 0:00",
	BuffBar.Clock(-5))
check(BuffBar.Clock(0.001) == "0:01", "a sliver of a second is still 0:01", BuffBar.Clock(0.001))
check(BuffBar.Clock(605) == "10:05", "seconds are two digits (10:05)", BuffBar.Clock(605))

------------------------------------------------------------------ 2. Active
local function getter(t) return function(name) return t[name] end end
local function ids(list)
	local out = {}
	for _, e in list do table.insert(out, e.Id) end
	return table.concat(out, ",")
end
check(#BuffBar.Active(getter({}), NOW) == 0, "nothing running = an empty list")
check(#BuffBar.Active(getter({ Buff_MightTonic = 0, Buff_GuardTonic = 0 }), NOW) == 0, "0 = not running")
check(#BuffBar.Active(nil, NOW) == 0, "no getter = an empty list")
local list = BuffBar.Active(getter({ Buff_MightTonic = NOW + 100, Buff_GuardTonic = NOW + 50 }), NOW)
check(ids(list) == "GuardTonic,MightTonic", "the soonest end first", ids(list))
check(list[1].Ends == NOW + 50 and list[1].Left == 50 and list[2].Left == 100, "Ends and Left (seconds) are given", list[1].Left)
list = BuffBar.Active(getter({ Buff_MightTonic = NOW + 100, Buff_GuardTonic = NOW + 50, Buff_LuckyTonic = NOW + 75, Buff_WisdomTonic = NOW + 10 }), NOW)
check(ids(list) == "WisdomTonic,GuardTonic", "at most MaxActive (2): the two soonest", ids(list))
list = BuffBar.Active(getter({ Buff_MightTonic = NOW - 1, Buff_GuardTonic = NOW, Buff_LuckyTonic = NOW + 5 }), NOW)
check(ids(list) == "LuckyTonic", "ended ones (past, or this very second) are dropped", ids(list))
list = BuffBar.Active(getter({ Buff_MightTonic = NOW + 40, Buff_LuckyTonic = NOW + 40 }), NOW)
check(ids(list) == "LuckyTonic,MightTonic", "the same end: by id (a steady order)", ids(list))
list = BuffBar.Active(getter({ Buff_MightTonic = "soon", Buff_GuardTonic = true, Buff_LuckyTonic = NOW + 5 }), NOW)
check(ids(list) == "LuckyTonic", "an attribute that is no number counts as not running", ids(list))
list = BuffBar.Active(getter({ Buff_Nope = NOW + 5, Buff_MightTonic = NOW + 9 }), NOW)
check(ids(list) == "MightTonic", "only Config.Alchemy.Tonics ids", ids(list))
Config.Alchemy.MaxActive = 3
list = BuffBar.Active(getter({ Buff_MightTonic = NOW + 100, Buff_GuardTonic = NOW + 50, Buff_LuckyTonic = NOW + 75, Buff_WisdomTonic = NOW + 10 }), NOW)
check(#list == 3, "the cap follows Config.Alchemy.MaxActive", #list)
Config.Alchemy.MaxActive = 2

------------------------------------------------------------------ 3. start, hidden, tiles
BuffBar.Init(registry)
BuffBar.Start()
local holder = find(gui, "BuffBar")
check(holder ~= nil and holder.Parent == gui, "Start builds the row under UIKit.Gui")
check(holder.Visible == false, "hidden at the start (nothing runs)")
BuffBar.Start()
check(#findAll(gui, "^BuffBar$") == 1 and #spawned == 1, "Start() runs once (one row, one loop)", #findAll(gui, "^BuffBar$"))
local want = {}
for id in Config.Alchemy.Tonics do want["Buff_" .. id] = true end
local got = {}
for _, n in sigNames do got[n] = true end
local allSig = true
for n in want do if not got[n] or not sigFns[n] then allSig = false end end
check(allSig and #sigNames == 4, "an attribute signal for every tonic id (Buff_<id>)", #sigNames)
check(holder.Active == false, "the row never takes the mouse")

attrs.Buff_MightTonic, attrs.Buff_GuardTonic = NOW + 151, NOW + 45
Config.Features.Tonics = false
BuffBar.Refresh()
check(holder.Visible == false and #findAll(holder, "^Tile_") == 0, "tonics off: hidden, no tiles (even while attributes are set)")
Config.Features.Tonics = true
BuffBar.Refresh()
check(holder.Visible == true, "tonics on and two running: shown")
local tiles = findAll(holder, "^Tile_")
check(#tiles == 2 and tiles[1].Name == "Tile_GuardTonic" and tiles[2].Name == "Tile_MightTonic", "two tiles, the soonest end first",
	tiles[1] and tiles[1].Name)
check(tiles[1].Image == "SlotCommon" and tiles[2].Image == "SlotCommon", "the approved slot art SlotCommon")
check(tiles[1].Size.Args[1] == 34 and tiles[1].Size.Args[2] == 34 and T.T.Tile == 34, "34 du square", tiles[1].Size.Args[1])
local gap = tiles[2].Position.Args[1] - tiles[1].Position.Args[1]
check(tiles[1].Position.Args[1] == 0 and gap == 34 + T.T.Gap, "tiles side by side with a small gap", gap)
local fb = tiles[1].Fallback
check(type(fb) == "table" and fb.CornerRadius ~= nil and fb.StrokeThickness == 2 and fb.BackgroundColor3.X == 16
	and fb.BackgroundColor3.Y == 20 and fb.BackgroundColor3.Z == 40, "the code fallback is BagUI's (dark fill, rim, corner)")
check(holder.Size.Args[1] == 2 * 34 + T.T.Gap, "the row is as wide as its tiles", holder.Size.Args[1])
local letter = find(tiles[2], "Letter")
check(letter and letter.Text == "M" and find(tiles[1], "Letter").Text == "G", "no icon art: the name's first letter (Might = M, Guard = G)",
	letter and letter.Text)
check(letter.TextColor3 == Config.Loot.Items.MightTonic.Color and find(tiles[1], "Letter").TextColor3 == Config.Loot.Items.GuardTonic.Color,
	"the letter is in the item's colour")
check(letter.Style == "Number", "the letter is a Number style text")
local t1, t2 = find(holder, "Time_GuardTonic"), find(holder, "Time_MightTonic")
check(t1.Text == "0:45" and t2.Text == "2:31", "under each tile its time left, m:ss (0:45, 2:31)", t1.Text .. " " .. t2.Text)
check(t1.Style == "Number" and t2.Style == "Number", "the time is UIKit.StyleText(label, Number)")
check(t1.Position.Args[2] == 34 + T.T.CapGap and t1.Position.Args[1] == tiles[1].Position.Args[1] + 17, "the time sits under its tile, centred")
local words = true
for _, d in descendants(holder) do
	if string.sub(d.Name or "", 1, 5) == "Time_" and not string.match(d.Text, "^[%d:]+$") then words = false end
end
check(words, "no words on the row (the times are digits and a colon only)")

-- the icons once the art is drawn: a changed order rebuilds the tiles
artReady = true
attrs.Buff_GuardTonic = NOW + 300
fire("Buff_GuardTonic")
tiles = findAll(holder, "^Tile_")
check(tiles[1].Name == "Tile_MightTonic" and tiles[2].Name == "Tile_GuardTonic", "an attribute change reorders the tiles (soonest first)", tiles[1].Name)
local icon = find(tiles[1], "Icon")
check(icon and icon.ItemId == "MightTonic" and find(tiles[1], "Letter") == nil, "with art: the item icon, no letter")
check(math.abs(icon.Position.Args[1] - 76 / 512) < 1e-9 and math.abs(icon.Position.Args[2] - 80 / 512) < 1e-9
	and math.abs(icon.Size.Args[1] - 360 / 512) < 1e-9 and math.abs(icon.Size.Args[2] - 356 / 512) < 1e-9,
	"the icon sits in the slot's Inner box (76, 80, 436, 436 of 512)")
artReady = false

------------------------------------------------------------------ 4. timers and signals
attrs.Buff_GuardTonic = NOW + 45
attrs.Buff_MightTonic = NOW + 151
fire("Buff_MightTonic")
t1, t2 = find(holder, "Time_GuardTonic"), find(holder, "Time_MightTonic")
check(t1.Text == "0:45" and t2.Text == "2:31", "a signal redraws at once", t1.Text .. " " .. t2.Text)
NOW += 1
BuffBar.Refresh()
check(find(holder, "Time_GuardTonic") == t1 and t1.Text == "0:44" and t2.Text == "2:30", "a second later the times move (the same labels)",
	t1.Text .. " " .. t2.Text)
NOW += 44
BuffBar.Refresh()
check(#findAll(holder, "^Tile_") == 1 and holder.Visible and find(holder, "Time_MightTonic").Text == "1:46",
	"a tonic that ran out leaves the row", #findAll(holder, "^Tile_"))
attrs.Buff_MightTonic = 0
fire("Buff_MightTonic")
check(holder.Visible == false and #findAll(holder, "^Tile_") == 0, "none running: hidden")
attrs.Buff_MightTonic = NOW + 10
fire("Buff_MightTonic")
check(holder.Visible == true and #findAll(holder, "^Tile_") == 1, "drinking one shows it again")
-- the loop: 0.25 s, updates the times
check(#spawned == 1, "one loop")
waits = {}
waitLimit = 2
NOW += 3
local okLoop = pcall(spawned[1])
check(not okLoop and waits[1] == 0.25, "the loop waits 0.25 s", waits[1])
check(find(holder, "Time_MightTonic").Text == "0:07", "the loop moves the timer", find(holder, "Time_MightTonic").Text)
HUD.IsVisible = function() return false end
BuffBar.Refresh()
check(holder.Visible == false, "the HUD hidden (opening, picker): the row goes with it")
HUD.IsVisible = function() return true end
BuffBar.Refresh()
check(holder.Visible == true, "the HUD back: the row is back")

------------------------------------------------------------------ 5. placement from the HUD layout
local pos = holder.Position
check(pos.Args[1] == 100 + 184 and pos.Args[2] == 470 - 4, "no MP bar: right edge = the HP bar's right edge, bottom = 4 du above the power line",
	tostring(pos.Args[1]) .. "," .. tostring(pos.Args[2]))
HUD.Layout = { Rects = { hp_bar = { X = 100, Y = 500, W = 184, H = 20 }, mp_bar = { X = 294, Y = 500, W = 184, H = 17 },
	power_line = { X = 100, Y = 470, W = 375, H = 16 } } }
BuffBar.Relayout()
check(holder.Position.Args[1] == 294 + 184 and holder.Position.Args[2] == 466,
	"with the MP bar: right edge = the end of the vitals row (UiSandbox 10/12: not between the bars)", holder.Position.Args[1])
check(holder.AnchorPoint.X == 1 and holder.AnchorPoint.Y == 1, "anchored bottom-right so the row grows to the left")
HUD.Layout = { Rects = { hp_bar = { X = 700, Y = 540, W = 200, H = 20 }, power_line = { X = 700, Y = 510, W = 375, H = 16 } } }
BuffBar.Relayout()
pos = holder.Position
check(pos.Args[1] == 900 and pos.Args[2] == 506, "Relayout reads the new HUD.Layout", tostring(pos.Args[1]) .. "," .. tostring(pos.Args[2]))
HUD.Layout = { Rects = { hp_bar = { X = 10, Y = 540, W = 100, H = 20 }, power_line = { X = 10, Y = 400, W = 375, H = 16 } } }
waits = {}
pcall(spawned[1])
check(holder.Position.Args[1] == 110 and holder.Position.Args[2] == 396, "a layout HUD made while this did not listen is picked up by the loop")
HUD.Layout = { Rects = {} }
BuffBar.Relayout()
check(holder.Visible == false, "no usable rects: hidden")
HUD.Layout = nil
BuffBar.Relayout()
check(holder.Visible == false, "no layout yet: hidden")
HUD.Layout = { Rects = { hp_bar = { X = 100, Y = 500, W = 184, H = 20 }, power_line = { X = 100, Y = 470, W = 375, H = 16 } } }
BuffBar.Relayout()
check(holder.Visible == true and holder.Position.Args[1] == 284, "a layout again: shown at its place")
HUD.Layout = { Rects = { hp_bar = { X = 100, Y = 500, W = 184, H = 20 }, mp_bar = { X = 294, Y = 500 },
	power_line = { X = 100, Y = 470, W = 375, H = 16 } } }
BuffBar.Relayout()
check(holder.Position.Args[1] == 284, "an MP rect without a width: the HP bar's edge")
------------------------------------------------------------------ 5b. the real-pixel floor (최종 검수 10/12)
local st, sc = BuffBar.Sizes(1)
check(st == 34 and sc == 15, "scale 1: the tile stays 34 du, the clock at its 15 px floor", st .. "," .. sc)
st, sc = BuffBar.Sizes(0.6)
check(st == 57 and sc == 25 and st * 0.6 >= 34 and sc * 0.6 >= 15, "scale 0.6: tile >= 34 px and clock >= 15 px real", st .. "," .. sc)
check(BuffBar.Sizes(nil) == 34 and BuffBar.Sizes(0) == 34, "no / bad scale: as at 1")
attrs.Buff_GuardTonic = NOW + 120
fire("Buff_GuardTonic")
HUD.Layout = { Scale = 0.6, Rects = { hp_bar = { X = 100, Y = 500, W = 184, H = 20 }, mp_bar = { X = 294, Y = 500, W = 184, H = 17 },
	power_line = { X = 100, Y = 470, W = 375, H = 16 } } }
BuffBar.Relayout()
local tiles = findAll(holder, "^Tile_")
local clocks = findAll(holder, "^Time_")
local tileSize = tiles[1] and tiles[1].Size and tiles[1].Size.Args[1]
check(#tiles == 2 and tileSize == 57, "a small HUD scale builds the tiles again at the floor size", tostring(tileSize))
local cx = {}
for _, c in clocks do table.insert(cx, c.Position.Args[1]) end
table.sort(cx)
check(#clocks == 2 and clocks[1].Size.Args[1] <= 57 + 6 and (cx[2] - cx[1]) >= clocks[1].Size.Args[1],
	"the two clocks never overlap (each as wide as its tile + gap)", #clocks)
check(holder.Size.Args[1] == 57 * 2 + 6 and holder.Size.Args[2] == 57 + 2 + 25, "the row's size follows", holder.Size.Args[1])
attrs.Buff_GuardTonic = 0
fire("Buff_GuardTonic")
HUD.Layout = { Rects = { hp_bar = { X = 100, Y = 500, W = 184, H = 20 }, power_line = { X = 100, Y = 470, W = 375, H = 16 } } }
BuffBar.Relayout()
------------------------------------------------------------------ 6. the loop's warnings and the switch (게임성 검수 10/12)
local goodLayout = HUD.Layout
-- a broken layout every pass (a new table each read, so every pass tries it again and fails)
rawset(HUD, "Layout", nil)
setmetatable(HUD, { __index = function(_, k)
	if k == "Layout" then return setmetatable({}, { __index = function() error("broken layout") end }) end
	return nil
end })
warns, waits, waitLimit = 0, {}, 5
pcall(spawned[1])
check(warns == 1, "an error every 0.25 s: one warning line, not four a second", warns)
CLOCK += 11
waits = {}
pcall(spawned[1])
check(warns == 2, "the same error 10 s later: one more line", warns)
setmetatable(HUD, nil)
HUD.Layout = goodLayout
BuffBar.Relayout()
check(holder.Visible == true, "a good layout again: shown")
Config.Features.Tonics = false
waits, waitLimit = {}, 2
pcall(spawned[1])
check(holder.Visible == false and BuffBar._T.S.Sig == nil, "the switch off: the loop hides the row and draws nothing")
Config.Features.Tonics = true
waits = {}
pcall(spawned[1])
check(holder.Visible == true and #findAll(holder, "^Tile_") >= 1, "on again: the tiles are built again")
Config.Features.Tonics = false

print(string.format("BUFF_BAR_SUMMARY checks=%d failed=%d", checks, failed))
