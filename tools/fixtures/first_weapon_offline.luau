-- Offline checks for A23-68 #3 (HUD.luau): the first weapon's big moment. The real L.First / L.TierChanged /
-- L.FirstWeapon / L.PowerPopup blocks of HUD.luau with small doubles. Input: HUD_BLOCKS (those blocks, extracted by
-- tools/test_first_weapon.py). No Studio / Roblox API calls.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if not ok then
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end

local W = { Now = 100, Timers = {}, Attrs = {}, Announced = {}, Played = {}, Emitted = 0, Tweens = {}, Reduced = false,
	Sets = {}, Destroyed = 0 }
local function advance(dt)
	W.Now += dt
	local due = {}
	for i = #W.Timers, 1, -1 do
		if W.Timers[i].At <= W.Now then table.insert(due, table.remove(W.Timers, i)) end
	end
	table.sort(due, function(a, b) return a.At < b.At end)
	for _, t in due do t.Fn(table.unpack(t.Args)) end
end
local function obj(props)
	local o = props or {}
	o.Children = o.Children or {}
	o.FindFirstChild = function(self, n) for _, c in self.Children do if c.Name == n then return c end end return nil end
	o.Destroy = function(self) W.Destroyed += 1 self.Parent = nil end
	return setmetatable(o, { __newindex = function(t, k, v)
		if k == "Parent" and type(v) == "table" and v.Children then table.insert(v.Children, t) end
		rawset(t, k, v)
	end })
