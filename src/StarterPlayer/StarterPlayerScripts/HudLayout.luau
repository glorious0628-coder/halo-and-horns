-- HudLayout.luau : A23-40 screen layout B ("보여 준 게임처럼") as one pure function (no instances, no services).
-- The rectangles of docs/design/hud_layout_B_imgdev_2026-10-06.json are real pixels on two reference screens: desktop
-- 1280x720 (MainGui UIScale 0.8; the PC numbers are 검수's docs/design/hud_layout_B_2026-10-06.json) and phone 749x361
-- (UIScale 0.75; 이미지 개발 placed the phone by the A23-40 rules), both with a 58 px top bar.
-- HudLayout.Compute turns them into MainGui logical units (before UIScale) for the current screen: every item keeps its
-- distance to the edge it belongs to (top-left / top-centre / the top bar / bottom-centre / bottom-right), the top rows
-- follow the real top-bar inset, the phone thumb ring follows the real jump button, the centre column narrows between the
-- left and right blocks, and on PCs the bottom-centre group moves left when the corner cluster would cover it.
--   PC:    top-left round minimap + 2 quest lines under it, top-centre war meter -> chips -> next event -> notify,
--          bottom-centre face + 'Lv · 전투력' + HP | MP + XP + icon tile row + the potion pair, the skill column Q · Z · X
--          on the right edge over a smaller attack disc, top-right the [메뉴] tile (A23-40 정정: its tiles fold out to the
--          left; the Tab list opens under it).
--   phone (2026-10-07, user via 검수: "어쨌든 모바일로도 되어야" + the reference shot): the same reading as the PC - the
--          minimap with the quest lines under it top-left, [메뉴] in the top bar, the face / Lv line / HP | MP / XP and
--          under them the tile row bottom-centre, centred between the thumbstick zone and the thumb ring (it gives up
--          tiles to [메뉴] where the room is short); the thumb ring = the attack disc by the jump button with the HP and
--          MP potions and Q · Z · X on one ring around it (lower left to upper right), 자동 above the jump button and the
--          grudge ghost above the ring's left end.
--   A23-40 보강 (user 2026-10-06 "메뉴 위치랑 가운데 바가 로블록스 기본 메뉴랑 위치가 같으면 좋겠어"): on both, [메뉴] and the war
--          meter sit IN the Roblox top bar row (env.Topbar = GuiService.TopbarInset, the free part of the bar right of
--          Roblox's own buttons), on the same middle line as Roblox's buttons; [메뉴] is as big as a Roblox button
--          (TOPBAR.Button real px, >= MIN_TAP on touch) and TOPBAR.Edge px from the bar's free right end; both keep their
--          real px size on every UIScale. The chips, the next-event line and notify start right under the bar, and the
--          [메뉴] fold-out runs left along the bar first, then down.
local HudLayout = {}

-- reference screens of the approved sheets (real px)
local REF = {
	Desktop = { W = 1280, H = 720, Scale = 0.8, Inset = 58 },
	Touch = { W = 749, H = 361, Scale = 0.75, Inset = 58, Jump = { 654, 271, 70, 70 } },
}

-- id = { desktop anchor, desktop { x, y, w, h }, touch { x, y, w, h }, touch anchor (default: the desktop one) }
-- anchors: TL top-left, TC top-centre, TB the Roblox top bar, BC bottom-centre, BR bottom-right (touch: the jump button)
local ITEMS = {
	minimap = { "TL", { 14, 66, 150, 150 }, { 8, 62, 80, 80 } },
	quest = { "TL", { 14, 226, 300, 52 }, { 8, 146, 240, 45 } },
	-- TB = in the Roblox top bar: x like TC, centred on the bar's middle, its height in REAL px (Roblox's buttons do not
	-- follow our UIScale); the sheet's y = on the middle line of Roblox's buttons (34 px)
	war_meter = { "TB", { 496, 13, 288, 42 }, { 255, 15, 240, 38 } },
	-- 검수 2026-10-08 (A23-75 2x chip): the PC chip row as wide as the war meter, so Safe Zone · Rare · 2x XP and '+N' fit
	-- in town (248 px folded the 2x chip into '+2'); the next-event line keeps the chip row's width (A23-63)
	chips = { "TC", { 496, 62, 288, 22 }, { 255, 62, 240, 17 } },
	-- A23-63 (2026-10-07): as wide as the chip row on PC and the whole column on phones - Montserrat runs wider and the
	-- king pill ("Pumpkin King is here! 4:54 left") was squeezed to 150 x 16 px with its words spilling out
	event = { "TC", { 496, 88, 288, 22 }, { 255, 81, 240, 18 } },
	notify = { "TC", { 496, 116, 288, 46 }, { 255, 100, 240, 34 } },
	portrait = { "BC", { 387, 586, 50, 50 }, { 225, 248, 45, 45 } },
	power_line = { "BC", { 445, 578, 449, 16 }, { 275, 250, 140, 14 } },
	hp_bar = { "BC", { 445, 598, 220, 20 }, { 275, 267, 68, 12 } },
	mp_bar = { "BC", { 673, 598, 221, 20 }, { 347, 267, 68, 12 } },
	xp_bar = { "BC", { 445, 622, 449, 8 }, { 275, 282, 140, 5 } },
	tiles = { "BC", { 445, 640, 327, 52 }, { 225, 296, 190, 45 } },
	-- A23-40 정정 + 보강: [메뉴] in the top bar's right end (TB anchor; size and position come from TOPBAR, the rects are
	-- the 1280x720 / 749x361 results). out.fold = its fold-out room
	menu = { "TB", { 1224, 12, 44, 44 }, { 692, 12, 45, 45 } },
	combo = { "BC", { 580, 463, 120, 24 }, { 520, 110, 144, 20 }, "BR" },
	-- PC combat (검수 2026-10-07 with the user's reference shot: "이렇게 … 똑같이 하지 말고 더 낫게"): a mouse / keyboard player
	-- reads keys, not thumbs. The potions (keys 1 · 2) sit right after the icon row (six tiles wide), part of the
	-- bottom-centre group: face, bars and the tiles + potions row make one block centred on the screen; the
	-- skills Q · Z · X are one column on the right edge (their key badges in reading order, like an action bar); the
	-- attack (left click / F) is a smaller disc under the column with 자동 and the grudge ghost left of it.
	-- Phones (검수 2026-10-07: "공격·스킬·물약을 엄지가 닿는 곳에 깔끔한 묶음으로", not two lone [Buy] buttons by the attack):
	-- one thumb ring - the attack disc left of the jump button, the HP and MP potions and Q · Z · X on one circle around
	-- it (centres 82 px from the attack's centre, 5 px apart, lower left to upper right: HP · MP · Q · Z · X; X clears the
	-- jump button), 자동 above the jump button, the grudge ghost above the ring's left end (A23-49: three skills Q · Z ·
	-- X, docs/design/skill_kit_beta_2026-10-06.md). The two potions are round buttons of their own (out.potions = the
	-- box around both with Cells, for VitalsUI.PlacePotions)
	potion_hp = { "BC", { 784, 640, 52, 52 }, { 500, 305, 46, 46 }, "BR" },
	potion_mp = { "BC", { 842, 640, 52, 52 }, { 496, 254, 46, 46 }, "BR" },
	ghost = { "BR", { 1050, 630, 61, 61 }, { 475, 161, 50, 50 } },
	q = { "BR", { 1199, 392, 66, 66 }, { 523, 204, 54, 54 } },
	z = { "BR", { 1199, 466, 66, 66 }, { 580, 188, 54, 54 } },
	x = { "BR", { 1199, 540, 66, 66 }, { 633, 215, 54, 54 } },
	auto = { "BR", { 1124, 634, 52, 52 }, { 694, 164, 44, 44 } },
	attack = { "BR", { 1186, 620, 80, 80 }, { 550, 248, 98, 98 } },
}
HudLayout.Items = ITEMS
HudLayout.Ref = REF

