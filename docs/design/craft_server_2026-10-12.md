# 장인 제작 서버 CraftService 설계 (게임성 개발 3, 2026-10-12)

근거: SPEC A23-127(제작은 장인만, 신화 T9)·A23-133(방어구·반지·펫 장비도 장인, 모든 글 키)·A23-56(실패 없음, 재료 안 잃음, 매크로·자동 불가, 품질 차이 작게)·A23-115·A23-119, `crafting_market_2026-10-11.md` §4(사다리·골드·XP), `save_v4_tables_2026-10-11.md`(Craft 표), `gather_server_2026-10-11.md` §1(채집 재료를 레시피에), 개발 4 `hammer_minigame_2026-10-12.md` §3(망치질 계약 — **그대로 받음**, 아래 §4).
상태: 설계(게임성 검수 판단 전). 숫자는 제안, 검수가 바꾸면 Config만 고친다.

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

## 3. 끝 (c->s `CraftFinish(id, hits)`)
- id = 지금 세션 id, 세션 하나에 한 번. hits = 숫자 5개(각 고리의 어긋남 ms, + = 늦게) 또는 false(안 누름). 숫자는 −400..400만, 다른 모양이면 그 칸 Miss.
- **시간 묶기(매크로 막기):** 고리는 누른 뒤 Rest 쉬고 다음이 시작되므로, 진짜 끝 시각 ≈ StartAt + 5×Ring + Σ(어긋남) + 4×Rest(안 누른 칸 = +200ms: 고리는 Good 늦은 끝까지 기다렸다 Miss로 넘어감 — 개발 4 확인 필요). 받은 때가 그보다 0.3초 넘게 이르면 거절(기록 `CraftEarly`, 세션은 시간 넘음 처리). 그래서 "모두 Perfect"라고 보내도 실제로 그 시간을 기다려야 한다.
- 점수(서버가 다시 셈, 클라 점수 안 믿음): e = |ms − 40|(입력 늦음 보정) → Perfect ≤ 70 · Great ≤ 130 · Good ≤ 200 · 그 밖·false = Miss. 3/2/1/0 합 ≥ 13 → **+2**, ≥ 9 → **+1**, 그 밖 **+0**.
- 사람 같지 않음: 5개가 모두 같은 숫자면 +0 + 기록 `CraftBot`.
- 시간 넘음: StartAt + 20초 안에 Finish 없음 → +0으로 완성. 나감·죽음도 +0으로 완성(재료는 이미 냄).
- 완성: 결과 넣기(Weapon → `LootService.AddSpare(player, tier, plus)`, Gear → Gear.Own, Item → GrantItems) → 제작 XP(레벨 오르면 여러 번) → `Craft.Made[id] += 1`, `Craft.Pend = ""` → s->c `CraftResult` + `CraftInfo` → 신호 `CraftService.Crafted(player, recipeId, plus)`(퀘스트·명성 ⑦이 들음).

## 4. 화면 계약 (개발 4 제안 그대로 + 조금 더한 칸)
- c->s `CraftStart(recipeId: string)` · `CraftFinish(id: number, hits: { number|false ×5 })`
- s->c `CraftSession { Id, Recipe, Strikes = 5, Ring = 1.2, Rest = 0.35, StartAt }` — StartAt = `workspace:GetServerTimeNow()` + 0.8.
- s->c `CraftResult { Id, Recipe, Kind, Tier?, Slot?, Item?, Plus, Grades = { "Perfect"|"Great"|"Good"|"Miss" ×5 }, XP, Lv, LvUp }` (Tier·Plus·Grades는 개발 4 안 그대로; Recipe·Kind·XP·Lv·LvUp을 더함).
- s->c `CraftInfo { Role, Lv, XP, Need, Made = { [recipeId] = n } }` — 들어올 때·결과 뒤(제작 창이 레벨·잠긴 레시피를 그림). 레시피 표 자체는 Config(클라도 읽음).
- 거절 = 알림 키 `Config.Craft.Text.{NeedLevel, NeedMats, NeedGold, Far, Busy, Full, Auto, NotArtisan}`. 결과 글("+1 Iron Sword")은 화면이 CraftResult로 만듦(서버 문장 없음).

## 5. 저장
- `data.Craft = { Smith/Alch/Tame = { Lv, XP }, Rep, Made, Pend }` — Pend는 짧은 글자라 v4 sanitize(모르는 납작한 칸 보존)가 그대로 지킴. 들어올 때 Pend가 알려진 레시피면 +0으로 완성, 모르는 글자면 비움.
- Rep(장인 명성 평생 점수)은 ⑦에서: 제작 XP만큼 더하는 안(봇 막기·주간 상한은 ⑦).

## 6. 다른 세션에 필요한 것
- **개발 2 (C1/C2):** `LootService.AddSpare(player, tier, plus) -> bool`, `LootService.SpareRoom(player, tier, plus) -> bool`(Spares 키 20·합 60), 새 재료 `KingJelly`·`ClatterGem` 드롭, Mythic T9. 그 전엔 무기 레시피가 꺼져 있음(함수 없으면 Weapon 레시피 거절 `Full`).
- **개발 4:** 위 §4 이름·모양. 제작 창은 `Config.Craft.Recipes` + `CraftInfo`로.
- **이미지 생성 1:** 길드 안 모루·솥·연구대 자리(태그 `CraftStation`, 속성 Role).

## 7. 시험 `tools/test_craft.py`(오프라인, 변이 포함)
스위치·장인만·역할만·Lv·재료·골드·자리 거리·자동 전투·세션 하나·분당 수·재료 먼저 빠짐·Pend 저장·점수 경계(70/130/200 ± 보정 40)·13/9점·모두 같은 수 = +0·너무 이른 Finish 거절·시간 넘음 +0·나감 +0·다음 접속 Pend 완성·XP 곡선·레벨업 여러 번·Lv30 상한·Made·CraftResult/CraftInfo 모양·알림은 키만·없는 재료 레시피 꺼짐·AddSpare 없으면 무기 거절.
