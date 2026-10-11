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
import re
import sys

import halo_props_v2 as HP

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_JSON = os.path.join(ROOT, "docs", "design", "halo_plan_v2_2026-10-11.json")
OUT_DIR = os.path.join(ROOT, "art", "review", "world", "halo_v2")
OUT_MAP = os.path.join(OUT_DIR, "halo_plan_v2_map.png")

def config_walk_speed():
    """Config.Player.WalkSpeed (검수 결정 1: walking times at the game's own speed, it was a hard-coded 16)"""
    src = open(os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "Config.luau"), encoding="utf-8").read()
    m = re.search(r"Config\.Player\s*=\s*\{[^}]*?WalkSpeed\s*=\s*(\d+(?:\.\d+)?)", src)
    return float(m.group(1)) if m else 16.0


WALK_SPEED = config_walk_speed()

# ---------------------------------------------------------------- the town story
STORY = [
    "빛 마을(Halo Citadel)은 하늘에서 깨진 왕관 조각 하나가 떨어진 곳이다. 조각은 언덕 위 대성당이 지키고, 기사단은 서쪽 성에서 마을과 바다를 지킨다.",
    "새 친구는 진영을 고르면 마을 한가운데 길(스폰)에 선다. Hallie 카드가 첫 할 일을 알려 준다: 교차로 대장간 Otto에게 무기를 받고 슬라임 5마리.",
    "그래서 첫 걸음은 곧장 북쪽 성문(84스터드)으로 나가 교차로 대장간 → 초원이다. 문 안에서 영웅상과 기사 Sir Gleam이 배웅한다.",
    "첫 장(M1)을 마치고 'Go to your town'으로 돌아오면 그때 시장 골목에서 물약을 사고, 시냇물 다리 B1을 건너 기사단 훈련장을 들르고, B2로 돌아 성문으로 다시 나간다(돌아와 들르는 고리).",
    "마을 사람들은 세 동네에 산다: 시장 위 언덕(가게 주인들), 동쪽 절벽 마을(바다를 보는 집), 남서쪽 정원 마을(꽃 키우는 집). 분수 광장이 모든 길이 만나는 마을 한가운데다.",
    "시냇물은 대성당 샘에서 시작해 정원 쉼터로 계단 폭포를 이루고, 북쪽으로 흘러 성문 옆 바다로 떨어진다. 문에 들어서면 정면 멀리 언덕 위 대성당, 왼쪽으로 돌면 W1 폭포가 보인다.",
]

# ---------------------------------------------------------------- land + districts (polygons in x, z)
# Shoreline in FINAL coordinates (after the grow below). 10/11 검수 ③ 2차 drew it (passed: "둥글고 들쭉날쭉"): 4 big capes
# (the entry neck the bridge lands on, NE hill cape, SE lookout cape, SW garden cape), bays NW (stream mouth, W1), NE (gate
# tower - hill), E (hill - cliff homes) and a west inlet (training - castle), a ragged cliff coast at the back (south).
# ③ 3차 grew it with the town (x 1.5/0.86, z 1.5/0.90 outside the core) and split every edge >= 26 with a small wiggle.
LAND = [(-30, -325), (-10, -325), (10, -325), (30, -325), (50, -328), (71, -336), (78, -350), (85, -364), (99, -376),
        (117, -378), (134, -370), (141, -356), (162, -350), (178, -349), (193, -352), (208, -359), (225, -358),
        (240, -357), (253, -366), (264, -373), (277, -376), (295, -392), (295, -410), (281, -428), (267, -447),
        (260, -460), (249, -470), (235, -490), (235, -510), (253, -523), (274, -537), (278, -551), (288, -563),
        (290, -582), (284, -600), (285, -618), (295, -633), (293, -650), (288, -667), (280, -683), (281, -700),
        (286, -715), (281, -730), (280, -745), (284, -760), (282, -776), (274, -790), (264, -800), (260, -813),
        (250, -825), (235, -830), (219, -828), (204, -837), (191, -844), (176, -847), (159, -839), (141, -840),
        (127, -851), (110, -853), (91, -846), (71, -843), (55, -851), (36, -853), (14, -840), (-8, -850),
        (-30, -837), (-45, -839), (-57, -847), (-75, -844), (-89, -833), (-109, -832), (-127, -840), (-145, -840),
        (-162, -837), (-177, -829), (-193, -830), (-209, -830), (-221, -820), (-234, -808), (-249, -800),
        (-264, -789), (-274, -773), (-274, -756), (-281, -740), (-290, -725), (-291, -707), (-283, -693),
        (-284, -677), (-290, -662), (-291, -647), (-291, -626), (-298, -607), (-300, -586), (-291, -567),
        (-286, -554), (-284, -540), (-270, -523), (-249, -513), (-246, -493), (-263, -477), (-266, -463),
        (-263, -450), (-253, -430), (-242, -412), (-235, -398), (-214, -384), (-201, -381), (-190, -372),
        (-177, -364), (-162, -364), (-138, -358), (-117, -350), (-103, -342), (-92, -336), (-71, -330), (-47, -327)]

DISTRICTS = [
    dict(id="arrival", name="들어오는 마당", y=0, color=(236, 226, 196),
         poly=[(-44, -328), (46, -328), (56, -380), (49, -438), (12, -447), (-30, -440), (-40, -400)],
         why="교차로 다리가 닿는 곳. 성문·영웅상·Sir Gleam·스폰·이동 발판이 모두 여기라 새 친구가 길을 잃지 않는다. 문에서 정면 멀리 언덕 위 대성당(남, 조금 동), 왼쪽(서)에 W1 폭포.",
         flowers=["흰", "연금", "하늘"], edge="성문 양쪽: 동쪽 큰 탑+등불 1, 서쪽 폭포+나무 무리+등불 2(거울 짝 없음)"),
    dict(id="market", name="시장 골목", y=4, y_to=8, color=(246, 210, 160),
         poly=[(49, -438), (58, -418), (110, -428), (126, -470), (114, -506), (70, -512), (28, -496), (12, -450)],
         why="__MARKET_WHY__",
         flowers=["주황", "흰"], edge="골목 끝 꽃 화단 + 낮은 난간"),
    dict(id="market_hill", name="시장 위 언덕 동네", y=14, color=(250, 228, 196),
         poly=[(108, -362), (176, -376), (182, -420), (166, -468), (128, -470), (112, -430)],
         why="가게 주인들이 가게 위 언덕에 산다. 북동 끝은 교차로 다리가 보이는 작은 전망 자리.",
         flowers=["주황", "크림"], edge="단 턱(시장보다 6 높음) + 계단 1곳"),
    dict(id="training", name="기사단 훈련장", y=2, color=(214, 222, 170),
         poly=[(-56, -394), (-52, -440), (-66, -480), (-150, -486), (-172, -446), (-152, -404), (-100, -394)],
         why="첫 장(M1_4 'Go to your town') 뒤 돌아와 기술을 연습하는 곳. 스폰에서 다리 B1 하나 건너면 바로, B2로 돌아 성문으로 나간다. 평평하고 넓은 흙 마당에 허수아비·과녁.",
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
         poly=[(-24, -600), (40, -590), (104, -602), (112, -652), (96, -694), (0, -698), (-54, -690), (-58, -640)],
         why="__CATHEDRAL_WHY__",
         flowers=["흰", "연보라"], edge="언덕 축대 + 계단 폭포(서)"),
    dict(id="cliff_homes", name="동쪽 절벽 마을", y=18, y_to=22, color=(250, 214, 222),
         poly=[(84, -516), (126, -506), (170, -482), (192, -520), (195, -590), (184, -640), (140, -650), (106, -630), (96, -596), (80, -560)],
         why="바다를 보는 집 5채가 두 단(18·22)에 2~3채씩 무리. 절벽 끝 폭포가 바다로 떨어진다.",
         flowers=["분홍", "흰"], edge="절벽 + 둔덕"),
    dict(id="lookout", name="동남 전망대", y=34, color=(226, 236, 250),
         poly=[(118, -658), (184, -646), (174, -690), (122, -696)],
         why="마을에서 가장 높은 곳에서 바다와 마을 전체를 본다. 전망 탑 하나, 가장자리 8 안에는 낮은 것만.",
         flowers=["하늘", "흰"], edge="난간 + 탑"),
]

# ---------------------------------------------------------------- roads (polylines), width = studs
ROADS = [
    dict(id="main", name="큰 길(첫 10분 뼈대)", w=20, grade=1,
         pts=[(0, -336), (0, -362), (2, -400), (6, -426), (34, -448), (60, -470), (72, -496), (44, -524), (22, -552), (40, -578), (62, -596), (70, -614)],
         note="성문 → 스폰(통로는 곧게) → 시장 골목 → 분수 광장(서쪽으로 돌아) → 동쪽으로 굽어 대성당 큰 계단"),
    dict(id="loop", name="훈련장 고리길", w=14, grade=2,
         pts=[(-4, -430), (-30, -436), (-48, -434), (-76, -440), (-100, -444), (-112, -424), (-96, -402), (-70, -384), (-50, -372), (-24, -366), (-8, -362)],
         note="스폰 → 다리 B1 → 훈련장 → 다리 B2 → 영웅상 → 성문(첫 10분 고리)"),
    dict(id="to_castle", name="성 큰 계단", w=12, grade=2, pts=[(-108, -470), (-112, -488), (-118, -500)], note="훈련장(2) → 성 문(16), 계단 + 쉼참 2"),
    dict(id="plaza_castle", name="광장-성 곁길", w=10, grade=2, pts=[(-30, -530), (-56, -528), (-80, -520), (-96, -512)], note="다리 B3 건너 성 뒤쪽 마당"),
    dict(id="to_hill", name="시장 위 언덕 계단", w=10, grade=2, pts=[(96, -458), (116, -444), (134, -420), (146, -396)], note="시장(8) → 언덕 동네(14)"),
    dict(id="to_cliff", name="절벽 마을 비탈", w=10, grade=2, pts=[(74, -536), (98, -548), (124, -556), (150, -576), (160, -608)], note="광장(10) → 절벽 마을(18 → 22)"),
    dict(id="to_garden", name="정원 길", w=8, grade=2, pts=[(-30, -566), (-56, -590), (-86, -616), (-118, -632), (-146, -650)], note="광장 → 정원 쉼터 → 정원 마을"),
    dict(id="to_lookout", name="전망대 길", w=6, grade=3, pts=[(104, -628), (114, -646), (130, -664), (146, -672)], note="대성당 언덕(30) → 전망대(34)"),
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
    dict(id="B2", at=(-56, -376), len=16, kind="작은 나무 다리", note="훈련장 → 성문 돌아가는 길"),  # review: 12 < stream 11 + 3
    dict(id="B3", at=(-58, -528), len=14, kind="금 난간 다리", note="광장 → 성 뒤 마당"),
]

# ---------------------------------------------------------------- buildings: kind -> footprint (w, d), height, floors, floor height, door (w, h)
KINDS = {
    "Gate": (50, 16, 48, 1, 30, (16, 30)),          # ④ skeleton (10/11): 44 -> 48 with the gold domes + finials, passage 16 x 30 kept
    "Tower": (12, 12, 46, 3, 8, (4, 7)),           # ④: 36 was the gallery line; with the gold dome, finial 46 (halo ring 47)
    "Shop": (24, 15, 18, 1, 9, (5, 7.5)),
    "HouseA": (24, 22, 26, 2, 7, (4, 7)),
    "HouseB": (26, 18, 28, 2, 7.5, (4, 7)),
    "Castle": (100, 70, 44, 3, 12, (10, 12)),  # 10/11 ③ 3차: new castle of light (F3 line), was 64 x 40
    "Cathedral": (70, 70, 54, 1, 24, (10, 14)),
    "Armory": (16, 12, 14, 1, 8, (4.4, 6.4)),      # ④: approved 2D (art/review/s2/halo_armory_views.jpg): hip roof + finial 14, door 4.4 x 6.4 (> avatar 5)
}

# (id, kind, district, x, z, faces=(x, z) the door looks at, note)
BUILDINGS = [
    ("Gate", "Gate", "arrival", 0, -334, (0, -300), "Gate_HaloTown Lintel (0,-330) 그대로. 깊이 16(다리 끝에 걸침), 통로 16×30: 오프닝 카메라 (18,30,-315)→(6,26,-340)가 문 안으로 지나가게"),
    ("Tower_GateEast", "Tower", "arrival", 40, -350, (20, -380), "성문 동쪽 큰 탑(서쪽엔 탑 없음 = 비대칭)"),
    ("Shop_Potion", "Shop", "market", 34, -470, (14, -440), "물약 가게: 스폰에서 보이게 북서를 봄"),
    ("Shop_Bakery", "Shop", "market", 82, -442, (66, -470), "빵집: 골목 북쪽"),
    ("Shop_Juice", "Shop", "market", 106, -482, (72, -482), "주스 가게: 골목 동쪽 끝"),
    ("Shop_Flower", "Shop", "market", 44, -500, (62, -472), "꽃 가게: 광장으로 내려가는 모퉁이"),
    ("House_Hill1", "HouseA", "market_hill", 128, -386, (146, -410), "언덕 동네 1"),
    ("House_Hill2", "HouseB", "market_hill", 162, -410, (138, -420), "언덕 동네 2"),
    ("House_Hill3", "HouseA", "market_hill", 146, -450, (150, -400), "언덕 동네 3"),
    ("Armory", "Armory", "training", -130, -414, (-108, -440), "기사단 무기고(작은 1층)"),
    ("Castle", "Castle", "castle", -136, -530, (-116, -470), "기사단 성: 문이 북쪽 훈련장 쪽"),
    ("Cathedral", "Cathedral", "cathedral", 72, -652, (66, -590), "대성당: 문이 북쪽 큰 계단 쪽, 축에서 동쪽으로 72 비킴(검수 10/11)"),
    ("House_Cliff1", "HouseB", "cliff_homes", 112, -532, (96, -548), "절벽 마을 아래 단(18) 1"),
    ("House_Cliff2", "HouseA", "cliff_homes", 152, -522, (130, -556), "절벽 마을 아래 단(18) 2"),
    ("House_Cliff3", "HouseA", "cliff_homes", 176, -556, (200, -556), "바다를 보는 집"),
    ("House_Cliff4", "HouseB", "cliff_homes", 168, -616, (150, -580), "절벽 마을 위 단(22) 1"),
    ("House_Cliff5", "HouseA", "cliff_homes", 128, -620, (150, -596), "절벽 마을 위 단(22) 2"),
    ("House_Garden1", "HouseA", "garden_homes", -118, -604, (-100, -628), "정원 마을 1"),
    ("House_Garden2", "HouseB", "garden_homes", -148, -622, (-140, -646), "정원 마을 2"),
    ("House_Garden3", "HouseA", "garden_homes", -164, -664, (-210, -680), "바다를 보는 집"),
    ("House_Garden4", "HouseB", "garden_homes", -112, -670, (-130, -642), "정원 마을 4"),
    ("Tower_Lookout", "Tower", "lookout", 178, -654, (150, -668), "전망 탑: 북동 모서리(검수 10/11 ③ 사진 14 — 광장은 대성당 북동 모서리 너머로만 보여서 여기, 꼭대기 눈높이 75)"),
]

