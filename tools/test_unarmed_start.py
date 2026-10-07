"""A23-34 bare-handed start (server side): new players start with no weapon and combat power 0, every class punches
until the M1_1 blacksmith gives the class basic weapon, offline.

Runs the CURRENT Config, Util, CombatService, LootService, StoryQuestService and PvPService sources (whole modules)
plus extracts of ShopService (onUpgradeWeapon / onSellWeapon / onBlacksmithPrompt), DataService (migrate /
fillDefaults), JusticeService (GetCombatPower) and CharacterVisuals (buildWeapon) in
tools/fixtures/unarmed_offline.luau on tools/fixtures/dev2_kit.luau, with the installed official Luau CLI. No Studio,
network, DataStore or Roblox API calls; the auto-combat loop is stepped by hand. Mutations run on in-memory copies of
the sources only.

Spec: docs/SPEC_ADDENDUM.md A23-34 (user 2026-10-06) + 검수 2026-10-06: buying the wood weapon bare-handed works and
the free tier 1 does not clash with it (both orders are checked).
Usage: py tools/test_unarmed_start.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_dev2_unarmed_start_2026-10-06.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, SSS, Suite, between, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "COMBAT_SOURCE": SSS / "CombatService.luau",
    "LOOT_SOURCE": SSS / "LootService.luau",
    "STORY_SOURCE": SSS / "StoryQuestService.luau",
    "PVP_SOURCE": SSS / "PvPService.luau",
    "SHOP_SOURCE": SSS / "ShopService.luau",
    "DATA_SOURCE": SSS / "DataService.luau",
    "JUSTICE_SOURCE": SSS / "JusticeService.luau",
    "VISUALS_SOURCE": SSS / "CharacterVisuals.luau",
}
WHOLE = ("CONFIG_SOURCE", "UTIL_SOURCE", "COMBAT_SOURCE", "LOOT_SOURCE", "STORY_SOURCE", "PVP_SOURCE")


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = {k: sources[k] for k in WHOLE}
    shop = sources["SHOP_SOURCE"]
    out["SHOP_EXTRACT"] = (
        "local Config, Util, Net, S, M, BLACKSMITH, blacksmith = ...\n"
        + "".join(function_block(shop, f"local function {name}(") for name in
                  ("finite", "notifyBad", "onUpgradeWeapon", "onSellWeapon", "onBlacksmithPrompt"))
        + "\nreturn { Upgrade = onUpgradeWeapon, Sell = onSellWeapon, Prompt = onBlacksmithPrompt }\n")
    data = sources["DATA_SOURCE"]
    out["DATA_EXTRACT"] = (
        "local Config, Util = ...\nlocal TAG = \"DataService\"\n"
        + between(data, "local TUTORIAL_NEW =", "------------------------------------------------------------------ helpers")
        + function_block(data, "local function migrate(")
        + function_block(data, "local function fillDefaults(")
        + "\nreturn migrate, fillDefaults\n")
    justice = sources["JUSTICE_SOURCE"]
    out["JUSTICE_EXTRACT"] = (
        "local Config = ...\nlocal JusticeService = {}\n"
        + function_block(justice, "local function levelAndTier(")
        + function_block(justice, "function JusticeService.GetCombatPower(")
        + "\nreturn JusticeService\n")
    visuals = sources["VISUALS_SOURCE"]
    out["VISUALS_EXTRACT"] = (
        "local Config, Util, clearChild, getClass, charScale, gripCFrame, buildStaff, buildBow, buildSword, addLight, "
        "sparkle, newPiece, getFaction, mount, buildBaton = ...\n"
        + function_block(visuals, "local function attrNum(")
        + function_block(visuals, "local function buildWeapon(")
        + "\nreturn buildWeapon\n")
    return out


C, CO, L, ST, SH, D, J, V = ("CONFIG_SOURCE", "COMBAT_SOURCE", "LOOT_SOURCE", "STORY_SOURCE", "SHOP_SOURCE", "DATA_SOURCE",
                             "JUSTICE_SOURCE", "VISUALS_SOURCE")
P = "PVP_SOURCE"
REFRESH_LINE = "\tif type(story) == \"table\" and type(story.Refresh) == \"function\" then pcall(story.Refresh, player) end\n"
OPEN_LINE = "\tNet.Get(\"OpenPanel\"):FireClient(player, \"WeaponShop\")\n"

MUTATIONS = [
    # --- Config: save defaults, damage, power, best weapon, names, the punch profile
    ("new players start with tier 1 again", C, "\t\tWeaponTier = 0,\n", "\t\tWeaponTier = 1,\n"),
    ("new players own tier 1 again", C, "\t\tWeaponOwnedMask = 0, -- tier N", "\t\tWeaponOwnedMask = 1, -- tier N"),
    ("bare hands hit like tier 1", C, "if not w then return Config.Combat.Unarmed.Damage * byLevel end",
     "if not w then return Config.Weapons[1].Damage * byLevel end"),
    ("bare hands take a scroll +N", C, "if not w then return Config.Combat.Unarmed.Damage * byLevel end",
     "if not w then return Config.Combat.Unarmed.Damage * byLevel * Config.EnhanceMult(enhance) end"),
    ("punch damage 5 (the weapon feels like no upgrade)", C, "Unarmed = { Damage = 4,", "Unarmed = { Damage = 5,"),
    ("bare power not counted from 0", C,
     "\tif not (type(tier) == \"number\" and Config.Weapons[tier]) then raw -= Config.PowerOf(1, 0, 1, 0) end\n", ""),
    ("every power counted from 0 (armed numbers move)", C,
     "if not (type(tier) == \"number\" and Config.Weapons[tier]) then raw -= Config.PowerOf(1, 0, 1, 0) end",
     "raw -= Config.PowerOf(1, 0, 1, 0)"),
    ("best weapon falls back to tier 1", C, "local best, bestDamage = 0, -1", "local best, bestDamage = 1, -1"),
    ("best weapon ignores ownership", C,
     "if type(def) == \"table\" and bit32.band(mask, bit32.lshift(1, tier - 1)) ~= 0",
     "if type(def) == \"table\" and (tier == 1 or bit32.band(mask, bit32.lshift(1, tier - 1)) ~= 0)"),
    ("bare-hands name is '?'", C, "\tif tier == 0 then return Config.Text.BareHands end -- A23-34: no weapon equipped\n", ""),
    ("bare hands show the tier-1 icon", C, "\tif tier < 1 then return nil end\n", ""),
    ("bare profile = the class row", C, "local armed = type(tier) == \"number\" and Config.Weapons[tier] ~= nil",
     "local armed = true"),
    ("punch reach = the class range", C, "Splash = 0, Range = u.Range,", "Splash = 0, Range = c.Range,"),
    ("punch keeps the class multiplier", C, "AimCone = u.AimCone, Damage = 1,", "AimCone = u.AimCone, Damage = c.Damage,"),
    ("punch hits two targets", C, "Pattern = \"Multi\", Targets = 1,", "Pattern = \"Multi\", Targets = 2,"),
    ("punch interval = the class interval", C, "SwingInterval = u.Interval,", "SwingInterval = c.SwingInterval,"),
    ("shop hit count with the class multiplier", C,
     "local c = Config.AttackProfile(classId, tier, factionId) -- A23-34",
     "local c = Config.Classes[classId] or Config.Classes.Warrior -- A23-34"),
    ("M1_1 gives no weapon", C, "Speaker = \"Smith\", GiveWeapon = 1,", "Speaker = \"Smith\","),
    # --- DataService
    ("load forces tier-1 ownership again", D,
     "d.WeaponOwnedMask = weaponTier >= 1 and bit32.bor(owned, bit32.lshift(1, weaponTier - 1)) or owned",
     "d.WeaponOwnedMask = bit32.bor(owned, 1, weaponTier >= 1 and bit32.lshift(1, weaponTier - 1) or 0)"),
    ("load turns tier 0 into a corrupted tier", D, "or weaponTier < 0\n", "or weaponTier < 1\n"),
    ("a corrupted mask becomes the old starter", D, "\t\towned = 0\n\tend", "\t\towned = 1\n\tend"),
    ("a corrupted tier becomes tier 1", D, "weaponTier = Config.BestUsableWeapon(owned, d.Level)", "weaponTier = 1"),
    ("v1 / v2 saves lose their tier 1", D, "d.WeaponOwnedMask = bit32.bor(mask, 1)", "d.WeaponOwnedMask = mask"),
    ("v1 / v2 saves without a tier stay bare-handed", D, "\t\t\td.WeaponTier = 1\n", "\t\t\td.WeaponTier = 0\n"),
    # --- CombatService: the punch
    ("bare Mage pays MP for a punch", CO, "if c.Id == \"Mage\" and not w.Unarmed\n", "if c.Id == \"Mage\"\n"),
    ("punch uses the class interval", CO, "nextSwingAt[player] = now + (w.SwingInterval or 1)",
     "nextSwingAt[player] = now + (c.SwingInterval or 1)"),
    ("punch uses the class range", CO, "local range = w.Range or 10", "local range = c.Range or 10"),
    ("punch uses the class pattern", CO, "\tif w.Pattern == \"Splash\" then", "\tif c.Pattern == \"Splash\" then"),
    ("punch damage with the class multiplier", CO, "local base = CombatService.ComputeMonsterHit(player, false, w)",
     "local base = CombatService.ComputeMonsterHit(player, false)"),
    ("punch on a player keeps the ranged factor", CO, "\tlocal c = shape or cls(attacker)\n\tlocal mult = S.JusticeService",
     "\tlocal c = cls(attacker)\n\tlocal mult = S.JusticeService"),
    ("PvP punch with the class multiplier", CO, "CombatService.ComputePvPHit(player, vp, w)", "CombatService.ComputePvPHit(player, vp)"),
    ("Swing Fx without Style", CO, "\t\t\tStyle = w.Style,\n", ""),
    ("punch Fx from the bow hand", CO, "From = weaponPosition(character, c.Id, pos, w.Unarmed),",
     "From = weaponPosition(character, c.Id, pos),"),
    ("punch Fx with the class contact / flight", CO, "local motion = TUNE.MOTION.Swing[w.Style or c.Id]",
     "local motion = TUNE.MOTION.Swing[c.Id]"),
    ("auto swings at the class range (whiffs)", CO, "#monstersNear(p, pos, w.Range or 10) > 0", "#monstersNear(p, pos, range) > 0"),
    ("auto yields for the class interval", CO, "if lm and os.clock() - lm < (w.SwingInterval or 1)",
     "if lm and os.clock() - lm < (c.SwingInterval or 1)"),
    ("auto skill reach shrinks to the punch", CO,
     "local range = c.Range or 10 -- the class range: the skill Q reach", "local range = w.Range or 10 -- the class range: the skill Q reach"),
    ("hit default tier 1", CO, "local tier = numAttr(attacker, \"WeaponTier\", 0)", "local tier = numAttr(attacker, \"WeaponTier\", 1)"),
    ("punch shove at the class contact", CO, "player, w.Style) -- A15", "player) -- A15"),
    # --- ShopService
    ("shop refuses a bare-handed buyer", SH,
     "or tier < 0 or tier > maxTier then return end\n\tlocal shop = Config.WeaponShop",
     "or tier < 1 or tier > maxTier then return end\n\tlocal shop = Config.WeaponShop"),
    ("shop needs the tier-1 bit again (buy)", SH,
     "\t\tor ownedMask > validMask then return end\n\tlocal selectedBit = bit32.lshift(1, selectedTier - 1)\n\tlocal alreadyOwned",
     "\t\tor ownedMask > validMask or bit32.band(ownedMask, 1) == 0 then return end\n\tlocal selectedBit = bit32.lshift(1, selectedTier - 1)\n\tlocal alreadyOwned"),
    ("tier 1 refusal says nothing", SH, "\t\tNet.Notify(player, Config.Text.WeaponFromQuest, \"info\")\n", ""),
    ("shop sells tier 1 for 0", SH, "if selectedTier == 1 and not alreadyOwned then", "if false then"),
    ("sell refuses a bare-handed seller", SH, "or tier < 0 or tier > maxTier then return end -- A23-34: 0 = bare hands",
     "or tier < 1 or tier > maxTier then return end -- A23-34: 0 = bare hands"),
    ("shop needs the tier-1 bit again (sell)", SH,
     "\t\tor ownedMask > validMask then return end\n\tlocal selectedBit = bit32.lshift(1, selectedTier - 1)\n\tif bit32.band",
     "\t\tor ownedMask > validMask or bit32.band(ownedMask, 1) == 0 then return end\n\tlocal selectedBit = bit32.lshift(1, selectedTier - 1)\n\tif bit32.band"),
    ("selling the equipped weapon equips tier 1", SH, "Config.BestUsableWeapon(leftMask, data.Level)", "1"),
    ("sold-weapon fallback ignores the level", SH, "Config.BestUsableWeapon(leftMask, data.Level)", "Config.BestUsableWeapon(leftMask)"),
    ("sold-weapon fallback skips the level rule", SH, "Config.BestUsableWeapon(leftMask, data.Level)",
     "Config.BestUsableWeapon(leftMask, math.huge)"),
    ("the anvil never finishes M1_1", SH, REFRESH_LINE, ""),
    ("the anvil opens the shop before the gift", SH, REFRESH_LINE + OPEN_LINE, OPEN_LINE + REFRESH_LINE),
    # --- LootService
    ("the gift replaces a bought weapon", L,
     "if math.floor(num(data.WeaponTier, 0)) ~= 0 or not Config.WeaponUsable(tier, level) then return nil end",
     "if not Config.WeaponUsable(tier, level) then return nil end"),
    ("bare equip ignores the level", L,
     "if math.floor(num(data.WeaponTier, 0)) ~= 0 or not Config.WeaponUsable(tier, level) then return nil end",
     "if math.floor(num(data.WeaponTier, 0)) ~= 0 then return nil end"),
    ("power line from the new weapon's power", L, "return Config.CombatPowerOf(player, 0, 0), Config.CombatPowerOf",
     "return Config.CombatPowerOf(player, tier, 0), Config.CombatPowerOf"),
    ("the gift is paid again to a legacy save", L,
     "if not data or not validTier(tier) or owns(data, tier) then return nil end", "if not data or not validTier(tier) then return nil end"),
    ("the gift is paid again while another weapon is held", L,
     "if not data or not validTier(tier) or owns(data, tier) then return nil end",
     "if not data or not validTier(tier) or (owns(data, tier) and math.floor(num(data.WeaponTier, 0)) == tier) then return nil end"),
    ("bare-handed PvP keeps the weapon floor", CO,
     "local floor = Config.Weapons[aTier] and Config.PvP.PowerRatioMin or Config.Combat.Unarmed.PvPRatioMin",
     "local floor = Config.PvP.PowerRatioMin"),
    ("bare PvP floor as high as the weapons'", C, "AimCone = 90, PvPRatioMin = 0.4 }", "AimCone = 90, PvPRatioMin = 0.8 }"),
    ("bought-first player gets no bag line", L,
     "\t\tnotify(player, string.format(TXT.FirstWeaponBag, name), \"reward\", \"Equip\")\n", ""),
    ("a drop is not equipped bare-handed", L,
     "\tlocal before, after = equipIfBare(player, data, tier)\n\tif isJackpot then",
     "\tlocal before, after = nil, nil\n\tif isJackpot then"),
    ("bare jackpot says 'equip it in the menu'", L,
     "notify(player, before and string.format(TXT.JackpotEquip, name, formatNumber(before), formatNumber(after))\n"
     "\t\t\tor string.format(TXT.JackpotSelf, name), \"reward\", before and \"None\" or \"Equip\")",
     "notify(player, string.format(TXT.JackpotSelf, name), \"reward\", \"Equip\")"),
    ("gift saved without the attribute mirror", L,
     "ensureTables(data)\n\tS.PlayerService.SetStat(player, \"WeaponOwnedMask\", bit32.bor(math.floor(num(data.WeaponOwnedMask, 0)), "
     "bit32.lshift(1, tier - 1)))",
     "ensureTables(data)\n\tdata.WeaponOwnedMask = bit32.bor(math.floor(num(data.WeaponOwnedMask, 0)), bit32.lshift(1, tier - 1))"),
    ("a join-time gift is never noted", L, "\tif not STATE.Watching[player] then Config.NoteGained(data, nil, tier) end\n", ""),
    ("the gift is noted twice in a session", L, "if not STATE.Watching[player] then Config.NoteGained",
     "if true then Config.NoteGained"),
    ("bare first scroll tells about enhancing", L,
     "local line = math.floor(num(data.WeaponOwnedMask, 0)) == 0 and TXT.FirstScrollBare or TXT.FirstScroll",
     "local line = TXT.FirstScroll"),
    ("a level reset drops a weapon owner to bare hands", L,
     "\tif best == 0 then\n\t\t-- A23-34: a weapon owner never goes back", "\tif false then\n\t\t-- A23-34: a weapon owner never goes back"),
    ("join safety net off", L, "and story.Done.M1_1 == true then", "and false then"),
    ("debug reset keeps the starter", L, "\tmask = math.floor(num(mask, 0))\n", "\tmask = bit32.bor(math.floor(num(mask, 0)), 1)\n"),
    # --- StoryQuestService
    ("M1_1 completion never pays the weapon", ST, "if def.GiveWeapon and S.LootService", "if false and S.LootService"),
    ("weapon line before the story lines", ST,
     "\tnotify(player, def.Finish or msg, \"reward\", \"QuestDone\")\n\tif def.Finish then notify(player, msg, \"reward\", \"None\") end\n"
     "\t-- Reward.Item (e.g. Pip1's scroll)",
     "\tlocal finishLine = def.Finish or msg\n\t-- Reward.Item (e.g. Pip1's scroll)"),
    # --- JusticeService / PvPService / CharacterVisuals
    # A23-69: the CombatPower attribute, PvP's fallback and the Tab list all use Config.CombatPowerOf, which clamps the tier
    # for every power number (JusticeService's own levelAndTier now feeds only the faction sum GetPower: tools/test_stats.py)
    ("the power formula clamps bare hands to tier 1", C,
     "\t\ttier = math.clamp(math.floor(tier), 0, Config.MaxWeaponTier) -- A23-34: 0 = bare hands\n",
     "\t\ttier = math.clamp(math.floor(tier), 1, Config.MaxWeaponTier) -- A23-34: 0 = bare hands\n"),
    ("bare hands draw a weapon", V,
     "\tif Config.Weapons[math.floor(attrNum(player, \"WeaponTier\", 0))] == nil then return end\n", ""),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    tele = strip_comments(read(SSS / "TelemetryService.luau"))
    check('if num(data.WeaponOwnedMask) > 0 then Step(player, "FirstWeapon") end' in tele
          and 'watch(player, "WeaponOwnedMask", function(v) if num(v) > 0 then Step(player, "FirstWeapon") end end)' in tele,
          "Telemetry step FirstWeapon (BB38) = any weapon owned (the M1_1 gift counts)")
    player = read(SSS / "PlayerService.luau")
    config = read(SHARED / "Config.luau")
    # A23-69: the Tab list falls back to Config.CombatPowerOf, which keeps bare hands (tier 0)
    check("v = Config.CombatPowerOf(p)" in player
          and "tier = math.clamp(math.floor(tier), 0, Config.MaxWeaponTier) -- A23-34: 0 = bare hands" in config,
          "Tab list Power fallback keeps bare hands (tier 0)")
    main = read(SSS / "Main.server.luau")
    check("S.LootService.DebugReset(player, tonumber(value) or 0)" in main, "debug LootReset defaults to the bare-handed start")
    data = strip_comments(read(SSS / "DataService.luau"))
    check("bit32.bor(owned, 1" not in data, "DataService never forces the tier-1 bit at load")
    check("Version = 4," in config,
          "save Version 4 (A23-69 stat points; A23-34 was additive: older v3 records already hold their tier 1)")
    shop = strip_comments(read(SSS / "ShopService.luau"))
    check("bit32.band(ownedMask, 1) == 0" not in shop, "the shop never requires the tier-1 bit")
    combat = strip_comments(read(SSS / "CombatService.luau"))
    check('"WeaponTier", 1)' not in combat, "CombatService reads a missing WeaponTier as bare hands (0)")
    story = read(SSS / "StoryQuestService.luau")
    check("function StoryQuestService.Refresh(player)" in story, "StoryQuestService.Refresh is public (the anvil runs it)")
    quest = read(SSS / "QuestService.luau")
    check('\tif not hasFirst then S.PlayerService.SetStat(player, "BlacksmithVisited", false) end\n\tsetStep(player, TUT_DONE)' in quest,
          "the first-mission claim clears an earlier anvil visit unless tier 1 is owned (behavior: test_onboarding)")
    check("hasFirst then\n\t\ttext = auto and (TUT_MESSAGES.AutoClaimedArmed or text) or (TUT_MESSAGES.ClaimedArmed or text)" in quest
          and "hasFirstWeapon(data) and TUT_MESSAGES.VisitBlacksmithArmed or TUT_MESSAGES.VisitBlacksmith" in quest,
          "a save that owns tier 1 gets the lines without the first-weapon promise (behavior: test_onboarding)")
    return count, failures


SUITE = Suite(
    mark="UNARMED",
    fixture=ROOT / "tools/fixtures/unarmed_offline.luau",
    world=ROOT / "tools/fixtures/dev2_combat_world.luau",
    out=ROOT / "docs/art/verification_2026-10-06/offline_dev2_unarmed_start_2026-10-06.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-34 server: Config.Data.Defaults WeaponTier 0 / WeaponOwnedMask 0; v1 / v2 records get tier 1 + its bit "
             "in migrate, v3 records keep what they own, fillDefaults accepts 0 and forces no bit, a corrupted tier = "
             "Config.BestUsableWeapon (0 = bare hands). Config.WeaponDamage(0) = Combat.Unarmed.Damage (4, no +N); "
             "Config.CombatPower counts bare hands from 0 (Lv1 = 0, Lv2 = 12) and leaves armed numbers unchanged; "
             "BestUsableWeapon -> 0 when nothing owned is usable; WeaponName(0) = Text.BareHands, WeaponArtKey(0) = nil; "
             "Config.AttackProfile(class, tier, faction) = the class row armed, the shared punch bare-handed (Style "
             "Punch, 1 nearest target within 7 in a 75 deg cone, 0.8 s, class multiplier 1, not ranged, no Mage MP). "
             "CombatService.Swing / auto combat use it (Fx Swing Style = 'Punch', From = right hand, Contact 0.15, no "
             "launch / flight); skill Q stays the class skill (class range / multiplier). ShopService sells tier 2-3 to "
             "a bare-handed player, refuses tier 1 with Text.WeaponFromQuest, selling the equipped weapon equips "
             "BestUsableWeapon (0 = bare hands); the anvil prompt runs StoryQuestService.Refresh before opening the "
             "shop. M1_1 (GiveWeapon = 1) -> LootService.GrantFirstWeapon: tier 1 owned, equipped only when bare-handed "
             "(notice FirstWeapon '전투력 X → Y'), else the bag line; nothing for a save that owns it; the join safety "
             "net pays a finished M1_1 that never paid. A weapon found bare-handed is equipped when its level allows. "
             "CharacterVisuals: tier 0 = no WeaponModel. JusticeService / PvP power read tier 0.",
    limitations="Offline doubles for Players, characters (a root facing -Z and a right hand), monsters (records with a "
                "root), Net and the other services. The client side (punch animation / Fx, blacksmith and item windows "
                "with tier 0, the class card text) is the 게임성 개발 1 contract; real play is checked after the merge.",
)

if __name__ == "__main__":
    run(SUITE)
