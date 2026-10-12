"""halo_props_v2.py (이미지 생성 1, 2026-10-11, SPEC A23-117 / A23-121 5단계 '입히기' 준비).

Every stage-5 prop of the new Halo town, one by one, each with a `why` (who uses it / what it is for), placed relative to
what gives it its reason (a door, a yard, a scene, a pool). Called from tools/halo_plan_v2.py main() with the plan module;
the props go into plan json `dressing.props`, their check messages into `checks.issues`, and the prop map is drawn to
art/review/world/halo_v2/halo_props_map.png (top view: numbered dots -> reason table).

Placement frames
  D(building, right, fwd, ...)  door frame: fwd = out of the door, right = the right hand of someone walking out
  Y(yard, dx, dz, ...) / S(scene, dx, dz, ...) / A(x, z, ...)  world offsets (x east, z north = toward the gate)
  W(pool, angle, ...)  on the bank of a pool (angle 0 = north, 90 = east)
yaw = the way the prop looks (0 = north +z, 90 = east), `face=(x, z)` turns it to look at a point.

Checks (A23-117 + acnh rules 6/10/11, docs/design/acnh_halo_layout_rules_2026-10-10.md):
  why missing; unknown kit; off the land; in a building; in the spawn-gate corridor or spawn circle; on water; blocking a road
  or alley; lamps only on paths / gathering places / doors; trees, bushes, rocks only at edges (land edge, district edge,
  water bank); pots / planters only at doors, path sides, yards, scenes; tall things (> 4.5) not within 4 of the main road;
  props overlapping each other or a fixed NPC / statue / pad; mirror pairs at a door; > 5 of one kit inside 40 x 40.
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_PMAP = os.path.join(ROOT, "art", "review", "world", "halo_v2", "halo_props_map.png")
KIT_LIST = os.path.join(ROOT, "tools", "halo_props_list.txt")

# kits that do not exist yet (stage 5 needs them: 2D -> 4-view 2D -> Tripo -> Blender, 이미지 생성 2/3), with height studs
NEW_KITS = {
    "NEW_Cauldron": ("물약 솥 (낮은 쇠솥 + 받침, 김)", 3.5),
    "NEW_BreadBasket": ("빵 바구니 (갓 구운 빵)", 1.6),
    "NEW_CafeTable": ("작은 둥근 탁자", 3.0),
    "NEW_WateringCan": ("물뿌리개", 1.2),
    "NEW_WhiteRock": ("흰 바위 2~3종 (절벽 발치·물가)", 2.5),
    "NEW_Hedge": ("생울타리 (꽃 핀 낮은 울타리 덤불)", 3.5),
    "NEW_FlowerBush": ("꽃 덤불 (연보라·흰)", 3.0),
    "NEW_GatherBush": ("채집 덤불 (매일 2~3곳 빛남)", 3.0),
    "NEW_ArmoryBarrels": ("무기고 통·상자 묶음", 3.5),
    "NEW_WallLamp": ("문 옆 벽등", 1.5),
    "NEW_Beehive": ("벌통 (나무 상자 2단)", 3.0),
    "NEW_NoticeBoard": ("마을 알림판", 6.0),
    "NEW_BellFrame": ("작은 종 걸이 (연습용 종)", 6.0),
    "NEW_Easel": ("이젤 (바다 그림)", 5.5),
    "NEW_CandleCrate": ("초 상자 (흰 초 묶음)", 2.0),
    "NEW_Telescope": ("망원경 (세 다리)", 5.0),
    "NEW_WaterBuckets": ("물통 2개 + 긴 갈퀴", 2.5),
    "NEW_SteppingStones": ("연못 징검다리 (납작 돌 5~6)", 0.5),
}
EXISTING = {"Town_Halo_Fountain3": 12.0}  # in the main game already (fixed name, Config)

# category, spacing radius (studs), height (studs) per kit prefix
CAT = [
    ("Lantern", "lamp", 0.8, 7), ("NEW_WallLamp", "lamp", 0.2, 1.5),
    ("Bench", "bench", 2.2, 3), ("FlowerPot", "pot", 1.2, 3.5), ("PotFlowers", "pot", 1.2, 3), ("Planter", "pot", 2.4, 5.8),
    ("RoundTree", "nature", 4.0, 10), ("NEW_FlowerBush", "nature", 2.2, 3), ("NEW_Hedge", "nature", 2.6, 3.5),
    ("NEW_GatherBush", "nature", 2.0, 3), ("NEW_WhiteRock", "nature", 1.8, 2.5),
    ("Topiary", "item", 2.0, 8), ("Flagpole", "item", 1.0, 12), ("GuardPost", "item", 3.5, 12), ("PhotoDisc", "item", 4.0, 0.3),
    ("Clothesline", "item", 4.5, 6), ("VegGarden", "item", 3.8, 2), ("Woodpile", "item", 2.6, 3), ("BreadStand", "item", 3.0, 5),
    ("FruitStall", "item", 3.2, 9), ("FlowerCart", "item", 3.2, 5), ("PotionCrate", "item", 2.2, 2.5), ("Scarecrow", "item", 1.8, 6.5),
    ("RackShieldSword", "item", 2.6, 5), ("Balustrade", "item", 2.4, 4.5), ("Fountain", "item", 9.0, 12),
    ("NEW_SteppingStones", "item", 1.0, 0.5), ("NEW_BreadBasket", "item", 1.0, 1.6), ("NEW_WateringCan", "item", 0.7, 1.2),
    ("NEW_CafeTable", "item", 1.6, 3), ("NEW_CandleCrate", "item", 1.2, 2), ("NEW_WaterBuckets", "item", 1.5, 2.5),
    ("NEW_Cauldron", "item", 2.0, 3.5), ("NEW_ArmoryBarrels", "item", 2.2, 3.5), ("NEW_Beehive", "item", 1.5, 3),
    ("NEW_NoticeBoard", "item", 1.8, 6), ("NEW_BellFrame", "item", 1.8, 6), ("NEW_Easel", "item", 1.5, 5.5), ("NEW_Telescope", "item", 1.5, 5),
]


def kit_names():
    names = set()
    with open(KIT_LIST, encoding="utf-8") as f:
        for ln in f:
            ln = ln.strip()
            if ln and not ln.startswith("#"):
                names.add(ln.split()[0])
    return names


def kit_cat(kit):
    for pre, cat, r, h in CAT:
        if pre in kit:
            if kit in NEW_KITS:
                h = NEW_KITS[kit][1]
            return cat, r, h
    return "item", 2.5, NEW_KITS.get(kit, ("", 3))[1]


# ---------------------------------------------------------------- the props (A23-117: every one says why it is there)
# order = district by district (the table follows it). Story: halo_plan_v2 WHY_B (who lives where).
def D(b, right, fwd, kit, why, yaw=0, face=None, top=False):
    return dict(frame="door", ref=b, off=(right, fwd), kit=kit, why=why, yaw_rel=yaw, face=face, top=top)


def Y(y, dx, dz, kit, why, yaw=0, face=None):
    return dict(frame="yard", ref=y, off=(dx, dz), kit=kit, why=why, yaw=yaw, face=face)


def S(s, dx, dz, kit, why, yaw=0, face=None, top=False):
    return dict(frame="scene", ref=s, off=(dx, dz), kit=kit, why=why, yaw=yaw, face=face, top=top)


def A(x, z, kit, why, yaw=0, face=None):
    return dict(frame="abs", ref=None, off=(x, z), kit=kit, why=why, yaw=yaw, face=face)


def W(p, ang, kit, why, out=1.0):
    return dict(frame="pool", ref=p, off=(ang, out), kit=kit, why=why, yaw=ang, face=None)


SPEC = [
    # --- 들어오는 마당: 성문 = 경비 자리·깃발, 영웅상 꽃 고리, 폭포 쪽 자연
    A(-35, -347, "HaloReasonHQ_GuardPost", "문지기 초소: 다리로 들어오는 사람을 맞는 경비 자리(서쪽에만 — 동쪽엔 탑, 비대칭)", face=(-35, -320)),
    A(29, -343, "HaloFlagpole_1", "성문 깃발: 다리에서 보면 여기가 빛 진영 마을임을 알림(탑 옆 하나, 짝 없음)"),
    A(-43, -391, "HaloVar4_PotFlowers_A", "영웅상 꽃 고리: 마을이 영웅을 기림(흰)"),
    A(-28, -394, "HaloVar3_PotFlowers_E", "영웅상 꽃 고리: 마을이 영웅을 기림(연금)"),
    A(-38, -395, "HaloFlowerPotHQ_Daisy", "영웅상 꽃 고리: 마을이 영웅을 기림(하늘·흰)"),
    A(-58, -337, "HaloVar3_RoundTree_E", "W1 폭포 옆 나무 무리: 성문 서쪽 끝 = 섬 가장자리(규칙 7, 동쪽 탑과 다르게)"),
    A(-62, -348, "HaloVar3_RoundTree_G", "W1 폭포 옆 나무 무리(둘째, 크기 다르게)"),
    A(-53, -357, "HaloVar3_RoundTree_F", "W1 폭포 옆 나무 무리(셋째)"),
    A(-71, -330, "NEW_WhiteRock", "W1 폭포 발치 흰 바위: 물가 자연, 나무 무리 아래 층(규칙 10)"),
    # --- 시장 골목: 가게마다 파는 것이 밖에 보인다
    D("Shop_Potion", 6, 2, "HaloReasonHQ_PotionCrate", "물약 병 상자: 물약 상인이 가게 밖에 내놓은 물약(첫 10분 둘째 할 일 표시)", yaw=-20),
    D("Shop_Potion", -8, 3, "NEW_Cauldron", "물약 솥: 가게 옆에서 물약을 끓임(김 = 멀리서도 물약 가게)"),
    D("Shop_Bakery", 6.5, 2.5, "HaloReasonHQ_BreadStand", "빵 진열대: 빵집 할머니(Folk3)가 밖에 빵을 내놓음"),
    D("Shop_Bakery", 9.5, 4, "NEW_BreadBasket", "빵 바구니: 진열대 옆 갓 구운 빵"),
    D("Shop_Bakery", -8, 2.5, "NEW_CafeTable", "작은 탁자: 빵 사서 바로 먹는 자리(뒷골목 안쪽, 길 밖)"),
    D("Shop_Bakery", -11.5, 2, "HaloReasonHQ_BenchA", "빵집 손님 벤치: 탁자 옆에 앉아 빵 먹는 자리", face=(104.9, -455.7)),
    D("Shop_Juice", 7, 3, "HaloReasonHQ_FruitStall", "과일 노점: 주스 아저씨(Folk1)가 짤 과일을 쌓아 둠"),
    D("Shop_Juice", -7.5, 4.5, "NEW_CafeTable", "주스 탁자: 골목 끝에서 주스 마시며 쉬는 자리"),
    D("Shop_Flower", -8, 6, "HaloReasonHQ_FlowerCart", "꽃 수레: 정원 마을에서 받아 온 꽃을 싣고 파는 수레(문 앞 길 반대쪽)", yaw=-15),
    D("Shop_Flower", -3, 2.6, "NEW_WateringCan", "물뿌리개: 꽃 가게 주인이 앞 화분에 물 줌"),
    D("Shop_Flower", -5.0, 1.3, "HaloFlowerPotHQ_Tulip", "파는 화분 줄(튤립): 꽃 가게 앞"),
    D("Shop_Flower", -7.3, 1.8, "HaloFlowerPotHQ_Rose", "파는 화분 줄(장미): 꽃 가게 앞"),
    D("Shop_Flower", -9.6, 1.2, "HaloFlowerPotHQ_Lavender", "파는 화분 줄(라벤더): 꽃 가게 앞"),
    Y("market_corner", -5, -6, "HaloVar4_Planter_D", "뒷골목 모퉁이 화단: 빵집·주스 가게 사이 골목이 꺾이는 곳 표시(주황·흰, 안쪽)"),
    S("시장 끝 꽃 화분 탁자", 0, 0, "NEW_CafeTable", "장 본 사람이 골목을 내려다보며 쉬는 탁자(작은 장면)"),
    S("시장 끝 꽃 화분 탁자", 2.5, 1.5, "HaloVar4_PotFlowers_C", "탁자 위·옆 꽃 화분(작은 장면)"),
    S("시장 끝 꽃 화분 탁자", -3.5, -0.5, "HaloReasonHQ_BenchC", "탁자 벤치: 골목을 보고 앉음", face=(124, -500)),
    # --- 시장 위 언덕 동네: 가게 주인들의 집
    D("House_Hill1", -15, -3, "HaloReasonHQ_Woodpile", "장작더미: 빵집 할머니 집, 빵 굽는 오븐 땔감"),
    D("House_Hill1", 3.6, 1.2, "HaloVar4_PotFlowers_A", "문 앞 화분: 빵집 할머니 집(주황)"),
    A(214, -439, "HaloReasonHQ_Clothesline", "언덕 마당 빨랫줄: 언덕 집 2·3·4가 같이 씀(마당 남쪽, 골목·문 앞 길 밖)", yaw=85),
    D("House_Hill2", -3.4, 1.3, "HaloVar4_PotFlowers_C", "문 앞 화분: 주스 아저씨 집(크림)"),
    D("House_Hill3", 7, 3, "HaloVar3_Planter_E", "약초 화단: 물약 상인이 집에서 약초를 키움"),
    Y("hill_yard", -8.5, 5, "HaloFlowerPotHQ_Sunflower", "언덕 마당 화분: 꽃 가게 주인(언덕 집 4)이 돌봄"),
    Y("hill_yard", -3, 8, "HaloFlowerPotHQ_Tulip", "언덕 마당 화분 둘째: 꽃 가게 주인이 돌봄"),
    W("hill_spring", 200, "NEW_WhiteRock", "언덕 샘 둘레 흰 바위: 물가 자연"),
    S("북동 곶 벤치", 4, 3, "HaloReasonHQ_BenchB", "언덕 동네 사람이 교차로 다리를 보는 벤치(곶 막다른 끝 보상)", face=(0, -300)),
    S("북동 곶 벤치", -7, 4, "HaloReasonHQ_PhotoDisc", "사진 자리: 교차로 다리와 바다가 한 장에(포토존 6곳 중 하나)"),
    A(262, -398, "HaloVar3_RoundTree_F", "북동 곶 가장자리 나무 무리: 섬 끝 자연(벤치 시야 밖, 남쪽)"),
    A(270, -410, "HaloVar3_RoundTree_E", "북동 곶 가장자리 나무 무리(둘째)"),
    A(258, -413, "NEW_FlowerBush", "나무 무리 아래 꽃 덤불(3겹, 규칙 10)"),
    # --- 기사단 훈련장: 첫 기술 시험
    A(-141, -469, "HaloReasonHQ_Scarecrow", "첫 기술 시험 표적 허수아비: 훈련장 표시(-130,-446) 앞 모래 마당", face=(-130, -446)),
    A(-155, -478, "HaloReasonHQ_Scarecrow", "첫 기술 시험 표적 둘째(거리 다르게)", face=(-130, -446)),
    A(-124, -481, "HaloReasonHQ_Scarecrow", "첫 기술 시험 표적 셋째", face=(-130, -446)),
    D("Armory", 5, 1.6, "HaloReasonHQ_RackShieldSword", "방패·칼 걸이: 무기고에서 꺼낸 무기를 바로 들고 연습"),
    D("Armory", -5, 1.8, "NEW_ArmoryBarrels", "무기고 통·상자: 훈련 도구 보관"),
    D("Armory", 3.2, 0.3, "NEW_WallLamp", "무기고 문 오른쪽 벽등: 밤 훈련 때 문 앞을 비춤"),
    D("Armory", -3.2, 0.3, "NEW_WallLamp", "무기고 문 왼쪽 벽등(승인 2D 그대로 문 양옆)"),
    A(-186, -444, "HaloFlagpole_2", "기사단 깃발: 훈련장이 기사단 땅임을 알림(무기고 옆)"),
    S("훈련장 관람 계단", 3, 4, "HaloReasonHQ_BenchC", "훈련 구경 벤치: 허수아비 마당을 봄", face=(-141, -469)),
    S("훈련장 관람 계단", 10, -6, "HaloReasonHQ_BenchA", "훈련 구경 벤치 둘째(각도 다르게)", face=(-141, -469)),
    A(-214, -414, "NEW_FlowerBush", "훈련장 가장자리 낮은 덤불(가운데 비움, 노랑)"),
    A(-232, -452, "NEW_FlowerBush", "훈련장 서쪽 가장자리 낮은 덤불(흰)"),
    # --- 기사단 성
    # (이미지 생성 3 10/12, 최종 검수) 성 C2 골격의 앞마당·계단(문 앞 ~14칸)을 비움: 깃발·정원수 2·벤치를 마당 밖 가장 가까운 빈 땅으로
    D("Castle", 7.3, 19.8, "HaloFlagpole_3", "성 문 깃발: 기사단 본부 표시(문 오른쪽 하나만)"),
    Y("castle_court", -12, 6, "HaloFlagpole_1", "성 앞 마당 깃발: 기사들이 모이는 자리(높이 다르게)"),
    D("Castle", -24.0, 18.5, "HaloVar3_Topiary_C", "성 앞 정원수: 기사단 성의 품위(짝 금지, 왼쪽)"),
    D("Castle", 27.0, 20.9, "HaloVar3_Topiary_D", "성 앞 정원수 둘째(종류·거리 다르게)"),
    Y("castle_court", -3.0, 6.1, "HaloReasonHQ_BenchA", "성 앞 마당 벤치: 교대 기다리는 기사", face=(-160, -522)),
    S("성벽 전망", -3, 7, "HaloReasonHQ_BenchB", "성벽 곁길 끝 바다 전망 벤치(막다른 길 보상)", face=(-330, -566)),
    S("성벽 전망", 3, 6, "HaloReasonHQ_PhotoDisc", "사진 자리: 서쪽 바다와 성벽"),
    S("성벽 전망", -10, 0, "HaloVar3_Balustrade_E", "낭떠러지 난간: 성벽 전망 끝 떨어짐 막이", yaw=90),
    A(-258, -642, "HaloVar3_RoundTree_G", "성벽 아래 나무 무리: 섬 서쪽 가장자리"),
    A(-247, -650, "HaloVar3_RoundTree_E", "성벽 아래 나무 무리(둘째)"),
    A(-266, -630, "NEW_WhiteRock", "나무 무리 아래 흰 바위(3겹)"),
    # --- 분수 광장: 모이는 곳
    A(22, -590, "Town_Halo_Fountain3", "마을 한가운데 분수: 모든 길이 만나는 곳(이름 고정, Config)"),
    A(4, -578, "HaloReasonHQ_BenchC", "분수 보며 쉬는 벤치(광장 = 모이는 곳)", face=(22, -590)),
    A(2, -603, "HaloReasonHQ_BenchA", "분수 보며 쉬는 벤치 둘째(각도 다르게)", face=(22, -590)),
    A(-22, -566, "HaloVar4_Planter_A", "광장 둘레 화단(분홍): 광장 가장자리 표시"),
    A(64, -632, "HaloVar3_Planter_E", "광장 둘레 화단(흰·금): 대성당 큰 계단 앞 갈림"),
    A(-92, -598, "HaloVar3_RoundTree_F", "시냇물 건너편(서쪽) 나무: 광장에서 보면 물 뒤에 심음(규칙 10), 광장 서쪽 경계"),
    # --- 정원 쉼터
    S("폭포 웅덩이 벤치", 0, 0, "HaloReasonHQ_BenchA", "폭포 웅덩이 벤치: 정원 쉼터에서 웅덩이 너머 W2 계단 폭포를 보며 쉼", face=(-38, -699)),
    S("폭포 웅덩이 벤치", -7, -7, "HaloVar3_Topiary_E", "쉼터 정원수: 벤치 뒤 그늘"),
    A(-112, -690, "NEW_Hedge", "쉼터 둘레 생울타리: 정원 쉼터 경계(남서)"),
    A(-104, -652, "NEW_Hedge", "쉼터 둘레 생울타리(북서, 길이 다르게)"),
    A(-36, -650, "HaloVar3_RoundTree_E", "웅덩이 건너편 나무: 물 앞이 아니라 물 뒤(규칙 10)"),
    A(-56, -711, "NEW_FlowerBush", "쉼터 남쪽 가장자리 꽃 덤불(연보라)"),
    W("garden_pool", 250, "NEW_WhiteRock", "웅덩이 가 흰 바위: 폭포 물이 닿는 물가"),
    # --- 정원 마을: 꽃 키우는 사람들
    D("House_Garden1", 10, 6, "HaloReasonHQ_VegGarden", "정원사 집 텃밭: 꽃 가게에 댈 꽃 모종"),
    D("House_Garden1", -3.5, 1.2, "HaloFlowerPotHQ_Sunflower", "문 앞 화분: 정원사 집(해바라기 노랑)"),
    D("House_Garden2", 3.5, 1.4, "HaloFlowerPotHQ_Daisy", "씨앗 받는 화분: 씨앗 모으는 사람 집(데이지)"),
    D("House_Garden2", -5.2, 2.6, "HaloVar3_PotFlowers_F", "씨앗 받는 화분 둘째(자리 다르게)"),
    D("House_Garden3", 5, 2.4, "HaloReasonHQ_RackShieldSword", "물러난 늙은 기사의 낡은 방패 걸이"),
    D("House_Garden3", -8, 6, "HaloReasonHQ_BenchB", "늙은 기사가 바다·성을 보는 벤치", face=(-300, -760)),
    D("House_Garden4", 8, 6, "NEW_Beehive", "벌통: 꽃밭 가운데 벌 치는 사람 집"),
    D("House_Garden4", -3.4, 1.3, "HaloFlowerPotHQ_Lavender", "문 앞 화분: 벌이 좋아하는 라벤더"),
    D("House_Garden5", 6.5, 3, "HaloVar4_Planter_A", "약초 화단: 물약 가게에 댈 약초(서쪽 끝 집)"),
    D("House_Garden6", 3.4, 1.3, "HaloFlowerPotHQ_Tulip", "문 앞 화분: 연못 집"),
    W("garden_pond", 160, "NEW_SteppingStones", "연못 징검다리: 연못 집 사람이 연꽃 돌보러 건너감", out=-2.0),
    W("garden_pond", 40, "NEW_WhiteRock", "연못 가 흰 바위: 물가 자연"),
    D("House_Garden7", -8, 6, "HaloReasonHQ_Clothesline", "이장 집 마당 빨랫줄", yaw=15),
    D("House_Garden7", 5.5, 3, "NEW_NoticeBoard", "마을 알림판: 이장 집 앞(오늘 채집 덤불·행사 알림 자리)"),
    Y("garden_yard", -8, -6, "HaloReasonHQ_VegGarden", "정원 마당 공동 텃밭: 집 2·3·5가 같이 일하는 꽃밭", yaw=10),
    Y("garden_yard", -9, 4, "HaloReasonHQ_Woodpile", "정원 마당 장작더미: 집 2·3·5가 같이 씀"),
    A(-264, -712, "HaloVar3_RoundTree_G", "서쪽 바다 쪽 나무 줄(무리 1): 정원 마을 가장자리"),
    A(-262, -729, "HaloVar3_RoundTree_E", "서쪽 바다 쪽 나무 무리 1 둘째"),
    A(-245, -795, "HaloVar3_RoundTree_F", "남서 모서리 나무 무리 2: 바다 집 뒤"),
    A(-190, -650, "NEW_GatherBush", "채집 덤불 1: 정원 마을 북쪽 가장자리(매일 2~3곳)"),
    A(-262, -760, "NEW_GatherBush", "채집 덤불 2: 서쪽 바닷가"),
    A(-210, -822, "NEW_GatherBush", "채집 덤불 3: 남쪽 바닷가"),
    A(-100, -800, "NEW_GatherBush", "채집 덤불 4: 남동 가장자리"),
    A(-90, -760, "NEW_GatherBush", "채집 덤불 5: 동쪽 가장자리(대성당 언덕 아래)"),
    # --- 대성당 언덕
    Y("cathedral_court", -20, -2, "HaloVar3_Topiary_C", "대성당 앞 정원수(서): 마당 가장자리, 계단 끝 길은 비움(디자인 검수 r2_06)"),
    Y("cathedral_court", 15, -5, "HaloVar3_Topiary_D", "대성당 앞 정원수(동, 거리 다르게)"),
    Y("cathedral_court", 18, 9, "HaloVar3_Topiary_E", "대성당 앞 정원수 셋째"),
    Y("cathedral_court", -13, -7, "HaloReasonHQ_PhotoDisc", "계단 꼭대기 사진 자리: 대성당 정면이 한 장에"),
    D("Cathedral", 9, 2, "NEW_CandleCrate", "초 상자: 초 만드는 사람(절벽 집 5)이 대성당에 댄 초"),
    S("대성당 뒤 바다 전망", 0, 0, "HaloReasonHQ_BenchA", "기도 뒤 조용히 남쪽 바다를 보는 벤치", face=(40, -900)),
    S("대성당 뒤 바다 전망", 0, -7, "HaloVar3_Balustrade_F", "언덕 끝 난간: 남쪽 낭떠러지 떨어짐 막이"),
    W("spring", 300, "NEW_WhiteRock", "대성당 샘 둘레 흰 바위: 시냇물이 시작하는 곳"),
    A(-58, -778, "HaloVar3_RoundTree_G", "언덕 서남 가장자리 나무 무리"),
    A(-52, -797, "HaloVar3_RoundTree_F", "언덕 서남 가장자리 나무 무리(둘째)"),
    # --- 동쪽 절벽 마을: 대성당 일꾼들
    D("House_Cliff1", 5, 1.6, "NEW_BellFrame", "작은 종 걸이: 종지기가 연습하는 종"),
    D("House_Cliff1", -3.6, 1.2, "HaloVar4_PotFlowers_D", "문 앞 화분: 종지기 집(분홍)"),
    D("House_Cliff2", 3.6, 1.3, "HaloFlowerPotHQ_Rose", "문 앞 화분: 성가대 선생님 집(장미)"),
    D("House_Cliff3", 4, 5, "NEW_Easel", "이젤: 바다를 그리는 화가(창이 바다 쪽)", yaw=0),
    D("House_Cliff4", 7, 3, "HaloVar4_Planter_A", "모종 화단: 대성당 정원사가 대성당에 심을 꽃"),
    D("House_Cliff5", 5, 1.6, "NEW_CandleCrate", "초 상자: 촛불 만드는 사람 집, 대성당에 댈 초"),
    D("House_Cliff6", -5, 5, "NEW_Telescope", "망원경: 별 보는 사람 집, 밤하늘을 봄"),
    D("House_Cliff7", 9, 5, "HaloReasonHQ_Clothesline", "빨랫줄: 성가대 아이들 옷", yaw=-10),
    D("House_Cliff8", 5, 1.6, "NEW_WaterBuckets", "물통·갈퀴: 폭포지기가 W3 물길을 돌봄"),
    Y("cliff_yard", -3, -7, "HaloVar4_Planter_D", "절벽 위 마당 화단(분홍·흰): 집 3·8 앞"),
    Y("cliff_landing", -6, 4, "HaloReasonHQ_BenchB", "비탈 쉼참 벤치: 절벽 비탈 오르다 쉬는 자리", face=(100, -600)),
    S("절벽 마을 발코니", 4, -3, "HaloReasonHQ_BenchC", "절벽 위 단 사람들이 동쪽 바다와 남쪽 W3 폭포를 보는 벤치", face=(330, -640)),
    S("절벽 마을 발코니", 9, -2, "HaloVar4_Balustrade_A", "절벽 끝 난간: 떨어짐 막이", yaw=90),
    W("cliff_pool", 210, "NEW_WhiteRock", "W3 폭포 위 웅덩이 흰 바위: 물가 자연"),
    A(272, -582, "HaloVar3_RoundTree_E", "동쪽 절벽 발치 나무 무리: 섬 가장자리"),
    A(264, -567, "HaloVar3_RoundTree_G", "동쪽 절벽 발치 나무 무리(둘째)"),
    A(276, -598, "NEW_WhiteRock", "절벽 발치 흰 바위(나무 무리 아래 층)"),
    # --- 동남 전망대
    Y("lookout_yard", -5, -5, "HaloReasonHQ_BenchB", "탑 오르기 전 쉬는 벤치: 마을 쪽을 봄", face=(80, -620)),
    S("전망 탑 꼭대기", 0, 0, "HaloReasonHQ_PhotoDisc", "전망 탑 꼭대기 사진 자리: 광장·대성당·바다", top=True),
    A(205, -822, "HaloVar4_Balustrade_C", "전망대 남쪽 끝 난간: 낭떠러지 떨어짐 막이", yaw=180),
]


# ---------------------------------------------------------------- resolve
def _scale(i):
    # deterministic 0.87..1.15 (rule 11), no two neighbours equal
    return round(0.87 + ((i * 37) % 29) / 28 * 0.28, 2)


def _jit(i):
    return ((i * 53) % 31) - 15  # -15..15 deg (rule 11, things that look at the path)


def resolve(H, blds, lamps):
    B = {b["id"]: b for b in blds}
    Yd = {y["id"]: y for y in H.YARDS}
    Sc = {n: at for n, at, _ in H.SCENES}
    Pl = {p["id"]: p for p in H.WATER["pools"]}
    out = []
    for i, s in enumerate(SPEC):
        fr, ref, (a1, a2) = s["frame"], s["ref"], s["off"]
        yaw = s.get("yaw", 0)
        anchor = ref
        if fr == "door":
            b = B[ref]
            yw = math.radians(b["yaw"])
            fx, fz = math.sin(yw), math.cos(yw)
            rx, rz = fz, -fx
            x, z = b["door_at"][0] + rx * a1 + fx * a2, b["door_at"][1] + rz * a1 + fz * a2
            yaw = b["yaw"] + s["yaw_rel"]
        elif fr == "yard":
            x, z = Yd[ref]["at"][0] + a1, Yd[ref]["at"][1] + a2
        elif fr == "scene":
            x, z = Sc[ref][0] + a1, Sc[ref][1] + a2
        elif fr == "pool":
            p = Pl[ref]
            r = p["r"] + a2 + kit_cat(s["kit"])[1] * 0.5
            x, z = p["at"][0] + math.sin(math.radians(a1)) * r, p["at"][1] + math.cos(math.radians(a1)) * r
            yaw = a1 + 180
        else:
            x, z = a1, a2
            anchor = None
        if s.get("face"):
            yaw = math.degrees(math.atan2(s["face"][0] - x, s["face"][1] - z))
        cat, rad, h = kit_cat(s["kit"])
        if cat in ("bench", "lamp") or "Balustrade" in s["kit"] or "Planter" in s["kit"]:
            yaw += _jit(i) * 0.4  # small wobble, still looks at its target
        out.append(dict(kit=s["kit"], cat=cat, at=[round(x, 1), round(z, 1)], yaw=round(yaw % 360), scale=_scale(i), r=rad, h=h,
                        anchor=(fr + ":" + str(anchor)) if anchor else "abs", why=s["why"], top=s.get("top", False)))
    # auto lamps (rule 6) become props with their reason (the road or yard they light)
    kits = ["HaloVar4_Lantern_A", "HaloVar4_Lantern_C", "HaloVar4_Lantern_B", "HaloVar3_Lantern_E", "HaloVar4_Lantern_D"]
    for j, (x, z, src) in enumerate(lamps):
        r = next((r for r in H.ROADS if r["id"] == src), None)
        if r:
            why = f"밤 길 등불: {r['name']}(사람이 다니는 길)"
        else:
            y = Yd.get(src)
            why = f"마당 등불: {y['note']}(모이는 곳)" if y else ""
        out.append(dict(kit=kits[(j * 3) % 5], cat="lamp", at=[x, z], yaw=round((_jit(j + 7)) % 360), scale=_scale(j + 101), r=0.8, h=7,
                        anchor=("road:" if r else "yard:") + src, why=why, top=False, auto=True))
    # 이미지 생성 3 10/12 (최종 검수): the castle C2 skeleton has a front plaza ~14 studs out of the plan footprint; the auto
    # lamp the plaza_castle road put on it goes to the nearest free ground
    for p in out:
        if p.get("auto") and p["at"] == [-135.8, -548.5]:
            p["at"] = [-130.7, -554.6]
    for p in out:
        p["district"] = next((dd["id"] for dd in H.DISTRICTS if H.inside(tuple(p["at"]), dd["poly"])), None)
        dd = H.DIST.get(p["district"]) if p["district"] else None
        p["ground_y"] = dd["y"] if dd else None
        # edge props (land between districts) are listed with the nearest district
        p["zone"] = p["district"] or min(H.DISTRICTS, key=lambda q: min(
            H.seg_dist(tuple(p["at"]), q["poly"][i], q["poly"][(i + 1) % len(q["poly"])]) for i in range(len(q["poly"]))))["id"]
    # number per district in the table order (lamps get their own L numbers)
    order = [dd["id"] for dd in H.DISTRICTS] + [None]
    n = 0
    for dname in order:
        for p in out:
            if p["zone"] == dname and not p.get("auto"):
                n += 1
                p["id"] = f"P{n:03d}"
    k = 0
    for p in out:
        if p.get("auto"):
            k += 1
            p["id"] = f"L{k:02d}"
    out.sort(key=lambda p: (p["id"][0] != "P", p["id"]))
    return out


# ---------------------------------------------------------------- checks



def fixed_spots(H):
    """the fixed bodies from the plan's final fixed points (review 10/11: this list was hard-coded with old spots); the two
    travel pads are boxes (결정 5: 12 x 12 + 2 kept clear), checked apart"""
    out = [("Bright", (18, -424), 2.5), ("TrainingMark", (-130, -446), 3)]
    for name, _now, new, _c in H.FIXED_MOVE:
        if new and (name.startswith(("영웅상", "Sir Gleam", "물약 상인", "Folk"))):
            out.append((name.split()[-1] if name.startswith("영웅상") else name, (new[0], new[2]), 4 if name.startswith("영웅상") else 2.5))
    return out


def check(H, blds, props):
    msgs = []
    FIXED_SPOTS = fixed_spots(H)
    pads = [(n, H.pad_box(c)) for n, c in H.PADS]
    known = kit_names() | set(NEW_KITS) | set(EXISTING)
    fps = [(b, H.footprint(b)) for b in blds]

    def fp_dist(pt, fp):
        if H.inside(pt, fp):
            return -1.0
        return min(H.seg_dist(pt, fp[i], fp[(i + 1) % 4]) for i in range(4))

    def road_d(pt, r):
        return min(H.seg_dist(pt, r["pts"][i], r["pts"][i + 1]) for i in range(len(r["pts"]) - 1))

    def water_d(pt):
        st = H.WATER["stream"]
        d = min(H.seg_dist(pt, st[i], st[i + 1]) - H.WATER["stream_w"][i] / 2 for i in range(len(st) - 1))
        for w in H.WATER["pools"]:
            d = min(d, math.hypot(pt[0] - w["at"][0], pt[1] - w["at"][1]) - w["r"])
        return d

    def edge_d(pt, poly):
        return min(H.seg_dist(pt, poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly)))

    for p in props:
        pt, tag, r = tuple(p["at"]), f"{p['id']} {p['kit']}", p["r"]
        if not p["why"]:
            msgs.append(f"이유 없음: 소품 {tag}")
        if p["kit"] not in known:
            msgs.append(f"키트 이름 모름: {tag}")
        if not H.inside(pt, H.LAND):
            msgs.append(f"소품 땅 밖: {tag}")
        if not p["top"]:
            for b, fp in fps:
                if fp_dist(pt, fp) < r * 0.6:
                    msgs.append(f"소품이 건물에 박힘: {tag} - {b['id']}")
        if abs(pt[0]) <= 12 + r and -432 <= pt[1] <= -330 or math.hypot(pt[0], pt[1] + 420) < 12 + r:
            msgs.append(f"소품이 스폰-문 통로에: {tag}")
        wd = water_d(pt)
        if p["kit"] not in ("NEW_WhiteRock", "NEW_SteppingStones", "Town_Halo_Fountain3") and wd < r * 0.5:
            msgs.append(f"소품 물 위: {tag}")
        if not p["top"] and p["kit"] not in ("Town_Halo_Fountain3",) and "PhotoDisc" not in p["kit"]:
            for rd in H.ROADS:
                lim = rd["w"] / 2 + (r * 0.5 if rd["grade"] <= 2 else r * 0.3)
                if p["cat"] == "lamp":
                    lim = rd["w"] / 2 + 0.3
                if road_d(pt, rd) < lim:
                    msgs.append(f"소품이 길 막음: {tag} - {rd['id']} ({road_d(pt, rd):.1f} < {lim:.1f})")
        # A23-117 placement rules per kind
        near_road = any(road_d(pt, rd) <= rd["w"] / 2 + 5 for rd in H.ROADS)
        near_yard = any(math.hypot(pt[0] - y["at"][0], pt[1] - y["at"][1]) <= y["r"] + 4 for y in H.YARDS)
        near_door = any(math.hypot(pt[0] - b["door_at"][0], pt[1] - b["door_at"][1]) <= 12 for b in blds)
        near_scene = any(math.hypot(pt[0] - a[0], pt[1] - a[1]) <= 10 for _, a, _ in H.SCENES)
        if p["cat"] == "lamp" and not (near_road or near_yard or near_door or p["district"] in ("plaza", "arrival")):
            msgs.append(f"등불이 길·모이는 곳 아님: {tag}")
        near_statue = math.hypot(pt[0] + 34, pt[1] + 388) <= 10
        if p["cat"] == "pot" and not (near_road or near_yard or near_door or near_scene or near_statue or p["district"] == "plaza"):
            msgs.append(f"화분·화단이 집·가게·길 앞 아님: {tag}")
        if p["cat"] == "nature":
            de = edge_d(pt, H.LAND)
            dd = edge_d(pt, H.DIST[p["district"]]["poly"]) if p["district"] else 0
            if not (de <= 35 or dd <= 12 or wd <= 10):
                msgs.append(f"숲·덤불이 가장자리 아님: {tag} (섬 끝 {de:.0f}, 구역 끝 {dd:.0f}, 물 {wd:.0f})")
        if p["h"] > 4.5 and p["cat"] != "lamp" and p["kit"] not in EXISTING:
            for rd in H.ROADS:
                if rd["id"] == "main" and road_d(pt, rd) - rd["w"] / 2 < 4:
                    msgs.append(f"큰길 4 안에 키 큰 것: {tag} (규칙 10)")
        for name, at, fr in FIXED_SPOTS:
            if math.hypot(pt[0] - at[0], pt[1] - at[1]) < (r + fr) * 0.9 and not p["top"]:
                msgs.append(f"소품이 고정점에 겹침: {tag} - {name}")
        for name, box in pads:
            if fp_dist(pt, box) < r:
                msgs.append(f"소품이 이동 발판 둘레에: {tag} - {name}")
    # props on props
    for i in range(len(props)):
        for j in range(i + 1, len(props)):
            a, b = props[i], props[j]
            if a["top"] or b["top"]:
                continue
            dd = math.hypot(a["at"][0] - b["at"][0], a["at"][1] - b["at"][1])
            if dd < (a["r"] + b["r"]) * 0.8:
                msgs.append(f"소품끼리 겹침: {a['id']} {a['kit']} - {b['id']} {b['kit']}")
            elif "lamp" in (a["cat"], b["cat"]) and "WallLamp" not in a["kit"] + b["kit"] and dd < a["r"] + b["r"] + 1.0:
                # 디자인 검수 10/11 (r2_04): a lamp post keeps its full base radius + 1 clear of any prop
                msgs.append(f"등불이 소품에 붙음: {a['id']} {a['kit']} - {b['id']} {b['kit']} ({dd:.1f})")
    # mirror pairs at a door: same kit, same distance out, opposite sides (wall lamps beside a door are the approved 2D)
    for b in blds:
        yw = math.radians(b["yaw"])
        fx, fz = math.sin(yw), math.cos(yw)
        loc = []
        for p in props:
            dx, dz = p["at"][0] - b["door_at"][0], p["at"][1] - b["door_at"][1]
            if math.hypot(dx, dz) < 14 and p["kit"] != "NEW_WallLamp":
                loc.append((p, dx * fz - dz * fx, dx * fx + dz * fz))
        for i in range(len(loc)):
            for j in range(i + 1, len(loc)):
                (p, r1, f1), (q, r2, f2) = loc[i], loc[j]
                if p["kit"] == q["kit"] and abs(r1 + r2) < 1.5 and abs(f1 - f2) < 1.5 and abs(r1) > 1:
                    msgs.append(f"문 앞 거울 짝: {p['id']} - {q['id']} ({b['id']})")
    # rule 11: at most 5 of one kit inside any 40 x 40 window
    seen = set()
    for p in props:
        same = [q for q in props if q["kit"] == p["kit"] and abs(q["at"][0] - p["at"][0]) <= 20 and abs(q["at"][1] - p["at"][1]) <= 20]
        if len(same) > 5 and p["kit"] not in seen:
            seen.add(p["kit"])
            msgs.append(f"같은 소품 40×40 안 {len(same)}개: {p['kit']} (규칙 11, ≤5)")
    return msgs


# ---------------------------------------------------------------- the prop map (검수 10/11: 평면도에 소품 점 + 번호 -> 이유 표)
CAT_COL = {"lamp": (255, 205, 60), "bench": (150, 90, 40), "pot": (235, 90, 150), "nature": (60, 150, 70), "item": (60, 110, 210)}
CAT_KO = {"lamp": "등불", "bench": "벤치", "pot": "화분·화단", "nature": "나무·덤불·바위", "item": "이유 소품"}


def draw(H, blds, props, issues):
    S3 = 3.0
    pad = 50
    minx, maxx = H.MINX, H.MAXX
    minz, maxz = H.MINZ, H.MAXZ
    mw = int((maxx - minx) * S3) + pad * 2
    mh = int((maxz - minz) * S3) + pad * 2 + 40
    panel = 1500
    im = Image.new("RGB", (mw + panel, max(mh, 2300)), (150, 200, 230))
    d = ImageDraw.Draw(im, "RGBA")

    def P(x, z):
        return (pad + (x - minx) * S3, pad + 40 + (maxz - z) * S3)

    d.polygon([P(*q) for q in H.LAND], fill=(246, 240, 214), outline=(110, 96, 70))
    for dd in H.DISTRICTS:
        d.polygon([P(*q) for q in dd["poly"]], fill=dd["color"] + (150,), outline=(110, 100, 80, 255), width=2)
    st = H.WATER["stream"]
    for i in range(len(st) - 1):
        d.line([P(*st[i]), P(*st[i + 1])], fill=(80, 160, 215), width=int(H.WATER["stream_w"][i] * S3))
    for w in H.WATER["pools"]:
        cx, cy = P(*w["at"])
        rr = w["r"] * S3
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(80, 160, 215))
    for r in H.ROADS:
        col = {1: (255, 255, 250, 255), 2: (236, 226, 200, 255), 3: (222, 210, 180, 230)}[r["grade"]]
        for i in range(len(r["pts"]) - 1):
            d.line([P(*r["pts"][i]), P(*r["pts"][i + 1])], fill=col, width=max(2, int(r["w"] * S3)))
    for y in H.YARDS:
        cx, cy = P(*y["at"])
        rr = y["r"] * S3
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(222, 210, 180), outline=(150, 130, 100))
    for b in blds:
        d.polygon([P(*q) for q in H.footprint(b)], fill=(255, 255, 255, 235), outline=(70, 60, 50), width=2)
        a = P(*b["door_at"])
        yw = math.radians(b["yaw"])
        e = P(b["door_at"][0] + math.sin(yw) * 5, b["door_at"][1] + math.cos(yw) * 5)
        d.line([a, e], fill=(200, 40, 40), width=4)
        cx, cy = P(b["x"], b["z"])
        f = H.font(12)
        t = b["id"].replace("House_", "").replace("Shop_", "").replace("Tower_", "")
        bb = d.textbbox((0, 0), t, font=f)
        d.text((cx - (bb[2] - bb[0]) / 2, cy - 8), t, fill=(90, 80, 70), font=f)
    for dd in H.DISTRICTS:
        xs = [q[0] for q in dd["poly"]]
        zs = [q[1] for q in dd["poly"]]
        cx, cy = P(min(xs) + 4, max(zs) - 2)
        d.text((cx, cy), dd["name"], fill=(60, 50, 40, 200), font=H.font(15, True))
    # props: dot then number label placed greedily so labels do not overlap
    taken = []
    fnum = H.font(12, True)
    for p in props:
        cx, cy = P(*p["at"])
        col = CAT_COL[p["cat"]]
        rr = 3 if p["cat"] == "lamp" else 5
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=col, outline=(30, 30, 30), width=1)
        if p["cat"] == "lamp":
            continue
        t = p["id"][1:].lstrip("0")
        bb = d.textbbox((0, 0), t, font=fnum)
        tw, th = bb[2] - bb[0] + 4, bb[3] - bb[1] + 4
        best = None
        for ring in (9, 16, 24, 33, 44):
            for ang in range(0, 360, 30):
                lx = cx + math.cos(math.radians(ang)) * ring - tw / 2
                ly = cy + math.sin(math.radians(ang)) * ring - th / 2
                box = (lx, ly, lx + tw, ly + th)
                if all(box[2] < o[0] or box[0] > o[2] or box[3] < o[1] or box[1] > o[3] for o in taken):
                    best = box
                    break
            if best:
                break
        if not best:
            best = (cx + 6, cy - 6, cx + 6 + tw, cy - 6 + th)
        taken.append(best)
        bx, by = (best[0] + best[2]) / 2, (best[1] + best[3]) / 2
        if math.hypot(bx - cx, by - cy) > 12:
            d.line([(cx, cy), (bx, by)], fill=(40, 40, 40, 160), width=1)
        d.rounded_rectangle(best, 3, fill=(255, 255, 255, 235), outline=col + (255,), width=2)
        d.text((best[0] + 2, best[1] + 1), t, fill=(20, 20, 20), font=fnum)
    n_auto = sum(1 for p in props if p.get("auto"))
    d.text((pad, 10), f"빛 마을 5단계 소품 지도 (A23-117 이유 칸)  ·  소품 {len(props) - n_auto} + 등불 {n_auto}  ·  번호 = 오른쪽 표  ·  "
                      f"검사 문제 {len(issues)}건  ·  빨간 선 = 문 방향", fill=(20, 40, 70), font=H.font(18, True))
    lx = pad
    for cat in ("item", "bench", "pot", "nature", "lamp"):
        d.ellipse([lx, 38, lx + 12, 50], fill=CAT_COL[cat], outline=(30, 30, 30))
        d.text((lx + 16, 34), CAT_KO[cat], fill=(20, 40, 70), font=H.font(14, True))
        lx += 140
    # table: district -> numbered props with why (two columns), then lamps per district, NEW kits
    x0, y = mw + 12, 10
    d.rectangle([mw, 0, mw + panel, im.size[1]], fill=(250, 248, 242))
    colw = panel // 2 - 10
    ft, fb = H.font(12), H.font(14, True)
    col_x = [mw + 12, mw + 12 + colw + 8]
    ci = 0
    y = 12
    names = {dd["id"]: dd["name"] for dd in H.DISTRICTS}
    order = [dd["id"] for dd in H.DISTRICTS] + [None]
    limit = im.size[1] - 20
    for dname in order:
        items = [p for p in props if p["zone"] == dname and not p.get("auto")]
        lamps = [p for p in props if p["zone"] == dname and p.get("auto")]
        if not items and not lamps:
            continue
        if y + 40 > limit:
            ci, y = ci + 1, 12
        d.text((col_x[ci], y), f"{names.get(dname, '구역 사이 땅')}  (소품 {len(items)}, 등불 {len(lamps)})", fill=(25, 25, 25), font=fb)
        y += 20
        for p in items:
            if y + 16 > limit:
                ci, y = ci + 1, 12
            kit = p["kit"].replace("HaloReasonHQ_", "").replace("HaloFlowerPotHQ_", "Pot_").replace("HaloVar4_", "").replace("HaloVar3_", "").replace("Halo", "")
            ln = f"{p['id'][1:].lstrip('0'):>3}. {kit}: {p['why']}"
            while d.textlength(ln, font=ft) > colw - 12:
                ln = ln[:-2]
            if ln != f"{p['id'][1:].lstrip('0'):>3}. {kit}: {p['why']}":
                ln = ln[:-1] + "…"
            d.ellipse([col_x[ci], y + 4, col_x[ci] + 8, y + 12], fill=CAT_COL[p["cat"]])
            d.text((col_x[ci] + 12, y), ln, fill=(160, 40, 40) if p["kit"].startswith("NEW_") else (45, 45, 45), font=ft)
            y += 16
        y += 6
    if y + 120 > limit:
        ci, y = min(ci + 1, 1), 12
    d.text((col_x[ci], y), "새로 만들 키트 (빨간 글씨, 이미지 생성 2D → 4면 → Tripo → Blender)", fill=(160, 40, 40), font=fb)
    y += 20
    cnt = {}
    for p in props:
        if p["kit"].startswith("NEW_"):
            cnt[p["kit"]] = cnt.get(p["kit"], 0) + 1
    for k, v in sorted(cnt.items(), key=lambda kv: -kv[1]):
        d.text((col_x[ci] + 8, y), f"{NEW_KITS[k][0]} ×{v}", fill=(90, 40, 40), font=ft)
        y += 16
    y += 6
    d.text((col_x[ci], y), f"등불 {n_auto}개 = 큰 길·2등급 길 25~40칸마다·굽이 바깥·마당마다 1 (규칙 6), 이유 = 그 길·마당", fill=(25, 25, 25), font=ft)
    y += 18
    d.text((col_x[ci], y), "검사: " + ("문제 0건" if not issues else f"{len(issues)}건 — plan json checks.issues"), fill=(25, 25, 25), font=fb)
    return im
