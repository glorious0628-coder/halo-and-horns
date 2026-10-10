"""The Studio window guard of tools/studio_mcp.py (게임성 개발 3, 2026-10-10), offline.

검수 2026-10-10: a session that forgot STUDIO_NAME landed in the MAIN Studio (the old default was "GoodEvil|81671223175574")
and a Play there picked a faction and a class by itself. The rules, tested with fake window lists (no Studio, no MCP,
no network; the real mcp.bat is never started):
  * no STUDIO_NAME and no STUDIO_ID (and no HH_MAIN_STUDIO=1) -> an error at once, before any window is asked about;
  * a main-Studio window (name contains GoodEvil or 81671223175574) is only picked with HH_MAIN_STUDIO=1 (by name, by
    STUDIO_ID prefix, or by default); a practice Studio (UiSandbox, WorldKit, FilmSet) needs nothing else;
  * two windows matching one name is still an error; a window that has not connected yet is "not found yet" (None).
Mutations run on in-memory copies of the source.

Usage: py tools/test_studio_guard.py [--no-mutations]
Report: docs/art/verification_2026-10-10/offline_dev3_studio_guard_2026-10-10.json
"""
from __future__ import annotations

import json
import os
import re
import sys
import types
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
SOURCE = TOOLS / "studio_mcp.py"
REPORT = ROOT / "docs/art/verification_2026-10-10/offline_dev3_studio_guard_2026-10-10.json"

MAIN = {"id": "aaaa1111-main", "name": "GoodEvil.rbxlx - Roblox Studio"}
MAIN_PUBLISHED = {"id": "bbbb2222-pub", "name": "Halo & Horns (81671223175574) - Roblox Studio"}
UI = {"id": "cccc3333-ui", "name": "UiSandbox.rbxlx - Roblox Studio"}
UI2 = {"id": "dddd4444-ui2", "name": "UiSandbox (2).rbxlx - Roblox Studio"}
FILM = {"id": "eeee5555-film", "name": "FilmSet.rbxlx - Roblox Studio"}
WORLD = {"id": "ffff6666-world", "name": "WorldKit.rbxlx - Roblox Studio"}


def load(text: str):
    mod = types.ModuleType("studio_mcp_under_test")
    mod.__file__ = str(SOURCE)
    os.environ.setdefault("LOCALAPPDATA", str(ROOT))
    exec(compile(text, str(SOURCE), "exec"), mod.__dict__)
    return mod


class Fake:
    """A Client without the process: request() answers list_roblox_studios from a list and counts the asks."""

    def __init__(self, mod, studios):
        self.c = object.__new__(mod.Client)
        self.asks = 0
        self.studios = studios

        def request(method, params=None):
            self.asks += 1
            return {"content": [{"text": json.dumps({"studios": self.studios})}]}

        self.c.request = request


def with_env(env: dict, fn):
    keep = {k: os.environ.get(k) for k in ("STUDIO_NAME", "STUDIO_ID", "HH_MAIN_STUDIO")}
    for k in keep:
        os.environ.pop(k, None)
    os.environ.update(env)
    try:
        return fn()
    finally:
        for k, v in keep.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v


def raises(fn, part: str) -> bool:
    try:
        fn()
    except RuntimeError as err:
        return part in str(err)
    return False


