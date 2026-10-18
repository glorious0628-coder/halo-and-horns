# 이미지 생성 3 — 상태 (2026-10-11 밤, PC 재부팅 뒤)

> **10/18 정리(최종 검수):** 옛 절은 지움 — 전부 git 역사에 있음: `git show b558445b:docs/handoff/state/img3.md`. 아래 = 지금 필요한 절 + 방법·도구 메모.

## ★ 10/14 낮 — ⛔ 전부 멈춤 (최종 검수 지시: 사용자 원래 계획 = 디자인은 10/20 뒤). 지금 상태만
- WorldKit·재질 일 안 함. 하던 것 없음(진행 중 작업 0, 올리는 중인 것 0, Studio 안 건드림).
- 남은 것(재개 때): 난간 v2 GLB(Blender 손보기 2, 통과 시) → 메시만 + 사용자 3D 가져오기 → 키트(tools/worldkit/tripo_parts_kit_gen.py) → P129 → 낮밤 사진. SA 20장 asset_ids에 있음(m0..m4). 화면 제어는 사용자가 거부했으니(10/14) 가져오기는 사용자 직접.
- WorldKit Studio(STUDIO_ID 98b5c8af-…) 열림·미저장, 내가 넣은 것 없음.

## ★ 10/14 낮 — 난간 멈춤 (기록): 합친 판 통과 취소
- 사용자가 WorldKit에 가져와 보고 합친 판 모양이 2D와 다르다고 함(가로대·받침 두껍고 기둥 작음) → 최종 검수가 통과 취소, Blender 손보기 2가 Codex로 레이아웃 다시(v2). **내 SA 20장(asset_ids SA_HaloVar4_Balustrade_C_m0..m4_*)은 그대로 둠(부품 텍스처는 같음).** v2 GLB 통과하면: 재질 번호·부품 수 다르면 `glb_sa_maps_multi.py`로 다시 확인(같은 부품 텍스처면 SA 재사용) → 메시만 `glb_strip_mesh.py --part-names` → 사용자 3D 가져오기 → 키트 스크립트(tripo_parts_kit_gen.py) → P129. Workspace의 사용자가 넣은 회색 모델은 건드리지 않음. 키트·놓기 스크립트와 재질 표는 그대로 쓸 수 있게 push됨(128995b).

