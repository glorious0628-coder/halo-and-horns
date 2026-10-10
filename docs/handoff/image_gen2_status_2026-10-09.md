# 이미지 생성 2 상태 (2026-10-09 밤)

## 끝난 것
- 빛 마을 건물 8개 뒤·좌·우 24장 (고급 5크레딧 × 24 = 120) — Gate, Tower, Cathedral, DomeHouseA, DomeHouseB, Shop, Statue, ArchBridge. 파일 `art/out/s2/halo/HaloProp_<이름>_{front,back,left,right}_HQ_src.png`(1024², 회색 바탕), 시트 `art/review/s2/halo_mv_<이름>.jpg`(`py tools/_img2_sheet.py <이름>`), 프롬프트 `art/prompts/HaloProp_<이름>_{back,left,right}.txt`(`tools/_halo_prop_mv_prompts.py`, 둥근 집·가게 차양은 앞쪽 벽에만 평평하게 — 검수 지적 반영).
- 분수(Fountain)는 앞면만(검수 OK).

## 방법 (새 Firefly 화면, 10/09)
- 프롬프트 칸이 textarea가 아니라 ProseMirror(`div.ProseMirror[contenteditable]`): `focus` → `execCommand('selectAll')` → `execCommand('insertText')`. 3번째 선택(품질)은 low/medium/high 그대로, 모델 값 `openai:firefly:colligo:gpt-image-2.5-prism`(화면 이름 "GPT Image 2.5 Sunburst"), 비율 1:1 값 `{"height":1024,"width":1024}`.
- 참조: Adobe MCP로 앞면 PNG 올리기(asset_initialize_file_upload → curl PUT → finalize) → presignedAssetUrl을 페이지에서 fetch → `input#file-input`에 넣기.
- 결과 받기: asset_search(GenAIAsset, 이미지 mediaType 필터, createDate desc)가 소리 세션 오디오·이미지 생성 1 그림과 섞이므로 query/시각으로 구분 → asset_get_presigned_urls의 **downloadUrl**(1024 PNG; renditionURL은 600px JPEG라 쓰지 말 것).
- 한 장 약 50~60초. 기다릴 때 javascript_tool은 45초 안에 끝나야 함.

- 한 장짜리 소품 11개(고급): `art/out/s2/halo/HaloProp_<이름>_front_HQ_src.png`, 시트 `art/review/s2/halo_props_singles_sheet.jpg`. 구름 덤불·바다 바위 아치·둥근 나무는 첫 판이 어긋나(화분·탑·받침대가 붙음) v2로 다시 그림: `..._front_v2_HQ_src.png`, 시트 `halo_props_redo_sheet.jpg` → 이 셋은 v2를 쓸 것.
- 뿔 성채 시안 1장(고급): `art/out/s2/horns/HornsProp_Castle_front_HQ_src.png`, 시트 `art/review/s2/horns_castle_front.jpg`, 프롬프트 `art/prompts/HornsProp_Castle_front.txt`(뿔 마을 시안 문 패널을 스타일 참조).

## 크레딧
- 오늘 밤 고급: 뒤·좌·우 24 + 소품 11 + 성채 1 + 소품 다시 3 = 39장 = 195크레딧. 잔액은 마지막 확인값 7885(10/09 06:29 UTC 계정 전환 전) 기준 약 7,700대 추정 — 정확한 값은 Firefly 화면에서 다음에 확인.

## 남은 것 (검수 큐)
1. 뿔 마을 소품 멀티뷰·한 장짜리(`docs/design/horns_town_plan_2026-10-09.md` 표): 문·감시탑·전쟁 천막·노점·나무집·돌다리는 멀티뷰, 모닥불·말뚝 울타리·화로·등불·깃대·침엽수·현무암 기둥·통/상자는 한 장.

## 10/10 아침 추가
- 빛 마을 가게 간판 4종(고급, 물약 v2·빵집·주스·꽃; 장난감은 검수가 뺌): `art/out/s2/halo/HaloSign_*_front_HQ_src.png`, 시트 `art/review/s2/halo_signs_sheet.jpg`. 프롬프트 `tools/_halo_npc_sign_prompts.py`.
- 빛 마을 NPC 5명 전신 후보(중간): `art/out/s2/npc/NPC_Halo<이름>_{A,B}_src.png`(+FlowerGirl C·D), 시트 `art/review/s2/halo_npc_candidates_sheet.jpg`, 추천 `halo_npc_picks_sheet.jpg`. 사용자 승인 대기 → 승인되면 앞면을 참조로 뒤·좌·우(고급).
- 뿔 마을: 앞면 22 + 성채 1(고급) → `art/out/s2/horns/HornsProp_<이름>_front_HQ_src.png`(+ v2: RockColumnB·C·Pine), 건물 9개 + 성채 뒤·좌·우 30장 → `..._{back,left,right}_HQ_src.png`, 시트 `art/review/s2/horns_*`. 도구 `tools/_horns_prop_prompts.py`, `_horns_prop_mv_prompts.py`, `_img2_sheet_horns.py`. StallSmith는 앞면만(뒤·좌·우 건너뜀, 검수 결정 대기).
- 방법 메모(10/10): 숨김 창에서도 프롬프트 입력·생성은 돌아감(새로고침 금지). Adobe 참조 링크(at.adobe.com)는 몇 시간 뒤 403 → 다시 올림. 새 asset_search는 이미지 mediaType 필터 + 시각 순서로 매핑.
- 크레딧(10/10 아침까지 고급): 간판 6 + 뿔 앞면 18+3 + 성채 1 + 뒤·좌·우 30 + 빛 소품 v2 등 = 약 300(어젯밤 분 제외). 화면 잔액은 다음에 확인.
