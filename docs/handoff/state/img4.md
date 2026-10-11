# 이미지 생성 4 — 상태 (2026-10-11 밤 2차)

## 지금 상태 한 줄
**(가) 31종 전부 + NEW_Cauldron 파트로 끝, (가+나) 몸통 26종(<키>__Body) 끝. WorldKit HaloV2.Props.Real 103개(저장 안 함). 검수 기다림: ① Studio 사진 화면 "전달함, 시작" ② Tripo 묶음 1 승인.**

## 검수 결정 (10/11 밤)
- 나누기 표 OK. **등불 56개 머리·벽등 머리·종 = Tripo**(이미 있는 4면 2D → HD 멀티뷰 → Blender에서 갈빗대·고리만 정확한 모양으로 바꿔 끼움 → C/N/R/M). 기둥·받침은 파트. 지금 파트 머리는 임시.
- 대리석: 작은 소품 = 줄눈 없는 크림, plain 임시 OK. 소품용 매끈한 크림 MV를 검수가 이미지 개발에 요청함 → 나오면 MAT_LUA "marble" 줄만 바꿈.

## Tripo 묶음 (검수에 보냄, 승인 전)
- 묶음 1 (4면 2D 있음) 23개 = 1,265점: 등불 머리 A~E 5 / 식물 따오기 17(화분 5·Topiary 3·RoundTree 3·BenchB·VegGarden·BreadStand·FruitStall·FlowerCart·PotionCrate) / Scarecrow.
- 묶음 2 (이미지 생성 2 4면 먼저) 18개 = 990점: WallLamp·BellFrame(종)·GatherBush·FlowerBush·PotFlowers A·C·D·E·F·Planter A·D·E·Balustrade_F(덤불)·WhiteRock a·b·c·BreadBasket·WateringCan·Hedge. (Cauldron은 파트로 됨 → 빠짐)
- 웹 studio.tripo3d.ai, HD H3.1 멀티뷰 55점, 기록 잔액 약 17,965(10/11 02:20). 방법: 메모리 tripo-web-in-app-browser.

## 도구
- `tools/prop_kit.py [키…|--all] [--apply]` → build/prop_kit/<키>.json/.luau, WorldKit ServerStorage.HaloPropKits. CSG 자르개도 ops를 가질 수 있음(팔각 구멍).
- `tools/prop_kit_preview.py`(Blender Cycles CPU, 절대 경로), `tools/prop_kit_sheet.py`(2D | 렌더, __Body는 키 2D로), `tools/prop_kit_shots.py`(Studio 사진, 화면 허락 뒤).
- `tools/worldkit/halo_props_place.py`: HaloPropKits에 같은 키가 있으면 Real로 바꿔 끼움(__Body는 안 끼움).
- 시트: `art/review/img4/propkit_c1_*`, `c2_lamps`, `c3`, `c4_pots`, `c4_planters`, `c4_stalls` (_blender.jpg).

## 다음
1. 화면 OK → `STUDIO_NAME=WorldKit py tools/prop_kit_shots.py art/review/img4/studio_c1234 --night` → `prop_kit_sheet.py --renders … --label Studio` → 검수 → "끝".
2. Tripo 묶음 1 승인 → 내장 브라우저 Tripo 웹(사용자 로그인 필요하면 검수 경유).
3. 재질별 CSG 합치기로 파트 수 줄이기(등불 56 ≈ 4천 파트) — 시험 후 검수에.
4. 약한 곳: Lavender 항아리 달걀형으로, Planter_E 옆 그림자 줄, 빨랫줄 수건 크기, 벽등.
