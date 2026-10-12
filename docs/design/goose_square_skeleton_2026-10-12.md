# 거위 광장 공간 골격 — 부품 이름·자리 표 (이미지 개발, 2026-10-12, SPEC A23-141)

계약: `docs/design/goose_square_contract_2026-10-12.md`. 이 표는 계약 §3 "공간 골격을 누가 어디에 두는지"의 답.
**만든 이:** 이미지 개발 (`tools/worldkit/goose_square.luau` + `py tools/goose_square.py --mode apply|remove|survey`). 메인에는 메인 반영 1이 `py tools/goose_square.py --mode apply --emit build/goose_square_apply.luau`로 만든 파일(ALLOW_MAIN true)을 메인에서 돌려 넣음.
**어디에:** 같은 place, `workspace.GooseSquare` (Model). 중심 기본 **(6000, 200, 6000)**(바닥 윗면 높이 y=200) — 모든 구역·Map.Bounds·안개 끝(950) 밖. 서버가 다른 값을 원하면 `--center x,y,z`로 다시 만들면 됨(개발 2와 맞출 것).

## 방향·크기 (로컬: x 동, z 남, 북 = -z; 바닥 윗면 = 중심 y)
| 이름 | 무엇 | 자리(중심 기준) | 비고 |
|---|---|---|---|
| `Floor` | 바닥 둥근 모서리 네모 110×90(모서리 반지름 16), 두께 4 | (0, -2, 0) | **태그 `WalkGround`**, 크림 SmoothPlastic, PrimaryPart |
| `GooseSpot` | 가운데 낮은 둥근 단, 지름 16, 높이 0.8 | (0, 0.4, 0) | 태그 `WalkGround`; `GooseSpotRing` = 아래 금 고리(지름 18) |
| `Nest` | 빛 둥지 자리(북쪽 끝): 둥근 받침 지름 6 + `NestCup` 금 | (0, 0.6, -37) | `NestRing` = 바닥 파란 원 지름 14 |
| `Cart` | 뿔 수레 자리(남쪽 끝): 낮은 상자 6×2×4 + 바퀴 2(`CartWheel`) | (0, 1.9, +37) | `CartRing` = 바닥 빨간 원 지름 14 |
| `SpawnHalo` | 빛 진영 들어오는 자리 원 지름 12(반경 6), 안 막힘 없음 | (0, 0.05, -24) | 반투명 표시, CanCollide false |
| `SpawnHorns` | 뿔 진영 들어오는 자리 원 지름 12 | (0, 0.05, +24) | 반투명 표시, CanCollide false |
| `Rim` | 둘레 낮은 돌 테두리(높이 3, 폭 3, 앉을 수 있는 턱) | 바닥 가장자리 | `GoldBand_*` = 윗면 금 띠(곧은 부분만) |
| `Wall_E/W/N/S` | 보이지 않는 벽 높이 30(CanCollide, Transparency 1) | 테두리 바깥 | 떨어지지 않게 |
| `SafetyPlate` | 보이지 않는 안전 판 | 바닥 아래 -14 | |

모델 속성(월드 좌표 Vector3): `NestPos`, `CartPos`, `GooseSpotPos`, `SpawnHaloPos`, `SpawnHornsPos`, `Skeleton = true`. 지도·QuestMarker는 `Nest`·`Cart` 부품 또는 이 속성을 읽으면 됨.

## 안 한 것
몬스터 없음(구역 밖), 꾸미기(나무·깃발·조명) 없음(교차로 차례), 빛살 줄무늬 없음(금 띠는 테두리·고리뿐). 재질 = 승인된 것만: 크림 SmoothPlastic (240,232,215) + 금 (255,168,36)(HH_HaloGoldTrim이 있으면 그 변형).
