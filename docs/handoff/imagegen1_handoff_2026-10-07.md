# 이미지 생성 1 인계 (2026-10-07, 계정 정리 — 다음 계정이 이어서)

읽는 순서: `AGENTS.md` → `docs/handoff/review_handoff_2026-10-07.md`(검수 인계) → 이 파일 → `docs/handoff/image_gen_status_2026-10-07.md`(오늘 상세).
**지금 도는 작업 없음**(Firefly·Tripo 모두 끝남). 새 유료 작업은 검수 지시 뒤에.

## 오늘 끝난 것 (모두 origin/main)
- 부서진 왕관 B2 3D + 뒤 텍스처 고침(e52a883 뒤), 빛 성 색 고침(84ae50a), 뿔 성 v4(8e8d012), 숲 소품 8개(96a0402), 숲 큰 것 10개(e8b104b), WorldKit 가져오기 1·2·3 장부 `art/models/worldkit/import_next*_assets_2026-10-07.json`(id → 개발 1).
- 사냥터 게시판 2개 Tripo(11a53c2, 검수 통과 — 숲은 구멍 메운 `Kit_W_JobBoard_fix.glb`).
- 해골 유적: 키트 목록 `docs/design/kit_ruins.md`(d0da20d) → 큰 것 2D 시안(d034799, 바위는 '돌만'으로 다시) → 검수 확정 → **고급 8장**(f2cb517, `art/out/hq/HQ_R_*.png`, 시트 `art/review/kit_ruins/ruins_big_hq_v1.jpg`, approved.json 기록).
- 교차로 날개 사진 벽 시안(e991439) → **검수가 A_1 확정**(고급은 아직).
- 3b Tripo 웹 시험(a0447d4): 분수·화로를 Smart Mesh와 HD로 → **HD(55)로 결정**(검수·사용자). 시트 `art/review/town3b/tripo_web_test_smart_vs_hd.jpg`.

## 하다 만 것
- **3b 시험 모델 4개는 Tripo 웹 ① 계정 안에만 있음 — GLB 안 받음.** 작업 id(records.json `Town_Halo_Fountain_web_hd` 등):
  - 분수 HD `6e003ef8-0896-4416-b116-e51275704316`(삼각형 9,643) · 화로 HD `53521772-9a79-44bc-a0cb-ee0b2314c2cc`(삼각형 9,411)
  - (안 씀) 분수 Smart `1819e3d4-…` · 화로 Smart `721360aa-…`(클릭이 여러 번 들어가 화로 Smart 4개가 생겼지만 포인트는 안 빠짐)
  - 받기(내려받기)는 **사용자 OK를 이 세션 채팅에서** 받아야 함(파일 이름·출처·크기·저장 위치를 말하고 묶음마다 한 번). 지난 턴에 물어봤고 아직 답 없음.
  - 내보내기 창: 형식 GLB, 텍스처 512/1k/2k/4k(8k 잠김) → **1k로**(Roblox는 1024). 내보내기 버튼에 왕관 표시가 있어 무료 계정에서 받아지는지는 아직 모름 → 구독·결제 요구가 뜨면 바로 멈추고 검수에.
- 사진 벽 A_1 고급(5크레딧) — '새 유료 작업 시작 금지' 때문에 안 함.

## 다음 큐 (순서대로)
1. **3b HD (다음 계정 1순위)**
   1. 사용자 OK → 분수·화로 HD GLB(1k) 받기 → `art/models/tripo/web/`.
   2. **분수 반짝이게**(사용자: "저 분수가 너무 아쉽다 ㅠ 조금 더 반짝일 수 없나"):
      - HD 화면 아래 **'무료 재시도(×3)'** 로 1~2번 더(0포인트) → 물줄기·금 장식이 가장 또렷한 판 고르기.
      - 텍스처만 고치기(0): 물 = 더 맑은 하늘색 + 흰 하이라이트, 금 = 더 진하게, 흰 구름 받침은 밝기 유지(빛 성 색 고침 `tools/halo_castle_color_fix.py` 방식 — 색 범위를 골라 채도·밝기를 시안 쪽으로).
      - 게임 안 연출은 아래 '개발 1 메모'.
   3. 나머지 13개 × HD 55 = **715**(남는 2,685): Halo_WallTower·Halo_HouseC·Halo_Bridge·Horns_WallTower·Horns_HouseC·Horns_Bridge·X_Altar·X_MarketArch·X_NoticeBoard·X_GooseNest·X_TreeB·X_HouseA·X_HouseB. 입력 `art/out/hq/HQ_<이름>.png`(모두 1024²), 목록 `build/tripo_3b_web.json`(크기·놓을 수). 검수에 범위·합계 → '예' 뒤 시작.
   4. GLB → Blender 렌더(`tools/compare_3d_render.py`) → 2D↔3D 시트 → 검수 → WorldKit 묶음.
   - 점검 메모: 뿔 성벽 탑 가운데 창 2개 + 아래 창이 얼굴처럼 읽히는지 3D 렌더에서 다시 보기.
