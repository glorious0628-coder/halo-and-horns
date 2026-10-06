"""World map v2 layout (A23-47 'wide and densely filled', MAP-CONCEPT2): the layout data + a flat colour sketch.

  py tools/worldmap_layout.py            -> docs/design/world_map_v2_2026-10-06.json
                                            art/review/worldmap/layout_v2_sketch.png   (1536x1024, wordless; Firefly reference)
                                            art/review/worldmap/layout_v2_labeled.png  (same + Korean labels and a stud grid, for people)

Coordinates are Roblox studs, top view: +X = east (right), -Z = north (up). The current world (Config.Map.Lands) is
x -110..1300, z -500..500; v2 keeps the same order of places (Crossroads hub in the middle, Halo north, Horns south,
Meadow -> Goblin Woods -> pass -> Skeleton Ruins to the east, Pumpkin Patch + Haunted Hollow south of the meadow) but
makes every place bigger so it can be filled densely. This is a proposal for 검수 / 게임성 개발 1, not code.
"""
import json
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "art", "review", "worldmap")

W, H = 1536, 1024
X0, X1 = -230, 1800           # world window shown on the sheet
Z0, Z1 = -720, 720
S = min(W / (X1 - X0), H / (Z1 - Z0))
OX = (W - (X1 - X0) * S) / 2
OY = (H - (Z1 - Z0) * S) / 2


def px(x, z):
    return (OX + (x - X0) * S, OY + (z - Z0) * S)


def rect(x0, x1, z0, z1):
    a, b = px(x0, z0), px(x1, z1)
    return [a[0], a[1], b[0], b[1]]


