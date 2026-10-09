-- PET-5 펫 창 (게임성 개발 1, 2026-10-09; server PET-2 PetList / EquipPet): runs the real Config.luau and the real
-- PetWindow.luau (tools/test_pet_window.py) on small doubles: Players.LocalPlayer attributes, a Remotes folder with
-- EquipPet, a Panels registry that builds the window with a recording kit, UIKit.ArtImage / Bar.
-- Inputs: CONFIG_SOURCE, PET_SOURCE. Every check is named and counted.
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

-- doubles
local NOW = 100
local attrs = { Class = "Warrior", Faction = "Halo", EquippedPet = "", PetLv = 0 }
local player = { GetAttribute = function(_, k) return attrs[k] end }
local sent = {}
local remote = { IsA = function(_, c) return c == "RemoteEvent" end }
function remote.FireServer(_, ...) table.insert(sent, { ... }) end
local remotes = { FindFirstChild = function(_, n) if n == "EquipPet" then return remote end return nil end }
local listeners = {}
local Net = { Get = function(n)
	return { OnClientEvent = { Connect = function(_, f) listeners[n] = f end } }
end }
local Util = { Warn = function(...) print("WARN", ...) end }
local shared = { WaitForChild = function(_, n) return n end }
local RS = { WaitForChild = function(_, n) return shared end, FindFirstChild = function(_, n) if n == "Remotes" then return remotes end return nil end }
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

-- a Panels double: Register keeps opts; open() builds into a fresh parent with a recording kit
local reg = {}
local current = nil
local rebuilt = 0
local buttons = {}
local order = 0
local kit = {
	Font = "Font.Gotham", Theme = { Gold = "gold", Text = "text", SubText = "sub", Good = "good" },
	Palette = { Button = "button", DarkText = "dark" },
	NextOrder = function() order += 1 return order end,
	Button = function(parent, text, color, size, onClick)
		local b = { ClassName = "TextButton", Text = text, Color = color, OnClick = onClick, Parent = parent }
		table.insert(buttons, b)
		return b
	end,
	Rebuild = nil, -- set below: Panels builds the window again (Build updates what it shows)
}
local panels = {
	Register = function(id, opts) reg[id] = opts return true end,
	Open = function(id) current = id return true end,
	CurrentId = function() return current end,
}
local bars = {}
local UIKit = {
	ArtImage = function(name, props)
		local o = { ClassName = "ImageLabel", Image = name, Name = props.Name }
		table.insert(made, o)
		return o
	end,
	Bar = function(props)
		local b = { ClassName = "Frame", Name = props.Name, Text = props.Text, Fill = nil }
		table.insert(bars, b)
		return b, function(f) b.Fill = f end, nil
	end,
}
PetWindow.Init({ Panels = panels, UIKit = UIKit })
PetWindow.Start()
kit.Rebuild = function()
	rebuilt += 1
	reg.Pet.Build({ ClassName = "ScrollingFrame" }, kit)
end
local function open()
	table.clear(buttons)
	table.clear(bars)
	table.clear(made)
	current = "Pet"
	reg.Pet.Build({ ClassName = "ScrollingFrame" }, kit)
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
local function btn(text)
	for _, b in buttons do if b.Text == text then return b end end
	return nil
end

-- 0. registered
check(reg.Pet ~= nil and PetWindow.IsReady(), "the window \"Pet\" is registered (the HUD's Pet tile shows)", reg.Pet)
check(reg.Pet.Rebuild and reg.Pet.Rebuild.EquippedPet and reg.Pet.Rebuild.PetLv, "it redraws when the pet / level changes")
check(type(listeners.PetList) == "function", "it listens to PetList")

