"""Offline check of the Shop window (src/StarterPlayer/StarterPlayerScripts/ShopUI.luau, SPEC A23-75) on PC and phones.

Reads ShopUI's layout numbers (the `L` table), its words (T.Names / T.Lines / capsule words) and the pass prices, rebuilds
the window the way Panels sizes it (canvas = screen / UIScale, at most 780 x 600 du, the ribbon hanging 23 du over the
top, content 18 du in from the rim) and measures every text with the game's own fonts (Roblox Studio's Denk One and
Montserrat .ttf; Roblox's TextSize is the line height, so the em size = TextSize / (ascent + descent), checked against
UiSandbox TextBounds of the bark lines: within 3 %). Checks, on every screen:
  - the four pass cards sit in one row and the window needs no scrolling for them
  - each card name fits one line at >= 12 px (TextScaled from 22 du down to its StyleMinPx floor)
  - each card's lines wrap into the room above the capsule at the Body floor (14 px; PC floors shrink with the window)
  - every capsule word ('199 R$', 'Owned', 'Coming soon', '100 R$ / mo') fits one line at >= 16 px
Writes docs/art/verification_2026-10-08/shop_layout_offline_2026-10-08.json and a mock sheet (.png) drawn with the
approved art and the fonts - an approximation for the layout, the Studio photos are the real check.

  py tools/test_shop_layout.py
"""
import json
import math
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOP = os.path.join(ROOT, "src", "StarterPlayer", "StarterPlayerScripts", "ShopUI.luau")
CONFIG = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "Config.luau")
ART = os.path.join(ROOT, "art", "ui")
OUT_DIR = os.path.join(ROOT, "docs", "art", "verification_2026-10-08")
OUT_JSON = os.path.join(OUT_DIR, "shop_layout_offline_2026-10-08.json")
OUT_PNG = os.path.join(OUT_DIR, "shop_layout_offline_2026-10-08.png")
FONTS = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "Versions")

# screens: name, width, height, touch (Config.UI: touch UIScale = clamp(h / 720, 0.75, 1.25); desktop =
# clamp(h / 720 * 0.8, 0.5, 1.0); UIKit.PxFloor = 1 on touch, min(1, scale / 0.8) on desktop)
SCREENS = [
    ("pc_1280x720", 1280, 720, False),
    ("pc_991x451", 991, 451, False),
    ("pc_1920x1080", 1920, 1080, False),
    ("phone_749x361", 749, 361, True),
    ("phone_844x390", 844, 390, True),
    ("phone_667x375", 667, 375, True),
]
INSET = 58  # GuiService:GetGuiInset().Y with the 2023 Roblox top bar
# Panels (FRAME / GUARD / content list): window max size, ribbon, rim padding, list paddings
WIN_MAX_W, WIN_MAX_H, TITLE_H, PAD, BOTTOM, MIN_H = 780, 600, 46, 18, 16, 190
LIST_GAP, PAD_TOP, PAD_BOTTOM, PAD_LEFT, PAD_RIGHT = 10, 4, 12, 2, 6
NOTE_SIZE = 15  # kit.Text: max(size, GUARD.FixedTextMin 15), no style floor
# UIKit.TextStyles floors (real px) and the floors ShopUI lowers with StyleMinPx
FLOOR_BODY, FLOOR_BUTTON, NAME_MIN_PX, CAPS_MIN_PX = 14, 16, 12, 12
WIDTH_MARGIN = 1.03  # PIL widths ran up to 3 % under Studio's TextBounds


def find_font(name):
    if os.path.isdir(FONTS):
        for v in sorted(os.listdir(FONTS), reverse=True):
            p = os.path.join(FONTS, v, "content", "fonts", name)
            if os.path.exists(p):
                return p
    raise SystemExit("font not found: " + name + " (Roblox Studio installs it under %LOCALAPPDATA%\\Roblox\\Versions)")


class Face:
    def __init__(self, file):
        self.path = find_font(file)
        big = ImageFont.truetype(self.path, 1000)
        a, d = big.getmetrics()
        self.ratio = (a + d) / 1000
        self.cache = {}

    def font(self, text_size):
        em = max(1, round(text_size / self.ratio))
        if em not in self.cache:
            self.cache[em] = ImageFont.truetype(self.path, em)
        return self.cache[em]

    def width(self, text, text_size):
        f = ImageFont.truetype(self.path, max(1, round(text_size / self.ratio * 10)))
        return f.getlength(text) / 10 * WIDTH_MARGIN


HEAD = Face("DenkOne-Regular.ttf")
BODY = Face("Montserrat-Regular.ttf")


