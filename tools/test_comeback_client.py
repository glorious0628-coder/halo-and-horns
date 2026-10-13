"""A23-167 'first minutes 2x XP' chip (게임성 개발 1, 2026-10-14; server = 게임성 개발 2, docs/design/comeback_server_2026-10-14.md),
offline.

Runs, in the official Luau CLI, the CURRENT HUD pieces cut out of the source with the CURRENT Config.EarlyXP block:
1. L.EarlyXPLeft: whole minutes left of Config.EarlyXP.Seconds from the PlaytimeSeconds attribute (nil when off, over or
   not known yet).
2. L.BoostText: the boost chip's words - the 2x passes as before; with no pass the first minutes' "2x XP · N min"; the
   2x Gold pass during the first minutes reads "2x XP · Gold" (the server never stacks 2x XP: the XP pass alone says 2x XP).
Static: L.RefreshBoost shows the chip from L.BoostText(xp, gold, L.EarlyXPLeft()) and keeps the XP star while the first
minutes run; the tick refreshes the chips (the minutes count down); TXT.EarlyXP takes the minutes. The tomorrow card /
News line live in tools/test_pause_card.py, the slot art in tools/test_attendance_ui.py, the back line in
tools/test_town_react.py. Mutations: each must be caught.

Usage: py tools/test_comeback_client.py
Report: docs/art/verification_2026-10-14/offline_comeback_client_2026-10-14.json (do not commit)
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HUD = ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-14/offline_comeback_client_2026-10-14.json"
CUTS = [("function L.EarlyXPLeft()", "\nend\n"), ("function L.BoostText(xp, gold, early)", "\nend\n")]

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end

local Config = {}
local cfn = assert(loadstring(CONFIG_SOURCE, "=Config.EarlyXP"))
setfenv(cfn, setmetatable({ Config = Config }, { __index = getfenv() }))
cfn()
local E = Config.EarlyXP
check(type(E) == "table" and E.Enabled == true and E.Seconds == 600, "Config.EarlyXP: on, 600 s", E and E.Seconds)

local ATTR = {}
local function num(name, default)
	local v = ATTR[name]
	if type(v) == "number" then return v end
	return default
end
local TXT = { BoostXP = "2x XP", BoostGold = "2x Gold", BoostBoth = "2x XP · Gold", EarlyXP = EARLY_WORDS }
local L = {}
local f = assert(loadstring(HUD_SOURCE, "=HUD"))
setfenv(f, setmetatable({ L = L, num = num, TXT = TXT, Config = Config }, { __index = getfenv() }))
f()

-- 1. L.EarlyXPLeft
ATTR.PlaytimeSeconds = 0
check(L.EarlyXPLeft() == 10, "a new save: 10 minutes", L.EarlyXPLeft())
ATTR.PlaytimeSeconds = 5
check(L.EarlyXPLeft() == 10, "5 s in: still 10 (whole minutes, rounded up)", L.EarlyXPLeft())
ATTR.PlaytimeSeconds = 541
check(L.EarlyXPLeft() == 1, "the last minute: 1", L.EarlyXPLeft())
ATTR.PlaytimeSeconds = 595
check(L.EarlyXPLeft() == 1, "595 s: 1 (the server's 2x still runs)", L.EarlyXPLeft())
ATTR.PlaytimeSeconds = 600
check(L.EarlyXPLeft() == nil, "600 s: over (the server's own line)", L.EarlyXPLeft())
ATTR.PlaytimeSeconds = 3600
check(L.EarlyXPLeft() == nil, "an old save: nothing", L.EarlyXPLeft())
ATTR.PlaytimeSeconds = nil
check(L.EarlyXPLeft() == nil, "no PlaytimeSeconds yet: nothing", L.EarlyXPLeft())
ATTR.PlaytimeSeconds = 0
E.Enabled = false
check(L.EarlyXPLeft() == nil, "switched off: nothing", L.EarlyXPLeft())
E.Enabled = true

-- 2. L.BoostText
check(L.BoostText(false, false, 7) == "2x XP · 7 min", "no pass, first minutes: 2x XP with the minutes", L.BoostText(false, false, 7))
check(L.BoostText(false, false, nil) == nil, "no pass, after: no chip", L.BoostText(false, false, nil))
check(L.BoostText(true, false, 7) == "2x XP", "the XP pass: its own words (never stacked)", L.BoostText(true, false, 7))
check(L.BoostText(true, false, nil) == "2x XP", "the XP pass after: the same", "")
check(L.BoostText(false, true, 7) == "2x XP · Gold", "the Gold pass in the first minutes: both", L.BoostText(false, true, 7))
check(L.BoostText(false, true, nil) == "2x Gold", "the Gold pass after: gold only", L.BoostText(false, true, nil))
check(L.BoostText(true, true, nil) == "2x XP · Gold", "both passes: both", "")
check(L.BoostText(false, false, 0) == nil, "0 minutes: no chip", "")

print(string.format("COMEBACK_SUMMARY checks=%d failed=%d", checks, failed))
'''

MUTATIONS = [
    ("minutes rounded down", "return left > 0 and math.ceil(left / 60) or nil", "return left > 0 and math.floor(left / 60) or nil"),
    ("never over", "return left > 0 and math.ceil(left / 60) or nil", "return math.ceil(left / 60)"),
    ("the switch ignored", "\tif type(e) ~= \"table\" or e.Enabled ~= true then return nil end\n",
     "\tif type(e) ~= \"table\" then return nil end\n"),
    ("an unknown playtime counts as a new save", "num(\"PlaytimeSeconds\", math.huge)", "num(\"PlaytimeSeconds\", 0)"),
    ("the XP pass shows the minutes too", "\tif xp then return TXT.BoostXP end\n", ""),
    ("the Gold pass hides the first minutes", "return (xp or first) and TXT.BoostBoth or TXT.BoostGold",
     "return xp and TXT.BoostBoth or TXT.BoostGold"),
    ("no chip in the first minutes", "return first and string.format(TXT.EarlyXP, early) or nil", "return nil"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def cut(text: str) -> str:
    out = []
    for start, end in CUTS:
        a = text.find(start)
        if a < 0:
            return ""
        b = text.find(end, a)
        if b < 0:
            return ""
        out.append(text[a:b + len(end)])
    return "\n".join(out)


def early_words(h: str) -> str | None:
    m = re.search(r'^\tEarlyXP = "([^"]*)",', h, re.M)
    return m[1] if m else None


def early_block(config: str) -> str:
    """the Config.EarlyXP table as it stands in Config.luau (only that block runs)"""
    m = re.search(r"^Config\.EarlyXP = \{\n.*?^\}\n", config, re.M | re.S)
    return m[0] if m else ""


def run(hud: str, config: str) -> tuple[int, int, str]:
    words = early_words(hud)
    text = ("local HUD_SOURCE = " + lua_str(cut(hud)) + "\nlocal CONFIG_SOURCE = " + lua_str(early_block(config))
            + "\nlocal EARLY_WORDS = " + (lua_str(words) if words is not None else "nil") + "\n" + FIXTURE)
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "comeback.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=180)
    out = proc.stdout + proc.stderr
    m = re.search(r"COMEBACK_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (int(m[1]) if m else 0), (int(m[2]) if m else 1), out


def statics(h: str) -> list[tuple[str, bool]]:
    return [
        ("RefreshBoost shows the chip from BoostText with the first minutes",
         "local early = L.EarlyXPLeft()\n\tlocal words = L.BoostText(xp, gold, early)\n"
         "\tsetChip(chip, words ~= nil, words, Theme.Gold, true, nil, true)" in h),
        ("the XP star while the first minutes run (the gold pile only for the Gold pass alone)",
         'local key = (gold and not xp and not early) and "IconGoldPile" or "IconExp"' in h),
        ("the tick refreshes the chips (the minutes count down)", re.search(r"local function tick\(\).*?\n\trefreshChips\(\)\n", h,
                                                                           re.S) is not None),
        ("TXT.EarlyXP takes the minutes", (early_words(h) or "").count("%d") == 1),
    ]


STATIC_MUTATIONS = [
    ("the chip ignores the first minutes", "\tlocal words = L.BoostText(xp, gold, early)\n", "\tlocal words = L.BoostText(xp, gold, nil)\n"),
    ("the gold pile in the first minutes", "(gold and not xp and not early)", "(gold and not xp)"),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    hud = HUD.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    found = cut(hud) != ""
    checks, failed, out = run(hud, config)
    print(out.strip())
    st = [{"check": n, "ok": ok} for n, ok in statics(hud)]
    for s in st:
        print(("STATIC_OK  " if s["ok"] else "STATIC_FAIL ") + s["check"])
    muts = []
    for name, old, new in MUTATIONS:
        hits = hud.count(old)
        caught = hits == 1 and run(hud.replace(old, new), config)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    for name, old, new in STATIC_MUTATIONS:
        hits = hud.count(old)
        caught = hits == 1 and not all(ok for _, ok in statics(hud.replace(old, new)))
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    ok = found and failed == 0 and checks > 0 and all(s["ok"] for s in st) and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "static": st, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
