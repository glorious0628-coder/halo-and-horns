-- Offline checks for the client side of dev2's story / lines contracts (town_quests_server 8 E2 + A23-58,
-- lines_pack_server 1-2): the real Announce.luau shows a king's Args.Banter as one more same-colour chat line (no toast);
-- the real Panels STORY.Lines / STORY.Hint (cut out of Panels.luau by the runner) pick a story step's lines by the
-- server's Var and the faction's choice hint. The runner (tools/test_story_client.py) prepends CONFIG_SOURCE,
-- ANNOUNCE_SOURCE and STORY_SOURCE (+ HINT_LEAN, the STORY.Text.HintLean literal). Roblox is replaced by small doubles.
-- Every check is named (group :: check) and collected. No Studio, Roblox API or network calls.

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

local function encode(v)
	local t = type(v)
	if t == "nil" then return "null" end
	if t == "boolean" then return v and "true" or "false" end
	if t == "number" then return (string.format("%.4f", v):gsub("%.?0+$", "")) end
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
local function show(v)
	local ok, s = pcall(encode, v)
	return ok and s or tostring(v)
end

----------------------------------------------------------------- engine doubles
local function rgb(r, g, b) return { R = r / 255, G = g / 255, B = b / 255, __kind = "Color3" } end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local function typeofDouble(v) return type(v) == "table" and rawget(v, "__kind") or type(v) end
local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __kind = "Vector3" }, vmt) end

local W = { Chat = {}, Core = {}, Toasts = {}, Handler = nil, ChatVersion = "ChatVersion.TextChatService" }
local channel = { Name = "RBXGeneral" }
function channel:IsA(c) return c == "TextChannel" end
function channel.DisplaySystemMessage(_, rich) table.insert(W.Chat, rich) end
local textChat = setmetatable({}, { __index = function(_, k)
	if k == "ChatVersion" then return W.ChatVersion end
	if k == "FindFirstChild" then
		return function(_, n)
			if n == "TextChannels" then return { FindFirstChild = function(_, c) return c == "RBXGeneral" and channel or nil end } end
			return nil
		end
	end
	return nil
end })
local starterGui = { SetCore = function(_, name, data)
	if name ~= "ChatMakeSystemMessage" then error("unknown core call " .. tostring(name)) end
	table.insert(W.Core, data)
end }

local function envFor(Config, Net)
	local shared = { WaitForChild = function(_, n) return { __module = n } end }
	local game = { GetService = function(_, n)
		if n == "ReplicatedStorage" then return { WaitForChild = function() return shared end } end
		if n == "TextChatService" then return textChat end
		if n == "StarterGui" then return starterGui end
		if n == "Players" then return { LocalPlayer = { GetAttribute = function() return nil end } } end
		return {}
	end }
	return { Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec, zero = vec(0, 0, 0) },
		Color3 = { new = function(r, g, b) return rgb(r * 255, g * 255, b * 255) end, fromRGB = rgb,
			fromHSV = function() return rgb(0, 0, 0) end },
		BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), UDim2 = ctor("UDim2"), UDim = ctor("UDim"),
		NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"),
		NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"), ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"),
		CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"), Font = ctor("Font"), Enum = enum, typeof = typeofDouble,
		game = game, workspace = { GetServerTimeNow = function() return 1790000000 end },
		Instance = { new = function(class) return { ClassName = class } end },
		require = function(m)
			if type(m) == "table" and m.__module == "Config" then return Config end
			if type(m) == "table" and m.__module == "Net" then return Net end
			error("unexpected require " .. show(m))
		end,
		task = { spawn = function(f, ...) f(...) end, defer = function(f, ...) f(...) end, wait = function() end,
			delay = function() end },
		warn = function(...) print("WARN", ...) end, print = function() end }
end

local function execute(name, text, env)
	local fn, err = loadstring(text, "=" .. name)
	assert(fn, err)
	setfenv(fn, setmetatable(env, { __index = getfenv() }))
	return fn()
end

local Config = execute("Config", CONFIG_SOURCE, envFor(nil, nil))

