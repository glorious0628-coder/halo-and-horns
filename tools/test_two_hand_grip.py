"""Two hands on the Berserker's great sword (게임성 개발 1, 2026-10-11; SPEC A23-108, 검수 10/11;
docs/design/class_grips_a23_108_2026-10-10.md: "두 손(오른손 위·왼손 아래 자루 끝)", §2 "왼손은 클라 몸짓이 자루로"), offline.

Geometry (Python FK on the R15 rig of place/GoodEvil.rbxlx: shoulder (+-0.972, 0.598, 0) on UpperTorso, upper arm
(0.501, -0.774, 0), lower arm (0, -0.807, 0), wrist -> grip (0, -0.29, 0); joint offsets = CFrame.Angles(rx, ry, rz)
in degrees, the weapon along the hand's -Z = "rx sum 90 = upright", Config.ClassGrips note) with the CURRENT
Config.ClassGrips.Warrior_Horns and CharacterVisuals SHAPES.GreatSword (handle length / centre): the right hand holds
the hilt in front of the chest near the middle; the blade rises up and back and crosses the shoulder plane over the
right shoulder; TwoHand puts the left hand on the handle below the right one; the left wrist is inside the left arm's
reach (the solve is not clamped). Static: WeaponPose solves the left arm after the hold with Fx's arm solver (this
frame's right hand from the torso through the right arm joints), skips a clamped solve, fades in with the pose weight;
Fx shares SolveArm / ArmGeometry / JointFrames; the great sword's grip part is named "Handle". Mutations: each must be
caught. The look itself = 메인 반영 Play photos (stand / walk, after merge).

Usage: py tools/test_two_hand_grip.py
Report: docs/art/verification_2026-10-11/offline_two_hand_grip_2026-10-11.json
"""
from __future__ import annotations

import json
import math
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau", "WP": SPS / "WeaponPose.luau",
         "FX": SPS / "Fx.luau", "CV": ROOT / "src/ServerScriptService/CharacterVisuals.luau"}
OUT = ROOT / "docs/art/verification_2026-10-11/offline_two_hand_grip_2026-10-11.json"

SH_R, SH_L = (0.972, 0.598, 0.0), (-0.972, 0.598, 0.0)
UPPER_R, UPPER_L, LOWER, GRIP = (0.501, -0.774, 0.0), (-0.501, -0.774, 0.0), (0.0, -0.807, 0.0), (0.0, -0.29, 0.0)
L1, L2 = math.hypot(0.501, 0.774), 0.807
NUM = r"(-?[\d.]+)"


