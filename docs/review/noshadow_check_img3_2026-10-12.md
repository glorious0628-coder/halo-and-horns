# 그림자 점검 — 이미지 생성 3 (집·건물·골격 타일·장식 입력 그림), 2026-10-12

최종 검수 지시(사용자: "그림자 있나 없나 살펴보라", SPEC A23-150 '그림자 없는 2D'). 169장을 직접 열어 봄(6장씩 시트, 의심 칸은 100% 확대).

**판정 기준:** 있음 = 바닥/땅 그림자, 반사 바닥, 진한 그림자 면 · 약간 = 땅 그림자는 없지만 접촉 그림자(AO)·어두운 면·구운 경사 음영 · 약간(옅음) = 같은 종류인데 아주 옅음 · 없음 = 고른 빛, 음영 없음.

## 요약

| 판정 | 장 수 |
|---|---|
| 있음 | 7 |
| 약간 (옅음 포함) | 160 |
| 없음 | 2 |
| 합계 | 169 |

- **땅에 떨어진 그림자가 있는 그림은 집·부품 쪽에는 없음.** 빛 성 완성 그림 3장(final·ref_C2·ref_final)과 대성당 실내 4장은 반사 바닥 + 그림자 → 있음.
- **집 2D 4면(앞·옆·뒤)은 모두 '약간'**: 3D 렌더 풍이라 접촉 그림자·어두운 면이 들어 있음 → A23-150 기준(접촉 그림자·AO·어두운 면도 없음)에는 맞지 않음. 새 집 7채(houses_new4)는 그중 가장 옅음.
- 빛 성 부품(장미창·첨탑·날개, parts / parts_high)도 '약간': 첨탑 한쪽 면이 어둡고 깃 사이 음영.
- 골격 타일: 금(GoldTrim)·매끈 대리석 = 없음, 블록 대리석 2종 = 블록 가장자리 구운 음영 약간(블록 경계 표현), 직물 2종 = 옅음.
- 이 그림들이 쓰인 곳: 집 15채·새 집 7채 Tripo HD 입력(4면) → 장식 GLB, 빛 성 장식 Tripo 입력(parts_high) 예정. 골격(Studio 파트)은 그림자 없는 단색·타일이라 그림자와 무관.

## 무리별 메모

- **A** — 땅 그림자 없음. 차양 아래·창 상자·계단 모서리·문 안쪽에 부드러운 접촉 그림자(AO), 둥근 벽·금 돔 한쪽이 어두움
- **B** — 땅 그림자 없음. 둥근 벽 가장자리 어두움, 처마·발코니·화분 아래 접촉 그림자
- **C** — 땅 그림자 없음. A·B보다 고르게 밝음, 처마·창 상자·지붕창 아래 옅은 접촉 그림자, 기와 한쪽 음영
- **D** — 땅 그림자 없음(부품). 첨탑 파란 면 한쪽 어두움, 날개 깃 사이·장미창 테 옅은 음영
- **E** — 외관: 계단·화단 아래 옅은 접촉 그림자, 돔 한쪽 음영
- **F** — 대리석 블록: 블록 가장자리 둘레에 구운 경사 음영(옅음), 줄눈이 어두움

## 전체 목록

