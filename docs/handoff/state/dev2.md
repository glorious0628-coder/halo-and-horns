# 게임성 개발 2 — 상태 (2026-10-14 늦은 밤, 가방 칸·장인 ①·큐 ①~④·무기 상점)

## 지금 (10/14 늦은 밤) — 모두 push, 최종 검수 병합 대기
| 가지 | tip | 무엇 | 시험 |
|---|---|---|---|
| dev2-artisan-sell | 828f3bed | 장인 ①: 채집 재료 판매 SellItem(상점 근처, 골드 "Sale") + 길드 일일 Gather/Craft(Neutral, 스위치 따라) | loot 666/142, a23_14 329, gamepass 232/116. main 합친 트리 = 원래 실패만 |
| dev2-bag-slots | 0418d411 | 가방 칸 12→16→20(BagSlots 저장·속성, Lunch1·M2_7 +4, 접속·장 건너뛰기 따라잡기), 새 종류만 칸 검사, 제작·거래소도 빈 칸 확인. 개발 1 표 d417e164 + main 합침 | loot 654/144, market 179/87, craft 189/118, town_quests 1043/248 |
| dev2-bag-reward | 4425b0fb | bag-slots 위: 퀘스트·이야기 보상은 가득 차도 들어감(GrantItem source "Reward") | loot 658, town_quests 1044, 새 변이 3 |
| dev2-sub-retry | 6dd30322 | 큐 ①: 구독 확인 3번 재시도 + 마지막 답 PassSeen["Sub:<key>"] | gamepass 255/130 |
| dev2-fund-ladder | 535cc107 | 큐 ②: 마을 기금 200 → 500 → 1,000(FundGiven으로 셈) | village_fund 127/52 |
| dev2-no-ticket | 1a497ec9 | 큐 ③: Robux 바꾸기 티켓 판매 삭제(ProcessReceipt 등), 게임 안 티켓은 그대로 | gamepass 248/126, notify_sound 70/61 |
| dev2-weapon-shop | (시험 중) | A23-186: Buy = true, 밈 무기 T10 Frying Pan·T11 Rubber Chicken(Meme, AnyClass, 15, 300골드), 세이브 v6, WeaponAtLeast(철 무기 판정), 맞힘 Fx Meme 키 + 팬 밀침 +1.5, 거래소·팩 제외 | 전체 sweep·변이 도는 중 |
- 큐 ④ 확인: N0·N0b는 main에 없음(장인 ②에서 Neutral 전용 Requires TutorialDone으로). 중립 Lv1~5 줄은 1장 메인 + S0·Lunch1·Pet1·S4로 비지 않음.
- 최종 검수에게 물은 것: 출석·게시판·필드 보스·피니셔·분실물·ChoiceCard 보상도 "Reward"(칸 무시)로 할지.
- 다음(최종 검수 큐 순서): 무기 상점 보고 → 장인 ②(목표 Gather·Craft·SellMat + N0/N0b/N4, W2 레시피 채집 재료만) → ③ 거래소 끄기 키·죽이기 시험 → ④ 작업대 3개 → ⑤ 연금 소모품 → ⑥ Gear 켜기 → ⑦ 끄기 키 묶음.
- worktree: ../wt_artisan, ../wt_bag(dev2-bag-reward), ../wt_subretry, ../wt_fundl, ../wt_ticket, ../wt_wshop, ../wt_tmpm(합친 트리 시험용, 지워도 됨).
- 스크래치 도구: sweep.py(전체 시험), only_mut.py(`<wt> <test.py> "이름|이름"` 변이 몇 개만).


