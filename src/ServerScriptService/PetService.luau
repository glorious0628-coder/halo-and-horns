-- PetService.luau : pets (A23-39 now; PET-2 later adds levels / XP / EquipPet / the pet list remote).
-- Server-authoritative. Save (Config.Data.Defaults.Pets): List[uid] = { Sp, Lv, XP, Name, Lean, Bound },
-- Equipped = { uid } (one pet in the beta), Next = the next uid number. Every client sees only the attributes
-- EquippedPet (species id, "" = none), PetLv and PetForm ("" = the base look); the pet follows its owner on the clients
-- (PET-3, 게임성 개발 1). A pet is never a server object, so it is never a target of anything.
--
-- A23-39 pet tamer (Config.Tamer, Config.IsTamer = the artisan guild's Archer): the moment a player is a tamer (class
-- pick / class change / faction change, or a join as one) they get the baby slime once, equipped, Bound. A save that was
-- the artisan hunter before A23-39 gets one notice + one free class change ticket (TamerNotice, saved first).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local PetService = {}
local S = nil
local TAG = "PetService"
local TAMER = Config.Tamer
local TXT = TAMER.Text
-- species the beta knows (PET-2 moves this to Config.Pets); unknown saved species are kept but never equipped
local KNOWN = { [TAMER.Pet] = true }
local LIMIT = { MaxLv = 10, NameLen = 20, UidLen = 32, Pets = 64 }

PetService.PetGranted = Util.Signal.new() -- (player, uid, species): PET-6 announcements later

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function getData(player)
	local ok, data = pcall(S.PlayerService.GetData, player)
	return ok and type(data) == "table" and data or nil
end

local function notify(player, text, kind)
	if type(text) == "string" and text ~= "" then pcall(Net.Notify, player, text, kind or "info") end
end

------------------------------------------------------------------ data
-- repairs data.Pets in place (a corrupted entry is dropped; an unknown species is kept but never equipped)
function PetService.Sanitize(data)
	local pets = type(data.Pets) == "table" and data.Pets or {}
	local list, count = {}, 0
	if type(pets.List) == "table" then
		for uid, p in pets.List do
			if count < LIMIT.Pets and type(uid) == "string" and #uid >= 1 and #uid <= LIMIT.UidLen and type(p) == "table"
				and type(p.Sp) == "string" and #p.Sp >= 1 and #p.Sp <= LIMIT.UidLen then
				count += 1
				list[uid] = {
					Sp = p.Sp,
					Lv = math.clamp(math.floor(num(p.Lv, 1)), 1, LIMIT.MaxLv),
					XP = math.max(0, math.floor(num(p.XP, 0))),
					Name = type(p.Name) == "string" and string.sub(p.Name, 1, LIMIT.NameLen) or "",
					Lean = type(p.Lean) == "string" and string.sub(p.Lean, 1, LIMIT.NameLen) or "",
					Bound = p.Bound == true,
				}
			end
		end
	end
	local equipped = {}
	if type(pets.Equipped) == "table" then
		for _, uid in pets.Equipped do
			if #equipped < 1 and type(uid) == "string" and list[uid] and KNOWN[list[uid].Sp] then table.insert(equipped, uid) end
		end
	end
	data.Pets = { List = list, Equipped = equipped, Next = math.max(1, math.floor(num(pets.Next, 1))) }
	return data.Pets
end

-- the attributes every client reads (EquippedPet / PetLv / PetForm)
local function publish(player, data)
	local pets = data.Pets
	local uid = type(pets) == "table" and type(pets.Equipped) == "table" and pets.Equipped[1] or nil
	local p = uid and pets.List[uid] or nil
	player:SetAttribute("EquippedPet", p and p.Sp or "")
	player:SetAttribute("PetLv", p and p.Lv or 0)
	player:SetAttribute("PetForm", "")
end

local function findSpecies(pets, species)
	for uid, p in pets.List do
		if p.Sp == species then return uid end
	end
	return nil
end