2. **해골 유적 큰 것 8개 → Tripo 웹 HD 8 × 55 = 440**(범위·합계 먼저 검수). 입력 `art/out/hq/HQ_R_*.png`, 크기·자리 `docs/design/kit_ruins.md`.
3. **사진 벽 A_1 고급**(5) — 참조 = Firefly 에셋 `urn:aaid:sc:AP:599d5c8a-97dc-415e-b87b-0f7a58ff089e`(X_PhotoWall_A_1, 1536×1024), 비율 `{"height":1024,"width":1536}` → 이미지 개발 업로드(Decal, 1024 폭) → 개발 1 배치(`docs/design/kit_crossroads.md` X_PhotoWall 줄: 13.5×9 스터드, 날개 뿌리 = 바닥에서 4).
4. **모닥불**: 2D 고급 끝(이미지 생성 2 ef15ac0, 검수 B2: 엇갈린 통나무 틈이 숯처럼 빛남 + 가운데 굵은 불꽃 한 덩어리). 입력 `art/out/hq/HQ_Woods_Campfire_FB2.png`(1024², 회색 바탕), approved.json `Kit_W_Campfire_Fire` → **Tripo API prop 40**(API 남은 45는 이 몫만, geometry_quality detailed 가능) → 2D↔3D 시트 → 다음 묶음. 불 없는 옛 `Kit_W_Campfire` 3D를 대체하고, 움직이는 불꽃·빛은 Studio에서 개발 1.
   - 유적 작은 것 3D 후보 8개(기둥 A·B, 쓰러진 기둥, 돌 이정표, 영혼불 그릇, 돌 등롱, 빈 이정표, 왕관 조각)는 다음 이미지 생성 2가 고급으로 그림(`docs/handoff/imagegen2_handoff_2026-10-07.md`). 그 뒤 Tripo를 누가 돌릴지는 검수에 확인(숲 소품 때는 이 세션이 돌림).
5. **다음 WorldKit 가져오기 묶음**: 게시판 2(`art/models/tripo/Kit_M_JobBoard_raw.glb`, `Kit_W_JobBoard_fix.glb`) + 3b HD + 모닥불 + 유적. 만들기 `tools/worldkit_combine.py`(spec `fit`) → **가져오기 버튼은 사용자가 누름** → MCP로 Model·피벗(바닥 가운데, 앞 -Z) → 장부 JSON + `tools/build_kit_from_ids.py` → id·크기 → 개발 1.
6. 나중: 오프닝 FilmSet 카메라 길(10/15), 조각 v2(사용자 답 대기).

## 개발 1 메모 — 빛 분수 반짝임(게임 안, 검수 경유)
- 물줄기: 흐르는 물 Beam/ParticleEmitter + 물 튀김, 작은 흰·금 별 반짝이(사용자: "물줄기도 나오게 해야지 로블록스 이펙트 사용해서!").
- 위 후광 고리: Neon + 금빛 PointLight(맵 전체 PointLight 수 제한 지키기).
- 물 표면: 살짝 빛나는 투명 판.
- 흔들림 끄기(접근성)·폰: 파티클 수 줄이기. Creator Store 무료 효과를 쓰면 스크립트는 지우기.

## 잔액 (10/07 끝)
- Tripo API **45**(모닥불 몫만).
- Tripo 웹 ① (계정 12516812) **3,400 / 3,550**. Smart Mesh 체험 0회 남음(안 씀).
- Tripo 웹 ② (25,000): ①을 다 쓴 뒤. 쓰기 전에 검수에 알림.
- Firefly: 약 9,660 / 10,000(같은 계정을 여러 세션이 씀, 숫자는 새로고침해야 바뀜). 오늘 이 세션 고급 = 70 + 유적 40.

