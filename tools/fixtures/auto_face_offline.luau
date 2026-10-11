-- A23-91 보강 (user 2026-10-09 "공격할 때 몬스터 쪽으로 몸 돌리기 … 조금 더 세세하게"): the turn toward a monster when
-- I attack. Runs the real Config.luau (Config.AutoFace, AttackProfile, class rows) and the real HUD.PickTarget,
-- L.AIM.ShowRing, L.AIM.TurnTo and L.FaceTarget (cut out by tools/test_auto_face.py) on small doubles: a fake clock,
-- RenderStepped and task.delay, a character, a camera and a Monsters folder. Inputs: CONFIG_SOURCE, HUD_SOURCE.
-- Every check is named and counted.
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
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __kind = "Vector3" }, vmt) end
vmt.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vmt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
vmt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return vec(v.X / m, v.Y / m, v.Z / m)
	end
	if k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end end
	return nil
end
-- a yaw-only CFrame: Position + Yaw (CFrame.Angles(0, yaw, 0) looks along (-sin yaw, 0, -cos yaw))
local cmt = {}
local function cf(pos, yaw) return setmetatable({ Position = pos, Yaw = yaw or 0, __kind = "CFrame" }, cmt) end
cmt.__index = function(c, k)
	if k == "LookVector" then return vec(-math.sin(c.Yaw), 0, -math.cos(c.Yaw)) end
	return nil
end
cmt.__mul = function(a, b) return cf(a.Position, a.Yaw + b.Yaw) end
local CF = {
	new = function(x, y, z)
		if type(x) == "table" then return cf(x, 0) end
		return cf(vec(x, y, z), 0)
	end,
	Angles = function(_, ry, _) return cf(vec(0, 0, 0), ry) end,
}
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local base = { Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec },
	Color3 = { new = vec, fromRGB = vec, fromHSV = vec }, BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"),
	UDim2 = ctor("UDim2"), UDim = ctor("UDim"), NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"),
	ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = CF, TweenInfo = ctor("TweenInfo"),
	Font = ctor("Font"), Enum = enum }
local cfgEnv = setmetatable(table.clone(base), { __index = getfenv() })
cfgEnv.CFrame = ctor("CFrame")
cfgEnv.workspace = { GetServerTimeNow = function() return 1790000000 end }
local fn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(fn, cfgEnv)
local Config = fn()
local AF = Config.AutoFace

-- the world doubles
local NOW = 100
local SERVER0 = 1790000000
local conns, timers = {}, {}
local RunService = { RenderStepped = { Connect = function(_, f)
	local c = { Fn = f, On = true }
	function c.Disconnect(self) self.On = false end
	table.insert(conns, c)
	return c
end } }
local function step(dt)
	NOW += dt
	for _, c in table.clone(conns) do
		if c.On then c.Fn(dt) end
	end
	for i = #timers, 1, -1 do
		local t = timers[i]
		if t.At <= NOW + 1e-9 then
			table.remove(timers, i)
			t.Fn()
		end
	end
end
local function run(seconds) -- 60 fps
	local n = math.max(1, math.floor(seconds * 60 + 0.5))
	for _ = 1, n do step(1 / 60) end
end
local function live() -- RenderStepped connections still running
	local n = 0
	for _, c in conns do if c.On then n += 1 end end
	return n
end

local folder = { List = {} }
function folder.GetChildren(self) return self.List end
local camera = { CFrame = { LookVector = vec(0, 0, -1) } }
local workspace = { CurrentCamera = camera, Name = "Workspace" }
function workspace.FindFirstChild(_, n) if n == "Monsters" then return folder end return nil end
local hum = { Health = 100, MoveDirection = vec(0, 0, 0), AutoRotate = true, HipHeight = 2 }
local root = { Position = vec(0, 3, 0), CFrame = cf(vec(0, 3, 0), 0), Size = vec(2, 2, 1) }
local char = {}
function char.FindFirstChild(_, n) if n == "HumanoidRootPart" then return root end return nil end
function char.FindFirstChildOfClass(_, c) if c == "Humanoid" then return hum end return nil end
hum.Parent, root.Parent = char, char
local player = { UserId = 1, Character = char }
local STATE = { Class = "Warrior", Tier = nil, Mouse = "MouseBehavior.Default" }
local uis = setmetatable({}, { __index = function(_, k) if k == "MouseBehavior" then return STATE.Mouse end return nil end })
local fired = {}

