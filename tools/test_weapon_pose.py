"""Weapon hold poses (게임성 개발 1, SPEC A23-108 ①③), offline.

Runs, in the official Luau CLI, the CURRENT Config.luau (Config.ClassGrips / Config.ClassGripKey) and the pure parts of
WeaponPose.luau (HoldFor, Angles). Checks: all nine class x faction rows with a weapon, a walk share and a hold of real
R15 joints and sane angles (|deg| <= 120); the three sides of a class hold differently (A23-108: not one pose recoloured);
the key and the fallback for a side not chosen; Angles scales by the fade weight and keeps only Walk of the shoulders'
forward raise while walking. Static: Fx.Animating (the pose steps aside during attack / hurt clips), WeaponPose writes in
PreSimulation and is loaded after Fx. Mutations: each must be caught. The look itself is checked in Studio photos
(메인 반영 1: 9 classes x stand / walk / attack / Q).

Usage: py tools/test_weapon_pose.py
Report: docs/art/verification_2026-10-10/offline_weapon_pose_2026-10-10.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"WP": SPS / "WeaponPose.luau", "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "FX": SPS / "Fx.luau", "MAIN": SPS / "ClientMain.client.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_weapon_pose_2026-10-10.json"

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local function vec(x, y, z) return { X = x or 0, Y = y or 0, Z = z or 0 } end
local base = { Vector3 = { new = vec, zero = vec() }, Vector2 = { new = vec }, Color3 = { new = vec, fromRGB = vec, fromHSV = vec },
	BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), UDim2 = ctor("UDim2"), UDim = ctor("UDim"),
	NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"),
	NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"), ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"),
	CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"), Font = ctor("Font"), Enum = enum }
local cfgEnv = setmetatable(table.clone(base), { __index = getfenv() })
cfgEnv.workspace = { GetServerTimeNow = function() return 1790000000 end }
local cf = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cf, cfgEnv)
local Config = cf()
local env = setmetatable(table.clone(base), { __index = getfenv() })
env.game = { GetService = function(_, n)
	if n == "ReplicatedStorage" then return { WaitForChild = function() return { WaitForChild = function(_, m) return m end } end } end
	return {}
end }
env.require = function(m) if m == "Config" then return Config end return { Warn = function() end } end
local f = assert(loadstring(WP_SOURCE, "=WeaponPose"))
setfenv(f, env)
local WP = f()

local JOINTS = { Waist = true, Neck = true, RightShoulder = true, RightElbow = true, RightWrist = true, LeftShoulder = true,
	LeftElbow = true, LeftWrist = true }
local G = Config.ClassGrips
local rows = 0
for _, class in { "Warrior", "Mage", "Archer" } do
	for _, side in { "Halo", "Horns", "Neutral" } do
		local key = Config.ClassGripKey(class, side)
		local d = G[key]
		local ok = type(d) == "table" and type(d.Weapon) == "string" and type(d.Walk) == "number" and d.Walk > 0 and d.Walk <= 1
			and type(d.Hold) == "table" and next(d.Hold) ~= nil
		for j, a in type(d) == "table" and type(d.Hold) == "table" and d.Hold or {} do
			if not JOINTS[j] or type(a) ~= "table" or #a ~= 3 then ok = false end
			for _, v in type(a) == "table" and a or {} do if math.abs(v) > 120 then ok = false end end
		end
		if ok then rows += 1 end
		check(ok, "a full row for every class x side (weapon, walk share, real joints, |deg| <= 120)", key)
	end
	local sig = {}
	for _, side in { "Halo", "Horns", "Neutral" } do
		local d = G[class .. "_" .. side]
		local parts = {}
		for j, a in d and d.Hold or {} do table.insert(parts, j .. "=" .. table.concat(a, ",")) end
		table.sort(parts)
		sig[side] = (d and d.Weapon or "") .. "|" .. table.concat(parts, ";")
	end
	check(sig.Halo ~= sig.Horns and sig.Horns ~= sig.Neutral and sig.Halo ~= sig.Neutral,
		"the three sides of a class hold differently (and the weapon differs)", class)
end
check(rows == 9, "nine rows", rows)
check(Config.ClassGripKey("Mage", "Horns") == "Mage_Horns" and Config.ClassGripKey("Mage", "None") == "Mage"
	and Config.ClassGripKey(nil, "Halo") == nil, "the key: class_side, a class alone without a side", "")
check(WP.HoldFor("Mage", "Horns") == G.Mage_Horns and WP.HoldFor("Archer", "Neutral") == G.Archer_Neutral,
	"HoldFor picks its own row", "")
check(WP.HoldFor("Warrior", nil) == G.Warrior_Halo and WP.HoldFor("Nope", "Halo") == nil, "no side yet: the Halo row; unknown class: none", "")
local d = G.Warrior_Neutral -- 검수 10/11: the Paladin's arms are placed from the sword now (OneHand / OffHand)
local a = WP.Angles(d, "RightShoulder", 1, false)
check(a and a[1] == d.Hold.RightShoulder[1] and a[3] == d.Hold.RightShoulder[3], "Angles at full weight = the hold", a and a[1])
a = WP.Angles(d, "RightShoulder", 0.5, false)
check(a and math.abs(a[1] - d.Hold.RightShoulder[1] * 0.5) < 1e-9, "half faded in = half the angles", a and a[1])
a = WP.Angles(d, "RightShoulder", 1, true)
check(a and math.abs(a[1] - d.Hold.RightShoulder[1] * d.Walk) < 1e-9 and a[3] == d.Hold.RightShoulder[3],
	"walking keeps Walk of the shoulder's forward raise (its side swing stays)", a and a[1])
a = WP.Angles(d, "RightElbow", 1, true)
check(a and a[1] == d.Hold.RightElbow[1], "walking leaves the elbows alone", a and a[1])
check(WP.Angles(d, "Neck", 1, false) == nil and WP.Angles(nil, "Neck", 1, false) == nil, "a joint the hold does not move: none", "")
print(("POSE_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("WP", "no fade (a jump)", "return { rx * w, (tonumber(a[2]) or 0) * w, (tonumber(a[3]) or 0) * w }",
     "return { rx, tonumber(a[2]) or 0, tonumber(a[3]) or 0 }"),
    ("WP", "walking changes nothing", "((moving and T.Shoulders[joint]) and math.clamp(tonumber(def.Walk) or 1, 0, 1) or 1)", "1"),
    ("WP", "walking bends every joint", "(moving and T.Shoulders[joint])", "moving"),
    ("WP", "no fallback without a side", '\tif type(def) ~= "table" and type(classId) == "string" then def = grips[classId .. "_Halo"] end\n', ""),
    ("WP", "the pose fights the attack clips", "\tif animating(char) then -- Fx's attack / hurt clip owns the joints now\n",
     "\tif false then\n"),
    ("CONFIG", "two sides share a pose", '''	Warrior_Neutral = { Weapon = "Hammer", Walk = 0.6, Hold = { RightShoulder = { 18, 0, 10 }, RightElbow = { 68, 0, 0 } },
		OffHand = { At = Vector3.new(-1.25, -0.65, 0.1), Up = Vector3.new(-0.75, 0.5, 0.4), Fwd = Vector3.new(0, 0, -1) } },''', '''	Warrior_Neutral = { Weapon = "GreatSword", Walk = 0.5, Hold = { Waist = { 5, 0, 0 } },
		TwoHand = { Hilt = Vector3.new(0.25, 0.2, -0.7), Aim = Vector3.new(0.85, 0.85, 0.75), Gap = { 0.45, 0.8 } } },'''),
    ("MAIN", "never loaded", '"QuickSlots", "WeaponPose", "LandShadow"', '"QuickSlots", "LandShadow"'),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def statics(src: dict) -> list[dict]:
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    return [
        {"check": "Fx.Animating(char) = an attack / hurt clip plays there", "ok": "function Fx.Animating(char)" in src["FX"]
         and "return st ~= nil and Feel.Active[st] == true" in src["FX"]},
        {"check": "the pose steps aside while Fx animates", "ok": "if animating(char) then" in src["WP"]},
        {"check": "it writes in PreSimulation (after the Animator, like Fx's clips)", "ok": "sig = RunService.PreSimulation" in src["WP"]},
        {"check": "메인 반영 10/10: upgraded avatar joints (AnimationConstraint) are found, preferred over a Motor6D", "ok":
         'if d:IsA("AnimationConstraint") then' in src["WP"] and "a1.Parent == part and a0.Parent == parent" in src["WP"]
         and 'if d:IsA("AnimationConstraint") then return d end' in src["WP"]},
        {"check": "ClientMain loads WeaponPose after Fx", "ok": "WeaponPose" in names and "Fx" in names
         and names.index("WeaponPose") > names.index("Fx")},
    ]


def run(src: dict) -> tuple[int, int, str, list]:
    text = "local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal WP_SOURCE = " + lua_str(src["WP"]) + "\n" + FIXTURE
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "pose.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"POSE_SUMMARY checks=(\d+) failed=(\d+)", out)
    st = statics(src)
    return (int(m[1]) if m else 0), (int(m[2]) if m else 1) + sum(0 if s["ok"] else 1 for s in st), out, st


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    checks, failed, out, st = run(src)
    print(out.strip())
    for s in st:
        print(("STATIC_OK  " if s["ok"] else "STATIC_FAIL ") + s["check"])
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        caught = False
        if hits == 1:
            m = dict(src)
            m[key] = src[key].replace(old, new)
            caught = run(m)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    ok = failed == 0 and checks > 0 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "static": st, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
