"""A23-131 / A23-134 / A23-137 golden egg hunt (GooseEggs + GooseService Eggs mode, the tug in Tug mode), run offline.

Runs the CURRENT Config, GooseEggs and GooseService sources (injected into tools/fixtures/golden_egg_offline.luau) with
the installed official Luau CLI (build/luau_cli_0_741). No Studio, network, DataStore or Roblox API calls. Every check is
named and collected. Static checks read the wiring the offline run cannot reach (PlayerService speed, SkillService Hop,
ZoneService pads / Travel, CombatService Tug-only goose, CharacterVisuals EggStack, MapBuilder homes, quests, health).
A mutation step breaks in-memory copies of the sources (never src/) and counts how many mutations the checks catch.

Usage: py tools/test_golden_egg.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-12/offline_dev2_golden_egg_2026-10-12.json
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SSS = ROOT / "src/ServerScriptService"
FIXTURE = ROOT / "tools/fixtures/golden_egg_offline.luau"
OUT = ROOT / "docs/art/verification_2026-10-12/offline_dev2_golden_egg_2026-10-12.json"
FILES = {
    "CONFIG_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
    "EGGS_SOURCE": SSS / "GooseEggs.luau",
    "GOOSE_SOURCE": SSS / "GooseService.luau",
}
STATIC = {
    "PLAYER": SSS / "PlayerService.luau",
    "SKILL": SSS / "SkillService.luau",
    "ZONE": SSS / "ZoneService.luau",
    "COMBAT": SSS / "CombatService.luau",
    "VISUALS": SSS / "CharacterVisuals.luau",
    "MAP": SSS / "MapBuilder.luau",
    "STORY": SSS / "StoryQuestService.luau",
    "HEALTH": SSS / "HealthService.luau",
}
C, EG, G = "CONFIG_SOURCE", "EGGS_SOURCE", "GOOSE_SOURCE"

# (name, source key, exact text, replacement): each must match exactly once in the current source
MUTATIONS = [
    # pick
    ("pick: no slack", EG, "local reach, high = E.PickRadius + E.PickSlack, E.PickHeight + E.PickSlack",
     "local reach, high = E.PickRadius, E.PickHeight + E.PickSlack"),
    ("pick: no height rule", EG, "if d <= reach and math.abs(st.Pos.Y - egg.Pos.Y) <= high then", "if d <= reach then"),
    ("pick: standing still picks", EG, "if st.Can and st.Pos and moved(st, now) then", "if st.Can and st.Pos then"),
    ("pick: a flying egg is picked", EG, "if now >= egg.LandAt and (egg.NoPick[p] or 0) <= now then", "if (egg.NoPick[p] or 0) <= now then"),
    ("pick: the dropper re-picks at once", EG, "if now >= egg.LandAt and (egg.NoPick[p] or 0) <= now then", "if now >= egg.LandAt then"),
    ("pick: farthest first", EG, "if a.D ~= b.D then return a.D < b.D end", "if a.D ~= b.D then return a.D > b.D end"),
    ("pick: tie ignores deliveries", EG, "if a.St.Delivered ~= b.St.Delivered then return a.St.Delivered < b.St.Delivered end\n", ""),
    ("pick: no plausibility check", EG, "if plausible[p] then pick(now, p, st, egg) end", "pick(now, p, st, egg)"),
    ("slots: a big egg with full-ish hands", EG, "if slots >= E.MaxSlots then return st.Slots == 0 end", "if slots >= E.MaxSlots then return st.Slots + slots <= E.MaxSlots + 1 end"),
    ("slots: no limit", EG, "return st.Slots + slots <= E.MaxSlots\n", "return true\n"),
    ("EggCan: co-op rival may pick", EG, "if R.Mode == \"Coop\" and f ~= R.CoopSide then return false end", ""),
    ("EggCan: kaiju may pick", EG, "if not isSide(f) or W.Blocked(p) then return false end", "if not isSide(f) then return false end"),
    ("EggCan: Neutral off", EG, "if f == \"Neutral\" then return true end", "if f == \"Neutral\" then return false end"),
    # deliver / H
    ("deliver: H not applied", EG, "local add = math.floor(pts * hFor(side, now) + 0.5)", "local add = pts"),
    ("deliver: H not rounded", EG, "local add = math.floor(pts * hFor(side, now) + 0.5)", "local add = pts * hFor(side, now)"),
    ("H: no cap", EG, "return math.clamp(math.sqrt(other / mine), 1, E.HMax)", "return math.sqrt(other / mine)"),
    ("H: no square root", EG, "return math.clamp(math.sqrt(other / mine), 1, E.HMax)", "return math.clamp(other / mine, 1, 3)"),
    ("H: N = entrants, not presence", EG, "local mine, other = R.Presence[side] / el, R.Presence[SIDES[side]] / el",
     "local mine, other = entrants(side), entrants(SIDES[side])"),
    ("deliver: any home", EG, "flat(st.Pos, E.Home[st.Faction]) <= E.HomeRadius then", "(flat(st.Pos, E.Home.Halo) <= E.HomeRadius or flat(st.Pos, E.Home.Horns) <= E.HomeRadius) then"),
    ("deliver: EggDelivered not set", EG, "\tsetAttr(p, \"EggDelivered\", st.Delivered)\n", ""),
    ("cheat: enforced", C, "Cheat = { SpeedSlack = 1.4, Grace = 0.3, Enforce = false },", "Cheat = { SpeedSlack = 1.4, Grace = 0.3, Enforce = true },"),
    # returns / order
    ("return: ring 50", EG, "elseif flat(st.Pos, E.Center) > E.RingRadius then", "elseif flat(st.Pos, E.Center) > 50 then"),
    ("return: no idle return", EG, "\t\t\telseif now - st.StillAt >= E.IdleReturn then\n\t\t\t\treturnCarry(p, st, \"Idle\", froms)\n", ""),
    ("return: idle 5 s", C, "IdleReturn = 10, IdleWobble = 7,", "IdleReturn = 5, IdleWobble = 4,"),
    ("return: faction change kept", EG, "if st.Faction ~= f and #st.Carry > 0 then returnCarry(p, st, \"Faction\") end", ""),
    ("return: a leaver keeps", EG, "\t\tif not seen[p] and (#st.Carry > 0 or st.Can or st.Plaza) then\n\t\t\treturnCarry(p, st, \"Leave\")",
     "\t\tif not seen[p] and (#st.Carry > 0 or st.Can or st.Plaza) then\n\t\t\tlocal _ = 0"),
    ("return: unpicked 30 s", C, "GroundCap = 30, Unpicked = 15,", "GroundCap = 30, Unpicked = 30,"),
    ("return: Travel ignored", EG, "\tif st then returnCarry(p, st, reason or \"Travel\") end", "\tlocal _ = st"),
    ("order: end before deliver", EG, "\tlocal el = now - R.T0\n\tlocal dt = math.clamp(now - R.LastStep, 0, 1)",
     "\tlocal el = now - R.T0\n\tif el >= E.Duration then return \"Done\" end\n\tlocal dt = math.clamp(now - R.LastStep, 0, 1)"),
    ("end: ground eggs picked at 60", EG, "\tif el < E.Duration then\n\t\treturnGround(now, false)", "\tpickAll(now)\n\tif el < E.Duration then\n\t\treturnGround(now, false)"),
    # overtime / laying / crown / naps
    ("overtime: none", EG, "\t\tif crownCarried() then R.Overtime = R.EndsAt + E.Crown.Overtime end\n", ""),
    ("overtime: 12 s", C, "Crown = { At = 50, Min = 50, Share = 0.15, Gold = 4, Overtime = 8 },", "Crown = { At = 50, Min = 50, Share = 0.15, Gold = 4, Overtime = 12 },"),
    ("laying: never stops", EG, "if el >= E.LayStop or el >= E.Crown.At and not R.CrownLaid then return end", "if false then return end"),
    ("laying: no hurry", EG, "if el >= E.Hurry.From and el < E.Hurry.To then rate *= E.Hurry.Mult end", ""),
    ("laying: rate ignores P", EG, "local rate = math.clamp(E.Rate.Base + E.Rate.PerPlayer * R.P, E.Rate.Min, E.Rate.Max)", "local rate = E.Rate.Min"),
    ("laying: lays while napping", EG, "\tif R.Goose.Act == \"Nap\" then return end\n", ""),
    ("crown: always 50", EG, "local pts = math.max(E.Crown.Min, math.floor(E.Crown.Share * (R.Rescue + R.Poach) + 0.5))", "local pts = E.Crown.Min"),
    ("crown: anywhere", EG, "\t\t\tlocal west = function(x) return x < c.X end\n", "\t\t\tlocal west = nil\n"),
    ("nap: big egg anywhere", EG, "\tlocal egg = layEgg(now, \"Big\", { Half = half, Any = true })", "\tlocal egg = layEgg(now, \"Big\", { Any = true })\n\thalf = nil"),
    ("bouncy: from 0 s", C, "Bouncy = { From = 30, Share = 0.15, Near = 7, Hop = 6, Hops = 3 },", "Bouncy = { From = 0, Share = 0.15, Near = 7, Hop = 6, Hops = 3 },"),
    ("bouncy: endless hops", EG, "if egg.Kind == \"Bouncy\" and egg.Hops < B.Hops and now >= egg.LandAt then", "if egg.Kind == \"Bouncy\" and now >= egg.LandAt then"),
    ("sneeze: no feathers", C, "Sneeze = 6, ArrivalFeathers = 3, NapFeathers = 1,", "Sneeze = 6, ArrivalFeathers = 0, NapFeathers = 1,"),
    # drop spots
    ("drop: basin 10", C, "Drop = { Min = 4, Max = 10, Fountain = 14,", "Drop = { Min = 4, Max = 10, Fountain = 10,"),
    ("drop: ring 50", C, "Home = 16, Ring = 46, Step = 4,", "Home = 16, Ring = 50, Step = 4,"),
    ("drop: home 10", C, "Home = 16, Ring = 46, Step = 4,", "Home = 10, Ring = 46, Step = 4,"),
    ("drop: water allowed", EG, "if y == nil or water then return nil end", "if y == nil then return nil end"),
    ("drop: no step rule", EG, "if math.abs(y - footY) > D.Step then return nil end", ""),
    ("drop: no prop check", EG, "if W.PropHit(v3(x, y, z)) then return nil end", ""),
    ("drop: altar / spawn allowed", EG, "\t\tif flat(p, a) < D.AvoidRadius then return nil end\n", ""),
    ("goose: into the basin", EG, "local k = math.clamp(d, Wk.MinFountain, Wk.MaxRing) / d", "local k = math.clamp(d, 0, Wk.MaxRing) / d"),
    # chase / tag
    ("chase: the trailing side", EG, "\tlocal side = leader()\n\tif not side then return nil end\n\tlocal best", "\tlocal side = leader()\n\tif not side then return nil end\n\tside = SIDES[side]\n\tlocal best"),
    ("chase: twice per player", EG, "\t\t\t\tR.Players[target].Chased = true\n", ""),
    ("chase: no alert second", EG, "ch = { Target = target, Start = R.T0 + t, Until", "ch = { Target = target, Start = R.T0 + t - E.ChaseAlert, Until"),
    ("tag: no hold", EG, "if now - ts.TagSince[v] >= T.Hold - 1e-6 then", "if true then"),
    ("tag: no shield", EG, "\t\t\t\t\t\tvs.Shield = now + T.Shield\n", ""),
    ("tag: no cooldown", EG, "\t\t\t\t\t\tts.TagReady = now + T.Cooldown\n", ""),
    ("tag: Neutral tags", EG, "local rival = ts.Can and isSide(ts.Faction) and ts.Faction ~= vs.Faction", "local rival = ts.Can and ts.Faction ~= vs.Faction"),
    ("tag: off", C, "Tag = { On = true, Radius = 3, Hold = 1, Shield = 3, Cooldown = 4 },", "Tag = { On = false, Radius = 3, Hold = 1, Shield = 3, Cooldown = 4 },"),
    # Neutral / feathers / items
    ("Neutral: carries eggs", EG, "\tif st.Faction == \"Neutral\" then -- A23-134: straight to the bag", "\tif false then -- A23-134: straight to the bag"),
    ("Neutral: no top bonus", EG, "\t\t\t\tW.Grant(p, E.Items.Egg, bonus, nil)\n", ""),
    ("Neutral: bonus is +50% rounded up", EG, "local bonus = math.max(1, math.floor(n * (E.NeutralTopMult - 1)))", "local bonus = math.ceil(n * (E.NeutralTopMult - 1))"),
    ("feather: takes a slot", C, "Feather = { Points = 0, Slots = 0 }, -- A23-134", "Feather = { Points = 0, Slots = 1 }, -- A23-134"),
    ("items: GoldenEgg not after Petal", C, "\"Jelly\", \"Petal\", \"GoldenEgg\", \"GooseFeather\",", "\"Jelly\", \"GoldenEgg\", \"GooseFeather\", \"Petal\","),
    ("speed: no carry multiplier", C, "local mult = n > 0 and E.Carry[n] or 1", "local mult = 1"),
    ("speed: plaza base 22", C, "PlazaSpeed = 20, -- A23-134", "PlazaSpeed = 22, -- A23-134"),
    # GooseService (Eggs mode)
    ("schedule: the old war-round clock", G, "\tif eggsOn() then\n\t\t-- A23-137: fixed KST clock times", "\tif false then\n\t\t-- A23-137: fixed KST clock times"),
    ("schedule: UTC, not KST", G, "local tz = tonumber(sch.TzOffset) or 32400", "local tz = 0"),
    ("schedule: every 10 min", C, "Schedule = { Every = 14400, TzOffset = 32400 },", "Schedule = { Every = 600, TzOffset = 32400 },"),
    ("war: +60 again", C, "WinWarPoints = 30, -- A23-137", "WinWarPoints = 60, -- A23-137"),
    ("verdict: a side out of the ring still counts", G, "local goneR = (entr.Horns or 0) <= 0 or horns <= 0", "local goneR = horns <= 0"),
    ("co-op: target never grows", G, "coop.People, coop.Target = people, coopTargetFor(people)", "coop.People, coop.Target = people, coopTargetFor(0)"),
    ("co-op: the tug's 20 per person", G, "local per = tonumber(eggsOn() and EGG.CoopPerPerson or Config.Goose.CoopPerPerson) or 20",
     "local per = tonumber(Config.Goose.CoopPerPerson) or 20"),
    ("paid: one egg always enough", G, "and (tonumber(EGG.MinCrowd) or 1) or (tonumber(EGG.MinDelivered) or 2)", "and 1 or 1"),
    ("paid: points ignored", G, "return (delivered or 0) >= need or (points or 0) >= (tonumber(EGG.MinPoints) or 20)", "return (delivered or 0) >= need"),
    ("paid: no crowd rule", G, "local need = (peakP or 0) >= (tonumber(EGG.CrowdFrom) or 16)", "local need = false"),
    ("notify: no 'Bring 2 eggs'", G, "\t\t\t\tif msg then pcall(Net.Notify, p, msg, \"info\") end\n\t\t\tend\n\t\tend\n\tend\n\tif judged == \"Versus\" and result ~= \"Tie\" then -- co-op / a side",
     "\t\t\t\tlocal _ = msg\n\t\t\tend\n\t\tend\n\tend\n\tif judged == \"Versus\" and result ~= \"Tie\" then -- co-op / a side"),
    ("honor: every round", G, "\tif now - at < (tonumber(EGG.HonorEvery) or 3600) then return end\n", ""),
    ("honor: +1", C, "HonorPoints = 5, HonorEvery = 3600,", "HonorPoints = 1, HonorEvery = 3600,"),
    ("honor: never saved", G, "\tcall(\"PlayerService\", \"SetStat\", p, \"EggHonorAt\", now)\n", ""),
    ("hit: the goose counts in Eggs mode", G, "if not active or eggsOn() then return 0 end -- A23-131", "if not active then return 0 end -- A23-131"),
    ("counts: eggs instead of points", G, "\t\t\t\trewarded[p] = pts\n", "\t\t\t\trewarded[p] = delivered\n"),
    ("overtime: not published", G, "\t\tsetGame(\"GooseOvertimeUntil\", GooseEggs.OvertimeUntil())\n", ""),
    ("faction change: eggs kept", G, "if counts[player] ~= nil or hitTimes[player] ~= nil or (active and eggsOn()) then",
     "if counts[player] ~= nil or hitTimes[player] ~= nil then"),
    ("leave: eggs kept", G, "\t\tif eggsOn() then pcall(GooseEggs.Leave, player) end -- A23-131: carried eggs fly back\n", ""),
    ("mode: Tug ignored", G, "\treturn Config.Goose.Mode == \"Eggs\" and GooseEggs ~= nil", "\treturn GooseEggs ~= nil"),
]


def literal(value: str) -> str:
    eq = "===="
    while "]" + eq + "]" in value:
        eq += "="
    return "[" + eq + "[" + value + "]" + eq + "]"


def make_harness(sources: dict[str, str]) -> str:
    head = "\n".join(f"local {key} = {literal(value)}" for key, value in sources.items())
    return head + "\n" + FIXTURE.read_text(encoding="utf-8")


def run_harness(binary: Path, harness_text: str, directory: Path, name: str) -> dict:
    path = directory / name
    path.write_text(harness_text, encoding="utf-8")
    proc = subprocess.run([str(binary), str(path)], cwd=ROOT, capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=900)
    result = None
    for line in proc.stdout.splitlines():
        if line.startswith("GOLDEN_EGG_RESULT_JSON "):
            result = json.loads(line[len("GOLDEN_EGG_RESULT_JSON "):])
    return {"returncode": proc.returncode, "stdout": proc.stdout, "stderr": proc.stderr, "result": result}


def failing_keys(result: dict | None) -> set[str]:
    if not result:
        return set()
    return {f"{n['Group']} :: {n['Name']}" for n in result.get("Named", []) if n.get("Fail", 0) > 0}


def strip_comments(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def static_checks() -> tuple[int, list[str]]:
    """Wiring the offline run cannot reach (read from the sources)."""
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    src = {k: p.read_text(encoding="utf-8-sig") for k, p in STATIC.items()}
    main = (SSS / "Main.server.luau").read_text(encoding="utf-8-sig")
    check("GooseEggs" not in main, "GooseEggs is not in the Main lists (GooseService requires it)")
    return count, failures


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
    raw = {key: path.read_bytes() for key, path in FILES.items()}
    sources = {key: value.decode("utf-8-sig").replace("\r\n", "\n") for key, value in raw.items()}
    fixture_raw = FIXTURE.read_bytes()
    compiled = subprocess.run([str(compiler), *(str(p) for p in FILES.values()), *(str(p) for p in STATIC.values()), str(FIXTURE)],
                              cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
                              encoding="utf-8", errors="replace", timeout=120)
    static_count, static_failures = static_checks()

    with tempfile.TemporaryDirectory(prefix="golden_egg_offline_") as tmp:
        tmpdir = Path(tmp)
        main_run = run_harness(binary, make_harness(sources), tmpdir, "golden_egg_main.luau")
        result = main_run["result"]
        baseline = failing_keys(result)
        mutations = []
        if not args.no_mutations:
            jobs = []
            for name, key, old, new in MUTATIONS:
                hits = sources[key].count(old)
                if hits != 1:
                    mutations.append({"mutation": name, "file": FILES[key].relative_to(ROOT).as_posix(), "applied": False,
                                      "caught": False, "note": f"pattern matched {hits} times; update MUTATIONS"})
                    continue
                mutated = dict(sources)
                mutated[key] = sources[key].replace(old, new, 1)
                jobs.append((name, key, make_harness(mutated)))

            def work(index_job):
                index, (name, key, text) = index_job
                out = run_harness(binary, text, tmpdir, f"golden_egg_mutant_{index:02d}.luau")
                new_fail = sorted(failing_keys(out["result"]) - baseline)
                crashed = out["result"] is None
                return {"mutation": name, "file": FILES[key].relative_to(ROOT).as_posix(), "applied": True,
                        "caught": crashed or bool(new_fail), "crashed": crashed,
                        "newFailingChecks": new_fail[:6], "newFailingCount": len(new_fail)}

            with ThreadPoolExecutor(max_workers=6) as pool:
                mutations.extend(pool.map(work, enumerate(jobs)))

    changed = [p.relative_to(ROOT).as_posix() for key, p in FILES.items() if p.read_bytes() != raw[key]]
    if FIXTURE.read_bytes() != fixture_raw:
        changed.append(FIXTURE.relative_to(ROOT).as_posix())
    marker = re.search(r"GOLDEN_EGG_OFFLINE_OK checks=(\d+) Studio/API calls=0", main_run["stdout"])
    named = result.get("Named", []) if result else []
    failing = [n for n in named if n.get("Fail", 0) > 0]
    caught = sum(1 for m in mutations if m.get("caught"))
    applied = sum(1 for m in mutations if m.get("applied"))
    ok = (compiled.returncode == 0 and main_run["returncode"] == 0 and marker is not None and not static_failures
          and not changed and all(m.get("applied") and m.get("caught") for m in mutations))
    report = {
        "status": ("passed-no-mutations" if args.no_mutations else "passed") if ok else "failed",
        "mutationsSkipped": args.no_mutations,
        "checks": result.get("Checks", 0) if result else 0,
        "failedChecks": result.get("Failed", 0) if result else 0,
        "namedChecks": len(named),
        "namedChecksFailing": len(failing),
        "failing": [{"group": n["Group"], "check": n["Name"], "failures": n["Fail"], "passes": n["Pass"],
                     "firstFailure": n.get("FirstFailure")} for n in failing],
        "named": [{"group": n["Group"], "check": n["Name"], "pass": n["Pass"], "fail": n["Fail"]} for n in named],
        "staticChecks": static_count,
        "staticFailures": static_failures,
        "mutations": {"total": len(MUTATIONS), "applied": applied, "caught": caught, "results": mutations},
        "compileOk": compiled.returncode == 0,
        "compileErrors": compiled.stderr.strip(),
        "runtimeError": None if result else (main_run["stderr"].strip() or main_run["stdout"].strip())[-2000:],
        "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(raw[key]).hexdigest() for key, p in FILES.items()},
        "fixtureSHA256": hashlib.sha256(fixture_raw).hexdigest(),
        "sourcesChangedDuringRun": changed,
        "studioCalls": 0, "apiCalls": 0,
        "contract": "docs/design/golden_egg_contract_2026-10-11.md + golden_egg_2026-10-11.md, SPEC A23-131 / A23-134 / A23-137: "
                    "walk-up picks (4.5 + 0.5 flat, 6 + 0.5 high, moved 1 stud in 0.5 s, nearest first, tie = fewer deliveries, "
                    "dropper waits 1.5 s, IsPlausible), 3 slots (big / crown need empty hands), plaza speed 20 x 0.9 / 0.8 / 0.7, "
                    "delivery in the own home ring x H (sqrt of average ring presence, cap 2) rounded, returns (ring 54, idle 10 s, "
                    "death, leave, faction, pads / Travel, kaiju / sack, unpicked 15 s, end), deliver -> return -> pick -> end, "
                    "crown overtime <= 8 s, laying stops at 55 s, drop-spot rules, chase, egg tag, Neutral to the bag + top x1.5, "
                    "feathers, the 4-hour KST schedule, war +30, Honor +5 once an hour, 'Bring 2 eggs' notify, Tug mode kept.",
        "limitations": "Offline doubles: GooseEggs.World (positions, ground, water, props, parts), a seeded random, the registry "
                       "(PlayerService / FactionService / ProgressionService / WarService), no 3D goose model, no characters. "
                       "Client drawing (EggFx) is not run here (tools/test_egg_fx.py). Studio play, multiple clients, real ping "
                       "and the real map's ground / props are not certified.",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if compiled.returncode:
        print(compiled.stderr, end="")
    for line in main_run["stdout"].splitlines():
        if line.startswith("CHECK_FAIL") or line.startswith("GOLDEN_EGG_OFFLINE"):
            print(line)
    if not result:
        print(main_run["stderr"][-3000:], end="")
    for message in static_failures:
        print(f"STATIC_FAILURE {message}")
    print(f"STATIC checks={static_count} failed={len(static_failures)}")
    for m in mutations:
        print(f"MUTATION {'caught ' if m.get('caught') else 'MISSED'} {m['mutation']}"
              + ("" if m.get("applied") else f" ({m.get('note')})"))
    if mutations:
        print(f"MUTATIONS caught={caught}/{applied} (of {len(MUTATIONS)})")
    else:
        print("MUTATIONS SKIPPED")
    print(f"Named checks: {len(named) - len(failing)} passed, {len(failing)} failing; "
          f"assertions {(result or {}).get('Checks', 0) - (result or {}).get('Failed', 0)}/{(result or {}).get('Checks', 0)}")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