-- a monster `deg` degrees off -Z (to my right for +), `dist` studs from the root, on the floor
local function mon(name, deg, dist, opts)
	opts = opts or {}
	local r = math.rad(deg)
	local m = { Name = name, Attrs = { RootHeight = 2.5 }, Parent = folder }
	for k, v in opts.Attrs or {} do m.Attrs[k] = v end
	local mr = { Name = "HumanoidRootPart", Position = vec(dist * math.sin(r), 2.5, -dist * math.cos(r)), Anchored = false,
		Size = vec(2, 2, 2), Parent = m }
	function mr.IsA(_, c) return c == "BasePart" end
	local mh = { Health = opts.Health or 50 }
	m.Root, m.Hum = mr, mh
	function m.FindFirstChild(_, n) if n == "HumanoidRootPart" then return mr end return nil end
	function m.FindFirstChildOfClass(_, c) if c == "Humanoid" then return mh end return nil end
	function m.GetAttribute(_, k) return m.Attrs[k] end
	function m.GetExtentsSize() return vec(opts.Width or 3, 3, opts.Width or 3) end
	table.insert(folder.List, m)
	return m
end
local function clear()
	table.clear(folder.List)
end
local function remove(m)
	local i = table.find(folder.List, m)
	if i then table.remove(folder.List, i) end
	m.Parent = nil
	m.Root.Parent = nil
end

local HUD, L = {}, {}
local hudEnv = setmetatable(table.clone(base), { __index = getfenv() })
hudEnv.HUD, hudEnv.L, hudEnv.Config = HUD, L, Config
hudEnv.workspace, hudEnv.game = workspace, { GetService = function(_, n) if n == "RunService" then return RunService end return nil end }
hudEnv.task = { delay = function(t, f) table.insert(timers, { At = NOW + t, Fn = f }) end }
hudEnv.os = { clock = function() return NOW end }
hudEnv.Util = { Now = function() return SERVER0 + NOW end }
hudEnv.UIKit = { ArtId = function(n) return n == "FxShockRing" and "rbxassetid://135827777163619" or nil end }
local made = {}
hudEnv.Instance = { new = function(c)
	local o = { ClassName = c }
	table.insert(made, o)
	return o
end }
hudEnv.UserInputService, hudEnv.LocalPlayer = uis, player
hudEnv.getClass = function() return STATE.Class end
hudEnv.getFaction = function() return "Halo" end
hudEnv.num = function(name, d) if name == "WeaponTier" then return STATE.Tier or d end return d end
hudEnv.fire = function(...) table.insert(fired, { ... }) end
local cut = assert(loadstring(HUD_SOURCE, "=HUD"))
setfenv(cut, hudEnv)
cut()

local function yawTo(m) -- the root's yaw that faces monster m
	local d = m.Root.Position - root.Position
	return math.atan2(-d.X, -d.Z)
end
local function angDiff(a, b) return math.abs((a - b + math.pi) % (2 * math.pi) - math.pi) end
local function face(deg) -- reset: stand at the origin facing `deg`, no turn running, every window over
	run(1)
	NOW += 10 -- every KeepFor / RingShow window over
	run(0.1)
	root.CFrame = cf(root.Position, -math.rad(deg))
	hum.MoveDirection, hum.AutoRotate = vec(0, 0, 0), true
	camera.CFrame = { LookVector = root.CFrame.LookVector }
	table.clear(fired)
