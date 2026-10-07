-- DamageWindow.luau : SKL-2 (A23-49 rule 4, docs/design/skill_kit_beta_2026-10-06.md §1-4): one book of the skill
-- amounts of the last Seconds (3) s per pair, so the class skills together stay under one cap however they are mixed
-- (Q + Z + X at once). Callers work out the cap in HP and ask for the room left, then book what really happened:
--   "Hit"   attacker -> victim (skill damage to a player): 35% of the victim's MaxHealth (Config.BasicSkill.PvPCapPct),
--           an Active kaiju 8% (Config.Kaiju.ReleaseCapPct) - the old per-cast cap of Q becomes this window
--   "Heal"  healer -> ally (Halo skill support): 30% of the ally's MaxHealth (Config.BasicSkill.HaloHealCapPct)
--   "Steal" player -> player (Horns skill life steal): 3% of the player's own MaxHealth (Config.Factions.Horns
--           LifestealCapPct; an Active kaiju without its health multiplier, as CombatService.applyLifesteal)
-- Basic swings keep their own per-swing rules (not booked here). Memory only; a player who leaves is forgotten.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local DamageWindow = {}
local S = nil
-- the window length in s (Config.Skills.WindowSec when game dev 1 adds it, else 3)
DamageWindow.Seconds = tonumber(Config.Skills and Config.Skills.WindowSec) or 3

-- book[from][to][kind] = { { T = os.clock(), N = amount }, ... } (weak keys: Player instances)
local book = setmetatable({}, { __mode = "k" })

local function entries(from, to, kind, create)
	local byTo = book[from]
	if not byTo then
		if not create then return nil end
		byTo = setmetatable({}, { __mode = "k" })
		book[from] = byTo
	end
	local byKind = byTo[to]
	if not byKind then
		if not create then return nil end
		byKind = {}
		byTo[to] = byKind
	end
	local list = byKind[kind]
	if not list then
		if not create then return nil end
		list = {}
		byKind[kind] = list
	end
	return list
end

-- drops the entries Seconds old or older; returns the sum of the rest
local function used(list, now)
	local sum, keep = 0, 1
	for i = 1, #list do
		local e = list[i]
		if now - e.T < DamageWindow.Seconds then
			list[keep] = e
			keep += 1
			sum += e.N
		end
	end
	for i = #list, keep, -1 do list[i] = nil end
	return sum
end

-- how much more of `kind` from -> to the window allows now (capHP = the cap in HP; never below 0)
function DamageWindow.Room(kind, from, to, capHP)
	if type(capHP) ~= "number" or capHP ~= capHP or capHP <= 0 then return 0 end
	local list = entries(from, to, kind, false)
	if not list then return capHP end
	return math.max(0, capHP - used(list, os.clock()))
end

-- books `n` (what was really dealt / healed) for kind from -> to
function DamageWindow.Book(kind, from, to, n)
	if from == nil or to == nil or type(n) ~= "number" or n ~= n or n <= 0 or n == math.huge then return end
	local list = entries(from, to, kind, true)
	local now = os.clock()
	used(list, now)
	table.insert(list, { T = now, N = n })
end

-- everything booked by or for this player goes (they left)
function DamageWindow.Forget(player)
	book[player] = nil
	for _, byTo in book do byTo[player] = nil end
end

function DamageWindow.Init(registry)
	S = registry
end

function DamageWindow.Start()
	local ps = S and S.PlayerService
	local leaving = ps and ps.PlayerLeaving
	if type(leaving) == "table" and type(leaving.Connect) == "function" then
		leaving:Connect(function(player) DamageWindow.Forget(player) end)
	end
end

return DamageWindow
