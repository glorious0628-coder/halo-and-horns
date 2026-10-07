"""Put a High re-render on the same canvas as the in-game Medium file it replaces (key and Size stay the same).

py hq_fit.py <old art/ui png> <new src png> <out png> --mode keep|icon|opaque [--max-diff 0.03] [-- <cut options>]
- keep:   tools/img2/cut_keep.py <src> --long <old longest side> <cut options>, then resize to the old canvas
          when the aspect differs by <= --max-diff (else keep the new size and say so).
- icon:   tools/img2/cut_icon.py <src> --size <old side> <cut options> (square round buttons / rings).
- opaque: no cutout (maps, parchment); resize the whole image to the old canvas.
Prints old/new size, aspect difference and the alpha overlap (IoU) with the old file, so a moved or reshaped part shows up.
"""
import argparse
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))


def iou(a, b):
    ma = np.asarray(a.getchannel("A")) > 128
    mb = np.asarray(b.getchannel("A")) > 128
    u = (ma | mb).sum()
    return float((ma & mb).sum()) / u if u else 1.0


def main():
    argv = sys.argv[1:]
    extra = []
    if "--" in argv:
        i = argv.index("--")
        argv, extra = argv[:i], argv[i + 1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("old")
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--mode", choices=["keep", "icon", "opaque"], default="keep")
    ap.add_argument("--max-diff", type=float, default=0.03)
    a = ap.parse_args(argv)

    old = Image.open(a.old)
    ow, oh = old.size
    if a.mode == "opaque":
        new = Image.open(a.src).convert("RGB").resize((ow, oh), Image.LANCZOS)
        new.save(a.out)
        print(f"{os.path.basename(a.out)} opaque {Image.open(a.src).size} -> {new.size}")
        return

    tmp = os.path.join(tempfile.gettempdir(), "hq_fit_tmp.png")
    if a.mode == "keep":
        cmd = [sys.executable, os.path.join(HERE, "cut_keep.py"), a.src, tmp, "--long", str(max(ow, oh))] + extra
    else:
        cmd = [sys.executable, os.path.join(HERE, "cut_icon.py"), a.src, tmp, "--size", str(max(ow, oh))] + extra
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout, r.stderr)
        sys.exit(1)
    new = Image.open(tmp).convert("RGBA")
    nw, nh = new.size
    diff = abs((nw / nh) / (ow / oh) - 1)
    note = "same canvas"
    if (nw, nh) != (ow, oh):
        if diff <= a.max_diff:
            new = new.resize((ow, oh), Image.LANCZOS)
            note = f"resized {nw}x{nh} -> {ow}x{oh}"
        else:
            note = f"KEPT NEW SIZE {nw}x{nh} (aspect differs {diff:.1%})"
    new.save(a.out)
    o = old.convert("RGBA")
    score = iou(o, new) if new.size == o.size else float("nan")
    print(f"{os.path.basename(a.out)} old {ow}x{oh} new {nw}x{nh} aspect diff {diff:.2%} -> {note}; alpha IoU vs old {score:.3f}")


if __name__ == "__main__":
    main()
