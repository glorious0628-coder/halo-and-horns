# 이미지 생성 2 — 인계 (2026-10-12 새벽)
## 지금 상태 (10/12 오전, 큐 비어 있음)
- 보고: 그림 시트는 **디자인 검수**(list_sessions), 로그인·창 보이기·사용자 질문은 최종 검수. Firefly 로그인됨, 탭 `seed`. **브라우저 창이 보여야 렌더/속도 정상**(숨기면 멈추거나 느림 → 최종 검수에 Ctrl+Shift+B 부탁).
- 오늘 끝·푸시·보고함(전부 디자인 검수 통과 또는 판정 대기): 가방/제작 아이콘 16종(통과, 올리기 이미지 개발) · 게임 아이콘 C(통과) · 새 집 7채 4면(통과) · 무기 4면 84(통과) · 물약 상인 4면(통과) · 성문 등 머리 4면(통과)+받침 Medium(그대로 씀)+무기고 뒤(통과) · 밈 5장 High(통과)+GG `EmoGG` 컷아웃(통과) · **후광·뿔 4면 16장**(`art/out/s2/memes_4v/`, 판정 대기) · **스티커 17종 High+컷아웃**(`stickers_cut/Emo*.png`, 판정 대기) · **채팅 말풍선 8 Medium**(`bubbles_cut/`, 판정 대기·고르기) · **빛 성 C2 정면·right·금문 한 짝**(`halo/castle6/`, 판정 대기) · **큰 지도 빛 섬 High 합성본 ★**(`worldmap/UIP_WorldMapV2_HaloNew_composite.png`, 판정 대기) · 새 집 주민 8명+Folk4 Medium 18장(`npc2/`, 최종 검수 고르기 대기).
- 크레딧: 오늘 High 합계 약 90장(약 450크레딧) 사용(아침 55 + 밈 5·4면 16·스티커 17·성 3·물약 상인 4·등 4·무기고 1·지도 1 …). 표시 잔액은 Firefly 화면에서 확인, 500 근처면 알림.
## 다음 일
- 주민 고른 것 High 정면(+4면 요청 시) / 말풍선 고른 것 High(안쪽 64px 띠 장식 맞춤) / 판정 반려 시 해당 칸 다시.
- 규칙: Medium 0크레딧 → 고르기 → High → `cutout_flat.py --holes` → 확인 시트(밝은·남색·자홍·48px) → 디자인 검수.
- 올리기는 이미지 개발(승인은 최종 검수).
## Firefly / 도구 메모
- 새 턴마다 `resize_window` 1440x900. 페이지를 다시 열면 보강 helper(품질 선택기 value+change, 품질 확인 실패 시 중단)를 javascript_exec에 다시 심기: `__pick(idx,value)`는 idx 2(품질)만 value+change, 나머지는 메뉴 클릭. 반복 실행에는 `setInterval`로 품질 값이 바뀌면 `__stopList=true`(실수 High=5크레딧).
- 참조: 이미 만든 결과 이미지의 `asset_get_presigned_urls` downloadUrl(https://at.adobe.com/…)을 `__setRef`에 그대로(assets 배열에 `{id, sourceType:"acp"}`). 로컬 파일은 asset_initialize_file_upload → curl PUT → finalize.
- 받기: asset_search(query `*`, sortBy createDate, sortOrder desc, limit N) → 시간순 키 매핑(로그 UTC 시각 ≈ asset createDate) → presigned → curl → 눈으로 확인(프롬프트 1000자 초과·참조 없이 나간 경우 걸러냄).
- 폴링은 javascript_exec 안에서 37초 이하 대기. 푸시 `py tools/push_paths.py -m "제목" <경로들>`은 백그라운드로(디렉터리 인자는 안 펼쳐짐, 파일 경로 명시), 끝은 `/tmp/push_*.log` 확인.
- 컷아웃: `py tools/cutout_flat.py <src> <out> --size 512 --fill 0.86 --check <시트>` (장당 ~20초, 긴 건 백그라운드).
- 이 세션 도구: `tools/_weapon_4v_sheet.py`, `_halo_kit_mv_prompts.py`/`_mv_sheet.py`, `_icons_bag_prompts.py`, `_halo_newkit_prompts.py`.
