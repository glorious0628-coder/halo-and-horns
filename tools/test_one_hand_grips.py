"""One-hand weapons placed from the weapon (게임성 개발 1, 2026-10-11; 검수 10/11 grip sheet: the staffs held near their
foot and leaning out, the flask lying on the palm; references docs/design/grip_reference_2026-10-11.md §1), offline.

Geometry (the same Python copy of WeaponPose.TwoHandGoals and Fx's two-bone solve as tools/test_two_hand_grip.py, the
place's R15 rig, scale 1 and 0.85) for the CURRENT Config.ClassGrips Mage_Halo / Mage_Horns / Mage_Neutral OneHand
(Hilt, Aim): the arm reaches (<= 92%), the grip point lies on the weapon line (<= 0.2), the held axis along the weapon
(<= 10 deg), the forearm crosses the weapon (45..135 deg); the staffs stand upright (the Light Mage's within 5 deg, the
Dark Mage's slanted forward at most 15 deg) beside the body (the hand outside the torso, the line clear of it). A23-142
(user 10/12 "마법봉 대가리를 거의 잡는 것 같고, 아직도 길고 뭉툭해"): every staff (orb / hook / flask included) is 0.65..0.75
of the AVATAR's own height (CharacterVisuals avatarHeight: the rig's head top; STAFF.Height when unreadable), held 40..55%
up from its foot, the orb's bottom >= 1.2 studs over the hand, carried off the ground (its foot >= 0.3 over it, never in
it; the client only lifts a carried staff - StaffCarry) - every tier, every staff kind, on several avatars (hand height
from the Hilt and the UpperTorso centre 3.21 studs above the feet - measured on the place's default R15, the old 3.9 was
an estimate); A23-133 (user 10/11 "무기가 너무 길어서 잡는 위치가 이상해"; grip_reference §5): every held length is a share
of the avatar's height (the same rig: 5.18 studs) - a sword (pommel end to tip) 0.72..0.95 with the hand 10..22% up
from its end and the blade 1.3..2.5x the rest, a bow 0.55..0.97 (the
short bow <= 0.72), the smithing hammer 0.35..0.55 held 15..33% up, the baton 0.3..0.6 - every tier, from LEN; the flask's
fist wraps the neck, the round body hangs under it, the cork above. A23-128 (user 2026-10-11 "한손검만"): both warriors
(Warrior_Halo Sword, Warrior_Horns DarkSword) hold a one-hand sword in the right hand at the side - the hand just
outside the hanging arm's line (hilt x 1.4..1.75, waist height, a little ahead), the tip ahead and 45 deg up (40..50,
never across the body, the line clear of the torso), the elbow bent low near the hanging arm's line (its Pole; x
1.3..1.55, above and behind the hand), the left hand empty (no OffHand, no left-arm hold), no TwoHand. 검수 10/11
(fix/onehand review): the forearm (elbow -> wrist line >= 0.4 studs, the hanging arm's is 0.47) and the hand (wrist ->
hand bottom >= 0.45) stay out of the UpperTorso / LowerTorso boxes, the wrist bends <= 30 deg (the forearm against the
hand's up), the handle + pommel (CharacterVisuals sizes, 0.21 thick) and the hand clear the right thigh (the place rig:
hip (0.5, -1.2, 0), RightUpperLeg 0.99 x 1.36 x 0.97 hung 0.47 under the hip) swinging +-40 deg; SHAPES.DarkSword is
buildSword's size and place (the same handle, the same blade size and spot for every tier length, the guard at the same
height and about as wide, a small round pommel at the handle's end). 최종 검수 10/12 (the staffs held lower; references
grip_reference §5-6: a fist holds a staff square to the forearm, the wrist bends 15..25 deg towards the thumb): the
three staff rows (Light Mage, Dark Mage, Alchemist) hold the hand 2.45..2.75 studs over the ground (it was 2.9), the
wrist <= 20 deg towards the thumb and <= 40 deg back / forward, the forearm and the hand >= 0.2 out of the torso, the
Light Mage's hand the highest and its staff the most upright, the Dark Mage's the lowest and leaning; the Alchemist
holds SHAPES.FlaskStaff (the approved 2D: a staff with a flask): a Shaft (the client's foot fix finds it) held at the
staffs' grip, a leather Wrap round the hand, the flask in a cradle on top
with its neck and cork. Static: WeaponPose runs OneHand when a row has no
TwoHand, writes only the right arm, fades with the pose weight, bends the elbow to the row's Pole; the rows keep no
right-arm hold angles. Mutations: each must be caught.

Usage: py tools/test_one_hand_grips.py
Report: docs/art/verification_2026-10-11/offline_one_hand_grips_2026-10-11.json
"""
from __future__ import annotations

import json
import math
from pathlib import Path
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import test_two_hand_grip as G  # noqa: E402  (the shared rig / goal / solve copies)

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau", "WP": SPS / "WeaponPose.luau",
         "CV": ROOT / "src/ServerScriptService/CharacterVisuals.luau"}
OUT = ROOT / "docs/art/verification_2026-10-11/offline_one_hand_grips_2026-10-11.json"
NUM = r"(-?[\d.]+)"
ROWS = {"Mage_Halo": {"Tilt": 10, "Staff": True}, "Mage_Horns": {"Tilt": 15, "Staff": True},
        "Mage_Neutral": {"Tilt": 10, "Staff": True}, "Warrior_Halo": {"Tilt": None, "Sword": "Sword"},
        "Warrior_Horns": {"Tilt": None, "Sword": "DarkSword"}}
# 검수 10/11 (fix/onehand review) the warriors' limits
SWORD = {"Elev": (40, 50), "Elbow": (1.3, 1.55), "Fore": 0.4, "Hand": 0.45, "HandLen": 0.15, "Wrist": 30, "Thick": 0.21, "Upper": 0.15,
         "ThighGap": 0.05}
THIGH = {"Hip": (0.5, -1.2, 0.0), "Half": (0.5, 0.49), "Top": 0.21, "Bottom": -1.15, "Swing": 40}  # place R15, torso space
# 검수 10/11 (grip_audit9 §2): the free left hands go to points on the body; Hip = the back of the hand on the waist
# (A23-128: the warriors' left hands are empty and hang - no OffHand)
OFF_ROWS = {"Warrior_Neutral": "Hip", "Mage_Halo": "Palm", "Mage_Horns": "Hip", "Mage_Neutral": "Hip", "Archer_Neutral": "Hip"}
DEFAULT_POLE = (0.7, -0.7, 0.2)  # WeaponPose T.PoleRight (the elbow down and out)
BODY = [((-1.0, 1.0), (-0.8, 0.8), (-0.5, 0.5)), ((-1.0, 1.0), (-1.6, -0.8), (-0.5, 0.5))]  # UpperTorso, LowerTorso boxes
# A23-133: measured on place/GoodEvil.rbxlx's default R15 (Workspace NPCs PotionMerchant): the feet' bottom 0, the
# UpperTorso centre 3.206, the shoulder joints 3.81, the head's top 5.18 (the old 3.9 was an estimate)
TORSO_ABOVE_FEET = 3.21  # studs, UpperTorso centre over the feet
AVATAR_H = 5.18  # studs, the feet to the top of the head at scale 1
SHOULDER_ABOVE_FEET = 3.8
TORSO_HALF = (1.0, 0.5)  # x, z half sizes of the UpperTorso box
# A23-133 (grip_reference §5): held lengths as shares of AVATAR_H; hands as shares of the length from its butt end / foot
REACH = {"Sword": (0.72, 0.95), "SwordHand": (0.10, 0.22), "BladeRest": (1.3, 2.5), "Staff": (0.65, 0.75),
         "StaffHand": (0.40, 0.55), "OrbClear": 1.2, "FootOff": 0.3, "Bow": (0.55, 0.97), "ShortBow": 0.72, "Hammer": (0.35, 0.55), "HammerHand": (0.15, 0.33),
         "Baton": (0.3, 0.6)}
# 최종 검수 10/12 (grip_reference §5-6): the staff rows' hand height over the ground, the wrist (radial = towards the
# thumb, flex = back / forward), the forearm / hand out of the torso
STAFF_ROWS = ("Mage_Halo", "Mage_Horns", "Mage_Neutral")
STAFF_POSE = {"Grip": (2.45, 2.75), "Radial": 20, "Flex": 40, "Out": 0.2}
ORB_UP = 1.75  # studs: the hand to the orb's centre along a staff (A23-142: 0.57 x ~3.6 - half the orb)
ORB_CLEAR = (-1.05, 1.3)  # torso space: the face's front is z -0.6, the head's side x 0.6
# 최종 검수 10/13 (side 90 deg, staff_front_v3f): the orb's back >= 0.2 ahead of the face's front (-0.6, a Neck bow a
# little further): its centre (the crook's hangs off the hook, read from SHAPES.CrookStaff) + a 0.35 radius <= FACE_FRONT
FACE_FRONT, FACE_GAP, ORB_R = -0.6, 0.2, 0.35
WORLD_TILT = 10  # deg: a staff's lean in the world (its tilt + the row's Waist hunch) - more lay across the body (10/12 photo)


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
    pole = re.search(r"OneHand = \{[^\n]*?Pole = Vector3\.new\(" + NUM + ", " + NUM + ", " + NUM + r"\)", body)
    weapon = re.match(r' Weapon = "(\w+)"', body)
    return {"Hilt": tuple(v[:3]), "Aim": G.unit(tuple(v[3:])), "HoldText": body.split("OneHand", 1)[0],
            "Pole": tuple(float(pole[i]) for i in range(1, 4)) if pole else DEFAULT_POLE,
            "Weapon": weapon[1] if weapon else None, "Body": body}


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
    """A23-142: CharacterVisuals STAFF + staffLen (a share of the avatar's height) + staffOrb (the orb shrinks to keep
    OrbClear) + the hand at Grip of the length in every staff shape"""
    m = re.search(r"local STAFF = \{ Grip = " + NUM + ", OrbClear = " + NUM + ", Height = " + NUM + ", Orb = " + NUM
                  + ", OrbPerTier = " + NUM + r" \}", cv)
    uses = (cv.count("local total, h = staffLen(w, height, sc)") == 3
            and 'local h = (type(height) == "number" and height > 0) and height / sc or STAFF.Height' in cv
            and "return h * tierLen(w, LEN.Staff)" in cv
            and "local room = total * (1 - STAFF.Grip) - STAFF.OrbClear * h / STAFF.Height - a" in cv
            and "local low = total * STAFF.Grip -- studs from the foot up to the hand" in cv
            and cv.count("local base, low = fist(grip), total * STAFF.Grip") == 2)
    orb = re.search(r"return math\.max\(" + NUM + r", math\.min\(STAFF\.Orb \+ STAFF\.OrbPerTier \* tier, room / b\)\)", cv)
    if not (m and uses):
        return None
    v = [float(m[i]) for i in range(1, 6)]
    return {"Grip": v[0], "OrbClear": v[1], "Height": v[2], "Orb": v[3], "OrbPer": v[4],
            "Shrink": orb is not None, "MinOrb": float(orb[1]) if orb else 0.0}


