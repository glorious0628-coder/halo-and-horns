# 잃어버린 물건 (Lost & Found) — 서버 (게임성 개발 3, 2026-10-10)

`docs/design/content_beyond_10min_2026-10-08.md` §C, 빛 마을 점검표 #45. 코드: `src/ServerScriptService/LostFoundService.luau`, 설정 `Config.LostFound` + 카드 4종 `Config.ChoiceCard.Kinds.Lost*`, 퀘스트 목록 연결 `QuestService.publish`. 시험: `py tools/test_lost_found.py`.

**기본은 꺼짐** (`Config.LostFound.Enabled = false`). RELEASE_PLAN이 "먼저 뺄 것"으로 적은 항목이고, 퀘스트 창이 새 줄 종류 `Find`를 그리고 물건 그림 4장이 들어와야 켜진다. 켜는 것은 검수 결정(또는 실시간 스위치).

## 게임 속 모습
1. 물건이 있는 곳(초원·숲·유적, 핼러윈 동안 호박밭)에서 사냥하면 **내 처치 수**를 센다. 60마리 전에는 아무 일 없고, 60마리부터 확률이 고르게 올라 100마리에서 꼭 나온다(60 = 1/41 … 99 = 40/41, 100 = 1). 나오면 수가 0부터 다시 센다.
2. 한 번에 **1개만** 들고, 하루(한국 시간) **3개**까지. 들고 있거나 하루치를 채웠으면 세지 않는다. 남의 처치 몫만 받은 사람(Minor)은 세지 않는다.
3. 나오면 그 물건의 공용 선택 카드(ChoiceCard)가 뜬다 — 저장되는 카드라 시간 제한이 없고 다음 접속에도 기다린다.
   | 물건 | 어디서 | 주인 | 카드 |
   |---|---|---|---|
   | Lost Teddy | 초원 | 아이 | "A lost teddy! Someone must miss it." [Give it back] / [Finder's fee!] |
   | Grab Club Badge | 숲 | 고블린 | [Give it back] / [Keep it as a trophy] |
   | Old Guard Medal | 유적 | 경비병 | [Give it back] / [Keep it as a trophy] |
   | Lost Candy Bag | 호박밭(핼러윈) | 아이 | [Give it back] / [Finder's fee!] |
4. 카드는 **보상을 주지 않는다**(점수만: Deeds 하루 6점, +1 내 편 / −1 반대 편). 고르면 걷기가 시작된다.
   - [Give it back], 아이 물건의 [Finder's fee!] → 교차로 **Lost & Found 벤치**(아이들 벤치 10스터드 안). 퀘스트 줄: "Bring the Lost Teddy to the Lost & Found · Crossroads" (안내: Fountain).
   - 아이 물건이 아닌 것의 [Keep it as a trophy] → **내 마을**(빛은 빛 마을, 뿔은 뿔 마을, 중립은 교차로). 줄: "Put the Grab Club Badge in your vault · your town" (안내: OwnTown).
5. 도착하면 1초 확인 루프가 알아서 준다. **사냥 2분어치**(내 레벨 기준, 2배 패스를 타지 않음):
   - Good = 그만큼의 XP + HP 물약 2 + MP 물약 2 + 그날 **첫** 습득이면 강화 주문서(70%) 1장.
   - Evil = 그만큼의 골드(출처 `Choice`).
   - 가방이 꽉 차 못 받은 물건은 판매가만큼 골드로. 지급이 실패해도 기록은 이미 지워서 두 번 주지 않는다.
6. KO·털기로 잃지 않는다: 들고 있는 것은 가방 물건이 아니라 `data.LostFound.Holding` 기록 하나다. 남이 가져갈 수 없다.

## 저장 `data.LostFound`
`{ Day, N (오늘 나온 수), K (지난 습득 뒤 처치 수), Holding = { Id, Phase "Choose" | "Carry", Side, Leg "Bench" | "Vault", First } | nil }`. 매번 읽을 때 고친다(날짜가 바뀌면 N=0, K는 이어짐; 깨진 Holding은 지움; N ≤ 1000, K ≤ 1,000,000). 기본값 `Config.Data.Defaults.LostFound`(데이터 버전 3 그대로).

## 연결
- `MonsterService.MonsterKilled` → `OnKilled`. `ChoiceCard.Picked` → 걷기 시작. `PlayerReady` → 걷던 사람은 다시 루프에 올린다.
- 다른 카드가 열려 있어서 카드를 못 띄웠으면(Phase "Choose") 다음 처치에서 다시 시도한다(카드는 한 번만 열림).
- `QuestService.publish`가 `LostFoundService.Rows`를 목록 끝에 붙인다: `Kind = "Find"`, `Id = "find:<item>"`, `Find = { Item, Leg, Guide }`, `ShortName` "Lost & Found" / "Trophy vault". [받기] 없음.
- Studio: `DebugCommand("Player1", "Lost", "Teddy")`(그 물건 습득 + 카드), `""`(지금 구역의 물건), `"clear"`(기록 지우기). `Config.LostFound.Enabled = true`가 있어야 걷기·줄이 움직인다.

## 개발 1 / 이미지 생성 2에게
- **개발 1:** 퀘스트 창·HUD가 새 줄 종류 `Find`를 그린다(진행 숫자 없음, 누르면 `Find.Guide`("Fountain" | "OwnTown")로 안내). 카드는 기존 Panels 'Card' 경로 그대로. 켜기 전에 한 번 확인.
- **이미지 생성 2:** 물건 그림 4장(Teddy, Club Badge, Guard Medal, Candy Bag) — 그림이 없으면 카드는 코드 대체 그림.

## 숫자 (검수가 정한다)
처치 60~100, 하루 3, 보상 2분어치, 물약 HP·MP 각 2, 첫 습득만 주문서 1장, 벤치 10스터드 — 모두 시작 값이다.

## 시험
`py tools/test_lost_found.py` — 설정·박자·끄기·구역/물건·누가 세나·하루 3개와 날짜·카드·두 갈래 걷기·벤치/금고 도착·지급(출처·2배 패스·가방 꽉 참·실패)·꺼 둔 채 걷기·다른 카드가 열려 있을 때·다음 접속·깨진 저장·디버그. 검사 155, 정적 16, 변이 85/85.
