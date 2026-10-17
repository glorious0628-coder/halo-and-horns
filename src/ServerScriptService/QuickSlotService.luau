-- QuickSlotService.luau : A23-109 quick slots 1·2·3 (server, 게임성 개발 2, 2026-10-10). Contract with 게임성 개발 1
-- (QuickSlots.luau, Config.QuickSlots — read only here):
--   save  data.QuickSlots = "<item1>,<item2>,<item3>" (Config.QuickSlots.Items keys, "" = empty). A brand-new save gets
--         Config.QuickSlots.Default (empty, 검수 10/10: the KO1 quest has the player fill a slot) from DataService; a stored
--         save without the field is from before the quick slots and starts with HP, MP, empty (T.OldSave: the old potion
--         circles on keys 1 / 2); a broken value (not text, too long) = the Default. Cleaned and saved at PlayerReady.
--   show  the owner's attribute Config.QuickSlots.Attr = the same text ("HP,MP,"), set when the player is ready and after
--         every accepted change. Always Count entries, known keys, one item in one slot.
--   c->s  Config.QuickSlots.Remote "SetQuickSlot"(slot 1..Count integer, item key | ""): the item already in another slot
--         swaps with what this slot held. Bad / extra args, not ready, faster than Config.RateLimits.SetQuickSlot: nothing.
--   use   unchanged: a slot press is the UsePotion remote (VitalsService, its own checks); nothing to do here.
-- Changed(player, slots { item, item, item }) fires after every accepted change; Get(player) = the slots now. An item
-- put into a slot (also by a swap) calls S.StoryQuestService.Event(player, "QuickSlotSet", { Slot, Kind }) when that
-- function exists (the KO1 'put a potion in a quick slot' row, 게임성 개발 3).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Util = require(ReplicatedStorage.Shared.Util)

local TAG = "QuickSlotService"
local Q = Config.QuickSlots
local T = {
	MaxLen = 120, -- a longer stored text is broken (the Default)
	OldSave = "HP,MP,", -- a stored save from before A23-109 (no field): the old HP / MP circles on keys 1 / 2
	Rate = (Config.RateLimits and Config.RateLimits.SetQuickSlot) or 0.2,
}

local QuickSlotService = {}
QuickSlotService.Changed = Util.Signal.new()

local S = nil

local function known(item)
	return type(item) == "string" and Q.Items[item] ~= nil
end

-- a stored text -> { item, item, item }: unknown entries and repeats empty; nil (a save from before the quick slots) =
-- T.OldSave, a broken value = Default
local function parse(value)
	local parts
	if value == nil then
		parts = string.split(T.OldSave, ",")
	elseif type(value) == "string" and #value <= T.MaxLen then
		parts = string.split(value, ",")
	else
		parts = Q.Default
	end
	local out, seen = {}, {}
	for i = 1, Q.Count do
		local item = parts[i]
		if not known(item) or seen[item] then item = "" end
		if item ~= "" then seen[item] = true end
		out[i] = item
	end
	return out
end
QuickSlotService.Parse = parse

-- the player's slots now (a new table)
function QuickSlotService.Get(player)
	local data = S.PlayerService.GetData(player)
	return parse(type(data) == "table" and data.QuickSlots or nil)
end

local function publish(player, slots)
	player:SetAttribute(Q.Attr, table.concat(slots, ","))
end

local function questEvent(player, slot, item)
	local sq = S.StoryQuestService
	if type(sq) ~= "table" or type(sq.Event) ~= "function" then return end
	local ok, err = pcall(sq.Event, player, "QuickSlotSet", { Slot = slot, Kind = item })
	if not ok then Util.Warn(TAG, "quest event: " .. tostring(err)) end
end

local function onSet(player, slot, item, ...)
	if select("#", ...) ~= 0 then return end
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > Q.Count then return end -- NaN fails floor
	if item ~= "" and not known(item) then return end
	if player.Parent ~= Players or not S.PlayerService.IsReady(player) then return end
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return end
	local slots = parse(data.QuickSlots)
	-- game play r8 (게임성 개발 1: the bag's first [1] left the HUD slot empty - the client shows its own pick until the
	-- attribute answers): a refused (too fast) or no-change request publishes the slots again, so the screen always
	-- returns to the truth at once instead of a stale attribute
	if not Util.RateLimit(player, "SetQuickSlot", T.Rate) or slots[slot] == item then
		publish(player, slots)
		return
	end
	local from = item ~= "" and table.find(slots, item) or nil
	if from then slots[from] = slots[slot] end -- the item moves here; what was here goes to its old slot
	slots[slot] = item
	data.QuickSlots = table.concat(slots, ",")
	publish(player, slots)
	QuickSlotService.Changed:Fire(player, table.clone(slots))
	if item ~= "" then questEvent(player, slot, item) end
end

local function onReady(player, data)
	if type(data) ~= "table" then return end
	local slots = parse(data.QuickSlots)
	data.QuickSlots = table.concat(slots, ",") -- clean (an old save gets its HP / MP once)
	publish(player, slots)
end

function QuickSlotService.Init(registry)
	S = registry
	for _, item in Q.Default do
		if item ~= "" and not known(item) then Util.Warn(TAG, "Default has an unknown item " .. tostring(item)) end
	end
end

function QuickSlotService.Start()
	Net.Get(Q.Remote).OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onSet, player, ...)
		if not ok then Util.Warn(TAG, "SetQuickSlot: " .. tostring(err)) end
	end)
	S.PlayerService.PlayerReady:Connect(function(player, data)
		local ok, err = pcall(onReady, player, data)
		if not ok then Util.Warn(TAG, "ready: " .. tostring(err)) end
	end)
	print("[QuickSlotService] started")
end

return QuickSlotService