# ---------------------------------------------------------------- the first 10 minutes + fixed points
# 검수 결정 4 (10/11): the real flow of the game (Config.Tutorial / Welcome / M1): the Hallie card sends the new player
# straight out of the gate to the Crossroads Forge (Otto, first weapon) and the meadow (5 slimes). The shops and the training
# yard are the return visit at M1_4 "Go to your town" (FIRST10_RETURN). at = None: outside the town (not drawn on the map)
FIRST10 = [
    dict(n=1, at=(0, -420), what="도착(스폰, 성문 쪽을 봄) + Hallie 카드(화면): 첫 할 일 = 대장간 Otto 무기 → 슬라임 5",
         fixed="Config.Zones.HaloTown.Spawn (0,0,-420) 그대로 · Config.Tutorial.Welcome.Halo (월드 NPC 없음)"),
    dict(n=2, at=(0, -336), what="성문 → 교차로 다리 (스폰에서 84스터드, 걸어서 약 4초)", fixed="Config.Map.Gates HaloTown (0,0,-330) 그대로"),
    dict(n=3, at=None, what="교차로 대장간 Otto: 첫 무기 (Tutorial.Steps.Forge, M1_1)", fixed="교차로 (빛 마을 밖)"),
    dict(n=4, at=None, what="초원: 슬라임 5 → 첫 사냥·레벨 (M1_2·M1_3)", fixed="SlimeMeadow (빛 마을 밖)"),
]
FIRST10_RETURN = [
    dict(n="R1", at=(0, -336), what="M1_4 'Go to your town': 성문으로 돌아옴", fixed="Enter OwnTown"),
    dict(n="R2", at=(0, -420), what="Hallie에게 보고(화면 패널)", fixed="M1_4 Talk (Panel)"),
    dict(n="R3", at=None, what="시장 골목 물약 가게(물약 상인)", fixed="PotionHalo (새 자리는 fixed_points.move)"),
    dict(n="R4", at=(-130, -446), what="다리 B1 → 기사단 훈련장(기술 연습)", fixed="새 Landmark TrainingYard (퀘스트 연결은 코드 변경 요청 = 검수)"),
    dict(n="R5", at=(0, -346), what="다리 B2로 돌아 성문 → 다음 장", fixed="-"),
]

# the first walk (spawn -> gate) and the return loop (gate -> spawn -> potion -> B1 -> training -> B2 -> gate), FINAL coordinates
ROUTE = [(0, -420), (0, -346)]
ROUTE_RETURN = [(0, -346), (0, -420), None, (8, -436), (-30, -436), (-52, -434), (-94, -440), (-130, -446), (-148, -424),
                (-124, -402), (-85, -386), (-55, -377), (-26, -374), (-6, -374), (0, -346)]

FIXED_KEEP = [
    ("Bridge_Halo", (0, -330), "Map.Decor.Bridge_Halo (0,-150)→(0,-330) 폭 22, 갑판 Y ~0.2: 교차로로 나가는 유일한 길"),
    ("Gate_HaloTown", (0, -330), "Map.Gates.Gate_HaloTown, PrimaryPart Lintel (Config 1734, MapBuilder가 매번 맞춤)"),
    ("스폰 + 보는 쪽", (0, -420), "Config.Zones.HaloTown.Spawn (0,0,-420) / SpawnLook (0,0,-330); 스폰 ±6 땅 = Y 0"),
    ("스폰-문 통로", None, "|x|≤12, z -330..-432 와 (0,-420) 반경 12는 비움(큰 길만, 소품·NPC·동상 없음)"),
    ("Bright", (18, -424), "Config.TownNpcs Bright (통로 밖, 스폰에서 18)"),
    ("이동 발판", (-24, -357), "Map.Pads Pad_Halo_SlimeMeadow (-24,0.7,-357) / Pad_Halo_GoblinWoods (24,0.7,-357) 그대로"),
    ("월드맵 라벨", (0, -400), "WorldMap.luau HaloTown"),
]
# (what, now, new (x, y, z) or None, Config / code to change)
FIXED_MOVE = [
    ("영웅상 HeroStatue", (0, -370), (-34, 0, -388), "Config.StoryQuests.Landmarks.HeroStatue (통로 |x|≤12 안이라 서쪽으로 비킴, 큰 길을 봄; H6 Near 16)"),
    ("Sir Gleam", (-10, -372), (-20, 0, -390), "Config.TownNpcs Gleam At/Look(0,-390) (통로 밖, 영웅상 옆에서 큰 길을 봄 — 옛 (-22,-368)은 고리길 위)"),
    ("물약 상인 PotionHalo", (20.07, -468.17), (24, 5, -458), "Config.TownNpcs PotionHalo At/Look(14,-440)/Y 5 (12칸 안 판매 그대로)"),
    ("Folk3 빵집", (-6.35, -476.52), (76, 7, -454), "Config.TownNpcs Folk3 At/Look(66,-470)/Y 7"),
    ("Folk1 주스", (38.42, -499.19), (92, 8, -484), "Config.TownNpcs Folk1 At/Look(72,-482)/Y 8"),
    ("Folk2 꽃", (6.6, -489.63), (58, 8, -490), "Config.TownNpcs Folk2 At/Look(62,-472)/Y 8"),
    ("Folk4 분수", (46, -556), (36, 10, -548), "Config.TownNpcs Folk4 At/Look(22,-540)/Y 10; 분수 이름 Town_Halo_Fountain3"),
    ("폭포 소리 6곳", None, None, "Config.Audio.Ambient.Waterfall.Spots → W1 (-70,1,-340), W2 (-44,20,-592), W3 (194,10,-566) 3곳(또는 Decor 아래 이름 …Waterfall)"),
    ("구역 상자·섬 땅·경계 (③ 3차)", None, None,
     f"땅이 x {min(p[0] for p in LAND)}..{max(p[0] for p in LAND)}, z {min(p[1] for p in LAND)}..{max(p[1] for p in LAND)}로 커짐 → "
     "Config.Zones.HaloTown Center/Size(안전 구역·음악·Enter 퀘스트·튕겨내기·몬스터 추적), Map.Land IslandHalo, Map.Bounds MinX/MinZ(-260/-720), "
     "Outskirts Size, 미니맵·큰 지도 범위를 같이 넓힘. 가장 높은 땅 Y 34 < 물 구조 MaxRise 42 그대로. 이웃 초원 z -240..240과 안 겹침"),
    ("RoadNorthIsland 띠", None, None, "미니맵 x -8..8, z -600..-330 → 새 큰 길 따라(성문→스폰→시장→광장→대성당)"),
    ("큰 지도·미니맵", None, None, "WorldMapV2 그림(이미지 생성 2) + Halo MapTiles 다시 찍기(6단계 직전)"),
    ("훈련장 (새)", None, (-100, 2, -444), "새 Landmark TrainingYard + 허수아비 표적(M1_4 귀환 뒤 들르는 곳. 퀘스트가 여기를 가리키게 할지는 코드 변경 요청 = 검수 결정)"),
    ("오프닝 카메라", None, None, "Intro.luau (18,30,-315)→(6,26,-340), 조각 (0,18,-406): 새 성문 통로 16×30이면 그대로, 3단계 사진으로 확인"),
]
GROUND_RULE = "걷는 바닥은 전부 Terrain(마당·길·광장·건물 앞·다리 끝 땅). 파트 바닥은 땅으로 안 침(MonsterService·ZoneService·KaijuService·LandShadow·SkillFx·Fx). 개발의 WalkGround 태그 전까지 건물 1층 바닥도 Terrain 위에 바로 문턱. 다리만 Decor.Bridge_* 이름."

SCENES = [
    ("폭포 웅덩이 벤치", (-74, -596), "정원 쉼터, W2 계단 폭포를 봄"),
    ("성벽 전망", (-186, -514), "서쪽 바다"),
    ("북동 곶 벤치", (170, -380), "교차로 다리와 바다"),
    ("시장 끝 꽃 화분 탁자", (118, -500), "골목을 내려다봄"),
    ("절벽 마을 발코니", (188, -600), "동쪽 바다 + W3"),
    ("대성당 뒤 바다 전망", (40, -694), "남쪽 바다"),
    ("전망 탑 꼭대기", (178, -654), "마을 전체(사진 자리): 광장·대성당·바다"),
    ("훈련장 관람 계단", (-150, -470), "허수아비 마당을 봄"),
]


# ---------------------------------------------------------------- grow (10/11 검수 ③ 3차, 사용자 "빛 마을 너무 작은 거 아니야?")
# The entry core stays exactly where the code expects it (gate, spawn, Bright, Sir Gleam, pads: |x| <= 40 and z >= -440);
# everything outside it is spread out 1.5x from the 10/11 stage-1 map (the island floats now, so no box limits it):
# ~560 x 540 studs of land, about the meadow / woods size. Building sizes do not scale; the space between them does.
SHRINK = dict(core_x=40, core_z=-440, kx=1.5, kz=1.5)


def shrink(x, z):
    c, cz = SHRINK["core_x"], SHRINK["core_z"]
    if abs(x) > c:
        x = math.copysign(c + (abs(x) - c) * SHRINK["kx"], x)
    if z < cz:
        z = cz + (z - cz) * SHRINK["kz"]
    return round(x, 1), round(z, 1)


for _d in DISTRICTS:
    _d["poly"] = [shrink(*p) for p in _d["poly"]]
for _r in ROADS:
    _r["pts"] = [shrink(*p) for p in _r["pts"]]
WATER["stream"] = [shrink(*p) for p in WATER["stream"]]
for _w in WATER["pools"] + WATER["falls"] + BRIDGES:
    _w["at"] = shrink(*_w["at"])
BUILDINGS = [(i, k, dd, *shrink(x, z), shrink(*f), n) for (i, k, dd, x, z, f, n) in BUILDINGS]
# FIRST10 / ROUTE are written in FINAL coordinates since the 10/11 review (no grow)
FIXED_MOVE = [(w, now, (shrink(new[0], new[2])[0], new[1], shrink(new[0], new[2])[1]) if new else None, cfg) for (w, now, new, cfg) in FIXED_MOVE]
SCENES = [(n, shrink(*at), v) for (n, at, v) in SCENES]

# ---------------------------------------------------------------- ③ 3차 additions, in FINAL coordinates (not grown)
# 7 more homes where the story has people living (market hill, cliff homes, garden homes); the bigger town must not look
# empty (A23-76 dense edges): alleys, small yards and ponds per district come with them.
BUILDINGS += [
    ("House_Hill4", "HouseB", "market_hill", 234, -444, (214, -430), "언덕 동네 4: 언덕 마당을 봄"),
    ("House_Cliff6", "HouseA", "cliff_homes", 178, -656, (205, -644), "절벽 마을 위 단: 비탈길을 봄"),
    ("House_Cliff7", "HouseB", "cliff_homes", 140, -656, (160, -634), "절벽 마을 아래 단: 골목을 봄"),
    ("House_Cliff8", "HouseA", "cliff_homes", 256, -668, (236, -654), "바다 쪽 끝 집(W3 폭포 옆)"),
    ("House_Garden5", "HouseA", "garden_homes", -244, -690, (-214, -716), "정원 마을 서쪽 끝"),
    ("House_Garden6", "HouseB", "garden_homes", -110, -748, (-132, -742), "정원 마을 연못 집"),
    ("House_Garden7", "HouseA", "garden_homes", -192, -808, (-176, -782), "정원 마을 남쪽 바다 집"),
]
for _r in ROADS:
    if _r["id"] == "castle_wall":
        _r["pts"] = [(-212, -636), (-258, -606), (-272, -566)]  # round the 100 x 70 castle
SCENES = [(n, (-272, -566) if n == "성벽 전망" else at, v) for (n, at, v) in SCENES]
ROADS += [
    dict(id="market_lane", name="시장 뒷골목", w=6, grade=3, pts=[(62, -476), (92, -456), (118, -472), (124, -500), (96, -522)],
         note="빵집·주스 가게 앞을 도는 골목(큰 길에서 들어가 다시 큰 길로)"),
    dict(id="hill_alley", name="언덕 마당 골목", w=6, grade=3, pts=[(181, -420), (205, -430), (228, -432)], note="언덕 마당 → 언덕 집 2·3·4"),
    dict(id="cliff_lower", name="절벽 아래 골목", w=6, grade=3, pts=[(127, -602), (140, -628), (156, -636)], note="절벽 집 7, 쉼참"),
    dict(id="cliff_south", name="절벽 남쪽 골목", w=5, grade=3, pts=[(220, -692), (196, -698)], note="절벽 집 5"),
    dict(id="cliff_upper", name="절벽 위 골목", w=6, grade=3, pts=[(205, -644), (232, -642), (244, -656)], note="절벽 집 3·8, W3 웅덩이 옆"),
    dict(id="cliff_top", name="절벽 집 2 계단", w=5, grade=3, pts=[(166, -614), (184, -590), (198, -578)], note="절벽 집 2"),
    dict(id="garden_west", name="정원 서쪽 골목", w=6, grade=3, pts=[(-199, -755), (-210, -738), (-232, -708)], note="정원 집 2·5"),
    dict(id="garden_sea", name="정원 바다 골목", w=5, grade=3, pts=[(-199, -755), (-230, -756), (-250, -772), (-246, -784)], note="정원 집 3(바다를 봄)"),
    dict(id="garden_pond", name="연못 골목", w=6, grade=3, pts=[(-157, -728), (-138, -744), (-128, -750)], note="연못 집 6"),
    dict(id="garden_south", name="정원 남쪽 골목", w=5, grade=3, pts=[(-157, -728), (-165, -760), (-170, -790)], note="정원 집 4·7"),
    dict(id="lookout_end", name="전망 탑 앞", w=6, grade=3, pts=[(199, -788), (222, -772), (236, -766)], note="전망 탑 문"),
]
# small yards (cobble circles: x, z, r) so each district has a place to stand, and more water
YARDS = [
    dict(id="hill_yard", at=(208, -426), r=9, note="언덕 마당"),
    dict(id="castle_court", at=(-160, -522), r=14, note="성 앞 마당"),
    dict(id="cliff_yard", at=(226, -646), r=8, note="절벽 위 마당"),
    dict(id="cliff_landing", at=(152, -640), r=6, note="절벽 아래 쉼참"),
    dict(id="garden_yard", at=(-214, -742), r=9, note="정원 마을 마당"),
    dict(id="lookout_yard", at=(232, -770), r=8, note="전망 탑 앞 마당"),
    dict(id="market_corner", at=(112, -488), r=7, note="시장 뒷골목 모퉁이"),
    dict(id="cathedral_court", at=(85, -708), r=14, note="대성당 앞 마당(큰 계단 위)"),
]
WATER["pools"] += [
    dict(id="garden_pond", at=(-120, -775), r=6, y=13, note="정원 마을 연못"),
    dict(id="hill_spring", at=(198, -372), r=4, y=14, note="언덕 동네 작은 샘"),
    dict(id="cliff_pool", at=(262, -640), r=5, y=18, note="W3 폭포 위 웅덩이"),
]


