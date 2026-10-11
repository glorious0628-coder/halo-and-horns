"""halo_plan_v2.py (이미지 생성 1, 2026-10-11, SPEC A23-121 빛 마을 처음부터 다시 - 1단계 '이야기와 구역').

Writes docs/design/halo_plan_v2_2026-10-11.json and the top-view map art/review/world/halo_v2/halo_plan_v2_map.png.
Everything is new (the old island / plan is not used). Frame: the Halo island box of Config (x -200..200, z -700..-330);
north = z -330 = the gate at the end of the Crossroads bridge (drawn at the top), south = z -700.
Checks it prints: buildings inside their district and on land, no two footprints overlap (with a 4-stud gap), every door
has a road / path within 14 studs, paving share of the land, mirror pairs (same kind within 12 studs of a mirrored one).
usage: py tools/halo_plan_v2.py
"""
import json
import math
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_JSON = os.path.join(ROOT, "docs", "design", "halo_plan_v2_2026-10-11.json")
OUT_DIR = os.path.join(ROOT, "art", "review", "world", "halo_v2")
OUT_MAP = os.path.join(OUT_DIR, "halo_plan_v2_map.png")

# ---------------------------------------------------------------- the town story
STORY = [
    "빛 마을(Halo Citadel)은 하늘에서 깨진 왕관 조각 하나가 떨어진 곳이다. 조각은 언덕 위 대성당이 지키고, 기사단은 서쪽 성에서 마을과 바다를 지킨다.",
    "새 친구는 교차로 다리를 건너 북쪽 성문으로 들어온다. 문 안에서 영웅상과 기사 Sir Gleam이 맞고, 몇 걸음 앞에서 길잡이 Bright가 기다린다.",
    "바로 옆 시장 골목에서 물약을 사고, 시냇물 다리를 건너 기사단 훈련장에서 첫 기술을 시험한 뒤, 다른 다리로 돌아 성문을 나가 교차로로 간다(첫 10분 고리).",
    "마을 사람들은 세 동네에 산다: 시장 위 언덕(가게 주인들), 동쪽 절벽 마을(바다를 보는 집), 남서쪽 정원 마을(꽃 키우는 집). 분수 광장이 모든 길이 만나는 마을 한가운데다.",
    "시냇물은 대성당 샘에서 시작해 정원 쉼터로 계단 폭포를 이루고, 북쪽으로 흘러 성문 옆 바다로 떨어진다. 그래서 문에 들어서면 폭포와 언덕 위 대성당이 함께 보인다.",
]

# ---------------------------------------------------------------- land + districts (polygons in x, z)
LAND = [(-150, -340), (-62, -335), (-30, -326), (30, -326), (92, -338), (150, -346), (186, -372), (178, -420),
        (193, -470), (186, -520), (196, -580), (189, -640), (176, -690), (120, -698), (60, -692), (0, -699),
        (-70, -690), (-130, -697), (-181, -676), (-193, -620), (-186, -560), (-197, -500), (-188, -452),
        (-171, -412), (-186, -372)]

