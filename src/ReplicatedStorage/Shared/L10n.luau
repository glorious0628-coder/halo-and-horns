-- L10n.luau : the Korean mode's text keys (게임성 개발 1, contract docs/design/l10n_contract_2026-10-11.md v4.1 §2-§6,
-- SPEC A23-111). Shared by server and client; requires only Config (TextKo lazily, on the first Korean lookup).
-- API (§3): Get, Format, T, Msg, Register, LangOf. PathOf (table -> its key path) is the helper UIKit.Tx needs.
--   key   = "<table path>.<field>" ("Config.Text.GooseReward", "Config.Factions.Halo.Perks.1", "HUD.TXT.Bag"); the
--           field is looked up first, then field .. "En". Unknown key -> the key text.
--   Korean only when lang == "ko" and TextKo[key].En == the current English text (else English: a stale entry never
--           shows on the wrong line).
--   Format rules §4: no Args (nil or {}) = no string.format (a literal "%" stays); {n} / {Name} slots, josa markers
--           {1:을} / {Unit:이}; Args filled in a pcall (Korean template -> English template -> key text); missing
--           slots ""; Config.Plural when the template used is the English one. Key tokens ({Auto}) stay raw: the
--           client fills them with Config.FillKeys and its own key map (FillKeys needs that map).
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require(script.Parent:WaitForChild("Config"))

local L10n = {}

