"""
Bark bubble text boxes vs the real lines (A23-74, 0 credits).

  py tools/img2/bark_textrect.py check            how big each kind's lines come out in game with its TextRect
  py tools/img2/bark_textrect.py fit [--min 14]   for kinds whose smallest line is below --min px (or overflows), search the
                                                  cream middle for a wider box and print the new TextRect
  py tools/img2/bark_textrect.py sheet <out.jpg> [Kind=x,y,w,h ...]   game-size preview (x3) of every line, old vs new box

Game rules copied from MonsterLabels.luau (origin/main 2026-10-07): the bubble is ArtW 104 px wide, its height =
104 x H/W clamped to 60..104; the TextLabel = TextRect fractions of it, TextWrapped + TextScaled between TextMin 12
and TextMax 26, LineHeight 0.9 (Roblox clamps it to 1.0), font = UIKit 'Head' = Denk One. Lines = Config.Barks.Lines of
the kind + the Golden lines (a golden monster of any kind). Words wrap at spaces; a word wider than the box overflows.
"""
import json
import re
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ROOT = "C:/Users/glori/Documents/Roblox/Game/"
FONT = "C:/Users/glori/AppData/Local/Roblox/Versions/version-76e1a02649ad4f35/content/fonts/DenkOne-Regular.ttf"
ART_W, H_MIN, H_MAX, T_MIN, T_MAX, LINE = 104, 60, 104, 12, 26, 1.0
KINDS = ["Slime", "BigSlime", "PumpkinSlime", "PumpkinKing", "LittleGhost", "GhostMinion", "GhostKing", "Goblin",
         "GoblinBrute", "BatGoblin", "Skeleton", "SkeletonKnight"]
sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def config_text():
    return subprocess.run(["git", "show", "origin/main:src/ReplicatedStorage/Shared/Config.luau"], cwd=ROOT, capture_output=True,
                          text=True, encoding="utf-8").stdout


def bark_lines(cfg):
    body = cfg[cfg.index("Config.Barks = {"):]
    body = body[body.index("Lines = {"):]
    out, cur = {}, None
    for ln in body.splitlines()[1:]:
        m = re.match(r"\s*(\w+) = \{\s*(--.*)?$", ln)
        if m:
            cur = m.group(1)
            out[cur] = []
            continue
        if cur:
            out[cur] += re.findall(r'"([^"]*)"', ln.split("--")[0])
        if re.match(r"\t}\s*,?\s*$", ln):
            break
    return out


def art_rects(cfg):
    out = {}
    for k in KINDS:
        m = re.search(r"BarkBubble" + k + r" = \{[^}]*Size = Vector2.new\((\d+), (\d+)\), TextRect = \{ ([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+) \}", cfg)
        out[k] = ((int(m.group(1)), int(m.group(2))), [float(m.group(i)) for i in range(3, 7)])
    return out


def bubble_px(size):
    w, h = size
    return ART_W, int(min(max(np.floor(ART_W * h / w + 0.5), H_MIN), H_MAX))


def wrap(font, text, width):
    words, lines, cur = text.split(" "), [], ""
    for wd in words:
        t = (cur + " " + wd).strip()
        if not cur or font.getlength(t) <= width:
            cur = t
        else:
            lines.append(cur)
            cur = wd
    lines.append(cur)
    return lines


def fit_size(text, bw, bh):
    """largest size T_MIN..T_MAX whose wrapped lines fit bw x bh; (T_MIN, True) = overflows even at the minimum"""
    for s in range(T_MAX, T_MIN - 1, -1):
        f = ImageFont.truetype(FONT, s)
        ls = wrap(f, text, bw)
        if max(f.getlength(t) for t in ls) <= bw and len(ls) * s * LINE <= bh:
            return s, False, ls
    f = ImageFont.truetype(FONT, T_MIN)
    return T_MIN, True, wrap(f, text, bw)


