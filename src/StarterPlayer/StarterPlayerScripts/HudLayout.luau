-- HudLayout.luau : A23-26 screen layout v2 as one pure function (no instances, no services).
-- The approved gray-box rectangles (docs/design/hud_layout_v2_2026-10-06.json) are real pixels on two reference
-- screens: desktop 1280x720 (MainGui UIScale 0.8) and phone 749x361 (UIScale 0.75), both with a 58 px top bar.
-- HudLayout.Compute turns them into MainGui logical units (before UIScale) for the current screen: every item keeps
-- its distance to the edge it belongs to (top-left / top-centre / top-right / bottom-right / bottom-centre), the
-- top rows follow the real top-bar inset, the phone combat cluster follows the real jump button, and the centre
-- column narrows between the left and right blocks on narrow screens.
local HudLayout = {}

-- reference screens of the approved sheet (real px)
local REF = {
	Desktop = { W = 1280, H = 720, Scale = 0.8, Inset = 58 },
	Touch = { W = 749, H = 361, Scale = 0.75, Inset = 58, Jump = { 654, 271, 70, 70 } },
}

-- id = { anchor, desktop { x, y, w, h }, touch { x, y, w, h } } (A23-26 v2, real px on the reference screens)
-- anchors: TL top-left, TC top-centre, TR top-right, BR bottom-right (touch: the jump button), BC bottom-centre
local ITEMS = {
	portrait = { "TL", { 10, 66, 64, 64 }, { 8, 62, 48, 48 } },
	hp_bar = { "TL", { 80, 68, 210, 18 }, { 60, 63, 150, 14 } },
	mp_bar = { "TL", { 80, 89, 210, 15 }, { 60, 79, 150, 12 } },
	power_line = { "TL", { 80, 107, 210, 16 }, { 60, 93, 150, 13 } },
	xp_bar = { "TL", { 10, 134, 280, 8 }, { 8, 112, 202, 6 } },
	minimap = { "TL", { 10, 148, 180, 180 }, { 8, 122, 96, 96 } },
	war_meter = { "TC", { 496, 66, 288, 46 }, { 255, 62, 240, 38 } },
	chips = { "TC", { 496, 116, 288, 21 }, { 241, 104, 267, 18 } },
	notify = { "TC", { 496, 141, 288, 117 }, { 241, 126, 267, 39 } },
	pet = { "TR", { 1062, 66, 51, 51 }, { 531, 62, 48, 48 } },
	bag = { "TR", { 1117, 66, 51, 51 }, { 585, 62, 48, 48 } },
	map = { "TR", { 1172, 66, 51, 51 }, { 639, 62, 48, 48 } },
	menu = { "TR", { 1227, 66, 51, 51 }, { 693, 62, 48, 48 } },
	quest = { "TR", { 980, 125, 290, 94 }, { 516, 116, 225, 36 } },
	combo = { "BC", { 580, 463, 120, 24 }, { 305, 236, 144, 20 } },
	potions = { "BR", { 926, 646, 122, 58 }, { 337, 298, 112, 54 } },
	ghost = { "BR", { 987, 577, 61, 61 }, { 590, 182, 57, 57 } },
	q = { "BR", { 1062, 588, 77, 77 }, { 455, 252, 72, 72 } },
	z = { "BR", { 1121, 510, 77, 77 }, { 497, 180, 72, 72 } },
	auto = { "BR", { 1213, 520, 51, 51 }, { 665, 215, 48, 48 } },
	attack = { "BR", { 1144, 584, 120, 120 }, { 534, 241, 112, 112 } },
}
HudLayout.Items = ITEMS
HudLayout.Ref = REF

