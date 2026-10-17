"""A23-110 the first KO King (FirstKOService, 게임성 개발 2), server side, offline.

game dev 3's quest KO1 "The King's Hop" (Config.FirstKO = { Quest, Step, RematchStep }) drives the King through
StoryQuestService.CurrentStep. At Config.FirstKO.Step the player gets a personal, quiet King Slime whose landing thud
(and every later hit) knocks the player out in one hit, once per account (data.FirstKODone), only below
Config.FirstKOKing.OneHitBelow and only while nothing is at stake (a grudge sack, wanted stars / bounty, a PvP fight, the
kaiju queue: then plain King hits and a normal death). That KO is lossless (CombatService's death pipeline: no grudge sack, bounty / stars, PvP KO or ranking step), its KO Fx
carries First = true, StoryQuestService.Event "FirstKO" moves the quest on, the player gets up near where it fell
(PlayerService get-up) with GetUp.HealthFrac of MaxHealth, and FirstKOService.FirstKO(player) fires once. On that row
with the KO already had (or from OneHitBelow on) no King comes and the quest is told "FirstKO" again every SpawnGap. At
Config.FirstKO.RematchStep the weakened retry King of Config.FirstKORetry comes (about 2 potions for every class / faction
/ Lv 1-9): a normal personal King whose kill is MonsterService's Personal MonsterKilled with Practice = true - the quest's
Kill row counts it, FinisherService gives no card, LootService rolls no boss drops, QuestService counts no daily job, and
it pays the XP / gold of Retry.PayAs; one win per session while the row stays. Its HP comes from the best weapon the
save may use (Config.BestUsableWeapon with its +N), and ONE HP potion wins it (no potion loses at 60-80% uptime).
A King whose owner steps into a town goes home; Config.FirstKOKing.Enabled = false sends no King but still tells the KO
row. Both Kings come only by the player (Near)
and never swing before the landing (Hold). No step number is hard-coded: an extra row before the rematch moves the retry
King. (The at-stake, Tell, Near / Hold and one-win checks follow the critic's corrected version, 2026-10-10.)

Runs the CURRENT Config, Util, FirstKOService, StoryQuestService, FinisherService and the tools/test_ranking.py world
(whole CombatService, PvPService, GrudgeService, RankingService, AnnounceService, LootService, TitleService,
ProgressionService, KaijuService + the PlayerService fame extract) on tools/fixtures/dev2_world.luau, plus the real
MonsterService code cut out (landAttack, killRecord, the spawnMonster hook fields, SpawnPersonal, RemovePersonal,
GroundAt), the real PlayerService get-up code cut out (getUp, spawnSpot, bindCharacterDeath, the spawn PivotTo line) and
QuestService.onMonsterKilled cut out, with the installed official Luau CLI. Most groups use a StoryQuestService double
(CurrentStep / Event); the group "quest KO1" runs the REAL StoryQuestService with Config's KO1. No Studio, network,
DataStore or Roblox API calls; mutations run on in-memory copies of the sources only.

Spec: docs/SPEC_ADDENDUM.md A23-110 (A23-109, A23-27 boss rules), docs/design/first_ko_quest_2026-10-10.md (game dev 3).
Usage: py tools/test_first_ko_king.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-11/offline_dev2_first_ko_king_2026-10-11.json (A23-113 ① landings; was ..._2026-10-10.json)
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run, strip_comments
from test_ranking import FILES as RANKING_FILES, bindings as ranking_bindings

FILES = dict(RANKING_FILES)
FILES.update({
    "FIRSTKO_SOURCE": SSS / "FirstKOService.luau",
    "MONSTER_SOURCE": SSS / "MonsterService.luau",
    "MAIN_SOURCE": SSS / "Main.server.luau",
    "STORY_SOURCE": SSS / "StoryQuestService.luau",
    "FINISHER_SOURCE": SSS / "FinisherService.luau",
    "QUEST_SOURCE": SSS / "QuestService.luau",
})
C, F, CO, MO, PL, MA = ("CONFIG_SOURCE", "FIRSTKO_SOURCE", "COMBAT_SOURCE", "MONSTER_SOURCE", "PLAYER_SOURCE",
                        "MAIN_SOURCE")
FI, LO, QU = "FINISHER_SOURCE", "LOOT_SOURCE", "QUEST_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = ranking_bindings(sources)
    for key in ("FIRSTKO_SOURCE", "MAIN_SOURCE", "STORY_SOURCE", "FINISHER_SOURCE"):
        out[key] = sources[key]
    mon = sources["MONSTER_SOURCE"]
    # the real MonsterService pieces A23-110 touches, on doubles of their upvalues
    out["MON_LAND_EXTRACT"] = (
        "local records, MC, REACT, FACE, OUT_Y, ATTACK_SEQ_ATTR, S, Config, Util, isPlayerInTown, targetable, "
        "warnThrottled = ...\n" + function_block(mon, "local function landAttack(") + "\nreturn landAttack\n")
    out["MON_KILL_EXTRACT"] = (
        "local records, Config, MC, MonsterService, factionOf, updateBar, deathPop, removePersonalRef, scheduleRespawn, "
        "warnThrottled = ...\n" + function_block(mon, "local function killRecord(") + "\nreturn killRecord\n")
    out["MON_PERSONAL_EXTRACT"] = (
        "local Config, Util, personal, PERSONAL_DISTANCE, PERSONAL_LIFETIME, groundPoint, probeGround, spawnMonster, "
        "despawn, warnThrottled = ...\nlocal MonsterService = {}\n"
        + function_block(mon, "function MonsterService.SpawnPersonal(")
        + function_block(mon, "function MonsterService.RemovePersonal(")
        + function_block(mon, "function MonsterService.GroundAt(")
        + "\nreturn MonsterService\n")
    # spawnMonster's record fields for the hooks (only the A23-110 lines: Quiet / _strike / _onKilled / Practice)
    spawn = function_block(mon, "local function spawnMonster(")
    first = spawn.find("\t\tQuiet = (owner")
    practice = spawn.find("\t\tPractice = (owner", first)
    last = spawn.find("\n", spawn.find("opts.Practice or kind) or nil,", practice)) if practice >= 0 else -1
    if first < 0 or practice < 0 or last < 0:
        raise ValueError("spawnMonster A23-110 record fields missing; update the test extractor.")
    out["MON_FIELDS_EXTRACT"] = ("local owner, opts, kind, Config = ...\nreturn {\n" + spawn[first:last + 1] + "}\n")
    player = sources["PLAYER_SOURCE"]
    out["PLAYER_GETUP_EXTRACT"] = (
        "local Config, Util, S, ready, deathBound, PlayerService, loopWarn, loadCharacter, spawnCFrame, respawnZoneId, "
        "firstMissionOpen, guideSpot = ...\n"
        + function_block(player, "local function getUp(") + function_block(player, "local function spawnSpot(")
        + function_block(player, "local function bindCharacterDeath(")
        + "\nreturn { GetUp = getUp, SpawnSpot = spawnSpot, Bind = bindCharacterDeath }\n")
    added = function_block(player, "local function onCharacterAdded(")
    pivot = [line for line in added.splitlines() if "character:PivotTo(context and cosmeticPivot(" in line]
    if len(pivot) != 1:
        raise ValueError("onCharacterAdded spawn PivotTo line changed; update the test extractor.")
    out["PLAYER_PIVOT_EXTRACT"] = (
        "local character, context, player, humanoid, root, cosmeticPivot, spawnSpot = ...\n" + pivot[0].strip() + "\n")
    quest = sources["QUEST_SOURCE"]
    out["QUEST_KILL_EXTRACT"] = (
        "local getData, getStep, getLevel, killWeight, addProgress, STEP_QUEST, STEP_GUIDE, TUT_ZONE, TUTORIAL_KINDS, "
        "setStep, tutorialKill, Config = ...\n" + function_block(quest, "local function onMonsterKilled(")
        + "\nreturn onMonsterKilled\n")
    return out


PEND = "\t\tST.Pending[target] = pend\n\t\tlocal applied"
SPAWN_CHECK = "\tif rec._strike ~= strike or (typeof(model) == \"Instance\" and model:GetAttribute(\"FirstKO\") ~= nil) then"
RETRY_OPT = "\t\topts.Practice = type(R.PayAs) == \"string\" and R.PayAs or true\n"
DONE_SET = "\tS.PlayerService.SetStat(victim, \"FirstKODone\", true)\n"
TELL = "\t\tST.NextAt[player] = now + num(FK.SpawnGap, 4)\n\t\treport(player, false)\n\t\treturn\n"
HOOKS = "Distance = num(FK.SpawnDistance, 6), Strike = strike, OnKilled = onKilled, Near = true,"

MUTATIONS = [
    ("r7: the first KO has no Kind", CO, "First = true, Kind = def and src.Kind or nil }", "First = true }"),
    # --- FirstKOService: the stage comes from the quest's CurrentStep (never a step number of our own)
    ("any quest step is the KO step", F, "\tif step == Q.Step then return (fresh and not off) and \"First\" or \"Tell\" end",
     "\tif step ~= nil then return (fresh and not off) and \"First\" or \"Tell\" end"),
    ("the KO row never", F, "\tif step == Q.Step then return (fresh and not off) and \"First\" or \"Tell\" end\n", ""),
    ("any quest step is the rematch", F, "\tif step == Q.RematchStep and not off then return \"Retry\" end",
     "\tif not off then return \"Retry\" end"),
    ("no rematch step", F, "\tif step == Q.RematchStep and not off then return \"Retry\" end\n", ""),
    ("the KO step hard-coded as 1", F, "\tif step == Q.Step then", "\tif step == 1 then"),
    ("the rematch step hard-coded as 4", F, "\tif step == Q.RematchStep and", "\tif step == 4 and"),
    ("disabled still sends the first King", F, "return (fresh and not off) and \"First\" or \"Tell\" end",
     "return fresh and \"First\" or \"Tell\" end"),
    ("disabled still sends the retry King", F, "\tif step == Q.RematchStep and not off then", "\tif step == Q.RematchStep then"),
    ("disabled strands the KO row", F, "return (fresh and not off) and \"First\" or \"Tell\" end",
     "return (not off) and (fresh and \"First\" or \"Tell\") or nil end"),
    ("another quest's step asked", F, "local ok, step = pcall(svc.CurrentStep, player, Q.Quest)",
     "local ok, step = pcall(svc.CurrentStep, player, \"KO1\")"),
    ("a throwing CurrentStep breaks the stage", F, "local ok, step = pcall(svc.CurrentStep, player, Q.Quest)",
     "local ok, step = true, svc.CurrentStep(player, Q.Quest)"),
    ("one-shot twice (Done ignored)", F, "local fresh = data.FirstKODone ~= true and num(data.Level, 1)", "local fresh = num(data.Level, 1)"),
    ("one-shot at any level", F, " and num(data.Level, 1) < num(FK.OneHitBelow, 10)\n", "\n"),
    ("a kaiju gets a King", F, "\tif not data or isKaiju(player) then return nil end", "\tif not data then return nil end"),
    ("a queued kaiju-to-be refused", F, "return ok and (st == \"Siren\" or st == \"Active\")", "return ok and st ~= \"None\""),
    # --- the place
    ("any zone", F, "\tif zone.Id ~= FK.Zone or zone.Town == true then return false end\n",
     "\tif zone.Town == true then return false end\n"),
    ("in town too", F, "\tif zone.Id ~= FK.Zone or zone.Town == true then return false end\n",
     "\tif zone.Id ~= FK.Zone then return false end\n"),
    ("landmark radius ignored", F, "\tif spot ~= nil and Util.FlatDistance(pos, spot) > radius then return false end\n", ""),
    # A23-222: each stage its own spot and radius (the first King: Landmark / Radius; the rematch: RetryLandmark / RetryRadius)
    # A23-227: Landmark and RetryLandmark are both KingHill, so swapping them in the code is equivalent; the Config
    # mutation "the rematch back at the meadow's arrival" guards the shipped value
    ("the rematch King within the first radius", F,
     "\tlocal radius = stage == \"Retry\" and num(FK.RetryRadius, num(FK.Radius, 90)) or num(FK.Radius, 90)\n",
     "\tlocal radius = num(FK.Radius, 90)\n"),
    ("the first King within the rematch radius", F,
     "\tlocal radius = stage == \"Retry\" and num(FK.RetryRadius, num(FK.Radius, 90)) or num(FK.Radius, 90)\n",
     "\tlocal radius = num(FK.RetryRadius, 90)\n"),
    ("the place check forgets the stage", F, "\tif not inPlace(player, stage) then return end\n", "\tif not inPlace(player) then return end\n"),
    ("Config: the old 90-stud radius", C, "Zone = \"SlimeMeadow\", Radius = 30, Landmark = \"KingHill\",",
     "Zone = \"SlimeMeadow\", Radius = 90, Landmark = \"KingHill\","),
    ("Config: no hill landmark (anywhere in the meadow)", C, "Zone = \"SlimeMeadow\", Radius = 30, Landmark = \"KingHill\",",
     "Zone = \"SlimeMeadow\", Radius = 30,"),
    ("Config: the rematch radius 30", C, "RetryRadius = 40, RetryLandmark = \"KingHill\",", "RetryRadius = 30, RetryLandmark = \"KingHill\","),
    ("Config: the rematch back at the meadow's arrival (A23-227)", C, "RetryRadius = 40, RetryLandmark = \"KingHill\",", "RetryRadius = 40, RetryLandmark = \"MeadowArrival\","),
    ("Config: the hill moved", C, "Config.StoryQuests.Landmarks.KingHill = Vector3.new(400, 0, -118)",
     "Config.StoryQuests.Landmarks.KingHill = Vector3.new(430, 0, 0)"),
    ("joins the field King's fight", F, "if type(r) == \"table\" and r.Owner == nil and r.Kind == kingKind() then return false end",
     "if false then return false end"),
    ("any monster blocks it", F, "if type(r) == \"table\" and r.Owner == nil and r.Kind == kingKind() then return false end",
     "if type(r) == \"table\" then return false end"),
    ("a dead player gets a King", F, "\tif not Util.IsAlive(player) then return false end\n\tlocal root", "\tlocal root"),
    # --- the hits
    ("one-shot for anyone", F, "\tif target ~= owner or not e or e.Rec ~= rec then return hitBase(rec, target, mult) end\n",
     "\tif not e or e.Rec ~= rec then return hitBase(rec, target, mult) end\n"),
    ("raised after the step ended", F, "\tif stage ~= e.Stage then return hitBase(rec, target, mult) end",
     "\tif false then return hitBase(rec, target, mult) end"),
    ("not lethal", F, "hum.MaxHealth * math.max(10, num(FK.OneHitMult, 20))", "hum.MaxHealth * 0.5"),
    ("Guard can save it", F, "hum.MaxHealth * math.max(10, num(FK.OneHitMult, 20))", "hum.MaxHealth * 1.05"),
    ("pending after the damage", F, PEND, "\t\tlocal applied"),
    ("a ForceField hit still claims", F,
     "\t\tif hum.Health > 0 and ST.Pending[target] == pend then ST.Pending[target] = nil end", ""),
    ("retry hits like the first", F, "return S.CombatService.DamagePlayer(target, hum.MaxHealth * retryOf(target).Hit * mult, nil, false, rec.Kind)",
     "return S.CombatService.DamagePlayer(target, hum.MaxHealth * 20, nil, false, rec.Kind)"),
    ("retry hit ignores the landing's mult", F, "hum.MaxHealth * retryOf(target).Hit * mult, nil, false, rec.Kind)",
     "hum.MaxHealth * retryOf(target).Hit, nil, false, rec.Kind)"),
    ("no KO screen name (no kind)", F, "hum.MaxHealth * math.max(10, num(FK.OneHitMult, 20)), nil,\n\t\t\tfalse, rec.Kind)",
     "hum.MaxHealth * math.max(10, num(FK.OneHitMult, 20)), nil,\n\t\t\tfalse, nil)"),
    # --- nothing at stake (no way out of a sack / stars / bounty / PvP / kaiju queue loss)
    ("a sack carrier's way out", F, "\tif not okS or sack then return true end\n", "\tif not okS then return true end\n"),
    ("wanted stars ignored", F, "if not okW or num(stars) >= 1 or num(player:GetAttribute(\"Bounty\")) > 0 then return true end",
     "if not okW or num(player:GetAttribute(\"Bounty\")) > 0 then return true end"),
    ("bounty ignored", F, "if not okW or num(stars) >= 1 or num(player:GetAttribute(\"Bounty\")) > 0 then return true end",
     "if not okW or num(stars) >= 1 then return true end"),
    ("the combat tag never read", F, "return type(Cb) == \"table\" and Cb.IsInCombat(player) == true end)", "return false end)"),
    ("a PvP fight ignored", F, "\tif not okP or fight then return true end\n", "\tif not okP then return true end\n"),
    ("the kaiju queue ignored", F, "\treturn not okK or (st ~= \"None\" and st ~= nil)\n", "\treturn not okK\n"),
    ("a failing check is no stake", F, "\tif not okS or sack then return true end\n", "\tif okS and sack then return true end\n"),
    ("a failing stars check is no stake", F, "if not okW or num(stars) >= 1 or num(player:GetAttribute(\"Bounty\")) > 0 then return true end",
     "if (okW and num(stars) >= 1) or num(player:GetAttribute(\"Bounty\")) > 0 then return true end"),
    ("a failing combat-tag check is no stake", F, "\tif not okP or fight then return true end\n", "\tif okP and fight then return true end\n"),
    ("a failing kaiju check is no stake", F, "\treturn not okK or (st ~= \"None\" and st ~= nil)\n", "\treturn okK and (st ~= \"None\" and st ~= nil)\n"),
    ("strike ignores the stake", F, "\tif stage == \"First\" and atStake(target) then return hitBase(rec, target, mult) end", ""),
    ("the claim ignores the stake", F, "or data.FirstKODone == true or atStake(victim) then return nil end",
     "or data.FirstKODone == true then return nil end"),
    ("the Died delay ignores the stake", F, "data.FirstKODone ~= true and not atStake(player) then return { Delay",
     "data.FirstKODone ~= true then return { Delay"),
    # --- the landing
    ("no landing thud", F, "\ttask.delay(math.max(0, num(FK.DropTime, 1.2)), function()\n\t\tlocal okL, err = pcall(land, player, rec)",
     "\ttask.delay(math.max(0, num(FK.DropTime, 1.2)), function()\n\t\tlocal okL, err = true, nil"),
    ("landing reaches anywhere", F, "\tif Util.FlatDistance(p, k) > math.max(0, num(FK.LandRadius, 10) - grace) or math.abs(p.Y - k.Y) > 12 then return end\n", ""),
    ("landing circle without grace", F, "math.max(0, num(FK.LandRadius, 10) - grace)", "num(FK.LandRadius, 10)"),
    ("the retry drop never hits", F, "\tif not e or e.Rec ~= rec or not rec.Alive then return end\n\tlocal root, kroot",
     "\tif not e or e.Rec ~= rec or e.Stage ~= \"First\" or not rec.Alive then return end\n\tlocal root, kroot"),
    ("no drop circle radius", F, "\t\tmodel:SetAttribute(\"DropRadius\", num(FK.LandRadius, 10))\n", ""),
    ("the first King never grows", F, "\t\topts.LeapGrow, opts.LeapGrowMax = math.max(0, num(FK.LeapGrow, 6)), math.max(0, num(FK.LeapGrowMax, 18))\n", ""),
    ("gets up toward the King", F, "\tif typeof(leap) == \"Vector3\" and Util.FlatDistance(leap, at) > 0.5 then return leap end\n", ""),
    ("no drop attributes", F, "\t\tmodel:SetAttribute(\"DropAt\", Util.Now())\n", ""),
    # --- the King
    ("the first King not quiet", F, "\t\topts.Quiet = true\n", "\t\topts.Quiet = false\n"),
    ("the retry King quiet again (the quest never counts it)", F, RETRY_OPT, RETRY_OPT + "\t\topts.Quiet = true\n"),
    ("the retry King not a practice King (boss credit)", F, RETRY_OPT, "\t\topts.Practice = nil\n"),
    ("no strike hook", F, HOOKS, "Distance = num(FK.SpawnDistance, 6), OnKilled = onKilled, Near = true,"),
    ("no kill hook", F, HOOKS, "Distance = num(FK.SpawnDistance, 6), Strike = strike, Near = true,"),
    ("home-town fallback allowed", F, HOOKS, "Distance = num(FK.SpawnDistance, 6), Strike = strike, OnKilled = onKilled,"),
    ("swings before the landing", F, "\t\tHold = math.max(0, num(FK.DropTime, 1.2)) + math.max(0, num(FK.FirstLeapAfter, 0.5)) }", "\t\tHold = 0 }"),
    ("first leap right at the drop", F, "\t\tHold = math.max(0, num(FK.DropTime, 1.2)) + math.max(0, num(FK.FirstLeapAfter, 0.5)) }",
     "\t\tHold = math.max(0, num(FK.DropTime, 1.2)) }"),
    ("retry King has the first HP", F, "local opts = { HP = first and math.max(1, num(FK.FirstHP, 5000)) or retryOf(player).HP,",
     "local opts = { HP = math.max(1, num(FK.FirstHP, 5000)),"),
    ("two Kings at once", F, "\tif e or stage == nil or now < (ST.NextAt[player] or 0) then return end",
     "\tif stage == nil or now < (ST.NextAt[player] or 0) then return end"),
    ("no spawn gap", F, "\tST.NextAt[player] = os.clock() + num(FK.SpawnGap, 4)\n\tlocal ok, model, rec", "\tlocal ok, model, rec"),
    ("lifetime end re-drops at once", F,
     "\t\t\tST.NextAt[player] = math.max(ST.NextAt[player] or 0, now + num(FK.SpawnGap, 4)) -- not a new drop at once\n", ""),
    ("King stays after the step", F, "\t\telseif stage ~= e.Stage or not Util.IsAlive(player) or inTown(player) then",
     "\t\telseif not Util.IsAlive(player) or inTown(player) then"),
    ("a King kept while its owner is in town", F, "not Util.IsAlive(player) or inTown(player) then", "not Util.IsAlive(player) then"),
    ("retry HP from the weapon in hand", F, "\tlocal tier = Config.BestUsableWeapon(data.WeaponOwnedMask, level)\n",
     "\tlocal tier = player:GetAttribute(\"WeaponTier\")\n"),
    ("retry HP ignores the +N", F, "\tlocal enh = type(data.WeaponEnhance) == \"table\" and num(data.WeaponEnhance[tier]) or 0\n", "\tlocal enh = 0\n"),
    ("a foreign personal King adopted", F, SPAWN_CHECK, "\tif (typeof(model) == \"Instance\" and model:GetAttribute(\"FirstKO\") ~= nil) then"),
    ("a stale King of ours adopted", F, SPAWN_CHECK, "\tif rec._strike ~= strike then"),
    ("the first King beaten is not reported", F, "\telse\n\t\treport(player, true)\n", "\telse\n"),
    ("the first King beaten reported as a KO", F, "\t\treport(player, true)\n", "\t\treport(player, false)\n"),
    ("no KingBeaten", F, "\tFirstKOService.KingBeaten:Fire(player, e.Stage == \"Retry\")\n", ""),
    ("KingBeaten says retry always", F, "FirstKOService.KingBeaten:Fire(player, e.Stage == \"Retry\")",
     "FirstKOService.KingBeaten:Fire(player, true)"),
    # --- the Tell row and the rematch row
    ("a stuck KO row never told again", F, TELL, "\t\tST.NextAt[player] = now + num(FK.SpawnGap, 4)\n\t\treturn\n"),
    ("the KO row told every tick", F, TELL, "\t\treport(player, false)\n\t\treturn\n"),
    ("a told row still gets a King", F, TELL, "\t\tST.NextAt[player] = now + num(FK.SpawnGap, 4)\n\t\treport(player, false)\n"),
    ("one rematch win ignored", F, "\tif stage == \"Retry\" and ST.Beaten[player] then return end", ""),
    ("Beaten never set", F, "\t\tST.Beaten[player] = true\n", ""),
    ("Beaten never cleared", F, "\tif stage ~= \"Retry\" then ST.Beaten[player] = nil end", ""),
    # --- the claim
    ("any death is the first KO", F, "\tif t < pend.At - 0.05 or t - pend.At > num(FK.ClaimGrace, 1) then return nil end\n", ""),
    ("claimed twice", F, "if not data or data.FirstKODone == true or atStake(victim) then return nil end",
     "if not data or atStake(victim) then return nil end"),
    ("Done never saved", F, DONE_SET, ""),
    ("Event FirstKO missing", F, "\treport(victim, false)\n\tFirstKOService.FirstKO:Fire(victim)", "\tFirstKOService.FirstKO:Fire(victim)"),
    ("Event with another name", F, "pcall(svc.Event, player, \"FirstKO\", { Kind = kingKind()", "pcall(svc.Event, player, \"FirstKo\", { Kind = kingKind()"),
    ("a throwing Event breaks the KO", F, "local ok, moved = pcall(svc.Event, player, \"FirstKO\", { Kind = kingKind(), Beaten = beaten == true or nil })",
     "local ok, moved = true, svc.Event(player, \"FirstKO\", { Kind = kingKind(), Beaten = beaten == true or nil })"),
    ("no FirstKO signal", F, "\tFirstKOService.FirstKO:Fire(victim)\n\treturn { RespawnIn", "\treturn { RespawnIn"),
    ("the King stays after the KO", F, DONE_SET + "\tremoveKing(victim, true)\n", DONE_SET),
    ("the King splats (not leaving)", F, "pcall(S.MonsterService.RemovePersonal, e.Rec, true, leaving == true)",
     "pcall(S.MonsterService.RemovePersonal, e.Rec, true, false)"),
    # --- the get-up
    ("get-up toward the King", F, "\t\tlocal p = pos + away * back\n", "\t\tlocal p = pos - away * back\n"),
    ("get-up not lifted", F, "local at = g + Vector3.new(0, num(G.Lift, 4), 0)", "local at = g"),
    ("get-up in town", F, "if zone.Id == FK.Zone and zone.Town ~= true then\n\t\t\t\t\tlocal at", "if true then\n\t\t\t\t\tlocal at"),
    ("no fall-back to the spot itself", F, "for _, back in { math.max(0, num(G.Back, 6)), 0 } do", "for _, back in { math.max(0, num(G.Back, 6)) } do"),
    ("get-up kept forever", F, "\t\tif os.clock() > up.Until then\n\t\t\tST.Up[player] = nil\n\t\t\treturn nil\n\t\tend\n", ""),
    ("no delay before the claim", F,
     "\t\tif data and data.FirstKODone ~= true and not atStake(player) then return { Delay = respawnIn() } end\n", ""),
    ("get-up never cleared", F, "\t\tST.Up[player] = nil -- the held get-up was used\n", ""),
    ("HP not lowered after the get-up", F, "\t\t\tlocal ok, err = pcall(getUpHealth, humanoid)", "\t\t\tlocal ok, err = true, nil"),
    ("the get-up heals", F, "\tif want < humanoid.Health then humanoid.Health = want end", "\thumanoid.Health = want"),
    ("a cosmetic swap uses the get-up", F, "\t\tif cosmetic == true then return end\n\t\tlocal up", "\t\tlocal up"),
    # --- Studio aid
    ("Debug outside Studio", F, "\tif not RunService:IsStudio() then return \"Studio only\" end\n", ""),
    ("Debug reset keeps the save flag", F, "\t\tS.PlayerService.SetStat(player, \"FirstKODone\", false)\n", ""),
    # --- Config.FirstKOKing / FirstKORetry
    ("first KO from Lv 1 only", C, "\tOneHitBelow = 10,", "\tOneHitBelow = 2,"),
    ("BossClear wide again", C, "\tBossClear = 24,", "\tBossClear = 60,"),
    ("gets up with full HP", C, "Keep = 20, HealthFrac = 0.4,", "Keep = 20, HealthFrac = 1,"),
    # A23-222: the first KO gets up at GetUp.Spot beside Fizzby, facing GetUp.Face
    ("Config: no get-up spot (back by the fall)", C, "HealthFrac = 0.4, Spot = Vector3.new(6, 0, -30), Face = Vector3.new(12, 0, -34) }",
     "HealthFrac = 0.4 }"),
    ("Config: the get-up spot moved", C, "Spot = Vector3.new(6, 0, -30), Face", "Spot = Vector3.new(20, 0, -30), Face"),
    ("Config: no get-up face", C, ", Face = Vector3.new(12, 0, -34) }", " }"),
    ("get-up: the Spot ignored", F, "\tif typeof(G.Spot) == \"Vector3\" then\n", "\tif false then\n"),
    ("get-up: the Spot without Lift", F, "\t\tlocal at = ground + Vector3.new(0, num(G.Lift, 4), 0)\n", "\t\tlocal at = ground\n"),
    ("get-up: the Spot's ground ignored", F, "local ground = (okG and typeof(g) == \"Vector3\") and g or", "local ground = false and g or"),
    ("get-up: no ground hit = the Spot's Y", F, "okG and noHit == true and 0 or G.Spot.Y", "G.Spot.Y"),
    ("get-up: no ground answer = Y 0", F, "okG and noHit == true and 0 or G.Spot.Y", "0"),
    ("get-up: never turns to the Face", F, "\t\tif face and Util.FlatDistance(face, at) > 0.5 then return CFrame.lookAt(at, face) end\n", ""),
    ("get-up: faces the Face's height", F, "Vector3.new(G.Face.X, at.Y, G.Face.Z)", "G.Face"),
    ("get-up: turns to a Face on the spot", F, "if face and Util.FlatDistance(face, at) > 0.5 then", "if face then"),
    ("practice pays the King's own XP", C, "MinHP = 40, PayAs = \"BigSlime\" }", "MinHP = 40, PayAs = \"SlimeKing\" }"),
    ("save field missing", C, "Config.Data.Defaults.FirstKODone = false", "Config.Data.FirstKODoneX = false"),
    ("retry King too strong (the old 2-potion King)", C, "Retry = { Seconds = 17, HitPct = 0.075,", "Retry = { Seconds = 18, HitPct = 0.09,"),
    ("retry King hits a bit harder", C, "Retry = { Seconds = 17, HitPct = 0.075,", "Retry = { Seconds = 17, HitPct = 0.08,"),
    ("retry King hits a bit softer", C, "Retry = { Seconds = 17, HitPct = 0.075,", "Retry = { Seconds = 17, HitPct = 0.07,"),
    ("retry King too weak", C, "Retry = { Seconds = 17, HitPct = 0.075,", "Retry = { Seconds = 14, HitPct = 0.075,"),
    ("retry ignores the +N", C, "Config.WeaponDamage(tonumber(tier), lv, tonumber(enhance) or 0)", "Config.WeaponDamage(tonumber(tier), lv, 0)"),
    ("FirstKORetry reads the quest's table", C, "\tlocal FK = Config.FirstKOKing\n\tlocal R = FK.Retry",
     "\tlocal FK = Config.FirstKO\n\tlocal R = FK.Retry"),
    ("retry ignores regen", C, "return { HP = hp, Hit = R.HitPct + regen * Config.Monsters.AttackCooldown }",
     "return { HP = hp, Hit = R.HitPct }"),
    ("retry ignores the faction bonus", C, "tonumber(enhance) or 0) * (c.Damage or 1) * (1 + bonus)", "tonumber(enhance) or 0) * (c.Damage or 1)"),
    ("retry ignores the class", C, "tonumber(enhance) or 0) * (c.Damage or 1) * (1 + bonus)", "tonumber(enhance) or 0) * (1 + bonus)"),
    ("retry ignores the swing speed", C, "/ math.max(0.1, tonumber(c.SwingInterval) or 1)", "/ 1"),
    # --- CombatService: the lossless pipeline
    ("no first-KO claim", CO, "\tlocal first = claimFirstKO(victim, diedAt)\n\tif first then", "\tlocal first = nil\n\tif first then"),
    ("first KO runs the whole pipeline", CO, "\t\tlastSource[victim] = nil\n\t\treturn\n\tend\n", "\t\tlastSource[victim] = nil\n\tend\n"),
    ("first KO keeps the King as the source", CO, "\t\tlastPvPAttacker[victim] = nil\n\t\tlastSource[victim] = nil\n\t\treturn",
     "\t\tlastPvPAttacker[victim] = nil\n\t\treturn"),
    ("no First flag", CO, "RespawnIn = tonumber(first.RespawnIn) or Config.Player.RespawnTime, First = true,",
     "RespawnIn = tonumber(first.RespawnIn) or Config.Player.RespawnTime,"),
    ("first KO screen with the normal wait", CO, "RespawnIn = tonumber(first.RespawnIn) or Config.Player.RespawnTime, First = true,",
     "RespawnIn = Config.Player.RespawnTime, First = true,"),
    ("first KO screen to everyone", CO, "\tNet.Fx(victim, \"KO\", fx)", "\tNet.Fx(nil, \"KO\", fx)"),
    ("first KO not telemetry", CO, "\tCombatService.KnockedOut:Fire(victim, def and \"Monster\" or \"Other\")\n", ""),
    # --- MonsterService: the hooks, the practice kill, Near / Hold / the lifetime
    ("strike hook ignored", MO, "\tif rec._strike then\n\t\t-- A23-110", "\tif false then\n\t\t-- A23-110"),
    ("quiet kill still pays", MO, "\tif rec.Quiet == true then\n\t\t-- A23-110", "\tif false then\n\t\t-- A23-110"),
    ("quiet kill not told", MO, "\t\t\tlocal ok, err = pcall(rec._onKilled, rec)\n", "\t\t\tlocal ok, err = true, nil\n"),
    ("quiet kill no splat", MO, "\t\trec._manualAt, rec._firstAt = nil, nil\n\t\tdeathPop(rec, true)\n", "\t\trec._manualAt, rec._firstAt = nil, nil\n"),
    ("a loud personal kill not told", MO, "\t\tif rec._onKilled then -- A23-110: its service hears it after the kill",
     "\t\tif false then -- A23-110: its service hears it after the kill"),
    ("quiet for a zone monster", MO, "Quiet = (owner ~= nil and opts.Quiet == true) or nil,", "Quiet = opts.Quiet == true or nil,"),
    ("practice for a zone monster", MO, "\t\tPractice = (owner ~= nil and opts.Practice ~= nil and opts.Practice ~= false)\n",
     "\t\tPractice = (opts.Practice ~= nil and opts.Practice ~= false)\n"),
    ("practice kind not checked", MO, "and ((type(opts.Practice) == \"string\" and Config.MonsterTypes[opts.Practice] ~= nil) and opts.Practice or kind) or nil,",
     "and (type(opts.Practice) == \"string\" and opts.Practice or kind) or nil,"),
    ("practice kill not flagged", MO, "\t\tinfo.XP, info.Gold, info.Practice = pay.XP, pay.Gold, true\n", "\t\tinfo.XP, info.Gold = pay.XP, pay.Gold\n"),
    ("practice kill pays the King's XP / gold", MO, "\t\tinfo.XP, info.Gold, info.Practice = pay.XP, pay.Gold, true\n", "\t\tinfo.Practice = true\n"),
    ("a personal King needs 3 hits (2 skill hits: no quest kill)", MO, "\tif isPersonal then minHits = 0 end", "\tif false then minHits = 0 end"),
    ("every monster pays one-hit contributors", MO, "\tif isPersonal then minHits = 0 end", "\tminHits = 0"),
    ("SpawnPersonal drops the hooks", MO, "\t\tQuiet = opts.Quiet == true, -- A23-110 (see spawnMonster)\n", ""),
    ("SpawnPersonal drops Practice", MO, "\t\tPractice = opts.Practice,\n", ""),
    ("SpawnPersonal no record", MO, "\tend)\n\treturn rec.Model, rec\nend", "\tend)\n\treturn rec.Model\nend"),
    ("Distance ignored", MO, "do table.insert(tries, { ang, dist }) end", "do table.insert(tries, { ang, PERSONAL_DISTANCE }) end"),
    ("Near ignored", MO, "\tif not pos and opts.Near == true then return nil end", "\tif false then return nil end"),
    ("Hold ignored", MO, "if hold and hold == hold and hold > 0 then rec._nextAttackAt = os.clock() + math.min(hold, 10) end",
     "if false then rec._nextAttackAt = 0 end"),
    ("Hold not capped", MO, "rec._nextAttackAt = os.clock() + math.min(hold, 10)", "rec._nextAttackAt = os.clock() + hold"),
    ("a quiet King splats at its lifetime end", MO, "despawn(rec, true, rec.Quiet == true)", "despawn(rec, true)"),
    ("RemovePersonal removes a zone monster", MO, "if type(rec) ~= \"table\" or rec.Owner == nil or not rec.Alive then return false end",
     "if type(rec) ~= \"table\" or not rec.Alive then return false end"),
    # --- the listeners of the practice kill
    ("a practice kill gives a finisher card", FI, "\tif info.Practice == true then return end -- A23-110", "\tif false then return end -- A23-110"),
    ("a practice kill rolls boss drops", LO, "\tif info.Practice == true then return nil end -- A23-110", "\tif false then return nil end -- A23-110"),
    ("a practice kill counts for daily jobs", QU, "\tif info.Practice == true then return end -- A23-110", "\tif false then return end -- A23-110"),
    # --- PlayerService: the get-up
    ("get-up spot ignored", PL, "\tif g and typeof(g.CFrame) == \"CFrame\" then return g.CFrame end\n", ""),
    ("get-up delay ignored", PL, "\t\tlocal upIn = g and tonumber(g.Delay) or nil\n", "\t\tlocal upIn = nil\n"),
    ("respawn not at the spot", PL, "cosmeticPivot(character, humanoid, root, context) or spawnSpot(player))",
     "cosmeticPivot(character, humanoid, root, context) or spawnCFrame(respawnZoneId(player), firstMissionOpen(player)))"),
    # --- Main
    ("not in Main INIT", MA, "\t\"FirstKOService\", -- 게임성 개발 2: A23-110 the first KO", "\t-- 게임성 개발 2: A23-110 the first KO"),
    ("not in Main START", MA, "\t\"FirstKOService\", -- 게임성 개발 2: A23-110 (before PlayerService", "\t-- 게임성 개발 2: A23-110 (before PlayerService"),
]


def static() -> tuple[int, list[str]]:
    count, failures = 0, []

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    svc = strip_comments(read(SSS / "FirstKOService.luau"))
    bare = svc.replace("task.wait(", "").replace("task.delay(", "").replace("task.spawn(", "")
    check("wait(" not in bare and "spawn(" not in bare and "delay(" not in bare.replace("Delay", ""), "task.* only")
    check("<const>" not in svc, "no <const>")
    check("Net.Get(" not in svc and "OnServerEvent" not in svc and "Notify" not in svc,
          "no new remote, no notice (the KO Fx and model attributes only: no player text)")
    check("MonsterKilled" not in svc, "FirstKOService never fires or listens to MonsterKilled")
    check("SpawnEvent" not in svc and "RemoveEvent" not in svc, "FirstKOService never spawns or removes an event (field) monster")
    check(re.search(r"\b[Ss]tep\s*[=~<>]=?\s*\d", svc) is None and re.search(r"\d\s*[=~<>]=?\s*step\b", svc) is None,
          "no step number of its own (Config.FirstKO.Step / RematchStep only)")
    check(svc.count("svc.CurrentStep") == 2 and svc.count("Q.Step") == 1 and svc.count("Q.RematchStep") == 1,
          "the stage reads StoryQuestService.CurrentStep against Config.FirstKO.Step / RematchStep")
    check(re.search(r"Config\.FirstKO\s*=|Config\.FirstKO\.\w+\s*=[^=]", svc) is None, "FirstKOService never writes game dev 3's Config.FirstKO")
    check(svc.count("pcall(svc.Event, player, \"FirstKO\"") == 1, "one StoryQuestService.Event \"FirstKO\" call (pcall)")
    check(svc.count("SetStat(") == 2, "FirstKODone is written only by the claim and the Studio reset")
    config = read(SHARED / "Config.luau")
    check(len(re.findall(r"^Config\.FirstKO\s*=", config, re.M)) == 1, "Config.FirstKO is defined once (game dev 3's)")
    check(len(re.findall(r"^Config\.FirstKOKing\s*=", config, re.M)) == 1, "Config.FirstKOKing is defined once")
    check(len(re.findall(r"^Config\.Data\.Defaults\.FirstKODone = false", config, re.M)) == 1, "the save field is added once (additive)")
    net = read(SHARED / "Net.luau")
    check("FirstKO" not in net, "Net.Names unchanged")
    main = read(SSS / "Main.server.luau")
    check(main.count('"FirstKOService"') == 2, "FirstKOService in INIT_ORDER and START_ORDER once each")
    monster = read(SSS / "MonsterService.luau")
    check("S.CombatService.DamagePlayer(target, rec.Def.Damage, nil, false, rec.Kind)" in monster,
          "a monster without a strike hook still deals Def.Damage with its kind (BB14)")
    check("local minHits = tonumber(def.RewardMinHits) or 0" in monster,
          "the zone / field bosses keep RewardMinHits (A23-27); only personal monsters drop it")
    for name in ("FinisherService.luau", "LootService.luau", "QuestService.luau"):
        check(read(SSS / name).count("info.Practice == true") == 1, f"{name} skips a practice kill once")
    for path in (SSS / "FirstKOService.luau", SSS / "MonsterService.luau", SSS / "CombatService.luau",
                 SSS / "PlayerService.luau", SSS / "FinisherService.luau", SSS / "LootService.luau", SSS / "QuestService.luau",
                 SHARED / "Config.luau"):
        raw = path.read_bytes().decode("utf-8")
        check("\t" in raw and "\r" not in raw, f"{path.name}: LF tabs")
    return count, failures


SUITE = Suite(
    mark="FIRST_KO_KING",
    fixture=ROOT / "tools/fixtures/first_ko_king_offline.luau",
    world=ROOT / "tools/fixtures/dev2_world.luau",
    out=ROOT / "docs/art/verification_2026-10-11/offline_dev2_first_ko_king_2026-10-11.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-110: Config.FirstKO { Quest, Step, RematchStep } (game dev 3) + Config.FirstKOKing { Enabled, Kind SlimeKing, "
             "OneHitBelow 10, Zone, Landmark?, Radius, BossClear, SpawnDistance, DropTime, LandRadius, FirstHP, OneHitMult, "
             "RespawnIn, ClaimGrace, GetUp { Back, Lift, Keep, HealthFrac }, SpawnGap, Tick, Retry { Seconds, HitPct, MinHP, "
             "PayAs } } + Config.FirstKORetry + data.FirstKODone. FirstKOService: StageOf (StoryQuestService.CurrentStep "
             "== Step -> First (FirstKODone false, below OneHitBelow) else Tell (Event FirstKO every SpawnGap, no King), == "
             "RematchStep -> Retry (one win per session while the row stays); Enabled = false: Tell at Step, nothing at "
             "RematchStep), the retry HP from Config.BestUsableWeapon + its +N, a King whose owner is in a town goes home, atStake (sack, stars, bounty, PvP tag, kaiju "
             "state, a failing check: plain hits, no claim), Tick (the first King: SpawnPersonal { HP, Quiet, Distance, Strike, "
             "OnKilled, Near, Hold }; the retry King: { HP, Distance, Strike, OnKilled, Near, Hold, Practice = PayAs }; model attributes "
             "FirstKO / DropAt / DropTime / DropRadius = LandRadius), the landing thud after DropTime for both Kings inside "
             "LandRadius - BossLeap.Grace, Hold = DropTime + FirstLeapAfter, the first King's LeapGrow / LeapGrowMax (A23-113 "
             "①: its leaps' circles grow after misses), strike(rec, target, mult) (first = MaxHealth x OneHitMult, retry = "
             "MaxHealth x FirstKORetry.Hit x mult, others = Def.Damage x mult; the first KO gets up away from DropFrom), ClaimKO (death pipeline: FirstKODone + not at stake, King leaves, "
             "get-up, StoryQuestService.Event(player, 'FirstKO', { Kind }), signal FirstKO), GetUp (PlayerService delay + "
             "CFrame; the get-up spawn sets HealthFrac x MaxHealth once), the quiet King killed: Event FirstKO { Beaten = true }. "
             "CombatService: claimFirstKO first; a claimed KO only sends Fx KO { By, Name, Faction '', Lost 0, Sack false, "
             "RespawnIn, First = true } + KnockedOut. MonsterService: rec.Quiet / _strike / _onKilled / Practice, a personal "
             "monster's kill needs no RewardMinHits and tells _onKilled after MonsterKilled, a practice kill = info.Practice + "
             "the PayAs kind's XP / gold, SpawnPersonal(...) -> model, rec (Near: no home-zone fallback; Hold: no swing before; "
             "a quiet one's lifetime end floats away), RemovePersonal, GroundAt. FinisherService / LootService / QuestService skip "
             "info.Practice. PlayerService: getUp delay + spawnSpot.",
    limitations="Offline doubles: the MonsterService AI (chase, wind-up timing, SEP rings), the client drop / KO screen and "
                "real Roblox Died ordering are not run; the retry numbers are checked with a fight model (King every "
                "1.5-1.6 s, potion 30% / 10 s, uptime 60-110%), not a real fight. The shop / quick-slot / drink happenings of the "
                "KO1 rows between the KO and the rematch are reported by hand in the quest group (game dev 3's tools/test_potions.py covers the hooks). Studio play "
                "by 메인 반영 1 (or DebugCommand FirstKO first / retry).",
)

if __name__ == "__main__":
    run(SUITE)
