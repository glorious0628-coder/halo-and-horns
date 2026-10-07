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
        ("L.SwingFaced faces the nearest monster, then swings at once (no delay: the server aims itself, bd3d6bd)",
         m_fn is not None and [ln.strip() for ln in m_fn.group(1).strip().splitlines()][-2:] == ['L.FaceTarget("Swing")', 'fire("Swing")']
         and "task.delay" not in m_fn.group(1)),
        ("the F key / attack button (startHold) swing through L.SwingFaced",
         m_hold is not None and "L.SwingFaced()" in m_hold.group(1) and 'fire("Swing")' not in m_hold.group(1)),
        ("a world click (PrimaryClick) swings through L.SwingFaced too",
         "C.CameraFollow.PrimaryClick:Connect(function()\n\t\tif inputAllowed() then L.SwingFaced() end" in hud),
    ]


HUD_MUTATIONS = [
    ("a world click skips FaceTarget (fires Swing at once)", "if inputAllowed() then L.SwingFaced() end",
     'if inputAllowed() then fire("Swing") end'),
    ("SwingFaced never turns first", 'L.FaceTarget("Swing")\n\tfire("Swing")', 'fire("Swing")'),
    ("SwingFaced waits for the turn again", 'L.FaceTarget("Swing")\n\tfire("Swing")',
     'L.FaceTarget("Swing")\n\ttask.delay(0.08, function() fire("Swing") end)'),
]


# A23-65 + A23-74 (user 2026-10-07): the follow turn and the recenter (tools/fixtures/camera_follow_offline.luau); each
# must make it fail. (a) D then stop -> behind me in 1.2 s, (b) W+D then stop, (c) no recenter in the holds / Free /
# blocked, (d) W+D arc radius, (e) backing up never turns. Review A23-74 (user 2026-10-07): (1) Roblox's keyboard /
# trackpad camera turn is a hand turn, (2) radius >= 50 studs for a stick held 0..110 deg off, (3) phones on Classic,
# no second walking turn under Roblox's Follow camera, (4) a 0.5 s hitch turns as if 1/20 s.
STOP_BOOK = ("\tif walking then\n\t\tFOLLOW.StopAt = math.huge\n\telseif FOLLOW.StopAt == math.huge then\n"
             "\t\tFOLLOW.StopAt = now\n\tend\n")
