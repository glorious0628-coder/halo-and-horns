"""After the user's one Import 3D of art/models/tripo/house_deco/HaloHouses15_Deco_v1.glb into WorldKit: put the decorations in
place (이미지 생성 3, 10/12; SPEC A23-125 step 3 = Roblox materials).

  py tools/house_deco_studio.py [--model HaloHouses15_Deco_v1]   -> build/house_deco_studio.json, then
  STUDIO_NAME=WorldKit py tools/studio_mcp.py call execute_luau @build/house_deco_studio.json

The Luau: finds the imported model (Workspace, by name), moves it so its bounding box min = the one tools/house_deco_pack.py
wrote (the importer's drop point T), checks the box size; splits its MeshParts by house prefix into
Workspace.SkeletonTest.<house>_Deco; materials: plain gold pieces (lantern frames, knobs, metal knocker rings, 09's dome +
ribs, any part without a SurfaceAppearance) = Metal + MaterialVariant HH_HaloGoldTrim + Color (255, 168, 36); pieces with
Tripo paint (domes, tower caps, door leaves) keep their SurfaceAppearance; door leaves Material Wood; LampGlass0..2 of each
SkeletonTest skeleton get the height of that house's rebuilt lantern glass band; then every HaloV2.Buildings.<plan id>
house clone (tools/house_plan_place.py) gets the same decorations at its plan spot (pivot = the skeleton clone's pivot) and
the same LampGlass height. Re-runnable: old <house>_Deco models are replaced.
"""
import argparse
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ap = argparse.ArgumentParser()
ap.add_argument("--model", default="HaloHouses15_Deco_v1")
a = ap.parse_args()
pack = json.load(open(os.path.join(ROOT, "art", "models", "tripo", "house_deco", "HaloHouses15_Deco_v1.json")))
plan = json.load(open(os.path.join(ROOT, "docs", "design", "halo_plan_v2_2026-10-11.json"), encoding="utf-8"))
SHORT = {}
for b in plan["buildings"]:
    sk = b.get("skeleton")
    if sk:
        h = sk["house"]
        nm = ("HaloDomeHouse_" + h) if h.isdigit() else ("HaloShop_" + h)
        SHORT.setdefault(nm, []).append(b["id"])
houses = []
for nm, h in pack["houses"].items():
    r = json.load(open(os.path.join(ROOT, "build", "deco", nm, "deco_raw.json"), encoding="utf-8"))
    band = r["pieces"].get("Lantern", {}).get("glass_band_studs")
    gh = round(band[1] - band[0], 3) if band else 0
    houses.append('{name="%s", ox=%g, oz=%g, glass=%g, ids={%s}}' % (nm, h["origin"][0], h["origin"][2], gh,
                                                                  ", ".join('"%s"' % i for i in SHORT.get(nm, []))))
