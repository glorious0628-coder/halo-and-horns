# 베타 기록(측정) 서버 계약 (SPEC A23-79 ⑥) — 게임성 개발 3, 2026-10-08

근거: `docs/design/retention_round_2026-10-08.md` "베타에서 잴 것"(검수 결정, 10/24 전에 넣기). 서버 = 기존
`src/ServerScriptService/TelemetryService.luau` 위에 덧붙임(관찰만, 게임 상태는 안 바꿈). 설정 = `Config.Analytics.Funnels`
등(Config.luau 맨 끝 "A23-79 beta metrics" 블록). 시험 = `py tools/test_beta_metrics.py`(126검사, 변이 62/62) +
기존 `py tools/test_metrics.py`(BB38, 95검사, 변이 51/51, 허용 이벤트 목록에 새 이름 추가).
Roblox 기록은 **게시된 서버에서만** 쌓인다(Studio Play는 기록 안 됨). Studio에서는 `[Metrics] …` 줄이 출력창에 찍힌다.

## 퍼널 (Roblox 한도 10개 중 6개: 온보딩 + 아래 5개)
| 퍼널 | 세션 | 단계 (순서대로, 세션마다 한 번) |
|---|---|---|
| LongRoad | 계정마다 한 번 | Level15 → Level25 → Level30 → Level40 → Level50 → Rebirth1 |
| DailyVisit | 한국 날짜(DayIndex)마다 | Join → Daily1(일일 1개 받음) → Daily3(일일 3개 다 끝남, 받기 전 포함) → SetChest(3개 다 받음 = 상자) → StopCardSeen(일일 멈춤 카드) |
| Social | 계정마다 한 번 | InviteSeen → InvitePrompt → InviteSent → InviteeJoined(내가 초대한 친구가 내 서버에 옴) → PlayedTogether10m |
| KingDiary | 계정마다 한 번 | Page1 → Page3 → Page6 → Page9 |
| PassShop | 상점 한 번 열 때마다(GUID) | ShopOpen → PassView → PurchasePrompt → Bought |
- **Roblox는 뒤 단계를 받으면 앞 단계를 자동으로 채운다.** 그래서 퍼널에는 늘 순서대로 오는 단계만 넣었다(반박 검토 10/08):
  출석 받기·3장 끝·유적 첫 일일은 건너뛸 수 있어서 **이벤트**(Attendance·ChapterEnd·RuinsDaily)로 뺐고, StopCardSeen은 **일일 카드**에만 센다
  (장 끝·왕관전 카드는 PauseCard 이벤트만). retention_round의 'LongRoad Lv25 → RuinsDaily1' 판단은 Level25 단계 수와 RuinsDaily 이벤트 수로 본다.
- 옛 저장은 이미 지난 단계를 접속 때 채운다(LongRoad 레벨·환생, KingDiary 쪽 수). 같은 단계는 두 번 안 보낸다.
- 일일 단계는 그날 일일(DailyDay = 오늘)일 때만 센다 — 자정 직후 QuestService가 새 일일을 만들기 전에는 어제 숫자라서.
- 접속 중에 한국 자정이 지나면 다음 1분 틱에 새 날(DaysPlayed +1, DailyVisit Join)로 센다.

## 사용자 정의 이벤트 (이름 한도 100 중 기존 48 + 새 17 = 65)
DaysPlayed(값 = 평생 날 수, 칸1 레벨 띠 1-9/10-24/25-49/50+, 칸2 진영) · ReturnGap(칸1 <6h/6-24h/1-3d/3d+) ·
Attendance(값 = 모은 날 수, 칸1 칸 번호) · PauseCard(칸1 Chapter/Daily/War) · WelcomeBack · FriendJoin(초대받은 사람, 칸1
InviterHere/InviterAway) · GoToFriend(칸1 구역) · DiaryPage(값 = 쪽, 칸1 Late/OnTime) · CandyTrade(값 = 사탕, 칸1 단지 id) ·
NotifyOptIn(칸1 shown/cannot) · InviteSent(값 = 고른 친구 수) · WelcomeBackGo · ChapterEnd(값 = 장 번호 1~3) · RuinsDaily(Lv25+ 첫 일일, 계정마다 한 번) · PromptNearKO(KO·강화 실패 30초 안에 구매 창,
**0이어야 함**, 칸1 KO/EnhanceFail, 칸2 패스) · KOLeave60(KO 60초 안에 나감, 칸1 구역) · LeaveContext(나갈 때, 칸1
KO/StopCard/DailyDone/Combat/Shop/Menu/Idle/Play, 칸2 판 길이 구간). 서버가 닫힐 때(모두 한꺼번에 나감)는 LeaveContext·KOLeave60을 안 센다.
- 이름·UserId·자유 글은 어느 칸에도 안 넣는다(정해진 목록 값만).

