# 거래소 창 C-6 — 화면 계약 제안 (게임성 개발 4, 2026-10-12, 개발 2와 맞출 것)

근거: SPEC A23-127(모든 서버 하나의 거래소, 거래는 거래소만, 서버 확인), A23-133(사기 Lv5 · 올리기 Lv10 + 플레이 1시간 + 계정 7일 · 판 사람 이름 숨김 · 수수료 10% · 거래소 골드는 2배 골드 패스 제외 · 주문서 거래 됨 · **거래소 퀘스트**), A23-130(설명 글 줄이기), A23-111(글은 키), A23-98(PC 먼저). 서버 설계 = 개발 2 `origin/api/dev2-crafting-design:docs/design/crafting_market_2026-10-11.md` §6(원장 DataStore + 목록 MemoryStore + 에스크로, §6-6 화면 계약). 이 문서는 §6-6을 **창이 실제로 쓰는 모양**으로 채우고 빈칸 4개를 묻는다. 스위치 `Config.Features.Market`(꺼짐) — 꺼져 있으면 창·메뉴·지도 표시 모두 없음.

## 1. 창 (Panels 창 "Market", 가방과 같은 칸 그림·버튼, 새 그림 없음)
탭 3개: **Buy · Sell · Mine**. 아래 줄 = 내 골드(은행 + 주머니).
- **Buy:** 왼쪽 = 종류 칸(Materials · Scrolls · Tonics · Weapons, 가방 탭과 같은 말) + 그 종류의 물건 목록(아이콘·이름·**가장 싼 값**·올라온 수). 위에 찾기 칸(물건 이름 글자로 거르기 — 클라가 Config 이름으로, 서버 요청 없음). 오른쪽 = 고른 물건의 리스팅 줄(값 싼 순, 한 번에 50줄, 다음 쪽): 개수·(무기면 +N)·값·남은 시간 + [Buy]. 값 옆에 기준가 대비 표시 없음(글 줄이기) — 기준가는 Sell에서만.
- **Sell:** 내 가방에서 팔 수 있는 것만(재료·주문서·물약·Pet Treat·여분 무기 `T:P`; 낀 무기·T1·HP/MP 물약·퀘스트 물건은 안 보임). 하나 고르면: 개수(− / + / 전부), 값 칸(숫자, Min~Max 안, 기준가 Ref를 처음 값으로), "받는 돈 = 값 − 10%" 한 줄, [List]. 막히면 버튼에 이유(Lv10 / 1시간 / 계정 7일 / 하루 20개 / 열린 10개).
- **Mine:** 내 리스팅(Open · Sold · Expired · Cancel)과 사는 중(Checking…). Open = 남은 시간 + [Cancel], Sold = "Sold" + 받은 돈(이미 받았으면 회색), Expired·Cancel = 물건 돌아옴 표시. 위 줄에 "Paid out" 알림이 오면 이 탭 숫자 점(BadgeDot).
- 막힌 상태: 사기 Lv5 전 = Buy 탭의 [Buy]가 "Lv 5"로 꺼짐. 거래소 쉼(MemoryStore 장애) = 창 가운데 한 줄 `Config.Market.Text.Resting`.

