# 두 마을(빛·뿔) 안 옛 모양(원시 파트) 소품 목록 (이미지 생성 1, 2026-10-08)

검수 요청(10/08): "두 마을 안에 아직 옛 모양(원시 파트)으로 남은 소품 목록을 메인 place/ 기준으로 — 이름·개수·자리, 3D 판이 이미 있는지. 만들기 전에 범위·포인트."

- **출처:** `place/GoodEvil.rbxlx` = 메인 10/07 22:39 저장본(38e8a9a). 도구 `tools/town_props_scan.py`(읽기만) — 마을 상자 = Config.Zones 지도 v2(빛 (0, -515), 뿔 (0, 515), 400 × 370). 투명(≥ 0.95) 계약 파트는 뺌.
- **요약:** 두 마을 안에서 3D(MeshPart)는 **성 2개(빛 70 · 뿔 v4)와 빛 마을 나무 5그루뿐**이에요. 나머지는 모두 원시 파트예요. 가게·집은 하나도 없어요(마을이 거의 비어 있음).

## 1. 마을 안 원시 파트 소품 — 3D 판 있는지

| 마을 | 이름(메인) | 개수 | 자리 (x, z) | 지금 모양 | 3D 판 | 상태 |
|---|---|---|---|---|---|---|
| 빛 | Map.Gates.Gate_HaloTown | 1 | (0, -330) | 흰 탑 2 + 금 돔 2 + 상인방 + 금 고리 8 | **Town_Halo_Gate** | 업로드됨(3a) — 계약: 상인방(Lintel) = HUD 안내 목표, ZoneService 문(투명으로 남기기) |
| 빛 | Map.Decor.HaloTower | 4 | (±58, -468), (±58, -362) | 흰 원통 + 금 띠·돔 + 금 고리 8 | **Town_Halo_WallTower**(HD) | 가져오기 D1(3_third) |
| 빛 | Map.Decor.HeroStatue | 6 | (±13, -350), (±13, -370), (±13, -390) — 마을 길 양옆 | 금 받침 + 흰 블록 몸·머리 + 금 고리(4파트) | **없음** | → 새로 만들 후보 A |
| 빛 | Map.Decor 낱개 Flower | 8 | (34, -366), (-63, -399), (29, -412), (-32, -447), (-42, -375), (-31, -363), (66, -407), (61, -438) | 분홍 1.6 정육면체 | **Kit_M_FlowersA/B** | 업로드됨(초원 키트) |
| 빛 | Map.Decor.Bridge_Halo | 1 | (0, -240) 다리(마을 입구 쪽 끝 -330) | 길이 184 상판 + 금 난간·기둥 26·등 12·받침 14 | Town_Halo_Bridge(HD, 22 × 14)는 **184 다리 대신 못 함** | 다리 끝 장식으로만(D1). 다리 몸은 그대로 |
| 뿔 | Map.Gates.Gate_HornsTown | 1 | (0, 330) | 검은 기둥 2 + 뿔 쐐기 6 + 빨간 눈 2 + 상인방 | **Town_Horns_Gate** | 업로드됨(3a) — 계약은 빛 문과 같음. '빨간 눈 2'는 얼굴처럼 읽힘 → 바꾸면 사라짐 |
| 뿔 | Map.Decor.HornTower | 2 | (-48, 450), (-46, 365) | 검은 기둥 + 쐐기 왕관 4 + 주황 창 3 | **Town_Horns_WallTower**(HD) | 가져오기 D1(3_third) |
| 뿔 | Map.Decor 낱개 Spike | 14 | 반지름 62 고리, (0, 410) 둘레: (±56, 437), (±39, 459), (±14, 470), (±62, 410), (±56, 383), (±39, 362), (±14, 350) | 검은 쐐기 4 × 13~22 높이 | **없음**(Town_Horns_Wall은 성벽 조각이라 뾰족 바위가 아님) | → 새로 만들 후보 C |
| 뿔 | Map.Decor 낱개 LavaChannel + ChannelRimL/R | 2줄(파트 6) | x = ±48, z 345~475(길이 130) | 주황 띠 + 검은 테 | 없음 | → **Terrain CrackedLava로 칠하기(0)** 추천(개발 1) |
| 뿔 | Map.Decor 낱개 LavaCrack | 4 | (14, 432), (-29, 428), (-35, 364), (31, 399) | 주황 11 × 2 판 | 없음 | → Terrain CrackedLava(0) |
| 뿔 | Map.Decor.Bridge_Horns | 1 | (0, 240) | 빛 다리와 같은 꼴(검·빨) | Town_Horns_Bridge(HD) — 다리 끝 장식으로만 | D1 |

