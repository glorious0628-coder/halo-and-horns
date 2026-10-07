# 이미지 생성 1 상태 (2026-10-07)

> 계정 정리(10/07): 다음 계정은 **`docs/handoff/imagegen1_handoff_2026-10-07.md`** 부터 읽기(다음 큐·잔액·주의). 이 파일은 오늘 상세 기록.

## 오늘 끝난 것 (모두 origin/main)
- **빛 성 깃발 문양 → 금빛 고리** (텍스처만, 0크레딧) — 깃발 5장(정면 4 + 왼쪽 탑 1). 사용자 OK "둘 다 넣어".
  `art/models/tripo/town/Town_Halo_Castle_10k_ring.glb`(2.5MB), 시트 `art/review/town3/halo_castle_banner_ring.jpg`.
  도구 `tools/banner_emblem_swap.py`(화면 공간에서 문양 지우기 + 고리 그리기, UV 이음매 무관). E1 오른쪽 가는 빛줄은 모델 모양(접힌 면).
- **뿔 성 새 판 v3N2** — 사용자 고름(v3 시트 a91acdb) → Firefly 고급 1장(5크레딧, N2_1 참조) → Tripo building(40, 면 9,598).
  `art/models/tripo/Town_Horns_Castle_v3_raw.glb`, 시트 `art/review/town3/horns_castle_v3_2d_vs_3d.jpg`. 사용자 OK "둘 다 넣어". 옛 Town_Horns_Castle_10k는 안 씀. 커밋 49fe94c.
- **⑦ 뿔 소굴 밝기** — 시트 `art/review/zone/horns_town_brightness_7.jpg`(cdaaeaa, 검수 OK). ZoneLook HornsTown 값 + 새 키 NightExp +1.9(Eclipse만) + 바닥 `art/ui/Tex_Basalt_FF2.png`(approved.json 기록). 개발 1 적용 뒤 낮·밤 실제 캡처로 다시 재기. 계산 도구 `tools/zone_brightness_sim.py`.
- **⑧ 교차로 돌길** — `tools/apply_surface_materials.lua` GE_Cobblestone StudsPerTile 14→8 + Organic(5c7cfb1). 그림 `art/review/zone/crossroads_cobble_scale_8.jpg`.
- 어제(10/06) 가져온 40개 애셋 id: `art/models/worldkit/import40_assets_2026-10-06.json` + 모델 만드는 도구 `tools/build_kit_from_ids.py`(MCP 한 번, 화면 제어 없음). 계급 장식은 앞 -Z → 서버 Yaw = 0(개발 2 반영).

- **슬라임 뒤통수 얼굴** (사용자 "징그러워") — 13종 앞·뒤·옆 검사 → 뒤 얼굴은 초원 슬라임·왕 슬라임뿐. 텍스처만 고침(0크레딧): `art/models/tripo/MonsterSlimeCube_tex_noback.png`, `BigSlimeCube_tex_blue_noback.png`(1024). 시트 `art/review/monsters/slime_backface_fix.jpg`(3733381, 검수 OK). 업로드 = 이미지 개발, TextureID 교체 = 개발 1. 도구 `tools/back_face_erase.py`(1024 텍스처에 써야 칸이 안 빔).
- **오프닝 콘티** — `art/review/opening/opening_storyboard_v1.jpg`(56b5186, 중간 20장 0크레딧, 원본 `art/out/opening/` 미추적). 검수 조건(보라 안개 손·십자 없는 고리 투구·삐친 얼굴) 반영. 고를 안 대기.

- **부서진 왕관 B2 3D** — B안(반반) 고급 1장(5크레딧) → Tripo(40, 면 9,764, e52a883). 뒤는 Tripo가 지어낸 금→주황이라 **텍스처만 고침**(0크레딧, 검수 ②): 진홍 반쪽 + 금 장식 그대로 + 빨강 보석 2 / 금 반쪽 + 파랑 보석 1 + 빛나는 지그재그 금(앞 금과 같은 평면).
  `art/models/tripo/Crown_Broken_B_backfix.glb`(1.6MB, 1024 텍스처 `Crown_Broken_B_tex_backfix.png`), 시트 `art/review/opening/crown_B2_backfix_8dir.jpg`.
  도구 `tools/crown_back_fix.py`: 5방향 덤프(뒤·뒤 3/4 둘·옆 둘)를 각자 화면에서 판정 → 텍셀마다 "얼마나 정면으로 봤나"로 표를 모음. 금구슬은 3D 공으로 기억해 모든 방향에 같게. `castle_window_dump.py`는 이제 hit 점·법선(pos/nor)도 저장.
