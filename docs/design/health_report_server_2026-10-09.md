# 건강 보고 — 서버 계약 (게임성 개발 3, 2026-10-09)

근거: `docs/design/system_review_round1_2026-10-09.md` 더할 것 9번(건강 보고), 검수 순서 지시 10/09 ③ — '털기 실제 금액·거위 보상 실측'도 이걸로.
사용자 규칙: "아무도 안 붙어 있어도 돌아가게" → **서버가 알아서 시간별로 쌓고**, 읽을 때만 Studio 명령창을 쓴다(키·계정 페이지 필요 없음).
서버는 끝났어요(`HealthService`, 게임 상태는 안 바꾸는 관찰자). 화면(클라)에는 아무것도 안 보여요.

## 무엇을 쌓나 (UTC 한 시간마다 문서 하나)
| 칸 | 뜻 | 어디서 |
|---|---|---|
| `Joins` | 들어온 사람 수 | PlayerService.PlayerReady |
| `Min[띠]` | 띠별 플레이어-분(1분마다 한 번, 준비된 사람 모두) | 1분 루프 |
| `Peak` | 한 서버에 동시에 준비된 사람 최대 | 같음(서버끼리는 큰 쪽) |
| `Servers` | 이 시간에 쓴 서버 수 | 서버마다 한 번 |
| `GoldIn[출처]` / `GoldOut[쓴 곳]` | 골드 들어옴 / 나감 | ProgressionService.GoldEarned / GoldSpent (출처·쓴 곳은 게임이 정한 이름) |
| `GoldBand[띠] = {In, Out}` | 띠별 골드 들어옴 / 나감 | 같음 + 그 사람의 레벨 띠 |
| `XP[띠]` | 띠별 XP | **새 신호** ProgressionService.XPEarned(player, amount) — AddXP가 실제로 더한 양(2배 패스·한 레벨 한도 뒤) |
| `Goose` | `Rounds`(판 수), `Versus`·`HaloWins`·`HornsWins`·`Ties`, `Coop`·`CoopWins`, `Empty`(받을 사람 없음), `Paid`·`Won`·`Lost`·`Rare`(보상 받은 사람 수·이김·못 이김(진·비김)·레어), `Gold`·`XP`(준 합계) | GooseService.GooseFinished + **새 신호** GooseService.GooseRewarded(player, {Won, Rare, Gold, XP, Level, Mode}) |
| `GooseBand[띠] = {N, Gold, XP}` | 띠별 거위 보상 받은 사람 수와 합계(1인 평균을 알 수 있음) | 같음 |
| `Plunder` | `PaidN/G`(도둑이 지킴) · `AvengedN/G`(복수 성공) · `ReturnedN/G`(돌려줌) = 자루 수와 골드 합계 | GrudgeService.SackResolved |
| `Pass[id] = {View, Prompt, Bought}` | 패스 보기 → 구매 창 → 구매 | TelemetryService.ClientMetric(PassView / PurchasePrompt) + MonetizationService.PassBought |
- 레벨 띠 = `Config.Health.Bands`(1-9 / 10-24 / 25-49 / 50+, 분석 이벤트의 레벨 띠와 같은 자름).
- 이름·UserId·자유 글은 어디에도 안 들어간다. 키는 문자·숫자·`_ - +`만, 24자까지. 합계 표 하나는 키 40개까지이고 넘으면 `Other`에 합쳐진다.
- **털기 실제 금액** = `Plunder`의 자루별 평균(골드 합계 ÷ 자루 수). **거위 보상 실측** = `Goose`의 보상 받은 1인 평균(골드·XP)과 띠별 평균.
- 골드는 옮기는 돈(털기 자루 등)이 '쓴 곳 + 출처' 양쪽에 같이 잡힐 수 있어요(순수입이 아니라 흐름). 순수입은 `GoldIn` 합계 − `GoldOut` 합계로 읽되 털기·세금 같은 이전은 이름(`GoldOut`의 `Plunder` 등)으로 가려 읽어요.

## 저장 (DataStore)
- 문서 하나 = UTC 한 시간, 키 `H<YYYYMMDDHH>` (예 `H2026092103`), 저장소 `Config.StoreName("HaloHorns_Health_v1")` — Dev는 그대로, Beta/Live는 `_Beta`/`_Live`, Studio는 `_STUDIO` 복사본(진짜 문서를 안 건드림).
- 서버마다 `Config.Health.FlushSeconds`(600초)의 **0.5~1.5배 아무 때나**(서버들이 한꺼번에 쓰지 않게)와 서버가 닫힐 때 아직 안 쓴 합계를 `UpdateAsync`로 **합쳐 쓴다**(숫자는 더하고 `Peak`만 큰 쪽, `Servers`는 서버당 시간당 한 번). 서버 수에 상관없이 같은 시간 문서에 계속 합쳐진다.
- 쓰기가 실패하면 합계를 버리지 않고 다음 번에 다시(두 번 더해지지 않음). 쓰는 동안 들어온 사건은 다음 번 몫.
- 읽을 때 문서를 다시 청소한다(깨진 키·큰 수·글자 값 제거).