end
local function ringOn() return L.AIM.Ring ~= nil and L.AIM.Ring.Parent == workspace end

-- 0. the numbers
check(AF ~= nil and AF.ServerHint == true, "Config.AutoFace.ServerHint = true (CombatService takes the pick, dev2 4da8ba09)", AF and AF.ServerHint)
-- sections 1-6 check the rule without the hint (it still runs for auto swings and while the flag is off)
AF.ServerHint = false
check(AF.SkipDeg == 10 and AF.TurnTime >= 0.06 and AF.TurnTime <= 0.1, "turn: skipped within 10 deg, takes 0.06-0.1 s (SPEC ②)",
	tostring(AF.SkipDeg) .. " " .. tostring(AF.TurnTime))
check(AF.KeepFor >= 1 and AF.Inside < 1 and AF.Inside >= 0.85, "keep ~1.5 s, new picks a little inside the range", AF.KeepFor .. " " .. AF.Inside)
check(AF.WAttacker > AF.WFront and AF.WAttacker > AF.WDist, "the monster hitting me weighs the most", AF.WAttacker)

-- 1. the pick = the server's own aim (ServerHint false; CombatService.Swing, A23-61)
STATE.Class, STATE.Tier = "Warrior", nil -- bare hands: Range 7, AimCone 90
face(0)
local front = mon("front60", 60, 6)
local back = mon("back", 170, 3)
local turned, model = L.FaceTarget("Swing")
check(model == front, "server rule: the nearest INSIDE the front half beats a nearer one behind", model and model.Name)
check(turned == true, "... and I turn to it (60 deg off)", turned)
run(AF.TurnTime + 0.05)
check(angDiff(root.CFrame.Yaw, yawTo(front)) < math.rad(1), "... facing it after TurnTime", math.deg(angDiff(root.CFrame.Yaw, yawTo(front))))
check(ringOn() and L.AIM.Target == front.Root, "... a ring under it while I attack", L.AIM.Target and L.AIM.Target.Parent.Name)
clear()
face(0)
back = mon("back", 170, 3)
local back2 = mon("back far", -150, 5)
turned, model = L.FaceTarget("Swing")
check(model == back and turned == true, "nothing in front: the nearest in any direction, and I turn", model and model.Name)
clear()
face(0)
local far = mon("far", 0, 7.5)
turned, model = L.FaceTarget("Swing")
check(model == nil and turned == false and not ringOn(), "beyond bare hands' 7 studs: nothing, no turn, no ring", model and model.Name)
STATE.Tier = 1 -- a Warrior weapon: the class row, Range 10
turned, model = L.FaceTarget("Swing")
check(model == far, "with a weapon the Warrior reaches 10 (Config.AttackProfile)", model and model.Name)
clear()
STATE.Class, STATE.Tier = "Archer", 1
face(0)
local archerT = mon("archer target", 120, 26)
turned, model = L.FaceTarget("Swing")
check(model == archerT and turned, "the Archer reaches 30 (long range) and turns", model and model.Name)
STATE.Tier = nil
face(0)
turned, model = L.FaceTarget("Swing")
check(model == nil, "a bare-handed Archer reaches 7 only", model and model.Name)
clear()
STATE.Class, STATE.Tier = "Warrior", nil

-- 2. monsters only, never the wrong ones
face(0)
local hidden = mon("hidden", 0, 3, { Attrs = { Hidden = true } })
local other = mon("theirs", 10, 4, { Attrs = { OwnerUserId = 2 } })
local dead = mon("dead", -10, 4, { Health = 0 })
turned, model = L.FaceTarget("Swing")
check(model == nil, "a hidden ambusher, someone else's monster and a dead one are never picked", model and model.Name)
local mine = mon("mine", 90, 5, { Attrs = { OwnerUserId = 1 } })
turned, model = L.FaceTarget("Swing")
check(model == mine, "my own quest monster is picked", model and model.Name)
clear()
face(0)
mon("a", 90, 4)
STATE.Mouse = "MouseBehavior.LockCenter"
turned, model = L.FaceTarget("Swing")
check(turned == false and model == nil and not ringOn(), "shift lock keeps its own facing (no turn, no ring)", tostring(turned))
STATE.Mouse = "MouseBehavior.Default"
clear()

