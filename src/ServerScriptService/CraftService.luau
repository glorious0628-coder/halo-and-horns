-- CraftService.luau : artisan crafting (게임성 개발 3, 2026-10-12; contract docs/design/craft_server_2026-10-12.md, 게임성
-- 검수 OK 10/12; the hammer screen = 게임성 개발 4's hammer_minigame_2026-10-12.md). Only artisans (faction Neutral) craft,
-- each only the recipes of their role (Config.Craft.Roles: Warrior = Smith, Mage = Alch, Archer = Tame). Never fails,
-- never loses materials (A23-56); no waiting timer. Switched by Config.Features.Crafting (off).
--   * CraftStart(recipeId): switch, a known recipe whose materials all exist, alive + class + Neutral + the recipe's role,
--     no open session, StartsPerMinute, auto combat off, within Range of the role's workbench, craft level, materials,
--     gold, room for the result. Then the gold and materials go at once and data.Craft.Pend = recipeId (a stop in between
--     finishes the craft at +0 on the next join) -> s->c CraftSession { Id, Recipe, Strikes, Ring, Rest, StartAt }.
--   * CraftStrike(id, i) at every ring end, in order: the server notes its own time. CraftFinish(id, hits): every claimed
--     offset is checked against the server's own timing of that ring (Config.Craft.Hammer TolMs + the ping jitter); a
--     ring the server did not time, or a claim too far off, is a Miss. Five equal claims = +0. Grades / +N:
--     Config.CraftGrade / Config.CraftPlus. No Finish by StartAt + Timeout, a leave or a KO = +0.
--   * The end: the result goes in (Weapon -> LootService.AddSpare, Gear -> data.Gear.Own, Item -> LootService.GrantItems),
--     craft XP for the role (levels up while it can, at most MaxLv), Craft.Made[id] + 1, Pend cleared -> s->c CraftResult
--     + CraftInfo, signal Crafted(player, recipeId, plus).
-- Notices are keys only (Config.Craft.Text, Net.NotifyKey). Nothing here is sold.
--   CraftService.TryStart(player, id) / Strike(player, sid, i) / Finish(player, sid, hits) -> "ok" | reason (the remote
--   handlers; public for the offline test) · RecipeOn(id) · Session(player)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local CraftService = {}
CraftService.Crafted = Util.Signal.new() -- (player, recipeId, plus)

local TAG = "CraftService"
local S = nil
local ST = {
	Open = {}, -- [Player] = { Id, Recipe, StartAt, Strikes = { [i] = server time }, Done = true? }
	Starts = {}, -- [Player] = { os.clock() of the recent starts } (StartsPerMinute)
	Serial = 0,
	GearSum = 60, -- Gear.Own holds at most this many things in all (the save v4 agreement; per key: Config.SaveV4.OwnKeyMax)
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

local function fire(player, remote, payload)
	local ok, err = pcall(function() Net.Get(remote):FireClient(player, payload) end)
	if not ok then Util.Warn(TAG, remote .. ": " .. tostring(err)) end
end

local function tele(player, name, value)
	if S.TelemetryService and S.TelemetryService.Custom then pcall(S.TelemetryService.Custom, player, name, value or 1) end
end

local function roleOf(data)
	if type(data) ~= "table" or data.Faction ~= "Neutral" or data.ClassChosen ~= true then return nil end
	return K().Roles[data.Class]
end

local function craftOf(data)
	if type(data.Craft) ~= "table" then data.Craft = Config.SanitizeCraft(data.Craft) end
	local c = data.Craft
	if type(c.Made) ~= "table" then c.Made = {} end
	if type(c.Pend) ~= "string" then c.Pend = "" end
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
		if type(r.Slot) ~= "string" or type(r.Tier) ~= "number" then return nil end
	elseif r.Kind == "Item" then
		if not Config.Loot.Items[r.Item] then return nil end
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
	end
	local have = type(data.Items) == "table" and math.floor(num(data.Items[r.Item])) or 0
	return have + math.max(1, math.floor(num(r.N, 1))) <= Config.Loot.ItemCap
end

-- the result goes in; false = it did not fit (the craft stays pending)
local function payOut(player, data, r, plus)
	if r.Kind == "Weapon" then
		local ok, yes = pcall(S.LootService.AddSpare, player, r.Tier, plus)
		return ok and yes == true
	elseif r.Kind == "Gear" then
		if type(data.Gear) ~= "table" then data.Gear = Config.SanitizeGear(data.Gear) end
		local own = data.Gear.Own
		local key = gearKey(r, plus)
		own[key] = math.floor(num(own[key])) + 1
		return true
	end
	local ok, gained = pcall(S.LootService.GrantItems, player, { { Id = r.Item, N = math.max(1, math.floor(num(r.N, 1))) } }, nil, "Craft")
	return ok and type(gained) == "table" and #gained > 0
end

local function sendInfo(player, data)
	local role = roleOf(data)
	if not role then return end
	local c = craftOf(data)
	local rr = roleRec(c, role)
	fire(player, "CraftInfo", { Role = role, Lv = rr.Lv, XP = rr.XP, Need = Config.CraftXPToNext(rr.Lv), Made = table.clone(c.Made) })
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
	if not payOut(player, data, r, plus) then return false end
	local c = craftOf(data)
	c.Pend = ""
	c.Made[recipeId] = math.floor(num(c.Made[recipeId])) + 1
	local lv, up = addXP(c, r.Role, r.XP)
	if S.PlayerService.MarkActive then pcall(S.PlayerService.MarkActive, player) end
	if player.Parent == Players then
		fire(player, "CraftResult", { Id = sid or 0, Recipe = recipeId, Kind = r.Kind, Tier = r.Tier, Slot = r.Slot, Item = r.Item,
			Plus = plus, Grades = grades, XP = r.XP, Lv = lv, LvUp = up })
		sendInfo(player, data)
	end
	CraftService.Crafted:Fire(player, recipeId, plus)
	return true
end

local function misses()
	local out = {}
	for i = 1, K().Hammer.Strikes do out[i] = "Miss" end
	return out
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
	local r = CraftService.RecipeOn(id)
	if not r then return "recipe" end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return "state" end
	local data = getData(player)
	if not data or not Util.IsAlive(player) then return "state" end
	local role = roleOf(data)
	if not role or role ~= r.Role then
		notify(player, "NotArtisan")
		return "role"
	end
	-- a craft paid earlier whose result did not fit (bag full at a join) gets one more try first
	local pend = craftOf(data).Pend
	if not ST.Open[player] and pend ~= "" and type(K().Recipes[pend]) == "table" then complete(player, data, pend, 0, misses(), 0) end
	if ST.Open[player] or craftOf(data).Pend ~= "" then
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
	c.Pend = id
	table.insert(recent, now)
	ST.Serial += 1
	local H = K().Hammer
	local sess = { Id = ST.Serial, Recipe = id, StartAt = serverNow() + H.Lead, Strikes = {} }
	ST.Open[player] = sess
	fire(player, "CraftSession", { Id = sess.Id, Recipe = id, Strikes = H.Strikes, Ring = H.Ring, Rest = H.Rest, StartAt = sess.StartAt })
	task.delay(H.Lead + H.Timeout, function()
		if ST.Open[player] == sess then closeAtZero(player, "Timeout") end
	end)
	return "ok"
end

function CraftService.Strike(player, sid, i)
	local sess = ST.Open[player]
	if not sess or sess.Id ~= sid or sess.Done then return "session" end
	local H = K().Hammer
	if i ~= #sess.Strikes + 1 or i > H.Strikes then return "order" end
	local t = serverNow()
	local last = sess.Strikes[i - 1] or (sess.StartAt - H.MinGap)
	if t - last < H.MinGap then return "fast" end
	sess.Strikes[i] = t
	return "ok"
end

local function pingOf(player)
	local ok, p = pcall(function() return player:GetNetworkPing() end)
	return math.clamp(ok and num(p) or 0, 0, 1)
end

-- the server's own timing of ring i in ms (nil = the server did not time it, or the ring before)
local function measured(sess, i, ping)
	local H = K().Hammer
	local t = sess.Strikes[i]
	if not t then return nil end
	if i == 1 then return ((t - ping / 2) - (sess.StartAt + H.Ring)) * 1000 end
	local prev = sess.Strikes[i - 1]
	if not prev then return nil end
	return (t - prev - H.Rest - H.Ring) * 1000
end

function CraftService.Finish(player, sid, hits)
	local sess = ST.Open[player]
	if not sess or sess.Id ~= sid or sess.Done then return "session" end
	local H = K().Hammer
	sess.Done = true
	ST.Open[player] = nil
	local ping = pingOf(player)
	local jitter = math.min(ping * 1000 * 0.5, H.JitterMaxMs)
	local grades, claims, mismatch = {}, {}, 0
	for i = 1, H.Strikes do
		local claim = type(hits) == "table" and hits[i] or nil
		local g = "Miss"
		if type(claim) == "number" then
			table.insert(claims, claim)
			local m = measured(sess, i, ping)
			local tol = H.TolMs + jitter + (i == 1 and ping * 1000 * 0.5 or 0)
			if m and math.abs(claim - m) <= tol then
				g = Config.CraftGrade(claim)
			else
				mismatch += 1
			end
		end
		grades[i] = g
	end
	local plus = Config.CraftPlus(grades)
	if #claims == H.Strikes then
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
	if select("#", ...) ~= 2 then return end
	local sid, i = ...
	if type(sid) ~= "number" or type(i) ~= "number" then return end -- Strike takes only the next whole ring of the open id
	CraftService.Strike(player, sid, i)
end

local function validHits(hits)
	if type(hits) ~= "table" then return nil end
	for k in hits do -- only the keys 1..Strikes (a sixth entry or a named key refuses the whole table)
		if type(k) ~= "number" or k ~= math.floor(k) or k < 1 or k > K().Hammer.Strikes then return nil end
	end
	local out = {}
	for i = 1, K().Hammer.Strikes do
		local v = hits[i]
		out[i] = (type(v) == "number" and v == v and math.abs(v) <= K().Hammer.MaxMs) and v or false
	end
	return out
end

local function onFinish(player, ...)
	if select("#", ...) ~= 2 then return end
	local sid, hits = ...
	if type(sid) ~= "number" or sid ~= sid then return end
	if not Util.RateLimit(player, "CraftFinish", num(Config.RateLimits.CraftFinish, 0.5)) then return end
	CraftService.Finish(player, sid, validHits(hits) or {})
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
	S.PlayerService.PlayerReady:Connect(guard("ready", function(player, data)
		if type(data) ~= "table" then return end
		local c = craftOf(data)
		if c.Pend ~= "" then
			-- a craft the server stopped in the middle of: paid already, finished now at +0 (an unknown id is dropped)
			if type(K().Recipes[c.Pend]) ~= "table" then
				c.Pend = ""
			elseif not complete(player, data, c.Pend, 0, misses(), 0) then
				notify(player, "Full")
			end
		end
		if on() then sendInfo(player, data) end
	end))
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
