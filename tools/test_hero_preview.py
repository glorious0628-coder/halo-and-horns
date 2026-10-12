"""ref_rpg_ui #3 Hero window 3D body (HeroPreview, 게임성 개발 1, 2026-10-13; design docs/design/ref_rpg_ui_2026-10-12.md #3,
BB8b), offline.

Runs, in the official Luau CLI, the CURRENT HeroPreview.luau (tools/fixtures/hero_preview_offline.luau) on doubles. The copy
keeps the weapon (WeaponModel), the halo / horns (FactionMark), parts, accessories, welds, joints and the humanoid; it drops
scripts, UI, effects, sounds, lights, movers, rope-type constraints, tools, the name tag and the glows / grudge ghost. Turn =
dragged pixels x DragDeg kept in 0..360; Distance fits the body's height or its turning width (the diagonal), whichever needs
more. Mount = the approved PanelCard (a plain frame without the art) holding a see-through, inset, input-taking
ViewportFrame with its own Camera, WorldModel and light; left-drag on the view turns it (a move without a press, the right
button or another finger do not), let go stops it; a new character is watched and a swapped piece (ChildAdded / Removed)
asks a new copy. Unmount disconnects everything and destroys the card. Static: the copy is anchored, takes the source's
CFrame / joint pose, never shows in first person, restores Archivable; CharacterUI only reaches it through C.HeroPreview.
The character copy itself is checked in Studio photos (tools/play_character_ui_photos.py). Mutations: each must be caught.

Usage: py tools/test_hero_preview.py
Report: docs/art/verification_2026-10-13/offline_hero_preview_2026-10-13.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"HERO": SPS / "HeroPreview.luau", "UI": SPS / "CharacterUI.luau", "MAIN": SPS / "ClientMain.client.luau"}
FIXTURE = ROOT / "tools/fixtures/hero_preview_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-13/offline_hero_preview_2026-10-13.json"

MUTATIONS = [
    ("HERO", "the name tag kept", "Drop = { Nametag = true, GrudgeGhost = true,", "Drop = { GrudgeGhost = true,"),
    ("HERO", "the weapon dropped", "Drop = { Nametag = true, GrudgeGhost = true,", "Drop = { WeaponModel = true, Nametag = true, GrudgeGhost = true,"),
    ("HERO", "scripts kept", 'Gone = { "LuaSourceContainer", ', "Gone = { "),
    ("HERO", "ropes kept", 'if inst:IsA("Constraint") and not inst:IsA("WeldConstraint") then return false end', ""),
    ("HERO", "welds dropped", 'if inst:IsA("Constraint") and not inst:IsA("WeldConstraint") then return false end',
     'if inst:IsA("Constraint") then return false end'),
    ("HERO", "the turn not wrapped", "* L.DragDeg) % 360", "* L.DragDeg)"),
    ("HERO", "the width ignored", "local need = math.max(h / 2 / t, r / (t * math.max(0.1, aspect)))", "local need = h / 2 / t"),
    ("HERO", "the aspect ignored", "r / (t * math.max(0.1, aspect))", "r / t"),
    ("HERO", "turned without a press", "\t\tlocal d = S.Drag\n\t\tif not d then return end\n", "\t\tlocal d = S.Drag or { X = 0 }\n"),
    ("HERO", "the right button turns", "if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then",
     "if t ~= Enum.UserInputType.Keyboard then"),
    ("HERO", "any finger turns", "(t == Enum.UserInputType.Touch and input == d.Input)", "t == Enum.UserInputType.Touch"),
    ("HERO", "never lets go", "then S.Drag = nil end", "then end"),
    ("HERO", "a swapped weapon not copied", "\t\ttable.insert(S.CharConns, character.ChildAdded:Connect(HeroPreview.Refresh))\n", ""),
    ("HERO", "connections kept after closing", "\tdisconnect(S.Conns)\n\tdisconnect(S.CharConns)\n", "\tdisconnect(S.CharConns)\n"),
    ("HERO", "the card left behind", "\tif S.Card then pcall(function() S.Card:Destroy() end) end\n", ""),
    ("HERO", "no art fallback", "\tif not card then\n\t\tcard = Instance.new(\"Frame\")", "\tif false then\n\t\tcard = Instance.new(\"Frame\")"),
    ("HERO", "the view takes no input", "\tview.Active = true\n", ""),
    ("HERO", "refresh while closed", "function HeroPreview.Refresh()\n\tif not S.View then return end\n", "function HeroPreview.Refresh()\n"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    eq = "=" * level
    return "[" + eq + "[\n" + s + "]" + eq + "]"


def static(src: dict) -> list[tuple[str, bool]]:
    hero = src["HERO"]
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    return [
        ("the copy stands still where I am (anchored, no collisions / touches / queries, the source's CFrame)",
         "\t\t\ttarget.Anchored = true\n\t\t\ttarget.CanCollide = false\n\t\t\ttarget.CanTouch = false\n\t\t\ttarget.CanQuery = false\n"
         in hero and "\t\t\ttarget.CFrame = source.CFrame\n" in hero),
        ("the copy keeps the pose of this moment (Motor6D / Bone Transform) and shows in first person (LocalTransparencyModifier 0)",
         "pcall(function() target.Transform = source.Transform end)" in hero and "target.LocalTransparencyModifier = 0" in hero),
        ("my character's Archivable is put back after the copy",
         "local archivable = character.Archivable\n\tcharacter.Archivable = true\n\tlocal ok, copy = pcall(function() return character:Clone() end)\n\tcharacter.Archivable = archivable\n" in hero),
        ("no name / health over the copy", "target.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None" in hero),
        ("the copy goes in only once every script / effect is out (parented after the strip)",
         hero.index("for source, target in map do") < hero.index("copy.Parent = S.World")),
        ("no player text in HeroPreview (no Text =)", re.search(r"\bText\s*=", hero) is None),
        ("CharacterUI reaches it only through C.HeroPreview (no require)", 'require(script.Parent:WaitForChild("HeroPreview"))' not in src["UI"]
         and "local h = C and C.HeroPreview" in src["UI"]),
        ("ClientMain loads HeroPreview once", names.count("HeroPreview") == 1),
    ]


def run(src: dict) -> tuple[int, int, str]:
    text = "local HERO_SOURCE = " + lua_str(src["HERO"]) + "\n" + FIXTURE.read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "hero_preview.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"HERO_PREVIEW_SUMMARY checks=(\d+) failed=(\d+)", out)
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
