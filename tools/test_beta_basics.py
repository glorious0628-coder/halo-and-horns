"""BB4 combat power ("전투력") and BB16 titles ("베타 개척자" / "회색 전설" / TitleSel), run offline.

Runs the CURRENT Config, Util, DataService, JusticeService and TitleService sources (plus PlayerService.SetStat and the
PvPService combatPower / BoldMult / bully weak-victim helpers, extracted) injected into
tools/fixtures/beta_basics_offline.luau with the installed official Luau CLI (build/luau_cli_0_741). No Studio, network,
DataStore or Roblox API calls. Every check is named and collected. A mutation step then breaks in-memory copies of the
sources (never src/), runs them from a temporary directory and counts how many mutations the checks catch.

Spec: docs/design/beta_basics_2026-10-05.md "### BB4." and "### BB16.".
Usage: py tools/test_beta_basics.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_beta_basics_2026-10-06.json
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
FIXTURE = ROOT / "tools/fixtures/beta_basics_offline.luau"
OUT = ROOT / "docs/art/verification_2026-10-06/offline_beta_basics_2026-10-06.json"
FILES = {
    "CONFIG_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
    "UTIL_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Util.luau",
    "DATA_SOURCE": ROOT / "src/ServerScriptService/DataService.luau",
    "JUSTICE_SOURCE": ROOT / "src/ServerScriptService/JusticeService.luau",
    "TITLE_SOURCE": ROOT / "src/ServerScriptService/TitleService.luau",
    # only PlayerService.SetStat / AddStat and the PvPService power helpers are extracted (make_harness); the whole files
    # are hashed and mutated
    "PLAYER_SOURCE": ROOT / "src/ServerScriptService/PlayerService.luau",
    "PVP_SOURCE": ROOT / "src/ServerScriptService/PvPService.luau",
}
EXTRACTED_ONLY = ("PLAYER_SOURCE", "PVP_SOURCE")
STATIC_ONLY = {
    "NET": ROOT / "src/ReplicatedStorage/Shared/Net.luau",
    "MAIN": ROOT / "src/ServerScriptService/Main.server.luau",
    "VISUALS": ROOT / "src/ServerScriptService/CharacterVisuals.luau",
    "HUD": ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau",
}
MARK = "BETA_BASICS"

DISPLAY_SESSION = '\tif type(sessionTitle) == "string" and sessionTitle ~= "" then return sessionTitle end\n'
DISPLAY_SELECTED = ('\tlocal def = type(selected) == "string" and selected ~= "" and Config.TitleDefs[selected] or nil\n'
                    '\tif def then return def.Name end\n')

# (name, source key, exact text, replacement): each must match exactly once in the current (LF-normalized) source
MUTATIONS = [
    # Config: BB4 power number
    ("CombatPower drops DisplayScale", "CONFIG_SOURCE",
     "return math.max(0, math.floor(raw * Config.Power.DisplayScale + 0.5))",
     "return math.max(0, math.floor(raw + 0.5))"),
    ("MaxCombatPower uses MaxWeaponTier only", "CONFIG_SOURCE",
     "best = math.max(best, Config.CombatPower(Config.Levels.MaxLevel, t, Config.Loot.MaxEnhance, even, top))",
     "best = Config.CombatPower(Config.Levels.MaxLevel, Config.MaxWeaponTier, Config.Loot.MaxEnhance, even, top)"),
    ("MaxCombatPower not cached", "CONFIG_SOURCE",
     "if not Config.Power[key] then", "if true then"),
    ("TitleSel not mirrored", "CONFIG_SOURCE",
     '"LuckEvents", "TitleSel",', '"LuckEvents",'),
    ("DisplayTitle puts selected above session", "CONFIG_SOURCE",
     DISPLAY_SESSION + DISPLAY_SELECTED, DISPLAY_SELECTED + DISPLAY_SESSION),
    # Config: PvPNote is a finished line. The wrapper returns its first argument, so PvPNote becomes the bare
    # "...at most x%s and at least x%s" template again (the numbers are dropped), whatever the wording is.
    ("PvPNote back to a \"%s\" template", "CONFIG_SOURCE",
     "Config.Power.Text.PvPNote = string.format(",
     "Config.Power.Text.PvPNote = (function(template) return template end)("),
    ("PvPNote numbers typed in, not from Config.PvP", "CONFIG_SOURCE",
     "\ttostring(Config.PvP.PowerRatioMax), tostring(Config.PvP.PowerRatioMin))\nConfig.Power.Text.PvPNoteEn",
     '\t"1.5", "0.8")\nConfig.Power.Text.PvPNoteEn'),
    # review 2026-10-06 (B6): the full-sentence checks. Each swap below keeps both numbers (and the most/least
    # words) inside the line, so only the exact finished-sentence comparison can catch it.
    ("PvPNoteEn fills min into 'at most' and max into 'at least'", "CONFIG_SOURCE",
     'PvPNoteEn = string.format("However strong the weapons, PvP damage is at most x%s and at least x%s",\n'
     '\ttostring(Config.PvP.PowerRatioMax), tostring(Config.PvP.PowerRatioMin))',
     'PvPNoteEn = string.format("However strong the weapons, PvP damage is at most x%s and at least x%s",\n'
     '\ttostring(Config.PvP.PowerRatioMin), tostring(Config.PvP.PowerRatioMax))'),
    ("PvPNoteEn wording swapped to 'at least ... and at most'", "CONFIG_SOURCE",
     'PvPNoteEn = string.format("However strong the weapons, PvP damage is at most x%s and at least x%s"',
     'PvPNoteEn = string.format("However strong the weapons, PvP damage is at least x%s and at most x%s"'),
    ("PvPNote reads 'at least' first, 'at most' second (numbers follow the words)", "CONFIG_SOURCE",
     'PvPNote = string.format("However strong the weapons, PvP damage is at most x%s and at least x%s",\n'
     '\ttostring(Config.PvP.PowerRatioMax), tostring(Config.PvP.PowerRatioMin))',
     'PvPNote = string.format("However strong the weapons, PvP damage is at least x%s and at most x%s",\n'
     '\ttostring(Config.PvP.PowerRatioMin), tostring(Config.PvP.PowerRatioMax))'),
    # JusticeService: GetCombatPower + the CombatPower attribute
    ("GetCombatPower includes the rebirth bonus", "JUSTICE_SOURCE",
     "\treturn Config.CombatPowerOf(player)\nend",
     "\tlocal level, tier, enhance = levelAndTier(player)\n"
     "\treturn math.floor(Config.PowerOf(level, tier, 1 + (tonumber(player:GetAttribute(\"RebirthBonus\")) or 0), enhance)"
     " * Config.Power.DisplayScale + 0.5)\nend"),
    ("CombatPower refresh not deferred", "JUSTICE_SOURCE",
     "task.defer(POWER.Refresh, player)", "POWER.Refresh(player)"),
    ("watchers not dropped on PlayerLeaving", "JUSTICE_SOURCE",
     "\tleaving[player] = true\n\tPOWER.Drop(player)\n", "\tleaving[player] = true\n"),
    ("CombatPower not set on PlayerReady", "JUSTICE_SOURCE",
     "POWER.Conns[player] = list\n\tPOWER.Refresh(player)", "POWER.Conns[player] = list"),
    ("WeaponEnhance not watched", "JUSTICE_SOURCE",
     '{ "Level", "WeaponTier", "WeaponEnhance", "StatAtk", "StatHp", "GearAtk", "GearHp", "WeaponOpt" }',
     '{ "Level", "WeaponTier", "StatAtk", "StatHp", "GearAtk", "GearHp", "WeaponOpt" }'),
    # PvPService helpers
    # A23-69: the fallback is the one power formula (Config.CombatPowerOf, the attributes)
    ("PvP fallback is not the displayed number", "PVP_SOURCE",
     "\treturn Config.CombatPowerOf(p)\nend", "\treturn Config.CombatPowerOf(p) + 1\nend"),
    ("BoldMult x2 needs more than 120%", "PVP_SOURCE",
     "if ratio >= P.BoldStrongRatio then", "if ratio > P.BoldStrongRatio then"),
    ("BoldMult x0.5 at exactly 80%", "PVP_SOURCE",
     "if ratio < P.BoldWeakRatio then", "if ratio <= P.BoldWeakRatio then"),
    ("bully weak test at exactly 50%", "PVP_SOURCE",
     "local weak = combatPower(victim) < B.WeakPowerRatio * combatPower(killer)",
     "local weak = combatPower(victim) <= B.WeakPowerRatio * combatPower(killer)"),
    # TitleService
    ("pioneer granted at exactly PioneerUntil", "TITLE_SOURCE",
     "os.time() < beta.PioneerUntil", "os.time() <= beta.PioneerUntil"),
    ("GrantPioneer flag ignored", "TITLE_SOURCE",
     "(beta.GrantPioneer == true and os.time()", "(os.time()"),
    ("legacy BetaPioneer boolean ignored", "TITLE_SOURCE",
     "local pioneer = data.BetaPioneer == true\n\t\tor (", "local pioneer = false\n\t\tor ("),
    # gameplay plan 2-A ⑦: the live switch PioneerTitle
    ("switch PioneerTitle ignored", "TITLE_SOURCE",
     "os.time() < beta.PioneerUntil and pioneerSwitchOn())", "os.time() < beta.PioneerUntil)"),
    ("a failing switchboard ends the grants", "TITLE_SOURCE",
     "return not ok or on ~= false", "return ok and on ~= false"),
    # review 10/14: the switch turning on after the first read grants the children already in game
    ("the switch turning on grants nobody", "TITLE_SOURCE",
     "\t\t\tif key ~= \"PioneerTitle\" or value ~= true then return end\n", "\t\t\tdo return end\n"),
    ("the switch grant ignores the date", "TITLE_SOURCE",
     "\tlocal pioneer = data.BetaPioneer == true\n\t\tor (beta.GrantPioneer == true and os.time() < beta.PioneerUntil",
     "\tlocal pioneer = data.BetaPioneer == true\n\t\tor (beta.GrantPioneer == true"),
    ("first grant auto-selects the pioneer title again", "TITLE_SOURCE",
     'if pioneer then TitleService.Grant(player, "BetaPioneer") end',
     'if pioneer and TitleService.Grant(player, "BetaPioneer") and data.TitleSel == "" then S.PlayerService.SetStat(player, "TitleSel", "BetaPioneer") end'),
    ("old auto-select never migrated back", "TITLE_SOURCE",
     'if data.TitleSel == "BetaPioneer" and data.TitleSelAt == nil then',
     'if false then'),
    ("migration also resets explicit picks", "TITLE_SOURCE",
     'if data.TitleSel == "BetaPioneer" and data.TitleSelAt == nil then',
     'if data.TitleSel == "BetaPioneer" then'),
    ("SetTitle does not record the explicit pick", "TITLE_SOURCE",
     'if type(data) == "table" then data.TitleSelAt = os.time() end',
     ''),
    ("SetTitle accepts known but unowned ids", "TITLE_SOURCE",
     'if id ~= "" and not (Config.TitleDefs[id] and TitleService.Owns(player, id)) then return end',
     'if id ~= "" and not Config.TitleDefs[id] then return end'),
    ("SetTitle ignores the argument count", "TITLE_SOURCE",
     'if select("#", ...) ~= 1 then return end', ""),
    ("SetTitle length limit off by one", "TITLE_SOURCE",
     "#id > 32 then return end", "#id > 33 then return end"),
    ("SetTitle ignores RateLimits.SetTitle", "TITLE_SOURCE",
     ' or not Util.RateLimit(player, "SetTitle", Config.RateLimits.SetTitle)', ""),
    ("unowned TitleSel kept at ready", "TITLE_SOURCE",
     'if data.TitleSel ~= "" and not (Config.TitleDefs[data.TitleSel] and titles(data)[data.TitleSel]) then',
     'if data.TitleSel ~= "" and not Config.TitleDefs[data.TitleSel] then'),
    ("GrayLegend not re-checked when FallMarks changes", "TITLE_SOURCE",
     '\t\tplayer:GetAttributeChangedSignal("FallMarks"):Connect(function() pcall(checkGrayLegend, player) end),\n', ""),
    ("TitlesOwned not filtered / ordered by TitleOrder", "TITLE_SOURCE",
     "for _, id in Config.TitleOrder do\n\t\tif titles(data)[id] then table.insert(owned, id) end\n\tend",
     "for id in titles(data) do\n\t\ttable.insert(owned, id)\n\tend"),
]


def literal(value: str) -> str:
    eq = "===="
    while "]" + eq + "]" in value:
        eq += "="
    return "[" + eq + "[" + value + "]" + eq + "]"


def between(text: str, start: str, end: str) -> str:
    first = text.find(start)
    last = text.find(end, first + len(start)) if first >= 0 else -1
    if first < 0 or last < 0:
        raise ValueError(f"Source boundary changed: {start!r} / {end!r}; update the test extractor.")
    return text[first:last]


def function_block(text: str, start: str) -> str:
    """`start` up to and including the first top-level `end` line after it (a whole function)."""
    first = text.find(start)
    last = text.find("\nend\n", first) if first >= 0 else -1
    if first < 0 or last < 0:
        raise ValueError(f"Source boundary changed: {start!r}; update the test extractor.")
    return text[first:last + 5]


def make_harness(sources: dict[str, str]) -> str:
    bindings = {key: value for key, value in sources.items() if key not in EXTRACTED_ONLY}
    set_stat = between(sources["PLAYER_SOURCE"], "function PlayerService.SetStat(", "function PlayerService.Respawn(")
    bindings["SET_STAT_SOURCE"] = "local PlayerService = {}\nlocal S, mirrored = ...\n" + set_stat + "\nreturn PlayerService"
    pvp = sources["PVP_SOURCE"]
    pvp_num = function_block(pvp, "local function num(p, key, default)")
    pvp_power = function_block(pvp, "local function combatPower(p)")
    pvp_bold = function_block(pvp, "function PvPService.BoldMult(killer, victim)")
    weak = re.search(r"\n(\tlocal weak = combatPower\(victim\)[^\n]*)\n", pvp)
    if not weak:
        raise ValueError("Source boundary changed: the PvPService bully weak-victim line; update the test extractor.")
    bindings["PVP_POWER_SOURCE"] = (
        "local Config = ...\nlocal S = nil\nlocal PvPService = {}\n" + pvp_num + "\n" + pvp_power + "\n" + pvp_bold
        + "\nfunction PvPService.Weak(killer, victim)\n\tlocal B = Config.Bully\n" + weak.group(1) + "\n\treturn weak\nend\n"
        + "return {\n"
        + "\tcombatPower = function(p, registry) S = registry; return combatPower(p) end,\n"
        + "\tBoldMult = function(k, v, registry) S = registry; return PvPService.BoldMult(k, v) end,\n"
        + "\tWeak = function(k, v, registry) S = registry; return PvPService.Weak(k, v) end,\n}\n")
    head = "\n".join(f"local {key} = {literal(value)}" for key, value in bindings.items())
    return head + "\n" + FIXTURE.read_text(encoding="utf-8").replace("\r\n", "\n")


def run_harness(binary: Path, harness_text: str, directory: Path, name: str) -> dict:
    path = directory / name
    path.write_text(harness_text, encoding="utf-8")
    proc = subprocess.run([str(binary), str(path)], cwd=ROOT, capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=600)
    result = None
    for line in proc.stdout.splitlines():
        if line.startswith(MARK + "_RESULT_JSON "):
            result = json.loads(line[len(MARK + "_RESULT_JSON "):])
    return {"returncode": proc.returncode, "stdout": proc.stdout, "stderr": proc.stderr, "result": result}


def failing_keys(result: dict | None) -> set[str]:
    if not result:
        return set()
    return {f"{n['Group']} :: {n['Name']}" for n in result.get("Named", []) if n.get("Fail", 0) > 0}


def strip_comments(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def static_checks() -> tuple[int, list[str]]:
    """Wiring the offline services cannot reach (client display, entry lists); the server rules are run above."""
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    def read(path: Path) -> str:
        return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")

    net = read(STATIC_ONLY["NET"])
    check(re.search(r'^\s*"SetTitle",', net, re.M) is not None, 'Net remote list has "SetTitle"')
    main = read(STATIC_ONLY["MAIN"])
    init = re.search(r"local INIT_ORDER = \{(.*?)\}", main, re.S)
    start = re.search(r"local START_ORDER = \{(.*?)\}", main, re.S)
    check(init is not None and '"TitleService"' in init.group(1) and start is not None and '"TitleService"' in start.group(1),
          "Main.server.luau lists TitleService in INIT_ORDER and START_ORDER")
    if init and start:
        s = start.group(1)
        check(s.find('"JusticeService"') < s.find('"LootService"') < s.find('"TitleService"'),
              "START_ORDER keeps JusticeService before LootService before TitleService (the fixture's PlayerReady order)")
    visuals = read(STATIC_ONLY["VISUALS"])
    check(re.search(r'TitleSel\s*=\s*\{\s*"Nametag"\s*\}', visuals) is not None,
          "CharacterVisuals REBUILD map: TitleSel -> Nametag")
    call = re.search(r"Config\.DisplayTitle\((.*?)\n\t\)", visuals, re.S)
    check(call is not None and 'attrStr(player, "TitleSel"' in call.group(1),
          "CharacterVisuals nametag passes the TitleSel attribute to Config.DisplayTitle")
    # review of 381f6a1: the pioneer is a mark on the nametag's second line (unless it is the selected line-1 title)
    check(re.search(r'TitlesOwned\s*=\s*\{\s*"Nametag"\s*\}', visuals) is not None,
          "CharacterVisuals REBUILD map: TitlesOwned -> Nametag (the pioneer mark follows a new grant)")
    mark = re.search(r'\n(\t+)local pioneer = Config\.TitleDefs and Config\.TitleDefs\.BetaPioneer\n(.*?)\n\1end\n',
                     visuals, re.S)
    body = mark.group(2) if mark else ""
    check(mark is not None and 'attrStr(player, "TitleSel", "") ~= "BetaPioneer"' in body
          and 'attrStr(player, "TitlesOwned", "")' in body and '"BetaPioneer"' in body
          and re.search(r"line2\s*\.\.=\s*[^\n]*pioneer\.Name", body) is not None,
          "CharacterVisuals nametag line 2 adds the BetaPioneer mark when owned (TitlesOwned) and not selected")
    hud = read(STATIC_ONLY["HUD"])
    # A23-40 layout B has no title line on the HUD (the nametag above and 내 캐릭터 carry it); a title the HUD draws
    # again must still come from the TitleSel attribute
    at = hud.find("Config.DisplayTitle(")
    check(at < 0 or 'attr("TitleSel"' in hud[at:at + 300],
          "HUD title (if the HUD draws one) passes the TitleSel attribute to Config.DisplayTitle")
    check(re.search(r'UIKit\.OnAttr\(\{[^}]*"TitleSel"', hud) is not None, "HUD redraws the title when TitleSel changes")
    check('attr("CombatPower"' in hud and "Config.CombatPower(" in hud,
          "HUD reads the CombatPower attribute and falls back to Config.CombatPower before the first set")
    writers, grants = [], []
    for path in sorted((ROOT / "src").rglob("*.luau")):
        rel = path.relative_to(ROOT).as_posix()
        code = strip_comments(read(path))
        if re.search(r'SetAttribute\(\s*"CombatPower"', code) and rel != "src/ServerScriptService/JusticeService.luau":
            writers.append(rel)
        if re.search(r'SetStat\([^)]*"TitleSel"|\.TitleSel\s*=[^=]|\.Titles\s*\[[^\]]*\]\s*=[^=]', code) \
                and rel != "src/ServerScriptService/TitleService.luau":
            grants.append(rel)
    check(not writers, f"only JusticeService writes the CombatPower attribute; others: {writers}")
    check(not grants, f"only TitleService writes TitleSel / Titles; others: {grants}")
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

    compiled = subprocess.run([str(compiler), *(str(p) for p in FILES.values()), str(FIXTURE)], cwd=ROOT,
                              stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
                              encoding="utf-8", errors="replace", timeout=120)
    static_count, static_failures = static_checks()

    with tempfile.TemporaryDirectory(prefix="beta_basics_offline_") as tmp:
        tmpdir = Path(tmp)
        main_run = run_harness(binary, make_harness(sources), tmpdir, "beta_basics_main.luau")
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
                try:
                    text = make_harness(mutated)
                except ValueError as error:  # the mutation broke an extractor boundary: counts as caught
                    mutations.append({"mutation": name, "file": FILES[key].relative_to(ROOT).as_posix(), "applied": True,
                                      "caught": True, "crashed": True, "note": str(error),
                                      "newFailingChecks": [], "newFailingCount": 0})
                    continue
                jobs.append((name, key, text))

            def work(index_job):
                index, (name, key, text) = index_job
                out = run_harness(binary, text, tmpdir, f"beta_basics_mutant_{index:02d}.luau")
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
    marker = re.search(MARK + r"_OFFLINE_OK checks=(\d+) Studio/API calls=0", main_run["stdout"])
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
        "findings": result.get("Findings", []) if result else [],
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
        "contract": "BB4 (docs/design/beta_basics_2026-10-05.md): Config.CombatPower(level, tier, +N) = floor(PowerOf(level, "
                    "tier, 1, +N) x DisplayScale 10 + 0.5) for a weapon (A23-34: bare hands count from 0: Lv1 0, Lv2 12) with samples 283 (Lv1 T1) / 387 (Lv1 T2) / 758 (Lv5 T3) / 1,052 "
                    "(Lv10 T3 +3) / 2,829 (Lv20 T5), Lv1 T8 872 < Lv1 T4 938, MaxCombatPower() = 37,805 (C1: Lv100, highest-damage "
                    "weapon = the Mythic tier 9, +10; tier 7 alone 25,488; cached; a tier-8 cap would be 7,027); rises with level and +N, ordered by weapon Damage; "
                    "Config.Power.Text (Label/Up/Change/Formula + En; PvPNote / PvPNoteEn are finished lines built right "
                    "after Config.PvP: strings with no '%', following PowerRatioMax / PowerRatioMin and equal to exactly "
                    "(A23-48: both) 'However strong the weapons, PvP "
                    "damage is at most x<Max> and at least x<Min>' (full-sentence compare: max first, min second) and "
                    "Config.Bully.Text (Title + 3 lines KO/EN "
                    "built from WeakPowerRatio 50% / FreshSpawnSeconds 15 / RepeatKOs 3 in RepeatWindow 10 min); "
                    "JusticeService.GetCombatPower = Config.CombatPowerOf(player) (A23-69: Config.CombatPower from the "
                    "Level / WeaponTier / WeaponEnhance attributes + StatAtk / StatHp, which count only with the StatPoints "
                    "switch on; no rebirth bonus), GetPower unchanged; the CombatPower attribute is set on PlayerReady, follows "
                    "Level / WeaponTier / WeaponEnhance (+ StatAtk / StatHp) with ONE task.defer-coalesced refresh per frame "
                    "(an equip = one change) and is disconnected on PlayerLeaving; PvPService combatPower fallback = "
                    "Config.CombatPowerOf (the attributes), BoldMult x2 "
                    "at ratio >= 1.2, x0.5 below 0.8, bully weak test victim < 50% of killer, all on the displayed integer. "
                    "BB16: Data Titles {} / TitleSel \"\" (TitleSel mirrored), Config.TitleDefs / TitleOrder / Beta "
                    "(GrantPioneer, PioneerUntil 2026-12-19 11:00 KST); BetaPioneer granted on PlayerReady before "
                    "PioneerUntil (legacy data.BetaPioneer always); no automatic selection: a grant never sets TitleSel "
                    "(it stays \"\", the faction rank stays the title, no TitleSel SetStat; only the player's SetTitle "
                    "picks); legacy rows from the first build (TitleSel \"BetaPioneer\" without TitleSelAt) go back to "
                    "\"\" once at ready (SetTitle records TitleSelAt, so an explicit pick is kept); the pioneer shows as a mark on the nametag's second line (CharacterVisuals, static "
                    "check); a \"\" choice survives rejoin, GrantPioneer=false stops new grants; "
                    "GrayLegend when FallMarks and RedeemMarks >= Rebirth.GrayLegendMin (at ready and on change); "
                    "TitlesOwned = owned TitleOrder ids joined by \",\"; unowned/unknown TitleSel -> \"\" at ready; SetTitle "
                    "remote: exactly one string <= 32 chars, \"\" or owned, ready, RateLimits.SetTitle 0.5 s, else ignored; "
                    "titles never change stats; DisplayTitle order session > selected > gray legend > rank.",
        "limitations": "Offline doubles: DataStore = in-memory rows (deep copies), PlayerService ready/leave flow and signals "
                       "modelled on the real one (real SetStat / AddStat), LootService reduced to its WeaponEnhance attribute "
                       "writes, attribute-changed signals fire immediately and only on a real change, task.defer flushed by the "
                       "fixture, os.time / os.clock doubles. PvPService is tested through extracted helpers (num, combatPower, "
                       "BoldMult, the bully weak line), not the whole KO flow. Client HUD / CharacterVisuals / BB8 picker are "
                       "only checked statically. Studio play, replication and multiple clients are not certified here.",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if compiled.returncode:
        print(compiled.stderr, end="")
    for line in main_run["stdout"].splitlines():
        if line.startswith("CHECK_FAIL") or line.startswith(MARK + "_OFFLINE"):
            print(line)
    if not result:
        print(main_run["stderr"], end="")
    for message in static_failures:
        print(f"STATIC_FAILURE {message}")
    print(f"STATIC checks={static_count} failed={len(static_failures)}")
    for m in mutations:
        print(f"MUTATION {'caught ' if m.get('caught') else 'MISSED'} {m['mutation']}"
              + ("" if m.get("applied") else f" ({m.get('note')})"))
    if mutations:
        print(f"MUTATIONS caught={caught}/{applied} (of {len(MUTATIONS)})")
    if args.no_mutations:
        print("MUTATIONS SKIPPED")
    for f in report["findings"]:
        print(f"FINDING [{f.get('Group')}] {f.get('Text')}")
    print(f"Named checks: {len(named) - len(failing)} passed, {len(failing)} failing; "
          f"assertions {report['checks'] - report['failedChecks']}/{report['checks']}")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if ok else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"Beta basics offline check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
