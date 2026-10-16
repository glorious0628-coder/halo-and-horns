-- BarkService.luau : quality_ideas ③ monster barks (docs/design/lines_pack_2026-10-06.md §2, 검수 2026-10-07). A monster
-- says one short English line (Config.Barks) at a moment: Spot (it picks a new target), Hit (it is hit), Low (its HP
-- first drops below LowAt in this life) and Idle (no target, a player within IdleNear, rolled every IdleEvery s).
-- MonsterService only fires MonsterService.Moment(rec, "Spot" | "Hit"); this service decides, rolls Chance and writes
-- the line on the monster model: attributes Bark (text), then BarkAt (server time). Game dev 1's MonsterLabels watches
-- BarkAt (it changes on every bark, even when the same line comes again), reads Bark and shows it as a bubble for
-- Config.Barks.Show s within MaxDistance studs (no player names, seen with the chat off too).
-- Cadence: one bark per monster per PerMonster s and per zone per PerZone s (all monsters in a zone share it); a bark
-- the cooldown blocks is dropped (no queue), except Low, which tries again at the next hit. Same moment: Low > Spot >
-- Hit > Idle (only one speaks). Lines: the kind's own (else Config.QuestKind(kind)'s); a golden monster prefers
-- Lines.Golden for every moment; the same line never comes twice in a row for a kind and moment. Lines never change
-- any score (GDD §0 tilts come from picks only).
-- A23-212 (user 10/16): two sure lines where a kind has them - Start = its first line of a life (said at its first Spot
-- instead of a Spot line: no roll, no cooldown) and Beaten = its line as it calms down after a defeat (MonsterService fires
-- Moment "Beaten" from killRecord; said on the still-standing body, no roll, no cooldown). Captain Clatter's match.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local BarkService = {}
local S = nil
local TAG = "BarkService"
local K = Config.Barks or {}
-- [rec] = { At = os.clock() of its last bark, Low = true once its Low line was said } (weak: dead records go away)
local saidBy = setmetatable({}, { __mode = "k" })
local zoneAt = {} -- [zone id] = os.clock() of the zone's last bark
local lastLine = {} -- [kind .. ":" .. moment] = index of the last line said (no repeats in a row)

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function on()
	return K.Enabled == true and type(K.Lines) == "table"
end

local function memo(rec)
	local m = saidBy[rec]
	if not m then
		m = { At = -math.huge, Low = false }
		saidBy[rec] = m
	end
	return m
end

-- the lines for this monster and moment: Golden first (a golden monster), then its kind, then its quest kind
local function linesFor(rec, moment)
	local L = K.Lines
	if rec.Golden == true and type(L.Golden) == "table" and type(L.Golden[moment]) == "table" and #L.Golden[moment] > 0 then
		return L.Golden[moment], "Golden"
	end
	local own = L[rec.Kind]
	if type(own) == "table" and type(own[moment]) == "table" and #own[moment] > 0 then return own[moment], rec.Kind end
	local qk = Config.QuestKind(rec.Kind)
	local alt = qk and L[qk]
	if type(alt) == "table" and type(alt[moment]) == "table" and #alt[moment] > 0 then return alt[moment], qk end
	return nil, nil
end

local function pickLine(list, key)
	local n = #list
	local i = Util.Random:NextInteger(1, n)
	if n > 1 and i == lastLine[key] then i = (i % n) + 1 end -- never the same line twice in a row
	lastLine[key] = i
	return list[i]
end

local function lowNow(rec)
	local max = num(rec.MaxHP, num(rec.Def and rec.Def.HP, 0))
	return max > 0 and num(rec.HP) > 0 and num(rec.HP) / max < num(K.LowAt, 0.3)
end

local function write(rec, line)
	local ok, err = pcall(function()
		rec.Model:SetAttribute("Bark", line)
		rec.Model:SetAttribute("BarkAt", workspace:GetServerTimeNow())
	end)
	if not ok then Util.Warn(TAG, "bark: " .. tostring(err)) end
	return ok
end

-- A23-212: a sure line (Start / Beaten) of this kind, said now; false when the kind has none
local function sure(rec, m, moment)
	local list, key = linesFor(rec, moment)
	if not list then return false end
	m.At = os.clock()
	zoneAt[rec.ZoneId or "?"] = m.At
	return write(rec, pickLine(list, key .. ":" .. moment))
end

-- one moment of one monster: the priority's first moment that may speak, after the rolls and both cooldowns
local function say(rec, moment)
	if not on() or type(rec) ~= "table" or typeof(rec.Model) ~= "Instance" then return false end
	local m = memo(rec)
	if moment == "Beaten" then return sure(rec, m, "Beaten") end -- A23-212 (the record is no longer Alive here)
	if not rec.Alive then return false end
	if moment == "Spot" and not m.Start then -- A23-212: the first Spot of a life says the Start line when there is one
		m.Start = true
		if sure(rec, m, "Start") then return true end
	end
	if moment == "Hit" and not m.Low and lowNow(rec) then moment = "Low" end -- Low > Hit (once per life)
	local now = os.clock()
	local zone = rec.ZoneId or "?"
	if now - m.At < num(K.PerMonster, 12) or now - (zoneAt[zone] or -math.huge) < num(K.PerZone, 6) then
		return false -- dropped (a missed Low tries again at the next hit)
	end
	local chance = type(K.Chance) == "table" and num(K.Chance[moment], 0) or 0
	if chance < 1 and Util.Random:NextNumber() >= chance then return false end
	local list, key = linesFor(rec, moment)
	if not list then return false end
	local line = pickLine(list, key .. ":" .. moment)
	m.At, zoneAt[zone] = now, now
	if moment == "Low" then m.Low = true end
	return write(rec, line)
end

-- Idle: a monster with no target and a player within IdleNear rolls Chance.Idle (every IdleEvery s from the loop; one
-- roll a tick however many players stand near it). Only the monsters that player may hit (own personal ones + zone
-- monsters of the player's zone: GetMonstersInRadius forPlayer).
local function idleTick()
	if not on() then return end
	local mons = S.MonsterService
	if type(mons) ~= "table" or type(mons.GetMonstersInRadius) ~= "function" then return end
	local seen = {}
	for _, p in S.PlayerService.GetReadyPlayers() do
		local root = Util.GetRoot(p)
		if root then
			local ok, list = pcall(mons.GetMonstersInRadius, root.Position, num(K.IdleNear, 40), p)
			for _, rec in ok and list or {} do
				if not seen[rec] and rec._target == nil then
					seen[rec] = true
					say(rec, "Idle")
				end
			end
		end
	end
end

function BarkService.Init(registry)
	S = registry
end

function BarkService.Start()
	local mons = S.MonsterService
	local moment = mons and mons.Moment
	if type(moment) == "table" and type(moment.Connect) == "function" then
		moment:Connect(function(rec, kind)
			if kind == "Spot" or kind == "Hit" or kind == "Beaten" then
				local ok, err = pcall(say, rec, kind)
				if not ok then Util.Warn(TAG, "moment: " .. tostring(err)) end
			end
		end)
	else
		Util.Warn(TAG, "missing signal MonsterService.Moment")
	end
	task.spawn(function()
		while true do
			task.wait(math.max(1, num(K.IdleEvery, 10)))
			local ok, err = pcall(idleTick)
			if not ok then Util.Warn(TAG, "idle: " .. tostring(err)) end
		end
	end)
	print("[BarkService] started" .. (on() and "" or " (off)"))
end

return BarkService
