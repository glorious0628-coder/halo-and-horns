"""The King Slime boss (SlimeKingService, 게임성 개발 2, 2026-10-08), server side, offline.

A23-84 / A23-85, docs/design/king_slime_split_2026-10-08.md §3: one King Slime on the server, the first slot 180 s after
the start, then every 480 s from its last appearance (a due slot waits for a ready hunter in the meadow); it stays 300 s.
Spot: the shrine's KingSpawn (workspace.Map) > MeadowTerrainStore HillTop moved 8 studs toward HillPathFoot >
Config.SlimeKing.Spawn. Defeat = Fx KingDefeat + Defeat line + Defeated signal; time up / lost = goes home + Leave line.
The old King Slime (BigSlime) is the Slime Prince; the finisher card belongs to the King Slime only.

Runs the CURRENT Config, Util and SlimeKingService on tools/fixtures/dev2_kit.luau + tools/fixtures/slime_king_offline.luau
with the installed official Luau CLI (MonsterService / PlayerService / ZoneService / AnnounceService are doubles). No
Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_slime_king.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-09/offline_dev2_slime_king_2026-10-09.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "NET_SOURCE": SHARED / "Net.luau",
    "MAIN_SOURCE": SSS / "Main.server.luau",
    "SLIMEKING_SOURCE": SSS / "SlimeKingService.luau",
}
C, K, N, M = "CONFIG_SOURCE", "SLIMEKING_SOURCE", "NET_SOURCE", "MAIN_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    ("no hunter check", K, "\tif not hunterHere() then return end", ""),
    ("any zone counts", K, "if ok and z == zone then return true end", "if ok then return true end"),
    ("not-ready players count", K, "\t\tif S.PlayerService.IsReady(p) then\n", "\t\tif true then\n"),
    ("shrine ignored", K, "\tif okS and shrine then return shrine, \"Shrine\" end\n", ""),
    ("hill step ignored", K, "\treturn top + d.Unit * math.max(0, num(C.PathStep, 8))", "\treturn top"),
    ("hill step goes away from the path", K, "\treturn top + d.Unit * math.max(0, num(C.PathStep, 8))",
     "\treturn top - d.Unit * math.max(0, num(C.PathStep, 8))"),
    ("hill step not flat", K, "local d = Vector3.new(foot.X - top.X, 0, foot.Z - top.Z)", "local d = foot - top"),
    ("radius lost", K, "{ Near = near, Radius = math.max(0, num(C.Radius, 2)) }", "{ Near = near }"),
    ("never leaves", K, "\t\telseif now >= B.EndsAt then\n\t\t\tfinish(false)\n", "\t\telseif false then\n"),
    ("leaving with a splat", K, "pcall(svc.RemoveEvent, rec, true, true)", "pcall(svc.RemoveEvent, rec, true, false)"),
    ("a lost model counts as a defeat", K, "finish(num(rec.HP, 1) <= 0) -- a lost", "finish(true) -- a lost"),
    ("no defeat Fx", K, "local ok, err = pcall(Net.Fx, nil, \"KingDefeat\"", "local ok, err = true, nil --"),
    ("no Defeated signal", K, "\t\tSlimeKingService.Defeated:Fire(rec.Kind, table.clone(ids))\n", ""),
    ("Defeat and Leave swapped", K, "(defeated and \"Defeat\" or \"Leave\")", "(defeated and \"Leave\" or \"Defeat\")"),
    ("no Appear line", K, "\tannounce(key() .. \"Appear\")\n", ""),
    ("next slot not set", K, "\t\tB.NextAt = now + math.max(60, num(C.Interval, 480))\n\telse", "\telse"),
    ("no retry delay", K, "B.NextAt = now + math.max(1, num(C.RetryDelay, 10))", "B.NextAt = now"),
    ("debug spawns twice", K, "\t\tif B.Rec.Alive then return \"already here\" end\n", ""),
    ("Active not published", K, "\tsetGame(key() .. \"Active\", active)\n", ""),
    ("first slot at once", K, "(Util.Now() + math.max(0, num(C.FirstDelay, 180)))", "(Util.Now())"),
    ("string ids in Contributors", K, "\t\t\tif type(id) == \"number\" then table.insert(ids, id) end",
     "\t\t\ttable.insert(ids, id)"),
    ("card back on the Prince", C, "\tKinds = { SlimeKing = true },", "\tKinds = { BigSlime = true },"),
    ("Prince renamed back", C, "BigSlime = { Name = \"Slime Prince\"", "BigSlime = { Name = \"King Slime\""),
    ("a mom line", C, "SlimeKingLeaveEn = \"King Slime: \\\"Hmph! Bedtime, kids!\\\"\"",
     "SlimeKingLeaveEn = \"King Slime: \\\"Hmph! Mom says bedtime!\\\"\""),
    ("King in the regular pool", C, "Zone = \"SlimeMeadow\", Count = 0, Boss = true,", "Zone = \"SlimeMeadow\", Count = 2, Boss = true,"),
    ("not in Main START", M, "\"ScoreBudget\", \"FinisherService\", \"SlimeKingService\", -- 게임성 개발 2 (before",
     "\"ScoreBudget\", \"FinisherService\", -- 게임성 개발 2 (before"),
    ("no Net default", N, "SlimeKingNextAt = 0, SlimeKingActive = false, SlimeKingEndsAt = 0,", ""),
]


def static() -> tuple[int, list[str]]:
    count, failures = 0, []

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    king = read(SSS / "SlimeKingService.luau")
    check("task.wait(" in king and "wait(" not in king.replace("task.wait(", ""), "task.wait only")
    check("<const>" not in king, "no <const>")
    for name in ("Spawn", "Interval", "Lifetime"):
        check(f"C.{name}" in king or name in ("Spawn",), f"reads Config.SlimeKing.{name}")
    everything = "".join(read(p) for p in (ROOT / "src").rglob("*.luau"))
    check("\"BigSlime\"" in read(SSS / "QuestService.luau") or "BigSlime" in everything,
          "the Slime Prince quests keep the BigSlime id")
    return count, failures


SUITE = Suite(
    mark="SLIMEKING",
    fixture=ROOT / "tools/fixtures/slime_king_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-09/offline_dev2_slime_king_2026-10-09.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="King Slime boss (A23-84/85, king_slime_split §3): one on the server, first slot 180 s after start, then "
             "every 480 s from its last appearance, a due slot waits for a ready hunter in SlimeMeadow, stays 300 s; "
             "spot shrine KingSpawn > HillTop + 8 toward HillPathFoot (flat) > Config.SlimeKing.Spawn, radius 2; no "
             "ground = retry in 10 s; defeat = Fx KingDefeat { Key, Kind, Pos, Contributors (numbers) } to all + "
             "SlimeKingDefeat + Defeated signal; time up / lost model = RemoveEvent(fade, leaving) + SlimeKingLeave; "
             "GameState SlimeKingActive / EndsAt / NextAt. BigSlime = Slime Prince; the finisher card is SlimeKing's only.",
    limitations="MonsterService (SpawnEvent ground pick, kill payout, model borrow), PlayerService, ZoneService and "
                "AnnounceService are doubles; the client (boss chip, minimap icon) and the shrine placement are not here.",
)

if __name__ == "__main__":
    run(SUITE)