DISTRICTS = [
    dict(id="arrival", name="들어오는 마당", y=0, color=(236, 226, 196),
         poly=[(-44, -328), (46, -328), (56, -380), (49, -438), (12, -447), (-30, -440), (-40, -400)],
         why="교차로 다리가 닿는 곳. 성문·영웅상·Sir Gleam·스폰·Bright가 모두 여기라 새 친구가 길을 잃지 않는다. 문에서 폭포(서)와 언덕 위 대성당(남동)이 보인다.",
         flowers=["흰", "연금", "하늘"], edge="성문 양쪽: 동쪽 큰 탑+등불 1, 서쪽 폭포+나무 무리+등불 2(거울 짝 없음)"),
    dict(id="market", name="시장 골목", y=4, y_to=8, color=(246, 210, 160),
         poly=[(49, -438), (58, -418), (110, -428), (126, -470), (114, -506), (70, -512), (28, -496), (12, -450)],
         why="Bright 바로 다음 할 일이 물약이라 스폰에서 40스터드 안에 물약 가게. 가게 4채가 한 골목에 각자 각도로 선다(A23-112). 골목은 0→8로 살짝 오른다.",
         flowers=["주황", "흰"], edge="골목 끝 꽃 화단 + 낮은 난간"),
    dict(id="market_hill", name="시장 위 언덕 동네", y=14, color=(250, 228, 196),
         poly=[(108, -362), (176, -376), (182, -420), (166, -468), (128, -470), (112, -430)],
         why="가게 주인들이 가게 위 언덕에 산다. 북동 끝은 교차로 다리가 보이는 작은 전망 자리.",
         flowers=["주황", "크림"], edge="단 턱(시장보다 6 높음) + 계단 1곳"),
    dict(id="training", name="기사단 훈련장", y=2, color=(214, 222, 170),
         poly=[(-56, -394), (-52, -440), (-66, -480), (-150, -486), (-172, -446), (-152, -404), (-100, -394)],
         why="첫 10분의 셋째 할 일(첫 기술 시험). 성문에서 다리 하나 건너면 바로라 시험 뒤 곧장 문으로 나간다. 평평하고 넓은 흙 마당에 허수아비·과녁.",
         flowers=["노랑", "흰"], edge="동쪽은 시냇물, 남쪽은 성 축대(단 턱 14)"),
    dict(id="castle", name="기사단 성", y=16, color=(200, 212, 232),
         poly=[(-150, -490), (-66, -488), (-72, -532), (-96, -566), (-152, -572), (-191, -556), (-195, -502)],
         why="기사단이 훈련장을 내려다보고 서쪽 바다를 지킨다. 성문(땅 높이 진짜 문)은 북쪽 훈련장 쪽, 큰 계단으로 이어진다. 돔 없음(A23-120).",
         flowers=["파랑", "흰"], edge="축대 벽 + 성벽 위 전망(서)"),
    dict(id="plaza", name="분수 광장", y=10, color=(240, 236, 214),
         poly=[(-34, -506), (30, -500), (70, -514), (78, -550), (50, -581), (0, -586), (-40, -560)],
         why="시장·성·동네·대성당 길이 모두 만나는 마을 한가운데. 들쭉날쭉한 광장 안에 잔디 섬과 화단(포장 ≤35%).",
         flowers=["분홍", "흰", "금"], edge="광장 둘레 낮은 화단, 서쪽은 시냇물"),
    dict(id="garden", name="정원 쉼터", y=12, color=(198, 230, 190),
         poly=[(-74, -570), (-40, -566), (-30, -604), (-60, -632), (-96, -612)],
         why="계단 폭포 웅덩이 옆 벤치·작은 장면. 광장에서 정원 마을로 가는 길에 쉬어 가는 곳.",
         flowers=["연보라", "흰"], edge="생울타리 + 웅덩이"),
    dict(id="garden_homes", name="정원 마을", y=12, y_to=16, color=(214, 236, 200),
         poly=[(-100, -578), (-152, -576), (-191, -602), (-185, -668), (-130, -694), (-76, -688), (-66, -642), (-96, -616)],
         why="꽃 키우는 사람들이 사는 남서쪽 조용한 동네. 집 4채가 마당·꽃밭과 함께, 1채는 바다를 본다.",
         flowers=["해바라기 노랑", "데이지 흰"], edge="나무 줄 + 낮은 울타리"),
    dict(id="cathedral", name="대성당 언덕", y=30, color=(232, 222, 242),
         poly=[(-24, -600), (40, -590), (96, -600), (106, -650), (82, -694), (0, -698), (-54, -690), (-58, -640)],
         why="왕관 조각을 지키는 곳이라 마을에서 가장 높다. 축에서 동쪽으로 비켜 서서 성문에서 바로 보인다(A23-112). 광장에서 큰 계단으로 오른다.",
         flowers=["흰", "연보라"], edge="언덕 축대 + 계단 폭포(서)"),
    dict(id="cliff_homes", name="동쪽 절벽 마을", y=18, y_to=22, color=(250, 214, 222),
         poly=[(84, -516), (126, -506), (170, -482), (192, -520), (195, -590), (184, -640), (140, -650), (106, -630), (96, -596), (80, -560)],
         why="바다를 보는 집 5채가 두 단(18·22)에 2~3채씩 무리. 절벽 끝 폭포가 바다로 떨어진다.",
         flowers=["분홍", "흰"], edge="절벽 + 둔덕"),
    dict(id="lookout", name="동남 전망대", y=34, color=(226, 236, 250),
         poly=[(110, -656), (184, -646), (174, -690), (116, -696)],
         why="마을에서 가장 높은 곳에서 바다와 마을 전체를 본다. 전망 탑 하나, 가장자리 8 안에는 낮은 것만.",
         flowers=["하늘", "흰"], edge="난간 + 탑"),
]

# ---------------------------------------------------------------- roads (polylines), width = studs
ROADS = [
    dict(id="main", name="큰 길(첫 10분 뼈대)", w=20, grade=1,
         pts=[(0, -336), (0, -362), (4, -400), (8, -426), (34, -448), (60, -470), (72, -496), (44, -524), (26, -560), (30, -588), (34, -612)],
         note="성문 → 영웅상(둘로 갈라져 감쌈) → 스폰 → 시장 골목 → 분수 광장 → 대성당 큰 계단"),
    dict(id="loop", name="훈련장 고리길", w=14, grade=2,
         pts=[(-4, -430), (-30, -436), (-48, -434), (-76, -440), (-100, -444), (-112, -424), (-96, -402), (-70, -384), (-50, -372), (-24, -366), (-8, -362)],
         note="스폰 → 다리 B1 → 훈련장 → 다리 B2 → 영웅상 → 성문(첫 10분 고리)"),
    dict(id="to_castle", name="성 큰 계단", w=12, grade=2, pts=[(-108, -470), (-112, -488), (-118, -500)], note="훈련장(2) → 성 문(16), 계단 + 쉼참 2"),
    dict(id="plaza_castle", name="광장-성 곁길", w=10, grade=2, pts=[(-30, -530), (-56, -528), (-80, -520), (-96, -512)], note="다리 B3 건너 성 뒤쪽 마당"),
    dict(id="to_hill", name="시장 위 언덕 계단", w=10, grade=2, pts=[(96, -458), (116, -444), (134, -420), (146, -396)], note="시장(8) → 언덕 동네(14)"),
    dict(id="to_cliff", name="절벽 마을 비탈", w=10, grade=2, pts=[(74, -536), (98, -548), (124, -556), (150, -576), (160, -608)], note="광장(10) → 절벽 마을(18 → 22)"),
    dict(id="to_garden", name="정원 길", w=8, grade=2, pts=[(-30, -566), (-56, -590), (-86, -616), (-118, -632), (-146, -650)], note="광장 → 정원 쉼터 → 정원 마을"),
    dict(id="to_lookout", name="전망대 길", w=6, grade=3, pts=[(84, -640), (116, -662), (146, -672)], note="대성당 언덕(30) → 전망대(34)"),
    dict(id="castle_wall", name="성벽 전망 곁길", w=5, grade=3, pts=[(-150, -560), (-176, -540), (-186, -514)], note="막다른 끝 = 서쪽 바다 전망(보상)"),
    dict(id="hill_point", name="북동 곶 곁길", w=5, grade=3, pts=[(150, -392), (170, -380)], note="막다른 끝 = 교차로 다리 보이는 벤치"),
]

