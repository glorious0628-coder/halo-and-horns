"""Client NaN guard audit (최종 검수 10/18, 게임 플레이 9판: the server's CFrame.lookAt of one point = NaN and the second
King's body flew off). Every CFrame.lookAt( and every .Unit in the client scripts must sit behind a distance check
(a Magnitude / length test in the same or the 8 lines before), or be listed in ALLOWED with why it can never get one
point (fixed scene positions, a vector that is never zero). A new unguarded one fails this test.
Also the facing turns that move MY character: HUD's L.AIM.TurnTo skips a target within 1 stud (flat), and every
lookAt that writes a character / camera frame is checked by name.
Mutations: removing a guard must be caught.
Usage: py tools/test_nan_guard.py
"""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
GUARD = re.compile(r"Magnitude|math\.sqrt|\bcl < |\bll < |\bdist < |\bd < 0|\bd > 0|< 1e-|> 1e-|< 0\.0|> 0\.0")
CALL = re.compile(r"CFrame\.lookAt\(|\.Unit\b")
WINDOW = 8
# (file, a piece of the line, why it is safe)
ALLOWED = [
    ("HUD.luau", "e.Unit", "a quest row field named Unit (the monster kind), no vector"),
    ("HUD.luau", "Unit = type(e.Unit)", "a quest row field named Unit"),
    ("HUD.luau", "state.Camera.CFrame = CFrame.lookAt(focus + root.CFrame.LookVector * distance, focus, up)",
     "the HUD portrait camera: distance > 0 from a unit LookVector"),
    ("HeroPreview.luau", "camera.CFrame = CFrame.lookAt(base * at, base * mid, base.UpVector)", "fixed preview offsets (at != mid)"),
    ("CodexUI.luau", "c.Camera.CFrame = CFrame.lookAt(c.Center + dir * dist, c.Center)", "dir is a unit vector, dist > 0 (Fit)"),
    ("Intro.luau", "CFrame.lookAt", "the opening's fixed scene positions (never one point)"),
    ("Intro.luau", ".Unit", "the opening's fixed scene positions"),
    ("ZoneLook.luau", "local dir = (s.B - s.A).Unit", "fixed map segments with two ends"),
    ("ZoneLook.luau", "p.CFrame = CFrame.lookAt(at, at + dir)", "dir is that segment's unit"),
    ("WeaponPose.luau", "v.Unit:Dot(dir)", "Studio-only grip probe (GripProbe), never in the game"),
    ("SkillFx.luau", "CFrame.fromMatrix(at + n * T.Lift, right, n, right:Cross(n).Unit)", "right and n are unit and at right angles"),
    ("SkillFx.luau", "p.CFrame = CFrame.lookAt(at + Vector3.new(0, T.Lift, 0), at + Vector3.new(0, T.Lift, 0) + dir)",
     "dir = c.Dir (a unit, set from a guarded dir)"),
    ("SkillFx.luau", "loop.CFrame = CFrame.lookAt(near + lift, near + lift + c.Dir)", "c.Dir is a unit"),
    ("SkillFx.luau", "tween(loop, 0.15, { CFrame = CFrame.lookAt(far + lift, far + lift + c.Dir) })", "c.Dir is a unit"),
    ("SkillFx.luau", "tween(loop, 0.2, { CFrame = CFrame.lookAt(back, back + c.Dir) })", "c.Dir is a unit"),
    ("SkillFx.luau", "local cf = CFrame.lookAt(mid, mid + c.Dir)", "c.Dir is a unit"),
    ("SkillFx.luau", "place(CFrame.lookAt(p, p + face), t)", "face is checked > 0.01 right above"),
    ("SkillFx.luau", "local c = { Data = data, From = from, Dir = dir.Unit,", "dir set to (0,0,-1) when < 0.01 above"),
    ("StoryNpcs.luau", "local home = CFrame.lookAt(feet, face)", "face moved 1 stud ahead when < 0.1 from feet above"),
    ("EventHUD.luau", "local inward = -dir.Unit * LABEL_INSET", "dir set to (0,1) when < 1e-3, 11 lines above"),
    ("Fx.luau", "tween(p, time, { CFrame = CFrame.lookAt(to, to + unit) }", "arrowBolt: returns when dir < 0.05 at its top"),
    ("Fx.luau", "local plane = CFrame.lookAt(chest, chest + look)", "look = my root's LookVector (a unit)"),
    ("Fx.luau", "local a, b = from.Unit, to.Unit", "Feel.turnBetween: the IK's own unit arm vectors (non-zero bones)"),
    ("Fx.luau", "if axis.Magnitude > 1e-5 then return CFrame.fromAxisAngle(axis.Unit", "guarded on the line"),
    ("Fx.luau", "return CFrame.fromAxisAngle(axis.Unit, math.pi)", "axis picked from a non-parallel basis right above"),
    ("Fx.luau", "local rotation = CFrame.lookAt(Vector3.zero, aim, up.Unit).Rotation", "aim a unit, up >= 0.05 checked above"),
    ("FirstSteps.luau", "cam.CFrame = CFrame.lookAt(pos, focus)", "TRAVEL.BehindSpot returns nil when dist < 0.5 (pos != focus)"),
    ("CameraFollow.luau", "camera.CFrame = CFrame.lookAt(pos, pos + yaw(look))", "look = the camera LookVector (unit), cl >= 0.05 checked"),
]

