# 게임성 개발 2 — 상태 (2026-10-16 밤: 큐 맨 위부터 순서대로)

## 큐 (최종 검수 순서 — 새 대화는 여기서 시작)
1. **2장 데이터 마무리** (worktree ../wt_rw, 가지 dev2-ch2-story, 아직 커밋 없음): 에이전트가 Shared/Quests/Halo_Ch2·Horns_Ch2·Artisan_Ch2.luau(M2_1~M2_6 진영판: Offer·Find·Lines·Scene·Next) + Config H1/R1/N3/N1/N2/N4 이야기 칸·새 제목(Birthday Ribbon / A Grand Birthday / Two Little Knots)·옛 Start/Finish/Clue 삭제를 씀(근거 build/codex/story_ch2_r1.md). 결정 = **본편·지선 모두 Offer 유지**(A23-199, 최종 검수 (a)). 남은 것: town_quests에서 옛 '자동 시작' 가정 31개를 '수락 먼저'로 고친 결과 확인(에이전트가 하던 중 — 결과 없으면 직접), Tiny 대명사 he, **단계 On = NPC id 허용**(tools/test_quest_data.py 271줄 'On must be Self' → 몸 있는 Story NPC id 허용 + 돌연변이 387줄 정리) 후 M2_3[2] 세 진영판에 Tiny peak 한 줄(§1 표: 빛 "Bright tied mine. I tied hers." / 뿔 "Bright kept my bad knot!" / 장인 "The box can wait. Her knot can stay." — 대명사 확인), **Clatter M2_4 장면 1회**(ClatterScenes Config.StoryQuests.Clatter.Scenes에 After = { Quest = "M2_4", Type = "EarnGold" }, Line "I'll carry my tools. You lead.", Move "Nod"; town_quests clatter 묶음에 1줄). 시험 quest_data·story_text·town_quests·story_npcs·quest_text → 커밋·push → 최종 검수 보고 + 개발 1(Panels BUILDERS.Story 진영판 Lines, On=NPC 재생).
2. **장인 길드 최소판 묶음**: A23-215 제작 곡선(build/codex/craft_curve_r1.md §2: 무기 W3~W9 재료·골드, CaptainBadge 0, DeepMoonShard·TrialCore 새 재료 = 아이템 정의 + 얻는 길, 방어구·반지·펫 T3, AS1), A23-217 장인 주간 선물(문턱은 최종 검수가 보냄), A23-219 제작 도구 강화(build/codex/craft_tools_r1.md, 옵션 크기 ×2, 강화 한 칸 역전·펫 이동 상한 검산). 큰 일 → 시작 전 계획 한 줄을 최종 검수에.
3. **A23-217 주간 진영 승부 서버**(build/codex/weekly_war_r1.md §5 — 저장·여러 서버 합산; 저장 구조 바뀌면 최종 검수에 미리).
- 병합 대기(게시 뒤 병합): dev2-scene-cmd bfd1d593, dev2-daily12 01038ecb, dev2-zone-lore 9a081f0e. 병합됨: otto-anvil f22d400b, offer-row cfab6038, welcome-accept, pvp-numbers, guide-flow-test.
- 규칙(사용자): 한 묶음 끝나면 push + tip 보고 + 이 파일 갱신 push → clear_session("self").

- **10/16 저녁 (최신)**: 병합됨(main): bound-free, reward-items, stale-muts, pvp-safe, kaiju-cross, calm-fade(+HIT_WAIT 0.7), clatter-guide(A23-212 ①②③④ + ClatterScenes.luau). 보고·병합 대기: **dev2-scene-cmd 5fd73a18**(A23-218② SceneSetup.luau + tools/scene.py, 프리셋 11), **dev2-daily12 01038ecb**(main 합침 + A23-215 묶음 12 + 칭호 RecordKeeper), **dev2-guide-flow-test a8354007**(🔴 할리 건: 서버 경로 정상, onboarding 몸 흐름 시험 872), **dev2-pvp-numbers 6af55828**(A23-216 숫자 + 괴수 발구르기 붉은 구역만). 다음 큐(최종 검수 순서): ① **2장 데이터** = build/codex/story_ch2_r1.md §2(M2_1~M2_6 진영별 이야기 칸)·§3(H1 "Birthday Ribbon"/R1 "A Grand Birthday"/N3 "Two Little Knots" 등 생일 지선, 지금 Config 목표·단계 그대로 이야기 칸만)·§6(전투 몬스터 사정 한 줄) + 단계 On = NPC id 허용(test_quest_data; M2_3[2] Tiny 한 줄+몸짓) + Clatter M2_4 장면 1회(ClatterScenes After) ② 장인 길드 최소판 묶음: A23-213(끝)·A23-215 제작 곡선(build/codex/craft_curve_r1.md §2, DeepMoonShard·TrialCore)·A23-217 장인 주간 선물·A23-219 제작 도구 강화(craft_tools_r1.md, 옵션 ×2 검산) ③ A23-217 주간 진영 승부 서버(build/codex/weekly_war_r1.md §5, 저장 바뀌면 최종 검수에 미리). 주의: MonsterService에 신호 더하면 first_ko_king 픽스처도(최종 검수가 Moment 추가 e573fee7). 시험 실행: 각 worktree build/luau_cli_0_741/에 luau 복사해 둠(--luau 없이 돌아감).

