# 이미지 생성 1 — 상태 (2026-10-11 인계)

## 지금 (10/11 밤, plan v2 검수 고침 끝, 비우기 전) — 먼저 읽기
- 검수 = **local_d522c0f1-07cf-4db1-b178-5f335a56db7c** (모든 것 검수). 보고는 send_message로 묶음마다 한 번.
- **끝낸 것(e8bd29f + 353c72c, 검수에 보고함):** `docs/review/halo_plan_v2_review_2026-10-11.md` 결정 7개 + 진짜 16건 + 확인 안 한 21건 고침.
  - 걷는 속도 = Config.Player.WalkSpeed(20, plan `walk_speed`). 성문→대성당 **26.0초**(대성당 굽은 계단 `cathedral_stairs` w12, 세 번 꺾음, 자체 높이 `ys`, `rails=True` → 걷기 계산이 난간 칸을 막음 + 대각선 모서리 질러가기 금지). 새 구역 `cathedral_steps`(계단 사이 꽃 단 = 가까운 계단 높이, halo_blockout `terrace`). 대성당 (84,-772), 앞 마당 (82,-718).
  - 전망대 y 28(탑 꼭대기 78 < 대성당 84), 검사 "대성당보다 높은 땅/건물". 절벽 마을 = 진짜 두 단: `tiers` 위 단 22(집 3·4·5·6·8), 아래 18(1·2·7), 절벽-전망대 계단 `cliff_lookout`.
  - 발판 둘레 12×12+2(`PADS`, `PAD_KEEP` 8): 고리길 남쪽으로, Tower_GateEast (39,-346) 문 남쪽, 채움 빛 2개 옮김, Sir Gleam (-20,-390). 검사: 길·건물·채움 빛·고정점·소품·등불 vs 발판.
  - 다리 = 길-시냇물 교차점에 자동(`fix_bridges`, `BRIDGE_ROAD`), B4 새(정원 길), B2 len 16. 검사 "다리 없이 물 건넘"·"길이 물에 걸림"·"시냇물이 건물에 걸림"·"마당이 건물에 걸림". 샘·W2·정원 웅덩이·W3 자리 높이에 맞게.
  - 구역 밖 = 모서리 + 받침 5 전부 안(`PAD_MARGIN`): 12채 옮김(+시장 위 언덕·정원 마을 다각형 넓힘), 자리는 scratchpad fit.py로 찾음. 받침 높이 다른 집 맞닿음 검사.
  - 문 길(`door_spurs`): 문 5칸 앞 점에서 가까운 길, 자기 집·남의 집·발판을 모서리 하나로 돌아감. 자기 문 길은 0번 구간만 검사 제외. 블록아웃 길은 건물 안 칸을 안 칠함.
  - 기울어진 구역 건물 받침 = 문 자리 땅 높이(시장 4→8·정원 12→16), 문 앞 턱 옆도 섞음(APRON_SIDE 8). 광장 원판 낮춤 규칙 = 두 도구 같은 칸 가운데 기준(skeleton_ground `D.grid`).
  - 첫 10분 = 실제 흐름(스폰+Hallie 카드 → 성문 → 교차로 대장간 → 초원), 가게·훈련장은 `first_10_return`(M1_4). 이유 글 = 새 집 문서(halo_new_houses) 주민대로, 고정점 code 글 = 최종 숫자(`final_fixed`, 가게 NPC는 자기 문 옆). 큰 길은 분수 동쪽으로.
  - 결과: plan 검사 0건, 소품 129 + 등불 56 검사 0건, 고장 넣어 시험 6가지 다 잡힘. 고정점 표 다시 만듦.