def rx(a):
    c, s = math.cos(a), math.sin(a)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def ry(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rz(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def mm(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def mv(a, v):
    return tuple(sum(a[i][k] * v[k] for k in range(3)) for i in range(3))


def add(a, b, k=1.0):
    return tuple(a[i] + b[i] * k for i in range(3))


def angles(t):
    return mm(mm(rx(math.radians(t[0])), ry(math.radians(t[1]))), rz(math.radians(t[2])))


def hold_row(cfg: str):
    m = re.search(r"\n\tWarrior_Horns = \{(.*?)\n\t\t[^\n]*\} \},\n", cfg, re.S)
    if not m:
        m = re.search(r"\n\tWarrior_Horns = \{([^\n]*\n[^\n]*)\n", cfg)
    if not m:
        return None
    row = m.group(0)
    joints = {}
    for name, a, b, c in re.findall(r"(\w+) = \{ " + NUM + ", " + NUM + ", " + NUM + r" \}", row):
        joints[name] = (float(a), float(b), float(c))
    th = re.search(r"TwoHand = \{ Part = \"(\w+)\", Along = " + NUM + r" \}", row)
    return {"Joints": joints, "Part": th and th[1], "Along": th and float(th[2]), "Row": row}


def sword(cv: str):
    m = re.search(r"function SHAPES\.GreatSword\(grip, sc, w, color\)(.*?)\nend", cv, re.S)
    if not m:
        return None
    body = m.group(1)
    ln = re.search(r"local handleLen, bladeLen = " + NUM + r", w\.Length", body)
    ctr = re.search(r'Name = "Handle".*?CFrame = L \* CFrame\.new\(0, ' + NUM + r" \* sc, 0\)", body, re.S)
    return {"Len": float(ln[1]) if ln else None, "Centre": float(ctr[1]) if ctr else None, "Named": 'Name = "Handle"' in body}


def geometry(src: dict) -> list[tuple[str, bool, str]]:
    row, sw = hold_row(src["CONFIG"]), sword(src["CV"])
    out = [("Warrior_Horns hold, TwoHand and the great sword handle are readable",
            row is not None and row["Part"] is not None and sw is not None and sw["Len"] and sw["Centre"] is not None, "")]
    if not out[0][1]:
        return out
    j = row["Joints"]
    rs = angles(j.get("RightShoulder", (0, 0, 0)))
    re_ = mm(rs, angles(j.get("RightElbow", (0, 0, 0))))
    rh = mm(re_, angles(j.get("RightWrist", (0, 0, 0))))
    elbow = add(SH_R, mv(rs, UPPER_R))
    wrist = add(elbow, mv(re_, LOWER))
    grip = add(wrist, mv(rh, GRIP))
    blade = mv(rh, (0, 0, -1))
    elev = math.degrees(math.atan2(blade[1], -blade[2]))
    out.append(("the right hand holds the hilt in front of the chest near the middle",
                grip[2] <= -0.5 and abs(grip[0]) <= 0.6 and -0.5 <= grip[1] <= 0.9, f"grip {tuple(round(x, 2) for x in grip)}"))
    out.append(("the blade rises up and back (110..145 deg from forward)", 110 <= elev <= 145, f"{elev:.0f}"))
    cross = None
    if blade[2] > 0.05:
        cross = add(grip, blade, -grip[2] / blade[2])
    out.append(("the blade crosses the shoulder plane over the right shoulder",
                cross is not None and 0.6 <= cross[0] <= 1.8 and 1.0 <= cross[1] <= 2.3,
                f"cross {cross and tuple(round(x, 2) for x in cross)}"))
    # the left grip spot: handle centre (Centre along the blade from the right grip) + Along x length
    off = sw["Centre"] + row["Along"] * sw["Len"]
    lo, hi = sw["Centre"] - sw["Len"] / 2, sw["Centre"] + sw["Len"] / 2
    out.append(("the left hand is on the handle, below the right hand (toward the pommel)",
                row["Part"] == "Handle" and lo + 0.1 <= off <= -0.4 and off <= hi, f"offset {off:.2f} in [{lo:.2f}, {hi:.2f}]"))
    spot = add(grip, blade, off)
    lw = add(spot, mv(rh, GRIP), -1.0)  # the left wrist sits like the right one: grip -> wrist back along the hand
    d = math.dist(lw, SH_L)
    out.append(("the left wrist is inside the left arm's reach (no clamped solve)",
                abs(L1 - L2) + 0.05 <= d <= (L1 + L2) * 0.97, f"{d:.2f} of {L1 + L2:.2f}"))
    return out


def statics(src: dict) -> list[tuple[str, bool, str]]:
    wp, fx = src["WP"], src["FX"]
    return [
        ("Fx shares its arm solver (SolveArm / ArmGeometry / JointFrames)",
         "Fx.SolveArm, Fx.ArmGeometry, Fx.JointFrames = Feel.solveArm, Feel.armGeometry, Feel.jointFrames" in fx, ""),
        ("WeaponPose solves the left hand after the hold",
         '\tif type(def.TwoHand) == "table" then WeaponPose.TwoHand(char, st, def, model) end\nend' in wp, ""),
        ("this frame's right hand comes from the torso through the right arm joints",
         "local handCF = torso * right.Shoulder.C0 * st.Joints.RightShoulder.Transform * right.Shoulder.C1:Inverse()" in wp
         and "* right.Wrist.C0 * st.Joints.RightWrist.Transform * right.Wrist.C1:Inverse()" in wp, ""),
        ("the spot is on the weapon part, read through the welded offset from the right hand",
         "local spot = handCF * hand.CFrame:ToObjectSpace(part.CFrame) * CFrame.new(0, part.Size.Y * (tonumber(th.Along) or 0), 0)" in wp, ""),
        ("a clamped (out of reach) solve leaves the left arm alone",
         'if type(pose) ~= "table" or pose.Clamped then return false end' in wp, ""),
        ("the left arm fades in with the pose weight", "local out = base:Lerp(pose[key], st.W)" in wp, ""),
        ("the left joints are kept like the hold's (handed back on release)",
         "st.Base[joint], st.Last[joint] = base, out" in wp.split("function WeaponPose.TwoHand", 1)[-1], ""),
    ]


def run(src: dict):
    res = geometry(src) + statics(src)
    lines = [("CHECK_OK " if ok else "CHECK_FAIL ") + name + (f" :: {d}" if d else "") for name, ok, d in res]
    return len(res), sum(0 if ok else 1 for _, ok, _ in res), lines


MUTATIONS = [
    ("CONFIG", "the old one-hand shoulder rest", "RightShoulder = { 70, 60, -50 },\n\t\tRightElbow = { 80, 0, 0 }, RightWrist = { 40, 0, 0 } }",
     "RightShoulder = { 72, 0, 26 },\n\t\tRightElbow = { 112, 0, 0 }, RightWrist = { -18, 0, 0 } }"),
    ("CONFIG", "the left hand above the right one", 'TwoHand = { Part = "Handle", Along = -0.24 }', 'TwoHand = { Part = "Handle", Along = 0.24 }'),
    ("CONFIG", "the left hand off the end of the handle", 'TwoHand = { Part = "Handle", Along = -0.24 }',
     'TwoHand = { Part = "Handle", Along = -0.9 }'),
    ("CONFIG", "the blade straight up", "RightWrist = { 40, 0, 0 } }", "RightWrist = { 0, 0, 0 } }"),
    ("CONFIG", "the hilt out at the side", "RightShoulder = { 70, 60, -50 }", "RightShoulder = { 70, 0, 20 }"),
    ("CONFIG", "the hilt too far from the left hand", "RightShoulder = { 70, 60, -50 }", "RightShoulder = { 70, 40, -10 }"),
    ("CONFIG", "the wrong part", 'TwoHand = { Part = "Handle"', 'TwoHand = { Part = "Blade"'),
    ("FX", "no shared solver", "Fx.SolveArm, Fx.ArmGeometry, Fx.JointFrames = Feel.solveArm, Feel.armGeometry, Feel.jointFrames\n", "\n"),
    ("WP", "never solved", '\tif type(def.TwoHand) == "table" then WeaponPose.TwoHand(char, st, def, model) end\n', ""),
    ("WP", "a clamped solve stretches the arm", 'if type(pose) ~= "table" or pose.Clamped then return false end',
     'if type(pose) ~= "table" then return false end'),
    ("WP", "no fade in", "local out = base:Lerp(pose[key], st.W)", "local out = pose[key]"),
    ("WP", "last frame's hand (the hands drift apart while moving)",
     "local spot = handCF * hand.CFrame:ToObjectSpace(part.CFrame)", "local spot = hand.CFrame * hand.CFrame:ToObjectSpace(part.CFrame)"),
    ("CV", "the handle renamed", 'Name = "Handle", Size = Vector3.new(0.32, handleLen, 0.32) * sc,',
     'Name = "Grip", Size = Vector3.new(0.32, handleLen, 0.32) * sc,'),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    n, failed, lines = run(src)
    print("\n".join(lines))
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
    status = "passed" if failed == 0 and n > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": n, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {n}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
