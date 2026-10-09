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

## 추가 — origin/dev2-clatter bc9a49da 가 2de1d1e4 위에 더한 차이 (게임성 개발 3, 2026-10-09)
방법: 더한 커밋만(1d44b1b2 필드 보스 엔진, d985a907 클래터 대장, bc9a49da 마무리 카드 → 하루 장부) 코드를 읽고, 임시 worktree(`Game-gpverify`)에서 origin/main 10c2b899 위에 `dev2-clatter`를 병합해 관련 시험 23개를 돌림. 고치지 않음.

### real 문제
1. **(낮음) 병합 시험 2개가 실패**
   - `test_gamepass` 정적 검사: 이번엔 **내** 쪽(`CommissionService`의 `AddBankGold(…, "Refund")` 되돌림)이 목록에 없어서였어요 → 54ceb04d에서 목록에 한 줄 추가해 main에 올렸어요(통과 185/186·변이 87/87). dev2-clatter의 `Finisher` 줄은 이미 목록에 있어 문제 없음.
   - `test_monster_bark`: `as uploaded: every monster kind draws its own bubble first … SlimeKing` — King Slime 몬스터가 생겼는데 `PENDING_ART`(그림 아직 안 올린 종류 목록)에도, 올린 말풍선 id에도 없어요. `art/review/monsters`의 King Slime 말풍선(189998dc)은 아직 업로드 id가 없음. 고칠 곳: 이미지 개발이 올려 `Config.UIArt` id를 넣거나, 그 전까지 시험 목록(`PENDING_ART`)에 `SlimeKing` 추가.
2. **(중간·설계) 클래터는 3번만 쳐도 전부 받아요** — `CaptainClatter` `RewardMinHits = 3`, `RewardMinDamageFrac = 0.005`(체력 20000의 0.5% = 100 피해)인데 XP·골드가 각 3,900(호박 대왕 300/150의 13배)이에요. 지나가며 3번 때리고 떠난 사람도 XP 3,900 + 골드 3,900(2배 패스면 7,800) + 확률 무기(T5 3%·T6 0.5%) + 왕관전 +20 + 주간 배지를 받아요. 다른 필드 보스와 같은 A23-27 규칙이지만 몫이 커서 무임승차 값이 커졌어요. 제안(개발 2): 클래터만 `RewardMinDamageFrac`을 0.02~0.03으로(체력의 2~3% = 같이 때린 사람 ~30명까지 허용).
3. **(낮음·설계) 왕관전 +20이 사람 수만큼 쌓여요** — `extraOne`이 `WarService.AddPoints(player, 20)`을 `poolN` 없이 불러서, 한 편 30명이 잡으면 그 편 점수통에 600점이 들어가요. 일반 몬스터는 `WarShare`/`poolN`(CR-M18, 한 번의 처치는 점수통에 한 번)으로 막아 둔 것과 달라요. 의도(편별 피해 몫을 따르는 큰 보상)라면 상한이 필요: `poolN = 20`이면 처치당 한 편 +20.
4. **(낮음) Captain's Badge 쓸 곳이 아직 없어요** — 설계 주석은 "T6 의뢰가 배지를 요구한다(A23-86 L)"인데 확정된 T6 주문(Knight Crest 30 + Bone 60, 검수 확정)에는 배지가 없어서 지금은 팔기(200골드)밖에 못 해요. 둘 중 하나로 정리 필요.

### 반박됨
- **마무리 카드 → 하루 장부**: `scoreOf`는 `Deeds.Preview(player, SIDE[option], points())`, `applyScore`는 `Deeds.Add`로 바뀌어 상한이 하나(6점)예요. `ScoreBudget.luau`·`Config.ScoreBudget`·기본값 삭제(옛 저장의 `data.ScoreBudget` 칸은 남지만 아무도 안 읽어서 해가 없음). 반대 편 −1·0 바닥·계급 하락 안내는 `Deeds`와 같은 규칙(finisher 시험 126/127·변이 64/64).
- **필드 보스 엔진 일반화**: 보스마다 `B[key]`, 한 종류에 한 마리(`Rec`), 일정은 보스별(`FirstDelay`·`Interval`·`Lifetime`), 사람 있을 때만(`hunterHere(key)`는 그 몬스터 구역), 시간 되면 떠남, 잃은 모델은 처치가 아님, 계절 없음 — King Slime 때 확인한 규칙이 그대로 키별로 돌아가요(`test_field_boss` 128/128·변이 42/42).
- **클래터 대장**: 나타남/사라짐/처치 말(아빠 가족 규칙과 무관, 엄마·가족 언급 없음, 설교 없음), 보스별 카드 글(`Cards[kind]`: Help = Enh70 1장(가방이 차면 값 300), Tickle = 300골드 — 같은 값), 편별 피해 몫 `Share`(두 편 합 100), 주간 보급(첫 처치 1개, 안 받은 주는 `Max` 2까지 쌓임, 가방이 차면 다음 처치로 미룸), 칭호 1/10/50(`Grant`는 한 번만), 드롭표(Knight Crest 3 고정 + 주문서·물약·무기 확률) 모두 코드와 시험이 맞아요.
- **서버 권위**: 새로 늘어난 리모트 없음(`FinisherPick`만, 이전과 같은 검증). Studio 도움 명령은 `IsStudio()` 안.

### 시험 (origin/main 10c2b899 + dev2-clatter bc9a49da, Main.server.luau 목록은 양쪽 다 남겨 해결)
통과: field_boss 128 · finisher 126 · choice_card 117 · commission 73 · board 95 · return 178 · attendance 98 · next_goal 52 · kill_log 28 · slime_prince 33 · english · story_text · weapon_first · halloween 608 · loot 547 · map_v2 · quest_window · notify_sound · ranking · beta_metrics · metrics (모두 변이 전부 잡음). 실패: gamepass(위 1번, 고침), monster_bark(위 1번).

### 결론
병합해도 규칙 위반은 없어요. 병합하는 쪽이 할 것: `Main.server.luau` 목록 양쪽 남기기, `monster_bark`의 King Slime 말풍선(그림 id 또는 `PENDING_ART`). 위 2번(클래터 무임승차)은 숫자만 정하면 되는 한 줄이라 병합 전에 개발 2와 정하는 걸 권해요.
