# 게임성 개발 1 — 인계 상태

## 10/18 정리 (최신; 사용자 "게임 두 개 만드는 게 어려울 것 같애. 우선 이거 정리하자." → 멈춤, 새 일 X)
- **Studio:** PhoneTest 창 닫음, 열린 시험 Studio 없음(패슬 패닉 창은 안 건드림).
- **화면 판 ④ 어디까지(1회, dev1-screen-1018 sync):** E 도감 [Go] ✅ · S 칼 손에(빛·뿔) ✅ · W 전사 물속 숨김·F 무시 ✅ · A 대화 상자 반만(상자 뜸·Bye 닫힘, Welcome 수락·스승은 못 봄) · WA 궁수 물속 ✗(PC 꺼져 끊김) · P 쿨다운 누름 ✗. 값·사진: docs/art/verification_2026-10-20/screen_1020/(log_run1_A_E_S_W.txt, 사진 12장; main ae62262). 관찰: 활이 등에 있을 때 시위 Beam이 켜져 보임(원인 못 봄).
- **가지·해시:** 병합됨(main 62b7b48e) = dev1-water-hand c02d2925 · dev1-neighbor d0f5a1f6. 병합 전 = dev1-dialog-box 59b8a80d · dev1-codex-next 459a37ea · dev1-detail-1 b8259b1b. 시험용(병합 X) = dev1-screen-1018 cabbc147(합친 판 + tools/dev1_screen 도구 사본).
- **남은 순서(다시 시작할 때):** ④ 남은 것(A 다시 = check1020 part_a G 다시 누르기 넣음, WA, P; `STUDIO_ID=… py build/dev1_tools/check1020.py A WA P`) → dialog-box·codex-next·detail-1 병합(최종 검수) → 활 시위 등에서 보이는 것 → ⑤ 대화 상자 ② 3D 얼굴 → ⑥ detail audit 순서 → ⑦ 제작 옵션 화면 + BagUI TonicBase(개발 2 부탁) + 공방 주간 선물 칸.

## 10/18 새 PC로 옮김 (최신; 최종 검수 "화면 판 ④는 오늘 안 함 — 다른 컴퓨터·다른 계정으로 옮겨서 이어 함")
- **가지 전부 push됨 (병합 전):**
  - dev1-water-hand **c02d2925** — A23-231 물속 무기 숨김(WeaponPose.Swimming/WaterHide, F·화면 클릭 무시) + A23-232 칼·몽둥이 손에(WeaponStow.Kinds = 활만). hold_pose2 65/0·변이 24/24, camera_input 43/43, tool_grip 369/0, HUD/WeaponPose 시험 66개 새 실패 0.
  - dev1-neighbor **d0f5a1f6** — StoryNpcs Who.Bag·등불 손 흔들기 = "Neighbor". **dev2-detail과 같이 병합.**
  - dev1-detail-1 **b8259b1b** — 세세한 #1·#8·#9·#6·#13·#14 + r11 ② 폰 둥근 물약 버튼 거절 흔들림. 물약 소리 = Deny '응-응' 그대로(최종 검수 10/18).
  - dev1-dialog-box **59b8a80d** (대화 상자 ①) · dev1-codex-next **459a37ea** (도감 [Go]) — 그대로, 화면 확인 뒤 병합.
  - **dev1-screen-1018 cabbc147** = 화면 판용 합친 판(main 589e4e34 + dialog-box + codex-next + detail-1 b8259b1b + water-hand c02d2925) + `tools/dev1_screen/`(옛 PC build/dev1_tools 25개 사본, README). **main에 병합 X** — 시험 Studio sync·도구 옮기기용.
