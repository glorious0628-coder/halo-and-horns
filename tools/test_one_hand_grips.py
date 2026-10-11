"""One-hand weapons placed from the weapon (게임성 개발 1, 2026-10-11; 검수 10/11 grip sheet: the staffs held near their
foot and leaning out, the flask lying on the palm; references docs/design/grip_reference_2026-10-11.md §1), offline.

Geometry (the same Python copy of WeaponPose.TwoHandGoals and Fx's two-bone solve as tools/test_two_hand_grip.py, the
place's R15 rig, scale 1 and 0.85) for the CURRENT Config.ClassGrips Mage_Halo / Mage_Horns / Mage_Neutral OneHand
(Hilt, Aim): the arm reaches (<= 92%), the grip point lies on the weapon line (<= 0.2), the held axis along the weapon
(<= 10 deg), the forearm crosses the weapon (45..135 deg); the staffs stand upright (the Light Mage's within 5 deg, the
Dark Mage's slanted forward at most 15 deg) beside the body (the hand outside the torso, the line clear of it); the flask
stands upright in front of the chest. CharacterVisuals: a staff is held StaffGrip of its length up from the foot (>= half
way for every staff up to 6 studs) and its foot never sinks under the ground nor floats more than 1.3 studs (hand height
from the Hilt and an UpperTorso centre ~3.9 studs above the feet - an estimate, checked in the Studio photos); the flask's
fist wraps the neck, the round body hangs under it, the cork above. Static: WeaponPose runs OneHand when a row has no
TwoHand, writes only the right arm, fades with the pose weight; the three rows keep no right-arm hold angles. Mutations:
each must be caught.

Usage: py tools/test_one_hand_grips.py
Report: docs/art/verification_2026-10-11/offline_one_hand_grips_2026-10-11.json
"""
from __future__ import annotations

import json
import math
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import test_two_hand_grip as G  # noqa: E402  (the shared rig / goal / solve copies)

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau", "WP": SPS / "WeaponPose.luau",
         "CV": ROOT / "src/ServerScriptService/CharacterVisuals.luau"}
OUT = ROOT / "docs/art/verification_2026-10-11/offline_one_hand_grips_2026-10-11.json"
NUM = r"(-?[\d.]+)"
ROWS = {"Mage_Halo": {"Tilt": 5, "Staff": True}, "Mage_Horns": {"Tilt": 15, "Staff": True},
        "Mage_Neutral": {"Tilt": 10, "Staff": False}, "Warrior_Halo": {"Tilt": None, "Staff": False}}
# 검수 10/11 (grip_audit9 §2): the free left hands go to points on the body; Hip = the back of the hand on the waist
OFF_ROWS = {"Warrior_Halo": "Fist", "Warrior_Neutral": "Hip", "Mage_Halo": "Palm", "Mage_Neutral": "Hip", "Archer_Neutral": "Hip"}
BODY = [((-1.0, 1.0), (-0.8, 0.8), (-0.5, 0.5)), ((-1.0, 1.0), (-1.6, -0.8), (-0.5, 0.5))]  # UpperTorso, LowerTorso boxes
TORSO_ABOVE_FEET = 3.9  # studs, UpperTorso centre over the feet (R15 estimate; the photos check it)
TORSO_HALF = (1.0, 0.5)  # x, z half sizes of the UpperTorso box


def row(cfg: str, key: str):
    m = re.search(r"\n\t" + key + r" = \{(.*?)\n\t(?:--|\w+_\w+ = \{|\})", cfg, re.S)
    if not m:
        return None
    body = m.group(1)
    oh = re.search(r"OneHand = \{ Hilt = Vector3\.new\(" + NUM + ", " + NUM + ", " + NUM + r"\), Aim = Vector3\.new\("
                   + NUM + ", " + NUM + ", " + NUM + r"\)", body + " } }")
    if not oh:
        return None
    v = [float(oh[i]) for i in range(1, 7)]
    hold = re.search(r"Hold = \{(.*?)\}\s*(,|\})", body, re.S)
    return {"Hilt": tuple(v[:3]), "Aim": G.unit(tuple(v[3:])), "HoldText": body.split("OneHand", 1)[0]}