WATER = dict(
    stream=[(-36, -600), (-58, -584), (-66, -556), (-58, -528), (-50, -500), (-50, -470), (-48, -440), (-50, -410), (-56, -382), (-66, -352), (-70, -336)],
    stream_w=[6, 7, 8, 9, 9, 10, 10, 10, 11, 12, 13],
    pools=[dict(id="spring", at=(-30, -606), r=7, y=30, note="대성당 샘"), dict(id="garden_pool", at=(-62, -584), r=9, y=12, note="정원 쉼터 웅덩이(계단 폭포 끝)"),
           dict(id="fountain", at=(22, -540), r=9, y=10, note="분수(2단)")],
    falls=[dict(id="W1", at=(-70, -340), drop="2 → 바다", steps=1, note="성문 서쪽, 문에서 보이는 폭포"),
           dict(id="W2", at=(-44, -592), drop="30 → 12", steps=3, note="대성당 샘 → 정원 쉼터, 계단 폭포 3단(지그재그)"),
           dict(id="W3", at=(194, -566), drop="18 → 바다", steps=2, note="동쪽 절벽 마을 끝, 2단")],
)

BRIDGES = [
    dict(id="B1", at=(-48, -434), len=16, kind="아치 돌다리", note="스폰 → 훈련장(첫 10분)"),
    dict(id="B2", at=(-56, -376), len=12, kind="작은 나무 다리", note="훈련장 → 성문 돌아가는 길"),
    dict(id="B3", at=(-58, -528), len=14, kind="금 난간 다리", note="광장 → 성 뒤 마당"),
]

# ---------------------------------------------------------------- buildings: kind -> footprint (w, d), height, floors, floor height, door (w, h)
KINDS = {
    "Gate": (50, 32, 48, 1, 20, (14, 20)),
    "Tower": (12, 12, 36, 3, 8, (4, 7)),
    "Shop": (24, 15, 18, 1, 9, (5, 7.5)),
    "HouseA": (24, 22, 26, 2, 7, (4, 7)),
    "HouseB": (26, 18, 28, 2, 7.5, (4, 7)),
    "Castle": (64, 40, 34, 3, 10, (8, 10)),
    "Cathedral": (70, 70, 54, 1, 24, (10, 14)),
    "Armory": (16, 12, 12, 1, 8, (5, 7)),
}

# (id, kind, district, x, z, faces=(x, z) the door looks at, note)
BUILDINGS = [
    ("Gate", "Gate", "arrival", 0, -346, (0, -300), "교차로 다리 끝. 통로 14×20, 양쪽으로 지나감"),
    ("Tower_GateEast", "Tower", "arrival", 40, -350, (20, -380), "성문 동쪽 큰 탑(서쪽엔 탑 없음 = 비대칭)"),
    ("Shop_Potion", "Shop", "market", 34, -470, (14, -440), "물약 가게: 스폰에서 보이게 북서를 봄"),
    ("Shop_Bakery", "Shop", "market", 82, -442, (66, -470), "빵집: 골목 북쪽"),
    ("Shop_Juice", "Shop", "market", 106, -482, (72, -482), "주스 가게: 골목 동쪽 끝"),
    ("Shop_Flower", "Shop", "market", 52, -500, (62, -472), "꽃 가게: 광장으로 내려가는 모퉁이"),
    ("House_Hill1", "HouseA", "market_hill", 128, -386, (146, -410), "언덕 동네 1"),
    ("House_Hill2", "HouseB", "market_hill", 162, -410, (138, -420), "언덕 동네 2"),
    ("House_Hill3", "HouseA", "market_hill", 146, -450, (150, -400), "언덕 동네 3"),
    ("Armory", "Armory", "training", -130, -414, (-108, -440), "기사단 무기고(작은 1층)"),
    ("Castle", "Castle", "castle", -136, -530, (-116, -470), "기사단 성: 문이 북쪽 훈련장 쪽"),
    ("Cathedral", "Cathedral", "cathedral", 36, -652, (32, -590), "대성당: 문이 북쪽 광장 쪽, 축에서 동쪽으로 비킴"),
    ("House_Cliff1", "HouseB", "cliff_homes", 112, -532, (96, -548), "절벽 마을 아래 단(18) 1"),
    ("House_Cliff2", "HouseA", "cliff_homes", 152, -522, (130, -556), "절벽 마을 아래 단(18) 2"),
    ("House_Cliff3", "HouseA", "cliff_homes", 176, -556, (200, -556), "바다를 보는 집"),
    ("House_Cliff4", "HouseB", "cliff_homes", 168, -616, (150, -580), "절벽 마을 위 단(22) 1"),
    ("House_Cliff5", "HouseA", "cliff_homes", 128, -620, (150, -596), "절벽 마을 위 단(22) 2"),
    ("House_Garden1", "HouseA", "garden_homes", -118, -604, (-100, -628), "정원 마을 1"),
    ("House_Garden2", "HouseB", "garden_homes", -148, -622, (-140, -646), "정원 마을 2"),
    ("House_Garden3", "HouseA", "garden_homes", -164, -664, (-210, -680), "바다를 보는 집"),
    ("House_Garden4", "HouseB", "garden_homes", -112, -670, (-130, -642), "정원 마을 4"),
    ("Tower_Lookout", "Tower", "lookout", 156, -676, (120, -662), "전망 탑"),
]

