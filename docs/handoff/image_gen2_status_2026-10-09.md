# 이미지 생성 2 상태 (2026-10-09 밤)

## 끝난 것
- 빛 마을 건물 8개 뒤·좌·우 24장 (고급 5크레딧 × 24 = 120) — Gate, Tower, Cathedral, DomeHouseA, DomeHouseB, Shop, Statue, ArchBridge. 파일 `art/out/s2/halo/HaloProp_<이름>_{front,back,left,right}_HQ_src.png`(1024², 회색 바탕), 시트 `art/review/s2/halo_mv_<이름>.jpg`(`py tools/_img2_sheet.py <이름>`), 프롬프트 `art/prompts/HaloProp_<이름>_{back,left,right}.txt`(`tools/_halo_prop_mv_prompts.py`, 둥근 집·가게 차양은 앞쪽 벽에만 평평하게 — 검수 지적 반영).
- 분수(Fountain)는 앞면만(검수 OK).

## 방법 (새 Firefly 화면, 10/09)
- 프롬프트 칸이 textarea가 아니라 ProseMirror(`div.ProseMirror[contenteditable]`): `focus` → `execCommand('selectAll')` → `execCommand('insertText')`. 3번째 선택(품질)은 low/medium/high 그대로, 모델 값 `openai:firefly:colligo:gpt-image-2.5-prism`(화면 이름 "GPT Image 2.5 Sunburst"), 비율 1:1 값 `{"height":1024,"width":1024}`.
- 참조: Adobe MCP로 앞면 PNG 올리기(asset_initialize_file_upload → curl PUT → finalize) → presignedAssetUrl을 페이지에서 fetch → `input#file-input`에 넣기.
- 결과 받기: asset_search(GenAIAsset, 이미지 mediaType 필터, createDate desc)가 소리 세션 오디오·이미지 생성 1 그림과 섞이므로 query/시각으로 구분 → asset_get_presigned_urls의 **downloadUrl**(1024 PNG; renditionURL은 600px JPEG라 쓰지 말 것).
- 한 장 약 50~60초. 기다릴 때 javascript_tool은 45초 안에 끝나야 함.

## 크레딧
- 이번 묶음 120(고급 24장) + 시험 포함 총 120. 잔액은 마지막 확인값 7885(10/09 06:29 UTC 계정 전환 전) 기준 약 7,700대 추정 — 정확한 값은 Firefly 화면에서 다음에 확인.

## 남은 것 (검수 큐)
1. 한 장짜리 소품 11개(앞면 20장 중 건물 9개를 뺀 나머지) — `art/prompts/HaloProp_{Balustrade,BannerPole,CloudBush,FarArch,Islet,Lantern,Planter,PotFlowers,RoundTree,Stairs,Topiary}_front.txt`.
2. 뿔 성채 시안 1장(고급) — 보라 현무암·붉은 천·큰 뿔·용암 빛, 빛살·글씨·사람 없음. 그다음 뿔 마을 소품 멀티뷰(`docs/design/horns_town_plan_2026-10-09.md`).