# ---------------------------------------------------------------- layout data (proposal)
LAYOUT = {
    "units": "studs; +X east, -Z north; Terrain top Y = 0",
    "zones": [
        {"id": "Crossroads", "ko": "교차로 마을", "en": "Crossroads", "kind": "town", "land": [-150, 150, -150, 150],
         "lv": "1", "pvp": False, "spawn": [0, -30], "landmark": "Sky Crown of Balance floating above + fountain crown-shard light beam",
         "landmark_ko": "하늘에 뜬 부서진 균형의 왕관 + 분수 빛기둥(어디서든 보임)", "color": (227, 207, 165)},
        {"id": "HaloTown", "ko": "빛의 성채", "en": "Halo Citadel", "kind": "town", "land": [-200, 200, -700, -330],
         "lv": "1", "pvp": False, "spawn": [0, -420], "landmark": "white castle with a floating golden halo ring (north end)",
         "landmark_ko": "북쪽 끝 흰 성 + 떠 있는 금 후광 고리(교차로 북쪽 길에서 보임)", "color": (246, 240, 222)},
        {"id": "HornsTown", "ko": "뿔 소굴", "en": "Horns Den", "kind": "town", "land": [-200, 200, 330, 700],
         "lv": "1", "pvp": False, "spawn": [0, 420], "landmark": "obsidian fortress with curved horn towers and a glowing amber shard (south end)",
         "landmark_ko": "남쪽 끝 흑요석 요새 + 뿔 탑 + 호박색 왕관 조각(교차로 남쪽 길에서 보임)", "color": (92, 54, 64)},
        {"id": "SlimeMeadow", "ko": "말랑 초원", "en": "Squishy Meadow", "kind": "hunt", "land": [210, 650, -240, 240],
         "lv": "1+", "pvp": False, "spawn": [230, 0], "landmark": "King Slime Hill: round green hill with a crown-shaped rock + giant jelly slime statue",
         "landmark_ko": "왕 슬라임 언덕(왕관 바위) + 거대 젤리 슬라임 석상", "color": (139, 203, 94)},
        {"id": "PumpkinPatch", "ko": "호박밭", "en": "Pumpkin Patch", "kind": "hunt", "season": "Halloween", "land": [420, 650, 240, 430],
         "lv": "1+", "pvp": False, "spawn": [535, 255], "landmark": "giant pumpkin house with a round door (no face)",
         "landmark_ko": "거대 호박 집(둥근 문, 얼굴 없음)", "color": (200, 128, 58)},
        {"id": "HauntedHollow", "ko": "유령 숲", "en": "Haunted Hollow", "kind": "hunt", "season": "Halloween", "land": [220, 420, 255, 430],
         "lv": "8-14", "pvp": False, "spawn": [400, 340], "landmark": "big twisted purple willow with blue lanterns under a full moon",
         "landmark_ko": "푸른 등불 달린 큰 보라 버드나무(보름달)", "color": (107, 90, 154)},
        {"id": "GoblinWoods", "ko": "고블린 숲", "en": "Goblin Woods", "kind": "hunt", "land": [710, 1190, -260, 260],
         "lv": "10+", "pvp": True, "spawn": [730, 0], "landmark": "giant old tree with a goblin treehouse",
         "landmark_ko": "고블린 나무집이 달린 거대 고목", "color": (62, 125, 58)},
        {"id": "SkeletonRuins", "ko": "해골 유적", "en": "Skeleton Ruins", "kind": "hunt", "land": [1260, 1780, -290, 290],
         "lv": "25+", "pvp": True, "spawn": [1280, 0], "landmark": "broken castle tower with a big round stone mask and blue spirit flames",
         "landmark_ko": "큰 둥근 돌 가면이 달린 부서진 성탑 + 푸른 영혼불", "color": (142, 138, 166)},
    ],
    "pass": {"ko": "고갯길(돌 아치)", "land": [1190, 1260, -70, 70], "color": (150, 130, 112)},
    "rivers": [{"ko": "교차로-초원 강", "x": [150, 210]}, {"ko": "초원-숲 강", "x": [650, 710]}],
    "bridges": [
        {"ko": "초원 다리", "from": [150, 0], "to": [210, 0], "width": 22},
        {"ko": "숲 다리", "from": [650, 0], "to": [710, 0], "width": 22},
        {"ko": "빛 다리", "from": [0, -150], "to": [0, -330], "width": 22},
        {"ko": "뿔 다리", "from": [0, 150], "to": [0, 330], "width": 22},
    ],
    "roads": [
        {"ko": "왕관 큰길(동서)", "pts": [[-150, 0], [1760, 0]], "w": 18},
        {"ko": "북쪽 길(성채)", "pts": [[0, -150], [0, -600]], "w": 16},
        {"ko": "남쪽 길(소굴)", "pts": [[0, 150], [0, 600]], "w": 16},
        {"ko": "호박밭 길", "pts": [[535, 0], [535, 330]], "w": 12},
        {"ko": "유령 숲 길(호박밭 서문)", "pts": [[535, 340], [330, 340]], "w": 10},
        {"ko": "초원 둘레길", "pts": [[260, -170], [600, -170]], "w": 10},
        {"ko": "숲 오솔길", "pts": [[760, -150], [1120, -150]], "w": 10},
        {"ko": "유적 길", "pts": [[1300, 150], [1700, 150]], "w": 10},
    ],
    "gates": [
        {"ko": "초원 관문(젤리 슬라임 석상)", "at": [210, 0]}, {"ko": "숲 관문(고블린 토템)", "at": [710, 0]},
        {"ko": "유적 관문(돌 가면)", "at": [1260, 0]}, {"ko": "빛 관문(날개 아치)", "at": [0, -330]},
        {"ko": "뿔 관문(뿔 아치)", "at": [0, 330]}, {"ko": "호박밭 문", "at": [535, 240]}, {"ko": "유령 숲 문", "at": [420, 340]},
    ],
    "landmarks": [
        {"ko": "하늘 왕관 + 분수", "at": [0, 0], "r": 34, "color": (245, 197, 66)},
        {"ko": "빛 성(후광 고리)", "at": [0, -630], "r": 48, "color": (255, 255, 255)},
        {"ko": "뿔 요새", "at": [0, 630], "r": 48, "color": (60, 24, 32)},
        {"ko": "왕 슬라임 언덕", "at": [500, -110], "r": 52, "color": (102, 190, 70)},
        {"ko": "젤리 트램펄린", "at": [330, 150], "r": 26, "color": (120, 230, 200)},
        {"ko": "거대 호박 집", "at": [585, 370], "r": 30, "color": (240, 140, 40)},
        {"ko": "유령 버드나무", "at": [300, 360], "r": 32, "color": (140, 110, 220)},
        {"ko": "고블린 나무집 고목", "at": [960, -90], "r": 58, "color": (40, 95, 40)},
        {"ko": "고갯길 돌 아치", "at": [1225, 0], "r": 22, "color": (170, 150, 130)},
        {"ko": "돌 가면 성탑", "at": [1560, -70], "r": 60, "color": (120, 116, 150)},
    ],
}

