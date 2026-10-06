# 게임성 개발(1) 인계 — 2026-10-06 멈춤 시점

- **최신(2026-10-06 밤 2, 사용자 "내일 하자"로 멈춤):** 오늘 밤 main에 올린 것 = **b1b8fda**(검수 저녁 ①②③: 월드 클릭도 L.SwingFaced = FaceTarget → 0.08초 뒤 Swing, 몬스터 FACE.MaxExtra 0.3 ≤ Fx TELE_GRACE, 펫 돌아올 때 P.Back 동안 달려오기, BatGoblin Idle·Walk 변환기 최신판 재생성, 새 test_pet_follow) · **d59f2a2**(개발 2 2b3447b까지 병합: H1·R1·N3, E1·E2·E3·E5, 3장 Grab Club, 대왕 9일 Banter·다섯 이름, 보호막 테두리, 계급 장식 3D) · **2985a5c**(클라 몫: Announce Banter 같은 색 채팅 줄, 상점 맨 위 ForgeGreeting/PotionGreeting, Panels STORY.Lines(LinesBy[Var] → Default → Lines)·Var 보관·STORY.Hint(ChoiceHintHalo/Horns, 0점 'leans' 줄), ClientMain ORDER 끝 "Audio", 새 test_story_client 76·변이 17/17) · **291c9f0**(SKL-1: Config.Skills 21개·플래그 꺼짐·Unlock Q1/Z5/X8·SkillKit/SkillDef/SkillNumbers·Keybinds SkillX(X, ButtonR3), 새 test_skill_kit 93·변이 10/10). 각 묶음 깨끗한 트리(Game-wtc)에서 오프라인 검사 통과.
  - **공용 Game 폴더:** 로컬 main이 origin/main과 갈라져 있음(검수 dbbb529 = 올린 2b24941). **내일 첫 일: `git pull --rebase`**(dbbb529은 저절로 빠짐) → 291c9f0 이상. 내 미완성 파일은 디스크에 없음(SKL-1 초안은 291c9f0으로 올라감).
  - **메인 Studio:** Edit 모드(밤 확인). **오늘 커밋들은 아직 Studio에 동기화 안 함** — 내일 검수 "전달함, 시작" 받고 `py tools/sync_to_studio.py`.
  - **내일 순서(검수):**
    1. **A23-61(새 사용자 결정):** 기본 공격 판정 = 앞쪽 반원(AimCone 180°), 옆 몬스터도 맞음. 클릭도 FaceTarget(b1b8fda에 이미 있음) — 서버 AimCone 숫자·검사 확인.
    2. **병합:** 개발 2 **f1f3b0c**(= d59f2a2 + 9d1e516 계급 문서 + d0a205b E12 숲 일일 + f1f3b0c E11 게시판 서버). **새 파일 src/ServerScriptService/BoardService.luau + Main INIT/START "BoardService"** — sync_to_studio.py가 새 Script를 Studio에 만드는지 꼭 확인(없으면 Main이 WaitForChild에서 멈춤). 내 몫 계약 docs/design/quest_volume_server_2026-10-07.md 2절(게시판 2곳 판+프롬프트 → BoardAction, 카드 창 Take/Reroll, 'Job' 줄, 켜는 날 Config.Board.Enabled = true).
    3. **Studio 묶음 동기화 + 자기 Play 확인:** 클릭 FaceTarget·A23-61, 817f93d 알림 줄바꿈(대왕·퀘스트 시작 알림), 35d3b56 Run/Walk 고리, Audio(소리 id 비어 조용한지, 오류 0), 상점 인사·이야기 대사, 보호막 테두리.
    4. **계급 장식 3D:** 이미지 생성 1 427baf8 — `py tools/build_kit_from_ids.py --only Acc_ --parent ServerStorage/MarkModels --out build/kit_marks_args.json` → `py tools/studio_mcp.py call execute_luau @build/kit_marks_args.json`(Edit 모드, MCP만). 애셋 id 표 art/models/worldkit/import40_assets_2026-10-06.json. 앞을 이미 −Z로 돌려 넣어서 **Config.Visuals.MarkModels.Yaw = 0**(개발 2 다음 커밋에 들어옴; 먼저 보려면 Config만 0으로). Play로 R1~R5 앞뒤·뿔 박힘·후광 뜸 확인.
    5. Save As build/GoodEvil.rbxlx(저장 창 = 검수 OK 뒤, 끝나면 화면 원래대로) → place/ 커밋.
    6. 대장간 3D 간판 "Forge"(장인 길드 빼기) → 노란 빔 얇게 → 같은 종류 이름표 겹침 → 폰 [메뉴] 펼침 원인(이미지 개발과).
    7. 그다음: Bright·Smokey(여자아이 0.8)·Tiny NPC 모델 + 태그 StoryNpc·NpcId + KidsBench(18,0,18)·Sunny Sam 벤치(18,0,-18), 마커 Guide 키 WoodsGate·HaloBridge·HornsBridge·GoblinWoods·SkeletonRuins·OwnTown, BB24, PERF-1, BB41, A23-53 세계 v2.
  - **넘긴 것:** A23-57 진영 카드 2장(가운데)은 이미지 개발이 맡음(검수 2026-10-06) — FactionPicker/ClassPicker 안 건드림.