def run_checks(mod, record) -> None:
    pick = mod.pick_studio
    both = [MAIN, UI]

    # --- pick_studio (pure)
    record(raises(lambda: pick(both, "", "", False), "STUDIO_NAME"), "no name, no id, no main flag: an error that says STUDIO_NAME")
    record(raises(lambda: pick(both, "  ", " ", False), "STUDIO_NAME"), "a name and an id of only spaces count as nothing")
    record(raises(lambda: pick([], None, None, False), "STUDIO_NAME"), "None names count as nothing, even with no window open")
    record(pick(both, "", "", True) == MAIN["id"], "HH_MAIN_STUDIO=1 alone picks the main Studio")
    record(pick([UI, MAIN_PUBLISHED], "", "", True) == MAIN_PUBLISHED["id"], "... also the published place (its id in the window name)")
    record(pick([UI], "", "", True) is None, "HH_MAIN_STUDIO=1 with no main window open: not connected yet (None), never the practice window")
    record(pick(both, "UiSandbox", "", False) == UI["id"], "STUDIO_NAME=UiSandbox picks the practice Studio, no flag needed")
    record(pick([MAIN, UI, FILM, WORLD], "FilmSet", "", False) == FILM["id"], "FilmSet and WorldKit are practice Studios too")
    record(pick([WORLD, FILM], "UiSandbox", "", False) is None, "the practice Studio is not open yet: None")
    record(pick([MAIN], "UiSandbox", "", False) is None, "only the main is open: a practice name never falls back to it")
    record(raises(lambda: pick(both, "GoodEvil", "", False), "메인"), "STUDIO_NAME=GoodEvil without the flag: refused")
    record(raises(lambda: pick(both, "goodevil", "", False), "메인"), "... in any letter case")
    record(raises(lambda: pick([MAIN_PUBLISHED], "81671223175574", "", False), "메인"), "the published place's id as the name: refused without the flag")
    record(raises(lambda: pick([MAIN_PUBLISHED], "Halo & Horns", "", False), "메인"), "a window found by another word of its name is still the main: refused")
    record(raises(lambda: pick(both, "GoodEvil|81671223175574", "", False), "메인"), "the old default name list: refused without the flag")
    record(pick(both, "GoodEvil", "", True) == MAIN["id"], "STUDIO_NAME=GoodEvil with the flag: the main Studio")
    record(raises(lambda: pick(both, "", MAIN["id"][:4], False), "메인"), "STUDIO_ID of the main without the flag: refused")
    record(pick(both, "", MAIN["id"][:4], True) == MAIN["id"], "STUDIO_ID of the main with the flag: ok")
    record(pick(both, "", UI["id"][:4], False) == UI["id"], "STUDIO_ID of a practice Studio: ok without the flag")
    record(pick(both, "", "zzzz", False) is None, "STUDIO_ID that matches no window: None (not connected yet)")
    record(pick(both, "GoodEvil", UI["id"][:4], False) == UI["id"], "STUDIO_ID wins over a name (the pinned window is what counts)")
    record(raises(lambda: pick([UI, UI2], "UiSandbox", "", False), "여러 개"), "two windows with one name: an error (STUDIO_ID chooses)")
    record(pick([UI, UI2], "UiSandbox", UI2["id"][:4], False) == UI2["id"], "... the pin chooses one of the two")
    record(raises(lambda: pick([UI, FILM], "UiSandbox|FilmSet", "", False), "여러 개"), "a name list with two matching windows is ambiguous, never a guess")
    record(pick([UI], "x| |UiSandbox", "", False) == UI["id"], "empty pieces of a name list are ignored")
    record(pick([UI, FILM], "UiSandbox| ", "", False) == UI["id"], "a space piece in a name list matches nothing (it is not 'every window')")
    record(raises(lambda: pick([{"id": "lc01-low", "name": "goodevil copy.rbxlx"}], "goodevil", "", False), "메인"), "a lower-case main window name is still the main")
    record(mod.is_main_name("GoodEvil.rbxlx") and mod.is_main_name("x 81671223175574") and not mod.is_main_name("UiSandbox") and not mod.is_main_name(None),
           "is_main_name: GoodEvil or the place id")

    # --- Client.studio_id (the environment, the asking)
    f = Fake(mod, both)
    record(with_env({}, lambda: raises(f.c.studio_id, "STUDIO_NAME")) and f.asks == 0, "studio_id with no environment: the error comes before any window is asked")
    f = Fake(mod, both)
    record(with_env({"HH_MAIN_STUDIO": "0"}, lambda: raises(f.c.studio_id, "STUDIO_NAME")) and f.asks == 0, "HH_MAIN_STUDIO=0 is not the flag")
    f = Fake(mod, both)
    record(with_env({"HH_MAIN_STUDIO": "yes"}, lambda: raises(f.c.studio_id, "STUDIO_NAME")) and f.asks == 0, "HH_MAIN_STUDIO=yes is not the flag either (only 1)")
    f = Fake(mod, both)
    record(with_env({"STUDIO_NAME": "UiSandbox"}, f.c.studio_id) == UI["id"] and f.asks == 1, "STUDIO_NAME=UiSandbox: the practice window, one ask")
    f = Fake(mod, both)
    record(with_env({"HH_MAIN_STUDIO": "1"}, f.c.studio_id) == MAIN["id"], "HH_MAIN_STUDIO=1: the main window")
    f = Fake(mod, both)
    record(with_env({"STUDIO_NAME": "GoodEvil"}, lambda: raises(f.c.studio_id, "메인")), "STUDIO_NAME=GoodEvil without the flag: refused")
    f = Fake(mod, both)
    record(with_env({"STUDIO_NAME": "GoodEvil", "HH_MAIN_STUDIO": "1"}, f.c.studio_id) == MAIN["id"], "STUDIO_NAME=GoodEvil with the flag: the main window")
    f = Fake(mod, both)
    record(with_env({"STUDIO_ID": MAIN["id"][:6]}, lambda: raises(f.c.studio_id, "메인")), "STUDIO_ID of the main without the flag: refused")
    f = Fake(mod, both)
    record(with_env({"STUDIO_ID": UI["id"][:6]}, f.c.studio_id) == UI["id"], "STUDIO_ID of a practice window: ok")

    # --- call(): list_roblox_studios needs no window, an explicit studio_id is the caller's own choice
    f = Fake(mod, both)
    sent = []
    f.c.request = lambda method, params=None: sent.append((method, params)) or {"content": []}
    with_env({}, lambda: f.c.call("list_roblox_studios", {}))
    record(len(sent) == 1 and "studio_id" not in sent[0][1]["arguments"], "call(list_roblox_studios) needs no environment and gets no studio_id")
    sent.clear()
    with_env({}, lambda: f.c.call("execute_luau", {"code": "x", "studio_id": "given"}))
    record(len(sent) == 1 and sent[0][1]["arguments"]["studio_id"] == "given", "a caller's own studio_id is passed through (it already chose a window)")
    f = Fake(mod, both)
    record(with_env({}, lambda: raises(lambda: f.c.call("execute_luau", {"code": "x"}), "STUDIO_NAME")) and f.asks == 0,
           "call(execute_luau) with no environment: refused, nothing sent")

    # --- the tools that use Client follow the same rule (no own default of the main window)
    for name in ("sync_to_studio.py", "playtest.py", "luau_check.py"):
        text = (TOOLS / name).read_text(encoding="utf-8")
        record("from studio_mcp import Client" in text and not re.search(r"STUDIO_NAME[\"']\s*,\s*[\"'][^\"']*GoodEvil", text) and '(기본 "GoodEvil")' not in text,
               f"{name} uses the shared Client and has no main-window default of its own")
    text = SOURCE.read_text(encoding="utf-8")
    record('os.environ.get("STUDIO_NAME", "")' in text and "GoodEvil|81671223175574" not in text.split("def pick_studio")[1], "no default name is left in studio_id")


