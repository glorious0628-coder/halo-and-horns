"""
캐릭터 움직임 검사 (검수 2026-10-08 v7 규칙, 사용자: "맞으면서 때리는 건 괜찮아 … 근데 가만히 서 있는 게 안 된다고").

  py tools/devlog_motioncheck.py build/devlog/shorts01/short01_ai_team

촬영 때 tools/devlog_shots_s40.py 가 클립마다 build/devlog/raw/<원본>.motion.json 을 남긴다: 0.1초마다
(시간, x, y, z, 이동 입력 0/1, 공격·스킬 애니메이션 0/1). 컷이 쓰는 원본 구간에서
  움직임 = 이동 입력이 있거나, 1초에 3스터드 넘게 움직였거나, 0.6초 안에 내 공격·스킬(게임 Fx 신호)이 있었음
이 아닌 샘플이 0.5초 넘게 이어지면 실패. 로그 시간과 영상 시간의 차이(녹화 시작이 조금 늦음)는 OFFSET 으로 맞춘다.
로그가 없는 원본(그림판·하늘·마을 배경 같은 캐릭터 없는 장면)은 '캐릭터 없음/로그 없음'으로 적고 사람이 본다.
출력: <폴더>/motioncheck.md. 실패가 있으면 끝 코드 1.
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from devlog_film import RAW  # noqa: E402

OFFSET = 0.45     # the log starts this much before the clip's first frame
STILL_MAX = 0.5
SPEED = 3.0
ACT_HOLD = 0.6  # a swing / cast counts as moving for this long (the swing animation)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    folder = sys.argv[1]
    cuts = json.load(open(os.path.join(folder, "cuts.json"), encoding="utf-8"))
    rows = ["| # | 영상 | 원본 | 원본 구간 | 움직인 샘플 | 가장 긴 정지 | 판정 |", "|---|---|---|---|---|---|---|"]
    fail = 0
    for i, c in enumerate(cuts, 1):
        if c["src0"] is None:
            continue
        log = os.path.join(RAW, c["source"] + ".motion.json")
        if not os.path.exists(log):
            rows.append("| %d | %.2f–%.2f | %s | %.2f–%.2f | - | - | 로그 없음(캐릭터 없는 장면이면 OK, 눈으로) |"
                        % (i, c["t0"], c["t1"], c["source"], c["src0"], c["src1"]))
            continue
        m = json.load(open(log))
        samples, acts = (m["samples"], m["acts"]) if isinstance(m, dict) else (m, [])
        act_t = [a[0] for a in acts]
        win = [r for r in samples if c["src0"] - 0.05 <= r[0] - OFFSET <= c["src1"] + 0.05]
        active = []
        for k, r in enumerate(win):
            sp = 0.0
            if k > 0:
                q = win[k - 1]
                dt = max(1e-3, r[0] - q[0])
                sp = math.hypot(r[1] - q[1], r[3] - q[3]) / dt
            swing = any(0 <= r[0] - a_ <= ACT_HOLD for a_ in act_t)   # my attack / skill event in the last ACT_HOLD s
            active.append(r[4] > 0 or r[5] > 0 or sp > SPEED or swing)
        run, longest = 0, 0
        for a in active:
            run = 0 if a else run + 1
            longest = max(longest, run)
        still = longest * 0.1
        ok = still <= STILL_MAX and len(win) > 0
        fail += 0 if ok else 1
        rows.append("| %d | %.2f–%.2f | %s | %.2f–%.2f | %d / %d | %.1f초 | %s |" % (
            i, c["t0"], c["t1"], c["source"], c["src0"], c["src1"], sum(active), len(win), still, "OK" if ok else "실패"))
    rows.append("")
    rows.append("가만히 서 있기 0.5초 넘는 컷: %d개" % fail)
    open(os.path.join(folder, "motioncheck.md"), "w", encoding="utf-8").write("\n".join(rows) + "\n")
    print("\n".join(rows))
    sys.exit(1 if fail else 0)


if __name__ == "__main__":
    main()
