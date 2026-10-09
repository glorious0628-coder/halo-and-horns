# 초반 이탈 막기: 바깥 근거 (2026-10-07)

> 기록용(10/07 당시, 결정은 A23-68). 지금과 다른 점: TOP 8 #1 '수락하면 바로 초원'은 없앰 — 무기 먼저, 대장간까지 걸어가고 순간이동은 퀘스트로 배움(A23-74·A23-88); 스킬은 Lv5부터라 첫 처치 뒤 Q 힌트 없음(A23-71); 첫 무기는 전투력 숫자가 오르는 연출(A23-68 #3). 지금 기준: AGENTS.md · SPEC_ADDENDUM A23 · RELEASE_PLAN.

> 코드와 문서를 읽고만 정리했어요. 파일 수정, 커밋, Studio 작업은 하지 않았어요. 크레딧 0.
> 대괄호 숫자는 맨 아래 출처 번호예요. [중간]·[약함]은 2차 자료이거나 근거가 약하다는 뜻이에요.

## 0. 한 줄 결론
- 가장 위험한 곳은 **처음 3분**이에요. 오프닝, 진영, 직업, 안내자 대화, 이동을 다 지나야 첫 슬라임을 쳐요.
- 코드로 계산하면 첫 타격까지 약 1.5~2분이에요. Roblox 추천이 감점하는 60초·180초 구간에 걸려요[1]. 실제로 잰 값은 아니에요.
- 그래서 새 시스템보다 먼저 할 것이 있어요. **첫 타격까지 줄이기, 그 자리 힌트, 첫 무기 순간, 단계별 기록**이에요.

## 1. 아이들이 초반에 나가는 이유 6개 (바깥 근거)
1. **재미까지 오래 걸려요.**
   - Roblox 추천은 60초 안, 61~180초 안에 나간 사람을 감점해요[1].
   - 첫 경험은 5분 안에 끝나고, 5분 안에 재밌어야 해요[3][4].
   - 첫 세션이 0~3분인 게임은 다음 날 돌아오는 비율이 약 4%(중간값)예요. 19~24분인 게임은 약 11.5%예요. 다만 상관관계일 뿐이에요[13 중간].
2. **다음에 뭘 할지 몰라요.**
   - 헷갈리는 한 단계에서 새 플레이어 약 70%가 빠진 예가 있어요. 고친 방법은 화분 위 아이콘 하나였어요[6].
   - Roblox 스태프 조언: "할 일을 알기 쉽게, 초반 걸림돌은 빼고, 계속할 이유를 줘라"[2].
3. **글로 가르쳐요.**
   - 아이들은 긴 설명을 건너뛰어요[15 중간].
   - 간단한 게임에서는 앞에 몰아 둔 튜토리얼이 효과가 없었어요. 필요한 순간에 주는 힌트만 효과가 있었어요(4.5만 명 실험)[14].
   - Roblox도 글 대신 하이라이트, 화살표, 시간이 지나면 뜨는 힌트를 권해요[5].
4. **초반 실패가 아프거나 지루해요.**
   - 아이가 화내는 큰 원인은 중요한 순간의 죽음·패배, 그리고 버그·랙이에요[16 중간].
   - "나무 하나 부수는 데 너무 오래 걸린다"가 30초 이탈 이유로 지목된 사례도 있어요[17 약함].
5. **폰에서 불편하거나 무거워요.**
   - 대부분 폰으로 하고, 걸림돌과 로딩에 민감해요[7].
   - 기본 조이스틱·점프 자리에 버튼을 두면 안 돼요[8].
   - 첫 60초는 로딩에 쓰이고, 안드로이드는 메모리가 차면 튕겨요[9].
6. **혼자이고, 다시 올 이유가 안 보여요.**
   - 혼자 하는 게임은 사람을 붙잡기 어려워요[7].
   - 친구와 같이 노는 날이 추천 신호예요. 초대 창을 쓰면 초대가 6~8배 늘어요[1][11].
   - 13세 미만은 채팅이 막히고 알림도 못 받아요[12][10]. 그래서 돌아올 이유는 게임 안에서 보여야 해요.
   - 추천은 이제 28일 동안 다시 오는지를 봐요[2].

## 2. 우리 게임에서 그 위험이 보이는 곳
관찰은 코드·실측·사진으로 확인한 것이고, 추측은 계산이나 짐작이라 직접 재 봐야 해요.

