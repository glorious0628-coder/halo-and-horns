# 채집 서버 GatherService 설계 (게임성 개발 3, 2026-10-11 밤)

근거: `docs/design/gathering_2026-10-06.md`(검수 설계, 규칙·숫자는 거기가 기준), SPEC A23-119(채집 베타 포함)·A23-127(제작은 장인만)·A23-133(모든 글 L10n 키, 한국어 베타)·A23-111·A23-78(상호작용 G)·A23-58·A23-86(Deeds 하루 6점)·A23-96(노드 3D 새로),
`docs/design/save_v4_tables_2026-10-11.md`(Gather 표), `docs/design/l10n_contract_2026-10-11.md` §5(ids·키만), 코드 main ca7554ae.
이 문서는 **서버 계약 + 화면 계약(게임성 개발 4)**이다. 10/06 설계에서 바뀐 곳만 '바뀜'으로 적는다.
**구현(10/11 밤, 가지 `dev3-gather`):** `GatherService.luau`, `LootService.GrantItems`, Config(`Config.Features.Gathering`은 따로 한 줄 — Features 표 줄을 바꾸면 다른 시험의 변이가 깨짐), Net `GatherState`, Main 두 목록. 시험 `tools/test_gather.py`(113 named, 변이 74/74). 화면 = 게임성 개발 4 `dev4-gather`(GatherView).

## 0. 한눈에
- 누구나(빛·뿔·장인) 같은 규칙: 노드 8스터드 안에서 **G 꾹**(폰 버튼 꾹) → 재료 1개(20%는 2개). XP·주문서·무기·물약 없음.
- 노드는 모두에게 보이고, 딴 사람에게만 **180초** 쉼. 실패 없음, 몬스터에게 맞아도 그대로, **사람에게 맞으면 그 채집 무효**.
- 서버 검사: 거리 12, 누른 시간 ≥ 0.8×정한 시간, 1초 1번, 노드별 내 쿨다운, **하루 400번**(KST).
- 식물 노드에서 가끔 **조각 꽃** → 공용 선택 카드(ChoiceCard) [나눠요]/[다 가져요].
- 스위치 `Config.Features.Gathering = false`(꺼져 있으면 노드도 안 만듦). 켜는 때 = 장인 길드 켜기와 같이(검수).

## 1. 재료 8종 (id 고정: 거래소 키 `I:<id>`·레시피가 씀)
| id | 화면 이름(영어, 키 `Config.Loot.Items.<id>.Name`) | 노드 kind | 구역 | 판매가 | 꾹 시간 | 노드 수 |
|---|---|---|---|---|---|---|
| `Herb` | Meadow Herb | `HerbBush`(식물) | SlimeMeadow | 1 | 1.5 | 12 |
| `CopperOre` | Copper Ore | `CopperRock` | SlimeMeadow | 2 | 2.0 | 8 |
| `OakLog` | Oak Log | `OakPile` | GoblinWoods | 3 | 1.5 | 8 |
| `Glowcap` | Glowcap | `GlowcapPatch`(식물) | GoblinWoods | 4 | 1.5 | 8 |
| `IronOre` | Iron Ore | `IronRock` | GoblinWoods | 5 | 2.0 | 6 |
| `SilverOre` | Silver Ore | `SilverRock` | SkeletonRuins | 8 | 2.0 | 6 |
| `MoonCrystal` | Moon Crystal | `MoonCrystal` | SkeletonRuins | 10 | 2.0 | 6 |
| `CrownDust` | Crown Dust | — (조각 꽃에서만) | — | 8 | — | — |

- **바뀜:** 호박밭 길 자리는 뺌(PumpkinPatch·HauntedHollow 숨김, A23-119). 새 구역(E-1, 검수가 고름)이 정해지면 그 구역 노드 1종을 9번째로 더한다(id 새로, 이 8개는 그대로).
- 아이템 정의는 `Config.Loot.Items`에 `{ Kind = "Material", Sell, Color, Icon = "" (그림 전 대체), Source = "Gather" }` + `Order`. 설명은 "Sell it at the Forge." → 제작이 켜지면 "Used for crafting." 줄(키로).
- **레시피 연결(제작 설계 ③에서 정함, 지금은 방향만):** 무기 T1~T3 = 구리, T4~T5 = 철, T6~T7 = 은, T9 = 달 수정(+ 몬스터 재료 그대로) / 활·지팡이 손잡이와 방어구 = 참나무 / 버프 물약 = 약초·빛버섯 / Pet Treat = 약초. 그래서 채집 재료가 모든 장인 사다리에 들어가고, 빛·뿔은 캔 것을 거래소에서 장인에게 판다.

