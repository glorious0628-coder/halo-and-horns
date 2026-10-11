-- 조련사 펫 창 몫 (게임성 개발 4, 2026-10-12; server 개발 3 dev3-tamer: PetList Roll, attribute PetRoll, FeedPet): runs
-- the real Config.luau and the real PetWindow.luau (tools/test_pet_tamer.py) on small doubles (the pet window test's:
-- Players attributes, Remotes EquipPet / FeedPet, a Panels registry with LastInventory, a recording kit with SetEnabled,
-- UIKit.ArtImage / Bar). Config.PetSpeedBonus is wrapped to see the roll the window passes (dev3's formula: Lv1 = roll %,
-- MaxLv = roll % + 3). Inputs: CONFIG_SOURCE, PET_SOURCE. Every check is named and counted.
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
local fn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(fn, cfgEnv)
local Config = fn()
-- 개발 3's speed with a roll (the window only passes it on)
local species = Config.PetSpeedBonus
local rollsSeen = {}
Config.PetSpeedBonus = function(sp, lv, roll)
	table.insert(rollsSeen, roll == nil and "nil" or roll)
	if type(roll) == "number" and roll > 0 then
		local maxLv = Config.Pets.MaxLv
		local a = roll / 100
		return a + 0.03 * (math.clamp(lv, 1, maxLv) - 1) / math.max(1, maxLv - 1)
	end
	return species(sp, lv)
end

-- doubles
local NOW = 100
local attrs = { Class = "Warrior", Faction = "Halo", EquippedPet = "", PetLv = 0, PetRoll = 0 }
local player = { GetAttribute = function(_, k) return attrs[k] end }
local sent = {}
local function remoteNamed(name)
	local r = { IsA = function(_, c) return c == "RemoteEvent" end }
	function r.FireServer(_, ...) table.insert(sent, { name, ... }) end
	return r
end
local remoteList = { EquipPet = remoteNamed("EquipPet"), FeedPet = remoteNamed("FeedPet") }
local remotes = { FindFirstChild = function(_, n) return remoteList[n] end }
local listeners = {}
local Net = { Get = function(n)
	return { OnClientEvent = { Connect = function(_, f) listeners[n] = f end } }
end }
local Util = { Warn = function(...) print("WARN", ...) end }
local shared = { WaitForChild = function(_, n) return n end }
local RS = { WaitForChild = function() return shared end, FindFirstChild = function(_, n) if n == "Remotes" then return remotes end return nil end }
local game = { GetService = function(_, n)
	if n == "Players" then return { LocalPlayer = player } end
	if n == "ReplicatedStorage" then return RS end
	return nil
end }
local mods = { Config = Config, Net = Net, Util = Util }
local made = {}
local Instance = { new = function(c)
	local o = { ClassName = c, Children = {} }
	table.insert(made, o)
	return o
end }

local petEnv = setmetatable(table.clone(base), { __index = getfenv() })
petEnv.game, petEnv.Instance = game, Instance
petEnv.require = function(n) return mods[n] end
petEnv.os = { clock = function() return NOW end, time = os.time }
petEnv.task = { spawn = function(f, ...) f(...) end, defer = function(f, ...) f(...) end, delay = function() end }
local pf = assert(loadstring(PET_SOURCE, "=PetWindow"))
setfenv(pf, petEnv)
local PetWindow = pf()

local reg = {}
local current = nil
local rebuilt = 0
local buttons = {}
local order = 0
local inventory = { Items = { PetTreat = 3 } }
local kit = {
	Font = "Font.Gotham", Theme = { Gold = "gold", Text = "text", SubText = "sub", Good = "good" },
	Palette = { Button = "button", DarkText = "dark" },
	NextOrder = function() order += 1 return order end,
	Button = function(parent, text, color, size, onClick)
		local b = { ClassName = "TextButton", Text = text, Color = color, OnClick = onClick, Parent = parent, Enabled = true }
		table.insert(buttons, b)
		return b
	end,
	SetEnabled = function(b, on) b.Enabled = on end,
}
local panels = {
	Register = function(id, opts) reg[id] = opts return true end,
	Open = function(id) current = id return true end,
	CurrentId = function() return current end,
	LastInventory = function() return inventory end,
}
local UIKit = {
	ArtImage = function(name, props)
		local o = { ClassName = "ImageLabel", Image = name, Name = props.Name }
		table.insert(made, o)
		return o
	end,
	Bar = function(props)
		local label = { ClassName = "TextLabel", Text = props.Text }
		local b = { ClassName = "Frame", Name = props.Name, Text = props.Text, Label = label }
		return b, function(f) b.Fill = f end, label
	end,
}
PetWindow.Init({ Panels = panels, UIKit = UIKit })
PetWindow.Start()
local update = nil
kit.Rebuild = function()
	rebuilt += 1
	update = reg.Pet.Build({ ClassName = "ScrollingFrame" }, kit)
end
local function open()
	table.clear(buttons)
	table.clear(made)
	current = "Pet"
	update = reg.Pet.Build({ ClassName = "ScrollingFrame" }, kit)
end
local function texts()
	local out = {}
	for _, o in made do
		if o.ClassName == "TextLabel" then table.insert(out, o.Text) end
	end
	return out
end
local function has(list, s)
	for _, v in list do if v == s then return true end end
	return false
