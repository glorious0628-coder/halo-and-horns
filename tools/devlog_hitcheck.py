"""
맞는 숫자 검사 (검수 2026-10-08 v6 → v7: "캐릭터가 맞는 숫자가 보이는 컷은 쓰지 않아요", 컷 전부·30fps).

  py tools/devlog_hitcheck.py build/devlog/shorts01/short01_ai_team

컷마다(그림판 컷 빼고 전부) 두 가지로 본다.
1) 촬영 로그: build/devlog/raw/<원본>.hurt.json 이 있으면(v7 촬영부터, tools/devlog_shots_s40.py) 그 클립을 찍는 동안
   내 Humanoid 체력이 줄어든 횟수(hits_taken). 0이면 그 클립 어디에도 맞는 숫자가 생길 수 없다.
2) 빨강 스캔: 원본 구간을 초당 30장, 가운데 위쪽(폭 20~80 %, 높이 위 2/3)에서 진한 빨강 픽셀을 센다.
   로그가 없는 원본은 이것으로 판정하고, 잡힌 프레임은 hitcheck_red.png 에 잘라 모아 사람이 눈으로 본다
   (빨간 깃발·카드·칼처럼 원래 빨간 그림도 잡히므로 '눈으로 확인'으로 적는다).
출력: <폴더>/hitcheck.md. 로그에 맞은 기록이 있는 컷이 하나라도 있으면 끝 코드 1.
"""

import json
import os
import subprocess
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from devlog_film import FFMPEG, RAW  # noqa: E402

SW, SH = 497, 225


def red_scan(source, t0, t1):
    p = subprocess.run([FFMPEG, "-v", "error", "-ss", "%.2f" % t0, "-t", "%.2f" % max(0.05, t1 - t0), "-i",
                        os.path.join(RAW, source + ".mp4"), "-vf", "fps=30,scale=%d:%d" % (SW, SH),
                        "-f", "rawvideo", "-pix_fmt", "rgb24", "pipe:1"], capture_output=True).stdout
    n = len(p) // (SW * SH * 3)
    if n == 0:
        return [], 0, None
    a = np.frombuffer(p[:n * SW * SH * 3], np.uint8).reshape(n, SH, SW, 3)
    box = a[:, 0:150, 100:400].astype(int)
    red = ((box[..., 0] > 190) & (box[..., 1] < 90) & (box[..., 2] < 90)).sum(axis=(1, 2))
    hits = [k for k in range(n) if red[k] > 6]
    return hits, n, a


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    folder = sys.argv[1]
    cuts = json.load(open(os.path.join(folder, "cuts.json"), encoding="utf-8"))
    rows = ["| # | 영상 | 원본 | 원본 구간 | 촬영 로그(내가 맞은 횟수) | 빨강 스캔(30fps) |", "|---|---|---|---|---|---|"]
    fail, look = 0, []
    crops = []
    for i, c in enumerate(cuts, 1):
        if c["src0"] is None:
            continue
        log = os.path.join(RAW, c["source"] + ".hurt.json")
        logtxt = "-"
        if os.path.exists(log):
            h = json.load(open(log)).get("hits_taken")
            logtxt = "%s번" % h
            if h != 0:
                fail += 1
        hits, n, a = red_scan(c["source"], c["src0"], c["src1"])
        scan = "%d / %d" % (len(hits), n)
        if hits and logtxt != "0번":
            look.append(i)
            for k in hits[:: max(1, len(hits) // 3)][:3]:
                crops.append((i, Image.fromarray(a[k][0:150, 100:400])))
        rows.append("| %d | %.2f–%.2f | %s | %.2f–%.2f | %s | %s |" % (i, c["t0"], c["t1"], c["source"], c["src0"], c["src1"], logtxt, scan))
    if crops:
        sheet = Image.new("RGB", (300 * 3, 150 * ((len(crops) + 2) // 3)), (0, 0, 0))
        for k, (i, im) in enumerate(crops):
            sheet.paste(im, ((k % 3) * 300, (k // 3) * 150))
        sheet.save(os.path.join(folder, "hitcheck_red.png"))
    rows.append("")
    rows.append("촬영 로그로 내가 맞은 컷: %d개. 로그 없는 컷 중 빨강이 잡혀 눈으로 볼 컷: %s (hitcheck_red.png)"
                % (fail, ", ".join(map(str, look)) or "없음"))
    open(os.path.join(folder, "hitcheck.md"), "w", encoding="utf-8").write("\n".join(rows) + "\n")
    print("\n".join(rows))
    sys.exit(1 if fail else 0)


if __name__ == "__main__":
    main()