## 지금 (10/14 저녁)
| 가지 | tip | 무엇 | 어디까지 |
|---|---|---|---|
| dev2-weapon-luck | ba755029 | 2-A ⑤ 무기 운(첫 브루트 T4·첫 기사/Clatter T5·운 카운터·숲 서브 GW9·GW10) + 변이 고침(황금 배수 줄 겹침, 새 변이 8) | **main 병합됨(d05f09c8)**. loot 630 / 134·commission 77 / 46·town_quests 1036 / 241 |
| dev2-launch-dates | 8b04abec | 2-A ⑦ 날짜 값(PioneerUntil 2100, 스위치 PioneerTitle, 배지 7개) + WIP 마무리(시험 3개 고침) | 최종 검수 병합 진행. return 245 / 121·beta_basics 232 / 35 |
| dev2-village-fund | e30da8fa | A23-178 B 마을 기금 서버(VillageFundService, 계약 `docs/design/village_fund_server_2026-10-14.md`), launch-dates 합침 위. Net 이름 FundGive·FundOpen + GameState 기본값 = 이 가지(개발 1 dev1-village-fund 864cf867은 Net 안 건드림) | 반박 검토 FIX 1 + MINOR 2 고침 보고함(분수 모델 `Town_Halo_Fountain3` 피벗 = 자리, 대체 Pos (34.55, 20, -566); 닫힐 때 도는 쓰기 기다림; 첫 읽기 성공 전 단계 글 없음). test_village_fund 114 / 46. 개척자 스위치 병합 뒤 main 합침(스위치 줄 둘 다), 전체 197 = 원래 실패만. **main 병합됨(e35d32b9)** |
| dev2-stats3 | f1aeeb48 | 2-A ⑧ 스탯 2단계를 main 위로(옛 dev2-stats2 91a7dd8d, 리베이스 없음) + 장비 배수와 곱하기 + CombatPowerOf 레벨·스탯 덮어쓰기 + main 합침 1번. 스위치 꺼짐 | 보고함. stat_service 70 / 37·stats 77 / 46·gear_slots 203 / 109. main 합친 뒤 전체 196개 = 원래 실패 8개만(costume_physics·halloween·metrics_board·place_english·rank_marks·skeleton_ground·skin_binding_studio·walk_forge_client) |
| dev2-gold-sinks | 8f53be76 | 2-A ⑥ 안 → 사용자 A23-178: 마을 기금(B)만, 주문서 구매(A) 안 함(소모품 = 연금술사) | 끝 |
| fix/pioneer-switch-ready | cd7e3331 | launch-dates 2차 검토 FIX: 스위치 정의 `Unread`(첫 읽기 성공 전 값), PioneerTitle Unread = false + `SwitchService.HasRead()`; TitleService가 Changed(켬) 때 접속 중인 아이에게 다시 줌 | **main 병합됨(0783dbbd)** |
| dev2-stale-text | 6637e536 | 2-C #12 낡은 글(S): 장인 길드 베타 포함(A23-162)·자동 번역 켬(A23-179)에 맞춰 Config 10곳(화면 글 3: Legend 출처, 장인 카드 'Crafting') + 서버 로그 2곳 | 보고함. 전체 = 원래 실패만. 개발 1 몫 4개 넘김(설정 Lang 줄, FactionPicker 직접 쓴 글, 제단 AutoLocalize, TextKo/L10n 잔재) |
| fix/skill-no-reject | 5bd777c5 | 사용자 10/14 '서버가 거절을 안 하게': 대상 없음 = 허공 쓰기(Fx Air, MP·재사용·간격·피해·셈 없음), 재사용 ≤ PressBuffer 0.35초 = Queued, 나머지 조용히 false, SkillPress = Queued만 | 보고함. skills 162 / 100, skills_x 167 / 93, 전체 196 = 원래 실패만 |
- 스탯 가지(stats3)는 '큰 병합 하루 하나' 규칙으로 10/15 검토.
- **장인 길드 최소판(사용자 10/14 '중립 애들 작업도', 2-B 11/06 판정 취소):** 계약 `docs/design/artisan_min_server_2026-10-14.md` 보고함 → 최종 검수 OK 기다림. OK 뒤 순서: ① SellItem(채집 재료 판매)+일일 채집·제작 2줄+N1/N2 막힘 고침 → ② 퀘스트 목표 Gather·Craft·SellMat + N0/N0b/N4 → ③ 거래소 dev2-market main 합치기+끄기 키+죽이기 시험+UnpackSpare → ④ 작업대 3개 → 스위치 켜기 시험. 최종 검수 OK(결정: W1 레시피 뺌·첫 제작 = 채집 재료만의 W2·N0 끝 150골드 + 자동 장착, 장인 마을 2단계는 빛→뿔→장인 순서 때).
  - 진행: **dev2-market** = ../wt_market, main 합침 6495d64e(로컬, push 전; market 161 / 72/72, 전체 시험 도는 중) → push·보고.
  - **dev2-artisan-sell**(① 판매 SellItem + 일일 Gather/Craft + N1/N2 주석) = ../wt_artisan, 커밋 전(loot 666, a23_14 329 통과; 변이 고침 2개 뒤 다시).
  - 그 뒤 대기열(최종 검수 10/14 밤): A23-181 같이 잡은 몹 사냥 명예·처치 수 = 첫 타격자 한 명(MonsterService 첫 타격 기록 없음 → 추가, S) → A23-182 Travel 원격 = 새 패스 FastTravel(149 R$, ID 0) 전용·발판은 무료(S) → 장인 ②~④ → ⑤ 연금 소모품 ⑥ Gear 켜기 ⑦ 새 기능 끄기 키 묶음. 운영 메모(나중): Env.Names Beta/Live, 배지 7 ID, TestServer 되돌리기.
