# 황금 알 줍기 — 서버 ↔ 화면 약속 (초안 v1, 게임성 개발 1 → 개발 2, 2026-10-11 밤)

설계: `docs/design/golden_egg_2026-10-11.md`, SPEC A23-131·A23-134. 서버 = 게임성 개발 2(`GooseEggs.luau`·`GooseService`), 화면 =
게임성 개발 1(`EventHUD`·`Fx`·`Audio`·`QuestTarget`·`WorldMap`). 시간은 모두 `Util.Now()`(= `workspace:GetServerTimeNow()`).
이 문서가 이름·모양의 기준이에요. 바꾸고 싶으면 이 문서를 고치고 서로 알려요.

## 1. 원칙
- 알마다 리모트를 보내지 않아요. 서버는 **알 부품 + 속성**만 두고, 포물선·반짝임·통통 뛰기·줍기 팝은 화면이 그려요.
- 늦게 들어온 사람도 같은 화면을 봐야 해서, 계속 이어지는 상태(점수·연장전·거위 행동)는 **속성**, 한 번 일어나는 일
  (배달·반납·쫓기 시작)은 **`Net.Fx`**로 보내요.
- 점수는 서버가 정수로 반올림한 값 하나만 올려요(H 곱한 뒤). 막대·결과·`GooseCount`가 모두 그 값을 써요.

## 2. Config (공유, 값은 개발 2가 정함 — 화면은 읽기만)
```lua
Config.Goose.Mode = "Eggs" -- "Tug" = 옛 줄다리기 (화면도 옛 막대로 돌아감)
Config.Goose.Egg = {
	Kinds = { -- Points는 기본 점수(왕관은 그때 정해서 부품 속성으로), Slots = 머리 위 칸
		Gold = { Points = 10, Slots = 1 }, Bouncy = { Points = 20, Slots = 1 },
		Big = { Points = 30, Slots = 3 }, Crown = { Points = 50, Slots = 3 },
		-- Feather = { Points = 0, Slots = 0 }, -- A23-134 장인 깃털이 땅에 떨어지는 물건이면
	},
	MaxSlots = 3, PickRadius = 4.5, PickHeight = 6, -- 서버는 +0.5 여유
	Center = Vector3.new(0, 0, 0), -- 링 가운데(분수). 화면의 링 경계 점·흔들림 거리·평소 마름모가 이 점을 씀
	RingRadius = 54, WobbleFrom = 45, -- 링 끝(반납), 45칸부터 든 알이 흔들림(화면)
	Home = { Halo = Vector3.new(-30, 0, -30), Horns = Vector3.new(-30, 0, 30) }, HomeRadius = 8,
	IdleReturn = 10, IdleWobble = 7, -- 들고 서 있기: 7초부터 흔들림(화면), 10초에 반납(서버)
	FlyTime = 0.7, -- 낳은·튄 알이 날아가는 시간(이 동안 못 주움)
	Tag = { On = true, Radius = 3, Hold = 1, Shield = 3, Cooldown = 4 }, -- A23-134 알 술래
}
```

## 3. 땅의 알 — `workspace.Effects.GooseEggs` (Folder, 서버가 만들고 비움; `Util.GetFolder(workspace, "Effects")` 아래)
- 땅에 있는 알 하나 = 고정 부품 하나(Anchored, CanCollide·CanQuery·CanTouch 끔, PointLight·Highlight 없음). 부품 CFrame =
  **내려앉을 자리**(땅 위). 화면은 이 부품을 `LocalTransparencyModifier = 1`로 숨기고, 그 부품을 복제한 것(MeshPart거나
  SpecialMesh가 있으면 그 모양 그대로, 없으면 코드 알)으로 포물선·반짝임을 그려요. 그래서 서버 부품에는 ParticleEmitter·빛을 달지 않아요
  (Tripo 알 모델이 오면 부품만 바꾸면 화면도 따라와요).
- 속성:

| 이름 | 모양 | 뜻 |
|---|---|---|
| `Id` | 정수 | 판 안에서 겹치지 않는 번호 |
| `Kind` | "Gold" / "Bouncy" / "Big" / "Crown" (/ "Feather") | 알 종류 |
| `Points` | 정수 | 이 알의 점수(왕관은 그때 값) |
| `From` | Vector3 | 날아오기 시작한 자리(거위 배, 쫓기·술래로 떨어뜨린 사람 머리, 통통 알의 옛 자리) |
| `LandAt` | 숫자 | 내려앉는 시각(이때부터 주울 수 있음) |

- 서버가 알을 옮길 때(통통 알 폴짝, 다시 뽑기)는 부품 CFrame과 `From`·`LandAt`을 **같이** 바꿔요. 화면은 `LandAt`이 바뀌면 그 포물선을
  다시 그려요.
- 주워지면 부품을 지우고(Destroy) 줍는 사람의 `EggCarry`를 올려요. 반납(15초 방치, 판 끝)은 지우기 + `EggReturn` Fx.

## 4. 플레이어 속성 (서버가 씀)
| 이름 | 모양 | 뜻 |
|---|---|---|
| `EggCarry` | 정수 0..3 | 든 칸 수(CharacterVisuals `EggStack`, 속도). `EggStack`의 알들은 머리(또는 등)에 **Motor6D `EggJoint`** 하나로 붙여 주세요 — 화면이 그 `Transform`으로 링 끝·서 있기 때 알을 흔들어요 |
| `GooseCount` | 정수 | 이번 판 내 배달 점수(지금 이름 그대로) |
| `EggDelivered` | 정수 | 이번 판 내가 배달한 알 개수(보상 기준 "2개 또는 20점") |
| `EggCan` | bool | 지금 알을 주울 수 있나(빛·뿔 참가 편, A23-134 장인 포함 / 괴수·원한 자루·협동 판의 늦은 상대 편·None = false). 화면은 false면 알을 반투명으로, 줍기 미리 보기도 안 함 |
| `EggShield` | 숫자 | 알 술래 보호가 끝나는 시각(화면: 둥근 보호 빛) |

## 5. GameState 속성
- 그대로: `GooseActive`, `GooseEndsAt`(연장전에도 **안 바꿈**), `GooseNextAt`, `GooseMode`("Versus"/"Coop"), `GooseCoopSide`,
  `GooseCoopTarget`(링에 들어온 사람마다 늘어남), `GooseCoopPeople`.
- 뜻이 바뀜: `GooseRescue` = 빛(둥지) 점수, `GoosePoach` = 뿔(수레) 점수 — Eggs 모드에서는 **정수**.
- 새로: `GooseOvertimeUntil`(왕관 알 연장전이 끝나는 시각, 없으면 0). 화면은 이때 막대 시계를 왕관 + 금색으로 바꾸고 째깍 소리는 이 시각 기준.

## 6. 거위 모형 — `workspace.Effects.GoldenGoose` 속성 (지금 자리 그대로)
- `Act` = "Walk" / "Nap" / "Alert" / "Chase" / "Lay", `ActUntil` = 그 행동이 끝나는 시각. 화면: Nap = Zzz 아이콘·코골이, Alert = "!"
  아이콘·꽥(쫓기 1초 전), Chase = 쫓는 동안. 늦게 온 사람도 보이게 속성으로 둬요.
- 머리 위 "Golden Goose" 글(`GooseLabel`)은 지워요(설계 '지울 것').

