"""skeleton_ground_run.py (이미지 생성 1, 10/11): generate + run the walking-ground skeleton in WorldKit (Edit mode, no window needed).
usage: py tools/worldkit/skeleton_ground_run.py [--only roads,plaza,yards,stairs,rails,bridges] [--offset X,Z]
Needs Workspace.HaloV2 (tools/halo_blockout.py first). Prints one summary line."""
import json, os, subprocess, sys
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
out = os.path.join(ROOT, "build", "skeleton_ground.luau")
subprocess.run([sys.executable, "-X", "utf8", os.path.join(ROOT, "tools", "skeleton_ground.py"), "--out", out, *sys.argv[1:]], check=True)
jp = os.path.join(os.environ["TEMP"], "skeleton_ground.json")
json.dump({"code": open(out, encoding="utf-8").read(), "datamodel_type": "Edit"}, open(jp, "w", encoding="utf-8"), ensure_ascii=False)
r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "studio_mcp.py"), "call", "execute_luau", "@" + jp],
                   env=dict(os.environ, STUDIO_NAME="WorldKit"), capture_output=True, text=True, encoding="utf-8", cwd=ROOT)
print(r.stdout.strip()[-800:] or r.stderr.strip()[-800:])
