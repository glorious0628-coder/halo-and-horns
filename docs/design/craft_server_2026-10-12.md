# 장인 제작 서버 CraftService 설계 (게임성 개발 3, 2026-10-12)

근거: SPEC A23-127(제작은 장인만, 신화 T9)·A23-133(방어구·반지·펫 장비도 장인, 모든 글 키)·A23-56(실패 없음, 재료 안 잃음, 매크로·자동 불가, 품질 차이 작게)·A23-115·A23-119, `crafting_market_2026-10-11.md` §4(사다리·골드·XP), `save_v4_tables_2026-10-11.md`(Craft 표), `gather_server_2026-10-11.md` §1(채집 재료를 레시피에), 개발 4 `hammer_minigame_2026-10-12.md` §3(망치질 계약 — **그대로 받음**, 아래 §4).
상태: **게임성 검수 OK(10/12)** — 레시피 표 시작값 OK, 펫 방어구·액세서리 = 조련사, 무기는 개발 2 AddSpare 뒤. 바뀐 것: 두드림마다 `CraftStrike`(§3). 숫자는 Config라 시험 뒤 조정.

## 0. 한눈에
- 장인(진영 Neutral)만, 자기 역할의 레시피만: 전사 → **대장장이(Smith)**, 마법사 → **연금술사(Alch)**, 궁수 → **조련사(Tame)**.
- 자리(모루·솥·연구대) 12스터드 안에서 레시피 고르고 [Forge] → 망치질 5번(약 8초) → 결과 +0/+1/+2. **실패 없음, 재료 안 잃음.** 기다리는 타이머 없음.
- 제작 레벨은 역할마다(`data.Craft.Smith/Alch/Tame = { Lv, XP }`), Lv1~30, 다음까지 XP = floor(40 × Lv^1.5). 2배 경험치 패스는 제작 XP에 안 들음. 사냥 레벨과 따로.
- 스위치 `Config.Features.Crafting = false`(장인 길드 켜기와 같이, 검수).

## 1. 레시피 표 `Config.Craft.Recipes[id]`
`{ Role, Kind = "Weapon"|"Gear"|"Item", Tier?, Slot?, Item?, N?, Lv, Gold, Mats = { [itemId] = n }, XP }`. 재료 id가 `Config.Loot.Items`에 없으면 그 레시피는 꺼져 있음(목록에 안 보이고 시작 거절) — 새 재료(KingJelly·ClatterGem·SeaShell·CrystalShard)가 들어오는 대로 켜짐.

**③ 대장장이 무기(이번 덩어리)** — crafting_market §4 + 채집 재료(바뀜: SeaShell·CrystalShard는 새 구역 하나만 베타라 뺐고 채집 재료로 바꿈):
| id | Tier | 제작 Lv | 골드 | 재료 | XP |
|---|---|---|---|---|---|
| W1 | 1 | 1 | 10 | Jelly 5, CopperOre 2 | 10 |
| W2 | 2 | 1 | 40 | Jelly 10, Petal 3, CopperOre 4 | 20 |
| W3 | 3 | 5 | 200 | SlimeCore 6, Jelly 20, CopperOre 10 | 60 |
| W4 | 4 | 10 | 750 | GoblinTooth 20, BruteHorn 10, IronOre 8, OakLog 4 | 150 |
| W5 | 5 | 15 | 2,500 | Bone 30, KnightCrest 12, IronOre 15, OakLog 6 | 400 |
| W6 | 6 | 20 | 7,500 | KnightCrest 30, Bone 60, CaptainBadge 1, SilverOre 12 | 900 |
| W7 | 7 | 25 | 22,500 | KnightCrest 60, Bone 100, CaptainBadge 2, ClatterGem 1, SilverOre 25 | 2,000 |
| W9 | 9 | 30 | 60,000 | KnightCrest 100, CaptainBadge 6, ClatterGem 3, KingJelly 10, MoonCrystal 20 | 4,000 |
- 무기는 반(전사/마법사/궁수) 구분 없는 tier 하나(마스크와 같음). 결과는 **여분 무기 `Spares["T:P"]`**(개발 2 C1). 
- 나중 덩어리가 같은 표에 줄만 더함: ④ 연금 버프 물약(`Kind = "Item"`, Role Alch, 결과 `Items`), ⑤ Pet Treat(Role Tame), ⑥ 방어구·반지(`Kind = "Gear"`, Role Smith, 결과 `Gear.Own`) · **펫 방어구·액세서리는 조련사(Role Tame)** 로 제안(A23-127 '조련사 = 펫 쪽'; 검수가 대장장이로 정하면 Role만 바꿈).

