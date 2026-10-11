# 이미지 생성 1 — 상태 (2026-10-11 인계)

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
  - 사진 도구: `py tools/worldkit/skeleton_civic_shots.py [--prep]`(창 복원 = 새 검수 "전달함, 시작" 뒤) → `art/review/world/halo_v2/skeleton/`, 시트 `py tools/worldkit/skeleton_civic_sheet.py`(콘셉트 2D | 사진).
  - 계획 높이 KINDS: 성문 44→48, 탑 36→46, 전망 탑 50.
  - 앞으로: 사진 판정 → 고침, 대성당·빛 성 등은 이미지 생성 3, 5단계 재료(섬 아랫면 바위·흰 바위·디딤돌) 아직.
  - 보고처: **새 검수 = local_94cfa4bc-942c-4ac1-97a4-e9f609739523** (이전 local_78581314는 물러남).

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

## 큐
1. ④ 골격 사진 28장 + 시트(창 요청 대기) → 판정 → 고침. (③ 회색 상자는 사용자 OK)
2. 폭포: 5단계에서 plan v2 falls로 새 지형에 다시 놓고 사진(고친 halo_waterfx)
3. (4단계 골격은 이미지 생성 3, 5단계 입히기 같이)

## 커밋 안 된 것: 없음 (공유 트리, push_paths 사용)
