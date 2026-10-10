-- SKL-1 (A23-49, docs/design/skill_kit_beta_2026-10-06.md sections 1 / 4 / 5 / 6-3 / 8-1): the real Config.luau with
-- engine doubles; checks Config.Skills (flags, unlocks, 21 skills with the section 4 numbers and section 5 English (A23-116: the 18 class skills by side)),
-- Config.SkillKit / SkillDef / SkillNumbers (A23-60 "Costs N MP") and the SkillX key. Input: CONFIG_SOURCE.
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
local S = Config.Skills

-- section 1 / 2: flags off, Q/Z/X, unlock levels, spacing, MP steal cap
check(type(S) == "table" and S.ZEnabled == false and S.XEnabled == false and S.PvPZX == false,
	"flags off until the 10/20 decision: ZEnabled / XEnabled / PvPZX = false", S and { S.ZEnabled, S.XEnabled, S.PvPZX })
check(S.MoveSkills == true and S.Fields == true and S.Taunt == true, "the section 10 fall-back switches start on")
check(table.concat(S.Order or {}, ",") == "Q,Z,X" and S.Unlock and S.Unlock.Q == 5 and S.Unlock.Z == 15 and S.Unlock.X == 25,
	"Q / Z / X unlock at Lv5 / Lv15 / Lv25 (A23-71, user 2026-10-07; SKL-1 had Lv1 / Lv5 / Lv8)")
check(S.GlobalGap == 0.5 and S.MPStealCap == 20, "0.5 s between skills, MP steal capped at 20 a cast")

-- section 4 numbers (the build-fast tables) per kit and slot: { MP, CD, Mult, Shape }
local WANT = {
	Warrior = { Q = { 20, 3, 6, "SelfCircle" }, Z = { 25, 6, 7.5, "Line" }, X = { 30, 15, 2, "Roar" } },
	Mage = { Q = { 20, 3, 6, "TargetCircle" }, Z = { 25, 5, 5, "Chain" }, X = { 30, 14, nil, "Field" } },
	Archer = { Q = { 20, 3, 6, "TargetCircle" }, Z = { 25, 5, 9, "Line" }, X = { 25, 10, 3, "Hop" } },
	Blacksmith = { Q = { 20, 3, 6, "SelfCircle" }, Z = { 25, 6, 7.5, "Line" }, X = { 30, 15, 2, "Roar" } },
	Alchemist = { Q = { 20, 3, 6, "TargetCircle" }, Z = { 25, 5, 5, "Chain" }, X = { 30, 14, nil, "Field" } },
	Tamer = { Q = { 20, 3, 6, "TargetCircle" }, Z = { 25, 5, 9, "Line" }, X = { 25, 10, 3, "Hop" } },
}
local NAMES = {
	Warrior = { Q = { Halo = "Halo Slam", Horns = "Crater Smash" }, Z = { Halo = "Glow Lasso", Horns = "Fire Rake" },
		X = { Halo = "Guardian Roar", Horns = "Rage Roar" } },
	Mage = { Q = { Halo = "Star Fall", Horns = "Purple Pop" }, Z = { Halo = "Birdie Bounce", Horns = "Flappy Zigzag" },
		X = { Halo = "Sun Circle", Horns = "Hex Circle" } },
	Archer = { Q = { Halo = "Feather Rain", Horns = "Spark Shower" }, Z = { Halo = "Comet Arrow", Horns = "Moon Shot" },
		X = { Halo = "Light Step", Horns = "Shadow Step" } },
	Blacksmith = { Q = "Hammer Quake", Z = "Hook Chain", X = "Anvil Guard" },
	Alchemist = { Q = "Potion Bomb", Z = "Bubble Hop", X = "Jelly Brew" },
	Tamer = { Q = "Pet Rush", Z = "Slime Roll", X = "Big Boing" },
}
local count, kits = 0, 0
for kit, slots in WANT do
	kits += 1
	local defs = S.Defs and S.Defs[kit]
	check(type(defs) == "table", kit .. ": a kit table", kit)
	for slot, w in slots do
		local d = defs and defs[slot]
		check(type(d) == "table" and d.MP == w[1] and d.CD == w[2] and (w[3] == nil or d.Mult == w[3]) and d.Shape == w[4],
			kit .. " " .. slot .. ": MP / CD / Mult / Shape = section 4", d and { d.MP, d.CD, d.Mult, d.Shape })
		local names = NAMES[kit][slot]
		if type(names) == "table" then
			for side, name in names do
				count += 1
				local v = d and d[side]
				check(type(v) == "table" and v.NameEn == name and type(v.DescEn) == "string" and #v.DescEn > 0 and #name <= 14,
					kit .. " " .. slot .. " " .. side .. ": " .. name .. " (<= 14 letters, a description)", v and v.NameEn)
			end
		else
			count += 1
			check(d and d.NameEn == names and type(d.DescEn) == "string" and #d.DescEn > 0 and #names <= 14,
				kit .. " " .. slot .. ": " .. names .. " (<= 14 letters, a description)", d and d.NameEn)
		end
	end
