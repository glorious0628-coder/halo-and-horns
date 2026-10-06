-- Real Fx red-edge code (flashEdges, MOTION.EdgeCovered / EdgeStep / ShakeAllowed, MOTION.EDGE) + doubles.
-- quality ideas 2026-10-06 #6: a hit flashes the edges by its size (small = almost invisible), below 30% HP they throb
-- slowly, never over an open window, with shake off no flash / throb (a steady faint edge while HP is low).
-- Inputs: EDGE_SOURCE (a chunk returning { flash = flashEdges, MOTION = MOTION, frames = flashFrames, W = world }).
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if not ok then
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end
local function near(a, b, eps) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6) end
local W = { clock = 100, tweens = {}, prefs = { Shake = true }, reduced = false, open = {}, hp = 100, maxHp = 100 }
local function tween(inst, t, goal)
	local tw = { Inst = inst, T = t, Goal = goal, Cancelled = false }
	function tw:Cancel() self.Cancelled = true end
	table.insert(W.tweens, tw)
	return tw
end
local hum = {}
setmetatable(hum, { __index = function(_, k)
	if k == "Health" then return W.hp end
	if k == "MaxHealth" then return W.maxHp end
	return nil
end })
local char = { FindFirstChildOfClass = function(_, c) if c == "Humanoid" then return hum end end }
local function module(name) return { IsOpen = function() return W.open[name] == true end } end
local env = setmetatable({
	tween = tween, LocalPlayer = { Character = char }, COLOR_HURT = "red",
	C = { Panels = module("Panels"), WorldMap = module("WorldMap"), FactionPicker = module("FactionPicker"),
		ClassPicker = module("ClassPicker"), Intro = module("Intro") },
	os = { clock = function() return W.clock end },
	game = { GetService = function() return { ReducedMotionEnabled = W.reduced } end },
	Enum = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, v) return k .. "." .. v end }) end }),
	W = W,
}, { __index = getfenv() })
local fn = assert(loadstring(EDGE_SOURCE))
setfenv(fn, env)
local R = fn()
local MOTION, frames, flash = R.MOTION, R.frames, R.flash
MOTION.Pref = function(key, default) local v = W.prefs[key]; if v == nil then return default end return v end
for i = 1, 4 do frames[i] = { BackgroundTransparency = 1, BackgroundColor3 = nil } end
local E = MOTION.EDGE
local function lastStart() return frames[1].BackgroundTransparency end

check(E.Small == 0.05 and E.Big == 0.15 and E.SmallT == 0.94 and E.BigT == 0.35 and E.LowHP == 0.3 and E.Period == 1.1
	and E.CalmT == 0.82, "EDGE tuning: 5% / 15% of MaxHealth, 0.94 / 0.35 transparency, throb below 30% HP every 1.1 s")
-- a small hit: almost invisible; a big hit: a clear flash; in between: scaled
flash("red", 0)
check(near(lastStart(), 0.94) and #W.tweens == 4 and W.tweens[1].Goal.BackgroundTransparency == 1,
	"a small hit: the edges start at 0.94 (almost invisible) and fade out", lastStart())
flash("red", 1)
check(near(lastStart(), 0.35) and W.tweens[1].Cancelled == true, "a big hit: a clear flash (0.35), the old fade cancelled", lastStart())
flash("red", 0.5)
check(near(lastStart(), 0.645), "a medium hit: halfway (0.645)", lastStart())
-- never over an open window
for _, name in { "Panels", "WorldMap", "FactionPicker", "ClassPicker", "Intro" } do
	W.open[name] = true
	frames[1].BackgroundTransparency = 1
	local n = #W.tweens
	flash("red", 1)
	check(frames[1].BackgroundTransparency == 1 and #W.tweens == n, name .. " open: no red edges over it")
	W.open[name] = nil
end
-- shake off (setting or Roblox reduced motion): no flash
W.prefs.Shake = false
frames[1].BackgroundTransparency = 1
flash("red", 1)
check(frames[1].BackgroundTransparency == 1, "shake off: a hit never flashes the edges")
W.prefs.Shake = true
W.reduced = true
flash("red", 1)
check(frames[1].BackgroundTransparency == 1, "Roblox reduced motion: no flash either")
W.reduced = false

-- the low-HP throb (EdgeStep): none above 30%, slow throb below, steady faint edge with shake off, hidden by windows
W.clock = 200
W.hp = 50
MOTION.EdgeStep()
check(frames[1].BackgroundTransparency == 1, "50% HP: no edges")
W.hp = 20
local seen = {}
for i = 0, 22 do
	W.clock = 200 + i * 0.05
	MOTION.EdgeStep()
	seen[#seen + 1] = frames[1].BackgroundTransparency
end
local lo, hi = math.huge, -math.huge
for _, v in seen do lo = math.min(lo, v); hi = math.max(hi, v) end
check(lo >= E.PulseHi - 1e-6 and hi <= E.PulseLo + 1e-6 and hi - lo > 0.2,
	"20% HP: the edges throb slowly between 0.55 and 0.85 over 1.1 s", { lo, hi })
W.open.Panels = true
MOTION.EdgeStep()
check(frames[1].BackgroundTransparency == 1, "20% HP with the bag open: no edges over it")
W.open.Panels = nil
W.prefs.Shake = false
MOTION.EdgeStep()
local a = frames[1].BackgroundTransparency
W.clock += 0.3
MOTION.EdgeStep()
check(near(a, E.CalmT) and near(frames[1].BackgroundTransparency, E.CalmT), "shake off at 20% HP: a steady faint edge (0.82), no throb", a)
W.prefs.Shake = true
-- a hit flash wins over the throb until it fades
flash("red", 1)
local during = frames[1].BackgroundTransparency
W.clock += 0.1
MOTION.EdgeStep()
check(near(frames[1].BackgroundTransparency, during), "a running hit flash is not overwritten by the throb")
W.clock += E.Fade
MOTION.EdgeStep()
check(frames[1].BackgroundTransparency ~= during, "after the flash the throb takes over again")
W.hp = 0
MOTION.EdgeStep()
check(frames[1].BackgroundTransparency == 1, "dead (0 HP): no throb")
print("FX_EDGES_SUMMARY checks=" .. checks .. " failed=" .. failed)