- worktree: ../wt_wluck, ../wt_dates, ../wt_vfund, ../wt_stats3, ../wt_pioneer, ../wt_stale, ../wt_skill (+ 옛 것). 시험 실행기는 스크래치 sweep.py(세션마다 다시 만듦: `<wt> <out> [--jobs N] [--mut] [이름…]`).
- **다음:** 10/15 패스 ID 9개 오면 그것 먼저 = origin/main 위 새 가지 dev2-pass-ids-2(9b90130c는 main에 있음)에 `py tools/set_pass_ids.py …` 커밋 1개 → test_gamepass(변이)·passes·pass_text·shop_layout·health → 보고. 그 밖엔 최종 검수가 정함.
- 주의: worktree에서 git이 쓴 파일(merge·checkout·apply)은 CRLF가 될 수 있음 → first_ko_king 'LF tabs' 정적 검사가 잡음. 커밋 전 바꾼 파일 LF 확인.
- 숲 서브 GW9·GW10은 영·한 대본(`docs/script/`)에 아직 없음 → ⑬ 때.

서버 전용·Studio 금지·main에 코드 push 금지(최종 검수가 병합). 보고처 = '최종 검수'(list_sessions, send_message). 덩어리마다 한 번.
읽는 순서: `docs/handoff/README.md`(새 입구) → `role_prompts/03_dev2.md` → 이 파일 → `docs/design/six_week_plan_2026-10-13.md`(주별 몫).

## 가지 (모두 push, 최종 검수 병합 대기·진행)
| 가지 | tip | 무엇 | 상태 |
|---|---|---|---|
| fix/test-prep-server | e43370e2 | 1-A 서버 몫 + 시험 스위치 | main 병합됨 |
| fix/test-prep-server-2 | bd50ad74 | 시험 숫자판(TestMetricsService, tools/test_metrics_board.py), set_pass_ids, 검토 고침 3개 + main 합침(bag_ui = 개발 1 판) | 검토 MERGE, 병합 중 |
| fix/mischief-name | 61d7c162 | A23-166 보이는 Infamy → Mischief(Config.FameName/FameLabel) + 검토 MINOR 3개(숫자판 Live 끔, Kept = Roblox 실제 답만 = MonetizationService.PassAnswer·'Unknown', 주문서 칸 가득 차면 표시 유지) | 보고함 |
| fix/scroll-toast-off | 696088cf | 첫 Slime Prince 주문서 안내 토스트 삭제(A23-130, Loot.Text.FirstScroll* 키 삭제) | 보고함 |
| dev2-honor-crown | 555e1a56 | 2-A #4 HuntFameService + #5 왕관 새 점수(WarService.AddKill/PersonalAdded) — mischief 위. 검토 FIX FIRST 고침: 처치 수 저장(data.CrownUnits), M2_1 15·GW4 100마리, KO 상한 UserId, PvP 정수, 점수 두 자리(HUD 한 줄), ZoneLevel, Minor 제외 | 고침 보고함. 설명 `docs/design/honor_crown_server_2026-10-14.md` |
| dev2-early-xp | 36396af8 (main 9264ae44) | A23-167 첫 10분 2배 XP(Config.EarlyXP, ProgressionService.XPBoost = 패스와 큰 쪽) + 내일 또 오기 서버(Fx TomorrowGift, 속성 Returned, WelcomeBack Days·News, AttendanceService.NextSlots, 소식 DataStore HaloHorns_News_v1) — origin/main 4f88cc5a 위 | 보고함. 설명 `docs/design/comeback_server_2026-10-14.md`. 화면은 개발 1 몫(문서 끝 4줄) |
| dev2-early-xp-2 | 20569434 | early-xp 후속: 빈 거위 판(Mode Pending) 소식 안 셈, BindToClose가 도는 쓰기 기다린 뒤 씀, crown-small 체리픽, NextSlots·Config TomorrowDay 주석 — origin/main 5e157bf7 위, ../wt_earlyxp2 | 보고함(return 244·121/121) |
| dev2-crown-small | 53e28b6a | API 사후 검토 낮음 2개: PvP KO 상한 칸은 AddPoints가 실제로 더했을 때만(AddPoints true/false), PersonalAdded 주석 — origin/main 893d8d37 위 | main 병합됨(10/14). early-xp-2의 체리픽 890994fe = 같은 내용 |
| dev2-metrics-howto | 078a0a3a | 시험 숫자판 점검: 매일 한 줄 안내 `docs/design/test_metrics_howto_2026-10-14.md` + board stderr UTF-8 — origin/main 89255e8b 위, ../wt_metrics | 최종 검수가 병합함(10/14) |
| dev2-pass-ids | 9b90130c (push함, ID 9개 모두 0) | test_gamepass가 진짜 패스 ID에서도 통과(세계마다 ID 0으로 시작, 설정 확인 '0 또는 정수>0·겹침 없음', 가격 변이 3개 ID 무관) — ../wt_passids | 최종 검수 지시로 시험 고침만 먼저 push(10/14, 232/232·116/116 다시 확인) → 병합 대기. ID 9개는 그 위에 커밋 하나 |
| dev2-halo-stage6 | bd903c79 | 빛 마을 6단계 서버 | 2주 차 교체 날 병합(map_v2 2개 = 새 큰 지도 그림 기다림) |

