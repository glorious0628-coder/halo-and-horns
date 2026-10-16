-- PvPService.luau : PvP rules (CanAttack, rookie / spawn protection, A23-113 ① Roblox friends), bully detection, KO
-- outcomes (plunder -> grudge sack, honor, bounty), Wanted stars + bounty, revenge marks and the Most Wanted board.
-- Server only. See TECH_SPEC §4.13 and SPEC_ADDENDUM A6 / A10-V3-3 / A23-113.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local TAG = "PvPService"

-- (the A3-M3 "under attack while auto-attack is ON" hint is sent by CombatService.DamagePlayer only)
local LOOP_INTERVAL = 1
local PRUNE_INTERVAL = 60 -- seconds between prunes of the bait damage log
local LOOP_WARN_INTERVAL = 10
-- ⑤ (quality_ideas §1, 검수): the spawn shield shows no bubble; the protected body wears this outline instead
local PROTECT_GLOW = "ProtectGlow"

-- review-fix tuning knobs (grouped to keep the chunk's local count low)
local GUARD = {
	DmgLogMax = 64, -- CR-M15: hits kept per attacker/victim pair (oldest dropped first)
	RecentHitSeconds = 3, -- CR-L4: a non-PvP death without damage this recent (reset / fall) keeps the stars
	KoLogKeep = math.max(1, Config.Bully.RepeatKOs - 1), -- CR-M4: KO times kept per killer/victim pair ({ t1, t2 })
	-- BB10 D2: a pair with no hit for this long starts a new fight (whose first hit decides self-defense)
	EngageGap = 2 * Config.Ranking.DefenseWindowSeconds,
}

-- Most Wanted board lines (TECH_SPEC §4.13 board text)
local BOARD_ROWS = 3 -- BB11: top 3 of each weekly board + the wanted line (texts: Config.Ranking.Text.Board)

local PvPService = {}

PvPService.PlayerKO = Util.Signal.new() -- (killer, victim, info)

local S = nil

-- per-player state (Player keys; cleaned on PlayerLeaving)
local stars = {} -- [Player] = number
local lastStarChange = {} -- [Player] = os.clock()
local protectedUntil = {} -- [Player] = os.clock() (0 = not protected)
local graceUntil = {} -- [Player] = os.clock() end of the A23-18 graduation grace
local wasRookie = {} -- [Player] = last rookie state seen by tickPlayer (graduation edge)
local spawnedAt = {} -- [Player] = os.clock() of the last CharacterSpawned
-- CR-M15: [attacker][victim] = { { T = os.clock(), A = damage }, ... } within Config.Bully.BaitWindow (bait check)
local dmgLog = {}
-- BB10 D2: ["<lo>:<hi>" UserIds] = { By = the player who struck first, T = os.clock() of that hit, Last = of the latest
-- hit either way, A / B = the two players } (a new fight starts after GUARD.EngageGap without a hit)
local engage = {}
local revenge = {} -- [Player] = { Target = Player, Until = os.clock() }
-- A23-113 ① (user 2026-10-10): Roblox friends never damage each other, whatever their sides and zones. Pairs["<lo>:<hi>"
-- UserIds] = the pair's one IsFriendsWith answer (a failed call = false), asked in the background when the second of
-- the two becomes ready on this server (join order does not matter) and kept until one of them leaves (a rejoin asks
-- again). Asking[key] = the token of the call in flight (a leave drops it, so its late answer is thrown away). A pair
-- without an answer yet is not friends. Burst calls one after another, the next Burst Gap s later (a full server).
-- RankingService keeps its own cache for the boards (there a failed call counts as friends).
local FRIEND = { Pairs = {}, Asking = {}, Burst = 5, Gap = 1 }

-- CR-M4: pair state (minted KO reward, repeat-KO log, claimed bully bounty) lives in the saved PairCD of the player
-- it belongs to, so a server hop or rejoin cannot reset it (pairReady / logKO below; pruned by PlayerService)

-- anti-farm: the minted bully part of a bounty is paid at most once per victim (any killer) per this window,
-- the time a max-stack bully needs to decay back to clean. Stored in the victim's PairCD as "bully:0".
local BULLY_BOUNTY_COOLDOWN = Config.Bully.DecaySeconds * Config.Bully.MaxStacks

local lastLoopWarn = 0

------------------------------------------------------------------ helpers
local function isPlaying(p)
	return p ~= nil and p.Parent ~= nil
end

local function warnLoop(err)
	local now = os.clock()
	if now - lastLoopWarn >= LOOP_WARN_INTERVAL then
		lastLoopWarn = now
		Util.Warn(TAG, "loop error: " .. tostring(err))
	end
end

-- BB37: every server-wide line names players through AnnounceService.PublicName (hidden -> "<faction> 한 명")
local function publicName(p, honorific)
	local A = S.AnnounceService
	if A and A.PublicName then
		local ok, name = pcall(A.PublicName, p, honorific)
		if ok and type(name) == "string" then return name end
	end
	return Util.PlayerDisplayName(p) .. (honorific and Config.Announce.Text.Honorific or "")
end

local function fmt(key, ...)
	return string.format(Config.Text[key], ...)
end

local function notify(p, text, kind, sound)
	if isPlaying(p) then
		Net.Notify(p, text, kind, nil, sound)
	end
end

local function setAttr(p, key, value)
	if p:GetAttribute(key) ~= value then
		p:SetAttribute(key, value)
	end
end

local function faction(p)
	return S.FactionService.GetFaction(p)
end

-- only Halo and Horns ever take part in PvP ("Neutral" and "None" never do; addendum A6)
local function isFighter(f)
	return f == "Halo" or f == "Horns"
end

local function kstate(p)
	local kaiju = S.KaijuService
	if kaiju and kaiju.GetState then
		return kaiju.GetState(p) or "None"
	end
	return "None"
end

-- persisted stat: live data table first, mirrored attribute as fallback
local function num(p, key, default)
	local data = S.PlayerService.GetData(p)
	local v = data and data[key]
	if v == nil then
		v = p:GetAttribute(key)
	end
	return tonumber(v) or default
end

local function bullyStacksOf(p)
	return tonumber(S.JusticeService.GetBullyStacks(p)) or 0
end

local function classOf(p)
	local C = S.ClassService
	return (C and C.GetClass and C.GetClass(p)) or "Warrior"
end

-- CR-M4: pair cooldown kept in the holder's saved PairCD ("<kind>:<otherUserId>" = os.time()). PlayerService.PairReady
-- owns it; the inline copy follows the same contract. commit = false only checks. No data -> false (no reward).
local function pairReady(holder, otherUserId, kind, cooldown, commit)
	if not holder then
		return false
	end
	local PS = S.PlayerService
	if PS.PairReady then
		local ok, res = pcall(PS.PairReady, holder, otherUserId, kind, cooldown, commit)
		return ok and res == true
	end
	local d = PS.GetData(holder)
	if type(d) ~= "table" then
		return false
	end
	if type(d.PairCD) ~= "table" then
		d.PairCD = {}
	end
	local k = kind .. ":" .. tostring(otherUserId)
	local t = os.time()
	if t - (tonumber(d.PairCD[k]) or 0) < cooldown then
		return false
	end
	if commit ~= false then
		d.PairCD[k] = t
	end
	return true
end

-- CR-M4: the killer's recent KO times on this victim live in the killer's PairCD as "kolog:<victimUserId>" =
-- { t1, t2 } (os.time, oldest first). Records this KO; true when it is the RepeatKOs-th within RepeatWindow.
local function logKO(killer, victim)
	local B = Config.Bully
	local d = S.PlayerService.GetData(killer)
	if type(d) ~= "table" then
		return false
	end
	if type(d.PairCD) ~= "table" then
		d.PairCD = {}
	end
	local k = "kolog:" .. tostring(victim.UserId)
	local t = os.time()
	local times = {}
	local old = d.PairCD[k]
	if type(old) == "table" then
		for _, v in old do
			local x = tonumber(v)
			if x and t - x <= B.RepeatWindow then
				table.insert(times, x)
			end
		end
		table.sort(times)
	end
	table.insert(times, t)
	local repeated = #times >= B.RepeatKOs
	while #times > GUARD.KoLogKeep do
		table.remove(times, 1)
	end
	d.PairCD[k] = times
	return repeated
end

-- bully stacks that still carry a bounty: 0 while this bully's bounty was already claimed (BULLY_BOUNTY_COOLDOWN,
-- the victim's PairCD "bully:0"). The stacks themselves (size / damage penalty, "깡패" tag) stay with JusticeService.
-- A23-23 D3: this week's outlaw counts as (at least) one bully stack for the bounty (Config.Bounty: units >= 1 and
-- x BountyMult once, so bully + outlaw is still at most x2), with the same claim cooldown.
local function bountyBullyStacks(p)
	local n = bullyStacksOf(p)
	if p:GetAttribute("Outlaw") == true then n = math.max(n, 1) end
	if n <= 0 or not pairReady(p, 0, "bully", BULLY_BOUNTY_COOLDOWN, false) then
		return 0
	end
	return n
