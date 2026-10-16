-- Production MonsterMotion + engine doubles (monster motion review 2026-10-06, survey 4-1). Bone poses are not
-- checked (CFrame is a stand-in); the clip choice, clip time, Slash restarts, the wind-up alignment, Walk / Fall rates
-- and per-monster loop phases are read through MonsterMotion.Debug. Inputs: SOURCE, CLIPS, WINDUP, GOBLIN_SPEED,
-- EXPECT_SLASH_HIT, EXPECT_FALL_HIT (from the clip files), BONES.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if not ok then
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end
local function near(a, b, eps) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6) end
local function signal()
	local rows, s = {}, {}
	function s:Connect(fn)
		local row = { Fn = fn, On = true }
		table.insert(rows, row)
		return { Disconnect = function() row.On = false end }
	end
	function s:Fire(...) for _, row in table.clone(rows) do if row.On then row.Fn(...) end end end
	return s
end
-- stand-ins: poses are built but never inspected
local cfmt = {}
local function cfr() return setmetatable({}, cfmt) end
cfmt.__mul = function() return cfr() end
cfmt.__index = { Lerp = function() return cfr() end }
local CFrameD = { new = function() return cfr() end, identity = cfr() }
local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vmt) end
vmt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Lerp" then return function(a, b, u) return vec(a.X + (b.X - a.X) * u, a.Y + (b.Y - a.Y) * u, a.Z + (b.Z - a.Z) * u) end end
	return nil
end
vmt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__mul = function(a, b)
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end

local mods = {}
for key, src in CLIPS do mods[key] = { Name = key, Src = src, IsA = function(_, c) return c == "ModuleScript" end } end
local configMod = { Value = { HitReact = { MonsterWindup = WINDUP }, MonsterTypes = { Goblin = { Speed = GOBLIN_SPEED } } } }
local function fakeRequire(m)
	if m.Src then return assert(loadstring(m.Src))() end
	return m.Value
end
local RS = { Shared = { Config = configMod } }
function RS:FindFirstChild(k) if k == "MonsterAnims" then return { FindFirstChild = function(_, n) return mods[n] end } end end
local render = signal()
local W = { clock = 1000, server = 50000, monsters = {}, randoms = {} }
local folder = { GetChildren = function() return W.monsters end }
local WS = { CurrentCamera = { CFrame = { Position = vec(0, 5, 0) } } }
function WS:FindFirstChild(k) if k == "Monsters" then return folder end end
function WS:GetServerTimeNow() return W.server end
local services = { Players = {}, ReplicatedStorage = RS, RunService = { RenderStepped = render } }
local mathD = setmetatable({ random = function()
	return table.remove(W.randoms, 1) or 0.5
end }, { __index = math })
local fn = assert(loadstring(SOURCE))
setfenv(fn, setmetatable({
	game = { GetService = function(_, n) return assert(services[n], n) end }, workspace = WS, require = fakeRequire,
	CFrame = CFrameD, Vector3 = { new = vec }, os = { clock = function() return W.clock end }, math = mathD,
	warn = function(...) print("WARN", ...) end, print = function() end,
}, { __index = getfenv() }))
local MM = fn()
MM.Init({})
MM.Start()
local M = MM.Debug
check(type(M) == "table" and type(M.State) == "table", "MonsterMotion.Debug exposes its tuning / state table")

local function newModel(kind, phase, rate01)
	table.insert(W.randoms, phase)
	table.insert(W.randoms, rate01)
	local attrs, sigs = { MonsterKind = kind }, {}
	local model = { Name = kind }
	function model:GetAttribute(k) return attrs[k] end
	function model:SetAttribute(k, v)
		attrs[k] = v
		if sigs[k] then sigs[k]:Fire() end
	end
	function model:GetAttributeChangedSignal(k)
		sigs[k] = sigs[k] or signal()
		return sigs[k]
	end
	model.AncestryChanged = signal()
	function model:IsA(c) return c == "Model" end
	local bones = {}
	for _, n in BONES do table.insert(bones, { Name = n, Transform = CFrameD.identity, IsA = function(_, c) return c == "Bone" end }) end
	local visual = { Name = "CustomVisual" }
	function visual:GetDescendants() return bones end
	function visual:GetScale() return 1 end
	local root = { Name = "HumanoidRootPart", Position = vec(0, 3, -10), AssemblyLinearVelocity = vec(0, 0, 0), Anchored = false, Parent = model }
	function model:FindFirstChild(n)
		if n == "CustomVisual" then return visual end
		if n == "HumanoidRootPart" then return root end
		return nil
	end
	table.insert(W.monsters, model)
	return model, root
end
local DT = 1 / 60
local function frame(dt)
	dt = dt or DT
	W.clock += dt
	W.server += dt
	render:Fire(dt)
end

-- 1. tracking + Idle at the monster's own phase / speed
local g, groot = newModel("Goblin", 0.25, 1) -- Phase 0.25, Rate 1 + (2*1 - 1) * Jitter
frame()
local st = M.State[g]
local idle = M.Cache.Goblin_Idle
check(st and st.Clip == "Idle" and near(st.Rate, 1 + M.Jitter) and idle and near(st.T, 0.25 * idle.Length + DT * st.Rate),
	"a standing goblin plays Idle from its own phase (0.25 of the loop) at its own speed (+8%)", st and { st.Clip, st.T })
local g2 = newModel("Goblin", 0.75, 0)
frame()
local st2 = M.State[g2]
check(st2 and st2.Clip == "Idle" and near(st2.Rate, 1 - M.Jitter) and math.abs(st2.T - st.T) > 0.2,
	"a second goblin starts its loop elsewhere and runs 8% slower (a group never moves in step)", st2 and { st2.T, st.T })