- **숲 키트 목록** `docs/design/kit_woods.md`(5a1eec0) — 작은 것 15종 + 그림체 머리·꼬리 + 지킬 것(해골·얼굴·눈 없음, 주황은 PvP 말뚝만). 이미지 생성 2가 16장 생성 중.

- **WorldKit 가져오기 1**(화면 제어 1번, 검수 OK): 뿔 성 v3N2·빛 성 고리 깃발·왕관 backfix → id 장부 `art/models/worldkit/import_next_assets_2026-10-07.json`(de7cfe2). 왕관 id → 개발 1(오프닝·하늘 왕관, ScaleTo 약 4).
- **빛 성 색 고침**(텍스처만 0크레딧, 검수 통과 84ae50a): 금·파랑 채도를 시안에 맞춤, 새 텍스처 rbxassetid://81624750351092. 시트 `art/review/town3/halo_castle_color_fix.jpg`(Blender 전·후 + WorldKit 게임 조명 캡처). id·크기·피벗 → 개발 1. 도구 `tools/halo_castle_color_fix.py`.
- **뿔 성 새 판 v4**(사용자: 빛 성보다 초라 → 처음부터): 4안×2 시트(837a818) → 사용자 B_1(계단식 산성) → 고급 5 → Tripo building 40(8e8d012, 검수 통과). 배치는 1.2배(84 × 65.6, 개발 1). v3N2는 안 씀.
- **숲 작은 소품 8개 Tripo**(이미지 생성 2 고급 그림, 320, 96a0402 통과). 모닥불만 다시 그리는 중(이미지 생성 2) → 받으면 Tripo 다시(geometry detailed 가능).
- **숲 큰 것**: 2D 11종×2(a42d8b8) → 10개 확정(우두머리 공터는 Tripo 대신 개발 1 조립 메모) → 나무 A는 다시(전나무 1, edc4b3d) → 고급 11장(B는 줄기 옹이가 눈 같아 한 번 더) → Tripo: building 4(고목·관문·천막 2) + prop 1(토템) + tree 3(나무 C·바위 2, 면 1,500 새 설정) = 320, 이어서 나무 A·B 다시 + 나무 C 3k 다시 = 120. 나무 C 덩굴은 1.5k·3k 둘 다 회색이라 텍스처만 고침(`W_Tree_C_vines.glb`, 0크레딧, 3k 다시 40은 헛씀).
- **WorldKit 가져오기 2·3 끝**(가져오기 버튼은 사용자 클릭): 뿔 성 v4 + 숲 소품 7 → `art/models/worldkit/import_next2_assets_2026-10-07.json`, 숲 큰 것 10 → `import_next3_assets_2026-10-07.json`. id·크기·피벗 → 개발 1.
- **사냥터 게시판 2개 Tripo**(표준 30×2=60, 11a53c2): 숲 판 앞면 구멍은 겹친 점 합친 뒤 1개만 진짜 구멍 → 나무 UV로 메움(0크레딧, `tools/glb_fill_board_hole.py`). 시트 `art/review/kit_woods/jobboards_2d_vs_3d.jpg`.
- **해골 유적 키트** `docs/design/kit_ruins.md`(d0da20d) + **큰 것 2D 시안** `art/review/kit_ruins/ruins_big_2d_v1.jpg`(8종×2, 중간 0크레딧, 원본 `art/out/kit/ruins_big/` 미추적). 바위 첫 안은 아치·깃발이 붙어 '돌만'으로 다시(v2). 100% 확대 점검: 얼굴·눈·해골·뼈·무덤·십자가·빨강 없음.

## 대기 중
- **조각 v2**(e52a883 시트) — 빛·뿔 조각 둘 다 쓸지 사용자 답(검수 경유) → 고급(5) → Tripo(약 40, 둘째 조각 +40은 승인 필요).
- **해골 유적 큰 것** — 검수 확정(추천 8개 그대로: 성탑 2 · 관문 1 · 아치 A 2 · 아치 B 1 · 제단 2 · 성벽 1 · 바위 A v2-1 · 바위 B v2-1) → 고급 8장 끝(40크레딧, `art/out/hq/HQ_R_*.png`, 시트 `art/review/kit_ruins/ruins_big_hq_v1.jpg`, approved.json 기록). 다음: Tripo 웹(3b 시험으로 정한 방식, 범위·합계 먼저 검수).
- **3b Tripo 웹 시험**(계정 ①, 150포인트 → 남은 3,400/3,550): 분수·화로를 Smart Mesh(모양 100·체험 0 + 텍스처 20)와 HD 최고 품질(55, 면 1만으로 설정)로 → 시트 `art/review/town3b/tripo_web_test_smart_vs_hd.jpg`. 추천 HD(13×55 = 715 vs Smart 13×120 = 1,560, 분수 색이 2D에 더 맞음). 검수·사용자 결정 + GLB 내려받기 허락 대기. 작업 id는 records.json `*_web_smart/_web_hd`. 나머지 13개는 결정 뒤.
  - 주의: 크롬 Tripo는 무거워 클릭이 시간 초과되면 여러 번 들어갈 수 있음(Smart Mesh 화로 4개 생김, 포인트는 안 빠짐) → 돈 드는 버튼은 한 번 누르고 화면으로 확인, 시간 초과에 다시 누르지 않기.