- **WorldKit(열림, 파일 저장 안 함)에 새 계획 다 다시 지음(10/11 밤):** halo_blockout apply → skeleton_civic_run(4채) → skeleton_ground_run(1467조각, CSG 실패 0) → halo_props_place(185, 땅 못 찾음 0). 높이 재확인(계단 10→30, 두 단 18/22, 전망대 28). 집·가게·대성당·성은 회색 상자(이미지 생성 3 골격 대기, 자리가 바뀐 것: 가게 2·집 다수·성·대성당).
- 사진은 아직(창 필요 → 검수 허락). 경로 확인 도구: `HALO_DUMP=1 py tools/halo_blockout.py` → build/wk/blockout_grid.json.
- **이미지 생성 3과 집 크기 맞춤(10/11 밤):** 짝 = Hill1 05 · Hill2 11 · Hill3 01 · Cliff1 10 · Cliff2 08 · Cliff3 06 · Cliff4 03 · Cliff5 09 · Garden1 12 · Garden2 02 · Garden3 07 · Garden4 04 (새 집 자리 = Hill4·Cliff6·7·8·Garden5·6·7). 몸통 W×D·문 면 위치·가게 문 옆 비킴(빵 오른쪽 4.6, 주스 왼쪽 4.6, 물약 오른쪽 3.8)은 이미지 생성 3 메시지대로, 원점 = 문 면을 door_at에. 계산: 16채 겹침 0·길 0·구역 안. **검수 OK 오면 → plan에 집마다 진짜 크기(몸통 + 처마 1.2) 넣고 검사 다시.**
- **기다리는 것:** 검수 판정. 개발 쪽에 넘길 것(검수 몫): 훈련장을 퀘스트가 가리키게 할지(코드 변경 요청), 고정점 표 B(NPC 새 At/Look).
- **이미지 개발 부탁:** HH_Fabric 밤 사진을 내 WorldKit 촬영 때 같이 찍고 싶어함 → 내 다음 WorldKit 촬영 차례가 정해지면 검수에 먼저 알릴 것.
- 메인 Studio(81671223175574)는 절대 안 건드림, 옛 메인 4차 적용 안 함.

## 지금 일: A23-121 빛 마을 처음부터 다시 (`docs/design/halo_restart_2026-10-11.md`)
- ① 이야기와 구역: **끝, 사용자 OK "지도 괜찮아"(10/11)**. 대성당 동쪽(72,-652, 축에서 13°) + 큰 길 광장에서 굽힘 반영됨.
  - 계획 `docs/design/halo_plan_v2_2026-10-11.json` ← `py -X utf8 tools/halo_plan_v2.py` (지도 `art/review/world/halo_v2/halo_plan_v2_map.png`)
  - 구역 11, 건물 22(종류·바닥 w×d·층·문 방향/자리/크기), 첫 10분 고리, 고정점 keep/move 표(new_xyz + 고칠 Config), 문에서 보이는 정도(gate_view)
  - 검사 0건: 포장 23%, 거울 짝 0, 겹침·땅 밖·스폰-문 통로(|x|≤12, z -330..-432) 막음 0
