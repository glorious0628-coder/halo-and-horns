# 퀘스트 많이 — 어느 레벨에서든 할 일 3개 이상 (A23-56, 검수 설계 2026-10-06)

> 사용자(A23-56): "게임성이 높고, 퀘스트가 많았으면 좋겠어." → 늘 **메인 1 + 서브 여러 개 + 일일 + 사냥터 게시판 의뢰**.
> 베타는 빛·뿔만(A23-57). 날짜: 기능 마감 10/24, 베타 10/31, 정식 12/19. 화면 글은 쉬운 영어(A23-48, `glossary_en_2026-10-06.md`).
> 이어 쓰는 문서: `quest_chain_2026-10-06.md`(메인·S 서브), `story_depth_2026-10-06.md`(3~5장, E0~E10), `town_npc_quests_2026-10-06.md`(H/R/N).
> 코드 기준: main 59c2585 + `Game-dev2` 작업 트리(아직 커밋 전, H1·R1·N3·E4·E6).
> 2026-10-09 검수: 서버는 들어감 — 실제 값·바뀐 좌표는 `quest_volume_server_2026-10-07.md`. 게시판은 개발 1 창이 아직 없어 꺼져 있음(`Config.Board.Enabled = false`). 아래 날짜·'작업 중' 표는 10/06 계획.

## 0. 한눈에
1. **지금 빈 곳은 Lv10부터다.** M2_7을 받으면 메인이 끝나고, 서브는 Lv8쯤 거의 다 끝난다. Lv10~25(혼자 수동 약 3시간)에는 일일 3개와 끝없는 '추가'(고블린 25~40마리)만 남는다.
2. **메인은 Lv25까지 끊기지 않게 한다.** story_depth의 3장 정식 몫(M3_2, M3_5~M3_8)은 거의 데이터만이라 베타로 당긴다.
3. **새 퀘스트 29개를 넣는다.** 서브 12개(+설계해 둔 서브 6개 당김), 게시판 의뢰 틀 10개, 숲 일일 7줄. 대부분 지금 있는 목표 종류로 만든다.
4. **새 엔진은 두 개만이다.** E11 사냥터 게시판(반복 의뢰)과 E12 레벨대별 일일. 나머지는 E0·E4·E6·E7 등 이미 정한 조각을 다시 쓴다.
5. **모든 퀘스트가 천사나 악마 쪽으로 기운다(GDD §0).** 서브는 마지막에 A/B 선택을 하고, 게시판은 [Kind]/[Sneaky] 중 고른 쪽을 기록한다. 보상은 골드·XP·물약·주문서뿐이고 능력치는 팔지 않는다.

---

## 1. 지금 퀘스트 수 (빛·뿔, 코드 확인)

**지금 있는 목표 종류** (`StoryQuestService.luau:145-185`, `:354-367`, `:490-511`)
- Kill{Kind, Zone, Golden, Near+Radius}, BasicKill, SafeKill{MinHP}, AutoKill
- SkillHit{Min}: 수동 스킬만 센다. Zone 필터는 없다(`:174-176`).
- WarPoints, EarnGold{Source}, WarChest, Goose
- Enter{Zone | OwnTown | AnyTown}, Level, Near{Spot, Radius, Zone}
- State: BlacksmithVisited, AutoOn, OwnIron 세 키뿐(`:145-150`)
- Talk, Choice, Trials(여러 목표, 순서 상관없음)
- 열림 조건: Factions, Requires{ClassChosen, Tutorial, Level, Done}, Show="GooseSoon"(`:297-308`, `:424-435`)
- **개발 2 작업 중**(Game-dev2, 커밋 전): Near.Stay(E4), Npc 단계, 선택별 보상(E6), Reward.GoldN·XPBar
- **없는 것:** KO·괴수·자루·함께 잡기·치유·아이템 납품 목표, 그리고 서브 반복(Done은 한 번 적으면 끝)
- **일일 틀**(QuestService): Kill, Golden, Gold, Release, Goose, Hunt(빛), Plunder(뿔) (`Config.luau:1769-1784`)

