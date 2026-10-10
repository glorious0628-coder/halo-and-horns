"""Skill Q art per class x side (게임성 개발 1, SPEC A23-116, docs/design/skills18_2026-10-10.md), offline.

Runs, in the official Luau CLI, the CURRENT SkillFx.luau with the CURRENT Config.luau and fake Roblox objects: each of
the six Q kits (Halo Slam, Crater Smash, Star Fall, Purple Pop, Feather Rain, Spark Shower) draws (SkillFx.Q -> true)
within the design's budget per cast - moving Parts BIG <= 12 / SMALL <= 8, own particles BIG <= 12 / SMALL <= 6 - every
Part anchored with no collision / query / touch / shadow, every ring line >= 0.6 studs, no Beam / ParticleEmitter with
a streak (VelocityParallel); a kit without art (the artisan guild) and a packet without a side draw nothing (Fx keeps
its old art); a crowded screen leaves another player's cast with its ring only; the hit pops are the nearest 6 x 2
(BIG) / 3 x 1 (SMALL); the heal sparkles only for data.Healed players (up to 5), the steal hearts only when data.Stole
> 0 on my own cast (up to 3 + a pink edge). Static: Fx's Release hands the art to SkillFx.Q and skips its old art when
drawn; ClientMain loads SkillFx before Audio; the move fixes (A23-116 고침 1-4) are in Fx. Mutations: each must be caught.

Usage: py tools/test_skill_fx.py
Report: docs/art/verification_2026-10-10/offline_skill_fx_2026-10-10.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "src/StarterPlayer/StarterPlayerScripts/SkillFx.luau"
FX = ROOT / "src/StarterPlayer/StarterPlayerScripts/Fx.luau"
MAIN = ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_skill_fx_2026-10-10.json"

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
-- vectors
local V = {}
V.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) if m == 0 then return v end return setmetatable({ X = v.X / m, Y = v.Y / m, Z = v.Z / m }, V) end
	return rawget(V, k)
end
local function v3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end
V.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__mul = function(a, b) if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end
V.__div = function(a, b) return v3(a.X / b, a.Y / b, a.Z / b) end
V.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
function V.Cross(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function V.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V.Lerp(a, b, u) return v3(a.X + (b.X - a.X) * u, a.Y + (b.Y - a.Y) * u, a.Z + (b.Z - a.Z) * u) end
local Vector3 = { new = v3, zero = v3(0, 0, 0), xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1) }
local CFm = {}
CFm.__index = CFm
CFm.__add = function(a, b) return setmetatable({ Position = a.Position + b }, CFm) end
CFm.__mul = function(a, b) if getmetatable(b) == CFm then return setmetatable({ Position = a.Position + (b.Position or v3()) }, CFm) end return a.Position + b end
local CFrame = { new = function(p, y, z) if type(p) == "number" then p = v3(p, y, z) end return setmetatable({ Position = p or v3() }, CFm) end,
	Angles = function() return setmetatable({ Position = v3() }, CFm) end,
	lookAt = function(p) return setmetatable({ Position = p }, CFm) end,
	fromMatrix = function(p) return setmetatable({ Position = p }, CFm) end }
local function ctor() return setmetatable({}, { __index = function() return function(...) return { ... } end end }) end
local EnumT = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, v) return k .. "." .. v end }) end })
local base = { Vector3 = Vector3, Vector2 = ctor(), Color3 = ctor(), BrickColor = ctor(), Rect = ctor(), UDim2 = ctor(),
	UDim = ctor(), NumberRange = ctor(), NumberSequence = ctor(), ColorSequence = ctor(), NumberSequenceKeypoint = ctor(),
	ColorSequenceKeypoint = ctor(), CFrame = CFrame, TweenInfo = ctor(), Font = ctor(), Enum = EnumT,
	workspace = { GetServerTimeNow = function() return 1790000000 end } }
-- instances
local created, emits, beams = {}, 0, 0
local Inst = {}
Inst.__index = function(o, k)
	local m = rawget(Inst, k)
	if m then return m end
	for _, ch in rawget(o, "Children") do if ch.Name == k then return ch end end
	return nil
end
Inst.__newindex = function(o, k, v)
	if k == "CFrame" and type(v) == "table" and v.Position then rawset(o, "Position", v.Position) end
	if k == "Parent" then
		local old = rawget(o, "_parent")
		if old then for i, ch in rawget(old, "Children") do if ch == o then table.remove(rawget(old, "Children"), i) break end end end
		rawset(o, "_parent", v)
		if type(v) == "table" and rawget(v, "Children") then table.insert(rawget(v, "Children"), o) end
		return
	end
	rawset(o, k, v)
end
function Inst.IsA(o, c) return rawget(o, "ClassName") == c end
function Inst.Destroy(o) o.Parent = nil rawset(o, "Destroyed", true) end
function Inst.GetDescendants(o)
	local out = {}
	local function walk(x) for _, ch in rawget(x, "Children") do table.insert(out, ch) walk(ch) end end
	walk(o)
	return out
end
function Inst.Clone(o)
	local c = Instance.new(rawget(o, "ClassName"))
	for k, v in o do if k ~= "Children" and k ~= "_parent" then rawset(c, k, v) end end
	return c
end
function Inst.Emit(o, n) emits += n rawset(o, "Emitted", (rawget(o, "Emitted") or 0) + n) end
function Inst.FindFirstChild(o, n, deep)
	for _, ch in rawget(o, "Children") do if ch.Name == n then return ch end end
	if deep then for _, ch in rawget(o, "Children") do local f = Inst.FindFirstChild(ch, n, true) if f then return f end end end
	return nil
end
Instance = { new = function(cls)
	local o = setmetatable({ ClassName = cls, Name = cls, Children = {} }, Inst)
	if cls == "Beam" then beams += 1 end
	table.insert(created, o)
	return o
end }
local ws = Instance.new("Workspace")
rawset(ws, "Terrain", Instance.new("Terrain"))
function ws.Raycast(_, from) return { Position = v3(from.X, 0, from.Z), Normal = v3(0, 1, 0) } end
local cf = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cf, setmetatable(base, { __index = getfenv() }))
local Config = cf()

local TOUCH = false
local pending = {}
local function later(t, fn) table.insert(pending, { T = t, Fn = fn }) end
local function runAll()
	local guard = 0
	while #pending > 0 and guard < 500 do
		guard += 1
		table.sort(pending, function(a, b) return a.T < b.T end)
		local p = table.remove(pending, 1)
		p.Fn()
	end
end
local HEAD = Instance.new("Part")
rawset(HEAD, "Position", v3(0, 5, 0))
local TORSO = Instance.new("Part")
rawset(TORSO, "Position", v3(0, 3, 0))
local ROOT = Instance.new("Part")
rawset(ROOT, "Position", v3(0, 3, 0))
local CHAR = Instance.new("Model")
HEAD.Name, TORSO.Name, ROOT.Name = "Head", "UpperTorso", "HumanoidRootPart"
HEAD.Parent, TORSO.Parent, ROOT.Parent = CHAR, CHAR, CHAR
local ME = { UserId = 7, Character = CHAR }
local services = {
	Players = { LocalPlayer = ME, GetPlayerByUserId = function(_, id) if id == 7 then return ME end return nil end },
	RunService = { RenderStepped = { Connect = function() return { Disconnect = function() end } end } },
	TweenService = { Create = function(_, inst, info, goal)
		return { Play = function() for k, v in goal do inst[k] = v end end, Cancel = function() end }
	end },
	UserInputService = setmetatable({}, { __index = function(_, k) if k == "TouchEnabled" then return TOUCH end end }),
}
local env = {
	game = { GetService = function(_, n) return services[n] end },
	workspace = ws, Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Enum = EnumT,
	RaycastParams = { new = function() return {} end },
	Color3 = base.Color3, ColorSequence = base.ColorSequence, NumberSequence = base.NumberSequence,
	NumberSequenceKeypoint = base.NumberSequenceKeypoint, NumberRange = base.NumberRange, UDim2 = base.UDim2, UDim = base.UDim,
	Vector2 = base.Vector2, TweenInfo = base.TweenInfo,
	task = { delay = function(t, fn) later(t, fn) end, spawn = function(fn) fn() end },
	typeof = function(v)
		if type(v) == "table" and getmetatable(v) == V then return "Vector3" end
		if type(v) == "table" and getmetatable(v) == Inst then return "Instance" end
		return type(v)
	end,
}
local f = assert(loadstring(MOD_SOURCE, "=SkillFx"))
setfenv(f, setmetatable(env, { __index = getfenv() }))
local SkillFx = f()

local MOVING = { Ball = true, Block = true, Ring = true, Disc = true }
local gets = {}
local realGet = SkillFx.Get
SkillFx.Get = function(kind, life)
	local p = realGet(kind, life)
	table.insert(gets, { Kind = kind, Part = p })
	return p
end
local function envFor() return { Muzzle = function() return v3(1, 4, 0) end, After = function(t, fn) later(t, fn) end } end
local function cast(class, faction, own, auto, hits, extra)
	gets, emits = {}, 0
	local data = { Class = class, Faction = faction, UserId = own and 7 or 99, Auto = auto, Hits = hits or {}, LaunchDelay = 0.18 }
	for k, v in extra or {} do data[k] = v end
	local res = SkillFx.Q(data, v3(10, 0, 0), 9, class == "Archer" and 0.4 or (class == "Mage" and 0.35 or 0.24), own, envFor())
	runAll()
	local moving = 0
	for _, g in gets do if MOVING[g.Kind] then moving += 1 end end
	return res, moving, emits
end
local KITS = { { "Warrior", "Halo" }, { "Warrior", "Horns" }, { "Mage", "Halo" }, { "Mage", "Horns" }, { "Archer", "Halo" }, { "Archer", "Horns" } }
for _, k in KITS do
	local name = k[1] .. "_" .. k[2]
	local res, moving, parts = cast(k[1], k[2], true, false)
	check(res == true, name .. ": draws", res)
	check(moving >= 2 and moving <= 12, name .. ": BIG moving parts 2..12", moving)
	check(parts >= 4 and parts <= 12, name .. ": BIG own particles 4..12", parts)
	local okParts = true
	for _, g in gets do
		local p = g.Part
		if not (p.Anchored == true and p.CanCollide == false and p.CanQuery == false and p.CanTouch == false and p.CastShadow == false) then okParts = false end
		if g.Kind == "Ring" or g.Kind == "Disc" then
			local line = p.Face.Round.Line
			if line.Thickness < 0.6 * 40 - 1e-6 then okParts = false end
		end
	end
	check(okParts, name .. ": parts anchored, no collision / query / touch / shadow, ring lines >= 0.6 studs", "")
	local res2, moving2, parts2 = cast(k[1], k[2], true, true)
	check(res2 == true and moving2 <= 8 and parts2 <= 6, name .. ": SMALL (auto) parts <= 8, particles <= 6", moving2 .. "/" .. parts2)
	check(moving2 <= moving and parts2 <= parts, name .. ": SMALL never more than BIG", moving2 .. "/" .. parts2)
	TOUCH = true
	local _, moving3, parts3 = cast(k[1], k[2], true, false)
	TOUCH = false
	check(moving3 <= 8 and parts3 <= 6, name .. ": a phone gets SMALL", moving3 .. "/" .. parts3)
end
check(beams == 0, "no Beam anywhere (no light lines)", beams)
local streak = false
for _, o in created do if rawget(o, "ClassName") == "ParticleEmitter" and o.Orientation ~= nil then streak = true end end
check(not streak, "no streak particles (VelocityParallel)", "")
check(SkillFx.Q({ Class = "Warrior", Faction = "Neutral" }, v3(), 9, 0.24, true, envFor()) == false, "the artisan guild keeps Fx's old art", "")
check(SkillFx.Q({ Class = "Warrior" }, v3(), 9, 0.24, true, envFor()) == false, "no side: nothing", "")
-- the hit pops
local hits = {}
for i = 1, 8 do table.insert(hits, { P = v3(i * 2, 0, 0) }) end
local _, _, withPops = cast("Warrior", "Halo", true, false, hits)
local _, _, without = cast("Warrior", "Halo", true, false, {})
check(withPops - without == 12, "BIG: the nearest 6 hits pop 2 dots each", withPops - without)
local _, _, smallPops = cast("Warrior", "Halo", true, true, hits)
local _, _, smallNone = cast("Warrior", "Halo", true, true, {})
check(smallPops - smallNone == 3, "SMALL: 3 hits, 1 dot each", smallPops - smallNone)
-- signals
local _, _, healed = cast("Warrior", "Halo", true, false, {}, { Healed = { 7 } })
check(healed - without == 3, "a healed player gets 3 gold sparkles", healed - without)
local _, movingSteal = cast("Warrior", "Horns", true, false, hits, { Stole = 5 })
local _, movingNo = cast("Warrior", "Horns", true, false, hits, { Stole = 0 })
check(movingSteal - movingNo == 3, "a real steal: 3 hearts fly from the hits", movingSteal - movingNo)
local hl = 0
for _, o in created do if rawget(o, "ClassName") == "Highlight" then hl += 1 end end
check(hl == 1, "... and one short pink edge on me", hl)
local _, movingOther = cast("Warrior", "Horns", false, false, hits, { Stole = 5 })
local _, movingOther0 = cast("Warrior", "Horns", false, false, hits, { Stole = 0 })
check(movingOther == movingOther0, "another player's steal: no hearts on my screen", movingOther .. "/" .. movingOther0)
-- crowded screen
for _ = 1, 70 do realGet("Ball", 1000) end
local resC, movingC = cast("Mage", "Halo", false, false, {})
check(resC == true and movingC == 1, "a crowded screen: another player's cast = its ring only", movingC)
local _, movingMine = cast("Mage", "Halo", true, false, {})
check(movingMine > 1, "... my own cast still draws all", movingMine)
-- Z (A23-116 Z stage)
local function zcast(class, faction, own, auto, extra)
	gets, emits = {}, 0
	local data = { Class = class, Faction = faction, UserId = own and 7 or 99, Auto = auto, Hits = {}, From = v3(0, 0, 0),
		Dir = v3(0, 0, -1), Len = class == "Archer" and 40 or 22, Width = class == "Archer" and 4 or 10, LaunchDelay = 0.18,
		Points = { v3(0, 0, -10), v3(5, 0, -15), v3(10, 0, -18), v3(14, 0, -22) } }
	for k, v in extra or {} do data[k] = v end
	local res = SkillFx.Z(data, own, envFor())
	runAll()
	local moving = 0
	for _, g in gets do if MOVING[g.Kind] then moving += 1 end end
	return res, moving, emits
end
for _, k in KITS do
	local name = "Z " .. k[1] .. "_" .. k[2]
	local res, moving, parts = zcast(k[1], k[2], true, false)
	check(res == true and moving >= 2 and moving <= 12, name .. ": draws, BIG moving parts 2..12", moving)
	check(parts >= 4 and parts <= 24, name .. ": BIG particles (own 12 + pops 12)", parts)
	local _, moving2, parts2 = zcast(k[1], k[2], true, true)
	check(moving2 <= 8 and parts2 <= 9, name .. ": SMALL parts <= 8, particles <= 6 + 3 pops", moving2 .. "/" .. parts2)
	local ok = true
	for _, g in gets do
		local p = g.Part
		if not (p.Anchored == true and p.CanCollide == false and p.CanQuery == false and p.CanTouch == false) then ok = false end
	end
	check(ok, name .. ": parts anchored, no collision / query / touch", "")
end
check(beams == 0, "Z: still no Beam", beams)
check(SkillFx.Z({ Class = "Mage", Faction = "Neutral", From = v3() }, true, envFor()) == false, "Z: the artisan guild draws nothing here", "")
check(SkillFx.Z({ Class = "Mage", Faction = "Halo" }, true, envFor()) == false, "Z: no From, nothing", "")
local mid = SkillFx.PathAt({ v3(0, 0, 0), v3(10, 0, 0) }, { 0, 1 }, 0.5, 3)
check(math.abs(mid.X - 5) < 1e-6 and math.abs(mid.Y - 3) < 1e-6, "the bird hops in a 3-stud arc", mid.Y)
local dash = SkillFx.PathAt({ v3(0, 0, 0), v3(10, 0, 0) }, { 0, 1 }, 0.5, 0)
check(math.abs(dash.Y) < 1e-6, "the bat dashes straight", dash.Y)
check(SkillFx.PathAt({ v3(0, 0, 0), v3(10, 0, 0) }, { 0, 1 }, 2, 3).X == 10, "past the end: the last point", "")
print(("SKILLFX_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("BIG and SMALL swapped", "local budget = big and T.Budget.Big or T.Budget.Small", "local budget = big and T.Budget.Small or T.Budget.Big"),
    ("phones get BIG", "local big = own and data.Auto ~= true and not UserInputService.TouchEnabled\n\tlocal budget", "local big = own and data.Auto ~= true\n\tlocal budget"),
    ("thin ring lines", "local thick = math.max(0.6, num(o.Thick, 0.8))", "local thick = num(o.Thick, 0.8) * 0.5"),
    ("every hit pops", "for i = 1, math.min(#list, budget.Pops) do", "for i = 1, #list do"),
    ("a fake heal", "for i, uid in data.Healed do", "for i, uid in { 7, 7 } do"),
    ("a steal with nothing stolen", "if stole > 0 and root and type(data.Hits) == \"table\" then", "if root and type(data.Hits) == \"table\" then"),
    ("others' steals drawn", "local root = own and LocalPlayer.Character", "local root = LocalPlayer.Character"),
    ("no crowd limit", "if not own and S.Live > T.ScreenParts then", "if false then"),
    ("the artisan guild drawn", "local kit = key and Q[key]", "local kit = key and (Q[key] or Q.Warrior_Halo)"),
    ("parts collide", "p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false",
     "p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, true, false, false, false"),
    ("all rain dots on SMALL", "if i <= dots then", "if true then"),
    ("no arc in hops", "return p + Vector3.new(0, (arc or 0) * math.sin(math.pi * u), 0)", "return p"),
    ("SMALL fire rake with rims", "\t\t\t\tif c.Big then\n\t\t\t\t\tlocal rim", "\t\t\t\tif true then\n\t\t\t\t\tlocal rim"),
    ("Z for the artisan guild", "local kit = key and Z[key]", "local kit = key and (Z[key] or Z.Mage_Halo)"),
]
STATIC = [
    ("Fx's Release hands the art to SkillFx.Q", lambda fx, m: "local okQ, res = pcall(sfx.Q, data, pos, radius, impactDelay, own, {" in fx),
    ("... and skips its old art when drawn", lambda fx, m: "elseif drawn then" in fx
     and "if not drawn then ring(pos, radius, color, { Grow = 0.25, Fade = 0.45" in fx and "if drawn then\n\t\t\t\t-- SkillFx drew the impact" in fx),
    ("an archer's drawn shot still lets the string go", lambda fx, m: "elseif drawn and classId == \"Archer\" then" in fx),
    ("ClientMain loads SkillFx before Audio", lambda fx, m: '"LandShadow", "SkillFx", "Audio" }' in m),
    ("고침 1: only a swing waits for a skill move", lambda fx, m: 'if which == "Swing" and st and Feel.Active[st] and Feel.validAttack(st.AttackContext)' in fx),
    ("고침 2: a cut blends CUT_BLEND s from the last pose", lambda fx, m: "st.BlendFrom, st.BlendAt = table.clone(st.Last), os.clock()" in fx
     and "outputs[joint] = from:Lerp(out, blendW)" in fx and "CUT_BLEND = 0.06" in fx),
    ("고침 3: the shot time by the slot", lambda fx, m: "current.Layers.Attack.Which = which" in fx and 'local release = attack.Which == "Release"' in fx),
    ("고침 4: the Spark Shower's second draw / release", lambda fx, m: "function Feel.secondShot(ctx, st, clip, rate)" in fx
     and "if clip.Redraw and clip.Shot2 then Feel.secondShot(context, current, clip, rate) end" in fx
     and "ShadowHunterRelease = { Len = 0.44, Redraw = 0.2, Shot2 = 0.3," in fx
     and "Joints = joints, Redraw = def.Redraw, Shot2 = def.Shot2 }" in fx),
    ("Fx's Skill hands the Z art to SkillFx.Z (near the camera)", lambda fx, m: 'if slot == "Z" and type(sfx) == "table" and type(sfx.Z) == "function" and at and nearCamera(at) then' in fx),
    ("the Horns side's Q moves", lambda fx, m: 'Warrior_Horns = { Release = "BerserkerRelease", Z = "BerserkerZ" }' in fx and 'Mage_Horns = { Release = "DarkMageRelease", Z = "DarkMageZ" }' in fx
     and 'Archer_Horns = { Release = "ShadowHunterRelease", Z = "ShadowHunterZ" }' in fx and 'Archer_Halo = { Release = "RangerRelease", Z = "RangerZ" }' in fx),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(mod: str, config: str) -> tuple[int, int, str]:
    text = "local CONFIG_SOURCE = " + lua_str(config) + "\nlocal MOD_SOURCE = " + lua_str(mod) + "\n" + FIXTURE
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "skillfx.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=180)
    out = proc.stdout + proc.stderr
    m = re.search(r"SKILLFX_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (int(m[1]) if m else 0), (int(m[2]) if m else 1), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    mod = MOD.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    fx = FX.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    main_src = MAIN.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    config = (ROOT / "src/ReplicatedStorage/Shared/Config.luau").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    checks, failed, out = run(mod, config)
    print(out.strip())
    statics = [{"check": n, "ok": bool(fn(fx, main_src))} for n, fn in STATIC]
    for s in statics:
        print(("STATIC_OK  " if s["ok"] else "STATIC_FAIL ") + s["check"])
    muts = []
    for name, old, new in MUTATIONS:
        hits = mod.count(old)
        caught = hits == 1 and run(mod.replace(old, new), config)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    ok = failed == 0 and checks > 0 and all(s["ok"] for s in statics) and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "static": statics, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