end

-- marks this bully's bounty as claimed (by any killer) for BULLY_BOUNTY_COOLDOWN
local function claimBullyBounty(p)
	pairReady(p, 0, "bully", 0)
end

-- CR-L5: weak-victim check power WITHOUT the rebirth bonus (that bonus is gold / XP only)
local function combatPower(p)
	local J = S.JusticeService
	if J and J.GetCombatPower then
		local ok, v = pcall(J.GetCombatPower, p)
		if ok and type(v) == "number" then
			return v
		end
	end
	-- BB4 / A23-69: the same formula as JusticeService (level, the equipped weapon +N read from the WeaponEnhance
	-- attribute - data.WeaponEnhance is the per-tier table - and the stat points)
	return Config.CombatPowerOf(p)
end

-- A23-18 boldness: x2 vs a much stronger victim, x0.5 vs a much weaker one (honor / infamy / war points only)
function PvPService.BoldMult(killer, victim)
	local P = Config.PvP
	local mine, theirs = combatPower(killer), combatPower(victim)
	if type(mine) ~= "number" or type(theirs) ~= "number" or mine ~= mine or theirs ~= theirs or mine <= 0 then return 1 end
	local ratio = theirs / mine
	if ratio >= P.BoldStrongRatio then return P.BoldStrongMult end
	if ratio < P.BoldWeakRatio then return P.BoldWeakMult end
	return 1
end

-- integer points x mult with fair rounding (x0.5 of 1 point = 50% chance of 1), so weak KOs still average half
function PvPService.ScalePoints(points, mult)
	local v = (tonumber(points) or 0) * (tonumber(mult) or 1)
	local whole = math.floor(v)
	if Util.Random:NextNumber() < v - whole then whole += 1 end
	return whole
end

-- A23-203 (user 10/15, 최종 검수 10/16 - GPT gameplay_r1 bug ①): danger only inside a red PvP zone. A combat tag no longer
-- carries a fight out into the Outskirts / bridges / safe hunting land (was addendum A10-V3-3): outside = no PvP hit
local function inPvP(p)
	return S.ZoneService.IsPvPZone(p) == true
end

local function rootPos(p)
	local root = Util.GetRoot(p)
	return root and root.Position or nil
end

-- CR-M15: remove every hit with T < cutoff from an ascending dmgLog list
local function pruneHits(hits, cutoff)
	while hits[1] ~= nil and hits[1].T < cutoff do
		table.remove(hits, 1)
	end
end

-- CR-M15: total damage `attacker` dealt to `victim` within Config.Bully.BaitWindow
local function recentDamage(attacker, victim, now)
	local byVictim = dmgLog[attacker]
	local hits = byVictim and byVictim[victim]
	if not hits then
		return 0
	end
	local sum = 0
	for _, h in hits do
		if now - h.T <= Config.Bully.BaitWindow then
			sum += h.A
		end
	end
	return sum
end

local function engageKey(a, b)
	return tostring(math.min(a.UserId, b.UserId)) .. ":" .. tostring(math.max(a.UserId, b.UserId))
end

-- BB10 D2 self-defense (never an unfair KO): the current fight between the two began with the victim's hit and the KO
-- landed within Config.Ranking.DefenseWindowSeconds of that first hit
local function victimStruckFirst(victim, killer, now)
	local e = engage[engageKey(victim, killer)]
	return e ~= nil and now - e.Last <= GUARD.EngageGap and e.By == victim
		and now - e.T <= Config.Ranking.DefenseWindowSeconds
end

-- BB10: the ranking verdict of one PvP KO ({ Fair, Unfair?, Exempt?, Reason? }; { Fair = false } without RankingService)
local function judgeKO(killer, victim, facts)
	local R = S.RankingService
	if R and R.JudgeKO then
		local ok, v = pcall(R.JudgeKO, killer, victim, facts)
		if ok and type(v) == "table" then return v end
		if not ok then Util.Warn(TAG, "JudgeKO: " .. tostring(v)) end
	end
	return { Fair = false }
end

-- BB10: Honor / Infamy from PvP go through PlayerService.GrantFame (the stat + the fair weekly board points)
local function grantFame(p, stat, n, verdict, victim)
	S.PlayerService.GrantFame(p, stat, n, { PvP = true, Fair = verdict.Fair == true, Victim = victim })
end