| 레벨대 (혼자 수동, 추정) | 메인 | 서브 (빛 / 뿔 같음) | 일일 | 게시판 |
|---|---|---|---|---|
| Lv1~5 (약 10분) | M0 + M1_1~M1_4 (5개) | S0, S4, S3, S1(거위 3분 전만) → 동시에 1~3 | 3 (새싹 풀 4줄) | 0 |
| Lv5~10 (약 25~35분) | M2_1~M2_7 (7개). M2_7은 Lv10까지 잠김 | S2, S3(운), S1 → 0~2 (+작업 중 H1 / R1) | 3 | 0 |
| Lv10~15 (약 35~45분) | **0** | 남은 S1·S2·S3만 → **0~1** | 3 (고블린 50~60마리 등) | 0 |
| Lv15~20 (약 50~60분) | **0** | **0** | 3 (+PvP 1) | 0 |
| Lv20~25 (약 70~80분) | **0** | **0** | 3 | 0 |

**근거**
- 메인 11개: `Config.luau:1561`. M0은 Tutorial이다. M2_7 다음 메인은 없다.
- 서브 7개: `Config.luau:1564`. 그중 N1·N2는 장인 전용(`:1734`, `:1740`)이라 베타 빛·뿔에게는 5개다.
- 개발 2 데이터: H1(빛)·R1(뿔)이 있고, N3은 `Factions={Neutral}`이다(`Game-dev2 Config.luau:1767-1839`, `:1818`).
- 서브 줄은 2개까지만 보낸다(`Config.luau:1557` MaxSubs=2, `StoryQuestService.luau:457`).
- 일일: 3칸이고 KST 자정에 바뀐다(`Config.luau:1757`, `:1813`). Lv1~9는 새싹 4줄(`:1799-1809`), Lv10+는 `Kill DailyUnits {50,60}`(`:1770`)이다. PvP 일일은 Lv15 이상·새싹 아님·하나만(`:1780-1782`).
- 받은 일일 칸은 끝없는 '추가'가 된다(`QuestService.luau:822`, `:649`). 추가는 고블린 25~40마리 같은 회색 반복이다(`Config.luau:1770`).
- 다음 목표 줄은 Lv10 숲이 열리면 사라진다(`QuestService.luau:494-511`, `:575`).
- 게시판: 사냥터 게시판은 없다. 교차로 현상수배 게시판(`Config.luau:1125`)은 PvP·랭킹용이다.
- 레벨: **베타 레벨 상한은 없다**(`Config.luau:169` MaxLevel=100, `Config.Beta` `:2518`은 칭호뿐). 숲은 Lv10, 유적은 Lv25(`:1091`, `:1094`)이므로 **베타 설계 범위는 Lv1~25**로 잡는다. Lv25+는 정식 4장 몫이다. 표의 시간은 XPToNext(`:176`)·고블린 XP 28(`:1250`)·분당 5마리로 낸 실측 전 추정이다.

**빈 곳**
- ① **Lv10~25 전체:** 메인 0, 서브 0~1. 일일 하나가 10~12분짜리 같은 숫자 벽이다. 가장 크다.
- ② **Lv8~10 대기:** M2_7이 잠긴 동안 서브가 다 끝나 일일과 추가만 남는다(quest_chain 4절 위험 구간).
- ③ 옛 세이브: Lv10 이상이면 `SQ.Main` 전체를 Done으로 바꾼다(`StoryQuestService.luau:318-321`). 3장을 넣는 순간 건너뛰므로 **E0을 먼저** 고친다.
- 첫 3분에 할 일이 1개인 것은 일부러 그렇게 둔 것이다(A23-3). 빈 곳이 아니다.

---

## 2. 목표 (레벨대마다 늘 열려 있는 수)