- ③ 회색 상자: **WorldKit에 지음(10/11 12:38, 새 이미지 생성 1)**, 사진 25장 → 검수 ★ 판정 대기
  - `py tools/halo_blockout.py --mode apply|remove|plan` → `build/wk/halo_blockout_apply.lua` (템플릿 `tools/worldkit/halo_blockout.luau`)
  - 사진: `py tools/worldkit/halo_blockout_shots.py` (창 복원 = 검수 "전달함, 시작" 뒤에만) → `art/review/world/halo_v2/blockout/*.jpg`, 모음 `blockout_sheet_all.jpg`
  - 고친 것: 지형을 WriteVoxels로 칸마다 씀. **로블록스는 채운 높이보다 표면을 2칸 위에 그림**(SURF=2, ReadVoxels로 확인) → 지금 계획 높이와 딱 맞음(입구 0, 광장 10, 정원 12, 절벽 18, 전망대 34). 옛 대리석 성문·HaloSign(Map.Gates/Landmarks)도 HaloV1Hold로.
  - 사진에서 본 문제: 오프닝 카메라 시작(18,30,-315)이 성문 앞벽만 보임(성문 높이 44 > 카메라 30), 경로가 오른쪽 기둥(x 8..25, z -326..-336)을 뚫음 → 검수가 고칠 방법 정함(개발 1 몫). 섬 윤곽이 위에서 거의 네모. 전망대 눈높이는 집에 가림.
  - **검수 1차 판정(10/11 12:45) 4개 고침**: ① 해안선 = 만 3곳(북서·북동·동) + 서쪽 물굽이 + 남쪽 들쭉날쭉 절벽(바위 가장자리), 북쪽 다리 쪽 모래 해변, 바다는 깊고 어둡게(-40 현무암, 해변 앞만 모래턱 -6) — `tools/halo_plan_v2.py` LAND + `halo_blockout.py` PAVED/BEACH/SEA_TIER. ② 광장 = 분수 둘레 r30 + 스폰 둘레 r14 흰 대리석 포장. ③ 오프닝 카메라 새 오프셋(SPOT.Halo 기준) 시작 (0,-4,140) → 끝 (0,-2,58), 통로 한가운데 높이 12~14, 광선 걸림 0 → 검수가 개발 1에 넘김. ④ 땅 높이 전망대에서는 대성당(꼭대기 84)이 광장을 가림 → 전망 탑을 북동 모서리 (178,-654)로(곶 내밂), 탑 꼭대기 눈높이 75에서 광장·분수·대성당·바다 통과.
  - **검수 2차(10/11 12:55): 섬 윤곽 통과("떠 있는 섬 그대로")**: 들어오는 곳 가운데(|x|≤40, z≥-440)는 그대로, 바깥은 x 0.86·z 0.90배로 당김(`halo_plan_v2.py` SHRINK, 계획의 모든 좌표에 적용 — 6단계 고정점 new_xyz도). 집 2채 옮김(절벽 5 raw (136,-640), 정원 2 raw (-156,-626)). 새 해안선(최종 좌표): 큰 곶 4·만 4, 변 < 40. 바다 = 해안 둘레 20칸 물 띠 + 바깥 바위 테, 그 밖은 빈 하늘(떠 있는 섬). 받침은 -48 평평 → **5단계에서 뾰족한 떠 있는 바위 아랫면으로 다듬기**. 넓은 바다(사방 300칸)는 해 보고 취소(clearWideSea가 남은 것 지움).
  - **③ 3차 = 1.5배 (A23-124, 사용자 "빛 마을 너무 작은 거 아니야?", 10/11 13:10 WorldKit에 지음)**: SHRINK → kx=kz=1.5(가운데 고정). 땅 x -300..295, z -321..-853(26.5만 st²). 해안선 = 2차 모양을 같이 늘리고 긴 변 나눔. 더함(최종 좌표, `halo_plan_v2.py` "③ 3차 additions"): 집 7(언덕4·절벽6~8·정원5~7, 집 19), 빛 성 KINDS 100×70×44, 골목 10, YARDS 8, 연못·샘 3, 광장 포장 r40. 새 검사: 길·물이 건물을 지남. 걷는 시간(`halo_blockout.py` 격자 Dijkstra → `art/review/world/halo_v2/walk_times.json`): 성문→대성당 25.7초, 가장 먼 집 29.6초. 격자·BOX는 땅에서 자동(EDGE 32), 사진 자리도 계획에서 자동(`halo_blockout_shots.py`, `--prep`은 창 없이 목록만). 사진 `blockout_sheet_x15.jpg` → 검수 ★ 대기.
  - 6단계 때 넓힐 것: HaloTown 구역 상자, Map.Land IslandHalo, Map.Bounds(MinX -260/MinZ -720 → 땅 -300/-853), Outskirts, 미니맵·큰 지도(고정점 표 "구역 상자·섬 땅·경계").
  - 전망 탑 = (247,-761), 사진 자리 = 탑 꼭대기(눈높이 75), 광장·분수·대성당·바다 광선 통과.
  - 앞면 햇빛 % (checks.front_sun, 위도 35 하루 해 길): 해는 늘 +z로 11.5° 기움 → 남향 면 직접 해 0. 성문 안쪽 0%, 벽은 최선이어도 평균 세기 30% → **검수: 방향 안 바꿈, 빛 설정은 이미지 개발 몫**.
  - 5단계 재료 목록 = plan json `dressing`(구역 11개: 길 재질·식물·이유 있는 소품(halo_props_list 이름)·물·경계·빛·빈 잔디, KIT, 새로 필요한 것, 등불 자리 48 자동(규칙 6), 성문 안쪽 채움 빛 4, uplights, PhotoDisc 6, 채집 덤불).
  - 되돌리기(remove)는 보관 때 자리(Corner 속성, 없으면 옛 y0 -24)로 붙임.
  - WorldKit에 함께 있는 것: Workspace.HaloV2(Buildings·Bridges·Markers·AvatarRefs), Workspace.BeamTest(x -3000, 띠 시험대)