def ceil_floor(px, pxfloor, s):
    return max(1, math.ceil(px * pxfloor / s - 0.001))


def wrap(face, text, size, width):
    words, lines, cur = text.split(" "), [], ""
    for w in words:
        trial = (cur + " " + w) if cur else w
        if not cur or face.width(trial, size) <= width:
            cur = trial
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def scaled_size(face, text, max_size, min_size, box_w, box_h, wrapped=False):
    """TextScaled: the largest whole size <= max that fits the box (one line unless wrapped); None below the floor"""
    for size in range(int(max_size), int(min_size) - 1, -1):
        if wrapped:
            lines = wrap(face, text, size, box_w)
            if all(face.width(l, size) <= box_w for l in lines) and len(lines) * size <= box_h:
                return size, len(lines)
        elif face.width(text, size) <= box_w and size <= box_h:
            return size, 1
    return None, 0


def parse_shop():
    s = open(SHOP, encoding="utf-8").read()
    block = re.search(r"\nlocal L = \{(.*?)\n\}", s, re.S).group(1)
    L = {k: float(v) for k, v in re.findall(r"(\w+) = (-?[\d.]+)", block)}
    passes = re.findall(r'\{ Kind = "(\w+)", Badge = "\w+", Icon = "(\w+)", Slot = "(\w+)", Price = (\d+)(, Attr = "\w+")?(, Info = true)? \}', s)
    names = dict(re.findall(r'(\w+) = "([^"]+)"', re.search(r"Names = \{([^}]*)\}", s).group(1)))
    lines_block = re.search(r"Lines = \{(.*?)\n\t\}", s, re.S).group(1)
    lines = dict(re.findall(r'(\w+) = "([^"]+)"', lines_block))
    words = {k: re.search(r"\n\t" + k + r' = "([^"]+)"', s).group(1) for k in ("PriceF", "MonthF", "Owned", "Soon", "Note", "Title")}
    return L, [{"Kind": p[0], "Icon": p[1], "Slot": p[2], "Price": int(p[3]), "Info": bool(p[5])} for p in passes], names, lines, words


def part_files():
    """Config.UIArt part key -> (local png, slice rect or None, size) through art/ui/asset_ids.json"""
    cfg = open(CONFIG, encoding="utf-8").read()
    ids = json.load(open(os.path.join(ART, "asset_ids.json"), encoding="utf-8"))
    by_id = {}
    for k, v in ids.items():
        vid = v if isinstance(v, str) else (v.get("id") or v.get("Id") or "")
        by_id.setdefault(str(vid).replace("rbxassetid://", ""), []).append(k)
    out = {}
    for m in re.finditer(r'\n\s+(\w+) = \{ Id = "rbxassetid://(\d+)", Size = Vector2\.new\((\d+), (\d+)\)(.*)', cfg):
        key, aid, rest = m.group(1), m.group(2), m.group(5)
        sl = re.search(r"Slice = Rect\.new\((\d+), (\d+), (\d+), (\d+)\)", rest)
        ss = re.search(r"SliceScale = ([\d.]+)", rest)
        for cand in by_id.get(aid, []):
            for name in (cand + ".png", "UIP_" + cand + ".png"):
                if os.path.exists(os.path.join(ART, name)):
                    out.setdefault(key, (os.path.join(ART, name), tuple(int(x) for x in sl.groups()) if sl else None,
                                         float(ss.group(1)) if ss else None, "FitHeight = true" in rest))
    return out


