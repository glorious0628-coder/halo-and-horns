"""A23-215 장인 2부: the deep vein run (Shared/Quests/DeepVein.luau), offline.

Three routes (DV1..DV3) take turns as run quests (def.Run = { Group "Vein", Turn, Of 3 }: outside the day's five, never Done,
data.Story.Runs.Vein counts the runs): three trail marks (Near) -> three personal Skeleton Knight guards, one at a time near the
guard spot (a Kill step's Spawn) -> the vein (Timing 3 of 5) -> one Deep Moon Shard paid NOT bound (Reward.FreeItems, LootService
source "RewardFree"). Going down sends the run back to its first mark (def.ResetOnKO); nothing is lost. Lv25, Crafting on.
Runs the CURRENT Config, Util, StoryQuestService, LootService and CombatService (the dev2_combat_world doubles for the other
services; MonsterService.SpawnPersonal / RemovePersonal recorded) with tools/fixtures/deep_vein_offline.luau and the installed
official Luau CLI. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_deep_vein.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-16/offline_dev2_deep_vein_2026-10-16.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, Suite, run
from test_unarmed_start import FILES as UNARMED_FILES, bindings as unarmed_bindings

FILES = dict(UNARMED_FILES)
FILES["DEEPVEIN_SOURCE"] = SHARED / "Quests/DeepVein.luau"
C, ST, L, DV = "CONFIG_SOURCE", "STORY_SOURCE", "LOOT_SOURCE", "DEEPVEIN_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = unarmed_bindings(sources)
    out["DEEPVEIN_SOURCE"] = sources["DEEPVEIN_SOURCE"]
    return out


MUTATIONS = [
    # API review 10/17 fixes
    ("review 1: the chain checks the turn only", ST, "st.Subs[nid] == nil and requirementsMet(player, data, nd) then", "st.Subs[nid] == nil and runTurnOk(st, nd) then"),
    ("review 1: a running run never re-checks its gate", ST, "\t\telseif st.Subs[id] and isRun(def) and not requirementsMet(player, data, def) then\n",
     "\t\telseif false then\n"),
    ("review 2: the guard pays as a knight (drops)", DV, " Pay = K.GuardPay,", ""),
    ("review 2: the guard has a knight's HP", DV, " HPMult = K.GuardHPMult ", " "),
    ("review 3: a guard spot in the Crown Pit", DV, "DV1Guard = Vector3.new(1680, 0, -190)", "DV1Guard = Vector3.new(1680, 0, -70)"),
    ("review 4: a guard beside a KO'd body", ST, "\tif not Util.IsAlive(player) then return end -- (API review 10/17", "\tif false then return end -- (API review 10/17"),
    ("review 5: the vein's minimum ignored", ST, "and os.clock() - num(p.First, p.At) >= num(step.Obj.MinSeconds)", "and true"),
    ("review 5: the minimum restarts at every open", ST, "First = (type(mine[key]) == \"table\" and mine[key].First) or os.clock() }", "First = os.clock() }"),
    # the pack
    ("no ResetOnKO", DV, "Run = { Group = \"Vein\", Turn = turn, Of = 3, Chain = true }, ResetOnKO = true,",
     "Run = { Group = \"Vein\", Turn = turn, Of = 3, Chain = true },"),
    ("no chain (back to Pip every run)", DV, "Turn = turn, Of = 3, Chain = true }", "Turn = turn, Of = 3 }"),
    ("the chain starts any route", ST, "and st.Subs[nid] == nil and requirementsMet(player, data, nd) then", "and st.Subs[nid] == nil then"),
    ("the chain never starts", ST, "\tif isRun(def) and def.Run.Chain == true then\n", "\tif false then\n"),
    ("the shard bound (Items)", DV, "Reward = { FreeItems = {", "Reward = { Items = {"),
    ("two guards", DV, "local GUARDS = 3", "local GUARDS = 2"),
    ("guards not personal", DV, "Kind = \"SkeletonKnight\", Personal = true, Count = GUARDS", "Kind = \"SkeletonKnight\", Count = GUARDS"),
    ("no Crafting gate", DV, "Level = 25, Feature = \"Crafting\" }", "Level = 25 }"),
    ("no Spawn", DV, "\t\tSpawn = { Kind = \"SkeletonKnight\", Spot = guard, Radius = 40, Pay = K.GuardPay, HPMult = K.GuardHPMult },\n", ""),
    # the engine: runs
    ("a run marked Done", ST, "\telseif isRun(def) then\n\t\tst.Runs[def.Run.Group] = math.floor(num(st.Runs[def.Run.Group])) + 1",
     "\telseif isRun(def) then\n\t\tst.Done[id] = true"),
    ("the turn never checked", ST, "\tif not runTurnOk(st, def) then return false end -- 장인 2부", "\tif false then return false end -- 장인 2부"),
    ("the turn off by one", ST, "return runs % of + 1 == math.floor(num(def.Run.Turn, 1))", "return runs % of == math.floor(num(def.Run.Turn, 1))"),
    ("Runs not kept clean", ST, "if type(k) ~= \"string\" or #k > 24 or num(v, -1) < 0 then st.Runs[k] = nil else st.Runs[k] = math.floor(v) end",
     "if false then st.Runs[k] = nil end"),
    # the engine: the guards
    ("a guard every tick", ST, "\tif type(rec) == \"table\" and rec.Alive then return end\n\tGUARD.Rec[player] = nil\n",
     "\tGUARD.Rec[player] = nil\n"),
    ("guards anywhere", ST, "\tif sp.Spot ~= nil and (spot == nil or Util.FlatDistance(root.Position, spot) > num(sp.Radius, 40)) then return end\n", ""),
    ("the guard never removed", ST, "\tif not guarding and GUARD.Rec[player] ~= nil then GUARD.Drop(player) end", "\tif false then GUARD.Drop(player) end"),
    # the engine: KO
    ("KO resets nothing", ST, "\t\tif def and def.ResetOnKO == true and", "\t\tif false and"),
    ("KO resets every quest", ST, "\t\tif def and def.ResetOnKO == true and type(tr)", "\t\tif def and type(tr)"),
    # free rewards
    ("FreeItems paid bound", ST, "grantItem(player, row.Id, row.N, row.Free and \"RewardFree\" or nil)", "grantItem(player, row.Id, row.N)"),
    ("RewardFree bound by the bag", L, "source == \"Reward\" or source == \"RewardFree\", source == \"Reward\")",
     "source == \"Reward\", source == \"Reward\" or source == \"RewardFree\")"),
    ("FreeItems not paid", ST, "\tfor _, row in type(r.FreeItems) == \"table\" and r.FreeItems or {} do\n", "\tfor _, row in {} do\n"),
]


def static() -> tuple[int, list[str]]:
    return 0, []


SUITE = Suite(
    mark="DEEP_VEIN",
    fixture=ROOT / "tools/fixtures/deep_vein_offline.luau",
    world=ROOT / "tools/fixtures/dev2_combat_world.luau",
    out=ROOT / "docs/art/verification_2026-10-16/offline_dev2_deep_vein_2026-10-16.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-215 장인 2부: Pip offers the deep vein run from Lv25 while Crafting is on: "
             "three routes take turns (def.Run: data.Story.Runs.Vein = runs done; never Done, never one of the day's five, offered "
             "again at once). Three trail marks in order (Near 12) -> three personal Skeleton Knights, one at a time, spawned "
             "(MonsterService.SpawnPersonal Near) while the player stands within 40 of the guard spot; only personal kills count -> "
             "the vein's Timing panel (3 of 5; a fail = try again) -> one Deep Moon Shard, NOT bound (Reward.FreeItems -> "
             "LootService.GrantItem source RewardFree: fits a full bag, tradeable). Going down (PlayerService.CharacterDied) puts "
             "a ResetOnKO run's current step back to 0 (its guard removed, its panel closed; marks passed stay); nothing lost.",
    limitations="The spots are temporary (StoryLandmark tags move them, a map pass places them for real); the guards' strength, "
                "the trail look and the vein prop are not checked here. Real MonsterService spawning is the personal monster code "
                "(FirstKOService uses the same call). The 1 s loop is modelled by calling Refresh by hand.",
)

if __name__ == "__main__":
    run(SUITE)