| 레벨대 | 메인 | 서브 (동시에 열림) | 일일 | 게시판 (들고 있는 의뢰) | 지금 할 수 있는 것 최소 |
|---|---|---|---|---|---|
| Lv1~5 | 1 | 1~3 | 3 (첫 임무 수락 뒤) | 0 (M1_4 뒤 열림) | 3 (첫 3분은 1) |
| Lv5~10 | 1 (Lv8~10은 잠김 줄) | 2~4 | 3 | 3 (초원 게시판) | 5 |
| Lv10~15 | 1 | 1~3 | 3 (숲 줄) | 3 (숲 게시판) | 4 |
| Lv15~20 | 1 (Lv15~18 사이 잠김 있음) | 1~3 | 3 (+PvP 1) | 3 | 4 |
| Lv20~25 | 1 (Lv21~25 사이 잠김 있음) | 1~2 | 3 | 3 | 4 |

**규칙**
1. **잠긴 줄은 셈하지 않는다.** "지금 할 수 있는 것"은 언제나 3개 이상이다. 일일을 다 받아도 게시판 3 + 메인이나 서브 1이 남는다.
2. **노가다는 줄이되 없애지 않는다.** 한 목표는 2~5분이고 처치 수는 1~15마리다. 같은 숫자만 커지는 사슬은 없다. 동사를 바꾼다(처치·장소·스킬 몰이·기본 공격만·체력 지키기·골드·이벤트·선택).
3. **기울기를 준다.**
   - 서브: 마지막 A(천사)/B(악마) 선택. H1 데이터와 같은 모양(Points 1, Pick 기록, E6 보상)으로 한다.
   - 게시판: [Kind]/[Sneaky]를 세기만 하고 명예·악명은 0이다. 반복 의뢰로 주간 랭킹을 올리지 못하게 하려는 것이다(A23-23 D1). → **10/09 바뀜(A23-86 결정 1):** 게시판 선택도 하루 장부 Deeds로 명예·악명 +1 / 반대 −1, 하루 6점까지. 주간 랭킹 점수는 여전히 0(BoardService).
   - 일일: 원래대로 둔다. 거위·Hunt·Plunder가 이미 진영 맛을 낸다.
4. **보상**
   - 서브 Lv5~10은 '마을형': 120골드 + 레벨 칸 0.5 + A 70% 주문서 / B HP 물약 3 + 60골드.
   - 서브 Lv10+는 '숲형': `Reward{Gold=2, XP=2}`(HuntValue 분, Lv10~24 = 384골드 + 672XP) + 같은 A/B 아이템. 단 B의 골드는 HuntValue 1분(192)이다.
   - 크기는 같고 종류만 다르다.
5. **첫 10분은 그대로 둔다.** 새 서브와 게시판은 M1_4 뒤, Lv5 이상에서 열린다. (예외: 첫 [Claim] 뒤 '잃어버린 도시락' 카드는 이 규칙보다 먼저, A23-70.)
6. **서브 줄을 늘린다.** `MaxSubs` 2 → 3. HUD 2줄은 그대로 두고, 펼친 목록에서 다 보인다(HUD.luau questFold). (→ HUD 퀘스트 표시는 A23-94로 '왼쪽 가운데 큰 글씨, 지금 퀘스트 하나 + Quests (n) ▼'로 바뀜.)

---

## 3. 새 퀘스트 (베타)

### 3-1. 메인 앞당김 (story_depth 3장 정식 몫 → 베타, 새 퀘스트 수에는 세지 않음)
| Id | 열림 | 목표 (있는 종류) | 필요한 것 |
|---|---|---|---|
| M3_2 Three Camps | M3_1 뒤 | Trials: 고블린 Kill Near GoblinCamp1/2/3 R40 각 1 | 야영지 좌표 3개(지도 v2, 개발 1). Kill Near는 이미 된다(`:163-166`) |
| M3_5 Sprout Graduation | Lv15 | State Graduated → Talk | **E7** (0.05일) |
| M3_6 Brute Hunt | Lv18 | Kill GoblinBrute 2 | 데이터만 |
| M3_7 Campfire Dust | Lv21 | SkillHit Min3 ×2 | 데이터만 (숲 필터는 선택, 0.05일) |
| M3_8 Call of the Tombs | Lv25 | Enter SkeletonRuins → Talk | 데이터만 |

story_depth 베타 몫(M3_1, M3_3, M3_4, Pip1)과 합치면 **메인 줄이 Lv25까지 비지 않는다.**

### 3-2. 서브 — 새 12개 + 설계해 둔 6개 당김 (모두 한 번만, 마지막은 A/B)

