"""SkillBar A23-180 gate + X hop prep offline test (user 10/14: no refusal words; the screen gates first).

A23-180 (최종 검수 10/14, server dev2 5bd777c5): the server no longer refuses a press (no monster = a cast at the air;
PressBuffer s of cooldown left = it waits) and answers only "Queued". So SkillBar shows no refusal words and no shake;
SkillBar.Gate decides first: a slot not learned, MP below the cost, more than Config.Skills.PressBuffer (0.35 s) of
cooldown, or the Hop slot (Shape Hop) while carrying the grudge sack (SackGold) / as a kaiju (KaijuState Siren, Active) /
with a goose egg (EggCarry) = nothing sent, nothing said, no sound; 0.35 s or less left = sent; the server's SkillPress
answers show nothing; the carry attributes repaint the bar. X hop prep (archer X, tamer Big Boing; XEnabled stays
off): Fx "Hop" { To, T } moves my own character along a low arc to To at its ground height (uphill too), keeps the
facing, ends still; a far / broken To, a knocked-out or new character = no move.
Runs the real SkillBar.luau + Config.luau in tools/fixtures/skill_press_offline.luau with the official Luau CLI.
Status "passed" only when the fixture passes AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-14/offline_skill_press_2026-10-14.json (do not commit)
"""
from pathlib import Path
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
BAR = ROOT / "src/StarterPlayer/StarterPlayerScripts/SkillBar.luau"
FIXTURE = ROOT / "tools/fixtures/skill_press_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-14/offline_skill_press_2026-10-14.json"

MUTATIONS = [
    ("MP short still sends", '\tif st.MPShort then return false, "MP" end\n', ""),
    ("carrying still hops", '\tif st.Heavy then return false, "Heavy" end\n', ""),
    ("any cooldown blocks (no buffer)", "if (tonumber(st.Left) or 0) > (tonumber(buffer) or T.PressBuffer) then", "if (tonumber(st.Left) or 0) > 0 then"),
    ("a long cooldown still sends", '\tif (tonumber(st.Left) or 0) > (tonumber(buffer) or T.PressBuffer) then return false, "Cooldown" end\n', ""),
    ("the buffer at 0.35 s blocks too", "if (tonumber(st.Left) or 0) > (tonumber(buffer) or T.PressBuffer) then",
     "if (tonumber(st.Left) or 0) >= (tonumber(buffer) or T.PressBuffer) then"),
    ("Use ignores the gate", "\tif not SkillBar.Gate(st, pressBuffer()) then return false end\n", ""),
    ("the sack ignored", 'num("SackGold", 0) > 0 or ', ""),
    ("the egg ignored", "\n\t\t\tor num(\"EggCarry\", 0) > 0", ""),
    ("every skill is a Hop", 'Hop = def ~= nil and def.Shape == "Hop",', "Hop = true,"),
    ("carrying never repaints", '\tUIKit.OnAttr({ "SackGold", "KaijuState", "EggCarry" }, refreshAll) -- A23-180: what blocks the Hop slot\n', ""),
    ("no hop move", '\t\t\tif kind == "Hop" then', '\t\t\tif false then'),
    ("a hop of any length", '\tif flat < 0.5 or flat > HOP.MaxDist then return false end\n', ''),
    ("a hop while knocked out", '\tif not (root and hum and hum.Health > 0) then return false end\n', '\tif not (root and hum) then return false end\n'),
    ("the landing ignores the ground", '\tlocal to = SkillBar.HopLanding(from, data.To, groundY(from, char), groundY(data.To, char))\n',
     '\tlocal to = data.To\n'),
    ("a flat hop (no arc)", '+ 4 * h * a * (1 - a),', '+ 0,'),
    ("the hop turns me", '\th.Root.CFrame = h.Root.CFrame.Rotation + p\n', '\th.Root.CFrame = CFrame.new(p)\n'),
    ("the hop never ends", '\tif a >= 1 then\n\t\th.Root.AssemblyLinearVelocity = Vector3.zero\n\t\tHOP.Live = nil\n\tend\n', ''),
    ("a new character keeps hopping", '\tif LocalPlayer.Character ~= h.Char or not h.Root.Parent or h.Hum.Health <= 0 then\n',
     '\tif not h.Root.Parent or h.Hum.Health <= 0 then\n'),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(config: str, bar: str, name: str):
    path = ROOT / f"build/skill_press_offline{name}.luau"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("local CONFIG_SOURCE = " + lua_str(config) + "\nlocal BAR_SOURCE = " + lua_str(bar) + "\n"
                    + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    r = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                       errors="replace", timeout=120)
    m = re.search(r"SKILL_PRESS_SUMMARY checks=(\d+) failed=(\d+)", r.stdout)
    ok = r.returncode == 0 and m is not None and m[2] == "0"
    fails = [ln for ln in (r.stdout + r.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(m[1]) if m else 0), fails, r


def main():
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    bar = BAR.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, r = run(config, bar, "")
    print(r.stdout, end="")
    print(r.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = bar.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(config, bar.replace(old, new), "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    code = "\n".join(line.split("--", 1)[0] for line in bar.splitlines())
    static = [
        ("no refusal word typed into SkillBar (Config.Skills.Text only)", not re.search(r'"(Not yet|Not ready|Not enough MP|No target)"', code)),
        ("A23-180: no shake / floating word / server refusal display left", not re.search(r"\bshake\(|b\.Word|OnPress|skillWord", code)),
        ("the hop only on the server's Fx (no own hop input)", len(re.findall(r'(?<!function )SkillBar[.]OnHop[(]', code)) == 1),
    ]
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAIL ") + name)
    status = "passed" if ok and all(x["caught"] for x in rows) and all(g for _, g in static) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failures": fails, "mutations": rows,
                               "static": [{"check": n, "ok": g} for n, g in static], "status": status, "studioCalls": 0},
                              indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, mutations {sum(x['caught'] for x in rows)}/{len(rows)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