- **10/16 낮 (최신)**: 보고한 가지(최종 검수 병합 판단): dev2-bound-craft c89303ec(병합됨) → **dev2-bound-free 7a2cc27a**(A23-213: 귀속 재료 = 무기 포함 모든 제작 OK, 결과물 자유, 환불만 귀속), **dev2-reward-items 71541584**(④ Reward.Potion 실제 지급 + Reward.Items 여러 종류 + 미리보기 Icon; 개발 1 한 줄: Icon or Id), **dev2-stale-muts 61383c29**(③, reward-items 위; town_quests 349/349, tamer_research·gear_slots), dev2-pvp-safe 389e8503(병합됨, 붉은 구역 밖 PvP 0), **dev2-kaiju-cross 57f4646b**(A23-218 괴수 = 둘 다 교차로 또는 둘 다 붉은 구역), **dev2-daily12 03f21bee**(K 표 50/5·20/3·30/5·해골 50; 병합 보류 — 보상표 사용자 답 대기). 다음 순서: A23-212 Clatter(① 오프닝 1줄 ② 첫 10분 장면 3 + 마을용 Clatter 몸 ③ 상대 진영 비난 줄 삭제 ④ 보스 시작/승리 대사, 근거 build/codex/story_world_r5.md) → 개발 1 부탁 A23-211 서버 몫(MonsterService deathPop: 파티클·축소 삭제, CalmTime SlimeKing 1.8·CaptainClatter 2.2) → 장인 길드 최소판(계획 순서 3번). A23-216 숫자는 내 몫인지 최종 검수에 물음. 도구: Luau = C:/Users/glori/Tools/luau-0.740 (시험에 --luau), 새 worktree wt_bound·wt_rw·wt_daily.

- **10/16 아침 (최신)**: 아래 1·2 끝 → **dev2-daily12 cf10e502**(53256460 위 1커밋) 최종 검수에 보냄. R 표 확정값, DH1·DR1 슬라임 6+표본 3, DN2·DC3 = 먼 곳 줍기(DN2Wood (640,80) ~610 studs, DC3Rests (1580,120) ~310 studs) + 그 물건 옆에서만 열리는 타이밍 3번(Obj.Spot), 소품 목록 고침. 시험: quest_data 통과, town_quests 1286/1286(돌연변이 324/327 = 옛 3개 그대로), story_text·quest_text·story_npcs 통과. CAPS에 개수 상한 없음(등급·골드만) 확인. 3번(장인 스위치)은 최종 검수 결정 기다림 — 장인 DN 3종 데이터 그대로.

