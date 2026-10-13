"""Meshy API (docs.meshy.ai) for Halo & Horns - multi-image (4 views) -> 3D, retexture, download, records.

  py tools/meshy_api.py balance
  py tools/meshy_api.py mesh <name> --front F.png --left L.png --right R.png --back B.png [--texture] [--pbr]
                        [--res 2k|4k|8k] [--model latest|meshy-7.1|meshy-6] [--dry-run] [--wait]
  py tools/meshy_api.py retex <name> --task <mesh task id> --front F.png [--left ...] [--res 4k] [--pbr] [--wait]
  py tools/meshy_api.py status <task id> [--kind multi-image-to-3d|retexture]
  py tools/meshy_api.py fetch <task id> --name <name> [--kind ...]   (downloads glb/fbx/thumbnails into art/models/meshy/<name>/)

Key: MESHY_API_KEY in the git-ignored .env (never printed, never in chat). Every create costs credits (A23-160: only after the
user's "go"); `--dry-run` prints the request without the images and sends nothing. Costs (docs 2026-10): multi-image mesh only 20,
with 2K/4K textures 30, 8K 35, +5 for geometry_resolution 2k; retexture 2K/4K 10, 8K 15. FAILED tasks are refunded.
Records: art/models/meshy/records.json  {name: [ {event, task, kind, params, credits, files, at} ]}.
"""
import argparse
import base64
import datetime as dt
import json
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = "https://api.meshy.ai/openapi/v1"
RECORDS = os.path.join(ROOT, "art", "models", "meshy", "records.json")
OUT_DIR = os.path.join(ROOT, "art", "models", "meshy")


def key():
    k = os.environ.get("MESHY_API_KEY", "").strip()
    if not k:
        env = os.path.join(ROOT, ".env")
        if os.path.exists(env):
            for line in open(env, encoding="utf-8", errors="ignore"):
                line = line.strip()
                if line.startswith("MESHY_API_KEY="):
                    k = line.split("=", 1)[1].strip().strip('"').strip("'")
    if not k:
        sys.exit("MESHY_API_KEY not set (.env)")
    return k


def call(method, path, body=None, raw=False):
    req = urllib.request.Request(BASE + path, method=method)
    req.add_header("Authorization", "Bearer " + key())
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, data=data, timeout=120) as r:
            txt = r.read()
            retry = r.headers.get("Retry-After")
            return (json.loads(txt) if not raw else txt), retry
    except urllib.error.HTTPError as e:
        msg = e.read().decode("utf-8", "ignore")
        if "Bearer" in msg:
            msg = "<redacted>"
        sys.exit("HTTP %d %s: %s" % (e.code, path, msg[:400]))


def data_uri(path):
    ext = os.path.splitext(path)[1].lower().lstrip(".")
    mime = {"jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png", "webp": "image/webp"}.get(ext)
    if not mime:
        sys.exit("unsupported image: " + path)
    b = open(path, "rb").read()
    if len(b) > 20 * 1024 * 1024:
        sys.exit("image over 20 MB: " + path)
    return "data:%s;base64,%s" % (mime, base64.b64encode(b).decode("ascii"))


