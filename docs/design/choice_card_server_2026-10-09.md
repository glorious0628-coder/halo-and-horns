# 하루 장부(Deeds) + 공용 선택 카드(ChoiceCard) — 서버 계약 (게임성 개발 3, 2026-10-09)

SPEC A23-86 결정 1(하루 선행·장난 장부) + `content_beyond_10min_2026-10-08.md` §3 CC. 개발 1(화면)·개발 2(마무리 카드, J 클래터)가 이 계약만 보면 돼요.

## 1. 하루 장부 `Deeds` (src/ServerScriptService/Deeds.luau)
- 되풀이 행동의 명예·악명은 **하루(한국 시간 00:00) 6점까지**만 올라요(`Config.Deeds.PerDay`). 연속 기록 없음.
- 자기 편 쪽 +점수, 반대 편 −점수(A23-58), 0 아래로는 안 내려가요. 반대 편 감점은 6점 상한을 쓰지 않아요.
- 골드를 내는 일 자체는 장부가 아니에요(장부 코드는 골드를 읽지 않아요). 보상은 6점이 차도 계속 나와요.
- 함수(서비스 `S.Deeds`):
  - `Deeds.Add(player, side, n?)` → `stat, change, mine, down, full` — `side` = `"Good"` | `"Evil"`, `n` 기본 1. `stat` = `"Honor"`|`"Infamy"`|`"None"`(편 없음), `change` = 실제로 바뀐 값(+/−/0), `mine` = 내 편 쪽, `down` = 계급이 내려갔는지, `full` = 내 편 쪽 상승이 하루 상한에 잘렸는지.
  - `Deeds.Preview(player, side, n?)` → `stat, change, mine` (Add가 지금 바꿀 값, 화면의 미리보기용).
  - `Deeds.Say(player, side, stat, change, mine, down, full)` — Add 결과의 안내 줄(반대 편 선택 Hallie/Magpie 줄, 계급 하락 줄, 하루 가득 줄). 점수 줄("Honor +1")은 부르는 쪽 몫.
  - `Deeds.Left(player)` / `Deeds.Used(player)` — 오늘 남은/쓴 점수.
  - `Deeds.Take(player, n)` → 상한에 들어가는 만큼(예약). `ScoreBudget.Take`와 같은 모양이라 개발 2가 마무리 카드를 옮길 때 그대로 바꿔 끼울 수 있어요.
- 저장(추가 칸, Version 3 그대로): `data.Deeds = { Day = Config.DayIndex, N = 오늘 쓴 점수 }`. 읽을 때마다 고쳐 쓰고 새 날은 0부터.
- 플레이어 속성: `DeedsToday`(쓴 점수), `DeedsMax`(6) — Q 창 Faction 탭의 "Deeds today 2/6". 접속 때와 바뀔 때, 그리고 60초마다(자정 넘김) 갱신돼요.
- `Config.ChoiceCard.Text.Full` = "Your shard is full for today. Come back tomorrow!" (카드가 `Full`일 때 서버가 한 번 알림으로 보내요).

## 2. 공용 선택 카드 `ChoiceCard` (src/ServerScriptService/ChoiceCard.luau)
- 나만 보는 카드. **좋은 쪽(Good)과 나쁜 쪽(Evil) 보상 크기는 같고 고정**(뽑기 없음). 카드 근처에 구매 버튼을 두지 않아요(A23-79).
- 카드 종류는 데이터: `Config.ChoiceCard.Kinds[kind] = { Title, Seconds?, Good = { Label, Done?, Reward = { Item|Potion, N, Gold }, Points? }, Evil = {…} }`. 지금은 비어 있고, 잃어버린 물건·견습생·클래터 같은 카드는 그 내용과 함께 들어와요.
- 두 가지 모양:
  - **저장 카드**(`Seconds` 없음): 시간 제한 없음, 한 장 대기, `data.Cards.Pending = { Id, Kind, Ctx }`, 접속하면 다시 떠요.
  - **시간 카드**(`Seconds`, 예: King Slime 마무리): 저장 안 함, 시간이 지나면 `None`(보상·점수 없음), 서버만 쓰는 `Grace` 1초.