## 내일 아침 할 일 (10/15 밤 정리, 최종 검수 지시) — 1·2 끝(10/16)
1. **매일 12종 수정**(가지 dev2-daily12 53256460 위에 커밋, ../wt_daily): 보상 = 최종 검수 수정 확정표(build/codex/daily_rewards_r1.md 반영) — DH2 HP Potion 1 · DH3 Oak Log 4 · DH1 Enh70 1 · DR3 MP Potion 1 · DR2 Jelly 10 · **DR1 Move70 1**(30% 아님) · DN3 Pet Treat 3 · DN1 Herb 10 · DN2 Glowcap 8 · DC1 Copper Ore 3 · DC2 Guard Tonic 2 · DC3 Moon Crystal 8, 골드 30/60/100/200은 **GoldN**(Gold는 사냥 단위라 틀림). 숫자는 Daily.luau 맨 위 R 표 한 곳. 난이도 상한(test_quest_data CAPS: Normal Item 개수 제한 없음? 확인) 맞는지 검사.
2. **Hard는 실제로 어렵게**: DH1·DR1(Hard) = Slime 6 + 표본 3(또는 Prince 포함), DN1(Normal)은 지금 크기(Slime 3 + 표본 2). DN2(Hard)·DC3(Challenge) 수리 = 3회 + 이동 거리 길게. 소품 목록 docs/design/daily_props_2026-10-15.md도 같이 고침(표본 3 등).
3. **제작 스위치 확인 결과(최종 검수에 이미 한 줄 보냄)**: Config.Features.Gathering·Crafting·Tonics·Research = false(빌드 스위치, Config 9879·9986·10155·10179), NeutralFaction = false → 베타 Live에서 꺼진 채. 장인 재료·간식·강장제 보상(Oak Log·Herb·Copper·Glowcap·Pet Treat·Guard Tonic)이 쓸모없음 + 장인 DN 3종은 Neutral 꺼져서 아무도 못 봄 → 최종 검수 답(켤지 / 보상 바꿀지) 따라 처리.
4. 소품·Pip 배치 목록 파일은 있음(docs/design/daily_props_2026-10-15.md) → 수정 반영 후 최종 검수가 메인 반영 1에 넘김.
5. 모험단 G0 = 10/20 기술 시험 뒤.

## 새 최종 검수에게 보낼 것 (인사 오면; 옛 최종 검수 local_5994bea0엔 보내지 않음)
1. **병합 요청 dev2-quest-p1 = 1caa86aa** (en-apply d8a47d89 위; 개발 1 dev1-quest-p1 6628e52b가 이 가지 위). 전체 223 비교(a951cf8b 기준): 새로 깨진 4개(first_meetings·halo_text·town_npcs·war_intro) 고침(2cab4ba8), 원래 실패 26개 줄 단위 비교 = 진행 중(결과 여기 적기). 시간 초과(-9)는 부하 탓, 혼자 돌리면 통과.
2. **질문**: M1_4가 등불로 바뀌며 옛 '안내자 보고' 대사(영웅 동상·용암 틈 설명, "More shards are out there. What will you do with the next one?")가 빠짐 — 옮길 곳(예: 1장 끝 안내자 한마디 / 도감 / 삭제)?
3. 이미 보낸 것: dev2-en-apply d8a47d89, dev2-mut-fix 584e2629 (옛 최종 검수가 병합했는지 확인 필요).

- **10/15 밤 (최신)**: 병합 대기 = **dev2-ch1-finish c9a2762a**(M1_1 옛 Finish 삭제, 첫 임무 이야기 칸 Config.Tutorial.Story + QuestService TEACH.Story, test_loot 돌연변이 158/158; ../wt_ch1) + **dev2-daily12 53256460**(Shared/Quests/Daily.luau 12종, 보상 R 표 한 곳, Pip 임시 몸, 소품 목록 docs/design/daily_props_2026-10-15.md; ../wt_daily). 병합됨: ch1-story 77c1f395, nudges-cut 8fe721cd, ops-rehearsal. 남은 일: 소품 배치 = 메인 반영 1(최종 검수가 넘김), H1/R1/N3 Offer 생기면 r2 2장 첫 사정 3줄, ⑦ 출시 알림(키·11/09), 모험단 G0(10/20 뒤), GPT 경제 조정 오면 Daily.luau R 표. 스크래치 도구: sweep.py, only_mut.py(세션마다 다시). 지워도 되는 worktree: ../wt_swbase ../wt_swmerge ../wt_story ../wt_party ../wt_escort ../wt_ops2 ../wt_nudge. 주의: worktree는 Game에서 `git worktree add ../wt_x`(-C Game 금지), sparse 패턴은 MSYS_NO_PATHCONV=1, 이스케이프 든 패치는 Write로 .py, xargs -P는 중간에 멈출 수 있음(직접 & 루프).
- **A23-208 이야기 칸 dev2-story-fields 498ae457**: 화면 몫(①Offer.Before ②Find 말풍선 ③Scene 몸짓 ④Next 줄·'!' 통통)은 개발 1이 받음(10/15 밤). 개발 1 세션 클리어 → 새 개발 1이 state/dev1.md 맨 위 ①~④로 이음. 내 쪽 할 일 없음, 화면 가지 나오면 서버 신호 맞는지만 확인.

