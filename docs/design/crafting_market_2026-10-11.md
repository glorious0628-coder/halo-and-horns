# 제작은 장인만 + 몬스터 드롭 무기 + 하나의 거래소 (A23-127 설계, 게임성 개발 2, 2026-10-11)

근거: SPEC A23-127(결정), A23-115·A23-119·A23-111·A23-75·A23-11/12·A23-86·A23-110·A23-123, AGENTS(첫 임무 150골드, 능력치 판매 없음, 뽑기 없음).
코드 기준: 커밋 999531ad. 숫자 중 "지금"은 코드 값, "제안"은 검수가 정할 값이다. 이 문서는 설계만 한다(코드 변경 없음).

## 1. 한 줄 요약 + 바뀌는 규칙
- 한 줄: **무기는 몬스터가 떨구고, 장인(중립)만 만들고, 모두가 하나의 거래소에서 사고판다.**
- 빛·뿔 플레이어: 대장간에서 무기를 사지 않는다(`Config.WeaponShop.MaxSoldTier = 3` → 0). 무기는 드롭·거래소·장인에게서 온다. 오토의 의뢰(`Config.Features.Commission = false`)는 켜지 않는다.
- 장인(대장장이·연금술사·조련사): 제작이 이들만의 일이다. 재료는 직접 사냥하거나 거래소에서 산다. 만든 것은 거래소에 판다.
- 그대로인 것: 뽑기 없음(GDD §10-1), 능력치 판매 없음(A23-75), 강화 규칙(10/30/70%, 실패 50% 한 단계 하락·50% 유지, 파괴 없음, 최대 +10, A23-11/12/14), 1:1 직접 거래 없음(A23-127 ④), 골드→로벅스 없음(A23-127 ①), 2배 골드 패스 유지(A23-75), 물약 상인 Fizzby의 HP/MP 물약 25골드(`Config.Vitals.PotionPrices`)와 KO1 "Buy a potion".

## 2. 등급·티어 사다리
지금(`Config.Weapons`, `Config.WeaponInfo`):

| Tier | Damage | MinLevel | 등급 | 지금 얻는 곳 | 바뀐 뒤 |
|---|---|---|---|---|---|
| 1 | 8 | 1 | Common | M1_1/Forge 선물 | 첫 임무 선물(그대로, §5) |
| 2 | 15 | 1 | Common | 상점 150 | 드롭(첫 Slime Prince 보장) · 장인 |
| 3 | 38 | 5 | Fine | 상점 800 | 드롭 · 장인 |
| 4 | 88 | 12 | Rare | 드롭·의뢰 | 드롭 · 장인 |
| 5 | 200 | 20 | Epic | 드롭·의뢰 | 드롭 · 장인 |
| 6 | 450 | 30 | Epic | 드롭·의뢰 | 드롭 · 장인 |
| 7 | 1000 | 40 | Legend(진영색) | 없음("artisans, full launch") | **장인만** |
| 8 | 76 | 1 | Legend | 슬라임 대박 1/20000 | 그대로(대박만, A23-12) |
| 9 (새) | 2200 | 50 | **Mythic** | — | **장인만, 보스 재료** |

