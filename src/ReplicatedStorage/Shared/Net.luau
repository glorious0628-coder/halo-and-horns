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
	"GhostHold", -- no arguments: A23-18 the robbed victim holds the thief's grudge sack (+2 s, 3 s cooldown)
	-- server -> client
	"Notify", "Fx", "OpenPanel",
	"NicknameResult", -- filtered nickname + status only, never the user's raw request
	"Announce", -- A23-15: { Key, Args, Grade, UserId } to every client (server-wide chat line)
	"Quests", -- CR-L50: the owner's quest list (replaces the replicated QuestsJson attribute), fired only on change
	-- review B11: the owner's items and per-tier scroll +N (replaces the replicated ItemsJson / EnhanceJson attributes).
	-- Payload { Items = { [itemId] = count >= 1 } (Config.Loot.Items ids only), Enhance = { [tier] = 0..MaxEnhance } }
	-- for tiers 1..Config.MaxWeaponTier; fired by LootService on PlayerReady, each spawn and after every change.
	"Inventory",
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
function Net.Notify(player, text, kind, duration)
	Net.Get("Notify"):FireClient(player, { Text = text, Kind = kind or "info", Duration = duration })
end

function Net.NotifyAll(text, kind, duration)
	Net.Get("Notify"):FireAllClients({ Text = text, Kind = kind or "announce", Duration = duration })
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