- **④ 건물 골격 (내 몫: 성문·성문 동쪽 탑·전망 탑·무기고; 집·가게·대성당·빛 성은 이미지 생성 3)** — 10/11 WorldKit에 지음, 사진 대기
  - `py tools/worldkit/skeleton_civic_run.py [--only Gate,...] [--mode remove]` (창 필요 없음) ← `tools/skeleton_civic.py`(계획 자세 x,z,yaw,ground_y에서 생성). 파트 빼기(CSG) 진짜 구멍, 대리석 크림 12 + 금 트림(255,175,25), 무기고 지붕은 파란 대용.
  - 회색 상자 자리에 바꿔 끼움: HaloV2.Buildings.<id>(회색은 ServerStorage.HaloGrayHold, 마스터 ServerStorage.HaloSkeletons). `halo_blockout` 다시 지어도 계획 자세 같으면 마스터를 복제(Skeleton 속성, PlanPose "x,z,yaw,ground").
  - 성문: 50×16×48, 통로 16×30(광선 통과), 탑 지름 14 ×2(금 돔·첨탑·배너·창), 아치 대리석+금, 메달리온, 금 코니스. **PrimaryPart = Lintel(앞 반쪽 금 코니스, 중심 y+4 → 월드 (0,-330), MapBuilder placeGate와 맞음)**. 6단계에서 모델 이름을 Gate_HaloTown으로.
  - 탑 12(46, 문 4×7 진짜): GateEast = 닫힌 갤러리 8창, Lookout = 열린 발코니(바닥 WalkGround 태그·난간·기둥 8, 눈높이 +4.8) 약 50.
  - 무기고 16×12: 승인 2D 없음 → 이미지 생성 2에 시안 요청(검수 전달).
  - 사진 28장 찍음(10/11 14:3x, 창은 이미 떠 있어 복원 없음): `art/review/world/halo_v2/skeleton/` + 시트 `sheet_all.jpg`·`sheet_<건물>.jpg`. 고친 것: 배너 Fabric→SmoothPlastic(스튜디오 빛에서 검게 나옴), 창 불투명 따뜻한 색(밤에 PointLight), 성문 위 후광 2겹, 발코니 카메라는 기둥 사이 틈에서.
  - **검수 판정(10/11) ④ 통과 + 고칠 것 4개**: ① 벽 차가움·② 금 올리브 = **WorldKit 기본 빛이 칙칙해서**(값은 그대로 맞음): C2c 낮(`tools/halo_light_sim.luau` C2c day → 사진 → `halo_light_restore.luau`)로 찍으면 크림 대리석 + 밝은 금(`art/review/world/halo_v2/skeleton_c2c/`). 사진은 앞으로 C2c로(`SK_OUT=… py tools/worldkit/skeleton_civic_shots.py`). ③ 무기고를 승인 2D(`art/review/s2/halo_armory_views.jpg`)에 맞춰 다시(모임지붕·문 위 금 방패 메달·쇠창살 아치 창·문 옆 등·금 띠·기둥, 113조각; 뒤 창은 이미지 생성 2 새 2D 뒤). ④ 성문 받침 위 등·작은 받침 기둥·난간, 무기고 통·상자·걸이·벽등 → plan dressing `new_needed`.
  - **다음 일(검수 10/11 ⑤ 준비)**: ① 광장·길·마당·계단·난간 파트 골격(WalkGround 태그) → api_agent `skeleton_ground`(branch `api/skeleton-ground`, 프롬프트 `build/api_agent_prompts/skeleton_ground.md`), ② 떠 있는 섬 아랫면 뾰족한 바위 → api_agent `island_underside`(branch `api/island-underside`), ③ 고정점 표 → **끝**(`docs/design/halo_fixed_points_v2_2026-10-11.md`, 생성 `tools/halo_fixed_points.py`). api 결과는 `build/api_agent/<job>/result.md`, 받는 법: `git fetch origin api/<이름>` → 결과 파일을 확인 → WorldKit 적용(생성기 실행기 `tools/worldkit/skeleton_ground_run.py`). 시작이 느리면(큰 작업 폴더 만들기 10분) 겹쳐 시작하지 말 것(--overwrite로 두 번째 시도가 첫 시도의 폴더를 지움).
  - 배너: Fabric + MaterialVariant HH_Fabric(이미지 개발 통과)로 되돌림.
  - 사진 도구: `py tools/worldkit/skeleton_civic_shots.py [--prep]`(창 복원 = 새 검수 "전달함, 시작" 뒤) → `art/review/world/halo_v2/skeleton/`, 시트 `py tools/worldkit/skeleton_civic_sheet.py`(콘셉트 2D | 사진).
  - 계획 높이 KINDS: 성문 44→48, 탑 36→46, 전망 탑 50.
  - 앞으로: 사진 판정 → 고침, 대성당·빛 성 등은 이미지 생성 3, 5단계 재료(섬 아랫면 바위·흰 바위·디딤돌) 아직.
  - 보고처: **새 검수 = local_94cfa4bc-942c-4ac1-97a4-e9f609739523** (이전 local_78581314는 물러남).

