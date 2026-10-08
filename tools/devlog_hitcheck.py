"""
데미지 숫자 위치 검사 (검수 2026-10-08 v6: "캐릭터가 맞는 숫자가 보이는 컷은 쓰지 않아요").

  py tools/devlog_hitcheck.py build/devlog/shorts01/short01_ai_team [원본이름 ...]

내가 맞으면 게임이 빨간 "-2 / -4"를 내 머리 위에 띄운다. 쇼츠 원본은 캐릭터가 화면 가운데에 있으므로, 컷이 쓰는 원본 구간의
프레임마다(초당 10장) 가운데 위쪽 상자(원본 폭의 20~80 %, 높이의 위 2/3)에서 진한 빨강 픽셀을 센다.
몬스터 위 숫자(하얀/노란 "4", "8!")는 빨강이 아니라 세지 않는다.
원본 이름을 주면 그 원본들만 검사한다(기본: s41_ 원본 = 내 캐릭터가 나오는 사냥 장면).
출력: <폴더>/hitcheck.md — 컷마다 빨간 숫자가 잡힌 프레임 수. 하나라도 있으면 끝 코드 1.
"""

import json
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from devlog_film import FFMPEG, RAW  # noqa: E402

SW, SH = 497, 225


def red_frames(source, t0, t1):
    p = subprocess.run([FFMPEG, "-v", "error", "-ss", "%.2f" % t0, "-t", "%.2f" % max(0.1, t1 - t0), "-i",
                        os.path.join(RAW, source + ".mp4"), "-vf", "fps=10,scale=%d:%d" % (SW, SH),
                        "-f", "rawvideo", "-pix_fmt", "rgb24", "pipe:1"], capture_output=True).stdout
    n = len(p) // (SW * SH * 3)
    if n == 0:
        return 0, 0
    a = np.frombuffer(p[:n * SW * SH * 3], np.uint8).reshape(n, SH, SW, 3).astype(int)
    box = a[:, 0:150, 100:400]   # the whole upper middle (a hurt number drifts up and sideways)
    red = ((box[..., 0] > 190) & (box[..., 1] < 90) & (box[..., 2] < 90)).sum(axis=(1, 2))
    return int((red > 6).sum()), n


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    folder = sys.argv[1]
    only = sys.argv[2:]
    cuts = json.load(open(os.path.join(folder, "cuts.json"), encoding="utf-8"))
    rows = ["| # | 영상 | 원본 | 원본 구간 | 빨간 숫자 프레임 |", "|---|---|---|---|---|"]
    bad = 0
    for i, c in enumerate(cuts, 1):
        if c["src0"] is None or (only and c["source"] not in only) or (not only and not c["source"].startswith("s41_")):
            continue
        hits, n = red_frames(c["source"], c["src0"], c["src1"])
        bad += hits
        rows.append("| %d | %.2f–%.2f | %s | %.2f–%.2f | %d / %d |" % (i, c["t0"], c["t1"], c["source"], c["src0"], c["src1"], hits, n))
    rows.append("")
    rows.append("내 머리 위 빨간 숫자(내가 맞음): %s" % ("0개" if bad == 0 else "%d프레임" % bad))
    open(os.path.join(folder, "hitcheck.md"), "w", encoding="utf-8").write("\n".join(rows) + "\n")
    print("\n".join(rows))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