def check_screen(name, vw, vh, touch, L, passes, names, lines, words):
    s = min(1.25, max(0.75, vh / 720)) if touch else min(1.0, max(0.5, vh / 720 * 0.8))
    pxf = 1.0 if touch else min(1.0, s / 0.8)
    cw, ch = vw / s, vh / s
    top = (INSET + 8) / s
    hang = TITLE_H / 2
    avail_h = max(220, ch - top - 12 - hang)
    win_w = max(280, min(WIN_MAX_W, cw - 24))
    max_h = min(WIN_MAX_H, avail_h)
    inner_w = win_w - 2 * PAD - PAD_LEFT - PAD_RIGHT
    card_w = (inner_w - (L["Cols"] - 1) * L["Gap"]) / L["Cols"]
    note_lines = wrap(BODY, words["Note"], NOTE_SIZE, inner_w)
    content_h = PAD_TOP + L["CardH"] + LIST_GAP + len(note_lines) * NOTE_SIZE + PAD_BOTTOM
    win_h = min(max(math.ceil(hang + 8 + content_h + BOTTOM), MIN_H), max_h)
    view_h = win_h - (hang + 8) - BOTTOM
    res = {"Scale": round(s, 3), "PxFloor": round(pxf, 3), "Canvas": [round(cw), round(ch)], "Window": [win_w, win_h],
           "CardW": round(card_w, 1), "ContentH": content_h, "ViewH": view_h, "Checks": {}, "Cards": {}}
    checks = res["Checks"]
    checks["four cards in one row, no scrolling"] = content_h <= view_h + 0.5 and L["Cols"] == 4 and len(passes) == 4
    lines_top = L["Pad"] + L["Slot"] + 4
    lines_h = L["CardH"] - lines_top - L["NameH"] - 2 - 6 - L["CapsH"] - L["Pad"]
    name_floor = ceil_floor(NAME_MIN_PX, pxf, s)
    body_size = max(L["LineSize"], ceil_floor(FLOOR_BODY, pxf, s))
    caps_floor = ceil_floor(CAPS_MIN_PX, pxf, s)
    caps_w, caps_h = card_w - 2 * L["Pad"] - 20, L["CapsH"] - 8
    for p in passes:
        k = p["Kind"]
        nsize, _ = scaled_size(HEAD, names[k], L["NameSize"], name_floor, card_w - 8, L["NameH"])
        wl = wrap(BODY, lines[k], body_size, card_w - 2 * L["Pad"])
        lines_ok = len(wl) * body_size <= lines_h + 0.5 and all(BODY.width(x, body_size) <= card_w - 2 * L["Pad"] for x in wl)
        caps_words = [words["MonthF"].replace("%s", str(p["Price"]))] if p["Info"] else \
            [words["PriceF"].replace("%s", str(p["Price"])), words["Owned"], words["Soon"]]
        caps = {}
        for w in caps_words:
            size, n = scaled_size(HEAD, w, L["CapsSize"], caps_floor, caps_w, caps_h)
            caps[w] = {"Size": size, "Px": round(size * s, 1) if size else None}
        res["Cards"][k] = {"NameSize": nsize, "NamePx": round(nsize * s, 1) if nsize else None, "Lines": wl,
                           "LineSize": body_size, "LinePx": round(body_size * s, 1), "LinesH": lines_h, "Capsule": caps}
        checks[k + ": name on one line at >= 12 px"] = nsize is not None and nsize * s >= NAME_MIN_PX * pxf - 0.01
        checks[k + ": lines fit above the capsule"] = lines_ok
        checks[k + ": capsule words on one line at >= 16 px"] = all(
            c["Size"] is not None and c["Size"] * s >= FLOOR_BUTTON * pxf - 0.01 for c in caps.values())
    res["Layout"] = {"Top": top, "Hang": hang, "AvailH": avail_h, "LinesTop": lines_top, "LinesH": lines_h,
                     "NoteLines": note_lines}
    return res


# ------------------------------------------------------------------ mock drawing (approximate)
def nine_slice(img, rect, scale, w, h):
    w, h = max(1, int(round(w))), max(1, int(round(h)))
    l, t, r, b = rect
    sw, sh = img.size
    cl, ct, cr, cb = l * scale, t * scale, (sw - r) * scale, (sh - b) * scale
    if cl + cr > w:
        k = w / (cl + cr); cl, cr = cl * k, cr * k
    if ct + cb > h:
        k = h / (ct + cb); ct, cb = ct * k, cb * k
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    xs_src, ys_src = [0, l, r, sw], [0, t, b, sh]
    xs_dst = [0, round(cl), w - round(cr), w]
    ys_dst = [0, round(ct), h - round(cb), h]
    for i in range(3):
        for j in range(3):
            sx0, sx1, sy0, sy1 = xs_src[i], xs_src[i + 1], ys_src[j], ys_src[j + 1]
            dx0, dx1, dy0, dy1 = xs_dst[i], xs_dst[i + 1], ys_dst[j], ys_dst[j + 1]
            if sx1 <= sx0 or sy1 <= sy0 or dx1 <= dx0 or dy1 <= dy0:
                continue
            out.alpha_composite(img.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.LANCZOS), (dx0, dy0))
    return out


def fit_image(img, w, h):
    k = min(w / img.size[0], h / img.size[1])
    return img.resize((max(1, int(img.size[0] * k)), max(1, int(img.size[1] * k))), Image.LANCZOS)


def draw_text(d, face, text, size_px, cx, cy, fill, stroke, anchor="mm", sw=2):
    d.text((cx, cy), text, font=face.font(size_px), fill=fill, stroke_width=sw, stroke_fill=stroke, anchor=anchor)


