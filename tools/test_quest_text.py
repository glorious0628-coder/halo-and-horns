"""Saved daily / extra quest texts are rebuilt in English at load (게임성 개발 3, 2026-10-08), offline.

검수 / 개발 1: saves from before A23-48 (English only) kept Korean daily text ("빛의 기사단 1명 털기") because
QuestService.ensureSlots trusted the saved Text. Now every valid saved quest gets its Text again from today's template
(QuestService.questText, also used by newQuest). Runs the CURRENT Config + QuestService's template table, num,
getLevel, isValidQuest, questText and ensureSlots (cut out; newQuest / boardOn stubbed) with
tools/fixtures/quest_text_offline.luau on tools/fixtures/dev2_kit.luau and the installed official Luau CLI.

Usage: py tools/test_quest_text.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-08/offline_dev3_quest_text_2026-10-08.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, between, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "QUEST_SOURCE": SSS / "QuestService.luau",
}
C, Q = "CONFIG_SOURCE", "QUEST_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    src = sources["QUEST_SOURCE"]
    extract = (
        "local Config, Util, S, newQuestStub = ...\n"
        + between(src, "local TEMPLATE_BY_ID = {}", "-- A6: quests that need a Halo/Horns side")
        + function_block(src, "local function num(")
        + function_block(src, "local function getLevel(")
        + function_block(src, "local function isValidQuest(")
        + "local function boardOn() return false end\n"
        + "local function newQuest(player, kind, others) return newQuestStub(player, kind, others) end\n"
        + function_block(src, "local function questText(")
        + function_block(src, "local function ensureSlots(")
        + "return { ensureSlots = ensureSlots, questText = questText }\n"
    )
    return {"CONFIG_SOURCE": sources["CONFIG_SOURCE"], "UTIL_SOURCE": sources["UTIL_SOURCE"], "QUEST_EXTRACT": extract}


MUTATIONS = [
    ("the saved text is kept", Q, "\t\t\tq.Text = questText(TEMPLATE_BY_ID[q.Id], q.Target, unit)\n", ""),
    ("only Release is rebuilt", Q, "\t\t\tq.Text = questText(TEMPLATE_BY_ID[q.Id], q.Target, unit)\n",
     "\t\t\tif q.Id == \"Release\" then q.Text = questText(TEMPLATE_BY_ID[q.Id], q.Target, unit) end\n"),
    ("a saved unit ignored", Q, "\t\t\tlocal unit = (type(q.Unit) == \"string\" and Config.MonsterTypes[q.Unit] ~= nil) and q.Unit\n",
     "\t\t\tlocal unit = false\n"),
    ("a broken unit trusted", Q, "(type(q.Unit) == \"string\" and Config.MonsterTypes[q.Unit] ~= nil) and q.Unit", "q.Unit"),
    ("no plural fix", Q, "\treturn Config.Plural(text) -- \"Join the Golden Goose tug 1 time\"\n", "\treturn text\n"),
    ("gold rounded", Q, "\t\ttext = string.format(t.Text, tostring(target)) -- CR-L31", "\t\ttext = string.format(t.Text, Util.FormatNumber(target)) -- CR-L31"),
    ("the monster's long name", Q, "tostring(unitDef.Short or unitDef.Name or unitId)", "tostring(unitDef.Name or unitId)"),
    ("Release keeps MinStacks", Q, "\t\t\tif q.Id == \"Release\" then q.MinStacks = nil end\n", ""),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    src = read(SSS / "QuestService.luau")
    nq = function_block(src, "local function newQuest(")
    check("local text = questText(t, target, unitId)" in nq, "newQuest builds its text with the same questText")
    ready = src[src.find("local function onPlayerReady("):]
    check(ready.find("ensureSlots(player, data)") != -1 and ready.find("ensureSlots(player, data)") < ready.find("publish(player)"),
          "PlayerReady repairs the slots (and their text) before the first publish")
    config = read(SHARED / "Config.luau")
    templates = re.search(r"Config\.Quests = \{.*?\n\tTemplates = \{(.*?)\n\t\}", config, re.S)
    texts = re.findall(r'Text = "([^"]*)"', templates.group(1)) if templates else []
    check(bool(texts) and not any(re.search(r"[가-힣]", t) for t in texts), "every template text is English")
    return count, failures


SUITE = Suite(
    mark="QUEST_TEXT",
    fixture=ROOT / "tools/fixtures/quest_text_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-08/offline_dev3_quest_text_2026-10-08.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="QuestService.ensureSlots (PlayerReady) rebuilds the Text of every valid saved daily / extra quest from its "
             "template (QuestService.questText, the same function newQuest uses): Kill / Golden name the saved Unit "
             "(a missing / unknown Unit = the level zone's main monster), Gold shows the exact number, Config.Plural; "
             "progress, target, rewards and the unit are kept; Release drops its old MinStacks.",
    limitations="Story rows are built from Config every publish already (not saved text). The client safety net "
                "(game dev 1, 4bac9159) is not run here.",
)

if __name__ == "__main__":
    run(SUITE)