-- 3. the turn feel
face(0)
local side = mon("side", 90, 5)
local y0 = root.CFrame.Yaw
turned = L.FaceTarget("Swing")
step(AF.TurnTime / 2)
local half = angDiff(root.CFrame.Yaw, y0) / angDiff(yawTo(side), y0)
check(half > 0.55 and half < 0.95, "smooth, not a snap: past half way at half the time (ease out)", half)
run(AF.TurnTime)
check(angDiff(root.CFrame.Yaw, yawTo(side)) < 1e-6, "lands exactly on the target", math.deg(angDiff(root.CFrame.Yaw, yawTo(side))))
check(live() <= 1, "the turn stops itself (only the ring's step stays)", live())
clear()
face(0)
local almost = mon("almost", 8, 5)
turned, model = L.FaceTarget("Swing")
check(turned == false and model == almost and ringOn(), "within 10 deg: no turn, but it is my target (ring)", tostring(turned))
clear()
face(0)
hum.MoveDirection = vec(1, 0, 0)
local walkT = mon("walk", -100, 5)
turned = L.FaceTarget("Swing")
check(turned and hum.AutoRotate == false, "walking: the body stays on the target", hum.AutoRotate)
run(AF.TurnTime + AF.SwingHold - 0.05)
check(hum.AutoRotate == false, "... for TurnTime + SwingHold", hum.AutoRotate)
run(0.1)
check(hum.AutoRotate == true, "... then walks on (AutoRotate back)", hum.AutoRotate)
root.CFrame = cf(root.Position, 0)
turned = L.FaceTarget("Swing")
run(AF.TurnTime + AF.SwingHold - 0.15)
root.CFrame = cf(root.Position, 0)
turned = L.FaceTarget("Swing") -- a second swing while walking
run(0.2)
check(hum.AutoRotate == false, "a second swing while walking holds again (the first hold does not end it)", hum.AutoRotate)
run(AF.TurnTime + AF.SwingHold)
check(hum.AutoRotate == true, "... and it ends after the second hold", hum.AutoRotate)
clear()
face(0)
mon("stand", 90, 5)
L.FaceTarget("Swing")
run(1)
check(hum.AutoRotate == true, "standing: AutoRotate untouched", hum.AutoRotate)
clear()

-- 4. the ring
face(0)
local big = mon("big", 30, 6, { Width = 9 })
L.FaceTarget("Swing")
step(1 / 60)
local rs = L.AIM.Ring.Size
check(math.abs(rs.X - 9 * AF.RingPad) < 1e-6 and math.abs(rs.Z - rs.X) < 1e-9, "the ring fits the body (RingPad x width)", rs.X)
local cfr = L.AIM.Ring.CFrame
check(math.abs(cfr.Position.Y - (big.Root.Position.Y - 2.5 + 0.1)) < 1e-6, "... on the floor (RootHeight)", cfr.Position.Y)
local artImg = nil
for _, o in made do
	if o.ClassName == "ImageLabel" and o.Parent and o.Parent.Parent == L.AIM.Ring then artImg = o end
end
check(L.AIM.Ring.Transparency == 1 and artImg ~= nil and artImg.Image == "rbxassetid://135827777163619",
	"... drawn by the approved round ring art FxShockRing (no rays; the part itself invisible)", L.AIM.Ring.Transparency)