def mock(name, vw, vh, touch, res, L, passes, names, words, parts):
    s = res["Scale"]
    canvas = Image.new("RGBA", (vw, vh), (58, 92, 70, 255))
    g = ImageDraw.Draw(canvas)
    for y in range(vh):  # a soft sky -> grass backdrop under the modal's 45 % black
        k = y / vh
        g.line([(0, y), (vw, y)], fill=(int(120 - 60 * k), int(170 - 70 * k), int(220 - 150 * k), 255))
    canvas.alpha_composite(Image.new("RGBA", (vw, vh), (0, 0, 0, int(255 * 0.55))))
    win_w, win_h = res["Window"]
    top, hang, avail = res["Layout"]["Top"], res["Layout"]["Hang"], res["Layout"]["AvailH"]
    cx, cy = vw / 2, (top + hang + avail / 2) * s
    wx, wy = cx - win_w * s / 2, cy - win_h * s / 2

    def art(key):
        p = parts.get(key)
        return (Image.open(p[0]).convert("RGBA"), p) if p else (None, None)

    plate, pp = art("PanelCard")
    if plate:
        canvas.alpha_composite(nine_slice(plate, pp[1], pp[2] * s, win_w * s, win_h * s), (int(wx), int(wy)))
    # ribbon + title
    rib, rp = art("RibbonHeader")
    title_px = 24 * s
    tw = HEAD.width(words["Title"], 24) * s
    rw = max(220 * s, 46 * 0.94 * s + tw + 46 * 0.45 * s)
    if rib:
        k = TITLE_H * s / rib.size[1]
        canvas.alpha_composite(nine_slice(rib, rp[1], k, rw, TITLE_H * s), (int(cx - rw / 2), int(wy - TITLE_H * s / 2)))
    ico, _ = art("IconCoin")
    if ico:
        ic = fit_image(ico, 46 * 0.52 * s, 46 * 0.52 * s)
        canvas.alpha_composite(ic, (int(cx - rw / 2 + 46 * 0.40 * s - ic.size[0] / 2), int(wy - ic.size[1] / 2)))
    d = ImageDraw.Draw(canvas)
    draw_text(d, HEAD, words["Title"], title_px, cx - rw / 2 + 46 * 0.94 * s, wy, (255, 255, 255), (27, 33, 64), "lm")
    # the X disc
    disc = max(46, math.ceil(44 / s)) if touch else 46
    rnd, _ = art("BtnRound")
    xg, _ = art("GlyphClose")
    if rnd:
        r = fit_image(rnd, disc * s, disc * s)
        canvas.alpha_composite(r, (int(wx + win_w * s - disc * 0.2 * s - r.size[0] / 2), int(wy + disc * 0.2 * s - r.size[1] / 2)))
        if xg:
            x = fit_image(xg, disc * 0.6 * s, disc * 0.6 * s)
            canvas.alpha_composite(x, (int(wx + win_w * s - disc * 0.2 * s - x.size[0] / 2), int(wy + disc * 0.2 * s - x.size[1] / 2)))
    # cards
    ox, oy = wx + (PAD + PAD_LEFT) * s, wy + (hang + 8 + PAD_TOP) * s
    cw, chh = res["CardW"] * s, L["CardH"] * s
    caps_art = {"buy": "BtnPrimary", "soon": "BtnSecondary", "info": "BtnSecondary", "owned": "BtnConfirm"}
    for i, p in enumerate(passes):
        k = p["Kind"]
        x0, y0 = ox + i * (cw + L["Gap"] * s), oy
        if plate:
            canvas.alpha_composite(nine_slice(plate, pp[1], pp[2] * s, cw, chh), (int(x0), int(y0)))
        slot, _ = art(p["Slot"])
        sl = L["Slot"] * s
        if slot:
            si = fit_image(slot, sl, sl)
            canvas.alpha_composite(si, (int(x0 + cw / 2 - si.size[0] / 2), int(y0 + L["Pad"] * s)))
        icon, _ = art(p["Icon"])
        if icon:
            ii = fit_image(icon, sl * L["Icon"], sl * L["Icon"])
            canvas.alpha_composite(ii, (int(x0 + cw / 2 - ii.size[0] / 2), int(y0 + L["Pad"] * s + sl / 2 - ii.size[1] / 2)))
        card = res["Cards"][k]
        d = ImageDraw.Draw(canvas)
        lt = res["Layout"]["LinesTop"]
        if card["NameSize"]:
            draw_text(d, HEAD, names[k], card["NameSize"] * s, x0 + cw / 2, y0 + (lt + L["NameH"] / 2) * s,
                      (255, 255, 255), (27, 33, 64))
        ly = y0 + (lt + L["NameH"] + 2) * s
        for line in card["Lines"]:
            draw_text(d, BODY, line, card["LineSize"] * s, x0 + cw / 2, ly, (236, 238, 248), (20, 24, 48), "mt", 1)
            ly += card["LineSize"] * s
        state = "info" if p["Info"] else ("owned" if k == "VIP" else ("soon" if k == "Gold2" else "buy"))
        word = list(card["Capsule"].keys())[0] if state in ("buy", "info") else (words["Owned"] if state == "owned" else words["Soon"])
        cap, cp = art(caps_art[state])
        bw, bh = cw - 2 * L["Pad"] * s, L["CapsH"] * s
        bx, by = x0 + L["Pad"] * s, y0 + chh - L["Pad"] * s - bh
        if cap:
            img = nine_slice(cap, cp[1], bh / cap.size[1], bw, bh)
            if state == "soon":
                img = Image.blend(img, Image.new("RGBA", img.size, (120, 120, 130, 0)), 0.0)
                px = img.load()
                for yy in range(img.size[1]):
                    for xx in range(img.size[0]):
                        r_, g_, b_, a_ = px[xx, yy]
                        px[xx, yy] = (int(r_ * 0.59), int(g_ * 0.59), int(b_ * 0.63), a_)
            canvas.alpha_composite(img, (int(bx), int(by)))
        size = card["Capsule"].get(word, {}).get("Size") or L["CapsSize"]
        ink = (27, 33, 64) if state == "buy" else (255, 255, 255)
        rim = (255, 240, 200) if state == "buy" else (27, 33, 64)
        d = ImageDraw.Draw(canvas)
        draw_text(d, HEAD, word, size * s, bx + bw / 2, by + bh * 0.48, ink + ((153,) if state == "soon" else (255,)), rim, "mm", 1)
    ny = oy + (L["CardH"] + LIST_GAP) * s
    for line in res["Layout"]["NoteLines"]:
        draw_text(d, BODY, line, NOTE_SIZE * s, cx, ny, (200, 200, 210), (0, 0, 0), "mt", 0)
        ny += NOTE_SIZE * s
    d.text((8, vh - 8), f"{name}  UIScale {s}  window {win_w:.0f}x{win_h:.0f} du  (mock: 2x XP buy · 2x Gold soon · VIP owned)",
           font=BODY.font(13), fill=(255, 255, 255), anchor="ld", stroke_width=2, stroke_fill=(0, 0, 0))
    return canvas