end
local root = obj({ Name = "HumanoidRootPart" })
local character = obj({ Name = "Kid" })
character.FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return root end return nil end
local env = setmetatable({
	L = {}, TXT = { Stronger = "Stronger!" }, IS_TOUCH = false, Theme = { Gold = "gold" },
	ui = { power = obj({ Name = "Power", AbsolutePosition = { X = 100, Y = 50 }, AbsoluteSize = { X = 80, Y = 20 } }),
		stats = obj({ Name = "Stats", AbsolutePosition = { X = 0, Y = 0 } }) },
	attr = function(k, d) local v = W.Attrs[k] if v == nil then return d end return v end,
	num = function(k, d) return tonumber(W.Attrs[k]) or d end,
	currentScale = function() return 1 end,
	ac = function(_, d) return d end,
	artLabel = function(_, props) return obj({ Name = props.Name, Text = props.Text }) end,
	Util = { FormatInt = function(n) return tostring(n) end },
	C = { Audio = { Play = function(e) table.insert(W.Played, e) return true end } },
	UIKit = { Announce = function(text, dur) table.insert(W.Announced, { text, dur }) end,
		ReducedMotion = function() return W.Reduced end },
	LocalPlayer = { Character = character },
	TweenService = { Create = function(_, inst, _, goal) table.insert(W.Tweens, { inst, goal }) return { Play = function() end } end },
	TweenInfo = { new = function() return {} end },
	Enum = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, v) return k .. "." .. v end }) end }),
	UDim2 = { fromOffset = function(x, y) return { X = x, Y = y } end },
	Vector2 = { new = function(x, y) return { X = x, Y = y } end },
	Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end },
	Color3 = { fromRGB = function(r, g, b) return { r, g, b } end },
	ColorSequence = { new = function(...) return { ... } end },
	NumberRange = { new = function(...) return { ... } end },
	NumberSequence = { new = function(...) return { ... } end },
	NumberSequenceKeypoint = { new = function(...) return { ... } end },
	Instance = { new = function(class)
		local o = obj({ ClassName = class, Name = class })
		if class == "ParticleEmitter" then o.Emit = function(_, n) W.Emitted += n end end
		return o
	end },
	os = { clock = function() return W.Now end },
	task = {
		delay = function(t, fn, ...) table.insert(W.Timers, { At = W.Now + t, Fn = fn, Args = { ... } }) end,
		spawn = function(fn, ...) fn(...) end,
		wait = function(t) advance(t or 1 / 30) end,
	},
	pcall = pcall, print = print,
}, { __index = getfenv() })
local fn = assert(loadstring("local L, TXT, ui = L, TXT, ui\n" .. HUD_BLOCKS .. "\nreturn L", "=HUD.first"))
setfenv(fn, env)
local L = env.L
rawset(env.ui.power, "Parent", env.ui.stats) -- the power label sits on the plate
-- the power state the blocks expect (HUD's own L.Pow line is in HUD_BLOCKS)
fn()
function L.PowerSet(n) table.insert(W.Sets, n) end
check(type(L.First) == "table" and type(L.TierChanged) == "function" and type(L.FirstWeapon) == "function", "the blocks load", "")

local function reset()
	W.Timers, W.Announced, W.Played, W.Emitted, W.Tweens, W.Sets = {}, {}, {}, 0, {}, {}
	L.First.Tier, L.First.Pop = nil, false
end
local function set(k, v) W.Attrs[k] = v end

-- 1. a save loading with a weapon: no moment
reset()
set("DataLoaded", false) set("ClassChosen", false) set("WeaponTier", 0)
L.TierChanged()
set("WeaponTier", 3) L.TierChanged()
set("DataLoaded", true) L.TierChanged()
set("ClassChosen", true) L.TierChanged()
advance(5)
check(#W.Announced == 0 and L.First.Pop == false, "loading a save with a weapon shows nothing", #W.Announced)

-- 2. a new player: class picked with bare hands, then the M1_1 gift (0 -> 1) + the power rise popup
reset()
set("DataLoaded", true) set("ClassChosen", false) set("WeaponTier", 0)
L.TierChanged()
set("ClassChosen", true) L.TierChanged()
check(L.First.Tier == 0 and not L.First.Pop, "the first live reading is the baseline", L.First.Tier)
set("WeaponTier", 1) L.TierChanged()
check(L.First.Pop == true, "0 -> 1 arms the moment", L.First.Pop)
L.PowerPopup(120, 340, 220)
check(#W.Announced == 1 and W.Announced[1][1] == "Stronger!", "a big 'Stronger!' banner", W.Announced[1] and W.Announced[1][1])
check(W.Played[1] == "PowerUp", "the PowerUp sound", W.Played[1])
check(W.Emitted == L.First.Sparks and W.Emitted > 0, "gold sparkles burst from me", W.Emitted)
local grew = false
for _, t in W.Tweens do if t[1].Name == "FirstWeaponScale" and t[2].Scale and t[2].Scale > 1.2 then grew = true end end
check(grew, "the Power number grows for a moment", #W.Tweens)
check(W.Sets[#W.Sets] == 340, "the count-up ends on the new Power", W.Sets[#W.Sets])
-- slow count: the number is still on its way after the normal 0.6 s
local mid
for i, v in W.Sets do if i > 1 and v > 120 and v < 340 then mid = v end end
check(mid ~= nil and #W.Sets >= math.floor(L.First.Count * 30) - 2, "the count-up is the slow one (First.Count)", #W.Sets)
advance(3)
check(#W.Announced == 1, "the fallback does not show it a second time", #W.Announced)

-- 3. no power popup came: the fallback shows it once
reset()
set("WeaponTier", 0) L.TierChanged()
set("WeaponTier", 1) L.TierChanged()
advance(L.First.Wait + 0.5)
check(#W.Announced == 1 and L.First.Pop == false, "without a power rise the moment still shows once", #W.Announced)

-- 4. a later weapon (1 -> 2) is no first weapon
reset()
set("WeaponTier", 1) L.TierChanged()
set("WeaponTier", 2) L.TierChanged()
advance(3)
check(#W.Announced == 0, "1 -> 2 shows nothing", #W.Announced)
L.PowerPopup(340, 500, 160)
check(#W.Announced == 0, "an ordinary power rise shows no banner", #W.Announced)

-- 5. 'Screen shake' off: no growing number
reset()
W.Reduced = true
set("WeaponTier", 0) L.TierChanged()
set("WeaponTier", 1) L.TierChanged()
L.PowerPopup(120, 340, 220)
local grewReduced = false
for _, t in W.Tweens do if t[1].Name == "FirstWeaponScale" then grewReduced = true end end
check(#W.Announced == 1 and not grewReduced, "reduced motion: the banner, no growing number", tostring(grewReduced))
W.Reduced = false

print(string.format("FIRST_WEAPON_SUMMARY checks=%d failed=%d", checks, failed))
