# 이미지 생성 1 상태 (2026-10-07)

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

## 대기 중
- **조각 v2**(e52a883 시트) — 빛·뿔 조각 둘 다 쓸지 사용자 답(검수 경유) → 고급(5) → Tripo(약 40, 둘째 조각 +40은 승인 필요).
- **다음 3D 가져오기 묶음** `build/import_next/WorldKit_ImportNext.glb`(뿔 성 70×67×58, 빛 성 70×55×66, 앞 -Z) + 왕관 B2 backfix(검수 OK 뒤) — 화면 제어라 다른 것과 모아서, 할 때 검수에 먼저. 만드는 법: `tools/worldkit_combine.py`(spec에 fit 크기) → WorldKit 가져오기 창 한 번 → `execute_luau`로 Model·피벗 정리 → id 기록.
- **3b Tripo**(약 480): 3a를 게임에서 본 뒤.
- **오프닝 콘티**(A23-55, 10/12~14): 욕심으로 왕관이 깨짐("If I can't have it, no one can!"), 얼굴 없는 그림자 손(무섭지 않게, 범인 진영 모름) → 조각이 흩어지며 빛·뿔이 서로 손가락질하는 귀여운 컷.

## 요령
- Firefly: 내장 브라우저에서 `preview_start`로 연 탭(tab-1)이 그려짐("seed" 탭은 빈 화면일 수 있음). 탭을 새로 열면 `tools/firefly_page_helpers.js`를 붙여 넣고 `__ready()` 확인 → `__runList([...])`. 고급은 승인 뒤만.
- git: 다른 세션의 안 커밋한 파일과 겹치면 pull 하지 말고 임시 worktree에서 내 커밋만 cherry-pick 해 push(49fe94c 때처럼).
- approved.json: 들여쓰기 1칸 그대로(`json.dumps(indent=1, ensure_ascii=False)`), 내 키만.
- **computer-use 도구는 확인용으로도 부르지 않기**(`list_granted_applications` 한 번에 사용자 화면 주황 '제어 중'이 턴 끝까지 켜짐, 10/07). 승인된 제어 단계 뒤엔 Esc → 턴 끝 → 검수에 "끝".
- push 거절 때 더 빠른 길: `git merge-tree --write-tree` + `git commit-tree -p origin/main` → `git push origin <새 커밋>:main`(공유 작업 트리를 안 건드림, 5a1eec0).

## 크레딧 (오늘)
- Firefly 고급 10(뿔 성 v3N2 5 + 왕관 B 5), 중간 0크레딧. Tripo 80(뿔 성 40 + 왕관 40) → 남은 905. 왕관 뒤 고치기·숲 목록 0.
