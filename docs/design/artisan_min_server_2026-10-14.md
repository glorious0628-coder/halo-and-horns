# 장인 길드 최소판 — 서버 계약 (게임성 개발 2, 2026-10-14)

사용자 10/14 "중립 애들 작업도 해야지" → gameplay_plan 2-B의 11/06 판정을 취소하고 지금 시작(최종 검수). 장인 = Neutral 진영
(대장장이 Smith·연금술사 Alch·조련사 Tame, A23-57/127). 이 문서 = 지금 main(1335aa8d)이 가진 것·없는 것·고장 + 서버가 할 일.
화면은 게임성 개발 1 몫(항목마다 표시). 새 그림 없음, 0원. 코드는 최종 검수 OK 뒤 origin/main 위 가지.

## 0. 한눈에 — 스위치 7개는 모두 꺼짐
`Config.Features`: **NeutralFaction**(20줄) · **Market**(20) · **Gathering**(8871) · **Crafting**(8978) · **Tonics**(9122) ·
**Research**(9146) · **Gear**(9199) = 전부 false. 켜는 순서 제안: Gathering → Crafting(+Tonics·Research·Gear) → Market → NeutralFaction
(마지막: 고를 수 있게 되는 순간). 하나씩 켤 때마다 시험 묶음 + 최종 검수.

| # | 항목 | 지금 main | 할 일 | 크기 | 담당 |
|---|---|---|---|---|---|
| ① | 장인 첫 10분 퀘스트 + N4 | **없음**(N1·N2는 있으나 전투 퀘스트·잠김, N4·첫 수확 없음, 채집·제작 목표 종류 없음) | 목표 종류 Gather·Craft·Sell + 퀘스트 3줄 | M | 개발 2(+대사 글) |
| ② | 채집 재료 팔 곳 | **고장**(재료 판매가 채집 재료를 일부러 건너뜀, 따로 팔 길 없음) | 대장간 모루에서 종류별 팔기 | S | 개발 2 서버 + 개발 1 버튼 |
| ③ | 무기 제작표 ↔ 드롭 | **있음**(재료 출처 빠진 것 없음) / **고장**(만든 무기가 '여분'에만 들어가 끼지도 팔지도 못함) | 여분 → 내 무기로 풀기(거래소 가지의 UnpackSpare) | M | 개발 2 |
| ④ | 스위치 규칙(PvP 면역·부활·제단·환생·일일) | **거의 다 있음**(아래 표) | 일일에 채집·제작 줄, N1·N2 막힘 주석 고치기 | S | 개발 2 |
| ⑤ | 거래소 서버 | **main에 없음**(dev2-market에 945줄, main보다 564 뒤) | main 합치기 + 실시간 끄기 키 + 서버 죽이기 시험 + 창 고장 3개 | M | 개발 2 + 개발 1(창) |
| ⑥ | 장인 마을 자리 | **없음**(구역·MapBuilder 골격 없음, 모루·작업대는 장소 파일에만) | 1단계 = 교차로 길드 마당(작업대 3개 파트), 2단계 = 장인 마을 구역(자리 결정 필요) | S → L | 개발 2(+메인 반영 1) |

## ① 장인 첫 10분 퀘스트
> **10/14 구현(dev2-artisan-quests):** 목표 Gather { Item?, Node?, Count }·Craft { Role?, Kind?, Count }·SellMat { Count } (StoryQuestService, 신호 GatherService.Gathered·CraftService.Crafted·LootService.MaterialSold 부드러운 연결). N0 'First Harvest' = 약초 3 + 구리 2 → 아무거나 1개 제작 → 150골드(GoldN) + 만든 무기 손에(Reward.EquipCrafted → LootService.EquipBestSpare: 더 센 것만). N0b 'Sell to the Smith' = 채집 재료 5개 팔기 → 30골드. N4 'Guild Order' = N2 뒤, 제작 2 → 교차로 → Gold 3·XP 3. Requires.Feature는 목록도 됨(N0 = Gathering + Crafting). W1 레시피 삭제, W2 = 약초 3 + 구리 2(참나무는 숲 Lv10이라 첫 10분엔 없음).
**지금:** `Config.StoryQuests` 서브 목록(3048-3053)에 N1·N2·N3만. N1 "The Artisan's Touch"(Lv5, SkillHit 3) · N2 "Guild Supply Book"
(큰 슬라임 3 + 몬스터 골드 60 + 교차로) = Neutral 전용인데 **둘 다 전투 퀘스트**이고 스위치 꺼짐으로 막힘(StoryQuestService 591-593;
주석은 "이미 Neutral인 저장은 그대로"라는데 코드는 그들도 막음 → 주석·코드 불일치). N3·WB1 = 모두에게 열림(Neutral 선택지 있음).
N4·N5·"First Harvest"·OathN 없음. 튜토리얼·M1~M3는 Neutral도 그대로 됨(교차로가 집, 장인 안내자 Kit 있음) — 막힘 없음, 제작 맛만 없음.
**엔진 빈칸:** 이야기 퀘스트 목표에 Gather / Craft / Sell 없음. `GatherService.Gathered`(38·349)·`CraftService.Crafted`(38·301) 신호는
있는데 StoryQuestService·QuestService가 안 들음. 한 번짜리 `Event` 목표(773-806, 이름 목록 `Config.StoryQuests.Events` 4142)는 있음.
**할 일(M):**
- StoryQuestService에 목표 3종: `Gather { Node?, Item?, Count }`(Gathered 신호), `Craft { Role?, Kind?, Count }`(Crafted 신호), `SellMat { Count }`
  (② 판매 신호). 숫자 목표라 기존 Kill·Gold처럼 `eventAmount`에 넣음.
