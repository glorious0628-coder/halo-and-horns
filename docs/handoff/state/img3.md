# 이미지 생성 3 — 상태 (2026-10-11, 새 세션)
## 지금 상태 한 줄
**집 07 골격 4판 끝(10/11 새 세션), 검수 판정 기다림.** 시트 `art/review/img3/skeleton07/skeleton07_v4_compare.jpg`. 대리석은 **크림 2판(HH_HaloMarbleBlock_Cream 12칸) + 파트 색 (255,244,222)** 로 고름 → 이미지 개발에 알림. WorldKit SkeletonTest = 4판 크림 수정판(600파트). Tripo 조각은 `import_now/HaloDomeHouse_07_placed_v4.glb`(사용자 가져오기 기다림, 검수 경유).
## 4판에서 바꾼 것 (검수 판정 6 + 측정)
- 몸통: 2D 실루엣(벽 폭 : 처마 위 = 1 : 0.86, 기둥 포함)을 다시 재 보니 옛 목표 XS 8.0·HF 5.25는 너무 납작(0.74) → **XS 7.6, HF 4.75, 대각 45°(2.85×2.85, Tripo 지붕 팔각과 같음), 깊이 = Tripo×1.13, Z1 12.35(처마 위 13.25)**. 실루엣 비 ≈ 0.80. 문 5.0×8.15 그대로.
- 타일 줄눈: WorldKit 시험(10/11) — **MaterialVariant 줄눈은 파트마다 맨 위 가장자리에서 시작**. 그래서 벽 판은 전부 Z1에서 끝나고, 금 띠·창 아래·받침 높이는 Z1에서 줄 수(9칸 = 9/8, 크림 = 1.5)로 셈. `--marble cream|block`이 높이를 다시 셈.
- 금: 바닥 고리(끊김 없음) · 임포스트 띠(창 아치 시작선, 창 틀만 비움) · 프리즈 띠(정면 포함) · 처마 금. 기둥 머리 크게, 처마 선 안쪽. 작은 네모(임포스트 조각·기둥 중간 띠) 뺌.
- 창: 유리 0.12만 안쪽, 금 틀 0.15 밖, 대리석 아치 덮개, 금 쐐기돌·창턱.
- 문: 대리석 안쪽 틀(문짝 가장자리 0.1 덮음) + 금 아치 0.7(0.3 튀어나옴) + 대리석 띠, 문짝은 0.4 들어감. 뒤판은 밝은 나무.
- 화분: 앞 모서리 둥근 화분 2(속 빈 테두리, 모래 흙 0.25 아래, 금 받침·줄·네잎 장식) + 옆·뒤 대각 화단 2(폭 1.8). 식물 덩어리 6개(keep GLB에서 잼)를 1.15배로 각자 화분·화단 가운데에.
- 계단 반원 2단(r 3.3 / 4.2), 정면 기둥 받침(금 머리·명판) 위에 앞 기둥 + 등불.
- 지붕: 2D처럼 처마가 처마돌 선 바로 안쪽(scale ≈ 1.02 × 1.03, keep 지붕 처마 윤곽으로 셈). 옛 큐의 'xy 1.2'는 처마가 벽 밖으로 1.4 나가서 안 씀.
## 큐 (순서)
1. ~~검수 판정~~ 10/11: Blender 모양 거의 통과, 크림 확정. ①메달 입체 ②뒤 창 → 고침(9393b4d, 시트 `skeleton07_v4b_compare.jpg`, WorldKit 600파트). **이 판이 ④ 건물 골격의 기준판.**
2. ~~Tripo 붙인 Studio 사진~~ 10/11 끝: 사용자 가져오기 → `SkeletonTest.House07_TripoPieces`(가져오기 도구가 180° 돌려 놓음 → roblox = (-x_b, z_b, y_b) + T를 문 상자로 풀어 PivotTo, 오차 0.004). 같은 Scene의 NPC_HaloBright는 다른 세션 것. 사진 `v4/studio_tripo/`(낮 8 + 밤 2, 뷰포트 1274x471), 시트 `skeleton07_v4c_studio.jpg`. 검수 최종 판정 기다림.
2b. v4c 판정(10/11): 방법·문 통과. ①금 재질 = 이미지 개발 시험 기다림 ②파트 차양(크림·노랑 Fabric, cb6ac629) — **Studio 사진에서 검게 나옴(값은 맞음, 원인 미확인) → 다음 사진 차례에 Fabric/SmoothPlastic 시험** ③기둥 0.4 앞·받침 금 머리 절반 ④등불 유리 Glass + LampLight(밤만 빛). 사진 `v4/studio_v4d/`.
2c. 새 규칙(검수 10/11, 사용자 "문고리가 동그랗지 않아"): 동그란·반듯한 금속 장식은 Blender 스크립트 → `tools/metal_ornaments.py`(knocker·hinge·lantern·leaf, 크기 인자). 집 07: 판자 문짝 + 문고리 + 경첩 2 + 등불 틀 2 = `art/models/tripo/skeleton_test/HaloDomeHouse_07_ornaments.glb`(import_now에 복사, 사용자 가져오기 1번 기다림). 시트 `art/review/img3/skeleton07/house07_ornaments_v1.jpg`. place 규칙에서 Tripo Door·DoorHw·Lanterns·Awning 뺌. 가져오면: Orn_* 금 = Metal + HH_HaloGoldTrim + (240,186,56), Orn_H07_Leaf = Wood (176,112,58), TripoPieces의 Door·DoorHw·Lantern 노드 지움.
2d. A23-125(사용자 다시 강조): 모든 3D = Tripo → Blender 손보기 → Roblox 재질. 집 07 조각 전부 손봄(10/11): 문짝·문고리·경첩·등불·지붕창 = Blender 정확한 부품(metal_ornaments, arch_window), 식물 6 = `tools/piece_fix.py --flowers`(파편·섬 지움, 꽃 = 정확한 5잎, 부품마다 C·N·R·M), 지붕 = `tools/roof_fit.py`(몸통 팔각에 맞춤·갈빗대 모서리로) + piece_fix 맵. 합본 `art/models/tripo/skeleton_test/HaloDomeHouse_07_fixed.glb`(2.76만 tris, `tools/glb_merge.py`) → import_now(사용자 클릭 1번 기다림). 시트 `art/review/img3/skeleton07/house07_fix_before_after.jpg`. records.json 키 `HaloDomeHouse_07_skeleton_v4_fix`. 가져온 뒤: TripoPieces 지우고 fixed로 바꿈, Orn 금 = Metal+HH_HaloGoldTrim, Leaf = Wood, Dormer_Surround = Marble+Cream, Glass = Glass 0.3, 꽃 = SmoothPlastic → 낮·밤 사진 + Studio 열 붙여 시트 완성.
2e. 10/11 집 07 끝판: fixed.glb 가져옴 → SkeletonTest.House07_Fixed(재질 3단계), 시트 `art/review/img3/skeleton07/house07_final_studio.jpg`, 사진 `v4/studio_fixed/`(C2c 빛으로 찍고 되돌림: tools/halo_light_sim.luau·restore). 판정 기다림.
2f. ④ 일반 생성기 `tools/skeleton_house.py` + `tools/house_specs/*.json`. 1묶음 02·05·09·03 골격 WorldKit z 60 줄(x 2950/2985/3020/3055), 장식 합본 `halo_houses_batch1_ornaments.glb`(import_now, 가져오기 기다림; 합칠 때 @dx,dy,dz로 집 원점 맞춤 → 붙일 땐 원점 3000,0,0 기준). 시트 `art/review/img3/houses/houses_batch1_blender.jpg`. 다음 묶음 01·04·06·08 → 10·11·12 → 가게 4 → 새 집 7 → 대성당·빛 성 C2.
2g. 10/11 오후 (사용자: "큰 작업은 API로") — ④ 15채 진행:
   - API 작업(tools/api_agent.py, 프롬프트 build/api_agent_prompts/*.md): house_specs_b2r(spec 11채, $1.09) · houses_b1_fixr(창 폭·09 원통·02 탑·3단 계단·돔 갈빗대, $1.30) · houses_gaps(문 위치·가게 진열창·발코니·창 화분 상자·박공지붕·퍼걸러·작은 탑 지붕, $1.67) → 셋 다 main에 반영(398da10f). 빠진 기능 표 docs/design/house_generator_gaps_2026-10-11.md.
   - API 작업은 --max-tokens 32000 + "파일 통째로 쓰지 말고 edit_file로 조금씩" 이 없으면 done_max_tokens로 아무것도 못 씀. 2D 원본 PNG는 API worktree에 없음(추적 안 됨) → 판정은 읽기 전용(--repo-dir 기본 = 공유 트리)으로 돌림.
   - 15채 Blender 시트 `art/review/img3/houses/houses_all15_blender.jpg`(build/render_houses.sh가 전부 다시 그림). 장식 GLB = art/models/tripo/skeleton_test/<name>_ornaments.glb.
   - 돌고 있음: API 판정 build/api_agent/houses_judge (읽기 전용, 결과 notes/houses_judge.md = 집마다 spec 고칠 값).
   - 천 = Fabric + HH_Fabric(이미지 개발 새 변형, 집 07·생성기 둘 다).
   - 공유 트리: 14:57 .git/index.lock 남아 HEAD가 origin보다 뒤(내 push는 push_paths라 정상). 다른 세션 git일 수 있어 안 지움 → 검수에 알림.
   다음 큐(리셋 뒤): ① houses_judge 결과 → spec 고치기(API write) → 다시 그림 → 시트 검수 ② 1묶음 재질·장식 GLB 합본(build: glb_merge @오프셋) → 사용자 Import 3D 1번 → WorldKit에 넣고 C2c 사진(halo_light_sim) ③ 집 07 차양 HH_Fabric WorldKit 다시 넣기 ④ 남은 기능(간판·박공·파라솔·온실·벽돌 돔) ⑤ 새 집 7 → 대성당·빛 성 C2 → 등불 Tripo → 다시 검수 11 → 새 구역 몬스터 8(after_reset §2).
3. 통과하면 ④ 건물 골격(지도 v2 건물 목록) — 이미지 생성 1 지도 기준.
## 멈춘 것 (A23-121 빛 마을 다시 만들기, 사용자 "3D 다시 재검수, 앞뒤옆 다 그려 넣기")
- 집 07·11 지붕 맵 따로 굽기(이미지 개발이 Roof 폴더를 기다렸음): **검수 10/11 '미루기'** — 지붕·문·창·차양 Tripo 조각은 A23-122 재검수 판정 뒤에 다시 구울지 정함.
- 집 11·가게 4의 몸통 바꾸기, 계단·다리·난간·받침 소품 골격: 이미지 생성 1의 새 구역 지도(1단계)가 나온 뒤.
- 꽃 덤불 3·생울타리 2(이미지 생성 2 High 앞면, `art/out/s2/halo/bushes_hq/`): **Tripo 안 넣음**. 앞으로 Tripo는 멀티뷰(앞·뒤·좌·우)만. 순서는 새 검수가 정함.
- 소품 57종(`tools/halo_props_list.txt`, 결과 `art/models/tripo/halo_props/<Name>/`): 빌드·맵은 끝났지만 **검수 시트 안 보냄**. 재검수 대상이라 결과 GLB(187MB)는 git에 안 올림(디스크에만). 시트는 `art/review/img3/<Name>_check.jpg`.
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
