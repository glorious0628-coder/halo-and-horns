# 퀘스트 많이(A23-56) 서버 쪽 — quest_volume §5 순서 (게임성 개발 2, 2026-10-07)

설계: `docs/design/quest_volume_2026-10-06.md`. 게임 글은 영어(A23-48).
- 메인 앞당김(3장 M3_1~M3_8 + E7 + Pip1): `docs/design/town_quests_server_2026-10-07.md` 9절(f3fb19c).

## 1. E12 레벨대별 일일 — 고블린 숲 Lv10~24
- `Config.Quests.Woods = { MinLevel = 10, MaxLevel = 24, RewardMinutes = 3, ChestMinutes = 6, Dailies }` — Newbie(Lv1~9)와 같은 방식: 줄은 템플릿 Id를 다시 쓰고, Targets는 정확한 수, 세 칸은 늘 서로 다른 목표.
  | 줄 | 목표 | Weight |
  |---|---|---|
  | Kill | 고블린 12~15 (보통 줄, 더 센 몬스터는 1, 약한 건 조각) | 3 |
  | Kill (Strict) | 고블린 우두머리 2 (고블린은 0) | 2 |
  | Release | 몬스터를 맞힌 수동 스킬 4~6번 | 3 |
  | Gold | 사냥 골드 150 / 200 / 250 | 3 |
  | Golden | 황금 몬스터 1 | 1 |
  | Goose | 거위 줄다리기 1 (빛·뿔만) | 1 |
  | Hunt / Plunder | PvP 1 (빛 / 뿔, Lv15+ · 새싹 보호 끝, 하루 하나 — 지금 규칙 그대로) | 1 |
- 보상: 한 칸 `HuntValue(level, 3)`, 세 칸 다 받으면 상자 `HuntValue(level, 6)` → 하루 = 사냥 15분어치(예전 템플릿 일일은 25분어치, 일은 약 3배였음). CR-M6 상한(5분)보다 작음.
- **Lv25+는 예전 템플릿 일일 그대로.** 상자는 지금처럼 '만든 레벨대'와 지금 레벨대 중 작은 것(Lv24 묶음을 Lv25에 받으면 숲 상자).
- 휴가: `Config.DailyDayMinutes` = Lv1~9 10분 / **Lv10~24 15분** / Lv25+ 25분, 하루 몫 70%(최대 3일) 그대로. 지난날 몫(f)은 그날 만든 레벨대로 계산.
- QuestService: `bandAt(level)`(Newbie → Woods → 없음), `newQuest`·`chestAt`·`runDayCheck`가 그 줄을 씀. A23-14 새싹 일일 줄은 그대로.
- 검사: `py tools/test_a23_14.py` 새 그룹 dailies-woods + 옛 Lv10 기대값을 Lv25(템플릿)·숲 밴드로 고침 — 3335검사, 변이 26/26.
- 개발 1: 화면은 그대로(일일 줄은 같은 Quests 원격). 숲 일일 Text 예 "Defeat Goblin Brute ×2", "Earn 200 gold by hunting".

## 2. 다음
- E11 사냥터 게시판(서버, 점수 0) → 서브 18개 데이터 → ③ 몬스터 한마디(lines_pack §2).
