"""The two-hand grip code (WeaponPose.TwoHand) and A23-128 "no two-hand warrior" (게임성 개발 1, 2026-10-11; SPEC A23-108,
검수 10/11; user 10/11 "대검을 잡는 게 이상한데? 손바닥 위에 올려놓은 느낌" -> A23-128 user 10/11 "한손검만 쓸 수 있게
하자"; references docs/design/grip_reference_2026-10-11.md), offline.

A23-128: no Config.ClassGrips row holds a weapon in two hands (no TwoHand) and nothing holds a great sword (no ClassGrips
Weapon "GreatSword", no CharacterVisuals SHAPES.GreatSword); both warriors hold a one-hand sword (OneHand - its
geometry is tools/test_one_hand_grips.py). The two-hand code stays for later weapons, so its statics stay: WeaponPose
drives both arms from TwoHandGoals in torso space (walk / run / jump keep the hands on: the arm swing is replaced), out
of reach = the closest reach (never a dropped frame), the grip point lands on the line (CFrame.new(-gripPos)), the up
turns to the shoulder, the fade, the gap from the hands' sizes, the Studio probe (GripProbe) measures every frame and
prints the worst. This file also holds the shared Python copies of the R15 rig of place/GoodEvil.rbxlx (UpperTorso
shoulders (+-0.972, 0.598, 0); arm attachments: shoulder (-+0.501, 0.419), elbow (0, -0.355) / (0, 0.275), wrist
(0, -0.532) / (0, 0.132), grip (0, -0.158)) and of WeaponPose.TwoHandGoals that test_one_hand_grips.py imports.
Mutations: each must be caught.

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
NUM = r"(-?[\d.]+)"

RIG = {"Shoulder": 0.972, "ShoulderY": 0.598, "SC1": (0.501, 0.419), "EC0": -0.355, "EC1": 0.275, "WC0": -0.532,
       "WC1": 0.132, "Grip": -0.158}
TORSO_TOP = 0.8


def sub(a, b): return tuple(a[i] - b[i] for i in range(3))
def add(a, b, k=1.0): return tuple(a[i] + b[i] * k for i in range(3))
def dot(a, b): return sum(a[i] * b[i] for i in range(3))
def length(a): return math.sqrt(dot(a, a))
def unit(a): n = length(a); return tuple(x / n for x in a)
def cross(a, b): return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
def angle(a, b): return math.degrees(math.acos(max(-1.0, min(1.0, dot(unit(a), unit(b))))))


def rig(side: str, k: float):
    s = 1 if side == "R" else -1
    shoulder = (s * RIG["Shoulder"] * k, RIG["ShoulderY"] * k, 0.0)
    l1 = length((RIG["SC1"][0], RIG["SC1"][1] - RIG["EC0"], 0)) * k  # |elbow.C0 - shoulder.C1|
    l2 = (RIG["EC1"] - RIG["WC0"]) * k
    return shoulder, l1, l2, (0.0, RIG["WC1"] * k, 0.0), (0.0, RIG["Grip"] * k, 0.0)


def goal(point, grip, shoulder, aim, src_wp):
    """WeaponPose.TwoHandGoals' goal(): hand frame (x, y, z axes) and position (follows the source's sign / order)."""
    up = sub(shoulder, point)
    up = sub(up, tuple(x * dot(up, aim) for x in aim))
    up = unit(up)
    z = tuple(-x for x in aim)
    x = cross(up, z)
    frame = (x, up, z)
    if "return CFrame.new(point) * CFrame.fromMatrix(Vector3.zero, up, up:Cross(z), z)" in src_wp:  # a mutation: the axes swapped
        frame = (up, x, z)
    sign = 1.0 if "fromMatrix(Vector3.zero, up:Cross(z), up, z) * CFrame.new(-gripPos)" in src_wp or "up, up:Cross(z), z) * CFrame.new(-gripPos)" in src_wp else -1.0
    gx, gy, gz = (g * sign for g in grip)
    pos = sub(point, add(add(tuple(a * gx for a in frame[0]), frame[1], gy), frame[2], gz))
    return frame, pos


def to_world(frame, pos, local):
    x, y, z = frame
    return add(add(add(pos, x, local[0]), y, local[1]), z, local[2])


def class_grips(cfg: str) -> str:
    return cfg[cfg.find("Config.ClassGrips = {"):cfg.find("function Config.ClassGripKey")]


def geometry(src: dict) -> list[tuple[str, bool, str]]:
    """A23-128 (user 10/11 "한손검만"): no two-hand weapon, no great sword; both warriors hold a one-hand sword"""
    block, cv = class_grips(src["CONFIG"]), src["CV"]
    rows = re.findall(r"\n\t(\w+_\w+) = \{ Weapon = \"(\w+)\"", block)
    warriors = {k: w for k, w in rows if k.startswith("Warrior_")}
    halo = re.search(r"\n\tWarrior_Halo = \{[^\n]*\n\t\tOneHand = \{ Hilt = ", block)
    horns = re.search(r"\n\tWarrior_Horns = \{[^\n]*\n\t\tOneHand = \{ Hilt = ", block)
    return [
        ("ClassGrips is readable (nine rows)", len(rows) == 9, f"{len(rows)}"),
        ("A23-128: no ClassGrips row holds a weapon in two hands (no TwoHand)", "TwoHand" not in block, ""),
        ("A23-128: no great sword (ClassGrips Weapon, CharacterVisuals SHAPES)",
         all(w != "GreatSword" for _, w in rows) and "SHAPES.GreatSword" not in cv, f"{warriors}"),
        ("A23-128: the Paladin holds the straight Sword, the Berserker the DarkSword, each in one hand (OneHand)",
         warriors.get("Warrior_Halo") == "Sword" and warriors.get("Warrior_Horns") == "DarkSword"
         and halo is not None and horns is not None, f"{warriors}"),
    ]


def statics(src: dict) -> list[tuple[str, bool, str]]:
    wp, fx = src["WP"], src["FX"]
    body = wp.split("function WeaponPose.TwoHand(", 1)[-1].split("function WeaponPose.OneHand(", 1)[0]
    return [
        ("Fx shares its arm solver", "Fx.SolveArm, Fx.ArmGeometry, Fx.JointFrames = Feel.solveArm, Feel.armGeometry, Feel.jointFrames" in fx, ""),
        ("WeaponPose runs TwoHand after the hold", '\tif type(def.TwoHand) == "table" then\n\t\tWeaponPose.TwoHand(char, st, def, model)\n' in wp, ""),
        ("the goal: grip point on the line, -Z along the blade, +Y to the shoulder",
         "return CFrame.new(point) * CFrame.fromMatrix(Vector3.zero, up:Cross(z), up, z) * CFrame.new(-gripPos)" in wp
         and "local up = shoulder - point\n\t\tup -= aim * up:Dot(aim)" in wp and "local z = -aim" in wp, ""),
        ("the left hand is Gap lower on the line", "goal(hilt - aim * gap, leftGrip, leftShoulder)" in wp, ""),
        ("the left hand goes to the handle's foot (its size up), never onto the right hand",
         "local foot = hand.CFrame:ToObjectSpace(handle.CFrame) * Vector3.new(0, -handle.Size.Y / 2, 0)" in body
         and "gap = math.max((foot.Z - grip.Z) - leftHand.Size.Z / 2 - T.GapPad, (hand.Size.Z + leftHand.Size.Z) / 2 * T.OverlapShare)" in body, ""),
        ("out of reach still poses (the closest reach): the hands never drop for a frame (검수 10/11 walk photos)",
         'if type(rPose) ~= "table" or type(lPose) ~= "table" then return false end' in body
         and ".Clamped then return" not in body, ""),
        ("walk / run / jump: the goals and the elbows live in torso space (the arm swing is replaced, not added)",
         "local aim = torso:VectorToWorldSpace(th.Aim.Unit)\n\tlocal hilt = torso * (th.Hilt * (k or 1))" in wp
         and "(torso * left.Shoulder.C0).Position, gap, WeaponPose.BodyScale(right))" in wp
         and "torso:VectorToWorldSpace(T.PoleRight)" in body and "torso:VectorToWorldSpace(T.Pole)" in body
         and "local out = base:Lerp(pose[w[2]], st.W)" in body, ""),
        ("Studio probe measures every frame and prints the worst (walk sequences)",
         'if RunService:IsStudio() and me and me:GetAttribute("GripProbe") == true then pcall(WeaponPose.ProbeStep, me, now) end' in wp
         and "w.dHand, w.dGrip, w.axis = math.max(w.dHand, v.dHand), math.max(w.dGrip, v.dGrip), math.max(w.axis, v.axis)" in wp, ""),
        ("both arms fade in with the pose weight", "local out = base:Lerp(pose[w[2]], st.W)" in body, ""),
        ("the arms are kept like the hold's (handed back on release)", "st.Base[joint], st.Last[joint] = base, out" in body, ""),
    ]


def run(src: dict):
    res = geometry(src) + statics(src)
    lines = [("CHECK_OK " if ok else "CHECK_FAIL ") + name + (f" :: {d}" if d else "") for name, ok, d in res]
    return len(res), sum(0 if ok else 1 for _, ok, _ in res), lines


MUTATIONS = [
    # A23-128 (user 10/11 "한손검만"): the great sword / two-hand grip never comes back
    ("CONFIG", "the Berserker's great sword again", 'Warrior_Horns = { Weapon = "DarkSword",', 'Warrior_Horns = { Weapon = "GreatSword",'),
    ("CONFIG", "the Berserker's two-hand grip again", "OneHand = { Hilt = Vector3.new(1.65, -1.05, -0.45)",
     "TwoHand = { Hilt = Vector3.new(1.65, -1.05, -0.45)"),
    ("CONFIG", "the Paladin's sword out of his hand", 'Warrior_Halo = { Weapon = "Sword",', 'Warrior_Halo = { Weapon = "Hammer",'),
    ("CV", "the great sword shape again", "function SHAPES.DarkSword(grip, sc, w, color)",
     "function SHAPES.GreatSword(grip, sc, w, color) end\nfunction SHAPES.DarkSword(grip, sc, w, color)"),
    ("WP", "the grip point off the line", "return CFrame.new(point) * CFrame.fromMatrix(Vector3.zero, up:Cross(z), up, z) * CFrame.new(-gripPos)", "return CFrame.new(point) * CFrame.fromMatrix(Vector3.zero, up:Cross(z), up, z) * CFrame.new(gripPos)"),
    ("WP", "the hand turned along the handle", "return CFrame.new(point) * CFrame.fromMatrix(Vector3.zero, up:Cross(z), up, z) * CFrame.new(-gripPos)", "return CFrame.new(point) * CFrame.fromMatrix(Vector3.zero, up, up:Cross(z), z) * CFrame.new(-gripPos)"),
    ("WP", "the left hand on top of the right", "goal(hilt - aim * gap, leftGrip, leftShoulder)", "goal(hilt, leftGrip, leftShoulder)"),
    ("WP", "never run", '\tif type(def.TwoHand) == "table" then\n\t\tWeaponPose.TwoHand(char, st, def, model)\n', '\tif false then\n\t\tWeaponPose.TwoHand(char, st, def, model)\n'),
    ("WP", "a clamped solve drops the pose (the hanging left hand)", 'if type(rPose) ~= "table" or type(lPose) ~= "table" then return false end',
     'if type(rPose) ~= "table" or type(lPose) ~= "table" or lPose.Clamped then return false end'),
    ("WP", "the blade in world space (turns with nothing)", "local aim = torso:VectorToWorldSpace(th.Aim.Unit)", "local aim = th.Aim.Unit"),
    ("WP", "the probe samples once per print", "pcall(WeaponPose.ProbeStep, me, now) end", "pcall(WeaponPose.ProbeStep, me, now + 99) end"),
    ("WP", "no fade", "local m, pose = st.Joints[joint], poses[w[1]]\n\t\tif m and pose and typeof(pose[w[2]]) == \"CFrame\" then\n\t\t\tlocal cur = m.Transform\n\t\t\tlocal last = st.Last[joint]\n\t\t\tlocal base = (last and same(cur, last)) and (st.Base[joint] or cur) or cur\n\t\t\tlocal out = base:Lerp(pose[w[2]], st.W)",
     "local m, pose = st.Joints[joint], poses[w[1]]\n\t\tif m and pose and typeof(pose[w[2]]) == \"CFrame\" then\n\t\t\tlocal cur = m.Transform\n\t\t\tlocal last = st.Last[joint]\n\t\t\tlocal base = (last and same(cur, last)) and (st.Base[joint] or cur) or cur\n\t\t\tlocal out = pose[w[2]]"),
    ("WP", "a fixed gap", "local foot = hand.CFrame:ToObjectSpace(handle.CFrame) * Vector3.new(0, -handle.Size.Y / 2, 0)", "local foot = Vector3.zero"),
    ("FX", "no shared solver", "Fx.SolveArm, Fx.ArmGeometry, Fx.JointFrames = Feel.solveArm, Feel.armGeometry, Feel.jointFrames\n", "\n"),
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