- 새 등급: `Config.WeaponGrades.Mythic = { Name = "Mythic", Stars = 6, Rank = 6, Color = (빨강-분홍, 이미지 개발이 고름) }`.
- 새 tier 9 이름(제안): `Crownforged Sword / Staff / Bow / Baton`. **`Config.WeaponNames`는 끝에만 붙인다**(저장 키 = 순서). 아이콘 `Weapon_<Class>_T9`는 그림 전까지 코드 대체.
- 신화 얻는 법: 대장장이 제작 Lv30 + 보스 재료(§4). 드롭 없음, 대박 없음.
- **저장 호환(중요):** 지금 DataService는 `MaxWeaponTier`보다 높은 비트가 있는 `WeaponOwnedMask`를 "깨짐"으로 보고 0으로 만든다(DataService 200~209줄). tier 9를 넣으면 옛 서버가 새 저장의 무기를 모두 지운다. 그래서 `Config.Data.Version = 4`로 올린다. 옛 서버는 새 기록을 거절한다(CR-L3). v3→v4 이전은 아무것도 바꾸지 않는다. 배포 때 모든 서버를 다시 시작한다.
- `Config.MaxCombatPower`(MaxWeaponTier 사용, test_beta_basics)가 커진다. 순위·전투력 표시 비율을 같이 확인한다.
- 방어구·액세서리: **코드에 없다**(CharacterVisuals의 Accessory는 Roblox 아바타 장식일 뿐). PvP 한 대 = 상대 **기본** MaxHealth × `HitPctOfMaxHP 0.10` × 힘 비율(0.8~1.5 clamp, `Config.PvP`)이다. 그래서 몬스터에만 듣는 능력치면 PvP 공정이 깨지지 않는다. 가장 작은 베타 모양(제안): 칸 2개 — **Armor**(몬스터에게 받는 피해 −5/−10/−15%) · **Ring**(최대 MP +10/+20/+30). 전투력(BB4) 숫자에는 넣지 않는다(괴롭힘 규칙 그대로). 모양은 '능력만'(아바타 장식 없음). 시간이 모자라면 베타 뒤(열린 결정 3).

## 3. 몬스터 드롭표 (빛·뿔 플레이어의 무기)
규칙(지금 코드 그대로): 기여자마다 따로 굴림, 황금 몬스터 ×`GoldenMult 3`(최대 100%), 해골 폐허 Crown Pit ×`LootMult 1.25`, `BelowLevel` = 그 무기 MinLevel 아래면 재료로 바꿔 줌, 대박 `Jackpot` 1/20000 T8(Slime).
가진 무기가 또 나오면 지금은 골드(`DuplicateWeaponGold` 4:300 5:1000 6:3000 7:9000 8:3000)다. **바뀐 뒤: '여분 무기'(Spares, +0)로 가방에 들어간다.** 거래소에 팔거나 오토에게 같은 골드에 판다(§5).

| 구역(레벨) | 몬스터 | 지금 무기 줄 | 제안 |
|---|---|---|---|
| 초원 1~9 | Slime | (대박 T8) | T2 0.002 · T3 0.001(BelowLevel Jelly 1) |
| | FlowerSlime | 없음 | 없음 |
| | BigSlime(Slime Prince) | 없음 | **첫 처치 T2 보장** · T2 0.02 · T3 0.015(BelowLevel SlimeCore 1) |
| | SlimeKing(보스 Lv8) | 없음 | T3 0.10(BelowLevel SlimeCore 2) · 새 재료 KingJelly 0.2 |
| 산호 해안 8~11(초안) | CoralCrab, Jellyfish | 없음 | T3 0.004 |
| | HermitCrab | 없음 | T3 0.012 · T4 0.001(BelowLevel SeaShell 2) |
| 고블린 숲 10~24 | Goblin(+SlingshotGoblin) | T4 0.001 | T4 **0.002** |
| | GoblinBrute | T4 0.005 | T4 0.005 · T5 0.0008(BelowLevel BruteHorn 1) |
| 수정 동굴 숲 14~21(초안) | CrystalLizard, CaveBat | 없음 | T4 0.002 |
| | GlowMushroom | 없음 | T4 0.004 |
| | CrystalGolem | T4 0.003(초안) | T4 0.004 · T5 0.001(BelowLevel CrystalShard 2) |
| 해골 폐허 25+ | Skeleton(+Archer) | T5 0.0005 | T5 **0.001** |
| | SkeletonKnight | T5 0.003 · T6 0.0005 | T5 **0.004** · T6 **0.001** |
| | CaptainClatter(보스) | T5 0.03 · T6 0.005 | T5 0.03 · T6 **0.01** · 새 재료 ClatterGem 0.1 · 주간 CaptainBadge 그대로 |
| 숨긴 할로윈 | Pumpkin/Ghost King 등 | T4 0.05 | 그대로(꺼져 있음) |

