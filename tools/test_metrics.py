"""BB38 beta metrics (docs/design/beta_basics_2026-10-05.md BB38, 검수 2026-10-07 economy / friends,
docs/design/emergent_play_watch_2026-10-06.md §2), offline.

Runs the CURRENT Config, Util, TelemetryService and SettingsService plus ProgressionService's gold functions (cut out)
on tools/fixtures/dev2_kit.luau with tools/fixtures/metrics_offline.luau and the installed official Luau CLI: an
AnalyticsService double records every funnel step / custom event; the services TelemetryService listens to are signal
doubles. Static checks cover the one-line hooks in CombatService (KnockedOut), RankingService (Viewed), MonsterService
(Party / Others) and the gold sinks' reasons (ShopService, PvPService, KaijuService). No Studio, network, DataStore or
Roblox API calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_metrics.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-07/offline_dev2_metrics_2026-10-07.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, between, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "TELEMETRY_SOURCE": SSS / "TelemetryService.luau",
    "SETTINGS_SOURCE": SSS / "SettingsService.luau",
    "PROGRESSION_SOURCE": SSS / "ProgressionService.luau",
}
C, T, ST, P = "CONFIG_SOURCE", "TELEMETRY_SOURCE", "SETTINGS_SOURCE", "PROGRESSION_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = {k: sources[k] for k in ("CONFIG_SOURCE", "UTIL_SOURCE", "TELEMETRY_SOURCE", "SETTINGS_SOURCE")}
    prog = sources["PROGRESSION_SOURCE"]
    out["GOLD_EXTRACT"] = (
        "local Util, S, getData = ...\nlocal M = {}\nM.GoldEarned = Util.Signal.new()\n"
        + between(prog, "M.GoldSpent = Util.Signal.new()", "M.LeveledUp")
        + function_block(prog, "local function num(")
        + between(prog, "function M.AddCarriedGold(", "function M.GetTotalGold(")
        + "\nreturn M\n")
    return out


MUTATIONS = [
    # --- A23-68 #5: the first 3 minutes
    ("an auto skill counts as the first skill hit", T,
     "if type(info) == \"table\" and info.Auto ~= true and num(info.MonstersHit) >= 1 then",
     "if type(info) == \"table\" and num(info.MonstersHit) >= 1 then"),
    ("a skill that hit nothing counts", T, "info.Auto ~= true and num(info.MonstersHit) >= 1 then", "info.Auto ~= true then"),
    ("the smith visit is not watched", T,
     "\twatch(player, \"BlacksmithVisited\", function(v) if v == true then Step(player, \"ForgeArrive\") end end)\n", ""),
    ("old saves do not catch up kills", T, "\tif num(data.TotalKills) > 0 then\n", "\tif false then\n"),
    ("walking into the meadow does not count", T,
     "\t\tif newZone == \"SlimeMeadow\" then TelemetryService.Step(player, \"MeadowArrive\") end\n", ""),
    ("the guide's meadow step does not count", T, "\t\tif pastMeadow(v) then Step(player, \"MeadowArrive\") end\n", ""),
    # --- A23-74: the Forge step (3) comes before the meadow
    ("the Forge step counts as a meadow arrival", T,
     "\tlocal function pastMeadow(v) return v == tutSteps.Quest or v == tutSteps.Done end\n",
     "\tlocal function pastMeadow(v) return num(v) >= 2 end\n"),
    ("an old save catches up the Forge after the meadow", T,
     "\tif data.BlacksmithVisited == true then Step(player, \"ForgeArrive\") end\n"
     "\tif num(data.WeaponOwnedMask) > 0 then Step(player, \"FirstWeapon\") end -- A23-34: any weapon owned\n"
     "\tif pastMeadow(tut) then Step(player, \"MeadowArrive\") end\n",
     "\tif pastMeadow(tut) then Step(player, \"MeadowArrive\") end\n"
     "\tif data.BlacksmithVisited == true then Step(player, \"ForgeArrive\") end\n"
     "\tif num(data.WeaponOwnedMask) > 0 then Step(player, \"FirstWeapon\") end -- A23-34: any weapon owned\n"),
    ("Config: the Forge back after the first mission", C,
     "\"FirstMissionAccept\", \"ForgeArrive\", \"FirstWeapon\", \"MeadowArrive\",\n\t\t\"FirstHit\", \"FirstKill\", \"FirstMissionDone\",",
     "\"FirstMissionAccept\", \"MeadowArrive\",\n\t\t\"FirstHit\", \"FirstKill\", \"FirstMissionDone\", \"ForgeArrive\", \"FirstWeapon\","),
    ("no first kill", T, "\tTelemetryService.Step(player, \"FirstKill\") -- A23-68 #5\n", ""),
    ("Config: the old 8 steps", C,
     "\"FirstMissionAccept\", \"ForgeArrive\", \"FirstWeapon\", \"MeadowArrive\",\n\t\t\"FirstHit\", \"FirstKill\", \"FirstMissionDone\", \"FirstSkillHit\",",
     "\"FirstMissionAccept\",\n\t\t\"FirstMissionDone\", \"FirstWeapon\","),
    # --- A23-71 S13 (D5): the first skill comes at Lv5, after the first weapon and before Auto Battle
    ("Config: FirstSkillHit back before the first mission", C,
     "\"FirstKill\", \"FirstMissionDone\", \"FirstSkillHit\", \"AutoUnlocked\",",
     "\"FirstSkillHit\", \"FirstKill\", \"FirstMissionDone\", \"AutoUnlocked\","),
    ("an old save catches up the skill hit before the first mission", T,
     "\tif tut == 99 then Step(player, \"FirstMissionDone\") end\n"
     "\tlocal done = type(data.Story) == \"table\" and type(data.Story.Done) == \"table\" and data.Story.Done or {}\n"
     "\tif done.M1_3 or done.S0 then Step(player, \"FirstSkillHit\") end -- both need a manual skill that hit a monster\n",
     "\tlocal done = type(data.Story) == \"table\" and type(data.Story.Done) == \"table\" and data.Story.Done or {}\n"
     "\tif done.M1_3 or done.S0 then Step(player, \"FirstSkillHit\") end -- both need a manual skill that hit a monster\n"
     "\tif tut == 99 then Step(player, \"FirstMissionDone\") end\n"),
    # --- the funnel
    ("steps logged again on another server", T, "\tif tel.Funnel[name] then return end\n", ""),
    ("no Level10 step", T, "\twatch(player, \"Level\", function(v) if num(v, 1) >= 10 then Step(player, \"Level10\") end end)\n", ""),
    ("no catch-up for an old save", T, "\tif data.IntroSeen == true then Step(player, \"IntroDone\") end\n", ""),
    ("step numbers from 0", T, "pcall(svc.LogOnboardingFunnelStepEvent, svc, player, index, name)",
     "pcall(svc.LogOnboardingFunnelStepEvent, svc, player, index - 1, name)"),
    ("the funnel misses a step", C, "\"ForgeArrive\", \"FirstWeapon\", \"MeadowArrive\",", "\"ForgeArrive\", \"MeadowArrive\","),
    # --- events
    ("FirstDeath every KO", T, "\t\tif tel.FirstDeath then return end\n", ""),
    ("AutoOn / AutoOff not throttled", T, "if not throttled(player, \"auto\", 10) then", "if true then"),
    ("Plunder_* for any outcome", T, "\t\tif name then TelemetryService.Custom(thief, \"Plunder_\" .. name, num(total)) end\n",
     "\t\tTelemetryService.Custom(thief, \"Plunder_\" .. tostring(name or outcome), num(total))\n"),
    ("no KeyRebind", T, "\t\tTelemetryService.Custom(player, \"KeyRebind\", num(changed, 1))\n", ""),
    ("a streak logged every kill", T, "and not st.Logged[st.Kind] then", "then"),
    ("the streak never resets", T, "if info.Kind == st.Kind then st.N += 1 else st.Kind, st.N = info.Kind, 1 end",
     "st.N += 1; st.Kind = info.Kind"),
    # --- windows
    ("any window id", T, "if type(id) ~= \"string\" or not T.UiIds[id] then return end", "if type(id) ~= \"string\" then return end"),
    ("UiMetric extra arguments", T, "\tif select(\"#\", ...) ~= 1 then return end\n\tlocal id = ...\n", "\tlocal id = ...\n"),
    ("UiMetric without a rate limit", T, "\tif not Util.RateLimit(player, \"UiMetric\", num(Config.RateLimits.UiMetric, 2)) then return end\n", ""),
    ("a window counted every open", T, "\tif not s or s.Windows[id] then return end\n", "\tif not s then return end\n"),
    ("UiMetric before ready", T, "\tif not S.PlayerService.IsReady(player) then return end\n\tif not Util.RateLimit(player, \"UiMetric\"",
     "\tif not Util.RateLimit(player, \"UiMetric\""),
    # --- return acts
    ("return acts for a first session too", T, "Returning = before >= 1,", "Returning = true,"),
    ("more than 3 return acts", T, "s.Acts >= math.floor(num(A.ReturnActs, 3))", "s.Acts >= 99"),
    ("unknown zones as return acts", T, "if type(newZone) == \"string\" and Config.Zones[newZone] then returnAct(", "if type(newZone) == \"string\" then returnAct("),
    # --- session sums
    ("no GoldIn", T, "\t\tfor source, gold in s.GoldIn do Custom(player, \"GoldIn\", gold, source) end\n", ""),
    ("GoldOut ignored", T, "if s and type(sink) == \"string\" then s.GoldOut[sink] = (s.GoldOut[sink] or 0) + math.max(0, num(amount)) end",
     "local _ = s"),
    ("solo kills counted together", T, "if num(info.Party, 1) >= 2 then s.Together += 1 end", "s.Together += 1"),
    ("a stranger counted as a friend", T, "if typeof(o) == \"Instance\" and isFriend(player, o) then",
     "if typeof(o) == \"Instance\" then"),
    ("away counted without the 5 minutes", T, "if os.clock() - own >= num(A.AwayAfter, 300) then s.AwayMin += 1 end", "s.AwayMin += 1"),
    ("away counted with auto off", T, "\t\t\tif p:GetAttribute(\"AutoCombatEnabled\") == true then\n", "\t\t\tif true then\n"),
    ("friend minutes with anyone here", T, "\t\t\t\tif q ~= p and q.Parent and isFriend(p, q) then\n", "\t\t\t\tif q ~= p and q.Parent then\n"),
    ("IsFriendsWith asked again for a known pair", T,
     "if other ~= player and other.Parent ~= nil and T.Friend[pairKey(player, other)] == nil then",
     "if other ~= player and other.Parent ~= nil then"),
    ("no zone minutes", T, "\t\tfor zone, minutes in s.ZoneMin do Custom(player, \"ZoneMinutes\", minutes, zone) end\n", ""),
    ("no ranking views", T, "\t\tfor board, views in s.Rankings do Custom(player, \"RankingViews\", views, board) end\n", ""),
    ("enhance success counted as a fail", T, "if success == false then T.EnhanceFailAt[player] = os.clock() end",
     "T.EnhanceFailAt[player] = os.clock()"),
    ("enhance fail leave at any time", T, "if failAt and os.clock() - failAt <= num(A.EnhanceFailLeave, 300) then", "if failAt then"),
    ("session minutes bucket off", T, "minutes < 15 and \"5-15\"", "minutes < 10 and \"5-15\""),
    # --- debug
    ("prints on a live server", T, "\t\t\tT.Debug = ok and studio == true\n", "\t\t\tT.Debug = true\n"),
    ("no prints in Studio", T, "\tif debugOn() then\n\t\tprint(string.format(\"[Metrics] %s", "\tif false then\n\t\tprint(string.format(\"[Metrics] %s"),
    # --- the services' new signals
    ("SpendGold fires no GoldSpent", P, "\tM.GoldSpent:Fire(player, amount, type(reason) == \"string\" and reason or \"Other\")\n", ""),
    ("TakeCarriedGold fires no GoldSpent", P, "\t\tM.GoldSpent:Fire(player, taken, type(reason) == \"string\" and reason or \"Taken\")\n", ""),
    ("KeysChanged on any blob", ST, "\t\tif changed > 0 then SettingsService.KeysChanged:Fire(player, changed) end\n",
     "\t\tSettingsService.KeysChanged:Fire(player, changed)\n"),
    ("KeysChanged misses removed keys", ST, "\t\tfor id in before do if after[id] == nil then changed += 1 end end\n", ""),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    combat = read(SSS / "CombatService.luau")
    hit = function_block(combat, "local function damageMonster(")
    check("CombatService.MonsterHit = Util.Signal.new()" in combat
          and hit.find("S.MonsterService.DamageMonster(") < hit.find("CombatService.MonsterHit:Fire(player, rec, killed)"),
          "CombatService.damageMonster fires MonsterHit(player, rec, killed) after the damage (A23-68 #5)")
    ko = function_block(combat, "local function sendKO(")
    check(ko.find("Net.Fx(victim, \"KO\"") < ko.find("CombatService.KnockedOut:Fire(victim, by)"),
          "CombatService.sendKO fires KnockedOut(victim, by) with the KO screen's cause")
    ranking = read(SSS / "RankingService.luau")
    req = function_block(ranking, "local function onRequest(")
    check("RankingService.Viewed:Fire(player, board, scope)" in req, "RankingService fires Viewed when it answers RequestRankings")
    monster = read(SSS / "MonsterService.luau")
    check("i.Party, i.Others = #eligible, {}" in monster and "if o.Player ~= e.Player then table.insert(i.Others, o.Player) end" in monster,
          "MonsterKilled info carries Party (eligible count) and Others (the other eligible players)")
    shop = read(SSS / "ShopService.luau")
    check('SpendGold(player, price, "Weapon")' in shop and 'SpendGold(player, price * amount, "Potion")' in shop,
          "the shop tags its gold sinks (Weapon, Potion)")
    pvp = read(SSS / "PvPService.luau")
    check(pvp.count('"Penalty")') == 2 and 'TakeCarriedGold(victim, stolen, "Plunder")' in pvp, "PvP tags plunder and penalties")
    kaiju = read(SSS / "KaijuService.luau")
    check(kaiju.count('"TakeCarriedGold", ') == 3 and kaiju.count('carried, "Kaiju")') == 3, "the kaiju tags its three gold takes")
    net = read(SHARED / "Net.luau")
    check(net.count('"UiMetric"') == 1, "Net.Names has UiMetric once")
    tel = read(SSS / "TelemetryService.luau")
    # A23-71 S13: the fallback list (no Config.Analytics) keeps the same 13 steps in the same order
    config = read(SHARED / "Config.luau")
    names = re.compile(r'"(\w+)"')
    cfg_steps = re.search(r"^Config\.Analytics = \{.*?\n\tSteps = \{(.*?)\}", config, re.S | re.M)
    tel_steps = re.search(r"\tSteps = A\.Steps or \{(.*?)\}", tel, re.S)
    check(bool(cfg_steps and tel_steps) and names.findall(cfg_steps.group(1)) == names.findall(tel_steps.group(1))
          and len(names.findall(tel_steps.group(1))) == 13,
          "TelemetryService's fallback funnel = Config.Analytics.Steps (13 steps, same order)")
    code = strip_comments(tel).replace("tostring(player.UserId)", "").replace("local x, y = a.UserId, b.UserId", "")
    check("UserId" not in code.replace("other.UserId", ""), "no UserId is ever logged (only throttle keys and the friend cache)")
    return count, failures


SUITE = Suite(
    mark="METRICS",
    fixture=ROOT / "tools/fixtures/metrics_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-07/offline_dev2_metrics_2026-10-07.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="BB38: the onboarding funnel (Config.Analytics.Steps, 13 steps in order with A23-68's first 3 minutes, "
             "A23-71 S13's FirstSkillHit after FirstWeapon, before AutoUnlocked, and A23-74's ForgeArrive / FirstWeapon "
             "right after FirstMissionAccept, before MeadowArrive (TutorialStep 3 = the Forge step is an acceptance, not a "
             "meadow arrival); once per account, old saves catch up in that order), "
             "c->s UiMetric(id) -> WindowOpen_<id> (Config.Analytics.UiIds, one argument, ready, 2 s, once a session), "
             "KeyRebind (SettingsService.KeysChanged), AutoOn / AutoOff, FirstDeath_<By> (CombatService.KnockedOut, once "
             "per account), Plunder_Kept / _Avenged / _Returned, EnhanceFailLeave (a failed enhance then a leave within "
             "300 s), SameKindStreak (30 in a row, once a session per kind), ReturnAct (a returning player's first 3 zone / "
             "window actions); at leave: SessionMinutes, AutoAwayMinutes (auto ON, no own action for 300 s), GoldIn / "
             "GoldOut per source / sink (ProgressionService.GoldEarned / GoldSpent with reasons), FriendMinutes, "
             "KillsTogether / KillsWithFriend (MonsterKilled Party / Others, IsFriendsWith once per pair), ZoneMinutes, "
             "RankingViews. No names, UserIds or free text; Studio prints every call ([Metrics]).",
    limitations="The real AnalyticsService dashboard and its limits are not reached offline. The client's UiMetric sends "
                "(Panels, the Tab list) are game dev 1's. The 5-minute loop (HighLevelInMeadow, ServerPopulation) is not "
                "stepped here (unchanged).",
)

if __name__ == "__main__":
    run(SUITE)
