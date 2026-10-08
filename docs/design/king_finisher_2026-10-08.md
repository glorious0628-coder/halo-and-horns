# 왕 슬라임 마무리 카드 — 서버 계약 (게임성 개발 2, 2026-10-08)

출처: `docs/design/rpg_success_analysis_2026-10-08.md` §4-3 #9, 검수 2026-10-08(아이 안전판, 베타 전). 서버 = 게임성 개발 2, 카드 화면 = 게임성 개발 1, 소리 = 소리 만들기.
**검수 OK 2026-10-08:** 아래 ①~④(10초 안 고르면 덤·점수 없음, 젤리 ×2 = 골드 4, 카드 골드 2배 제외, 하루 상한 5)를 제안값 그대로 확정했어요. 숫자는 Config만 고치면 바뀌어요.

## 1. 무엇이 일어나나

1. 왕 슬라임(`BigSlime`, 금빛·개인 왕 슬라임 포함)의 HP가 0이 되면 지금처럼 **모두에게 같은 처치**예요. 퐁 사라짐, 경험치·골드·드롭, A23-2 왕관 조각, A23-12 첫 왕 슬라임 70% 주문서 보장, 퀘스트·스토리·게시판·퍼널 집계는 하나도 바뀌지 않아요. 카드는 그 **뒤에 덧붙는 덤**이에요.
2. 그 처치의 보상을 받는 기여자(`ContributorWindow` 15초 안) 가운데 **직접 때린 사람**에게만 나만 보는 카드 1장을 줘요.
   - 직접 때림 = 서버가 받아들인 **수동** 공격이 처치 전 15초(`ContributorWindow`) 안에 1번 이상이에요.
     - 수동 공격: Swing 버튼, Q, Z/X를 직접 누른 것이에요. 직접 누른 Z/X 장판이 나중에 때리는 것도 수동이에요.
     - 자동 전투로 나간 공격과 스킬은 세지 않아요. 구역 밖이나 남의 개인 몬스터처럼 거절된 공격도 세지 않아요.
   - 자동 전투로만 때린 사람에게는 카드가 없어요.
3. 카드: **"The King Slime is dizzy!"**
   - [Help it hop home] = 빛 쪽(Good): 젤리 선물
   - [Tickle out its coins] = 뿔 쪽(Evil): 골드
4. **10초** 안에 안 고르면 선택 없이 끝나요. 처치 보상은 처치 순간 이미 받았고, 카드 덤(젤리·골드)과 점수만 없어요.
   - 검수 OK(①): "보상은 기본으로 받음" = 처치 보상만 받아요.
5. 무릎 꿇기·떨기 같은 연출은 없어요. 'Shake it down'이라는 이름도 쓰지 않아요.

## 2. 보상과 점수

| | Help it hop home (Good) | Tickle out its coins (Evil) |
|---|---|---|
| 덤 | 젤리 ×2 | 은행 골드 +4, 출처 `"Finisher"` |
| 크기 | 젤리 판매가 2 × 2 = 4골드 | 4골드 |
| 빛(Halo) | 명예 +1 (하루 상한 안) | 명예 −1 (A23-58, 0 아래로는 안 내려감) |
| 뿔(Horns) | 악명 −1 (A23-58) | 악명 +1 (하루 상한 안) |
| 중립·진영 없음 | 덤만 받고 점수 없음(A6) | 덤만 받고 점수 없음 |

- **같은 크기:** `Config.Finisher.Help.N × Config.Loot.Items.Jelly.Sell == Config.Finisher.Tickle.Gold`를 시험이 지켜요.
  - 가방에 젤리가 꽉 차서 덜 들어가면, 못 들어간 젤리는 판매가만큼 골드로 줘요. 이때 LootService의 'full' 알림도 함께 떠요. 그래서 Help가 손해 보는 일은 없어요.
- **2배 골드 패스(A23-75):** `"Finisher"` 골드는 2배가 되지 않아요(`Config.PassBoost.GoldSources`에 넣지 않음).
  - 아이템은 2배가 아니니, 패스를 산 아이에게도 두 버튼이 같은 크기로 남아요. 돈 때문에 뿔 쪽으로 기울지 않게 하려는 거예요.
  - **A23-75 예외(검수 OK ③):** 2x Gold 패스는 "번 골드는 모두 2배"지만, 마무리 카드 골드(`"Finisher"`)는 2배가 아니에요.
    - 도덕 선택에서 돈을 낸 아이에게 한쪽이 더 이득이 되지 않게 하려는 거예요.
    - 같은 원칙으로 이야기 선택 골드(`"Choice"`)도 2배가 아니에요(`docs/design/gamepass_server_2026-10-08.md` 4절).
