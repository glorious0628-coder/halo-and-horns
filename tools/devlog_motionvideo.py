"""
화면으로 보는 캐릭터 움직임 검사 (검수 2026-10-08 v7: "가만히 서 있는 프레임이 0.5초를 넘으면 안 돼요").

  py tools/devlog_motionvideo.py build/devlog/shorts01/short01_ai_team

캐릭터가 나오는 컷(원본이 s41_/s42_/s40_king_fight — 캐릭터를 화면 가운데에 두고 찍은 클립)마다, 완성 영상에서
캐릭터 둘레 상자(가로 340~740, 세로 520~1300)를 초당 10장 흑백 96×190으로 뽑아 이웃 프레임 차이(0~255 평균)를 잰다.
나뭇가지·칼 휘두르기, 걷기, 깡충은 이 상자 안에서 크게 바뀐다. 차이가 STILL(1.2) 미만인 프레임이 0.5초 넘게
이어지면 실패. 큰 글자·자막은 상자 밖(위·아래)에 있어서 거의 섞이지 않는다.
보조: 촬영 로그(.motion.json)의 이동 입력도 함께 적는다(휘두르기는 로그에 안 잡혀서 화면 검사가 기준).
출력: <폴더>/motionvideo.md. 실패가 있으면 끝 코드 1.
"""

import json
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from devlog_build import FFMPEG  # noqa: E402

BOX = (340, 520, 400, 780)   # x, y, w, h in the 1080x1920 frame
STILL, STILL_MAX = 1.2, 0.5
CHAR = ("s41_", "s42_", "s40_king_fight")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    folder = sys.argv[1]
    cuts = json.load(open(os.path.join(folder, "cuts.json"), encoding="utf-8"))
    video = os.path.join(folder, "final.mp4")
    x, y, w, h = BOX
    rows = ["| # | 영상 | 원본 | 무엇 | 가장 긴 정지 | 평균 움직임 | 판정 |", "|---|---|---|---|---|---|---|"]
    fail = 0
    for i, c in enumerate(cuts, 1):
        if c["src0"] is None or not c["source"].startswith(CHAR) or c["source"] in ("s41_crown_sky",):
            continue
        t0 = c["t0"] + 0.2   # skip the transition in
        p = subprocess.run([FFMPEG, "-v", "error", "-ss", "%.3f" % t0, "-t", "%.3f" % max(0.1, c["t1"] - t0), "-i", video, "-vf",
                            "fps=10,crop=%d:%d:%d:%d,scale=96:190,format=gray" % (w, h, x, y), "-f", "rawvideo", "pipe:1"],
                           capture_output=True).stdout
        n = len(p) // (96 * 190)
        a = np.frombuffer(p[:n * 96 * 190], np.uint8).reshape(n, 190, 96).astype(float)
        d = [float(np.abs(a[k] - a[k - 1]).mean()) for k in range(1, n)]
        run, longest = 0, 0
        for v in d:
            run = run + 1 if v < STILL else 0
            longest = max(longest, run)
        still = longest / 10.0
        ok = still <= STILL_MAX
        fail += 0 if ok else 1
        rows.append("| %d | %.2f–%.2f | %s %.2f–%.2f | %s | %.1f초 | %.1f | %s |" % (
            i, c["t0"], c["t1"], c["source"], c["src0"], c["src1"], c.get("note") or "", still, float(np.mean(d)) if d else 0,
            "OK" if ok else "실패"))
    rows.append("")
    rows.append("캐릭터 컷에서 0.5초 넘게 화면이 거의 안 바뀐 컷: %d개 (상자 %s, 차이 < %.1f)" % (fail, BOX, STILL))
    open(os.path.join(folder, "motionvideo.md"), "w", encoding="utf-8").write("\n".join(rows) + "\n")
    print("\n".join(rows))
    sys.exit(1 if fail else 0)


if __name__ == "__main__":
    main()