# ---------------------------------------------------------------- the first 10 minutes + fixed points
FIRST10 = [
    dict(n=1, at=(0, -420), what="도착(스폰, 성문 쪽을 봄)", fixed="Config.Zones.HaloTown.Spawn (0,0,-420) 그대로"),
    dict(n=2, at=(18, -424), what="길잡이 Bright", fixed="Config.TownNpcs Bright (18,-424) 그대로"),
    dict(n=3, at=(24, -458), what="물약 가게(물약 상인)", fixed="PotionHalo (20.07,-468.17) → (24,-458) 옮김"),
    dict(n=4, at=(-100, -444), what="기사단 훈련장(첫 기술 시험)", fixed="새 자리: 코드에 훈련장 표적/표시가 아직 없음"),
    dict(n=5, at=(0, -336), what="성문 → 교차로 다리", fixed="Config.Map.Gates HaloTown (0,0,-330) 그대로"),
]

# the walk itself (the road points between the stops): 1 -> 2 -> 3 -> back over B1 -> 4 -> round over B2 -> 5
ROUTE = [(0, -420), (18, -424), (24, -458), (8, -436), (-30, -436), (-48, -434), (-76, -440), (-100, -444), (-112, -424),
         (-96, -402), (-70, -384), (-56, -376), (-24, -366), (-8, -362), (0, -346)]

FIXED_KEEP = [
    ("성문 / 다리 끝", (0, -330), "Config.Map.Gates, 다리 경로 From (0,-150) To (0,-330)"),
    ("스폰 + 보는 쪽", (0, -420), "Config.Zones.HaloTown.Spawn / SpawnLook (0,0,-330)"),
    ("영웅상", (0, -370), "Config.StoryQuests.Landmarks.HeroStatue"),
    ("Sir Gleam", (-10, -372), "Config.TownNpcs Gleam"),
    ("Bright", (18, -424), "Config.TownNpcs Bright"),
    ("구역 경계", None, "Config.Zones.HaloTown Center (0,0,-515) Size 400×370 = x -200..200, z -700..-330; IslandHalo 같은 상자"),
    ("월드맵 이름 자리", (0, -400), "WorldMap.luau HaloTown 라벨"),
    ("오프닝 카메라", (0, -410), "Intro.luau Halo = (0,16,-410)"),
]
FIXED_MOVE = [
    ("물약 상인 PotionHalo", (20.07, -468.17), (24, -458), "Config.TownNpcs PotionHalo At/Look/Y(9 → 5)"),
    ("Folk1 주스", (38.42, -499.19), (88, -482), "Config.TownNpcs Folk1 At/Look/Y"),
    ("Folk2 꽃", (6.6, -489.63), (60, -490), "Config.TownNpcs Folk2 At/Look/Y"),
    ("Folk3 빵", (-6.35, -476.52), (76, -456), "Config.TownNpcs Folk3 At/Look/Y"),
    ("Folk4 분수", (46, -556), (34, -546), "Config.TownNpcs Folk4 At/Look(분수 (22,-540))/Y 10"),
    ("폭포 소리 6곳", None, None, "Config.Audio.Ambient.Waterfall.Spots → W1 (-70,1,-340), W2 (-44,20,-592), W3 (194,10,-566)"),
    ("빛 마을 미니맵 그림", None, None, "Config.UIArt MapHaloTown: 새 마을이 서면 다시 그림(이미지 개발)"),
    ("훈련장 (새)", None, (-100, -444), "새 Landmark TrainingYard + 허수아비 표적(게임성 개발: 첫 기술 퀘스트가 여기를 가리키게)"),
]

