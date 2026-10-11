-- friend_pvp_offline.luau : A23-113 ① (user 2026-10-10, docs/SPEC_ADDENDUM.md): Roblox friends never damage each other,
-- even on different sides inside PvP areas: manual swings, Q / Z / X, fields and the kaiju's stomp. The friend answer is
-- PvPService's one IsFriendsWith call per pair, asked when the second of the two is ready (join order free), cached until
-- one of them leaves; a failed call = not friends; not friends until the answer arrives. Friend KOs stay off the boards
-- exactly as before (RankingService's own cache, the opposite failure rule). tools/test_friend_pvp.py runs the REAL
-- PvPService + CombatService + SkillService + DamageWindow on dev2_combat_world.luau (bareWorld, its PvPService double
-- swapped for the real one; every zone there is a PvP zone) and the real PvPService + CombatService + KaijuService +
-- RankingService on dev2_world.luau (rankWorld). Bodies face -Z.

local KJ = C0.Kaiju
if not vmt.__unm then vmt.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end end -- the hop goes back (-facing)

local function hp(p) return p.Character:FindFirstChild("Humanoid").Health end

local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6 end

local function face(p, dir)
	p.Character:FindFirstChild("HumanoidRootPart").CFrame = { LookVector = dir }
end

-- the combat world with the REAL PvPService (Z / X / PvPZX on, the SKL-2 unlocks Q Lv1 / Z Lv5 / X Lv8)
local function fightWorld(o)
	o = o or {}
	local w = bareWorld({})
	local K = w.Config.Skills
	K.ZEnabled, K.XEnabled, K.PvPZX = true, true, true
	K.Unlock = { Q = 1, Z = 5, X = 8 }
	if o.Friends then w.Friends = o.Friends end
	if o.FriendError then w.FriendError = o.FriendError end
	local reg = w.Registry
	reg.JusticeService.GetBullyStacks = function() return 0 end
	local pvp = w:Load("PvPService", PVP_SOURCE)
	reg.PvPService = pvp
	pvp.Init(reg)
	w.PvP = pvp
	w.Hurt = {} -- every CombatService.PlayerDamaged { V, N, A }
	w.Combat.PlayerDamaged:Connect(function(v, n, a) table.insert(w.Hurt, { V = v, N = n, A = a }) end)
	-- a ready Lv20 fighter (past the rookie shield) with the class weapon and MP; jo as w:Join
	function w:Fighter(id, faction, jo)
		jo = jo or {}
		jo.Faction, jo.Class = faction, jo.Class or "Warrior"
		jo.Level, jo.Tier, jo.Mask = jo.Level or 20, 1, 1
		jo.Data = jo.Data or {}
		jo.Data.PlaytimeSeconds = jo.Data.PlaytimeSeconds or 99999
		jo.Attrs = jo.Attrs or {}
		jo.Attrs.Mana = 200
		return self:Join(id, jo)
	end
	-- PlayerService's leave: PlayerLeaving while still ready, then gone
	function w:Leave(p)
		self.PS.PlayerLeaving:Fire(p, self.Data[p])
		self.Ready[p] = nil
		self:Remove(p)
		self:Flush()
	end
	function w:Use(p, slot)
		self:Advance(0.11) -- RateLimits.UseSkill
		self.Net.Get("UseSkill").OnServerEvent:Fire(p, slot)
		self:Flush()
	end
	function w:Swing(p)
		self:Advance(1.1) -- past the swing interval
		self.Combat.Swing(p, true)
		self:Flush()
	end
	function w:HurtOf(v)
		local n = 0
		for _, h in self.Hurt do if h.V == v then n += 1 end end
		return n
	end
	return w
end

-- A (101, Halo) at the origin, the friend B (202, Horns) and the stranger C (303, Horns) in front; answers arrived
local function trio(o)
	o = o or {}
	local w = fightWorld({ Friends = { ["101:202"] = true } })
	local a = w:Fighter(101, "Halo", { Class = o.Class })
	local b = w:Fighter(202, "Horns", { Pos = o.BPos or vec(0, 0, -4) })
	local c = w:Fighter(303, "Horns", { Pos = o.CPos or vec(2, 0, -4) })
	w:RunSpawned()
	return w, a, b, c
end

------------------------------------------------------------------ 1. the friend cache (PvPService)
runGroup("friend cache", function()
	local w = fightWorld({ Friends = { ["101:202"] = true } })
	local a = w:Fighter(101, "Halo")
	local b = w:Fighter(202, "Horns", { Pos = vec(0, 0, -4) })
	check(w.FriendCalls == 0, "the join only queues the friend check (no web call inside PlayerReady)", w.FriendCalls)
	check(w.PvP.AreFriends(a, b) == false and w.PvP.CanAttack(a, b) == true,
		"before the answer the pair is NOT friends (CanAttack allows the hit)", show({ w.PvP.AreFriends(a, b), w.PvP.CanAttack(a, b) }))
	w:RunSpawned()
	check(w.FriendCalls == 1, "the background job asks IsFriendsWith once for the pair", w.FriendCalls)
	check(w.PvP.AreFriends(a, b) == true and w.PvP.AreFriends(b, a) == true, "A then B: the pair is cached both ways")
	local ok, why = w.PvP.CanAttack(a, b)
	local ok2, why2 = w.PvP.CanAttack(b, a)
	check(ok == false and why == "Friend" and ok2 == false and why2 == "Friend", "CanAttack: false, 'Friend' both ways",
		show({ ok, why, ok2, why2 }))
	for _ = 1, 10 do w.PvP.AreFriends(a, b) end
	check(w.FriendCalls == 1, "AreFriends reads the cache only (never asks Roblox)", w.FriendCalls)
	check(w.PvP.AreFriends(a, a) == false and w.PvP.AreFriends(a, nil) == false and w.PvP.AreFriends(nil, b) == false
		and w.PvP.AreFriends(a, newInstance("Folder", w)) == false, "AreFriends: self / nil / not a player = false")
	-- a stranger joins: only the new pairs are asked; one call per pair
	local c = w:Fighter(303, "Horns", { Pos = vec(2, 0, -4) })
	w:RunSpawned()
	check(w.FriendCalls == 3 and w.PvP.AreFriends(a, c) == false and w.PvP.AreFriends(b, c) == false
		and w.PvP.CanAttack(a, c) == true, "a third player: 2 new calls (A:C, B:C), not friends, A may hit C",
		show({ w.FriendCalls, w.PvP.CanAttack(a, c) }))
	w.PS.PlayerReady:Fire(c, w.Data[c]) -- a second PlayerReady for the same player
	w:RunSpawned()
	check(w.FriendCalls == 3, "a known pair is never asked again (one call per pair)", w.FriendCalls)
	-- same faction / Neutral keep their own reasons
	local d = w:Fighter(404, "Halo", { Pos = vec(0, 0, 4) })
	local n = w:Fighter(505, "Neutral", { Pos = vec(0, 0, 6) })
	w.Friends["101:404"], w.Friends["101:505"] = true, true
	w:RunSpawned()
	local okD, whyD = w.PvP.CanAttack(a, d)
	local okN, whyN = w.PvP.CanAttack(a, n)
	local okS, whyS = w.PvP.CanAttack(a, a)
	check(w.PvP.AreFriends(a, d) and okD == false and whyD == "SameFaction" and okN == false and whyN == "Neutral"
		and okS == false and whyS == "Self", "a same-side friend stays 'SameFaction', a Neutral friend 'Neutral', self 'Self'",
		show({ whyD, whyN, whyS }))

	-- B joins first, then A: the same pair, the same answer
	local w2 = fightWorld({ Friends = { ["101:202"] = true } })
	local b2 = w2:Fighter(202, "Horns")
	local a2 = w2:Fighter(101, "Halo")
	w2:RunSpawned()
	check(w2.FriendCalls == 1 and w2.PvP.AreFriends(a2, b2) == true and w2.PvP.AreFriends(b2, a2) == true,
		"B then A: one call, cached both ways (join order does not matter)", w2.FriendCalls)
	check(select(2, w2.PvP.CanAttack(b2, a2)) == "Friend", "B then A: CanAttack 'Friend'")
end)

------------------------------------------------------------------ 2. a failed call
runGroup("failed call", function()
	local w = fightWorld({ Friends = { ["101:202"] = true }, FriendError = { ["101:202"] = true } })
	local a = w:Fighter(101, "Halo")
	local b = w:Fighter(202, "Horns", { Pos = vec(0, 0, -4) })
	w:RunSpawned()
	check(w.FriendCalls == 1 and w.PvP.AreFriends(a, b) == false and w.PvP.CanAttack(a, b) == true,
		"IsFriendsWith threw: NOT friends (pcall; the hit is allowed)", show({ w.FriendCalls, w.PvP.AreFriends(a, b) }))
	w.FriendError = {} -- Roblox would answer "friends" now
	w.PS.PlayerReady:Fire(b, w.Data[b]) -- B's join runs again: the failed pair is the only one it could ask
	w:RunSpawned()
	check(w.FriendCalls == 1 and w.PvP.AreFriends(a, b) == false,
		"the failed answer is stored (not friends): not asked again while both stay", show({ w.FriendCalls, w.PvP.AreFriends(a, b) }))
	w:Swing(a)
	check(hp(b) < 100, "…so A's swing hits B", hp(b))
	check(#w.Warnings == 0, "a failed friend call is silent (no warning)", w.Warnings[1])
end)

------------------------------------------------------------------ 3. leaving and rejoining
runGroup("leave and rejoin", function()
	-- the higher id leaves; they stop being friends meanwhile; the rejoin asks again
	local w = fightWorld({ Friends = { ["101:202"] = true } })
	local a = w:Fighter(101, "Halo")
	local b = w:Fighter(202, "Horns", { Pos = vec(0, 0, -4) })
	w:RunSpawned()
	check(w.PvP.AreFriends(a, b) == true, "setup: friends")
	w:Leave(b)
	w.Friends["101:202"] = nil
	local b2 = w:Fighter(202, "Horns", { Pos = vec(0, 0, -4) })
	check(w.PvP.AreFriends(a, b2) == false, "after B left, the old answer is gone (the rejoin is not friends before its answer)")
	w:RunSpawned()
	check(w.FriendCalls == 2 and w.PvP.AreFriends(a, b2) == false and w.PvP.CanAttack(a, b2) == true,
		"B's rejoin asks again (2 calls) and gets the new answer", show({ w.FriendCalls, w.PvP.AreFriends(a, b2) }))
	-- the lower id leaves; they became friends meanwhile
	w.Friends["101:202"] = true
	w:Leave(a)
	local a2 = w:Fighter(101, "Halo")
	w:RunSpawned()
	check(w.FriendCalls == 3 and w.PvP.AreFriends(a2, b2) == true, "A's rejoin asks again too (the lower id of the pair)",
		show({ w.FriendCalls, w.PvP.AreFriends(a2, b2) }))
	-- a leave while the call is still in flight: its late answer is thrown away
	local w3 = fightWorld({ Friends = { ["101:202"] = true } })
	local a3 = w3:Fighter(101, "Halo")
	local b3 = w3:Fighter(202, "Horns", { Pos = vec(0, 0, -4) })
	local plain = b3.IsFriendsWith
	b3.IsFriendsWith = function(self, otherId)
		w3:Leave(a3) -- A leaves while Roblox answers
		w3.Friends["101:202"] = nil
		return plain(self, otherId) or true -- the answer of the moment A was still here
	end
	w3:RunSpawned()
	b3.IsFriendsWith = plain
	local a4 = w3:Fighter(101, "Halo")
	w3:RunSpawned()
	check(w3.FriendCalls == 2 and w3.PvP.AreFriends(a4, b3) == false,
		"a leave during the call: the late answer is dropped, the rejoin asks again", show({ w3.FriendCalls, w3.PvP.AreFriends(a4, b3) }))
end)

------------------------------------------------------------------ 4. a full server: the calls are spaced
runGroup("spacing", function()
	local w = fightWorld()
	for i = 1, 6 do w:Fighter(100 + i, i % 2 == 0 and "Halo" or "Horns", { Pos = vec(i * 30, 0, 0) }) end
	w:RunSpawned()
	check(w.FriendCalls == 15, "6 players: 15 pairs, each asked once", w.FriendCalls)
	w:Fighter(200, "Halo", { Pos = vec(0, 0, 300) })
	w:RunSpawned()
	check(w.FriendCalls == 20, "a 7th player: 5 calls at once (Burst)…", w.FriendCalls)
	w:Advance(0.9)
	w:RunSpawned()
	check(w.FriendCalls == 20, "…the 6th not yet…", w.FriendCalls)
	w:Advance(0.2)
	w:RunSpawned()
	check(w.FriendCalls == 21, "…and 1 s later the rest", w.FriendCalls)
end)

-- the newcomer leaves before its later wave: that wave asks nobody (FRIEND.Ask's presence / ready guard)
runGroup("leave before the next wave", function()
	local w = fightWorld()
	local early = {}
	for i = 1, 6 do table.insert(early, (w:Fighter(100 + i, i % 2 == 0 and "Halo" or "Horns", { Pos = vec(i * 30, 0, 0) }))) end
	w:RunSpawned()
	local n = w:Fighter(200, "Halo", { Pos = vec(0, 0, 300) })
	w:RunSpawned()
	check(w.FriendCalls == 20, "setup: the newcomer's first wave = 5 calls, the 6th pair waits 1 s", w.FriendCalls)
	local last = early[6] -- 106: the pair of the later wave
	w.Friends["106:200"] = true
	w:Leave(n) -- before the later wave
	w:Advance(1.1)
	w:RunSpawned()
	check(w.FriendCalls == 20, "the later wave after the newcomer left: no call (nobody asks for a leaver)", w.FriendCalls)
	w.Friends["106:200"] = nil
	local n2 = w:Fighter(200, "Halo", { Pos = vec(0, 0, 300) })
	check(w.PvP.AreFriends(last, n2) == false, "no stale answer is left for the rejoin (before its own answers)")
	w:RunSpawned()
	w:Advance(1.1)
	w:RunSpawned()
	local friends = 0
	for _, p in early do if w.PvP.AreFriends(p, n2) then friends += 1 end end
	check(w.FriendCalls == 26 and friends == 0, "the rejoin asks all 6 pairs fresh (none are friends now)",
		show({ w.FriendCalls, friends }))
end)

------------------------------------------------------------------ 5. manual swings
runGroup("swing", function()
	local w, a, b, c = trio()
	local f0 = #w.Fx
	w:Swing(a)
	check(hp(b) == 100 and hp(c) < 100, "A's swing in a PvP area: the friend B takes 0, the stranger C is hit (as before)",
		show({ hp(b), hp(c) }))
	local sw = w:FxOf("Swing", f0)[1]
	local hitB = false
	for _, h in (sw and sw.Data.Hits) or {} do if h.V == b.UserId then hitB = true end end
	check(sw ~= nil and not hitB, "the Swing Fx carries no hit number on the friend")
	check(w.Combat.IsInCombat(b) == false and w.Combat.GetLastPvPAttacker(b) == nil and w:HurtOf(b) == 0,
		"the friend is not combat-tagged, no KO credit, no PlayerDamaged", show({ w.Combat.IsInCombat(b), w:HurtOf(b) }))
	-- the other way round (B faces A)
	face(b, vec(0, 0, 1))
	w:Swing(b)
	check(hp(a) == 100, "B's swing at A: 0 (Horns -> Halo friend)", hp(a))
	-- the answer has not arrived yet: the hit lands
	local w2 = fightWorld({ Friends = { ["101:202"] = true } })
	local a2 = w2:Fighter(101, "Halo")
	local b2 = w2:Fighter(202, "Horns", { Pos = vec(0, 0, -4) })
	w2:Swing(a2)
	local before = hp(b2)
	check(before < 100, "before the friend answer arrives the swing hits (not friends yet)", before)
	w2:RunSpawned()
	w2:Swing(a2)
	check(hp(b2) == before, "after the answer the next swing deals 0", show({ before, hp(b2) }))
	-- strangers: unchanged
	local w3 = fightWorld()
	local a3 = w3:Fighter(101, "Halo")
	local b3 = w3:Fighter(202, "Horns", { Pos = vec(0, 0, -4) })
	w3:RunSpawned()
	w3:Swing(a3)
	check(hp(b3) < 100 and w3.Combat.GetLastPvPAttacker(b3) == a3, "not friends: the swing hits and credits A as before", hp(b3))
end)

------------------------------------------------------------------ 6. the class skills
runGroup("skills", function()
	-- Q (Warrior: a circle around me)
	local w, a, b, c = trio()
	w:Use(a, "Q")
	check(hp(b) == 100 and hp(c) < 100, "Q: the friend 0, the stranger hit", show({ hp(b), hp(c) }))
	-- Z (Warrior: Earth Cleave line)
	local wz, az, bz, cz = trio()
	wz:Use(az, "Z")
	check(hp(bz) == 100 and hp(cz) < 100, "Z (line): the friend 0, the stranger hit", show({ hp(bz), hp(cz) }))
	-- Z (Mage: chain) - the chain never starts on or jumps to the friend
	local wc, ac, bc, cc = trio({ Class = "Mage", BPos = vec(0, 0, -6), CPos = vec(0, 0, -12) })
	wc:Use(ac, "Z")
	check(hp(bc) == 100 and hp(cc) < 100, "Z (chain): the friend 0, the stranger hit", show({ hp(bc), hp(cc) }))
	-- X (Warrior: roar)
	local wx, ax, bx, cx = trio()
	wx:Use(ax, "X")
	check(hp(bx) == 100 and hp(cx) < 100, "X (roar): the friend 0, the stranger hit", show({ hp(bx), hp(cx) }))
	-- X (Archer: hop, the wind where I stood)
	local wh, ah, bh, ch = trio({ Class = "Archer" })
	wh:Use(ah, "X")
	check(hp(bh) == 100 and hp(ch) < 100, "X (hop wind): the friend 0, the stranger hit", show({ hp(bh), hp(ch) }))
	-- X (Mage: field) - its ticks hit monsters only, a friend inside takes nothing
	local wf, af, bf, cf = trio({ Class = "Mage", BPos = vec(0, 0, -20), CPos = vec(3, 0, -20) })
	local slime = wf:Monster("Slime", 20, 0, 99999)
	wf:Use(af, "X")
	for _ = 1, 4 do wf:Advance(1) end
	check(hp(bf) == 100 and hp(cf) == 100 and wf:Dealt(slime) > 0 and #wf:FxOf("SkillTick", 0) >= 4,
		"X (field) ticks: the friend inside 0 (players never), the slime is hit every tick", show({ hp(bf), wf:Dealt(slime) }))
end)

------------------------------------------------------------------ 7. the last gate: CombatService.DamagePlayer
runGroup("final gate", function()
	local w, a, b, c = trio()
	local n0 = #w.Hurt
	check(w.Combat.DamagePlayer(b, 1000, a) == 0 and hp(b) == 100 and #w.Hurt == n0,
		"DamagePlayer(friend, 1000, A) = 0: no damage, no KO, no PlayerDamaged", show({ hp(b), #w.Hurt - n0 }))
	check(w.Combat.IsInCombat(a) == false and w.Combat.GetLastPvPAttacker(b) == nil, "…and no combat tag on either side")
	check(w.Combat.DamagePlayer(a, 1000, b, true) == 0 and hp(a) == 100, "the other way (a crit) = 0 too")
	check(w.Combat.DamagePlayer(c, 10, a) == 10 and hp(c) == 90, "a stranger still takes the hit", hp(c))
	check(w.Combat.DamagePlayer(b, 10, nil, false, "Slime") == 10 and hp(b) == 90, "a monster's hit on the friend still lands",
		hp(b))
end)

------------------------------------------------------------------ 8. the kaiju (CanAttack's exception)
runGroup("kaiju exception", function()
	local w = fightWorld({ Friends = { ["101:202"] = true } })
	local a = w:Fighter(101, "Halo", { Level = 3 }) -- a rookie: only the kaiju exception lets them hit
	local k = w:Fighter(202, "Horns", { Pos = vec(0, 0, -4) })
	local d = w:Fighter(303, "Halo", { Level = 3, Pos = vec(2, 0, 0) })
	w:RunSpawned()
	w.KaijuOf[k] = "Active"
	local okA, whyA = w.PvP.CanAttack(a, k)
	check(w.PvP.CanAttack(d, k) == true and okA == false and whyA == "Friend",
		"a Halo stranger may hit the Active kaiju (exception); its Halo friend may not ('Friend' wins)", show({ okA, whyA }))
	local okK, whyK = w.PvP.CanAttack(k, a)
	check(okK == false and whyK == "Friend", "the kaiju never hits its friend either", show({ okK, whyK }))
	face(k, vec(0, 0, 1))
	w:Swing(k)
	check(hp(a) == 100, "the kaiju's swing: its friend takes 0", hp(a))
end)

------------------------------------------------------------------ 9. the kaiju's stomp and HP (the real KaijuService)
runGroup("kaiju stomp", function()
	local w = rankWorld({ Kaiju = true, Friends = { ["101:201"] = true } })
	w.AllowWarn = { "missing", "zoom" }
	local ws = w:Env().workspace
	ws.Raycast = function() return nil end
	ws.FindFirstChild = function() return nil end
	local k = w:Join(201, "Horns")
	k.CameraMaxZoomDistance = 30
	local f = w:Join(101, "Halo")
	local e = w:Join(102, "Halo")
	w:RunSpawned()
	check(w.PvP.AreFriends(k, f) == true and w.PvP.AreFriends(k, e) == false, "setup: F is the kaiju's friend, E is not")
	w.PvP.DebugSetStars(k, KJ.StarsNeeded)
	w:KaijuTick()
	w:KaijuTick(KJ.SirenSeconds)
	local K = w.Registry.KaijuService
	check(K.GetState(k) == "Active", "the kaiju is active", K.GetState(k))
	check(near(K.GetHealthMult(k), KJ.HPMult * (1 + KJ.HPPerNearbyHalo)),
		"the kaiju's HP counts E only (its friend F cannot fight it)", show({ K.GetHealthMult(k), KJ.HPMult }))
	local f0 = #w.Fx
	w:KaijuTick(KJ.StompInterval)
	local dmg = w.Util.RoundDamage(100 * KJ.StompPct)
	local stomps = 0
	for i = f0 + 1, #w.Fx do if w.Fx[i].Kind == "Stomp" then stomps += 1 end end
	check(stomps == 1 and dmg > 0, "setup: the kaiju stomped once", stomps)
	check(hp(f) == 100 and hp(e) == 100 - dmg, "a stomp in a PvP zone: the friend 0, the stranger the stomp",
		show({ hp(f), hp(e), dmg }))
	check(w.Combat.GetLastPvPAttacker(e) == k and w.Combat.GetLastPvPAttacker(f) == nil, "the stranger's stomp credits the kaiju; the friend's nothing")
	w.PvPZone = false -- outside PvP zones the stomp passes no attacker (environmental): the stomp itself skips friends
	w:KaijuTick(KJ.StompInterval)
	check(hp(f) == 100 and hp(e) == 100 - 2 * dmg, "a stomp outside PvP zones: the friend 0 (no attacker passed), the stranger hit",
		show({ hp(f), hp(e) }))
end)

-- the ONLY Halo player near the Active kaiju is its friend: the event is never contested (stomp / HP count), so the kaiju
-- survives with the uncontested line and no minted bonus. Control: the same with a stranger is contested.
runGroup("kaiju friend never contests", function()
	local function survive(friendly)
		local w = rankWorld({ Kaiju = true, Friends = friendly and { ["101:201"] = true } or {} })
		w.AllowWarn = { "missing", "zoom" }
		local ws = w:Env().workspace
		ws.Raycast = function() return nil end
		ws.FindFirstChild = function() return nil end
		local k = w:Join(201, "Horns", { Carried = 1000 })
		k.CameraMaxZoomDistance = 30
		local h = w:Join(101, "Halo")
		w:RunSpawned()
		w.PvP.DebugSetStars(k, KJ.StarsNeeded)
		w:KaijuTick()
		w:KaijuTick(KJ.SirenSeconds)
		local K = w.Registry.KaijuService
		local out = { Active = K.GetState(k) == "Active", Mult = K.GetHealthMult(k), Friends = w.PvP.AreFriends(k, h) }
		local f0 = #w.Fx
		w:KaijuTick(KJ.StompInterval)
		out.Stomps = 0
		for i = f0 + 1, #w.Fx do if w.Fx[i].Kind == "Stomp" then out.Stomps += 1 end end
		out.HP = hp(h)
		local n0, g0 = #w.Notices, #w.Gold
		w:KaijuTick(KJ.Duration)
		out.Bonus, out.Bank = 0, 0
		for i = g0 + 1, #w.Gold do
			local g = w.Gold[i]
			if g.P == k and g.Src == "KaijuBonus" then out.Bonus += g.N end
			if g.P == k and g.Src == "KaijuBank" then out.Bank += g.N end
		end
		for _, t in w:NoticesFor(k, n0) do if has(t, "Survived!") then out.Line = t end end
		return out
	end
	local f = survive(true)
	check(f.Active and f.Friends and near(f.Mult, KJ.HPMult), "only its friend near: the kaiju's HP has no Halo bonus (x HPMult)",
		show({ f.Mult, KJ.HPMult }))
	check(f.Stomps == 1 and f.HP == 100, "the stomp spares the friend", show({ f.Stomps, f.HP }))
	check(f.Line ~= nil and has(f.Line, "Survived! +1K gold") and f.Bonus == 0 and f.Bank == 1000,
		"it survives uncontested: the 'Survived! +1K gold' line (A23-130: one short line), the pouch banked, no minted bonus", show(f))
	local s = survive(false)
	check(s.Active and not s.Friends and near(s.Mult, KJ.HPMult * (1 + KJ.HPPerNearbyHalo)) and s.HP < 100,
		"control, a stranger near: HP bonus and stomped", show({ s.Mult, s.HP }))
	check(s.Line ~= nil and has(s.Line, "Survived!") and s.Bonus > 0,
		"control: contested, the bonus is minted", show(s))
end)

------------------------------------------------------------------ 10. rankings: exactly as before
runGroup("ranking unchanged", function()
	local w, k, v = duel({ Friends = { ["101:202"] = true } })
	check(w.JoinFriendCalls == 1 and w.PvP.AreFriends(k, v) == true, "duel setup: PvPService asked once at the join",
		w.JoinFriendCalls)
	check(w:Hit(v, k, 10) == 0 and hp(v) == 100 and w.FriendCalls == 0, "a friend's hit = 0 (and RankingService is not asked by it)",
		show({ hp(v), w.FriendCalls }))
	check(select(2, w.PvP.CanAttack(k, v)) == "Friend", "CanAttack 'Friend' in the ranking world too")
	w:KO(v, k)
	check(w.Data[k].Honor == 1 and w:Rank(k).Honor == 0 and w:Rank(k).PvP == 0 and refused(w, "Friend") == 1,
		"a friend KO (HandleKO): the stat only, no board, reason Friend (as before)", show(w:Rank(k)))
	-- a failed call: PvP says NOT friends (the hit lands), the boards still say friends (no points) - the two rules stay apart
	local w2, k2, v2 = duel({ FriendError = { ["101:202"] = true } })
	check(w2.PvP.AreFriends(k2, v2) == false and w2:Hit(v2, k2, 10) == 10, "IsFriendsWith failed: PvP not friends, the hit lands",
		hp(v2))
	w2:KO(v2, k2)
	check(w2:Rank(k2).Honor == 0 and w2:Rank(k2).PvP == 0 and refused(w2, "Friend") == 1,
		"…but the ranking still counts the failed pair as friends (no board points, its own rule)", show(w2:Rank(k2)))
	local calls = w2.FriendCalls
	local verdict = w2.Ranking.JudgeKO(k2, v2, { Bold = 1 }) -- a judge that may ask Roblox itself (no NoYield)
	check(w2.FriendCalls == calls + 1 and verdict.Fair == false and verdict.Reason == "Friend",
		"RankingService's own call fails again: still friends for the boards (never cached)", show({ verdict, w2.FriendCalls - calls }))
	-- strangers: a fair KO as before
	local w3, k3, v3 = duel()
	check(w3:Hit(v3, k3, 10) == 10, "strangers: the hit lands")
	w3:KO(v3, k3)
	check(w3:Rank(k3).Honor == 1 and refused(w3, "Friend") == 0, "strangers: a fair KO reaches the weekly Honor board", show(w3:Rank(k3)))
end)

finish()