| 이유 | 어디 | 무엇 | 구분 |
|---|---|---|---|
| 1 | `Intro.luau` `run()` | 오프닝 약 22초(1.5초 뒤부터 넘기기 가능) | 관찰(코드 시간 합) |
| 1 | FactionPicker → ClassPicker → `Config.Tutorial.Welcome`(4줄) → `Text.Travel` "Menu > Travel > Squishy Meadow" | 첫 슬라임 전에 화면 4개를 지나고 이동해야 해요. 마을 스폰(z ±410)에서 초원 스폰(x 220)까지 약 465스터드(걷는 속도 20) | 관찰 |
| 1 | 위 단계를 합친 시간 | 첫 타격까지 약 1.5~2분 | 추측(계산). F10-E2E는 10/05 변경 뒤로 다시 재지 않았어요(`beta_board_2026-10-06.md:303`) |
| 2 | `beta_board:303`, `quality_ideas:17` | 첫 보상 뒤 대장간까지 262초. 지도 v2로 더 멀어졌어요. 'Go! ▶'는 아직 코드에 없어요 | 관찰 |
| 4 | `PlayerService.luau:432-433` | 쓰러지면 늘 집 마을에서 다시 태어나요. 첫 임무 중이면 초원까지 다시 가야 해요 | 관찰(아이에게 주는 영향은 추측) |
| 4 | `Config.Combat.Unarmed`(:463), `StoryQuests.Defs.S0`(:1949) | 맨손 펀치로 슬라임 하나에 약 5대 → 첫 임무에 약 25번 눌러요. S0 왕 슬라임(HP 40)은 약 20번이에요. 맨손일 때 직업 느낌은 Q 스킬뿐이에요 | 숫자는 관찰, 지루함은 추측. 맨손 시작은 사용자 결정(A23-34) |
| 2·3 | S0 `Requires = { ClassChosen = true }` | 직업을 고르자마자 첫 임무와 "Beat a King Slime"이 같이 떠요 | 관찰(헷갈림은 추측) |
| 2·3 | `ideas_ui_2026-10-07.md` §1 | 할 일 글자가 잘려요('Fre… 1/5'). 이벤트 알림이 창을 가려요. 막힌 버튼이 왜 안 되는지 말하지 않아요 | 관찰(사진) |
| 3 | `HUD.luau`·`SkillBar.luau`, `QuestTarget.luau` 머리말 | 공격·스킬을 그 순간 알려 주는 힌트 코드가 없어요. 초원 안에서는 목표 표시가 꺼져서 슬라임 위에 표시가 없어요 | 관찰 |
| 4 | `LootService.luau:304-319` | 맨손에서 첫 무기로 바뀌는 순간이 가장 큰 성장인데, 알림 한 줄(전투력 A → B)뿐이에요 | 관찰 |
| 2 | `TelemetryService.luau:5-6` | 단계별 기록(퍼널)은 8단계가 있어요. 그런데 수락(5)과 첫 임무 끝(6) 사이에 초원 도착·첫 처치가 없어서 가장 위험한 구간이 안 보여요 | 관찰 |
| 5 | `verification_2026-10-07/picker_view_2026-10-07.json` | 폰(749×361)에서 진영 카드 글자가 11~12px이에요 | 관찰 |
| 5 | beta_board PERF-1 | 폰 성능 검사를 아직 안 했어요. Tripo 소품은 계속 늘어요 | 관찰(튕김 위험은 추측) |
| 6 | 코드에 `PromptGameInvite` 없음, BB25 | 친구 초대 기능이 없어요 | 관찰 |
| 6 | beta_board BB32 | 출석 달력 계획에 'Streak'(연속) 칸이 있어요 | 관찰(끊기면 리셋되는 방식이면 위험) |

**이미 좋은 것 (지켜요)**
- Lv2가 슬라임 3마리면 와요(첫 레벨 필요 XP 15, 슬라임 5XP)[3].
- 첫 임무 보상 150골드, 오프닝 넘기기 버튼이 있어요.
- 같이 때린 몬스터는 때린 사람 모두에게 처치로 쳐 줘요(`MonsterService` `killRecord`).
- 현상 별이 없으면 몬스터에게 쓰러져도 골드를 안 잃어요(`PvPService:554`).
- 새싹 보호막이 있어요.
- 휴가 보너스: 못 들어온 날을 ×0.7로 최대 3일까지 채워 줘요.

## 3. 덧붙이면 좋은 것 TOP 8

