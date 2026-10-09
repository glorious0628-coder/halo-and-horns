# 몬스터 레벨 속성 — 서버 계약 (게임성 개발 2, 2026-10-09)

근거: `docs/design/system_review_round1_2026-10-09.md` #6(이름표 위험 색). 가지 `dev2-mlevel`(dev2-mobs3 위) → main 병합 c87215c7.

## 서버(끝)
- 모든 몬스터 모델(일반·개인·이벤트·보스)에 속성 **`Level`** = `Config.MonsterLevel(kind)`. 스폰할 때 한 번 달아요. 싸움 판정은 이 값을 읽지 않아요.
- `Config.MonsterLevels`(구역 띠 안: 초원 1~9, 숲 10~24, 유적 25+, 핼러윈 밭은 Lv1 밭):

| 초원 | 핼러윈 | 숲 | 유적 |
|---|---|---|---|
| Slime 2 · Flower Slime 3 · Slime Prince 5 · King Slime 8 | Pumpkin Slime 3 · Ghost Minion 6 · Little Ghost 7 · Pumpkin King 10 · Ghost King 12 | Goblin 12 · Bat Goblin 13 · Slingshot Goblin 14 · Goblin Brute 18 | Skeleton 26 · Skeleton Archer 28 · Skeleton Knight 30 · Captain Clatter 32 |

- 목록에 없는 종류는 그 구역의 `MinLevel`이에요.

## 개발 1 몫
- `Config.MonsterDanger(내 레벨, 몬스터 Level)` → `"Weak"`(6 이상 낮음, 회색) / `"Even"`(흰색) / `"Strong"`(3 이상 높음, 노랑) / `"Deadly"`(8 이상 높음, 빨강). 경계는 `Config.MonsterDangerBands = { Weak = -6, Strong = 3, Deadly = 8 }`(검수 확정).
- 개발 1의 `Config.MonsterDangerLook`(색 `Colors`, `LevelOf(kind, Level 속성)`, `Tier`)가 이 함수를 불러 이름표를 칠해요(03e7e71e).
- 예: Lv1에게 초록 슬라임은 흰색, Slime Prince는 노랑. Lv10에게 Goblin Brute는 빨강. Lv25에게 Captain Clatter는 노랑.

## 시험
`py tools/test_monster_level.py` — 검사 26개(모든 종류에 레벨, 띠 안, 구역 안 순서, 스폰 때 속성, 위험 띠, MonsterDangerLook이 같은 띠를 씀), 변이 11/11.
