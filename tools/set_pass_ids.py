"""Put the game pass ids the user made into Config (A23-156 / A23-160: 9 passes = Config.GamePasses 5 + Config.Looks 4).

Usage: py tools/set_pass_ids.py XP2=123 Gold2=456 VIP=789 Stickers=... Bubbles=... HaloIce=... HaloGold=... HornsLava=... HornsShadow=...
       [--check]   (--check = show what would change, write nothing)
Only `Id = <n>` inside the named Config.GamePasses row and `PassId = <n>` inside the named Config.Looks row change; anything else
in Config stays byte-identical. An id is a whole number > 0. Prints each change and which of the 9 are still 0.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

CONFIG = Path(__file__).resolve().parents[1] / "src/ReplicatedStorage/Shared/Config.luau"
PASSES = ["XP2", "Gold2", "VIP", "Stickers", "Bubbles"]
LOOKS = ["HaloIce", "HaloGold", "HornsLava", "HornsShadow"]


def block(text: str, head: str) -> tuple[int, int]:
    start = text.index(head)
    return start, text.index("\n}", start)


def row_pattern(key: str, field: str) -> re.Pattern:
    return re.compile(r"(\n\t" + re.escape(key) + r" = \{[^\n]*?\b" + field + r" = )(\d+)")


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    check = "--check" in argv
    wanted: dict[str, int] = {}
    for arg in argv:
        if arg == "--check":
            continue
        m = re.fullmatch(r"(\w+)=(\d+)", arg)
        if not m or m[1] not in PASSES + LOOKS or int(m[2]) <= 0:
            print(f"bad argument {arg!r}: use <key>=<id>, key one of {', '.join(PASSES + LOOKS)}", file=sys.stderr)
            return 2
        wanted[m[1]] = int(m[2])
    raw = CONFIG.read_bytes()
    text = raw.decode("utf-8")
    ids: dict[str, int] = {}
    for keys, head, field in ((PASSES, "Config.GamePasses = {", "Id"), (LOOKS, "Config.Looks = {", "PassId")):
        start, end = block(text, head)
        part = text[start:end]
        for key in keys:
            found = row_pattern(key, field).findall(part)
            if len(found) != 1:
                print(f"{key}: its row in {head} was not found once; Config changed? nothing written", file=sys.stderr)
                return 1
            ids[key] = int(found[0][1])
            if key in wanted and wanted[key] != ids[key]:
                part = row_pattern(key, field).sub(lambda m: m[1] + str(wanted[key]), part, count=1)
                print(f"{key}: {ids[key]} -> {wanted[key]}")
                ids[key] = wanted[key]
        text = text[:start] + part + text[end:]
    seen = [v for v in ids.values() if v > 0]
    if len(seen) != len(set(seen)):
        print("the same id twice; nothing written", file=sys.stderr)
        return 1
    still = [k for k, v in ids.items() if v == 0]
    print("still 0: " + (", ".join(still) if still else "none (all 9 set)"))
    if not check and text.encode("utf-8") != raw:
        CONFIG.write_bytes(text.encode("utf-8"))
        print(f"written: {CONFIG}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
