-- 게임성 개발 4 gear slots (2026-10-12): runs the real Config.luau and the real GearSlots.luau (tools/test_gear_slots_ui.py) on small
-- doubles: Players.LocalPlayer attributes + change signals, a recording Instance tree, UIKit art doubles (ItemIcon / ArtImage return
-- nil for one id to test the letter fallback), the CharacterUI / BagUI / PetWindow registry. Inputs: CONFIG_SOURCE, GEAR_SOURCE.
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
local cf = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cf, cfgEnv)
local Config = cf()

------------------------------------------------------------------ an Instance tree double
local omt = {}
local function newObj(class, props)
	local o = setmetatable({ __p = { ClassName = class, Name = class, Children = {}, ZIndex = 1 } }, omt)
	for k, v in props or {} do o[k] = v end
	return o
end
omt.__index = function(o, k)
	local p = rawget(o, "__p")
	if k == "GetChildren" then return function(self) return table.clone(rawget(self, "__p").Children) end end
	if k == "Destroy" then
		return function(self)
			local q = rawget(self, "__p")
			if q.Parent then
				local kids = rawget(q.Parent, "__p").Children
				local i = table.find(kids, self)
				if i then table.remove(kids, i) end
			end
			q.Parent, q.Destroyed = nil, true
		end
	end
	return p[k]
end
omt.__newindex = function(o, k, v)
	local p = rawget(o, "__p")
	if k == "Parent" then
		if p.Parent then
			local kids = rawget(p.Parent, "__p").Children
			local i = table.find(kids, o)
			if i then table.remove(kids, i) end
		end
		p.Parent = v
		if v then table.insert(rawget(v, "__p").Children, o) end
		return
	end
	p[k] = v
end
local function descendants(root, out)
	out = out or {}
	for _, ch in rawget(root, "__p").Children do
		table.insert(out, ch)
		descendants(ch, out)
	end
	return out
end
local function find(root, name)
	for _, d in descendants(root) do if d.Name == name then return d end end
	return nil
end
local function count(root, pat)
	local n = 0
	for _, d in descendants(root) do if type(d.Name) == "string" and string.find(d.Name, pat) then n += 1 end end
	return n
end

------------------------------------------------------------------ doubles
local attrs = { Class = "Warrior", Faction = "Halo", WeaponTier = 0, WeaponEnhance = 0, EquippedPet = "", PetLv = 1 }
local sigs, connects = {}, {} -- [attribute] = the module's change handler / how many times it was connected
local player = { GetAttribute = function(_, k) return attrs[k] end,
	GetAttributeChangedSignal = function(_, k)
		return { Connect = function(_, f) sigs[k] = f connects[k] = (connects[k] or 0) + 1 end }
	end }
local Util = { Warn = function(...) print("WARN", ...) end }
local L10nReg = {}
local L10n = { Register = function(path, t) L10nReg[path] = t return t end }
local shared = { WaitForChild = function(_, n) return n end }
local RS = { WaitForChild = function() return shared end }
local game = { GetService = function(_, n)
	if n == "Players" then return { LocalPlayer = player } end
	if n == "ReplicatedStorage" then return RS end
	return nil
end }
local mods = { Config = Config, Util = Util, L10n = L10n }
local env = setmetatable(table.clone(base), { __index = getfenv() })
env.game, env.Instance, env.require = game, { new = function(c) return newObj(c) end }, function(n) return mods[n] end
env.UDim2 = {
	fromOffset = function(x, y) return { X = { Scale = 0, Offset = x }, Y = { Scale = 0, Offset = y } } end,
	fromScale = function(x, y) return { X = { Scale = x, Offset = 0 }, Y = { Scale = y, Offset = 0 } } end,
	new = function(xs, xo, ys, yo) return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } } end,
}
env.UDim = { new = function(s, o) return { Scale = s, Offset = o } end }
env.typeof = function(v) if type(v) == "table" and v.__p then return "Instance" end return typeof(v) end
local gf = assert(loadstring(GEAR_SOURCE, "=GearSlots"))
setfenv(gf, env)
local GearSlots = gf()

