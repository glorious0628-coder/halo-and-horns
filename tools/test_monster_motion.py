"""Offline test of the production MonsterMotion (monster motion review 2026-10-06, survey 4-1), plus mutations.

Every attack restarts Slash; the wind-up (WindupAt) starts it at HitTime - wind-up so the clip's fastest frame meets the
impact; an AttackSeq without a seen wind-up shows the follow-through; Walk runs at real speed / chase Speed (0.45-1.5x)
and a chase at 75%+ of that speed plays Run; a standing monster plays one LookAround every 6-12 s (moving cuts it);
loops start at each monster's own phase and +-8% speed; beaten (A23-211) stays Idle, no fall
0.5 s after death; Leaving monsters float (Idle). Real Goblin clip modules; Config numbers read from Config.luau.
Status "passed" only when the fixture passes AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-06/offline_monster_motion_2026-10-06.json
"""
from pathlib import Path
import hashlib
import json
import math
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src/StarterPlayer/StarterPlayerScripts/MonsterMotion.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
ANIMS = ROOT / "src/ReplicatedStorage/MonsterAnims"
FIXTURE = ROOT / "tools/fixtures/monster_motion_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-06/offline_monster_motion_2026-10-06.json"
CLIP_NAMES = ["Idle", "Walk", "Run", "LookAround", "Slash", "Hurt"]

MUTATIONS = [
    ("Slash never restarts while it plays (token ignored)",
     "if st.Clip == name and st.PlayToken == token then return end", "if st.Clip == name then return end"),
    ("the wind-up no longer starts the swing", "startSlash(st, c, M.HitTime(c) - toImpact)", "local _ = toImpact"),
    ("the swing starts at its first frame (not aligned)", "startSlash(st, c, M.HitTime(c) - toImpact)", "startSlash(st, c, 0)"),
    ("every AttackSeq restarts the swing", "if not c or os.clock() - st.SlashSeenAt <= M.SlashFresh then return end",
     "if not c then return end"),
    ("HitTime takes the first frame", "if sum > best then best, bestI = sum, i end", "if best < 0 then best, bestI = sum, i end"),
    ("Walk ignores the real speed",
     "rate = st.Rate * math.clamp(ratio, M.WalkRate.Min, M.WalkRate.Max)", "rate = st.Rate"),
    ("a beaten monster plays a hurt again", 'want = "Idle" -- beaten (A23-211', 'want, once = "Hurt", true -- beaten (A23-211'),
    ("loops all start in step", "st.T = from or (once and 0 or st.Phase * clip.Length)", "st.T = from or 0"),
    ("every monster loops at the same speed", "Rate = 1 + (math.random() * 2 - 1) * M.Jitter,", "Rate = 1 + 0 * math.random(),"),
    ("a chase walks (Run never played)", 'want = (ratio >= M.RunAbove and clipFor(st.Kind, "Run")) and "Run" or "Walk"',
     'want = "Walk"'),
    ("a standing monster never looks around", 'if now < st.LookUntil then want, once = "LookAround", true end', ""),
    ("moving does not cut the LookAround", "\t\t\t\t\tst.LookUntil = 0\n\t\t\t\t\tlocal ratio", "\t\t\t\t\tlocal ratio"),
    ("LookAround right after the last one (no 6-12 s gap)",
     "st.LookAt = now + (look and look.Length or 0) + M.LookEvery[1]", "st.LookAt = now + 0 * M.LookEvery[1]"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    eq = "=" * level
    return f"[{eq}[{s}]{eq}]"


def hit_time(text: str) -> float:
    fps = int(re.search(r"Fps = (\d+)", text).group(1))
    frames = int(re.search(r"Frames = (\d+)", text).group(1))
    rs = [[float(x) for x in b.split(",")] for b in re.findall(r"r = \{ ([^}]*) \}", text)]
    best, bi = -1.0, 0
    for i in range(frames - 1):
        t = 0.0
        for r in rs:
            dot = sum(r[i * 4 + k] * r[i * 4 + 4 + k] for k in range(4))
            t += 2 * math.acos(min(1.0, abs(dot)))
        if t > best:
            best, bi = t, i
    return (bi + 0.5) / fps


def harness(source: str) -> str:
    config = CONFIG.read_text(encoding="utf-8")
    windup = float(re.search(r"MonsterWindup = ([\d.]+)", config).group(1))
    speed = float(re.search(r"^\tGoblin = \{[^\n]*?Speed = ([\d.]+)", config, re.M).group(1))
    clips = {name: (ANIMS / f"Goblin_{name}.luau").read_text(encoding="utf-8") for name in CLIP_NAMES}
    bones = re.findall(r'\["([^"]+)"\] = \{ r =', clips["Slash"])
    parts = ["local SOURCE = " + lua_str(source), "local CLIPS = {"]
    for name, text in clips.items():
        parts.append(f'\t["Goblin_{name}"] = {lua_str(text)},')
    parts.append("}")
    parts.append(f"local WINDUP, GOBLIN_SPEED = {windup!r}, {speed!r}")
    parts.append(f"local EXPECT_SLASH_HIT = {hit_time(clips['Slash'])!r}")
    parts.append("local BONES = {" + ", ".join(f'"{b}"' for b in bones) + "}")
    return "\n".join(parts) + "\n" + FIXTURE.read_text(encoding="utf-8")


def run(source: str, name: str):
    path = ROOT / f"build/monster_motion_offline{name}.luau"
    path.write_text(harness(source), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=120)
    match = re.search(r"MONSTER_MOTION_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    source = SOURCE.read_text(encoding="utf-8-sig")
    compile_run = subprocess.run([str(BINARY.with_name("luau-compile.exe")), str(SOURCE)], cwd=ROOT,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, timeout=60)
    ok, checks, fails, result = run(source, "")
    print(result.stdout, end="")
    print(compile_run.stderr + result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = source.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(source.replace(old, new), "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    passed = compile_run.returncode == 0 and ok and all(r["applied"] and r["caught"] for r in rows)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in [SOURCE, CONFIG] + [ANIMS / f"Goblin_{n}.luau" for n in CLIP_NAMES]},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
              "studioCalls": 0,
              "contract": __doc__.split("Status")[0].strip(),
              "limitations": "Bone poses, real Bone.Transform playback, RenderStepped timing and the server's AttackSeq / "
                             "WindupAt timing need a Studio check."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
