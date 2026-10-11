"""First-KO King drop (게임성 개발 1, SPEC A23-110 + 개발 2 FirstKOService), offline.

Runs, in the official Luau CLI, the CURRENT Fx.luau WOBBLE.dropLift cut out of Fx.luau with doubles: a monster with
DropAt (server time) / DropTime is drawn DROP_HEIGHT studs up at DropAt and falls faster and faster
(height x (1 - u^2)) to the ground at DropAt + DropTime; it lands with the big thud (AttackMul) exactly once; a drop
already long over at the join (u >= 1.5) lands silently; another player's own King (Feel.isForeign) never thuds; no
DropAt / DropTime = on the ground. A23-113 ① leap (개발 2 MonsterService LEAP, docs/design/boss_leap_2026-10-11.md):
with DropHeight the King leaps a low arc from DropFrom to DropPos (the body already stands at DropPos): at the start it
is drawn at DropFrom on the ground (offset = DropFrom - DropPos, the ground's height difference), at mid time
DropHeight up and half way, at the end on the spot with the thud once; DropHeight 0 with DropFrom = DropPos (Captain
Clatter's slam) = no lift; DropHeight without DropFrom = an arc in place; no DropHeight = the old sky fall (KO1's first
drop). Static: the slime joint adds the drop height and turns the sideways offset into the joint's frame; the King's
attack-hop thud skips another player's own King; LandShadow draws the circle from the same attributes. Mutations:
each must be caught.

Usage: py tools/test_king_drop.py
Report: docs/art/verification_2026-10-10/offline_king_drop_2026-10-10.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FX = ROOT / "src/StarterPlayer/StarterPlayerScripts/Fx.luau"
SHADOW = ROOT / "src/StarterPlayer/StarterPlayerScripts/LandShadow.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_king_drop_2026-10-10.json"
START, END = "WOBBLE.DROP_HEIGHT = 40", "-- true for a monster whose kind thuds (the King Slime)"

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local NOW, FOREIGN, thuds = 100, false, {}
local WOBBLE, MOTION, Feel = {}, { THUD = { AttackMul = 1.4 } }, {}
function MOTION.Thud(root, h, mul) table.insert(thuds, mul) return true end
function Feel.isForeign() return FOREIGN end
local V3 = {}
local function v3(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, V3) end
local env = { WOBBLE = WOBBLE, MOTION = MOTION, Feel = Feel,
	workspace = { GetServerTimeNow = function() return NOW end },
	typeof = function(v) return getmetatable(v) == V3 and "Vector3" or type(v) end,
	asNum = function(v, d) return type(v) == "number" and v or d end }
local f = assert(loadstring(SOURCE, "=drop"))
setfenv(f, setmetatable(env, { __index = getfenv() }))
f()
local function model(attrs) return { GetAttribute = function(_, n) return attrs[n] end } end
local king = model({ DropAt = 100, DropTime = 1.2 })
local st = { Root = {}, H = 6 }
check(math.abs(WOBBLE.dropLift(king, st) - WOBBLE.DROP_HEIGHT) < 1e-9, "at DropAt: DROP_HEIGHT up", WOBBLE.dropLift(king, st))
NOW = 100.6
local mid = WOBBLE.dropLift(king, st)
check(math.abs(mid - WOBBLE.DROP_HEIGHT * 0.75) < 1e-6, "half way in time: 3/4 of the height left (it speeds up)", mid)
check(#thuds == 0, "no thud in the air", #thuds)
NOW = 101.21
check(WOBBLE.dropLift(king, st) == 0, "landed: on the ground", "")
check(#thuds == 1 and thuds[1] == 1.4, "lands with the big thud (AttackMul) once", #thuds)
NOW = 101.5
WOBBLE.dropLift(king, st)
check(#thuds == 1, "... never twice", #thuds)
thuds = {}
local old = model({ DropAt = 50, DropTime = 1.2 })
NOW = 100
check(WOBBLE.dropLift(old, { Root = {}, H = 6 }) == 0 and #thuds == 0, "a drop long over at the join: silent, on the ground", #thuds)
FOREIGN = true
NOW = 200.1
local other = model({ DropAt = 199.6, DropTime = 0.5 }) -- lands right now (u = 1)
WOBBLE.dropLift(other, { Root = {}, H = 6 })
check(#thuds == 0, "another player's own King never thuds on my screen", #thuds)
FOREIGN = false
check(WOBBLE.dropLift(model({}), st) == 0, "no DropAt / DropTime: on the ground", "")
check(WOBBLE.dropLift(model({ DropAt = 1, DropTime = 0 }), st) == 0, "DropTime 0: on the ground", "")
NOW = 99
check(math.abs(WOBBLE.dropLift(model({ DropAt = 100, DropTime = 1 }), { Root = {}, H = 6 }) - WOBBLE.DROP_HEIGHT) < 1e-9, "before DropAt: still at the top", "")
-- A23-113 ① the King's leap: a low arc from DropFrom to DropPos (the body already stands at DropPos)
local function near(a, b) return math.abs(a - b) < 1e-6 end
thuds = {}
local leap = model({ DropAt = 300, DropTime = 1, DropHeight = 12, DropFrom = v3(10, 0, -4), DropPos = v3(0, 0, 0) })
local lst = { Root = {}, H = 6 }
NOW = 300
local up, ox, oz = WOBBLE.dropLift(leap, lst)
check(near(up, 0) and near(ox, 10) and near(oz, -4), "leap start: drawn on the ground where it jumped (DropFrom)", up .. "," .. ox)
check(up < WOBBLE.DROP_HEIGHT * 0.5, "a leap never starts in the sky (not the old 40-stud fall)", up)
NOW = 300.5
up, ox, oz = WOBBLE.dropLift(leap, lst)
check(near(up, 12) and near(ox, 5) and near(oz, -2), "mid leap: DropHeight up, half way across", up .. "," .. ox)
NOW = 300.25
local upA = WOBBLE.dropLift(leap, lst)
NOW = 300.75
local upB = WOBBLE.dropLift(leap, lst)
check(near(upA, upB) and near(upA, 9), "the arc is even (up at 1/4 = up at 3/4 = 3/4 of DropHeight)", upA .. "/" .. upB)
check(#thuds == 0, "no thud in the air (leap)", #thuds)
NOW = 301.05
up, ox, oz = WOBBLE.dropLift(leap, lst)
check(up == 0 and ox == 0 and oz == 0 and #thuds == 1, "leap end: on the spot, the thud once", #thuds)
local hill = model({ DropAt = 400, DropTime = 1, DropHeight = 12, DropFrom = v3(6, 3, 0), DropPos = v3(0, 0, 0) })
NOW = 400
up = WOBBLE.dropLift(hill, { Root = {}, H = 6 })
check(near(up, 3), "jumping from higher ground starts that much up", up)
local slam = model({ DropAt = 500, DropTime = 1, DropHeight = 0, DropFrom = v3(2, 0, 2), DropPos = v3(2, 0, 2) })
NOW = 500.5
up, ox, oz = WOBBLE.dropLift(slam, { Root = {}, H = 6 })
check(up == 0 and ox == 0 and oz == 0, "DropHeight 0 with DropFrom = DropPos (a slam): no lift", up)
local inPlace = model({ DropAt = 600, DropTime = 1, DropHeight = 12 })
NOW = 600.5
up, ox, oz = WOBBLE.dropLift(inPlace, { Root = {}, H = 6 })
check(near(up, 12) and ox == 0 and oz == 0, "DropHeight without DropFrom: an arc in place", up)
print(("DROP_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("falls at an even speed", "return WOBBLE.DROP_HEIGHT * (1 - u * u)", "return WOBBLE.DROP_HEIGHT * (1 - u)"),
    ("thuds every frame", "if st.DropLanded ~= at then", "if true then"),
    ("old drops thud at the join", "if u < 1.5 and not Feel.isForeign(model) then", "if not Feel.isForeign(model) then"),
    ("foreign Kings thud", "if u < 1.5 and not Feel.isForeign(model) then", "if u < 1.5 then"),
    ("a small thud", "asNum(MOTION.THUD.AttackMul, 1.4)", "1"),
    ("every leap falls from the sky", 'if type(h) ~= "number" then return WOBBLE.DROP_HEIGHT * (1 - u * u), 0, 0 end',
     "do return WOBBLE.DROP_HEIGHT * (1 - u * u), 0, 0 end"),
    ("no sideways move (the King pops at the spot)", "ox, oz = (from.X - to.X) * k, (from.Z - to.Z) * k", "ox, oz = 0, 0"),
    ("the sideways move runs backwards", "ox, oz = (from.X - to.X) * k, (from.Z - to.Z) * k", "ox, oz = (from.X - to.X) * u, (from.Z - to.Z) * u"),
    ("a flat arc", "math.max(0, h) * 4 * u * k", "math.max(0, h) * k"),
    ("the ground difference ignored", "\t\tup += (from.Y - to.Y) * k\n", ""),
]
STATIC = [
    ("the slime joint adds the drop height and the leap's sideways offset (in the joint's frame)",
     lambda fx, sh: "local drop, dropX, dropZ = WOBBLE.dropLift(model, st)" in fx
     and "local c1 = CFrame.new(0, -(hop + drop + (sy - 1) * half) + WOBBLE.Sink, 0)" in fx
     and "c1 = CFrame.new(-(st.Root.CFrame * st.Joint.C0).Rotation:VectorToObjectSpace(Vector3.new(dropX, 0, dropZ))) * c1" in fx
     and "st.Joint.C1 = c1" in fx),
    ("the attack-hop thud skips another player's own King", lambda fx, sh: "if MOTION.Thuds(model) and not Feel.isForeign(model) then" in fx),
    ("LandShadow draws the circle from DropAt / DropTime", lambda fx, sh: 'model:GetAttributeChangedSignal("DropAt")' in sh
     and 'DropTime = model:GetAttribute("DropTime")' in sh),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(block: str) -> tuple[int, int, str]:
    text = "local SOURCE = " + lua_str(block) + "\n" + FIXTURE
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "drop.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"DROP_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (int(m[1]) if m else 0), (int(m[2]) if m else 1), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    fx = FX.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    sh = SHADOW.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    a, b = fx.find(START), fx.find(END)
    block = fx[a:b]
    checks, failed, out = run(block)
    print(out.strip())
    statics = [{"check": n, "ok": bool(fn(fx, sh))} for n, fn in STATIC]
    for s in statics:
        print(("STATIC_OK  " if s["ok"] else "STATIC_FAIL ") + s["check"])
    muts = []
    for name, old, new in MUTATIONS:
        hits = block.count(old)
        caught = hits == 1 and run(block.replace(old, new))[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    ok = a >= 0 and b > a and failed == 0 and checks > 0 and all(s["ok"] for s in statics) and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "static": statics, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
