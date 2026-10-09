"""E11 hunting-field job boards (BoardService; quest_volume §3-3 / §4, 검수 OK 2026-10-07), offline.

Runs the CURRENT BoardService with the sources tools/test_unarmed_start.py binds (Config, Util, CombatService,
LootService, StoryQuestService ...) on tools/fixtures/dev2_combat_world.luau with tools/fixtures/board_offline.luau and
the installed official Luau CLI. BoardService's 1 s loop is stepped by hand. No Studio, network, DataStore or Roblox
API calls; mutations run on in-memory copies of the sources only. QuestService's side of the switch (extra quests on /
off, the Job rows in the list) is checked in tools/test_a23_14.py (group board-switch).

Usage: py tools/test_board.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_dev2_board_2026-10-06.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SSS, Suite, function_block, read, run
from test_unarmed_start import FILES as UNARMED_FILES, bindings as unarmed_bindings

FILES = dict(UNARMED_FILES)
FILES["BOARD_SOURCE"] = SSS / "BoardService.luau"
FILES["DEEDS_SOURCE"] = SSS / "Deeds.luau"  # A23-86: a finished job is one deed of the daily ledger
BD, C, ST = "BOARD_SOURCE", "CONFIG_SOURCE", "STORY_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = unarmed_bindings(sources)
    out["BOARD_SOURCE"] = sources[BD]
    out["DEEDS_SOURCE"] = sources["DEEDS_SOURCE"]
    return out


MUTATIONS = [
    ("job rows lose their ShortName", BD, ", ShortName = job.ShortName,", ","),
    ("the hint row loses its ShortName", BD, "\n\t\t\tShortName = (B.Text or {}).HintShort,", ""),
    ("the switch ignored", BD, "local function on()\n\treturn B.Enabled == true\nend", "local function on()\n\treturn true\nend"),
    ("the board works from anywhere", BD,
     "\treturn spot ~= nil and root ~= nil and Util.FlatDistance(root.Position, spot) <= num(B.Range, 14)\nend\n\nlocal function onBoardAction",
     "\treturn true\nend\n\nlocal function onBoardAction"),
    ("no carry limit", BD, "\t\tif #st.Held >= num(B.Hold, 3) then\n", "\t\tif false then\n"),
    ("the taken card stays", BD, "\t\tst.Seen = true -- the hint row goes away\n\t\treplaceCard(player, st, boardId, slot)\n",
     "\t\tst.Seen = true -- the hint row goes away\n"),
    ("swaps forget the last templates", BD, "\tfor _, id in st.Recent[boardId] or {} do avoid[id] = true end\n", ""),
    ("never half after 10", BD, "\tif done >= num(B.FullPerDay, 10) then\n", "\tif false then\n"),
    ("the scroll on every 5th+ job", BD, "if st.Done == num(B.BonusAt, 5) and not st.Bonus then",
     "if st.Done >= num(B.BonusAt, 5) then"),
    ("the scroll one job late", BD, "if st.Done == num(B.BonusAt, 5) and not st.Bonus then",
     "if st.Done == num(B.BonusAt, 5) + 1 and not st.Bonus then"),
    ("the side is not counted", BD, "\tstory.N[h.Side] = math.floor(num(story.N[h.Side])) + 1\n", ""),
    ("a finished job pays again", BD, "\ttable.remove(st.Held, index)\n", ""),
    # A23-71 S11: 'Hit 3 at once' (NeedSkill) waits for the first skill, also as a saved card
    ("A23-71: a skill job before the first skill", BD, "\treturn not job.NeedSkill or Config.SkillLearned(",
     "\treturn true or Config.SkillLearned("),
    ("S11: a saved card is kept when the player can't do it", BD,
     "if job and canDo(player, job) and #valid < num(B.Cards, 4) then", "if job and #valid < num(B.Cards, 4) then"),
    ("Auto Battle jobs before the unlock", BD,
     '\tif job.NeedAuto and player:GetAttribute("AutoCombatUnlocked") ~= true then return false end\n', ""),
    ("the woods board may lose its safe card", BD, "\tif type(safe) ~= \"table\" then return end\n", "\tdo return end\n"),
    ("no swap cooldown", BD, "\t\tif now < num(st.RerollAt) then return end\n", ""),
    ("a stay counts ticks, not time", BD, "local held = math.min(h.Target, math.floor(os.clock() - mine[key]))",
     "local held = math.min(h.Target, num(h.P) + 1)"),
    ("leaving keeps the count", BD, "\t\t\t\tif mine then mine[key] = nil end\n", ""),
    ("no hint row", BD, "\t\ttable.insert(rows, { Id = \"job:board\"", "\t\tlocal _ = ({ Id = \"job:board\""),
    ("the hint stays after the first job", BD, "\t\tst.Seen = true -- the hint row goes away", "\t\tlocal _ = 0"),
    ("a broken save keeps 4+ jobs", BD, "and (h.Side == \"Kind\" or h.Side == \"Sneaky\") and #held < num(B.Hold, 3) then",
     "and (h.Side == \"Kind\" or h.Side == \"Sneaky\") then"),
    ("the wrong side's line", BD, "notify(player, h.Side == \"Kind\" and T.LeanKind or T.LeanSneaky, \"info\")",
     "notify(player, T.LeanKind, \"info\")"),
    # (no "slot range" mutation: a slot outside 1..Cards finds no card and is ignored by the next line anyway)
    ("EventAmount not shared", ST, "function StoryQuestService.EventAmount(player, obj, ev)\n\treturn eventAmount(player, obj, ev)",
     "function StoryQuestService.EventAmount(player, obj, ev)\n\treturn 0"),
    ("Config: the switch on before the window", C, "Config.Board = {\n\tEnabled = false,", "Config.Board = {\n\tEnabled = true,"),
    ("Config: the woods board inside the PvP woods", C,
     "Config.StoryQuests.Landmarks.WoodsBoard = Config.StoryQuests.Landmarks.WoodsGate",
     "Config.StoryQuests.Landmarks.WoodsBoard = Config.Zones.GoblinWoods.Spawn"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    main = read(SSS / "Main.server.luau")
    init = main[main.find("local INIT_ORDER"):main.find("local START_ORDER")]
    start = main[main.find("local START_ORDER"):main.find("local S = {}")]
    check('"BoardService"' in init and '"BoardService"' in start, "Main loads and starts BoardService")
    check(start.find('"BoardService"') < start.find('"PlayerService"'), "BoardService starts before PlayerService")
    net = read(ROOT / "src/ReplicatedStorage/Shared/Net.luau")
    check('"BoardAction"' in net and '"Board",' in net, "Net.Names has BoardAction (c->s) and Board (s->c)")
    board = read(SSS / "BoardService.luau")
    check("AddStat" not in board and "RankingService" not in board and "GrantFame" not in board,
          "the boards give no honor / infamy / ranking points (A23-23 D1)")
    return count, failures


SUITE = Suite(
    mark="BOARD",
    fixture=ROOT / "tools/fixtures/board_offline.luau",
    world=ROOT / "tools/fixtures/dev2_combat_world.luau",
    out=ROOT / "docs/art/verification_2026-10-06/offline_dev2_board_2026-10-06.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="E11: Config.Board (Enabled false until the board window ships). BoardAction(board, Open | Take | Reroll, "
             "slot, Kind | Sneaky) within Range of the board spot; 4 cards per board from J1..J10 with the field's values "
             "(J7 only after Auto Battle is unlocked; the woods always keep J6 / J10, outside PvP); carry 3; a taken / "
             "swapped card gets a template that is neither on the board nor one of its last two; one swap per 60 s. "
             "Jobs are judged by StoryQuestService.EventAmount (J10: seconds in one go at the gate); a finished job pays "
             "at once HuntValue(board level, 1), half after 10 a KST day, the 5th of a day adds one 30% scroll, counts "
             "the side in data.Story.N (no honor / infamy / ranking) and says which way the shard leaned. JobRows = "
             "Kind 'Job' rows (+ the 'Job Board' hint after M1_4 until the first job). A broken save is cleaned at load.",
    limitations="The board model, prompt and window are game dev 1's (remote contract in the doc); QuestService's extras "
                "switch is tested in test_a23_14. Real walking and the 1 s loop timing are modelled by moving the root "
                "and stepping the loop.",
)

if __name__ == "__main__":
    run(SUITE)
