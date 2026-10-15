"""test_l10n_coverage.py : offline checks of tools/l10n_coverage.py (no network, no Studio).

The Korean judge (problems), the table index, the key / text matching (judge) on small made-up tables, then one full run
on the CURRENT Config with a saved table (--table-json): an empty table = every string missing, a table that knows one
string in Korean = that one ok. Static: the tool reads the table only (no PATCH / DELETE) and never prints the key.

Usage: py tools/test_l10n_coverage.py
"""
from __future__ import annotations

import csv
import json
from pathlib import Path
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import l10n_coverage as C  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
passed = failed = 0


def check(ok: bool, name: str, got=""):
    global passed, failed
    if ok:
        passed += 1
    else:
        failed += 1
        print(f"FAIL {name}: {got}")


def entry(key, source, ko=None, who="User"):
    t = [{"locale": "es", "translationText": "x", "translator": {"agentType": "Automation"}}]
    if ko is not None:
        t.append({"locale": "ko", "translationText": ko, "translator": {"agentType": who}})
    return {"identifier": {"key": key, "context": "", "source": source}, "translations": t}


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    P = C.problems
    # ---------------------------------------------------------------- the Korean judge
    check(P("Bought a potion!", "물약을 샀어요!") == [], "a good line: fine", P("Bought a potion!", "물약을 샀어요!"))
    check(P("Bought a potion!", "") == ["empty"] and P("Bought a potion!", "  ") == ["empty"], "blank = empty")
    check(P("Bought a potion!", "Bought a potion!") == ["english"], "the English as is = english")
    check(P("Bought a potion!", "Bought potion") == ["english"], "no Hangul at all = english")
    check(P("HP ×1.0", "HP ×1.0") == [] and P("Lv {1} · {2}", "Lv {1} · {2}") == [] and P("VIP", "VIP") == [],
          "abbreviations / numbers may stay as they are")
    check(P("PvP zone!", "PvP 구역!") == [] and P("2x XP", "XP 2배") == [], "capital abbreviations inside Korean: fine")
    check(P("Sell the potion", "potion 팔기") == ["mixed"], "an English word left in = mixed", P("Sell the potion", "potion 팔기"))
    check(P("Clear the path · {Unit} {1}/{2}", "길 뚫기 · {Unit} {1}/{2}") == [], "{Unit} is a placeholder, not English")
    check("placeholders" in P("Hit {1} slimes", "슬라임 잡기"), "a lost {1} = placeholders")
    check("placeholders" in P("Hit %d slimes", "슬라임 {1}마리"), "%d vs {1} = placeholders")
    check("numbers" in P("Kill 5 slimes", "슬라임 잡기"), "a lost number = numbers")
    check(P("Top 3: XP +10%", "1~3등: XP +10%") == [], "Korean may add numbers (Top 3 -> 1~3등)")
    check(P("Brute: Zzz… five more minutes…", "우두머리: 쿨쿨… 5분만 더…") == [], "a number word turned into a digit: fine")
    check(P("Hidden as \"<side> member\"", "\"<side> 소속\"으로 숨김") == [], "<side> is a placeholder")
    # ---------------------------------------------------------------- the index
    bk, bs = C.index([entry("A", "Hello there"), entry("", "Hello there", "안녕"), entry("B", "Bye now", "잘 가", "Automation")])
    check(bs["Hello there"]["ko"] == "안녕", "a source in two entries: the translated one wins", bs.get("Hello there"))
    check(bk["A"]["ko"] is None and bk["B"]["translator"] == "Automation", "by key + translator kept", bk)
    check(C.index([entry("A", "x y", "에이")], "ja")[0]["A"]["ko"] is None, "another locale: no Korean")
    # ---------------------------------------------------------------- matching
    bk, bs = C.index([
        entry("Config.T.Gold", "+{1} gold", "+{1} 골드"),
        entry("auto1", "Thanks a lot!", "고마워요!"),
        entry("Config.T.Old", "Win the old crown", "옛 왕관"),
        entry("Config.T.Empty", "Nothing here yet", None),
    ])
    J = C.judge
    check(J({"key": "Config.T.Gold", "source": "+{1} gold", "by": "key"}, bk, bs)[0] == "ok", "a format line by key: ok")
    check(J({"key": "Config.X.Thanks", "source": "Thanks a lot!", "by": "text"}, bk, bs)[0] == "ok",
          "a plain line found by its text (any key): ok")
    check(J({"key": "Config.X.New", "source": "Brand new words", "by": "text"}, bk, bs)[0] == "missing", "unknown: missing")
    check(J({"key": "Config.T.Empty", "source": "Nothing here yet", "by": "text"}, bk, bs)[0] == "missing",
          "an entry without Korean: missing")
    v, hit, why = J({"key": "Config.T.Old", "source": "Win the new crown", "by": "key"}, bk, bs)
    check(v == "suspect" and "stale" in why, "the table's source for the key is old English: stale", (v, why))
    check(J({"key": "Config.T.Gold2", "source": "+{1} gold", "by": "key"}, bk, bs)[0] == "ok",
          "a format line under a new key: found by its source")
    # ---------------------------------------------------------------- a full run on the current Config
    with tempfile.TemporaryDirectory(prefix="l10ncov_") as tmp:
        t = Path(tmp)
        (t / "empty.json").write_text("[]", encoding="utf-8")
        run = [sys.executable, str(ROOT / "tools/l10n_coverage.py"), "--out-dir", str(t), "--no-client-scan",
               "--format-csv", str(t / "none.csv")]
        p = subprocess.run(run + ["--table-json", str(t / "empty.json")], capture_output=True, text=True, encoding="utf-8",
                           timeout=600)
        check(p.returncode == 0 and "missing" in p.stdout, "runs on the current Config with a saved table", p.stderr[-400:])
        miss = list(csv.DictReader((t / "missing_ko.csv").open(encoding="utf-8-sig")))
        keys = {r["Key"]: r["Source"] for r in miss}
        check(len(miss) > 500, "an empty table: hundreds missing", len(miss))
        check(any(k.startswith("Config.StoryQuests.") for k in keys) and any(k.startswith("Config.ClientText.") for k in keys)
              and any(k.startswith("Config.Text.") for k in keys), "Text, ClientText and StoryQuests are all collected")
        fmt = next(((k, s) for k, s in keys.items() if "{1}" in s), None)
        check(fmt is not None, "format lines carry the Roblox form ({1})", fmt)
        plain = next(((k, s) for k, s in keys.items() if "{" not in s and "%" not in s and " " in s), None)
        table = [entry(plain[0], plain[1], "한국어 줄"), entry(fmt[0], fmt[1], fmt[1])]
        (t / "one.json").write_text(json.dumps(table, ensure_ascii=False), encoding="utf-8")
        p = subprocess.run(run + ["--table-json", str(t / "one.json")], capture_output=True, text=True, encoding="utf-8",
                           timeout=600)
        miss2 = {r["Key"] for r in csv.DictReader((t / "missing_ko.csv").open(encoding="utf-8-sig"))}
        sus = list(csv.DictReader((t / "suspect_ko.csv").open(encoding="utf-8-sig")))
        check(plain[0] not in miss2 and len(miss2) == len(miss) - 2, "the translated lines leave the missing list",
              (len(miss), len(miss2)))
        check(any(r["Key"] == fmt[0] and "english" in r["Reason"] for r in sus), "Korean = the English: suspect english",
              sus[:2])
        check(list(sus[0].keys()) == ["Key", "Source", "Ko", "Reason", "Translator"] and list(miss[0].keys()) == ["Key", "Source"],
              "csv columns")
    # ---------------------------------------------------------------- 최종 검수 10/15: every Config string unless an id
    import l10n_export as E
    W = E.looks_like_words
    words = [("Config.Classes.Warrior.Names.Halo", "Paladin"), ("Config.Classes.Archer.Names.Horns", "Shadow Hunter"),
             ("Config.Titles.Halo.1", "Squire"), ("Config.Titles.None", "Adventurer"), ("Config.WeaponNames.Warrior.1", "Twig"),
             ("Config.Codex.Screen.Text.Months.1", "Jan"), ("Config.Settings.Defs.Cam.Options.1", "Follow"),
             ("Config.Ranking.Text.TitleNames.Honor", "Honor"), ("Config.Barks.Lines.Slime.Idle.2", "Jiggle~"),
             ("Config.Keybinds.Actions.1.Label", "Attack"), ("Config.Text.PotionBought", "Bought %s potion x%d!")]
    ids = [("Config.Craft.Roles.Warrior", "Smith"), ("Config.Analytics.Steps.2", "Faction"), ("Config.Map.Lands.2.Name", "LandMeadow"),
           ("Config.TownNpcs.List.1.Name", "Npc_Bright"), ("Config.UIArt.Fonts.Body", "Font.GothamBold"),
           ("Config.Settings.Defs.Lang.Options.2", "ko"), ("Config.Factions.Halo.TeamColor", "New Yeller"),
           ("Config.QuestTabs.ById.story:H1", "Faction"), ("Config.UIArt.Parts.Toast.Tone", "Navy"),
           ("Config.Visuals.MarkModels.Halo.1", "Acc_HaloR1"), ("Config.Pets.Species.BabySlime.Icon", "IconPetBabySlime"),
           ("Config.Pets.Species.FlowerSlime.Rarity", "Fine"), ("Config.Data.Defaults.Settings.Cam", "Follow")]
    bad_w = [k for k, v in words if not W(k, v)]
    bad_i = [k for k, v in ids if W(k, v)]
    check(not bad_w, "class card names, rank titles, weapon names, months, options, idle barks are player words", bad_w)
    check(not bad_i, "ids stay out (roles, analytics, map parts, npc names, fonts, locales, colours, art, defaults)", bad_i)
    # ---------------------------------------------------------------- static
    src = (ROOT / "tools/l10n_coverage.py").read_text(encoding="utf-8")
    check('"PATCH"' not in src and '"DELETE"' not in src and '"POST", f"{U.BASE}/autolocalization' in src,
          "reads the table only (the table-id lookup POST, then GETs)")
    check(not any("api_key()" in line and "print(" in line for line in src.splitlines()), "the key is never printed")
    print(f"L10N_COVERAGE_OK checks={passed + failed} passed={passed} failed={failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
