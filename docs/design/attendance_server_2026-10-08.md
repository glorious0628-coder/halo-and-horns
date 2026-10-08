# 출석 서버 계약 (SPEC A23-77) — 게임성 개발 3, 2026-10-08

근거: SPEC A23-77 (사용자 2026-10-08 "이대로", "끊기면 0되면 안 돼"). 서버 = `src/ServerScriptService/AttendanceService.luau`,
설정 = `Config.Attendance` (Config.luau 맨 끝 블록). 시험 = `py tools/test_attendance.py` (오프라인 98검사, 변이 36/36).

## 규칙
- 하루 한 번(한국 자정에 날 바뀜, `Config.DayIndex`) 7칸 출석판의 **다음 칸**을 받는다. 빠진 날은 그냥 넘어가고 다음 접속에 다음 칸. 연속 출석 없음, 아무것도 0으로 안 돌아감.
- 7칸: ① HP 물약 2 ② 골드 3분어치 ③ 강화 주문서 70% 1 ④ 골드 3분어치 ⑤ HP 물약 3 + 재료 4분어치 ⑥ 경험치 5분어치 ⑦ 주간 상자 = 골드·경험치 10분어치 + 주문서 30% 1. 7칸 뒤 다시 1칸.
  - "N분어치" = `Config.HuntValue(내 레벨, N)` (내 레벨 구역 대표 몬스터를 분당 12마리 잡는 값).
  - 재료 4분어치 = 내 레벨 구역 대표 몬스터 재료의 평균 개수(분당 12 × 4분 × 떨어질 확률). 초원 = 젤리 14개, 해골 유적 = 뼈 19개.
  - 물약이 가방에 안 들어가면 남은 병은 물약 값(25골드)으로 준다(받은 것이 사라지지 않음).
- 모은 날 수(평생): 7 칭호 Regular · 14 (출석 치장) · 28 이름표 테두리(`Border = "Days28"`) · 50 칭호 Super Regular · 100 칭호 Mega Regular. 문구는 임시 — 검수가 정한다.
  - 출석 전용 후광·뿔은 개발 2의 `Config.Looks`(A23-75 틀, `Unlock = { Attendance = 14 / 50 / 100 }`)를 그대로 쓴다. 날 수가 닿으면 **두 진영 것 모두** `MonetizationService.GrantLook`으로 열어 준다(진영을 바꿔도 있음). 알림 줄은 내 진영 것만.
  - 접속할 때 이미 닿은 이정표는 조용히 채운다(나중에 추가된 칭호·치장도 받음).
- A23-75 2배 패스: 골드는 `AddBankGold(…, "Attendance")`, 경험치는 `AddXP` — 2배는 개발 2의 ProgressionService 안에서. 알림·Fx에는 **실제로 들어온 양**을 쓴다(개발 2 판은 들어온 양을 돌려줌, 지금 main은 아무것도 안 돌려주므로 요청한 양).

## 원격·속성·신호 (화면 = 게임성 개발 1·이미지 개발)
| 무엇 | 이름 | 내용 |
|---|---|---|
| 받기 | c→s `ClaimAttendance`() | 인자 없음. 준비됨·직업 고름·1초 제한. 오늘 이미 받았으면 아무 일 없음. |
| 받을 수 있나 | 속성 `AttendReady` (bool) | 오늘 받을 칸이 열림. 한국 자정에 30초 안에 켜짐(온라인 플레이어). |
| 다음 칸 | 속성 `AttendSlot` (1~7) | 다음 받기가 주는 칸. 판 그리기: `Config.Attendance.Board[칸]` + `Config.HuntValue(Level, 분)`로 금액 계산 가능. |
| 모은 날 수 | 속성 `AttendDays` | 평생 모은 날 수. 이름표 테두리는 `Config.Attendance.Milestones`에서 Border가 있는 가장 높은 칸 ≤ AttendDays. |
| 받은 뒤 | Fx `Attendance` { Slot, Days, Gold, XP, Items = { { Id, N } }, Box } | 주인에게만. 도장 찍기·상자 열기 연출용(Box = 7칸). Items의 Id는 `Config.Loot.Items` id 또는 "HP"/"MP". |
| 알림 줄 | Notify | "Day 3 reward! +Enhance Scroll 70%", "7 days collected!", "New title: Regular!", "New look: Sprout Halo!", "New name frame!" |
| 기록용 | `AttendanceService.Claimed(player, slot, days)` | TelemetryService가 DailyVisit 퍼널 AttendanceClaim에 쓴다. |

- 창 여는 때(제안): 첫 임무를 받은 뒤(TutorialStep 99), `AttendReady`가 true면 한 번 연다. 첫 10분·KO·구매 창 근처에는 안 연다. 판에 시계 숫자("다음 칸까지 3시간") 없음.
- 저장: `data.Attendance = { Days, LastDay, Slot }` (기본값 `Config.Data.Defaults.Attendance`, 버전 3 그대로). 깨진 값은 서비스가 접속 때 고침(음수·소수·NaN·먼 미래 LastDay·범위 밖 Slot).
- Studio 시험: `game.ServerScriptService.DebugCommand:Invoke("<이름>", "AttendNext")` → 오늘 칸이 다시 열림.

## 바뀐 파일
- 새: `src/ServerScriptService/AttendanceService.luau`, `tools/test_attendance.py`, `tools/fixtures/attendance_offline.luau`, `tools/fixtures/dev3_world.luau`(게임성 개발 3 시험 공용 대역).
- `Config.luau` 맨 끝 블록(출석 표, 칭호 3개를 `TitleDefs`/`TitleOrder`에 덧붙임, `RateLimits.ClaimAttendance`, 저장 기본값).
- `Net.luau` 이름 목록 맨 끝 `ClaimAttendance`. `Main.server.luau` INIT/START 목록 + DebugCommand `AttendNext`.

## 기본값으로 정한 것 (검수가 바꾸면 Config 한 줄)
1. 1·5칸 물약 = HP 물약.
2. 7칸 주문서 = `Enh30`(코드에서는 A23-14대로 성공하면 +3; A23-77 글의 "+2"와 다름).
3. 50·100일 칭호 이름 = Super Regular · Mega Regular (임시).