| Id | 종류 | 열림 | 말하는 이 | 목표 사슬 | 한 줄 (EN) | A (천사) / B (악마) | 보상 | 엔진 |
|---|---|---|---|---|---|---|---|---|
| S6 (당김) | Sub | Lv5, M1_4 뒤, 진영별 단계 | Guide | 빛: Kill Slime Near MeadowArrival ×5 / 뿔: EarnGold 80 → Enter OwnTown | "New kids walk this path. Keep it safe!" / "A Horn Legion pouch must be FAT!" | Help them find the slimes / Make them say "Thanks, boss!" · Share snacks with the den / Count it twice. Mine! | 마을형 | 랜드마크 1 |
| XR1 (당김) | Sub | Lv5, 모두 | Tiny | Talk → Kill BigSlime 1 → Talk → Choice | "A ~~King Slime~~ Slime Prince swallowed a teddy bear!" (A23-84) | Return it to its owner / Sell it at the counter | 마을형 | – |
| H2 (당김) | Sub | Lv8, 빛 | Bright | Near Fountain R22 → Kill Slime 5 → Choice | "The town lantern is gone! Did a slime eat it?" | Give it back to the town / Hang it in my house | 마을형 | – |
| **R5** | Sub | Lv8, 뿔 | Smokey | Near SlimePond R30 → Kill BigSlime 1 → Choice | "A ~~King Slime~~ Slime Prince is wearing Smokey's sack as a hat!" (A23-84) | Give it back to Smokey / Finders keepers! | 마을형 | – |
| **GW2** | Sub | Lv11, 모두 | Guide | Near WoodsGate Stay 10 → Kill Goblin Near WoodsArrival ×4 → Choice | "The woods path is so dark. Kids are scared to walk it." | Put up a lamp for everyone / Put up a KEEP OUT sign | 숲형 | E4 |
| H3 (당김) | Sub | Lv12, 빛 | Sir Gleam | Talk → Kill Slime 6 → Talk → Choice | "Day 40: Cat in tree. Again!" | Let the cat be. Help someone new. / Put it back up. More hearts! | 숲형 | – |
| R3 (당김) | Sub | Lv12, 뿔 | Rascal Rex | Talk → EarnGold 60 → Talk → Choice | "Prank number 200! Same as 199?" | Plan a surprise party instead / Do prank 201. The same one! | 숲형 | – |
| GW1 (당김) | Sub | Lv12, 모두 | Grabbo | Near GoblinCamp1 R10 → Talk → Choice | "Welcome to Grab Club! Meeting number 47." | Give the dust back / Grab MORE dust! | 숲형 | 랜드마크 |
| **GW3** | Sub | Lv14, 모두 | Guide | Kill Golden Zone=GoblinWoods 1 → Talk → Choice | "A goblin painted himself gold to look rich!" | Tell him he's fine as he is / Sell him more gold paint | 숲형 | – |
| **H5** | Sub | Lv15, 빛 | Bright | Talk → Kill GoblinBrute 1 → Talk → Choice | "Bright needs Form H-2 to fight a Brute. Who made these forms?!" | Skip the form. Just help! / Fill in three more forms | 숲형 | – |
| **R6** | Sub | Lv15, 뿔 | Smokey | Talk → EarnGold 200 → Talk → Choice | "Plan B failed. Time for… Plan B?" | Try a brand-new plan / Plan B again, but LOUDER | 숲형 | – |
| **GW4** | Sub | Lv16, 빛·뿔 | Guide | WarPoints 40 → Choice | "The Crown War is close! Win points for your side." | Cheer for both sides / Victory dance, our side only! | 숲형 | – |
| **GW5** | Sub | Lv17, 빛·뿔 | Fountain Shard | Goose ×2 → Talk → Choice | "The Golden Goose looks so tired…" | Let her rest a day / Make her lay eggs faster! | 숲형 | – |
| **GW6** | Sub | Lv19, 모두 | Guide | SafeKill GoblinBrute MinHP 0.5 ×1 → Choice | "Beat a Brute and stay above half HP. He just wants a nap." | Tuck him in for a nap / Draw a mustache on him | 숲형 | – |
| **GW7** | Sub | Lv21, GW1 뒤 | Grabbo | Near GoblinCamp1 R10 → Talk → SkillHit Min3 ×2 → Choice | "Grab Club meets again. Same topic?" | Bring the club a new idea / Vote for MORE. Again! | 숲형 | E2 선택 (Default 줄) |
| **H6** | Sub | Lv22, 빛 | Bright | Near HeroStatue Stay 10 → Kill Goblin 8 → Choice | "The hero statues are dusty. Who were they, really?" | Add a statue of a sprout too / Make OUR statue bigger | 숲형 | E4, 랜드마크 |
| **R7** | Sub | Lv22, 뿔 | Smokey | Near LavaCrack Stay 10 → EarnGold 300 → Choice | "Party at the lava cracks! Bring snacks… or gold." | Invite the whole den / VIP only. Just us! | 숲형 | E4, 랜드마크 |
| **GW8** | Sub | Lv23, 모두 | Guide | EarnGold 500 → Enter OwnTown → Talk → Choice | "Your vault is SO full. What is all this gold for?" | Give some to the town fund / Build a bigger vault | 숲형 | – |

