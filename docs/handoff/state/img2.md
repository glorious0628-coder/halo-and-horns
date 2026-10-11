# 이미지 생성 2 — 인계 (2026-10-12 새벽)
## 지금 상태
- 보고: 그림 시트는 **디자인 검수**(list_sessions 'local_a9261aed…'), 로그인·화면·사용자 질문·크레딧 큰 묶음은 최종 검수(local_d522c0f1…).
- 10/12 아침: PC 재시작으로 앱 브라우저가 새로 열림, 탭 `seed`(firefly.adobe.com/generate/image). 창이 숨김이라 페이지가 렌더 안 됨 → 사용자가 Ctrl+Shift+B로 창을 보이게 해야 시작 가능(최종 검수가 사용자 복귀 후 부탁). 다음 큐 6건은 `art/prompts/img2_next_queue_2026-10-12.json`(ref는 이름 → Medium/Garden7 front/GameIcon_C_m2의 presign URL을 asset_search로 새로 받아 넣기). 이전 큐 32건은 전부 끝.
- 끝·푸시: 무기 High 앞면 28장 + 4면 84장(`art/out/s2/weapons_t13_4v/`) + 마법사 옆면 redo(`*_v2.png`, 대장장이 T3 left, 연금술사 T1 left/right 포함) / 빛 마을 소품 4면 전부(kits_mv·mv2·mv3) / 새 집 7채 4면(`houses_new4/`, Garden6 left_v3, Garden7 back/left/right_v3) / **가방 재료 아이콘 11종 High + 컷아웃**(`icons_bag_hq/`, `icons_bag_cut/` 512 투명, 시트 `art/review/s2/icons_bag_hq_cut_sheet.jpg`) / 게임 아이콘 후보 8장(`gameicon/`) / Glowcap m3·m4 + 망치질 Ring·Target·Ingot Medium 후보(`icons_bag/`, `icons_craft/`, 시트 `glowcap_craft_medium_cands.jpg`).
- 디자인 검수 판정 대기: Glowcap·망치질 Medium 고르기, 가방 아이콘 11종, redo 시트 2장(weapons_4v_redo_side.jpg, houses_new4_redo_v3.jpg), 게임 아이콘 고르기(최종 검수 경유, C_m2 추천·B_m1).
## 다음 일 (10/12 PC 꺼짐 전 정리 — 새 Generate 안 함, Firefly에서 만든 것은 전부 내려받아 푸시 끝)
- 디자인 검수 판정(10/12): 가방 아이콘 11종 컷아웃 통과(올리기 승인은 최종 검수 경유 → 이미지 개발). 무기 옆면 9장 통과(무기 84장 4면 끝). Garden6 left_v3, Garden7 back·left 통과.
1. **Garden7 right 한 장 더**(5 크레딧): 발코니를 맨 위 창 층(y≈425, 앞·뒤·왼과 같은 높이)으로 올리고, 그 아래 가운데 층은 아치 창 + 꽃상자. 참조 = Garden7 front(`gVvrKEvoqthUOMHf` presign 만료 시 asset_search로 다시), 이전 right_v3 프롬프트 수정. 결과 `HaloNewHouse_Garden7_right_v4.png`. 통과하면 새 집 7채 4면 끝 → Tripo는 이미지 생성 3(집 장식).
2. **고른 High 4장(20크레딧)**: Glowcap **m4**, **CraftRing m1**, **CraftTarget m1**, **CraftIngot m1** (Medium 파일 `icons_bag/IconGlowcap_m4.png`, `icons_craft/Craft*_m1.png`; 프롬프트 `art/prompts/IconGlowcap.txt` + Craft 큐 프롬프트, 참조 = 고른 Medium). High로 받아 `tools/cutout_flat.py`(Ring은 `--holes` 가운데 투명, 바깥 남색 외곽선 유지) → 밝은·어두운 바탕 + 64·128px 시트에 가방 아이콘 11종과 함께 → 디자인 검수. Craft는 금 ~(255,168,36), 광선 없음.
3. **게임 아이콘 = C_m2 확정(SPEC A23-139)**: High 1장(5) → 512×512 마무리(네모 꽉 채움, 투명 아님, 글자 없음) + 150px 줄인 것 같이 시트 → 디자인 검수. 올리기는 최종 검수 승인.
3b. **새 아이콘 5종(디자인 검수 10/12)**: IconPetTreat, IconMightTonic(빨강/주황·불꽃 방울 마개), IconGuardTonic(파랑·방패 마개), IconLuckyTonic(초록·네잎클로버 마개), IconWisdomTonic(보라·별 마개). 물약 4병은 병 모양 하나(둥근 플라스크+굵은 목, 체력·마나 병과 겹치지 않게). 프롬프트 `art/prompts/Icon<이름>_m1/m2.txt`, 큐 `art/prompts/img2_icons_bag2_queue_2026-10-12.json`(ref=IconJelly `RieuC2wy2mPEtait`, 만료 시 새로). Medium 2장씩(10) 한 시트 → 디자인 검수가 고름 → High 5장(25) → 컷아웃(Inner 76~436) + 48px 시트(Glowcap·Craft·CrownDust와 한 장). 큐 순서: 맨 앞 6건 → 이 10건 Medium 먼저 돌려도 됨(0크레딧).
4. 올리기는 이미지 개발이 함(내가 올리지 않음).
5. 크레딧: 오늘 밤 약 1,400 사용, 표시 잔액 약 3,400 추정(정확치는 Firefly 화면). 500 근처면 알림.
## Firefly / 도구 메모
- 새 턴마다 `resize_window` 1440x900. 페이지를 다시 열면 보강 helper(품질 선택기 value+change, 품질 확인 실패 시 중단)를 javascript_exec에 다시 심기: `__pick(idx,value)`는 idx 2(품질)만 value+change, 나머지는 메뉴 클릭. 반복 실행에는 `setInterval`로 품질 값이 바뀌면 `__stopList=true`(실수 High=5크레딧).
- 참조: 이미 만든 결과 이미지의 `asset_get_presigned_urls` downloadUrl(https://at.adobe.com/…)을 `__setRef`에 그대로(assets 배열에 `{id, sourceType:"acp"}`). 로컬 파일은 asset_initialize_file_upload → curl PUT → finalize.
- 받기: asset_search(query `*`, sortBy createDate, sortOrder desc, limit N) → 시간순 키 매핑(로그 UTC 시각 ≈ asset createDate) → presigned → curl → 눈으로 확인(프롬프트 1000자 초과·참조 없이 나간 경우 걸러냄).
- 폴링은 javascript_exec 안에서 37초 이하 대기. 푸시 `py tools/push_paths.py -m "제목" <경로들>`은 백그라운드로(디렉터리 인자는 안 펼쳐짐, 파일 경로 명시), 끝은 `/tmp/push_*.log` 확인.
- 컷아웃: `py tools/cutout_flat.py <src> <out> --size 512 --fill 0.86 --check <시트>` (장당 ~20초, 긴 건 백그라운드).
- 이 세션 도구: `tools/_weapon_4v_sheet.py`, `_halo_kit_mv_prompts.py`/`_mv_sheet.py`, `_icons_bag_prompts.py`, `_halo_newkit_prompts.py`.