T7·T9는 드롭이 없다(장인만). KO1의 개인 King(Practice)은 보스 드롭이 없다(그대로).

**빠르기(보통 플레이어, 기준 `Config.Economy.KillsPerMinute = 12`, 황금 제외, 평균값):**
- T1: Forge 걸음 단계, 약 2분째.
- T2: M1_2의 첫 Slime Prince 보장, 약 6분째. 이 한 번만 손에 든 T1보다 세면 바로 낀다(새 글 키 `FirstDropWeapon`).
- T3(Lv5부터, 약 9분째 Lv5): 초원 한 마리당 0.85×0.001 + 0.15×0.015 ≈ 0.0031 → 약 320마리 ≈ 27분, King(8분마다) 포함 약 20분. 산호 해안 ≈ 0.0055 → 약 15분.
- T4(Lv12): 숲 0.8×0.002 + 0.2×0.005 ≈ 0.0026 → 약 385마리 ≈ 32분. 수정 동굴 숲도 약 33분.
- T5(Lv20, 보통 폐허 Lv25에서): 0.75×0.001 + 0.25×0.004 ≈ 0.00175 → 약 570마리 ≈ 48분(+클래터 3%).
- 옛 상점과 비교: T3 800골드 ≈ 초원 20분(Slime 3골드×12), T4 3000 ≈ 숲 16분(Goblin 16×12), T5 10000 ≈ 폐허 13분(Skeleton 65×12). 드롭은 더 느리다 → 그 틈을 거래소·장인이 채운다(§4 균형).
- 측정: 베타에서 `FirstDrop_T<n>` 분(§6 Telemetry)을 보고 P를 고친다(A23-12 "플레이 후 조정").

**첫 무기와 150골드:** 첫 임무 보상 150골드(`Config.Tutorial.QuestRewardGold`)는 그대로 둔다(AGENTS). 쓰임만 바뀐다: 나무 무기 사기 → **KO1 물약(25골드) + 저축(Lv5부터 거래소)**. 나무 무기(T2)는 바로 다음 이야기(M1_2) 첫 Prince에게서 반드시 나온다. 오토의 M1_1 대사가 이유를 준다: "Slime Princes ate the shard dust… and a weapon! Beat one!".

## 4. 장인 제작 사다리
공통:
- 장인 = 중립 진영(`Config.Factions.Neutral`, Warrior→Blacksmith, Mage→Alchemist, Archer→Tamer, `Config.IsTamer`). 베타에 들어가므로 `Config.Features.NeutralFaction`을 켠다(때는 검수).
- **제작 레벨은 따로**: 저장 `Craft = { Lv = 1, XP = 0 }`(추가형). 제작 성공마다 제작 XP. 사냥 XP·레벨은 그대로다. 2배 경험치 패스는 제작 XP에 안 듣는다(제안). 다음까지 XP = `40 × Lv^1.5`(제안), 최대 Lv30.
- 성공 규칙: **실패 없음, 재료 안 날아감**(A23-56). 망치질 미니게임 결과 → Good +0 / Great +1 / Perfect +2 강화로 나온다(상한 +10). 시간은 미니게임(약 10초)뿐, 기다리는 타이머 없음. 매크로·자동 전투로 못 한다(서버가 두드림 간격 검사).
- 결과물은 **여분 무기(Spares) `"tier:plus"`**로 가방에 들어간다 → 직접 쓰거나(그 tier가 없을 때) 거래소에 판다.
- 장소: 교차로 장인 길드 모루(`Map.Landmarks.ArtisanGuild.Anvil`, 지금 오토 자리).

대장장이 무기(제안, 골드 ≈ 기준가 25%):

