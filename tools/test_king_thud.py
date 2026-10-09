"""King Slime landing thud (user 2026-10-09 "킹슬라임이 뛸 때는 쿵쿵 카메라 효과 있으면 좋겠어"; 검수: near players only,
short, small, a thud + a round dust ring, off with Settings 'Screen shake').

Runs, in the official Luau CLI, the CURRENT MOTION.Falloff / MOTION.ThudPlan / MOTION.BumpOffset (cut out of Fx.luau)
with the CURRENT Config.BossThud numbers: the camera drop is full within Near studs, less and less to Far, none beyond,
none with 'Screen shake' off / Reduced Motion (the sound and the dust stay), capped at BumpMax; the attack hop thuds
harder; the drop is short (over in BumpTime s, a fast drop then one small bounce, back to 0). Static: every walk-hop
landing and the attack hop landing of a BossThud kind call MOTION.Thud, landings closer than Gap s make one thud, the
camera moves only up / down (never turns), the ring is the round ring art (no rays), the sound is KingThud.
Mutations: each must be caught.

Usage: py tools/test_king_thud.py
Report: docs/art/verification_2026-10-09/offline_king_thud_2026-10-09.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"FX": ROOT / "src/StarterPlayer/StarterPlayerScripts/Fx.luau",
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-09/offline_king_thud_2026-10-09.json"

STATIC = [
    ("walk-hop landings of a BossThud kind thud", "FX",
     ["\t\t\t\t\t\tif st.Thud and lastS > 0 and s <= 0 and not foreign then\n",
      "\t\t\t\t\t\t\tlocal okT, errT = pcall(MOTION.Thud, st.Root, st.H, 1)\n", "Thud = MOTION.Thuds(model)"]),
    ("the attack hop lands with the bigger thud", "FX",
     ["if model.Parent and root.Parent then MOTION.Thud(root, h, asNum(MOTION.THUD.AttackMul, 1.4)) end"]),
    ("landings closer than Gap s make one thud", "FX",
     ["\tif now - b.LastAt < asNum(T.Gap, 0.3) and mul <= (b.LastMul or 0) then return false end\n"]),
    ("the camera only moves up / down (never turns: the follow camera never sees it)", "FX",
     ["\tif cam then cam.CFrame += Vector3.new(0, MOTION.BumpOffset(t, b.Mag, b.Dur), 0) end\n"]),
    ("'Screen shake' off / Reduced Motion: no camera drop", "FX",
     ["\tif not MOTION.ShakeAllowed() then return false end\n",
      "local plan = MOTION.ThudPlan(me and Util.FlatDistance(me.Position, pos) or nil, mul, MOTION.ShakeAllowed())"]),
    ("a round dust ring (the ring art, no rays) and the KingThud sound", "FX",
     ["StartDiameter = r, Art = true })", 'pcall(audio.Play, "KingThud", { Volume = plan.Volume })']),
    ("Config: the King Slime thuds; the sound is set", "CONFIG",
     ["\tKinds = { SlimeKing = true },\n", "\t\tKingThud = { File = "]),
]
MUTATIONS = [
    ("FX", "the drop at any distance", "\tif d >= far then return 0 end\n", ""),
    ("FX", "the drop with 'Screen shake' off", "\tif shakeOk == true and d ~= nil then\n", "\tif d ~= nil then\n"),
    ("FX", "no cap on the drop", "asNum(T.BumpMax, 0.9))", "math.huge)"),
    ("FX", "the attack hop no bigger", "asNum(T.Bump, 0.6) * asNum(mul, 1) *", "asNum(T.Bump, 0.6) *"),
    ("FX", "the camera never comes back up (no damping)", "* math.exp(-3 * t / dur)", "* 1"),
    ("FX", "every landing thuds twice (no gap)", "\tif now - b.LastAt < asNum(T.Gap, 0.3) and mul <= (b.LastMul or 0) then return false end\n", ""),
    ("FX", "walk hops never thud", "\t\t\t\t\t\t\tlocal okT, errT = pcall(MOTION.Thud, st.Root, st.H, 1)\n", "\t\t\t\t\t\t\tlocal okT, errT = true, nil\n"),
    ("CONFIG", "a huge drop", "\tBump = 0.6,", "\tBump = 3,"),
]

FIXTURE = r'''
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local function asNum(v, d) v = tonumber(v) if v == nil or v ~= v then return d end return v end
local MOTION = { THUD = THUD }
local f = assert(loadstring(PARTS, "=parts"))
setfenv(f, setmetatable({ MOTION = MOTION, asNum = asNum }, { __index = getfenv() }))
f()
local T = THUD
local P = MOTION.ThudPlan
local near, far = T.Near, T.Far
check("numbers: near 18 / far 45 / a small drop (<= 0.9 studs) / short (<= 0.35 s)", near == 18 and far == 45 and T.BumpMax <= 0.9 and T.BumpTime <= 0.35,
	T.Near .. " " .. T.Far .. " " .. T.BumpMax .. " " .. T.BumpTime)
check("within Near: the full drop", math.abs(P(5, 1, true).Bump - T.Bump) < 1e-9, P(5, 1, true).Bump)
local mid = P((near + far) / 2, 1, true).Bump
check("half way to Far: about half", math.abs(mid - T.Bump / 2) < 1e-6, mid)
check("beyond Far: no drop", P(far + 1, 1, true).Bump == 0)
check("the attack hop drops more, within the cap", P(5, T.AttackMul, true).Bump > P(5, 1, true).Bump and P(5, 10, true).Bump <= T.BumpMax + 1e-9)
check("'Screen shake' off: no drop, the sound stays", P(5, 1, false).Bump == 0 and P(5, 1, false).Volume == 1)
check("no character: nothing", P(nil, 1, true).Bump == 0 and P(nil, 1, true).Volume == 0)
check("the sound fades out to SoundFar", P(T.SoundFar + 1, 1, true).Volume == 0 and P((near + T.SoundFar) / 2, 1, true).Volume > 0)
local B = MOTION.BumpOffset
local dur, mag = T.BumpTime, T.Bump
local lowest, lowAt = 0, 0
for i = 0, 100 do
	local t = dur * i / 100
	local y = B(t, mag, dur)
	if y < lowest then lowest, lowAt = y, t end
end
check("the camera drops (down first)", lowest < -mag * 0.5, lowest)
check("... fast (lowest within 0.08 s)", lowAt <= 0.08, lowAt)
check("... never more than the drop", lowest >= -mag - 1e-9, lowest)
check("back to 0 when it ends", B(dur, mag, dur) == 0 and math.abs(B(dur * 0.99, mag, dur)) < mag * 0.1, B(dur * 0.99, mag, dur))
check("no drop before it starts / for 0 studs", B(-0.1, mag, dur) == 0 and B(0.1, 0, dur) == 0)
print(("THUD_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''


def config_thud(config: str) -> str:
    m = re.search(r"\nConfig\.BossThud = (\{\n.*?\n\})\n", config, re.S)
    if not m:
        raise ValueError("Config.BossThud missing")
    body = m.group(1)
    body = re.sub(r"\n\tKinds = \{[^}]*\},", "", body)
    body = re.sub(r"\n\tDustColor = [^\n]*", "", body)
    return body


def run(src: dict) -> tuple[int, int, str]:
    fx = src["FX"]
    parts = []
    for name in ("Falloff", "ThudPlan", "BumpOffset"):
        m = re.search(r"\nfunction MOTION\." + name + r"\(.*?\n\nend\n|\nfunction MOTION\." + name + r"\(.*?\nend\n", fx, re.S)
        if not m:
            return 0, 1, f"MOTION.{name} missing"
        parts.append(m.group(0))
    try:
        thud = config_thud(src["CONFIG"])
    except ValueError as e:
        return 0, 1, str(e)
    text = (f"local THUD = {thud}\nlocal PARTS = [==========[{''.join(parts)}]==========]\n" + FIXTURE)
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "thud.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"THUD_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed = int(m[2]) if m else 1
    for name, key, needles in STATIC:
        ok = all(src[key].count(n) == 1 for n in needles)
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
        failed += 0 if ok else 1
    return (int(m[1]) if m else 0) + len(STATIC), failed, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8") for k, p in FILES.items()}
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
    status = "passed" if failed == 0 and checks > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
