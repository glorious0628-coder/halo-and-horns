"""게임성 개발 4 gear slots in the Hero window (2026-10-12; contract: the "GearSlots contract" in CharacterUI.luau), offline.

Runs the CURRENT Config.luau and GearSlots.luau in the official Luau CLI (tools/fixtures/gear_slots_ui_offline.luau; the player's
attributes and change signals, a recording Instance tree, UIKit art doubles and the CharacterUI / BagUI / PetWindow registry are
doubles). Checks: Cells (weapon art / grade / +N, no weapon, pet icon / Lv, no pet, the four empty, gear data drop-in), Build draws
six named cells at CharacterUI's columns / rows with one caption each (Style false + TextScaled + max 15), the frame Size 220 x 266 and
opts.Refresh only when it changes, Weapon -> ShowView("Weapons") (else BagUI.Open("Gear")), Pet -> PetWindow.Open, the empty cells do
nothing, the six attributes redraw (connected once), Refresh redraws, the letter fallback. Static: ClientMain loads GearSlots after
UIKit, no Enum.KeyCode, no English outside TXT. Mutations: each must be caught.

Usage: py tools/test_gear_slots_ui.py
Report: docs/art/verification_2026-10-12/offline_gear_slots_ui_2026-10-12.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"GEAR": ROOT / "src/StarterPlayer/StarterPlayerScripts/GearSlots.luau",
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "MAIN": ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau"}
FIXTURE = ROOT / "tools/fixtures/gear_slots_ui_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-12/offline_gear_slots_ui_2026-10-12.json"

MUTATIONS = [
    ("GEAR", "+N not cut to MaxEnhance", "cell.Plus = math.clamp(math.floor(num(ctx.Plus, 0)), 0, Config.Loot.MaxEnhance)",
     "cell.Plus = math.floor(num(ctx.Plus, 0))"),
    ("GEAR", "the weapon grade ignored", "cell.Grade = Config.WeaponGrades[grade] and grade or \"Common\"", "cell.Grade = \"Common\""),
    ("GEAR", "a tier above the last is a weapon", " and tier <= Config.MaxWeaponTier and type(Config.WeaponInfo[tier]) == \"table\"", ""),
    ("GEAR", "pet Lv not cut to MaxLv", "1, Config.Pets.MaxLv)", "1, 999)"),
    ("GEAR", "gear data of every cell taken", "if type(g) == \"table\" and g.Icon ~= nil then", "if true then"),
    ("GEAR", "the pet icon is an item icon", "cell.Name, cell.Icon, cell.Art, cell.Grade = def.Name, def.Icon, true, \"Common\"",
     "cell.Name, cell.Icon, cell.Art, cell.Grade = def.Name, def.Icon, false, \"Common\""),
    ("GEAR", "the empty weapon wears a grade slot", "local part = cell.Grade and L.Slot[cell.Grade] or \"SlotEmpty\"",
     "local part = cell.Grade and L.Slot[cell.Grade] or \"SlotCommon\""),
    ("GEAR", "opts.Refresh never called", "if S.Opts and type(S.Opts.Refresh) == \"function\" then call(S.Opts.Refresh) end", ""),
    ("GEAR", "opts.Refresh called every Build", "if ok and cw == w and ch == h then return end", ""),
    ("GEAR", "Pet Acc in the wrong column", "PetArmor = 0, PetAcc = 1 },\n\tRows", "PetArmor = 0, PetAcc = 2 },\n\tRows"),
    ("GEAR", "Weapon opens the wrong view", "call(ch.ShowView, \"Weapons\")", "call(ch.ShowView, \"Slots\")"),
    ("GEAR", "no bag fallback tab", "call(bag.Open, \"Gear\")", "call(bag.Open, \"Bag\")"),
    ("GEAR", "Pet opens nothing", "if type(pw) == \"table\" then return call(pw.Open) end", "if false then return call(pw.Open) end"),
    ("GEAR", "Armor is pressable", "Pet = \"Pet\", Armor = \"Gear\"", "Pet = \"Pet\", Armor = \"Weapon\""),
    ("GEAR", "no attribute watched", "for _, name in L.Watch do", "for _, name in {} do"),
    ("GEAR", "PetLv not watched", "\"EquippedPet\", \"PetLv\" }", "\"EquippedPet\" }"),
    ("GEAR", "WeaponEnhance not watched", "\"WeaponTier\", \"WeaponEnhance\", \"Class\"", "\"WeaponTier\", \"Class\""),
    ("GEAR", "signals connected on every Build", "if not S.Connected and LocalPlayer then", "if LocalPlayer then"),
    ("GEAR", "Refresh does not redraw", "if S.Frame then redraw() end", "if S.Frame then end"),
    ("GEAR", "a redraw keeps the old cells", "\tclearDrawn()\n\tfor _, cell in GearSlots.Cells", "\tfor _, cell in GearSlots.Cells"),
    ("GEAR", "+N on every cell", "if (cell.Plus or 0) > 0 then", "if true then"),
    ("GEAR", "no letter fallback", "local letter = string.upper(string.match(tostring(cell.Name or \"\"), \"%w\") or \"?\")", "local letter = \"?\""),
    ("GEAR", "captions not scaled", "TextWrapped = false, TextScaled = true, Style = false })", "TextWrapped = false, TextScaled = false, Style = false })"),
    ("GEAR", "caption max size too big", "tc.MaxTextSize = L.Size.Small", "tc.MaxTextSize = 99"),
    ("GEAR", "Lv not bottom-right", "Name = \"Lv\", AnchorPoint = Vector2.new(1, 1)", "Name = \"Lv\", AnchorPoint = Vector2.new(0, 0)"),
    ("GEAR", "the +N ignores the enhance attribute", "Plus = attr(\"WeaponEnhance\")", "Plus = 0"),
    ("GEAR", "a press error escapes", "local ok, err = pcall(fn, ...)", "local ok, err = true, fn(...)"),
    ("MAIN", "GearSlots is never loaded", "\"UIKit\", \"GearSlots\", \"Settings\",", "\"UIKit\", \"Settings\","),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def static(src: dict) -> list[tuple[str, bool]]:
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    lines = [l for l in src["GEAR"].splitlines() if not l.strip().startswith("--")]
    code = "\n".join(lines)
    m = re.search(r"local TXT = \{.*?\n\}\n", code, re.S)
    rest = code.replace(m.group(0), "") if m else code
    rest = "\n".join(l for l in rest.splitlines() if "Util.Warn" not in l and "L10n.Register" not in l)
    words = [s for s in re.findall(r'"([^"\n]*)"', rest) if re.search(r"[A-Za-z]", s) and " " in s.strip()]
    return [
        ("ClientMain loads GearSlots after UIKit", "GearSlots" in names and "UIKit" in names and names.index("GearSlots") > names.index("UIKit")),
        ("no Enum.KeyCode in GearSlots (BB1)", "Enum.KeyCode" not in code),
        ("the words sit in a TXT table registered as GearSlots.TXT", m is not None and "L10n.Register(\"GearSlots.TXT\", TXT)" in code),
        ("no English outside TXT (Util.Warn lines excepted)", not words and "Not " not in rest),
    ]


def run(src: dict) -> tuple[int, int, str]:
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal GEAR_SOURCE = " + lua_str(src["GEAR"]) + "\n"
            + FIXTURE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "gear_slots.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"GEAR_SLOTS_SUMMARY checks=(\d+) failed=(\d+)", out)
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