SCENES = [
    ("폭포 웅덩이 벤치", (-74, -596), "정원 쉼터, W2 계단 폭포를 봄"),
    ("성벽 전망", (-186, -514), "서쪽 바다"),
    ("북동 곶 벤치", (170, -380), "교차로 다리와 바다"),
    ("시장 끝 꽃 화분 탁자", (118, -500), "골목을 내려다봄"),
    ("절벽 마을 발코니", (188, -600), "동쪽 바다 + W3"),
    ("대성당 뒤 바다 전망", (40, -694), "남쪽 바다"),
    ("전망 탑 꼭대기", (156, -676), "마을 전체(사진 자리)"),
    ("훈련장 관람 계단", (-150, -470), "허수아비 마당을 봄"),
]


# ---------------------------------------------------------------- geometry
def inside(pt, poly):
    x, z = pt
    c = False
    n = len(poly)
    for i in range(n):
        x1, z1 = poly[i]
        x2, z2 = poly[(i + 1) % n]
        if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1:
            c = not c
    return c


def area(poly):
    s = 0.0
    for i in range(len(poly)):
        x1, z1 = poly[i]
        x2, z2 = poly[(i + 1) % len(poly)]
        s += x1 * z2 - x2 * z1
    return abs(s) / 2


def seg_dist(p, a, b):
    ax, az = a
    bx, bz = b
    px, pz = p
    dx, dz = bx - ax, bz - az
    t = max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / max(dx * dx + dz * dz, 1e-9)))
    return math.hypot(px - (ax + t * dx), pz - (az + t * dz))


def footprint(b):
    w, d = b["w"], b["d"]
    yaw = math.radians(b["yaw"])
    fx, fz = math.sin(yaw), math.cos(yaw)  # door direction (x, z)
    rx, rz = fz, -fx  # right
    pts = []
    for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        pts.append((b["x"] + rx * sx * w / 2 + fx * sz * d / 2, b["z"] + rz * sx * w / 2 + fz * sz * d / 2))
    return pts


def poly_overlap(a, b, gap=0.0):
    # separating axis test on two convex quads, grown by gap
    for poly in (a, b):
        for i in range(len(poly)):
            x1, z1 = poly[i]
            x2, z2 = poly[(i + 1) % len(poly)]
            nx, nz = z2 - z1, -(x2 - x1)
            ln = math.hypot(nx, nz)
            nx, nz = nx / ln, nz / ln
            pa = [x * nx + z * nz for x, z in a]
            pb = [x * nx + z * nz for x, z in b]
            if max(pa) + gap / 2 < min(pb) - gap / 2 or max(pb) + gap / 2 < min(pa) - gap / 2:
                return False
    return True


COMPASS = ["북", "북동", "동", "남동", "남", "남서", "서", "북서"]


