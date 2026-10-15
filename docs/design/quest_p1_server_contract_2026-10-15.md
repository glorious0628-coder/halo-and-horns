# 퀘스트 P1 서버 계약 — 묶음 2(첫 30분) ①~⑨ (게임성 개발 2, 2026-10-15)

근거: `docs/design/quest_bible_2026-10-15.md` v3 §3·§4~7·§11·§13, §15 '퀘스트 체감 규칙 14줄 + P1 제작 순서'. A23-199 장치(`quest_offer_server_2026-10-15.md`) 위에 쌓는다. 화면 = 개발 1(같은 번호끼리). 문장은 전부 `Config.StoryQuests`(중앙 영어), 코드에 글 없음.

## 0. 이미 있는 것 (그대로 씀)
- Sub `Offer = { Npc, Lines }` → 속성 `StoryOffers`, `OpenPanel "Offer" {Id, Npc}`, `StoryAction(Id,"Accept"|"Decline")`.
- 단계 `Pickup { Spot, Radius }` / `Deliver { Npc }`, `StoryAction(Id,"Pickup"|"Deliver")`, Deliver는 Panel 없으면 NPC 말 걸기로 건넴.
- 단계의 진영 덮어쓰기 `Steps[i].Halo/Horns/Neutral = { ... }` (stepOf).
- 완료는 `Story.Done[id]`를 먼저 저장한 뒤 지급(같은 id 두 번 지급 0). 단계 선물은 `Story.First["Give"..id..st]`.

## ① 계약 (이번 묶음에서 새로 생기는 것)

### ①-1 Offer 넓힘
| 항목 | 규칙 |
|---|---|
| Main도 Offer | 다음 본편 Def에 `Offer`가 있으면 자동 시작 안 함. 그 NPC가 `StoryOffers`에 들어가고, Accept 때 `Story.Main` 시작. 이미 진행 중인 옛 저장의 Main 트랙은 그대로 계속(Offer 건너뜀). |
| 진영별 NPC | `Offer.Npc`가 표 `{ Halo = "Gleam", Horns = "Smokey", Neutral = "Otto" }`이면 내 진영 것. 글 줄은 기존대로 `Lines.All/Halo/Horns/Neutral`. |
| 보상 미리보기 | `OpenPanel "Offer"` 페이로드에 `Reward = { Gold, XP, Items = { {Id,N} }, BagSlots }` — 실제로 줄 것만(규칙 11). 0/없음 = 키 없음. Gold/XP는 지금 레벨로 계산한 값(HuntValue·GoldN·XPBar). |
| 몸 없는 NPC | `[몸 필요]` NPC(StoryNpc 태그 + NpcId)가 월드에 없으면 그 Offer는 안 나옴(`StoryOffers`에도 없음). 기존 npcNear의 '몸 없으면 통과'는 Offer·Practice·Emote에선 쓰지 않음. |
| 거절 | 아무것도 저장 안 함, 다음 말 걸기에 다시 부탁(기존). 거절이 다른 줄(주선·Lv5)을 막지 않음(§11). |

