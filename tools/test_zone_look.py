"""ZoneLook offline check (A23-30 zone moods; A23-45 haunted hollow dusk, review 2026-10-06).

Runs the CURRENT src/StarterPlayer/StarterPlayerScripts/ZoneLook.luau with the installed official Luau CLI
(build/luau_cli_0_741) against small doubles (Color3 with Lerp, Lighting / Players / RunService / ReplicatedStorage
stand-ins, a Config with the three war skies) and checks ZoneLook.TargetFor, the pure goal of a zone over a base:
- every zone keeps the base ClockTime / fog except the haunted hollow (Dusk), which on a daytime base turns the clock to
  its dusk, greys the fog in (purple-navy, nearer FogEnd) and dims the sun, with a blue ambient lift; a night base keeps
  its night clock; the meadow is the base itself (factor 1)
- the factor maths (Brightness x Bright, Ambient x Amb, exposure + Exp) for the hollow, and ZoneLook.Blend half way into
  / out of the hollow (the eased dusk weight)
- quality 7 (2026-10-07): the horns den's lighter numbers and its NightExp (+1.9 exposure under the Eclipse sky only;
  no other zone gets a night lift)
No Studio, network or Roblox API calls. Mutations break in-memory copies of ZoneLook; each must be caught.

Usage: py tools/test_zone_look.py [--no-mutations]
Report: docs/art/verification_2026-10-06/offline_zone_look_2026-10-06.json
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src/StarterPlayer/StarterPlayerScripts/ZoneLook.luau"
OUT = ROOT / "docs/art/verification_2026-10-06/offline_zone_look_2026-10-06.json"

HARNESS = r'''
local checks, failed, named, order = 0, 0, {}, {}
local function check(name, ok, detail)
	checks += 1
	local n = named[name]
	if not n then n = { Name = name, Fail = 0 }; named[name] = n; table.insert(order, name) end
	if not ok then
		failed += 1
		n.Fail += 1
		n.First = n.First or tostring(detail)
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end
local cmt = {}
cmt.__index = { Lerp = function(a, b, t) return setmetatable({ R = a.R + (b.R - a.R) * t, G = a.G + (b.G - a.G) * t,
	B = a.B + (b.B - a.B) * t, __kind = "Color3" }, cmt) end }
local function c3(r, g, b) return setmetatable({ R = r, G = g, B = b, __kind = "Color3" }, cmt) end
local Color3 = { new = c3, fromRGB = function(r, g, b) return c3(r / 255, g / 255, b / 255) end }
local function typeofD(v) return type(v) == "table" and rawget(v, "__kind") or type(v) end
local sig = { Connect = function() return { Disconnect = function() end } end }
local inst = setmetatable({}, { __index = function() return function() return sig end end })
local Lighting = { Brightness = 2, Ambient = c3(0.43, 0.42, 0.42), OutdoorAmbient = c3(0.5, 0.49, 0.49),
	ExposureCompensation = -0.2, EnvironmentSpecularScale = 0.6, ClockTime = 14.2, FogColor = c3(0.8, 0.84, 0.9),
	FogStart = 250, FogEnd = 1100, GetPropertyChangedSignal = function() return sig end,
	FindFirstChild = function() return nil end }
local Config = { Sky = { TweenTime = 3,
	Neutral = { ClockTime = 14.2, Brightness = 2.0, Ambient = Color3.fromRGB(110, 108, 106), OutdoorAmbient = Color3.fromRGB(128, 126, 124),
		FogColor = Color3.fromRGB(205, 215, 230), FogStart = 250, FogEnd = 1100, ExposureCompensation = -0.2 },
	Dawn = { ClockTime = 7.2, Brightness = 2.1, Ambient = Color3.fromRGB(128, 112, 92), OutdoorAmbient = Color3.fromRGB(150, 130, 104),
		FogColor = Color3.fromRGB(255, 220, 150), FogStart = 120, FogEnd = 650 },
	Eclipse = { ClockTime = 0.5, Brightness = 1.4, Ambient = Color3.fromRGB(100, 62, 78), OutdoorAmbient = Color3.fromRGB(115, 76, 92),
		FogColor = Color3.fromRGB(90, 10, 20), FogStart = 120, FogEnd = 650 } } }
local game = { GetService = function(_, name)
	if name == "Lighting" then return Lighting end
	if name == "Players" then return { LocalPlayer = { GetAttribute = function() return nil end, GetAttributeChangedSignal = function() return sig end } } end
	if name == "RunService" then return { Heartbeat = sig, IsStudio = function() return false end } end
	if name == "ReplicatedStorage" then return { WaitForChild = function() return { WaitForChild = function() return "Config" end } end,
		FindFirstChild = function() return nil end } end
	return inst
end }
local env = setmetatable({ game = game, Color3 = Color3, typeof = typeofD, require = function() return Config end,
	workspace = { Terrain = { FindFirstChildOfClass = function() return nil end } }, Instance = { new = function() return {} end } },
	{ __index = getfenv() })
local fn = assert(loadstring(ZONELOOK_SOURCE, "=ZoneLook"))
setfenv(fn, env)
local ZoneLook = fn()
local function base(sky)
	local p = Config.Sky[sky]
	return { Brightness = p.Brightness, Ambient = p.Ambient, OutdoorAmbient = p.OutdoorAmbient,
		ExposureCompensation = p.ExposureCompensation or 0, EnvironmentSpecularScale = 0.6, ClockTime = p.ClockTime,
		FogColor = p.FogColor, FogStart = p.FogStart, FogEnd = p.FogEnd }
end
local function near(a, b, e) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (e or 1e-6) end
local function sameColor(a, b) return a and b and near(a.R, b.R, 1e-4) and near(a.G, b.G, 1e-4) and near(a.B, b.B, 1e-4) end

-- every zone but the hollow keeps the war sky's clock and fog
for _, z in { "SlimeMeadow", "Crossroads", "GoblinWoods", "SkeletonRuins", "PumpkinPatch", "HaloTown", "HornsTown" } do
	for _, sky in { "Neutral", "Dawn", "Eclipse" } do
		local b = base(sky)
		local g = ZoneLook.TargetFor(z, b, sky)
		check(z .. " keeps the clock", near(g.ClockTime, b.ClockTime), z .. "/" .. sky .. " " .. tostring(g.ClockTime))
		check(z .. " keeps the fog", sameColor(g.FogColor, b.FogColor) and near(g.FogEnd, b.FogEnd) and near(g.FogStart, b.FogStart),
			z .. "/" .. sky)
	end
end
-- the meadow is the base itself
do
	local b = base("Neutral")
	local g = ZoneLook.TargetFor("SlimeMeadow", b, "Neutral")
	check("meadow brightness = base", near(g.Brightness, 2), g.Brightness)
	check("meadow ambient = base", sameColor(g.Ambient, b.Ambient), "ambient")
end
-- the hollow at day: dusk clock, purple fog nearer, dim sun, blue ambient lift, exposure up
do
	local b = base("Neutral")
	local g, cc = ZoneLook.TargetFor("HauntedHollow", b, "Neutral")
	check("hollow day -> dusk clock 18.9", near(g.ClockTime, 18.9, 1e-4), g.ClockTime)
	check("hollow fog nearer (<= 340)", near(g.FogEnd, 340) and near(g.FogStart, 60), g.FogStart .. ".." .. g.FogEnd)
	check("hollow fog purple-navy", g.FogColor.B > g.FogColor.R and g.FogColor.B > g.FogColor.G and g.FogColor.B < 0.5,
		("%.2f %.2f %.2f"):format(g.FogColor.R, g.FogColor.G, g.FogColor.B))
	check("hollow sun dimmed to 0.7-0.9", g.Brightness >= 0.7 and g.Brightness <= 0.95, g.Brightness)
	check("hollow ambient leans blue", g.Ambient.B > g.Ambient.R + 0.1, ("%.2f %.2f"):format(g.Ambient.R, g.Ambient.B))
	check("hollow exposure up", g.ExposureCompensation > b.ExposureCompensation, g.ExposureCompensation)
	check("hollow tint violet", cc.TintColor.B >= cc.TintColor.R, "tint")
	-- Dawn (7.2): still turned to the dusk clock (forward the short way: +11.7 h)
	local d = ZoneLook.TargetFor("HauntedHollow", base("Dawn"), "Dawn")
	check("hollow at dawn -> dusk clock", near(d.ClockTime, 18.9, 1e-4), d.ClockTime)
	check("hollow at dawn fog nearer", d.FogEnd <= 340, d.FogEnd)
	-- Eclipse night (0.5): the night clock stays, the fog still turns purple and nearer
	local n = ZoneLook.TargetFor("HauntedHollow", base("Eclipse"), "Eclipse")
	check("hollow at night keeps the night clock", near(n.ClockTime, 0.5), n.ClockTime)
	check("hollow at night fog purple", n.FogColor.B > n.FogColor.R, "fog")
	check("hollow at night keeps the night floor light", n.Brightness >= 1.4 * 0.95 - 1e-6, n.Brightness)
end
-- quality 7 (2026-10-07): the horns den is lighter by day and gets NightExp under the Eclipse sky only
do
	for _, sky in { "Neutral", "Dawn", "Eclipse" } do
		local b = base(sky)
		local g, cc = ZoneLook.TargetFor("HornsTown", b, sky)
		local want = b.ExposureCompensation + 0.25 + (sky == "Eclipse" and 1.9 or 0)
		check("horns den exposure: +0.25, +1.9 more only at night", near(g.ExposureCompensation, want, 1e-4),
			sky .. " " .. tostring(g.ExposureCompensation) .. " want " .. want)
		check("horns den sun not dimmed (Bright 1.0)", near(g.Brightness, b.Brightness * (sky == "Eclipse" and math.max(1, 0.95) or 1), 1e-4),
			sky .. " " .. tostring(g.Brightness))
		check("horns den ambient 1.18 / 0.98 / 1.00", near(g.Ambient.R, math.min(1, b.Ambient.R * 1.18), 1e-3)
			and near(g.Ambient.G, b.Ambient.G * 0.98, 1e-3) and near(g.Ambient.B, b.Ambient.B * 1.0, 1e-3), sky)
		check("horns den tint 255,236,230, contrast 0.03", near(cc.TintColor.G, 236 / 255, 1e-3) and near(cc.Contrast, 0.03, 1e-4),
			sky)
	end
	for _, z in { "SlimeMeadow", "Crossroads", "HaloTown", "GoblinWoods", "SkeletonRuins" } do
		local n = ZoneLook.TargetFor(z, base("Eclipse"), "Eclipse")
		local d = ZoneLook.TargetFor(z, base("Neutral"), "Neutral")
		check("other zones: no night exposure lift", near(n.ExposureCompensation - base("Eclipse").ExposureCompensation,
			d.ExposureCompensation - base("Neutral").ExposureCompensation, 1e-6), z)
	end
end
-- half way through a zone change (the eased weight carries the dusk too)
do
	local b = base("Neutral")
	local h = ZoneLook.Blend("SlimeMeadow", "HauntedHollow", 0.5, b, "Neutral")
	check("half way into the hollow: clock half way", near(h.ClockTime, (14.2 + 18.9) / 2, 1e-4), h.ClockTime)
	check("half way into the hollow: fog half way", near(h.FogEnd, (1100 + 340) / 2, 1e-4), h.FogEnd)
	local o = ZoneLook.Blend("HauntedHollow", "SlimeMeadow", 1, b, "Neutral")
	check("out of the hollow: back to the base clock", near(o.ClockTime, 14.2), o.ClockTime)
	check("out of the hollow: back to the base fog", near(o.FogEnd, 1100), o.FogEnd)
end
local list = {}
for _, k in order do table.insert(list, { Name = k, Fail = named[k].Fail, First = named[k].First }) end
local parts = {}
for _, n in list do table.insert(parts, string.format('{"name":%q,"fail":%d}', n.Name, n.Fail)) end
print("ZONE_LOOK_RESULT_JSON {\"checks\":" .. checks .. ",\"failed\":" .. failed .. ",\"named\":[" .. table.concat(parts, ",") .. "]}")
if failed == 0 then print("ZONE_LOOK_OFFLINE_OK checks=" .. checks .. " Studio/API calls=0") end
'''

MUTATIONS = [
    ("hollow has no dusk", "Dusk = { Clock = 18.9,", "NoDusk = { Clock = 18.9,"),
    ("dusk clock ignores the weight", "clock = (clock + clockDelta(clock, d.Clock) * w) % 24", "clock = clock"),
    ("night base also turned to dusk", "if type(clock) == \"number\" and clock >= 6 and clock < d.Clock then",
     "if type(clock) == \"number\" then"),
    ("fog never nearer", "lerp(base.FogEnd, math.min(base.FogEnd, d.FogEnd), w)", "base.FogEnd"),
    ("hollow as bright as the meadow", "Bright = 0.45, Exp = 0.2,", "Bright = 1, Exp = 0.2,"),
    ("dusk weight lost when easing", "W = lerp(a.W or 0, b.W or 0, t), Dusk = b.Dusk or a.Dusk,", "W = 0, Dusk = nil,"),
    # quality 7 (2026-10-07)
    ("NightExp by day too", 'Exp = z.Exp + (sky == "Eclipse" and (z.NightExp or 0) or 0),', "Exp = z.Exp + (z.NightExp or 0),"),
    ("no NightExp", 'Exp = z.Exp + (sky == "Eclipse" and (z.NightExp or 0) or 0),', "Exp = z.Exp,"),
    ("horns den back to the dark numbers", "Bright = 1.0, Exp = 0.25, Tint = rgb(255, 236, 230)", "Bright = 0.88, Exp = 0.08, Tint = rgb(255, 236, 230)"),
]


def run(binary: Path, source: str, tmp: Path, name: str):
    text = "local ZONELOOK_SOURCE = [====[" + source + "]====]\n" + HARNESS
    path = tmp / name
    path.write_text(text, encoding="utf-8")
    p = subprocess.run([str(binary), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                       errors="replace", timeout=120)
    res = None
    for line in p.stdout.splitlines():
        if line.startswith("ZONE_LOOK_RESULT_JSON "):
            res = json.loads(line[len("ZONE_LOOK_RESULT_JSON "):])
    return p, res


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--luau", type=Path, default=ROOT / "build/luau_cli_0_741/luau.exe")
    ap.add_argument("--no-mutations", action="store_true")
    args = ap.parse_args()
    raw = SRC.read_bytes()
    source = raw.decode("utf-8-sig").replace("\r\n", "\n")
    with tempfile.TemporaryDirectory(prefix="zonelook_") as t:
        tmp = Path(t)
        proc, res = run(args.luau.resolve(), source, tmp, "real.luau")
        base_fail = {n["name"] for n in (res or {}).get("named", []) if n["fail"]}
        muts = []
        if not args.no_mutations:
            for i, (name, old, new) in enumerate(MUTATIONS):
                if source.count(old) != 1:
                    muts.append({"mutation": name, "applied": False, "caught": False, "note": f"matched {source.count(old)}"})
                    continue
                _, r = run(args.luau.resolve(), source.replace(old, new, 1), tmp, f"mut{i}.luau")
                new_fail = sorted({n["name"] for n in (r or {}).get("named", []) if n["fail"]} - base_fail)
                muts.append({"mutation": name, "applied": True, "caught": r is None or bool(new_fail), "newFailing": new_fail[:4]})
    ok = res is not None and res["failed"] == 0 and "ZONE_LOOK_OFFLINE_OK" in proc.stdout
    mut_ok = all(m["applied"] and m["caught"] for m in muts)
    status = "failed" if not (ok and mut_ok) else ("passed-no-mutations" if args.no_mutations else "passed")
    report = {"status": status, "checks": (res or {}).get("checks"), "failed": (res or {}).get("failed"), "mutations": muts,
              "sourceSHA256": hashlib.sha256(raw).hexdigest(), "runtimeError": None if res else (proc.stderr or proc.stdout)[-1500:],
              "studioCalls": 0, "apiCalls": 0}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for line in proc.stdout.splitlines():
        if line.startswith(("CHECK_FAIL", "ZONE_LOOK_OFFLINE")):
            print(line)
    if res is None:
        print(proc.stderr[-1500:])
    for m in muts:
        print(f"MUTATION {'caught ' if m['caught'] else 'MISSED'} {m['mutation']}" + ("" if m["applied"] else f" ({m['note']})"))
    print("Status:", status)
    return 0 if status.startswith("passed") else 1


if __name__ == "__main__":
    raise SystemExit(main())