## 2. 시작 검사 (c->s `CraftStart(recipeId)`)
순서대로, 하나라도 틀리면 거절 + `Net.NotifyKey("Config.Craft.Text.<키>")`(글 키만):
1. 스위치 켜짐, 레시피 있음(재료 id 모두 아는 것), 살아 있음, ClassChosen, **진영 Neutral**, 레시피 Role = 내 역할.
2. 열린 세션 없음(Busy), 시작 3초에 1번, 분당 6번.
3. 자동 전투 켜져 있지 않음(`AutoCombatEnabled`), 내 역할 자리 12스터드 안(Far). 자리 = 태그 `CraftStation`(속성 Role) 파트, 길드 안 자리가 생기기 전엔 교차로 모루(`ShopService.Anvil()`).
4. 제작 Lv ≥ 레시피 Lv(NeedLevel), 재료 모두(NeedMats), 골드(NeedGold).
5. 결과 자리 있음: Weapon = 여분 칸(`LootService.SpareRoom(player, tier, 2)` — 키 20·합 60, +2까지 들어갈 자리), Gear = Gear.Own 키 20·합 60, Item = ItemCap. 없으면 Full.
- 통과: **재료·골드를 그 자리에서 뺌**(`LootService.TakeItem`·`ProgressionService.SpendGold(…, "Craft")`) + `data.Craft.Pend = recipeId`(저장에 남는 짧은 글자 — 서버가 죽거나 나가도 다음 접속에 +0으로 완성) → s->c `CraftSession`.

## 3. 망치질과 끝 (최종 계약 10/12 — 게임성 검수·개발 4·개발 3 합의)
- 숫자·규칙은 **`src/ReplicatedStorage/Shared/CraftMini.luau`(개발 4) 한 곳**: 서버(CraftService)와 화면이 같이 씀. 시험 `tools/test_craft_mini.py`.
- **고정 일정:** 고리 i 목표 T_i = StartAt + i×Ring + (i−1)×Rest. 누름이 다음 고리를 옮기지 않음. 안 누른 고리는 Good 창이 닫히면(Closes) Miss.
- c->s `CraftStrike(id, i, ms)` — **누를 때만**, ms = 누른 때 − T_i(+ = 늦게). 서버는 고리마다 처음 것만 `{ Ms, At = 서버 시각 }`으로 적음(i = 1..5 정수, ms 숫자 −400..400 — 밖이면 안 받음).
- c->s `CraftFinish(id)` — 끝(또는 Skip = 바로 Finish = +0). 서버가 `CraftMini.Accept(strikes, StartAt, 핑 ms)`로 점수: 서버가 잰 (At − T_i) − ms 가 −50..250 + 1.5×핑 밖이면 그 칸 Miss, 안 온 칸 Miss, 앞 칸보다 Rest 안 지나 온 것 Miss. 판정 |ms − 40| ≤ 70 / 130 / 200, 3/2/1/0점, 13 이상 +2, 9 이상 +1.
- 덤: 5개가 모두 같은 ms면 +0(기록 `CraftBot`), 판정은 됐는데 도착이 안 맞은 칸 수 기록(`CraftMismatch`).
- 시간 넘음(StartAt + 20초)·나감·KO = 그 자리에서 +0 완성(재료 안 잃음). 결과 넣기·XP·Made·Pend 비우기·CraftResult·CraftInfo·Crafted 신호는 모든 끝에서 같음.

## 4. 화면 계약
- c->s `CraftStart(recipeId: string)` · `CraftStrike(id: number, i: 1..5, ms: number)` · `CraftFinish(id: number)`
- s->c `CraftSession { Id, Recipe, Strikes, Ring, Rest, StartAt }` — StartAt = `workspace:GetServerTimeNow()` + CraftMini.T.Lead.
- s->c `CraftResult { Id, Recipe, Kind, Tier?, Slot?, Item?, Plus, Grades = { ×5 }, XP, Lv, LvUp }`.
- s->c `CraftInfo { Role, Lv, XP, Need, Made = { [recipeId] = n } }` — 들어올 때·결과 뒤. 레시피 표는 Config(클라도 읽음).
- 거절 = 알림 키 `Config.Craft.Text.{NeedLevel, NeedMats, NeedGold, Far, Busy, Full, Auto, NotArtisan}`. 결과 글은 화면이 CraftResult로 만듦.