### ①-2 새 단계 종류 (Obj.Type)
| Type | 필드 | 서버 판정 | 화면 몫 |
|---|---|---|---|
| `Practice` | `Spot`(Landmarks 키), `Radius`(기본 8), `Count`(기본 1) | 그 단계가 열려 있을 때, 기본 공격 스윙(새 신호 `CombatService.BasicSwing(player, pos, look)`, 맨손 펀치도)이 Spot 반경 안·Spot 쪽(내적 ≥ 0.3)이면 1. 몬스터·피해 없음 | 연습대(허수아비) 모델·맞으면 흔들림. 단계 동안 속성 `PracticeTool` = 퀘스트 id → 손에 '빌린 연습 도구' 모양(가방·거래·판매 없음), 단계 끝나면 "" |
| `Emote` | `Spot`, `Radius`(기본 10), `Allowed = { cheer = "Evil", wave = "Good", ... }` | `StoryAction(Id,"Emote",name)`: 열린 단계·반경 안·Allowed에 있는 이름. name의 값이 Pick(선악 쪽)으로 저장 | 그 자리에서 기존 무료 감정표현 버튼(PC/폰) → 실행 + 서버에 이름 보냄 |
| `Match` | `Target`(정답 모양 id), `Wrong = { id, id }`(오답 2) — 모양 표 `Config.QuestShapes[id] = { Shape = "Ring"/"Disc"/"Square"/"Diamond"/"Cross"/"Bars", Color }`(한 세트 안 Shape·Color 모두 다름) | 그 단계 Npc/Spot 근처에서 말 걸기 → 서버가 3개를 섞어 `OpenPanel "Match" { Id, Target, Options = {id,id,id} }`(정답 자리 기억, 클라는 모름). `StoryAction(Id,"Match","1"~"3")`: 맞음 = Fx `MatchHit { Id }` + 다음 단계, 틀림 = Fx `MatchMiss { Id, Pick }`(재료 손실 0, 다시 고름) | 맞추기 창 — 개발 1 |
| `Timing` | (없음) — 통과 기준 `Config.StoryQuests.TimingPass = 3`(5번 중) | 근처에서 말 걸기 → `OpenPanel "Timing" { Id }`(서버가 연 시각 기억). `StoryAction(Id,"Timing","Good/Tries")`: Tries = 5, Good ≥ 3, 연 뒤 ≥ 2초면 Fx `TimingHit { Id }` + 다음 단계, 아니면 Fx `TimingMiss { Id }`. 재료는 통과 때만 소비 | CraftView 연습 모드 5번 — 개발 1 |
| `Learn` | `Slot`(기본 "Q") | 그 진영 스승에게 말 걸어 배움이 일어나면 통과(`StoryQuestService.Event "SkillLearned"`, Past = 이미 배운 저장은 바로 통과) | 기존 SkillLearned Fx 그대로 |

### ①-3 배움 문(Lv5 시험)
- `Config.Skills.Learn.Gate = { Q = "M1_3" }`: Q는 그 퀘스트가 **Learn 단계에 있거나 끝났을 때만** 스승에게서 배움. Lv5가 돼도 시험 전이면 `SkillLearnReady` = 0, 목표 줄 = "스승에게 시험 받기"(NextLearn 대신 새 줄 `NextTest`).
- 환생·스승 몸 없음·Learn 꺼짐 = 기존대로 바로 열림. 이미 Q를 가진 저장은 회수 0.

### ①-4 개인 장면 기록 (규칙 3~5, 13)
- 저장 `Story.Flags = { [key] = 값(문자열) }` — 내 등불·팔찌·왕관 같은 개인 결과. 다른 사람·서버 상태를 바꾸지 않음.
- 단계 필드 `SetFlag = { Key, Value }`(또는 Choice 쪽마다 `Flag = "값"`): 그 단계가 끝날 때(저장 뒤) 기록.
- 속성 `StoryFlags` = `"Lamp=Mine,Crown=Paper"`(키 정렬) — 재접속 때 화면이 복원.
- Fx `StoryScene { Id, Key, Value }` — 기록하는 그 순간 1번(보상 아님, 다시 봐도 지급 0).

### ①-5 보상 원장
- 퀘스트 보상 = 기존 `Done[id]` 먼저 저장(1회). 진영 변경해도 id가 같으면(M1_3·M1_4) 재지급 0.
- 단계·장면 보상 = `Story.Paid[key] = true` 먼저 저장 후 지급(`Give…`/`Top…`도 이쪽 규칙). 실패(가방 가득 등) = 표시 지우고 다음 접속 재시도(기존 RetryGifts 확장).
- 새 행의 금액은 비워 둠(바이블 §3 '빈칸을 확정값처럼 배포 금지'): 새 의뢰 Reward 없음(기록만) → 숫자는 최종 검수가 정하면 Config 한 줄.