| # | 이름 | 한 줄 | 왜 (출처) | 날 | 담당 | 언제 |
|---|---|---|---|---|---|---|
| 1 | **수락하면 바로 초원** | 안내자 [Accept]를 누르면 3초 뒤 초원 입구에 내려요. 첫 임무 동안은 쓰러져도 초원 입구에서 다시 시작해요. 마을에 개인 몬스터를 두지 않는다는 10/04 결정은 그대로예요 | 60초·180초 이탈 감점[1]. 첫 경험 5분 이하[4]. 퀘스트 주는 곳 바로 옆에 약한 적(블록스 프루츠)[19 중간]. 실패 뒤 빨리 돌아오게[16 중간] | 1.25 (품질 ④ 'Go!' 1.0은 이미 계획 + 부활 위치 0.25) | 개발 2(이동·부활) + 개발 1(버튼) | 베타-지금 |
| 2 | **첫 3분 기록 다시 짜기** | 기록 8단계 사이에 '초원 도착·첫 타격·첫 처치·대장간 도착·첫 스킬 명중'을 넣어요. 공개 전이라 지금 번호를 다시 매겨도 잃을 기록이 거의 없어요 | 한 단계에서 70% 이탈한 예[6]. 이 기록은 서버에서, 게시된 게임에서만 쌓여요[6]. 하루 100명 전에는 비교표가 없어서 우리 기록이 유일한 기준이에요[1] | 0.25 | 개발 2 | 베타-지금 (10/24 전에 넣어야 베타 기록이 생겨요) |
| 3 | **그 자리 힌트** | 슬라임이 닿는 거리에 왔는데 5초 동안 안 때리면 공격 버튼이 흔들리며 "Tap to hit!"이 떠요. 첫 처치 뒤에는 Q 버튼이 빛나며 "Try your skill!"이 떠요. 초원 안에서 가장 가까운 슬라임 위에 작은 표시를 띄워요 | 하이라이트·화살표·늦게 뜨는 힌트[5]. 필요한 순간의 힌트만 효과가 있었어요[14]. 'Tap', 'Hit' 같은 쉬운 말[15 중간]. 맨손이어도 Q는 직업 스킬이라 직업 느낌이 일찍 나요 | 0.6 | 개발 1 0.35 + 이미지 개발 0.25 (있는 빛 테와 목표 표시를 다시 써서 새 그림 0) | 베타-지금 |
| 4 | **첫 무기 '팡!'** | 대장간에서 첫 무기를 받는 순간 한 번만 반짝이, 소리, 큰 글 "Stronger!"와 '슬라임 N대 → M대'를 보여 줘요(숫자는 `Config.SwingHitsToKill`로 계산) | 온보딩 끝에는 일부러 만든 기쁜 순간이 있어야 해요[3]. 첫 루프를 마치면 기쁨을 줘요[4]. 지금은 가장 큰 성장이 알림 한 줄뿐이에요 | 0.5 | 개발 1 0.35(연출·소리 연결) + 개발 2 0.15(소리 파일) | 베타-지금 |
| 5 | **한 번에 목표 하나** | 첫 [Claim] 전에는 S0 줄을 접어요(퀘스트는 그대로 받아 둬요). 왕관·점수·이벤트 칸과 큰 이벤트 알림은 그 뒤로 미뤄요. 품질 ⑨ 새싹 HUD를 넓히는 것이에요 | 작은 화면은 금방 꽉 차서 상황에 맞는 UI만 보여야 해요[8]. UI는 조금씩 보여 주기[17 약함]. 목표는 아이콘과 '지금/목표'를 같이[15 중간] | 0.35 (⑨ 0.2는 이미 계획 + 0.15) | 이미지 개발 + 개발 2 | 베타-지금. 자동 전투 퀘스트를 진영 직후 받는다는 사용자 결정은 그대로 두고 줄만 접어요. 검수 확인 필요 |
| 6 | **친구 초대 + 친구 옆에서 시작** | BB25 초대 버튼을 만들고, 첫 [Claim] 뒤 한 번만 "Play with a friend!"를 띄워요. 초대받은 친구는 초대한 아이가 있는 안전 지역에서 시작해요. 보상은 없거나 1번만, 상한을 둬요 | 초대 창을 쓰면 초대 6~8배, 초대받은 사람을 친구 옆에[11]. 함께 노는 날이 추천 신호[1]. 채팅 없이 되는 협동[12]. 보상은 1번·상한[21] | 0.75 (BB25 0.5 + 옆 스폰 0.25) | 개발 1 + 개발 2 | 베타-여유 (초대 창은 실기기 확인 필요) |
| 7 | **'쉬어도 돼요' 카드** | 1장 끝(M1_4 보고)처럼 이야기가 끝맺는 곳에서 차분한 카드를 띄워요. "Saved!" + 다음 목표 한 줄 + 같은 크기의 [Keep playing]·[OK] | 끝맺음이 있어야 아이가 편히 나가요[24 중간]. 쉬라는 넛지는 권장, 더 놀게 하는 넛지는 금지[23]. 13세 미만은 알림이 없으니 다음 이유를 게임 안에 둬요[10] | 0.4 | 개발 1 + 검수(문구) | 베타-여유 |
| 8 | **돌아오면 반겨 주기** | 다시 들어오면 "Welcome back! Next: …" 한 줄을 띄우고, 휴가 보너스는 그대로 둬요. BB32 출석은 '연속' 대신 '모은 날 수'로 해서 빠져도 잃지 않게 해요 | 같은 숫자라도 보너스는 좋아하고 벌칙은 싫어해요(WoW 휴식 경험치)[22 중간]. 끊기면 리셋되는 연속은 잃을까 봐 조급하게 만들어요[22 중간]. 24시간 지나면 사라지는 일일 퀘스트는 아이용으로 바꿔야 해요(추론)[18]. 28일 동안 다시 오는지가 추천에 중요해요[2] | 0.25 (한 줄) · BB32는 원래대로 정식 | 개발 2 + 개발 1 | 한 줄은 베타-여유, 출석은 정식 |

