"""Upload 3D models (and images) to Roblox with the Open Cloud Assets API - no Studio '3D 가져오기' click.

최종 검수 2026-10-13 — NOT RUN YET (waits for the key; the first real upload needs the user's OK). Needs a user-made API key (Creator Hub → Open Cloud → API Keys: Access Permissions "Assets"
Read + Write) in the git-ignored .env:
    ROBLOX_API_KEY=...            (never print it, never commit it, never ask for it in chat)
    ROBLOX_CREATOR_ID=<user id>   (or ROBLOX_GROUP_ID=<group id> for a group-owned asset)

    py tools/roblox_asset_upload.py build/import3d/HaloFlowerPotHQ_Tulip_TU.glb [more files ≤ 10] [--dry-run]

One call = one asset, file ≤ 20 MB. .glb/.gltf/.fbx → assetType Model (a Model container with MeshParts),
.png/.jpg/.bmp/.tga → Decal. Each result goes into art/models/roblox_assets.json {file name: {assetId, at, type}}.
In Studio (Edit, execute_luau): local m = game:GetService("InsertService"):LoadAsset(<assetId>) → the MeshPart(s)
inside give the MeshId to copy into our own MeshPart (then SurfaceAppearance as before).
Moderation rule (AGENTS 1): look at every model/image yourself before uploading, ≤ 10 per run.
"""
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEDGER = os.path.join(ROOT, "art", "models", "roblox_assets.json")
API = "https://apis.roblox.com/assets/v1"
TYPES = {
    ".glb": ("Model", "model/gltf-binary"), ".gltf": ("Model", "model/gltf+json"), ".fbx": ("Model", "model/fbx"),
    ".png": ("Decal", "image/png"), ".jpg": ("Decal", "image/jpeg"), ".jpeg": ("Decal", "image/jpeg"),
    ".bmp": ("Decal", "image/bmp"), ".tga": ("Decal", "image/tga"),
}


def read_env():
    env = {}
    path = os.path.join(ROOT, ".env")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def call(method, url, key, body=None, ctype=None):
    req = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": key})
    if ctype:
        req.add_header("Content-Type", ctype)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.loads(r.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.read().decode('utf-8', 'replace')[:400]}") from None


def multipart(fields, file_field, file_name, file_type, data):
    b = uuid.uuid4().hex
    out = []
    for k, v in fields.items():
        out.append(f'--{b}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode("utf-8"))
    out.append(f'--{b}\r\nContent-Disposition: form-data; name="{file_field}"; filename="{file_name}"\r\n'
               f"Content-Type: {file_type}\r\n\r\n".encode("utf-8") + data + b"\r\n")
    out.append(f"--{b}--\r\n".encode("utf-8"))
    return b"".join(out), f"multipart/form-data; boundary={b}"


def upload(path, key, creator):
    ext = os.path.splitext(path)[1].lower()
    if ext not in TYPES:
        raise RuntimeError(f"unsupported file type {ext}")
    asset_type, file_type = TYPES[ext]
    data = open(path, "rb").read()
    if len(data) > 20 * 1024 * 1024:
        raise RuntimeError(f"{len(data)} bytes > 20 MB (strip textures first: tools/glb_strip_mesh.py)")
    name = os.path.splitext(os.path.basename(path))[0][:50]
    request = {"assetType": asset_type, "displayName": name, "description": "Halo & Horns",
               "creationContext": {"creator": creator}}
    body, ctype = multipart({"request": json.dumps(request)}, "fileContent", os.path.basename(path), file_type, data)
    op = call("POST", f"{API}/assets", key, body, ctype)
    op_id = (op.get("path") or "").split("/")[-1] or op.get("operationId")
    if not op_id:
        raise RuntimeError(f"no operation in reply: {str(op)[:300]}")
    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(2)
        op = call("GET", f"{API}/operations/{op_id}", key)
    if not op.get("done"):
        raise RuntimeError(f"operation {op_id} not done after 120 s")
    if op.get("error"):
        raise RuntimeError(f"operation error: {op['error']}")
    asset_id = (op.get("response") or {}).get("assetId")
    if not asset_id:
        raise RuntimeError(f"no assetId: {str(op)[:300]}")
    return asset_type, str(asset_id)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry-run" in sys.argv
    if not args or len(args) > 10:
        sys.exit("usage: roblox_asset_upload.py <file> [... up to 10] [--dry-run]")
    for p in args:
        if not os.path.isfile(p):
            sys.exit(f"missing file: {p}")
    env = read_env()
    key = env.get("ROBLOX_API_KEY") or os.environ.get("ROBLOX_API_KEY")
    if env.get("ROBLOX_GROUP_ID"):
        creator = {"groupId": env["ROBLOX_GROUP_ID"]}
    elif env.get("ROBLOX_CREATOR_ID"):
        creator = {"userId": env["ROBLOX_CREATOR_ID"]}
    else:
        creator = None
    if dry:
        for p in args:
            ext = os.path.splitext(p)[1].lower()
            print(f"DRY {p} {os.path.getsize(p)} B -> {TYPES.get(ext, ('?', '?'))[0]}")
        print("key:", "set" if key else "MISSING (.env ROBLOX_API_KEY)", "| creator:", creator or "MISSING")
        return
    if not key or not creator:
        sys.exit("ROBLOX_API_KEY and ROBLOX_CREATOR_ID (or ROBLOX_GROUP_ID) must be in .env - a user step")
    ledger = json.load(open(LEDGER, encoding="utf-8")) if os.path.exists(LEDGER) else {}
    failed = 0
    for i, p in enumerate(args):
        if i:
            time.sleep(3)
        try:
            asset_type, asset_id = upload(p, key, creator)
        except Exception as e:  # report and go on with the next file
            failed += 1
            print(f"FAIL {p}: {e}")
            continue
        ledger[os.path.basename(p)] = {"assetId": asset_id, "type": asset_type, "at": time.strftime("%Y-%m-%d %H:%M")}
        print(f"OK {p} -> {asset_type} {asset_id}")
        with open(LEDGER, "w", encoding="utf-8") as f:
            json.dump(ledger, f, ensure_ascii=False, indent=1)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
