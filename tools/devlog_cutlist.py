"""
컷 목록·겹침·정지 검사 (검수 2026-10-08 v6 → v7 기준: "같은 원본 구간은 영상에서 한 번만", 정지 1.5초 넘으면 불합격).

  py tools/devlog_cutlist.py build/devlog/shorts01/short01_ai_team

입력: <폴더>/cuts.json (tools/devlog_build.py 가 씀), <폴더>/final.mp4
출력: <폴더>/cutlist.md — 컷 표(영상 시작·끝, 원본 파일·구간, 무엇) + 검사 결과
      <폴더>/dupes.png  — 서로 가장 닮은 컷 쌍(다른 컷끼리) 8개를 나란히(눈으로 확인)
검사:
  1) 원본 구간 겹침: 같은 원본을 쓰는 두 컷의 구간이 0.2초 넘게 겹치면 실패
  2) 모든 프레임 쌍: 컷마다(들어오는 전환 0.25초 빼고) 초당 6장을 뽑아, 다른 컷의 모든 프레임과 pHash(64비트)·색 MAD(16×9)를 비교한다.
     pHash 차이 ≤ 18/64 이거나 색 MAD < 35 인 쌍이 있으면 '비슷함'으로 적고 dupes.png 에 넣는다(사람이 눈으로 판정).
     pHash ≤ 10 이고 MAD < 20 이면 거의 같은 화면 → 실패
  3) 정지: 컷 안에서 이웃 프레임(초당 10장, 64×36 흑백) 차이가 0.6 미만으로 1.5초 넘게 이어지면 실패
  4) 한 원본은 최대 2컷, 같은 원본 컷이 바로 이어지면 실패(그림판 컷 제외)
문제가 하나라도 있으면 끝 코드 1.
"""

import json
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from devlog_build import FFMPEG  # noqa: E402

OVERLAP, PH_NEAR, MAD_NEAR, PH_SAME, MAD_SAME = 0.2, 18, 35, 10, 20
FREEZE_DIFF, FREEZE_MAX = 0.6, 1.5
N = 32
_C = np.array([[math.cos(math.pi * (2 * x + 1) * u / (2 * N)) for x in range(N)] for u in range(N)])


def frames(video, t0, t1, fps, size, gray):
    w, h = size
    p = subprocess.run([FFMPEG, "-v", "error", "-ss", "%.3f" % t0, "-t", "%.3f" % max(0.05, t1 - t0), "-i", video, "-vf",
                        "fps=%d,scale=%d:%d" % (fps, w, h), "-f", "rawvideo", "-pix_fmt", "gray" if gray else "rgb24", "pipe:1"],
                       capture_output=True).stdout
    ch = 1 if gray else 3
    n = len(p) // (w * h * ch)
    a = np.frombuffer(p[:n * w * h * ch], np.uint8).astype(float)
    return a.reshape(n, h, w) if gray else a.reshape(n, h, w, 3)


