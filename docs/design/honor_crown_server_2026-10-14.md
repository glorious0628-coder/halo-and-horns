# 사냥 명예·왕관전 새 점수 — 서버 (게임성 개발 2, 2026-10-14)

근거: `docs/design/gameplay_plan_2026-10-13.md` 2-A #4·#5, SPEC A23-135·A23-137, 설계 `docs/design/crown_war_content_2026-10-11.md`(점수 예산 표).
가지 `dev2-honor-crown`(fix/mischief-name 위). 보스 경쟁·황금 시간·조각 비는 이 가지에 없어요(따로 할 일).

## #5 왕관전 점수 (A23-135·137)

| 출처 | 전 | 지금 |
|---|---|---|
| 사냥 | 1마리 = 1점 | **100마리 = 1점**(`Config.War.KillsPerPoint`), 황금 몬스터 = 5마리 |
| PvP KO | 20 + 별당 5 | **2 + 별당 0.5**를 정수로 공정 반올림(2.5 → 2 또는 3), 한 사람(UserId) 판당 3번까지(`PvPKOMaxPerRound`, 다시 들어와도 그대로) |
| 괴수 | 150 | **30**(`Config.Kaiju.HaloWarPoints/HornsWarPoints`) |
| 황금 알 | 30 | 30(그대로, A23-137) |
| Clatter 보스 | 20 | **2**(보스 경쟁이 들어오면 바뀜) |
| 상자(`ChestMinPoints`) | 개인 30 | **개인 1**(= 100마리 또는 PvP KO 한 번) |
| 한 편만 있을 때(`SiegeTarget`) | 1인 150 | **1인 1.5**(= 1인 150마리) |

- **개인 점수는 정수**예요. 처치 수(단위)를 사람마다 세다가 100이 되면 개인 +1점이에요. 남은 단위는 **저장**돼요(`data.CrownUnits`, 판·접속·서버를 넘어 이어짐; 편을 바꿀 때만 지움). 그래서 "My pts"에 소수가 없고, 몬스터마다 '+1'이 뜨지 않아요.
- **편 점수(풀)는 소수**로 바로 쌓여요(100마리 = 1). 같이 잡은 몹은 CR-M18처럼 사람 수로 나눠요. 1인당 점수는 **소수 두 자리**로 보이고(HUD `fmtScore`), 승부도 그 보이는 값으로 내요(같아 보이면 비김).
- 새 신호 `WarService.PersonalAdded(player, n, source)` — 개인 점수가 정수로 오를 때만("Hunt" | "PvP" | "Other").
- 이야기 퀘스트의 왕관 단계(Type WarPoints)는 **처치 단위**를 세요(1마리 = 1, 황금 = 5; 정수 점수·PvP는 안 셈). 글 "Monsters for the crown %d/%d". M2_1 **15**(그대로), GW4 40 → **100**. (처음엔 정수 점수 1·3이었지만 최종 검수 10/13: 짧게 노는 아이가 M2_1을 못 끝냄 → 마리 수로.) M2_1 시작 글 = "Every 100 monsters you beat = 1 point for your side!". S2 글 = "Win a crown war chest".
- 상자·한 편 목표는 '옛 난이도를 새 규모로 옮긴 값'이에요. 보스 경쟁·황금 시간이 들어오면 설계 표대로(상자 3, 한 편 10~12) 올리고, 10/17·11/7 시험 기록으로 다시 맞춰요.

## #4 PvP 없이 명예·장난 점수 (A23-135, A23-166 이름)

- 새 `HuntFameService`: **자기 레벨 구역이나 더 어려운 구역**의 몬스터 100마리(황금 = 5)마다 Honor(빛) / Infamy(뿔, 화면 글은 Mischief) +1.
  - 자기 레벨 구역 = `Config.QuestZoneForLevel`(Lv1~9 초원, Lv10~24 숲, Lv25+ 폐허). Lv15가 초원에서 잡으면 안 셈.
  - 레벨 문 없는 구역(할로윈·새 구역, MinLevel 1)은 `Config.HuntFame.ZoneLevel`(권장 시작 레벨)로 봐요: Crystal Cave Woods 14, Coral Coast·Haunted Hollow 8, Pumpkin Patch 1.
  - 개인 몬스터·연습 몬스터·Clatter 무임승차(`info.Minor`)·장인(Neutral)·진영 없음은 안 셈.
  - 저장 `data.HuntFame`(더하기만)에 남은 수가 남아요. 오를 때 "Honor +1 from hunting!" / "Mischief +1 from hunting!" 한 줄.
  - `PlayerService.GrantFame(…, { Hunt = true })` → 주간 PvP 랭킹 보드에는 안 올라가요(보드는 공정한 PvP만).
- 1000마리(약 2~3시간)면 Squire/Rascal 다음 계급(10점)이에요. 숫자는 `Config.HuntFame`.
- '하루 선행 점수 주는 곳'(선택 카드·마무리 카드·잃은 물건)은 공용 선택 카드 창(2-A #3, 개발 1)이 생기면 켜요. 이 가지에서는 안 켬.
- 도움말 줄: "… from fair fights, story choices and hunting (100 monsters of your level = 1)."

## 시험

- 새 `tools/test_crown_points.py` + `tools/fixtures/crown_points_offline.luau`: 진짜 WarService·HuntFameService·StoryQuestService.EventAmount.
- 고친 시험: field_boss·a2390(Clatter 2), return(상자 1).
- 최종 검수 API 반박 검토(10/13, FIX FIRST) 고침: 처치 단위 저장, M2_1·GW4 마리 수, KO 상한 UserId, PvP 정수, 점수 두 자리·보이는 값으로 승부, ZoneLevel, Minor 제외. 시험 75개·변이 39/39.
- 남은 질문(사용자): 같이 잡은 몹은 사냥 명예를 기여자마다 1마리씩 줘요(파티면 사람 수만큼). WarShare처럼 나눌지는 사용자 결정.
