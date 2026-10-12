"""Upload one GLB mesh (one primitive) to Roblox as a Mesh asset without the 3D importer (이미지 생성 3, 10/13).

  STUDIO_NAME=WorldKit py tools/glb_mesh_upload.py <file.glb> <Name> --height 13 [--front +z] [--flip-v] [--dry]

The GLB (glTF axes, Y up) is read here: positions scaled so the model is --height studs tall, bottom centre at 0 (x/z centred on
the box), turned so its front (--front: the glTF axis the model faces, '+z' for a Blender '-Y front' export) looks along
Roblox -Z. Positions / normals / UVs go to the practice Studio in chunks (ServerStorage._GlbMeshData StringValues), an
EditableMesh is built there and uploaded with AssetService:CreateAssetAsync (Edit mode, like tools/upload_hull_meshes.py).
Prints and records the mesh id in art/models/worldkit/glb_mesh_assets.json {Name: {mesh, src, height, size, tris}}.
Roblox limit: 20,000 triangles a mesh. NOTE 10/13: CreateAssetAsync is "not available yet" in our Studio -> use tools/glb_strip_mesh.py + one user 3D import. Props only (AGENTS.md hard rule 1: view the model first).
"""
import argparse
import json
import os
import re
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "models", "worldkit", "glb_mesh_assets.json")
GUARD = 'if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end\n'
CT = {5126: "f", 5125: "I", 5123: "H", 5121: "B"}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}

ap = argparse.ArgumentParser()
ap.add_argument("glb")
ap.add_argument("name")
ap.add_argument("--height", type=float, required=True)
ap.add_argument("--front", default="+z", choices=["+z", "-z", "+x", "-x"])
ap.add_argument("--flip-v", action="store_true")
ap.add_argument("--dry", action="store_true")
a = ap.parse_args()
if re.search(r"GoodEvil|81671223175574", os.environ.get("STUDIO_NAME", "")) or not os.environ.get("STUDIO_NAME"):
    sys.exit("set STUDIO_NAME to a practice Studio (WorldKit)")

f = open(a.glb, "rb").read()
jl = struct.unpack("<I", f[12:16])[0]
g = json.loads(f[20:20 + jl])
b0 = 20 + jl + 8


def acc(i):
    ac = g["accessors"][i]
    bv = g["bufferViews"][ac["bufferView"]]
    n, k = ac["count"], NC[ac["type"]]
    fmt = CT[ac["componentType"]]
    size = struct.calcsize(fmt)
    stride = bv.get("byteStride", size * k)
    o = b0 + bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
    return [struct.unpack_from("<" + fmt * k, f, o + j * stride) for j in range(n)]


prims = [p for m in g["meshes"] for p in m["primitives"]]
if len(prims) != 1:
    sys.exit("one primitive only (got %d)" % len(prims))
