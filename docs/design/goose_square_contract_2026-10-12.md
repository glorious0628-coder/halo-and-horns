# 거위 광장 들어가기·나오기 — 서버 ↔ 화면 약속 (초안 v1, 게임성 개발 1 → 개발 2, 2026-10-12)

SPEC A23-141(사용자 10/12): 황금 알은 'Join'을 누른 사람만 같은 서버 안 맵 밖의 거위 광장(Goose Square)에서. 진짜 교차로 광장엔
거위·알·막대가 없음. 알·점수·보상 약속은 `docs/design/golden_egg_contract_2026-10-11.md` 그대로(그 문서의 '링에 들어온 사람' =
'거위 광장에 들어온 사람'). 서버 = 게임성 개발 2, 화면 = 게임성 개발 1. 이름이 바뀌면 개발 2가 이 문서를 고치고 알려 줘요.

## 1. 원격 (c→s, 하나)
- `GooseSquare`(what): what = `"Join"` | `"Leave"`, `select('#') == 1`, IsReady, `RateLimits.GooseSquare = 1`.
- Join: 서버가 조건을 보고 들여보냄(화면 어두워짐은 화면이 함, 서버는 기다리지 않음). 거절이면 `Net.Notify` 한 줄(아래 Text 키).
- Leave: 언제든. 판이 끝나면 서버가 모두 내보냄(원격 없이).

## 2. 플레이어 속성 (서버가 씀)
| 이름 | 값 | 화면이 하는 것 |
|---|---|---|
| `InGooseSquare` | bool | true가 되면/false가 되면 짧게 어두워졌다 밝아짐(0.25초 어둡게 → 0.35초 밝게), 막대 버튼 Join ↔ Leave, 둥지·수레 표시(QuestMarker·WorldMap·QuestTarget)와 알 화면(EggFx 막대·고리·째깍)은 이게 true일 때만 |
| `GooseJoinBlock` | "" 또는 "Dead" / "Monster" / "Grudge" / "PvP" | ""가 아니면 Join 버튼 흐리게(눌러도 아무 일 없음, 글 없음 — A23-130). 서버가 바뀔 때만 씀(PvP는 맞거나 때린 뒤 10초 지나면 ""로) |

- 화면은 `GooseJoinBlock`이 없으면(서버가 아직 안 씀) 버튼을 밝게 두고, 거절은 서버 Notify로만 알아요.
- 순간이동(들어갈 때 자기 진영 쪽, 나올 때 누른 자리 / 위험하면 마을 시작점)은 서버. 화면은 `InGooseSquare` 바뀜만 봐요.

## 3. GameState
- `GooseActive`(그대로) = 열려 있음 → Join 버튼은 이때만 보여요. 판 끝(`GooseActive` false)이면 버튼 숨김.
- 새 이름 없음. 광장 위치를 화면이 알아야 하면(지도) `workspace.GooseSquare` 모델(서버 또는 place)의 `Nest`·`Cart` 부품(또는 속성
  `NestPos`·`CartPos`)을 읽어요 — 공간 골격을 누가 어디에 두는지 정해지면 여기 적기.

## 4. Config (공유)
```lua
Config.Goose.Square = {
	Remote = "GooseSquare",
	Fade = { In = 0.25, Out = 0.35 },
	Text = { Join = "Join", Leave = "Leave",
		Dead = "You can't join right now.", Monster = "You can't join right now.", Grudge = "You can't join right now.",
		PvP = "You can't join during a fight.", Closed = "The goose is gone." },
}
```
- Text는 서버 Notify(거절)와 화면 버튼이 같이 써요(쉬운 영어 짧게, A23-130). 값은 개발 2가 넣고 화면은 읽기만.

## 5. 화면이 하는 것 (서버 몫 아님)
- 위 막대(EventHUD) 거위 칩에 Join / Leave 버튼(승인된 UI 부품 + UIKit 대체), 들어갈 때·나올 때 짧게 어두워짐.
- 교차로 광장(진짜 맵)에는 알 화면 없음: EggFx 막대·고리·소리·미리 보기·QuestMarker 둥지/수레는 `InGooseSquare`일 때만.
- 자동 전투는 서버가 멈추고(몬스터 없음) 돌아오면 저장대로 — 화면은 자동 전투 버튼 상태만 따라감.
