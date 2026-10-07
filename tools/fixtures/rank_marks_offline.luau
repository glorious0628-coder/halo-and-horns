-- rank_marks_offline.luau : 계급 장식 3D (이미지 생성 1 45b6220, 사용자 OK). CharacterVisuals.buildFactionMark puts the
-- rank's own imported halo / horns model (ServerStorage.MarkModels Acc_HaloR1..R5 / Acc_HornsR1..R5) on the head: scaled
-- by head height / 1.2, horns sunk 0.06 into the head top, halos floating 0.3 above it, turned by Yaw; a missing model
-- keeps the old drawn mark. tools/test_rank_marks.py binds CONFIG_SOURCE, UTIL_SOURCE and MARKS_EXTRACT (attrNum,
-- markTemplate, buildMarkModel, buildFactionMark cut from the CURRENT CharacterVisuals) in front of dev2_kit.luau.

local C0 = execute("Config", CONFIG_SOURCE, nativeEnv())
local M0 = C0.Visuals.MarkModels

-- a translation + yaw CFrame stand-in (the head never turns here): enough to read where a mark sits
local cfm = {}
local function cf(x, y, z, yaw) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, Yaw = yaw or 0, Roll = 0 }, cfm) end
cfm.__mul = function(a, b) local r = cf(a.X + b.X, a.Y + b.Y, a.Z + b.Z, a.Yaw + b.Yaw); r.Roll = a.Roll + b.Roll; return r end
-- the head never turns here: head space = a plain shift
cfm.__index = { PointToObjectSpace = function(self, v) return vec(v.X - self.X, v.Y - self.Y, v.Z - self.Z) end }
local CF = {
	new = function(x, y, z) return cf(x, y, z) end,
	Angles = function(rx, ry, rz)
		local r = cf(0, 0, 0, ry or 0)
		r.Roll = rz or 0
		return r
	end,
}

-- the real Roblox sizes of the ten models (studs; 이미지 생성 1: width x depth x height -> Size = (width, height, depth))
local SIZES = {
	Acc_HornsR1 = vec(0.98, 0.43, 0.30), Acc_HornsR2 = vec(1.19, 0.60, 0.30), Acc_HornsR3 = vec(1.42, 1.19, 0.63),
	Acc_HornsR4 = vec(1.40, 1.12, 0.51), Acc_HornsR5 = vec(1.50, 1.42, 0.98),
	Acc_HaloR1 = vec(1.34, 0.09, 1.34), Acc_HaloR2 = vec(1.37, 0.31, 1.39), Acc_HaloR3 = vec(2.10, 0.79, 1.48),
	Acc_HaloR4 = vec(2.35, 0.90, 1.40), Acc_HaloR5 = vec(2.97, 1.57, 1.48),
}

-- the kit's instance doubles learn Clone, FindFirstChildWhichIsA and the BasePart family (this suite only)
local function isA(inst, kind)
	if kind == "BasePart" then return inst.ClassName == "MeshPart" or inst.ClassName == "Part" or inst.ClassName == "WedgePart" end
	return inst.ClassName == kind or kind == "Instance"
end
instMeta.Methods.IsA = isA
instMeta.Methods.Clone = function(inst)
	local c = newInstance(inst.ClassName, inst._world)
	for k, v in inst do
		if k ~= "_children" and k ~= "_parent" and k ~= "Attrs" and k ~= "Signals" then rawset(c, k, v) end
	end
	for _, child in inst._children do child:Clone().Parent = c end
	return c
end
instMeta.Methods.FindFirstChildWhichIsA = function(inst, kind, recursive)
	for _, child in inst._children do
		if isA(child, kind) then return child end
		if recursive then
			local deep = child:FindFirstChildWhichIsA(kind, true)
			if deep then return deep end
		end
	end
	return nil
end

