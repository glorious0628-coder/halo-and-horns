# 디자인 검수 — 상태 (2026-10-11 밤 2차)

- 역할: `role_prompts/13_design_review.md`. 보고처 = 최종 검수('모든 것 검수'). 세션 id는 list_sessions로.
- 확정값(최종 검수): 금 (255,168,36), 금속 0.5·거칠기 0.15.
- 새 판정 기준(사용자 10/11 "그림자가 없어서 이상한 건가, 뭔가 선이 없어 보여"): 파트 소품은 2D처럼 가장자리 어둠·홈 그늘·선이 보여야 함.
- 10/11 밤 PC 꺼짐 → WorldKit 저장 안 한 것 사라짐. 이미지 생성 1이 스크립트로 다시 지음 → 이미지 개발이 금·매끈 대리석 MV 다시 넣음 → 그 뒤 소품 사진.

## 끝난 판정
- 이미지 생성 1 땅·길 3차(806d6c0, `art/review/world/halo_v2/review2/sheet_review2_v3.jpg`) = 통과. 5단계로 넘긴 것: 계단 발치 흰 칠 번짐, 계단 옆 회색 각진 바위면, 꽃 단 턱 검은 바위 띠 → 축대.
- 이미지 개발 매끈한 크림 대리석 3판 = 통과(color 140510838680155, WorldKit MV `HH_HaloMarbleSmooth_Cream`; 원통 흰 선 = 화면 겹침).
- 이미지 생성 2 키트 4면 1차: FlowerBush·GatherBush·벽등 머리(잘라서) 통과 → Tripo 묶음(이미지 생성 4가 돌림, 최종 검수 승인 26개 ≈ 1,430점).
- 이미지 생성 2 키트 4면 2차(2ea2872): WhiteRock a·b·c·BreadBasket·Hedge 통과(묶음 2 조건).

## 기다리는 것
- 이미지 생성 2: 종만 4면(High 20 OK), 벽등 머리 자른 4장, 벽등 받침 앞·뒤 Medium, WateringCan right High 1장(5 OK), 무기 High 28장(`art/review/s2/weapons_t13_hq_all.jpg`, 비율 숫자와 같이).
- 이미지 생성 4: 소품 사진 + 밋밋함 비교 시트(소품 BenchA·Lantern_A·Beehive·Planter 1; 2D|A 지금|B 메인 C2c 빛|C Blender 곡률·AO SurfaceAppearance|D1 Highlight|D2 뒤집힌 껍데기; 낮·밤, 5·15칸, 파트·삼각형·텍스처 수). 빛 표 = `docs/design/light_compare_worldkit_vs_main_2026-10-11.md`. 우연한 얼굴(Lantern_A_q34 오른쪽 아래 흰 덩어리+초록 점) 고침 확인.
- C·D2 올리기 약 9개 = 최종 검수 승인 대기.
- 이미지 생성 3: Tripo HD 장식(돔·문짝·등불·차양 틀) Blender 손보기 — A23-125 세 단계·12항목.