## 2. 노드 자리·모양
- 폴더 `workspace.Map.GatherNodes`(서버가 만듦). 노드 하나 = Model, 속성 `GatherId`(문자열 `"<Zone>:<n>"`, 고정), `GatherKind`.
- 자리: ① WorldKit이 놓은 `GatherSpot` 태그 파트(속성 `Node = kind`)가 있으면 그것만 그 구역에 씀 ② 없으면 `Config.Gather.Spots[zone] = { { Node, U, V }, ... }`(구역 `Config.Zones` 사각형 안 비율 좌표) → 위에서 아래로 광선(플레이어·몬스터·GatherNodes 제외)으로 땅 높이.
- 무더기 안 노드 간격 ≥ 8스터드(프롬프트가 한 번에 하나). 두지 않는 곳: 마을 3곳, 스폰 40스터드 안, 큰길(z 0) 위, 트램펄린 자리(10/06 §2).
- 모양: `ServerStorage.GatherKit[<kind>]` 모델이 있으면 복제(이미지 생성 1, Tripo→Blender→재질, A23-125). 없으면 **임시 대체**: 앵커 파트 하나(`Config.Gather.Nodes[kind].Color`, 식물 = Ball, 바위 = 둥근 Block). 대체는 스위치 꺼진 동안 시험용. 장식 덤불·바위에 노드 색을 쓰지 않는다.

## 3. 입력·검사 (서버)
- 노드마다 ProximityPrompt `GatherPrompt`: `HoldDuration = Nodes[kind].Hold`, `MaxActivationDistance = 8`, `RequiresLineOfSight = false`, `ActionText = ""`·`ObjectText = ""` + 속성 **`ActionKey = "Config.Gather.Text.Pick"|"Config.Gather.Text.Mine"`**, **`ObjectKey = "Config.Loot.Items.<id>.Name"`**(L10n 계약 §5-3, 클라 Keybinds `applyPrompt`가 글과 G 키를 넣음).
- `ProximityPromptService.PromptButtonHoldBegan(prompt, player)` → `HOLD[player] = { Id, T0 = os.clock() }`. `PromptButtonHoldEnded` → 지움(Triggered가 먼저면 그대로).
- `PromptTriggered(prompt, player)` 검사 순서(하나라도 틀리면 아무것도 안 줌):
  1. 스위치 켜짐, prompt가 GatherNodes 안의 우리 노드, player 살아 있음, `ClassChosen`이고 진영 ≠ None.
  2. `HOLD[player].Id == 이 노드` 이고 `os.clock() - T0 ≥ Hold × MinHoldRatio(0.8)`.
  3. HumanoidRootPart ↔ 노드 피벗 거리 ≤ `ServerRange 12`.
  4. 1초 1번(`Config.RateLimits.Gather = 1`).
  5. 이 노드의 내 쿨다운 끝남(`CD[player][Id] ≤ os.time()`).
  6. 오늘(`Config.DayIndex`) 수 < `DailyCap 400` — 넘으면 `NotifyKey Config.Gather.Text.DailyCap` 한 번(세션당), 끝.
  7. 누르기 시작 뒤 **사람에게 맞음** 없음: `CombatService.PlayerDamaged(victim, amount, attacker)`에서 attacker가 다른 Player이고 amount > 0이면 `HOLD[victim].Hit = true` → Triggered에서 `NotifyKey Config.Gather.Text.PvPCut`, 쿨다운은 안 걸림.
- 통과: 개수 = 1, `Double 0.2` 확률로 2 → `LootService.GrantItems(player, { { Id, N } }, 노드 위치, "Gather")`(새 공개 함수: addItem + Fx "Loot" + ItemsGranted, 꽉 차면 지금처럼 알림). 실제로 들어간 수만 셈. 0개(가방 꽉 참)면 쿨다운·하루 수 안 셈.
- 그다음 `CD[player][Id] = os.time() + Regrow(180)`, `Gather.N += 1`, `Gather.Total += 1`, 식물이면 조각 꽃 굴림(§4), `GatherService.Gathered:Fire(player, itemId, n, kind)`, 화면에 `GatherState`.
- 노드 쿨다운은 서버 메모리만(나가면 지움). 서버를 옮겨 다시 따는 것은 하루 400으로 막힘.
- 자동 채집 없음: 서버가 노드를 따는 길은 사람이 누른 프롬프트뿐. 자동 전투는 노드를 대상으로 잡지 않음.

