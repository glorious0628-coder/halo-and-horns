"""Draw queue of the 43 unique house decoration chunks for 이미지 생성 2 (이미지 생성 3, 10/13; SPEC A23-150 1번·5번).

  py tools/house_chunk_queue.py

Kinds + which houses get them come from tools/house_chunk_list.py (KINDS / GETS, read with ast, nothing run). For every
kind: the old 2D house view that shows it best + a crop box (fractions of that image, picked by eye on gridded sheets),
cut to art/review/img3/chunk_refs/<id>_ref.png (upscaled so the short side is >= 512 px, reference only - the new art is a
new 3D render without shadows). Writes art/prompts/house_chunks_queue_2026-10-13.json (order = most visible first) and
the check sheet art/review/img3/chunk_refs/chunk_refs_sheet.jpg.
"""
import ast
import json
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
H = "art/out/s2/halo/"
CAST = H + "castle6/HaloCastle_C2_%s.png"
NEW = H + "houses_new4/HaloNewHouse_%s.png"
SRC = open(os.path.join(ROOT, "tools", "house_chunk_list.py"), encoding="utf-8").read()
VAL = {}
for node in ast.parse(SRC).body:
    if isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name) and node.targets[0].id in ("KINDS", "GETS"):
        VAL[node.targets[0].id] = ast.literal_eval(node.value)
KINDS = dict(VAL["KINDS"])
GETS = VAL["GETS"]