def staff_orb(rule, tier: int, total: float, h: float, a: float, b: float) -> float:
    """CharacterVisuals.staffOrb (h = the avatar's height)"""
    want = rule["Orb"] + rule["OrbPer"] * tier
    if not rule["Shrink"]:
        return want
    room = total * (1 - rule["Grip"]) - rule["OrbClear"] * h / rule["Height"] - a
    return max(rule["MinOrb"], min(want, room / b))


def staff_kinds(cv: str, rule):
    """A23-142: the three staff shapes as (total, tier, h) -> (top over the foot, the orb's bottom over the foot), read from
    the source (buildStaff, SHAPES.CrookStaff, SHAPES.FlaskStaff); None for a shape that cannot be read"""
    out = {}
    b = body_of(cv, "local function buildStaff(grip, sc, w, color, tier, height)")
    sh = re.search(r"local shaftLen = total - d \* " + NUM, b)
    tip = re.search(r"\(shaftLen - low \+ d \* " + NUM + r"\) \* sc", b)
    sd = re.search(r"local d = staffOrb\(tier, total, h, " + NUM + ", " + NUM + r"\)", b)
    if sh and tip and sd:
        k1, k2, a, bb = float(sh[1]), float(tip[1]), float(sd[1]), float(sd[2])

        def staff(total, tier, h, k1=k1, k2=k2, a=a, bb=bb):
            d = staff_orb(rule, tier, total, h, a, bb)
            shaft = total - d * k1
            return max(shaft, shaft + d * (k2 + 0.5)), shaft + d * (k2 - 0.5)
        out["Staff"] = staff
    b = body_of(cv, "function SHAPES.CrookStaff(grip, sc, w, color, tier, height)")
    kk = re.search(r"local K = \{ Hook = " + NUM + ", OrbX = " + NUM + ", OrbY = " + NUM + r", Bend = " + NUM + r" \}", b)
    if kk and "local shaftLen = total - K.Hook" in b and "local d = staffOrb(tier, total, h, K.Hook - K.OrbY, 0.5)" in b \
            and ("CFrame = top * CFrame.new(0, K.OrbY * sc, -K.OrbX * sc)," in b or "CFrame = top * CFrame.new(K.OrbX * sc, K.OrbY * sc, 0)," in b):
        hook, oy = float(kk[1]), float(kk[3])

        def crook(total, tier, h, hook=hook, oy=oy):
            d = staff_orb(rule, tier, total, h, hook - oy, 0.5)
            shaft = total - hook
            return shaft + hook, shaft + oy - d / 2
        out["CrookStaff"] = crook
    fs = flask_staff(cv)
    if fs and fs["Shaft"] and fs["Flask"] and fs["CorkAt"]:
        def flask(total, tier, h, f=fs):
            d = staff_orb(rule, tier, total, h, f["Neck"] + f["Cork"], 1)
            shaft = total - d * (f["Sit"] + 0.5) - (f["Neck"] + f["Cork"])
            return shaft + d * (f["Sit"] + 0.5) + f["Neck"] + f["Cork"], shaft + d * f["Sit"] - d / 2
        out["FlaskStaff"] = flask
    return out


def hand_height(torso: float, hilt_y: float, k: float) -> float:
    """the hand's height over the ground in the staff pose: the UpperTorso centre + the Hilt y x the body scale"""
    return torso + hilt_y * k


# 게임성 검수 10/11 (other avatars): (name, UpperTorso centre over the ground, WeaponPose body scale); A23-142: their
# heights = the centre + the default rig's centre-to-head-top (5.18 - 3.21) x the body scale
STAFF_RIGS = [("the place's default R15", TORSO_ABOVE_FEET, 1.0), ("long legs (+0.5)", TORSO_ABOVE_FEET + 0.5, 1.0),
              ("height 0.9, narrow", TORSO_ABOVE_FEET * 0.9, 0.75), ("height 1.05", TORSO_ABOVE_FEET * 1.05, 1.0)]


def rig_height(torso: float, k: float) -> float:
    return torso + (AVATAR_H - TORSO_ABOVE_FEET) * k


def len_rule(cv: str):
    """A23-133: CharacterVisuals LEN (the Config Length range -> studs per kind), read by tierLen in every shape"""
    m = re.search(r"local LEN = \{ From = \{ " + NUM + ", " + NUM + r" \}, Blade = \{ " + NUM + ", " + NUM + r" \}, Staff = \{ "
                  + NUM + ", " + NUM + r" \}, Bow = \{ " + NUM + ", " + NUM + r" \} \}", cv)
    fn = ("local t = math.clamp(((tonumber(w.Length) or LEN.From[1]) - LEN.From[1]) / (LEN.From[2] - LEN.From[1]), 0, 1)" in cv
          and "return to[1] + (to[2] - to[1]) * t" in cv)
    uses = (cv.count("local bladeLen = tierLen(w, LEN.Blade)") == 2 and "local H = tierLen(w, LEN.Bow) * (tonumber(scale) or 1)" in cv
            and "Size = Vector3.new(0.25, w.Length" not in cv)
    if not (m and fn and uses):
        return None
    v = [float(m[i]) for i in range(1, 9)]
    return {"From": v[0:2], "Blade": v[2:4], "Staff": v[4:6], "Bow": v[6:8]}


def tier_len(rule, kind: str, length: float) -> float:
    if not rule:  # the old shapes: the Config Length itself
        return length
    a, b = rule["From"]
    t = min(max((length - a) / (b - a), 0.0), 1.0)
    lo, hi = rule[kind]
    return lo + (hi - lo) * t


def weapon_lengths(cfg: str):
    """the weapon tiers (1..N) - the staff length now comes from STAFF.Len / PerTier per tier"""
    return [float(x) for x in re.findall(r"\n\t\{ Tier = \d, [^\n]*?Length = " + NUM, cfg)]


def flask_staff(cv: str):
    """최종 검수 10/12: SHAPES.FlaskStaff (the approved 2D: a staff with a flask) - its numbers and parts"""
    m = re.search(r"function SHAPES\.FlaskStaff\(grip, sc, w, color, tier, height\)(.*?)\nend", cv, re.S)
    if not m:
        return None
    b = m.group(1)
    f = re.search(r"local F = \{ Neck = " + NUM + ", Cork = " + NUM + ", Sit = " + NUM + ", Wrap = " + NUM, b)
    if not f:
        return None
    return {"Neck": float(f[1]), "Cork": float(f[2]), "Sit": float(f[3]), "WrapLen": float(f[4]),
            "Shaft": "local shaftLen = total - d * (F.Sit + 0.5) - (F.Neck + F.Cork)" in b
            and "local base, low = fist(grip), total * STAFF.Grip" in b
            and re.search(r'Name = "Shaft",[^}]*CFrame = base \* CFrame\.new\(0, \(shaftLen / 2 - low\) \* sc, 0\)', b, re.S) is not None,
            "Wrap": re.search(r'Name = "Wrap",[^}]*CFrame = base,', b, re.S) is not None,
            "Top": "local top = base * CFrame.new(0, (shaftLen - low) * sc, 0)" in b,
            "Flask": "local d = staffOrb(tier, total, h, F.Neck + F.Cork, 1)" in b
            and re.search(r'Name = "Flask", Shape = Enum\.PartType\.Ball,[^}]*CFrame = top \* CFrame\.new\(0, d \* F\.Sit \* sc, 0\)', b, re.S) is not None,
            "CorkAt": "local neckAt = d * (F.Sit + 0.5) + F.Neck / 2" in b
            and "CFrame = top * CFrame.new(0, (neckAt + F.Neck / 2 + F.Cork / 2) * sc, 0)," in b,
            "Main": "return parts, flask" in b}


def line_clear_of_torso(point, aim):
    # sample the weapon line +-3 studs around the hand; inside the torso box (|x| < 1, |z| < 0.5, |y| < 0.8) = hit
    for i in range(-30, 31):
        p = G.add(point, aim, i / 10)
        if abs(p[0]) < TORSO_HALF[0] and abs(p[2]) < TORSO_HALF[1] and abs(p[1]) < 0.8:
            return False
    return True


def body_gap(a, b, k, n=24):
    """the closest the segment a-b comes to the (scaled) UpperTorso / LowerTorso boxes"""
    best = 9.0
    for i in range(n + 1):
        p = G.add(a, G.sub(b, a), i / n)
        for (x0, x1), (y0, y1), (z0, z1) in BODY:
            dx = max(x0 * k - p[0], 0.0, p[0] - x1 * k)
            dy = max(y0 * k - p[1], 0.0, p[1] - y1 * k)
            dz = max(z0 * k - p[2], 0.0, p[2] - z1 * k)
            best = min(best, math.sqrt(dx * dx + dy * dy + dz * dz))
    return best