def main():
    L, passes, names, lines, words = parse_shop()
    if len(passes) != 4:
        raise SystemExit(f"expected 4 pass cards in ShopUI.PASSES, found {len(passes)}")
    parts = part_files()
    report = {"Shop": os.path.relpath(SHOP, ROOT), "Fonts": {"Head": HEAD.path, "Body": BODY.path,
              "HeadRatio": round(HEAD.ratio, 3), "BodyRatio": round(BODY.ratio, 3)}, "Screens": {}}
    shots, failed = [], []
    for name, vw, vh, touch in SCREENS:
        res = check_screen(name, vw, vh, touch, L, passes, names, lines, words)
        report["Screens"][name] = res
        for check, ok in res["Checks"].items():
            if not ok:
                failed.append(f"{name}: {check}")
        shots.append(mock(name, vw, vh, touch, res, L, passes, names, words, parts))
    report["Failed"] = failed
    report["Passed"] = not failed
    os.makedirs(OUT_DIR, exist_ok=True)
    json.dump(report, open(OUT_JSON, "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=1)
    # sheet: the screens at their real size, two per row
    col_w = max(i.size[0] for i in shots)
    rows = [shots[i:i + 2] for i in range(0, len(shots), 2)]
    sheet = Image.new("RGB", (col_w * 2 + 30, sum(max(i.size[1] for i in r) + 10 for r in rows) + 10), (24, 26, 34))
    y = 10
    for r in rows:
        x = 10
        for im in r:
            sheet.paste(im.convert("RGB"), (x, y))
            x += col_w + 10
        y += max(i.size[1] for i in r) + 10
    sheet.save(OUT_PNG)
    for name in report["Screens"]:
        r = report["Screens"][name]
        cards = ", ".join(f"{k} {c['NamePx']}px/{len(c['Lines'])}l" for k, c in r["Cards"].items())
        print(f"{name:15s} scale {r['Scale']:<5} window {r['Window'][0]:.0f}x{r['Window'][1]:.0f} card {r['CardW']} du  {cards}")
    print("FAILED:\n  " + "\n  ".join(failed) if failed else "all checks passed")
    print("wrote", os.path.relpath(OUT_JSON, ROOT), "and", os.path.relpath(OUT_PNG, ROOT))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