## 4. 조각 꽃 (Shard Bloom)
- 식물 노드(HerbBush·GlowcapPatch) 채집 성공 뒤: 오늘 꽃 < 3 이고 열린 선택 카드가 없을 때만 굴림. `Total`이 5가 되는 첫 채집은 반드시(FirstBloom), 아니면 8%.
- `ChoiceCard.Offer(player, "ShardBloom", { Gather = Id })` — 카드 정의 `Config.ChoiceCard.Kinds.ShardBloom = { Seconds = 120, Title, Good = { Label = "Share it", Reward = { Item = "CrownDust", N = 2 }, Points = 1 }, Evil = { Label = "Keep it all", Reward = { Item = "CrownDust", N = 3 }, Points = 1 } }`. 점수는 ChoiceCard가 Deeds로(빛 나눔 = 명예 +1, 뿔 다 가짐 = 악명 +1, 반대는 −1, 장인은 점수 없음, 하루 6점). Offer가 false면 꽃 없음(수 안 셈).
- `ChoiceCard.Picked(player, "ShardBloom", side)`:
  - Good: 40스터드 안 다른 사람(진영 상관없음) 각 +1 CrownDust, 받는 사람 `Gather.Gift` 하루 10까지. 받는 사람에게 `NotifyKey Config.Gather.Text.BloomGift`(이름 없음).
  - None(120초 지남): +1 CrownDust, `NotifyKey Config.Gather.Text.BloomWilt`, 점수 없음.
- `Gather.Bloom += 1`은 Offer 성공 때. 주간 랭킹·왕관 쟁탈전 점수 없음. 사냥 골드 퀘스트(EarnGold)에 안 셈.

## 5. 저장 (`data.Gather`, v4 표 합의안)
`{ Day, N, Bloom, Gift, Total, FirstBloom }` — 날이 바뀌면(Day ≠ 오늘) N·Bloom·Gift = 0. sanitize는 Config.SanitizeGather(v4 가지).

## 6. Config
```
Config.Features.Gathering = false
Config.Gather = {
	DailyCap = 400, MinHoldRatio = 0.8, PromptRange = 8, ServerRange = 12, Regrow = 180, Double = 0.2,
	Nodes = { HerbBush = { Item = "Herb", Hold = 1.5, Action = "Pick", Plant = true, Zone = "SlimeMeadow", Color = … }, … },
	Spots = { SlimeMeadow = { { "HerbBush", u, v }, … }, GoblinWoods = …, SkeletonRuins = … },
	Bloom = { Chance = 0.08, FirstAt = 5, DailyMax = 3, Radius = 40, GiftDailyMax = 10 },
	Heavy = 200, -- 한 시간 채집이 이보다 많으면 Telemetry "GatherHeavy"(id·이름 없음)
	Text = { Pick = "Pick", Mine = "Mine", DailyCap = "…", PvPCut = "A player hit you! Try again.", BloomGift = "Someone shared a Shard Bloom! +1 Crown Dust", BloomWilt = "The bloom closed up. +1 Crown Dust" },
}
Config.RateLimits.Gather = 1
```
- 글은 모두 `Config.Gather.Text`·`Config.Loot.Items.*`·카드 표(키)에. 서버는 `Net.NotifyKey`만(영어 문장을 보내지 않음).
- 자리 표(U,V)는 10/06 §2의 스터드 후보를 지금 `Config.Zones` 사각형 비율로 바꿔 넣는다(호박밭 길 빼고).

## 7. 화면 계약 (게임성 개발 4)
- s->c `GatherState { Ready = { [GatherId] = 쉬기 끝 시각(workspace:GetServerTimeNow 기준) }, N, Cap }` — 채집 뒤마다, 들어올 때 한 번.
- 클라 `GatherView`: Ready가 미래인 노드는 **나에게만** 프롬프트 `Enabled = false`(로컬), 흐리게, 반짝이 끔. 시각이 지나면 다시 켬.
- 얻음 팝업 = 기존 Fx "Loot"(Items = `{ { Item = id, N } }`, 이름은 클라가 id로). 장인이면 Fx "Gather" `{ Id, Artisan = true }` → 청록 톱니 반짝이·망치 톡톡(겉모습뿐).
- 조각 꽃 = 기존 ChoiceCard Fx "Card"/"CardEnd". 프롬프트 글 = `ActionKey`/`ObjectKey`.
- 첫 안내 줄은 **없음**(게임성 개발 4 판단, A23-130 설명 글 줄이기). `FirstHint` 키는 만들지 않았다.

