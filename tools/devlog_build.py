"""
개발 일지 쇼츠(9:16, 1080×1920, 30fps) 만들기 — 촬영 편집 세션 (A23-42, 바이럴 쇼츠 기준 2026-10-06).

  py tools/devlog_build.py shorts01 [--only short02_picture_to_3d] [--no-tts]

입력: docs/devlog/<plan>_plan.json (줄·장면·효과음·제목 초안), build/devlog/raw/*.mp4 (FilmSet 녹화),
      build/devlog/turn/<name>/f_*.png (tools/devlog_turntable.py), art/ (승인 그림)
출력: build/devlog/<plan>/<short id>/ final.mp4 · en.srt · ko.srt · meta.txt · check_sheet.png · safe_check.json (git 밖)
      (안전 영역 시트: py tools/devlog_safe_sheet.py build/devlog/<plan>/<short id>)

- 장면: 파이썬(PIL)이 프레임마다 그린다 — 영상 자르기·확대/밀기(부드러운 소수점 이동), 흔들림, 전환(번쩍·휙·펀치),
  큰 글자·칩 '뿅' 등장, 자막(1~3단어, 가운데 크게, 중요한 단어 금색/빨강, 굵은 외곽선). 인코더 하나로 바로 내보낸다.
- 자막(네온, 사용자 2026-10-07): 가로 540 가운데 고정, 덩어리마다 크기·줄바꿈을 한 번 정하고 강조 단어가 바뀌어도
  줄이 움직이거나 커지지 않는다. 너무 길면 두 줄 → 글자 줄이기. 프레임마다 자막·이모지·큰 글자·칩 상자를 재서
  쇼츠 안전 영역 SAFE(60,200)-(960,1500) 밖이 하나라도 있으면 빌드가 실패한다(safe_check.json).
- 내레이션: MeloTTS(MIT) EN-US (build/tts/.venv), 앞뒤 무음을 잘라 잇는다. 또렷하게(저음 컷·3 kHz 살짝 올림·압축),
  문장 끝(. ! ?)에서는 sentence_gap만큼 더 쉰다.
- 효과음: Kenney CC0 + 직접 합성(휙). 말하는 동안에는 효과음을 낮춘다(덕킹). 음악 없음.
- 소리 크기: 두 번 재는 loudnorm, -14 LUFS / -1.5 dBTP.
- {DAYS}: 빌드하는 날(KST) 기준 2026-10-31 베타까지 남은 날.
"""

import datetime as dt
import json
import math
import os
import random
import re
import subprocess
import sys
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "build", "devlog", "raw")
TURN = os.path.join(ROOT, "build", "devlog", "turn")
TTS_PY = os.path.join(ROOT, "build", "tts", ".venv", "Scripts", "python.exe")
FONT = os.path.join(ROOT, "art", "fonts", "jua", "Jua-Regular.ttf")
W, H, FPS, SR = 1080, 1920, 30, 48000
BAND_H = 250
BOX_Y, BOX_H = 250, 1350          # main picture box under the title band (below it: blurred fill behind YouTube's title area)
CAP_CX, CAP_CY, CAP_MAXW = 520, 1340, 860   # captions: centre, just above the lower third, clear of the right-side buttons
GAP, LEAD = 0.03, 0.05
# YouTube Shorts UI covers the top ~200 px, bottom ~420 px, right ~120 px, left ~60 px (검수 2026-10-07):
# text, faces and key action stay inside SAFE; CX is the centre of that box (boards and captions use it)
SAFE = (60, 200, 960, 1500)
CX = (SAFE[0] + SAFE[2]) // 2
EMOJI_FONT = "C:/Windows/Fonts/seguiemj.ttf"
VBAND = (150, 1500)          # neon style: rows the game footage fills (full width); outside = blurred copy
NEON_CAP_Y, NEON_CAP_SIZE = 1400, 120
# neon captions sit on the frame's centre line and must stay inside SAFE even at the pop peak (x 1.06) and with their glow:
# visible width <= 2 * (SAFE[2] - CAPX) / 1.06 - 2 * glow margin
CAPX = 540
CAP_POP = [0.7, 0.9, 1.04, 1.06, 1.03, 1.0]
CAP_MAXW = int(2 * (SAFE[2] - CAPX) / CAP_POP[3]) - 2 * 22
SAFE_ALPHA = 128              # a pixel counts as visible text / outline / strong glow above this alpha (safe-area check)
NEON_CHUNK = (12, 2)          # neon captions: max characters / words on screen at once
CHECK = (2, 180, 12)          # check sheet: frames per second, tile width, tiles per row
ENC_V = ["-preset", "medium", "-crf", "18"]   # video encoder settings
TARGET_MB = 0                 # > 0: cap the video bitrate so the whole file stays under this size (the long-form: 95)
EXTRA_BOARDS = {}             # name -> fn(shot) for boards a wrapper adds (tools/devlog_long.py)
SAFE_CHECK = True             # neon shorts: fail the build if any caption / overlay box leaves SAFE (the long-form turns it off)
BETA = dt.date(2026, 10, 31)
GOLD, RED, WHITE = (255, 214, 80), (255, 84, 84), (255, 255, 255)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from devlog_film import FFMPEG  # noqa: E402

FFPROBE = os.path.join(os.path.dirname(FFMPEG), "ffprobe.exe")


# ------------------------------------------------------------------ helpers
def days_left():
    kst = dt.datetime.now(dt.timezone(dt.timedelta(hours=9))).date()
    return max(0, (BETA - kst).days)


ONES = "zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen".split()
TENS = "_ _ twenty thirty forty fifty sixty seventy eighty ninety".split()


def words(n):
    if n < 20:
        return ONES[n]
    t, o = divmod(n, 10)
    return TENS[t] + ("-" + ONES[o] if o else "")


def fill(text, for_tts=False):
    d = days_left()
    return text.replace("{DAYS}", words(d) if for_tts else str(d))


_FONTS = {}


def font(size):
    size = max(8, int(size))
    if size not in _FONTS:
        _FONTS[size] = ImageFont.truetype(FONT, size)
    return _FONTS[size]


def hexrgb(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", **kw)
    if r.returncode != 0:
        raise RuntimeError("command failed: %s\n%s" % (" ".join(map(str, cmd[:10])), r.stderr[-3000:]))
    return r


def probe_duration(path):
    return float(run([FFPROBE, "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path]).stdout.strip())


def ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def load_rgba(path):
    return Image.open(os.path.join(ROOT, path)).convert("RGBA")


def contain(im, w, h):
    s = min(w / im.width, h / im.height)
    return im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)


def cover(im, w, h, focus=(0.5, 0.5)):
    s = max(w / im.width, h / im.height)
    im = im.resize((math.ceil(im.width * s), math.ceil(im.height * s)), Image.LANCZOS)
    x, y = int((im.width - w) * focus[0]), int((im.height - h) * focus[1])
    return im.crop((x, y, x + w, y + h))


def gradient(w, h, top, bottom):
    t, b = np.array(hexrgb(top), float), np.array(hexrgb(bottom), float)
    k = np.linspace(0, 1, h)[:, None]
    col = (t[None, :] * (1 - k) + b[None, :] * k).astype(np.uint8)
    return Image.fromarray(np.repeat(col[:, None, :], w, axis=1), "RGBA")


def radial(w, h, inner, outer, cx=0.5, cy=0.45):
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xx - w * cx) / w) ** 2 + ((yy - h * cy) / h) ** 2 * 0.6)
    k = np.clip(d / 0.55, 0, 1)[..., None]
    a, b = np.array(hexrgb(inner), float), np.array(hexrgb(outer), float)
    return Image.fromarray((a * (1 - k) + b * k).astype(np.uint8), "RGBA")


def rounded(size, radius, fill_rgba, outline=None, width=0):
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(im).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=fill_rgba, outline=outline, width=width)
    return im


def soft_shadow_paste(canvas, im, xy, blur=18, alpha=150, off=(0, 14)):
    a = im.split()[-1].point(lambda v: v * alpha // 255)
    pad = blur * 2
    sh = Image.new("RGBA", (im.width + pad * 2, im.height + pad * 2), (0, 0, 0, 0))
    blk = Image.new("RGBA", im.size, (0, 0, 0, 255))
    blk.putalpha(a)
    sh.paste(blk, (pad + off[0], pad + off[1]), blk)
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur)), (xy[0] - pad, xy[1] - pad))
    canvas.alpha_composite(im, xy)