local S = {
	Roots = { Config = Config }, -- key prefix -> table (Config registers itself, §2; modules through L10n.Register)
	Paths = setmetatable({}, { __mode = "k" }), -- table -> its key path (shallowest first; Config indexed on demand)
	ConfigIndexed = false,
	Ko = nil, -- TextKo, loaded on first use (pcall; missing = {})
	Studio = nil, -- client in Studio (pseudo-locale §9-9), read once
	MaxDepth = 8, -- nested messages / lists
	JoinKey = "Config.L10n.Join",
	HiddenKey = "Config.Announce.Text.HiddenName", -- "A member of the %s" (AnnounceService.PublicName's words)
	SomeoneKey = "Config.Announce.Text.Someone",
	HonorificKey = "Config.Announce.Text.Honorific",
	-- josa markers after a slot: marker -> { after a final consonant, after a vowel, not Hangul (both) }
	Josa = {},
}
-- built from code points (no Hangul literal in code, tools/test_story_text.py): 을/를, 이/가, 은/는, 과/와
for _, row in { { 0xC744, 0xB97C }, { 0xC774, 0xAC00 }, { 0xC740, 0xB294 }, { 0xACFC, 0xC640 } } do
	local a, b = utf8.char(row[1]), utf8.char(row[2])
	local entry = { a, b, a .. "(" .. b .. ")" }
	S.Josa[a], S.Josa[b] = entry, entry
end
do
	local eu, ro = utf8.char(0xC73C), utf8.char(0xB85C) -- 으, 로 (a final ㄹ takes 로 too)
	local entry = { eu .. ro, ro, "(" .. eu .. ")" .. ro, Ro = true }
	S.Josa[eu .. ro], S.Josa[ro], S.Josa["(" .. eu .. ")" .. ro] = entry, entry, entry
end

local function textKo()
	if S.Ko == nil then
		local ok, t = pcall(function()
			return require(script.Parent:WaitForChild("TextKo", 5))
		end)
		S.Ko = (ok and type(t) == "table") and t or {}
	end
	return S.Ko
end

local function pseudo(s)
	if S.Studio == nil then
		local ok, v = pcall(function() return RunService:IsStudio() and RunService:IsClient() end)
		S.Studio = ok and v == true
	end
	if not S.Studio or s == "" then return s end
	local lp = Players.LocalPlayer
	local ok, on = pcall(function() return lp ~= nil and lp:GetAttribute("L10nPseudo") == true end)
	if ok and on then return "⟦" .. s .. "⟧" end
	return s
end

local function step(node, part)
	if type(node) ~= "table" then return nil end
	local v = node[part]
	if v == nil then
		local n = tonumber(part)
		if n ~= nil then v = node[n] end
	end
	if v == nil then v = node[part .. "En"] end
	return v
end

-- the current English text of a key (nil = no such text)
local function resolve(key)
	local best, bestLen = nil, 0
	for prefix, tbl in S.Roots do
		local n = #prefix
		if n > bestLen and string.sub(key, 1, n + 1) == prefix .. "." then best, bestLen = tbl, n end
	end
	if best == nil then return nil end
	local rest = string.sub(key, bestLen + 2)
	if rest == "" then return nil end
	local node = best
	for part in string.gmatch(rest, "[^%.]+") do
		node = step(node, part)
		if node == nil then return nil end
	end
	return type(node) == "string" and node or nil
end

-- text, isEnglish, english text (text == nil: unknown key)
local function pick(key, lang)
	local en = resolve(key)
	if en == nil then return nil, true, nil end
	if lang == "ko" then
		local e = textKo()[key]
		if type(e) == "table" and type(e.Ko) == "string" and e.Ko ~= "" and e.En == en then return e.Ko, false, en end
	end
	return en, true, en
end

local function hasHangul(s)
	return string.find(s, "[\234-\237][\128-\191][\128-\191]") ~= nil
end

local function josa(text, marker)
	local entry = S.Josa[marker]
	if entry == nil then return marker end
	local last = nil
	pcall(function()
		for _, c in utf8.codes(text) do last = c end
	end)
	if last == nil or last < 0xAC00 or last > 0xD7A3 then return entry[3] end
	local jong = (last - 0xAC00) % 28
	if entry.Ro then return (jong == 0 or jong == 8) and entry[2] or entry[1] end
	return jong ~= 0 and entry[1] or entry[2]
end

local renderArg -- forward
local tr -- forward

local function msg(m, lang, depth)
	if type(m) == "string" then return m end
	if type(m) ~= "table" or depth > S.MaxDepth then return "" end
	if m.Key ~= nil then return tr(m.Key, m.Args, lang, m.Named, depth + 1) end
	return tostring(renderArg(m, lang, depth + 1))
end

-- one Args / Named value (§5-1): string, number, nested message, { Who, Hon }, { Hidden, Hon }, { Join = { ... } }
renderArg = function(v, lang, depth)
	local tv = type(v)
	if tv == "string" or tv == "number" then return v end
	if v == nil then return "" end
	if tv ~= "table" then return tostring(v) end
	if depth > S.MaxDepth then return "" end
	if v.Key ~= nil then return msg(v, lang, depth) end
	if v.Who ~= nil then
		return tostring(v.Who) .. (v.Hon == true and L10n.Get(S.HonorificKey, lang) or "")
	end
	if v.Hidden ~= nil then
		local id = v.Hidden
		local f = type(Config.Factions) == "table" and type(id) == "string" and Config.Factions[id] or nil
		if id ~= "None" and type(f) == "table" then
			return tr(S.HiddenKey, { { Key = "Config.Factions." .. id .. ".Name" } }, lang, nil, depth + 1)
		end
		return L10n.Get(S.SomeoneKey, lang)
	end
	if type(v.Join) == "table" then
		local parts = {}
		for _, m in ipairs(v.Join) do table.insert(parts, tostring(renderArg(m, lang, depth + 1))) end
		return table.concat(parts, L10n.Get(S.JoinKey, lang))
	end
	return ""
end

-- {n} / {Name} slots (+ josa marker); unknown names ({Auto}, key tokens) stay. escape: the text goes through % next
local function braces(template, vals, nvals, escape)
	if not string.find(template, "{", 1, true) then return template end
	return (string.gsub(template, "{([%w_]+)(:?)([^{}]*)}", function(name, colon, marker)
		if colon == "" and marker ~= "" then return nil end
		local v
		local n = tonumber(name)
		if n ~= nil then
			v = vals[n]
			if v == nil then v = "" end
		else
			v = nvals[name]
			if v == nil then return nil end
		end
		local s = tostring(v)
		if marker ~= "" then s ..= josa(s, marker) end
		if escape then s = string.gsub(s, "%%", "%%%%") end
		return s
	end))
end

-- %s / %d / %.1f slots one by one (a missing value = ""); %% -> %. Throws on a bad value (the caller's pcall)
local function percent(template, vals)
	local i = 0
	return (string.gsub(template, "%%([%-%+ #0]*%d*%.?%d*)([%a%%])", function(flags, conv)
		if conv == "%" then return "%" end
		i += 1
		local v = vals[i]
		if v == nil then return "" end
		return string.format("%" .. flags .. conv, v)
	end))
end

local function fill(template, args, lang, named, english, depth)
	if type(template) ~= "string" then return "" end
	if args ~= nil and type(args) ~= "table" then args = { args } end
	local hasArgs = type(args) == "table" and #args > 0
	local hasNamed = type(named) == "table" and next(named) ~= nil
	-- rule 1: no Args (nil or {}), no Named, no "{": the template as it is (never string.format)
	if not hasArgs and not hasNamed and not string.find(template, "{", 1, true) then return template end
	local vals, nvals = {}, {}
	if hasArgs then
		for i = 1, #args do vals[i] = renderArg(args[i], lang, depth) end
	end
	if hasNamed then
		for k, v in named do
			if type(k) == "string" then nvals[k] = renderArg(v, lang, depth) end
		end
	end
	local out = braces(template, vals, nvals, hasArgs)
	if hasArgs then out = percent(out, vals) end
	if english then out = Config.Plural(out) end
	return out
end

tr = function(key, args, lang, named, depth)
	if type(key) ~= "string" then return "" end
	local text, english, en = pick(key, lang)
	if text == nil then return pseudo(key) end
	local ok, out = pcall(fill, pseudo(text), args, lang, named, english, depth)
	if ok and type(out) == "string" then return out end
	if not english then
		ok, out = pcall(fill, pseudo(en), args, lang, named, true, depth)
		if ok and type(out) == "string" then return out end
	end
	return pseudo(key)
end

---------------------------------------------------------------------------------------------------------------- API
function L10n.Get(key, lang)
	if type(key) ~= "string" then return "" end
	local text = pick(key, lang)
	return pseudo(text or key)
end

function L10n.Format(template, args, lang, named)
	if type(template) ~= "string" then return "" end
	local english = lang ~= "ko" or not hasHangul(template)
	local ok, out = pcall(fill, template, args, lang, named, english, 0)
	if ok and type(out) == "string" then return out end
	return template
end

function L10n.T(key, args, lang, named)
	return tr(key, args, lang, named, 0)
end

function L10n.Msg(m, lang)
	local ok, out = pcall(msg, m, lang, 0)
	if ok and type(out) == "string" then return out end
	return ""
end

-- a client module's text table ("HUD.TXT"); inner tables come with it ("SkillBook.T" covers "SkillBook.T.Text.Title")
local function index(path, tbl)
	local queue, seen, head = { { path, tbl } }, {}, 1
	while queue[head] ~= nil do
		local p, t = queue[head][1], queue[head][2]
		head += 1
		if not seen[t] then
			seen[t] = true
			if S.Paths[t] == nil then S.Paths[t] = p end
			for k, v in t do
				local tk = type(k)
				if type(v) == "table" and not seen[v] and (tk == "number" or (tk == "string" and not string.find(k, ".", 1, true))) then
					table.insert(queue, { p .. "." .. tostring(k), v })
				end
			end
		end
	end
end

function L10n.Register(path, tbl)
	if type(path) ~= "string" or path == "" or path == "Config" or type(tbl) ~= "table" then return tbl end
	S.Roots[path] = tbl
	index(path, tbl)
	return tbl
end

-- the key path of a registered table (or a Config table), nil when it is not part of one
function L10n.PathOf(tbl)
	if type(tbl) ~= "table" then return nil end
	local p = S.Paths[tbl]
	if p == nil and not S.ConfigIndexed then
		S.ConfigIndexed = true
		index("Config", Config)
		p = S.Paths[tbl]
	end
	return p
end

-- attribute Lang ("ko" / "en", set by the server, §1), else the Roblox locale: "ko*" -> "ko", else "en"
function L10n.LangOf(player)
	if player == nil then return "en" end
	local ok, lang = pcall(function() return player:GetAttribute("Lang") end)
	if ok and (lang == "ko" or lang == "en") then return lang end
	local ok2, loc = pcall(function() return player.LocaleId end)
	if ok2 and type(loc) == "string" and string.lower(string.sub(loc, 1, 2)) == "ko" then return "ko" end
	return "en"
end

return L10n
