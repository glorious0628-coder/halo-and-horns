# 이미지 생성 인계 상태 (2026-10-06 오후, 세계·굵직한 그림 세션)

- **역할(A23-31):** 이 세션 = 세계·굵직한 그림(지형 타일, 하늘, 나무 재질, 깃발, 사냥터 분위기, 게임 아이콘·썸네일 11b, 출시 장식 18). 작은 그림(진영 화면 묶음 2, UI·아이템·무기·직업/NPC·옷)은 '이미지 생성 2'가 한다. `cutout_flat.py`·`band_mask.py`·`make_tileable.py`는 이 세션만 고친다. approved.json은 고치기 직전에 다시 읽고 내 키만 고친 뒤 바로 경로 지정 커밋.
- **순서(사용자 2026-10-06):** 작은 디자인은 나중, 세계 구성 그림부터(A23-29). 사냥터마다 맞추기(A23-30).
- 요령: `docs/design/image_session_handoff_2026-10-06.md`. Firefly는 내장 브라우저 tabId "seed", GPT Image 2.5 Sunburst·중간(크레딧 0 사용). JS 대기열: `window.__T`(문구), `__runQueue(keys, __T)`(진행 원 `sp-progress-circle`이 사라지고 새 blob 그림이 생겨야 다음 장), `__seenBlobs`(화면에 50장까지만 남아서 누적 집계). 생성 버튼을 이전 장이 끝나기 전에 누르면 조용히 버려진다.
- 다운로드: `asset_search`(GenAIAsset, createDate desc) → 이름(문구 첫머리)으로 내 것만 → `asset_get_presigned_urls` → `curl -sL`. 같은 계정에 이미지 생성 2·다른 게임 생성물이 섞인다.

## 끝 (커밋)
- 묶음 6 HUD 11장(83cf898) · 묶음 1 마스터(68cd2eb, 빛 전사 B2는 pending-user) · IconNoBuff 다시 자름(3f1716b) · IconGoldGuard(bb6caa8).
- 땅 타일 첫 4장 Grass·LeafyGrass·DirtPath·Cobblestone `_FF`(c2e9800) → 사용자 E로 확정(A23-30).
- 세계 바닥 10장(bb6caa8, 재질 표대로): Slate=Tex_RuinsFlagstone_FF, Mud=Tex_PumpkinSoil_FF, Ground, Limestone, Basalt, CrackedLava, Rock, Sand, Marble, WoodPlanks — 상태 picked(이미지 개발 UiSandbox 확인 뒤 확정). 시트 `art/review/tex_world_A_hunting.png`, `tex_world_B_towns.png`.
- 하늘 Sky_Sun·Sky_SunDawn·Sky_MoonEclipse(512, 완전 검정 바탕, 더해지는 방식) — picked, 실제 하늘에서 확인 필요(작게 보면 해가 흰 꽃처럼 날아감).
- `tools/make_tileable.py`: 최소 차이 경로 잇기(두 번째 경로 고리 닫힘), `--prefer-dark 20`(돌 틈), `-20`(밝은 용암 틈), `--grid x|y|xy`(격자·널빤지 줄에서 줄까지). 3×3 시트로 확인.
- 쓰지 않은 후보: `art/out/tex/`(미추적) — 격자 할로 타일·쿨톤 점판암·왕관 조각 땅은 재질 칸이 없어 안 넘김.

- 나무 재질 Tex_TreeLeaves·Tex_TreeBark(38a6148, 밝은 무채색 — 파트 Color 곱하기, 이름 붙인 변형 GE_TreeLeaves/GE_TreeBark).
- 교차로 승리 깃발 4장 Banner_*(f5ed062, 683x1024 2:3).
- 하늘 해·달 다시(37fc90a): 빛살 없는 둥근 원판(빛살은 Roblox 해 렌더에서 흰 데이지처럼 보였음).
- 돌·판석 바닥 6장 이음 다시(efcdd0a) + make_tileable 고침: 비용 정규화, --search, 품질 경고, 100% 이음 크롭, 둥근 자갈용 --reseat. 모드 고르는 법은 도구 머리말.

## A23-33 세계 소품 키트 (이 세션이 이끎)
1. 끝: 소품 목록 `docs/design/world_kit_2026-10-06.md`(+ .json) — 사냥터별 81종(3de8eb5).
2. 끝: 사냥터 콘셉트 7장 `art/review/world_concepts_sheet.png`, 고른 안 `art/review/concept/*.jpg`(cf207b9). 사용자에게 보냄.
3. 다음: `build/WorldKit.rbxlx`(복사해 둠, 아직 안 엶)에서 교차로부터 3D — Creator Store(search_asset/insert_asset) → Roblox 생성 → Tripo(크레딧 합계 검수에 먼저). 넣자마자 Script/LocalScript/ModuleScript/원격/프롬프트 삭제, `art/models/worldkit/manifest.json`에 애셋 ID·만든 사람·삼각형 수, 모델은 `art/models/worldkit/*.rbxm`. 모든 Studio 도구에 STUDIO_NAME=WorldKit(메인·UiSandbox 절대 안 건드림). 쓸 때만 열고 닫기.
4. 게임 아이콘·썸네일(11b)은 10/20 무렵, 높음 품질이면 검수에 먼저.
- 주의: 파트에 붙은 MaterialVariant는 파트 Color가 ColorMap에 곱해진다 — 길·다리 파트 색이 진하면 타일이 어두워짐(이미지 개발에 알림).
- Firefly 비율은 쓰고 나면 1:1로 돌려 둔다(깃발 2:3, 콘셉트 3:2 썼음).
