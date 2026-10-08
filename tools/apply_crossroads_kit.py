"""Place the crossroads 3D prop kit in the open main Studio (Edit mode).

  py tools/apply_crossroads_kit.py     # (STUDIO_ID=<id> when two windows of the place are open)

1. inserts every K_* (crossroads) and GF_* (HauntedHollow) model of art/models/worldkit/manifest.json that
   ServerStorage.KitStage lacks (the user's own
   Model assets, Studio MCP insert_asset);
2. runs tools/worldkit/crossroads_kit_main.luau (idempotent: rebuilds Map.Decor.CrossroadsKit, keeps the contracts).
Also run by tools/apply_studio_state.py, so reopening the cloud place restores it.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio_mcp import Client  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "art", "models", "worldkit", "manifest.json")
PLACE_LUA = os.path.join(ROOT, "tools", "worldkit", "crossroads_kit_main.luau")
SWAP_LUA = os.path.join(ROOT, "tools", "worldkit", "crossroads_3d_swap.luau")

HAVE = """local SS=game:GetService("ServerStorage")
local k=SS:FindFirstChild("KitStage") or Instance.new("Folder")
k.Name="KitStage" k.Parent=SS
local t={} for _,c in k:GetChildren() do t[c.Name]=true end
return game:GetService("HttpService"):JSONEncode(t)"""

# insert_asset puts the asset in a Model named after assetName: unwrap it to K_* (the kit model itself)
UNWRAP = """local k=game:GetService("ServerStorage").KitStage
local h=k:FindFirstChild(%s)
if not h then return "missing holder" end
local inner=h:FindFirstChildWhichIsA("Model")
if inner and #h:GetChildren()==1 then inner.Name=%s inner.Parent=k h:Destroy() else h.Name=%s end
local m=k:FindFirstChild(%s)
for _,d in m:GetDescendants() do if d:IsA("LuaSourceContainer") then d:Destroy() end end
return "ok" """


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def run(c):
    state = text_of(c.call("get_studio_state", {}))
    if "Current Studio Mode: Edit" not in state:
        sys.exit("Studio must be in Edit mode: " + state[:120])
    with open(MANIFEST, encoding="utf-8") as f:
        manifest = json.load(f)
    kit = dict(manifest["kit"])
    # A23-45: the HauntedHollow props too (MapBuilder clones GF_* from ServerStorage.KitStage at runtime)
    kit.update((manifest.get("ghost_forest") or {}).get("kit") or {})
    have = json.loads(text_of(c.call("execute_luau", {"code": HAVE, "datamodel_type": "Edit"})) or "{}")
    if isinstance(have, list):
        have = {}
    for name, entry in kit.items():
        if name in have:
            continue
        holder = "H_" + name
        r = c.call("insert_asset", {"assetId": str(entry["assetId"]), "assetName": holder, "assetType": "Model",
                                    "parentPath": "game.ServerStorage.KitStage"})
        q = json.dumps
        u = text_of(c.call("execute_luau", {"code": UNWRAP % (q(holder), q(name), q(name), q(name)),
                                             "datamodel_type": "Edit"}))
        print("insert", name, entry["assetId"], "error" if r.get("isError") else u)
    with open(PLACE_LUA, encoding="utf-8") as f:
        res = c.call("execute_luau", {"code": f.read(), "datamodel_type": "Edit"})
    print("crossroads_kit_main:", ("ERROR " if res.get("isError") else "") + text_of(res)[:600])
    # 2026-10-08 (검수): the K_ kit is only the fallback now; the Tripo swap goes right back on top of it
    # (crossroads_3d_swap.luau drops the fresh K_ copies kit_main just rebuilt and re-seats pads / board / lights).
    with open(SWAP_LUA, encoding="utf-8") as f:
        res = c.call("execute_luau", {"code": f.read(), "datamodel_type": "Edit"})
    print("crossroads_3d_swap:", ("ERROR " if res.get("isError") else "") + text_of(res)[:600])


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    c = Client()
    try:
        c.start()
        run(c)
    finally:
        c.close()


if __name__ == "__main__":
    main()
