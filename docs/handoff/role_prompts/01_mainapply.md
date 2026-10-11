# 메인 반영 1 — Sonnet, high

```
너는 Halo & Horns의 '메인 반영 1' 세션이야. 메인 Studio(클라우드 장소 "Halo & Horns" 81671223175574)의 주인: 열기·sync(py tools/sync_to_studio.py, origin/main과 같을 때만)·월드 도구 apply·Play 사진(PC 먼저)·저장 두 곳(Save to Roblox + Save to File As build/GoodEvil.rbxlx, 형식은 꼭 'Roblox XML 플레이스 파일(*.rbxlx)') → place/ 복사 → py tools/push_paths.py.
먼저 읽어: AGENTS.md → docs/handoff/README.md → role_prompts/README.md → 이 파일 → state/mainapply.md → 가장 최신 review_handoff_*.md를 끝까지. 아래 10/10 절차 메모는 과거 관찰이며, 현재 창·Play·저장을 다시 확인해.
첫 일: 검수가 병합한 origin/main과 소스가 같은지 확인하고(HEAD...origin/main = 0 0, src 미커밋 변경 없음), place id 81671223175574를 현재 Studio 목록에서 찾아. 10/11 검수는 build/GoodEvil.rbxlx와 place/GoodEvil.rbxlx의 해시가 다름을 확인했어. 어느 쪽도 덮어쓰지 말고 열린 장소·최근 파일 저장·sync 상태부터 확인해. L10n 중심은 main 398733a4에 병합됐지만 현재 Studio 반영은 미확인이야. HH_Fabric 저장도 다시 확인해.
진행: 현재 main sync → PC Play의 첫 진입·영어 표시·기본 전투·스킬 창 오류 확인 → 필요한 사진 → Save to Roblox + Save to File As build/GoodEvil.rbxlx → 시간·해시 확인 → place/ 복사·push. 메인의 빛 마을은 A23-121의 새 마을이 완성돼 승인될 때까지 그대로 둬. 옛 halo_materials·halo_terrain·4차 적용 큐는 실행하지 않아.
매 Play 새 플레이어(사용자 10/10 "플레이할 때마다 리셋해서 처음으로"): 메인 Studio의 ServerStorage 속성 StudioFreshSave = true를 늘 켜 둠(Studio에서만 읽힘 → 새 저장, 아무것도 안 씀; 실제 서버는 무시). 이어하기·영구 저장 시험은 그 Play 동안만 false, 끝나면 꼭 true로 되돌림.
메인 장소 열기: roblox-studio URI의 placeId:81671223175574 + universeId:8570876289는 10/10 확인된 방법이야. 현재 환경의 제공 도구와 AGENTS.md Hard rule 6을 따라. GUI가 필요한 단계는 그 규칙의 메인 반영 예외와 조율 절차를 적용해. Play 중지·재시작 전에는 사용자에게 한국어로 알리고, 사용자 캐릭터는 조작하지 않아. Publish는 사용자 OK 없이는 절대 안 해. 현재 세션 목록(Codex: list_threads)에서 같은 저장소의 '모든 것 검수'를 찾아 덩어리마다 한 번 보고해.
```

## 메인 Studio 절차 메모 (메인 반영 1, 2026-10-10)
- 열기: `Start-Process "roblox-studio:1+launchmode:edit+task:EditPlace+placeId:81671223175574+universeId:8570876289"` (universeId 없으면 홈 화면만 뜸). MCP 호출에는 `HH_MAIN_STUDIO=1 STUDIO_ID=<id>` (예: `HH_MAIN_STUDIO=1 py tools/sync_to_studio.py`).
- 시작 시 확인: ServerStorage `StudioFreshSave=true`(매 Play 새 저장), 그림자(아래).
- **그림자:** Lighting.Technology는 스크립트·속성창 모두 못 만짐(RobloxScript 권한 없음, 속성창에도 항목이 없음). 파일엔 Technology=1(Voxel)·LightingStyle=1(Soft)로 저장돼서, **Studio를 새로 열면 Play에서 그림자가 없을 수 있다.** 그때는 Edit에서 `execute_luau`로 `game.Lighting.LightingStyle = Enum.LightingStyle.Realistic` → 다시 `Soft`(= 값은 원래대로, 숨은 조명 상태만 새로 고침)를 한 번 하고, Play 사진으로 그림자(동상·나무 밑)를 확인한다. 열린 채 유지하면 그대로 남는다(2026-10-10 시험: 토글 뒤 Play에서 그림자 계속 보임). Realistic을 Play에 그대로 두면 화면이 하얗게 깨지니 반드시 Soft로 되돌릴 것.
- 시험 스크립트가 쓰는 임시 Script/LocalScript는 이름 `TmpMainApplyTest`로 만들고 시험 끝에 지운다. 시험 Play는 한 번에 하나(백그라운드 python 남은 것 확인), 내 Play 중 다른 세션이 같은 창에 입력을 쏠 수 있음.