## 8. 다른 서비스와 이어지는 곳
- **LootService**: 공개 `GrantItems(player, list, pos, source)` 추가(개발 2 파일 — 이 가지에서 작은 함수만, 개발 2에 알림).
- **CombatService.PlayerDamaged**: 연결만(파일 안 고침).
- **ChoiceCard**: 카드 종류 하나 + Picked 연결(파일 안 고침).
- **퀘스트**: `GatherService.Gathered` 신호. 목표 종류 `Gather`(일일 "Pick 8 herbs", 장인 'First Harvest')는 ⑧ 장인 첫 10분에서 붙임.
- **Main.server.luau**: 두 목록 모두 LostFoundService 다음(LootService·ChoiceCard 뒤, START는 PlayerService 앞), **같은 커밋**으로(따로 올리면 서버가 멈춤).
- **Telemetry**: Funnel "FirstGather", 시간당 Heavy 넘으면 "GatherHeavy".

## 9. 열린 것 (검수에게)
1. ~~오토의 '재료 팔기'는 Material을 전부 판다~~ → **게임성 검수 답(10/11):** 한 번에 다 팔기는 **몬스터 재료만** 판다. 채집·제작 재료(`Source`가 있는 물건, 예 "Gather")는 빼고, 나중에 가방에서 하나씩 고르는 SellItem(개발 4 가방 + 개발 2 서버)으로 판다. 구현: LootService onSellMaterials에 `def.Source ~= nil`이면 건너뜀(가지 `dev3-gather`, test_loot에 시험·변이). 최종 검수가 다르게 정하면 바꿈.
2. 새 구역 노드(9번째)는 E-1 구역이 정해진 뒤.
3. 노드 3D(이미지 생성 1/3): 노드 7종 2D → Tripo. 그 전까지 임시 대체(스위치 꺼짐).

## 9-2. 켜기 전 고친 것 (게임성 검수 10/12, 가지 `dev3-craft`)
1. **팔 곳:** 채집 재료는 오토 한 번에 팔기에서 빠짐 → 재료 설명을 "Artisans craft with it."로, 가방 가득 줄은 `Config.Loot.Text.ItemFullKeep`("… is full (max N).", 대장간 말 없음). **켜는 조건(남음):** 가방에서 하나씩 파는 SellItem(개발 2 서버 + 개발 4 가방) 또는 거래소 — 그 전엔 999개가 차면 그 재료만 '가득'.
2. **꽃 나눔 중심 = 꽃 자리**(카드 120초 동안 마을로 뛰어가도 거기서 안 나눠짐), 받는 사람은 준비됨·살아 있음·직업 고름.
3. **준비된 사람만:** 꾹 시작·Try 모두 `IsReady`, 정리는 PlayerLeaving과 Players.PlayerRemoving 둘 다.
4. **넣은 수는 가방으로 셈:** GrantItems 앞뒤 개수 차이(넣은 뒤 오류가 나도 채집·쿨다운이 셈).
5. **앉음·순간이동:** Humanoid.Sit이면 거절. 0.5초마다 위치를 재서 한 번에 60스터드 넘게 움직였으면(순간이동·날아감) 3초 동안 거절(걷기는 걸리지 않음).
- 시험 test_gather 132 named·변이 86/86.

## 10. 시험 (`tools/test_gather.py`, 오프라인, dev2_kit + dev3_world 대역)
거리·누른 시간(0.79×는 거절, 0.8×는 통과)·1초 1번·노드 쿨다운(나만, 다른 사람은 됨)·하루 400(다음 KST 날 다시)·사람에게 맞음 무효(몬스터는 됨)·가방 꽉 참이면 수 안 셈·20% 두 개·스위치 꺼짐이면 노드 없음·FirstBloom 다섯 번째·하루 꽃 3·나눔 40스터드·받기 하루 10·120초 지나면 +1·장인 점수 없음·글은 NotifyKey 키만(영어 문장 없음)·Main 목록·저장 Gather 다시 불러오기. 변이(mutation)로 각 검사를 하나씩 끄면 시험이 실패해야 한다.