local function computeBounty(p)
	if not isFighter(faction(p)) then
		return 0
	end
	return Config.Bounty(num(p, "Level", 1), stars[p] or 0, bountyBullyStacks(p))
end

local function refreshStarAttrs(p)
	if not isPlaying(p) then
		return
	end
	setAttr(p, "WantedStars", stars[p] or 0)
	setAttr(p, "Bounty", computeBounty(p))
end

-- the newbie PvP shield is meaningless for Neutral (never in PvP at all; addendum A6)
local function rookieAttr(p)
	return faction(p) ~= "Neutral" and PvPService.IsRookie(p)
end

local function addStar(killer)
	stars[killer] = math.min(Config.PvP.MaxStars, (stars[killer] or 0) + 1)
	lastStarChange[killer] = os.clock()
	refreshStarAttrs(killer) -- A23-191 (최종 검수 10/15): no server-wide 'Most Wanted' banner (WantedStars / Bounty say it)
end

-- the shield and its outline always go together
local function destroyForceFields(p)
	local character = p.Character
	if not character then
		return
	end
	for _, child in character:GetChildren() do
		if child:IsA("ForceField") or (child:IsA("Highlight") and child.Name == PROTECT_GLOW) then
			child:Destroy()
		end
	end
end

-- 빛 마을 점검 #42: true while p stands in a town (no PvP there; a spawn-plaza outline protects nothing)
local function inTown(p)
	local zs = S and S.ZoneService
	if type(zs) ~= "table" or type(zs.IsTown) ~= "function" then return false end
	local ok, town = pcall(zs.IsTown, p)
	return ok and town == true
end

-- 빛 마을 점검 #41: true while p stands in a faction town (Config.Zones[..].Town with a Faction: Halo Citadel, Horns Den;
-- the Crossroads town has none)
local function inFactionTown(p)
	local zs = S and S.ZoneService
	if type(zs) ~= "table" or type(zs.GetZone) ~= "function" then return false end
	local ok, zone = pcall(zs.GetZone, p)
	return ok and type(zone) == "table" and zone.Town == true and zone.Faction ~= nil
end


