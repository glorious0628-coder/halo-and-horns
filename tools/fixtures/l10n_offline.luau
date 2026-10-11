-- 한국어 모드 L10n 중심 (게임성 개발 1, 2026-10-11; contract docs/design/l10n_contract_2026-10-11.md v4.1): runs the
-- real Config.luau, L10n.luau, TextKo.luau and Net.luau (tools/test_l10n.py) on small doubles: game:GetService
-- (RunService with a Studio / client switch, Players.LocalPlayer attributes, ReplicatedStorage.Remotes recording
-- FireClient / FireAllClients), script.Parent:WaitForChild + require by name, and a small fixture TextKo.
-- Inputs: CONFIG_SOURCE, L10N_SOURCE, TEXTKO_SOURCE, NET_SOURCE. Every check is named and counted.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then
		print("CHECK_OK " .. name)
	else
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end

local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vmt) end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local base = { Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec },
	Color3 = { new = vec, fromRGB = vec, fromHSV = vec }, BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"),
	UDim2 = ctor("UDim2"), UDim = ctor("UDim"), NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"),
	ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"),
	Font = ctor("Font"), Enum = enum }
local cfgEnv = setmetatable(table.clone(base), { __index = getfenv() })
cfgEnv.workspace = { GetServerTimeNow = function() return 1790000000 end }
local cfn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cfn, cfgEnv)
local Config = cfn()

-- doubles
local W = { Studio = false, Client = false }
local lpAttrs = {}
local localPlayer = { GetAttribute = function(_, k) return lpAttrs[k] end }
local fired = {}
local remote = {
	FireClient = function(_, p, payload) table.insert(fired, { To = p, Payload = payload }) end,
	FireAllClients = function(_, payload) table.insert(fired, { To = "all", Payload = payload }) end,
}
local RS = { Remotes = { FindFirstChild = function(_, n) return remote end },
	WaitForChild = function(_, n) return { WaitForChild = function() return remote end } end }
local RunService = { IsStudio = function() return W.Studio end, IsClient = function() return W.Client end,
	IsServer = function() return not W.Client end }
local game = { GetService = function(_, n)
	if n == "RunService" then return RunService end
	if n == "Players" then return { LocalPlayer = W.Client and localPlayer or nil } end
	if n == "ReplicatedStorage" then return RS end
	return nil
end }
local function loadModule(source, name, mods)
	local parent = { WaitForChild = function(_, n) return n end, FindFirstChild = function(_, n) return n end }
	local env = setmetatable(table.clone(base), { __index = getfenv() })
	env.game = game
	env.script = { Parent = parent }
	env.require = function(n)
		local m = mods[n]
		if m == nil then error("no module " .. tostring(n)) end
		return m
	end
	local f = assert(loadstring(source, "=" .. name))
	setfenv(f, env)
	return f()
end

local REAL_KO = loadModule(TEXTKO_SOURCE, "TextKo", {})
local KO = {
	["Config.Settings.Text.Lang"] = { Ko = "언어", En = "Language" }, -- current
	["Config.Settings.Text.Music"] = { Ko = "음악", En = "Music!" }, -- stale (English changed)
	["Config.Text.NoSuchLine"] = { Ko = "없는 줄", En = "No such line" }, -- key does not resolve
	["Config.Announce.Text.RareWeapon"] = { Ko = "{1:이} {2:을} 물리치고 {3} 무기 [{4}]를 얻었어요!",
		En = "%s beat a %s and got a %s weapon: [%s]!" }, -- {n} reorder + josa (good)
	["Config.Announce.Text.FirstMax"] = { Ko = "%d님이 [%s]를 처음으로 +10까지 강화했어요!",
		En = "%s is the first to enhance [%s] to +10!" }, -- %d for %s (placeholder types differ)
	["Config.Announce.Text.Subject"] = { Ko = "%d", En = "%s" }, -- fails with a string: English fallback
	["Config.Announce.Text.More"] = { Ko = "%s 님이 좋은 물건을 %d개 더 찾았어요!", En = "%s found %d more great things!" }, -- stale
	["Config.Announce.Text.HiddenName"] = { Ko = "%s 한 명", En = "A member of the %s" },
	["Config.Factions.Halo.Name"] = { Ko = "빛의 기사단", En = "Knights of Light" },
}
local function newL10n(ko)
	return loadModule(L10N_SOURCE, "L10n", { Config = Config, TextKo = ko })
