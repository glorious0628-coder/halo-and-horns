"""Make every rebuilt wall lantern the same size in WorldKit after the deco import (이미지 생성 3, 10/12): open glass band
1.05 studs (the skeleton LampGlass height). Some lanterns came out up to 2.2 (09, 11: their measured body was narrow and the
"never narrower than the 0.7 glass" rule scaled them up), so they are scaled down in Studio instead of a new import.

  py tools/house_lantern_resize.py   -> build/house_lantern_resize.json, then
  STUDIO_NAME=<WorldKit window> py tools/studio_mcp.py call execute_luau @build/house_lantern_resize.json

For each house: f = 1.05 / band (band from build/deco/<house>/deco_raw.json). Every <house>_Lantern* MeshPart (in
SkeletonTest.<house>_Deco and in each HaloV2.Buildings clone) is scaled by f about the wall point behind its nearest
LampGlass (LampGlass centre + 0.75 towards the wall), so the bracket stays on the wall; that LampGlass / LampCore move to
the new glass centre, the glass becomes 1.05 tall and as wide as the body allows (2 x bottom half width x f - 0.12, 0.3 .. 0.7).
Idempotent: a lantern already resized carries the attribute LanternScaled and is skipped.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
pack = json.load(open(os.path.join(ROOT, "art", "models", "tripo", "house_deco", "HaloHouses15_Deco_v1.json")))
rows = []
for nm in pack["houses"]:
    L = json.load(open(os.path.join(ROOT, "build", "deco", nm, "deco_raw.json"), encoding="utf-8"))["pieces"].get("Lantern")
    if not L:
        continue
    band = L["glass_band_studs"][1] - L["glass_band_studs"][0]
    f = 1.05 / band
    gw = max(0.3, min(0.7, 2 * L["body_half_width_studs"][0] * f - 0.12))
    rows.append('{name="%s", f=%.4f, gw=%.3f}' % (nm, f, gw))
code = '''if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end
local H = {%s}
local out = {}
local roots = {workspace.SkeletonTest}
local B = workspace:FindFirstChild("HaloV2") and workspace.HaloV2:FindFirstChild("Buildings")
if B then for _, c in B:GetChildren() do if c:GetAttribute("HouseSkeleton") then table.insert(roots, c) end end end
for _, h in H do
  local n = 0
  for _, root in roots do
    -- this house's deco model(s) and skeleton model under this root
    local deco = root:FindFirstChild(h.name .. "_Deco")
    local skel = root:FindFirstChild(h.name .. "_Skeleton") or (root ~= workspace.SkeletonTest and root:FindFirstChild(h.name .. "_Skeleton", true))
    if deco and skel then
      local glasses = {}
      for _, q in skel:GetDescendants() do
        if q:IsA("BasePart") and string.match(q.Name, "^LampGlass%%d") then table.insert(glasses, q) end
      end
      for _, l in deco:GetChildren() do
        if l:IsA("BasePart") and string.find(l.Name, "_Lantern") and not l:GetAttribute("LanternScaled") then
          local best, bd = nil, 1e9
          for _, g in glasses do local d = (g.Position - l.Position).Magnitude; if d < bd then best, bd = g, d end end
          if best and bd < 4 then
            local idx = string.match(best.Name, "%%d+")
            local core = skel:FindFirstChild("LampCore" .. idx, true)
            local pw = best.CFrame:PointToWorldSpace(Vector3.new(0, 0, 0.75))      -- the wall behind the glass centre
            l.Size = l.Size * h.f
            l.Position = pw + (l.Position - pw) * h.f
            l:SetAttribute("LanternScaled", h.f)
            local gc = pw + (best.Position - pw) * h.f
            best.CFrame = best.CFrame - best.Position + gc
            best.Size = Vector3.new(h.gw, 1.05, h.gw)
            if core then core.CFrame = core.CFrame - core.Position + gc; core.Size = Vector3.new(h.gw * 0.5, 0.5, h.gw * 0.5) end
            n += 1
          end
        end
      end
    end
  end
  table.insert(out, string.format("%%s f %%.2f glass %%.2f: %%d lanterns", h.name, h.f, h.gw, n))
end
return table.concat(out, " | ")''' % ",\n".join(rows)
json.dump({"code": code, "datamodel_type": "Edit"}, open(os.path.join(ROOT, "build", "house_lantern_resize.json"), "w", encoding="utf-8"))
print("[lantern] %d houses -> build/house_lantern_resize.json" % len(rows))
