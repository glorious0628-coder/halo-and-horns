# 무기 디자인 — 상태 (10/14 저녁)

역할 파일: `docs/handoff/role_prompts/18_weapon_design.md` (A23-187). 보고 = 최종 검수.

## 최종 검수 결정 (10/14)
- A: 옛 HD 28개(10/12, 조명 제거 꺼짐·폴리곤 15000)를 0점으로 다시 받아 하나씩 판정. 떨어지는 것만 A23-174 설정으로 새로(개수·점수 먼저 최종 검수에).
- B: '진함' 13개도 옛 HD 먼저 판정 → HD에 그림자가 구워져 보이면 그것만 Codex 다시 그리기 → 새 HD.
- 밈 2(Frying Pan·Rubber Chicken) = 2D부터 Codex. 순서: Paladin → 나머지 Halo → Horns → Neutral. 3개마다 시트 한 장.

## 끝낸 것
- 옛 HD 28개 다시 받음(0점, 잔액 18,375 그대로): `art/models/tripo/weapons/<이름>/<이름>_HD_src.glb` (디스크만, git에 안 올림 ≈305 MB). records.json 각 `*_web_hd_mv4`에 `web_redownload` 한 줄.
  - 받는 법: Chrome 확장 javascript_tool이 서명 주소를 가림 → 페이지에서 `/ko/workspace/generate/<task>` 로 router.push → `$pinia…['feature-workspace'].current.latest.model_url` fetch → `http://127.0.0.1:8765/`(scratch 임시 서버, x-name 헤더) POST. 한 번 부를 때 45초 넘으면 시간 초과 → `.then`으로 뒤에서 돌림.
- 판정 시트 덩어리 1 Paladin: `art/review/weapon_design/chunk1_Paladin.jpg` (+ 개별 `Paladin_T{1,2,3}_sheet.jpg`). 셋 다 비침 0, 삼각형 12,825~14,746. 내 판정: 통과(T1 3D가 잎 1개·옹이 조금 더, T3 칼날 홈이 2D보다 조금 더 어두움). T2는 최종 검수 통과.
- Codex 그림자 없는 다시 그리기 3개(T3: Paladin·LightMage·Ranger) 4면 = `art/out/s2/weapons_t13_4v_ns/`, 시트 `art/review/weapon_design/ns_redraw_T3_3.jpg`. 문제: Ranger_T3 새 뒷면 시위가 오른쪽(옛 뒷면은 왼쪽 = 거울) → 쓰려면 다시. 결정 B로 지금은 '옛 HD가 떨어지면'만 씀.
- 도구: `tools/weapon_hd_views.py`(Blender 렌더), `tools/weapon_hd_sheet.py`(무기 하나), `tools/weapon_chunk_sheet.py`(3개 한 장), `tools/weapon_ns_sheet.py`(옛/새 2D). 렌더 PNG(`art/review/weapon_design/<직업_T>/v_*.png`)는 git에 안 올림.

## 다음
- 최종 검수의 Paladin 판정 → 통과면 Blender 크기·피벗·방향(Config.Weapons Length, 피벗 = 손잡이 중앙, +Y 칼끝).
- 덩어리 2 LightMage T1~T3, 3 Ranger T1~T3 → Horns → Neutral (렌더는 `weapon_hd_views.py`, 시트는 `weapon_chunk_sheet.py`).
- 밈 2개 2D(Codex).
- 점수 쓴 것: 0. ChatGPT 그림 12장.
