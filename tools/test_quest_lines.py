"""HUD quest lines offline check (SPEC A23-81: the lines on the left show only quests in progress, at most
Config.QuestTabs.HudLines, the main one first, name + 3/5 without cut words; a pressed quest becomes the marker's).

Extracts the A23-81 helper block of the CURRENT src/StarterPlayer/StarterPlayerScripts/HUD.luau (L.QuestLines,
L.HasQuestBook, L.EntryKey, L.QuestLineOrder, L.TrackDone) and HUD.QuestTarget / HUD.QuestCanClaim / HUD.QuestCanReroll /
HUD.QuestGo, and runs them with the installed official Luau CLI (build/luau_cli_0_741) against small doubles. Static: the
lines are built for L.QuestLines(), the block grows by one line height per extra line, every device shows the server's
short name, refreshQuests orders the lines with L.QuestLineOrder and draws no 'Daily Quests 0/3' filler line, a HUD line
that is no claim / guide / story row asks HUD.QuestGo. Mutations: in-memory copies with one rule broken each; each must
make a check fail. Status "passed" only when the checks pass, the static checks pass AND every mutation was applied and
caught. Report: docs/art/verification_2026-10-08/offline_quest_lines_2026-10-08.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
HUD = ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-08/offline_quest_lines_2026-10-08.json"

FIXTURE = r"""
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if not ok then failed += 1; print(("CHECK_FAIL %s :: %s"):format(name, tostring(detail or ""))) end
end
local Config = { QuestTabs = { HudLines = 3 } }
local IS_TOUCH = false
local QUEST_ICON = { tutorial = "IconMonSlime", Gold = "IconCoin" }
function Config.QuestTab(id, kind)
	if id == "story:H2" then return "Faction" end
	return ({ Tutorial = "Main", Main = "Main", Sub = "Side", Job = "Side", Daily = "Daily", Extra = "Daily" })[kind] or "Side"
end
Config.Quests = { Templates = {
	{ Id = "Kill", ShortName = "Monster hunt", Text = "Defeat %s ×%d" },
	{ Id = "Gold", ShortName = "Earn gold", Text = "Earn %s gold by hunting" },
	{ Id = "Plunder", ShortName = "Rob Knights", Text = "Rob %d Knights of Light" },
} }
Config.MonsterTypes = { Slime = { Name = "Green Slime", Short = "Slime" }, Goblin = { Name = "Goblin" } }
Config.PluralWords = { ["Knights"] = "Knight" }
function Config.Plural(text)
	for many, one in Config.PluralWords do text = string.gsub(text, "%f[%d]1 " .. many, "1 " .. one) end
	return text
end
local questState = { Rows = nil, Shown = 1 }
local questRows = {}
local C = {}
local L, HUD = {}, {}
local PINNED, GUIDES = {}, 0
L.PinnedTap = function(e) table.insert(PINNED, e) end
local function refreshGuides() GUIDES += 1 end
local function attr(_, d) return d end
local function getFaction() return "Halo" end
HELPERS
FUNCS
local function e(id, slot, p, t, extra)
	local r = { Id = id, Slot = slot, Progress = p or 0, Target = t or 1, CanClaim = true, Kind = "Daily", Text = id }
	for k, v in extra or {} do r[k] = v end
	return r
end
-- L.QuestLines
check("three lines (Config.QuestTabs.HudLines)", L.QuestLines() == 3)
Config.QuestTabs.HudLines = 9
check("never more than five", L.QuestLines() == 5)
Config.QuestTabs = nil
check("no table: the old two lines", L.QuestLines() == 2)
Config.QuestTabs = { HudLines = 3 }
-- L.HasQuestBook
check("no quest window module: false", L.HasQuestBook() == false)
C.QuestBook = { Toggle = function() end, IsReady = function() return true end }
check("a ready quest window: true", L.HasQuestBook() == true)
C.QuestBook.IsReady = function() return false end
check("a window that did not register: false", L.HasQuestBook() == false)
-- L.QuestLineOrder
local entries = { e("main", nil), e("s1", nil), e("kill", 1), e("gold", 2), e("job", nil) }
local o = L.QuestLineOrder(entries, 1, { 4, nil, 4, 2 })
check("first the 'now do' row, then the preferred ones, then the rest in order (no repeats)",
	table.concat(o, ",") == "1,4,2,3,5", table.concat(o, ","))