# ---------------------------------------------------------------- 검수 plan v2 결과 (10/11 저녁, docs/review/halo_plan_v2_review_2026-10-11.md)
# FINAL coordinates. 결정 1 walking speed 20 (Config.Player.WalkSpeed) -> the cathedral climb becomes a switchback stair (the
# island does not grow); 2 the cathedral stands on the highest ground (lookout 34 -> 28); 3 the cliff village gets two real
# tiers 18 / 22; 4 the first 10 minutes = the real flow (spawn -> Hallie card -> gate -> Crossroads Forge -> meadow; shops and
# training yard on the M1_4 "Go to your town" return); 5 the two travel pads keep 12 x 12 + 2 clear; 6 B3 ends at the castle
# court, the garden road crosses on B4; 7 every footprint (+5 pad margin) sits inside its own district.
PADS = [("Pad_Halo_SlimeMeadow", (-24, -357)), ("Pad_Halo_GoblinWoods", (24, -357))]
PAD_KEEP = 8  # half side of the keep-clear square: the 10 x 10 pad -> 12 x 12 + 2 studs round it
PAD_MARGIN = 5  # 결정 7: the flattened pad round a footprint (halo_blockout flattens 5 from the walls)


def pad_box(c, grow=0.0):
    k = PAD_KEEP + grow
    return [(c[0] - k, c[1] - k), (c[0] + k, c[1] - k), (c[0] + k, c[1] + k), (c[0] - k, c[1] + k)]


def _road(rid):
    return next(r for r in ROADS if r["id"] == rid)


def _dist(did):
    return next(d for d in DISTRICTS if d["id"] == did)


def _bld(bid, x, z, faces):
    global BUILDINGS
    BUILDINGS = [(i, k, dd, x, z, faces, n) if i == bid else (i, k, dd, bx, bz, f, n) for (i, k, dd, bx, bz, f, n) in BUILDINGS]


# 결정 5: the loop road's east end runs 2+ studs south of the SlimeMeadow pad box (centre line z <= -373 for x -39..-9)
_road("loop")["pts"] = [(-4, -430), (-30, -436), (-52.0, -434), (-94.0, -440), (-130.0, -446.0), (-148.0, -424), (-124.0, -402),
                        (-85.0, -386), (-55.0, -377), (-26, -374), (-6, -374)]
# 결정 1: the main road stops at the plaza's south edge; a 12-wide switchback stair climbs the hill face in three legs
# (10 -> 30 over ~200 studs instead of 70) to the cathedral court, which moves south with the cathedral
ROADS.append(dict(id="cathedral_stairs", name="대성당 굽은 계단", w=12, grade=1,
                  pts=[(40, -647), (100, -660), (107, -668), (100, -676), (42, -682), (35, -690), (42, -698), (70, -704), (80, -714)],
                  rails=True, note="광장(10) → 대성당 앞 마당(30): 언덕 앞면을 세 번 꺾어 오름(결정 1), 꺾는 곳마다 쉼참, 양옆 난간"))
_st = _road("cathedral_stairs")
_cum = [0.0]
for _i in range(len(_st["pts"]) - 1):
    _cum.append(_cum[-1] + math.hypot(_st["pts"][_i + 1][0] - _st["pts"][_i][0], _st["pts"][_i + 1][1] - _st["pts"][_i][1]))
_st["ys"] = [round(10 + 20 * min(c / _cum[-2], 1.0), 2) for c in _cum]  # own height profile (halo_blockout uses it): even climb, flat into the court
# 결정 6: B3 / plaza_castle ends at the castle court (it never reached the castle's back)
_road("plaza_castle")["pts"] = [(-30, -575.0), (-64.0, -572.0), (-100.0, -560.0), (-124.0, -548.0), (-148, -530)]
_road("plaza_castle")["note"] = "광장 → 다리 B3 → 성 앞 마당(동쪽에서 들어감)"
# the garden road crosses the stream on B4 below the new garden pool (it ran over the W2 fall with no bridge)
_road("to_garden")["pts"] = [(-30, -629.0), (-58, -640), (-90, -656), (-104, -676), (-109.0, -704.0), (-157.0, -728.0), (-199.0, -755.0)]
_road("to_garden")["note"] = "광장 → 다리 B4 → 정원 쉼터 → 정원 마을"
# 결정 3: a stair lane from the upper cliff tier (22) up to the lookout (28)
ROADS.append(dict(id="cliff_lookout", name="절벽-전망대 계단", w=5, grade=3, pts=[(220, -692), (216, -724), (214, -752), (222, -772)],
                  note="절벽 위 단(22) → 전망대(28)"))

# the cathedral spring sits fully on the hill (it straddled the cliff), W2 falls over the hill edge into the new garden pool
WATER["stream"] = [(-14, -706), (-36, -700), (-56, -690), (-72, -662), (-79.0, -614.0), (-67.0, -572.0), (-55.0, -530.0), (-55.0, -485.0),
                   (-52.0, -440), (-55.0, -410), (-64.0, -382), (-79.0, -352), (-85.0, -336)]
WATER["stream_w"] = [4, 5, 6, 7, 8, 9, 9, 10, 10, 10, 11, 12, 13]
for _p in WATER["pools"]:
    if _p["id"] == "spring":
        _p.update(at=(-14, -706), r=6, note="대성당 샘(언덕 위)")
    elif _p["id"] == "garden_pool":
        _p.update(at=(-56, -690), r=8, note="정원 쉼터 웅덩이(W2 끝)")
    elif _p["id"] == "cliff_pool":
        _p.update(at=(270, -642), r=5, y=22, note="W3 폭포 위 웅덩이(절벽 위 단)")
for _f in WATER["falls"]:
    if _f["id"] == "W2":
        _f.update(at=(-38, -699), note="대성당 샘 → 언덕 끝 → 정원 쉼터 웅덩이, 계단 폭포 3단")
    elif _f["id"] == "W3":
        _f.update(at=(288, -641), drop="22 → 바다", note="절벽 위 단 웅덩이 → 동쪽 바다, 2단")
# bridges: B1-B3 keep their roads, B4 is new; every bridge's spot is the road / stream crossing (fix_bridges, B2 was 2.75 off)
BRIDGES.append(dict(id="B4", at=(-72, -650), len=14, kind="낮은 돌다리", note="광장 → 정원 쉼터 (정원 길)"))
BRIDGE_ROAD = {"B1": "loop", "B2": "loop", "B3": "plaza_castle", "B4": "to_garden"}

# 결정 2: the lookout drops to 28 (tower top 78 < the cathedral's 84), the cathedral moves south for the stair court
_dist("lookout")["y"] = 28
_dist("lookout")["why"] = "마을과 바다가 가장 넓게 보이는 곳(대성당보다는 낮음). 전망 탑 하나, 섬 가장자리 8 안에는 낮은 것만."
_dist("cathedral")["poly"] = [(-24, -680.0), (24, -686), (30, -710), (72, -710), (96, -692), (118, -684), (138, -686), (148.0, -758.0),
                              (124.0, -821.0), (0, -827.0), (-61.0, -815.0), (-67.0, -740.0)]
# the hill face between the plaza and the cathedral: terraces stepped by the stair legs (halo_blockout: each cell takes the
# height of the nearest point of the stair, so a leg can not be cut by walking up the grass)
DISTRICTS.insert(DISTRICTS.index(_dist("cathedral")), dict(
    id="cathedral_steps", name="대성당 계단 언덕", y=10, y_to=30, terrace="cathedral_stairs", color=(238, 226, 236),
    poly=[(26, -658), (55.0, -651.5), (82, -622), (100, -626), (118, -650), (118, -684), (96, -692), (72, -710), (30, -710)],
    why="광장에서 대성당까지 언덕 앞면. 굽은 계단이 세 번 꺾어 오르고, 계단 사이는 꽃 단. 오르는 동안 광장·바다가 점점 넓게 보인다.",
    flowers=["흰", "연보라", "금"], edge="계단 사이 꽃 단(턱 = 계단 높이)"))
YARDS = [dict(y, at=(82, -718)) if y["id"] == "cathedral_court" else y for y in YARDS]
YARDS = [dict(y, at=(118, -472)) if y["id"] == "market_corner" else y for y in YARDS]
# 결정 3: the cliff village = a lower tier 18 (north-west: houses 1, 2, 7) and an upper tier 22 (east and south: 3, 4, 5, 6, 8),
# joined by to_cliff; the cathedral / cliff polygons no longer overlap at x 126-143
_c = _dist("cliff_homes")
_c.pop("y_to", None)
_c["poly"] = [(106.0, -554.0), (169.0, -539.0), (235.0, -503.0), (268.0, -560.0), (272.5, -665.0), (256.0, -740.0), (190.0, -755.0),
              (150, -735), (138, -676), (100.0, -620.0)]
_c["tiers"] = [dict(id="upper", name="위 단", y=22,
                    poly=[(186, -590), (270, -584), (272.5, -665), (256, -740), (190, -755), (150, -735), (158, -690), (159, -640), (175, -622)])]
_c["edge"] = "절벽 + 두 단 사이 턱 4(비탈길 to_cliff로 오름)"
# slope lines of the y -> y_to districts (were halo_blockout SLOPES in stage-1 coordinates; the plan owns them now)
_dist("market")["slope"] = [(12, -455), (148, -485)]
_dist("garden_homes")["slope"] = [(-124, -698), (-235, -788)]
# 결정 7: two districts widen to the coast where their edge house had no room inward (House_Hill4, House_Garden7)
_dist("market_hill")["poly"] = [(142.0, -362), (244.0, -376), (262, -418), (238, -480), (172.0, -485.0), (148.0, -430)]
_dist("garden_homes")["poly"] = [(-130.0, -647.0), (-208.0, -644.0), (-266.5, -683.0), (-257.5, -782.0), (-215, -818), (-178, -828),
                                 (-94.0, -812.0), (-79.0, -743.0), (-124.0, -704.0)]
# 결정 7 + review: buildings that stuck out of their district / faced the wrong way (positions found by tools/_halo_fit.py)
_bld("Cathedral", 84, -772, (84, -700))
_bld("House_Cliff3", 244, -614, (226, -646))  # door to the cliff yard (it faced the sea with the path behind the house)
for _id, _x, _z in (("Tower_GateEast", 39, -346), ("Shop_Potion", 40, -490), ("Shop_Flower", 58, -519), ("House_Hill1", 170, -389),
                    ("Armory", -175, -417), ("Castle", -176, -574), ("House_Hill4", 231, -448), ("House_Cliff6", 180, -655), ("House_Cliff7", 142, -656),
                    ("House_Cliff8", 248, -674), ("House_Garden5", -242, -691), ("House_Garden7", -190, -804), ("Tower_Lookout", 233, -777)):
    _b = next(t for t in BUILDINGS if t[0] == _id)
    _yaw = math.atan2(_b[5][0] - _b[3], _b[5][1] - _b[4])  # same door direction after the move
    _bld(_id, _x, _z, (_x + math.sin(_yaw) * 30, _z + math.cos(_yaw) * 30))
_bld("Tower_GateEast", 39, -346, (39, -400))  # 결정 5: door to the south so its path goes round the GoblinWoods pad (it faced into it)
_bld("House_Cliff7", 142, -656, (142 + math.sin(math.radians(60)) * 30, -656 + math.cos(math.radians(60)) * 30))  # yaw 40 -> 60: room for the tier step to Cliff6
# the main road crossed the fountain basin (centre line 9 from it, half width 10): it now passes east of the fountain
_road("main")["pts"] = [(0, -336), (0, -362), (2, -400), (6, -426), (34, -452.0), (70.0, -485.0), (88.0, -524.0), (60, -562), (54, -604), (40, -647.0)]
_road("main")["note"] = "성문 → 스폰(통로는 곧게) → 시장 골목 → 분수 광장(분수 동쪽으로) → 광장 남쪽 끝에서 대성당 굽은 계단"
for _f in WATER["falls"]:
    _f["y"] = {"W1": 1, "W2": 21, "W3": 12}[_f["id"]]  # sound / FX height (halfway down each fall)
_road("cliff_lookout")["pts"] = [(220, -692), (206, -712), (208, -748), (222, -772)]
_road("lookout_end")["pts"] = [(199, -788), (210, -785), (220, -782)]
_road("lookout_end")["note"] = "전망 탑 문 앞 마당"
YARDS = [dict(y, at=(214, -786)) if y["id"] == "lookout_yard" else y for y in YARDS]
SCENES = [(n, (233, -777) if n == "전망 탑 꼭대기" else at, v) for (n, at, v) in SCENES]
SCENES = [(n, (266, -604) if n == "절벽 마을 발코니" else (146, -524) if n == "시장 끝 꽃 화분 탁자" else
           (-80, -676) if n == "폭포 웅덩이 벤치" else at, v) for (n, at, v) in SCENES]


