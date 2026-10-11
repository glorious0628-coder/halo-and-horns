"""조련사 펫 창 몫 (게임성 개발 4, 2026-10-12; server 개발 3 origin/dev3-tamer dccbc1e5, docs/design/tamer_server_2026-10-12.md
§7: PetList rows carry Roll = { Spd }, the follower's attribute PetRoll, c->s FeedPet(uid); switch Config.Features.Research),
offline.

Runs the CURRENT Config.luau and PetWindow.luau in the official Luau CLI (tools/fixtures/pet_tamer_offline.luau; the pet
window test's doubles + FeedPet, Panels.LastInventory, kit.SetEnabled; Config.PetSpeedBonus wrapped to see the roll).
Checks: a summoned pet's roll goes into Config.PetSpeedBonus (Lv1 = roll %), a found pet passes none; before the first
PetList the follower's roll is the attribute PetRoll (0 = none); a PetRoll change redraws; "Born with +N% speed" on a
rolled pet only; research off = no [Feed] and Feed sends nothing; research on = [Feed (n)] per pet (n = Pet Treats in the
bag), off at the top level or with none, FeedPet(uid) once per Gap; the count updates in place (no rebuild); a fed pet's
XP-only PetList moves the bar in place. Mutations: each must be caught.

Usage: py tools/test_pet_tamer.py
Report: docs/art/verification_2026-10-12/offline_pet_tamer_2026-10-12.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"PET": ROOT / "src/StarterPlayer/StarterPlayerScripts/PetWindow.luau",
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau"}
FIXTURE = ROOT / "tools/fixtures/pet_tamer_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-12/offline_pet_tamer_2026-10-12.json"

MUTATIONS = [
    ("PET", "a summoned pet's roll is not passed",
     "Equipped = on, Speed = math.floor(Config.PetSpeedBonus(sp, lv, roll) * 100 + 0.5), Roll = roll,",
     "Equipped = on, Speed = math.floor(Config.PetSpeedBonus(sp, lv) * 100 + 0.5), Roll = roll,"),
    ("PET", "the follower's PetRoll ignored", "\t\t\tlocal roll = rollOf(ctx.PetRoll)\n", "\t\t\tlocal roll = nil\n"),
    ("PET", "a roll of 0 counts", "return n > 0 and math.floor(n) or nil", "return math.floor(n)"),
    ("PET", "no born line",
     "\tif row.Roll then label(kit, mid, string.format(T.Text.Born, row.Roll), 16, kit.Theme.SubText, nil, \"Body\") end\n", ""),
    ("PET", "a PetRoll change keeps the old window", "PetLv = true, PetRoll = true,", "PetLv = true,"),
    ("PET", "feed while research is off", "return type(Config.FeatureOn) == \"function\" and Config.FeatureOn(\"Research\") == true and R ~= nil",
     "return R ~= nil"),
    ("PET", "feed on at the top level", "Enabled = not isMax and num(feed.Count, 0) >= 1", "Enabled = num(feed.Count, 0) >= 1"),
    ("PET", "feed with no treat", "Enabled = not isMax and num(feed.Count, 0) >= 1", "Enabled = not isMax"),
    ("PET", "feed twice within the gap", "or not feedOn() or os.clock() - S.FeedAt < T.Gap then return false end",
     "or not feedOn() then return false end"),
    ("PET", "the treat count never updates", "\t\tshown = n\n\t\tPetWindow.PaintFeeds(n)\n", "\t\tshown = n\n"),
    ("PET", "the small lines below the UIKit floor", "\tlabel(kit, mid, line, 16, kit.Theme.SubText, nil, \"Body\")\n",
     "\tlabel(kit, mid, line, 16, kit.Theme.SubText)\n"),
    ("PET", "a styled line loses its colour", "\t\tpcall(ui.StyleText, l, style)\n\t\tl.TextColor3 = color\n", "\t\tpcall(ui.StyleText, l, style)\n"),
    ("PET", "the row keeps the icon's height", "\tf.AutomaticSize = Enum.AutomaticSize.Y\n", ""),
    ("PET", "the live count turns the top level on", "kit.SetEnabled(f.Button, n >= 1 and not f.Max)", "kit.SetEnabled(f.Button, n >= 1)"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(src: dict) -> tuple[int, int, str]:
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal PET_SOURCE = " + lua_str(src["PET"]) + "\n"
            + FIXTURE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "pet_tamer.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"PET_TAMER_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (int(m[1]) if m else 0), (int(m[2]) if m else 1), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    checks, failed, out = run(src)
    print(out.strip())
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        caught = False
        if hits == 1:
            m = dict(src)
            m[key] = src[key].replace(old, new)
            caught = run(m)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    status = "passed" if failed == 0 and checks > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
