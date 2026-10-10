"""Run a tools/worldkit/*.luau Edit-mode tool in a Studio window, replacing "__MODE__" (no screen control).

  py tools/run_worldkit_tool.py <tool.luau> <MODE> [--studio WorldKit]      (default window name: GoodEvil, like studio_mcp.py)

Writes build/_run_<tool>.json and calls execute_luau through tools/studio_mcp.py; prints the tool's return string.
Add `--zone <name>` for zone_swap.luau. Use `--studio WorldKit` for the practice place; the main place is run by 메인 반영 only.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
tool, mode = sys.argv[1], sys.argv[2]
env = dict(os.environ)
if "--studio" in sys.argv:
    env["STUDIO_NAME"] = sys.argv[sys.argv.index("--studio") + 1]
code = Path(ROOT / tool).read_text(encoding="utf-8").replace("__MODE__", mode)
if env.get("STUDIO_NAME") and "GoodEvil" not in env["STUDIO_NAME"] and "81671223175574" not in env["STUDIO_NAME"]:
    # practice Studio only: refuse to run if the connection landed in the main place (2026-10-10 safety rule from 검수)
    code = 'if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end\n' + code
if "--zone" in sys.argv:  # zone_swap.luau: halo | horns | ruins | pumpkin | hollow
    code = code.replace("__ZONE__", sys.argv[sys.argv.index("--zone") + 1])
out = ROOT / "build" / f"_run_{Path(tool).stem}.json"
out.write_text(json.dumps({"code": code, "datamodel_type": "Edit"}, ensure_ascii=False), encoding="utf-8")
r = subprocess.run([sys.executable, str(ROOT / "tools/studio_mcp.py"), "call", "execute_luau", f"@{out}"],
                   capture_output=True, text=True, encoding="utf-8", env=env, cwd=ROOT)
print((r.stdout or "") + (r.stderr or ""))
