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

## 덩어리 진행
- 1 Paladin: 최종 검수 통과 → Blender 맞춤 끝 `<이름>_HD_fit.glb`(+ .json): T1 3 / T2 3.5 / T3 4 스터드, 원점 = 손잡이 가운데(폭 단면으로 찾음, 길이의 0.15~0.19), +Y 칼끝, 앞면 Roblox -Z. 확인 `art/review/weapon_design/chunk1_Paladin_fit.png`. 도구 `tools/weapon_hd_fit.py`, `tools/weapon_fit_check.py` + `tools/weapon_fit_check_sheet.py`.
- 2 LightMage: 최종 검수 통과(T2 각진 보석 허용) → 맞춤 끝(--kind staff --grip 0.45, 길이 3/3.5/4), 확인 `chunk2_LightMage_fit.png`. 닫힌 틈(T1 220px·T2 4,148px)은 2D에도 있는 고리 틈. T2 구슬이 3D에선 각진 보석.

- 3 Ranger: 통과 → 맞춤 끝(--kind bow --grip 0.5), 확인 `chunk3_Ranger_fit.png`. 각 _HD_fit.json에 code_len(`tools/weapon_code_len.py`, 최종 검수: 넣을 때 코드가 MeshPart 크기 맞춤 = 개발 1).
- 4~6 Horns: 8개 통과 → 맞춤 끝(확인 `chunk_Horns_fit_a/b.png`). Berserker_T3 옛 HD 떨어짐(바늘구멍) → 새 HD(task 96d262d9, `_HD2_src.glb`, 6,852 삼각형, 구멍 0) → 맞춤 끝(`--guard-mult 2.5`, 확인 `Berserker_T3_HD2_fit.png`), 최종 검수 판정 대기.
- 7~9 Neutral: 8개 통과 → 맞춤 끝(망치·몽둥이 0.3, 물병 지팡이 0.45; 확인 `chunk_Neutral_fit_a/b.png`). Blacksmith_T2 옛 HD·새 HD(task 614dca14) 둘 다 양쪽 끝 둥근 구리판 → 원인 = 2D 오른쪽 면이 끝을 정면으로 안 봄(`Blacksmith_T2_2d_heads.jpg`) → 2D 옆면 다시 그리기 제안.
- Tripo 점수: 110 씀(잔액 18,320 → 18,210). 받기 = 페이지 fetch → 127.0.0.1 임시 서버(x-suffix 헤더로 `_HD2_src`). 닫힌 틈 = 활과 시위 사이(정상). T3 시위가 아주 가늘어 틈이 안 닫히지만 끝까지 이어짐.
- 주의: 게임 코드(CharacterVisuals tierLen)는 Config Length를 그대로 안 씀: 칼 ≈3.85~4.55, 지팡이 = 아바타 키 0.65~0.75, 활 3.1~4.9 스터드. GLB는 Config Length로 맞췄음(최종 검수 지시) — 넣을 때 MeshPart 크기로 맞추면 됨.

## 다음
- 최종 검수의 Paladin 판정 → 통과면 Blender 크기·피벗·방향(Config.Weapons Length, 피벗 = 손잡이 중앙, +Y 칼끝).
- 덩어리 2 LightMage T1~T3, 3 Ranger T1~T3 → Horns → Neutral (렌더는 `weapon_hd_views.py`, 시트는 `weapon_chunk_sheet.py`).
- 밈 2개 2D(Codex).
- 점수 쓴 것: 0. ChatGPT 그림 12장.
