# 슬라임 초원 소품 목록 (시안 보고 뽑음) — 이미지 생성 1, 2026-10-09 (A23-97)

시안: `art/review/world/meadow_v2_concepts_2026-10-09.jpg` (원본 6장 `art/out/meadow_v2/*.png`, 1536×1024, GPT Image 2.5 Sunburst High, 30 크레딧).
프롬프트: `art/prompts/Bundle_SlimeMeadow_00..05_*.txt`. 규칙: 빌려 쓴 숲 키트(W_*, Kit_W_*)는 초원에서 뺀다. 초원 전용만 쓴다.

## 시안에서 읽은 것 (한 줄)
- 땅: 가운데 둥근 왕관 길(흙길) + 3단 잔디 단 + 둘레 이끼 낀 둥근 바위벽 + 풀 덮은 언덕 고리. 물길(왼쪽 위 폭포 → 연못 → 개울), 오른쪽 위 왕관 언덕 + 구불 길.
- 나무는 **둥근 브로콜리 잎뭉치** 한 종류(큰 것 / 작은 것). 울타리는 **굵은 나무 말뚝 + 밧줄**. 덤불은 둥글게 줄지은 산울타리. 바위는 **둥글고 이끼 낀 3개 묶음**(일렬 금지).

## 필요한 새 모델 (Tripo, 개별 2D → 3D)
| 이름 | 개수(대략) | 비고 |
|---|---|---|
| Kit_M_TreeA 큰 둥근 나무 | 26 | 숲덩이 + 줄기, 잎 비늘 느낌 |
| Kit_M_TreeB 작은 둥근 나무 | 26 | A와 모양 다르게 |
| Kit_M_Boulder A/B/C 이끼 둥근 바위 | 3종 × 14묶음(2~4개) | 숲 W_Boulder 대신, 이끼 면 하나만 |
| Kit_M_StepStone 납작 디딤돌 | 길 14곳 × 4~6장 | 같은 모양 3종 |
| Kit_M_Fern 고사리 | 40 | 숲 Kit_W_Fern 대신 |
| Kit_M_Reeds 부들·갈대 | 12묶음 | 물가 |
| Kit_M_LilyPad 수련 | 10묶음 | 연못 위(작은 판 + 흰 꽃) |
| Kit_M_Gate 입구 문(돌기둥 + 나무 아치 + 슬라임 조각) | 1 (+ 교차로쪽 1) | 시안 1번 그대로. 문 이름 Gate_* 계약은 개발에서 |
| Kit_M_SignPost 화살 표지판 | 6 | **새로** (A23-96 기존 손수정본 교체) |
| Kit_M_RopeFence 말뚝+밧줄 한 칸 | 120칸 | 기존 Kit_M_Fence와 시안 비교 후 교체 여부 |
| Kit_M_Pebbles 작은 돌 흩뿌림 | 30 | 길 가장자리 |

## 이미 있는 초원 전용 (시안과 나란히 보고 맞으면 유지, 안 맞으면 새로)
Kit_M_CrownShrine(새로 만듦, 시안 2번과 맞춰 둠), Kit_M_Bridge(널다리, 시안 5번 보고 비교), Kit_M_BushA/B, Kit_M_FlowersA/B(LOD), Kit_M_JobBoard, Kit_M_Pinwheel, Kit_M_FlowerCart, Kit_M_PicnicBasket, Kit_M_LogBench, Kit_M_Stump, Kit_M_Mushrooms, Kit_M_JellyRock, Kit_M_CrystalPile, Kit_M_PuddleRim, Kit_M_MeadowArch.

## 땅·재질(코드, Tripo 아님)
- 바위 재질 타일(이끼 둥근 조약돌) 2안 → `Bundle_SlimeMeadow_06_rocktile` (1:1, 이어붙이기 검사 후 Terrain Rock 재질).
- 폭포·연못·개울: 지형 도구(meadow_terrain) 그대로, 폭포 모델 WoodsWaterfall 방식. 시안 5번 같은 각도로 사진 비교.
- 언덕 벽: 지형 4단 + 이끼 바위 면(시안 4번).

## 순서 제안
1) 나무 A/B, 바위 A/B/C, 디딤돌, 문, 표지판(새로) 개별 2D(이미지 생성 2) → Tripo.
2) 지형·배치 도구에 새 모델 연결 → 메인 사진(같은 각도 6장) 나란히.
3) 슬라임 3종 새 모델(멀티뷰 받는 대로) → 미니맵 칸 다시.