| Tier | 제작 Lv | 골드 | 재료(어디서) | 제작 XP |
|---|---|---|---|---|
| 1 | 1 | 10 | Jelly 5(Slime) | 10 |
| 2 | 1 | 40 | Jelly 10, Petal 3(FlowerSlime) | 20 |
| 3 | 5 | 200 | SlimeCore 6(Prince), Jelly 20, SeaShell 10(산호) | 60 |
| 4 | 10 | 750 | GoblinTooth 20, BruteHorn 10(숲) — 옛 의뢰 재료 | 150 |
| 5 | 15 | 2,500 | Bone 30, KnightCrest 12(폐허), CrystalShard 20(수정 숲) | 400 |
| 6 | 20 | 7,500 | KnightCrest 30, Bone 60, CaptainBadge 1 | 900 |
| 7 Legend | 25 | 22,500 | KnightCrest 60, Bone 100, CaptainBadge 2, ClatterGem 1 | 2,000 |
| 9 Mythic | 30 | 60,000 | KnightCrest 100, CaptainBadge 6, ClatterGem 3, KingJelly 10 | 4,000 |

- 새 재료(이름): `KingJelly`("Royal Jelly", King Slime 0.2, Sell 60) · `ClatterGem`("Old Crown Gem", Captain Clatter 0.1, Sell 400). 초안 재료 `SeaShell`(Sell 4)·`CrystalShard`(Sell 8)은 새 구역 가지에서 온다.
- CaptainBadge는 한 사람 한 주 1개(`Weekly Max 2`)라서 장인은 거래소에서 사냥꾼 배지를 모은다 → 사냥꾼에게 보스를 잡을 이유.
- 방어구·반지(열린 결정 3이 '예'면): Armor/Ring 각 3단(Iron Lv8 / Crystal Lv16 / Spirit Lv24), 재료는 같은 구역 재료.

연금술사 물약(버프, 180초, 같은 종류는 시간만 새로 시작, 겹치지 않음, 한 번에 2병):

| 물약 | 제작 Lv | 효과 | 재료·골드 |
|---|---|---|---|
| Might Tonic | 1 | 몬스터에게 주는 피해 +10% (PvP 없음) | Jelly 5, Petal 3, 20 |
| Guard Tonic | 3 | 몬스터에게 받는 피해 −10% | SlimeCore 2, SeaShell 3, 30 |
| Lucky Tonic | 8 | 재료 줄 확률 ×1.25 (무기·주문서·대박 줄 아님) | Petal 5, CrystalShard 3, 60 |
| Wisdom Tonic | 12 | 사냥 XP +10% | GoblinTooth 5, Bone 3, 100 |

빠르기 물약은 PvP 추격(A23-86 결정 4) 때문에 베타 뒤. HP/MP 기본 물약은 Fizzby가 그대로 판다.

조련사(베타 가장 작은 판):
- 연구력: 조련사가 잡은 몬스터 가족(QuestKind 기준)마다 1점. 단계 50/150/400/1000/2500.
- 소환: 연구 2단계 + 재료(Slime 가족: Jelly 30, SlimeCore 5) → 그 가족 펫, 능력치(걷기 +5~10%) 게임 안 랜덤(로벅스 없음, A23-115). 베타는 3D가 있는 Slime 가족만. 다른 가족은 펫 3D가 생기면.
- 제작품: **Pet Treat**(Jelly 5, Petal 2 → 3개, 펫 XP +20). 거래소에 팔 수 있다. 펫 자체는 팔 수 없다(Bound).

균형: T4 재료 = 숲 약 10분(Tooth 0.4, Horn 0.5) + 750골드 + 재료값 약 300 → 기준가 3,000에 팔면 수수료 뒤 약 1,650 남는다. 드롭 평균 32분보다 빠르니 장인이 시장을 채운다. 장인 친구가 없어도 T1~T6는 드롭, T8은 대박으로 오른다. T7·T9만 거래소를 거친다.