- 한 번에 한 장: `ChoiceCard.Offer(player, kind, ctx?)` → `true` | `false, "open" | "kind" | "notready" | "gone"`.
- 주고받기(Net):
  - s→c `Fx "Card"` `{ Id, Kind, Title, Seconds?, Stat, Good = {Label, Item?, Potion?, N?, Gold?, Score, Hint?}, Evil = {…} }` — `Score` = 지금 고르면 바뀔 값(+1/−1/0), `Hint` = `"Neutral"`(편 없음: 보상만) | `"Full"`(내 편, 오늘 점수 가득) | `"Zero"`(반대 편, 잃을 게 없음) | `nil`.
  - s→c `Fx "CardEnd"` `{ Id, Kind, Side = "Good"|"Evil"|"None", Stat, Score, Item?, N, Gold, Full }` — 실제로 일어난 일.
  - c→s `"CardAction"`(id: number, side: "Good"|"Evil") — 열린 카드의 Id만, 한 번만, 0.3초 속도 제한. 인자 수·종류가 다르면 무시.
- 보상: 아이템은 `LootService.GrantItem`(가방이 차면 남은 만큼 판매값 골드), 골드는 `AddBankGold(..., "Choice")`(2배 패스 안 탐). 점수는 **오직 `Deeds.Add`** 로만. 한 줄 알림 "Kind choice! · +Jelly x2 · Honor +1"(Done 글은 카드마다 바꿀 수 있어요), 반대 편 선택은 A23-58 안내 줄(Hallie/Magpie), 계급이 내리면 계급 줄.
- 기록: 고를 때마다 `data.Story.N[kind][side] += 1`. **My Way는 아직 읽지 않아요.** 무게(검수 결정 2026-10-09): 되풀이 카드 5번 = 이야기 선택 1번, 되풀이 몫 합계는 이야기 몫을 넘지 않게 상한 — 다음 덩어리.
- 신호: `ChoiceCard.Picked(player, kind, side, result)` (고름과 시간 끝 모두).
- 저장: `data.Cards = { Serial, Pending }` (Serial은 카드 Id, 줄어들지 않음).
- Studio 도움: `DebugCommand("Card", "<kind>")`.

## 2-1. 이미 장부를 쓰는 곳
- 일감 게시판(`BoardService`): 끝낸 [Kind] 일 = 좋은 행동 1점, [Sneaky] 일 = 장난 1점(내 편 +1 / 반대 편 −1, 하루 6점 안, 보상은 계속). `Config.Board.Text.Score = "%s +%d"`. 주간 랭킹 점수는 여전히 없음(A23-23 D1).
- 견습생 카드(오토의 의뢰, `docs/design/commission_server_2026-10-09.md`)와 앞으로의 잃어버린 물건·클래터 카드는 `ChoiceCard`를 거쳐요.

## 3. 개발 2 마무리 카드와 합치기 (순서)
1. 지금은 따로: `FinisherService`의 Net 이름(`FinisherCard/FinisherPick/FinisherEnd`, `Help`/`Tickle`)을 안 바꿔요. 개발 1 화면이 그걸 써요.
2. King Slime이 main에 들어간 뒤: `FinisherService`의 점수 부분(`ScoreBudget`)을 `Deeds`(`Take`/`Add`)로 바꿔 하루 상한이 하나가 되게 해요. ScoreBudget `PerDay = 5`(proposed)는 장부 6점으로 합쳐져요.
3. 그다음 열기/고르기/기록을 `ChoiceCard.Offer`로 옮겨요(`Help`→`Good`, `Tickle`→`Evil` 이름만 매핑, 시간 카드, 옛 Fx 이름은 한 판 호환). finisher 시험이 그대로 통과해야 해요.

## 4. 시험
`py tools/test_choice_card.py` — 검사 117개 + 정적 18개, 변이 58/58 (`docs/art/verification_2026-10-09/offline_dev3_choice_card_2026-10-09.json`).