- **점수는 `PlayerService.AddStat`만 써요.** 이야기 선택(D1)처럼 이번 주 랭킹 점수에는 들어가지 않아요(`GrantFame` 안 씀). 그래서 랭킹 파밍 길이 없어요.
- **하루 공통 상한(P9, 새로 만듦):** `Config.ScoreBudget = { PerDay = 5 }`, KST 하루(`Config.DayIndex`) 기준이에요.
  - 되풀이해서 오르는 명예·악명 **오름**만 여기서 빼 써요. 내림(A23-58 감점)은 상한과 상관없어요.
  - 상한이 차면 고른 덤은 그대로 받아요. 점수는 0이고 "shard leaned" 한 줄만 나와요.
  - 저장: `data.ScoreBudget = { Day, N }`. 모듈 `ScoreBudget.luau`의 `Take(player, n) → 실제로 준 수`, `Left(player)`는 앞으로 생길 다른 반복 점수원(새싹 돕기 등)도 같이 써요.
  - 계급 숫자로 보면: 하루 5점이면 계급 2(10점)까지 이틀, 계급 3(50점)까지 열흘이에요. 이 선택만으로 그래요.
- **한 줄 알림(서버가 보냄):** 고르면 한 줄이 떠요. 예: "It hops home happy! +2 Jelly · Honor +1", "Coins pop out! +4 gold · Infamy +1".
  - 반대 편 감점 줄과 계급 내려감 줄은 이야기 선택의 글(`Config.StoryQuests.Text` OffSide*/RankDown*)을 그대로 써요.

## 3. 리모트·페이로드 (클라 = 게임성 개발 1)

### 서버 → 클라: `Fx "FinisherCard"` (그 사람에게만)
```lua
{ Id = 17,                 -- 이 사람 카드 번호(서버가 1씩 올림), FinisherPick에 그대로 돌려줌
  Kind = "BigSlime",
  Seconds = 10,            -- 카드가 열려 있는 시간(이 뒤엔 서버가 받지 않음, 지연 여유 Grace 1초는 서버만 앎)
  Stat = "Honor",          -- "Honor" | "Infamy" | "None"(중립·진영 없음)
  Help   = { Item = "Jelly", N = 2, Score = 1 },   -- Score = 지금 고르면 바뀔 내 점수(+1, -1, 0)
  Tickle = { Gold = 4, Score = 0, Hint = "Zero" }, -- Hint = Score만으로 모자랄 때의 안내(아래)
}
```
- 글은 `Config.Finisher.Text`(공유 Config)에 있어요: `Title`, `Help`, `Tickle`, `Score`("Honor +1"), `ScoreDown`("Honor -1"),
  `HintFull`, `HintZero`, `HintNeutral`.
- **점수 힌트(반박 검토 2026-10-08):** 버튼마다 `Score`가 0이 아니면 `Score`(+는 `Score`, −는 `ScoreDown` 글)를 보여 주세요.
  0이면 버튼의 `Hint`를 보여 주세요.
  - `"Full"`: 내 편 버튼인데 오늘 점수(하루 5)를 다 썼어요 → `HintFull`.
  - `"Zero"`: 반대 편 버튼인데 잃을 점수가 없어요(명예·악명 0, A23-58 바닥) → `HintZero`.
  - `"Neutral"`: 중립·진영 없음이에요(두 버튼 모두) → `HintNeutral`.
  - `Hint`가 없으면(nil) 점수가 있는 버튼이에요.
- 고른 뒤의 보상 줄은 서버가 Notify(소리 `"None"`)로 보내요. 고른 순간의 소리는 클라가 `FinisherEnd`로 틀어요.
  - 반대 편을 골랐는데 잃을 점수가 없으면, 이야기 선택처럼 안내 줄 뒤에 "Your shard leaned to …"가 붙어요.
