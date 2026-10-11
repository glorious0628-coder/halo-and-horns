# 이미지 생성 2 — 인계 (2026-10-11 밤, PC 재시작 뒤)
## 지금 상태
- 보고 대상: 그림 시트는 **디자인 검수**(list_sessions), 로그인·화면·사용자 질문은 최종 검수(=옛 모든 것 검수 local_d522c0f1…).
- 끝·푸시함: 무기 v2 27장+뿔 최종 b / 무기 High 앞면 28장(`art/out/s2/weapons_t13_hq/`, dc6684b2) / 빛 마을 소품 4면 High 7종(꽃덤불·채집덤불·벽등·벌통·망원경·이젤·종 걸이, `art/out/s2/halo/kits_mv/`) / Tripo 몫 6종(흰 바위 a·b·c·빵 바구니·물뿌리개·생울타리, `kits_mv2/`, 2ea2872). 설명 `docs/design/halo_newkits_2d_2026-10-11.md`, `weapon_t13_candidates_2026-10-11.md`.
- **Firefly 로그인이 PC 재시작으로 풀림(10/11 밤)** → 최종 검수에 요청함. 사용자가 로그인하면 이어감.
## 다음 일
1. 이미지 생성 4 Tripo 묶음 2 중 4면이 없는 8종의 뒤·왼·오른 High(앞면 HQ 있음, 참조로): PotFlowers A·C·D(`art/out/s2/halo/variants4/HaloVar4_*_HQ_src.png`), E·F(`variants/HaloVar3_*`), Planter A·D(variants4)·E(variants). 8종×3=24장=120크레딧. 앞면 HQ 8장은 Adobe에 올려둠(presigned URL은 세션 안에서만 확인). '종 4면'·63장 목록은 최종 검수 답 대기.
2. Beehive 지붕 박공 맞춤은 안 함(파트로 만듦, 검수 결정).
3. 무기 High 앞면 승인 뒤 → Tripo용 뒤·왼·오른 4면(방향: 검 T2·T3·Berserker T3 손잡이 위, 가지 검·지팡이 반대).
4. 크레딧 약 4,350 남음(밤새 약 415 사용). 500 근처면 알림.
## Firefly / 도구 메모
- 내장 브라우저 탭 `seed`(firefly.adobe.com/generate/image), 새 턴마다 `resize_window` 1440x900. 페이지를 다시 열면 `tools/_firefly_helpers.js`를 javascript_exec에 붙여 심음(`__runList`; `__setRef`는 URL을 fetch해 올림).
- 품질 선택기: **클릭 안 먹음** → `p=__deepAll('sp-picker')[2]; p.open=false; p.value='medium'|'high'; p.dispatchEvent(new Event('change',{bubbles:true,composed:true}))`. 반복 실행에는 interval로 값이 바뀌면 `__stopList=true`(실수 High=5크레딧). 모델 pick은 `__pick(0,'openai:firefly:colligo:gpt-image-2.5-prism')`.
- 참조는 이전에 만든 결과 이미지의 `asset_get_presigned_urls` downloadUrl(at.adobe.com)을 그대로 `__setRef`에 넣으면 됨(재업로드 불필요). 로컬 파일은 asset_initialize_file_upload → curl PUT → finalize.
- 받기: asset_search(GenAIAsset, createDate desc, limit N) → 시간순으로 키 매핑 → asset_get_presigned_urls → curl downloadUrl. '클릭'만 기록되고 결과가 없는 경우가 있으니 로그 시각과 asset createDate를 맞춰 보고, 결과를 눈으로 확인(참조 없이 나간 엉뚱한 그림 사례 있음).
- 폴링은 sleep 40초 이하(숨은 창은 더 길면 타임아웃). 푸시는 `py tools/push_paths.py -m "제목" <경로>`(백그라운드로, 2분 넘게 걸림 → 완료는 git fetch로 확인).