## 골드 → 경제 대시보드
`LogEconomyEvent(…, "Gold", 금액, 지금 가진 골드(주머니+은행), 거래 종류, SKU = ProgressionService 태그)`. 골드 한 번마다가
아니라 **출처·쓴 곳별 합계를 5분마다 + 나갈 때** 보낸다(전체 한도 분당 120 + 20×동접). 거래 종류: Attendance =
TimedReward, Sale·Refund = Shop(들어옴), Weapon·Potion·LookChange = Shop(나감), 나머지 Gameplay.
- 참고: 지금 일일·이야기·첫 임무 골드는 모두 태그 "Quest"라서 Daily를 따로 보려면 QuestService의 태그를 나눠야 한다(개발 2가
  payReward를 고치는 중이라 손대지 않음 — 필요하면 검수가 정함).

## 화면(게임성 개발 1)이 보낼 것 — c→s `ClientMetric`(id, arg?)
| id | arg | 언제 |
|---|---|---|
| ShopOpen | (없음) | 상점 창을 열 때마다(30초 안에 다시 열면 같은 방문) |
| InviteSeen | "Menu" / "PlayerList" / "GooseWin" / "WarWin" | [Invite a friend] 버튼이 보일 때(판마다 한 번이면 충분) |
| InvitePrompt | 같은 목록 | Roblox 초대 창을 열 때 (Invite.Prompt 성공) |
| InviteSent | 고른 친구 수 1~50 | `SocialService.GameInvitePromptClosed`(player, recipientIds)에서 #recipientIds ≥ 1 |
| PassView | 패스 id(XP2·Gold2·VIP·Look, 또는 `Config.Looks` id) | 상점에서 패스 칸을 볼 때(열린 방문이 없으면 여기서 방문 시작) |
| PurchasePrompt | 같은 id | Roblox 구매 창을 열 때 |
| OptIn | "shown" / "cannot" | 알림 동의: `CanPromptOptInAsync`가 true면 `PromptOptIn` 뒤 OptInPromptClosed에서 "shown", false면 "cannot" |
| WelcomeBackGo | (없음) | Welcome back 카드의 [Go] (PauseCard.Shown의 button "Go") |
- 같은 id는 0.5초에 한 번, 한 사람이 1분에 10번까지만 받는다(한 사람이 게임 전체 기록 한도를 못 채우게). OptIn·WelcomeBackGo는 판마다 한 번.
  목록 밖·인자 틀림은 조용히 버린다.
- 상점 방문은 `ClientMetric("ShopOpen")` 또는 `UiMetric("Shop")`(지금 클라는 창마다 판에 한 번만 보냄) 또는 첫 PassView로 시작한다. 10분 지나면 방문 끝.

## 다른 서버 쪽이 줄 것
- 게임성 개발 2(A23-75): 패스를 산 것이 확인되면 `MonetizationService.PassBought:Fire(player, kind)` 신호 하나(이름 다르면 알려 주면 맞춤). 없으면 Bought 단계만 비어 있다.
- 게임성 개발 3(A23-77·79): `AttendanceService.Claimed`, `ReturnService.CardShown/Welcomed`, `InviteService.InviteJoined/PlayedTogether/WentToFriend`, `DiaryService.PageOpened/CandyTraded`, `StoryQuestService.QuestDone` — 신호가 없으면 그 단계만 비고 오류는 없다.

## 판단 날짜(retention_round 그대로)
11/03 첫 D1 뒤: 온보딩 퍼널 가장 큰 낙차 + KOLeave60 많은 구역. 11/07~08 첫 D7 뒤: LongRoad Lv25→RuinsDaily1·Lv30 전환,
DailyVisit SetChest 비율, Social(InviteSent/D1), Rebirth1, PromptNearKO > 0이면 버그.
