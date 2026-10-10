-- FirstKOService.luau : A23-110 the first KO (게임성 개발 2; user 2026-10-10 "한 번 죽자. 초반 퀘스트 하면서 그래서 물약 사게
-- 하고, 퀵슬롯 하게 하자" + "죽게 만드는 거에서는 킹 슬라임을 잡자"). Config.FirstKOKing (the numbers) + Config.FirstKO (game dev
-- 3's quest KO1 "The King's Hop": Quest, Step, RematchStep; never a step number of our own).
-- The stage comes from StoryQuestService.CurrentStep(player, Config.FirstKO.Quest):
--   == Step        "First": a quiet personal King Slime (MonsterService.SpawnPersonal Quiet: only its owner sees and hits
--                  it, its kill fires no MonsterKilled). Its landing thud - and every later hit - knocks the player out in
--                  one hit, once per account (data.FirstKODone), only below Config.FirstKOKing.OneHitBelow, and never
--                  while something is at stake (a grudge sack, wanted stars / bounty, a PvP fight, the kaiju queue: then it
--                  hits like a plain King and a death is a normal one, so the lossless KO is no way out of a loss). That KO
--                  loses nothing: CombatService's death pipeline asks ClaimKO and then only sends the short KO screen
--                  (Net.Fx "KO" First = true); the quest hears StoryQuestService.Event(player, "FirstKO", { Kind }) (its
--                  next row); PlayerService asks GetUp and stands the player up near where it fell after RespawnIn s, with
--                  GetUp.HealthFrac of MaxHealth. Killed anyway: Event "FirstKO" { Kind, Beaten = true } (the row counts).
--                  "Tell": the KO already had (or Lv OneHitBelow+): no King, the quest is told again every SpawnGap.
--   == RematchStep "Retry": a normal personal King (SpawnPersonal Practice = Retry.PayAs) with the HP / hits of
--                  Config.FirstKORetry (one HP potion wins; the HP from the best weapon the save may use). Its kill is MonsterService's normal Personal kill (MonsterKilled
--                  Kind SlimeKing, ZoneId SlimeMeadow, Personal, Practice = true): the quest's Kill row counts it; no
--                  finisher card, drops or daily jobs; the Slime Prince's XP / gold. One win per session while the row
--                  stays (no farming a stuck row). A KO by it is a normal KO.
-- Both Kings: Near (by the player or not at all), Hold = DropTime (no swing before the landing); a King whose owner
-- steps into a town goes home (it never swings there, so it is never fought from there). Config.FirstKOKing.Enabled =
-- false: no King at all, the KO row is still told (never stuck on it).
--   FirstKOService.StageOf(player, data?) -> "First" | "Tell" | "Retry" | nil
--   FirstKOService.ClaimKO(victim, diedAt) -> { RespawnIn = s } | nil   (CombatService's death pipeline)
--   FirstKOService.GetUp(player) -> { Delay = s, CFrame = CFrame? } | nil (PlayerService's respawn)
--   FirstKOService.Tick()                                              (the check loop, every Config.FirstKOKing.Tick s)
--   FirstKOService.Debug(player, value)                                (Studio: "first" / "retry" / "reset" / "off")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local FirstKOService = {}
-- (player) once per account, right after the lossless first KO (data.FirstKODone is set, the quest already told)
FirstKOService.FirstKO = Util.Signal.new()
-- (player, retry) the player's own King fell (informational): retry = true for the rematch King, false for the first one
FirstKOService.KingBeaten = Util.Signal.new()

local TAG = "FirstKOService"
local S = nil
local FK = Config.FirstKOKing or {}
local ST = {
	Kings = {}, -- [Player] = { Rec = MonsterService record, Stage = "First" | "Retry" }
	Pending = {}, -- [Player] = { At = os.clock(), Pos = Vector3, From = Vector3 } a lethal first-KO hit just dealt
	Up = {}, -- [Player] = { Delay = s, CFrame = CFrame?, Until = os.clock() } the claimed get-up (until the next spawn)
	NextAt = {}, -- [Player] = os.clock() before which no new King comes (and the quest is not told again)
	Beaten = {}, -- [Player] = true: a rematch King fell in this session (no second one while the row stays)
	Force = {}, -- [Player] = "First" | "Retry" (Studio Debug only)
	WarnAt = {},
}

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function warnThrottled(key, msg)
	local now = os.clock()
	if now - (ST.WarnAt[key] or -math.huge) < 10 then return end
	ST.WarnAt[key] = now
	Util.Warn(TAG, tostring(msg))
end

local function getData(player)
	local ok, data = pcall(S.PlayerService.GetData, player)
	return ok and type(data) == "table" and data or nil
end

local function kingKind()
	local k = FK.Kind
	return (type(k) == "string" and Config.MonsterTypes[k] ~= nil) and k or "SlimeKing"
end

local function respawnIn()
	return math.clamp(num(FK.RespawnIn, 3), 0.5, 10)
end

------------------------------------------------------------------ the quest (game dev 3's KO1)
local function quest()
	return type(Config.FirstKO) == "table" and Config.FirstKO or {}
end

-- the step game dev 3's quest stands at (StoryQuestService.CurrentStep: nil = not started, done or waiting for [Claim])
local function questStep(player)
	local Q, svc = quest(), S.StoryQuestService
	if type(Q.Quest) ~= "string" or type(svc) ~= "table" or type(svc.CurrentStep) ~= "function" then return nil end
	local ok, step = pcall(svc.CurrentStep, player, Q.Quest)
	if not ok then
		warnThrottled("step", step)
		return nil
	end
	return type(step) == "number" and step or nil
end

-- tells the quest that its first row is done: the first KO (beaten = false) or the first King beaten after all (true).
-- StoryQuestService.Event returns true when the step moved
local function report(player, beaten)
	local svc = S.StoryQuestService
	if type(svc) ~= "table" or type(svc.Event) ~= "function" then return false end
	local ok, moved = pcall(svc.Event, player, "FirstKO", { Kind = kingKind(), Beaten = beaten == true or nil })
	if not ok then
		warnThrottled("event", moved)
		return false
	end
	return moved == true
end

-- a kaiju (KaijuService Siren / Active) never gets a King: its KO belongs to the kaiju event's pipeline
local function isKaiju(player)
	local K = S.KaijuService
	if type(K) ~= "table" or type(K.GetState) ~= "function" then return false end
	local ok, st = pcall(K.GetState, player)
	return ok and (st == "Siren" or st == "Active")
end

-- something a normal death would settle (the death pipeline's grudge sack, wanted stars / bounty, a PvP KO, the kaiju
-- queue): the lossless first KO must never skip it, so then the King hits like a plain King. A failing check counts as
-- at stake (no lossless KO when unsure)
local function atStake(player)
	local G, P, Cb, K = S.GrudgeService, S.PvPService, S.CombatService, S.KaijuService
	local okS, sack = pcall(function() return type(G) == "table" and G.HasSack(player) == true end)
	if not okS or sack then return true end
	local okW, stars = pcall(function() return type(P) == "table" and tonumber(P.GetStars(player)) or 0 end)
	if not okW or num(stars) >= 1 or num(player:GetAttribute("Bounty")) > 0 then return true end
	-- the PvP combat tag (CombatTagTime): set on both the hit player and the hitter, so it also covers a live attacker
	local okP, fight = pcall(function() return type(Cb) == "table" and Cb.IsInCombat(player) == true end)
	if not okP or fight then return true end
	local okK, st = pcall(function() return type(K) == "table" and K.GetState(player) or "None" end)
	return not okK or (st ~= "None" and st ~= nil)
end

-- "First" = the one-hit King (the quest's Step, the account never had the KO, below OneHitBelow); "Tell" = the quest's
-- Step but the KO already happened (or OneHitBelow reached): the quest is told, no King; "Retry" = the weakened King (the
-- quest's RematchStep); nil = none. Enabled = false: no King at all, the KO row is still told (never stuck on it)
function FirstKOService.StageOf(player, data)
	data = data or getData(player)
	if not data or isKaiju(player) then return nil end
	local off = FK.Enabled == false
	local fresh = data.FirstKODone ~= true and num(data.Level, 1) < num(FK.OneHitBelow, 10)
	local forced = (not off) and ST.Force[player] or nil
	if forced == "First" then return fresh and "First" or "Retry" end
	if forced == "Retry" then return "Retry" end
	local Q = quest()
	local step = questStep(player)
	if step == nil then return nil end
	if step == Q.Step then return (fresh and not off) and "First" or "Tell" end
	if step == Q.RematchStep and not off then return "Retry" end
	return nil
end

-- the quest's spot (Landmark: a StoryLandmark-tagged instance first, then Config.StoryQuests.Landmarks); nil = anywhere
local function landmark()
	local id = FK.Landmark
	if type(id) ~= "string" then return nil end
	local SQ = type(Config.StoryQuests) == "table" and Config.StoryQuests or {}
	local spot = Util.TaggedSpot(SQ.LandmarkTag or "StoryLandmark", id)
	if spot == nil and type(SQ.Landmarks) == "table" then spot = SQ.Landmarks[id] end
	return typeof(spot) == "Vector3" and spot or nil
end

-- the player stands where the King comes: alive, in Zone (not a town), within Radius of the landmark when one is set,
-- and no field King (FieldBossService's, Owner nil) within BossClear studs: the two bodies never overlap
local function inPlace(player)
	if not Util.IsAlive(player) then return false end
	local root = Util.GetRoot(player)
	local pos = root and root.Position
	if typeof(pos) ~= "Vector3" then return false end
	local zone = Config.ZoneAt(pos)
	if zone.Id ~= FK.Zone or zone.Town == true then return false end
	local spot = landmark()
	if spot ~= nil and Util.FlatDistance(pos, spot) > num(FK.Radius, 90) then return false end
	local okM, list = pcall(S.MonsterService.GetMonstersInRadius, pos, math.max(0, num(FK.BossClear, 24)))
	if okM and type(list) == "table" then
		for _, r in list do
			if type(r) == "table" and r.Owner == nil and r.Kind == kingKind() then return false end
		end
	end
	return true
end

------------------------------------------------------------------ the hits
-- the retry King's numbers for this player: the best weapon the save may use (Config.BestUsableWeapon, with that tier's
-- +N), never the one in hand (a swap to a weak weapon must not shrink the King)
local function retryOf(player)
	local data = getData(player) or {}
	local level = num(data.Level, num(player:GetAttribute("Level"), 1))
	local tier = Config.BestUsableWeapon(data.WeaponOwnedMask, level)
	local enh = type(data.WeaponEnhance) == "table" and num(data.WeaponEnhance[tier]) or 0
	return Config.FirstKORetry(level, tier, player:GetAttribute("Class"), player:GetAttribute("Faction"), enh)
end

local function hitBase(rec, target)
	local def = type(rec.Def) == "table" and rec.Def or {}
	return S.CombatService.DamagePlayer(target, num(def.Damage, 1), nil, false, rec.Kind)
end

-- every landed hit of a King of ours (MonsterService rec._strike) and its landing thud. Only the owner on the King's own
-- stage gets the raised damage: the first King one-shots (the lethal hit is noted BEFORE the damage, so a Died handler
-- that runs at once already sees it), the retry King hits FirstKORetry.Hit of MaxHealth; anything else is a plain hit
local function strike(rec, target)
	local owner = rec.Owner
	local e = owner and ST.Kings[owner]
	if target ~= owner or not e or e.Rec ~= rec then return hitBase(rec, target) end
	local hum, root = Util.GetHumanoid(target), Util.GetRoot(target)
	if not hum or not root or hum.Health <= 0 then return 0 end
	local stage = FirstKOService.StageOf(target)
	if stage ~= e.Stage then return hitBase(rec, target) end -- the step moved on under it (Tick sends it home)
	if stage == "First" and atStake(target) then return hitBase(rec, target) end -- never a way out of a loss
	if stage == "First" then
		local from = (rec.Root and rec.Root.Parent) and rec.Root.Position or root.Position
		local pend = { At = os.clock(), Pos = root.Position, From = from }
		ST.Pending[target] = pend
		local applied = S.CombatService.DamagePlayer(target, hum.MaxHealth * math.max(10, num(FK.OneHitMult, 20)), nil,
			false, rec.Kind)
		if hum.Health > 0 and ST.Pending[target] == pend then ST.Pending[target] = nil end -- a ForceField took it: no KO
		return applied
	end
	return S.CombatService.DamagePlayer(target, hum.MaxHealth * retryOf(target).Hit, nil, false, rec.Kind)
end

------------------------------------------------------------------ the King
-- the owner stands in a town: a personal King there never swings (MonsterService), so it must not be fought from there
local function inTown(player)
	local root = Util.GetRoot(player)
	return root ~= nil and typeof(root.Position) == "Vector3" and Config.ZoneAt(root.Position).Town == true
end

local function removeKing(player, leaving)
	local e = ST.Kings[player]
	ST.Kings[player] = nil
	if not e then return end
	local ok, err = pcall(S.MonsterService.RemovePersonal, e.Rec, true, leaving == true)
	if not ok then warnThrottled("remove", err) end
end

-- MonsterService (rec._onKilled; for the rematch King after its MonsterKilled, which already reached the quest's Kill row):
-- our King fell. The first King beaten before it knocked its owner out still passes the quest's row
local function onKilled(rec)
	local player = rec.Owner
	local e = player and ST.Kings[player]
	if not e or e.Rec ~= rec then return end
	ST.Kings[player] = nil
	ST.NextAt[player] = os.clock() + num(FK.SpawnGap, 4)
	if e.Stage == "Retry" then
		ST.Beaten[player] = true
	else
		report(player, true)
	end
	FirstKOService.KingBeaten:Fire(player, e.Stage == "Retry")
end

-- the first King's landing thud, DropTime s after it appeared: hits its owner within LandRadius (flat, 12 up / down)
local function land(player, rec)
	local e = ST.Kings[player]
	if not e or e.Rec ~= rec or e.Stage ~= "First" or not rec.Alive then return end
	local root, kroot = Util.GetRoot(player), rec.Root
	if not root or not kroot or not kroot.Parent or not Util.IsAlive(player) then return end
	local p, k = root.Position, kroot.Position
	if Config.ZoneAt(p).Town == true then return end
	if Util.FlatDistance(p, k) > num(FK.LandRadius, 10) or math.abs(p.Y - k.Y) > 12 then return end
	strike(rec, player)
end

local function spawnKing(player, stage)
	local first = stage == "First"
	-- Near: never the home-town fallback spot (by the player or not at all); Hold: no swing before the landing
	local opts = { HP = first and math.max(1, num(FK.FirstHP, 5000)) or retryOf(player).HP,
		Distance = num(FK.SpawnDistance, 6), Strike = strike, OnKilled = onKilled, Near = true,
		Hold = math.max(0, num(FK.DropTime, 1.2)) }
	if first then
		opts.Quiet = true
	else
		local R = type(FK.Retry) == "table" and FK.Retry or {}
		opts.Practice = type(R.PayAs) == "string" and R.PayAs or true
	end
	ST.NextAt[player] = os.clock() + num(FK.SpawnGap, 4)
	local ok, model, rec = pcall(S.MonsterService.SpawnPersonal, player, kingKind(), opts)
	if not ok then
		warnThrottled("spawn", model)
		return nil
	end
	if type(rec) ~= "table" or rec.Alive ~= true then return nil end
	if rec._strike ~= strike or (typeof(model) == "Instance" and model:GetAttribute("FirstKO") ~= nil) then
		-- not a fresh King of ours (SpawnPersonal reuses one per kind): it goes home, the next check sends ours
		pcall(S.MonsterService.RemovePersonal, rec, true, true)
		return nil
	end
	ST.Kings[player] = { Rec = rec, Stage = stage }
	if typeof(model) == "Instance" then
		-- game dev 1: the drop from the sky (DropAt = server time, DropTime s) and the stage
		model:SetAttribute("FirstKO", stage)
		model:SetAttribute("DropTime", num(FK.DropTime, 1.2))
		model:SetAttribute("DropAt", Util.Now())
	end
	if first then
		task.delay(math.max(0, num(FK.DropTime, 1.2)), function()
			local okL, err = pcall(land, player, rec)
			if not okL then warnThrottled("land", err) end
		end)
	end
	return rec
end

local function checkPlayer(player, now)
	local e = ST.Kings[player]
	local stage = FirstKOService.StageOf(player)
	if stage ~= "Retry" then ST.Beaten[player] = nil end -- the rematch row is over (or not reached)
	if e then
		if e.Rec.Alive ~= true then
			ST.Kings[player] = nil -- its time ran out / its model was lost (a kill already cleared it in onKilled)
			ST.NextAt[player] = math.max(ST.NextAt[player] or 0, now + num(FK.SpawnGap, 4)) -- not a new drop at once
			e = nil
		elseif stage ~= e.Stage or not Util.IsAlive(player) or inTown(player) then
			removeKing(player, true) -- the step moved on, its owner fell (a retry starts fresh) or went into a town
			ST.NextAt[player] = now + num(FK.SpawnGap, 4)
			return
		end
	end
	if e or stage == nil or now < (ST.NextAt[player] or 0) then return end
	if stage == "Tell" then
		-- the quest waits for a KO this account already had (or a player too strong for the one hit): tell it, no King
		ST.NextAt[player] = now + num(FK.SpawnGap, 4)
		report(player, false)
		return
	end
	if stage == "Retry" and ST.Beaten[player] then return end -- one rematch win per session while the row stays
	if not inPlace(player) then return end
	spawnKing(player, stage)
end

function FirstKOService.Tick()
	local now = os.clock()
	for player, up in ST.Up do
		if now > up.Until or player.Parent == nil then ST.Up[player] = nil end
	end
	for player, pend in ST.Pending do
		if now - pend.At > num(FK.ClaimGrace, 1) + 1 then ST.Pending[player] = nil end
	end
	local okL, list = pcall(S.PlayerService.GetReadyPlayers)
	if not okL or type(list) ~= "table" then return end
	for _, player in list do
		local ok, err = pcall(checkPlayer, player, now)
		if not ok then warnThrottled("tick", err) end
	end
end

------------------------------------------------------------------ the KO and the get-up
-- where the first KO gets up: GetUp.Back studs from where it fell, away from the King (else right there), on the
-- monsters' walkable ground in Zone and out of town, facing where the King was; nil = the normal spawn
local function getUpCFrame(pend)
	local G = type(FK.GetUp) == "table" and FK.GetUp or {}
	local pos, from = pend.Pos, pend.From
	local away = Vector3.new(pos.X - from.X, 0, pos.Z - from.Z)
	away = away.Magnitude > 0.01 and away.Unit or Vector3.new(0, 0, 1)
	for _, back in { math.max(0, num(G.Back, 6)), 0 } do
		local p = pos + away * back
		local okG, g, noHit = pcall(S.MonsterService.GroundAt, p.X, p.Z)
		if okG then
			if g == nil and noHit == true then g = Vector3.new(p.X, 0, p.Z) end -- a bare test place: flat ground
			if typeof(g) == "Vector3" then
				local zone = Config.ZoneAt(g)
				if zone.Id == FK.Zone and zone.Town ~= true then
					local at = g + Vector3.new(0, num(G.Lift, 4), 0)
					return CFrame.lookAt(at, at - away)
				end
			end
		end
	end
	return nil
end

-- the first KO gets up with GetUp.HealthFrac of MaxHealth (the quest's next rows buy and drink a potion); never a heal
local function getUpHealth(humanoid)
	if typeof(humanoid) ~= "Instance" or humanoid.Health <= 0 then return end
	local G = type(FK.GetUp) == "table" and FK.GetUp or {}
	local want = math.max(1, math.floor(humanoid.MaxHealth * math.clamp(num(G.HealthFrac, 0.4), 0.05, 1) + 0.5))
	if want < humanoid.Health then humanoid.Health = want end
end

-- CombatService's death pipeline, first of all: this death is the first KO when the King's lethal hit was dealt within
-- ClaimGrace s before it, the account never had it and nothing is at stake. Then FirstKODone is set (before anything else:
-- never twice), the King floats home, the get-up is held for PlayerService, the quest is told (Event "FirstKO") and FirstKO
-- fires. -> { RespawnIn } or nil (a normal death)
function FirstKOService.ClaimKO(victim, diedAt)
	local pend = ST.Pending[victim]
	ST.Pending[victim] = nil
	if not pend then return nil end
	local t = num(diedAt, os.clock())
	if t < pend.At - 0.05 or t - pend.At > num(FK.ClaimGrace, 1) then return nil end
	local data = getData(victim)
	if not data or data.FirstKODone == true or atStake(victim) then return nil end -- at stake: the normal pipeline
	S.PlayerService.SetStat(victim, "FirstKODone", true)
	removeKing(victim, true)
	ST.NextAt[victim] = os.clock() + num(FK.SpawnGap, 4)
	local okC, cf = pcall(getUpCFrame, pend)
	if not okC then warnThrottled("getup", cf) end
	local up = { Delay = respawnIn(), CFrame = okC and cf or nil,
		Until = os.clock() + math.max(1, num(type(FK.GetUp) == "table" and FK.GetUp.Keep, 20)) }
	ST.Up[victim] = up
	report(victim, false)
	FirstKOService.FirstKO:Fire(victim)
	return { RespawnIn = up.Delay }
end

-- PlayerService: the held get-up ({ Delay, CFrame }), or - at the Died event, before the pipeline claimed the KO - the
-- first KO's delay alone; nil = a normal respawn
function FirstKOService.GetUp(player)
	local up = ST.Up[player]
	if up then
		if os.clock() > up.Until then
			ST.Up[player] = nil
			return nil
		end
		return { Delay = up.Delay, CFrame = up.CFrame }
	end
	local pend = ST.Pending[player]
	if pend and os.clock() - pend.At <= num(FK.ClaimGrace, 1) then
		local data = getData(player)
		if data and data.FirstKODone ~= true and not atStake(player) then return { Delay = respawnIn() } end
	end
	return nil
end

------------------------------------------------------------------ Studio aid / lifecycle
-- Main.server DebugCommand "FirstKO": "first" / "retry" = that stage without the quest (this session), "reset" = the
-- account may have its first KO again, anything else = back to the quest
function FirstKOService.Debug(player, value)
	if not RunService:IsStudio() then return "Studio only" end
	local v = tostring(value)
	if v == "reset" then
		S.PlayerService.SetStat(player, "FirstKODone", false)
		return "FirstKODone = false"
	end
	removeKing(player, true)
	ST.NextAt[player], ST.Beaten[player] = 0, nil
	if v == "first" or v == "retry" then
		ST.Force[player] = v == "first" and "First" or "Retry"
		return "forced " .. v
	end
	ST.Force[player] = nil
	return "off"
end

local function forget(player)
	ST.Kings[player] = nil -- MonsterService removes a leaving owner's personal monsters itself
	ST.Pending[player], ST.Up[player], ST.NextAt[player], ST.Force[player], ST.Beaten[player] = nil, nil, nil, nil, nil
end

function FirstKOService.Init(registry)
	S = registry
end

function FirstKOService.Start()
	local PS = S.PlayerService
	PS.PlayerLeaving:Connect(forget)
	PS.CharacterSpawned:Connect(function(player, _character, humanoid, cosmetic)
		if cosmetic == true then return end
		local up = ST.Up[player]
		ST.Up[player] = nil -- the held get-up was used
		if up then
			local ok, err = pcall(getUpHealth, humanoid)
			if not ok then warnThrottled("health", err) end
		end
	end)
	Players.PlayerRemoving:Connect(forget)
	task.spawn(function()
		while true do
			task.wait(math.max(0.1, num(FK.Tick, 0.5)))
			local ok, err = pcall(FirstKOService.Tick)
			if not ok then warnThrottled("loop", err) end
		end
	end)
end

return FirstKOService