- 굵은 글씨가 새로 만든 12개다. 당긴 것의 대사는 `story_depth` §3과 §5, `town_npc_quests`를 그대로 쓴다.
- GW5와 GW8은 A23-55('욕심')를 설교 없이 건드린다. GW8 마지막 쪽은 "Is a bigger vault ever big enough?"이다.
- **N3 고치기(A23-57):** 지금 데이터는 `Factions={Neutral}`이다. 빛·뿔 누구나 받도록 Factions를 빼고, Good/Evil Points 1을 준다.
- 서브 수는 진영마다 같다. 빛과 뿔 모두 16개가 새로 열린다(공정). 말하는 이 Grabbo, Sir Gleam, Rascal Rex는 베타에선 이름만 쓴다(story_depth §4).

### 3-3. 사냥터 게시판 의뢰 틀 10개 (`Config.Board.Jobs`, 사냥터마다 변수만 바꿈)

| 변수 | 초원 게시판 (Lv1~9 값) | 숲 게시판 (Lv10~24 값) |
|---|---|---|
| Unit / Big | Slime / BigSlime | Goblin / GoblinBrute |
| Arrival / Spot | MeadowArrival / SlimePond | WoodsArrival / GoblinCamp1 |

**같은 목표에 문구 두 개(Kind / Sneaky)를 붙인다.** 고른 쪽만 기록한다.

| Job | 목표 (초원 / 숲) | Kind (EN) | Sneaky (EN) | 엔진 |
|---|---|---|---|---|
| J1 | Kill Unit Near Arrival R40 ×5 / ×4 | "Clear the path so new kids can walk." | "Clear the path. Now it's YOUR road!" | – |
| J2 | Kill Unit Near Spot R40 ×4 / ×3 | "The pond is too crowded. Give the frogs room." | "Best spot in the meadow. Claim it!" | – |
| J3 | Kill Big ×2 / ×1 | "A big one scares travelers. Stop it!" | "Bonk the big one. Show who's boss!" | – |
| J4 | SkillHit Min3 ×2 | "A swarm blocks a cart. Clear it at once!" | "Hit three at once. Make everyone look!" | – |
| J5 | BasicKill Unit ×6 / ×4 | "Basic hits only. Don't scare the birds." | "No skills needed. Too easy!" | – |
| J6 | EarnGold 40 / 150 | "Collect gold for the town road fund." | "Fill your pouch. Bigger pouch, bigger grin!" | – |
| J7 | AutoKill ×8 / ×6 (S0 뒤) | "Let your shard guard the road." | "Let your shard do the boring part." | – |
| J8 | Kill Golden 1 (드물게) | "A golden one is lost. Bring it home!" | "A golden one! Finders keepers!" | – |
| J9 | SafeKill Big MinHP 0.5 ×1 | "Show the sprouts how to fight safely." | "Win without a scratch. Show off!" | – |
| J10 | Near Arrival R14 Stay 15 | "Stand guard at the gate." | "Stand at the gate and look scary." | E4 |

