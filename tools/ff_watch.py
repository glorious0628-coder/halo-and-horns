"""Rename Firefly auto-downloads (Downloads\*.tmp, random names) to target files in generation order (이미지 생성 2, 10/13).
Usage: py tools/ff_watch.py <targets.json> [--downloads <dir>]   targets.json = JSON list of destination PNG paths in the exact
order the page (tools/firefly_autodl_helpers.js) downloads them. Only ONE session may generate/watch at a time (same Downloads
folder). Waits until a .tmp is >100 KB and its size stopped changing, then moves it to the next target; logs to
<targets.json>.log; ends when every target is filled. Check every file by eye afterwards (a missed/duplicated download shifts the order)."""
import glob
import json
import os
import shutil
import sys
import time

targets = json.load(open(sys.argv[1], encoding="utf-8"))
dl = sys.argv[sys.argv.index("--downloads") + 1] if "--downloads" in sys.argv else os.path.join(os.path.expanduser("~"), "Downloads")
log = sys.argv[1] + ".log"
i = 0
sizes = {}
while i < len(targets):
    for f in sorted(glob.glob(os.path.join(dl, "*.tmp")), key=os.path.getmtime):
        s = os.path.getsize(f)
        if s > 100000 and sizes.get(f) == s:
            os.makedirs(os.path.dirname(targets[i]), exist_ok=True)
            shutil.move(f, targets[i])
            open(log, "a", encoding="utf-8").write("%s -> %s (%d)\n" % (os.path.basename(f), targets[i], s))
            i += 1
            sizes.pop(f, None)
            if i >= len(targets):
                break
        else:
            sizes[f] = s
    time.sleep(5)
open(log, "a").write("ALL DONE\n")