o = L.QuestLineOrder(entries, 3, { 9, 3 })
check("a missing or repeated preferred index is skipped", table.concat(o, ",") == "3,1,2,4,5", table.concat(o, ","))
check("no entries: no lines", #L.QuestLineOrder({}, 1, {}) == 0)
-- L.EntryKey
check("a slot's key changes with its template", L.EntryKey(e("kill", 1)) ~= L.EntryKey(e("gold", 1)) and L.EntryKey(e("kill", 1)) == "kill|1")
-- L.TrackDone
questState.DoneSession = nil
local old = { e("kill", 1, 5, 5), e("gold", 2, 10, 50), e("story:S3", nil, 1, 1, { Kind = "Sub" }), e("tip", nil, 1, 1, { NextGoal = true }),
	e("plunder", 3, 0, 3) } -- slot 3 was rerolled (left unfinished)
local new = { e("hunt", 1, 0, 3), e("gold", 2, 12, 50) }
L.TrackDone(old, new)
local ids = {}
for _, d in questState.DoneSession do table.insert(ids, d.Id) end
check("a claimable quest that left the list is done; a rerolled unfinished one is not; a next-goal row never",
	table.concat(ids, ",") == "kill,story:S3", table.concat(ids, ","))
L.TrackDone(old, new)
check("the same quest is not listed twice", #questState.DoneSession == 2, #questState.DoneSession)
for i = 1, 45 do L.TrackDone({ e("q" .. i, 1, 1, 1) }, {}) end
check("the session list keeps the newest 40", #questState.DoneSession == 40 and questState.DoneSession[40].Id == "q45", #questState.DoneSession)
L.TrackDone(nil, new)
check("no previous list: nothing happens", #questState.DoneSession == 40)
-- the claim / reroll rules
check("[Claim]: finished daily / sub / pinned only", HUD.QuestCanClaim(e("kill", 1, 5, 5)) and HUD.QuestCanClaim(e("s", nil, 1, 1, { Kind = "Sub" }))
	and HUD.QuestCanClaim(e("t", nil, 1, 1, { Kind = "Tutorial", Pinned = true })) and not HUD.QuestCanClaim(e("j", nil, 2, 2, { Kind = "Job" }))
	and not HUD.QuestCanClaim(e("kill", 1, 4, 5)))
check("[New]: an unfinished slot only", HUD.QuestCanReroll(e("kill", 1, 4, 5)) and not HUD.QuestCanReroll(e("kill", 1, 5, 5))
	and not HUD.QuestCanReroll(e("s", nil, 0, 1, { Kind = "Sub" })) and not HUD.QuestCanReroll(e("m", 1, 0, 1, { Pinned = true })))
-- HUD.QuestGo + HUD.QuestTarget
local TARGETS = {}
C.QuestTarget = { ForEntry = function(en) table.insert(TARGETS, en.Id) return { Id = en.Id } end }
local rows = { e("main", nil, 0, 1, { Pinned = true, Kind = "Main", Story = { Id = "M1_1" } }), e("kill", 1, 1, 5), e("gold", 2, 1, 50) }
questState.Rows, questState.Shown = rows, 1
check("no pressed quest: the marker follows the 'now do' row", HUD.QuestTarget().Id == "main")
HUD.QuestGo(rows[1])
check("a story / guide row runs its own action (L.PinnedTap), not the marker", PINNED[1] == rows[1] and questState.GuideKey == nil)
HUD.QuestGo(rows[3])
check("any other quest becomes the marker's quest", questState.GuideKey == "gold|2" and HUD.QuestTarget().Id == "gold" and GUIDES == 1)
questState.Rows = { rows[1], rows[2] }
check("when that quest leaves the list the marker goes back to the 'now do' row", HUD.QuestTarget().Id == "main" and questState.GuideKey == nil)
check("QuestGo without a quest: false", HUD.QuestGo(nil) == false)
-- 검수 10/08: a daily / extra slot saved before A23-48 keeps Korean words; the screen writes it again in English
local KO = "\235\185\155\236\157\152 \234\184\176\236\130\172\235\139\168 1\235\170\133 \237\132\184\234\184\176" -- "빛의 기사단 1명 털기"
check("an old Korean Plunder daily is shown in English (count, then Config.Plural)",
	L.EnglishQuestText(e("Plunder", 1, 0, 1, { Text = KO }), KO) == "Rob 1 Knight of Light", L.EnglishQuestText(e("Plunder", 1, 0, 1), KO))
check("a Kill row names its monster by its short name (else its name)",
	L.EnglishQuestText(e("Kill", 2, 0, 50, { Unit = "Slime" }), KO) == "Defeat Slime ×50"
	and L.EnglishQuestText(e("Kill", 2, 0, 3, { Unit = "Goblin" }), KO) == "Defeat Goblin ×3",
	L.EnglishQuestText(e("Kill", 2, 0, 50, { Unit = "Slime" }), KO))
check("a Gold row shows the plain number", L.EnglishQuestText(e("Gold", 3, 0, 60), KO) == "Earn 60 gold by hunting",
	L.EnglishQuestText(e("Gold", 3, 0, 60), KO))
check("an extra slot is written again too", L.EnglishQuestText(e("Gold", 4, 0, 50, { Kind = "Extra" }), KO) == "Earn 50 gold by hunting")
check("a Kill row whose monster is unknown keeps the server's text", L.EnglishQuestText(e("Kill", 2, 0, 5, { Unit = "Nope" }), "keep") == "keep")
check("story / tutorial / job rows and unknown templates keep the server's text",
	L.EnglishQuestText(e("Gold", nil, 0, 1, { Kind = "Sub" }), "Sub text") == "Sub text"
	and L.EnglishQuestText(e("Tutorial", 1, 0, 1), "First mission") == "First mission"
	and L.EnglishQuestText(e("Plunder", 1, 0, 1, { Target = "?" }), "no target") == "no target")
check("a daily's short name comes from its English template", L.EnglishShortName(e("Plunder", 1, 0, 1, { ShortName = KO })) == "Rob Knights"
	and L.EnglishShortName(e("x", nil, 0, 1, { Kind = "Job", ShortName = "Board" })) == "Board"
	and L.EnglishShortName(e("x", nil, 0, 1, { Kind = "Job" })) == nil)
-- 검수 10/08 (the user's photo: a finished line showed only its icon and [Claim]): a finished line = its name + Done!;
-- the pill only where a press claims it (PC every line, phones line 1)
local fin = e("kill", 1, 5, 5, { Kind = "Daily" })
local c1, p1 = L.LineFinish(fin, 2)
check("PC: a finished daily on line 2 is claimable with its pill", c1 == true and p1 == true)
IS_TOUCH = true
local c2, p2 = L.LineFinish(fin, 2)
local c3, p3 = L.LineFinish(fin, 1)
check("phones: line 2 says Done! without a pill (the block's tap claims line 1), line 1 keeps it", c2 == true and p2 == false
	and c3 == true and p3 == true)
IS_TOUCH = false
check("unfinished / a board job / no quest: not claimable", not L.LineFinish(e("kill", 1, 4, 5), 1)
	and not L.LineFinish(e("job", nil, 2, 2, { Kind = "Job" }), 1) and not L.LineFinish(nil, 1)
	and not L.LineFinish(e("kill", 1, 5, 5, { CanClaim = false }), 1))
check("a finished story step and the pinned first mission are claimable", L.LineFinish(e("story:S3", nil, 1, 1, { Kind = "Sub" }), 1)
	and L.LineFinish(e("tutorial", nil, 5, 5, { Kind = "Tutorial", Pinned = true }), 1))
-- the line icon: the quest's tab icon first, then the monster head, the row type's icon, the scroll
local keys = L.LineIconKeys(e("kill", 1, 0, 5, { Unit = "Slime" }))
check("a kill daily: the Daily tab icon, then the slime head, then the scroll", keys[1] == "QuestTabIconDaily" and keys[2] == "IconMonSlime"
	and keys[#keys] == "IconScroll", table.concat(keys, ","))
keys = L.LineIconKeys(e("story:H2", nil, 0, 1, { Kind = "Sub" }))
check("a Halo story: the Faction tab icon", keys[1] == "QuestTabIconFaction", table.concat(keys, ","))
keys = L.LineIconKeys(e("tutorial", nil, 0, 5, { Kind = "Tutorial" }))
check("the first mission: the Main tab icon, then its own slime icon", keys[1] == "QuestTabIconMain" and keys[2] == "IconMonSlime",
	table.concat(keys, ","))
check("no quest: the star", L.LineIconKeys(nil)[1] == "IconStar")
print(("QUEST_LINES_SUMMARY checks=%d failed=%d"):format(checks, failed))
"""

MUTATIONS = [
    # A23-99 추가 (2026-10-10): the head line 'Quests (N) ▼' is gone
    ("the head line shows again", "ui.questHead.Frame.Visible = L.QuestHeadOn() and #entries > 0",
     "ui.questHead.Frame.Visible = #entries > 0"),
    ("the lines keep a gap for the gone head line", "local hh = (ui.questHead and L.QuestHeadOn()) and math.floor(lh * 0.75) or 0",
     "local hh = ui.questHead and math.floor(lh * 0.75) or 0"),
    ("lines never capped", "\treturn math.clamp(math.floor(tonumber(type(qt) == \"table\" and qt.HudLines) or 2), 1, 5)\n",
     "\treturn math.floor(tonumber(type(qt) == \"table\" and qt.HudLines) or 2)\n"),
    ("the 'now do' row not first", "\tadd(first)\n\tfor k = 1, 5 do add(prefer[k]) end\n", "\tfor k = 1, 5 do add(prefer[k]) end\n\tadd(first)\n"),
    ("repeats allowed", "\t\tif type(i) == \"number\" and entries[i] and not seen[i] then\n", "\t\tif type(i) == \"number\" and entries[i] then\n"),
    ("unfinished quests counted done", "\t\tif e.Progress >= e.Target and e.CanClaim and not now[L.EntryKey(e)] and not e.NextGoal then\n",
     "\t\tif not now[L.EntryKey(e)] and not e.NextGoal then\n"),
    ("next-goal rows counted done", "and not now[L.EntryKey(e)] and not e.NextGoal then\n", "and not now[L.EntryKey(e)] then\n"),
    ("done listed twice", "\t\t\tif not dup then\n", "\t\t\tif true then\n"),
    ("the session list grows forever", "\t\t\t\tif #questState.DoneSession > 40 then table.remove(questState.DoneSession, 1) end\n", ""),
    ("a slot keeps its key when its template changes", "\treturn tostring(e.Id) .. \"|\" .. tostring(e.Slot)\n", "\treturn tostring(e.Slot)\n"),
    ("the window counted ready before it registered",
     "\treturn type(qb) == \"table\" and type(qb.Toggle) == \"function\" and type(qb.IsReady) == \"function\" and qb.IsReady() == true\n",
     "\treturn type(qb) == \"table\" and type(qb.Toggle) == \"function\"\n"),
    ("a pressed quest never leads", "\tquestState.GuideKey = L.EntryKey(e)\n\tpcall(refreshGuides)\n", "\tpcall(refreshGuides)\n"),
    ("a story row loses its own action", "\tif (e.Pinned or e.Story) and L.PinnedTap then\n\t\tL.PinnedTap(e)\n\t\treturn true\n\tend\n", ""),
    ("a gone quest keeps the marker", "\t\tif not e then questState.GuideKey = nil end\n", ""),
    ("[Claim] on a board job", "\t\tand (e.Pinned == true or e.Kind == \"Daily\" or e.Kind == \"Sub\")\n", "\n"),
    ("a finished line's pill everywhere on phones", "\treturn claimable, claimable and (not IS_TOUCH or li == 1)\n", "\treturn claimable, claimable\n"),
    ("no pill on PC lines 2+", "\treturn claimable, claimable and (not IS_TOUCH or li == 1)\n", "\treturn claimable, claimable and li == 1\n"),
    ("a line that is not finished claims", "\t\tand e.Progress >= e.Target and e.CanClaim == true\n", "\t\tand e.CanClaim == true\n"),
    ("no tab icon", "\tif ok and type(tab) == \"string\" then table.insert(keys, \"QuestTabIcon\" .. tab) end\n", ""),
    ("the monster head before the tab icon", "\tif e.Unit then table.insert(keys, \"IconMon\" .. tostring(e.Unit)) end\n",
     "\tif e.Unit then table.insert(keys, 1, \"IconMon\" .. tostring(e.Unit)) end\n"),
    ("saved daily words trusted", "\tif type(e) ~= \"table\" or (e.Kind ~= \"Daily\" and e.Kind ~= \"Extra\") then return text end\n",
     "\tif true then return text end\n"),
    ("extra slots keep saved words", "\tif type(e) ~= \"table\" or (e.Kind ~= \"Daily\" and e.Kind ~= \"Extra\") then return text end\n",
     "\tif type(e) ~= \"table\" or e.Kind ~= \"Daily\" then return text end\n"),
    ("every row written again", "\tif type(e) ~= \"table\" or (e.Kind ~= \"Daily\" and e.Kind ~= \"Extra\") then return text end\n",
     "\tif type(e) ~= \"table\" then return text end\n"),
    ("Kill shows the long name", "local name = type(def) == \"table\" and (def.Short or def.Name) or nil\n",
     "local name = type(def) == \"table\" and def.Name or nil\n"),
    ("no Config.Plural", "\t\tif okP and type(plural) == \"string\" then out = plural end\n", ""),
    ("Gold shows 60.0", "ok, out = pcall(string.format, t.Text, tostring(math.floor(target)))\n",
     "ok, out = pcall(string.format, t.Text, tostring(target + 0.0) .. \".0\")\n"),
    ("short name from the saved row", "\t\tif t and type(t.ShortName) == \"string\" and t.ShortName ~= \"\" then return t.ShortName end\n", ""),
]


def extract(src):
    helpers = re.search(r"\n(-{20,} A23-81 quest lines / window helpers\n.*?)\n-{20,} building: quest lines", src, re.S)
    funcs = []
    for name in ("HUD.QuestTarget", "HUD.QuestCanClaim", "HUD.QuestCanReroll", "HUD.QuestGo"):
        m = re.search(r"\nfunction " + re.escape(name) + r"\(.*?\nend\n", src, re.S)
        funcs.append(m[0] if m else "")
    return (helpers[1] if helpers else ""), "\n".join(funcs)


def run(src: str, name: str):
    helpers, funcs = extract(src)
    path = ROOT / f"build/quest_lines_offline{name}.luau"
    path.write_text(FIXTURE.replace("HELPERS", helpers).replace("FUNCS", funcs), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"QUEST_LINES_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = bool(helpers) and result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def static_checks(src):
    build = src[src.find("function L.BuildQuestLines(root)"):src.find("function L.LayoutQuestLines(q)")]
    layout = src[src.find("function L.LayoutQuestLines(q)"):src.find("function L.FitQuestLine(l)")]
    setline = src[src.find("function L.SetQuestLine(l, e, label, nums)"):src.find("function L.QuestLineTap(i)")]
    tap = src[src.find("function L.QuestLineTap(i)"):src.find("function L.QuestBlockTap()")]
    fit = src[src.find("function L.FitQuestLine(l)"):src.find("function L.SetQuestLine(l, e, label, nums)")]
    refresh = src[src.find("refreshQuests = function()"):src.find("toggleQuests = function(open)")]
    full = src
    glow = full[full.find("local function makeGlow(parent, radius)"):full.find("-- the shared press feel")]
    pulse = full[full.find("local callTarget = nil"):full.find("L.SetStoryPulse(callTarget)")]
    # every child the builder parents to a quest row (Parent = row): only the four line parts
    row_children = re.findall(r'Name = "(\w+)",[^\n]*\n(?:[^\n]*\n){0,8}?\s*Parent = row,', build)
    return [
        ("검수 10/09 story line: its pulse goes round the line's plate (else band), never the row (a list)",
         "callTarget = L.LineGlowTarget(l)" in pulse and "callTarget = l.Row" not in pulse
         and "\treturn l.Plate or l.Band\n" in full),
        ("검수 10/09: makeGlow never puts its frame inside a list / grid (it would be one more list item)",
         'if typeof(parent) ~= "Instance" or parent:FindFirstChildWhichIsA("UIGridStyleLayout") then return nil end' in glow),
        ("every line kind (plain / claim / story call / Done!) has the same row: icon, words, numbers, claim pill only",
         sorted(row_children) == ["Claim", "Icon", "Nums", "Text"]),
        ("검수 10/09: a re-fit lays the plates out again (once a frame)", "\t\t\tL.LayoutQuestPlates()\n" in fit
         and "\tif not L.PlatesQueued then\n" in fit),
        ("the lines are built for L.QuestLines()", "local n = L.QuestLines()" in build and "for i = 1, n do" in build
         and "Size = UDim2.new(1, 0, 1 / n, 0)," in build),
        ("the block grows one line height per extra line", "block.Size = UDim2.fromOffset(q.W, lh * L.QuestLines())" in layout),
        ("every device shows the server's short name (no cut words)",
         "if e and e.ShortName and label == e.Text then label = e.ShortName end" in setline and "IS_TOUCH and e and e.ShortName" not in setline),
        ("refreshQuests orders the lines with L.QuestLineOrder (main first)",
         "local order = L.QuestLineOrder(entries, shown, { callIndex, second, firstClaim, s0, firstDaily })" in refresh),
        ("no 'Daily Quests 0/3' filler on lines 2+", "if li == 1 and not label then label = head end" in refresh
         and "L.SetQuestLine(ui.qline[2], e2, l2 or head, n2)" not in refresh),
        ("a HUD line that is no claim / guide / story row asks HUD.QuestGo", "elseif HUD.QuestGo then\n\t\tHUD.QuestGo(e)" in tap),
        ("the 'Done this session' list follows every redraw (every row, the window's More rows too: #19)",
         "L.TrackDone(questState.All or questState.Rows, all)" in refresh),
        ("a daily / extra row's words + short name come from the English template (an old save may hold Korean)",
         "Text = L.QuestText(L.EnglishQuestText(e, tostring(e.Text or \"\")))," in src
         and "ShortName = L.EnglishShortName(e)," in src),
        ("a finished line keeps its name + Done! (SetQuestLine uses L.LineFinish / L.LineIconKeys)",
         "local claimable, pill = L.LineFinish(e, li)" in setline and "l.Nums.Text = claimable and TXT.QuestDone or (nums or \"\")" in setline
         and "for _, key in L.LineIconKeys(e) do" in setline and 'QuestDone = "Done!",' in src),
        ("the ▼ sits on the head line 'Quests (N)' over the lines, not beside line 1",
         'QuestHead = "Quests (%d)",' in src and "Parent = headRow," in build and "Parent = ui.qline[1].Row," not in src
         and 'ui.questHead.Text.Text = L.Tx(TXT, "QuestHead", #all)' in refresh  # 10/14: by key (UIKit.Tr)
         and "block.Position = UDim2.fromOffset(q.X, q.Y + hh)" in layout),
        # A23-99 추가 (user 2026-10-10 photo "이거 없애달라니까"): the head line is off - no frame, no height, no gap
        ("A23-99: the head line 'Quests (N) ▼' is gone (Config.Nudges.QuestHead = false) and leaves no gap",
         "\tQuestHead = false,\n" in (ROOT / "src/ReplicatedStorage/Shared/Config.luau").read_text(encoding="utf-8-sig")
         and "ui.questHead.Frame.Visible = L.QuestHeadOn() and #entries > 0" in refresh
         and "local hh = (ui.questHead and L.QuestHeadOn()) and math.floor(lh * 0.75) or 0" in layout
         and "local hh = ui.questHead.Frame.Visible and ui.questHead.Frame.Size.Y.Offset or 0" in src
         and "\treturn (Config.Nudges or {}).QuestHead == true\n" in src),
        ("the words get their own width (no flex shrink that squeezed a finished line's name to nothing)",
         "UIFlexItem" not in build and "l.Text.Size = UDim2.new(0, math.max(1, math.min(math.ceil(w) + 2, math.floor(avail))), 1, 0)" in fit),
        ("the quest list may come as { Quests, Book } (a table or JSON): rows + the window's book",
         "payload = data -- a JSON payload is read like a table payload below" in src
         and 'if type(payload) == "table" and type(payload.Quests) == "table" then' in src
         and "if type(payload.Book) == \"table\" then questState.Book = payload.Book end\n" in src
         and "\t\tdata = payload.Quests" in src),
        ("검수 10/10 API review ①: the phone's claim line counts only the rows the block shows (entries)",
         "		claimable, hot = ready, ready > 0" in src),
        ("검수 10/10 API review ③: the tracker keeps room for the head line only while it shows",
         "+ (L.QuestHeadOn() and math.floor(lh * 0.75) or 0) + 8" in src),
        ("A23-104: the payload's DailyLocked is kept for the quest window (HUD.DailyLocked)",
         "questState.DailyLocked = payload.DailyLocked == true" in src and "function HUD.DailyLocked()" in src),
    ]


def main():
    src = HUD.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(src, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    static = static_checks(src)
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    rows = []
    for name, old, new in MUTATIONS:
        applied = src.count(old) == 1
        caught, why = False, []
        if applied:
            mutated = src.replace(old, new)
            m_ok, _, why, _ = run(mutated, "_mut")
            # a static check failing on the mutated source catches it too (the head line rules are text checks)
            caught = not m_ok or not all(g for _, g in static_checks(mutated))
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    passed = ok and all(g for _, g in static) and all(r["applied"] and r["caught"] for r in rows)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {HUD.relative_to(ROOT).as_posix(): hashlib.sha256(HUD.read_bytes()).hexdigest()},
              "studioCalls": 0,
              "limitations": "Extracted functions + the code's text: how three lines sit under the minimap on PC and phone is "
                             "a Studio photo (메인 반영) and the quest rect's size is 이미지 개발's HudLayout."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
