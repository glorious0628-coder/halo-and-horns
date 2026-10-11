# 메인 반영 1 — 인계 상태 (2026-10-11)

## 메인 Studio 상태 (2026-10-12 새벽 01:50, 3번째 메인 반영 1 → 다음에게)
- 창: place 81671223175574, Edit, Play 정지, StudioFreshSave=true. PC가 꺼지면 닫힘 → 다시 열기: `Start-Process "roblox-studio:1+launchmode:edit+task:EditPlace+placeId:81671223175574+universeId:8570876289"` 뒤 `HH_MAIN_STUDIO=1 py tools/studio_mcp.py call list_roblox_studios '{}'`로 창 id를 찾아 `STUDIO_ID=<id>`.
- 다시 열면 클라우드판(옛 저장)이라 **코드 sync 필요**(`git fetch && git reset --keep origin/main` → `py tools/sync_to_studio.py`) + **HH_Fabric v2 ID 2개 다시**: MaterialService.HH_Fabric ColorMap rbxassetid://76316272601072, RoughnessMap rbxassetid://119858177335377 (execute_luau Edit). 둘 다 안 하면 옛 코드·v1 천.
- 지금 Studio 코드 = main **37a5dc62** sync본(그 뒤 src 변경 없음 확인, origin/main 68fa4344). 최종 검수가 "마무리: 앞 sync·저장 취소, 아침 1번으로 미룸"이라 했지만 37a5dc62 sync·저장은 이미 끝났음.
- **마지막 저장**: build/GoodEvil.rbxlx 2026-10-12 01:38:53, 43,971,218B, SHA256 d1b561a5…16cc = place/GoodEvil.rbxlx (push **21193b6**). 소스 37a5dc62 판, HH_Fabric v2·PackageLink 99 포함, 빛 마을은 그대로(A23-121). 이전 저장 b82e7de는 옛것.
- 보고처: **최종 검수** (list_sessions 제목 "최종 검수"). 게임성 검수에도 사본.
- 시험 스크립트(build/mainapply_2026-10-09b/, git 무시): play_merge11.py·play_merge11b.py(첫 미션·거위·쉼 카드·PvP), play_bag_main.py(가방), play_grips_main.py·play_tip_main.py·play_r1012b.py(한손검·지팡이 끝·R15·계단), play_r1012a.py(Hero·강화·모루 G·재료 팔기), play_chip.py(받기 칩, CLOSED=1), play_spawn.py·play_puddle.py(몹 생김·웅덩이·가방 재료 아이콘). 사진 docs/art/verification_2026-10-12/main_apply/*. 시험 Play는 늘 StudioFreshSave=true 유지.
- 저장 요령(마우스·키보드 필요, 검수 "전달함, 시작" 뒤): 컴퓨터 제어 권한은 **`robloxstudiobeta.exe`** 이름으로 신청(앱 이름 "Roblox Studio"로는 창이 마스크됨). 먼저 PowerShell SetForegroundWindow로 메인 창 앞으로 → File 메뉴 클릭(22,42) → 마우스를 (108,333)에 올려 툴팁 "새 이름으로 활성 로컬 파일 저장" 확인 → 클릭 → 형식 드롭다운(413,403)→(255,440) rbxlx → 이름 칸(400,378) 삼중 클릭·Ctrl+A·"GoodEvil" 입력 → 자동완성 목록의 GoodEvil.rbxlx(181,419) 클릭 → Enter → 덮어쓰기 "예"(732,422). 끝나면 시간·해시·`</roblox>` 끝 확인 → place/ 복사 → push_paths.
- 알게 된 것: 모루 G 프롬프트는 NPC Otto가 아니라 Map.Landmarks.ArtisanGuild.Anvil(MaxActivationDistance 12)에 있고 진짜 키(user_keyboard_input keyDown/keyUp G)로만 열림(Dispatch는 안 됨). HUD Hero 칸은 "Coming soon!"(창 없음). 첫 미션 뒤 자연으로 뜨는 Hallie "Lost Lunchbox!" 모달이 쉼 카드·PvP 카드를 막음 → 시험 땐 DebugCommand StoryDone "Lunch1".
- 열린 문제(게임성 검수에 넘김): 계단에서 지팡이 끝 −0.12·경사 +0.51, 강화/받기 칩 잘림(고침 확인됨), 둘째 웅덩이 테두리 주변은 슬라임이 없어 못 봄, 첫 KO 킹 비교는 probe에 없음.

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
