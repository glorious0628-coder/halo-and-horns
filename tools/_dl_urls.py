"""py tools/_dl_urls.py <dir> <prefix> : reads <dir>/urls.txt ('name token' per line), downloads https://at.adobe.com/<token> to <dir>/<prefix>_<name>.png"""
import subprocess, sys
from pathlib import Path
d = Path(sys.argv[1]); pre = sys.argv[2]
for l in (d / "urls.txt").read_text().splitlines():
    if l.strip():
        n, t = l.split()
        subprocess.run(["curl", "-s", "-L", "-o", str(d / f"{pre}_{n}.png"), "https://at.adobe.com/" + t])
from PIL import Image
for f in sorted(d.glob("*.png")):
    try:
        im = Image.open(f); im.load(); print(f.name, im.size)
    except Exception as e:
        print("BAD", f.name)
