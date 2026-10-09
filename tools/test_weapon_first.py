"""A23-74 weapon first (server side) + A23-88 (no automatic move): the first mission's Forge step — [Accept] -> "Go to
Otto's Forge" on foot -> the anvil prompt hands over the class basic weapon -> "Travel to the Squishy Meadow" (the pad or
the map) -> the hunt, offline.

Runs the CURRENT QuestService (whole module, its loops stepped by hand) with the Config, Util, CombatService,
LootService, StoryQuestService and PvPService sources and the ShopService / DataService / JusticeService /
CharacterVisuals extracts of tools/test_unarmed_start.py, on tools/fixtures/dev2_combat_world.luau with
tools/fixtures/weapon_first_offline.luau, with the installed official Luau CLI. No Studio, network, DataStore or Roblox
API calls; mutations run on in-memory copies of the sources only.

Spec: docs/SPEC_ADDENDUM.md A23-74 (user 2026-10-07 "맨 손이니까 무기를 제일 먼저 줘야지 / 무기도 없는데 어케 싸우라고")
+ 검수 2026-10-07 (the Forge before the slimes, A23-34's GiveWeapon reused, old saves never left bare-handed, the 150
gold redesigned). Contract: docs/design/weapon_first_server_2026-10-07.md.
Usage: py tools/test_weapon_first.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-07/offline_dev2_weapon_first_2026-10-07.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SSS, Suite, read, run, strip_comments
from test_unarmed_start import FILES as UNARMED_FILES, bindings as unarmed_bindings

FILES = dict(UNARMED_FILES)
FILES["QUEST_SOURCE"] = SSS / "QuestService.luau"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = unarmed_bindings(sources)
    out["QUEST_SOURCE"] = sources["QUEST_SOURCE"]
    return out


C, Q, SH, D = "CONFIG_SOURCE", "QUEST_SOURCE", "SHOP_SOURCE", "DATA_SOURCE"

MUTATIONS = [
    # --- Config
    ("Config: no Forge step", C, "Steps = { Kill = 0, Guide = 1, Quest = 2, Forge = 3, Done = 99 },",
     "Steps = { Kill = 0, Guide = 1, Quest = 2, Done = 99 },"),
    ("Config: the claim line promises the first weapon again", C,
     "\t\tClaimed = \"Thanks for guarding the supply road! +%s gold. That buys a new weapon at the Forge!\",",
     "\t\tClaimed = \"Thanks for guarding the supply road! +%s gold. Get your first weapon at the Crossroads Forge.\","),
    ("Config: M1_1 pays nothing", C,
     "Big brothers always grab the biggest bite!\",\n\t\t\tReward = { Gold = 1 },", "Big brothers always grab the biggest bite!\","),
    # --- [Accept]: the Forge first for a bare-handed player
    ("accept: never the Forge", Q, "\tif STEP_FORGE and needsFirstWeapon(getData(player)) then\n", "\tif false then\n"),
    ("accept: the Forge even with the first weapon", Q, "\tif STEP_FORGE and needsFirstWeapon(getData(player)) then\n",
     "\tif STEP_FORGE then\n"),
    # 검수 2026-10-07 minor 6: one rule for [Accept] and the late gift - bare-handed AND without the first weapon
    ("needs the weapon: a held weapon ignored (only tier 1 checked)", Q,
     "return type(data) == \"table\" and not hasFirstWeapon(data) and math.floor(num(data.WeaponTier, 0)) <= 0",
     "return type(data) == \"table\" and not hasFirstWeapon(data)"),
    ("needs the weapon: tier 1 owned is not enough", Q,
     "return type(data) == \"table\" and not hasFirstWeapon(data) and math.floor(num(data.WeaponTier, 0)) <= 0",
     "return type(data) == \"table\" and math.floor(num(data.WeaponTier, 0)) <= 0"),
    # 검수 2026-10-07 minor 2: no anvil in the world = the gift at once, never stuck at the Forge step
    ("no anvil at [Accept]: stuck at the Forge step (the old rule)", Q, "\t\tif FORGE.Anvil() then\n\t\t\tsetStep(player, STEP_FORGE)\n",
     "\t\tif true then\n\t\t\tsetStep(player, STEP_FORGE)\n"),
    ("no anvil at [Accept]: no gift", Q, "\t\tFORGE.Give(player, \"first weapon (no anvil)\")\n\tend\n\tsetStep(player, STEP_GUIDE)",
     "\tend\n\tsetStep(player, STEP_GUIDE)"),
    ("no anvil at the Forge step: stuck", Q, "\t\tif not FORGE.Anvil() then\n\t\t\tFORGE.Give(player, \"first weapon (no anvil)\")\n",
     "\t\tif false then\n\t\t\tFORGE.Give(player, \"first weapon (no anvil)\")\n"),
    ("no anvil at the Forge step: moves on without the weapon", Q,
     "\t\t\tFORGE.Give(player, \"first weapon (no anvil)\")\n\t\t\tsetStep(player, STEP_GUIDE)\n", "\t\t\tsetStep(player, STEP_GUIDE)\n"),
    # --- the forge trip's landing
    # --- the forge row and its tap
    ("row: no Forge row", Q, "\telseif step == STEP_FORGE then\n\t\t-- A23-74: a tap sends RequestTutorial",
     "\telseif false then\n\t\t-- A23-74: a tap sends RequestTutorial"),
    # --- A23-88: nothing moves the player; the walker's arrival is a metric
    ("Config: the Forge text is the old one", C, "Forge = \"Go to Otto's Forge in the Crossroads\",", "Forge = \"Get your first weapon · Crossroads Forge\","),
    ("Config: the Forge text forgets the Crossroads", C, "Forge = \"Go to Otto's Forge in the Crossroads\",", "Forge = \"Go to Otto's Forge\","),
    ("Config: the travel row is the old one", C, "Travel = \"Travel to Squishy Meadow — step on the glowing travel pad (or Map → Travel)\",", "Travel = \"Free the supply road · Menu > Travel > Squishy Meadow\","),
    ("Config: the accept trip is back", C, "\tRespawnInMeadow = true,\n\tFoldOthers = true,\n", "\tRespawnInMeadow = true,\n\tFoldOthers = true,\n\tAcceptTravelSeconds = 3,\n"),
    ("Config: the forge landing is back", C, "Forge = { Near = 24 },", "Forge = { Landing = \"Anvil\", Back = 8, Lift = 4, Near = 24 },"),
    ("Config: the meadow trip delay is back", C, "Forge = { Near = 24 },", "Forge = { Near = 24, TravelDelay = 3 },"),
    ("Config: arrival within 60 studs", C, "Forge = { Near = 24 },", "Forge = { Near = 60 },"),
    ("Config: Otto no longer points to the meadow", C, "The Squishy Meadow is next.", "Now go free the supply road."),
    ("accept: the arrival clock never starts", Q, "\tFORGE.AcceptedAt[player] = os.clock()\n", ""),
    ("arrival: every tick", Q, "if from and not FORGE.Reached[player] and FORGE.Near(player) then", "if from and FORGE.Near(player) then"),
    ("arrival: from afar", Q, "if from and not FORGE.Reached[player] and FORGE.Near(player) then", "if from and not FORGE.Reached[player] then"),
    ("arrival: a saved step counts too", Q, "local from = FORGE.AcceptedAt[player]\n", "local from = FORGE.AcceptedAt[player] or os.clock()\n"),
    ("arrival: not counted", Q, "\t\t\tM.ForgeReached:Fire(player, math.max(0, os.clock() - from))\n", ""),
    ("arrival: the seconds are the clock", Q, "M.ForgeReached:Fire(player, math.max(0, os.clock() - from))", "M.ForgeReached:Fire(player, os.clock())"),
    ("gift: the mission stays at the Forge", Q, "\tsetStep(player, STEP_GUIDE)\n\treturn true", "\treturn true"),
    # --- the gift (QuestService.ForgeGift via the anvil prompt)
    ("gift at any step", Q,
     "or not player:IsA(\"Player\") or getStep(player) ~= STEP_FORGE then return false end",
     "or not player:IsA(\"Player\") then return false end"),
    ("gift without a class", Q, "\tif not data or data.ClassChosen ~= true then return false end\n\tNet.Notify(player, TUT_MESSAGES.ForgeGift",
     "\tif not data then return false end\n\tNet.Notify(player, TUT_MESSAGES.ForgeGift"),
    ("gift: no weapon", Q, "\t\tlocal ok, err = pcall(loot.GrantFirstWeapon, player, 1)\n\t\tif not ok then Util.Warn(TAG, \"GrantFirstWeapon: \"",
     "\t\tlocal ok, err = true, nil\n\t\tif not ok then Util.Warn(TAG, \"GrantFirstWeapon: \""),
    ("gift: no Otto line", Q, "\tNet.Notify(player, TUT_MESSAGES.ForgeGift or \"Take this weapon!\", \"info\")\n", ""),
    ("shop: the window opens at the gift", SH, "\t\tif ok and handled == true then return end\n", ""),
    ("shop: never asks for the gift", SH, "if type(quest) == \"table\" and type(quest.ForgeGift) == \"function\" then",
     "if false then"),
    # --- the claim: the visit cleared, the next-weapon line
    ("claim: keeps the forge visit", Q, "\tS.PlayerService.SetStat(player, \"BlacksmithVisited\", false)\n\tsetStep(player, TUT_DONE)",
     "\tsetStep(player, TUT_DONE)"),
    ("claim: 'armed' = owns the first weapon (the old rule)", Q,
     "\tlocal armed = bit32.band(math.floor(num(getData(player).WeaponOwnedMask, 0)), bit32.bnot(1)) ~= 0\n",
     "\tlocal armed = bit32.btest(math.floor(num(getData(player).WeaponOwnedMask, 0)), 1)\n"),
    # --- old saves never stay bare-handed
    ("late: no late gift", Q, "\tFORGE.LateGift(player, data, step) -- A23-74", "\t-- A23-74"),
    ("late: at the welcome / Forge step too", Q,
     "\tif step ~= STEP_GUIDE and step ~= STEP_QUEST and step ~= TUT_DONE then return end\n", ""),
    ("late: for anyone (weapon or not)", Q, "\tif not needsFirstWeapon(data) then return end\n", ""),
    ("late: every tick", Q, "\tFORGE.Late[player] = true\n", ""),
    ("late: without a class", Q, "\tif FORGE.Late[player] or data.ClassChosen ~= true then return end\n",
     "\tif FORGE.Late[player] then return end\n"),
    # --- the save
    ("save: the Forge step reset at load", D,
     "and d.TutorialStep ~= steps.Done and d.TutorialStep ~= steps.Forge then", "and d.TutorialStep ~= steps.Done then"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    shop = read(SSS / "ShopService.luau")
    check("function M.Anvil()\n\tlocal anvil = blacksmith()\n\treturn anvil\nend" in shop,
          "ShopService.Anvil = the anvil part while the weapon shop is open (blacksmith(): nil when closed)")
    data = strip_comments(read(SSS / "DataService.luau"))
    check("{ Kill = 0, Guide = 1, Quest = 2, Forge = 3, Done = 99 }" in data,
          "DataService's fallback steps keep the Forge step too")
    player = strip_comments(read(SSS / "PlayerService.luau"))
    check("(step == steps.Guide or step == steps.Quest)" in player,
          "a KO at the Forge step respawns at home (only steps 1 / 2 respawn in the meadow; behavior: test_onboarding)")
    quest = strip_comments(read(SSS / "QuestService.luau"))
    check("trip(" not in quest and "travelToMeadow" not in quest and "FORGE.Move" not in quest and "FORGE.Request" not in quest
          and "MoveLockUntil" not in quest, "A23-88: QuestService has no trip, no forced move, no lock left")
    check("ZoneService.Travel" not in quest, "QuestService never calls ZoneService.Travel any more (nothing moves the player by itself)")
    tele = strip_comments(read(SSS / "TelemetryService.luau"))
    check("local function pastMeadow(v) return v == tutSteps.Quest or v == tutSteps.Done end" in tele,
          "the funnel's MeadowArrive never counts the Forge step (behavior: test_metrics)")
    return count, failures


SUITE = Suite(
    mark="WEAPON_FIRST",
    fixture=ROOT / "tools/fixtures/weapon_first_offline.luau",
    world=ROOT / "tools/fixtures/dev2_combat_world.luau",
    out=ROOT / "docs/art/verification_2026-10-07/offline_dev2_weapon_first_2026-10-07.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-74 + A23-88 server: Config.Tutorial.Steps.Forge = 3. [Accept] (step 0, no tier 1 owned) -> step 3 with "
             "NO automatic trip (no Fx Travel, no lock, nobody moved; Config.Tutorial.Forge = { Near = 24 } only); a save "
             "owning a weapon -> step 1, no trip. Step 3 row 'Go to Otto's Forge' (Pinned, ShortName 'To the Forge', not "
             "claimable); the walker's first arrival within 24 studs of the anvil fires QuestService.ForgeReached(player, "
             "seconds since [I'm In!]) once (TelemetryService: Custom ForgeWalk) - only for a walk begun this session; "
             "RequestTutorial at step 3 does nothing; meadow kills before the gift count nothing. The anvil prompt at step 3 "
             "(ShopService -> QuestService.ForgeGift): Otto's line ('The Squishy Meadow is next.'), "
             "LootService.GrantFirstWeapon (tier 1 equipped, 'Power 0 -> N'), step 1 'Travel to Squishy Meadow - step on the "
             "glowing travel pad (or Map -> Travel)' (ShortName 'To the meadow'), no weapon window, no automatic trip; any "
             "arrival in the meadow (the pad, Map -> Travel, a walk) starts the hunt (step 2). The claim always clears "
             "BlacksmithVisited (M1_1 = a new visit: Otto's lines, Gold 1, then the shop where the 150 gold buy tier 2) "
             "and says Claimed (next weapon) unless a better weapon is owned (ClaimedArmed). Old saves at steps 1 / 2 / "
             "99, class chosen, bare-handed without tier 1 get the gift at the join (once a session; never at steps 0 / "
             "3, never when armed). No anvil: the gift at once. The Forge step survives a save / load.",
    limitations="Offline doubles for Players, characters, the anvil part, ZoneService (Travel / ZoneChanged) and the "
                "services the combat world stubs; StoryQuestService runs without its 1 s loop (the test calls Refresh, as "
                "the anvil does). The client side (the path light to the Forge, the glowing travel pad, the one-time speech "
                "bubble, the Stronger! moment) is game dev 1's contract; the walking time (20-40 s) and an unblocked path "
                "are checked in the live map (main Play).",
)

if __name__ == "__main__":
    run(SUITE)