## 5. 저장
- `data.Craft = { Smith/Alch/Tame = { Lv, XP }, Rep, Made, Pend }` — Pend는 짧은 글자라 v4 sanitize(모르는 납작한 칸 보존)가 그대로 지킴. 들어올 때 Pend가 알려진 레시피면 +0으로 완성, 모르는 글자면 비움.
- Rep(장인 명성 평생 점수)은 ⑦에서: 제작 XP만큼 더하는 안(봇 막기·주간 상한은 ⑦).

## 6. 다른 세션에 필요한 것
- **개발 2 (C1/C2):** `LootService.AddSpare(player, tier, plus) -> bool`, `LootService.SpareRoom(player, tier, plus) -> bool`(Spares 키 20·합 60), 새 재료 `KingJelly`·`ClatterGem` 드롭, Mythic T9. 그 전엔 무기 레시피가 꺼져 있음(함수 없으면 Weapon 레시피 거절 `Full`).
- **개발 4:** 위 §4 이름·모양. 제작 창은 `Config.Craft.Recipes` + `CraftInfo`로.
- **이미지 생성 1:** 길드 안 모루·솥·연구대 자리(태그 `CraftStation`, 속성 Role).

## 7. 시험 `tools/test_craft.py`(오프라인, 변이 포함)
스위치·장인만·역할만·Lv·재료·골드·자리 거리·자동 전투·세션 하나·분당 수·재료 먼저 빠짐·Pend 저장·점수 경계(70/130/200 ± 보정 40)·13/9점·모두 같은 수 = +0·너무 이른 Finish 거절·시간 넘음 +0·나감 +0·다음 접속 Pend 완성·XP 곡선·레벨업 여러 번·Lv30 상한·Made·CraftResult/CraftInfo 모양·알림은 키만·없는 재료 레시피 꺼짐·AddSpare 없으면 무기 거절.

## 8. 구현 (10/12, 가지 `dev3-craft`)
- `src/ServerScriptService/CraftService.luau`(망치질은 `Shared/CraftMini` require), Config(`Config.Features.Crafting`·`Config.Craft`·`Config.CraftXPToNext`; 망치질 숫자는 Config에 없음), Net 원격 6개, Main 두 목록(GatherService 다음). CraftMini.luau·test_craft_mini.py는 개발 4 dev4-craft 44dba035와 같은 파일.
- 시험 `tools/test_craft.py`: 101 named·변이 56/56(핑 = 시작·두드림·지금 중 큰 값, 개발 4 44dba035)(도착이 안 맞으면 Miss·핑 무시·일정 틀림·서버 시각 대신 클라 시각 변이 포함). test_craft_mini 45·16/16.
- **켜는 가지에서 할 것(최종 검수 10/12):** 2배 XP 패스 설명(Config 약 4185 "Get 2x XP from everything you do")을 "Get 2x level XP, so you level up 2x faster. Crafting levels do not change. No stats are for sale."로 바꾸고, 시험에 '제작 켜짐이면 패스 글에 Crafting 줄' 정적 검사. 패스에 제작 XP를 넣을지는 최종 검수가 사용자에게 물음(답 바뀌면 다시).
- 허용(−50..250 + 1.5×핑)은 CraftMini.T(Early·Late·JitterMul) — 숫자 하나로 조정.
- **지표(게임성 검수 10/12):** 제작마다 Telemetry `CraftStrikeD`(값 = 두드림 (서버 ms − 클라 ms) 가장 큰 값, a = 가장 작은 값, b = 받은 두드림 수) → 10/17~20 시험 뒤 CraftMini 창(Early·Late·JitterMul) 조정. 베타는 지금 창 그대로. test_craft 102·58/58.
- **켜기 전 고친 것(게임성 검수·최종 검수 10/12):** ②저장 `Craft.Pend = { Id, Plus, Gold, Mats }`(낸 것 그대로; Config.SanitizeCraft가 지킴) — 레시피가 사라졌으면 골드(`CraftRefund`, 2배 아님)·재료를 돌려줌 ③끝에 자리가 없으면 번 +N을 Pend.Plus에 남기고 다음 접속·다음 시작에 그 +N으로 ④Item은 전부 들어갈 때만, Gear는 끝에서 칸 상한(합 60·키 20)을 다시 보고 전부 아니면 대기 ⑤스위치가 꺼져 있으면 들어올 때 아무것도 읽거나 쓰지 않음 ⑥엉뚱한 세션 id의 Finish는 0.5초 제한을 쓰지 않음. ①무기 레시피는 개발 2 AddSpare/SpareRoom 뒤, W7·W9는 ClatterGem·KingJelly(Loot.Items에 아직 없음)·T9 뒤. test_craft 122·69/69, test_save_v4_tables 100·58/58.