- 날짜 박힌 값 목록(3주 차 '아주 먼 날짜 + 출시 날 스위치', 2-A #12): BuildLabel, Beta.PioneerUntil 12/19, 하늘 주석 '12/19 launch',
  Halloween EndsAt 11/09·Banter DayOneStart 10/31, Badges Order Halloween2026, 할로윈 주석 'beta 2026-12-01', 글 "launch date is set in December".
- **내일 이어갈 자리(10/14 낮):** 네 가지 다 main(early-xp-2 포함). 오늘 1·2 끝: dev2-metrics-howto push·보고, dev2-pass-ids 로컬 커밋.
  10/15 패스 ID 오면: ../wt_passids에서 `py tools/set_pass_ids.py XP2=… Gold2=… VIP=… Stickers=… Bubbles=… HaloIce=… HaloGold=… HornsLava=… HornsShadow=…`
  (9b90130c가 main에 병합됐으면 먼저 `git merge origin/main`, 리베이스 금지) → test_gamepass(변이 포함)·passes·pass_text·shop_layout·health 다시 → `git checkout -- docs/art/` → 커밋(-- Config.luau) → push → 최종 검수 보고.
  (10/14 확인: 가짜 ID 9개로 관련 시험 15개 통과. 9b90130c는 10/14 push함.) 주간 사용량 73% → 새 일 시작 안 함.
- **다음 일:** 최종 검수가 정함. dev2-early-xp 병합됨, 후속 dev2-early-xp-2(20569434) 보고함 → 병합 기다림(고칠 것이 오면 그 가지 위에 커밋, 리베이스 금지).
  dev2-honor-crown 555e1a56 = main 병합됨(4fe62394). 같이 잡은 몹 사냥 명예 나누기 = 11/7 전 사용자 결정(backlog, 지금 그대로).
  2배 XP 속도: 계산상 Lv10이 슬라임만 약 16분 → 약 8분(퀘스트 보상도 2배) — 10/17 숫자판 'Lv5까지 분'으로 확인, 빠르면 최종 검수가 EarlyMult/Seconds 결정.
- 그 뒤 후보(최종 검수가 정함): 6단계 서버 병합, 무기 운 보정(2-A #6), 골드 쓸 곳(#7), 스탯 서버(#9), 날짜 값(#12), 보스 경쟁·황금 시간(crown_war_content).
- A23-168: 덩어리 보고 뒤 기다릴 일만 남으면 이 파일 적고 push → clear_session("self").

## worktree·도구
- ../wt_prep(test-prep-server-2), ../wt_prep_t(전체 시험 고정판), ../wt_mischief, ../wt_scroll, ../wt_honor, ../wt_halo6, ../wt_earlyxp, ../wt_crownsmall, ../wt_base1014(4f88cc5a 비교용). 병합 끝난 것은 그냥 둠.
- 가벼운 worktree: Game에서 `git worktree add --no-checkout -b <가지> ../wt_<이름> origin/main` → `MSYS_NO_PATHCONV=1 git sparse-checkout set
  --no-cone /src/ /tools/ /docs/ /AGENTS.md` → `git read-tree -mu HEAD` → `cp -r ../Game/build/luau_cli_0_741 build/`.
- 시험 실행기: 스크래치 run_tests.py(`<worktree> <outdir> [이름…]`, 하나씩; rc·CHECK_FAIL·failing·MISSED 요약). 스크래치는 세션마다 다시 만듦.
  시험 도는 worktree 파일은 고치지 말 것. 커밋 전 `git checkout -- docs/art/`(시험 보고서 되돌림).
- **Bash 도구는 `\n`·`\b`를 진짜 줄바꿈·백스페이스로 바꿈** → 백슬래시가 든 고침은 Edit 도구나 Write로 만든 py 파일로.
- 시험 상세에 플레이어 객체를 show()하면 스택 넘침 → 플레이어 뺀 복사본으로.
- 새 저장 칸·새 연결은 다른 시험 세계에서 경고가 나지 않게 '부드럽게' 찾기(PvP 훅처럼).
- 원래 실패(main): costume_physics(은퇴), halloween(그림 필요), ops_safety 변이 'Halloween is not applied', place_english, rank_marks,
  skeleton_ground, studio_guard 변이, skin_binding(_studio), quest_target(rows 2개), walk_forge_client, metrics_board(인자 필요 = 시험 아님).
- 전체 시험: 스크래치 sweep.py(`<worktree> <outdir> [이름…]`, 6개 동시, --no-mutations 되는 것만) → summary.txt. 10/14 새벽 192개 중 183 통과·9 = 위 원래 실패.