-- 2. the wind-up starts Slash so its fastest frame meets the impact
g:SetAttribute("WindupAt", W.server)
frame()
local slash = M.Cache.Goblin_Slash
check(slash and near(M.HitTime(slash), EXPECT_SLASH_HIT, 1e-9), "Slash HitTime = the clip's fastest frame (from the clip data)",
	slash and M.HitTime(slash))
check(st.Clip == "Slash" and near(st.T, EXPECT_SLASH_HIT - WINDUP + DT, 1e-6),
	"the wind-up starts Slash at HitTime - wind-up (its first part skipped)", st.T)
local frames = math.floor(WINDUP / DT + 0.5) - 1
for _ = 1, frames do frame() end
check(near(st.T, EXPECT_SLASH_HIT, DT), "at the impact (wind-up end) the clip is at its fastest frame", { st.T, EXPECT_SLASH_HIT })
-- the impact's AttackSeq belongs to that wind-up: no restart
local before = st.T
g:SetAttribute("AttackSeq", 1)
frame()
check(st.Clip == "Slash" and near(st.T, before + DT, 1e-6), "the impact (AttackSeq) right after its wind-up does not restart the swing", st.T)

-- 3. back-to-back attacks: every new wind-up restarts the swing (it used to freeze on the last frame)
for _ = 1, 20 do frame() end
local mid = st.T
g:SetAttribute("WindupAt", W.server)
frame()
check(st.Clip == "Slash" and near(st.T, EXPECT_SLASH_HIT - WINDUP + DT, 1e-6) and mid > st.T,
	"a second attack while Slash still plays restarts it from the wind-up point", { mid, st.T })

-- 4. an impact seen without its wind-up (it arrived late / off screen): the follow-through from the fastest frame
for _ = 1, 90 do frame() end -- past SlashFresh and the swing
g:SetAttribute("AttackSeq", 2)
frame()
check(st.Clip == "Slash" and near(st.T, EXPECT_SLASH_HIT + DT, 1e-6), "an AttackSeq with no wind-up seen: Slash from its fastest frame", st.T)

-- 5. Walk plays as fast as the monster really walks
for _ = 1, 120 do frame() end -- the swing ends
groot.AssemblyLinearVelocity = vec(GOBLIN_SPEED / 2, 0, 0)
frame()
local t0 = st.T
frame()
check(st.Clip == "Walk" and near(st.T - t0, DT * st.Rate * 0.5, 1e-9),
	"walking at half its chase speed: the Walk clip runs at half speed (no sliding feet)", { st.Clip, st.T - t0 })
groot.AssemblyLinearVelocity = vec(GOBLIN_SPEED * 3, 0, 0)
frame() -- three times its chase speed: it switches to Run
t0 = st.T
frame()
check(st.Clip == "Run" and near(st.T - t0, DT * st.Rate * M.WalkRate.Max, 1e-9), "a very fast slide is capped at 1.5x", st.T - t0)

-- 5b. chasing at its full speed it runs (Run clip, ab7e7a5); a half-speed wander walks
groot.AssemblyLinearVelocity = vec(GOBLIN_SPEED, 0, 0)
frame()
t0 = st.T
frame()
check(st.Clip == "Run" and near(st.T - t0, DT * st.Rate * 1, 1e-9), "chasing at its full speed: the Run clip at its own pace", { st.Clip, st.T - t0 })
groot.AssemblyLinearVelocity = vec(GOBLIN_SPEED * (M.RunAbove - 0.05), 0, 0)
frame()
check(st.Clip == "Walk" and M.RunAbove == 0.75, "below 75% of the chase speed it walks", st.Clip)

-- 5c. standing: now and then one LookAround (two head turns), then Idle; moving cuts it off
groot.AssemblyLinearVelocity = vec(0, 0, 0)
st.LookAt = W.clock + 0.5
frame()
check(st.Clip == "Idle", "standing before its look time: Idle", st.Clip)
for _ = 1, 31 do frame() end
local look = M.Cache.Goblin_LookAround
check(look and st.Clip == "LookAround" and st.T < 0.05 and near(st.LookUntil - W.clock, look.Length / st.Rate, 0.05)
	and st.LookAt > st.LookUntil + M.LookEvery[1] - 0.1,
	"its look time: one LookAround from the start, the next one 6-12 s after it ends", { st.Clip, st.T })
for _ = 1, 30 do frame() end
groot.AssemblyLinearVelocity = vec(GOBLIN_SPEED / 2, 0, 0)
frame()
check(st.Clip == "Walk" and st.LookUntil == 0, "walking off cuts the LookAround", st.Clip)
groot.AssemblyLinearVelocity = vec(0, 0, 0)
frame()
check(st.Clip == "Idle", "standing again before the next look time: back to Idle (the cut look does not resume)", st.Clip)

-- 6. beaten (A23-211, user 10/16): no fall of any kind - it stays calm (Idle) while Fx relaxes and fades it
groot.AssemblyLinearVelocity = vec(0, 0, 0)
groot.Anchored = true
frame()
check(st.Clip == "Idle" and M.Cache.Goblin_Fall == nil and M.FallRate == nil,
	"beaten: Idle, no Fall clip, no fall rate", { st.Clip })
-- 7. an event monster going home (Leaving) floats calmly: no fall
local k, kroot = newModel("Goblin", 0.5, 0.5)
frame()
k:SetAttribute("Leaving", true)
kroot.Anchored = true
frame()
check(M.State[k].Clip == "Idle", "Leaving + anchored: Idle (it floats away), never the fall", M.State[k].Clip)

print("MONSTER_MOTION_SUMMARY checks=" .. checks .. " failed=" .. failed)
