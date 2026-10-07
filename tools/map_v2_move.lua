-- 지도 v1 → v2 옮기기 (SPEC A23-53, Studio 편집 모드, py tools/map_v2_apply.py move [--apply]).
-- MODE (러너가 "__MODE__" 자리를 바꾼다. 그대로면 "dry" = 아무것도 안 옮기고 무엇을 옮길지만 센다):
--   "dry"   = 목록만
--   "apply" = 옮김
-- 무엇을:
--   ① 마을: v1 빛 섬(x -110..110, z -500..-300)·뿔 섬(z 300..500) 위의 것은 관문과 함께 10 스터드 바깥으로
--      (빛 z -10, 뿔 z +10: v1 스폰 (0, -+410) → v2 스폰 (0, -+420)). 성(이름에 castle / fortress)은 섬 끝
--      랜드마크 자리 (0, -+630) 로.
--   ② 사냥터 장식: v1 땅 조각 안의 상대 자리를 v2 땅 조각의 같은 상대 자리로(크기·높이·방향 그대로):
--      초원 v1 x 155..490 → v2 210..650, 숲 v1 x 530..915 → v2 710..1190, 유적 v1 x 915..1300 → v2 1260..1780
--      (z 는 v1 -175..175 → v2 각 땅의 z 범위).
--   ③ 호박밭·유령 숲 장식(Decor.PumpkinPatch / HauntedHollow)은 MapBuilder 가 v2 자리에 다시 짓도록 보관함으로.
--   교차로(x -110..115, z -175..175)는 그대로. 다리·길·PvP 경계(preview_map terrain 이 다시 지음)·관문(MapBuilder /
--   preview_map 이 옮김)·구역·벽·발판은 건드리지 않는다. 한 번 옮긴 것에는 속성 MapV2Moved = true 를 달아 두 번 옮기지 않는다.
-- 보는 곳: workspace.Map.Decor / Landmarks / NPCs 의 자식, 그리고 workspace 바로 아래의 다른 폴더·모델(키트 묶음:
-- KitTowns, KitTownFill …)의 자식. Terrain·Camera·Map 의 계약 폴더(Zones/Walls/Pads/Gates/Ground)는 제외.

local MODE = "__MODE__"
if MODE ~= "apply" then MODE = "dry" end

local SS = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local TOWN = {
	Halo = { MinX = -125, MaxX = 125, MinZ = -515, MaxZ = -285, Shift = -10, Castle = Vector3.new(0, 0, -630) },
	Horns = { MinX = -125, MaxX = 125, MinZ = 285, MaxZ = 515, Shift = 10, Castle = Vector3.new(0, 0, 630) },
}
local CROSSROADS = { MinX = -110, MaxX = 115, MinZ = -175, MaxZ = 175 }
-- v1 piece (x range, z -175..175) -> v2 land
local FIELDS = {
	{ Name = "Meadow", From = { MinX = 155, MaxX = 490, MinZ = -175, MaxZ = 175 }, To = { MinX = 210, MaxX = 650, MinZ = -240, MaxZ = 240 } },
	{ Name = "Woods", From = { MinX = 530, MaxX = 915, MinZ = -175, MaxZ = 175 }, To = { MinX = 710, MaxX = 1190, MinZ = -260, MaxZ = 260 } },
	{ Name = "Ruins", From = { MinX = 915, MaxX = 1300, MinZ = -175, MaxZ = 175 }, To = { MinX = 1260, MaxX = 1780, MinZ = -290, MaxZ = 290 } },
}
-- rebuilt elsewhere (never moved here)
local SKIP_PREFIX = { "Bridge_", "PvPBorder_", "Gate_", "Pad_", "Wall" }
local SKIP_NAME = { Roads = true, PreviewSpawn = true, CrownOfBalance = true, CrownSkyAnchor = true }
local SEASON_DECOR = { PumpkinPatch = true, HauntedHollow = true }

local function inRect(p, r) return p.X >= r.MinX and p.X <= r.MaxX and p.Z >= r.MinZ and p.Z <= r.MaxZ end
local function lower(s) return string.lower(tostring(s)) end

local function posOf(inst)
	if inst:IsA("BasePart") then return inst.Position end
	if inst:IsA("Model") then
		local ok, cf = pcall(inst.GetPivot, inst)
		if ok then return cf.Position end
	end
	if inst:IsA("Folder") then
		local sum, n = Vector3.zero, 0
		for _, d in inst:GetDescendants() do
			if d:IsA("BasePart") then sum += d.Position; n += 1 end
		end
		if n > 0 then return sum / n end
	end
	return nil
end

local function moveBy(inst, delta)
	if inst:IsA("BasePart") then
		inst.CFrame = inst.CFrame + delta
	elseif inst:IsA("Model") then
		inst:PivotTo(inst:GetPivot() + delta)
	elseif inst:IsA("Folder") then
		for _, d in inst:GetChildren() do moveBy(d, delta) end
	end