## 5. 오토(NPC 대장간)·의뢰 다시 설계
- 오토가 하는 일: ① 재료 사기(지금 `SellMaterials` 그대로) ② 여분 무기 사기(옛 `DuplicateWeaponGold` 값, 출처 "Sale" → 2배 안 됨) ③ 가진 무기 바꿔 끼기(지금 `UpgradeWeapon`의 다시 끼기) ④ 장인 안내(제작표 보기만, 길드 가는 길) ⑤ 싼 재료 3종(Jelly·Petal·SeaShell)을 Sell×4에 하루 50개까지 팔기(장인 연습용, 열린 결정 9).
- 수리 없음(내구도 없음), 파괴 없음.
- `Config.WeaponShop.MaxSoldTier = 0` = "팔지 않음, 끼기만". 지금 ShopService는 0이면 끼기까지 거절하므로(48줄) 0을 허용하도록 고친다. T1 첫 선물(Forge 단계, `QuestService.ForgeGift`)과 M1_1 `GiveWeapon = 1` 안전망은 그대로 둔다(첫 임무 보상, 오토가 만드는 것이 아님 — "Guild starter gift").
- 의뢰: `Config.Features.Commission = false` 유지, `Config.Tutorial.Ladder.Hooks`의 Commission 줄을 뺀다. 파일은 베타 뒤 지운다(Main 목록·require 먼저 빼기).
- 옛 저장: 산 T2/T3·의뢰 무기·+N은 **그대로 가진다**(마스크 그대로). 옛 "무기 팔기"(T2~3 가격 10%) 대신 '여분으로 싸기 → 오토/거래소'.

## 6. 유저 거래소 (모든 서버 하나)
### 6-1. 무엇을 올리나
- 됨: 재료, 강화·옮기기 주문서(열린 결정 4), 연금술 물약, Pet Treat, **무기**(여분 `tier:plus`, 또는 가진 무기를 '싸서' 올림: 낀 무기·T1은 안 됨).
- 안 됨: HP/MP 기본 물약(상인이 25골드에 팜, 돈 세탁 길), 펫, 퀘스트 물건, 칭호, 치장, 패스·로벅스 물건, 분실물.
- 무기는 반 이름이 없다(마스크 tier). 사는 사람 반의 이름으로 보인다. 그 tier를 이미 가지면 살 수 없다(버튼 흐림).

### 6-2. 데이터 모양
- **진실 = DataStore** `HaloHorns_Market_v1`, 키 `L_<GUID>`(38자 < 50): `{ Id, Seller, K = "I:Jelly" | "W:4:2", N, Price, At, Exp = At+259200(72시간), St = "Open"|"Sold"|"Cancel"|"Expired", Buyer?, SoldAt?, Paid? }`. 이 기록이 원장이다(30일 뒤 정리).
- **목록 = MemoryStore SortedMap** `HHMkt_<K>`: key = 리스팅 Id, sortKey = 가격, value = `{ p, n, x }`(약 100바이트), 만료 72시간+1시간. 돈·물건은 MemoryStore에 절대 맡기지 않는다.
- 플레이어 저장(추가형, v4): `Market = { Out = { [id] = { K, N, Price, St } }, In = { [id] = { Price, St } }, Done = { 최근 50 id }, Day, Lists, Buys }`, `Spares = { ["4:0"] = n }`(키마다 20, 합 60).
- 값 한계(제안): 재료 = Sell ~ Sell×25. 무기 기준가 R = 옛 Price(T2 150, T3 800, T4 3000, T5 10000, T6 30000, T7 90000, T8 20000, T9 250000)×(1+0.3×plus), 범위 0.2R~5R. 주문서 R: Enh70 300, Enh30 800, Enh10 2000, Move70 400, Move30 900, Move10 2000. 물약 R 200.
- 한 사람: 열린 리스팅 10개, 하루 새 리스팅 20, 하루 구매 30.

