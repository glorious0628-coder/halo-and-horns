# 거래소 서버 C-5 / C-7 — 설계·약속 (게임성 개발 2, 2026-10-13)

근거: SPEC A23-127(모든 서버 하나의 거래소, 거래는 거래소만), A23-133(사기 Lv5 · 올리기 Lv10 + 플레이 1시간 + 계정 7일 · 판 사람 이름 숨김 · 수수료 10% · 거래소 골드는 2배 골드 아님 · 주문서 거래 됨 · 거래소 퀘스트), 설계 `origin/api/dev2-crafting-design:docs/design/crafting_market_2026-10-11.md` §6, 화면 계약 `docs/design/market_window_2026-10-12.md` §6(개발 4와 합의). 서버 = `src/ServerScriptService/MarketService.luau`, 숫자·글 = `Config.Market`. 시험 `py tools/test_market.py`. 스위치 `Config.Features.Market`(꺼짐 그대로 — 켜는 건 최종 검수).

## 1. 진실은 하나 (돈·물건은 늘 한 곳)
- **장부 = DataStore** `HaloHorns_Market_v1`(Config.StoreName), 키 `L_<id>`: `{ Id, Seller, K, N, Price, At, Exp, St = Open|Sold|Cancel|Expired, Buyer?, SoldAt?, Paid? }`.
- **목록 = MemoryStore**(힌트만, 돈·물건 없음): 키마다 정렬 맵 `HHMkt_<키>`(id → { p, n, x, s }, 값 싼 순), 요약 `HHMktIndex`(키 → { L 가장 싼 값, C 줄 수 }), 판 힌트 `HHMktSold`(판 사람 → 팔린 id).
- **플레이어 저장**(v4 Market 표): `Out[id] = { K, N, Price, St, At, Exp, Ret?, Idx?, Fin? }`, `In[id] = { Price(총액), St = Pay, K, N }`, `Done`(끝난 id 50개), `Day / Lists / Buys`, `P<판 사람 UserId>` = 오늘 그 사람에게서 산 수. 새 상태 `Pend`(장부 전 저장됨)·`Pay`(돈 냄, 장부 전) 추가(SaveV4.MarketStates).
- 규칙: **먼저 내 저장(DataService.Save 성공), 그다음 장부, 마지막에 맵.** 저장 실패 = 되돌리고 "Resting".

## 2. 흐름
- **올리기** `MarketList(kind, id, n, price)`: 관문·속도(6초)·키·값 범위·가진 수 → 가방에서 뺌, `Out = Pend` → 저장 → 장부 행(없을 때만) Open → `Out = Open` → 맵. 장부 오류면 다시 읽어 "없음 = 돌려줌 / 있음 = Open / 모름 = Pend(Checking, 다음 차례에 끝냄)". 맵 실패 = `Idx = false`(다음 차례에 넣음).
- **사기** `MarketBuy(id, price)`: 관문(Lv5·하루 30)·장부 읽기(Open·안 끝남·내 것 아님·**값 같음**)·받을 자리·무기 tier 이미 있으면 안 됨·같은 판 사람 하루 3번·골드 → 골드 뺌, `In = Pay` → 저장 → 장부 UpdateAsync 하나(Open·안 끝남 → Sold + Buyer = 나; **두 사람 중 하나만**) → 물건 줌(`Done`) / 진 사람은 돌려받음(`MarketRefund`). 쓰고 나서 오류면 다시 읽어 판단, 읽기도 안 되면 `In`이 남아 다음 차례에 정리(화면 Waiting).
- **판 돈**: 판 사람 서버가 받음(힌트는 20초마다, 열린 줄 전부는 5분마다, 접속 때). 총액 − floor(10%) → 은행 골드 `"Market"`(2배 아님), `Out = Paid` + `Done` → 그 저장 뒤 장부 `Paid = true`. 판 사람 돈은 판 사람 저장만 줌.
- **취소** `MarketCancel(id)` / **끝(72시간)**: 장부 Open → Cancel / Expired(사기와 같은 키라 하나만 이김) → 가방에 돌려줌(자리 없으면 취소 거절; 끝났는데 자리 없으면 `Ret`로 남아 다음 차례에 다시). 이미 팔렸으면 돈을 줌.
- **접속 확인**: 모든 `Out`/`In` 줄을 장부와 맞춤 — Pend+장부 없음 = 돌려줌, Pend+Open = Open, Open+Sold = 돈, Pay+나에게 Sold = 물건, Pay+그 밖 = 환불, Paid 줄·장부 Paid = 다시 안 줌. 서버가 단계 사이에 꺼져도 잃는 것 없음.
- **스위치 꺼짐**: 새 올리기·사기·창 응답 없음("Off"), 이미 있는 줄의 돈·돌려주기는 계속.
- **싸기/풀기**(가방 버튼, 화면은 아직): `PackWeapon(tier)` = 가진 무기(손에 든 것·T1 아님) → 여분 `T:+N`, `UnpackSpare("T:P")` = 안 가진 tier의 여분 → 가짐.