### 3-4. 숲 일일 7줄 (E12: Newbie 방식 레벨대, Lv10~24, 한 줄 약 3분)
| Id (템플릿) | 목표 | Weight |
|---|---|---|
| Kill | Goblin 12~15 | 3 |
| Kill (Strict) | GoblinBrute 2 | 2 |
| Release | 몬스터 맞힌 스킬 4~6번 | 3 |
| Gold | 사냥 골드 150 / 200 / 250 | 3 |
| Golden | 황금 몬스터 1 | 1 |
| Goose | 거위 참여 1 (빛·뿔) | 1 |
| Hunt / Plunder | PvP 1 (Lv15+, 새싹 아님, 하나만 — 지금 규칙) | 1 |

- 보상: RewardMinutes 3, ChestMinutes 6을 제안한다. 하루치는 사냥 15분어치이고, 지금은 25분어치다(`Config.luau:1814-1815`). 한 줄 노력이 1/3로 줄기 때문이다. 실측 뒤 개발 2가 조정한다.
- 휴가 보상은 `DailyDayMinutes`가 레벨대를 보므로 그대로 따라간다.

**새로 만드는 것 합계:** 서브 12 + 게시판 틀 10 + 숲 일일 7 = **29개**(당긴 서브 6·메인 5는 따로).

### 3-5. 엔진 조각

| # | 무엇 | 쓰는 곳 | 담당·일수 | 상태 |
|---|---|---|---|---|
| E0 | 옛 세이브 이전 수정 (Lv10~24는 Chapter ≤ 2만 Done) | 3장 전부 | 개발 2, 0.05 | **필수**, story_depth |
| E2 | LinesBy (선택) | GW7 (없으면 Default) | story_depth | 선택 |
| E4 | Near.Stay | GW2, H6, R7, J10 (+H1·R1) | 개발 2 | 작업 중 |
| E6 | 선택별 보상 + `LootService.GrantItem` | 모든 서브, 게시판 보너스 | 개발 2 | 작업 중 |
| E7 | State Graduated | M3_5 | 개발 2, 0.05 | 앞당김 |
| **E11** | **사냥터 게시판**: 반복 의뢰 칸, eventAmount 재사용, Kind/Sneaky 기록, 하루 카운터, 원격 `BoardAction`(서버 거리 검사) | 3-3 | 개발 2 1.0 + 개발 1 1.0 | 새것 |
| **E12** | **레벨대별 일일**: `Quests.Newbie`를 `Quests.Bands`로 일반화 (isNewbieLevel, chestAt, DailyDayMinutes, runDayCheck) | 3-4 | 개발 2, 0.4 | 새것 |
| 작은 것 | MaxSubs 3, N3 Factions, 랜드마크 7개 (MeadowArrival = 초원 Spawn, WoodsArrival = 숲 Spawn, GoblinCamp1~3, HeroStatue, LavaCrack), 게시판 자리 2곳 | | 개발 2 0.1 + 개발 1 좌표 0.2 | 데이터 |

- 랜드마크는 Zone.Spawn과 preview_map 물건(`HeroStatue`, `LavaCrack`, `GoblinCamp`)에서 계산해, 지도 v2(A23-53)로 옮겨도 따라가게 한다.

---

## 4. 일일·게시판 구조

**일일 (지금 그대로 + E12)**
- 3칸이 한국 시간 00:00에 새로 나온다(`Config.Daily.TimezoneOffset`). 미국 서부로는 오전 8시다.
- 3개를 다 받으면 상자를 주고, 못 온 날은 휴가 보상 70%를 준다(최대 3일).
- 바꾸기는 60초 쿨다운이다(`Config.luau:1758`).
- 레벨대는 Lv1~9 새싹 / **Lv10~24 숲(새)** / Lv25+ 지금 템플릿이다.

**게시판 (E11)**
- **자리:** 사냥터 입구에 둔다. 초원은 도착 지점 옆, 숲은 WoodsGate의 초원 쪽 끝이라 PvP 밖이다. 교차로 현상수배 게시판과는 다른 것이다.
  - M1_4 뒤에 퀘스트 줄 "Job Board · tap for directions"와 마커(A23-36)로 처음 안내한다.
