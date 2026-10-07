"""
쇼츠 안전 영역 시트 — 다 만든 final.mp4 위에 유튜브 쇼츠가 가리는 곳을 칠하고, 빌드가 프레임마다 잰 자막·이모지·
큰 글자·칩 상자를 그려 한 장으로 모은다(검수 확인용, 사용자 2026-10-07: 자막은 늘 가운데, 화면 밖 글자 0개).

  py tools/devlog_safe_sheet.py build/devlog/shorts01/short01_ai_team [다른 폴더 ...]

입력: <폴더>/final.mp4, <폴더>/safe_check.json (tools/devlog_build.py 가 씀: log = [[프레임, 종류, [x0, y0, x1, y1]], ...])
출력: <폴더>/safe_overlay.png
  - 왼쪽 큰 칸: 영상 전체의 모든 상자를 한 화면에 겹쳐 그린 것(상자가 빨간 테두리 = 안전 영역 안에만 있어야 함)
  - 오른쪽 칸들: 1초마다 한 장 + 자막이 가장 넓은·높은·낮은 프레임
  - 어두운 띠 = 쇼츠 화면이 가리는 곳(위 200, 아래 420, 왼쪽 60, 오른쪽 120), 빨간 테두리 = SAFE (60,200)-(960,1500)
  - 초록 = 자막, 하늘 = 이모지, 노랑 = 큰 글자, 분홍 = 칩, 밖으로 나간 상자 = 빨갛게 칠함
로그가 영상의 모든 프레임을 덮는지(ffprobe 프레임 수와 비교, 소리에 맞춰 끝 1~2프레임이 잘리는 것은 괜찮음)와
밖 상자 수를 출력하고, 하나라도 문제면 끝 코드 1.
"""

import json
import os
import subprocess
import sys
from collections import defaultdict

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from devlog_build import FFMPEG, FFPROBE, W, H, SAFE  # noqa: E402

TILE_W, TILE_H, PER_ROW, LABEL_H = 216, 384, 8, 34
BIG_W, BIG_H = 540, 960
KIND_COL = {"caption": (80, 230, 120), "emoji": (90, 200, 255), "big": (255, 220, 60), "chip": (255, 120, 210)}
FONT = "C:/Windows/Fonts/malgun.ttf"
FONT_B = "C:/Windows/Fonts/malgunbd.ttf"


def font(size, bold=False):
    try:
        return ImageFont.truetype(FONT_B if bold else FONT, size)
    except OSError:
        return ImageFont.load_default()


def outside(b):
    return b[0] < SAFE[0] or b[1] < SAFE[1] or b[2] > SAFE[2] or b[3] > SAFE[3]


def shade(im, s):
    """darken what the Shorts UI covers, red line on the safe box (s = tile scale)"""
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    for r in [(0, 0, W, SAFE[1]), (0, SAFE[3], W, H), (0, SAFE[1], SAFE[0], SAFE[3]), (SAFE[2], SAFE[1], W, SAFE[3])]:
        d.rectangle([v * s for v in r], fill=(0, 0, 0, 120))
    d.rectangle([v * s for v in SAFE], outline=(255, 40, 40, 255), width=2)
    im.alpha_composite(ov)


def draw_boxes(im, boxes, s, width=2, alpha=255):
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    for kind, b in boxes:
        r = [v * s for v in b]
        if outside(b):
            d.rectangle(r, fill=(255, 0, 0, 110), outline=(255, 0, 0, 255), width=width + 1)
        else:
            d.rectangle(r, outline=KIND_COL.get(kind, (255, 255, 255)) + (alpha,), width=width)
    im.alpha_composite(ov)


def probe_frames(path):
    out = subprocess.run([FFPROBE, "-v", "error", "-count_packets", "-select_streams", "v:0", "-show_entries",
                          "stream=nb_read_packets", "-of", "csv=p=0", path], capture_output=True, text=True).stdout
    return int(out.strip().split(",")[0])


