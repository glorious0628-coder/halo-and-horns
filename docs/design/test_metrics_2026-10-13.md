# 시험 숫자판 (A23-160 ④, 게임성 개발 2, 2026-10-13)

10/17~20 비공개 시험에서 세 가지를 숫자로 봐요: **첫 화면 통과율**, **10분 완주율**, **패스 구매 + 재접속 혜택 유지**.
근거: SPEC A23-160 결정 2 ④, A23-156, `gameplay_plan_2026-10-13.md` 1-A #13·1-B 합격선.

## 기록 길 두 개

| 길 | 어디에 쌓임 | 언제 보임 | 무엇 |
|---|---|---|---|
| 우리 기록 (새) | DataStore `HaloHorns_TestMetrics_v1`(환경 이름 붙음, `Config.StoreName`), 키 = 회차 `PT1` | 서버가 1분쯤마다·닫힐 때 씀 → 바로 | 아래 표 전부 |
| Creator Hub | Roblox Analytics(온보딩 퍼널 13단계, 다른 퍼널 6개, 사용자 이벤트) | 보통 하루쯤 늦게 | 같은 첫 단계들(참고·대조용), PerfFps/PerfMem |

- 우리 기록 = `TestMetricsService`(서버 관찰자: 게임은 안 바꾸고 저장에 `data.Telemetry.Test`만 더함). 이름·UserId를 저장하지 않아요. 숫자만 서버끼리 더해요(UpdateAsync).
- **Live 게임에서는 꺼져요**(`Config.EnvName() == "Live"`, 시험 스위치와 같음). 12/8 뒤 Live에 숫자가 쌓이지 않아요.
- 계정마다 표시는 저장에 더해요(`data.Telemetry.Test`, 더하기만). 그래서 한 사람이 두 번 세지지 않아요.
- Studio Play에서 쓴 것은 `_STUDIO` 복사본에 따로 쌓여요. 시험 숫자를 더럽히지 않아요.
- 켜고 끄기: `Config.TestMetrics.Enabled`. 다음 시험(12/3~6, A23-162)은 `Round = "PT2"`만 바꿔요.

## 숫자의 뜻

- **새 계정** = 이번 회차에 처음 본 계정 중 깨끗한 저장(인트로 안 봄, Lv1, 처치 0, 플레이 2분 미만). 개발자 계정 같은 옛 저장은 '계정'에만 들어가요.
- **첫 화면 통과율** = 진영 고른 새 계정 ÷ 새 계정. 인트로 끝낸 수도 같이 봐요.
  - 로딩 중에 나간 사람은 서버가 준비되기 전이라 안 세져요. 그 수는 Creator Hub의 새 사용자 수와 비교해요.
- **분** = 플레이한 시간(`PlaytimeSeconds`)을 다 채운 분으로 셈. 4분 59초 = 4분. "10분 안" = 9분대까지예요.
- **10분 완주** = 새 계정이 Lv5, 첫 드롭 무기(2단 이상 무기 보유 — 대장간 선물 1단은 아님), 첫 미션 Claim을 셋 다 10분 안에 해낸 것.
- **합격선**(1-B): Lv5 5분, Lv10 15분, 첫 드롭 무기 4분. 표는 그 안에 닿은 새 계정 비율과 중간값이에요.
- **패스** = 산 수(Bought), 산 뒤 **다른 접속**에서 다시 들어온 수(Back), 그때 들어온 지 20초 뒤 **Roblox가 그 접속에서 직접 '가짐'이라고 답한** 수(Kept, `MonetizationService.PassAnswer`). Roblox가 아직 답하지 않았으면 '확인 못 함'(Unknown)으로 세요. 저장된 옛 답은 Kept로 세지 않아요.
  - 유지율 = Kept ÷ (Back − 확인 못 함). 100%가 아니면 사고예요. 바로 최종 검수에 알려요. '확인 못 함'이 많으면 Roblox 응답이 느린 것이라 다시 접속해 봐요.
- 진영(새 계정의 첫 진영)과 기기(첫 Perf 기록의 기기)도 같이 세요.
- (10/15 최종 검수, A23-162) 기기 성능: 모든 계정의 Perf 기록(2분마다)을 기기별로 더해요 — 샘플 수, 평균 FPS, 가장 낮은 초 FPS, 메모리 MB, 끊김(가장 낮은 초 < 20) 비율, FPS 구간(<20 · 20~29 · 30~44 · 45+). 숫자판 '기기 성능' 표. Creator Hub를 기다리지 않고 그날 저녁에 봐요.

## 표 뽑기 — `tools/test_metrics_board.py`

```
py tools/test_metrics_board.py --studio --save build/test_metrics_PT1.json --out build/test_metrics_PT1.md
```
- `--studio`는 게임 Studio(Edit, 'Studio에서 API 접근' 켬)에서 읽기만 해요. 게임 Studio는 `HH_MAIN_STUDIO=1`이라 **메인 반영 1 또는 최종 검수만** 돌려요. Play를 시작하지 않아서 화면을 쓰지 않아요.
- 다른 길: `--print-luau`로 읽는 코드를 받아 Studio 명령 줄에 붙이고, 나온 `TESTMETRICS_JSON` 줄을 파일로 저장해 `--json 파일`로 넣어요.
- Creator Hub 대조: Analytics → Funnels → Onboarding 숫자를 CSV로(내보내기, 또는 `단계,명` 두 칸 손으로) 저장해 `--hub 파일.csv`.

## #13 기록 길이 실제로 쌓이는지 확인하는 방법

1. **시험 전(10/16, 메인 반영 1):** 동결판 sync 뒤 첫 10분 Play를 한 번 해요. 그다음 Play를 멈추고 이렇게 읽어요.
   ```
   py tools/test_metrics_board.py --studio --studio-copy
   ```
   그 Play 계정이 깨끗한 저장이 아니면 '계정 1명, 새 계정 0명'으로 나와요. 길이 살아 있다는 뜻으로는 충분해요. 읽기가 실패하면 Studio의 'API 접근'이 꺼져 있는 거예요.
2. **시험 첫날(10/17) 저녁:** `--studio`(진짜 저장)로 계정 수가 시험자 수와 비슷한지 봐요. 0명이면 서버가 쓰지 못하는 거예요. 그때는 HealthService 시간 보고서(`DebugCommand("Health","live")`)의 Joins와 비교하고, ServerError를 봐요.
3. **10/18 아침(Creator Hub):** Analytics → Funnels에서 Onboarding의 IntroDone·Faction 수가 0이 아닌지 봐요. Custom events에서 `PerfFps`·`PerfMem`(폰 기기 칸 포함)과 `MinutesToLv5`가 있는지도 봐요. 하루쯤 늦을 수 있어요. Studio에서 낸 이벤트는 Creator Hub에 안 쌓여요.
4. **패스:** 사용자가 패스마다 한 번씩 사고 나갔다 다시 들어온 뒤 board의 패스 표에서 그 패스의 '혜택 남음'이 1이 됐는지 봐요(들어오고 20초 뒤에 셈).

## 바뀐 파일

- `src/ServerScriptService/TestMetricsService.luau`(새) + `Main.server.luau` 두 목록(PlayerService 앞).
- `Config.TestMetrics`(Config 끝, `Config.TestServer` 앞).
- `tools/test_metrics_board.py`(새), 시험 `tools/test_test_metrics.py` + `tools/fixtures/test_metrics_offline.luau`(66 확인, 변이 43/43).