def thigh_gap(a, b, k, n=40):
    """the closest the segment a-b comes to the right thigh box, the leg swung about x by -Swing..Swing deg"""
    hip = tuple(v * k for v in THIGH["Hip"])
    hx, hz = THIGH["Half"]
    best = 9.0
    for deg in range(-THIGH["Swing"], THIGH["Swing"] + 1, 5):
        c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
        for i in range(n + 1):
            q = G.sub(G.add(a, G.sub(b, a), i / n), hip)
            y, z = q[1] * c + q[2] * s, -q[1] * s + q[2] * c  # into the swung leg's frame
            dx = max(abs(q[0]) - hx * k, 0.0)
            dy = max(THIGH["Bottom"] * k - y, 0.0, y - THIGH["Top"] * k)
            dz = max(abs(z) - hz * k, 0.0)
            best = min(best, math.sqrt(dx * dx + dy * dy + dz * dz))
    return best


def split_args(text: str) -> list[str]:
    out, depth, cur = [], 0, ""
    for ch in text:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
        else:
            cur += ch
    return out + [cur.strip()]


def sword_parts(body: str, names: dict):
    """the accPart blocks of a sword builder: name -> list of (size, centre) along L (+Y = the blade's way)"""
    parts = {}
    for name, block in re.findall(r'Name = "(\w+)",(.*?)\}\)', body, re.S):
        size = re.search(r"Size = Vector3\.new\(([^)]*)\) \* sc", block)
        cf = re.search(r"CFrame = L \* CFrame\.new\((.*?)\)(?: \* CFrame\.Angles|,\n)", block, re.S)
        if not size:
            continue
        # a part built in a `for _, s in { -1, 1 }` loop (the dark guard's two halves) = one part per side
        for s in ((-1.0, 1.0) if re.search(r"\bs \*", block) else (1.0,)):
            env = dict(names, s=s)
            try:
                sz = tuple(float(eval(x, {"__builtins__": {}}, env)) for x in split_args(size.group(1)))
                at = (tuple(float(eval(x, {"__builtins__": {}}, env)) for x in split_args(cf.group(1))) if cf
                      else ((0.0, 0.0, 0.0) if re.search(r"CFrame = L,", block) else None))
            except Exception:  # noqa: BLE001 - an unreadable expression = no part
                continue
            if at is not None:
                parts.setdefault(name, []).append((sz, at))
    return parts


class _NS:
    def __init__(self, **kw):
        self.__dict__.update(kw)


def sword_dims(cv: str, length: float):
    """buildSword's and SHAPES.DarkSword's parts for a blade of this length, plus the dark guard's sweep"""
    b = re.search(r"local function buildSword\(grip, sc, w, color\)(.*?)\nend\n", cv, re.S)
    d = re.search(r"function SHAPES\.DarkSword\(grip, sc, w, color\)(.*?)\nend\n", cv, re.S)
    hb = b and re.search(r"local handleLen = " + NUM, b.group(1))
    hd = d and re.search(r"local D = \{ Handle = " + NUM + r",[^\n]*Sweep = " + NUM + r" \}", d.group(1))
    if not (hb and hd):
        return None
    w = _NS(Length=length)
    blade = tier_len(len_rule(cv), "Blade", length)  # A23-133: the blade from LEN
    sword = sword_parts(b.group(1), {"handleLen": float(hb[1]), "w": w, "sc": 1.0, "bladeLen": blade})
    dark = sword_parts(d.group(1), {"D": _NS(Handle=float(hd[1])), "w": w, "sc": 1.0, "bladeLen": blade})
    return {"Sword": sword, "Dark": dark, "Sweep": float(hd[2]), "Handle": float(hb[1]), "DarkHandle": float(hd[1])}


def dark_sword_checks(cv: str, lens: list[float]) -> list[tuple[str, bool, str]]:
    out = []
    dims = [sword_dims(cv, L) for L in lens] or [None]
    ok = all(x and all(k in x["Sword"] for k in ("Handle", "Guard", "Blade")) and all(k in x["Dark"]
             for k in ("Handle", "Guard", "Blade", "Pommel")) for x in dims)
    out.append(("A23-128 / 검수 10/11: buildSword and SHAPES.DarkSword are readable (handle, guard, blade, pommel)", ok,
                f"{len(lens)} tiers"))
    if not ok:
        return out
    x = dims[0]
    sh, dh = x["Sword"]["Handle"][0], x["Dark"]["Handle"][0]
    out.append(("DarkSword: the handle as long and thick as the Paladin's sword, centred on the grip",
                sh[0] == dh[0] and sh[1] == dh[1] and dh[1] == (0.0, 0.0, 0.0), f"{sh} / {dh}"))
    same_blade = all(d["Sword"]["Blade"][0] == d["Dark"]["Blade"][0] for d in dims)
    out.append(("DarkSword: the blade the same size and spot as buildSword's for every tier length", same_blade,
                ", ".join(f"{d['Dark']['Blade'][0]}" for d in dims[:2])))
    sg = x["Sword"]["Guard"][0]
    sweep = math.radians(x["Sweep"])
    width = 2 * max(abs(at[0]) + sz[0] / 2 * math.cos(sweep) + sz[1] / 2 * math.sin(sweep) for sz, at in x["Dark"]["Guard"])
    heights = [at[1] for _, at in x["Dark"]["Guard"]]
    out.append(("DarkSword: the guard at the same height on the handle (+-0.05) and about as wide (+-0.15)",
                len(heights) == 2 and all(abs(h - sg[1][1]) <= 0.05 for h in heights) and abs(width - sg[0][0]) <= 0.15,
                f"{heights} vs {sg[1][1]}, width {width:.2f} vs {sg[0][0]}"))
    pz, pat = x["Dark"]["Pommel"][0]
    h = x["DarkHandle"]
    out.append(("DarkSword: a small round pommel right at the handle's end (<= 0.45 across)",
                max(pz) <= 0.45 and -(h / 2 + 0.25) <= pat[1] <= -h / 2 and pat[0] == 0 and pat[2] == 0, f"{pz} at {pat}"))
    return out


def sword_reach(cv: str, kind: str):
    """how far the held sword's handle (+ pommel) reaches back from the grip point, and its guard forward"""
    d = sword_dims(cv, 3.0)
    if not d:
        return None
    parts = d["Dark" if kind == "DarkSword" else "Sword"]
    back = max(-at[1] + sz[1] / 2 for name in ("Handle", "Pommel") for sz, at in parts.get(name, []))
    front = max(at[1] + sz[1] / 2 for sz, at in parts.get("Guard", []))
    return back, front


def body_of(cv: str, head: str):
    m = re.search(re.escape(head) + r"(.*?)\nend\n", cv, re.S)
    return m.group(1) if m else ""


def within(v: float, span) -> bool:
    return span[0] <= v <= span[1]