local function marksWorld(o)
	o = o or {}
	local w = newWorld({})
	local env = w:Env()
	env.CFrame = CF
	local ss = newInstance("ServerStorage", w)
	if o.Folder ~= false then
		local folder = newInstance("Folder", w)
		folder.Name = M0.Folder
		folder.Parent = ss
		for name, size in SIZES do
			if not (o.Skip and o.Skip[name]) then
				local mesh = newInstance("MeshPart", w)
				mesh.Name, mesh.Size, mesh.Anchored, mesh.CanCollide = name, size, true, true
				mesh.MeshId = "rbxassetid://" .. name
				if o.AsModel and o.AsModel[name] then
					local model = newInstance("Model", w)
					model.Name = name
					mesh.Name = "Mesh"
					mesh.Parent = model
					model.Parent = folder
				else
					mesh.Parent = folder
				end
			end
		end
	end
	w.Lights, w.Glows, w.Mounted = {}, {}, {}
	local newPiece = function(name)
		local m = newInstance("Model", w)
		m.Name = name
		return m
	end
	local mount = function(model, parts, character)
		for _, p in parts do p.Parent = model end
		model.Parent = character
		table.insert(w.Mounted, { Model = model, Parts = parts })
	end
	local accPart = function(props)
		local p = newInstance(props.ClassName or "Part", w)
		for k, v in props do
			if k ~= "ClassName" and k ~= "Parent" then p[k] = v end
		end
		return p
	end
	local addLight = function(parent, color, range, brightness)
		table.insert(w.Lights, { Parent = parent, Color = color, Range = range, Brightness = brightness })
	end
	local sparkle = function(parent, color, rate, size)
		table.insert(w.Glows, { Parent = parent, Color = color, Rate = rate, Size = size })
	end
	local clearChild = function(parent, name)
		for _, child in parent:GetChildren() do if child.Name == name then child.Parent = nil end end
	end
	local getFaction = function(player) return player:GetAttribute("Faction") or "None" end
	local charScale = function() return 1 end
	local buildNeutralGear = function() return { accPart({ Name = "GearDisc" }) } end
	w.Build = execute("CharacterVisuals.marks", MARKS_EXTRACT, env, C0, w.Util, ss, newPiece, mount, accPart, addLight,
		sparkle, clearChild, getFaction, charScale, buildNeutralGear)
	-- a player with a blocky head (1.2 studs high unless o.Head) whose top is at Y = 10.6
	function w:Hero(userId, faction, points, headY)
		local p = self:NewPlayer(userId, {})
		p:SetAttribute("Faction", faction)
		p:SetAttribute(faction == "Horns" and "Infamy" or "Honor", points or 0)
		local character = newInstance("Model", w)
		local head = newInstance("Part", w)
		local h = headY or 1.2
		head.Name, head.Size, head.CFrame = "Head", vec(1.2 * h / 1.2, h, 1.2 * h / 1.2), cf(0, 10.6 - h / 2, 0)
		head.Parent = character
		p.Character = character
		return p, character, head
	end
	-- 3rd idea round #6: an accessory whose handle top is `above` studs over the head top (Y 10.6), `height` tall, on
	-- the attachment `slot` (nil = none) and of AccessoryType `kind` (nil = unset)
	function w:Wear(character, slot, above, height, kind)
		local acc = newInstance("Accessory", w)
		acc.Name = "Acc" .. tostring(slot) .. tostring(above)
		acc.AccessoryType = kind
		local handle = newInstance("Part", w)
		handle.Name, handle.Size = "Handle", vec(1.4, height, 1.4)
		handle.Position = vec(0, 10.6 + above - height / 2, 0)
		handle.Parent = acc
		if slot then
			local att = newInstance("Attachment", w)
			att.Name = slot
			att.Parent = handle
		end
		acc.Parent = character
		return acc
	end
	return w
end

local function markOf(character)
	return character:FindFirstChild("FactionMark")
end
local function rankPoints(f, rank)
	return C0.Titles.Thresholds[rank]
