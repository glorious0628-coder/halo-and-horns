"""Read the MeshIds of the outline hulls the user imported with Studio's Import 3D (build/hull_import/Hull_<Kit>.obj) (이미지 개발 2026-10-12).
  STUDIO_NAME=Game py tools/read_imported_hulls.py [--clean]        (WorldKit Studio, Edit; execute_luau only, no mouse/keyboard)
Finds every MeshPart whose name or ancestor Model name starts with "Hull_" anywhere in Workspace / ServerStorage, prints MeshId, size, world position and pivot,
writes art/models/worldkit/prop_hull_assets.json {"<Kit>": {"D2_hull_035": "rbxassetid://..", "D2_centre_035": [x,y,z], "import_pos": [..]}} and, with --clean,
destroys the imported instances. D2_centre = the box centre of the OBJ (from build/prop_kit_hull035/<Kit>_D2_035.json D2_center_roblox, or computed from the obj).
If the importer moved the mesh (position != the OBJ box centre) the import_pos is recorded too so the mesh pivot can be matched.
"""
import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402

OUT = os.path.join(ROOT, "art", "models", "worldkit", "prop_hull_assets.json")
LUA = r'''
local out = {}
local function walk(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("MeshPart") then
			local top, cur = nil, d
			while cur and cur ~= root do
				if string.sub(cur.Name, 1, 5) == "Hull_" then top = cur end
				cur = cur.Parent
			end
			if top then
				table.insert(out, { name = top.Name, part = d.Name, id = d.MeshId, size = { d.Size.X, d.Size.Y, d.Size.Z },
					pos = { d.Position.X, d.Position.Y, d.Position.Z }, full = d:GetFullName() })
			end
		end
	end
end
walk(workspace); walk(game:GetService("ServerStorage"))
return "<<<" .. game:GetService("HttpService"):JSONEncode(out) .. ">>>"
'''
CLEAN = r'''
local n = 0
for _, root in ipairs({ workspace, game:GetService("ServerStorage") }) do
	for _, d in ipairs(root:GetChildren()) do
		if string.sub(d.Name, 1, 5) == "Hull_" then d:Destroy() n += 1 end
	end
end
return "destroyed " .. n
'''


def centre_from_obj(kit):
    f = os.path.join(ROOT, "build", "prop_kit_hull035", "%s_D2_035.obj" % kit)
    vs = [[float(x) for x in ln.split()[1:4]] for ln in open(f, encoding="utf-8") if ln.startswith("v ")]
    lo = [min(v[i] for v in vs) for i in range(3)]
    hi = [max(v[i] for v in vs) for i in range(3)]
    return [round((lo[i] + hi[i]) / 2, 4) for i in range(3)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--clean", action="store_true")
    a = ap.parse_args()
    c = Client()
    c.start()
    try:
        r = c.call("execute_luau", {"code": LUA, "datamodel_type": "Edit"})
        txt = "".join(p.get("text", "") for p in r.get("content", []))
        found = json.loads(re.search(r"<<<(.*)>>>", txt, re.S).group(1))
        rec = json.load(open(OUT, encoding="utf-8")) if os.path.exists(OUT) else {}
        for f in found:
            kit = re.sub(r"^Hull_", "", f["name"])
            kit = re.sub(r"_D2_035$", "", kit)
            ctr = centre_from_obj(kit) if os.path.exists(os.path.join(ROOT, "build", "prop_kit_hull035", "%s_D2_035.obj" % kit)) else None
            print(kit, f["id"], "size", [round(x, 3) for x in f["size"]], "pos", [round(x, 3) for x in f["pos"]], "obj centre", ctr, f["full"])
            if f["id"]:
                e = rec.setdefault(kit, {})
                e["D2_hull_035"] = f["id"]
                e["D2_centre_035"] = ctr
                e["import_pos"] = [round(x, 4) for x in f["pos"]]
        with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(rec, fh, ensure_ascii=False, indent=1)
        print(len(found), "hull meshparts found")
        if a.clean and found:
            print(c.call("execute_luau", {"code": CLEAN, "datamodel_type": "Edit"}))
    finally:
        c.close()


if __name__ == "__main__":
    main()