# ---------------------------------------------------------------- A23-117 '이유' 칸 (검수 10/11 17:30): every district says what it does,
# every building / yard / bridge / photo scene says who uses it and why it stands there. A missing why is a check issue.
DIST_JOB = {
    "arrival": "들어오고 나가는 곳 — 문지기·길잡이·이동 발판",
    "market": "사고파는 곳 — 가게 4채 한 골목",
    "market_hill": "가게 주인들이 사는 곳",
    "training": "기술 연습 — 첫 기술 시험",
    "castle": "기사단 본부 — 훈련장과 서쪽 바다를 지킴",
    "plaza": "모이는 곳 — 모든 길이 만남",
    "garden": "쉬어 가는 곳 — 폭포 웅덩이 벤치",
    "garden_homes": "꽃 키우는 사람들이 사는 곳",
    "cathedral": "기도하는 곳 — 왕관 조각을 지킴",
    "cliff_homes": "대성당 일꾼과 바다를 보는 사람들이 사는 곳",
    "cathedral_steps": "대성당으로 오르는 길 — 굽은 계단과 꽃 단",
    "lookout": "내려다보는 곳 — 마을·바다 사진 자리",
}
WHY_B = {
    "Gate": "교차로 다리에서 마을로 들어오는 하나뿐인 문. 문지기가 지킨다",
    "Tower_GateEast": "문지기 망루: 다리로 오는 사람을 높이서 본다(동쪽에만, 비대칭)",
    "Shop_Potion": "물약 상인 가게: 첫 장 뒤 돌아와(M1_4) 처음 들르는 가게. 스폰에서 동쪽(시장 쪽)으로 돌면 보인다",
    "Shop_Bakery": "빵집 할머니(Folk3) 가게. 언덕 동네 계단 아래 뒷골목 입구",
    "Shop_Juice": "주스 아저씨(Folk1) 가게. 골목 끝, 구경하고 쉬어 가는 자리",
    "Shop_Flower": "꽃 가게(Folk2). 시장 골목에서 광장으로 올라가는 모퉁이, 정원 마을 꽃을 받아 판다",
    "House_Hill1": "빵집 할머니 집: 가게로 내려가는 계단이 가장 가깝다",
    "House_Hill2": "주스 아저씨 집: 언덕 마당 옆",
    "House_Hill3": "물약 상인 집: 문은 언덕 마당 쪽, 뒤창이 시장을 내려다본다",
    "House_Hill4": "약초꾼 부부 집: 시장 물약 가게에 약초를 대 준다 (A23-124 새 집, 2D 그대로)",
    "Armory": "기사단 무기고: 훈련장 바로 옆이라 무기를 꺼내 바로 연습한다",
    "Castle": "기사단 성: 훈련장을 내려다보고 서쪽 바다를 지킨다. 문은 훈련장 쪽",
    "Cathedral": "왕관 조각을 지키는 대성당: 마을에서 가장 높은 언덕(Y30, 꼭대기 84 = 마을에서 가장 높음), 굽은 계단 위",
    "House_Cliff1": "성가대 아이들 집: 아래 단, 대성당 가는 비탈 아래",
    "House_Cliff2": "성가대 선생님 집: 아래 단",
    "House_Cliff3": "바다를 그리는 화가 집: 위 단, 문은 절벽 위 마당 쪽, 창이 바다 쪽",
    "House_Cliff4": "대성당 정원사 집: 위 단 남쪽, 전망대 계단 옆",
    "House_Cliff5": "촛불 만드는 사람 집: 위 단 서쪽, 대성당 언덕이 가장 가깝다(초를 댐)",
    "House_Cliff6": "비탈길 우편배달 소년 집: 위 단, 비탈길 to_cliff 바로 옆(매일 마을을 한 바퀴) (A23-124 새 집, 2D 그대로)",
    "House_Cliff7": "골목 종지기 할아버지 집: 아래 골목, 해 질 녘 종을 친다 (A23-124 새 집, 2D 그대로)",
    "House_Cliff8": "늙은 뱃사공 집: 위 단 바다 쪽 끝, 테라스 망원경으로 하늘 바다의 배를 센다 (A23-124 새 집, 2D 그대로)",
    "House_Garden1": "정원사 집: 꽃 가게에 꽃을 댄다, 광장에서 가장 가깝다",
    "House_Garden2": "씨앗 모으는 사람 집",
    "House_Garden3": "물러난 늙은 기사 집: 서쪽 바닷가, 문이 바다 쪽",
    "House_Garden4": "벌 치는 사람 집: 꽃밭 가운데",
    "House_Garden5": "꽃 농부 집: 서쪽 끝, 정원 마을 꽃 화분을 키운다 (A23-124 새 집, 2D 그대로)",
    "House_Garden6": "연못 낚시꾼 집: 연못 물고기·개구리 이야기를 좋아한다 (A23-124 새 집, 2D 그대로)",
    "House_Garden7": "별 보는 학자 집: 남쪽 바닷가 끝, 밤마다 왕관 조각 별을 기록한다 (A23-124 새 집, 2D 그대로)",
    "Tower_Lookout": "전망 탑: 마을·바다를 가장 넓게 내려다보는 사진 자리(대성당보다 낮음, 전망대 안쪽)",
}
WHY_YARD = {
    "hill_yard": "언덕 집 2·3·4가 같이 쓰는 마당(빨랫줄·화분)",
    "castle_court": "기사들이 모이는 성 문 앞 마당",
    "cliff_yard": "절벽 위 단 마당: 화가 집(3) 문 앞, 뱃사공 집(8)과 같이 씀",
    "cliff_landing": "절벽 비탈 오르다 쉬는 쉼참",
    "garden_yard": "정원 서쪽 골목 옆 공동 꽃밭 마당(집 2·3·5가 같이 씀)",
    "lookout_yard": "전망 탑에 오르기 전 모이는 곳",
    "market_corner": "뒷골목이 꺾이는 모퉁이(빵집·주스 가게 사이) 노점·수레 자리",
    "cathedral_court": "굽은 계단 위, 기도하러 온 사람들이 모이는 대성당 앞",
}
WHY_BRIDGE = {
    "B1": "첫 10분: 스폰에서 훈련장으로 시냇물을 건너는 곳",
    "B2": "훈련 뒤 성문으로 돌아가는 고리길이 시냇물을 건너는 곳",
    "B3": "광장에서 성 앞 마당으로 동쪽에서 들어가는 곁길",
    "B4": "광장에서 정원 쉼터·정원 마을로 가는 길이 시냇물을 건너는 곳(W2 폭포 아래)",
}
WHY_SCENE = {
    "폭포 웅덩이 벤치": "정원 쉼터에서 쉬는 사람 자리",
    "성벽 전망": "성벽 곁길 막다른 끝의 보상(서쪽 바다)",
    "북동 곶 벤치": "언덕 동네 사람이 교차로 다리를 보는 자리",
    "시장 끝 꽃 화분 탁자": "장 본 사람이 골목을 내려다보며 쉬는 자리",
    "절벽 마을 발코니": "절벽 위 단 사람이 동쪽 바다와 남쪽 W3 폭포를 보는 자리",
    "대성당 뒤 바다 전망": "기도 뒤 조용히 바다를 보는 자리",
    "전망 탑 꼭대기": "마을 전체 사진 자리",
    "훈련장 관람 계단": "훈련을 구경하는 자리",
}
for _d in DISTRICTS:
    _d["job"] = DIST_JOB.get(_d["id"], "")
    if _d["id"] == "training":
        _d["why"] = _d["why"].replace("흙 마당", "모래 마당")  # 10/11 2차: the yard terrain is Sand (GE_Ground read near black)
    if _d["id"] == "cliff_homes":
        _d["why"] = ("대성당 일꾼(성가대·정원사·초 만드는 사람·종지기)과 바다를 보는 사람(화가·뱃사공)이 산다. 집 8채가 진짜 두 단: "
                     "아래 단 18(집 1·2·7) · 위 단 22(집 3·4·5·6·8), 비탈길 to_cliff로 오른다. 위 단 끝 W3 폭포가 바다로 떨어진다.")
    if _d["id"] == "garden_homes":
        _d["why"] = "꽃 키우는 사람들이 사는 남서쪽 조용한 동네. 집 7채가 마당·꽃밭·연못과 함께, 2채(집 3·7)는 바닷가에 선다."
for _y in YARDS:
    _y["why"] = WHY_YARD.get(_y["id"], "")
for _b in BRIDGES:
    _b["why"] = WHY_BRIDGE.get(_b["id"], "")


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


def footprint(b, grow=0.0):
    w, d = b["w"] + 2 * grow, b["d"] + 2 * grow
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


def road_profile_at(r, p):
    """height on road r's centre line nearest to p (roads with their own 'ys' only)"""
    best = None
    for i in range(len(r["pts"]) - 1):
        (ax, az), (bx, bz) = r["pts"][i], r["pts"][i + 1]
        dx, dz = bx - ax, bz - az
        t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - az) * dz) / max(dx * dx + dz * dz, 1e-9)))
        dd = math.hypot(p[0] - ax - t * dx, p[1] - az - t * dz)
        if best is None or dd < best[0]:
            best = (dd, r["ys"][i] + (r["ys"][i + 1] - r["ys"][i]) * t)
    return best[1]


def dist_height(dd, p):
    """ground height of district dd at p: tiers, terrace (nearest stair point), slope line, else its y"""
    for t in dd.get("tiers", []):
        if inside(p, t["poly"]):
            return t["y"]
    if dd.get("terrace"):
        return road_profile_at(next(r for r in ROADS if r["id"] == dd["terrace"]), p)
    if dd.get("y_to") is not None and dd.get("slope"):
        (ax, az), (bx, bz) = dd["slope"]
        dx, dz = bx - ax, bz - az
        t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - az) * dz) / max(dx * dx + dz * dz, 1e-9)))
        return dd["y"] + (dd["y_to"] - dd["y"]) * t
    return dd["y"]


def build_list():
    out = []
    for bid, kind, dist, x, z, faces, note in BUILDINGS:
        w, d, h, floors, fh, door = KINDS[kind]
        dx, dz = faces[0] - x, faces[1] - z
        yaw = round(math.degrees(math.atan2(dx, dz)) / 5) * 5
        dd = DIST[dist]
        gy = dd["y"]
        if dd.get("tiers") or dd.get("y_to") is not None:
            # review: on sloped / tiered districts the pad takes the ground height at the door (was the district's low y, up to
            # 3.9 below the ground round it) -> the pad cut and the doorstep apron shrink to under 1 stud
            gy = round(dist_height(dd, (x + math.sin(math.radians(yaw)) * d / 2, z + math.cos(math.radians(yaw)) * d / 2)))
        h = {"Tower_Lookout": 50}.get(bid, h)  # ④: the open belvedere + dome + finial
        out.append(dict(id=bid, kind=kind, district=dist, x=x, z=z, ground_y=gy, yaw=yaw,
                        door_dir=[round(math.sin(math.radians(yaw)), 3), round(math.cos(math.radians(yaw)), 3)],
                        door_compass=compass(math.sin(math.radians(yaw)), math.cos(math.radians(yaw))),
                        w=w, d=d, h=h, floors=floors, floor_h=fh, door_size=list(door), note=note, why=WHY_B.get(bid, "")))
    for b in out:
        yaw = math.radians(b["yaw"])
        b["door_at"] = [round(b["x"] + math.sin(yaw) * b["d"] / 2, 1), round(b["z"] + math.cos(yaw) * b["d"] / 2, 1)]
        b["footprint"] = [[round(p[0], 1), round(p[1], 1)] for p in footprint(b)]
    return out


def nearest_on(r, p):
    best = None
    for i in range(len(r["pts"]) - 1):
        (ax, az), (bx, bz) = r["pts"][i], r["pts"][i + 1]
        dx, dz = bx - ax, bz - az
        t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - az) * dz) / max(dx * dx + dz * dz, 1e-9)))
        q = (ax + t * dx, az + t * dz)
        dd = math.hypot(q[0] - p[0], q[1] - p[1]) - r["w"] / 2
        if best is None or dd < best[0]:
            best = (dd, q)
    return best


def seg_clear(a, b, polys, step=1.0):
    n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / step))
    for k in range(n + 1):
        p = (a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n)
        if any(inside(p, q) for q in polys):
            return False
    return True


def door_spurs(blds):
    """a garden path (grade 3, 4 wide) from every door to a road. Review 10/11: the target is the road point nearest to the
    step 5 out of the door (not to the door), and the path goes round its own house, the other houses and the two pad boxes
    with one corner waypoint when the straight line would cut through them"""
    spurs = []
    W = 4
    for b in blds:
        door = b["door_at"]
        near = sorted(((*nearest_on(r, door), r["id"]) for r in ROADS), key=lambda t: t[0])
        b["door_to_path"] = round(max(near[0][0], 0), 1)
        b["path_from"] = near[0][2]
        if near[0][0] <= 3:
            continue
        yaw = math.radians(b["yaw"])
        step = (door[0] + math.sin(yaw) * 5, door[1] + math.cos(yaw) * 5)
        obst = [footprint(o, W / 2 + 0.5) for o in blds] + [pad_box(c, W / 2 + 0.5) for _, c in PADS]
        wide = [footprint(o, W / 2 + 2.5) for o in blds] + [pad_box(c, W / 2 + 2.5) for _, c in PADS]
        cands = sorted(((*nearest_on(r, step), r["id"]) for r in ROADS), key=lambda t: t[0])[:5]
        best = None
        for dd, q, rid in cands:
            if seg_clear(step, q, obst):
                pths = [[step, q]]
            else:  # one corner waypoint round whatever the straight line hits
                hit = [k for k, o in enumerate(obst) if not seg_clear(step, q, [o])]
                pths = [[step, c, q] for k in hit for c in wide[k]
                        if inside(c, LAND) and not any(inside(c, o) for o in obst) and seg_clear(step, c, obst) and seg_clear(c, q, obst)]
            for pts in pths:
                ln = sum(math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]) for i in range(len(pts) - 1))
                if best is None or ln < best[0]:
                    best = (ln, pts, rid)
        if best is None:  # nothing clear: straight (the checks flag it)
            best = (0, [step, cands[0][1]], cands[0][2])
        spurs.append(dict(id="door_" + b["id"], name="문 앞 길", w=W, grade=3,
                          pts=[(door[0], door[1])] + [(round(p[0], 1), round(p[1], 1)) for p in best[1]],
                          note=f"{b['id']} 문 → {best[2]} ({best[0]:.0f})"))
    return spurs


