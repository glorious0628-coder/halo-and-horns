"""A23-75 (user 2026-10-08 "수익 상품 ... 모두"): game passes, server side, offline.

docs/design/gamepass_server_2026-10-08.md. Config.GamePasses (2x XP 199, 2x Gold 149, VIP 249; Id 0 = "Coming soon",
never asked about), Config.PassBoost (x2, the earned gold sources, the join-check retries, the supporter board),
Config.Looks (4 sold faction looks 99 each + 6 attendance-only, A23-77) and the additive save fields Looks / PassSeen.
MonetizationService (the only server user of MarketplaceService) asks Roblox at join (UserOwnsGamePassAsync, 3 tries,
waits 1 s then 2 s; when every try fails the last saved answer counts), takes PromptGamePassPurchaseFinished at once,
keeps the attributes PassXP2 / PassGold2 / PassVIP / LooksOwned / LookOn, takes c->s SetLook, unlocks attendance looks
(GrantLook) and keeps the VIP supporter board (GameState SupporterNames, a shared DataStore list). ProgressionService
doubles every XP grant and the gold of earned sources once (never in GetXPMult / GetGoldMult) and returns what was
added; every grant site shows that amount. The Studio DebugCommand "Pass" / "LookGrant" are test aids.

Runs the CURRENT Config, Util, ProgressionService and MonetizationService on tools/fixtures/dev2_kit.luau doubles with
tools/fixtures/gamepass_offline.luau and the installed official Luau CLI; every XP / gold grant in
src/ServerScriptService is checked here as source text (its source, and that the line shown uses what was added). No
Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_gamepass.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-08/offline_dev2_gamepass_2026-10-08.json
"""
from __future__ import annotations

import re
from collections import Counter

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "PROGRESSION_SOURCE": SSS / "ProgressionService.luau",
    "MONETIZATION_SOURCE": SSS / "MonetizationService.luau",
}
C, P, M = "CONFIG_SOURCE", "PROGRESSION_SOURCE", "MONETIZATION_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


# every XP / gold grant on the server: (file, call, gold source or None for XP, the line shown uses what was added)
EXPECTED = [
    ("BoardService.luau", "AddBankGold", "Quest", True),
    ("BoardService.luau", "AddXP", None, True),
    ("FactionService.luau", "AddBankGold", "SignOn", True),
    ("GooseService.luau", "AddBankGold", "Event", True),
    ("GooseService.luau", "AddXP", None, True),
    ("GrudgeService.luau", "AddBankGold", "Refund", False),
    ("GrudgeService.luau", "AddBankGold", "Refund", False),
    ("GrudgeService.luau", "AddBankGold", "Refund", False),
    ("GrudgeService.luau", "AddCarriedGold", "Plunder", False),
    ("GrudgeService.luau", "AddBankGold", "Bounty", True),
    ("KaijuService.luau", "AddBankGold", "KaijuBank", False),
    ("KaijuService.luau", "AddBankGold", "Kaiju", True),
    ("KaijuService.luau", "AddBankGold", "KaijuTransfer", False),
    ("KaijuService.luau", "AddBankGold", "Kaiju", True),
    ("LootService.luau", "AddCarriedGold", "Loot", True),
    ("LootService.luau", "AddCarriedGold", "Sale", False),
    ("Main.server.luau", "AddCarriedGold", "Other", False),
    ("ProgressionService.luau", "AddCarriedGold", "Monster", True),
    ("ProgressionService.luau", "AddXP", None, True),
    ("PvPService.luau", "AddBankGold", "Bounty", True),
    ("PvPService.luau", "AddBankGold", "Bounty", True),
    ("PvPService.luau", "AddBankGold", "Bounty", True),
    ("QuestService.luau", "AddBankGold", "Quest", True),
    ("QuestService.luau", "AddXP", None, False),  # the first mission's XP: its line names the gold only
    ("QuestService.luau", "AddBankGold", "Quest", True),
    ("QuestService.luau", "AddXP", None, True),
    ("ShopService.luau", "AddCarriedGold", "Sale", False),
    ("StoryQuestService.luau", "AddBankGold", "Quest", True),
    ("StoryQuestService.luau", "AddXP", None, True),
    ("StoryQuestService.luau", "AddBankGold", "Quest", True),
    ("WarService.luau", "AddBankGold", "War", True),
]
CALL = re.compile(r"\b(AddXP|AddCarriedGold|AddBankGold)\(|\"(AddXP|AddCarriedGold|AddBankGold)\",")