### 6-3. 흐름 (규칙: **먼저 내 저장에 적고, 그다음 공개**)
1. 올리기: 서버 검사(관문·속도·소유·값·개수) → 메모리에서 물건 빼고 `Out[id] = Pend` → **DataService 즉시 저장 성공 확인** → `L_<id>` UpdateAsync(없을 때만 만듦, Open) → `Out[id] = Open` → MemoryStore 목록 추가. 저장 실패면 되돌리고 거절.
2. 사기: 검사(관문, 골드 ≥ 값, 받을 수 있음, 자기 것 아님, 보낸 값 == 지금 값) → 골드를 빼고 `In[id] = Pay` → **즉시 저장** → `L_<id>` UpdateAsync: St == Open 이고 안 만료면 Sold+Buyer=나 (**단 하나의 원자 이동**). 아니면 즉시 환불.
3. 성공: 물건을 사는 사람 저장에 넣고 `In` 지움, `Done`에 id. 저장은 다음 빈자리(키당 6초)에. 목록에서 지움(실패해도 됨: 낡은 줄은 사기에서 "Already sold").
4. 판 사람 돈: 판 사람 서버가 `Out`을 60초마다(접속 중) 또는 다음 접속 때 GetAsync로 본다. Sold면 **판 사람 저장 한 번에** `가격 − floor(10%)`를 BankGold에(출처 "Market", `PassBoost.GoldSources`에 없음 → 2배 아님) + `Out` 지움 + `Done`에 id → 저장 뒤 `L.Paid = true`. 판 사람의 돈은 판 사람 저장만 준다(단 하나의 주인).
5. 취소/만료: `L` UpdateAsync Open→Cancel/Expired(사기와 같은 키라 둘 중 하나만 이김) → 물건을 판 사람 저장에 돌려줌.

### 6-4. 실패 처리
- 서버가 단계 사이에 죽음: 접속 때 `Reconcile`이 `Out`/`In`의 id마다 `L`을 읽는다(최대 10+몇 개 GetAsync). `Out Pend` + L 없음 → 물건 돌려줌. `In Pay` + L이 나에게 Sold → 물건 줌, 아니면 환불. `Done`에 있으면 아무것도 안 함(멱등).
- UpdateAsync 오류: 결과를 모르면 같은 조건으로 다시 시도한다("Buyer == 나"면 성공으로 봄). 그래도 안 되면 `In`을 남기고 30초마다 다시 본다. 화면은 "Checking…".
- 두 사람이 동시에 사기: 같은 키 UpdateAsync는 차례로 돈다 → 한 명만 Sold, 다른 사람은 환불.
- 판 사람이 나감: 돈은 `L`에 기다린다. 다음 접속에 받는다.
- MemoryStore 장애: 보기·사기 멈춤("Market is resting"), 올린 것은 DataStore에 안전. 판 사람 서버가 목록 다시 넣기(`Out`의 Idx=false).
- 복제 막기: 세션 잠금(DataService), id마다 한 번(`Done`), 상태 조건 UpdateAsync, 물건·돈은 늘 한 곳(판 사람 저장 → L 기록 → 사는 사람 저장).
- Roblox 한계(문서 값): DataStore 서버당 분당 읽기·쓰기 각 60+10×인원, 같은 키 쓰기 6초에 1번, 값 4MB, 키 50자. MemoryStore 메모리 64KB+1KB×전체 동접(동접 100 → 약 164KB ≈ 리스팅 1,500개), 요청 1000+100×동접/분, GetRangeAsync 한 번 최대 200개(반환 개수만큼 단위), 값 32KB, 만료 최대 45일. → 서버마다 품목 페이지를 15초 캐시, 한 번에 50줄. 메모리가 차면 새 리스팅 거절("Market is full").
- 한 거래 비용: L 쓰기 3번, 저장 강제 쓰기 2~3번(6초 간격 지킴: 거래 속도 제한 6초).

### 6-5. 남용 막기
- 관문(제안): 사기 Lv5+, 올리기 Lv10+ · `PlaytimeSeconds ≥ 3600` · 계정 나이(AccountAge) 7일+.
- 값 한계(6-2) + 수수료 10%(골드 줄이기).
- 부계 세탁: 같은 사는·파는 사람 짝은 한국 하루 3번(`PairCD`처럼 "mkt:<id>"), 자기 리스팅 못 삼.
- 속도: `Config.RateLimits` MarketBrowse 1, MarketList 10, MarketBuy 6, MarketCancel 5.
- 기록(TelemetryService, 고정 이름, id·이름 없음): MarketList, MarketSold(값 + 기준가 비율 띠), MarketFee(GoldOut "MarketFee"), MarketCancel, MarketExpire, MarketRefund, MarketPairCap, MarketFail_<단계>, FirstDrop_T<n>(분). GoldIn "Market".
- 아이 안전: 자유 글 없음(물건 키·개수·값만). 판 사람 이름은 안 보임(열린 결정 6). 그래서 신고 버튼은 필요 없고, 이상한 값은 기록으로 검수가 본다.

