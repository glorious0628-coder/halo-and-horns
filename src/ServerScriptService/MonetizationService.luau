-- MonetizationService.luau : Robux change tickets ("변경권") and A23-75 game passes. The ONLY server user of
-- MarketplaceService: owns ProcessReceipt (idempotent; grants only after a successful save), the ticket counters,
-- game pass ownership (2x XP / 2x Gold / VIP / faction looks), SetLook and the VIP supporter board.
-- data.Tickets and data.ProcessedReceipts are mutated directly here (documented exception).
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local TAG = "MonetizationService"

local MonetizationService = {}

local S = nil

local GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted
local NOT_YET = Enum.ProductPurchaseDecision.NotProcessedYet

local ATTRIBUTE = { Class = "ClassTickets", Faction = "FactionTickets" }
local GOT_TEXT = { Class = "ClassTicketGot", Faction = "FactionTicketGot" }
local WAIT_STEP = 0.5

local inFlight = {} -- [PurchaseId string] = true while a receipt is being granted (concurrent retries wait)
-- [Player] = number of that player's receipts being granted. Ticket use is refused meanwhile: a ticket spent before
-- the forced save finished could not be taken back by the rollback, and Roblox would deliver the receipt again.
local inFlightByPlayer = {}

------------------------------------------------------------------ helpers
local function ticketTable(player)
	local data = S.PlayerService.GetData(player)
	if not data then return nil end
	if type(data.Tickets) ~= "table" then
		data.Tickets = { Class = 0, Faction = 0 }
	end
	return data.Tickets
end

local function kindOfProduct(productId)
	for _, p in Config.Products do
		if p.Id ~= 0 and p.Id == productId then
			return p.Kind
		end
	end
	return nil
end

local function notify(player, textKey)
	if player.Parent == nil then return end
	pcall(Net.Notify, player, string.format(Config.Text[textKey]), "reward", nil, "None") -- sound_gaps C1: never QuestDone
end

-- grant step for a NEW PurchaseId (caller holds inFlight[purchaseId]); returns the decision
local function grant(player, data, kind, purchaseId)
	local receipts = data.ProcessedReceipts
	table.insert(receipts, purchaseId)
	while #receipts > Config.Tickets.MaxReceiptsKept do
		table.remove(receipts, 1)
	end
	MonetizationService.AddTickets(player, kind, 1)

	-- force a save; the purchase is only "granted" once it is persisted
	local okSave, saved = pcall(S.DataService.Save, player, false)
	if okSave and saved then
		notify(player, GOT_TEXT[kind])
		return GRANTED
	end

	-- roll back the in-memory grant (only if this session table is still the live one); Roblox retries later
	if S.PlayerService.GetData(player) == data then
		if MonetizationService.GetTickets(player, kind) >= 1 then
			local idx = table.find(receipts, purchaseId)
			if idx then table.remove(receipts, idx) end
			MonetizationService.AddTickets(player, kind, -1)
		end
		-- else: the granted ticket is already spent (UseTicket is blocked while in flight, so this is a safety net).
		-- Keep the PurchaseId next to that spent ticket: whichever later save persists the spend also persists the id,
		-- so the redelivered receipt returns PurchaseGranted instead of granting a second ticket.
	end
	Util.Warn(TAG, ("save failed for purchase %s of %s; it will be retried"):format(purchaseId, player.Name))
	return NOT_YET
end