def length_checks(src: dict) -> list[tuple[str, bool, str]]:
    """A23-133 (user 10/11 "무기가 너무 길어서 잡는 위치가 이상해"; grip_reference §5): the held lengths against the avatar's
    height (AVATAR_H) at every Config.Weapons tier, and where the hand holds them"""
    cv, H = src["CV"], AVATAR_H
    lrule, srule, lens = len_rule(cv), staff_rule(cv), weapon_lengths(src["CONFIG"])
    out = [("A23-133: LEN / tierLen read; the swords, staffs and bows take their length from it",
            lrule is not None and srule is not None and len(lens) >= 7, f"{lrule}")]
    if not (lrule and srule and lens):
        return out
    by_len = sorted(range(len(lens)), key=lambda i: lens[i])
    # the swords: from the butt end (the handle's / pommel's far end) to the blade's tip; the hand = the grip point (0)
    for kind, key in (("Paladin's Sword", "Sword"), ("Berserker's DarkSword", "Dark")):
        rows = []
        for length in lens:
            d = sword_dims(cv, length)
            parts = d[key] if d else {}
            if not (parts.get("Blade") and parts.get("Handle")):
                rows = []
                break
            butt = min(at[1] - sz[1] / 2 for name in ("Handle", "Pommel") for sz, at in parts.get(name, []))
            tip = max(at[1] + sz[1] / 2 for sz, at in parts["Blade"])
            blade = parts["Blade"][0][0][1]
            total = tip - butt
            rows.append({"H": total / H, "Hand": -butt / total, "Ratio": blade / (total - blade), "Studs": total})
        ok = len(rows) == len(lens)
        out.append((f"A23-133: the {kind} {REACH['Sword'][0]}..{REACH['Sword'][1]} of the avatar's height (butt to tip) "
                    "at every tier, never shorter at a longer tier", ok and all(within(r["H"], REACH["Sword"]) for r in rows)
                    and all(rows[a]["Studs"] <= rows[b]["Studs"] + 1e-9 for a, b in zip(by_len, by_len[1:])),
                    ", ".join(f"{r['Studs']:.2f}/{r['H']:.2f}" for r in rows)))
        out.append((f"A23-133: the {kind}'s hand {REACH['SwordHand'][0]:.0%}..{REACH['SwordHand'][1]:.0%} up from its butt end, "
                    f"the blade {REACH['BladeRest'][0]}..{REACH['BladeRest'][1]}x the hilt",
                    ok and all(within(r["Hand"], REACH["SwordHand"]) and within(r["Ratio"], REACH["BladeRest"]) for r in rows),
                    ", ".join(f"{r['Hand']:.2f}/{r['Ratio']:.2f}" for r in rows)))
    # A23-142 (user 10/12): the three staffs against each avatar's own height, every tier
    kinds = staff_kinds(cv, srule)
    hands = {k: row(src["CONFIG"], k) for k in STAFF_ROWS}
    rows = []
    for name, torso, k in STAFF_RIGS:
        Hr = rig_height(torso, k)
        for key, r in hands.items():
            hand = hand_height(torso, r["Hilt"][1], k)
            for kind, shape in kinds.items():
                for tier, length in enumerate(lens, start=1):
                    total = Hr * tier_len(lrule, "Staff", length)
                    top, orb_bottom = shape(total, tier, Hr)
                    low = total * srule["Grip"]
                    rows.append({"Rig": name, "Kind": kind, "Tier": tier, "H": top / Hr, "Grip": low / top,
                                 "Clear": (orb_bottom - low) * AVATAR_H / Hr, "Foot": hand - low, "Top": hand - low + top,
                                 "Head": Hr})
    ok_read = len(kinds) == 3 and len(rows) == len(STAFF_RIGS) * len(hands) * 3 * len(lens)
    out.append((f"A23-142: every staff (orb / hook / flask included) {REACH['Staff'][0]}..{REACH['Staff'][1]} of the avatar's own "
                "height (every tier, kind and avatar)", ok_read and all(within(round(r["H"], 9), REACH["Staff"]) for r in rows),
                f"{min(r['H'] for r in rows):.3f}..{max(r['H'] for r in rows):.3f}" if rows else f"{list(kinds)}"))
    out.append((f"A23-142: held {REACH['StaffHand'][0]:.0%}..{REACH['StaffHand'][1]:.0%} up from the foot (the middle wrap)",
                ok_read and all(within(round(r["Grip"], 9), REACH["StaffHand"]) for r in rows),
                f"{min(r['Grip'] for r in rows):.2f}..{max(r['Grip'] for r in rows):.2f}" if rows else ""))
    out.append((f"A23-142: the orb's bottom >= {REACH['OrbClear']} studs over the hand on the default avatar (scaled with the "
                "height; the head never in the fist)",
                ok_read and all(r["Clear"] >= REACH["OrbClear"] - 1e-9 for r in rows),
                f"min {min(r['Clear'] for r in rows):.2f}" if rows else ""))
    out.append((f"A23-142: carried off the ground - the foot >= {REACH['FootOff']} over it (never in it), the top under the "
                "head's top + 0.3", ok_read and all(r["Foot"] >= REACH["FootOff"] and r["Top"] <= r["Head"] + 0.3 for r in rows),
                f"foot {min(r['Foot'] for r in rows):.2f}..{max(r['Foot'] for r in rows):.2f}" if rows else ""))
    # the bows (held in the middle: buildBow centres the riser on the grip)
    short = re.search(r"return buildBow\(grip, sc, w, color, " + NUM + ", " + NUM + r"\)", body_of(cv, "function SHAPES.ShortBow("))
    bows = [tier_len(lrule, "Bow", length) / H for length in lens]
    k = float(short[1]) if short else 1.0
    out.append((f"A23-133: the bow {REACH['Bow'][0]}..{REACH['Bow'][1]} of the avatar's height, the Shadow Hunter's short bow "
                f"<= {REACH['ShortBow']}", all(within(b, REACH["Bow"]) for b in bows) and max(bows) * k <= REACH["ShortBow"],
                f"{min(bows):.2f}..{max(bows):.2f}, short x{k}"))
    # the smithing hammer: the handle's bottom to the head's top, held low on the handle
    hb = body_of(cv, "function SHAPES.Hammer(grip, sc, w, color)")
    hl = re.search(r"local handleLen = " + NUM, hb)
    lo = re.search(r"local base, low = fist\(grip\), handleLen \* " + NUM, hb)
    hd = re.search(r'Name = "Head", Size = Vector3\.new\(' + NUM + ", " + NUM + ", " + NUM + r"\) \* sc,[^}]*CFrame = base \* "
                   r"CFrame\.new\(0, \(handleLen - low\) \* sc, 0\)", hb, re.S)
    if hl and lo and hd:
        total = float(hl[1]) + float(hd[2]) / 2
        out.append((f"A23-133: the smithing hammer {REACH['Hammer'][0]}..{REACH['Hammer'][1]} of the avatar's height, held "
                    f"{REACH['HammerHand'][0]:.0%}..{REACH['HammerHand'][1]:.0%} up the handle",
                    within(total / H, REACH["Hammer"]) and within(float(hl[1]) * float(lo[1]) / total, REACH["HammerHand"]),
                    f"{total / H:.2f} / {float(hl[1]) * float(lo[1]) / total:.2f}"))
    else:
        out.append(("A23-133: the smithing hammer is readable", False, ""))
    # the tamer's baton (the biggest tip)
    bb = body_of(cv, "local function buildBaton(grip, sc, w, color, tier)")
    bl = re.search(r"local shaftLen = " + NUM, bb)
    bd = re.search(r"local d = " + NUM + r" \+ " + NUM + r" \* tier", bb)
    bt = re.search(r"\(shaftLen - low \+ d \* " + NUM + r"\) \* sc", bb)
    if bl and bd and bt:
        d = float(bd[1]) + float(bd[2]) * len(lens)
        total = (float(bl[1]) + d * (float(bt[1]) + 0.5)) / H
        out.append((f"A23-133: the baton {REACH['Baton'][0]}..{REACH['Baton'][1]} of the avatar's height", within(total, REACH["Baton"]),
                    f"{total:.2f}"))
    else:
        out.append(("A23-133: the baton is readable", False, ""))
    return out


