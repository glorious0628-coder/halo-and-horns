-- PetService.luau : pets (A23-39; PET-2 levels / XP / EquipPet / the owner's pet list; PET-4 the lost baby slime).
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

local function notify(player, text, kind, sound)
	if type(text) == "string" and text ~= "" then pcall(Net.Notify, player, text, kind or "info", nil, sound) end
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

-- PET-1: the walk speed follows the equipped pet (PlayerService.RefreshSpeed reads the attributes below)
local function refreshSpeed(player)
	local ps = S and S.PlayerService
	if type(ps) == "table" and type(ps.RefreshSpeed) == "function" then
		local ok, err = pcall(ps.RefreshSpeed, player)
		if not ok then Util.Warn(TAG, "RefreshSpeed: " .. tostring(err)) end
	end
end

-- PET-2: the pet XP a pet of level lv needs for the next level (Config.Pets.XPPerLv x lv; 0 at MaxLv)
function PetService.XPToNext(lv)
	local P = Config.Pets or {}
	lv = math.floor(num(lv, 1))
	if lv >= num(P.MaxLv, LIMIT.MaxLv) then return 0 end
	return math.max(1, math.floor(num(P.XPPerLv, 15))) * math.max(1, lv)
end

-- PET-2: the owner's pet list (remote "PetList", owner only)
local function sendList(player, pets)
	local list = {}
	for uid, p in pets.List do
		table.insert(list, { Uid = uid, Sp = p.Sp, Lv = p.Lv, XP = p.XP, Need = PetService.XPToNext(p.Lv), Name = p.Name,
			Lean = p.Lean })
	end
	table.sort(list, function(a, b) return a.Uid < b.Uid end)
	pcall(function()
		Net.Get("PetList"):FireClient(player, { Equipped = pets.Equipped[1] or "", List = list })
	end)
end

-- the attributes every client reads (EquippedPet / PetLv / PetForm), then the walk speed, then the owner's list
local function publish(player, data)
	local pets = data.Pets
	local uid = type(pets) == "table" and type(pets.Equipped) == "table" and pets.Equipped[1] or nil
	local p = uid and pets.List[uid] or nil
	player:SetAttribute("EquippedPet", p and p.Sp or "")
	player:SetAttribute("PetLv", p and p.Lv or 0)
	player:SetAttribute("PetForm", "")
	refreshSpeed(player)
	if type(pets) == "table" and type(pets.List) == "table" then sendList(player, pets) end
end

local function findSpecies(pets, species)
	for uid, p in pets.List do
		if p.Sp == species then return uid end
	end
	return nil
end

------------------------------------------------------------------ A23-39 pet tamer
-- PET-4: a pet of `species` added once (an owned one is never duplicated; an owned one without a Lean / Name takes
-- these), equipped when nothing is. lean = "Good" | "Evil" | "" (the story pick), name = the label over my pet ("" =
-- none), text = the notice (nil = none). Returns the new uid, or nil when the player already had one.
function PetService.GrantPet(player, species, lean, name, text)
	local data = getData(player)
	if not data or not KNOWN[species] then return nil end
	local pets = PetService.Sanitize(data)
	lean = (lean == "Good" or lean == "Evil") and lean or ""
	name = type(name) == "string" and string.sub(name, 1, LIMIT.NameLen) or ""
	local have = findSpecies(pets, species)
	if have then
		local p = pets.List[have]
		local changed = false
		if p.Lean == "" and lean ~= "" then p.Lean, changed = lean, true end
		if p.Name == "" and name ~= "" then p.Name, changed = name, true end
		if #pets.Equipped == 0 then
			pets.Equipped = { have }
			changed = true
		end
		if changed then publish(player, data) end
		return nil
	end
	local uid
	repeat -- never reuse a uid a kept (e.g. unknown-species) entry holds
		uid = "P" .. tostring(pets.Next)
		pets.Next += 1
	until pets.List[uid] == nil
	pets.List[uid] = { Sp = species, Lv = 1, XP = 0, Name = name, Lean = lean, Bound = true }
	if #pets.Equipped == 0 then pets.Equipped = { uid } end
	publish(player, data)
	if type(text) == "string" then
		notify(player, text, "reward", "None") -- sound_gaps C1: no pet sound yet, never QuestDone
	end
	PetService.PetGranted:Fire(player, uid, species)
	return uid
end

-- the tamer's baby slime (A23-39): GrantPet with the tamer's notice. quiet = no notice.
function PetService.GiveTamerPet(player, quiet)
	return PetService.GrantPet(player, TAMER.Pet, "", "", not quiet and TXT.PetGot or nil)
end

-- PET-2 c->s "EquipPet"(uid): an owned pet of a known species is the one that follows; "" puts it away
local function onEquip(player, ...)
	if select("#", ...) ~= 1 then return end
	local uid = ...
	if type(uid) ~= "string" or #uid > LIMIT.UidLen then return end
	if not S.PlayerService.IsReady(player) or not Util.RateLimit(player, "EquipPet", num(Config.RateLimits.EquipPet, 0.5)) then
		return
	end
	local data = getData(player)
	if not data then return end
	local pets = PetService.Sanitize(data)
	if uid == "" then
		pets.Equipped = {}
	else
		local p = pets.List[uid]
		if not p or not KNOWN[p.Sp] then return end
		pets.Equipped = { uid }
	end
	publish(player, data)
end

-- PET-2: every kill its owner is paid for (MonsterKilled, auto combat too) gives the equipped pet XPPerKill pet XP;
-- a level up refreshes the walk speed (Config.PetSpeedBonus follows the level)
local function onKilled(player, info)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or type(info) ~= "table" then return end
	local data = getData(player)
	if not data or type(data.Pets) ~= "table" then return end
	local pets = data.Pets -- sanitized at join / grant / equip; a kill never rebuilds it
	if type(pets.List) ~= "table" or type(pets.Equipped) ~= "table" then pets = PetService.Sanitize(data) end
	local uid = pets.Equipped[1]
	local p = uid and pets.List[uid] or nil
	if not p then return end
	local need = PetService.XPToNext(p.Lv)
	if need <= 0 then return end -- MaxLv
	p.XP += math.max(0, math.floor(num((Config.Pets or {}).XPPerKill, 1)))
	local leveled = false
	while need > 0 and p.XP >= need do
		p.XP -= need
		p.Lv += 1
		leveled = true
		need = PetService.XPToNext(p.Lv)
	end
	if need <= 0 then p.XP = 0 end
	if leveled then
		publish(player, data)
	else
		sendList(player, pets)
	end
end

-- PET-2 catch-up: a save whose lost-baby-slime quest is done (a pick saved) but has no baby slime gets it, quietly
local function catchUp(player, data)
	local G = Config.PetGrant
	local st = type(data.Story) == "table" and data.Story or nil
	if type(G) ~= "table" or not st or type(st.Done) ~= "table" or st.Done[G.Quest] ~= true then return end
	local pick = type(st.Pick) == "table" and st.Pick[G.Quest] or nil
	local lean = type(G.Picks) == "table" and G.Picks[pick] or nil
	if lean ~= "Good" and lean ~= "Evil" then return end
	PetService.GrantPet(player, G.Species, lean, (G.Names or {})[lean] or "", nil)
end

-- PET-4: the lost baby slime's story pick (Config.PetGrant.Quest) makes it my pet, either side
local function onStoryPicked(player, questId, pick)
	local G = Config.PetGrant
	if type(G) ~= "table" or questId ~= G.Quest then return end
	local lean = type(G.Picks) == "table" and G.Picks[pick] or nil
	if lean ~= "Good" and lean ~= "Evil" then return end
	PetService.GrantPet(player, G.Species, lean, (G.Names or {})[lean] or "", (G.Text or {}).Got)
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
	local okC, errC = pcall(catchUp, player, data) -- PET-2 (also for non-tamers)
	if not okC then Util.Warn(TAG, "catch-up: " .. tostring(errC)) end
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
		notify(player, Config.ClassChangeKeepsLevel(data.Level) and TXT.BecameFree or TXT.Became, "reward", "None")
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
	if S.StoryQuestService then connect("StoryQuestService", "Picked", onStoryPicked) end -- PET-4
	if S.MonsterService then connect("MonsterService", "MonsterKilled", onKilled) end -- PET-2 pet XP
	Net.Get("EquipPet").OnServerEvent:Connect(function(player, ...) -- PET-2
		local ok, err = pcall(onEquip, player, ...)
		if not ok then Util.Warn(TAG, "EquipPet: " .. tostring(err)) end
	end)
	print("[PetService] started")
end

return PetService