def compass(dx, dz):
    # north = +z (toward the gate / Crossroads), east = +x
    ang = math.degrees(math.atan2(dx, dz)) % 360
    return COMPASS[int((ang + 22.5) // 45) % 8]


DIST = {d["id"]: d for d in DISTRICTS}


def build_list():
    out = []
    for bid, kind, dist, x, z, faces, note in BUILDINGS:
        w, d, h, floors, fh, door = KINDS[kind]
        dx, dz = faces[0] - x, faces[1] - z
        yaw = round(math.degrees(math.atan2(dx, dz)) / 5) * 5
        dd = DIST[dist]
        gy = dd["y"]
        out.append(dict(id=bid, kind=kind, district=dist, x=x, z=z, ground_y=gy, yaw=yaw,
                        door_dir=[round(math.sin(math.radians(yaw)), 3), round(math.cos(math.radians(yaw)), 3)],
                        door_compass=compass(math.sin(math.radians(yaw)), math.cos(math.radians(yaw))),
                        w=w, d=d, h=h, floors=floors, floor_h=fh, door_size=list(door), note=note))
    for b in out:
        yaw = math.radians(b["yaw"])
        b["door_at"] = [round(b["x"] + math.sin(yaw) * b["d"] / 2, 1), round(b["z"] + math.cos(yaw) * b["d"] / 2, 1)]
        b["footprint"] = [[round(p[0], 1), round(p[1], 1)] for p in footprint(b)]
    return out


def door_spurs(blds):
    """a garden path (grade 3, 4 wide) from every door to the nearest grade 1-2 road point"""
    spurs = []
    for b in blds:
        door = b["door_at"]
        best = None
        for r in ROADS:
            if r["grade"] == 3 and not r["id"].startswith("castle") and not r["id"].startswith("hill"):
                pass
            for i in range(len(r["pts"]) - 1):
                (ax, az), (bx, bz) = r["pts"][i], r["pts"][i + 1]
                dx, dz = bx - ax, bz - az
                t = max(0.0, min(1.0, ((door[0] - ax) * dx + (door[1] - az) * dz) / max(dx * dx + dz * dz, 1e-9)))
                q = (ax + t * dx, az + t * dz)
                dist = math.hypot(q[0] - door[0], q[1] - door[1]) - r["w"] / 2
                if best is None or dist < best[0]:
                    best = (dist, q, r["id"])
        b["door_to_path"] = round(max(best[0], 0), 1)
        b["path_from"] = best[2]
        if best[0] > 3:
            yaw = math.radians(b["yaw"])
            step = (door[0] + math.sin(yaw) * 5, door[1] + math.cos(yaw) * 5)
            spurs.append(dict(id="door_" + b["id"], name="문 앞 길", w=4, grade=3,
                              pts=[(door[0], door[1]), step, (round(best[1][0], 1), round(best[1][1], 1))],
                              note=f"{b['id']} 문 → {best[2]} ({best[0]:.0f})"))
    return spurs


def checks(blds):
    msgs = []
    for b in blds:
        fp = footprint(b)
        if not all(inside(p, LAND) for p in fp):
            msgs.append(f"땅 밖: {b['id']}")
        if not inside((b["x"], b["z"]), DIST[b["district"]]["poly"]):
            msgs.append(f"구역 밖: {b['id']} ({b['district']})")
        if b["door_to_path"] > 40:
            msgs.append(f"문 앞 길 멀다: {b['id']} {b['door_to_path']:.0f}")
    for i in range(len(blds)):
        for j in range(i + 1, len(blds)):
            if poly_overlap(footprint(blds[i]), footprint(blds[j]), gap=4):
                msgs.append(f"겹침(4 띄움): {blds[i]['id']} - {blds[j]['id']}")
    # mirror pairs: same kind within 12 studs of the x-mirrored other
    pairs = 0
    for i in range(len(blds)):
        for j in range(len(blds)):
            if i < j and blds[i]["kind"][:5] == blds[j]["kind"][:5]:
                if math.hypot(blds[i]["x"] + blds[j]["x"], blds[i]["z"] - blds[j]["z"]) < 12:
                    pairs += 1
                    msgs.append(f"거울 짝: {blds[i]['id']} - {blds[j]['id']}")
    # paving share (roads as width x length; squares counted from the plaza / arrival paved share)
    land = area(LAND)
    road = sum(r["w"] * math.hypot(r["pts"][i + 1][0] - r["pts"][i][0], r["pts"][i + 1][1] - r["pts"][i][1])
               for r in ROADS for i in range(len(r["pts"]) - 1))
    squares = 0.55 * area(DIST["plaza"]["poly"]) + 0.35 * area(DIST["arrival"]["poly"]) + 0.6 * area(DIST["training"]["poly"])
    pave = (road + squares) / land
    return msgs, pairs, land, pave


# ---------------------------------------------------------------- drawing
S = 2.4
PAD = 40
MW = int(400 * S) + PAD * 2
MH = int(370 * S) + PAD * 2
PANEL = 560


def P(x, z):
    return (PAD + (x + 200) * S, PAD + (-330 - z) * S)


def font(sz, bold=False):
    return ImageFont.truetype("C:/Windows/Fonts/malgunbd.ttf" if bold else "C:/Windows/Fonts/malgun.ttf", sz)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def draw_map(blds):
    im = Image.new("RGB", (MW + PANEL, MH), (120, 186, 222))
    d = ImageDraw.Draw(im, "RGBA")
    # sea texture: soft rings around the island are skipped (no rays); plain sea + a light shore
    d.polygon([P(*p) for p in LAND], fill=(246, 240, 214), outline=(110, 96, 70))
    for dd in DISTRICTS:
        k = 1.0 - min(dd["y"], 34) / 34 * 0.22
        d.polygon([P(*p) for p in dd["poly"]], fill=shade(dd["color"], k) + (255,), outline=(120, 110, 90, 255))
    # water
    st = WATER["stream"]
    for i in range(len(st) - 1):
        d.line([P(*st[i]), P(*st[i + 1])], fill=(80, 160, 215), width=int(WATER["stream_w"][i] * S))
    for p in WATER["pools"]:
        x, z = p["at"]
        r = p["r"] * S
        cx, cy = P(x, z)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(80, 160, 215), outline=(40, 110, 170))
    # roads
    for r in ROADS:
        col = {1: (255, 252, 240), 2: (232, 222, 196), 3: (214, 200, 168)}[r["grade"]]
        for i in range(len(r["pts"]) - 1):
            d.line([P(*r["pts"][i]), P(*r["pts"][i + 1])], fill=col, width=max(3, int(r["w"] * S)))
        for p in r["pts"]:
            cx, cy = P(*p)
            rr = r["w"] * S / 2
            d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=col)
        if r["grade"] == 1:
            for i in range(len(r["pts"]) - 1):
                d.line([P(*r["pts"][i]), P(*r["pts"][i + 1])], fill=(214, 176, 60, 160), width=2)
    # bridges
    for b in BRIDGES:
        cx, cy = P(*b["at"])
        d.rounded_rectangle([cx - 9, cy - b["len"] * S / 2, cx + 9, cy + b["len"] * S / 2], 4, fill=(160, 120, 80), outline=(90, 60, 30))
        d.text((cx + 12, cy - 8), b["id"], fill=(60, 40, 20), font=font(13, True))
    # falls
    for f in WATER["falls"]:
        cx, cy = P(*f["at"])
        d.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=(255, 255, 255), outline=(40, 110, 170), width=3)
        d.text((cx + 10, cy + 2), f["id"], fill=(20, 70, 130), font=font(13, True))
    # buildings
    for b in blds:
        fp = [P(*p) for p in footprint(b)]
        col = {"Gate": (226, 200, 120), "Tower": (210, 210, 220), "Shop": (250, 170, 110), "HouseA": (255, 255, 255),
               "HouseB": (250, 246, 236), "Castle": (150, 170, 210), "Cathedral": (240, 230, 255), "Armory": (190, 170, 140)}[b["kind"]]
        d.polygon(fp, fill=col, outline=(60, 50, 40), width=2)
        # door tick
        yaw = math.radians(b["yaw"])
        dx, dz = math.sin(yaw), math.cos(yaw)
        a = P(b["door_at"][0], b["door_at"][1])
        e = P(b["door_at"][0] + dx * 6, b["door_at"][1] + dz * 6)
        d.line([a, e], fill=(200, 40, 40), width=4)
    # labels for districts
    for dd in DISTRICTS:
        xs = [p[0] for p in dd["poly"]]
        zs = [p[1] for p in dd["poly"]]
        cx, cy = P(sum(xs) / len(xs), sum(zs) / len(zs))
        txt = f"{dd['name']}\nY{dd['y']}" + (f"→{dd['y_to']}" if dd.get("y_to") else "")
        f = font(15, True)
        bb = d.multiline_textbbox((0, 0), txt, font=f, align="center")
        w, h = bb[2] - bb[0], bb[3] - bb[1]
        d.rounded_rectangle([cx - w / 2 - 5, cy - h / 2 - 4, cx + w / 2 + 5, cy + h / 2 + 6], 6, fill=(255, 255, 255, 190))
        d.multiline_text((cx - w / 2, cy - h / 2), txt, fill=(40, 30, 20), font=f, align="center")
    # first 10 minutes
    route = ROUTE
    for i in range(len(route) - 1):
        d.line([P(*route[i]), P(*route[i + 1])], fill=(220, 40, 120, 200), width=3)
    for s in FIRST10:
        cx, cy = P(*s["at"])
        d.ellipse([cx - 13, cy - 13, cx + 13, cy + 13], fill=(220, 40, 120), outline=(255, 255, 255), width=2)
        d.text((cx - 5, cy - 11), str(s["n"]), fill=(255, 255, 255), font=font(17, True))
    # fixed points kept
    for name, at, _ in FIXED_KEEP:
        if at and name not in ("스폰 + 보는 쪽", "Bright", "성문 / 다리 끝", "월드맵 이름 자리", "오프닝 카메라"):
            cx, cy = P(*at)
            d.rectangle([cx - 5, cy - 5, cx + 5, cy + 5], fill=(30, 30, 30))
    # scenes
    for name, at, _ in SCENES:
        cx, cy = P(*at)
        d.regular_polygon((cx, cy, 7), 4, fill=(250, 210, 40), outline=(120, 90, 0))
    # compass + scale
    d.text((PAD, 8), "북 = 성문·교차로 다리 (z -330)   ·   1칸 = 50스터드   ·   Y = 땅 높이", fill=(20, 40, 70), font=font(15, True))
    for gx in range(-200, 201, 50):
        d.line([P(gx, -330), P(gx, -334)], fill=(20, 40, 70), width=1)
        d.text((P(gx, -330)[0] - 10, MH - PAD + 6), str(gx), fill=(20, 40, 70), font=font(11))
    for gz in range(-350, -701, -50):
        d.text((4, P(0, gz)[1] - 7), str(gz), fill=(20, 40, 70), font=font(11))
    return im, d


