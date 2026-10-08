-- MonetizationService.luau : Robux change tickets ("변경권"). The ONLY server user of MarketplaceService:
-- owns ProcessReceipt (idempotent; grants only after a successful save) and the ticket counters.
-- data.Tickets and data.ProcessedReceipts are mutated directly here (documented exception).
local MarketplaceService = game:GetService("MarketplaceService")
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

------------------------------------------------------------------ public API
function MonetizationService.Init(registry)
	S = registry
	S.PlayerService.PlayerReady:Connect(function(player)
		publish(player)
	end)
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt -- assigned ONCE, only here

	if RunService:IsStudio() then
		local missing = false
		for _, p in Config.Products do
			if p.Id == 0 then missing = true end
		end
		if missing then
			print("[MonetizationService] Developer Product ids are 0: buy buttons show 'This item isn't ready yet'. Create 2 Developer Products on create.roblox.com (your game > Monetization > Developer Products) and paste their ids into Config.Products.")
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