## Tripo 웹 쓰는 법 (크롬 = Claude in Chrome)
- **탭은 일을 시작할 때만 열고 끝나면 닫기**(사용자가 빈 탭을 싫어함). 확장이 '연결 안 됨'이면 검수에 알림(사용자가 다시 연결).
- `studio.tripo3d.ai/ko` → 헤더에 포인트·"안녕하세요, 12516812님" 확인. 로그인은 사용자만.
- 홈의 그림 칸에 `file_upload` → 작업 공간으로 넘어감. 왼쪽 **'HD 모델'** 탭 → '지오메트리 및 텍스처' 설정: **폴리곤 수 10000**(기본 2,000,000!), 텍스처 4K, PBR 켬, 삼각형, 울트라 메시 켬(설정은 저장됨, 매번 확인) → '생성 55'.
- 그림 바꾸기: 왼쪽 그림 칸 오른쪽 위 휴지통. **오른쪽 '관리' 버튼은 일괄 내보내기/일괄 삭제 메뉴 — 누르지 않기**(눌렀으면 Esc).
- 페이지가 무거워 클릭이 시간 초과될 수 있고, 그때 클릭이 여러 번 들어감 → **돈 드는 버튼은 한 번 누르고 화면·포인트로 확인, 시간 초과에 다시 누르지 않기**. 생성 중에는 생성 버튼이 막힘.
- 작업 공간 오른쪽 목록은 그 작업과 관련된 것만 보임 → 작업 id URL(`/ko/workspace/generate/<id>`)로 바로 열기.
- 화면 캡처는 `computer screenshot` + `save_to_disk`(받기 없이 비교할 때).
- 왼쪽 '구독자 전용' 칸에 '개인정보 보호: 공유 전용'이 보임 → 무료 계정 모델은 공개일 수 있음(확인 안 함, 필요하면 검수가 판단).
- records.json에 작업마다 계정·포인트·작업 id·남은 포인트(`*_web_hd` 형식).

## 도구
- Firefly: 내장 브라우저 tab-1(도우미 `tools/firefly_page_helpers.js` → `__runList([...])`, 고급은 `quality:"high"` + `ref`=Firefly 에셋 previewUrl). 결과는 Adobe `asset_search`(GenAIAsset, createDate) → 이 세션 표시 **737956** → `asset_get_presigned_urls` → curl. 비율 값은 공백 없는 `{"height":1024,"width":1024}`, 문구 1000자 미만, 바위·자연물은 바위 머리 문장(`kit_ruins.md`).
- Blender 5.2 `C:\Users\glori\Tools\blender-5.2.2-windows-x64\blender.exe --background --factory-startup --python …`: `tools/compare_3d_render.py`(앞 3/4·뒤 3/4·게임 카메라 + 삼각형 수), `tools/compare_3d_sheet.py`, `tools/glb_texture_patch.py`, `tools/halo_castle_color_fix.py`, `tools/castle_window_dump.py`, `tools/crown_back_fix.py`, `tools/glb_fill_board_hole.py`. 시트 스크립트 예: `build/tripo_web_test_sheet.py`, `build/ruins_hq_sheet.py`(build/는 git 밖).
- Tripo API: `py tools/tripo_api.py`(prop 40 · building 40 · prop_std 30 · tree 40/면 1,500).
- 올리기: **`py tools/push_paths.py -m "제목" <경로들>`**(공유 폴더에서 git commit 금지, AGENTS f27ca7e).

## 주의
- WorldKit '가져오기' 버튼은 합성 클릭을 무시 → 사용자가 누름. 화면 제어 전엔 검수에 "이미지 생성 1 — 무엇 — 몇 초" → "전달함, 시작" → 끝나면 "끝".
- computer-use 도구는 확인용으로도 부르지 않기(주황 '제어 중'이 켜짐).
- 검수의 앱 메시지는 **내 턴이 끝나야** 도착 → 검수 답을 기다릴 때는 턴을 끝내기. SendMessage는 사용자가 이 채팅에 쓰지 않은 채 10번을 넘으면 막힘.
- 얼굴·눈·해골·뼈·무덤·십자가 금지, 사람은 단정한 옷(AGENTS 하드 룰). 100% 확대로 보고 나서 보내기.