- **게시판 2개 3D 통과**(11a53c2, 숲은 구멍 메운 `_fix` 판) → 다음 WorldKit 가져오기 묶음에 넣기(가져오기 버튼은 사용자).
- **모닥불** — 이미지 생성 2 다시 그림 → 검수 고름 → 고급(5) → Tripo API prop 40(남은 45, geometry detailed 가능) → 다음 가져오기(사용자 클릭).
- WorldKit 가져오기 만드는 법: `tools/worldkit_combine.py`(spec fit) → 사용자가 '3D 가져오기' 클릭 → MCP로 Model·피벗(바닥 가운데, 앞 -Z) → 장부 JSON + `tools/build_kit_from_ids.py`.
- **오프닝 콘티**(A23-55, 10/12~14): 욕심으로 왕관이 깨짐("If I can't have it, no one can!"), 얼굴 없는 그림자 손(무섭지 않게, 범인 진영 모름) → 조각이 흩어지며 빛·뿔이 서로 손가락질하는 귀여운 컷.

## 요령
- Firefly: 내장 브라우저에서 `preview_start`로 연 탭(tab-1)이 그려짐("seed" 탭은 빈 화면일 수 있음). 탭을 새로 열면 `tools/firefly_page_helpers.js`를 붙여 넣고 `__ready()` 확인 → `__runList([...])`. 고급은 승인 뒤만.
- git: 다른 세션의 안 커밋한 파일과 겹치면 pull 하지 말고 임시 worktree에서 내 커밋만 cherry-pick 해 push(49fe94c 때처럼).
- approved.json: 들여쓰기 1칸 그대로(`json.dumps(indent=1, ensure_ascii=False)`), 내 키만.
- 화면 제어가 약속한 시간을 넘길 것 같으면 중간에 멈추고 바로 검수에 알리기(10/07, 2분 반). 가져오기 미리보기 버튼이 반응 없으면 열어 두고 사용자 한 번 클릭 부탁.
- **computer-use 도구는 확인용으로도 부르지 않기**(`list_granted_applications` 한 번에 사용자 화면 주황 '제어 중'이 턴 끝까지 켜짐, 10/07). 승인된 제어 단계 뒤엔 Esc → 턴 끝 → 검수에 "끝".
- push 거절 때 더 빠른 길: `git merge-tree --write-tree` + `git commit-tree -p origin/main` → `git push origin <새 커밋>:main`(공유 작업 트리를 안 건드림, 5a1eec0).

## 크레딧 (오늘)
- Firefly 고급 70(뿔 성 v3N2 5 + 왕관 B 5 + 뿔 성 v4 5 + 숲 큰 것 11장 55), 중간 0크레딧(숲 22 + 뿔 성 8 + 나무 A 6장). 웹 화면 숫자는 9700/10000으로 보였음(새로고침 전일 수 있음).
- Tripo API: 945 → 왕관 40 → 숲 소품 320 → 뿔 성 v4 40 → 숲 큰 것 8개 320 → 나무 3개 120 → 게시판 2개 60 → **남은 45**(모닥불 몫). 그 뒤는 웹 ①(3,550, Smart Mesh 100/개) → 웹 ②(25,000, 쓰기 전 검수에 알림).
- 해골 유적 2D 16장 + 바위 다시 4장 + 사진 벽 4장 = 중간 0크레딧. Firefly 웹 화면 9700/10000(10/07 03:40 다시 읽음). 그 뒤 유적 고급 8장 = 40(화면 숫자는 새로고침해야 바뀜, 다른 세션도 같은 계정을 씀).
- Tripo 웹 ①: 3b 시험 150(HD 55×2 + Smart Mesh 텍스처 20×2) → 3,400/3,550.
- Firefly 도우미 주의: 비율 값은 공백 없는 `{"height":1024,"width":1024}` 그대로(공백이 있으면 고르기가 조용히 실패해 앞 비율로 그려짐 — 바위 A v2가 세로로 나온 까닭).
