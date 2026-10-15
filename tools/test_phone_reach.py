"""Phone reach + the PvP edge (최종 검수 10/15, the textbook: forgiving taps, a danger shown before it hits), offline.

Runs the CURRENT HUD.NearMiss and ZoneLook.PvPRects / OutsideBy / EdgesFor in the official Luau CLI on small doubles:
a tap a little off the round attack disc still counts (within Slack x its radius), farther does not; the PvP places
are the zones with PvP = true plus a zone's PvPArea (a season zone only in its season); the red edge shows only while I
stand outside one and within Near studs, never for the Artisan Guild (no PvP). Static: the near-miss only takes touches
that reached the world (gameProcessed false) and the edge pass runs in ZoneLook.Start. Each mutation must make a check
fail.

Usage: py tools/test_phone_reach.py
"""
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"HUD": SPS / "HUD.luau", "ZL": SPS / "ZoneLook.luau"}
LUAU = ROOT / "build/luau_cli_0_741/luau.exe"
if not LUAU.exists():
    LUAU = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"

PURE = r"""
local function vec(kind) return function(x, y, z) return setmetatable({ X = x, Y = y, Z = z or 0 }, { __type = kind }) end end
local V2, V3 = vec("Vector2"), vec("Vector3")
local function typeof(v) local mt = type(v) == "table" and getmetatable(v) return mt and mt.__type or type(v) end
local Config = {
	ZoneOrder = { "Meadow", "Woods", "Ruins", "Spooky" },
	Zones = {
		Meadow = { PvP = false, Center = V3(0, 0, 0), Size = V3(100, 0, 100) },
		Woods = { PvP = true, Center = V3(500, 0, 0), Size = V3(200, 0, 200) },
		Ruins = { PvP = false, Center = V3(1000, 0, 0), Size = V3(300, 0, 300), PvPArea = { Center = V3(1050, 0, 0), Size = V3(100, 0, 100) } },
		Spooky = { PvP = true, Season = "Halloween", Center = V3(0, 0, 900), Size = V3(100, 0, 100) },
	},
	SeasonOn = function(s) return false end,
}
local HUD, ZoneLook = {}, {}
ZoneLook.EDGE = { Near = 45 }
__FUNC__
local fails = 0
local function check(name, ok, detail)
	print((ok and "CHECK_OK " or "CHECK_FAIL ") .. name .. (ok and "" or (" :: " .. tostring(detail))))
	if not ok then fails += 1 end
end
local pos, size = V2(100, 100), V2(100, 100) -- a disc centred at (150, 150), radius 50
check("a tap on the disc counts", HUD.NearMiss(pos, size, V2(150, 150), 1.3))
check("a tap a little off it (60 px from the centre) still counts", HUD.NearMiss(pos, size, V2(210, 150), 1.3))
check("farther (70 px) does not", not HUD.NearMiss(pos, size, V2(220, 150), 1.3))
check("a touch Position (Vector3) works too", HUD.NearMiss(pos, size, V3(150, 205, 0), 1.3))
check("no size / no point: never", not HUD.NearMiss(pos, V2(0, 0), V2(100, 100), 1.3) and not HUD.NearMiss(pos, size, nil, 1.3))
local rects = ZoneLook.PvPRects()
local keys = {}
for _, r in rects do keys[r.Key] = true end
check("the PvP zones and a zone's PvP area", keys.Woods and keys["Ruins:Area"] and not keys.Meadow and not keys.Ruins)
check("a season zone off season: none", not keys.Spooky)
local woods = rects[1]
check("outside by its distance to the edge", math.abs(ZoneLook.OutsideBy(woods, V3(380, 0, 0)) - 20) < 1e-6)
check("inside: 0 or less", ZoneLook.OutsideBy(woods, V3(500, 0, 0)) <= 0)
local e = ZoneLook.EdgesFor(V3(380, 0, 0), "Halo", rects)
check("near the woods from outside: its edge shows", e.Woods == true and e["Ruins:Area"] == nil)
check("inside the woods: no curtain", next(ZoneLook.EdgesFor(V3(500, 0, 0), "Horns", rects)) == nil)
check("far away: nothing", next(ZoneLook.EdgesFor(V3(300, 0, 0), "Halo", rects)) == nil)
check("the Artisan Guild (no PvP): nothing", next(ZoneLook.EdgesFor(V3(380, 0, 0), "Neutral", rects)) == nil)
check("no side yet: nothing", next(ZoneLook.EdgesFor(V3(380, 0, 0), nil, rects)) == nil)
print(fails == 0 and "REACH_PURE_OK" or "REACH_PURE_FAILED")
"""