def grants() -> list[tuple[str, str, str | None, bool, str]]:
    out = []
    for path in sorted(SSS.glob("*.luau")):
        for raw in read(path).splitlines():
            line = raw.split("--", 1)[0]
            m = CALL.search(line)
            if not m or re.search(r"function\s+M\.(AddXP|AddCarriedGold|AddBankGold)\(", line):
                continue
            kind = m.group(1) or m.group(2)
            strings = re.findall(r"\"([A-Za-z]+)\"", line[m.end():])
            source = strings[-1] if kind != "AddXP" and strings else None
            shown = re.search(r"[\w\]]\s*=\s*(tonumber\()?[\w.]*\s*\(?\s*(S\.ProgressionService\.|Progression\.|M\.|call\()",
                              line) is not None
            out.append((path.name, kind, source, shown, raw.strip()))
    return out


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    found = grants()
    got = Counter((f, k, s) for f, k, s, _, _ in found)
    want = Counter((f, k, s) for f, k, s, _ in EXPECTED)
    check(got == want, f"every XP / gold grant is a known one with its source (extra {dict(got - want)}, missing {dict(want - got)})")
    shown_want = Counter((f, k, s) for f, k, s, sh in EXPECTED if sh)
    shown_got = Counter((f, k, s) for f, k, s, sh, _ in found if sh)
    check(shown_got == shown_want, f"each earned grant keeps what was added for its line (missing {dict(shown_want - shown_got)}, "
                                   f"extra {dict(shown_got - shown_want)})")
    config = read(SHARED / "Config.luau")
    boost = re.search(r"GoldSources = \{([^}]*)\}", config)
    sources = set(re.findall(r"(\w+) = true", boost.group(1))) if boost else set()
    earned = {s for f, k, s, sh in EXPECTED if s and sh}
    check(earned <= sources and not (sources & {"Sale", "Refund", "Plunder", "KaijuBank", "KaijuTransfer", "Other", "Penalty"}),
          f"the shown (earned) sources are the 2x Gold ones, never a transfer ({sorted(sources)})")
    quest = strip_comments(read(SSS / "QuestService.luau"))
    for text in ("cg, cx = payReward(player, cg, cx)", "local gotGold = payReward(player,", "paidGold += (payReward(player, g, x))",
                 "Util.FormatNumber(gotGold)), \"reward\", auto and 6 or nil", "Config.Text.QuestDone, Util.FormatNumber(gotGold)"):
        check(text in quest, f"QuestService shows what payReward / the first mission added: {text}")
    check(quest.count("g, x = payReward(player, g, x)") == 2, "QuestService: the daily claim and the vacation show what was added")
    pay = function_block(quest, "local function payReward(")
    check("return math.max(0, gold), math.max(0, xp)" in pay, "payReward returns the gold and XP added")
    kaiju = strip_comments(read(SSS / "KaijuService.luau"))
    check(re.search(r"AddBankGold\", p, taken, \"KaijuBank\"", kaiju) is not None
          and re.search(r"bonus = tonumber\(call\(\"ProgressionService\", \"AddBankGold\", p, bonus, \"Kaiju\"\)\)", kaiju) is not None
          and re.search(r"AddBankGold\", p, moved, \"KaijuTransfer\"", kaiju) is not None
          and re.search(r"mintShare = tonumber\(call\(\"ProgressionService\", \"AddBankGold\", p, mintShare, \"Kaiju\"\)\)", kaiju)
          is not None, "kaiju: the carried gold moved is never 2x, only the minted part")
    prog = strip_comments(read(SSS / "ProgressionService.luau"))
    for fn in ("function M.GetGoldMult(", "function M.GetXPMult("):
        body = function_block(prog, fn)
        check("PassMult" not in body and "HasPass" not in body, f"{fn} leaves the pass out (it is applied once, in the grant)")
    check(prog.count("* M.PassMult(player,") == 2, "the pass is applied in two places only: AddXP and boostGold")
    net = read(SHARED / "Net.luau")
    check("\"SetLook\"," in net and "SupporterNames = \"\"," in net, "Net: c->s SetLook, GameState SupporterNames")
    data = read(SSS / "DataService.luau")
    check("if Config.SanitizeLooks then d.Looks, d.PassSeen = Config.SanitizeLooks(d.Looks, d.PassSeen) end" in data,
          "DataService repairs Looks / PassSeen on load (additive, Version 3)")
    main = read(SSS / "Main.server.luau")
    studio = main.find("if game:GetService(\"RunService\"):IsStudio() then")
    pass_key = main.find("elseif key == \"Pass\" then")
    look_key = main.find("elseif key == \"LookGrant\" then")
    check(0 <= studio < pass_key and studio < look_key and "S.MonetizationService.DebugSetPass(player, k," in main,
          "DebugCommand Pass / LookGrant: Studio only")
    money = strip_comments(read(SSS / "MonetizationService.luau"))
    check(money.count("MarketplaceService.ProcessReceipt = processReceipt") == 1
          and "PromptGamePassPurchaseFinished:Connect" in money, "MonetizationService: one ProcessReceipt, the purchase signal")
    services = [p for p in SSS.glob("*.luau") if p.name != "MonetizationService.luau"]
    check(not any("UserOwnsGamePassAsync" in read(p) or "PromptGamePassPurchaseFinished" in read(p) for p in services),
          "no other server file asks Roblox about passes")
    top_locals = len(re.findall(r"^local ", read(SSS / "MonetizationService.luau"), re.M))
    check(top_locals < 190, f"MonetizationService top-level locals under the 200 limit ({top_locals})")
    for name in ("MonetizationService.luau", "ProgressionService.luau"):
        text = read(SSS / name)
        check("local x <const>" not in text and not re.search(r"\b(wait|spawn|delay)\(", re.sub(r"task\.\w+\(", "", text)),
              f"{name}: Luau rules (no <const>, task.* only)")
    return count, failures


