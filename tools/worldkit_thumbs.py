"""
Creator Store 후보 썸네일을 한 장에 모아 보는 시트 (이미지 생성 1, 세계 소품 키트).

  py tools/worldkit_thumbs.py out.png "라벨=12345" "라벨2=67890" ...
  py tools/worldkit_thumbs.py out.png @candidates.txt      (줄마다 "라벨=ID")

thumbnails.roblox.com 420x420 PNG를 받아 4열 격자로 붙이고 아래에 라벨·ID를 쓴다.
"""

import io
import json
import sys
import urllib.request

from PIL import Image, ImageDraw, ImageFont

CELL = 300
COLS = 4
PAD = 8
LABEL_H = 44


def font(size):
    for name in ("malgunbd.ttf", "malgun.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def fetch_json(url):
    with urllib.request.urlopen(url, timeout=30) as r:
        return json.load(r)


def fetch_img(url):
    with urllib.request.urlopen(url, timeout=30) as r:
        return Image.open(io.BytesIO(r.read())).convert("RGBA")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    out = sys.argv[1]
    items = []
    for arg in sys.argv[2:]:
        if arg.startswith("@"):
            with open(arg[1:], encoding="utf-8") as f:
                lines = [l.strip() for l in f if l.strip() and not l.startswith("#")]
        else:
            lines = [arg]
        for l in lines:
            label, _, aid = l.rpartition("=")
            items.append((label.strip(), aid.strip()))
    urls = {}
    ids = [a for _, a in items]
    for i in range(0, len(ids), 50):
        chunk = ",".join(ids[i:i + 50])
        d = fetch_json(f"https://thumbnails.roblox.com/v1/assets?assetIds={chunk}&size=420x420&format=Png")
        for x in d.get("data", []):
            urls[str(x["targetId"])] = x.get("imageUrl")
    rows = (len(items) + COLS - 1) // COLS
    sheet = Image.new("RGB", (COLS * (CELL + PAD) + PAD, rows * (CELL + LABEL_H + PAD) + PAD), (236, 232, 222))
    draw = ImageDraw.Draw(sheet)
    f1, f2 = font(17), font(13)
    for i, (label, aid) in enumerate(items):
        x = PAD + (i % COLS) * (CELL + PAD)
        y = PAD + (i // COLS) * (CELL + LABEL_H + PAD)
        draw.rectangle([x, y, x + CELL, y + CELL], fill=(200, 205, 212))
        url = urls.get(aid)
        if url:
            try:
                im = fetch_img(url).resize((CELL, CELL), Image.LANCZOS)
                sheet.paste(im, (x, y), im)
            except Exception as e:  # noqa: BLE001
                draw.text((x + 8, y + 8), f"thumb fail {e}", fill=(160, 0, 0), font=f2)
        else:
            draw.text((x + 8, y + 8), "no thumb", fill=(160, 0, 0), font=f2)
        draw.text((x + 4, y + CELL + 3), label[:22], fill=(30, 30, 50), font=f1)
        draw.text((x + 4, y + CELL + 24), aid, fill=(90, 90, 100), font=f2)
    sheet.save(out)
    print(out, len(items), "items")


if __name__ == "__main__":
    main()