- **베타-지금 5개:** 새로 드는 일은 약 1.75일이에요(개발 1 약 0.7, 개발 2 약 0.75, 이미지 개발 약 0.3). 이미 계획된 ④·⑨ 1.2일은 따로예요. 10/12 점검에서 넣어 보고, 밀리면 #5 → #4 순서로 미뤄요. #1~#3은 끝까지 지켜요.
- **TOP 8 밖이지만 꼭 할 것:**
  - PERF-1(폰 첫 1분 메모리·FPS)을 베타 필수로 올려요[9].
  - F10-E2E를 첫 타격 시각까지 포함해 다시 재요.
  - 게시 뒤에는 Roblox의 'New User First Session Retention' 그래프로 몇 분째에 나가는지 봐요[4].
- **맨손 펀치 수(첫 임무 약 25번):** 사용자 결정(A23-34)이라 그대로 둬요. F10-E2E에서 지루하다고 나오면 숫자만 검수를 거쳐 사용자에게 물어요.

## 4. 하지 말 것 5개 (다른 게임의 나쁜 패턴)
1. **끊기면 0이 되는 연속 출석, "오늘 안 오면 잃어요"**
   - Adopt Me의 30일 출석은 하루 빠지면 숫자가 줄어요[22 중간].
   - 아이가 더 오래 놀게 하는 넛지는 금지예요[23].
   - 우리: BB32는 '모은 날 수'로 만들어요.
2. **카운트다운, 한정 시간 상점, 가짜 할인, 전체 재입고 타이머**
   - 시드니대가 매출 상위 15개 게임을 조사했더니 14개에 오해를 부르는 관행이 있었어요[25].
   - 네덜란드 당국(ACM)은 Epic에 가짜 24시간 타이머와 'Get it now' 문구로 112.5만 유로 벌금을 매겼어요[26].
   - Grow a Garden식 5분 전체 재입고도 같은 압박이에요[25].
   - 우리: 변경권 판매 창도 타이머와 'Buy now' 없이 만들어요. 게임 버튼과 떨어진 곳에서 따로 확인하게 해요[26].
3. **친구 수만큼 보상**
   - Grow a Garden은 서버 안 친구 한 명당 +10%를 줘요. 공략은 "서버 사람을 다 친구 추가하라"고 해요[29].
   - 아이에게 낯선 사람을 친구로 추가하라고 부추기는 셈이에요.
   - 우리: `idea_backlog.md:51`의 '친구와 함께하면 +10%'는 하지 않는 쪽을 권해요. 하려면 '내가 초대한 친구와 첫 퀘스트 1번, 초대한 사람당 3번까지'로 해요[21].
   - '함께 싸운 모험가 카드'의 친구 요청 버튼도 같은 이유로 다시 봐요.
4. **돈으로 사는 자동 공격·진행 패스, 운·강화 아이템 판매**
   - 자동 클릭 패스를 49 Robux에 파는 게임이 있어요[25].
   - Robux로 사는 강화·운 아이템은 Roblox 규칙상 '유료 확률 아이템'이라 확률을 꼭 보여 줘야 해요. PEGI는 이런 게임을 16세 이상으로 올려요[27].
   - 우리: 자동 전투는 지금처럼 퀘스트로 열고, 강화 주문서는 드롭으로만 얻게 해요.