- **보이는 것:** 카드 4장. 카드마다 [Kind] [Sneaky] 두 버튼이 있다. 누르면 그 의뢰를 받는다.
  - 한 번에 3개까지 들고 다닌다. 그래서 게시판 왕복은 약 10분에 한 번이다.
  - 받은 의뢰는 퀘스트 목록에 'Job' 표시로 나온다.
- **끝낼 때:** 다 하면 바로 지급하고 토스트를 띄운다. [받기]를 누를 필요가 없다.
  - 그 카드 자리에는 같은 사냥터 풀에서 새 카드가 들어온다. 바로 전 2개와 같은 틀은 나오지 않는다.
  - 카드 바꾸기는 일일과 같은 60초 쿨다운을 쓴다.
- **보상:** 게시판 사냥터 기준 `HuntValue(그 사냥터 최저 레벨, 1)`이다.
  - 초원 36골드 + 60XP, 숲 192골드 + 336XP.
  - 높은 레벨이 초원 의뢰로 큰돈을 버는 것을 막는다.
  - 하루 다섯 번째 의뢰는 **30% 주문서 1장**을 더 준다(양쪽 같음, 하루 1번).
- **반복 한도:** 하루(KST) 10개까지 전액, 그 뒤는 절반이다. 0이 되지는 않는다(지금 '추가'의 ExtraRewardMult 0.5와 같은 생각).
  - **E11이 켜지면 '추가' 생성은 끈다.** 받은 일일 칸은 비우고, 게시판이 그 역할을 한다.
- **기울기:** 고른 쪽을 `data.Story.N.Kind` / `.Sneaky`에 센다. 토스트는 "Your shard leaned to the light." / "…to the dark."이다.
  - 게시판에 "Kind 12 · Sneaky 3"을 보여 준다.
  - ~~명예·악명·랭킹 점수는 0이다.~~ → 명예·악명은 하루 장부 Deeds(+1 / 반대 −1, 하루 6점, A23-86 결정 1), 랭킹 점수는 0. 칭호 10·50개는 정식에서 E3로 준다.
- **아이 친화:** 시간 제한·실패·사라짐이 없다. 지역을 나가도 의뢰가 유지된다. 연속 출석 압박이 없다. 자동 전투 아이도 J7처럼 할 수 있는 카드가 늘 있다.
  - 숲 게시판의 J2(야영지)는 PvP 지역 안이다. Lv15·1시간 새싹 보호를 그대로 믿되, 숲 카드 4장 중 PvP 지역 밖에서 되는 카드(J6, J10)가 늘 1장 이상 있게 한다.

---

## 5. 담당·일정

| 담당 | 일 | 일수 |
|---|---|---|
| 개발 2 (서버·데이터) | E0·E7·N3·MaxSubs·랜드마크 데이터 | 0.25 |
| | 메인 앞당김 5개 (영어 데이터 + 오프라인 검사) | 0.3 |
| | 서브 18개 데이터 (새 12 + 당김 6) + 오프라인 검사 (중복 지급 0, 재접속, 진영 바꾸기) | 1.3 |
| | E12 숲 일일 + 검사 (휴가·상자 레벨대) | 0.4 |
| | E11 게시판 서버 + 검사 (중복 지급, 하루 경계, 거리, 원격 검증) | 1.0 |
| | **합계** | **약 3.25일** |
| 개발 1 (NPC·게시판·화면) | 게시판 2곳 (임시 판 + SurfaceGui, 기존 승인 UI 부품·UIKit 대체 그림) + ProximityPrompt + 카드 창 | 1.0 |
| | 퀘스트 목록 줄 늘리기·'Job' 표시·폰 749×361 스크롤 | 0.3 |
| | 랜드마크 좌표 (지도 v2), 이름만 쓰는 말하는 이 | 0.2 |
| | 디버그 레벨로 Lv1→25 한 바퀴 (빛·뿔, PC·폰) | 0.5 |
| | **합계** (새 그림 없음, 게시판 3D 소품은 이미지 생성 1 키트(A23-47)가 나오면 교체) | **약 2일** |

