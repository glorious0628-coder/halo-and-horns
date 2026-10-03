-- Main.server.luau : the ONLY server entry point.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
Net.CreateAll() -- remotes + GameState folder exist before anything else runs

local INIT_ORDER = {
	"DataService", "PlayerService", "NicknameService", "MonetizationService", "MapBuilder", "ZoneService", "FactionService",
	"ClassService", "CostumeService", "VitalsService", "ExpressionService", "JusticeService", "ProgressionService", "CombatService", "MonsterService", "PvPService",
	"GrudgeService", "WarService", "KaijuService", "GooseService", "ShopService", "QuestService", "CharacterVisuals",
}
-- WarService starts before GooseService (goose schedule reads the round end).
-- PlayerService starts LAST so every service is ready before the first player is processed.
local START_ORDER = {
	"MapBuilder", "ZoneService", "FactionService", "ClassService", "CostumeService", "VitalsService", "ExpressionService", "JusticeService", "ProgressionService",
	"CombatService", "MonsterService", "PvPService", "GrudgeService", "WarService", "KaijuService", "GooseService",
	"ShopService", "QuestService", "MonetizationService", "CharacterVisuals", "DataService", "NicknameService", "PlayerService",
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
--   keys: Gold, Stars, Bully, Tickets, Absent, Goose, Faction, any mirrored stat (Level, PlaytimeSeconds, Class, ...)
if game:GetService("RunService"):IsStudio() then
	local debugFn = Instance.new("BindableFunction")
	debugFn.Name = "DebugCommand"
	debugFn.OnInvoke = function(playerName, key, value)
		local player = game:GetService("Players"):FindFirstChild(playerName)
		if not player or not S.PlayerService.IsReady(player) then return "no such ready player" end
		if key == "Nickname" then
			S.NicknameService.SetNickname(player, value) -- actual live registry, including filtering/global reservation
			return player:GetAttribute("NicknameStatus")
		elseif key == "Mana" then
			S.VitalsService.DebugSetMana(player, value)
		elseif key == "Charge" then
			return S.CombatService.DebugSetCharge(player, value) and "ok" or "invalid charge"
		elseif key == "CostumePilot" then
			local data = S.PlayerService.GetData(player)
			if value ~= "Costume_HaloWarriorM" or not data or data.Faction ~= "Halo"
				or data.Class ~= "Warrior" or data.CharacterGender ~= "M" or not data.ClassChosen then
				return "select male Halo Warrior for pilot"
			end
			local folder = game:GetService("ServerStorage"):FindFirstChild("CostumePendingRigs")
			local rig = folder and folder:FindFirstChild(value)
			if not S.CostumeService.ValidateTemplate(rig) then return "invalid pending pilot" end
			local sharedConfig = require(ReplicatedStorage.Shared.Config)
			sharedConfig.Costumes.TemplateFolder = "CostumePendingRigs" -- this Play session only
			S.CostumeService.RequestRefresh(player)
		elseif key == "Gold" then
			S.ProgressionService.AddCarriedGold(player, value, "Other")
		elseif key == "Stars" then
			S.PvPService.DebugSetStars(player, value)
		elseif key == "Bully" then
			for _ = 1, value do S.JusticeService.AddBullyStack(player) end
		elseif key == "Tickets" then
			S.MonetizationService.AddTickets(player, "Class", value)
			S.MonetizationService.AddTickets(player, "Faction", value)
		elseif key == "Absent" then
			S.QuestService.DebugSimulateAbsence(player, value)
		elseif key == "Goose" then
			S.GooseService.DebugStart()
		elseif key == "Faction" then
			S.FactionService.SetFaction(player, value, "Choose")
			S.PlayerService.RefreshCharacter(player, true)
		else
			S.PlayerService.SetStat(player, key, value)
			if key == "Level" or key == "Class" then S.PlayerService.RefreshCharacter(player, true) end
		end
		return "ok"
	end
	debugFn.Parent = ServerScriptService
end

print(("[Main] Halo & Horns server started (%d/%d services)"):format(started, #START_ORDER))