- **화면 판 ④ 할 내용 (새 PC, 최종 검수 '전달함, 시작' 뒤, 약 15분 닫기 포함):** PhoneTest_1015 열기 → dev1-screen-1018 worktree에서 `STUDIO_ID=… py tools/sync_to_studio.py` → `STUDIO_ID=… py tools/dev1_screen/check1020.py` (h1016.py의 GAME 경로를 새 PC에 맞춤; 사진·로그 docs/art/verification_2026-10-20/screen_1020/) → Play 멈춤 → **창 닫기** → "끝". 볼 값: A 대화 상자(얼굴·이름·줄·[Next]→[I'm In!]·스승 Ok·[Bye] 닫힘, TutorialStep 바뀜) / E 도감 [Go] 표시 안내 / S 빛·뿔 전사 7초 서 있기 → StowWeld 없음·RightGrip 켬 / W 물 블록(Play 동안만 Terrain FillBlock) → Swimming·무기 부품 전부 숨김·F 서버 Swing 수 0(땅에선 +1)·나오면 다시, 궁수 물속 6초 → 나와서 등·시위 숨김 / P 퀵슬롯 1 물약 마심 → 쿨다운 중 키 1 = RefuseBase·빨간 테두리·개수 그대로.
- **이 PC에만 있던 것:** build/dev1_tools/*(→ dev1-screen-1018 tools/dev1_screen에 사본), 옛 worktree ../Game-dev1water(dev1-water-hand)·../Game-dev1nb(dev1-neighbor)·../Game-dev1detail(dev1-detail-1)·../Game-dev1grip(dev1-dialog-box)·../wt_dev1base1020(dev1-screen-1018) — 전부 push돼 있어 지워도 됨. 각 worktree build/luau_cli_0_741는 ../Game/build에서 복사한 것(git 밖), build/sw 스윕 로그도 git 밖.
- **열린 시험 Studio 없음**(10/18 화면 판 1회 뒤 PhoneTest 창 닫음; 사용자 "정리하라고 했잖니" → 멈춤).
- **화면 판 ④ 1회 결과(10/18, dev1-screen-1018 sync, 로그 docs/art/verification_2026-10-20/screen_1020/log_run1_A_E_S_W.txt + 사진 12장):** E 도감 [Go] ✅(누르면 창 닫힘·표시 켜짐 17m → 숲에서 따라감) · S 칼 손에 ✅(빛 Sword·뿔 DarkSword 7초 서 있어도 StowWeld 없음·RightGrip 켬·손~손잡이 0.00) · W 전사 물속 ✅(Swimming·부품 4/4 숨김·F 2번 서버 Swing 0, 땅에선 +1·나오면 숨김 0) · A 대화 상자 반쯤 ✅(상자 뜸: 얼굴 Frame+Image·이름 Hallie·줄·Next·Bye·I'm In 보임, Bye 누르면 닫힘) — 첫 G 두 번이 안 먹어 Welcome 수락·스승 단계는 못 봄(check1020 part_a에 G 다시 누르기 넣음). **남은 것:** A 다시, WA 궁수 물속(PC 꺼져 끊김), P 쿨다운 누름. 🔎 관찰: 궁수 활이 등에 있는데(stow=true) 시위 Beam 2개가 켜져 있음(string=11) — stow-fix와 다름, 다음에 원인 볼 것.
- **▶ 남은 순서:** ④ 화면 판 → ⑤ 대화 상자 ② 3D 얼굴(ViewportFrame, dialog-box 위 가지; DialogBox.luau drawFace에 몸 있으면 StoryNpcs.Body 복사 → 없으면 초상 → 첫 글자) → ⑥ detail audit 순서(#21 → #24·#26 → #15 → #3·#2 → #16 → #17 → #25 → #29·#30 → #31·#32 → #27·#28, + #5·#19) → ⑦ 제작 옵션 화면(dev2-craft-optsb 위: Config.SpareParse/GearParse로 BagUI:205·MarketWindow:243·300·CraftWindow:405 'T:P:O', 옵션 표시, 특제 물약) + **개발 2 10/18 부탁(작은 것): BagUI.TonicState에 Config.TonicBase(cell.Id) 넘기기(BagUI 548·1526·1568 근처, 1571 pending Ends = ends[base]; dev2-craft-optsb 2e87bf70에 TonicBase)** + 공방 '주간 선물' 칸(dev2-craft-week CraftInfo.Week, 계약 docs/design/craft_week_server_2026-10-17.md). buff_bar 실패는 개발 2가 서버에서 정리함(화면 고칠 것 없음).
- 서버 몫 알림: 자동 전투(CombatService autoReady)는 물속도 휘두름 = 개발 2.

## 10/20 — 다른 계정 새 세션 (최신)
- **가지 dev1-water-hand c02d2925** (push, worktree ../Game-dev1water): ① A23-231 물속 무기 숨김 — WeaponPose.Swimming(Humanoid 상태 Swimming) + WaterHide(무기 부품·데칼 LocalTransparencyModifier 1, 빛·반짝이·활 시위 끔 = 켜져 있던 것만, 나오면 그대로 되돌림; 모든 캐릭터, 이 클라마다), 헤엄 중 PoseStep 자세 안 씀(팔 = 헤엄 몸짓), 물속에서 등에 넣은 활은 나와도 시위 숨김 유지, 숨겨진 무기는 넣기 소리·반짝 없음. HUD L.Swimming: F·공격 버튼(startHold)·화면 클릭(PrimaryClick) 물속이면 안 휘두름(글 X). ② A23-232 Config.WeaponStow.Kinds = 활만(Bow·ShortBow), 허리 코드·Hip 줄은 남김. 시험 hold_pose2 65/0·변이 24/24(물속·칼 손에 13개 새로), camera_input 43/43(화면 클릭 줄 맞춤), tool_grip 369/0. HUD/WeaponPose 읽는 시험 66개 스윕: 새 실패 0(auto_face·walk_forge_client·crown_points MISSED 2·attendance_ui는 main에도 같은 실패, map_v2는 sparse에 docs 없음). detail-1과 합친 판에서 camera_input·hold_pose2·auto_face·detail_batch1 통과. 병합 충돌 없음(main·detail-1·dialog-box·codex-next·dev2-detail·craft-optsb).
- **가지 dev1-neighbor d0f5a1f6** (push, ../Game-dev1nb): StoryNpcs Who.Bag·등불 Common 손 흔들기 = "Neighbor" — **dev2-detail과 같이 병합**(이웃 몸은 개발 2 가지). StoryNpcs 시험 7개 통과.
- **dev1-detail-1 b8259b1b** (c37d9fb7 위에 덧붙임): r11 ② 물약 쿨다운 중 누름 — 퀵슬롯 길(키 1·슬롯 터치)은 #8에 이미 있음(UIKit.Refuse = 흔들림 + 빨간 테두리 + Deny '응-응'), 폰 둥근 물약 버튼(VitalsUI BtnPotion)도 거절이면 흔들림. detail_batch1 9/9·8/8, quick_slots·keys_settings 350·phone_first10 등 통과(english 1·MISSED 3은 main도 같음).
- 남은 것: 자동 전투(서버 CombatService autoReady)는 물속도 휘두름 = 개발 2 몫(최종 검수에 알림). 스킬 Q/Z/X 물속 막기는 SPEC에 없어 안 함.
- **④ 화면 판 준비 끝:** 합친 판 = ../wt_dev1base1020 로컬 커밋 31047ade(main 589e4e34 + dialog-box + codex-next + detail-1 b8259b1b + water-hand c02d2925; push 안 함). 도구 `build/dev1_tools/check1020.py` (A 대화 상자 Welcome·스승·Bye / E 도감 Go / S 칼 손에 빛·뿔 / W 물 블록 만들어 헤엄 숨김·F 서버 Swing 수·궁수 시위 / P 쿨다운 누름 흔들림 값), 사진·로그 docs/art/verification_2026-10-20/screen_1020/. 순서: 최종 검수 '전달함, 시작' → PhoneTest_1015 열기 → `cd ../wt_dev1base1020 && STUDIO_ID=… py tools/sync_to_studio.py` → `STUDIO_ID=… py build/dev1_tools/check1020.py` → Play 멈춤 → 창 닫기 → "끝".
- **▶ 다음:** ④ 화면 판 → ⑤ 대화 상자 ② 3D 얼굴 → ⑥ detail audit 순서 → ⑦ 제작 옵션 화면 + buff_bar(개발 2와).

## 10/17 밤 멈춤 (최신; 사용자 "잠깐 정리하자, 화요일 오전부터 작업하자")
- 병합됨: dev1-r9-small(KO 그림 자리·King 물약 반짝·tool_grip 해시), dev1-staff-tilt, dev1-your-king, dev1-nan-guard(d54ee16c).
- **가지(push, 병합 전):** dev1-dialog-box 59b8a80d (대화 상자 ①, 화요일 화면 눌러 보기 뒤 병합; loot 716/0·audio 364/0 통과, loot MISSED 4개는 main에도 같은 옛 패턴) · dev1-codex-next 459a37ea (도감 [Go], 화면 확인 대기) · dev1-detail-1 c37d9fb7 (세세한 묶음 1: #1·#8·#9·#6·#13·#14, worktree ../Game-dev1detail; audio 시험 #13 고침 뒤 다시 돌려 확인 필요).
- 화면 판 안 함(Studio 안 엶). 도구 build/dev1_tools/check1019.py(도감 [Go]·KO·King 반짝) 준비됨.
- **▶ 화요일 남은 큐:** ① 물속 무기 숨김 A23-231(헤엄 = 숨김, 나오면 다시, 물속 F 무시) ② 칼·몽둥이 손에 A23-232(Config.WeaponStow.Kinds에서 Sword·DarkSword 빼기, 허리 코드는 둠, hold_pose2·tool_grip 맞춤) ③ Neighbor 두 줄(StoryNpcs Who.Bag "Folk1"→"Neighbor", Hop("Folk1",1)→Hop("Neighbor",1); 개발 2 dev2-detail과 같이) ④ 화면 판: 도감 [Go]·KO 그림·King 40% 반짝·물속 무기 ⑤ 대화 상자 ② 3D 얼굴 ⑥ detail audit 순서: #21 → #24·#26 → #15 → #3·#2 → #16 → #17 → #25 → #29·#30 → #31·#32 → #27·#28, + #5(슬라임 AttackSeq 몸짓 그리는지)·#19(스승 Find 말풍선 안 보이는 원인) ⑦ buff_bar 시험은 개발 2와.

## 10/18 — 8판 묶음 끝 (최신)
- **병합됨(main):** fix/quick-first-put(첫 넣기 다시 보내기 + 가방 Quick 같은 칸 다시 눌러도 안 빠짐) · dev1-craft-tool(제작 창 Tool 탭·강화·결과·축복 줄, A23-219) · dev1-r8-small 1b39f497(물약 0개 아이콘 또렷·숫자만 회색, 축복 판 첫 줄 Blessed Scroll) · dev1-your-king 0c192861(내 King 'Your King' 이름 + M1_2 표시가 내 King 몸에, A23-228).
- **가지 dev1-staff-tilt 7411479b** (push, 병합 전): Config.WeaponGrips Staff/CrookStaff/FlaskStaff Turn·Rest Z -12(지팡이 끝 손 오른쪽 = 머리 밖). 근거 값(시험 Play, docs/art/verification_2026-10-18/r8_checks/): 머리 중심~지팡이 축 1단 +0.15, 2단 휘두름 -0.02(스침), 4단 코드 지팡이 끝 공 -0.30(박힘). test_tool_grip 방향 확인(손 오른쪽 쪽으로 12도). **Studio 확인 = 게임 플레이 9판 뒤 화면 차례**(`py build/dev1_tools/check1018.py D`: 2·3·4단 쉼/휘두름 거리 + 사진).
- 결정: 피해 숫자 예측 안 함(A23-221 ③); 체형 직후 첫 휘두름 1.96은 재현 안 됨(버그 아님); 쉴 때 칼·활이 긴 머리·치마 뚫음은 디자인 재개 때 검집과 같이.
- 시험 장소 주의: PhoneTest_1015는 옛 지도 → KingHop/Landmark:KingHill이 마을(-4,3,-424)로 감. 들판 (390,-110)에 직접 세워서 봄. MCP execute_luau의 require는 게임과 다른 모듈 사본(서버 PlayerService.GetData 안 됨) → 서버 값 바꾸기는 DebugCommand(Scene/Item/Gold/stats)로만, Config 바꿀 땐 worktree에서 임시로 고쳐 sync(커밋 X) 뒤 되돌림.
- 도구(git 밖, build/dev1_tools): press1017b.py(퀵슬롯 값 가르기 6번), craft7.py(Tool 탭 이유 줄·성공·실패·축복), check1018.py(C 두 King, A/D 지팡이-머리 거리, B 체형 직후), avatar1017.py, lag1017.py.
- **▶ 다음:** 지팡이 Studio 확인(화면 차례) → dev1.md 큐: #2 폰 실기 확인(화면) → 닫힌 문 판자 = 디자인 재개 때(idea_backlog), 맵 끝 = EdgeHint 끝남 → **#7 도감 빈 카드 획득처·진척** → #11 왕관 막대 내 기여 → #8 친구 위치.

## 10/17 오전 — 앱 재시작 여러 번 (최신; 긴 명령은 끊김 → 덩어리마다 바로 커밋·push)
- **dev1-first12 da277a7f** (push) = 10/16 밤 10 내용 + b81ee81c SignFit 위 칩도 피함 / 7be8d91a 거위 칩·[Join]은 M1_1 줄 사라질 때까지(HUD.EventsWait) / a7155259 Guide 없는 Npc 단계(M1_3 To Tiny·Return bag) 표시·누르기 = 그 NPC, 'Next goal ·' 줄 목표 글 / 0283a181 거리 글 테두리 진하게·마을 사람 말풍선 AlwaysOnTop / da277a7f #1 KO 화면 몬스터 머리 그림(DeathScreen.KindOf, 서버 Kind 오면 그것)·일어나면 HP 물약 칸 한 번 반짝(QuickSlots.Glow). 모두 최종 검수에 보고함.
- 스윕(../Game-dev1grip vs ../wt_d1base, build/sw/_summary.txt, 이어 돌리기 = scratchpad sweep_rest.sh 방식: 요약에 없는 시험만): 197/253까지 새 실패 = test_audio(고침)뿐.
- **▶ 다음 (최종 검수 10/17):** 개발 2 묶음(PracticeH 자리·Tiny·M1_3) 오면 같이 시험·병합(허수아비 F 한 대 → step 넘어가는지 다시) → dev1.md 큐: #2 폰 실기 확인(화면 신청) → 닫힌 문 판자·투명 벽 → 보이는 울타리(MapBuilder = 개발 2와 나눔) → #7 도감 빈 카드 획득처·진척 → #11 왕관 막대 내 기여 → #8 친구 위치.


> **10/18 정리(최종 검수):** 옛 절은 지움 — 전부 git 역사에 있음: `git show b558445b:docs/handoff/state/dev1.md`. 아래 = 지금 필요한 절 + 방법·도구 메모.