-- 1. no pet
open()
check(#buttons == 0 and has(texts(), "No pets yet."), "no pet: one quiet line, no buttons", table.concat(texts(), ","))

-- 2. the first PetList (one follower, level 3)
local need3 = 15 * 3
local payload = { Equipped = "P1", List = { { Uid = "P1", Sp = "BabySlime", Lv = 3, XP = 12, Need = need3, Name = "Good Buddy", Lean = "Good" } } }
listeners.PetList(payload)
open()
local t = texts()
check(has(t, "Good Buddy"), "the story name", table.concat(t, ","))
local speed3 = math.floor(Config.PetSpeedBonus("BabySlime", 3) * 100 + 0.5)
check(has(t, "Lv 3 · Walk speed +" .. speed3 .. "%"), "Lv and the walk speed it gives", table.concat(t, ","))
check(#bars == 1 and bars[1].Text == "12/" .. need3 .. " XP" and math.abs(bars[1].Fill - 12 / need3) < 1e-9,
	"the XP bar (XP / Need)", bars[1] and bars[1].Text)
check(has(t, "Following you"), "the follower says so")
check(btn("Put away") ~= nil and btn("Follow me") == nil, "the follower has [Put away]")
local icon = nil
for _, o in made do if o.ClassName == "ImageLabel" then icon = o end end
check(icon ~= nil and icon.Image == "IconPetBabySlime", "the approved pet icon (no new art)", icon and icon.Image)

-- 3. put it away: EquipPet("") once per Gap
table.clear(sent)
btn("Put away").OnClick()
btn("Put away").OnClick()
check(#sent == 1 and sent[1][1] == "", "[Put away] fires EquipPet(\"\") once (one press per Gap)", #sent)
NOW += 1
btn("Put away").OnClick()
check(#sent == 2, "... again after Gap", #sent)

-- 4. put away -> the server's list: no follower, [Follow me]
listeners.PetList({ Equipped = "", List = payload.List })
open()
check(btn("Follow me") ~= nil and btn("Put away") == nil and not has(texts(), "Following you"),
	"a resting pet has [Follow me]", #buttons)
table.clear(sent)
NOW += 1
btn("Follow me").OnClick()
check(#sent == 1 and sent[1][1] == "P1", "[Follow me] fires EquipPet(uid)", sent[1] and sent[1][1])

-- 5. tamer: never [Put away] (M1); CanPutAway = false from the server hides it too
attrs.Class, attrs.Faction = Config.Tamer.Class, Config.Tamer.Faction
listeners.PetList(payload)
open()
check(btn("Put away") == nil and has(texts(), "Following you"), "the tamer's pet (its weapon) has no [Put away]", #buttons)
attrs.Class, attrs.Faction = "Warrior", "Halo"
listeners.PetList({ Equipped = "P1", List = payload.List, CanPutAway = false })
open()
check(btn("Put away") == nil, "the server's CanPutAway = false hides it", #buttons)

-- 6. MAX, no story name, two pets (the follower first), an unknown species cannot follow
local maxLv = Config.Pets.MaxLv
listeners.PetList({ Equipped = "P2", List = {
	{ Uid = "P1", Sp = "BabySlime", Lv = maxLv, XP = 0, Need = 0, Name = "", Lean = "" },
	{ Uid = "P2", Sp = "BabySlime", Lv = 1, XP = 0, Need = 15, Name = "Little Minion", Lean = "Evil" },
	{ Uid = "P3", Sp = "Dragon", Lv = 1, XP = 0, Need = 15, Name = "", Lean = "" },
} })
local rows = PetWindow.Rows({ Equipped = "P2", List = {
	{ Uid = "P1", Sp = "BabySlime", Lv = maxLv, XP = 0, Need = 0, Name = "", Lean = "" },
	{ Uid = "P2", Sp = "BabySlime", Lv = 1, XP = 0, Need = 15, Name = "Little Minion", Lean = "Evil" },
	{ Uid = "P3", Sp = "Dragon", Lv = 1, XP = 0, Need = 15, Name = "", Lean = "" },
} }, { Class = "Warrior", Faction = "Halo" })
check(rows[1].Uid == "P2" and rows[2].Uid == "P1" and rows[3].Uid == "P3", "the follower first, then by uid",
	rows[1].Uid .. rows[2].Uid .. rows[3].Uid)
check(rows[2].Name == "Baby Slime" and rows[2].Max and rows[2].Fill == 1, "no story name: the species name; Lv max = MAX",
	rows[2].Name)
check(rows[3].CanFollow == false, "an unknown species cannot follow", rows[3].CanFollow)
open()
local maxBar = false
for _, b in bars do if b.Text == "MAX" then maxBar = true end end
check(maxBar, "the MAX bar")

-- 7. no PetList yet: the follower from the attributes, no XP, no buttons
local rowsA = PetWindow.Rows(nil, { Class = "Warrior", Faction = "Halo", EquippedPet = "BabySlime", PetLv = 2 })
check(#rowsA == 1 and rowsA[1].Lv == 2 and rowsA[1].XP == nil and not rowsA[1].CanPutAway and not rowsA[1].CanFollow,
	"before the first PetList: the follower from EquippedPet / PetLv", #rowsA)
check(#PetWindow.Rows(nil, { EquippedPet = "" }) == 0, "... nothing when none follows")

-- 8. redraws: only while open, only when what it shows changed
listeners.PetList(payload)
open()
rebuilt = 0
listeners.PetList(payload)
check(rebuilt == 0, "the same list again: no redraw", rebuilt)
listeners.PetList({ Equipped = "P1", List = { { Uid = "P1", Sp = "BabySlime", Lv = 3, XP = 13, Need = need3, Name = "Good Buddy" } } })
check(rebuilt == 1, "a kill's pet XP: one redraw", rebuilt)
current = nil
listeners.PetList({ Equipped = "P1", List = { { Uid = "P1", Sp = "BabySlime", Lv = 3, XP = 14, Need = need3, Name = "Good Buddy" } } })
check(rebuilt == 1, "closed: no redraw", rebuilt)
check(PetWindow.OnList("junk") == false and PetWindow.OnList({}) == false, "a bad payload is ignored")

print(("PET_WINDOW_SUMMARY checks=%d failed=%d"):format(checks, failed))
