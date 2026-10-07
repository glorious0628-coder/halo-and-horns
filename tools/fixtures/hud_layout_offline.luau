-- Offline checks for HudLayout.Compute (A23-40 layout B). The runner (tools/test_hud_layout.py) prepends:
--   HUDLAYOUT_SOURCE : the current src/StarterPlayer/StarterPlayerScripts/HudLayout.luau text
--   V2               : the approved rects of docs/design/hud_layout_B_imgdev_2026-10-06.json { Items = { { Id, Round,
--                      Pc, Phone } }, Zones = { { Name, Pc, Phone } } } (real px on 1280x720 / 749x361)
--   CASES            : screens { Name, Base, Pouch, Touch, Ref, Supported, PxW, PxH, Env = { W, H, Scale, Inset, Touch,
--                      Jump } } (Env in MainGui logical units, as HUD.luau passes it; Jump = the TouchGui JumpButton rect)
--   EXCEPTIONS       : { { Screen, Check, Reason } } named, explained screens (by Base) where a check cannot hold for lack
--                      of room; the excepted check is replaced by a weaker one and the case is listed in the report
-- Every check is named (case :: check) and collected, never asserted, so a mutation shows up as a new failing name.
-- No Studio, Roblox API or network calls.

local Named, order = {}, {}
local checks, failed = 0, 0
local function check(group, name, ok, detail)
	checks += 1
	local key = group .. " :: " .. name
	local n = Named[key]
	if not n then
		n = { Group = group, Name = name, Pass = 0, Fail = 0 }
		Named[key] = n
		table.insert(order, key)
	end
	if ok then
		n.Pass += 1
	else
		n.Fail += 1
		failed += 1
		if not n.FirstFailure then n.FirstFailure = tostring(detail or "") end
		print(("CHECK_FAIL %s :: %s :: %s"):format(group, name, tostring(detail or "")))
	end
end

local function execute(text, env)
	local fn, err = loadstring(text)
	assert(fn, err)
	setfenv(fn, setmetatable(env or {}, { __index = getfenv() }))
	return fn()
end

----------------------------------------------------------------- tiny JSON writer (results for the runner)
local function encode(v)
	local t = type(v)
	if t == "nil" then return "null" end
	if t == "boolean" then return v and "true" or "false" end
	if t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return "null" end
		return (string.format("%.4f", v):gsub("%.?0+$", ""))
	end
	if t == "string" then
		return '"' .. v:gsub('[%c"\\]', function(c)
			if c == '"' then return '\\"' end
			if c == "\\" then return "\\\\" end
			return string.format("\\u%04x", string.byte(c))
		end) .. '"'
	end
	if #v > 0 or next(v) == nil then
		local parts = {}
		for _, x in ipairs(v) do table.insert(parts, encode(x)) end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local keys = {}
	for k in v do table.insert(keys, tostring(k)) end
	table.sort(keys)
	local parts = {}
	for _, k in keys do table.insert(parts, encode(k) .. ":" .. encode(v[k])) end
	return "{" .. table.concat(parts, ",") .. "}"
end

----------------------------------------------------------------- geometry
local function finite(x) return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge end

-- signed gap between two rects (negative = they overlap by that much on the tighter axis)
local function rectGap(a, b)
	local dx = math.max(b.X - (a.X + a.W), a.X - (b.X + b.W))
	local dy = math.max(b.Y - (a.Y + a.H), a.Y - (b.Y + b.H))
	if dx < 0 and dy < 0 then return math.max(dx, dy) end
	if dx < 0 then return dy end
	if dy < 0 then return dx end
	return math.sqrt(dx * dx + dy * dy)
end

-- circles are measured as circles (the inscribed circle of a round item's square)
local function gap(a, aRound, b, bRound)
	if aRound and bRound then
		local ax, ay, ar = a.X + a.W / 2, a.Y + a.H / 2, math.min(a.W, a.H) / 2
		local bx, by, br = b.X + b.W / 2, b.Y + b.H / 2, math.min(b.W, b.H) / 2
		return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) - ar - br
	end
	if aRound or bRound then
		local c, r = aRound and a or b, aRound and b or a
		local cx, cy, cr = c.X + c.W / 2, c.Y + c.H / 2, math.min(c.W, c.H) / 2
		local px = math.clamp(cx, r.X, r.X + r.W)
		local py = math.clamp(cy, r.Y, r.Y + r.H)
		local d = math.sqrt((cx - px) ^ 2 + (cy - py) ^ 2)
		if cx >= r.X and cx <= r.X + r.W and cy >= r.Y and cy <= r.Y + r.H then return -cr end
		return d - cr
	end
	return rectGap(a, b)
