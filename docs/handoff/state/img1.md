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
  - 전망 탑 = (158.7,-632.6), 사진 자리 = 탑 꼭대기(눈높이 75). 땅 높이에서는 대성당(꼭대기 84)이 광장을 가림.
  - 되돌리기(remove)는 보관 때 자리(Corner 속성, 없으면 옛 y0 -24)로 붙임.
  - WorldKit에 함께 있는 것: Workspace.HaloV2(Buildings·Bridges·Markers·AvatarRefs), Workspace.BeamTest(x -3000, 띠 시험대)

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
1. 회색 상자: 14·14b 다시 찍기(창 요청함) → 검수가 사용자에게 ★
2. 폭포: 5단계에서 plan v2 falls로 새 지형에 다시 놓고 사진(고친 halo_waterfx)
3. (4단계 골격은 이미지 생성 3, 5단계 입히기 같이)

## 커밋 안 된 것: 없음 (공유 트리, push_paths 사용)
