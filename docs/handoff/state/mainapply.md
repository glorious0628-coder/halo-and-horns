# 메인 반영 1 — 인계 상태 (2026-10-11)

## 메인 Studio 상태 (2026-10-11 오후, 2번째 메인 반영 1 → 3번째에게 인계)
- 창: place 81671223175574, 창 id 264bc370-636a-48f3-9288-b2e1abec63bc(열 때마다 바뀜 → list_roblox_studios). Edit 모드, Play 정지. `HH_MAIN_STUDIO=1 STUDIO_ID=<id>`.
- 코드: origin/main **2406d35d** 시점까지 sync됨(스킬 창 SkillBook·걷는 바닥 Ground·대검/지팡이 쥐기·빛 마을 조명 C2c 포함). 공유 트리가 뒤처지면 `git fetch && git reset --keep origin/main` 뒤 `py tools/sync_to_studio.py`.
- 마지막 저장: 2026-10-10 20:10:36(place/ 72a5f19). 그 뒤 월드 변경 없음, 코드 sync만 미저장 → 저장(Save to Roblox + Save As build/GoodEvil.rbxlx)은 새 검수 "전달함, 시작" 뒤에.
- 빛 마을 4차 적용 중단(A23-121). 새 마을이 다 될 때까지 메인 빛 마을 건드리지 말 것.
- 보고처: **새 '모든 것 검수' = local_94cfa4bc-942c-4ac1-97a4-e9f609739523**.

## 오늘 한 일 (사진: docs/art/verification_2026-10-11/main_apply/)
skillbook/·skillbook_lv5/·skillbook_v2/·skillbook_v3/(스킬 창), ground_bridge/(다리 위 스킬 원), twohand_horns/·twohand_horns2/·twohand_v2/·twohand_v2b/(grips9/ 포함)·twohand_v3/(쥐기), twohand_mage/(Lv25 마법사 창), halo_light_c2c/(낮·밤), halo_entrance/·halo_entrance2/(입구 전체).
- 시험 스크립트(git 무시): build/mainapply_2026-10-09b/ play_skillbook.py, play_bridge.py, play_twohand.py, play_grips_v2.py(9조합+GripProbe), play_v3.py(마법사+조명+입구; SKIPGRIP=1). **임시 Tmp 스크립트 없이 execute_luau 직접**(캐릭터 시험: Level·SkillSlots·WeaponTier 속성을 서버에서 올림, 조합 변경은 Faction/Class 속성, 조명은 `ServerScriptService.DebugCommand:Invoke("", "Clock", 시)`, 이동은 VISIT(x,z,yaw)).
- 알려진 것: 연금술사는 속성 전환으로 probe 키가 Warrior_Neutral로 나옴(진짜 직업 선택 경로 필요).

## 큐
1. 새 검수가 병합한 뒤 sync 부탁 → sync·Play 오류 0·사진.
2. 새 빛 마을이 메인에 들어간 뒤: 처마 밑 비 + 밤 등불 사진, 문·계단·다리·분수·간판 확인.
3. 저장(검수 OK 뒤): Save to Roblox + Save to File As `build/GoodEvil.rbxlx`(rbxlx), 시간·해시 → `place/` 복사 → `py tools/push_paths.py`.

## 절차 메모 (자세한 건 `docs/handoff/role_prompts/01_mainapply.md` "메인 Studio 절차 메모")
- Play 테스트: 내 스크립트 `build/mainapply_2026-10-09b/play_*.py`(git 무시). 최신 틀 = `play_rain.py`/`play_morning11.py`. `tools/play_main_checklist.py` 머리를 exec. 새로 시작 → 원격으로 ChooseFaction Halo / ChooseClass Warrior,"M" / AcceptTutorial → 테스트 → Play 정지.
- 임시 스크립트 `TmpMainApplyTest`(StarterPlayerScripts LocalScript / ServerScriptService Script)는 Edit에서 만들고 끝나면 삭제. **`sync_to_studio.py`가 이걸 지우니 sync 뒤에 다시 만들 것**(이번에 이것 때문에 Play가 WaitForChild에서 멈춤).
- 창이 최소화되면 3D 캡처가 흰색 → PowerShell `ShowWindow(handle,4)`(활성화 없음)로 복원, 끝나면 `7`. `open_application`은 새 Studio 홈을 띄우므로 쓰지 말 것.
- Play는 한 번에 하나. 다른 세션 python 테스트가 많으면 Studio가 느려지고 내 Play에 원격을 쏘기도 함.
- Studio 사진 폴더: `docs/art/verification_2026-10-10/main_apply_morning/<이름>/`.

## 막힌 것 / 결정 대기
- 없음. 새 검수(local_78581314) 큐 대기.