def geometry(src: dict) -> list[tuple[str, bool, str]]:
    out = []
    wp = src["WP"]
    for key, spec in ROWS.items():
        r = row(src["CONFIG"], key)
        out.append((f"{key}: OneHand (Hilt, Aim) is readable", r is not None, ""))
        if not r:
            continue
        hilt, aim = r["Hilt"], r["Aim"]
        worst = {"reach": 0.0, "dist": 0.0, "axis": 0.0, "fore": (180.0, 0.0), "elbow": (-9.0, 9.0, 9.0), "elbowIn": 9.0,
                 "wrist": 0.0, "foreGap": 9.0, "handGap": 9.0, "swordThigh": 9.0, "handThigh": 9.0, "upper": 9.0,
                 "radial": -90.0, "flex": 0.0}
        reach = sword_reach(src["CV"], spec.get("Sword") or "Sword")
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
            pole = r["Pole"]  # WeaponPose: the row's OneHand Pole, else T.PoleRight
            ax = G.unit(G.sub(wrist, shoulder))
            along = (d * d + l1 * l1 - l2 * l2) / (2 * d)
            h = math.sqrt(max(0.0, l1 * l1 - along * along))
            bend = G.unit(G.sub(pole, tuple(x * G.dot(pole, ax) for x in ax)))
            elbow = G.add(G.add(shoulder, ax, along), bend, h)
            fore = G.angle(G.sub(wrist, elbow), aim)
            worst["fore"] = (min(worst["fore"][0], fore), max(worst["fore"][1], fore))
            # the elbow's widest spot out from the side (x, unscaled) and its height (y) against the hand's
            worst["elbow"] = (max(worst["elbow"][0], elbow[0] / k), min(worst["elbow"][1], elbow[1] - wrist[1]),
                              min(worst["elbow"][2], elbow[2] - wrist[2]))
            worst["elbowIn"] = min(worst["elbowIn"], elbow[0] / k)
            # 검수 10/11: the wrist (the forearm's up against the hand's up), the forearm / hand against the torso boxes,
            # the handle + pommel and the hand against the swinging thigh (all unscaled)
            worst["wrist"] = max(worst["wrist"], G.angle(G.sub(elbow, wrist), frame[1]))
            # 최종 검수 10/12: the wrist split - towards the thumb (the hand's -Z; radial, normal 15..25 deg) and back /
            # forward (about the knuckle line)
            fa = G.unit(G.sub(elbow, wrist))
            fy, fz, fx = G.dot(fa, frame[1]), G.dot(fa, frame[2]), G.dot(fa, frame[0])
            worst["radial"] = max(worst["radial"], math.degrees(math.atan2(-fz, fy)))
            worst["flex"] = max(worst["flex"], abs(math.degrees(math.atan2(fx, fy))))
            bottom = G.add(pos, frame[1], -SWORD["HandLen"] * k)
            worst["foreGap"] = min(worst["foreGap"], body_gap(elbow, wrist, k) / k)
            # 게임성 검수 10/11: the upper arm too (its lower half, mid -> elbow; the top half sits at the shoulder joint,
            # inside the torso's edge on every rig)
            worst["upper"] = min(worst["upper"], body_gap(G.add(shoulder, G.sub(elbow, shoulder), 0.5), elbow, k) / k)
            worst["handGap"] = min(worst["handGap"], body_gap(wrist, bottom, k) / k)
            worst["handThigh"] = min(worst["handThigh"], thigh_gap(wrist, bottom, k) / k - SWORD["Hand"])
            if reach:
                tail, head = G.add(hk, aim, -reach[0] * k), G.add(hk, aim, reach[1] * k)
                worst["swordThigh"] = min(worst["swordThigh"], thigh_gap(tail, head, k) / k - SWORD["Thick"])
        out.append((f"{key}: the arm reaches (<= 92%)", worst["reach"] <= 0.92, f"{worst['reach']:.2f}"))
        out.append((f"{key}: the grip point on the weapon line (<= 0.2) and the held axis along it (<= 10 deg)",
                    worst["dist"] <= 0.2 and worst["axis"] <= 10, f"{worst['dist']:.3f} / {worst['axis']:.1f}"))
        out.append((f"{key}: the forearm crosses the weapon (45..135 deg)", 45 <= worst["fore"][0] and worst["fore"][1] <= 135,
                    f"{worst['fore'][0]:.0f}..{worst['fore'][1]:.0f}"))
        out.append((f"{key}: 게임성 검수 10/11 the upper arm's lower half stays out of the torso / hip boxes "
                    f"(>= {SWORD['Upper']}; the hanging arm's is 0.22)", worst["upper"] >= SWORD["Upper"], f"{worst['upper']:.2f}"))
        tilt = G.angle(aim, (0.0, 1.0, 0.0))
        if spec["Tilt"] is None:
            # A23-128 (user 10/11 "한손검만"; grip_reference §1-8): a one-hand sword in the right hand at the side
            elev = math.degrees(math.atan2(aim[1], -aim[2]))
            out.append((f"{key}: holds the one-hand '{spec['Sword']}' (no two-hand grip, no great sword)",
                        r["Weapon"] == spec["Sword"] and "TwoHand" not in r["Body"], f"{r['Weapon']}"))
            out.append((f"{key}: the hand at the right side just outside the hanging arm's line, waist height, a little ahead",
                        1.4 <= hilt[0] <= 1.75 and -1.0 <= hilt[1] <= -0.6 and -0.9 <= hilt[2] <= -0.4, f"{hilt}"))
            lo, hi = SWORD["Elev"]
            out.append((f"{key}: the tip ahead and {lo}..{hi} deg up, never across the body, the line clear of the torso",
                        lo <= elev <= hi and aim[2] < -0.4 and 0 <= aim[0] <= 0.3 and line_clear_of_torso(hilt, aim),
                        f"{elev:.0f} deg, aim {tuple(round(x, 2) for x in aim)}"))
            e0, e1 = SWORD["Elbow"]
            out.append((f"{key}: the elbow low near the hanging arm's line (x {e0}..{e1}, never tucked in), above and behind "
                        "the hand", e0 <= worst["elbowIn"] and worst["elbow"][0] <= e1 and worst["elbow"][1] > 0.1
                        and worst["elbow"][2] > 0.3, f"x {worst['elbowIn']:.2f}..{worst['elbow'][0]:.2f}, "
                        f"{tuple(round(x, 2) for x in worst['elbow'])}"))
            out.append((f"{key}: 검수 10/11 the forearm (>= {SWORD['Fore']}) and the hand (>= {SWORD['Hand']}) stay out of the "
                        "torso / hip boxes", worst["foreGap"] >= SWORD["Fore"] and worst["handGap"] >= SWORD["Hand"],
                        f"forearm {worst['foreGap']:.2f}, hand {worst['handGap']:.2f}"))
            out.append((f"{key}: 검수 10/11 the wrist nearly straight (<= {SWORD['Wrist']} deg)", worst["wrist"] <= SWORD["Wrist"],
                        f"{worst['wrist']:.1f} deg"))
            out.append((f"{key}: 검수 10/11 the handle + pommel and the hand clear the thigh swinging +-{THIGH['Swing']} deg",
                        reach is not None and worst["swordThigh"] >= SWORD["ThighGap"] and worst["handThigh"] >= 0.0,
                        f"sword {worst['swordThigh']:.2f}, hand {worst['handThigh']:.2f}, reach {reach}"))
            out.append((f"{key}: the left hand is empty and hangs (no OffHand, no left-arm hold)",
                        "OffHand" not in r["Body"] and "Left" not in r["HoldText"], ""))
        else:
            # 디자인 검수 10/12 (the orb by the face from the side): splayed 3..8 deg out, never in, never flagged far out
            splay = math.degrees(math.atan2(aim[0], aim[1]))
            out.append((f"{key}: upright (tilt <= {spec['Tilt']} deg), splayed out 3..8 deg (never in, never far out)",
                        tilt <= spec["Tilt"] and 3 <= splay <= 8, f"{tilt:.0f} deg, splay {splay:.1f}"))
        if spec["Tilt"] is None:
            pass
        elif spec["Staff"]:
            out.append((f"{key}: the staff stands beside the body (hand outside the torso, the line clear of it)",
                        hilt[0] >= 0.8 and line_clear_of_torso(hilt, aim), f"{hilt}"))
            # 디자인 검수 10/12 (staff_short_v2 side photo: the orb right beside / in front of the face): the orb (about
            # ORB_UP along the staff over the hand) ahead of the face and outside the head - torso space z / x
            orb = G.add(hilt, aim, ORB_UP)
            if r["Weapon"] == "CrookStaff":  # the orb hangs off the hook: along the fist's -Z (ahead) or its +X (old: back)
                shoulder0, _, _, _, grip0 = G.rig("R", 1.0)
                fr, _ = G.goal(hilt, grip0, shoulder0, aim, wp)
                cb = body_of(src["CV"], "function SHAPES.CrookStaff(grip, sc, w, color, tier, height)")
                kk = re.search(r"OrbX = " + NUM + ", OrbY = " + NUM, cb)
                ox = float(kk[1]) if kk else 0.0
                if "CFrame = top * CFrame.new(0, K.OrbY * sc, -K.OrbX * sc)," in cb:
                    orb = G.add(orb, fr[1], -ox)
                else:
                    orb = G.add(orb, fr[0], ox)
            neck = re.search(r"Neck = \{ " + NUM, r["HoldText"])
            face = FACE_FRONT - 0.6 * math.sin(math.radians(max(0.0, -float(neck[1])))) if neck else FACE_FRONT
            out.append((f"{key}: 디자인 검수 10/12 the orb clears the face (ahead z <= {ORB_CLEAR[0]}, outside x >= {ORB_CLEAR[1]})",
                        orb[2] <= ORB_CLEAR[0] and orb[0] >= ORB_CLEAR[1], f"z {orb[2]:.2f}, x {orb[0]:.2f}"))
            out.append((f"{key}: 최종 검수 10/13 from the side (90 deg) the orb's back is >= {FACE_GAP} ahead of the face",
                        orb[2] + ORB_R <= face - FACE_GAP, f"orb back {orb[2] + ORB_R:.2f}, face {face:.2f}"))
            g0, g1 = STAFF_POSE["Grip"]
            grip_y = TORSO_ABOVE_FEET + hilt[1]
            out.append((f"{key}: 최종 검수 10/12 the hand lowered from the chest to {g0}..{g1} studs over the ground (it was 2.9)",
                        g0 <= grip_y <= g1, f"{grip_y:.2f}"))
            out.append((f"{key}: 최종 검수 10/12 the wrist <= {STAFF_POSE['Radial']} deg towards the thumb and <= "
                        f"{STAFF_POSE['Flex']} deg back / forward (grip_reference §5-6)",
                        worst["radial"] <= STAFF_POSE["Radial"] and worst["flex"] <= STAFF_POSE["Flex"],
                        f"{worst['radial']:.1f} / {worst['flex']:.1f} deg"))
            out.append((f"{key}: 최종 검수 10/12 the forearm and the hand >= {STAFF_POSE['Out']} out of the torso",
                        worst["foreGap"] >= STAFF_POSE["Out"] and worst["handGap"] >= STAFF_POSE["Out"],
                        f"forearm {worst['foreGap']:.2f}, hand {worst['handGap']:.2f}"))
        out.append((f"{key}: no right-arm hold angles fight the placement",
                    "RightShoulder" not in r["HoldText"] and "RightElbow" not in r["HoldText"] and "RightWrist" not in r["HoldText"], ""))
    # 최종 검수 10/12 (keep the sides apart, GDD §0; main photo: the Dark Mage's staff lay across the body): every staff
    # within WORLD_TILT of upright in the world (its torso-space tilt forward + the row's Hold Waist lean: -Waist), the
    # Light Mage's the most upright and his hand not lower than the others', the Dark Mage hunched (Waist <= -6)
    sr = {k: row(src["CONFIG"], k) for k in STAFF_ROWS}
    if all(sr.values()):
        def waist(key):
            j = re.search(r"Waist = \{ " + NUM, sr[key]["HoldText"])
            return float(j[1]) if j else 0.0
        world = {k: math.degrees(math.atan2(-r["Aim"][2], r["Aim"][1])) - waist(k) for k, r in sr.items()}
        hy = {k: r["Hilt"][1] for k, r in sr.items()}
        out.append((f"최종 검수 10/12: every staff within {WORLD_TILT} deg of upright in the world (the hunch included; never "
                    "across the body), the Light Mage's the most upright, his hand not lower than the others', the Dark Mage "
                    "hunched", all(0 <= w <= WORLD_TILT for w in world.values())
                    and world["Mage_Halo"] <= min(world.values()) and hy["Mage_Halo"] >= max(hy.values()) and waist("Mage_Horns") <= -6,
                    ", ".join(f"{k} {TORSO_ABOVE_FEET + hy[k]:.2f}/{world[k]:.0f} deg" for k in STAFF_ROWS)))
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
    rule, lens, lrule = staff_rule(src["CV"]), weapon_lengths(src["CONFIG"]), len_rule(src["CV"])
    out.append(("A23-142: the staffs use STAFF / staffLen (a share of the avatar's height) / staffOrb and the hand at Grip",
                rule is not None and lrule is not None and len(lens) >= 7, f"{len(lens)} tiers"))
    if rule:
        cv = src["CV"]
        orbs = [staff_orb(rule, tier, AVATAR_H * tier_len(lrule, "Staff", ln), AVATAR_H, 0, 1) for tier, ln in enumerate(lens, start=1)]
        out.append(("CharacterVisuals.avatarHeight: the avatar's own rig (HipHeight, root half, root -> UpperTorso -> neck rest "
                    "offsets, half the head) and buildWeapon passes it to all three staffs, which it marks StaffCarry",
                    "local torso = hum.HipHeight + root.Size.Y / 2 + (r0.Y - r1.Y) + (w0.Y - w1.Y)" in cv
                    and "return torso + (n0.Y - n1.Y) + head.Size.Y / 2" in cv
                    and 'local isStaff = kind == "Staff" or kind == "CrookStaff" or kind == "FlaskStaff"' in cv
                    and 'local staffHeight = (isStaff and type(avatarHeight) == "function") and avatarHeight(character) or nil' in cv
                    and "parts, main = shape(grip, sc, w, color, tier, staffHeight)" in cv
                    and "parts, main = buildStaff(grip, sc, w, color, tier, staffHeight)" in cv
                    and 'if isStaff then model:SetAttribute("StaffCarry", true) end' in cv
                    and "staffHandHeight" not in cv and "staffLow" not in cv, ""))
        out.append(("the staff orb stays hand sized (<= 0.9 studs)", all(d <= 0.9 for d in orbs), ", ".join(f"{d:.2f}" for d in orbs)))
    out += length_checks(src)
    fs, rn = flask_staff(src["CV"]), row(src["CONFIG"], "Mage_Neutral")
    cv = src["CV"]
    out.append(("최종 검수 10/12: the Alchemist holds the flask staff (SHAPES.FlaskStaff; the old hand flask is gone), its foot "
                "on the ground (buildWeapon passes the avatar's hand height)",
                bool(rn and rn["Weapon"] == "FlaskStaff") and "function SHAPES.Flask(" not in cv
                and 'local isStaff = kind == "Staff" or kind == "CrookStaff" or kind == "FlaskStaff"' in cv,
                f"{rn and rn['Weapon']}"))
    out.append(("최종 검수 10/12: the flask staff = a Shaft (the client's foot fix finds it) through staffLow, a leather Wrap "
                "round the hand (>= 0.5 long), the flask sitting in its cradle on top, the neck and the cork above, the flask "
                "the main part", bool(fs and fs["Shaft"] and fs["Wrap"] and fs["WrapLen"] >= 0.5 and fs["Top"] and fs["Flask"]
                                      and fs["CorkAt"] and fs["Main"]), f"{fs}"))
    out += dark_sword_checks(src["CV"], weapon_lengths(src["CONFIG"]))
    return out