mn, mx = pack["roblox_bbox"]["min"], pack["roblox_bbox"]["max"]
code = '''if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end
local M = workspace:FindFirstChild("%s", true)
if not M then return "imported model %s not found" end
local H = {%s}
local EMIN, EMAX = Vector3.new(%g, %g, %g), Vector3.new(%g, %g, %g)
local out = {}
-- 1. where the importer dropped it: move by the box difference
local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
for _, p in M:GetDescendants() do
  if p:IsA("BasePart") then
    local cf, sz = p.CFrame, p.Size
    for _, sx in {-0.5, 0.5} do for _, sy in {-0.5, 0.5} do for _, sz_ in {-0.5, 0.5} do
      local w = cf:PointToWorldSpace(Vector3.new(sx * sz.X, sy * sz.Y, sz_ * sz.Z)); lo = lo:Min(w); hi = hi:Max(w)
    end end end
  end
end
local d = EMIN - lo
table.insert(out, string.format("box size got %%.1f,%%.1f,%%.1f want %%.1f,%%.1f,%%.1f; moved by %%.2f,%%.2f,%%.2f",
  (hi - lo).X, (hi - lo).Y, (hi - lo).Z, (EMAX - EMIN).X, (EMAX - EMIN).Y, (EMAX - EMIN).Z, d.X, d.Y, d.Z))
for _, p in M:GetDescendants() do if p:IsA("BasePart") then p.CFrame = p.CFrame + d; p.Anchored = true end end
-- 2. per house: SkeletonTest.<house>_Deco, materials, lamp glass
local ST = workspace.SkeletonTest
local B = workspace:FindFirstChild("HaloV2") and workspace.HaloV2:FindFirstChild("Buildings")
local function gold(p)
  p.Material = Enum.Material.Metal; p.MaterialVariant = "HH_HaloGoldTrim"; p.Color = Color3.fromRGB(255, 168, 36)
end
for _, h in H do
  local old = ST:FindFirstChild(h.name .. "_Deco"); if old then old:Destroy() end
  local m = Instance.new("Model"); m.Name = h.name .. "_Deco"; m.Parent = ST
  local n = 0
  for _, p in M:GetDescendants() do
    if p:IsA("BasePart") and (string.sub(p.Name, 1, #h.name) == h.name or string.find(p.Name, "Orn_" .. h.name, 1, true)) then
      p.Parent = m; n += 1
      local sa = p:FindFirstChildWhichIsA("SurfaceAppearance")
      if string.find(p.Name, "_Leaf") then p.Material = Enum.Material.Wood
      elseif not sa then gold(p) end
      p.CastShadow = true; p.CanCollide = false
    end
  end
  m.WorldPivot = CFrame.new(h.ox, 0, h.oz)
  local sk = ST:FindFirstChild(h.name .. "_Skeleton")
  local function lamps(root)
    if h.glass <= 0 or not root then return end
    for _, q in root:GetDescendants() do
      if q:IsA("BasePart") and string.match(q.Name, "^LampGlass%%d") then q.Size = Vector3.new(q.Size.X, h.glass, q.Size.Z) end
    end
  end
  lamps(sk)
  -- check: the door leaf against the skeleton's DoorFront (5 studs in front of the door face, front = -Z in the rows)
  local chk = ""
  local df = sk and sk:FindFirstChild("DoorFront", true)
  local lf = m:FindFirstChild(h.name .. "_Leaf") or m:FindFirstChild(h.name .. "_Leaf0")
  if df and lf then
    local lp, dp = lf.Position, df.WorldPosition
    local lf1 = m:FindFirstChild(h.name .. "_Leaf1")
    if lf1 then lp = (lf.Position + lf1.Position) / 2 end
    chk = string.format(" door dx %%.2f dz %%.2f", lp.X - dp.X, lp.Z - (dp.Z + 5))
  end
  -- 3. the plan spots
  local placed = 0
  for _, id in h.ids do
    local tgt = B and B:FindFirstChild(id)
    if tgt and tgt:GetAttribute("HouseSkeleton") then
      local o2 = tgt:FindFirstChild(h.name .. "_Deco"); if o2 then o2:Destroy() end
      local c = m:Clone(); c.Parent = tgt; c:PivotTo(tgt.WorldPivot); lamps(tgt); placed += 1
    end
  end
  table.insert(out, string.format("%%s: %%d parts, plan copies %%d, glass %%.2f%%s", h.name, n, placed, h.glass, chk))
end
local left = 0
for _, p in M:GetDescendants() do if p:IsA("BasePart") then left += 1 end end
if left == 0 then M:Destroy() end
table.insert(out, "left in the import model: " .. left)
return table.concat(out, " | ")''' % (a.model, a.model, ",\n".join(houses), *mn, *mx)
os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
json.dump({"code": code, "datamodel_type": "Edit"}, open(os.path.join(ROOT, "build", "house_deco_studio.json"), "w", encoding="utf-8"))
print("[studio] %d houses -> build/house_deco_studio.json" % len(houses))
