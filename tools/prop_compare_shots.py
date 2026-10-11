"""Comparison photos for the "선이 없어 보여" test (디자인 검수 10/11, 이미지 생성 4): the same props, the same camera, several
looks side by side, in the WorldKit Studio under the main Halo-town light (tools/halo_light_sim.luau C2c day / night).

  A   = the kit as built now, on the grey showcase floor 300 studs up (like the first Studio photos)
  B   = the kit on real town ground (cobble + grass) + CastShadow on every part (lamp glass / neon stay off)
  B2  = B + one more light change: Lighting.EnvironmentDiffuseScale 0.5 -> 0.3 (shade sides darker)
  D1  = B + a Highlight outline (dark brown, FillTransparency 1, DepthMode Occluded; no upload; <= 31 on screen)
  C   = B with the flat-coloured parts swapped for the baked MeshPart (tools/prop_kit_bake.py) - needs --assets
  D2  = B + inverted-hull MeshPart (uploaded) - needs --assets
  D2t / D2T = B + inverted hull built in Studio from build/prop_kit_hull/<Kit>_D2_035.obj / _D2_060.obj
        (tools/prop_kit_bake.py --hull-only) with an EditableMesh: nothing is uploaded, it lives only in this Edit session
Rows (--rows): day / night (lamps on) x camera 5 / 15 studs from the kit centre (front 3/4, a little above).

  STUDIO_NAME=WorldKit py tools/prop_compare_shots.py <out_dir> [Kit ...] [--cols A,B,B2,D1] [--spot -24,0.2,-440]
          [--rows day5,day15,night5,night15] [--assets assets.json] [--flip] [--keep] [--dry]

assets.json = {"<Kit>": {"C_mesh": "rbxassetid://..", "C_color": "rbxassetid://..", "D2_hull": "rbxassetid://.."}}
(ids from 이미지 개발 after 최종 검수 approval). Needs the WorldKit window visible: ask 최종 검수 for the screen slot.
Saves <out_dir>/<Kit>_<col>_<day|night>_<5|15>.png; restores the light and removes everything it placed.
"""
import argparse
import base64
import io
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from PIL import Image  # noqa: E402
from studio_mcp import Client  # noqa: E402

SIM = open(os.path.join(ROOT, "tools", "halo_light_sim.luau"), encoding="utf-8").read()
RESTORE = open(os.path.join(ROOT, "tools", "halo_light_restore.luau"), encoding="utf-8").read()
GUARD = 'if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end\n'
KITS = ["HaloReasonHQ_BenchA", "HaloVar4_Lantern_A", "NEW_Beehive", "HaloVar4_Planter_D__Body"]
BAKE = {"marble", "mblock", "stone", "blue", "slate", "dark", "paint", "candle", "pcream", "groove"}   # = tools/prop_kit_bake.py BAKE