def draw_panel(im, d, blds, stats):
    x0 = MW + 16
    y = 14
    d.rectangle([MW, 0, MW + PANEL, MH], fill=(250, 248, 242))
    d.text((x0, y), "빛 마을 v2 — 1단계 이야기와 구역", fill=(30, 30, 30), font=font(22, True)); y += 38
    d.text((x0, y), "첫 10분 고리 (분홍 번호)", fill=(200, 30, 110), font=font(16, True)); y += 26
    for s in FIRST10:
        d.text((x0 + 6, y), f"{s['n']}. {s['what']}", fill=(40, 40, 40), font=font(14)); y += 21
    y += 8
    d.text((x0, y), "구역 (Y = 높이, 꽃 색)", fill=(30, 30, 30), font=font(16, True)); y += 26
    for dd in DISTRICTS:
        yy = f"{dd['y']}" + (f"→{dd['y_to']}" if dd.get("y_to") else "")
        d.rectangle([x0 + 4, y + 4, x0 + 16, y + 16], fill=dd["color"], outline=(90, 80, 60))
        d.text((x0 + 22, y), f"{dd['name']}  Y{yy}  ·  {'/'.join(dd['flowers'])}", fill=(40, 40, 40), font=font(14)); y += 21
    y += 8
    cnt = {}
    for b in blds:
        cnt[b["kind"]] = cnt.get(b["kind"], 0) + 1
    houses = cnt.get("HouseA", 0) + cnt.get("HouseB", 0)
    d.text((x0, y), "건물 22채 (빨간 짧은 선 = 문 방향)", fill=(30, 30, 30), font=font(16, True)); y += 26
    lines = [f"성문 1 · 탑 {cnt.get('Tower', 0)} (성문 동쪽 1, 전망 1)", f"가게 {cnt.get('Shop', 0)} (물약·빵·주스·꽃, 시장 골목 한 줄)",
             f"집 {houses} = 시장 위 3 · 절벽 5 · 정원 4", "기사단 성 1 (64×40, 3층, 돔 없음) · 무기고 1", "대성당 1 (70×70, 언덕 Y30, 축에서 동쪽)"]
    for ln in lines:
        d.text((x0 + 6, y), ln, fill=(40, 40, 40), font=font(14)); y += 21
    y += 8
    d.text((x0, y), "물·다리", fill=(30, 30, 30), font=font(16, True)); y += 26
    for ln in ["시냇물 1줄: 대성당 샘 → 계단 폭포 W2(3단) → 광장 서쪽 → 성문 옆 W1로 바다",
               "W3: 동쪽 절벽 마을 2단 폭포 · 분수 2단(광장)", "다리 3개(모양·길이 다름): B1 첫 10분, B2 고리, B3 성 뒤"]:
        d.text((x0 + 6, y), ln, fill=(40, 40, 40), font=font(13)); y += 20
    y += 8
    d.text((x0, y), "고정점", fill=(30, 30, 30), font=font(16, True)); y += 26
    for ln in ["그대로: 성문(0,-330), 스폰(0,-420), 영웅상, Gleam, Bright, 구역 상자",
               "옮김: 물약 상인 · Folk1~4 · 폭포 소리 · 미니맵 그림 (Config 목록은 JSON)",
               "새로: 훈련장 표적·표시 (게임성 개발 몫)"]:
        d.text((x0 + 6, y), ln, fill=(40, 40, 40), font=font(13)); y += 20
    y += 8
    d.text((x0, y), "검사", fill=(30, 30, 30), font=font(16, True)); y += 26
    for ln in [f"포장 약 {stats['pave'] * 100:.0f}% (목표 ≤35%) · 거울 짝 {stats['pairs']}",
               f"겹침·땅 밖·문 앞 길 먼 것: {stats['issues']}건", "노란 마름모 = 작은 장면·사진 자리 8곳", "검은 네모 = 그대로 두는 고정점"]:
        d.text((x0 + 6, y), ln, fill=(40, 40, 40), font=font(13)); y += 20