(Roads·바닥 판은 지형/길이라 뺌. 빛 마을 HaloTownTrees 5그루는 이미 3D.)

## 2. 마을이 비어 있음 — 이미 있는 3D로 채우기(만들 것 없음, 배치만)
WorldKit 미리보기용 배치 도구 `tools/worldkit/towns_kit_place.luau` + `towns_fill_place.luau`(10/06, 길 따라 두 줄 거리 + 가운데 광장 + 성벽·큰 문)가 있지만 **옛 무료 키트 이름(H_*/R_*)**을 써요. 같은 자리에 Tripo 판을 넣으면 돼요:

| 옛 무료 키트(배치 도구) | Tripo 판 | 상태 |
|---|---|---|
| H_Gate / R_Gate | Town_Halo_Gate / Town_Horns_Gate | 업로드됨(3a) |
| H_Wall / R_Wall | Town_Halo_Wall / Town_Horns_Wall | 업로드됨(3a) |
| H_House_A·B / R_House_A·B | Town_Halo_HouseA·B / Town_Horns_HouseA·B (+ HouseC HD) | B1·B2(2_second), HouseC는 D1 |
| H_Shop_Bakery·Potion | Town_Halo_Bakery·Potion (+ Smithy·JuiceBar) | B1 |
| R_Shop_Forge·Tavern | Town_Horns_Smithy·JuiceBar (+ Bakery·Potion) | B2 |
| H_Castle / R_Fortress | Town_Halo_Castle(9조각) / Town_Horns_Castle ③(9조각) | A·H(1_first) |
| R_Watchtower | Town_Horns_WallTower | D1 |
| H_Lamp | Kit_X_Lamp | C1 |
| H_Crates | Kit_X_Crate / Kit_W_Crates | C1 / 업로드됨 |
| H_FlowerPot / R_Planter | Kit_X_FlowerPot | C1 |
| H_Flowers | Kit_M_FlowersA·B | 업로드됨 |
| K_Bench | Kit_X_Bench | C1 |
| K_Brazier / R_AltarBrazier | Kit_X_Brazier / Town_Horns_Brazier(HD) | C2 / D2 |
| H_Banner / R_Banner | Kit_X_BannerHalo / Kit_X_BannerHorns | C1 |
| H_BridgePost·Rail / R_BridgeRail | Town_Halo_Bridge / Town_Horns_Bridge(다리 끝) | D1 |
| K_Fountain(마을 광장) | **X_Fountain**(옛 교차로 분수, 업로드됨 — 교차로는 ② 분수로 바뀌니 빛 마을 광장으로 옮겨 쓰기) | 업로드됨 |
| Town_Halo_Spawn / Town_Horns_Spawn | 마을 스폰 받침 | 업로드됨(3a) |
| H_KnightStatue / R_WarriorStatue | 없음 | 후보 A·B |
| R_Spikes | 없음 | 후보 C |
| R_LavaChannel | Terrain CrackedLava | 0 |
| H_Cathedral, H_Cloud | 빛 성이 대신함 — 안 만듦 | — |

## 3. 새로 만들 후보(아직 안 만듦 — 검수 OK 뒤에)
같은 길: Firefly 시안(중간 0) → 고른 것 고급 5 → Tripo 웹 HD 55.

| 후보 | 어디 | 개수(같은 모델 되풀이) | 비용 |
|---|---|---|---|
| A. 빛 마을 기사 석상(흰 대리석 + 금, 갑옷 기사 — 옷·몸 가린 모습, 단순한 얼굴) | HeroStatue 6자리(마을 길 양옆) | 1 모델 × 6 | Firefly 5 + Tripo 55 |
| B. 뿔 마을 전사 석상(검은 돌 + 용암 금, 뿔 투구) — 빛 석상과 짝 | 뿔 마을 길 양옆(옛 자리 없음, 배치 도구에 R_WarriorStatue 자리) | 1 모델 × 4~6 | Firefly 5 + Tripo 55 |
| C. 뿔 마을 흑요석 뿔 바위(용암 금, 둥근 장난감 모양 — 뾰족 쐐기 대신) | Spike 14자리(반지름 62 고리) | 1~2 모델 × 14 | 1개: Firefly 5 + Tripo 55 / 2개(높이 다른 것): 10 + 110 |

- 추천: **A + C(1개)** = Firefly 10 + Tripo 110. B는 짝을 맞추고 싶으면 + 5 + 55.
- 0원으로 되는 것: 용암 줄·금(Terrain CrackedLava), 꽃(Kit_M_Flowers), 마을 채우기(2번 표 — 배치만).