## 10/11 17:15 새 검수(local_d522c0f1) 차례 — 사진 16장 + 섬 아랫면 2차
- api/skeleton-ground·island-underside 내용 = main(daf40946 스쿼시), 브랜치 삭제 가능. WorldKit은 `build/WorldKit.rbxlx`(15:20 저장) 열어서 다 있음(HaloV2 Buildings 29·Ground 1440) — 다시 지을 필요 없었음. 열 때 `Start-Process <Studio exe> WorldKit.rbxlx -WindowStyle Minimized`, 사진 도구는 SW_SHOWNOACTIVATE라 앞으로 안 끌어옴.
- `py tools/halo_blockout.py --mode terrain` 새로 만듦: 지형만 다시 씀(HaloV2 회색 상자·골격·Ground 파트 그대로). apply는 HaloV2를 지우므로 쓰면 skeleton_civic_run·skeleton_ground_run도 다시.
- 섬 2차(검수 ③): 물 띠 4칸(16) + 바위 테 4칸(16, 2칸은 멀리서 LOD 구멍), 테 위 물보다 2.8~5.8 높게, 띠·물가 3칸 땅은 -30 아래까지 바위. 아랫면 = 가운데로 갈수록 깊게(105·dn^0.9, 흔들림) + 큰 뾰족 6 + 중간 22 + 작은 것, 깊이 최대 216(VY0 -232, UND_UNIT 3). 옆 물-공기 맞닿음 1454 → 14(남은 14는 시냇물 윗면이 둑보다 1칸 높음, 섬 안쪽, 옛날부터).
- 사진 자리: hill_yard(광장 쪽 30, 높이 16), cathedral_stairs(뒤·위로) + 벽 앞으로 당기기(두 장만). `--nobloom` 추가.
- 원인 찾음: plaza_high 흰 얼룩 = 지형 포장(Concrete→GE_HaloPave, r40)이 분수 원판 파트(r40, 두께 0.5, 윗면 10.15) 사이로 솟음(블룸 아님, nobloom 사진도 같음). bridge_B1 검은 덩어리 = 훈련장 지형 Ground + MaterialVariant GE_Ground가 C2c 빛에서 거의 검게(재질 빠진 것 아님).