def staff_gap_ok(wp: str) -> bool:
    """WeaponPose T.StaffGap: the foot's wanted clearance when it would touch the ground (0.05 .. 0.15)"""
    a = re.search(r"StaffGap = " + NUM + ",", wp)
    return bool(a) and 0.05 <= float(a[1]) <= 0.15


LIFT_HARNESS = r'''
local T = { StaffGap = GAP, StaffFix = FIX, StaffMax = MAX }
local WeaponPose = {}
-- FUNC --
local function run(foot0, ground, frames, lift0, carry)
	local lift = lift0 or 0
	for _ = 1, frames do lift = WeaponPose.StaffLift(lift, foot0 + lift, ground, T.StaffGap, carry) end
	return lift
end
local function report(name, ok, detail) print((ok and "CHECK_OK " or "CHECK_FAIL ") .. name .. " :: " .. tostring(detail)) end
local l = run(0.27, 0, 20)
report("10/12 photo: a tip 0.27 over the ground settles StaffGap over it", math.abs(0.27 + l - T.StaffGap) < 0.005, 0.27 + l)
l = run(-0.15, 0, 20)
report("a tip in the ground comes up to StaffGap", math.abs(-0.15 + l - T.StaffGap) < 0.005, -0.15 + l)
l = run(2, 0, 30)
report("never more than StaffMax down (a far foot: a jump, a step)", l >= -T.StaffMax - 1e-9 and l <= -T.StaffMax + 1e-6, l)
local d = 0.3
for _ = 1, 10 do d = WeaponPose.StaffLift(d, 1, nil, T.StaffGap) end
report("no ground under it: the lift goes back towards 0", math.abs(d) < 0.01, d)
-- A23-142: a carried staff (StaffCarry) hangs off the ground - never lowered onto it, only lifted out of it
l = run(1.0, 0, 30, 0, true)
report("A23-142: a carried staff 1.0 over the ground stays there (no lift down)", math.abs(l) < 1e-9, l)
l = run(-0.2, 0, 30, 0, true)
report("A23-142: a carried staff whose foot would go in (a step) is lifted to StaffGap", math.abs(-0.2 + l - T.StaffGap) < 0.005, -0.2 + l)
l = run(1.0, 0, 30, 0.3, true)
report("A23-142: the ground drops away again - the lift goes back to 0, never below", l >= 0 and l < 0.01, l)
'''