local function handleReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then return NOT_YET end

	-- wait for the buyer's data
	local waited = 0
	while not S.PlayerService.IsReady(player) and waited < Config.Tickets.ReceiptWaitSeconds do
		if player.Parent == nil then return NOT_YET end
		task.wait(WAIT_STEP)
		waited += WAIT_STEP
	end
	if player.Parent == nil or not S.PlayerService.IsReady(player) then return NOT_YET end

	local kind = kindOfProduct(info.ProductId)
	if not kind or not ATTRIBUTE[kind] then
		Util.Warn(TAG, ("unknown product id %s (purchase %s)"):format(tostring(info.ProductId), tostring(info.PurchaseId)))
		return NOT_YET
	end

	local data = S.PlayerService.GetData(player)
	if not data then return NOT_YET end
	if type(data.ProcessedReceipts) ~= "table" then
		data.ProcessedReceipts = {}
	end

	local purchaseId = tostring(info.PurchaseId)
	if inFlight[purchaseId] then return NOT_YET end -- the same receipt is being processed right now
	if table.find(data.ProcessedReceipts, purchaseId) then return GRANTED end -- already granted and saved

	inFlight[purchaseId] = true
	inFlightByPlayer[player] = (inFlightByPlayer[player] or 0) + 1
	local ok, decision = pcall(grant, player, data, kind, purchaseId)
	inFlight[purchaseId] = nil
	local left = (inFlightByPlayer[player] or 1) - 1
	if left > 0 then
		inFlightByPlayer[player] = left
	else
		inFlightByPlayer[player] = nil
	end
	if not ok then
		Util.Warn(TAG, "grant error: " .. tostring(decision))
		return NOT_YET
	end
	return decision
end

local function processReceipt(info)
	local ok, decision = pcall(handleReceipt, info)
	if not ok then
		Util.Warn(TAG, "ProcessReceipt error: " .. tostring(decision))
		return NOT_YET
	end
	return decision
end

local function publish(player)
	for kind, attr in ATTRIBUTE do
		player:SetAttribute(attr, MonetizationService.GetTickets(player, kind))
	end
end

------------------------------------------------------------------ A23-75 game passes, looks, supporter board
-- docs/design/gamepass_server_2026-10-08.md. PASS.Owned[player][key] = true while the player owns that pass (key =
-- a Config.GamePasses kind or a sold Config.Looks id): the server's truth for HasPass (the attributes are only for the
-- screen). Ownership comes from Roblox when the player joins (UserOwnsGamePassAsync, Config.PassBoost.CheckTries with
-- a doubling wait; when every try fails, the last saved answer data.PassSeen counts) and at once from
-- PromptGamePassPurchaseFinished (purchased = true). A pass with Id 0 is never asked about (it is not sold yet).
-- PASS.Debug[player][key] = true / false: a Studio DebugCommand "Pass" override (never saved, never on the board).
local PASS = { Owned = {}, Debug = {}, Board = {}, Store = nil }

-- the passes this server sells: { { Key = kind or look id, Id = game pass id } }
function PASS.Sold()
	local list = {}
	for kind, p in Config.GamePasses do
		local id = tonumber(p.Id)
		if id and id > 0 then table.insert(list, { Key = kind, Id = id }) end
	end
	for lookId, look in Config.Looks do
		local id = tonumber(look.PassId)
		if id and id > 0 then table.insert(list, { Key = lookId, Id = id }) end
	end
	return list
end

-- one answer from Roblox: true / false, or nil when every try failed
function PASS.Ask(userId, passId)
	local wait = Config.PassBoost.CheckWait
	for i = 1, Config.PassBoost.CheckTries do
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, userId, passId)
		if ok and type(owns) == "boolean" then return owns end
		if i < Config.PassBoost.CheckTries then
			task.wait(wait)
			wait *= 2
		end
	end
	return nil
end

local function seenTable(data)
	if type(data.PassSeen) ~= "table" then data.PassSeen = {} end
	return data.PassSeen
end

local function looksTable(data)
	if type(data.Looks) ~= "table" then data.Looks = { Owned = {}, On = "" } end
	if type(data.Looks.Owned) ~= "table" then data.Looks.Owned = {} end
	if type(data.Looks.On) ~= "string" then data.Looks.On = "" end
	return data.Looks
end

-- true while the player owns the pass `key` (a Config.GamePasses kind or a sold look id); a Studio override first
function MonetizationService.HasPass(player, key)
	local d = PASS.Debug[player]
	if d and d[key] ~= nil then return d[key] == true end
	local o = PASS.Owned[player]
	return o ~= nil and o[key] == true
end