def grab(path, frames, w, h):
    """the given frame numbers, scaled to w×h, in frame order"""
    sel = "+".join("eq(n\\,%d)" % f for f in frames)
    p = subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-i", path, "-vf", "select='%s',scale=%d:%d" % (sel, w, h),
                        "-fps_mode", "passthrough", "-f", "rawvideo", "-pix_fmt", "rgb24", "pipe:1"], capture_output=True)
    if p.returncode != 0:
        raise RuntimeError(p.stderr.decode("utf-8", "replace")[-400:])
    n = w * h * 3
    return [Image.frombytes("RGB", (w, h), p.stdout[i * n:(i + 1) * n]).convert("RGBA") for i in range(len(p.stdout) // n)]


def sheet(folder):
    name = os.path.basename(os.path.normpath(folder))
    rep = json.load(open(os.path.join(folder, "safe_check.json"), encoding="utf-8"))
    video = os.path.join(folder, "final.mp4")
    fps = rep.get("fps", 30)
    log = rep.get("log")
    if log is None:
        raise RuntimeError("%s: safe_check.json has no per-frame log - rebuild with the current tools/devlog_build.py" % name)
    by = defaultdict(list)
    for f, kind, b in log:
        by[f].append((kind, b))
    nvid = probe_frames(video)
    bad = [(f, k, b) for f, k, b in log if outside(b)]

    # 1 s steps (mid-second) + the widest / highest / lowest caption frames
    picks = {}
    for k in range(int(nvid / fps)):
        picks.setdefault(int((k + 0.5) * fps), "%.1fs" % (k + 0.5))
    caps = [(f, b) for f, kind, b in log if kind == "caption"]
    if caps:
        for tag, key in [("widest", lambda r: -(r[1][2] - r[1][0])), ("highest", lambda r: r[1][1]), ("lowest", lambda r: -r[1][3])]:
            f = sorted(caps, key=key)[0][0]
            picks[f] = "%s %.1fs" % (tag, f / fps)
    for f, _, _ in bad[:6]:
        picks[f] = "OUT %.1fs" % (f / fps)
    frames = sorted(p for p in picks if p < nvid)
    tiles = grab(video, frames, TILE_W, TILE_H)
    s = TILE_W / W

    rows = (len(tiles) + PER_ROW - 1) // PER_ROW
    head = 96
    sw = 20 + BIG_W + 30 + PER_ROW * (TILE_W + 10)
    sh = head + max(BIG_H + 60, rows * (TILE_H + LABEL_H + 10)) + 20
    out = Image.new("RGBA", (sw, sh), (24, 26, 34, 255))
    d = ImageDraw.Draw(out)
    # the build checked every frame it drew; the mux (-shortest) may drop the last frame or two when the audio ends first
    ok = not bad and len(by) > 0 and 0 <= rep["frames"] - nvid <= 2
    d.text((20, 12), "%s — 안전 영역 확인 %s" % (name, "통과" if ok else "문제 있음"), font=font(34, True),
           fill=(120, 240, 140) if ok else (255, 90, 90))
    d.text((20, 56), "영상 프레임 %d · 로그 프레임 %d · 상자 %d개 · 안전 영역 밖 %d개 · 전체 범위 %s (SAFE %s)"
           % (nvid, rep["frames"], len(log), len(bad), rep.get("extent"), list(SAFE)), font=font(22), fill=(230, 230, 230))

    # every box of the whole video on one frame
    big = Image.new("RGBA", (BIG_W, BIG_H), (52, 56, 70, 255))
    mid = grab(video, [nvid // 2], BIG_W, BIG_H)
    if mid:
        big = Image.blend(mid[0], Image.new("RGBA", (BIG_W, BIG_H), (30, 30, 40, 255)), 0.7)
    shade(big, BIG_W / W)
    uniq = sorted({(k, tuple(b)) for _, k, b in log})
    draw_boxes(big, uniq, BIG_W / W, width=1, alpha=90)
    out.alpha_composite(big, (20, head + 40))
    d.text((20, head + 4), "영상 전체 상자 %d종 겹쳐 보기" % len(uniq), font=font(24, True), fill=(255, 255, 255))

    x0 = 20 + BIG_W + 30
    for i, (f, t) in enumerate(zip(frames, tiles)):
        shade(t, s)
        draw_boxes(t, by.get(f, []), s)
        col, row = i % PER_ROW, i // PER_ROW
        x, y = x0 + col * (TILE_W + 10), head + row * (TILE_H + LABEL_H + 10)
        lab = picks[f]
        d.text((x + 2, y + 2), lab, font=font(20, True), fill=(255, 90, 90) if lab.startswith("OUT") else (255, 255, 255))
        out.alpha_composite(t, (x, y + LABEL_H))
    path = os.path.join(folder, "safe_overlay.png")
    out.convert("RGB").save(path, optimize=True)
    print("%s: video frames %d, log frames %d, boxes %d, outside %d, extent %s -> %s"
          % (name, nvid, rep["frames"], len(log), len(bad), rep.get("extent"), "OK" if ok else "FAIL"), flush=True)
    return ok


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    results = [sheet(f) for f in sys.argv[1:]]
    sys.exit(0 if all(results) else 1)


if __name__ == "__main__":
    main()
