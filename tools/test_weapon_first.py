"""A23-74 weapon first (server side): the first mission's Forge step — [Accept] -> the trip to the Crossroads Forge ->
the anvil prompt hands over the class basic weapon -> the trip to the meadow -> the hunt, offline.

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
    ("Config: no meadow trip after the gift", C, "Near = 24, TravelDelay = 3 },", "Near = 24, TravelDelay = nil },"),
    ("Config: the claim line promises the first weapon again", C,
     "\t\tClaimed = \"Thanks for guarding the supply road! +%s gold. That buys a new weapon at the Forge!\",",
     "\t\tClaimed = \"Thanks for guarding the supply road! +%s gold. Get your first weapon at the Crossroads Forge.\","),
    ("Config: M1_1 pays nothing", C,
     "The King Slimes ate the most of it.\",\n\t\t\tReward = { Gold = 1 },", "The King Slimes ate the most of it.\","),
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
    ("accept: no forge trip", Q,
     "\t\t\tif not FORGE.Near(player) then trip(player, FORGE.Zone, \"Forge\", FORGE.Move) end\n\t\t\treturn\n", "\t\t\treturn\n"),
    ("accept: a trip even next to the anvil", Q,
     "\t\t\tif not FORGE.Near(player) then trip(player, FORGE.Zone, \"Forge\", FORGE.Move) end\n",
     "\t\t\ttrip(player, FORGE.Zone, \"Forge\", FORGE.Move)\n"),
    # 검수 2026-10-07 minor 2: no anvil in the world = the gift at once, never stuck at the Forge step
    ("no anvil at [Accept]: stuck at the Forge step (the old rule)", Q, "\t\tif FORGE.Anvil() then\n\t\t\tsetStep(player, STEP_FORGE)\n",
     "\t\tif true then\n\t\t\tsetStep(player, STEP_FORGE)\n"),
    ("no anvil at [Accept]: no gift", Q, "\t\tFORGE.Give(player, \"first weapon (no anvil)\")\n\tend\n\tsetStep(player, STEP_GUIDE)",
     "\tend\n\tsetStep(player, STEP_GUIDE)"),
    ("no anvil at the Forge step: stuck", Q, "\t\tif not FORGE.Anvil() then\n\t\t\tFORGE.Give(player, \"first weapon (no anvil)\")\n",
     "\t\tif false then\n\t\t\tFORGE.Give(player, \"first weapon (no anvil)\")\n"),
    ("no anvil at the Forge step: moves on without the weapon", Q,
     "\t\t\tFORGE.Give(player, \"first weapon (no anvil)\")\n\t\t\tsetStep(player, STEP_GUIDE)\n", "\t\t\tsetStep(player, STEP_GUIDE)\n"),
    ("trip: no Spot in the Fx", Q, "{ UserId = player.UserId, To = to, Spot = spot, T = wait }",
     "{ UserId = player.UserId, To = to, T = wait }"),
    # --- the forge trip's landing
    ("spot: away from the Crossroads spawn", Q, "\tlocal dx, dz = from.X - a.X, from.Z - a.Z\n",
     "\tlocal dx, dz = a.X - from.X, a.Z - from.Z\n"),
    ("spot: no lift (inside the floor)", Q, "\tlocal foot = a.Y - anvil.Size.Y / 2 + num(FORGE.Cfg.Lift, 4)\n",
     "\tlocal foot = a.Y - anvil.Size.Y / 2\n"),
    ("spot: Landing 'Spawn' ignored", Q,
     "\tlocal anvil = FORGE.Cfg.Landing == \"Anvil\" and FORGE.Anvil() or nil\n", "\tlocal anvil = FORGE.Anvil()\n"),
    ("spot: not facing the anvil", Q, "\treturn CFrame.lookAt(pos, Vector3.new(a.X, foot, a.Z))\n",
     "\treturn CFrame.lookAt(pos, Vector3.new(from.X, foot, from.Z))\n"),
    ("move: no zone travel first", Q, "\tlocal ok, moved = pcall(S.ZoneService.Travel, player, FORGE.Zone, true)\n",
     "\tlocal ok, moved = true, true\n"),
    ("move: a refused travel still lands at the anvil", Q, "\tif not ok or moved ~= true then return end\n", ""),
    ("move: a respawned character is moved", Q,
     "then return end\n\tif getStep(player) ~= STEP_FORGE or FORGE.Near(player) then return end\n\tlocal ok, moved",
     "then end\n\tif getStep(player) ~= STEP_FORGE or FORGE.Near(player) then return end\n\tlocal ok, moved"),
    ("move: after the step moved on", Q,
     "\tif getStep(player) ~= STEP_FORGE or FORGE.Near(player) then return end\n\tlocal ok, moved",
     "\tif FORGE.Near(player) then return end\n\tlocal ok, moved"),
    ("move: no teleport grace", Q,
     "\tif type(S.ZoneService.MarkTeleported) == \"function\" then pcall(S.ZoneService.MarkTeleported, player) end\n", ""),
    # --- the forge row and its tap
    ("row: no Forge row", Q, "\telseif step == STEP_FORGE then\n\t\t-- A23-74: a tap sends RequestTutorial",
     "\telseif false then\n\t\t-- A23-74: a tap sends RequestTutorial"),
    ("tap: no forge trip on RequestTutorial", Q, "\tif getStep(player) == STEP_FORGE then\n\t\tif Util.RateLimit(player, \"RequestTutorial\"",
     "\tif false then\n\t\tif Util.RateLimit(player, \"RequestTutorial\""),
    ("tap: a second trip during the fade", Q,
     "\tif num(player:GetAttribute(\"MoveLockUntil\")) > Util.Now() or FORGE.Near(player) then return end\n\ttrip(",
     "\tif FORGE.Near(player) then return end\n\ttrip("),
    ("tap: a trip next to the anvil", Q,
     "\tif num(player:GetAttribute(\"MoveLockUntil\")) > Util.Now() or FORGE.Near(player) then return end\n\ttrip(",
     "\tif num(player:GetAttribute(\"MoveLockUntil\")) > Util.Now() then return end\n\ttrip("),
    # --- the gift (QuestService.ForgeGift via the anvil prompt)
    ("gift at any step", Q,
     "or not player:IsA(\"Player\") or getStep(player) ~= STEP_FORGE then return false end",
     "or not player:IsA(\"Player\") then return false end"),
    ("gift without a class", Q, "\tif not data or data.ClassChosen ~= true then return false end\n\tNet.Notify(player, TUT_MESSAGES.ForgeGift",
     "\tif not data then return false end\n\tNet.Notify(player, TUT_MESSAGES.ForgeGift"),
    ("gift: no weapon", Q, "\t\tlocal ok, err = pcall(loot.GrantFirstWeapon, player, 1)\n\t\tif not ok then Util.Warn(TAG, \"GrantFirstWeapon: \"",
     "\t\tlocal ok, err = true, nil\n\t\tif not ok then Util.Warn(TAG, \"GrantFirstWeapon: \""),
    ("gift: no Otto line", Q, "\tNet.Notify(player, TUT_MESSAGES.ForgeGift or \"Take this weapon!\", \"info\")\n", ""),
    ("gift: the mission stays at the Forge", Q, "\tsetStep(player, STEP_GUIDE)\n\tlocal delay = tonumber(FORGE.Cfg.TravelDelay)\n",
     "\tlocal delay = tonumber(FORGE.Cfg.TravelDelay)\n"),
    ("gift: the meadow trip at once", Q, "\t\ttask.delay(delay, function()\n\t\t\tif player.Parent ~= Players or getStep(player) ~= STEP_GUIDE",
     "\t\ttask.delay(0, function()\n\t\t\tif player.Parent ~= Players or getStep(player) ~= STEP_GUIDE"),
    ("gift: no meadow trip", Q,
     "\t\t\tif num(player:GetAttribute(\"MoveLockUntil\")) > Util.Now() then return end\n\t\t\ttrip(player, TUT_ZONE, nil, travelToMeadow)\n",
     "\t\t\tif num(player:GetAttribute(\"MoveLockUntil\")) > Util.Now() then return end\n"),
    ("gift: the meadow trip after the hunt began", Q,
     "\t\t\tif player.Parent ~= Players or getStep(player) ~= STEP_GUIDE then return end\n",
     "\t\t\tif player.Parent ~= Players then return end\n"),
    ("gift: the meadow trip over a running one", Q,
     "\t\t\tif num(player:GetAttribute(\"MoveLockUntil\")) > Util.Now() then return end\n\t\t\ttrip(", "\t\t\ttrip("),
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
    check(quest.count("trip(player, TUT_ZONE, nil, travelToMeadow)") == 2 and quest.count("FORGE.Move)") == 2,
          "two meadow trips (accept with the first weapon, after the gift) and two forge trips (accept, the row's tap)")
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
    contract="A23-74 server: Config.Tutorial.Steps.Forge = 3. [Accept] (step 0, no tier 1 owned) -> step 3 + the forge "
             "trip (Fx Travel { UserId, To = 'Crossroads', Spot = 'Forge', T = 3 }, MoveLockUntil now + 4.5, 3 s later "
             "ZoneService.Travel('Crossroads', instant) then, with Forge.Landing 'Anvil', ZoneService.MarkTeleported + "
             "PivotTo Forge.Back 8 studs in front of the anvil toward the Crossroads spawn, Forge.Lift 4 above its bottom, "
             "facing it; then Fx TravelDone + lock 0; no trip within Forge.Near 24 studs; a refused travel or a new "
             "character moves nobody); a save owning tier 1 -> step 1 + the meadow trip as before. Step 3 row: Pinned, "
             "Text.Forge, ShortName 'To the Forge', not claimable; RequestTutorial at step 3 = the forge trip again (not "
             "during a fade, not next to the anvil); meadow kills before the gift count nothing. The anvil prompt at "
             "step 3 (ShopService -> QuestService.ForgeGift): Otto's ForgeGift line, LootService.GrantFirstWeapon "
             "(tier 1 equipped, 'Power 0 -> N'), step 1 (2 when standing in the meadow), no weapon window; "
             "Forge.TravelDelay 3 s later the meadow trip unless the hunt began or a trip runs. The claim always clears "
             "BlacksmithVisited (M1_1 = a new visit: Otto's lines, Gold 1, then the shop where the 150 gold buy tier 2) "
             "and says Claimed (next weapon) unless a better weapon is owned (ClaimedArmed). Old saves at steps 1 / 2 / "
             "99, class chosen, bare-handed without tier 1 get the gift at the join (once a session; never at steps 0 / "
             "3, never when armed). The Forge step survives a save / load.",
    limitations="Offline doubles for Players, characters, the anvil part, ZoneService (Travel / MarkTeleported / "
                "ZoneChanged) and the services the combat world stubs; StoryQuestService runs without its 1 s loop (the "
                "test calls Refresh, as the anvil does). The client side (the forge beam, the row's tap, the fade's "
                "place name, the Stronger! moment) is game dev 1's contract; the landing spot is checked in the live map "
                "after the merge.",
)

if __name__ == "__main__":
    run(SUITE)
