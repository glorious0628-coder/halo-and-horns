# A23-46 마을 사람 퀘스트 H1·R1·N3 + A23-57 장인 스위치 + A23-58 선택 점수 + 결말 단서·E0 — 서버 계약 (게임성 개발 2, 2026-10-07)

설계: `docs/design/town_npc_quests_2026-10-06.md` + `docs/design/story_depth_2026-10-06.md` §3·§5-⑥(검수 결정: 셋 다 M2_3 뒤, H1 3단계는 초원 왕 슬라임, 반전판 대사). 게임 글은 영어(A23-48). 오프라인 검사: `py tools/test_town_quests.py`(130검사, 변이 30/30), 맨손·조련사 검사와 같은 가짜 세계(`tools/fixtures/dev2_combat_world.luau`).

## 1. 퀘스트 (Config.StoryQuests.Defs, Subs 끝에 H1·R1·N3)
| id | 누구 | NPC | 단계 | 마지막 고르기 |
|---|---|---|---|---|
| H1 The Horns Are Up to Something | 빛 | Bright (빛의 성채) | Talk → Near WoodsGate **10초** → 왕 슬라임 2(초원) → Choice | 생일 젤리 반전: A "Tell everyone the truth" / B "Keep the rumor going. It's more fun!" |
| R1 The Halos Are Up to Something | 뿔 | Smokey (뿔 소굴) | Talk → Near Fountain(교차로) **15초** → 슬라임 6 → Choice | 불꽃 쇼 반전: A/B는 H1과 같음 |
| N3 Both Sides Are Suspicious | 모두(Factions 없음, A23-57) | Tiny (교차로) | Talk → Near HaloBridge → Near HornsBridge → 사냥 골드 30 → Choice | A "Send both sides a peace letter" / B "Sell more spy glasses to both!" |

- 열림: `Requires.Done = { "M2_3" }` + 진영. 한 번만(Done). 주간 랭킹 점수 없음(A23-23 D1).
- 보상: 끝에 **120골드 + 지금 레벨 XP 칸의 절반**(`Reward = { GoldN = 120, XPBar = 0.5 }`). 고른 쪽 보상: **A = 70% 강화 주문서 1**, **B = HP 물약 3 + 골드 60**. 선택 점수 1은 A23-58 규칙(4절), 장인 저장은 A/B 기록만(A6).
- 끝 줄은 질문(`Finish`): "So who started the rumor? …Does anyone remember?" 등.
- 장소(`Config.StoryQuests.Landmarks`): `WoodsGate` (474,0,0) = 고블린 다리 초원 끝 14칸 뒤(PvP 밖·레벨 문 밖), `HaloBridge` (0,0,-161) / `HornsBridge` (0,0,161) = 교차로 쪽 다리 끝. 다리(`Config.Map.Bridges`)를 옮기면 같이 옮긴다 — 검사가 20칸 넘게 떨어지면 실패.

## 2. 엔진 (StoryQuestService)
- **E4 `Near.Stay = 초`**: 1초 반복에서 반경 안이면 그때부터 잰 시간(`os.clock`, 세션 안에서만, 저장 안 함), 벗어나면 0부터. 줄은 Progress/Target = 초("Spy by the woods' edge 5/10 s"). 다른 때 부르는 Refresh(지역 바뀜·레벨 업)가 겹쳐도 두 번 세지 않는다.
- **E6 고른 쪽 보상**: `Choice.Good.Reward` / `Choice.Evil.Reward` = `{ Item = 아이템 id | Potion = "HP"|"MP", N, Gold }`. 장인 A는 Good 쪽, B는 Evil 쪽. 고른 기록(Pick)을 먼저 적고 점수 → 보상 → 다음(끝 보상). 한 줄 알림 "+Enhance Scroll 70%" / "+HP Potion ×3 · +60 gold".
- **`LootService.GrantItem(player, id, n)`**(새 공개 함수): `Config.Loot.Items` id 또는 물약 "HP"/"MP"를 n개(1~99), 드랍과 같은 상한·가득 참 알림. 준 개수를 돌려준다(이야기 깊이 E6·이스터에그 보상도 이것을 쓴다).
- **보상 칸 더함**: `Reward.GoldN`(정확한 골드), `Reward.XPBar`(지금 레벨 XP 칸 비율). 기존 `Gold`/`XP`(사냥 분)와 함께 쓸 수 있다.

## 3. 게임성 개발 1에게: NPC·대화 계약
1. **NPC 모델**: id `Bright`(빛의 성채 경비) · `Smokey`(뿔 소굴 망보는 꼬마) · `Tiny`(교차로 장인 길드 견습생). 이름은 `Config.StoryQuests.Speakers[id]`. 모델에 **CollectionService 태그 `StoryNpc`**(`StoryQuests.NpcTag`) + **속성 `NpcId` = id**. 서버는 모델 피벗(파트면 Position)에서 **16칸**(`NpcRange`) 안일 때만 Talk/Choose/Open을 받는다. 그 id의 NPC가 세계에 없으면 어디서든 된다(배치 전에도 퀘스트가 막히지 않게).
2. **대화**: NPC 프롬프트 → 그 NPC가 걸린 퀘스트 줄(`row.Story.Npc == id`)의 `StoryAction(questId, "Open")` → 서버가 `OpenPanel "Story" { Id, St }` → 지금 Story 창 그대로(단계 `Lines`·`def.Speaker`, Talk 단계는 확인 → `"Talk"`, 마지막은 Choice → `"Choose"` + `"Good"`/`"Evil"`, 장인 저장은 `"A"`/`"B"`). **Npc 단계는 저절로 뜨지 않는다**(앞 단계가 끝나도 창이 안 열림 — NPC에게 가야 함).
3. **퀘스트 줄**: `row.Story.Npc` = 지금 말 걸 NPC(그 NPC 머리 위 '!'), `row.Story.Guide` = 그 마을 zone id(`HaloTown`·`HornsTown`·`Crossroads`). 새 Guide 키 `WoodsGate`·`HaloBridge`·`HornsBridge`(+기존 `Fountain`)는 `Config.StoryQuests.Landmarks` 좌표 — 마커 길 안내(QuestTarget)에 추가해 주세요. 머물기 줄은 `ShowProgress` + 초 단위 Progress/Target.
4. 참고: 서브 줄이 `MaxSubs = 2`라 진행 중인 H1이 S2·S3 뒤에 가려질 수 있다 — A23-56 퀘스트 양 설계에서 검수가 정한다.

