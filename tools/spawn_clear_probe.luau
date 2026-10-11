-- read-only (게임성 개발 2, A23-129, 2026-10-11): do new monsters spawn inside trees / rocks / buildings on the REAL map?
-- 메인 반영 1 runs it via execute_luau in Edit (datamodel_type "Edit"; a Play "Server" works too). It changes nothing:
-- it requires a fresh copy of MonsterService (no Init / Start: no monsters, no players, so pickSpawnPoint takes its plain
-- random tries) and only reads workspace.Map.
-- Per monster zone of the live Config: PICKS spawn points split over the zone's regular kinds through
-- MonsterService.PickSpawnPoint (the real pickSpawnPoint with the A23-129 body check) = "after", and PICKS plain ground
-- points the old way (Util.RandomPointInZone + MonsterService.GroundAt: ground + the CR-L14 centre ray only) = "before".
-- Every point is checked against every map prop by a test written here (sampled body points inside a part's box and the
-- part's own points inside the body; nothing shared with the game's index). Expected: after = 0 overlaps everywhere.
local PICKS = 500
local FOOT = 0.5

local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local Config = require(RS.Shared.Config)
local Util = require(RS.Shared.Util)
local MS = require(SSS:FindFirstChild("MonsterService"))
local out = { "spawn_clear_probe  place " .. tostring(game.PlaceId) .. "  " .. os.date("!%Y-%m-%d %H:%M UTC") }
if type(MS.PickSpawnPoint) ~= "function" then
	return "MonsterService.PickSpawnPoint missing: this Studio has no A23-129 code yet (sync first)"
end
local map = workspace:FindFirstChild("Map")
if not map then return "no workspace.Map" end

-- the props: every BasePart under Map but the walking ground and its contents, Ground / Zones / Pads, invisible
-- non-collidable helpers
local skip = {}
for _, g in Config.GroundRoots(workspace.Terrain, map, CS:GetTagged((Config.Ground or {}).Tag or "WalkGround")) do
	skip[g] = true
end
for _, n in { "Ground", "Zones", "Pads" } do
	local f = map:FindFirstChild(n)
	if f then skip[f] = true end
end
local function skipped(inst)
	local p = inst
	while p and p ~= map do
		if skip[p] then return true end
		p = p.Parent
	end
	return false
end
local props, cells = {}, {}
local CELL = 32
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") and not skipped(d) and not (d.Transparency >= 0.95 and not d.CanCollide) then
		local s = d.Size
		local pr = { Part = d, CF = d.CFrame, Size = s, Reach = s.Magnitude / 2 }
		table.insert(props, pr)
		local c = pr.CF.Position
		for cx = math.floor((c.X - pr.Reach) / CELL), math.floor((c.X + pr.Reach) / CELL) do
			for cz = math.floor((c.Z - pr.Reach) / CELL), math.floor((c.Z + pr.Reach) / CELL) do
				local k = cx .. ":" .. cz
				cells[k] = cells[k] or {}
				table.insert(cells[k], pr)
			end
		end
	end
