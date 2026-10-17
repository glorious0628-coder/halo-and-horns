# 게임 플레이 — 상태

## 10/16 오후 (최종 검수가 엶)
- 사용자 "게임 플레이하는 세션도 하나 만들자!" → 역할 파일 `docs/handoff/role_prompts/04_playtest.md`.
- **다음(1판):** `build/PlayTest.rbxlx` 복사·열기(🟠 절차) → main sync → 빛 첫 10분 PC 처음부터 → 보고 `docs/review/playtest/2026-10-16_r1.md`.
- 이미 아는 것(다시 보고 X): 무기 쥐는 모습 이상(개발 1 고치는 중, `docs/review/grip_check_2026-10-16.md`), Tiny 첫 G가 M2_3 제안보다 분실물 창 먼저, 순간이동 직후 Rose 첫 G 무반응(둘 다 개발 2).

## 10/16 저녁 — 1판 끝 (빛 · 전사 · PC, sync acf54995 / src 9ca5aafc)
- 한 것: build/PlayTest.rbxlx 열고(창 이름이 'Game'으로 잡힘 → STUDIO_ID로 고름, game.Name = PlayTest.rbxlx 확인) main sync → 새 저장으로 진영 → 할리 → I'm In → 선생님 → 대장간 첫 무기 → Otto M1_1 → 왕자 → 강화 → M1_3 받음까지(12분 26초). Play 중지, PlayTest 프로세스만 닫음.
- 보고서 `docs/review/playtest/2026-10-16_r1.md`, 사진 `docs/art/verification_2026-10-16/playtest/r1/`(jpg).
- TOP 5: 선생님 연습 막다른 길 / 강화 단계에서 KO / 할리가 첫 화면 밖 / 보상 안 느껴짐 / 첫 10분 절반이 밤.
- 도구: scratchpad pt.py(play·stop·state·texts·btns·near·shot·key·click·lua) — 다음 세션이면 이 절 보고 다시 만들기. 걷기는 character_navigation(길 찾기)라 시간은 아이보다 짧음. 서버에서 허수아비를 못 찾음 = 허수아비는 클라(StoryNpcs makeDummy)에만 있음.
- **다음 판:** 메인 반영 1의 다음 'sync <sha>' 신호 → 뿔 · 궁수/마법사로 처음부터 + 바뀐 곳(scene.py). 가능하면 2x XP 패스 끈 판.
- 최종 검수 10/16 저녁 메모(다음 판 꼭): ① **패스 없이** — Play 시작 직후 Server에서 `game.ServerScriptService.DebugCommand:Invoke("", "Pass", "XP2:off")`, 같은 식으로 `Gold2:off`·`VIP:off`(MonetizationService.DebugSetPass, 이 세션만, 저장 안 됨; 첫 인자 = 플레이어 이름이 필요하면 이름) → 위쪽 '2x XP · Gold' 칩이 없어졌는지 사진으로 확인. ② 오프닝 안 나온 원인 값 하나: Play 직후 1~2초 간격으로 IntroSeen·화면(인트로 GUI) 값 기록 — 1판은 25초 뒤 처음 봤을 때 이미 IntroSeen=true(인트로가 그 사이 끝났는지, 안 나왔는지 모름). 클라가 `IntroSeen` 원격을 쏴야 true가 됨(QuestService onIntroSeen).
- 지금: 쉼, 메인 반영 1 sync 신호 기다림.

## 10/16 저녁 — 2판 끝 (뿔 · 궁수 · PC · 패스 끔, sync 1c946b0a)
- 보고서 `docs/review/playtest/2026-10-16_r2.md`, 사진 `.../playtest/r2/`. 패스 끄기 = DebugCommand:Invoke(<플레이어 이름>, "Pass", "XP2:off") 등 — 됨.
- 오프닝 원인 값: 오프닝은 나오고 약 21초 뒤 혼자 끝나 IntroSeen=true(1판은 25초 뒤에 봐서 몰랐음).
- 고쳐진 것 확인: 첫 스폰이 Magpie 쪽을 봄. 그대로: 연습 할 일 안 보임, 강화 중 KO(2/2), 첫 무기 창 없음. 새로: 초원 들어가면 방향 표시 꺼짐, 사냥 중 Daily Gifts 창.
- 못 한 것: 'Tiny 본편 먼저'(c2644158) — M1_3 Tiny 단계까지 못 감. 도구 문제: character_navigation이 (380,11,60) 대신 바닷가로 감 → 슬라임 0/4.
- 도구: pt.py에 PT_ROUND 환경 변수(사진 폴더), intro_watch.py(1초 간격 IntroSeen·GUI), face.lua(가장 가까운 BigSlime 보기). Studio id는 매번 list_roblox_studios로(이번 34dfd4a5).
- **다음 판:** 다음 sync 신호 → 'Tiny 본편 먼저'를 장면으로 + 빛 · 마법사 처음부터.
- 최종 검수 10/16 저녁: 다음 판부터 보고서 '게임성' 칸에 한 줄 — "첫 10분 누구나 XP 2배를 아이가 알아챘나?"(칩 '2x XP · N min'을 봤나, 언제, 뜻을 알 만했나). 패스 끈 판에서만 보임. (2판 값: 첫 화면 0:08부터 '2x XP · 9 min' 칩이 위 가운데, 9:50 Daily Gifts 때는 없어짐. 글만 있고 눌러도 설명 없음 — 다음 판에 눌러 보기.)

