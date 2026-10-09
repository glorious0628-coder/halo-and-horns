# 폰 프레임·메모리 기록 — 서버 계약 (게임성 개발 3, 2026-10-09)

근거: `docs/design/system_review_round1_2026-10-09.md` 더하기 7번(폰 성능 안전망), 검수 순서 지시 10/09 ② — 10/17~20 비공개 시험 목록의 '폰 프레임·메모리'.
서버는 끝났고(`TelemetryService` 위에 덧붙임, 게임 상태는 안 바꿈), 재는 쪽(클라)은 **게임성 개발 1** 몫이에요.

## 서버가 받는 것
c→s `ClientMetric("Perf", 표)` — 인자 하나, 아래 다섯 칸이 **전부** 든 표 하나(칸이 모자라거나 더 있으면 버림, 표가 아니어도 버림).

| 칸 | 뜻 | 허용 |
|---|---|---|
| `D` | 기기 종류 | `"Phone"` / `"Tablet"` / `"Desktop"` / `"Console"` (`Config.Analytics.PerfDevices`) |
| `F` | 지난 창의 평균 FPS | 정수 0~240 |
| `W` | 지난 창에서 가장 낮았던 1초의 FPS | 정수 0~F (평균보다 높을 수 없음) |
| `M` | 메모리 MB | 정수 0~16384 |
| `Q` | 그래픽 품질 단계 | 정수 0~10 (0 = 자동, `Enum.SavedQualitySetting`) |

- 한 사람이 **60초에 한 번**만 받는다(`Config.Analytics.Perf.MinGap`). 더 빠른 호출은 버린다. 틀린 표는 이 60초를 쓰지 않는다. 같은 id의 0.5초 한도와 '준비된 사람만'은 다른 ClientMetric과 같다.
- 분당 10개짜리 공용 기록 한도(`ClientMetricPerMinute`)를 **쓰지도, 기다리지도 않는다.** 폰 한 대가 샘플 하나에 이벤트 3개를 남겨서, 2분마다 보내면 분당 1.5개 — Roblox 한도(1인당 분당 20개) 아래다.
- 받은 샘플은 `TelemetryService.ClientMetric` 신호로도 넘긴다(깨끗이 다시 만든 표).

## 남는 기록 (사용자 정의 이벤트 이름 3개 추가 → 합계 69 / 한도 100)
| 이벤트 | 값 | 칸1 | 칸2 | 칸3 |
|---|---|---|---|---|
| `PerfFps` | F (평균 FPS) | 기기 | 구역 id (`Config.Zones`, 목록 밖·없음이면 `Other`) | `Q<단계>` 예: `Q5` |
| `PerfFpsLow` | W — **W < `Config.Analytics.Perf.Low`(20)일 때만** | 같음 | 같음 | 같음 |
| `PerfMem` | M (MB) | 같음 | 같음 | 같음 |
- 이름·UserId·자유 글은 어느 칸에도 안 들어간다(기기·구역·Q 숫자 목록 값만).
- Roblox 기록은 **게시된 서버에서만** 쌓인다. Studio Play에서는 출력창에 `[Metrics] PerfFps = 42 (Phone, SlimeMeadow, Q5)` 줄이 찍힌다.

## 개발 1에게 (클라 계약)
1. **보내는 때:** 준비된 뒤 `Config.Analytics.Perf.Every`(120)초마다 한 번. 그 창에서 **화면이 켜져 있던 시간이 60초 미만이면 보내지 않는다**(폰이 뒤로 갔다 온 경우·창 로딩 중).
2. **어떻게:** `ComeBack.Metric("Perf", { D = …, F = …, W = …, M = …, Q = … })`. **`ComeBack.ArgOk`(서버 `argOk`의 클라 복사본)에 `"Perf"` 규칙을 더해야 한다**(서버 `perfOk`와 같은 검사: 다섯 칸 전부, 정수, 같은 범위, `W ≤ F`, 기기 목록) — 안 더하면 호출이 클라에서 걸러진다. 시험 `py tools/test_come_back.py`에 한 검사 더.
3. **무엇을 재나(제안, 개발 1이 확정):**
   - `D`: 터치만 있으면 화면 짧은 변이 작은 쪽 `Phone`, 큰 쪽 `Tablet`(경계값은 개발 1이 정함, 예: 600 px); 키보드가 있으면 `Desktop`; 게임패드만이면 `Console`.
   - `F`: 창 안 프레임 평균 FPS(반올림). `W`: 1초 평균 FPS들 중 가장 낮은 값(`min(W, F)`로 보내 W ≤ F 보장).
   - `M`: `Stats:GetTotalMemoryUsageMb()` 내림. `Q`: `UserSettings().GameSettings.SavedQualityLevel.Value`.
4. 이 기록은 게임 화면·조작에 아무것도 바꾸지 않는다(보이는 것 없음). 지연 없이 가볍게(프레임 루프에 더하기만).

## 읽는 법 (Creator Hub → 분석 → 사용자 정의 이벤트)
- `PerfFps`를 칸1(기기)로 나눠 평균값(= 값 합 ÷ 횟수)을 본다: **Phone·Tablet 평균이 너무 낮은 구역**(칸2)과 **품질 단계**(칸3)를 찾는다.
- `PerfFpsLow` 횟수 ÷ `PerfFps` 횟수 = 끊김이 있었던 샘플 비율(기기·구역별).
- `PerfMem` 평균·큰 값 = 폰이 튕기기 쉬운 구역. 10/17~20 비공개 시험 때 기준 숫자(예: 폰 평균 30 이상, 끊김 샘플 20% 아래)를 정한다 — 숫자는 시험 결과를 보고 검수가 정한다.
- 켜고 끄는 값은 `Config.Analytics.Perf`(Every / MinGap / Low / MaxFps / MaxMem / MaxQuality)와 `Config.Analytics.PerfDevices`.

## 시험
`py tools/test_beta_metrics.py` — 178 검사, 변이 90/90(이 일로 변이 26개 더). 새 묶음 "phone performance": 좋은 샘플의 세 이벤트와 칸, W 20은 낮지 않고 19는 낮음, 모르는 구역 → Other, 범위 끝값 허용, 나쁜 호출 22가지(칸 모자람·넘침·모르는 기기·음수·소수·글자·NaN·무한대·W > F·메모리·품질 범위·중첩·배열·빈 표·글자·숫자·인자 없음·인자 둘) 모두 무시, 60초에 한 번, 틀린 표는 60초를 안 씀, 공용 한도와 서로 영향 없음, 준비 안 된 사람 무시, AnalyticsService 없어도 안 깨짐, 칸에 목록 밖 값 없음. 정적: 이벤트 이름 69 ≤ 100.
관련 묶음 모두 통과: test_metrics(51/51), test_return(83/83), test_attendance(36/36), test_ops_safety(61/61), test_come_back, test_invite.
