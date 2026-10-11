# 빛 마을 소품 나누기 — 파트 생성기 / Tripo (이미지 생성 4, 2026-10-11)

- 출처: plan `dressing.props` 185개(64종) = P 129 + 자동 등불 L 56. 2D: `art/review/s2/halo_reason_props_4views.jpg`·`halo_lanterns_4views.jpg`·`halo_bench_tree_topiary_4views.jpg`·`halo_flowerpots_4views.jpg`·`halo_variants4_sheet.jpg`·`halo_flagpoles_sheet.jpg`·`halo_newkits_front_cands.jpg`.
- 규칙: A23-120(단순한 덩어리 = Studio 파트), A23-122/125(복잡한 것 = 4면 Tripo → Blender → Roblox 재질). 동그란 것은 Roblox 원통·공(정확한 원)으로.

## (가) 전부 Studio 파트 — `tools/prop_kit.py` — 31종 102개

| 키 | 개수 | 이유 |
|---|---|---|
| `HaloReasonHQ_BenchA` | 6 | 대리석 받침·나무 판 4장·금 공 — 상자·원통·공 |
| `HaloReasonHQ_BenchC` | 4 | 등받이 없는 판 + 받침 2개 |
| `HaloVar4_Balustrade_A` | 1 | 기둥 2 + 둥근 난간동자(원통·공 쌓기) + 갓돌 |
| `HaloVar4_Balustrade_C` | 1 | 꺾인 난간(두 칸) |
| `HaloVar3_Balustrade_E` | 1 | 난간 |
| `HaloVar3_Balustrade_F` | 1 | 난간 |
| `HaloFlagpole_1` | 2 | 네모 받침·둥근 기둥·금 팔·공 꼭지 |
| `HaloFlagpole_2` | 1 | 둥근 받침 원판·가는 기둥·공+뾰족 꼭지 |
| `HaloFlagpole_3` | 1 | 굵은 네모 기둥·양팔 공 3 |
| `HaloReasonHQ_PhotoDisc` | 4 | 납작 원판 + 금 테 |
| `HaloReasonHQ_GuardPost` | 1 | 원통 몸·반구 돔(공을 몸에 묻음)·줄무늬 차양·표지판 |
| `HaloReasonHQ_Woodpile` | 2 | 박공 헛간 + 통나무(원통) 쌓기 |
| `HaloReasonHQ_Clothesline` | 3 | 기둥 2·줄·수건(얇은 천 판, 줄무늬)·바구니 상자 |
| `HaloReasonHQ_RackShieldSword` | 2 | 틀·칼(판+쐐기)·둥근 방패(원판+금 테)·작은 깃발 천 |
| `Town_Halo_Fountain3` | 1 | 둥근 수반 2단(원통)·금 테·모서리 공 기둥 4, 물 = 유리 원판 + 파티클 |
| `NEW_CafeTable` | 3 | 둥근 상판·가운데 기둥·받침 원판 |
| `NEW_CandleCrate` | 2 | 나무 상자 + 금 모서리 + 흰 초(원통) |
| `NEW_ArmoryBarrels` | 1 | 통 2(원통 + 금 띠) + 상자 1 |
| `NEW_Beehive` | 1 | 흰 상자 2단 + 작은 박공 지붕 + 다리 |
| `NEW_NoticeBoard` | 1 | 기둥 2 + 판 + 작은 지붕 |
| `NEW_Easel` | 1 | 세 다리 + 캔버스(색면 파트 몇 장) |
| `NEW_Telescope` | 1 | 세 다리 + 원통 경통 + 금 띠 |
| `NEW_WaterBuckets` | 1 | 나무 통 2(원통 + 띠) + 긴 갈퀴 |
| `NEW_SteppingStones` | 1 | 납작 돌 5~6(원통·크기 다르게) |
| `NEW_WallLamp` | 2 | 벽 판 + 팔 + 유리 등 상자 + 금 틀, 밤 PointLight |
| `NEW_BellFrame` | 1 | 대리석 기둥 2 + 나무 들보 + 작은 금 종(원통·공 겹침) |
| `HaloVar4_Lantern_A` | 12 | 기둥·받침 = 파트, 등 머리 = 유리 + 금 틀 파트(아래 질문 1) |
| `HaloVar4_Lantern_B` | 11 | 받침 상자 + 유리 공 + 금 띠 |
| `HaloVar4_Lantern_C` | 11 | 굽은 팔 등불 |
| `HaloVar4_Lantern_D` | 11 | 양팔 등불 |
| `HaloVar3_Lantern_E` | 11 | 받침 + 돔 등(반구 묻기) |

