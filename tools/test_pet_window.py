"""PET-5 펫 창 (게임성 개발 1, 2026-10-09; server = PET-2 PetService "PetList" / "EquipPet", contract
docs/design/pet4_lost_baby_slime_2026-10-09.md), offline.

Runs, in the official Luau CLI, the CURRENT Config.luau and PetWindow.luau in tools/fixtures/pet_window_offline.luau
(Players / Remotes / Panels / UIKit doubles). Checks: the window "Pet" is registered (the HUD's Pet tile opens it) and
listens to PetList; no pet = one quiet line; a row = the approved pet icon, the story name (else the species name),
Lv + the walk speed it gives (Config.PetSpeedBonus), the XP bar (XP / Need, MAX at the top level); the follower says so
and has [Put away] -> EquipPet(""), a resting pet [Follow me] -> EquipPet(uid), one press per Gap s; a tamer never sees
[Put away] (M1, docs/review/pet2_verify_2026-10-09.md), nor anyone when the server sends CanPutAway = false; an unknown
species cannot follow; the follower first; before the first PetList the follower comes from EquippedPet / PetLv; the
open window redraws only when what it shows changed. Static: ClientMain loads PetWindow after Panels; Config.Pets
species have a Name and Icon. Mutations: each must be caught.

Usage: py tools/test_pet_window.py
Report: docs/art/verification_2026-10-09/offline_pet_window_2026-10-09.json
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
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "MAIN": ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau",
         "HUD": ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau"}
FIXTURE = ROOT / "tools/fixtures/pet_window_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-09/offline_pet_window_2026-10-09.json"

MUTATIONS = [
    ("PET", "the tamer can put its weapon away", "local canPut = payload.CanPutAway ~= false and not tamer",
     "local canPut = payload.CanPutAway ~= false"),
    ("PET", "the server's CanPutAway ignored", "local canPut = payload.CanPutAway ~= false and not tamer",
     "local canPut = not tamer"),
    ("PET", "[Put away] sends the uid", "text, uid, color = T.Text.PutAway, \"\", kit.Palette.Button",
     "text, uid, color = T.Text.PutAway, row.Uid, kit.Palette.Button"),
    ("PET", "double presses go through", "if type(uid) ~= \"string\" or os.clock() - S.PressAt < T.Gap then return false end",
     "if type(uid) ~= \"string\" then return false end"),
    ("PET", "an unknown species can follow", "CanFollow = not on and speciesDef(sp) ~= nil,", "CanFollow = not on,"),
    ("PET", "the story name ignored", "Name = (type(p.Name) == \"string\" and p.Name ~= \"\") and p.Name or speciesName(sp),",
     "Name = speciesName(sp),"),
    ("PET", "no MAX at the top level", "local isMax = lv >= maxLv or need <= 0", "local isMax = false"),
    ("PET", "the follower not first", "if a.Equipped ~= b.Equipped then return a.Equipped end", ""),
    ("PET", "an XP-only change rebuilds the window (a press in progress is lost)",
     "\tif PetWindow.Sig(rows, true) == S.Shape then -- only XP moved: the bars, in place\n",
     "\tif false then -- only XP moved: the bars, in place\n"),
    ("PET", "the bar text stays old", "\t\t\t\tif b.Text then b.Text.Text = PetWindow.BarText(r) end\n", ""),
    ("PET", "the resting pet says 'Walk speed'", "string.format(row.Equipped and T.Text.Speed or T.Text.SpeedRest, row.Speed)",
     "string.format(T.Text.Speed, row.Speed)"),
    ("PET", "small XP numbers again", "BarH = 20, BarText = 15,", "BarH = 20, BarText = 13,"),
    ("PET", "redraws while closed", "and panels.CurrentId() == T.Window", ""),
    ("PET", "no fallback before the first PetList", "\t\tif type(sp) == \"string\" and sp ~= \"\" then\n", "\t\tif false then\n"),
    ("PET", "no speed line", "if row.Speed > 0 then line ..= ", "if false then line ..= "),
    ("CONFIG", "the species has no name", "Name = \"Baby Slime\", Icon = \"IconPetBabySlime\"", "Icon = \"IconPetBabySlime\""),
    ("MAIN", "the window is never loaded", "\"PetWindow\", \"SkillBook\",", "\"SkillBook\","),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def static(src: dict) -> list[tuple[str, bool]]:
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    return [
        ("ClientMain loads PetWindow after Panels", "PetWindow" in names and "Panels" in names
         and names.index("PetWindow") > names.index("Panels")),
        ("the HUD's Pet tile opens the window \"Pet\"",
         '{ Id = "Pet", Icon = "IconPetBabySlime", Window = "Pet", Keep = ' in src["HUD"]),
        ("every Config.Pets species has a Name and an Icon for the window",
         # A23-194 (10/15): 12 species, each row `<Id> = { ... Name = "...", Icon = "..." ...` (Icon "" = the default)
         re.search(r"\n\t\tBabySlime = \{ Speed = \{ 0\.07, 0\.10 \}, Name = \"Baby Slime\", Icon = \"IconPetBabySlime\",",
                   src["CONFIG"]) is not None
         and len(re.findall(r"\n\t\t[A-Z]\w+ = \{ (?:Speed = \{ [\d.]+, [\d.]+ \}, )?Name = \"[^\"]+\", Icon = \"\w*\",",
                            src["CONFIG"].split("Config.Pets = {", 1)[1].split("\n}\n", 1)[0])) == 12),
    ]


def run(src: dict) -> tuple[int, int, str]:
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal PET_SOURCE = " + lua_str(src["PET"]) + "\n"
            + FIXTURE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "pet_window.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"PET_WINDOW_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed = int(m[2]) if m else 1
    st = static(src)
    for name, ok in st:
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
        failed += 0 if ok else 1
    return (int(m[1]) if m else 0) + len(st), failed, out


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
