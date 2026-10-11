# 메인 반영 1 — 인계 상태 (2026-10-11)

## 메인 Studio 상태 (2026-10-11 밤 23:30, 3번째 메인 반영 1)
- PC가 꺼졌다 켜져 Studio를 다시 열었음(Start-Process roblox-studio:1+launchmode:edit+task:EditPlace+placeId:81671223175574+universeId:8570876289). 창 id는 열 때마다 바뀜 → `HH_MAIN_STUDIO=1 py tools/studio_mcp.py call list_roblox_studios '{}'` 후 `STUDIO_ID=<id>`. 지금 Edit, Play 정지, ServerStorage StudioFreshSave=true.
- 코드: main **d0bcc6d2**(병합 3176b8fb 포함)까지 sync됨. 그 뒤 origin이 더 나아감(한손검 후속·가방·채집·제작 꺼짐 병합 예정) → `git fetch && git reset --keep origin/main` 뒤 `py tools/sync_to_studio.py`.
- HH_Fabric v2 ID(Color 76316272601072, Roughness 119858177335377)는 Studio에 들어가 있음. Studio를 닫았다 다시 열면 클라우드판은 v1이라 이 ID 2개를 execute_luau로 다시 넣을 것.
- 마지막 저장: **build/GoodEvil.rbxlx 2026-10-11 23:25:09, 43,786,932B, SHA256 dffacff7…56ec = place/GoodEvil.rbxlx(push b82e7de)**. 소스는 d0bcc6d2 판. 비교용 옛 파일 build/GoodEvil_2026-10-11_night.rbxlx(21:21, 75e5b6e6…).
- 보고처: **최종 검수** (list_sessions에서 제목 "최종 검수"). 사진 결과의 디자인/게임성 검수로 가는 건 최종 검수가 정함.
- 저장(Save to File As)은 마우스·키보드가 필요함: 검수 "전달함, 시작" 뒤 권한 요청은 **`robloxstudiobeta.exe`**(앱 이름 "Roblox Studio"로는 창이 마스크됨)로 하고, File 메뉴 → 마우스를 "다른 이름으로 파일에 저장"(약 108,333)에 올려 툴팁 확인 → 클릭 → 형식 드롭다운에서 rbxlx 선택 → 이름 칸에 GoodEvil 입력 후 자동완성 목록의 GoodEvil.rbxlx 클릭 → Enter → 덮어쓰기 "예". 끝나면 PowerShell ShowWindow로 창은 그대로 두거나 원래대로.

## 오늘 한 일 (사진: docs/art/verification_2026-10-11/main_apply/)
skillbook/·skillbook_lv5/·skillbook_v2/·skillbook_v3/(스킬 창), ground_bridge/(다리 위 스킬 원), twohand_horns/·twohand_horns2/·twohand_v2/·twohand_v2b/(grips9/ 포함)·twohand_v3/(쥐기), twohand_mage/(Lv25 마법사 창), halo_light_c2c/(낮·밤), halo_entrance/·halo_entrance2/(입구 전체).
- 시험 스크립트(git 무시): build/mainapply_2026-10-09b/ play_skillbook.py, play_bridge.py, play_twohand.py, play_grips_v2.py(9조합+GripProbe), play_v3.py(마법사+조명+입구; SKIPGRIP=1). **임시 Tmp 스크립트 없이 execute_luau 직접**(캐릭터 시험: Level·SkillSlots·WeaponTier 속성을 서버에서 올림, 조합 변경은 Faction/Class 속성, 조명은 `ServerScriptService.DebugCommand:Invoke("", "Clock", 시)`, 이동은 VISIT(x,z,yaw)).
- 알려진 것: 직업 id는 Warrior/Mage/Archer뿐(연금술사 = Mage+Neutral, 대장장이 = Warrior+Neutral, 조련사 = Archer+Neutral). "Alchemist"를 Class로 넣으면 Warrior로 떨어짐(개발 1 설명). 연금술사 사진은 twohand_v2/grips9/Neutral_Mage_front.png(probe Mage_Neutral: Right dGrip=0.00).

## 큐 (10/11 밤)
0. 곧 검수가 병합 4개(한손검 후속·가방·채집·제작 꺼짐) 보냄 → sync·PC Play 사진·콘솔·저장. 시험 스크립트: build/mainapply_2026-10-09b/play_merge11.py(첫 미션·사냥), play_merge11b.py(거위·쉼 카드·PvP 카드, PVP_ONLY=1 가능). 사진 docs/art/verification_2026-10-11/main_apply/merge_a23130*/.
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
