# origin/dev2-kingfinish 2de1d1e4 (King Slime 보스 + 마무리 카드, A23-84/85) 독립 검증 — 게임성 개발 3, 2026-10-09

방법: 개발 2가 아니라 반박하는 쪽으로 읽음. 임시 worktree(`Game-gpverify`, origin/main a75ab917 + `git merge origin/dev2-kingfinish`)에서 코드를 읽고 전체 시험 85개를 `TEMP` 따로 한 줄로 돌림. 고치지 않음(개발 2 몫).

## real 문제
1. **(중간) 병합 상태에서 `test_gamepass` 정적 검사 2개가 실패** — `FinisherService.AddBankGold(…, "Finisher")`가 gamepass 시험의 "알려진 골드 지급 목록"에 없어서 `every XP / gold grant is a known one with its source` · `each earned grant keeps what was added for its line`가 깨져요(`extra {FinisherService.luau, AddBankGold, Finisher}`). 코드는 맞아요("Finisher"는 `Config.PassBoost.GoldSources`에 없어서 2배가 안 붙음, 변이 시험도 이미 확인). 고칠 곳: `tools/test_gamepass.py`의 기대 목록에 `("FinisherService.luau", "AddBankGold", "Finisher")` 한 줄 추가. 안 하면 main CI가 빨개져요.
2. **(중간) 지금 main과 합치면 충돌 3곳(src 2개)** — main에 CC·하루 장부(d6ec96e7)와 숲의 부름·새싹 맹세가 들어오면서 `Net.luau`(Names 목록: `CardAction` 줄 ↔ `FinisherPick` 줄), `Main.server.luau`(INIT/START 목록: `Deeds, ChoiceCard` 줄 ↔ `ScoreBudget, FinisherService, SlimeKingService` 줄), `tools/fixtures/board_offline.luau`(같은 Slime Prince 이름 고침을 양쪽이 함) 충돌. 둘 다 **양쪽을 다 남기면** 되는 이웃 줄 충돌이에요. 시험 JSON 충돌은 main 쪽을 쓰고 병합 뒤 다시 만들면 돼요.
3. **(낮음·설계) 하루 점수 상한이 두 개** — 마무리 카드는 `ScoreBudget`(PerDay **5**, proposed), A23-86 하루 장부 `Deeds`(PerDay **6**)가 새로 생겼어요. 합치기 순서(계약서 `choice_card_server_2026-10-09.md` §3): King Slime이 main에 들어온 뒤 `FinisherService`의 `ScoreBudget.Left/Take`를 `Deeds.Preview/Take`로 바꿔 상한을 하나(6)로. 안 바꾸면 같은 날 마무리 카드 5점 + 다른 되풀이 6점 = 11점이 들어가요.
4. **(낮음·튜닝) 체력 2500 · 5분** — 설계 문서가 "혼자 Lv5~8 약 4분"이라 했는데 `Lifetime` 300초라 혼자 Lv5는 거의 못 잡고 자리를 비우면 사라져요. 숫자는 "proposed, tune after play"라고 적혀 있어 위반은 아니고 플레이 뒤 확인 항목.

