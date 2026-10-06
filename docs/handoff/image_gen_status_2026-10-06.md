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

## 하는 중 / 다음
1. 나무: 잎 덩어리 `Tex_Leaves`·나무 껍질 `Tex_Bark`(밝은 무채색 — 파트 Color로 숲·마을 색). 잎은 기본 플라스틱 공이라 **잎 파트에만 붙이는 비덮어쓰기 MaterialVariant**로, 줄기는 Wood(문 기둥·말뚝도 Wood라 같이 바뀜) 또는 줄기 전용 변형.
2. 교차로 승리 깃발 4장 `Banner_{Halo,Horns,Crossroads,Artisan}`(문구 써 둠, 9:16 불투명 — Firefly 2:3로 받고 잘라 576x1024).
3. 게임 아이콘·썸네일(11b)은 10/20 무렵, 높음 품질이면 검수에 먼저.
- 주의: 파트에 붙은 MaterialVariant는 파트 Color가 ColorMap에 곱해진다 — 길·다리 파트 색이 진하면 타일이 어두워짐(이미지 개발에 알림).