end
check(kits == 6 and count == 27, "6 kits, 27 names (the class kits' Q / Z / X x 2 sides = 18, the artisan guild's 9)", { kits, count })
-- the shapes' own numbers
local D = S.Defs
check(D.Warrior.Q.Radius == 9 and D.Mage.Q.Range == 35 and D.Archer.Q.Range == 30 and D.Mage.Q.Radius == 9,
	"Q: radius 9; Mage aims 35, Archer 30 (BasicSkill numbers kept)")
check(D.Warrior.Z.Len == 22 and D.Warrior.Z.Width == 10 and D.Warrior.Z.Pull == 5 and D.Archer.Z.Len == 40 and D.Archer.Z.Width == 4
	and D.Archer.Z.Push == 3 and D.Mage.Z.Jump == 10 and D.Mage.Z.Hits == 4, "Z shapes: band 22x10 pull 5, line 40x4 push 3, chain 10 studs 4 hits")
check(D.Warrior.X.TauntRadius == 16 and D.Warrior.X.TauntSec == 4 and D.Warrior.X.SelfGuard == 0.4 and D.Warrior.X.Halo.AllyGuard == 0.2
	and D.Warrior.X.Horns.MPSteal == 5, "Roar: taunt 16 / 4 s, self guard 40%; Halo allies 20%, Horns +5 MP a monster")
check(D.Mage.X.Radius == 12 and D.Mage.X.Duration == 5 and D.Mage.X.TickMult == 1.5 and D.Mage.X.Slow == 0.5
	and D.Mage.X.Horns.MPStealTick == 2, "Field: r12, 5 s, x1.5 a second, slow 50%; Hex +2 MP a monster a tick")
check(D.Archer.X.Hop == 10 and D.Archer.X.Radius == 7 and D.Archer.X.Push == 6 and D.Archer.X.Auto.Never == true
	and D.Tamer.X.Auto.Never == true, "Hop: 10 back, wind r7 x3 push 6; auto combat never uses a Hop")
check(D.Blacksmith.X.Craft == "Anvil" and D.Alchemist.X.Craft == "Cauldron" and D.Tamer.X.Craft == "BigSlime"
	and D.Blacksmith.X.Halo == nil and D.Alchemist.X.Horns == nil, "artisan X: crafted looks only, no faction extras (A6)")
check(D.Warrior.Z.Auto.NoPull == true and D.Blacksmith.Z.Auto.NoPull == true, "an auto Z never pulls (section 1-5)")

-- SkillKit / SkillDef
check(Config.SkillKit("Warrior", "Halo") == "Warrior" and Config.SkillKit("Mage", "Horns") == "Mage"
	and Config.SkillKit("Warrior", "Neutral") == "Blacksmith" and Config.SkillKit("Mage", "Neutral") == "Alchemist"
	and Config.SkillKit("Archer", "Neutral") == "Tamer" and Config.SkillKit("Archer", "Halo") == "Archer"
	and Config.SkillKit("Nope", "None") == "Warrior", "SkillKit: the artisan guild's kits, else the class (unknown -> Warrior)")
