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
	"SetAnnounceName", -- (hide: boolean) P5: hide my name in server-wide chat announcements
	"SetTitle", -- (id: string <= 32, owned Config.TitleDefs id or "" = automatic) BB16 nametag title
	"GhostHold", -- no arguments: A23-18 the robbed victim holds the thief's grudge sack (+2 s, 3 s cooldown)
	"SetSettings", -- (blob?) BB2: zero args = "send me mine"; one table <= 16 keys (SettingsService sanitizes + echoes)
	"RequestRankings", -- (board: Config.Ranking.Order id, scope: "Server" | "Global") BB10: answered with "Rankings"
	"BoardAction", -- E11 (boardId, "Open" | "Take" | "Reroll", slot?, "Kind" | "Sneaky"?) at a job board (BoardService)
	"UseSkill", -- SKL-2 (slot: "Q" | "Z" | "X") one press = one cast (SkillService; Q also stays on "Release")
	"UiMetric", -- BB38 (windowId: Config.Analytics.UiIds) a window the client opened (TelemetryService, metrics only)
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
	-- 게임성 개발 3 (2026-10-08), client -> server:
	"ClaimAttendance", -- A23-77: no arguments; today's attendance slot (AttendanceService)
	"ClientMetric", -- A23-79: (id: Config.Analytics.ClientMetrics, arg?) what only the client sees (TelemetryService, metrics)
	"GoToFriend", -- A23-79 #3: (userId) travel to a Roblox friend on this server (InviteService; the travel rules apply)
	"CandyTrade", -- A23-79 #4: (jar id: Config.CandyJar.Trades[].Id) candy for a stat-free title (DiaryService)
	-- 게임성 개발 2 (2026-10-08), client -> server:
	"FinisherPick", -- (card id: number, "Help" | "Tickle") the King Slime finisher card (FinisherService)
}

Net.GameStateDefaults = {
	-- WarService
	WarHaloScore = 0, WarHornsScore = 0, WarRoundEndsAt = 0, WarMode = "Idle", WarBlessing = "None",
	-- FactionService
	HaloCount = 0, HornsCount = 0,
	-- CR-L7: FactionService.GetUnderdogCounts (no rookies, no 120 s idlers) for the rebirth underdog bonus + preview
	UnderdogHalo = 0, UnderdogHorns = 0,
	-- JusticeService
	HaloPower = 0, HornsPower = 0, HaloSize = 1, HornsSize = 1, WeakerFaction = "None",
	-- GooseService
	GooseNextAt = 0, GooseActive = false, GooseEndsAt = 0, GooseRescue = 0, GoosePoach = 0,
	-- A23-14 "함께 구조" mirror (GooseService.publishMode; EventHUD.updateGoose)
	GooseMode = "Versus", GooseCoopSide = "None", GooseCoopTarget = 0, GooseCoopPeople = 0,
	-- KaijuService
	KaijuPhase = "None", KaijuUserId = 0, KaijuName = "", KaijuEndsAt = 0,
	-- HalloweenService (Config.Halloween): server time (Util.Now) of the next Pumpkin King, 0 = season off / none
	PumpkinKingNextAt = 0, PumpkinKingActive = false, PumpkinKingEndsAt = 0,
	GhostKingNextAt = 0, GhostKingActive = false, GhostKingEndsAt = 0, -- A23-45: the HauntedHollow miniboss
	-- FieldBossService (게임성 개발 2): per Config.FieldBosses key; the King Slime boss of the meadow (NextAt in the past = due, waiting for
	-- a hunter in the meadow; 0 = off)
	SlimeKingNextAt = 0, SlimeKingActive = false, SlimeKingEndsAt = 0,
	-- RankingService (BB10): the current ranking week (Config.WeekIndex) and when it ends (Monday 00:00 KST, os.time)
	RankWeekId = 0, RankWeekEndsAt = 0,
	-- SettingsService (BB3 footer): false while this server runs without a DataStore (DataService memory mode)
	SaveOK = true,
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

-- player == nil -> FireAllClients
function Net.Fx(player, kind, data)
	if player then
		Net.Get("Fx"):FireClient(player, kind, data)
	else
		Net.Get("Fx"):FireAllClients(kind, data)
	end
end

return Net
