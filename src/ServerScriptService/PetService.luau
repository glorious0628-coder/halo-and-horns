-- PetService.luau : pets (A23-39; PET-2 levels / XP / EquipPet / the owner's pet list; PET-4 the lost baby slime).
-- Server-authoritative. Save (Config.Data.Defaults.Pets): List[uid] = { Sp, Lv, XP, Name, Lean, Bound, Roll? },
-- Equipped = { uid } (one pet in the beta), Next = the next uid number, Away = the player put the pet away (PET-2b: it
-- stays away after a rejoin until EquipPet brings it back; never the tamer, whose pet is its weapon). Every client
-- sees only the attributes EquippedPet (species id, "" = none), PetLv, PetRoll (a summoned pet's Roll.Spd, 0 = none:
-- the walk speed) and PetForm ("" = the base look); the pet
-- follows its owner on the clients (PET-3, 게임성 개발 1). A pet is never a server object, so it is never a target of
-- anything.
--
-- A23-39 pet tamer (Config.Tamer, Config.IsTamer = the artisan guild's Archer): the moment a player is a tamer (class
-- pick / class change / faction change, or a join as one) they get the baby slime once, equipped, Bound. A save that was
-- the artisan hunter before A23-39 gets one notice + one free class change ticket (TamerNotice, saved first).
local Players = game:GetService("Players")
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
local PETS = Config.Pets
local LIMIT = { NameLen = 20, UidLen = 32, Pets = 64 }
-- PET-2b L4: when each owner last got PetList, and whether an XP-only send waits (Config.Pets.ListEvery); weak keys
-- so a send racing a leave never keeps a player (PlayerRemoving clears them too)
local LIST = { Last = setmetatable({}, { __mode = "k" }), Queued = setmetatable({}, { __mode = "k" }) }
-- ⑥ PetArmor: the part of a pet XP gain below 1 kept for the next gain ([player][uid] = fraction; memory only, a leave
-- drops it), so a kill's 1 pet XP x 1.2 still adds up (5 kills = 6)
local GEARREM = setmetatable({}, { __mode = "k" })

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

-- the species the game knows (Config.Pets.Species); unknown saved species are kept but never equipped
local function known(species)
	return type(species) == "string" and type(PETS.Species[species]) == "table"
end

local function isTamer(player, data)
	return data.ClassChosen == true and Config.IsTamer(data.Class, data.Faction)
end

------------------------------------------------------------------ data
-- save v4 (docs/design/save_v4_tables_2026-10-11.md): a summoned pet's in-game random stats { Spd = whole % in
-- Config.SaveV4.PetRollSpd }; any other shape drops the whole Roll (a value is never made up)
local function sanitizeRoll(r)
	local range = Config.SaveV4 and Config.SaveV4.PetRollSpd
	if type(r) ~= "table" or type(range) ~= "table" then return nil end
	local spd = r.Spd
	if type(spd) ~= "number" or spd ~= math.floor(spd) or spd < range[1] or spd > range[2] then return nil end
	for k in r do
		if k ~= "Spd" then return nil end
	end
	return { Spd = spd }
end

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
					Lv = math.clamp(math.floor(num(p.Lv, 1)), 1, PETS.MaxLv),
					XP = math.max(0, math.floor(num(p.XP, 0))),
					Name = type(p.Name) == "string" and string.sub(p.Name, 1, LIMIT.NameLen) or "",
					Lean = type(p.Lean) == "string" and string.sub(p.Lean, 1, LIMIT.NameLen) or "",
					Bound = p.Bound == true,
					Roll = sanitizeRoll(p.Roll),
				}
			end
		end
	end
	local equipped = {}
	if type(pets.Equipped) == "table" then
		for _, uid in pets.Equipped do
			if #equipped < 1 and type(uid) == "string" and list[uid] and known(list[uid].Sp) then table.insert(equipped, uid) end
		end
	end
	-- PET-2b M1: Away only means something while a pet is owned and none follows
	local away = pets.Away == true and #equipped == 0 and next(list) ~= nil
	data.Pets = { List = list, Equipped = equipped, Next = math.max(1, math.floor(num(pets.Next, 1))), Away = away }
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
	lv = math.floor(num(lv, 1))
	if lv >= PETS.MaxLv then return 0 end
	return math.max(1, math.floor(num(PETS.XPPerLv, 15))) * math.max(1, lv)
end