MUTATIONS = [
    ("no name is fine", "    if not name and not pin:\n", "    if False:\n"),
    ("main needs no flag", '    if chosen is not None and is_main_name(chosen.get("name")) and not allow_main:\n', "    if False:\n"),
    ("only GoodEvil is main", 'MAIN_NAMES = ("GoodEvil", "81671223175574")', 'MAIN_NAMES = ("GoodEvil",)'),
    ("the main is found by name case-sensitively", '    return any(m.lower() in (name or "").lower() for m in MAIN_NAMES)', '    return any(m in (name or "") for m in MAIN_NAMES)'),
    ("the flag alone picks a practice window", '        name = "|".join(MAIN_NAMES)\n', '        name = "UiSandbox"\n'),
    ("two windows are not an error", "        if len(hits) > 1:\n", "        if False:\n"),
    ("the old default name is back", 'name = os.environ.get("STUDIO_NAME", "")', 'name = os.environ.get("STUDIO_NAME", "GoodEvil|81671223175574")'),
    ("any non-empty flag counts", 'allow_main = os.environ.get("HH_MAIN_STUDIO", "").strip() == "1"', 'allow_main = os.environ.get("HH_MAIN_STUDIO", "").strip() != ""'),
    ("the early check is gone", "        pick_studio([], name, pin, allow_main)  # the missing-name error comes at once, before any waiting\n", ""),
    ("the pin is ignored", '        chosen = next((s for s in studios if (s.get("id") or "").startswith(pin)), None)\n', "        chosen = None\n"),
    ("a pin bypasses the main check", '    if chosen is not None and is_main_name(chosen.get("name")) and not allow_main:\n',
     '    if chosen is not None and not pin and is_main_name(chosen.get("name")) and not allow_main:\n'),
    ("a practice name falls back to the main", "        chosen = hits[0] if hits else None\n", "        chosen = hits[0] if hits else next((s for s in studios if is_main_name(s.get('name'))), None)\n"),
    ("empty name pieces match everything", 'for w in name.split("|") if w.strip())', 'for w in name.split("|"))'),
    ("spaces count as a name", '    name, pin = (name or "").strip(), (pin or "").strip()\n', '    name, pin = (name or ""), (pin or "")\n'),
    ("the guard is only in the loop's first ask", '            found = pick_studio(studios, name, pin, allow_main)\n', '            found = pick_studio(studios, name, pin, True)\n'),
]