MUTATIONS = [
    # config
    ("2x Gold for sales", C, "GoldSources = { Monster = true,", "GoldSources = { Sale = true, Monster = true,"),
    ("kills not doubled", C, "GoldSources = { Monster = true, Quest = true,", "GoldSources = { Quest = true,"),
    ("x1", C, "\tMult = 2,\n\tGoldSources", "\tMult = 1,\n\tGoldSources"),
    ("one try", C, "\tCheckTries = 3,\n", "\tCheckTries = 1,\n"),
    ("VIP price", C, "VIP = { Id = 0, Price = 249,", "VIP = { Id = 0, Price = 199,"),
    ("a sold look free", C, "HaloIce = { Faction = \"Halo\", PassId = 0, Price = 99,", "HaloIce = { Faction = \"Halo\", PassId = 0, Price = 0,"),
    ("look order off", C, "\t\tif oa ~= ob then return oa < ob end\n", "\t\tif oa ~= ob then return oa > ob end\n"),
    ("sanitize keeps unknown looks", C, "if type(id) == \"string\" and Config.Looks[id] and type(t) == \"number\"",
     "if type(id) == \"string\" and type(t) == \"number\""),
    ("sanitize keeps non-boolean answers", C, "if type(id) == \"string\" and type(v) == \"boolean\" and",
     "if type(id) == \"string\" and"),
    # the boost
    ("no 2x XP", P, "\tamount = math.floor(amount * M.PassMult(player, \"XP2\"))\n", ""),
    ("no 2x Gold", P, "\t\treturn math.floor(amount * M.PassMult(player, \"Gold2\"))\n", "\t\treturn amount\n"),
    ("every source doubled", P, "\tif type(sources) == \"table\" and sources[source] == true then\n",
     "\tif type(sources) == \"table\" then\n"),
    ("pass ignored (always x2)", P, "\treturn (ok and has == true) and math.max(1, num(Config.PassBoost.Mult, 1)) or 1\n",
     "\treturn math.max(1, num(Config.PassBoost.Mult, 1))\n"),
    ("cap dropped", P, "\tif cap ~= nil then amount = math.min(amount, math.max(0, math.floor(num(cap)))) end\n", ""),
    ("doubled twice (in GetXPMult)", P, "\t\t+ num(data.RedeemMarks) * Config.Rebirth.RedeemXPPer\n",
     "\t\t+ num(data.RedeemMarks) * Config.Rebirth.RedeemXPPer + (M.PassMult(player, \"XP2\") - 1)\n"),
    ("AddXP returns nothing", P, "\t\tM.LeveledUp:Fire(player, level)\n\tend\n\treturn amount\nend\n",
     "\t\tM.LeveledUp:Fire(player, level)\n\tend\nend\n"),
    ("kill line shows the old amount", P, "\tgold = M.AddCarriedGold(player, gold, \"Monster\")", "\tM.AddCarriedGold(player, gold, \"Monster\")"),
    ("GoldEarned before the pass", P,
     "\tamount = boostGold(player, amount, source)\n\tS.PlayerService.AddStat(player, \"BankGold\", amount)\n"
     "\tM.GoldEarned:Fire(player, amount, source)\n",
     "\tlocal base = amount\n\tamount = boostGold(player, amount, source)\n\tS.PlayerService.AddStat(player, \"BankGold\", amount)\n"
     "\tM.GoldEarned:Fire(player, base, source)\n"),
    # ownership
    ("ids 0 asked", M, "\t\tlocal id = tonumber(p.Id)\n\t\tif id and id > 0 then", "\t\tlocal id = tonumber(p.Id)\n\t\tif id then"),
    ("no retry", M, "\tfor i = 1, Config.PassBoost.CheckTries do\n", "\tfor i = 1, 1 do\n"),
    ("no wait between tries", M, "\t\t\ttask.wait(wait)\n\t\t\twait *= 2\n", ""),
    ("no saved fallback", M, "\t\t\tanswer = seenTable(data)[p.Key] == true -- Roblox did not answer", "\t\t\tanswer = false -- Roblox did not answer"),
    ("answers not saved", M, "\t\t\tseenTable(data)[p.Key] = answer\n", ""),
    ("a purchase taken back", M, "\t\tif owned[p.Key] ~= true then owned[p.Key] = answer end", "\t\towned[p.Key] = answer"),
    ("left player written", M, "\t\tif player.Parent == nil or S.PlayerService.GetData(player) ~= data then return end\n", ""),
    ("closed prompt counts", M, "\tif purchased ~= true or typeof(player)", "\tif typeof(player)"),
    ("purchase not saved", M, "\t\t\tif data then seenTable(data)[p.Key] = true end\n", ""),
    ("debug override ignored", M, "\tif d and d[key] ~= nil then return d[key] == true end\n", ""),
    # looks
    ("SetLook: any faction", M, "\t\tif not look or look.Faction ~= player:GetAttribute(\"Faction\") or not MonetizationService.OwnsLook(player, id) then\n\t\t\treturn\n",
     "\t\tif not look or not MonetizationService.OwnsLook(player, id) then\n\t\t\treturn\n"),
    ("SetLook: not owned", M, "\t\tif not look or look.Faction ~= player:GetAttribute(\"Faction\") or not MonetizationService.OwnsLook(player, id) then\n\t\t\treturn\n",
     "\t\tif not look or look.Faction ~= player:GetAttribute(\"Faction\") then\n\t\t\treturn\n"),
    ("SetLook: no rate limit", M, " or not Util.RateLimit(player, \"SetLook\", Config.RateLimits.SetLook) then return end",
     " then return end"),
    ("SetLook: extra arguments", M, "function PASS.OnSetLook(player, ...)\n\tif select(\"#\", ...) ~= 1 then return end\n",
     "function PASS.OnSetLook(player, ...)\n"),
    ("worn look ignores the faction", M, "\tif not look or look.Faction ~= player:GetAttribute(\"Faction\") or not MonetizationService.OwnsLook(player, id) then\n\t\treturn \"\"\n",
     "\tif not look or not MonetizationService.OwnsLook(player, id) then\n\t\treturn \"\"\n"),
    ("a sold look granted", M, "\tif not look or type(look.Unlock) ~= \"table\" then return false end\n", "\tif not look then return false end\n"),
    ("granted twice", M, "\tif owned[id] ~= nil then return false end\n", ""),
    ("faction switch keeps the look", M, "\t\tS.FactionService.FactionChanged:Connect(function(player)\n\t\t\tpcall(PASS.Publish, player)\n",
     "\t\tS.FactionService.FactionChanged:Connect(function(player)\n"),
    # supporters
    ("hidden names on the board", M, "\tif player.Parent == nil or player:GetAttribute(\"HideAnnounceName\") == true then return end\n",
     "\tif player.Parent == nil then return end\n"),
    ("board not deduplicated", M, "and type(e.T) == \"number\" and not seen[e.U] then", "and type(e.T) == \"number\" then"),
    ("board oldest first", M, "\t\tif a.T ~= b.T then return a.T > b.T end\n", "\t\tif a.T ~= b.T then return a.T < b.T end\n"),
    ("board not capped", M, "\twhile #list > Config.PassBoost.MaxSupporters do table.remove(list) end\n", ""),
    ("debug VIP written to the shared list", M, "\tif localOnly then return end\n", ""),
    ("no refresh", M, "\tif ok then PASS.Show(PASS.Clean(raw)) end\n", ""),
    ("no VIP at join", M, "\tif MonetizationService.HasPass(player, \"VIP\") and PASS.Owned[player].VIP == true then PASS.AddSupporter(player) end\n",
     ""),
]


