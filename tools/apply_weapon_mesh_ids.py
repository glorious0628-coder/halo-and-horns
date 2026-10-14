"""Fill Config.WeaponMeshes' MeshId / TextureId from 메인 반영 1's upload table (dev1-weapon-mesh, 최종 검수 10/14).

build/weapon_mesh_ids.json = { "<manifest name, e.g. Weapon_Halo_Paladin_T1>": { "MeshId": "rbxassetid://N",
"TextureId": "rbxassetid://N" }, ... } (jokes: Weapon_Meme_FryingPan / Weapon_Meme_RubberChicken). Each Config row ends
with "-- <manifest name>", so the row is found by that name. Only rbxassetid://<digits> ids are written; a name with no
row is reported. Usage: py tools/apply_weapon_mesh_ids.py [--ids build/weapon_mesh_ids.json] [--check]
(--check = say what would change, write nothing)
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
ID = re.compile(r"^rbxassetid://\d+$")


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids", default=str(ROOT / "build/weapon_mesh_ids.json"))
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    ids_path = Path(a.ids)
    if not ids_path.exists():
        alt = ROOT.parent / "Game/build/weapon_mesh_ids.json"
        ids_path = alt if alt.exists() else ids_path
    ids = json.loads(ids_path.read_text(encoding="utf-8"))
    raw = CONFIG.read_text(encoding="utf-8")
    crlf = "\r\n" in raw
    lines = raw.replace("\r\n", "\n").split("\n")
    a0 = next((i for i, l in enumerate(lines) if l.startswith("Config.WeaponMeshes = {")), None)
    if a0 is None:
        print("Config.WeaponMeshes not found")
        return 1
    a1 = next(i for i in range(a0, len(lines)) if lines[i] == "}")
    changed, unknown, bad = 0, [], []
    for name, v in ids.items():
        mesh, tex = str(v.get("MeshId", "")), str(v.get("TextureId", "") or "")
        if not ID.match(mesh) or (tex and not ID.match(tex)):
            bad.append(name)
            continue
        hit = None
        for i in range(a0, a1):
            if lines[i].rstrip().endswith("-- " + name):
                hit = i
        if hit is None:
            unknown.append(name)
            continue
        new = re.sub(r'MeshId = "[^"]*"', f'MeshId = "{mesh}"', lines[hit])
        new = re.sub(r'TextureId = "[^"]*"', f'TextureId = "{tex}"', new)
        if new != lines[hit]:
            changed += 1
            print(("WOULD SET " if a.check else "SET ") + name + " " + mesh + (" " + tex if tex else ""))
            lines[hit] = new
    if not a.check and changed:
        out = "\n".join(lines)
        CONFIG.write_text(out.replace("\n", "\r\n") if crlf else out, encoding="utf-8")
    print(f"rows set: {changed}; unknown names: {unknown or 'none'}; bad ids: {bad or 'none'}")
    return 0 if not unknown and not bad else 1


if __name__ == "__main__":
    sys.exit(main())