def staff_lift_checks(src: dict) -> list[tuple[str, bool, str]]:
    wp = src["WP"]
    fn = re.search(r"\nfunction WeaponPose\.StaffLift\(.*?\nend\n", wp, re.S)
    vals = {k: re.search(k + r" = " + NUM, wp) for k in ("StaffGap", "StaffFix", "StaffMax")}
    binary = ROOT / "build/luau_cli_0_741/luau.exe"
    if not binary.exists():
        binary = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
    if not fn or not all(vals.values()):
        return [("10/12: WeaponPose.StaffLift and T.StaffGap / StaffFix / StaffMax readable", False, "")]
    code = (LIFT_HARNESS.replace("-- FUNC --", fn.group(0)).replace("GAP", vals["StaffGap"][1])
            .replace("FIX", vals["StaffFix"][1]).replace("MAX", vals["StaffMax"][1]))
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "staff_lift.luau"
        f.write_text(code, encoding="utf-8")
        r = subprocess.run([str(binary), str(f)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = []
    for ln in r.stdout.splitlines():
        if ln.startswith("CHECK_"):
            ok = ln.startswith("CHECK_OK")
            name, _, detail = ln.split(" ", 1)[1].partition(" :: ")
            out.append((name, ok, detail))
    if len(out) != 7 or r.returncode != 0:
        out.append(("10/12: the StaffLift Luau run finished (7 checks)", False, (r.stderr or r.stdout)[-200:]))
    return out


def statics(src: dict) -> list[tuple[str, bool, str]]:
    wp = src["WP"]
    body = wp.split("function WeaponPose.OneHand(", 1)[-1].split("\nend\n", 1)[0]
    off = wp.split("function WeaponPose.OffHand(", 1)[-1].split("\nend\n", 1)[0]
    cv = src["CV"]
    gear = re.search(r"local GEAR = \{ Size = " + NUM + ", Gap = " + NUM + r" \}", cv)

    # 최종 검수 10/11 (the two warriors stood alike): the Paladin tall (Waist / Neck >= 0 = back / chin up, this table's
    # sign) and the Berserker leaning in and hunched (Waist <= -6, Neck < 0), his tip lower than the Paladin's
    def hold(key: str, joint: str):
        m = re.search(r"\n\t" + key + r" = \{(.*?)\n\t(?:--|\w+_\w+ = \{|\})", src["CONFIG"], re.S)  # the row (as row())
        body = m.group(1) if m else ""
        h = body.split("Hold = {", 1)[1].split("OneHand", 1)[0].split("OffHand", 1)[0] if "Hold = {" in body else ""
        j = re.search(joint + r" = \{ " + NUM, h)
        return float(j[1]) if j else 0.0
    halo, horns = row(src["CONFIG"], "Warrior_Halo"), row(src["CONFIG"], "Warrior_Horns")
    elev = [math.degrees(math.atan2(r["Aim"][1], -r["Aim"][2])) if r else 0.0 for r in (halo, horns)]
    stance = [
        ("최종 검수 10/11: the Paladin stands tall (Waist, Neck >= 0), the Berserker leans in and hunches (Waist <= -6, "
         "Neck < 0), his tip lower", hold("Warrior_Halo", "Waist") >= 0 and hold("Warrior_Halo", "Neck") >= 0
         and hold("Warrior_Horns", "Waist") <= -6 and hold("Warrior_Horns", "Neck") < 0 and elev[1] < elev[0] - 3,
         f"Halo {hold('Warrior_Halo', 'Waist')}/{hold('Warrior_Halo', 'Neck')} {elev[0]:.0f} deg, Horns "
         f"{hold('Warrior_Horns', 'Waist')}/{hold('Warrior_Horns', 'Neck')} {elev[1]:.0f} deg"),
        # 게임성 검수 10/11: +Waist = leaning BACK here, so every Horns row leans in or stays (<= 0) and every Halo row
        # stands tall or stays (>= 0) - the Dark Mage (+8) and the Shadow Hunter (+12) leaned back against their notes
        ("게임성 검수 10/11: the Horn Legion's rows lean in (Waist <= 0), the Knights' stand tall (Waist >= 0) - "
         "+Waist leans back in ClassGrips",
         all(hold(c + "_Horns", "Waist") <= 0 and hold(c + "_Halo", "Waist") >= 0 for c in ("Warrior", "Mage", "Archer")),
         ", ".join(f"{c} {hold(c + '_Halo', 'Waist'):g}/{hold(c + '_Horns', 'Waist'):g}" for c in ("Warrior", "Mage", "Archer"))),
    ]
    return stance + [
        ("검수 10/11: the Neutral gear sits small just over the head / hat (markFloor defined before it, half size or less)",
         gear is not None and float(gear[1]) <= 0.6 and float(gear[2]) <= 0.5
         and 0 < cv.find("local function markFloor(") < cv.find("local function buildNeutralGear(head, sc, character)")
         and "buildNeutralGear(head, sc, character), character, head)" in cv
         and "local floor = character and markFloor(character, head, k) or head.Size.Y / 2" in cv, ""),
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
         "local rGoal = WeaponPose.TwoHandGoals(torso + Vector3.new(0, lift, 0), oh," in body and body.count("for i = 1, 3 do") == 2
         and "T.TwoJoints[i]" in body and "Left" not in body.replace("T.LeftGrip", ""), ""),
        # 게임성 검수 10/12 (메인 반영 1 photo grips_low, the user's avatar: the staff tip 0.27 / 0.26 over the sole)
        ("10/12: a staff's hand goal follows its Shaft's foot onto the ground (StaffStep: the foot cast down, StaffLift "
         "applied to the goal, only the goal moves - the solve keeps the real torso)",
         "local lift = WeaponPose.StaffStep(st, model)" in body
         and "local pose = fx.SolveArm(right, torso, rGoal, torso:VectorToWorldSpace(pole))" in body
         and "local foot = (shaft.CFrame * CFrame.new(0, -shaft.Size.Y / 2, 0)).Position" in wp
         and "local hit = Ground.Cast(foot + Vector3.new(o[1] * r, 0, o[2] * r), 2, T.StaffReach)" in wp
         and staff_gap_ok(wp), ""),
        # 게임성 검수 10/13 (r1012b: a stair -0.12, a slope +0.51 against the sole)
        ("10/13: the staff reads the ground at its centre and a ring of its half width, the highest counts; GripProbe "
         "prints the tip against the ground under it (not the sole)",
         re.search(r"StaffRing = \{ \{ 0, 0 \}, \{ 1, 0 \}, \{ -1, 0 \}, \{ 0, 1 \}, \{ 0, -1 \} \}", wp) is not None
         and "for _, o in T.StaffRing do" in wp and "local r, ground = shaft.Size.X / 2, nil" in wp
         and "if hit and (ground == nil or hit.Position.Y > ground) then ground = hit.Position.Y end" in wp
         and 'st.StaffLift = WeaponPose.StaffLift(st.StaffLift, foot.Y, ground, T.StaffGap, model:GetAttribute("StaffCarry") == true)' in wp
         and "if carry == true then nextLift = math.max(nextLift, 0) end" in wp
         and '"Staff tip-ground=%s lift=%.2f tilt=%.0f"' in wp and "st.StaffFootY - st.StaffGroundY" in wp
         and "st.StaffTilt = math.deg(math.acos(math.clamp(shaft.CFrame.UpVector.Y, -1, 1)))" in wp, ""),
        ("OneHand fades in with the pose weight", "local out = base:Lerp(pose[w[2]], st.W)" in body, ""),
        ("A23-128: OneHand bends the elbow to the row's Pole (else T.PoleRight)",
         'local pole = typeof(oh.Pole) == "Vector3" and oh.Pole or T.PoleRight' in body
         and "local pose = fx.SolveArm(right, torso, rGoal, torso:VectorToWorldSpace(pole))" in body, ""),
        ("A23-128: no great sword shape left (CharacterVisuals), the dark one-hand sword exists",
         "SHAPES.GreatSword" not in cv and "function SHAPES.DarkSword(grip, sc, w, color)" in cv, ""),
    ]


def run(src: dict):
    res = geometry(src) + statics(src) + staff_lift_checks(src)
    lines = [("CHECK_OK " if ok else "CHECK_FAIL ") + name + (f" :: {d}" if d else "") for name, ok, d in res]
    return len(res), sum(0 if ok else 1 for _, ok, _ in res), lines


MUTATIONS = [
    ("CONFIG", "the Light Mage's staff leaning out", "Aim = Vector3.new(0.09, 1, -0.05), Pole", "Aim = Vector3.new(0.6, 1, -0.05), Pole"),
    # 최종 검수 10/13 (staff_front_v3f side photo)
    ("CV", "the crook's orb hangs back at the face again", "CFrame = top * CFrame.new(0, K.OrbY * sc, -K.OrbX * sc),",
     "CFrame = top * CFrame.new(K.OrbX * sc, K.OrbY * sc, 0),"),
    ("CONFIG", "the Alchemist's flask at the face again (the 10/12 spot)", "OneHand = { Hilt = Vector3.new(1.4, -0.55, -1.3)",
     "OneHand = { Hilt = Vector3.new(1.4, -0.55, -0.8)"),
    # 디자인 검수 10/12 (staff_short_v2 side photo)
    ("CONFIG", "the orb by the Light Mage's face again (the old spot)", "OneHand = { Hilt = Vector3.new(1.4, -0.5, -1.2), Aim = Vector3.new(0.09, 1, -0.05)",
     "OneHand = { Hilt = Vector3.new(1.4, -0.5, -0.8), Aim = Vector3.new(0.09, 1, -0.05)"),
    ("CONFIG", "the Alchemist's staff not splayed", "Aim = Vector3.new(0.09, 1, -0.1), Pole", "Aim = Vector3.new(0, 1, -0.1), Pole"),
    ("CONFIG", "the Dark Mage's staff splayed in", "Aim = Vector3.new(0.09, 1, 0), Pole", "Aim = Vector3.new(-0.09, 1, 0), Pole"),
    # A23-128 (user 10/11 "한손검만"): the warriors' one-hand swords at the side
    ("CONFIG", "the Paladin's sword across the body again", "Aim = Vector3.new(0.05, 0.7, -0.7)", "Aim = Vector3.new(-0.8, 0.55, -0.2)"),
    ("CONFIG", "the Paladin's sword held in front of the belly", "OneHand = { Hilt = Vector3.new(1.65, -0.85, -0.6)",
     "OneHand = { Hilt = Vector3.new(0.4, -0.6, -0.9)"),
    ("CONFIG", "the Paladin's left fist in front of the chest again",
     "Aim = Vector3.new(0.05, 0.7, -0.7), Pole = Vector3.new(0.6, -0.6, 0.8) } },",
     "Aim = Vector3.new(0.05, 0.7, -0.7), Pole = Vector3.new(0.6, -0.6, 0.8) },\n"
     "\t\tOffHand = { At = Vector3.new(-0.3, 0.0, -0.95), Up = Vector3.new(-0.95, -0.3, 0.65), Fwd = Vector3.new(0, 1, 0) } },"),
    ("CONFIG", "the Paladin's elbow flared out", "Aim = Vector3.new(0.05, 0.7, -0.7), Pole = Vector3.new(0.6, -0.6, 0.8) }",
     "Aim = Vector3.new(0.05, 0.7, -0.7), Pole = Vector3.new(1.5, -0.2, 0.3) }"),
    # 검수 10/11 (fix/onehand review)
    ("CONFIG", "the Paladin's hand back in the hip (the old spot)", "OneHand = { Hilt = Vector3.new(1.65, -0.85, -0.6)",
     "OneHand = { Hilt = Vector3.new(1.35, -0.8, -0.6)"),
    ("CONFIG", "the Paladin's elbow tucked into the side", "Aim = Vector3.new(0.05, 0.7, -0.7), Pole = Vector3.new(0.6, -0.6, 0.8) }",
     "Aim = Vector3.new(0.05, 0.7, -0.7), Pole = Vector3.new(-0.6, -0.6, 0.8) }"),
    ("CONFIG", "the Berserker's wrist bent hard (the old 35 deg tip, the hand high)",
     "OneHand = { Hilt = Vector3.new(1.65, -0.85, -0.65), Aim = Vector3.new(0.1, 0.6, -0.7)",
     "OneHand = { Hilt = Vector3.new(1.65, -0.6, -0.65), Aim = Vector3.new(0.1, 0.56, -0.82)"),
    ("CONFIG", "the Berserker's hand down at the thigh", "OneHand = { Hilt = Vector3.new(1.65, -0.85, -0.65)",
     "OneHand = { Hilt = Vector3.new(1.0, -1.3, -0.3)"),
    ("CONFIG", "the Berserker's great sword again", 'Warrior_Horns = { Weapon = "DarkSword",', 'Warrior_Horns = { Weapon = "GreatSword",'),
    ("CONFIG", "the Berserker's two-hand grip again", "Aim = Vector3.new(0.1, 0.6, -0.7), Pole = Vector3.new(0.6, -0.6, 0.8) } },",
     "Aim = Vector3.new(0.1, 0.6, -0.7), Pole = Vector3.new(0.6, -0.6, 0.8) },\n"
     "\t\tTwoHand = { Hilt = Vector3.new(0.25, 0.2, -0.7), Aim = Vector3.new(0.85, 0.85, 0.75), Gap = { 0.45, 0.9 } } },"),
    ("CONFIG", "the Berserker's tip pointing down", "Aim = Vector3.new(0.1, 0.6, -0.7)", "Aim = Vector3.new(0.1, -0.3, -0.9)"),
    ("CONFIG", "the Berserker's sword straight up", "Aim = Vector3.new(0.1, 0.6, -0.7)", "Aim = Vector3.new(0.1, 1, -0.2)"),
    # 검수 10/11: the dark sword = buildSword's size and place
    ("CV", "the dark sword's handle longer than the Paladin's", "local D = { Handle = 1.2,", "local D = { Handle = 1.8,"),
    ("CV", "the dark blade bigger", "Size = Vector3.new(0.25, bladeLen, 0.6) * sc,\n\t\tMaterial = w.Material, Color = color:Lerp(D.Dark, D.Shade),",
     "Size = Vector3.new(0.25, bladeLen * 1.4, 0.6) * sc,\n\t\tMaterial = w.Material, Color = color:Lerp(D.Dark, D.Shade),"),
    ("CV", "the dark blade set further out", "CFrame = L * CFrame.new(0, (D.Handle / 2 + 0.25 + bladeLen / 2) * sc, 0),",
     "CFrame = L * CFrame.new(0, (D.Handle / 2 + 0.9 + bladeLen / 2) * sc, 0),"),
    # A23-133 (user 10/11 "무기가 너무 길어서 잡는 위치가 이상해"): the held lengths against the avatar's height
    ("CV", "A23-133: the old long blades", "Blade = { 2.4, 3.1 }", "Blade = { 3, 6.5 }"),
    ("CV", "A23-133: the Paladin's blade off LEN (the Config length)", "local handleLen = 1.2\n\tlocal bladeLen = tierLen(w, LEN.Blade)",
     "local handleLen = 1.2\n\tlocal bladeLen = w.Length"),
    ("CV", "A23-133: the dark blade off LEN", "local bladeLen = tierLen(w, LEN.Blade) -- A23-133", "local bladeLen = w.Length -- A23-133"),
    ("CV", "A23-133: a stubby sword", "Blade = { 2.4, 3.1 }", "Blade = { 1.2, 1.6 }"),
    ("CV", "A23-142: the old tall staffs (0.85..1.0 of the height)", "Staff = { 0.65, 0.75 }", "Staff = { 0.85, 1.0 }"),
    ("CV", "A23-142: the top tier a hair over 0.75", "Staff = { 0.65, 0.75 }", "Staff = { 0.65, 0.78 }"),
    ("CV", "A23-133: the old long bows", "Bow = { 3.1, 4.9 }", "Bow = { 3, 6.5 }"),
    ("CV", "A23-133: the short bow as big as the bow", "return buildBow(grip, sc, w, color, 0.75, 15)", "return buildBow(grip, sc, w, color, 1, 15)"),
    ("CV", "A23-133: a long smithing hammer", "local handleLen = 1.9", "local handleLen = 3.4"),
    ("CV", "A23-133: the hammer held under its head", "local base, low = fist(grip), handleLen * 0.3", "local base, low = fist(grip), handleLen * 0.8"),
    ("CV", "A23-133: a long baton", "local shaftLen = 1.8", "local shaftLen = 3.4"),
    ("CV", "the dark guard twice as wide", "CFrame = L * CFrame.new(s * 0.27 * sc,", "CFrame = L * CFrame.new(s * 0.7 * sc,"),
    ("CV", "a big pommel", "Size = Vector3.new(0.36, 0.36, 0.36) * sc", "Size = Vector3.new(0.8, 0.8, 0.8) * sc"),
    ("CONFIG", "최종 검수 10/11: the Berserker stands like the Paladin again",
     "Hold = { Waist = { -10, 0, 0 }, Neck = { -6, 0, 0 } },", "Hold = { Waist = { 5, 0, 0 } },"),
    ("CONFIG", "the Berserker's left arm held up", 'Warrior_Horns = { Weapon = "DarkSword", Walk = 0.5, Hold = { Waist = { -10, 0, 0 }, Neck = { -6, 0, 0 } },',
     'Warrior_Horns = { Weapon = "DarkSword", Walk = 0.5, Hold = { Waist = { -10, 0, 0 }, Neck = { -6, 0, 0 }, LeftShoulder = { 40, 0, 0 } },'),
    ("WP", "the row's Pole ignored", 'local pole = typeof(oh.Pole) == "Vector3" and oh.Pole or T.PoleRight', "local pole = T.PoleRight"),
    # 게임성 검수 10/12 (the photo's floating staff tip)
    ("WP", "the staff foot never fixed", "local lift = WeaponPose.StaffStep(st, model)", "local lift = 0"),
    ("WP", "the lift pushes the wrong way", "local nextLift = lift - off * T.StaffFix", "local nextLift = lift + off * T.StaffFix"),
    ("WP", "no cap on the lift", "return math.clamp(nextLift, -T.StaffMax, T.StaffMax)", "return nextLift"),
    # A23-142: carried staffs
    ("WP", "a carried staff pulled down onto the ground", "if carry == true then nextLift = math.max(nextLift, 0) end",
     "if false then nextLift = math.max(nextLift, 0) end"),
    ("WP", "StaffStep never says the staff is carried", 'T.StaffGap, model:GetAttribute("StaffCarry") == true)', "T.StaffGap, false)"),
    ("CV", "the server never marks a staff carried", 'if isStaff then model:SetAttribute("StaffCarry", true) end',
     'if false then model:SetAttribute("StaffCarry", true) end'),
    ("WP", "a jump keeps the lift", "then return lift * (1 - T.StaffFix) end", "then return lift end"),
    ("WP", "the solve moves with the goal (the torso lifted too)", "local pose = fx.SolveArm(right, torso, rGoal,",
     "local pose = fx.SolveArm(right, torso + Vector3.new(0, lift, 0), rGoal,"),
    ("WP", "a foot height other than the server's", "StaffGap = 0.08,", "StaffGap = 0.3,"),
    # 게임성 검수 10/13
    ("WP", "the lowest ground of the ring (a tread's edge swallows the tip)",
     "if hit and (ground == nil or hit.Position.Y > ground) then ground = hit.Position.Y end",
     "if hit and (ground == nil or hit.Position.Y < ground) then ground = hit.Position.Y end"),
    ("WP", "the centre only again", "StaffRing = { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } },", "StaffRing = { { 0, 0 } },"),
    ("CV", "the dark sword never made", "function SHAPES.DarkSword(grip, sc, w, color)", "function SHAPES.DarkSword_(grip, sc, w, color)"),
    ("CONFIG", "a hand-on-hip sinks into the waist", "OffHand = { At = Vector3.new(-1.25, -0.65, 0.1), Up = Vector3.new(-0.75, 0.5, 0.4), Fwd = Vector3.new(0, 0, -1) } },\n\t-- Light Mage",
     "OffHand = { At = Vector3.new(-0.6, -0.65, 0.1), Up = Vector3.new(-0.75, 0.5, 0.4), Fwd = Vector3.new(0, 0, -1) } },\n\t-- Light Mage"),
    ("CONFIG", "the old left-arm hold kept (Tamer)", "RightWrist = { -30, 0, 0 } }, OffHand", "RightWrist = { -30, 0, 0 }, LeftShoulder = { 0, 0, -15 } }, OffHand"),
    ("CONFIG", "the staff across the chest", "OneHand = { Hilt = Vector3.new(1.4, -0.5, -1.2)", "OneHand = { Hilt = Vector3.new(0.2, -0.5, -1.2)"),
    ("CONFIG", "the Dark Mage's staff slanted far", "Aim = Vector3.new(0.09, 1, 0), Pole", "Aim = Vector3.new(0.09, 1, -0.8), Pole"),
    ("CONFIG", "10/12 photo: the Dark Mage's staff across the body again (11 deg + the hunch)", "Aim = Vector3.new(0.09, 1, 0), Pole",
     "Aim = Vector3.new(0.09, 1, -0.2), Pole"),
    # 최종 검수 10/12 (the staffs held lower, grip_reference §5-6)
    ("CONFIG", "the Light Mage's hand back up at the chest (the old spot)",
     "OneHand = { Hilt = Vector3.new(1.4, -0.5, -1.2), Aim = Vector3.new(0.09, 1, -0.05), Pole = Vector3.new(0.2, -0.1, 0.4) }",
     "OneHand = { Hilt = Vector3.new(1.0, -0.3, -0.6), Aim = Vector3.new(0, 1, -0.05) }"),
    ("CONFIG", "the Dark Mage's hand at the hip (the arm straight, the wrist broken)", "OneHand = { Hilt = Vector3.new(1.5, -0.5, -1.2)",
     "OneHand = { Hilt = Vector3.new(1.5, -1.1, -1.2)"),
    ("CONFIG", "the Light Mage's elbow out (the default bend: the wrist breaks)",
     "Aim = Vector3.new(0.09, 1, -0.05), Pole = Vector3.new(0.2, -0.1, 0.4) }", "Aim = Vector3.new(0, 1, -0.05) }"),
    ("CONFIG", "the Light Mage's hand tucked into the torso", "OneHand = { Hilt = Vector3.new(1.4, -0.5, -1.2)",
     "OneHand = { Hilt = Vector3.new(1.05, -0.5, -1.2)"),
    ("CONFIG", "the Dark Mage's free hand out at the side again", "Hold = { Waist = { -8, 0, 0 }, Neck = { -5, 0, 0 } },",
     "Hold = { Waist = { -8, 0, 0 }, Neck = { -5, 0, 0 }, LeftShoulder = { 14, 0, -20 } },"),
    # 게임성 검수 10/11: the Horns rows leaned back against their notes
    ("CONFIG", "the Dark Mage leans back again", "Hold = { Waist = { -8, 0, 0 }, Neck = { -5, 0, 0 } },",
     "Hold = { Waist = { 8, 0, 0 }, Neck = { -5, 0, 0 } },"),
    ("CONFIG", "the Shadow Hunter leans back again", "Hold = { Waist = { -12, 0, 0 }, Neck = { -8, 0, 0 },",
     "Hold = { Waist = { 12, 0, 0 }, Neck = { -8, 0, 0 },"),
    ("CV", "the big floating gear again", "local GEAR = { Size = 0.55, Gap = 0.35 }", "local GEAR = { Size = 1, Gap = 1.6 }"),
    ("CV", "the gear ignores the hat / hair", "buildNeutralGear(head, sc, character), character, head)", "buildNeutralGear(head, sc), character, head)"),
    ("CONFIG", "the Alchemist's elbow out (the default bend)", "Aim = Vector3.new(0.09, 1, -0.1), Pole = Vector3.new(0.2, -0.1, 0.4) },",
     "Aim = Vector3.new(0.09, 1, -0.1) },"),
    ("CONFIG", "the flask staff held out of reach", "OneHand = { Hilt = Vector3.new(1.4, -0.55, -1.3)", "OneHand = { Hilt = Vector3.new(1.4, -0.55, -2.2)"),
    ("CONFIG", "the Alchemist holds the old hand flask again", 'Mage_Neutral = { Weapon = "FlaskStaff",', 'Mage_Neutral = { Weapon = "Flask",'),
    ("CONFIG", "the old right-arm hold kept", 'Mage_Halo = { Weapon = "Staff", Walk = 0.7, Hold = { Neck',
     'Mage_Halo = { Weapon = "Staff", Walk = 0.7, Hold = { RightShoulder = { 8, 0, 8 }, Neck'),
    # 게임성 검수 10/11: the staff foot on every avatar
    ("CV", "A23-142: one fixed height for every avatar (tall avatars' staffs short, small ones' over 0.75)",
     'local h = (type(height) == "number" and height > 0) and height / sc or STAFF.Height', "local h = STAFF.Height"),
    ("CV", "A23-142: the hand at the orb again (grip 66%)", "local STAFF = { Grip = 0.43,", "local STAFF = { Grip = 0.66,"),
    ("CV", "A23-142: the orb never shrinks (a big tier's orb comes down to the hand)",
     "return math.max(0.3, math.min(STAFF.Orb + STAFF.OrbPerTier * tier, room / b))", "return STAFF.Orb + STAFF.OrbPerTier * tier"),
    ("CV", "A23-142: the crook's orb hangs low again", "local K = { Hook = 0.5, OrbX = 0.55, OrbY = 0.1, Bend = -60 }",
     "local K = { Hook = 0.5, OrbX = 0.55, OrbY = -0.6, Bend = -60 }"),
    ("CV", "A23-142: the head counted from the neck (the avatar's height too short)", "return torso + (n0.Y - n1.Y) + head.Size.Y / 2",
     "return torso + (n0.Y - n1.Y)"),
    ("CV", "buildWeapon never measures the avatar",
     'local staffHeight = (isStaff and type(avatarHeight) == "function") and avatarHeight(character) or nil', "local staffHeight = nil"),
    ("CV", "the old big orb", "Orb = 0.5, OrbPerTier = 0.05 }", "Orb = 0.7, OrbPerTier = 0.1 }"),
    ("CV", "the flask staff longer by a stick (too tall)",
     "local shaftLen = total - d * (F.Sit + 0.5) - (F.Neck + F.Cork)", "local shaftLen = total - d * (F.Sit + 0.5) + 0.6"),
    ("CV", "the flask staff's wrap off the hand", "Material = Enum.Material.Fabric, Color = F.Leather, CFrame = base,",
     "Material = Enum.Material.Fabric, Color = F.Leather, CFrame = base * CFrame.new(0, -1.2 * sc, 0),"),
    ("CV", "the flask staff never measured for this avatar (nor marked carried)",
     'local isStaff = kind == "Staff" or kind == "CrookStaff" or kind == "FlaskStaff"', 'local isStaff = kind == "Staff" or kind == "CrookStaff"'),
    ("CV", "the flask staff's shaft renamed (the client's foot fix loses it)",
     'table.insert(parts, accPart({\n\t\tName = "Shaft",', 'table.insert(parts, accPart({\n\t\tName = "Pole",'),
    ("CV", "the flask floating over its cradle", "CFrame = top * CFrame.new(0, d * F.Sit * sc, 0),", "CFrame = top * CFrame.new(0, (d + 0.8) * sc, 0),"),
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