## 7. Net.Fx (한 번 일어나는 일, 모두에게)
| 이름 | data | 화면 |
|---|---|---|
| `EggDeliver` | `{ UserId, Pos, N, Points, Side }` (Pos = 집 고리 가운데, N = 알 수, Points = 정수, Side = "Halo"/"Horns"/"Neutral") | 내 배달이면 "+Points" 팝 + EggDeliverHalo/Horns. 남의 것은 소리만 30칸 안에서 |
| `EggReturn` | `{ Froms = { Vector3, … } }` | 알이 거위에게 날아감(링 밖·발판·Travel·진영 바꿈·쓰러짐·나감·서 있기·15초 방치·판 끝) |
| `EggTag` | `{ Victim, By, Pos }` (UserId 둘) | 술래 성공 팝·소리(떨어진 알은 3절의 `From`/`LandAt`로 날아감) |
| `GooseEnd` | 지금 그대로 `{ Pos, Winner, Coop }` | 조각 색(빛 승 = 금, 뿔 승 = 어둡게), 이긴 편 집에 색종이 |

- 설계 0단계의 `EggLay`·`EggPop`은 리모트로 보내지 않아요: 낳기 = 폴더에 부품이 생김, 줍기 = 부품이 사라지고 누군가의 `EggCarry`가
  오름(화면이 알아서 그림). `GooseNap`·`GooseChase`는 6절의 `Act` 속성으로 대신해요.

## 8. 화면이 미리 하는 것 (서버가 알아야 할 것)
- 줍기 미리 보기: 내 몸이 평면 `PickRadius`·높이 `PickHeight` 안이고, `EggCan`이고, 남은 칸이 있고, `LandAt`이 지났으면 화면이 그 알을
  먼저 숨기고 팝을 보여 줘요. 0.6초 뒤에도 부품이 폴더에 있으면 다시 보여 줘요. 서버는 반경 0.5 여유를 줘요.
- 내 집 고리(나만 보임)·링 경계 반짝이 원·알 흔들림(45칸·서 있기 7초)·내려앉을 자리 그림자는 화면만 해요. 서버 리모트 없음.
- 마지막 째깍 소리는 "이번 판에 알을 주운 사람"(내 `EggCarry`가 한 번이라도 올랐음)만 — 화면이 알아서 셈.

## 9. 개발 2에게 묻는 것
1. A23-134 장인(중립): 알을 들고 다니나(집이 어디?), 줍자마자 가방으로 가나? 화면은 `EggDeliver` Side = "Neutral"이면 "+1" 팝만 해요.
2. 깃털은 땅에 떨어지는 물건(Kind "Feather")인가요, 아니면 알과 같이 받는 재료인가요?
3. "Bring 2 eggs for a reward."는 서버가 판 끝에 Notify로 보내 주세요(실패 사실 한 줄, 화면은 따로 안 띄움).

### 답 (개발 2, 2026-10-12)
1. **장인(중립):** `EggCan` = true. 들고 다니지 않고 줍자마자 가방으로(`GoldenEgg`, 알 종류 상관없이 1개; `EggCarry` 안 오름·느려지지 않음), 점수·P·N·H·협동에 안 셈. Fx `EggDeliver { UserId, Pos, N = 1, Points = 0, Side = "Neutral" }` → 화면은 "+1" 팝. 판 끝에 장인 중 가장 많이 주운 사람(동점 모두) +50%(내림, 최소 +1).
2. **깃털:** 땅의 물건 `Kind = "Feather"`(Points 0, Slots 0), 같은 폴더·같은 속성. 도착 재채기 3개 + 낮잠마다 1개. `EggCan`인 누구나 줍고 가방으로 `GooseFeather`(칸·점수·속도 없음).
3. **"Bring 2 eggs for a reward."** = 판 끝에 서버가 `Net.Notify`(빛·뿔, 알 1개 이상 날랐지만 기준(알 2개 또는 20점, 광장 16명 이상이면 1개) 미만인 사람만).
- **A23-141 (10/12):** 알 판은 거위 광장에서 — 링 가운데·집은 `workspace.GooseSquare`의 GooseSpot·Nest(빛)·Cart(뿔)(§2의 `Center`·`Home`은 표시 부품이 없을 때만 쓰는 옛 값). 광장 안 사람만 줍고, 광장 벽이 링 끝을 대신함. 들어가기·나오기·이름: `docs/design/goose_square_contract_2026-10-12.md`.
