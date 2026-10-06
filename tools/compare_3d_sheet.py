"""
3D 도구 비교 시트: compare_3d_render.py 결과를 한 장에 모은다.

  py tools/compare_3d_sheet.py <render_dir> <out.png> "<subject>|<source.png>|<label1>,<label2>,..." ["<subject>|..."]

- 한 주제(subject)마다: 왼쪽 원본 그림, 오른쪽에 도구별 한 줄(앞 3/4, 뒤 3/4, 게임 카메라, 같은 면 수로 줄인 게임 카메라, 멀리서 본 크기).
- 줄 머리에 삼각형 수·텍스처 크기·파일 크기를 적는다.
"""

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

RD, OUT = sys.argv[1], sys.argv[2]
SPECS = sys.argv[3:]
CELL = 300
HEAD = 230
BG = (200, 204, 210)
FONT = "C:/Windows/Fonts/malgunbd.ttf"
f_big = ImageFont.truetype(FONT, 26)
f_mid = ImageFont.truetype(FONT, 19)
f_small = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 16)
META_P = os.path.join(RD, "meta.json")
META = json.load(open(META_P, encoding="utf-8")) if os.path.exists(META_P) else {}
NAMES = {"tripoH31": "Tripo H3.1", "tripoP1": "Tripo P1", "meshy": "Meshy"}
COLS = [("front34", "앞 3/4"), ("back34", "뒤 3/4"), ("game", "게임 카메라"), ("game_dec", "같은 면 수"), ("far", "멀리서")]


def render(label, view):
    p = os.path.join(RD, f"{label}_{view}.png")
    if not os.path.exists(p):
        return None
    im = Image.open(p).convert("RGBA")
    bg = Image.new("RGBA", im.size, BG + (255,))
    bg.alpha_composite(im)
    return bg.convert("RGB")


blocks = []
for spec in SPECS:
    subject, src, labels = spec.split("|", 2)
    labels = [l for l in labels.split(",") if l]
    w = HEAD + CELL + len(COLS) * CELL + 40
    h = 50 + len(labels) * (CELL + 20)
    blk = Image.new("RGB", (w, h), (248, 246, 240))
    d = ImageDraw.Draw(blk)
    d.text((20, 10), subject, font=f_big, fill=(20, 30, 60))
    if src and os.path.exists(src):
        s = Image.open(src).convert("RGB")
        s.thumbnail((CELL, CELL))
        blk.paste(s, (20, 55))
        d.text((20, 55 + s.size[1] + 6), "원본 그림", font=f_small, fill=(60, 60, 60))
    for r, label in enumerate(labels):
        y = 50 + r * (CELL + 20)
        x0 = 20 + CELL + 20
        tool = label.split("_", 1)[1] if "_" in label else label
        st_p = os.path.join(RD, f"{label}_stats.json")
        st = json.load(open(st_p)) if os.path.exists(st_p) else {}
        d.text((x0, y + 8), NAMES.get(tool, tool), font=f_mid, fill=(20, 30, 60))
        lines = [f"삼각형 {st.get('tris', '?'):,}" if isinstance(st.get('tris'), int) else "삼각형 ?",
                 f"텍스처 {', '.join(st.get('images', [])) or '?'}",
                 f"파일 {st.get('bytes', 0) / 1048576:.1f}MB",
                 f"재질 {st.get('materials', '?')} · 물체 {st.get('objects', '?')}"]
        if st.get("dec_tris"):
            lines.append(f"줄인 판 {st['dec_tris']:,}")
        m = META.get(label, {})
        if m:
            lines.append(f"비용 {m.get('cost', '?')} · {m.get('seconds', '?')}초")
        for i, t in enumerate(lines):
            d.text((x0, y + 40 + i * 24), t, font=f_small, fill=(50, 50, 50))
        for c, (view, title) in enumerate(COLS):
            cx = x0 + HEAD + c * CELL
            if view == "far":
                g = render(label, "game_dec") or render(label, "game")
                if g is None:
                    continue
                small = g.resize((72, 72), Image.LANCZOS)
                tile = Image.new("RGB", (CELL - 10, CELL - 10), BG)
                tile.paste(small, ((CELL - 10 - 72) // 2, (CELL - 10 - 72) // 2))
                blk.paste(tile, (cx, y + 5))
            else:
                v = view.replace("_dec", "")
                g = render(label, v + ("_dec" if view.endswith("_dec") else ""))
                if g is None and view.endswith("_dec"):
                    g = render(label, v)  # already under the face limit
                if g is None:
                    continue
                blk.paste(g.resize((CELL - 10, CELL - 10), Image.LANCZOS), (cx, y + 5))
            if r == 0:
                d.text((cx + 6, y - 22 if y > 30 else 28), title, font=f_small, fill=(80, 80, 80))
    blocks.append(blk)

W = max(b.size[0] for b in blocks)
H = sum(b.size[1] for b in blocks) + 70
sheet = Image.new("RGB", (W, H), (248, 246, 240))
ImageDraw.Draw(sheet).text((20, 18), "3D 도구 비교 — 같은 그림, 같은 조명·카메라·크기 (A23-47)", font=f_big, fill=(20, 30, 60))
y = 70
for b in blocks:
    sheet.paste(b, (0, y))
    y += b.size[1]
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
sheet.save(OUT)
print("sheet", OUT, sheet.size)
