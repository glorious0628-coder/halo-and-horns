"""Big landing ground shadow (게임성 개발 1, SPEC A23-113 ①), offline.

Runs, in the official Luau CLI, the CURRENT LandShadow.luau (Plan / Look / Check / Step) with the CURRENT Config.luau and
fake Roblox objects: a monster's DropAt + DropTime draws one round disc (a Cylinder Part, Anchored, no collision /
query / touch / shadow) of DropRadius (else Config.LandShadow.Radius by MonsterKind, else Default) at DropPos (else the
ground under the root); it darkens from StartAlpha to EndAlpha up to the landing while the inner disc grows to the rim,
then fades and is removed; the same DropAt never draws twice, a new DropAt draws again; another player's personal
monster, a warning already over and one beyond MaxDistance draw nothing; DropTime is clamped to MaxTime. Static: ClientMain
loads it; it watches DropAt on workspace.Monsters; no text, no rays (no Beam / Billboard / TextLabel / ParticleEmitter).
Mutations: each must be caught.

Usage: py tools/test_land_shadow.py
Report: docs/art/verification_2026-10-10/offline_land_shadow_2026-10-10.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "src/StarterPlayer/StarterPlayerScripts/LandShadow.luau"
MAIN = ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_land_shadow_2026-10-10.json"

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local V3 = {}
V3.__index = V3
V3.__add = function(a, b) return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, V3) end
V3.__sub = function(a, b) return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z }, V3) end
V3.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	return rawget(V3, k)
end
local Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end }
local function ctor() return setmetatable({}, { __index = function() return function(...) return { ... } end end }) end
local EnumT = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, v) return k .. "." .. v end }) end })
local base = { Vector3 = Vector3, Vector2 = ctor(), Color3 = ctor(), BrickColor = ctor(), Rect = ctor(), UDim2 = ctor(),
	UDim = ctor(), NumberRange = ctor(), NumberSequence = ctor(), ColorSequence = ctor(), NumberSequenceKeypoint = ctor(),
	ColorSequenceKeypoint = ctor(), CFrame = ctor(), TweenInfo = ctor(), Font = ctor(), Enum = EnumT,
	workspace = { GetServerTimeNow = function() return 1790000000 end } }
local cf = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cf, setmetatable(base, { __index = getfenv() }))
local Config = cf()
local T = Config.LandShadow

local NOW = 1000
local MY = Vector3.new(0, 3, 0)
local parts = {}
local function newInst(cls)
	local o = { ClassName = cls, Children = {}, Transparency = 0 }
	function o:Destroy() self.Parent = nil self.Destroyed = true end
	function o:FindFirstChild(n) return self.Children[n] end
	if cls == "Part" then table.insert(parts, o) end
	return o
end
local wsFolder = nil
local ws = {
	Terrain = {},
	GetServerTimeNow = function() return NOW end,
	FindFirstChild = function(_, n) if n == "LandShadows" then return wsFolder end return nil end,
	Raycast = function(_, from, dir) return { Position = Vector3.new(from.X, 0, from.Z) } end,
}
local CF = { new = function(v) return { P = v } end, Angles = function() return { Rot = true } end }
setmetatable(CF, { __index = function() return function() return {} end end })
local cfMeta = { __mul = function(a, b) return { P = a.P, Rot = b.Rot } end }
local CFrame = { new = function(v) return setmetatable({ P = v }, cfMeta) end, Angles = function() return setmetatable({ Rot = true }, cfMeta) end }
local Instance = { new = function(cls)
	local o = newInst(cls)
	if cls == "Folder" then wsFolder = o end
	return o
end }
local LocalPlayer = { UserId = 7, Character = { FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return { Position = MY } end end } }
local function service(name)
	if name == "Players" then return { LocalPlayer = LocalPlayer } end
	if name == "ReplicatedStorage" then return { WaitForChild = function() return { WaitForChild = function(_, n) return n end } end } end
	return { RenderStepped = { Connect = function() end } }
end
local GroundDouble = { Cast = function(pos, up, down) -- Shared.Ground double: the same ray on the workspace double
	return ws:Raycast(pos + Vector3.new(0, up or 3, 0), Vector3.new(0, -(down or 80), 0))
end }
local env = {
	game = { GetService = function(_, n) return service(n) end },
	require = function(n) if n == "Ground" then return GroundDouble end return Config end,
	workspace = ws, Vector3 = Vector3, CFrame = CFrame, Instance = Instance, Enum = EnumT, typeof = function(v)
		if type(v) == "table" and getmetatable(v) == V3 then return "Vector3" end
		return type(v)
	end,
	RaycastParams = { new = function() return {} end },
	Color3 = base.Color3,
}
local f = assert(loadstring(MOD_SOURCE, "=LandShadow"))
setfenv(f, setmetatable(env, { __index = getfenv() }))
local LS = f()

local function monster(attrs)
	local m = { Parent = {}, Name = attrs.Name or "SlimeKing", Attr = attrs, PrimaryPart = { Position = attrs.Root or Vector3.new(4, 3, 0) } }
	function m:GetAttribute(n) return self.Attr[n] end
	function m:FindFirstChild() return nil end
	return m
end
local function live() return LS.Live() end

-- the first-KO King: DropAt + DropTime only
local k = monster({ DropAt = 1000, DropTime = 1.2, MonsterKind = "SlimeKing" })
LS.Check(k)
check(live() == 1, "a DropAt draws a circle", live())
LS.Check(k)
check(live() == 1 and #parts == 2, "the same DropAt never draws twice (checked again while it shows)", #parts)
local outer, inner = parts[1], parts[2]
check(outer and outer.Shape == "PartType.Cylinder" and outer.Anchored and not outer.CanCollide and not outer.CanQuery
	and not outer.CanTouch and not outer.CastShadow, "a round flat disc, anchored, no collision / query / touch / shadow", "")
check(outer and outer.Size and math.abs(outer.Size.Y - 2 * T.Radius.SlimeKing) < 1e-6, "the King's radius from Config (no DropRadius)", outer and outer.Size and outer.Size.Y)
check(outer and outer.CFrame and outer.CFrame.P and math.abs(outer.CFrame.P.X - 4) < 1e-6 and outer.CFrame.P.Y < 0.5,
	"on the ground under the King", outer and outer.CFrame and outer.CFrame.P and outer.CFrame.P.Y)
local a0 = outer.Transparency
check(math.abs(a0 - T.StartAlpha) < 1e-6, "faint at the start", a0)
NOW = 1000.6
LS.Step()
local mid = outer.Transparency
check(mid < a0 and mid > T.EndAlpha, "darker half way", mid)
check(inner.Size and inner.Size.Y > T.Radius.SlimeKing * 0.8 and inner.Size.Y < T.Radius.SlimeKing * 1.2, "the inner disc half grown half way", inner.Size and inner.Size.Y)
NOW = 1001.2
LS.Step()
check(math.abs(outer.Transparency - T.EndAlpha) < 1e-6, "darkest at the landing", outer.Transparency)
check(math.abs(inner.Size.Y - 2 * T.Radius.SlimeKing) < 1e-6, "the inner disc at the rim at the landing", inner.Size.Y)
NOW = 1001.2 + T.Linger + T.Fade * 0.5
LS.Step()
check(outer.Transparency > T.EndAlpha and outer.Transparency < 1 and live() == 1, "then fades", outer.Transparency)
NOW = 1001.2 + T.Linger + T.Fade + 0.01
LS.Step()
check(live() == 0 and outer.Destroyed and inner.Destroyed, "and is gone", live())
LS.Check(k)
check(live() == 0, "the same DropAt never draws twice", live())
k.Attr.DropAt = 1003
NOW = 1003
LS.Check(k)
check(live() == 1, "a new DropAt draws again", live())
NOW = 1010
LS.Step()

-- the server's own radius and spot; clamps
local n0 = #parts
local b = monster({ DropAt = 1010, DropTime = 9, DropRadius = 15, DropPos = Vector3.new(20, 1, 5), MonsterKind = "PumpkinKing" })
LS.Check(b)
local o2 = parts[n0 + 1]
check(o2 and math.abs(o2.Size.Y - 30) < 1e-6, "DropRadius wins", o2 and o2.Size.Y)
check(o2 and math.abs(o2.CFrame.P.X - 20) < 1e-6 and math.abs(o2.CFrame.P.Z - 5) < 1e-6, "DropPos wins", "")
local plan = LS.Plan({ DropAt = 0, DropTime = 9 }, 0)
check(plan and math.abs(plan.Land - T.MaxTime) < 1e-6, "DropTime is clamped to MaxTime", plan and plan.Land)
plan = LS.Plan({ DropAt = 0, DropTime = 1, Kind = "CaptainClatter" }, 0)
check(plan and plan.Radius == T.Radius.CaptainClatter, "Captain Clatter's radius by kind", plan and plan.Radius)
plan = LS.Plan({ DropAt = 0, DropTime = 1, Kind = "Goblin" }, 0)
check(plan and plan.Radius == T.Radius.Default, "any other kind: Default", plan and plan.Radius)
check(LS.Plan({ DropAt = 0, DropTime = 0 }, 0) == nil and LS.Plan({ DropTime = 1 }, 0) == nil, "no DropTime / DropAt: nothing", "")
NOW = 1030
LS.Step()

-- what draws nothing
local before = live()
LS.Check(monster({ DropAt = 1030, DropTime = 1, OwnerUserId = 99 }))
check(live() == before, "another player's personal monster: nothing", live())
LS.Check(monster({ DropAt = 1030, DropTime = 1, OwnerUserId = 7 }))
check(live() == before + 1, "my own personal King: drawn", live())
local np = #parts
LS.Check(monster({ DropAt = 1020, DropTime = 1 }))
check(live() == before + 1 and #parts == np, "a warning already over (streamed in late): nothing", #parts - np)
LS.Check(monster({ DropAt = 1030, DropTime = 1, Root = Vector3.new(500, 3, 0) }))
check(live() == before + 1, "beyond MaxDistance: nothing", live())
print(("SHADOW_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("no darkening", "local alpha = a0 + (a1 - a0) * k", "local alpha = a0"),
    ("the inner disc never grows", "local d = math.max(p.Radius * 2 * k, 0.05)", "local d = math.max(p.Radius * 2, 0.05)"),
    ("never removed", "if done or not p.Outer.Parent then", "if false then"),
    ("draws twice", "if type(at) ~= \"number\" or S.Seen[model] == at then return end", "if type(at) ~= \"number\" then return end"),
    ("others' personal monsters drawn", "if owner ~= nil and owner ~= LocalPlayer.UserId then return end", ""),
    ("late warnings drawn", "if now >= land + num(T.Linger, 0.15) then return nil end", ""),
    ("no MaxDistance", "if me and (me - spot).Magnitude > num(T.MaxDistance, 160) then return end", ""),
    ("DropRadius ignored", "local r = num(a.DropRadius, nil) or", "local r ="),
    ("DropPos ignored", "if typeof(spot) ~= \"Vector3\" then", "if true then"),
    ("no clamp", "dur = math.min(dur, num(T.MaxTime, 3))", ""),
    ("collides", "p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false",
     "p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, true, false, false, false"),
    ("no fade", "alpha += (1 - alpha) * (after / fade)", ""),
]
STATIC = [
    ("ClientMain loads LandShadow", lambda m, s: '"WeaponPose", "LandShadow", "SkillFx", "Audio" }' in m),
    ("watches DropAt on workspace.Monsters", lambda m, s: 'workspace:WaitForChild("Monsters", 30)' in s
     and 'model:GetAttributeChangedSignal("DropAt")' in s and "monsters.ChildAdded:Connect" in s),
    ("no text, no rays (no Beam / Billboard / TextLabel / ParticleEmitter / Decal)",
     lambda m, s: not any(w in s for w in ('"Beam"', '"BillboardGui"', '"TextLabel"', '"ParticleEmitter"', '"Decal"', '"SurfaceGui"'))),
    ("a round disc (Cylinder), steps every frame", lambda m, s: "p.Shape = Enum.PartType.Cylinder" in s and "RunService.RenderStepped:Connect" in s),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(mod: str, config: str) -> tuple[int, int, str]:
    text = "local CONFIG_SOURCE = " + lua_str(config) + "\nlocal MOD_SOURCE = " + lua_str(mod) + "\n" + FIXTURE
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "shadow.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"SHADOW_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (int(m[1]) if m else 0), (int(m[2]) if m else 1), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    mod = MOD.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    main_src = MAIN.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    checks, failed, out = run(mod, config)
    print(out.strip())
    statics = [{"check": n, "ok": bool(fn(main_src, mod))} for n, fn in STATIC]
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