## 10/11 19:xx 5단계 입히기 준비: 소품 하나하나 이유 칸 (검수 지시, 파일만)
- `tools/halo_props_v2.py` SPEC = 손으로 정한 소품 130개(문·마당·장면·물가 기준 자리, 키트, why) + 자동 등불 44(이유 = 그 길·마당). `halo_plan_v2.py` main이 부름 → plan json `dressing.props`·`new_kits`·`stage5_fixes`, 검사는 `checks.issues`(지금 0).
- 검사: 이유 없음·키트 모름·땅 밖·건물에 박힘·통로·물 위·길/골목 막음·등불은 길·마당·문·광장만·나무/덤불/바위는 섬 끝 35·구역 끝 12·물가 10 안만·화분은 문·길·마당·장면·영웅상·광장만·큰길 4 안 키 큰 것(규칙 10)·고정 NPC/발판 겹침·소품끼리 겹침·문 앞 거울 짝·40×40 같은 키트 >5(규칙 11). 빈 why·통로 넣어 시험 → 잡힘.
- 자동 등불: 다른 길·골목·문 앞 길 한가운데면 반대쪽으로, 그래도 안 되면 뺌(48 → 44).
- 지도 `art/review/world/halo_v2/halo_props_map.png`(번호 = 표, 빨간 글씨 = 새 키트 NEW_ 18종). 구역 밖 가장자리 소품은 가까운 구역(zone)에 묶음.
- 바꾼 것: 성문 경비 초소 = 성문 안쪽 **서쪽**(동쪽은 탑·발판·채움 빛, 비대칭).
- 검수 사진 판정 → 5단계 할 일 = plan `dressing.stage5_fixes`(길 두 겹·반 잘린 디딤돌·하늘색 기둥 숨김·바위 테·LOD 점·폭포 v2).
- **금 2차(이미지 개발, 10/11 저녁)**: WorldKit(저장 안 함)의 HH_HaloGoldTrim 파트 4110개 = 색 (255,195,45), MV 금속 0.5·거칠기 0.15. 되돌리기 `tools/gold_trim_apply.luau` MODE "undo". **내 생성기(skeleton_civic·skeleton_ground GOLD_RGB)는 아직 (255,175,25)** → 다시 돌리면 옛 금색으로 돌아감. → **최종 (255,168,36)(cd1aaa3) 확정, 두 파일 GOLD_RGB 고쳐 올림** — 이제 다시 돌려도 금색 같음.
- **검수 판정(10/11): 소품 130 + 등불 44 통과.** 밀도는 5단계 사진에서 다시(분수 광장·대성당 언덕 잔디·전망대가 비어 보이면 이유 있는 것만 더함). 새 키트 18종 = **전부 만듦** → 목록 `docs/design/halo_new_prop_kits_2026-10-11.md`(2D 4면 이미지 생성 2, Tripo·Blender 이미지 생성 3, 검수가 넘김).
- **WorldKit에 놓음(10/11 저녁, Edit, 파일 저장 안 함)**: `py tools/worldkit/halo_props_place.py [--mode remove]` → `Workspace.HaloV2.Props` = StandIn 96(옛 WorldKit3D 등불·화단·화분·나무·토피어리·난간을 키트 키×크기로 줄여 대신 놓음, 속성 StandIn — 자리·크기 보기용, 최종 모양 아님) + Placeholder 78(반투명 상자 + 이름: 파랑 41 = 만든 키트지만 Studio에 없음 HaloReasonHQ·Flagpole, 주황 37 = NEW). 땅 못 찾은 것 0, 탑 꼭대기 사진 원판은 탑 위. 속성 PropId·Kit·Why·Anchor.
- 왜 진짜 키트가 아닌가: HaloVar4_*/HaloReasonHQ_*/FlowerPotHQ 모델은 파일(`art/models/tripo/halo_props/<이름>/*_parts.glb`)만 있고 WorldKit에 안 올라감 + 3D 재검사(`docs/review/3d_recheck_2026-10-11_result.md`) 178개 전부 '다시'. 고쳐진 키트가 Studio에 들어오면 STAND 표 대신 그 모델을 복제하게 바꿀 것.
- 사진은 아직(창 신청 필요). 다음: 사진 → 밀도 판정 → stage5_fixes.
- (옛) 다음: 검수 판정(새 키트 18종 중 무엇을 만들지 = 이미지 생성 2/3 몫) → WorldKit 놓기 도구(소품 = ImportHold/키트 모델, 높이는 지형에서).