| # | 무리 | 파일 | 판정 | 메모 |
|---|---|---|---|---|
| 1 | A 집 앞 2D | `art/out/s2/halo/houses/HaloDomeHouse_01_front_HQ_src.png` | 약간 |  |
| 2 | A 집 앞 2D | `art/out/s2/halo/houses/HaloDomeHouse_02_front_HQ_recolor.png` | 약간 |  |
| 3 | A 집 앞 2D | `art/out/s2/halo/houses/HaloDomeHouse_02_front_HQ_src.png` | 약간 |  |
| 4 | A 집 앞 2D | `art/out/s2/halo/houses/HaloDomeHouse_03_front_HQ_src.png` | 약간 |  |
| 5 | A 집 앞 2D | `art/out/s2/halo/houses/HaloDomeHouse_04_front_HQ_src.png` | 약간 |  |
| 6 | A 집 앞 2D | `art/out/s2/halo/houses/HaloDomeHouse_05_front_HQ_src.png` | 약간 |  |
| 7 | A 집 앞 2D | `art/out/s2/halo/houses/HaloDomeHouse_06_front_HQ_recolor.png` | 약간 |  |
| 8 | A 집 앞 2D | `art/out/s2/halo/houses/HaloDomeHouse_06_front_HQ_src.png` | 약간 |  |
| 9 | A 집 앞 2D | `art/out/s2/halo/houses/HaloDomeHouse_07_front_HQ_src.png` | 약간 |  |
| 10 | A 집 앞 2D | `art/out/s2/halo/houses/HaloDomeHouse_08_front_HQ_src.png` | 약간 |  |
| 11 | A 집 앞 2D | `art/out/s2/halo/houses/HaloDomeHouse_09_front_HQ_src.png` | 약간 |  |
| 12 | A 집 앞 2D | `art/out/s2/halo/houses/HaloDomeHouse_10_front_HQ_recolor.png` | 약간 |  |
| 13 | A 집 앞 2D | `art/out/s2/halo/houses/HaloDomeHouse_10_front_HQ_src.png` | 약간 |  |
| 14 | A 집 앞 2D | `art/out/s2/halo/houses/HaloDomeHouse_11_front_HQ_src.png` | 약간 |  |
| 15 | A 집 앞 2D | `art/out/s2/halo/houses/HaloDomeHouse_12_front_HQ_recolor.png` | 약간 |  |
| 16 | A 집 앞 2D | `art/out/s2/halo/houses/HaloDomeHouse_12_front_HQ_src.png` | 약간 |  |
| 17 | A 집 앞 2D | `art/out/s2/halo/shops/HaloShop_Bakery_front_HQ_src.png` | 약간 |  |
| 18 | A 집 앞 2D | `art/out/s2/halo/shops/HaloShop_Flower_front_HQ_src.png` | 약간 |  |
| 19 | A 집 앞 2D | `art/out/s2/halo/shops/HaloShop_Juice_front_HQ_src.png` | 약간 |  |
| 20 | A 집 앞 2D | `art/out/s2/halo/shops/HaloShop_Potion_front_HQ_src.png` | 약간 |  |
| 21 | A 집 앞 2D | `art/out/s2/halo/roofs/HaloDomeHouse_01_roof_v2.png` | 약간 |  |
| 22 | A 집 앞 2D | `art/out/s2/halo/roofs/HaloDomeHouse_05_roof_v2.png` | 약간 |  |
| 23 | A 집 앞 2D | `art/out/s2/halo/roofs/HaloDomeHouse_07_roof_v2.png` | 약간 |  |
| 24 | A 집 앞 2D | `art/out/s2/halo/roofs/HaloDomeHouse_11_roof_v2.png` | 약간 |  |
| 25 | A 집 앞 2D | `art/out/s2/halo/roofs/HaloDomeHouse_12_roof_v2.png` | 약간 |  |
| 26 | A 집 앞 2D | `art/out/s2/halo/roofs/HaloShop_Flower_roof_v2.png` | 약간 |  |
| 27 | A 집 앞 2D | `art/out/s2/halo/roofs/HaloShop_Juice_roof_v2.png` | 약간 |  |
| 28 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_01_back.png` | 약간 |  |
| 29 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_01_left.png` | 약간 |  |
| 30 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_01_right.png` | 약간 |  |
| 31 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_02_back.png` | 약간 |  |
| 32 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_02_left.png` | 약간 |  |
| 33 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_02_right.png` | 약간 |  |
| 34 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_03_back.png` | 약간 |  |
| 35 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_03_left.png` | 약간 |  |
| 36 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_03_right.png` | 약간 |  |
| 37 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_04_back.png` | 약간 |  |
| 38 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_04_left.png` | 약간 |  |
| 39 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_04_right.png` | 약간 |  |
| 40 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_05_back.png` | 약간 |  |
| 41 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_05_left.png` | 약간 |  |
| 42 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_05_right.png` | 약간 |  |
| 43 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_06_back.png` | 약간 |  |
| 44 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_06_left.png` | 약간 |  |
| 45 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_06_right.png` | 약간 |  |
| 46 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_07_back.png` | 약간 |  |
| 47 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_07_left.png` | 약간 |  |
| 48 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_07_right.png` | 약간 |  |
| 49 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_08_back.png` | 약간 |  |
| 50 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_08_left.png` | 약간 |  |
| 51 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_08_right.png` | 약간 |  |
| 52 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_09_back.png` | 약간 |  |
| 53 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_09_left.png` | 약간 |  |
| 54 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_09_right.png` | 약간 |  |
| 55 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_10_back.png` | 약간 |  |
| 56 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_10_left.png` | 약간 |  |
| 57 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_10_right.png` | 약간 |  |
| 58 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_11_back.png` | 약간 |  |
| 59 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_11_left.png` | 약간 |  |
| 60 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_11_right.png` | 약간 |  |
| 61 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_12_back.png` | 약간 |  |
| 62 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_12_left.png` | 약간 |  |
| 63 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloDomeHouse_12_right.png` | 약간 |  |
| 64 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloShop_Bakery_back.png` | 약간 |  |
| 65 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloShop_Bakery_left.png` | 약간 |  |
| 66 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloShop_Bakery_right.png` | 약간 |  |
| 67 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloShop_Flower_back.png` | 약간 |  |
| 68 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloShop_Flower_left.png` | 약간 |  |
| 69 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloShop_Flower_right.png` | 약간 |  |
| 70 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloShop_Juice_back.png` | 약간 |  |
| 71 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloShop_Juice_left.png` | 약간 |  |
| 72 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloShop_Juice_right.png` | 약간 |  |
| 73 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloShop_Potion_back.png` | 약간 |  |
| 74 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloShop_Potion_left.png` | 약간 |  |
| 75 | B 집 옆·뒤 2D (houses_mv) | `art/out/s2/halo/houses_mv/HaloShop_Potion_right.png` | 약간 |  |
| 76 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Cliff6_back_v2.png` | 약간(옅음) |  |
| 77 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Cliff6_front.png` | 약간(옅음) |  |
| 78 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Cliff6_left_v2.png` | 약간(옅음) |  |
| 79 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Cliff6_right_v2.png` | 약간(옅음) |  |
| 80 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Cliff7_back_v2.png` | 약간(옅음) | 거의 평평(기둥 사이 옅은 접촉 음영만) |
| 81 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Cliff7_front.png` | 약간(옅음) |  |
| 82 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Cliff7_left_v2.png` | 약간(옅음) |  |
| 83 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Cliff7_right_v2.png` | 약간(옅음) |  |
| 84 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Cliff8_back_v2.png` | 약간(옅음) |  |
| 85 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Cliff8_front.png` | 약간(옅음) |  |
| 86 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Cliff8_left_v2.png` | 약간(옅음) |  |
| 87 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Cliff8_right_v2.png` | 약간(옅음) |  |
| 88 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden5_back_v2.png` | 약간(옅음) |  |
| 89 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden5_front.png` | 약간(옅음) |  |
| 90 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden5_left_v2.png` | 약간(옅음) |  |
| 91 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden5_right_v2.png` | 약간(옅음) |  |
| 92 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden6_back_v2.png` | 약간(옅음) |  |
| 93 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden6_front.png` | 약간(옅음) |  |
| 94 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden6_left_v2.png` | 약간(옅음) |  |
| 95 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden6_left_v3.png` | 약간(옅음) |  |
| 96 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden6_right_v2.png` | 약간(옅음) |  |
| 97 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden7_back_v2.png` | 약간(옅음) |  |
| 98 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden7_back_v3.png` | 약간(옅음) |  |
| 99 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden7_front.png` | 약간(옅음) |  |
| 100 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden7_left_v2.png` | 약간(옅음) |  |
| 101 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden7_left_v3.png` | 약간(옅음) |  |
| 102 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden7_right_v2.png` | 약간(옅음) |  |
| 103 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden7_right_v3.png` | 약간(옅음) |  |
| 104 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden7_right_v4.png` | 약간(옅음) |  |
| 105 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Hill4_back_v2.png` | 약간(옅음) |  |
| 106 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Hill4_front.png` | 약간(옅음) |  |
| 107 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Hill4_left_v2.png` | 약간(옅음) |  |
| 108 | C 새 집 7채 2D (houses_new4) | `art/out/s2/halo/houses_new4/HaloNewHouse_Hill4_right_v2.png` | 약간(옅음) |  |
| 109 | D 빛 성 C2 | `art/out/s2/halo/castle6/HaloCastle_C2_back_src.png` | 약간 |  |
| 110 | D 빛 성 C2 | `art/out/s2/halo/castle6/HaloCastle_C2_final_src.png` | 있음 | 반사 바닥 + 바닥에 빛·그림자, 정문 안 깊은 그림자 |
| 111 | D 빛 성 C2 | `art/out/s2/halo/castle6/HaloCastle_C2_front_HQ_src.png` | 약간 |  |
| 112 | D 빛 성 C2 | `art/out/s2/halo/castle6/HaloCastle_C2_gateleaf_HQ_src.png` | 약간(옅음) | 금 문짝 돋을새김 옅은 음영 |
| 113 | D 빛 성 C2 | `art/out/s2/halo/castle6/HaloCastle_C2_left_src.png` | 약간 |  |
| 114 | D 빛 성 C2 | `art/out/s2/halo/castle6/HaloCastle_C2_right_HQ_src.png` | 약간 |  |
| 115 | D 빛 성 C2 | `art/out/s2/halo/castle6/HaloCastle_C2_top_src.png` | 약간 |  |
| 116 | D 빛 성 C2 | `art/out/s2/halo/castle6/ref_C2.png` | 있음 | 반사 바닥 + 바닥 그림자, 정문 안 그림자 |
| 117 | D 빛 성 C2 | `art/out/s2/halo/castle6/ref_final.png` | 있음 | 반사 바닥 + 바닥 그림자, 정문 안 그림자 |
| 118 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_Rose_back.png` | 약간 |  |
| 119 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_Rose_front.png` | 약간 |  |
| 120 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_Rose_left.png` | 약간 |  |
| 121 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_Rose_right.png` | 약간 |  |
| 122 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_Spire_back.png` | 약간 |  |
| 123 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_Spire_front.png` | 약간 |  |
| 124 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_Spire_left.png` | 약간 |  |
| 125 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_Spire_right.png` | 약간 |  |
| 126 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_WingL_back.png` | 약간 |  |
| 127 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_WingL_back2.png` | 약간 |  |
| 128 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_WingL_front.png` | 약간 |  |
| 129 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_WingL_left.png` | 약간 |  |
| 130 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_WingL_right.png` | 약간 |  |
| 131 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_WingR_back.png` | 약간 |  |
| 132 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_WingR_back2.png` | 약간 |  |
| 133 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_WingR_front.png` | 약간 |  |
| 134 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_WingR_left.png` | 약간 |  |
| 135 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_WingR_right.png` | 약간 |  |
| 136 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_Rose_back.png` | 약간 |  |
| 137 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_Rose_front.png` | 약간 |  |
| 138 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_Rose_left.png` | 약간 |  |
| 139 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_Rose_right.png` | 약간 |  |
| 140 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_Spire_back.png` | 약간 |  |
| 141 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_Spire_front.png` | 약간 |  |
| 142 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_Spire_left.png` | 약간 |  |
| 143 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_Spire_right.png` | 약간 |  |
| 144 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_WingEdge_L_left.png` | 약간 |  |
| 145 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_WingEdge_L_right.png` | 약간 |  |
| 146 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_WingEdge_R_left.png` | 약간 |  |
| 147 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_WingEdge_R_right.png` | 약간 |  |
| 148 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_WingL_back.png` | 약간 |  |
| 149 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_WingL_front.png` | 약간 |  |
| 150 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_WingL_left.png` | 약간 |  |
| 151 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_WingL_right.png` | 약간 |  |
| 152 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_WingR_back.png` | 약간 |  |
| 153 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_WingR_front.png` | 약간 |  |
| 154 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_WingR_left.png` | 약간 |  |
| 155 | D 빛 성 C2 | `art/out/s2/halo/castle6/parts/CastlePart_WingR_right.png` | 약간 |  |
| 156 | E 대성당 | `art/out/s2/halo/HaloProp_Cathedral_back_HQ_src.png` | 약간 |  |
| 157 | E 대성당 | `art/out/s2/halo/HaloProp_Cathedral_front_HQ_src.png` | 약간 |  |
| 158 | E 대성당 | `art/out/s2/halo/HaloProp_Cathedral_left_HQ_src.png` | 약간 |  |
| 159 | E 대성당 | `art/out/s2/halo/HaloProp_Cathedral_right_HQ_src.png` | 약간 |  |
| 160 | E 대성당 | `art/out/s2/interior/Interior_Cathedral_part1.png` | 있음 | 실내: 강한 빛줄기·반사 바닥·기둥 그림자 |
| 161 | E 대성당 | `art/out/s2/interior/Interior_Cathedral_part2.png` | 있음 | 실내: 반사 바닥·제단 그림자 |
| 162 | E 대성당 | `art/out/s2/interior/Interior_Cathedral_part3.png` | 있음 | 실내: 반사 바닥·창빛·기둥 그림자 |
| 163 | E 대성당 | `art/out/s2/interior/Interior_Cathedral_whole.png` | 있음 | 실내: 반사 바닥·의자 그림자 |
| 164 | F 골격 타일 색 맵 | `art/ui/halo_tile/Halo_GoldTrim_color.png` | 없음 | 금 결 무늬만, 음영 없음 |
| 165 | F 골격 타일 색 맵 | `art/ui/halo_tile/Halo_TowerMarbleBlockCream_color.png` | 약간 | 블록 가장자리 구운 음영 |
| 166 | F 골격 타일 색 맵 | `art/ui/halo_tile/Halo_TowerMarbleBlock_color.png` | 약간 | 블록 가장자리 구운 음영 |
| 167 | F 골격 타일 색 맵 | `art/ui/halo_tile/fabric/Halo_Fabric_color.png` | 약간(옅음) | 직물 결 옅은 음영 |
| 168 | F 골격 타일 색 맵 | `art/ui/halo_tile/fabric_v2/Halo_Fabric_color.png` | 약간(옅음) | 직물 결 옅은 음영 |
| 169 | F 골격 타일 색 맵 | `art/ui/halo_tile/marble_smooth/Halo_MarbleSmoothCream_color.png` | 없음 | 대리석 결만, 음영 없음 |

시트(점검에 쓴 6장 묶음)는 저장하지 않음 — 원본 경로로 다시 볼 수 있음. 판정: 이미지 생성 3, 같은 날 직접 열람.
