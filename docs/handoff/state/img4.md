# 이미지 생성 4 — 상태 (2026-10-11 밤 4차)

## 지금 상태 한 줄
**Tripo 묶음 1 26개 끝(1,430점, 잔액 16,535, records `<키>_web_hd_mv4`, 파일 art/models/tripo/web/<키>_HD_src.glb). WorldKit 소품 58종 다시 넣음(Real 103). 다음 = 디자인 검수 비교 시험 1장(A·B·C·D1·D2) + Blender 손보기. 사진 다시 찍기 3분 최종 검수 승인 기다림.**

## 디자인 검수 비교 시험 (10/11 밤, 사용자 "그림자가 없어서 이상한 건가, 뭔가 선이 없어 보여")
- 소품 4: HaloReasonHQ_BenchA · HaloVar4_Lantern_A(머리 임시 파트) · NEW_Beehive · 화분 하나(2D와 가장 닮은 것). 대리석 HH_HaloMarbleSmooth_Cream + 금 HH_HaloGoldTrim.
- 칸: 2D | A 지금 | B 빛 마을 실제 땅 위 + 모든 파트 CastShadow + C2c 빛(+한 가지 더: Diffuse 0.3 또는 ShadowSoftness 0.1) | C Blender 색 한 장 굽기(대리석 바탕 + AO 높이 4~6 %·최저 0.78·회갈색 + 곡률 -10/+5 %, 선형 곱) → MeshPart + SurfaceAppearance | D1 Highlight 바깥선(진한 갈색, Fill 1, Occluded) | D2 뒤집힌 껍데기 BenchA.
- 줄: C2c 낮·밤(등불 켬), 거리 5·15칸, 같은 카메라. 아래에 파트·삼각형·텍스처·Highlight 수, 폰 성능(추측이면 추측).
- 순서: A·B·D1 먼저(올리기 없음), C·D2 굽기는 지금, 올리기(약 9개)는 최종 검수 승인 뒤 이미지 개발.
- 같이 고칠 것: studio_c1234/HaloVar4_Lantern_A_q34.png 오른쪽 아래 흰 둥근 덩어리 + 초록 점 = 애벌레 얼굴 → NEW_SteppingStones 이끼 공(2개씩) → 공 빼고 납작한 이끼 조각으로.
- 결과 시트 1장 + 추천 → 디자인 검수.

## 10/11 밤 3차 (재부팅 뒤)
- 대리석 기본 = HH_HaloMarbleSmooth_Cream(이미지 개발 MV, 8 studs) — prop_kit.py `--marble smooth`(1700569).
- Studio 사진 1차 102장 `art/review/img4/studio_c1234/`(카메라가 멀어 작게 나옴) → 거리·간격 고침, 다시 찍기 3분은 이미지 생성 1이 WorldKit 바탕 다시 지은 뒤 최종 검수에 신청. WorldKit은 재부팅으로 닫힘 → HaloPropKits 다시 `py tools/prop_kit.py --all --apply` + `halo_props_place.py` 필요.
- 보고: 소품 3D = **디자인 검수**, 화면·유료 = 최종 검수(모든 것 검수).
- Tripo 묶음 1 승인 26개 ≈ 1,430점(등불 머리 5 + 식물 17 + 허수아비 + FlowerBush·GatherBush·WallLamp). 들어간 것: Lantern_C 1개(task f8976a51-4f83-4084-ab2d-180e9d47c2a0, 잔액 17,910). 재부팅으로 Tripo 로그아웃 → 최종 검수에 사용자 로그인 요청함.
- 이어 돌리는 법: scratchpad `tripo_srv.py tripo_jobs.json`(127.0.0.1:8766, /load?job=<키> → window.name에 4장 → Tripo 페이지로 이동) → 4면 탭(767,187 css px) → 슬롯 앞/왼쪽/오른쪽/뒷면에 DataTransfer → 8K 끄기 → 지오메트리 및 텍스처: 면 수 칸 focus+select 후 computer type + Tab(식물 20000, 나머지 15000) → 4K·PBR·삼각형·울트라 메시 켜짐·조명 제거 꺼짐 확인 → "생성 55" 클릭 → 잔액·task id 기록.
- 좌우 슬롯: Tripo 왼쪽 = 물체 자신의 왼쪽 = 2D *_right.png(기본). 예외(2D가 물체 기준 이름): Lantern_C(left2), PotionCrate → 왼쪽 슬롯에 *_left.

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