- **최신(2026-10-06 밤, PC 재시작 뒤):** 오늘 저녁 커밋 5e15ab6(이전 세션 영어·PetFollow·물약 검사), b416527(카메라 오른쪽 드래그만 A23-51 + Studio 기기 흉내 원인), 4402a2c(몬스터 바라보며 때리기), 132ddf2·59c2585(개발 2 4f47f42 병합), 그리고 이번 place 커밋(몬스터 움직임 ①~④·자연스러움·Run/LookAround·빨간 테 ⑥ + place/GoodEvil.rbxlx 19:28:56). 메인 Studio = 진짜 장소(dfd22257 창), Edit. 재시작 뒤 열린 AutoRecovery 창은 사용자 답대로 저장 없이 닫힘(디스크 복구 파일은 그대로).
  - **병합 대기:** 개발 2 0c96f32(= 2e6c514 H1·R1·N3 + A23-57/58 + 결말 단서 + E0 + 서브 줄 3개 + 보호막 → 진영 색 테두리). 이미지 개발 7cc9d60·1f9d291(SkillBar, A23-60)은 이미 main.
  - **다음 순서:** dev2 병합 → SKL-1(Config.Skills Defs 21·Unlock·"Costs N MP"(A23-60)·SkillKit/SkillDef/SkillNumbers·Keybinds SkillX, 초안 scratchpad skl1_config.luau, keys_settings 검사 SkillX 반영) → 개발 2에 해시 → A23-57 진영 카드 2장 → 대장간 3D 간판 "Forge"(장인 길드 빼기) → 노란 빔 얇게 → 같은 종류 이름표 겹침 → 폰 [메뉴] 펼침 원인(폰에서 ui.foldGeom/HudLayout fold 자리 비어 보임) → 브라이트(여자아이 A23-59)·스모키 0.8 + KidsBench + NPC 태그 StoryNpc → BB24 → PERF-1 → BB41 → quest_volume 게시판(10/12 뒤) → A23-53 세계 v2.
  - **사진에서 찾은 남은 문제:** 알림 영어 잘림·폰 HUD 겹침(이미지 개발에 넘김), 대장간 간판 한글, 빔, 이름표 겹침, [메뉴] 펼침.

- **최신(2026-10-06 저녁):** 유령 3D(왕 111999674841692·똘마니 84018800442559) CustomModels 연결·정면 확인(devlog 16, 검수 통과), 크기 똘마니 3·왕 9(Config Scale 0.6/1.8). 이름표는 같은 종류 5칸 안이면 하나(MonsterLabels). **BB13** Panels.Register(kit·Cleanup·FixedBody·Rebuild 거르기·RENDER Arg·뒤로 = 온 창·Esc/패드 B 닫기) + **BB3** SettingsUI.luau(설정 창 영어: 직업·환생·오프닝·이름 숨기기·휴가·닉네임(BB8 전까지)·키 설정 탭·효과음·흔들림·키 표시·버전 줄·저장 꺼짐) + Fx 효과음 배수·흔들림 끄기 + SettingsService가 GameState SaveOK. 메인 Studio에 a0e8098·052c7b4와 함께 동기화, 자기 Play로 Settings·Keys 탭 확인(docs/art/verification_2026-10-06/bb13/). **남은 것:** Config.Help(BB15 도움말·새 소식, 규칙 조사 중) → 등록 확인 → 오프라인 keys_settings 재검사 → 커밋. 그다음 A23-34 맨손 병합(검수 OK 오면, 클라이언트 §6 + HUD doUpgrade 서버 경유), A23-48 내 창 글자 영어.

