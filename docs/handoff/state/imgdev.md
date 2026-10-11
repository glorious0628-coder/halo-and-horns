# 이미지 개발 — 상태 (2026-10-11 밤 3차: 금 파트 색 확정)

- **금 파트 색 (255,168,36) 확정** (이미지 생성 3 집 07 사진 후보 4개를 내 눈으로도 봄: 195,45는 레몬·올리브빛, 250,155,30은 갈색 쪽, 168,36이 2D에 가장 가까움). WorldKit 4110개 적용 끝(저장 안 함). 생성기 상수 바꿀 곳: 이미지 생성 1(skeleton_civic·skeleton_ground GOLD_RGB), 이미지 생성 3(skeleton_house·house07·preview). 남은 차이 = Studio 금이 2D보다 어두움(빛·노출 쪽, 추측) — 조명 값 적용(ZoneLook HaloTown C2c) 뒤 다시 봄.

# 이미지 개발 — 상태 (2026-10-11 밤 2차: 금 WorldKit 적용·FF3 시트)

- **금 WorldKit 적용 끝(저장 안 함):** HH_HaloGoldTrim 파트 4110개 색 (255,195,45), MV 금속 137160255192059(0.5)·거칠기 109029776386025(0.15). 도구 `tools/gold_trim_apply.luau` (MODE survey/apply/undo, 메인은 ALLOW_MAIN 막음). 최종 확인 = 이미지 생성 3의 다음 집 07 사진(2D 옆) — 어긋나면 파트 색만. 메인엔 새 마을 들어갈 때 같이.
- **FF3 5장 3×3 시트:** art/review/imgdev/tex_ff3_tiled3x3_sheet_2026-10-11.jpg — 이음매 없음, Grass·GrassShade·MeadowFlowers는 패턴 반복이 눈에 띔(꽃이 격자로 보임). 판정은 검수.

# 이미지 개발 — 상태 (2026-10-11 밤 갱신: ID 점검·재질 3종 검수 라운드)

## 지금 기다리는 것 / 다음 일 (이 블록이 맨 위 최신)
1. **금(HH_HaloGoldTrim) 확정(검수 10/11 밤)**: 금속 0.5(Halo_GoldTest_metal50 137160255192059) + 거칠기 0.15(Halo_GoldTest_rough15 109029776386025) + 파트 색 **(255,195,45)** — building_variants_halo.json·approved.json·asset_ids에 적음(3차 시험 안 함). 최종 확인은 **다음 골격 사진(이미지 생성 3 집 07 등)을 2D 옆에 놓고** — 어긋나면 파트 색만 고침. WorldKit·UiSandbox MV는 아직 옛 맵(0.7/0.35)이라, 적용은 이미지 생성 3·1이 WorldKit에서 `tools/building_variants.py`로 MV 다시 만들 때 같이(요청 오면 내가 Luau 만들기). 메인엔 금 MV 아직 없음(새 마을 들어갈 때). 시트 `gold_candidates_sheet2_2026-10-11.jpg`, 촬영 도구 `tools/gold_candidates_{test.luau,capture.py}`(UiSandbox 열기: Start-Process RobloxStudioBeta.exe build/UiSandbox.rbxlx; 빛은 halo_light_sim C2c). UiSandbox는 지금 닫혀 있음.
2. **HH_Fabric v2** 올림 완료·메인 반영 1이 메인 Studio MV ID 교체(color 76316272601072, rough 119858177335377; 미저장 — 낮·밤 Play 사진·Save As는 급한 병합 Play 때 같이, 검수가 확인되면 알려줌 → 그때 v1 color·rough 파일·기록 정리, normal 공용이라 삭제 금지). 맵 ID(color 76316272601072 / normal 102973991596175(v1과 같음) / rough 119858177335377; asset_ids `Halo_Fabric2_*`). 메인 MV ID 교체는 **메인 반영 1에 직접 요청**(아직 안 함). v2가 메인 Play 사진에서 확인된 뒤 v1 color·rough 파일·기록 삭제(normal은 공용이라 삭제 금지).
3. 직조 밤 사진 — 메인 Play 사진(메인 반영 1)으로 대신 확인 예정; WorldKit 촬영이 따로 필요하면 이미지 생성 1 차례와 안 겹치게 검수에 신청.
4. Tex_*_FF3 5장(uploaded_review_pending) 3×3 시트를 다음 재질 시트에 같이.
5. 기록: `art/review/imgdev/id_audit_2026-10-11.md`(표 A~D, §9). 크림 대리석 approved, 금 작업값 확정(최종 확인 대기), 직조 v2 통과(메인 확인 대기).
6. 아래 옛 큐(빛 마을 지붕 맵, 집·가게 SA 적용, A23-105 사진)는 그대로 유효.

# 이미지 개발 — 상태 (2026-10-11 저녁, 새 세션이 정리하고 쉼; 사용량 19:00 리셋까지)

## 다음 큐 (순서대로, 전부 남의 입력을 기다림)
1. **빛 마을 지붕 맵 올리기** — 집 07·11 지붕은 몸통 타일 맵(Body_t00~t11)을 같이 쓰는 조각이라 따로 구운 Roof 맵이 아직 없음.
   이미지 생성 3이 굽는 순서를 검수에 물음(A23-122 3D 재검수와 겹침). 폴더 이름이 오면
   `py tools/upload_sa_maps.py art/models/tripo/halo_houses/<집> --tags CNMR --names <집>_Roof...` → 적용 목록 다시 만들기(아래 2).
