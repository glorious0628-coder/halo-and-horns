"""A23-32 bag sort '얻은 순': the server's order numbers (data.ItemSeq / WeaponSeq / ItemSeqNext), offline.

Runs the CURRENT Config, Util and LootService sources in tools/fixtures/item_seq_offline.luau on
tools/fixtures/dev2_kit.luau with the installed official Luau CLI. No Studio, network, DataStore or Roblox API calls.
Mutations run on in-memory copies of the sources only.

Spec: docs/SPEC_ADDENDUM.md A23-32; docs/design/beta_basics_2026-10-05.md BB7 '사용자 결정 2026-10-06' (정렬 '얻은 순':
아이템마다 마지막으로 얻은 순번, 서버 저장 값).
Usage: py tools/test_item_seq.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_dev2_item_seq_2026-10-06.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "LOOT_SOURCE": SSS / "LootService.luau",
}


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


C, L = "CONFIG_SOURCE", "LOOT_SOURCE"
MUTATIONS = [
    ("the counter never moves", C, "\td.ItemSeqNext = n\n", ""),
    ("a weapon gain written as an item key", C, "\tif tier ~= nil then\n\t\td.WeaponSeq[tier] = n", "\tif false then\n\t\td.WeaponSeq[tier] = n"),
    ("unknown keys kept", C, "(Config.Loot.Items[k] ~= nil or Config.ItemSeqPotions[k] ~= nil)", "true"),
    ("the counter may repeat a used number", C, "d.ItemSeqNext = math.max(int(d.ItemSeqNext), top)", "d.ItemSeqNext = int(d.ItemSeqNext)"),
    ("no weapon array for an old save", C, "\t\tweapons[tier] = int(old[tier])\n", ""),
    ("addItem notes nothing", L, "\tConfig.NoteGained(data, id) -- A23-32 '얻은 순'\n", ""),
    ("addItem notes before the full-stack check", L,
     "\tif given <= 0 then return 0 end\n\tdata.Items[id] = have + given\n\tConfig.NoteGained(data, id)",
     "\tConfig.NoteGained(data, id)\n\tif given <= 0 then return 0 end\n\tdata.Items[id] = have + given"),
    ("payload without ItemSeq", L, "ItemSeq = itemSeq, WeaponSeq = weaponSeq, Spares = spares }", "WeaponSeq = weaponSeq, Spares = spares }"),
    ("payload without WeaponSeq", L, "ItemSeq = itemSeq, WeaponSeq = weaponSeq, Spares = spares }", "ItemSeq = itemSeq, Spares = spares }"),
    ("potions never noted", L, "\t\t\t\tConfig.NoteGained(d, key)\n\t\t\t\treturn true", "\t\t\t\treturn true"),
    ("using a potion counts as a gain", L, "\t\t\t\tif v <= was then return false end\n", ""),
    ("weapons never noted", L, "\t\t\t\t\tConfig.NoteGained(d, nil, tier)\n", ""),
    ("selling a weapon counts as a gain", L, "if bit32.btest(v, bit) and not bit32.btest(was, bit) then",
     "if bit32.btest(v, bit) ~= bit32.btest(was, bit) then"),
    ("the loaded stats count as gains", L, "\t\t\tseen[attr] = math.floor(num(player:GetAttribute(attr)))\n\t\t\tplayer:GetAttributeChangedSignal",
     "\t\t\tseen[attr] = 0\n\t\t\tplayer:GetAttributeChangedSignal"),
    ("a noted gain is never pushed", L, "\t\t\t\tif d and onChange(d, v, was) then publish(player, d) end",
     "\t\t\t\tif d then onChange(d, v, was) end"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    data = read(SSS / "DataService.luau")
    fill = function_block(data, "local function fillDefaults(")
    check("Config.SanitizeItemSeq(d)" in fill, "DataService.fillDefaults repairs the ItemSeq fields of every loaded save")
    loot = read(SSS / "LootService.luau")
    check(loot.count("Config.NoteGained(") == 5 and "function LootService.GrantMarketWeapon(" in loot and "if not STATE.Watching[player] then Config.NoteGained(data, nil, tier) end" in loot,
          "LootService notes gains in 5 places (addItem, potion watcher, weapon watcher, the market weapon, and the A23-34 first-weapon gift "
          "only while the watcher is not connected yet)")
    # every potion / weapon-ownership write in the server goes through PlayerService.SetStat (mirrored -> the watcher)
    raw = []
    for path in sorted(SSS.glob("*.luau")):
        for line in read(path).splitlines():
            code = line.split("--", 1)[0]
            for key in ("HPPotionCount", "MPPotionCount", "WeaponOwnedMask"):
                if f"data.{key} =" in code or f"d.{key} =" in code:
                    raw.append(f"{path.name}: {code.strip()}")
    allowed = ("DataService.luau",)  # load-time repair before PlayerReady (not a gain)
    bad = [r for r in raw if not r.startswith(allowed)]
    check(not bad, f"potion / weapon ownership changes outside the load repair go through SetStat (watched): {bad}")
    config = read(SHARED / "Config.luau")
    head = "\tMirrored = {"
    mirrored = config.split(head, 1)[1].split("\n\t},", 1)[0] if head in config else ""
    check(all(f'"{k}"' in mirrored for k in ("HPPotionCount", "MPPotionCount", "WeaponOwnedMask")),
          "the watched stats are mirrored attributes (Config.Data.Mirrored)")
    return count, failures


SUITE = Suite(
    mark="ITEM_SEQ",
    fixture=ROOT / "tools/fixtures/item_seq_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-06/offline_dev2_item_seq_2026-10-06.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-32 '얻은 순': data.ItemSeq[item id | PotionHP | PotionMP] and data.WeaponSeq[tier] hold the number of the "
             "last gain from the one counter data.ItemSeqNext (bigger = more recent, 0 = an old save / never). Gains: "
             "LootService.addItem (drops, the first-scroll grant, DebugGive), and a rise of the mirrored HPPotionCount / "
             "MPPotionCount or a new WeaponOwnedMask bit from any service (shop, quests, story, drops); using / selling "
             "and the values a save loads with are not gains. Config.SanitizeItemSeq (DataService.fillDefaults) keeps only "
             "known keys and positive integers, a dense weapon array, and a counter never below a used number. The owner's "
             "Inventory payload carries ItemSeq and WeaponSeq; a rejoin keeps them.",
    limitations="Offline doubles: Players / attributes (changed signals fire on a real change, synchronously), a "
                "PlayerService double (data rows, SetStat mirror), DataService's load is stood in by the defaults fill + "
                "Config.SanitizeItemSeq (the fillDefaults call is checked statically). The bag window's sort (BB7, client) is "
                "the 게임성 개발 session's and is not certified here.",
)

if __name__ == "__main__":
    run(SUITE)
