"""Upload SurfaceAppearance maps (<name>_C / _N / _M / _R .png in one folder) to Roblox in batches of 10 through a
practice Studio's MCP upload_image; ids -> art/ui/asset_ids.json as SA_<name>_<T>. 이미지 개발 2026-10-10 (the
crossroads run, made general for 이미지 생성 3's Halo town bundles).

  py tools/upload_sa_maps.py <folder> [--names A,B] [--tags NMR] [--port 8766] [--pause 20] [--dry] [--replace]
--tags: which maps (default NMR: the colour stays the game's own, decision (a) - a new colour map greys the whole SA
while it waits for moderation; pass CNMR for models that are not in the game yet). Already recorded keys are skipped.
STUDIO_NAME must name a practice Studio (default UiSandbox). Never uploads from art/out/v1 (Hard rule 1).
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IDS = os.path.join(ROOT, "art", "ui", "asset_ids.json")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("--names", default="", help="model names (default: every <name>_N.png in the folder)")
    ap.add_argument("--tags", default="NMR")
    ap.add_argument("--port", type=int, default=8766)
    ap.add_argument("--pause", type=float, default=20.0, help="seconds between batches")
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--stale-from", help="with --replace: only keys whose id still equals the one in this older "
                    "asset_ids copy (resume a stopped replace run without uploading the done ones again)")
    ap.add_argument("--replace", action="store_true", help="upload again even when SA_<name>_<T> is recorded (rebaked maps; "
                    "the old id is overwritten in asset_ids, the old one is printed)")
    a = ap.parse_args()
    folder = os.path.abspath(a.folder)
    if "art" + os.sep + "out" + os.sep + "v1" in folder:
        raise SystemExit("never upload from art/out/v1 (AGENTS.md Hard rule 1)")
    os.environ.setdefault("STUDIO_NAME", "UiSandbox")
    if re.search(r"GoodEvil|81671223175574", os.environ["STUDIO_NAME"]):
        raise SystemExit("practice Studio only")
    names = [n for n in a.names.split(",") if n] or sorted(f[:-6] for f in os.listdir(folder) if f.endswith("_N.png"))
    files = [f"{n}_{t}.png" for n in names for t in a.tags if os.path.isfile(os.path.join(folder, f"{n}_{t}.png"))]
    with open(IDS, encoding="utf-8") as f:
        ids = json.load(f)
    stale = None
    if a.stale_from:
        with open(a.stale_from, encoding="utf-8") as f:
            stale = json.load(f)
    todo = [f for f in files if "SA_" + f[:-4] not in ids or (a.replace and (stale is None
            or ids.get("SA_" + f[:-4]) == stale.get("SA_" + f[:-4])))]
    if a.replace:
        for f in todo:
            if "SA_" + f[:-4] in ids:
                print("  replaces", "SA_" + f[:-4], ids["SA_" + f[:-4]])
    print(len(names), "models,", len(files), "files,", len(todo), "to upload")
    if a.dry or not todo:
        return
    import socket
    import urllib.request
    port = a.port
    with socket.socket() as sk:  # a port someone else's server holds would serve the wrong folder (10/10: 64 fails)
        if sk.connect_ex(("127.0.0.1", port)) == 0:
            with socket.socket() as free:
                free.bind(("127.0.0.1", 0))
                port = free.getsockname()[1]
            print("port", a.port, "is busy - using", port)
    srv = subprocess.Popen([sys.executable, "-m", "http.server", str(port), "--bind", "127.0.0.1"], cwd=folder,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    base = f"http://127.0.0.1:{port}/"
    try:
        served = False
        for _ in range(40):  # the file must come back (200) from THIS folder before any upload
            try:
                with urllib.request.urlopen(base + todo[0], timeout=2) as r:
                    served = r.status == 200
                if served:
                    break
            except Exception:  # noqa: BLE001
                time.sleep(0.5)
        if not served:
            raise SystemExit(f"the local server does not serve {todo[0]} - nothing uploaded")
        for i in range(0, len(todo), 10):
            batch = todo[i:i + 10]
            arg = json.dumps({"imagePaths": [base + f for f in batch]})
            r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "studio_mcp.py"), "call", "upload_image", arg],
                               capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=900)
            out = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
            try:
                res = json.loads(out)
            except ValueError:
                print("batch", i // 10 + 1, "bad output:", (r.stdout + r.stderr)[-800:])
                break
            with open(IDS, encoding="utf-8") as f:  # re-read: other sessions write this file too
                ids = json.load(f)
            ok = 0
            for f in batch:
                v = res.get(base + f)
                if isinstance(v, str) and re.match(r"^rbxassetid://\d+$", v):
                    ids["SA_" + f[:-4]] = v
                    ok += 1
                else:
                    print("  fail", f, v)
            with open(IDS, "w", encoding="utf-8", newline="\n") as fh:
                json.dump(ids, fh, ensure_ascii=False, indent=2)
                fh.write("\n")
            print("batch", i // 10 + 1, ok, "/", len(batch), flush=True)
            if i + 10 < len(todo):
                time.sleep(a.pause)
    finally:
        srv.terminate()
        try:
            srv.wait(5)
        except subprocess.TimeoutExpired:
            srv.kill()


if __name__ == "__main__":
    main()