### 6-6. 화면 계약 (게임성 개발 1)
- 장소: 교차로 `Market` 자리(`Config.Features.Market` 켜면 지도 표시).
- c->s `MarketBrowse(key, page)` → s->c `MarketPage { Key, Page, Rows = { { Id, Price, N, Plus, Left } }, Ref, Min, Max }`
- c->s `MarketMine()` → s->c `MarketMine { Rows = { { Id, Key, N, Plus, Price, State, Left } }, Waiting }`
- c->s `MarketList(kind "I"|"W", id 또는 tier, n, price)`, `MarketBuy(id, price)`, `MarketCancel(id)`, `PackWeapon(tier)` / `UnpackSpare(key)`.
- 알림은 **글 대신 키**(A23-111): s->c Fx `"Market" { Key = "MarketSold", Args = { K, Price } }`. 영어 글은 `Config.Market.Text[key]`, 한국어는 같은 키. 물건 이름은 클라가 키로 찾는다.

## 7. 지금 코드에서 바꿀 곳 + 순서(덩어리 = 가지 하나, API 쓰기 한 번 ≤ $5)
- `Config.luau`: Weapons T9, WeaponGrades.Mythic, WeaponNames/WeaponInfo 끝에 붙임·출처 글, `WeaponShop.MaxSoldTier = 0`, Loot.Tables 무기 줄, `Loot.FirstWeaponDrop = { Monster = "BigSlime", Tier = 2 }`, 새 재료, `Config.Craft`, `Config.Market`, `Data.Version = 4` + Defaults(Spares, Craft, Market, Research), Tutorial 글(Claimed 등 "buys a new weapon" 문장), `Text.CanAfford`/`KillsToAfford`, Ladder Commission 줄, RateLimits, Analytics.
- `DataService.luau`: v4 이전, 9비트 마스크, 새 표 정리.
- `ShopService.luau`: 0 = 끼기만, 무기 팔기 → 여분 팔기.
- `LootService.luau`: 무기 줄, 첫 Prince 보장, 중복 → Spares, 싸기/풀기.
- `QuestService.luau`: `nextGoalText`의 IronGold("Iron weapon for 800 gold") → 드롭 안내, 받기 글.
- `StoryQuestService` / Config M1_1 대사(오토가 Prince 안내).
- `CommissionService.luau`: 손대지 않음(꺼짐), 베타 뒤 삭제.
- 새 `CraftService.luau`, `MarketService.luau`(+ `Main.server.luau` Init/Start 목록, PlayerService가 마지막).
- `ProgressionService`: 출처 "Market" 확인(2배 아님). `TelemetryService`: 6-5 이벤트. `PetService`: 연구·소환(C5).
- 클라(게임성 개발 1): Forge 창(사기 칸 없앰, 재료·여분 팔기·제작표), 제작 창 + 망치질, 거래소 창, 가방 여분 칸, 다음 목표 글.

| 덩어리 | 내용 | 시험 |
|---|---|---|
| C1 | 사다리 T9·Mythic + 저장 v4 | test_weapon_ladder.py |
| C2 | 드롭표 + 첫 Prince T2 + Spares | test_weapon_drops.py |
| C3 | 첫 10분·오토 바꾸기·의뢰 줄 빼기 | test_first10_drops.py |
| C4 | 대장장이 제작 + 제작 레벨 | test_craft.py |
| C5 | 연금술 물약 + 조련사 연구·간식 | test_alchemy.py, test_tamer_research.py |
| C6 | 거래소 원장·에스크로·정산·Reconcile | test_market_escrow.py(단계마다 서버 죽이기, 두 구매자 경쟁) |
| C7 | MemoryStore 목록·관문·텔레메트리·Features.Market | test_market_index.py, test_market_abuse.py |
| C8 | (결정 3이 예면) Armor·Ring 칸 | test_gear_slots.py |

