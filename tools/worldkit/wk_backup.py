"""wk_backup.py (이미지 생성 1, 2026-10-11): back up / restore the WorldKit Studio WITHOUT the mouse or keyboard (최종 검수 10/11:
the PC lost power and the unsaved WorldKit work was gone). Studio's Ctrl+S needs the keyboard, so instead every top-level
child of Workspace (not Terrain / Camera), ServerStorage, ReplicatedStorage, MaterialService and Lighting is serialized
in Studio with SerializationService (binary .rbxm, the same format Studio's "Save to File" writes), plus the whole
Terrain as a TerrainRegion, and copied out through execute_luau as base64 chunks (Edit mode, STUDIO_NAME=WorldKit).

usage:
  py tools/worldkit/wk_backup.py save [--only Workspace.HaloV2,ServerStorage.ImportHold] [--no-terrain]
        -> build/wk_backup/<YYYYMMDD_HHMMSS>/<n>_<Parent>.<Name>.rbxm + terrain.rbxm + manifest.json (build/ is git-ignored)
  py tools/worldkit/wk_backup.py list
  py tools/worldkit/wk_backup.py load <stamp|latest> [--only names] [--replace] [--terrain] [--check]
        --replace: an existing child with the same name under the same parent is destroyed first (else skipped)
        --terrain: paste the saved Terrain back (overwrites the region)
        --check:   deserialize into ServerStorage._WKBackupCheck, count, destroy (nothing changes)
Each .rbxm can also be opened by hand in Studio (Insert > from file)."""
import base64
import datetime
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "build", "wk_backup")
CHUNK = 90_000  # base64 chars per execute_luau round trip (the MCP output is cut at 100k chars)
env = dict(os.environ, STUDIO_NAME="WorldKit")

B64 = r'''
local A = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local E, DEC = {}, {}
for i = 1, 64 do E[i - 1] = string.byte(A, i) DEC[string.byte(A, i)] = i - 1 end
local function enc(b)
	local n = buffer.len(b)
	local out = buffer.create(math.ceil(n / 3) * 4)
	local o = 0
	for i = 0, n - 1, 3 do
		local a, c, d = buffer.readu8(b, i), i + 1 < n and buffer.readu8(b, i + 1) or 0, i + 2 < n and buffer.readu8(b, i + 2) or 0
		local v = a * 65536 + c * 256 + d
		buffer.writeu8(out, o, E[bit32.rshift(v, 18)])
		buffer.writeu8(out, o + 1, E[bit32.band(bit32.rshift(v, 12), 63)])
		buffer.writeu8(out, o + 2, i + 1 < n and E[bit32.band(bit32.rshift(v, 6), 63)] or 61)
		buffer.writeu8(out, o + 3, i + 2 < n and E[bit32.band(v, 63)] or 61)
		o += 4
	end
	return buffer.tostring(out)
end
local function dec(s)
	local n = #s
	local pad = (string.sub(s, -2) == "==") and 2 or ((string.sub(s, -1) == "=") and 1 or 0)
	local out = buffer.create(n // 4 * 3 - pad)
	local o = 0
	for i = 1, n, 4 do
		local a, b2, c, d = string.byte(s, i, i + 3)
		local v = DEC[a] * 262144 + DEC[b2] * 4096 + (DEC[c] or 0) * 64 + (DEC[d] or 0)
		buffer.writeu8(out, o, bit32.rshift(v, 16))
		if o + 1 < buffer.len(out) then buffer.writeu8(out, o + 1, bit32.band(bit32.rshift(v, 8), 255)) end
		if o + 2 < buffer.len(out) then buffer.writeu8(out, o + 2, bit32.band(v, 255)) end
		o += 3
	end
	return out
end
'''

GUARD = 'if string.find(game.Name, "GoodEvil") or game.PlaceId == 81671223175574 then error("main Studio: WorldKit only") end\n'


def luau(code):
    p = os.path.join(os.environ["TEMP"], "wk_backup_arg.json")
    json.dump({"code": GUARD + code, "datamodel_type": "Edit"}, open(p, "w", encoding="utf-8"), ensure_ascii=False)
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "studio_mcp.py"), "call", "execute_luau", "@" + p],
                       env=env, capture_output=True, text=True, encoding="utf-8", cwd=ROOT)
    out = (r.stdout or "").strip()
    if "<<<" not in out:
        raise SystemExit("execute_luau failed: " + (out[-600:] or r.stderr[-600:]))
    return out[out.index("<<<") + 3:out.rindex(">>>")]