SUITE = Suite(
    mark="GAMEPASS",
    fixture=ROOT / "tools/fixtures/gamepass_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-08/offline_dev2_gamepass_2026-10-08.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-75 (user 2026-10-08): Config.GamePasses XP2 (2x XP, 199) / Gold2 (2x Gold, 149) / VIP (249), Attr "
             "PassXP2 / PassGold2 / PassVIP, Id 0 = not sold (never asked, 'Coming soon'). At join the server asks Roblox "
             "(UserOwnsGamePassAsync, 3 tries, waits 1 s then 2 s; every try failing = the last saved answer, "
             "data.PassSeen) and PromptGamePassPurchaseFinished (purchased) turns a pass on at once (a late 'no' never takes "
             "it back that session). x2 applies once per grant in ProgressionService: every XP grant, and gold from the "
             "earned sources (Monster, Quest, Event, Bounty, War, Loot, Kaiju minted part, SignOn, Attendance) - never "
             "Sale / Refund / Plunder / KaijuBank / KaijuTransfer / Penalty / Other; GetXPMult / GetGoldMult leave it out; "
             "the A23-27 one-level cap holds after it; each grant returns what was added and every line shown uses it. "
             "Looks: 4 sold (99) + 6 attendance-only (14 / 50 / 100 days, GrantLook), LooksOwned in shop order, LookOn = "
             "an owned look of the player's faction (SetLook, 0.5 s; a faction switch hides it). VIP owners go on the "
             "supporter board (GameState SupporterNames, newest first, 30, a shared DataStore list read every 5 min; a "
             "hidden name never). Studio DebugCommand Pass / LookGrant are session-only test aids.",
    limitations="MarketplaceService, DataStores, Players and the PlayerService are doubles; real Roblox answer times, "
                "purchase prompts, game pass ids and the shared list across real servers are only checkable after the "
                "user creates the passes (Studio / a published test). The grant sites outside ProgressionService are "
                "checked as source text (their source and that their line uses the returned amount), not run.",
)

if __name__ == "__main__":
    run(SUITE)