-- true when the player may wear the look: its pass is owned, or it was unlocked (attendance, data.Looks.Owned)
function MonetizationService.OwnsLook(player, id)
	if type(id) ~= "string" or not Config.Looks[id] then return false end
	if MonetizationService.HasPass(player, id) then return true end
	local data = S.PlayerService.GetData(player)
	return data ~= nil and looksTable(data).Owned[id] ~= nil
end

-- the owned look ids in shop order
function MonetizationService.LooksOwned(player)
	local list = {}
	for _, id in Config.LookOrder() do
		if MonetizationService.OwnsLook(player, id) then table.insert(list, id) end
	end
	return list
end

-- the worn look: the saved one while it is owned and of the player's faction (a faction switch hides it; switching back
-- shows it again), else ""
function PASS.Worn(player)
	local data = S.PlayerService.GetData(player)
	if not data then return "" end
	local id = looksTable(data).On
	local look = Config.Looks[id]
	if not look or look.Faction ~= player:GetAttribute("Faction") or not MonetizationService.OwnsLook(player, id) then
		return ""
	end
	return id
end

-- the screen's copy: PassXP2 / PassGold2 / PassVIP (Config.GamePasses Attr), LooksOwned, LookOn
function PASS.Publish(player)
	if player.Parent == nil then return end
	for kind, p in Config.GamePasses do
		player:SetAttribute(p.Attr, MonetizationService.HasPass(player, kind))
	end
	player:SetAttribute("LooksOwned", table.concat(MonetizationService.LooksOwned(player), ","))
	player:SetAttribute("LookOn", PASS.Worn(player))
end

-- the join check (its own thread: Roblox can take a few seconds)
function PASS.Check(player)
	local data = S.PlayerService.GetData(player)
	if not data or player.Parent == nil then return end
	local owned = PASS.Owned[player] or {}
	PASS.Owned[player] = owned
	PASS.Publish(player) -- false / the saved looks first: nothing waits for Roblox
	for _, p in PASS.Sold() do
		local answer = PASS.Ask(player.UserId, p.Id)
		if player.Parent == nil or S.PlayerService.GetData(player) ~= data then return end
		if answer == nil then
			answer = seenTable(data)[p.Key] == true -- Roblox did not answer: the last answer it gave
		else
			seenTable(data)[p.Key] = answer
		end
		if owned[p.Key] ~= true then owned[p.Key] = answer end -- a purchase meanwhile is never taken back
	end
	PASS.Publish(player)
	if MonetizationService.HasPass(player, "VIP") and PASS.Owned[player].VIP == true then PASS.AddSupporter(player) end
end

-- PromptGamePassPurchaseFinished (server side: a client cannot fake it)
function PASS.Purchased(player, passId, purchased)
	if purchased ~= true or typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent == nil then return end
	for _, p in PASS.Sold() do
		if p.Id == passId then
			local owned = PASS.Owned[player] or {}
			PASS.Owned[player] = owned
			owned[p.Key] = true
			local data = S.PlayerService.GetData(player)
			if data then seenTable(data)[p.Key] = true end
			PASS.Publish(player)
			if p.Key == "VIP" then PASS.AddSupporter(player) end
			print(("[MonetizationService] %s bought game pass %s"):format(player.Name, p.Key))
		end
	end
end

-- c->s SetLook(id): one string <= 32, an owned look of the player's faction, or "" (wear none); anything else ignored
function PASS.OnSetLook(player, ...)
	if select("#", ...) ~= 1 then return end
	local id = ...
	if type(id) ~= "string" or #id > 32 then return end
	if not S.PlayerService.IsReady(player) or not Util.RateLimit(player, "SetLook", Config.RateLimits.SetLook) then return end
	local data = S.PlayerService.GetData(player)
	if not data then return end
	if id ~= "" then
		local look = Config.Looks[id]
		if not look or look.Faction ~= player:GetAttribute("Faction") or not MonetizationService.OwnsLook(player, id) then
			return
		end
	end
	looksTable(data).On = id
	player:SetAttribute("LookOn", PASS.Worn(player))
end

