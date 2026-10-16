"""SignFit (게임성 개발 1, 게임 플레이 2판·3판 2026-10-16), offline.

Runs, in the official Luau CLI, the CURRENT SignFit.luau's pure SignFit.Plan: nearest sign first; a farther sign that
touches a kept one ('Forge' over 'Altar of Fate') is hidden, the nearer stays; a sign on the quest goal box is hidden;
apart signs both stay; a hidden sign needs Back px more room before it shows again (no blinking). Static: ClientMain
loads SignFit; the story marks / name tags are skipped. Mutations: each must be caught.

Usage: py tools/test_sign_fit.py
"""
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"FIT": ROOT / "src/StarterPlayer/StarterPlayerScripts/SignFit.luau",
         "MAIN": ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"

FIXTURE = r'''
local game = { GetService = function(_, name) return {} end }
local warn = print
local Vector2 = { zero = { X = 0, Y = 0 } }
local SignFit = (function() SIGNFIT_SOURCE_BODY end)()
local n, failed = 0, 0
local function check(v, name, detail)
    n += 1
    if v then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
-- 'Forge' (near) and 'Altar of Fate' (far) on the same spot
local h = SignFit.Plan({ { Key = "Altar", D = 30, X = 700, Y = 300, W = 300, H = 40 },
    { Key = "Forge", D = 12, X = 560, Y = 310, W = 120, H = 40 } }, {})
check(h.Altar == true and h.Forge == nil, "overlap: the farther sign hides, the nearer stays", tostring(h.Altar) .. tostring(h.Forge))
h = SignFit.Plan({ { Key = "A", D = 30, X = 200, Y = 100, W = 100, H = 30 }, { Key = "B", D = 10, X = 600, Y = 100, W = 100, H = 30 } }, {})
check(next(h) == nil, "apart signs both stay")
h = SignFit.Plan({ { Key = "Pad", D = 20, X = 200, Y = 420, W = 220, H = 30 } }, { { X = 10, Y = 410, W = 300, H = 90 } })
check(h.Pad == true, "a sign on the quest goal box hides")
h = SignFit.Plan({ { Key = "Pad", D = 20, X = 200, Y = 300, W = 220, H = 30 } }, { { X = 10, Y = 410, W = 300, H = 90 } })
check(h.Pad == nil, "a sign above the goal stays")
-- 6 px gap: shown stays shown (Pad 4), hidden stays hidden (Pad 4 + Back 8)
local gap = { Key = "Pad", D = 20, X = 200, Y = 410 - 6 - 15, W = 220, H = 30 }
h = SignFit.Plan({ gap }, { { X = 10, Y = 410, W = 300, H = 90 } })
check(h.Pad == nil, "6 px from the goal: shown")
gap.Hid = true
h = SignFit.Plan({ gap }, { { X = 10, Y = 410, W = 300, H = 90 } })
check(h.Pad == true, "6 px from the goal, hidden before: stays hidden (no blinking)")
print("SIGN_FIT_SUMMARY checks=" .. n .. " failed=" .. failed)
'''

MUTATIONS = [
    ("FIT", "the nearer hides (no sort)", "table.sort(list, function(a, b) return a.D < b.D end)",
     "table.sort(list, function(a, b) return a.D > b.D end)"),
    ("FIT", "the goal box ignored", "\t\t\tif overlaps(e, k, pad) then hide = true break end\n", "\t\t\tif false then hide = true break end\n"),
    ("FIT", "signs never hide each other", "then hide = true break end\n\t\t\tend\n\t\tend\n\t\tif hide",
     "then hide = false break end\n\t\t\tend\n\t\tend\n\t\tif hide"),
    ("FIT", "no room to come back", "local pad = T.Pad + (e.Hid and T.Back or 0)", "local pad = T.Pad"),
    ("MAIN", "never loaded", "\"LightCap\", \"SignFit\",", "\"LightCap\","),
]


def run(src: dict) -> tuple[int, str]:
    body = src["FIT"]
    body = body.rsplit("return SignFit", 1)[0] + "return SignFit"
    text = FIXTURE.replace("SIGNFIT_SOURCE_BODY", body)
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "sign_fit.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=60)
    out = proc.stdout + proc.stderr
    m = re.search(r"SIGN_FIT_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed = int(m[2]) if m else 1
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    ok = order is not None and '"SignFit"' in order.group(1)
    out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + "ClientMain loads SignFit"
    failed += 0 if ok else 1
    skip = all(k in src["FIT"] for k in ("Nametag = true", "StoryNpcMark = true", "StoryFindBubble = true"))
    out += ("\nSTATIC_OK " if skip else "\nSTATIC_FAIL ") + "name tags / story marks never hidden"
    failed += 0 if skip else 1
    return failed, out


def main() -> int:
    src = {k: v.read_text(encoding="utf-8") for k, v in FILES.items()}
    failed, out = run(src)
    print(out)
    caught = 0
    for key, name, old, new in MUTATIONS:
        if old not in src[key]:
            print(f"MUTATION_MISSED (text not found): {name}")
            continue
        m = dict(src)
        m[key] = src[key].replace(old, new, 1)
        f, _ = run(m)
        if f > 0:
            caught += 1
            print(f"mutation caught: {name}")
        else:
            print(f"MUTATION_SURVIVED: {name}")
    good = failed == 0 and caught == len(MUTATIONS)
    print(f"Status: {'passed' if good else 'failed'} (failed {failed}, mutations {caught}/{len(MUTATIONS)})")
    return 0 if good else 1


if __name__ == "__main__":
    sys.exit(main())
