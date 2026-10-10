"""A23-14 rookie dailies, golden goose co-op and the free class change below Lv5, run offline.

Runs the CURRENT Config, DataService, QuestService, GooseService and ClassService sources (injected into
tools/fixtures/a23_14_offline.luau) with the installed official Luau CLI (build/luau_cli_0_741). No Studio, network,
DataStore or Roblox API calls. Every check is named and collected. A mutation step then breaks in-memory copies of the
sources (never src/), runs them from a temporary directory and counts how many mutations the checks catch.

Usage: py tools/test_a23_14.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_a23_14_2026-10-06.json
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
FIXTURE = ROOT / "tools/fixtures/a23_14_offline.luau"
OUT = ROOT / "docs/art/verification_2026-10-06/offline_a23_14_2026-10-06.json"
FILES = {
    "CONFIG_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
    "NET_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Net.luau",
    "DATA_SOURCE": ROOT / "src/ServerScriptService/DataService.luau",
    "QUEST_SOURCE": ROOT / "src/ServerScriptService/QuestService.luau",
    "GOOSE_SOURCE": ROOT / "src/ServerScriptService/GooseService.luau",
    "CLASS_SOURCE": ROOT / "src/ServerScriptService/ClassService.luau",
}
STATIC_ONLY = {
    "CLASS_PICKER": ROOT / "src/StarterPlayer/StarterPlayerScripts/ClassPicker.luau",
    "PANELS": ROOT / "src/StarterPlayer/StarterPlayerScripts/Panels.luau",
    "EVENT_HUD": ROOT / "src/StarterPlayer/StarterPlayerScripts/EventHUD.luau",
}

# (name, source key, exact text, replacement): each must match exactly once in the current source
MUTATIONS = [
    # A23-71 (user 2026-10-07): no skill before Lv5
    ("A23-71: a skill daily before the first skill", "QUEST_SOURCE",
     "return t.Id ~= \"Release\" or (data ~= nil and Config.SkillLearned(data.SkillSlots, data.Level, data.Rebirths))",
     "return true"),
    ("A23-71: an old skill daily is kept at join", "QUEST_SOURCE",
     "\tremakeUnfit(player, data, getFaction(player)) -- A23-71: a skill daily kept from before the Lv5 rule\n", ""),
    ("A23-71: a remade daily loses its reward", "QUEST_SOURCE",
     "\t\t\t\tnq.RewardGold = math.max(nq.RewardGold, math.floor(num(q.RewardGold)))\n", ""),
    ("A23-71: a finished skill daily is remade too", "QUEST_SOURCE",
     "if isValidQuest(q) and not isComplete(q) and not templateFitsNow(", "if isValidQuest(q) and not templateFitsNow("),
    ("A23-71: old saves keep their slots", "DATA_SOURCE", "\t\tif d.SkillsA71 ~= true then\n", "\t\tif false then\n"),
    ("A23-71: the save fix runs every join", "DATA_SOURCE", "\t\tif d.SkillsA71 ~= true then\n", "\t\tif true then\n"),
    ("A23-71: SkillLearned ignores the saved slots", "CONFIG_SOURCE",
     "return (tonumber(slots) or 0) >= 1 or Config.SkillSlotsFor(level, rebirths) >= 1",
     "return Config.SkillSlotsFor(level, rebirths) >= 1"),
    ("A23-71: SkillLearned ignores the level", "CONFIG_SOURCE",
     "return (tonumber(slots) or 0) >= 1 or Config.SkillSlotsFor(level, rebirths) >= 1", "return (tonumber(slots) or 0) >= 1"),
    ("quest rows lose the template's ShortName", "QUEST_SOURCE",
     "\t\t\t\t\tShortName = tpl and tpl.ShortName or nil, -- 검수 2026-10-07: the phone HUD quest row\n", ""),
    ("newbie daily pays the 5-minute reward", "QUEST_SOURCE",
     "rewardGold, rewardXP = Config.HuntValue(level, num(NEWBIE.RewardMinutes, Config.Daily.QuestMinutes))",
     "rewardGold, rewardXP = Config.DailyQuestReward(level)"),
    ("newbie band includes Lv10", "QUEST_SOURCE",
     "and level <= num(NEWBIE.MaxLevel, 0)", "and level <= num(NEWBIE.MaxLevel, 0) + 1"),
    ("strict king-slime row counts slimes as fractions", "QUEST_SOURCE",
     "if strict and w < 1 then return 0 end", ""),
    ("newbie chest pays the Lv10+ chest", "QUEST_SOURCE",
     "return Config.HuntValue(level, num(NEWBIE.ChestMinutes, Config.Daily.ChestMinutes))",
     "return Config.DailyChestReward(level)"),
    ("chest ignores the generation band", "QUEST_SOURCE",
     "if genLevel >= 1 and genLevel ~= level then", "if false then"),
    ("newbie rows allow a repeated goal", "QUEST_SOURCE",
     "if not otherIds[row.Id] then", "if true then"),
    # A23-71 S9 / D3: with no skill row, the third Lv1-4 daily is the other monster's Kill row
    ("S9: the third rookie row may repeat the King Slime", "QUEST_SOURCE",
     "local pool = (#preferred > 0 and preferred) or (#otherUnit > 0 and otherUnit) or candidates",
     "local pool = (#preferred > 0 and preferred) or candidates"),
    ("S9: rows compared by template only", "QUEST_SOURCE",
     "otherKeys[q.Id .. \"|\" .. tostring(q.Unit)] = true", "otherKeys[q.Id] = true"),
    ("S9: a band row's unit ignored", "QUEST_SOURCE",
     "if band and type(row.Monster) == \"string\" and type(Config.MonsterTypes[row.Monster]) == \"table\" then return row.Monster end",
     "if false then return row.Monster end"),
    ("vacation uses the Lv10+ day value", "CONFIG_SOURCE",
     "local g, x = Config.HuntValue(level, Config.DailyDayMinutes(level))",
     "local g, x = Config.HuntValue(level, Config.Daily.QuestMinutes * Config.Quests.Slots + Config.Daily.ChestMinutes)"),
    ("co-op success pays 100%", "GOOSE_SOURCE",
     "local share = (judged == \"Coop\" and success) and (tonumber(Config.Goose.CoopWinShare) or 0.7) or nil",
     "local share = nil"),
    ("daily gate: the jobs are always open", "QUEST_SOURCE", "\tif type(D) ~= \"table\" or D.IntroGate ~= true then return true end\n", "\treturn true\n"),
    ("daily gate: the intro flag does not open them", "QUEST_SOURCE", "\treturn data.DailyIntro == true or num(data.DailyDay) > 0\n", "\treturn num(data.DailyDay) > 0\n"),
    ("daily gate: an old save is locked", "QUEST_SOURCE", "\treturn data.DailyIntro == true or num(data.DailyDay) > 0\n", "\treturn data.DailyIntro == true\n"),
    ("daily gate: a new save is open", "QUEST_SOURCE", "\treturn data.DailyIntro == true or num(data.DailyDay) > 0\n", "\treturn true\n"),
    ("daily gate: join makes the set anyway", "QUEST_SOURCE", "\tif dailiesOpen(data) then\n\t\t-- a save that already runs its dailies never gets the intro quest (A23-104)",
     "\tif true then\n\t\t-- a save that already runs its dailies never gets the intro quest (A23-104)"),
    ("daily gate: the day check makes sets anyway", "QUEST_SOURCE", "\tif not data or not dailiesOpen(data) then return end\n\tlocal today", "\tif not data then return end\n\tlocal today"),
    ("daily gate: locked kills count", "QUEST_SOURCE", "\tif not data or not dailiesOpen(data) or type(data.Quests) ~= \"table\" then return end\n\tlocal quests = data.Quests\n\tfor i = 1, #quests do",
     "\tif not data or type(data.Quests) ~= \"table\" then return end\n\tlocal quests = data.Quests\n\tfor i = 1, #quests do"),
    ("daily gate: a rebirth makes extras", "QUEST_SOURCE", "\tif not dailiesOpen(data) or type(data.Quests) ~= \"table\" then return end\n\tlocal quests = data.Quests\n\tfor i = 1, Config.Quests.Slots do",
     "\tif type(data.Quests) ~= \"table\" then return end\n\tlocal quests = data.Quests\n\tfor i = 1, Config.Quests.Slots do"),
    ("daily gate: the list is not locked", "QUEST_SOURCE", "DailyLocked = locked or nil", "DailyLocked = nil"),
    ("daily gate: the list shows locked jobs", "QUEST_SOURCE", "\tif not locked and type(data.Quests) == \"table\" then", "\tif type(data.Quests) == \"table\" then"),
    ("daily gate: a locked player rerolls an extra", "QUEST_SOURCE", "\tif not data or not dailiesOpen(data) or type(data.Quests) ~= \"table\" then return end -- A23-104: no jobs to reroll yet",
     "\tif not data or type(data.Quests) ~= \"table\" then return end -- A23-104: no jobs to reroll yet"),
    ("daily gate: the absence hook opens them", "QUEST_SOURCE", "\tif not dailiesOpen(getData(player)) then return end -- A23-104: no daily jobs yet, nothing to be away from\n", "\tif not getData(player) then return end\n"),
    ("daily gate: the intro opens nothing", "QUEST_SOURCE", "\tS.PlayerService.SetStat(player, \"DailyIntro\", true)\n", ""),
    ("daily gate: the intro makes no set", "QUEST_SOURCE", "\tS.PlayerService.SetStat(player, \"DailyIntro\", true)\n\tensureSlots(player, data)\n\trunDayCheck(player)\n",
     "\tS.PlayerService.SetStat(player, \"DailyIntro\", true)\n"),
    ("daily gate: the intro signal is not heard", "QUEST_SOURCE", "\tconnectSignal(\"StoryQuestService\", \"QuestDone\", function(player, id)", "\tconnectSignal(\"StoryQuestService\", \"QuestDoneX\", function(player, id)"),
    ("daily gate: any quest opens them", "QUEST_SOURCE", "\t\tif id ~= (Config.Daily and Config.Daily.IntroQuest) then return end\n", ""),
    ("daily gate: an old save gets the intro quest", "QUEST_SOURCE", "\t\tif done and type(intro) == \"string\" then done[intro] = true end\n", ""),
    ("daily gate: config off", "CONFIG_SOURCE", "\tIntroGate = true,", "\tIntroGate = false,"),
    ("daily gate: another intro quest", "CONFIG_SOURCE", "\tIntroQuest = \"D0\",", "\tIntroQuest = \"D1\","),
    ("daily gate: no save default", "CONFIG_SOURCE", "Config.Data.Defaults.DailyIntro = false\n", ""),
    ("daily gate: D0 opens after the second chapter", "CONFIG_SOURCE", "Title = \"Daily Jobs\", ShortName = \"Daily jobs\", Requires = { Done = { \"M1_4\" } },",
     "Title = \"Daily Jobs\", ShortName = \"Daily jobs\", Requires = { Done = { \"M2_3\" } },"),
    ("the first class pick says it again", "CLASS_SOURCE",
     "\tClassService.ClassChanged:Fire(player, classId, old) -- also when equal, so visuals / charge refresh\n",
     "\tClassService.ClassChanged:Fire(player, classId, old) -- also when equal, so visuals / charge refresh\n"
     "\tNet.Notify(player, string.format(\"Your class is now %s!\", Config.ClassName(classId, faction)), \"good\")\n"),
    ("the class pick text is back", "CONFIG_SOURCE", "\tClassChangedFree = \"You changed your class to %s! You start again",
     "\tClassChosen = \"Your class is now %s!\",\n\tClassChangedFree = \"You changed your class to %s! You start again"),
    ("the pay is not reported (HealthService)", "GOOSE_SOURCE",
     "\tGooseService.GooseRewarded:Fire(p, { Won = won, Rare = rare == true, Gold = gold, XP = xp, Level = level,\n\t\tMode = judged == \"Coop\" and \"Coop\" or \"Versus\" })\n",
     ""),
    ("the pay report says Versus for co-op", "GOOSE_SOURCE",
     "Mode = judged == \"Coop\" and \"Coop\" or \"Versus\" })", "Mode = \"Versus\" })"),
    ("the pay report calls a failed co-op Versus", "GOOSE_SOURCE",
     "Mode = judged == \"Coop\" and \"Coop\" or \"Versus\" })", "Mode = share ~= nil and \"Coop\" or \"Versus\" })"),
    ("the pay report always says won", "GOOSE_SOURCE",
     "GooseService.GooseRewarded:Fire(p, { Won = won,", "GooseService.GooseRewarded:Fire(p, { Won = true,"),
    ("co-op gives war points", "GOOSE_SOURCE",
     "if judged == \"Versus\" and result ~= \"Tie\" then", "if result ~= \"Tie\" then"),
    ("co-op target ignores the headcount", "GOOSE_SOURCE",
     "return math.max(1, math.floor(per * math.max(1, people) + 0.5))", "return math.max(1, math.floor(per + 0.5))"),
    ("auto-only players are paid", "GOOSE_SOURCE",
     "if (finalManual[p] or 0) >= MIN_MANUAL_HITS then", "if true then"),
    ("rival pulls during co-op", "GOOSE_SOURCE",
     "if mode == \"Coop\" and f ~= coop.Side then", "if false then"),
    ("no co-op when only one faction is present", "GOOSE_SOURCE",
     "elseif halo > 0 or horns > 0 then\n\t\tmode = \"Coop\"", "elseif false then\n\t\tmode = \"Coop\""),
    ("rival-left tug is a forced tie again", "GOOSE_SOURCE",
     "\t\t\trivalLeft = true\n\t\t\tjudged = \"Coop\"", "\t\t\trivalLeft = true\n\t\t\tjudged = \"Pending\""),
    ("GooseFinished skipped for co-op", "GOOSE_SOURCE",
     "GooseService.GooseFinished:Fire(result, rewarded, info)",
     "if judged ~= \"Coop\" then GooseService.GooseFinished:Fire(result, rewarded, info) end"),
    ("free change below Lv5 resets the level", "CLASS_SOURCE",
     "local keepLevel = freeKeepsLevel(player)", "local keepLevel = false"),
    ("ticket spent below Lv5", "CLASS_SOURCE",
     "if keepLevel then useTicket = false end", ""),
    ("keep-level change fully heals", "CLASS_SOURCE",
     "S.PlayerService.RefreshCharacter(player, not keepLevel)", "S.PlayerService.RefreshCharacter(player, true)"),
    ("keep threshold off by one", "CONFIG_SOURCE",
     "return math.floor(lv) < (tonumber(Config.ClassChange.FreeKeepLevelBelow) or 0)",
     "return math.floor(lv) <= (tonumber(Config.ClassChange.FreeKeepLevelBelow) or 0)"),
    # E12 the Goblin Woods band (quest_volume §3-4)
    ("Lv10-24 gets the template dailies again", "QUEST_SOURCE", "\t\treturn WOODS\n", "\t\treturn nil\n"),
    ("the woods band reaches Lv25", "QUEST_SOURCE", "and level <= num(WOODS.MaxLevel, 0) then",
     "and level <= num(WOODS.MaxLevel, 0) + 1 then"),
    ("a woods daily pays the 5-minute reward", "QUEST_SOURCE",
     "rewardGold, rewardXP = Config.HuntValue(level, num(band.RewardMinutes, Config.Daily.QuestMinutes)) -- E12",
     "rewardGold, rewardXP = Config.DailyQuestReward(level) -- E12"),
    ("the woods chest pays the Lv25 chest", "QUEST_SOURCE",
     "\tif band then return Config.HuntValue(level, num(band.ChestMinutes, Config.Daily.ChestMinutes)) end\n", ""),
    ("woods targets scaled like templates", "QUEST_SOURCE", "\tif t.Id == \"Gold\" and not band then",
     "\tif t.Id == \"Gold\" and not newbie then"),
    ("woods vacation uses the 25-minute day", "CONFIG_SOURCE",
     "\t\treturn (tonumber(wd.RewardMinutes) or Config.Daily.QuestMinutes) * slots\n",
     "\t\treturn Config.Daily.QuestMinutes * slots + Config.Daily.ChestMinutes + 0 * slots\n"),
    ("the brute row is not strict", "CONFIG_SOURCE", 'Monster = "GoblinBrute", Strict = true, Targets = { 2 } },',
     'Monster = "GoblinBrute", Targets = { 2 } },'),
    # (no "vacation share ignores the woods band" mutation: a woods daily is 3 of 15 minutes and a template daily 5 of
    # 25, the same 1/5 share, so the old day's f cannot differ; the paid amount follows Config.DailyDayMinutes, above)
    # E11 the job-board switch (QuestService's side)
    ("the board switch always on", "QUEST_SOURCE",
     "\treturn type(Config.Board) == \"table\" and Config.Board.Enabled == true\n", "\treturn true\n"),
    ("board on: a claimed daily still becomes an extra", "QUEST_SOURCE",
     "\tdata.Quests[slot] = boardOn() and { Kind = \"Empty\" } or newQuest(", "\tdata.Quests[slot] = newQuest("),
    ("board on: the empty slot is listed", "QUEST_SOURCE",
     "\t\t\tif type(q) == \"table\" and not isEmptySlot(q) then\n", "\t\t\tif type(q) == \"table\" then\n"),
    ("board on: an empty slot can be rerolled", "QUEST_SOURCE",
     "\tif boardOn() and not isValidQuest(q) then return end -- E11: an empty slot is never rerolled into an extra\n", ""),
    ("board on: the job rows are not listed", "QUEST_SOURCE",
     "\tif boardOn() and board and type(board.JobRows) == \"function\" then", "\tif false then"),
    ("board on: a finished extra refills its slot", "QUEST_SOURCE",
     "\t\tdata.Quests[index] = boardOn() and { Kind = \"Empty\" } or newQuest(", "\t\tdata.Quests[index] = newQuest("),
    ("board on: a rebirth refills empty slots", "QUEST_SOURCE",
     "\t\t\tquests[i] = boardOn() and { Kind = \"Empty\" } or newQuest(", "\t\t\tquests[i] = newQuest("),
    # A23-113 #8: one daily is not hunting (from Lv10), and the Choice daily
    ("A23-113: no non-hunting daily guarantee", "QUEST_SOURCE", "\tif kind == \"Daily\" and not newbie and level >= num(Config.Quests.NonHuntFrom, 10)",
     "\tif false and kind == \"Daily\" and not newbie and level >= num(Config.Quests.NonHuntFrom, 10)"),
    ("A23-113: the guarantee only from Lv20", "QUEST_SOURCE", "level >= num(Config.Quests.NonHuntFrom, 10)", "level >= 20"),
    ("A23-113: the guarantee on the first slot too", "QUEST_SOURCE",
     "\t\tand otherCount >= math.max(1, num(Config.Quests.Slots, 3) - 1) and not otherNonHunt then", "\t\tand not otherNonHunt then"),
    ("A23-113: another non-hunting slot is forced anyway", "QUEST_SOURCE", " and not otherNonHunt then", " then"),
    ("A23-113: a Choice daily with no source on", "QUEST_SOURCE", "\tif t.Id == \"Choice\" and not choiceOn() then return false end\n", ""),
    ("A23-113: the job board is no choice source", "QUEST_SOURCE", "\tif type(Config.Board) == \"table\" and Config.Board.Enabled == true then return true end\n", ""),
    ("A23-113: the lost things are no choice source", "QUEST_SOURCE", "\tif type(Config.LostFound) == \"table\" and Config.LostFound.Enabled == true then return true end\n", ""),
    ("A23-113: kill cards are no choice source", "QUEST_SOURCE", "if type(card) == \"table\" and card.Enabled ~= false then return true end", "if false then return true end"),
    ("A23-113: a deed never fills the Choice daily", "QUEST_SOURCE",
     "if typeof(player) == \"Instance\" and player:IsA(\"Player\") then addProgress(player, \"Choice\", 1) end", "local _ = player"),
    ("A23-113: a deed fills the goose daily", "QUEST_SOURCE", "addProgress(player, \"Choice\", 1) end", "addProgress(player, \"Goose\", 1) end"),
    ("A23-113 config: Goose is hunting", "CONFIG_SOURCE", "RewardPerUnit = 20, NonHunt = true,\n\t\t\tText = \"Join the Golden Goose", "RewardPerUnit = 20,\n\t\t\tText = \"Join the Golden Goose"),
    ("A23-113 config: Choice is hunting", "CONFIG_SOURCE", "RewardPerUnit = 20, NonHunt = true,\n\t\t\tText = \"Make a kind or sneaky choice\"", "RewardPerUnit = 20,\n\t\t\tText = \"Make a kind or sneaky choice\""),
    ("A23-113 config: the guarantee from Lv30", "CONFIG_SOURCE", "\tNonHuntFrom = 10,", "\tNonHuntFrom = 30,"),
    ("A23-113 config: the woods have no Choice row", "CONFIG_SOURCE",
     "\t\t\t{ Id = \"Choice\", Weight = 3, Targets = { 1 } }, -- A23-113: one kind or sneaky choice (only while a choice source is on)\n", ""),
    ("A23-113 config: the Choice daily needs two choices", "CONFIG_SOURCE", "{ Id = \"Choice\", Weight = 3, Targets = { 1 } }", "{ Id = \"Choice\", Weight = 3, Targets = { 2 } }"),
    # 검수 2026-10-10: the goose rests a day; the PvP kinds are drawn rarely
    ("goose rest: none", "QUEST_SOURCE", " and not (gooseResting and rt.Id == \"Goose\") then", " then"),
    ("goose rest: the day is never marked", "QUEST_SOURCE", "\tif kind == \"Daily\" and t.Id == \"Goose\" then data.GooseDay = today end\n", ""),
    ("goose rest: the same day rests too", "QUEST_SOURCE", " and num(data.GooseDay) ~= today\n", "\n"),
    ("goose rest: a mark of 0 rests", "QUEST_SOURCE", "kind == \"Daily\" and num(data.GooseDay) > 0\n", "kind == \"Daily\"\n"),
    ("goose rest: zero days", "CONFIG_SOURCE", "\tGooseRestDays = 1,", "\tGooseRestDays = 0,"),
    ("goose rest: three days", "CONFIG_SOURCE", "\tGooseRestDays = 1,", "\tGooseRestDays = 3,"),
    ("goose rest: no save field", "CONFIG_SOURCE", "Config.Data.Defaults.GooseDay = 0", "Config.Data.Defaults.GooseDay_ = 0"),
    ("PvP weight: the woods Hunt row is common again", "CONFIG_SOURCE", "{ Id = \"Hunt\", Weight = 0.4, Targets = { 1 } }", "{ Id = \"Hunt\", Weight = 1.5, Targets = { 1 } }"),
    ("PvP weight: the Hunt template is common again", "CONFIG_SOURCE", "{ Id = \"Hunt\", ShortName = \"Catch Wanted\", Weight = 3, Units", "{ Id = \"Hunt\", ShortName = \"Catch Wanted\", Weight = 40, Units"),
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
        if line.startswith("A23_14_RESULT_JSON "):
            result = json.loads(line[len("A23_14_RESULT_JSON "):])
    return {"returncode": proc.returncode, "stdout": proc.stdout, "stderr": proc.stderr, "result": result}


def failing_keys(result: dict | None) -> set[str]:
    if not result:
        return set()
    return {f"{n['Group']} :: {n['Name']}" for n in result.get("Named", []) if n.get("Fail", 0) > 0}


def static_checks() -> tuple[int, list[str]]:
    """Client wiring that the offline services cannot reach (display only; the server rules are run above)."""
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    picker = STATIC_ONLY["CLASS_PICKER"].read_text(encoding="utf-8-sig")
    check("ClassChangeRuleF" in picker and "FreeKeepLevelBelow" in picker,
          "ClassPicker footer uses Config.Text.ClassChangeRuleF with Config.ClassChange.FreeKeepLevelBelow")
    panels = STATIC_ONLY["PANELS"].read_text(encoding="utf-8-sig")
    check("ClassChangeKeepsLevel" in panels and "ClassFreeKeepLevelF" in panels,
          "Panels class-change preview uses Config.ClassChangeKeepsLevel / ClassFreeKeepLevelF (no 'Lv N -> Lv 1' below Lv5)")
    hud = STATIC_ONLY["EVENT_HUD"].read_text(encoding="utf-8-sig")
    check("GooseMode" in hud and "GooseCoopTarget" in hud and "HudProgress" in hud,
          "EventHUD draws the co-op gauge from GameState GooseMode / GooseCoopTarget and Config.Goose.Text")
    net = FILES["NET_SOURCE"].read_text(encoding="utf-8-sig")
    check(all(key in net for key in ("GooseMode", "GooseCoopSide", "GooseCoopTarget", "GooseCoopPeople")),
          "Net.GameStateDefaults has the four co-op goose attributes")
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

    with tempfile.TemporaryDirectory(prefix="a23_14_offline_") as tmp:
        tmpdir = Path(tmp)
        main_run = run_harness(binary, make_harness(sources), tmpdir, "a23_14_main.luau")
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
                out = run_harness(binary, text, tmpdir, f"a23_14_mutant_{index:02d}.luau")
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
    marker = re.search(r"A23_14_OFFLINE_OK checks=(\d+) Studio/API calls=0", main_run["stdout"])
    named = result.get("Named", []) if result else []
    failing = [n for n in named if n.get("Fail", 0) > 0]
    caught = sum(1 for m in mutations if m.get("caught"))
    applied = sum(1 for m in mutations if m.get("applied"))
    ok = (compiled.returncode == 0 and main_run["returncode"] == 0 and marker is not None and not static_failures
          and not changed and all(m.get("applied") and m.get("caught") for m in mutations))
    report = {
        "status": ("passed-no-mutations" if args.no_mutations else "passed") if ok else "failed",
        "mutationsSkipped": args.no_mutations,
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
        "contract": "A23-14 (user 2026-10-05): Lv1-9 dailies = three different short goals (king slime 3 strict / slime 12-15, "
                    "skill hits 3-5, hunting gold 40-60), 72 gold + 120 XP each and a 144 + 240 chest (one day = 600 XP < 1381 "
                    "for Lv10), vacation 252 + 420 per missed rookie day, chest capped to the generation band; golden goose "
                    "co-op when only one of Halo/Horns is present: target 20 x headcount, 70% of the winner reward, 0 war "
                    "points, 3 manual hits to be paid, Neutral excluded, GooseFinished still fired (quest credit), rival-left "
                    "tug judged by the co-op rule; free class change below Lv5 keeps level/XP (no ticket spent, HP fraction "
                    "kept), from Lv5 free = Lv1 / XP 0 and ticket = level kept.",
        "limitations": "Offline doubles: DataStore table, seeded Util.Random, ProgressionService pay recorder (no level-ups), "
                       "faction counts from the fixture roster, no goose 3D model, rate limits always pass. Client HUD/Panels "
                       "are only checked statically. Studio play, multiple clients and the real timers are not certified here.",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if compiled.returncode:
        print(compiled.stderr, end="")
    for line in main_run["stdout"].splitlines():
        if line.startswith("CHECK_FAIL") or line.startswith("A23_14_OFFLINE"):
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
    if args.no_mutations:
        print("MUTATIONS SKIPPED")
    print(f"Named checks: {len(named) - len(failing)} passed, {len(failing)} failing; "
          f"assertions {report['checks'] - report['failedChecks']}/{report['checks']}")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if ok else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"A23-14 offline check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
