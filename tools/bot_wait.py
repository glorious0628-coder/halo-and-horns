"""Poll the test hunt bot (tools/fixtures/hunt_bot_client.luau) until it finishes; print its result JSON.

  py tools/bot_wait.py --mine [timeout_seconds, default 400]

GUARD (reviewer item 8, 2026-10-06): ONLY for the worker's own test Play. Never use it while the user is
playing: the bot moves the character and fires the attack/skill remotes. The explicit --mine flag is the
worker's statement that the running Play session is its own test Play; without it this tool refuses to run
and never contacts Studio.
Results are a "bot upper bound" only (a scripted, perfectly efficient hunter, not a human). Report them only
with that label, and never use them to change rewards, prices or XP.
"""
import json, os, re, sys, time

RESULT_KIND = ("bot upper bound (scripted hunter in the worker's own test Play; "
               "never use it to change rewards, prices or XP)")

args = sys.argv[1:]
if "--mine" not in args:
    sys.exit("refused: pass --mine to confirm this is YOUR OWN test Play (never while the user plays). "
             "Results are a bot upper bound only and never change rewards/prices.")
rest = [a for a in args if a != "--mine"]
if len(rest) > 1 or (rest and not re.fullmatch(r"\d+(\.\d+)?", rest[0])):
    sys.exit(__doc__)
timeout = float(rest[0]) if rest else 400.0

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio_mcp import Client  # imported only after the guard

LUA = 'local b=_G.HHC_BOT if not b then return "none" end if b.Running then return "running" end return game:GetService("HttpService"):JSONEncode(b.Result)'
c = Client()
try:
    c.start()
    t0 = time.time()
    while time.time() - t0 < timeout:
        r = "".join(p.get("text", "") for p in c.call("execute_luau", {"code": LUA, "datamodel_type": "Client"}).get("content", []))
        if r not in ("running", "none"):
            try:
                result = json.loads(r)
            except json.JSONDecodeError:
                print(r)
                break
            if isinstance(result, dict):
                result["ResultKind"] = RESULT_KIND
            print(json.dumps(result, ensure_ascii=False))
            break
        time.sleep(10)
    else:
        sys.exit(f"timed out after {timeout:.0f}s without a bot result")
finally:
    c.close()
