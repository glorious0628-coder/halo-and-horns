-- Offline checks for the first-weapon screen words (A23-127, plan 10/13 §1-A #2, 게임성 개발 1) with the real Config.luau:
-- Config.WeaponSource follows Config.WeaponShop.Buy (drops while the Forge sells none, the shop line while it sells),
-- the drop goal's words (Tutorial.Text.NextIronDrop, ShortNames.IronDrop). The runner (tools/test_first_weapon_client.py)
-- prepends CONFIG_SOURCE.
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if not ok then
		failed += 1
		print(("CHECK_FAIL %s :: %s"):format(name, tostring(detail or "")))
	end
end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local cfgEnv = setmetatable({
	game = { GetService = function() return setmetatable({}, { __index = function() return function() return nil end end }) end },
	Vector3 = ctor("Vector3"), Vector2 = ctor("Vector2"), UDim2 = ctor("UDim2"), UDim = ctor("UDim"),
	Color3 = { new = function(...) return { ... } end, fromRGB = function(...) return { ... } end, fromHSV = function() return {} end },
	BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), NumberRange = ctor("NumberRange"),
	NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), Font = ctor("Font"),
	TweenInfo = { new = function(...) return { ... } end }, Enum = enum, Instance = { new = function() return {} end },
	typeof = function(v) return type(v) end, warn = function() end,
}, { __index = getfenv() })
local cfn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cfn, cfgEnv)
local Config = cfn()

local shop = Config.WeaponShop
local was = shop.Buy
shop.Buy = false
check("no weapon sold: tier 2 comes from the Slime Prince (the first one always)",
	Config.WeaponSource(2):find("Slime Prince", 1, true) ~= nil and Config.WeaponSource(2):find("first", 1, true) ~= nil,
	Config.WeaponSource(2))
check("no weapon sold: tier 3 comes from the King Slime (the first one always)",
	Config.WeaponSource(3):find("King Slime", 1, true) ~= nil and Config.WeaponSource(3):find("first", 1, true) ~= nil,
	Config.WeaponSource(3))
check("no weapon sold: no source says 'Sold at the Forge'", not Config.WeaponSource(2):find("Sold", 1, true)
	and not Config.WeaponSource(3):find("Sold", 1, true))
check("tier 1 stays the Blacksmith's gift", Config.WeaponSource(1):find("Blacksmith", 1, true) ~= nil, Config.WeaponSource(1))
check("the first-drop rows really exist (Prince tier 2)", type(Config.Loot.FirstWeaponDrop) == "table"
	and Config.Loot.FirstWeaponDrop.Monster == "BigSlime" and Config.Loot.FirstWeaponDrop.Tier == 2)
shop.Buy = nil
check("selling (Buy not false): the old shop lines", Config.WeaponSource(2) == "Sold at the Forge"
	and Config.WeaponSource(3) == "Sold at the Forge (from Lv5)", Config.WeaponSource(3))
shop.Buy = true
check("Buy = true: the shop lines too", Config.WeaponSource(2) == "Sold at the Forge")
shop.Buy = was
check("tiers without a shop line keep their own", Config.WeaponSource(4) == Config.WeaponInfo[4].Source
	and Config.WeaponSource(9) == "Crafted by artisans")

local T = Config.Tutorial.Text
check("the drop goal line names the King Slime and the iron weapon", type(T.NextIronDrop) == "string"
	and T.NextIronDrop:find("King Slime", 1, true) ~= nil and T.NextIronDrop:find("Iron weapon", 1, true) ~= nil, T.NextIronDrop)
check("the drop goal line has nothing to format and no 'gold' (QuestTarget's old text search)",
	not T.NextIronDrop:find("%", 1, true) and not T.NextIronDrop:lower():find("gold", 1, true), T.NextIronDrop)
check("it starts like the other next goals", T.NextIronDrop:sub(1, #"Next goal · ") == "Next goal · ")
local short = Config.Tutorial.ShortNames.IronDrop
check("the phone row's short name (<= 14 letters, English)", type(short) == "string" and #short <= 14 and #short >= 3
	and not short:find("[^\32-\126]"), short)

print(("FIRST_WEAPON_CLIENT_SUMMARY checks=%d failed=%d"):format(checks, failed))