local tiny = mon("tiny", 30, 3, { Width = 0.5 })
L.FaceTarget("Swing")
step(1 / 60)
check(math.abs(L.AIM.Ring.Size.X - AF.RingSize) < 1e-6, "a tiny monster: at least RingSize", L.AIM.Ring.Size.X)
tiny.Hum.Health = 0
step(1 / 60)
check(not ringOn(), "the ring goes when the target dies", ringOn())
clear()
face(0)
mon("x", 30, 4)
L.FaceTarget("Swing")
run(AF.RingShow - 0.1)
check(ringOn(), "the ring stays while I keep attacking (RingShow)", ringOn())
run(0.2)
check(not ringOn(), "... and goes RingShow s after my last attack", ringOn())
clear()

-- 5. auto combat's standing facing (which = nil): the server's aim, no ring, waits while my own attacks keep a target
face(0)
local a1 = mon("a1", 120, 4)
local keptBefore, lastBefore = L.AIM.Target, L.AIM.LastAttack
turned, model = L.FaceTarget()
check(model == a1 and turned and not ringOn() and L.AIM.Target == keptBefore and L.AIM.LastAttack == lastBefore,
	"auto: turns to the server's pick, no ring, my kept target untouched", tostring(ringOn()))
clear()
face(0)
local m1 = mon("m1", 100, 4)
L.FaceTarget("Swing")
run(0.2)
root.CFrame = cf(root.Position, 0)
turned = L.FaceTarget()
check(turned == false, "auto waits while my own attack keeps a target (KeepFor)", turned)
run(AF.KeepFor)
turned = L.FaceTarget()
check(turned == true, "... then turns again", turned)
clear()

-- 6. the swing / skill send my pick to the server
face(0)
local s1 = mon("s1", 45, 4)
L.SwingFaced()
check(#fired == 1 and fired[1][1] == "Swing" and fired[1][2] == s1, "Swing goes at once with my target (arg 1 = the Model)",
	fired[1] and tostring(fired[1][2] and fired[1][2].Name))