def save(only, terrain):
    sel = json.dumps(only or [])
    meta = luau(B64 + r'''
local ss = game:GetService("SerializationService")
local HS = game:GetService("HttpService")
local only = HS:JSONDecode([==[''' + sel + r''']==])
local want = {}
for _, n in only do want[n] = true end
local roots = {}
for _, c in workspace:GetChildren() do
	if not c:IsA("Terrain") and not c:IsA("Camera") then table.insert(roots, c) end
end
for _, n in { "ServerStorage", "ReplicatedStorage", "MaterialService", "Lighting" } do
	for _, c in game:GetService(n):GetChildren() do
		if c.Name ~= "_WKBackupCheck" then table.insert(roots, c) end
	end
end
shared.WKB = {}
local items, errs = {}, {}
for _, r in roots do
	local key = r.Parent.Name .. "." .. r.Name
	if #only == 0 or want[key] then
		local ok, buf = pcall(function() return ss:SerializeInstancesAsync({ r }) end)
		if ok then
			local s = enc(buf)
			table.insert(shared.WKB, s)
			table.insert(items, { parent = r.Parent == workspace and "Workspace" or r.Parent.ClassName, name = r.Name, class = r.ClassName,
				bytes = buffer.len(buf), b64 = #s, n = #r:GetDescendants() + 1 })
		else
			table.insert(errs, key .. ": " .. tostring(buf))
		end
	end
end
local ter = nil
if ''' + ("true" if terrain else "false") + r''' then
	local t = workspace.Terrain
	local reg = t:CopyRegion(t.MaxExtents)
	local buf = ss:SerializeInstancesAsync({ reg })
	local s = enc(buf)
	table.insert(shared.WKB, s)
	local mn = t.MaxExtents.Min
	ter = { corner = { mn.X, mn.Y, mn.Z }, bytes = buffer.len(buf), b64 = #s }
end
return "<<<" .. HS:JSONEncode({ items = items, terrain = ter, errors = errs, place = game.Name }) .. ">>>"
''')
    m = json.loads(meta)
    m.setdefault("terrain", None)  # 이미지 개발 10/11: --no-terrain left the key out (Luau nil) -> KeyError before the manifest
    m.setdefault("errors", [])
    if not isinstance(m.get("items"), list):
        m["items"] = []
    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    d = os.path.join(OUT, stamp)
    os.makedirs(d, exist_ok=True)
    blobs = list(m["items"]) + ([dict(m["terrain"], name="terrain")] if m["terrain"] else [])
    for k, it in enumerate(blobs):
        parts = []
        got = 0
        while got < it["b64"]:
            parts.append(luau('return "<<<" .. string.sub(shared.WKB[%d], %d, %d) .. ">>>"' % (k + 1, got + 1, got + CHUNK)))
            got += len(parts[-1])
            if not parts[-1]:
                raise SystemExit("empty chunk at %s" % it["name"])
        raw = base64.b64decode("".join(parts))
        if len(raw) != it["bytes"]:
            raise SystemExit("size mismatch %s: %d != %d" % (it["name"], len(raw), it["bytes"]))
        fn = "terrain.rbxm" if k == len(m["items"]) else "%02d_%s.%s.rbxm" % (k, it["parent"], it["name"])
        open(os.path.join(d, fn), "wb").write(raw)
        it["file"] = fn
        print("  %-48s %8d KB" % (fn, len(raw) // 1024))
    luau('shared.WKB = nil return "<<<ok>>>"')
    if m["terrain"]:
        m["terrain"]["file"] = "terrain.rbxm"
    json.dump(dict(stamp=stamp, place=m["place"], items=m["items"], terrain=m["terrain"], errors=m["errors"]),
              open(os.path.join(d, "manifest.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("[wk_backup] saved %d roots%s -> %s (%d KB), errors %d" % (len(m["items"]), " + terrain" if m["terrain"] else "", d,
          sum(os.path.getsize(os.path.join(d, f)) for f in os.listdir(d)) // 1024, len(m["errors"])))
    for e in m["errors"]:
        print("  ERROR", e)


def pick(stamp):
    # only finished backups (a folder without manifest.json is a failed / hand-made one)
    st = sorted(s for s in os.listdir(OUT) if os.path.exists(os.path.join(OUT, s, "manifest.json"))) if os.path.isdir(OUT) else []
    if not st:
        raise SystemExit("no backups in " + OUT)
    return os.path.join(OUT, st[-1] if stamp == "latest" else stamp)


def load(stamp, only, replace, terrain, check):
    d = pick(stamp)
    man = json.load(open(os.path.join(d, "manifest.json"), encoding="utf-8"))
    todo = [it for it in man["items"] if not only or "%s.%s" % (it["parent"], it["name"]) in only]
    if terrain and man.get("terrain"):
        todo.append(dict(man["terrain"], name="terrain", parent="Terrain"))
    luau('shared.WKB = nil return "<<<ok>>>"')
    seen = set()
    for it in todo:
        # --replace: the FIRST item of a (parent, name) clears every old child of that name; later items with the same name
        # (Workspace had 6 "Scene" models) are added beside it, never destroying the one just loaded
        key = (it["parent"], it["name"])
        mode = ("replace" if key not in seen else "add") if replace else "skip"
        seen.add(key)
        s = base64.b64encode(open(os.path.join(d, it["file"]), "rb").read()).decode()
        luau('shared.WKB = {} return "<<<ok>>>"')
        for i in range(0, len(s), CHUNK):
            luau('table.insert(shared.WKB, "%s") return "<<<ok>>>"' % s[i:i + CHUNK])
        res = luau(B64 + r'''
local ss = game:GetService("SerializationService")
local list = ss:DeserializeInstancesAsync(dec(table.concat(shared.WKB)))
shared.WKB = nil
local inst = list[1]
local par = "''' + it["parent"] + r'''"
local name = "''' + it["name"].replace('"', '\\"') + r'''"
if ''' + ("true" if check else "false") + r''' then
	local f = Instance.new("Folder") f.Name = "_WKBackupCheck" f.Parent = game:GetService("ServerStorage")
	inst.Parent = f
	local n = #inst:GetDescendants() + 1
	f:Destroy()
	return "<<<check " .. name .. " " .. n .. ">>>"
end
if par == "Terrain" then
	local c = { ''' + ", ".join(str(v) for v in (it.get("corner") or [0, 0, 0])) + r''' }
	workspace.Terrain:PasteRegion(inst, Vector3int16.new(c[1], c[2], c[3]), true)
	return "<<<terrain pasted>>>"
end
local P = par == "Workspace" and workspace or game:GetService(par)
local mode = "''' + mode + r'''"
if mode == "replace" then
	for _, c in P:GetChildren() do if c.Name == name then c:Destroy() end end
elseif mode == "skip" and P:FindFirstChild(name) then
	inst:Destroy()
	return "<<<skip " .. name .. " (exists)>>>"
end
inst.Parent = P
return "<<<loaded " .. par .. "." .. name .. " " .. (#inst:GetDescendants() + 1) .. ">>>"
''')
        print(" ", res, "(saved n=%s)" % it.get("n", "-"))


def main():
    a = sys.argv[1:]
    if not a or a[0] not in ("save", "load", "list"):
        print(__doc__)
        return
    only = []
    if "--only" in a:
        only = [s for s in a[a.index("--only") + 1].split(",") if s]
    if a[0] == "save":
        save(only, "--no-terrain" not in a)
    elif a[0] == "list":
        for s in sorted(os.listdir(OUT)) if os.path.isdir(OUT) else []:
            if not os.path.exists(os.path.join(OUT, s, "manifest.json")):
                print(s, "(no manifest: not a finished backup)")
                continue
            m = json.load(open(os.path.join(OUT, s, "manifest.json"), encoding="utf-8"))
            print(s, len(m["items"]), "roots", "+ terrain" if m.get("terrain") else "")
    else:
        load(a[1] if len(a) > 1 and not a[1].startswith("--") else "latest", only, "--replace" in a, "--terrain" in a, "--check" in a)


if __name__ == "__main__":
    main()