-- PET-2: the owner's pet list (remote "PetList", owner only). CanPutAway = false for the tamer (PET-2b: the window
-- hides its put-away button; EquipPet "" is ignored for it)
local function sendList(player, data)
	local pets = data.Pets
	LIST.Last[player] = os.clock()
	local list = {}
	for uid, p in pets.List do
		table.insert(list, { Uid = uid, Sp = p.Sp, Lv = p.Lv, XP = p.XP, Need = PetService.XPToNext(p.Lv), Name = p.Name,
			Lean = p.Lean, Roll = p.Roll })
	end
	table.sort(list, function(a, b) return a.Uid < b.Uid end)
	pcall(function()
		Net.Get("PetList"):FireClient(player, { Equipped = pets.Equipped[1] or "", List = list,
			CanPutAway = not isTamer(player, data) })
	end)
end

-- PET-2b L4: an XP-only change sends the list at most once every Config.Pets.ListEvery seconds (the newest numbers)
local function sendListSoon(player, data)
	if LIST.Queued[player] then return end
	local wait = (LIST.Last[player] or -math.huge) + num(PETS.ListEvery, 1) - os.clock()
	if wait <= 0 then
		sendList(player, data)
		return
	end
	LIST.Queued[player] = true
	task.delay(wait, function()
		LIST.Queued[player] = nil
		if player.Parent ~= Players then return end
		local now = getData(player)
		if now and type(now.Pets) == "table" and type(now.Pets.List) == "table" then sendList(player, now) end
	end)
end

-- PET-2b L3: a pet line waits Config.Pets.NoticeAfter seconds, so it comes after the quest's own lines (with a window
-- open the toasts show one line at a time, and the last one stays)
local function notifyLater(player, text)
	task.delay(num(PETS.NoticeAfter, 0.5), function()
		if player.Parent == Players then notify(player, text, "reward", "None") end -- sound_gaps C1: never QuestDone
	end)
end

-- the attributes every client reads (EquippedPet / PetLv / PetForm), then the walk speed, then the owner's list
local function publish(player, data)
	local pets = data.Pets
	local uid = type(pets) == "table" and type(pets.Equipped) == "table" and pets.Equipped[1] or nil
	local p = uid and pets.List[uid] or nil
	player:SetAttribute("EquippedPet", p and p.Sp or "")
	player:SetAttribute("PetLv", p and p.Lv or 0)
	player:SetAttribute("PetRoll", p and p.Roll and p.Roll.Spd or 0)
	player:SetAttribute("PetForm", "")
	player:SetAttribute("PetAcc", Config.PetGearBonus(data.Gear, uid, "PetAcc")) -- ⑥ gear (게임성 개발 3): the following pet's PetAcc (0 = none)
	refreshSpeed(player)
	if type(pets) == "table" and type(pets.List) == "table" then sendList(player, data) end
end

-- the gift / story pet of a species (one each); a summoned pet (Roll, ⑤ tamer) is a pet of its own and never this one
local function findSpecies(pets, species)
	for uid, p in pets.List do
		if p.Sp == species and p.Roll == nil then return uid end
	end
	return nil
end

local function petCount(pets)
	local n = 0
	for _ in pets.List do n += 1 end
	return n
end

-- a new pet row (grant / SummonPet): a fresh uid, out when nothing follows, then publish, the notice (text, nil = none)
-- and PetGranted. nil when LIMIT.Pets pets are owned already: checked BEFORE it goes in (Sanitize keeps an arbitrary 64
-- of a longer list, so a 65th would lose some pet at the next join)
local function addPet(player, data, pets, row, text)
	if petCount(pets) >= LIMIT.Pets then return nil end
	local uid
	repeat -- never reuse a uid a kept (e.g. unknown-species) entry holds
		uid = "P" .. tostring(pets.Next)
		pets.Next += 1
	until pets.List[uid] == nil
	pets.List[uid] = row
	if #pets.Equipped == 0 then pets.Equipped, pets.Away = { uid }, false end
	publish(player, data)
	if type(text) == "string" then notifyLater(player, text) end
	PetService.PetGranted:Fire(player, uid, row.Sp)
	return uid
end

------------------------------------------------------------------ A23-39 pet tamer
-- PET-4: a pet of `species` added once (an owned one - not a summon - is never duplicated; an owned one without a Lean / Name takes
-- these), equipped when nothing is. lean = "Good" | "Evil" | "" (the story pick), name = the label over my pet ("" =
-- none), text = the notice (nil = none). Returns the new uid, or nil when the player already had one.
-- PET-2b M1: an owned pet the player put away stays away (a join, the catch-up, the story pick); bringOut = the tamer
-- (its pet is its weapon) brings it out anyway. A new pet always comes out when nothing follows.
local function grant(player, species, lean, name, text, bringOut)
	local data = getData(player)
	if not data or not known(species) then return nil end
	local pets = PetService.Sanitize(data)
	lean = (lean == "Good" or lean == "Evil") and lean or ""
	name = type(name) == "string" and string.sub(name, 1, LIMIT.NameLen) or ""
	local have = findSpecies(pets, species)
	if have then
		local p = pets.List[have]
		local changed = false
		if p.Lean == "" and lean ~= "" then p.Lean, changed = lean, true end
		if p.Name == "" and name ~= "" then p.Name, changed = name, true end
		if #pets.Equipped == 0 and (bringOut or not pets.Away) then
			pets.Equipped, pets.Away = { have }, false
			changed = true
		end
		if changed then publish(player, data) end
		return nil
	end
	return addPet(player, data, pets, { Sp = species, Lv = 1, XP = 0, Name = name, Lean = lean, Bound = true }, text)
