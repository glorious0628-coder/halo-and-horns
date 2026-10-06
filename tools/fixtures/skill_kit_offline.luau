-- SKL-1 (A23-49, docs/design/skill_kit_beta_2026-10-06.md sections 1 / 4 / 5 / 6-3 / 8-1): the real Config.luau with
-- engine doubles; checks Config.Skills (flags, unlocks, 21 skills with the section 4 numbers and section 5 English),
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
check(table.concat(S.Order or {}, ",") == "Q,Z,X" and S.Unlock and S.Unlock.Q == 1 and S.Unlock.Z == 5 and S.Unlock.X == 8,
	"Q / Z / X unlock at Lv1 / Lv5 / Lv8")
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
	Warrior = { Q = "Shockwave", Z = "Earth Cleave", X = { Halo = "Guardian Roar", Horns = "Rage Roar" } },
	Mage = { Q = "Meteor", Z = "Chain Bolt", X = { Halo = "Sun Circle", Horns = "Hex Circle" } },
	Archer = { Q = "Arrow Rain", Z = "Pierce Shot", X = { Halo = "Light Step", Horns = "Shadow Step" } },
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
check(kits == 6 and count == 21, "6 kits, 21 skills (Q 6, Z 6, X 9)", { kits, count })
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
	and T.XHalo == "Halo: guards friends" and T.XHorns == "Horns: steals MP" and T.XArtisan == "Artisan: crafted look",
	"section 5 short words (English, A23-48)")
for k, v in T or {} do
	check(type(v) == "string" and not v:find("[\234-\237][\128-\191][\128-\191]"), "no Korean in Config.Skills.Text", k)
end

-- section 6-3: the SkillX key (X, pad R3, flag XEnabled), after SkillZ
local KB = Config.Keybinds
local iz, ix = nil, nil
for i, a in KB.Actions do
	if a.Id == "SkillZ" then iz = i end
	if a.Id == "SkillX" then ix = i end
end
local ax = ix and KB.Actions[ix]
check(ax and ix == iz + 1 and ax.Key == "X" and ax.Pad == "ButtonR3" and ax.Flag == "Skills.XEnabled" and ax.Group == "Combat"
	and ax.LabelEn == "Skill 3" and ax.ButtonEn == "Skill 3 button", "SkillX: X / ButtonR3, Flag Skills.XEnabled, right after SkillZ",
	ax and { ax.Key, ax.Pad, ax.Flag })
local reserved = {}
for _, n in KB.Reserved do reserved[n] = true end
check(not reserved.X and not reserved.ButtonR3, "X is not a reserved key")
print("SKILL_KIT_SUMMARY checks=" .. checks .. " failed=" .. failed)