## 읽기 (Studio 명령창, Play 중 — 준비된 플레이어 한 명이 있어야 해요)
```
game.ServerScriptService.DebugCommand:Invoke("Player1", "Health")           -- 이 서버가 아직 안 쓴 합계
game.ServerScriptService.DebugCommand:Invoke("Player1", "Health", "stored") -- 이 환경의 저장 문서 최근 24시간(Studio: 자기 _STUDIO 복사본)
game.ServerScriptService.DebugCommand:Invoke("Player1", "Health", "live")   -- 진짜 게임의 문서(읽기만), 최근 24시간
game.ServerScriptService.DebugCommand:Invoke("Player1", "Health", "live:48") -- 시간 수 지정(1~72)
```
출력(예): 시간 수·서버-시간·접속·동시 최대 / 띠별 플레이어-시간 / 띠별 XP·골드 들어옴 per 플레이어-시간 / 골드 들어옴(큰 출처 6개)·나감·순 / 거위 한 줄(판·승·협동·보상 평균)과 띠별 평균 / 털기 평균 / 패스 / **Alerts**.

## 경보 (시작 숫자, `Config.Health.Alerts` — 첫 시험 뒤 조정)
- `QUIET`: 가장 최근 문서가 끝난 지 3시간 넘게 아무도 안 썼다(창 안에 데이터가 하나라도 있을 때).
- `SURGE`: 가장 최근 **끝난** 시간의 띠별 XP / 골드 들어옴 per 플레이어-분이, 그 앞 시간들 평균의 **2배 이상**(그 띠에 시간당 플레이어-분 60 이상인 시간만 비교, 앞 시간이 3개 이상 있어야 판정).
- `GOOSE`: 승부가 난 거위 판이 10번 이상인데 한쪽이 75% 이상 이겼다(비김 제외).
- 경보가 없으면 `Alerts: none`.

## 시험
`py tools/test_health.py` — 검사 158, 정적 36, 변이 129/129 (10/10 고침 뒤). 기록 하나하나(골드·XP·띠 경계·거위·털기·패스·키 청소·상한), 합치기(다른 서버가 먼저 씀·Peak·실패 후 재시도·쓰는 중 사건·두 번 더해지지 않음), 저장소 이름(Studio/Beta/Live/Dev), 루프 대기(0.5~1.5배)·닫힐 때 저장·스위치, 읽기(시간 수 상한·live는 진짜 이름·깨진 문서 청소·읽다 실패해도 앞 줄 유지), 경보 경계(정확히 2배·3개 앞 시간·60분·75%·10판), 글. 진짜 `ProgressionService.AddXP`가 `XPEarned`를 쏘는지, 진짜 `GooseService`가 `GooseRewarded`를 쏘는지(`py tools/test_a23_14.py`, 변이 48/48).
한계: 진짜 DataStore 한도·분석 대시보드는 안 건드림(시간당 서버당 쓰기 1~2번이라 한도의 한참 아래). 경보 숫자는 시작 값.

## 10/10 검수 확인 뒤 작은 고침 5개
- 치장(Look): 클라는 'Look', 구매는 치장의 진짜 id로 보내서 퍼널이 두 줄로 갈렸다 → `OnPass`가 Config.Looks의 id를 모두 'Look' 한 줄로 모은다.
- `OnClientMetric`: 받은 호출마다 세던 것 → (사람, 단계, 패스)마다 한 시간에 한 번만(사람 객체 키의 약한 표). 구매(Bought)는 서버가 본 사실이라 제한 없음.
- 거위 `GooseRewarded.Mode`: 실패한 협동도 'Versus'였다 → `finish()`가 판정한 `judged`("Coop"/"Versus")를 `rewardPlayer`에 넘긴다.
- Studio `DebugCommand`: 읽기 전용 키(Errors·Health·StoryDump·DataDump·LootRoll)는 저장을 DebugTainted로 만들지 않는다(나머지 키는 그대로 표시).
- `Config.Analytics.UiIds`에 'Pet'·'Diary' 추가(분석 이름 수는 test_beta_metrics가 100 아래인지 확인).
