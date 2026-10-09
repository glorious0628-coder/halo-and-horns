"""The field bosses (FieldBossService, 게임성 개발 2; started as the King Slime 2026-10-08), server side, offline.

content_beyond_10min_2026-10-08 FB + A23-84 / A23-85 (docs/design/king_slime_split_2026-10-08.md §3): per
Config.FieldBosses key one boss on the server, the first slot FirstDelay s after the start, then every Interval s from its
last appearance (a due slot waits for a ready hunter in its zone); it stays Lifetime s. Spot: the marked attribute
(KingSpawn) on workspace.Map > (Hill) MeadowTerrainStore HillTop moved 8 studs toward HillPathFoot > Spawn > a zone
spawn point. Defeat = Fx KingDefeat + Defeat line + Defeated signal; time up / lost = goes home + Leave line.
The old King Slime (BigSlime) is the Slime Prince; the finisher card belongs to the King Slime only.

Runs the CURRENT Config, Util and FieldBossService on tools/fixtures/dev2_kit.luau + tools/fixtures/field_boss_offline.luau
with the installed official Luau CLI (MonsterService / PlayerService / ZoneService / AnnounceService are doubles). No
Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_field_boss.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-09/offline_dev2_field_boss_2026-10-09.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "NET_SOURCE": SHARED / "Net.luau",
    "MAIN_SOURCE": SSS / "Main.server.luau",
    "FIELDBOSS_SOURCE": SSS / "FieldBossService.luau",
}
C, K, N, M = "CONFIG_SOURCE", "FIELDBOSS_SOURCE", "NET_SOURCE", "MAIN_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    ("no hunter check", K, "\tif not hunterHere(key) then return end", ""),
    ("any zone counts", K, "if ok and z == zone then return true end", "if ok then return true end"),
    ("not-ready players count", K, "\t\tif S.PlayerService.IsReady(p) then\n", "\t\tif true then\n"),
    ("marked spot ignored", K, "\tif okS and marked then return marked, \"Marked\" end\n", ""),
    ("hill for every boss", K, "\tif c.Hill == true then\n", "\tif true then\n"),
    ("hill step ignored", K, "\treturn top + d.Unit * math.max(0, num(step, 8))", "\treturn top"),
    ("hill step goes away from the path", K, "\treturn top + d.Unit * math.max(0, num(step, 8))",
     "\treturn top - d.Unit * math.max(0, num(step, 8))"),
    ("hill step not flat", K, "local d = Vector3.new(foot.X - top.X, 0, foot.Z - top.Z)", "local d = foot - top"),
    ("radius lost", K, "{ Near = near, Radius = math.max(0, num(c.Radius, 2)) }", "{ Near = near }"),
    ("never leaves", K, "\t\telseif now >= b.EndsAt then\n\t\t\tfinish(key, false)\n", "\t\telseif false then\n"),
    ("leaving with a splat", K, "pcall(svc.RemoveEvent, rec, true, true)", "pcall(svc.RemoveEvent, rec, true, false)"),
    ("a lost model counts as a defeat", K, "finish(key, num(rec.HP, 1) <= 0) -- a lost", "finish(key, true) -- a lost"),
    ("no defeat Fx", K, "local ok, err = pcall(Net.Fx, nil, \"KingDefeat\"", "local ok, err = true, nil --"),
    ("no Defeated signal", K, "\t\tFieldBossService.Defeated:Fire(key, rec.Kind, table.clone(ids), rec)\n", ""),
    ("Defeat and Leave swapped", K, "(defeated and \"Defeat\" or \"Leave\")", "(defeated and \"Leave\" or \"Defeat\")"),
    ("no Appear line", K, "\tannounce(key .. \"Appear\")\n", ""),
    ("next slot not set", K, "\t\tb.NextAt = now + math.max(60, num(c.Interval, 480))\n\telse", "\telse"),
    ("no retry delay", K, "b.NextAt = now + math.max(1, num(c.RetryDelay, 10))", "b.NextAt = now"),
    ("debug spawns twice", K, "\t\tif b.Rec.Alive then return \"already here\" end\n", ""),
    ("Active not published", K, "\tsetGame(key .. \"Active\", active)\n", ""),
    ("first slot at once", K, "(now + math.max(0, num(c.FirstDelay, 180)))", "(now)"),
    ("string ids in Contributors", K, "\t\t\tif type(id) == \"number\" then table.insert(ids, id) end",
     "\t\t\ttable.insert(ids, id)"),
    ("card back on the Prince", C, "\tKinds = { SlimeKing = true, CaptainClatter = true },",
     "\tKinds = { BigSlime = true, CaptainClatter = true },"),
    ("Prince renamed back", C, "BigSlime = { Name = \"Slime Prince\"", "BigSlime = { Name = \"King Slime\""),
    ("a mom line", C, "SlimeKingLeaveEn = \"King Slime: \\\"Hmph! Bedtime, kids!\\\"\"",
     "SlimeKingLeaveEn = \"King Slime: \\\"Hmph! Mom says bedtime!\\\"\""),
    ("King in the regular pool", C, "Zone = \"SlimeMeadow\", Count = 0, Boss = true,", "Zone = \"SlimeMeadow\", Count = 2, Boss = true,"),
    ("not in Main START", M, "\"FinisherService\", \"FieldBossService\", -- 게임성 개발 2 (before",
     "\"FinisherService\", -- 게임성 개발 2 (before"),
    ("no Net default", N, "SlimeKingNextAt = 0, SlimeKingActive = false, SlimeKingEndsAt = 0,", ""),
    # J Captain Clatter extras
    ("war pool per player (stacks)", K, "local ok, err = pcall(S.WarService.AddPoints, player, war, war / n)",
     "local ok, err = pcall(S.WarService.AddPoints, player, war, war)"),
    ("sides never counted", K, "\t\t\tif type(f) == \"string\" then sides[f] = (sides[f] or 0) + 1 end\n", ""),
    ("no extras paid", K, "\t\tpayExtras(key, ids)\n", ""),
    ("no side share", K, "\t\t\tShare = shareOf(rec) })", "\t\t\tShare = nil })"),
    ("share sides swapped", K, "return { Halo = hp, Horns = 100 - hp }", "return { Halo = 100 - hp, Horns = hp }"),
    ("no war points", K, "\tif num(c.War) > 0 and S.WarService", "\tif false and S.WarService"),
    ("kills never counted", K, "\trow.Kills = math.max(0, math.floor(num(row.Kills))) + 1\n",
     "\trow.Kills = math.max(0, math.floor(num(row.Kills)))\n"),
    ("titles at any count", K, "if type(at) == \"number\" and row.Kills >= at then", "if type(at) == \"number\" then"),
    ("no weekly bank", K, "\t\trow.Owed = math.min(max, row.Owed + (week - row.Week))\n", "\t\trow.Owed = row.Owed\n"),
    ("first kill gives nothing", K, "\tif row.Week <= 0 then\n\t\trow.Owed = math.min(max, row.Owed + 1)\n",
     "\tif row.Week <= 0 then\n\t\trow.Owed = row.Owed\n"),
    ("a full bag loses the guarantee", K, "\tif num(got) < 1 then return end -- a full bag", "\tif false then return end -- a full bag"),
    ("broken save banks more", K, "\trow.Owed = math.min(max, row.Owed) -- a broken save", "\trow.Owed = row.Owed -- a broken save"),
    ("badge every kill", K, "\trow.Owed -= 1\n", ""),
    ("Clatter weekly 3", C, "\t\tWeekly = { Item = \"CaptainBadge\", N = 1, Max = 2 },", "\t\tWeekly = { Item = \"CaptainBadge\", N = 1, Max = 3 },"),
    ("Clatter every 10 min", C, "\tClatter = { Enabled = true, Kind = \"CaptainClatter\", FirstDelay = 300, Interval = 1200,",
     "\tClatter = { Enabled = true, Kind = \"CaptainClatter\", FirstDelay = 300, Interval = 600,"),
    ("Clatter card not the same size", C, "Tickle = { Gold = 300 },", "Tickle = { Gold = 400 },"),
]


def static() -> tuple[int, list[str]]:
    count, failures = 0, []

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    king = read(SSS / "FieldBossService.luau")
    check("task.wait(" in king and "wait(" not in king.replace("task.wait(", ""), "task.wait only")
    check("<const>" not in king, "no <const>")
    for name in ("Spawn", "Interval", "Lifetime", "FirstDelay", "Attr", "Hill"):
        check(f"c.{name}" in king, f"reads Config.FieldBosses[key].{name}")
    check(not (SSS / "SlimeKingService.luau").exists(), "SlimeKingService.luau is gone (FieldBossService took it over)")
    everything = "".join(read(p) for p in (ROOT / "src").rglob("*.luau"))
    check("SlimeKingService" not in everything.replace("SlimeKingService 2026-10-08", ""),
          "nothing requires the old SlimeKingService")
    check("\"BigSlime\"" in read(SSS / "QuestService.luau") or "BigSlime" in everything,
          "the Slime Prince quests keep the BigSlime id")
    return count, failures


SUITE = Suite(
    mark="FIELDBOSS",
    fixture=ROOT / "tools/fixtures/field_boss_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-09/offline_dev2_field_boss_2026-10-09.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="Field bosses (Config.FieldBosses; the King Slime A23-84/85, king_slime_split §3): one of each on the "
             "server, first slot FirstDelay s after start, then every Interval s from its last appearance, a due slot "
             "waits for a ready hunter in its zone, stays Lifetime s; spot Attr on workspace.Map > (Hill) HillTop + 8 "
             "toward HillPathFoot (flat) > Spawn > a zone spawn point, Radius; no ground = retry in RetryDelay s; defeat "
             "= Fx KingDefeat { Key, Kind, Pos, Contributors (numbers) } to all + <Key>Defeat + Defeated(key, kind, ids, "
             "rec); time up / lost model = RemoveEvent(fade, leaving) + <Key>Leave; GameState <Key>Active / EndsAt / "
             "NextAt. King Slime: 180 / 480 / 300 s, KingSpawn, hill. BigSlime = Slime Prince; the card is SlimeKing's.",
    limitations="MonsterService (SpawnEvent ground pick, kill payout, model borrow), PlayerService, ZoneService and "
                "AnnounceService are doubles; the client (boss chip, minimap icon) and the shrine placement are not here.",
)

if __name__ == "__main__":
    run(SUITE)