## 10/11 18:00 구획·이유·골격 다듬기 (검수 지시)
- 검수 판정: 섬 2차 통과. 5단계 할 일로 적음: **바위 테가 옆에서 검고 두꺼운 곧은 띠**(색·튀어나온 바위로 다듬기), **under_side_close 파란 점 2개**(LOD 티).
- 광장 원판 아래 지형 1칸 낮춤(`PAVED_SINK`, skeleton_ground `D.plaza_sink`로 원판 높이 그대로), 훈련장 땅 = 모래(`DIST_MAT`), e39c823.
- A23-117 이유 칸: `tools/halo_plan_v2.py` DIST_JOB(구역 하는 일)·WHY_B(건물 29: 누가 살고 왜 여기)·WHY_YARD·WHY_BRIDGE·WHY_SCENE → plan json `job`/`why`. 빠지면 checks에 "이유 없음". 집 주인 이야기(종지기·성가대·정원사 등)는 내가 정한 안 — 검수/사용자가 바꾸면 WHY_B만 고침.
- 구획 지도: `art/review/world/halo_v2/halo_district_map.png`(구역 색·이름, 건물 번호 = 오른쪽 표, 주황 테 = A23-124 새 집 7).
- 골격 다듬기(지형): 기울어진 구역(시장 4→8·정원 12→16·절벽 18→22)에서 문 앞 땅이 문턱보다 최대 4 높았음 → 문 앞 평평한 턱(APRON_D 8 + 경사 12), 건물 받침 평탄화는 **벽에서 5 안**(전에는 모서리 점에서만 3 → 안쪽 바닥이 최대 4 솟음). 지금: 문 앞 땅 ≤0.4, 안쪽 바닥 ≤0.8. Ground 골격 다시 지음(1403조각, CSG 실패 0). 사진 `art/review/world/halo_v2/doors/`(`ground_shots.py --doors`).
- 문 안 갈색 = 바닥 잔디를 70% 투명 빨간 DoorHole 판 너머로 본 색(문제 아님).

## 폭포 물줄기 (5단계 재료)
- High 최종 업로드 `rbxassetid://111806947888357` (`art/ui/Halo_WaterfallStreaks.png`, approved.json·asset_ids.json 기록, 5 크레딧)
- `tools/worldkit/halo_waterfx.luau` STREAK 넣음, 경사 물 램프 따라 착지점(9/9), 거품 원판 → 둥근 물보라 파티클, 띠 넓고 밝게. WorldKit에 적용됨(옛 지형 위).
- **원인 찾고 고침(10/11 12:40)**: ① Attachment에 WorldCFrame을 넣고 나서 부모에 넣어 위치가 2배로 밀림(띠가 -6016,103에 그려짐) → 부모 먼저. ② 비FaceCamera 띠의 폭은 부착점 Y축으로 펼쳐짐(시험대: X=옆/Y=위 → 서는 지느러미, X=흐름/Y=옆 → 눕는 띠) → fromMatrix(점, down, side). ③ 기본 파티클이 뾰족한 별(빛살) → 물보라·거품 Texture = smoke_main.dds(둥근 연기). 시험대 사진 `art/review/world/halo_v2/blockout/90_beamtest_*.jpg`.
- 회색 상자 지은 뒤에는 새 지형에 폭포가 다시 생겨야 함(halo_waterfx는 HaloTerrainStore "Waterfalls"를 읽음 — 새 지형엔 없음 → 5단계에서 plan v2 falls로 바꿀 것).