clear()
face(0)
table.clear(fired)
L.SwingFaced()
check(#fired == 1 and fired[1][1] == "Swing" and fired[1][2] == nil, "no monster: Swing still goes (a whiff), no target", #fired)
clear()

-- 7. ServerHint on (once CombatService takes the pick): keep, score, attacker first, nothing behind far
AF.ServerHint = true
face(0)
local A = mon("A", 40, 6)
turned, model = L.FaceTarget("Swing")
check(model == A, "score: the only one", model and model.Name)
run(0.5)
local B = mon("B", 0, 3)
turned, model = L.FaceTarget("Swing")
check(model == A, "keep: the same target while I keep attacking, though a nearer one comes", model and model.Name)
run(AF.KeepFor + 0.1)
turned, model = L.FaceTarget("Swing")
check(model == B, "after KeepFor a new pick (the nearer, centred one)", model and model.Name)
run(0.3)
remove(B)
turned, model = L.FaceTarget("Swing")
check(model == A, "the kept target died: the next one", model and model.Name)
run(0.3)
A.Root.Position = vec(0, 2.5, -6.9) -- beyond Inside x 7 but within 7
turned, model = L.FaceTarget("Swing")
check(model == A, "a kept target stays until it leaves the Range (not Inside)", model and model.Name)
run(0.3)
A.Root.Position = vec(0, 2.5, -7.5)
turned, model = L.FaceTarget("Swing")
check(model == nil, "... and is dropped when it leaves the Range", model and model.Name)
clear()
face(0)
local edge = mon("edge", 0, 7 * (AF.Inside + 0.02))
turned, model = L.FaceTarget("Swing")
check(model == nil, "a NEW pick only a little inside the Range (Inside)", model and model.Name)
clear()
face(0)
local calm = mon("calm", 0, 4)
local hitter = mon("hitter", 70, 6, { Attrs = { WindupAt = SERVER0 + NOW - 0.5 } })
turned, model = L.FaceTarget("Swing")
check(model == hitter, "the monster winding up at me (WindupAt, server time) comes first", model and model.Name)
clear()
face(0)
calm = mon("calm", 0, 4)
hitter = mon("hitter", 70, 6, { Attrs = { WindupAt = SERVER0 + NOW - AF.AttackerFor - 0.5 } })
turned, model = L.FaceTarget("Swing")
check(model == calm, "... but not after AttackerFor s", model and model.Name)
clear()
STATE.Class, STATE.Tier = "Archer", 1 -- Range 30
face(0)
calm = mon("calm", 0, 12)
local farHitter = mon("far hitter", 70, 11, { Attrs = { WindupAt = SERVER0 + NOW } })
turned, model = L.FaceTarget("Swing")
check(model == calm, "a winding-up monster beyond AttackerReach is not 'hitting me'", model and model.Name)
farHitter.Root.Position = vec(8 * math.sin(math.rad(70)), 2.5, -8 * math.cos(math.rad(70)))
run(AF.KeepFor + 0.1)
farHitter.Attrs.WindupAt = SERVER0 + NOW
turned, model = L.FaceTarget("Swing")
check(model == farHitter, "... within AttackerReach it is", model and model.Name)
clear()
STATE.Class, STATE.Tier = "Warrior", nil
face(0)
local behindFar = mon("behind far", 180, 6.5)
turned, model = L.FaceTarget("Swing")
check(model == nil, "behind me farther than BackNear: never picked (even alone)", model and model.Name)
local behindNear = mon("behind near", 180, 4)
turned, model = L.FaceTarget("Swing")
check(model == behindNear, "behind me but close: picked", model and model.Name)
clear()
face(0)
local left = mon("left", -40, 5)
local centre = mon("centre", 40, 5)
camera.CFrame = { LookVector = vec(math.sin(math.rad(40)), 0, -math.cos(math.rad(40))) }
turned, model = L.FaceTarget("Swing")
check(model == centre, "two alike: the one nearer the screen centre", model and model.Name)
clear()
face(0)
local x2 = mon("x2", 80, 6)
local y2 = mon("y2", 100, 2, { Attrs = { WindupAt = SERVER0 + NOW } })
turned, model = L.FaceTarget("Swing")
check(model == y2, "score (manual): the close attacker just behind the side line", model and model.Name)
face(0)
y2.Attrs.WindupAt = SERVER0 + NOW
turned, model = L.FaceTarget()
check(model == x2, "auto keeps the server's aim even with ServerHint (no hint goes with auto swings)", model and model.Name)
clear()
AF.ServerHint = false

-- 8. HUD.PickTarget alone (pure)
local cfgS = { Score = false, Inside = 0.95, BackDot = -0.2, BackNear = 6, WDist = 1, WFront = 0.8, WScreen = 0.5, WAttacker = 1.5 }
check(HUD.PickTarget({}, nil, false, cfgS) == nil, "pure: no candidates = nil")
check(HUD.PickTarget({ { Key = "x", D = 3, Range = 7, Front = false, Dot = -1, CamDot = -1, Attacker = false },
	{ Key = "y", D = 5, Range = 7, Front = true, Dot = 0.1, CamDot = 0, Attacker = false } }, nil, false, cfgS) == "y",
	"pure: server rule takes the front one")
local cfgK = table.clone(cfgS)
cfgK.Score = true
check(HUD.PickTarget({ { Key = "k", D = 7.2, Range = 7, Front = true, Dot = 1, CamDot = 1, Attacker = false },
	{ Key = "n", D = 4, Range = 7, Front = true, Dot = 0.5, CamDot = 0.5, Attacker = false } }, "k", true, cfgK) == "n",
	"pure: a kept target beyond its Range is dropped")
check(HUD.PickTarget({ { Key = "k", D = 6.9, Range = 7, Front = false, Dot = -0.9, CamDot = -0.9, Attacker = false },
	{ Key = "n", D = 2, Range = 7, Front = true, Dot = 1, CamDot = 1, Attacker = true } }, "k", true, cfgK) == "k",
	"pure: a kept target stays within Range though behind me and a better one is near")

print(("AUTO_FACE_SUMMARY checks=%d failed=%d"):format(checks, failed))