## 10/16 밤 — 3판 끝 (빛 · 마법사 · 패스 끔, sync f6af22e6 쥐는 점)
- 보고서 `docs/review/playtest/2026-10-16_r3.md`, 사진 `.../playtest/r3/`(walk_sheet, attack_sheet, *_zoom).
- 쥐는 모습: 마법사 서 있기 좋아짐 / 공격 때 지팡이가 머리 뒤를 지남. 강화 중 KO 3/3, KO 이름 'King Slime'이 틀렸을 수 있음(근처엔 왕자뿐), 빛 첫 화면 카메라가 할리를 안 봄(몸만 돎).
- 도구: cam.py(카메라 각도 사진), walkshot.py(W 누른 채 따라가는 카메라), atkshot.py(F 순간 사진) — scratchpad, STUDIO_ID 환경 변수 필요.
- **다음 판:** 다음 sync 신호 → 전사·궁수 쥐는 모습 + 'Tiny 본편 먼저'(장면).

## 10/16 밤 — 4판 끝 (뿔 · 전사 → 세 직업 쥐는 모습, sync 2a3489d1)
- 보고서 `docs/review/playtest/2026-10-16_r4.md`, 사진 `.../playtest/r4/`(직업별 *_sheet).
- 좋아짐: 마법사 공격(머리 겹침 없음), 궁수 쏘기·활 등에 메기, 전사 공격. 새 문제: 전사 몽둥이 허리 뒤 수평 꼬리, 궁수 활시위가 등 뒤에 따로 뜸.
- 'Tiny 본편 먼저' 확인됨(장면: scene.py OfferM1_3 → 수락 → DebugCommand Faction Horns → StoryStep M1_3:3 → Tiny G). 대화 안 보임 + 목표 'Next goal.'은 진영 바꾼 시험 탓일 수 있음.
- 도구: Studio 명령 Class(직업 바꾸기), Clock 12, idle.py/walkshot.py/atkshot.py(PRE·FACE 환경 변수), sheet.py. 순간 이동 직후 ~10초 하얀 사진 → 기다렸다 찍기. 뿔 마을 → 사거리 character_navigation 실패할 때 있음.
- **다음 판:** 다음 sync 신호 → 뿔 처음부터 M1_3 3단계 Tiny까지(진영 바꾸기 없이), 빛 전사 검 허리 각도.

## 10/16 밤 — 새 계정 세션 시작
- 도구는 옛 scratchpad(`%TEMP%\claude\C--Users-glori-Documents-Roblox-Game\52d0667a-…\scratchpad`)에서 새 scratchpad로 그대로 복사(pt.py·intro_watch·cam·walkshot·atkshot·idle·sheet·*.lua). pt.py 안 STUDIO_ID 기본값은 옛 값 → 매 판 list_roblox_studios로 새 id를 환경 변수로.
- 지금: 메인 반영 1의 'sync <sha>' 신호 기다림. 다음 판 = 4판 '다음 판' 그대로.

## 10/16 밤 — 5판 끝 (뿔 · 마법사 · 패스 끔, sync 85754011 칼 허리·활 시위)
- 보고서 `docs/review/playtest/2026-10-16_r5.md`, 사진 `.../playtest/r5/`(cmp_warrior_idle·cmp_archer_idle = 위 r4/아래 r5).
- 고쳐짐: 칼 허리 아래 45°(뿔·빛), 등 활 시위 없음. 새로/그대로: KO 3번(강화·Lv5 슬라임·HP 7 걷기), M1_3 길 표시 틀림/없음(To Tiny 410스터드 0), Tiny 대화 없음(진영 안 바꿔도), 뿔 첫 화면 카메라 Magpie 안 봄.
- 도구: PlayTest 창 id 21d331aa(매번 list로), atkshot/walkshot OUT = PT_ROUND. 뿔 마을 → 대장간 길 찾기는 (0,3,380)→(0,3,280)→(10,3,200)→(30,3,120)→(36,3,70) 중간 지점으로.
- **다음 판:** 다음 sync 신호 → 뿔 전사로 처음부터(첫 무기 몽둥이 허리 각도) / first12 병합 뒤 강화·KO·물약 흐름.