## WorldKit에 있는 것
- ServerStorage.ImportHold 22개(import_now 10/11: 대성당 v2, 성문 v3, 탑 A/B/C, 집 01~12 parts, 가게 4 parts, 빵집 할머니) — 보관만
- Workspace: HaloDomeHouse_07_keep, HaloVar3_RoundTree_E_keep(이미지 생성 3 몫), 옛 빈 "Scene" 모델 6개(손 안 댐)
- 옛 빛 마을(Map.Decor.HaloProps/HaloGold/HaloWaterFx, 옛 성문·HaloSign, 지형 복사본)은 ServerStorage.HaloV1Hold에 보관됨(remove로 되돌림). WorldKit 파일 저장은 안 함 — 닫혀도 apply로 다시 지음

## 멈춘 것 (A23-121)
- 메인 4차 적용, 옛 plan json(`halo_layout_plan_2026-10-10.json`, `tools/halo_layout.py`) 고치기, 대성당 v2·성문 v3·탑 조립본 배치

## 큐 (10/11 15:20 정리 — 사용량 한도라 쉬는 중, 판정은 19:00 리셋 뒤)
1. **WorldKit Studio가 15:20에 닫힘**(Roblox Studio 프로세스 0, `list_roblox_studios` = []). `build/WorldKit.rbxlx`는 15:20:26에 70MB로 저장됨 → **열면 지금까지 지은 것이 있을 가능성**(검수가 창 여는 단계를 "전달함, 시작"으로 허락해야 함). 열린 뒤 확인: `Workspace.HaloV2`(Buildings 29·Ground·Bridges·Markers), `ServerStorage.HaloSkeletons`·`HaloGrayHold`·`HaloV1Hold`. 비어 있으면 아래 순서로 **파일만으로 다시 지을 수 있음**(창 필요 없음, 전부 execute_luau, STUDIO_NAME=WorldKit):
   `py tools/halo_blockout.py --mode apply` → build/wk/halo_blockout_apply.lua 실행 (러너 예: `build/.../runluau`, 또는 studio_mcp execute_luau) → `py tools/worldkit/skeleton_civic_run.py` → `py tools/worldkit/skeleton_ground_run.py`
2. 사진 16장 아직 못 찍음(Studio 닫혀서): `py -X utf8 tools/worldkit/ground_shots.py`(--prep으로 자리 목록; C2c 낮 빛 바꿨다 원복 포함, 창 복원 "전달함, 시작" 뒤) → `art/review/world/halo_v2/ground/`. 본 것: 길 988·광장 원판 4·마당 16·계단 147·난간 220·다리 판 60 (총 1435조각, CSG 실패 0, WalkGround 태그 972+다리 3), 섬 아랫면 복셀 읽기(광장 아래 -56, 스폰 -80).
3. 건물 골격 사진 판정·고칠 것(④ 통과, C2c 사진 통과) — 다음 건물 골격(집·가게·대성당·빛 성)은 이미지 생성 3.
4. 5단계 입히기(꽃·덤불·생울타리·등불·소품·폭포 새 섬에) — 재료 목록 plan dressing, 새 섬 폭포는 plan falls로 halo_waterfx 다시.
5. 6단계: 고정점 표 `docs/design/halo_fixed_points_v2_2026-10-11.md`대로 개발 1·2가 Config·시험 고침 → 메인 반영 1.
6. 무기고 뒤 창 2개: 이미지 생성 2가 새 2D 뒤에 골격에 넣음. 성문 받침 등·작은 기둥·난간은 Tripo 4면 2D 큐.
7. api_agent: 큰 코드는 `docs/handoff/api_agent_howto.md`대로(작업 폴더 만들기 느림 → 겹쳐 시작 금지). 이번에 만든 것: skeleton_ground($1.21), island_underside($0.38), 둘 다 main에 올림(daf4094), 브랜치 삭제 가능.

## 커밋 안 된 것: 없음 (공유 트리, push_paths 사용)