P = prims[0]
pos = acc(P["attributes"]["POSITION"])
nor = acc(P["attributes"]["NORMAL"])
uv = acc(P["attributes"]["TEXCOORD_0"])
idx = [t[0] for t in acc(P["indices"])]
if len(idx) // 3 > 20000:
    sys.exit("too many triangles: %d" % (len(idx) // 3))
lo = [min(p[i] for p in pos) for i in range(3)]
hi = [max(p[i] for p in pos) for i in range(3)]
s = a.height / (hi[1] - lo[1])
cx, cz = (lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2


def turn(x, z):
    # make the model's front look along Roblox -Z
    return {"+z": (-x, -z), "-z": (x, z), "+x": (z, -x), "-x": (-z, x)}[a.front]


V, N, U = [], [], []
for (x, y, z), (nx, ny, nz), (u, v) in zip(pos, nor, uv):
    X, Z = turn((x - cx) * s, (z - cz) * s)
    V += [X, (y - lo[1]) * s, Z]
    NX, NZ = turn(nx, nz)
    N += [NX, ny, NZ]
    U += [u, (1 - v) if a.flip_v else v]
size = [max(V[0::3]) - min(V[0::3]), max(V[1::3]) - min(V[1::3]), max(V[2::3]) - min(V[2::3])]
print("[glb] %s: %d verts, %d tris, size %.2f x %.2f x %.2f" % (a.name, len(pos), len(idx) // 3, *size))
if a.dry:
    sys.exit(0)

data = {"V": ",".join("%.4f" % v for v in V), "N": ",".join("%.3f" % v for v in N), "U": ",".join("%.5f" % v for v in U),
        "T": ",".join(str(i + 1) for i in idx)}


def luau(code):
    tmp = os.path.join(os.environ.get("TEMP", ROOT), "glb_mesh_arg.json")
    json.dump({"code": code, "datamodel_type": "Edit"}, open(tmp, "w", encoding="utf-8"))
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "studio_mcp.py"), "call", "execute_luau", "@" + tmp],
                       capture_output=True, text=True, encoding="utf-8", errors="replace", env=dict(os.environ), timeout=600)
    out = (r.stdout + r.stderr).strip()
    return out.splitlines()[-1] if out else ""


print(luau(GUARD + 'local f = game:GetService("ServerStorage"):FindFirstChild("_GlbMeshData"); if f then f:Destroy() end; '
           'f = Instance.new("Folder"); f.Name = "_GlbMeshData"; f.Parent = game:GetService("ServerStorage"); return "ok"'))
CH = 80000
for k, txt in data.items():
    parts = [txt[i:i + CH] for i in range(0, len(txt), CH)]
    for j, p in enumerate(parts):
        r = luau(GUARD + 'local v = Instance.new("StringValue"); v.Name = "%s_%03d"; v.Value = "%s"; '
                 'v.Parent = game:GetService("ServerStorage")._GlbMeshData; return "%s_%03d"' % (k, j, p, k, j))
        if not r.endswith("%s_%03d" % (k, j)):
            sys.exit("chunk %s %d failed: %s" % (k, j, r[-300:]))
    print("[glb] sent", k, len(parts), "chunks", flush=True)

BUILD = GUARD + r'''
local AS = game:GetService("AssetService")
local F = game:GetService("ServerStorage")._GlbMeshData
local function nums(key)
	local names = {}
	for _, c in F:GetChildren() do if string.sub(c.Name, 1, #key + 1) == key .. "_" then table.insert(names, c.Name) end end
	table.sort(names)
	local s = {}
	for _, n in names do table.insert(s, F[n].Value) end
	local out = {}
	for w in string.gmatch(table.concat(s), "[^,]+") do out[#out + 1] = tonumber(w) end
	return out
end
local V, N, U, T = nums("V"), nums("N"), nums("U"), nums("T")
local em = AS:CreateEditableMesh()
local vid, nid, uid = {}, {}, {}
for i = 1, #V / 3 do
	vid[i] = em:AddVertex(Vector3.new(V[3 * i - 2], V[3 * i - 1], V[3 * i]))
	nid[i] = em:AddNormal(Vector3.new(N[3 * i - 2], N[3 * i - 1], N[3 * i]).Unit)
	uid[i] = em:AddUV(Vector2.new(U[2 * i - 1], U[2 * i]))
end
for i = 1, #T, 3 do
	local a, b, c = T[i], T[i + 1], T[i + 2]
	local fid = em:AddTriangle(vid[a], vid[b], vid[c])
	em:SetFaceNormals(fid, { nid[a], nid[b], nid[c] })
	em:SetFaceUVs(fid, { uid[a], uid[b], uid[c] })
end
local ok, res, id = pcall(function()
	return AS:CreateAssetAsync(em, Enum.AssetType.Mesh, { Name = "%s", Description = "Halo & Horns town prop (Tripo + Blender touch-up), no people" })
end)
F:Destroy()
if not ok then return "ERR " .. tostring(res) end
return "RES " .. tostring(res) .. " ID " .. tostring(id) .. " V " .. (#V / 3) .. " T " .. (#T / 3)
''' % a.name
r = luau(BUILD)
print("[glb]", r)
m = re.search(r"ID (\d+)", r)
if not m or "Success" not in r:
    sys.exit("upload failed")
rec = json.load(open(OUT, encoding="utf-8")) if os.path.exists(OUT) else {}
rec[a.name] = {"mesh": "rbxassetid://" + m.group(1), "src": os.path.relpath(a.glb, ROOT).replace("\\", "/"), "height": a.height,
               "size": [round(v, 3) for v in size], "tris": len(idx) // 3, "front": a.front, "flip_v": a.flip_v}
json.dump(rec, open(OUT, "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=1)
print("[glb] recorded", OUT)
