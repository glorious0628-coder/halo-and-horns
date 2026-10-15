-- QuestCreditService.luau : SPEC A23-201 / A23-204 who a kill's QUESTS credit (게임성 개발 2 / api party2, 2026-10-15;
-- docs/design/party_guild_2026-10-15.md §1). Pays nothing itself: MonsterService puts the answer on each MonsterKilled info
-- (info.Credit = { Personal, Shared }, info.PartyBoss) and fires MonsterService.QuestKill for credited players the kill does
-- not pay. Quest code (StoryQuestService.EventAmount, QuestService, BoardService) reads info.Credit; a kill without it
-- (personal / quiet / practice monsters, old callers) counts as before.
--   * Hit(rec, player): every accepted hit (MonsterService.DamageMonster) -> rec._credit[player] = { Last, Counted,
--     CountedAt, Party, Snap }; a hit counts toward Counted only Config.Party.BossHitGap s after the last counted one.
--     Party / Snap = the hitter's party at that hit and its members' membership stamps (PartyService.JoinSeq).
--   * A REAL hitter at the kill: last hit within CreditWindow s, standing in the monster's zone within CreditRange studs of
--     the kill; a boss (Def.Boss) also needs Counted >= BossMinHits.
--   * Shared (joint quests, obj.Credit = "Shared"): every real hitter.
--   * Personal (every other quest): the kill's first hitter (MonsterService's info.First, A23-181) and, for EVERY party
--     with a real hitter (docs §1-2 case 2: not only the first hitter's party), the members who are real hitters or stand
--     near (zone + CreditRange, alive, own action within ActiveWindow) and were in that party with the same membership at
--     its member's real hit and still at the kill (an invite after the hit, or leave + join again, credits nothing).
--     Outside a party: the first hitter only. A boss: every real hitter (both flags).
--   * PartyBoss (A23-204): a real hitter of a boss who is in a party -> WarService gives that player's own side the crown
--     units (hunt honor and normal monsters stay first-hitter, A23-181).
--   * Once per spawn: Judge answers once per record (rec._creditDone) and empties the ledger.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local QuestCreditService = {}

local TAG = "QuestCreditService"
local S = nil
local P = Config.Party or {}

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function partyOf(p)
	local ps = S and S.PartyService
	if not ps or type(ps.PartyOf) ~= "function" then return nil end
	local ok, party = pcall(ps.PartyOf, p)
	return ok and type(party) == "table" and party or nil
end

-- the membership stamp of p (nil when PartyService has none: then the party table alone decides)
local function joinOf(p)
	local ps = S and S.PartyService
	if not ps or type(ps.JoinSeq) ~= "function" then return nil end
	local ok, j = pcall(ps.JoinSeq, p)
	return ok and j or nil
end

local function zoneOf(p)
	local zs = S and S.ZoneService
	if zs and type(zs.GetZoneId) == "function" then
		local ok, z = pcall(zs.GetZoneId, p)
		if ok and z ~= nil then return z end
	end
	return p:GetAttribute("ZoneId")
end

-- in the monster's zone (a personal monster: anywhere) and within CreditRange studs of the kill
local function nearKill(rec, p, pos)
	if p.Parent == nil then return false end
	if rec.Owner == nil and rec.ZoneId ~= nil and zoneOf(p) ~= rec.ZoneId then return false end
	if typeof(pos) ~= "Vector3" then return true end -- no kill spot known: the zone decides
	local root = Util.GetRoot(p)
	if not root then return false end
	local ok, d = pcall(function() return (root.Position - pos).Magnitude end)
	return ok and type(d) == "number" and d <= num(P.CreditRange, 80)
end

local function activeAlive(p)
	local hum = Util.GetHumanoid(p)
	if not hum or num(hum.Health) <= 0 then return false end
	local ps = S and S.PlayerService
	if not ps or type(ps.GetLastOwnActive) ~= "function" then return true end
	local ok, at = pcall(ps.GetLastOwnActive, p)
	return ok and type(at) == "number" and os.clock() - at <= num(P.ActiveWindow, 30)
end

-- one accepted hit of `player` on `rec`
function QuestCreditService.Hit(rec, player)
	if type(rec) ~= "table" or not (typeof(player) == "Instance" and player:IsA("Player")) then return end
	if type(rec._credit) ~= "table" then rec._credit = {} end
	local now = os.clock()
	local e = rec._credit[player]
	if not e then
		e = { Last = now, Counted = 0, CountedAt = -math.huge }
		rec._credit[player] = e
	end
	e.Last = now
	if now - e.CountedAt >= num(P.BossHitGap, 3) then
		e.Counted += 1
		e.CountedAt = now
	end
	-- docs §1-2 epoch: who was in my party (and since when) at this hit
	local party = partyOf(player)
	if party and type(party.Members) == "table" then
		local snap = {}
		for _, m in party.Members do snap[m] = joinOf(m) or true end
		e.Party, e.Snap = party, snap
	else
		e.Party, e.Snap = nil, nil
	end
end

-- the kill's quest credit: (credit map [Player] = { Personal, Shared, PartyBoss }, extras = credited players not in `paid`)
-- or nil when this record was judged already. paid = the players MonsterKilled fires for; firstP = info.First's player.
function QuestCreditService.Judge(rec, pos, paid, firstP)
	if type(rec) ~= "table" or rec._creditDone == true then return nil, {} end
	rec._creditDone = true
	local ledger = type(rec._credit) == "table" and rec._credit or {}
	rec._credit = {}
	local now = os.clock()
	local boss = type(rec.Def) == "table" and rec.Def.Boss == true
	local window = num(P.CreditWindow, 15)
	local minHits = num(P.BossMinHits, 2)
	local function real(p)
		local e = ledger[p]
		if type(e) ~= "table" or now - num(e.Last, -math.huge) > window then return false end
		if boss and num(e.Counted) < minHits then return false end
		return nearKill(rec, p, pos)
	end
	-- still in that party with the stamp it had at the hit
	local function same(p, party, snap)
		return partyOf(p) == party and snap[p] ~= nil and snap[p] == (joinOf(p) or true)
	end
	-- the parties with a real hitter: [party] = { [member] = true }, the members it had at that hit and still has
	local hitParties = {}
	if not boss then
		for p, e in ledger do
			if type(e) == "table" and e.Party ~= nil and type(e.Snap) == "table" and same(p, e.Party, e.Snap) and real(p) then
				local set = hitParties[e.Party] or {}
				hitParties[e.Party] = set
				for m in e.Snap do
					if same(m, e.Party, e.Snap) then set[m] = true end
				end
			end
		end
	end
	local out, extras = {}, {}
	local function judge(p)
		local r = real(p)
		local c = { Shared = r, Personal = false, PartyBoss = false }
		if boss then
			c.Personal = r
			c.PartyBoss = r and partyOf(p) ~= nil
		elseif p == firstP then
			c.Personal = true -- A23-181: the first hitter's kill (as today)
		else
			local mine = partyOf(p)
			local set = mine and hitParties[mine] or nil
			if set and set[p] then c.Personal = r or (nearKill(rec, p, pos) and activeAlive(p)) end
		end
		return c
	end
	for _, p in paid do
		if typeof(p) == "Instance" and out[p] == nil then out[p] = judge(p) end
	end
	-- real hitters the kill does not pay (under its damage bar), and the members of every party that hit it
	local others = {}
	for p in ledger do table.insert(others, p) end
	for _, set in hitParties do
		for m in set do table.insert(others, m) end
	end
	for _, p in others do
		if out[p] == nil and typeof(p) == "Instance" and p.Parent ~= nil then
			local c = judge(p)
			if c.Personal or c.Shared then
				out[p] = c
				table.insert(extras, p)
			end
		end
	end
	return out, extras
end

function QuestCreditService.Init(registry)
	S = registry
end

function QuestCreditService.Start()
	print("[" .. TAG .. "] started")
end

return QuestCreditService