----------------------------------------------------------------- Announce: Args.Banter
local function hex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
do
	local g = "banter chat line"
	local Net = { Get = function(name)
		assert(name == "Announce", name)
		return { OnClientEvent = { Connect = function(_, fn) W.Handler = fn end } }
	end }
	local Announce = execute("Announce", ANNOUNCE_SOURCE, envFor(Config, Net))
	local ui = {
		Lang = function() return "en" end,
		ShouldHoldBanners = function() return false end,
		Toast = function(text, kind) table.insert(W.Toasts, { Text = text, Kind = kind }) end,
		Announce = function() end,
	}
	Announce.Init({ UIKit = ui })
	Announce.Start()
	check(g, "Announce listens to the Announce remote", type(W.Handler) == "function", "no handler")

	local events = Config.Announce and Config.Announce.Events or {}
	local appear = {}
	for key, ev in events do
		if string.sub(key, -6) == "Appear" and type(ev) == "table" then table.insert(appear, key) end
	end
	table.sort(appear)
	check(g, "Config has king appear events (PumpkinKingAppear, GhostKingAppear)", #appear >= 2, show(appear))
	local function fire(msg)
		W.Chat, W.Core, W.Toasts = {}, {}, {}
		W.Handler(msg)
	end
	local banter = 'Pumpkin King: "Me <3 & my zebra jelly"'
	for _, key in appear do
		local ev = events[key]
		fire({ Key = key, Args = { Banter = banter }, Event = true })
		local col = string.format('<font color="%s">', hex(ev.Color))
		check(g, "an appear line with Banter = two chat lines", #W.Chat == 2, key .. " " .. show(W.Chat))
		check(g, "line 1 is the event line, line 2 the banter (escaped for rich text)",
			W.Chat[2] ~= nil and string.find(W.Chat[2], "Me &lt;3 &amp; my zebra jelly", 1, true) ~= nil
			and string.find(W.Chat[1] or "", "Me &lt;3", 1, true) == nil, key .. " " .. show(W.Chat))
		check(g, "both lines in the event's own colour", W.Chat[1] ~= nil and W.Chat[2] ~= nil
			and string.find(W.Chat[1], col, 1, true) == 1 and string.find(W.Chat[2], col, 1, true) == 1, key .. " " .. show(W.Chat))
		local banterToasts = 0
		for _, t in W.Toasts do
			if string.find(t.Text, "zebra", 1, true) then banterToasts += 1 end
		end
		check(g, "the banter never toasts (the event's own toast stays as it was)",
			banterToasts == 0 and #W.Toasts == (ev.Toast == true and 1 or 0), key .. " " .. show(W.Toasts))
		fire({ Key = key, Args = {}, Event = true })
		check(g, "no Banter: one chat line (as before)", #W.Chat == 1, key .. " " .. show(W.Chat))
		fire({ Key = key, Args = { Banter = 42 }, Event = true })
		check(g, "a non-string Banter is ignored", #W.Chat == 1, key .. " " .. show(W.Chat))
		fire({ Key = key, Args = { Banter = "" }, Event = true })
		check(g, "an empty Banter is ignored", #W.Chat == 1, key .. " " .. show(W.Chat))
	end
	-- a drop line never carries a banter line (only events do)
	fire({ Key = "RareWeapon", Grade = "Rare", Args = { Who = "Ann", Faction = "Halo", Class = "Warrior", Weapon = 3,
		Monster = "Slime", Banter = banter } })
	check(g, "a weapon drop line ignores Banter", #W.Chat == 1 and string.find(W.Chat[1] or "", "zebra", 1, true) == nil,
		show(W.Chat))
	-- the legacy chat (the place still runs it): two system messages, same Color, plain text
	W.ChatVersion = "ChatVersion.LegacyChatService"
	local key = appear[1]
	if key then
		fire({ Key = key, Args = { Banter = banter }, Event = true })
		check(g, "legacy chat: two system messages, the banter unescaped, same Color",
			#W.Core == 2 and W.Core[2].Text == banter and W.Core[1].Color == W.Core[2].Color
			and W.Core[1].Color == events[key].Color, show(W.Core))
	end
	W.ChatVersion = "ChatVersion.TextChatService"
end

----------------------------------------------------------------- Panels STORY.Lines / STORY.Hint
local STORY = { Text = { HintLean = HINT_LEAN, HintHave = HINT_HAVE } }
local storyEnv = { STORY = STORY, Config = Config, string = string, type = type, math = math, UIKit = nil }
execute("STORY", STORY_SOURCE, storyEnv)

----------------------------------------------------------------- Panels STORY.PortraitKey (검수 2026-10-07)
do
	local g = "story speaker portrait"
	local parts = Config.UIArt and Config.UIArt.Parts or {}
	local function validId(id) return type(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil end
	local function artPart(name)
		local def = parts[name]
		return (type(def) == "table" and validId(def.Id)) and def or nil
	end
	check(g, "Panels has STORY.PortraitKey", type(STORY.PortraitKey) == "function", type(STORY.PortraitKey))
	storyEnv.UIKit = { Portrait = function() end, ArtPart = artPart }
	-- 검수's table: Otto, Fizzby, the three town NPCs, Kit and the two faction guides (no Speaker = my guide); the crown
	-- shard and the fountain shard share PTR_CrownShard (image dev 94207f5)
	local want = { Smith = "PortraitMerchantC", Potion = "PortraitPotionMerchant", Bright = "PTR_TownBright",
		Smokey = "PTR_TownSmokey", Tiny = "PTR_TownTiny", Guild = "PortraitGuideArtisan", Halo = "PortraitGuideHalo",
		Horns = "PortraitGuideHorns", Shard = "PTR_CrownShard", Fountain = "PTR_CrownShard" }
	for voice, key in want do
		local got = STORY.PortraitKey(voice)
		check(g, "a speaker with art shows its own face (검수 table)", got == key, voice .. " -> " .. show(got))
	end
	for _, voice in { "Kids", "Pip", "Dibs", "Grabbo", "Gleam", "Rex", "Nobody" } do
		local got = STORY.PortraitKey(voice)
		check(g, "a speaker without art (kids, goblins, Gleam, Rex) gets no portrait slot", got == nil,
			voice .. " -> " .. show(got))
	end
	local sq = Config.StoryQuests or {}
	for voice, key in (sq.Portraits or {}) do
		local known = (sq.Speakers and sq.Speakers[voice] ~= nil) or voice == "Halo" or voice == "Horns"
		check(g, "every Portraits row is a speaker (or the Halo / Horns guide) with a real art id",
			known and artPart(key) ~= nil, voice .. " " .. show(key))
	end
	-- the id goes empty while a picture is redrawn: no slot (never a blank frame)
	storyEnv.UIKit = { Portrait = function() end, ArtPart = function() return nil end }
	check(g, "an art id that is empty / invalid: no portrait slot", STORY.PortraitKey("Smith") == nil,
		show(STORY.PortraitKey("Smith")))
	storyEnv.UIKit = { ArtPart = artPart }
	check(g, "no UIKit.Portrait: no portrait slot", STORY.PortraitKey("Smith") == nil, show(STORY.PortraitKey("Smith")))
	storyEnv.UIKit = nil
	check(g, "no UIKit: no portrait slot", STORY.PortraitKey("Smith") == nil, show(STORY.PortraitKey("Smith")))
end

do
	local g = "story lines by Var"
	check(g, "Panels has STORY.Lines and STORY.Hint", type(STORY.Lines) == "function" and type(STORY.Hint) == "function",
		show({ type(STORY.Lines), type(STORY.Hint) }))
	local step = {
		Lines = { All = { "old" } },
		LinesBy = { From = "M2_3", Good = { All = { "g" } }, Evil = { Halo = { "eh" }, All = { "e" } },
			Purify = { All = { "p" } }, Default = { All = { "d" } } },
	}
	local function first(t) return type(t) == "table" and t[1] or nil end
	check(g, "Var Good -> the Good lines", first(STORY.Lines(step, "Halo", "Good")) == "g", show(STORY.Lines(step, "Halo", "Good")))
	check(g, "a faction row wins over All (Evil: Halo row for Halo, All for Horns)",
		first(STORY.Lines(step, "Halo", "Evil")) == "eh" and first(STORY.Lines(step, "Horns", "Evil")) == "e",
		show({ STORY.Lines(step, "Halo", "Evil"), STORY.Lines(step, "Horns", "Evil") }))
	check(g, "an exact pick value has its own lines (Var Purify)", first(STORY.Lines(step, "Horns", "Purify")) == "p")
	check(g, "a Var without its own lines -> Default", first(STORY.Lines(step, "Halo", "B")) == "d")
	check(g, "no Var (old server) -> Default (= the step's Lines for old clients)", first(STORY.Lines(step, "Halo", nil)) == "d")
	check(g, "a step without LinesBy keeps its Lines (Var ignored)",
		first(STORY.Lines({ Lines = { Horns = { "h" }, All = { "a" } } }, "Horns", "Good")) == "h"
		and first(STORY.Lines({ Lines = { All = { "a" } } }, "Halo", "Evil")) == "a")
	check(g, "a step with neither -> no lines (empty page, never an error)", #STORY.Lines({}, "Halo", "Good") == 0)

	-- the real data: every LinesBy step gives Halo and Horns players lines for each of its keys and for no Var
	local sq = Config.StoryQuests or {}
	local defs = sq.Defs or {}
	local n, seenM34 = 0, false
	for id, def in defs do
		for si, st in (type(def) == "table" and def.Steps) or {} do
			if type(st) == "table" and type(st.LinesBy) == "table" then
				n += 1
				if id == "M3_4" then seenM34 = true end
				check(g, "every LinesBy has a Default", type(st.LinesBy.Default) == "table", id .. " step " .. si)
				for var in st.LinesBy do
					if var ~= "From" then
						for _, f in { "Halo", "Horns" } do
							local lines = STORY.Lines(st, f, var)
							local ok = #lines > 0
							for _, l in lines do ok = ok and type(l) == "string" and l ~= "" end
							check(g, "real LinesBy: lines for every Var and both factions", ok, id .. " step " .. si .. " " .. var .. " " .. f)
						end
					end
				end
				for _, f in { "Halo", "Horns" } do
					check(g, "real LinesBy: lines with no Var too", #STORY.Lines(st, f, nil) > 0, id .. " step " .. si .. " " .. f)
				end
			end
		end
	end
	check(g, "the data has LinesBy steps (M3_4's pick card and reaction)", n >= 2 and seenM34, show({ n, seenM34 }))
end

do
	local g = "choice hint"
	local TXT = Config.StoryQuests.Text
	local obj = { Type = "Choice", Good = { Points = 3, Label = "Give" }, Evil = { Points = 5, Label = "Keep" } }
	local halo, horns = STORY.Hint(obj, "Halo"), STORY.Hint(obj, "Horns")
	check(g, "Halo: Honor +Good on the left, Honor -Evil on the right (A23-58)",
		type(halo) == "string" and string.find(halo, "Honor +3", 1, true) ~= nil and string.find(halo, "Honor -5", 1, true) ~= nil, halo)
	check(g, "Horns: Mischief -Good on the left, Mischief +Evil on the right (A23-58; A23-166 name)",
		type(horns) == "string" and string.find(horns, "Mischief -3", 1, true) ~= nil and string.find(horns, "Mischief +5", 1, true) ~= nil, horns)
	check(g, "the artisan guild: the no-points line", STORY.Hint(obj, "Neutral") == TXT.ChoiceHintNeutral)
	local okNil, hNil = pcall(STORY.Hint, obj, nil)
	local okOdd, hOdd = pcall(STORY.Hint, obj, "Guild")
	check(g, "no faction yet / an unknown faction id: the no-points line, never an error",
		okNil and okOdd and hNil == TXT.ChoiceHintNeutral and hOdd == TXT.ChoiceHintNeutral, show({ okNil, hNil, okOdd, hOdd }))
	local zero = { Type = "Choice", Good = { Points = 0 }, Evil = { Points = 0 } }
	check(g, "two 0-point picks (E5): the lean line, no +0 / -0",
		STORY.Hint(zero, "Halo") == HINT_LEAN and STORY.Hint(zero, "Horns") == HINT_LEAN and string.find(HINT_LEAN, "%d", 1, true) == nil,
		show({ STORY.Hint(zero, "Halo"), HINT_LEAN }))
	local saved = TXT.ChoiceHintHalo
	TXT.ChoiceHintHalo = nil
	local fb = STORY.Hint(obj, "Halo")
	TXT.ChoiceHintHalo = saved
	check(g, "an older Config without the faction line falls back to ChoiceHint", fb == string.format(TXT.ChoiceHint, 3, 5), fb)
	-- round 3 #5: the real minus (never below 0, A23-58) and my points now
	local h0 = STORY.Hint(obj, "Halo", 0)
	check(g, "Halo with 0 Honor: 'Honor -0' and '(you have 0)'",
		string.find(h0, "Honor +3", 1, true) ~= nil and string.find(h0, "Honor -0", 1, true) ~= nil
		and string.find(h0, string.format(HINT_HAVE, 0), 1, true) ~= nil, h0)
	local h10 = STORY.Hint(obj, "Halo", 10)
	check(g, "Halo with 10 Honor: the full -5", string.find(h10, "Honor -5", 1, true) ~= nil
		and string.find(h10, string.format(HINT_HAVE, 10), 1, true) ~= nil, h10)
	local r1 = STORY.Hint(obj, "Horns", 1)
	check(g, "Horns with 1 Mischief: 'Mischief -1' (the good pick costs what I have)",
		string.find(r1, "Mischief -1", 1, true) ~= nil and string.find(r1, "Mischief +5", 1, true) ~= nil
		and string.find(r1, string.format(HINT_HAVE, 1), 1, true) ~= nil, r1)
	check(g, "points unknown (nil): the plain hint, no '(you have'", STORY.Hint(obj, "Halo", nil) == halo, STORY.Hint(obj, "Halo", nil))
	check(g, "0-point picks with points known: still the lean line", STORY.Hint(zero, "Halo", 4) == HINT_LEAN, STORY.Hint(zero, "Halo", 4))
	-- every real choice card: a finished English line (no %d left) for both factions
	for id, def in Config.StoryQuests.Defs or {} do
		for si, st in (type(def) == "table" and def.Steps) or {} do
			local objs = {}
			if type(st) == "table" and type(st.Obj) == "table" then table.insert(objs, st.Obj) end
			for _, f in { "Halo", "Horns" } do
				if type(st) == "table" and type(st[f]) == "table" and type(st[f].Obj) == "table" then table.insert(objs, st[f].Obj) end
			end
			for _, o in objs do
				if o.Type == "Choice" then
					for _, f in { "Halo", "Horns", "Neutral" } do
						local h = STORY.Hint(o, f)
						check(g, "real choice cards: a finished hint line for every faction",
							type(h) == "string" and h ~= "" and string.find(h, "%", 1, true) == nil, id .. " step " .. si .. " " .. f .. " " .. tostring(h))
					end
				end
			end
		end
	end
end

----------------------------------------------------------------- Panels TYPE (UIKit.Typewriter on dialogue lines)
do
	local g = "dialogue typewriter"
	local calls = {}
	local function fakeHandle()
		local h = { State = "typing" }
		h.Finish = function() h.State = "done" end
		h.Done = function() return h.State ~= "typing" end
		return h
	end
	local kit = { Typewriter = function(label, text, opts)
		table.insert(calls, { Label = label, Text = text, Speed = opts and opts.Speed, Speaker = opts and opts.Speaker })
		label.Text = text
		local h = fakeHandle()
		calls[#calls].Handle = h
		return h
	end }
	local made = {}
	local inst = { new = function(class)
		local o = { ClassName = class, Activated = { Connect = function(_, fn) table.insert(made, fn) end } }
		return o
	end }
	local env = { UIKit = kit, Instance = inst, UDim2 = { fromScale = function() return {} end }, tostring = tostring,
		type = type, pcall = pcall }
	local TYPE = execute("TYPE", TYPE_SOURCE .. "\nreturn TYPE", env)
	check(g, "Panels has TYPE.Show / Finish / Tap", type(TYPE) == "table" and type(TYPE.Show) == "function"
		and type(TYPE.Finish) == "function" and type(TYPE.Tap) == "function")
	local label, state = { Text = "", ZIndex = 1 }, {}
	TYPE.Show(state, label, "Hallie here!", "Halo", 1)
	check(g, "a new line types in at 40 letters / s with the speaker's voice", #calls == 1 and calls[1].Speed == 40
		and calls[1].Speaker == "Halo" and calls[1].Text == "Hallie here!", show(calls[1]))
	TYPE.Show(state, label, "Hallie here!", "Halo", 1)
	TYPE.Show(state, label, "Hallie here!", "Halo", 1)
	check(g, "the same page on a refresh never retypes", #calls == 1, #calls)
	check(g, "a tap while it types finishes the line (the tap is used up)", TYPE.Finish(state) == true and calls[1].Handle.Done())
	check(g, "a tap after it finished is free (Next pages on)", TYPE.Finish(state) == false)
	TYPE.Show(state, label, "Welcome to the Knights!", "Halo", 2)
	check(g, "the next page types again", #calls == 2 and calls[2].Text == "Welcome to the Knights!", #calls)
	TYPE.Show(state, label, "Welcome to the Knights!", "Halo", 3)
	check(g, "the same words on another page still type (page in the key)", #calls == 3, #calls)
	TYPE.Tap(state, label)
	check(g, "Tap puts one invisible button over the line that finishes it", #made == 1)
	made[1]()
	check(g, "tapping the line finishes it", calls[3].Handle.Done())
	-- no UIKit.Typewriter (older UIKit): the whole line at once
	local env2 = { UIKit = {}, Instance = inst, UDim2 = { fromScale = function() return {} end }, tostring = tostring,
		type = type, pcall = pcall }
	local TYPE2 = execute("TYPE2", TYPE_SOURCE .. "\nreturn TYPE", env2)
	local l2, st2 = { Text = "" }, {}
	TYPE2.Show(st2, l2, "Fix first. Talk later.", "Guild", 1)
	check(g, "without UIKit.Typewriter the line shows at once", l2.Text == "Fix first. Talk later." and TYPE2.Finish(st2) == false)
end

----------------------------------------------------------------- Panels.Metric (BB38 UiMetric)
do
	local g = "window open metric"
	local W2 = { Now = 0, Sent = {}, Jobs = {} }
	local env = {
		Config = Config, table = table, type = type,
		fire = function(name, id) table.insert(W2.Sent, { Name = name, Id = id, At = W2.Now }) end,
		task = { spawn = function(fn) table.insert(W2.Jobs, coroutine.create(fn)) end,
			wait = function(t) coroutine.yield(t) end },
		Panels = {},
	}
	local P = execute("METRIC", METRIC_SOURCE .. "\nreturn Panels", env)
	-- run the sender coroutine like the task scheduler: each yield(t) waits t seconds
	local function run(seconds)
		local stop = W2.Now + seconds
		while true do
			local job = W2.Jobs[1]
			if not job or W2.Now > stop then break end
			local ok, wait = coroutine.resume(job)
			if coroutine.status(job) == "dead" then table.remove(W2.Jobs, 1) else W2.Now += (tonumber(wait) or 0) end
			if not ok then error(wait) end
		end
	end
	check(g, "Panels has Metric", type(P.Metric) == "function")
	P.Metric("Items")
	P.Metric("Items")
	P.Metric("Settings")
	P.Metric("Nickname") -- not in Config.Analytics.UiIds
	P.Metric("Help")
	run(30)
	local ids = {}
	for _, row in W2.Sent do table.insert(ids, row.Id) end
	check(g, "each listed window once, in order; unknown ids never", table.concat(ids, ",") == "Items,Settings,Help", table.concat(ids, ","))
	local spaced = true
	for i = 2, #W2.Sent do
		if W2.Sent[i].At - W2.Sent[i - 1].At < 2 then spaced = false end
	end
	check(g, "a burst goes out at least 2 s apart (the server allows one per 2 s)", spaced and #W2.Sent == 3, #W2.Sent)
	check(g, "every send is the UiMetric remote with one id", W2.Sent[1] and W2.Sent[1].Name == "UiMetric")
	P.Metric("Items")
	run(5)
	check(g, "a window opened again later is not sent again", #W2.Sent == 3, #W2.Sent)
end

local named = {}
for _, key in order do table.insert(named, Named[key]) end
print("STORY_CLIENT_RESULT_JSON " .. encode({ Checks = checks, Failed = failed, Named = named }))
if failed == 0 then print("STORY_CLIENT_OFFLINE_OK checks=" .. checks) end
