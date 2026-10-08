"""A23-79 다시 오게 만들기, the server's part (게임성 개발 3, 2026-10-08), offline.

Runs the CURRENT Config, Util, ReturnService (pause card, welcome back, My Way, badges, the notification opt-in moment),
InviteService (invite joins, Go to friend), DiaryService (King Diary, candy jar) and TitleService on
tools/fixtures/dev2_kit.luau + tools/fixtures/dev3_world.luau with tools/fixtures/return_offline.luau and the installed
official Luau CLI. QuestService.PinnedRow, the new story / war / king signals, BadgeService and ZoneService.Travel are
doubles. Static checks: the remotes, the service lists, the small hooks in WarService / HalloweenService /
StoryQuestService / QuestService / LootService. No Studio, network, DataStore or Roblox API calls; mutations run on
in-memory copies of the sources only.

Usage: py tools/test_return.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-08/offline_dev3_return_2026-10-08.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "RETURN_SOURCE": SSS / "ReturnService.luau",
    "INVITE_SOURCE": SSS / "InviteService.luau",
    "DIARY_SOURCE": SSS / "DiaryService.luau",
    "TITLE_SOURCE": SSS / "TitleService.luau",
}
C, R, I, D = "CONFIG_SOURCE", "RETURN_SOURCE", "INVITE_SOURCE", "DIARY_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # --- #1 pause card / welcome back
    ("a card for every main quest", R, "\tif T.ChapterEnd[id] then queueCard(player, \"Chapter\") end\n", "\tqueueCard(player, \"Chapter\")\n"),
    ("the first main of a chapter counts as its end", R, "\t\tif ch and ch > 0 then last[ch] = id end\n",
     "\t\tif ch and ch > 0 and not last[ch] then last[ch] = id end\n"),
    ("no gap between cards", R, "\tif T.CardAt[player] and now - T.CardAt[player] < num(R.MinGap, 120) then return end\n", ""),
    ("a card in the middle of a fight", R, "\tif inCombat(player) then\n", "\tif false then\n"),
    ("the card comes at once (old goal)", R, "\ttask.delay(num(R.CardDelay, 1.5), sendCard, player, why, 0)\n", "\tsendCard(player, why, 0)\n"),
    ("a daily card on every claim", R, "\tif math.floor(num(player:GetAttribute(\"DailyClaims\"))) == slots then queueCard(player, \"Daily\") end\n",
     "\tif math.floor(num(player:GetAttribute(\"DailyClaims\"))) >= 1 then queueCard(player, \"Daily\") end\n"),
    ("a war card without war points", R, "\t\tif typeof(player) == \"Instance\" and player.Parent ~= nil and num(points) >= minPoints then\n",
     "\t\tif typeof(player) == \"Instance\" and player.Parent ~= nil then\n"),
    ("a war card in the first minutes", R, "now - joined >= num(W.MinSession, 900) and", "true and"),
    ("a war card every round", R, "(last == nil or now - last >= num(W.MinGap, 1800))", "true"),
    ("a war card for an idle round", R, "\tif mode == \"Idle\" or type(snapshot) ~= \"table\" then return end\n",
     "\tif type(snapshot) ~= \"table\" then return end\n"),
    ("no tomorrow line", R, "\t\tpayload.Tomorrow = TXT.TomorrowDaily or \"New dailies\"\n", ""),
    ("the diary line ignored", R, "\t\t\tif ok and type(line) == \"string\" and line ~= \"\" then payload.Tomorrow = line end\n", ""),
    ("welcome back after 5 hours", R, "num(R.WelcomeAfter, 6 * 3600)", "num(R.WelcomeAfter / 2, 6 * 3600)"),
    ("welcome back for a brand-new save", R, "\tif last > 0 and os.time() - last >= num(R.WelcomeAfter, 6 * 3600)",
     "\tif os.time() - last >= num(R.WelcomeAfter, 6 * 3600)"),
    ("welcome back before the first mission", R, "\t\tand num(data.TutorialStep) == 99 then\n", "\t\tthen\n"),
    ("welcome back at once", R, "\t\ttask.delay(num(R.WelcomeDelay, 4), welcomeBack, player)\n", "\t\twelcomeBack(player)\n"),
    ("[Go] into the other side's town", R,
     "\t\treturn Config.HomeZoneId(player:GetAttribute(\"Faction\")) == zoneId and \"Home\" or nil\n", "\t\treturn zoneId\n"),
    ("[Go] past a level gate", R, "\tif num(player:GetAttribute(\"Level\"), 1) < num(zone.MinLevel, 1) then return nil end\n", ""),
    ("[Go] into a seasonal field", R, "\tif zone.Season ~= nil then\n\t\tzoneId = R.SeasonFallback or \"SlimeMeadow\"\n",
     "\tif false then\n\t\tzoneId = R.SeasonFallback or \"SlimeMeadow\"\n"),
    ("landmarks ignored", R, "\tlocal pos = type(marks) == \"table\" and marks[guide] or nil\n", "\tlocal pos = nil\n"),
    ("the long text over the short name", R,
     "\tlocal text = (type(row.ShortName) == \"string\" and row.ShortName ~= \"\") and row.ShortName or row.Text\n",
     "\tlocal text = row.Text or row.ShortName\n"),
    # --- #2 My Way
    ("My Way from one pick", R, "\tif total < num(MW.MinPicks, 2) then return \"\" end\n", ""),
    ("no Balance Walker", R, "\tif math.abs(lean) <= math.floor(total * num(MW.BalanceShare, 0.2)) then return \"BalanceWalker\" end\n", ""),
    ("Horns names swapped", R, "\treturn lean < 0 and \"ProudRascal\" or \"SoftDevil\"\n", "\treturn lean > 0 and \"ProudRascal\" or \"SoftDevil\"\n"),
    ("named picks ignored", R, "\t\t\tif pick == ((obj.Good and obj.Good.Pick) or \"Good\") then return \"Good\" end\n", ""),
    ("a Neutral name", R, "\tif faction ~= \"Halo\" and faction ~= \"Horns\" then return \"\" end\n", ""),
    ("My Way not refreshed on a pick", R, "\tconnect(\"StoryQuestService\", \"Picked\", function(player) refreshMyWay(player) end)\n", ""),
    # --- #2 badges
    ("badge id 0 asked anyway", R, "\t\tif id > 0 and r.Badges[key] == nil", "\t\tif r.Badges[key] == nil"),
    ("a badge asked again and again", R, "\t\tif id > 0 and r.Badges[key] == nil", "\t\tif id > 0"),
    ("a failed badge is saved as awarded", R, "\t\tif ok then\n\t\t\tlocal data = S.PlayerService.GetData(player)\n",
     "\t\tif true then\n\t\t\tlocal data = S.PlayerService.GetData(player)\n"),
    ("a failed badge retried at once", R, "(retry == nil or os.clock() - retry >= num(B.RetrySeconds, 300))", "true"),
    ("the first weapon is Stronger!", R, "bit32.band(mask, bit32.bnot(1)) ~= 0", "mask ~= 0"),
    ("Rank 2 at rank 1", R, "\t\treturn num(rank) >= 2\n", "\t\treturn num(rank) >= 1\n"),
    ("Halloween after the season", R, "season.Enabled == false or os.time() >= num(season.EndsAt, 0) then return end",
     "season.Enabled == false then return end"),
    ("no catch-up at join", R, "\trefreshMyWay(player)\n\tcheckBadges(player)\n", "\trefreshMyWay(player)\n"),
    # --- #5 opt-in
    ("opt-in in the first 10 minutes", R, "\tif num(data.PlaytimeSeconds) < num(N.MinPlaySeconds, 600) then return false end\n", ""),
    ("opt-in right after a KO", R, "\t\tif at and now - at < calm then return false end\n", ""),
    ("opt-in twice a session", R, "\tif not data or T.OptInSent[player] then return false end\n", "\tif not data then return false end\n"),
    ("opt-in again after shown", R, "\tif r.OptIn == \"shown\" then return false end\n\tif r.OptIn == \"cannot\"",
     "\tif r.OptIn == \"cannot\""),
    ("cannot is never asked again", R, "os.time() - r.OptInAt < num(N.RetryCannot, 30 * 86400)", "true"),
    ("the card's opt-in also as its own Fx", R, "\tif not inCard then fx(player, \"OptInMoment\", { Why = why }) end\n",
     "\tfx(player, \"OptInMoment\", { Why = why })\n"),
    ("an unknown opt-in result saved", R, "\tif not data or (result ~= \"shown\" and result ~= \"cannot\") then return end\n",
     "\tif not data then return end\n"),
    ("no asked list", R, "\t\tlocal ok, err = pcall(store.SetAsync, store, tostring(userId), { At = os.time() })\n", "\t\tlocal ok, err = true, nil\n"),
    # --- #3 invites
    ("text LaunchData accepted", I, "not string.match(raw, \"^%d+$\") then return nil end", "false then return nil end"),
    ("my own id as an invite", I, "id ~= math.floor(id) or id == player.UserId then return nil end", "id ~= math.floor(id) then return nil end"),
    ("the last invite overwrites the first", I, "\t\tif type(data.Invite) ~= \"table\" or type(data.Invite.By) ~= \"number\" then\n",
     "\t\tif true then\n"),
    ("PlayedTogether every minute after 10", I, "and not T.Logged[key] then\n", "then\n"),
    ("PlayedTogether at once", I, "\t\t\tif T.Together[key] >= num(I.TogetherMinutes, 10)", "\t\t\tif T.Together[key] >= 1"),
    ("Go to a stranger", I, "\tif not isFriend(player, friend) then return end\n", ""),
    ("a sprout sent into PvP", I, "\tif target and target.PvP == true and num(player:GetAttribute(\"Level\"), 1) < rookie then\n",
     "\tif false then\n"),
    ("Go into the other side's town", I, "\t\tif home ~= zoneId then return nil, TXT.OtherTown end\n", ""),
    ("Go skips the travel rules (instant)", I, "pcall(S.ZoneService.Travel, player, dest, false)", "pcall(S.ZoneService.Travel, player, dest, true)"),
    ("Go without a rate limit", I, "\tif not Util.RateLimit(player, \"GoToFriend\", num(Config.RateLimits.GoToFriend, 3)) then return end\n", ""),
    ("Go accepts a string id", I, "\tif type(userId) ~= \"number\" or userId ~= userId", "\tif userId ~= userId"),
    ("Go to a seasonal field itself", I, "\tif zone.Season ~= nil then\n\t\tzoneId = I.SeasonZone or \"SlimeMeadow\"\n",
     "\tif false then\n\t\tzoneId = I.SeasonZone or \"SlimeMeadow\"\n"),
    ("the invite pair needs a friend call", I, "\tif T.By[player] == other.UserId or T.By[other] == player.UserId then return true end\n", ""),
    # --- #4 diary / candy jar
    ("pages past today's", D, "\tif d.Pages >= today then return end\n", "\tif d.Pages >= PAGES then return end\n"),
    ("pages after the season", D, "\tif not seasonOn(now) then return end\n\tlocal d = record(data)\n\tlocal today", "\tlocal d = record(data)\n\tlocal today"),
    ("no opt-in after page 1", D, "\t\tif type(ret) == \"table\" and type(ret.OptInMoment) == \"function\" then pcall(ret.OptInMoment, player, \"Diary\") end\n", ""),
    ("late never flagged", D, "\tlocal late = page < today -- catching up a day already past\n", "\tlocal late = false\n"),
    ("the jar takes candy for an owned title", D,
     "\tif type(titles) == \"table\" and type(titles.Owns) == \"function\" and titles.Owns(player, e.Title) then\n", "\tif false then\n"),
    ("the jar closes after the season", D, "\tlocal e = jarEntry(id)\n", "\tif not seasonOn(os.time()) then return end\n\tlocal e = jarEntry(id)\n"),
    ("the jar ignores the cost", D, "\tlocal ok, taken = pcall(loot.TakeItem, player, \"Candy\", cost)\n", "\tlocal ok, taken = true, true\n"),
    ("the jar accepts two arguments", D, "\tif select(\"#\", ...) ~= 1 then return end\n\tlocal id = ...\n\tif type(id) ~= \"string\" or #id > 32",
     "\tlocal id = ...\n\tif type(id) ~= \"string\" or #id > 32"),
    # --- Config
    ("Config: welcome back after 1 hour", C, "\tWelcomeAfter = 6 * 3600,", "\tWelcomeAfter = 3600,"),
    ("Config: Pumpkin Pal for 5 candy", C, "{ Id = \"PumpkinPal\", Title = \"PumpkinPal\", Candy = 50 }", "{ Id = \"PumpkinPal\", Title = \"PumpkinPal\", Candy = 5 }"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    net = read(SHARED / "Net.luau")
    for name in ("GoToFriend", "CandyTrade"):
        check(net.count(f'"{name}"') == 1, f"Net.Names has {name} once")
    main = read(SSS / "Main.server.luau")
    names = re.compile(r'"(\w+)"')
    init = names.findall(re.search(r"local INIT_ORDER = \{(.*?)\n\}", main, re.S).group(1))
    start = names.findall(re.search(r"local START_ORDER = \{(.*?)\n\}", main, re.S).group(1))
    for svc in ("ReturnService", "InviteService", "DiaryService"):
        check(init.count(svc) == 1 and start.count(svc) == 1 and start.index(svc) < start.index("PlayerService")
              and (SSS / f"{svc}.luau").is_file(), f"{svc}: file + both lists, started before PlayerService")
    check(start[-1] == "PlayerService" and sorted(init) == sorted(start), "PlayerService last, the lists match")
    war = read(SSS / "WarService.luau")
    end_round = function_block(war, "local function endRound(")
    check("WarService.RoundEnded = Util.Signal.new()" in war and "WarService.RoundEnded:Fire(winner, mode, snapshot)" in end_round,
          "WarService.endRound fires RoundEnded(winner, mode, snapshot)")
    hw = read(SSS / "HalloweenService.luau")
    fin = function_block(hw, "local function finish(")
    check("HalloweenService.KingDefeated = Util.Signal.new()" in hw
          and fin.find("if defeated and type(rec) == \"table\" then") < fin.find("HalloweenService.KingDefeated:Fire(b.Key, rec.Kind, table.clone(ids))"),
          "HalloweenService.finish fires KingDefeated only for a beaten king, with the paid UserIds")
    sq = read(SSS / "StoryQuestService.luau")
    comp = function_block(sq, "local function complete(")
    act = function_block(sq, "local function onStoryAction(")
    check("StoryQuestService.QuestDone:Fire(player, id)" in comp and comp.find("st.Done[id] = true") < comp.find("QuestDone:Fire"),
          "StoryQuestService.complete fires QuestDone after Done is saved")
    check("StoryQuestService.Picked:Fire(player, id, st.Pick[id])" in act
          and act.find("StoryQuestService.Picked:Fire") < act.find("advance(player, data, id, tr)\n\t\tif type(reply)"),
          "onStoryAction fires Picked after the pick is saved, before advancing")
    qs = read(SSS / "QuestService.luau")
    check("function M.PinnedRow(player)" in qs, "QuestService.PinnedRow exists")
    loot = read(SSS / "LootService.luau")
    take = function_block(loot, "function LootService.TakeItem(")
    check("if have < n then return false end" in take and "publish(player, data)" in take, "LootService.TakeItem: never below 0, pushes the bag")
    for path in ("ReturnService.luau", "InviteService.luau", "DiaryService.luau"):
        code = strip_comments(read(SSS / path))
        check(not re.search(r"[가-힣]", code), f"{path}: no Korean outside comments")
        check("Reward" not in code or path != "InviteService.luau", "InviteService pays nothing")
    inv = strip_comments(read(SSS / "InviteService.luau"))
    check("AddBankGold" not in inv and "GrantItem" not in inv and "AddXP" not in inv, "no invite reward of any kind (A23-68)")
    return count, failures


SUITE = Suite(
    mark="RETURN",
    fixture=ROOT / "tools/fixtures/return_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-08/offline_dev3_return_2026-10-08.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-79 server: Fx PauseCard { Why Chapter|Daily|War, Next = the pinned row's short name, Zone = a Travel "
             "destination I may enter (Home for my town, none for the other side's / a gated zone, seasonal -> meadow), "
             "Tomorrow (daily: the King Diary page while one waits), OptIn? } 1.5 s after a chapter's last main quest / the "
             "day's last daily claim / a war round I scored in after 15 min of play (one war card in 30 min), 120 s apart, "
             "waits out a fight; Fx WelcomeBack { Next, Zone } 4 s after a join 6 h+ after the last leave (first mission "
             "done); attribute MyWay from the story picks (2+ picks, a fifth = Balance Walker, Halo True Knight / Rebel "
             "Angel, Horns Proud Rascal / Soft-Hearted Devil, Neutral none); 8 badges via BadgeService (id 0 never asked, "
             "saved once, failures retried after 300 s, caught up at join); the opt-in moment once (10 min played, 60 s "
             "after a KO / failed scroll / purchase prompt, 'cannot' again after 30 days, a shown prompt -> the asked "
             "DataStore list); invite joins from LaunchData (digits, not mine, the first kept) + PlayedTogether at 10 "
             "minutes; GoToFriend(userId): ready, 3 s, a friend / invite pair here, PvP zones only from Lv15, never the "
             "other town, ZoneService.Travel with the channel; King Diary pages per king beaten together up to today's "
             "page in the season, page 9 title once; candy jar titles for candy, after the season too.",
    limitations="The cards / book / jar windows and the opt-in prompt are client work (game dev 1; PauseCard.luau exists). "
                "BadgeService ids are made by the user at publishing. The real QuestService / StoryQuestService / WarService "
                "/ HalloweenService run in their own suites; here their new signals are doubles (static checks cover the "
                "hooks).",
)

if __name__ == "__main__":
    run(SUITE)
