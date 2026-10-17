"""A23-91 보강 (user 2026-10-09 "공격할 때 몬스터 쪽으로 몸 돌리기 … 조금 더 세세하게"): the turn toward a monster when I
attack, offline.

Runs, in the official Luau CLI, the CURRENT Config.luau (Config.AutoFace, AttackProfile, class rows) and the CURRENT
HUD.PickTarget / L.AIM.ShowRing / L.AIM.TurnTo / L.FaceTarget (cut out of HUD.luau) in
tools/fixtures/auto_face_offline.luau: a fake clock, RenderStepped and task.delay, a character, a camera and a Monsters
folder. Checks: with ServerHint false the pick copies CombatService.Swing's own aim (A23-61: the nearest inside the
front half, else the nearest within Range) so the turn, the ring and the hit agree; the attack's own Range (bare hands 7,
Warrior 10, Archer 30); monsters only (no hidden ambusher, no one else's monster, no dead one); a short eased turn
(TurnTime), none within SkipDeg; walking holds the body on the target for TurnTime + SwingHold; the ring = the approved
round FxShockRing art sized to the body on the floor, gone when the target dies or RingShow s after my last attack; auto
combat's standing facing keeps the server's aim, shows no ring and waits while my attacks keep a target; Swing / Release
carry my pick (arg 1). With ServerHint true: the kept target (until it dies / leaves Range), score (closeness within
Inside x Range, front, screen centre, a monster winding up at me within AttackerReach first), nothing behind me farther
than BackNear. Static: the call sites; ServerHint on exactly when CombatService takes the pick (HINT.Pick).
Mutations: each must be caught.

Usage: py tools/test_auto_face.py
Report: docs/art/verification_2026-10-09/offline_auto_face_2026-10-09.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"HUD": ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau",
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "COMBAT": ROOT / "src/ServerScriptService/CombatService.luau"}
FIXTURE = ROOT / "tools/fixtures/auto_face_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-09/offline_auto_face_2026-10-09.json"

CUT_START = "function HUD.PickTarget(cands, current, keep, cfg)\n"
CUT_END = "\n-- one Swing for one press"

STATIC = [
    ("the attack button / F key / world click swing goes at once with my pick", "HUD",
     ["function L.SwingFaced()\n\tif not L.SwingGate() then return end\n\tlocal _, target = L.FaceTarget(\"Swing\")\n",
      "\tif type(fx) == \"table\" and type(fx.PredictSwing) == \"function\" then pcall(fx.PredictSwing) end\n\tfire(\"Swing\", target)\nend\n"]),
    ("skill Q turns first (TurnTime), then goes with my pick", "HUD",
     ["\tlocal turned, target = L.FaceTarget(\"Release\") -- the skill waits for the turn (TurnTime)\n",
      "function() fire(\"Release\", target) end)\n\telse\n\t\tfire(\"Release\", target)\n"]),
    ("auto combat faces only while I stand", "HUD",
     ["if hum and hum.MoveDirection.Magnitude < 0.1 then pcall(L.FaceTarget) end"]),
]
MUTATIONS = [
    ("HUD", "server rule: the nearest anywhere (the front half ignored)", "\t\treturn front or near\n", "\t\treturn near or front\n"),
    ("HUD", "ServerHint ignored (score without the server)", "Score = manual and A.ServerHint == true,", "Score = manual,"),
    ("HUD", "no keeping the target", "\tif keep and current ~= nil then\n", "\tif false then\n"),
    ("HUD", "a kept target stays beyond Range", "if c.Key == current and c.D <= c.Range then return current end",
     "if c.Key == current then return current end"),
    ("HUD", "new picks to the very edge (no Inside)", "if c.D <= c.Range * cfg.Inside and not", "if c.D <= c.Range and not"),
    ("HUD", "monsters behind me far are picked", " and not (c.Dot < cfg.BackDot and c.D > cfg.BackNear) then", " then"),
    ("HUD", "the monster hitting me is not first", "+ (c.Attacker and cfg.WAttacker or 0)", "+ 0"),
    ("HUD", "no screen-centre weight", "+ cfg.WScreen * math.max(0, c.CamDot)", "+ 0"),
    ("HUD", "attacker = any windup at any distance", "Attacker = serverNow - windup < attackerFor and d <= attackerReach",
     "Attacker = serverNow - windup < attackerFor"),
    ("HUD", "a snap again (no ease)", "\t\tk = 1 - (1 - k) * (1 - k) -- ease out\n", "\t\tk = 1\n"),
    ("HUD", "turns even when almost facing it", "\tif math.abs(delta) < math.rad(tonumber(A.SkipDeg) or 10) then return false end\n", ""),
    ("HUD", "walking: the body never walks on", "\t\t\tif L.AIM.Hold == token and hum.Parent then hum.AutoRotate = true end\n", ""),
    ("HUD", "walking: the body is not held on the target", "\t\thum.AutoRotate = false\n", ""),
    ("HUD", "hidden ambushers are targeted", " and m:GetAttribute(\"Hidden\") ~= true\n", "\n"),
    ("HUD", "someone else's monsters are targeted", "\t\t\tand (owner == nil or owner == me) then\n", "\t\t\tthen\n"),
    ("HUD", "dead monsters are targeted", "and (not mh or mh.Health > 0) and m:GetAttribute", "and m:GetAttribute"),
    ("HUD", "auto combat shows the ring / keeps targets", "\tlocal manual = which ~= nil\n", "\tlocal manual = true\n"),
    ("HUD", "auto combat turns away from my kept target", "\tif not manual and keep then return false end\n", ""),
    ("HUD", "the basic attack uses the class row (bare hands reach 10+)",
     "which == \"Swing\" and Config.AttackProfile(getClass(), math.floor(num(\"WeaponTier\", 0)), getFaction())\n\t\tor Config.Classes[getClass()]",
     "Config.Classes[getClass()]"),
    ("HUD", "the ring stays on a dead target", "if not m or (mh and mh.Health <= 0) or", "if not m or"),
    ("HUD", "the ring stays forever", "\t\t\tor os.clock() - L.AIM.LastAttack >= (tonumber(A.RingShow) or 1.5) then\n", "\t\t\tthen\n"),
    ("HUD", "the ring keeps its first size", "\t\tif L.AIM.RingFor ~= t then -- a new target: size to its body\n",
     "\t\tif L.AIM.RingFor == nil then -- a new target: size to its body\n"),
    ("HUD", "the ring floats at the root", "t.Position.Y - up + 0.1", "t.Position.Y + 0.1"),
    ("HUD", "Swing goes without my pick", "\tfire(\"Swing\", target)\n", "\tfire(\"Swing\")\n"),
    ("CONFIG", "ServerHint off although the server takes the pick", "\tServerHint = true,\n", "\tServerHint = false,\n"),
    ("CONFIG", "a slow turn", "TurnTime = 0.08,", "TurnTime = 0.3,"),
]


def cut(hud: str) -> str:
    a = hud.find(CUT_START)
    b = hud.find(CUT_END, a)
    if a < 0 or b < 0:
        raise ValueError("HUD.PickTarget .. L.SwingFaced block missing; update the cutter")
    # 세세한 게임성 #1 (10/18): SwingFaced goes through L.SwingGate (L.SwingBuffer, HUD.SwingPlan) right above it
    sf = hud.find("\nL.SwingBuffer = {", b)
    sf_end = hud.find("\nend\n", hud.find("\nfunction L.SwingFaced()\n", b)) + 5
    return hud[a:b] + "\n" + hud[sf:sf_end]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(src: dict) -> tuple[int, int, str]:
    try:
        hud_part = cut(src["HUD"])
    except ValueError as e:
        return 0, 1, str(e)
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal HUD_SOURCE = " + lua_str(hud_part) + "\n"
            + FIXTURE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "auto_face.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"AUTO_FACE_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed = int(m[2]) if m else 1
    for name, key, needles in STATIC:
        ok = all(src[key].count(n) == 1 for n in needles)
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
        failed += 0 if ok else 1
    # the flag follows the server: on once CombatService takes the pick (HINT.Pick), off while it takes none
    takes_pick = "function HINT.Pick(player, pos, range, hint)" in src["COMBAT"]
    hint_on = re.search(r"\n\tServerHint = true,\n", src["CONFIG"]) is not None
    ok = hint_on == takes_pick
    out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + "ServerHint on exactly when CombatService takes the pick"
    failed += 0 if ok else 1
    return (int(m[1]) if m else 0) + len(STATIC) + 1, failed, out


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
    status = "passed" if failed == 0 and checks > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
