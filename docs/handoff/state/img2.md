# 이미지 생성 2 — 인계 (10/14 10:30, ⛔ 전부 멈춤)
## 10/14 10:30 (맨 위 = 이것부터)
- **⛔ 사용자 지시로 전부 멈춤(최종 검수 전달, 원래 계획 A23-163: 2D는 10/20부터).** 다시 그리기·사람 14명·⑤ 지시는 모두 취소. Codex 그림 그리지 않음. 11:41 자동 재개 작업(`build/img2_next/resume_1141.sh`)도 껐음. 10/20 전에는 최종 검수 지시 없이 시작하지 않음.
- **push 상태**: 그린 부품 PNG·시트·꽃 목록 전부 push됨. 사람 부품 프롬프트 156개 push(b3bdf8c~8c79744). 미push 없음.
- **10/20에 이어갈 목록 (다시 그릴 것, 0원 Codex; 그리기 전후로 원래 통짜 4면과 나란히 놓고 비율(높이/폭)·대칭·개수 확인, 시트 맨 위 줄 = 원래 그림)**:
  1. `HaloFlowerPotHQ_Daisy_Pot`: 8각인데 앞 그림 기둥 비대칭 → 모서리마다 기둥, 좌우 대칭으로 앞 다시(8각이라 앞 1장 → 4면 복사 OK).
  2. `HaloFlowerPotHQ_Rose_Bowl`: 원래보다 깊음(원래 높이/폭 ≈0.46, 지금 ≈0.63) → 비율 적어 앞 다시. + 옆 뜯김(아래 4번 원인).
  3. `HaloVar4_PotFlowers_A_Bowl`: raw는 멀쩡, 옆 뜯김만 → 맞춤만 다시(Codex 불필요).
  4. **뜯김 원인 = `build/img2_next/parts_fit.py`의 마스크**: 회색 밝기(L) 차이 > 14로 나눠서, 따뜻한 대리석(≈215,195,180)과 회색 배경(≈190,191,193)의 밝기 차가 8~15라 테두리가 배경으로 빠짐. 고칠 법 = 채널별 최대 차이 > 7(배경 잡음 ≤2). 10/14엔 멈춤 지시로 고치지 않음 — 10/20에 고치고, 그전에 맞춘 대리석 부품(그릇·화분·상자)도 다시 맞춰 뜯김 확인.
  5. `HaloVar4_Planter_A_Box`: 네모 상자(옆 폭 = 앞 폭)인데 옆이 좁음 → left/right/back = 앞 복사(Codex 불필요).
  6. `HaloReasonHQ_VegGarden_Bed`: 물뿌리개가 뒤 그림에서 화단 앞에 있음 → 물뿌리개 빼고 화단만 앞·옆 다시(물뿌리개는 있는 NEW_WateringCan 모델 씀), back = 앞 뒤집기, right = left 뒤집기. 프롬프트 생성기 `parts_prompts_b5.py` 97줄의 'watering can' 문구 빼기.
  7. `HaloVar3_PotFlowers_F_Vines`: 덩굴 = 테 위 낮은 잎 뭉치 + 꽃병 왼쪽·오른쪽 두 커튼(앞 = 아치) → 옆 = 커튼 정면(아래 틈 없음). 프롬프트 `art/prompts/HaloVar3_PotFlowers_F_Vines_left_ns.txt`(push), job `HaloVar3_PotFlowers_F_Vines:left:NEW,art/out/s2/noshadow/HaloVar3_PotFlowers_F_front_ns.png`, right = left 뒤집기, back = 앞 뒤집기.
  8. `HaloPart_Flower_TulipWhite`·`TulipBlue`: 옆 = 잎이 앞뒤로 겹친 좁은 모습. 프롬프트 `*_left_ns.txt`(push), job `<이름>:left:NEW`, right = left 뒤집기, back = 앞 뒤집기.
  9. `HaloVar3_RoundTree_F_Trunk`(옆 = 거의 I자)·`_Canopy`(옆 = 한쪽 덩어리, 아래 열림 없음): 프롬프트 `*_left_ns.txt`(push), job `<이름>:left:NEW,art/out/s2/noshadow/HaloVar3_RoundTree_F_left_ns.png`, right = left 뒤집기, back = 앞 뒤집기.
  10. `HaloPart_Flower_WhiteDaisyMany` 새로: Daisy 화분의 흰 꽃 = 꽃잎 많은 데이지(지금 WhiteDaisy 5잎은 PotA·PotF·덤불용으로 OK). 앞·옆·뒤(fl 방식, ref = `HaloFlowerPotHQ_Daisy_front_ns.png`), 꽃 목록 md의 Daisy 줄을 WhiteDaisyMany로 고치기.
  11. `Town_Halo_Fountain3_Top`(디자인 검수 10/14 10:40, 최종 검수와 같은 판단): 꼭지 금 공이 원래 통짜 `art/out/s2/noshadow/Town_Halo_Fountain3_front_ns.png` 꼭대기보다 ≈1.4배 큼 → 원래 그림을 재서 공 지름 ≈ 위 그릇 폭의 1/4로 앞 다시, 그릇·기둥은 그대로, 둥근 부품이라 앞 1장 → 4면 복사. 시트 맨 위 줄 = 원래 통짜 4면.
  - 그다음 원래 순서: 사람 14명 부품(프롬프트·작업 목록 준비 끝, 아래 '10/14 10:00' 참고; raw 4장 SirGleam·PotionMerchant Head front·left 있음) → ⑤ 108장.
