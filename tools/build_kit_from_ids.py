"""
Make the Studio command that builds kit Models from uploaded mesh/texture ids (no 3D importer, no screen control).

  py tools/build_kit_from_ids.py [--list art/models/worldkit/import40_assets_2026-10-06.json] [--only Acc_,Kit_M_]
                                 [--parent ServerStorage/MarkModels] [--replace] --out build/kit_args.json
  py tools/studio_mcp.py call execute_luau @build/kit_args.json      (Studio in Edit mode)

Each item becomes Model <name> with one anchored MeshPart <name> (AssetService:CreateMeshPartAsync), the uploaded
texture, the listed size in studs, pivot at the bottom centre and the front facing -Z, under --parent (folders are
made when missing; a first path part that is a service name uses that service). Existing names are skipped unless
--replace. Gates, bridges, walls, spawn pads, the fountain, the guild hall and castles get PreciseConvexDecomposition
collision (walk-through arches); small props get Hull; rank marks get Box (the server turns collision off).
"""
import argparse
import json

ap = argparse.ArgumentParser()
ap.add_argument("--list", default="art/models/worldkit/import40_assets_2026-10-06.json")
ap.add_argument("--only", default="", help="comma list of name prefixes")
ap.add_argument("--parent", default="ServerStorage/WorldKit3D")
ap.add_argument("--replace", action="store_true")
ap.add_argument("--out", required=True)
a = ap.parse_args()

items = json.load(open(a.list, encoding="utf-8"))["items"]
prefixes = [p for p in a.only.split(",") if p]
if prefixes:
    items = [it for it in items if any(it["name"].startswith(p) for p in prefixes)]
PRECISE = ("Gate", "Bridge", "Wall", "Spawn", "Fountain", "GuildHall", "PadBase", "SpawnPlaza", "Castle")


def fidelity(name):
    if name.startswith("Acc_"):
        return "Box"
    if any(k in name for k in PRECISE):
        return "PreciseConvexDecomposition"
    return "Hull"


rows = ",\n".join(
    '  {name = "%s", mesh = "%s", tex = "%s", size = Vector3.new(%s, %s, %s), col = Enum.CollisionFidelity.%s}'
    % (it["name"], it["meshId"], it["textureId"], *it["size_studs"], fidelity(it["name"])) for it in items)
code = f'''local AssetService = game:GetService("AssetService")
local PARENT, REPLACE = "{a.parent}", {"true" if a.replace else "false"}
local node = nil
for seg in string.gmatch(PARENT, "[^/]+") do
  local nxt = node and node:FindFirstChild(seg)
  if not node then
    local ok, svc = pcall(function() return game:GetService(seg) end)
    nxt = ok and svc or game:FindFirstChild(seg)
  end
  if not nxt then
    nxt = Instance.new("Folder")
    nxt.Name = seg
    nxt.Parent = node
  end
  node = nxt
end
local items = {{
{rows}
}}
local made, skipped, failed = 0, 0, {{}}
for _, it in ipairs(items) do
  local old = node:FindFirstChild(it.name)
  if old and not REPLACE then
    skipped += 1
    continue
  end
  local opts = {{CollisionFidelity = it.col, RenderFidelity = Enum.RenderFidelity.Automatic}}
  local ok, mp = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromUri(it.mesh), opts) end)
  if not ok then
    ok, mp = pcall(function() return AssetService:CreateMeshPartAsync(it.mesh, opts) end)
  end
  if not ok then
    table.insert(failed, it.name .. ": " .. tostring(mp))
    continue
  end
  if old then old:Destroy() end
  mp.Name = it.name
  mp.TextureID = it.tex
  mp.Size = it.size
  mp.Anchored = true
  mp.PivotOffset = CFrame.new(0, -it.size.Y / 2, 0)
  local m = Instance.new("Model")
  m.Name = it.name
  mp.Parent = m
  m.PrimaryPart = mp
  m:SetAttribute("Front", "-Z")
  m:PivotTo(CFrame.new())
  m.Parent = node
  made += 1
end
return string.format("%s: made %d, skipped %d, failed %d %s", node:GetFullName(), made, skipped, #failed, table.concat(failed, "; "))
'''
json.dump({"code": code, "datamodel_type": "Edit"}, open(a.out, "w", encoding="utf-8"), ensure_ascii=False)
print(f"{len(items)} items -> {a.out} (parent {a.parent})")