## 반박됨 (깨 보려 했지만 맞게 되어 있음)
- **1마리 보장**: `B.Rec ~= nil`이면 `appear`가 바로 false, `finish`는 `B.Rec`를 비운 다음에만 다음이 나올 수 있어요. `SpawnEvent`로 만든 몹은 `Event = true`라 일반 풀에서 제외(`aliveCountOf`)·다시 안 나옴(`noRespawn`), `Count = 0`이라 일반 풀 목표 0. Studio `DebugSpawn`도 이미 있으면 "already here".
- **초원에 사람 있을 때만**: `tick`이 `hunterHere()`(준비된 플레이어가 `SlimeMeadow`에 있음)일 때만 `appear`. 아무도 없으면 `NextAt`이 과거로 남아 "첫 사냥꾼이 오면" 나옴(시험 "waits for a hunter"). 자리 못 찾으면 10초 뒤 다시.
- **5분 뒤 사라짐**: `EndsAt = now + Lifetime(300)`, 지나면 `finish(false)` → `RemoveEvent(rec, fade, leaving)`(보상 없음), `Leave` 말, `Defeated` 신호 없음. 모델을 잃은 경우(HP>0, Alive false)는 처치가 아니라 Leave로 셈(시험 "a lost model is a Leave"). 다음 칸은 "마지막 등장으로부터 480초".
- **처치 보상**: 일반 `MonsterService` 처치 그대로(기여 조건 RewardMinHits 3 · RewardMinDamageFrac 0.5% · `XPCapBelowLevel` 8 — 호박 대왕과 같은 값), 드롭표 `Loot.Tables.SlimeKing`(고정 몫 SlimeCore×2·Jelly×4 + 확률), 새싹 보호(Lv5 미만·600초 미만은 노리지 않음) 코드 확인. Slime Prince 퀘스트·첫 70% 주문서는 `BigSlime` 그대로(KingSlime 처치는 세지 않음).
- **마무리 카드**: 직접 누른 기여자만(`info.Manual`, 자동 전투만이면 없음), 한 번에 한 장(`CARD.Open`), 고르기는 `FinisherPick(id, option)`을 서버가 id·옵션·속도(0.3초)·인자 수·Seconds+Grace 안인지·한 번만 확인, 닫기(`CARD.Open[player] = nil`)를 먼저 하고 지급. Help 젤리 2개(가방이 차면 판매값 4골드)와 Tickle 4골드가 **같은 값**(시험 확인), 골드 출처 `"Finisher"`는 2배 패스 대상이 아님. 점수는 내 편 +1(하루 상한 안), 반대 편 −1(0 바닥, 계급 하락 안내) — A23-58 그대로. 편 없는 사람은 보상만. Slime Prince에는 카드 없음(`Kinds = { SlimeKing = true }`).
- **아빠 대사(A23-85)**: "Who's bothering my kids?!" · "Okay, okay! Dad needs a nap!" · "Hmph! Bedtime, kids!" · 말풍선 "MY KIDS?!" "Dad's here!" "Big hug~" "Hmm. Kids?". 엄마·부인 언급 없음(시험이 mom/mother/wife 검사), 설교 없음, 가족 모양을 놀리지 않음, 무섭지만 장난스러움.
- **서버 권위**: 새 서비스에 클라이언트가 보내는 값으로 상태가 바뀌는 길은 `FinisherPick` 하나뿐이고 위처럼 검증돼요. 보스 등장·사라짐·보상은 전부 서버. Studio 도움 명령(`Finisher`, `SlimeKing`)은 `IsStudio()` 블록 안에서만 생겨요.

## 시험 결과 (병합 상태 a75ab917 + dev2-kingfinish 2de1d1e4, `TEMP` 분리, 한 줄로 85개)
- 82개 통과. `test_finisher` 120/120·변이 62/62, `test_slime_king` 74/74·변이 27/27, `test_gamepass` 185/186(위 1번), `test_board`·`test_weapon_first` 통과(내 Slime Prince 고침이 이미 main에 있음).
- 실패 3개: `test_costume_physics`, `test_skin_binding_studio`(은퇴한 도구, 의도된 실패), `test_gamepass`(real 1번).
- 실제 Roblox에서만 알 수 있는 것(시험 불가): 사당 `KingSpawn` 자리에 걸을 수 있는 땅이 있는지(없으면 hill → Config.Spawn으로 물러남), 모델이 `BigSlime` 몸 × 2.5로 보이는 모양, 폰 성능.

## 결론
병합 전에 개발 2(또는 병합하는 쪽)가 할 것: 위 1번(시험 목록 한 줄), 2번(충돌 이웃 줄 양쪽 남기기). 3번은 병합 뒤 순서대로. 보스·카드 자체는 규칙 위반을 못 찾았어요.
