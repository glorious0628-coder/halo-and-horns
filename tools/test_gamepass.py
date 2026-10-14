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
A23-75 review 2026-10-08: the kaiju survive bonus is made from a pouch that already holds 2x Gold, so it is never doubled
again ("KaijuBonus"), only its cap; the saved answers (PassSeen) count from PlayerReady on (grants paid while joining);
the supporter board follows a later hide toggle, a hidden rejoin and a refund (one shared write per player per WriteGap).

Runs the CURRENT Config, Util, ProgressionService, MonetizationService and KaijuService's survive() reward (extracted
with its call / getNum helpers) on tools/fixtures/dev2_kit.luau doubles with
tools/fixtures/gamepass_offline.luau and the installed official Luau CLI; every XP / gold grant in
src/ServerScriptService is checked here as source text (its source, and that the line shown uses what was added). No
Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_gamepass.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-08/offline_dev2_gamepass_2026-10-08.json
"""
from __future__ import annotations

import re
from collections import Counter

from dev2_offline import ROOT, SHARED, SSS, Suite, between, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "PROGRESSION_SOURCE": SSS / "ProgressionService.luau",
    "MONETIZATION_SOURCE": SSS / "MonetizationService.luau",
    "KAIJU_SOURCE": SSS / "KaijuService.luau",
    "CRAFT_SOURCE": SSS / "CraftService.luau",  # A23-139: read as text only (the craft XP line)
}
C, P, M, K, CR = "CONFIG_SOURCE", "PROGRESSION_SOURCE", "MONETIZATION_SOURCE", "KAIJU_SOURCE", "CRAFT_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = {key: value for key, value in sources.items() if key != K}
    kaiju = sources[K]
    # A23-75 review 2026-10-08: KaijuService's REAL survive() with its constants and its real warnThrottled / call /
    # getNum helpers, as one chunk returning survive and SURVIVE_BONUS_MINUTES (the fixture gives the rest as globals)
    out["KAIJU_SURVIVE_SOURCE"] = "\n".join([
        between(kaiju, "local SURVIVE_BONUS_MINUTES", "\nlocal KaijuService = {}"),
        function_block(kaiju, "local function warnThrottled("),
        function_block(kaiju, "local function call("),
        function_block(kaiju, "local function getNum("),
        function_block(kaiju, "local function survive(p)"),
        "return survive, SURVIVE_BONUS_MINUTES\n",
    ])
    return out


# every XP / gold grant on the server: (file, call, gold source or None for XP, the line shown uses what was added)
EXPECTED = [
    ("AttendanceService.luau", "AddBankGold", "Attendance", True),  # A23-77, game dev 3 (main)
    ("AttendanceService.luau", "AddXP", None, True),
    ("BoardService.luau", "AddBankGold", "Quest", True),
    ("BoardService.luau", "AddXP", None, True),
    ("CommissionService.luau", "AddBankGold", "Refund", False),  # A23-86 H: the order's gold back if a material cannot be taken (never 2x)
    ("FactionService.luau", "AddBankGold", "SignOn", True),
    ("FinisherService.luau", "AddBankGold", "Finisher", True),  # the field bosses' card: shown as added, never 2x
    ("GooseService.luau", "AddBankGold", "Event", True),
    ("GooseService.luau", "AddXP", None, True),
    ("GrudgeService.luau", "AddBankGold", "Refund", False),
    ("GrudgeService.luau", "AddBankGold", "Refund", False),
    ("GrudgeService.luau", "AddBankGold", "Refund", False),
    ("GrudgeService.luau", "AddCarriedGold", "Plunder", False),
    ("GrudgeService.luau", "AddBankGold", "Bounty", True),
    ("KaijuService.luau", "AddBankGold", "KaijuBank", False),
    ("KaijuService.luau", "AddBankGold", "KaijuBonus", True),  # shown as added, never 2x (PRE_BOOSTED)
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
    ("StoryQuestService.luau", "AddBankGold", "Choice", True),  # a pick's gold: shown as added, never 2x
    ("StoryQuestService.luau", "AddCarriedGold", "Choice", False),  # A23-110 KO1: the missing part of 50 gold for two potions (a gift, no line, never 2x)
    ("WarService.luau", "AddBankGold", "War", True),
]
# A23-75 review 2026-10-08: shown as added, but never 2x: made from gold that already holds the pass (the kaiju survive
# bonus is half the pouch; only its cap scales with the pass)
PRE_BOOSTED = {"KaijuBonus"}
# A23-75 review 2026-10-08 (검수 3rd look): shown as added, never 2x - a good / evil pick's gold (story picks "Choice",
# the King Slime finisher card "Finisher" on its own branch) must not pay one side more for a paying child
NOT_DOUBLED = {"Choice", "Finisher"}
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
    earned = {s for f, k, s, sh in EXPECTED if s and sh} - PRE_BOOSTED - NOT_DOUBLED
    never = {"Sale", "Refund", "Plunder", "KaijuBank", "KaijuTransfer", "Other", "Penalty"} | PRE_BOOSTED | NOT_DOUBLED
    check(earned <= sources and not (sources & never),
          f"the shown (earned) sources are the 2x Gold ones, never a transfer or a pre-boosted one ({sorted(sources)})")
    quest = strip_comments(read(SSS / "QuestService.luau"))
    for text in ("cg, cx = payReward(player, cg, cx)", "local gotGold = payReward(player,", "paidGold += (payReward(player, g, x))",
                 "string.format(TUT_CLAIMED_TEXT, Util.FormatNumber(gotGold)), \"reward\", nil, \"QuestDone\"", "Config.Text.QuestDone, Util.FormatNumber(gotGold)"):
        check(text in quest, f"QuestService shows what payReward / the first mission added: {text}")
    # 최종 검수 10/13 (EarlyMult 0.35, A23-14 kept): the vacation claim passes its Lv9 cap (the cap is applied after the 2x XP pass)
    check(quest.count("g, x = payReward(player, g, x)") == 1 and quest.count("g, x = payReward(player, g, x, room)") == 1,
          "QuestService: the daily claim and the vacation show what was added")
    pay = function_block(quest, "local function payReward(")
    check("return math.max(0, gold), math.max(0, xp)" in pay, "payReward returns the gold and XP added")
    kaiju = strip_comments(read(SSS / "KaijuService.luau"))
    check(re.search(r"AddBankGold\", p, taken, \"KaijuBank\"", kaiju) is not None
          and re.search(r"bonus = tonumber\(call\(\"ProgressionService\", \"AddBankGold\", p, bonus, \"KaijuBonus\"\)\)", kaiju)
          is not None
          and re.search(r"AddBankGold\", p, moved, \"KaijuTransfer\"", kaiju) is not None
          and re.search(r"mintShare = tonumber\(call\(\"ProgressionService\", \"AddBankGold\", p, mintShare, \"Kaiju\"\)\)", kaiju)
          is not None, "kaiju: the carried gold moved is never 2x, only the minted part")
    check("local passMult = math.max(1, tonumber(call(\"ProgressionService\", \"PassMult\", p, \"Gold2\")) or 1)" in kaiju
          and "math.min(fullBonus, math.max(0, math.floor(capGold * passMult)))" in kaiju,
          "kaiju survive: only the bonus cap scales with the 2x Gold pass (A23-75 review 2026-10-08)")
    prog = strip_comments(read(SSS / "ProgressionService.luau"))
    for fn in ("function M.GetGoldMult(", "function M.GetXPMult("):
        body = function_block(prog, fn)
        check("PassMult" not in body and "HasPass" not in body, f"{fn} leaves the pass out (it is applied once, in the grant)")
    # A23-167: AddXP takes XPBoost (the 2x XP pass or the first minutes, the larger), boostGold the gold pass
    add_xp = function_block(prog, "function M.AddXP(")
    boost = function_block(prog, "function M.XPBoost(")
    check(prog.count("* M.PassMult(player,") == 1 and prog.count("* M.XPBoost(player)") == 1
          and "amount = math.floor(amount * M.XPBoost(player))" in add_xp
          and "return math.max(M.PassMult(player, \"XP2\"), early)" in boost,
          "the pass is applied in two places only: AddXP (XPBoost) and boostGold")
    # 검수 2026-10-08: quest rewards double their gold (and XP) only; items (scrolls, jelly, potions, materials) never.
    # Item grants (LootService.GrantItem / drops, the quest / board / story item rewards) never read the pass: outside
    # ProgressionService / MonetizationService only KaijuService's survive cap and CraftService's craft XP line (A23-139,
    # user 10/12: 2x level AND crafting XP; the fixture's "craft XP pass" group checks it is that line only) read PassMult
    # TestMetricsService (A23-160 the test's numbers board) only asks HasPass on a later join to count a pass that still works
    # (read-only observer, grants nothing; tools/test_test_metrics.py checks it never pays or changes anything)
    readers = sorted(p.name for p in SSS.glob("*.luau")
                     if p.name not in ("ProgressionService.luau", "MonetizationService.luau", "TestMetricsService.luau")
                     and re.search(r"PassMult|HasPass|PassBoost|PassGold2|PassXP2", strip_comments(read(p))))
    check(readers == ["CraftService.luau", "KaijuService.luau"],
          f"items are never 2x: no grant path but the kaiju cap and the craft XP line read the pass ({readers})")
    net = read(SHARED / "Net.luau")
    check("\"SetLook\"," in net and "SupporterNames = \"\"," in net, "Net: c->s SetLook, GameState SupporterNames")
    data = read(SSS / "DataService.luau")
    check("if Config.SanitizeLooks then d.Looks, d.PassSeen = Config.SanitizeLooks(d.Looks, d.PassSeen) end" in data,
          "DataService repairs Looks / PassSeen on load (additive, Version 3)")
    main = read(SSS / "Main.server.luau")
    init = re.findall(r"\"(\w+)\"", between(main, "local INIT_ORDER = {", "}"))
    check(all(n in init and init.index("MonetizationService") < init.index(n)
              for n in ("ProgressionService", "QuestService", "StoryQuestService", "BoardService")),
          "MonetizationService connects PlayerReady before the services that pay there (A23-75 review 2026-10-08)")
    studio = main.find("if game:GetService(\"RunService\"):IsStudio() then")
    pass_key = main.find("elseif key == \"Pass\" then")
    look_key = main.find("elseif key == \"LookGrant\" then")
    check(0 <= studio < pass_key and studio < look_key and "S.MonetizationService.DebugSetPass(player, k," in main,
          "DebugCommand Pass / LookGrant: Studio only")
    money = strip_comments(read(SSS / "MonetizationService.luau"))
    check("ProcessReceipt" not in money and "Config.Products" not in money
          and "PromptGamePassPurchaseFinished:Connect" in money,
          "MonetizationService: no ProcessReceipt / Developer Product (A23-28: no Robux change tickets), the pass purchase signal")
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
    # A23-167 the first minutes x2 XP (게임성 개발 2, 2026-10-14)
    ("early: the pass and the first minutes multiply (x4)", P, "\treturn math.max(M.PassMult(player, \"XP2\"), early)\n",
     "\treturn M.PassMult(player, \"XP2\") * early\n"),
    ("early: the pass alone (no first minutes)", P, "\tamount = math.floor(amount * M.XPBoost(player))\n",
     "\tamount = math.floor(amount * M.PassMult(player, \"XP2\"))\n"),
    ("early: for every save", P, "\treturn math.max(0, num(E.Seconds) - num(data.PlaytimeSeconds))\n", "\treturn num(E.Seconds)\n"),
    ("early: one second longer", P, "\treturn math.max(0, num(E.Seconds) - num(data.PlaytimeSeconds))\n",
     "\treturn math.max(0, num(E.Seconds) + 1 - num(data.PlaytimeSeconds))\n"),
    ("early: the switch ignored", P, "\tif type(E) ~= \"table\" or E.Enabled == false then return 0 end\n",
     "\tif type(E) ~= \"table\" then return 0 end\n"),
    ("early: the cap before the boost", P,
     "\tamount = math.floor(amount * M.XPBoost(player))\n\tif cap ~= nil then amount = math.min(amount, math.max(0, math.floor(num(cap)))) end\n",
     "\tif cap ~= nil then amount = math.min(amount, math.max(0, math.floor(num(cap)))) end\n\tamount = math.floor(amount * M.XPBoost(player))\n"),
    ("early: Config 30 minutes", C, "\tSeconds = 600,\n\tMult = 2,\n", "\tSeconds = 1800,\n\tMult = 2,\n"),
    ("early: Config x3", C, "\tSeconds = 600,\n\tMult = 2,\n", "\tSeconds = 600,\n\tMult = 3,\n"),
    # A23-144 chat bubble skins
    ("bubbles: the pack is free", M, "\treturn MonetizationService.HasPass(player, Config.Bubbles.Pass)\nend\n", "\treturn true\nend\n"),
    ("bubbles: any side's free bubble", M, "\tif side then return side == player:GetAttribute(\"Faction\") end\n", "\tif side then return true end\n"),
    ("bubbles: a refused pick is saved", M, "\tif key ~= \"\" and not PASS.BubbleUsable(player, key) then return end\n", ""),
    ("bubbles: no rate limit", M, "or not Util.RateLimit(player, \"SetBubble\", Config.RateLimits.SetBubble or 0.5) then return end", "then return end"),
    ("bubbles: the saved pick shown even when unusable", M,
     "if type(want) == \"string\" and want ~= \"\" and PASS.BubbleUsable(player, want) then return want end",
     "if type(want) == \"string\" and want ~= \"\" then return want end"),
    ("bubbles: no free bubble", M, "\treturn type(free) == \"string\" and free or \"\"\nend\n", "\treturn \"\"\nend\n"),
    ("bubbles: never published", M, "\tplayer:SetAttribute(\"BubbleOn\", PASS.BubbleOf(player)) -- A23-144\n", ""),
    ("bubbles: any argument count", M, "\tif select(\"#\", ...) ~= 1 then return end\n\tlocal key = ...\n\tif type(key) ~= \"string\" or #key > 32 then return end\n",
     "\tlocal key = ...\n\tif type(key) ~= \"string\" or #key > 32 then return end\n"),
    # A23-143 chat stickers
    ("stickers: the pack is free", M, "\tif not Config.StickerFree(key) and not MonetizationService.HasPass(player, Config.Stickers.Pass) then return end\n", ""),
    ("stickers: no rate limit", M, "\tif not Util.RateLimit(player, \"SendSticker\", Config.RateLimits.SendSticker or 2) then return end\n", ""),
    ("stickers: any argument count", M, "\tif select(\"#\", ...) ~= 1 then return end\n\tlocal key = ...\n\tif not Config.IsSticker(key) then return end\n",
     "\tlocal key = ...\n\tif not Config.IsSticker(key) then return end\n"),
    ("stickers: any art id", M, "\tif not Config.IsSticker(key) then return end\n", "\tif type(key) ~= \"string\" then return end\n"),
    ("stickers: the dead send", M, "\tif not S.PlayerService.IsReady(player) or not Util.IsAlive(player) then return end\n\tif not Config.StickerFree",
     "\tif not S.PlayerService.IsReady(player) then return end\n\tif not Config.StickerFree"),
    ("stickers: sent to the sender only", M, "pcall(Net.Fx, nil, \"Sticker\", { UserId = player.UserId, Key = key })",
     "pcall(Net.Fx, player, \"Sticker\", { UserId = player.UserId, Key = key })"),
    ("stickers: every one free", C, "\treturn Config.IsSticker(key) and type(part) == \"table\" and part.Free == true\n", "\treturn Config.IsSticker(key)\n"),
    ("stickers: pass 199", C, "Price = 99, Name = \"Sticker Pack\"", "Price = 199, Name = \"Sticker Pack\""),  # 10/14: any pass id
    # A23-139: the pass doubles craft XP only, never what a craft makes
    ("craft: the result count x the pass", CR, "\tlocal n = math.max(1, math.floor(num(r.N, 1))) + math.max(0, math.floor(num(plus))) -- items: N + the hammer's +N\n", "\tlocal n = (math.max(1, math.floor(num(r.N, 1))) + math.max(0, math.floor(num(plus)))) * math.max(1, num(S.ProgressionService.PassMult(player, \"XP2\"), 1))\n"),
    ("craft: the +N x the pass", CR, "\t\tlocal okPass, pass = pcall(function() return ps and type(ps.PassMult) == \"function\" and ps.PassMult(player, \"XP2\") or 1 end)\n\t\txp = math.floor(num(r.XP) * (okPass and num(pass, 1) or 1))\n\tend\n", "\t\tlocal okPass, pass = pcall(function() return ps and type(ps.PassMult) == \"function\" and ps.PassMult(player, \"XP2\") or 1 end)\n\t\txp = math.floor(num(r.XP) * (okPass and num(pass, 1) or 1))\n\t\tplus = math.min(2, plus * num(pass, 1))\n\tend\n"),
    ("craft: the 2x Gold pass on craft XP", CR, "ps.PassMult(player, \"XP2\") or 1 end)\n", "ps.PassMult(player, \"Gold2\") or 1 end)\n"),
    ("craft: XP x the pass twice", CR, "\t\txp = math.floor(num(r.XP) * (okPass and num(pass, 1) or 1))\n", "\t\txp = math.floor(num(r.XP) * (okPass and num(pass, 1) or 1) * (okPass and num(pass, 1) or 1))\n"),
    # config
    ("2x Gold for sales", C, "GoldSources = { Monster = true,", "GoldSources = { Sale = true, Monster = true,"),
    ("kills not doubled", C, "GoldSources = { Monster = true, Quest = true,", "GoldSources = { Quest = true,"),
    ("x1", C, "\tMult = 2,\n\tGoldSources", "\tMult = 1,\n\tGoldSources"),
    ("one try", C, "\tCheckTries = 3,\n", "\tCheckTries = 1,\n"),
    ("VIP price", C, "Price = 249, Name = \"VIP\"", "Price = 199, Name = \"VIP\""),  # 10/14: any pass id
    ("a sold look free", C, "Price = 99, Name = \"Ice Halo\"", "Price = 0, Name = \"Ice Halo\""),    ("look order off", C, "\t\tif oa ~= ob then return oa < ob end\n", "\t\tif oa ~= ob then return oa > ob end\n"),
    ("sanitize keeps unknown looks", C, "if type(id) == \"string\" and Config.Looks[id] and type(t) == \"number\"",
     "if type(id) == \"string\" and type(t) == \"number\""),
    ("sanitize keeps non-boolean answers", C, "if type(id) == \"string\" and type(v) == \"boolean\" and",
     "if type(id) == \"string\" and"),
    # the boost
    ("no 2x XP", P, "\tamount = math.floor(amount * M.XPBoost(player))\n", ""),
    ("no 2x XP pass (the first minutes only)", P, "\treturn math.max(M.PassMult(player, \"XP2\"), early)\n", "\treturn early\n"),
    ("no 2x Gold", P, "\t\treturn math.floor(amount * M.PassMult(player, \"Gold2\"))\n", "\t\treturn amount\n"),
    ("every source doubled", P, "\tif type(sources) == \"table\" and sources[source] == true then\n",
     "\tif type(sources) == \"table\" then\n"),
    ("pass ignored (always x2)", P, "\treturn (ok and has == true) and math.max(1, num(Config.PassBoost.Mult, 1)) or 1\n",
     "\treturn math.max(1, num(Config.PassBoost.Mult, 1))\n"),
    ("cap dropped", P, "\tif cap ~= nil then amount = math.min(amount, math.max(0, math.floor(num(cap)))) end\n", ""),
    ("doubled twice (in GetXPMult)", P, "\t\t+ num(data.RedeemMarks) * Config.Rebirth.RedeemXPPer\n",
     "\t\t+ num(data.RedeemMarks) * Config.Rebirth.RedeemXPPer + (M.PassMult(player, \"XP2\") - 1)\n"),
    ("AddXP returns nothing", P, "\t\tM.LeveledUp:Fire(player, level)\n\tend\n\tM.XPEarned:Fire(player, amount)\n\treturn amount\nend\n",
     "\t\tM.LeveledUp:Fire(player, level)\n\tend\n\tM.XPEarned:Fire(player, amount)\nend\n"),
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
    ("answers not saved", M, "\t\t\tseenTable(data)[p.Key] = answer or owned[p.Key] == true\n", ""),
    ("a purchase taken back", M, "\t\tif owned[p.Key] ~= true then owned[p.Key] = answer end", "\t\towned[p.Key] = answer"),
    ("left player written", M, "\t\tif player.Parent == nil or S.PlayerService.GetData(player) ~= data then return end\n", ""),
    ("closed prompt counts", M, "\tif purchased ~= true or typeof(player)", "\tif typeof(player)"),
    ("purchase not saved", M, "\t\tif answer == true and data then seenTable(data)[p.Key] = true end\n", ""),
    ("debug override ignored", M, "function MonetizationService.HasPass(player, key)\n\tlocal d = PASS.Debug[player]\n\tif d and d[key] ~= nil then return d[key] == true end\n",
     "function MonetizationService.HasPass(player, key)\n\tlocal d = PASS.Debug[player]\n"),
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
    # PassBought (game dev 3's metric)
    ("no PassBought", M, "\t\t\tMonetizationService.PassBought:Fire(player, p.Key)\n", ""),
    ("PassBought before the pass is on", M,
     "\t\towned[p.Key] = true\n\t\tlocal data = S.PlayerService.GetData(player)\n",
     "\t\tMonetizationService.PassBought:Fire(player, p.Key)\n\t\towned[p.Key] = true\n"
     "\t\t\tlocal data = S.PlayerService.GetData(player)\n"),
    ("PassBought at the join check", M,
     "\t\tif owned[p.Key] ~= true then owned[p.Key] = answer end -- a purchase meanwhile is never taken back\n",
     "\t\tif owned[p.Key] ~= true then owned[p.Key] = answer end -- a purchase meanwhile is never taken back\n"
     "\t\tif answer then MonetizationService.PassBought:Fire(player, p.Key) end\n"),
    # review 2nd look
    ("a purchase during the check saved as no", M, "\t\t\tseenTable(data)[p.Key] = answer or owned[p.Key] == true\n",
     "\t\t\tseenTable(data)[p.Key] = answer\n"),
    ("long names dropped", M, "#e.N <= 80", "#e.N <= 40"),
    ("failed writes never retried", M, "\t\tif tries > 0 and tries <= Config.PassBoost.WriteRetries and not PASS.Queued[userId] then\n",
     "\t\tif false then\n"),
    ("retries without end", M, "\t\tif tries > 0 and tries <= Config.PassBoost.WriteRetries and not PASS.Queued[userId] then\n",
     "\t\tif tries > 0 and not PASS.Queued[userId] then\n"),
    ("no duplicate id warning", M, "\t\t\tif ids[p.Id] then Util.Warn(", "\t\t\tif false then Util.Warn("),
    ("top level returns the full amount", P, "\t\tamount = math.max(0, amount - math.max(0, xp - full))\n", ""),
    # review 3rd look (검수 2026-10-08)
    ("a purchase trusted without asking Roblox", M,
     "\t\tlocal answer = PASS.Ask(player.UserId, p.Id)\n\t\t-- gamepass_3f5dd020_verify",
     "\t\tlocal answer = true\n\t\t-- gamepass_3f5dd020_verify"),
    # gamepass_3f5dd020_verify (개발 3, 2026-10-09): a cached "no" right after a purchase is asked again
    ("no recheck after a no", M, "\t\t\tif answer ~= false or player.Parent == nil then break end\n",
     "\t\t\tbreak\n"),
    ("rechecks keep asking after a yes", M, "\t\t\tif answer ~= false or player.Parent == nil then break end\n",
     "\t\t\tif player.Parent == nil then break end\n"),
    ("one recheck only", C, "\tPurchaseRecheck = { 2, 5 },", "\tPurchaseRecheck = { 2 },"),
    ("recheck waits from zero each time", M, "\t\t\ttask.wait(math.max(0, at - waited))", "\t\t\ttask.wait(at)"),
    ("recheck after the buyer left", M, "\t\t\tif player.Parent == nil then return end\n\t\t\tanswer = PASS.Ask",
     "\t\t\tanswer = PASS.Ask"),
    ("a refused purchase kept", M, "\t\tif answer == false then\n\t\t\tUtil.Warn(", "\t\tif false then\n\t\t\tUtil.Warn("),
    ("an unanswered purchase saved", M, "if answer == true and data then seenTable(data)[p.Key] = true end",
     "if data then seenTable(data)[p.Key] = true end"),
    ("an unanswered VIP shared", M, "if p.Key == \"VIP\" then PASS.AddSupporter(player, answer ~= true) end",
     "if p.Key == \"VIP\" then PASS.AddSupporter(player) end"),
    ("PassBought without Roblox's yes", M, "\t\tif answer == true then\n\t\t\tprint(", "\t\tif true then\n\t\t\tprint("),
    ("Studio purchases saved for real", M,
     "\t\tif RunService:IsStudio() then\n\t\t\tlocal data = S.PlayerService.GetData(player)\n",
     "\t\tif false then\n\t\t\tlocal data = S.PlayerService.GetData(player)\n"),
    ("a Studio purchase not tainted", M, "\t\t\tif data then data.DebugTainted = true end\n", ""),
    ("Studio shares the live list", M, "(RunService:IsStudio() and \"_STUDIO\" or \"\")", "\"\""),
    ("names never follow the nickname", M, "\tend\n\tPASS.AddSupporter(player, not PASS.Confirmed(player))\nend\n",
     "\tend\nend\n"),
    ("an unchanged name written again", M, "\t\tif e.U == player.UserId and e.N == name then return end\n", ""),
    ("a renamed unconfirmed VIP shared", M, "\tend\n\tPASS.AddSupporter(player, not PASS.Confirmed(player))\nend\n",
     "\tend\n\tPASS.AddSupporter(player)\nend\n"),
    ("a hide toggle shares an unconfirmed VIP", M,
     "\telseif vip and MonetizationService.HasPass(player, \"VIP\") then\n\t\tPASS.AddSupporter(player, not PASS.Confirmed(player))\n",
     "\telseif vip and MonetizationService.HasPass(player, \"VIP\") then\n\t\tPASS.AddSupporter(player)\n"),
    ("names follow an unverified nickname", M, "\tlocal name = Util.PlayerDisplayName(player)\n\tfor _, e in PASS.Board do\n",
     "\tlocal name = player:GetAttribute(\"Nickname\") or player.DisplayName\n\tfor _, e in PASS.Board do\n"),
    ("no VIP at join", M, "\t\telseif MonetizationService.HasPass(player, \"VIP\") then\n\t\t\tPASS.AddSupporter(player)\n",
     "\t\telseif false then\n"),
    # A23-75 review 2026-10-08: the kaiju survive bonus (the pass once), the saved answers at join, the board and a hide
    ("kaiju bonus doubled again", K, "p, bonus, \"KaijuBonus\")", "p, bonus, \"Kaiju\")"),
    ("kaiju bonus cap not doubled", K, "math.floor(capGold * passMult)", "math.floor(capGold)"),
    ("KaijuBonus a 2x source", C, "GoldSources = { Monster = true,", "GoldSources = { KaijuBonus = true, Monster = true,"),
    ("no saved answers at join", M, "\t\tPASS.Seed(player) -- A23-75 review 2026-10-08", "\t\t-- A23-75 review 2026-10-08"),
    ("saved answers ignored", M, "\treturn s ~= nil and s[key] == true\n", "\treturn false\n"),
    ("saved answers outlive Roblox's", M, "\tif o ~= nil and o[key] ~= nil then return o[key] == true end\n",
     "\tif o ~= nil and o[key] == true then return true end\n"),
    ("unsold passes seeded", M, "\t\tfor _, p in PASS.Sold() do\n\t\t\tif seenTable(data)[p.Key] == true then seen[p.Key] = true end\n",
     "\t\tfor k, v in seenTable(data) do\n\t\t\tif v == true then seen[k] = true end\n"),
    ("hide toggle ignored", M, "GetAttributeChangedSignal(\"HideAnnounceName\")", "GetAttributeChangedSignal(\"Unused\")"),
    ("shown again not listed", M,
     "\telseif vip and MonetizationService.HasPass(player, \"VIP\") then\n\t\tPASS.AddSupporter(player, not PASS.Confirmed(player))\n",
     "\telseif false then\n"),
    ("removal not written to the shared list", M, "\tPASS.Show(PASS.Without(PASS.Board, player.UserId))\n\tPASS.Write(player.UserId, false)\n",
     "\tPASS.Show(PASS.Without(PASS.Board, player.UserId))\n"),
    ("hidden VIP rejoining stays listed", M, "\t\tif player:GetAttribute(\"HideAnnounceName\") == true then\n\t\t\tPASS.RemoveSupporter(player)\n",
     "\t\tif player:GetAttribute(\"HideAnnounceName\") == true then\n"),
    ("refund stays listed", M, "\telseif wasVip and owned.VIP == false then\n", "\telseif false then\n"),
    ("board shows a hidden player here", M,
     "\t\tif not (here and here:GetAttribute(\"HideAnnounceName\") == true) then table.insert(shown, e) end\n",
     "\t\ttable.insert(shown, e)\n"),
    ("no write gap", M, "\tif wait > 0 then task.delay(wait, run) else task.spawn(run) end\n", "\ttask.spawn(run)\n"),
    ("no write gap (config)", C, "\tWriteGap = 10,\n", "\tWriteGap = 0,\n"),
    ("a queued write keeps the first choice", M, "\tPASS.Want[userId] = entry\n\tif PASS.Queued[userId] then return end\n",
     "\tif PASS.Queued[userId] then return end\n\tPASS.Want[userId] = entry\n"),
    ("a queued write dropped after a leave", M, "\t\tlocal want = PASS.Want[userId]\n\t\tPASS.Want[userId] = nil\n",
     "\t\tlocal want = PASS.Want[userId]\n\t\tPASS.Want[userId] = nil\n\t\tif Players:GetPlayerByUserId(userId) == nil then return end\n"),
    # A23-182: the Fast Travel subscription
    ("sub: the api id without EXP-", M, 'then return string.format("EXP-%d", id) end', 'then return string.format("%d", id) end'),
    ("sub: Id 0 asked", M, 'id == id and id > 0 and id == math.floor(id) then', 'id == id and id >= 0 and id == math.floor(id) then'),
    ("sub: a failed ask counts", M, "\t\ton = ok and type(res) == \"table\" and res.IsSubscribed == true\n", "\t\ton = not ok or res.IsSubscribed == true\n"),
    ("sub: renewing counts as subscribed", M, "res.IsSubscribed == true\n", "(res.IsSubscribed == true or res.IsRenewing == true)\n"),
    ("sub: no attribute", M, '\tif type(def.Attr) == "string" then player:SetAttribute(def.Attr, on) end\n', ""),
    ("sub: never asked at join", M, "\t\ttask.spawn(SUB.CheckAll, player) -- A23-182: subscriptions, every join\n", ""),
    ("sub: the change signal ignored", M, "\t\t\t\tif MonetizationService.SubscriptionApiId(key) == subscriptionId then\n",
     "\t\t\t\tif false then\n"),
    ("sub: any change rechecks every key", M, "\t\t\t\tif MonetizationService.SubscriptionApiId(key) == subscriptionId then\n",
     "\t\t\t\tif true then\n"),
    ("sub: kept after a leave", M, "\t\tSUB.Active[player] = nil\n", ""),
    ("sub: HasSub is the attribute", M, "\tlocal a = SUB.Active[player]\n\treturn a ~= nil and a[key] == true\n",
     "\treturn player:GetAttribute(\"SubFastTravel\") ~= false\n"),
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
             "it back that session). Review 2026-10-08: the saved answer of a sold pass counts from PlayerReady until Roblox "
             "answers (grants paid while joining see it). x2 applies once per grant in ProgressionService: every XP grant, "
             "and gold from the earned sources (Monster, Quest, Event, Bounty, War, Loot, Kaiju minted hunt part, SignOn, "
             "Attendance) - never Sale / Refund / Plunder / KaijuBank / KaijuTransfer / KaijuBonus (the survive bonus, half "
             "a pouch that already holds the pass; only its cap doubles) / Penalty / Other; GetXPMult / GetGoldMult leave it out; "
             "the A23-27 one-level cap holds after it; each grant returns what was added and every line shown uses it. "
             "Looks: 4 sold (99) + 6 attendance-only (14 / 50 / 100 days, GrantLook), LooksOwned in shop order, LookOn = "
             "an owned look of the player's faction (SetLook, 0.5 s; a faction switch hides it). VIP owners go on the "
             "supporter board (GameState SupporterNames, newest first, 30, a shared DataStore list read every 5 min; a "
             "hidden name never: hiding later, rejoining hidden or a refund takes it off here at once and off the shared "
             "list, one shared write per player per 10 s with the latest choice). Studio DebugCommand Pass / LookGrant are "
             "session-only test aids.",
    limitations="MarketplaceService, DataStores, Players and the PlayerService are doubles; real Roblox answer times, "
                "purchase prompts, game pass ids and the shared list across real servers are only checkable after the "
                "user creates the passes (Studio / a published test). The grant sites outside ProgressionService are "
                "checked as source text (their source and that their line uses the returned amount), not run, except "
                "KaijuService's survive() reward (extracted and run on the real ProgressionService; the kaiju event "
                "around it is a stand-in).",
)

if __name__ == "__main__":
    run(SUITE)