local missingItem, missingArt = "Weapon_Warrior_T2", nil -- ids whose picture is not drawn yet
local function artObj(class, name, props)
	local o = newObj(class, { Image = name })
	for k, v in props or {} do
		if k ~= "Parent" then o[k] = v end
	end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end
local UIKit = {
	Font = "Font.Gotham", Theme = { Gold = "gold", Text = "text", SubText = "sub" },
	ArtImage = function(name, props) if name == missingArt then return nil end return artObj("ImageLabel", name, props) end,
	ArtFrame = function(name, props) return artObj("Frame", name, props) end,
	ArtButton = function(name, props, onClick)
		local b = artObj("ImageButton", name, props)
		b.OnClick = onClick
		return b
	end,
	ItemIcon = function(id, props) if id == missingItem then return nil end return artObj("ImageLabel", "Icon:" .. tostring(id), props) end,
	StyleText = function(l, style) l.Style = style end,
	Tx = function(t, key, ...)
		local s = t[key .. "En"] or t[key]
		if type(s) ~= "string" then return "" end
		if select("#", ...) > 0 then return string.format(s, ...) end
		return s
	end,
}
local calls = {} -- what a press reached
local registry = {
	UIKit = UIKit,
	CharacterUI = { ShowView = function(v) table.insert(calls, "ShowView:" .. tostring(v)) end },
	BagUI = { Open = function(t) table.insert(calls, "Bag:" .. tostring(t)) end },
	PetWindow = { Open = function() table.insert(calls, "Pet") end },
}
GearSlots.Init(registry)
local T = GearSlots._T
local IDS = "Weapon,Armor,Ring,Pet,PetArmor,PetAcc"
local function ids(cells)
	local out = {}
	for _, c in cells do table.insert(out, c.Id) end
	return table.concat(out, ",")
end
local function pos(o) return o.Position.X.Offset, o.Position.Y.Offset end
local function cap(frame, id) return find(frame, "Cap_" .. id) end
local function cell(frame, id) return find(frame, "Cell_" .. id) end