- 퀘스트 3줄(Neutral 전용, 스위치 켜지면 열림):
  - **N0 "First Harvest"**(진영 고른 직후, M1_1과 함께): 약초 3 + 구리 2 채집 → 작업대에서 아무거나 하나 만들기(역할별 첫 제작: 대장 W2·연금 첫 토닉·조련 연구 1) → 보상 소량 골드·장인 명성.
  - **N0b "Sell to the Smith"**: 채집 재료 5개를 모루에서 팔기(②) — 골드 쓸 줄 알게.
  - **N4 "Guild Order"**(N2 뒤, 두 번째 마을 퀘스트): 길드 주문 = 역할별 제작 2개 + 교차로 길드 마당(⑥) 들르기.
- N1·N2는 그대로 두되 '이미 Neutral인 저장'이 막히는 문제를 고침(주석대로: Neutral 저장은 스위치와 상관없이 받음) — S.
- 글은 Config 글 표(쉬운 영어), 대사는 개발 1·최종 검수가 다듬음. 일일: `templateFitsFaction`(QuestService 65-66·215-219)에 채집·제작 줄 2개("Pick 8 herbs", "Craft 2 things") — S.

## ② 채집 재료 팔 곳
**지금:** 채집 노드 8종(Herb·CopperOre·OakLog·Glowcap·IronOre·SilverOre·MoonCrystal + 꽃 CrownDust, Config 8886-8935)은 모두
`Kind = "Material"`·Sell 1~10골드·`Source = "Gather"`(5563-5570). `LootService.onSellMaterials`(692-717)는 Source가 있으면 **일부러 건너뜀**
(703: "나중에 가방에서 하나씩 SellItem") — 그런데 SellItem 원격은 없음 → **채집 재료는 어디서도 못 팖.** 모루 판매 거리 검사는
`ShopService.CanBuyWeapon`(211-225, 모루 12스터드, `workspace.Map.Landmarks.ArtisanGuild.Anvil`은 장소 파일에만 있음) — 진영 검사 없음.
**할 일(S):** 원격 `SellItem(itemId, n)`: 모루 거리·Ready·`Kind = Material`·Source 있는 것만·n은 1..가진 수 → `Sell × n` 골드(주머니, 출처 "SellGather")
+ 판매 신호(① SellMat). 모두 팔기(SellMaterials)는 지금처럼 몬스터 재료만(제작 재료를 실수로 다 팔지 않게). 화면 = 가방의 'Sells for' 줄과 [Sell] 버튼(개발 1).

## ③ 무기 제작표 ↔ 드롭
**지금(있음):** 대장 레시피 W1~W7·W9(8989-8996, W8 없음 = 잭팟 단계). 재료 출처가 빠진 것 **없음**: 젤리·꽃잎·코어·고블린 이빨·브루트 뿔·뼈·기사 문장 =
몬스터 드롭, 광석·나무·약초 = 채집, KingJelly(킹 슬라임 20%)·ClatterGem(클래터 10%) = `Feature = "Crafting"` 켜질 때만 드롭(LootService 245),
CaptainBadge = 클래터 주간 선물(최대 2) → W9(배지 6개)는 3주 걸림. 모든 무기 레시피가 Gathering을, 두 개가 Crafting을 기다림.
**고장:** 만든 무기 = `LootService.AddSpare`(873-909) → `data.Spares["T:P"]`만, 보유 비트 없음 → 끼지도(장비 가방은 보기만) 팔지도 못함(대장간
판매는 보유 비트, 거래소 없음). W1 제작은 의미 없음(Tier 1 = 무료 직업 무기).
**할 일(M):** 거래소 가지(⑤)의 `UnpackSpare(key)`(여분 → 내 무기 보유 비트, +N 옮김)·`PackWeapon(tier)`를 그대로 가져와 쓰기(장인이 만든 무기를
본인이 써 보기 + 거래소에 올리기). W1 레시피는 빼거나 'Lv1 연습용'(재료만 돌려받음) — 최종 검수 결정. 전투력 미리보기 = 화면(개발 1, 장비 칸 main에 있음).