SEA = (110, 190, 228)
RIVER = (96, 176, 222)
ROAD = (222, 190, 128)
BRIDGE = (150, 104, 62)


def organic(mask, seed, bumps=26, amp=46, blur=16):
    """Soften a land mask into a natural coastline: add/cut a few big circles along the edge, blur hard, threshold.
    Same seed -> same coast, so the sketch and the labeled sheet match."""
    import random
    rnd = random.Random(seed)
    m = mask.copy()
    d = ImageDraw.Draw(m)
    box = m.getbbox()
    if not box:
        return m
    x0, y0, x1, y1 = box
    for i in range(bumps):
        t = rnd.uniform(0.08, 0.92)
        side = rnd.randrange(4)
        if side == 0:
            cx, cy = x0 + t * (x1 - x0), y0
        elif side == 1:
            cx, cy = x0 + t * (x1 - x0), y1
        elif side == 2:
            cx, cy = x0, y0 + t * (y1 - y0)
        else:
            cx, cy = x1, y0 + t * (y1 - y0)
        r = rnd.uniform(0.45, 1.0) * amp
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255 if rnd.random() < 0.6 else 0)
    m = m.filter(ImageFilter.GaussianBlur(blur))
    return m.point(lambda v: 255 if v > 128 else 0)


def group_mask(rects, grow=0):
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    for (x0, x1, z0, z1) in rects:
        d.rounded_rectangle(rect(x0 - grow, x1 + grow, z0 - grow, z1 + grow), radius=int(60 * S), fill=255)
    return m


def zone_of(x, z):
    """Nearest zone rectangle (the 'pass' band counts as its own)."""
    px0, px1, _, _ = LAYOUT["pass"]["land"]
    if px0 - 10 <= x <= px1 + 10 and -330 <= z <= 330:
        return None
    best, bd = None, 1e18
    for q in LAYOUT["zones"]:
        x0, x1, z0, z1 = q["land"]
        dx = max(x0 - x, 0, x - x1)
        dz = max(z0 - z, 0, z - z1)
        dd = dx * dx + dz * dz
        if dd < bd:
            best, bd = q, dd
    return best


GROUPS = [  # land pieces; water between them = sea or river straits crossed by bridges
    ("cross", ["Crossroads"]), ("halo", ["HaloTown"]), ("horns", ["HornsTown"]),
    ("meadow", ["SlimeMeadow", "PumpkinPatch", "HauntedHollow"]), ("wild", ["GoblinWoods", "SkeletonRuins"]),
]


