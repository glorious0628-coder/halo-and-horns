# 이미지 생성 2 — 인계 (2026-10-12 점심, 세션 정리로 쉼)
## 지금 상태
- **Firefly 큐 비어 있음(생성 중인 것 없음).** 이어받는 세션 = 이미지 개발. 시트 보고는 **최종 검수**(디자인 검수 쉼, 대기 목록 `docs/handoff/state/design_review.md`).
- 오늘 끝·푸시·보고(전부 origin/main): 가방/제작 아이콘 16종(통과) · 게임 아이콘 C(통과) · 새 집 7채 4면(통과) · 무기 4면 84(통과) · 물약 상인 4면(통과) · 성문 등 머리 4면·받침·무기고 뒤(통과) · 밈 5장 High(통과)+GG `EmoGG`(통과) · 밈 후광·뿔 4면 16(통과, PixelHalo 옆면 최종 = `Meme_PixelHalo_{left,right}_final_HQ.png`, right는 left 좌우 뒤집음) · 스티커 17종 High+컷아웃(통과, 올리기 승인됨) · 채팅 말풍선 8 Medium v2(통과, 사용자 고르기 대기) · 빛 성 C2 정면·right·금문 한 짝(통과) · 큰 지도 빛 섬 합성본 ★(통과, 최종 검수에 올림) · **주민 9명 High 정면+뒤·왼·오른 36장(`art/out/s2/npc2_hq/`, 시트 `art/review/s2/npc_residents_4v_a/b.jpg`, 정면 시트는 통과·4면 판정 대기)**.
- approved.json에 밈 5장·4면 기록 푸시함.
## 남은 일(요청 오면)
1. 채팅 말풍선: 사용자가 고른 것 High(5크레딧) — 규칙: 512×256 투명, 장식은 왼쪽 위·오른쪽 위 모서리 64×64 안에만, 위·아래 변 가운데 장식 없음, 꼬리 없음, 글자 없음, 가운데 평평. Medium 파일 `art/out/s2/bubbles/Bubble_<Light·Horns·Pixel·Donut(m2)·Night·Cloud·Flower·Crown(m2)>`, 투명 512×256 `bubbles_cut/`, 시트 `chat_bubbles_8_medium_v2.jpg`. 글 읽힘 칸: 밝은 면 짙은 남색 글, 어두운 면 흰 글.
2. 주민 4면 판정 반려 시 해당 칸 다시. 그 뒤 Tripo는 이미지 생성 3/4.
3. 큰 지도 합성본이 사용자에게 보인 뒤 수정 요청 오면: `art/out/s2/worldmap/WorldMapV2_HaloNew_r2m1_HQ.png`(High 전체) + 옛 지도 `art/ui/UIP_WorldMapV2.png`, 합성은 바다 쪽으로 부드럽게(스크립트는 이 세션 기록: 땅 마스크=파란 바다 아닌 곳 팽창+블러10, `build/img2_next/` 임시).
4. 올리기는 이미지 개발(승인은 최종 검수). 나는 올리지 않음.
## 크레딧
- 오늘 High 합계 약 145장(≈725크레딧) 사용. 어젯밤 약 1,400. 표시 잔액은 Firefly 화면에서 확인(어제 아침 추정 3,400 → 지금 약 2,200~2,700 추정), **500 근처면 최종 검수에 알림**.
## Firefly / 도구 요령 (이어받는 세션용)
- 탭 `seed`(https://firefly.adobe.com/generate/image), `resize_window` 1440x900. **앱 브라우저 창이 보이는 상태여야 렌더·속도 정상**(숨김이면 멈춤/느림 → 최종 검수에 Ctrl+Shift+B 부탁, 로그인은 사용자가). 로그인 풀리면 최종 검수에 알림, 비밀번호 입력 금지.
- helper: `tools/_firefly_helpers.js` 내용을 javascript_exec에 붙여 심기(`__runList` ref 있음 / `__runNoRef`, 품질 value+change 고침 포함, `__qLog`, `__stopList`). 프롬프트 <1000자(넘으면 조용히 실패). 폴링은 한 번에 ≤37초.
- 참조 이미지: `asset_get_presigned_urls`(assets=[{id,sourceType:"acp"}]) downloadUrl(몇 시간 유효), 로컬 파일은 `asset_initialize_file_upload`(path,file_size,media_type) → `curl -L -X PUT` → `asset_finalize_file_upload`(transfer_document) → presignedAssetUrl.
- 결과 받기: `asset_search`(query `*` 또는 프롬프트 글, sortBy createDate, sortOrder desc, limit N; start 없음) → 오래된 것부터 로그 순서와 대조 → presign → curl. 로그엔 '성공'인데 에셋이 없는 칸이 가끔 있음(주민 Folk4_left처럼) → 개수 세어 다시.
- 컷아웃: `py tools/cutout_flat.py <src> <out> --size 512 --fill 0.86 --holes --check <시트>`(장당 ~20초, 한 장씩 백그라운드), 확인 시트는 항상 **자홍 칸 포함**. 푸시는 `py tools/push_paths.py -m "제목" <파일 경로들>`(디렉터리 인자 안 펼쳐짐, 백그라운드).
- 프롬프트·큐 원문: `art/prompts/`(`Meme_*.txt`, `Icon*.txt`, `img2_*queue*.json`), 주민·스티커·말풍선 프롬프트는 이 세션 javascript에서 만든 것이라 파일엔 없음 → 규칙만 기억: 주민 = "Use the attached image as the exact design reference… same face/clothes… add a small thin floating gold halo ring above the head… full-body front view, relaxed A-pose, plain flat medium gray background"; 4면 = "only turn the camera… straight-on at mid-height… BACK / exact LEFT-SIDE (faces right edge) / RIGHT-SIDE".
- **새 규칙(사용자 10/12 16:30, Blender 손보기 경유): 2D 그림(특히 Tripo에 넣는 앞면·4면)에 그림자 금지** — 바닥 그림자·드리운 그림자·진한 음영 없이 고르고 평평한 빛(그림이 그대로 색 맵이 돼 그림자가 굽힘). 프롬프트에 'no shadows, no cast shadow, flat even lighting, no ground shadow' 넣고, 이미 만든 4면 그림(주민·밈·성·소품)에 그림자가 보이면 다시 그리기 대상.
- 규칙: Medium 0크레딧 → 고르기 → High 5크레딧 → 컷아웃 → 시트(밝은·남색·자홍·48px). 빛살 무늬 금지, 사람은 단정한 옷(얼굴·손만), 밈·스티커 글자는 철자 하나하나 확인.