def seg_cross(a, b, c, d):
    """intersection point of segments ab and cd, or None"""
    r = (b[0] - a[0], b[1] - a[1])
    s = (d[0] - c[0], d[1] - c[1])
    den = r[0] * s[1] - r[1] * s[0]
    if abs(den) < 1e-9:
        return None
    t = ((c[0] - a[0]) * s[1] - (c[1] - a[1]) * s[0]) / den
    u = ((c[0] - a[0]) * r[1] - (c[1] - a[1]) * r[0]) / den
    if 0 <= t <= 1 and 0 <= u <= 1:
        return (a[0] + t * r[0], a[1] + t * r[1])
    return None


def stream_crossings(r):
    st = WATER["stream"]
    out = []
    for i in range(len(r["pts"]) - 1):
        for j in range(len(st) - 1):
            p = seg_cross(r["pts"][i], r["pts"][i + 1], st[j], st[j + 1])
            if p:
                out.append((p, j))
    return out


def fix_bridges():
    """every bridge sits on its road's stream crossing (B2 was 2.75 off, its west end over water)"""
    for br in BRIDGES:
        rd = next(r for r in ROADS if r["id"] == BRIDGE_ROAD[br["id"]])
        xs = stream_crossings(rd)
        if xs:
            p, j = min(xs, key=lambda t: math.hypot(t[0][0] - br["at"][0], t[0][1] - br["at"][1]))
            br["at"] = (round(p[0], 1), round(p[1], 1))
            br["road"] = rd["id"]
            br["stream_w"] = WATER["stream_w"][j]


def road_samples(r, step=1.0):
    for i in range(len(r["pts"]) - 1):
        (ax, az), (bx, bz) = r["pts"][i], r["pts"][i + 1]
        n = max(1, int(math.hypot(bx - ax, bz - az) / step))
        for k in range(n + 1):
            yield i, (ax + (bx - ax) * k / n, az + (bz - az) * k / n)


def review_checks(blds, fp_dist):
    """검수 plan v2 결과 (10/11): pads, bridges, roads on water, stream through houses, the cathedral highest, pads of
    different heights touching"""
    msgs = []
    for name, c in PADS:
        box = pad_box(c)
        for r in ROADS:
            if any(fp_dist(p, box) < r["w"] / 2 for _, p in road_samples(r)):
                msgs.append(f"길이 이동 발판 둘레에: {r['id']} - {name}")
        for b in blds:
            if poly_overlap(footprint(b), box):
                msgs.append(f"건물이 이동 발판 둘레에: {b['id']} - {name}")
        for f in FILL_LIGHTS:
            if fp_dist(f["at"], box) < 1:
                msgs.append(f"채움 빛이 이동 발판 둘레에: {f['note']} - {name}")
        for n2, _now, new, _c in FIXED_MOVE:
            if new and fp_dist((new[0], new[2]), box) < 2.5:
                msgs.append(f"고정점이 이동 발판 둘레에: {n2} - {name}")
    # fixed NPCs / statue off every road band (Sir Gleam stood in the loop road)
    for n2, _now, new, _c in FIXED_MOVE:
        if not new or n2.startswith("훈련장"):  # the training mark is a yard spot, not a body
            continue
        for r in ROADS:
            dd = min(seg_dist((new[0], new[2]), r["pts"][i], r["pts"][i + 1]) for i in range(len(r["pts"]) - 1)) - r["w"] / 2
            if dd < 1.5:
                msgs.append(f"고정점이 길 위: {n2} - {r['id']} ({dd:.1f})")
    # every road / stream crossing has a bridge within len / 2 (the garden road ran over W2 with none)
    for r in ROADS:
        for p, _j in stream_crossings(r):
            if not any(math.hypot(p[0] - br["at"][0], p[1] - br["at"][1]) <= br["len"] / 2 for br in BRIDGES):
                msgs.append(f"다리 없이 물 건넘: {r['id']} ({p[0]:.0f},{p[1]:.0f})")
    for br in BRIDGES:
        if br.get("stream_w") and br["len"] < br["stream_w"] + 3:
            msgs.append(f"다리가 짧음: {br['id']} {br['len']} < 물 폭 {br['stream_w']} + 3")
    for w in WATER["pools"]:
        if w["id"] == "fountain":
            continue
        for r in ROADS:
            if any(math.hypot(p[0] - w["at"][0], p[1] - w["at"][1]) < w["r"] + r["w"] / 2 for _, p in road_samples(r)):
                msgs.append(f"길이 물에 걸림: {r['id']} - {w['id']}")
    st = WATER["stream"]
    for b in blds:
        fp = footprint(b)
        for i in range(len(st) - 1):
            if any(fp_dist(p, fp) < WATER["stream_w"][i] / 2 for _, p in road_samples(dict(pts=[st[i], st[i + 1]]))):
                msgs.append(f"시냇물이 건물에 걸림: {b['id']}")
                break
    for y in YARDS:
        for b in blds:
            if fp_dist(tuple(y["at"]), footprint(b)) < y["r"]:
                msgs.append(f"마당이 건물에 걸림: {y['id']} - {b['id']}")
    # 결정 2: the cathedral's ground is the highest ground and its top the highest top
    cat = next(b for b in blds if b["kind"] == "Cathedral")
    for dd in DISTRICTS:
        if dd["id"] in (cat["district"], "cathedral_steps"):
            continue
        top = max([dd["y"], dd.get("y_to") or dd["y"]] + [t["y"] for t in dd.get("tiers", [])])
        if top >= cat["ground_y"]:
            msgs.append(f"대성당보다 높은 땅: {dd['id']} {top}")
    for b in blds:
        if b is not cat and b["ground_y"] + b["h"] >= cat["ground_y"] + cat["h"]:
            msgs.append(f"대성당보다 높은 건물: {b['id']} {b['ground_y'] + b['h']}")
    # pads of different heights must not touch (both are flattened PAD_MARGIN round the walls)
    for i in range(len(blds)):
        for j in range(i + 1, len(blds)):
            a, b = blds[i], blds[j]
            if a["ground_y"] != b["ground_y"] and poly_overlap(footprint(a, PAD_MARGIN), footprint(b, PAD_MARGIN)):
                msgs.append(f"받침 높이 다른데 맞닿음: {a['id']} {a['ground_y']} - {b['id']} {b['ground_y']}")
    return msgs


