# 저장 v4 새 표 묶음 (게임성 개발 3 안 → 게임성 개발 2 합의용, 2026-10-11 밤)

근거: SPEC A23-127·A23-133·A23-134·A23-119, `origin/api/dev2-crafting-design:docs/design/crafting_market_2026-10-11.md` §2·§4·§6-2,
`docs/design/gathering_2026-10-06.md` §6, `docs/design/gameplay_remaining_2026-10-11.md` C-1, 코드 main ca7554ae
(DataService.fillDefaults·migrate, PetService.Sanitize, LootService.sanitize, Config.SanitizeStats).
상태: **합의됨(개발 2 답 2026-10-11 밤, 맨 아래 '합의')**. 코드 = 가지 `dev3-v4-tables`(Version 3 그대로, 동작 없음), 시험 `tools/test_save_v4_tables.py`.

## 0. 왜 한 번에
- `Config.Data.Version = 4`가 필요한 진짜 이유는 T9(마스크 9비트·WeaponEnhance[9])다. v3 서버는 9번째 비트를 '깨짐'으로 보고 무기를 모두 지운다(DataService 204-209).
- 새 표 자체는 v3에서도 Stats·Looks처럼 '추가형'으로 넣을 수 있다(fillDefaults가 모르는 키를 지우지 않음). 위험은 **모양이 나중에 바뀌는 것**과 **다른 서비스의 sanitize가 모르는 하위 키를 지우는 것**(예: PetService.Sanitize는 펫 줄을 새로 만들어 모르는 칸을 버림).
- 그래서 규칙: **v4 뒤에 쓰일 표의 모양과 sanitize를 지금 한 번에 정하고 넣는다.** 동작(서비스)은 나중 가지에서 붙인다. 뒤에 붙는 가지는 모양을 바꾸지 않는다.

## 1. 공통 규칙
1. 모두 `Config.Data.Defaults`의 추가형 칸 + `Config.Sanitize<이름>(t) -> t`(공유 Config, 서버·시험 같이 씀). DataService.fillDefaults가 `if Config.SanitizeX then d.X = Config.SanitizeX(d.X) end`로 부른다(SanitizeStats와 같은 꼴, 잘린 Config를 쓰는 오프라인 시험 보호).
2. sanitize는 **값을 만들어 주지 않는다**: 깨진 칸 = 기본값 또는 버림, 개수는 상한까지만 자름. NaN·inf·소수·음수 = 0.
3. **모양이 맞는 모르는 하위 키는 지우지 않는다**(LootService B10 규칙과 같음). 그래서 나중 코드가 키를 더해도 버전을 또 올리지 않는다.
4. 저장에는 **id·숫자만**(A23-111/133 L10n: 영어 문장 없음).
5. 물건은 늘 **한 곳에만** 있다(복제 막기): 여분 칸 / 낀 칸 / 거래소 원장 중 하나.
6. 키 모양 `"T:P"` = tier:plus(정수, 앞 0 없음). 장비 키 `"<칸>:T:P"`.

