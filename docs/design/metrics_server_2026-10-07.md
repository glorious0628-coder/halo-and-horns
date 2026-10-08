# BB38 베타 지표 서버 (게임성 개발 2, 2026-10-07)

설계: `docs/design/beta_basics_2026-10-05.md` BB38(P6 퍼널), 검수 2026-10-07(경제·친구 지표 — quality_ideas #60), `docs/design/emergent_play_watch_2026-10-06.md` §2(스스로 만든 목표 신호). Roblox AnalyticsService만 쓰고, **이름·UserId·자유 글은 이벤트 이름에도 칸(field)에도 넣지 않는다** — 모든 이름과 칸 값은 고정 목록(`Config.Analytics`, 지역 id, 몬스터 종류, 골드 출처)에서만 온다. Studio에서는 모든 호출을 `[Metrics] …`로 출력한다(`Config.Analytics.Debug`, 기본 = Studio만).

## 1. 퍼널 (계정마다 한 번, 순서대로 번호)
`Config.Analytics.Steps` = 1 IntroDone · 2 Faction · 3 Class · 4 FirstMissionAccept · 5 FirstMissionDone · 6 FirstWeapon · 7 AutoUnlocked · 8 **Level10**. 저장은 `data.Telemetry.Funnel = { [이름] = true }`(Version 그대로). 옛 저장은 접속 때 이미 지난 단계를 한 번에 따라잡는다. (옛 `Steps`/`Onb` 기록은 시험 데이터라 읽지 않음.)

## 2. 바로 보내는 이벤트
| 이벤트 | 값 / 칸 | 언제 |
|---|---|---|
| `WindowOpen_<id>` | 1 | 클라 `UiMetric(id)` — id는 `Config.Analytics.UiIds`, 인자 하나, 준비됨, 2초에 1번, **세션당 창별 1번** |
| `KeyRebind` | 바뀐 동작 수 | SettingsService가 키 설정을 받아들였고 묶음이 달라졌을 때(`SettingsService.KeysChanged`) |
| `AutoOn` / `AutoOff` | 1 | 자동 전투 켬/끔(10초에 1번) |
| `FirstDeath_<By>` | 1, 칸1 = 지역 | 계정 첫 쓰러짐, By = BB14 KO 화면 원인(Player·Kaiju·Monster·Fall·Other, `CombatService.KnockedOut`) |
| `Plunder_Kept` / `_Avenged` / `_Returned` | 골드 | 원한 돈자루 결과 |
| `SameKindStreak` | 30, 칸1 = 종류 | 같은 종류를 30마리 연달아(세션당 종류별 1번) — 의도하지 않은 반복 |
| `ReturnAct` | 1~3, 칸1 = Zone/Window, 칸2 = id | **다시 온** 플레이어(세션 2번째부터)의 처음 3가지 행동(지역 들어가기·창 열기) |
| (그대로) `RookieFirstKillSeconds`, `CrownTrialMiss`, 5분마다 `HighLevelInMeadow`·`ServerPopulation` | | |

## 3. 나갈 때 보내는 세션 합계
| 이벤트 | 값 / 칸 |
|---|---|
| `SessionMinutes` | 분, 칸1 = 0-5·5-15·15-30·30-60·60+ |
| `AutoAwayMinutes` | 자동 ON인데 내 입력 없이 5분(`AwayAfter` 300초) 넘은 분 수 — 0이면 안 보냄 |
| `EnhanceFailLeave` | 강화 실패 뒤 300초 안에 나가면 그 초 |
| `GoldIn` | 출처별 합계, 칸1 = Monster·Loot·Sale·Quest·Refund·Plunder·Bounty·War·Event·Kaiju·KaijuBonus·KaijuBank·KaijuTransfer·SignOn·Other (`ProgressionService.GoldEarned`, A23-75: 2x Gold 패스가 곱한 뒤의 양. 가입 보너스는 Other → SignOn, 괴수는 새로 생긴 몫 Kaiju·생존 보너스 KaijuBonus와 옮겨진 골드 KaijuBank·KaijuTransfer로 나뉨) |
| `GoldOut` | 쓴 곳별 합계, 칸1 = Weapon·Potion·Plunder·Penalty·Kaiju·Taken·Other (새 `ProgressionService.GoldSpent`) |
| `FriendMinutes` | 친구가 같은 서버에 있던 분, 칸1 = WithFriend / Solo |
| `KillsTogether` / `KillsWithFriend` | 2명 이상이 함께 잡은 처치 / 그중 친구와 함께(새 `MonsterKilled` info.Party·Others) |
| `ZoneMinutes` | 지역별 분, 칸1 = 지역 id |
| `RankingViews` | 순위표별 본 횟수, 칸1 = 순위표 id (새 `RankingService.Viewed`) |

- 친구: 들어올 때 이미 있는 사람들과 `IsFriendsWith`(최대 12번, 쌍마다 한 번, 서버 동안 기억).

## 4. 서버 쪽에 더한 것 (한두 줄씩)
- `ProgressionService.GoldSpent(player, amount, sink)` — `SpendGold(p, n, reason)`·`TakeCarriedGold(p, n, reason)`에 이유(선택). 상점 "Weapon"·"Potion", PvP "Plunder"·"Penalty", 괴수 "Kaiju". 쓸 수 없는 단계(no yield) 안에서 쏘니 듣는 쪽은 기다리면 안 됨.
- `CombatService.KnockedOut(victim, by)` — KO 화면을 보낸 직후.
- `SettingsService.KeysChanged(player, changed)`, `RankingService.Viewed(player, board, scope)`.
- `MonsterService` killRecord: `info.Party`(보상 받는 사람 수)·`info.Others`(다른 사람들, 서버 안에서만).
- Net `UiMetric`, `RateLimits.UiMetric = 2`, `Config.Analytics`.

## 5. 게임성 개발 1에게 (클라, 약 0.1일)
- 창이 열릴 때 `Net.Get("UiMetric"):FireServer(id)` — id는 Panels의 창 id 그대로(`Config.Analytics.UiIds`: Menu·Items·Bag·Skills·Character·Ranking·Journal·Board·Settings·Help·News·Travel·WorldMap·WeaponShop·PotionShop·Shop·Rebirth·Altar·Class·PlayerList·Feedback). Tab 목록은 "PlayerList". 목록에 없는 id는 서버가 무시(새 창은 이 목록에 한 줄 더하기). 같은 창을 여러 번 보내도 세션에 1번만 센다.

## 6. 검사
- `py tools/test_metrics.py` — 81검사 + 정적 8, 변이 38/38: 퍼널 순서·한 번·옛 저장 따라잡기·다른 서버에서 다시 안 보냄, 이벤트들, UiMetric 검증(모르는 id·인자·준비 안 됨·2초·세션당 1번), 다시 온 플레이어 3행동(모르는 지역 제외), 세션 합계(골드 입출·친구 분·같이/친구와 처치·자리 비움 분·지역 분·순위표·세션 분), 강화 실패 뒤 나감, 개인정보(고정 이름만, 이름·UserId 없음), Studio 출력·라이브 출력 없음·AnalyticsService 없음, 진짜 SpendGold/TakeCarriedGold의 GoldSpent, 진짜 SettingsService의 KeysChanged.