end
local function near(a, b) return math.abs(a - b) < 1e-6 end
local RANK_SCALE = { 1.4, 1.2 } -- 검수 2026-10-07 (3rd idea round #6): R1 x1.4, R2 x1.2, ranks 3-5 x1
local MAX_RISE = 1.0 -- the highest a hat / hair lifts the mark above a 1.2 head (x head / 1.2)

runGroup("config", function()
	check(type(M0) == "table" and M0.Folder == "MarkModels" and #M0.Halo == 5 and #M0.Horns == 5,
		"Config.Visuals.MarkModels: 5 halos + 5 horns in ServerStorage.MarkModels", show(M0 and { M0.Folder, #M0.Halo, #M0.Horns }))
	for r = 1, 5 do
		check(M0.Halo[r] == "Acc_HaloR" .. r and M0.Horns[r] == "Acc_HornsR" .. r, "rank " .. r .. ": the delivered file names",
			show({ M0.Halo[r], M0.Horns[r] }))
	end
	check(M0.HeadRef == 1.2 and M0.HaloGap == 0.3 and M0.HornsDepth == 0.06, "head 1.2, halo +0.3, horns -0.06 (이미지 생성 1)",
		show({ M0.HeadRef, M0.HaloGap, M0.HornsDepth }))
	check(#C0.Titles.Thresholds == 5, "five ranks (Config.Titles.Thresholds)", #C0.Titles.Thresholds)
	check(M0.Glow and M0.Glow.Rank == 5 and M0.Yaw == 0, "the R5 glow (이미지 생성 1) and Yaw 0 (the models already face -Z, 427baf8)",
		show(M0.Glow and { M0.Glow.Rank, M0.Yaw }))
end)

runGroup("each rank wears its own model", function()
	local w = marksWorld()
	for _, f in { "Halo", "Horns" } do
		for r = 1, 5 do
			local p, character, head = w:Hero(100 + r + (f == "Horns" and 10 or 0), f, rankPoints(f, r))
			local nLights, nGlows = #w.Lights, #w.Glows
			w.Build(p, character)
			local mark = markOf(character)
			local part = mark and mark._children[1]
			local name = (f == "Halo" and "Acc_HaloR" or "Acc_HornsR") .. r
			local size = SIZES[name] * (RANK_SCALE[r] or 1)
			check(mark ~= nil and #mark._children == 1 and part.MeshId == "rbxassetid://" .. name,
				f .. " rank " .. r .. ": the " .. name .. " model", show(part and part.MeshId))
			if part then
				local top = 10.6
				local lift = f == "Halo" and 0.3 or -0.06
				check(near(part.CFrame.Y, top + lift + size.Y / 2) and near(part.CFrame.X, 0) and near(part.CFrame.Z, 0),
					f .. " rank " .. r .. ": bottom at head top " .. (f == "Halo" and "+0.3" or "-0.06"), show({ part.CFrame.Y, top + lift + size.Y / 2 }))
				check(near(part.CFrame.Yaw, math.rad(M0.Yaw)) and near(part.Size.X, size.X) and near(part.Size.Y, size.Y),
					f .. " rank " .. r .. ": turned by Yaw, real size on a 1.2 head (R1 x1.4, R2 x1.2)", show({ part.CFrame.Yaw, part.Size }))
				check(part.Anchored == false and part.CanCollide == false and part.Massless == true and part.CanQuery == false
					and part.CanTouch == false, f .. " rank " .. r .. ": a weightless, non-colliding accessory",
					show({ part.Anchored, part.CanCollide, part.Massless }))
				local lit = #w.Lights > nLights
				check(lit == (f == "Halo"), f .. " rank " .. r .. ": " .. (f == "Halo" and "the halo glows (light)" or "no light on horns"),
					show(#w.Lights - nLights))
				local glow = #w.Glows > nGlows
				check(glow == (r >= M0.Glow.Rank), f .. " rank " .. r .. ": sparkles only at rank " .. M0.Glow.Rank, show(#w.Glows - nGlows))
			end
		end
	end
end)

runGroup("bigger heads, models, missing files", function()
	local w = marksWorld({ AsModel = { Acc_HaloR2 = true }, Skip = { Acc_HornsR3 = true } })
	-- a 1.5-stud head: size and both offsets x1.25
	local p, character = w:Hero(201, "Horns", rankPoints("Horns", 2), 1.5)
	w.Build(p, character)
	local part = markOf(character)._children[1]
	local k = 1.5 / 1.2
	local r2 = SIZES.Acc_HornsR2.Y * k * RANK_SCALE[2]
	check(near(part.Size.Y, r2) and near(part.CFrame.Y, 10.6 - 0.06 * k + r2 / 2),
		"a 1.5 head: the horns x1.25 (x1.2 for R2) and sunk 0.06 x1.25", show({ part.Size.Y, part.CFrame.Y }))
	-- a template imported as a Model with one mesh inside
	local q, qc = w:Hero(202, "Halo", rankPoints("Halo", 2))
	w.Build(q, qc)
	local qp = markOf(qc)._children[1]
	check(qp and qp.MeshId == "rbxassetid://Acc_HaloR2", "a template that is a Model: its mesh is used", show(qp and qp.MeshId))
	-- a rank whose model is not in Studio yet keeps the old drawn horns
	local r, rc = w:Hero(203, "Horns", rankPoints("Horns", 3))
	w.Build(r, rc)
	local names = {}
	for _, c in markOf(rc)._children do table.insert(names, c.Name) end
	table.sort(names)
	check(#names == 2 and names[1] == "HornL" and names[2] == "HornR", "rank 3 horns missing in Studio: the drawn horns", show(names))
	-- no folder at all: every mark is the old drawn one; the guild keeps its gear
	local w2 = marksWorld({ Folder = false })
	local h, hc = w2:Hero(204, "Halo", rankPoints("Halo", 5))
	w2.Build(h, hc)
	check(markOf(hc)._children[1].Name == "HaloDisc", "no MarkModels folder: the drawn halo disc", show(markOf(hc)._children[1].Name))
	local g, gc = w:Hero(205, "Neutral", 0)
	w.Build(g, gc)
	check(markOf(gc)._children[1].Name == "GearDisc", "the guild keeps its gear (no rank model)")
	-- rebuilding replaces the old mark (one FactionMark)
	w.Build(p, character)
	local marks = 0
	for _, c in character._children do if c.Name == "FactionMark" then marks += 1 end end
	check(marks == 1, "a rebuild leaves one mark", marks)
end)

-- 3rd idea round #6 (검수 2026-10-07): R1 / R2 were buried in hair. The mark stands on the head top or on the top of a
-- hat / hair accessory (HatAttachment / HairAttachment, or AccessoryType Hat / Hair) when higher, at most 1.0 x k
-- above the head top; the four avatar kinds the review asked for: bald, up-do, long hair, hat
runGroup("on top of hair and hats", function()
	local w = marksWorld()
	check(type(M0.RankScale) == "table" and M0.RankScale[1] == RANK_SCALE[1] and M0.RankScale[2] == RANK_SCALE[2]
		and M0.RankScale[3] == nil and M0.MaxRise == MAX_RISE, "Config: RankScale { 1.4, 1.2 }, MaxRise 1.0",
		show({ M0.RankScale, M0.MaxRise }))
	local id = 300
	-- the R1 halo / horns bottom over the head top (Y 10.6) for one outfit
	local function bottom(f, outfit, headY, rank)
		id += 1
		local p, character, head = w:Hero(id, f, rankPoints(f, rank or 1), headY)
		for _, item in outfit do w:Wear(character, item[1], item[2], item[3], item[4]) end
		w.Build(p, character)
		local part = markOf(character)._children[1]
		return part.CFrame.Y - part.Size.Y / 2 - 10.6, part, head
	end
	local HALO_GAP, HORNS_DEPTH = 0.3, 0.06
	local cases = {
		{ "bald: on the head", {}, 0 },
		{ "up-do (a bun 0.8 over the head)", { { "HairAttachment", 0.8, 1.4 } }, 0.8 },
		{ "long hair (0.25 over the head, hanging down)", { { "HairAttachment", 0.25, 2.6 } }, 0.25 },
		{ "a cap (0.35 over the head)", { { "HatAttachment", 0.35, 0.6 } }, 0.35 },
		{ "a top hat (1.6 over the head): capped at 1.0", { { "HatAttachment", 1.6, 1.7 } }, MAX_RISE },
		{ "a cap on an up-do: the higher one", { { "HatAttachment", 0.35, 0.6 }, { "HairAttachment", 0.8, 1.4 } }, 0.8 },
		{ "wings on the back (2.0 over the head): not a head slot", { { "BodyBackAttachment", 2.0, 3.0 } }, 0 },
		{ "glasses (below the head top) change nothing", { { "FaceFrontAttachment", -0.3, 0.3 } }, 0 },
		{ "hair with AccessoryType Hair and no slot name", { { nil, 0.5, 1.0, "AccessoryType.Hair" } }, 0.5 },
		{ "a hat with AccessoryType Hat and no slot name", { { nil, 0.4, 0.8, "AccessoryType.Hat" } }, 0.4 },
		{ "a waist item of another type: ignored", { { nil, 0.9, 1.0, "AccessoryType.Waist" } }, 0 },
	}
	for _, case in cases do
		local halo = bottom("Halo", case[2])
		check(near(halo, case[3] + HALO_GAP), "halo R1, " .. case[1], show({ halo, case[3] + HALO_GAP }))
		local horns = bottom("Horns", case[2])
		check(near(horns, case[3] - HORNS_DEPTH), "horns R1, " .. case[1], show({ horns, case[3] - HORNS_DEPTH }))
	end
	-- R2 on an up-do: x1.2 and on the bun
	local b2, part2 = bottom("Halo", { { "HairAttachment", 0.8, 1.4 } }, nil, 2)
	check(near(b2, 0.8 + HALO_GAP) and near(part2.Size.X, SIZES.Acc_HaloR2.X * RANK_SCALE[2]), "halo R2 on an up-do: x1.2, on the bun",
		show({ b2, part2.Size.X }))
	-- R5 keeps its own size
	local _, part5 = bottom("Horns", {}, nil, 5)
	check(near(part5.Size.Y, SIZES.Acc_HornsR5.Y), "rank 5: its real size (x1)", show(part5.Size.Y))
	-- a 1.5-stud head under a giant hat: the cap grows with the head (1.0 x 1.25)
	local k = 1.5 / 1.2
	local big = bottom("Halo", { { "HatAttachment", 3.0, 3.2 } }, 1.5)
	check(near(big, MAX_RISE * k + HALO_GAP * k), "a 1.5 head under a giant hat: at most 1.25 over the head", show({ big, MAX_RISE * k + HALO_GAP * k }))
end)

-- UI round 2 #7 (검수 2026-10-07): the name tag over a head uses the game's fonts (A23-63) from one Config place
runGroup("name tag fonts", function()
	local F = C0.Fonts
	check(type(F) == "table" and F.Head == "rbxasset://fonts/families/DenkOne.json"
		and F.Body == "rbxasset://fonts/families/Montserrat.json", "Config.Fonts: Head = Denk One, Body = Montserrat", show(F))
	local w = newWorld({})
	local tag = execute("CharacterVisuals.nametag", NAMETAG_EXTRACT, w:Env(), C0)
	local p = newInstance("Player", w)
	local bb = tag.create(p)
	local function face(n)
		local l = bb:FindFirstChild(n)
		return l and type(l.FontFace) == "table" and l.FontFace.Args or {}
	end
	check(face("Line1")[1] == F.Head, "the name line: Denk One (Head)", show(face("Line1")))
	check(face("Line2")[1] == F.Body and face("Line3")[1] == F.Body, "lines 2 and 3: Montserrat (Body)",
		show({ face("Line2")[1], face("Line3")[1] }))
	check(face("Line1")[2] == "FontWeight.Bold" and face("Line2")[2] == "FontWeight.Bold", "bold, like the old GothamBold",
		show({ face("Line1")[2], face("Line2")[2] }))
	local ghost = newInstance("TextLabel", w)
	tag.tagFont(ghost, "Ghost")
	check(type(ghost.FontFace) == "table" and ghost.FontFace.Args[1] == F.Body, "the grudge ghost's label: Montserrat",
		show(ghost.FontFace))
	-- no Config.Fonts (an old Config): the label keeps GothamBold
	local plain = newInstance("TextLabel", w)
	C0.Fonts = nil
	local ok, err = pcall(tag.tagFont, plain, "Line1")
	C0.Fonts = F
	check(ok and plain.Font == "Font.GothamBold" and plain.FontFace == nil, "without Config.Fonts: GothamBold, no error",
		show({ ok, err, plain.Font, plain.FontFace }))
end)

finish()
