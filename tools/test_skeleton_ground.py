"""Static test for tools/skeleton_ground.py (no Studio needed): runs the generator into a temp file and checks the Luau text.
usage: py tools/test_skeleton_ground.py"""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLAN = json.load(open(os.path.join(ROOT, "docs", "design", "halo_plan_v2_2026-10-11.json"), encoding="utf-8"))
GEN = os.path.join(ROOT, "tools", "skeleton_ground.py")
REQUIRED = ["WalkGround", "HaloV2", "Ground", "Roads", "Plaza", "Yards", "Stairs", "Rails", "IgnoreWater",
            "Bridges", "Raycast", "SubtractAsync", "HH_HaloGoldTrim", "HH_HaloMarbleBlock_Cream"]
FORBIDDEN = ["wait(", "spawn(", "<const>"]
bad = []


def gen(*extra):
    with tempfile.TemporaryDirectory() as td:
        out = os.path.join(td, "sub", "g.luau")
        r = subprocess.run([sys.executable, "-X", "utf8", GEN, "--out", out, *extra], capture_output=True, text=True, encoding="utf-8")
        if r.returncode != 0:
            bad.append("generator failed %s: %s" % (extra, (r.stderr or r.stdout)[-300:]))
            return ""
        return open(out, encoding="utf-8").read()


src = gen()
for w in REQUIRED:
    if w not in src:
        bad.append("missing word: " + w)
for w in FORBIDDEN:
    if w in src.replace("task.wait(", ""):
        bad.append("forbidden: " + w)
if "__" in src:
    i = src.index("__")
    bad.append("template placeholder left: " + src[max(0, i - 20):i + 30].replace("\n", " "))
roads = PLAN["roads"]
n = src.count("Road_")
if n < len(roads):
    bad.append("Road_ appears %d times, plan has %d roads" % (n, len(roads)))
for r in roads:
    if 'name="Road_%s"' % r["id"] not in src:
        bad.append("road not in script: " + r["id"])
for y in PLAN["yards"]:
    if 'id="%s"' % y["id"] not in src:
        bad.append("yard not in script: " + y["id"])
if "ALL = true" not in src:
    bad.append("default run should be a full run (ALL = true)")
part = gen("--only", "yards")
if "ALL = false" not in part or "yards = true" not in part or "roads = true" in part:
    bad.append("--only yards did not narrow the stages")
r = subprocess.run([sys.executable, "-X", "utf8", GEN, "--out", os.path.join(tempfile.gettempdir(), "sg_bad.luau"), "--only", "nope"],
                   capture_output=True, text=True, encoding="utf-8")
if r.returncode == 0:
    bad.append("unknown --only stage was accepted")
if bad:
    print("FAIL")
    for b in bad:
        print(" -", b)
    sys.exit(1)
print("OK: %d roads, %d bytes of Luau, Road_ x%d" % (len(roads), len(src), n))