def main() -> int:
    no_mutations = "--no-mutations" in sys.argv
    sys.stdout.reconfigure(encoding="utf-8")
    source = SOURCE.read_text(encoding="utf-8")
    results: list[tuple[bool, str]] = []

    def record(ok, message):
        results.append((bool(ok), message))

    try:
        run_checks(load(source), record)
    except Exception as err:  # a crash is a failure, with its message
        record(False, f"checks crashed: {err!r}")
    failing = [m for ok, m in results if not ok]
    for m in failing:
        print("CHECK_FAIL", m)
    print(f"STUDIO_GUARD_OK checks={len(results)} failed={len(failing)}" if not failing else f"STUDIO_GUARD_FAILED checks={len(results)} failed={len(failing)}")
    caught, missed = 0, []
    mutation_rows = []
    if not no_mutations:
        for name, old, new in MUTATIONS:
            if source.count(old) != 1:
                missed.append(f"{name} (pattern matches {source.count(old)}x)")
                mutation_rows.append({"mutation": name, "applied": False, "caught": False})
                continue
            bad: list[tuple[bool, str]] = []
            try:
                run_checks(load(source.replace(old, new, 1)), lambda ok, m: bad.append((bool(ok), m)))
                hit = any(not ok for ok, _ in bad)
            except Exception:
                hit = True
            mutation_rows.append({"mutation": name, "applied": True, "caught": hit})
            if hit:
                caught += 1
            else:
                missed.append(name)
        for name in missed:
            print("MUTATION MISSED", name)
        print(f"MUTATIONS caught={caught}/{len(MUTATIONS)}")
    else:
        print("MUTATIONS SKIPPED (status passed-no-mutations: do not commit this report)")
    status = "failed" if failing or missed else ("passed-no-mutations" if no_mutations else "passed")
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps({
        "status": status, "checks": len(results), "failedChecks": len(failing), "failing": failing,
        "mutations": {"total": len(MUTATIONS), "caught": caught, "skipped": no_mutations, "missed": missed, "results": mutation_rows},
        "contract": "tools/studio_mcp.py picks a Studio window only with STUDIO_NAME or STUDIO_ID; the main Studio (GoodEvil / "
                    "81671223175574) only with HH_MAIN_STUDIO=1; the default name is gone; two matching windows stay an error.",
        "studioCalls": 0, "apiCalls": 0,
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Report: {REPORT.relative_to(ROOT).as_posix()}")
    return 0 if status != "failed" else 1


if __name__ == "__main__":
    sys.exit(main())
