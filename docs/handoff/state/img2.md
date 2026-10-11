# 이미지 생성 2 — 인계 (2026-10-11 저녁, 검수 지시로 비움)
## 지금 상태
- (10/11 밤) 무기 v2 27장 + 뿔 전사 최종 3장 Medium 완료, 시트 5장·표(`docs/design/weapon_t13_candidates_2026-10-11.md` v2 절) → 검수 보고함. 검수가 고른 칸만 High(5×N). Firefly 품질 선택기: `p.value='medium'`+change 이벤트로 바꿈(클릭 선택은 안 먹음; 확인은 화면 라벨 '중간').
- 벤치 B left2 High 1장 완료·푸시(8326341) — 검수 판정 대기.
- 무기 9종×T1~T3 Medium 27장 생성·푸시(247ff89) — 검수가 고를 칸 대기(고른 것만 나중에 High 5크레딧). 표 `docs/design/weapon_t13_candidates_2026-10-11.md`, 시트 `art/review/s2/weapons_t13_*.jpg`.
- 보고는 검수 `local_d522c0f1-07cf-4db1-b178-5f335a56db7c`(send_message, 인자 session_id).
## 다음 일 (검수 지시 10/11 — 비운 뒤 여기 1)부터 시작)
검수 판정: 벤치 B left2 HQ 통과(approved.json 정리는 내 키만). 무기 27장 Medium은 모양·안전 통과, 그러나 **그림체가 HQ 9종(통통한 장난감·큰 금 장식)과 안 맞아 High 안 감.**
1) 27장 Medium 다시(0크레딧): 같은 진영·직업 HQ 앞면(`art/out/s2/weapons/Weapon_<키>_front_HQ_src.png`; 뿔 전사는 대검이라 빼고 HQ 시트의 통통한 결만 참조)을 스타일 참조로 걸고, 지금 후보 모양(T1 가지·T2 깎은 나무·T3 쇠 보강)은 유지. 굵고 둥근 비율, 짧고 두꺼운 날·손잡이.
2) 단계 차이: T3는 HQ(위 단계 완성형)보다 확실히 소박하게. 대장장이 T3 = 지금 HQ 망치와 거의 같음 → 금 띠·고리 빼고 쇠 띠만 등으로 낮춤.
3) 연금술사 T1~T3: 손에 드는 것만(지팡이 하나). 작은 병은 지팡이에 매달린 것만, 옆에 따로 놓인 병·막대 빼기(Tripo 한 덩어리).
4) 뿔 전사 최종 룩: 대검 HQ 대신 **어두운 한손검**으로 새로(A23-128). Medium 후보 2~3장(HQ 시트의 용암 금·뿔 가드 결 유지) → 시트.
5) 시트 4장(전사·마법사·궁수·중립) + 뿔 전사 최종 시트 → 검수. 검수가 고른 칸만 High(5×N, 30칸 안팎 ≈150크레딧 OK). Tripo 갈 때는 A23-122대로 앞·뒤·좌·우 4장.
## 기다리는 것 (위 다음 일로 대체됨)
- 검수의 무기 칸 선택·High 승인, 뿔 전사 최종(앞·뒤·옆 HQ)을 한손검으로 다시 그릴지 결정(옛 HQ는 대검).
- 이전 큐(빛 성 2차 F1~F4, 새 구역 몬스터, 빛 마을 조감) 상태는 옛 인계 `git log -- docs/handoff/state/img2.md`의 앞 버전 참고(검수가 새 우선순위 줄 때까지 보류).
## Firefly / 도구 메모
- 내장 브라우저 탭 `seed`(firefly.adobe.com/generate/image), **로그인 됨**(10/11 저녁, 사용자). 로그인이 풀리면 사용자가 직접(내가 입력 금지). 새 턴마다 `resize_window` 1440x900. 페이지를 다시 열면 `tools/_firefly_helpers.js`(참조 없음 `__runNoRef`)를 javascript_exec에 붙여 심기. 참조는 `__setRef(url,name)`만 따로 정의(helpers에 있음).
- 품질 선택 `sp-picker[2]`: 클릭이 안 먹으면 `p.value='high'; p.dispatchEvent(new Event('change',{bubbles:true,composed:true}))` 후 라벨 '높음' 확인. 모델은 로그인 뒤 Gemini로 돌아가니 gpt-image-2.5-prism 다시 선택.
- 받기: asset_search(GenAIAsset, createDate) → asset_get_presigned_urls(id,sourceType acp) → curl `downloadUrl`; 참조 업로드 asset_initialize_file_upload(file_size 대략)→curl PUT→asset_finalize_file_upload(filename·directory_asset_id·transfer_document)→presignedAssetUrl.
- 크레딧 표시 4770/10000(10/11 저녁, 다음 재설정 11/4). 500 근처면 검수에 알림.
- 푸시는 `py tools/push_paths.py -m "제목" <경로>`.