end
local L10n = newL10n(KO)

---------------------------------------------------------------- §9-1 / §9-2 / §9-4 audit of a TextKo table
local function specs(s)
	local out = {}
	for flags, conv in string.gmatch(s, "%%([%-%+ #0]*%d*%.?%d*)([%a%%])") do
		if conv ~= "%" then table.insert(out, flags .. conv) end
	end
	return out
end
local function tokens(s)
	local nums, names, maxN = {}, {}, 0
	for name in string.gmatch(s, "{([%w_]+)[^{}]*}") do
		local n = tonumber(name)
		if n then
			nums[n] = true
			maxN = math.max(maxN, n)
		else
			names[name] = true
		end
	end
	return nums, names, maxN
end
local function sameNames(a, b)
	for k in a do if not b[k] then return false end end
	for k in b do if not a[k] then return false end end
	return true
end
local function samePlaceholders(en, ko)
	local se, sk = specs(en), specs(ko)
	local _, ne, maxE = tokens(en)
	local nk, nameK, maxK = tokens(ko)
	if not sameNames(ne, nameK) then return false end
	if maxK > 0 then
		if #sk > 0 then return false end -- never % and {n} in one text
		local allowed = math.max(#se, maxE)
		for n in nk do if n > allowed then return false end end
		return true
	end
	if maxE > 0 then return false end
	if #se ~= #sk then return false end
	for i = 1, #se do if se[i] ~= sk[i] then return false end end
	return true
end
local function audit(L, ko)
	local unresolved, mismatch, stale = {}, {}, {}
	for key, e in ko do
		local en = L.Get(key, "en")
		if en == key then
			table.insert(unresolved, key)
		else
			if type(e) ~= "table" or e.En ~= en then table.insert(stale, key) end
			if type(e) ~= "table" or type(e.Ko) ~= "string" or not samePlaceholders(en, e.Ko) then table.insert(mismatch, key) end
		end
	end
	table.sort(unresolved)
	table.sort(mismatch)
	table.sort(stale)
	return unresolved, mismatch, stale
end
local function list(t) return table.concat(t, ", ") end

local u, m, s = audit(newL10n(REAL_KO), REAL_KO)
check(type(REAL_KO) == "table", "the real TextKo.luau returns a table")
check(#u == 0, "§9-1 every real TextKo key resolves to an English text", list(u))
check(#m == 0, "§9-2 every real TextKo entry keeps the placeholder sequence", list(m))
check(#s == 0, "§9-4 no stale real TextKo entry (list for 검수)", list(s))
print("STALE_REAL " .. list(s))
u, m, s = audit(L10n, KO)
check(list(u) == "Config.Text.NoSuchLine", "§9-1 a fixture key that does not resolve is listed", list(u))
check(list(m) == "Config.Announce.Text.FirstMax, Config.Announce.Text.Subject",
	"§9-2 %d for %s is listed; {n} reorder + josa passes", list(m))
check(list(s) == "Config.Announce.Text.More, Config.Settings.Text.Music", "§9-4 stale entries (saved En != English) listed", list(s))
print("STALE_FIXTURE " .. list(s))
check(samePlaceholders("%s got %.1f", "%s: %.1f") and not samePlaceholders("%s got %.1f", "%s: %d")
	and not samePlaceholders("Press {Auto}", "누르기") and not samePlaceholders("%s %s", "{1} %s")
	and samePlaceholders("Beat {Unit}", "{Unit:을} 잡기"), "§9-2 types, key tokens, % with {n}, named + josa")

---------------------------------------------------------------- Get / keys (§2, §6)
check(L10n.Get("Config.Settings.Text.Lang", "ko") == "언어", "ko + current entry -> Korean", L10n.Get("Config.Settings.Text.Lang", "ko"))
check(L10n.Get("Config.Settings.Text.Lang", "en") == "Language", "en -> English")
check(L10n.Get("Config.Settings.Text.Music", "ko") == "Music", "stale entry -> English", L10n.Get("Config.Settings.Text.Music", "ko"))
check(L10n.Get("Config.Factions.Halo.Perks.2", "en") == Config.Factions.Halo.Perks[2], "array index key (Perks.2)",
	L10n.Get("Config.Factions.Halo.Perks.2", "en"))
check(L10n.Get("Config.Text.NoSuchLine", "ko") == "Config.Text.NoSuchLine", "unknown key -> the key text")
check(L10n.Get(nil, "en") == "", "a non-string key -> \"\"")
local MOD = { Bag = "Bag", Inner = { Title = "Hi", TitleEn = "Hi" }, List = { "a", "b" }, CoinEn = "Coins",
	Both = "new", BothEn = "old" }
check(L10n.Register("Mod.TXT", MOD) == MOD, "Register returns the table")
check(L10n.Get("Mod.TXT.Bag", "en") == "Bag" and L10n.Get("Mod.TXT.Inner.Title", "en") == "Hi"
	and L10n.Get("Mod.TXT.List.2", "en") == "b", "registered table: field, inner table, array", L10n.Get("Mod.TXT.List.2", "en"))
check(L10n.Get("Mod.TXT.Coin", "en") == "Coins", "leaf .. \"En\" when the leaf is missing", L10n.Get("Mod.TXT.Coin", "en"))
check(L10n.Get("Mod.TXT.Both", "en") == "new", "leaf first, then leaf .. \"En\"", L10n.Get("Mod.TXT.Both", "en"))
check(L10n.Get("Mod.TXT.Nope", "en") == "Mod.TXT.Nope" and L10n.Get("Other.Bag", "en") == "Other.Bag", "unregistered -> key text")
check(L10n.PathOf(MOD.Inner) == "Mod.TXT.Inner" and L10n.PathOf(MOD) == "Mod.TXT", "PathOf finds a registered table by identity",
	L10n.PathOf(MOD.Inner))
check(L10n.PathOf(Config.Settings.Text) == "Config.Settings.Text", "PathOf finds a Config table", L10n.PathOf(Config.Settings.Text))
check(L10n.PathOf({}) == nil, "PathOf: an unknown table -> nil")

---------------------------------------------------------------- Format rules (§4, §9-6)
local perk = Config.Factions.Halo.Perks[1]
check(string.find(perk, "%", 1, true) ~= nil, "the fixture Perks.1 text has a literal %", perk)
check(L10n.T("Config.Factions.Halo.Perks.1", nil, "en") == perk and L10n.T("Config.Factions.Halo.Perks.1", {}, "en") == perk,
	"no Args (nil and {}): a literal % stays (Perks.1)", L10n.T("Config.Factions.Halo.Perks.1", {}, "en"))
check(L10n.Format("Rate 50%% and 10%dash", nil, "en") == "Rate 50%% and 10%dash"
	and L10n.Format("Rate 50%% and 10%dash", {}, "en") == "Rate 50%% and 10%dash", "no Args (nil and {}): no string.format at all",
	L10n.Format("Rate 50%% and 10%dash", {}, "en"))
check(L10n.Format("Enhance Scroll %d%%", { 10 }, "en") == "Enhance Scroll 10%", "%% with Args -> %",
	L10n.Format("Enhance Scroll %d%%", { 10 }, "en"))
check(L10n.Format("+%s gold +%s XP", { "12.3K", "300" }, "en") == "+12.3K gold +300 XP", "%s slots, pre-formatted strings")
check(L10n.Format("%.1f s", { 2.345 }, "en") == "2.3 s", "%.1f slot", L10n.Format("%.1f s", { 2.345 }, "en"))
check(L10n.Format("%s and %s", { "a" }, "en") == "a and " and L10n.Format("{1}-{2}", { "a" }, "en") == "a-",
	"missing slots -> \"\"", L10n.Format("%s and %s", { "a" }, "en"))
check(L10n.Format("{2} then {1}", { "a", "b" }, "ko") == "b then a", "{n} numbered slots (reorder)", L10n.Format("{2} then {1}", { "a", "b" }, "ko"))
check(L10n.Format("{1} done", { "50%" }, "en") == "50% done", "a % inside a slot value survives the % pass",
	L10n.Format("{1} done", { "50%" }, "en"))
check(L10n.Format("Beat %d %s", "x", "en") ~= nil, "a non-table Args does not throw")
-- pcall fallback: Korean template -> English template -> key text
check(L10n.T("Config.Announce.Text.Subject", { "Bo" }, "ko") == "Bo", "a failing Korean template -> the English template",
	L10n.T("Config.Announce.Text.Subject", { "Bo" }, "ko"))
check(L10n.T("Config.Announce.Text.More", { "Bo", "x" }, "en") == "Config.Announce.Text.More", "the English template fails too -> key text",
	L10n.T("Config.Announce.Text.More", { "Bo", "x" }, "en"))
check(L10n.Format("%d left", { "x" }, "en") == "%d left", "Format: a failing template -> the template")
-- Plural on the English template only
check(L10n.T("Config.Announce.Text.More", { "Bo", 1 }, "en") == "Bo found 1 more great item!", "en: Config.Plural on the English template",
	L10n.T("Config.Announce.Text.More", { "Bo", 1 }, "en"))
check(L10n.T("Config.Announce.Text.More", { "Bo", 1 }, "ko") == "Bo found 1 more great item!", "ko falling back (stale) -> English + Plural",
	L10n.T("Config.Announce.Text.More", { "Bo", 1 }, "ko"))
check(L10n.T("Config.Announce.Text.More", { "Bo", 3 }, "en") == "Bo found 3 more great items!", "Plural keeps 3 items")
check(L10n.Format("%d days 남음", { 1 }, "ko") == "1 days 남음", "a Korean template gets no Plural", L10n.Format("%d days 남음", { 1 }, "ko"))
check(L10n.Format("Away for %d days", { 1 }, "en") == "Away for 1 day", "Format en: Plural", L10n.Format("Away for %d days", { 1 }, "en"))
-- josa
local function j(t, v) return L10n.Format(t, { v }, "ko") end
check(j("{1:을}", "사과") == "사과를" and j("{1:을}", "책") == "책을" and j("{1:를}", "책") == "책을", "을/를 by the last syllable",
	j("{1:을}", "사과"))
check(j("{1:이}", "철수") == "철수가" and j("{1:가}", "곰") == "곰이", "이/가", j("{1:이}", "철수"))
check(j("{1:은}", "나") == "나는" and j("{1:는}", "밥") == "밥은", "은/는", j("{1:은}", "나"))
check(j("{1:와}", "책") == "책과" and j("{1:과}", "나") == "나와", "와/과", j("{1:와}", "책"))
check(j("{1:(으)로}", "집") == "집으로" and j("{1:(으)로}", "나무") == "나무로", "(으)로", j("{1:(으)로}", "집"))
check(j("{1:(으)로}", "서울") == "서울로" and j("{1:으로}", "물") == "물로", "(으)로 after a final ㄹ -> 로", j("{1:(으)로}", "서울"))
check(j("{1:을}", "Bob") == "Bob을(를)" and j("{1:이}", "3") == "3이(가)" and j("{1:로}", "Bob") == "Bob(으)로",
	"not Hangul -> both forms", j("{1:을}", "Bob"))
check(L10n.T("Config.Announce.Text.RareWeapon", { "철수", "슬라임", "Rare", "Sword" }, "ko") == "철수가 슬라임을 물리치고 Rare 무기 [Sword]를 얻었어요!",
	"Korean {n} + josa template from TextKo", L10n.T("Config.Announce.Text.RareWeapon", { "철수", "슬라임", "Rare", "Sword" }, "ko"))
-- Named
check(L10n.Format("Beat 3 {Unit}", nil, "en", { Unit = { Key = "Config.Factions.Halo.Short" } }) == "Beat 3 Knights",
	"Named token with a nested message (no Args)", L10n.Format("Beat 3 {Unit}", nil, "en", { Unit = { Key = "Config.Factions.Halo.Short" } }))
check(L10n.Format("Press {Auto} to {Unit}", nil, "en", { Unit = "x" }) == "Press {Auto} to x", "key tokens ({Auto}) stay raw")
check(L10n.Format("{Unit:을} 잡아요", nil, "ko", { Unit = "슬라임" }) == "슬라임을 잡아요", "Named + josa")
check(L10n.T("Config.Announce.Text.Subject", { "Bo" }, "en", { Unit = "x" }) == "Bo", "Args + Named together")

---------------------------------------------------------------- Msg (§5-1)
check(L10n.Msg({ Key = "Config.Announce.Text.HiddenName", Args = { { Key = "Config.Factions.Halo.Name" } } }, "en")
	== "A member of the Knights of Light", "nested message")
check(L10n.Msg({ Key = "Config.Announce.Text.HiddenName", Args = { { Key = "Config.Factions.Halo.Name" } } }, "ko") == "빛의 기사단 한 명",
	"nested message in Korean")
check(L10n.Msg({ Key = "Config.Announce.Text.Subject", Args = { { Who = "Bo" } } }, "en") == "Bo", "Who")
local honWas = Config.Announce.Text.Honorific
Config.Announce.Text.Honorific = "-nim"
check(L10n.Msg({ Key = "Config.Announce.Text.Subject", Args = { { Who = "Bo", Hon = true } } }, "en") == "Bo-nim"
	and L10n.Msg({ Key = "Config.Announce.Text.Subject", Args = { { Who = "Bo" } } }, "en") == "Bo", "Who + Hon adds the honorific")
Config.Announce.Text.Honorific = honWas
check(L10n.Msg({ Key = "Config.Announce.Text.Subject", Args = { { Hidden = "Halo", Hon = true } } }, "en") == "A member of the Knights of Light",
	"Hidden faction -> A member of the <faction>", L10n.Msg({ Key = "Config.Announce.Text.Subject", Args = { { Hidden = "Halo" } } }, "en"))
check(L10n.Msg({ Key = "Config.Announce.Text.Subject", Args = { { Hidden = "None" } } }, "en") == Config.Announce.Text.Someone
	and L10n.Msg({ Key = "Config.Announce.Text.Subject", Args = { { Hidden = "Bogus" } } }, "en") == Config.Announce.Text.Someone,
	"Hidden None / unknown -> Someone")
check(L10n.Format("{1:이} 왔어요", { { Hidden = "Halo" } }, "ko") == "빛의 기사단 한 명이 왔어요", "Hidden in Korean + josa",
	L10n.Format("{1:이} 왔어요", { { Hidden = "Halo" } }, "ko"))
check(L10n.Msg({ Join = { { Key = "Config.Factions.Halo.Short" }, "50 gold", { Who = "Bo" } } }, "en") == "Knights · 50 gold · Bo",
	"Join with the Config.L10n.Join separator", L10n.Msg({ Join = { { Key = "Config.Factions.Halo.Short" }, "50 gold", { Who = "Bo" } } }, "en"))
check(Config.L10n ~= nil and Config.L10n.Join == " · ", "Config.L10n.Join is \" · \"")
check(L10n.Msg({ Key = "Config.Announce.Text.Subject", Args = { { Join = { "a", "b" } } } }, "en") == "a · b", "a list inside a message")
check(L10n.Msg({ Key = "Config.Announce.Text.Subject", Named = { Unit = "x" }, Args = { 5 } }, "en") == "5", "a number arg in %s")
local loop = { Key = "Config.Announce.Text.Subject" }
loop.Args = { loop }
check(type(L10n.Msg(loop, "en")) == "string", "a message that contains itself ends (depth limit)")
check(L10n.Msg("plain", "en") == "plain" and L10n.Msg(nil, "en") == "", "Msg: plain string / nil")

---------------------------------------------------------------- LangOf (§1)
local function pl(lang, loc) return { GetAttribute = function(_, k) return k == "Lang" and lang or nil end, LocaleId = loc } end
check(L10n.LangOf(pl("ko", "en-us")) == "ko" and L10n.LangOf(pl("en", "ko-kr")) == "en", "attribute Lang wins")
check(L10n.LangOf(pl(nil, "ko-kr")) == "ko" and L10n.LangOf(pl("xx", "ko-KR")) == "ko", "no / bad attribute: LocaleId ko* -> ko")
check(L10n.LangOf(pl(nil, "en-us")) == "en" and L10n.LangOf(nil) == "en", "else en")

---------------------------------------------------------------- pseudo-locale (§9-9)
lpAttrs.L10nPseudo = true
W.Studio, W.Client = false, true
check(newL10n(KO).Get("Config.Settings.Text.Lang", "en") == "Language", "pseudo flag outside Studio: no marks")
W.Studio, W.Client = true, false
check(newL10n(KO).Get("Config.Settings.Text.Lang", "en") == "Language", "pseudo flag on a Studio server: no marks")
W.Studio, W.Client = true, true
local P = newL10n(KO)
check(P.Get("Config.Settings.Text.Lang", "en") == "⟦Language⟧" and P.Get("Config.Settings.Text.Lang", "ko") == "⟦언어⟧",
	"Studio client + L10nPseudo: Get wraps in ⟦…⟧", P.Get("Config.Settings.Text.Lang", "en"))
check(P.T("Config.Announce.Text.More", { "Bo", 1 }, "en") == "⟦Bo found 1 more great item!⟧", "pseudo: T wraps the template",
	P.T("Config.Announce.Text.More", { "Bo", 1 }, "en"))
lpAttrs.L10nPseudo = nil
check(newL10n(KO).Get("Config.Settings.Text.Lang", "en") == "Language", "Studio client without the flag: no marks")
W.Studio, W.Client = false, false

---------------------------------------------------------------- Net.NotifyKey / NotifyAllKey (§5-3)
local Ls = newL10n(KO)
local Net = loadModule(NET_SOURCE, "Net", { L10n = Ls, Config = Config })
local who = { Name = "P1" }
table.clear(fired)
Net.NotifyKey(who, "Config.Announce.Text.Subject", { { Hidden = "Halo" } }, nil, 3, "Coin", { Unit = "x" })
local f1 = fired[1]
check(f1 ~= nil and f1.To == who and f1.Payload.Key == "Config.Announce.Text.Subject" and f1.Payload.Kind == "info"
	and f1.Payload.Duration == 3 and f1.Payload.Sound == "Coin" and f1.Payload.Named.Unit == "x" and f1.Payload.Args[1].Hidden == "Halo",
	"NotifyKey sends Key, Args, Named, Kind (info), Duration, Sound")
check(f1 and f1.Payload.Text == "A member of the Knights of Light", "NotifyKey Text = the English L10n.Msg", f1 and f1.Payload.Text)
Net.NotifyAllKey("Config.Factions.Halo.Perks.1", {})
local f2 = fired[2]
check(f2 and f2.To == "all" and f2.Payload.Kind == "announce" and f2.Payload.Text == perk, "NotifyAllKey(key, {}): announce, literal % kept",
	f2 and f2.Payload.Text)
W.Studio = true
local okBad = pcall(Net.NotifyKey, who, "Config.Text.NoSuchLine", nil)
check(not okBad and #fired == 2, "Studio: an unknown key errors (nothing sent)", #fired)
W.Studio = false
Net.NotifyKey(who, "Config.Text.NoSuchLine", nil)
check(fired[3] and fired[3].Payload.Text == "Config.Text.NoSuchLine", "live server: an unknown key still sends (key text)")
Net.Notify(who, "Hello", "good")
check(fired[4] and fired[4].Payload.Text == "Hello" and fired[4].Payload.Key == nil, "Net.Notify unchanged (Text only)")

print(string.format("L10N_SUMMARY checks=%d failed=%d", checks, failed))
