"""Client side of dev2's story / lines contracts, offline (town_quests_server_2026-10-07 section 8 E2 + A23-58,
lines_pack_server_2026-10-07 sections 1-2), plus the Audio loader line (6509895).

Runs the CURRENT Config.luau, Announce.luau and the STORY.Lines / STORY.Hint functions cut out of Panels.luau in
tools/fixtures/story_client_offline.luau with the installed official Luau CLI (build/luau_cli_0_741):
- a king's appear line with Args.Banter shows one more chat line in the event's colour (escaped, never a toast; legacy
  chat too); drop lines, empty / non-string Banter: nothing new;
- a story step's lines follow the server's Var (LinesBy[Var], else Default; no LinesBy: Lines; faction row over All),
  and every real LinesBy step has lines for each Var and both factions;
- a dialogue line types in (UIKit.Typewriter, 40 letters / s, the speaker's voice), a refresh never retypes it, a tap
  (the line, [Next] or an answer button) first shows the whole line; without UIKit.Typewriter it shows at once;
- the choice hint is the faction's A23-58 line (Halo: Honor +Good / -Evil, Horns: Infamy -Good / +Evil), the guild's
  no-points line, the lean line for two 0-point picks (E5), ChoiceHint for an older Config; no "%" left on real cards;
- 검수 2026-10-07: the speaker's portrait (STORY.PortraitKey): Otto, Fizzby, Bright, Smokey, Tiny, Kit and the two
  faction guides show their Config.UIArt face; shards, kids, goblins, Gleam, Rex, an empty art id or no UIKit: no slot.
Static checks: the Forge / Potion windows put Config.Text.ForgeGreeting / PotionGreeting on top, a waiting story page
keeps Var, the Story window uses STORY.Lines(step, f, arg.Var) / STORY.Hint, ClientMain ORDER ends with "Audio", the
Story line and page sit in STORY.Talk's row beside the portrait.
Mutations: in-memory copies with one rule broken each; each must fail a check that passes on the real sources. Status
"passed" only when everything passes AND every mutation was applied and caught (--no-mutations: "passed-no-mutations").

Usage: py tools/test_story_client.py [--no-mutations]
Report: docs/art/verification_2026-10-07/offline_story_client_2026-10-07.json
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
ANNOUNCE = SPS / "Announce.luau"
PANELS = SPS / "Panels.luau"
CLIENT_MAIN = SPS / "ClientMain.client.luau"
HUD = SPS / "HUD.luau"
WORLDMAP = SPS / "WorldMap.luau"
PLAYERLIST = SPS / "PlayerListUI.luau"
AUDIO = SPS / "Audio.luau"
FIXTURE = ROOT / "tools/fixtures/story_client_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-07/offline_story_client_2026-10-07.json"

BANTER_CALL = "\t\tA.Chat(escape(args.Banter), g.Color)\n"
BANTER_IF = 'if type(ev) == "table" and type(args.Banter) == "string" and args.Banter ~= "" then'
# (name, file key, old, new): each old must match exactly once
MUTATIONS = [
    ("the banter is never shown", "announce", BANTER_CALL, ""),
    ("the banter is not escaped for rich text", "announce", "A.Chat(escape(args.Banter), g.Color)", "A.Chat(args.Banter, g.Color)"),
    ("the banter in the drop colour", "announce", "A.Chat(escape(args.Banter), g.Color)",
     "A.Chat(escape(args.Banter), Config.WeaponGrades.Rare.Color)"),
    ("the banter also toasts", "announce", BANTER_CALL,
     BANTER_CALL + '\t\tpcall(C.UIKit.Toast, args.Banter, "reward", 5)\n'),
    ("drop lines show a banter too", "announce", BANTER_IF, 'if type(args.Banter) == "string" and args.Banter ~= "" then'),
    ("an empty banter is shown", "announce", BANTER_IF, 'if type(ev) == "table" and type(args.Banter) == "string" then'),
    ("Var ignored (always Default)", "panels", "(step.LinesBy[var] or step.LinesBy.Default)", "step.LinesBy.Default"),
    ("no Default fallback", "panels", "(step.LinesBy[var] or step.LinesBy.Default)", "step.LinesBy[var]"),
    ("the faction row ignored", "panels", "(src[f] or src.All)", "src.All"),
    ("the hint ignores the faction line", "panels", 'type(own) == "string" and own or TXT.ChoiceHint', "TXT.ChoiceHint"),
    # round 3 #5
    ("the hint shows the full minus at 0 points", "panels",
     "\tif f == \"Halo\" then evil = math.min(evil, have) else good = math.min(good, have) end\n", ""),
    ("no '(you have N)'", "panels", " .. string.format(STORY.Text.HintHave, have)", ""),
    ("the window passes no points", "panels", "STORY.Hint(obj, f, STORY.Points(f))", "STORY.Hint(obj, f)"),
    ("0-point picks show +0 / -0", "panels", "\tif good <= 0 and evil <= 0 then return STORY.Text.HintLean end\n", ""),
    ("the guild sees score numbers", "panels", 'if f ~= "Halo" and f ~= "Horns" then return TXT.ChoiceHintNeutral end',
     "if false then return TXT.ChoiceHintNeutral end"),
    ("a waiting page drops Var", "panels", "STORY.Pending = { Id = arg.Id, St = arg.St, Var = arg.Var }",
     "STORY.Pending = { Id = arg.Id, St = arg.St }"),
    ("the Story window ignores Var", "panels", "local lines = STORY.Lines(step, f, arg.Var)", "local lines = STORY.Lines(step, f, nil)"),
    ("no Forge greeting", "panels", "local hello = Config.Text and Config.Text.ForgeGreeting", "local hello = nil"),
    ("no Potion greeting", "panels", "local hello = Config.Text and Config.Text.PotionGreeting", "local hello = nil"),
    ("ClientMain never loads Audio", "client_main", '"SkillBar", "Audio" }', '"SkillBar" }'),
    # quality 2: UIKit.Typewriter on the dialogue lines (검수 2026-10-07: 40 letters / s, a tap shows the whole line)
    ("typing at UIKit's 38 / s", "panels", "local TYPE = { Speed = 40 }", "local TYPE = { Speed = 38 }"),
    ("every refresh retypes the line", "panels", "\tif state.Key == key and state.Label == label then return end\n", ""),
    ("a tap never finishes the line", "panels", "\t\th.Finish()\n\t\treturn true\n", "\t\treturn false\n"),
    ("Welcome [Next] skips a typing line", "panels", "if pending or TYPE.Finish(typing) then return end", "if pending then return end"),
    ("an answer while typing is sent at once", "panels",
     "\t\tif TYPE.Finish(typing) then return end -- the first tap while the line types shows it whole\n", ""),
    ("the Story line no longer types", "panels", 'TYPE.Show(typing, line, tostring(lines[page] or ""), voice, page)',
     'line.Text = tostring(lines[page] or "")'),
    # 검수 2026-10-07: the speaker's portrait in the Story window
    ("the Story window has no portrait", "panels", "local talk, align = STORY.Talk(parent, voice)",
     "local talk, align = parent, Enum.TextXAlignment.Center"),
    ("the line stays outside the portrait row", "panels", 'addText(talk, "", { Name = "StoryLine"',
     'addText(parent, "", { Name = "StoryLine"'),
    ("a speaker whose art id is empty still gets a slot", "panels",
     '\tif type(UIKit.ArtPart) == "function" and not UIKit.ArtPart(key) then return nil end\n', ""),
    ("Otto shows Fizzby's face", "config", 'Smith = "PortraitMerchantC"', 'Smith = "PortraitPotionMerchant"'),
    ("the crown shard gets the guide's face", "config", 'Shard = "PTR_CrownShard"', 'Shard = "PortraitGuideHalo"'),
    ("the goblins get a face", "config", 'Portraits = { Smith = ', 'Portraits = { Pip = "PortraitGuideHorns", Smith = '),
    ("no guide face when a step has no speaker", "config", ' Halo = "PortraitGuideHalo",\n', "\n"),
    # BB38 UiMetric (dev2 cfef90c): once per window per session, only UiIds, spaced Gap s apart
    ("a window counts twice", "panels", "or METRIC.Sent[id] or type(ids)", "or false or type(ids)"),
    ("any id is sent", "panels", 'or type(ids) ~= "table" or not table.find(ids, id) then return end', "then return end"),
    ("a burst goes out at once (the server drops the 2nd)", "panels", "Busy = false, Gap = 2.1 }", "Busy = false, Gap = 0 }"),
    ("opening a window sends nothing", "panels", "\tcurrentId = id\n\tPanels.Metric(id)\n", "\tcurrentId = id\n"),
    ("the [메뉴] fold sends nothing", "hud",
     'if type(panels) == "table" and type(panels.Metric) == "function" then pcall(panels.Metric, "Menu") end', ""),
]


def lua_long(text: str) -> str:
    eq = "===="
    while f"]{eq}]" in text:
        eq += "="
    return f"[{eq}[{text}]{eq}]"


def cut_story(panels: str) -> tuple[str, str]:
    """STORY.Lines + STORY.Hint + STORY.PortraitKey source and the HintLean literal (raises when the shape changed)."""
    parts = []
    for head in (r"function STORY\.Lines\(step, f, var\)", r"function STORY\.Hint\(obj, f, have\)",
                 r"function STORY\.PortraitKey\(voice\)"):
        m = re.search(r"\n(" + head + r"\n.*?\nend)\n", panels, re.S)
        if not m:
            raise ValueError(f"Panels.luau: {head} missing; update the extractor")
        parts.append(m.group(1))
    lean = re.search(r'\bHintLean = ("(?:[^"\\]|\\.)*")', panels)
    have = re.search(r'\bHintHave = ("(?:[^"\\]|\\.)*")', panels)
    if not lean or not have:
        raise ValueError("Panels.luau: STORY.Text.HintLean / HintHave missing")
    return "\n".join(parts) + "\n", lean.group(1) + ", " + have.group(1)


def cut_metric(panels: str) -> str:
    """the BB38 UiMetric block of Panels.luau (local METRIC ... the end of Panels.Metric)"""
    m = re.search(r"\n(local METRIC = \{.*?\nfunction Panels\.Metric\(id\)\n.*?\nend)\n", panels, re.S)
    if not m:
        raise ValueError("Panels.luau: the METRIC block is missing; update the extractor")
    return m.group(1)


def cut_type(panels: str) -> str:
    """the TYPE helper block of Panels.luau (local TYPE ... the end of TYPE.Tap)"""
    m = re.search(r"\n(local TYPE = \{.*?\nfunction TYPE\.Tap\(state, label\)\n.*?\nend)\n", panels, re.S)
    if not m:
        raise ValueError("Panels.luau: the TYPE helpers are missing; update the extractor")
    return m.group(1)


def static_checks(src: dict[str, str]) -> list[tuple[str, bool]]:
    panels, main = src["panels"], src["client_main"]
    wshop = re.search(r"\nBUILDERS\.WeaponShop = function\(parent\)\n(.*?)addText\(parent, T\.WeaponLocation", panels, re.S)
    potion = re.search(r'The potion shop is coming soon\.".*?return nil\n\tend\n(.*?)local gold = addText\(parent, "", '
                       r'\{ Name = "PotionGold"', panels, re.S)
    story = re.search(r"\nBUILDERS\.Story = function\(parent\)\n(.*?)\nend\n", panels, re.S)
    welcome = re.search(r"\nBUILDERS\.Welcome = function\(parent\)\n(.*?)\nend\n", panels, re.S)
    order = re.search(r"local ORDER = \{([^}]*)\}", main)
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    return [
        ("the Forge window shows Config.Text.ForgeGreeting on top (before the location line)",
         wshop is not None and "local hello = Config.Text and Config.Text.ForgeGreeting" in wshop.group(1)
         and 'addText(parent, hello, { Name = "ShopGreeting"' in wshop.group(1)),
        ("the Potion window shows Config.Text.PotionGreeting on top (before the gold line)",
         potion is not None and "local hello = Config.Text and Config.Text.PotionGreeting" in potion.group(1)
         and 'addText(parent, hello, { Name = "ShopGreeting"' in potion.group(1)),
        ("a story page waiting for a calm moment keeps the server's Var",
         "STORY.Pending = { Id = arg.Id, St = arg.St, Var = arg.Var }" in panels),
        ("the Story window takes its lines from STORY.Lines(step, f, arg.Var) and its hint from STORY.Hint(obj, f)",
         story is not None and "local lines = STORY.Lines(step, f, arg.Var)" in story.group(1)
         and "STORY.Hint(obj, f, STORY.Points(f))" in story.group(1) and "step.Lines" not in story.group(1)),
        ("the Story line and page sit beside the speaker's portrait (STORY.Talk(parent, voice) builds the row with "
         "UIKit.Portrait; 검수 2026-10-07)",
         story is not None and "local talk, align = STORY.Talk(parent, voice)" in story.group(1)
         and 'addText(talk, "", { Name = "StoryLine", Size = 22, Align = align })' in story.group(1)
         and 'addText(talk, "", { Name = "StoryPage"' in story.group(1)
         and re.search(r"\nfunction STORY\.Talk\(parent, voice\)\n\tlocal key = STORY\.PortraitKey\(voice\)\n.*?"
                       r"pcall\(UIKit\.Portrait, key, \{.*?\nend\n", panels, re.S) is not None),
        ("ClientMain ORDER ends with Audio, every module once, every module file exists",
         bool(names) and names[-1] == "Audio" and len(names) == len(set(names))
         and all((SPS / f"{n}.luau").is_file() for n in names)),
        ("the Welcome line types (TYPE.Show) with a tap button, [Next] finishes a typing line first",
         welcome is not None and "TYPE.Tap(typing, line)" in welcome.group(1)
         and "TYPE.Show(typing, line, tostring(def.Lines[page])" in welcome.group(1)
         and "if pending or TYPE.Finish(typing) then return end" in welcome.group(1)),
        ("the Story line types (TYPE.Show ... voice, page), [Next] and the answers finish a typing line first",
         story is not None and "TYPE.Tap(typing, line)" in story.group(1)
         and 'TYPE.Show(typing, line, tostring(lines[page] or ""), voice, page)' in story.group(1)
         and story.group(1).count("TYPE.Finish(typing)") >= 2),
        ("BB38: Panels.Open sends Panels.Metric(id); the [메뉴] fold, the world map and the Tab list send theirs",
         "\tcurrentId = id\n\tPanels.Metric(id)\n" in panels
         and 'pcall(panels.Metric, "Menu")' in src["hud"]
         and 'pcall(panels.Metric, "WorldMap")' in src["worldmap"]
         and 'pcall(panels.Metric, "PlayerList")' in src["playerlist"]),
        ("Config has the two shop greetings (dev2 lines_pack 11)",
         re.search(r'\n\tForgeGreeting = "[^"]+",', src["config"]) is not None
         and re.search(r'\n\tPotionGreeting = "[^"]+",', src["config"]) is not None),
    ]


def run(src: dict[str, str], directory: Path, name: str) -> dict:
    story, lean = cut_story(src["panels"])
    type_src = cut_type(src["panels"])
    metric_src = cut_metric(src["panels"])
    text = (f"local CONFIG_SOURCE = {lua_long(src['config'])}\nlocal ANNOUNCE_SOURCE = {lua_long(src['announce'])}\n"
            f"local STORY_SOURCE = {lua_long(story)}\nlocal HINT_LEAN, HINT_HAVE = {lean}\nlocal TYPE_SOURCE = {lua_long(type_src)}\n"
            f"local METRIC_SOURCE = {lua_long(metric_src)}\n"
            + FIXTURE.read_text(encoding="utf-8"))
    path = directory / name
    path.write_text(text, encoding="utf-8")
    proc = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                          errors="replace", timeout=300)
    result = None
    for line in proc.stdout.splitlines():
        if line.startswith("STORY_CLIENT_RESULT_JSON "):
            result = json.loads(line[len("STORY_CLIENT_RESULT_JSON "):])
    return {"stdout": proc.stdout, "stderr": proc.stderr, "result": result}


def failing(result: dict | None) -> set[str]:
    if not result:
        return set()
    return {f"{n['Group']} :: {n['Name']}" for n in result.get("Named", []) if n.get("Fail", 0) > 0}


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-mutations", action="store_true")
    args = parser.parse_args()
    files = {"config": CONFIG, "announce": ANNOUNCE, "panels": PANELS, "client_main": CLIENT_MAIN, "hud": HUD,
             "worldmap": WORLDMAP, "playerlist": PLAYERLIST}
    raw = {p: p.read_bytes() for p in (*files.values(), AUDIO, FIXTURE)}
    src = {k: raw[p].decode("utf-8-sig").replace("\r\n", "\n") for k, p in files.items()}
    compiler = BINARY.with_name("luau-compile.exe")
    compiled = subprocess.run([str(compiler), str(ANNOUNCE), str(PANELS), str(CLIENT_MAIN), str(FIXTURE)], cwd=ROOT,
                              stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, encoding="utf-8",
                              errors="replace", timeout=120)
    static = static_checks(src)
    mutations = []
    with tempfile.TemporaryDirectory(prefix="story_client_") as tmp:
        tmpdir = Path(tmp)
        real = run(src, tmpdir, "story_real.luau")
        base = failing(real["result"])
        print(real["stdout"], end="")
        if real["stderr"]:
            print(real["stderr"], end="")
        if not args.no_mutations:
            for i, (name, key, old, new) in enumerate(MUTATIONS):
                hits = src[key].count(old)
                if hits != 1:
                    mutations.append({"mutation": name, "applied": False, "caught": False,
                                      "note": f"pattern matched {hits} times; update MUTATIONS"})
                    print(f"mutation NOT APPLIED: {name}")
                    continue
                mutated = dict(src)
                mutated[key] = src[key].replace(old, new, 1)
                static_bad = [n for n, ok in static_checks(mutated) if not ok]
                try:
                    m = run(mutated, tmpdir, f"story_mut_{i:02d}.luau")
                    crashed = m["result"] is None
                    new_fail = sorted(failing(m["result"]) - base)
                except ValueError as err:
                    crashed, new_fail = True, [str(err)]
                caught = crashed or bool(new_fail) or bool(static_bad)
                mutations.append({"mutation": name, "file": key, "applied": True, "caught": caught, "crashed": crashed,
                                  "newFailingChecks": (new_fail + static_bad)[:6]})
                print(f"mutation {'caught' if caught else 'NOT CAUGHT'}: {name}")
    for name, ok in static:
        print(("STATIC ok   " if ok else "STATIC FAIL ") + name)
    changed = [p.relative_to(ROOT).as_posix() for p, b in raw.items() if p.read_bytes() != b]
    result = real["result"] or {}
    named = result.get("Named", [])
    bad = [n for n in named if n.get("Fail", 0) > 0]
    real_ok = real["result"] is not None and not bad and "STORY_CLIENT_OFFLINE_OK" in real["stdout"]
    mut_ok = all(m.get("applied") and m.get("caught") for m in mutations)
    static_ok = all(ok for _, ok in static)
    if compiled.returncode == 0 and real_ok and static_ok and not changed and mut_ok:
        status = "passed-no-mutations" if args.no_mutations else "passed"
    else:
        status = "failed"
    report = {
        "status": status,
        "checks": result.get("Checks", 0),
        "namedChecks": len(named),
        "failing": [{"group": n["Group"], "check": n["Name"], "firstFailure": n.get("FirstFailure")} for n in bad],
        "static": [{"check": n, "ok": ok} for n, ok in static],
        "mutations": {"total": len(MUTATIONS), "applied": sum(1 for m in mutations if m.get("applied")),
                      "caught": sum(1 for m in mutations if m.get("caught")), "results": mutations},
        "compileOk": compiled.returncode == 0,
        "compileErrors": compiled.stderr.strip(),
        "runtimeError": None if real["result"] else (real["stderr"].strip() or real["stdout"].strip())[-2000:],
        "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(b).hexdigest() for p, b in raw.items()},
        "sourcesChangedDuringRun": changed,
        "studioCalls": 0,
        "contract": "town_quests_server_2026-10-07 section 8 (E2 LinesBy -> Var, A23-58 choice hints, E5 0-point picks) "
                    "and lines_pack_server_2026-10-07 sections 1-2 (Args.Banter chat line, shop greetings); "
                    "ClientMain loads Audio (6509895).",
        "limitations": "The Story / shop windows themselves (layout, fonts, phone sizes, the portrait's look) and the "
                       "real chat need a Studio Play check; the Panels checks run the cut-out STORY functions and read "
                       "the builders.",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Named checks: {len(named) - len(bad)} passed, {len(bad)} failing; assertions "
          f"{result.get('Checks', 0) - result.get('Failed', 0)}/{result.get('Checks', 0)}")
    print(f"Status: {status} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if status in ("passed", "passed-no-mutations") else 1


if __name__ == "__main__":
    raise SystemExit(main())
