-- HudLayout.luau : A23-40 screen layout B ("보여 준 게임처럼") as one pure function (no instances, no services).
-- The rectangles of docs/design/hud_layout_B_imgdev_2026-10-06.json are real pixels on two reference screens: desktop
-- 1280x720 (MainGui UIScale 0.8; the PC numbers are 검수's docs/design/hud_layout_B_2026-10-06.json) and phone 749x361
-- (UIScale 0.75; 이미지 개발 placed the phone by the A23-40 rules), both with a 58 px top bar.
-- HudLayout.Compute turns them into MainGui logical units (before UIScale) for the current screen: every item keeps its
-- distance to the edge it belongs to (top-left / top-centre / top-right / bottom-centre / bottom-right), the top rows follow
-- the real top-bar inset, the phone combat cluster follows the real jump button, the centre column narrows between the
-- left and right blocks, and on PCs the bottom-centre group moves left when the corner cluster would cover it.
--   PC:    top-left round minimap + 2 quest lines under it, top-centre war meter -> chips -> next event -> notify,
--          bottom-centre face + 'Lv · 전투력' + HP | MP + XP + icon tile row, bottom-right combat cluster, top-right the
--          [메뉴] tile (A23-40 정정: its tiles fold out to the left; the Tab list opens under it).
--   phone: the bottom centre belongs to the thumbstick and the combat buttons, so the face / bars / tile row sit top-right
--          (the quest lines beside the minimap, the centre column between them); [메뉴] ends the tile row on the right.
local HudLayout = {}

-- reference screens of the approved sheets (real px)
local REF = {
	Desktop = { W = 1280, H = 720, Scale = 0.8, Inset = 58 },
	Touch = { W = 749, H = 361, Scale = 0.75, Inset = 58, Jump = { 654, 271, 70, 70 } },
}

-- id = { desktop anchor, desktop { x, y, w, h }, touch { x, y, w, h }, touch anchor (default: the desktop one) }
-- anchors: TL top-left, TC top-centre, TR top-right, BC bottom-centre, BR bottom-right (touch: the jump button)
local ITEMS = {
	minimap = { "TL", { 14, 66, 150, 150 }, { 8, 62, 84, 84 } },
	quest = { "TL", { 14, 226, 300, 52 }, { 98, 62, 150, 45 } },
	war_meter = { "TC", { 496, 66, 288, 42 }, { 255, 62, 240, 38 } },
	chips = { "TC", { 516, 112, 248, 22 }, { 255, 103, 240, 17 } },
	event = { "TC", { 546, 138, 188, 22 }, { 300, 122, 150, 16 } },
	notify = { "TC", { 496, 166, 288, 46 }, { 255, 141, 240, 34 } },
	portrait = { "BC", { 362, 586, 50, 50 }, { 502, 62, 45, 45 }, "TR" },
	power_line = { "BC", { 420, 578, 440, 16 }, { 551, 62, 190, 14 }, "TR" },
	hp_bar = { "BC", { 420, 598, 216, 20 }, { 551, 78, 93, 13 }, "TR" },
	mp_bar = { "BC", { 644, 598, 216, 20 }, { 648, 78, 93, 13 }, "TR" },
	xp_bar = { "BC", { 420, 622, 440, 8 }, { 551, 95, 190, 6 }, "TR" },
	tiles = { "BC", { 420, 640, 440, 52 }, { 502, 112, 191, 45 }, "TR" },
	-- A23-40 정정 (user 2026-10-06 "메뉴는 오른쪽 위에, 누르면 옆으로 좌르륵"): PC top-right corner 10 px from the edge
	-- under the top bar; phone the right end of the tile row (the plate holds the corner). out.fold = its fold-out room
	menu = { "TR", { 1218, 66, 52, 52 }, { 696, 112, 45, 45 } },
	combo = { "BC", { 580, 463, 120, 24 }, { 305, 236, 144, 20 } },
	potions = { "BR", { 926, 646, 122, 58 }, { 337, 298, 112, 54 } },
	ghost = { "BR", { 987, 577, 61, 61 }, { 590, 182, 57, 57 } },
	q = { "BR", { 1062, 588, 77, 77 }, { 455, 252, 72, 72 } },
	z = { "BR", { 1121, 505, 77, 77 }, { 497, 180, 72, 72 } },
	auto = { "BR", { 1213, 515, 51, 51 }, { 665, 215, 48, 48 } },
	attack = { "BR", { 1146, 592, 118, 118 }, { 534, 241, 112, 112 } },
}
HudLayout.Items = ITEMS
HudLayout.Ref = REF

local CENTER = { "war_meter", "chips", "event", "notify" }
local MIN_CENTER = 240 -- logical units: narrowest centre column (the war meter stays >= 240du)
local GAP = 8
-- touch targets never shrink below 60 logical units (~45 real px at the phone's 0.75 UIScale). A scaled down button
-- grows back: the portrait from its top-left corner (the bars beside it give way, the tile row under it moves down), the
-- tiles to MIN_TAP squares (fewer fit the row), the quest lines downwards, the round combat buttons around their centre,
-- the potions upwards and then to the left (both cells: the potions rect holds HP and MP side by side, POTION_GAP apart)
local MIN_TAP = 60
local ROUND_TAPS = { "ghost", "q", "z", "auto", "attack" }
local POTION_GAP = 6 -- real px between the HP and MP buttons on both reference sheets (out.potions.Gap, in du)
HudLayout.PotionGap = POTION_GAP
local TILE_GAP = 3 -- real px: the least gap between two tiles of the icon row (out.tiles.Gap, in du)
local STICK = { X = 0.4, Y = 1 / 3 } -- touch thumbstick zone: x < 0.4 W and y > H / 3
-- desktop: the bottom-centre group (face, power line, bars, XP, tiles) and the corner cluster it must stay clear of
local BC_GROUP = { "portrait", "power_line", "hp_bar", "mp_bar", "xp_bar", "tiles" }
local CLUSTER = { "potions", "ghost", "q", "z", "auto", "attack" }
-- touch: the plate beside the portrait (moves right when the portrait grows back to MIN_TAP)
local PLATE = { "power_line", "hp_bar", "mp_bar", "xp_bar" }
-- [메뉴] fold-out: lines of squares as big as [메뉴], filled from [메뉴] to the left. The first line is [메뉴]'s own;
-- more lines go down on PCs and UP on phones (A23-38: phones fold out upward only, never onto the combat buttons). While
-- open it may run over the centre column's info rows (chips / next event / notify), on phones also over the tile row it
-- replaces and the face / bars above it, but never over the war meter, the minimap, the quest lines, a combat button,
-- the jump button or the thumbstick zone
local FOLD_OVER = { tiles = true, menu = true, chips = true, event = true, notify = true, combo = true }
local FOLD_OVER_TOUCH = { portrait = true, power_line = true, hp_bar = true, mp_bar = true, xp_bar = true }
local FOLD_ROWS = 3
local FOLD_GAP = 4 -- real px between two fold-out squares on PCs

local function rect(x, y, w, h)
	return { X = x, Y = y, W = w, H = h }
end

local function anchorOf(id, touch)
	local def = ITEMS[id]
	if not def then return "TL" end
	return touch and def[4] or def[1]
end
HudLayout.AnchorOf = anchorOf

-- env = { W, H = MainGui size in logical units, Scale = UIScale, Inset = top bar inset (real px), Touch = bool,
--         Jump = { X, Y, W, H } of the touch jump button in logical units or nil, Hidden = { [id] = true } }
-- returns { [id] = { X, Y, W, H } } in logical units (MainGui space, before UIScale). potions also carries Gap (du between
-- its HP and MP cells: cell width = (W - Gap) / 2); tiles carries Size (square tile side), Gap (least gap) and Count (how
-- many tiles fit the row: the HUD shows that many, the rest go into the [메뉴] tile)
function HudLayout.Compute(env)
	local touch = env.Touch == true
	local ref = touch and REF.Touch or REF.Desktop
	local k = 1 / ref.Scale -- reference px -> logical units
	local s = (type(env.Scale) == "number" and env.Scale > 0) and env.Scale or 1
	local W, H = env.W, env.H
	local top = (tonumber(env.Inset) or ref.Inset) / s -- logical y of the top bar's bottom edge
	local jump = touch and env.Jump or nil
	local hidden = env.Hidden or {}
	-- touch: a safe area narrower / shorter than the reference phone (notch insets: 749x361 -> 655x340) scales the
	-- whole layout down by the same factor, so the stick zone and the gaps stay free
	if touch then
		k *= math.min(1, W / (ref.W / ref.Scale), H / (ref.H / ref.Scale))
	end
	local rj = touch and ref.Jump or nil -- the approved sheet's jump button (real px)
	local out = {}
	for id, def in ITEMS do
		local r = touch and def[3] or def[2]
		local x, y, w, h = r[1], r[2], r[3] * k, r[4] * k
		local anchor = anchorOf(id, touch)
		if anchor == "BC" and jump then anchor = "BR" end -- touch: the combo line rides with the cluster (never under Q)
		local X, Y
		if anchor == "TL" then
			X, Y = x * k, top + (y - ref.Inset) * k
		elseif anchor == "TR" then
			X, Y = W - (ref.W - x) * k, top + (y - ref.Inset) * k
		elseif anchor == "TC" then
			X, Y = W / 2 + (x - ref.W / 2) * k, top + (y - ref.Inset) * k
		elseif anchor == "BC" then
			X, Y = W / 2 + (x - ref.W / 2) * k, H - (ref.H - y) * k
		elseif jump and rj then
			-- BR on touch: keep the approved gaps to the live jump button's edges (Roblox draws it 70 or 120 px, so its
			-- centre alone would put a big button over it): left of it -> gap to its left edge, over it (자동) -> centred;
			-- wholly above it -> gap to its top, else the offset to its middle
			if x >= rj[1] then
				X = jump.X + jump.W / 2 + (x + r[3] / 2 - rj[1] - rj[3] / 2) * k - w / 2
			else
				X = jump.X - (rj[1] - x) * k
			end
			if y + r[4] <= rj[2] then
				Y = jump.Y - (rj[2] - y) * k
			else
				Y = jump.Y + jump.H / 2 + (y - rj[2] - rj[4] / 2) * k
			end
		else -- BR
			X, Y = W - (ref.W - x) * k, H - (ref.H - y) * k
		end
		out[id] = rect(X, Y, w, h)
	end
	out.potions.Gap = POTION_GAP * k
	local tileGap = TILE_GAP * k

	if touch then
		-- portrait: grows from its top-left corner; the plate beside it gives way (same right edge), the tile row moves down
		local p = out.portrait
		if p.W < MIN_TAP then
			local g = MIN_TAP - p.W
			p.W, p.H = MIN_TAP, MIN_TAP
			for _, id in PLATE do
				local r = out[id]
				r.X, r.W = r.X + g, math.max(1, r.W - g)
			end
			out.tiles.Y += g
			out.menu.Y += g
		end
		-- quest lines: one MIN_TAP target (two text lines), grown downward
		if out.quest.H < MIN_TAP then out.quest.H = MIN_TAP end
		for _, id in ROUND_TAPS do
			local r = out[id]
			if r.W < MIN_TAP then
				r.X, r.Y, r.W, r.H = r.X + r.W / 2 - MIN_TAP / 2, r.Y + r.H / 2 - MIN_TAP / 2, MIN_TAP, MIN_TAP
			end
		end
		-- potions: two cells side by side (HP, MP), each >= MIN_TAP. The rect grows upwards, then to the left with the
		-- same right edge (Q sits right of it), but never into the thumbstick zone or onto an item level with it on the
		-- left; a phone without that room keeps the widest cells it can get (the offline test names it as an exception)
		local pot = out.potions
		if pot.H < MIN_TAP then pot.Y, pot.H = pot.Y + pot.H - MIN_TAP, MIN_TAP end
		local potRight = pot.X + pot.W
		local minX = potRight - (2 * MIN_TAP + pot.Gap)
		if pot.Y + pot.H > H * STICK.Y then minX = math.max(minX, W * STICK.X) end
		for oid, o in out do
			if oid ~= "potions" and not hidden[oid] and o.X + o.W <= pot.X + 0.01 and o.Y < pot.Y + pot.H and o.Y + o.H > pot.Y then
				minX = math.max(minX, o.X + o.W + GAP)
			end
		end
		if minX < pot.X then pot.X, pot.W = minX, potRight - minX end
	end

	-- tile row: square tiles as tall as the row (>= MIN_TAP on touch), Count = how many fit with the least gap
	local tiles = out.tiles
	local size = touch and math.max(tiles.H, MIN_TAP) or tiles.H
	tiles.H = size
	tiles.Size = size
	tiles.Gap = tileGap
	tiles.Count = math.max(1, math.floor((tiles.W + tileGap) / (size + tileGap) + 1e-6))
	-- [메뉴]: a square (>= MIN_TAP on touch) that keeps its right edge; on phones it ends the tile row (same line, the
	-- row stops one gap before it, so a grown [메뉴] takes a square from the row, never covers it)
	local menu = out.menu
	local mSize = touch and math.max(menu.H, MIN_TAP) or menu.H
	menu.X, menu.W, menu.H = menu.X + menu.W - mSize, mSize, mSize
	if touch then
		menu.Y = tiles.Y
		tiles.W = math.max(size, menu.X - tileGap - tiles.X)
		tiles.Count = math.max(1, math.floor((tiles.W + tileGap) / (size + tileGap) + 1e-6))
	end

	-- desktop: the bottom-centre group moves left (keeping its shape) when the corner cluster reaches it, but never past
	-- the left margin; if that is still not enough it is squeezed from its left edge (narrow 4:3 / 5:4 windows)
	if not touch then
		local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
		for _, id in BC_GROUP do
			local r = out[id]
			minX, maxX = math.min(minX, r.X), math.max(maxX, r.X + r.W)
			minY, maxY = math.min(minY, r.Y), math.max(maxY, r.Y + r.H)
		end
		local clusterLeft = math.huge
		for _, id in CLUSTER do
			local r = out[id]
			if not hidden[id] and r.Y < maxY and r.Y + r.H > minY then clusterLeft = math.min(clusterLeft, r.X) end
		end
		local limit = clusterLeft - GAP
		if maxX > limit then
			local shift = math.min(maxX - limit, math.max(0, minX - GAP))
			for _, id in BC_GROUP do out[id].X -= shift end
			minX, maxX = minX - shift, maxX - shift
			if maxX > limit and maxX - minX > 1 then
				local f = math.max(0.5, (limit - minX) / (maxX - minX))
				for _, id in BC_GROUP do
					local r = out[id]
					r.X = minX + (r.X - minX) * f
					if id ~= "portrait" then r.W *= f end
				end
				tiles.Count = math.max(1, math.floor((tiles.W + tileGap) / (size + tileGap) + 1e-6))
			end
		end
	end

	-- centre column (war meter, chips, next event, notify): the rows share one room (the tightest gap between the left
	-- and right items level with any of them) and one centre x, so the column stays straight and never runs under a
	-- neighbour on narrow phones / small windows
	local leftEdge, rightEdge = 0, W
	for _, id in CENTER do
		local c = out[id]
		for oid, o in out do
			local anchor = anchorOf(oid, touch)
			if not hidden[oid] and anchor ~= "TC" and anchor ~= "BC" and oid ~= "combo"
				and o.Y < c.Y + c.H and o.Y + o.H > c.Y then
				if o.X + o.W / 2 < W / 2 then
					leftEdge = math.max(leftEdge, o.X + o.W + GAP)
				else
					rightEdge = math.min(rightEdge, o.X - GAP)
				end
			end
		end
	end
	local room, widest = rightEdge - leftEdge, 0
	for _, id in CENTER do
		local r = out[id]
		local w = math.max(math.min(r.W, room), math.min(MIN_CENTER, r.W))
		r.W = w
		widest = math.max(widest, w)
	end
	local cx = math.clamp(W / 2, leftEdge + widest / 2, math.max(leftEdge + widest / 2, rightEdge - widest / 2))
	for _, id in CENTER do
		local r = out[id]
		r.X = cx - r.W / 2
	end

	-- everything stays on screen and below the top bar (big tablets / very short windows)
	for _, r in out do
		r.X = math.clamp(r.X, 0, math.max(0, W - r.W))
		r.Y = math.clamp(r.Y, top, math.max(top, H - r.H))
	end

	-- [메뉴] fold-out room: Lines = { { X, Y, Cols } } right-aligned one gap left of [메뉴]; each line reaches left to the
	-- nearest item it may not cover (an item level with it that reaches under [메뉴] leaves no room: the line closes). X / Y / W / H = the box
	-- around all lines, Cols = the first line's squares, Rows = #Lines
	local m = out.menu
	local fGap = touch and tileGap or FOLD_GAP * k -- phones: the tile row's gap (the first line lies on that row)
	local fSize = m.H
	local right = m.X - fGap
	local blockers = {}
	for oid, o in out do
		if not hidden[oid] and not FOLD_OVER[oid] and not (touch and FOLD_OVER_TOUCH[oid]) then table.insert(blockers, o) end
	end
	if touch then
		table.insert(blockers, rect(0, H * STICK.Y, W * STICK.X, H - H * STICK.Y))
		if jump then table.insert(blockers, jump) end
	end
	local function colsAt(y0)
		local left = 0
		for _, o in blockers do
			if o.Y < y0 + fSize and o.Y + o.H > y0 and o.X < m.X - 0.01 then
				left = math.max(left, o.X + o.W + GAP)
			end
		end
		return math.max(0, math.floor((right - left + fGap) / (fSize + fGap) + 1e-6))
	end
	local lines = {}
	local y, step = m.Y, (touch and -1 or 1) * (fSize + fGap)
	local x0, y0, y1 = right, math.huge, -math.huge
	while #lines < FOLD_ROWS and y >= top - 0.01 and y + fSize <= H + 0.01 do
		local cols = colsAt(y)
		if cols < 1 then break end
		local lx = right - cols * (fSize + fGap) + fGap
		table.insert(lines, { X = lx, Y = y, Cols = cols })
		x0, y0, y1 = math.min(x0, lx), math.min(y0, y), math.max(y1, y + fSize)
		y += step
	end
	if #lines == 0 then -- no room at all (a tiny window): one square over [메뉴]'s left neighbour
		lines[1] = { X = right - fSize, Y = m.Y, Cols = 1 }
		x0, y0, y1 = right - fSize, m.Y, m.Y + fSize
	end
	out.fold = { X = x0, Y = y0, W = right - x0, H = y1 - y0, Size = fSize, Gap = fGap, Cols = lines[1].Cols,
		Rows = #lines, Lines = lines }
	return out
end

function HudLayout.Init() end
function HudLayout.Start() end

return HudLayout