end

local function inter(a, b) -- rect intersection area > 0
	return math.min(a.X + a.W, b.X + b.W) - math.max(a.X, b.X) > 0.01
		and math.min(a.Y + a.H, b.Y + b.H) - math.max(a.Y, b.Y) > 0.01
end

local function fmt(r)
	if type(r) ~= "table" then return tostring(r) end
	return ("(%.1f,%.1f %.1fx%.1f)"):format(r.X or 0 / 0, r.Y or 0 / 0, r.W or 0 / 0, r.H or 0 / 0)
end

----------------------------------------------------------------- what the checks need to know
local ROUND = {}
for _, it in V2.Items do
	if it.Round then ROUND[it.Id] = true end
end
ROUND.minimap = nil -- measured as its square box (the round view sits inside it)
-- interactive = something a finger / mouse presses (the minimap, chips, event, notify, combo, bars are passive displays;
-- the minimap is drawn with Active = false)
local INTERACTIVE = { portrait = true, quest = true, tiles = true, menu = true, potions = true,
	ghost = true, q = true, z = true, x = true, auto = true, attack = true }
local TAPS = { "portrait", "ghost", "q", "z", "x", "auto", "attack", "menu" }
local MIN_TAP = 60 -- logical units (>= 45 real px at the phone's 0.75 UIScale)
local MIN_PRESS_GAP = 2 -- logical units between any two pressable items (touching buttons are a regression)
local POTION_GAP_PX = 6 -- real px between the HP and MP potion cells on both reference sheets
local TILE_GAP_PX = 3 -- real px on the reference screens: least gap between two tiles of the icon row
local FACE = { "portrait", "power_line", "hp_bar", "mp_bar", "xp_bar", "tiles" }
local LEFT_BAND = { "minimap", "quest" }
local CENTER = { "war_meter", "chips", "event", "notify" }
local CLUSTER = { "potions", "ghost", "q", "z", "x", "auto", "attack" }
local REF_SCALE = { Desktop = 0.8, Touch = 0.75 }
-- A23-40 정정: the [메뉴] fold-out (out.fold) never covers these while open (it may cover the chips / next event /
-- notify rows and, on phones, the tile row it replaces); ROW_TILES = the icon row's windows (phones fold the overflow)
local FOLD_PROTECT = { "minimap", "quest", "war_meter", "potions", "ghost", "q", "z", "x", "auto", "attack" }
local FOLD_PROTECT_PC = { "portrait", "power_line", "hp_bar", "mp_bar", "xp_bar", "tiles" } -- phones fold up over these
local MENU_TILES = 4 -- 새 소식 · 이동 · 도움말 · 설정
-- A23-40 보강: these sit IN the Roblox top bar row (centred on its middle, inside its free part), not below it
local TOP_BAR = { war_meter = true, menu = true }
local ROBLOX_BUTTON_PX = 44 -- Roblox's top bar button height in a 58 px bar (Inset - 4 in smaller bars)
local MENU_EDGE_PX = 12 -- [메뉴] keeps this from the bar's free right end
local ROW_TILES = 6 -- 캐릭터 · 가방 · 스킬 · 지도 · 랭킹 · 펫

local function excepted(case, name)
	for _, e in EXCEPTIONS do
		if e.Screen == case.Base and e.Check == name then return e end
	end
	return nil
end

local results, exceptions = {}, {}
for _, case in CASES do
	local g = case.Name
	local env = case.Env
	local ok, out = pcall(function()
		local HudLayout = execute(HUDLAYOUT_SOURCE)
		return HudLayout.Compute(table.clone(env))
	end)
	check(g, "Compute runs", ok and type(out) == "table", ok and "no table" or out)
	if not ok or type(out) ~= "table" then continue end
	local W, H, s = env.W, env.H, env.Scale
	local top = env.Inset / s
	local touch = env.Touch == true
	-- the approved sheet the rects follow: the phone one on touch only (short PC windows: desktop sheet, smaller UIScale)
	local sheet = case.Sheet == true
	-- the Roblox top bar's free part (GuiService.TopbarInset) as HUD.luau passes it
	local bar = env.Topbar or { X0 = 164 / s, Y0 = 0, X1 = W, Y1 = top }
	local buttonPx = math.min(ROBLOX_BUTTON_PX, env.Inset - 4)
	-- Roblox's own buttons sit 2 px above the bar's bottom (44 px buttons at y 12..56 in the 58 px bar, UiSandbox)
	local barMid = bar.Y1 - (2 + buttonPx / 2) / s
	local rects = {}
	for id, r in out do
		rects[id] = { X = r.X, Y = r.Y, W = r.W, H = r.H, Gap = r.Gap, Size = r.Size, Count = r.Count, Cols = r.Cols,
			Rows = r.Rows, Lines = r.Lines }
	end
	results[g] = { Px = { case.PxW, case.PxH }, Scale = s, Touch = touch, Sheet = sheet, W = W, H = H, Top = top, Rects = rects,
		Jump = env.Jump, Pouch = false, Bar = bar }

	-- 1. every approved item exists, is finite and sits on screen below the top bar
	local ids = {}
	for _, it in V2.Items do table.insert(ids, it.Id) end
	check(g, "no pouch line in layout B", out.pouch_line == nil, fmt(out.pouch_line))
	for _, id in ids do
		local r = out[id]
		local good = type(r) == "table" and finite(r.X) and finite(r.Y) and finite(r.W) and finite(r.H) and r.W > 0 and r.H > 0
		check(g, "rect " .. id, good, fmt(r))
		if good then
			check(g, "on screen " .. id, r.X >= -0.5 and r.X + r.W <= W + 0.5 and r.Y + r.H <= H + 0.5, fmt(r))
			if TOP_BAR[id] and not (touch and id == "menu") then
				-- A23-40 보강: in the bar's free part (clear of Roblox's buttons by >= 4 px), centred on its middle, never
				-- taller than a Roblox button
				check(g, "in the top bar " .. id, r.Y >= bar.Y0 - 0.5 and r.Y + r.H <= bar.Y1 + 0.5
					and r.X >= bar.X0 + 4 / s - 0.5 and r.X + r.W <= bar.X1 + 0.5,
					("%s bar %.1f..%.1f x %.1f..%.1f"):format(fmt(r), bar.Y0, bar.Y1, bar.X0, bar.X1))
				check(g, "on Roblox's button middle " .. id, math.abs(r.Y + r.H / 2 - barMid) <= 0.5,
					("%s mid %.2f buttons' mid %.2f"):format(fmt(r), r.Y + r.H / 2, barMid))
				check(g, "no taller than a Roblox button " .. id,
					r.H * s <= buttonPx + 0.5 or (touch and id == "menu" and r.H <= MIN_TAP + 0.01),
					("%.1f px, button %d px"):format(r.H * s, buttonPx))
			else
				check(g, "below top bar " .. id, r.Y >= top - 0.5, ("%s top=%.1f"):format(fmt(r), top))
			end
		end
	end
	if not out.attack or not out.portrait or not out.chips or not out.tiles then continue end
	-- the potions rect publishes the gap between its HP and MP cells (du; cell width = (W - Gap) / 2)
	local pg = out.potions and out.potions.Gap
	check(g, "potion gap published", finite(pg) and pg >= MIN_PRESS_GAP - 0.01, tostring(pg))
	if not finite(pg) then pg = 0 end
	-- the tile row publishes square tiles: Size = its height, Gap >= 2du, Count = as many as fit the row
	local t = out.tiles
	local tileOk = finite(t.Size) and finite(t.Gap) and type(t.Count) == "number" and t.Count >= 1
	check(g, "tile row published", tileOk, ("size %s gap %s count %s"):format(tostring(t.Size), tostring(t.Gap), tostring(t.Count)))
	if tileOk then
		check(g, "tiles are square rows", math.abs(t.Size - t.H) <= 0.01, fmt(t))
		check(g, "tile gap", t.Gap >= MIN_PRESS_GAP - 0.01, ("gap %.2f"):format(t.Gap))
		check(g, "tiles fit the row", t.Count * t.Size + (t.Count - 1) * t.Gap <= t.W + 0.01, fmt(t) .. " count " .. t.Count)
		check(g, "one more tile would not fit", (t.Count + 1) * t.Size + t.Count * t.Gap > t.W - 0.01,
			fmt(t) .. " count " .. t.Count)
	end

	if case.Supported then
		-- 2. nothing overlaps anything (circles as circles); pressable items also keep >= MIN_PRESS_GAP apart (touching
		-- buttons pass a plain overlap test); the tightest gaps are reported
		local minGap, minPair = math.huge, ""
		local minPress, pressPair = math.huge, ""
		for i = 1, #ids do
			for j = i + 1, #ids do
				local a, b = ids[i], ids[j]
				local ra, rb = out[a], out[b]
				if ra and rb then
					local d = gap(ra, ROUND[a], rb, ROUND[b])
					check(g, "no overlap " .. a .. "/" .. b, d >= -0.01, ("gap %.2f %s %s"):format(d, fmt(ra), fmt(rb)))
					if d < minGap then minGap, minPair = d, a .. "/" .. b end
					if INTERACTIVE[a] and INTERACTIVE[b] then
						check(g, "press gap " .. a .. "/" .. b, d >= MIN_PRESS_GAP - 0.01,
							("gap %.2f %s %s"):format(d, fmt(ra), fmt(rb)))
						if d < minPress then minPress, pressPair = d, a .. "/" .. b end
					end
				end
			end
		end
		results[g].MinGap = { Gap = minGap, Pair = minPair }
		results[g].MinPressGap = { Gap = minPress, Pair = pressPair }

		-- 3. touch: thumb-size targets, nothing pressable on the jump button or in the thumbstick zone
		if touch then
			for _, id in TAPS do
				local r = out[id]
				if id == "menu" then
					-- a tile-row square under the bar (review 2026-10-07: taps in the Roblox bar never reach it)
					check(g, "tap size " .. id, math.min(r.W, r.H) >= MIN_TAP - 0.01, ("%s %.1f px"):format(fmt(r), r.W * s))
					check(g, "menu under the top bar on touch", r.Y >= top - 0.5, ("%s top=%.1f"):format(fmt(r), top))
				else
					check(g, "tap size " .. id, math.min(r.W, r.H) >= MIN_TAP - 0.01, fmt(r))
				end
			end
			check(g, "tap size tiles", tileOk and t.Size >= MIN_TAP - 0.01, fmt(t))
			check(g, "tap size quest lines", out.quest.H >= MIN_TAP - 0.01 and out.quest.W >= MIN_TAP - 0.01, fmt(out.quest))
			-- tiles: 5 on the reference phone, at least 3 on every phone (the rest fold out of [메뉴])
			local tileName = "tiles at least 3 on phones"
			local e3 = excepted(case, tileName)
			-- touch: [메뉴] is the row's last square (review 2026-10-07), it counts as one of the three
			local rowCount = (tileOk and t.Count or 0) + (touch and 1 or 0)
			if rowCount >= 3 then
				check(g, tileName, true)
				if e3 then check(g, "exception still needed: " .. tileName, false, "3 tiles fit; drop the exception") end
			elseif e3 then
				check(g, "tiles at least 2 on tiny phones", tileOk and t.Count >= 2, fmt(t) .. " count " .. tostring(t.Count))
				table.insert(exceptions, { Screen = g, Check = tileName, Reason = e3.Reason, Measured = tileOk and t.Count or 0,
					Need = 3 })
			else
				check(g, tileName, false, fmt(t) .. " count " .. tostring(t.Count))
			end
			-- potions: both cells (HP, MP side by side, Gap apart) are thumb size; a declared exception (no room) only
			-- requires the pair to reach the thumbstick zone edge, and is reported with its measured cell width
			local pot = out.potions
			local cellW = (pot.W - pg) / 2
			check(g, "tap size potions cell height", pot.H >= MIN_TAP - 0.01, fmt(pot))
			local cellName = "tap size potions cell width"
			local e = excepted(case, cellName)
			if cellW >= MIN_TAP - 0.01 then
				check(g, cellName, true)
				if e then check(g, "exception still needed: " .. cellName, false, ("cell %.2fdu fits; drop the exception"):format(cellW)) end
			elseif e then
				check(g, "potions use all their room", pot.X <= 0.4 * W + 0.5, ("%s stick edge %.2f"):format(fmt(pot), 0.4 * W))
				table.insert(exceptions, { Screen = g, Check = cellName, Reason = e.Reason, Measured = cellW, Need = MIN_TAP })
			else
				check(g, cellName, false, ("cell %.2fdu (gap %.2f) %s"):format(cellW, pg, fmt(pot)))
			end
			local stick = { X = 0, Y = H / 3, W = 0.4 * W, H = H - H / 3 }
			for id in INTERACTIVE do
				check(g, "stick zone free " .. id, not inter(out[id], stick), fmt(out[id]))
			end
			if env.Jump then
				for id in INTERACTIVE do
					check(g, "jump free " .. id, gap(out[id], ROUND[id], env.Jump, true) >= -0.01,
						fmt(out[id]) .. " jump " .. fmt(env.Jump))
				end
				-- the cluster hugs the jump button: attack sits left of it, the cluster in the lower right
				check(g, "attack left of jump", out.attack.X + out.attack.W <= env.Jump.X + 1, fmt(out.attack))
				check(g, "attack near jump", env.Jump.X - (out.attack.X + out.attack.W) <= 40,
					fmt(out.attack) .. " jump " .. fmt(env.Jump))
			end
		end
		if sheet then
			-- phone plate: face, bars and the tile row sit in the top-right block, flush with the right edge (8 px)
			for _, id in FACE do
				check(g, "phone plate top-right " .. id, out[id].X + out[id].W >= 0.6 * W and out[id].Y + out[id].H <= 0.5 * H,
					fmt(out[id]))
			end
			for _, id in { "power_line", "mp_bar", "xp_bar" } do
				local right = W - (out[id].X + out[id].W)
				check(g, "phone plate at the right edge " .. id, right >= 2 and right <= 16, ("%s right gap %.2f"):format(fmt(out[id]), right))
			end
			-- the row reaches the plate's right edge: the tiles (mouse: [메뉴] is in the bar) or [메뉴] after them (touch)
			local pl = out.power_line
			local rowRight = touch and (out.menu.X + out.menu.W) or (t.X + t.W)
			check(g, "phone tiles reach the plate's right edge", math.abs(rowRight - (pl.X + pl.W)) <= 0.5,
				fmt(t) .. " " .. fmt(out.menu) .. " " .. fmt(pl))
		else
			-- 4. desktop: the corner cluster in the bottom-right corner; the face group along the bottom, centred unless it
			-- had to step aside, always clear of the cluster and inside the left margin
			check(g, "attack in corner", W - (out.attack.X + out.attack.W) <= 30 and H - (out.attack.Y + out.attack.H) <= 30,
				fmt(out.attack))
			local minX, maxX = math.huge, -math.huge
			for _, id in FACE do
				local r = out[id]
				minX, maxX = math.min(minX, r.X), math.max(maxX, r.X + r.W)
				check(g, "face group at the bottom " .. id, r.Y + r.H / 2 >= 0.6 * H, fmt(r))
			end
			local clusterLeft = math.huge
			for _, id in CLUSTER do clusterLeft = math.min(clusterLeft, out[id].X) end
			local centred = math.abs((minX + maxX) / 2 - W / 2) <= 1
			check(g, "face group centred or stepped aside", centred or maxX <= clusterLeft - 8 + 0.01,
				("group %.1f..%.1f W/2 %.1f cluster %.1f"):format(minX, maxX, W / 2, clusterLeft))
			check(g, "face group left margin", minX >= 8 - 0.01, ("group %.1f..%.1f"):format(minX, maxX))
			check(g, "all 8 tiles on 16:9 PCs", (W / H < 1.7) or (tileOk and t.Count >= 8),
				fmt(t) .. " count " .. tostring(t.Count))
			check(g, "at least 6 tiles on every PC", tileOk and t.Count >= 6, fmt(t) .. " count " .. tostring(t.Count))
		end
		-- [메뉴]: a square in the top bar's right end, MENU_EDGE_PX from its free part's end, a Roblox button on PCs
		-- (A23-40 정정 + 보강)
		local m = out.menu
		if touch then
			-- touch: the tile row's last square, as big as the tiles (review 2026-10-07)
			check(g, "menu at the tile row's right end", tileOk and math.abs(m.Y - t.Y) <= 0.01
				and math.abs(m.H - t.Size) <= 0.01 and m.X >= t.X + t.W - 0.01, fmt(m) .. " " .. fmt(t))
		else
			local rightPx = (bar.X1 - (m.X + m.W)) * s
			check(g, "menu at the top bar's right end", rightPx >= MENU_EDGE_PX - 0.5 and rightPx <= MENU_EDGE_PX + 0.5,
				("%s right %.1f px"):format(fmt(m), rightPx))
		end
		check(g, "menu square", math.abs(m.W - m.H) <= 0.01, fmt(m))
		if not touch then
			check(g, "menu as big as a Roblox button", math.abs(m.H * s - buttonPx) <= 0.5, ("%.1f px"):format(m.H * s))
		end

		-- 5. blocks stay at their edges: minimap + quest top-left, the top rows hug the top bar, the cluster lower right
		for _, id in LEFT_BAND do
			check(g, "left block " .. id, out[id].X <= 0.3 * W, fmt(out[id]))
		end
		check(g, "minimap left", out.minimap.X <= 0.1 * W, fmt(out.minimap))
		-- the first rows under the bar: the minimap and the chip row (the war meter is in the bar)
		local firstRow = math.min(out.minimap.Y, out.chips.Y)
		check(g, "top rows hug the top bar", firstRow - top >= 2 and firstRow - top <= 16,
			("first row %.1f top %.1f"):format(firstRow, top))
		check(g, "chips right under the bar", (out.chips.Y - top) * s >= 2 - 0.01 and (out.chips.Y - top) * s <= 8 + 0.01,
			("chips %.1f top %.1f (%.1f px)"):format(out.chips.Y, top, (out.chips.Y - top) * s))
		for _, id in CLUSTER do
			check(g, "cluster lower right " .. id, out[id].X + out[id].W / 2 >= (sheet and 0.45 or 0.5) * W
				and out[id].Y + out[id].H / 2 >= 0.4 * H,
				fmt(out[id]))
		end
		-- the quest lines hang under the minimap on PC, beside it on the phone sheet (outside the thumbstick zone)
		if sheet then
			check(g, "quest beside the minimap", out.quest.X >= out.minimap.X + out.minimap.W - 0.01
				and out.quest.Y <= out.minimap.Y + 1, fmt(out.quest) .. " " .. fmt(out.minimap))
		else
			check(g, "quest under the minimap", out.quest.Y >= out.minimap.Y + out.minimap.H - 0.01
				and math.abs(out.quest.X - out.minimap.X) <= 1, fmt(out.quest) .. " " .. fmt(out.minimap))
		end

		-- 6. centre column: one centre x for the meter, the chip row, the next-event line and notify, top-down in that
		-- order; meter >= 240du (or its approved width when smaller); >= 6du from the blocks beside it
		local cx = out.war_meter.X + out.war_meter.W / 2
		for _, id in CENTER do
			check(g, "centre column " .. id, math.abs(out[id].X + out[id].W / 2 - cx) <= 1, fmt(out[id]))
		end
		for i = 2, #CENTER do
			local a, b = out[CENTER[i - 1]], out[CENTER[i]]
			check(g, "column order " .. CENTER[i], b.Y >= a.Y + a.H - 0.01, fmt(a) .. " " .. fmt(b))
		end
		local refW = 0
		for _, it in V2.Items do
			if it.Id == "war_meter" then refW = (sheet and it.Phone.w or it.Pc.w) / (sheet and REF_SCALE.Touch or REF_SCALE.Desktop) end
		end
		check(g, "war meter width", out.war_meter.W >= math.min(240, refW) - 0.5, fmt(out.war_meter))
		local sides = sheet and { "minimap", "quest", "portrait", "power_line", "hp_bar", "mp_bar", "xp_bar", "tiles" }
			or { "minimap", "quest" }
		for _, cid in CENTER do
			local c = out[cid]
			for _, id in sides do
				local o = out[id]
				if o.Y < c.Y + c.H and o.Y + o.H > c.Y then
					local d = (o.X + o.W / 2 < cx) and (c.X - (o.X + o.W)) or (o.X - (c.X + c.W))
					check(g, "column clear of " .. cid .. "/" .. id, d >= 6 - 0.01, fmt(c) .. " " .. fmt(o))
				end
			end
		end

		-- 7. [메뉴] fold-out room (A23-40 정정): lines of [메뉴]-sized squares right-aligned one gap left of [메뉴]; the first
		-- on [메뉴]'s line, more lines down on PCs / up on phones (A23-38 "위쪽에서만"); the four menu tiles in one line
		-- (검수: "폰에서도 한 줄에"; narrow 4:3-ish PC windows may wrap), room for the phone row's overflow too; never
		-- over the war meter, minimap, quest lines, a combat button, the jump button or the thumbstick zone (PCs: nor the
		-- face group / tile row)
		local f, m = out.fold, out.menu
		local foldOk = type(f) == "table" and finite(f.Size) and finite(f.Gap) and type(f.Lines) == "table" and #f.Lines >= 1
			and f.Rows == #f.Lines and f.Cols == (f.Lines[1] and f.Lines[1].Cols)
		check(g, "fold published", foldOk, fmt(f))
		if foldOk then
			check(g, "fold squares as big as the menu", math.abs(f.Size - m.H) <= 0.01, fmt(f) .. " " .. fmt(m))
			check(g, "fold first line on the menu's line", math.abs(f.Lines[1].Y - m.Y) <= 0.01, fmt(f) .. " " .. fmt(m))
			check(g, "fold gap", f.Gap >= MIN_PRESS_GAP - 0.01, ("gap %.2f"):format(f.Gap))
			local total = 0
			for i, ln in f.Lines do
				total += ln.Cols
				local rr = { X = ln.X, Y = ln.Y, W = ln.Cols * (f.Size + f.Gap) - f.Gap, H = f.Size }
				check(g, "fold line ends at the menu", math.abs(rr.X + rr.W + f.Gap - m.X) <= 0.01, fmt(rr) .. " " .. fmt(m))
				if i == 1 then
					if touch then
						-- touch: the first line on [메뉴]'s tile row, under the bar
						check(g, "fold first line under the top bar", rr.Y >= top - 0.01, fmt(rr) .. (" top %.1f"):format(top))
					else
						-- the first line runs along the top bar, right of Roblox's own buttons
						check(g, "fold first line in the top bar", rr.Y >= bar.Y0 - 0.01 and rr.Y + rr.H <= bar.Y1 + 0.01
							and rr.X >= bar.X0 - 0.01, fmt(rr) .. (" bar x0 %.1f"):format(bar.X0))
					end
				else
					check(g, "fold line on screen below the top bar", rr.X >= -0.01 and rr.Y >= top - 0.01 and rr.Y + rr.H <= H + 0.01,
						fmt(rr))
					-- mouse: down, the second line right under the bar (one gap), the next ones one square + gap apart;
					-- touch: up from the tile row, one square + gap apart, never into the bar
					local prev = f.Lines[i - 1]
					if touch then
						local want = prev.Y - f.Size - f.Gap
						check(g, "fold lines go up", math.abs(ln.Y - want) <= 0.01 and ln.Y >= top - 0.01,
							fmt(rr) .. (" want y %.2f"):format(want))
					else
						local want = i == 2 and math.max(prev.Y + f.Size + f.Gap, top + f.Gap) or prev.Y + f.Size + f.Gap
						check(g, "fold lines go down", math.abs(ln.Y - want) <= 0.01, fmt(rr) .. (" want y %.2f"):format(want))
					end
				end
				local protect = table.clone(FOLD_PROTECT)
				if not sheet then
					for _, id in FOLD_PROTECT_PC do table.insert(protect, id) end
				end
				for _, id in protect do
					check(g, "fold clear of " .. id, gap(rr, false, out[id], ROUND[id]) >= -0.01, fmt(rr) .. " " .. fmt(out[id]))
				end
				if touch then
					check(g, "fold stick zone free", not inter(rr, { X = 0, Y = H / 3, W = 0.4 * W, H = H - H / 3 }), fmt(rr))
					if env.Jump then check(g, "fold jump free", gap(rr, false, env.Jump, true) >= -0.01, fmt(rr)) end
				end
			end
			local oneLine = touch or W / H >= 1.2
			local lineName = "fold holds the menu tiles" .. (oneLine and " in one line" or "")
			local eLine = oneLine and excepted(case, lineName) or nil
			if (oneLine and f.Cols or total) >= MENU_TILES then
				check(g, lineName, true)
				if eLine then check(g, "exception still needed: " .. lineName, false, "they fit in one line; drop the exception") end
			elseif eLine then
				-- too narrow for the bar: the rest wraps to the line right under it
				check(g, "fold wraps right under the bar", total >= MENU_TILES and f.Lines[2] ~= nil
					and f.Lines[2].Y <= top + f.Gap + 0.01, ("cols %d total %d"):format(f.Cols, total))
				table.insert(exceptions, { Screen = g, Check = lineName, Reason = eLine.Reason, Measured = f.Cols, Need = MENU_TILES })
			else
				check(g, lineName, false, ("cols %d total %d"):format(f.Cols, total))
			end
			local overflow = sheet and math.max(0, ROW_TILES - (tileOk and t.Count or 0)) or 0
			check(g, "fold holds the row overflow", total >= MENU_TILES + overflow,
				("total %d need %d"):format(total, MENU_TILES + overflow))
		end
	end

	-- 7. the reference screens reproduce the approved sheet (real px, +-1)
	if case.Ref then
		for _, it in V2.Items do
			local want = touch and it.Phone or it.Pc
			local r = out[it.Id]
			local px = { x = r.X * s, y = r.Y * s, w = r.W * s, h = r.H * s }
			local d = math.max(math.abs(px.x - want.x), math.abs(px.y - want.y), math.abs(px.w - want.w), math.abs(px.h - want.h))
			check(g, "matches sheet " .. it.Id, d <= 1.01,
				("got %.1f,%.1f %.1fx%.1f want %d,%d %dx%d"):format(px.x, px.y, px.w, px.h, want.x, want.y, want.w, want.h))
		end
		check(g, "matches sheet potion gap", math.abs(pg * s - POTION_GAP_PX) <= 1.01, ("gap %.2f px"):format(pg * s))
		check(g, "matches sheet tile gap", tileOk and math.abs(t.Gap * s - TILE_GAP_PX) <= 0.51, ("gap %.2f px"):format((t.Gap or 0) * s))
		-- phones: 4 tiles + [메뉴] as the row's last square (touch, review 2026-10-07; was 5 with [메뉴] in the bar)
		check(g, "reference tile count", tileOk and t.Count == (touch and 4 or 8), fmt(t) .. " count " .. tostring(t.Count))
	end

	-- 8. hiding the auto button (before the crown-shard quest) never moves another item
	local ok2, out2 = pcall(function()
		local HudLayout = execute(HUDLAYOUT_SOURCE)
		local e = table.clone(env)
		e.Hidden = { auto = true }
		return HudLayout.Compute(e)
	end)
	if ok2 and type(out2) == "table" then
		for _, id in { "tiles", "quest", "minimap", "war_meter", "portrait" } do
			local a, b = out[id], out2[id]
			check(g, "auto hidden keeps " .. id, a and b and math.abs(a.X - b.X) < 0.01 and math.abs(a.Y - b.Y) < 0.01, fmt(b))
		end
	else
		check(g, "auto hidden runs", false, out2)
	end
end

----------------------------------------------------------------- static: HudLayout stays a pure module
do
	local src = HUDLAYOUT_SOURCE
	local code = src:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
	check("static", "no services", not code:find("GetService", 1, true) and not code:find("game", 1, true)
		and not code:find("workspace", 1, true), "HudLayout must not touch the DataModel")
	check("static", "no instances", not code:find("Instance.new", 1, true), "HudLayout must not create instances")
	check("static", "no require", not code:find("require%("), "HudLayout must not require other modules")
	local topLocals = 0
	for line in code:gmatch("[^\n]+") do
		if line:match("^local%s") then
			local names = line:match("^local%s+function%s+") and 1 or select(2, (line:match("^local%s+([^=]+)") or ""):gsub(",", ",")) + 1
			topLocals += names
		end
	end
	check("static", "top-level locals < 150", topLocals < 150, topLocals)
end

local named = {}
for _, key in order do table.insert(named, Named[key]) end
print("HUD_LAYOUT_RESULT_JSON " .. encode({ Checks = checks, Failed = failed, Named = named, Cases = results,
	Exceptions = exceptions }))
if failed == 0 then
	print(("HUD_LAYOUT_OFFLINE_OK checks=%d Studio/API calls=0"):format(checks))
end