# (kind, id, one line for the drawer, [(ref image, crop box x0 y0 x1 y1 as fractions), ...]) - most visible first
Q = [
    ("등불 + 팔", "LampArm", "wall lantern: gold lantern frame with pale clear see-through glass (no glow painted), round cap + knob, curved gold wall arm and small wall plate. 3D note: Tripo keeps only the gold frame + arm; the glass and the night light stay the Studio parts LampGlass / LampCore",
     [(H + "roofs/HaloDomeHouse_11_roof_v2.png", (0.60, 0.46, 0.70, 0.62)), (H + "houses_new4/HaloNewHouse_Hill4_left_v2.png", (0.73, 0.53, 0.84, 0.72))]),
    ("외문", "DoorSingle", "single arched wooden door leaf, vertical planks, two long gold strap hinges, gold ring knocker",
     [(H + "roofs/HaloDomeHouse_11_roof_v2.png", (0.38, 0.42, 0.59, 0.75))]),
    ("날개 왼쪽", "CastleWingL", "castle: huge white angel wing with gold feather edges + its base, left side of the facade (ref 2 = the same wing seen from the back = image right)",
     [(CAST % "front_HQ_src", (0.17, 0.12, 0.52, 0.82)), (CAST % "back_src", (0.46, 0.06, 0.80, 0.72))]),
    ("날개 오른쪽", "CastleWingR", "castle: huge white angel wing with gold feather edges + its base, right side (mirror of the left one in the 2D; ref 2 = seen from the back = image left)",
     [(CAST % "front_HQ_src", (0.48, 0.12, 0.83, 0.82)), (CAST % "back_src", (0.20, 0.06, 0.54, 0.72))]),
    ("둥근 갈빗대 돔", "DomeRibbed", "round gold dome with ribs, ring base and a pointed gold finial (02, 06, 08, Potion)",
     [(H + "houses/HaloDomeHouse_02_front_HQ_src.png", (0.29, 0.04, 0.71, 0.33))]),
    ("쌍문", "DoorDouble", "double arched wooden door, two leaves, gold fleur hinges, two gold knobs",
     [(H + "houses/HaloDomeHouse_04_front_HQ_src.png", (0.42, 0.53, 0.58, 0.86))]),
    ("창 화분 A", "WindowBoxA", "window box plants: white + blue daisies with green leaves hanging over the edge (box = skeleton)",
     [(H + "houses_new4/HaloNewHouse_Hill4_left_v2.png", (0.27, 0.68, 0.53, 0.88))]),
    ("원뿔 나무", "ConeTree", "small cone-shaped garden tree (topiary), dense round leaf clumps, no pot",
     [(H + "houses/HaloDomeHouse_08_front_HQ_src.png", (0.19, 0.66, 0.29, 0.80))]),
    ("장미창 무늬", "CastleRose", "castle: round rose window, 8 petal gold tracery with glowing yellow glass + gold ring frame",
     [(CAST % "front_HQ_src", (0.43, 0.46, 0.57, 0.62))]),
    ("성 문 무늬", "CastleGateLeaf", "castle: tall pointed gold door leaf with a flower medallion and vertical panels",
     [(CAST % "gateleaf_HQ_src", None), (CAST % "front_HQ_src", (0.42, 0.62, 0.58, 0.88))]),
    ("양파 돔", "DomeOnion", "plump gold onion dome with ribs, ring base and a pointed finial (04)",
     [(H + "houses/HaloDomeHouse_04_front_HQ_src.png", (0.29, 0.02, 0.71, 0.41))]),
    ("팔각 돔", "DomeOctagon", "eight-sided gold dome with flat facets and a pointed finial (03)",
     [(H + "houses/HaloDomeHouse_03_front_HQ_src.png", (0.24, 0.02, 0.80, 0.36))]),
    ("공 꼭지 돔", "DomeBall", "wide round gold dome with ribs and one big gold ball finial (09)",
     [(H + "houses/HaloDomeHouse_09_front_HQ_src.png", (0.25, 0.02, 0.75, 0.38))]),
    ("가는 양파 돔", "DomeOnionSlim", "slim tall gold onion dome, two small balls at the base, pointed spire (10)",
     [(H + "houses/HaloDomeHouse_10_front_HQ_recolor.png", (0.33, 0.00, 0.67, 0.28))]),
    ("벽돌 돔", "DomeBrick", "rounded red-brown brick dome with a cream stone rim (Bakery)",
     [(H + "shops/HaloShop_Bakery_front_HQ_src.png", (0.53, 0.17, 0.83, 0.36))]),
    ("파라솔", "JuiceParasol", "rooftop: blue + white striped canopy on four gold posts, crates of oranges, lemons, apples (Juice)",
     [(H + "roofs/HaloShop_Juice_roof_v2.png", (0.27, 0.02, 0.73, 0.35))]),
    ("온실", "Greenhouse", "rooftop glass greenhouse with gold frame and green plants + white flowers inside (Flower)",
     [(H + "roofs/HaloShop_Flower_roof_v2.png", (0.22, 0.08, 0.78, 0.35))]),
    ("간판", "ShopSign", "blank gold shop sign board with scroll ends and a small top ornament (no letters; text = TextLabel)",
     [(H + "shops/HaloShop_Bakery_front_HQ_src.png", (0.31, 0.32, 0.67, 0.46))]),
    ("담쟁이 벽", "IvyWall", "green ivy climbing up a wall corner with small white + blue flowers (flat back, hangs on the wall)",
     [(H + "houses/HaloDomeHouse_09_front_HQ_src.png", (0.18, 0.24, 0.39, 0.93))]),
    ("담쟁이 발코니", "IvyBalcony", "ivy hanging down from a balcony rail / pergola beam, white flowers (06, 08, 10, 12)",
     [(H + "roofs/HaloDomeHouse_12_roof_v2.png", (0.28, 0.07, 0.72, 0.30))]),
    ("꽃 덤불 화분", "FlowerBushPot", "round flower bush: white + blue flowers in a green leaf mound with hanging vines (pot = skeleton)",
     [(H + "houses/HaloDomeHouse_02_front_HQ_src.png", (0.20, 0.70, 0.40, 0.93))]),
    ("현관 반돔", "DomePorchHalf", "small half dome over the door: gold ribbed half dome with finial (08)",
     [(H + "houses/HaloDomeHouse_08_front_HQ_src.png", (0.36, 0.42, 0.64, 0.58))]),
    ("정자 돔", "DomePavilion", "small rooftop pavilion: open arches, gold mini dome and ball (01)",
     [(H + "roofs/HaloDomeHouse_01_roof_v2.png", (0.60, 0.12, 0.76, 0.30))]),
    ("작은 탑 돔", "DomeTowerSmall", "small gold tower cap: little ribbed dome with point, sits on a corner pillar (02, x4)",
     [(H + "houses/HaloDomeHouse_02_front_HQ_src.png", (0.18, 0.30, 0.27, 0.41))]),
    ("빵 진열", "BreadDisplay", "bakery window shelves: baguettes, round loaves, croissants in baskets (Bakery)",
     [(H + "shops/HaloShop_Bakery_front_HQ_src.png", (0.28, 0.55, 0.55, 0.83))]),
    ("주스 가판", "JuiceStand", "juice counter: wooden shelves, glass juice jars (orange, red, green), fruit crates (Juice)",
     [(H + "roofs/HaloShop_Juice_roof_v2.png", (0.37, 0.58, 0.72, 0.92))]),
    ("물약 진열", "PotionDisplay", "potion shelves: round glowing bottles (pink, teal, purple, gold), books (Potion)",
     [(H + "shops/HaloShop_Potion_front_HQ_src.png", (0.26, 0.57, 0.55, 0.82))]),
    ("장미 격자", "RoseTrellis", "white wooden lattice panel with climbing blue + white flowers (Flower)",
     [(H + "roofs/HaloShop_Flower_roof_v2.png", (0.10, 0.36, 0.26, 0.80))]),
    ("장미 아치", "RoseArch", "rose arch only: green vine lattice arch with pink roses, the door opening left EMPTY (no door leaf, no awning, no lanterns) (Garden5)",
     [(NEW % "Garden5_front", (0.32, 0.44, 0.75, 0.90))]),
    ("해바라기 화단", "SunflowerBed", "flower bed: sunflowers + white daisies in green leaves (Garden5)",
     [(NEW % "Garden5_front", (0.14, 0.68, 0.40, 0.90))]),
    ("연못", "Pond", "small round pond: gold rim, blue water, lily pads, white lotus, ferns behind (Garden6)",
     [(NEW % "Garden6_front", (0.01, 0.54, 0.39, 0.82))]),
    ("성 울타리", "CastleHedge", "castle: low trimmed green hedge strip on a white stone curb",
     [(CAST % "front_HQ_src", (0.02, 0.74, 0.44, 0.93))]),
    ("별 꼭지", "StarFinial", "gold five-point star finial on a short gold stem (Cliff6, Garden7, castle spires)",
     [(H + "houses_new4/HaloNewHouse_Cliff6_front.png", (0.44, 0.00, 0.56, 0.13))]),
    ("바람개비", "WeatherVane", "gold weathervane: star on top + arrow with feather tail (Garden7)",
     [(NEW % "Garden7_front", (0.40, 0.00, 0.59, 0.15))]),
    ("굴뚝 갓", "ChimneyCap", "chimney top: cream stone chimney with two gold pots (11, Hill4)",
     [(NEW % "Hill4_front", (0.77, 0.07, 0.92, 0.24))]),
    ("굴뚝 등", "ChimneyLantern", "bakery chimney top: small round gold lantern cupola with dome and ball (Bakery)",
     [(H + "shops/HaloShop_Bakery_front_HQ_src.png", (0.62, 0.04, 0.76, 0.24))]),
    ("동그란 나무", "RoundTree", "small round clipped bush tree in a gold-rim pot on the roof (05)",
     [(H + "roofs/HaloDomeHouse_05_roof_v2.png", (0.27, 0.22, 0.36, 0.31))]),
    ("메달 + 종", "MedalBell", "only the gold four-leaf medal + the small gold bell on its wall bracket, drawn together (no door, no lantern) (Cliff7)",
     [(NEW % "Cliff7_front", (0.44, 0.30, 0.75, 0.60))]),
    ("망원경", "Telescope", "brass telescope on a gold tripod stand (Cliff8 balcony) - made by Tripo like the other chunks (최종 검수 10/12)",
     [(NEW % "Cliff8_front", (0.76, 0.24, 0.93, 0.46))]),
    ("가마솥", "Cauldron", "black iron cauldron on three short legs, bubbling green potion (Potion) - made by Tripo like the other chunks (최종 검수 10/12)",
     [(H + "shops/HaloShop_Potion_front_HQ_src.png", (0.64, 0.73, 0.79, 0.93))]),
    ("꽃 양동이", "FlowerBuckets", "wooden + tin flower buckets with blue hydrangea, white tulips (Flower)",
     [(H + "roofs/HaloShop_Flower_roof_v2.png", (0.25, 0.74, 0.41, 0.91))]),
    ("창 화분 B", "WindowBoxB", "window box plants: pink + white tulips with green leaves (Cliff6)",
     [(H + "houses_new4/HaloNewHouse_Cliff6_front.png", (0.16, 0.45, 0.36, 0.58))]),
    ("모서리 꼭지", "CornerFinial", "small gold corner finial: ball + point on a little stepped base (08 corners, x4)",
     [(H + "houses/HaloDomeHouse_08_front_HQ_src.png", (0.19, 0.22, 0.27, 0.33))]),
]
assert len(Q) == len(KINDS) == len({q[0] for q in Q}), (len(Q), len(KINDS))
assert all(q[0] in KINDS for q in Q)

