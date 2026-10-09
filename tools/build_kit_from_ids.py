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
PRECISE = ("Gate", "Bridge", "Wall", "Spawn", "Fountain", "GuildHall", "PadBase", "SpawnPlaza", "Castle",
           "Arch", "NoticeBoard", "Stairs",
           "Shop", "Cathedral", "DomeHouse")  # 2026-10-08 검수: walk-through arch, board face ray, steps you climb; 2026-10-10 zone_check_halo #12: shop counters, cathedral steps, house porches (a Hull would wall them off)


def fidelity(name):
    if name.startswith("Acc_"):
        return "Box"
    if any(k in name for k in PRECISE):
        return "PreciseConvexDecomposition"
    return "Hull"


# 2026-10-08 (검수): "sa" = SurfaceAppearance maps (PBR import, e.g. the fountain); "group" + "offset" = one tile of a
# multi-mesh model (castles cut in 9 texture tiles): every tile of a group goes into ONE Model named after the group,
# at its offset (studs, tile centre relative to the group's bottom centre); the group pivot is that bottom centre.
def row(it):
    sa = it.get("sa") or {}
    extra = ""
    if sa:
        extra += ", sa = {%s}" % ", ".join('%s = "%s"' % (k, v) for k, v in sa.items())
    if it.get("group"):
        extra += ', group = "%s", offset = Vector3.new(%s, %s, %s)' % (it["group"], *it["offset"])
    return ('  {name = "%s", mesh = "%s", tex = "%s", size = Vector3.new(%s, %s, %s), col = Enum.CollisionFidelity.%s%s}'
            % (it["name"], it["meshId"], it.get("textureId", ""), *it["size_studs"],
               fidelity(it.get("group") or it["name"]), extra))


rows = ",\n".join(row(it) for it in items)
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
local groups = {{}}  -- group name -> Model filled this run
for _, it in ipairs(items) do
  local old = node:FindFirstChild(it.group or it.name)
  if it.group and groups[it.group] then
    old = nil
  elseif old and not REPLACE then
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
  if it.sa then
    local sa = Instance.new("SurfaceAppearance")
    local okSa, errSa = pcall(function()
      if it.sa.color then sa.ColorMap = it.sa.color end
      if it.sa.normal then sa.NormalMap = it.sa.normal end
      -- 2026-10-08 검수: Tripo's imported metalness maps render the whole model chrome-grey (notice board, nest, houses);
      -- stylized props look right without one, so the metal map is never applied

      if it.sa.rough then sa.RoughnessMap = it.sa.rough end
    end)
    if okSa then sa.Parent = mp else table.insert(failed, it.name .. " SurfaceAppearance: " .. tostring(errSa)) end
  end
  if it.group then
    local g = groups[it.group]
    if not g then
      g = Instance.new("Model")
      g.Name = it.group
      g:SetAttribute("Front", "-Z")
      g.WorldPivot = CFrame.new()
      g.Parent = node
      groups[it.group] = g
    end
    mp.CFrame = CFrame.new(it.offset)
    mp.Parent = g
    made += 1
    continue
  end
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