### ①-6 ID·앵커 (설명용 → 최종 키)
| 바이블 | 서버 id | 부탁 NPC(NpcId) | 앵커(Landmarks) |
|---|---|---|---|
| H00/R00/N00 | 첫 임무(TutorialStep) | Hallie / Magpie / Kit(새 몸) → 스승 | 새 TutorialStep `Teacher = 4`(빛·뿔: 안내자 수락 → 스승 인사 → Forge) |
| H00a/R00a/N00a | `H_Basics` `R_Basics` `N_Basics` (Sub) | Gleam / Smokey / Otto | `PracticeH` `PracticeR` `PracticeN` (스승 옆 연습대) |
| H01/R01/N01 | `M1_1` (Main, Offer 추가) | Otto | 기존 |
| H02 / R02 | `H_Band` / `R_Band` (Sub, Lv3) | Bright / Smokey | `BandRibbon`(빛 리본 자리), `PoseSpot`(뿔 포즈 자리) |
| HS01/RS01/NS01 | `HS01` `RS01` `NS01` (Sub, Lv3, Basics 뒤) | Gleam / Smokey / Otto | 손수건→Bright, 단추→Rex(새 몸), 바퀴→Kit |
| Lunch1 | `Lunch1` (Offer로 바꿈) | Tiny | `Lunchbox` |
| H03/R03/N03 | `M1_3` (Main, 진영별 단계, Offer at 스승, Lv5) | Gleam / Smokey / Otto | `LostBag`(빛 주민 짐), Rose 소포, 장인 작업대 |
| H04/R04/N04 | `M1_4` (Main, 진영별, Offer) | Bright / Smokey / Tiny | `LampH` `LampR` `LampN` |
| N0 준비 | `N0`/`N0A`/`N0T` (Offer at Otto, Lv3) | Otto | 주문함 |

새 몸(TownNpcs 임시 기본 몸, 최종 외형 전): **Hallie**(빛 마을 스폰 옆), **Magpie**(뿔 마을 스폰 옆), **Kit**(교차로 Forge 옆), **Rex**(뿔 마을). 위치는 Config 한 줄(바꾸기 쉬움).

### ①-7 옛 저장 이관 (§11, 서버 ⑨에서 시험)
- `Story.Schema` 없음 = 1 → 2로 한 번 옮김. 버전 `Data.Version` 그대로.
- Main 트랙이 이미 M1_1/M1_3/M1_4에 있으면 Offer 없이 계속. M1_3 옛 단계: St1(Lv 대기) → 새 St1(사냥 4), St2(스킬 맞히기) + Q 보유 → 새 시험을 사냥부터(배움 단계는 Past로 바로 통과), 보상 1회.
- Lunch1 옛 St1(Tiny Talk) → 새 St1(사냥), St≥2 → St-1(Talk 단계가 Offer로 옮겨 감).
- 첫 임무 TutorialStep 0~3은 그대로 이어짐(빛·뿔의 Teacher 단계는 새 수락부터).

## 나머지 순서 (서버, 끝마다 SHA + 화면 몫 목록 → 개발 1)
② 안내자 몸 3 + 첫 임무 Teacher 단계 + `H/R/N_Basics`(Practice) + 첫 무기 1회
③ M1_1 Offer, `H_Band`/`R_Band`, Lunch1 Offer화(거절해도 주선 안 막힘)
④ Match·Timing 공용 판정 + N0 준비(주문함)
⑤ M1_3 진영별 시험(BasicKill Slime4 + 도움1) → Learn 문
⑥ Emote 단계(R_Band 포즈, 장소 감정표현)
⑦ M1_4 등불 선택 → Flags·StoryScene(빛 손인사·등불 / 뿔 종이 왕관·Rose 웃음 / 장인 바퀴·약·아기 슬라임)
⑧ 짧은 추격·호위(청크 3, ② ~ ⑦ 뒤)
⑨ 이관·계측(첫 수락·Lv5·배움·지선 수락·실패/복구 시각 → TelemetryService)

