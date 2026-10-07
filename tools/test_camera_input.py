"""Run the production CameraFollow input/lifecycle code with offline engine doubles, plus mutations.

A23-51 (user 2026-10-06): the camera turns with the right mouse drag only (Roblox's default camera, which CameraFollow
never touches); a left drag never turns it; a left press on the world = one attack on the press, never repeated.
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
    passed = compile_run.returncode == 0 and ok and all_caught and all(g for _, g in static)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failed": 0 if ok else 1,
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              "hudSHA256": hashlib.sha256(HUD.read_bytes()).hexdigest(),
              "hudStatic": [{"check": n, "ok": g} for n, g in static],
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
              "studioCalls": 0, "physicalInputTested": False,
              "contract": "A23-51 (user 2026-10-06): the camera turns with the RIGHT mouse drag only, owned by Roblox's "
                          "default camera (CameraFollow binds no render step, never writes Camera.CFrame and ignores "
                          "MouseButton2); a left drag never turns the camera; a left press on the world fires "
                          "PrimaryClick once on the press (HUD -> one Swing), never on the release, never repeated while "
                          "held or dragged, never for a processed (GUI) press, an open picker / Panels / WorldMap / Roblox "
                          "menu, a focused text box, loading, a scripted camera or a missing character; touch is left to "
                          "Roblox; the camera subject follows the new humanoid after a costume swap / respawn and a "
                          "scripted camera keeps its own subject.",
              "limitations": "Engine input propagation, the default camera's right-drag orbit itself and real mouse/touch "
                             "need runtime validation (Studio own test Play)."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
