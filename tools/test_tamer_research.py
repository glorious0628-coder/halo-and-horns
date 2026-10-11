"""Pet tamer research (TamerService, 게임성 개발 3, 2026-10-12), offline.

Contract docs/design/tamer_server_2026-10-12.md §1 (crafting_market §4, A23-115): the pet tamer (the artisan Archer, class
picked) gets 1 research point for every kill it is paid for (not a MinorShare share; auto combat too) in the monster's
family (Config.MonsterFamily: every slime is Slime); stages 50 / 150 / 400 / 1000 / 2500, a new stage says so once
(key only, named families); TamerInfo at join and after changes (once a second, a new stage at once); at most 64
families, counters capped; AddSummon adds Sum; switched by Config.Features.Research. Runs the CURRENT Config, Util and
TamerService on tools/fixtures/dev2_kit.luau + tools/fixtures/dev3_world.luau with
tools/fixtures/tamer_research_offline.luau and the installed official Luau CLI. No Studio, network, DataStore or Roblox
API calls; mutations run on in-memory copies of the sources.

Usage: py tools/test_tamer_research.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-12/offline_dev3_tamer_research_2026-10-12.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "TAMER_SOURCE": SSS / "TamerService.luau",
}
C, T = "CONFIG_SOURCE", "TAMER_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # --- the table
    ("config: on by default", C, "Config.Features.Research = false\n", "Config.Features.Research = true\n"),
    ("config: stage 2 at 100", C, "\tStages = { 50, 150, 400, 1000, 2500 },", "\tStages = { 50, 100, 400, 1000, 2500 },"),
    ("config: the Prince is its own family", C, "\t\tBigSlime = \"Slime\", FlowerSlime = \"Slime\",", "\t\tFlowerSlime = \"Slime\","),
    ("config: no quest-kind fallback", C, "\tif type(fam) == \"string\" then return fam end\n\treturn Config.QuestKind(kind)\n", "\tif type(fam) == \"string\" then return fam end\n\treturn kind\n"),
    ("config: unknown kinds have a family", C, "\tif type(kind) ~= \"string\" or Config.MonsterTypes[kind] == nil then return nil end\n\tlocal fam = Config.Research.Family[kind]", "\tif type(kind) ~= \"string\" then return nil end\n\tlocal fam = Config.Research.Family[kind]"),
    ("config: stage one too early", C, "\t\tif pts >= need then stage = i else break end\n", "\t\tif pts + 1 >= need then stage = i else break end\n"),
    # --- points
    ("kill: the switch not checked", T, "\tif not on() or typeof(player) ~= \"Instance\" or not player:IsA(\"Player\") or type(info) ~= \"table\" then return end\n", "\tif typeof(player) ~= \"Instance\" or not player:IsA(\"Player\") or type(info) ~= \"table\" then return end\n"),
    ("kill: free riders count", T, "\tif info.Minor == true then return end\n\tlocal data = getData(player)\n\tif not isTamer(data) then return end\n", "\tlocal data = getData(player)\n\tif not isTamer(data) then return end\n"),
    ("kill: everyone researches", T, "\tlocal data = getData(player)\n\tif not isTamer(data) then return end\n", "\tlocal data = getData(player)\n\tif not data then return end\n"),
    ("kill: class not picked counts", T, "\treturn type(data) == \"table\" and data.ClassChosen == true and Config.IsTamer(data.Class, data.Faction)\n", "\treturn type(data) == \"table\" and Config.IsTamer(data.Class, data.Faction)\n"),
    ("kill: by kind, not family", T, "\tlocal fam = Config.MonsterFamily(info.Kind)\n", "\tlocal fam = Config.MonsterTypes[info.Kind] and info.Kind\n"),
    ("kill: no key cap", T, "\tif r.Pts[fam] == nil and count(r.Pts) >= Config.SaveV4.MaxKeys then return end\n", ""),
    ("kill: no count cap", T, "\tlocal after = math.min(Config.SaveV4.MaxCount, before + 1)\n", "\tlocal after = before + 1\n"),
    ("kill: two points", T, "\tlocal after = math.min(Config.SaveV4.MaxCount, before + 1)\n", "\tlocal after = math.min(Config.SaveV4.MaxCount, before + 2)\n"),
    ("kill: broken save not repaired", T, "\tif type(data.Research) ~= \"table\" or type(data.Research.Pts) ~= \"table\" or type(data.Research.Sum) ~= \"table\" then\n", "\tif type(data.Research) ~= \"table\" then\n"),
    # --- stages
    ("stage: no line", T, "\t\t\tlocal ok, err = pcall(Net.NotifyKey, player, \"Config.Research.Text.Stage\",\n", "\t\t\tlocal ok, err = pcall(function() end,\n"),
    ("stage: a line every kill", T, "\tif s1 > s0 then\n\t\tif type(Config.Research.Text.Names[fam]) == \"string\" then\n", "\tif s1 >= s0 then\n\t\tif type(Config.Research.Text.Names[fam]) == \"string\" then\n"),
    ("stage: unnamed families get a line", T, "\t\tif type(Config.Research.Text.Names[fam]) == \"string\" then\n", "\t\tif true then\n"),
    ("stage: no signal", T, "\t\tTamerService.StageUp:Fire(player, fam, s1)\n", ""),
    ("stage: info waits", T, "\tsendSoon(player, data, s1 > s0)\n", "\tsendSoon(player, data, false)\n"),
    # --- TamerInfo
    ("info: no info at the join", T, "\t\t\tif isTamer(data) then send(player, data) end\n", ""),
    ("info: every kill at once", T, "\tif now or not last or os.clock() - last >= gap then\n", "\tif true then\n"),
    ("info: waits never sent", T, "\t\tlocal d = getData(player)\n\t\tif d then send(player, d) end\n", ""),
    ("info: no stage list", T, "\t\t\tStages = table.clone(Config.Research.Stages) })\n", "\t\t\tStages = nil })\n"),
    # --- summons
    ("summon: Sum not counted", T, "\tr.Sum[family] = math.min(Config.SaveV4.MaxCount, math.floor(num(r.Sum[family])) + 1)\n", ""),
    ("summon: info not sent", T, "\tr.Sum[family] = math.min(Config.SaveV4.MaxCount, math.floor(num(r.Sum[family])) + 1)\n\tsendSoon(player, data, true)\n", "\tr.Sum[family] = math.min(Config.SaveV4.MaxCount, math.floor(num(r.Sum[family])) + 1)\n"),
]


def static() -> tuple[int, list[str]]:
    count, failures = 0, []

    def check(ok: bool, name: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(name)

    main = read(SSS / "Main.server.luau")
    init = re.search(r"local INIT_ORDER = \{(.*?)\n\}", main, re.S)
    start = re.search(r"local START_ORDER = \{(.*?)\n\}", main, re.S)
    ni = re.findall(r'"(\w+)"', strip_comments(init.group(1))) if init else []
    ns = re.findall(r'"(\w+)"', strip_comments(start.group(1))) if start else []
    check("TamerService" in ni and ni.index("TamerService") > ni.index("MonsterService"), "Main INIT_ORDER has TamerService")
    check("TamerService" in ns and ns.index("TamerService") < ns.index("PlayerService"), "Main START_ORDER has TamerService before PlayerService")
    net = read(SHARED / "Net.luau")
    names = re.search(r"Net\.Names = \{(.*?)\n\}", net, re.S)
    check(bool(names) and '"TamerInfo"' in strip_comments(names.group(1)), "Net.Names has TamerInfo")
    tamer = strip_comments(read(SSS / "TamerService.luau"))
    check("Net.Notify(" not in tamer and "Net.NotifyKey" in tamer, "TamerService sends notices by key only")
    check(not re.search(r"MarketplaceService|PromptPurchase|Robux", tamer), "no purchase path for research (A23-115: no Robux)")
    return count, failures


SUITE = Suite(
    mark="TAMER_RESEARCH",
    fixture=ROOT / "tools/fixtures/tamer_research_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-12/offline_dev3_tamer_research_2026-10-12.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="Tamer research (docs/design/tamer_server_2026-10-12.md §1, crafting_market §4, A23-115): switch "
             "Config.Features.Research off; the tamer (artisan Archer, class picked) gets 1 point per paid kill (not "
             "MinorShare; auto too) in Config.MonsterFamily (every slime = Slime); stages 50/150/400/1000/2500, one "
             "keyed line per new stage (named families), StageUp signal; TamerInfo { Pts, Stage, Sum, Stages } at join "
             "and after changes (once a second, a new stage / summon at once); 64 families, MaxCount; AddSummon.",
    limitations="The summon / Pet Treat recipes (CraftService) and the PetService side (SummonPet, AddPetXP, the Roll "
                "speed) come in the next chunk after 게임성 개발 2 agrees; the research window is client work.",
)

if __name__ == "__main__":
    run(SUITE)