------------------------------------------------------------------ A23-39 pet tamer
-- the tamer's baby slime: added once (an owned baby slime is never duplicated), equipped when nothing is. quiet = no
-- notice. Returns the new uid, or nil when the player already had one.
function PetService.GiveTamerPet(player, quiet)
	local data = getData(player)
	if not data then return nil end
	local pets = PetService.Sanitize(data)
	local have = findSpecies(pets, TAMER.Pet)
	if have then
		if #pets.Equipped == 0 then
			pets.Equipped = { have }
			publish(player, data)
		end
		return nil
	end
	local uid
	repeat -- never reuse a uid a kept (e.g. unknown-species) entry holds
		uid = "P" .. tostring(pets.Next)
		pets.Next += 1
	until pets.List[uid] == nil
	pets.List[uid] = { Sp = TAMER.Pet, Lv = 1, XP = 0, Name = "", Lean = "", Bound = true }
	if #pets.Equipped == 0 then pets.Equipped = { uid } end
	publish(player, data)
	if not quiet then notify(player, TXT.PetGot, "reward") end
	PetService.PetGranted:Fire(player, uid, TAMER.Pet)
	return uid
end

local function isTamer(player, data)
	return data.ClassChosen == true and Config.IsTamer(data.Class, data.Faction)
end

-- a join: a save that was the artisan hunter before A23-39 (a tamer without TamerNotice) gets the notice and one free
-- class change ticket, once (the flag is saved first); every tamer then gets the pet
local function onPlayerReady(player, data)
	data = type(data) == "table" and data or getData(player)
	if not data then return end
	PetService.Sanitize(data)
	publish(player, data)
	if not isTamer(player, data) then return end
	if data.TamerNotice ~= true then
		data.TamerNotice = true
		local m = S.MonetizationService
		if type(m) == "table" and type(m.AddTickets) == "function" then
			local ok, err = pcall(m.AddTickets, player, "Class", 1)
			if not ok then Util.Warn(TAG, "free class change ticket: " .. tostring(err)) end
		end
		-- below Lv FreeKeepLevelBelow the class window has no ticket button (a free change keeps the level anyway)
		notify(player, Config.ClassChangeKeepsLevel(data.Level) and TXT.BecameFree or TXT.Became, "reward")
	end
	PetService.GiveTamerPet(player)
end

-- becoming a tamer during a session (class pick / class change / faction change): chosen now, so no notice ticket
local function onBecame(player)
	if not S.PlayerService.IsReady(player) then return end
	local data = getData(player)
	if not data or not isTamer(player, data) then return end
	data.TamerNotice = true
	PetService.GiveTamerPet(player)
end

------------------------------------------------------------------ the models the clients draw (PET-3)
-- ServerStorage.CustomModels.Pet<species> -> ReplicatedStorage.PetModels.<species>, once at Start (a missing model is
-- skipped; every script inside the copy is removed). The PET-3 follower (게임성 개발 1) clones from PetModels.
local SCRIPT_CLASSES = { Script = true, LocalScript = true, ModuleScript = true }
function PetService.PublishModels()
	local custom = ServerStorage:FindFirstChild("CustomModels")
	if not custom then return 0 end
	local folder = ReplicatedStorage:FindFirstChild("PetModels")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PetModels"
		folder.Parent = ReplicatedStorage
	end
	local made = 0
	for species in KNOWN do
		local src = custom:FindFirstChild("Pet" .. species)
		if src and not folder:FindFirstChild(species) then
			local ok, copy = pcall(function() return src:Clone() end)
			if ok and copy then
				for _, d in copy:GetDescendants() do
					if SCRIPT_CLASSES[d.ClassName] then d:Destroy() end
				end
				copy.Name = species
				copy.Parent = folder
				made += 1
			end
		end
	end
	return made
end

------------------------------------------------------------------ lifecycle
function PetService.Init(registry)
	S = registry
end

local function connect(serviceName, signalName, fn)
	local svc = S[serviceName]
	local sig = svc and svc[signalName]
	if type(sig) == "table" and type(sig.Connect) == "function" then
		sig:Connect(function(...)
			local ok, err = pcall(fn, ...)
			if not ok then Util.Warn(TAG, signalName .. ": " .. tostring(err)) end
		end)
	else
		Util.Warn(TAG, "missing signal " .. serviceName .. "." .. signalName)
	end
end

function PetService.Start()
	local ok, err = pcall(PetService.PublishModels)
	if not ok then Util.Warn(TAG, "PublishModels: " .. tostring(err)) end
	connect("PlayerService", "PlayerReady", onPlayerReady)
	connect("ClassService", "ClassChanged", function(player) onBecame(player) end)
	connect("FactionService", "FactionChanged", function(player) onBecame(player) end)
	print("[PetService] started")
end

return PetService