-- ⑤ a soft outline in the faction color (no fill, hidden behind walls) while protected, outside the towns (#42).
-- Protect adds it; the 1 s loop puts it back on a rebuilt body (an appearance swap moves the ForceField, not this) and
-- after the protected player walks out of town, and takes it off back inside
local function addProtectGlow(p)
	local character = p.Character
	local f = Config.Factions[faction(p)]
	if not character or not character.Parent or character:FindFirstChild(PROTECT_GLOW) or not (f and f.Color) or inTown(p) then
		return
	end
	local h = Instance.new("Highlight")
	h.Name = PROTECT_GLOW
	h.FillTransparency = 1
	h.OutlineColor = f.Color
	h.OutlineTransparency = Config.PvP.ProtectGlow.OutlineTransparency
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = character
end

local function removeProtectGlow(p)
	local glow = p.Character and p.Character:FindFirstChild(PROTECT_GLOW)
	if glow and glow:IsA("Highlight") then glow:Destroy() end
end

local function clearRevenge(p)
	revenge[p] = nil
	if isPlaying(p) then
		setAttr(p, "RevengeTargetId", 0)
		setAttr(p, "RevengeUntil", 0)
	end
end

-- clears p's own revenge mark and every other player's mark that targets p
local function clearRevengeInvolving(p)
	local holders = {}
	for holder, r in revenge do
		if holder == p or r.Target == p then
			table.insert(holders, holder)
		end
	end
	for _, holder in holders do
		clearRevenge(holder)
	end
end

------------------------------------------------------------------ friends (A23-113 ①)
-- one pair's IsFriendsWith call (it yields and can throw: pcall; a failed call = not friends). The answer is kept only
-- while this call is still the pair's current one (FRIEND.Drop on a leave in between throws it away)
function FRIEND.Ask(newcomer, other)
	local key = engageKey(newcomer, other)
	if FRIEND.Pairs[key] ~= nil or FRIEND.Asking[key] ~= nil then return end -- once per pair
	local PS = S.PlayerService
	if not isPlaying(newcomer) or not isPlaying(other) or not PS.IsReady(newcomer) or not PS.IsReady(other) then return end
	local token = {}
	FRIEND.Asking[key] = token
	local ok, res = pcall(function() return newcomer:IsFriendsWith(other.UserId) end)
	if FRIEND.Asking[key] ~= token then return end -- one of them left meanwhile
	FRIEND.Asking[key] = nil
	FRIEND.Pairs[key] = ok and res == true
end

-- the newcomer's pairs with every other ready player, in the background: Burst calls in a row (each waits for its own
-- answer), the next Burst Gap s later
function FRIEND.Join(newcomer)
	local others = {}
	for _, o in S.PlayerService.GetReadyPlayers() do
		if o ~= newcomer then table.insert(others, o) end
	end
	for first = 1, #others, FRIEND.Burst do
		local batch = {}
		for i = first, math.min(#others, first + FRIEND.Burst - 1) do table.insert(batch, others[i]) end
		local function run()
			for _, o in batch do
				local ok, err = pcall(FRIEND.Ask, newcomer, o)
				if not ok then Util.Warn(TAG, "friend check failed: " .. tostring(err)) end
			end
		end
		local wave = (first - 1) / FRIEND.Burst
		if wave == 0 then task.spawn(run) else task.delay(wave * FRIEND.Gap, run) end
	end
end

-- a leaver's answers and calls in flight are forgotten, so a rejoin asks again
function FRIEND.Drop(player)
	local id = tostring(player.UserId)
	for _, list in { FRIEND.Pairs, FRIEND.Asking } do
		for key in list do
			local lo, hi = string.match(key, "^([^:]+):([^:]+)$")
			if lo == id or hi == id then list[key] = nil end
		end
	end
end

-- A23-113 ①: true when the two players are Roblox friends (this server's cached answer: never yields, never asks)
function PvPService.AreFriends(a, b)
	if typeof(a) ~= "Instance" or typeof(b) ~= "Instance" or a == b or not a:IsA("Player") or not b:IsA("Player") then
		return false
	end
	return FRIEND.Pairs[engageKey(a, b)] == true
end

------------------------------------------------------------------ public API
function PvPService.GetStars(player)
	return (player and stars[player]) or 0
end

function PvPService.ResetStars(player)
	if not player then
		return
	end
	stars[player] = 0
	lastStarChange[player] = os.clock()
	refreshStarAttrs(player)
end

function PvPService.DebugSetStars(player, n)
	if not isPlaying(player) then
		return
	end
	stars[player] = math.clamp(math.floor(tonumber(n) or 0), 0, Config.PvP.MaxStars)
	lastStarChange[player] = os.clock()
	refreshStarAttrs(player)
end

-- Rebirths == 0 and (Level < RookieLevel or PlaytimeSeconds < RookiePlaytime)
function PvPService.IsRookie(player)
	if not player then
		return false
	end
	if num(player, "Rebirths", 0) ~= 0 then
		return false
	end
	return num(player, "Level", 1) < Config.PvP.RookieLevel
		or num(player, "PlaytimeSeconds", 0) < Config.PvP.RookiePlaytime
end

-- A23-18 graduation grace (review of c08c382): started on the rookie -> graduate edge for Halo / Horns only, saved as
-- an absolute time (data.GraduateGraceUntil) so a rejoin keeps the rest; checked lazily wherever PvP damage is decided
local function startGrace(p, seconds)
	if seconds <= 0 then return end
	graceUntil[p] = os.clock() + seconds
	local data = S.PlayerService.GetData(p)
	if type(data) == "table" then data.GraduateGraceUntil = os.time() + math.ceil(seconds) end
	setAttr(p, "GraduateGraceUntil", Util.Now() + seconds)
end

local function checkGraduation(p)
	if not isPlaying(p) then return end
	local isRookie = PvPService.IsRookie(p)
	local f = faction(p)
	if wasRookie[p] == true and not isRookie and (f == "Halo" or f == "Horns") and not graceUntil[p] then
		startGrace(p, Config.PvP.GraduateGraceSeconds)
		notify(p, fmt("GraduateStart"), "reward", "None") -- sound_gaps C1
	end
	wasRookie[p] = isRookie
end

function PvPService.InGrace(p)
	if not p then return false end
	checkGraduation(p) -- closes the up-to-1 s gap before the next tick
	return (graceUntil[p] or 0) > os.clock()
end

-- rookie shield or graduation grace: no PvP damage either way (CanAttack, kaiju stomp)
function PvPService.IsShielded(p)
	return PvPService.IsRookie(p) or PvPService.InGrace(p)
end

-- 빛 마을 점검 #41 / A23-103: true while p stands in a faction town (the kaiju exception skips them; KaijuService does
-- not count them as kaiju fighters either)
function PvPService.InFactionTown(p)
	return inFactionTown(p)
end

function PvPService.HasRevenge(attacker, victim)
	local r = attacker and revenge[attacker]
	return r ~= nil and victim ~= nil and r.Target == victim and os.clock() < r.Until
end

function PvPService.Protect(player, seconds)
	if not isPlaying(player) then
		return
	end
	seconds = tonumber(seconds) or 0
	if seconds <= 0 then
		return
	end
	local character = player.Character
	if character and character.Parent and not character:FindFirstChildOfClass("ForceField") then
		local ff = Instance.new("ForceField")
		ff.Visible = false -- ⑤ no bubble (Humanoid:TakeDamage still respects it); the outline shows the shield
		ff.Parent = character
	end
	protectedUntil[player] = math.max(protectedUntil[player] or 0, os.clock() + seconds)
	setAttr(player, "Protected", true)
	addProtectGlow(player)
end

function PvPService.BreakProtection(player)
	if not player then
		return
	end
	-- cheap early-out: CombatService calls this after every PvP hit
	if (protectedUntil[player] or 0) == 0 and player:GetAttribute("Protected") ~= true then
		return
	end
	protectedUntil[player] = 0
	destroyForceFields(player)
	if isPlaying(player) then
		setAttr(player, "Protected", false)
	end
end

-- (allowed: boolean, reasonKey: string?)
function PvPService.CanAttack(attacker, victim)
	if attacker == nil or victim == nil or attacker == victim then
		return false, "Self"
	end
	local PS = S.PlayerService
	if not PS.IsReady(attacker) or not PS.IsReady(victim) then
		return false, "NotReady"
	end
	if not Util.IsAlive(attacker) or not Util.IsAlive(victim) then
		return false, "Dead"
	end
	-- A23-141: the Goose Square is a safe place (nobody inside hits or is hit by a player)
	if Config.InGooseSquare and (Config.InGooseSquare(attacker) or Config.InGooseSquare(victim)) then
		return false, "SafeZone"
	end
	local fa, fv = faction(attacker), faction(victim)
	if fa == "Neutral" or fv == "Neutral" then
		return false, "Neutral" -- addendum A6: Neutral never hits / is hit by players, anywhere
	end
	if not isFighter(fa) or not isFighter(fv) or fa == fv then
		return false, "SameFaction"
	end
	-- A23-113 ①: Roblox friends never hit each other, in any zone (before the kaiju exception: a friend kaiju too)
	if PvPService.AreFriends(attacker, victim) then
		return false, "Friend"
	end
	-- kaiju exception (A23-220, user 10/16 "글리치 이용해서 깨는 건 안 돼", replaces A23-218's Crossroads exception): Halo may
	-- hit the Active kaiju (rookies allowed, protection ignored) only while both stand inside a red PvP zone - the same
	-- place the kaiju can fight back. The Crossroads, the towns, the safe hunting land, one of the two outside: nobody hits
	-- anybody (the normal rules below answer SafeZone)
	if fa == "Halo" and kstate(victim) == "Active" and not inFactionTown(attacker) and inPvP(attacker) and inPvP(victim) then
		return true, nil
	end
	if not inPvP(attacker) or not inPvP(victim) then
		return false, "SafeZone"
	end
	if PvPService.IsRookie(attacker) or PvPService.IsRookie(victim) then
		return false, "Rookie"
	end
	if PvPService.InGrace(attacker) or PvPService.InGrace(victim) then
		return false, "Rookie" -- A23-18: 60 s graduation grace, both ways
	end
	if victim:GetAttribute("Protected") == true then
		return false, "Protected"
	end
	return true, nil
end

-- called ONLY by CombatService's death pipeline (no kill credit: monster, fall, reset)
function PvPService.HandleNonPvPDeath(victim)
	if not victim then
		return
	end
	if (stars[victim] or 0) >= 1 then
		-- CR-L4: a death in town or without damage in the last few seconds (reset, fall) keeps the stars and bounty:
		-- carried gold is 0 in town, so a reset there would otherwise wipe them for free
		local lastHit = tonumber(S.CombatService.GetLastDamagedAt(victim)) or 0
		if S.ZoneService.IsTown(victim) == true or os.clock() - lastHit > GUARD.RecentHitSeconds then
			return
		end
		local carried = num(victim, "CarriedGold", 0)
		local loss = math.floor(carried * Config.PvP.VillainLossOnWantedPvEDeath)
		if loss > 0 then
			S.ProgressionService.TakeCarriedGold(victim, loss, "Penalty")
		end
	end
	PvPService.ResetStars(victim)
end

-- called ONLY by CombatService's death pipeline (after GrudgeService.OnCarrierDown). ctx = { HadSack = the victim
-- carried a grudge sack when it fell (seen before step 1 of the pipeline closed it) }
function PvPService.HandleKO(victim, killer, ctx)
	if not victim then
		return
	end
	if killer == nil or killer == victim or not isPlaying(killer) then
		PvPService.HandleNonPvPDeath(victim)
		return
	end
	local fk, fv = faction(killer), faction(victim)
	if not isFighter(fk) or not isFighter(fv) or fk == fv then
		-- defensive: Neutral / None / same-faction deaths are never PvP KOs (addendum A6)
		PvPService.HandleNonPvPDeath(victim)
		return
	end

	local P = Config.PvP
	local B = Config.Bully
	local Justice = S.JusticeService
	local Progression = S.ProgressionService
	-- the KO's own time (the death pipeline may wait for the friend answer; a respawn after it is not "fresh")
	local now = (type(ctx) == "table" and tonumber(ctx.At)) or os.clock()

	-- 1. snapshot + KO log (CR-M4: the log is kept in the killer's save)
	local starsBefore = stars[victim] or 0
	local bullyBefore = bullyStacksOf(victim)
	-- the victim's bully stacks that still pay a bounty (0 once claimed; anti-farm, see BULLY_BOUNTY_COOLDOWN)
	local bountyBully = bountyBullyStacks(victim)
	local repeated = logKO(killer, victim)

	-- 2. bully check (any faction pairing)
	local weak = combatPower(victim) < B.WeakPowerRatio * combatPower(killer) -- CR-L5
	-- CR-M15: bait = the victim dealt >= BaitMinPct of the killer's base MaxHealth to the killer within BaitWindow
	-- A23-69: with the killer's Health points (the hit base grows with them, so "two hits" keeps its meaning)
	local baitNeed = (B.BaitMinPct or 0.2) * Config.StatMaxHealth(num(killer, "Level", 1), fk, classOf(killer),
		Config.StatAllocOf(killer).H)
	local baitDealt = recentDamage(victim, killer, now)
	local baited = baitDealt > 0 and baitDealt >= baitNeed
	if weak and baited then
		weak = false -- anti-bait: the victim attacked the killer first
	end
	local victimOutlaw = victim:GetAttribute("Outlaw") == true -- A23-23: an outlaw is hunted like a bully
	if weak and B.WantedIgnoresWeakRule and (starsBefore > 0 or bullyBefore > 0 or victimOutlaw) then
		weak = false
	end
	local spawned = spawnedAt[victim]
	local fresh = spawned ~= nil and spawned <= now and now - spawned < B.FreshSpawnSeconds
	local bully = weak or fresh or repeated
	-- CR-M14: a fresh / repeat KO of a victim who baited the killer is self-defense (no bully stack, no rewards),
	-- and a kaiju never becomes a bully (that would double its kaiju pool)
	local defense = baited and (fresh or repeated)
	if defense or kstate(killer) ~= "None" then
		bully = false
	end

	-- BB10 / A23-23: the weekly ranking verdict, decided before the revenge marks below change. A fair KO (PvPCreditOK)
	-- lets the Honor / Infamy below reach the weekly board; an unfair one (weak / idle / new / 4th of the week / fresh)
	-- that no exemption covers adds 1 to the killer's PvP board inside JudgeKO. Never yields: the death pipeline already
	-- asked IsFriendsWith (RankingService.ResolveFriends), so JudgeKO reads the friend cache only (NoYield).
	local bold = PvPService.BoldMult(killer, victim) -- A23-18: honor / infamy / war points only
	local killerMark = revenge[killer]
	local verdict = judgeKO(killer, victim, {
		Bold = bold, Fresh = fresh, Repeated = repeated,
		Defense = defense or victimStruckFirst(victim, killer, now),
		Revenge = killerMark ~= nil and killerMark.Target == victim and now < killerMark.Until,
		VictimWanted = starsBefore > 0, VictimBully = bullyBefore > 0, VictimOutlaw = victimOutlaw,
		VictimKaiju = kstate(victim) ~= "None", KillerKaiju = kstate(killer) == "Active", -- D2: a killer who IS a kaiju
		VictimHadSack = type(ctx) == "table" and ctx.HadSack == true, NoYield = true,
	})

	-- 3. revenge (always)
	revenge[victim] = { Target = killer, Until = now + Config.Revenge.Duration }
	setAttr(victim, "RevengeTargetId", killer.UserId)
	setAttr(victim, "RevengeUntil", Util.Now() + Config.Revenge.Duration)
	notify(victim, fmt("Revenge", Util.PlayerDisplayName(killer)), "info")
	local killerRevenge = revenge[killer]
	if killerRevenge and killerRevenge.Target == victim then
		clearRevenge(killer) -- A23-130: no "Revenge done!" line (the KO and its reward lines answer)
	end

	local info
	if defense then
		-- CR-M14: self-defense KO: no bully stack, stars, plunder, honor/infamy, bounty or war points
		info = { Kind = "Defense", Bully = false, VictimStars = starsBefore, Stolen = 0, Bounty = 0, Rewarded = false }
	elseif bully then
		-- 4. bully KO: no plunder, stars, honor/infamy, bounty or war points
		local n = math.floor(tonumber(Justice.AddBullyStack(killer)) or 0)
		notify(killer, fmt("BullyKO", n), "bad", "None") -- a consequence, not a refused press
		refreshStarAttrs(killer) -- bounty doubles while a bully
		info = { Kind = "Bully", Bully = true, VictimStars = starsBefore, Stolen = 0, Bounty = 0, Rewarded = false }
	else
		-- 5. pair cooldown for minted rewards (CR-M4: kept in the killer's save as "ko:<victimUserId>")
		local pairOk = pairReady(killer, victim.UserId, "ko", P.PairRewardCooldown)
		if pairOk and bold > 1 then notify(killer, fmt("BoldStrong"), "reward", "None") -- the score line says RankUp
		elseif pairOk and bold < 1 then notify(killer, fmt("BoldWeak"), "info") end
		local vLevel = num(victim, "Level", 1)

		if fk == "Horns" then
			-- 6a. Horns KO Halo: plunder into the grudge sack
			if pairOk then
				addStar(killer) -- CR-M3: a farmed pair (inside the cooldown) adds no star
			end
			local stolen = 0
			if not S.GrudgeService.CanSteal(killer, victim) then
				notify(killer, fmt("PlunderTooSoon"), "info")
			else
				local carried = num(victim, "CarriedGold", 0)
				local safeFloor = P.SafeFloorPerLevel * vLevel
				stolen = math.min(math.floor(math.max(0, carried - safeFloor) * P.PlunderRate), P.PlunderCapPerLevel * vLevel)
				if stolen > 0 then
					stolen = math.floor(tonumber(Progression.TakeCarriedGold(victim, stolen, "Plunder")) or 0)
				end
				if stolen > 0 then
					-- A23-18 boldness; BB10: the sack also carries the fair weekly points (paid only if the thief keeps it)
					local inf = pairOk and PvPService.ScalePoints(1, bold) or 0
					local rankPts = verdict.Fair == true and inf or 0
					S.GrudgeService.AddToSack(killer, victim, stolen, inf, rankPts)
					if rankPts > 0 and S.RankingService and S.RankingService.CommitFair then
						pcall(S.RankingService.CommitFair, killer, victim)
					end
					local from, to = rootPos(victim), rootPos(killer)
					if from and to then
						-- sound_gaps B2: Victim / Thief = UserIds (the client plays Plunder for the victim, GoldPickup for the thief)
						Net.Fx(nil, "Plunder", { From = from, To = to, Amount = stolen, Victim = victim.UserId, Thief = killer.UserId })
					end
					-- A23-130: the victim's KO card says who and how much (no Plundered line); the thief gets the gain only
					notify(killer, fmt("PlunderGain", Util.FormatNumber(stolen)), "reward", "GoldPickup")
				end
			end
			if stolen == 0 and pairOk then
				local inf = PvPService.ScalePoints(1, bold) -- A23-18 boldness
				if inf > 0 then grantFame(killer, "Infamy", inf, verdict, victim) end -- no sack to carry it
			end
			local bullyBounty = 0
			if bountyBully > 0 and pairOk then
				bullyBounty = Config.Bounty(vLevel, 0, bountyBully)
				if bullyBounty > 0 then
					claimBullyBounty(victim) -- claimed: no bully bounty on this victim for any killer for a while
					bullyBounty = Progression.AddBankGold(killer, bullyBounty, "Bounty") or bullyBounty -- A23-75: as added
					notify(killer, fmt("BullyBountyGain", Util.FormatNumber(bullyBounty)), "reward", "GoldPickup")
				end
			end
			info = {
				Kind = "Plunder", Bully = false, VictimStars = starsBefore,
				Stolen = stolen, Bounty = bullyBounty, Rewarded = pairOk, BoldMult = bold,
			}
		elseif starsBefore == 0 and bountyBully == 0 then
			-- 6b. Halo KO a clean Horns (or a bully whose bounty was already claimed): honor
			if pairOk then
				local honor = PvPService.ScalePoints(P.HonorPerKOMin, bold) -- A23-18 boldness
				if honor > 0 then
					grantFame(killer, "Honor", honor, verdict, victim)
					notify(killer, fmt("HonorGain", honor), "reward", "RankUp") -- sound_gaps C1: my side's score went up
				end
			end
			info = { Kind = "Honor", Bully = false, VictimStars = 0, Stolen = 0, Bounty = 0, Rewarded = pairOk, BoldMult = bold }
		else
			-- 6c. Halo KO a Wanted (or bully) Horns: bounty
			local bounty = pairOk and Config.Bounty(vLevel, starsBefore, bountyBully) or 0
			if bounty > 0 then
				if bountyBully > 0 then
					claimBullyBounty(victim) -- claimed: no bully bounty on this victim for any killer for a while
				end
				bounty = Progression.AddBankGold(killer, bounty, "Bounty") or bounty -- A23-75: as added (2x Gold)
			end
			local honor = pairOk and PvPService.ScalePoints(math.max(1, starsBefore), bold) or 0 -- A23-18 boldness
			if honor > 0 then
				grantFame(killer, "Honor", honor, verdict, victim)
			end
			if starsBefore > 0 then
				local carried = num(victim, "CarriedGold", 0)
				local loss = math.floor(carried * P.VillainLossOnBountyKO)
				if loss > 0 then
					Progression.TakeCarriedGold(victim, loss, "Penalty")
				end
			end
			if bounty > 0 or honor > 0 then
				notify(killer, fmt("BountyGain", Util.FormatNumber(bounty), honor), "reward", "GoldPickup")
			end
			-- A23-130: no server-wide bounty brag (BountyAnnounce); the hunter has the line above
			info = {
				Kind = "Bounty", Bully = false, VictimStars = starsBefore,
				Stolen = 0, Bounty = bounty, Rewarded = pairOk, BoldMult = bold,
			}
		end
	end

	-- 7. victim's stars are gone; tell everyone
	PvPService.ResetStars(victim)
	PvPService.PlayerKO:Fire(killer, victim, info)
end

------------------------------------------------------------------ board
-- RichText-safe player text on the board (nicknames are validated, Roblox names too; escaped anyway)
local function boardEsc(text)
	return (string.gsub(tostring(text), "[&<>\"]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;" }))
end

-- BB11 (검수 2026-10-06): the crossroads board shows THIS server's weekly boards (Honor / Infamy / Artisan / PvP, the
-- same numbers as the ranking window, ties share a rank) and one wanted line. Names through PublicName; the red outlaw
-- tag only for players who ARE outlaws this week (shown even when the name is hidden, A23-23).
local function updateBoard()
	local ok, label = pcall(function()
		return S.MapBuilder.GetBoardLabel()
	end)
	if not ok or not label then
		return
	end
	local T = Config.Ranking.Text.Board
	local outlawTag = ' <font color="#FF4A4A">' .. Config.Ranking.Text.OutlawTag .. "</font>"
	local R = S.RankingService
	local lines = { T.Header }
	for _, board in Config.Ranking.Order do
		local rows = {}
		if R and R.ServerTop then
			local okTop, top = pcall(R.ServerTop, board, BOARD_ROWS)
			if okTop and type(top) == "table" then rows = top end
		end
		local parts = {}
		for _, row in rows do
			local text = string.format(T.Row, row.Rank, boardEsc(row.Name), Util.FormatNumber(row.Value))
			if row.Outlaw then text ..= outlawTag end
			table.insert(parts, text)
		end
		table.insert(lines, "<b>" .. T.Titles[board] .. "</b>  " .. (#parts > 0 and table.concat(parts, T.Sep) or T.Empty))
	end

	local wanted = {}
	for _, p in S.PlayerService.GetReadyPlayers() do
		local bounty = tonumber(p:GetAttribute("Bounty")) or 0
		if bounty > 0 then
			table.insert(wanted, { P = p, Name = publicName(p), Bounty = bounty, Stars = stars[p] or 0, Bully = bullyStacksOf(p) })
		end
	end
	table.sort(wanted, function(a, b)
		if a.Bounty ~= b.Bounty then
			return a.Bounty > b.Bounty
		end
		return a.P.UserId < b.P.UserId
	end)
	local parts = {}
	for i = 1, math.min(BOARD_ROWS, #wanted) do
		local w = wanted[i]
		local text = string.format("%d. %s", i, boardEsc(w.Name))
		if w.Stars > 0 then
			text ..= " " .. string.rep("★", w.Stars)
		end
		text ..= " " .. Util.FormatNumber(w.Bounty) .. T.Gold
		if w.Bully > 0 then
			text ..= " " .. T.Bully
		end
		if w.P:GetAttribute("Outlaw") == true then text ..= outlawTag end
		table.insert(parts, text)
	end
	table.insert(lines, "<b>" .. T.Wanted .. "</b>  " .. (#parts > 0 and table.concat(parts, T.Sep) or T.Empty))

	local text = table.concat(lines, "\n")
	if label.RichText ~= true then label.RichText = true end
	if label.Text ~= text then
		label.Text = text
	end
end

------------------------------------------------------------------ loops
local function tickPlayer(p, now)
	-- protection expiry (while protected: the outline back on a rebuilt body)
	local pu = protectedUntil[p]
	if pu and pu > 0 and now >= pu then
		protectedUntil[p] = 0
		destroyForceFields(p)
		setAttr(p, "Protected", false)
	elseif pu and pu > 0 then
		if inTown(p) then removeProtectGlow(p) else addProtectGlow(p) end
	end

	-- star decay: one star per StarDecaySeconds, paused while queued / siren / active kaiju
	local s = stars[p] or 0
	if s > 0 then
		if kstate(p) ~= "None" then
			lastStarChange[p] = now
		elseif now - (lastStarChange[p] or now) >= Config.PvP.StarDecaySeconds then
			stars[p] = s - 1
			lastStarChange[p] = now
		end
	end
	refreshStarAttrs(p)
	checkGraduation(p)
	if graceUntil[p] and now >= graceUntil[p] then
		graceUntil[p] = nil
		local data = S.PlayerService.GetData(p)
		if type(data) == "table" then data.GraduateGraceUntil = 0 end
		setAttr(p, "GraduateGraceUntil", 0) -- A23-130: no GraduateEnd line (the HUD countdown chip goes away)
	end
	setAttr(p, "Rookie", rookieAttr(p))

	-- revenge expiry
	local r = revenge[p]
	if r and (now >= r.Until or not isPlaying(r.Target)) then
		clearRevenge(p)
	end
end

-- CR-M15: drop bait-log hits older than BaitWindow (pair state itself is in the saves, CR-M4); BB10: finished fights
local function pruneDmgLog(now)
	for key, e in engage do
		if now - e.Last > GUARD.EngageGap then engage[key] = nil end
	end
	local cutoff = now - Config.Bully.BaitWindow
	for attacker, byVictim in dmgLog do
		for victim, hits in byVictim do
			pruneHits(hits, cutoff)
			if #hits == 0 then
				byVictim[victim] = nil
			end
		end
		if next(byVictim) == nil then
			dmgLog[attacker] = nil
		end
	end
end

-- CR-M12: stars saved at leave come back on the next join minus the decay for the time away, capped below the kaiju
-- threshold. Clears the saved fields. Returns (stars, seconds already spent toward the next decay step).
local function takeSavedStars(player, data)
	if type(data) ~= "table" then
		return 0, 0
	end
	local saved = math.floor(tonumber(data.SavedStars) or 0)
	local at = tonumber(data.SavedStarsAt) or 0
	data.SavedStars = 0
	data.SavedStarsAt = 0
	if saved <= 0 or at <= 0 or not isFighter(faction(player)) then
		return 0, 0
	end
	local step = math.max(1, Config.PvP.StarDecaySeconds)
	local away = math.max(0, os.time() - at)
	local decayed = math.floor(away / step)
	local needed = (Config.Kaiju and Config.Kaiju.StarsNeeded) or Config.PvP.MaxStars
	local cap = math.max(0, math.min(Config.PvP.MaxStars, needed - 1))
	local n = math.clamp(saved - decayed, 0, cap)
	return n, away - decayed * step
end

-- CR-M11: a Wanted Horns logging out while combat-tagged pays the bounty (+ honor, like a bounty KO) to the last Halo
-- attacker, once per pair per PairRewardCooldown. Returns true when paid (the stars count as claimed).
local function payLeaveBounty(player)
	-- CR-M11 / CR-M2: a server shutdown is not the player's choice; keep the stars (saved by CR-M12) instead
	local PS = S.PlayerService
	if PS and type(PS.IsShuttingDown) == "function" then
		local okS, closing = pcall(PS.IsShuttingDown)
		if okS and closing == true then
			return false
		end
	end
	local s = stars[player] or 0
	if s < 1 or faction(player) ~= "Horns" or kstate(player) == "Active" then
		return false -- an Active kaiju's logout is resolved by KaijuService
	end
	local C = S.CombatService
	if not C.IsInCombat(player) then
		return false
	end
	local a = C.GetLastPvPAttacker(player)
	if a == nil or a == player or not isPlaying(a) or not S.PlayerService.IsReady(a) or faction(a) ~= "Halo" then
		return false
	end
	if not pairReady(a, player.UserId, "ko", Config.PvP.PairRewardCooldown) then
		return false
	end
	local bully = bountyBullyStacks(player) -- 0 when this bully's bounty was already claimed
	local bounty = Config.Bounty(num(player, "Level", 1), s, bully)
	local bold = PvPService.BoldMult(a, player)
	local honor = PvPService.ScalePoints(math.max(1, s), bold) -- A23-18 boldness (same as a KO)
	-- BB10: judged like a KO with the leaver as the victim (their data is still loaded here); Wanted = never unfair
	local lastMark = revenge[a]
	local verdict = judgeKO(a, player, {
		Bold = bold, Fresh = false, Repeated = false, Defense = victimStruckFirst(player, a, os.clock()),
		Revenge = lastMark ~= nil and lastMark.Target == player and os.clock() < lastMark.Until,
		VictimWanted = true, VictimBully = bully > 0, VictimOutlaw = player:GetAttribute("Outlaw") == true,
		VictimKaiju = kstate(player) ~= "None", KillerKaiju = kstate(a) == "Active", VictimHadSack = false,
		NoYield = true, -- a PlayerLeaving handler: no web call (friends cache only)
	})
	if bounty > 0 then
		if bully > 0 then
			claimBullyBounty(player)
		end
		bounty = S.ProgressionService.AddBankGold(a, bounty, "Bounty") or bounty -- A23-75: as added (2x Gold)
	end
	if honor > 0 then grantFame(a, "Honor", honor, verdict, player) end
	notify(a, fmt("BountyGain", Util.FormatNumber(bounty), honor), "reward", "GoldPickup")
	return true
end

------------------------------------------------------------------ signal handlers
local function onPlayerReady(player, data)
	-- CR-M12: bring back the stars saved at the last leave (decayed); failures just start clean
	local okSaved, restored, partial = pcall(takeSavedStars, player, data or S.PlayerService.GetData(player))
	if not okSaved then
		Util.Warn(TAG, "saved stars restore failed: " .. tostring(restored))
		restored, partial = 0, 0
	end
	stars[player] = restored
	lastStarChange[player] = os.clock() - (restored > 0 and partial or 0)
	protectedUntil[player] = 0
	player:SetAttribute("WantedStars", 0)
	player:SetAttribute("Bounty", 0)
	player:SetAttribute("Rookie", rookieAttr(player))
	wasRookie[player] = PvPService.IsRookie(player) -- graduation edge starts from the loaded state
	local saved = tonumber(type(data) == "table" and data.GraduateGraceUntil or 0) or 0
	if saved > os.time() then
		startGrace(player, saved - os.time()) -- a rejoin keeps the rest of the 60 s grace
	else
		player:SetAttribute("GraduateGraceUntil", 0)
	end
	player:SetAttribute("Protected", false)
	player:SetAttribute("RevengeTargetId", 0)
	player:SetAttribute("RevengeUntil", 0)
	if restored > 0 then
		refreshStarAttrs(player)
	end
	-- A23-113 ①: ask Roblox about this newcomer and every player already here (background)
	local okFriends, errFriends = pcall(FRIEND.Join, player)
	if not okFriends then
		Util.Warn(TAG, "friend checks failed: " .. tostring(errFriends))
	end
end

local function cleanupPlayer(player)
	clearRevengeInvolving(player)
	stars[player] = nil
	lastStarChange[player] = nil
	protectedUntil[player] = nil
	spawnedAt[player] = nil
	revenge[player] = nil
	dmgLog[player] = nil
	for _, byVictim in dmgLog do
		byVictim[player] = nil
	end
	for key, e in engage do
		if e.A == player or e.B == player then engage[key] = nil end
	end
end

local function onPlayerLeaving(player, data)
	graceUntil[player], wasRookie[player] = nil, nil
	FRIEND.Drop(player) -- A23-113 ①: a rejoin asks again
	-- CR-M11: runs before KaijuService's handler (init order) and while JusticeService still reports the bully
	-- stacks (CR-L1 defers their cleanup)
	local okPay, paid = pcall(payLeaveBounty, player)
	if not okPay then
		Util.Warn(TAG, "leave bounty failed: " .. tostring(paid))
		paid = false
	end
	-- CR-M12: save the unclaimed stars so a rejoin cannot wipe them; a paid leave bounty or an Active kaiju
	-- (KaijuService resolves it) leaves none
	local d = data or S.PlayerService.GetData(player)
	if type(d) == "table" then
		local keep = (paid == true or kstate(player) == "Active") and 0 or (stars[player] or 0)
		-- CR-M12: like SavedBullyAt, back-date by the time already spent toward the next decay step this session
		-- (a queued / siren kaiju refreshes lastStarChange every tick, so into ~ 0 there)
		local step = math.max(1, Config.PvP.StarDecaySeconds)
		local now = os.clock()
		local into = math.clamp(math.floor(now - (lastStarChange[player] or now)), 0, step - 1)
		d.SavedStars = keep
		d.SavedStarsAt = keep > 0 and (os.time() - into) or 0
	end
	-- other services' PlayerLeaving handlers (e.g. KaijuService) may still call ResetStars; clean up after them
	clearRevengeInvolving(player)
	task.defer(cleanupPlayer, player)
end

local function onCharacterSpawned(player, _character, _humanoid, cosmetic)
	if cosmetic then return end -- replacing an appearance never renews spawn protection / the spawn clock
	spawnedAt[player] = os.clock()
	PvPService.Protect(player, Config.PvP.SpawnProtection)
end

-- CR-M15: log each PvP hit with its damage (the applied amount once CR-M10 lands) for the bait check
local function onPlayerDamaged(victim, amount, attacker)
	if victim == nil or attacker == nil then
		return
	end
	-- BB10 D2: who struck first in this fight (any hit, even one a shield blocked)
	local nowFight = os.clock()
	local key = engageKey(attacker, victim)
	local e = engage[key]
	if e == nil or nowFight - e.Last > GUARD.EngageGap then
		engage[key] = { By = attacker, T = nowFight, Last = nowFight, A = attacker, B = victim }
	else
		e.Last = nowFight
	end
	amount = tonumber(amount) or 0
	if amount ~= amount or amount <= 0 then
		return
	end
	local now = os.clock()
	local byVictim = dmgLog[attacker]
	if not byVictim then
		byVictim = {}
		dmgLog[attacker] = byVictim
	end
	local hits = byVictim[victim]
	if not hits then
		hits = {}
		byVictim[victim] = hits
	end
	pruneHits(hits, now - Config.Bully.BaitWindow)
	table.insert(hits, { T = now, A = amount })
	while #hits > GUARD.DmgLogMax do
		table.remove(hits, 1)
	end
end

local function onFactionChanged(player)
	PvPService.ResetStars(player)
	-- revenge marks never cross a faction change (and Neutral never gives/gets revenge; A6)
	clearRevengeInvolving(player)
	if isPlaying(player) then
		setAttr(player, "Rookie", rookieAttr(player))
	end
end

------------------------------------------------------------------ lifecycle
function PvPService.Init(registry)
	S = registry
	S.PlayerService.PlayerReady:Connect(onPlayerReady)
	S.PlayerService.PlayerLeaving:Connect(onPlayerLeaving)
	S.PlayerService.CharacterSpawned:Connect(onCharacterSpawned)
	S.CombatService.PlayerDamaged:Connect(onPlayerDamaged)
	S.FactionService.FactionChanged:Connect(onFactionChanged)
end

function PvPService.Start()
	local okBoard, errBoard = pcall(updateBoard)
	if not okBoard then
		Util.Warn(TAG, "board update failed: " .. tostring(errBoard))
	end

	task.spawn(function()
		local boardAcc = 0
		local pruneAcc = 0
		while true do
			task.wait(LOOP_INTERVAL)
			local now = os.clock()
			for _, p in S.PlayerService.GetReadyPlayers() do
				local ok, err = pcall(tickPlayer, p, now)
				if not ok then
					warnLoop(err)
				end
			end

			boardAcc += LOOP_INTERVAL
			if boardAcc >= Config.PvP.BoardRefresh then
				boardAcc = 0
				local ok, err = pcall(updateBoard)
				if not ok then
					warnLoop(err)
				end
			end

			pruneAcc += LOOP_INTERVAL
			if pruneAcc >= PRUNE_INTERVAL then
				pruneAcc = 0
				local ok, err = pcall(pruneDmgLog, now)
				if not ok then
					warnLoop(err)
				end
			end
		end
	end)

	print("[PvPService] started")
end

return PvPService
