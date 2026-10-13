"""Fetch Firefly results from pre-signed S3 URLs straight into the project (no browser download, no desktop window).
Usage: py tools/ff_fetch.py <map.json> [--out <dir>] [--pattern "HaloChunk_{label}_ns.png"]
map.json = {"<label>": "<pre-signed url>", ...} from the page's __urlMap(); label like 'MedalBell_back'.
Checks the PNG header and the x-resource-length size. Files that exist are skipped."""
import json
import os
import re
import subprocess
import sys

m = json.load(open(sys.argv[1], encoding="utf-8"))
out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "."
pat = sys.argv[sys.argv.index("--pattern") + 1] if "--pattern" in sys.argv else "{label}.png"
for label, url in m.items():
    dst = os.path.join(out, pat.format(label=label))
    if os.path.exists(dst):
        print("skip", dst); continue
    os.makedirs(os.path.dirname(dst) or ".", exist_ok=True)
    r = subprocess.run(["curl", "-s", "-L", "-o", dst, "-w", "%{http_code}", url], capture_output=True, text=True)
    want = int((re.search(r"x-resource-length=(\d+)", url) or [0, 0])[1])
    ok = r.stdout.strip() == "200" and os.path.getsize(dst) == want and open(dst, "rb").read(8) == b"\x89PNG\r\n\x1a\n"
    print(label, r.stdout.strip(), os.path.getsize(dst), "OK" if ok else "BAD")
    if not ok:
        os.remove(dst)
