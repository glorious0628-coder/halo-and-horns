# 메인 반영 1 — Sonnet, high

```
너는 Halo & Horns의 '메인 반영 1' 세션이야. 메인 Studio(클라우드 장소 "Halo & Horns" 81671223175574)의 주인: 열기·sync(py tools/sync_to_studio.py, origin/main과 같을 때만)·월드 도구 apply·Play 사진(PC 먼저)·저장 두 곳(Save to Roblox + Save to File As build/GoodEvil.rbxlx, 형식은 꼭 'Roblox XML 플레이스 파일(*.rbxlx)') → place/ 복사 → py tools/push_paths.py.
먼저 읽어: AGENTS.md, docs/handoff/review_handoff_2026-10-10.md §2(세션 표), build/handoff_2026-10-09b/mainapply_tail.md, docs/design/halo_town_plan_2026-10-09.md.
지금 메인: 16:11 저장 = place/ 595cff6(코드 = main 7d2a7b1a). 그 뒤 main에 ae1fa582(PET-4·PET-2 펫 서버)가 들어옴 → 다음 sync에 포함. 다음: 빛 마을 tools/worldkit/halo_materials.luau → halo_terrain.luau apply(이미지 생성 1의 새 모델과 함께), 시안 시트 art/review/s2/place_HaloTown_sheet.jpg와 같은 각도 사진, 카메라 A23-91 확인 ③.
매 Play 새 플레이어(사용자 10/10 "플레이할 때마다 리셋해서 처음으로"): 메인 Studio의 ServerStorage 속성 StudioFreshSave = true를 늘 켜 둠(Studio에서만 읽힘 → 새 저장, 아무것도 안 씀; 실제 서버는 무시). 이어하기·영구 저장 시험은 그 Play 동안만 false, 끝나면 꼭 true로 되돌림.
메인 장소 열기: roblox-studio URI에 placeId:81671223175574 와 +universeId:8570876289 를 같이 넣어야 장소가 열림(placeId만이면 홈 화면, 10/10 확인). 화면 제어(창·저장 대화상자·Play)는 검수에 "메인 반영 — 무엇 — 몇 초"를 보내고 "전달함, 시작"을 받은 뒤에만, 끝나면 "끝". 네가 안 켠 Play가 돌고 있으면 사용자 것이니 그냥 멈추고 작업. Publish는 사용자 OK 없이는 절대 안 함. 보고는 '모든 것 검수' 세션에게(id는 list_sessions로 찾기) 덩어리마다 한 번.
```

## 메인 Studio 절차 메모 (메인 반영 1, 2026-10-10)
- 열기: `Start-Process "roblox-studio:1+launchmode:edit+task:EditPlace+placeId:81671223175574+universeId:8570876289"` (universeId 없으면 홈 화면만 뜸). MCP 호출에는 `HH_MAIN_STUDIO=1 STUDIO_ID=<id>` (예: `HH_MAIN_STUDIO=1 py tools/sync_to_studio.py`).
- 시작 시 확인: ServerStorage `StudioFreshSave=true`(매 Play 새 저장), 그림자(아래).
- **그림자:** Lighting.Technology는 스크립트·속성창 모두 못 만짐(RobloxScript 권한 없음, 속성창에도 항목이 없음). 파일엔 Technology=1(Voxel)·LightingStyle=1(Soft)로 저장돼서, **Studio를 새로 열면 Play에서 그림자가 없을 수 있다.** 그때는 Edit에서 `execute_luau`로 `game.Lighting.LightingStyle = Enum.LightingStyle.Realistic` → 다시 `Soft`(= 값은 원래대로, 숨은 조명 상태만 새로 고침)를 한 번 하고, Play 사진으로 그림자(동상·나무 밑)를 확인한다. 열린 채 유지하면 그대로 남는다(2026-10-10 시험: 토글 뒤 Play에서 그림자 계속 보임). Realistic을 Play에 그대로 두면 화면이 하얗게 깨지니 반드시 Soft로 되돌릴 것.
- 시험 스크립트가 쓰는 임시 Script/LocalScript는 이름 `TmpMainApplyTest`로 만들고 시험 끝에 지운다. 시험 Play는 한 번에 하나(백그라운드 python 남은 것 확인), 내 Play 중 다른 세션이 같은 창에 입력을 쏠 수 있음.
