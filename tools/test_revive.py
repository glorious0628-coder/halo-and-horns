"""99N G (계획 8) helping a friend up — the server (ReviveService, 게임성 개발 2), offline.

Runs the CURRENT Config, Util, ReviveService sources (plus Main / Net text for the wiring and PlayerService's getUp cut
out) in tools/fixtures/revive_offline.luau on tools/fixtures/dev2_kit.luau with the installed official Luau CLI. No Studio,
network, DataStore or Roblox API calls. Mutations run on in-memory copies only.

Usage: py tools/test_revive.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-14/offline_dev2_revive_2026-10-14.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "NET_SOURCE": SHARED / "Net.luau",
    "REVIVE_SOURCE": SSS / "ReviveService.luau",
    "MAIN_SOURCE": SSS / "Main.server.luau",
    "PLAYER_SOURCE": SSS / "PlayerService.luau",
}


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = dict(sources)
    out["PLAYER_GETUP"] = function_block(out.pop("PLAYER_SOURCE"), "local function getUp(")
    return out


C, R, M, N, P = "CONFIG_SOURCE", "REVIVE_SOURCE", "MAIN_SOURCE", "NET_SOURCE", "PLAYER_SOURCE"
MUTATIONS = [
    # feedback_audit #8 (최종 검수 10/15): the helper's side of a revive
    ("no ReviveDone to the helper", R, "\tpcall(Net.Fx, helper, \"ReviveDone\", { Target = target.UserId })\n", ""),
    ("the helper gets Revived (its death screen)", R, "\tpcall(Net.Fx, helper, \"ReviveDone\", { Target = target.UserId })\n",
     "\tpcall(Net.Fx, helper, \"Revived\", { Target = target.UserId })\n"),
    # the KO
    ("a prompt with nobody near", R, "\tif not friendNear(player, side, pos) then return end\n", ""),
    ("a foe counts as a friend near", R, "if other ~= player and sideOf(other) == side and alive(other)", "if other ~= player and alive(other)"),
    ("the first KO gets a prompt too", R, "\tif not on() or not isPlayer(player) or firstKOHolds(player) then return end\n",
     "\tif not on() or not isPlayer(player) then return end\n"),
    ("the switch ignored", R, "\treturn R.Enabled == true\n", "\treturn true\n"),
    ("no wait (the usual 3 s)", R, "\treturn { Delay = num(R.Wait, 10) }\n", "\treturn nil\n"),
    ("helped: no spot", R, "\tif d.Revived then return { Delay = 0, CFrame = CFrame.new(d.Pos + Vector3.new(0, 3, 0)) } end\n", ""),
    ("the prompt is not G", R, "\tprompt.KeyboardKeyCode = Enum.KeyCode.G\n", ""),
    ("the prompt has no side", R, '\tprompt:SetAttribute("Side", side)\n', ""),
    # the hold
    ("a quick trigger works", R, " or os.clock() - h.At < num(R.Hold, 3) - num(R.HoldSlack, 0.25) then return end", " then return end"),
    ("a trigger without a hold works", R, "\tif not h or h.Prompt ~= prompt or ", "\tif h and h.Prompt ~= prompt or "),
    # the rules
    ("another side may help", R, '\tif sideOf(helper) ~= d.Side then return "Side" end -- another side never (in PvP too)\n', ""),
    ("no range check", R, '\tif (rootOf(helper.Character).Position - d.Pos).Magnitude > num(R.Range, 6) + num(R.RangeSlack, 2) then return "Far" end\n', ""),
    ("a dead helper may help", R, '\tif not alive(helper) then return "Bad" end\n', ""),
    ("no cooldown", R, "\tST.LastAt[helper] = now\n", ""),
    ("no potion needed", R, "\tif not key or have < 1 then\n", "\tif not key then\n"),
    ("the potion is not used", R, "\tS.PlayerService.SetStat(helper, key, have - 1)\n", ""),
    ("after the wait it still works", R, " or os.clock() > d.Until then return \"Gone\" end", ' then return "Gone" end'),
    ("helping yourself", R, " or helper == target or ", " or "),
    ("no fame", R, "\t\tS.PlayerService.GrantFame(helper, stat, fame, { Revive = true })\n", ""),
    ("fame for the wrong side", R, 'local STAT = { Halo = "Honor", Horns = "Infamy" }', 'local STAT = { Halo = "Infamy", Horns = "Honor" }'),
    ("no respawn", R, "\tS.PlayerService.Respawn(target)\n\tlocal stat", "\tlocal stat"),
    # the spawn
    ("full HP after the help", R, "\thumanoid.Health = math.max(1, math.floor(humanoid.MaxHealth * math.clamp(num(R.HPPct, 0.3), 0.05, 1) + 0.5))\n", ""),
    ("the shield never cut", R, "\t\t\tif player.Character == character then pcall(pvp.BreakProtection, player) end\n", ""),
    ("the record never cleared", R, "\tlocal d = ST.Down[player]\n\tif not d then return end\n\tclear(player)\n", "\tlocal d = ST.Down[player]\n\tif not d then return end\n"),
    # skip / leave
    ("skip takes arguments", R, '\tif select("#", ...) ~= 0 or not isPlayer(player) then return end\n', "\tif not isPlayer(player) then return end\n"),
    ("skip for anyone", R, "\tif not d or d.Revived then return end\n\tclear(player)\n\tS.PlayerService.Respawn(player)",
     "\tclear(player)\n\tS.PlayerService.Respawn(player)"),
    ("leaving keeps the prompt", R, "\t\tclear(player)\n\t\tST.Hold[player], ST.LastAt[player] = nil, nil\n", "\t\tST.Hold[player], ST.LastAt[player] = nil, nil\n"),
    # wiring
    ("PlayerService never asks ReviveService", P, '{ "FirstKOService", "ReviveService" }', '{ "FirstKOService" }'),
    ("PlayerService asks ReviveService first", P, '{ "FirstKOService", "ReviveService" }', '{ "ReviveService", "FirstKOService" }'),
    ("Main: never started", M, '\t"ReviveService", -- 게임성 개발 2: 99N G (after PvPService', '\t"ReviveServiceX", -- 게임성 개발 2: 99N G (after PvPService'),
    ("Net: no ReviveSkip", N, '\t"ReviveSkip", -- 99N G', '\t"ReviveSkipX", -- 99N G'),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    rv = strip_comments(read(SSS / "ReviveService.luau"))
    check("<const>" not in rv, "no local x <const>")
    check("task.wait" not in rv and "task.spawn" not in rv, "ReviveService never yields (task.delay only)")
    check(rv.count("Revived = true") == 1, "one place marks a help (Try)")
    check("Config.PotionStockKey(" in rv, "the potion stock key comes from Config")
    return count, failures


SUITE = Suite(
    mark="REVIVE",
    fixture=ROOT / "tools/fixtures/revive_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-14/offline_dev2_revive_2026-10-14.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="99N G (계획 8): a KO (Halo / Horns / Neutral) with a living friend of the same side within Config.Revive.WaitNear "
             "(40) waits Wait (10 s) instead of RespawnTime (PlayerService getUp: FirstKOService first, then ReviveService.GetUp), "
             "with a ProximityPrompt (PromptName, G, Hold 3 s, Range 6, attributes Side / ReviveUserId) on the body and "
             "ReviveUntil (server time) + Fx ReviveWait { Sec }. A friend of the same side who held it Hold s (the hold's begin "
             "seen by the server), within Range + RangeSlack, alive, past Cooldown (10 s), with an HP potion: the potion is "
             "used, the KO'd player gets up at the body (Respawn + GetUp CFrame) with HPPct (30%) HP and the spawn shield cut "
             "at Shield (3 s); the helper gets Fame (1) Honor / Infamy (Neutral none, ctx Revive). Another side: never. "
             "c->s ReviveSkip(): up in town now.",
    limitations="Offline doubles: PlayerService (data rows, Respawn log, signals), FactionService, FirstKOService, PvPService, "
                "ProximityPromptService (signals fired by the checks), bodies as instance doubles. The real prompt on screen "
                "(shown to the same side only: 게임성 개발 1), the hold bar and a real respawn need a live Studio play.",
)

if __name__ == "__main__":
    run(SUITE)
