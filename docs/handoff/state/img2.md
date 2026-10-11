# 이미지 생성 2 — 인계 (2026-10-11 저녁, 검수 지시로 비움)
## 지금 상태
- 벤치 B left2 High 1장 완료·푸시(8326341) — 검수 판정 대기.
- 무기 9종×T1~T3 Medium 27장 생성·푸시(247ff89) — 검수가 고를 칸 대기(고른 것만 나중에 High 5크레딧). 표 `docs/design/weapon_t13_candidates_2026-10-11.md`, 시트 `art/review/s2/weapons_t13_*.jpg`.
- 보고는 검수 `local_d522c0f1-07cf-4db1-b178-5f335a56db7c`(send_message, 인자 session_id).
## 기다리는 것
- 검수의 무기 칸 선택·High 승인, 뿔 전사 최종(앞·뒤·옆 HQ)을 한손검으로 다시 그릴지 결정(옛 HQ는 대검).
- 이전 큐(빛 성 2차 F1~F4, 새 구역 몬스터, 빛 마을 조감) 상태는 옛 인계 `git log -- docs/handoff/state/img2.md`의 앞 버전 참고(검수가 새 우선순위 줄 때까지 보류).
## Firefly / 도구 메모
- 내장 브라우저 탭 `seed`(firefly.adobe.com/generate/image), **로그인 됨**(10/11 저녁, 사용자). 로그인이 풀리면 사용자가 직접(내가 입력 금지). 새 턴마다 `resize_window` 1440x900. 페이지를 다시 열면 `tools/_firefly_helpers.js`(참조 없음 `__runNoRef`)를 javascript_exec에 붙여 심기. 참조는 `__setRef(url,name)`만 따로 정의(helpers에 있음).
- 품질 선택 `sp-picker[2]`: 클릭이 안 먹으면 `p.value='high'; p.dispatchEvent(new Event('change',{bubbles:true,composed:true}))` 후 라벨 '높음' 확인. 모델은 로그인 뒤 Gemini로 돌아가니 gpt-image-2.5-prism 다시 선택.
- 받기: asset_search(GenAIAsset, createDate) → asset_get_presigned_urls(id,sourceType acp) → curl `downloadUrl`; 참조 업로드 asset_initialize_file_upload(file_size 대략)→curl PUT→asset_finalize_file_upload(filename·directory_asset_id·transfer_document)→presignedAssetUrl.
- 크레딧 표시 4770/10000(10/11 저녁, 다음 재설정 11/4). 500 근처면 검수에 알림.
- 푸시는 `py tools/push_paths.py -m "제목" <경로>`.
