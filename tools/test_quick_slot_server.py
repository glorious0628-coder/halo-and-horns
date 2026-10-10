"""A23-109 quick slots 1·2·3 — the server half (QuickSlotService, 게임성 개발 2), offline.

Runs the CURRENT Config, Util and QuickSlotService sources (plus Main / Net text for the wiring and QuickSlots.Parse cut
from the client's QuickSlots.luau) in tools/fixtures/quick_slot_server_offline.luau on tools/fixtures/dev2_kit.luau with
the installed official Luau CLI. No Studio, network, DataStore or Roblox API calls. Mutations run on in-memory copies only.
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
    "MAIN_SOURCE": SSS / "Main.server.luau",
    "CLIENT_SOURCE": CLIENT,
}


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = dict(sources)
    out["CLIENT_PARSE"] = function_block(out.pop("CLIENT_SOURCE"), "function QuickSlots.Parse(attr)")
    return out


C, Q, M, N = "CONFIG_SOURCE", "QUICK_SOURCE", "MAIN_SOURCE", "NET_SOURCE"
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
    ("no rate limit", Q, '\tif not Util.RateLimit(player, "SetQuickSlot", T.Rate) then return end\n', ""),
    ("the rate limit falls to 0", Q, "Rate = (Config.RateLimits and Config.RateLimits.SetQuickSlot) or 0.2,", "Rate = 0,"),
    ("no data check", Q, '\tif type(data) ~= "table" then return end\n\tlocal slots = parse(data.QuickSlots)\n\tif slots[slot] == item',
     "\tlocal slots = parse(data.QuickSlots)\n\tif slots[slot] == item"),
    # SetQuickSlot: the change
    ("a moved item is copied, not swapped", Q, "\tif from then slots[from] = slots[slot] end", "\tlocal _ = from"),
    ("the same item on its own slot fires Changed", Q, "\tif slots[slot] == item then return end\n", ""),
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
    ("ready: a stored value is not cleaned", Q,
     '\tif data.QuickSlots ~= nil then data.QuickSlots = table.concat(slots, ",") end\n', ""),
    ("ready: a missing field is written as the Default", Q, "\tif data.QuickSlots ~= nil then data.QuickSlots =",
     "\tif true then data.QuickSlots ="),
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
    # one place writes the save field, outside the load repair: onSet (and nobody else in the server)
    writers = []
    for path in sorted(SSS.glob("*.luau")):
        for line in strip_comments(read(path)).splitlines():
            if ".QuickSlots =" in line:
                writers.append(f"{path.name}: {line.strip()}")
    check(all(w.startswith("QuickSlotService.luau:") for w in writers) and len(writers) == 2,
          f"only QuickSlotService writes data.QuickSlots (onSet + the load repair): {writers}")
    # a slot press stays the UsePotion remote (no second potion path on the server)
    check("UsePotion" not in quick and "PotionCount" not in quick, "QuickSlotService has no potion use path of its own")
    return count, failures


SUITE = Suite(
    mark="QUICK_SLOT_SERVER",
    fixture=ROOT / "tools/fixtures/quick_slot_server_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-10/offline_dev2_quick_slot_server_2026-10-10.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-109 server (contract with 게임성 개발 1, Config.QuickSlots read only): data.QuickSlots = \"<i1>,<i2>,<i3>\" "
             "(Config.QuickSlots.Items keys HP / MP, \"\" = empty; additive, Version 3, written only when the player changes "
             "a slot); a missing / broken value is Config.QuickSlots.Default (HP, MP, empty); a stored value is cleaned at "
             "PlayerReady (unknown items and repeats empty, extra parts dropped, > 120 chars = Default). The owner's "
             "attribute QuickSlots = the same text, set at PlayerReady and after every accepted change; the client's "
             "QuickSlots.Parse reads it the same. c->s SetQuickSlot(slot 1..3 integer, item key | \"\"): the item already in "
             "another slot swaps with this slot's; the same item on its own slot / emptying an empty slot = no change; "
             "bad or extra args, not ready, left, no data, faster than Config.RateLimits.SetQuickSlot (0.2 s): nothing, no "
             "notice. QuickSlotService.Changed(player, slots) after every accepted change; Get(player); Parse(value). A slot "
             "press stays the UsePotion remote (VitalsService, unchanged).",
    limitations="Offline doubles: Players / attributes, a PlayerService double (data rows, IsReady, PlayerReady); the real "
                "DataService save is not run (the field is a plain string in the saved table). The slots on screen, keys, "
                "the bag rows (게임성 개발 1) and the KO1 quest (게임성 개발 3) are not certified here; a live Studio play "
                "is still needed.",
)

if __name__ == "__main__":
    run(SUITE)