## 가지 dev2-quest-p1 (worktree ../wt_p1) 내용
- P1 ①~⑨ 서버 전부: 부탁 장치(Main Offer·진영별 NPC·몸 필요·보상 미리보기·AcceptScene), 단계 Practice/Emote/Match/Timing/Learn/Skip/Escort/Chase, Story.Flags·StoryScene, 안내자 몸·스승 단계(TutorialStep 4)·H/R/N_Basics, M1_1 Otto 부탁, Lunch1 부탁+줍기, H_Band/R_Band, N0 Lv3 주문표 맞추기, M1_3 = 스승 Lv5 시험 + 배움 문(Skills.Learn.Gate), M1_4 = 등불, 계측, Story.Schema 2~5 이관. 계약·화면 몫 = docs/design/quest_p1_server_contract_2026-10-15.md.
- 퀘스트 데이터 묶음: Config.AddQuests + Shared/Quests 폴더, 규격 docs/design/quest_data_contract_2026-10-15.md(난이도 A23-207 포함), 검사 `py tools/test_quest_data.py`(자기 변이 17/17), test_story_text도 묶음 읽음.
- A23-205 매일 부탁 하루 5개(Story.Daily, 속성 StoryOffersDim), A23-206 귀속 보상(ItemsBound, 거래소·판매 자유분만, 사용은 귀속 먼저, 버전 그대로).
- ⑧ 추격·호위: Obj Escort/Chase + Config.StoryQuests.Paths, 속성 StoryMover/Kind/Pos/State.
- 개발 1에 화면 몫 다 보냄(⑧·Dim·Bound 포함).
- 다음(새 최종 검수 지시 기다림): 파티 가지 검토(api/party1은 커밋 0으로 멈춤), Codex 퀘스트 묶음 시험·통합, 공용 퀘스트·보스 공동 인정(A23-201/204).
- 개발 1과 합의: Match = StoryAction(Id,"Match","1~3"), Fx MatchHit/MatchMiss{Pick}; Timing = OpenPanel "Timing"{Id}, StoryAction(Id,"Timing","Good/Tries") 5번 중 3, 최소 2초, Fx TimingHit/TimingMiss; QuestShapes 6모양.
- 도구(스크래치, 세션마다 다시): sweep.py(절대경로 wt 필요), only_mut.py `<wt> tools/test_x.py "접두|접두"`, failnames.py, cmp_fail.py. **Bash heredoc은 \\t \\n을 진짜 탭/줄바꿈으로 바꿈 → 이스케이프 든 패치는 Write로 .py 만든 뒤 실행.**

## 지금 (10/15) — 오늘 가지 (모두 push, SHA는 최종 검수에 보고)
| 가지 | tip | 무엇 | 상태 |
|---|---|---|---|
| dev2-notify-gate | c9004c54 | A23-191 서버 알림 관문 Net.NotifyText: 'bad'만 글자, 나머지 소리만/없음. 괴수 시작·Most Wanted·Fall/Redeem 배너 줄 삭제. test_notify_gate 새 시험 | main 병합 |
| dev2-metrics-perf | 17068f08 | 숫자판 '기기 성능' 표(Perf 샘플 기기별 FPS·가장 낮은 초·메모리·끊김) | main 병합 |
| dev2-tame-craft | a8db119e | N0 3갈래(Requires.Classes, N0b DoneAny), AP1·T1 약초3, CraftService.NextGoal(사다리 첫 훅 Craft), PA/PC 실제 제작 시험 | main 병합 |
| dev2-pets12 | bc43cc88 | A23-194 펫 12종(Species Rarity·Family·Acquire·Bonus·Ready), PetBonus/PetReady, PetService.Bonus/BonusExtra(PvP 0), 속성 PetBonusType·PetBonus, PetGrants(+data.PetGrants), Craft S2~S5. 아기 슬라임 속도는 PvP에서도 그대로(최종 검수 결정) | main 병합 |
| dev2-feedback-signals | 3cd9aa5c | 반응 신호: LevelUp From·PowerFrom·PowerTo, 배우기 = SkillLearned 하나, Fx Drink, Upgrade Source, Choice 점수·랭크 전후, ReviveDone, CrownPoint(정수만) | 보고 |
| dev2-l10n-all | 76459ab3 | l10n_export: 모든 Config 문자열(제외 목록 방식) + 클라 .Text 직접 글 → 새로 잡힌 180개(build/l10n/missing_new_1015.csv) | main 병합 |
| dev2-goose-tests | e4316bfb | a23_14 거위 시험 GooseResult* 기준 + 줄다리기도 결과 남김 | main 병합 |
| dev2-forge-dupe | 0de782a5 | (이름과 달리) A23-197 도시락 이야기 퀘스트(Tiny → 연못 슬라임 2 → Lunchbox 줍기 → 선택 → Tiny) | main 병합 |
| dev2-drop-m12 | e6550f08 | M1_2 없앰(팔찌 줄 → M1_1 Finish, KO1 = M1_1 뒤) | main에 같은 내용 들어감(ff1e8954) |
| dev2-welcome-tests | 2258cd1b | 환영 1쪽=인사·2쪽=대장간 순서에 halo_text·weapon_first 시험 맞춤 | 보고 |
| dev2-quest-offer | 9c92783f | A23-199 공통 장치: Def.Offer [수락]/[거절](StoryOffers 속성, OpenPanel "Offer"), Pickup/Deliver 단계, 갈 곳 검사(KNOWN 33) — 계약 docs/design/quest_offer_server_2026-10-15.md | 보고 |