def checks(blds):
    msgs = []
    for b in blds:
        if not b.get("why"):
            msgs.append(f"이유 없음: {b['id']}")
    for kind, items, key in (("마당", YARDS, "id"), ("다리", BRIDGES, "id")):
        for it in items:
            if not it.get("why"):
                msgs.append(f"이유 없음: {kind} {it[key]}")
    for n, _a, _v in SCENES:
        if n not in WHY_SCENE:
            msgs.append(f"이유 없음: 장면 {n}")
    for dd in DISTRICTS:
        if not dd.get("job"):
            msgs.append(f"하는 일 없음: 구역 {dd['id']}")
    for b in blds:
        fp = footprint(b)
        if b["kind"] != "Gate" and not all(inside(p, LAND) for p in fp):  # the gate stands on the bridge end
            msgs.append(f"땅 밖: {b['id']}")
        # 결정 7: all four corners of the footprint + its 5-stud pad inside the own district (the centre alone let 4 stick out)
        if b["kind"] != "Gate" and not all(inside(p, DIST[b["district"]]["poly"]) for p in footprint(b, PAD_MARGIN)):
            msgs.append(f"구역 밖: {b['id']} ({b['district']})")
        if b["door_to_path"] > 40:
            msgs.append(f"문 앞 길 멀다: {b['id']} {b['door_to_path']:.0f}")
    for i in range(len(blds)):
        for j in range(i + 1, len(blds)):
            if poly_overlap(footprint(blds[i]), footprint(blds[j]), gap=4):
                msgs.append(f"겹침(4 띄움): {blds[i]['id']} - {blds[j]['id']}")
    # ③ 3차: roads / alleys / pools must not run through a building (door spurs of that building and the gate passage excepted)
    def fp_dist(pt, fp):
        if inside(pt, fp):
            return -1.0
        return min(seg_dist(pt, fp[i], fp[(i + 1) % 4]) for i in range(4))
    for r in ROADS:
        for b in blds:
            if b["kind"] == "Gate":
                continue
            own = r["id"] == "door_" + b["id"]
            fp = footprint(b)
            hit = False
            for i in range(len(r["pts"]) - 1):
                (ax, az), (bx, bz) = r["pts"][i], r["pts"][i + 1]
                n = max(1, int(math.hypot(bx - ax, bz - az) // 2))
                for k in range(n + 1):
                    if (own and i == 0) or (i == 0 and k == 0 and r["id"].startswith("door_")):
                        continue  # review: only the own door step (segment 0) may touch its house, not the whole spur
                    t = k / n
                    if fp_dist((ax + (bx - ax) * t, az + (bz - az) * t), fp) < r["w"] / 2 - 0.5:
                        hit = True
                        break
                if hit:
                    break
            if hit:
                msgs.append(f"길이 건물을 지남: {r['id']} - {b['id']}")
    for w in WATER["pools"]:
        for b in blds:
            if fp_dist(tuple(w["at"]), footprint(b)) < w["r"]:
                msgs.append(f"물이 건물에 걸림: {w['id']} - {b['id']}")
    msgs += review_checks(blds, fp_dist)
    # the spawn-gate corridor (|x|<=12, z -330..-432) and the spawn circle stay clear (the gate itself is the passage)
    for b in blds:
        if b["kind"] == "Gate":
            continue
        fp = footprint(b)
        cor = [(-12, -330), (12, -330), (12, -432), (-12, -432)]
        if poly_overlap(fp, cor) or any(math.hypot(px, pz + 420) < 12 for px, pz in fp):
            msgs.append(f"스폰-문 통로 막음: {b['id']}")
    for name, now, new, _ in FIXED_MOVE:
        if new and abs(new[0]) <= 12 and -432 <= new[2] <= -330:
            msgs.append(f"통로 안 고정점: {name}")
    # what the gate shows: from the eye inside the gate (0, 6, -345) how much of each tall building rises above
    # everything in front of it (ground heights from the districts, building tops = ground + h)
    eye = (0.0, 6.0, -345.0)
    sight = {}
    for tgt in blds:
        if tgt["kind"] not in ("Cathedral", "Castle", "Tower"):
            continue
        dist = math.hypot(tgt["x"] - eye[0], tgt["z"] - eye[2])
        top_ang = (tgt["ground_y"] + tgt["h"] - eye[1]) / dist
        base_ang = (tgt["ground_y"] - eye[1]) / dist
        block = base_ang
        by = None
        for o in blds:
            if o is tgt or o["kind"] == "Gate":
                continue
            od = math.hypot(o["x"] - eye[0], o["z"] - eye[2])
            if od >= dist:
                continue
            # does the line eye -> target pass this footprint? sample along it
            hit = False
            for k in range(1, 60):
                t = k / 60 * (od + 15) / dist
                px, pz = eye[0] + (tgt["x"] - eye[0]) * t, eye[2] + (tgt["z"] - eye[2]) * t
                if inside((px, pz), footprint(o)):
                    hit = True
                    break
            if hit:
                a = (o["ground_y"] + o["h"] - eye[1]) / od
                if a > block:
                    block, by = a, o["id"]
        seen = max(0.0, min(1.0, (top_ang - block) / max(top_ang - base_ang, 1e-6)))
        sight[tgt["id"]] = dict(angle_from_axis=round(math.degrees(math.atan2(tgt["x"], -(tgt["z"] - eye[2]))), 1),
                                visible_share=round(seen, 2), hidden_by=by)
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
    squares += sum(math.pi * y["r"] ** 2 for y in YARDS)
    pave = (road + squares) / land
    return msgs, pairs, land, pave, sight


# ---------------------------------------------------------------- stage 5 dressing list (검수 10/11: 재료 목록 미리)
# What each district gets in stage 5 (입히기). Kit names = tools/halo_props_list.txt (Tripo, 이미지 생성 3) + the building
# parts in WorldKit ServerStorage.ImportHold; acnh rules (docs/design/acnh_halo_layout_rules_2026-10-10.md) by number.
# Paths everywhere: grade 1 = white marble + gold line (Concrete -> 이미지 개발 MaterialVariant), grade 2 / yards =
# cobble (another stone), grade 3 = stepping stones in grass; steep cells = stairs (HaloStairs_1-5 on the big ones).
# Lamps: auto spots below (Lantern A-E mixed, >= 2 kinds per district, +-15 deg, x0.87-1.15, warm, on at Dusk/Night).
KIT = dict(
    lamps=["HaloVar4_Lantern_A", "HaloVar4_Lantern_B", "HaloVar4_Lantern_C", "HaloVar4_Lantern_D", "HaloVar3_Lantern_E"],
    rails=["HaloVar4_Balustrade_A", "HaloVar4_Balustrade_B", "HaloVar4_Balustrade_C", "HaloVar4_Balustrade_D", "HaloVar3_Balustrade_E",
           "HaloVar3_Balustrade_F"],
    planters=["HaloVar4_Planter_A", "HaloVar4_Planter_D", "HaloVar3_Planter_E"],
    pots=["HaloVar4_PotFlowers_A", "HaloVar4_PotFlowers_C", "HaloVar4_PotFlowers_D", "HaloVar3_PotFlowers_E", "HaloVar3_PotFlowers_F",
          "HaloFlowerPotHQ_Daisy", "HaloFlowerPotHQ_Lavender", "HaloFlowerPotHQ_Rose", "HaloFlowerPotHQ_Sunflower", "HaloFlowerPotHQ_Tulip"],
    trees=["HaloVar3_RoundTree_E", "HaloVar3_RoundTree_F", "HaloVar3_RoundTree_G"],
    topiary=["HaloVar3_Topiary_C", "HaloVar3_Topiary_D", "HaloVar3_Topiary_E"],
    benches=["HaloReasonHQ_BenchA", "HaloReasonHQ_BenchB", "HaloReasonHQ_BenchC"],
    flags=["HaloFlagpole_1", "HaloFlagpole_2", "HaloFlagpole_3"],
    new_needed=["꽃 덤불·생울타리 (이미지 생성 3, 2D -> 3D 진행 중; 구름 덤불은 사용자 \"뭉탱이\"로 뺌)", "흰 바위 2~3종 (절벽 발치·물가)",
                "성문 받침 위 등 4 + 작은 받침 기둥 4 + 낮은 난간 (성문 2D 앞면 양쪽, 4면 2D 큐 · ④ 골격에는 안 넣음)",
                "무기고: 통·상자·무기 걸이(RackShieldSword), 문 옆 벽등 2 (골격에는 단순 틀만)",
                "디딤돌 (정원 길)", "작은 다리·징검다리 (연못·샘)", "떠 있는 섬 아랫면 뾰족 바위 (검수 ③ 2차)"],
)
DRESSING = {
    "arrival": dict(paths="큰 길 흰 대리석+금 테 (통로 |x|<=12는 곧게, 소품 없음), 북쪽은 모래 해변",
                    plants="W1 폭포 옆(서) 나무 무리 3 + 흰 바위, 영웅상 둘레 꽃 고리, 해변 쪽은 낮은 풀",
                    props="GuardPost (성문 안쪽 서쪽: 문지기 — 동쪽은 탑이라 비대칭, 동쪽 발판·채움 빛 피함), Flagpole_1 (탑 옆, 짝 없음), 영웅상 꽃 고리",
                    water="W1 1단 폭포 -> 바다 (halo_waterfx), 시냇물 하구",
                    edge="동쪽 큰 탑+등불 1 / 서쪽 W1 폭포+나무 무리+등불 2 (규칙 7)",
                    light="성문 안쪽 채움 빛 (FILL_LIGHTS, 앞면 햇빛 0%)", empty="스폰 원 둘레 잔디 (통로 밖)"),
    "market": dict(paths="큰 길 대리석 + 시장 뒷골목 조약돌, 모퉁이 마당", plants="골목 끝 꽃 화단 (주황·흰), 가게 사이 화분",
                   props="가게마다 이유 있는 것: 물약=PotionCrate, 빵=BreadStand, 주스=FruitStall, 꽃=FlowerCart; 가게 차양·간판 (ImportHold 가게 4 parts)",
                   water="-", edge="골목 끝 낮은 난간 + 꽃 화단", light="골목 등불 (자동)", empty="뒷골목 안쪽 작은 잔디"),
    "market_hill": dict(paths="조약돌 골목·계단 (시장 8 -> 언덕 14)", plants="북동 곶 가장자리 나무 무리, 집마다 화분 (주황·크림)",
                        props="Clothesline·Woodpile·VegGarden (사는 집), BenchB (북동 곶 벤치 = 교차로 다리 경치), 언덕 마당 화단",
                        water="언덕 샘 (작은 바위 샘)", edge="단 턱 (시장보다 6 높음) + Balustrade", light="마당 등불 1, 곶 벤치 작은 빛",
                        empty="곶 앞 잔디"),
    "training": dict(paths="모래 마당 (Sand, 10/11: Ground는 C2c 빛에서 거의 검음), 고리길 조약돌", plants="마당 가장자리만 낮은 덤불 (가운데는 비움)",
                     props="Scarecrow 3 (첫 기술 시험 표적, 훈련장 표시 (-130,-446)), RackShieldSword, Flagpole_2, 관람 계단 (HaloStairs) 장면",
                     water="동쪽 시냇물 + 다리 B1·B2 (모양 다름)", edge="동쪽 시냇물 / 남쪽 성 축대", light="마당 모서리 등불 2",
                     empty="흙 마당 가운데 (기술 시험 자리)"),
    "castle": dict(paths="성 앞 마당 조약돌 + 성 큰 계단 (HaloStairs_3) + 성벽 곁길", plants="Topiary 2종 섞어 성 앞 (짝 금지), 성벽 아래 나무 무리",
                   props="Flagpole_3 x2 (높이 다르게), 성벽 곁길 Balustrade, 끝 = 성벽 전망 벤치 (서쪽 바다)", water="-",
                   edge="축대 벽 + 성벽", light="성 정면 아래 은은한 빛 2, 곁길 등불", empty="성 뒤 잔디 (성 뒤 마당)"),
    "plaza": dict(paths="포장 원 r40 안에 잔디 섬·화단 (들쭉날쭉, 규칙 5)", plants="광장 가장자리 꽃 화단 (분홍·흰·금), 서쪽 시냇물 건너 나무",
                  props="Town_Halo_Fountain3 (2단 분수), BenchA·C, Planter, PhotoDisc 1, Folk4 자리", water="분수",
                  edge="광장 둘레 낮은 화단, 서쪽 시냇물", light="광장 둘레 등불 (자동, 짝 없이)", empty="광장 남동쪽 잔디 섬"),
    "garden": dict(paths="디딤돌", plants="생울타리 + 연보라·흰 꽃, 웅덩이 건너편 나무 (물 앞엔 안 둠)",
                   props="BenchA (폭포 웅덩이 벤치 장면), Topiary", water="W2 계단 폭포 3단 (지그재그) + 정원 웅덩이",
                   edge="생울타리 + 웅덩이", light="장면 작은 빛 1", empty="웅덩이 옆 잔디"),
    "garden_homes": dict(paths="디딤돌 골목, 정원 마당 조약돌",
                         plants="해바라기 노랑·데이지 흰 덩어리, 나무 줄 (서쪽 바다 쪽), 채집 덤불 5곳 (매일 2~3곳)",
                         props="VegGarden·Clothesline·Woodpile, FlowerPotHQ Sunflower·Daisy, 연못 징검다리 (새로)", water="정원 연못",
                         edge="나무 줄 + 낮은 울타리", light="마당 등불 1, 골목 등불", empty="연못 북쪽 잔디"),
    "cathedral_steps": dict(paths="굽은 계단 대리석+금 테 (다리 3개, 꺾는 곳마다 쉼참 + 난간)", plants="계단 사이 꽃 단 (흰·연보라·금), 단 턱 아래 낮은 덤불",
                            props="꺾는 쉼참마다 벤치 또는 화분 하나 (짝 없이)", water="-", edge="단 턱 = 계단 높이 (단마다 다른 꽃)",
                            light="계단 등불 (자동)", empty="맨 아래 단 동쪽 잔디"),
    "cathedral": dict(paths="굽은 계단 끝 -> 대성당 앞 마당 대리석", plants="Topiary 3종 섞어 (줄 세우기 금지), 흰·연보라 꽃",
                      props="대성당 뒤 바다 전망 벤치 + Balustrade, PhotoDisc (계단 꼭대기)", water="대성당 샘 -> W2 머리",
                      edge="언덕 축대 + 계단 폭포 (서)", light="대성당 아래 은은한 빛 (uplights)", empty="대성당 동쪽 잔디"),
    "cliff_homes": dict(paths="조약돌 골목·계단 (18 -> 22)", plants="분홍·흰 꽃, 절벽 발치 나무·흰 바위 (10~20칸 불규칙)",
                        props="Clothesline·PotFlowers, BenchC (절벽 마을 발코니 장면), 동쪽 절벽 Balustrade", water="W3 2단 폭포 + 웅덩이",
                        edge="절벽 + 둔덕", light="골목 등불, 발코니 작은 빛", empty="절벽 아래 쉼참 옆 잔디"),
    "lookout": dict(paths="전망 탑 앞 마당", plants="가장자리 8칸 안엔 낮은 것만 (하늘·흰 꽃)", props="전망 탑 (ImportHold 탑 A/B/C), BenchB, PhotoDisc",
                    water="-", edge="난간 + 탑", light="탑 아래 은은한 빛", empty="탑 남쪽 잔디"),
}
# 검수 10/11 사진 판정에서 5단계로 미룬 것 (입힐 때 같이 고침)
STAGE5_FIXES = [
    "길 두 겹 금지: door_House_Garden3 오른쪽처럼 헤링본 포장(지형) 위에 두꺼운 흰 디딤돌이 또 깔린 곳 — 포장 길이면 디딤돌 빼고, "
    "디딤돌 길은 잔디 위에만·얇게·땅에 반쯤 묻게 (skeleton_ground 3등급 돌 + halo_blockout 3등급 포장 중 하나만)",
    "반 잘린 디딤돌: door_House_Cliff4·Garden3 — 층 턱·땅에 파묻힌 돌은 턱 위로 올리거나 뺌",
    "빵집·주스 사진의 하늘색 기둥 = 표시 판(Markers)이면 OK, 6단계 전에 숨김 확인",
    "바위 테가 옆에서 검고 두꺼운 곧은 띠 → 색·튀어나온 바위로 다듬기",
    "under_side_close 파란 점 2개(LOD 티) 지우기",
    "섬 받침 -48 평평 → 뾰족한 떠 있는 바위 아랫면 (2차 됨, 사진 확인)",
    "새 섬 폭포: halo_waterfx가 옛 HaloTerrainStore Waterfalls를 읽음 → plan v2 falls(W1·W2·W3)로 바꿈",
    "대성당 굽은 계단(cathedral_stairs, rails=True): 다리(leg) 양옆 난간을 끊김 없이 — 꽃 단을 넘어 질러가지 못하게(걷는 시간 계산이 난간을 막힘으로 침)",
]
# the gate's inner face never gets direct sun (front_sun 0%): warm fill lights there (검수 10/11), outside the spawn corridor
FILL_LIGHTS = [
    dict(at=(-15, -347), kind="등불 (따뜻한 PointLight)", note="성문 안쪽 서"),
    dict(at=(18, -345), kind="등불 (따뜻한 PointLight)", note="성문 안쪽 동 (서쪽과 거리 다르게)"),  # 결정 5: was (17,-349) on the pad box edge
    dict(at=(-20, -345), kind="낮은 등불", note="성문 안쪽 서 둘째"),  # 결정 5: was (-21,-353) on the SlimeMeadow pad box
    dict(at=(0, -342.5), kind="SurfaceLight (낮엔 약하게)", note="성문 안쪽 면 전체, 위쪽 띠"),
]


def lamp_spots(blds):
    """auto lamp spots (rule 6): along the main and grade-2 roads every 25-40 studs (uneven), sides switched irregularly,
    on the outer side of every bend > 25 deg, one per yard; never in the spawn corridor, on water or in a footprint"""
    gaps = [28, 36, 25, 40, 31, 34, 27, 38]
    sides = [1, -1, -1, 1, -1, 1, 1, -1, 1, -1]
    spots = []
    fps = [footprint(b) for b in blds]

    def ok(x, z):
        if abs(x) <= 13 and -432 <= z <= -330:
            return False
        if any(inside((x, z), pad_box(c, 1)) for _, c in PADS):  # 결정 5
            return False
        if not inside((x, z), LAND):
            return False
        for fp in fps:
            if inside((x, z), fp) or min(seg_dist((x, z), fp[i], fp[(i + 1) % 4]) for i in range(4)) < 2:
                return False
        st = WATER["stream"]
        for i in range(len(st) - 1):
            if seg_dist((x, z), st[i], st[i + 1]) < WATER["stream_w"][i] / 2 + 1.5:
                return False
        for w in WATER["pools"]:
            if math.hypot(x - w["at"][0], z - w["at"][1]) < w["r"] + 1.5:
                return False
        # 5단계 (10/11): never in the middle of another road, alley or door path
        for r2 in ROADS:
            for i in range(len(r2["pts"]) - 1):
                if seg_dist((x, z), r2["pts"][i], r2["pts"][i + 1]) < r2["w"] / 2 + 0.6:
                    return False
        return all(math.hypot(x - q[0], z - q[1]) >= 8 for q in spots)

    k = 0
    for r in ROADS:
        if r["grade"] > 2:
            continue
        pts = r["pts"]
        off = r["w"] / 2 + 2.5
        acc, nxt = 0.0, gaps[k % len(gaps)] / 2
        for i in range(len(pts) - 1):
            (ax, az), (bx, bz) = pts[i], pts[i + 1]
            L = math.hypot(bx - ax, bz - az)
            if L < 1e-6:
                continue
            ux, uz = (bx - ax) / L, (bz - az) / L
            d = 0.0
            while acc + (L - d) >= nxt:
                d += nxt - acc
                acc = 0.0
                sd = sides[k % len(sides)]
                for sd2 in (sd, -sd):  # the other side when this one is an alley / door path / building
                    x, z = ax + ux * d - uz * off * sd2, az + uz * d + ux * off * sd2
                    if ok(x, z):
                        spots.append((round(x, 1), round(z, 1), r["id"]))
                        break
                k += 1
                nxt = gaps[k % len(gaps)]
            acc += L - d
            # bend: the outer side of the turn at pts[i + 1]
            if i + 2 < len(pts):
                cx_, cz_ = pts[i + 2][0] - bx, pts[i + 2][1] - bz
                Lc = math.hypot(cx_, cz_)
                if Lc > 1e-6:
                    turn = math.degrees(math.atan2(ux * cz_ / Lc - uz * cx_ / Lc, ux * cx_ / Lc + uz * cz_ / Lc))
                    if abs(turn) > 25:
                        out_s = -1 if turn > 0 else 1
                        x, z = bx - uz * off * out_s, bz + ux * off * out_s
                        if ok(x, z):
                            spots.append((round(x, 1), round(z, 1), r["id"]))
    for y in YARDS:
        x, z = y["at"][0] + y["r"] * 0.7, y["at"][1] + y["r"] * 0.7
        if ok(x, z):
            spots.append((round(x, 1), round(z, 1), y["id"]))
    return spots


# ---------------------------------------------------------------- front sunlight (검수 10/11, 이미지 개발: fronts in shade)
# The main world's day: DayCycleService turns Lighting.ClockTime; WarService sets GeographicLatitude 35. Measured in Studio
# (Lighting:GetSunDirection, lat 35, 10/11): sun(t) = (0.9799 cos h, 0.9799 sin h, 0.1994), h = 15 deg x (t - 6): it rises
# in +x (east), sets in -x, and always leans +z (north, the gate side) by 11.5 deg -> a face looking -z (south) never gets
# direct sun. Day phase 7-17 runs at an even pace (Config.DayCycle.Pace: 960 s), so hours weigh the same.
SUN_LAT = 35
MAIN_FRONTS = ["Gate", "Shop_Potion", "Shop_Bakery", "Shop_Juice", "Shop_Flower", "Cathedral", "Castle", "Tower_GateEast",
               "Armory", "Tower_Lookout"]


def sun_dir(t):
    h = math.radians(15 * (t - 6))
    return (0.9799 * math.cos(h), 0.9799 * math.sin(h), 0.1994)


def front_sun(blds):
    """per building: share of the Day phase (7-17) its front face gets direct sun (n.s > 0.05 and not shadowed by other
    buildings or higher district ground), and the mean strength (n.s averaged over the day, 1 = facing the sun all day).
    The gate is checked on its INNER face (the one the town sees)."""
    tops = [(b, footprint(b), b["ground_y"] + b["h"]) for b in blds]
    maxtop = max(t for _, _, t in tops)
    dpolys = [(dd["poly"], max(dd["y"], dd.get("y_to") or dd["y"])) for dd in DISTRICTS]
    times = [7 + 0.25 * i for i in range(41)]
    out = {}
    for b in blds:
        yaw = math.radians(b["yaw"])
        nx, nz = math.sin(yaw), math.cos(yaw)
        if b["kind"] == "Gate":
            nx, nz = -nx, -nz
        # sample points on the front face: 3 across x 3 up, 0.6 out from the wall
        rx, rz = nz, -nx
        cx, cz = b["x"] + nx * (b["d"] / 2 + 0.6), b["z"] + nz * (b["d"] / 2 + 0.6)
        pts = [(cx + rx * f * b["w"] * 0.35, b["ground_y"] + hh, cz + rz * f * b["w"] * 0.35)
               for f in (-1, 0, 1) for hh in (2.5, b["h"] * 0.5, b["h"] - 2)]
        others = [(o, fp, top) for o, fp, top in tops if o is not b and math.hypot(o["x"] - b["x"], o["z"] - b["z"]) < 260]
        lit_w, strength = 0.0, 0.0
        for t in times:
            sx, sy, sz = sun_dir(t)
            ns = nx * sx + nz * sz
            if ns <= 0.05:
                continue
            strength += ns / len(times)
            free = 0
            for px, py, pz in pts:
                blocked = False
                k = 2.0
                while k < 260:
                    qx, qy, qz = px + sx * k, py + sy * k, pz + sz * k
                    if qy > maxtop + 2 and qy > 40:
                        break
                    for o, fp, top in others:
                        if qy < top and abs(qx - o["x"]) < 60 and abs(qz - o["z"]) < 60 and inside((qx, qz), fp):
                            blocked = True
                            break
                    if not blocked:
                        for poly, gy in dpolys:
                            if qy < gy and inside((qx, qz), poly):
                                blocked = True
                                break
                    if blocked:
                        break
                    k += 3.0
                if not blocked:
                    free += 1
            lit_w += free / len(pts) / len(times)
        out[b["id"]] = dict(front_lit_pct=round(lit_w * 100), strength_pct=round(strength * 100), main=b["id"] in MAIN_FRONTS,
                            face=compass(nx, nz) + ("(안쪽)" if b["kind"] == "Gate" else ""))
    return out


# ---------------------------------------------------------------- drawing
S = 2.0
PAD = 40
# the frame follows the land (③ 3차: the town grew past the old x -200..200, z -330..-700 box)
MINX = math.floor(min(p[0] for p in LAND) / 50) * 50 - 10
MAXX = math.ceil(max(p[0] for p in LAND) / 50) * 50 + 10
MAXZ = -310
MINZ = math.floor(min(p[1] for p in LAND) / 50) * 50 - 10
MW = int((MAXX - MINX) * S) + PAD * 2
MH = int((MAXZ - MINZ) * S) + PAD * 2
PANEL = 600


def P(x, z):
    return (PAD + (x - MINX) * S, PAD + (MAXZ - z) * S)


def font(sz, bold=False):
    return ImageFont.truetype("C:/Windows/Fonts/malgunbd.ttf" if bold else "C:/Windows/Fonts/malgun.ttf", sz)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def draw_map(blds, lamps=()):
    im = Image.new("RGB", (MW + PANEL, MH), (120, 186, 222))
    d = ImageDraw.Draw(im, "RGBA")
    # sea texture: soft rings around the island are skipped (no rays); plain sea + a light shore
    d.polygon([P(*p) for p in LAND], fill=(246, 240, 214), outline=(110, 96, 70))
    for dd in DISTRICTS:
        k = 1.0 - min(dd["y"], 34) / 34 * 0.22
        d.polygon([P(*p) for p in dd["poly"]], fill=shade(dd["color"], k) + (255,), outline=(120, 110, 90, 255))
        for t in dd.get("tiers", []):  # 결정 3: a real upper tier (darker, outlined, its own label)
            k2 = 1.0 - min(t["y"], 34) / 34 * 0.22
            d.polygon([P(*p) for p in t["poly"]], fill=shade(dd["color"], k2 * 0.93) + (255,), outline=(90, 70, 60, 255), width=2)
            xs, zs = [p[0] for p in t["poly"]], [p[1] for p in t["poly"]]
            tx, ty = P(max(xs) - 52, max(zs) - 4)
            d.text((tx, ty), f"{t['name']} Y{t['y']}", fill=(60, 40, 30), font=font(14, True))
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
    for y in YARDS:
        cx, cy = P(*y["at"])
        rr = y["r"] * S
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(214, 200, 168), outline=(150, 130, 100))
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
    for route, col in ((ROUTE_RETURN, (120, 60, 200, 170)), (ROUTE, (220, 40, 120, 220))):
        for i in range(len(route) - 1):
            d.line([P(*route[i]), P(*route[i + 1])], fill=col, width=3)
    for s in FIRST10 + FIRST10_RETURN:
        if not s.get("at"):
            continue
        ret = str(s["n"]).startswith("R")
        cx, cy = P(*s["at"])
        if ret:
            cx, cy = cx + 16, cy + 10  # the return marks sit beside the first-walk ones (same spots for R1 / R2)
        col = (120, 60, 200) if ret else (220, 40, 120)
        d.ellipse([cx - 13, cy - 13, cx + 13, cy + 13], fill=col, outline=(255, 255, 255), width=2)
        f = font(13 if ret else 17, True)
        bb = d.textbbox((0, 0), str(s["n"]), font=f)
        d.text((cx - (bb[2] - bb[0]) / 2, cy - (bb[3] - bb[1]) / 2 - 4), str(s["n"]), fill=(255, 255, 255), font=f)
    # the spawn-gate corridor (kept clear) and the fixed points
    a, b = P(-12, -330), P(12, -432)
    for yy in range(int(a[1]), int(b[1]), 10):
        d.line([(a[0], yy), (a[0], yy + 5)], fill=(200, 30, 30), width=2)
        d.line([(b[0], yy), (b[0], yy + 5)], fill=(200, 30, 30), width=2)
    for px in (-24, 24):
        cx, cy = P(px, -357)
        d.rectangle([cx - 6, cy - 6, cx + 6, cy + 6], fill=(120, 220, 120), outline=(20, 90, 20), width=2)
    for name, now, new, _ in FIXED_MOVE:
        if new and now:
            cx, cy = P(new[0], new[2])
            d.rectangle([cx - 5, cy - 5, cx + 5, cy + 5], fill=(30, 30, 30))
    # stage 5 lamps (small warm dots) and the gate's fill lights (orange)
    for x, z, _src in lamps:
        cx, cy = P(x, z)
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(255, 214, 90), outline=(150, 110, 20))
    for f in FILL_LIGHTS:
        cx, cy = P(*f["at"])
        d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(255, 140, 40), outline=(140, 60, 0))
    # scenes
    for name, at, _ in SCENES:
        cx, cy = P(*at)
        d.regular_polygon((cx, cy, 7), 4, fill=(250, 210, 40), outline=(120, 90, 0))
    # compass + scale
    d.text((PAD, 8), "북 = 성문·교차로 다리 (z -330)   ·   1칸 = 50스터드   ·   Y = 땅 높이", fill=(20, 40, 70), font=font(15, True))
    for gx in range(MINX + 10, MAXX - 9, 50):
        d.line([P(gx, MAXZ), P(gx, MAXZ - 4)], fill=(20, 40, 70), width=1)
        d.text((P(gx, MAXZ)[0] - 10, MH - PAD + 6), str(gx), fill=(20, 40, 70), font=font(11))
    for gz in range(-350, MINZ, -50):
        d.text((4, P(0, gz)[1] - 7), str(gz), fill=(20, 40, 70), font=font(11))
    return im, d


