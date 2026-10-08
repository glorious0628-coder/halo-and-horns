"""
컷 목록·겹침 검사 (검수 2026-10-08 v6: "같은 원본 구간은 영상에서 한 번만").

  py tools/devlog_cutlist.py build/devlog/shorts01/short01_ai_team

입력: <폴더>/cuts.json (tools/devlog_build.py 가 씀), <폴더>/final.mp4
출력: <폴더>/cutlist.md — 컷 표(영상 시작·끝, 원본 파일·구간, 큰 글자) + 검사 결과
검사:
  1) 원본 구간 겹침: 같은 원본 파일을 쓰는 두 컷의 구간이 0.2초 넘게 겹치면 실패
  2) 프레임 해시: 각 컷 가운데 프레임의 평균 해시(16×16 흑백)를 서로 비교해 거의 같은 컷(차이 ≤ 6/256)이 있으면 실패
     (그림판 컷은 우리 그래픽이라 제외)
문제가 하나라도 있으면 끝 코드 1.
"""

import json
import os
import subprocess
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from devlog_build import FFMPEG, W, H  # noqa: E402

OVERLAP = 0.2
NEAR = 6


def frame_at(video, t):
    p = subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-ss", "%.3f" % t, "-i", video, "-frames:v", "1",
                        "-vf", "scale=16:16,format=gray", "-f", "rawvideo", "pipe:1"], capture_output=True)
    return p.stdout


def ahash(raw):
    if len(raw) < 256:
        return None
    avg = sum(raw[:256]) / 256
    return [1 if v > avg else 0 for v in raw[:256]]


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    folder = sys.argv[1]
    cuts = json.load(open(os.path.join(folder, "cuts.json"), encoding="utf-8"))
    video = os.path.join(folder, "final.mp4")
    rows = ["| # | 영상 | 원본 | 원본 구간 | 큰 글자 |", "|---|---|---|---|---|"]
    for i, c in enumerate(cuts, 1):
        span = "%.2f–%.2f" % (c["src0"], c["src1"]) if c["src0"] is not None else "-"
        rows.append("| %d | %.2f–%.2f | %s | %s | %s |" % (i, c["t0"], c["t1"], c["source"], span, c.get("big") or ""))
    bad = []
    vids = [(i, c) for i, c in enumerate(cuts, 1) if c["src0"] is not None]
    for a in range(len(vids)):
        for b in range(a + 1, len(vids)):
            (i, x), (j, y) = vids[a], vids[b]
            if x["source"] == y["source"]:
                ov = min(x["src1"], y["src1"]) - max(x["src0"], y["src0"])
                if ov > OVERLAP:
                    bad.append("원본 겹침: 컷 %d와 %d (%s, %.2f초 겹침)" % (i, j, x["source"], ov))
    hashes = [(i, ahash(frame_at(video, (c["t0"] + c["t1"]) / 2))) for i, c in vids]
    for a in range(len(hashes)):
        for b in range(a + 1, len(hashes)):
            (i, h1), (j, h2) = hashes[a], hashes[b]
            if h1 and h2:
                d = sum(p != q for p, q in zip(h1, h2))
                if d <= NEAR:
                    bad.append("화면이 거의 같음: 컷 %d와 %d (해시 차이 %d/256)" % (i, j, d))
    rows.append("")
    rows.append("검사: 원본 구간 겹침 0.2초 넘는 곳 + 컷 가운데 프레임 해시 차이 6/256 이하 → %s" % ("문제 0개" if not bad else "%d개" % len(bad)))
    rows += ["- " + x for x in bad]
    out = os.path.join(folder, "cutlist.md")
    open(out, "w", encoding="utf-8").write("\n".join(rows) + "\n")
    print("\n".join(rows))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
