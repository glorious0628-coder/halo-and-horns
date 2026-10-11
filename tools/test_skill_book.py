"""BB9 스킬 창 (게임성 개발 1, 2026-10-11; SPEC A23-49 / A23-71 / A23-113 / A23-116, design
docs/design/skill_kit_beta_2026-10-06.md §6-4, docs/design/skills18_2026-10-10.md "스킬 창 글(진영 줄)"), offline.

Runs, in the official Luau CLI, the CURRENT Config.luau and SkillBook.luau in tools/fixtures/skill_book_offline.luau
(Players / RunService / UserInputService / Panels / UIKit / Keybinds doubles). Checks: the window "Skills" is
registered (the HUD's Skills tile and K open it) and rebuilds on class / faction / level / slots / rebirths / weapon
while MP and cooldowns repaint in place; rows = the basic attack then Q, and Z / X only while their flags are on; each
skill row has its faction's name (Config.SkillDef), the numbers line (MP · cooldown · shape · hit) and the faction
line (Q / Z QZHalo / QZHorns, X XHalo / XHorns / XArtisan, none for the artisan Q / Z or with no side); icons in the
SkillBar order; the live state Ready / seconds left / Need MP / Unlocks at Lv N (+ [Where to hunt] -> Travel), learned
by the saved SkillSlots, the level or a rebirth; the attack row (punch bare-handed, the class pattern, Mage MP per
hit, the weapon icon, the tamer's weapon); the passive part (class stats, faction perks, fall / redeem marks);
keyboards get the key in the name and [Change keys] -> Settings Keys, touch gets neither. Static: ClientMain loads
SkillBook after Panels; the HUD tile opens "Skills"; a locked tile's window key only wiggles; the window icon.
Mutations: each must be caught.

Usage: py tools/test_skill_book.py
Report: docs/art/verification_2026-10-11/offline_skill_book_2026-10-11.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"BOOK": ROOT / "src/StarterPlayer/StarterPlayerScripts/SkillBook.luau",
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "MAIN": ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau",
         "HUD": ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau",
         "PANELS": ROOT / "src/StarterPlayer/StarterPlayerScripts/Panels.luau"}
FIXTURE = ROOT / "tools/fixtures/skill_book_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-11/offline_skill_book_2026-10-11.json"

MUTATIONS = [
    ("BOOK", "Z / X rows with their flags off", "\treturn s[T.Flag[slot]] == true or ctx.Preview == true\n", "\treturn true\n"),
    ("BOOK", "Q / Z get the X faction line", "\tif slot == \"X\" then\n\t\tif faction == \"Halo\" then return word(\"XHalo\") end",
     "\tif true then\n\t\tif faction == \"Halo\" then return word(\"XHalo\") end"),
    ("BOOK", "Horns Q / Z line missing", "\tif faction == \"Horns\" then return word(\"QZHorns\") end\n\treturn nil\nend",
     "\treturn nil\nend"),
    ("BOOK", "the artisan X line missing", "\t\tif faction == \"Neutral\" then return word(\"XArtisan\") end\n", ""),
    ("BOOK", "the saved slots ignored", "\tif num(ctx.SkillSlots, 0) >= idx then return true end\n", ""),
    ("BOOK", "a rebirth does not open the slots", "\t\tif ok and num(n, 0) >= idx then return true end\n", ""),
    ("BOOK", "the cooldown never shows", "\tif left > 0.05 then return string.format(T.Text.Wait, left), \"wait\" end\n", ""),
    ("BOOK", "MP never short", "\tif num(ctx.Mana, 0) < row.MP then return word(\"NeedMP\"), \"mp\" end\n", ""),
    ("BOOK", "own numbers again (not Config.SkillNumbers)",
     "\tlocal line = type(Config.SkillNumbers) == \"function\" and Config.SkillNumbers(def) or \"\"\n", "\tlocal line = \"\"\n"),
    ("CONFIG", "the chain counts targets as jumps", "string.format(T.ShapeChain, math.max(0, math.floor((tonumber(def.Hits) or 1) - 1)))",
     "string.format(T.ShapeChain, math.floor(tonumber(def.Hits) or 1))"),
    ("BOOK", "no hit multiplier", "\tif mult > 0 then line ..= ", "\tif false then line ..= "),
    ("BOOK", "no faction icon first", "local icons = { \"Skill_\" .. class .. \"_\" .. slot .. \"_\" .. faction, ",
     "local icons = { "),
    ("BOOK", "the punch shows as Attack", "Name = bare and T.Text.Punch or T.Text.Attack,", "Name = T.Text.Attack,"),
    ("BOOK", "no Mage MP per hit", "if not bare and class == \"Mage\" and mageMP > 0 then", "if false then"),
    ("BOOK", "no faction perks", "\tif faction ~= \"None\" and type(fd) == \"table\" and type(fd.Perks) == \"table\" and #fd.Perks > 0 then",
     "\tif false then"),
    ("BOOK", "marks not shown", "\tif fall > 0 then\n", "\tif false then\n"),
    ("BOOK", "[Where to hunt] goes nowhere", "\t\t\tkit.Open(\"Travel\")\n", "\t\t\tkit.Open(\"Menu\")\n"),
    ("BOOK", "[Change keys] on touch", "\tif ctx.Keyboard then\n\t\tlocal b = kit.Button(parent, T.Text.ChangeKeys",
     "\tif true then\n\t\tlocal b = kit.Button(parent, T.Text.ChangeKeys"),
    ("BOOK", "the state never repaints", "\t\tfor _, view in VIEW.Rows do paintState(kit, view, now) end\n", ""),
    ("BOOK", "MP changes rebuild the whole window", "Rebuild = { Class = true,", "Rebuild = { Mana = true, Class = true,"),
    ("BOOK", "the faction line in plain gold", "local fl = label(kit, mid, row.FactionLine, T.Small, (fd and fd.Color) or kit.Theme.Gold, true)",
     "local fl = label(kit, mid, row.FactionLine, T.Small, kit.Theme.Gold, true)"),
    ("BOOK", "plain labels again (tiny text in short PC windows)", "\t\tpcall(ui.StyleText, l, bold and \"Title\" or \"Body\")\n", ""),
    ("BOOK", "the style's white wins over the colours", "\t\tpcall(ui.StyleText, l, bold and \"Title\" or \"Body\")\n\t\tl.TextColor3 = color\n",
     "\t\tpcall(ui.StyleText, l, bold and \"Title\" or \"Body\")\n"),
    ("BOOK", "the attack row gets an empty state column again", "\t-- right: the live state (+ [Where to hunt] while locked)\n\tif row.Slot == \"Attack\" then return end\n",
     "\t-- right: the live state (+ [Where to hunt] while locked)\n"),
    ("BOOK", "every state column wide", "(row.Locked and T.RightW or T.StateW)", "T.RightW"),
    ("BOOK", "the scroll jumps on a level up", "		KeepScroll = true,", "		KeepScroll = false,"),
    ("PANELS", "Panels ignores KeepScroll", "queueRebuild(o ~= nil and o.KeepScroll == true)", "queueRebuild()"),
    ("MAIN", "the window is never loaded", "\"PetWindow\", \"SkillBook\", \"QuestBook\",", "\"PetWindow\", \"QuestBook\","),
    ("HUD", "K opens the window while its tile is locked", "\t\tif def.Key == action and L.TileLocked(def.Id) then\n",
     "\t\tif false then\n"),
    ("PANELS", "no window icon", "Diary = \"IconDiary\", Skills = \"IconSkills\" },", "Diary = \"IconDiary\" },"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def static(src: dict) -> list[tuple[str, bool]]:
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    return [
        ("ClientMain loads SkillBook after Panels", "SkillBook" in names and "Panels" in names
         and names.index("SkillBook") > names.index("Panels")),
        ("the HUD's Skills tile opens the window \"Skills\"",
         '{ Id = "Skills", Icon = "IconSkills", Window = "Skills", Key = "Skills", Keep = 4 },' in src["HUD"]),
        ("a locked tile's window key only wiggles it (A23-113 ③)",
         re.search(r"\t\tif def\.Key == action and L\.TileLocked\(def\.Id\) then\n\t\t\tL\.TileWiggle\(def\.Id\)\n\t\t\treturn true\n",
                   src["HUD"]) is not None),
        ("the window has the Skills icon", 'Skills = "IconSkills" },' in src["PANELS"]),
        ("Panels: a KeepScroll window's data redraw keeps the scroll",
         "\t\t\tlocal o = REG.Opts[currentId]\n\t\t\tqueueRebuild(o ~= nil and o.KeepScroll == true)\n" in src["PANELS"]),
        ("the Skills tile stays locked until the first skill (Config.HudReveal)",
         'Skills = "Skill"' in src["CONFIG"]),
    ]


def run(src: dict) -> tuple[int, int, str]:
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal BOOK_SOURCE = " + lua_str(src["BOOK"]) + "\n"
            + FIXTURE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "skill_book.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"SKILL_BOOK_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed = int(m[2]) if m else 1
    st = static(src)
    for name, ok in st:
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
        failed += 0 if ok else 1
    return (int(m[1]) if m else 0) + len(st), failed, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    checks, failed, out = run(src)
    print(out.strip())
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        caught = False
        if hits == 1:
            m = dict(src)
            m[key] = src[key].replace(old, new)
            caught = run(m)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    status = "passed" if failed == 0 and checks > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