# place one look of one kit; returns its bounding box as JSON. %s: kit, look, spot x/y/z, assets json, bake part names
PLACE = GUARD + r'''
local kit, look = "%s", "%s"
local SX, SY, SZ = %s, %s, %s
local A = game:GetService("HttpService"):JSONDecode([==[%s]==])
local bakeNames = game:GetService("HttpService"):JSONDecode([==[%s]==])
local HULL = %s
local src = game:GetService("ServerStorage").HaloPropKits:FindFirstChild(kit)
if not src then return "no kit " .. kit end
local old = workspace:FindFirstChild("PropCompare"); if old then old:Destroy() end
local root = Instance.new("Folder"); root.Name = "PropCompare"; root.Parent = workspace
local m = src:Clone()
local pivot
if look == "A" then
	pivot = CFrame.new(5000, 300, 0) * CFrame.Angles(0, math.rad(25), 0)   -- same turn as on the ground
	local floor = Instance.new("Part"); floor.Name = "Floor"; floor.Anchored = true; floor.Size = Vector3.new(60, 1, 60)
	floor.CFrame = CFrame.new(5000, 299.5, 0); floor.Material = Enum.Material.Concrete; floor.Color = Color3.fromRGB(200, 196, 186)
	floor.Parent = root
else
	pivot = CFrame.new(SX, SY, SZ) * CFrame.Angles(0, math.rad(25), 0)   -- C2c day sun rakes the front (80 deg), camera 45 deg off the sun
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Material ~= Enum.Material.Glass and d.Material ~= Enum.Material.Neon then d.CastShadow = true end
	end
end
m:PivotTo(pivot)
m.Parent = root
if look == "D1" then
	local h = Instance.new("Highlight"); h.Name = "CompareOutline"; h.Adornee = m
	h.FillTransparency = 1; h.OutlineTransparency = 0; h.OutlineColor = Color3.fromRGB(74, 50, 36)
	h.DepthMode = Enum.HighlightDepthMode.Occluded; h.Parent = m
end
local AS = game:GetService("AssetService")
local function meshPart(id, centre)
	local ok, mp = pcall(function() return AS:CreateMeshPartAsync(Content.fromUri(id), {CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Precise}) end)
	if not ok then error("mesh " .. id .. ": " .. tostring(mp)) end
	mp.Anchored = true; mp.CanCollide = false; mp.CanTouch = false; mp.CanQuery = false
	mp.CFrame = pivot * CFrame.new(centre[1], centre[2], centre[3])
	mp.Parent = m
	return mp
end
if look == "C" then
	local set = {}
	for _, n in bakeNames do set[n] = true end
	for _, c in m:GetChildren() do if c:IsA("BasePart") and set[c.Name] then c:Destroy() end end
	local mp = meshPart(A.C_mesh, A.C_centre)
	mp.Name = "Baked"; mp.CastShadow = true
	local sa = Instance.new("SurfaceAppearance"); sa.ColorMap = A.C_color
	sa.RoughnessMap = "rbxassetid://76093268063395"; sa.MetalnessMap = "rbxassetid://87489921567476"
	sa.Parent = mp
elseif look == "D2" then
	local mp = meshPart(A.D2_hull, A.D2_centre)
	mp.Name = "OutlineHull"; mp.CastShadow = false; mp.Material = Enum.Material.SmoothPlastic; mp.Color = Color3.fromRGB(74, 50, 36)
elseif HULL then
	-- EditableMesh hull (no upload): vertices are centred on the hull's own box centre HULL.c (kit-local Roblox axes)
	local em = AS:CreateEditableMesh()
	local ids = {}
	for i = 1, #HULL.V, 3 do ids[#ids + 1] = em:AddVertex(Vector3.new(HULL.V[i], HULL.V[i + 1], HULL.V[i + 2])) end
	for i = 1, #HULL.T, 3 do em:AddTriangle(ids[HULL.T[i]], ids[HULL.T[i + 1]], ids[HULL.T[i + 2]]) end
	local mp = AS:CreateMeshPartAsync(Content.fromObject(em))
	mp.Name = "OutlineHull"; mp.Anchored = true; mp.CanCollide = false; mp.CanTouch = false; mp.CanQuery = false
	mp.CastShadow = false; mp.Material = Enum.Material.SmoothPlastic; mp.Color = Color3.fromRGB(74, 50, 36)
	mp.CFrame = pivot * CFrame.new(HULL.c[1], HULL.c[2], HULL.c[3])
	mp.Parent = m
end
local cf, sz = m:GetBoundingBox()
local nParts, nLights = 0, 0
for _, d in m:GetDescendants() do
	if d:IsA("BasePart") then nParts += 1 end
	if d:IsA("PointLight") and d.Name == "LampLight" then nLights += 1 end
end
local lv = pivot.LookVector
return string.format('{"c":[%%.3f,%%.3f,%%.3f],"s":[%%.3f,%%.3f,%%.3f],"look":[%%.4f,%%.4f],"parts":%%d,"lamps":%%d}',
	cf.X, cf.Y, cf.Z, sz.X, sz.Y, sz.Z, lv.X, lv.Z, nParts, nLights)
'''
LAMPS = GUARD + r'''
local on = %s
local r = workspace:FindFirstChild("PropCompare")
if r then for _, d in r:GetDescendants() do if d:IsA("PointLight") and d.Name == "LampLight" then d.Enabled = on end end end
return "ok"
'''
DIFF = GUARD + 'game:GetService("Lighting").EnvironmentDiffuseScale = %s; return "diff"'
CLEAN = GUARD + 'local r = workspace:FindFirstChild("PropCompare"); if r then r:Destroy() end; return "removed"'


def sim(phase):
    return SIM.replace('local CAND, PHASE = "%s", "%s"', 'local CAND, PHASE = "C2c", "' + phase + '"')


def luau(c, code):
    r = c.call("execute_luau", {"code": code, "datamodel_type": "Edit"})
    return "".join(p.get("text", "") for p in r.get("content", []) if p.get("type") == "text")