## 2. 표 (주인 = 쓰는 서비스, sanitize 작성 = 이 가지)
| 표 | 기본값 | 주인 | 모양·상한 |
|---|---|---|---|
| `Spares` | `{}` | 개발 2 (Loot 중복·Market·Shop), 개발 3 (Craft 결과) | `{ ["T:P"] = n }`, T 1..MaxWeaponTier(9, 모양 검사는 1..32 — 미래 tier 보존), P 0..Loot.MaxEnhance, n 1..20(키당), 합 60은 **쓰는 쪽이 거절**(sanitize는 안 지움) |
| `Market` | `{ Out = {}, In = {}, Done = {}, Day = 0, Lists = 0, Buys = 0 }` | 개발 2 | 설계 §6-2 그대로. sanitize도 개발 2 |
| `Craft` | `{ Smith = { Lv = 1, XP = 0 }, Alch = { Lv = 1, XP = 0 }, Tame = { Lv = 1, XP = 0 }, Rep = 0, Made = {} }` | 개발 3 | **역할마다 제작 레벨**(아래 질문 1). Lv 1..Config.Craft.MaxLv(30), XP 정수 ≥0, Rep = 평생 장인 점수(계급 5단계; 주간 판은 이미 `Rank.Artisan`), Made = `{ [레시피 id] = n }`(첫 제작 퀘스트·기록, id ≤32자, 키 64개까지) |
| `Research` | `{ Pts = {}, Sum = {} }` | 개발 3 | 조련사 연구력. `Pts[가족] = 점수`, `Sum[가족] = 소환 횟수`. 가족 = QuestKind id(≤24자, 키 32개까지), 정수 0..1e7 |
| `Gather` | `{ Day = 0, N = 0, Bloom = 0, Gift = 0, Total = 0, FirstBloom = false }` | 개발 3 | Day = KST DayIndex, N = 오늘 채집 수(상한 400은 서비스), Bloom = 오늘 조각 꽃(≤3), Gift = 오늘 받은 나눔(≤10), Total = 평생 채집 수(다섯 번째 약초 꽃·퀘스트), FirstBloom = 보장 꽃 받음. 노드 쿨다운은 메모리만 |
| `Gear` | `{ Own = {}, On = { Armor = "", Ring = "" }, Pet = {} }` | 개발 3 | A23-133: 방어구·반지 + **펫 방어구·액세서리**. `Own[ "<칸>:T:P" ] = n`(칸 = Armor·Ring·PetArmor·PetAcc, T 1..16, P 0..MaxEnhance, 키당 20). `On.Armor/Ring = "T:P"` 또는 "". `Pet[펫 uid] = { Armor = "T:P", Acc = "T:P" }`. **낀 것은 Own에서 빠진다**(한 곳). 펫이 없어진 uid의 장비는 GearService가 PlayerReady에 Own으로 돌려줌(sanitize는 안 지움). 펫 장비를 Pets.List 안에 두지 않는 이유 = PetService.Sanitize가 모르는 칸을 버림 |
| `Buffs` | `{}` | 개발 3 | 연금 버프 물약: `{ [물약 id] = 끝나는 os.time }`, 2개까지. 불러올 때 지난 것은 버리고, 남은 시간이 Duration(180)보다 길면 잘라냄(늘리지 않음). 서버를 옮겨도 산 3분이 안 사라지게 |
| `Stats` | 그대로 `{ Auto, Order }` | 개발 3 (A-9) | 무료 초기화는 칸이 필요 없음(stat_points 설계 §2-4). 바뀌는 것 없음 |
| `Pets.List[uid].Roll` | 없음 = `{}` | 개발 2 PetService.Sanitize가 지킴 | 소환 펫의 게임 안 랜덤 능력치 `{ Spd = 5..10 }`(정수 %, 설계 §4). 지금 Sanitize는 줄을 새로 만들어 이 칸을 버림 → **v4 가지에서 Sanitize가 Roll을 지키게** |
| 무기 마스크·`WeaponEnhance`·`WeaponSeq` | — | 개발 2 (C1) | 9비트, 배열 1..9. v3→v4 이전은 바꾸는 것 없음(설계 §2) |

`Items`(물건 id → 개수)는 모양이 그대로다. 새 물건 id(채집 재료, 버프 물약 4종, Pet Treat, KingJelly, ClatterGem, A23-134 황금 알·깃털, 새 구역 SeaShell·CrystalShard)는 LootService B10 규칙으로 이미 보존되므로 v4에 묶이지 않는다. 단 **id 이름은 거래소 키 `I:<id>`와 레시피가 쓰므로 제작·채집 설계에서 한 번 정하면 바꾸지 않는다**(개발 3이 채집 설계에서 목록 확정).

## 3. 순서 (제안)
1. 개발 3 가지 `dev3-v4-tables`: Craft·Research·Gather·Gear·Buffs 기본값 + `Config.Sanitize*` + fillDefaults 호출 + 오프라인 시험(`tools/test_save_v4_tables.py`: 깨진 값·NaN·거대 값·모르는 키 보존·한 곳 규칙·Version 그대로 3). **동작 없음**(쓰는 서비스 없음) — Stats·Looks처럼 v3에서도 안전.
2. 개발 2 C1(T9·Mythic·Spares·Market·Pets.Roll·**Version 4**)이 1 위에서 버전을 올린다. 그러면 v4 커밋 하나에 모든 표의 모양이 이미 있다.
3. 그 뒤 가지(GatherService, CraftService, Market…)는 모양을 바꾸지 않고 동작만 붙인다.

