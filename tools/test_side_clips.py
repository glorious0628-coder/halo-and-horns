"""Class x side attack moves (게임성 개발 1, SPEC A23-108 ④, Halo first), static / offline.

Reads the CURRENT Fx.luau and Config.luau. Checks: every MOTION.SIDE_CLIPS row is a Config.ClassGrips key and names
clips that exist; each side clip fits its class (Len <= SwingInterval x SWING_FIT), its keys run in time order from 0 to
Len, every joint is a real R15 joint, consecutive keys stay under 180 degrees apart per axis (the slerp rule), its
strike key sits on the class's contact time (Paladin = SLASH_CONTACT, Light Mage = CAST_DELAY) so the slash / cast art
and the sound still land on it; Feel.playAttack takes the side clips (not for a style like bare hands / the pet) by the
attacker's Faction attribute. A23-128 (검수 10/11): the warriors' one-hand sword clips (Paladin / Berserker) never put
the empty left fist on the hilt beside the right (the free arm balances) and their notes say no both hands / great
sword. Mutations: each must be caught. The look is checked in Studio photos (메인 반영 1).

Usage: py tools/test_side_clips.py
Report: docs/art/verification_2026-10-10/offline_side_clips_2026-10-10.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
FX = ROOT / "src/StarterPlayer/StarterPlayerScripts/Fx.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_side_clips_2026-10-10.json"
JOINTS = {"Waist", "Neck", "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist"}
STRIKE = {"PaladinSwing": ("SLASH_CONTACT", "Warrior"), "LightMageSwing": ("CAST_DELAY", "Mage"),
          "PaladinRelease": ("RELEASE_CONTACT.Warrior", "Warrior"), "LightMageRelease": ("RELEASE_CONTACT.Mage", "Mage"),
          # A23-116 Q (the Horns side + the Ranger)
          "BerserkerRelease": ("RELEASE_CONTACT.Warrior", "Warrior"), "DarkMageRelease": ("RELEASE_CONTACT.Mage", "Mage"),
          "RangerRelease": ("RELEASE_LAUNCH.Archer", "Archer"), "ShadowHunterRelease": ("RELEASE_LAUNCH.Archer", "Archer")}
# Z / X (A23-108 ⑤, off until the 10/20 check): one strike key each, inside the clip
ONE_HAND = ("PaladinSwing", "PaladinRelease", "PaladinZ", "PaladinX", "BerserkerRelease", "BerserkerZ", "BerserkerX")
ZX = {"PaladinZ", "PaladinX", "LightMageZ", "LightMageX", "BerserkerZ", "DarkMageZ", "RangerZ", "ShadowHunterZ",
      "BerserkerX", "DarkMageX", "RangerX", "ShadowHunterX"}


def clip(fx: str, name: str):
    m = re.search(r"\t\t" + name + r" = \{ Len = ([\d.]+),[^\n]*?Keys = \{[^\n]*\n(.*?)\n\t\t\} \},", fx, re.S)
    if not m:
        return None
    keys = []
    for line in m.group(2).split("\n"):
        k = re.match(r'\s*\{ ([\d.]+), "(\w+)", \{(.*)\} \},\s*$', line)
        if not k:
            continue
        joints = {j: tuple(float(v) for v in a.split(",")) for j, a in re.findall(r"(\w+) = \{ ([-\d., ]+) \}", k.group(3))}
        keys.append((float(k.group(1)), k.group(2), joints))
    return float(m.group(1)), keys


def num(src: str, pat: str):
    m = re.search(pat, src)
    return float(m.group(1)) if m else None


def checks(fx: str, cfg: str) -> list[tuple[str, bool]]:
    out = []
    side = fx[fx.find("\tSIDE_CLIPS = {"):fx.find("\tCLASS_CLIPS = {")]
    rows = []
    for key, body in re.findall(r"(\w+_\w+) = \{ ([^}]*) \}", side):
        for move, name in re.findall(r"(Swing|Release|Z|X) = \"(\w+)\"", body):
            rows.append((key, name))
    grips = cfg[cfg.find("Config.ClassGrips = {"):cfg.find("function Config.ClassGripKey")]
    out.append(("Halo's Paladin and Light Mage have their own swing", ("Warrior_Halo", "PaladinSwing") in rows
                and ("Mage_Halo", "LightMageSwing") in rows))
    out.append(("... and their own Q (release)", ("Warrior_Halo", "PaladinRelease") in rows and ("Mage_Halo", "LightMageRelease") in rows))
    out.append(("A23-116: every side's own Q", all((k, n) in rows for k, n in [("Warrior_Horns", "BerserkerRelease"),
        ("Mage_Horns", "DarkMageRelease"), ("Archer_Halo", "RangerRelease"), ("Archer_Horns", "ShadowHunterRelease")])))
    out.append(("... and their own Z / X; the Ranger's Z is the solved draw", all((k, n) in rows for k, n in [
        ("Warrior_Halo", "PaladinZ"), ("Warrior_Halo", "PaladinX"), ("Mage_Halo", "LightMageZ"), ("Mage_Halo", "LightMageX"),
        ("Archer_Halo", "RangerZ"), ("Warrior_Horns", "BerserkerZ"), ("Mage_Horns", "DarkMageZ"), ("Archer_Horns", "ShadowHunterZ")])))
    fit = num(fx, r"SWING_FIT = ([\d.]+)")
    for key, name in rows:
        out.append((f"{key} is a ClassGrips row", f"\t{key} = {{" in grips))
        c = clip(fx, name)
        out.append((f"{name} exists", c is not None))
        if not c:
            continue
        length, keys = c
        cls = key.split("_")[0]
        block = cfg[cfg.find(f"\t{cls} = {{", cfg.find("Config.Classes = {")):]
        interval = num(block, r"SwingInterval = ([\d.]+)")
        limit = (interval * fit) if interval is not None and fit is not None else None
        if name.endswith("Release") or name in ZX:
            limit = 0.8  # a release clip is sped up to RELEASE_ANIM_TIME (0.75 s); keep its own length near that
        out.append((f"{name} fits its move (swing <= SwingInterval x SWING_FIT, release <= 0.8 s)", limit is not None
                    and length <= limit + 1e-9))
        times = [t for t, _, _ in keys]
        out.append((f"{name}: keys in time order from 0 to Len", times == sorted(times) and times[0] == 0 and abs(times[-1] - length) < 1e-9))
        out.append((f"{name}: real R15 joints only", all(j in JOINTS for _, _, js in keys for j in js)))
        ok = True
        for (_, _, a), (_, _, b) in zip(keys, keys[1:]):
            for j in set(a) | set(b):
                va, vb = a.get(j, (0, 0, 0)), b.get(j, (0, 0, 0))
                if any(abs(x - y) >= 180 for x, y in zip(va, vb)):
                    ok = False
        out.append((f"{name}: neighbouring keys < 180 degrees apart", ok))
        const, _ = STRIKE.get(name, (None, None))
        if const:
            if "." in const:
                tbl, cls2 = const.split(".")
                t = num(fx, tbl + r" = \{[^}]*?" + cls2 + r" = ([\d.]+)")
            else:
                t = num(fx, const + r" = ([\d.]+)")
            strike = [kt for kt, ease, _ in keys if ease == "In"]
            out.append((f"{name}: the strike key on {const}", t is not None and len(strike) == 1 and abs(strike[0] - t) < 1e-9))
    for name in ZX:
        c = clip(fx, name)
        strikes = [kt for kt, ease, _ in (c[1] if c else []) if ease == "In"]
        out.append((f"{name}: one strike key inside the clip", c is not None and len(strikes) == 1 and 0 < strikes[0] < c[0]))
    # A23-128 one-hand swords (검수 10/11 fix/onehand review): the warriors' clips never close the empty left fist on the
    # hilt next to the right one (in no key do both arms sit together: shoulders' forward < 20 deg apart, elbows <= 20
    # apart, and side swings parallel (< 20 apart) or mirrored to meet in the middle (sum < 30)), and the notes over
    # them say no both hands / two-hand / great sword
    for name in ONE_HAND:
        c = clip(fx, name)
        bad = []
        for t, _, js in (c[1] if c else []):
            ls, rs = js.get("LeftShoulder"), js.get("RightShoulder")
            le, re_ = js.get("LeftElbow", (0, 0, 0)), js.get("RightElbow", (0, 0, 0))
            if ls and rs and abs(ls[0] - rs[0]) < 20 and abs(le[0] - re_[0]) <= 20 and (abs(ls[2] - rs[2]) < 20
                                                                                    or abs(ls[2] + rs[2]) < 30):
                bad.append(t)
        start = fx.find(f"\t\t{name} = {{ Len")
        note = []
        for ln in reversed(fx[:start].split("\n")[:-1]):
            if not ln.strip().startswith("--"):
                break
            note.append(ln.lower())
        out.append((f"A23-128 {name}: the free left arm balances (no fist on the hilt), no 'both hands' / great sword "
                    "in its note", c is not None and not bad and not re.search(r"both hands|two-hand|great sword", " ".join(note))))
    out += [
        ("Fx \"Skill\" plays the Z / X move (only those slots)", "handlers.Skill = function(data)" in fx
         and 'if slot ~= "Z" and slot ~= "X" then return end' in fx and "pcall(Feel.playAttack, ctx.Char, classId, slot," in fx),
        ("Z / X hold like a release (a swing cannot cut them short)", 'if which ~= "Swing" then current.ReleaseUntil' in fx),
        ("playAttack takes the side clips (not for a style)", "if not style then names = MOTION.SideClips(char, classId) or names end" in fx),
        ("SideClips reads the attacker's Faction (ClassGripKey)", 'Config.ClassGripKey(classId, p:GetAttribute("Faction"))' in fx),
        ("a move the side has none for stays the class's (Z / X: the side's own only)",
         "return { Swing = row.Swing or base.Swing, Release = row.Release or base.Release, Z = row.Z, X = row.X }" in fx),
    ]
    return out


MUTATIONS = [
    ("every skill slot plays a move", 'if slot ~= "Z" and slot ~= "X" then return end', 'if slot == "" then return end'),
    ("a swing cuts a Z / X short", 'if which ~= "Swing" then current.ReleaseUntil', 'if which == "Release" then current.ReleaseUntil'),
    ("side clips never used", "\tif not style then names = MOTION.SideClips(char, classId) or names end", "\tlocal _ = 0"),
    ("the Paladin strikes late", '\t\t\t{ 0.23, "In", { Waist = { -12, 6, 0 }', '\t\t\t{ 0.3, "In", { Waist = { -12, 6, 0 }'),
    ("a key flips past 180", "RightShoulder = { 158, -6, 12 }", "RightShoulder = { 158, -6, 212 }"),
    ("the Light Mage clip too long", "LightMageSwing = { Len = 0.68,", "LightMageSwing = { Len = 1.68,"),
    ("a row for no class", "\t\tMage_Halo = { Swing = \"LightMageSwing\",", "\t\tMage_Sky = { Swing = \"LightMageSwing\","),
    ("the Light Mage's Q strikes early", '\t\t\t{ 0.35, "In", { Waist = { -18, 0, 0 }', '\t\t\t{ 0.3, "In", { Waist = { -18, 0, 0 }'),
    # A23-128 (검수 10/11): the old two-hand grips on the one-hand swords
    ("the Paladin's Q: both fists on the hilt again", "RightWrist = { -80, 0, 0 }, LeftShoulder = { 58, 0, -12 }, LeftElbow = { 70, 0, 0 } } },",
     "RightWrist = { -80, 0, 0 }, LeftShoulder = { 168, 0, -6 }, LeftElbow = { 72, 0, 0 }, LeftWrist = { -80, 0, 0 } } },"),
    ("the Berserker's Q: both fists at the smash", "LeftShoulder = { 10, 0, -46 }, LeftElbow = { 20, 0, 0 }",
     "LeftShoulder = { 58, 0, 12 }, LeftElbow = { 8, 0, 0 }, LeftWrist = { -86, 0, 0 }"),
    ("the Berserker's Z: both hands drag the blade", "LeftShoulder = { 46, 0, -26 }, LeftElbow = { 50, 0, 0 }",
     "LeftShoulder = { 20, 0, 30 }, LeftElbow = { 30, 0, 0 }"),
    ("the Berserker's X: the tip set down with both hands", "LeftShoulder = { 12, 0, -18 }, LeftElbow = { 40, 0, 0 }",
     "LeftShoulder = { 40, 0, 6 }, LeftElbow = { 10, 0, 0 }, LeftWrist = { -60, 0, 0 }"),
    ("the old 'both hands' note", "-- right hand (the left fist clenched low at the side;",
     "-- right hand with both hands (the left fist clenched low at the side;"),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    fx = FX.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    cfg = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    res = checks(fx, cfg)
    for name, ok in res:
        print(("CHECK_OK  " if ok else "CHECK_FAIL ") + name)
    muts = []
    for name, old, new in MUTATIONS:
        hits = fx.count(old)
        caught = hits == 1 and not all(ok for _, ok in checks(fx.replace(old, new), cfg))
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    failed = sum(0 if ok else 1 for _, ok in res)
    ok = failed == 0 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": len(res), "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {len(res)}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