## ★ 10/14 낮 — 난간 ⑤ 1차 (기록)
- 한 일: build/tripo_parts/HaloVar4_Balustrade_C_tripo.glb(13 메시·재질 5·압축 없음) → `tools/glb_sa_maps_multi.py`(재질별 원본 맵) → `tools/hd_mat_tune.py`(금 = 색 마스크 또는 M>0.5 → 금속 0.90·거칠기 0.30·색상 42°·채도↑; 대리석 = 금속 0·거칠기 0.50·상아 색상 36°·V 대비 1.35·흰점 0.99 소프트클립; 원본 대리석은 분홍빛 + 거칠기 0.2대라 번쩍였음) → build/img3_bal/tuned2 → **SA 20장 올림**(asset_ids `SA_HaloVar4_Balustrade_C_m0..m4_{C,N,M,R}`; m0 = 기둥 6개(DoubleSided), m1 = 끝 기둥 2, m2 = 가로대 2, m3 = 받침 2, m4 = 모서리 기둥).
- 메시만 GLB = `build/import3d_bal/HaloVar4_Balustrade_C_TU.glb`(`glb_strip_mesh.py --part-names`: 노드 이름 `..._pNN_mK`). **사용자 화면 제어 거부(10/14)** → 3D 가져오기는 사용자 직접(WorldKit 창 → 홈 → 3D 가져오기 → 이 GLB 1개). 가져오면 Workspace.HaloVar4_Balustrade_C_TU.
- 다음(가져온 뒤, MCP만): `py tools/worldkit/tripo_parts_kit_gen.py HaloVar4_Balustrade_C 4.5 --two 0` → build/wk/tripo_parts_kit_HaloVar4_Balustrade_C.luau 실행(= ServerStorage.HaloTripoKits.<이름>, 높이 4.5칸, 피벗 바닥 중앙) → 놓기 = Workspace.HaloV2.Props.Real.P129_HaloVar4_Balustrade_C(전망대 남쪽 끝 낭떠러지 난간, pos 205,28,-822 yaw 4°, 옛 파트 키트 103파트; 옛 것은 ServerStorage.Parked_*로) — V자(모서리) 모양이라 옛 납작 키트(9×2.3)보다 앞뒤가 깊음(높이 4.5 기준 폭 ≈12 × 깊이 ≈7): 자리 맞는지 사진으로 확인, 꼭지(+z) 방향은 바깥 낭떠러지 쪽 → `tools/prop_ab_shots.py <out> P129=art/out/s2/noshadow/HaloVar4_Balustrade_C_front_ns.png --back`(창 펼침 필요) → 디자인 검수.
- Luau 실행 도구: build/img3_bal/run.py(STUDIO_ID 고정, 코드 파일 → execute_luau; JSON 안 '
' 때문에 파싱 오류 나므로 파일로).
- WorldKit(STUDIO_ID 98b5c8af-552d-45f0-aa71-3ee3a5eae7ee, 이름 "Game") 열림, 저장 안 됨(place=0). 내가 넣은 것 아직 없음(저장할 것 없음).

## ★ 10/14 낮 끝 (클리어 전) — 다음 나는 여기부터
- **준비된 것:** ① 키트 스크립트 `tools/worldkit/npc_hd_kit.luau`(몸 SA + 메시 후광 숨김 + 게임 후광 Acc_HaloR1 같은 자리·지름, 키 5.2칸; 부품 사람에도 재사용) ② `tools/npc_hd_split.py`(Blender: 후광 고리 분리·피벗, meshopt GLB 재저장 겸용; 절대 경로만) ③ 재질 표 `docs/design/roblox_material_hd_2026-10-14.md`(첫 모델로 시험 뒤 고침) ④ SA 올린 8장(통짜 BakerGranny·BellElder)은 **미사용**, asset_ids에 _NOTE 표시(지우지 말 것).
- **다음 일 = 난간:** 최종 검수가 Blender로 합친 `build/tripo_parts/HaloVar4_Balustrade_C_tripo.glb`(부품 13개 = MeshPart 13, 가로대·받침은 축별 맞춤 판; join false). 순서: meshopt이면 Blender 재저장(npc_hd_split.py 참고) → `glb_sa_maps.py`(부품마다 맵) → 맵 직접 보고 10장 이하씩 올림 → `glb_strip_mesh.py` → 최종 검수에 사용자 3D 가져오기 신청 → WorldKit에 놓기 + 재질 표대로 보정 → 2D 옆 낮·밤(C2c) → 디자인 검수 → 최종 검수.
- WorldKit Studio = 열림·최소화, **저장 금지**(최종 검수 먼저). MCP 이름 "Game", STUDIO_ID로 선택(list_roblox_studios). SA 올리기 남은 것(d 14·g 4 − ArmoryBarrels·JuiceParasol --replace)은 위 10/14 절 그대로.

## ★ 10/14 낮 — 다시 켬 (A23-174·175: HD 모델 + ⑤ Roblox 재질 전부 필수)
- 할 일: 통과 HD 모델(art/models/tripo/web/<이름>_HD_pbr_src.*, Blender 크기·피벗 끝난 판; 난간 등 부품 = tools/assemble_parts.py 합본 GLB) → WorldKit(STUDIO_NAME=WorldKit)에 가져오기(사용자 3D 가져오기, 최종 검수 경유) → SA 보정 → 2D 옆 낮·밤(C2c) → 디자인 검수 → 최종 검수. 재질 표 초안 = docs/design/roblox_material_hd_2026-10-14.md.
- WorldKit Studio = **열림(10/14 낮, 최소화, MCP 이름 "Game"·studio_id는 list_roblox_studios로 확인; STUDIO_NAME=WorldKit 안 맞으면 STUDIO_ID)**. 저장본(10/13 23:42)에 HaloV2·HaloTripoKits 58·Parked_PreTripo*·_TU 109 다 있음 → 백업 불러오기 불필요. 저장(Ctrl+S)은 최종 검수에게 먼저.
- SA 올리기 남은 것(asset_ids 대조, 10/14): b·c·e = 전부 기록됨. **d 14종**(SignFlower·SignPotion·PotFlowers_E/F·Planter_A(Var4)·PotFlowers_A/C(Var4)·CandleCrate·Easel·GatherBush·NoticeBoard·SteppingStone·WaterBuckets·WateringCan) 안 올라감(sa_d 올리다 Empty 오류로 멈춤), **g 4종**(Topiary_E·Balustrade_C·PotFlowers_D·Beehive) 안 올라감, **JuiceParasol은 아직 옛 줄무늬 id**(--replace 남음). **NEW_ArmoryBarrels(sa_g) 올리지 말 것**(구멍, 사용자 취소; HD 통 새로 옴). e_hold(GuardPost·PotionCrate) 보류 그대로. 올릴 때: `STUDIO_NAME=WorldKit py tools/upload_sa_maps.py build/sa_d --tags CNMR` (d·g는 새 모델이라 CNMR), g는 `--names Topiary_E…`로 ArmoryBarrels 빼고, JuiceParasol만 `--replace`; 올리는 동안 push 금지.
- asset_ids.json 214키 push 완료(fabdd81). 순서: d → g → JuiceParasol --replace → Statue --replace → 키트 생성(tripo_kits_gen.py) → 놓기.
- **10/14 NPC 2(BakerGranny·BellElder, HD 사람)**: GLB는 meshopt 압축(Roblox 못 읽음) → `tools/npc_hd_split.py`(Blender: 후광 고리 = 따로 면 ~100개 분리, 피벗 바닥 중앙, 모양·색 그대로, thr 0.46) → build/hd_npc/tu/<이름>_TU.glb → `glb_sa_maps.py`(매트 규칙) build/sa_hd1 → SA 8장 올림(asset_ids 기록, STUDIO_ID=98b5c8af) → `glb_strip_mesh.py` build/import3d_hd/<이름>_TU.glb(2 primitives). **취소(10/14 최종 검수: 사용자 '사람도 머리·몸·소품 따로') — 통짜 사람 HD는 미사용, 가져오기 안 함, SA 8장은 asset_ids에 _NOTE 표시. 방법(후광 분리·게임 후광·5.2칸)은 부품 사람에 재사용.** 다음 실제 일 = 난간(build/tripo_parts/HaloVar4_Balustrade_C_tripo.glb, 최종 검수가 Blender로 합쳐 줌; meshopt GLB면 Blender 재저장 → strip_mesh → 가져오기). 가져온 뒤: `tools/worldkit/npc_hd_kit.luau` 실행(몸 SA + MeshHalo 숨김 + 게임 후광 Acc_HaloR1 같은 자리·같은 지름, 키 5.2칸) → 2D 옆 낮·밤 사진(C2c) → 디자인 검수. 한 명(Granny)으로 방법 확정 뒤 나머지 13 같은 방법. 렌더 확인용 build/hd_npc/render.py(Workbench 4면, 절대 경로만).

## 도구 (전부 push됨)
- 생성: `py tools/skeleton_house07.py [--marble cream|block]` → `build/skeleton_test_07.luau` + `.json`(파트) + `_place.json`(Tripo 조각 옮기기 규칙) + `_cams.json`(미리보기 가까이 카메라).
- 조각 배치: `blender … --python tools/skeleton_place.py -- art/models/tripo/skeleton_test/HaloDomeHouse_07_keep.glb build/skeleton_test_07_place.json art/models/tripo/skeleton_test/HaloDomeHouse_07_placed_v4.glb`.
  - region 규칙: x/y/z, near, arch, no_white, no_gold, drop_tall, drop_boxes
  - 변형 규칙: scale/about, move, rotz, align
- 미리보기: `tools/skeleton_preview.py <절대경로 out> --parts … --glb … --cams build/skeleton_test_07_cams.json [--marble cream]`(상대 경로면 파일이 안 생김). 같은 카메라로 옛 Tripo도(`--glb import_now/…_parts.glb`).
- 시트: `py tools/skeleton_sheet.py <2d> <tripo_dir> <skel_dir> <out.jpg> [--studio "줄 제목|이름=경로;이름=경로"]`.
- 조각 자르기: `tools/skeleton_keep.py`. Studio 사진: `STUDIO_NAME=WorldKit py tools/skeleton_shots.py <dir>`(창이 최소화돼 있으면 흰 사진 → 새 검수에 창 복원 요청).
- WorldKit 넣기: luau를 `{"code":…, "datamodel_type":"Edit"}` json으로 만들어 `STUDIO_NAME=WorldKit py tools/studio_mcp.py call execute_luau @file.json`.
## WorldKit 상태
- `Workspace.SkeletonTest`: House07_Skeleton **4판 크림**(512파트 + 화분 8, 원점 3000,0,0, 앞 = -Z, 속성 SkeletonVersion 4) + Tree_Pot_Skeleton(x 3026). 재질 변형 3종이 들어가 있음(building_variants 실행: 대리석 9 UPDATED, 크림 12·금 테 MADE).
- 이미지 생성 1이 `HaloDomeHouse_07_keep`(옛 keep, 20노드)과 `HaloVar3_RoundTree_E_keep`을 SkeletonTest 옆(+x 30쪽)에 둠. 크기는 가져온 그대로.
  - 4판에 맞는 건 `placed_v4.glb`(import_now에 넣어 둠 — v3는 import_now에서 뺌, 원점만 맞추면 골격과 맞음). 옛 keep을 쓰면 skeleton_place 규칙대로 옮겨야 함.
- 4판 Studio 사진(골격만): `art/review/img3/skeleton07/v4/studio_block|studio_cream|studio_cream_warm/*.png`. 등불 Neon 상자·갈색 계단 판(문짝 뒤판)은 Tripo 조각을 안 붙여서 보임. Blender 미리보기 `v4/skel|skel_cream|tripo`(디스크만, git 안 올림).
- 크림판 사진은 바꿔 넣은 직후 무늬가 늦게 떠 회색 판으로 찍힘 → 몇 초 뒤 다시 찍기.
## 숫자·경로
- 시트: `art/review/img3/skeleton07/skeleton07_v4_compare.jpg`(4판), `skeleton07_v3_compare.jpg`(3판), `skeleton07_compare.jpg`(2판).
- 2D: `art/out/s2/halo/roofs/HaloDomeHouse_07_roof_v2.png`.
- 4판 수치: 골격 크림 520파트(9칸판 548), 남긴 Tripo 1.28만 tris(옛 몸통 2.4만 + 1024 맵 16장 대신).
- Tripo 웹 잔액(25k 계정) ≈ 17,965(records.json 마지막). `import_now/`: git 금지, 다 쓰면 비움.
- 집 07·11 지붕 기와 오인식 고친 parts(07 WinPane 547→281, 11 507→143)는 이번 push에 포함. 이미지 개발이 이미 새 id로 올림.
## 막힌 것
- 없음. 4판 시작 전 새 검수의 순서 확인.