end
local function btnNamed(name, i)
	local n = 0
	for _, b in buttons do
		if b.Name == name then
			n += 1
			if n == (i or 1) then return b end
		end
	end
	return nil
end

local maxLv = Config.Pets.MaxLv
local summoned = { Uid = "P7", Sp = "BabySlime", Lv = 1, XP = 0, Need = 15, Name = "", Lean = "", Roll = { Spd = 7 } }
local found = { Uid = "P1", Sp = "BabySlime", Lv = 3, XP = 5, Need = 45, Name = "Good Buddy", Lean = "Good" }
local topPet = { Uid = "P8", Sp = "BabySlime", Lv = maxLv, XP = 0, Need = 0, Name = "", Lean = "", Roll = { Spd = 10 } }

-- 1. the roll goes into the speed (the summoned pet only)
local rows = PetWindow.Rows({ Equipped = "P7", List = { summoned, found } }, { Class = "Warrior", Faction = "Halo" })
check(rows[1].Uid == "P7" and rows[1].Roll == 7 and rows[1].Speed == 7, "a summoned pet: its roll (7) is its Lv1 speed (+7%)", rows[1].Speed)
check(rows[2].Roll == nil and rows[2].Speed == math.floor(species("BabySlime", 3) * 100 + 0.5), "a found pet: no roll, the species' line")
check(table.find(rollsSeen, 7) ~= nil and table.find(rollsSeen, "nil") ~= nil, "Config.PetSpeedBonus gets the roll (nil without one)")
local fb = PetWindow.Rows(nil, { EquippedPet = "BabySlime", PetLv = 1, PetRoll = 9 })
check(#fb == 1 and fb[1].Roll == 9 and fb[1].Speed == 9, "before the first PetList: the follower's roll from the attribute PetRoll")
check(PetWindow.Rows(nil, { EquippedPet = "BabySlime", PetLv = 1, PetRoll = 0 })[1].Roll == nil, "PetRoll 0 = no roll")
check(reg.Pet.Rebuild.PetRoll == true, "a PetRoll change redraws the window")
listeners.PetList({ Equipped = "P7", List = { summoned, found } })
open()
check(has(texts(), "Born with +7% speed") and not has(texts(), "Born with +0% speed"), "\"Born with +7% speed\" on the summoned pet only",
	table.concat(texts(), ","))
local bornCount = 0
for _, s in texts() do if string.find(s, "Born with", 1, true) then bornCount += 1 end end
check(bornCount == 1, "no line for a pet without a roll", bornCount)

-- 2. research off: no feed button
check(btnNamed("Feed") == nil and rows[1].Feed == nil, "research off (Config.Features.Research): no [Feed]")
check(PetWindow.Feed("P7") == false and #sent == 0, "Feed sends nothing while research is off")

-- 3. research on (개발 3's shapes)
Config.Research = { Treat = "PetTreat", TreatXP = 20, Stages = { 50, 150, 400, 1000, 2500 } }
Config.Loot.Items.PetTreat = { Kind = "Treat", Name = "Pet Treat", Sell = 10, Source = "Craft" }
Config.Features.Research = true
listeners.PetList({ Equipped = "P7", List = { summoned, found, topPet } })
open()
local f1, f2, f3 = btnNamed("Feed", 1), btnNamed("Feed", 2), btnNamed("Feed", 3)
check(f1 and f2 and f3 and f1.Text == "Feed (3)" and f1.Enabled and f2.Enabled, "every pet has [Feed (3)] (3 treats in the bag)", f1 and f1.Text)
check(f3.Enabled == false, "a pet at the top level: [Feed] off")
f1.OnClick()
f1.OnClick()
local feeds = 0
for _, s in sent do if s[1] == "FeedPet" then feeds += 1 end end
check(feeds == 1 and sent[#sent][2] == "P7", "[Feed] = FeedPet(uid), once per Gap", feeds)
NOW += 1
f2.OnClick()
check(sent[#sent][1] == "FeedPet" and sent[#sent][2] == "P1", "... then another pet after Gap")
check(PetWindow.Feed("") == false, "no uid: nothing")
-- the count lives (a treat eaten / made) without a rebuild
rebuilt = 0
inventory = { Items = { PetTreat = 2 } }
update()
check(rebuilt == 0 and f1.Text == "Feed (2)" and f1.Enabled and f3.Enabled == false, "2 left: the buttons say so in place (top level stays off)",
	f1.Text)
inventory = { Items = {} }
update()
check(f1.Text == "Feed (0)" and f1.Enabled == false and f2.Enabled == false, "no treat: [Feed (0)] off")
-- the server's next PetList with the pet fed (XP only): the bars in place, the buttons kept
local fed = table.clone(found)
fed.XP = 25
listeners.PetList({ Equipped = "P7", List = { summoned, fed, topPet } })
check(rebuilt == 0, "the pet's XP after a treat: no rebuild (the bar moves in place)", rebuilt)
open()
check(btnNamed("Feed", 1).Text == "Feed (0)" and btnNamed("Feed", 1).Enabled == false, "opened with no treat: [Feed (0)] off from the start")
Config.Features.Research = false
open()
NOW += 5
local before = #sent
check(btnNamed("Feed") == nil and PetWindow.Feed("P7") == false and #sent == before,
	"the switch off again (its table still there): no [Feed], nothing sent")

print(("PET_TAMER_SUMMARY checks=%d failed=%d"):format(checks, failed))
