"""Find box faces of a part kit that lie in the same plane facing the same way and overlap (이미지 생성 4, 10/12).

Such faces z-fight in Roblox (two colours flicker) and render black in the Cycles previews (PotTulip_B band / post corners,
frame panel corners). Only Block parts; boxes whose axes are not parallel are skipped.

  py tools/prop_kit_coplanar.py [build/prop_kit/<kit>.json ...]   (default: every kit json)
"""
import glob
import json
import os
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EPS = 0.002


def boxes(K):
    out = []
    for p in K["parts"]:
        if p.get("s") != "Block":
            continue
        X, Y = np.array(p["X"], float), np.array(p["Y"], float)
        Z = np.cross(X, Y)
        out.append((p["n"], p.get("m"), np.array(p["p"], float), (X, Y, Z), np.array(p["size"], float) / 2))
    return out


def faces(b):
    n, m, c, ax, h = b
    for i in range(3):
        for s in (-1, 1):
            j, k = [q for q in range(3) if q != i]
            yield ax[i] * s, c + ax[i] * s * h[i], (ax[j], h[j]), (ax[k], h[k])


def overlap(fa, fb):
    na, pa, (ua, hua), (va, hva) = fa
    nb, pb, (ub, hub), (vb, hvb) = fb
    if np.dot(na, nb) < 0.999 or abs(np.dot(pb - pa, na)) > EPS:
        return 0.0
    # B's half extents along A's in-plane axes (B's axes parallel to A's, any order)
    eb = [abs(np.dot(ub, ua)) * hub + abs(np.dot(vb, ua)) * hvb, abs(np.dot(ub, va)) * hub + abs(np.dot(vb, va)) * hvb]
    if min(abs(abs(np.dot(ub, ua)) - 1), abs(abs(np.dot(vb, ua)) - 1)) > 1e-3:
        return 0.0
    d = pb - pa
    ox = min(hua, np.dot(d, ua) + eb[0]) - max(-hua, np.dot(d, ua) - eb[0])
    oy = min(hva, np.dot(d, va) + eb[1]) - max(-hva, np.dot(d, va) - eb[1])
    return ox * oy if ox > EPS and oy > EPS else 0.0


def check(path):
    K = json.load(open(path))
    B = boxes(K)
    hits = []
    if not B:
        return K["name"], hits
    floor = min(b[2][2] - sum(abs(b[3][i][2]) * b[4][i] for i in range(3)) for b in B)
    for i in range(len(B)):
        for j in range(i + 1, len(B)):
            for fa in faces(B[i]):
                if fa[0][2] < -0.99 and abs(fa[1][2] - floor) < 0.003:    # both on the ground: hidden
                    continue
                for fb in faces(B[j]):
                    a = overlap(fa, fb)
                    if a > 0:
                        hits.append((B[i][0], B[i][1], B[j][0], B[j][1], round(a, 4)))
    return K["name"], hits


def main():
    paths = sys.argv[1:] or sorted(p for p in glob.glob(os.path.join(ROOT, "build", "prop_kit", "*.json")) if not os.path.basename(p).startswith("_"))
    tot = 0
    for p in paths:
        name, hits = check(p)
        if not hits:
            continue
        diff = [h for h in hits if h[1] != h[3]]
        tot += len(hits)
        print("%s: %d coplanar overlaps (%d of two materials)" % (name, len(hits), len(diff)))
        for h in (diff or hits)[:8]:
            print("   %s (%s) ~ %s (%s)  area %.4f" % h)
    print("total", tot)


if __name__ == "__main__":
    main()