end

function PetService.GrantPet(player, species, lean, name, text)
	return grant(player, species, lean, name, text, false)
end

-- the tamer's baby slime (A23-39): the grant with the tamer's notice, always out (PET-2b). quiet = no notice.
function PetService.GiveTamerPet(player, quiet)
	return grant(player, TAMER.Pet, "", "", not quiet and TXT.PetGot or nil, true)
end

------------------------------------------------------------------ ⑤ tamer summons / treats (게임성 개발 3, 2026-10-12)
-- docs/design/tamer_server_2026-10-12.md §2-§4 (game dev 2 agreed the shapes 10/12). SummonPet: a NEW pet of `species`
-- even when one is owned, Bound, with its in-game random stats roll = { Spd } (Config.SaveV4.PetRollSpd; never made up
-- here). nil = an unknown species, a bad roll, or LIMIT.Pets pets already. CraftService calls it at the end of a summon.
function PetService.SummonPet(player, species, roll)
	local data = getData(player)
	if not data or not known(species) then return nil end
	local r = sanitizeRoll(roll)
	if not r then return nil end
	local pets = PetService.Sanitize(data)
	return addPet(player, data, pets, { Sp = species, Lv = 1, XP = 0, Name = "", Lean = "", Bound = true, Roll = r }, nil)
end

-- room for one more pet (CraftService checks it before a summon takes anything)
function PetService.HasRoom(player)
	local data = getData(player)
	if not data then return false end
	local pets = type(data.Pets) == "table" and type(data.Pets.List) == "table" and data.Pets or PetService.Sanitize(data)
	return petCount(pets) < LIMIT.Pets
end

-- a copy of my pet `uid` { Sp, Lv, XP } (nil = not mine)
function PetService.GetPet(player, uid)
	local data = getData(player)
	local pets = data and data.Pets
	local p = type(uid) == "string" and type(pets) == "table" and type(pets.List) == "table" and pets.List[uid] or nil
	if type(p) ~= "table" then return nil end
	return { Sp = p.Sp, Lv = p.Lv, XP = p.XP }
end

-- ⑥ gear (GearService, 게임성 개발 3): my pets' worn gear changed -> publish again (PetAcc, the walk speed, the list)
function PetService.Refresh(player)
	local data = getData(player)
	if not data then return false end
	if type(data.Pets) ~= "table" or type(data.Pets.List) ~= "table" or type(data.Pets.Equipped) ~= "table" then PetService.Sanitize(data) end
	publish(player, data)
	return true
end

-- a well-formed EquipPet the server turned down (the tamer's put-away, too fast, not ready yet, a pet it does not own):
-- the owner's window gets the true list back (game dev 1's report: it may already show the change), at most once every
-- Config.Pets.ListEvery s (sendListSoon), so a held button never floods it
local function equipRefused(player)
	local data = getData(player)
	if not data then return end
	PetService.Sanitize(data)
	sendListSoon(player, data)
end

-- PET-2 c->s "EquipPet"(uid): an owned pet of a known species is the one that follows; "" puts it away (saved, PET-2b),
-- except for the tamer (검수 2026-10-09: the pet is its weapon; PetList CanPutAway = false). A well-formed one turned
-- down sends the list back (equipRefused); a malformed one is ignored
local function onEquip(player, ...)
	if select("#", ...) ~= 1 then return end
	local uid = ...
	if type(uid) ~= "string" or #uid > LIMIT.UidLen then return end
	if not S.PlayerService.IsReady(player) or not Util.RateLimit(player, "EquipPet", num(Config.RateLimits.EquipPet, 0.5)) then
		return equipRefused(player)
	end
	local data = getData(player)
	if not data then return end
	local pets = PetService.Sanitize(data)
	if uid == "" then
		if isTamer(player, data) then return equipRefused(player) end
		pets.Equipped, pets.Away = {}, true
	else
		local p = pets.List[uid]
		if not p or not known(p.Sp) then return equipRefused(player) end
		pets.Equipped, pets.Away = { uid }, false
	end
	publish(player, data)
end