FREE_LINE = '\tif setting("Cam", "Follow") == "Free" or blocked() then return end\n'
HOLD_LINE = ("\tif now - FOLLOW.LastManual < FOLLOW.ManualHold or now - FOLLOW.LastAttack < FOLLOW.AttackHold then return end\n")
FOLLOW_MUTATIONS = [
    # walking
    ("(e) spins while backing up", "BackDot = -0.35,", "BackDot = -1.1,"),
    ("sidesteps never turn again (the old A23-65 forward-only rule)", "BackDot = -0.35,", "BackDot = 0.5,"),
    ("(d) a held side key circles tightly (side cap = forward cap)", "SideRate = math.rad(16),", "SideRate = math.rad(45),"),
    ("(d) a linear fade (W+D circles at ~43 studs)", "(1 - t) ^ FOLLOW.Fade * (1 + FOLLOW.Fade * t)", "(1 - t)"),
    ("(d) the old dot-based cap (full 45 deg/s up to 60 deg: 25-stud circles)",
     "local t = math.clamp((off - FOLLOW.FullAngle) / (FOLLOW.SideAngle - FOLLOW.FullAngle), 0, 1)",
     "local t = math.clamp((off - FOLLOW.SideAngle) / math.rad(30), 0, 1)"),
    ("a hard switch instead of a smooth fade", "(1 - t) ^ FOLLOW.Fade * (1 + FOLLOW.Fade * t)", "(t < 0.4 and 1 or 0)"),
    ("forward walks lose the full cap", "return side + (full - side) * (1 - t)", "return side + 0 * (1 - t)"),
    ("'Screen shake' off ignored sideways", "slow and FOLLOW.SlowSideRate or FOLLOW.SideRate", "FOLLOW.SideRate"),
    ("Reduced Motion ignored", "or FOLLOW.Reduced()", "or false"),
    ("no hold after a hand turn", "if now - FOLLOW.LastManual < FOLLOW.ManualHold or now - FOLLOW.LastAttack",
     "if now - FOLLOW.LastAttack"),
    ("(c) no hold after my swing (walk and recenter)", " or now - FOLLOW.LastAttack < FOLLOW.AttackHold then return end",
     " then return end"),
    ("no turn-speed cap while walking", "return math.clamp(angle * math.min(1, ease * dt), -rate * dt, rate * dt)",
     "return angle * math.min(1, ease * dt)"),
    ("(c) Settings Free ignored (walk and recenter)", 'if setting("Cam", "Follow") == "Free" or blocked() then return end',
     "if blocked() then return end"),
    ("(c) windows / scripted camera no longer block", 'if setting("Cam", "Follow") == "Free" or blocked() then return end',
     'if setting("Cam", "Follow") == "Free" then return end'),
    ("'Screen shake' off ignored", 'local slow = setting("Shake", true) == false', "local slow = false"),
    ("other players' swings hold my camera", "\t\tand data.UserId == LocalPlayer.UserId then\n", "\t\tthen\n"),
    ("the move stick holds it", "if width > 0 and input.Position.X > width * FOLLOW.CameraSide then", "if true then"),
    ("turns the wrong way", "local angle = math.atan2(cz * mx - cx * mz, dot)", "local angle = math.atan2(cx * mz - cz * mx, dot)"),
    ("follows in shift lock", "if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then return end -- shift lock turns me itself",
     "-- (shift lock check removed)"),
    # A23-74 standing recenter
    ("(a)(b) no recenter on the stop (f3ab1f1: a side view forever)",
     "\t\ta = FOLLOW.CenterTurn(cx, cz, humanoid, now, dt, slow, was)\n", "\t\ta = nil\n"),
    ("(a) the recenter turns the wrong way", "local angle = math.atan2(cz * fx - cx * fz, dot)",
     "local angle = math.atan2(cx * fz - cz * fx, dot)"),
    ("(a) the recenter too slow (30 deg/s)", "CenterRate = math.rad(120),", "CenterRate = math.rad(30),"),
    ("(a) the recenter snaps round (no speed cap)", "-FOLLOW.CenterSpeed * dt, FOLLOW.CenterSpeed * dt)", "-math.huge, math.huge)"),
    ("(a) no ease in (top speed at once)", "(was and FOLLOW.CenterSpeed or 0) +", "math.huge +"),
    ("(a) no wait after the stop (recenters while switching keys)", "if now - FOLLOW.StopAt < FOLLOW.StopDelay\n\t\tor ",
     "if "),
    ("(a) never settles (stops at the dead zone edge)", "(was and FOLLOW.Settle or FOLLOW.DeadZone)", "FOLLOW.DeadZone"),
    ("the dead zone ignored (nudges after every small body turn)", "(was and FOLLOW.Settle or FOLLOW.DeadZone)", "FOLLOW.Settle"),
    ("(b) the recenter starts only past 50 deg (W+D stays a side view)", "(was and FOLLOW.Settle or FOLLOW.DeadZone)",
     "(was and FOLLOW.Settle or math.rad(50))"),
    ("(c) a hand turn no longer keeps my view after the stop", "\n\t\tor FOLLOW.LastManual >= FOLLOW.StopAt - FOLLOW.ManualHold then",
     " then"),
    ("a hand turn blocks the recenter for good (no new walk re-arms it)", "FOLLOW.LastManual >= FOLLOW.StopAt - FOLLOW.ManualHold",
     "FOLLOW.LastManual > -math.huge"),
    ("(e) the recenter spins 180 deg after backing up",
     "if dot < FOLLOW.BackDot then return nil end -- I face the camera (a backpedal ended): no 180 deg spin", "-- (removed)"),
    ("the recenter ignores 'Screen shake' off", "math.min(slow and FOLLOW.SlowCenterRate or FOLLOW.CenterRate,",
     "math.min(FOLLOW.CenterRate,"),
    ("the recenter runs for a dead character", "if not root or humanoid.Health <= 0 then return nil end",
     "if not root then return nil end"),
    ("(c) the stop is only counted after the hand-turn hold (a right drag before the stop is forgotten)",
     STOP_BOOK + FREE_LINE + HOLD_LINE, FREE_LINE + HOLD_LINE + STOP_BOOK),
    # review A23-74 (user 2026-10-07): (1) Roblox's keyboard / trackpad turn = a hand turn
    ("(1) a held arrow / Comma / Period is no hand turn (the recenter pulls Roblox's keyboard turn back)",
     " or FOLLOW.KeyTurn() then", " then"),
    ("(1) the Right arrow forgotten", "Enum.KeyCode.Left, Enum.KeyCode.Right, ", "Enum.KeyCode.Left, "),
    ("(1) a Comma / Period tap between two frames is missed",
     "if table.find(FOLLOW.TurnKeys, input.KeyCode) and not UserInputService:GetFocusedTextBox() then", "if false then"),
    ("(1) a processed Comma / Period tap is ignored (Roblox's camera binds those keys itself)",
     "if table.find(FOLLOW.TurnKeys, input.KeyCode) and not UserInputService",
     "if table.find(FOLLOW.TurnKeys, input.KeyCode) and not processed and not UserInputService"),
    ("(1) any key press counts as a hand turn", "if table.find(FOLLOW.TurnKeys, input.KeyCode) and not",
     "if input.KeyCode and not"),
    ("(1) a comma held while typing in a text box counts",
     "if UserInputService:GetFocusedTextBox() then return false end -- typing a comma in chat turns nothing", "-- (removed)"),
    ("(1) a period pressed while typing in a text box counts",
     "and not UserInputService:GetFocusedTextBox() then\n\t\t\tFOLLOW.LastManual", "then\n\t\t\tFOLLOW.LastManual"),
    ("(1) a trackpad pan is no hand turn",
     "pcall(function() UserInputService.PointerAction:Connect(FOLLOW.OnPointerAction) end)", "local _ = nil"),
    ("(1) a wheel / pinch zoom counts as a hand turn", "if pan and pan.Magnitude > 1e-3 then", "if pan then"),
    # (2) the arc radius >= ~50 studs at every held angle
    ("(2) no radius cap (a stick 25 deg off circles at 38 studs)",
     ", (tonumber(speed) or 0) * math.min(1, ml) / FOLLOW.MinRadius)", ", math.huge)"),
    ("(2) the radius cap at 35 studs", "MinRadius = 55,", "MinRadius = 35,"),
    ("(2) a half-pushed stick gets the full-speed cap (27-stud circles)", "* math.min(1, ml) /", "* 1 /"),
    ("(2) the radius cap reads a fixed 20 studs/s (a slower walk circles tighter)",
     "FOLLOW.WalkTurn(cx, cz, move, dt, slow, humanoid.WalkSpeed)", "FOLLOW.WalkTurn(cx, cz, move, dt, slow, 20)"),
    # (3) phones: Roblox's Classic touch camera; no second walking turn under Roblox's Follow camera
    ("(3) phones keep Roblox's Follow camera (no Classic switch)",
     "then LocalPlayer.DevTouchCameraMode = modes.Classic end", "then local _ = modes.Classic end"),
    ("(3) Start never switches the touch camera", "\tFOLLOW.TouchClassic() -- phones", "\t-- (removed) -- phones"),
    ("(3) WalkTurn adds to Roblox's Follow camera (two turns)", "elseif not FOLLOW.RobloxFollows() then", "elseif true then"),
    ("(3) touch Default read as Classic (it is Follow on touch)",
     'if mode == "Default" then mode = if touch then "Follow" else "Classic" end', 'if mode == "Default" then mode = "Classic" end'),
    ("(3) a PC reads the touch mode (a PC player's Follow choice ignored)",
     "(if touch then LocalPlayer.DevTouchCameraMode else LocalPlayer.DevComputerCameraMode)", "(LocalPlayer.DevTouchCameraMode)"),
    ("(3) an explicit touch mode (Orbital) is overridden too",
     "if mode == modes.UserChoice or mode == modes.Follow then", "if true then"),
    # (4) a hitch never jumps the camera
    ("(4) no frame clamp (a 0.5 s hitch jumps the recenter 60 deg)",
     "\tdt = math.min(dt, FOLLOW.MaxDt) -- A23-74 review: a hitch never jumps the camera\n", ""),
    ("(4) the clamp at 1/2 s", "MaxDt = 1 / 20,", "MaxDt = 1 / 2,"),
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
