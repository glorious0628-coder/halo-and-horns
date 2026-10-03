-- ClassService.luau : first class pick (free, keeps level) and class change (free = Lv 1 / ticket = keep level).
-- Class ids: "Warrior", "Mage", "Archer". Display names depend on the faction (incl. "Neutral", addendum A6)
-- and always go through Config.ClassName.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local TAG = "ClassService"

local ClassService = {}

ClassService.ClassChanged = Util.Signal.new() -- (player, newClass, oldClass)

local S = nil

------------------------------------------------------------------ helpers
local function isClassId(id)
	if type(id) ~= "string" then return false end
	local def = Config.Classes[id]
	return type(def) == "table" and def.Id == id
end

local function notify(player, key, kind, ...)
	local fmt = Config.Text[key]
	if type(fmt) ~= "string" then return end
	Net.Notify(player, string.format(fmt, ...), kind)
end

local function factionOf(player)
	return S.FactionService.GetFaction(player)
end

local function kaijuState(player)
	local k = S.KaijuService
	if k and k.GetState then
		local ok, st = pcall(k.GetState, player)
		if ok and type(st) == "string" then return st end
	end
	return "None"
end

local function isClassChosen(player)
	local data = S.PlayerService.GetData(player)
	if data and type(data.ClassChosen) == "boolean" then return data.ClassChosen end
	return player:GetAttribute("ClassChosen") == true
end

------------------------------------------------------------------ public API
function ClassService.GetClass(player)
	if not player then return "Warrior" end
	local c = player:GetAttribute("Class")
	if isClassId(c) then return c end
	return "Warrior"
end

function ClassService.GetClassDef(player)
	return Config.Classes[ClassService.GetClass(player)] or Config.Classes.Warrior
end

------------------------------------------------------------------ remotes
-- first pick: free and keeps the level (also the one-time pick for data migrated from v1)
local function onChooseClass(player, classId)
	if not S.PlayerService.IsReady(player) then return end
	if not isClassId(classId) then return end
	if not Util.RateLimit(player, "ChooseClass", Config.RateLimits.ChooseClass) then return end
	if isClassChosen(player) then return end -- silent
	local faction = factionOf(player)
	if faction == "None" then
		notify(player, "NeedFaction", "bad")
		return
	end

	local old = ClassService.GetClass(player)
	S.PlayerService.SetStat(player, "Class", classId)
	S.PlayerService.SetStat(player, "ClassChosen", true)
	S.PlayerService.RefreshCharacter(player, true)
	ClassService.ClassChanged:Fire(player, classId, old) -- also when equal, so visuals / charge refresh
	notify(player, "ClassChosen", "good", Config.ClassName(classId, faction))
end

local function onChangeClass(player, classId, useTicket)
	if not S.PlayerService.IsReady(player) then return end
	if not isClassId(classId) or type(useTicket) ~= "boolean" then return end
	if not Util.RateLimit(player, "ChangeClass", Config.RateLimits.ChangeClass) then return end
	if not isClassChosen(player) then return end -- silent
	if classId == ClassService.GetClass(player) then
		notify(player, "ClassSame", "bad")
		return
	end
	if not Util.IsAlive(player) then return end -- silent
	if S.ZoneService.IsPvPZone(player) then
		notify(player, "ClassNeedSafe", "bad")
		return
	end
	if S.GrudgeService.HasSack(player) then
		notify(player, "BlockedSack", "bad")
		return
	end
	if kaijuState(player) ~= "None" then
		notify(player, "BlockedKaiju", "bad")
		return
	end
	-- Config.PvP.CombatTagTime "blocks travel/switch/class change" (+ addendum A7-4 not-in-combat for both paths):
	-- prevents a mid-fight full heal through RefreshCharacter(full).
	if S.CombatService.IsInCombat(player) then
		notify(player, "TravelBlockedCombat", "bad")
		return
	end
	if useTicket then
		local okTicket, why = S.MonetizationService.UseTicket(player, "Class")
		if not okTicket then
			-- CR-L25: a purchase still being saved is not "no ticket"
			notify(player, why == "Pending" and "TicketSaving" or "NoTicket", "bad")
			return
		end
	end

	if not useTicket then
		-- free: Level 1, XP 0 (gold, bank, weapon tier, rebirth bonus, marks, tickets, quests are kept)
		S.ProgressionService.ResetLevel(player)
	end

	local old = ClassService.GetClass(player)
	S.PlayerService.SetStat(player, "Class", classId)
	S.PlayerService.RefreshCharacter(player, true)
	ClassService.ClassChanged:Fire(player, classId, old)
	local name = Config.ClassName(classId, factionOf(player))
	notify(player, useTicket and "ClassChangedTicket" or "ClassChangedFree", "good", name)
end

------------------------------------------------------------------ lifecycle
local function onPlayerReady(player, data)
	-- repair a corrupted stored class silently (GetClass already falls back to Warrior)
	local c = data and data.Class
	if not isClassId(c) then
		Util.Warn(TAG, "invalid stored class " .. tostring(c) .. " for " .. player.Name .. "; reset to Warrior")
		S.PlayerService.SetStat(player, "Class", "Warrior")
	end
end

function ClassService.Init(registry)
	S = registry
	S.PlayerService.PlayerReady:Connect(onPlayerReady)
end

function ClassService.Start()
	Net.Get("ChooseClass").OnServerEvent:Connect(onChooseClass)
	Net.Get("ChangeClass").OnServerEvent:Connect(onChangeClass)
	print("[ClassService] started")
end

return ClassService
