# 메인 반영 1 — 인계 상태 (2026-10-11)

## 메인 Studio 상태 (2026-10-12 낮 11:00, 3번째 메인 반영 1 → 다음에게; 스스로 clear 함)
- 창: Edit, Play 정지, StudioFreshSave=true. 창 id는 열 때마다 바뀜 → `HH_MAIN_STUDIO=1 py tools/studio_mcp.py call list_roblox_studios '{}'` 후 `STUDIO_ID=<id>`(지금 b2281643-ef9b-4501-8753-69c024b67d0f). 이름이 "헤일로 & 혼스 (81671223175574)" 또는 "Darugi_S2의 장소: 10122026_1 (79345022650204)"로 번갈아 보일 수 있음 — 사용자 답 "무시해도 돼"(설문 다시 하려고 만든 것). **Ctrl+S·Save to Roblox·Publish 절대 금지**(클라우드가 새 place로 감), 저장은 Save to File As build/GoodEvil.rbxlx만. studio_mcp MAIN_NAMES·AGENTS 규칙 3은 최종 검수가 고침(건드리지 말 것).
- 코드: Studio는 main **5b1a2f96**(A23-142 지팡이 0.7배) sync본(그 뒤 shared HEAD는 0ee15714 이상, src 새 변화 있으면 `py tools/push_paths.py --sync`(공유 트리가 다른 세션 수정 중이면 reset --keep이 막히므로 이걸 씀) 뒤 `py tools/sync_to_studio.py`).
- 천 HH_Fabric v3b ID(Color 130243612742018·Normal 78044174442027·Roughness 111200474370652)는 파일에 저장됨. Studio를 닫았다 클라우드에서 다시 열면 v1이 되니 execute_luau(Edit)로 이 3개를 다시 넣을 것(v2 되돌릴 값 76316272601072 / 102973991596175 / 119858177335377).
- **마지막 저장**: build/GoodEvil.rbxlx 2026-10-12 10:41:15, 44,082,577B, SHA256 bacdbf24…58e6 = place/GoodEvil.rbxlx (push **6e8b2600**), 소스 ecde46c6 판. 그 뒤 병합(5b1a2f96 지팡이 짧게 등)은 아직 저장 안 됨 → 최종 검수 "전달함, 시작" 받으면 저장(이번 묶음엔 '저장 안 해도 됨'이라 했음).
- 보고처: **최종 검수**(list_sessions 제목 "최종 검수"), 마법사·그림 사진은 **디자인 검수**에도, 게임성 관련은 **게임성 검수**에도 사본.
- 시험 스크립트(build/mainapply_2026-10-09b/, git 무시, 헤더는 tools/play_main_checklist.py exec): play_staff_short.py/play_staff_hip.py(세 마법사 앞·옆·손·계단·걷기·T1/T7), play_e27.py(PvP 카드·Hero 칸·계단 지팡이), play_text1012.py(서버 글: 강화·보스·물약·거위), play_puddle.py, play_bag_main.py, play_r1012a.py(모루 G·재료 팔기), play_chip.py, play_spawn.py, play_merge11*.py. 시험 Play는 늘 끝에 멈추고 StudioFreshSave=true 유지.
- 저장 요령(마우스·키보드, 최종 검수 "전달함, 시작" 뒤에만): ① PowerShell SetForegroundWindow로 메인 창을 앞으로(창 제목 "헤일로*"). ② 컴퓨터 제어 권한은 `robloxstudiobeta.exe` 이름으로(앱 이름 "Roblox Studio"는 창이 마스크됨; 이미 승인돼 있으면 재사용). ③ File 메뉴(22,42) → 마우스를 (108,333)에 올려 툴팁 "새 이름으로 활성 로컬 파일 저장" 확인 → 클릭. ④ 저장 창이 열리면 **스크린샷으로 위치 확인**(창 위치가 ±8px 바뀐 적 있음): 형식 드롭다운 → "Roblox XML 플레이스 파일 (*.rbxlx)" 고르기, 이름 칸 삼중클릭·Ctrl+A·"GoodEvil" 입력 → 자동완성 목록의 "GoodEvil.rbxlx" 클릭 → Enter → 덮어쓰기 "예". ⑤ 끝나면 시간·SHA·`</roblox>` 끝·PackageLink 99 확인 → place/ 복사 → py tools/push_paths.py -m "…" place/GoodEvil.rbxlx → "끝".
- 알게 된 것: 이 Bash 도구는 가끔 PATH가 깨짐 → `export PATH="/usr/bin:/bin:/c/Users/glori/AppData/Local/Programs/Python/Launcher:/c/Users/glori/AppData/Local/Programs/Python/Python313:/c/Program\ Files/Git/cmd:$PATH"`. 모루 G 프롬프트는 Map.Landmarks.ArtisanGuild.Anvil(NPC Otto 아님), 진짜 키(user_keyboard_input keyDown/keyUp)만. Q는 퀘스트 장부, Z가 첫 스킬. 첫 미션 뒤 Hallie "Lost Lunchbox!" 모달이 카드를 막음 → 시험 땐 DebugCommand StoryDone "Lunch1". HUD Hero 칸은 자물쇠(창 없음). 옮기기(Transfer)·무법자 주 시작 줄은 아직 못 봄(다음 기회).

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
