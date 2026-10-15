"""A23-191 (최종 검수 10/15): the server Notify gate in Net.luau, offline.

The client draws only a failure line (Kind "bad"). Net.Notify / NotifyAll / NotifyKey / NotifyAllKey send a "bad" line
with its text; every other kind sends its sound alone (Text "", no Key) or nothing when it has no sound (Sound "None", or
info / good / announce without a Sound; "reward" without a Sound keeps the client's QuestDone). Runs the CURRENT Net.luau
on tools/fixtures/dev2_kit.luau with tools/fixtures/notify_gate_offline.luau and the installed official Luau CLI. No
Studio, network or Roblox API calls; mutations run on in-memory copies only.

Usage: py tools/test_notify_gate.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-15/offline_notify_gate_2026-10-15.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run, strip_comments

FILES = {
    "NET_SOURCE": SHARED / "Net.luau",
}
N = "NET_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    ("every kind keeps its text", N, "\tif kind == \"bad\" then return text end\n\tif sound == \"None\"", "\tdo return text end\n\tif sound == \"None\""),
    ("bad loses its text", N, "\tif kind == \"bad\" then return text end\n\tif sound == \"None\"", "\tif kind == \"bad\" then return \"\" end\n\tif sound == \"None\""),
    ("a sound line keeps its text", N, "\tif type(sound) == \"string\" and sound ~= \"\" then return \"\" end",
     "\tif type(sound) == \"string\" and sound ~= \"\" then return text end"),
    ("Sound None still sent", N, "\tif sound == \"None\" then return nil end\n", ""),
    ("reward without a sound dropped", N, "\tif kind == \"reward\" then return \"\" end -- the client's kind sound (QuestDone)\n", ""),
    ("info without a sound sent", N, "\treturn nil\nend\n\nfunction Net.Notify(", "\treturn \"\"\nend\n\nfunction Net.Notify("),
    ("Notify skips the gate", N, "\tlocal t = Net.NotifyText(text, kind, sound)\n\tif t == nil then return end\n\tNet.Get(\"Notify\"):FireClient(player, { Text = t,",
     "\tlocal t = text\n\tNet.Get(\"Notify\"):FireClient(player, { Text = t,"),
    ("NotifyAll skips the gate", N, "\tlocal t = Net.NotifyText(text, kind, sound)\n\tif t == nil then return end\n\tNet.Get(\"Notify\"):FireAllClients({ Text = t,",
     "\tlocal t = text\n\tNet.Get(\"Notify\"):FireAllClients({ Text = t,"),
    ("NotifyAll default kind info -> still nothing, default bad", N, "\tkind = kind or \"announce\"\n\tlocal t", "\tkind = kind or \"bad\"\n\tlocal t"),
    ("NotifyKey keeps the key", N, "\tif kind ~= \"bad\" then return Net.Notify(player, \"\", kind, duration, sound) end\n", ""),
    ("NotifyAllKey keeps the key", N, "\tif kind ~= \"bad\" then return Net.NotifyAll(\"\", kind, duration, sound) end\n", ""),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0
    # A23-191: the server-wide banners the gate made silent are gone from the sources too
    for name, piece in (("KaijuService.luau", "Config.Story.KaijuStart"), ("PvPService.luau", "fmt(\"MostWanted\""),
                        ("ProgressionService.luau", "Config.Story.Fall"), ("ProgressionService.luau", "Config.Story.Redeem")):
        count += 1
        if piece in strip_comments(read(SSS / name)):
            failures.append(f"{name} still sends {piece}")
    # the remote is only fired from Net.luau (no module goes around the gate)
    for path in sorted(SSS.glob("*.luau")):
        count += 1
        code = strip_comments(read(path))
        if 'Get("Notify")' in code or "Remotes.Notify" in code:
            failures.append(f"{path.name} fires the Notify remote directly")
    return count, failures


SUITE = Suite(
    mark="NOTIFYGATE",
    fixture=ROOT / "tools/fixtures/notify_gate_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-15/offline_notify_gate_2026-10-15.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="Net.NotifyText(text, kind, sound): bad -> text; Sound None -> nothing; a Sound -> '' (sound alone); reward -> '' "
             "(QuestDone); else nothing. Notify / NotifyAll send { Text = that } or nothing; NotifyKey / NotifyAllKey send the "
             "keyed line only for bad, else the plain sound-only line without a Key. KaijuStart, MostWanted, Fall / Redeem "
             "banners removed from their services; no service fires the Notify remote around Net.",
    limitations="The 150-odd call sites that still pass a text for a non-bad kind are left as they are (their text is never "
                "sent; the ones with a Sound are the sound carriers). The client side (UIKit draws only 'bad') is 게임성 개발 1's.",
)

if __name__ == "__main__":
    run(SUITE)