## 4. 개발 2에게 묻는 것
1. 제작 레벨을 역할마다(Smith·Alch·Tame) 따로 — 설계 §4는 하나(`Craft = { Lv, XP }`). 직업을 바꾸면 Lv30 대장장이가 바로 Lv30 연금술사가 되는 것을 막으려고 나눔. 괜찮나?
2. PetService.Sanitize가 `Roll`(그리고 모양이 맞는 모르는 칸 일반)을 지키게 C1에서 고쳐 줄 수 있나? 아니면 내 가지에서 고칠까?
3. 순서 3(내 가지 먼저, C1이 버전 올림) 괜찮나? 아니면 C1을 내 가지 위에 만들어 커밋 하나로?
4. 개발 2 쪽에서 v4에 더 넣을 칸(예: 오토 싼 재료 하루 50개 `Shop = { Day, N }`, 거래소 퀘스트 표시)이 있나?
5. Spares 상한(키 20·합 60)을 Gear.Own에도 같게(키 20·합 60, 따로 셈) 쓸까?

## 합의 (개발 2 답, 2026-10-11 밤)
1. **제작 레벨은 역할마다**(Smith·Alch·Tame 각 `{ Lv, XP }`). Rep·Made는 셋이 같이 씀. (설계 §4의 `Craft = { Lv, XP }` 하나를 대신함)
2. **PetService.Sanitize의 Roll 보존은 개발 3 가지에서.** 펫 줄에는 '모르는 칸 일반 보존'을 하지 않고 **Roll만 명시**: `Roll = { Spd = 정수 5..10 }`, 모양이 틀리면 Roll 통째로 버림(값을 만들어 주지 않음). 기존 펫 시험을 다 돌려 통과 확인.
3. **순서:** 개발 3 `dev3-v4-tables`(Version 3, 동작 없음) 먼저 → 개발 2 C1이 그 위에서 **Version 4**(T9 마스크·WeaponEnhance[9]·Spares·Market sanitize). C1은 지금 바로는 아님(개발 2: A23-129 검토·서버 글 판정·황금 알 다음).
4. **v4에 더 넣는 칸 2개(주인 개발 2, 모양·sanitize는 개발 3 가지에 같이):**
   - `Shop = { Day = 0, N = 0 }` — 오토 싼 재료 하루 50(설계 열린 결정 9). Day = KST DayIndex, N 0..50.
   - `EggHonorAt = 0` — 황금 알(A23-134) 명예/악명 1시간 한 번 +5. os.time 정수 ≥ 0, ~~미래 값이면 0~~ → **미래 값은 지금(now)으로 자름**(게임성 검수 10/11: 0이면 서버끼리 시계가 몇 초만 달라도 '1시간에 한 번'이 바로 다시 열림. 늦게 열리는 건 괜찮고 일찍 열리면 안 됨; 가지 `dev3-gather`). 서버를 옮겨 다니며 다시 받는 것을 막으려고 저장에 둠.
   - 깃털은 Items id(예 `GooseFeather`)라 모양 변경 없음. 거래소 퀘스트 표시는 StoryQuest 기록으로 충분(칸 없음).
5. **Gear.Own 상한 = Spares와 같게:** 키당 20, 합 60은 쓰는 쪽이 거절(따로 셈). 낀 것(On·Pet)은 합에 안 셈.
- 검수 보고는 개발 3이 한 번에 한다.

## 구현 메모 (dev3-v4-tables)
- `Config.SaveV4`(상한 표) + `Config.Data.Defaults.{Craft, Research, Gather, Gear, Buffs, Shop, EggHonorAt}` + `Config.Sanitize{Craft, Research, Gather, Gear, Buffs, Shop, EggHonorAt}` + `Config.SanitizeSaveV4(d, now)`(DataService.fillDefaults 끝에서 부름). Config 맨 위 지역 변수는 `V4` 표 하나만 늘림(200개 한도).
- Gear.Own 키는 숫자를 그대로 다시 써서 합침(`"Armor:01:0"` = `"Armor:1:0"`), 지도 하나에 키 64개까지(정렬 순서로 같은 것만 남김). Buffs는 불러올 때 서버 시계로 지난 것 버림·180초 넘으면 자름·끝이 늦은 2개.
- 시험: 깨진 값·NaN·inf·글자·긴 id·모르는 칸 보존·두 번 고쳐도 같음·DataService 실제 불러오기 경로·PetService Roll. 변이 53개 모두 잡음.
