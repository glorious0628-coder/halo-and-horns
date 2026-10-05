"""Run the production CameraFollow input/lifecycle code with offline engine doubles.

Does not inject physical mouse input, call Studio, or validate Roblox camera collision.
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src/StarterPlayer/StarterPlayerScripts/CameraFollow.luau"
FIXTURE = ROOT / "tools/fixtures/camera_input_offline.luau"


def main():
    source = SOURCE.read_text(encoding="utf-8-sig")
    harness = ROOT / "build/camera_input_offline.luau"
    harness.write_text("local SOURCE = [====[" + source + "]====]\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    binary = ROOT / "build/luau_cli_0_741/luau.exe"
    compile_run = subprocess.run([str(binary.with_name("luau-compile.exe")), str(SOURCE)], cwd=ROOT,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, timeout=60)
    result = subprocess.run([str(binary), str(harness)], cwd=ROOT, capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=60)
    print(result.stdout, end="")
    print(compile_run.stderr + result.stderr, end="")
    match = re.search(r"CAMERA_INPUT_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    report = {"status": "passed" if compile_run.returncode == result.returncode == 0 and match else "failed",
              "checks": int(match[1]) if match else 0, "failed": int(match[2]) if match else 1,
              "sourceSHA256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
              "studioCalls": 0, "physicalInputTested": False,
              "contract": "A23: left-drag measured from input.Position differences (Vector2), Delta ignored; "
                          "skipped while MouseBehavior ~= Default; short click fires once; drag never attacks.",
              "limitations": "Engine input propagation, default-camera follow/zoom/occlusion and real mouse/touch need runtime validation."}
    path = ROOT / "docs/art/verification_2026-10-06/offline_camera_input_2026-10-06.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
