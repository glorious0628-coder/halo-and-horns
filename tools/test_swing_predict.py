"""손맛 ① (GPT build/codex/game_feel_r1.md TOP 1, 최종 검수 2026-10-16) - my body's basic attack starts on my press.

Measured 10/16 (docs/art/verification_2026-10-16/attack_feel): my own swing waited for the server's Swing Fx. Static
checks on the current sources:
- HUD L.SwingFaced: face the target, Fx.PredictSwing, then the Swing remote (no delay);
- Fx.PredictSwing: only when the swing is ready (the class interval of Config.AttackProfile since my last own swing;
  inside it the server's 0.20 s reservation does the next one - no second reservation here), plays my body's swing and
  the whoosh only - A23-196: no target flash, number, hit sound or ring before the server confirms;
- handlers.Swing: the next own Manual Swing Fx within Window s pairs with that press and plays no second swing; an auto
  swing (Manual not true) or a late Fx swings as before.
Mutations: in-memory copies with one rule broken each; each must be caught.

Usage: py tools/test_swing_predict.py
Report: docs/art/verification_2026-10-16/offline_swing_predict_2026-10-16.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
FILES = {"FX": ROOT / "src/StarterPlayer/StarterPlayerScripts/Fx.luau",
         "HUD": ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau"}
OUT = ROOT / "docs/art/verification_2026-10-16/offline_swing_predict_2026-10-16.json"

NEEDLES = [
    ("HUD", "the press: face, my body's swing, then the remote", [
        "\tlocal _, target = L.FaceTarget(\"Swing\")\n", "pcall(fx.PredictSwing) end\n\tfire(\"Swing\", target)\nend"]),
    ("FX", "only when the swing is ready (no early move inside the cooldown)", [
        "if now - P.LastSwing < asNum(prof.SwingInterval, 1) - P.Gap then return false end"]),
    ("FX", "the class's real swing (the profile's style, bare hands = the punch)", [
        "local prof = Config.AttackProfile(classId, me:GetAttribute(\"WeaponTier\"), faction)", "Style = prof.Style,"]),
    ("FX", "the pair: the next own Manual Fx within Window plays no second swing", [
        "if data.Manual == true and P.Pending and os.clock() - P.Pending <= P.Window then",
        "P.Pending = nil -- my press already plays this swing"]),
    ("FX", "an unpaired own Fx swings as before", ["\t\t\tFx.PlaySound(\"Swing\")\n\t\t\tanimateOwnAttack(data, \"Swing\")\n\t\t\tP.LastSwing = os.clock()\n"]),
]


def run(files: dict[str, str]) -> tuple[int, int, list[str]]:
    lines, checks, failed = [], 0, 0

    def check(name, ok, detail=""):
        nonlocal checks, failed
        checks += 1
        failed += 0 if ok else 1
        lines.append(("CHECK_OK " if ok else "CHECK_FAIL ") + name + ("" if ok else f" :: {detail}"))

    for fk, name, needles in NEEDLES:
        miss = [n for n in needles if files[fk].count(n) != 1]
        check(f"{fk}: {name}", not miss, miss)
    m = re.search(r"\nfunction Fx\.PredictSwing\(\)\n(.*?)\nend\n", files["FX"], re.S)
    body = m[1] if m else ""
    check("A23-196: the early swing shows no hit (no flash / number / hit sound / ring / hits)", body != "" and not re.search(
        r"showHits|flash|Number|spawnNumber|ring\(|Hit|burst|Shake", body), "")
    check("no second reservation on the client (the server's 0.20 s one stays the only one)",
          not re.search(r"Queue|Reserve|Buffer|task\.delay", body), "")
    return checks, failed, lines


MUTATIONS = [
    ("HUD", "the remote before my body", "pcall(fx.PredictSwing) end\n\tfire(\"Swing\", target)\nend",
     "pcall(print) end\n\tfire(\"Swing\", target)\n\tpcall(fx.PredictSwing)\nend"),
    ("FX", "an early swing inside the cooldown", "if now - P.LastSwing < asNum(prof.SwingInterval, 1) - P.Gap then return false end", ""),
    ("FX", "the server's Fx restarts the swing", "P.Pending = nil -- my press already plays this swing (Fx.PredictSwing): no restart",
     "animateOwnAttack(data, \"Swing\") -- my press already plays this swing"),
    ("FX", "an auto swing pairs with a press", "if data.Manual == true and P.Pending and", "if P.Pending and"),
    ("FX", "a hit flash before the server", "\tP.Pending, P.LastSwing = now, now\n", "\tP.Pending, P.LastSwing = now, now\n\tflashMonstersAt({})\n"),
    ("FX", "a client-side reservation", "\tP.Pending, P.LastSwing = now, now\n", "\tP.Pending, P.LastSwing = now, now\n\ttask.delay(0.2, Fx.PredictSwing)\n"),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    files = {k: p.read_text(encoding="utf-8").replace("\r\n", "\n") for k, p in FILES.items()}
    checks, failed, lines = run(files)
    print("\n".join(lines))
    muts = []
    for fk, name, old, new in MUTATIONS:
        hits = files[fk].count(old)
        caught = False
        if hits == 1:
            copy = dict(files)
            copy[fk] = files[fk].replace(old, new)
            caught = run(copy)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    status = "passed" if failed == 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
