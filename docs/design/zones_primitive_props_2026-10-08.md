# 사냥터·길가 옛 모양(원시 파트) 소품 목록 (이미지 생성 1, 2026-10-08)

검수 요청(10/08): "사냥터 나머지(해골 폐허·유령 숲·고갯길 밖·고블린 숲 중 키트 안 들어간 곳)와 교차로 바깥 길가 — 원시 파트 소품 목록 + 이미 있는 3D 짝. 새로 만들 게 있으면 범위·포인트 먼저."

- **출처:** `place/GoodEvil.rbxlx`(메인 10/07 22:39, 38e8a9a). 도구 `tools/town_props_scan.py --zones all`(읽기만, 존 상자 = Config.Zones 지도 v2. 어느 존에도 안 들면 Outskirts = 길가·다리·고갯길). 투명 계약 파트는 뺌. 초원·두 마을은 앞 문서(`towns_primitive_props_2026-10-08.md`, 초원 키트)라 뺌.
- **요약:** 유령 숲(20)·고갯길 바위(70)·바다 바위(26)·고블린 숲 키트(197)는 이미 3D. **원시 파트가 크게 남은 곳 = 해골 폐허 전부, 호박밭 전부, 관문 4개, 다리 4개.**

## 1. 존별 원시 파트 → 3D 짝

| 존 | 이름(메인) | 개수 | 자리 | 지금 모양 | 3D 짝 | 상태 / 할 일 |
|---|---|---|---|---|---|---|
| 해골 폐허 | Map.Decor 낱개 Tombstone | 16 | x 1404~1696, z -213~246 흩어짐 | 회색 3 × 4 × 1 판 | **Kit_R_StoneMarker**(둥근 머리 이정표, 글자·얼굴·십자 없음) | 고급 2D 있음(`art/out/kit/ruins/StoneMarker_C_HQ.png`), **3D 없음** |
| 해골 폐허 | Map.Decor 낱개 BrokenPillar | 17 | x 1337~1724, z -224~248 | 4 × 4 기둥 높이 5~18 | **Kit_R_PillarA / PillarB** (+ PillarFallen) | 고급 2D 있음, 3D 없음 |
| 해골 폐허 | Map.Decor.BrokenArch | 3 | (1483~1672, -122~138) — 퀘스트 M4-2 자리 | 기둥 2 + 머리돌 | **R_Arch_A / R_Arch_B** | 고급 2D 있음(`art/out/hq/HQ_R_Arch_*.png`), 3D 없음 — 계약: 퀘스트 자리 |
| 해골 폐허 | Map.Decor 낱개 TornFlag + TornPole | 4 + 4 | x 1476~1699, z -66~70 길 양옆 | 보라 판 + 막대 | **Kit_R_Banner** | 2D 중간만(`Banner.png`) → 고급 5 필요, 3D 없음 |
| 해골 폐허 | Map.Decor 낱개 SoulWisp | 6 | x 1408~1726 | 보라 빛 공(PointLight 6) | **Kit_R_SpiritBowl**(돌 그릇) + 빛은 그대로 | 고급 2D 있음, 3D 없음 — 빛(PointLight) 계약 유지 |
| 해골 폐허 | Map.Gates.Gate_SkeletonRuins | 1 | (1260, 0) | 흰 기둥 2 + 상인방 + **해골 12 + 해골 눈 2 + 턱** | **R_Gate**(무너진 성문, 얼굴 없음) | 고급 2D 있음, 3D 없음 — 해골 얼굴은 kit_ruins 규칙(얼굴·해골 없음)에 어긋남 → 바꾸길 추천. 상인방 계약 유지 |
| 해골 폐허 | Map.Decor.PvPBorder_1260 | 말뚝 10 + 빨간 끝 10 + 띠 | x 1262, z -60~60 | 나무 말뚝 + 빨강 | (그대로) | 빨강 = 극한 PvP 표시 계약 — 바꾸지 않음 |
| 고블린 숲 | Map.Gates.Gate_GoblinWoods | 1 | (710, 0) | 나무 기둥 2 + 창 2 + 상인방 + 토템 + **토템 눈** | **W_Gate** + W_Totem | **업로드됨**(숲 키트) — 배치만. 상인방 계약 유지 |
| 고블린 숲 | Map.Decor 낱개 DarkBush + RedEye | 6 + 12 | x 962~1119, z -194~37 | 짙은 초록 5 정육면체 + 빨간 눈 2개씩 | Kit_X_Bush(C2) 또는 Kit_M_BushB를 어둡게 칠한 판(0) | **빨간 눈 = 소품 얼굴(규칙 위반)** → 눈은 빼기, 덤불만 바꾸기 |
| 고블린 숲 | WoodsKit 안 남은 Log + Embers | 6 + 3 | 캠프 3곳 (840~1090, -150~130) | 통나무 막대 + 주황 판 | **Kit_W_Campfire**(업로드됨) + Kit_W_Campfire_Fire(가져오기 E) | 배치만 |
| 고블린 숲 | WoodsKit 안 남은 Pole + Cloth + Patch | 2벌 | (1102~1120, 144) | 막대 + 초록 천(빨래 걸이) | 없음 | 작아서 그대로 두거나 빼기(새로 안 만듦 추천) |
| 고블린 숲 | Map.Decor.PvPBorder_710 | 말뚝 10 + 주황 끝 10 + 띠 | x 712, z -60~60 | 나무 말뚝 | Kit_W_CampFence(업로드됨)로 말뚝만 | PvP 표시 띠는 그대로 |
| 호박밭 | Map.Decor.PumpkinPatch 울타리 FencePost + FenceRail | 50 + 49 | 밭 둘레 x 420~650, z 242~430 | 갈색 막대 | **Kit_M_Fence**(업로드됨, 6 폭) | 배치만(울타리 한 칸 = 6) |
| 호박밭 | Map.Decor.PumpkinPatch Pumpkin + Stem + Leaf | 37 + 32 + 33 | 밭 안 줄지어 | 주황 정육면체 + 줄기·잎 | **없음** | → 새로 만들 후보 P |
| 초원 입구 | Map.Gates.Gate_SlimeMeadow | 1 | (200, 0) | 나무 기둥 2 + 상인방 + **슬라임 석상 8 정육면체 + 눈 2** | 없음 | → 새로 만들 후보 M(시안의 덩굴·랜턴 나무 아치 = 튀는 곳 ⑭). 눈 달린 석상은 소품 얼굴 |
| 길가(Outskirts) | Map.Decor.Bridge_Halo / Bridge_Horns | 각 1 | (0, ∓240), 길이 184 | 상판 + 금/빨 난간·기둥 26·등 12·받침 14 | Town_Halo/Horns_Bridge(HD, 22 × 14)는 끝 장식으로만 | 상판(걷는 길)은 그대로 — 난간 모듈은 나중 후보 |
| 길가 | Map.Decor.Bridge_Meadow / Bridge_Goblin | 각 1 | (180, 0) / (680, 0), 길이 64 | 나무 상판 + 난간·기둥·받침 | Kit_M_Bridge(12 × 12)는 길이가 안 맞음 | 그대로(난간만 Kit_M_Fence로 바꿀 수 있음) |
| 교차로 | Map.Pads RingSeg | 36 | 패드 3개 둘레 | 네온 고리 조각 | — | 순간이동 표시(게임 빛) — 그대로 |
| 교차로 | Map.Decor Disc | 1 | (0, 0) 지름 52 | 광장 바닥 원판 | — | 바닥 — 그대로(분수 둘레는 Kit_X_Curb) |
| 유령 숲·고갯길·바다 | HauntedHollow / PassRocks / SeaRocks | 20 / 70 / 26 | — | 이미 3D | — | 할 것 없음 |