## 2. 원격 (§6-6 그대로 + 빈칸 채움 — **굵은 것이 새로 묻는 것**)
| 방향 | 이름 | 모양 | 비고 |
|---|---|---|---|
| c->s | **`MarketIndex()`** | 없음 | **새로.** Buy 왼쪽 목록에 '가장 싼 값·수'가 필요 |
| s->c | **`MarketIndex`** | `{ Rows = { { Key, Low, Count } }, At }` | Key = `"I:<itemId>"` / `"W:<tier>:<plus>"`. 서버 15초 캐시 그대로 |
| c->s | `MarketBrowse(key, page)` | key 위 모양, page 1.. | |
| s->c | `MarketPage` | `{ Key, Page, Pages, Rows = { { Id, Price, N, Plus, Left } }, Ref, Min, Max }` | **Pages 더함**(다음 쪽 버튼). Left = 남은 초 |
| c->s | `MarketList(kind, id, n, price)` | kind "I" \| "W", id = itemId \| `"T:P"`(여분 키), n, price | §6-6의 'tier' 대신 **여분 키 "T:P"**로(+N이 다른 여분 구별) — 확인 부탁 |
| c->s | `MarketBuy(id, price)` | 보이던 값 그대로(값이 바뀌었으면 서버 거절) | |
| c->s | `MarketCancel(id)` | | |
| c->s | `MarketMine()` | | |
| s->c | `MarketMine` | `{ Rows = { { Id, Key, N, Plus, Price, State, Left, Paid } }, Waiting, Today = { Lists, Buys } }` | **Paid · Today 더함**(Sell 버튼 이유 '하루 20개'를 클라가 보이려고) |
| c->s | `PackWeapon(tier)` / `UnpackSpare(key)` | | 가방 쪽 버튼(가진 무기를 여분으로 싸기) — 가방이 붙임 |
| s->c | Fx `"Market"` | `{ Key, Args }` | Key = `MarketSold` · `MarketBought` · `MarketPaid` · `MarketCancelled` · `MarketExpired` · `MarketRefund` · 거절 키(아래). 글 = `Config.Market.Text[Key]`(영어, 한국어는 같은 키) |

- **거절 알림 키(제안, Config.Market.Text):** `NeedLevelBuy`(Lv5) · `NeedLevelList`(Lv10) · `NeedPlaytime` · `NeedAccountAge` · `PriceChanged` · `AlreadySold` · `NotEnoughGold` · `CantReceive`(이미 그 무기 tier 있음/칸 가득) · `TooMany`(열린 10) · `DayLimit` · `PriceRange` · `Resting` · `Full`(메모리 가득) · `PairLimit`. 화면은 키 글을 그대로 한 번(토스트), 두 번째 줄 없음(A23-130).
- **관문을 화면이 미리 보이는 법:** Level(속성), `PlaytimeSeconds`(속성 있나? 없으면 **속성으로 달아 주기** 부탁), 계정 나이 = `LocalPlayer.AccountAge`(클라가 읽음). 서버가 다시 확인.
- 이름 숨김: Rows에 판 사람 없음(그대로).

## 3. 거래소 퀘스트 (A23-133, 글 짧게)
- 첫 사기 · 첫 올리기 · 첫 판매 받기 3개를 기존 퀘스트 책(StoryQuest/QuestService)에 줄로. 화면은 따로 없음 — 퀘스트 줄의 [Go]가 Market 창을 그 탭으로 연다(`Panels.Open("Market", { Tab = "Buy" | "Sell" | "Mine" })`).
- **묻는 것:** 퀘스트 정의·보상은 개발 2(또는 QuestService 주인)가? 보상 값은 검수가?

## 4. 화면 쪽 순서 (서버 전)
1. 이 계약 합의(개발 2) → 2. `MarketWindow.luau` + 서버 대역(오프라인 시험 픽스처가 MarketIndex/Page/Mine을 흉내) — 스위치 꺼짐, API 쓰기로 → 3. 개발 2 C-5 가지가 오면 대역 대신 실제 원격으로 UiSandbox 사진(두 구매자 경쟁·만료·Paid는 서버 시험이 주인).

## 5. 개발 2에게 묻는 것 (4개)
1. `MarketIndex` 원격(종류별 가장 싼 값·수) 추가 괜찮나? (아니면 Browse를 키마다 부르게 되어 요청이 많음)
2. `MarketList`의 무기 id를 tier 대신 여분 키 `"T:P"`로?
3. `MarketPage.Pages` · `MarketMine.Paid / Today` 더하기 괜찮나?
4. `PlaytimeSeconds`를 플레이어 속성으로 보여 줄 수 있나(관문 이유를 버튼에 미리)? 거래소 퀘스트는 누가 넣나?
