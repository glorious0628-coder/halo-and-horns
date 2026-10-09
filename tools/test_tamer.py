"""A23-39 pet tamer (server side): the artisan guild's Archer is the pet tamer — the Archer numbers with a pet look,
the baby slime pet once, the one-time notice + free class change for saves from before, offline.

Runs the CURRENT Config, Util, CombatService, LootService, StoryQuestService, PetService (whole modules) plus the
ShopService / JusticeService / CharacterVisuals extracts of tools/test_unarmed_start.py on
tools/fixtures/dev2_combat_world.luau with tools/fixtures/tamer_offline.luau, with the installed official Luau CLI.
No Studio, network, DataStore or Roblox API calls. Mutations run on in-memory copies of the sources only.

Spec: docs/SPEC_ADDENDUM.md A23-39 + 검수 2026-10-06 (tamer damage = Halo archer damage, the pet once, the free change
once; bare-handed = punch rules with the pet look).
Usage: py tools/test_tamer.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_dev2_tamer_2026-10-06.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run, strip_comments
from test_unarmed_start import FILES as UNARMED_FILES, bindings as unarmed_bindings

FILES = dict(UNARMED_FILES)
FILES["PET_SOURCE"] = SSS / "PetService.luau"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = unarmed_bindings(sources)
    out["PET_SOURCE"] = sources["PET_SOURCE"]
    return out


C, CO, PE, V = "CONFIG_SOURCE", "COMBAT_SOURCE", "PET_SOURCE", "VISUALS_SOURCE"

MUTATIONS = [
    # --- PET-2: pet XP, EquipPet, the owner's list, catch-up
    ("no pet XP", PE, "\tif S.MonsterService then connect(\"MonsterService\", \"MonsterKilled\", onKilled) end -- PET-2 pet XP\n", ""),
    ("XP needs 10 a level", C, "\tXPPerLv = 15,\n", "\tXPPerLv = 10,\n"),
    ("the level never rises", PE, "\t\tp.Lv += 1\n", ""),
    ("a put-away pet still levels", PE, "\tlocal uid = pets.Equipped[1]\n\tlocal p = uid and pets.List[uid] or nil\n\tif not p then return end\n\tlocal need",
     "\tlocal uid = next(pets.List)\n\tlocal p = uid and pets.List[uid] or nil\n\tif not p then return end\n\tlocal need"),
    ("no list to the owner", PE, "\t\tNet.Get(\"PetList\"):FireClient(player, { Equipped = pets.Equipped[1] or \"\", List = list })\n", ""),
    ("cannot put it away", PE, "\tif uid == \"\" then\n\t\tpets.Equipped = {}\n", "\tif uid == \"\" then\n\t\treturn\n"),
    ("any uid equips", PE, "\t\tif not p or not KNOWN[p.Sp] then return end\n\t\tpets.Equipped = { uid }", "\t\tpets.Equipped = { uid }"),
    ("no rate limit", PE, "or not Util.RateLimit(player, \"EquipPet\", num(Config.RateLimits.EquipPet, 0.5)) then", "then"),
    ("extra arguments allowed", PE, "\tif select(\"#\", ...) ~= 1 then return end\n\tlocal uid = ...", "\tlocal uid = ..."),
    ("no catch-up", PE, "\tlocal okC, errC = pcall(catchUp, player, data) -- PET-2", "\tlocal okC, errC = true, nil -- PET-2"),
    ("catch-up without the quest", PE, "or type(st.Done) ~= \"table\" or st.Done[G.Quest] ~= true then return end", "then return end"),
    # --- PET-4: the lost baby slime for everyone
    ("no pet from the story pick", PE, "\tif S.StoryQuestService then connect(\"StoryQuestService\", \"Picked\", onStoryPicked) end -- PET-4\n", ""),
    ("any quest gives the pet", PE, "\tif type(G) ~= \"table\" or questId ~= G.Quest then return end\n", "\tif type(G) ~= \"table\" then return end\n"),
    ("the lean ignored", PE, "\tpets.List[uid] = { Sp = species, Lv = 1, XP = 0, Name = name, Lean = lean, Bound = true }",
     "\tpets.List[uid] = { Sp = species, Lv = 1, XP = 0, Name = name, Lean = \"\", Bound = true }"),
    ("a second baby slime", PE, "\tlocal have = findSpecies(pets, species)\n\tif have then\n", "\tlocal have = nil\n\tif have then\n"),
    ("an owned pet never takes the lean", PE, "\t\tif p.Lean == \"\" and lean ~= \"\" then p.Lean, changed = lean, true end\n", ""),
    ("the tamer line for everyone", PE, "(G.Text or {}).Got)", "TXT.PetGot)"),
    ("minion is Good", C, "Picks = { Care = \"Good\", Minion = \"Evil\", A = \"Good\", B = \"Evil\" },",
     "Picks = { Care = \"Good\", Minion = \"Good\", A = \"Good\", B = \"Evil\" },"),
    ("12 slimes", C, "Obj = { Type = \"Kill\", Kind = \"Slime\", Zone = \"SlimeMeadow\", Count = 8 } },\n\t\t\t\t{ Text = \"A lost baby slime!",
     "Obj = { Type = \"Kill\", Kind = \"Slime\", Zone = \"SlimeMeadow\", Count = 12 } },\n\t\t\t\t{ Text = \"A lost baby slime!"),
    # --- Config: names, the tamer test, weapons, the attack profile, the class card
    ("the artisan Archer is still the hunter", C, 'Neutral = "Pet Tamer", None = "Archer" },', 'Neutral = "Hunter", None = "Archer" },'),
    ("IsTamer ignores the faction", C, "return T ~= nil and classId == T.Class and factionId == T.Faction",
     "return T ~= nil and classId == T.Class"),
    ("IsTamer never true", C, "return T ~= nil and classId == T.Class and factionId == T.Faction", "return false"),
    ("tamer weapons keep the bow names", C,
     "local names = (Config.IsTamer(classId, factionId) and Config.WeaponNames.Tamer) -- A23-39: batons",
     "local names = (false and Config.WeaponNames.Tamer) -- A23-39: batons"),
    ("tamer weapons keep the bow icons", C,
     "if tier <= 6 and Config.IsTamer(classId, factionId) then return \"Weapon_Tamer_T\" .. tostring(tier) end",
     "if false then return \"Weapon_Tamer_T\" .. tostring(tier) end"),
    ("tamer T7 / T8 get missing baton icons", C, "if tier <= 6 and Config.IsTamer(", "if Config.IsTamer("),
    ("tamer swing without the pet look", C, "\t\ttp.Style = Config.Tamer.SwingStyle\n", ""),
    ("armed and bare tamer share one profile", C, 'local key = armed and "Armed" or "Bare"', 'local key = "Bare"'),
    ("tamer profile skipped", C, "if not Config.IsTamer(c.Id, factionId) then return p end", "if true then return p end"),
    ("tamer card = the archer card", C, "if Config.IsTamer(classId, factionId) then return Config.Tamer.Card end", ""),
    # --- CombatService
    ("tamer skill without the pet look", CO, "local style = Config.IsTamer(c.Id, fac) and Config.Tamer.SkillStyle or nil",
     "local style = nil"),
    ("Release Fx without Style", CO, "\t\tStyle = style,\n\t\tFaction = fac,\n\t\tContactDelay = motion and motion.Contact,",
     "\t\tFaction = fac,\n\t\tContactDelay = motion and motion.Contact,"),
    ("tamer skill with the arrow-rain timing", CO, "local motion = TUNE.MOTION.Release[style or c.Id]",
     "local motion = TUNE.MOTION.Release[c.Id]"),
    ("no pet headbutt contact time", CO, "\t\t\tPetHeadbutt = { Contact = 0.3 }, -- A23-39 pet tamer: the pet reaches its target and bonks it\n", ""),
    ("tamer skill shove at the class time", CO, "REACT.SHOVE_RELEASE, player, style)", "REACT.SHOVE_RELEASE, player)"),
    # --- PetService
    ("the tamer's pet is another species", PE, "return PetService.GrantPet(player, TAMER.Pet,", "return PetService.GrantPet(player, \"Nope\","),
    ("an owned pet is never re-equipped", PE, "\t\tif #pets.Equipped == 0 then\n\t\t\tpets.Equipped = { have }", "\t\tif false then\n\t\t\tpets.Equipped = { have }"),
    ("a new pet is not equipped", PE, "\tif #pets.Equipped == 0 then pets.Equipped = { uid } end\n", ""),
    ("the pet attributes are not published", PE, "\tpublish(player, data)\n\tif type(text) == \"string\" then\n", "\tif type(text) == \"string\" then\n"),
    ("no pet notice", PE, "\t\tnotify(player, text, \"reward\", \"None\") -- sound_gaps C1", "\t\tlocal _ = nil -- sound_gaps C1"),
    ("the tamer gets no notice", PE, "not quiet and TXT.PetGot or nil)", "nil)"),
    ("a non-tamer gets the pet", PE, "return data.ClassChosen == true and Config.IsTamer(data.Class, data.Faction)",
     "return data.ClassChosen == true"),
    ("the tamer before the class pick", PE, "return data.ClassChosen == true and Config.IsTamer(data.Class, data.Faction)",
     "return Config.IsTamer(data.Class, data.Faction)"),
    ("the legacy hunter gets no ticket", PE, "\t\t\tlocal ok, err = pcall(m.AddTickets, player, \"Class\", 1)\n",
     "\t\t\tlocal ok, err = true, nil\n"),
    ("the ticket at every join", PE, "\tif data.TamerNotice ~= true then\n\t\tdata.TamerNotice = true", "\tif true then\n\t\tdata.TamerNotice = true"),
    ("a new tamer still gets the old-save ticket", PE, "\tdata.TamerNotice = true\n\tPetService.GiveTamerPet(player)\nend", "\tPetService.GiveTamerPet(player)\nend"),
    ("no 'the hunter became the tamer' notice", PE,
     "\t\tnotify(player, Config.ClassChangeKeepsLevel(data.Level) and TXT.BecameFree or TXT.Became, \"reward\", \"None\")\n", ""),
    ("the ticket wording below Lv5", PE, "Config.ClassChangeKeepsLevel(data.Level) and TXT.BecameFree or TXT.Became", "TXT.Became"),
    ("no pet for the legacy tamer", PE, "TXT.BecameFree or TXT.Became, \"reward\", \"None\")\n\tend\n\tPetService.GiveTamerPet(player)",
     "TXT.BecameFree or TXT.Became, \"reward\", \"None\")\n\tend"),
    ("legacy check only for a missing flag", PE, "\tif data.TamerNotice ~= true then", "\tif data.TamerNotice == nil then"),
    ("a returning tamer's pet is not published", PE, "\tpublish(player, data)\n\tif not isTamer(player, data) then return end\n",
     "\tif not isTamer(player, data) then publish(player, data) return end\n"),
    ("pet given while not ready", PE, "\tif not S.PlayerService.IsReady(player) then return end\n\tlocal data = getData(player)\n\tif not data or not isTamer",
     "\tlocal data = getData(player)\n\tif not data or not isTamer"),
    ("an unknown species is equipped", PE, "and list[uid] and KNOWN[list[uid].Sp] then", "and list[uid] then"),
    ("a uid is reused", PE, "\tuntil pets.List[uid] == nil", "\tuntil true"),
    ("corrupted levels kept", PE, "Lv = math.clamp(math.floor(num(p.Lv, 1)), 1, LIMIT.MaxLv),", "Lv = num(p.Lv, 1),"),
    ("two pets equipped", PE, "if #equipped < 1 and type(uid)", "if #equipped < 2 and type(uid)"),
    # --- CharacterVisuals
    ("the tamer still holds a bow", V, 'local kind = (Config.IsTamer and Config.IsTamer(classId, getFaction(player))) and "Baton" or classDef.Weapon',
     "local kind = classDef.Weapon"),
    # --- PetService.PublishModels (PET-3 models for the clients)
    ("the pet models are never published", PE, "\tlocal ok, err = pcall(PetService.PublishModels)\n", "\tlocal ok, err = true, nil\n"),
    ("scripts are copied with the model", PE, "\t\t\t\t\tif SCRIPT_CLASSES[d.ClassName] then d:Destroy() end\n", ""),
    ("a model is copied again every publish", PE, "if src and not folder:FindFirstChild(species) then", "if src then"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    main = read(SSS / "Main.server.luau")
    init = main[main.index("local INIT_ORDER"):main.index("local START_ORDER")]
    start = main[main.index("local START_ORDER"):]
    start = start[:start.index("}")]
    check('"PetService"' in init and '"PetService"' in start, "PetService is in Main's INIT_ORDER and START_ORDER")
    check(start.index('"PetService"') < start.index('"PlayerService"'),
          "PetService starts before PlayerService (its PlayerReady handler is connected before the first join)")
    check((SSS / "PetService.luau").is_file(), "the PetService module exists (the lists never name a missing module)")
    pet = strip_comments(read(SSS / "PetService.luau"))
    # PET-2: exactly the owner's list (s->c PetList) and EquipPet (c->s), both named in Net
    net = read(SHARED / "Net.luau")
    check(set(re.findall(r'Net\.Get\("(\w+)"\)', pet)) == {"PetList", "EquipPet"} and pet.count("OnServerEvent") == 1
          and '"EquipPet"' in net and '"PetList"' in net, "PET-2 remotes: PetList (owner) + EquipPet, named in Net")
    config = read(SHARED / "Config.luau")
    check("Pets = { List = {}, Equipped = {}, Next = 1 }," in config and "TamerNotice = false," in config,
          "save defaults: Pets + TamerNotice (additive, Version stays 3)")
    return count, failures


SUITE = Suite(
    mark="TAMER",
    fixture=ROOT / "tools/fixtures/tamer_offline.luau",
    world=ROOT / "tools/fixtures/dev2_combat_world.luau",
    out=ROOT / "docs/art/verification_2026-10-06/offline_dev2_tamer_2026-10-06.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-39 server: Config.IsTamer(class, faction) = Neutral + Archer. Config.Classes.Archer.Names.Neutral = "
             "'펫 조련사'; Config.WeaponName = Config.WeaponNames.Tamer (조련 지휘봉 줄) and WeaponArtKey 'Weapon_Tamer_T1..6' "
             "for the tamer (T7 / T8 keep the Archer keys); Config.AttackProfile(Archer, tier, Neutral) = the Archer row "
             "(armed) or the punch (bare) with Style 'PetHeadbutt'; Config.ClassCard = Config.Tamer.Card. CombatService: "
             "Swing Fx Style PetHeadbutt (contact 0.3, no launch / flight), Release Fx Style 'PetDash' (contact 0.35), "
             "damage = a Halo archer's. PetService: data.Pets { List[uid] = { Sp, Lv, XP, Name, Lean, Bound }, "
             "Equipped = { uid }, Next } sanitized at join; attributes EquippedPet / PetLv / PetForm; a tamer (class pick, "
             "class change, faction change or a join) gets the baby slime once, equipped, Bound, with Text.PetGot; a save "
             "that was the artisan hunter before (no TamerNotice) gets Text.Became + one free Class ticket once; a tamer "
             "made during a session sets TamerNotice without a ticket. CharacterVisuals: the tamer holds a baton.",
    limitations="Offline doubles as tools/test_unarmed_start.py. The pet following its owner, the headbutt / dash "
                "animations, the class card and the bag pet row are the 게임성 개발 1 contract; real play after the merge.",
)

if __name__ == "__main__":
    run(SUITE)
