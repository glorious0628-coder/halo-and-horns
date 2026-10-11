# 이미지 생성 2 — 인계 (2026-10-12 새벽)
## 지금 상태
- 보고: 그림 시트는 **디자인 검수**(list_sessions 'local_a9261aed…'), 로그인·화면·사용자 질문·크레딧 큰 묶음은 최종 검수(local_d522c0f1…).
- Firefly 로그인 정상(10/12 사용자가 풀어 줌, PC 재시작 때 풀렸었음). 탭 `seed`, 1440x900.
- 끝·푸시: 무기 High 앞면 28장 + **4면 84장**(`art/out/s2/weapons_t13_4v/`, 손잡이 아래 통일, 칼 5자루 앞면 돌림) / 빛 마을 소품 Tripo 몫 전부 4면(kits_mv·kits_mv2·kits_mv3, 종·벽등 머리·화분·화단·난간 덤불·물뿌리개 right v2·Planter_E left_v3) / 새 집 7채 4면(`houses_new4/`) / 가방 재료 아이콘 12개 Medium 후보(`icons_bag/`) / 게임 아이콘 후보 8장(`gameicon/`).
- 디자인 검수 판정 대기: 무기 4면 전사·마법사·궁수·중립 시트, 새 집 시트, 가방 아이콘 고르기(→ 고른 것 High 12×5), 게임 아이콘 고르기.
## 다음 일
1. 가방 아이콘: 디자인 검수가 고른 칸만 High(5×12=60) → `tools/cutout_flat.py`로 잘라내기, 밝은·어두운 바탕 + 48px 확인 시트 → 디자인 검수. 올리기는 이미지 개발.
2. 요청 오면: 마법사 고리 머리 옆면 6장 다시(LightMage T1 left·right, DarkMage T1·T2 left·right; 정확히 90도 옆, 30크레딧), 게임 아이콘 고른 안 High.
3. 크레딧: 오늘 밤 약 1,150 사용, 표시 잔액 약 3,650(10/11 저녁 4,770 기준, 정확치는 Firefly 화면). 500 근처면 알림.
## Firefly / 도구 메모
- 새 턴마다 `resize_window` 1440x900. 페이지를 다시 열면 `tools/_firefly_helpers.js` 대신 이번 세션 보강판(품질 선택기 value+change, 품질 확인 실패 시 중단, 모델 확인)을 javascript_exec에 다시 심기: `__pick(idx,value)`는 idx 2(품질)만 value 지정+change 이벤트, 나머지는 메뉴 클릭. 반복 실행에는 `setInterval`로 품질 값이 바뀌면 `__stopList=true`(실수 High=5크레딧).
- 참조: 이미 만든 결과 이미지의 `asset_get_presigned_urls` downloadUrl(https://at.adobe.com/…)을 `__setRef`에 그대로. 로컬 파일은 asset_initialize_file_upload → curl PUT → finalize(presigned URL 몇 시간 유효).
- 받기: asset_search(GenAIAsset, createDate desc, limit N) → 시간순(오래된 것부터) 키 매핑 → asset_get_presigned_urls → curl. 로그 시각과 asset createDate를 맞춰 보고(로그엔 '성공'인데 결과가 없는 경우가 있음: 프롬프트 1000자 초과·참조 없이 나감) 결과를 눈으로 확인.
- 폴링은 sleep 38초 이하(숨은 창은 더 길면 타임아웃). 푸시 `py tools/push_paths.py -m "제목" <경로>`는 백그라운드로(2분 넘게 걸림), 끝은 `git fetch` + `git log origin/main`로 확인.
- 이 세션 도구: `tools/_weapon_4v_sheet.py`, `_halo_kit_mv_prompts.py`/`_mv_sheet.py`, `_weapon_ratio_check.py`(참고용; 가지 검은 잘못 잼), `_icons_bag_prompts.py`, `_halo_newkit_prompts.py`.