def check_kind(kind, rect, size, lines):
    bw_, bh_ = bubble_px(size)
    bw, bh = rect[2] * bw_, rect[3] * bh_
    res = [(t,) + fit_size(t, bw, bh)[:2] for t in lines]
    return (bw_, bh_), (bw, bh), res


def cream_mask(kind):
    im = np.asarray(Image.open(ROOT + f"art/ui/BarkBubble{kind}.png").convert("RGBA")).astype(int)
    rgb, al = im[..., :3], im[..., 3]
    m = (al > 250) & (rgb.min(-1) > 215) & ((rgb.max(-1) - rgb.min(-1)) < 40)
    lab, n = ndimage.label(m)
    H, W = m.shape
    mid = lab[H // 4:3 * H // 4, W // 4:3 * W // 4]
    cnt = np.bincount(mid.ravel(), minlength=n + 1)
    cnt[0] = 0
    return ndimage.binary_fill_holes(lab == int(np.argmax(cnt)))


_F100 = None


def line_widths(text):
    """minimal widest-line width at size 100 for 1..n lines (word wrap at spaces): {n: width}"""
    global _F100
    if _F100 is None:
        _F100 = ImageFont.truetype(FONT, 100)
    words = text.split(" ")
    out = {}
    n = len(words)
    for k in range(1, n + 1):  # split into k lines: try every split (barks have <= 4 words)
        best = None
        from itertools import combinations
        for cut in combinations(range(1, n), k - 1):
            parts, prev = [], 0
            for c in list(cut) + [n]:
                parts.append(" ".join(words[prev:c]))
                prev = c
            w = max(_F100.getlength(p) for p in parts)
            best = w if best is None else min(best, w)
        out[k] = best
    return out


def fast_size(lw, bw, bh):
    """biggest size for a box (bw x bh px) from line_widths(): (size, overflow)"""
    s = 0.0
    for k, w in lw.items():
        s = max(s, min(bw / (w / 100), bh / (k * LINE)))
    s = min(int(s), T_MAX)
    return (s, False) if s >= T_MIN else (T_MIN, True)


def best_rect(kind, size, lines, margin=0.035, step=6):
    """the box inside the cream middle (eroded by margin x width) that gives the biggest smallest-line size,
    then the biggest total, then centred; returns (score, fractions [x, y, w, h])"""
    m = cream_mask(kind)
    H, W = m.shape
    e = ndimage.binary_erosion(m, iterations=max(1, int(margin * W)))
    cs = np.vstack([np.zeros((1, W), int), np.cumsum(e, 0)])
    bw_, bh_ = bubble_px(size)
    sx, sy = bw_ / W, bh_ / H
    LW = [line_widths(t) for t in lines]
    best = None
    for y0 in range(0, H, step):
        for y1 in range(y0 + 6 * step, H, step):
            full = (cs[y1] - cs[y0]) == (y1 - y0)
            if not full.any():
                continue
            d = np.diff(np.r_[0, full.astype(int), 0])
            starts, ends = np.where(d == 1)[0], np.where(d == -1)[0]
            k = int(np.argmax(ends - starts))
            x0, x1 = starts[k], ends[k]
            bw, bh = (x1 - x0) * sx, (y1 - y0) * sy
            sizes = [fast_size(lw, bw, bh) for lw in LW]
            # no line may overflow; then the biggest total (short words stay big), then the smallest line, centred
            score = (not any(o for _, o in sizes), sum(z for z, _ in sizes), min(z for z, _ in sizes), -abs((y0 + y1) / 2 - H * 0.5))
            if best is None or score > best[0]:
                best = (score, [round(float(x0) / W, 3), round(float(y0) / H, 3), round(float(x1 - x0) / W, 3), round(float(y1 - y0) / H, 3)])
    return best


if __name__ == "__main__":
    cfg = config_text()
    L = bark_lines(cfg)
    R = art_rects(cfg)
    gold = L.get("Golden", [])
    mode = sys.argv[1] if len(sys.argv) > 1 else "check"
    lim = int(sys.argv[sys.argv.index("--min") + 1]) if "--min" in sys.argv else 14
    if mode in ("check", "fit"):
        for k in KINDS:
            size, rect = R[k]
            lines = L[k] + gold
            bub, box, res = check_kind(k, rect, size, lines)
            worst = min(res, key=lambda r: (not r[2], r[1]))
            over = [t for t, s, o in res if o]
            print(f"{k:15s} bubble {bub[0]}x{bub[1]} box {box[0]:.0f}x{box[1]:.0f}px  smallest {worst[1]}px ({worst[0]!r})"
                  + (f"  OVERFLOW {over}" if over else ""))
            if mode == "fit" and (over or worst[1] < lim):
                b = best_rect(k, size, lines)
                nb = (b[1][2] * bub[0], b[1][3] * bub[1])
                print(f"   -> new TextRect {b[1]}  box {nb[0]:.0f}x{nb[1]:.0f}px  fits {b[0][0]}  total {b[0][1]}  smallest {b[0][2]}px")
    elif mode == "sheet":
        out = sys.argv[2]
        new = {a.split("=")[0]: [float(v) for v in a.split("=")[1].split(",")] for a in sys.argv[3:] if "=" in a}
        Z = 3
        F = ImageFont.truetype("C:/Windows/Fonts/malgunbd.ttf", 16)
        rows = []
        for k in KINDS:
            size, rect = R[k]
            lines = L[k] + gold
            bub = bubble_px(size)
            art = Image.open(ROOT + f"art/ui/BarkBubble{k}.png").convert("RGBA").resize((bub[0] * Z, bub[1] * Z), Image.LANCZOS)
            for tag, rc in (("now", rect), ("new", new.get(k))):
                if rc is None:
                    continue
                cells = []
                for t in lines:
                    c = Image.new("RGBA", art.size, (96, 150, 70, 255))
                    c.alpha_composite(art)
                    d = ImageDraw.Draw(c)
                    bw, bh = rc[2] * bub[0], rc[3] * bub[1]
                    s, o, ls = fit_size(t, bw, bh)
                    f = ImageFont.truetype(FONT, s * Z)
                    x0, y0 = rc[0] * bub[0] * Z, rc[1] * bub[1] * Z
                    d.rectangle((x0, y0, x0 + bw * Z, y0 + bh * Z), outline=(255, 60, 60, 160), width=1)
                    yy = y0 + (bh * Z - len(ls) * s * Z * LINE) / 2
                    for ln in ls:
                        d.text((x0 + (bw * Z - f.getlength(ln)) / 2, yy), ln, font=f, fill=(28, 36, 82, 255))
                        yy += s * Z * LINE
                    cells.append((c.convert("RGB"), f"{s}px" + (" 넘침" if o else "")))
                rows.append((f"{k} · {tag}  box {bw:.0f}x{bh:.0f}px", cells))
        cw = ART_W * Z + 8
        maxc = max(len(c) for _, c in rows)
        ch = max(c[0][0].height for _, c in rows) + 24
        sheet = Image.new("RGB", (20 + maxc * cw, 50 + len(rows) * (ch + 26)), (250, 245, 236))
        d = ImageDraw.Draw(sheet)
        d.text((20, 12), "말풍선 글자 칸 × 실제 대사 (게임 크기 104px의 3배, Denk One, 12~26px 자동) — 빨간 테 = 글자 칸", font=ImageFont.truetype("C:/Windows/Fonts/malgunbd.ttf", 20), fill=(24, 30, 64))
        y = 50
        for title, cells in rows:
            d.text((20, y), title, font=F, fill=(24, 30, 64) if "now" in title else (170, 40, 40))
            for i, (im, cap) in enumerate(cells):
                sheet.paste(im, (20 + i * cw, y + 22))
                d.text((20 + i * cw + 2, y + 22 + im.height + 1), cap, font=F, fill=(170, 40, 40) if ("넘침" in cap or int(cap.split("px")[0]) < 14) else (24, 30, 64))
            y += ch + 26
        sheet.save(out, quality=90)
        print(out, sheet.size)