def text_img(parts, size, stroke=None):
    """parts = [(text, rgb)] drawn on one line with a thick dark outline; returns RGBA"""
    f = font(size)
    stroke = stroke if stroke is not None else max(4, size // 11)
    widths = [f.getlength(t) for t, _ in parts]
    tw = int(sum(widths)) + stroke * 2 + 8
    th = int(size * 1.35) + stroke * 2
    im = Image.new("RGBA", (tw + 12, th + 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    x = stroke + 4
    for (t, col), wpx in zip(parts, widths):
        d.text((x + 5, stroke + 9), t, font=f, fill=(0, 0, 0, 150), stroke_width=stroke, stroke_fill=(0, 0, 0, 150))
        x += wpx
    x = stroke + 4
    for (t, col), wpx in zip(parts, widths):
        d.text((x, stroke + 2), t, font=f, fill=tuple(col) + (255,), stroke_width=stroke, stroke_fill=(18, 12, 28, 255))
        x += wpx
    return im


NEON_FONT = "C:/Windows/Fonts/seguibl.ttf"
NEON = {"green": (60, 255, 90), "cyan": (60, 232, 255), "red": (255, 59, 59), "yellow": (255, 225, 77), "pink": (255, 90, 200),
        "orange": (255, 150, 40), "white": (255, 255, 255)}
_NEON_FONTS = {}


def neon_font(size):
    size = max(8, int(size))
    if size not in _NEON_FONTS:
        _NEON_FONTS[size] = ImageFont.truetype(NEON_FONT, size)
    return _NEON_FONTS[size]


def neon_img(parts, size):
    """parts = [(text, rgb)]: Segoe UI Black, thick dark outline, a blurred glow in each coloured part"""
    f = neon_font(size)
    fe = ImageFont.truetype(EMOJI_FONT, max(20, int(size * 0.8)))
    stroke = max(6, size // 9)
    widths = [(fe.getlength(t) + 10) if col == "emoji" else f.getlength(t) for t, col in parts]
    pad = 40
    tw, th = int(sum(widths)) + stroke * 2 + pad * 2, int(size * 1.4) + stroke * 2 + pad * 2
    im = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    glow = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    dg, d = ImageDraw.Draw(glow), ImageDraw.Draw(im)
    x = stroke + pad
    for (t, col), wpx in zip(parts, widths):
        if col != "emoji" and tuple(col) != WHITE:
            dg.text((x, stroke + pad // 2), t, font=f, fill=tuple(col) + (230,), stroke_width=stroke + 10, stroke_fill=tuple(col) + (200,))
        x += wpx
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(16)))
    x = stroke + pad
    for (t, col), wpx in zip(parts, widths):
        if col == "emoji":
            d.text((x + 10, stroke + pad // 2 + int(size * 0.12)), t, font=fe, embedded_color=True)
        else:
            d.text((x + 4, stroke + pad // 2 + 7), t, font=f, fill=(0, 0, 0, 160), stroke_width=stroke, stroke_fill=(0, 0, 0, 160))
            d.text((x, stroke + pad // 2), t, font=f, fill=tuple(col) + (255,), stroke_width=stroke, stroke_fill=(12, 10, 18, 255))
        x += wpx
    return im


def cap_layout(words, max_w, size=None, min_size=84):
    """one fixed layout for a caption chunk: (size, lines) where lines = [[word, ...], ...]. Words keep a tight gap
    (0.26 x size). One line while it fits at >= min_size, else one word per line (still centred)."""
    size = size or NEON_CAP_SIZE

    def line_w(ws, sz):
        f = neon_font(sz)
        return sum(f.getlength(w) for w in ws) + 0.26 * sz * (len(ws) - 1) + 2 * max(6, sz // 9)

    sz = size
    while sz > min_size and line_w(words, sz) > max_w:
        sz -= 4
    if line_w(words, sz) <= max_w or len(words) == 1:
        while sz > 40 and line_w(words, sz) > max_w:
            sz -= 4
        return sz, [list(words)]
    sz = size
    while sz > 40 and max(line_w([w], sz) for w in words) > max_w:
        sz -= 4
    return sz, [[w] for w in words]


def cap_img(words, colors, size, lines):
    """render a caption chunk with its fixed layout; colors[i] = rgb of words[i] (white = no glow). Every highlight state
    of one chunk has the same canvas size and word positions, so the line never moves."""
    f = neon_font(size)
    stroke = max(6, size // 9)
    gap = 0.26 * size
    pad = 40
    lh = int(size * 1.25)
    widths = [[f.getlength(w) for w in ln] for ln in lines]
    lw = [sum(ws) + gap * (len(ws) - 1) for ws in widths]
    tw = int(max(lw)) + stroke * 2 + pad * 2
    th = lh * len(lines) + int(size * 0.2) + stroke * 2 + pad * 2
    im = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    glow = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    dg, d = ImageDraw.Draw(glow), ImageDraw.Draw(im)
    places = []
    k = 0
    for li, ln in enumerate(lines):
        x = pad + stroke + (max(lw) - lw[li]) / 2
        y = pad // 2 + stroke + li * lh
        for wi, w in enumerate(ln):
            places.append((w, x, y, colors[k]))
            x += widths[li][wi] + gap
            k += 1
    for w, x, y, col in places:
        if tuple(col) != WHITE:
            dg.text((x, y), w, font=f, fill=tuple(col) + (230,), stroke_width=stroke + 10, stroke_fill=tuple(col) + (200,))
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(16)))
    for w, x, y, col in places:
        d.text((x + 4, y + 7), w, font=f, fill=(0, 0, 0, 160), stroke_width=stroke, stroke_fill=(0, 0, 0, 160))
        d.text((x, y), w, font=f, fill=tuple(col) + (255,), stroke_width=stroke, stroke_fill=(12, 10, 18, 255))
    return im


_EMO = {}


def emoji_img(e, size=104):
    if (e, size) not in _EMO:
        fe = ImageFont.truetype(EMOJI_FONT, size)
        im = Image.new("RGBA", (int(size * 1.6), int(size * 1.6)), (0, 0, 0, 0))
        ImageDraw.Draw(im).text((int(size * 0.2), int(size * 0.1)), e, font=fe, embedded_color=True)
        _EMO[(e, size)] = im.crop(im.getbbox() or (0, 0, 1, 1))
    return _EMO[(e, size)]


def neon_fit(text, max_w, size, emoji=False):
    """largest size (step 4) whose drawn width fits max_w: the text, its outline on both sides and, for a caption that ends
    with an emoji, the emoji (0.8 x size) and its gap"""
    def width(sz):
        return neon_font(sz).getlength(text) + 2 * max(6, sz // 9) + ((0.8 * sz + 30) if emoji else 0)
    while size > 40 and width(size) > max_w:
        size -= 4
    return size


def topline_img(text):
    """reference style context line: black text on a white box, at most two lines"""
    f = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 46)
    words, lines, cur = text.split(), [], ""
    for w in words:
        cand = (cur + " " + w).strip()
        if cur and f.getlength(cand) > 880:
            lines.append(cur)
            cur = w
        else:
            cur = cand
    if cur:
        lines.append(cur)
    lw = int(max(f.getlength(l) for l in lines)) + 44
    lh = 58 * len(lines) + 26
    box = rounded((lw, lh), 14, (255, 255, 255, 245))
    d = ImageDraw.Draw(box)
    for k, l in enumerate(lines):
        d.text((lw // 2, 13 + 29 + 58 * k), l, font=f, fill=(15, 15, 20, 255), anchor="mm")
    return box


def fit_size(text, max_w, size):
    while size > 30 and font(size).getlength(text) > max_w:
        size -= 2
    return size


def pop_scale(i):
    """scale for frame i since appearance: 0.65 -> 1.10 -> 1.0"""
    seq = [0.65, 0.9, 1.06, 1.1, 1.04, 1.0]
    return seq[i] if i < len(seq) else 1.0


_VIS = {}


def visible_box(im):
    """bbox of the pixels a viewer reads (alpha > SAFE_ALPHA), cached per image"""
    key = id(im)
    if key not in _VIS:
        _VIS[key] = (im, im.getchannel("A").point(lambda a: 255 if a > SAFE_ALPHA else 0).getbbox())
    return _VIS[key][1]


def paste_center(canvas, im, cx, cy, scale=1.0, check=None):
    """paste im centred at (cx, cy); check = (log list, kind, frame) records the visible box for the safe-area check"""
    if check is not None:
        bb = visible_box(im)
        if bb:
            x0 = cx - im.width * scale / 2
            y0 = cy - im.height * scale / 2
            check[0].append((check[2], check[1], (round(x0 + bb[0] * scale), round(y0 + bb[1] * scale),
                                                  round(x0 + bb[2] * scale), round(y0 + bb[3] * scale))))
    if scale != 1.0:
        im = im.resize((max(1, int(im.width * scale)), max(1, int(im.height * scale))), Image.BICUBIC)
    canvas.alpha_composite(im, (int(cx - im.width / 2), int(cy - im.height / 2)))


# ------------------------------------------------------------------ boards
TEAM = [
    ("Reviewer", "the boss: checks everything", "art/ui/IconRanking.png", "#F2C94C"),
    ("Game Dev 1", "builds the game in Studio", "art/ui/IconHammer.png", "#6FCF97"),
    ("Game Dev 2", "writes the server code", "art/ui/IconSettings.png", "#6FCF97"),
    ("World Artist", "big world art + 3D props", "art/ui/UI_MapParchment.png", "#56CCF2"),
    ("Small Artist", "icons, buttons, characters", "art/ui/IconCharacter.png", "#56CCF2"),
    ("Art Dev", "puts the art into the game", "art/ui/IconSkills.png", "#BB86FC"),
    ("Film Crew", "made this video!", "art/ui/IconNews.png", "#FF8A65"),
]
_BOARD_CACHE = {}


def board_team(lit):
    c = radial(W, H, "#26306E", "#0A0D22")
    d = ImageDraw.Draw(c)
    top, rowh, gap = BOX_Y + 40, 118, 10
    for i, (name, role, icon, col) in enumerate(TEAM):
        on = i in lit
        y = top + i * (rowh + gap)
        x = 60 if not on else 46
        cw = 960 if not on else 988
        card = rounded((cw, rowh), 34, hexrgb("#2E3A7E" if on else "#161B3E"), outline=hexrgb(col, 255 if on else 60), width=7 if on else 3)
        c.alpha_composite(card, (x, y))
        ic = contain(load_rgba(icon), 92, 92)
        if not on:
            ic.putalpha(ic.split()[-1].point(lambda v: v * 80 // 255))
        c.alpha_composite(ic, (x + 24 + (92 - ic.width) // 2, y + (rowh - ic.height) // 2))
        a = 255 if on else 80
        d.text((x + 140, y + 40), name, font=font(52), fill=hexrgb(col, a), anchor="lm", stroke_width=3, stroke_fill=(10, 10, 25, a))
        d.text((x + 140, y + 88), role, font=font(34), fill=(235, 238, 255, a), anchor="lm")
    return c


def board_classes():
    c = radial(W, H, "#3B4BA0", "#120F2A")
    files = ["CLS_HaloWarrior_M", "CLS_HaloMage_F", "CLS_HaloArcher_M", "CLS_HornsWarrior_F", "CLS_HornsMage_M", "CLS_HornsArcher_F",
             "CLS_ArtisanWarrior_M", "CLS_ArtisanMage_F"]
    for k, f in enumerate(files):
        col, row = k % 4, k // 4
        x, y = 20 + col * 262, BOX_Y + 70 + row * 470 + (30 if col % 2 else 0)
        im = contain(load_rgba("art/ui/%s.png" % f), 250, 420)
        soft_shadow_paste(c, im, (x + (250 - im.width) // 2, y))
    return c


def board_angel_devil():
    c = Image.new("RGBA", (W, H))
    c.alpha_composite(gradient(W, H // 2, "#FFF1B8", "#7CC8FF"), (0, 0))
    c.alpha_composite(gradient(W, H // 2, "#6A1236", "#1A0614"), (0, H // 2))
    halo = contain(load_rgba("art/ui/CLS_HaloWarrior_M.png"), 520, 600)
    horn = contain(load_rgba("art/ui/CLS_HornsWarrior_F.png"), 520, 600)
    soft_shadow_paste(c, halo, (CX - halo.width // 2, BOX_Y + 30))
    soft_shadow_paste(c, horn, (CX - horn.width // 2, H // 2 + 60))
    return c


def polaroid(im, w, label):
    pic = contain(im, w, w)
    frame = rounded((pic.width + 40, pic.height + 140), 28, (255, 255, 255, 255))
    frame.alpha_composite(pic, (20, 20))
    ImageDraw.Draw(frame).text((frame.width // 2, pic.height + 82), label, font=font(70), fill=(40, 40, 60, 255), anchor="mm")
    return frame.rotate(-3, resample=Image.BICUBIC, expand=True)


def board_picture(img, label):
    c = radial(W, H, "#3A3F86", "#11122C")
    p = polaroid(load_rgba(img), 700, label)
    soft_shadow_paste(c, p, ((W - p.width) // 2, BOX_Y + 60))
    return c


def board_stage(color_in="#4A5BC4", color_out="#10122A"):
    c = radial(W, H, color_in, color_out, cy=0.5)
    floor = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(floor).ellipse((170, 1290, 910, 1440), fill=(0, 0, 0, 110))
    c.alpha_composite(floor.filter(ImageFilter.GaussianBlur(18)))
    return c


TEAM_CARDS = [("🔍", "BOSS", "#F2C94C"), ("🔨", "BUILDER", "#6FCF97"), ("🖥️", "BUILDER", "#6FCF97"), ("⚙️", "BUILDER", "#6FCF97"), ("🖌️", "ARTIST", "#56CCF2"),
              ("✏️", "ARTIST", "#56CCF2"), ("🧩", "ART DEV", "#BB86FC"), ("🔊", "SOUND", "#FF7FC8"), ("🎥", "FILM CREW", "#FF8A65")]


def team_cells():
    """8 cards (the 8 sessions): rows of 3 + 3 + 2 centred on the frame (x 540), inside the Shorts safe area even at
    the pop peak; emoji on top, one word under it"""
    emo = ImageFont.truetype("C:/Windows/Fonts/seguiemj.ttf", 109)
    cells = []
    cw, ch, gx, gy = 246, 270, 20, 20
    rows = [TEAM_CARDS[k:k + 3] for k in range(0, len(TEAM_CARDS), 3)]  # 9 sessions (game dev 3 added 2026-10-08): 3 + 3 + 3
    flat = []
    for r, row in enumerate(rows):
        x0 = CAPX - (len(row) * cw + (len(row) - 1) * gx) // 2
        for k in range(len(row)):
            flat.append((x0 + k * (cw + gx), BOX_Y + 60 + r * (ch + gy)))
    for i, (e, word, col) in enumerate(TEAM_CARDS):
        x, y = flat[i]
        cell = rounded((cw, ch), 38, hexrgb("#24306E"), outline=hexrgb(col), width=8)
        ic = Image.new("RGBA", (150, 150), (0, 0, 0, 0))
        ImageDraw.Draw(ic).text((10, 8), e, font=emo, embedded_color=True)
        ic = ic.crop(ic.getbbox() or (0, 0, 1, 1))
        ic = contain(ic, 132, 132)
        cell.alpha_composite(ic, ((cw - ic.width) // 2, 24))
        lab = text_img([(word, hexrgb(col)[:3])], fit_size(word, cw - 30, 64))
        cell.alpha_composite(lab, ((cw - lab.width) // 2, ch - lab.height - 6))
        cells.append((cell, x + cw // 2, y + ch // 2))
    return cells


def choice_cells():
    """the end question as two big buttons side by side (검수 2026-10-08): GIVE IT BACK (gold, angel) / ONE BITE! (purple,
    devil), inside the Shorts safe area even at the pop / bob peak"""
    emo = ImageFont.truetype("C:/Windows/Fonts/seguiemj.ttf", 109)
    cells = []
    cw, ch, gap = 425, 400, 30
    for i, (e, l1, l2, fill, rim, col) in enumerate((("😇", "GIVE IT", "BACK", "#7A5A12", "#FFD650", (255, 236, 150)),
                                                     ("😈", "ONE", "BITE!", "#4A1E7A", "#C77DFF", (236, 200, 255)))):
        cell = rounded((cw, ch), 46, hexrgb(fill), outline=hexrgb(rim), width=10)
        ic = Image.new("RGBA", (150, 150), (0, 0, 0, 0))
        ImageDraw.Draw(ic).text((10, 8), e, font=emo, embedded_color=True)
        ic = contain(ic.crop(ic.getbbox() or (0, 0, 1, 1)), 120, 120)
        ic = contain(ic, 150, 150)
        cell.alpha_composite(ic, ((cw - ic.width) // 2, 24))
        for k, word in enumerate((l1, l2)):
            lab = text_img([(word, col)], fit_size(word, cw - 40, 92))
            cell.alpha_composite(lab, ((cw - lab.width) // 2, 190 + k * 96))
        cells.append((cell, CAPX + (-1 if i == 0 else 1) * (cw + gap) // 2, 820))
    box = Image.new("RGBA", (190, 190), (0, 0, 0, 0))   # the lost lunchbox the choice is about
    ImageDraw.Draw(box).text((8, 8), "🍱", font=ImageFont.truetype("C:/Windows/Fonts/seguiemj.ttf", 109), embedded_color=True)
    box = contain(box.crop(box.getbbox() or (0, 0, 1, 1)), 240, 240)
    cells.insert(0, (box, CAPX, 470))
    com = text_img([("COMMENT ", WHITE), ("😇", WHITE), (" OR ", WHITE), ("😈", WHITE)], 70) if False else text_img([("COMMENT BELOW!", WHITE)], 72)
    cells.append((com, CAPX, 1100))
    return cells


GRID6 = [("Slime", "MonsterSlimeCube"), ("Baby Slime", "PetBabySlime"), ("Pumpkin Slime", "MonsterPumpkinSlime"),
         ("Pumpkin King", "MonsterPumpkinKing"), ("Bat Goblin", "MonsterBatGoblin"), ("Little Ghost", "MonsterLittleGhost")]  # one family per row


def grid6_cells():
    cells = []
    cw, ch = 420, 300
    for i, (name, fid) in enumerate(GRID6):
        col, row = i % 2, i // 2
        x, y = SAFE[0] + 10 + col * (cw + 40), BOX_Y + 40 + row * (ch + 20)
        cell = rounded((cw, ch), 30, (255, 255, 255, 40), outline=(255, 255, 255, 110), width=3)
        m = contain(load_rgba("art/models/tripo/%s_preview.png" % fid), 240, 222)
        cell.alpha_composite(m, ((cw - m.width) // 2, 6))
        lab = text_img([(name, WHITE)], 42)
        cell.alpha_composite(lab, ((cw - lab.width) // 2, ch - 74))
        cells.append((cell, x + cw // 2, y + ch // 2))
    return cells


def board_end():
    c = radial(W, H, "#FF9A3C", "#3B0F4F", cy=0.42)
    king = contain(load_rgba("art/models/tripo/MonsterPumpkinKing_preview.png"), 640, 640)
    soft_shadow_paste(c, king, (CX - king.width // 2 - 40, BOX_Y + 470))
    buddy = contain(load_rgba("art/models/tripo/MonsterPumpkinSlime_preview.png"), 250, 250)  # pumpkin family only (A23-45)
    soft_shadow_paste(c, buddy, (CX + 180, BOX_Y + 800))
    paste_center(c, text_img([("HALO & HORNS", (255, 243, 214))], fit_size("HALO & HORNS", 860, 120)), CX, BOX_Y + 250)
    paste_center(c, text_img([("BETA  OCT 31", GOLD)], fit_size("BETA  OCT 31", 860, 116)), CX, BOX_Y + 390)
    return c


CODE_FILE, CODE_LINES = "src/ServerScriptService/HalloweenService.luau", (154, 170)


def board_code():
    """our own Luau source as a code editor page (for "I can't code")"""
    c = Image.new("RGBA", (W, H), hexrgb("#1E1E2E"))
    d = ImageDraw.Draw(c)
    mono = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 40)
    lines = open(os.path.join(ROOT, CODE_FILE), encoding="utf-8").read().splitlines()[CODE_LINES[0] - 1:CODE_LINES[1]]
    kw = {"local", "function", "end", "if", "then", "else", "elseif", "return", "not", "and", "or", "while", "do", "true", "false", "nil"}
    y = BOX_Y + 30
    for n, line in enumerate(lines, CODE_LINES[0]):
        d.text((24, y), "%3d" % n, font=mono, fill=(110, 115, 140, 255))
        x = 110
        for tok in re.split(r"(\s+|[(),.=+\-<>\[\]{}])", line.replace("	", "    ")):
            if not tok:
                continue
            col = (198, 120, 221) if tok in kw else (152, 195, 121) if tok.startswith('"') else (97, 175, 239) if re.match(r"^[A-Z]", tok) else (220, 223, 228)
            if tok.strip().startswith("--"):
                col = (106, 115, 125)
            d.text((x, y), tok, font=mono, fill=col + (255,))
            x += mono.getlength(tok)
            if x > W - 20:
                break
        y += 54
    return c


def board_doodle():
    """a wobbly stick figure on paper (for "I can't draw")"""
    c = radial(W, H, "#F7F1E3", "#D9CDB0", cy=0.45)
    d = ImageDraw.Draw(c)
    rng = random.Random(5)
    ink = (40, 40, 50, 255)

    def wob(pts, w=9):
        q = [(x + rng.uniform(-6, 6), y + rng.uniform(-6, 6)) for x, y in pts]
        d.line(q, fill=ink, width=w, joint="curve")

    cx, cy = CX, 760
    d.ellipse((cx - 95, cy - 330, cx + 85, cy - 150), outline=ink, width=9)
    d.ellipse((cx - 50, cy - 270, cx - 30, cy - 250), fill=ink)
    d.ellipse((cx + 15, cy - 265, cx + 33, cy - 247), fill=ink)
    d.arc((cx - 45, cy - 240, cx + 40, cy - 190), 20, 160, fill=ink, width=7)
    wob([(cx, cy - 150), (cx + 8, cy - 40), (cx - 4, cy + 90)])
    wob([(cx + 4, cy - 100), (cx - 120, cy - 30), (cx - 170, cy - 80)])
    wob([(cx + 4, cy - 100), (cx + 110, cy - 150), (cx + 160, cy - 120)])
    wob([(cx - 4, cy + 90), (cx - 90, cy + 230)])
    wob([(cx - 4, cy + 90), (cx + 80, cy + 240), (cx + 120, cy + 236)])
    d.polygon([(cx - 70, cy - 330), (cx - 40, cy - 400), (cx - 10, cy - 330)], outline=ink, width=7)
    return c


def board_pic_full(img, crop=None):
    src = Image.open(os.path.join(ROOT, img)).convert("RGBA")
    if crop:  # fractional (x0, y0, x1, y1), e.g. to leave out a sheet's heading
        src = src.crop((int(crop[0] * src.width), int(crop[1] * src.height), int(crop[2] * src.width), int(crop[3] * src.height)))
    bg = cover(src, W // 8, H // 8).filter(ImageFilter.GaussianBlur(3)).resize((W, H), Image.BILINEAR)
    bg = Image.eval(bg.convert("RGB"), lambda v: int(v * 0.6)).convert("RGBA")
    fg = contain(src, SAFE[2] - SAFE[0] - 40, int((SAFE[3] - SAFE[1]) * 0.8))
    soft_shadow_paste(bg, fg, (CX - fg.width // 2, SAFE[1] + 40))
    return bg


NOGRID = [(CAPX - 215, 560), (CAPX + 215, 560), (CAPX - 215, 1000), (CAPX + 215, 1000)]  # cell centres, 400 px cells


def board_nogrid(imgs):
    """up to 4 candidate pictures on a stage (the director's NO pile)"""
    c = board_stage("#3A3F66", "#10122A")
    for (cx, cy), f in zip(NOGRID, imgs):
        card = rounded((400, 400), 30, hexrgb("#F4EEDF"), outline=hexrgb("#2A2F55"), width=6)
        im = contain(load_rgba(os.path.join(ROOT, f)), 360, 360)
        card.alpha_composite(im, ((400 - im.width) // 2, (400 - im.height) // 2))
        soft_shadow_paste(c, card, (cx - 200, cy - 200))
    return c


def board_image(img, focus=(0.5, 0.5)):
    c = Image.new("RGBA", (W, H))
    c.alpha_composite(cover(Image.open(os.path.join(ROOT, img)).convert("RGBA"), W, H, focus))
    return c


def get_board(shot):
    key = json.dumps({k: shot.get(k) for k in ("board", "lit", "img", "label", "image", "focus_img", "crop", "which")}, sort_keys=True)
    if key in _BOARD_CACHE:
        return _BOARD_CACHE[key]
    b = shot.get("board")
    if b == "team":
        im = board_team(set(shot.get("lit", [])))
    elif b == "classes":
        im = board_classes()
    elif b == "angel_devil":
        im = board_angel_devil()
    elif b == "picture":
        im = board_picture(shot["img"], shot.get("label", "PICTURE"))
    elif b == "end":
        im = board_end()
    elif b in EXTRA_BOARDS:
        im = EXTRA_BOARDS[b](shot)
    elif b == "pic_full":
        im = board_pic_full(shot["img"], shot.get("crop"))
    elif b == "code":
        im = board_code()
    elif b == "doodle":
        im = board_doodle()
    elif b == "nogrid":
        im = board_nogrid(shot["imgs"])
    elif b in ("grid6", "stage", "team_cards", "choice2"):
        im = board_stage("#5A3A9A", "#140A24") if b == "grid6" else board_stage("#2B3A8A", "#0A0D22") if b == "team_cards" else board_stage("#3A2A6A", "#0E0A1E") if b == "choice2" else board_stage()
    elif "image" in shot:
        im = board_image(shot["image"], tuple(shot.get("focus_img", (0.5, 0.5))))
    else:
        raise ValueError("unknown board %r" % shot)
    _BOARD_CACHE[key] = im.convert("RGB")
    return _BOARD_CACHE[key]


# ------------------------------------------------------------------ video source reader
class VideoReader:
    def __init__(self, name, ss, speed=1.0):
        self.path = os.path.join(RAW, name + ".mp4")
        r = run([FFPROBE, "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height", "-of", "csv=p=0", self.path])
        self.w, self.h = [int(v) for v in r.stdout.strip().split(",")[:2]]
        vf = "setpts=%.4f*PTS,fps=%d" % (1.0 / speed, FPS)
        self.p = subprocess.Popen([FFMPEG, "-hide_banner", "-loglevel", "error", "-ss", "%.3f" % ss, "-i", self.path, "-vf", vf,
                                   "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
        self.last = None

    def next(self):
        n = self.w * self.h * 3
        buf = self.p.stdout.read(n)
        if buf and len(buf) == n:
            self.last = Image.frombytes("RGB", (self.w, self.h), buf)
        return self.last  # hold the last frame if the clip runs out

    def close(self):
        try:
            self.p.stdout.close()
            self.p.kill()
        except Exception:
            pass


def box_from_video(fr, shot, t, top):
    """crop window (box aspect) from the source frame at camera time t in [0,1]"""
    sw, sh = fr.size
    ah = sh - top
    z0, z1 = shot.get("z", [1.0, 1.0])
    z = lerp(z0, z1, ease(t))
    f0 = shot.get("f", [[0.5, 0.5], [0.5, 0.5]])
    fx, fy = lerp(f0[0][0], f0[1][0], ease(t)), lerp(f0[0][1], f0[1][1], ease(t))
    ratio = W / BOX_H
    ch = ah / z
    cw = ch * ratio
    if cw > sw:
        cw = sw
        ch = cw / ratio
    x0 = (sw - cw) * fx
    y0 = top + (ah - ch) * fy
    return fr.resize((W, BOX_H), Image.BICUBIC, box=(x0, y0, x0 + cw, y0 + ch))


def compose_video_full(fr, shot, t, top):
    """the whole 9:16 frame from the source (zoom / focus animated; band-style zoom values are softened x0.8)"""
    sw, sh = fr.size
    ah = sh - top
    z0, z1 = shot.get("zf", [max(1.0, v * 0.8) for v in shot.get("z", [1.0, 1.0])])
    z = lerp(z0, z1, ease(t))
    f0 = shot.get("f", [[0.5, 0.5], [0.5, 0.5]])
    fx, fy = lerp(f0[0][0], f0[1][0], ease(t)), lerp(f0[0][1], f0[1][1], ease(t))
    ch = ah / z
    cw = ch * W / H
    x0 = (sw - cw) * fx
    y0 = top + (ah - ch) * fy
    return fr.resize((W, H), Image.BICUBIC, box=(x0, y0, x0 + cw, y0 + ch))


def compose_video_band(fr, shot, t, top):
    """full-width band VBAND from the source (zoom / focus animated), on a blurred, darker copy of the frame"""
    sw, sh = fr.size
    ah = sh - top
    bh = VBAND[1] - VBAND[0]
    z0, z1 = shot.get("zf", [max(1.0, v * 0.8) for v in shot.get("z", [1.0, 1.0])])
    z = lerp(z0, z1, ease(t))
    f0 = shot.get("f", [[0.5, 0.5], [0.5, 0.5]])
    fx, fy = lerp(f0[0][0], f0[1][0], ease(t)), lerp(f0[0][1], f0[1][1], ease(t))
    ch = ah / z
    cw = ch * W / bh
    if cw > sw:
        cw = sw
        ch = cw * bh / W
    x0 = (sw - cw) * fx
    y0 = top + (ah - ch) * fy
    small = fr.crop((0, top, sw, sh)).resize((96, 170), Image.BILINEAR)
    bg = small.filter(ImageFilter.GaussianBlur(5)).resize((W, H), Image.BILINEAR)
    bg = Image.eval(bg, lambda v: int(v * 0.5))
    bg.paste(fr.resize((W, bh), Image.BICUBIC, box=(x0, y0, x0 + cw, y0 + ch)), (0, VBAND[0]))
    return bg


def compose_video_fit(fr, shot, t, top):
    """a window / card shot: the source's full aspect (zoom / focus animated) fitted to the frame width at fit_y, on a
    blurred, darker copy (the 9:16 band would cut the sides of a wide card)"""
    sw, sh = fr.size
    ah = sh - top
    z0, z1 = shot.get("zf", shot.get("z", [1.0, 1.0]))
    z = lerp(z0, z1, ease(t))
    f0 = shot.get("f", [[0.5, 0.5], [0.5, 0.5]])
    fx, fy = lerp(f0[0][0], f0[1][0], ease(t)), lerp(f0[0][1], f0[1][1], ease(t))
    cw, ch = sw / z, ah / z
    x0 = (sw - cw) * fx
    y0 = top + (ah - ch) * fy
    h = int(round(W * ch / cw))
    small = fr.crop((0, top, sw, sh)).resize((96, 170), Image.BILINEAR)
    bg = small.filter(ImageFilter.GaussianBlur(5)).resize((W, H), Image.BILINEAR)
    bg = Image.eval(bg, lambda v: int(v * 0.5))
    bg.paste(fr.resize((W, h), Image.BICUBIC, box=(x0, y0, x0 + cw, y0 + ch)), (0, int(shot.get("fit_y", 900)) - h // 2))
    return bg


def compose_video_frame(fr, shot, t, top):
    sw, sh = fr.size
    small = fr.crop((0, top, sw, sh)).resize((96, 170), Image.BILINEAR, reducing_gap=None)
    bg = small.filter(ImageFilter.GaussianBlur(5)).resize((W, H), Image.BILINEAR)
    bg = Image.eval(bg, lambda v: int(v * 0.55))
    bg.paste(box_from_video(fr, shot, t, top), (0, BOX_Y))
    return bg


# ------------------------------------------------------------------ captions
def caption_chunks(text, hl, hlr, max_chars=14, max_words=3):
    toks = text.split()
    hl_words = set(w.lower().strip(".,!?:") for k in hl for w in fill(k).split())
    hlr_words = set(w.lower().strip(".,!?:") for k in hlr for w in fill(k).split())
    # a short highlighted phrase ("art dev," / "sound maker,") stays in one chunk instead of splitting "AN ART" | "DEV,"
    low = [w.lower().strip(".,!?:") for w in toks]
    spans = {}
    for k in list(hl) + list(hlr):
        ph = [w.lower().strip(".,!?:") for w in fill(k).split()]
        if len(ph) > 1 and len(" ".join(fill(k).split())) <= max_chars:
            for i in range(len(low) - len(ph) + 1):
                if low[i:i + len(ph)] == ph:
                    spans.setdefault(i, i + len(ph))
    chunks, cur = [], []
    i = 0
    while i < len(toks):
        j = spans.get(i, i + 1)
        unit = toks[i:j]
        cand = " ".join(cur + unit)
        too_many = len(cur) + len(unit) > max_words and not (len(unit) > 1 and len(cand) <= max_chars)
        if cur and (too_many or len(cand) > max_chars or re.search(r"[.!?:,]$", cur[-1])):
            chunks.append(cur)
            cur = []
        cur.extend(unit)
        i = j
    if cur:
        chunks.append(cur)
    out = []
    for ch in chunks:
        parts = []
        for i, w in enumerate(ch):
            key = w.lower().strip(".,!?:")
            col = RED if key in hlr_words else GOLD if key in hl_words else WHITE
            parts.append((w + (" " if i < len(ch) - 1 else ""), col))
        out.append(parts)
    return out


def cap_upper(t):
    """caption caps, but a plural acronym keeps its small s ('AIs', not 'AIS')"""
    keep = set(m.group(1).upper() for m in re.finditer(r"(?<![A-Za-z])([A-Z]{2,})s(?![A-Za-z])", t))
    return re.sub(r"(?<![A-Z])([A-Z]{2,})S(?![A-Z])", lambda m: m.group(1) + "s" if m.group(1) in keep else m.group(0), t.upper())


def word_times(it):
    """(WORD, start s) of each spoken word of a timeline line, timed exactly like the neon karaoke captions"""
    line = it["line"]
    cs = caption_chunks(fill(line["en"]), line.get("hl", []), line.get("hlr", []), max_chars=NEON_CHUNK[0], max_words=NEON_CHUNK[1])
    words_all = [[t.upper().strip() for t, _ in ch_] for ch_ in cs]
    lens = [sum(len(w) + 1 for w in c) - 1 + 3 for c in words_all]
    t0, t1 = it["start"], it["speech_end"]
    out, t = [], t0
    for c, L in zip(words_all, lens):
        d = (t1 - t0) * L / sum(lens)
        wl = [len(w) + 2 for w in c]
        tw = t
        for w, l_ in zip(c, wl):
            out.append((w.strip(".,!?:…"), tw))
            tw += d * l_ / sum(wl)
        t += d
    return out


def cue_times(it, cues):
    """start times of the cue words in order (a repeated word = its next use), e.g. a team card pops as its word is said"""
    if not cues:
        return None
    wt = word_times(it)
    out, j, last = [], 0, it["start"]
    for cue in cues:
        if cue.startswith("+"):  # "+0.2" = the card before + 0.2 s (two cards on one word: "three BUILDERS")
            out.append(last + float(cue[1:]))
            continue
        key = cue.upper().strip(".,!?:…")
        while j < len(wt) and wt[j][0] != key:
            j += 1
        last = wt[j][1] if j < len(wt) else it["start"]
        out.append(last)
        j += 1
    return out


def build_caption_events(timeline, style="band"):
    ev = []
    for it in timeline:
        line = it["line"]
        if line.get("cap") is False or line.get("silent"):
            continue
        cs = caption_chunks(fill(line["en"]), line.get("hl", []), line.get("hlr", []), max_chars=NEON_CHUNK[0] if style == "neon" else 14,
                            max_words=NEON_CHUNK[1] if style == "neon" else 3)
        if style == "neon":
            ncol = NEON.get(line.get("neon", "yellow"), NEON["yellow"])
            words_all = [[(cap_upper(t), c) for t, c in ch_] for ch_ in cs]
            lens = [sum(len(t) for t, _ in c) + 3 for c in words_all]
            t0, t1 = it["start"], it["speech_end"]
            t = t0
            for ci, (c, L) in enumerate(zip(words_all, lens)):
                d = (t1 - t0) * L / sum(lens)
                ws = [w.strip() for w, _ in c]
                size, lines = cap_layout(ws, CAP_MAXW)          # one layout per chunk: it never moves or resizes
                wl = [len(w) + 2 for w in ws]
                emo = line.get("emoji") if ci == len(words_all) - 1 else None
                tw = t
                for wi in range(len(c)):
                    # the spoken word in the line colour, hlr words always red, the rest white
                    cols = [ncol if k == wi else NEON["red"] if col == RED else WHITE for k, (w, col) in enumerate(c)]
                    dw = d * wl[wi] / sum(wl)
                    ev.append({"start": tw, "end": tw + dw, "pop_from": t, "hold": t1 + 0.06,
                               "img": cap_img(ws, cols, size, lines), "emoji": emo})
                    tw += dw
                t += d
            continue
        lens = [sum(len(t) for t, _ in c) + 3 for c in cs]
        t0, t1 = it["start"], it["speech_end"]
        t = t0
        for c, L in zip(cs, lens):
            d = (t1 - t0) * L / sum(lens)
            txt = "".join(t for t, _ in c)
            if style == "neon":
                ev.append({"start": t, "end": t + d, "img": neon_img(c, neon_fit(txt, 940, 150)), "hold": t1 + 0.06})
            else:
                size = fit_size(txt, CAP_MAXW, 118)
                ev.append({"start": t, "end": t + d, "img": text_img(c, size), "hold": t1 + 0.06})
            t += d
    for a, b in zip(ev, ev[1:]):
        a["end"] = min(b["start"], max(a["end"], a["hold"]))  # no caption left over a silent beat
    if ev:
        ev[-1]["end"] += 0.35
    return ev


# ------------------------------------------------------------------ sound effects
# Kenney.nl CC0 packs (Impact Sounds, Interface Sounds; docs/devlog/sfx_licenses.md) + our own synthesised whoosh / sub
SFX_DIR = os.path.join(ROOT, "build", "devlog", "sfx")
SFX_FILES = {
    "boom": "impact/Audio/impactSoft_heavy_000.ogg",
    "hit": "impact/Audio/impactPunch_heavy_002.ogg",
    "pop": "interface/Audio/drop_002.ogg",
    "card": "interface/Audio/drop_003.ogg",
    "ding": "interface/Audio/confirmation_002.ogg",
    "tick": "interface/Audio/tick_004.ogg",
    "sound_card": os.path.join(ROOT, "art", "sfx", "SkillLearn.wav"),   # our own synth (소리 만들기 2026-10-07): the SOUND team card
}
# the game's own sounds (art/sfx, 소리 만들기: own synth / Kenney CC0 / Firefly, docs/devlog/sfx_licenses.md) as g_<Name>
for _g in ("PumpkinKing", "Purify", "Devour", "GoldPickup", "LevelUp", "CrownHalo", "CrownHorns", "KillPop", "HitHeavy",
           "KingDefeat", "PowerUp"):
    SFX_FILES["g_" + _g] = os.path.join(ROOT, "art", "sfx", _g + ".wav")
_SFX = {}
SFX_GAIN = {"whoosh": 0.3, "boom": 0.3, "hit": 0.26, "pop": 0.22, "card": 0.2, "sound_card": 0.24, "g_PumpkinKing": 0.32, "g_Purify": 0.3, "g_Devour": 0.3, "g_GoldPickup": 0.2, "g_LevelUp": 0.26,
            "g_CrownHalo": 0.28, "g_CrownHorns": 0.28, "g_KillPop": 0.24, "g_HitHeavy": 0.26, "g_KingDefeat": 0.3, "g_PowerUp": 0.28, "ding": 0.2, "tick": 0.25}  # about -18..-11 dB under the voice


def sfx(name):
    if name in _SFX:
        return _SFX[name]
    f = SFX_FILES.get(name)
    if f and os.path.exists(os.path.join(SFX_DIR, f)):
        r = subprocess.run([FFMPEG, "-v", "error", "-i", os.path.join(SFX_DIR, f), "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True)
        x = np.frombuffer(r.stdout, dtype=np.float32).astype(np.float64)
        x = x / max(1e-6, np.abs(x).max()) * 0.9
        if name == "boom":  # add our sub-bass under the thud for the boss moments
            sub = synth_sfx("boom") * 0.55
            n = max(len(x), len(sub))
            x = np.pad(x, (0, n - len(x))) + np.pad(sub, (0, n - len(sub)))
        _SFX[name] = x
    else:
        _SFX[name] = synth_sfx(name if name not in ("hit", "card") else ("boom" if name == "hit" else "pop"))
    return _SFX[name]


def synth_sfx(name):
    rng = np.random.default_rng(7)
    if name == "whoosh":
        n = int(SR * 0.42)
        t = np.linspace(0, 1, n)
        noise = rng.standard_normal(n)
        env = np.sin(np.pi * t) ** 2
        out = np.zeros(n)
        y = 0.0
        for i in range(n):  # sweeping one-pole low-pass
            a = 0.02 + 0.25 * env[i]
            y += a * (noise[i] - y)
            out[i] = y
        out -= np.convolve(out, np.ones(40) / 40, mode="same")
        return out * env * 3.2
    if name == "pop":
        n = int(SR * 0.12)
        t = np.arange(n) / SR
        f = 500 + 1300 * (t / t[-1])
        ph = 2 * np.pi * np.cumsum(f) / SR
        return np.sin(ph) * np.exp(-t * 32) * 0.9
    if name == "boom":
        n = int(SR * 0.9)
        t = np.arange(n) / SR
        f = 95 * np.exp(-t * 3) + 38
        ph = 2 * np.pi * np.cumsum(f) / SR
        low = np.sin(ph) * np.exp(-t * 4.5)
        noise = rng.standard_normal(n) * np.exp(-t * 18) * 0.35
        noise = np.convolve(noise, np.ones(30) / 30, mode="same")
        return (low + noise) * 1.1
    if name == "ding":
        n = int(SR * 0.8)
        t = np.arange(n) / SR
        return (np.sin(2 * np.pi * 1318.5 * t) * 0.6 + np.sin(2 * np.pi * 2637 * t) * 0.25 + np.sin(2 * np.pi * 1976 * t) * 0.15) * np.exp(-t * 6) * 0.7
    if name == "tick":
        n = int(SR * 0.05)
        t = np.arange(n) / SR
        return np.sin(2 * np.pi * 2200 * t) * np.exp(-t * 90) * 0.6
    raise ValueError(name)


# ------------------------------------------------------------------ audio
def tts_wavs(short, voice, tts_dir, out_dir, do_tts):
    jobs = [{"id": "%s_%s" % (short["id"], l["id"]), "text": fill(l.get("tts", l["en"]), True),
             "out": os.path.join(tts_dir, "%s_%s.wav" % (short["id"], l["id"])),
             **{k: voice[k] for k in ("speaker", "speed", "noise_scale", "noise_scale_w", "sdp_ratio") if k in voice},
             **({"speed": l["tts_speed"]} if "tts_speed" in l else {})}   # a line may talk faster (team list, 검수 v5)
            for l in short["lines"] if not l.get("silent")]
    if do_tts:
        jf = os.path.join(out_dir, "tts_jobs.json")
        json.dump(jobs, open(jf, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        r = subprocess.run([TTS_PY, os.path.join(ROOT, "tools", "devlog_tts.py"), jf], capture_output=True, text=True, encoding="utf-8", errors="replace")
        if r.returncode != 0:
            raise RuntimeError("tts failed:\n" + r.stderr[-3000:])
    out = {}
    for j in jobs:  # trim the silence MeloTTS leaves (gently: keep soft word ends), clean the voice, 48 kHz mono
        trimmed = j["out"].replace(".wav", "_trim.wav")
        trim = "silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.06"
        voice_fx = VOICE_FX if voice.get("process", True) else "anull"
        run([FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-i", j["out"], "-af",
             "%s,areverse,%s,areverse,%s,aresample=%d" % (trim, trim, voice_fx, SR), "-ac", "1", "-sample_fmt", "s16", trimmed])
        with wave.open(trimmed) as w:
            out[j["id"]] = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
    return [out.get("%s_%s" % (short["id"], l["id"]), np.zeros(int(float(l.get("silent", 0)) * SR), dtype=np.float32))
            for l in short["lines"]]


# a clearer voice: cut rumble, a little presence (consonants), gentle compression so every word is as loud
VOICE_FX = ("highpass=f=90,equalizer=f=3200:t=q:w=1.0:g=3,equalizer=f=250:t=q:w=1.0:g=-2,"
            "acompressor=threshold=-20dB:ratio=2.5:attack=5:release=80:makeup=2")


def duck(fx, voice_track, depth=0.42, attack=0.015, release=0.25):
    """lower the effects while the narrator talks (sidechain ducking): gain -> depth (0.42 = -7.5 dB) under speech"""
    hop = SR // 200                                                    # 5 ms control rate
    n = len(voice_track) // hop
    if n == 0:
        return fx
    frames = voice_track[:n * hop].reshape(n, hop)
    env = np.sqrt((frames ** 2).mean(axis=1))
    speech = env > 0.015
    g = np.ones(n)
    a_up, a_dn = math.exp(-1 / (release * 200)), math.exp(-1 / (attack * 200))
    cur = 1.0
    for i in range(n):
        target = depth if speech[i] else 1.0
        a = a_dn if target < cur else a_up
        cur = target + (cur - target) * a
        g[i] = cur
    gain = np.repeat(g, hop)
    gain = np.pad(gain, (0, max(0, len(fx) - len(gain))), constant_values=1.0)[:len(fx)]
    return fx * gain


def write_wav(path, x):
    x = np.clip(x, -1, 1)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def loudnorm(src, dst):
    # tame the effect peaks first so the linear loudnorm can reach -14 LUFS without clipping
    pre = src.replace(".wav", "_lim.wav")
    run([FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-i", src, "-af",
         "acompressor=threshold=0.25:ratio=3:attack=5:release=80,alimiter=limit=0.5:level=disabled", pre])
    src = pre
    r = run([FFMPEG, "-hide_banner", "-i", src, "-af", "loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json", "-f", "null", "-"])
    js = json.loads(r.stderr[r.stderr.rindex("{"):r.stderr.rindex("}") + 1])
    af = ("loudnorm=I=-14:TP=-1.5:LRA=11:measured_I=%s:measured_TP=%s:measured_LRA=%s:measured_thresh=%s:offset=%s:linear=true,aresample=%d"
          % (js["input_i"], js["input_tp"], js["input_lra"], js["input_thresh"], js["target_offset"], SR))
    run([FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-i", src, "-af", af, "-ar", str(SR), dst])


# ------------------------------------------------------------------ build one short
def build_short(short, voice, out_root, do_tts=True):
    sid = short["id"]
    out_dir = os.path.join(out_root, sid)
    tts_dir = os.path.join(out_root, "tts")
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(tts_dir, exist_ok=True)
    voices = tts_wavs(short, voice, tts_dir, out_dir, do_tts)
    # timeline: lines back to back
    t = LEAD
    timeline = []
    for l, v in zip(short["lines"], voices):
        d = len(v) / SR
        timeline.append({"line": l, "audio": v, "start": t, "speech_end": t + d})
        # a clear stop after a sentence (user: "문장 끝을 분명히"), a short breath elsewhere
        default_gap = short.get("gap", GAP)
        if "gap" not in l and re.search(r"[.!?…]\s*$", fill(l.get("en", ""))):
            default_gap = max(float(default_gap), float(short.get("sentence_gap", default_gap)))
        t += d + float(l.get("gap", default_gap))
    total = t + float(short.get("tail", 0.4))
    nframes = int(round(total * FPS))
    # shots → frame ranges (a line's shots split its span by weight)
    bounds = [0.0] + [it["start"] for it in timeline[1:]] + [total]
    shots = []
    for i, it in enumerate(timeline):
        f0, f1 = round(bounds[i] * FPS), round(bounds[i + 1] * FPS)
        ss = it["line"]["shots"]
        ws = [float(s.get("w", 1.0)) for s in ss]
        acc = f0
        for k, s in enumerate(ss):
            n = (f1 - acc) if k == len(ss) - 1 else round((f1 - f0) * ws[k] / sum(ws))
            shots.append({"shot": s, "f0": acc, "f1": acc + n, "cue_t": cue_times(it, s.get("cues"))})
            acc += n
    # the cut list (검수 v6: every cut's source and part, for tools/devlog_cutlist.py)
    cuts = []
    for sh in shots:
        s_ = sh["shot"]
        n_ = sh["f1"] - sh["f0"]
        sp_ = float(s_.get("speed", 1.0))
        cuts.append({"t0": round(sh["f0"] / FPS, 2), "t1": round(sh["f1"] / FPS, 2),
                     "source": s_.get("video") or ("board:" + str(s_.get("board") or s_.get("cards"))),
                     "src0": round(float(s_.get("ss", 0)), 2) if "video" in s_ else None,
                     "src1": round(float(s_.get("ss", 0)) + n_ / FPS * sp_, 2) if "video" in s_ else None,
                     "big": (s_.get("big") or {}).get("text"), "note": s_.get("note", "")})
    json.dump(cuts, open(os.path.join(out_dir, "cuts.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    # audio: narration + effects
    mix = np.zeros(int(total * SR) + SR)
    for it in timeline:
        o = int(it["start"] * SR)
        mix[o:o + len(it["audio"])] += it["audio"]
    fx = np.zeros_like(mix)
    for sh in shots:
        for e in sh["shot"].get("sfx", []):
            name, at = (e, 0.0) if isinstance(e, str) else (e["name"], float(e.get("at", 0.0)))
            snd = sfx(name) * float(sh["shot"].get("sfx_gain", SFX_GAIN.get(name, 0.25)))
            o = int((sh["f0"] / FPS + at) * SR)
            o = max(0, o)
            fx[o:o + len(snd)] += snd[:max(0, len(fx) - o)]
        names = sh["shot"].get("cue_sfx")   # one effect on each cue word (team cards: the card pops as its word is said);
        for ci, tc in enumerate(sh["cue_t"] or []) if names else []:   # a list = one name per cue (the SOUND card has its own)
            name = names[ci] if isinstance(names, list) else names
            snd = sfx(name) * float(sh["shot"].get("sfx_gain", SFX_GAIN.get(name, 0.25)))
            o = max(0, int(tc * SR))
            fx[o:o + len(snd)] += snd[:max(0, len(fx) - o)]
    fx = duck(fx, mix)
    raw_wav, norm_wav = os.path.join(out_dir, "mix_raw.wav"), os.path.join(out_dir, "mix.wav")
    write_wav(raw_wav, (mix + fx)[:int(total * SR)])
    loudnorm(raw_wav, norm_wav)
    # captions + subtitles files
    style = short.get("style", "band")
    cap_y = int(short.get("cap_y", NEON_CAP_Y if short.get("style") == "neon" else CAP_CY))
    caps = build_caption_events(timeline, style)
    write_srts(timeline, out_dir)
    # title band (one image)
    band = Image.new("RGBA", (W, BAND_H + 40), (0, 0, 0, 0))
    grad = gradient(W, BAND_H + 40, "#000000", "#000000")
    grad.putalpha(Image.fromarray(np.linspace(215, 0, BAND_H + 40).astype(np.uint8)[:, None].repeat(W, 1), "L"))
    band.alpha_composite(grad)
    if style == "neon":  # no dark band: only the white context line near the top (reference style)
        band = Image.new("RGBA", (W, BAND_H + 40), (0, 0, 0, 0))
        if short.get("topline"):  # optional (user 2026-10-06: not needed)
            tl = topline_img(fill(short["topline"]))
            band.alpha_composite(tl, ((W - tl.width) // 2, 150))
    else:
        b0, b1 = short["band"]
        paste_center(band, text_img([(b0, GOLD)], fit_size(b0, 980, 96)), W // 2, 142)
        paste_center(band, text_img([(b1, WHITE)], fit_size(b1, 980, 50)), W // 2, 222)
    # render
    final = os.path.join(out_dir, "final.mp4")
    enc_v = ENC_V
    if TARGET_MB:
        kbps = max(1500, int(TARGET_MB * 8000 / total) - 230)  # minus the 192k audio and the mp4 overhead
        enc_v = ["-preset", "slow", "-crf", "20", "-maxrate", "%dk" % kbps, "-bufsize", "%dk" % (2 * kbps)]
    enc = subprocess.Popen([FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
                            "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (W, H), "-r", str(FPS), "-i", "-",
                            "-i", norm_wav, "-map", "0:v", "-map", "1:a",
                            "-c:v", "libx264"] + enc_v + ["-profile:v", "high", "-pix_fmt", "yuv420p",
                            "-c:a", "aac", "-b:a", "192k", "-ar", str(SR), "-movflags", "+faststart", "-shortest", final],
                           stdin=subprocess.PIPE)
    turn_cache = {}
    rnd = random.Random(3)
    last = None
    safe_log = []          # (frame, kind, visible box) of every caption / emoji / big word / chip (neon shorts)
    check_on = style == "neon" and SAFE_CHECK
    for sh in shots:
        s, f0, f1 = sh["shot"], sh["f0"], sh["f1"]
        n = max(1, f1 - f0)
        reader = VideoReader(s["video"], float(s.get("ss", 0)), float(s.get("speed", 1.0))) if "video" in s else None
        top = int(s.get("top", 72 if s.get("topbar") else 0))
        cb_ = s.get("board") or s.get("cards")
        cells = grid6_cells() if cb_ == "grid6" else team_cells() if cb_ == "team_cards" else choice_cells() if cb_ == "choice2" else None
        tframes = None
        shot_prev = last
        if "turn" in s:
            key = s["turn"]
            if key not in turn_cache:
                d_ = os.path.join(TURN, key)
                turn_cache[key] = [Image.open(os.path.join(d_, f)).convert("RGBA") for f in sorted(os.listdir(d_)) if f.endswith(".png")]
            tframes = turn_cache[key]
        for i in range(n):
            fi = f0 + i
            t = i / max(1, n - 1)
            if reader:
                comp = compose_video_fit if s.get("fit") else compose_video_full if s.get("full") else compose_video_band if style == "neon" else compose_video_frame
                fr = comp(reader.next(), s, t, top).convert("RGBA")
                if s.get("tint"):   # a colour wash for the shot (devil = purple, 검수 v7: the two lunchbox results must differ)
                    tc = hexrgb(s["tint"][0])[:3]
                    fr = Image.blend(fr, Image.new("RGBA", (W, H), tc + (255,)), float(s["tint"][1]))
            else:
                base = get_board(s)
                z0, z1 = s.get("z", [1.0, 1.06])
                z = lerp(z0, z1, ease(t))
                fo = s.get("f", [[0.5, 0.5], [0.5, 0.5]])
                fx_, fy_ = lerp(fo[0][0], fo[1][0], ease(t)), lerp(fo[0][1], fo[1][1], ease(t))
                bw, bh = W / z, H / z
                x0, y0 = (W - bw) * fx_, (H - bh) * fy_
                fr = base.resize((W, H), Image.BICUBIC, box=(x0, y0, x0 + bw, y0 + bh)).convert("RGBA")
                if tframes:
                    k = int(round(float(s.get("start", 0)) + i * float(s.get("step", 1)))) % len(tframes)  # step < 1 = slow swing past the front
                    m = tframes[k]
                    sc = float(s.get("scale", 1.0))
                    paste_center(fr, m, CX, int(s.get("y", BOX_Y + 560)), sc * pop_scale(i) if s.get("pop") else sc)
            if cells:
                if reader and s.get("dim"):  # cards over the game: a dark see-through layer (검수 v5)
                    fr.alpha_composite(Image.new("RGBA", (W, H), (8, 10, 30, int(255 * float(s["dim"])))))
                per = int(s["every"] * FPS) if s.get("every") else max(1, int(n * 0.75) // len(cells))
                cue_t = sh["cue_t"]
                for ci, (cell, cx, cy) in enumerate(cells):
                    k = 99 if s.get("static") else fi - math.ceil(cue_t[ci] * FPS - 1e-6) if cue_t and ci < len(cue_t) else i - ci * per
                    if k >= 0:
                        if s.get("bob"):  # the two end buttons bounce in turn
                            cy = cy - int(abs(math.sin(math.pi * (fi / FPS) * 1.8 + ci * math.pi / 2)) * 34)
                        paste_center(fr, cell, cx, cy, pop_scale(k))
            # falling / rising icons
            for key, sign in (("rain", 1), ("float", -1)):
                spec = s.get(key)
                if spec:
                    sprites = _sprites(spec, n)
                    for (im_, x_, y0_, sp_, rot_) in sprites:
                        yy = y0_ + sign * sp_ * i
                        if -200 < yy < H + 200:
                            paste_center(fr, im_.rotate(rot_ * i, resample=Image.BICUBIC, expand=True) if rot_ else im_, x_, yy)
            if s.get("xcells"):  # a red X on each NO-pile picture in turn
                xm = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                dx = ImageDraw.Draw(xm)
                for ci_, (cx_, cy_) in enumerate(NOGRID[:len(s.get("imgs", []))]):
                    if ci_ in s.get("keep", []):
                        continue
                    prog = ease((i - 3 - ci_ * float(s["xcells"]) * FPS) / 4)
                    if prog > 0:
                        r_ = 150
                        for p0, p1 in (((cx_ - r_, cy_ - r_), (cx_ + r_, cy_ + r_)), ((cx_ + r_, cy_ - r_), (cx_ - r_, cy_ + r_))):
                            e_ = (lerp(p0[0], p1[0], prog), lerp(p0[1], p1[1], prog))
                            dx.line([p0, e_], fill=(20, 0, 0, 200), width=46)
                            dx.line([p0, e_], fill=(235, 40, 40, 255), width=34)
                fr.alpha_composite(xm)
            if s.get("xmark"):
                xm = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                dx = ImageDraw.Draw(xm)
                cx_, cy_, r_ = CX, int(s.get("xy", BOX_Y + 560)), 330
                for k_, (p0, p1) in enumerate((((cx_ - r_, cy_ - r_), (cx_ + r_, cy_ + r_)), ((cx_ + r_, cy_ - r_), (cx_ - r_, cy_ + r_)))):
                    prog = ease((i - 4 - k_ * 5) / 4)
                    if prog > 0:
                        e_ = (lerp(p0[0], p1[0], prog), lerp(p0[1], p1[1], prog))
                        dx.line([p0, e_], fill=(20, 0, 0, 200), width=86)
                        dx.line([p0, e_], fill=(235, 40, 40, 255), width=66)
                fr.alpha_composite(xm)
            # shake
            if s.get("shake"):
                amp = 10 * (1 - t) + 3
                dx, dy = rnd.uniform(-amp, amp), rnd.uniform(-amp, amp)
                fr = fr.transform(fr.size, Image.AFFINE, (1, 0, dx, 0, 1, dy), resample=Image.BILINEAR)
            # transition in
            kind = s.get("in", "punch")
            if kind == "punch" and i < 6:
                z = 1.0 + 0.10 * (1 - ease(i / 5))
                bw, bh = W / z, H / z
                fr = fr.resize((W, H), Image.BICUBIC, box=((W - bw) / 2, (H - bh) / 2, (W + bw) / 2, (H + bh) / 2))
            elif kind == "whip" and i < 6 and shot_prev is not None:
                # the new shot slides in from the right and pushes the last frame out to the left (motion-blurred, never black)
                off = int(W * (1 - ease((i + 1) / 6)) ** 1.6)
                if off > 0:
                    k = max(1, off // 24)
                    old = shot_prev.filter(ImageFilter.BoxBlur(k))
                    new = fr.filter(ImageFilter.BoxBlur(k))
                    fr = Image.new("RGBA", (W, H), (0, 0, 0, 255))
                    fr.paste(old.crop((W - off, 0, W, H)), (0, 0))
                    fr.paste(new.crop((0, 0, W - off, H)), (off, 0))
            last = fr
            # band + caption
            fr = fr.copy()
            fr.alpha_composite(band, (0, 0))
            # chip / big word: drawn after the transition, so a whip never slides a word off the frame (user 2026-10-07)
            ch = s.get("chip")
            if ch:
                pill = chip_img(ch)
                chip_y = int(s.get("chip_y", SAFE[1] + 90 if int(s.get("cap_y", 9999)) > 800 else int(s["cap_y"]) + 175))
                # left-aligned, far enough in that the pop (x 1.1 around its centre) never crosses the safe edge
                paste_center(fr, pill, SAFE[0] + 14 + pill.width * 0.55, chip_y, pop_scale(i),
                             check=(safe_log, "chip", fi) if check_on else None)
            hb = s.get("hl_box")  # a pulsing glow around one button of a card shot (x0, y0, x1, y1 in the 9:16 frame)
            if hb:
                pulse = 0.5 + 0.5 * math.sin(fi / FPS * 2 * math.pi * 2.0)
                ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                dv = ImageDraw.Draw(ov)
                hc = hexrgb(s.get("hl_col", "#FFD650"))[:3]
                pad = int(6 + 10 * pulse)
                for wd, al in ((22, 50), (12, 110), (6, 255)):
                    dv.rounded_rectangle([hb[0] - pad, hb[1] - pad, hb[2] + pad, hb[3] + pad], radius=26,
                                         outline=hc + (int(al * (0.55 + 0.45 * pulse)),), width=wd)
                fr.alpha_composite(ov.filter(ImageFilter.GaussianBlur(2)))
            bg_ = s.get("big")
            if bg_:
                txt = fill(bg_["text"])
                col_ = NEON.get(bg_.get("color")) or hexrgb(bg_.get("color", "#FFD650"))[:3]
                if style == "neon":   # centred on the frame like the captions, fitted for the pop peak (x 1.1)
                    img_ = neon_img([(txt, col_)], neon_fit(txt, int(2 * (SAFE[2] - CAPX) / 1.1) - 44, bg_.get("size", 170)))
                    paste_center(fr, img_, CAPX, min(SAFE[3] - 110, max(SAFE[1] + 90, bg_.get("y", BOX_Y + 260))), pop_scale(i),
                                 check=(safe_log, "big", fi) if check_on else None)
                else:
                    img_ = text_img([(txt, col_)], fit_size(txt, 860, bg_.get("size", 150)))
                    paste_center(fr, img_, CX, min(SAFE[3] - 110, max(SAFE[1] + 90, bg_.get("y", BOX_Y + 260))), pop_scale(i))
            tt = fi / FPS
            for c in caps:
                if c["start"] <= tt < c["end"]:
                    k = int((tt - c.get("pop_from", c["start"])) * FPS)
                    cy_ = int(s.get("cap_y", cap_y))
                    if style == "neon":
                        img_ = c["img"]
                        # keep a two-line caption fully above the bottom safe edge / below the top edge
                        cy_ = min(cy_, SAFE[3] - 10 - img_.height // 2 + 40) if cy_ > 800 else max(cy_, SAFE[1] + 10 + img_.height // 2 - 40)
                        sc = CAP_POP[k] if k < len(CAP_POP) else 1.0
                        paste_center(fr, img_, CAPX, cy_, sc, check=(safe_log, "caption", fi) if check_on else None)
                        if c.get("emoji"):   # the emoji floats above (or, for a top caption, below) the line, never inside it
                            em = emoji_img(c["emoji"])
                            ey = cy_ - img_.height // 2 - 10 if cy_ > 800 else cy_ + img_.height // 2 + 20
                            paste_center(fr, em, CAPX, ey, sc, check=(safe_log, "emoji", fi) if check_on else None)
                    else:
                        paste_center(fr, c["img"], CAP_CX, cy_, pop_scale(k))
                    break
            if kind == "flash" and i < 5:
                a = [0.85, 0.6, 0.35, 0.18, 0.06][i]
                fr = Image.blend(fr, Image.new("RGBA", (W, H), (255, 255, 255, 255)), a)
            enc.stdin.write(fr.convert("RGB").tobytes())
        if reader:
            reader.close()
    enc.stdin.close()
    if enc.wait() != 0:
        raise RuntimeError("encode failed")
    if check_on:   # every caption / emoji / big word / chip box of every frame inside the Shorts safe area
        bad = [(f_, k_, b_) for f_, k_, b_ in safe_log if b_[0] < SAFE[0] or b_[1] < SAFE[1] or b_[2] > SAFE[2] or b_[3] > SAFE[3]]
        rep_ = {"safe": SAFE, "frames": nframes, "boxes": len(safe_log), "outside": len(bad),
                "worst": sorted(bad, key=lambda r: -max(SAFE[0] - r[2][0], SAFE[1] - r[2][1], r[2][2] - SAFE[2], r[2][3] - SAFE[3]))[:20],
                "extent": [min(b[0] for _, _, b in safe_log), min(b[1] for _, _, b in safe_log),
                           max(b[2] for _, _, b in safe_log), max(b[3] for _, _, b in safe_log)] if safe_log else None,
                "fps": FPS, "log": [[f_, k_, list(b_)] for f_, k_, b_ in safe_log]}   # every box, for tools/devlog_safe_sheet.py
        json.dump(rep_, open(os.path.join(out_dir, "safe_check.json"), "w"), indent=1)
        print("safe-area check: %d boxes in %d frames, outside %d, extent %s" % (len(safe_log), nframes, len(bad), rep_["extent"]), flush=True)
        if bad:
            raise RuntimeError("caption / overlay outside the Shorts safe area: %s" % rep_["worst"][:5])
    run([FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-i", final, "-vf",
         "drawbox=x=%d:y=%d:w=%d:h=%d:color=red@0.9:t=8,fps=%s,scale=%d:-2,tile=%dx%d"
         % (SAFE[0], SAFE[1], SAFE[2] - SAFE[0], SAFE[3] - SAFE[1], CHECK[0], CHECK[1], CHECK[2], math.ceil(total * CHECK[0] / CHECK[2])),
         "-frames:v", "1", os.path.join(out_dir, "check_sheet.png")])
    m = short.get("meta", {})
    dur = probe_duration(final)
    open(os.path.join(out_dir, "meta.txt"), "w", encoding="utf-8").write(
        "TITLE (EN): %s\n제목 (KO): %s\n\nDESCRIPTION (EN):\n%s\n\n설명 (KO): %s\n\nHASHTAGS: %s\n\nLENGTH %.1f s · 1080x1920 · 30 fps · beta in %d days (built %s KST)\n"
        % (m.get("title_en", ""), m.get("title_ko", ""), m.get("desc_en", ""), m.get("desc_ko", ""), " ".join(m.get("tags", [])),
           dur, days_left(), dt.datetime.now(dt.timezone(dt.timedelta(hours=9))).strftime("%Y-%m-%d %H:%M")))
    print("%s  %.1fs  %.1f MB" % (final, dur, os.path.getsize(final) / 1e6), flush=True)
    return final


_SPRITES = {}


def _sprites(spec, n):
    """icons scattered for rain / float: (image, x, y0, speed px/frame, degrees/frame)"""
    key = json.dumps(spec, sort_keys=True) + str(n)
    if key not in _SPRITES:
        rng = random.Random(11)
        base = load_rgba(spec["icon"])
        out = []
        for k in range(int(spec.get("count", 16))):
            sz = rng.randint(int(spec.get("min", 90)), int(spec.get("max", 170)))
            im = contain(base, sz, sz)
            x = rng.randint(60, W - 60)
            sp = rng.uniform(22, 40) * float(spec.get("speed", 1.0))
            y0 = (-rng.randint(80, 1400)) if spec.get("down", True) else (H + rng.randint(80, 900))
            if "float" in spec.get("mode", ""):
                y0 = H + rng.randint(40, 900)
            out.append((im, x, y0, sp, rng.uniform(-6, 6) if spec.get("spin", True) else 0))
        _SPRITES[key] = out
    return _SPRITES[key]


_CHIPS = {}


def chip_img(ch):
    key = (ch["icon"], ch["text"])
    if key not in _CHIPS:
        f = font(60)
        tw = int(f.getlength(ch["text"]))
        pill = rounded((tw + 190, 124), 62, (20, 18, 40, 235), outline=GOLD + (255,), width=6)
        ic = contain(load_rgba(ch["icon"]), 94, 94)
        pill.alpha_composite(ic, (24, (124 - ic.height) // 2))
        ImageDraw.Draw(pill).text((140, 64), ch["text"], font=f, fill=WHITE + (255,), anchor="lm")
        _CHIPS[key] = pill
    return _CHIPS[key]


def srt_time(t):
    ms = int(round(max(0.0, t) * 1000))
    h, ms = divmod(ms, 3600000)
    m, ms = divmod(ms, 60000)
    s, ms = divmod(ms, 1000)
    return "%02d:%02d:%02d,%03d" % (h, m, s, ms)


def write_srts(timeline, out_dir):
    en, ko = [], []
    timeline = [it for it in timeline if (it["line"].get("srt") or not it["line"].get("silent")) and it["line"].get("cap") is not False
                or it["line"].get("srt")]
    for n, it in enumerate(timeline, 1):
        end_ = it["speech_end"] + 0.05 if not it["line"].get("silent") else it["start"] + float(it["line"]["silent"])
        span = "%s --> %s" % (srt_time(it["start"]), srt_time(end_))
        en.append("%d\n%s\n%s\n" % (n, span, fill(it["line"]["en"])))
        ko.append("%d\n%s\n%s\n" % (n, span, fill(it["line"]["ko"])))
    open(os.path.join(out_dir, "en.srt"), "w", encoding="utf-8").write("\n".join(en))
    open(os.path.join(out_dir, "ko.srt"), "w", encoding="utf-8").write("\n".join(ko))


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    plan_id = sys.argv[1]
    plan = json.load(open(os.path.join(ROOT, "docs", "devlog", plan_id + "_plan.json"), encoding="utf-8"))
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    out_root = os.path.join(ROOT, "build", "devlog", plan_id)
    for s in plan["shorts"]:
        if only and s["id"] != only:
            continue
        build_short(s, plan["voice"], out_root, do_tts="--no-tts" not in sys.argv)


if __name__ == "__main__":
    main()