def off_row(cfg: str, key: str):
    m = re.search(r"\n\t" + key + r" = \{(.*?)\n\t(?:--|\w+_\w+ = \{|\})", cfg, re.S)
    if not m:
        return None
    body = m.group(1)
    o = re.search(r"OffHand = \{ At = Vector3\.new\(" + NUM + ", " + NUM + ", " + NUM + r"\), Up = Vector3\.new\(" + NUM + ", "
                  + NUM + ", " + NUM + r"\), Fwd = Vector3\.new\(" + NUM + ", " + NUM + ", " + NUM + r"\) \}", body)
    if not o:
        return None
    v = [float(o[i]) for i in range(1, 10)]
    hold = body.split("OneHand", 1)[0].split("OffHand", 1)[0]
    return {"At": tuple(v[0:3]), "Up": G.unit(tuple(v[3:6])), "Fwd": G.unit(tuple(v[6:9])),
            "NoLeftHold": "LeftShoulder" not in hold and "LeftElbow" not in hold and "LeftWrist" not in hold}


def off_goal(at, up, fwd, grip):
    """WeaponPose.OffHandGoal: the hand's frame (x, y = Up, z = -Fwd made square to Up) and its position"""
    f = G.unit(G.sub(fwd, tuple(x * G.dot(fwd, up) for x in up)))
    z = tuple(-x for x in f)
    x = G.cross(up, z)
    frame = (x, up, z)
    pos = G.sub(at, G.add(G.add(tuple(a * grip[0] for a in x), up, grip[1]), z, grip[2]))
    return frame, pos


def staff_rule(cv: str):
    m = re.search(r"local STAFF = \{ Grip = " + NUM + ", FootMin = " + NUM + ", FootMax = " + NUM + ", Len = " + NUM
                  + ", PerTier = " + NUM + ", Orb = " + NUM + ", OrbPerTier = " + NUM + r" \}", cv)
    uses = (cv.count("staffLow(shaftLen)") >= 2 and "return math.clamp(shaftLen * STAFF.Grip, STAFF.FootMin, STAFF.FootMax)" in cv
            and cv.count("local shaftLen = STAFF.Len + STAFF.PerTier * tier") == 2
            and cv.count("local d = STAFF.Orb + STAFF.OrbPerTier * tier") == 2)
    if not (m and uses):
        return None
    v = [float(m[i]) for i in range(1, 8)]
    return {"Grip": v[0], "Min": v[1], "Max": v[2], "Len": v[3], "Per": v[4], "Orb": v[5], "OrbPer": v[6]}


def weapon_lengths(cfg: str):
    """the weapon tiers (1..N) - the staff length now comes from STAFF.Len / PerTier per tier"""
    return [float(x) for x in re.findall(r"\n\t\{ Tier = \d, [^\n]*?Length = " + NUM, cfg)]


def flask(cv: str):
    m = re.search(r"function SHAPES\.Flask\(grip, sc, w, color, tier\)(.*?)\nend", cv, re.S)
    if not m:
        return None
    b = m.group(1)
    neck_on_fist = re.search(r'Name = "Neck",[^}]*CFrame = base,', b, re.S) is not None
    ball_below = re.search(r'Name = "Flask",[^}]*CFrame = base \* CFrame\.new\(0, -\(', b, re.S) is not None
    cork_above = re.search(r'Name = "Cork",[^}]*CFrame = base \* CFrame\.new\(0, \(neckLen / 2', b, re.S) is not None
    return {"Neck": neck_on_fist, "Ball": ball_below, "Cork": cork_above}


