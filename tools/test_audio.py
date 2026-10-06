"""Audio offline check (quality ① sound effects, docs/design/quality_ideas_2026-10-06.md §1).

Runs the CURRENT src/ReplicatedStorage/Shared/Config.luau and src/StarterPlayer/StarterPlayerScripts/Audio.luau, injected
into tools/fixtures/audio_offline.luau, with the installed official Luau CLI (build/luau_cli_0_741): Roblox is replaced by
small doubles (Sound copies that record their plays, signals fired by hand, task.delay queues, a Monsters folder, a
LocalPlayer and GameState with attributes, the Fx / Notify remotes). No Studio, network or Roblox API calls.

Checks (named, collected), to 검수's table (docs/design/lines_pack_2026-10-06.md §6): what each Fx packet plays (my swing per
class / style / faction, auto marked, other players' at OthersMul only within OthersRange, the bow at the arrow's launch,
ONE hit sound per swing - soft for slimes / ghosts, heavy for the rest, players, crits and 3+ monsters - the goose
honk, skills = SkillCast with my class file + the X faction layer, the combo coin 0.8 -> 1.6 with milestones, scroll
success / fail, gold outside kills, my level up, big hurts); Config.Audio (every event, its files, sane numbers, combat
<= 0.40 < level up 0.85, purify = devour, kings >= 0.85x, ducking, others, talk voices); runtime: Fx defaults muted once
our files exist, Click -> Tap, silent without an id, volume / speed from the table, auto / others multipliers, cooldown,
Max copies per event, 8 at once, the Sound effects setting, ducking and its return, the 'No' alias, typewriter voices;
listeners: auto on / off, purify / devour / RankDown (A23-58, not on a faction change), potions, kings / goose (not at
the join), Notify bad / reward, a new quest id (not the first list), windows, the combo across real Fx packets.
Mutations: in-memory copies of Audio.luau with one rule broken each; each must make a check fail that passes on the real
source. --no-mutations skips them and the status is then "passed-no-mutations" (never "passed").

Usage: py tools/test_audio.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_audio_2026-10-06.json
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tools/fixtures/audio_offline.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
AUDIO = ROOT / "src/StarterPlayer/StarterPlayerScripts/Audio.luau"
OUT = ROOT / "docs/art/verification_2026-10-06/offline_audio_2026-10-06.json"

# (name, exact text in Audio.luau, replacement): each must match exactly once
MUTATIONS = [
    ("auto sounds at full volume", "if opts.Auto == true and def.Auto == true then volume *= T.AutoMul end", ""),
    ("others at full volume", "if opts.Others == true then volume *= T.OthersMul end", ""),
    ("others heard from anywhere", "if uid == nil or d == nil or d > T.OthersRange then return out end",
     "if uid == nil then return out end"),
    ("bow twangs at the draw",
     "at = math.clamp(num(data.LaunchDelay, T.LaunchDefault), 0, 1) -- the bow twangs when the arrow leaves", "at = 0"),
    ("Neutral pitch ignored", "speedMul = num(NEUTRAL_SPEED[class], 1)", "speedMul = 1"),
    ("slimes hit heavy", 'if not (type(kind) == "string" and SOFT[kind]) then heavy = true end', "heavy = true"),
    ("three monsters stay soft", 'if heavy or monsters >= T.HitHeavyAt then return "HitHeavy", goose end',
     'if heavy then return "HitHeavy", goose end'),
    ("the goose never honks", 'if goose then add(out, "GooseHonk", at, extra) end', ""),
    ("hits play at the swing start",
     "planHits(out, data, math.clamp(num(data.ContactDelay, T.ContactDefault), 0, 1), extra, ctx)",
     "planHits(out, data, 0, extra, ctx)"),
    ("combo coin never rises",
     "local speed = math.min(num(T.Combo.Top, 1.6), num(T.Combo.Base, 0.8) * 2 ^ (step / 12))",
     "local speed = num(T.Combo.Base, 0.8)"),
    ("no combo milestone", 'if MILESTONES[combo] then add(out, "ComboMilestone", 0.15) end', ""),
    ("everyone's level up plays here", 'if own then add(out, "LevelUp", 0) end', 'add(out, "LevelUp", 0)'),
    ("every hurt is big",
     "if maxHP > 0 and amount > 0 and (amount >= maxHP * T.HurtBigFrac or hp < maxHP * T.HurtLowFrac) then",
     "if amount > 0 then"),
    ("faction layer on every skill", 'if own and data.Slot == "X" then', "if own then"),
    ("events without an id play", 'if type(id) ~= "string" or id == "" then return nil end',
     'if type(id) ~= "string" then return nil end'),
    ("Fx coin not muted", 'if idOf("ComboCoin") then fx.Coin = "" end', ""),
    ("Sound effects setting ignored", "\tif mult <= 0 then return false end\n", "\n"),
    ("no cooldown", "if last and now - last < num(def.Gap, 0.03) then return false end", ""),
    ("no copies cap", "if #pool >= math.max(1, math.floor(num(def.Max, 1))) then return nil end", ""),
    ("no 8-at-once cap", "if playingCount() >= T.MaxPlaying then return false end", ""),
    ("no ducking", "S.Groups.Combat.Volume = num(T.Duck.Mul, 0.5)", ""),
    ("join-time auto values sound", "if prev == nil or not loaded() then return end", "if false then return end"),
    ("a faction change counts as RankDown", "elseif v < prev and os.clock() - S.FactionAt > T.FactionCalm then",
     "elseif v < prev then"),
    ("buying potions chimes",
     'if type(prev) == "number" and type(v) == "number" and v < prev and loaded() then Audio.Play("Potion") end',
     'if type(v) == "number" and loaded() then Audio.Play("Potion") end'),
    ("kings already there at the join sound", "if v == true and prev ~= true and fresh() then Audio.Play(event) end",
     "if v == true and prev ~= true then Audio.Play(event) end"),
    ("the first quest list chimes", "if S.QuestIds and not S.QuestIds[id] then fresh = true end",
     "if not (S.QuestIds and S.QuestIds[id]) then fresh = true end"),
    ("a window staying open repeats", "if was ~= nil and was ~= open then", "if open or was ~= open then"),
    ("combo never resets", "if S.ComboToken == token then S.Combo = 0 end", ""),
    ("'No' is not Deny", 'Aliases = { No = "Deny" },', "Aliases = {},"),
]


def lua_long(text: str) -> str:
    eq = "===="
    while f"]{eq}]" in text:
        eq += "="
    return f"[{eq}[{text}]{eq}]"


def harness(config: str, audio: str) -> str:
    return (f"local CONFIG_SOURCE = {lua_long(config)}\nlocal AUDIO_SOURCE = {lua_long(audio)}\n"
            + FIXTURE.read_text(encoding="utf-8"))


def run(binary: Path, text: str, directory: Path, name: str) -> dict:
    path = directory / name
    path.write_text(text, encoding="utf-8")
    proc = subprocess.run([str(binary), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                          errors="replace", timeout=300)
    result = None
    for line in proc.stdout.splitlines():
        if line.startswith("AUDIO_RESULT_JSON "):
            result = json.loads(line[len("AUDIO_RESULT_JSON "):])
    return {"stdout": proc.stdout, "stderr": proc.stderr, "result": result}


def failing(result: dict | None) -> set[str]:
    if not result:
        return set()
    return {f"{n['Group']} :: {n['Name']}" for n in result.get("Named", []) if n.get("Fail", 0) > 0}


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", type=Path, default=ROOT / "build/luau_cli_0_741/luau.exe")
    parser.add_argument("--no-mutations", action="store_true")
    args = parser.parse_args()
    binary = args.luau.resolve()
    compiler = binary.with_name("luau-compile" + binary.suffix)
    if not binary.is_file() or not compiler.is_file():
        print("Installed Luau CLI missing; this test never downloads tools.", file=sys.stderr)
        return 1
    raw = {p: p.read_bytes() for p in (CONFIG, AUDIO, FIXTURE)}
    config = raw[CONFIG].decode("utf-8-sig").replace("\r\n", "\n")
    audio = raw[AUDIO].decode("utf-8-sig").replace("\r\n", "\n")
    compiled = subprocess.run([str(compiler), str(AUDIO), str(FIXTURE)], cwd=ROOT, stdout=subprocess.DEVNULL,
                              stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace", timeout=120)
    mutations = []
    with tempfile.TemporaryDirectory(prefix="audio_") as tmp:
        tmpdir = Path(tmp)
        real = run(binary, harness(config, audio), tmpdir, "audio_real.luau")
        base = failing(real["result"])
        if not args.no_mutations:
            jobs = []
            for name, old, new in MUTATIONS:
                hits = audio.count(old)
                if hits != 1:
                    mutations.append({"mutation": name, "applied": False, "caught": False,
                                      "note": f"pattern matched {hits} times; update MUTATIONS"})
                    continue
                jobs.append((name, harness(config, audio.replace(old, new, 1))))

            def work(index_job):
                index, (name, text) = index_job
                m = run(binary, text, tmpdir, f"audio_mut_{index:02d}.luau")
                new_fail = sorted(failing(m["result"]) - base)
                crashed = m["result"] is None
                return {"mutation": name, "applied": True, "caught": crashed or bool(new_fail), "crashed": crashed,
                        "newFailingChecks": new_fail[:6]}

            with ThreadPoolExecutor(max_workers=6) as pool:
                mutations.extend(pool.map(work, enumerate(jobs)))
    changed = [p.relative_to(ROOT).as_posix() for p, b in raw.items() if p.read_bytes() != b]
    result = real["result"] or {}
    named = result.get("Named", [])
    bad = [n for n in named if n.get("Fail", 0) > 0]
    real_ok = real["result"] is not None and not bad and "AUDIO_OFFLINE_OK" in real["stdout"]
    mut_ok = all(m.get("applied") and m.get("caught") for m in mutations)
    if compiled.returncode == 0 and real_ok and not changed and mut_ok:
        status = "passed-no-mutations" if args.no_mutations else "passed"
    else:
        status = "failed"
    report = {
        "status": status,
        "checks": result.get("Checks", 0),
        "namedChecks": len(named),
        "failing": [{"group": n["Group"], "check": n["Name"], "firstFailure": n.get("FirstFailure")} for n in bad],
        "mutations": {"total": len(MUTATIONS), "caught": sum(1 for m in mutations if m.get("caught")), "results": mutations},
        "compileOk": compiled.returncode == 0,
        "compileErrors": compiled.stderr.strip(),
        "runtimeError": None if real["result"] else (real["stderr"].strip() or real["stdout"].strip())[-2000:],
        "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(b).hexdigest() for p, b in raw.items()},
        "sourcesChangedDuringRun": changed,
        "studioCalls": 0, "apiCalls": 0,
        "limitations": "Doubles instead of the engine: real playback, loading and loudness are checked in Studio and by "
                       "ear; the combo / QuietStart timings use os.clock busy waits and a hand-run task.delay queue.",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if compiled.returncode:
        print(compiled.stderr, end="")
    for line in real["stdout"].splitlines():
        if line.startswith("AUDIO_OFFLINE") or line.startswith("CHECK_FAIL"):
            print(line)
    if not real["result"]:
        print(real["stderr"], end="")
    for m in mutations:
        print(f"MUTATION {'caught ' if m.get('caught') else 'MISSED'} {m['mutation']}"
              + ("" if m.get("applied") else f" ({m.get('note')})"))
    print(f"Named checks: {len(named) - len(bad)} passed, {len(bad)} failing")
    print(f"Status: {status}")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if status in ("passed", "passed-no-mutations") else 1


if __name__ == "__main__":
    raise SystemExit(main())