## 3. 숫자 (`Config.Market`, 내가 정함 — 바꾸려면 최종 검수)
- 관문: 사기 Lv5, 올리기 Lv10 + 플레이 3600초 + 계정 7일(A23-133). 열린 줄 10, 하루 올리기 20·사기 30, 같은 판 사람 하루 3번, 72시간, 수수료 10%.
- **값은 1개 값**(N개 줄은 N × 값을 냄). 범위: 재료 = 판매가(Sell) ~ Sell×25, 처음 값 Sell×3 / 주문서 Ref(Enh70 300 · Enh30 800 · Enh10 2000 · Move70 400 · Move30 900 · Move10 2000) / 물약·Pet Treat Ref = Sell×5 / 무기 Ref = 옛 가격 × (1 + 0.3 × +N)(T8 20000) — 주문서·물약·무기 범위 Ref×0.2 ~ Ref×5.
- 올릴 수 있는 것: Config.Loot.Items 중 Material·Enhance·Transfer·Tonic·Treat, 여분 무기 T2~T9 +0~10(한 줄에 1개). 안 됨: HP/MP 물약, T1, 퀘스트·치장·펫.
- 속도 제한(초): MarketIndex·Browse·Mine 1, List·Buy·Cancel 6, Pack·Unpack 1. 색인 캐시 30초, 페이지 캐시 15초, 한 쪽 50줄(한 번 읽기 200줄 = 4쪽).

## 4. 화면 약속 (market_window §6 그대로 + 덧붙임)
- 원격: `MarketIndex`(c→s 물음 / s→c `{ Rows = { { Key, Low, Count } }, At, Gate }`), `MarketBrowse(key, page)` → `MarketPage { Key, Page, Pages, Rows = { { Id, Price, N, Plus, Left } }, Ref, Min, Max }`(내 줄·판 사람은 안 보임), `MarketMine`(c→s / s→c `{ Rows = { { Id, Key, N, Plus, Price, State, Left, Paid } }, Waiting, Today = { Lists, Buys }, Gate }`), `MarketList`, `MarketBuy`, `MarketCancel`, `PackWeapon`, `UnpackSpare`.
- `Gate = { Buy = "" | 거절 키, List = "" | 거절 키, ListIn = 다음 올리기까지 초 }`. State = Open | Sold | Cancel | Expired(Paid는 따로 bool).
- 알림 = `Net.Notify` 한 줄(`Config.Market.Text`): MarketListed · MarketBought · MarketPaid · MarketCancelled · MarketExpired · MarketRefund · Checking + 거절 키(NeedLevelBuy · NeedLevelList · NeedPlaytime · NeedAccountAge · PriceChanged · AlreadySold · NotEnoughGold · CantReceive · Owned · TooMany · DayLimit · PriceRange · Resting · Full · PairLimit · TooFast · Off · Own · NoItem · CantSell · InHand). Fx `"Market"`은 쓰지 않음(화면에 받는 곳 없음).
- **화면 쪽 고칠 것(개발 4/1에 알림):** 값이 1개 값이라 Sell의 "You get"은 `n × 값 − floor(n × 값 × 10%)`, Buy 줄은 "×N  값(1개)" + [Buy]가 N × 값을 냄.

## 5. 남은 것
- 거래소 퀘스트 3개(첫 사기·첫 올리기·첫 판매 받기): `MarketService.Listed / Bought / Paid` 신호로 다음 커밋(보상 값 = 최종 검수).
- 기록(TelemetryService) 이벤트, Studio에서 MemoryStore 한도 확인(API 켠 Studio), 화면 연결 사진(개발 4/메인 반영 1).