## 기다리는 것
- ① '대장장이가 무기 2개' 버그: 코드상 T1 지급은 전부 소유 비트로 한 번만. 몬스터 표에 T1 드롭 없음 → 가방 Twig 줄 = 가진 T1(설명 '대장장이 선물') + 다른 무기일 가능성 큼. 사용자 답(상황) 오면 다시. worktree ../wt_dupe(이제 도시락 가지).
- 퀘스트 전체 다시 짜기(Codex, 진영별 주선) 확정 뒤 한 묶음: 스승의 시험(A23-198, 사냥 슬라임 4 + 주민 돕기), M1_4, 도시락 조정, 갈 곳 없는 33단계 채우기. 공통 장치(Offer/Pickup/Deliver)는 준비됨.
- 시험 기준선(10/15 main): 원래 실패 = costume_physics·halloween·metrics_board(인자)·place_english·rank_marks·skeleton_ground·skin_binding_studio·walk_forge_client + weapon_shop_meme(클라 WeaponPose 정적, 개발 1). a23_14 변이 놓침 2 + 패턴 안 맞음 5는 main 원래 것.
- 도구(스크래치, 세션마다 다시): sweep.py `<wt> <out.json> --jobs N`, only_mut.py `<wt> <tools/test_x.py> "이름|접두*"`. Bash 도구는 heredoc 안 
을 줄바꿈으로 바꿈 → 이스케이프 든 파이썬은 Write로 파일 만든 뒤 실행.
- worktree(오늘): ../wt_gtest ../wt_ngate ../wt_mperf ../wt_tame ../wt_pets ../wt_fb ../wt_l10n ../wt_dupe ../wt_m12 ../wt_offer ../wt_welc — 병합 끝난 것은 지워도 됨.


## 내일 큐 (최종 검수 10/15)
1. **test_a23_14 거위 토스트 시험 고치기** (아래 '다음 할 일'): 실패 7 = goose-coop / goose-modes가 A23-191로 지운 옛 토스트 문구를 찾음 → GameState GooseResult* 기준으로. 새 worktree는 origin/main(856a8540 이상)에서.
- 개발 1: StoryNpcs 9줄(SkillTeacher → called)은 개발 1 상태 파일 '지킬 줄'에 있음, 충돌 없음.

## 지금 (10/15 새벽) — 병합됨 (856a8540)
- **dev2-learn-skill-2 7ba592dd** (main 8d7075eb 위; worktree ../wt_learn): 메인 Play(publish8)에서 Lv5인데 SkillLearnReady 0 / Gleam 프롬프트 꺼짐 고침. ① SkillService: PlayerReady 때 Level 속성 변화 훅 → catchUp(DebugCommand Level은 LeveledUp 안 탐) ② QuestService.publish: GoalKind "SkillLearn" 줄이 스토리 메인 줄보다 고정 칸 먼저(대장간 방문 뒤) ③ 클라 StoryNpcs.Refresh: SkillLearnReady > SkillSlots 동안 SkillTeacher NPC 프롬프트·! 켬(개발 1에 알림). 시험: skills 207 + 120/120, town_quests 1068 + 260/260, next_goal 58 + 19/19, story_npcs 14 + 11/11, board 97 + 27/27.
- **다음 할 일:** test_a23_14(변이 없이) 323/330 — 실패 7 = goose-coop / goose-modes 토스트 문구 시험(A23-191 거위 토스트 삭제 뒤 시험이 옛 토스트를 찾음, main에서도 같음). 시험을 GameState GooseResult* 기준으로 고치기.
- 개발 1 약속(A23-193 화면): 속성 SkillLearnReady(숫자)/SkillTeacher(NpcId), Fx SkillLearned{Slots,Teacher}, 스승 = StoryNpc 태그 + NpcId, 새 원격 없음.

