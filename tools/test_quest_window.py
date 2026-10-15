"""QuestBook offline check (SPEC A23-81: Q = the whole quest window; five tabs Main / Side / Daily / Event / Faction, each
with In progress / Available / Done; a row press guides like the HUD lines).

Runs the CURRENT src/StarterPlayer/StarterPlayerScripts/QuestBook.luau with the CURRENT Config.luau (Config.QuestTabs /
Config.QuestTab, StoryQuests, Tutorial, Quests) in tools/fixtures/quest_window_offline.luau with the installed official Luau
CLI (build/luau_cli_0_741): Panels, the window kit and the HUD's quest API are small doubles. Static: ClientMain loads
QuestBook after Panels and HUD; the game words are English (no Hangul in its text table); the HUD routes its quest list
(Q, the ▼ button, a phone tap) to the window and offers the API the window uses. Mutations: in-memory copies with one rule
broken each (QuestBook or Config); each must make a check fail. Status "passed" only when the fixture passes, the static
checks pass AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-08/offline_quest_window_2026-10-08.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
BOOK = SCRIPTS / "QuestBook.luau"
HUD = SCRIPTS / "HUD.luau"
CLIENT_MAIN = SCRIPTS / "ClientMain.client.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
FIXTURE = ROOT / "tools/fixtures/quest_window_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-08/offline_quest_window_2026-10-08.json"

MUTATIONS = [
    # 최종 검수 10/15: the list rows are translated by their English words
    ("BOOK", "list rows drawn in English", "\tlabel(kit, f, rowWords(row.Text), T.RowText,", "\tlabel(kit, f, row.Text, T.RowText,"),
    ("BOOK", "a 'words · tail' row never split", '\tif not string.find(text, " · ", 1, true) then return text end\n',
     "\tdo return text end\n"),
    ("BOOK", "no tab icons", "\t\ttabIcon(b, id)\n", ""),
    ("BOOK", "an icon without art", '\tif not ok or type(img) ~= "string" or img == "" then return nil end\n', ""),
    # 검수 10/09: the Studio-only preview hook
    ("BOOK", "the preview hook outside Studio", "\tif RunService:IsStudio() then\n\t\tlocal lp = Players.LocalPlayer\n",
     "\tif true then\n\t\tlocal lp = Players.LocalPlayer\n"),
    ("BOOK", "the preview shows the real rows", "\tif S.Preview then return QuestBook.PreviewContext(S.Preview, Util.Now()) end\n", ""),
    ("BOOK", "a sample [Claim] reaches the server", "\t\t\tif S.Preview then return end -- sample rows: nothing to claim\n", ""),
    ("BOOK", "'' never closes the preview", "\t\tS.Preview = nil\n\t\tQuestBook.Toggle(false)\n", "\t\tS.Preview = nil\n"),
    ("BOOK", "the open window is not redrawn", "\t\tif VIEW.Body then drawBody() else QuestBook.Toggle(true) end\n",
     "\t\tQuestBook.Toggle(true)\n"),
    ("BOOK", "any mode accepted", "\tif not T.Preview.Modes[mode] then return nil end\n", ""),
    ("BOOK", "empty mode keeps the rows", "\t\tif empty then return out end\n", ""),
    ("BOOK", "no rerollable sample daily", '{ Id = "Gold", Kind = "Daily", Slot = 2, Text = "Collect 60 gold", Progress = 20, Target = 60 },',
     '{ Id = "Gold", Kind = "Daily", Slot = 2, Text = "Collect 60 gold", Progress = 60, Target = 60 },'),
    ("BOOK", "every quest in every tab", "\t\t\tif QuestBook.TabOf(e) == tab then\n", "\t\t\tif true then\n"),
    ("BOOK", "no goose info line", '\t\tif gattr("GooseActive") == true then table.insert(out.InProgress, { Kind = "Info", Text = T.Text.Goose }) end\n', ""),
    ("BOOK", "the crown war line without a round", "\t\tif warEnds > now then\n", "\t\tif true then\n"),
    ("BOOK", "wanted stars ignored", "\t\tif stars > 0 then table.insert(out.InProgress, { Kind = \"Info\", Text = string.format(T.Text.Wanted, stars) }) end\n", ""),
    ("BOOK", "the server's book ignored", "\tlocal book = type(ctx.Book) == \"table\" and ctx.Book or nil\n", "\tlocal book = nil\n"),
    ("BOOK", "the book's rows in every tab", "\t\t\tif row and row.Tab == tab then done(row.Text) end\n",
     "\t\t\tif row then done(row.Text) end\n"),
    ("BOOK", "the book's Available rows in every tab", "\t\t\t\tif row and row.Tab == tab then\n\t\t\t\t\trow.Kind = \"Available\"\n",
     "\t\t\t\tif row then\n\t\t\t\t\trow.Kind = \"Available\"\n"),
    ("BOOK", "the Main tab lists Available", "T.NoAvailable = { Main = true }", "T.NoAvailable = {}"),
    ("BOOK", "the book's words replaced by the title", "\tif type(text) == \"string\" and text ~= \"\" then return text end\n", ""),
    ("BOOK", "with a book the main chain is still guessed", "\t\tif not book and mainId and type(chain) == \"table\" then\n",
     "\t\tif mainId and type(chain) == \"table\" then\n"),
    ("BOOK", "session stories listed next to the book", " and not (book and story) then\n", " then\n"),
    ("BOOK", "the whole main chain counted done", "\t\t\t\tif id == mainId then break end\n", ""),
    ("BOOK", "the first mission never done", "\t\tif (step and step >= doneStep) or mainId then done(T.Text.FirstMission) end\n", ""),
    ("BOOK", "the first mission done while it runs", "\t\tif (step and step >= doneStep) or mainId then done(T.Text.FirstMission) end\n",
     "\t\tdone(T.Text.FirstMission)\n"),
    ("BOOK", "this session's finished quests in every tab", "\t\tif type(d) == \"table\" and Config.QuestTab(d.Id, d.Kind) == tab and not (book and story) then\n",
     "\t\tif type(d) == \"table\" and not (book and story) then\n"),
    ("BOOK", "no daily count", "\t\tif claims > 0 then table.insert(out.Done", "\t\tif false then table.insert(out.Done"),
    ("BOOK", "a row press does not close the window", "\t\t\tif hudCall(\"QuestGo\", row.Entry) and VIEW.Kit then VIEW.Kit.Close() end\n",
     "\t\t\thudCall(\"QuestGo\", row.Entry)\n"),
    ("BOOK", "[Claim] does nothing", "\t\t\thudCall(\"QuestClaim\", row.Entry)\n", ""),
    ("BOOK", "[New] claims instead", "\t\t\thudCall(\"QuestReroll\", row.Entry)\n", "\t\t\thudCall(\"QuestClaim\", row.Entry)\n"),
    ("BOOK", "no redraw when the quests change", "\t\t\t\tlocal ok, err = pcall(drawBody)\n", "\t\t\t\tlocal ok, err = true, nil\n"),
    ("BOOK", "a closed window still redraws",
     "\tVIEW.Parent, VIEW.Kit, VIEW.Tabs, VIEW.Body, VIEW.Bar, VIEW.TabSig = nil, nil, nil, nil, nil, nil\n", ""),
    ("BOOK", "Daily shows while locked", 'not (id == "Daily" and ctx.DailyLocked == true)', "true"),
    ("BOOK", "empty tabs show", "keep = #sec.InProgress + #sec.Available + #sec.Done > 0", "keep = true"),
    ("BOOK", "Main can hide", "local keep = i == 1\n", "local keep = false\n"),
    ("BOOK", "the tab set never changes in an open window", "\tif table.concat(vis, \",\") ~= VIEW.TabSig then makeTabs(vis) end\n", ""),
    ("BOOK", "Toggle never closes", "\t\tif current == T.Window then panels.Close(true) end\n", ""),
    ("BOOK", "the asked tab ignored", "\tif type(arg) == \"table\" and table.find(tabs(), arg.Tab) then\n", "\tif false then\n"),
    ("BOOK", "no counts on the tabs", "\t\tb.Text = n > 0 and string.format(T.Text.TabCount, name, n) or name\n", "\t\tb.Text = name\n"),
    ("BOOK", "diary links without the diary window", "\t\tif ctx.HasDiary == true and total > 0 and (live or pages > 0) then\n",
     "\t\tif total > 0 and (live or pages > 0) then\n"),
    ("BOOK", "diary links after the season with no page", "\t\tif ctx.HasDiary == true and total > 0 and (live or pages > 0) then\n",
     "\t\tif ctx.HasDiary == true and total > 0 then\n"),
    ("BOOK", "a link counted on the tab", "\t\t\tif r.Kind ~= \"Link\" then n += 1 end -- a window link is no quest to count\n",
     "\t\t\tn += 1\n"),
    ("BOOK", "a link opens nothing", "\t\t\tif VIEW.Kit then VIEW.Kit.Open(row.Window, row.Arg) end -- with a back button to the quests\n", ""),
    ("CONFIG", "QuestTab ignores the id table", "\tif byId then return byId end\n", ""),
    ("CONFIG", "a Halo story counted as Side", '["story:H2"] = "Faction", ', ""),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(book: str, config: str, name: str):
    path = ROOT / f"build/quest_window_offline{name}.luau"
    path.write_text("local CONFIG_SOURCE = " + lua_str(config) + "\nlocal BOOK_SOURCE = " + lua_str(book) + "\n"
                    + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=180)
    match = re.search(r"QUEST_BOOK_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    book = BOOK.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(book, config, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for src_name, name, old, new in MUTATIONS:
        src = book if src_name == "BOOK" else config
        applied = src.count(old) == 1
        caught, why = False, []
        if applied:
            mutated = src.replace(old, new)
            m_ok, _, why, _ = run(mutated if src_name == "BOOK" else book, mutated if src_name == "CONFIG" else config, "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "source": src_name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    cm = CLIENT_MAIN.read_text(encoding="utf-8-sig")
    order = re.search(r"local ORDER = \{([^}]*)\}", cm)
    names = re.findall(r'"([A-Za-z]+)"', order[1]) if order else []
    hud = HUD.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    settings_ui = (SCRIPTS / "SettingsUI.luau").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    words = re.search(r"\tText = \{(.*?)\n\t\},", book, re.S) or re.search(r"\nConfig\.ClientText\.QuestBook = \{(.*?)\n\}", CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n"), re.S)
    static = [
        ("ClientMain loads QuestBook after Panels and HUD", "QuestBook" in names and "Panels" in names and "HUD" in names
         and names.index("QuestBook") > names.index("Panels") and names.index("QuestBook") > names.index("HUD")),
        ("the window's words are English (A23-48)", bool(words) and not re.search(r"[가-힣]", words[1])),
        ("the Main tab draws no Available section (검수 10/08)",
         "if not T.NoAvailable[S.Tab] then section(kit, body, T.Text.Available, sec.Available, T.Text.EmptyAvailable) end" in book),
        ("the HUD's quest list opens the window (toggleQuests -> QuestBook.Toggle)",
         "if L.HasQuestBook() then\n\t\tlocal ok = pcall(C.QuestBook.Toggle, open)" in hud),
        ("the HUD offers the window's API", all(f"function HUD.{fn}(" in hud for fn in
         ("QuestEntries", "QuestBook", "QuestDoneSession", "QuestCanClaim", "QuestCanReroll", "QuestClaim", "QuestReroll", "QuestGo"))),
        # 빛 마을 점검 #19 (dev3: Config.StoryQuests.SendAllSubs): More rows = the quest window only
        ("#19: the HUD keeps a row's More flag, draws only the rows without it, and the window lists every row",
         "\t\t\t\tMore = e.More == true,\n" in hud
         and "\t\tif not e.More or waiting then table.insert(entries, e) end\n" in hud
         and "\tquestState.All = all -- + the More rows (HUD.QuestEntries: the quest window)\n" in hud
         and "\tfor i, e in questState.All or questState.Rows or {} do out[i] = e end\n" in hud),
        ("검수 10/10: a waiting story (B15) on a More row stays on the HUD (its row to tap and pulse)",
         "\t\tlocal waiting = call ~= nil and e.Story ~= nil and e.Story.Panel and e.Story.Id == call.Id\n" in hud
         and hud.find("\tlocal call = L.StoryPending()\n\tlocal entries = {}\n") > 0),
        ("검수 10/10: the claim count covers every row (the window's More rows too; the head count is gone, A23-99)",
         "\tfor _, e in all do\n\t\tif e.Progress >= e.Target and e.CanClaim and (e.Pinned or e.Kind == \"Daily\" or e.Kind == \"Sub\") then claimable += 1 end\n" in hud),
        ("#19: a More row (no HUD row) is claimed straight from the window",
         "\tif e.More and e.Story and type(e.Id) == \"string\" and not throttled(\"claim\", 0.35) then\n\t\tfire(\"ClaimQuest\", e.Id)\n" in hud),
        ("the HUD tells the window when its quests change", "pcall(function() HUD.QuestsChanged:Fire() end)" in hud
         and "HUD.QuestsChanged = Util.Signal.new()" in hud),
        ("Help keeps the Key settings button -> Settings / Keys, and the keys tip line is gone (A23-191: no tip lines)",
         'button(kit, row1, help.KeysButton, 200, function() kit.Open("Settings", { Tab = "Keys" }) end)' in settings_ui
         and "KeysTip" not in settings_ui and "Tip: You can change your keys" not in config),
    ]
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    passed = ok and all(r["applied"] and r["caught"] for r in rows) and all(g for _, g in static)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in (BOOK, CONFIG, HUD, CLIENT_MAIN)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "limitations": "Doubles instead of Panels / the HUD: the window's look on PC and phone and the HUD's real rows "
                             "are a Studio photo check (메인 반영). The book rows follow 게임성 개발 3's contract "
                             "(tools/test_quest_book.py checks the server side); before a book comes Done is what the client can tell."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