## (가+나) 몸통은 파트, 식물·작은 물건만 Tripo — 27종 61개

| 키 | 개수 | 이유 |
|---|---|---|
| `HaloFlowerPotHQ_Daisy` | 2 | 팔각 화분 = 파트 / 꽃 = Tripo |
| `HaloFlowerPotHQ_Tulip` | 3 | 네모 화분 = 파트 / 꽃 |
| `HaloFlowerPotHQ_Sunflower` | 2 | 통 화분(원통 + 금 띠) = 파트 / 꽃 |
| `HaloFlowerPotHQ_Rose` | 2 | 둥근 그릇 = 파트(CSG 공 자르기) / 꽃 |
| `HaloFlowerPotHQ_Lavender` | 2 | 항아리 = 파트(늘린 공 + 원통) / 꽃 |
| `HaloVar4_PotFlowers_A` | 2 | 그릇 = 파트 / 꽃 |
| `HaloVar4_PotFlowers_C` | 2 | 잔 모양 항아리 = 파트 / 꽃 |
| `HaloVar4_PotFlowers_D` | 1 | 넓은 그릇 = 파트 / 꽃 |
| `HaloVar3_PotFlowers_E` | 1 | 화분 = 파트 / 꽃 |
| `HaloVar3_PotFlowers_F` | 1 | 항아리 = 파트 / 담쟁이 |
| `HaloVar4_Planter_A` | 3 | 네모 화단 = 파트 / 덤불 |
| `HaloVar4_Planter_D` | 2 | 팔각 화단 = 파트 / 원뿔 나무 |
| `HaloVar3_Planter_E` | 2 | 탑 화단 = 파트 / 덤불 |
| `HaloVar3_RoundTree_E` | 6 | 둥근 화단(원통 + 금 테) = 파트 / 나무(열매) |
| `HaloVar3_RoundTree_F` | 5 | 화단 = 파트 / 늘어진 나무 |
| `HaloVar3_RoundTree_G` | 5 | 화단 = 파트 / 둥근 나무 |
| `HaloVar3_Topiary_C` | 2 | 화분 = 파트 / 공 3단 잎 |
| `HaloVar3_Topiary_D` | 2 | 팔각 화분 = 파트 / 나선 잎 |
| `HaloVar3_Topiary_E` | 2 | 화분 = 파트 / 네모 잎 |
| `HaloReasonHQ_BenchB` | 5 | 벤치·둥근 화단 = 파트 / 꽃 |
| `HaloReasonHQ_VegGarden` | 2 | 대리석 밭 = 파트 / 채소·물뿌리개 |
| `HaloReasonHQ_BreadStand` | 1 | 진열대·선반·천 = 파트 / 빵 |
| `HaloReasonHQ_FruitStall` | 1 | 가게·차양·상자·과일(공) = 파트 / 양옆 꽃 덤불 |
| `HaloReasonHQ_FlowerCart` | 1 | 수레·바퀴·차양 = 파트 / 꽃 |
| `HaloReasonHQ_PotionCrate` | 1 | 상자·병(유리 공 + 원통)·간판 = 파트 / 담쟁이 꽃 |
| `NEW_Hedge` | 2 | 2D는 대리석 화단 위 울타리: 화단 = 파트 / 덤불 |
| `NEW_Cauldron` | 1 | 돌 받침 = 파트, 솥 = CSG(공 − 윗면) 먼저 시도, 안 되면 Tripo |

## (나) 전부 Tripo 4면 — 6종 22개

| 키 | 개수 | 이유 |
|---|---|---|
| `HaloReasonHQ_Scarecrow` | 3 | 천 옷·짚 머리 — 파트로 안 됨 |
| `NEW_WhiteRock` | 8 | 자연 바위 3종(a·b·c) |
| `NEW_GatherBush` | 5 | 꽃 덤불 + 빛나는 열매(2D는 대리석 받침 → 받침만 파트 가능) |
| `NEW_FlowerBush` | 4 | 꽃 덤불(연보라·흰·노랑) |
| `NEW_BreadBasket` | 1 | 버들 짜임 + 빵 |
| `NEW_WateringCan` | 1 | 굽은 주둥이·손잡이 |

## (나) Tripo 묶음 메모
- 식물만 쓰는 것은 이미 있는 4면 2D(화분·나무·토피어리·이유 소품)로 Tripo 통째 → Blender에서 식물만 남김(skeleton_keep 방식) → 손보기·맵 굽기. 새 4면 2D가 필요한 것: NEW_ 6종(+ Hedge·Cauldron 받침 위 부분).
- 유료 묶음은 범위·개수 따로 검수에 보냄(아직 안 씀).