def grab(c, tag, cam, look):
    res = c.call("screen_capture", {"capture_id": "pc_" + tag, "camera_position": cam, "look_at_position": look})
    for part in res.get("content", []):
        if part.get("type") == "image":
            im = Image.open(io.BytesIO(base64.b64decode(part["data"])))
            w, h = im.size
            s = min(w, h)
            return im.crop(((w - s) // 2, (h - s) // 2, (w + s) // 2, (h + s) // 2))
    raise RuntimeError("no image for %s: %s" % (tag, str(res)[:300]))


HULLS = {"D2t": "035", "D2T": "060"}


def hull_lua(kit, col, flip):
    """Luau table literal {V = {...}, T = {...}, c = {...}} from build/prop_kit_hull/<Kit>_D2_<t>.obj (triangulated)."""
    f = os.path.join(ROOT, "build", "prop_kit_hull", "%s_D2_%s.obj" % (kit, HULLS[col]))
    vs, ts = [], []
    for ln in open(f, encoding="utf-8"):
        if ln.startswith("v "):
            vs.append([float(x) for x in ln.split()[1:4]])
        elif ln.startswith("f "):
            idx = [int(w.split("/")[0]) for w in ln.split()[1:]]
            if len(idx) != 3:
                raise SystemExit("%s: not triangulated" % f)
            ts.append(idx[::-1] if flip else idx)
    lo = [min(v[i] for v in vs) for i in range(3)]
    hi = [max(v[i] for v in vs) for i in range(3)]
    c = [(lo[i] + hi[i]) / 2 for i in range(3)]
    V = ",".join("%.4f,%.4f,%.4f" % (v[0] - c[0], v[1] - c[1], v[2] - c[2]) for v in vs)
    T = ",".join("%d,%d,%d" % tuple(t) for t in ts)
    return "{V = {%s}, T = {%s}, c = {%.4f, %.4f, %.4f}}" % (V, T, c[0], c[1], c[2]), len(ts)


def bake_names(kit):
    K = json.load(open(os.path.join(ROOT, "build", "prop_kit", kit + ".json")))
    names = [t["n"] for t in K["parts"] if t["m"] in BAKE]
    other = {t["n"] for t in K["parts"] if t["m"] not in BAKE}
    clash = sorted(set(names) & other)
    if clash:
        raise SystemExit("%s: part names used by baked and kept parts: %s" % (kit, clash))
    return names


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("kits", nargs="*")
    ap.add_argument("--cols", default="A,B,B2,D1")
    ap.add_argument("--spot", default="-24,0.2,-440")
    ap.add_argument("--assets", default="")
    ap.add_argument("--rows", default="day5,day15,night5,night15")
    ap.add_argument("--flip", action="store_true", help="reverse hull triangle winding (if the hull shows as a solid blob)")
    ap.add_argument("--keep", action="store_true")
    ap.add_argument("--dry", action="store_true", help="place every look and print it, no light change, no photos")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    kits = a.kits or KITS
    cols = a.cols.split(",")
    sx, sy, sz = a.spot.split(",")
    assets = json.load(open(a.assets)) if a.assets else {}
    stats = {}
    c = Client()
    c.start()
    try:
        rows = [(r.rstrip("0123456789"), int(r.lstrip("adghinty"))) for r in a.rows.split(",")]
        phases = [p for p in ("day", "night") if any(r[0] == p for r in rows)]
        for phase in (phases[:1] if a.dry else phases):
            dists = [d for (p, d) in rows if p == phase]
            if not a.dry:
                print(luau(c, sim(phase))[:160])
            for kit in kits:
                for col in cols:
                    real = "B" if col == "B2" else col
                    if real in ("C", "D2") and kit not in assets:
                        continue
                    if real == "D2" and "D2_hull" not in assets.get(kit, {}):
                        continue
                    hull, ntri = ("nil", 0)
                    if col in HULLS:
                        hull, ntri = hull_lua(kit, col, a.flip)
                    txt = luau(c, PLACE % (kit, real, sx, sy, sz, json.dumps(assets.get(kit, {})),
                                           json.dumps(bake_names(kit) if real == "C" else []), hull))
                    try:
                        box = json.loads(txt[txt.index("{"):txt.rindex("}") + 1])
                    except ValueError:
                        raise RuntimeError("%s %s: %s" % (kit, col, txt[:300]))
                    stats.setdefault(kit, {})[col] = {"parts": box["parts"], "lamps": box["lamps"], "hull_tris": ntri}
                    if a.dry:
                        print("[dry]", kit, col, box, flush=True)
                        continue
                    luau(c, LAMPS % ("true" if phase == "night" else "false"))
                    if col == "B2":
                        luau(c, DIFF % "0.3")
                    cx, cy, cz = box["c"]
                    lx, lz = box["look"]
                    # front 3/4 like tools/prop_kit_shots.py "q34": 35 deg off the kit's front towards the kit's own
                    # left side (-RightVector), 14 deg above
                    az, el = math.radians(35), math.radians(14)
                    rx, rz = -lz, lx                       # kit's RightVector
                    dx = lx * math.cos(az) - rx * math.sin(az)
                    dz = lz * math.cos(az) - rz * math.sin(az)
                    for i, dist in enumerate([dists[0]] + dists):
                        cam = [cx + dx * dist * math.cos(el), cy + dist * math.sin(el), cz + dz * dist * math.cos(el)]
                        tag = "%s_%s_%s_%d" % (kit, col, phase, dist)
                        im = grab(c, tag, cam, [cx, cy, cz])
                        if i:                       # the first frame after a move can still show the old camera: drop it
                            im.save(os.path.join(a.out, tag + ".png"))
                    if col == "B2":
                        luau(c, DIFF % "0.5")
                    print("[compare]", phase, kit, col, flush=True)
    finally:
        if not a.dry:
            print(luau(c, RESTORE)[:200])
        if not a.keep:
            print(luau(c, CLEAN))
    json.dump(stats, open(os.path.join(a.out, "_stats.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