def line_clear_of_torso(point, aim):
    # sample the weapon line +-3 studs around the hand; inside the torso box (|x| < 1, |z| < 0.5, |y| < 0.8) = hit
    for i in range(-30, 31):
        p = G.add(point, aim, i / 10)
        if abs(p[0]) < TORSO_HALF[0] and abs(p[2]) < TORSO_HALF[1] and abs(p[1]) < 0.8:
            return False
    return True


def geometry(src: dict) -> list[tuple[str, bool, str]]:
    out = []
    wp = src["WP"]
    for key, spec in ROWS.items():
        r = row(src["CONFIG"], key)
        out.append((f"{key}: OneHand (Hilt, Aim) is readable", r is not None, ""))
        if not r:
            continue
        hilt, aim = r["Hilt"], r["Aim"]
        worst = {"reach": 0.0, "dist": 0.0, "axis": 0.0, "fore": (180.0, 0.0)}
        for k in (1.0, 0.85):
            shoulder, l1, l2, wc1, grip = G.rig("R", k)
            hk = tuple(v * k for v in hilt)  # WeaponPose.BodyScale: the point scales with the body
            frame, pos = G.goal(hk, grip, shoulder, aim, wp)
            wrist = G.to_world(frame, pos, wc1)
            d = G.length(G.sub(wrist, shoulder))
            eps = min(l1, l2) * 0.001
            clamped = not (abs(l1 - l2) + eps <= d <= l1 + l2 - eps)
            worst["reach"] = max(worst["reach"], 9.0 if clamped else d / (l1 + l2))
            rel = G.sub(G.to_world(frame, pos, grip), hk)
            worst["dist"] = max(worst["dist"], G.length(G.sub(rel, tuple(x * G.dot(rel, aim) for x in aim))))
            worst["axis"] = max(worst["axis"], G.angle(tuple(-x for x in frame[2]), aim))
            pole = (0.7, -0.7, 0.2)
            ax = G.unit(G.sub(wrist, shoulder))
            along = (d * d + l1 * l1 - l2 * l2) / (2 * d)
            h = math.sqrt(max(0.0, l1 * l1 - along * along))
            bend = G.unit(G.sub(pole, tuple(x * G.dot(pole, ax) for x in ax)))
            elbow = G.add(G.add(shoulder, ax, along), bend, h)
            fore = G.angle(G.sub(wrist, elbow), aim)
            worst["fore"] = (min(worst["fore"][0], fore), max(worst["fore"][1], fore))
        out.append((f"{key}: the arm reaches (<= 92%)", worst["reach"] <= 0.92, f"{worst['reach']:.2f}"))
        out.append((f"{key}: the grip point on the weapon line (<= 0.2) and the held axis along it (<= 10 deg)",
                    worst["dist"] <= 0.2 and worst["axis"] <= 10, f"{worst['dist']:.3f} / {worst['axis']:.1f}"))
        out.append((f"{key}: the forearm crosses the weapon (45..135 deg)", 45 <= worst["fore"][0] and worst["fore"][1] <= 135,
                    f"{worst['fore'][0]:.0f}..{worst['fore'][1]:.0f}"))
        tilt = G.angle(aim, (0.0, 1.0, 0.0))
        if spec["Tilt"] is None:
            # the Paladin (class_grips table): the sword in front of the body, its tip up to the left and ahead
            out.append((f"{key}: the sword's tip up to the left and ahead, the hilt in front on the right",
                        aim[0] < -0.2 and aim[1] > 0.5 and aim[2] < -0.1 and hilt[0] > 0 and hilt[2] < -0.5
                        and line_clear_of_torso(hilt, aim), f"aim {tuple(round(x, 2) for x in aim)}"))
        else:
            out.append((f"{key}: upright (tilt <= {spec['Tilt']} deg), never leaning out to the side",
                        tilt <= spec["Tilt"] and aim[0] <= 0.05, f"{tilt:.0f} deg, x {aim[0]:.2f}"))
        if spec["Tilt"] is None:
            pass
        elif spec["Staff"]:
            out.append((f"{key}: the staff stands beside the body (hand outside the torso, the line clear of it)",
                        hilt[0] >= 0.8 and line_clear_of_torso(hilt, aim), f"{hilt}"))
        else:
            out.append((f"{key}: the flask in front of the chest", hilt[2] <= -0.6 and abs(hilt[0]) <= 0.8 and -0.4 <= hilt[1] <= 0.4,
                        f"{hilt}"))
        out.append((f"{key}: no right-arm hold angles fight the placement",
                    "RightShoulder" not in r["HoldText"] and "RightElbow" not in r["HoldText"] and "RightWrist" not in r["HoldText"], ""))
    for key, kind in OFF_ROWS.items():
        o = off_row(src["CONFIG"], key)
        out.append((f"{key}: OffHand (At, Up, Fwd) is readable and no left-arm hold angles fight it",
                    o is not None and o["NoLeftHold"], ""))
        if not o:
            continue
        worst = {"reach": 0.0, "fold": 9.0, "inside": 9.0, "touch": 0.0}
        for k in (1.0, 0.85):
            shoulder, l1, l2, wc1, grip = G.rig("L", k)
            frame, pos = off_goal(tuple(v * k for v in o["At"]), o["Up"], o["Fwd"], grip)
            wrist = G.to_world(frame, pos, wc1)
            d = G.length(G.sub(wrist, shoulder))
            worst["reach"] = max(worst["reach"], d / (l1 + l2))
            worst["fold"] = min(worst["fold"], d / (l1 + l2))
            # the hand's centre stays out of the (scaled) body boxes by about half a hand
            gaps = []
            for (x0, x1), (y0, y1), (z0, z1) in BODY:
                dx = max(x0 * k - pos[0], 0.0, pos[0] - x1 * k)
                dy = max(y0 * k - pos[1], 0.0, pos[1] - y1 * k)
                dz = max(z0 * k - pos[2], 0.0, pos[2] - z1 * k)
                gaps.append(math.sqrt(dx * dx + dy * dy + dz * dz))
            worst["inside"] = min(worst["inside"], min(gaps))
            worst["touch"] = max(worst["touch"], min(gaps))
        out.append((f"{key}: the free arm reaches its point without folding (35%..92%)",
                    worst["reach"] <= 0.92 and worst["fold"] >= 0.35, f"{worst['fold']:.2f}..{worst['reach']:.2f}"))
        out.append((f"{key}: the free hand never sinks into the body (centre >= 0.15 outside)", worst["inside"] >= 0.15,
                    f"{worst['inside']:.2f}"))
        if kind == "Hip":
            out.append((f"{key}: the hand rests ON the waist's side (centre <= 0.45 from it), at waist height",
                        worst["touch"] <= 0.45 and o["At"][0] < -1.0 and -1.0 <= o["At"][1] <= -0.4, f"{worst['touch']:.2f}"))
        else:
            out.append((f"{key}: the hand in front of the chest", o["At"][2] <= -0.7 and -0.6 <= o["At"][1] <= 0.3, f"{o['At']}"))
    rule, lens = staff_rule(src["CV"]), weapon_lengths(src["CONFIG"])
    out.append(("CharacterVisuals: the staffs use STAFF / staffLow", rule is not None and len(lens) >= 7, f"{len(lens)} tiers"))
    if rule and lens:
        hand_y = min(row(src["CONFIG"], "Mage_Halo")["Hilt"][1], row(src["CONFIG"], "Mage_Horns")["Hilt"][1])
        hand_above_feet = TORSO_ABOVE_FEET + hand_y
        fracs, feet, tops, orbs = [], [], [], []
        for tier in range(1, len(lens) + 1):
            shaft = rule["Len"] + rule["Per"] * tier
            low = min(max(shaft * rule["Grip"], rule["Min"]), rule["Max"])
            fracs.append((shaft, low / shaft))
            feet.append(hand_above_feet - low)
            tops.append(hand_above_feet - low + shaft)
            orbs.append(rule["Orb"] + rule["OrbPer"] * tier)
        out.append(("every staff is held above its middle (the reference)",
                    all(f >= 0.5 for s, f in fracs), ", ".join(f"{s:g}:{f:.2f}" for s, f in fracs)))
        out.append(("the staff's foot never sinks into the ground nor floats more than 1.3 studs",
                    all(0.0 <= y <= 1.3 for y in feet), ", ".join(f"{y:.2f}" for y in feet)))
        out.append(("user 10/11 '마법봉 너무 크지 않니?': the staff top between the shoulder (4.3) and just over the head (5.8)",
                    all(4.3 <= t <= 5.8 for t in tops), ", ".join(f"{t:.2f}" for t in tops)))
        out.append(("the staff orb stays hand sized (<= 0.9 studs)", all(d <= 0.9 for d in orbs), ", ".join(f"{d:.2f}" for d in orbs)))
    fk = flask(src["CV"])
    out.append(("the flask: the fist wraps the neck, the body hangs under it, the cork on top",
                bool(fk and fk["Neck"] and fk["Ball"] and fk["Cork"]), f"{fk}"))
    return out