## 앞서 (10/14 한밤) — 병합됨(learn = cc07f98b)
| 가지 | tip | 무엇 | 시험 |
|---|---|---|---|
| dev2-learn-skill | ec0b7341 | A23-193: Lv5/15/25(+과제) = 준비만(속성 SkillLearnReady/SkillTeacher), 진영 스승(Gleam/Rose=Smokey/Otto — Otto 몸에 Talk 프롬프트) 대화 → SkillService.TryLearn → SkillSlots + Fx SkillLearned{Slots,Teacher}. 환생·스승 몸 없음·Learn off = 바로. 저장 형식 그대로. 목표 줄 NextLearn / SkillLearnFirst | skills 206 + 120/120, town_quests 1068 + 260/260, board 97 + 27/27, next_goal 58 + 19/19, a23_14 330(변이 없이) |
| dev2-goose-polish | f3b67a9c | 거위 검토 ②③④⑤ 서버: 토스트·announce 전부 삭제, GameState GooseResult*, 광장 안 사람 기준 모드(GooseSquare.CountIn)·같은 판정, 협동 목표 고정, 장인 왕관 알 금지·+0 Fx 없음, 퀘스트 info.Took(알 1개+), 거위 걷기 MaxSpeed 14 | golden_egg 220 + 93/93, goose_square 92 + 52/52, notify_sound 69 + 60/60 |
- 거위 검토 전문: Game/build/codex/goose_review_2026-10-14.md (Codex goose_codex.md). ① 광장 골격 = build/goose_square_apply.luau(메인 반영 1 몫).
- 개발 1에 보냄: 스킬 배우기 화면 이름, 거위 화면 몫 목록(경계 점 높이·결과 멈춤·Join 칩 반짝·뒤뚱).
- worktree: ../wt_learn, ../wt_goose, ../wt_l10ncov, ../wt_huntattr, ../wt_bench(sparse; build/luau_cli 복사해 둠).

## 앞서 (10/14 밤 늦게)
- **dev2-benches-2 2e6cb56e** (보고함, 6번째 묶음; 관련 a23_14·gamepass·gear_slots·save_v4·weapon_ladder 통과): main 사진에 작업대 0개 → 원인 = ensureBenches가 Features.Crafting 꺼지면 안 만듦(모루 경로는 맞음: Map.Landmarks.ArtisanGuild.Anvil). 고침: 작업대 3개는 항상, Craft 프롬프트만 Crafting 켜졌을 때; 실시간 끄기 = 프롬프트 지움. craft 223/251, 변이 129/129. 남은 MISSED 'bag: a used-up material frees nothing'(패턴 2회) = main 원래 것.
- **dev2-huntfame-attr f56045ce** (보고함, 개발 1 요청 큐 ③): 속성 HuntFame = data.HuntFame (Mirrored + OnKilled SetAttribute). crown_points 86/47 변이, Mirrored 쓰는 시험 6개 통과. worktree ../wt_huntattr(sparse: src/tools/docs/design, build/luau_cli 복사).
- **dev2-l10n-coverage 49f8da14** (보고함): tools/l10n_coverage.py — 플레이어 글 전부(Config 걷기 + 등록 글 표 + format_keys.csv + 하드코딩 찾기) vs 클라우드 표(읽기만) → build/l10n/missing_ko.csv, suspect_ko.csv(empty/english/mixed/numbers/placeholders/stale), auto_ko.csv(자동 번역), table_entries.json. 10/14 결과: 글 2751, ok 2439, missing 305, suspect 7, auto 48. test_l10n_coverage 32/32. l10n_format_keys에 picked_rows() 나눔(출력 같음). 번역 자체 = 최종 검수 + GPT. worktree ../wt_l10ncov(sparse).
- 주의: worktree에서도 `git stash` 쓰지 말 것(저장소 공용 stash 목록) — 10/14 실수로 한 번 하고 바로 pop함.
- 다음: 메인 반영 1 sync 사진에서 Workbench_Smith/Alch/Tame 3개 확인(최종 검수가 봄). worktree ../wt_bench = dev2-benches-2.