**날짜 (안, 10/12 점검에서 beta_board 개발 2 줄 — 스킬·펫·GOOSE-Q — 과 맞춰 확정)**
- 10/07 검수: 이 문서 영어 줄 확정
- 10/16 개발 2: E0·E7·E12·N3 (story_depth E0~E6과 같은 날)
- 10/17~18 개발 2: 메인 앞당김 + Lv10~25 서브
- 10/19~20 개발 2: E11 서버
- 10/21 개발 2: Lv5~10 서브(S6, XR1, H2, R5)
- 10/15 개발 1: 랜드마크 좌표
- 10/21~22 개발 1: 게시판 화면
- 10/23 개발 1: 한 바퀴 플레이
- 10/24: 마감

**늦으면 빼는 순서 (아래부터):** H2·R5 → S6·XR1 → H6·R7 → GW7·GW8 → 게시판 3D 판(목록 줄의 "Job Board" 버튼으로 사냥터 안 어디서나 고르기) → GW4~GW6
- **끝까지 지킬 것:** E0, 메인 Lv25까지, E12, 게시판(최소판), Lv10~15·15~20·20~25에 서브 1개 이상

**정식(12/19) 또는 장인 업데이트**
- 유적 게시판과 Lv25+ 일일 줄, 4장 서브(R2, SR1 등)
- 장인 퀘스트(N1·N2·N3 장인판, N4·N5, "First Harvest"): `Gather` 목표, `gathering_2026-10-06.md`
- PvP 의뢰(S10 현상수배 KO, S11 원한 자루): KO·Sack 목표가 새로 필요
- 함께 잡기(S7·S12): CoopKill 새로 필요
- 재료 납품 의뢰(고블린 이빨 등): Deliver 목표 새로 필요
- 게시판 칭호(E3), 메아리 장면(E8·E9)

**검수 판정 (2026-10-06 저녁)**
- **이 설계로 간다.** 우선순위는 '끝까지 지킬 것' 줄(E0 → 메인 Lv25까지 → E12 → 게시판 최소판 → 레벨대마다 서브 1개 이상)을 먼저 끝내고, 나머지 서브는 위 '늦으면 빼는 순서'의 반대 순으로 채운다.
- **게시판 점수 = 0(A23-58 예외):** 게시판은 하루 10개씩 되풀이되는 의뢰라 명예·악명을 주면 계급 칭호(10·50·200·1000)를 농사로 올릴 수 있다. 그래서 [Kind]/[Sneaky]는 기울기 기록·토스트만 하고 점수는 양쪽 모두 0이다. 한 번만 하는 서브·메인·마을 퀘스트 선택은 A23-58대로 점수가 오르거나 깎인다. (→ A23-86 결정 1, 10/09: 지금은 하루 장부 Deeds 6점 안에서 명예·악명이 움직이고, 계급 농사는 하루 상한이 막음. 랭킹 점수는 여전히 0.)
- **'Sneaky' 그대로:** 8~12살이 흔히 쓰는 말이고 '나쁜 짓'보다 장난 느낌이라 맞다.
- **보상 수치:** 문서 기본값(초원 36골드+60XP, 숲 192+336, 하루 10개 전액 뒤 절반, 다섯 번째 30% 주문서 1장, 숲형 서브 B 192골드)으로 넣고 실측(A23-12 방식)으로 고친다. 숲 일일 RewardMinutes 3·ChestMinutes 6도 같은 방식.
- **N3:** A23-57대로 Factions를 빼고 빛·뿔 누구나 받게 한다(개발 2에 전달함).
- **일정 위험:** 개발 2 약 3.25일 + 개발 1 약 2일이 새로 생겼다. 스킬(A23-49·50)·이야기(A23-52·55)·지도 v2(A23-53)와 합치면 10/24 안에 다 들어가지 않을 수 있다. 장인(A23-57) 몫이 빠진 만큼을 빼고 **10/12 점검에서 실제 속도로 다시 계산**해 무엇을 정식으로 넘길지 정하고, 사용자에게 한 번에 묻는다.