5. **진 직후 사라고 권하기, "아깝다!" 아슬아슬 연출**
   - 시드니대 조사가 꼽은 압박 수법이에요[25].
   - 우리: 강화가 한 단계 떨어진 순간(TelemetryService가 이미 `LeftAfterEnhanceDrop`으로 기록해요)에는 상점이나 판매 창을 띄우지 않아요. 대신 주문서가 나오는 몬스터만 알려 줘요.

## 출처 (받은 조사 묶음)
1. Roblox Discovery 문서: https://create.roblox.com/docs/en-us/discovery.md
2. 28일 기준으로 바뀐 추천(2026-06), 스태프 조언(2026-08): devforum 4684575 · about.roblox.com/newsroom/2026/06 · devforum 4779042
3. Onboarding 문서: https://create.roblox.com/docs/production/game-design/onboarding
4. Retention·Engagement 문서: https://create.roblox.com/docs/en-us/production/analytics/retention.md · https://create.roblox.com/docs/production/analytics/engagement
5. Onboarding techniques: https://create.roblox.com/docs/en-us/production/game-design/onboarding-techniques.md
6. 퍼널 이벤트(스태프 예시, 문서): devforum 3064458 · https://create.roblox.com/docs/en-us/production/analytics/funnel-events.md
7. Design for Roblox: https://create.roblox.com/docs/en-us/production/game-design/design-for-roblox.md
8. 크로스플랫폼 UI, UI/UX: https://create.roblox.com/docs/ui/cross-platform-design · https://create.roblox.com/docs/en-us/production/game-design/ui-ux-design.md
9. 성능 대시보드: https://create.roblox.com/docs/en-us/production/analytics/performance.md
10. 게임 알림(13세 이상, 하루 1번): https://create.roblox.com/docs/en-us/production/promotion/experience-notifications
11. 초대 창(스태프, 2023): devforum 2170724
12. 연령 확인과 채팅 제한(2025-11), 1분기 주주서한: about.roblox.com/newsroom/2025/11 · SEC 8-K 2026-04-30
13. GameAnalytics 2025 Roblox 보고서 [중간]: https://www.gameanalytics.com/reports/2025-roblox-report
14. CHI 2012 튜토리얼 실험: https://grail.cs.washington.edu/projects/game-abtesting/chi2012/
15. NN/g 아이 UX [중간]: https://www.nngroup.com/articles/childrens-websites-usability-issues/ · https://www.nngroup.com/articles/kids-cognition/
16. Tampere Playlab(아이의 게임 분노), UXmatters [중간]: blogs.tuni.fi/playlab
17. DevForum 커뮤니티 글(Ancient Peaks, 30초 이탈) [약함]: 조사 묶음 top_games 4번에 인용
18. 퀘스트 디자인 문서: https://create.roblox.com/docs/en-us/production/game-design/introduction-to-quest-design.md
19. 블록스 프루츠 시작 섬 공략 [중간]: https://rblxguide.com/games/blox-fruits/islands/starter-island
21. 추천인 시스템 문서: https://create.roblox.com/docs/production/promotion/referral-system
22. WoW 휴식 경험치(GameBanshee), Adopt Me 연속 출석(allthings.how) [중간]: https://www.gamebanshee.com/qw9
23. 영국 ICO 아동 코드 13번(넛지): ico.org.uk … 13-nudge-techniques
24. 5Rights 'Disrupted Childhood', KIT 끝맺음 연구 [중간]: https://5rightsfoundation.com/in-action/disrupted-childhood-the-cost-of-persuasive-design-2023.html
25. 시드니대 Roblox 결제 관행 보고서(2026-05): https://www.sydney.edu.au/news-opinion/news/2026/05/17/inside-the-pay-to-play-world-of-roblox-targeting-children-.html
26. ACM의 Epic 벌금(CMS 요약), 미국 FTC 합의: https://cms.law/en/nld/legal-updates/acm-fines-epic-games-after-ruling-fortnite-encouraged-children-to-buy
27. 유료 확률 아이템 규칙, PEGI 2026: https://create.roblox.com/docs/en-us/production/monetization/paid-random-items
29. Grow a Garden(Fortune 기사, 친구 보너스 공략) [중간]: https://fortune.com/2025/07/30/roblox-video-game-grow-a-garden-viral-summer-hit/