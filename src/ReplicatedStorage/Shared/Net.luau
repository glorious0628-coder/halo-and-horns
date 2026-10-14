-- Net.luau : remote names, creation (server), lookup (both), and send helpers (server).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.Names = {
	-- client -> server
	"ChooseFaction", "ChooseClass", "Swing", "Release", "SetAutoAttack", "UpgradeWeapon", "SellWeapon",
	"Rebirth", "SwitchFaction", "ChangeClass", "SetNickname", "UsePotion", "BuyPotion", "Travel", "RerollQuest", "ClaimQuest", "ClaimVacation",
	"RequestTutorial", "AcceptTutorial", -- no arguments; pending faction-guide dialogue and mission acceptance
	"IntroSeen", -- no arguments; the first-time opening ended (watched or skipped)
	"StoryAction", -- (questId, "Talk" | "Choose" | "Open", option?) for the active story step only
	"UseItem", -- (itemId, tier [, toTier]) A23-12 enhance / transfer scroll on owned weapons
	"EquipWeapon", -- (tier) equip an owned weapon from the item list (drops / legendary)
	"SellMaterials", -- no arguments; sells every material at the blacksmith anvil
	"SellItem", -- (itemId, n) artisan min ②: n of one gathered / crafted material (a Source item) at the Forge anvil (LootService)
	"SetAnnounceName", -- (hide: boolean) P5: hide my name in server-wide chat announcements
	"SetTitle", -- (id: string <= 32, owned Config.TitleDefs id or "" = automatic) BB16 nametag title
	"GhostHold", -- no arguments: A23-18 the robbed victim holds the thief's grudge sack (+2 s, 3 s cooldown)
	"SetSettings", -- (blob?) BB2: zero args = "send me mine"; one table <= 16 keys (SettingsService sanitizes + echoes)
	"RequestRankings", -- (board: Config.Ranking.Order id, scope: "Server" | "Global") BB10: answered with "Rankings"
	"BoardAction", -- E11 (boardId, "Open" | "Take" | "Reroll", slot?, "Kind" | "Sneaky"?) at a job board (BoardService)
	"UseSkill", -- SKL-2 (slot: "Q" | "Z" | "X") one press = one cast (SkillService; Q also stays on "Release")
	"UiMetric", -- BB38 (windowId: Config.Analytics.UiIds) a window the client opened (TelemetryService, metrics only)
	"SetLook", -- A23-75 (id: an owned Config.Looks id of the player's faction, or "" = none) MonetizationService
	"EquipPet", -- PET-2 (uid: an owned pet uid of a known species, or "" = put it away) PetService
	"GooseSquare", -- A23-141 ("Join" | "Leave") the Goose Square (GooseSquare.luau via GooseService)
	"SendSticker", -- A23-143 (key: a Config.Stickers.Order id) a chat sticker over my head (MonetizationService)
	"SetBubble", -- A23-144 (key: a Config.Bubbles.Order id I may use, or "" = my side's free one) MonetizationService
	-- server -> client
	"Notify", "Fx", "OpenPanel",
	"NicknameResult", -- filtered nickname + status only, never the user's raw request
	"Announce", -- A23-15: { Key, Args, Grade, UserId } to every client (server-wide chat line)
	"Quests", -- CR-L50: the owner's quest list (replaces the replicated QuestsJson attribute), fired only on change
	-- review B11: the owner's items and per-tier scroll +N (replaces the replicated ItemsJson / EnhanceJson attributes).
	-- Payload { Items = { [itemId] = count >= 1 } (Config.Loot.Items ids only), Enhance = { [tier] = 0..MaxEnhance } }
	-- for tiers 1..Config.MaxWeaponTier; fired by LootService on PlayerReady, each spawn and after every change.
	"Inventory",
	"Settings", -- BB2: { Seq, Settings } owner only: the echo of an accepted SetSettings and once on PlayerReady
	-- BB10: { Board, Scope, Rows = { { Rank, UserId (0 = hidden), Name, Sub?, Faction, Value, Test? } <= TopN },
	-- Me = { Rank?, Value, Note? }, UpdatedAt, WeekId, WeekEndsAt } owner only, the answer to RequestRankings
	"Rankings",
	-- E11: { Board, Cards = { { Slot, Id, Kind, Sneaky, Goal, Target, RewardGold, RewardXP } }, Held, Hold, Done,
	-- FullPerDay, Kind, Sneaky, RerollAt } owner only, the answer to BoardAction (Open / Take / Reroll)
	"Board",
	-- PET-2: { Equipped = uid | "", List = { { Uid, Sp, Lv, XP, Need, Name, Lean } } } owner only, PetService on
	-- PlayerReady and after every change (grant, equip, pet XP)
	"PetList",
	-- 게임성 개발 3 (2026-10-08), client -> server:
	"ClaimAttendance", -- A23-77: no arguments; today's attendance slot (AttendanceService)
	"ClientMetric", -- A23-79: (id: Config.Analytics.ClientMetrics, arg?) what only the client sees (TelemetryService, metrics)
	"GoToFriend", -- A23-79 #3: (userId) travel to a Roblox friend on this server (InviteService; the travel rules apply)
	"CandyTrade", -- A23-79 #4: (jar id: Config.CandyJar.Trades[].Id) candy for a stat-free title (DiaryService)
	-- 게임성 개발 2 (2026-10-08), client -> server:
	"FinisherPick", -- (card id: number, "Help" | "Tickle") the King Slime finisher card (FinisherService)
	"CardAction", -- A23-86 CC: (card id: number, "Good" | "Evil") the open choice card (ChoiceCard)
	"Commission", -- A23-86 H: (tier: integer) order the golden / crystal / spirit weapon at the Forge (CommissionService)
	"SetQuickSlot", -- A23-109 (게임성 개발 2): (slot 1..3, item: a Config.QuickSlots.Items key | "") QuickSlotService; the
	-- answer is the owner's QuickSlots attribute (no reply remote)
	-- 게임성 개발 3 (2026-10-11), server -> client:
	"GatherState", -- owner only { Ready = { [GatherId] = workspace:GetServerTimeNow() it can be picked again }, N, Cap }
	-- (GatherService after each gather and at PlayerReady; the client's GatherView dims my resting nodes)
	-- 게임성 개발 3 (2026-10-12) crafting (CraftService, docs/design/craft_server_2026-10-12.md §4), client -> server:
	"CraftStart", -- (recipeId: a Config.Craft.Recipes id)
	"CraftStrike", -- (sessionId: number, i: 1..5, ms: the press offset, + = late) on a press; the server notes its own time
	"CraftFinish", -- (sessionId: number) the hammer is over (or Skip): the server grades the strikes (Shared/CraftMini)
	-- server -> client (owner only):
	"CraftSession", -- { Id, Recipe, Strikes, Ring, Rest, StartAt (server time) }
	"CraftResult", -- { Id, Recipe, Kind, Tier?, Slot?, Item?, Plus, Grades, XP, Lv, LvUp, Pet? = { Uid, Species, Spd } (a summon), Fame }
	"CraftInfo", -- { Role, Lv, XP, Need, Made, On, Rep, Rank, NextRep } at join, after every craft and a class / faction change
	-- 게임성 개발 3 (2026-10-12) alchemy tonics (BuffService), client -> server:
	"UseTonic", -- (itemId: a Config.Alchemy.Tonics item) drink one; the running ones are the attributes Buff_<itemId>
	-- 게임성 개발 3 (2026-10-12) tamer research (TamerService), server -> client (owner only, the tamer):
	"TamerInfo", -- { Pts = { [family] = points }, Stage = { [family] = 0..5 }, Sum = { [family] = summons }, Stages }
	-- client -> server (anyone with a pet):
	"FeedPet", -- (uid: my pet) one Pet Treat -> that pet gets Config.Research.TreatXP pet XP
	-- 게임성 개발 3 (2026-10-12) gear slots (GearService, docs/design/gear_slots_2026-10-12.md §3), client -> server:
	"EquipGear", -- (slot: Armor | Ring, key: "T:P" from Own, or "" = take it off)
	"EquipPetGear", -- (uid: my pet, slot: PetArmor | PetAcc, key: "T:P" from Own, or "" = take it off)
	-- server -> client (owner only):
	"GearInfo", -- { Own = { ["<Slot>:T:P"] = n }, On = { Armor, Ring }, Pet = { [uid] = { PetArmor?, PetAcc? } } } at join and after changes
	-- 게임성 개발 2 (2026-10-13) A23-153 the monster codex (CodexService, docs/design/codex_cards_contract_2026-10-13.md):
	"CodexOpen", -- c->s, no arguments: send me my codex (answered with "Codex"; rate-limited)
	"Codex", -- s->c owner only { V = 1, Cards = { [kind] = { Kills, Golden, Stage, First } }, Glow } at join and on CodexOpen
	-- s->c owner only, one per moment: { Event = "Card" | "Silver" | "Holo" | "Golden" | "Page" | "Glow", Kind?, Stage?,
	-- Card? = { Kills, Golden, Stage, First }, Gold, XP (added), Title?, Page?, Key, Args, Text, Debug? }
	"CodexUp",
	-- 게임성 개발 2 (2026-10-14) A23-178 the village fund (VillageFundService, docs/design/village_fund_server_2026-10-14.md):
	"FundGive", -- c->s, no arguments (anything sent is ignored): one gift of Config.VillageFund.Step at my side's fountain
	-- s->c owner only { Faction, Today, PerDay, Step, Gold, Can, Why?, Week, Sum, Goals, Level }: after the fountain prompt
	-- and after every gift (Why = "Poor" | "Full" | "Closed" when Can is false)
	"FundOpen",
	-- 게임성 개발 2 (2026-10-13) C-5 / C-7 the player market (MarketService; docs/design/market_server_2026-10-13.md,
	-- MarketWindow contract docs/design/market_window_2026-10-12.md §6). MarketIndex / MarketMine go both ways (c->s ask, s->c
	-- answer); MarketPage answers MarketBrowse
	"MarketIndex", -- c->s () | s->c { Rows = { { Key, Low, Count } }, At, Gate = { Buy, List, ListIn } }
	"MarketBrowse", -- c->s (key "I:<id>" | "W:T:P", page 1..)
	"MarketPage", -- s->c { Key, Page, Pages, Rows = { { Id, Price (one unit), N, Plus, Left } }, Ref, Min, Max }
	"MarketMine", -- c->s () | s->c { Rows = { { Id, Key, N, Plus, Price, State, Left, Paid } }, Waiting, Today, Gate }
	"MarketList", -- c->s (kind "I" | "W", id = item id | spare "T:P", n, price of one unit)
	"MarketBuy", -- c->s (listing id, price of one unit as shown): buys the whole row (N x price)
	"MarketCancel", -- c->s (listing id)
	"PackWeapon", -- c->s (tier): an owned weapon (not in hand, not tier 1) -> a spare "T:P"
	"UnpackSpare", -- c->s (spare key "T:P"): a spare of a tier I do not own -> owned
}

Net.GameStateDefaults = {
	-- A23-178 VillageFundService: this week's fund sums (every server, + this server's unsaved) and the town light level
	-- (0 none, 1 lanterns, 2 lanterns + night fireworks); FundWeek = Config.WeekIndex of the sums
	FundWeek = 0, FundHalo = 0, FundHorns = 0, FundLevelHalo = 0, FundLevelHorns = 0,
	-- WarService
	WarHaloScore = 0, WarHornsScore = 0, WarRoundEndsAt = 0, WarMode = "Idle", WarBlessing = "None",
	-- FactionService
	HaloCount = 0, HornsCount = 0,
	-- A23-75 MonetizationService: VIP owners' display names (every server), newest first, one per line
	SupporterNames = "",
	-- A: SwitchService (the live switchboard): true = on; the screen hides what is off (PassSales: the [Buy] buttons)
	SwitchPassSales = true, SwitchHalloween = true, SwitchCrownWar = true, SwitchGoose = true,
	-- CR-L7: FactionService.GetUnderdogCounts (no rookies, no 120 s idlers) for the rebirth underdog bonus + preview
	UnderdogHalo = 0, UnderdogHorns = 0,
	-- JusticeService
	HaloPower = 0, HornsPower = 0, HaloSize = 1, HornsSize = 1, WeakerFaction = "None",
	-- GooseService
	GooseNextAt = 0, GooseActive = false, GooseEndsAt = 0, GooseRescue = 0, GoosePoach = 0,
	-- A23-14 "함께 구조" mirror (GooseService.publishMode; EventHUD.updateGoose)
	GooseMode = "Versus", GooseCoopSide = "None", GooseCoopTarget = 0, GooseCoopPeople = 0,
	-- A23-131 egg hunt: the crown egg's overtime end (0 = none; GooseEndsAt never moves)
	GooseOvertimeUntil = 0,
	-- KaijuService
	KaijuPhase = "None", KaijuUserId = 0, KaijuName = "", KaijuEndsAt = 0,
	-- HalloweenService (Config.Halloween): server time (Util.Now) of the next Pumpkin King, 0 = season off / none
	PumpkinKingNextAt = 0, PumpkinKingActive = false, PumpkinKingEndsAt = 0,
	GhostKingNextAt = 0, GhostKingActive = false, GhostKingEndsAt = 0, -- A23-45: the HauntedHollow miniboss
	-- FieldBossService (게임성 개발 2): per Config.FieldBosses key; the King Slime boss of the meadow (NextAt in the past = due, waiting for
	-- a hunter in the meadow; 0 = off)
	SlimeKingNextAt = 0, SlimeKingActive = false, SlimeKingEndsAt = 0,
	ClatterNextAt = 0, ClatterActive = false, ClatterEndsAt = 0, -- J Captain Clatter (the ruins)
	-- RankingService (BB10): the current ranking week (Config.WeekIndex) and when it ends (Monday 00:00 KST, os.time)
	RankWeekId = 0, RankWeekEndsAt = 0,
	-- A23-105 DayCycleService: the phase of the ClockTime shown and the night share (0..1) of the time-of-day look at it
	-- (under every sky, a war sky included), the weather
	DayPhase = "Day", NightLevel = 0, Weather = "Clear",
	-- SettingsService (BB3 footer): false while this server runs without a DataStore (DataService memory mode)
	SaveOK = true,
	-- Net.CreateAll (게임성 개발 1 10/13): true in a private server (game.PrivateServerId ~= "", which the client cannot read);
	-- the shop card and the HUD line read it
	PrivateServer = false,
}

-- server only; call once, first thing in Main.server.luau
function Net.CreateAll()
	assert(RunService:IsServer(), "Net.CreateAll is server-only")
	local folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in Net.Names do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage

	local gs = ReplicatedStorage:FindFirstChild("GameState") or Instance.new("Folder")
	gs.Name = "GameState"
	for k, v in Net.GameStateDefaults do
		if gs:GetAttribute(k) == nil then gs:SetAttribute(k, v) end
	end
	local okP, privateId = pcall(function() return game.PrivateServerId end)
	gs:SetAttribute("PrivateServer", okP and type(privateId) == "string" and privateId ~= "")
	gs.Parent = ReplicatedStorage
end

function Net.Get(name)
	if RunService:IsServer() then
		local r = ReplicatedStorage.Remotes:FindFirstChild(name)
		assert(r, "Unknown remote: " .. tostring(name))
		return r
	end
	return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(name)
end

function Net.GameState()
	if RunService:IsServer() then return ReplicatedStorage.GameState end
	return ReplicatedStorage:WaitForChild("GameState")
end

-- server helpers --------------------------------------------------------
-- kind: "info" | "good" | "bad" | "reward" | "announce"
-- sound (sound_spec 2026-10-07 §4-1, optional): the Config.Audio key the client plays for this line ("None" = no sound);
-- without it the client keeps its kind mapping ("bad" -> Deny, "reward" -> QuestDone)
function Net.Notify(player, text, kind, duration, sound)
	Net.Get("Notify"):FireClient(player, { Text = text, Kind = kind or "info", Duration = duration, Sound = sound })
end

function Net.NotifyAll(text, kind, duration, sound)
	Net.Get("Notify"):FireAllClients({ Text = text, Kind = kind or "announce", Duration = duration, Sound = sound })
end

-- Korean mode (contract docs/design/l10n_contract_2026-10-11.md §5-3): a keyed line { Key, Args, Named } that every client
-- writes in its own language (L10n.Msg); Text = the English copy (old clients / logs; a client with Key never uses it).
-- args = array (pre-formatted numbers as strings, §4), named = { Unit = ..., ... }. In Studio an unknown key errors.
local function keyPayload(key, args, named, kind, duration, sound)
	local L10n = require(script.Parent:WaitForChild("L10n"))
	if RunService:IsStudio() and (type(key) ~= "string" or L10n.Get(key, "en") == key) then
		error("Net.NotifyKey: unknown text key " .. tostring(key), 3)
	end
	return { Key = key, Args = args, Named = named, Kind = kind, Duration = duration, Sound = sound,
		Text = L10n.Msg({ Key = key, Args = args, Named = named }, "en") }
end

function Net.NotifyKey(player, key, args, kind, duration, sound, named)
	Net.Get("Notify"):FireClient(player, keyPayload(key, args, named, kind or "info", duration, sound))
end

function Net.NotifyAllKey(key, args, kind, duration, sound, named)
	Net.Get("Notify"):FireAllClients(keyPayload(key, args, named, kind or "announce", duration, sound))
end

-- player == nil -> FireAllClients
function Net.Fx(player, kind, data)
	if player then
		Net.Get("Fx"):FireClient(player, kind, data)
	else
		Net.Get("Fx"):FireAllClients(kind, data)
	end
end

return Net
