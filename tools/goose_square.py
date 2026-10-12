"""Goose Square space skeleton driver (이미지 개발 2026-10-12, SPEC A23-141; contract docs/design/goose_square_contract_2026-10-12.md).
  STUDIO_NAME=UiSandbox py tools/goose_square.py --mode apply|remove|survey [--center 6000,200,6000] [--emit build/goose_square_apply.luau]
apply  : builds workspace.GooseSquare in the chosen EDIT-mode practice Studio (re-run = rebuild)
remove : deletes it   survey: parts / WalkGround tag count
--emit : only writes the ready-to-run Luau (ALLOW_MAIN = true for 메인 반영 1 to run in the main place with its own tool; nothing is sent to a Studio).
Part names are listed in docs/design/goose_square_contract_2026-10-12.md section 3 (written by 이미지 개발).
"""
import argparse
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "worldkit", "goose_square.luau")


def make(mode, center, allow_main=False):
    s = open(SRC, encoding="utf-8").read()
    x, y, z = center
    s = s.replace("__MODE__", mode).replace("__CX__", repr(x)).replace("__CY__", repr(y)).replace("__CZ__", repr(z))
    if allow_main:
        s = s.replace("local ALLOW_MAIN = false", "local ALLOW_MAIN = true", 1)
    return s


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", default="survey", choices=["apply", "remove", "survey"])
    ap.add_argument("--center", default="6000,200,6000")
    ap.add_argument("--emit", default="", help="write the Luau for the main place (ALLOW_MAIN true) to this file and stop")
    a = ap.parse_args()
    c = tuple(float(v) for v in a.center.split(","))
    if a.emit:
        with open(a.emit, "w", encoding="utf-8", newline="\n") as f:
            f.write(make(a.mode, c, allow_main=True))
        print("wrote", a.emit)
        return
    if not os.environ.get("STUDIO_NAME") and not os.environ.get("STUDIO_ID"):
        raise SystemExit("set STUDIO_NAME=UiSandbox (practice Studio, Edit mode)")
    arg = os.path.join(os.environ.get("TEMP", "."), "goose_square_args.json")
    with open(arg, "w", encoding="utf-8") as f:
        json.dump({"code": make(a.mode, c), "datamodel_type": "Edit"}, f)
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "studio_mcp.py"), "call", "execute_luau", "@" + arg], capture_output=True, text=True, encoding="utf-8", errors="replace")
    print((r.stdout or "") + (r.stderr or ""))


if __name__ == "__main__":
    main()