-- A23-77 (AttendanceService): unlock an attendance look (Config.Looks with Unlock, never a sold one). True when new.
function MonetizationService.GrantLook(player, id)
	local look = type(id) == "string" and Config.Looks[id] or nil
	if not look or type(look.Unlock) ~= "table" then return false end
	local data = S.PlayerService.GetData(player)
	if not data then return false end
	local owned = looksTable(data).Owned
	if owned[id] ~= nil then return false end
	owned[id] = os.time()
	PASS.Publish(player)
	return true
end

------------------------------------------------------------------ supporter board (VIP owners of every server)
-- a clean board list: { { U = UserId, N = name, T = os.time() } }, one entry per UserId (the newest), newest first,
-- at most MaxSupporters; anything broken is dropped
function PASS.Clean(raw)
	local list, seen = {}, {}
	if type(raw) == "table" then
		for _, e in raw do
			if type(e) == "table" and type(e.U) == "number" and type(e.N) == "string" and e.N ~= "" and #e.N <= 40
				and type(e.T) == "number" and not seen[e.U] then
				seen[e.U] = true
				table.insert(list, { U = e.U, N = e.N, T = e.T })
			end
		end
	end
	table.sort(list, function(a, b)
		if a.T ~= b.T then return a.T > b.T end
		return a.U < b.U
	end)
	while #list > Config.PassBoost.MaxSupporters do table.remove(list) end
	return list
end

-- `list` with `entry` put first (its older line removed)
function PASS.Insert(list, entry)
	local out = { entry }
	for _, e in list do
		if e.U ~= entry.U then table.insert(out, e) end
	end
	return PASS.Clean(out)
end

function PASS.Show(list)
	PASS.Board = list
	local names = {}
	for _, e in list do table.insert(names, e.N) end
	local ok, err = pcall(function() Net.GameState():SetAttribute("SupporterNames", table.concat(names, "\n")) end)
	if not ok then Util.Warn(TAG, "supporter board: " .. tostring(err)) end
end

function PASS.GetStore()
	if PASS.Store == nil then
		local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, Config.PassBoost.SupporterStore)
		PASS.Store = ok and store or false
	end
	return PASS.Store or nil
end

-- a VIP owner joined or bought VIP: on this server's board at once, then in the shared list (a player who hides
-- their name in announcements, P5, stays off the board)
function PASS.AddSupporter(player, localOnly)
	if player.Parent == nil or player:GetAttribute("HideAnnounceName") == true then return end
	local entry = { U = player.UserId, N = Util.PlayerDisplayName(player), T = os.time() }
	PASS.Show(PASS.Insert(PASS.Board, entry))
	if localOnly then return end
	local store = PASS.GetStore()
	if not store then return end
	task.spawn(function()
		local ok, result = pcall(store.UpdateAsync, store, Config.PassBoost.SupporterKey, function(old)
			return PASS.Insert(PASS.Clean(old), entry)
		end)
		if ok and type(result) == "table" then
			PASS.Show(PASS.Clean(result))
		elseif not ok then
			Util.Warn(TAG, "supporter board save: " .. tostring(result))
		end
	end)
end

