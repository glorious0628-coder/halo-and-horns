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

## 6. 서버 (게임성 개발 2, 2026-10-12, 가지 dev2-goose-square)
- **모듈:** `src/ServerScriptService/GooseSquare.luau`(GooseService만 부름, Main 목록 아님). 원격 `GooseSquare`는 Net.Names에 등록, 서버가 `Config.Goose.Square.Remote or "GooseSquare"`로 연결. `Config.RateLimits.GooseSquare = 1`은 서버 쪽 Config에.
- **화면 표 `Config.Goose.Square`(Remote·Attr·Block·Fade·Text)는 개발 1 가지에서만 정의.** 서버는 읽기만: 속성 이름 `Attr or "InGooseSquare"`, `Block or "GooseJoinBlock"`, 거절 글 = `Text[키]`(표·키가 없으면 Notify 안 함, 오류 없음).
- **서버 숫자 = `Config.Goose.SquareSpace`:** Enabled, Center (6000, 200, 6000)(바닥 윗면), Size 110×4×90(대역 바닥), WallHeight 30, Offsets(GooseSpot 0 · Nest z-37 · Cart z+37 · SpawnHalo z-24 · SpawnHorns z+24 · SpawnNeutral x-22), SpawnSpread 4, SpawnClear 6(시작점 둘레엔 알이 안 떨어짐), ReturnAfter 4, FightSeconds 10, FallBelow 25, Margin 20, BlockEvery 0.5, KillHeightPad 50.
- **공간:** `workspace.GooseSquare`(이미지 개발 골격, `goose_square_skeleton_2026-10-12.md`)의 모델 속성 `GooseSpotPos`·`NestPos`·`CartPos`·`SpawnHaloPos`·`SpawnHornsPos`·`SpawnNeutralPos`를 먼저, 없으면 같은 이름 부품, 그래도 없으면 GooseSpot(또는 Center) + Offsets. `Floor`(부품 또는 모델 상자) = 광장 범위. **모델이 아예 없을 때만** 서버가 Center에 평평한 바닥(태그 WalkGround) + 보이지 않는 벽 4개 + 같은 이름 표시 부품(투명)과 속성을 한 번 만듦(BuiltBy = "GooseSquare", 꾸미기 없음).
- **알 판:** 링 가운데 = GooseSpot, 집 = Nest(빛)·Cart(뿔), 시작점 3곳 둘레 SpawnClear 안엔 알 없음. 광장 안 사람(`InGooseSquare`)만 줍고·세고·배달함. 광장 벽이 링 끝을 대신함(링 끝 반납 없음). 협동 목표·H·'한 편 안 옴' = 광장에 들어온 사람 기준.
- **Join:** `GooseActive`일 때만(연장전 포함), 준비됨, 진영 Halo·Horns·Neutral(장인 OK), 살아 있음(`Dead`), 괴수 아님(`Monster`), 원한 자루 없음(`Grudge`), 최근 10초 안 PvP 피해를 주거나 받지 않음(`PvP`, `CombatService.LastPvPAt`). 들어가면: 누른 자리 + 그 구역 기억, 자동 전투는 **속성만** 끔(저장된 선택 그대로), 자기 진영 시작점 둘레 4칸 안·3.5칸 위로 순간이동(`ZoneService.MarkTeleported`), `InGooseSquare = true`. `GooseJoinBlock`은 준비된 모든 사람에게 0.5초마다 바뀔 때만 씀(안에 있으면 "").
- **나가기:** 'Leave' 버튼·진영 바꿈 = 돌아감 / 죽음·서버 나감·Travel·멀리 옮겨짐 = 그 자리에 둠(이미 다른 데로 감). 순서: 든 알 반납 → `InGooseSquare = false` → 자동 전투는 저장값대로 → (살아 있으면) 돌아갈 자리로. **돌아갈 자리** = 누른 자리, 단 PvP 자리·죽는 높이 + 50 아래·광장 안·누른 구역과 다른 구역(없어짐)이면 자기 진영 마을 시작점(`ZoneService.GetSpawnCFrame`, 중립·None = 교차로).
- **판 끝:** 결과 뒤 ReturnAfter(4초)에 광장 안 모두 돌아감. 바닥에서 떨어지면(옆 Margin·아래 FallBelow 밖) 바로 나감 + 돌아감, 300칸 넘게 다른 데로 옮겨지면 나감만.
- **안전:** 광장 안 사람은 PvP 때리기·맞기 없음(`PvPService.CanAttack` → "SafeZone", `Config.InGooseSquare(p)`). 몬스터 없음(구역 밖 = Outskirts). 교차로에는 거위 횃대도 없음(MapBuilder: Tug 모드에서만).
- **그 밖(서버):** 광장 안 속도 = `PlayerService.ComputeWalkSpeed` 맨 위에서 `EggPlaza`면 `Config.GooseEggSpeed(EggCarry)`(직업·펫 무시, 20 × 0.9/0.8/0.7). 알을 들면 Hop "TooHeavy". 알 탑 = CharacterVisuals `EggStack`(등 바구니, Motor6D `EggJoint` 하나 — 화면이 Transform으로 흔듦). 이야기 첫 +1은 Tug 모드에서만(알 판은 한 시간 한 번 +5). HealthService: Joins·Delivered·ScoreGap·DropFails·CheatLogs·CrownFlips.
- 시험: `tools/test_goose_square.py`(GooseSquare 실제 코드 + 연결 정적 검사 + 변이), `tools/test_golden_egg.py`(알 규칙).