end
table.insert(out, "props counted: " .. #props)

local function bodyOf(def)
	local s = tonumber(def.Scale) or 1
	local slime = def.Shape == "Slime"
	return (slime and 1.5 or 1.25) * s, (slime and 3 or 5) * s + math.max(0, tonumber(def.Float) or 0)
end
local function inBox(pr, v)
	local l = pr.CF:PointToObjectSpace(v)
	return math.abs(l.X) <= pr.Size.X / 2 and math.abs(l.Y) <= pr.Size.Y / 2 and math.abs(l.Z) <= pr.Size.Z / 2
end
-- the first prop the body of def standing on g overlaps (sampled), or nil
local function hitAt(g, def)
	local r, h = bodyOf(def)
	local lo, hi = g.Y + FOOT, g.Y + h
	local seen = {}
	for cx = math.floor((g.X - r) / CELL), math.floor((g.X + r) / CELL) do
		for cz = math.floor((g.Z - r) / CELL), math.floor((g.Z + r) / CELL) do
			for _, pr in cells[cx .. ":" .. cz] or {} do
				local c = pr.CF.Position
				if not seen[pr] and math.abs(c.X - g.X) <= pr.Reach + r and math.abs(c.Z - g.Z) <= pr.Reach + r then
					seen[pr] = true
					for _, y in { lo + 0.02, (lo + hi) / 2, hi - 0.02 } do
						for _, rr in { 0, r * 0.5, r * 0.97 } do
							for k = 0, (rr == 0 and 0 or 15) do
								local a = k * math.pi / 8
								if inBox(pr, Vector3.new(g.X + math.cos(a) * rr, y, g.Z + math.sin(a) * rr)) then return pr.Part end
							end
						end
					end
					for _, ox in { -0.98, 0, 0.98 } do
						for _, oy in { -0.98, 0, 0.98 } do
							for _, oz in { -0.98, 0, 0.98 } do
								local v = pr.CF:PointToWorldSpace(Vector3.new(ox * pr.Size.X / 2, oy * pr.Size.Y / 2, oz * pr.Size.Z / 2))
								if v.Y > lo and v.Y < hi and math.sqrt((v.X - g.X) ^ 2 + (v.Z - g.Z) ^ 2) < r then return pr.Part end
							end
						end
					end
				end
			end
		end
	end
	return nil
end
local function pathOf(p)
	local bits, q = {}, p
	while q and q ~= map do
		table.insert(bits, 1, q.Name)
		q = q.Parent
	end
	return table.concat(bits, "/")
end
local function fmt(v) return string.format("(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z) end

-- the zones with regular monsters
local zones, order = {}, {}
for kind, def in Config.MonsterTypes do
	if type(def) == "table" and (tonumber(def.Count) or 0) > 0 and def.Boss ~= true and Config.Zones[def.Zone] then
		if not zones[def.Zone] then
			zones[def.Zone] = {}
			table.insert(order, def.Zone)
		end
		table.insert(zones[def.Zone], kind)
	end
end
table.sort(order)

local first = true
local total = 0
for _, zid in order do
	local kinds = zones[zid]
	table.sort(kinds)
	local zone = Config.Zones[zid]
	-- after: the real pick
	local got, none, bad, ex = 0, 0, 0, {}
	local t0 = os.clock()
	local firstMs = nil
	for i = 1, PICKS do
		local kind = kinds[(i - 1) % #kinds + 1]
		local def = Config.MonsterTypes[kind]
		local t1 = os.clock()
		local g = MS.PickSpawnPoint(kind)
		if first then
			firstMs, first = (os.clock() - t1) * 1000, false
		end
		if g then
			got += 1
			local hit = hitAt(g, def)
			if hit then
				bad += 1
				if #ex < 3 then table.insert(ex, kind .. " " .. fmt(g) .. " in " .. pathOf(hit)) end
			end
		else
			none += 1
		end
		if i % 25 == 0 then task.wait() end
	end
	local ms = (os.clock() - t0) * 1000 / PICKS
	total += bad
	-- before: plain ground points (the old rule), with the zone's biggest regular kind's body
	local big, bigR = kinds[1], -1
	for _, k in kinds do
		local r = bodyOf(Config.MonsterTypes[k])
		if r > bigR then big, bigR = k, r end
	end
	local oldN, oldBad, noGround, who = 0, 0, 0, {}
	for i = 1, PICKS do
		local pt = Util.RandomPointInZone(zone, Config.Monsters.SpawnInset)
		local g, noHit = MS.GroundAt(pt.X, pt.Z)
		if g then
			oldN += 1
			local hit = hitAt(g, Config.MonsterTypes[big])
			if hit then
				oldBad += 1
				local key = pathOf(hit):gsub("[_%d]+$", "")
				who[key] = (who[key] or 0) + 1
			end
		elseif noHit then
			noGround += 1
		end
		if i % 25 == 0 then task.wait() end
	end
	local top = {}
	for k, n in who do table.insert(top, { k, n }) end
	table.sort(top, function(a, b) return a[2] > b[2] end)
	local tops = {}
	for i = 1, math.min(4, #top) do table.insert(tops, top[i][1] .. " " .. top[i][2]) end
	table.insert(out, string.format("%-14s kinds %s", zid, table.concat(kinds, ",")))
	table.insert(out, string.format("  after : %d picks, %d none this pass, %d INSIDE A PROP, %.2f ms/pick", got, none, bad, ms))
	for _, e in ex do table.insert(out, "    ! " .. e) end
	table.insert(out, string.format("  before: %d ground points, %d inside a prop with a %s body (%.0f%%)%s", oldN, oldBad, big,
		oldN > 0 and oldBad * 100 / oldN or 0, noGround > 0 and (", " .. noGround .. " with no ground at all") or ""))
	if #tops > 0 then table.insert(out, "    most: " .. table.concat(tops, " | ")) end
end
table.insert(out, string.format("first pick incl. the index build: %.1f ms", firstMs or -1))
table.insert(out, total == 0 and "RESULT OK: no new monster inside a prop" or ("RESULT FAIL: " .. total .. " picks inside a prop"))
local text = table.concat(out, "\n")
print(text)
return text