## 앞서 (10/14 밤)
- **보고함, 병합 대기:**

| 가지 | tip | 무엇 | 시험 |
|---|---|---|---|
| dev2-skill-tasks | c56594e0 | 99N D(계획 5): Z/X = 레벨 + 직업 과제(Config.Skills.Tasks; 전사 기본 공격 처치 40 / Z 3+ ×15, 마법사 Q 2+ ×20 / Z 3+ ×15, 궁수 20스터드+ 처치 30 / 25+ 50; 장인 직업 = 원래 직업 것). data.SkillTask, 속성 SkillTaskSlot·SkillTaskN, Config.SkillTaskLine(화면 글) | skills 182/새 변이 11, sweep 211 = 원래 8 |
| dev2-revive | 60c69182 | 99N G(계획 8): ReviveService — 40스터드 안 같은 편 있으면 10초 대기 + G 3초 프롬프트(6스터드), HP 물약 1, HP 30%·보호 3초, Honor/Infamy +1, 쿨 10초, ReviveSkip | test_revive 49/31, sweep 214 = 원래 8 |
- 최종 검수 OK: 수치·모양(Unlock 그대로 + Tasks 표 따로), 살리기 설계.
- 개발 1 몫으로 알림: SkillBook learned() 마지막 줄(레벨만 보고 배움), 살리기 프롬프트 다른 편에겐 숨기기, 죽음 화면 ReviveUntil·ReviveSkip 버튼, 목표 칩 SkillTaskLine.
- 앞선 묶음(ae0e9c4a·928dd298·544a2e82)은 최종 검수 4·5번째 병합 묶음에서 시험 중.
- worktree: ../wt_sktask, ../wt_revive (+ ../wt_ks, ../wt_ops, ../wt_gpt, ../wt_bench, ../wt_alch, ../wt_stats3 병합 뒤 지워도 됨).
- 주의: 레벨로 Z/X 여는 시험 세계는 K.Tasks.Enabled = false 넣어야 함(skills_x·skill_signals·friend_pvp에 넣음).


## 앞서 (10/14 밤 늦게)
- **가지 쌓기(모두 craft 시험이 겹쳐서 위로 쌓음, 리베이스 없음):** market-ready → alch → benches → gpt-fixes → kill-switches → ops-env. 맨 위를 병합하면 아래가 다 들어감.

| 가지 | tip | 무엇 | 시험 |
|---|---|---|---|
| dev2-market-ready | 32bb2660 | 장인 ③: Switches.Defs.Market(실시간 끄기) + 서버 죽이기 단계 시험 + UnpackSpare | market 206/91 |
| dev2-alch | 4c4b011d | 장인 ⑤: 연금 레시피 AP1(HP 물약 2)·AP2(MP 2)·AS1(70% 주문서, Lv3), Kind Potion(재고 한도 N+2), main 합침 | craft 200/122 |
| dev2-benches | cad622fd | 장인 ④: Config.Craft.Benches(Smith·Alch·Tame), 모루 옆 Workbench_<역할> 자동 배치(CraftStation 태그, 12번 재시도), alch 합침 | craft 210/125 |
| dev2-gpt-fixes | 648db8b2 | GPT 검토 4건: ① 재료를 다 쓰는 무기 제작 = 빈 칸 셈 ② 가진 단계의 더 높은 +N = 바꿔 끼움·거래소 구매 됨 ③ 이미 가진 첫 드롭 = 강화 주문서 + 예비 +0 ④ 숫자판 DropWeapon(8분) | craft 215, loot 695, market 185, test_metrics 78/48 |
| dev2-kill-switches | ae0e9c4a | ⑤(가): Artisan·Crafting·Gathering·Tonics·Research·Gear 끄기(Feature → Config.LiveOff) + FieldBoss; 다시 켜면 Gear onReady·채집 Build·제작 프롬프트+대기 정산 | craft 220, market 212/93, sweep 211 = 원래 실패 8만 |
| dev2-ops-env | 928dd298 | ⑥: Config.Env Names + Places{Beta, Live} place id, 공개 서버가 Dev면 경고 1줄. 배지 ID 0 = 안전하게 건너뜀 | ops_safety 141/71(Halloween 변이 = 원래 놓침) |
- **모두 보고함.** 최종 검수: ae0e9c4a 묶음을 4번째 병합 묶음으로 시험 중, ops-env 928dd298은 같은 묶음 또는 5번째.
- ⑦ 스탯 dev2-stats3 544a2e82 = origin/main 178914e1 합침(깨끗), sweep 212 = 원래 실패 8만, 보고함. 스탯 스위치 꺼짐.
- 골드 0→300(첫 무기) = 2배 골드 패스(제작자 자동 소유), 버그 아님(최종 검수 확인, A23-75 그대로).
- 주의: keepboth.py는 겹친 충돌(같은 줄에 두 그룹)을 반토막 냄 → 큰 fixture 충돌은 한쪽(--theirs) + 내 그룹을 원래 커밋에서 다시 끼우기(스크래치 rebuild_craft.py, gpt_merge.py, ks_merge.py).
- W2가 main에서 약초 3 + 구리 2 → 시험의 대장장이엔 Herb 넣기.
- worktree: ../wt_alch, ../wt_bench, ../wt_gpt, ../wt_ks, ../wt_ops (+ 옛 것).