def statics(src: dict) -> list[tuple[str, bool, str]]:
    wp = src["WP"]
    body = wp.split("function WeaponPose.OneHand(", 1)[-1].split("\nend\n", 1)[0]
    off = wp.split("function WeaponPose.OffHand(", 1)[-1].split("\nend\n", 1)[0]
    return [
        ("WeaponPose runs OneHand and OffHand when a row has no TwoHand",
         '\telse\n\t\tif type(def.OneHand) == "table" then WeaponPose.OneHand(char, st, def, model) end\n'
         '\t\tif type(def.OffHand) == "table" then WeaponPose.OffHand(char, st, def) end\n' in wp, ""),
        ("OffHand places the left hand on its body point and writes only the left arm (fading in)",
         "local goal = WeaponPose.OffHandGoal(torso, oh, gripOf(leftHand, \"LeftGripAttachment\", T.LeftGrip), WeaponPose.BodyScale(right or left))" in off
         and "for i = 4, 6 do" in off and "local out = base:Lerp(pose[w[2]], st.W)" in off, ""),
        ("the body points scale with the avatar (WeaponPose.BodyScale from the shoulder joint)",
         "return math.clamp(math.abs(c0.Position.X) / T.ShoulderX, 0.6, 1.4)" in wp
         and "CFrame.new(torso * (oh.At * (k or 1)))" in wp and "local hilt = torso * (th.Hilt * (k or 1))" in wp, ""),
        ("OneHand places the right hand from the weapon (TwoHandGoals) and writes only the right arm",
         "local rGoal = WeaponPose.TwoHandGoals(torso, oh," in body and body.count("for i = 1, 3 do") == 2
         and "T.TwoJoints[i]" in body and "Left" not in body.replace("T.LeftGrip", ""), ""),
        ("OneHand fades in with the pose weight", "local out = base:Lerp(pose[w[2]], st.W)" in body, ""),
    ]