- **최신(새 계정, 한도로 멈춤):** 개발 2 병합 끝 = main **dfefaaa**(푸시, eac036f·ff38ce4·e078bf5, 충돌 5곳 해결, 병합 트리 오프라인 16종 변형 포함 통과). 이미지 개발 미완성 HUD v2는 worktree `Game-imgdev`로 옮겨져 작업 폴더 src는 HEAD와 같음. 임시 worktree `Game-wtc`는 병합용(지워도 됨).
- **Studio:** 메인 Studio(창 이름 '악마 키우기 (placeId: 81671223175574)') 열림·Edit 모드. dfefaaa src 동기화(74개 씀·6개 지움) + `apply_studio_state.py`(몬스터 모델 10종 다시 넣음) 끝. **플레이 확인·Save As·place 커밋은 아직.**
- **다음:** 플레이로 랭킹·게시판 서버 확인(오류 0) → Save As build/GoodEvil.rbxlx → place/ 커밋 → b9ada3b 땅·조명·나무 메인 적용 → 호박밭 배치 4개 → BB13(A23-38 + A23-40 B안: 아이콘 줄 끝 [메뉴]에서 위로 펼침) → BB3 → BB6 → BB7. 개발 2 BB14는 rebase 끝 = **65e2ba6**(dev2, 푸시됨; 500f60d는 옛 해시라 쓰지 않음) → 병합 뒤 몬스터·플레이어·낙하 쓰러짐에 본인만 Net.Fx 'KO' 확인. A23-39 펫 조련사 클라이언트는 PET-3와 10/17~18(검수에 알림).

(아래는 이전 기록)

- **끝난 것(main에 푸시):** 1614575 핼러윈 4종·사탕·호박 대왕 / c6d31ec 안 F10-4 첫 임무 60초 자동 지급 / 6b1e45a 27246d1 검수 수정(상호작용 키 제한, Keybinds.ShowsKeys, 러너 mutationsSkipped, 검사 보강, 황금 몬스터 Fill 0.25, 슬라임 깊이 늘리기 제거) / 78320eb 개발2 5f52534 병합(BB37·BB12) / 5f357b7 병합 뒤 증거.
- **커밋 안 한 파일:** `src/StarterPlayer/StarterPlayerScripts/Fx.luau` 한 개. '땅에 붙는 느낌' 작업이에요(검수 요청 1~3). 컴파일되고 Studio에 동기화했어요.
  - 블롭 그림자: 카메라 140스터드 안 모든 몬스터 밑에 원판 3겹. 슬라임은 몸×1.15, 유령은 작고 옅게.
  - 슬라임 통통: 몸 높이 15%, 최대 0.6.
  - 착지 먼지 3~5개.
  - 슬라임 0.1 묻힘.
  - 확인: 해골·고블린 발밑 그림자는 보여요. 슬라임 그림자를 키운 뒤의 '후' 사진은 아직 못 봤어요. 사진은 scratchpad의 after_fix_6.jpg이고, '전' 사진은 docs/art/verification_2026-10-06/monsters_before_fix_2026-10-06.jpg예요. 사진을 보고 커밋하면 돼요.
- **Studio 상태:** 메인 Studio(악마 키우기, pid 18272)는 Edit 모드이고 Play는 멈췄어요. src 전체가 동기화돼 있어요(Fx 포함). place 저장은 75ad8ef 이후 안 했어요. 다음 place 커밋 전에 `py tools/apply_studio_state.py` → 파일로 저장(Save to File As build/GoodEvil.rbxlx) → place/로 복사해요.
- **다음 할 일 순서:**
  1. Fx '후' 사진 확인 → 커밋. 검수 4번(고블린·해골 걷기 발 닿음 캡처)과 5번(같은 자리 전·후)도 해요.
  2. 1614575 검수 결과 10개(검수 메시지 참고):
     - 대왕 안전: Level<5 또는 플레이 600초 미만, 진영 무관
     - 기여: 3타 + 최대 HP의 0.5%
     - Lv8 미만은 대왕 XP를 XPToNext로 자르기
     - 무기 줄은 MinLevel 이상일 때만 + 장착 레벨 제한
     - 대왕 주문서 확률 절반
     - FRONT_FIX를 매번 적용(멱등)
     - MonsterMotion State 청소
     - 드랍 줄 ×N
     - CrownTrialMiss를 QuestKind로
     - 대왕 안전 오프라인 검사·studio_halloween json
  3. BB13 → BB3: 작업 지시 초안은 scratchpad의 wf_bb13_bb3.js예요. 메뉴 아이콘 키는 Config에 있고, [내 캐릭터]는 UIKit.CharacterIcon을 써요.
  4. 이미지 개발 f0e011a·938c230 동기화·확인, 개발2 다음 덩어리 병합.
- **주의:** 같은 작업 폴더를 여러 세션이 써요. 커밋은 `git commit -- <경로>`로만 해요. 테스트는 변형 포함으로 돌려 증거 json을 남겨요.
