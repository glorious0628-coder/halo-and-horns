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
1. 회색 상자 ★ 판정 대기(검수 → 사용자) → 고칠 것 반영
2. 폭포: 5단계에서 plan v2 falls로 새 지형에 다시 놓고 사진(고친 halo_waterfx)
3. (4단계 골격은 이미지 생성 3, 5단계 입히기 같이)

## 커밋 안 된 것: 없음 (공유 트리, push_paths 사용)
