-- CraftService.luau : artisan crafting (게임성 개발 3, 2026-10-12; contract docs/design/craft_server_2026-10-12.md, 게임성
-- 검수 OK 10/12; the hammer screen = 게임성 개발 4's hammer_minigame_2026-10-12.md). Only artisans (faction Neutral) craft,
-- each only the recipes of their role (Config.Craft.Roles: Warrior = Smith, Mage = Alch, Archer = Tame). Never fails,
-- never loses materials (A23-56); no waiting timer. Switched by Config.Features.Crafting (off).
--   * CraftStart(recipeId): switch, a known recipe whose materials all exist, alive + class + Neutral + the recipe's role,
--     no open session, StartsPerMinute, auto combat off, within Range of the role's workbench, craft level, materials,
--     gold, room for the result. Then the gold and materials go at once and data.Craft.Pend = { Id, Plus = -1, Gold, Mats }
--     (what was paid; a stop in between finishes the craft on the next join at its +N, or at +0 if never hammered; a
--     recipe gone by then pays it all back) -> s->c CraftSession { Id, Recipe, Strikes, Ring, Rest, StartAt }.
--   * The hammer = Shared/CraftMini (fixed ring schedule): CraftStrike(id, i, ms) on a press notes { Ms, At = server
--     time } once per ring; CraftFinish(id) grades them with CraftMini.Accept (a strike whose arrival does not fit its
--     claimed offset, or one that never came, is a Miss). Five equal offsets = +0. No Finish by StartAt +
--     CraftMini.T.Timeout, a leave or a KO = +0.
--   * The end: the result goes in (Weapon -> LootService.AddSpare, Gear -> data.Gear.Own, Item -> LootService.GrantItems,
--     Pet (⑤ a tamer's summon: TamerService research points first) -> PetService.SummonPet with Roll.Spd = a random whole
--     % in the recipe's Spd + the hammer's +N, at most Config.SaveV4.PetRollSpd[2]; then TamerService.AddSummon),
--     craft XP for the role (levels up while it can, at most MaxLv), Craft.Made[id] + 1, Pend cleared -> s->c CraftResult
--     + CraftInfo, signal Crafted(player, recipeId, plus).
--   * ⑦ fame (docs/design/artisan_fame_2026-10-12.md): an artisan of the recipe's role gets Config.CraftFame -> data.Craft.Rep
--     (lifetime) + RankingService.Credit "Artisan" (the weekly board); the attribute ArtisanRank (Config.ArtisanRank, 0 =
--     not an artisan now) at PlayerReady, after a craft and after a class / faction change; a new rank says so once
--     (key Config.Craft.Text.RankUp) and fires RankUp(player, rank).
-- Notices are keys only (Config.Craft.Text, Net.NotifyKey). Nothing here is sold.
--   CraftService.TryStart(player, id) / Strike(player, sid, i, ms) / Finish(player, sid) -> "ok" | reason (the remote
--   handlers; public for the offline test) · RecipeOn(id) · Session(player) · Settle(player, data) (a waiting craft)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local CraftMini = require(Shared:WaitForChild("CraftMini")) -- the hammer's numbers and rules (게임성 개발 4, shared with the screen)

local CraftService = {}
CraftService.Crafted = Util.Signal.new() -- (player, recipeId, plus)
CraftService.RankUp = Util.Signal.new() -- (player, rank) ⑦

local TAG = "CraftService"
local S = nil
local ST = {
	Open = {}, -- [Player] = { Id, Recipe, StartAt, Strikes = { [i] = server time }, Done = true? }
	Starts = {}, -- [Player] = { os.clock() of the recent starts } (StartsPerMinute)
	Serial = 0,
	Prompts = {}, -- [ProximityPrompt] = the workbench's role (the "Craft" prompts this service made)
	GearSum = 60, -- Gear.Own holds at most this many things in all (the save v4 agreement; per key: Config.SaveV4.OwnKeyMax)
	Rng = Random.new(), -- a summon's random walk bonus (never Robux, A23-115)
}

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function K()
	return Config.Craft
end

local function on()
	return Config.FeatureOn("Crafting") and type(Config.Craft) == "table"
end

local function getData(player)
	local ok, data = pcall(S.PlayerService.GetData, player)
	return ok and type(data) == "table" and data or nil
end

local function notify(player, key)
	local ok, err = pcall(Net.NotifyKey, player, "Config.Craft.Text." .. key, nil, "bad")
	if not ok then Util.Warn(TAG, "notice " .. key .. ": " .. tostring(err)) end
end

local function serverNow()
	local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
	return ok and type(t) == "number" and t or os.time()
end

-- the player's round-trip ping in ms (0..1000); CraftMini takes the biggest of the session start's, the strike's and now
local function pingMs(player)
	local ok, p = pcall(function() return player:GetNetworkPing() end)
	return math.clamp((ok and num(p) or 0) * 1000, 0, 1000)
end

local function fire(player, remote, payload)
	local ok, err = pcall(function() Net.Get(remote):FireClient(player, payload) end)
	if not ok then Util.Warn(TAG, remote .. ": " .. tostring(err)) end
end

local function tele(player, name, value, a, b)
	if S.TelemetryService and S.TelemetryService.Custom then pcall(S.TelemetryService.Custom, player, name, value or 1, a, b) end
end

local function roleOf(data)
	if type(data) ~= "table" or data.Faction ~= "Neutral" or data.ClassChosen ~= true then return nil end
	return K().Roles[data.Class]
end

local function craftOf(data)
	if type(data.Craft) ~= "table" then data.Craft = Config.SanitizeCraft(data.Craft) end
	local c = data.Craft
	if type(c.Made) ~= "table" then c.Made = {} end
	return c
end

local function roleRec(c, role)
	local r = c[role]
	if type(r) ~= "table" then
		r = { Lv = 1, XP = 0 }
		c[role] = r
	end
	r.Lv = math.clamp(math.floor(num(r.Lv, 1)), 1, K().MaxLv)
	r.XP = math.max(0, math.floor(num(r.XP)))
	return r
end

------------------------------------------------------------------ recipes
-- a recipe that can be made at all: every material is a known item, the result has a place to go
function CraftService.RecipeOn(id)
	local r = type(id) == "string" and K().Recipes[id] or nil
	if type(r) ~= "table" or type(r.Mats) ~= "table" then return nil end
	for item in r.Mats do
		if not Config.Loot.Items[item] then return nil end
	end
	if r.Kind == "Weapon" then
		local L = S and S.LootService
		if not (L and type(L.AddSpare) == "function" and type(L.SpareRoom) == "function" and Config.Weapons[r.Tier]) then return nil end
	elseif r.Kind == "Gear" then
		-- ⑥ gear recipes wait for Config.Features.Gear (nothing to wear them with before it: GearService)
		if not Config.FeatureOn("Gear") or type(r.Slot) ~= "string" or type(r.Tier) ~= "number" then return nil end
	elseif r.Kind == "Item" then
		if not Config.Loot.Items[r.Item] then return nil end
	elseif r.Kind == "Pet" then
		-- ⑤ a summon needs the research switch, a known species and both services' calls
		local P, T = S and S.PetService, S and S.TamerService
		if not (Config.FeatureOn("Research") and type(r.Species) == "string" and type(Config.Pets.Species[r.Species]) == "table"
			and type(r.Family) == "string" and type(r.Spd) == "table" and P and type(P.SummonPet) == "function"
			and type(P.HasRoom) == "function" and T and type(T.Points) == "function") then
			return nil
		end
	else
		return nil
	end
	return r
end

local function hasMats(data, r)
	local items = type(data.Items) == "table" and data.Items or {}
	for item, n in r.Mats do
		if math.floor(num(items[item])) < n then return false end
	end
	return true
end

local function gearKey(r, plus)
	return string.format("%s:%d:%d", r.Slot, r.Tier, plus)
end

-- room for the result at any +N (0..2), checked before anything is taken
local function room(player, data, r)
	if r.Kind == "Weapon" then
		for plus = 0, 2 do
			local ok, yes = pcall(S.LootService.SpareRoom, player, r.Tier, plus)
			if not ok or yes ~= true then return false end
		end
		return true
	elseif r.Kind == "Gear" then
		local own = type(data.Gear) == "table" and type(data.Gear.Own) == "table" and data.Gear.Own or {}
		local sum = 0
		for _, n in own do sum += math.floor(num(n)) end
		if sum >= ST.GearSum then return false end
		for plus = 0, 2 do
			if math.floor(num(own[gearKey(r, plus)])) >= Config.SaveV4.OwnKeyMax then return false end
		end
		return true
	elseif r.Kind == "Pet" then
		local ok, yes = pcall(S.PetService.HasRoom, player)
		return ok and yes == true
	end
	local have = type(data.Items) == "table" and math.floor(num(data.Items[r.Item])) or 0
	return have + math.max(1, math.floor(num(r.N, 1))) + 2 <= Config.Loot.ItemCap -- N + the best +N (2)
end

-- the result goes in; false = it did not fit (the craft stays pending). A summon also returns { Uid, Species, Spd }
local function payOut(player, data, r, plus)
	if r.Kind == "Pet" then
		local lo = math.floor(num(r.Spd[1], 5))
		local spd = math.min(Config.SaveV4.PetRollSpd[2], ST.Rng:NextInteger(lo, math.max(lo, math.floor(num(r.Spd[2], lo))))
			+ math.max(0, math.floor(num(plus))))
		local ok, uid = pcall(S.PetService.SummonPet, player, r.Species, { Spd = spd })
		if not ok or type(uid) ~= "string" then return false end
		local okS, err = pcall(S.TamerService.AddSummon, player, r.Family)
		if not okS then Util.Warn(TAG, "AddSummon: " .. tostring(err)) end
		return true, { Uid = uid, Species = r.Species, Spd = spd }
	elseif r.Kind == "Weapon" then
		local ok, yes = pcall(S.LootService.AddSpare, player, r.Tier, plus)
		return ok and yes == true
	elseif r.Kind == "Gear" then
		if type(data.Gear) ~= "table" then data.Gear = Config.SanitizeGear(data.Gear) end
		local own = data.Gear.Own
		local key = gearKey(r, plus)
		local sum = 0
		for _, n in own do sum += math.floor(num(n)) end
		-- the caps again at the end (the bag may have filled during the hammer): all of it or nothing
		if sum >= ST.GearSum or math.floor(num(own[key])) >= Config.SaveV4.OwnKeyMax then return false end
		own[key] = math.floor(num(own[key])) + 1
		return true
	end
	local n = math.max(1, math.floor(num(r.N, 1))) + math.max(0, math.floor(num(plus))) -- items: N + the hammer's +N
	local function have()
		return type(data.Items) == "table" and math.floor(num(data.Items[r.Item])) or 0
	end
	local before = have()
	if before + n > Config.Loot.ItemCap then return false end -- never a part of it
	pcall(S.LootService.GrantItems, player, { { Id = r.Item, N = n } }, nil, "Craft")
	return have() - before >= n
end

local function sendInfo(player, data)
	local role = roleOf(data)
	local c = craftOf(data)
	local rank, nextRep = Config.ArtisanRank(c.Rep)
	-- ⑦ the artisan rank every client sees (0 = not an artisan now)
	local okA, errA = pcall(function() player:SetAttribute("ArtisanRank", role and rank or 0) end)
	if not okA then Util.Warn(TAG, "ArtisanRank: " .. tostring(errA)) end
	if not role then return end
	local rr = roleRec(c, role)
	-- On = the recipe ids of my role the server would start now (a recipe waiting for its drops / spares is left out)
	local onIds = {}
	for id, r in K().Recipes do
		if r.Role == role and CraftService.RecipeOn(id) then table.insert(onIds, id) end
	end
	table.sort(onIds)
	fire(player, "CraftInfo", { Role = role, Lv = rr.Lv, XP = rr.XP, Need = Config.CraftXPToNext(rr.Lv), Made = table.clone(c.Made),
		On = onIds, Rep = math.floor(num(c.Rep)), Rank = rank, NextRep = nextRep })
end

-- craft XP for `role`; returns the level now and whether it rose
local function addXP(c, role, xp)
	local rr = roleRec(c, role)
	local before = rr.Lv
	rr.XP += math.max(0, math.floor(num(xp)))
	while rr.Lv < K().MaxLv do
		local need = Config.CraftXPToNext(rr.Lv)
		if need <= 0 or rr.XP < need then break end
		rr.XP -= need
		rr.Lv += 1
	end
	rr.XP = math.min(rr.XP, Config.SaveV4.MaxCount)
	return rr.Lv, rr.Lv > before
end

-- the end of a craft (every path: finish, time-up, leave, KO, a pending one at join). false = the result did not fit
local function complete(player, data, recipeId, plus, grades, sid)
	local r = K().Recipes[recipeId]
	if type(r) ~= "table" then return false end
	local c = craftOf(data)
	-- an earned +N is kept in the save if the result does not fit now (the next try pays that +N, never less)
	if type(c.Pend) == "table" and c.Pend.Id == recipeId then c.Pend.Plus = plus end
	local paid, pet = payOut(player, data, r, plus)
	if not paid then return false end
	c.Pend = nil
	c.Made[recipeId] = math.floor(num(c.Made[recipeId])) + 1
	-- A23-139 (user 10/12 "그래야 공평"): craft XP only for a player who is that artisan now (a pending craft finished after
	-- a side change still pays its item, never the XP), x2 with the 2x XP pass (the same pass check as level XP)
	local xp, fame = 0, 0
	if roleOf(data) == r.Role then
		fame = Config.CraftFame(r, plus) -- ⑦ (never the 2x XP pass)
		local ps = S.ProgressionService
		local okPass, pass = pcall(function() return ps and type(ps.PassMult) == "function" and ps.PassMult(player, "XP2") or 1 end)
		xp = math.floor(num(r.XP) * (okPass and num(pass, 1) or 1))
	end
	local lv, up = addXP(c, r.Role, xp)
	local rank0 = Config.ArtisanRank(c.Rep)
	if fame > 0 then
		c.Rep = math.min(Config.SaveV4.MaxCount, math.floor(num(c.Rep)) + fame)
		local RS = S.RankingService
		if RS and type(RS.Credit) == "function" then
			local okR, errR = pcall(RS.Credit, player, "Artisan", fame, "Craft")
			if not okR then Util.Warn(TAG, "Credit: " .. tostring(errR)) end
		end
	end
	local rank1 = Config.ArtisanRank(c.Rep)
	if rank1 > rank0 and player.Parent == Players then
		local row = K().Ranks[rank1]
		local okN, errN = pcall(Net.NotifyKey, player, "Config.Craft.Text.RankUp", { { Key = "Config.Craft.Text.Ranks." .. row.Id } }, "reward")
		if not okN then Util.Warn(TAG, "rank notice: " .. tostring(errN)) end
		CraftService.RankUp:Fire(player, rank1)
	end
	if S.PlayerService.MarkActive then pcall(S.PlayerService.MarkActive, player) end
	if player.Parent == Players then
		fire(player, "CraftResult", { Id = sid or 0, Recipe = recipeId, Kind = r.Kind, Tier = r.Tier, Slot = r.Slot, Item = r.Item,
			Plus = plus, Grades = grades, XP = xp, Lv = lv, LvUp = up, Pet = pet, Fame = fame })
		sendInfo(player, data)
	end
	CraftService.Crafted:Fire(player, recipeId, plus)
	return true
end

local function misses()
	local out = {}
	for i = 1, CraftMini.T.Strikes do out[i] = "Miss" end
	return out
end

-- a craft paid and not delivered (Craft.Pend): finished at its earned +N (+0 if it was never hammered), or - when the
-- recipe is gone (a later update) - everything paid comes back (A23-56: materials are never lost). Returns "done",
-- "refund", "wait" (the result does not fit yet: it stays) or "none"
function CraftService.Settle(player, data)
	local c = craftOf(data)
	local p = c.Pend
	if type(p) ~= "table" then return "none" end
	if type(K().Recipes[p.Id]) ~= "table" then
		c.Pend = nil
		local gold = math.floor(num(p.Gold))
		if gold > 0 then pcall(S.ProgressionService.AddBankGold, player, gold, "CraftRefund") end
		local list = {}
		for item, n in type(p.Mats) == "table" and p.Mats or {} do
			local left = math.floor(num(n))
			while Config.Loot.Items[item] and left > 0 do
				table.insert(list, { Id = item, N = math.min(99, left) })
				left -= 99
			end
		end
		if #list > 0 then pcall(S.LootService.GrantItems, player, list, nil, "CraftRefund") end
		tele(player, "CraftRefund", 1)
		return "refund"
	end
	return complete(player, data, p.Id, math.max(0, math.floor(num(p.Plus))), misses(), 0) and "done" or "wait"
end

-- close the open session at +0 (time-up, leave, KO); a result that does not fit stays pending in the save
local function closeAtZero(player, why)
	local sess = ST.Open[player]
	if not sess or sess.Done then return end
	sess.Done = true
	ST.Open[player] = nil
	local data = getData(player)
	if not data then return end
	if not complete(player, data, sess.Recipe, 0, misses(), sess.Id) and player.Parent == Players then notify(player, "Full") end
	tele(player, "CraftClosed_" .. why, 1)
end

------------------------------------------------------------------ the three remotes
function CraftService.TryStart(player, id)
	if not on() then return "off" end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return "state" end
	local r = CraftService.RecipeOn(id)
	if not r then
		-- a known recipe the server keeps off (its drops / the spares are not in yet) says so; an unknown id says nothing
		if type(id) == "string" and type(K().Recipes[id]) == "table" then notify(player, "NotReady") end
		return "recipe"
	end
	local data = getData(player)
	if not data or not Util.IsAlive(player) then return "state" end
	local role = roleOf(data)
	if not role or role ~= r.Role then
		notify(player, "NotArtisan")
		return "role"
	end
	-- a craft paid earlier whose result did not fit (bag full at a join) gets one more try first
	if not ST.Open[player] and type(craftOf(data).Pend) == "table" then CraftService.Settle(player, data) end
	if ST.Open[player] or type(craftOf(data).Pend) == "table" then
		notify(player, "Busy")
		return "busy"
	end
	local now = os.clock()
	local recent = {}
	for _, t in ST.Starts[player] or {} do
		if now - t < 60 then table.insert(recent, t) end
	end
	ST.Starts[player] = recent
	if #recent >= K().StartsPerMinute then
		notify(player, "Busy")
		return "minute"
	end
	if player:GetAttribute("AutoCombatUnlocked") == true and player:GetAttribute("AutoCombatEnabled") == true then
		notify(player, "Auto")
		return "auto"
	end
	local root = Util.GetRoot(player)
	local bench = nil
	for _, part in CollectionService:GetTagged(K().StationTag) do
		if part:IsA("BasePart") and part:GetAttribute("Role") == role then
			if not bench or (root and (part.Position - root.Position).Magnitude < (bench.Position - root.Position).Magnitude) then bench = part end
		end
	end
	if not bench and S.ShopService and type(S.ShopService.Anvil) == "function" then
		local ok, anvil = pcall(S.ShopService.Anvil)
		bench = ok and anvil or nil
	end
	if not root or not bench or (root.Position - bench.Position).Magnitude > K().Range then
		notify(player, "Far")
		return "far"
	end
	local c = craftOf(data)
	if roleRec(c, role).Lv < r.Lv then
		notify(player, "NeedLevel")
		return "level"
	end
	if r.Kind == "Pet" then
		local ok, pts = pcall(S.TamerService.Points, player, r.Family)
		if not ok or num(pts) < num(r.Research) then
			notify(player, "NeedResearch")
			return "research"
		end
	end
	if not hasMats(data, r) then
		notify(player, "NeedMats")
		return "mats"
	end
	if not room(player, data, r) then
		notify(player, "Full")
		return "full"
	end
	-- pay: the gold (SpendGold is the gold check: it takes nothing when short), then the materials (checked above;
	-- nothing yields in between)
	if not S.ProgressionService.SpendGold(player, r.Gold, "Craft") then
		notify(player, "NeedGold")
		return "gold"
	end
	for item, n in r.Mats do
		if not S.LootService.TakeItem(player, item, n) then Util.Warn(TAG, "take " .. item .. " failed after the check") end
	end
	c.Pend = { Id = id, Plus = -1, Gold = r.Gold, Mats = table.clone(r.Mats) }
	table.insert(recent, now)
	ST.Serial += 1
	local T = CraftMini.T
	local sess = { Id = ST.Serial, Recipe = id, StartAt = serverNow() + T.Lead, Strikes = {}, StartPing = pingMs(player) }
	ST.Open[player] = sess
	fire(player, "CraftSession", { Id = sess.Id, Recipe = id, Strikes = T.Strikes, Ring = T.Ring, Rest = T.Rest, StartAt = sess.StartAt })
	task.delay(T.Lead + T.Timeout, function()
		if ST.Open[player] == sess then closeAtZero(player, "Timeout") end
	end)
	return "ok"
end

-- a press: the first strike of ring i is noted with the server's time and the ping then (CraftMini.Accept checks it at
-- the Finish)
function CraftService.Strike(player, sid, i, ms)
	local sess = ST.Open[player]
	if not sess or sess.Id ~= sid or sess.Done then return "session" end
	if type(i) ~= "number" or i ~= math.floor(i) or i < 1 or i > CraftMini.T.Strikes then return "ring" end
	if sess.Strikes[i] then return "again" end
	if type(ms) ~= "number" or ms ~= ms or math.abs(ms) > CraftMini.T.MaxMs then return "ms" end
	sess.Strikes[i] = { Ms = ms, At = serverNow(), Ping = pingMs(player) }
	return "ok"
end

-- the end of the hammer: CraftMini.Accept grades the strikes that came (a missing or a made-up one is a Miss); five
-- equal offsets are not a person (+0). A Finish right away (Skip) = every ring a Miss = +0
function CraftService.Finish(player, sid)
	local sess = ST.Open[player]
	if not sess or sess.Id ~= sid or sess.Done then return "session" end
	sess.Done = true
	ST.Open[player] = nil
	local grades, _, plus = CraftMini.Accept(sess.Strikes, sess.StartAt, pingMs(player), sess.StartPing)
	local claims, mismatch = {}, 0
	for i = 1, CraftMini.T.Strikes do
		local s = sess.Strikes[i]
		if s then
			table.insert(claims, s.Ms)
			if grades[i] == "Miss" and CraftMini.Grade(s.Ms) ~= "Miss" then mismatch += 1 end
		end
	end
	if #claims == CraftMini.T.Strikes then
		local same = true
		for i = 2, #claims do
			if claims[i] ~= claims[1] then same = false end
		end
		if same then
			plus = 0
			tele(player, "CraftBot", 1)
		end
	end
	if mismatch > 0 then tele(player, "CraftMismatch", mismatch) end
	-- 게임성 검수 10/12: how far each strike's arrival sat from its claim (server ms - client ms), to tune CraftMini's window
	-- after the 10/17-20 test: value = the biggest, a = the smallest, b = how many strikes came
	local dMax, dMin, dN = -math.huge, math.huge, 0
	for i = 1, CraftMini.T.Strikes do
		local s = sess.Strikes[i]
		if s then
			local d = (s.At - CraftMini.Target(sess.StartAt, i)) * 1000 - s.Ms
			dMax, dMin, dN = math.max(dMax, d), math.min(dMin, d), dN + 1
		end
	end
	if dN > 0 then tele(player, "CraftStrikeD", math.floor(dMax + 0.5), math.floor(dMin + 0.5), dN) end
	local data = getData(player)
	if not data then return "state" end
	if not complete(player, data, sess.Recipe, plus, grades, sess.Id) then
		notify(player, "Full")
		return "full"
	end
	return "ok"
end

function CraftService.Session(player)
	return ST.Open[player]
end

------------------------------------------------------------------ remotes
local function onStart(player, ...)
	if select("#", ...) ~= 1 then return end
	local id = ...
	if type(id) ~= "string" or #id > 16 then return end
	if not Util.RateLimit(player, "CraftStart", num(Config.RateLimits.CraftStart, 3)) then return end
	CraftService.TryStart(player, id)
end

local function onStrike(player, ...)
	if select("#", ...) ~= 3 then return end
	local sid, i, ms = ...
	if type(sid) ~= "number" then return end
	CraftService.Strike(player, sid, i, ms)
end

local function onFinish(player, ...)
	if select("#", ...) ~= 1 then return end
	local sid = ...
	if type(sid) ~= "number" then return end
	local sess = ST.Open[player]
	if not sess or sess.Id ~= sid then return end -- a stale / wrong id never uses up the limit of the real Finish
	if not Util.RateLimit(player, "CraftFinish", num(Config.RateLimits.CraftFinish, 0.5)) then return end
	CraftService.Finish(player, sid)
end

------------------------------------------------------------------ workbench prompts
-- every part tagged StationTag (attribute Role = Smith | Alch | Tame; WorldKit places them in the guild) gets one "Craft"
-- prompt (ActionKey / ObjectKey: the client writes the words). An artisan of that role opens the craft window
-- (OpenPanel "Craft" + CraftInfo); anyone else hears NotArtisan. The Crossroads anvil keeps Otto's prompt only.
local function addPrompt(part)
	if not on() or typeof(part) ~= "Instance" or not part:IsA("BasePart") or part:FindFirstChild("CraftPrompt") then return end
	local role = part:GetAttribute("Role")
	if type(role) ~= "string" or type(K().Text.Stations[role]) ~= "string" then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CraftPrompt"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = math.min(10, K().Range)
	prompt.RequiresLineOfSight = false
	prompt.ActionText = ""
	prompt.ObjectText = ""
	prompt:SetAttribute("ActionKey", "Config.Craft.Text.Prompt")
	prompt:SetAttribute("ObjectKey", "Config.Craft.Text.Stations." .. role)
	prompt.Parent = part
	ST.Prompts[prompt] = role
end

local function onPrompt(prompt, player)
	local role = ST.Prompts[prompt]
	if not role or not on() then return end
	local data = getData(player)
	if not data or not S.PlayerService.IsReady(player) then return end
	if roleOf(data) ~= role then
		notify(player, "NotArtisan")
		return
	end
	fire(player, "OpenPanel", "Craft")
	sendInfo(player, data)
end

------------------------------------------------------------------ service
function CraftService.Init(registry)
	S = registry
end

local function guard(label, fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then Util.Warn(TAG, label .. ": " .. tostring(err)) end
	end
end

function CraftService.Start()
	Net.Get("CraftStart").OnServerEvent:Connect(guard("CraftStart", onStart))
	Net.Get("CraftStrike").OnServerEvent:Connect(guard("CraftStrike", onStrike))
	Net.Get("CraftFinish").OnServerEvent:Connect(guard("CraftFinish", onFinish))
	ProximityPromptService.PromptTriggered:Connect(guard("prompt", onPrompt))
	for _, part in CollectionService:GetTagged(K().StationTag) do pcall(addPrompt, part) end
	CollectionService:GetInstanceAddedSignal(K().StationTag):Connect(guard("station", addPrompt))
	S.PlayerService.PlayerReady:Connect(guard("ready", function(player, data)
		-- switched off: nothing is read or written (a waiting craft waits for the switch)
		if type(data) ~= "table" or not on() then return end
		if type(data.Craft) == "table" and type(data.Craft.Pend) == "table" and CraftService.Settle(player, data) == "wait" then
			notify(player, "Full")
		end
		sendInfo(player, data)
	end))
	-- ⑦ a class / faction change: the artisan rank attribute (and a new artisan's CraftInfo) follows at once
	for _, pair in { { "ClassService", "ClassChanged" }, { "FactionService", "FactionChanged" } } do
		local sig = S[pair[1]] and S[pair[1]][pair[2]]
		if type(sig) == "table" and type(sig.Connect) == "function" then
			sig:Connect(guard("changed", function(player)
				if not on() then return end
				local data = getData(player)
				if data then sendInfo(player, data) end
			end))
		end
	end
	S.PlayerService.PlayerLeaving:Connect(guard("leave", function(player)
		closeAtZero(player, "Leave")
		ST.Starts[player] = nil
	end))
	if S.PlayerService.CharacterDied then
		S.PlayerService.CharacterDied:Connect(guard("ko", function(player)
			closeAtZero(player, "KO")
		end))
	end
	print("[CraftService] started")
end

return CraftService
