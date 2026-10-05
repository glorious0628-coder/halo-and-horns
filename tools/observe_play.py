"""Watch the user's Studio Play session from the server side only (no input), logging first-10-minute milestones.

  py tools/observe_play.py <out.jsonl> [seconds=900] [interval=3]
Writes one JSON line per change of the tracked player attributes.
"""
import json, sys, time, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio_mcp import Client

LUA = r'''
local P = game:GetService("Players")
local out = {}
for _, p in P:GetPlayers() do
  local a = {}
  for _, k in ipairs({"Faction","Class","ClassChosen","TutorialStep","TutorialKills","ZoneId","Level","XP","BankGold","CarriedGold",
    "WeaponTier","WeaponOwnedMask","BlacksmithVisited","TotalKills","DailyClaims","Mana"}) do a[k] = p:GetAttribute(k) end
  local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
  a.HP = h and math.floor(h.Health) or nil
  out[p.Name] = a
end
return game:GetService("HttpService"):JSONEncode({t = workspace.DistributedGameTime, players = out})
'''

def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))

def main():
    path = sys.argv[1]
    total = float(sys.argv[2]) if len(sys.argv) > 2 else 900
    step = float(sys.argv[3]) if len(sys.argv) > 3 else 3
    c = Client(); c.start()
    last = None; t0 = time.time()
    with open(path, "a", encoding="utf-8") as f:
        while time.time() - t0 < total:
            try:
                raw = text_of(c.call("execute_luau", {"code": LUA, "datamodel_type": "Server"}))
                d = json.loads(raw[raw.index("{"):raw.rindex("}") + 1])
                key = json.dumps({k: {kk: vv for kk, vv in v.items() if kk not in ("Mana", "HP", "XP")} for k, v in d["players"].items()}, sort_keys=True)
                if key != last:
                    last = key
                    d["wall"] = round(time.time() - t0, 1)
                    f.write(json.dumps(d, ensure_ascii=False) + "\n"); f.flush()
            except Exception as e:
                pass  # not playing yet / between sessions
            time.sleep(step)

if __name__ == "__main__":
    main()
