# 이미지 개발 — 상태 (2026-10-11 밤 갱신: ID 점검·재질 3종 검수 라운드)

## 지금 기다리는 것 / 다음 일 (이 블록이 맨 위 최신)
1. **금(HH_HaloGoldTrim) 2차 끝(10/11 밤)** — 시트 `art/review/imgdev/gold_candidates_sheet2_2026-10-11.jpg`, 촬영 빛 = 메인 C2c(halo_light_sim) 낮 15.3시·밤 21시 + 그림 하늘. **빛을 메인과 맞추니 1차의 "탁한 겨자"는 대부분 UiSandbox 빛 탓이었음**: 햇빛면에서 BASE(0.7·0.35·255,175,25)는 이미 진한 금빛 노랑, D/E(금속0.5·0.15)는 레몬 노랑에 가깝고(E 255,215,70이 2D에 제일 근접), 그늘은 전부 탁한 노랑, 밤엔 BASE가 주황 갈색·D~F는 겨자 노랑. G(금속0.3) 후보는 0.3 금속 맵이 안 올라가 있어 빠짐(올리려면 검수 승인). 판정은 검수. 시험 판은 지웠고 UiSandbox는 닫음(저장 안 함). 다시 하려면 UiSandbox 열고(Start-Process RobloxStudioBeta.exe build/UiSandbox.rbxlx) 빛 sim 낮 적용 → gold_candidates_test.luau build → gold_candidates_capture.py.
2. **HH_Fabric v2** 올림 완료(color 76316272601072 / normal 102973991596175(v1과 같음) / rough 119858177335377; asset_ids `Halo_Fabric2_*`). 메인 MV ID 교체는 **메인 반영 1에 직접 요청**(아직 안 함). v2가 메인 Play 사진에서 확인된 뒤 v1 color·rough 파일·기록 삭제(normal은 공용이라 삭제 금지).
3. 직조 밤 사진 — WorldKit 촬영은 이미지 생성 1 차례와 안 겹치게 검수에 따로 신청.
4. Tex_*_FF3 5장(uploaded_review_pending) 3×3 시트를 다음 재질 시트에 같이.
5. 기록: `art/review/imgdev/id_audit_2026-10-11.md`(표 A~D, §9). 크림 대리석 approved, 금 redo, 직조 v2 통과.
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