end

local function skipped(inst)
	if SKIP_NAME[inst.Name] then return true end
	for _, p in SKIP_PREFIX do
		if string.sub(inst.Name, 1, #p) == p then return true end
	end
	return false
end

-- what to do with one item: kind, delta (nil = leave)
local function plan(inst)
	if inst:GetAttribute("MapV2Moved") then return "done", nil end
	local p = posOf(inst)
	if not p then return "nopos", nil end
	for key, t in TOWN do
		if inRect(p, t) then
			local name = lower(inst.Name)
			if string.find(name, "castle", 1, true) or string.find(name, "fortress", 1, true) then
				return "castle" .. key, Vector3.new(t.Castle.X - p.X, 0, t.Castle.Z - p.Z)
			end
			return "town" .. key, Vector3.new(0, 0, t.Shift)
		end
	end
	if inRect(p, CROSSROADS) then return "crossroads", nil end
	for _, f in FIELDS do
		if inRect(p, f.From) then
			local u = (p.X - f.From.MinX) / (f.From.MaxX - f.From.MinX)
			local v = (p.Z - f.From.MinZ) / (f.From.MaxZ - f.From.MinZ)
			local nx = f.To.MinX + u * (f.To.MaxX - f.To.MinX)
			local nz = f.To.MinZ + v * (f.To.MaxZ - f.To.MinZ)
			return "field" .. f.Name, Vector3.new(nx - p.X, 0, nz - p.Z)
		end
	end
	return "elsewhere", nil
end

-- the containers to look into
local map = workspace:FindFirstChild("Map")
local sources = {}
if map then
	for _, n in { "Decor", "Landmarks", "NPCs" } do
		local f = map:FindFirstChild(n)
		if f then table.insert(sources, f) end
	end
end
local playerChars = {}
for _, plr in Players:GetPlayers() do
	if plr.Character then playerChars[plr.Character] = true end
end
-- top-level folders are looked into; a top-level model / part (a kit piece placed straight in workspace) is one unit
local topUnits = {}
for _, c in workspace:GetChildren() do
	if c ~= map and not c:IsA("Terrain") and not c:IsA("Camera") and not playerChars[c] and c.Name ~= "Map" then
		if c:IsA("Folder") then
			table.insert(sources, c)
		elseif c:IsA("Model") or c:IsA("BasePart") then
			table.insert(topUnits, c)
		end
	end
end

local counts, examples, seasonal = {}, {}, {}
local moved = 0
-- one unit: a Model or a part moves as one piece
local function handle(inst, where)
	local kind, delta = plan(inst)
	counts[kind] = (counts[kind] or 0) + 1
	examples[kind] = examples[kind] or {}
	if (delta or kind == "elsewhere") and #examples[kind] < 4 then
		local p = posOf(inst)
		local d = delta or Vector3.zero
		table.insert(examples[kind], string.format("%s/%s (%.0f,%.0f)->(%.0f,%.0f)", where, inst.Name, p.X, p.Z, p.X + d.X, p.Z + d.Z))
	end
	if delta and MODE == "apply" then
		moveBy(inst, delta)
		inst:SetAttribute("MapV2Moved", true)
		moved += 1
	end
end
-- a Folder is looked into (its models / parts move one by one)
local function visit(src)
	for _, inst in src:GetChildren() do
		if src.Name == "Decor" and src.Parent == map and SEASON_DECOR[inst.Name] then
			table.insert(seasonal, inst)
		elseif skipped(inst) then
			counts.skipped = (counts.skipped or 0) + 1
		elseif inst:IsA("Folder") then
			visit(inst)
		elseif inst:IsA("Model") or inst:IsA("BasePart") then
			handle(inst, src.Name)
		end
	end
end
for _, src in sources do visit(src) end
for _, inst in topUnits do
	if skipped(inst) then counts.skipped = (counts.skipped or 0) + 1 else handle(inst, "workspace") end
end
if MODE == "apply" and #seasonal > 0 then
	local backup = SS:FindFirstChild("MapV1Backup") or Instance.new("Folder")
	backup.Name = "MapV1Backup"
	backup.Parent = SS
	local sub = backup:FindFirstChild("SeasonDecor") or Instance.new("Folder")
	sub.Name = "SeasonDecor"
	sub.Parent = backup
	for _, inst in seasonal do inst.Parent = sub end
end

local out = { string.format("map v2 move (%s): sources %d, moved %d, season decor to backup %d", MODE, #sources, moved, #seasonal) }
local keys = {}
for k in counts do table.insert(keys, k) end
table.sort(keys)
for _, k in keys do
	local ex = examples[k]
	table.insert(out, string.format("  %s: %d%s", k, counts[k], (ex and #ex > 0) and ("  e.g. " .. table.concat(ex, "; ")) or ""))
end
return table.concat(out, "\n")
