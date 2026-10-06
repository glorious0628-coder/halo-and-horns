"""Render a HUD gray-box layout spec onto a dimmed in-game screenshot (PC 1280x720 + phone 749x361).

Usage:
  py tools/render_graybox.py <layout.json> <out_prefix> [--bg <screenshot>]

layout.json: { "name", "items": [{id, label_ko, group, pc:{x,y,w,h}, phone:{x,y,w,h}, key_hint?, shape? ("round")}],
               "reserved_zones": [{name_ko, pc:{...}, phone:{...}}] }
Writes <out_prefix>_pc.png, <out_prefix>_phone.png and <out_prefix>_sheet.png.
Also prints overlaps between items (same screen) so the spec can be fixed before showing it.
"""
import argparse
import json

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = "C:/Windows/Fonts/malgunbd.ttf"
PALETTE = [
    (70, 130, 220), (230, 160, 40), (60, 170, 110), (170, 90, 200), (220, 80, 80),
    (40, 170, 190), (200, 120, 60), (120, 120, 140), (210, 190, 60), (90, 100, 210),
]


def font(size):
    return ImageFont.truetype(FONT, max(9, int(size)))


def bg_image(path, w, h):
    if path:
        im = Image.open(path).convert("RGB")
        scale = max(w / im.width, h / im.height)
        im = im.resize((int(im.width * scale + 0.5), int(im.height * scale + 0.5)), Image.LANCZOS)
        left, top = (im.width - w) // 2, (im.height - h) // 2
        im = im.crop((left, top, left + w, top + h))
        im = im.filter(ImageFilter.GaussianBlur(9))
        dark = Image.new("RGB", (w, h), (20, 24, 36))
        return Image.blend(im, dark, 0.68)
    return Image.new("RGB", (w, h), (40, 44, 56))


def fit_text(draw, text, w, h, start):
    size = start
    while size > 9:
        f = font(size)
        lines = wrap(draw, text, f, w - 6)
        lh = f.getbbox("가")[3] + 2
        if lh * len(lines) <= h - 4:
            return f, lines, lh
        size -= 1
    f = font(9)
    return f, wrap(draw, text, f, w - 6)[:2], f.getbbox("가")[3] + 2


def wrap(draw, text, f, maxw):
    out, cur = [], ""
    for ch in text:
        if draw.textlength(cur + ch, font=f) <= maxw or not cur:
            cur += ch
        else:
            out.append(cur)
            cur = ch
    if cur:
        out.append(cur)
    return out


def rect_of(r):
    return r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"]


def overlaps(items, key):
    found = []
    for i in range(len(items)):
        for j in range(i + 1, len(items)):
            a, b = items[i].get(key), items[j].get(key)
            if not a or not b or a["w"] <= 0 or b["w"] <= 0:
                continue
            ax0, ay0, ax1, ay1 = rect_of(a)
            bx0, by0, bx1, by1 = rect_of(b)
            if ax0 < bx1 and bx0 < ax1 and ay0 < by1 and by0 < ay1:
                found.append((items[i]["id"], items[j]["id"]))
    return found


def render(spec, key, w, h, bg, scale_font):
    im = bg_image(bg, w, h).convert("RGBA")
    over = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for z in spec.get("reserved_zones", []):
        r = z.get(key)
        if not r or r["w"] <= 0:
            continue
        x0, y0, x1, y1 = rect_of(r)
        d.rectangle((x0, y0, x1, y1), fill=(255, 60, 60, 40), outline=(255, 90, 90, 200), width=2)
        for k in range(int(x0) - int(y1 - y0), int(x1), 14):
            d.line((max(k, x0), y0 + max(0, x0 - k), min(k + (y1 - y0), x1), y0 + min(y1 - y0, x1 - k)), fill=(255, 90, 90, 60), width=1)
        d.text((x0 + 4, y1 - 4), z["name_ko"], font=font(12 * scale_font), fill=(255, 170, 170, 255), anchor="ld")
    groups = {}
    for it in spec["items"]:
        r = it.get(key)
        if not r or r["w"] <= 0 or r["h"] <= 0:
            continue
        g = it.get("group", "")
        col = groups.setdefault(g, PALETTE[len(groups) % len(PALETTE)])
        x0, y0, x1, y1 = rect_of(r)
        if it.get("shape") == "round":
            d.ellipse((x0, y0, x1, y1), fill=col + (150,), outline=(255, 255, 255, 230), width=2)
        else:
            d.rounded_rectangle((x0, y0, x1, y1), radius=min(8, r["h"] / 3), fill=col + (150,), outline=(255, 255, 255, 230), width=2)
        label = it["label_ko"] + (f" [{it['key_hint']}]" if it.get("key_hint") and key == "pc" else "")
        f, lines, lh = fit_text(d, label, r["w"], r["h"], 15 * scale_font)
        ty = y0 + (r["h"] - lh * len(lines)) / 2
        for ln in lines:
            d.text(((x0 + x1) / 2, ty), ln, font=f, fill=(255, 255, 255, 255), anchor="mt", stroke_width=2, stroke_fill=(20, 24, 40, 255))
            ty += lh
    im.alpha_composite(over)
    title = f"{spec.get('name', 'layout')} · {'PC 1280×720' if key == 'pc' else '폰 749×361'}"
    ImageDraw.Draw(im).text((w - 8, h - 6), title, font=font(13 * scale_font), fill=(255, 255, 255, 200), anchor="rd")
    return im.convert("RGB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("spec")
    ap.add_argument("out_prefix")
    ap.add_argument("--bg", default="docs/art/verification_2026-10-06/slime_cube_ingame_2026-10-06.jpg")
    args = ap.parse_args()
    spec = json.load(open(args.spec, encoding="utf-8"))
    pc = render(spec, "pc", 1280, 720, args.bg, 1.0)
    ph = render(spec, "phone", 749, 361, args.bg, 0.8)
    pc.save(args.out_prefix + "_pc.png")
    ph.save(args.out_prefix + "_phone.png")
    sheet = Image.new("RGB", (1280, 720 + 16 + 361), (24, 26, 34))
    sheet.paste(pc, (0, 0))
    sheet.paste(ph, ((1280 - 749) // 2, 736))
    sheet.save(args.out_prefix + "_sheet.png")
    for key in ("pc", "phone"):
        ov = overlaps(spec["items"], key)
        print(f"{key}: {len(ov)} overlaps", ov[:30])


if __name__ == "__main__":
    main()
