"""UIKit.Tr - sentences with numbers / names translated by key (최종 검수 10/14, A23-179), offline.

Roblox's automatic translation only matches whole drawn sentences, so "Next: Lv 5 · first skill" stayed English. Now:
1. UIKit.TrForm(fmt): the localization table's Source form - each %s / %d / %.1f / %02d ... -> {1}, {2}, ...; %% -> %.
   tools/l10n_format_keys.py makes the same form for every Config sentence (build/l10n/format_keys.json / .csv): both
   are checked to agree here.
2. UIKit.TrArgs(fmt, ...): each argument printed as its own English token would ("%d" 5.6 -> "6", "%.1f", "%02d").
3. UIKit.Tr(key, ...): a non-English player's translator -> Translator:FormatByKey(key, args); English / no translator /
   unknown key / an error / no arguments = the English line as before (L10n.T).
4. UIKit.Tx(t, key, ...) with arguments goes through UIKit.Tr (every keyed table: Config paths, module TXT tables);
   UIKit.Start asks for the translator once (UIKit.TrStart).
Extracted and run: the TR block of UIKit.luau with doubles. Static: the hookups. Mutations: each must make a check fail.
Report: docs/art/verification_2026-10-14/offline_ui_tr_2026-10-14.json (do not commit)
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from l10n_format_keys import module_rows, roblox_form  # noqa: E402

FILE = ROOT / "src/StarterPlayer/StarterPlayerScripts/UIKit.luau"
TOOL = ROOT / "tools/l10n_format_keys.py"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-14/offline_ui_tr_2026-10-14.json"
CUT = ("UIKit.TR = { Translator = nil", "\n-- the player's translator (once")
TX_CUT = ("function UIKit.Tx(t, key, ...)", "\nend\n")
SAMPLES = ["Enhance Scroll: 70% gives +1", "Next: %s", "Lv %d · %s (100%%)", "%.1f%%", "%02d:%02d left", "Reborn! Gold, XP +%d%%", "Power %s → %s",
           "Bought %s potion x%d!", "no tokens here", "%s stole %s gold"]

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local TEMPLATES = { ["Config.GoalChips.Text.Zone"] = "Lv %d · %s", ["CraftWindow.TXT.Power"] = "Power %s → %s" }
local tcalls = 0
local L10n = {
	Get = function(key) return TEMPLATES[key] or key end,
	T = function(key, args) tcalls += 1 return "EN:" .. key .. ":" .. (args and table.concat(args, ",") or "") end,
	PathOf = function(t) return t.__path end,
}
local fcalls = {}
local Translator = { LocaleId = "ko-kr" }
function Translator:FormatByKey(key, args)
	table.insert(fcalls, key)
	if key == "Bad.Key" then error("no entry") end
	return "KO[" .. key .. "]" .. table.concat(args, "|")
end
local UIKit = { L10n = L10n, Lang = function() return "en" end }
local f = assert(loadstring(PART .. "\n" .. TX, "=Part"))
setfenv(f, setmetatable({ UIKit = UIKit }, { __index = getfenv() }))
f()

-- 1. the table's form
for _, s in SAMPLES_LUA do
	local form, n = UIKit.TrForm(s[1])
	check(form == s[2] and n == s[3], "form of " .. s[1], form .. " / " .. tostring(n))
end
-- 2. the arguments as their English tokens print them
local a = UIKit.TrArgs("Lv %d · %s", 5, "Woods")
check(#a == 2 and a[1] == "5" and a[2] == "Woods", "Lv %d · %s -> 5, Woods", table.concat(a, ","))
a = UIKit.TrArgs("%.1f and %02d and %d", 2.345, 7, 5.6)
check(a[1] == "2.3" and a[2] == "07" and a[3] == string.format("%d", 5.6), "%.1f / %02d / %d of a fraction (as English prints it)",
	table.concat(a, ","))
a = UIKit.TrArgs("%d and %s", nil, "x")
check(a[1] == "nil" and a[2] == "x", "a bad argument does not break the list", table.concat(a, ","))
a = UIKit.TrArgs("100%% %s", "x")
check(#a == 1 and a[1] == "x", "%% is no argument", table.concat(a, ","))
a = UIKit.TrArgs("50%%d of %s", "x")
check(#a == 1 and a[1] == "x", "%%d is the words '%d', no argument", table.concat(a, ","))
a = UIKit.TrArgs(nil, 1)
check(#a == 0, "no format: no arguments")
-- 3. Tr
check(UIKit.Tr("Config.GoalChips.Text.Zone", 5, "Woods") == "EN:Config.GoalChips.Text.Zone:5,Woods" and #fcalls == 0,
	"no translator: the English line (L10n.T)")
UIKit.TR.Translator, UIKit.TR.English = Translator, true
check(UIKit.Tr("Config.GoalChips.Text.Zone", 5, "Woods"):sub(1, 3) == "EN:" and #fcalls == 0, "an English player: the English line")
UIKit.TR.English = false
local out = UIKit.Tr("Config.GoalChips.Text.Zone", 5, "Woods")
check(out == "KO[Config.GoalChips.Text.Zone]5|Woods" and fcalls[1] == "Config.GoalChips.Text.Zone",
	"another language: FormatByKey(key, the printed arguments)", out)
check(UIKit.Tr("Unknown.Key", 1):sub(1, 3) == "EN:" and #fcalls == 1, "an unknown key: English, the translator not asked")
TEMPLATES["Bad.Key"] = "x %s"
check(UIKit.Tr("Bad.Key", 1):sub(1, 3) == "EN:" and #fcalls == 2, "the translator fails: English")
-- 10/14 (publish5): a piece without arguments goes by its key too (it may sit inside another sentence)
out = UIKit.Tr("Config.GoalChips.Text.Zone")
check(out == "KO[Config.GoalChips.Text.Zone]" and #fcalls == 3, "no arguments: by its key too (FormatByKey, no arguments)", out)
table.remove(fcalls)
check(UIKit.Tr("Unknown.Word"):sub(1, 3) == "EN:" and #fcalls == 2, "no arguments, unknown key: English, not asked")
TEMPLATES["Config.X.Up"] = "Up %.1f%%"
out = UIKit.Tr("Config.X.Up", 2.345)
check(out == "KO[Config.X.Up]2.3", "the table gets the printed number (2.3), not the raw one", out)
table.remove(fcalls)
-- 4. Tx with arguments goes by key
local Craft = { __path = "CraftWindow.TXT", Power = "Power %s → %s", Title = "Crafting" }
out = UIKit.Tx(Craft, "Power", "120", "150")
check(out == "KO[CraftWindow.TXT.Power]120|150", "UIKit.Tx with arguments -> UIKit.Tr by its key", out)
TEMPLATES["CraftWindow.TXT.Title"] = "Crafting"
out = UIKit.Tx(Craft, "Title")
check(out == "KO[CraftWindow.TXT.Title]" and #fcalls == 4, "UIKit.Tx without arguments: by its key too", out)
-- 5. the goal chips (HUD L.GoalTiers, the real function): the inner pieces (the step, the side word) are translated
-- by their keys BEFORE they go into 'Next: %s' / 'Big goal: %s' (publish5: they stayed English)
for k, v in { Next = "Next: %s", Big = "Big goal: %s", FirstSkill = "Lv %d · first skill", Halo = "Win the Crown" } do
	TEMPLATES["Config.GoalChips.Text." .. k] = v
end
local Config = { GoalChips = { Enabled = true, Steps = { { Kind = "Skill", Slot = "Q" } },
	Text = { __path = "Config.GoalChips.Text", Next = "Next: %s", Big = "Big goal: %s", FirstSkill = "Lv %d · first skill",
		Skill = "Lv %d · new skill", Halo = "Win the Crown", Horns = "Win the Crown" } },
	Skills = { Order = { "Q", "Z", "X" }, Unlock = { Q = 5 } }, Zones = {} }
local L = {}
function L.Tx(t, key, ...) return UIKit.Tx(t, key, ...) end
local fg = assert(loadstring(GOAL, "=GoalTiers"))
setfenv(fg, setmetatable({ L = L, Config = Config }, { __index = getfenv() }))
fg()
local nextLine, big = L.GoalTiers(1, 0, 0, "Halo", nil)
check(nextLine == "KO[Config.GoalChips.Text.Next]KO[Config.GoalChips.Text.FirstSkill]5", "goal chip tier 2: the step inside is translated too", nextLine)
check(big == "KO[Config.GoalChips.Text.Big]KO[Config.GoalChips.Text.Halo]", "goal chip tier 3: the side word inside is translated too", big)
-- 6. 개발 1 10/14 (Korean client: '다음: Enhance', '출처: Flower Slime', '· Pouch 0'): the arguments' words are
-- translated by their English text (Translator:Translate); numbers never go there
local words = { Woods = "숲", Pouch = "주머니" }
local tcount = 0
function Translator:Translate(ctx, text)
	tcount += 1
	assert(not string.find(text, "^%d+$"), "a number asked: " .. text)
	return words[text] or text
end
UIKit.TR.English = false
out = UIKit.Tr("Config.GoalChips.Text.Zone", 5, "Woods")
check(out == "KO[Config.GoalChips.Text.Zone]5|숲", "the words inside the sentence are translated too", out)
TEMPLATES["Config.ClientText.HUD.Pouch"] = "· %s %s"
out = UIKit.Tr("Config.ClientText.HUD.Pouch", "Pouch", "0")
check(out == "KO[Config.ClientText.HUD.Pouch]주머니|0", "a wordless format: its words translated, the number as it is", out)
out = UIKit.Tr("Unknown.Key", "Pouch")
check(out == "EN:Unknown.Key:주머니", "not in the table: the English format with the words translated", out)
out = UIKit.Tr("Unknown.Key", "Grabbo")
check(out == "EN:Unknown.Key:Grabbo", "a word with no entry stays as it is", out)
UIKit.TR.English = true
tcount = 0
out = UIKit.Tr("Config.GoalChips.Text.Zone", 5, "Woods")
check(tcount == 0 and out:sub(1, 3) == "EN:" and out:find("Woods", 1, true), "an English player: nothing translated", out)
check(UIKit.TrWord("Woods") == "Woods" and tcount == 0, "TrWord: an English player keeps the word, translator not asked")
UIKit.TR.English = false
check(UIKit.TrWord("1.2K") == "1.2K" and UIKit.TrWord("100/100") == "100/100" and tcount == 0, "TrWord: numbers never asked")
check(UIKit.TrWord("Pouch") == "주머니" and tcount == 1, "TrWord: a word by its English text")
print(("UI_TR_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("%% taken as an argument", 'local clean = string.gsub(fmt, "%%%%", "")', "local clean = fmt"),
    ("a bad argument breaks the list", "out[i] = ok and s or tostring(v)", "out[i] = s"),
    ("the form keeps %%", 's = string.gsub(s, UIKit.TR.Pct, "%%")', "s = s"),
    ("A: '70% gives' read as a slot again (the space flag)", 'Spec = "%%[-+#0]*', 'Spec = "%%[-+ #0]*'),
    ("an English player asks the translator", "if tr and not UIKit.TR.English and type(key)", "if tr and type(key)"),
    ("an unknown key asks the translator", 'if type(fmt) == "string" and fmt ~= key then', 'if type(fmt) == "string" then'),
    ("a translator error not caught", "local ok, out = pcall(tr.FormatByKey, tr, key, args)",
     "local ok, out = true, tr:FormatByKey(key, args)"),
    ("raw arguments to the table", "local args = n > 0 and UIKit.TrArgs(fmt, ...) or {}", "local args = { ... }"),
    ("the words inside stay English (dev 1 10/14: '다음: Enhance')", "for i, a in args do args[i] = UIKit.TrWord(a) end", ""),
    ("not-in-table formats keep English words ('· Pouch 0')", "vals[i] = UIKit.TrWord(vals[i])", "vals[i] = vals[i]"),
    ("an English player's words go to the translator", "if not tr or UIKit.TR.English or type(s)", "if not tr or type(s)"),
    ("numbers go to the translator", 'type(s) ~= "string" or not string.find(s, "%a%a")', 'type(s) ~= "string"'),
    ("Tx skips Tr", '\t\t\treturn UIKit.Tr(path .. "." .. key, ...) -- 10/14', '\t\t\treturn UIKit.L10n.T(path .. "." .. key, nil, UIKit.Lang()) -- 10/14'),
    ("a piece without arguments stays English (publish5)", "if tr and not UIKit.TR.English and type(key)", "if tr and n > 0 and not UIKit.TR.English and type(key)"),
    ("no translator asked at start", "\ttask.spawn(UIKit.TrStart) -- 10/14", "\t-- task.spawn(UIKit.TrStart) -- 10/14"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def cut(text: str, start: str, end: str, keep_end: bool = False) -> str:
    a = text.find(start)
    if a < 0:
        return ""
    b = text.find(end, a)
    if b < 0:
        return ""
    return text[a:b + (len(end) if keep_end else 0)]


def samples_lua() -> str:
    rows = []
    for s in SAMPLES:
        form, args = roblox_form(s)
        rows.append("{ " + lua_str(s) + ", " + lua_str(form) + ", " + str(len(args)) + " }")
    return "local SAMPLES_LUA = { " + ", ".join(rows) + " }\n"


def statics(src: str) -> list[tuple[str, bool]]:
    tool = TOOL.read_text(encoding="utf-8") if TOOL.exists() else ""
    return [
        ("UIKit.Start asks for the translator once (UIKit.TrStart, GetTranslatorForPlayerAsync in a pcall)",
         "\ttask.spawn(UIKit.TrStart) -- 10/14" in src and "GetTranslatorForPlayerAsync(LocalPlayer)" in src),
        ("the format list tool writes the table form (json + csv) with the same token rule",
         "def roblox_form(" in tool and 'with_suffix(".csv")' in tool and r'SPEC = re.compile(r"%%|%[-+#0]*\d*(?:\.\d+)?[sdifgxXcq]")' in tool
         and 'Spec = "%%[-+#0]*%d*%.?%d*[sdifgxXcq]"' in src),
        # 최종 검수 10/14 A: '70% gives' is words, not a '% g' slot (no space flag, both sides)
        ("'70% gives +1' has no slot (Python form)", roblox_form("Enhance Scroll: 70% gives +1")[1] == []),
        # (2): the registered module word tables are in the list under their registered keys
        ("the format list reads the modules' registered word tables (HUD.TXT, EventHUD.TXT, PauseCard.T.Text)",
         module_keys() >= {"HUD.TXT.QuestHeader", "HUD.TXT.QuestHeaderTouch", "EventHUD.TXT.GooseNext", "PauseCard.T.Text.BackNext",
                           "SkillBar.TXT.NewSkill", "CraftWindow.TXT.Power"}),
    ] + first_minutes()


SPS_DIR = ROOT / "src/StarterPlayer/StarterPlayerScripts"


def module_keys() -> set[str]:
    try:  # every row the format list writes (moved tables keep their registered path: Config.ClientText rows renamed)
        from l10n_format_keys import rows
        return {r["key"] for r in rows()} | {k for k, _ in module_rows()[0]}
    except Exception:  # noqa: BLE001
        return set()


def first_minutes() -> list[tuple[str, bool]]:
    """최종 검수 10/14 (1): the first-10-minute screens put their %-sentences through the table by key (L.Tx / trx ->
    UIKit.Tx -> UIKit.Tr), and their word tables have key paths"""
    def read(name: str) -> str:
        p = SPS_DIR / name
        return p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") if p.exists() else ""
    hud, ev, ds = read("HUD.luau"), read("EventHUD.luau"), read("DeathScreen.luau")
    sb, fs, pc = read("SkillBar.luau"), read("FirstSteps.luau"), read("PauseCard.luau")
    plain = re.compile(r"string\.format\((?:TXT|T\.Text)\.\w+")
    return [
        ("HUD: no %-sentence of its words by plain string.format; HUD.TXT registered; goal chips by key",
         not plain.search(hud) and 'UIKit.L10n.Register("HUD.TXT", TXT)' in hud and "function L.Tx(t, key, ...)" in hud
         and 'fmt("Next", best.Text)' in hud and 'fmt("Big", sideWord)' in hud),
        ("EventHUD: its sentences by key (L.Tx), EventHUD.TXT registered",
         not plain.search(ev) and 'C.UIKit.L10n.Register("EventHUD.TXT", TXT)' in ev),
        ("KO screen: cause / lost / back / 'This run' by key (Config.Death.Text)",
         "out.Cause = f and trx(TX, by, name) or nil" in ds and 'trx(TX, "Respawn"' in ds and "trx(TX, key," in ds),
        ("skill bar, first steps, pause cards: by key, their tables registered",
         not plain.search(sb) and not plain.search(fs) and not plain.search(pc)
         and 'Register("SkillBar.TXT", TXT)' in sb and 'Register("FirstSteps.TXT", TXT)' in fs
         and 'Register("PauseCard.T.Text", T.Text)' in pc),
    ]


def goal_cut() -> str:
    hud = (SPS_DIR / "HUD.luau").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    return cut(hud, "function L.GoalTiers(", "\nend\n", keep_end=True)


def run(src: str) -> tuple[int, int, str]:
    part, tx = cut(src, *CUT), cut(src, *TX_CUT, keep_end=True)
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "ui_tr.luau"
        p.write_text("local PART = " + lua_str(part) + "\nlocal TX = " + lua_str(tx) + "\nlocal GOAL = " + lua_str(goal_cut()) + "\n" + samples_lua() + FIXTURE, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"UI_TR_SUMMARY checks=(\d+) failed=(\d+)", out)
    st = statics(src)
    out += "".join(("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + n for n, ok in st)
    return (int(m[1]) if m else 0) + len(st), (int(m[2]) if m else 1) + sum(1 for _, ok in st if not ok), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = FILE.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    found = cut(src, *CUT) != "" and cut(src, *TX_CUT, keep_end=True) != ""
    checks, failed, out = run(src)
    print(out.strip())
    muts = []
    for name, old, new in MUTATIONS:
        hits = src.count(old)
        caught = False
        if hits == 1:
            caught = run(src.replace(old, new))[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    ok = found and failed == 0 and checks > 5 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Extracted")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