2. **집·가게 SA 적용** — WorldKit 가져오기(사용자 클릭) 뒤 이미지 생성 1/3이 WorldKit에서 돌림. Luau 만들기:
   `py tools/apply_sa_by_name.py <집 01~12·가게 4 폴더> --glass <각 _Glass> --skip '_Body_t[0-9]+$' --mode survey|apply`
   (부품 64 + 유리 16; Mesh_0이면 부모 이름으로 찾음). 몸통(Body_t**) 맵은 A23-120으로 안 씀.
3. **A23-105 사진 1번** — 새 마을(A23-121)이 메인에 들어간 뒤 메인 반영 1이 처마 밑 + 밤 등불 사진.
4. 화면·카메라 일은 전부 검수 "전달함, 시작" 뒤에만(WorldKit 카메라는 이미지 생성 1·3과 번갈아).

## 10/11 저녁에 끝낸 것 (전부 main)
- **대리석:** 크림 12칸(HH_HaloMarbleBlock_Cream), 파트 색 벽 (255,244,222)·바닥 (238,226,205), 9칸판 안 씀(36ef441).
- **금(HH_HaloGoldTrim):** 금속 0.7 + 거칠기 0.35 + 평평 노멀, 파트 색 **(255,175,25)** — 원인은 금속 1 × 파란 하늘 반사 = 올리브.
  시트 art/review/imgdev/gold_trim_test_2026-10-11.jpg, 맵 art/ui/halo_tile/goldtest/(만드는 도구 tools/gold_trim_maps.py).
  WorldKit에는 적용됨(집 07 금 파트 298개 색 바꿈). 메인에는 아직 안 넣음(메인은 GE_*만 씀; 새 마을이 들어갈 때 같이).
- **빛 마을 조명:** 후보 C0~C3·C2b·C2c 사진, 추천 C2c = `HaloTown = { Amb = {1.45,1.36,1.32}, Bright = 1.0, Exp = 0.15, Tint = rgb(255,248,236), Sat = 0.08, Con = 0.04, CC = 0.02, Specular = 0.8 }`
  (docs/design/halo_zonelook_values_2026-10-11.md, 시트 art/review/imgdev/halo_light_*). 적용은 개발 쪽. 흉내 도구 tools/halo_light_sim.luau·halo_light_restore.luau
  (WorldKit에 메인 빛을 흉내 → 사진 → 복구; 판정 사진은 C2c 낮으로).
- **Fabric:** 원인 = Fabric 기본 알베도가 어둡고 무채색(칠한 색의 25% 이하; 변형·로드·조명 아님). **HH_Fabric**(Fabric 베이스, 2 studs, 밝은 직조 맵,
  tools/fabric_weave_maps.py, id color 117704901835962 / normal 102973991596175 / rough 138111432038584) → 색 96% 통과(art/review/imgdev/hh_fabric_test_2026-10-11.jpg).
  **메인에 적용 끝**(메인 반영 1: MV 만들고 Fabric 파트 11개 apply, COLOR_SCALE 1; 저장은 다음 Save As). 도구 tools/building_variants_main_fabric.luau · fabric_variant_apply.luau(survey/apply/undo).
  이미지 생성 1·3에게 천 파트는 Fabric + MaterialVariant "HH_Fabric" + Color로 쓰라고 알림(집 차양은 지금 SmoothPlastic).
- **스킬 Z·X 아이콘 사진:** art/review/imgdev/skillbar_lv25_2026-10-11.jpg (통과).
- **api_agent:** read_image(2257314), 쓰기 모드 --write --branch api/<이름>(9f7b8e5), sparse worktree 기본(e6779bed). 사용법 docs/handoff/api_agent_howto.md (시험 311/0).

## 만든 MaterialVariant (art/models/worldkit/building_variants_halo.json; WorldKit에만, 메인은 HH_Fabric만 있음)
- `HH_HaloMarbleBlock` Marble 9 — 안 씀. `HH_HaloMarbleBlock_Cream` Marble 12 (color 80357186990466 normal 73394105072257, rough/metal = 1판).
- `HH_HaloGoldTrim` Metal 4 — color 94913368757526 normal 131597673772642, **rough 128833041727597 (0.35) metal 139091750772198 (0.7)**, 파트 Color (255,175,25). 옛 맵 rough 82910627301523 / metal 91394364117916.
- `HH_Fabric` Fabric 2 — 위.

## 도구 (tools/)
upload_sa_maps.py, apply_sa_by_name.py, apply_sa_maps.py, building_variants.py(--only), gold_trim_maps.py, fabric_weave_maps.py, halo_light_sim/restore.luau,
fabric_probe.luau(읽기 전용), zone_split_batch.py, deco_sa_maps.py, api_agent.py.

## Studio·worktree
- UiSandbox: 열려 있음, Edit. WorldKit: 시험판은 전부 지움, 빛 원래대로(반사 0.8·확산 0.3·14시).
- 포트 8765에 남의 http.server(PID 28400) — 끄지 말 것.
- worktree C:/Users/glori/Documents/Roblox/Game-imgdev-q: 브랜치 imgdev-skillicons(병합됨).
- 공유 트리에서 `git pull` 하지 말 것(다른 세션 미커밋 파일과 부딪힘) — 올릴 땐 push_paths.py(폴더 경로는 안 올라갈 수 있으니 파일을 하나씩 적을 것).

## 남의 일로 넘긴 것
- 집 07 차양(검정 체크 → SmoothPlastic으로 피함)은 이미지 생성 3이 HH_Fabric으로 되돌릴지 정함.
- 조명 값(ZoneLook HaloTown) 적용·사진 재확인은 개발 쪽 + 메인 반영 1.
