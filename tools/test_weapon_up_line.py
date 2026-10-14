"""최종 검수 10/15 (Codex C1): a better weapon says what it means - HUD.WeaponUpLine, offline.

1. HUD.WeaponUpLine(fromTier, toTier, level, class, faction, powerFrom, powerTo) = Config.Power.Text.WeaponUp
   ("Power 120 → 180 · Slime: 10 hits → 6 hits") with the basic hits from Config.SwingHitsToKill (the Forge window's own
   count), "1 hits" -> "1 hit"; nil for a joke weapon, unknown hits, or no fewer hits.
Static: L.TierChanged remembers the tier before a better one (L.Pow.TierFrom); the next power settle shows the line as a
toast next to the +N count-up and forgets it.
Runs the CURRENT Config.luau (doubles) + the cut function. Mutations: each must be caught.
Report: docs/art/verification_2026-10-15/offline_weapon_up_line_2026-10-15.json (do not commit)
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
FILES = {"CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau", "HUD": SPS / "HUD.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-15/offline_weapon_up_line_2026-10-15.json"

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
local HUD, L = {}, {}
function L.Tx(t, key, ...) return string.format(t[key], ...) end
local Util = { FormatInt = function(n) return tostring(math.floor(n)) end }
local f = assert(loadstring(PART, "=Part"))
setfenv(f, setmetatable({ HUD = HUD, L = L, Config = Config, Util = Util }, { __index = getfenv() }))
f()

local b, a = Config.SwingHitsToKill(1, 1, "Warrior", "Slime", "Halo"), Config.SwingHitsToKill(2, 1, "Warrior", "Slime", "Halo")
local line = HUD.WeaponUpLine(1, 2, 1, "Warrior", "Halo", 120, 180)
check(type(b) == "number" and type(a) == "number" and a < b, "T1 -> T2: fewer basic hits for a Slime (Config.SwingHitsToKill)", tostring(b) .. " -> " .. tostring(a))
check(line == Config.Plural(string.format(Config.Power.Text.WeaponUp, "120", "180", b, a)) and line:find("Slime:", 1, true) ~= nil,
	"the line: Power 120 → 180 · Slime: N hits → M hits", line)
check(HUD.WeaponUpLine(1, 10, 1, "Warrior", "Halo", 120, 125) == nil, "a joke weapon (Meme): no line")
check(HUD.WeaponUpLine(2, 2, 1, "Warrior", "Halo", 180, 180) == nil, "no fewer hits: no line")
check(HUD.WeaponUpLine(1, 99, 1, "Warrior", "Halo", 120, 180) == nil, "an unknown tier: no line")
local plural = Config.Plural("Slime: 1 hits → 1 hits")
check(plural == "Slime: 1 hit → 1 hit", "Config.Plural makes '1 hits' '1 hit'", plural)
print(("WEAPON_UP_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("HUD", "a joke weapon gets the line", "or type(def) ~= \"table\" or def.Meme ~= nil then return nil end", "or type(def) ~= \"table\" then return nil end"),
    ("HUD", "the hits the wrong way round", "Util.FormatInt(powerTo), before, after))", "Util.FormatInt(powerTo), after, before))"),
    ("HUD", "never shown after a better weapon", "\tif F.Tier >= 1 and tier > F.Tier then L.Pow.TierFrom = F.Tier end", "\tlocal _ = F.Tier"),
    ("HUD", "shown again on every power rise", "\t\tP.TierFrom = nil\n", ""),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def cut(text: str, start: str) -> str:
    a = text.find(start)
    if a < 0:
        return ""
    b = text.find("\nend\n", a)
    return text[a:b + 5] if b >= 0 else ""


def statics(h: str) -> list[tuple[str, bool]]:
    return [
        ("L.TierChanged remembers the tier before a better one; the settle toasts the line and forgets it",
         "\tif F.Tier >= 1 and tier > F.Tier then L.Pow.TierFrom = F.Tier end" in h
         and "if line then pcall(UIKit.Toast, line, \"good\") end" in h and "\t\tP.TierFrom = nil\n" in h),
    ]


def run(src: dict) -> tuple[int, int, str]:
    part = cut(src["HUD"], "function HUD.WeaponUpLine(")
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "weapon_up.luau"
        p.write_text("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal PART = " + lua_str(part) + "\n" + FIXTURE, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
    out = proc.stdout + proc.stderr
    m = re.search(r"WEAPON_UP_SUMMARY checks=(\d+) failed=(\d+)", out)
    st = statics(src["HUD"])
    out += "".join(("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + n for n, ok in st)
    return (int(m[1]) if m else 0) + len(st), (int(m[2]) if m else 1) + sum(1 for _, ok in st if not ok), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    checks, failed, out = run(src)
    print(out.strip())
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
    ok = failed == 0 and checks >= 6 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Runs the")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