- **한 번에 한 장:** 카드가 열려 있는 동안 또 왕 슬라임을 잡으면 새 카드는 없어요. 열린 카드가 바뀌지 않게 하려는 거예요.

### 클라 → 서버: 리모트 `"FinisherPick"` (id, option)
- 인자는 정확히 2개예요: `id`(number, 받은 카드의 Id)와 `option`(`"Help"` | `"Tickle"`).
- 서버는 이것만 받아요. 아니면 조용히 무시해요.
  - 열린 카드가 있음
  - Id가 같음
  - 시간 안(Seconds + Grace 1초)
  - 처음 고름(1회)
  - RateLimit 0.3초
- 고른 순간 카드는 닫혀요. 같은 Id를 다시 보내도 무시해요.

### 서버 → 클라: `Fx "FinisherEnd"` (그 사람에게만)
```lua
{ Id = 17, Pick = "Help",  -- "Help" | "Tickle" | "None"(시간 끝)
  Stat = "Honor", Score = 1,   -- 실제로 바뀐 점수(+1 / -1 / 0)
  Item = "Jelly", N = 2, Gold = 0 }  -- 실제로 받은 덤(젤리가 꽉 차서 골드로 바뀐 몫은 Gold에)
```
- 클라는 이걸 받으면 카드를 닫아요. 받지 못해도 Seconds가 지나면 스스로 닫아요.
- 소리: 고른 순간 `Pick`으로 Purify(Help)·Devour(Tickle)를 틀지는 소리 만들기와 개발 1이 정해요. 서버는 이야기 선택의 `Fx "Choice"`를 보내지 않아요(이야기 카드 동작과 섞이지 않게).

### 그 밖에
- 자동 전투는 카드 때문에 멈추지 않아요. 카드는 10초 뒤 혼자 끝나요.
- 고르기 전에 나가면 그 카드는 `None`으로 끝나요(측정에도 None).
- 진영은 **고르는 순간**의 진영으로 점수를 매겨요.
- `FinisherService.Picked`(Util.Signal): `(player, pick "Help"|"Tickle"|"None", kind)`. 게임성 개발 3이 My Way 등에 쓸 수 있어요. 이야기 선택(`StoryQuestService.Picked`)과는 따로예요.
- Studio 시험: `DebugCommand:Invoke("Player1", "Finisher")`를 부르면 처치 없이 카드 1장이 떠요(개발 1 화면 시험용, 저장에 DebugTainted).

## 4. 측정 (TelemetryService)
- 커스텀 이벤트는 `FinisherPick` 1개만 써요.
  - 값 1
  - 칸1 = `"Halo"`(Help) | `"Horns"`(Tickle) | `"None"`(시간 끝·나감)
  - 칸2 = 내 진영(`Halo` | `Horns` | `Neutral` | `None`)
- 카드를 받은 경우에만 남겨요. 한 번에 한 장 규칙 때문에 카드를 못 받은 처치는 세지 않아요.
- `GoldIn` 출처에 `Finisher`가 하나 더 생겨요(`docs/design/metrics_server_2026-10-07.md`).

## 5. Config (새 블록, 따로)
```lua
Config.Finisher = { Kinds = { BigSlime = true }, Seconds = 10, Grace = 1, Points = 1,
	Help = { Item = "Jelly", N = 2 }, Tickle = { Gold = 4 }, Text = { ... } }
Config.ScoreBudget = { PerDay = 5 }
Config.Data.Defaults.ScoreBudget = { Day = 0, N = 0 }
Config.RateLimits.FinisherPick = 0.3
```

## 6. 시험
- 파일: `tools/test_finisher.py` + `tools/fixtures/finisher_offline.luau`.
- 진짜 MonsterService·CombatService·ProgressionService·LootService를 띄운 오프라인 세계에서 돌리고, 변이(mutation)도 넣어요.
- 확인하는 것:
  - 수동·자동·섞임 처치
  - 15초 밖 수동 공격
  - 다른 몬스터
  - 고름·시간 끝·늦은 고름·두 번 고름·남의 Id·이상한 인자
  - 빛·뿔·중립 점수와 A23-58 바닥
  - 하루 상한과 날 바뀜
  - 젤리 꽉 참
  - 처치 보상·첫 주문서 보장이 그대로인지
  - 측정 이벤트