OUT_DMAP = os.path.join(OUT_DIR, "halo_district_map.png")
NEW_HOUSES = {"House_Hill4", "House_Cliff6", "House_Cliff7", "House_Cliff8", "House_Garden5", "House_Garden6", "House_Garden7"}
KIND_KO = {"Gate": "성문", "Tower": "탑", "Shop": "가게", "HouseA": "집", "HouseB": "집", "Castle": "성", "Cathedral": "대성당", "Armory": "무기고"}


def draw_district_map(blds):
    """A23-117 구획 지도 (검수 10/11): districts with their job, every building numbered inside its district with its why,
    the A23-124 new homes outlined orange. Output art/review/world/halo_v2/halo_district_map.png"""
    panel = 980
    im = Image.new("RGB", (MW + panel, MH), (150, 200, 230))
    d = ImageDraw.Draw(im, "RGBA")
    d.polygon([P(*p) for p in LAND], fill=(246, 240, 214), outline=(110, 96, 70))
    for dd in DISTRICTS:
        d.polygon([P(*p) for p in dd["poly"]], fill=dd["color"] + (255,), outline=(90, 80, 60, 255), width=3)
    st = WATER["stream"]
    for i in range(len(st) - 1):
        d.line([P(*st[i]), P(*st[i + 1])], fill=(80, 160, 215), width=int(WATER["stream_w"][i] * S))
    for r in ROADS:
        for i in range(len(r["pts"]) - 1):
            d.line([P(*r["pts"][i]), P(*r["pts"][i + 1])], fill=(255, 255, 255, 150), width=max(2, int(r["w"] * S * 0.6)))
    order = [dd["id"] for dd in DISTRICTS]
    num = {}
    for b in sorted(blds, key=lambda b: (order.index(b["district"]), b["id"])):
        num[b["id"]] = len(num) + 1
    for b in blds:
        fp = [P(*q) for q in footprint(b)]
        d.polygon(fp, fill=(255, 255, 255), outline=(60, 50, 40), width=2)
        if b["id"] in NEW_HOUSES:
            d.polygon(fp, outline=(240, 120, 0), width=5)
        yaw = math.radians(b["yaw"])
        dx, dz = math.sin(yaw), math.cos(yaw)
        a = P(b["door_at"][0], b["door_at"][1])
        e = P(b["door_at"][0] + dx * 7, b["door_at"][1] + dz * 7)
        d.line([a, e], fill=(200, 40, 40), width=4)
        cx, cy = P(b["x"], b["z"])
        t = str(num[b["id"]])
        f = font(16, True)
        bb = d.textbbox((0, 0), t, font=f)
        d.text((cx - (bb[2] - bb[0]) / 2, cy - (bb[3] - bb[1]) / 2 - 4), t, fill=(20, 20, 20), font=f)
    for dd in DISTRICTS:
        # label at the clearest point inside the district: farthest from its edges and from every building
        xs = [q[0] for q in dd["poly"]]
        zs = [q[1] for q in dd["poly"]]
        best, bx, bz = -1.0, sum(xs) / len(xs), sum(zs) / len(zs)
        for gx in range(int(min(xs)), int(max(xs)) + 1, 4):
            for gz in range(int(min(zs)), int(max(zs)) + 1, 4):
                if not inside((gx, gz), dd["poly"]):
                    continue
                pl = dd["poly"]
                de = min(seg_dist((gx, gz), pl[i], pl[(i + 1) % len(pl)]) for i in range(len(pl)))
                db = min([math.hypot(gx - b["x"], gz - b["z"]) - max(b["w"], b["d"]) / 2 for b in blds] + [999])
                sc = min(de * 1.6, db)
                if sc > best:
                    best, bx, bz = sc, gx, gz
        cx, cy = P(bx, bz)
        cy -= 11
        f = font(15, True)
        bb = d.textbbox((0, 0), dd["name"], font=f)
        w = bb[2] - bb[0]
        d.rounded_rectangle([cx - w / 2 - 5, cy - 2, cx + w / 2 + 5, cy + 22], 6, fill=(255, 255, 255, 215), outline=(90, 80, 60, 255))
        d.text((cx - w / 2, cy), dd["name"], fill=(30, 25, 20), font=f)
    d.text((PAD, 8), "빛 마을 구획 지도 (A23-117)  ·  북 = 성문·교차로 다리  ·  번호 = 오른쪽 표  ·  빨간 선 = 문 방향  ·  주황 테 = A23-124 새 집 7",
           fill=(20, 40, 70), font=font(15, True))
    # panel: district -> job -> numbered buildings with why
    x0, y = MW + 14, 12
    d.rectangle([MW, 0, MW + panel, MH], fill=(250, 248, 242))
    d.text((x0, y), f"구획 {len(DISTRICTS)} · 건물 {len(blds)} (집 {sum(1 for b in blds if b['kind'].startswith('House'))}, 새 집 {len(NEW_HOUSES)})",
           fill=(30, 30, 30), font=font(19, True)); y += 30
    for dd in DISTRICTS:
        d.rectangle([x0, y + 4, x0 + 14, y + 18], fill=dd["color"], outline=(90, 80, 60))
        d.text((x0 + 20, y), f"{dd['name']} — {dd['job']}", fill=(25, 25, 25), font=font(15, True)); y += 22
        for b in sorted([b for b in blds if b["district"] == dd["id"]], key=lambda b: num[b["id"]]):
            col = (200, 90, 0) if b["id"] in NEW_HOUSES else (50, 50, 50)
            ln = f"{num[b['id']]:>2}. {KIND_KO[b['kind']]} {b['id']} (문 {b['door_compass']}): {b['why']}"
            d.text((x0 + 22, y), ln, fill=col, font=font(12)); y += 17
        ys = [yd for yd in YARDS if inside(yd["at"], dd["poly"])]
        for yd in ys:
            d.text((x0 + 22, y), f"  마당 {yd['id']}: {yd['why']}", fill=(110, 90, 60), font=font(12)); y += 17
        y += 4
    return im

