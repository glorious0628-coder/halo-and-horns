# 몬스터 레벨 속성 — 서버 계약 (게임성 개발 2, 2026-10-09)

근거: `docs/design/system_review_round1_2026-10-09.md` #6(이름표 위험 색). 가지 `dev2-mlevel`(dev2-mobs3 위).

## 서버(끝)
- 모든 몬스터 모델(일반·개인·이벤트·보스)에 속성 **`Level`** = `Config.MonsterLevel(kind)`. 스폰할 때 한 번 달아요. 싸움 판정은 이 값을 읽지 않아요.
- `Config.MonsterLevels`(구역 띠 안: 초원 1~9, 숲 10~24, 유적 25+, 핼러윈 밭은 Lv1 밭):

| 초원 | 핼러윈 | 숲 | 유적 |
|---|---|---|---|
| Slime 2 · Flower Slime 3 · Slime Prince 5 · King Slime 8 | Pumpkin Slime 3 · Ghost Minion 6 · Little Ghost 7 · Pumpkin King 10 · Ghost King 12 | Goblin 12 · Bat Goblin 13 · Slingshot Goblin 14 · Goblin Brute 18 | Skeleton 26 · Skeleton Archer 28 · Skeleton Knight 30 · Captain Clatter 32 |

- 목록에 없는 종류는 그 구역의 `MinLevel`이에요.

## 개발 1 몫
- 이름표 색은 개발 1의 `Config.MonsterDanger`(`Tier(몬스터 Lv, 내 Lv)`, `LevelOf(kind, Level 속성)`, `Colors`)가 이 `Level` 속성을 읽어 칠해요(main에 이미 있음). 제 쪽의 같은 이름 함수는 병합 때 지웠어요(2026-10-09).
- 경계: 개발 1 표는 Weak −5 / Strong +3 / Deadly +8이에요. 검수가 확정한 Weak는 −6이라 맞출지 검수가 정해요.

## 시험
`py tools/test_monster_level.py` — 검사 21개(모든 종류에 레벨, 띠 안, 구역 안 순서, 스폰 때 속성, 개발 1 Tier로 본 색), 변이 6/6.
