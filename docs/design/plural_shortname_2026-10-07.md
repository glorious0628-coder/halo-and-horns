# 단·복수와 짧은 퀘스트 이름 (게임성 개발 2, 2026-10-07)

검수 요청 두 가지(사용자 캡처 'Vacation Bonus ... 1 days', 폰 749 화면 "Free the sup…" / "Hit 4 monst…").

## 1. 1 day / 2 days — `Config.Plural`

- `Config.PluralWords` = 복수 → 단수 표(days → day, times → time, slimes, monsters, materials, quests, players, hits,
  basic hits, Wanted players, Knights, more great items …).
- `Config.Plural(text)`: 숫자를 넣어 만든 문장에서 **혼자 있는 1** 뒤의 복수만 단수로 바꾼다("1 days" → "1 day").
  11, 0.1, 1,000, 1/3은 그대로. 문자열이 아니면 그대로 돌려준다.
- 쓰는 법: `Config.Plural(string.format(text, n))`. 새 "%d <명사>s" 문구를 만들면 그 명사를 `PluralWords`에 한 줄 더한다.
- 서버에서 씌운 곳: 판매(LootService SellDone), 일일·추가 퀘스트 문장(QuestService, 옛 저장의 "tug 1 times"도 불러올 때
  고침), 첫 임무 문장, 이야기 퀘스트 줄(StoryQuestService), 괴롭힘 규칙 문장(Config가 불러올 때 만드는 줄).

### 게임성 개발 1에게 (클라, 5곳 — 한 줄씩 씌우기)
> 2026-10-09 검수: 5곳 모두 씌움(main, 아래 줄 번호는 그 뒤 바뀜).

| 파일:줄 | 지금 | 바꿀 것 |
|---|---|---|
| HUD.luau:3049 | `string.format(TXT.QuestTouchClaim, claimable)` | `Config.Plural(string.format(...))` ("Claim 1 quest!") |
| Panels.luau:2619-2620 | `string.format(T.WeaponEffectNowF, now)` / `string.format(T.WeaponEffectF, now, with)` | 둘 다 `Config.Plural(...)` ("Slime in 1 basic hit") |
| Panels.luau:2922 | `string.format(T.VacationHeaderF, days)` | `Config.Plural(...)` ("away for 1 day") |
| Announce.luau:70 | `string.format(tmpl, who, count)` | `Config.Plural(...)` ("found 1 more great item!") |
| EventHUD.luau:975 | `safeFormat(gt.HudFull[side], mine, hits)` | `Config.Plural(safeFormat(...))` ("Hit it 1 time") |

검사기 `test_story_text.py`가 앞의 셋을 `plural-literal` 경고로 알려 준다(씌우면 사라짐). 뒤의 둘은 문구를 그때그때
고르는 곳이라 검사기가 따라가지 못한다.

## 2. 짧은 퀘스트 이름 — `ShortName` (14자 이하)

- 모든 퀘스트 정의에 `ShortName`(영어, 쉬운 말, 14자 이하):
  - 이야기 퀘스트 48개 `Config.StoryQuests.Defs[id].ShortName` (예: M1_1 "Slime jelly", S0 "Learn to fight",
    M3_1 "Goblin thieves"). 단계마다 다르게 하고 싶으면 그 단계에 `ShortName`을 넣으면 그게 먼저다.
  - 일일·추가 퀘스트 틀 7개 `Config.Quests.Templates[].ShortName` (Kill "Monster hunt", Golden "Golden hunt",
    Gold "Earn gold", Release "Skill hits", Goose "Goose tug", Hunt "Catch Wanted", Plunder "Rob Knights").
    몬스터는 줄의 아이콘(Unit)이 보여 준다.
  - 게시판 일 10개 `Config.Board.Jobs[].ShortName` + 안내 줄 `Config.Board.Text.HintShort = "Job Board"`.
  - 첫 임무 줄 `Config.Tutorial.ShortNames` (Welcome ~~"Meet the Guide"~~ → "Meet %s"(안내자 이름), Travel ~~"Supply road"~~ → "To the meadow", Quest "Supply road", Forge
    "To the Forge", IronLevel·Zone "Reach Lv %d"(그 목표에 필요한 레벨), IronGold "Iron weapon").
- 서버는 퀘스트 목록(`Quests` 리모트 JSON)의 줄마다 `ShortName`을 같이 보낸다(QuestService 첫 임무·일일·추가,
  StoryQuestService 이야기 줄, BoardService 게시판 줄). 없는 줄은 `ShortName`이 비어 있고, 클라는 지금처럼 자른다.
- 이미지 개발: 폰 HUD 퀘스트 줄에서 `entry.ShortName or <지금 문장>`.

## 3. 알림 두 문장
- 첫 임무 보상 알림 4줄(Claimed·ClaimedArmed와 En 짝)의 "+%s gold · Get…/Check…"를 "+%s gold. Get…/Check…"로
  나눴다. 검수가 말한 "Daily quest done! +60 gold · Check the board for more jobs."는 main·dev2·imgdev의 src 어디에도
  그대로는 없다(같은 꼴인 이 4줄을 고침).

## 4. 검사
- `py tools/test_story_text.py`: 9 `plural-*`(1 + 복수, PluralWords에 없는 명사, 씌우지 않은 string.format, 클라
  문구), 10 `shortname-*`(14자 넘음, 빠짐). 변이 10/10.