def draw_panel(im, d, blds, stats):
    x0 = MW + 16
    y = 14
    d.rectangle([MW, 0, MW + PANEL, MH], fill=(250, 248, 242))
    d.text((x0, y), f"빛 마을 v2 — 구역 (③ 3차: 1.5배, 땅 {stats['land'] / 1000:.0f}천 st²)", fill=(30, 30, 30), font=font(22, True)); y += 38
    d.text((x0, y), "첫 10분 (분홍) · 첫 장 뒤 돌아와 들름 (보라 R)", fill=(200, 30, 110), font=font(16, True)); y += 26
    for s in FIRST10 + FIRST10_RETURN:
        t = f"{s['n']}. {s['what']}"
        d.text((x0 + 6, y), t if len(t) <= 44 else t[:43] + "…", fill=(40, 40, 40), font=font(13)); y += 19
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
    d.text((x0, y), f"건물 {len(blds)}채 (빨간 짧은 선 = 문 방향)", fill=(30, 30, 30), font=font(16, True)); y += 26
    hd = {}
    for b in blds:
        if b["kind"].startswith("House"):
            hd[b["district"]] = hd.get(b["district"], 0) + 1
    cw, cd = KINDS["Castle"][0], KINDS["Castle"][1]
    lines = [f"성문 1 · 탑 {cnt.get('Tower', 0)} (성문 동쪽 1, 전망 1)", f"가게 {cnt.get('Shop', 0)} (물약·빵·주스·꽃, 시장 골목 한 줄)",
             f"집 {houses} = 시장 위 {hd.get('market_hill', 0)} · 절벽 {hd.get('cliff_homes', 0)} · 정원 {hd.get('garden_homes', 0)}",
             f"빛 성 1 ({cw}×{cd}, 3층, 돔 없음) · 무기고 1", "대성당 1 (70×70, 언덕 Y30, 축에서 동쪽)",
             f"골목 {len([r for r in ROADS if r['grade'] == 3 and not r['id'].startswith('door_')])} · 작은 마당 {len(YARDS)} · 연못·샘 {len(WATER['pools'])}"]
    for ln in lines:
        d.text((x0 + 6, y), ln, fill=(40, 40, 40), font=font(14)); y += 21
    y += 8
    d.text((x0, y), "물·다리", fill=(30, 30, 30), font=font(16, True)); y += 26
    for ln in ["시냇물 1줄: 대성당 샘 → 계단 폭포 W2(3단) → 광장 서쪽 → 성문 옆 W1로 바다",
               "W3: 동쪽 절벽 마을 2단 폭포 · 분수 2단(광장)", "다리 3개(모양·길이 다름): B1 첫 10분, B2 고리, B3 성 뒤"]:
        d.text((x0 + 6, y), ln, fill=(40, 40, 40), font=font(13)); y += 20
    y += 8
    d.text((x0, y), "고정점", fill=(30, 30, 30), font=font(16, True)); y += 26
    for ln in ["그대로: 다리·성문(0,-330)·스폰(0,-420)·Bright·Gleam·이동 발판 2(초록) / 구역 상자는 넓힘",
               "빨간 점선 = 스폰-문 통로(|x|≤12) 비움 → 영웅상·Gleam만 옆으로",
               "옮김(검은 네모): 영웅상·Gleam·물약 상인·Folk1~4 / 폭포 소리 3곳",
               "새로: 훈련장 표적·표시 · 걷는 바닥은 전부 Terrain"]:
        d.text((x0 + 6, y), ln, fill=(40, 40, 40), font=font(13)); y += 20
    y += 8
    d.text((x0, y), "검사", fill=(30, 30, 30), font=font(16, True)); y += 26
    low = sorted([(v["front_lit_pct"], k) for k, v in stats.get("sun", {}).items() if v["main"]])[:3]
    for ln in [f"포장 약 {stats['pave'] * 100:.0f}% (목표 ≤35%) · 거울 짝 {stats['pairs']}",
               "앞면 햇빛 낮은 주요 건물: " + ", ".join(f"{k} {p}%" for p, k in low),
               f"겹침·땅 밖·문 앞 길 먼 것: {stats['issues']}건", "노란 마름모 = 작은 장면·사진 자리 8곳", "검은 네모 = 옮긴 고정점의 새 자리"]:
        d.text((x0 + 6, y), ln, fill=(40, 40, 40), font=font(13)); y += 20


VENDORS = [("물약 상인 PotionHalo", "PotionHalo", "Shop_Potion", -4), ("Folk3 빵집", "Folk3", "Shop_Bakery", -4),
           ("Folk1 주스", "Folk1", "Shop_Juice", -4), ("Folk2 꽃", "Folk2", "Shop_Flower", 4)]  # (name, Config id, shop, side of the door)
FIXED_LOOK = {}


def final_fixed(blds):
    """review 10/11: the vendor NPCs stand beside their own shop door looking out (the stage-1 spots were grown with the
    town but the shops moved), and every code string is written from the final numbers (some kept pre-1.5x text)"""
    global FIXED_MOVE
    B = {b["id"]: b for b in blds}
    f = {w["id"]: w for w in WATER["falls"]}
    fp = next(p for p in WATER["pools"] if p["id"] == "fountain")
    out = []
    for name, now, new, cfg in FIXED_MOVE:
        v = next((v for v in VENDORS if v[0] == name), None)
        if v:
            b = B[v[2]]
            yw = math.radians(b["yaw"])
            fx, fz = math.sin(yw), math.cos(yw)
            x, z = b["door_at"][0] + fz * v[3] + fx * 1.5, b["door_at"][1] - fx * v[3] + fz * 1.5
            look = (round(b["door_at"][0] + fx * 12, 1), round(b["door_at"][1] + fz * 12, 1))
            new = (round(x, 1), b["ground_y"], round(z, 1))
            cfg = (f"Config.TownNpcs {v[1]} At ({new[0]},{new[1]},{new[2]}) Look ({look[0]},{look[1]}): {b['id']} 문 "
                   f"{'오른쪽' if v[3] > 0 else '왼쪽'}, 거리 쪽을 봄 (12칸 안 판매·말하기 그대로)")
            FIXED_LOOK[name] = look
        elif name.startswith("Folk4"):
            new, look = (36, 10, -596), tuple(fp["at"])
            cfg = f"Config.TownNpcs Folk4 At (36,10,-596) Look ({look[0]},{look[1]}): 분수 동쪽, 분수를 봄; 분수 이름 Town_Halo_Fountain3"
            FIXED_LOOK[name] = look
        elif name == "Sir Gleam":
            FIXED_LOOK[name] = (0, new[2])
        elif name.startswith("폭포 소리"):
            cfg = "Config.Audio.Ambient.Waterfall.Spots → " + ", ".join(
                f"{k} ({f[k]['at'][0]},{f[k]['y']},{f[k]['at'][1]})" for k in ("W1", "W2", "W3")) + " 3곳(또는 Decor 아래 이름 …Waterfall)"
        out.append((name, now, new, cfg))
    FIXED_MOVE = out


def main():
    blds = build_list()
    final_fixed(blds)
    pot = next(b for b in blds if b["id"] == "Shop_Potion")
    ROUTE_RETURN[2] = tuple(pot["door_at"])
    pd = math.hypot(pot["door_at"][0], pot["door_at"][1] + 420)
    DIST["market"]["why"] = (f"가게 4채가 한 골목에 각자 각도로 선다(A23-112). 물약 가게 문은 스폰에서 약 {pd:.0f}스터드(걸어서 약 "
                             f"{pd / WALK_SPEED:.0f}초): 첫 장 뒤 돌아와(M1_4) 처음 들르는 곳. 골목은 4→8로 살짝 오른다.")
    cat = next(b for b in blds if b["id"] == "Cathedral")
    DIST["cathedral"]["why"] = (f"왕관 조각을 지키는 곳이라 마을에서 가장 높다(Y{cat['ground_y']}, 꼭대기 {cat['ground_y'] + cat['h']}). "
                                f"축에서 동쪽으로 {cat['x']:.0f} 비켜 서서(A23-112) 성문에서 비스듬히 보이고, 광장 남쪽 끝에서 굽은 계단이 "
                                "세 번 꺾어 오른다(결정 1). 서쪽 끝에 샘.")
    for s in FIRST10_RETURN:
        if s["n"] == "R3":
            s["at"] = tuple(pot["door_at"])
    ROADS.extend(door_spurs(blds))
    fix_bridges()
    msgs, pairs, land, pave, sight = checks(blds)
    lamps = lamp_spots(blds)
    props = HP.resolve(sys.modules[__name__], blds, lamps)
    pmsgs = HP.check(sys.modules[__name__], blds, props)
    msgs += pmsgs
    print(f"[props] {sum(1 for p in props if not p.get('auto'))} props + {sum(1 for p in props if p.get('auto'))} lamps, issues {len(pmsgs)}")
    for k, v in sight.items():
        print("[gate view]", k, v)
    sun = front_sun(blds)
    print(f"[dressing] lamp spots {len(lamps)}, fill lights {len(FILL_LIGHTS)}, districts {len(DRESSING)}")
    for k, v in sorted(sun.items(), key=lambda kv: kv[1]["front_lit_pct"]):
        print("[front sun]", k, v)
    for m in msgs:
        print("[check]", m)
    stats = dict(pave=pave, pairs=pairs, issues=len([m for m in msgs if not m.startswith("거울")]), land=land, sun=sun)
    print(f"[plan] land {land:.0f} st² · paving ~{pave * 100:.1f}% · mirror pairs {pairs} · buildings {len(blds)} · issues {stats['issues']}")
    os.makedirs(OUT_DIR, exist_ok=True)
    im, d = draw_map(blds, lamps)
    draw_panel(im, d, blds, stats)
    im.save(OUT_MAP)
    draw_district_map(blds).save(OUT_DMAP)
    HP.draw(sys.modules[__name__], blds, props, pmsgs).save(HP.OUT_PMAP)
    plan = dict(
        note="빛 마을 v2 1단계 '이야기와 구역' (SPEC A23-121, 이미지 생성 1, 2026-10-11). 옛 섬·옛 plan은 쓰지 않음. 좌표 x,z(스터드), "
             "북 = z -330 성문/교차로 다리. y = 그 구역 땅 높이(y_to = 경사 끝). 건물 yaw = 문이 보는 방향(0 = 북 +z, 90 = 동 +x). "
             "3단계 회색 상자와 4단계 골격은 이 값을 쓴다.",
        frame=dict(x=[min(p[0] for p in LAND), max(p[0] for p in LAND)], z=[min(p[1] for p in LAND), max(p[1] for p in LAND)],
                   north="z -330 (gate, Crossroads bridge)", grow=SHRINK),
        story=STORY,
        first_10_minutes=FIRST10,
        first_10_return=FIRST10_RETURN,
        first_10_route=[list(p) for p in ROUTE],
        return_route=[list(p) for p in ROUTE_RETURN],
        walk_speed=WALK_SPEED,
        pads=dict(keep_half=PAD_KEEP, note="결정 5: 발판 둘레 12×12 + 2 = 길·등불·문 길·소품·건물 없음",
                  at={n: list(c) for n, c in PADS}),
        land=[list(p) for p in LAND],
        districts=[{k: (v if k != "poly" else [list(p) for p in v]) for k, v in dd.items() if k != "color"} for dd in DISTRICTS],
        roads=[{**r, "pts": [list(p) for p in r["pts"]]} for r in ROADS],
        water={**WATER, "stream": [list(p) for p in WATER["stream"]]},
        bridges=BRIDGES,
        yards=[{**y, "at": list(y["at"])} for y in YARDS],
        dressing=dict(note="5단계 입히기 재료 목록(검수 10/11). 키트 이름 = tools/halo_props_list.txt, 규칙 = acnh 12규칙", kit=KIT,
                      by_district=DRESSING, lamps=[[p[0], p[1]] for p in lamps],
                      props_note="A23-117: 소품 하나하나 = 키트·자리(x,z)·yaw(보는 쪽, 0 = 북)·크기·무엇에 붙었나(anchor)·이유(why). "
                                 "P = 손으로 정한 것(tools/halo_props_v2.py SPEC), L = 자동 등불(규칙 6). 높이는 놓을 때 지형에서 읽음(ground_y는 구역 높이). "
                                 "NEW_ 키트 = 아직 없는 것(new_kits), 지도 art/review/world/halo_v2/halo_props_map.png",
                      props=props, new_kits={k: v[0] for k, v in HP.NEW_KITS.items()},
                      stage5_fixes=STAGE5_FIXES,
                      fill_lights=[{**f, "at": list(f["at"])} for f in FILL_LIGHTS],
                      uplights=["Cathedral 앞 마당 바닥 2(은은히 위로)", "Tower_GateEast 아래 1", "Tower_Lookout 아래 1", "Castle 정면 아래 2"],
                      photo_discs=["대성당 계단 꼭대기", "다리 B1 위", "폭포 웅덩이 벤치", "전망 탑 꼭대기", "성벽 전망", "북동 곶 벤치"],
                      gather_bushes="정원 마을 5곳(매일 2~3곳, 플레이어마다 다름) - 동작은 베타 다듬기"),
        buildings=blds,
        scenes=[dict(name=n, at=list(a), view=v, why=WHY_SCENE.get(n, "")) for n, a, v in SCENES],
        fixed_points=dict(keep=[dict(name=n, at=list(a) if a else None, code=c) for n, a, c in FIXED_KEEP],
                          move=[dict(name=n, now=list(a) if a else None, new_xyz=list(b) if b else None, code=c,
                                     look=list(FIXED_LOOK[n]) if n in FIXED_LOOK else None) for n, a, b, c in FIXED_MOVE],
                          ground_rule=GROUND_RULE, pads=[dict(name="Pad_Halo_SlimeMeadow", at=[-24, 0.7, -357]), dict(name="Pad_Halo_GoblinWoods", at=[24, 0.7, -357])],
                          names=dict(fountain="Town_Halo_Fountain3", lamps="LampLight 속성/태그", collision="DecorPlayerOnly")),
        gate_view=sight,
        checks=dict(paving_share=round(pave, 3), mirror_pairs=pairs, issues=msgs, land_area=round(land),
                    front_sun=dict(note="앞면 햇빛 %: 낮 7-17시 중 앞면이 해를 직접 받는 몫(n·s > 0.05, 다른 건물·높은 땅 그림자 뺌, 앞면 9점 평균). "
                                        "세기 %: 하루 평균 n·s(100 = 하루 종일 해를 정면으로). 위도 35(WarService), 해는 늘 +z(북, 성문 쪽)로 11.5° 기움 "
                                        "→ -z(남)를 보는 면은 직접 해 0. 성문은 안쪽 면(마을이 보는 면).", by_building=sun)),
        rules="A23-112 비대칭, A23-117 구역·이유, A23-106/120 진짜 문·빈 속, 성 돔 없음, 빛살 무늬 금지, acnh 12규칙",
    )
    with open(OUT_JSON, "w", encoding="utf-8", newline="") as f:
        f.write(json.dumps(plan, ensure_ascii=False, indent=1) + "\n")
    print("[plan] wrote", OUT_JSON, OUT_MAP)


if __name__ == "__main__":
    main()