## 10/17 — 6판 끝 (빛 · 궁수 · 패스 끔, src d4c4b483 첫 12분 새 흐름)
- 보고서 `docs/review/playtest/2026-10-17_r6.md`, 사진 `docs/art/verification_2026-10-17/playtest/r6/`.
- 좋아짐: 첫 화면 카메라, 아침 시작(밤 13분), 허수아비 한 대, 첫 무기 몸짓, 모루 강화 창, 1000골드, 뿔 몽둥이 허리 45°. 문제: King 2번째도 KO(빛 마을에서 일어남), 퀵슬롯 넣는 길, 강화 실패 표시 없음, 표시 엉뚱, Daily Gifts 창.
- **도구가 옮겨짐:** scratchpad가 지워져서 `build/playtest_tools/`(git 밖, 재부팅에도 남음)에 다시 만듦 — pt.py(PT_DATE·PT_ROUND·STUDIO_ID), pose.py(idle/walk/atk PRE → 시트), intro_watch.py, face.lua(NAME). 열기: place/ → build/PlayTest.rbxlx 복사 → Start-Process(pid는 build/playtest_tools/pid.txt).
- 도구 주의: 길 찾기는 KO 뒤에도 다음 지점으로 걸어감 → KO 장면 볼 땐 KO 뒤 nav 멈추기. 빛 Gleam 동상 옆에서 nav가 'Success'만 하고 안 움직임 → W로 빼기.
- **다음 판:** 다음 sync 신호 → King 첫 KO 뒤 Fizzby 옆·KO 화면 몬스터 그림, M1_3·Tiny, 대장간 잠금 글.
- 다음 판에 같이 볼 것: f6507381 맵 끝 투명 벽 흐린 막(EdgeHint, 클라만) — 맵 끝까지 걸어가서 막이 보이나·이상한가.
- 다음 판에 같이 볼 것: 66cdb70d 장인 쪽(첫 12분엔 안 보임) — 끝에 scene.py ArtisanSmith/ArtisanAlch로 짧게.

## 10/17 오후 — 7판 끝 (뿔 · 전사 · 패스 끔, src b823a57c)
- 보고서 `docs/review/playtest/2026-10-17_r7.md`, 사진 `docs/art/verification_2026-10-17/playtest/r7/`.
- 확인됨: 뿔 첫 화면 카메라, King 첫 KO → Fizzby 옆, M1_3 끝 다음 목표 글, EdgeHint 보임(하얀 판처럼), 장인 Tiny 부탁. 문제: King 두 번째 KO(2/2), 강화 실패 2/2 표시 없음, 표시 엉뚱(King·Lost bag), 퀵슬롯, KO 화면 그림 없음.
- 도구: M1_2에서 막히면 DebugCommand StoryDone M1_2 → scene.py OfferM1_3(진영이 빛으로 바뀜). KO 장면 = KO 글 뜨면 바로 shot. 맵 끝 = Config.Map.Bounds(-260/1840/-720/720, 다 물), 순간 이동 후 Humanoid:MoveTo.
- **다음 판:** A23-225 병합 뒤 강화 → King 다시 → Lv5 시험·M1_3 진짜 순서.

## 10/17 저녁 — 8판 끝 (직업별 전사·궁수·마법사, src 9657762c → c16e09ab → 034174d8)
- 보고서 `docs/review/playtest/2026-10-17_r8.md`, 사진·기록 `docs/art/verification_2026-10-17/playtest/r8/`.
- 공통 문제: 두 번째 King 못 이김(마법사: 길 위 King Slime이 뛰어내려 KO, 언덕 King과 둘), Quick [1] 두 번 = 칸 비고 목표 'Drink' 남아 막힘, 마법사 Prince가 표시 자리 밖, 궁수 Prince F 28번, 긴 머리·치마와 칼·활 겹침.
- 도구: `build/playtest_tools/flow.py <Halo|Horns> <Warrior|Archer|Mage> [단계]` 한 직업 점검표 자동(0 시작 … 9 다음 목표), `pose.py idle|walk|atk PRE`. KO 순간 길 찾기 ~2분 멈춤(도구). 멈춘 python은 Win32_Process에서 flow.py로 찾아 끄기.
- **다음 판:** A23-227 뒤 두 번째 King 세 직업 + 퀵슬롯 두 번 누르기.
