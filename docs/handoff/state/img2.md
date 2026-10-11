# 이미지 생성 2 — 인계 (2026-10-12 새벽)
## 지금 상태
- 보고: 그림 시트는 **디자인 검수**(list_sessions 'local_a9261aed…'), 로그인·화면·사용자 질문·크레딧 큰 묶음은 최종 검수(local_d522c0f1…).
- Firefly 로그인 정상. 탭 `seed`, 1440x900. 큐 32건 전부 끝(큐 비어 있음).
- 끝·푸시: 무기 High 앞면 28장 + 4면 84장(`art/out/s2/weapons_t13_4v/`) + 마법사 옆면 redo(`*_v2.png`, 대장장이 T3 left, 연금술사 T1 left/right 포함) / 빛 마을 소품 4면 전부(kits_mv·mv2·mv3) / 새 집 7채 4면(`houses_new4/`, Garden6 left_v3, Garden7 back/left/right_v3) / **가방 재료 아이콘 11종 High + 컷아웃**(`icons_bag_hq/`, `icons_bag_cut/` 512 투명, 시트 `art/review/s2/icons_bag_hq_cut_sheet.jpg`) / 게임 아이콘 후보 8장(`gameicon/`) / Glowcap m3·m4 + 망치질 Ring·Target·Ingot Medium 후보(`icons_bag/`, `icons_craft/`, 시트 `glowcap_craft_medium_cands.jpg`).
- 디자인 검수 판정 대기: Glowcap·망치질 Medium 고르기, 가방 아이콘 11종, redo 시트 2장(weapons_4v_redo_side.jpg, houses_new4_redo_v3.jpg), 게임 아이콘 고르기(최종 검수 경유, C_m2 추천·B_m1).
## 다음 일
1. 고른 Glowcap 1 + Craft 3(Ring·Target·Ingot) High(5×4=20) → `tools/cutout_flat.py`(Ring은 가운데 구멍 투명: `--holes`), 64/128px 시트 → 디자인 검수. Craft는 금 ~(255,168,36), 가방 아이콘과 같은 굵은 남색 윤곽선, 광선 없음.
2. 게임 아이콘 고른 안 High.
3. 올리기는 이미지 개발이 함(내가 올리지 않음).
4. 크레딧: 오늘 밤 약 1,400 사용, 표시 잔액 약 3,400 추정(정확치는 Firefly 화면). 500 근처면 알림.
## Firefly / 도구 메모
- 새 턴마다 `resize_window` 1440x900. 페이지를 다시 열면 보강 helper(품질 선택기 value+change, 품질 확인 실패 시 중단)를 javascript_exec에 다시 심기: `__pick(idx,value)`는 idx 2(품질)만 value+change, 나머지는 메뉴 클릭. 반복 실행에는 `setInterval`로 품질 값이 바뀌면 `__stopList=true`(실수 High=5크레딧).
- 참조: 이미 만든 결과 이미지의 `asset_get_presigned_urls` downloadUrl(https://at.adobe.com/…)을 `__setRef`에 그대로(assets 배열에 `{id, sourceType:"acp"}`). 로컬 파일은 asset_initialize_file_upload → curl PUT → finalize.
- 받기: asset_search(query `*`, sortBy createDate, sortOrder desc, limit N) → 시간순 키 매핑(로그 UTC 시각 ≈ asset createDate) → presigned → curl → 눈으로 확인(프롬프트 1000자 초과·참조 없이 나간 경우 걸러냄).
- 폴링은 javascript_exec 안에서 37초 이하 대기. 푸시 `py tools/push_paths.py -m "제목" <경로들>`은 백그라운드로(디렉터리 인자는 안 펼쳐짐, 파일 경로 명시), 끝은 `/tmp/push_*.log` 확인.
- 컷아웃: `py tools/cutout_flat.py <src> <out> --size 512 --fill 0.86 --check <시트>` (장당 ~20초, 긴 건 백그라운드).
- 이 세션 도구: `tools/_weapon_4v_sheet.py`, `_halo_kit_mv_prompts.py`/`_mv_sheet.py`, `_icons_bag_prompts.py`, `_halo_newkit_prompts.py`.
