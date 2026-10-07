# 게임성 개발 1 인계 (2026-10-07 저녁, 계정 바꾸기 전)

다음 계정의 게임성 개발 1이 읽을 것. 먼저 `AGENTS.md`, 그다음 이 파일. 사용자에게는 한국어, 게임 글자는 영어만(A23-48).

## 1. 지금 상태 한 줄
- **메인 Studio = origin/main 713fd05 코드**(dev2 A23-71 병합까지, 동기화 뒤 다시 비교: 바뀐 스크립트 0 / 그대로 104). **place 커밋 ce27afa**(build/GoodEvil.rbxlx 13:52:14 = place/, sha256 b865947c…, XML 12,196,623바이트). 이 place에 아래 편집 화면 변경이 다 들어 있어.
- 메인 Studio 편집 화면에 넣은 것(동기화와 별개, place 파일에만 남음): 빛 성·뿔 성 v4 배치, 옛 Cathedral·겹친 HornTower 1개 → ServerStorage.KitOld, 하늘 왕관 빌보드 앞 3/4, Chat.ChatLocalization(빈 LocalizationTable), WorldKit3D에 성 2·숲 소품 7·숲 큰 것 10 모델.

## 2. 오늘 끝난 것 (커밋)
- 오프닝: 폰 위 띠 화면 맨 위부터(0221b7e), 첫 장면 왕관 앞 3/4(아래 25°·옆 30°).
- 채팅 영어: 레거시 채팅이라 서버 `ChatText.luau`가 팀 줄 "You joined the Horn Legion!"(팀 색, 일반 채널), 다른 Roblox 줄은 영어만, Team/System 환영 줄 지움(948e71b). Announce에 TextChatService 쪽도 있음. place의 `Chat.ChatLocalization` 빈 표 → 채팅 칸 글자도 영어("To chat click here…", "Tap here to chat").
- 모든 GUI AutoLocalize = false(ClientMain, 1c04476): 한국어 계정에서 Roblox 자동 번역 막기. PlayerGui 891개·월드 모두 0개 켜짐 확인.
- 큰 지도: "Market" 숨김(Config.Features.Market = false), 대장간 자리 이름 "Forge"(NeutralFaction 꺼진 동안). ArtisanGuild = 대장간 모루라 숨기지 않음.
- A23-68 클라 #1~#3(cfd05ec): `FirstSteps.luau` — 수락 → "Off to Squishy Meadow! 3·2·1" + 까맣게(Fx Travel/TravelDone), 공격 힌트(5초), 초원 슬라임 표시(QuestMarker.Focus); HUD 첫 무기 "Stronger!" + Power 천천히 + 반짝이 + PowerUp 소리.
- A23-71(da6402b 등): 배우기 전 스킬 칸 숨김, 배우는 순간 "New skill!" + 버튼 톡 + "Press Q"/"Tap the new button" + SkillLearn(없으면 PowerUp). 잠김 = 레벨 AND SkillSlots(둘 중 하나라도 열리면 열림). 키 미리 누르면 "Skills come at Lv N".
- 3회차 클라: 폰 고정 줄 한 번 → 안내자 창(#3), 둘째 줄 순서 이야기→받기→S0→일일 + PC 0단계 머리글 숨김(#1), 선택 안내 "(you have N)" + 실제로 깎이는 값(#5), 안내자 첫 창 [I'm In!] 넓게 + 폰 64px 얼굴(#2), 선택 버튼 BtnKind/BtnSneaky + 날개·뿔 글리프(#10, 도시락 카드도). #4는 이미지 개발이 UIKit에서 이미 함.
- UI 2회차: #8 100골드 이상 무기 두 번 눌러 사기("Tap again to buy" 3초), #3 멀리서 연 대장간 구경 + [Show me the way](HUD.ShowGuide), 물약 0개 [Buy] → 물약 상인 길 안내.
- 소리: 알림 payload Sound 따르기("None" = 무음), Fx Choice → Purify/Devour(점수 오를 때는 안 냄), 퀘스트 초 줄 '5/10 s'(ProgressUnit), Plural 5곳, SwingArcher = ""(sound_spec §4-2 1).
- 카메라: 앞으로 걸을 때만 따라감(걷는 방향·카메라 앞 내적 ≥ 0.5, 옆걸음 빙글 문제), 속도 45°/s.
- E11: MapBuilder `ensureJobBoards` — Landmarks.JobBoard_Meadow/Woods 호스트에 ProximityPrompt "BoardPrompt"(속성 Board), Config.Board.Enabled를 따름. 창(BoardPanel)은 이미지 개발(다음 계정) 몫, `docs/handoff/imgdev_handoff_2026-10-07.md`.
- 병합: dev2 0f6de17 · 324055a · 2c5e84e · 54c1041 · a95e9c6, 이미지 개발 6f0ab5a · eecc7b3 · 5b76009.
- 시험 고침: halloween(KING 가짜 물체 TextBounds·V2.rects 스텁), barks Main 패턴, town_quests 스위치.

## 3. Studio 확인 결과 (내 시험 Play, 2026-10-07 저녁, 한국어 Roblox 언어)
- PC: 팀 줄 영어, 화면 한글 0, 수락 → TravelFade 3·2·1 → 까맣게 → ZoneId SlimeMeadow·TutorialStep 2 → 페이드 사라짐, AutoLocalize 켜진 GUI 0, 콘솔 오류 0.
- 폰(749×361): 위 띠 화면 맨 위(-58, 높이 83.2 = 띠 25.2 + 버튼 줄 58), 좌우 끝까지(x -47, 폭 748), 채팅 영어, 퀘스트 짧은 이름 "Supply road 0/5".
- **[Menu] 폰:** MCP instance_path 클릭으로 펼쳐지지 않음(TileMenu (601.5, 52.25) 45×45). 이미지 개발 말로는 기기 흉내에서 MCP 마우스가 어긋남. GetGuiObjectsAtPosition으로 덮개 확인이 남음(7절).
- A23-71(713fd05 뒤 시험 Play): Lv1에 스킬 버튼 없음 → DebugCommand Level 5 → Q 나타남 + "New skill! Shockwave" + "Press Q", 콘솔 오류 0(`pc/a2371_log.txt`).
- 사진(창 복원 뒤, 검수 허락): `pc/01_opening_crown.jpg`(왕관 앞 3/4, 자막·Skip), `phone/01_opening_crown.jpg`(위 띠 맨 위부터), `edit/castle_halo_front.jpg`·`castle_horns_front.jpg`(성 두 개), `pc/05_halo_castle.jpg`(Play 중 'Click to hit!' 공격 힌트가 보임 — Play 중 카메라를 성 쪽으로 돌리는 건 안 먹었고, 성 사진은 편집 화면 것이 유효).
- 증거: `docs/art/verification_2026-10-07/studio_round_evening/{pc,phone,edit}/`(log.txt·result.json·사진).

## 4. 다음 큐 (순서대로, 검수 2026-10-07 저녁)
1. **빛 마을 분수 물줄기(사용자: "물줄기도 나오게 해야지 로블록스 이펙트 사용해서!"):** Town_Halo_Fountain(3b HD로 들어옴)에 Roblox 효과로 흐르는 물. 위 그릇에서 떨어지는 줄기 Beam(흐르는 물 텍스처를 TextureSpeed로) 또는 ParticleEmitter(포물선, Acceleration 아래), 맨 위 솟는 물기둥 1, 아래 그릇 튀김(Splash) + 물결 반짝이, 흰·금 작은 별 파티클, 위 후광 고리 Neon + 금빛 PointLight(맵 전체 40 제한). 순서(A23-62): Creator Store 무료 물 효과 먼저(스크립트 다 지우고 맑은 하늘색·흰 하이라이트로) → 없으면 직접. 폰 성능(Rate 낮게), 흔들림 끄기면 반짝이 줄이기. 모델이 아직 없으면 지금 분수(Landmarks.Fountain)에 먼저 붙여 시험.
2. **폰 [Menu]:** 폰 흉내 Play에서 MCP instance_path 클릭으로 펼쳐지지 않음(TileMenu (601.5, 52.25) 45×45, 키 B로는 열림). `GetGuiObjectsAtPosition`(가운데)은 FxEdgeGui.FxHurtFlash, MainGui.WorldMap.Viewport(Active) 순이었지만 WorldMap root는 닫히면 Visible=false(WorldMap.Close)라 이 API가 안 보이는 것도 돌려주는 것으로 보임 → 덮개라는 증거는 아님. 이미지 개발 말로는 기기 흉내에서 MCP 마우스가 어긋남. 다음: 실제 폰(또는 Studio 기기 흉내에서 사람 손 클릭)으로 확인, 안 되면 이미지 개발(HudLayout)과 원인 찾기.
3. **고블린 숲 배치:** `docs/design/kit_woods.md`(자리·개수)와 이미지 생성 1 메모(우두머리 공터 (1110, 120) 지름 40, 가운데 반지름 12 비움, 통나무 의자 6~8 + 큰 그루터기 2~3 + 탁자 1 + 빈 천 깃발 2, 주황 금지). 좌표가 **지도 v2(A23-53)** 기준이라 지도 v2를 먼저 넣어야 함(Config.Map.Lands·Zones·Bridges·Roads·Gates·Bounds + `tools/preview_map.lua` 지형, `docs/design/world_map_v2_2026-10-06.md`). 모델은 이미 ServerStorage.WorldKit3D에 있음(Kit_W_* 7 + W_* 10). 나무는 0.8~1.2배·Yaw 무작위로 수십 그루, 길 |z|<12 비움, 충돌은 줄기 쪽만. W_Gate는 Gate_GoblinWoods + Lintel(PrimaryPart) 계약 유지. 사냥 게시판 3D(Tripo 11a53c2)는 JobBoard_Meadow / JobBoard_Woods 이름으로 놓으면 BoardPrompt가 그 PrimaryPart에 붙음.
4. **모닥불 불꽃:** 숲 모닥불(Kit_W_Campfire, 이미지 생성 1이 다시 그리는 중 — 다음 가져오기 때 id)은 장작 + 잔불까지만 그림이라, 불꽃·빛은 Studio에서 Fire/Neon + PointLight(야영지 3개, 맵 전체 40 제한)로 붙임.
5. **자동 전투 Lv5 확인:** A23-71 뒤 자동 전투는 배운 스킬만 씀 — Lv5 전에는 휘두르기만, Lv5에 Q를 배운 뒤에는 자동으로 Q도 쓰는지 Studio Play로 확인(SkillSlots·Fx SkillUnlocked, dev2 940fb2e).
6. 소리 설계서 §4-2 Audio 일(`docs/design/sound_spec_2026-10-07.md`): 처치 '뽕'·동전을 내 다음 Swing/Release의 ContactDelay + 0.04 s에(여러 마리면 KillPop 1 + 동전 물결 최대 4) → Swing.Mage를 SwingMageHalo/Horns로, SkillCast는 LaunchDelay에, 진영 층 Q/Z/X → 궁수 SwingArrow 한 발 + 대상 2 이상이면 +0.068 s → HitCrit 층 키, HitHeavyAt=3 삭제(같은 재질 ×1.25), 다른 플레이어 풀 분리, MaxPlaying 우선순위, 자동 전투 보상 0.75배 → 나머지 7~14번·경로표. id 없는 키는 ""(무음). 소리 id는 소리 만들기 세션이 보냄. 폰 흉내에서 말랑(HitSoft) 소리 들리는지도(폰 -5.1 dB 경고).
7. SKL-3 클라(개발 2 작업 중): Fx 'Skill' Statuses, 'Hop' {To, T} 0.25초 이동, 'SkillEnd', GuardPct/GuardUntil 표시(XEnabled 꺼진 채). 계약 문서는 개발 2가 보냄.
8. 3회차 #7·#6 Studio 확인(dev2 a95e9c6): 초원 도착 뒤 첫 처치 10초 이하, 아바타 4종(올림머리·긴 머리·모자·대머리) 후광·뿔 R1·R2 사진.
9. 교차로 3D 순위 게시판 글 넘침 사진 확인(PvPService → MapBuilder.GetBoardLabel; BoardText는 TextScaled+TextWrapped+UIPadding).
10. A23-69 스탯 찍기 클라(10/18–19): Hero 창 [Stats] 탭 `StatUI.luau`(64px 2줄 + 자동 스위치 + 초기화, 전투력 칩 누르면 열림, 직접 모드 빨간 점, 레벨업 줄). BB8(10/13–14)이 먼저. 설계 `docs/design/stat_points_2026-10-07.md` §4·§7.
11. 그 밖: #10의 남은 조각 명예·악명 칩(IconRankHonor/Infamy), NPC Bright·Smokey(0.8배)·Tiny(태그 StoryNpc/NpcId + 벤치), A23-64 TownReact(10/17 점검에서 여유 있을 때만), BB24·PERF-1·BB41.

## 5. 주의할 점
- **동기화는 깨끗한 worktree에서만:** `C:\Users\glori\Documents\Roblox\Game-wtc`(내 worktree). 시작할 때 `git fetch -q origin && git merge --ff-only origin/main`(또는 checkout --detach origin/main) → `git rev-list --left-right --count HEAD...origin/main`이 `0 0`인지 → 그 폴더에서 `py tools/sync_to_studio.py`. 공유 Game 폴더에서 sync하지 말 것(다른 세션이 로컬 커밋을 두는 일이 있음). 두 번째 worktree `Game-wtc2`는 병합 시험용.
- **커밋:** Game-wtc에서는 평소대로 `git commit -- <paths>` → `git fetch` → 필요하면 `git merge --no-ff origin/main`(dev2 커밋 해시를 지키려면 rebase 말고 merge) → `git push origin HEAD:main`. 공유 Game 폴더에서는 `py tools/push_paths.py -m "제목" <경로들>`(AGENTS f27ca7e).
- **Studio:** 메인 Studio pid는 매번 바뀔 수 있음 — 창은 프로세스 id로 고를 것(제목 "헤일로 & 혼스 - Roblox Studio"). `Get-Process RobloxStudioBeta | Select -First 1`은 이미지 개발의 UiSandbox를 잡은 적이 있음. Studio MCP는 `tools/studio_mcp.py`(제목에 GoodEvil이 든 창; 지금 place 81671223175574).
- **화면 제어:** 창 복원·최소화도 화면 제어 → 검수 "전달함, 시작" 먼저. computer-use를 Esc·확인용으로 부르지 말 것. 창이 최소화돼 있으면 screen_capture가 하얗게 나옴.
- **사용자 Play 중에는** sync·Play·입력 금지. `get_studio_state`로 Edit인지 먼저 봄. 내 시험 Play는 끝나면 멈추고 기기 흉내 PC로.
- **시험:** 내 러너 `run_suites.sh`(scratchpad)는 `py tools/test_<이름>.py`를 차례로 돌림. 전체 오프라인 시험 50개 남짓(costume_physics·skin_binding_studio 제외, place_english --studio는 Edit에서만). halloween은 3분쯤 걸림.
- **HUD·Fx는 200 지역 변수 한계 가까움:** 새 상태는 L / TXT 같은 표에.
- **검수 메시지:** 검수 세션이 '권한 무시' 모드라 내 SendMessage가 붙잡혔다가 풀리기도 함. 검수 답은 앱 세션 메시지로 옴 — 기다릴 때는 턴을 끝내야 대기열 메시지가 도착함.

## 6. 증거 경로
- 오프라인: `docs/art/verification_2026-10-07/offline_{chat_text,first_steps,first_weapon,skill_learn,round3_client,story_client,place_english}_2026-10-07.json`, `docs/art/verification_2026-10-06/offline_camera_input_a23_51_2026-10-06.json` 등.
- Studio: `docs/art/verification_2026-10-07/studio_round_evening/`(pc·phone·edit), 편집 화면 한글 검사 `place_english_studio_2026-10-07.json`.

## 7. 하다 만 것
- 없음. 코드는 모두 origin/main(713fd05까지)이고 메인 Studio와 0/0, place는 ce27afa로 올림. 오프라인 시험 전부 통과(마지막 묶음 기록은 `docs/art/verification_2026-10-0{6,7}/offline_*.json`).
- 메인 Studio 창은 최소화된 채(편집 모드), 기기 흉내 PC(default), 내 시험 Play는 모두 멈춤.
