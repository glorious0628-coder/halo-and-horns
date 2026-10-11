"""Two hands on the Berserker's great sword (게임성 개발 1, 2026-10-11; SPEC A23-108, 검수 10/11; user 10/11 "대검을 잡는
게 이상한데? 손바닥 위에 올려놓은 느낌"; references docs/design/grip_reference_2026-10-11.md), offline.

Geometry: the CURRENT Config.ClassGrips.Warrior_Horns.TwoHand (Hilt, Aim, Gap) through a Python copy of
WeaponPose.TwoHandGoals and Fx's two-bone arm solve (Feel.solveArm) on the R15 rig of place/GoodEvil.rbxlx (UpperTorso
shoulders (+-0.972, 0.598, 0); arm attachments: shoulder (-+0.501, 0.419), elbow (0, -0.355) / (0, 0.275), wrist
(0, -0.532) / (0, 0.132), grip (0, -0.158)), at scale 1 and 0.85, with blocky hands (1 stud along the handle) and small
ones (0.4). For each hand: the solve is in reach (wrist distance <= 92% of the arm), the grip point (where a Roblox tool
handle runs) lies on the handle line (<= 0.2 studs), the hand's -Z (the held axis) lies along the blade (<= 10 deg),
the forearm crosses the handle (45..135 deg - not lying along the forearm, the "on the palm" look), the left hand is
below the right one by the gap. The blade passes just over the right shoulder (the shoulder plane z = 0 at x 0.8..1.5,
y 0.85..1.5, above the torso top 0.8) and rises up and back (115..145 deg). The great sword's handle reaches past the
left hand (CharacterVisuals SHAPES.GreatSword: top / below). Static: WeaponPose drives both arms from TwoHandGoals in
torso space (walk / run / jump keep the hands on: the arm swing is replaced), out of reach = the closest reach (never
a dropped frame), the grip point lands on the line (CFrame.new(-gripPos)), the up turns to the shoulder, the fade, the
gap from the hands' sizes, the Studio probe (GripProbe) measures every frame and prints the worst. Mutations: each
must be caught. The look and the walk sequence = 메인 반영 photos + probe lines.

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
    if "CFrame.fromMatrix(Vector3.zero, up, up:Cross(z), z)" in src_wp:  # a mutation: the axes swapped
        frame = (up, x, z)
    sign = 1.0 if "* CFrame.new(-gripPos)" in src_wp else -1.0
    gx, gy, gz = (g * sign for g in grip)
    pos = sub(point, add(add(tuple(a * gx for a in frame[0]), frame[1], gy), frame[2], gz))
    return frame, pos


def to_world(frame, pos, local):
    x, y, z = frame
    return add(add(add(pos, x, local[0]), y, local[1]), z, local[2])


def config_row(cfg: str):
    m = re.search(r"\n\tWarrior_Horns = \{[^\n]*\n\t\tTwoHand = \{ Hilt = Vector3\.new\(" + NUM + ", " + NUM + ", " + NUM
                  + r"\), Aim = Vector3\.new\(" + NUM + ", " + NUM + ", " + NUM + r"\), Gap = \{ " + NUM + ", " + NUM
                  + r" \} \} \},", cfg)
    if not m:
        return None
    v = [float(m[i]) for i in range(1, 9)]
    return {"Hilt": tuple(v[0:3]), "Aim": unit(tuple(v[3:6])), "Gap": (v[6], v[7])}


def handle(cv: str):
    m = re.search(r"function SHAPES\.GreatSword\(grip, sc, w, color\)(.*?)\nend", cv, re.S)
    if not m:
        return None
    t = re.search(r"local top, below, bladeLen = " + NUM + ", " + NUM + r", w\.Length \* 1\.3", m.group(1))
    named = 'Name = "Handle"' in m.group(1)
    pommel = re.search(r'Name = "Pommel", Shape = Enum\.PartType\.Ball, Size = Vector3\.new\(' + NUM + r",[^}]*CFrame = L \* "
                       r"CFrame\.new\(0, -\(below \+ " + NUM + r"\) \* sc, 0\)", m.group(1), re.S)
    # the pommel's reach past the handle's end = its centre offset + its radius
    extra = float(pommel[2]) + float(pommel[1]) / 2 if pommel else None
    return {"Top": float(t[1]), "Below": float(t[2]), "Named": named, "Pommel": extra} if t else None


def geometry(src: dict) -> list[tuple[str, bool, str]]:
    row, hd = config_row(src["CONFIG"]), handle(src["CV"])
    out = [("Warrior_Horns TwoHand (Hilt, Aim, Gap) and the great sword handle are readable", bool(row and hd), "")]
    if not out[0][1]:
        return out
    hilt, aim, (gmin, gmax) = row["Hilt"], row["Aim"], row["Gap"]
    wp = src["WP"]
    left_on_top = "goal(hilt, leftGrip, leftShoulder)" in wp
    elev = math.degrees(math.atan2(aim[1], -aim[2]))
    out.append(("the blade rises up and back (115..145 deg from forward)", 115 <= elev <= 145, f"{elev:.0f}"))
    cross_at = add(hilt, aim, -hilt[2] / aim[2]) if aim[2] > 0.05 else None
    out.append(("the blade passes just over the right shoulder (above the torso top)",
                cross_at is not None and 0.8 <= cross_at[0] <= 1.5 and max(0.85, TORSO_TOP) <= cross_at[1] <= 1.5,
                f"{cross_at and tuple(round(x, 2) for x in cross_at)}"))
    out.append(("the hilt is in front of the chest", hilt[2] <= -0.5 and abs(hilt[0]) <= 0.6 and -0.4 <= hilt[1] <= 0.6,
                f"{hilt}"))
    worst = {"reach": 0.0, "dist": 0.0, "axis": 0.0, "fore": (180.0, 0.0), "below": 9.0, "apart": 9.0}
    for k in (1.0, 0.85):
        for hand_len in (1.0, 0.4):
            # WeaponPose: the left hand at the handle's foot (half its length up), never closer than 0.8 of the sizes
            gap = 0.0 if left_on_top else min(max(max(hd["Below"] - hand_len / 2 - 0.05, hand_len * 0.8), gmin), gmax)
            worst["below"] = min(worst["below"], hd["Below"] + (hd["Pommel"] or 0) - (gap + hand_len / 2))
            worst["apart"] = min(worst["apart"], gap - min(hand_len, 0.45))
            worst["pommel"] = max(worst.get("pommel", 0.0), hd["Below"] - (gap + hand_len / 2))
            for side, point in (("R", hilt), ("L", add(hilt, aim, -gap))):
                shoulder, l1, l2, wc1, grip = rig(side, k)
                frame, pos = goal(point, grip, shoulder, aim, wp)
                wrist = to_world(frame, pos, wc1)
                d = length(sub(wrist, shoulder))
                eps = min(l1, l2) * 0.001
                clamped = not (abs(l1 - l2) + eps <= d <= l1 + l2 - eps)
                worst["reach"] = max(worst["reach"], 9.0 if clamped else d / (l1 + l2))
                rel = sub(to_world(frame, pos, grip), hilt)
                off = sub(rel, tuple(x * dot(rel, aim) for x in aim))
                worst["dist"] = max(worst["dist"], length(off))
                worst["axis"] = max(worst["axis"], angle(tuple(-x for x in frame[2]), aim))
                # the elbow of the two-bone solve (pole: down and out), then the forearm against the handle
                pole = (0.7 if side == "R" else -0.7, -0.7, 0.2)
                ax = unit(sub(wrist, shoulder))
                along = (d * d + l1 * l1 - l2 * l2) / (2 * d)
                h = math.sqrt(max(0.0, l1 * l1 - along * along))
                bend = unit(sub(pole, tuple(x * dot(pole, ax) for x in ax)))
                elbow = add(add(shoulder, ax, along), bend, h)
                fore = angle(sub(wrist, elbow), aim)
                worst["fore"] = (min(worst["fore"][0], fore), max(worst["fore"][1], fore))
    out.append(("both arms reach (wrist <= 92% of the arm; scale 1 / 0.85, blocky / small hands)",
                worst["reach"] <= 0.92, f"{worst['reach']:.2f}"))
    out.append(("each grip point lies on the handle line (<= 0.2 studs)", worst["dist"] <= 0.2, f"{worst['dist']:.3f}"))
    out.append(("each hand's held axis lies along the blade (<= 10 deg)", worst["axis"] <= 10, f"{worst['axis']:.1f}"))
    out.append(("the forearms cross the handle (45..135 deg), not lying along it",
                45 <= worst["fore"][0] and worst["fore"][1] <= 135, f"{worst['fore'][0]:.0f}..{worst['fore'][1]:.0f}"))
    out.append(("the left hand sits below the right one, side by side (gap >= a small hand)", worst["apart"] >= 0,
                f"{worst['apart']:.2f}"))
    out.append(("the handle (+ its pommel) reaches past the left hand", hd["Named"] and worst["below"] >= 0.1,
                f"{worst['below']:.2f}"))
    out.append(("the left hand rests near the pommel (<= 0.3 studs of bare handle under it; reference)",
                hd["Pommel"] is not None and worst.get("pommel", 9) <= 0.3, f"{worst.get('pommel', 9):.2f}"))
    return out


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
         "local aim = torso:VectorToWorldSpace(th.Aim.Unit)\n\tlocal hilt = torso * th.Hilt" in wp
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
    ("CONFIG", "the blade straight up", "Aim = Vector3.new(0.85, 0.85, 0.75)", "Aim = Vector3.new(0, 1, 0.05)"),
    ("CONFIG", "the blade across the chest (the photo)", "Aim = Vector3.new(0.85, 0.85, 0.75)", "Aim = Vector3.new(0.85, 0.55, -0.1)"),
    ("CONFIG", "the hilt too far ahead", "Hilt = Vector3.new(0.25, 0.2, -0.7)", "Hilt = Vector3.new(0.25, 0.2, -1.6)"),
    ("CONFIG", "the hilt at the belly, the left hand out of reach", "Hilt = Vector3.new(0.25, 0.2, -0.7)",
     "Hilt = Vector3.new(0.3, -0.6, -0.9)"),
    ("CONFIG", "the hands far apart", "Gap = { 0.45, 0.9 } } },", "Gap = { 1.4, 1.6 } } },"),
    ("CONFIG", "the hands overlapping", "Gap = { 0.45, 0.9 } } },", "Gap = { 0.1, 0.2 } } },"),
    ("CV", "a long bare handle under the left hand", "local top, below, bladeLen = 0.6, 1.15, w.Length * 1.3", "local top, below, bladeLen = 0.6, 2.0, w.Length * 1.3"),
    ("CV", "no pommel", 'Name = "Pommel", Shape = Enum.PartType.Ball', 'Name = "Knob", Shape = Enum.PartType.Ball'),
    ("WP", "the grip point off the line", "* CFrame.new(-gripPos)", "* CFrame.new(gripPos)"),
    ("WP", "the hand turned along the handle", "CFrame.fromMatrix(Vector3.zero, up:Cross(z), up, z)",
     "CFrame.fromMatrix(Vector3.zero, up, up:Cross(z), z)"),
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