## ④ 스위치 규칙 — 지금 코드
| 규칙 | 지금 | 근거 |
|---|---|---|
| PvP 면역 | **됨**: 둘 중 하나라도 Neutral이면 피해 0·KO 처리 건너뜀, 신입 보호·PvP 구역 안내·정의·전쟁·거위·괴수 제외 | PvPService 614-615·676-680, CombatService 621-623·1488 |
| 부활·죽음 | **됨**: 집 = 교차로, 진영 마을 밖으로 튕김, PvP 아닌 죽음은 Wanted만 골드 잃음(Neutral은 Wanted 불가) → 잃는 것 없음. 죽으면 하던 제작 취소, 자연 회복 0(None은 0.01) | PlayerService 145-154, ZoneService 4-5, CraftService 608 |
| 제단(진영 바꾸기) | **반쯤**: Neutral에서 나가기 됨(약한 쪽, 표 없음); 들어가기는 `Config.Pickable`이 막음 → 스위치 켜면 됨 | FactionService 45-46·193-205·309-353 |
| 환생 | **스위치만 기다림**: Neutral 대상 됨, Pickable이 막음, 괴롭힘 막기·보너스 그대로 | ProgressionService 43·396-467 |
| 일일 | **됨(전투만)**: Kill·Golden·Gold·Release·Choice + 신입·숲 줄. 채집·제작 줄 없음 → ①에서 2줄 | QuestService 65-66·215-219 |
| 진영 버프 0 | **됨**(XP·골드·피해 0, HP 1배) | Config 881-904 |
| Wanted·자루·현상금 | **됨**(PvP를 못 하니 안 생김). `CanBeWanted = false`는 아무도 안 읽음(데이터만) | Config 893, PvPService 1180 |
| 고르기 카드·지도 이름 | **됨**(스위치 따라 바뀜) | FactionPicker 29-37, WorldMap 950 |
→ 할 일: 일일 2줄(①), N1·N2 막힘 고침(①), `CanBeWanted` 읽거나 지우기(S). 스위치를 켤 때 이 표대로 시험 한 묶음(test_artisan_rules).

## ⑤ 거래소 서버
**지금:** main엔 MarketService·Config.Market 없음(저장 모양 9303-9331과 개발 1의 MarketWindow만). `dev2-market`(d9e0abc2, 10/13) = MarketService 945줄 +
계약 `docs/design/market_server_2026-10-13.md` + test_market(15묶음: 두 구매자 경쟁 '1번 이김·2번 환불' 있음, 재접속 점검 = 단계 사이에
서버가 멈춰도 잃는 것 없음 오프라인 시험 있음, 스위치 끔 = `Config.Features.Market`).
**남은 것:** ⓐ main 합치기(564커밋 뒤, 리베이스 없음) + 전체 시험 ⓑ **실시간 끄기 키** `Config.Switches.Defs.Market`(지금은 Features만 → 게시 없이 못 끔) — S
ⓒ **서버 죽이기 시험**: 각 단계(Pend·Pay·Sold·Cancel) 직후 서버가 사라지는 경우를 단계마다 한 줄씩(지금은 재접속 묶음 하나) — S~M ⓓ 거래소 퀘스트
(처음 사기·처음 올리기, A23-133, Listed·Bought 신호 있음) — S ⓔ Studio MemoryStore 한도 확인 — 메인 반영 1. **창 고장 3개(개발 1):** 65초·3900초가 둘 다
'1:05'(MarketWindow 193-199), 내 목록 값이 수수료 전(1008), T1 여분이 팔기 목록에(275·329-334; 서버는 이미 W:1:0 거절).

## ⑥ 장인 마을 자리
**지금:** `Config.Zones`·`ZoneOrder`·`Map.Lands`에 장인 마을 없음, MapBuilder가 짓는 표지 = 분수·제단·현상수배 판·거위 횃대뿐(757-762).
`ArtisanGuild`(모루 포함)는 장소 파일에만, Neutral 스폰 = 교차로 (0, 0, -25). `CraftStation` 태그 작업대는 코드도 장소에도 없음 → CraftService가 교차로 모루로 대체.
**할 일:** 1단계(S, 0원) = MapBuilder가 교차로 `ArtisanGuild` 옆 길드 마당에 작업대 3개(Smith·Alch·Tame, 파트 골격 + 기존 재질, `CraftStation` 태그·Role 속성)를
Config 자리표로 지음 → 제작이 모루 대체에서 벗어남. 2단계(L) = 장인 마을 구역(구역 상자·집·길) — 자리는 최종 검수·사용자 결정(지도 v2 빈 곳; 빛 마을 6단계 뒤).

## 순서 제안(최종 검수 OK 뒤, 가지 하나씩)
1. dev2-artisan-sell(②) + 일일 2줄·N1/N2 막힘(④) — S, 바로.
2. dev2-artisan-quests(① 목표 3종 + N0·N0b·N4) — M.
3. dev2-market-2(⑤ main 합치기 + 끄기 키 + 서버 죽이기 시험 + 퀘스트) — M, ③ UnpackSpare 포함.
4. dev2-artisan-yard(⑥ 1단계 작업대 3개) — S.
5. 스위치 켜기 시험(test_artisan_rules, 7개 순서대로) → 최종 검수 → 사용자 한 줄.
결정 필요(최종 검수): W1 레시피 처리, 장인 마을 2단계 자리, 첫 제작 보상 크기.