## 앞서 (10/14 한밤)
- **main 병합됨:** artisan-sell, bag-slots, bag-reward(6곳 포함 77699c57), sub-retry, fund-ladder, no-ticket, first-hit, weapon-shop(v6), market, stale-text.
- **push·보고, 병합 대기:**

| 가지 | tip | 무엇 | 시험 |
|---|---|---|---|
| dev2-artisan-quests | 4ee3c50d | 장인 ②: 목표 Gather·Craft·SellMat, N0(약초 3 + 구리 2 → 제작 → 150골드 + 만든 무기 장착 EquipBestSpare)·N0b(5개 팔기 → 30)·N4(N2 뒤 제작 2 → 교차로), W1 레시피 삭제, W2 = 약초 3 + 구리 2 | town_quests 1058/251, craft 186, craft_window 158/59 |
| dev2-xp-ramp | 3a0808fc | Config.Levels.Ramp {10 = 0.5, 11 = 0.65, 12 = 0.8, 13 = 0.9}, 새 시험 test_xp_ladder | 13 / 5 |
| dev2-first10-b | e5915e58 | Codex B1(Trials 줄 = 첫 미완 시험 글), B5(King 줄은 King 120초 안일 때만, FieldBossService.SecondsUntil), B6(XPEarned source, 숫자판 XP[Lv5/Lv10] 사냥/그 밖) | town_quests·next_goal·test_metrics·health 변이 |
| dev2-first-flow | 0ec2dadc | A23-188: 첫 임무 = 대장간 방문(T1 + 150골드 finishFirst), 옛 1·2단계 저장 = 접속 때 끝, M1_1 = Prince 1 → 주문서 쓰기, M1_2 Prince 1, 숫자판 Weapon = T1 | weapon_first 113/52, unarmed 261/77, onboarding 842 |

- 큐(최종 검수 10/14): 장인 ③ 거래소 실시간 끄기 키 Switches.Defs.Market + 단계별 서버 죽이기 시험 + 거래소 퀘스트 → ④ 작업대 3개(교차로 길드 마당, MapBuilder, CraftStation 태그) → ⑤ 연금 소모품 → ⑥ Gear 켜기 + 전투력 → ⑦ 새 기능 끄기 키 묶음 → 운영(Env.Names Beta/Live, 배지 7 ID, TestServer 되돌리기).
- 규칙(최종 검수 10/14): 전체 시험은 가지당 한 번(4개 동시), 변이는 바뀐 시험만. 큐가 비면 상태 파일 push 뒤 clear_session("self").
- 주의: main의 unarmed_start 변이 2개('join-time gift' 패턴 2번) — weapon-shop 가지에서 고쳐 main에 있음. skill_learn 'no banner' NOT APPLIED = 개발 1 몫(클라이언트).
- worktree: ../wt_aq, ../wt_xp, ../wt_f10, ../wt_flow (+ 병합 끝난 wt_artisan·wt_bag·wt_subretry·wt_fundl·wt_ticket·wt_wshop·wt_tmpm은 지워도 됨).
- 스크래치 도구: sweep.py(`<wt> <out> [--jobs N]`), only_mut.py(`<wt> <test.py> "이름|이름"`), keephead.py(충돌 = 우리 쪽).


## 앞서 (10/14 늦은 밤)
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
