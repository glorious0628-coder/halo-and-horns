"""Rebuild CloudFront-signed Tripo model URLs from (label, date, uuid, file, epoch, signature) lines and download.
py tripo_dl.py <lines.txt> <out_dir>
"""
import base64
import json
import os
import sys
import urllib.request

lines, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
for ln in open(lines, encoding="utf-8"):
    p = ln.split()
    if len(p) < 6:
        continue
    label, date, uid, fname, epoch, sig = p[:6]
    res = f"https://tripo-data.rg1.data.tripo3d.com/tripo-studio/{date}/{uid}/{fname}"
    pol = json.dumps({"Statement": [{"Resource": res, "Condition": {"DateLessThan": {"AWS:EpochTime": int(epoch)}}}]},
                     separators=(",", ":"))
    b = base64.b64encode(pol.encode()).decode().replace("+", "-").replace("=", "_").replace("/", "~")
    url = f"{res}?Key-Pair-Id=K1676C64NMVM2J&Policy={b}&Signature={sig}"
    dst = os.path.join(out, label + os.path.splitext(fname)[1])
    try:
        with urllib.request.urlopen(url, timeout=60) as r, open(dst, "wb") as f:
            f.write(r.read())
        print(label, "OK", os.path.getsize(dst))
    except Exception as e:
        print(label, "FAIL", e)