def phash(g32):
    d = _C @ g32 @ _C.T
    low = d[:8, :8].flatten()[1:]
    return low > np.median(low)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    folder = sys.argv[1]
    cuts = json.load(open(os.path.join(folder, "cuts.json"), encoding="utf-8"))
    video = os.path.join(folder, "final.mp4")
    bad, warn = [], []
    rows = ["| # | 영상 | 원본 | 원본 구간 | 무엇 | 큰 글자 |", "|---|---|---|---|---|---|"]
    for i, c in enumerate(cuts, 1):
        span = "%.2f–%.2f" % (c["src0"], c["src1"]) if c["src0"] is not None else "-"
        rows.append("| %d | %.2f–%.2f | %s | %s | %s | %s |" % (i, c["t0"], c["t1"], c["source"], span, c.get("note") or "",
                                                              c.get("big") or ""))
    # 1) source overlap, 4) at most 2 cuts per source, never back to back
    vids = [(i, c) for i, c in enumerate(cuts, 1) if c["src0"] is not None]
    for a in range(len(vids)):
        for b in range(a + 1, len(vids)):
            (i, x), (j, y) = vids[a], vids[b]
            if x["source"] == y["source"]:
                ov = min(x["src1"], y["src1"]) - max(x["src0"], y["src0"])
                if ov > OVERLAP:
                    bad.append("원본 겹침: 컷 %d와 %d (%s, %.2f초)" % (i, j, x["source"], ov))
    count = {}
    for i, c in vids:
        count[c["source"]] = count.get(c["source"], 0) + 1
    for s_, n_ in count.items():
        if n_ > 2:
            bad.append("한 원본을 %d컷에 씀: %s (최대 2)" % (n_, s_))
    for k in range(1, len(cuts)):
        if cuts[k]["src0"] is not None and cuts[k]["source"] == cuts[k - 1]["source"]:
            bad.append("같은 원본 컷이 바로 이어짐: 컷 %d·%d (%s)" % (k, k + 1, cuts[k]["source"]))
    # 2) every frame pair across different cuts
    samples = []   # (cut, t, phash, colour)
    for i, c in enumerate(cuts, 1):
        s0 = min(c["t0"] + 0.25, c["t1"] - 0.1)   # skip the transition in (a whip / flash still shows the cut before)
        g = frames(video, s0, c["t1"], 6, (N, N), True)
        col = frames(video, s0, c["t1"], 6, (16, 9), False)
        for k in range(min(len(g), len(col))):
            samples.append((i, s0 + k / 6.0, phash(g[k]), col[k]))
    pairs = []
    for a in range(len(samples)):
        for b in range(a + 1, len(samples)):
            ia, ta, ha, ca = samples[a]
            ib, tb, hb, cb = samples[b]
            if ia == ib:
                continue
            ph = int((ha != hb).sum())
            mad = float(np.abs(ca - cb).mean())
            if ph <= PH_NEAR or mad < MAD_NEAR:
                pairs.append((ph + mad / 4, ia, ta, ib, tb, ph, mad))
    best = {}
    for p in sorted(pairs):
        key = (p[1], p[3])
        if key not in best:
            best[key] = p
    near = sorted(best.values())
    for _, ia, ta, ib, tb, ph, mad in near:
        msg = "컷 %d(%.2f초)와 컷 %d(%.2f초): pHash %d/64, 색 MAD %.1f" % (ia, ta, ib, tb, ph, mad)
        if ph <= PH_SAME and mad < MAD_SAME:
            bad.append("거의 같은 화면: " + msg)
        else:
            warn.append("비슷함(눈으로 확인): " + msg)
    if near:
        top = near[:8]
        sheet = Image.new("RGB", (2 * 216 + 30, len(top) * (384 + 30)), (24, 26, 34))
        d = ImageDraw.Draw(sheet)
        for r, (_, ia, ta, ib, tb, ph, mad) in enumerate(top):
            for k, t in enumerate((ta, tb)):
                f = frames(video, t, t + 0.05, 30, (216, 384), False)
                if len(f):
                    sheet.paste(Image.fromarray(f[0].astype(np.uint8)), (k * (216 + 30), r * 414 + 30))
            d.text((4, r * 414 + 6), "cut %d %.2fs  vs  cut %d %.2fs   pHash %d  MAD %.1f" % (ia, ta, ib, tb, ph, mad), fill=(255, 255, 255))
        sheet.save(os.path.join(folder, "dupes.png"))
    # 3) freezes inside a cut
    for i, c in enumerate(cuts, 1):
        g = frames(video, c["t0"], c["t1"], 10, (64, 36), True)
        run, longest = 0, 0
        for k in range(1, len(g)):
            run = run + 1 if np.abs(g[k] - g[k - 1]).mean() < FREEZE_DIFF else 0
            longest = max(longest, run)
        if longest / 10.0 > FREEZE_MAX:
            bad.append("정지 %.1f초: 컷 %d (%.2f–%.2f)" % (longest / 10.0, i, c["t0"], c["t1"]))
    rows.append("")
    rows.append("검사(원본 겹침·한 원본 최대 2컷·연속 금지·모든 프레임 쌍 pHash/MAD·정지 1.5초): 실패 %d개, 눈으로 볼 것 %d개"
                % (len(bad), len(warn)))
    rows += ["- 실패: " + x for x in bad] + ["- " + x for x in warn[:12]]
    open(os.path.join(folder, "cutlist.md"), "w", encoding="utf-8").write("\n".join(rows) + "\n")
    print("\n".join(rows))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
