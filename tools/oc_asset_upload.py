"""oc_asset_upload.py : upload FBX models to Roblox with the Open Cloud Assets API (key in .env ROBLOX_OPENCLOUD_KEY,
needs the key permission 'asset:read' + 'asset:write' for the user/group that owns the game).

  py tools/oc_asset_upload.py --manifest art/models/tripo/weapons/weapons_fit_manifest.json --creator-user <userId>
                              [--only NAME,NAME] [--out build/weapon_model_ids.json]

POST https://apis.roblox.com/assets/v1/assets (multipart: request JSON + fileContent) -> operation -> poll
GET  https://apis.roblox.com/assets/v1/operations/{id} -> response.assetId (a Model asset). The MeshId/TextureId inside
are read in Studio afterwards (InsertService:LoadAsset -> MeshPart.MeshId / TextureID) by 메인 반영 1 via MCP.
Prints counts/ids only, never the key.
"""
import argparse
import json
import os
import sys
import time
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://apis.roblox.com/assets/v1"


def key():
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        if line.startswith("ROBLOX_OPENCLOUD_KEY="):
            return line.split("=", 1)[1].strip().strip('"')
    sys.exit("no ROBLOX_OPENCLOUD_KEY in .env")


def upload(k, fbx, name, creator_user, creator_group):
    creator = {"userId": creator_user} if creator_user else {"groupId": creator_group}
    req = {"assetType": "Model", "displayName": name[:50], "description": "Halo & Horns weapon (Tripo HD, Blender fit)",
           "creationContext": {"creator": creator}}
    with open(fbx, "rb") as fh:
        r = requests.post(f"{BASE}/assets", headers={"x-api-key": k},
                          files={"request": (None, json.dumps(req), "application/json"),
                                 "fileContent": (os.path.basename(fbx), fh, "model/fbx")}, timeout=300)
    if r.status_code != 200:
        return None, f"HTTP {r.status_code} {r.text[:200]}"
    op = r.json()
    for _ in range(60):
        time.sleep(3)
        g = requests.get(f"{BASE}/operations/{op['operationId']}", headers={"x-api-key": k}, timeout=60)
        if g.status_code != 200:
            return None, f"poll HTTP {g.status_code} {g.text[:160]}"
        j = g.json()
        if j.get("done"):
            if "error" in j:
                return None, str(j["error"])[:200]
            return j["response"]["assetId"], None
    return None, "timeout"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--creator-user", type=int)
    ap.add_argument("--creator-group", type=int)
    ap.add_argument("--only")
    ap.add_argument("--out", default="build/weapon_model_ids.json")
    a = ap.parse_args()
    k = key()
    m = json.load(open(ROOT / a.manifest, encoding="utf-8"))
    only = set(a.only.split(",")) if a.only else None
    out_p = ROOT / a.out
    out = json.load(open(out_p, encoding="utf-8")) if out_p.exists() else {}
    ok = fail = 0
    for w in m["weapons"]:
        if only and w["name"] not in only:
            continue
        if w["name"] in out and out[w["name"]].get("ModelId"):
            continue
        fbx = ROOT / (w["glb"][:-4] + ".fbx")
        if not fbx.exists():
            print(f"{w['name']}: no fbx"); fail += 1; continue
        aid, err = upload(k, str(fbx), w["name"], a.creator_user, a.creator_group)
        if aid:
            out[w["name"]] = {"ModelId": aid, "fbx": str(fbx.relative_to(ROOT))}
            ok += 1
            print(f"{w['name']}: model {aid}")
        else:
            fail += 1
            print(f"{w['name']}: FAIL {err}")
        out_p.parent.mkdir(parents=True, exist_ok=True)
        json.dump(out, open(out_p, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"done ok {ok} failed {fail} -> {a.out}")


if __name__ == "__main__":
    main()
