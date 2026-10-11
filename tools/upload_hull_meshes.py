"""Upload the inverted-hull outline meshes (D2) of the prop kits as mesh assets (이미지 개발 2026-10-12; 최종 검수 approval via 디자인 검수).
No 3D importer / mouse: the OBJ (build/prop_kit_hull/<Kit>_D2_<035|060>.obj, triangulated, Roblox axes) is read here, rebuilt in the Studio
as an EditableMesh (centred on its own box centre like tools/prop_compare_shots.py hull_lua) and uploaded with AssetService:CreateAssetAsync
(plugin-level call through execute_luau, practice Studio, Edit mode).

  STUDIO_NAME=WorldKit py tools/upload_hull_meshes.py --kits HaloReasonHQ_BenchA,NEW_Beehive --thick 035[,060] [--dry]

Prints and records {"<Kit>": {"D2_hull_<t>": "rbxassetid://..", "D2_centre_<t>": [x,y,z]}} in art/models/worldkit/prop_hull_assets.json
(centre = the offset the mesh's own centre has in kit-local Roblox axes: CFrame = kitPivot * CFrame.new(centre), as prop_compare_shots uses D2_centre).
Skips a key that is already recorded unless --replace. View every render yourself first (AGENTS.md hard rule 1: props only, no people).
"""
import argparse
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
OUT = os.path.join(ROOT, "art", "models", "worldkit", "prop_hull_assets.json")

LUA = r'''
if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end
local AS = game:GetService("AssetService")
local H = %s
local em = AS:CreateEditableMesh()
local ids = {}
for i = 1, #H.V, 3 do ids[#ids + 1] = em:AddVertex(Vector3.new(H.V[i], H.V[i + 1], H.V[i + 2])) end
for i = 1, #H.T, 3 do em:AddTriangle(ids[H.T[i]], ids[H.T[i + 1]], ids[H.T[i + 2]]) end
local ok, res, id = pcall(function() return AS:CreateAssetAsync(em, Enum.AssetType.Mesh, { Name = "%s", Description = "Halo town prop outline hull (inverted hull, no people)" }) end)
if not ok then return "ERR " .. tostring(res) end
return "RES " .. tostring(res) .. " ID " .. tostring(id)
'''


def hull(kit, t, d="prop_kit_hull"):
    f = os.path.join(ROOT, "build", d, "%s_D2_%s.obj" % (kit, t))
    vs, ts = [], []
    for ln in open(f, encoding="utf-8"):
        if ln.startswith("v "):
            vs.append([float(x) for x in ln.split()[1:4]])
        elif ln.startswith("f "):
            idx = [int(w.split("/")[0]) for w in ln.split()[1:]]
            if len(idx) != 3:
                raise SystemExit("%s: not triangulated" % f)
            ts.append(idx)
    lo = [min(v[i] for v in vs) for i in range(3)]
    hi = [max(v[i] for v in vs) for i in range(3)]
    c = [(lo[i] + hi[i]) / 2 for i in range(3)]
    V = ",".join("%.4f,%.4f,%.4f" % (v[0] - c[0], v[1] - c[1], v[2] - c[2]) for v in vs)
    T = ",".join("%d,%d,%d" % tuple(t_) for t_ in ts)
    return "{V = {%s}, T = {%s}}" % (V, T), c, len(vs), len(ts)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kits", required=True)
    ap.add_argument("--thick", default="035")
    ap.add_argument("--dir", default="prop_kit_hull", help="folder under build/ (the 0.035 outline run: prop_kit_hull035)")
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--replace", action="store_true")
    a = ap.parse_args()
    rec = json.load(open(OUT, encoding="utf-8")) if os.path.exists(OUT) else {}
    todo = []
    for kit in a.kits.split(","):
        for t in a.thick.split(","):
            if f"D2_hull_{t}" in rec.get(kit, {}) and not a.replace:
                print("skip (recorded)", kit, t)
                continue
            lit, c, nv, nt = hull(kit, t, a.dir)
            print(kit, t, "verts", nv, "tris", nt, "centre", [round(x, 4) for x in c])
            todo.append((kit, t, lit, c))
    if a.dry or not todo:
        return
    from studio_mcp import Client
    cl = Client()
    cl.start()
    try:
        for kit, t, lit, c in todo:
            r = cl.call("execute_luau", {"code": LUA % (lit, "HaloHull_%s_%s" % (kit, t)), "datamodel_type": "Edit"})
            txt = "".join(p.get("text", "") for p in r.get("content", []))
            print(kit, t, txt.strip()[:300])
            if "ID " in txt and txt.strip().startswith("RES"):
                aid = txt.strip().split("ID ")[-1].strip()
                if aid.isdigit():
                    rec.setdefault(kit, {})[f"D2_hull_{t}"] = "rbxassetid://" + aid
                    rec[kit][f"D2_centre_{t}"] = [round(x, 4) for x in c]
                    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
                        json.dump(rec, f, ensure_ascii=False, indent=1)
    finally:
        cl.close()


if __name__ == "__main__":
    main()
