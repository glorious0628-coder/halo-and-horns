"""A23-109 quick slots 1·2·3 — the server half (QuickSlotService, 게임성 개발 2), offline.

Runs the CURRENT Config, Util, QuickSlotService and DataService sources (plus Main / Net text for the wiring and
QuickSlots.Parse cut from the client's QuickSlots.luau) in tools/fixtures/quick_slot_server_offline.luau on
tools/fixtures/dev2_kit.luau with the installed official Luau CLI. No Studio, network, DataStore or Roblox API calls. Mutations run on in-memory copies only.
The client half (slots on screen, keys 1·2·3, the bag rows) is 게임성 개발 1's tools/test_quick_slots.py.

Usage: py tools/test_quick_slot_server.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-10/offline_dev2_quick_slot_server_2026-10-10.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run, strip_comments

CLIENT = ROOT / "src/StarterPlayer/StarterPlayerScripts/QuickSlots.luau"
FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "NET_SOURCE": SHARED / "Net.luau",
    "QUICK_SOURCE": SSS / "QuickSlotService.luau",
    "DATA_SOURCE": SSS / "DataService.luau",
    "MAIN_SOURCE": SSS / "Main.server.luau",
    "CLIENT_SOURCE": CLIENT,
}


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = dict(sources)
    out["CLIENT_PARSE"] = function_block(out.pop("CLIENT_SOURCE"), "function QuickSlots.Parse(attr)")
    return out


C, Q, D, M, N = "CONFIG_SOURCE", "QUICK_SOURCE", "DATA_SOURCE", "MAIN_SOURCE", "NET_SOURCE"
MUTATIONS = [
    # SetQuickSlot: argument checks
    ("extra arguments accepted", Q, '\tif select("#", ...) ~= 0 then return end\n\tif type(slot)', "\tif type(slot)"),
    ("slot range not checked", Q, " or slot < 1 or slot > Q.Count then return end", " then return end"),
    ("slot 0 accepted", Q, " or slot < 1 or ", " or slot < 0 or "),
    ("fractional slots accepted", Q, "slot ~= math.floor(slot) or ", ""),
    ("slot type not checked", Q, 'type(slot) ~= "number" or ', ""),
    ("unknown items accepted", Q, '\tif item ~= "" and not known(item) then return end\n', ""),
    ("known() takes any string", Q, 'return type(item) == "string" and Q.Items[item] ~= nil', 'return type(item) == "string"'),
    ("a player who is not ready may set", Q, " or not S.PlayerService.IsReady(player) then return end", " then return end"),
    ("a player who left may set", Q, "if player.Parent ~= Players or ", "if "),
    ("no rate limit", Q, 'if not Util.RateLimit(player, "SetQuickSlot", T.Rate) or slots[slot] == item then',
     "if slots[slot] == item then"),
    ("the rate limit falls to 0", Q, "Rate = (Config.RateLimits and Config.RateLimits.SetQuickSlot) or 0.2,", "Rate = 0,"),
    ("no data check", Q, '\tif type(data) ~= "table" then return end\n\tlocal slots = parse(data.QuickSlots)\n\t-- game play r8',
     "\tlocal slots = parse(data.QuickSlots)\n\t-- game play r8"),
    # SetQuickSlot: the change
    ("a moved item is copied, not swapped", Q, "\tif from then slots[from] = slots[slot] end", "\tlocal _ = from"),
    ("the same item on its own slot fires Changed", Q, ' or slots[slot] == item then\n\t\tpublish(player, slots)\n\t\treturn\n\tend',
     ' then\n\t\tpublish(player, slots)\n\t\treturn\n\tend'),
    ("game play r8: a no-change request leaves a stale attribute", Q, ' or slots[slot] == item then\n\t\tpublish(player, slots)\n',
     ' or slots[slot] == item then\n'),
    ("the change is not saved", Q, '\tdata.QuickSlots = table.concat(slots, ",")\n\tpublish(player, slots)\n\tQuickSlotService',
     "\tpublish(player, slots)\n\tQuickSlotService"),
    ("the change is not shown", Q, "\tpublish(player, slots)\n\tQuickSlotService.Changed", "\tQuickSlotService.Changed"),
    ("Changed never fires", Q, "\tQuickSlotService.Changed:Fire(player, table.clone(slots))\n", ""),
    ("Changed hands out the live table", Q, "Changed:Fire(player, table.clone(slots))", "Changed:Fire(player, {})"),
    # parse (load + every change)
    ("repeats kept", Q, "if not known(item) or seen[item] then", "if not known(item) then"),
    ("unknown stored items kept", Q, "if not known(item) or seen[item] then", 'if type(item) ~= "string" or seen[item] then'),
    ("no length cap", Q, 'if type(value) == "string" and #value <= T.MaxLen then', 'if type(value) == "string" then'),
    ("a broken value is all empty, not the Default", Q, "\t\tparts = Q.Default\n", "\t\tparts = {}\n"),
    ("short text keeps its length", Q, "\tfor i = 1, Q.Count do\n\t\tlocal item = parts[i]", "\tfor i = 1, #parts do\n\t\tlocal item = parts[i]"),
    ("Get reads another field", Q, "data.QuickSlots or nil", "data.QuickSlot or nil"),
    # load
    ("ready: no attribute", Q, '\tpublish(player, slots)\nend\n\nfunction QuickSlotService.Init', "end\n\nfunction QuickSlotService.Init"),
    ("ready: the clean slots are not saved", Q, '\tdata.QuickSlots = table.concat(slots, ",") -- clean', "\t-- clean"),
    ("an old save gets the Default", Q, '\tif value == nil then\n\t\tparts = string.split(T.OldSave, ",")\n\telseif',
     "\tif false then\n\telseif"),
    ("an old save gets empty slots", Q, 'OldSave = "HP,MP,",', 'OldSave = ",,",'),
    # the KO1 quest entry
    ("no QuickSlotSet", Q, '\tif item ~= "" then questEvent(player, slot, item) end\n', ""),
    ("emptying tells the quest", Q, 'if item ~= "" then questEvent(player, slot, item) end', "questEvent(player, slot, item)"),
    ("the quest hears the wrong slot", Q, "{ Slot = slot, Kind = item }", "{ Slot = 1, Kind = item }"),
    ("the quest hears another name", Q, 'pcall(sq.Event, player, "QuickSlotSet"', 'pcall(sq.Event, player, "QuickSlot"'),
    ("a quest error escapes", Q, 'local ok, err = pcall(sq.Event, player, "QuickSlotSet", { Slot = slot, Kind = item })',
     'local ok, err = true, sq.Event(player, "QuickSlotSet", { Slot = slot, Kind = item })'),
    ("no quest entry = an error", Q, '\tif type(sq) ~= "table" or type(sq.Event) ~= "function" then return end\n', ""),
    # DataService: a brand-new save
    ("a brand-new save gets no field (= HP / MP)", D,
     '\tif type(Config.QuickSlots) == "table" and type(Config.QuickSlots.Default) == "table" then\n'
     '\t\td.QuickSlots = table.concat(Config.QuickSlots.Default, ",")\n\tend\n', ""),
    ("a first DataStore record gets no slots", D, "\t\tgiveNewQuickSlots(d)\n\telseif type(d.TutorialStep)", "\telseif type(d.TutorialStep)"),
    ("a Studio memory-mode record gets no slots (= HP / MP)", D, "\t\tgiveNewQuickSlots(d) -- ", "\t\tlocal _ = d -- "),
    ("a brand-new save gets HP / MP", D, 'd.QuickSlots = table.concat(Config.QuickSlots.Default, ",")', 'd.QuickSlots = "HP,MP,"'),
    ("ready: not connected", Q, "\tS.PlayerService.PlayerReady:Connect(function(player, data)\n",
     "\tlocal _ = (function(player, data)\n"),
    ("a broken Default is not reported", Q,
     '\t\tif item ~= "" and not known(item) then Util.Warn(TAG, "Default has an unknown item " .. tostring(item)) end\n', ""),
    ("the remote name is not Config's", Q, "Net.Get(Q.Remote)", 'Net.Get("SetQuickSlots")'),
    ("the attribute name is not Config's", Q, "player:SetAttribute(Q.Attr, ", 'player:SetAttribute("QuickSlot", '),
    # Config / wiring
    ("Config: the rate limit is 0", C, "\tSetQuickSlot = 0.2, -- A23-109", "\tSetQuickSlot = 0, -- A23-109"),
    ("Main: never initialized", M, '\t"QuickSlotService", -- 게임성 개발 2: A23-109 quick slots', '\t"QuickSlotServiceX", -- 게임성 개발 2: A23-109 quick slots'),
    ("Main: started after PlayerService", M,
     '\t"QuickSlotService", -- 게임성 개발 2: A23-109 (before PlayerService too: it listens to PlayerReady)\n', ""),
    ("Net: the remote missing", N, '\t"SetQuickSlot", -- A23-109', '\t"SetQuickSlotX", -- A23-109'),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    quick = strip_comments(read(SSS / "QuickSlotService.luau"))
    check("<const>" not in quick, "no local x <const>")
    check("wait(" not in quick and "task.delay" not in quick, "QuickSlotService never yields or delays")
    check(quick.count("pcall(onSet, player, ...)") == 1 and quick.count("pcall(onReady, player, data)") == 1,
          "both handlers run inside pcall")
    # the server only reads Config.QuickSlots (게임성 개발 1 owns it)
    check(not re.search(r"(^|[^.\w])(Q|Config\.QuickSlots)(\.\w+|\[[^]]*\])+\s*=[^=]", quick, re.M),
          "QuickSlotService never writes Config.QuickSlots")
    # who writes the save field: QuickSlotService (onSet + the PlayerReady clean) and DataService (a brand-new save)
    writers = []
    for path in sorted(SSS.glob("*.luau")):
        for line in strip_comments(read(path)).splitlines():
            if ".QuickSlots =" in line:
                writers.append(path.name)
    check(sorted(writers) == ["DataService.luau", "QuickSlotService.luau", "QuickSlotService.luau"],
          f"only QuickSlotService (2) and DataService's new save (1) write data.QuickSlots: {writers}")
    # a slot press stays the UsePotion remote (no second potion path on the server)
    check("UsePotion" not in quick and "PotionCount" not in quick, "QuickSlotService has no potion use path of its own")
    return count, failures


SUITE = Suite(
    mark="QUICK_SLOT_SERVER",
    fixture=ROOT / "tools/fixtures/quick_slot_server_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-10/offline_dev2_quick_slot_server_2026-10-10.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-109 server (contract with 게임성 개발 1, Config.QuickSlots read only): data.QuickSlots = \"<i1>,<i2>,<i3>\" "
             "(Config.QuickSlots.Items keys HP / MP, \"\" = empty; additive, Version 3). A brand-new save gets "
             "Config.QuickSlots.Default (empty, 검수 10/10) from DataService; a stored save without the field (from before "
             "the quick slots) gets HP, MP, empty once; a broken value (not text, > 120 chars) = the Default; cleaned and "
             "saved at PlayerReady (unknown items and repeats empty, extra parts dropped). The owner's "
             "attribute QuickSlots = the same text, set at PlayerReady and after every accepted change; the client's "
             "QuickSlots.Parse reads it the same. c->s SetQuickSlot(slot 1..3 integer, item key | \"\"): the item already in "
             "another slot swaps with this slot's; the same item on its own slot / emptying an empty slot = no change; "
             "bad or extra args, not ready, left, no data, faster than Config.RateLimits.SetQuickSlot (0.2 s): nothing, no "
             "notice. QuickSlotService.Changed(player, slots) after every accepted change; an item put into a slot (also a swap) "
             "calls S.StoryQuestService.Event(player, \"QuickSlotSet\", { Slot, Kind }) when it exists (pcall; emptying, "
             "no change and refused calls: nothing). Get(player); Parse(value). A slot "
             "press stays the UsePotion remote (VitalsService, unchanged).",
    limitations="Offline doubles: Players / attributes, a PlayerService double (data rows, IsReady, PlayerReady), a "
                "StoryQuestService double (Event), the kit's DataStore (the real DataService Load / Release). The slots on screen, keys, "
                "the bag rows (게임성 개발 1) and the KO1 quest (게임성 개발 3) are not certified here; a live Studio play "
                "is still needed.",
)

if __name__ == "__main__":
    run(SUITE)