STATIC = [
    ("HUD: the facing turn skips a target within 1 stud (flat)", "HUD.luau",
     "if dir.Magnitude < 1 or look.Magnitude < 0.01 then return false end"),
    ("HUD: the turn is an atan2 yaw (no lookAt of my own root)", "HUD.luau",
     "root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, from + delta * k, 0)"),
    ("SkillFx.Arrow: a and b on one spot = a short arrow ahead", "SkillFx.luau",
     "\tif dir.Magnitude < 0.05 then\n\t\tdir = Vector3.new(0, 0, -1)\n\t\tb = a + dir * 0.05\n\tend"),
    ("SkillFx rope: one spot keeps the last frame", "SkillFx.luau", "\t\t\tif d < 0.05 then return end"),
    ("SkillFx arrow tip: never the Unit of a zero vector", "SkillFx.luau",
     "local way = (stop - start).Magnitude > 0.05 and (stop - start).Unit or c.Dir"),
]

MUTATIONS = [
    ("SkillFx.luau", "SkillFx.Arrow guard gone", "\tif dir.Magnitude < 0.05 then\n\t\tdir = Vector3.new(0, 0, -1)\n\t\tb = a + dir * 0.05\n\tend\n", ""),
    ("SkillFx.luau", "the rope guard gone", "\t\t\tif d < 0.05 then return end -- one spot", "\t\t\t-- one spot"),
    ("HUD.luau", "the facing turn guard gone", "if dir.Magnitude < 1 or look.Magnitude < 0.01 then return false end",
     "if look.Magnitude < 0.01 then return false end"),
    ("PetFollow.luau", "a new unguarded Unit", "\tif flat.Magnitude < 0.05 then flat = Vector3.new(0, 0, -1) end\n", ""),
]


def allowed(fname: str, line: str) -> bool:
    return any(f == fname and piece in line for f, piece, _ in ALLOWED)


def audit(files: dict[str, str]) -> list[str]:
    bad = []
    for fname, text in files.items():
        lines = text.split("\n")
        for i, line in enumerate(lines):
            code = line.split("--", 1)[0]
            if not CALL.search(code):
                continue
            if allowed(fname, line):
                continue
            ctx = "\n".join(lines[max(0, i - WINDOW):i + 1])
            if GUARD.search(ctx):
                continue
            bad.append(f"{fname}:{i + 1}: {line.strip()[:120]}")
    return bad


def checks(files: dict[str, str]) -> list[tuple[str, bool, str]]:
    out = []
    bad = audit(files)
    out.append(("every client CFrame.lookAt / .Unit is guarded or listed safe", not bad, "; ".join(bad[:6])))
    for name, fname, needle in STATIC:
        out.append((name, needle in files.get(fname, ""), ""))
    return out


def main() -> int:
    files = {p.name: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for p in SPS.glob("*.luau")}
    failed = 0
    for name, ok, detail in checks(files):
        print(("CHECK_OK " if ok else "CHECK_FAIL ") + name + ("" if ok or not detail else " :: " + detail))
        failed += 0 if ok else 1
    caught = 0
    for fname, name, old, new in MUTATIONS:
        src = files.get(fname, "")
        if src.count(old) != 1:
            print(f"MUTATION MISSED {name} (pattern matched {src.count(old)})")
            continue
        mutated = dict(files)
        mutated[fname] = src.replace(old, new)
        if any(not ok for _, ok, _ in checks(mutated)):
            caught += 1
            print(f"MUTATION caught  {name}")
        else:
            print(f"MUTATION MISSED {name}")
    ok = failed == 0 and caught == len(MUTATIONS)
    print(f"Status: {'passed' if ok else 'failed'} (checks {len(checks(files))}, failed {failed}, mutations {caught}/{len(MUTATIONS)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
