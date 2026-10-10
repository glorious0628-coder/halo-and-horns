-- 검수 2026-10-10 (A23-113 follow-up): the plain-English text of the passes, Config.PassInfo. The real Config.luau with engine
-- doubles; the words must say what the code does and move with its numbers. Input: CONFIG_SOURCE.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if not ok then
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end
local ENUM
do
	local types = {}
	ENUM = setmetatable({}, { __index = function(_, typeName)
		local t = types[typeName]
		if not t then
			local cache = {}
			t = setmetatable({}, { __index = function(_, itemName)
				local e = cache[itemName]
				if not e then
					e = { Name = itemName, EnumType = typeName, __kind = "EnumItem" }
					cache[itemName] = e
				end
				return e
			end })
			types[typeName] = t
		end
		return t
	end })
end
local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __kind = "Vector3" }, vmt) end
vmt.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vmt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local env = setmetatable({ Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec },
	Color3 = { new = vec, fromRGB = vec, fromHSV = vec }, BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"),
	UDim2 = ctor("UDim2"), UDim = ctor("UDim"), NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"),
	ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"), CFrame = ctor("CFrame"),
	TweenInfo = ctor("TweenInfo"), Font = ctor("Font"), Enum = ENUM }, { __index = getfenv() })
local fn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(fn, env)
local Config = fn()

local I = Config.PassInfo
check(type(I) == "table", "Config.PassInfo exists")
local KINDS = { "XP2", "Gold2", "VIP", "Look", "PrivateServer" }
local function has(text, word) return string.find(string.lower(text), string.lower(word), 1, true) ~= nil end

-- the numbers stay as they were (the text only follows them)
local P = Config.GamePasses
check(P.XP2.Price == 199 and P.Gold2.Price == 149 and P.VIP.Price == 249 and Config.PassBoost.Mult == 2,
	"prices 199 / 149 / 249 and the 2x are untouched", { P.XP2.Price, P.Gold2.Price, P.VIP.Price, Config.PassBoost.Mult })

-- every kind has a card line and a page description in plain ASCII English
local count = 0
for _, kind in KINDS do
	local row = I and I[kind]
	local line, desc = row and row.Line, row and row.Desc
	check(type(line) == "string" and #line >= 6 and #line <= 38, kind .. ": a short card line (6-38 letters)", line)
	check(type(desc) == "string" and #desc >= 40 and #desc <= 300, kind .. ": a page description (40-300 letters)", desc and #desc)
	for _, text in { tostring(line), tostring(desc) } do
		check(not string.find(text, "[^\32-\126]"), kind .. ": plain ASCII (no Korean, no fancy dashes)", text)
	end
	check(type(desc) == "string" and has(desc, I and I.NoStats or "?"), kind .. ": says 'No stats are for sale.'", desc)
	count += 1
end
check(count == 5 and I and I.NoStats == "No stats are for sale.", "5 kinds and the one no-stats sentence", I and I.NoStats)

-- the words say what the code does
local mult = Config.PassBoost.Mult .. "x"
check(has(I.XP2.Line, mult) and has(I.XP2.Desc, mult) and has(I.XP2.Desc, "xp") and has(I.XP2.Desc, "level"),
	"2x XP: the text names XP, leveling and the multiplier (Config.PassBoost.Mult)", I.XP2.Desc)
check(not has(I.XP2.Desc, "gold") and not has(I.XP2.Line, "gold"), "2x XP does not talk about gold", I.XP2.Desc)
check(has(I.Gold2.Line, mult) and has(I.Gold2.Desc, mult) and has(I.Gold2.Desc, "gold"), "2x Gold: gold and the multiplier", I.Gold2.Desc)
check(not has(I.Gold2.Desc, "xp") and not has(I.Gold2.Desc, "level"), "2x Gold does not talk about XP or levels", I.Gold2.Desc)
check(Config.PassBoost.GoldSources.Plunder == nil and has(I.Gold2.Desc, "other players is not doubled"),
	"2x Gold: gold taken from other players is not doubled (Plunder is not a doubled source) and the text says so", I.Gold2.Desc)
check(Config.PassBoost.GoldSources.Monster == true and Config.PassBoost.GoldSources.Quest == true and has(I.Gold2.Desc, "hunting")
	and has(I.Gold2.Desc, "quests"), "2x Gold: hunting and quests are doubled sources and named", I.Gold2.Desc)
check(has(I.VIP.Desc, "crown") and has(I.VIP.Desc, "chat") and has(I.VIP.Desc, "Supporters board"), "VIP: the crown, the chat tag and the Supporters board",
	I.VIP.Desc)
check(not has(I.VIP.Desc, "emote") and not has(I.VIP.Line, "emote"), "VIP: no emote is promised (it is not built)", I.VIP.Desc)
check(has(I.Look.Desc, "color") and has(I.Look.Desc, "only changes how you look"), "Looks: only the looks change", I.Look.Desc)
check(has(I.PrivateServer.Desc, "private server") and has(I.PrivateServer.Desc, "friends"), "Private server: for you and your friends",
	I.PrivateServer.Desc)
-- never a promise of strength
for _, kind in KINDS do
	local desc = I[kind].Desc
	check(not has(desc, "stronger") and not has(desc, "damage") and not has(desc, "power") and not has(desc, "win"),
		kind .. ": no promise of strength or winning", desc)
end
print("PASS_TEXT_SUMMARY checks=" .. checks .. " failed=" .. failed)
