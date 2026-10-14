"""KingDiary offline check (SPEC A23-79 #4: the King Diary book + the candy jar; server = 게임성 개발 3's DiaryService).

Runs the CURRENT src/StarterPlayer/StarterPlayerScripts/KingDiary.luau with the CURRENT Config.luau in
tools/fixtures/king_diary_offline.luau with the installed official Luau CLI (build/luau_cli_0_741): Panels, the window
kit, PauseCard, UIKit.RewardPopup, the remotes and the player are small doubles. Static: ClientMain loads KingDiary after
Panels / PauseCard; the words are English; nothing is sold in it; the quest window's Event tab links it. Mutations:
in-memory copies with one rule broken each; each must make a check fail. Status "passed" only when the fixture passes,
the static checks pass AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-08/offline_king_diary_2026-10-08.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
MODULE = SCRIPTS / "KingDiary.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
CLIENT_MAIN = SCRIPTS / "ClientMain.client.luau"
FIXTURE = ROOT / "tools/fixtures/king_diary_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-08/offline_king_diary_2026-10-08.json"

MUTATIONS = [
    ("the server's %d sentence kept", "\tlocal words = string.gsub(text, \"%s*[^%.!%?]*%%d[^%.!%?]*[%.!%?]\", \"\")\n",
     "\tlocal words = text\n"),
    ("the day counted from 0", "\treturn math.clamp(math.floor((now - first) / 86400) + 1, 1, n)\n",
     "\treturn math.clamp(math.floor((now - first) / 86400), 1, n)\n"),
    ("before day one every page is today's", "\tif now < first then return 1 end\n", "\tif now < first then return n end\n"),
    ("a closed page shown open", "Open = i <= open }\n", "Open = i <= open + 1 }\n"),
    ("a page still to come says 'beat a king'", "\t\telseif i > today then\n", "\t\telseif false then\n"),
    ("after the season still 'beat a king'", "\t\telseif not live then\n", "\t\telseif false then\n"),
    ("the date in UTC, not Korea", "\tKST = 9 * 3600,\n", "\tKST = 0,\n"),
    ("an owned title tradeable", "\t\t\t\tCanTrade = not mine and candy >= cost })\n", "\t\t\t\tCanTrade = candy >= cost })\n"),
    ("too little candy tradeable", "\t\t\t\tCanTrade = not mine and candy >= cost })\n", "\t\t\t\tCanTrade = not mine })\n"),
    ("TitlesOwned not read", "\tfor id in string.gmatch(type(ctx.Titles) == \"string\" and ctx.Titles or \"\", \"[^,]+\") do owned[id] = true end\n", ""),
    ("a new page card again (A23-191)", 'if kind == "DiaryPage" or kind == "DiaryDone" then return false end',
     'if kind == "DiaryPage" then C.PauseCard.Show("Tip", { Text = "x" }) return true end'),
    ("trade spam", "\tif os.clock() - S.TradeAt < T.TradeGap then return false end\n", ""),
    ("my candy never updates", "\tS.Candy = (n == n and n >= 0 and n < math.huge) and math.floor(n) or 0\n", ""),
    ("no candy before my own payload", "\tif not S.HasCandy and type(panels) == \"table\" and type(panels.ItemCount) == \"function\" then\n",
     "\tif false then\n"),
    ("the cache read over my own payload", "\tS.HasCandy = true -- a payload of my own came: Panels' cache is no longer needed\n", ""),
    ("[Trade] on whatever the candy", "\t\t\tif type(kit.SetEnabled) == \"function\" then pcall(kit.SetEnabled, b, row.CanTrade) end\n", ""),
    ("no rebuild on a new page", "\t\tRebuild = { DiaryPages = true, TitlesOwned = true },\n", "\t\tRebuild = { TitlesOwned = true },\n"),
    ("the asked page not marked", "row.Page == S.Page and kit.Theme.Gold or kit.Theme.Text)\n", "kit.Theme.Text)\n"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(src: str, config: str, name: str):
    path = ROOT / f"build/king_diary_offline{name}.luau"
    path.write_text("local CONFIG_SOURCE = " + lua_str(config) + "\nlocal DIARY_SOURCE = " + lua_str(src) + "\n"
                    + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"KING_DIARY_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    src = MODULE.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(src, config, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = src.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(src.replace(old, new), config, "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    cm = CLIENT_MAIN.read_text(encoding="utf-8-sig")
    order = re.search(r"local ORDER = \{([^}]*)\}", cm)
    names = re.findall(r'"([A-Za-z]+)"', order[1]) if order else []
    code = "\n".join(line.split("--", 1)[0] for line in src.splitlines())
    words = re.search(r"\tText = \{(.*?)\},", src, re.S) or re.search(r"\nConfig\.ClientText\.KingDiary = \{(.*?)\n\}", CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n"), re.S)
    book = (SCRIPTS / "QuestBook.luau").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    static = [
        ("ClientMain loads KingDiary after Panels and PauseCard", "KingDiary" in names and "Panels" in names and "PauseCard" in names
         and names.index("KingDiary") > names.index("Panels") and names.index("KingDiary") > names.index("PauseCard")),
        ("the words are English (A23-48)", bool(words) and not re.search(r"[가-힣]", words[1])),
        ("nothing is sold in it (A23-79: candy -> titles only)", not re.search(r"MarketplaceService|Prompt[A-Za-z]*Purchase", code)),
        ("the quest window's Event tab links the diary and the jar",
         'Window = "Diary", Arg = { Tab = "Diary" } })' in book and 'Window = "Diary", Arg = { Tab = "Jar" } })' in book),
    ]
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    passed = ok and all(r["applied"] and r["caught"] for r in rows) and all(g for _, g in static)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in (MODULE, CONFIG, CLIENT_MAIN)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "limitations": "Doubles instead of Panels / UIKit: how the book and the jar look on PC and phone is a Studio "
                             "photo check (메인 반영); pages open only when a king is beaten together (DiaryService, "
                             "tools/test_return.py); a menu square for the diary needs 이미지 개발's icon."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
