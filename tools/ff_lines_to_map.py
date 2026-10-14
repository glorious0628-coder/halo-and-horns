"""Compose Firefly pre-signed S3 URLs from compact lines 'label|id|bytes|X-Amz-Date|signature' (the page returns these from
__urlMap with the long constant part cut) -> map.json for tools/ff_fetch.py.  py tools/ff_lines_to_map.py lines.txt map.json"""
import json
import sys

B = "https://pre-signed-firefly-prod.s3-accelerate.amazonaws.com/images/%s?x-resource-length=%s&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIARDA3TX66IYNWUJ27%%2F%s%%2Fus-west-2%%2Fs3%%2Faws4_request&X-Amz-Date=%s&X-Amz-Expires=86400&X-Amz-SignedHeaders=host&X-Amz-Signature=%s"
m = {}
for ln in open(sys.argv[1], encoding="utf-8").read().splitlines():
    if not ln.strip():
        continue
    label, i, n, d, sig = ln.split("|")
    m[label] = B % (i, n, d[:8], d, sig)
json.dump(m, open(sys.argv[2], "w"), indent=0)
print(len(m), "urls")
