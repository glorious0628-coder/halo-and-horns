# 메인 반영 1 — 인계 상태 (2026-10-11)

## 메인 Studio 상태
- 창: 클라우드 place 81671223175574 ("Halo & Horns"). 열기: `Start-Process "roblox-studio:1+launchmode:edit+task:EditPlace+placeId:81671223175574+universeId:8570876289"` (universeId 없으면 홈만 열림). 창 id는 열 때마다 바뀜 → `HH_MAIN_STUDIO=1`, `STUDIO_ID`는 list_roblox_studios로 확인.
- 지금: Edit 모드, Play 정지. 코드는 origin/main(1c4a2e09 시점)과 sync됨. TmpMainApplyTest 임시 스크립트 없음. `ServerStorage.StudioFreshSave=true`(Play마다 새 저장) 유지.
- 마지막 저장: 2026-10-10 20:10:36, `build/GoodEvil.rbxlx` = `place/GoodEvil.rbxlx` (43,488,522 B, sha256 d2c06980…8383), 72a5f19로 push됨. 그 뒤 **월드 변경 없음**, 코드 sync만 미저장(클라우드 저장·Save As 안 함).
- 빛 마을: 3차 배치(Halo_Cathedral (-38,59,-660) 등) 그대로. **4차 적용 중단** — A23-121(빛 마을 처음부터 다시, 새 마을 완성 후 한 번에 교체). 그때까지 메인 빛 마을 건드리지 말 것. 옛 HaloCastle은 ServerStorage.HaloPropsOld.

## 하던 일 (끝남)
- 이미지 개발 요청 비·눈 사진 3장 → `docs/art/verification_2026-10-10/main_apply_morning/rain_preview/` (보고 완료). Night 프리뷰는 밝기 안 바꿈(원래 그런 것), 메인 마을 등불엔 LampLight 태그 없음.

## 큐 (순서대로)
1. 새 빛 마을이 메인에 들어간 뒤: 처마 밑 비 사진 + 밤 등불 사진(서버에서 GameState DayPhase + Lighting.ClockTime 같이 바꿔야 함, 몇 초마다 다시 써짐). 이미지 개발이 부탁.
2. 개발1 스킬 Q 아이콘/SkillFx 반영(55bbdcb3 이후) sync → Lv5 Halo/Horns Q 스킬 사진(슬라임 맞는 순간) + 활 2종 근접 사진 + 무기 쥐기 9조합 시트(좌/우 3/4 + 걷기, 손 거리·Up).
3. dev3의 Config.TownNpcs 3차 배치 커밋이 main에 오면 sync → NPC 위치 확인(Folk1~3, PotionMerchant_Halo, Bright (8,-424), Sir Gleam (110,-400)). 새 마을 계획과 겹치면 새 마을 기준으로.
4. 새 마을 적용 후 미확인: 문 통과, 계단 3, 다리 4, 밤 등불, 분수 물줄기, 간판.
5. 저장은 화면 조작(마우스·키보드)이라 검수 "전달함, 시작" 뒤에만: Save to Roblox + Save to File As `build/GoodEvil.rbxlx`(형식 rbxlx), 시간·해시 확인 → `place/` 복사 → `py tools/push_paths.py`.

## 절차 메모 (자세한 건 `docs/handoff/role_prompts/01_mainapply.md` "메인 Studio 절차 메모")
- Play 테스트: 내 스크립트 `build/mainapply_2026-10-09b/play_*.py`(git 무시). 최신 틀 = `play_rain.py`/`play_morning11.py`. `tools/play_main_checklist.py` 머리를 exec. 새로 시작 → 원격으로 ChooseFaction Halo / ChooseClass Warrior,"M" / AcceptTutorial → 테스트 → Play 정지.
- 임시 스크립트 `TmpMainApplyTest`(StarterPlayerScripts LocalScript / ServerScriptService Script)는 Edit에서 만들고 끝나면 삭제. **`sync_to_studio.py`가 이걸 지우니 sync 뒤에 다시 만들 것**(이번에 이것 때문에 Play가 WaitForChild에서 멈춤).
- 창이 최소화되면 3D 캡처가 흰색 → PowerShell `ShowWindow(handle,4)`(활성화 없음)로 복원, 끝나면 `7`. `open_application`은 새 Studio 홈을 띄우므로 쓰지 말 것.
- Play는 한 번에 하나. 다른 세션 python 테스트가 많으면 Studio가 느려지고 내 Play에 원격을 쏘기도 함.
- Studio 사진 폴더: `docs/art/verification_2026-10-10/main_apply_morning/<이름>/`.

## 막힌 것 / 결정 대기
- 없음. 새 검수(local_78581314) 큐 대기.