def block(src: str, name: str) -> str:
    m = re.search(r"^function " + re.escape(name) + r"\(.*?^end\n", src, re.S | re.M)
    return m.group(0) if m else ""


def statics(s: dict) -> list[tuple[str, bool]]:
    hud, zl = s["HUD"], s["ZL"]
    bind = hud[hud.find("local function bindButtonInput()"):]
    bind = bind[:bind.find("\nend\n")]
    return [
        ("the near-miss takes only touches that reached the world, and attacks like the disc",
         "UserInputService.TouchStarted:Connect(function(input, gameProcessed)" in bind
         and "if gameProcessed or not ui.attack or not ui.attack.Visible or not inputAllowed() then return end" in bind
         and "startHold(input)" in bind[bind.find("TouchStarted"):]),
        ("the edge pass runs in ZoneLook.Start", "pcall(ZoneLook.RefreshEdges)" in zl),
        ("the curtain never blocks or catches clicks", "p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false" in zl),
    ]


MUTATIONS = [
    ("HUD", "no slack", "return math.sqrt((point.X - cx) ^ 2 + (point.Y - cy) ^ 2) <= r * (tonumber(slack) or 1)",
     "return math.sqrt((point.X - cx) ^ 2 + (point.Y - cy) ^ 2) <= r"),
    ("HUD", "near-miss also over buttons", "if gameProcessed or not ui.attack or not ui.attack.Visible or not inputAllowed() then return end",
     "if not ui.attack or not ui.attack.Visible or not inputAllowed() then return end"),
    ("ZL", "no PvP areas", "\t\t\t\ttable.insert(out, { Key = id .. \":Area\", Center = a.Center, Size = a.Size })\n", ""),
    ("ZL", "the Guild warned", 'if typeof(pos) ~= "Vector3" or faction == "Neutral" or faction == nil or faction == "" then return out end',
     'if typeof(pos) ~= "Vector3" then return out end'),
    ("ZL", "the curtain inside too", "if d > 0 and d <= ZoneLook.EDGE.Near then out[r.Key] = true end",
     "if d <= ZoneLook.EDGE.Near then out[r.Key] = true end"),
    ("ZL", "season ignored", "(z.Season == nil or (type(Config.SeasonOn) == \"function\" and Config.SeasonOn(z.Season)))", "true"),
]


def run(src: dict) -> tuple[bool, list, str]:
    funcs = block(src["HUD"], "HUD.NearMiss") + "".join(block(src["ZL"], n) for n in
                                                         ("ZoneLook.PvPRects", "ZoneLook.OutsideBy", "ZoneLook.EdgesFor"))
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "reach.luau"
        f.write_text(PURE.replace("__FUNC__", funcs), encoding="utf-8")
        r = subprocess.run([str(LUAU), str(f)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = r.stdout + r.stderr
    st = statics(src)
    return "REACH_PURE_OK" in out and all(g for _, g in st), st, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    src = {k: p.read_text(encoding="utf-8") for k, p in FILES.items()}
    good, st, out = run(src)
    print(out.strip())
    for name, g in st:
        print(("STATIC_OK " if g else "STATIC_FAIL ") + name)
    caught = 0
    for key, name, old, new in MUTATIONS:
        if src[key].count(old) != 1:
            print(f"MUTATION NOT_APPLIED {name} (matched {src[key].count(old)})")
            continue
        m = dict(src)
        m[key] = src[key].replace(old, new)
        bad, _, _ = run(m)
        caught += 0 if bad else 1
        print(("MUTATION caught  " if not bad else "MUTATION MISSED ") + name)
    passed = good and caught == len(MUTATIONS)
    print(f"Status: {'passed' if passed else 'failed'} (statics {sum(g for _, g in st)}/{len(st)}, mutations {caught}/{len(MUTATIONS)})")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