------------------------------------------------------------------ 0. Cells (pure)
check(L10nReg["GearSlots.TXT"] == T.TXT, "the words are a registered L10n table (GearSlots.TXT, A23-111)")
local cells = GearSlots.Cells({ Tier = 4, Plus = 5, Class = "Warrior", Faction = "Halo" })
check(#cells == 6 and ids(cells) == IDS, "six cells in the order Weapon, Armor, Ring, Pet, Pet Armor, Pet Acc", ids(cells))
local w = cells[1]
check(w.Kind == "Weapon" and w.Empty == false and w.Icon == Config.WeaponArtKey(4, "Warrior", "Halo") and w.Icon == "Weapon_Warrior_T4",
	"Weapon: the art key of tier / class / faction", w.Icon)
check(w.Grade == Config.WeaponInfo[4].Grade and w.Grade == "Rare" and w.Plus == 5, "Weapon: the tier's grade (Rare) and +5", tostring(w.Grade) .. tostring(w.Plus))
check(w.Name == Config.WeaponName(4, "Warrior", "Halo"), "Weapon: the weapon's name (for the letter)")
check(GearSlots.Cells({ Tier = 4, Plus = 99 })[1].Plus == Config.Loot.MaxEnhance and GearSlots.Cells({ Tier = 4, Plus = -3 })[1].Plus == 0,
	"Weapon: +N is cut to 0 .. MaxEnhance")
for _, ctx in { { Tier = 0 }, {}, { Tier = 99 }, { Tier = -1 }, { Tier = 0 / 0 } } do
	local e = GearSlots.Cells(ctx)[1]
	check(e.Empty == true and e.Icon == nil and e.Grade == nil and e.Plus == nil, "Weapon: no weapon (tier " .. tostring(ctx.Tier) .. ") = empty")
end
local p = GearSlots.Cells({ Pet = "BabySlime", PetLv = 3 })[4]
check(p.Kind == "Pet" and p.Empty == false and p.Icon == Config.Pets.Species.BabySlime.Icon and p.Art == true and p.Grade == "Common" and p.Lv == 3,
	"Pet: the species icon (an art part), the common slot, Lv 3")
check(GearSlots.Cells({ Pet = "BabySlime", PetLv = 99 })[4].Lv == Config.Pets.MaxLv and GearSlots.Cells({ Pet = "BabySlime" })[4].Lv == 1,
	"Pet: Lv is cut to 1 .. MaxLv")
check(GearSlots.Cells({ Pet = "" })[4].Empty and GearSlots.Cells({})[4].Empty and GearSlots.Cells({ Pet = "NoSuchPet" })[4].Empty
	and GearSlots.Cells({ Pet = 5 })[4].Empty, "Pet: none / unknown species = empty")
local four = true
for _, i in { 2, 3, 5, 6 } do
	local c = cells[i]
	four = four and c.Empty == true and c.Kind == "Gear" and c.Icon == nil
end
check(four, "Armor, Ring, Pet Armor, Pet Acc: four empty cells without gear data")
local g = GearSlots.Cells({ Gear = { Ring = { Icon = "RingX", Grade = "Rare", Plus = 2, Name = "Ruby" } } })
check(g[3].Empty == false and g[3].Icon == "RingX" and g[3].Grade == "Rare" and g[3].Plus == 2 and g[2].Empty and g[5].Empty and g[6].Empty,
	"Gear data drops into its own cell only")
local w2, h2 = GearSlots.FrameSize()
check(w2 == 220 and h2 == 266, "the frame box is 220 x 266 du (3 rows always)", tostring(w2) .. "x" .. tostring(h2))

------------------------------------------------------------------ 1. Build
GearSlots.Refresh() -- before Build: nothing, no error
local refreshed = 0
local frame = newObj("Frame", { Name = "EquipSlots", Size = env.UDim2.fromOffset(220, 266) })
GearSlots.Build(frame, { Refresh = function() refreshed += 1 end })
local want = { Weapon = { 0, 0 }, Armor = { 78, 0 }, Ring = { 156, 0 }, Pet = { 0, 92 }, PetArmor = { 0, 184 }, PetAcc = { 78, 184 } }
for id, xy in want do
	local c = cell(frame, id)
	local x, y = nil, nil
	if c then x, y = pos(c) end
	check(c ~= nil and x == xy[1] and y == xy[2] and c.Size.X.Offset == 64 and c.Size.Y.Offset == 64, "Build: Cell_" .. id .. " at " .. xy[1] .. "," .. xy[2], tostring(x) .. "," .. tostring(y))
end
check(count(frame, "^Cell_") == 6 and count(frame, "^Cap_") == 6, "Build: six cells and six captions")
local words = { Weapon = "Weapon", Armor = "Armor", Ring = "Ring", Pet = "Pet", PetArmor = "Pet Armor", PetAcc = "Pet Acc" }
for id, word in words do
	local c = cap(frame, id)
	local x, y = nil, nil
	if c then x, y = pos(c) end
	local cx, cy = pos(cell(frame, id))
	check(c ~= nil and c.Text == word and x == cx - 6 and y == cy + 66, "Build: the word \"" .. word .. "\" under " .. id, c and c.Text)
end
local c0 = cap(frame, "PetArmor")
local tcs = 0
for _, ch in c0.GetChildren(c0) do if ch.ClassName == "UITextSizeConstraint" and ch.MaxTextSize == 15 then tcs += 1 end end
check(c0.TextScaled == true and c0.Style == nil and tcs == 1 and c0.TextWrapped == false, "captions: Style false + TextScaled + UITextSizeConstraint max 15")
check(refreshed == 0 and frame.Size.X.Offset == 220 and frame.Size.Y.Offset == 266, "Build: the frame is already 220 x 266 -> opts.Refresh is not called")
check(cell(frame, "Weapon").Image == "SlotEmpty" and cell(frame, "Pet").Image == "SlotEmpty" and find(frame, "Icon") == nil,
	"no weapon, no pet: SlotEmpty cells without icon")
for _, id in { "Armor", "Ring", "PetArmor", "PetAcc" } do
	check(cell(frame, id).Image == "SlotEmpty" and cell(frame, id).OnClick == nil, id .. ": SlotEmpty, not pressable")
end
check(cell(frame, "Weapon").OnClick ~= nil and cell(frame, "Pet").OnClick ~= nil, "Weapon and Pet cells are pressable")
local other = newObj("Frame", { Size = env.UDim2.fromOffset(100, 100) })
GearSlots.Build(other, { Refresh = function() refreshed += 1 end })
check(other.Size.X.Offset == 220 and other.Size.Y.Offset == 266 and refreshed == 1, "another size -> the frame is set to 220 x 266 and opts.Refresh runs once", refreshed)
check(count(other, "^Cell_") == 6 and count(frame, "^Cell_") == 0, "a new frame takes the six cells over (none left behind)")
GearSlots.Build(frame, { Refresh = function() refreshed += 1 end }) -- back on the first frame
local all = true
for _, name in { "WeaponTier", "WeaponEnhance", "Class", "Faction", "EquippedPet", "PetLv" } do
	all = all and connects[name] == 1 and type(sigs[name]) == "function"
end
check(all, "the six attributes are watched, each connected once (Build ran three times)")

------------------------------------------------------------------ 2. drawing the worn weapon and pet
attrs.WeaponTier, attrs.WeaponEnhance = 4, 5
sigs.WeaponTier()
local wc = cell(frame, "Weapon")
check(wc.Image == "SlotRare" and find(wc, "Icon").Image == "Icon:Weapon_Warrior_T4", "WeaponTier change: the Rare slot with the weapon's icon", wc.Image)
check(find(wc, "Plus") ~= nil and find(wc, "Plus").Text == "+5", "the weapon's +5")
local pl = find(wc, "Plus")
check(pl.Position.X.Offset == 4 and pl.Position.Y.Offset == 1 and pl.TextColor3 == "gold", "+N sits top-left in gold")
attrs.WeaponEnhance = 0
sigs.WeaponEnhance()
check(find(cell(frame, "Weapon"), "Plus") == nil, "+0 shows no +N")
attrs.WeaponTier = 8
sigs.WeaponTier()
check(cell(frame, "Weapon").Image == "SlotLegendary", "tier 8: the Legendary slot", cell(frame, "Weapon").Image)
attrs.Faction = "Horns"
attrs.WeaponTier = 7
sigs.Faction()
check(find(cell(frame, "Weapon"), "Icon").Image == "Icon:Weapon_Warrior_T7_Horns", "Faction change redraws (the T7 icon is the faction's)",
	find(cell(frame, "Weapon"), "Icon").Image)
attrs.Class = "Mage"
sigs.Class()
check(find(cell(frame, "Weapon"), "Icon").Image == "Icon:Weapon_Mage_T7_Horns", "Class change redraws")
attrs.WeaponTier, attrs.Class, attrs.Faction = 2, "Warrior", "Halo"
sigs.WeaponTier()
local lw = find(cell(frame, "Weapon"), "Letter")
local wname = Config.WeaponName(2, "Warrior", "Halo")
check(find(cell(frame, "Weapon"), "Icon") == nil and lw ~= nil and lw.Text == string.upper(string.sub(wname, 1, 1)),
	"a weapon icon not drawn yet shows the first letter of its name", lw and lw.Text)
attrs.EquippedPet, attrs.PetLv = "BabySlime", 3
sigs.EquippedPet()
local pc = cell(frame, "Pet")
check(pc.Image == "SlotCommon" and find(pc, "Icon").Image == "IconPetBabySlime", "EquippedPet change: the pet's icon in SlotCommon", pc.Image)
local lv = find(pc, "Lv")
check(lv ~= nil and lv.Text == "Lv 3" and lv.AnchorPoint.X == 1 and lv.AnchorPoint.Y == 1 and lv.Position.X.Scale == 1 and lv.Position.Y.Scale == 1
	and find(pc, "Plus") == nil, "\"Lv 3\" bottom-right", lv and lv.Text)
attrs.PetLv = 4
sigs.PetLv()
check(find(cell(frame, "Pet"), "Lv").Text == "Lv 4", "PetLv change redraws")
missingArt = "IconPetBabySlime"
sigs.PetLv()
local lp = find(cell(frame, "Pet"), "Letter")
check(find(cell(frame, "Pet"), "Icon") == nil and lp ~= nil and lp.Text == "B", "a pet icon not drawn yet shows the letter of its name", lp and lp.Text)
missingArt = nil
attrs.EquippedPet = ""
sigs.EquippedPet()
check(cell(frame, "Pet").Image == "SlotEmpty" and find(cell(frame, "Pet"), "Lv") == nil, "the pet leaves: SlotEmpty again")
check(count(frame, "^Cell_") == 6 and count(frame, "^Cap_") == 6 and #frame.GetChildren(frame) == 12, "redraws leave exactly six cells and six captions",
	#frame.GetChildren(frame))

------------------------------------------------------------------ 3. Refresh
attrs.WeaponTier, attrs.EquippedPet = 5, "BabySlime" -- changed without a signal
check(cell(frame, "Weapon").Image ~= "SlotEpic", "(no signal, no redraw)")
GearSlots.Refresh()
check(cell(frame, "Weapon").Image == "SlotEpic" and cell(frame, "Pet").Image == "SlotCommon" and #frame.GetChildren(frame) == 12,
	"Refresh() redraws from the attributes without duplicates")

------------------------------------------------------------------ 4. pressing
cell(frame, "Weapon").OnClick()
check(calls[1] == "ShowView:Weapons" and #calls == 1, "Weapon -> CharacterUI.ShowView(\"Weapons\")", table.concat(calls, ","))
cell(frame, "Pet").OnClick()
check(calls[2] == "Pet" and #calls == 2, "Pet -> PetWindow.Open()", table.concat(calls, ","))
for _, id in { "Armor", "Ring", "PetArmor", "PetAcc" } do
	local c = cell(frame, id)
	if c.OnClick then c.OnClick() end
end
check(#calls == 2, "the four empty cells do nothing")
GearSlots.Init({ UIKit = UIKit, BagUI = registry.BagUI, PetWindow = registry.PetWindow })
cell(frame, "Weapon").OnClick()
check(calls[3] == "Bag:Gear", "Weapon without CharacterUI.ShowView -> BagUI.Open(\"Gear\")", calls[3])
GearSlots.Init({ UIKit = UIKit, CharacterUI = {}, BagUI = registry.BagUI })
cell(frame, "Weapon").OnClick()
check(calls[4] == "Bag:Gear", "a CharacterUI without ShowView -> the bag too", calls[4])
cell(frame, "Pet").OnClick()
check(#calls == 4, "Pet without a PetWindow: nothing (no error)")
GearSlots.Init({ UIKit = UIKit, CharacterUI = { ShowView = function() error("boom") end } })
local okPress = pcall(cell(frame, "Weapon").OnClick)
check(okPress, "a press that fails does not throw")
GearSlots.Init({})
check(pcall(cell(frame, "Weapon").OnClick), "an empty registry: a press does nothing, no error")

print(string.format("GEAR_SLOTS_SUMMARY checks=%d failed=%d", checks, failed))