def draw_sketch(labels=False, marks=True):
    img = Image.new("RGB", (W, H), SEA)
    d = ImageDraw.Draw(img)
    land = Image.new("L", (W, H), 0)
    for gi, (gid, ids) in enumerate(GROUPS):
        rects = [next(q for q in LAYOUT["zones"] if q["id"] == i)["land"] for i in ids]
        if gid == "wild":
            x0, x1, z0, z1 = LAYOUT["pass"]["land"]
            rects.append([x0 - 30, x1 + 30, -240, 240])
        m = organic(group_mask(rects), 21 + gi * 7)
        land.paste(255, (0, 0), m)
    # water straits between the land pieces (rivers / sea gaps the bridges cross), gently wavy
    import math
    carve = ImageDraw.Draw(land)
    for (xc, half, za, zb, ph) in ((180, 26, -340, 340, 0.0), (680, 28, -340, 340, 1.7), (210, 14, 240, 760, 0.9)):
        left, right = [], []
        for k in range(0, 61):
            z = za + (zb - za) * k / 60
            w = 9 * math.sin(z / 55.0 + ph)
            left.append(px(xc - half + w, z))
            right.append(px(xc + half + w, z))
        carve.polygon(left + right[::-1], fill=0)
    # shallow-water rim, beach, then land colours by nearest zone
    img.paste((150, 214, 236), (0, 0), land.filter(ImageFilter.MaxFilter(29)).filter(ImageFilter.GaussianBlur(6)))
    img.paste((238, 222, 170), (0, 0), land.filter(ImageFilter.MaxFilter(9)))
    colour = Image.new("RGB", (W, H), (0, 0, 0))
    cp = colour.load()
    step = 2
    for y in range(0, H, step):
        for x in range(0, W, step):
            wx = X0 + (x - OX) / S
            wz = Z0 + (y - OY) / S
            q = zone_of(wx, wz)
            c = (128, 112, 98) if q is None else q["color"]
            for yy in range(y, min(y + step, H)):
                for xx in range(x, min(x + step, W)):
                    cp[xx, yy] = c
    colour = colour.filter(ImageFilter.ModeFilter(9))
    img.paste(colour, (0, 0), land)
    x0, x1, z0, z1 = LAYOUT["pass"]["land"]
    d.rectangle(rect(x0 - 4, x1 + 4, z0, z1), fill=LAYOUT["pass"]["color"])
    # density hints: clumps of trees in the meadow edges and the woods, rocks in the ruins, little roofs in towns
    import random
    rnd = random.Random(5)
    def dots(zid, n, col, rmin, rmax, edge=0.0):
        z = next(q for q in LAYOUT["zones"] if q["id"] == zid)
        x0, x1, z0, z1 = z["land"]
        for _ in range(n):
            x, zz = rnd.uniform(x0 + 25, x1 - 25), rnd.uniform(z0 + 25, z1 - 25)
            if abs(zz) < 28 and z["kind"] == "hunt":
                continue
            cx, cy = px(x, zz)
            r = rnd.uniform(rmin, rmax) * S
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)
    dots("GoblinWoods", 170, (36, 92, 40), 9, 18)
    dots("SlimeMeadow", 40, (92, 160, 70), 8, 13)
    dots("SkeletonRuins", 70, (110, 106, 130), 6, 12)
    dots("HauntedHollow", 26, (80, 64, 128), 7, 12)
    dots("PumpkinPatch", 30, (236, 140, 40), 4, 6)
    for zid, roof in (("HaloTown", (240, 200, 90)), ("HornsTown", (170, 50, 50)), ("Crossroads", (180, 120, 80))):
        z = next(q for q in LAYOUT["zones"] if q["id"] == zid)
        x0, x1, z0, z1 = z["land"]
        for _ in range(26 if zid != "Crossroads" else 14):
            x, zz = rnd.uniform(x0 + 30, x1 - 30), rnd.uniform(z0 + 30, z1 - 30)
            if abs(x) < 26:
                continue
            cx, cy = px(x, zz)
            d.rectangle([cx - 6, cy - 5, cx + 6, cy + 5], fill=roof)
    # roads
    for r in LAYOUT["roads"]:
        pts = [px(*p) for p in r["pts"]]
        d.line(pts, fill=ROAD, width=max(3, int(r["w"] * S)))
    # bridges
    for b in LAYOUT["bridges"]:
        (ax, az), (bx, bz) = b["from"], b["to"]
        hw = b["width"] / 2
        if ax == bx:
            d.rectangle(rect(ax - hw, ax + hw, min(az, bz), max(az, bz)), fill=BRIDGE)
        else:
            d.rectangle(rect(min(ax, bx), max(ax, bx), az - hw, az + hw), fill=BRIDGE)
    # landmarks: round blobs with a dark ring (the painter turns each into the described miniature)
    for lm in LAYOUT["landmarks"] if marks else []:
        cx, cy = px(*lm["at"])
        r = lm["r"] * S
        d.ellipse([cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3], fill=(40, 36, 52))
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=lm["color"])
    for g in LAYOUT["gates"] if marks else []:
        cx, cy = px(*g["at"])
        d.rectangle([cx - 6, cy - 6, cx + 6, cy + 6], fill=(60, 50, 70))
    if labels:
        f = ImageFont.truetype("C:/Windows/Fonts/malgunbd.ttf", 20)
        fs = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 15)
        for x in range(-200, 1801, 200):
            a = px(x, Z0)[0]
            d.line([(a, 0), (a, H)], fill=(255, 255, 255), width=1)
            d.text((a + 3, 3), str(x), font=fs, fill=(255, 255, 255))
        for zz in range(-600, 601, 200):
            b = px(X0, zz)[1]
            d.line([(0, b), (W, b)], fill=(255, 255, 255), width=1)
            d.text((3, b + 2), str(zz), font=fs, fill=(255, 255, 255))
        for z in LAYOUT["zones"]:
            x0, x1, z0, z1 = z["land"]
            below = z["id"] in ("HauntedHollow", "PumpkinPatch")
            cx, cy = px((x0 + x1) / 2, (z1 + (70 if z["id"] == "HauntedHollow" else 18)) if below else (z0 + 30))
            t = f"{z['ko']} Lv{z['lv']}" + (" PvP" if z["pvp"] else "") + (" (핼러윈)" if z.get("season") else "")
            tw = d.textlength(t, font=f)
            d.rectangle([cx - tw / 2 - 4, cy - 2, cx + tw / 2 + 4, cy + 26], fill=(0, 0, 0))
            d.text((cx - tw / 2, cy), t, font=f, fill=(255, 255, 255))
            sx, sz = z["spawn"]
            p = px(sx, sz)
            d.polygon([(p[0], p[1] - 9), (p[0] - 8, p[1] + 6), (p[0] + 8, p[1] + 6)], fill=(255, 60, 60))
        for lm in LAYOUT["landmarks"]:
            cx, cy = px(*lm["at"])
            r = lm["r"] * S
            t = lm["ko"]
            tw = d.textlength(t, font=fs)
            d.rectangle([cx - tw / 2 - 2, cy + r + 3, cx + tw / 2 + 2, cy + r + 22], fill=(255, 255, 255))
            d.text((cx - tw / 2, cy + r + 4), t, font=fs, fill=(20, 20, 30))
        d.text((W - 340, H - 24), "빨간 세모 = 스폰 · 숫자 = 스터드(+X 동, -Z 북)", font=fs, fill=(255, 255, 255))
    return img


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    draw_sketch(False).save(os.path.join(OUT_DIR, "layout_v2_sketch.png"))
    draw_sketch(False, marks=False).save(os.path.join(OUT_DIR, "layout_v2_sketch_nomarks.png"))
    draw_sketch(True).save(os.path.join(OUT_DIR, "layout_v2_labeled.png"))
    data = json.loads(json.dumps(LAYOUT, default=list))
    for z in data["zones"]:
        x0, x1, z0, z1 = z["land"]
        z["size"] = [x1 - x0, z1 - z0]
    json.dump(data, open(os.path.join(ROOT, "docs", "design", "world_map_v2_2026-10-06.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print("scale", round(S, 4), "px/stud; wrote sketch, labeled sheet and json")


if __name__ == "__main__":
    main()
