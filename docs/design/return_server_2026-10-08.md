# 다시 오게 만들기 서버 계약 (SPEC A23-79) — 게임성 개발 3, 2026-10-08

근거: SPEC A23-79 5묶음(사용자 2026-10-08 고름), `docs/design/psychology_retention_2026-10-08.md`,
`docs/design/retention_round_2026-10-08.md`. 서버 = 새 `ReturnService.luau`(#1 멈춤 카드·Welcome back, #2 My Way·배지, #5 알림
동의) · `InviteService.luau`(#3) · `DiaryService.luau`(#4). 설정 = Config.luau 맨 끝 "A23-79 coming back" 블록.
시험 = `py tools/test_return.py`(155검사, 변이 70/70). 능력치 0, 판매 0, 카운트다운 0, 초대 보상 0(A23-68).

## #1 멈춤 카드 + Welcome back (클라 = 개발 1 `PauseCard.luau`, 이미 main에 있음)
| 신호 | 언제 | 내용 |
|---|---|---|
| Fx `PauseCard` { Why, Next, Zone?, Tomorrow?, OptIn? } | ① 장 끝(각 장의 마지막 메인 퀘스트 M1_4·M2_7·M3_8을 끝낸 1.5초 뒤) ② 그날 일일 3개를 다 받았을 때(DailyClaims = 3) ③ 왕관전 한 판 끝(그 판에서 상자 점수 30 이상, 이번 접속 15분 이상, 왕관전 카드는 30분에 한 번) | Why = "Chapter" / "Daily" / "War". Next = 고정 퀘스트 줄의 짧은 이름(ShortName, 없으면 글). Zone = [Go]용 이동 목적지(아래). Tomorrow(일일 카드만) = "New dailies" 또는 핼러윈 중 "King Diary page N". OptIn = true면 카드를 닫은 뒤 알림 동의 창을 띄울 차례(#5). |
| Fx `WelcomeBack` { Next, Zone? } | 마지막으로 나간 지 6시간 이상 지나 다시 들어오면(첫 임무를 끝낸 저장만) 접속 4초 뒤 한 번 | [Go] = 기존 Travel 원격(Zone). |
- 카드끼리는 120초 띄움. 싸우는 중이면 3초마다 10번까지 기다렸다 보냄. 카드에는 시계 숫자·구매 버튼 없음(클라 규칙 그대로).
- **Zone 규칙(서버가 정해 보냄):** 퀘스트 안내(Guide)가 구역이면 그 구역, 이야기 장소(Landmarks)면 그 장소가 있는 구역,
  대장간·다리·분수 → Crossroads, 내 마을 → "Home", **상대 진영 마을·레벨이 모자란 구역 → Zone 없음**(버튼 숨김), 핼러윈 밭 → 초원.
  다음 목표 줄이 "Zone"(숲 열림)이면 GoblinWoods, "IronGold"면 Crossroads, 고정 줄이 없으면 "Hunt and get stronger!" + 내 레벨 사냥터.
- 기록: `ReturnService.CardShown(player, why)`, `ReturnService.Welcomed(player)`.

## #2 My Way 이름 + 배지 8개
- 속성 `MyWay` = 보이는 이름(영어) 또는 ""(아직 없음). 클라는 값이 바뀔 때(접속 때 첫 값 말고) 2초 알림.
  - 이야기 선택 기록(data.Story.Pick)에서 그 퀘스트 Choice 단계의 Good/Evil 쪽을 센다(장인 길드 A/B도 같은 쪽으로).
  - 선택 2개 미만 → "". |착한 수 − 나쁜 수| ≤ 전체의 1/5(내림) → **Balance Walker**. 빛: 착한 쪽이 많으면 **True Knight**, 나쁜 쪽이면 **Rebel Angel**.
    뿔: 나쁜 쪽 **Proud Rascal**, 착한 쪽 **Soft-Hearted Devil**. 장인 길드·진영 없음 → "". 판단·설교·능력치 없음.
  - 선택할 때(StoryQuestService.Picked)와 진영이 바뀔 때 바로 다시 계산.
- 배지(BadgeService:AwardBadge, pcall): ChoseSide(진영 고름) · FirstSlime(첫 처치) · LostLunchbox(Lunch1 끝) · Stronger(2티어 이상 무기
  보유 — 첫 무료 무기는 아님) · FirstSkill(첫 스킬 배움) · ShardChoice(S0 끝) · Rank2(진영 계급 2) · Halloween2026(2026 시즌에 사탕을
  얻거나 대왕을 함께 잡음). `Config.Badges.Ids`가 0이면 묻지 않음 → **게시 때 사용자가 배지 8개를 만들고 id를 붙여 넣으면** 다음
  접속에 이미 이룬 것까지 한꺼번에 준다(하루 무료 5개 → 이틀에 나눠 만들기, launch_ops_checklist). 저장 data.Return.Badges[키] = { Id = 준 배지 id, At }.
  **AwardBadge가 true일 때만** 받은 것으로 저장(검수 검토 10/08). false(배지 꺼짐·id 틀림)면 UserHasBadgeAsync로 이미 가졌는지 확인 →
  가졌으면 저장, 아니면 오류처럼 경고 + 5분 뒤 다시. 저장된 Id가 지금 Config id와 다르면(사용자가 id를 고침) 안 받은 것으로 보고 새 id로 다시 준다.

## #3 친구 초대 + Go to friend (클라 = 개발 1 `Invite.luau`, 이미 main에 있음)
- 초대 접속: `GetJoinData().LaunchData`가 숫자만(내 id 아님, 20자 이하)이면 초대 접속. 처음 데려온 사람을 data.Invite = { By, At }에 남김(보상 없음).
- c→s `GoToFriend`(userId): 준비됨, 직업 고름, 3초 제한. 같은 서버의 Roblox 친구(또는 나를 초대한 / 내가 초대한 사람)에게만.
  - 친구 구역 → 목적지: 내 마을이면 "Home", **상대 마을이면 거절**("Your friend is in the other side's town."), 핼러윈 밭 → 초원,
    변두리 → "Your friend is exploring far away. Try again soon!", 같은 구역이면 "You're already there!".
  - **PvP 구역(숲·유적)은 Lv15부터**("Your friend is in a PvP zone. Come at Lv 15!") — 새싹을 PvP로 보내지 않음.
  - 그다음은 `ZoneService.Travel`(보통 3초 이동, 레벨 문·전투·원한 자루·괴수·현상 별 규칙 그대로). 거절 이유는 그대로 한 줄.
- 기록: `InviteService.InviteJoined(invitee, inviterId, inviter?)`, 10분 같이 있으면 `PlayedTogether(inviter, invitee)` 한 번, `WentToFriend(player, zone)`.

## #4 호박 대왕 일기 + 사탕 단지
- 대왕(호박·유령)을 함께 잡으면(그 처치가 보상을 준 UserId = HalloweenService.KingDefeated의 목록) 다음 쪽이 열림. **오늘 날짜 쪽까지만**
  (10/31 = 1쪽 … 11/08 = 9쪽, 10/31 전에는 1쪽까지). 늦게 와도 대왕 한 번에 한 쪽씩 몰아 읽기. 시즌(11/09 0시) 뒤에는 새 쪽 없음.
  - 속성 `DiaryPages`, Fx `DiaryPage` { Page, Today, Late }, 9쪽 → 칭호 **Party Guest 2026** + Fx `DiaryDone` {} 한 번(색종이).
  - 쪽 글 = `Config.Halloween.Banter.Days[쪽]`의 두 대왕 줄(클라가 그림; 9쪽 유령 대왕 줄의 %d는 서버 수가 없으니 GhostKingZero 줄이나 고정 문구로).
  - 1쪽을 연 뒤 알림 동의 순간(#5)이 올 수 있음.
- c→s `CandyTrade`(id): `Config.CandyJar.Trades` — **Pumpkin Pal = 사탕 50**, **Candy Keeper = 사탕 200**(임시, 검수가 정함). 이미 가진 칭호면 사탕 안 가져감.
  사탕이 모자라면 "You need N candy." 시즌 뒤에도 열림. 사탕은 `LootService.TakeItem`으로만 줄어듦(가방 다시 보냄).

## #5 알림 동의 순간 (13세 이상 판단·창은 클라 ExperienceNotificationService)
- 순간: 그날 일일 3개를 다 받았을 때(PauseCard의 OptIn = true) 또는 대왕 일기 1쪽 뒤(Fx `OptInMoment` { Why = "Diary" }).
  - 한 접속에 한 번, 플레이 10분(PlaytimeSeconds 600) 전에는 안 함, KO·강화 실패·구매 창 60초 안에는 안 함.
- 클라: `CanPromptOptInAsync()` → true면 `PromptOptIn()` → 닫히면 `ClientMetric("OptIn", "shown")`, false면 `ClientMetric("OptIn", "cannot")`.
  - shown → 다시 안 물음. cannot(13세 미만·이미 정함·Roblox 30일 쉼) → 30일 뒤 다시 물을 수 있음.
  - shown이면 그 UserId를 DataStore `HaloHorns_NotifyAsked_v1`(키 = UserId, { At })에 남김 → 11/09 업데이트의 Open Cloud 보내기(키는 Secrets, 사용자 몫)가 이 목록을 씀.
    (Roblox는 수락 여부를 알려 주지 않아서 "물어본 사람" 목록이다. 실제로는 동의한 사람에게만 배달됨.)

## 저장 (추가 칸, Version 3 그대로)
`Return = { Badges = { [키] = { Id, At } }, OptIn = "" | "shown" | "cannot", OptInAt }`, `Diary = { Pages, Done }`, `Invite = { By, At }`.
각 서비스가 접속 때 깨진 값을 고친다(DataService는 안 고침).

## 다른 파일에 더한 작은 줄 (다른 줄 안 바꿈)
- `WarService.RoundEnded(winner, mode, snapshot)` — endRound 끝. `HalloweenService.KingDefeated(key, kind, ids)` — 잡힌 대왕만.
- `StoryQuestService.QuestDone(player, id)` — complete 끝(Done 저장 뒤), `Picked(player, id, pick)` — 선택 저장 뒤 advance 전.
- `QuestService.PinnedRow(player)` — publish가 맨 위에 놓는 줄(이야기 메인 줄 / 첫 임무·다음 목표 줄). `LootService.TakeItem(player, id, n)`.

## 화면(개발 1·이미지 개발)이 할 것
1. PauseCard: `Tomorrow` 줄(일일 카드)과 `OptIn` 플래그 처리(카드 닫은 뒤 알림 창), [Go] 누르면 `ClientMetric("WelcomeBackGo")`.
2. My Way: `MyWay` 속성 바뀔 때 2초 알림(첫 값 제외). 3. Invite.GoTo는 그대로(원격 GoToFriend 생김), 초대 버튼에 `ClientMetric` InviteSeen/InvitePrompt/InviteSent(측정 계약).
4. 일기 책(`DiaryPages`, Fx DiaryPage/DiaryDone)·사탕 단지 창(`CandyTrade`), 5. 알림 동의 창(`OptInMoment` / 카드 OptIn).