def main():
    blds = build_list()
    ROADS.extend(door_spurs(blds))
    msgs, pairs, land, pave = checks(blds)
    for m in msgs:
        print("[check]", m)
    stats = dict(pave=pave, pairs=pairs, issues=len([m for m in msgs if not m.startswith("거울")]), land=land)
    print(f"[plan] land {land:.0f} st² · paving ~{pave * 100:.1f}% · mirror pairs {pairs} · buildings {len(blds)} · issues {stats['issues']}")
    os.makedirs(OUT_DIR, exist_ok=True)
    im, d = draw_map(blds)
    draw_panel(im, d, blds, stats)
    im.save(OUT_MAP)
    plan = dict(
        note="빛 마을 v2 1단계 '이야기와 구역' (SPEC A23-121, 이미지 생성 1, 2026-10-11). 옛 섬·옛 plan은 쓰지 않음. 좌표 x,z(스터드), "
             "북 = z -330 성문/교차로 다리. y = 그 구역 땅 높이(y_to = 경사 끝). 건물 yaw = 문이 보는 방향(0 = 북 +z, 90 = 동 +x). "
             "3단계 회색 상자와 4단계 골격은 이 값을 쓴다.",
        frame=dict(x=[-200, 200], z=[-700, -330], north="z -330 (gate, Crossroads bridge)"),
        story=STORY,
        first_10_minutes=FIRST10,
        first_10_route=[list(p) for p in ROUTE],
        land=[list(p) for p in LAND],
        districts=[{k: (v if k != "poly" else [list(p) for p in v]) for k, v in dd.items() if k != "color"} for dd in DISTRICTS],
        roads=[{**r, "pts": [list(p) for p in r["pts"]]} for r in ROADS],
        water={**WATER, "stream": [list(p) for p in WATER["stream"]]},
        bridges=BRIDGES,
        buildings=blds,
        scenes=[dict(name=n, at=list(a), view=v) for n, a, v in SCENES],
        fixed_points=dict(keep=[dict(name=n, at=list(a) if a else None, code=c) for n, a, c in FIXED_KEEP],
                          move=[dict(name=n, now=list(a) if a else None, new=list(b) if b else None, code=c) for n, a, b, c in FIXED_MOVE]),
        checks=dict(paving_share=round(pave, 3), mirror_pairs=pairs, issues=msgs, land_area=round(land)),
        rules="A23-112 비대칭, A23-117 구역·이유, A23-106/120 진짜 문·빈 속, 성 돔 없음, 빛살 무늬 금지, acnh 12규칙",
    )
    with open(OUT_JSON, "w", encoding="utf-8", newline="") as f:
        f.write(json.dumps(plan, ensure_ascii=False, indent=1) + "\n")
    print("[plan] wrote", OUT_JSON, OUT_MAP)


if __name__ == "__main__":
    main()
