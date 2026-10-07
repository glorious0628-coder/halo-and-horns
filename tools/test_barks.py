"""③ monster barks (docs/design/lines_pack_2026-10-06.md §2, 검수 2026-10-07), offline.

Runs the CURRENT Config (Barks), Util and BarkService on tools/fixtures/dev2_kit.luau with
tools/fixtures/barks_offline.luau and the installed official Luau CLI: a MonsterService stand-in fires
Moment(rec, "Spot" | "Hit") and answers GetMonstersInRadius; the real MonsterService.DamageMonster runs as a chunk cut
from the current MonsterService.luau; the Spot hooks (aiStep / personalStep) and the Main order lists are read from the
bound sources. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_barks.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-07/offline_dev2_barks_2026-10-07.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "BARK_SOURCE": SSS / "BarkService.luau",
    "MONSTER_SOURCE": SSS / "MonsterService.luau",
    "MAIN_SOURCE": SSS / "Main.server.luau",
}
C, B, M, MAIN = "CONFIG_SOURCE", "BARK_SOURCE", "MONSTER_SOURCE", "MAIN_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # BarkService: cadence, rolls, Low, lines, idle
    ("no per-monster cooldown", B, "if now - m.At < num(K.PerMonster, 12) or now", "if now"),
    ("no per-zone cooldown", B, " or now - (zoneAt[zone] or -math.huge) < num(K.PerZone, 6)", ""),
    ("the chance never rolled (always speaks)", B,
     "\tif chance < 1 and Util.Random:NextNumber() >= chance then return false end\n", ""),
    ("a roll equal to the chance speaks", B, "Util.Random:NextNumber() >= chance", "Util.Random:NextNumber() > chance"),
    ("Low never said", B, "if moment == \"Hit\" and not m.Low and lowNow(rec) then moment = \"Low\" end", ""),
    ("Low on every low hit (never marked)", B, "\tif moment == \"Low\" then m.Low = true end\n", ""),
    ("a Low blocked by a cooldown is never retried", B, "then moment = \"Low\" end -- Low > Hit",
     "then moment = \"Low\"; m.Low = true end -- Low > Hit"),
    ("exactly 30% counts as low", B, "num(rec.HP) / max < num(K.LowAt, 0.3)", "num(rec.HP) / max <= num(K.LowAt, 0.3)"),
    ("golden lines ignored", B, "if rec.Golden == true and type(L.Golden)", "if false and type(L.Golden)"),
    ("no QuestKind fallback", B, "local qk = Config.QuestKind(rec.Kind)", "local qk = nil"),
    ("lines repeat back to back", B,
     "\tif n > 1 and i == lastLine[key] then i = (i % n) + 1 end -- never the same line twice in a row\n", ""),
    ("idle while chasing someone", B, "if not seen[rec] and rec._target == nil then", "if not seen[rec] then"),
    ("idle rolls once per nearby player", B, "if not seen[rec] and rec._target == nil then", "if rec._target == nil then"),
    ("idle ignores the distance", B, "num(K.IdleNear, 40), p)", "1000, p)"),
    ("idle asks for every monster (no forPlayer)", B, "num(K.IdleNear, 40), p)", "num(K.IdleNear, 40))"),
    ("Enabled ignored", B, "return K.Enabled == true and type(K.Lines) == \"table\"", "return type(K.Lines) == \"table\""),
    ("no BarkAt", B, "\t\trec.Model:SetAttribute(\"BarkAt\", workspace:GetServerTimeNow())\n", ""),
    ("a dead monster barks", B, "type(rec) ~= \"table\" or not rec.Alive or", "type(rec) ~= \"table\" or"),
    ("Spot moments ignored", B, "if kind == \"Spot\" or kind == \"Hit\" then", "if kind == \"Hit\" then"),
    ("the idle loop ignores IdleEvery", B, "task.wait(math.max(1, num(K.IdleEvery, 10)))", "task.wait(1)"),
    # MonsterService hooks (game dev 1's file: two lines + the signal)
    ("no Hit moment", M, "\t\tMonsterService.Moment:Fire(record, \"Hit\") -- ③ barks\n", ""),
    ("a Hit moment on the killing hit too", M, "\tkillRecord(record) -- the killing hit",
     "\tMonsterService.Moment:Fire(record, \"Hit\")\n\tkillRecord(record) -- the killing hit"),
    ("no Spot moment in aiStep", M, "\t\t\tMonsterService.Moment:Fire(rec, \"Spot\") -- ③ barks: a new target\n", ""),
    ("Spot on every AI tick", M,
     "\t\tif rec._target ~= best.Player then\n\t\t\trec._chaseStuck = 0\n"
     "\t\t\tMonsterService.Moment:Fire(rec, \"Spot\") -- ③ barks: a new target\n\t\tend",
     "\t\tMonsterService.Moment:Fire(rec, \"Spot\")\n\t\tif rec._target ~= best.Player then\n\t\t\trec._chaseStuck = 0\n\t\tend"),
    ("a personal monster spots on every tick", M, "\t\trec._spotted = true\n", ""),
    # Main order lists (the module file and the lists go in the same commit)
    # anchors that do not lean on the end of the lists (game dev 1: "ChatText" came after them)
    ("BarkService never started", MAIN, "\"BarkService\", \"DamageWindow\",\n", "\"DamageWindow\",\n"),
    ("BarkService never loaded", MAIN, "\"BarkService\", \"DamageWindow\", \"SkillService\",", "\"DamageWindow\", \"SkillService\","),
    # Config.Barks as written (lines_pack §2-2 cadence; A23-74 sound-word lines, user 2026-10-07)
    ("Hit chance 50%", C, "Chance = { Spot = 0.5, Hit = 0.2, Low = 1, Idle = 0.15 },",
     "Chance = { Spot = 0.5, Hit = 0.5, Low = 1, Idle = 0.15 },"),
    ("a sentence comes back", C, "\"Clack clack!\"", "\"Guarding! Guarding what? Halt!\""),
    ("a 13-letter word", C, "\"Best patch!\"", "\"Bestest patch!\""),
    ("a three-dot ellipsis", C, "\"Wobble…\"", "\"Wobble...\""),
    ("a scary word", C, "\"Hoo-ouch!\"", "\"Scary!\""),
    ("two kinds share a sound", C, "\"Oopsie!\"", "\"Eep!\""),
    ("a kind loses its own first sound", C, "Spot = { \"Grrr!\", \"Sack time!\" },", "Spot = { \"Sack time!\", \"Grrr!\" },"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    bark = strip_comments(read(SSS / "BarkService.luau"))
    check("Net." not in bark and "Notify" not in bark, "BarkService sends no message or chat line (model attributes only)")
    for word in ("Honor", "Infamy", "AddPoints", "SetStat", "AddGold", "Reward"):
        check(word not in bark, f"barks never change a score or reward ({word})")
    check(bark.count("task.wait(") == 1 and bark.count("task.spawn(") == 1, "one Idle loop, no other waits (handlers never yield)")
    monster = read(SSS / "MonsterService.luau")
    dm = function_block(monster, "function MonsterService.DamageMonster(")
    check(dm.count("Moment:Fire") == 1, "DamageMonster fires one moment")
    check(monster.count("Moment:Fire") == 3, "MonsterService fires exactly three moments (Hit, aiStep Spot, personal Spot)")
    config = read(SHARED / "Config.luau")
    check(config.count("\nConfig.Barks = {") == 1, "one Config.Barks table")
    return count, failures


SUITE = Suite(
    mark="BARKS",
    fixture=ROOT / "tools/fixtures/barks_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-07/offline_dev2_barks_2026-10-07.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="③ (lines_pack §2): MonsterService fires Moment(rec, \"Spot\") when a monster picks a new target (a personal "
             "monster once, when it first goes for its owner) and Moment(rec, \"Hit\") when a hit leaves it alive. "
             "BarkService (Config.Barks) turns a Hit below LowAt (30%) into Low once a life, drops a moment blocked by "
             "PerMonster (12 s) or PerZone (6 s, all monsters of a zone) with no roll (a blocked Low tries again at the "
             "next hit), rolls Chance (Spot 50%, Hit 20%, Low 100%, Idle 15%; a roll equal to the chance stays quiet), "
             "picks the golden set first for a golden monster, else its kind's, else Config.QuestKind's, never the same "
             "line twice in a row, and writes model attributes Bark, then BarkAt (server time). Every IdleEvery (10) s a "
             "monster with no target within IdleNear (40) of a player (the monsters that player may hit) rolls Idle once. "
             "Lines never change a score. A23-74 (user 2026-10-07): every line is a sound word or one short word in the "
             "monster's own voice (at most 2 words and 12 letters, no two kinds share a line, e.g. Slime 'Blub?', "
             "King Slime 'BLOOP!', Ghost King 'OOOH!'); the kinds and moments are unchanged.",
    limitations="The bubble is game dev 1's (MonsterLabels: watch BarkAt, show Bark for Show s within MaxDistance). The "
                "real aiStep / personalStep are checked as source text (the AI needs the engine); DamageMonster runs as "
                "a cut chunk. The optional goose barks (Lines.Goose, GooseService) are not wired.",
)

if __name__ == "__main__":
    run(SUITE)