- 판정: 꽃 5종 줄기 끝 지운 판 통과(디자인 검수). BushPot 작은 노란 꽃 4개 = 뺌(최종 검수 OK). 부품 2D ①②③ 14종 통과.


> **10/18 정리(최종 검수):** 옛 절은 지움 — 전부 git 역사에 있음: `git show b558445b:docs/handoff/state/img2.md`. 아래 = 지금 필요한 절 + 방법·도구 메모.

## Firefly / 도구 요령 (이어받는 세션용)
- 탭 `seed`(https://firefly.adobe.com/generate/image), `resize_window` 1440x900. **앱 브라우저 창이 보이는 상태여야 렌더·속도 정상**(숨김이면 멈춤/느림 → 최종 검수에 Ctrl+Shift+B 부탁, 로그인은 사용자가). 로그인 풀리면 최종 검수에 알림, 비밀번호 입력 금지.
- helper: `tools/_firefly_helpers.js` 내용을 javascript_exec에 붙여 심기(`__runList` ref 있음 / `__runNoRef`, 품질 value+change 고침 포함, `__qLog`, `__stopList`). 프롬프트 <1000자(넘으면 조용히 실패). 폴링은 한 번에 ≤37초.
- 참조 이미지: `asset_get_presigned_urls`(assets=[{id,sourceType:"acp"}]) downloadUrl(몇 시간 유효), 로컬 파일은 `asset_initialize_file_upload`(path,file_size,media_type) → `curl -L -X PUT` → `asset_finalize_file_upload`(transfer_document) → presignedAssetUrl.
- 결과 받기: `asset_search`(query `*` 또는 프롬프트 글, sortBy createDate, sortOrder desc, limit N; start 없음) → 오래된 것부터 로그 순서와 대조 → presign → curl. 로그엔 '성공'인데 에셋이 없는 칸이 가끔 있음(주민 Folk4_left처럼) → 개수 세어 다시.
- 컷아웃: `py tools/cutout_flat.py <src> <out> --size 512 --fill 0.86 --holes --check <시트>`(장당 ~20초, 한 장씩 백그라운드), 확인 시트는 항상 **자홍 칸 포함**. 푸시는 `py tools/push_paths.py -m "제목" <파일 경로들>`(디렉터리 인자 안 펼쳐짐, 백그라운드).
- 프롬프트·큐 원문: `art/prompts/`(`Meme_*.txt`, `Icon*.txt`, `img2_*queue*.json`), 주민·스티커·말풍선 프롬프트는 이 세션 javascript에서 만든 것이라 파일엔 없음 → 규칙만 기억: 주민 = "Use the attached image as the exact design reference… same face/clothes… add a small thin floating gold halo ring above the head… full-body front view, relaxed A-pose, plain flat medium gray background"; 4면 = "only turn the camera… straight-on at mid-height… BACK / exact LEFT-SIDE (faces right edge) / RIGHT-SIDE".
- **새 규칙(사용자 10/12 16:30, Blender 손보기 경유): 2D 그림(특히 Tripo에 넣는 앞면·4면)에 그림자 금지** — 바닥 그림자·드리운 그림자·진한 음영 없이 고르고 평평한 빛(그림이 그대로 색 맵이 돼 그림자가 굽힘). 프롬프트에 'no shadows, no cast shadow, flat even lighting, no ground shadow' 넣고, 이미 만든 4면 그림(주민·밈·성·소품)에 그림자가 보이면 다시 그리기 대상.
- 규칙: Medium 0크레딧 → 고르기 → High 5크레딧 → 컷아웃 → 시트(밝은·남색·자홍·48px). 빛살 무늬 금지, 사람은 단정한 옷(얼굴·손만), 밈·스티커 글자는 철자 하나하나 확인.