local CENTER = { "war_meter", "chips", "event", "notify" }
-- the Roblox top bar row (real px, UiSandbox PC + phones 2026-10-06): Left = where Roblox's own buttons end when Roblox
-- reports no TopbarInset (164), Button = their height in a 58 px bar (smaller bars: Inset - 4), Bottom = their gap to the
-- bar's bottom (44 px buttons at y 12..56: middle 34 px), Edge = the gap we keep from the bar's free right end, Tap = the
-- touch floor of [메뉴] (= MIN_TAP at the phone's 0.75 UIScale)
local TOPBAR = { Left = 164, Button = 44, Bottom = 2, Edge = 12, Tap = 45 }
HudLayout.Topbar = TOPBAR
local FOLD_MIN = 4 -- the [메뉴] squares that must fit beside it on the bar (새 소식 · 이동 · 도움말 · 설정)
local MIN_CENTER = 240 -- logical units: narrowest centre column (the war meter stays >= 240du)
-- review 2026-10-07 (user: "이거 위치 왜이래?" on a short Studio window): a mouse / keyboard PC always lays out on the
-- desktop sheet, however small the window; short windows get a smaller UIScale instead (Config.UI.DesktopScaleMin 0.5),
-- which keeps the desktop layout's top and bottom blocks apart. The phone sheet is for touch only (replaces SMALL_PC)
local GAP = 8
-- touch targets never shrink below 60 logical units (~45 real px at the phone's 0.75 UIScale). A scaled down button
-- grows back: the round combat buttons and potions around their centre, the quest lines downwards; in the bottom-centre
-- group the face from its bottom-left corner and the tile row upwards
local MIN_TAP = 60
local ROUND_TAPS = { "ghost", "q", "z", "x", "auto", "attack", "potion_hp", "potion_mp" }
local POTION_GAP = 6 -- real px between the HP and MP buttons on the PC sheet (out.potions.Gap, in du)
HudLayout.PotionGap = POTION_GAP
local TILE_GAP = 3 -- real px: the least gap between two tiles of the icon row (out.tiles.Gap, in du)
-- touch thumbstick zone: x < 0.3 W and y > 0.54 H, nothing pressable there (2026-10-07 phone layout: the quest lines hang
-- under the minimap above the thumb's rest; Roblox's thumbstick appears where the thumb lands in the lower left and rests
-- around Mid = 0.2 W). 검수 2026-10-07 ("폰 아래 묶음 가운데"): the bottom-centre group is as wide as the room right of
-- Room = 0.4 W and sits centred between the thumbstick's rest and the thumb ring (left edge 0.3 W on the reference phones)
local STICK = { X = 0.3, Y = 0.54, Mid = 0.2, Room = 0.4 }
-- the bottom-centre group (face, power line, bars, XP, tiles; PCs: the potions right of the tiles) and the corner cluster
-- it must stay clear of (touch: the thumb ring, potions included)
local BC_GROUP = { "portrait", "power_line", "hp_bar", "mp_bar", "xp_bar", "tiles", "potion_hp", "potion_mp" }
local CLUSTER = { "ghost", "q", "z", "x", "auto", "attack" }
local RING = { "potion_hp", "potion_mp", "ghost", "q", "z", "x", "auto", "attack" }
local RING_BUTTONS = { "potion_hp", "potion_mp", "q", "z", "x" } -- the buttons on the ring itself (lower left -> upper right)
local BARS = { "power_line", "hp_bar", "mp_bar", "xp_bar" } -- touch: they run from the face to the tile row's right end
local BAR_GAP = 5 -- real px between the face and the bars, and between HP and MP, on the phone sheet
local ROW_MAX = 6 -- touch: the bottom group grows up to this many tiles wide where the room allows (the icon row's windows)
-- small PC windows (main Studio 2026-10-08, 991x451 -> UIScale 0.5): real-px floors for the quest lines' width, the
-- HP / MP bars' height ("Get your first wea...", bar numbers ~6 px) and the notify column's width: as wide as on the
-- 1280x720 sheet (a two-line notice kept one cut line, "First mission: Free the...": its words never go under 11 real px,
-- Config.UI.MinTextSize); the centre column's room still clamps it on the narrowest windows
local PC_FLOOR = { QuestW = 250, Bar = 14, NotifyW = 288 }
-- [메뉴] fold-out: lines of squares as big as [메뉴], filled from [메뉴] to the left. The first line is [메뉴]'s own (in the
-- top bar, never over Roblox's buttons); more lines go down (A23-38's "위쪽에서만": [메뉴] is the topmost thing now).
-- While open it may run over the centre column's info rows (chips / next event / notify), but never over the war meter,
-- the minimap, the quest lines, the face group, a combat button, the jump button or the thumbstick zone
local FOLD_OVER = { menu = true, chips = true, event = true, notify = true, combo = true }
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
--         Jump = { X, Y, W, H } of the touch jump button in logical units or nil, Hidden = { [id] = true },
--         Topbar = { X0, Y0, X1, Y1 } = the free part of the Roblox top bar (GuiService.TopbarInset) in logical units
--         (MainGui space) or nil (then TOPBAR.Left .. W, 0 .. Inset) }
-- returns { [id] = { X, Y, W, H } } in logical units (MainGui space, before UIScale). potions (derived) = the box around
-- potion_hp and potion_mp with Gap (du between them on PCs) and Cells = { HP, MP } (the two button rects); tiles carries
-- Size (square tile side), Gap (least gap) and Count (how many tiles fit the row: the HUD shows that many, the rest go
-- into the [메뉴] fold-out)
function HudLayout.Compute(env)
	local touch = env.Touch == true
	-- sheet = which approved sheet the rects come from (the phone one on touch only); touch = the finger rules
	local sheet = touch
	local ref = sheet and REF.Touch or REF.Desktop
	local k = 1 / ref.Scale -- reference px -> logical units
	local s = (type(env.Scale) == "number" and env.Scale > 0) and env.Scale or 1
	local W, H = env.W, env.H
	local top = (tonumber(env.Inset) or ref.Inset) / s -- logical y of the top bar's bottom edge
	local jump = touch and env.Jump or nil
	local hidden = env.Hidden or {}
	-- the Roblox top bar row (logical units): its free part and the button size there (real px -> du, no UIScale)
	local tb = type(env.Topbar) == "table" and env.Topbar or nil
	local bar = {
		X0 = tb and tonumber(tb.X0) or TOPBAR.Left / s,
		Y0 = tb and tonumber(tb.Y0) or 0,
		X1 = tb and tonumber(tb.X1) or W,
		Y1 = tb and tonumber(tb.Y1) or top,
	}
	if not (bar.X1 > bar.X0 and bar.Y1 > bar.Y0) then bar = { X0 = TOPBAR.Left / s, Y0 = 0, X1 = W, Y1 = top } end
	local barPx = (bar.Y1 - bar.Y0) * s
	local btn = math.min(TOPBAR.Button, math.max(1, barPx - 4)) / s
	-- the middle of Roblox's own buttons (they sit TOPBAR.Bottom px above the bar's bottom): ours share it
	local barMid = bar.Y1 - TOPBAR.Bottom / s - btn / 2
	-- touch: a safe area narrower / shorter than the reference phone (notch insets: 749x361 -> 655x340) scales the
	-- whole layout down by the same factor, so the stick zone and the gaps stay free
	if sheet then
		k *= math.min(1, W / (ref.W / ref.Scale), H / (ref.H / ref.Scale))
	end
	local rj = touch and ref.Jump or nil -- the approved sheet's jump button (real px)
	-- touch: the thumb cluster (the BR items: attack, ring, 자동, ghost, combo) is one rigid shape. The attack keeps its
	-- approved gaps to the live jump button (left edge, middle; Roblox draws it 70 or 120 px), every other BR item its sheet
	-- offset from the attack's centre, all at one scale kc that never lets the smallest ring button fall below MIN_TAP (so
	-- nothing grows into its neighbour on small phones)
	local kc, ac = k, nil
	if jump and rj then
		local ringMin = math.huge
		for _, id in RING_BUTTONS do ringMin = math.min(ringMin, ITEMS[id][3][3]) end
		kc = math.max(k, MIN_TAP / ringMin)
		local ra = ITEMS.attack[3]
		ac = { X = jump.X - (rj[1] - ra[1]) * kc + ra[3] * kc / 2,
			Y = jump.Y + jump.H / 2 + (ra[2] + ra[4] / 2 - rj[2] - rj[4] / 2) * kc, SX = ra[1] + ra[3] / 2, SY = ra[2] + ra[4] / 2 }
	end
	local out = {}
	for id, def in ITEMS do
		local r = sheet and def[3] or def[2]
		local x, y, w, h = r[1], r[2], r[3] * k, r[4] * k
		local anchor = anchorOf(id, sheet)
		local X, Y
		if anchor == "TL" then
			X, Y = x * k, top + (y - ref.Inset) * k
		elseif anchor == "TC" then
			X, Y = W / 2 + (x - ref.W / 2) * k, top + (y - ref.Inset) * k
		elseif anchor == "TB" then
			-- in the Roblox top bar: centred on its middle, as tall as on the sheet in real px (never taller than a button)
			h = math.min(r[4], TOPBAR.Button, math.max(1, barPx - 4)) / s
			X, Y = W / 2 + (x - ref.W / 2) * k, barMid - h / 2
		elseif anchor == "BC" then
			X, Y = W / 2 + (x - ref.W / 2) * k, H - (ref.H - y) * k
		elseif ac then
			-- BR on touch: the rigid thumb cluster around the attack's centre (kc above; the combo line keeps the screen's
			-- scale k - text over the cluster, never wider than the centre column allows on small phones)
			if id ~= "combo" then w, h = r[3] * kc, r[4] * kc end
			X = ac.X + (x + r[3] / 2 - ac.SX) * kc - w / 2
			Y = ac.Y + (y + r[4] / 2 - ac.SY) * kc - h / 2
		else -- BR
			X, Y = W - (ref.W - x) * k, H - (ref.H - y) * k
		end
		out[id] = rect(X, Y, w, h)
	end
	local tileGap = TILE_GAP * k

	-- PC floors (PC_FLOOR): the quest lines widen to the right; the HP / MP bars grow upwards with the power line and the
	-- face, so the XP bar and the tile row keep their places
	if not sheet then
		-- the quest lines widen only up to a GAP before an item level with them (the combo line on short windows)
		local q = out.quest
		local qw = math.max(q.W, PC_FLOOR.QuestW / s)
		for oid, o in out do
			if oid ~= "quest" and oid ~= "minimap" and o.X > q.X and o.Y < q.Y + q.H and o.Y + o.H > q.Y then
				qw = math.min(qw, o.X - GAP - q.X)
			end
		end
		q.W = math.max(q.W, qw)
		local hb, mb = out.hp_bar, out.mp_bar
		local d = PC_FLOOR.Bar / s - hb.H
		if d > 0 then
			hb.Y, hb.H = hb.Y - d, hb.H + d
			mb.Y, mb.H = mb.Y - d, mb.H + d
			out.power_line.Y -= d
			out.portrait.Y -= d
		end
	end

	if touch then
		-- quest lines: one MIN_TAP target (two text lines), grown downward
		if out.quest.H < MIN_TAP then out.quest.H = MIN_TAP end
		for _, id in ROUND_TAPS do
			local r = out[id]
			if r.W < MIN_TAP then
				r.X, r.Y, r.W, r.H = r.X + r.W / 2 - MIN_TAP / 2, r.Y + r.H / 2 - MIN_TAP / 2, MIN_TAP, MIN_TAP
			end
		end
		-- 2026-10-07 phone layout (user via 검수: "어쨌든 모바일로도 되어야" + the reference shot): the bottom-centre group sits
		-- between the thumbstick zone and the thumb ring. Thumb sizes first, growing upwards so the tile row keeps its
		-- bottom: the row, the face from its bottom-left corner (the bars ride up with the row)
		local face, tl = out.portrait, out.tiles
		local rowBottom = tl.Y + tl.H
		local rowH = math.max(tl.H, MIN_TAP)
		local lift = rowH - tl.H
		for _, id in BARS do out[id].Y -= lift end
		face.Y -= lift
		tl.Y, tl.H = rowBottom - rowH, rowH
		if face.W < MIN_TAP then
			local g = MIN_TAP - face.W
			face.Y, face.W, face.H = face.Y - g, MIN_TAP, MIN_TAP
		end
		-- across: the group's width is the room from STICK.Room to a GAP left of the ring buttons level with the bars and
		-- the row (the face may stand above the bars at the group's left end), up to ROW_MAX tiles wide; it sits centred
		-- between the thumbstick's rest (STICK.Mid) and those buttons ("조이스틱과 전투 버튼 사이 가운데", 검수 2026-10-07),
		-- never left of the thumbstick zone (STICK.X; defensive: the centred group starts there at the latest). The tile row
		-- spans the group (tiles that do not fit go to [메뉴]), the bars run from the face to the group's right end, HP and
		-- MP halves BAR_GAP apart
		local limit = W
		for _, id in RING do
			local r = out[id]
			if not hidden[id] and r.Y < rowBottom and r.Y + r.H > out.power_line.Y then limit = math.min(limit, r.X - GAP) end
		end
		local edge, mid = W * STICK.X, W * STICK.Mid
		local room = math.max(0, limit - W * STICK.Room)
		local gw = math.min(room, ROW_MAX * rowH + (ROW_MAX - 1) * tileGap)
		local left = math.max(edge, mid + (limit - mid - gw) / 2)
		local right = left + gw
		local barGap = BAR_GAP * k
		tl.X, tl.W = left, gw
		face.X = left
		local bx = face.X + face.W + barGap
		local bw = math.max(1, right - bx)
		local half = math.max(1, (bw - barGap) / 2)
		out.power_line.X, out.power_line.W = bx, bw
		out.xp_bar.X, out.xp_bar.W = bx, bw
		out.hp_bar.X, out.hp_bar.W = bx, half
		out.mp_bar.X, out.mp_bar.W = bx + half + barGap, half
	end

	-- tile row: square tiles as tall as the row (touch: the row already grew to MIN_TAP), Count = how many fit with the
	-- least gap
	local tiles = out.tiles
	local size = tiles.H
	tiles.Size = size
	tiles.Gap = tileGap
	tiles.Count = math.max(touch and 0 or 1, math.floor((tiles.W + tileGap) / (size + tileGap) + 1e-6))
	-- [메뉴]: a Roblox-button-sized square in the top bar, TOPBAR.Edge px from its free right end, centred on the bar's
	-- middle like Roblox's own buttons (A23-40 보강); on touch never under TOPBAR.Tap real px (= MIN_TAP at the phone's
	-- 0.75 UIScale; on tablets MIN_TAP du would no longer fit the 58 px bar)
	local menu = out.menu
	local mSize = touch and math.max(btn, TOPBAR.Tap / s) or btn
	menu.W, menu.H = mSize, mSize
	menu.X = bar.X1 - TOPBAR.Edge / s - mSize
	menu.Y = barMid - mSize / 2
	-- (2026-10-07 phone layout: touch keeps [메뉴] in the bar too, like the reference shot; review 2026-10-07 had moved it
	-- under the bar after MCP taps missed it under phone emulation, whose clicks are offset - a real phone test decides)

	-- desktop: the bottom-centre group moves left (keeping its shape) when the corner cluster reaches it, but never past
	-- the left margin; if that is still not enough it is squeezed from its left edge (narrow 4:3 / 5:4 windows)
	if not sheet then
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
				-- the right end comes in to the limit (narrow 4:3-ish windows): the face and the starts of the bars and the
				-- row stay, the potion pair keeps its size and gaps at the right end, the tile row gives up its right part
				-- (tiles that no longer fit go to [메뉴]) and the bars end with the pair, HP and MP halves keeping their gap
				local hp, mp = out.potion_hp, out.potion_mp
				local lead, cut = hp.X - (tiles.X + tiles.W), maxX - limit
				mp.X -= cut
				hp.X -= cut
				tiles.W = math.max(0, hp.X - lead - tiles.X)
				out.power_line.W -= cut
				out.xp_bar.W -= cut
				local hb, mb = out.hp_bar, out.mp_bar
				local barGap = mb.X - (hb.X + hb.W)
				local half = math.max(1, (out.power_line.W - barGap) / 2)
				hb.W = half
				mb.X, mb.W = hb.X + half + barGap, half
				tiles.Count = math.max(1, math.floor((tiles.W + tileGap) / (size + tileGap) + 1e-6))
			end
		end
	end

	-- centre column (war meter, chips, next event, notify): the rows share one room (the tightest gap between the left
	-- and right items level with any of them) and one centre x, so the column stays straight and never runs under a
	-- neighbour on narrow phones / small windows
	-- In the top bar row the left neighbour is Roblox's own buttons and the right one [메뉴] with room for FOLD_MIN fold
	-- squares beside it (the war meter never takes the fold's first line)
	local leftEdge, rightEdge = 0, W
	local fGapRow = FOLD_GAP * k
	for _, id in CENTER do
		local c = out[id]
		for oid, o in out do
			local anchor = anchorOf(oid, sheet)
			if not hidden[oid] and anchor ~= "TC" and anchor ~= "BC" and oid ~= "combo" and oid ~= "war_meter"
				and o.Y < c.Y + c.H and o.Y + o.H > c.Y then
				if o.X + o.W / 2 < W / 2 then
					leftEdge = math.max(leftEdge, o.X + o.W + GAP)
				elseif oid == "menu" then
					rightEdge = math.min(rightEdge, o.X - FOLD_MIN * (o.W + fGapRow) - GAP)
				else
					rightEdge = math.min(rightEdge, o.X - GAP)
				end
			end
		end
		if c.Y < bar.Y1 and c.Y + c.H > bar.Y0 then leftEdge = math.max(leftEdge, bar.X0 + GAP) end
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
	-- small PC windows (UiSandbox 2026-10-08): that shared room is the top bar's (Roblox's buttons .. [메뉴]'s fold); the
	-- notify column sits lower, so it widens back to PC_FLOOR.NotifyW around the same centre over its own row's room
	if not sheet then
		local n = out.notify
		local want = PC_FLOOR.NotifyW / s
		if n.W < want then
			local l, r = 0, W
			for oid, o in out do
				if oid ~= "notify" and not hidden[oid] and o.Y < n.Y + n.H and o.Y + o.H > n.Y then
					if o.X + o.W / 2 < cx then l = math.max(l, o.X + o.W + GAP) else r = math.min(r, o.X - GAP) end
				end
			end
			local half = math.min(want / 2, cx - l, r - cx)
			if half * 2 > n.W then n.X, n.W = cx - half, half * 2 end
		end
	end

	-- everything stays on screen and below the top bar (big tablets / very short windows); the top bar items stay in it
	for id, r in out do
		r.X = math.clamp(r.X, 0, math.max(0, W - r.W))
		if anchorOf(id, sheet) == "TB" then
			r.Y = math.clamp(r.Y, bar.Y0, math.max(bar.Y0, bar.Y1 - r.H))
		else
			r.Y = math.clamp(r.Y, top, math.max(top, H - r.H))
		end
	end

	-- [메뉴] fold-out room: Lines = { { X, Y, Cols } } right-aligned one gap left of [메뉴]; each line reaches left to the
	-- nearest item it may not cover (an item level with it that reaches under [메뉴] leaves no room: the line closes). X / Y / W / H = the box
	-- around all lines, Cols = the first line's squares, Rows = #Lines
	local m = out.menu
	local fGap = FOLD_GAP * k
	local fSize = m.H
	local right = m.X - fGap
	local blockers = {}
	for oid, o in out do
		if not hidden[oid] and not FOLD_OVER[oid] then table.insert(blockers, o) end
	end
	table.insert(blockers, rect(0, bar.Y0, bar.X0, bar.Y1 - bar.Y0)) -- Roblox's own top bar buttons
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
	-- the first line on [메뉴]'s own line in the top bar, the next ones from just under the bar down (mouse and touch)
	local lines = {}
	local y, step = m.Y, fSize + fGap
	local x0, y0, y1 = right, math.huge, -math.huge
	local yMin = math.min(top, bar.Y0)
	while #lines < FOLD_ROWS and y >= yMin - 0.01 and y + fSize <= H + 0.01 do
		local cols = colsAt(y)
		if cols < 1 then break end
		local lx = right - cols * (fSize + fGap) + fGap
		table.insert(lines, { X = lx, Y = y, Cols = cols })
		x0, y0, y1 = math.min(x0, lx), math.min(y0, y), math.max(y1, y + fSize)
		y = math.max(y + step, top + fGap)
	end
	if #lines == 0 then -- no room at all (a tiny window): one square over [메뉴]'s left neighbour
		lines[1] = { X = right - fSize, Y = m.Y, Cols = 1 }
		x0, y0, y1 = right - fSize, m.Y, m.Y + fSize
	end
	out.fold = { X = x0, Y = y0, W = right - x0, H = y1 - y0, Size = fSize, Gap = fGap, Cols = lines[1].Cols,
		Rows = #lines, Lines = lines }
	-- the potion pair for VitalsUI.PlacePotions: the box around both buttons, Gap and Cells (each button's own rect)
	local ph, pm = out.potion_hp, out.potion_mp
	local px0, py0 = math.min(ph.X, pm.X), math.min(ph.Y, pm.Y)
	out.potions = { X = px0, Y = py0, W = math.max(ph.X + ph.W, pm.X + pm.W) - px0,
		H = math.max(ph.Y + ph.H, pm.Y + pm.H) - py0, Gap = POTION_GAP * k, Cells = { HP = ph, MP = pm } }
	return out
end

function HudLayout.Init() end
function HudLayout.Start() end

return HudLayout
