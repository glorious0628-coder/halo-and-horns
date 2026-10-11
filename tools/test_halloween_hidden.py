"""The hidden Pumpkin Patch and Haunted Hollow, offline (게임성 개발 3, 2026-10-11, SPEC A23-119), plus mutations.

The user moved the public beta to 2026-12-01 and skips the Halloween season: the two seasonal fields are HIDDEN with one Config
value, Config.Halloween.Enabled = false (no code and no data is deleted; docs/design/halloween_hidden_2026-10-11.md). The real
Config.luau as shipped (no season override) is loaded with engine doubles (tools/fixtures/halloween_hidden_offline.luau) and must
show: both zones are gone from ZoneAt, every Halloween kind is off, the candy bag is not offered, no quest / daily / tutorial / help /
board / deed text or objective names the hidden fields, the news window has no Halloween line and no launch date that moved.
The static part reads the client and server sources that decide what is drawn or run (MiniMap, WorldMap, QuestBook, HalloweenService,
LostFoundService, SwitchService). Status "passed" only when the fixture and the static part pass AND every mutation was applied and caught.
(The suites that test the season's own rules - test_halloween, test_king_diary, test_map_v2, test_quest_target, test_return - turn the
season ON inside their fixtures.)
Report: docs/art/verification_2026-10-11/offline_halloween_hidden_2026-10-11.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
FIXTURE = ROOT / "tools/fixtures/halloween_hidden_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-11/offline_halloween_hidden_2026-10-11.json"
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
SSS = ROOT / "src/ServerScriptService"
FILES = {
    "MiniMap": SPS / "MiniMap.luau", "WorldMap": SPS / "WorldMap.luau", "QuestBook": SPS / "QuestBook.luau",
    "HalloweenService": SSS / "HalloweenService.luau", "LostFoundService": SSS / "LostFoundService.luau",
    "SwitchService": SSS / "SwitchService.luau",
}


def static_checks(texts: dict[str, str]) -> list[str]:
    """What the readers of the season do; every line is a failure message."""
    bad: list[str] = []

    def need(ok: bool, message: str) -> None:
        if not ok:
            bad.append(message)

    mm = texts["MiniMap"]
    need("local function seasonOff(def)" in mm and "Config.SeasonOn(def.Season)" in mm, "MiniMap has seasonOff (Config.SeasonOn)")
    read = mm.split("local function readRects(list)", 1)[-1].split("local function prepareData", 1)[0]
    need("not seasonOff(l)" in read, "MiniMap.readRects skips lands and roads of a season that is off")
    zones = mm.split("W.Zones = {}", 1)[-1].split("-- drawn world", 1)[0]
    need("not seasonOff(z)" in zones, "MiniMap skips the zones of a season that is off")
    wm = texts["WorldMap"]
    need("(l.Season == nil or Config.SeasonOn(l.Season))" in wm, "WorldMap draws a land only while its season is on")
    need("(z.Season == nil or Config.SeasonOn(z.Season))" in wm, "WorldMap draws a zone only while its season is on")
    qb = texts["QuestBook"]
    need("hw.Enabled ~= false and now < (tonumber(hw.EndsAt) or 0)" in qb, "QuestBook: the King Diary / candy jar rows follow Enabled and EndsAt")
    need("(live or pages > 0)" in qb, "QuestBook: the rows show only while live or when I have a page")
    need('return Config.SeasonOn("Halloween")' in texts["HalloweenService"], "HalloweenService runs only while Config.SeasonOn('Halloween')")
    need("Config.SeasonOn(d.Season)" in texts["LostFoundService"], "LostFoundService offers an item only while its season is on")
    need('Config.Halloween.Enabled = SwitchService.On("Halloween") and ORIGINAL.Halloween == true' in texts["SwitchService"],
         "the live switch Halloween can only turn the season off (ANDed with the Config value)")
    return bad


# (name, target, exact old text, new text, a text the failing checks must name); target = "Config" or a FILES key
MUTATIONS = [
    ("the season is on again", "Config", "\tEnabled = false,\n\t-- A23-28 HW-13", "\tEnabled = true,\n\t-- A23-28 HW-13", "Enabled is false"),
    ("the news says Halloween", "Config", "{ Title = \"New this week\", Lines = {\n",
     "{ Title = \"New this week\", Lines = {\n\t\t\t\"Halloween: the Pumpkin Patch and the new Haunted Hollow with ghosts and the Ghost King.\",\n", "no Halloween line"),
    ("the news names December 19", "Config", "carries over to the full launch.\"", "carries over to the full launch on December 19.\"", "December 19"),
    ("the news forgets the beta", "Config", "Your beta save carries over to the full launch.", "Your save is kept.", "the beta lines stay"),
    ("a quest guides to the patch", "Config",
     "{ Text = \"Slimes %d/%d\", Guide = \"SlimeMeadow\", Obj = { Type = \"Kill\", Kind = \"Slime\", Zone = \"SlimeMeadow\", Count = 6 } },",
     "{ Text = \"Slimes %d/%d\", Guide = \"PumpkinPatch\", Obj = { Type = \"Kill\", Kind = \"Slime\", Zone = \"SlimeMeadow\", Count = 6 } },",
     "points at a hidden zone"),
    ("a quest says candy", "Config", "Finish = \"Sir Gleam: Is it still helping if you do it for the hearts?\",",
     "Finish = \"Sir Gleam: Is it still helping? Have some candy!\",", "names pumpkins"),
    ("the candy bag is offered", "Config", "Card = \"LostCandy\", Season = \"Halloween\" },", "Card = \"LostCandy\" },", "candy bag is not offered"),
    ("a pumpkin slime without its season", "Config", "QuestAs = \"Slime\",\n\t\tSeason = \"Halloween\", HP = 14", "QuestAs = \"Slime\",\n\t\tHP = 14",
     "lives outside the two fields"),
    ("the live switch is gone", "Config", "Halloween = { Type = \"Bool\", Default = true }, -- Config.Halloween.Enabled follows it",
     "HalloweenX = { Type = \"Bool\", Default = true },", "live switch Halloween"),
    ("the minimap draws a season that is off (lands)", "MiniMap", "if type(l) == \"table\" and not seasonOff(l) then", "if type(l) == \"table\" then", "skips lands and roads"),
    ("the minimap draws a season that is off (zones)", "MiniMap", " and not seasonOff(z) then", " then", "skips the zones"),
    ("the minimap helper reads another season", "MiniMap", "not Config.SeasonOn(def.Season)", "false", "has seasonOff"),
    ("the big map draws a seasonal land", "WorldMap", "(l.Season == nil or Config.SeasonOn(l.Season))", "true", "WorldMap draws a land"),
    ("the diary row ignores the switch", "QuestBook", "hw.Enabled ~= false and now", "now", "follow Enabled"),
    ("the live switch can turn the season on", "SwitchService", "SwitchService.On(\"Halloween\") and ORIGINAL.Halloween == true", "SwitchService.On(\"Halloween\")",
     "can only turn the season off"),
    ("the candy bag ignores its season", "LostFoundService", "Config.SeasonOn(d.Season)", "true", "offers an item only while"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(config: str, name: str):
    path = ROOT / f"build/halloween_hidden_offline{name}.luau"
    path.write_text("local CONFIG_SOURCE = " + lua_str(config) + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=300)
    match = re.search(r"HALLOWEEN_HIDDEN_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails


def main():
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    texts = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    ok, checks, fails = run(config, "")
    for line in fails:
        print(line)
    static = static_checks(texts)
    for line in static:
        print("STATIC_FAILURE", line)
    print(f"HALLOWEEN_HIDDEN fixture checks={checks} ok={ok}; static failures={len(static)}")
    rows = []
    for name, target, old, new, expect in MUTATIONS:
        source = config if target == "Config" else texts[target]
        applied = source.count(old) == 1
        caught, why = False, []
        if applied:
            if target == "Config":
                m_ok, _, why = run(config.replace(old, new), "_mut")
                why = [w for w in why]
                caught = (not m_ok) and any(expect in line for line in why)
            else:
                mutated = dict(texts)
                mutated[target] = source.replace(old, new)
                why = static_checks(mutated)
                caught = any(expect in line for line in why)
        rows.append({"mutation": name, "target": target, "applied": applied, "caught": caught, "expect": expect, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    passed = ok and not static and all(r["applied"] and r["caught"] for r in rows)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails, "staticFailures": static,
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows), "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {CONFIG.relative_to(ROOT).as_posix(): hashlib.sha256(CONFIG.read_bytes()).hexdigest(),
                               **{p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in FILES.values()}},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "contract": __doc__.split("Status")[0].strip(),
              "limitations": "The land and the props of the two fields stay in the saved place (nothing is deleted): the world side (image generation 1) "
                             "replaces them when the new zone is built. What a client draws is read as source text, not run."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