local gx, hx = Config.SkillDef("Warrior", "Halo", "X"), Config.SkillDef("Warrior", "Horns", "X")
check(gx and gx.NameEn == "Guardian Roar" and gx.AllyGuard == 0.2 and gx.MP == 30 and gx.Halo == nil and gx.Kit == "Warrior" and gx.Slot == "X",
	"SkillDef Halo X: the faction table merged over the base (no nested Halo / Horns)", gx and gx.NameEn)
check(hx and hx.NameEn == "Rage Roar" and hx.MPSteal == 5 and hx.AllyGuard == nil, "SkillDef Horns X: its own extras only", hx and hx.NameEn)
local nx = Config.SkillDef("Warrior", "None", "X")
check(nx and nx.NameEn == "Guardian Roar", "a split X seen with no side yet shows the Halo name", nx and nx.NameEn)
check(Config.SkillDef("Archer", "Neutral", "Q").NameEn == "Pet Rush" and Config.SkillDef("Archer", "Neutral", "Q").Style == "PetDash",
	"the tamer's Q is Pet Rush (the PetDash release style)")
check(Config.SkillDef("Warrior", "Halo", "W") == nil, "an unknown slot -> nil")

-- A23-116 (docs/design/skills18_2026-10-10.md "한눈에 표" / "이름 규칙"): the 18 class skills, one name and one line per side
do
	local CLASSES, SIDES, SLOTS = { "Warrior", "Mage", "Archer" }, { "Halo", "Horns" }, { "Q", "Z", "X" }
	local OLD_NAMES = { "Shockwave", "Earth Cleave", "Meteor", "Chain Bolt", "Arrow Rain", "Pierce Shot" }
	-- words that may also sit in a shop / monster name: the faction words and the common 'Star' (attendance looks, not for sale)
	local TOLERATED = { star = true, halo = true, horns = true }
	local NUMBER_KEYS = { "Shape", "Mult", "MP", "CD", "Push", "Pull", "Radius", "Range", "Len", "Width", "AimCone", "Jump", "Hits",
		"Hop", "HopTime", "Duration", "Tick", "TickMult", "Slow", "TauntRadius", "TauntSec", "SelfGuard" }
	local function plain(v)
		if type(v) ~= "table" then return tostring(v) end
		local keys = {}
		for k in v do keys[#keys + 1] = tostring(k) end
		table.sort(keys)
		local out = {}
		for _, k in keys do out[#out + 1] = k .. "=" .. plain(v[k]) end
		return "{" .. table.concat(out, ",") .. "}"
	end
	local owners, seen, dupName, bare, sameNumbers, sideOnly, descOk, descBad = {}, {}, nil, true, true, true, true, {}
	local noSide, oldGone, count18 = true, true, 0
	for _, class in CLASSES do
		for _, slot in SLOTS do
			local base = D[class][slot]
			if base.NameEn ~= nil or base.DescEn ~= nil then bare = false end
			local halo, horns = Config.SkillDef(class, "Halo", slot), Config.SkillDef(class, "Horns", slot)
			for _, key in NUMBER_KEYS do
				if plain(halo[key]) ~= plain(horns[key]) then sameNumbers = false end
			end
			if plain(halo.Auto) ~= plain(horns.Auto) then sameNumbers = false end
			if slot ~= "X" then
				for _, side in SIDES do
					for k in base[side] do
						if k ~= "NameEn" and k ~= "DescEn" then sideOnly = false end
					end
				end
			end
			for _, side in SIDES do
				local def = side == "Halo" and halo or horns
				count18 += 1
				local name = def.NameEn
				if type(name) ~= "string" or #name == 0 or #name > 13 then descOk = false end
				if seen[tostring(name)] then dupName = name end
				seen[tostring(name)] = true
				for _, old in OLD_NAMES do
					if name == old then oldGone = false end
				end
				for word in tostring(name):gmatch("%a+") do
					word = word:lower()
					local list = owners[word] or {}
					owners[word] = list
					list[#list + 1] = { Kit = class, Slot = slot, Side = side }
				end
				local d = tostring(def.DescEn)
				local low = d:lower()
				local fits
				if slot == "X" and side == "Halo" then
					fits = low:find("guarded", 1, true) or low:find("less damage", 1, true)
				elseif slot == "X" then
					fits = low:find("steal mp", 1, true)
				elseif side == "Halo" then
					fits = low:find("heal", 1, true)
				else
					fits = low:find("steal hp", 1, true)
				end
				if type(def.DescEn) ~= "string" or #d == 0 or #d > 100 or not fits then
					descOk = false
					descBad[#descBad + 1] = class .. slot .. side
				end
			end
			local none, nilSide = Config.SkillDef(class, "None", slot), Config.SkillDef(class, nil, slot)
			if none.NameEn ~= halo.NameEn or none.DescEn ~= halo.DescEn or nilSide.NameEn ~= halo.NameEn then noSide = false end
		end
	end
	check(count18 == 18, "18 class skills (3 classes x 3 slots x 2 sides)", count18)
	check(dupName == nil, "the 18 names are all different", dupName)
	check(bare, "no base NameEn / DescEn left on a class skill: the words live in the Halo / Horns tables")
	check(sideOnly, "a Q / Z Halo / Horns table holds only NameEn + DescEn (the numbers are the slot's, the same for both sides)")
	check(sameNumbers, "the same slot: Halo and Horns share Shape / Mult / MP / CD / Push / Pull / sizes / Auto")
	check(descOk, "18 names <= 13 letters and a line <= 100 letters that fits the side (heal / steal HP / guard / steal MP)", descBad)
	check(noSide, "no side yet (None / nil): the Halo words for every class skill")
	check(oldGone, "the old names (Shockwave, Earth Cleave, Meteor, Chain Bolt, Arrow Rain, Pierce Shot) are gone")
	-- a word may sit in two class names only as the X pair of one class (Roar / Circle / Step)
	local wordBad
	for word, list in owners do
		if #list > 1 then
			local ok = #list == 2 and list[1].Slot == "X" and list[2].Slot == "X" and list[1].Kit == list[2].Kit
				and list[1].Side ~= list[2].Side
			if not ok then wordBad = word end
		end
	end
	check(wordBad == nil, "no word is shared between the 18 names except an X pair's (Roar, Circle, Step)", wordBad)
	-- no word shared with the artisan guild's 9 names
	local artisan, artisanBad = {}, nil
	for _, kit in { "Blacksmith", "Alchemist", "Tamer" } do
		for _, slot in SLOTS do
			for word in D[kit][slot].NameEn:gmatch("%a+") do artisan[word:lower()] = true end
		end
	end
	for word in owners do
		if artisan[word] then artisanBad = word end
	end
	check(artisanBad == nil, "no word shared with the artisan guild's names (Hammer Quake, Hook Chain, ...)", artisanBad)
	-- no word shared with a monster, a pass or a look (so a skill never reads like a shop item or a creature)
	local other = {}
	local function addWords(s)
		if type(s) == "string" then
			for word in s:gmatch("%a+") do other[word:lower()] = true end
		end
	end
	for _, m in Config.MonsterTypes do addWords(m.Name) addWords(m.Short) end
	for _, p in Config.GamePasses do addWords(p.Name) end
	for _, l in Config.Looks do addWords(l.Name) end
	local otherBad
	-- the nine X names are the old ones (Roar / Circle / Step pairs, A23-49; 'Shadow Step' already sat beside the 99 R$ look
	-- 'Shadow Horns', reported to the reviewer 2026-10-10): the new Q / Z names are the ones that must stay clear
	for word, list in owners do
		for _, o in list do
			if o.Slot ~= "X" and other[word] and not TOLERATED[word] then otherBad = word end
		end
	end
	check(next(other) ~= nil and otherBad == nil, "no Q / Z word shared with a monster, a game pass or a look name (Bat, Lava, Gold ... avoided)", otherBad)
	-- the artisan guild still reads its own names whatever the class
	check(Config.SkillDef("Warrior", "Neutral", "Q").NameEn == "Hammer Quake" and Config.SkillDef("Mage", "Neutral", "Z").NameEn == "Bubble Hop"
		and Config.SkillDef("Archer", "Neutral", "X").NameEn == "Big Boing" and Config.SkillDef("Warrior", "Neutral", "X").NameEn == "Anvil Guard",
		"the artisan guild keeps its own names")
end
check(Config.SkillDef("Mage", "Halo", "Z") == Config.SkillDef("Mage", "Halo", "Z"), "SkillDef answers from a cache (same table)")

-- A23-60: MP shows in the info line, not on the buttons
local line = Config.SkillNumbers(Config.SkillDef("Warrior", "Halo", "Z"))
check(line == "Costs 25 MP · 6 s cooldown · Line 22", "SkillNumbers: 'Costs 25 MP · 6 s cooldown · Line 22'", line)
check(Config.SkillNumbers(Config.SkillDef("Mage", "Horns", "Q")) == "Costs 20 MP · 3 s cooldown · Area 9",
	"SkillNumbers Q: 'Costs 20 MP · 3 s cooldown · Area 9'", Config.SkillNumbers(Config.SkillDef("Mage", "Horns", "Q")))
check(Config.SkillNumbers(Config.SkillDef("Mage", "Halo", "Z")):find("Jumps 3", 1, true) ~= nil
	and Config.SkillNumbers(Config.SkillDef("Archer", "Horns", "X")):find("Hop 10", 1, true) ~= nil
	and Config.SkillNumbers(Config.SkillDef("Mage", "Neutral", "X")):find("Field 5 s", 1, true) ~= nil,
	"SkillNumbers: chain jumps, hop studs, field seconds")
local T = S.Text
check(T and T.NoMP == "Not enough MP" and T.NoTarget == "No target" and T.TooHeavy == "Too heavy to jump!" and T.CantHop == "Can't hop here"
	and T.UnlocksAt == "Unlocks at Lv%d" and T.Cost == "Costs %d MP" and T.NewSkill == "New skill! %s (%s)"
	and T.XHalo == "Halo: guards friends" and T.XHorns == "Horns: steals MP" and T.XArtisan == "Artisan: crafted look"
	and T.QZHalo == "Halo: your hits heal friends" and T.QZHorns == "Horns: your hits steal HP",
	"section 5 short words (English, A23-48)")
for k, v in T or {} do
	check(type(v) == "string" and not v:find("[\234-\237][\128-\191][\128-\191]"), "no Korean in Config.Skills.Text", k)
end

-- section 6-3: the SkillX key (C since the user's 10/08 MMO keys - Q is the quest list, the skills are Z / X / C -,
-- pad R3, flag XEnabled), after SkillZ
local KB = Config.Keybinds
local iz, ix = nil, nil
for i, a in KB.Actions do
	if a.Id == "SkillZ" then iz = i end
	if a.Id == "SkillX" then ix = i end
end
local ax = ix and KB.Actions[ix]
check(ax and ix == iz + 1 and ax.Key == "C" and ax.Pad == "ButtonR3" and ax.Flag == "Skills.XEnabled" and ax.Group == "Combat"
	and ax.LabelEn == "Skill 3" and ax.ButtonEn == "Skill 3 button", "SkillX: C / ButtonR3, Flag Skills.XEnabled, right after SkillZ",
	ax and { ax.Key, ax.Pad, ax.Flag })
local reserved = {}
for _, n in KB.Reserved do reserved[n] = true end
check(not reserved.C and not reserved.ButtonR3, "C is not a reserved key")
print("SKILL_KIT_SUMMARY checks=" .. checks .. " failed=" .. failed)