local CENTER = { "war_meter", "chips", "notify" }
local MIN_CENTER = 240 -- logical units: narrowest centre column (spec final: the war meter stays >= 240du)
local GAP = 8
local LUCK = { Share = 0.36, Min = 120, Gap = 6 } -- the luck pill takes the left end of the chip row (A23-26)
-- touch targets never shrink below 60 logical units (~45 real px at the phone's 0.75 UIScale, spec final). A scaled
-- down button grows back: the portrait from its top-left corner (the bars beside it give way), the rail buttons from
-- the right edge with their spacing widened (RAIL_GAP), the round combat buttons around their centre, the potions upwards
local MIN_TAP = 60
local RAIL = { "menu", "map", "bag", "pet" } -- right to left
local RAIL_GAP = 4
local ROUND_TAPS = { "ghost", "q", "z", "auto", "attack" }

local function rect(x, y, w, h)
	return { X = x, Y = y, W = w, H = h }
end

-- env = { W, H = MainGui size in logical units, Scale = UIScale, Inset = top bar inset (real px), Touch = bool,
--         Jump = { X, Y, W, H } of the touch jump button in logical units or nil, Hidden = { [id] = true } }
-- returns { [id] = { X, Y, W, H } } in logical units (MainGui space, before UIScale)
function HudLayout.Compute(env)
	local touch = env.Touch == true
	local ref = touch and REF.Touch or REF.Desktop
	local k = 1 / ref.Scale -- reference px -> logical units
	local s = (type(env.Scale) == "number" and env.Scale > 0) and env.Scale or 1
	local W, H = env.W, env.H
	local top = (tonumber(env.Inset) or ref.Inset) / s -- logical y of the top bar's bottom edge
	local jump = touch and env.Jump or nil
	-- touch: a safe area narrower / shorter than the reference phone (notch insets: 749x361 -> 655x340) scales the
	-- whole layout down by the same factor, so the stick zone and the gaps stay free (검수 2026-10-06)
	if touch then
		k *= math.min(1, W / (ref.W / ref.Scale), H / (ref.H / ref.Scale))
	end
	local rj = touch and ref.Jump or nil -- the approved sheet's jump button (real px)
	local out = {}
	for id, def in ITEMS do
		local r = touch and def[3] or def[2]
		local x, y, w, h = r[1], r[2], r[3] * k, r[4] * k
		local anchor = def[1]
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

	if touch then
		-- portrait: grows from its top-left corner; the bars beside it give way (same right edge), the rows under it move down
		local p = out.portrait
		if p.W < MIN_TAP then
			local g = MIN_TAP - p.W
			p.W, p.H = MIN_TAP, MIN_TAP
			for _, id in { "hp_bar", "mp_bar", "power_line" } do
				local r = out[id]
				r.X, r.W = r.X + g, math.max(1, r.W - g)
			end
			out.xp_bar.Y += g
			out.minimap.Y += g
		end
		-- rail: from the right edge, every button >= MIN_TAP and >= RAIL_GAP apart; the quest board moves under it
		local first = out[RAIL[1]]
		local size = math.max(first.W, MIN_TAP)
		local refStep = (ITEMS[RAIL[1]][3][1] - ITEMS[RAIL[2]][3][1]) * k
		local step = math.max(refStep, size + RAIL_GAP)
		local right, grow = first.X + first.W, size - first.H
		for i, id in RAIL do
			local r = out[id]
			r.X, r.W, r.H = right - size - (i - 1) * step, size, size
		end
		if grow > 0 then out.quest.Y += grow end
		for _, id in ROUND_TAPS do
			local r = out[id]
			if r.W < MIN_TAP then
				r.X, r.Y, r.W, r.H = r.X + r.W / 2 - MIN_TAP / 2, r.Y + r.H / 2 - MIN_TAP / 2, MIN_TAP, MIN_TAP
			end
		end
		local pot = out.potions
		if pot.H < MIN_TAP then pot.Y, pot.H = pot.Y + pot.H - MIN_TAP, MIN_TAP end
	end

	-- centre column (war meter, chips, notify): the rows share one room (the tightest gap between the left and right
	-- items level with any of them) and one centre x, so the column stays straight and never runs under a neighbour
	-- on narrow phones / small windows
	local hidden = env.Hidden or {}
	local leftEdge, rightEdge = 0, W
	for _, id in CENTER do
		local c = out[id]
		for oid, o in out do
			if not hidden[oid] and ITEMS[oid] and ITEMS[oid][1] ~= "TC" and ITEMS[oid][1] ~= "BC"
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

	-- luck pill: left end of the chip row; the status chips use the rest of the row
	local chips = out.chips
	local lw = math.min(chips.W * 0.5, math.max(LUCK.Min, chips.W * LUCK.Share))
	out.luck = rect(chips.X, chips.Y, lw, chips.H)
	chips.X, chips.W = chips.X + lw + LUCK.Gap, chips.W - lw - LUCK.Gap

	-- everything stays on screen and below the top bar (big tablets / very short windows)
	for _, r in out do
		r.X = math.clamp(r.X, 0, math.max(0, W - r.W))
		r.Y = math.clamp(r.Y, top, math.max(top, H - r.H))
	end
	return out
end

function HudLayout.Init() end
function HudLayout.Start() end

return HudLayout
