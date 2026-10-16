-- Main.server.luau : the ONLY server entry point.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
Config.ApplyTestServer() -- A23-156: the private test server's settings (Config.TestServer), before any service reads them
Net.CreateAll() -- remotes + GameState folder exist before anything else runs

local INIT_ORDER = {
	"DataService", "PlayerService", "NicknameService", "MonetizationService", "MapBuilder", "ZoneService", "FactionService",
	"ClassService", "VitalsService", "JusticeService", "ProgressionService", "CombatService", "MonsterService", "PvPService",
	"GrudgeService", "WarService", "KaijuService", "GooseService", "ShopService", "QuestService", "StoryQuestService",
	"AnnounceService", "SettingsService", "RankingService", "LootService", "TelemetryService", "TitleService",
	"CharacterVisuals", "HalloweenService", "PetService", "BoardService", "BarkService", "DamageWindow", "SkillService",
	"StatService", "ChatText",
	"AttendanceService", -- 게임성 개발 3: A23-77
	"ReturnService", "InviteService", "DiaryService", -- 게임성 개발 3: A23-79
	"FinisherService", -- 게임성 개발 2: the field bosses' finisher card (points: Deeds)
	"FieldBossService", -- 게임성 개발 2: the year-round field bosses (the King Slime, ...)
	"HuntFameService", -- 게임성 개발 2: 2-A #4 Honor / Infamy from own-level hunting (A23-135)
	"Deeds", "ChoiceCard", "CommissionService", "KillLog", -- 게임성 개발 3: A23-86 (Deeds before ChoiceCard)
	"KillCardService", -- 게임성 개발 2: A23-87 cards some kills offer (after ChoiceCard)
	"QuickSlotService", -- 게임성 개발 2: A23-109 quick slots 1·2·3 (the save + the SetQuickSlot remote)
	"FirstKOService", -- 게임성 개발 2: A23-110 the first KO (the King Slime's one hit on the quest step, lossless)
	"LostFoundService", -- 게임성 개발 3: #45 the lost things (after ChoiceCard: it listens to the card)
	"GatherService", -- 게임성 개발 3: gathering (after LootService and ChoiceCard: it grants items, opens the bloom card)
	"CraftService", -- 게임성 개발 3: artisan crafting (after LootService, ProgressionService and ShopService)
	"BuffService", -- 게임성 개발 3: alchemy tonics (CombatService / LootService / ProgressionService ask it at run time)
	"TamerService", -- 게임성 개발 3: tamer research points (listens to MonsterService.MonsterKilled)
	"GearService", -- 게임성 개발 3: gear slots (after PetService: it asks it to republish a pet's gear)
	"ServerErrorService", "SwitchService", -- 게임성 개발 3: ops safety (the error record, the live switchboard)
	"HealthService", -- 게임성 개발 3: the hourly health report (2026-10-09)
	"DayCycleService", -- 게임성 개발 2: A23-105 the day and the weather (a crown-war sky covers its look, the clock turns on)
	"CodexService", -- 게임성 개발 2: A23-153 the monster codex (listens to MonsterKilled; pays through ProgressionService)
	"TestMetricsService", -- 게임성 개발 2: A23-160 the private test's numbers board (read-only observer)
	"VillageFundService", -- 게임성 개발 2: A23-178 the village fund (the fountain gifts, the week's sums)
	"MarketService", -- 게임성 개발 2: C-5 / C-7 the player market (after DataService, LootService, ProgressionService)
	"ReviveService", -- 게임성 개발 2: 99N G helping a friend up (after FirstKOService and PvPService)
	"PartyService", "QuestCreditService", -- A23-201 / A23-204 the party + who a kill's quests credit (MonsterService asks at run time)
	"SceneSetup", -- 게임성 개발 2: A23-218 ② the Studio test scenes (DebugCommand key Scene; refuses outside Studio)
}
-- WarService starts before GooseService (goose schedule reads the round end).
-- PlayerService starts LAST so every service is ready before the first player is processed.
local START_ORDER = {
	"MapBuilder", "ZoneService", "FactionService", "ClassService", "VitalsService", "JusticeService", "ProgressionService",
	"CombatService", "MonsterService", "PvPService", "GrudgeService", "WarService", "KaijuService", "GooseService",
	"ShopService", "QuestService", "StoryQuestService", "AnnounceService", "HalloweenService", "LootService", "TelemetryService",
	"TitleService", "MonetizationService", "CharacterVisuals", "DataService",
	"NicknameService", "SettingsService", "RankingService", "PetService", "BoardService", "BarkService", "DamageWindow",
	"SkillService", "StatService", "ChatText",
	"AttendanceService", -- 게임성 개발 3: A23-77 (before PlayerService: it listens to PlayerReady)
	"ReturnService", "InviteService", "DiaryService", -- 게임성 개발 3: A23-79 (before PlayerService too)
	"FinisherService", "FieldBossService", -- 게임성 개발 2 (before PlayerService too)
	"HuntFameService", -- 게임성 개발 2: 2-A #4 (before PlayerService too)
	"Deeds", "ChoiceCard", "CommissionService", "KillLog", -- 게임성 개발 3: A23-86 (before PlayerService too)
	"KillCardService", -- 게임성 개발 2: A23-87 (before PlayerService too)
	"QuickSlotService", -- 게임성 개발 2: A23-109 (before PlayerService too: it listens to PlayerReady)
	"FirstKOService", -- 게임성 개발 2: A23-110 (before PlayerService too: it listens to PlayerLeaving / CharacterSpawned)
	"LostFoundService", -- 게임성 개발 3: #45 (before PlayerService too: it listens to PlayerReady)
	"GatherService", -- 게임성 개발 3: gathering (before PlayerService too: it listens to PlayerReady)
	"CraftService", -- 게임성 개발 3: crafting (before PlayerService too: a pending craft finishes at PlayerReady)
	"BuffService", -- 게임성 개발 3: tonics (before PlayerService too: running tonics show at PlayerReady)
	"TamerService", -- 게임성 개발 3: tamer research (before PlayerService too: TamerInfo at PlayerReady)
	"GearService", -- 게임성 개발 3: gear slots (before PlayerService too: GearInfo / GearAtk / GearHp at PlayerReady)
	"ServerErrorService", "SwitchService", -- 게임성 개발 3: ops safety (before PlayerService too)
	"HealthService", -- 게임성 개발 3: the hourly health report (before PlayerService: it listens to PlayerReady)
	"DayCycleService", -- 게임성 개발 2: A23-105 (after WarService, whose Start bootstraps the light and hands Neutral to it)
	"CodexService", -- 게임성 개발 2: A23-153 (before PlayerService too: it listens to PlayerReady)
	"TestMetricsService", -- 게임성 개발 2: A23-160 (before PlayerService too: it listens to PlayerReady)
	"VillageFundService", -- 게임성 개발 2: A23-178 (after SwitchService: it asks the switch VillageFund)
	"MarketService", -- 게임성 개발 2: C-5 / C-7 (before PlayerService too: the join check at PlayerReady)
	"ReviveService", -- 게임성 개발 2: 99N G (after PvPService: its spawn shield comes first; before PlayerService)
	"PartyService", "QuestCreditService", -- A23-201 (before PlayerService too: it listens to PlayerLeaving)
	"SceneSetup", -- 게임성 개발 2: A23-218 ② (Studio test scenes only)
	"PlayerService",
}

local S = {}
for _, name in INIT_ORDER do
	local module = ServerScriptService:WaitForChild(name)
	local ok, result = pcall(require, module)
	if not ok then
		error(("[Main] failed to require %s: %s"):format(name, tostring(result)))
	end
	S[name] = result
end

for _, name in INIT_ORDER do
	local ok, err = pcall(S[name].Init, S)
	if not ok then
		warn(("[Main] %s.Init failed: %s"):format(name, tostring(err)))
	end
end

local started = 0
for _, name in START_ORDER do
	local ok, err = pcall(S[name].Start)
	if ok then
		started += 1
	else
		warn(("[Main] %s.Start failed: %s"):format(name, tostring(err)))
	end
end

-- Studio-only debug hook for the test checklist (Command Bar, server side):
--   game.ServerScriptService.DebugCommand:Invoke("Player1", "Level", 20)
--   game.ServerScriptService.DebugCommand:Invoke("Player1", "Gold", 5000)   -- adds carried gold
--   keys: Gold, Stars, Bully, Tickets, Absent, Goose, PumpkinKing, Faction, any mirrored stat (Level, PlaytimeSeconds, Class, ...)
--   A23-77: AttendNext (today's attendance claim opens again); Finisher (a King Slime finisher card, no kill); SlimeKing / any Config.FieldBosses key (that boss now)
--   A23-110: FirstKO ("first" / "retry": that personal King without the quest, this session; "reset": FirstKODone = false; "off": back to the quest)
--   A23-77: AttendNext (today's attendance claim opens again)
--   StoryStep ("M2_3:1": the active quest goes to that step), StorySub ("KO1:3": that Sub quest starts at that step, a bare "KO1" =
--   step 1), StoryDone ("KO1": that quest is done, no reward)
--   A23-86: Card (a choice card of that Config.ChoiceCard.Kinds id opens now)
--   #45: Lost ("Teddy" / "ClubBadge" / "GuardMedal" / "CandyBag": a find now with its card, "clear": forget the find; needs Config.LostFound.Enabled for the walk)
--   ops: Errors (the last server errors; value "stored" / "live" reads the saved document)
--   ops: Health (this server's unsaved hourly sums + alerts; value "stored" / "live" or "live:48" reads the saved hours)
--   BB10: RankSettle (settle this week's server board now; STUDIO season), RankWrite (write my rows now), PairCD (clear
--   my pair cooldowns + this week's fair-point counters). Every command marks the save DebugTainted (never on PRE / B1),
--   except the read-only ones (Errors, Health, StoryDump, DataDump, LootRoll: they only read or count).
--   A23-75: Pass ("XP2:on" / "Gold2:off" / "VIP:clear" / "HaloIce:on": this session only, never saved, never on the
--   shared supporter board), LookGrant ("HaloSprout": an attendance look, saved like a real unlock)
--   A23-105 (no player needed, nothing saved or tainted): Clock (hours 0-24: the day jumps there and goes on), Weather
--   ("Rain" / "Snow" / "Clear" [":seconds"]: that weather now, snow in any month here), DayState (the day / weather now):
--   game.ServerScriptService.DebugCommand:Invoke("", "Clock", 21)
--   A23-218 ②: Scene (a preset of SceneSetup.PRESETS, "Kill" = beat the nearest scene monster, or a JSON spec; tools/scene.py)
if game:GetService("RunService"):IsStudio() then
	local debugFn = Instance.new("BindableFunction")
	debugFn.Name = "DebugCommand"
	local READ_ONLY = { Errors = true, Health = true, StoryDump = true, DataDump = true, LootRoll = true } -- these change nothing saved
	debugFn.OnInvoke = function(playerName, key, value)
		if key == "Clock" or key == "Weather" or key == "DayState" then -- A23-105: the server's day (no player, no save)
			return S.DayCycleService.Debug(key, value)
		end
		local player = game:GetService("Players"):FindFirstChild(playerName)
		if not player or not S.PlayerService.IsReady(player) then return "no such ready player" end
		local okData, tainted = pcall(function() return S.PlayerService.GetData(player) end)
		tainted = okData and type(tainted) == "table" and tainted or nil
		if tainted and not READ_ONLY[key] then tainted.DebugTainted = true end -- BB10: a debugged save never reaches PRE / B1 boards (a read-only command is no debugging)
		if key == "RankSettle" then
			return S.RankingService.DebugSettle()
		elseif key == "RankWrite" then
			return S.RankingService.DebugWrite(player)
		elseif key == "PairCD" then
			if tainted then
				tainted.PairCD = {}
				if type(tainted.Rank) == "table" then tainted.Rank.Victims, tainted.Rank.YieldN = {}, 0 end
			end
			return "ok"
		elseif key == "Nickname" then
			S.NicknameService.SetNickname(player, value) -- actual live registry, including filtering/global reservation
			return player:GetAttribute("NicknameStatus")
		elseif key == "Mana" then
			S.VitalsService.DebugSetMana(player, value)
		elseif key == "Charge" then
			return S.CombatService.DebugSetCharge(player, value) and "ok" or "invalid charge"
		elseif key == "Scene" then -- A23-218 ② Studio test scene (SceneSetup.luau)
			return S.SceneSetup.Apply(player, value)
		elseif key == "StoryStep" then -- Studio test aid: "M2_3:1" moves the active main quest back/forward to that step
			local id, st = string.match(tostring(value), "^([%w_]+):(%d+)$")
			local data = S.PlayerService.GetData(player)
			local story = data and type(data.Story) == "table" and data.Story
			local main = story and story.Main
			local track = (main and main.Id == id) and main or (story and type(story.Subs) == "table" and story.Subs[id])
			if not track then return "no active quest " .. tostring(id) end
			track.St, track.P, track.T, track.Claim = tonumber(st), 0, {}, false
			return "ok"
		elseif key == "StorySub" then -- Studio test aid: "KO1:3" starts that Sub quest at that step (a bare "KO1" = step 1)
			local id, step = string.match(tostring(value), "^([%w_]+):?(%d*)$")
			if not id then return 'use "<quest>:<step>"' end
			return S.StoryQuestService.DebugSub(player, id, tonumber(step) or 1)
		elseif key == "StoryDone" then -- Studio test aid: "KO1" marks that quest done (no reward)
			return S.StoryQuestService.DebugDone(player, tostring(value))
		elseif key == "StoryDump" then -- Studio test aid: the saved story quest state as JSON
			local data = S.PlayerService.GetData(player)
			return game:GetService("HttpService"):JSONEncode(data and data.Story or {})
		elseif key == "DataDump" then -- Studio test aid: one saved data field as JSON (value = field name, e.g. "Telemetry")
			local data = S.PlayerService.GetData(player)
			return game:GetService("HttpService"):JSONEncode({ [tostring(value)] = data and data[tostring(value)] })
		elseif key == "Item" then -- Studio test aid: value = "Enh70" or "Enh70:5" (A23-12 item id[:count])
			local id, n = string.match(tostring(value), "^(%w+):?(%d*)$")
			return S.LootService.DebugGive(player, id, tonumber(n) or 1)
		elseif key == "AutoIdle" then -- Studio test aid: seconds before auto combat rests (P2), this server only
			Config.Combat.AutoIdleSeconds = math.max(10, tonumber(value) or 900)
			return "AutoIdleSeconds=" .. Config.Combat.AutoIdleSeconds
		elseif key == "Announce" then -- Studio test aid: "RareWeapon:4:Goblin" / "Jackpot:8" / "FirstMax:3" (real service)
			local k, t, m = string.match(tostring(value), "^(%a+):?(%d*):?(%a*)$")
			local tier = tonumber(t) or 4
			local info = Config.WeaponInfo and Config.WeaponInfo[tier]
			S.AnnounceService.Announce(player, k, { Weapon = tier, Monster = m ~= "" and m or nil }, info and info.Grade or "Rare")
			return "sent " .. tostring(k)
		elseif key == "LootReset" then -- Studio test aid: clear items / scroll +N / loot flags (value = weapon mask to keep)
			return S.LootService.DebugReset(player, tonumber(value) or 0) -- A23-34: 0 = bare-handed start
		elseif key == "LootRoll" then -- Studio test aid (review B12): "Slime:200" or "Slime:200:golden" = COUNT-ONLY rolls
			-- with the real drop tables; nothing is granted, saved or announced (returns a JSON tally)
			local kind, n, golden = string.match(tostring(value), "^(%w+):?(%d*):?(%a*)$")
			local tally = S.LootService.DebugSimulate(kind, math.clamp(tonumber(n) or 1, 1, 100000), golden == "golden")
			if not tally then return "unknown monster kind: " .. tostring(kind) end
			return game:GetService("HttpService"):JSONEncode(tally)
		elseif key == "Gold" then
			S.ProgressionService.AddCarriedGold(player, value, "Other")
		elseif key == "Stars" then
			S.PvPService.DebugSetStars(player, value)
		elseif key == "Bully" then
			for _ = 1, value do S.JusticeService.AddBullyStack(player) end
		elseif key == "Pass" then -- A23-75 Studio test aid: a game pass on / off / back to Roblox's answer
			local k, mode = string.match(tostring(value), "^(%w+):?(%a*)$")
			return S.MonetizationService.DebugSetPass(player, k, mode ~= "" and mode or "on")
		elseif key == "LookGrant" then -- A23-75 Studio test aid: unlock an attendance look (A23-77)
			return tostring(S.MonetizationService.GrantLook(player, tostring(value)))
		elseif key == "Tickets" then
			S.MonetizationService.AddTickets(player, "Class", value)
			S.MonetizationService.AddTickets(player, "Faction", value)
		elseif key == "Absent" then
			S.QuestService.DebugSimulateAbsence(player, value)
		elseif key == "FirstKO" then -- A23-110 Studio test aid: "first" / "retry" (that King without the quest), "reset", "off"
			return S.FirstKOService.Debug(player, value)
		elseif key == "Finisher" then -- Studio test aid: a King Slime finisher card without a kill (FinisherService)
			return S.FinisherService.DebugOffer(player) and "ok" or "a card is open"
		elseif key == "Errors" then -- ops: the last server errors (value nil = this server, "stored" = the saved document, "live" = the real game's)
			return S.ServerErrorService.Debug(value ~= nil and tostring(value) or nil)
		elseif key == "Health" then -- ops: the hourly health report (value nil = this server, "stored" / "live" [":hours"] = the saved documents)
			return S.HealthService.Debug(value ~= nil and tostring(value) or nil)
		elseif key == "Lost" then -- #45 Studio test aid: "Teddy" / "ClubBadge" / "GuardMedal" / "CandyBag" (a find now), "" (the zone's item), "clear"
			if tostring(value) == "clear" then return S.LostFoundService.DebugClear(player) end
			return S.LostFoundService.DebugFind(player, value ~= nil and tostring(value) ~= "" and tostring(value) or nil)
		elseif key == "Card" then -- A23-86 Studio test aid: a choice card of that kind (Config.ChoiceCard.Kinds) opens now
			return tostring(S.ChoiceCard.Offer(player, tostring(value)))
		elseif key == "AttendNext" then -- A23-77 Studio test aid: today's attendance claim opens again
			return S.AttendanceService.DebugNextDay(player)
		elseif key == "Codex" then -- A23-153 Studio test aid: "reset", "Slime:99" (kills, no reward), "show:Slime:Silver" (the moment again)
			return S.CodexService.Debug(player, value)
		elseif key == "Goose" then
			S.GooseService.DebugStart()
		elseif type(Config.FieldBosses) == "table" and type(Config.FieldBosses[key]) == "table" and key ~= "Order" then
			return S.FieldBossService.DebugSpawn(key) -- Studio test aid: that field boss appears now (SlimeKing, ...)
		elseif key == "PumpkinKing" or key == "GhostKing" then -- Studio test aid: that Halloween miniboss appears now
			return S.HalloweenService.DebugSpawn(key)
		elseif key == "Faction" then
			S.FactionService.SetFaction(player, value, "Choose")
			S.PlayerService.RefreshCharacter(player, true)
		else
			local oldClass = S.ClassService.GetClass(player)
			S.PlayerService.SetStat(player, key, value)
			if key == "Level" or key == "Class" then S.PlayerService.RefreshCharacter(player, true) end
			-- act like ChooseClass / ChangeClass so the ClassChanged listeners run (A23-39: the tamer's pet + TamerNotice;
			-- QA sets Faction, then Class, then ClassChosen)
			if key == "Class" or key == "ClassChosen" then
				S.ClassService.ClassChanged:Fire(player, S.ClassService.GetClass(player), oldClass)
			end
		end
		return "ok"
	end
	debugFn.Parent = ServerScriptService
end

print(("[Main] Halo & Horns server started (%d/%d services)"):format(started, #START_ORDER))