## 4. A23-58 자기 편답지 않은 선택은 내 점수 깎기 (모든 선악 선택)
- `StoryQuestService.pickScore`: 빛 = 착한 쪽 명예 +점수 / 나쁜 쪽 **명예 −점수**, 뿔 = 나쁜 쪽 악명 +점수 / 착한 쪽 **악명 −점수**. 반대 편 점수(빛의 악명·뿔의 명예)는 선택으로 움직이지 않는다(옛 'OddHalo/OddHorns'와 '빛이 나쁜 쪽 → 악명 +' 규칙 대신).
- 0 아래로 안 내려간다(실제로 깎은 만큼만, 0이면 알림도 없음). 알림 `StoryQuests.Text.OffSideHalo` "Not very angel-like! Honor -%d" / `OffSideHorns` "Too nice for a devil! Infamy -%d". `Config.GetTitle` 계급이 내려가면 한 줄 `RankDownHalo` "Your rank went down. Do good deeds to get it back!" / `RankDownHorns` "…Do devilish deeds to get it back!".
- 아이템·골드 보상은 그대로. PvP(`GrantFame`)·주간 판은 안 건드림(검사: 선택이 랭킹 서비스를 부르지 않음).
- 선택 안내: `ChoiceHint`(두 숫자 호출 그대로, 숫자 없는 문장으로 바꿈) + 새 `ChoiceHintHalo` "Left: Honor +%d · Right: Honor -%d (not very angel-like)" / `ChoiceHintHorns` "Left: Infamy -%d (too nice) · Right: Infamy +%d" — **개발 1: Panels 2725의 안내를 진영별 줄로 바꿔 주세요**(인자 Good.Points, Evil.Points).

## 5. 결말 단서 (story_depth §0-1·§2-1 베타 줄, 1a2475e)
- `Config.Story.Premise`(진영 카드 3줄) = "They say someone broke the Crown of Balance." / "Some who picked up its shards grew a halo. Others grew horns." / "Now each side says the other did it." 새 `Config.Story.OpeningRumor` 3줄 = "They say the Crown kept the world in balance." / "They say someone wanted it all to themselves." / "\"If I can't have it, no one can!\" CRACK." `OpeningAsk` = "Which side will you choose?". **오프닝(A23-44 다시 만들기)은 OpeningRumor 1~3 → Premise 2~3 → OpeningAsk 순서로 읽기.**
- M1_2 끝 "…And a braided band? Gold and purple.", M1_4 안내자 2쪽(빛·뿔 소문 줄) + 3쪽 장 끝 질문, M2_3 1쪽 "Halos and Horns tell the same story…" + 끝 "Two kids by the fountain…", M2_7 끝 질문(+ 뿔 줄 "Goblins grab for a boss…").
- H1: "…Who said so first?", 12쪽, "Happy birthday, S." 병 + 끝 뒤 `Clue` 토스트(손목 끈). R1: 금 망원경, 보라 불꽃·"signed 'B.'" + `Clue`. N3: "nobody saw it", 두 아이·벤치·작은 표식.
- 새 퀘스트 칸 `Clue`: 끝 줄·보상 줄 뒤에 한 줄 더(정보). Speakers `Kids` = "Bright & Smokey", Landmarks `KidsBench` (18,0,18).
- 아직 안 한 것(데이터가 생길 때): EG03 거위 줄, M3_3 크레용 토스트, EG14 Bench Detective(숨김 서브·칭호 = E3·E5와 같이), LinesBy(E2).

## 6. E0 옛 세이브 이전 (story_depth E0)
- 이야기가 없는 옛 세이브가 Lv10 이상이면 `StoryQuests.SkipChapters`({Lv10 → 2장까지, Lv25 → 3장까지})대로 그 장까지만 Done, 다음 장부터 시작(예전에는 Main 전체를 Done으로 해서 3장을 넣으면 통째로 건너뛰었다). 한 번만(`First.Migrated`), 지난 보상·점수 없음.

## 7. A23-57 장인 진영 스위치
- `Config.Features = { NeutralFaction = false }`, `Config.FeatureOn(name)`, `Config.Pickable(factionId)` = 새로 고를 수 있는 진영(빛·뿔, 장인은 스위치가 켜졌을 때만).
- 서버: FactionService 진영 고르기(`ChooseFaction`)·제단(`SwitchFaction` 대상) — 장인 요청은 다른 잘못된 요청처럼 무시 + 로그 한 줄(10초 묶음). ProgressionService 환생 대상 장인도 거절 + 로그. StoryQuestService는 장인 전용 서브(N1 장인의 손놀림, N2 길드 보급 장부)를 주지 않는다. **코드·데이터는 지우지 않는다**, 이미 장인인 시험 저장은 그대로(진영·N3 유지).
- `Config.FactionOrder`는 그대로(개발 1의 고르기 화면이 스위치를 읽어 카드 2장).
