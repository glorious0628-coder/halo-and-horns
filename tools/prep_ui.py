"""
GPT가 만든 UI 부품(art/out/UIP_*.png)을 게임용으로 다듬는다 → art/ui/<이름>.png + art/ui/ui_meta.json

  py tools/prep_ui.py            -> 전부
  py tools/prep_ui.py UIP_PanelCard UIP_IconCoin

- 투명 여백을 잘라 낸다 (알파 > 8 인 영역 + 2px).
- 크기를 줄인다: 틀(9-slice)·버튼 512px, 아이콘 256px (긴 변 기준).
- 9-slice 틀은 가운데 색에서 바깥으로 테두리 두께를 재서 SliceCenter(left, top, right, bottom)를 기록한다.
"""

import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "out")
DST = os.path.join(ROOT, "art", "ui")

FRAMES = {"UIP_PanelParchment", "UIP_PanelCard", "UIP_RibbonHeader", "UIP_Pill", "UIP_BarTrack", "UIP_BtnSquare"}
BIG = {"UIP_BtnAttack", "UIP_BtnSpecial", "UIP_LevelBadge", "UIP_PortraitRing", "UIP_ShieldHalo", "UIP_ShieldHorns"}


def crop_alpha(im):
    a = im.getchannel("A").point(lambda v: 255 if v > 8 else 0)
    box = a.getbbox()
    if not box:
        return im
    l, t, r, b = box
    return im.crop((max(0, l - 2), max(0, t - 2), min(im.width, r + 2), min(im.height, b + 2)))


def close(c1, c2, tol=28):
    return all(abs(int(x) - int(y)) <= tol for x, y in zip(c1[:3], c2[:3])) and c1[3] > 200


def border_line(im, axis, from_start, at, center):
    w, h = im.size
    n = w if axis == "x" else h
    run = 0
    rng = range(n // 2) if from_start else range(n - 1, n // 2, -1)
    for i, p in enumerate(rng):
        px = im.getpixel((p, at)) if axis == "x" else im.getpixel((at, p))
        if close(px, center):
            run += 1
            if run >= 6:
                return i - run + 1
        else:
            run = 0
    return n // 4


def border(im, axis, from_start):
    """distance from an edge to where the flat interior color starts; the max over three scan lines (20/50/80 %)
    so rounded corners (capsule ends) stay inside the fixed slice"""
    w, h = im.size
    center = im.getpixel((w // 2, h // 2))
    other = h if axis == "x" else w
    return max(border_line(im, axis, from_start, int(other * f), center) for f in (0.2, 0.5, 0.8))


def main(names):
    os.makedirs(DST, exist_ok=True)
    meta_path = os.path.join(DST, "ui_meta.json")
    meta = json.load(open(meta_path, encoding="utf-8")) if os.path.exists(meta_path) else {}
    if not names:
        names = sorted(f[:-4] for f in os.listdir(SRC) if f.startswith("UIP_") and f.endswith(".png"))
    for name in names:
        src = os.path.join(SRC, name + ".png")
        if not os.path.exists(src):
            print("없음", name)
            continue
        im = crop_alpha(Image.open(src).convert("RGBA"))
        limit = 512 if (name in FRAMES or name in BIG) else 256
        scale = min(1.0, limit / max(im.size))
        if scale < 1.0:
            im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
        im.save(os.path.join(DST, name + ".png"))
        info = {"w": im.width, "h": im.height}
        if name in FRAMES:
            pad = 3
            l = border(im, "x", True) + pad
            r = border(im, "x", False) + pad
            t = border(im, "y", True) + pad
            b = border(im, "y", False) + pad
            # Roblox SliceCenter = Rect(left, top, width - right, height - bottom)
            info["slice"] = [l, t, im.width - r, im.height - b]
        meta[name] = info
        print(name, info)
    json.dump(meta, open(meta_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main(sys.argv[1:])
