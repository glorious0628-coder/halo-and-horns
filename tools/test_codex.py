"""A23-153 the monster codex (CodexService + save v5, 게임성 개발 2, 2026-10-13), offline.

docs/design/codex_cards_2026-10-12.md (최종 검수), screen contract docs/design/codex_cards_contract_2026-10-13.md. Every kill the
kill record counts (MonsterService.MonsterKilled, never a personal monster) of a series-1 kind (Config.Codex.Pages: the 11 beta
kinds) adds to the save's Codex[kind] = { Kills, Golden, Stage, First }; stage 1 / 100 / 1000 kills (Card / Silver / Gold Holo)
and the first golden kill (Gold Foil, never a boss) pay a small reward (Config.Codex.Reward x the kind's own XP / Gold) and send
s->c CodexUp (+ a toast); a full page gives its title; every card at stage 3 = the CodexGlow attribute (cosmetic). The owner
gets the whole codex (s->c Codex) at join and on c->s CodexOpen. Save v5: DataService.migrate fills the codex once from
KillLog.ByKind (no reward); fillDefaults repairs it (Config.SanitizeCodex). Runs the CURRENT Config, Util, CodexService,
TitleService, KillLog and chunks cut from DataService (migrate / fillDefaults) on tools/fixtures/dev2_kit.luau +
tools/fixtures/dev3_world.luau with tools/fixtures/codex_offline.luau and the installed official Luau CLI. No Studio, network,
DataStore or Roblox API calls; mutations run on in-memory copies only.

Usage: py tools/test_codex.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-13/offline_dev2_codex_2026-10-13.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "CODEX_SOURCE": SSS / "CodexService.luau",
    "TITLE_SOURCE": SSS / "TitleService.luau",
    "LOG_SOURCE": SSS / "KillLog.luau",
    "DATA_SOURCE": SSS / "DataService.luau",
}
C, X, D = "CONFIG_SOURCE", "CODEX_SOURCE", "DATA_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = {k: sources[k] for k in ("CONFIG_SOURCE", "UTIL_SOURCE", "CODEX_SOURCE", "TITLE_SOURCE", "LOG_SOURCE")}
    data = sources[D]
    out["DATA_EXTRACT"] = (
        "local Config, Util, TAG, TUTORIAL_DONE = ...\n"
        + function_block(data, "local function giveNewQuickSlots(")
        + function_block(data, "local function migrate(")
        + function_block(data, "local function fillDefaults(")
        + "\nreturn { Migrate = migrate, Fill = fillDefaults }\n")
    return out


MUTATIONS = [
    # --- config
    ("config: the version stays 4", C, "so it must refuse v6 records (CR-L3)\n\tVersion = 6,",
     "so it must refuse v6 records (CR-L3)\n\tVersion = 4,"),
    ("config: the default record stays 4", C, "\tDefaults = {\n\t\tVersion = 6,", "\tDefaults = {\n\t\tVersion = 4,"),
    ("config: no Codex default", C, "Config.Data.Defaults.Codex = {} -- save v5", "Config.Data.Defaults.CodexX = {} -- save v5"),
    ("config: Silver at 50", C, "\tSteps = { 1, 100, 1000 }, -- kills", "\tSteps = { 1, 50, 1000 }, -- kills"),
    ("service: bosses on the normal rewards", X, "\t\tlocal mults = boss and X.Reward.BossStage or X.Reward.Stage\n",
     "\t\tlocal mults = X.Reward.Stage\n"),
    ("config: a boss can be golden", C, "\treturn type(def) == \"table\" and def.Boss ~= true\n", "\treturn type(def) == \"table\"\n"),
    ("config: codex gold not earned", C, "Config.PassBoost.GoldSources.Codex = true", "Config.PassBoost.GoldSources.CodexX = true"),
    ("config: a page title not ordered", C, "for _, id in { \"SlimeScholar\", \"GoblinScholar\", \"SkeletonScholar\" } do",
     "for _, id in { \"SlimeScholar\", \"GoblinScholar\" } do"),
    ("config: the King Slime off its page", C, "Kinds = { \"Slime\", \"FlowerSlime\", \"BigSlime\", \"SlimeKing\" } },",
     "Kinds = { \"Slime\", \"FlowerSlime\", \"BigSlime\" } },"),
    # --- the repair
    ("repair: a stage taken back", C, "Stage = math.max(int(e.Stage, 3), Config.CodexStage(kind, kills)),",
     "Stage = Config.CodexStage(kind, kills),"),
    ("repair: a stage never raised", C, "Stage = math.max(int(e.Stage, 3), Config.CodexStage(kind, kills)),",
     "Stage = int(e.Stage, 3),"),
    ("repair: Golden above Kills", C, "math.min(int(e.Golden, Config.Codex.MaxKills), kills) or 0", "int(e.Golden, Config.Codex.MaxKills) or 0"),
    ("repair: a boss foil kept", C, "local golden = Config.CodexCanGold(kind) and math.min(", "local golden = true and math.min("),
    ("repair: NaN kills kept", C, "if type(v) ~= \"number\" or v ~= v or v == math.huge or v == -math.huge then return 0 end\n\t\treturn math.clamp(math.floor(v), 0, hi)",
     "if type(v) ~= \"number\" then return 0 end\n\t\treturn math.clamp(math.floor(v), 0, hi)"),
    ("repair: 0-kill rows kept", C, "\t\t\tif kills >= 1 then\n\t\t\t\tlocal golden", "\t\t\tif kills >= 0 then\n\t\t\t\tlocal golden"),
    ("repair: no kill ceiling", C, "\t\t\tlocal kills = int(e.Kills, Config.Codex.MaxKills)\n", "\t\t\tlocal kills = int(e.Kills, math.huge)\n"),
    # --- the v5 step
    ("v5 step: no fill from the kill record", D, "\t\tif Config.CodexFromKillLog then d.Codex = Config.CodexFromKillLog(d.KillLog, d.Codex) end\n", ""),
    ("v5 / v6 steps: the version stays (A23-186: the v6 step is the last)", D, "\t\td.Version = 6\n", ""),
    ("v5 step: runs on every load", D, "\tif (tonumber(d.Version) or 1) < 5 then\n", "\tif true then\n"),
    ("v5 step: no repair at load", D, "\tif Config.SanitizeCodex then d.Codex = Config.SanitizeCodex(d.Codex) end\n", ""),
    ("fill: a smaller kill record wins", C, "\t\t\telseif e.Kills < n then\n", "\t\t\telse\n"),
    ("fill: Halloween kinds too", C, "\tfor _, kind in Config.Codex.Order do\n\t\tlocal n = byKind[kind]\n",
     "\tfor kind in byKind do\n\t\tlocal n = byKind[kind]\n"),
    # --- the service
    ("service: personal monsters count", X, "if X.Enabled ~= true or type(info) ~= \"table\" or info.Personal == true then return end",
     "if X.Enabled ~= true or type(info) ~= \"table\" then return end"),
    ("service: the switch ignored", X, "if X.Enabled ~= true or type(info) ~= \"table\" or info.Personal == true then return end",
     "if type(info) ~= \"table\" or info.Personal == true then return end"),
    ("service: any monster kind", X, "if type(kind) ~= \"string\" or not X.PageOf[kind] or not Config.MonsterTypes[kind] then return end",
     "if type(kind) ~= \"string\" or not Config.MonsterTypes[kind] then return end"),
    ("service: First never set", X, "\t\te = { Kills = 0, Golden = 0, Stage = 0, First = os.time() }\n", "\t\te = { Kills = 0, Golden = 0, Stage = 0, First = 0 }\n"),
    ("service: no kill ceiling", X, "\te.Kills = math.min(X.MaxKills, e.Kills + 1)\n", "\te.Kills += 1\n"),
    ("service: one stage at most per kill", X, "\twhile e.Stage < reach and e.Stage < 3 do\n", "\tif e.Stage < reach and e.Stage < 3 then\n"),
    ("service: no golden count", X, "\t\te.Golden = math.min(e.Kills, e.Golden + 1)\n", ""),
    ("service: a foil per golden kill", X, "\t\tif e.Golden == 1 then table.insert(events, { Event = \"Golden\"",
     "\t\tif e.Golden >= 1 then table.insert(events, { Event = \"Golden\""),
    ("service: Golden from any value", X, "\tif info.Golden == true and Config.CodexCanGold(kind) then\n", "\tif info.Golden and Config.CodexCanGold(kind) then\n"),
    ("service: no reward", X, "\t\tlocal gold, xp = pay(player, kind, ev.Mult * share)\n", "\t\tlocal gold, xp = 0, 0\n"),
    ("service: the reward in pocket gold", X, "pcall(S.ProgressionService.AddBankGold, player, gold, \"Codex\")",
     "pcall(S.ProgressionService.AddCarriedGold, player, gold, \"Codex\")"),
    ("service: the golden x on the reward", X, "\tlocal gold = math.floor((tonumber(def.Gold) or 0) * mult + 0.5)\n",
     "\tlocal gold = math.floor((tonumber(def.Gold) or 0) * mult * 3 + 0.5)\n"),
    ("service: the line shows the asked amount", X, "\t\tif ok then gotGold = tonumber(got) or gold else", "\t\tif ok then gotGold = gold else"),
    ("service: no toast", X, "\tif X.ServerToast then Net.Notify(player, text, \"reward\") end\n", ""),
    ("service: the toast switch ignored", X, "\tif X.ServerToast then Net.Notify(player, text, \"reward\") end\n", "\tNet.Notify(player, text, \"reward\")\n"),
    ("service: no CodexUp", X, "\tNet.Get(\"CodexUp\"):FireClient(player, ev)\n", ""),
    ("service: '+0 XP' at the top level", X, "\t\tlocal reward = (ev.XP or 0) > 0 and string.format(", "\t\tlocal reward = true and string.format("),
    ("service: no page title", X, "\t\tlocal ok, new = pcall(S.TitleService.Grant, player, page.Title)\n", "\t\tlocal ok, new = true, false\n"),
    ("service: the page moment for an owned title", X, "\t\telseif new == true then\n", "\t\telse\n"),
    # gameplay plan 2026-10-13 1-A #7: only kinds that can appear now
    ("1-A #7: the page waits for kinds that never spawn", X,
     "\t\tif Config.CodexCounts(kind) and (type(e) ~= \"table\" or (tonumber(e.Stage) or 0) < 1) then return false end",
     "\t\tif type(e) ~= \"table\" or (tonumber(e.Stage) or 0) < 1 then return false end"),
    ("1-A #7: the glow waits for kinds that never spawn", X,
     "\t\tif Config.CodexCounts(kind) and (type(e) ~= \"table\" or (tonumber(e.Stage) or 0) < 3) then return false end",
     "\t\tif type(e) ~= \"table\" or (tonumber(e.Stage) or 0) < 3 then return false end"),
    ("1-A #7: every kind counts", C, "\treturn type(def) == \"table\" and (def.Boss == true or (tonumber(def.Count) or 0) > 0)",
     "\treturn type(def) == \"table\""),
    ("1-A #7: bosses never count", C, "\treturn type(def) == \"table\" and (def.Boss == true or (tonumber(def.Count) or 0) > 0)",
     "\treturn type(def) == \"table\" and (tonumber(def.Count) or 0) > 0"),
    ("service: a page at every new card", X, "\tif before < 1 and page and pageDone(codex, page)", "\tif before < 1 and page"),
    ("service: no glow moment", X, "\tif before < 3 and e.Stage >= 3 and allHolo(codex) then\n", "\tif false then\n"),
    ("service: the glow at any Holo", X, "\tif before < 3 and e.Stage >= 3 and allHolo(codex) then\n", "\tif before < 3 and e.Stage >= 3 then\n"),
    ("service: no attributes", X, "\tplayer:SetAttribute(X.Attr.Cards, cardsOwned(codex))\n", ""),
    ("service: the glow attribute always on", X, "\tplayer:SetAttribute(X.Attr.Glow, allHolo(codex))\n", "\tplayer:SetAttribute(X.Attr.Glow, true)\n"),
    ("service: no repair at join", X, "\tdata.Codex = Config.SanitizeCodex(data.Codex)\n", ""),
    ("service: no snapshot at join", X, "\tpublish(player, data.Codex)\n\tsend(player, data.Codex)\nend", "\tpublish(player, data.Codex)\nend"),
    ("service: no title at join", X, "\t\t\tif pageDone(data.Codex, page) and Config.TitleDefs[page.Title] then\n",
     "\t\t\tif false then\n"),
    ("service: CodexOpen without the rate limit", X, "if not S.PlayerService.IsReady(player) or not Util.RateLimit(player, \"CodexOpen\", Config.RateLimits.CodexOpen) then return end",
     "if not S.PlayerService.IsReady(player) then return end"),
    ("service: CodexOpen before ready", X, "if not S.PlayerService.IsReady(player) or not Util.RateLimit(", "if not Util.RateLimit("),
    ("debug: a reward on the kills set", X, "\t\t\tcodex[kind] = { Kills = kills, Golden = old and math.min(old.Golden, kills) or 0, Stage = Config.CodexStage(kind, kills),",
     "\t\t\tpay(player, kind, 3)\n\t\t\tcodex[kind] = { Kills = kills, Golden = old and math.min(old.Golden, kills) or 0, Stage = Config.CodexStage(kind, kills),"),
    ("service: a minor share pays the whole stage reward", X,
     "if info.Minor == true then share = math.clamp(tonumber(Config.MonsterTypes[kind].MinorShare) or 0, 0, 1) end",
     "if info.Minor == true then share = 1 end"),
    ("service: a minor kill without a MinorShare pays in full", X, "tonumber(Config.MonsterTypes[kind].MinorShare) or 0, 0, 1)",
     "tonumber(Config.MonsterTypes[kind].MinorShare) or 1, 0, 1)"),
    ("service: a minor kill not counted", X, "\tlocal kind = info.Kind\n", "\tif info.Minor == true then return end\n\tlocal kind = info.Kind\n"),
    ("service: no XP cap below the boss's level", X, "\t\tif level < capBelow then cap = math.floor(Config.XPToNext(level)) end\n", ""),
    ("service: the cap not passed", X, "pcall(S.ProgressionService.AddXP, player, xp, cap)", "pcall(S.ProgressionService.AddXP, player, xp)"),
    ("service: the cap at the cap level too", X, "if level < capBelow then cap", "if level <= capBelow then cap"),
    ("config: boss steps back to 100 / 1000", C, "\tBossSteps = { 1, 10, 30 },\n", "\tBossSteps = { 1, 100, 1000 },\n"),
    ("models: scripts kept", X, "\t\tif STRIP[d.ClassName] then\n\t\t\td:Destroy()\n", "\t\tif false then\n\t\t\td:Destroy()\n"),
    ("models: sounds kept", X, "ModuleScript = true, Sound = true, ParticleEmitter", "ModuleScript = true, ParticleEmitter"),
    ("models: parts not anchored", X, "\tpart.Anchored = true\n", ""),
    ("models: parts hit by rays", X, "\tpart.CanQuery = false\n", ""),
    ("models: a BasePart model left loose", X, "\tif copy:IsA(\"BasePart\") then still(copy) end\n", ""),
    ("models: the source's name", X, "\tcopy.Name = kind\n", ""),
    ("models: no ModelFrom", X, "\tt = type(from) == \"string\" and from ~= kind and folder:FindFirstChild(from) or nil\n", "\tt = nil\n"),
    ("models: a folder taken as a model", X, "\tif t and (t:IsA(\"Model\") or t:IsA(\"BasePart\")) then return t, nil end", "\tif t then return t, nil end"),
    ("models: one broken model stops the rest", X,
     "\t\t\tlocal ok, err = pcall(function()\n\t\t\t\tlocal src, from = templateOf(custom, kind)\n\t\t\t\tif not src then return end\n"
     "\t\t\t\tcopyOf(src, kind, from).Parent = folder\n\t\t\t\tmade += 1\n\t\t\tend)\n",
     "\t\t\tlocal ok, err = true, nil\n\t\t\tlocal src, from = templateOf(custom, kind)\n\t\t\tif src then\n"
     "\t\t\t\tcopyOf(src, kind, from).Parent = folder\n\t\t\t\tmade += 1\n\t\t\tend\n"),
    ("models: published twice", X, "\t\tif not folder:FindFirstChild(kind) then\n\t\t\tlocal ok, err", "\t\tif true then\n\t\t\tlocal ok, err"),
    ("models: no borrowed attribute", X, "\t\tcopy:SetAttribute(\"CodexFrom\", from)\n", ""),
    ("models: never published", X, "\tlocal okModels, errModels = pcall(CodexService.PublishModels)\n", "\tlocal okModels, errModels = true, nil\n"),
    ("debug: any event name", X, "if not X.PageOf[showKind] or not EVENTS[event] then return", "if not X.PageOf[showKind] then return"),
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
    names = re.compile(r'"(\w+)"')
    init_list = names.findall(strip_comments(init.group(1))) if init else []
    start_list = names.findall(strip_comments(start.group(1))) if start else []
    check(init_list.count("CodexService") == 1 and start_list.count("CodexService") == 1, "CodexService is in both lists once")
    check(start_list[-1] == "PlayerService" and start_list.index("CodexService") < start_list.index("PlayerService")
          and init_list.index("CodexService") > init_list.index("TitleService")
          and init_list.index("CodexService") > init_list.index("ProgressionService"),
          "CodexService inits after TitleService / ProgressionService and starts before PlayerService")
    check(sorted(init_list) == sorted(start_list), "every service is in both lists")
    check('key == "Codex" then' in main and "S.CodexService.Debug(player, value)" in main, "the Studio DebugCommand 'Codex'")
    net = read(SHARED / "Net.luau")
    net_names = names.findall(strip_comments(net[net.find("Net.Names = {"):net.find("Net.GameStateDefaults")]))
    check(all(net_names.count(n) == 1 for n in ("CodexOpen", "Codex", "CodexUp")), "Net.Names has CodexOpen, Codex, CodexUp once")
    codex = strip_comments(read(SSS / "CodexService.luau"))
    check("SetStat(" not in codex and "AddStat(" not in codex and "GrantItem" not in codex and "GrantLook" not in codex,
          "the codex sets no stat, grants no item and no look (gold / XP / titles only)")
    check(codex.count("AddBankGold") == 1 and codex.count("AddXP") == 1, "one gold grant (bank, 'Codex') and one XP grant")
    money = strip_comments(read(SSS / "MonetizationService.luau"))
    check("Codex" not in money, "no Robux path touches the codex (never sold)")
    config = read(SHARED / "Config.luau")
    section = config[config.find("-- A23-153 monster codex"):]
    strings = re.findall(r'"([^"\n]*)"', strip_comments(section))
    check(bool(section) and not any(re.search("[가-힣]", s) for s in strings), "the codex section's game text is English only")
    check(not re.search(r"^local ", section, re.M), "the codex section adds no top-level local (Config's 200-locals limit)")
    mirrored = re.search(r"\tMirrored = \{(.*?)\n\t\}", config, re.S)
    check(bool(mirrored) and '"Codex"' not in mirrored.group(1), "Codex is not mirrored")
    data = read(SSS / "DataService.luau")
    mig = function_block(data, "local function migrate(")
    check("< 5 then" in mig and "\t\td.Version = 5\n\tend\n" in mig and mig.find("< 5 then") > mig.find("< 4 then"),
          "DataService.migrate has the v5 step after the v4 one")
    contract = ROOT / "docs/design/codex_cards_contract_2026-10-13.md"
    check(contract.is_file() and all(k in read(contract) for k in ("CodexOpen", "CodexUp", "CodexGlow", "CodexCards", "Config.Codex.Text")),
          "the screen contract exists and names the remotes, attributes and text keys")
    return count, failures


SUITE = Suite(
    mark="CODEX",
    fixture=ROOT / "tools/fixtures/codex_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-13/offline_dev2_codex_2026-10-13.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-153: Codex[kind] = { Kills, Golden, Stage, First } for the 11 series-1 kinds (3 pages); the KillLog rule "
             "(MonsterKilled, not personal); stages at 1 / 100 / 1000 (Card / Silver / Gold Holo; bosses 1 / 10 / 30), a skipped "
             "stage paid in order; a minor share (info.Minor) counts but its stage reward is x MinorShare (0 without one); below "
             "XPCapBelowLevel the card XP is at most one level (A23-27); "
             "the first golden kill = Gold Foil (never a boss); rewards = 3 / 20 / 100 kills' worth (bosses 1 / 3 / 10, foil 5) "
             "of the kind's own XP / Gold as bank gold 'Codex' + XP; CodexUp { Event, Kind, Stage, Card, Gold, XP, Title, Page, "
             "Key, Args, Text } + a reward toast while ServerToast; a full page = its title once (silent at join); every card "
             "at stage 3 = CodexGlow; CodexCards = cards owned; snapshot Codex at join and on CodexOpen (1 s). Save v5: "
             "migrate fills the codex once from KillLog.ByKind (Golden 0, First 0, no reward); fillDefaults repairs it.",
    limitations="The card window, the 3D card and the evolve moment are 게임성 개발 1's (the contract doc); the card art is "
                "image gen 2's. The real DataStore round trip of a v4 -> v5 record is in tools/test_onboarding.py.",
)

if __name__ == "__main__":
    run(SUITE)