OUT = os.path.join(ROOT, "art", "review", "img3", "chunk_refs")
os.makedirs(OUT, exist_ok=True)
items = []
thumbs = []
for i, (kind, cid, line, refs) in enumerate(Q):
    houses = [h for h, v in GETS.items() if kind in v]
    rl = []
    for j, (src, box) in enumerate(refs):
        if not os.path.isfile(os.path.join(ROOT, src)):
            raise SystemExit("missing " + src)
        if box is None:
            rl.append({"image": src, "crop": None})
            thumbs.append((cid, Image.open(os.path.join(ROOT, src)).convert("RGB")))
            continue
        im = Image.open(os.path.join(ROOT, src)).convert("RGB")
        W, Hh = im.size
        c = im.crop((round(box[0] * W), round(box[1] * Hh), round(box[2] * W), round(box[3] * Hh)))
        k = max(1.0, 512.0 / min(c.size))
        if k > 1:
            c = c.resize((round(c.size[0] * k), round(c.size[1] * k)), Image.LANCZOS)
        name = "%s_ref%s.png" % (cid, "" if j == 0 else str(j + 1))
        c.save(os.path.join(OUT, name))
        rl.append({"image": src, "crop_box": list(box), "crop": "art/review/img3/chunk_refs/" + name})
        thumbs.append((cid + ("" if j == 0 else " #%d" % (j + 1)), c))
    items.append({"order": i + 1, "id": "HaloChunk_" + cid, "name_ko": kind, "what_ko": KINDS[kind], "draw": line,
                  "houses": houses, "house_count": len(houses), "refs": rl})

