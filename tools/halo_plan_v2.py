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
         poly=[(-24, -600), (40, -590), (104, -602), (112, -652), (96, -694), (0, -698), (-54, -690), (-58, -640)],
         why="왕관 조각을 지키는 곳이라 마을에서 가장 높다. 축에서 동쪽으로 70 비켜 서서(A23-112) 성문에서 비스듬히 보이고, 큰 길은 광장에서 한 번 굽어 큰 계단으로 오른다. 서쪽 끝에 샘.",
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
    dict(id="B2", at=(-56, -376), len=12, kind="작은 나무 다리", note="훈련장 → 성문 돌아가는 길"),
    dict(id="B3", at=(-58, -528), len=14, kind="금 난간 다리", note="광장 → 성 뒤 마당"),
]

# ---------------------------------------------------------------- buildings: kind -> footprint (w, d), height, floors, floor height, door (w, h)
KINDS = {
    "Gate": (50, 16, 44, 1, 30, (16, 30)),
    "Tower": (12, 12, 36, 3, 8, (4, 7)),
    "Shop": (24, 15, 18, 1, 9, (5, 7.5)),
    "HouseA": (24, 22, 26, 2, 7, (4, 7)),
    "HouseB": (26, 18, 28, 2, 7.5, (4, 7)),
    "Castle": (100, 70, 44, 3, 12, (10, 12)),  # 10/11 ③ 3차: new castle of light (F3 line), was 64 x 40
    "Cathedral": (70, 70, 54, 1, 24, (10, 14)),
    "Armory": (16, 12, 12, 1, 8, (5, 7)),
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
    ("Sir Gleam", (-10, -372), (-22, 0, -368), "Config.TownNpcs Gleam At/Look(0,-372) (통로 밖으로 12 비킴, 문 길 옆 그대로)"),
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
    ("훈련장 (새)", None, (-100, 2, -444), "새 Landmark TrainingYard + 허수아비 표적(게임성 개발: 첫 기술 퀘스트가 여기를 가리키게)"),
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
for _f in FIRST10:
    _f["at"] = shrink(*_f["at"])
ROUTE = [shrink(*p) for p in ROUTE]
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
        if b["kind"] != "Gate" and not all(inside(p, LAND) for p in fp):  # the gate stands on the bridge end
            msgs.append(f"땅 밖: {b['id']}")
        if not inside((b["x"], b["z"]), DIST[b["district"]]["poly"]):
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
            if b["kind"] == "Gate" or r["id"] == "door_" + b["id"]:
                continue
            fp = footprint(b)
            hit = False
            for i in range(len(r["pts"]) - 1):
                (ax, az), (bx, bz) = r["pts"][i], r["pts"][i + 1]
                n = max(1, int(math.hypot(bx - ax, bz - az) // 2))
                for k in range(n + 1):
                    if i == 0 and k == 0 and r["id"].startswith("door_"):
                        continue
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
                "디딤돌 (정원 길)", "작은 다리·징검다리 (연못·샘)", "떠 있는 섬 아랫면 뾰족 바위 (검수 ③ 2차)"],
)
DRESSING = {
    "arrival": dict(paths="큰 길 흰 대리석+금 테 (통로 |x|<=12는 곧게, 소품 없음), 북쪽은 모래 해변",
                    plants="W1 폭포 옆(서) 나무 무리 3 + 흰 바위, 영웅상 둘레 꽃 고리, 해변 쪽은 낮은 풀",
                    props="GuardPost (성문 동쪽 탑 옆: 문지기), Flagpole_1 (탑 옆, 짝 없음), 해변 쪽 낮은 Balustrade, PotFlowers",
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
    "training": dict(paths="흙 마당 (Ground), 고리길 조약돌", plants="마당 가장자리만 낮은 덤불 (가운데는 비움)",
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
    "cathedral": dict(paths="큰 계단 (HaloStairs_3/5) -> 대성당 앞 마당 대리석", plants="Topiary 3종 섞어 (줄 세우기 금지), 흰·연보라 꽃",
                      props="대성당 뒤 바다 전망 벤치 + Balustrade, PhotoDisc (계단 꼭대기)", water="대성당 샘 -> W2 머리",
                      edge="언덕 축대 + 계단 폭포 (서)", light="대성당 아래 은은한 빛 (uplights)", empty="대성당 동쪽 잔디"),
    "cliff_homes": dict(paths="조약돌 골목·계단 (18 -> 22)", plants="분홍·흰 꽃, 절벽 발치 나무·흰 바위 (10~20칸 불규칙)",
                        props="Clothesline·PotFlowers, BenchC (절벽 마을 발코니 장면), 동쪽 절벽 Balustrade", water="W3 2단 폭포 + 웅덩이",
                        edge="절벽 + 둔덕", light="골목 등불, 발코니 작은 빛", empty="절벽 아래 쉼참 옆 잔디"),
    "lookout": dict(paths="전망 탑 앞 마당", plants="가장자리 8칸 안엔 낮은 것만 (하늘·흰 꽃)", props="전망 탑 (ImportHold 탑 A/B/C), BenchB, PhotoDisc",
                    water="-", edge="난간 + 탑", light="탑 아래 은은한 빛", empty="탑 남쪽 잔디"),
}
# the gate's inner face never gets direct sun (front_sun 0%): warm fill lights there (검수 10/11), outside the spawn corridor
FILL_LIGHTS = [
    dict(at=(-15, -347), kind="등불 (따뜻한 PointLight)", note="성문 안쪽 서"),
    dict(at=(17, -349), kind="등불 (따뜻한 PointLight)", note="성문 안쪽 동 (서쪽과 거리 다르게)"),
    dict(at=(-21, -353), kind="낮은 등불", note="성문 안쪽 서 둘째"),
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
                x, z = ax + ux * d - uz * off * sd, az + uz * d + ux * off * sd
                if ok(x, z):
                    spots.append((round(x, 1), round(z, 1)))
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
                            spots.append((round(x, 1), round(z, 1)))
    for y in YARDS:
        x, z = y["at"][0] + y["r"] * 0.7, y["at"][1] + y["r"] * 0.7
        if ok(x, z):
            spots.append((round(x, 1), round(z, 1)))
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
    route = ROUTE
    for i in range(len(route) - 1):
        d.line([P(*route[i]), P(*route[i + 1])], fill=(220, 40, 120, 200), width=3)
    for s in FIRST10:
        cx, cy = P(*s["at"])
        d.ellipse([cx - 13, cy - 13, cx + 13, cy + 13], fill=(220, 40, 120), outline=(255, 255, 255), width=2)
        d.text((cx - 5, cy - 11), str(s["n"]), fill=(255, 255, 255), font=font(17, True))
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
    for x, z in lamps:
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


def draw_panel(im, d, blds, stats):
    x0 = MW + 16
    y = 14
    d.rectangle([MW, 0, MW + PANEL, MH], fill=(250, 248, 242))
    d.text((x0, y), f"빛 마을 v2 — 구역 (③ 3차: 1.5배, 땅 {stats['land'] / 1000:.0f}천 st²)", fill=(30, 30, 30), font=font(22, True)); y += 38
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


def main():
    blds = build_list()
    ROADS.extend(door_spurs(blds))
    msgs, pairs, land, pave, sight = checks(blds)
    for k, v in sight.items():
        print("[gate view]", k, v)
    sun = front_sun(blds)
    lamps = lamp_spots(blds)
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
    plan = dict(
        note="빛 마을 v2 1단계 '이야기와 구역' (SPEC A23-121, 이미지 생성 1, 2026-10-11). 옛 섬·옛 plan은 쓰지 않음. 좌표 x,z(스터드), "
             "북 = z -330 성문/교차로 다리. y = 그 구역 땅 높이(y_to = 경사 끝). 건물 yaw = 문이 보는 방향(0 = 북 +z, 90 = 동 +x). "
             "3단계 회색 상자와 4단계 골격은 이 값을 쓴다.",
        frame=dict(x=[min(p[0] for p in LAND), max(p[0] for p in LAND)], z=[min(p[1] for p in LAND), max(p[1] for p in LAND)],
                   north="z -330 (gate, Crossroads bridge)", grow=SHRINK),
        story=STORY,
        first_10_minutes=FIRST10,
        first_10_route=[list(p) for p in ROUTE],
        land=[list(p) for p in LAND],
        districts=[{k: (v if k != "poly" else [list(p) for p in v]) for k, v in dd.items() if k != "color"} for dd in DISTRICTS],
        roads=[{**r, "pts": [list(p) for p in r["pts"]]} for r in ROADS],
        water={**WATER, "stream": [list(p) for p in WATER["stream"]]},
        bridges=BRIDGES,
        yards=[{**y, "at": list(y["at"])} for y in YARDS],
        dressing=dict(note="5단계 입히기 재료 목록(검수 10/11). 키트 이름 = tools/halo_props_list.txt, 규칙 = acnh 12규칙", kit=KIT,
                      by_district=DRESSING, lamps=[list(p) for p in lamps],
                      fill_lights=[{**f, "at": list(f["at"])} for f in FILL_LIGHTS],
                      uplights=["Cathedral 앞 마당 바닥 2(은은히 위로)", "Tower_GateEast 아래 1", "Tower_Lookout 아래 1", "Castle 정면 아래 2"],
                      photo_discs=["대성당 계단 꼭대기", "다리 B1 위", "폭포 웅덩이 벤치", "전망 탑 꼭대기", "성벽 전망", "북동 곶 벤치"],
                      gather_bushes="정원 마을 5곳(매일 2~3곳, 플레이어마다 다름) - 동작은 베타 다듬기"),
        buildings=blds,
        scenes=[dict(name=n, at=list(a), view=v) for n, a, v in SCENES],
        fixed_points=dict(keep=[dict(name=n, at=list(a) if a else None, code=c) for n, a, c in FIXED_KEEP],
                          move=[dict(name=n, now=list(a) if a else None, new_xyz=list(b) if b else None, code=c) for n, a, b, c in FIXED_MOVE],
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
