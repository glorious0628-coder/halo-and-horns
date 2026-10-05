"""BB1 key map (Keybinds) and BB2 saved settings (SettingsService / Settings), run offline.

Runs the CURRENT Config, Util, Net, DataService, SettingsService, Keybinds and Settings sources (injected into
tools/fixtures/keys_settings_offline.luau) with the installed official Luau CLI (build/luau_cli_0_741). No Studio,
network, DataStore or Roblox API calls. Every check is named and collected. A mutation step then breaks in-memory copies
of the sources (never src/), runs them from a temporary directory and counts how many mutations the checks catch.

Usage: py tools/test_keys_settings.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_keys_settings_2026-10-06.json
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
FIXTURE = ROOT / "tools/fixtures/keys_settings_offline.luau"
OUT = ROOT / "docs/art/verification_2026-10-06/offline_keys_settings_2026-10-06.json"
PLAYER_SCRIPTS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {
    "CONFIG_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
    "UTIL_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Util.luau",
    "NET_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Net.luau",
    "DATA_SOURCE": ROOT / "src/ServerScriptService/DataService.luau",
    "SERVICE_SOURCE": ROOT / "src/ServerScriptService/SettingsService.luau",
    "KEYBINDS_SOURCE": PLAYER_SCRIPTS / "Keybinds.luau",
    "SETTINGS_SOURCE": PLAYER_SCRIPTS / "Settings.luau",
}
STATIC_ONLY = {
    "CLIENT_MAIN": PLAYER_SCRIPTS / "ClientMain.client.luau",
    "SERVER_MAIN": ROOT / "src/ServerScriptService/Main.server.luau",
    "HUD": PLAYER_SCRIPTS / "HUD.luau",
    "VITALS": PLAYER_SCRIPTS / "VitalsUI.luau",
    "GHOST": PLAYER_SCRIPTS / "GrudgeGhost.luau",
    "WORLD_MAP": PLAYER_SCRIPTS / "WorldMap.luau",
    "PANELS": PLAYER_SCRIPTS / "Panels.luau",
    "STORY": ROOT / "src/ServerScriptService/StoryQuestService.luau",
}

# (name, source key, exact text, replacement): each must match exactly once in the current (LF-normalized) source
MUTATIONS = [
    ("KeyMap: an explicit key already taken is kept", "CONFIG_SOURCE",
     'if v ~= "" and not taken[v] then', 'if v ~= "" then'),
    ("KeyMap: a default-only collision is not reported", "CONFIG_SOURCE",
     "table.insert(collisions, def.Id)", "local _ = def.Id"),
    ("KeyMap: a non-live action keeps its saved key", "CONFIG_SOURCE",
     "if live(def) and explicit(def) then", "if explicit(def) then"),
    ("Flag ignored (the Z skill is always live)", "CONFIG_SOURCE",
     "\treturn node == true", "\treturn true"),
    ("Reserved letters become usable", "CONFIG_SOURCE",
     "if not KB.ReservedSet[n] then KB.AllowedSet[n] = true end", "KB.AllowedSet[n] = true"),
    ("Sfx not snapped to the 0.1 step", "CONFIG_SOURCE",
     "v = def.Min + math.floor((v - def.Min) / def.Step + 0.5) * def.Step", "v = v"),
    ("enum settings accept any string", "CONFIG_SOURCE",
     'if type(v) ~= "string" or not table.find(def.Options, v) then v = d end', 'if type(v) ~= "string" then v = d end'),
    ("saved keys keep entries equal to the default", "CONFIG_SOURCE",
     'if type(v) == "string" and (v == "" or Config.KeyUsable(v)) and v ~= a.Key then',
     'if type(v) == "string" and (v == "" or Config.KeyUsable(v)) then'),
    ("two actions may save the same key", "CONFIG_SOURCE",
     'if used[v] then v = "" else used[v] = true end', "used[v] = true"),
    ("unknown top-level settings are kept", "CONFIG_SOURCE",
     "local out = { V = ST.Version, Keys = {} }", "local out = table.clone(src); out.V = ST.Version; out.Keys = {}"),
    ("old saves are not sanitized on load", "DATA_SOURCE",
     "d.Settings = Config.SanitizeSettings(d.Settings)", "d.Settings = d.Settings"),
    ("SetSettings accepts two arguments", "SERVICE_SOURCE",
     "if n > 1 then return end", "if n > 2 then return end"),
    ("SetSettings accepts 17 top-level keys", "SERVICE_SOURCE",
     "if count > (Config.Settings.MaxBlobKeys or 16) then return end",
     "if count > (Config.Settings.MaxBlobKeys or 16) + 1 then return end"),
    ("Seq is not clamped", "SERVICE_SOURCE",
     "seq = math.clamp(math.floor(s), 0, MAX_SEQ)", "seq = s"),
    ("SetSettings works before PlayerReady", "SERVICE_SOURCE",
     "if not S.PlayerService.IsReady(player) then return end", ""),
    ("SetSettings is not rate-limited", "SERVICE_SOURCE",
     'if not Util.RateLimit(player, "SetSettings", Config.RateLimits.SetSettings or 1) then return end', ""),
    ("the echo goes to every client", "SERVICE_SOURCE",
     'Net.Get("Settings"):FireClient(player, ', 'Net.Get("Settings"):FireAllClients('),
    ("the blob is saved without SanitizeSettings", "SERVICE_SOURCE",
     "if n == 1 then data.Settings = Config.SanitizeSettings(blob) end", "if n == 1 then data.Settings = blob end"),
    ("no push on PlayerReady", "SERVICE_SOURCE",
     "local ok, err = pcall(function() send(player, 0, SettingsService.Get(player)) end)", "local ok, err = true, nil"),
    ("SetLocal does not swap (the holder keeps its key)", "KEYBINDS_SOURCE",
     "if holder and holder ~= action then sparse[holder] = old end", ""),
    ("touch-only devices see key labels", "KEYBINDS_SOURCE",
     "if touchOnly() then return en and def.ButtonEn or def.Button end", ""),
    ("every pad button is wired", "KEYBINDS_SOURCE",
     'if live[def.Id] and KB.PadWired[def.Id] and def.Pad ~= "" then', 'if live[def.Id] and def.Pad ~= "" then'),
    ("the client sends without waiting for the rate-limit slot", "SETTINGS_SOURCE",
     "local wait = ST.LastSent + interval() - os.clock()", "local wait = 0"),
    ("older echoes are applied", "SETTINGS_SOURCE",
     "if seq ~= seq or seq < ST.Seq then return end", "if seq ~= seq then return end"),
    ("an echo overwrites changes not yet sent", "SETTINGS_SOURCE",
     "for k in ST.Dirty do value[k] = Util.DeepCopy(ST.Local[k]) end", ""),
    ("a blob the server drops is never sent again", "SETTINGS_SOURCE",
     "if ST.InFlight ~= flight then return end", "do return end"),
    ("an echo does not end the in-flight wait (needless resends)", "SETTINGS_SOURCE",
     "if ST.InFlight and seq >= ST.InFlight.Seq then", "if false then"),
    ("an unanswered blob is resent forever", "SETTINGS_SOURCE",
     "if ST.Resends >= ST.MaxResends then return end", ""),
    ("SetLocal keeps a non-live action's saved entry on the new key", "KEYBINDS_SOURCE",
     'if not K.Live[id] and v ~= "" and (v == key or (holder and holder ~= action and v == old)) then sparse[id] = nil end',
     ""),
    ("SetLocal keeps a non-live action's saved entry on the swapped holder's new key", "KEYBINDS_SOURCE",
     "(v == key or (holder and holder ~= action and v == old))", "(v == key)"),
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
                          encoding="utf-8", errors="replace", timeout=600)
    result = None
    for line in proc.stdout.splitlines():
        if line.startswith("KEYS_SETTINGS_RESULT_JSON "):
            result = json.loads(line[len("KEYS_SETTINGS_RESULT_JSON "):])
    return {"returncode": proc.returncode, "stdout": proc.stdout, "stderr": proc.stderr, "result": result}


def failing_keys(result: dict | None) -> set[str]:
    if not result:
        return set()
    return {f"{n['Group']} :: {n['Name']}" for n in result.get("Named", []) if n.get("Fail", 0) > 0}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def lua_list(text: str, name: str) -> list[str]:
    match = re.search(r"local " + name + r"\s*=\s*\{(.*?)\n?\}", text, re.S)
    return re.findall(r'"([^"]+)"', match.group(1)) if match else []


def function_body(text: str, header: str) -> str:
    start = text.find(header)
    if start < 0:
        return ""
    end = text.find("\nend\n", start)
    return text[start:end if end > 0 else len(text)]


def static_checks() -> tuple[int, list[str]]:
    """Client / server wiring the offline modules cannot reach (HUD, VitalsUI, GrudgeGhost, WorldMap, load order)."""
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    # BB1 acceptance: 'Enum.KeyCode.' only in Keybinds, Intro (Return / KeypadEnter / ButtonA) and WorldMap (ButtonB / Escape)
    allowed_codes = {"Intro.luau": {"Return", "KeypadEnter", "ButtonA"}, "WorldMap.luau": {"ButtonB", "Escape"}}
    for path in sorted((ROOT / "src/StarterPlayer").rglob("*.luau")):
        codes = set(re.findall(r"Enum\.KeyCode\.(\w+)", read(path)))
        if not codes or path.name == "Keybinds.luau":
            continue
        extra = codes - allowed_codes.get(path.name, set())
        check(not extra, f"{path.relative_to(ROOT).as_posix()} has no fixed Enum.KeyCode outside BB1's list ({sorted(extra)})")

    order = lua_list(read(STATIC_ONLY["CLIENT_MAIN"]), "ORDER")
    pos = {name: i for i, name in enumerate(order)}
    check("Keybinds" in pos and "Settings" in pos and "UIKit" in pos,
          "ClientMain ORDER lists Settings and Keybinds")
    if "Keybinds" in pos and "Settings" in pos and "UIKit" in pos:
        check(pos["UIKit"] < pos["Keybinds"] and pos["Settings"] < pos["Keybinds"],
              "ClientMain: Keybinds after UIKit and Settings (Keybinds.Init reads the saved keys)")
        later = [n for n in ("Fx", "VitalsUI", "HUD", "Panels", "WorldMap", "GrudgeGhost") if n in pos]
        check(all(pos["Keybinds"] < pos[n] for n in later),
              "ClientMain: Keybinds before Fx, VitalsUI, HUD, Panels, WorldMap and GrudgeGhost")
    server = read(STATIC_ONLY["SERVER_MAIN"])
    init, start = lua_list(server, "INIT_ORDER"), lua_list(server, "START_ORDER")
    check("SettingsService" in init and "AnnounceService" in init
          and init.index("SettingsService") == init.index("AnnounceService") + 1,
          "Main INIT_ORDER: SettingsService right after AnnounceService")
    check("SettingsService" in start and start[-1:] == ["PlayerService"]
          and start.index("SettingsService") < start.index("PlayerService"),
          "Main START_ORDER: SettingsService before PlayerService, PlayerService last")

    hud = read(STATIC_ONLY["HUD"])
    began = function_body(hud, "local function onInputBegan")
    check("IsCapturing()" in began and "GetFocusedTextBox" in began and "gameProcessed" in began,
          "HUD onInputBegan: nothing while capturing, typing in a TextBox or gameProcessed")
    check("ActionFor(input)" in began and began.find("L.WindowKey(action)") >= 0
          and began.find("L.WindowKey(action)") < began.find("inputAllowed()"),
          "HUD: input through Keybinds.ActionFor; window and menu keys run before inputAllowed()")
    window = function_body(hud, "function L.WindowKey")
    check("CurrentId()" in window and "panels.Close, true" in window and "panels.Open, target" in window and "Has(target)" in window,
          "HUD L.WindowKey: same window key closes, another switches, an unregistered window does nothing")
    check("kb.Changed:Connect(L.RefreshKeys)" in hud and "KeyBadges" in hud,
          "HUD key badges follow Keybinds.Changed and Settings.KeyBadges")
    vitals = read(STATIC_ONLY["VITALS"])
    check('action == "PotionHP"' in vitals and 'action == "PotionMP"' in vitals and "ActionFor(input)" in vitals
          and "IsCapturing()" in vitals, "VitalsUI potions use Keybinds.ActionFor (and stop while capturing)")
    vkeys = function_body(vitals, "function VitalsUI.RefreshKeys")
    check("kb.Label" in vkeys and "kb.KeyName" in vkeys and '"KeyBadges"' in vkeys and "key.Visible" in vkeys
          and "Text = tostring(i)" not in vitals,
          "VitalsUI potion badges show Keybinds.Label, hide when unbound or Settings.KeyBadges is off")
    check("keys.Changed:Connect(VitalsUI.RefreshKeys)" in vitals and "st.Changed:Connect(VitalsUI.RefreshKeys)" in vitals,
          "VitalsUI potion badges redraw on Keybinds.Changed and Settings.Changed")
    ghost = read(STATIC_ONLY["GHOST"])
    check('ActionFor(input) == "GhostHold"' in ghost and "IsCapturing()" in ghost and "GetFocusedTextBox" in ghost,
          "GrudgeGhost holds with ActionFor('GhostHold') (T), not G")
    wmap = read(STATIC_ONLY["WORLD_MAP"])
    check('kb.Get("Map")' in wmap and "UnbindAction(ACTION_TOGGLE)" in wmap and "kb.Changed:Connect" in wmap
          and "{Map} / Esc" in wmap, "WorldMap binds Get('Map'), rebinds on Changed, hint '{Map} / Esc: 닫기'")
    panels = read(STATIC_ONLY["PANELS"])
    check("function Panels.CurrentId()" in panels and "Panels.IsRegistered = Panels.Has" in panels,
          "Panels.CurrentId and Panels.IsRegistered exist")
    story = read(STATIC_ONLY["STORY"])
    check("Config.FillKeys(" in story and "Config.KeyMap(" in story,
          "StoryQuestService fills {Auto} in toasts from Config.KeyMap(data.Settings.Keys)")
    row = function_body(story, "local function rowFor")
    check(row != "" and "keyText(" not in row,
          "StoryQuestService quest rows keep the raw {Auto} token (the client fills it per device)")
    parse = function_body(hud, "local function parseQuests")
    qtext = function_body(hud, "function L.QuestText")
    check("L.QuestText(" in parse and "kb.Fill" in qtext and "IS_TOUCH" in qtext,
          "HUD fills quest row key tokens (keyboard: current key, touch-only: button name)")
    check(re.search(r"kb\.Changed:Connect\(function\(\)[^\n]*\n\s*if questState\.Started then refreshQuests\(\) end", hud)
          is not None, "HUD redraws the quest rows on Keybinds.Changed")
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

    with tempfile.TemporaryDirectory(prefix="keys_settings_offline_") as tmp:
        tmpdir = Path(tmp)
        main_run = run_harness(binary, make_harness(sources), tmpdir, "keys_settings_main.luau")
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
                out = run_harness(binary, text, tmpdir, f"keys_settings_mutant_{index:02d}.luau")
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
    marker = re.search(r"KEYS_SETTINGS_OFFLINE_OK checks=(\d+) Studio/API calls=0", main_run["stdout"])
    named = result.get("Named", []) if result else []
    failing = [n for n in named if n.get("Fail", 0) > 0]
    caught = sum(1 for m in mutations if m.get("caught"))
    applied = sum(1 for m in mutations if m.get("applied"))
    ok = (compiled.returncode == 0 and main_run["returncode"] == 0 and marker is not None and not static_failures
          and not changed and all(m.get("applied") and m.get("caught") for m in mutations))
    report = {
        "status": "passed" if ok else "failed",
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
        "contract": "docs/design/beta_basics_2026-10-05.md BB1 + BB2 (A23-21: PC keyboard keys only, fixed pad layout, "
                    "button names on touch-only devices): 17 actions with the BB1 default keys / pad buttons, Reserved and "
                    "Allowed key sets, KeyMap collision rule (explicit first in Actions order, a taken explicit key -> '', "
                    "a live default-only action whose default is taken -> '' and reported once per session, non-live "
                    "actions hold no key, never wipe all keys), KeyLabel, SanitizeSettings (unknown keys dropped, sparse "
                    "Keys, Sfx clamp + 0.1 step, finite numbers, bools, enums), DataService fills Settings without a "
                    "Version bump, SettingsService (<= 1 argument, <= 16 top-level keys, Seq clamped 0..2^31, ready + 1 s "
                    "rate limit, dropped calls answered with nothing, owner-only echo, push on PlayerReady), Keybinds "
                    "(Get / ActionFor / Label / PadFor / SetLocal swap / Clear / Reset / Apply / Changed / Collisions / "
                    "Capture / Dispatch / prompts) and the Settings client (pull at Start, one pending blob at max(now, "
                    "lastSent + 1.05 s), Flush through the same slot, older echoes ignored, unsent changes kept, a blob "
                    "the server drops without an answer re-sent through the same slot, at most 5 times in a row). "
                    "Review fixes 2026-10-06: a non-live action's stale saved key never blanks a live action in SetLocal; "
                    "potion badges, quest-row key tokens and the in-flight resend are checked (static / offline).",
        "limitations": "Offline doubles: virtual clock for os.clock / task.delay, cached EnumItems, remotes with a fixed "
                       "or scripted latency, DataStore table, Panels.Has from a registered-window set, UIKit.Toast recorder. "
                       "HUD / VitalsUI / GrudgeGhost / WorldMap / Panels / StoryQuestService wiring is only checked "
                       "statically. Not certified here: real key presses in Studio, which non-letter keys Roblox swallows, "
                       "whether ProximityPrompt accepts a changed KeyboardKeyCode, real DataStore saves across rejoins, "
                       "multiple clients.",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if compiled.returncode:
        print(compiled.stderr, end="")
    for line in main_run["stdout"].splitlines():
        if line.startswith("CHECK_FAIL") or line.startswith("KEYS_SETTINGS_OFFLINE"):
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
        print(f"Keys / settings offline check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