-- n pet XP into one pet row: levels up while it can (at MaxLv the XP is 0). nil = it is MaxLv already (nothing changes),
-- else whether it levelled up
local function giveXP(p, n)
	local need = PetService.XPToNext(p.Lv)
	if need <= 0 then return nil end -- MaxLv
	p.XP += n
	local leveled = false
	while need > 0 and p.XP >= need do
		p.XP -= need
		p.Lv += 1
		leveled = true
		need = PetService.XPToNext(p.Lv)
	end
	if need <= 0 then p.XP = 0 end
	return leveled
end

-- ⑥ gear (게임성 개발 3): the pet XP of ONE gain x (1 + the PetArmor bonus of THAT pet) + the fraction kept from the last
-- gains of that pet; the whole part goes in, the rest waits (GEARREM). The one place the bonus is applied (a kill and
-- AddPetXP both go through it before giveXP). 0 / no gear = n as it is.
local function gearXP(player, data, uid, n)
	local rems = GEARREM[player]
	local exact = n * (1 + Config.PetGearBonus(data.Gear, uid, "PetArmor")) + (rems and rems[uid] or 0)
	local whole = math.floor(exact + 1e-9) -- (1e-9: 20 x 1.2 is 24, not 23.999..)
	local rest = exact - whole
	if rest > 1e-9 then
		if not rems then
			rems = {}
			GEARREM[player] = rems
		end
		rems[uid] = rest
	elseif rems then
		rems[uid] = nil
	end
	return whole
end

-- PET-2: every kill its owner is paid for (MonsterKilled, auto combat too) gives the equipped pet XPPerKill pet XP;
-- a level up refreshes the walk speed (Config.PetSpeedBonus follows the level). A free rider's share (info.Minor,
-- MonsterService MinorShare) is not a paid kill (PET-2b L1, like LootService.RollKill).
local function onKilled(player, info)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or type(info) ~= "table" then return end
	if info.Minor == true then return end
	local data = getData(player)
	if not data or type(data.Pets) ~= "table" then return end
	local pets = data.Pets -- sanitized at join / grant / equip; a kill never rebuilds it
	if type(pets.List) ~= "table" or type(pets.Equipped) ~= "table" then pets = PetService.Sanitize(data) end
	local uid = pets.Equipped[1]
	local p = uid and pets.List[uid] or nil
	if not p then return end
	local leveled = giveXP(p, gearXP(player, data, uid, math.max(0, math.floor(num((Config.Pets or {}).XPPerKill, 1)))))
	if leveled == nil then return end -- MaxLv
	if leveled then
		publish(player, data)
	else
		sendListSoon(player, data)
	end
end

-- ⑤ a Pet Treat (TamerService.Feed): n (a whole number > 0) pet XP into my pet `uid`, the same levels as kills.
-- Returns its level (unchanged at MaxLv: Feed turns that down before the treat goes), nil = not my pet / a bad n
function PetService.AddPetXP(player, uid, n)
	if type(uid) ~= "string" or type(n) ~= "number" or n ~= math.floor(n) or n <= 0 or n == math.huge then return nil end
	local data = getData(player)
	if not data or type(data.Pets) ~= "table" then return nil end
	local pets = data.Pets
	if type(pets.List) ~= "table" or type(pets.Equipped) ~= "table" then pets = PetService.Sanitize(data) end
	local p = pets.List[uid]
	if type(p) ~= "table" then return nil end
	n = gearXP(player, data, uid, n) -- ⑥ gear (게임성 개발 3): PetArmor of this pet
	local leveled = giveXP(p, n)
	if leveled then
		publish(player, data)
	elseif leveled == false then
		sendListSoon(player, data)
	end
	return p.Lv
end

-- PET-2 catch-up: a save whose lost-baby-slime quest is done (a pick saved) but has no baby slime gets it, quietly
-- (an owned one, put away or not, is left as it is: PET-2b M1)
local function catchUp(player, data)
	local G = Config.PetGrant
	local st = type(data.Story) == "table" and data.Story or nil
	if type(G) ~= "table" or not st or type(st.Done) ~= "table" or st.Done[G.Quest] ~= true then return end
	if findSpecies(data.Pets, G.Species) then return end
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

-- becoming a tamer during a session (class pick / class change / faction change): chosen now, so no notice ticket.
-- Every class / faction change sends the owner's list again (PET-2b: CanPutAway follows the tamer)
local function onBecame(player)
	if not S.PlayerService.IsReady(player) then return end
	local data = getData(player)
	if not data then return end
	if isTamer(player, data) then
		data.TamerNotice = true
		PetService.GiveTamerPet(player)
	end
	if type(data.Pets) == "table" and type(data.Pets.List) == "table" then sendList(player, data) end
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
	for species in PETS.Species do
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
	Players.PlayerRemoving:Connect(function(player) -- PET-2b L4
		LIST.Last[player], LIST.Queued[player] = nil, nil
		GEARREM[player] = nil -- ⑥ PetArmor fractions
	end)
	print("[PetService] started")
end

return PetService
