# 이미지 생성 1 — 상태 (2026-10-11 인계)

## 지금 일: A23-121 빛 마을 처음부터 다시 (`docs/design/halo_restart_2026-10-11.md`)
- ① 이야기와 구역: **끝, 사용자 OK "지도 괜찮아"(10/11)**. 대성당 동쪽(72,-652, 축에서 13°) + 큰 길 광장에서 굽힘 반영됨.
  - 계획 `docs/design/halo_plan_v2_2026-10-11.json` ← `py -X utf8 tools/halo_plan_v2.py` (지도 `art/review/world/halo_v2/halo_plan_v2_map.png`)
  - 구역 11, 건물 22(종류·바닥 w×d·층·문 방향/자리/크기), 첫 10분 고리, 고정점 keep/move 표(new_xyz + 고칠 Config), 문에서 보이는 정도(gate_view)
  - 검사 0건: 포장 23%, 거울 짝 0, 겹침·땅 밖·스폰-문 통로(|x|≤12, z -330..-432) 막음 0
- ③ 회색 상자: **도구만 준비, WorldKit에 아직 안 지음** ← 다음 할 일
  - `py tools/halo_blockout.py --mode apply|remove|plan [--offset X,Z]` → `build/wk/halo_blockout_apply.lua` (템플릿 `tools/worldkit/halo_blockout.luau`)
  - 실행: `{"code": <파일>, "datamodel_type":"Edit"}` json → `STUDIO_NAME=WorldKit py tools/studio_mcp.py call execute_luau @json`
  - apply = 옛 지형 복사본+옛 장식을 ServerStorage.HaloV1Hold에 보관 → 상자(x ±214, z -322..-714) 비우고 Terrain(4칸 격자, 길·계단 Slate·시냇물·바다) → Workspace.HaloV2(Buildings 22 회색 껍데기, Bridges Bridge_B1~3, Markers 고정점) / remove = 되돌림
  - 오프라인 미리보기 `art/review/world/halo_v2/blockout_raster_preview.png`
  - **검수 10/11: 이미지 생성 3의 SkeletonTest(x=3000)와 떨어진 곳에 지을 것** → 기본(제자리, 옛 빛 마을 자리 x -200..200)이면 떨어져 있음. 확인 후 apply.
  - 그다음 사진 ★: 들어오는 곳 눈높이, 광장, 구역별, 위에서, 아바타 크기 비교 → 새 검수에 창 복원 요청과 같이.
  - 3단계에서 볼 것: 오프닝 카메라 (18,30,-315)→(6,26,-340)가 성문 통로 16×30 안으로 지나가는지, 계단 자리(Slate) 길이, 막힌 곳.

## 폭포 물줄기 (5단계 재료)
- High 최종 업로드 `rbxassetid://111806947888357` (`art/ui/Halo_WaterfallStreaks.png`, approved.json·asset_ids.json 기록, 5 크레딧)
- `tools/worldkit/halo_waterfx.luau` STREAK 넣음, 경사 물 램프 따라 착지점(9/9), 거품 원판 → 둥근 물보라 파티클, 띠 넓고 밝게. WorldKit에 적용됨(옛 지형 위).
- **사진 10/11 12:21 (고친 뒤 3장)**: `art/review/world/halo_new/waterfx/waterfx_EC_1~3.jpg`, 모음 `waterfx_EC_crop3.jpg` (도구 `tools/worldkit/waterfx_shots.py`). 결과: 접시 거품판은 사라짐 OK. **하지만 물줄기 띠(Beam)와 물보라 파티클이 사진에 안 보임** → 다음 할 일: Edit 모드 캡처에서 Beam/파티클이 안 그려지는지(Play 캡처로 확인), 띠가 지형 물 표면 아래 묻혔는지(Lift 0.25 → 0.8), 띠 방향(fromMatrix X=옆, Y=법선)이 맞는지 시험용 Part 위 Beam으로 확인.
- 회색 상자 지은 뒤에는 새 지형에 폭포가 다시 생겨야 함(halo_waterfx는 HaloTerrainStore "Waterfalls"를 읽음 — 새 지형엔 없음 → 5단계에서 plan v2 falls로 바꿀 것).

## WorldKit에 있는 것
- ServerStorage.ImportHold 22개(import_now 10/11: 대성당 v2, 성문 v3, 탑 A/B/C, 집 01~12 parts, 가게 4 parts, 빵집 할머니) — 보관만
- Workspace: HaloDomeHouse_07_keep, HaloVar3_RoundTree_E_keep(이미지 생성 3 몫), 옛 빈 "Scene" 모델 6개(손 안 댐)
- 옛 빛 마을(Map.Decor.HaloProps/HaloGold/HaloWaterFx, 지형) 그대로 — blockout apply가 보관함

## 멈춘 것 (A23-121)
- 메인 4차 적용, 옛 plan json(`halo_layout_plan_2026-10-10.json`, `tools/halo_layout.py`) 고치기, 대성당 v2·성문 v3·탑 조립본 배치

## 큐
1. 회색 상자 apply → 사진 ★ → 새 검수
2. 폭포 사진 3장 → 새 검수
3. (4단계 골격은 이미지 생성 3, 5단계 입히기 같이)

## 커밋 안 된 것: 없음 (공유 트리, push_paths 사용)
