-- CharacterUI.luau (게임성 개발 1, BB8 내 캐릭터 창; design docs/design/beta_basics_2026-10-05.md "BB8" with the newer
-- decisions A23-48 English only, A23-99 / A23-130 less hand-holding, A23-78 E key, A23-133 gear row): the Panels window
-- "Character" ("Hero": the HUD's Hero tile and the E key open it; until it is registered the tile stays locked).
--   [Gear]  left : my Roblox headshot (UIKit.HeadshotImage) + the big Power number (the CombatPower attribute)
--           right: a Frame "EquipSlots" with the six gear cells - row 1 Weapon · Armor · Ring, row 2 Pet, row 3 Pet Armor · Pet Acc -
--                  and the title list beside it.
--   GearSlots contract (게임성 개발 4; agreed after the first draft). WITH C.GearSlots (a table with a Build function, looked
--   up when the window is built, not at Init) game dev 4 draws ALL SIX cells inside the EquipSlots frame and CharacterUI draws
--   NO cell of its own (no Weapon cell, no Pet cell, no SlotEmpty placeholders): it only owns the frame (name "EquipSlots",
--   Position (0, 0), the 3 x 3 cell default Size) and
--     - calls C.GearSlots.Build(frame, { Refresh = fn }) once - the first build; the frame outlives the window, so the cells
--       keep their state (a failing Build = no GearSlots: the frame is cleared and the fallback below is drawn),
--     - calls C.GearSlots.Refresh() on every open (after the window is drawn).
--   opts.Refresh is for GearSlots to call when its cells change size (e.g. no pet -> one row less): GearSlots sets the frame's
--   Size (offset units = du, the bounding box of its cells) and then calls opts.Refresh(); CharacterUI reads frame.Size and
--   lays the window out around it again (the title list moves beside the frame). It never writes the Size of a GearSlots frame.
--   The Weapon cell of GearSlots may call CharacterUI.ShowView("Weapons") (the owned-weapons list with [Equip]) and back.
--   WITHOUT GearSlots CharacterUI draws the fallback itself: the Weapon cell (tier frame + "+N"; pressing it opens the owned
--   weapons with [Equip] - EquipWeapon: the bag's path, the same rate gap, fight and level guards, one request at a time), the
--   Pet cell (only while the player has pets; it opens the Pet window) and Armor / Ring / Pet Armor / Pet Acc as empty
--   SlotEmpty cells. The title row sends SetTitle.
--   [Stats] only values that exist as Config data or replicated attributes: level, max HP, MP, walk speed, one hit, crit,
--           class / side traits, the effects that are on now, rebirth bonus, honor / infamy and the points to the next rank.
-- The EquipSlots frame lives as long as this module: Panels destroys a window's children when it closes, so Cleanup takes the
-- frame out first and the next build puts the same frame back (the gear cells keep their state; Build is called once).
-- The window is a fixed-height body (Panels), so "lays out again" = the title list's place and the right column, not the height.
-- Display only: the server checks every request. Text: short English in TXT (L10n key "CharacterUI.TXT.*", A23-111). PC first.
-- Public API: CharacterUI.Init(C), CharacterUI.Start(), CharacterUI.IsReady(), CharacterUI.Open(tab?),
-- pure: CharacterUI.Weapons(ctx) -> rows, CharacterUI.EquipState(row, ctx) -> text, enabled, CharacterUI.Titles(ctx) -> list,
-- CharacterUI.StatRows(ctx) -> rows, CharacterUI.PetState(rows) -> { Equipped, Count } | nil, CharacterUI.NextRank(faction, points)
-- acts: CharacterUI.Equip(tier) -> bool, CharacterUI.SetTitle(id) -> bool, CharacterUI.Refresh(force?), CharacterUI.Relayout(),
-- CharacterUI.ShowTab("Gear" | "Stats"), CharacterUI.ShowView("Slots" | "Weapons")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local L10n = require(Shared:WaitForChild("L10n"))

local CharacterUI = {}
local C = nil
local TAG = "CharacterUI"
local LocalPlayer = Players.LocalPlayer

-- player text (A23-48 English, A23-130 short, no tips; A23-111: keys "CharacterUI.TXT.<field>")
local TXT = Config.ClientText.CharacterUI -- the words: Config.ClientText.CharacterUI (moved 10/14)
L10n.Register("CharacterUI.TXT", TXT)

-- layout (du = MainGui units) and fixed rules
local L = {
	Window = "Character", Width = 600, -- Panels FRAME.Pad 18 each side -> 564 du of content
	Tabs = { "Gear", "Stats" },
	TabH = 40, Gap = 8,
	LeftW = 150, Split = 14, -- the left column (headshot + power) and the space right of it
	LeftBar = 4, -- A23-145 phone photos 10/13: the left column scrolls on a short window; a thin bar (the chips fill its width)
	Portrait = 100,
	ChangeW = 96, ChangeH = 30, -- the nickname's [Change] (게임성 검수 10/12: moved here from Settings)
	ChipW = 70, ChipH = 30, ChipIcon = 20, -- the power's two parts (ref_rpg_ui #1)
	Cell = 64, ColGap = 14, CapH = 18, RowGap = 10, -- one gear cell, the word under it
	Cols = { Weapon = 0, Armor = 1, Ring = 2, Pet = 0, PetArmor = 0, PetAcc = 1 },
	Rows = { Weapon = 0, Armor = 0, Ring = 0, Pet = 1, PetArmor = 2, PetAcc = 2 },
	FrameW = 3 * 64 + 2 * 14, FrameH = 3 * (64 + 18) + 2 * 10, -- the EquipSlots default: 3 columns x 3 rows of Cell / ColGap / CapH / RowGap
	TitleGap = 16, TitleW = 150, TitleH = 36, -- the title list sits TitleGap right of the EquipSlots frame
	Fallback = { "Armor", "Ring", "PetArmor", "PetAcc" }, -- the empty cells drawn when there is no GearSlots
	RowH = 74, Icon = 52, ButtonW = 112, BtnH = 40,
	StatH = 26, StatLabelW = 200,
	StatBtnW = 110, StatBtnH = 32, StatPlusW = 44, StatNameW = 90, HuntBarH = 10, -- 최종 검수 10/15: the point panel / hunt bar
	CardW = 132, CardH = 50, CardIcon = 26, TraitW = 132, TraitH = 28, -- the Stats tab's cards and chips (ref_rpg_ui #5)
	RibbonH = 34, BarH = 18, BarIcon = 22, -- the title ribbon and the next rank bar (ref_rpg_ui #9)
	-- the locked titles (CharacterUI.LockedTitles): past / season ones left out, side ones only for that side, at most this many
	LockedSkip = { BetaPioneer = true, PartyGuest2026 = true, PumpkinPal = true, CandyKeeper = true },
	LockedSide = { GuardianCadet = "Halo", RascalCadet = "Horns" },
	LockedMax = 6,
	BodyGap = 12, BodyH = 220, -- the 3D body under the gear cells, as wide as them (ref_rpg_ui #3, C.HeroPreview)
	Size = { Name = 18, Body = 16, Small = 15, Count = 16, Power = 34, Head = 18 },
	-- the slot parts' icon box (Config.UIArt SlotCommon ... Inner = Rect(76, 80, 436, 436) of 512), same as the bag
	Inner = { X = 76 / 512, Y = 80 / 512, W = 360 / 512, H = 356 / 512 },
	Slot = { Common = "SlotCommon", Fine = "SlotUncommon", Rare = "SlotRare", Epic = "SlotEpic", Legend = "SlotLegendary",
		Mythic = "SlotLegendary" },
	GapMargin = 0.15, -- s over Config.RateLimits[remote] (the server drops a 2nd request inside it without a reply)
	PendingTimeout = 3, -- s without an answer -> the request stops waiting (quietly)
	ShowRebirthMin = 1, -- rebirth rows show from this many rebirths / marks / bonus
}
-- the attributes that redraw the open window
CharacterUI.Watch = { Level = true, Class = true, Faction = true, WeaponTier = true, WeaponOwnedMask = true, WeaponEnhance = true,
	CombatPower = true, Nickname = true, EquippedPet = true, PetLv = true, TitleSel = true, TitlesOwned = true, SizeMult = true, BullyStacks = true,
	WantedStars = true, RevengeUntil = true, Rebirths = true, RebirthBonus = true, FallMarks = true, RedeemMarks = true,
	Honor = true, Infamy = true, MaxMana = true, InCombatUntil = true, StatAtk = true, StatHp = true, DataLoaded = true,
	StatFree = true, AutoStat = true, HuntFame = true }

local S = {
	Ready = false,
	Tab = "Gear", View = "Slots", -- View: "Slots" (the gear cells + titles) | "Weapons" (the owned weapons list)
	Equip = nil, -- the EquipSlots frame (kept between builds)
	GearBuilt = false, -- C.GearSlots.Build ran on this frame
	GearOff = false, -- C.GearSlots.Build failed: the fallback cells are drawn instead
	Drawn = {}, -- the fallback cells / captions this module drew in the frame
	ReadyAt = {}, -- [remote] = os.clock() when the next send is allowed
	Pending = nil, -- { Tier, WeaponTier, SentAt, ReadyAt, Answered? }
	Why = nil, -- the power part whose sources show ("Attack" | "Health"; ref_rpg_ui #1)
}
local VIEW = {} -- the open window: Kit, Parent, Pages, Sigs ...

---------------------------------------------------------------------------------------------------- small helpers
local function num(v, d)
	v = tonumber(v)
	if v == nil or v ~= v or v == math.huge or v == -math.huge then return d end
	return v
end

local function attr(name, d)
	local v = LocalPlayer and LocalPlayer:GetAttribute(name)
	if v == nil then return d end
	return v
end

local function tx(t, key, ...)
	local ui = C and C.UIKit
	if type(ui) == "table" and type(ui.Tx) == "function" then
		local ok, s = pcall(ui.Tx, t, key, ...)
		if ok and type(s) == "string" then return s end
	end
	local s = t[key .. "En"] or t[key]
	if type(s) ~= "string" then return "" end
	if select("#", ...) > 0 then
		local ok, out = pcall(string.format, s, ...)
		return ok and out or s
	end
	return s
end

local function owns(mask, tier)
	return bit32.btest(math.max(0, math.floor(num(mask, 0))), bit32.lshift(1, tier - 1))
end

local function enhOf(enh, tier)
	local n = type(enh) == "table" and (enh[tier] or enh[tostring(tier)]) or nil
	return math.clamp(math.floor(num(n, 0)), 0, Config.Loot.MaxEnhance)
end

local function weaponGradeId(tier)
	local info = Config.WeaponInfo[tier]
	return (info and Config.WeaponGrades[info.Grade]) and info.Grade or "Common"
end

local function inCombat()
	return num(attr("InCombatUntil"), 0) > Util.Now()
end

local function clock(secs)
	secs = math.max(0, math.ceil(num(secs, 0)))
	return string.format(TXT.Clock, secs // 60, secs % 60)
end

local function pct(x)
	return math.floor(num(x, 0) * 100 + 0.5)
end

---------------------------------------------------------------------------------------------------- weapons (pure)
-- the owned weapons, the worn one first, then the strongest (by Damage, never by the tier number). ctx = { Mask, Equipped,
-- Level, Class, Faction, Enhance = { [tier] = n }, EquippedPlus, PowerNow, Power(tier, plus) -> number }. A row = { Tier,
-- Name, Plus, Grade, Icon, Equipped, Usable, MinLevel, Attack, PowerNow, PowerWith }
function CharacterUI.Weapons(ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local equipped = math.floor(num(ctx.Equipped, 0))
	local level = math.max(1, math.floor(num(ctx.Level, 1)))
	local rows = {}
	for tier = 1, Config.MaxWeaponTier do
		if owns(ctx.Mask, tier) or tier == equipped then
			local plus = enhOf(ctx.Enhance, tier)
			if tier == equipped and plus == 0 then plus = math.clamp(math.floor(num(ctx.EquippedPlus, 0)), 0, Config.Loot.MaxEnhance) end
			local with = type(ctx.Power) == "function" and ctx.Power(tier, plus) or nil
			table.insert(rows, { Tier = tier, Name = Config.WeaponName(tier, ctx.Class, ctx.Faction), Plus = plus,
				Grade = weaponGradeId(tier), Icon = Config.WeaponArtKey(tier, ctx.Class, ctx.Faction), Equipped = tier == equipped,
				Usable = Config.WeaponUsable(tier, level), MinLevel = math.floor(num(Config.Weapons[tier].MinLevel, 1)),
				NeedSide = Config.Weapons[tier].RequiresFaction == true,
				Attack = math.floor(Config.WeaponDamage(tier, level, plus)),
				PowerNow = type(ctx.PowerNow) == "number" and ctx.PowerNow or nil, PowerWith = type(with) == "number" and with or nil })
		end
	end
	table.sort(rows, function(a, b)
		if a.Equipped ~= b.Equipped then return a.Equipped end
		local da, db = num(Config.Weapons[a.Tier].Damage, 0), num(Config.Weapons[b.Tier].Damage, 0)
		if da ~= db then return da > db end
		return a.Tier < b.Tier
	end)
	return rows
end

-- the button of a weapon row: the bag's words. ctx = { Combat, Pending = { Tier } | nil }
function CharacterUI.EquipState(row, ctx)
	ctx = type(ctx) == "table" and ctx or {}
	if row.Equipped then return tx(TXT, "Equipped"), false end
	if not row.Usable then return tx(TXT, "FromLv", row.MinLevel), false end
	if ctx.Pending and ctx.Pending.Tier == row.Tier then return tx(TXT, "Checking"), false end
	-- 게임성 검수 10/12: the server's other refusals (LootService onEquipWeapon) dim the button instead of a silent drop:
	-- dead, no class yet, a side weapon (RequiresFaction) without a side
	if ctx.Dead or ctx.NoClass or (row.NeedSide and ctx.Faction == "None") then return tx(TXT, "Equip"), false end
	if ctx.Combat then return tx(TXT, "InFight"), false end
	return tx(TXT, "Equip"), ctx.Pending == nil
end

---------------------------------------------------------------------------------------------------- titles (pure)
-- "Auto" (the faction rank) first, then the titles the player owns in Config.TitleOrder. ctx = { Owned = "id,id", Sel = id | "" }.
-- A row = { Id, Name, Color?, Current }; exactly one is current
function CharacterUI.Titles(ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local owned = {}
	if type(ctx.Owned) == "string" then
		for id in string.gmatch(ctx.Owned, "[^,]+") do owned[id] = true end
	end
	local sel = type(ctx.Sel) == "string" and ctx.Sel or ""
	if sel ~= "" and not (owned[sel] and Config.TitleDefs[sel]) then sel = "" end
	local list = { { Id = "", Name = tx(TXT, "TitleAuto"), Current = sel == "" } }
	for _, id in Config.TitleOrder do
		local def = Config.TitleDefs[id]
		if owned[id] and def then
			table.insert(list, { Id = id, Name = tx(def, "Name"), Color = def.Color, Current = sel == id })
		end
	end
	return list
end

---------------------------------------------------------------------------------------------------- pet cell (pure)
-- rows = PetWindow.Rows(...): no row = no pet cell (nil); else the worn pet (or nil: pets, none following) and the count
function CharacterUI.PetState(rows)
	if type(Config.Pets) ~= "table" or type(rows) ~= "table" or #rows == 0 then return nil end
	local worn = nil
	for _, r in rows do
		if r.Equipped then worn = r end
	end
	return { Equipped = worn, Count = #rows }
end

---------------------------------------------------------------------------------------------------- stats (pure)
-- 최종 검수 10/13 (ref_rpg_ui #9): my side's rank as a bar - { Title, Next (nil at the top), Fill 0..1 inside this rank,
-- ToGo, Icon } for Halo (honor) / Horns (infamy); nil without a side
function CharacterUI.RankBar(faction, honor, infamy)
	local names, th = Config.Titles[faction], Config.Titles.Thresholds
	if type(names) ~= "table" then return nil end
	local points = math.max(0, math.floor(num(faction == "Halo" and honor or infamy, 0)))
	local title, rank = Config.GetTitle(faction, honor, infamy)
	local lo, hi = num(th[rank], 0), th[rank + 1]
	local nextName = hi and names[rank + 1] or nil
	local fill = hi and math.clamp((points - lo) / math.max(1, hi - lo), 0, 1) or 1
	return { Title = title, Next = nextName, Fill = fill, ToGo = hi and (hi - points) or 0,
		Icon = faction == "Halo" and "IconRankHonor" or "IconRankInfamy" }
end

-- 최종 검수 10/13 (ref_rpg_ui #9): the titles I do not own yet (Config.TitleOrder), shown grey under mine. API review: only
-- ones I can still earn - no weekly (Timed) title, none of L.LockedSkip (past / season ones), not the other side's
-- (L.LockedSide), at most L.LockedMax
function CharacterUI.LockedTitles(owned, faction)
	local have = {}
	if type(owned) == "string" then
		for id in string.gmatch(owned, "[^,]+") do have[id] = true end
	end
	local list = {}
	for _, id in Config.TitleOrder do
		local def = Config.TitleDefs[id]
		local side = L.LockedSide[id]
		if def and not have[id] and def.Timed ~= true and not L.LockedSkip[id] and (side == nil or side == faction) then
			table.insert(list, { Id = id, Name = tx(def, "Name") })
			if #list >= L.LockedMax then break end
		end
	end
	return list
end

-- the next rank of a side: name and points to go; nil at the top (Config.Titles)
function CharacterUI.NextRank(faction, points)
	local names, th = Config.Titles[faction], Config.Titles.Thresholds
	if type(names) ~= "table" then return nil end
	points = math.max(0, math.floor(num(points, 0)))
	for i, t in th do
		if points < t and names[i] then return names[i], t - points end
	end
	return nil
end

-- one normal hit: the weapon at this level x the class x the side's attack bonus x the immediate half of a swing
-- (the server's formula without crit / buffs, Config.SwingHitsToKill's)
local function hitDamage(ctx)
	local tier = math.clamp(math.floor(num(ctx.Tier, 0)), 0, Config.MaxWeaponTier)
	local level = math.max(1, math.floor(num(ctx.Level, 1)))
	local profile = Config.AttackProfile(ctx.Class, tier, ctx.Faction)
	local f = Config.Factions[ctx.Faction]
	local bonus = type(f) == "table" and num(f.DamageBonus, 0) or 0
	local per = Config.WeaponDamage(tier, level, num(ctx.EquippedPlus, 0)) * num(profile.Damage, 1) * (1 + bonus)
		* num(Config.BasicSkill and Config.BasicSkill.SwingImmediate, 0.5)
	return math.max(1, math.floor(per + 0.5))
end

-- the Stats tab. ctx = { Level, MaxHealth, MaxMana, WalkSpeed, Tier, EquippedPlus, Class, Faction, SizeMult, BullyStacks,
-- WantedStars, RevengeUntil, Now, Blessing, Rebirths, RebirthBonus, FallMarks, RedeemMarks, Honor, Infamy }
-- -> rows { Kind = "Head" | "Card" | "Chip" | "Row", Id?, Icon?, Label?, Value?, Text? }; a value with no source leaves its
-- row out. 최종 검수 10/13 (ref_rpg_ui #5: the text wall): the core numbers are cards (an icon, the number, one word), the
-- class / side traits and the effects on now are short chips made from the numbers ("XP +30%"), no perk sentences
-- (pure) 최종 검수 10/15 (계획 5, 2-C #3; StatService dev2-stats3): the Stats tab's point panel - nil while
-- Config.Features.StatPoints is off (no 'soon': hidden). ctx: StatOn, StatAtk, StatHp, StatFree, AutoStat, PowerNow,
-- PowerWith(a, h) -> the power with that split. -> { Free, Auto, CanReset, Rows = { { Letter, Name, Points, Line, Next,
-- CanAdd, CanAdd5 } A, H } }
function CharacterUI.StatPanel(ctx)
	if type(ctx) ~= "table" or ctx.StatOn ~= true then return nil end
	local ST = type(Config.Stats) == "table" and Config.Stats or {}
	local W = type(ST.Text) == "table" and ST.Text or {}
	local a, h = math.max(0, math.floor(num(ctx.StatAtk, 0))), math.max(0, math.floor(num(ctx.StatHp, 0)))
	local free = math.max(0, math.floor(num(ctx.StatFree, 0)))
	local auto = ctx.AutoStat ~= false
	local now = math.floor(num(ctx.PowerNow, 0))
	local out = { Free = free, Auto = auto, CanReset = not auto and (a + h) > 0, Rows = {} }
	for _, letter in { "A", "H" } do
		local pts = letter == "A" and a or h
		local with = nil
		if type(ctx.PowerWith) == "function" then
			local ok, v = pcall(ctx.PowerWith, letter == "A" and a + 1 or a, letter == "H" and h + 1 or h)
			if ok and type(v) == "number" then with = math.floor(v) end
		end
		local maxed = pts >= (tonumber(ST.MaxPoints) or 99)
		table.insert(out.Rows, { Letter = letter, Name = type(W.Names) == "table" and tx(W.Names, letter) or letter, Points = pts,
			Line = tx(W, "Points", pts, pct(Config.StatBonus(pts))),
			Next = (with and not maxed) and tx(W, "NextPower", Util.FormatInt(now), Util.FormatInt(with)) or nil,
			CanAdd = not auto and free >= 1 and not maxed, CanAdd5 = not auto and free >= 2 and not maxed })
	end
	return out
end

-- (pure) the hunting fame bar (HuntFameService's units toward the next point; attribute HuntFame) - nil without it, for
-- Neutral / None, or while Config.HuntFame is off. -> { Have, Per, Frac, Label, Value }
function CharacterUI.HuntBar(ctx)
	local HF = Config.HuntFame
	if type(ctx) ~= "table" or type(HF) ~= "table" or HF.Enabled == false then return nil end
	if ctx.Faction ~= "Halo" and ctx.Faction ~= "Horns" then return nil end
	local have = tonumber(ctx.HuntFame)
	if have == nil or have ~= have then return nil end
	local per = math.max(1, math.floor(num(HF.KillsPerPoint, 100)))
	have = math.clamp(math.floor(have), 0, per)
	local W = type(Config.Stats) == "table" and type(Config.Stats.Text) == "table" and Config.Stats.Text or {}
	return { Have = have, Per = per, Frac = have / per, Label = tx(W, "Hunt"), Value = tx(W, "HuntValue", have, per) }
end

-- c->s StatAction(op, arg) (StatService: "add" / "add5" "A" | "H", "reset", "auto" true | false); Auto on asks first
function CharacterUI.StatAction(op, arg)
	if not VIEW.Kit then return false end
	if op == "auto" and arg == true then
		local W = type(Config.Stats) == "table" and type(Config.Stats.Text) == "table" and Config.Stats.Text or {}
		if type(VIEW.Kit.Confirm) == "function" then
			VIEW.Kit.Confirm(tx(W, "AutoAsk"), tx(W, "AutoAskBody"), tx(W, "AutoAskOk"), function() send("StatAction", nil, "auto", true) end)
			return true
		end
	end
	return send("StatAction", nil, op, arg)
end

function CharacterUI.StatRows(ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local rows = {}
	-- 최종 검수 10/15: the point panel and the hunting fame bar first (each only when it applies)
	local panel = CharacterUI.StatPanel(ctx)
	if panel then table.insert(rows, { Kind = "StatPanel", Id = "Points", Panel = panel }) end
	local hunt = CharacterUI.HuntBar(ctx)
	if hunt then table.insert(rows, { Kind = "HuntBar", Id = "Hunt", Bar = hunt }) end
	local function head(id) table.insert(rows, { Kind = "Head", Id = id, Text = tx(TXT.Heads, id) }) end
	local function row(id, value) table.insert(rows, { Kind = "Row", Id = id, Label = tx(TXT.Stat, id), Value = value }) end
	local function card(id, icon, value)
		table.insert(rows, { Kind = "Card", Id = id, Icon = icon, Label = tx(TXT.Stat, id), Value = value })
	end
	local function chip(id, text) table.insert(rows, { Kind = "Chip", Id = id, Text = text }) end
	local faction = type(ctx.Faction) == "string" and ctx.Faction or "None"
	local level = math.max(1, math.floor(num(ctx.Level, 1)))

	head("Stats")
	card("Level", "IconStar", tostring(level))
	if num(ctx.MaxHealth, 0) > 0 then card("MaxHP", "IconHeart", Util.FormatInt(math.floor(ctx.MaxHealth))) end
	card("MP", "IconPotionMP", Util.FormatInt(math.floor(num(ctx.MaxMana, num(Config.Vitals.MaxMana, 100)))))
	if num(ctx.WalkSpeed, 0) > 0 then card("Speed", "IconBoot", tostring(math.floor(ctx.WalkSpeed * 10 + 0.5) / 10)) end
	local ok, hit = pcall(hitDamage, ctx)
	if ok then card("Hit", "IconSword", Util.FormatInt(hit)) end
	card("Crit", nil, tx(TXT, "CritValue", pct(Config.Combat.CritChance), tostring(Config.Combat.CritMult)))

	-- the class's and the side's traits: chips from the numbers (Config.Classes Stats are short already)
	head("Traits")
	local class = Config.Classes[ctx.Class] or Config.Classes.Warrior
	for i, text in type(class.Stats) == "table" and class.Stats or {} do chip("Class" .. i, text) end
	local fdef = Config.Factions[faction]
	if faction ~= "None" and type(fdef) == "table" then
		if num(fdef.XPBonus, 0) > 0 then chip("XP", tx(TXT.Chip, "XP", pct(fdef.XPBonus))) end
		if num(fdef.GoldBonus, 0) > 0 then chip("Gold", tx(TXT.Chip, "Gold", pct(fdef.GoldBonus))) end
		if num(fdef.MaxHPMult, 1) > 1.001 then chip("HP", tx(TXT.Chip, "HP", pct(fdef.MaxHPMult - 1))) end
		if num(fdef.DamageBonus, 0) > 0 then chip("ATK", tx(TXT.Chip, "ATK", pct(fdef.DamageBonus))) end
		if num(fdef.RegenPerSec, 0) > 0 then chip("Regen", tx(TXT.Chip, "Regen")) end
		if num(fdef.Lifesteal, 0) > 0 then chip("Steal", tx(TXT.Chip, "Steal", pct(fdef.Lifesteal))) end
		if fdef.ReleaseSupport == true then chip("Heal", tx(TXT.Chip, "Heal")) end
	end

	-- what is on right now (nothing: no heading), chips too
	local effects = {}
	local size = num(ctx.SizeMult, 1)
	if size > 1.001 then table.insert(effects, { "Size", tx(TXT.Chip, "Size", size) }) end
	local bully = math.floor(num(ctx.BullyStacks, 0))
	if bully >= 1 then
		table.insert(effects, { "Bully", tx(TXT.Chip, "Bully", pct(1 - Config.BullyMult(bully))) })
		table.insert(effects, { "NoAuto", tx(TXT.Chip, "NoAuto") })
	end
	local stars = faction == "Horns" and math.clamp(math.floor(num(ctx.WantedStars, 0)), 0, Config.PvP.MaxStars) or 0
	if stars >= 1 then
		table.insert(effects, { "Wanted", tx(TXT.Chip, "Wanted", string.rep("★", stars), pct(stars * Config.PvP.StarDamageBonus)) })
	end
	local left = num(ctx.RevengeUntil, 0) - num(ctx.Now, 0)
	if left > 0 then table.insert(effects, { "Revenge", tx(TXT.Chip, "Revenge", pct(Config.Revenge.Bonus), clock(left)) }) end
	-- 게임성 검수 10/12: the crown war's blessing is only the winning side's (WarService.HasBlessing) - gold and XP
	local blessing = ctx.Blessing
	if (blessing == "Halo" or blessing == "Horns") and blessing == faction then
		table.insert(effects, { "Blessing", tx(TXT.Chip, "Blessing", pct(Config.War.BlessingGold)) })
	end
	if #effects > 0 then
		head("Effects")
		for _, e in effects do chip(e[1], e[2]) end
	end

	local rebirths = math.max(0, math.floor(num(ctx.Rebirths, 0)))
	local bonus = math.max(0, num(ctx.RebirthBonus, 0))
	local fall = math.max(0, math.floor(num(ctx.FallMarks, 0)))
	local redeem = math.max(0, math.floor(num(ctx.RedeemMarks, 0)))
	if rebirths >= L.ShowRebirthMin or bonus > 0 or fall > 0 or redeem > 0 then
		head("Rebirth")
		if rebirths >= 1 then row("Rebirths", tostring(rebirths)) end
		if bonus > 0 then row("RebirthBonus", tx(TXT, "RebirthBonusValue", pct(bonus))) end
		if fall > 0 then row("Fall", tx(TXT, "MarksValue", fall, Config.Rebirth.MarkMax)) end
		if redeem > 0 then row("Redeem", tx(TXT, "MarksValue", redeem, Config.Rebirth.MarkMax)) end
	end

	if faction == "Halo" or faction == "Horns" then
		head("Rank")
		local honor, infamy = math.max(0, math.floor(num(ctx.Honor, 0))), math.max(0, math.floor(num(ctx.Infamy, 0)))
		local mine = faction == "Halo" and honor or infamy
		local other = faction == "Halo" and infamy or honor
		local title = Config.GetTitle(faction, honor, infamy)
		row("Rank", title)
		row(faction == "Halo" and "Honor" or "Infamy", Util.FormatInt(mine))
		local nextName, toGo = CharacterUI.NextRank(faction, mine)
		row("Next", nextName and tx(TXT, "NextValue", nextName, toGo) or tx(TXT, "TopRank"))
		if other > 0 then row(faction == "Halo" and "Infamy" or "Honor", Util.FormatInt(other)) end
	end
	return rows
end

---------------------------------------------------------------------------------------------------- data
local function ui() return C and C.UIKit end

local function gameAttr(name, d)
	local kit = ui()
	if type(kit) == "table" and type(kit.GameAttr) == "function" then
		local ok, v = pcall(kit.GameAttr, name, d)
		if ok and v ~= nil then return v end
	end
	return d
end

-- the +N per weapon tier of the bag's Inventory payload (Panels keeps the last one)
local function inventoryEnhance()
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.LastInventory) ~= "function" then return nil end
	local ok, payload = pcall(panels.LastInventory)
	return (ok and type(payload) == "table" and type(payload.Enhance) == "table") and payload.Enhance or nil
end

-- the pet rows (PetWindow's own model: the last PetList, else the follower from the attributes); {} without a pet system
local function petRows()
	local pw = C and C.PetWindow
	if type(pw) ~= "table" or type(pw.Rows) ~= "function" then return {} end
	local list = nil
	if type(pw.Lists) == "function" then
		local ok, l = pcall(pw.Lists)
		if ok then list = l end
	end
	local ok, rows = pcall(pw.Rows, list, { Class = attr("Class"), Faction = attr("Faction"), EquippedPet = attr("EquippedPet"),
		PetLv = attr("PetLv"), PetRoll = attr("PetRoll") })
	return (ok and type(rows) == "table") and rows or {}
end

-- the model's input from the attributes (and the humanoid)
local function context()
	local class = attr("Class")
	local okH, hum = pcall(Util.GetHumanoid, LocalPlayer)
	if not okH then hum = nil end
	local level = math.max(1, math.floor(num(attr("Level"), 1)))
	local tier = math.clamp(math.floor(num(attr("WeaponTier"), 0)), 0, Config.MaxWeaponTier)
	local plus = num(attr("WeaponEnhance"), 0)
	local okP, now = pcall(Config.CombatPowerOf, LocalPlayer)
	local okPa, pa, ph = pcall(Config.PowerPartsOf, LocalPlayer)
	local parts = okPa and { A = pa, H = ph } or nil
	local okAl, alloc = pcall(Config.StatAllocOf, LocalPlayer)
	local okG, ga, gh = pcall(Config.GearMultsOf, LocalPlayer)
	local power = tonumber(attr("CombatPower", nil))
	if power == nil then power = okP and tonumber(now) or 0 end -- before the server's first set (Config.CombatPowerOf, test_stats)
	return { Level = level, Class = (type(class) == "string" and Config.Classes[class]) and class or "Warrior",
		Faction = type(attr("Faction")) == "string" and attr("Faction") or "None",
		Mask = num(attr("WeaponOwnedMask"), 0), Equipped = tier, Tier = tier, EquippedPlus = plus, Enhance = inventoryEnhance(),
		PowerNow = okP and now or nil, Power = function(t, p) return Config.CombatPowerOf(LocalPlayer, t, p) end,
		CombatPower = math.floor(power),
		MaxHealth = hum and hum.MaxHealth or nil, WalkSpeed = hum and hum.WalkSpeed or nil,
		MaxMana = num(attr("MaxMana"), num(Config.Vitals.MaxMana, 100)),
		SizeMult = num(attr("SizeMult"), 1), BullyStacks = num(attr("BullyStacks"), 0), WantedStars = num(attr("WantedStars"), 0),
		RevengeUntil = num(attr("RevengeUntil"), 0), Now = Util.Now(), Blessing = gameAttr("WarBlessing", "None"),
		Rebirths = num(attr("Rebirths"), 0), RebirthBonus = num(attr("RebirthBonus"), 0), FallMarks = num(attr("FallMarks"), 0),
		RedeemMarks = num(attr("RedeemMarks"), 0), Honor = num(attr("Honor"), 0), Infamy = num(attr("Infamy"), 0),
		Owned = tostring(attr("TitlesOwned", "")), Sel = tostring(attr("TitleSel", "")),
		-- 최종 검수 10/13 (ref_rpg_ui #1): the power's two parts and what goes into them
		Attack = parts and parts.A or 0, Health = parts and parts.H or 0, Plus = math.floor(plus),
		Alloc = okAl and alloc or nil, Gear = okG and { A = ga, H = gh } or nil,
		-- 최종 검수 10/15: the point panel (StatService) and the hunting fame bar (HuntFameService)
		StatOn = Config.FeatureOn("StatPoints"), StatAtk = num(attr("StatAtk"), 0), StatHp = num(attr("StatHp"), 0),
		StatFree = num(attr("StatFree"), 0), AutoStat = attr("AutoStat") ~= false, HuntFame = attr("HuntFame"),
		PowerWith = function(a, h) return Config.CombatPowerOf(LocalPlayer, nil, nil, nil, { A = a, H = h }) end }
end

---------------------------------------------------------------------------------------------------- requests
-- seconds between two sends of one remote (the server's rate limit + a margin)
local function gap(key)
	local v = num(type(Config.RateLimits) == "table" and Config.RateLimits[key], 0.4)
	return math.max(0, v) + L.GapMargin
end

-- sends one request unless one is waiting or the server would still drop it; true when sent (the bag's rule)
local function send(key, pending, ...)
	local kit = VIEW.Kit
	local now = os.clock()
	if not kit or (pending and S.Pending) or now < (S.ReadyAt[key] or 0) then return false end
	kit.Fire(key, ...)
	S.ReadyAt[key] = now + gap(key)
	if pending then
		pending.SentAt, pending.ReadyAt = now, S.ReadyAt[key]
		S.Pending = pending
	end
	return true
end

-- a waiting equip answered (the worn weapon changed) and past the server's interval, or timed out; true when it changed
local function checkPending()
	local p = S.Pending
	if not p then return false end
	local now, changed = os.clock(), false
	if not p.Answered then
		if math.floor(num(attr("WeaponTier"), 0)) ~= p.WeaponTier then
			p.Answered, changed = true, true
		elseif now - p.SentAt >= L.PendingTimeout then
			S.Pending = nil -- a refusal already got the server's toast; no second line (A23-130)
			return true
		end
	end
	if p.Answered and now >= (p.ReadyAt or 0) then S.Pending, changed = nil, true end
	return changed
end

-- c->s EquipWeapon(tier): the bag's path (the same guards: owned, usable at this level, not in a fight, one request at a time)
function CharacterUI.Equip(tier)
	if not VIEW.Kit or type(tier) ~= "number" then return false end
	local row = nil
	for _, r in CharacterUI.Weapons(context()) do
		if r.Tier == tier then row = r end
	end
	if not row or row.Equipped or not row.Usable or inCombat() then return false end
	return send("EquipWeapon", { Tier = tier, WeaponTier = math.floor(num(attr("WeaponTier"), 0)) }, tier)
end

-- c->s SetTitle(id): "" = Auto or a title I own that is not the one shown
function CharacterUI.SetTitle(id)
	if not VIEW.Kit or type(id) ~= "string" then return false end
	local ctx = context()
	for _, t in CharacterUI.Titles(ctx) do
		if t.Id == id then
			if t.Current then return false end
			return send("SetTitle", nil, id)
		end
	end
	return false
end

-- 최종 검수 10/13 (ref_rpg_ui #3): the 3D body module (may be missing: then no body, the rest works)
local function preview()
	local h = C and C.HeroPreview
	if type(h) == "table" and type(h.Mount) == "function" then return h end
	return nil
end

local function gearModule()
	local g = C and C.GearSlots
	if not S.GearOff and type(g) == "table" and type(g.Build) == "function" then return g end
	return nil
end

---------------------------------------------------------------------------------------------------- drawing
local function label(parent, text, size, color, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = VIEW.Kit and VIEW.Kit.Font or Enum.Font.GothamMedium
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	for k, v in props or {} do
		if k ~= "Style" then l[k] = v end
	end
	l.Parent = parent
	local kit = ui()
	if props and props.Style == false then return l end -- a tiny caption that shrinks to fit (no text-size floor)
	if type(kit) == "table" and type(kit.StyleText) == "function" then
		pcall(kit.StyleText, l, (props and props.Style) or "Body")
		l.TextColor3 = color
	end
	return l
end

local function colorOf(name)
	local kit = VIEW.Kit
	local th = kit and kit.Theme or {}
	if name == "Gold" then return th.Gold end
	if name == "Good" then return th.Good end
	if name == "Bad" then return th.Bad end
	if name == "Sub" or name == "Same" then return th.SubText end
	return th.Text
end

-- 최종 검수 10/13 (ref_rpg_ui #1): the sources of the power's Attack / Health (pure: ctx = { Level, Tier, Plus, Class,
-- Faction, Alloc = { A, H }, Gear = { A, H } }) - short lines, numbers and names only
function CharacterUI.PowerWhy(part, ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local lines = {}
	local level = math.max(1, math.floor(num(ctx.Level, 1)))
	if part == "Attack" then
		local tier = math.floor(num(ctx.Tier, 0))
		if Config.Weapons[tier] then
			table.insert(lines, tx(TXT.Why, "Weapon", Config.WeaponName(tier, ctx.Class, ctx.Faction), math.floor(num(ctx.Plus, 0))))
		else
			table.insert(lines, tx(TXT.Why, "Fist"))
		end
	end
	table.insert(lines, tx(TXT.Why, "Level", level))
	local alloc = type(ctx.Alloc) == "table" and ctx.Alloc or {}
	local pts = math.floor(num(part == "Attack" and alloc.A or alloc.H, 0))
	if Config.FeatureOn("StatPoints") and pts > 0 then table.insert(lines, tx(TXT.Why, "Points", pts)) end
	local gear = type(ctx.Gear) == "table" and ctx.Gear or {}
	local pct = math.floor((num(part == "Attack" and gear.A or gear.H, 1) - 1) * 100 + 0.5)
	if Config.Features.Gear == true and pct > 0 then table.insert(lines, tx(TXT.Why, part == "Attack" and "Ring" or "Armor", pct)) end
	return lines
end

-- 최종 검수 10/13 (ref_rpg_ui #2): a power change as one line + its colour name (nil = no line)
function CharacterUI.DiffLine(now, with)
	local d, tone = Config.PowerDiff(now, with)
	if not d then return nil, nil end
	local t = Config.Power.Text.Diff
	if tone == "Good" then return string.format(t.Up, Util.FormatInt(d)), "Good" end
	if tone == "Bad" then return string.format(t.Down, Util.FormatInt(d)), "Bad" end
	return t.Same, "Same"
end

local function clear(frame)
	if not frame then return end
	for _, ch in frame:GetChildren() do
		if not ch:IsA("UIGridLayout") and not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
	end
end

local function listLayout(frame, gapPx, center)
	local list = frame:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, gapPx)
	if center then list.HorizontalAlignment = Enum.HorizontalAlignment.Center end
	list.Parent = frame
	return list
end

local function scroller(parent, name)
	local f = Instance.new("ScrollingFrame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.CanvasSize = UDim2.new()
	f.AutomaticCanvasSize = Enum.AutomaticSize.Y
	f.ScrollingDirection = Enum.ScrollingDirection.Y
	f.ScrollBarThickness = 6
	f.Parent = parent
	return f
end

-- one approved slot (an ImageButton when onClick) with the grade part; nil grade = the empty slot look the bag uses
local function slot(parent, gradeId, onClick, name)
	local kit = ui()
	local part = gradeId and L.Slot[gradeId] or "SlotEmpty"
	local rim = gradeId and Config.WeaponGrades[gradeId] and Config.WeaponGrades[gradeId].Color or Color3.fromRGB(60, 66, 96)
	local fb = { BackgroundColor3 = Color3.fromRGB(16, 20, 40), CornerRadius = UDim.new(0, 10), StrokeColor = rim, StrokeThickness = 2 }
	local props = { Name = name, Size = UDim2.fromOffset(L.Cell, L.Cell), Parent = parent }
	if onClick then return (kit.ArtButton(part, props, onClick, fb)) end
	return (kit.ArtFrame(part, props, fb))
end

-- the picture in a slot's Inner box: an approved art part (art = true) or an item icon; the first letter when it has none
local function putIcon(box, key, art, markText)
	local kit = ui()
	local props = { Name = "Icon", Position = UDim2.fromScale(L.Inner.X, L.Inner.Y), Size = UDim2.fromScale(L.Inner.W, L.Inner.H),
		ScaleType = Enum.ScaleType.Fit, ZIndex = (tonumber(box.ZIndex) or 1) + 1 }
	local img = art and kit.ArtImage(key, props) or ((not art) and kit.ItemIcon(key, props) or nil)
	if img then
		img.Parent = box
	elseif type(markText) == "string" then
		local letter = string.upper(string.match(markText, "%w") or "?")
		label(box, letter, math.floor(L.Cell * 0.42), Color3.new(1, 1, 1), { Name = "Letter", AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(L.Inner.W, L.Inner.H),
			TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = props.ZIndex, Style = "Number" })
	end
end

-- a corner word of a cell (top-left): "+N" / "Lv N"
local function corner(box, text, color)
	label(box, text, L.Size.Count, color, { Name = "Plus", Position = UDim2.fromOffset(4, 1),
		Size = UDim2.new(1, -8, 0, L.Size.Count + 2), TextWrapped = false, ZIndex = (tonumber(box.ZIndex) or 1) + 3, Style = "Number" })
end

-- the cell's top-left corner in EquipSlots
local function cellPos(id)
	return UDim2.fromOffset(L.Cols[id] * (L.Cell + L.ColGap), L.Rows[id] * (L.Cell + L.CapH + L.RowGap))
end

-- the one short word under a cell
local function caption(frame, name, id)
	local p = cellPos(id)
	local inset = 6
	local cap = label(frame, tx(TXT.Slots, id), L.Size.Small, colorOf("Sub"), { Name = name,
		Position = UDim2.new(0, p.X.Offset - inset, 0, p.Y.Offset + L.Cell + 2), Size = UDim2.fromOffset(L.Cell + 2 * inset, L.CapH - 2),
		TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextScaled = true, Style = false })
	local tc = Instance.new("UITextSizeConstraint")
	tc.MaxTextSize = L.Size.Small
	tc.Parent = cap
	return cap
end

function CharacterUI.ShowView(view)
	if view ~= "Slots" and view ~= "Weapons" then return end
	S.View = view
	if VIEW.Sigs then VIEW.Sigs.Weapons, VIEW.Sigs.Slots = nil, nil end
	if VIEW.SlotsView then VIEW.SlotsView.Visible = view == "Slots" end
	if VIEW.WeaponsView then VIEW.WeaponsView.Visible = view == "Weapons" end
	CharacterUI.Refresh(false)
end

local function openPet()
	local kit = VIEW.Kit
	local panels = C and C.Panels
	local has = type(panels) == "table" and type(panels.Has) == "function" and panels.Has("Pet") == true
	if has and kit and type(kit.Open) == "function" then
		pcall(kit.Open, "Pet") -- a back button returns here
	elseif C and type(C.PetWindow) == "table" and type(C.PetWindow.Open) == "function" then
		pcall(C.PetWindow.Open)
	end
end

-- takes back what the fallback drew (before GearSlots draws its cells, and before the fallback draws again)
local function clearFallback()
	for _, o in S.Drawn do pcall(o.Destroy, o) end
	S.Drawn = {}
end

-- the FALLBACK cells of EquipSlots (no GearSlots only): the Weapon cell, the Pet cell (with pets), four SlotEmpty cells.
-- Only called while there is no GearSlots (refresh checks): with it this module draws no cell at all.
local function drawSlots(frame, data)
	clearFallback()
	local function keep(o)
		table.insert(S.Drawn, o)
		return o
	end
	local function capt(name, id) keep(caption(frame, name, id)) end
	local worn = data.Worn
	local box
	if worn then
		box = keep(slot(frame, worn.Grade, function() CharacterUI.ShowView(S.View == "Weapons" and "Slots" or "Weapons") end, "Cell_Weapon"))
		putIcon(box, worn.Icon, false, worn.Name)
		if worn.Plus > 0 then corner(box, "+" .. tostring(worn.Plus), colorOf("Gold")) end
	else
		box = keep(slot(frame, nil, function() CharacterUI.ShowView(S.View == "Weapons" and "Slots" or "Weapons") end, "Cell_Weapon"))
	end
	box.Position = cellPos("Weapon")
	capt("Cap_Weapon", "Weapon")
	local pet = data.Pet
	if pet then
		local row = pet.Equipped
		box = keep(slot(frame, row and "Common" or nil, openPet, "Cell_Pet"))
		if row then
			putIcon(box, row.Icon, true, row.Name)
			corner(box, tx(TXT, "PetLv", row.Lv), colorOf("Gold"))
		end
		box.Position = cellPos("Pet")
		capt("Cap_Pet", "Pet")
	end
	for _, id in L.Fallback do
		local empty = keep(slot(frame, nil, nil, "Empty_" .. id))
		empty.Position = cellPos(id)
		capt("EmptyCap_" .. id, id)
	end
end

local function drawLeft(frame, ctx)
	clear(frame)
	local kit = ui()
	listLayout(frame, 4, true)
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	local holder = Instance.new("Frame")
	holder.Name = "Portrait"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(L.Portrait, L.Portrait)
	holder.LayoutOrder = nextOrder()
	holder.Parent = frame
	local holePos, holeSize = nil, nil
	if type(kit.ArtInner) == "function" then
		local ok, p, s = pcall(kit.ArtInner, "PortraitRing")
		if ok then holePos, holeSize = p, s end
	end
	local head = Instance.new("ImageLabel")
	head.Name = "Headshot"
	local okImg, image = pcall(kit.HeadshotImage, LocalPlayer.UserId)
	head.Image = okImg and image or ""
	head.ScaleType = Enum.ScaleType.Crop
	head.BackgroundColor3 = Color3.fromRGB(16, 20, 40)
	head.Position = holePos or UDim2.fromScale(0.17, 0.16)
	head.Size = holeSize or UDim2.fromScale(0.67, 0.67)
	head.ZIndex = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = head
	head.Parent = holder
	local ring = kit.ArtImage("PortraitRing", { Name = "Ring", Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	if ring then ring.Parent = holder end
	-- 게임성 검수 10/12: the nickname lives here now (SettingsUI hides its own row once this window exists): the name and
	-- [Change] -> the Panels "Nickname" window
	local nick = attr("Nickname", "")
	nick = (type(nick) == "string" and nick ~= "") and nick or LocalPlayer.DisplayName
	local nickLabel = label(frame, nick, L.Size.Name, colorOf("Text"), { Name = "Nickname", Size = UDim2.new(1, 0, 0, L.Size.Name + 4),
		TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, LayoutOrder = nextOrder() })
	if typeof(nickLabel) == "Instance" then pcall(function() nickLabel.AutoLocalize = false end) end -- A23-179: a name
	local pk = VIEW.Kit
	if type(pk) == "table" and type(pk.Button) == "function" and type(pk.Open) == "function" then
		local change = pk.Button(frame, tx(TXT, "Change"), pk.Palette.Button, UDim2.fromOffset(L.ChangeW, L.ChangeH), function()
			pcall(pk.Open, "Nickname")
		end)
		change.Name = "ChangeName"
		change.LayoutOrder = nextOrder()
	end
	local who = label(frame, tx(TXT, "LevelClass", ctx.Level, Config.ClassName(ctx.Class, ctx.Faction)), L.Size.Body, colorOf("Text"),
		{ Name = "Who", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = nextOrder() })
	-- 최종 검수 10/13 (ref_rpg_ui #9): the title I show, on the approved ribbon
	local shown = nil
	for _, t in CharacterUI.Titles(ctx) do
		if t.Current and t.Id ~= "" then shown = t.Name end
	end
	local bar = CharacterUI.RankBar(ctx.Faction, ctx.Honor, ctx.Infamy)
	shown = shown or (bar and bar.Title) or nil
	if shown then
		local ribbon = kit.ArtFrame("TitleRibbon", { Name = "TitleRibbon", Size = UDim2.new(1, 0, 0, L.RibbonH), LayoutOrder = nextOrder() },
			{ BackgroundColor3 = Color3.fromRGB(120, 40, 50) })
		ribbon.Parent = frame
		label(ribbon, shown, L.Size.Small, colorOf("Text"), { Name = "Title", Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = 3 })
	end
	label(frame, tx(TXT, "Power"), L.Size.Small, colorOf("Sub"), { Name = "PowerWord", Size = UDim2.new(1, 0, 0, L.Size.Small + 4),
		TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, LayoutOrder = nextOrder() })
	label(frame, Util.FormatInt(ctx.CombatPower), L.Size.Power, colorOf("Gold"), { Name = "PowerNumber",
		Size = UDim2.new(1, 0, 0, L.Size.Power + 6), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false,
		LayoutOrder = nextOrder(), Style = "Number" })
	-- 최종 검수 10/13 (ref_rpg_ui #1): [sword] Attack · [heart] Health under the power; a press lists where each comes from
	local parts = Instance.new("Frame")
	parts.Name = "PowerParts"
	parts.BackgroundTransparency = 1
	parts.Size = UDim2.new(1, 0, 0, L.ChipH)
	parts.LayoutOrder = nextOrder()
	parts.Parent = frame
	local pl = Instance.new("UIListLayout")
	pl.FillDirection = Enum.FillDirection.Horizontal
	pl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pl.SortOrder = Enum.SortOrder.LayoutOrder
	pl.Padding = UDim.new(0, 6)
	pl.Parent = parts
	for i, part in { { "Attack", "IconSword", ctx.Attack }, { "Health", "IconHeart", ctx.Health } } do
		local id = part[1]
		local chip = kit.ArtButton("Chip", { Name = "Part_" .. id, Size = UDim2.fromOffset(L.ChipW, L.ChipH), LayoutOrder = i },
			function()
				S.Why = S.Why ~= id and id or nil
				CharacterUI.Refresh(true)
			end, { BackgroundColor3 = Color3.fromRGB(40, 46, 72) })
		chip.Parent = parts
		local icon = kit.ArtImage(part[2], { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 5, 0.5, 0),
			Size = UDim2.fromOffset(L.ChipIcon, L.ChipIcon), ZIndex = 3 })
		if icon then icon.Parent = chip end
		label(chip, Util.FormatInt(num(part[3], 0)), L.Size.Small, S.Why == id and colorOf("Gold") or colorOf("Text"),
			{ Name = "Value", Position = UDim2.fromOffset(L.ChipIcon + 8, 0), Size = UDim2.new(1, -(L.ChipIcon + 10), 1, 0),
				TextWrapped = false, ZIndex = 3 })
	end
	-- 최종 검수 10/13 (ref_rpg_ui #9): the next rank bar (my side's points inside this rank; full at the top)
	local rb = CharacterUI.RankBar(ctx.Faction, ctx.Honor, ctx.Infamy)
	if rb then
		local row = Instance.new("Frame")
		row.Name = "RankBar"
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, L.BarIcon + L.Size.Small + 6)
		row.LayoutOrder = nextOrder()
		row.Parent = frame
		local icon = kit.ArtImage(rb.Icon, { Name = "Icon", Size = UDim2.fromOffset(L.BarIcon, L.BarIcon), ZIndex = 3 })
		if icon then icon.Parent = row end
		local track = kit.ArtFrame("BarTrack", { Name = "Track", Position = UDim2.new(0, L.BarIcon + 4, 0, (L.BarIcon - L.BarH) / 2),
			Size = UDim2.new(1, -(L.BarIcon + 4), 0, L.BarH) }, { BackgroundColor3 = Color3.fromRGB(24, 28, 48) })
		track.Parent = row
		local fill = kit.ArtFrame("BarFill", { Name = "Fill", Size = UDim2.fromScale(math.max(0.04, rb.Fill), 1), ZIndex = 3 },
			{ BackgroundColor3 = Color3.fromRGB(255, 214, 110) })
		fill.Parent = track
		label(row, rb.Next and tx(TXT, "ToGo", rb.ToGo) or tx(TXT, "TopRank"), L.Size.Small, colorOf("Sub"), { Name = "ToGo",
			Position = UDim2.fromOffset(0, L.BarIcon + 2), Size = UDim2.new(1, 0, 0, L.Size.Small + 3),
			TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false })
	end
	if S.Why then
		local why = Instance.new("Frame")
		why.Name = "PowerWhy"
		why.BackgroundTransparency = 1
		why.Size = UDim2.new(1, 0, 0, 0)
		why.AutomaticSize = Enum.AutomaticSize.Y
		why.LayoutOrder = nextOrder()
		why.Parent = frame
		listLayout(why, 1, true)
		for i, text in CharacterUI.PowerWhy(S.Why, ctx) do
			label(why, text, L.Size.Small, colorOf("Sub"), { Name = "Why" .. i, Size = UDim2.new(1, 0, 0, L.Size.Small + 3),
				TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, LayoutOrder = i })
		end
	end
	return who
end

local function drawTitles(frame, titles)
	clear(frame)
	local kit = VIEW.Kit
	listLayout(frame, 6, false)
	local order = 1
	label(frame, tx(TXT, "TitleHead"), L.Size.Name, colorOf("Gold"), { Name = "TitleHead", Size = UDim2.new(1, 0, 0, L.Size.Name + 6),
		TextWrapped = false, LayoutOrder = order })
	for _, t in titles do
		order += 1
		local b = kit.Button(frame, t.Name, t.Current and kit.Theme.Gold or kit.Palette.Button, UDim2.fromOffset(L.TitleW, L.TitleH),
			function() CharacterUI.SetTitle(t.Id) end, t.Current and kit.Palette.DarkText or nil)
		b.Name = "Title_" .. (t.Id == "" and "Auto" or t.Id)
		b.LayoutOrder = order
	end
	-- 최종 검수 10/13 (ref_rpg_ui #9): the ones still to earn, grey and off
	for _, t in CharacterUI.LockedTitles(attr("TitlesOwned", ""), attr("Faction", "None")) do
		order += 1
		local b = kit.Button(frame, t.Name, kit.Palette.Button, UDim2.fromOffset(L.TitleW, L.TitleH), function() end)
		b.Name = "Locked_" .. t.Id
		b.LayoutOrder = order
		kit.SetEnabled(b, false)
	end
end

local function drawWeapons(frame, rows, ctx)
	clear(frame)
	local kit = VIEW.Kit
	listLayout(frame, 6, false)
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, -8, 0, L.TitleH + 4)
	header.LayoutOrder = nextOrder()
	header.Parent = frame
	local back = kit.Button(header, tx(TXT, "Back"), kit.Palette.Button, UDim2.fromOffset(90, L.TitleH), function()
		CharacterUI.ShowView("Slots")
	end)
	back.Name = "Back"
	label(header, tx(TXT, "Weapons"), L.Size.Name, colorOf("Gold"), { Name = "WeaponsHead", Position = UDim2.fromOffset(104, 0),
		Size = UDim2.new(1, -104, 1, 0), TextWrapped = false })
	if #rows == 0 then
		label(frame, tx(TXT, "NoWeapons"), L.Size.Body, colorOf("Sub"), { Name = "NoWeapons", Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder() })
		return
	end
	local okA, alive = pcall(Util.IsAlive, LocalPlayer)
	local state = { Combat = inCombat(), Pending = S.Pending, Dead = okA and alive == false,
		NoClass = attr("ClassChosen") ~= true, Faction = ctx.Faction }
	for _, r in rows do
		local f = Instance.new("Frame")
		f.Name = "Weapon_" .. tostring(r.Tier)
		f.BackgroundColor3 = kit.Palette.Button
		f.BackgroundTransparency = r.Equipped and 0.45 or 0.65
		f.BorderSizePixel = 0
		f.Size = UDim2.new(1, -8, 0, L.RowH)
		f.LayoutOrder = nextOrder()
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 12)
		rc.Parent = f
		f.Parent = frame
		local box = slot(f, r.Grade, nil, "Slot")
		box.Position = UDim2.fromOffset(10, (L.RowH - L.Cell) / 2)
		putIcon(box, r.Icon, false, r.Name)
		if r.Plus > 0 then corner(box, "+" .. tostring(r.Plus), colorOf("Gold")) end
		local info = Instance.new("Frame")
		info.Name = "Info"
		info.BackgroundTransparency = 1
		info.Position = UDim2.fromOffset(10 + L.Cell + 10, 0)
		info.Size = UDim2.new(1, -(10 + L.Cell + 10 + L.ButtonW + 18), 1, 0)
		info.Parent = f
		local il = listLayout(info, 2, false)
		il.VerticalAlignment = Enum.VerticalAlignment.Center
		local g = Config.WeaponGrades[r.Grade] or Config.WeaponGrades.Common
		label(info, r.Name, L.Size.Name, g.Color, { Name = "Name", Size = UDim2.new(1, 0, 0, L.Size.Name + 4), TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 1, Style = "Title" })
		label(info, tx(TXT, "Attack", Util.FormatInt(r.Attack)), L.Size.Small, colorOf("Sub"), { Name = "Attack",
			Size = UDim2.new(1, 0, 0, L.Size.Small + 3), TextWrapped = false, LayoutOrder = 2 })
		if r.PowerNow and r.PowerWith and r.Usable then
			local line, color = nil, nil
			if r.Equipped then
				line = tx(TXT, "PowerNow", Util.FormatInt(r.PowerNow))
			else
				line, color = CharacterUI.DiffLine(r.PowerNow, r.PowerWith)
			end
			label(info, line, L.Size.Small, colorOf(color), { Name = "Power", Size = UDim2.new(1, 0, 0, L.Size.Small + 3),
				TextWrapped = false, LayoutOrder = 3 })
		end
		local text, enabled = CharacterUI.EquipState(r, state)
		local b = kit.Button(f, text, enabled and kit.Palette.Free or kit.Palette.Button, UDim2.fromOffset(L.ButtonW, L.BtnH), function()
			CharacterUI.Equip(r.Tier)
		end)
		b.Name = "Equip_" .. tostring(r.Tier)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -8, 0.5, 0)
		kit.SetEnabled(b, enabled)
	end
end

local function drawStats(frame, rows)
	clear(frame)
	listLayout(frame, 4, false)
	local order = 0
	local kit = ui()
	local group, groupKind = nil, nil
	-- consecutive cards / chips share one grid (ref_rpg_ui #5: number cards and short chips instead of text rows)
	local function grid(kind)
		if group and groupKind == kind then return group end
		order += 1
		group = Instance.new("Frame")
		group.Name = kind == "Card" and ("Cards" .. order) or ("Chips" .. order)
		group.BackgroundTransparency = 1
		group.Size = UDim2.new(1, -8, 0, 0)
		group.AutomaticSize = Enum.AutomaticSize.Y
		group.LayoutOrder = order
		group.Parent = frame
		local g = Instance.new("UIGridLayout")
		g.CellSize = kind == "Card" and UDim2.fromOffset(L.CardW, L.CardH) or UDim2.fromOffset(L.TraitW, L.TraitH)
		g.CellPadding = UDim2.fromOffset(6, 6)
		g.SortOrder = Enum.SortOrder.LayoutOrder
		g.Parent = group
		groupKind = kind
		return group
	end
	for _, r in rows do
		if r.Kind == "Card" then
			local g = grid("Card")
			local c = kit.ArtFrame("Chip", { Name = "Card_" .. r.Id, LayoutOrder = #g:GetChildren() },
				{ BackgroundColor3 = Color3.fromRGB(40, 46, 72) })
			c.Parent = g
			if r.Icon then
				local icon = kit.ArtImage(r.Icon, { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0),
					Size = UDim2.fromOffset(L.CardIcon, L.CardIcon), ZIndex = 3 })
				if icon then icon.Parent = c end
			end
			local x = r.Icon and (L.CardIcon + 10) or 8
			label(c, r.Value, L.Size.Body, colorOf("Text"), { Name = "Value", Position = UDim2.fromOffset(x, 2),
				Size = UDim2.new(1, -(x + 4), 0.55, 0), TextWrapped = false, ZIndex = 3, Style = "Number" })
			label(c, r.Label, L.Size.Small, colorOf("Sub"), { Name = "Label", Position = UDim2.new(0, x, 0.55, -2),
				Size = UDim2.new(1, -(x + 4), 0.45, 0), TextWrapped = false, ZIndex = 3 })
			continue
		elseif r.Kind == "Chip" then
			local g = grid("Chip")
			local c = kit.ArtFrame("Chip", { Name = "Chip_" .. r.Id, LayoutOrder = #g:GetChildren() },
				{ BackgroundColor3 = Color3.fromRGB(40, 46, 72) })
			c.Parent = g
			label(c, r.Text, L.Size.Small, colorOf("Text"), { Name = "Text", Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = 3 })
			continue
		end
		group, groupKind = nil, nil
		order += 1
		if r.Kind == "StatPanel" then
			CharacterUI.DrawPanel(frame, r.Panel, order)
			continue
		elseif r.Kind == "HuntBar" then
			CharacterUI.DrawHunt(frame, r.Bar, order)
			continue
		end
		if r.Kind == "Head" then
			label(frame, r.Text, L.Size.Head, colorOf("Gold"), { Name = "Head_" .. r.Id, Size = UDim2.new(1, -8, 0, L.Size.Head + 14),
				TextWrapped = false, TextYAlignment = Enum.TextYAlignment.Bottom, LayoutOrder = order })
		elseif r.Kind == "Row" then
			local f = Instance.new("Frame")
			f.Name = "Stat_" .. r.Id
			f.BackgroundTransparency = 1
			f.Size = UDim2.new(1, -8, 0, L.StatH)
			f.LayoutOrder = order
			f.Parent = frame
			label(f, r.Label, L.Size.Body, colorOf("Sub"), { Name = "Label", Size = UDim2.new(0, L.StatLabelW, 1, 0), TextWrapped = false })
			label(f, r.Value, L.Size.Body, colorOf("Text"), { Name = "Value", Position = UDim2.fromOffset(L.StatLabelW + 8, 0),
				Size = UDim2.new(1, -(L.StatLabelW + 8), 1, 0), TextWrapped = false })
		else
			label(frame, r.Text, L.Size.Body, colorOf("Sub"), { Name = "Line" .. order, Size = UDim2.new(1, -8, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order })
		end
	end
end

-- 최종 검수 10/15: the point panel - a head, the free points with [Auto] and [Reset], then a row per stat: its name,
-- points · bonus, [+] [+5] and what one more point gives (Power A → B); every press goes through CharacterUI.StatAction
function CharacterUI.DrawPanel(frame, p, order)
	local kit = VIEW.Kit
	local W = type(Config.Stats) == "table" and type(Config.Stats.Text) == "table" and Config.Stats.Text or {}
	local box = Instance.new("Frame")
	box.Name = "StatPanel"
	box.BackgroundTransparency = 1
	box.Size = UDim2.new(1, -8, 0, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.LayoutOrder = order
	box.Parent = frame
	listLayout(box, 4, false)
	label(box, tx(W, "Head"), L.Size.Head, colorOf("Gold"), { Name = "Head", Size = UDim2.new(1, 0, 0, L.Size.Head + 10), TextWrapped = false,
		LayoutOrder = 1 })
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.BackgroundTransparency = 1
	top.Size = UDim2.new(1, 0, 0, L.StatBtnH)
	top.LayoutOrder = 2
	top.Parent = box
	label(top, tx(W, "Free", p.Free), L.Size.Body, colorOf(p.Free > 0 and "Gold" or "Sub"), { Name = "Free",
		Size = UDim2.new(1, -(2 * L.StatBtnW + 12), 1, 0), TextWrapped = false })
	if kit and type(kit.Button) == "function" then
		local auto = kit.Button(top, p.Auto and tx(W, "AutoOn") or tx(W, "AutoOff"), kit.Palette.Button, UDim2.fromOffset(L.StatBtnW, L.StatBtnH),
			function() CharacterUI.StatAction("auto", not p.Auto) end)
		auto.Name = "Auto"
		auto.AnchorPoint, auto.Position = Vector2.new(1, 0), UDim2.new(1, -(L.StatBtnW + 6), 0, 0)
		local reset = kit.Button(top, tx(W, "Reset"), kit.Palette.Button, UDim2.fromOffset(L.StatBtnW, L.StatBtnH),
			function() CharacterUI.StatAction("reset") end)
		reset.Name = "Reset"
		reset.AnchorPoint, reset.Position = Vector2.new(1, 0), UDim2.fromScale(1, 0)
		if type(kit.SetEnabled) == "function" then pcall(kit.SetEnabled, reset, p.CanReset) end
	end
	for i, r in p.Rows do
		local f = Instance.new("Frame")
		f.Name = "Stat_" .. r.Letter
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, 0, 0, L.StatBtnH + (r.Next and L.Size.Small + 4 or 0))
		f.LayoutOrder = 2 + i
		f.Parent = box
		label(f, r.Name, L.Size.Body, colorOf("Text"), { Name = "Name", Size = UDim2.new(0, L.StatNameW, 0, L.StatBtnH), TextWrapped = false })
		label(f, r.Line, L.Size.Body, colorOf("Sub"), { Name = "Line", Position = UDim2.fromOffset(L.StatNameW, 0),
			Size = UDim2.new(1, -(L.StatNameW + 2 * L.StatPlusW + 12), 0, L.StatBtnH), TextWrapped = false })
		if r.Next then
			label(f, r.Next, L.Size.Small, colorOf("Sub"), { Name = "Next", Position = UDim2.fromOffset(L.StatNameW, L.StatBtnH),
				Size = UDim2.new(1, -L.StatNameW, 0, L.Size.Small + 4), TextWrapped = false })
		end
		if kit and type(kit.Button) == "function" then
			for j, b in { { "add", "Plus", r.CanAdd }, { "add5", "Plus5", r.CanAdd5 } } do
				local btn = kit.Button(f, tx(W, b[2]), kit.Palette.Free, UDim2.fromOffset(L.StatPlusW, L.StatBtnH),
					function() CharacterUI.StatAction(b[1], r.Letter) end)
				btn.Name = b[2]
				btn.AnchorPoint, btn.Position = Vector2.new(1, 0), UDim2.new(1, j == 1 and -(L.StatPlusW + 6) or 0, 0, 0)
				if type(kit.SetEnabled) == "function" then pcall(kit.SetEnabled, btn, b[3]) end
			end
		end
	end
end

-- 최종 검수 10/15: the hunting fame bar - its words, a thin bar (the share to the next point), 'have / per'
function CharacterUI.DrawHunt(frame, b, order)
	local f = Instance.new("Frame")
	f.Name = "HuntBar"
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, -8, 0, L.StatH + L.HuntBarH + 4)
	f.LayoutOrder = order
	f.Parent = frame
	label(f, b.Label, L.Size.Body, colorOf("Sub"), { Name = "Label", Size = UDim2.new(0.6, 0, 0, L.StatH), TextWrapped = false })
	label(f, b.Value, L.Size.Body, colorOf("Text"), { Name = "Value", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.4, 0, 0, L.StatH), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, Style = "Number" })
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = Color3.fromRGB(40, 46, 72)
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(0, L.StatH + 2)
	track.Size = UDim2.new(1, 0, 0, L.HuntBarH)
	track.Parent = f
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = colorOf("Gold")
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(math.clamp(b.Frac, 0, 1), 1)
	fill.Parent = track
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(0.5, 0)
	c2.Parent = fill
end

local function paintTabs()
	local kit = VIEW.Kit
	if not (kit and VIEW.Tabs) then return end
	for _, id in L.Tabs do
		local b = VIEW.Tabs[id]
		if b then
			local on = S.Tab == id
			kit.Paint(b, on and kit.Theme.Gold or kit.Palette.Button, on and kit.Palette.DarkText or kit.Theme.Text)
		end
	end
end

-- draws what changed (force = all): the left column, the gear cells, the titles, the open list / the stats tab
local function refresh(force)
	local kit = VIEW.Kit
	if not (kit and VIEW.Left and VIEW.EquipFrame) then return end
	if force then VIEW.Sigs = {} end
	checkPending()
	local ctx = context()
	local sigs = VIEW.Sigs
	local sig = table.concat({ ctx.CombatPower, ctx.Level, ctx.Class, ctx.Faction, tostring(attr("Nickname", "")),
		tostring(ctx.Attack), tostring(ctx.Health), tostring(S.Why), tostring(ctx.Honor), tostring(ctx.Infamy), tostring(ctx.Sel),
		tostring(ctx.Owned) }, "|")
	if sigs.Left ~= sig then
		sigs.Left = sig
		drawLeft(VIEW.Left, ctx)
	end
	-- 최종 검수 10/13 (ref_rpg_ui #3): a new look copies the 3D body again (the first draw is Mount's own)
	sig = table.concat({ tostring(attr("WeaponTier")), tostring(ctx.Faction), tostring(ctx.Class), tostring(attr("SizeMult")) }, "|")
	if sigs.Body ~= sig then
		local first = sigs.Body == nil
		sigs.Body = sig
		local hp = preview()
		if hp and VIEW.Body and not first and type(hp.Refresh) == "function" then pcall(hp.Refresh) end
	end
	local weapons = CharacterUI.Weapons(ctx)
	if not (gearModule() or S.GearBuilt) then -- the fallback cells (GearSlots draws its own)
		local data = { Pet = CharacterUI.PetState(petRows()) }
		for _, r in weapons do
			if r.Equipped then data.Worn = r end
		end
		local pet = data.Pet
		sig = table.concat({ data.Worn and (data.Worn.Tier .. ":" .. data.Worn.Plus) or "-",
			pet and (pet.Count .. ":" .. (pet.Equipped and (tostring(pet.Equipped.Species) .. tostring(pet.Equipped.Lv)) or "-")) or "-" }, "|")
		if sigs.Slots ~= sig then
			sigs.Slots = sig
			drawSlots(VIEW.EquipFrame, data)
		end
	end
	local titles = CharacterUI.Titles(ctx)
	local parts = {}
	for _, t in titles do table.insert(parts, t.Id .. (t.Current and "*" or "")) end
	sig = table.concat(parts, ",")
	if sigs.Titles ~= sig then
		sigs.Titles = sig
		drawTitles(VIEW.Titles, titles)
	end
	if S.View == "Weapons" and S.Tab == "Gear" then
		parts = { inCombat() and "c" or "", S.Pending and (S.Pending.Answered and "a" or "p") or "", tostring(ctx.PowerNow) }
		for _, r in weapons do
			table.insert(parts, table.concat({ r.Tier, r.Plus, tostring(r.Equipped), tostring(r.Usable), tostring(r.PowerWith) }, ":"))
		end
		sig = table.concat(parts, "|")
		if sigs.Weapons ~= sig then
			sigs.Weapons = sig
			local y = VIEW.WeaponsView.CanvasPosition.Y
			drawWeapons(VIEW.WeaponsView, weapons, ctx)
			VIEW.WeaponsView.CanvasPosition = Vector2.new(0, y)
		end
	end
	if S.Tab == "Stats" then
		local rows = CharacterUI.StatRows(ctx)
		parts = {}
		for _, r in rows do table.insert(parts, tostring(r.Text) .. "=" .. tostring(r.Value)) end
		sig = table.concat(parts, "|")
		if sigs.Stats ~= sig then
			sigs.Stats = sig
			local y = VIEW.StatsPage.CanvasPosition.Y
			drawStats(VIEW.StatsPage, rows)
			VIEW.StatsPage.CanvasPosition = Vector2.new(0, y)
		end
	end
end

-- everything again (force = nil / true) or only what changed (false)
function CharacterUI.Refresh(force)
	if force == nil then force = true end
	refresh(force)
end

function CharacterUI.ShowTab(id)
	if not table.find(L.Tabs, id) then return end
	S.Tab = id
	if VIEW.GearPage then VIEW.GearPage.Visible = id == "Gear" end
	if VIEW.StatsPage then VIEW.StatsPage.Visible = id == "Stats" end
	if VIEW.Sigs then VIEW.Sigs.Stats, VIEW.Sigs.Weapons = nil, nil end
	paintTabs()
	refresh(false)
end

---------------------------------------------------------------------------------------------------- the window
-- the EquipSlots frame: made once and kept (Cleanup takes it out before Panels clears the window). A frame that cannot be
-- put back (destroyed anyway) is made again - and its gear cells are built again
local function placeEquipSlots(parent)
	local f = S.Equip
	if f ~= nil and not pcall(function() f.Parent = parent end) then f = nil end
	if f == nil then
		f = Instance.new("Frame")
		f.Name = "EquipSlots"
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromOffset(L.FrameW, L.FrameH)
		f.Parent = parent
		S.Equip, S.GearBuilt, S.Drawn = f, false, {}
	end
	f.Position = UDim2.fromOffset(0, 0)
	return f
end

-- the EquipSlots frame's size in du (what GearSlots set, else the 3 x 3 default)
local function frameSize(frame)
	local ok, w, h = pcall(function() return frame.Size.X.Offset, frame.Size.Y.Offset end)
	w, h = ok and num(w, 0) or 0, ok and num(h, 0) or 0
	if w <= 0 or h <= 0 then return L.FrameW, L.FrameH end
	return w, h
end

-- lays the right column out around the frame's size: the title list moves beside the frame (a narrower frame = it moves
-- left, a taller one stays put: the page scrolls). Safe while the window is closed
function CharacterUI.Relayout()
	local frame, titles = VIEW.EquipFrame, VIEW.Titles
	if not (frame and titles) then return end
	local w, h = frameSize(frame)
	titles.Position = UDim2.fromOffset(w + L.TitleGap, 0)
	local body = VIEW.Body
	if body then
		pcall(function()
			body.Position = UDim2.fromOffset(0, h + L.BodyGap)
			body.Size = UDim2.fromOffset(w, L.BodyH)
		end)
	end
end

-- GearSlots (게임성 개발 4): Build once with the frame, Refresh on every open; the module may be missing
local function hookGear(frame, afterDraw)
	local g = gearModule()
	if not g then return end
	if not S.GearBuilt then
		S.GearBuilt = true
		clearFallback() -- it draws every cell itself
		local ok, err = pcall(g.Build, frame, { Refresh = function() CharacterUI.Relayout() end })
		if not ok then
			Util.Warn(TAG, "GearSlots.Build failed: " .. tostring(err))
			S.GearBuilt, S.GearOff = false, true -- no GearSlots after all: whatever it drew goes, the fallback is drawn
			pcall(function()
				for _, ch in frame:GetChildren() do ch:Destroy() end
			end)
			return
		end
	end
	if afterDraw and type(g.Refresh) == "function" then
		local ok, err = pcall(g.Refresh)
		if not ok then Util.Warn(TAG, "GearSlots.Refresh failed: " .. tostring(err)) end
	end
end

local function build(parent, kit, arg)
	VIEW = { Kit = kit, Parent = parent, Tabs = {}, Sigs = {} }
	S.Tab = (type(arg) == "table" and table.find(L.Tabs, arg.Tab)) and arg.Tab or "Gear"
	S.View = "Slots"
	-- tabs (the Panels capsules, gold = open: the same look as the bag's)
	local bar = Instance.new("Frame")
	bar.Name = "Tabs"
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, 0, 0, L.TabH)
	local bl = Instance.new("UIListLayout")
	bl.FillDirection = Enum.FillDirection.Horizontal
	bl.SortOrder = Enum.SortOrder.LayoutOrder
	bl.Padding = UDim.new(0, 6)
	bl.Parent = bar
	bar.Parent = parent
	local n = #L.Tabs
	for i, id in L.Tabs do
		local b = kit.Button(bar, tx(TXT.Tabs, id), kit.Palette.Button, UDim2.new(1 / n, -6 * (n - 1) / n, 1, 0), function()
			CharacterUI.ShowTab(id)
		end)
		b.Name = "Tab_" .. id
		b.LayoutOrder = i
		VIEW.Tabs[id] = b
	end
	local pages = Instance.new("Frame")
	pages.Name = "Pages"
	pages.BackgroundTransparency = 1
	pages.Position = UDim2.fromOffset(0, L.TabH + L.Gap)
	pages.Size = UDim2.new(1, 0, 1, -(L.TabH + L.Gap))
	pages.Parent = parent
	-- [Gear]: left = headshot + power, right = the gear cells + titles, or the weapon list
	local gear = Instance.new("Frame")
	gear.Name = "GearPage"
	gear.BackgroundTransparency = 1
	gear.Size = UDim2.fromScale(1, 1)
	gear.Parent = pages
	-- A23-145 (phone photos 10/13): a phone's window ends under the title ribbon -> the power, its parts and the rank bar
	-- were cut off; the column scrolls like the right one (a PC window shows it whole, no bar)
	local left = scroller(gear, "Left")
	left.Size = UDim2.new(0, L.LeftW, 1, 0)
	left.ScrollBarThickness = L.LeftBar
	local right = Instance.new("Frame")
	right.Name = "Right"
	right.BackgroundTransparency = 1
	right.Position = UDim2.fromOffset(L.LeftW + L.Split, 0)
	right.Size = UDim2.new(1, -(L.LeftW + L.Split), 1, 0)
	right.Parent = gear
	local slotsView = scroller(right, "SlotsView")
	local weaponsView = scroller(right, "WeaponsView")
	weaponsView.Visible = false
	local equip = placeEquipSlots(slotsView)
	local titles = Instance.new("Frame")
	titles.Name = "Titles"
	titles.BackgroundTransparency = 1
	titles.Position = UDim2.fromOffset(L.FrameW + L.TitleGap, 0)
	titles.Size = UDim2.new(0, L.TitleW, 0, 0)
	titles.AutomaticSize = Enum.AutomaticSize.Y
	titles.Parent = slotsView
	local stats = scroller(pages, "StatsPage")
	stats.Visible = false
	VIEW.GearPage, VIEW.Left, VIEW.SlotsView, VIEW.WeaponsView, VIEW.EquipFrame, VIEW.Titles, VIEW.StatsPage =
		gear, left, slotsView, weaponsView, equip, titles, stats
	-- 최종 검수 10/13 (ref_rpg_ui #3): my 3D body (weapon, halo / horns) under the gear cells; drag it to turn it
	local hp = preview()
	if hp then
		local ok, body = pcall(hp.Mount, slotsView, UDim2.fromOffset(L.FrameW, L.BodyH))
		if ok then VIEW.Body = body else Util.Warn(TAG, "HeroPreview.Mount failed: " .. tostring(body)) end
	end
	hookGear(equip, false) -- Build (the first time) before the cells are drawn
	CharacterUI.Relayout() -- the frame may be another size than the default (GearSlots resized it)
	-- data changes redraw in place (Rebuild = false: no full window rebuild)
	kit.OnAttr(function(name)
		if CharacterUI.Watch[name] then
			if VIEW.Queued then return end
			VIEW.Queued = true
			task.defer(function()
				VIEW.Queued = false
				if VIEW.Kit == kit then refresh(false) end
			end)
		end
	end)
	CharacterUI.ShowTab(S.Tab)
	refresh(true)
	hookGear(equip, true) -- Refresh on every open
	-- Panels' 0.25 s update: the humanoid's numbers, the pending equip, the pets list, a revenge timer
	return function()
		if VIEW.Kit ~= kit then return end
		refresh(false)
	end
end

local function cleanup()
	local hp = preview()
	if hp and type(hp.Unmount) == "function" then pcall(hp.Unmount) end
	local f = S.Equip
	if f then pcall(function() f.Parent = nil end) end -- Panels clears the window's children next: keep the gear frame
	VIEW = {}
end

-- 최종 검수 10/13 (ref_rpg_ui #7): is there an owned weapon I can wear now that raises my power? (HUD's Hero / Bag tile
-- dot, no words). Pure on rows (CharacterUI.Weapons); BetterWeapon() reads mine from the attributes
-- 최종 검수 10/13 (API review): state = { Dead, NoClass, Faction } - the server's refusals EquipState dims (dead, no class
-- yet, a side weapon without a side) light no dot either
function CharacterUI.HasBetter(rows, state)
	state = type(state) == "table" and state or {}
	if state.Dead or state.NoClass then return false end
	for _, r in type(rows) == "table" and rows or {} do
		if not r.Equipped and r.Usable and not (r.NeedSide and state.Faction == "None")
			and type(r.PowerNow) == "number" and type(r.PowerWith) == "number" and r.PowerWith > r.PowerNow then
			return true
		end
	end
	return false
end

function CharacterUI.BetterWeapon()
	local okP, now = pcall(Config.CombatPowerOf, LocalPlayer)
	if not okP then return false end
	local ctx = { Mask = num(attr("WeaponOwnedMask"), 0), Equipped = math.floor(num(attr("WeaponTier"), 0)),
		Level = math.max(1, math.floor(num(attr("Level"), 1))), Class = attr("Class"), Faction = attr("Faction"),
		Enhance = inventoryEnhance(), EquippedPlus = num(attr("WeaponEnhance"), 0), PowerNow = now,
		Power = function(t, p) return Config.CombatPowerOf(LocalPlayer, t, p) end }
	local ok, rows = pcall(CharacterUI.Weapons, ctx)
	local okA, alive = pcall(Util.IsAlive, LocalPlayer)
	return ok and CharacterUI.HasBetter(rows, { Dead = okA and alive == false, NoClass = attr("ClassChosen") ~= true,
		Faction = attr("Faction") }) or false
end

function CharacterUI.IsReady()
	return S.Ready
end

-- opens the window (on a tab: "Gear" | "Stats")
function CharacterUI.Open(tab)
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.Open) ~= "function" then return false end
	return (pcall(panels.Open, L.Window, type(tab) == "string" and { Tab = tab } or nil))
end

function CharacterUI.Init(registry)
	C = registry
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.Register) ~= "function" then
		Util.Warn(TAG, "Panels.Register is missing; the hero window is off")
		return
	end
	S.Ready = panels.Register(L.Window, {
		Build = build,
		Title = function() return tx(TXT, "Title") end,
		FixedBody = true,
		Rebuild = false,
		Width = L.Width,
		Cleanup = cleanup,
	}) == true
end

function CharacterUI.Start() end

-- offline tests
CharacterUI._T = { TXT = TXT, L = L, S = S }

return CharacterUI