def run(src: dict):
    res = geometry(src) + statics(src)
    lines = [("CHECK_OK " if ok else "CHECK_FAIL ") + name + (f" :: {d}" if d else "") for name, ok, d in res]
    return len(res), sum(0 if ok else 1 for _, ok, _ in res), lines


MUTATIONS = [
    ("CONFIG", "the Light Mage's staff leaning out", "OneHand = { Hilt = Vector3.new(1.0, -0.3, -0.6), Aim = Vector3.new(0, 1, -0.05) }",
     "OneHand = { Hilt = Vector3.new(1.0, -0.3, -0.6), Aim = Vector3.new(0.6, 1, -0.05) }"),
    ("CONFIG", "the Paladin's sword tip to the right", "Aim = Vector3.new(-0.45, 0.8, -0.4)", "Aim = Vector3.new(0.6, 0.6, -0.4)"),
    ("CONFIG", "a hand-on-hip sinks into the waist", "OffHand = { At = Vector3.new(-1.25, -0.65, 0.1), Up = Vector3.new(-0.75, 0.5, 0.4), Fwd = Vector3.new(0, 0, -1) } },\n\t-- Light Mage",
     "OffHand = { At = Vector3.new(-0.6, -0.65, 0.1), Up = Vector3.new(-0.75, 0.5, 0.4), Fwd = Vector3.new(0, 0, -1) } },\n\t-- Light Mage"),
    ("CONFIG", "the Paladin's fist pushed out of reach", "OffHand = { At = Vector3.new(-0.3, 0.0, -0.95)", "OffHand = { At = Vector3.new(-0.3, 0.0, -2.2)"),
    ("CONFIG", "the old left-arm hold kept (Tamer)", "RightWrist = { -30, 0, 0 } }, OffHand", "RightWrist = { -30, 0, 0 }, LeftShoulder = { 0, 0, -15 } }, OffHand"),
    ("CONFIG", "the staff across the chest", "OneHand = { Hilt = Vector3.new(1.0, -0.3, -0.6)", "OneHand = { Hilt = Vector3.new(0.2, -0.3, -0.6)"),
    ("CONFIG", "the Dark Mage's staff slanted far", "Aim = Vector3.new(0, 1, -0.2) } },", "Aim = Vector3.new(0, 1, -0.8) } },"),
    ("CONFIG", "the flask held out of reach", "OneHand = { Hilt = Vector3.new(0.55, -0.05, -0.9)", "OneHand = { Hilt = Vector3.new(0.55, -0.05, -2.2)"),
    ("CONFIG", "the old right-arm hold kept", 'Mage_Halo = { Weapon = "Staff", Walk = 0.7, Hold = { Neck',
     'Mage_Halo = { Weapon = "Staff", Walk = 0.7, Hold = { RightShoulder = { 8, 0, 8 }, Neck'),
    ("CV", "the hand near the foot again", "local STAFF = { Grip = 0.72, FootMin = 2.4, FootMax = 3.4,",
     "local STAFF = { Grip = 0.4, FootMin = 0, FootMax = 99,"),
    ("CV", "a staff sinks into the ground", "local STAFF = { Grip = 0.72, FootMin = 2.4, FootMax = 3.4,",
     "local STAFF = { Grip = 0.72, FootMin = 2.4, FootMax = 5,"),
    ("CV", "the old tall staffs", "Len = 4.2, PerTier = 0.15,", "Len = 5.5, PerTier = 0.4,"),
    ("CV", "the old big orb", "Orb = 0.5, OrbPerTier = 0.05 }", "Orb = 0.7, OrbPerTier = 0.1 }"),
    ("CV", "the flask on the palm again", "CFrame = base * CFrame.new(0, -(neckLen / 2 + d / 2 - 0.05) * sc, 0),",
     "CFrame = base * CFrame.new(0, (d / 2 + 0.05) * sc, 0),"),
    ("WP", "never run", '\t\tif type(def.OneHand) == "table" then WeaponPose.OneHand(char, st, def, model) end\n',
     '\t\tif false then WeaponPose.OneHand(char, st, def, model) end\n'),
    ("WP", "the free hand never placed", '\t\tif type(def.OffHand) == "table" then WeaponPose.OffHand(char, st, def) end\n',
     '\t\tif false then WeaponPose.OffHand(char, st, def) end\n'),
    ("WP", "no body scale (small avatars stretch)", "return math.clamp(math.abs(c0.Position.X) / T.ShoulderX, 0.6, 1.4)", "return 1"),
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