순서: C1 → C2 → C3(첫 10분이 먼저 맞아야 함) → C6 → C7 → C4 → C5 → C8. 기능 마감 11/24.

## 8. 첫 10분 (전 → 후)
| 분 | 전 | 후 |
|---|---|---|
| 0~1 | 오프닝·진영·직업 | 같음 |
| 1~2 | [I'm In!] → Forge 걸음 → 오토가 T1 | 같음(T1 = 길드 첫 선물) |
| 2~5 | 초원 슬라임 5 → [Claim] 150골드 "That buys a new weapon" | 같음, 글만 "Save it for potions and the Market!" |
| 5~6 | M1_1 오토 → 상점 열림 → T2 150골드 구매 | M1_1 오토: 재료 팔기 + "Princes swallowed a weapon!" |
| 6~7 | M1_2 Prince 2 | M1_2 **첫 Prince가 T2를 떨굼, 바로 낌**(+ 70% 주문서 그대로) |
| 7~10 | KO1: King 한 방 → 물약 사기 → 퀵슬롯 → 재도전 승 | 같음(150골드로 물약). King 2600HP 계산(T2 기준) 그대로 맞음 |
| 10~ | 다음 목표 "Iron weapon for 800 gold" | "Iron weapon: Slime Princes and the King drop it (Lv5)" + Lv5 거래소 열림 |

## 9. 시험 이름
- 새: §7 표의 9개.
- 고칠 기존 시험(grep으로 찾음): test_loot.py(DuplicateWeaponGold, onUpgradeWeapon, 할로윈 무기 줄), test_unarmed_start.py(WeaponShop, Sell, 마스크), test_weapon_first.py(Forge·ForgeGift·150골드로 T2), test_commission.py(꺼짐 유지), test_next_goal.py(Ladder Commission 줄, QuestRewardGold), test_onboarding.py(마스크 1..255 → 1..511, 150골드), test_metrics.py(SpendGold "Weapon"), test_beta_basics.py(MaxCombatPower), test_kill_log.py·test_stats.py·test_potions.py·test_weapon_motion.py(MaxWeaponTier·Weapons 추출), test_first_ko_king.py(T1~3 빌드), test_halloween.py, test_gamepass.py(Market 2배 아님), test_item_seq.py, test_story_client.py·test_round3_client.py(클라 WeaponShop 창), 새 구역 가지의 test_new_zones.py(골렘 무기 줄).

## 10. 열린 결정 (검수·사용자)
1. T1 첫 무기: Forge 걸음 + 오토가 '길드 첫 선물'로 줌(기본) / 가이드가 수락 때 줌(Forge 걸음 없앰).
2. 신화 숫자: T9 Damage 2200, MinLevel 50, 레시피 §4(기본).
3. 방어구·반지 베타에 넣기: 넣음, C8 = 맨 끝, 늦으면 베타 뒤(기본).
4. 강화·옮기기 주문서 거래: 됨(기본).
5. 거래소 관문: 사기 Lv5 / 올리기 Lv10 + 1시간 + 계정 7일(기본).
6. 판 사람 이름 숨김(기본).
7. A23-115 "제작 무기는 드롭과 다른 계열" vs A23-127 "기본부터 신화까지 제작": 같은 tier 키 + 품질 +N(기본), 다른 모양·이름은 베타 뒤.
8. `NeutralFaction` 켜는 때: C4 합친 뒤 검수 플레이 확인 후(기본).
9. 오토의 싼 재료 판매: Jelly·Petal·SeaShell, Sell×4, 하루 50(기본).
10. 중복 무기: 골드 대신 여분 무기(기본). 2배 골드 패스 보유자는 오토에게 팔 때 2배가 사라진다(Sale) — 받아들임(기본).
11. 의뢰 코드: 꺼 둔 채 베타 뒤 삭제(기본).
