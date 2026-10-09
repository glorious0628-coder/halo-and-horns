"""Basic-attack floor ring offline check (검수 10/08: the yellow floor oval after every attack looked like a glitch).

Extracts handlers.Swing and MOTION.HIT_RING from the CURRENT src/StarterPlayer/StarterPlayerScripts/Fx.luau and runs the
handler with the installed official Luau CLI (build/luau_cli_0_741) against doubles that record every ring() call
(Feel.after / launchWeapon / launchArrow call back at once). Rule: a basic attack draws no floor disc around the attacker;
only MY punch / magic hit leaves one small, faint, quick mark at the target; other players' basic attacks draw none.
Mutations: in-memory copies with one rule broken each; each must make a check fail. Status "passed" only when the
checks pass AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-08/offline_hit_ring_2026-10-08.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
FX = ROOT / "src/StarterPlayer/StarterPlayerScripts/Fx.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-08/offline_hit_ring_2026-10-08.json"

FIXTURE = r"""
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if not ok then failed += 1; print(("CHECK_FAIL %s :: %s"):format(name, tostring(detail or ""))) end
end
local Vector3 = { new = function(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, VMT) end }
VMT = {
	__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
	__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
	__index = function(v, k) if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end end,
}
HIT_RING_LINE
local MOTION = { HIT_RING = HIT_RING, CAST_DELAY = 0.24, SHOT_DELAY = 0.22, SLASH_CONTACT = 0.23, SLASH_VFX_AT = 0.17,
	PetMove = function() end }
local RINGS, HITS = {}, 0
local function ring(pos, radius, color, opts) table.insert(RINGS, { Pos = pos, Radius = radius, Opts = opts or {} }) end
local function showHits() HITS += 1 end
local OWN = true
local function isOwn() return OWN end
local Fx = { PlaySound = function() end }
local function animateOwnAttack() end
local function asVec(v) return v end
local function asStr(v, d) return type(v) == "string" and v or d end
local function asNum(v, d) return type(v) == "number" and v or d end
local function nearCamera() return true end
local function factionColor() return "yellow" end
local function validTargets(list) return list or {} end
local function warnThrottled() end
local function orb() end
local function arrowBolt() end
local Feel = {
	attackContext = function() return {} end,
	animateOther = function() end,
	expectHits = function() end,
	after = function(_, _, fn) fn() end,
	launchWeapon = function(_, _, fn) fn() end,
	launchArrow = function(_, _, fn) fn() end,
	muzzle = function(_, from) return from end,
	magicBurst = function() end,
	slash = function() end,
}
local handlers = {}
SWING_SOURCE
local ME, MOB = Vector3.new(0, 0, 0), Vector3.new(5, 0, 0)
local function swing(class, own, targets, style)
	RINGS, HITS, OWN = {}, 0, own
	handlers.Swing({ Pos = ME, From = ME, Class = class, Faction = "Halo", Radius = 8, Targets = targets, Style = style, Manual = true })
	return RINGS
end
check("a Warrior swing (mine) draws no floor disc", #swing("Warrior", true, { MOB }) == 0 and HITS == 1, #RINGS)
check("another player's Warrior swing draws none", #swing("Warrior", false, { MOB }) == 0 and HITS == 1, #RINGS)
check("an Archer shot draws none", #swing("Archer", true, { MOB }) == 0 and #swing("Archer", false, { MOB }) == 0)
local r = swing("Mage", true, { MOB })
check("my magic hit: one small mark at the target", #r == 1 and r[1].Pos == MOB and r[1].Radius <= 1.5, r[1] and r[1].Radius)
check("another player's magic: none", #swing("Mage", false, { MOB }) == 0)
check("my magic with no target: none", #swing("Mage", true, {}) == 0)
r = swing("Warrior", true, { MOB }, "Punch")
check("my punch hit: one small mark at the target", #r == 1 and r[1].Pos == MOB and r[1].Radius <= 1.5, r[1] and r[1].Radius)
check("my punch at nothing: none", #swing("Warrior", true, {}, "Punch") == 0)
check("another player's punch: none", #swing("Warrior", false, { MOB }, "Punch") == 0)
check("the mark is faint and quick (transparency >= 0.75, gone within 0.25 s, thin)", HIT_RING.Transparency >= 0.75
	and HIT_RING.Grow + HIT_RING.Fade <= 0.25 and HIT_RING.Thickness <= 0.1,
	("%s %s %s"):format(tostring(HIT_RING.Transparency), tostring(HIT_RING.Fade), tostring(HIT_RING.Thickness)))
print(("HIT_RING_SUMMARY checks=%d failed=%d"):format(checks, failed))
"""

MUTATIONS = [
    ("the Warrior disc back", "\t\tFeel.after(ctx, showAt, function()\n\t\t\tshowHits(hits, own, false, feel)\n",
     "\t\tFeel.after(ctx, showAt, function()\n\t\t\tring(pos, 4, color, MOTION.HIT_RING)\n\t\t\tshowHits(hits, own, false, feel)\n"),
    ("others' punches draw", "\t\t\tif own and targets[1] then ring(", "\t\t\tif targets[1] then ring("),
    ("others' magic draws", "\t\t\t\tif target and own then\n", "\t\t\t\tif target then\n"),
    ("a loud mark", "Transparency = 0.78,", "Transparency = 0.45,"),
    ("a slow mark", "Fade = 0.14,", "Fade = 0.3,"),
    ("a big mark", "Radius = 1.3 }", "Radius = 4 }"),
    ("a thick disc", "Thickness = 0.06,", "Thickness = 0.2,"),
]


def extract(src):
    swing = re.search(r"\nhandlers\.Swing = function\(data\)\n.*?\nend\n", src, re.S)
    hit = re.search(r"\tHIT_RING = (\{[^\n]*\}),", src)
    return (swing[0] if swing else ""), (("local HIT_RING = " + hit[1]) if hit else "")


def run(src, name):
    swing, hit = extract(src)
    path = ROOT / f"build/hit_ring_offline{name}.luau"
    path.write_text(FIXTURE.replace("SWING_SOURCE", swing).replace("HIT_RING_LINE", hit), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"HIT_RING_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = bool(swing) and bool(hit) and result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    src = FX.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(src, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = src.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(src.replace(old, new), "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    passed = ok and all(r["applied"] and r["caught"] for r in rows)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {FX.relative_to(ROOT).as_posix(): hashlib.sha256(FX.read_bytes()).hexdigest()},
              "studioCalls": 0,
              "limitations": "The handler with doubles: whether the hit still feels clear in play (slash / sparks / numbers) "
                             "and that no floor oval shows on the hills is a Studio Play photo / video check (메인 반영, 촬영 편집)."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
