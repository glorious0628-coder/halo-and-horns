# 이미지 생성 3 — 인계 (2026-10-11 낮, 옛 세션 → 새 세션)
## 지금 상태 한 줄
집 07 골격 시험 3판까지 끝남(f686324). 검수 판정은 "방법 통과, 모양 아직 불통과". 4판은 **안 시작함**. 보고·창 복원 요청은 새 검수 `local_78581314-72d6-4b45-90b3-1bb6431efa7f`로.
## 멈춘 것 (A23-121 빛 마을 다시 만들기, 사용자 "3D 다시 재검수, 앞뒤옆 다 그려 넣기")
- 집 11·가게 4의 몸통 바꾸기, 계단·다리·난간·받침 소품 골격: 이미지 생성 1의 새 구역 지도(1단계)가 나온 뒤.
- 꽃 덤불 3·생울타리 2(이미지 생성 2 High 앞면, `art/out/s2/halo/bushes_hq/`): **Tripo 안 넣음**. 앞으로 Tripo는 멀티뷰(앞·뒤·좌·우)만. 순서는 새 검수가 정함.
- 소품 57종(`tools/halo_props_list.txt`, 결과 `art/models/tripo/halo_props/<Name>/`): 빌드·맵은 끝났지만 **검수 시트 안 보냄**. 재검수 대상이라 결과 GLB(187MB)는 git에 안 올림(디스크에만). 시트는 `art/review/img3/<Name>_check.jpg`.
## 큐 (순서) — 집 07 골격 4판 (새 검수 판정 6 + 옛 검수 판정, `skeleton07_v3_compare.jpg` 기준)
1. 몸통: 2D는 낮고 넓은 팔각(앞이 둥글게 꺾임). 앞 3면을 꺾은 팔각 반쪽으로 바꿈. 2D 비율은 벽 폭 : 벽 높이 : 지붕 = 1 : 0.81 : 0.33(2D 앞면 픽셀로 잼). 문 5.0×8.15는 그대로 두고 집을 넓힘. 목표값: XS≈8.0, HF≈5.25.
   - Tripo 식물은 화단 위치와 묶여 있음 → 화단 식물을 uniform 1.15배로 키우고 화단 높이도 ×1.15.
   - 지붕 scale은 xy 1.2, z 1.0.
2. 금: 흩어진 작은 네모 대신 블록 줄눈에 맞춘 이어진 띠 몇 줄 + 큰 장식 몇 개. 바닥 띠 끊김 0.
3. 대각면 창: 앞 정사영 크롭에선 금 L자만 보였음(창은 있음, 비스듬함). 아치·하늘색 유리·금테가 15칸에서 보이게 확인.
4. 문: 문 둘레가 진한 갈색 틈 → 대리석 문틀(안쪽 깊이) + 굵은 금 아치. 지금 나무 뒤판(Door_Back, 충돌 없음)이 틈으로 보임.
5. 화단: 꽃이 떠 보임 → 둥근 화분(흙 보이게) 안에 꽃·덩굴. 흙 Ground가 Studio에서 검게 보임 → Sand (140,100,62) 시험. 문 앞 계단은 **반원 2단**(세로 원기둥 반쯤 벽에 묻기).
6. 색: 대리석 1판(HH_HaloMarbleBlock 9) vs 크림 2판(HH_HaloMarbleBlock_Cream 12)을 집 07에 나란히 찍어 고르고 → 이미지 개발(`local_cc99020f-145c-49a0-b785-851525008ee9`)에 값 알림. 미리보기 맵 `art/ui/halo_tile/Halo_TowerMarbleBlockCream_*`.
7. 통과 기준: 15칸에서 2D와 같은 집, 5칸에서 옛 Tripo판보다 선명. Studio 사진(Tripo 조각 붙인 것) + 2D | 옛 Tripo | 골격 같은 각도·빛 비교.
## 도구 (전부 push됨, f686324)
- 생성: `py tools/skeleton_house07.py` → `build/skeleton_test_07.luau` + `.json`(파트) + `_place.json`(Tripo 조각 옮기기 규칙).
- 조각 배치: `blender … --python tools/skeleton_place.py -- art/models/tripo/skeleton_test/HaloDomeHouse_07_keep.glb build/skeleton_test_07_place.json art/models/tripo/skeleton_test/HaloDomeHouse_07_placed_v3.glb`.
  - region 규칙: x/y/z, near, arch, no_white, no_gold, drop_tall, drop_boxes
  - 변형 규칙: scale/about, move, rotz, align
- 미리보기: `tools/skeleton_preview.py <out> --parts … --glb …`. 같은 카메라로 옛 Tripo도(`--glb …_parts.glb`).
- 시트: `py tools/skeleton_sheet.py <2d> <tripo_dir> <skel_dir> <out.jpg>`.
- 조각 자르기: `tools/skeleton_keep.py`. Studio 사진: `STUDIO_NAME=WorldKit py tools/skeleton_shots.py <dir>`(창이 최소화돼 있으면 흰 사진 → 새 검수에 창 복원 요청).
- WorldKit 넣기: luau를 `{"code":…, "datamodel_type":"Edit"}` json으로 만들어 `STUDIO_NAME=WorldKit py tools/studio_mcp.py call execute_luau @file.json`.
## WorldKit 상태
- `Workspace.SkeletonTest`: House07_Skeleton 3판(478파트, 원점 3000,0,0, 앞 = -Z) + Tree_Pot_Skeleton(x 3026). 재질 변형 3종이 들어가 있음(building_variants 실행: 대리석 9 UPDATED, 크림 12·금 테 MADE).
- 이미지 생성 1이 `HaloDomeHouse_07_keep`(옛 keep, 20노드)과 `HaloVar3_RoundTree_E_keep`을 SkeletonTest 옆(+x 30쪽)에 둠. 크기는 가져온 그대로.
  - 3판에 맞는 건 `placed_v3.glb`(import_now에 넣어 둠, 원점만 맞추면 골격과 맞음). 옛 keep을 쓰면 skeleton_place 규칙대로 옮겨야 함.
- 3판 Studio 사진(Tripo 조각 없이, 골격만): `art/review/img3/skeleton07/v3_studio/*.png`, 모음 `v3_studio_grid.jpg`. 등불 Neon 상자가 틀 없이 떠 보이는 건 조각을 아직 안 붙여서임.
## 숫자·경로
- 시트: `art/review/img3/skeleton07/skeleton07_v3_compare.jpg`(3판), `skeleton07_compare.jpg`(2판).
- 2D: `art/out/s2/halo/roofs/HaloDomeHouse_07_roof_v2.png`.
- 3판 수치: 골격 478파트, 남긴 Tripo 1.28만 tris(옛 몸통 2.4만 + 1024 맵 16장 대신).
- Tripo 웹 잔액(25k 계정) ≈ 17,965(records.json 마지막). `import_now/`: git 금지, 다 쓰면 비움.
- 집 07·11 지붕 기와 오인식 고친 parts(07 WinPane 547→281, 11 507→143)는 이번 push에 포함. 이미지 개발이 이미 새 id로 올림.
## 막힌 것
- 없음. 4판 시작 전 새 검수의 순서 확인.