## 2. 새로 만들 후보(아직 안 만듦 — 검수 OK 뒤에)

| 후보 | 무엇 | 2D | 3D(Tripo 웹 HD) | 비용 |
|---|---|---|---|---|
| R1. 해골 폐허 최소 바꾸기 | R_Gate · R_Arch_A · R_Arch_B · Kit_R_PillarA · Kit_R_PillarB · Kit_R_StoneMarker · Kit_R_SpiritBowl · Kit_R_Banner = 8종 | 7종 고급 이미 있음, Banner만 고급 5 | 8 × 55 | **Firefly 5 + Tripo 440** |
| R2. 해골 폐허 나머지(선택) | R_BrokenTower(입구 랜드마크) · R_CrownAltar · R_WallRuin · R_Cliff_A/B · PillarFallen · Rubble · CrownPieces · StoneLantern · SignPost = 10종 | 고급 이미 있음(StoneLantern·SignPost 포함) | 10 × 55 | Tripo 550 |
| P. 호박 덩굴 무더기 | 호박 2~3개 + 큰 잎 + 덩굴(한 모델, 크기 섞어 37자리) | 시안 0 → 고급 5 | 1 × 55 | Firefly 5 + Tripo 55 |
| M. 초원 입구 덩굴 아치 | 초원 시안의 덩굴·꽃·랜턴 나무 아치(관문, 얼굴 없음) — 상인방 계약 유지 | 시안 0 → 고급 5 | 1 × 55(면 2만) | Firefly 5 + Tripo 55 |

- 추천: **R1 + P + M** = Firefly 15 + Tripo 550(잔액 2,245 → 1,695). R2는 R1이 들어간 뒤 사용자 반응 보고.
- 0원으로 되는 것: 고블린 관문(W_Gate), 캠프불(Kit_W_Campfire), 숲 말뚝(Kit_W_CampFence), 호박밭 울타리(Kit_M_Fence), 숲 덤불(Kit_X_Bush 또는 색 바꾼 BushB) + 빨간 눈 빼기.
