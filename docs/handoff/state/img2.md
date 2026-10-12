# 이미지 생성 2 — 인계 (2026-10-12 새벽)
## 지금 상태 (10/12 오전)
- 보고: 그림 시트는 **디자인 검수**(list_sessions), 로그인·화면·사용자 질문은 최종 검수. Firefly 로그인됨, 탭 `seed`(창은 보이게 유지돼야 렌더됨), 큐 비어 있음.
- 끝·푸시·보고함: 가방 아이콘 11종 High+컷아웃(통과) / Glowcap·CraftRing·Target·Ingot High+컷아웃(`icons_bag_cut/`, 시트 `icons_new_batch_cut_sheet.jpg`) / 게임 아이콘 C High(`gameicon/GameIcon_C_512.png`·`_150.png`, 시트 `gameicon_C_hq_sheet.jpg`) / Garden7 right v4(`garden7_4v_v4.jpg`, 발코니 위치 왼쪽 가장자리라 판정 대기) / 새 아이콘 5종 Medium 10장(`icons_bag2/`, 시트 `icons_bag2_medium_cands.jpg`).
- 크레딧: 오늘 아침 High 6장 사용(30). 어젯밤 합산 약 1,430 사용, 표시 잔액은 Firefly 화면에서 확인(약 3,400 추정). 500 근처면 알림.
## 다음 일
1. 디자인 검수가 새 아이콘 5종 Medium에서 고르면 → 각각 High(5×5=25, ref=고른 Medium presign) → 컷아웃(`tools/cutout_flat.py`, 필요시 Inner 76~436 맞춤) + 48px 시트(앞 묶음과 한 장) → 디자인 검수.
2. Garden7 right v4 판정: 안 되면 1장 더(5크레딧). 통과하면 새 집 7채 4면 끝 → Tripo는 이미지 생성 3.
3. 게임 아이콘·아이콘 올리기는 최종 검수 승인 → 이미지 개발이 함(내가 올리지 않음).
## Firefly / 도구 메모
- 새 턴마다 `resize_window` 1440x900. 페이지를 다시 열면 보강 helper(품질 선택기 value+change, 품질 확인 실패 시 중단)를 javascript_exec에 다시 심기: `__pick(idx,value)`는 idx 2(품질)만 value+change, 나머지는 메뉴 클릭. 반복 실행에는 `setInterval`로 품질 값이 바뀌면 `__stopList=true`(실수 High=5크레딧).
- 참조: 이미 만든 결과 이미지의 `asset_get_presigned_urls` downloadUrl(https://at.adobe.com/…)을 `__setRef`에 그대로(assets 배열에 `{id, sourceType:"acp"}`). 로컬 파일은 asset_initialize_file_upload → curl PUT → finalize.
- 받기: asset_search(query `*`, sortBy createDate, sortOrder desc, limit N) → 시간순 키 매핑(로그 UTC 시각 ≈ asset createDate) → presigned → curl → 눈으로 확인(프롬프트 1000자 초과·참조 없이 나간 경우 걸러냄).
- 폴링은 javascript_exec 안에서 37초 이하 대기. 푸시 `py tools/push_paths.py -m "제목" <경로들>`은 백그라운드로(디렉터리 인자는 안 펼쳐짐, 파일 경로 명시), 끝은 `/tmp/push_*.log` 확인.
- 컷아웃: `py tools/cutout_flat.py <src> <out> --size 512 --fill 0.86 --check <시트>` (장당 ~20초, 긴 건 백그라운드).
- 이 세션 도구: `tools/_weapon_4v_sheet.py`, `_halo_kit_mv_prompts.py`/`_mv_sheet.py`, `_icons_bag_prompts.py`, `_halo_newkit_prompts.py`.