-- every RefreshSeconds: the shared list (other servers' VIPs)
function PASS.Refresh()
	local store = PASS.GetStore()
	if not store then return end
	local ok, raw = pcall(store.GetAsync, store, Config.PassBoost.SupporterKey)
	if ok then PASS.Show(PASS.Clean(raw)) end
end

-- Studio test aid (Main DebugCommand "Pass", value "XP2:on" / "VIP:off" / "HaloIce:clear"): overrides the pass for
-- this session only (never saved, never on the shared board)
function MonetizationService.DebugSetPass(player, key, mode)
	if not (Config.GamePasses[key] or (Config.Looks[key] and Config.Looks[key].PassId ~= nil)) then
		return "unknown pass: " .. tostring(key)
	end
	local d = PASS.Debug[player] or {}
	PASS.Debug[player] = d
	if mode == "on" then d[key] = true elseif mode == "off" then d[key] = false else d[key] = nil end
	PASS.Publish(player)
	if key == "VIP" and MonetizationService.HasPass(player, "VIP") then PASS.AddSupporter(player, true) end
	return ("%s %s (HasPass = %s)"):format(key, tostring(mode), tostring(MonetizationService.HasPass(player, key)))
end

------------------------------------------------------------------ public API
function MonetizationService.Init(registry)
	S = registry
	S.PlayerService.PlayerReady:Connect(function(player)
		publish(player)
		task.spawn(function() -- A23-75: game pass ownership (Roblox can take a few seconds)
			local ok, err = pcall(PASS.Check, player)
			if not ok then Util.Warn(TAG, "pass check: " .. tostring(err)) end
		end)
	end)
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt -- assigned ONCE, only here
	-- A23-75 game passes
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local ok, err = pcall(PASS.Purchased, player, passId, purchased)
		if not ok then Util.Warn(TAG, "pass purchase: " .. tostring(err)) end
	end)
	Net.Get("SetLook").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(PASS.OnSetLook, player, ...)
		if not ok then Util.Warn(TAG, "SetLook: " .. tostring(err)) end
	end)
	if S.FactionService and S.FactionService.FactionChanged then -- a look of the other side comes off (and back)
		S.FactionService.FactionChanged:Connect(function(player)
			pcall(PASS.Publish, player)
		end)
	end
	S.PlayerService.PlayerLeaving:Connect(function(player)
		PASS.Owned[player], PASS.Debug[player] = nil, nil
	end)
	task.spawn(function() -- the shared supporter board, now and every RefreshSeconds
		while true do
			local ok, err = pcall(PASS.Refresh)
			if not ok then Util.Warn(TAG, "supporter board: " .. tostring(err)) end
			task.wait(Config.PassBoost.RefreshSeconds)
		end
	end)

	if RunService:IsStudio() then
		local missing = false
		for _, p in Config.Products do
			if p.Id == 0 then missing = true end
		end
		if missing then
			print("[MonetizationService] Developer Product ids are 0: buy buttons show 'This item isn't ready yet'. Create 2 Developer Products on create.roblox.com (your game > Monetization > Developer Products) and paste their ids into Config.Products.")
		end
		if #PASS.Sold() == 0 then
			print("[MonetizationService] A23-75 game pass ids are 0: the shop shows 'Coming soon'. Create the passes on create.roblox.com (your game > Monetization > Passes) and paste their ids into Config.GamePasses / Config.Looks PassId.")
		end
	end

	print("[MonetizationService] started")
end

function MonetizationService.GetTickets(player, kind)
	if not ATTRIBUTE[kind] then return 0 end
	local t = ticketTable(player)
	if not t then return 0 end
	local n = tonumber(t[kind]) or 0
	if n ~= n then return 0 end
	return math.max(0, math.floor(n))
end

-- data.Tickets[kind] (>= 0) + attribute; returns the new count
function MonetizationService.AddTickets(player, kind, delta)
	if not ATTRIBUTE[kind] then
		Util.Warn(TAG, "unknown ticket kind: " .. tostring(kind))
		return 0
	end
	local t = ticketTable(player)
	if not t then return 0 end
	delta = tonumber(delta) or 0
	if delta ~= delta or delta == math.huge or delta == -math.huge then delta = 0 end
	local newCount = math.max(0, math.floor(MonetizationService.GetTickets(player, kind) + delta))
	t[kind] = newCount
	player:SetAttribute(ATTRIBUTE[kind], newCount)
	return newCount
end

-- consumes 1 if available. CR-L25: false, "Pending" while a purchase of this player is still being saved (callers
-- show Text.TicketSaving, not NoTicket: the bought ticket is already counted); false, "None" when there is none
function MonetizationService.UseTicket(player, kind)
	if inFlightByPlayer[player] then return false, "Pending" end
	if MonetizationService.GetTickets(player, kind) < 1 then return false, "None" end
	MonetizationService.AddTickets(player, kind, -1)
	return true
end

return MonetizationService