def record(name, entry):
    os.makedirs(os.path.dirname(RECORDS), exist_ok=True)
    d = {}
    if os.path.exists(RECORDS):
        d = json.load(open(RECORDS, encoding="utf-8"))
    entry["at"] = dt.datetime.now().strftime("%Y-%m-%d %H:%M")
    d.setdefault(name, []).append(entry)
    json.dump(d, open(RECORDS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


def wait_task(kind, task):
    while True:
        j, retry = call("GET", "/%s/%s" % (kind, task))
        st = j.get("status")
        print("  %s %s%%" % (st, j.get("progress")))
        if st in ("SUCCEEDED", "FAILED", "CANCELED"):
            return j
        time.sleep(max(3, int(retry) if retry and str(retry).isdigit() else 8))


def fetch_files(j, name):
    d = os.path.join(OUT_DIR, name)
    os.makedirs(d, exist_ok=True)
    files = []
    urls = dict(j.get("model_urls") or {})
    for k in ("glb", "fbx"):
        if urls.get(k):
            p = os.path.join(d, "%s_%s.%s" % (name, j.get("id", "")[:8], k))
            _dl(urls[k], p)
            files.append(os.path.relpath(p, ROOT))
    th = j.get("thumbnail_urls") or {}
    for k, u in th.items():
        p = os.path.join(d, "%s_%s_thumb_%s.png" % (name, j.get("id", "")[:8], k))
        _dl(u, p)
        files.append(os.path.relpath(p, ROOT))
    if j.get("thumbnail_url") and not th:
        p = os.path.join(d, "%s_%s_thumb.png" % (name, j.get("id", "")[:8]))
        _dl(j["thumbnail_url"], p)
        files.append(os.path.relpath(p, ROOT))
    for i, t in enumerate(j.get("texture_urls") or []):
        for k, u in t.items():
            p = os.path.join(d, "%s_%s_tex%d_%s.png" % (name, j.get("id", "")[:8], i, k))
            _dl(u, p)
            files.append(os.path.relpath(p, ROOT))
    return files


def _dl(url, path):
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=600) as r, open(path, "wb") as f:
        while True:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
    print("  saved", os.path.relpath(path, ROOT), os.path.getsize(path))


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("balance")
    m = sub.add_parser("mesh")
    m.add_argument("name")
    m.add_argument("--front", required=True)
    m.add_argument("--left")
    m.add_argument("--right")
    m.add_argument("--back")
    m.add_argument("--texture", action="store_true", help="texture in the same task (else mesh only, retex later)")
    m.add_argument("--pbr", action="store_true")
    m.add_argument("--res", default="4k", choices=["2k", "4k", "8k"])
    m.add_argument("--model", default="latest")
    m.add_argument("--geo", default="standard", choices=["standard", "2k"])
    m.add_argument("--pose", default="", help="'' | a-pose | t-pose (people)")
    m.add_argument("--dry-run", action="store_true")
    m.add_argument("--wait", action="store_true")
    r = sub.add_parser("retex")
    r.add_argument("name")
    r.add_argument("--task", required=True, help="SUCCEEDED multi-image-to-3d task id")
    r.add_argument("--front", required=True)
    r.add_argument("--left")
    r.add_argument("--right")
    r.add_argument("--back")
    r.add_argument("--pbr", action="store_true")
    r.add_argument("--res", default="4k", choices=["2k", "4k", "8k"])
    r.add_argument("--dry-run", action="store_true")
    r.add_argument("--wait", action="store_true")
    s = sub.add_parser("status")
    s.add_argument("task")
    s.add_argument("--kind", default="multi-image-to-3d")
    f = sub.add_parser("fetch")
    f.add_argument("task")
    f.add_argument("--name", required=True)
    f.add_argument("--kind", default="multi-image-to-3d")
    a = ap.parse_args()

    if a.cmd == "balance":
        j, _ = call("GET", "/balance")
        print(json.dumps(j, ensure_ascii=False))
        return
    if a.cmd == "status":
        j, _ = call("GET", "/%s/%s" % (a.kind, a.task))
        j.pop("model_urls", None)
        print(json.dumps(j, ensure_ascii=False, indent=1)[:3000])
        return
    if a.cmd == "fetch":
        j, _ = call("GET", "/%s/%s" % (a.kind, a.task))
        if j.get("status") != "SUCCEEDED":
            sys.exit("task is " + str(j.get("status")))
        files = fetch_files(j, a.name)
        record(a.name, {"event": "fetch", "task": a.task, "kind": a.kind, "files": files, "credits": j.get("consumed_credits")})
        return

    views = [p for p in (a.front, a.left, a.right, a.back) if p]
    for p in views:
        if not os.path.exists(p):
            sys.exit("missing image: " + p)
    if a.cmd == "mesh":
        body = {
            "image_urls": ["<%s>" % p for p in views],
            "ai_model": a.model,
            "geometry_resolution": a.geo,
            "should_texture": bool(a.texture),
            "should_remesh": False,
            "target_formats": ["glb", "fbx"],
            "multi_view_thumbnails": True,
            "moderation": True,
        }
        if a.texture:
            body["enable_pbr"] = bool(a.pbr)
            body["texture_resolution"] = a.res
            body["texture_image_urls"] = ["<%s>" % p for p in views]
        if a.pose:
            body["pose_mode"] = a.pose
        kind = "multi-image-to-3d"
        est = (30 if a.res in ("2k", "4k") else 35) if a.texture else 20
        if a.geo == "2k":
            est += 5
    else:
        body = {
            "input_task_id": a.task,
            "enable_pbr": bool(a.pbr),
            "texture_resolution": a.res,
            "multiview_image_urls": ["<%s>" % p for p in views],  # docs: 1-4 images, first = front, needs meshy-7
            "ai_model": "meshy-7",
            "enable_original_uv": True,
            "target_formats": ["glb", "fbx"],
        }
        kind = "retexture"
        est = 10 if a.res in ("2k", "4k") else 15
    print("POST /%s  est. credits %d" % (kind, est))
    print(json.dumps(body, ensure_ascii=False, indent=1))
    if a.dry_run:
        print("dry-run: nothing sent")
        return
    real = dict(body)
    if "image_urls" in real:
        real["image_urls"] = [data_uri(p) for p in views]
    if "texture_image_urls" in real:
        real["texture_image_urls"] = [data_uri(p) for p in views]
    if "multiview_image_urls" in real:
        real["multiview_image_urls"] = [data_uri(p) for p in views]
    j, _ = call("POST", "/" + kind, real)
    task = j.get("result")
    print("task", task)
    record(a.name, {"event": "create", "task": task, "kind": kind, "params": body, "credits_est": est})
    if a.wait:
        j = wait_task(kind, task)
        if j.get("status") == "SUCCEEDED":
            files = fetch_files(j, a.name)
            record(a.name, {"event": "done", "task": task, "kind": kind, "files": files, "credits": j.get("consumed_credits")})
        else:
            record(a.name, {"event": j.get("status"), "task": task, "kind": kind, "error": (j.get("task_error") or {}).get("message")})
            print("task", j.get("status"), (j.get("task_error") or {}).get("message"))


if __name__ == "__main__":
    main()
