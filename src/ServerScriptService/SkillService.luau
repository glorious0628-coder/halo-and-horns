-- SkillService.luau : SKL-2 (A23-49, docs/design/skill_kit_beta_2026-10-06.md §1-§4, §8-1): the class skills Q / Z / X of
-- every kit (Config.Skills, Config.SkillKit / SkillDef). One press = one cast; the server picks the target.
--   Cast(player, slot, isAuto) is the one entry for the UseSkill remote, the old Release remote (Q) and auto combat:
--     - the shared GlobalGap (0.5 s) between any two skills: a manual press inside it is queued once (it fires when the
--       gap ends), an auto cast simply waits;
--     - every refusal comes before MP is spent (locked / switched off / cooldown / no MP / no target) and tells the
--       presser: Net.Fx "SkillPress" { Slot, Result = "Queued" | "Locked" | "Cooldown" | "NoMP" | "NoTarget" }.
--   Q = CombatService.Release (Config.BasicSkill numbers, unchanged). Z / X shapes run here. SKL-2: Line (a band Len x
--   Width toward the nearest target within Range / Len in the aim cone, else straight ahead) and Chain (the nearest
--   target within Range in the aim cone, then jumps of Jump studs to the nearest new target, Hits in all; no first target
--   = "No target"). SKL-3 adds Field, Roar and Hop (X), so an X cast is refused until then. With nothing in the aim
--   cone a shape aims at the nearest monster within its reach in any direction (A23-61 server aim, the swing's rule):
--   the root turns to it when the cast goes off and that cast hits monsters only.
--   Damage: D (CombatService.ComputeMonsterHit, never crit) x Mult per target, each target once a cast. Players only for
--   a manual cast with Config.Skills.PvPZX on (CombatService.ComputePvPHit x Mult through DamageWindow, like Q). Pull
--   (manual only) / Push through MonsterService.Displace. Halo heals allies within HealRadius of the caster, Horns steal
--   life (both through DamageWindow, CombatService.Kit). CombatService.Released fires with Slot / MonstersHit / Auto.
--   Slots (saved SkillSlots 0..3, mirrored, never lowered): none at the start, Q at Unlock.Q (Lv5), Z at Unlock.Z
--   (Lv15), X at Unlock.X (Lv25) (A23-71), all three after a rebirth (Config.SkillSlotsFor); an old save catches up at
--   PlayerReady. Z / X work only while Config.Skills.ZEnabled / XEnabled (Studio tests until the 10/20 decision); a
--   newly opened slot sends Fx "SkillUnlocked" { Slot } only then (Q always).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local SkillService = {}
local S = nil
local TAG = "SkillService"
local K = Config.Skills or {}
local SLOT = { Q = 1, Z = 2, X = 3 }
local FLAG = { Z = "ZEnabled", X = "XEnabled" }
local READY_ATTR = { Q = "SkillReadyAt", Z = "SkillReadyAtZ", X = "SkillReadyAtX" }
local PVP = { Halo = true, Horns = true }
local TUNE = {
	FxLife = 0.3, -- s the ground mark of a cast shows (§6-2)
	HealRadius = 12, -- studs around the caster: the Halo allies a Z / X heals (§3)
	BigScale = 1.5, -- a monster at least this big (MonsterTypes Scale) or a boss is "big" (Earth Cleave auto rule)
}
-- [Player] = { LastAt = os.clock() of the last cast, Queued = slot waiting for the gap, ReadyAt = { [slot] = os.clock() } }
local state = setmetatable({}, { __mode = "k" })
local SHAPES = {} -- [Def.Shape] = function(ctx) -> plan | nil, refusal

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function isPlayer(x)
	return typeof(x) == "Instance" and x:IsA("Player")
end

local function stateOf(player)
	local s = state[player]
	if not s then
		s = { LastAt = -math.huge, ReadyAt = {} }
		state[player] = s
	end
	return s
end

local function factionOf(player)
	local f = S.FactionService.GetFaction(player)
	return type(f) == "string" and f or "None"
end

local function classOf(player)
	local c = S.ClassService.GetClassDef(player)
	return type(c) == "table" and c or Config.Classes.Warrior
end

local function slotsOf(player)
	return math.clamp(math.floor(num(player:GetAttribute("SkillSlots"), 0)), 0, 3) -- A23-71: 0 = no skill yet
end

local function flagOn(slot)
	return slot == "Q" or K[FLAG[slot]] == true
end

-- the presser's answer (manual casts only): the client shakes the button / shows the short word / the queued ring
local function press(player, slot, result)
	local ok, err = pcall(Net.Fx, player, "SkillPress", { Slot = slot, Result = result })
	if not ok then Util.Warn(TAG, "press: " .. tostring(err)) end
end

local function flatDir(v)
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then return Vector3.new(0, 0, -1) end
	return f.Unit
end

------------------------------------------------------------------ shapes (pure: they pick, they never hit)
-- the nearest target within `reach` of the caster in the aim cone: a monster, or a player when the cast may hit players
local function nearestAimed(ctx, reach, cone)
	local kit = S.CombatService.Kit
	local best = nil
	local mons = kit.Aimed(kit.MonstersNear(ctx.Player, ctx.Pos, reach), ctx.Root, cone)
	if mons[1] then best = { Kind = "M", E = mons[1] } end
	if ctx.PvP then
		local pls = kit.Aimed(kit.PlayersNear(ctx.Player, ctx.Pos, reach), ctx.Root, cone)
		if pls[1] and (best == nil or pls[1].Dist < best.E.Dist) then best = { Kind = "P", E = pls[1] } end
	end
	if best then return best end
	-- A23-61 server aim (검수 2026-10-07, the swing's rule): nothing in the cone -> the nearest monster within reach in any
	-- direction; the root turns to it when the cast goes off (resolve) and the cast hits monsters only
	local any = kit.MonstersNear(ctx.Player, ctx.Pos, reach)[1]
	if any then
		ctx.TurnTo, ctx.PvP = any.Pos, false
		return { Kind = "M", E = any }
	end
	return nil
end

-- Line: a band Len x Width from the caster toward the aimed target (Range, else Len, away), else straight ahead
function SHAPES.Line(ctx)
	local def, pos = ctx.Def, ctx.Pos
	local kit = S.CombatService.Kit
	local len, width = num(def.Len, 20), num(def.Width, 4)
	local aim = nearestAimed(ctx, num(def.Range, len), def.AimCone or ctx.Class.AimCone)
	local dir = flatDir(aim and (aim.E.Pos - pos) or ctx.Root.CFrame.LookVector)
	local half = width / 2
	local function onBand(p)
		local d = p - pos
		local along = d.X * dir.X + d.Z * dir.Z
		return along >= 0 and along <= len and math.abs(d.X * dir.Z - d.Z * dir.X) <= half
	end
	local reach = math.sqrt(len * len + half * half)
	local plan = { Center = pos + dir * (len / 2), Dir = dir, Len = len, Width = width, Monsters = {}, Players = {} }
	for _, m in kit.MonstersNear(ctx.Player, pos, reach) do
		if onBand(m.Pos) then table.insert(plan.Monsters, m) end
	end
	if ctx.PvP then
		for _, v in kit.PlayersNear(ctx.Player, pos, reach) do
			if onBand(v.Pos) then table.insert(plan.Players, v) end
		end
	end
	return plan
end

-- Chain: the aimed target within Range, then the nearest new target within Jump of the last one, Hits in all
function SHAPES.Chain(ctx)
	local def = ctx.Def
	local kit = S.CombatService.Kit
	local jump, hits = num(def.Jump, 10), math.max(1, math.floor(num(def.Hits, 4)))
	local first = nearestAimed(ctx, num(def.Range, 35), def.AimCone or ctx.Class.AimCone)
	if not first then return nil, "NoTarget" end
	local chain = { first }
	local used = { [first.E.Rec or first.E.Player] = true }
	while #chain < hits do
		local at = chain[#chain].E.Pos
		local nextLink = nil
		for _, m in kit.MonstersNear(ctx.Player, at, jump) do -- nearest first
			if not used[m.Rec] then
				nextLink = { Kind = "M", E = m }
				break
			end
		end
		if ctx.PvP then
			for _, v in kit.PlayersNear(ctx.Player, at, jump) do -- a player once a cast
				if not used[v.Player] then
					if nextLink == nil or v.Dist < nextLink.E.Dist then nextLink = { Kind = "P", E = v } end
					break
				end
			end
		end
		if not nextLink then break end
		used[nextLink.E.Rec or nextLink.E.Player] = true
		table.insert(chain, nextLink)
	end
	local plan = { Center = first.E.Pos, Radius = jump, Points = {}, Monsters = {}, Players = {} }
	for _, link in chain do
		table.insert(plan.Points, link.E.Pos)
		table.insert(link.Kind == "M" and plan.Monsters or plan.Players, link.E)
	end
	return plan
end

------------------------------------------------------------------ auto rules (Config.Skills.Defs[kit][slot].Auto)
-- Min targets on the shape; OrBig: one big monster is enough; BeforeQIfSpread = n: with fewer than n spread targets
-- (every chain point inside one Q circle) Q goes first while it is ready
local function autoRule(ctx, plan)
	local a = ctx.Def.Auto
	if type(a) ~= "table" or a.Never then return false end
	local n = #plan.Monsters
	if n == 0 then return false end
	if a.OrBig then
		for _, m in plan.Monsters do
			local d = m.Rec.Def or Config.MonsterTypes[m.Rec.Kind]
			if d and (d.Boss or num(d.Scale, 1) >= TUNE.BigScale) then return true end
		end
	end
	if n < num(a.Min, 1) then return false end
	if a.BeforeQIfSpread then
		local radius = num((Config.BasicSkill or {}).Radius, 9)
		local spread = false
		for _, m in plan.Monsters do
			if Util.FlatDistance(m.Pos, plan.Monsters[1].Pos) > radius then spread = true end
		end
		if not (spread and n >= num(a.BeforeQIfSpread, 2)) then
			local p = ctx.Player
			local qReady = Util.Now() >= num(p:GetAttribute("SkillReadyAt"), 0)
				and num(p:GetAttribute("Mana"), 0) >= num((Config.BasicSkill or {}).ManaCost, 20)
			if qReady then return false end
		end
	end
	return true
end

------------------------------------------------------------------ the cast
-- Pull (a manual cast only) or Push for a monster this cast hit and left alive
local function move(ctx, rec)
	local ms = S.MonsterService
	if type(ms) ~= "table" or type(ms.Displace) ~= "function" then return end
	local def = ctx.Def
	local mode, studs = nil, 0
	if num(def.Pull) > 0 and not ctx.Auto then
		mode, studs = "Pull", num(def.Pull)
	elseif num(def.Push) > 0 then
		mode, studs = "Push", num(def.Push)
	end
	if mode then
		local ok, err = pcall(ms.Displace, rec, mode, ctx.Pos, studs, ctx.Player)
		if not ok then Util.Warn(TAG, "displace: " .. tostring(err)) end
	end
end

local function resolve(ctx, plan)
	local player, def = ctx.Player, ctx.Def
	local CS = S.CombatService
	local kit = CS.Kit
	local mult = num(def.Mult, 1)
	local hits = {}
	local total, shown, monstersHit, playersHit = 0, 0, 0, 0
	if ctx.TurnTo then kit.TurnTo(ctx.Root, ctx.Pos, ctx.TurnTo) end -- A23-61 server aim: face the monster I aimed at
	if #plan.Monsters > 0 then
		local dealt = Util.RoundDamage(CS.ComputeMonsterHit(player, false) * mult)
		for _, m in plan.Monsters do
			local rec = m.Rec
			if rec.Alive then
				-- before the damage: a kill by this cast is a skill kill (story S0 "basic attacks only")
				rec._skillBy = rec._skillBy or {}
				rec._skillBy[player] = true
				local killed, applied = kit.HitMonster(rec, dealt, player)
				if killed or applied > 0 then -- 0 = refused by MonsterService (owner / zone rules): not a hit
					table.insert(hits, { P = m.Pos, A = dealt, C = false, K = "M" })
					total += applied
					shown += dealt
					monstersHit += 1
					if not killed then move(ctx, rec) end
				end
			end
		end
	end
	-- players: a manual cast with PvPZX on only (the shape found none otherwise); the 3 s window per pair like Q
	for _, v in plan.Players do
		local vp = v.Player
		local vHum = Util.GetHumanoid(vp)
		if vp.Parent and vHum and vHum.Health > 0 then
			local capPct = kit.Kaiju(vp) == "Active" and num(Config.Kaiju.ReleaseCapPct, 0.08)
				or num((Config.BasicSkill or {}).PvPCapPct, 0.35)
			local raw = kit.Fit(CS.ComputePvPHit(player, vp) * mult, kit.Room("Hit", player, vp, capPct * vHum.MaxHealth))
			if raw > 0 then
				local dealt = Util.RoundDamage(raw)
				local applied = CS.DamagePlayer(vp, dealt, player) or 0
				kit.Book("Hit", player, vp, applied)
				total += applied
				shown += dealt
				playersHit += 1
				table.insert(hits, { P = v.Pos, A = dealt, C = false, K = "P", V = vp.UserId })
			end
		end
	end
	if playersHit > 0 then S.PvPService.BreakProtection(player) end
	local healed = kit.Heal(player, ctx.Pos, TUNE.HealRadius, total)
	kit.Steal(player, total)
	if not ctx.Auto then S.PlayerService.MarkActive(player) end
	local extent = math.max(num(plan.Len), num(def.Range), num(plan.Radius))
	kit.FxNear(player, "Skill", plan.Center or ctx.Pos, extent, {
		UserId = player.UserId,
		Character = Util.GetCharacter(player),
		Class = ctx.Class.Id,
		Kit = def.Kit,
		Faction = ctx.Faction,
		Slot = ctx.Slot,
		Shape = def.Shape,
		From = ctx.Pos,
		Center = plan.Center,
		Dir = plan.Dir,
		Len = plan.Len,
		Width = plan.Width,
		Radius = plan.Radius,
		Points = plan.Points,
		Life = TUNE.FxLife,
		Auto = ctx.Auto,
		Total = shown,
		Hits = hits,
		Statuses = {}, -- SKL-3: Guard / Taunt / Slow / MP
	})
	CS.Released:Fire(player, {
		Slot = ctx.Slot,
		Stacks = 0, -- legacy event compatibility
		Auto = ctx.Auto,
		Perfect = false,
		Center = plan.Center or ctx.Pos,
		Radius = num(plan.Radius, num(plan.Len)),
		Total = total,
		MonstersHit = monstersHit,
		PlayersHit = playersHit,
		Healed = healed,
	})
end

local function castQ(player, s, isAuto)
	local skill = Config.BasicSkill or {}
	if not isAuto then
		if Util.Now() < num(player:GetAttribute("SkillReadyAt"), 0) then
			press(player, "Q", "Cooldown")
			return false
		end
		if num(player:GetAttribute("Mana"), 0) < num(skill.ManaCost, 20) then
			press(player, "Q", "NoMP")
			return false
		end
	end
	local ok = S.CombatService.Release(player, isAuto) == true
	if ok then s.LastAt = os.clock() end
	return ok
end

local function castZX(player, s, slot, isAuto)
	local c = classOf(player)
	local fac = factionOf(player)
	local def = Config.SkillDef(c.Id, fac, slot)
	local shape = def and SHAPES[def.Shape]
	if not shape then return false end -- Field / Roar / Hop: SKL-3
	if isAuto and (type(def.Auto) ~= "table" or def.Auto.Never) then return false end
	local root = Util.GetRoot(player)
	local kit = S.CombatService.Kit
	if not root or kit.Blocked(player, root, "Skill") then return false end
	local now = os.clock()
	if now < (s.ReadyAt[slot] or -math.huge) then
		if not isAuto then press(player, slot, "Cooldown") end
		return false
	end
	local cost = num(def.MP)
	if num(player:GetAttribute("Mana"), 0) < cost then
		if not isAuto then press(player, slot, "NoMP") end
		return false
	end
	local ctx = { Player = player, Class = c, Faction = fac, Def = def, Slot = slot, Auto = isAuto, Root = root,
		Pos = root.Position, PvP = not isAuto and K.PvPZX == true and PVP[fac] == true }
	local plan, why = shape(ctx)
	if not plan then
		if not isAuto and why then press(player, slot, why) end
		return false
	end
	if isAuto and not autoRule(ctx, plan) then return false end
	if not S.VitalsService.TrySpendMana(player, cost, true) then
		if not isAuto then press(player, slot, "NoMP") end
		return false
	end
	local cd = num(def.CD, 1)
	s.LastAt = now
	s.ReadyAt[slot] = now + cd
	player:SetAttribute(READY_ATTR[slot], Util.Now() + cd)
	resolve(ctx, plan)
	return true
end

-- one cast of `slot` ("Q" | "Z" | "X"); true when it went off (a queued press returns false and fires later)
function SkillService.Cast(player, slot, isAuto)
	isAuto = isAuto == true
	if not isPlayer(player) or player.Parent == nil or SLOT[slot] == nil then return false end
	if not S.PlayerService.IsReady(player) or player:GetAttribute("ClassChosen") ~= true or not Util.IsAlive(player) then
		return false
	end
	if not flagOn(slot) or SLOT[slot] > slotsOf(player) then
		if not isAuto then press(player, slot, "Locked") end
		return false
	end
	local s = stateOf(player)
	local wait = num(K.GlobalGap, 0.5) - (os.clock() - s.LastAt)
	if wait > 0.001 then
		if isAuto or s.Queued ~= nil then return false end -- auto waits; one queued press at a time
		s.Queued = slot
		press(player, slot, "Queued")
		local character = Util.GetCharacter(player)
		task.delay(wait, function()
			if s.Queued ~= slot then return end
			s.Queued = nil
			if player.Parent == nil or Util.GetCharacter(player) ~= character then return end
			local ok, err = pcall(SkillService.Cast, player, slot, false)
			if not ok then Util.Warn(TAG, "queued cast: " .. tostring(err)) end
		end)
		return false
	end
	if slot == "Q" then return castQ(player, s, isAuto) end
	return castZX(player, s, slot, isAuto)
end

-- auto combat (CombatService.autoTick, after its own auto checks): Z when its auto rule holds (SKL-3: X first). True
-- when a skill went off (Q follows on a later tick, after the gap).
function SkillService.AutoCast(player)
	if K.ZEnabled ~= true or slotsOf(player) < SLOT.Z then return false end
	return SkillService.Cast(player, "Z", true)
end

------------------------------------------------------------------ slots (A23-71: Q Lv5, Z Lv15, X Lv25, all after a rebirth)
local function slotsFor(player)
	return Config.SkillSlotsFor(num(player:GetAttribute("Level"), 1), num(player:GetAttribute("Rebirths")))
end

-- raises the saved SkillSlots to what the level / rebirths allow (never lowers it); announce = the new-slot Fx
local function catchUp(player, announce)
	if not isPlayer(player) or player.Parent == nil or not S.PlayerService.IsReady(player) then return end
	local have = slotsOf(player)
	local want = slotsFor(player)
	if want <= have then return end
	S.PlayerService.SetStat(player, "SkillSlots", want)
	if not announce then return end
	local order = K.Order or { "Q", "Z", "X" }
	for i = have + 1, want do
		local slot = order[i]
		if slot and flagOn(slot) then
			local ok, err = pcall(Net.Fx, player, "SkillUnlocked", { Slot = slot })
			if not ok then Util.Warn(TAG, "unlock: " .. tostring(err)) end
		end
	end
end

------------------------------------------------------------------ remote
local function onUseSkill(player, slot, ...)
	if select("#", ...) ~= 0 or type(slot) ~= "string" or SLOT[slot] == nil then return end
	if not S.PlayerService.IsReady(player) then return end
	if not Util.RateLimit(player, "UseSkill", num(Config.RateLimits.UseSkill, 0.1)) then return end
	S.PlayerService.MarkActive(player)
	S.CombatService.Kit.NoteManual(player) -- auto combat yields to my own presses
	SkillService.Cast(player, slot, false)
end

------------------------------------------------------------------ lifecycle
local function connect(serviceName, signalName, fn)
	local service = S[serviceName]
	local signal = service and service[signalName]
	if type(signal) == "table" and type(signal.Connect) == "function" then
		signal:Connect(function(...)
			local ok, err = pcall(fn, ...)
			if not ok then Util.Warn(TAG, signalName .. ": " .. tostring(err)) end
		end)
	else
		Util.Warn(TAG, "missing signal " .. serviceName .. "." .. signalName)
	end
end

local function forgetQueue(player)
	local s = state[player]
	if s then s.Queued = nil end
end

function SkillService.Init(registry)
	S = registry
end

function SkillService.Start()
	Net.Get("UseSkill").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onUseSkill, player, ...)
		if not ok then Util.Warn(TAG, "UseSkill: " .. tostring(err)) end
	end)
	connect("PlayerService", "PlayerReady", function(player) catchUp(player, false) end)
	connect("ProgressionService", "LeveledUp", function(player) catchUp(player, true) end)
	connect("ProgressionService", "Rebirthed", function(player) catchUp(player, true) end)
	-- a real respawn resets the Z / X cooldowns like Q's (CombatService); a cosmetic one never does
	connect("PlayerService", "CharacterSpawned", function(player, _character, _humanoid, cosmetic)
		if cosmetic or not isPlayer(player) then return end
		local s = state[player]
		if s then
			s.ReadyAt, s.Queued = {}, nil
		end
		if player.Parent then
			player:SetAttribute(READY_ATTR.Z, 0)
			player:SetAttribute(READY_ATTR.X, 0)
		end
	end)
	connect("PlayerService", "CharacterDied", forgetQueue)
	connect("FactionService", "FactionChanged", forgetQueue)
	connect("ClassService", "ClassChanged", forgetQueue)
	connect("PlayerService", "PlayerLeaving", function(player) state[player] = nil end)
	print("[SkillService] started (Z " .. tostring(K.ZEnabled == true) .. ", X " .. tostring(K.XEnabled == true) .. ")")
end

return SkillService
