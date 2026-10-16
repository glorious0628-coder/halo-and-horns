"""Run the production CameraFollow input/lifecycle code with offline engine doubles, plus mutations.

A23-51 (user 2026-10-06): the camera turns with the right mouse drag only (Roblox's default camera, which CameraFollow
never touches); a left drag never turns it; a left press on the world = one attack on the press, never repeated.
A23-65 + A23-74 (user 2026-10-07): the follow turn behind me while walking (forward, diagonal and sideways in wide arcs;
never backing up) and the recenter behind my facing once I stop (never after a backpedal or my own hand turn).
Review A23-74 (user 2026-10-07): Roblox's keyboard / trackpad camera turn is a hand turn, every held stick angle walks a
circle of radius >= 50 studs, phones get Roblox's Classic touch camera (no second walking turn under its Follow camera)
and a long frame turns as if it were 1/20 s.
Does not inject physical mouse input, call Studio, or validate Roblox camera collision.
Status "passed" only when the fixture passes AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-06/offline_camera_input_a23_51_2026-10-06.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src/StarterPlayer/StarterPlayerScripts/CameraFollow.luau"
HUD = ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
FIXTURE = ROOT / "tools/fixtures/camera_input_offline.luau"
FOLLOW_FIXTURE = ROOT / "tools/fixtures/camera_follow_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-06/offline_camera_input_a23_51_2026-10-06.json"

BEGAN = "UserInputService.InputBegan:Connect(onPrimaryBegan)"
GUARD = "input.UserInputType ~= Enum.UserInputType.MouseButton1 or processed or blocked()"
# (name, old, new): each must change the source and make the fixture fail
MUTATIONS = [
    ("attack on the release instead of the press", BEGAN, "UserInputService.InputEnded:Connect(onPrimaryBegan)"),
    ("a press on a GUI attacks", GUARD, "input.UserInputType ~= Enum.UserInputType.MouseButton1 or blocked()"),
    ("open windows / loading no longer block", GUARD, "input.UserInputType ~= Enum.UserInputType.MouseButton1 or processed"),
    ("the right button attacks", GUARD, GUARD.replace("MouseButton1", "MouseButton2")),
    ("holding the left button repeats the attack", BEGAN, BEGAN + "\n\tUserInputService.InputChanged:Connect(function(i, p)"
     " if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then"
     " onPrimaryBegan({ UserInputType = Enum.UserInputType.MouseButton1 }, p) end end)"),
    ("a left drag turns the camera again", BEGAN, BEGAN + "\n\tUserInputService.InputChanged:Connect(function()"
     " if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then"
     " workspace.CurrentCamera.CFrame = \"turned\" end end)"),
    ("a render step drives the camera again", BEGAN, BEGAN + "\n\tgame:GetService(\"RunService\"):BindToRenderStep("
     "\"HHC_LeftMouseCamera\", Enum.RenderPriority.Camera.Value - 1, function() end)"),
    ("an open Panels window no longer blocks", '"FactionPicker", "ClassPicker", "Panels", "WorldMap"',
     '"FactionPicker", "ClassPicker", "WorldMap"'),
    ("the humanoid never becomes the subject", "camera.CameraSubject = humanoid", "camera.CameraSubject = camera.CameraSubject"),
    ("a scripted camera loses its subject",
     "\tif not camera or camera.CameraType ~= Enum.CameraType.Custom then return end\n", "\tif not camera then return end\n"),
]


# review 2026-10-06 (medium): the world click (PrimaryClick) must take the same face-the-nearest-monster path as the F key
# and the attack button (L.SwingFaced: L.FaceTarget("Swing"), then the Swing at once - since dev2 bd3d6bd the server
# aims at the nearest monster itself, so no wait for the turn to replicate). Static checks on HUD.luau + mutations.
def hud_checks(hud: str):
    hud = hud.replace("\r\n", "\n")
    m_fn = re.search(r"\nfunction L\.SwingFaced\(\)\n(.*?)\nend\n", hud, re.S)
    m_hold = re.search(r"\nlocal function startHold\(source\)\n(.*?)\nend\n", hud, re.S)
    return [
        ("L.SwingFaced faces my target, starts my body's swing (Fx.PredictSwing, 손맛 ① 10/16), then swings at once with it (no delay: the server aims itself, bd3d6bd)",
         m_fn is not None and [ln.strip() for ln in m_fn.group(1).strip().splitlines()][0] == 'local _, target = L.FaceTarget("Swing")'
         and [ln.strip() for ln in m_fn.group(1).strip().splitlines()][-1] == 'fire("Swing", target)'
         and "pcall(fx.PredictSwing)" in m_fn.group(1)
         and "task.delay" not in m_fn.group(1)),
        ("the F key / attack button (startHold) swing through L.SwingFaced",
         m_hold is not None and "L.SwingFaced()" in m_hold.group(1) and 'fire("Swing")' not in m_hold.group(1)),
        ("a world click (PrimaryClick) swings through L.SwingFaced too",
         "C.CameraFollow.PrimaryClick:Connect(function()\n\t\tif inputAllowed() then L.SwingFaced() end" in hud),
    ]


HUD_MUTATIONS = [
    ("a world click skips FaceTarget (fires Swing at once)", "if inputAllowed() then L.SwingFaced() end",
     'if inputAllowed() then fire("Swing") end'),
    ("SwingFaced never turns first", 'local _, target = L.FaceTarget("Swing")\n', 'local target = nil\n'),
    ("SwingFaced waits for the turn again", '\tfire("Swing", target)\nend',
     '\ttask.delay(0.08, function() fire("Swing", target) end)\nend'),
    ("my body waits for the server again", "pcall(fx.PredictSwing)", "pcall(print)"),
]


# A23-91 (user 2026-10-09 "콘솔 게임처럼"): the console-style follow (tools/fixtures/camera_follow_offline.luau); each must
# make it fail.
FOLLOW_MUTATIONS = [
    # 1 only while walking / a stop brakes
    ("1 the stop never brakes (it coasts on)", "\tlocal k = walking and FOLLOW.Response or FOLLOW.StopResponse\n",
     "\tlocal k = walking and FOLLOW.Response or 0.5\n"),
    ("1 a standing body still turns it (the old recenter)", "\tlocal walking = ml >= FOLLOW.MinMove\n", "\tlocal walking = true\n"),
    # 2 dead zone, spring, acceleration cap, no overshoot
    ("2 a 6 deg dead zone again", "DeadZone = math.rad(15),", "DeadZone = math.rad(6),"),
    ("2 no acceleration cap", "\tFOLLOW.Vel = math.clamp(want, FOLLOW.Vel - step, FOLLOW.Vel + step)\n", "\tFOLLOW.Vel = want\n"),
    ("2 a frame-rate-bound ease (share per frame)", "(1 - math.exp(-k * dt))", "math.min(1, k / 60)"),
    ("2 it may turn past the dead zone edge (overshoot)", "\tif dot >= FOLLOW.BackDot then limit = math.max(0, excess) end", "\tlocal _ = 0"),
    ("2 turns the wrong way", "local angle = math.atan2(cz * ux - cx * uz, dot)", "local angle = math.atan2(cx * uz - cz * ux, dot)"),
    # 3 backwards / sideways
    ("3 spins while walking toward the camera", "BackDot = -0.3,", "BackDot = -1.1,"),
    ("3 sideways as fast as forward", "SideMin = 0.35,", "SideMin = 1,"),
    # 4 hand turn
    ("4 no hold after a hand turn", "\tif now - FOLLOW.LastManual < FOLLOW.ManualHold then\n", "\tif false then\n"),
    ("4 after the hold it snaps back (the speed kept)", "\t\tFOLLOW.Vel = 0 -- a hand turn: my own view; afterwards it builds up again from 0\n", ""),
    ("4 a held arrow / Comma / Period is no hand turn", " or FOLLOW.KeyTurn() then", " then"),
    ("4 the right stick is no hand turn", "elseif input.KeyCode == Enum.KeyCode.Thumbstick2 and input.Position.Magnitude > 0.25 then",
     "elseif false then"),
    ("4 the move stick holds it", "if width > 0 and input.Position.X > width * FOLLOW.CameraSide then", "if true then"),
    # 5 combat
    ("5 full follow during a fight", "if now - FOLLOW.LastAttack < FOLLOW.CombatHold then share *= FOLLOW.CombatScale end", "-- (removed)"),
    ("5 other players' swings weaken my camera", "\t\tand data.UserId == LocalPlayer.UserId then\n", "\t\tthen\n"),
    # 7 / 8 caps and hitches
    ("7 no hitch clamp", "\tdt = math.clamp(dt, 0, FOLLOW.MaxDt)\n", ""),
    ("8 no top speed cap", "\t\t\tlocal cap = math.min(slow and FOLLOW.SlowMaxRate or FOLLOW.MaxRate,\n",
     "\t\t\tlocal cap = math.min(math.huge,\n"),
    ("8 'Screen shake' off ignored", 'local slow = setting("Shake", true) == false', "local slow = false"),
    ("8 Reduced Motion ignored", "or FOLLOW.Reduced()", "or false"),
    ("8 no radius cap (tight circles)", "(tonumber(speed) or 0) * math.min(1, ml) / FOLLOW.MinRadius)", "math.huge)"),
    # off
    ("Settings Free ignored", 'if setting("Cam", "Follow") == "Free" or blocked() or FOLLOW.RobloxFollows()',
     "if blocked() or FOLLOW.RobloxFollows()"),
    ("no setting yet = no follow (the default must be Follow)", 'if setting("Cam", "Follow") == "Free"', 'if setting("Cam", "Free") == "Free"'),
    ("windows no longer block", 'if setting("Cam", "Follow") == "Free" or blocked() or FOLLOW.RobloxFollows()',
     'if setting("Cam", "Follow") == "Free" or FOLLOW.RobloxFollows()'),
    ("adds to Roblox's own Follow camera (two turns)", 'or blocked() or FOLLOW.RobloxFollows()\n', "or blocked()\n"),
    ("follows in shift lock", "\t\tor UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then -- shift lock turns me itself\n",
     "\t\tor false then\n"),
    ("follows in first person", "if (focus - cf.Position).Magnitude < 1 then FOLLOW.Vel = 0 return end -- first person",
     "-- (first person check removed)"),
    # phones: Roblox's Classic touch camera
    ("phones keep Roblox's Follow camera (no Classic switch)",
     "then LocalPlayer.DevTouchCameraMode = modes.Classic end", "then local _ = modes.Classic end"),
    ("touch Default read as Classic (it is Follow on touch)",
     'if mode == "Default" then mode = if touch then "Follow" else "Classic" end', 'if mode == "Default" then mode = "Classic" end'),
]


def run_follow(source: str, name: str):
    harness = ROOT / f"build/camera_follow_offline{name}.luau"
    harness.write_text("local SOURCE = [====[" + source + "]====]\n" + FOLLOW_FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(harness)], cwd=ROOT, capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=60)
    match = re.search(r"CAMERA_FOLLOW_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fail = ""
    if not ok:
        lines = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.strip()]
        fail = lines[0][:240] if lines else "no output"
    return ok, (int(match[1]) if match else 0), fail, result


def run(source: str, name: str):
    harness = ROOT / f"build/camera_input_offline{name}.luau"
    harness.write_text("local SOURCE = [====[" + source + "]====]\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(harness)], cwd=ROOT, capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=60)
    match = re.search(r"CAMERA_INPUT_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fail = ""
    if not ok:
        lines = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.strip()]
        fail = lines[0][:240] if lines else "no output"
    return ok, (int(match[1]) if match else 0), fail, result


def main():
    source = SOURCE.read_text(encoding="utf-8-sig")
    compile_run = subprocess.run([str(BINARY.with_name("luau-compile.exe")), str(SOURCE)], cwd=ROOT,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, timeout=60)
    ok, checks, fail, result = run(source, "")
    print(result.stdout, end="")
    print(compile_run.stderr + result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = source.count(old) == 1
        caught = False
        why = ""
        if applied:
            m_ok, _, why, _ = run(source.replace(old, new), "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failure": why})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    f_ok, f_checks, f_fail, f_result = run_follow(source, "")
    print(f_result.stdout, end="")
    print(f_result.stderr, end="")
    for name, old, new in FOLLOW_MUTATIONS:
        applied = source.count(old) == 1
        caught = False
        why = ""
        if applied:
            m_ok, _, why, _ = run_follow(source.replace(old, new), "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "fixture": "camera_follow", "applied": applied, "caught": caught, "failure": why})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    hud = HUD.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    static = hud_checks(hud)
    # A23-91: Config.CameraFollow (the numbers the user's feedback changes) = FOLLOW's own names with the same values,
    # and Start copies it over FOLLOW
    cfg = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    m_cfg = re.search(r"\nConfig\.CameraFollow = \{\n(.*?)\n\}\n", cfg, re.S)
    m_fol = re.search(r"\nlocal FOLLOW = \{\n(.*?)\n\}\n", source.replace("\r\n", "\n"), re.S)
    pairs_cfg = dict(re.findall(r"(\w+) = ([^,\n]+),", m_cfg.group(1))) if m_cfg else {}
    pairs_fol = dict(re.findall(r"(\w+) = ([^,\n]+),", m_fol.group(1))) if m_fol else {}
    same = bool(pairs_cfg) and all(pairs_fol.get(k) == v for k, v in pairs_cfg.items())
    static.append(("A23-91: Config.CameraFollow = FOLLOW's names and values (" + ", ".join(sorted(pairs_cfg)) + ")", same))
    static.append(("A23-91: Start copies Config.CameraFollow over FOLLOW",
                   "if type(value) == \"number\" and type(FOLLOW[key]) == \"number\" then FOLLOW[key] = value end" in source))
    for name, good in static:
        print(("STATIC ok   " if good else "STATIC FAIL ") + name)
    for name, old, new in HUD_MUTATIONS:
        applied = hud.count(old) == 1
        caught = applied and not all(g for _, g in hud_checks(hud.replace(old, new)))
        rows.append({"mutation": name, "file": "HUD.luau", "applied": applied, "caught": caught, "failure": "static"})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    all_caught = all(r["applied"] and r["caught"] for r in rows)
    passed = compile_run.returncode == 0 and ok and f_ok and all_caught and all(g for _, g in static)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failed": 0 if ok else 1,
              "follow": {"checks": f_checks, "ok": f_ok, "failure": f_fail,
                         "fixtureSHA256": hashlib.sha256(FOLLOW_FIXTURE.read_bytes()).hexdigest()},
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              "hudSHA256": hashlib.sha256(HUD.read_bytes()).hexdigest(),
              "hudStatic": [{"check": n, "ok": g} for n, g in static],
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
              "studioCalls": 0, "physicalInputTested": False,
              "contract": "A23-51 (user 2026-10-06): the camera turns with the RIGHT mouse drag only, owned by Roblox's "
                          "default camera (CameraFollow's only render step is the A23-65 / A23-74 follow turn, which "
                          "never moves the camera while dragging and never takes over the right drag); a left drag never turns "
                          "the camera; a left press on the world fires "
                          "PrimaryClick once on the press (HUD -> one Swing), never on the release, never repeated while "
                          "held or dragged, never for a processed (GUI) press, an open picker / Panels / WorldMap / Roblox "
                          "menu, a focused text box, loading, a scripted camera or a missing character; touch is left to "
                          "Roblox; the camera subject follows the new humanoid after a costume swap / respawn and a "
                          "scripted camera keeps its own subject. A23-65 + A23-74 (user 2026-10-07): while walking in any "
                          "direction but a backpedal toward the camera (walk . look < -0.35) the camera turns toward the "
                          "walk (eased; the cap is 45 deg/s within 20 deg of the camera look, fading smoothly to 16 deg/s "
                          "by 60 deg, so camera-relative W+D / D / a 37-100 deg stick walk wide arcs, radius >= 55 studs "
                          "at WalkSpeed 20; 25 / 10 deg/s with 'Screen shake' off or Reduced Motion); 0.25 s after the walk "
                          "ends the camera eases round behind the HumanoidRootPart's facing (ease in, <= 120 deg/s, ease "
                          "out; D or W+D let go -> within 8 deg in 1.2 s, then within 1 deg, no overshoot; a 6 deg dead "
                          "zone keeps it still once behind; 60 deg/s with 'Screen shake' off or Reduced Motion); never "
                          "after a backpedal (no 180 deg spin), for a dead character, or after a hand turn within 1.5 s "
                          "before the stop or any time after it (kept until the next walk); the phone thumbstick drives "
                          "it, its touch never holds it; neither turn 1.5 s after a right drag / camera-side finger drag / "
                          "right stick, 0.5 s after my own Swing / Release / Skill Fx (the recenter resumes after it), in "
                          "shift lock, first person, a window / scripted camera, or with Settings Camera = Free. Review A23-74 "
                          "(user 2026-10-07): Roblox's own keyboard / trackpad camera turn (Left / Right arrows, Comma / "
                          "Period held or tapped, processed or not, outside a text box; a trackpad pan, not a wheel / "
                          "pinch zoom) is a hand turn too (a held Right arrow turned 14 deg and snapped back before); the "
                          "walking cap is never above speed / 55 studs (speed = Humanoid WalkSpeed x how far the stick is "
                          "pushed), so a stick held anywhere 0..110 deg off forward walks a circle of radius >= 50 studs "
                          "(55 at 20-35 deg; 38 before); Start sets LocalPlayer.DevTouchCameraMode = Classic when it is "
                          "UserChoice / Follow (the place's StarterPlayer DevTouchCameraMovementMode is UserChoice, so "
                          "phones got Roblox's Follow camera and its own walking turn: 10-stud circles at a 90 deg stick), "
                          "and while Roblox's Follow camera is still active (the set refused, a PC player who picked "
                          "Follow) WalkTurn stays off (the standing recenter still runs); a frame is clamped to 1/20 s "
                          "(a 0.5 s hitch turned the recenter 60 deg, now <= 6).",
              "limitations": "Engine input propagation, the default camera's right-drag orbit itself and real mouse/touch "
                             "need runtime validation (Studio own test Play). Roblox's camera is a double here: its "
                             "keyboard turn is simulated at 120 deg/s; whether the client-side DevTouchCameraMode set "
                             "switches the PlayerModule touch camera needs a phone-emulator Play."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
