-- KillCardService.luau : choice cards some kills offer (게임성 개발 2, A23-87, 검수 2026-10-09). Config.KillCards[cardKind]
-- = { Kinds = { [monster kind] = true }, Chance, Cooldown }: a MonsterKilled (one per paid contributor) of one of Kinds
-- offers ChoiceCard kind `cardKind` (Config.ChoiceCard.Kinds) with chance Chance, at most once per Cooldown s per player
-- and card kind (server memory; the cooldown starts only when a card really opened). The card itself - its options,
-- rewards, the daily deeds cap, one open card at a time - is game dev 3's ChoiceCard. First user: FlowerPatch (a
-- Flower Slime kill: "A flower got squished!").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local KillCardService = {}

local TAG = "KillCardService"
local S = nil
local K = Config.KillCards or {}
local LAST = {} -- [Player] = { [cardKind] = os.clock() of the last card it opened }

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function onKilled(player, info)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return end
	if type(info) ~= "table" or type(info.Kind) ~= "string" then return end
	local kinds = Config.ChoiceCard and Config.ChoiceCard.Kinds or {}
	for cardKind, c in K do
		if type(c) == "table" and c.Enabled ~= false and type(c.Kinds) == "table" and c.Kinds[info.Kind] == true
			and kinds[cardKind] then
			local mine = LAST[player] or {}
			local now = os.clock()
			if now - (mine[cardKind] or -math.huge) >= math.max(0, num(c.Cooldown, 600))
				and Util.Random:NextNumber() < math.clamp(num(c.Chance), 0, 1) then
				local ok, opened = pcall(S.ChoiceCard.Offer, player, cardKind)
				if not ok then
					Util.Warn(TAG, "Offer " .. cardKind .. ": " .. tostring(opened))
				elseif opened == true then
					mine[cardKind] = now
					LAST[player] = mine
				end
			end
		end
	end
end

function KillCardService.Init(registry)
	S = registry
end

function KillCardService.Start()
	S.MonsterService.MonsterKilled:Connect(function(player, info)
		local ok, err = pcall(onKilled, player, info)
		if not ok then Util.Warn(TAG, "kill: " .. tostring(err)) end
	end)
	Players.PlayerRemoving:Connect(function(player)
		LAST[player] = nil
	end)
end

return KillCardService
