"""BB10 weekly rankings (RankingService) and the one weekly settle of A23-22 / A23-23 / A23-24, offline.

Runs the CURRENT Config, Util, RankingService, AnnounceService, PvPService, GrudgeService, TitleService, LootService,
CombatService and ProgressionService sources (whole modules) plus the PlayerService fame / activity functions and the
CharacterVisuals nametag function (extracted) in tools/fixtures/ranking_offline.luau on tools/fixtures/dev2_kit.luau,
with the installed official Luau CLI. No Studio, network, DataStore or Roblox API calls: Players, ordered / standard
DataStores (budgets, failure injection, a second server sharing the stores), UserService, IsFriendsWith, task and the
clocks are doubles. Mutations run on in-memory copies of the sources only.

Spec: docs/design/ranking_service_plan_2026-10-06.md (§10 list, §12-A decisions D1-D6), docs/SPEC_ADDENDUM.md A23-22 /
A23-23 / A23-24, docs/design/beta_basics_2026-10-05.md "### BB10." (2026-10-06 notes).
Usage: py tools/test_ranking.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_ranking_2026-10-06.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, between, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "RANKING_SOURCE": SSS / "RankingService.luau",
    "ANNOUNCE_SOURCE": SSS / "AnnounceService.luau",
    "PVP_SOURCE": SSS / "PvPService.luau",
    "GRUDGE_SOURCE": SSS / "GrudgeService.luau",
    "TITLE_SOURCE": SSS / "TitleService.luau",
    "LOOT_SOURCE": SSS / "LootService.luau",
    "COMBAT_SOURCE": SSS / "CombatService.luau",
    "PROGRESSION_SOURCE": SSS / "ProgressionService.luau",
    "PLAYER_SOURCE": SSS / "PlayerService.luau",
    "VISUALS_SOURCE": SSS / "CharacterVisuals.luau",
    "KAIJU_SOURCE": SSS / "KaijuService.luau",
}
WHOLE = ("CONFIG_SOURCE", "UTIL_SOURCE", "RANKING_SOURCE", "ANNOUNCE_SOURCE", "PVP_SOURCE", "GRUDGE_SOURCE",
         "TITLE_SOURCE", "LOOT_SOURCE", "COMBAT_SOURCE", "PROGRESSION_SOURCE", "KAIJU_SOURCE")


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = {k: sources[k] for k in WHOLE}
    player = sources["PLAYER_SOURCE"]
    out["PLAYER_FAME_SOURCE"] = (
        "local PlayerService, S, ready, loopWarn = ...\nlocal lastActive, lastOwn = {}, {}\n"
        + function_block(player, "function PlayerService.GrantFame(")
        + between(player, "function PlayerService.MarkActive(", "-- CR-M2: true once BindToClose started")
        + "\nreturn PlayerService\n")
    visuals = sources["VISUALS_SOURCE"]
    # A23-75 VIP: updateNametag calls CROWN.Place (the table and its two functions come along)
    crown_at = visuals.find("local CROWN = {")
    crown_end = visuals.find("\n}\n", crown_at)
    if crown_at < 0 or crown_end < 0:
        raise ValueError("CharacterVisuals CROWN table missing; update the test extractor.")
    out["NAMETAG_SOURCE"] = (
        "local Config, Util = ...\nlocal NEUTRAL_ID = \"Neutral\"\nlocal NEUTRAL_EMBLEM = \"A\"\n"
        + visuals[crown_at:crown_end + 3]
        + function_block(visuals, "function CROWN.Part(") + function_block(visuals, "function CROWN.Place(")
        + "".join(function_block(visuals, f"local function {name}(") for name in
                  ("attrNum", "attrStr", "getFaction", "getClass", "factionColor", "esc", "nametagOffset", "updateNametag"))
        + "\nreturn updateNametag\n")
    return out


R, P, G, L, C, PR, CO, PL, T, V = ("RANKING_SOURCE", "PVP_SOURCE", "GRUDGE_SOURCE", "LOOT_SOURCE", "CONFIG_SOURCE",
                                   "PROGRESSION_SOURCE", "COMBAT_SOURCE", "PLAYER_SOURCE", "TITLE_SOURCE", "VISUALS_SOURCE")
A, K = "ANNOUNCE_SOURCE", "KAIJU_SOURCE"

MUTATIONS = [
    # --- RankingService: the fair-point check (PvPCreditOK) and the KO verdict (JudgeKO)
    ("Bold < 1 never refused", R, 'if (tonumber(facts.Bold) or 1) < 1 then return "Weak" end', 'if false then return "Weak" end'),
    ("fresh spawn not checked", R, 'if facts.Fresh == true then return "Fresh" end', ""),
    ("repeat KOs not checked", R, 'if facts.Repeated == true then return "Repeated" end', ""),
    ("idle window ignored", R, "if last <= 0 or os.clock() - last > R.VictimActiveSeconds then return \"Idle\" end",
     "if last <= 0 then return \"Idle\" end"),
    ("idle check reads GetLastActive (hits count)", R, "local fn = PS.GetLastOwnActive or PS.GetLastActive", "local fn = PS.GetLastActive"),
    ("victim account age ignored", R, "((tonumber(victim.AccountAge) or 0) < R.PvPMinVictimAccountDays\n\t\tor ", "(false\n\t\tor "),
    ("victim playtime ignored", R, "or (tonumber(vdata and vdata.PlaytimeSeconds) or 0) < R.PvPMinVictimPlaytime)", "or false)"),
    ("newbie check also in STUDIO", R, 'if RankingService.EffectiveSeason() ~= "STUDIO" and ((tonumber(victim.AccountAge)',
     "if ((tonumber(victim.AccountAge)"),
    ("per-victim week cap off by one", R, ">= R.MaxCreditPerVictimPerWeek then", "> R.MaxCreditPerVictimPerWeek then"),
    ("victim daily yield cap ignored", R, "and vrank.YieldN >= R.MaxYieldPerVictimPerDay then return \"YieldCap\" end",
     "and false then return \"YieldCap\" end"),
    ("friend check skipped", R, 'if RankingService.EffectiveSeason() ~= "STUDIO" and friends(killer, victim, facts.NoYield == true) then',
     "if false then"),
    ("IsFriendsWith error cached", R, "\tif not ok then return true end\n\tST.Friends[key] = res == true",
     "\tif not ok then ST.Friends[key] = true; return true end\n\tST.Friends[key] = res == true"),
    ("PlayerLeaving asks the web (NoYield ignored)", R, "\tif noYield then return true end\n", ""),
    ("revenge not exempt", R, '(facts.Revenge == true and "Revenge") or ', ""),
    ("Wanted victim not exempt", R, '(facts.VictimWanted == true and "Wanted")', '(false and "Wanted")'),
    ("bully victim not exempt", R, '(facts.VictimBully == true and "Bully")', '(false and "Bully")'),
    ("outlaw victim not exempt", R, '(facts.VictimOutlaw == true and "Outlaw")', '(false and "Outlaw")'),
    ("kaiju victim not exempt", R, '(facts.VictimKaiju == true and "Kaiju")', '(false and "Kaiju")'),
    ("kaiju killer not exempt", R, '(facts.KillerKaiju == true and "KillerKaiju")', '(false and "KillerKaiju")'),
    ("sack thief not exempt", R, '(facts.VictimHadSack == true and "Sack")', '(false and "Sack")'),
    ("self-defense not exempt", R, '(facts.Defense == true and "Defense")', '(false and "Defense")'),
    ("YieldCap counted as unfair", R, "local UNFAIR = { Weak = true,", "local UNFAIR = { YieldCap = true, Weak = true,"),
    ("3 KOs in 10 min not on the PvP board", R, "local UNFAIR = { Weak = true, Fresh = true, Repeated = true,",
     "local UNFAIR = { Weak = true, Fresh = true,"),
    ("overlapping reasons count twice", R, '\t\tRankingService.Credit(killer, "PvP", 1, reason)\n',
     '\t\tRankingService.Credit(killer, "PvP", 1, reason)\n\t\tif facts.Fresh == true and facts.Repeated == true then '
     'RankingService.Credit(killer, "PvP", 1, reason) end\n'),
    ("private servers still judged fair", R, 'if game.PrivateServerId ~= "" then return "Private" end', ""),
    ("a killer at WeekCap still uses fair counters", R,
     'if cap and (ensureWeek(killer, kdata)[board] or 0) >= cap then return "WeekCap" end', ""),
    ("unfair KO worth 2", R, 'RankingService.Credit(killer, "PvP", 1, reason)', 'RankingService.Credit(killer, "PvP", 2, reason)'),
    ("exempt KOs still unfair", R, "if exempt == nil and UNFAIR[reason] then", "if UNFAIR[reason] then"),
    # --- RankingService: credits
    ("D1 story / goose fame reaches the board", R, 'if type(ctx) ~= "table" then return false end',
     'if type(ctx) ~= "table" then ctx = { PvP = true, Fair = true } end'),
    ("unfair PvP fame credited", R, "if ctx.PvP == true and ctx.Fair == true then", "if ctx.PvP == true then"),
    ("CommitFair never called", R, 'if ok and typeof(ctx.Victim) == "Instance" then RankingService.CommitFair(player, ctx.Victim) end', ""),
    ("paid sack credits n instead of RankPoints", R, 'return RankingService.Credit(player, board, ctx.RankPoints, "Sack")',
     'return RankingService.Credit(player, board, n, "Sack")'),
    ("private servers count", R, 'if game.PrivateServerId ~= "" then refuse("Private"); return false end', ""),
    ("board faction not checked", R, 'if def.Faction and factionOf(player) ~= def.Faction then refuse("Faction"); return false end', ""),
    ("a credit is not cut at WeekCap", R, "rank[board] = cap and math.min(cap, cur + n) or cur + n", "rank[board] = cur + n"),
    ("WeekCap ignored", R, "if cap and cur >= cap then", "if false then"),
    ("victim yield not counted", R, "rank.YieldN = math.min(99, rank.YieldN + 1)", ""),
    ("per-victim count not kept", R, "list[key] = math.min(99, (list[key] or 0) + 1)", ""),
    # --- RankingService: 장인 명성
    ("tags for any faction", R, 'if factionOf(player) ~= "Neutral" or type(gained) ~= "table" then return end',
     'if type(gained) ~= "table" then return end'),
    ("tags while away", R, "if last <= 0 or os.clock() - last > R.HandActiveSeconds then return end", ""),
    ("untagged scrolls score", R, "\tif have <= 0 then\n\t\ttags[id] = nil\n\t\treturn\n\tend\n", ""),
    ("a tag is never used up", R, "tags[id] = have > 1 and have - 1 or nil", "tags[id] = have"),
    ("tags outlive their scrolls", R, "local have = math.min(tags[id] or 0, held + 1)", "local have = tags[id] or 0"),
    ("no '+N 장인 명성' notice", R, 'pcall(Net.Notify, player, string.format(TXT.ArtisanGain, gain), "reward", nil, "RankUp")', ""),
    # --- RankingService: writes
    ("hidden flag not encoded", R, "(hidden and 10 or 0)", "0"),
    ("faction code not encoded", R, " + (R.FactionCode[faction] or 0)", ""),
    ("eligibility ignored", R, "if (tonumber(p.AccountAge) or 0) < R.MinAccountDays or (tonumber(data.PlaytimeSeconds) or 0) < R.MinPlaySeconds then",
     "if false then"),
    ("tainted saves reach PRE", R, 'if data.DebugTainted == true and not studio then return false, "Tainted" end', ""),
    ("Studio is not the STUDIO season", R, 'if RunService:IsStudio() or memory then return "STUDIO" end', 'if memory then return "STUDIO" end'),
    ("memory mode is not STUDIO", R, 'if RunService:IsStudio() or memory then return "STUDIO" end',
     'if RunService:IsStudio() then return "STUDIO" end'),
    ("write gap ignored", R, "or (ST.Dirty[p] and now - (ST.LastWrite[p] or -math.huge) >= R.WriteEverySeconds)", "or ST.Dirty[p]"),
    ("write budget ignored", R, "if budget(Enum.DataStoreRequestType.SetIncrementSortedAsync) < R.MinBudget then", "if false then"),
    ("unchanged values rewritten", R, "\tif written[name] == want then return true end\n", ""),
    ("removal cached as nil (the and/or trap)", R, "\tif want == nil then want = false end\n", ""),
    ("faction change keeps the old row", R, "\t\t\trank.Drop[board] = rank.WeekId\n", ""),
    ("a pending removal targets this week's row", R, "local name = RankingService.StoreName(board, wk)",
     "local name = RankingService.StoreName(board, rank.WeekId)"),
    ("Studio counts in the live save", R, 'if season == "STUDIO" and type(rank) == "table" and liveSeason(rank.Season) then', "if false then"),
    ("Studio results written to the live save", R,
     'if RankingService.EffectiveSeason() == "STUDIO" and liveSeason(type(data.Rank) == "table" and data.Rank.Season) then', "if false then"),
    ("Studio removes live titles", R, 'if RankingService.EffectiveSeason() == "STUDIO" then return end -- a Studio test never removes a live title', ""),
    ("a removed week title never given back", R,
     'if best and S.TitleService and S.TitleService.Grant then pcall(S.TitleService.Grant, p, "Rank" .. best.Board .. best.Rank) end', ""),
    ("the KO judged at the pipeline's (late) time", P, "local now = (type(ctx) == \"table\" and tonumber(ctx.At)) or os.clock()",
     "local now = os.clock()"),
    ("a respawn after the KO counts as fresh", P, "spawned ~= nil and spawned <= now and now - spawned", "spawned ~= nil and now - spawned"),
    ("the KO time not passed", CO, "At = diedAt }", "At = nil }"),
    ("Drop cleared without the removal", R, "if want[name] ~= nil or writeRow(written, name, key, nil) then", "if true then"),
    ("a board back in use is removed anyway", R, "if want[name] ~= nil or writeRow(written, name, key, nil) then",
     "if writeRow(written, name, key, nil) then"),
    ("the earlier session's cache trusted", R, "\tST.Written[p.UserId] = nil -- a new session", "\tlocal _ = nil -- a new session"),
    ("a join never redoes a lost write", R, "if (rank[board] or 0) > 0 then ST.Dirty[p] = true end", ""),
    ("a credit during the write is lost", R, "if (ST.Gen[p] or 0) == gen0 then ST.Dirty[p] = nil end", "ST.Dirty[p] = nil"),
    ("another season's points kept", R, "if type(rank) == \"table\" and rank.WeekId == cur and rank.Season == season then return rank end",
     "if type(rank) == \"table\" and rank.WeekId == cur then return rank end"),
    ("the season is never stamped", R, "\tdata.Rank.Season = season\n", ""),
    ("faction change keeps the old points", R, "\t\t\trank[board] = 0\n", ""),
    ("leaving the guild keeps the tags", R, 'if oldFaction == "Neutral" and newFaction ~= "Neutral" then rank.HandScroll = {} end', ""),
    ("no write when leaving", R, "\t\t\tlocal ok, res = pcall(writePlayer, p, data)\n", "\t\t\tlocal ok, res = true, true\n"),
    ("leave writes not counted for BindToClose", R, "\tST.Leaving += 1\n", ""),
    ("leave writes never uncounted", R, "\t\tST.Leaving -= 1\n", ""),
    ("week flip loses last week's points", R, "ST.Pending[p], ST.LastWeek[p] = snap, snap", "ST.LastWeek[p] = snap"),
    ("hide change waits for the write gap", R, "local due = ST.Force[p] or ST.HideQueue[p] or", "local due = ST.Force[p] or"),
    ("HideSynced never set after the writes", R, "\t\t\trank.HideSynced = hidden\n", ""),
    ("a hide toggle during the write is lost", R, "if ST.HideQueue[p] and (data.HideAnnounceName == true) == hidden then",
     "if ST.HideQueue[p] then"),
    ("join never resyncs the hidden flag", R,
     "if rank.HideSynced ~= (data.HideAnnounceName == true) then RankingService.MarkHideChanged(p) end", ""),
    # --- RankingService: reads / remote
    ("hidden rows keep the UserId", R, "local row = { Rank = r.Rank or i, UserId = hidden and 0 or r.UserId,",
     "local row = { Rank = r.Rank or i, UserId = r.UserId,"),
    ("live players not re-masked", R, 'if live then hidden = live:GetAttribute("HideAnnounceName") == true end', ""),
    ("names not cached", R, "if c and os.clock() - c.At < R.NameCacheSeconds then return c.Name end", ""),
    ("read budget ignored", R, "if budget(Enum.DataStoreRequestType.GetSortedAsync) < R.MinReadBudget then", "if false then"),
    ("reads not staggered", R, "ST.ReadNext[board] = now + (i - 1) * R.ReadStagger", "ST.ReadNext[board] = now"),
    ("RequestRankings argument count not checked", R, 'if select("#", ...) ~= 2 then return end', ""),
    ("RequestRankings not rate limited", R,
     'if not Util.RateLimit(player, "RequestRankings", Config.RateLimits.RequestRankings) then return end', ""),
    ("last week's cache served", R, "if not cache or cache.WeekId ~= week() then return {}, {}, 0 end",
     "if not cache then return {}, {}, 0 end"),
    ("server scope ignores the board faction", R, "if v > 0 and (def.Faction == nil or def.Faction == f) then", "if v > 0 then"),
    # --- RankingService: settle + effects
    ("settle without the 10 min delay", R, "+ R.SettleDelaySeconds or os.clock() < ST.SettleNextTry then return end",
     "+ 0 or os.clock() < ST.SettleNextTry then return end"),
    ("D5 outlaw floor removed", R,
     "local min = R.Boards[board].Outlaw and R.OutlawMinScore or 1\n\tlocal rows = {}",
     "local min = 1\n\tlocal rows = {}"),
    # --- 검수 tie rule
    ("ranks 1, 2, 3 instead of 1, 2, 2", R, "r.Rank = (i > 1 and rows[i - 1].Value == r.Value) and rows[i - 1].Rank or i", "r.Rank = i"),
    ("settle reads only RewardTop rows", R, "\t\t:GetSortedAsync(false, R.TopN):GetCurrentPage()\n\tlocal min",
     "\t\t:GetSortedAsync(false, R.RewardTop):GetCurrentPage()\n\tlocal min"),
    ("settle rank = list position", R,
     "local r = at and math.clamp(math.floor(tonumber(type(ranks) == \"table\" and ranks[at]) or at), 1, R.RewardTop) or nil",
     "local r = at"),
    ("global rows keep the stored order", R, "\trankRows(rows) -- same score = same rank number", "\t-- same score = same rank number"),
    ("server rows rank = position", R, "rows[i] = { Rank = e.Rank,", "rows[i] = { Rank = i,"),
    ("Me.Rank = position", R, "me.Rank = at and rows[at].Rank or nil", "me.Rank = at"),
    ("a tie past the page is not logged", R, "if #page >= R.TopN and #ids > 0 and rows[#rows].Value >= rows[#ids].Value then", "if false then"),
    ("private-server scrolls tagged", R, '\tif game.PrivateServerId ~= "" then return end -- private-server scrolls', "\t-- private-server scrolls"),
    ("a switched top 3 told '+10%'", R, "if f ~= factionOf(p) then -- switched since", "if false then -- switched since"),
    # --- BB11 town board
    ("board outlaw tag for this week's candidates", R, 'Outlaw = p ~= nil and p:GetAttribute("Outlaw") == true })', "Outlaw = true })"),
    ("board rank = position", R, "table.insert(out, { Rank = rows[i].Rank, Name", "table.insert(out, { Rank = i, Name"),
    ("board ignores the weekly boards", P, '\t\t\tif okTop and type(top) == "table" then rows = top end\n', ""),
    ("board without the outlaw tag", P, "\t\t\tif row.Outlaw then text ..= outlawTag end\n", ""),
    ("board names not escaped", P, "string.format(T.Row, row.Rank, boardEsc(row.Name),", "string.format(T.Row, row.Rank, row.Name,"),
    ("board label not RichText", P, "\tif label.RichText ~= true then label.RichText = true end\n", ""),
    ("board without the wanted line", P, '\ttable.insert(lines, "<b>" .. T.Wanted .. "</b>  "', '\tlocal _ = ("<b>" .. T.Wanted .. "</b>  "'),
    ("last writer wins", R, 'return type(old) == "table" and old or built', "return built"),
    ("a failed read settles from this server", R, 'if season ~= "STUDIO" then', "if false then"),
    ("D4 never gives up", R, 'local giveUp = season ~= "STUDIO" and first ~= nil and os.time() - first >= R.SettleGiveUpSeconds',
     "local giveUp = false"),
    ("D4 gives up at the first failure", R, "first ~= nil and os.time() - first >= R.SettleGiveUpSeconds", "first ~= nil"),
    ("STUDIO fallback uses this week's points", R, "doc = serverDoc(prev, prev)", "doc = serverDoc(prev, week())"),
    ("DebugSettle uses last week's points", R, "local doc = serverDoc(week() - 1, week())", "local doc = serverDoc(week() - 1, week() - 1)"),
    ("settle retried at once", R, "ST.SettleNextTry = os.clock() + R.SettleRetrySeconds", "ST.SettleNextTry = 0"),
    ("results act in the settled week", R, "local effect = (tonumber(doc.Week) or 0) + 1", "local effect = (tonumber(doc.Week) or 0)"),
    ("outlaw re-applied (notice repeats)", R, "if type(ol) ~= \"table\" or ol.WeekId ~= effect or ol.Season ~= season then", "if true then"),
    ("reward re-applied (notice repeats)", R,
     "if best and not (type(rr) == \"table\" and rr.WeekId == effect and rr.Season == season and rr.Board == best.Board\n\t\tand rr.Rank == best.Rank) then",
     "if best then"),
    ("outlaw without the season stamp", R, "data.Outlaw = { WeekId = effect, Season = season }", "data.Outlaw = { WeekId = effect }"),
    ("no rank title", R, 'pcall(S.TitleService.Grant, p, "Rank" .. best.Board .. best.Rank)', "local _ = best"),
    ("reward in any faction", R, " and def.Faction == factionOf(p)", ""),
    ("outlaw in any later week", R, "local outlaw = ol.WeekId == cur and ol.Season == season",
     "local outlaw = (tonumber(ol.WeekId) or 0) > 0 and ol.Season == season"),
    ("outlaw of another season acts", R, "local outlaw = ol.WeekId == cur and ol.Season == season", "local outlaw = ol.WeekId == cur"),
    ("reward of another season acts", R, "local mine = rr.WeekId == cur and rr.Season == season", "local mine = rr.WeekId == cur"),
    ("week titles never revoked", R, 'pcall(T.Revoke, p, "Rank" .. board .. rank)', "local _ = board"),
    ("outlaw end not announced", R, 'pcall(Net.Notify, p, text, "good")', ""),
    ("'auto combat is back' while still a bully", R, 'if (tonumber(p:GetAttribute("BullyStacks")) or 0) < 1 then', "if true then"),
    ("'auto combat is back' without auto unlocked", R,
     'local text = p:GetAttribute("AutoCombatUnlocked") == true and TXT.OutlawEnd or TXT.OutlawEndNoAuto', "local text = TXT.OutlawEnd"),
    ("Me.Note never Hidden", R, '\t\t\tme.Note = "Hidden"', '\t\t\tme.Note = nil'),
    ("DebugSettle outside STUDIO", R, 'if RankingService.EffectiveSeason() ~= "STUDIO" then return "STUDIO season only" end', ""),
    ("GameState week not mirrored", R, 'if gs:GetAttribute("RankWeekId") ~= cur then gs:SetAttribute("RankWeekId", cur) end', ""),
    # --- Config
    ("WeekIndex without the KST offset", C, "math.floor((unixTime + Config.Daily.TimezoneOffset + 3 * 86400) / 604800)",
     "math.floor((unixTime + 3 * 86400) / 604800)"),
    ("OutlawMinScore 1", C, "OutlawMinScore = 3,", "OutlawMinScore = 1,"),
    ("SanitizeRank keeps an older week", C, "if int(rank.WeekId, 0, 1e9) == week then", "if true then"),
    ("SanitizeRank: Victims unbounded", C, "if n >= R.MaxVictimKeys then break end", ""),
    ("SanitizeRank: any Victims key", C, 'string.match(k, "^U%-?%d+$")', "true"),
    ("SanitizeRank: YieldN never resets", C,
     "if int(rank.YieldDay, 0, 1e9) == out.YieldDay then out.YieldN = int(rank.YieldN, 0, 99) end", "out.YieldN = int(rank.YieldN, 0, 99)"),
    ("SanitizeRank: a PvP 'reward' kept", C, "R.Boards[rr.Board] and R.Boards[rr.Board].Reward and rr.Board", "R.Boards[rr.Board] and rr.Board"),
    ("RewardMult 1.20", C, "RewardMult = 1.10,", "RewardMult = 1.20,"),
    ("Artisan WeekCap 600", C, "WeekCap = { Honor = 150, Infamy = 150, Artisan = 60 },", "WeekCap = { Honor = 150, Infamy = 150, Artisan = 600 },"),
    ("Artisan title wording 'Artisan Fame'", C, 'TitleNames = { Honor = "Honor", Infamy = "Infamy", Artisan = "Artisan" },',
     'TitleNames = { Honor = "Honor", Infamy = "Infamy", Artisan = "Artisan Fame" },'),
    ("SanitizeRank: Drop kept for any board", C, "if R.Boards[board].Faction and (wk == week or wk == week - 1) then out.Drop[board] = wk end",
     "if wk == week or wk == week - 1 then out.Drop[board] = wk end"),
    ("SanitizeRank: last week's removals dropped", C, "(wk == week or wk == week - 1)", "(wk == week)"),
    ("SanitizeRank: seasons dropped", C, "local out = { WeekId = week, Season = season(rank.Season),", "local out = { WeekId = week, Season = \"\","),
    # --- PvPService
    ("fame always fair", P, "{ PvP = true, Fair = verdict.Fair == true, Victim = victim }", "{ PvP = true, Fair = true, Victim = victim }"),
    ("revenge mark not passed", P, "Revenge = killerMark ~= nil and killerMark.Target == victim and now < killerMark.Until,", "Revenge = false,"),
    ("victim-struck-first not passed", P, "Defense = defense or victimStruckFirst(victim, killer, now),", "Defense = defense,"),
    ("HadSack not passed", P, 'VictimHadSack = type(ctx) == "table" and ctx.HadSack == true,', "VictimHadSack = false,"),
    ("outlaw victim not passed", P, "VictimOutlaw = victimOutlaw,", "VictimOutlaw = false,"),
    ("defense window ignored", P, "\t\tand now - e.T <= Config.Ranking.DefenseWindowSeconds\n", "\n"),
    ("defense ignores who started the fight", P, "return e ~= nil and now - e.Last <= GUARD.EngageGap and e.By == victim",
     "return e ~= nil and now - e.Last <= GUARD.EngageGap"),
    ("a fight never ends", P, "if e == nil or nowFight - e.Last > GUARD.EngageGap then", "if e == nil then"),
    ("every hit starts a new fight", P, "if e == nil or nowFight - e.Last > GUARD.EngageGap then", "if true then"),
    # (no "hidden bounty line" / "IsHidden always false" mutations: A23-130 turned the server-wide bounty line off, and it
    # was the only user of AnnounceService.IsHidden)
    ("kaiju name not re-published on a hide toggle", K,
     "\t\t\t\tpublish(phase, player.UserId, kaijuName, phaseEndsAt)\n", "\t\t\t\tlocal _ = phase\n"),
    ("HandleKO may ask the web", P, "ctx.HadSack == true, NoYield = true,", "ctx.HadSack == true, NoYield = false,"),
    ("a queued kaiju counts as a kaiju killer", P, 'KillerKaiju = kstate(killer) == "Active", -- D2', 'KillerKaiju = kstate(killer) ~= "None", -- D2'),
    ("unfair plunder carries fair points", P, "local rankPts = verdict.Fair == true and inf or 0", "local rankPts = inf"),
    ("plunder fair point not committed", P, "pcall(S.RankingService.CommitFair, killer, victim)", "local _ = killer"),
    ("outlaw has no bounty", P, 'if p:GetAttribute("Outlaw") == true then n = math.max(n, 1) end', ""),
    ("outlaw bounty stacks on bully stacks", P, "n = math.max(n, 1)", "n = n + 1"),
    ("leave bounty asks the web", P, "NoYield = true, -- a PlayerLeaving handler", "NoYield = false, -- a PlayerLeaving handler"),
    ("leave bounty ignores the verdict", P, 'if honor > 0 then grantFame(a, "Honor", honor, verdict, player) end',
     'if honor > 0 then S.PlayerService.AddStat(a, "Honor", honor) end'),
    ("hunting a weak outlaw is a bully KO", P, "(starsBefore > 0 or bullyBefore > 0 or victimOutlaw)", "(starsBefore > 0 or bullyBefore > 0)"),
    # --- GrudgeService
    ("paid sack credits all its infamy", G, "{ RankPoints = sack.RankInfamy or 0 }", "{ RankPoints = sack.Infamy }"),
    ("rankPts not clamped", G, "rankPts = math.clamp(math.floor(tonumber(rankPts) or 0), 0, infamy)", "rankPts = math.floor(tonumber(rankPts) or 0)"),
    ("sack RankInfamy overwritten", G, "sack.RankInfamy = (sack.RankInfamy or 0) + rankPts", "sack.RankInfamy = rankPts"),
    # --- LootService
    ("reward on the jackpot", L, "math.min(1, num(jackpot.Chance) * rowMult)", "math.min(1, num(jackpot.Chance) * rowMult * rowBonus)"),
    ("reward not on rows", L, "num(row.P) * rowMult * rowBonus", "num(row.P) * rowMult"),
    ("outlaw keeps full drops", L,
     '(num(player:GetAttribute("BullyStacks")) >= 1 or player:GetAttribute("Outlaw") == true)', 'num(player:GetAttribute("BullyStacks")) >= 1'),
    ("Enhanced without the item id", L, "LootService.Enhanced:Fire(player, tier, before, after, success, id)",
     "LootService.Enhanced:Fire(player, tier, before, after, success)"),
    # --- ProgressionService
    ("no XP reward", PR, 'if type(reward) == "string" and reward ~= "" and Config.Ranking then mult *= num(Config.Ranking.RewardMult) end', ""),
    ("outlaw keeps full XP", PR,
     '(num(player:GetAttribute("BullyStacks")) >= 1 or player:GetAttribute("Outlaw") == true)', 'num(player:GetAttribute("BullyStacks")) >= 1'),
    ("XP penalty twice (x0.25)", PR, "\t\tmult *= num(pen.XPMult)\n\tend\n",
     "\t\tmult *= num(pen.XPMult)\n\tend\n\tif player:GetAttribute(\"Outlaw\") == true then mult *= num(pen.XPMult) end\n"),
    # --- CombatService
    ("an outlaw may use auto combat", CO,
     'and ((tonumber(player:GetAttribute("BullyStacks")) or 0) >= 1 or player:GetAttribute("Outlaw") == true)',
     'and ((tonumber(player:GetAttribute("BullyStacks")) or 0) >= 1)'),
    ("Outlaw attribute not watched", CO, 'player:GetAttributeChangedSignal("Outlaw"):Connect(function() penaltyChanged(true) end)', ""),
    ("a hit taken is the victim's own action", CO, 'if attacker then S.PlayerService.MarkActive(victim, "Hit") end',
     "if attacker then S.PlayerService.MarkActive(victim) end"),
    ("the pipeline never resolves the friend answer", CO, "local okFriends, errFriends = pcall(ranking.ResolveFriends, killer, victim)",
     "local okFriends, errFriends = true, nil"),
    ("HadSack read after the sack closed", CO, "\tlocal okSack, hadSack = pcall(S.GrudgeService.HasSack, victim)\n",
     "\tpcall(S.GrudgeService.OnCarrierDown, victim, killer)\n\tlocal okSack, hadSack = pcall(S.GrudgeService.HasSack, victim)\n"),
    ("outlaw gets the bully text", CO, "Net.Notify(player, outlawOnly and Config.Ranking.Text.OutlawNoAuto or Config.Text.BullyNoAuto, \"bad\")",
     "Net.Notify(player, Config.Text.BullyNoAuto, \"bad\")"),
    ("bully 'penalty over' at the outlaw end", CO, "elseif wasBully and not now and not fromOutlaw and", "elseif wasBully and not now and"),
    # --- PlayerService
    ("GrantFame skips the ranking", PL, "local ok, err = pcall(ranking.CreditFame, player, stat, n, ctx)", "local ok, err = true, nil"),
    ("hits move GetLastOwnActive", PL, 'if kind ~= "Hit" then lastOwn[player] = os.clock() end', "lastOwn[player] = os.clock()"),
    # --- TitleService / CharacterVisuals
    ("Revoke keeps the selected title", T, 'if data.TitleSel == id then S.PlayerService.SetStat(player, "TitleSel", "") end', ""),
    ("no outlaw tag", V, "(outlaw and (' <font color=\"#FF4A4A\">' .. Config.Ranking.Text.OutlawTag .. \"</font>\") or \"\")", '""'),
    ("tag hidden with the name", V, 'local outlaw = player:GetAttribute("Outlaw") == true',
     'local outlaw = player:GetAttribute("Outlaw") == true and player:GetAttribute("HideAnnounceName") ~= true'),
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
    init = re.search(r"local INIT_ORDER = \{(.*?)\}", main, re.S)
    start = re.search(r"local START_ORDER = \{(.*?)\}", main, re.S)
    names_init = re.findall(r'"(\w+)"', init.group(1)) if init else []
    names_start = re.findall(r'"(\w+)"', start.group(1)) if start else []
    check("RankingService" in names_init and names_init.index("RankingService") > names_init.index("AnnounceService"),
          "Main INIT_ORDER lists RankingService after AnnounceService")
    check("RankingService" in names_start and names_start.index("RankingService") < names_start.index("PlayerService"),
          "Main START_ORDER lists RankingService before PlayerService")
    check((SSS / "RankingService.luau").is_file(), "the listed RankingService.luau exists (the list and the file go in one commit)")
    debug = between(main, 'debugFn.OnInvoke = function(playerName, key, value)', 'elseif key == "Nickname" then')
    check("tainted.DebugTainted = true" in debug and debug.find("tainted.DebugTainted = true") < debug.find('key == "RankSettle"'),
          "DebugCommand marks the save DebugTainted before any key branch")
    for key in ("RankSettle", "RankWrite", "PairCD"):
        check(f'key == "{key}"' in debug, f"DebugCommand key {key}")
    net = read(SHARED / "Net.luau")
    check('"RequestRankings"' in net and '"Rankings"' in net, "Net.Names has RequestRankings and Rankings")
    check("RankWeekId = 0, RankWeekEndsAt = 0" in net, "Net.GameStateDefaults has RankWeekId / RankWeekEndsAt")
    data = read(SSS / "DataService.luau")
    fill = function_block(data, "local function fillDefaults(")
    check("Config.SanitizeRank(d, os.time())" in fill, "DataService.fillDefaults runs Config.SanitizeRank")
    pvp = strip_comments(read(SSS / "PvPService.luau"))
    check(not re.search(r'AddStat\([^)]*"(Honor|Infamy)"', pvp), "PvPService: no Honor / Infamy AddStat left (all through GrantFame)")
    check(len(re.findall(r'grantFame\((killer|a), "(Honor|Infamy)"', pvp)) == 4, "PvPService: 4 fame sites use grantFame (3 KO + leave bounty)")
    grudge = strip_comments(read(SSS / "GrudgeService.luau"))
    check(not re.search(r'AddStat\([^)]*"(Honor|Infamy)"', grudge) and "GrantFame(thief, \"Infamy\", sack.Infamy, { RankPoints" in grudge,
          "GrudgeService pay: GrantFame with the sack's RankPoints")
    story = strip_comments(read(SSS / "StoryQuestService.luau"))
    goose = strip_comments(read(SSS / "GooseService.luau"))
    check("GrantFame" not in story and "CreditFame" not in story and "GrantFame" not in goose,
          "D1: story / goose fame stays AddStat (never a board)")
    everywhere = []
    for path in sorted(SSS.glob("*.luau")):
        code = strip_comments(read(path))
        for line in code.splitlines():
            if re.search(r'AddStat\([^)]*"(Honor|Infamy)"', line) and path.name != "StoryQuestService.luau":
                everywhere.append(f"{path.name}: {line.strip()}")
            if "NotifyAll" in line and "PlayerDisplayName" in line:
                everywhere.append(f"{path.name}: {line.strip()}")
    check(not everywhere, f"no Honor/Infamy AddStat outside StoryQuest, no raw names in NotifyAll: {everywhere}")
    visuals = read(SSS / "CharacterVisuals.luau")
    check(re.search(r'Outlaw = \{ "Nametag" \}', visuals) is not None, "CharacterVisuals rebuilds the nametag when Outlaw changes")
    telemetry = read(SSS / "TelemetryService.luau")
    check('connect("LootService", "Enhanced", function(player, _tier, _before, _after, success)' in telemetry,
          "the other Enhanced listener (TelemetryService, BB38) reads the 5th argument success, nothing after it")
    ranking = strip_comments(read(SSS / "RankingService.luau"))
    leaving = function_block(read(SSS / "RankingService.luau"), "local function onLeaving(")
    head = leaving.split("task.spawn(function()", 1)[0]
    check("task.spawn(function()" in leaving and "task.wait" not in head and "Async" not in head,
          "PlayerLeaving handler never yields (the write and its waits run in their own thread)")
    check("FireAllClients" not in ranking and 'Net.Get("Rankings"):FireClient(player' in ranking, "Rankings goes to the asking player only")
    check("SetAsync" in ranking and "IncrementAsync" not in ranking, "ordered rows are SetAsync values (never increments)")
    player = read(SSS / "PlayerService.luau")
    check("rankingPending() > 0" in player and "r.PendingWrites" in player,
          "PlayerService BindToClose waits for the ranking leave writes (after the saves, same timeout)")
    combat = read(SSS / "CombatService.luau")
    pipe = function_block(combat, "local function runDeathPipeline(")
    check(pipe.find("GrudgeService.HasSack") < pipe.find('pipelineCall("GrudgeService.OnCarrierDown"') and "victim, killer, koCtx)" in pipe,
          "death pipeline: HasSack is read before OnCarrierDown and passed to HandleKO")
    return count, failures


SUITE = Suite(
    mark="RANKING",
    fixture=ROOT / "tools/fixtures/ranking_offline.luau",
    world=ROOT / "tools/fixtures/dev2_world.luau",
    out=ROOT / "docs/art/verification_2026-10-06/offline_ranking_2026-10-06.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="BB10 / A23-22 / A23-23 / A23-24 + D1-D6: four weekly boards (Honor Halo, Infamy Horns, Artisan Neutral, PvP "
             "every faction) from Monday 00:00 KST (WeekIndex 2962 = 10/05). Honor / Infamy count only fair PvP points "
             "(PvPCreditOK: Bold >= 1, victim's own action within 60 s (hits taken do not count, D6), not friends (an "
             "IsFriendsWith error counts as friends; never asked inside PlayerLeaving), victim >= 7 days / 3 h (skipped in "
             "the STUDIO season), < 3 per victim per week, victim < 5 a day, not fresh / repeated). An unfair KO (weak, "
             "idle, new, 4th, fresh, repeated) adds 1 to the PvP board unless exempt (revenge, Wanted, bully, outlaw, kaiju "
             "victim or killer, sack thief seen before the sack closes, self-defense within 10 s); YieldCap alone counts "
             "nowhere; friends count nowhere. Story / goose fame never reaches a board (D1). Grudge sacks credit only their "
             "fair RankInfamy when Paid. 장인 명성: tags on Enh scrolls my own kills dropped while Neutral and active, one "
             "tag per use, success = after - before, fails / transfers / untagged / last week 0; cleared on leaving the "
             "guild. Ordered stores HH_Rank_<season>_<board>_W<week>, key U_<id>, value score*100 + hidden*10 + code; "
             "STUDIO season in Studio / memory mode; eligibility, DebugTainted, ExcludeUserIds, budgets, 120 s gap, "
             "faction-change removal, leave write, week-flip snapshot, hide must-write + HideSynced; reads every 180 s "
             "staggered 45 s, names batched + cached, hidden rows '<진영> 한 명' / UserId 0, live re-mask, the "
             "RequestRankings remote answers from the cache only. One settle 10 min after Monday (first writer wins in "
             "HH_RankSettle_<season> W<week>), retry 60 s, give up after 2 h (D4), PvP top 3 with >= 3 points become "
             "outlaws (D5), Honor / Infamy / Artisan top 3 get RankReward + a timed title for that week only and only in "
             "that faction. Effects: XP and drop rows x1.10 (never the jackpot), outlaw = bully penalty once (x0.5, "
             "never x0.25, jackpot too, first scroll kept), no auto combat (OutlawAutoOff / OutlawNoAuto / OutlawEnd), "
             "bounty like one bully stack (max x2), red nametag tag even when hidden.",
    limitations="Offline doubles: Players / Instances / attributes / characters, PlayerService (data rows, SetStat mirror; "
                "GrantFame and the activity clocks are the real extracted functions), FactionService, JusticeService "
                "(power = the Power attribute, bully stacks = the attribute), ZoneService, KaijuService, MapBuilder, "
                "MonsterService signal, ProgressionService gold, DataStoreService (ordered + standard, budgets, failures, a "
                "second server sharing the stores), UserService, IsFriendsWith, task (the services' forever-loops are "
                "stepped through their public Tick functions; GrudgeService's loop is resumed by hand). Real Roblox "
                "OrderedDataStore limits / latency, two real servers, the HUD chips and the ranking window (BB11, client) "
                "are not certified here: the 게임성 개발 session plays them after the merge; real-server checks with two "
                "7-day accounts come after 10/10 (BB10 acceptance).",
)

if __name__ == "__main__":
    run(SUITE)
