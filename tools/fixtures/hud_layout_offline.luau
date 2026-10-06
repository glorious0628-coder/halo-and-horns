-- Offline checks for HudLayout.Compute (A23-26 HUD v2). The runner (tools/test_hud_layout.py) prepends:
--   HUDLAYOUT_SOURCE : the current src/StarterPlayer/StarterPlayerScripts/HudLayout.luau text
--   V2               : the approved rects of docs/design/hud_layout_v2_2026-10-06.json { Items = { { Id, Round, Pc, Phone } },
--                      Zones = { { Name, Pc, Phone } } } (real px on 1280x720 / 749x361)
--   CASES            : screens { Name, Touch, Ref, Supported, Scale, PxW, PxH, Env = { W, H, Scale, Inset, Touch, Jump } }
--                      (Env in MainGui logical units, as HUD.luau passes it; Jump = the TouchGui JumpButton rect)
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
-- interactive = something a finger / mouse presses (the minimap, chips, notify, combo, bars are passive displays)
local INTERACTIVE = { portrait = true, pet = true, bag = true, map = true, menu = true, quest = true, potions = true,
	ghost = true, q = true, z = true, auto = true, attack = true }
local TAPS = { "portrait", "pet", "bag", "map", "menu", "ghost", "q", "z", "auto", "attack" }
local MIN_TAP = 60 -- logical units (spec final: >= 45 real px at the phone's 0.75 UIScale)
local LEFT_BAND = { "portrait", "hp_bar", "mp_bar", "power_line", "xp_bar" }
local RIGHT_BAND = { "pet", "bag", "map", "menu", "quest" }
local TOP_ROWS = { "portrait", "hp_bar", "war_meter", "pet", "bag", "map", "menu" }
local RAIL = { "pet", "bag", "map", "menu" }
local CLUSTER = { "potions", "ghost", "q", "z", "auto", "attack" }
local REF_SCALE = { Desktop = 0.8, Touch = 0.75 }

local function zoneRect(name, touch)
	for _, z in V2.Zones do
		if z.Name == name then return touch and z.Phone or z.Pc end
	end
	return nil
end

local results = {}
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
	local rects = {}
	for id, r in out do rects[id] = { X = r.X, Y = r.Y, W = r.W, H = r.H } end
	results[g] = { Px = { case.PxW, case.PxH }, Scale = s, Touch = touch, W = W, H = H, Top = top, Rects = rects,
		Jump = env.Jump }

	-- 1. every approved item (+ the luck pill) exists, is finite and sits on screen below the top bar
	local ids = {}
	for _, it in V2.Items do table.insert(ids, it.Id) end
	table.insert(ids, "luck")
	for _, id in ids do
		local r = out[id]
		local good = type(r) == "table" and finite(r.X) and finite(r.Y) and finite(r.W) and finite(r.H) and r.W > 0 and r.H > 0
		check(g, "rect " .. id, good, fmt(r))
		if good then
			check(g, "on screen " .. id, r.X >= -0.5 and r.X + r.W <= W + 0.5 and r.Y + r.H <= H + 0.5, fmt(r))
			check(g, "below top bar " .. id, r.Y >= top - 0.5, ("%s top=%.1f"):format(fmt(r), top))
		end
	end
	if not out.attack or not out.portrait or not out.luck then continue end

	if case.Supported then
		-- 2. nothing overlaps anything (circles as circles); the tightest gaps are reported
		local minGap, minPair = math.huge, ""
		for i = 1, #ids do
			for j = i + 1, #ids do
				local a, b = ids[i], ids[j]
				local ra, rb = out[a], out[b]
				if ra and rb then
					local d = gap(ra, ROUND[a], rb, ROUND[b])
					check(g, "no overlap " .. a .. "/" .. b, d >= -0.01, ("gap %.2f %s %s"):format(d, fmt(ra), fmt(rb)))
					if d < minGap then minGap, minPair = d, a .. "/" .. b end
				end
			end
		end
		results[g].MinGap = { Gap = minGap, Pair = minPair }

		-- 3. touch: thumb-size targets, nothing pressable on the jump button or in the thumbstick zone
		if touch then
			for _, id in TAPS do
				local r = out[id]
				check(g, "tap size " .. id, math.min(r.W, r.H) >= MIN_TAP - 0.01, fmt(r))
			end
			check(g, "tap size potions", out.potions.H >= MIN_TAP - 0.01, fmt(out.potions))
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
		else
			-- 4. desktop: nothing pressable under the bottom-left chat window (anchored bottom-left, ref px -> du)
			local z = zoneRect("채팅 창(PC 왼쪽 아래로 옮김)", false)
			if z then
				local k = 1 / REF_SCALE.Desktop
				local chat = { X = z.x * k, Y = H - (720 - z.y) * k, W = z.w * k, H = z.h * k }
				for id in INTERACTIVE do
					check(g, "chat free " .. id, not inter(out[id], chat), fmt(out[id]) .. " chat " .. fmt(chat))
				end
				check(g, "chat free minimap", not inter(out.minimap, chat), fmt(out.minimap))
			end
			-- the corner cluster: attack in the bottom-right corner
			check(g, "attack in corner", W - (out.attack.X + out.attack.W) <= 30 and H - (out.attack.Y + out.attack.H) <= 30,
				fmt(out.attack))
		end

		-- 5. blocks stay at their edges: left block left, rail + quest right, top rows hug the top bar
		for _, id in LEFT_BAND do
			check(g, "left block " .. id, out[id].X <= 0.3 * W, fmt(out[id]))
		end
		check(g, "minimap left", out.minimap.X <= 0.1 * W, fmt(out.minimap))
		for _, id in RIGHT_BAND do
			check(g, "right block " .. id, out[id].X + out[id].W >= 0.7 * W, fmt(out[id]))
		end
		check(g, "menu at right edge", W - (out.menu.X + out.menu.W) <= 16, fmt(out.menu))
		local firstRow = math.huge
		for _, id in TOP_ROWS do firstRow = math.min(firstRow, out[id].Y) end
		check(g, "top rows hug the top bar", firstRow - top >= 2 and firstRow - top <= 16,
			("first row %.1f top %.1f"):format(firstRow, top))
		for _, id in CLUSTER do
			check(g, "cluster lower right " .. id, out[id].X + out[id].W / 2 >= (touch and 0.45 or 0.5) * W
				and out[id].Y + out[id].H / 2 >= 0.4 * H,
				fmt(out[id]))
		end
		-- the rail reads left to right: pet, bag, map, menu on one row
		for i = 2, #RAIL do
			local a, b = out[RAIL[i - 1]], out[RAIL[i]]
			check(g, "rail order " .. RAIL[i], a.X < b.X and math.abs(a.Y - b.Y) <= 1, fmt(a) .. " " .. fmt(b))
		end

		-- 6. centre column: one centre x for the meter, the chip row (luck + chips) and notify; meter >= 240du (or
		-- its approved width when smaller); it keeps >= 6du from the left / right blocks beside it
		local cx = out.war_meter.X + out.war_meter.W / 2
		local rowL, rowR = out.luck.X, out.chips.X + out.chips.W
		check(g, "centre column chips", math.abs((rowL + rowR) / 2 - cx) <= 1, ("row %.1f-%.1f cx %.1f"):format(rowL, rowR, cx))
		check(g, "centre column notify", math.abs(out.notify.X + out.notify.W / 2 - cx) <= 1, fmt(out.notify))
		check(g, "luck left of chips", out.luck.X + out.luck.W <= out.chips.X + 0.01 and math.abs(out.luck.Y - out.chips.Y) <= 0.01,
			fmt(out.luck) .. " " .. fmt(out.chips))
		local refW = 0
		for _, it in V2.Items do
			if it.Id == "war_meter" then refW = (touch and it.Phone.w or it.Pc.w) / (touch and REF_SCALE.Touch or REF_SCALE.Desktop) end
		end
		check(g, "war meter width", out.war_meter.W >= math.min(240, refW) - 0.5, fmt(out.war_meter))
		for _, cid in { "war_meter", "luck", "chips", "notify" } do
			local c = out[cid]
			for _, id in LEFT_BAND do
				local o = out[id]
				if o.Y < c.Y + c.H and o.Y + o.H > c.Y then
					check(g, "column clear of left " .. cid .. "/" .. id, c.X - (o.X + o.W) >= 6 - 0.01, fmt(c) .. " " .. fmt(o))
				end
			end
			for _, id in RIGHT_BAND do
				local o = out[id]
				if o.Y < c.Y + c.H and o.Y + o.H > c.Y then
					check(g, "column clear of right " .. cid .. "/" .. id, o.X - (c.X + c.W) >= 6 - 0.01, fmt(c) .. " " .. fmt(o))
				end
			end
		end
	end

	-- 7. the reference screens reproduce the approved sheet (real px, +-1)
	if case.Ref then
		for _, it in V2.Items do
			local want = touch and it.Phone or it.Pc
			local r = out[it.Id]
			if it.Id == "chips" then -- the approved chip row = luck pill + status chips
				r = { X = out.luck.X, Y = out.luck.Y, W = out.chips.X + out.chips.W - out.luck.X, H = out.chips.H }
			end
			local px = { x = r.X * s, y = r.Y * s, w = r.W * s, h = r.H * s }
			local d = math.max(math.abs(px.x - want.x), math.abs(px.y - want.y), math.abs(px.w - want.w), math.abs(px.h - want.h))
			check(g, "matches sheet " .. it.Id, d <= 1.01,
				("got %.1f,%.1f %.1fx%.1f want %d,%d %dx%d"):format(px.x, px.y, px.w, px.h, want.x, want.y, want.w, want.h))
		end
	end

	-- 8. hiding the reserved pet slot never moves the other rail buttons (the rail must not shift at launch)
	local ok2, out2 = pcall(function()
		local HudLayout = execute(HUDLAYOUT_SOURCE)
		local e = table.clone(env)
		e.Hidden = { pet = true }
		return HudLayout.Compute(e)
	end)
	if ok2 and type(out2) == "table" then
		for _, id in { "bag", "map", "menu", "quest" } do
			local a, b = out[id], out2[id]
			check(g, "pet hidden keeps " .. id, a and b and math.abs(a.X - b.X) < 0.01 and math.abs(a.Y - b.Y) < 0.01, fmt(b))
		end
	else
		check(g, "pet hidden runs", false, out2)
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
print("HUD_LAYOUT_RESULT_JSON " .. encode({ Checks = checks, Failed = failed, Named = named, Cases = results }))
if failed == 0 then
	print(("HUD_LAYOUT_OFFLINE_OK checks=%d Studio/API calls=0"):format(checks))
end