## 결과 (10/15 저녁, 가지 dev2-quest-p1) — ①②③④⑤⑥⑦⑨ 서버 끝, ⑧ 다음
| 번호 | 서버가 한 것 | 이관 |
|---|---|---|
| ① | Main Offer, 진영별 Offer.Npc, 몸 없는 NPC는 Offer 없음(본편은 몸 없으면 예전처럼 저절로 시작), Offer 패널 Reward, AcceptScene, 새 단계 Practice/Emote/Match/Timing/Learn, Story.Flags + 속성 StoryFlags + Fx StoryScene, LearnOpen | — |
| ② | 안내자 몸 Hallie/Magpie/Kit(+Rex), 첫 임무 = 안내자 말 걸기로 열림(줄 탭·자동 창 없음, 몸 없으면 예전), TutorialStep Teacher=4(빛·뿔: 스승 만나기 → Forge), H/R/N_Basics(스승 시범 → 연습대 한 번 → 반납) | DataService가 4 유지 |
| ③ | M1_1 = Otto 부탁(진영별 말), Lunch1 = Tiny 부탁 + 실제 Pickup(M1_1 뒤에도 늦은 수락), H_Band(Bright 보여주기/숨기기, Band 깃발), R_Band(포즈 자리에서 cheer/wave, Crown=Paper/Bow) | Schema 2 Lunch1 한 칸 앞으로 |
| ④ | N0/N0A/N0T = Otto 부탁(Lv3) → 채집 → 주문표 맞추기(Knot/Gem/Patch) → 제작 | Schema 5 제작 단계 한 칸 뒤로 |
| ⑤ | M1_3 = 스승 Lv5 시험(BasicKill Slime4 → 빛 LostBag→Folk1 / 뿔 SnackParcel→Tiny / 장인 자기 직업 제작→Tiny → 스승에게서 Learn), Q는 그 Learn 단계부터만 배움(Config.Skills.Learn.Gate), 다음 목표 줄 SkillTest | Schema 3 M1_3 처음부터 |
| ⑥ | Emote 단계(R_Band에서 사용) | — |
| ⑦ | M1_4 = 등불(Bright/Rose/Tiny 부탁 → 등불 자리 → 공용/내 빛 선택 Lamp 깃발 → 반응 → [Claim]), 시험 도움 장면 Help=Bag/Prank/Smith·Alch·Tame | Schema 4 M1_4 등불부터(Claim 기다리던 건 그대로) |
| ⑨ | Telemetry QuestAccept(분)·QuestDecline·QuestMiniMiss·MinutesToFirstSkill | — |

### 화면 몫 (개발 1)
1. 몸: TownNpcs에 Hallie(빛 스폰 옆)·Magpie(뿔 스폰 옆)·Kit(모루 옆 Side 7)·Rex(뿔 마을) 기본 몸 + Talk. Folk1이 이제 StoryNpc(라벨 Neighbor, TownFolk 태그도 유지).
2. 첫 임무 줄: TutorialStep 0 = "Talk to Hallie" + `GuideNpc`(안내자 NpcId) — 줄 탭은 길 안내만(서버가 RequestTutorial 무시). TutorialStep 4 = "Meet Sir Gleam at the town gate" + `GuideNpc`(스승). Welcome 창은 안내자에게 말 걸면 OpenPanel "Welcome".
3. 연습대: Landmarks PracticeH / PracticeR, PracticeN = 모루 기준 Behind -8, Side -7(TownNpcs.Spot과 같은 식; StoryLandmark 모델을 두면 그 자리). 속성 `PracticeTool` = 퀘스트 id인 동안 손에 '빌린 연습 도구'(T1 모양, 가방에 없음). Accept 때 Fx StoryScene {Key="Demo", Value=스승 NpcId} = 스승 기본 공격 한 번.
4. 물건 자리: LostBag(초원 입구), SnackParcel(Rose 옆), Lunchbox, LampH/LampR/LampN, PoseSpot — Pickup 단계일 때 물건+줍기 프롬프트, 등불 모양, 포즈 자리 표시.
5. Emote 단계: 그 자리에서 cheer/wave 버튼(PC/폰) → 감정표현 실행 + StoryAction(Id,"Emote","cheer"|"wave").
6. 장면(StoryScene / StoryFlags 복원): Crown=Paper(종이 왕관 + Rose 웃음)·Bow, Band=Show/Hide(Bright 손목 숨김/까치발), Lamp=Common(주민 손인사·등불 켜짐, 빛 편은 빛이 후광에 닿음)/Mine(내 빛·그림자 장난), Help=Bag(주민 큰 손인사)/Prank(리본 튀고 Tiny 웃음)/Smith(바퀴 굴러감)/Alch(Tiny 약 마시고 뜀)/Tame(아기 슬라임 간식 먹고 다가옴).
7. 다음 목표 GoalKind "SkillTest"("Next goal · Take Sir Gleam's test"): Lv5인데 시험 전. SkillLearnReady는 시험 Learn 단계 전엔 0.