doc = {
    "made_by": "이미지 생성 3, 2026-10-13 (최종 검수 요청 10/12 밤)",
    "for": "이미지 생성 2 — 집 덩어리 장식 고유 43종 그림 (같은 모양은 한 번, A23-150 5번)",
    "source": "docs/design/house_chunk_decor_2026-10-12.md (tools/house_chunk_list.py), crops by tools/house_chunk_queue.py",
    "rules": [
        "A23-150 1: shadow-free 3D render - keep volume, rounded edges, soft form shading and material shine; even light-box "
        "light from all sides; NO ground / cast / contact shadow, no dark side, no dark crevices; bright true colours; not flat 2D colouring",
        "A23-150 5: tiny pieces are drawn together as one chunk on one sheet (dome + finial, door leaf + hinges + knocker, lantern + arm)",
        "4 views front / left / right / back, same object, same size, same light (A23-122); the old 2D crop is the shape "
        "reference only (copy its shape and colours, never its shadows)",
        "no letters on signs, no ray-burst patterns, no outlines (A23-148); plain light grey background",
        "candidates = Firefly Medium; final = the user's ChatGPT plan image tool, Firefly High only when ChatGPT runs out (A23-151); prompt < 1000 chars for Firefly",
        "old 2D used as a reference is deleted once its new art passes (A23-150 3)",
    ],
    "order_rule": "most visible first: everywhere-at-eye-level (lantern, doors), then the castle landmark, big rooftop domes, "
                  "window plants / trees, shop fronts, then the small one-house pieces",
    "items": items,
}
json.dump(doc, open(os.path.join(ROOT, "art", "prompts", "house_chunks_queue_2026-10-13.json"), "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)

try:
    font = ImageFont.truetype("arial.ttf", 16)
except OSError:
    font = ImageFont.load_default()
C, COLS = 220, 8
rows = (len(thumbs) + COLS - 1) // COLS
S = Image.new("RGB", (COLS * (C + 6) + 6, rows * (C + 26) + 6), (34, 34, 38))
d = ImageDraw.Draw(S)
for n, (lab, im) in enumerate(thumbs):
    t = im.copy()
    t.thumbnail((C, C))
    x, y = 6 + (n % COLS) * (C + 6), 6 + (n // COLS) * (C + 26)
    S.paste(t, (x, y + 22))
    d.text((x, y + 2), lab, fill=(255, 210, 120), font=font)
S.save(os.path.join(OUT, "chunk_refs_sheet.jpg"), quality=88)
print("[chunks] %d kinds, %d refs -> art/prompts/house_chunks_queue_2026-10-13.json" % (len(items), len(thumbs)))
