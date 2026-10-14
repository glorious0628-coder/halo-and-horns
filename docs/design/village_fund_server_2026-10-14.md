# 마을 기금 — 서버 계약 (게임성 개발 2, 2026-10-14; A23-178 B, gameplay_plan 2-A ⑥)

사용자 10/14 09:40: "마을 기금은 좋아." 주문서 골드 구매(A)는 안 함(소모품은 연금술사 몫). 이 문서는 서버가 지킬 약속이에요.
코드는 최종 검수 OK 뒤 origin/main 위 새 가지 `dev2-village-fund`(리베이스 없음). 새 그림 없음. 화면 몫은 맨 끝 4줄(개발 1).

> **10/14 최종 검수 OK + 코드:** 가지 `dev2-village-fund`(origin/main + dev2-launch-dates 합침: 같은 스위치 목록). 결정: 목표 30,000/100,000 그대로(10/20 숫자 보고 조정), 뿔 = `Spots.Horns` 없음(오류·안내 없음), 날짜 = `Config.DayIndex`(출석과 같음), 단계 글 Lanterns·Fireworks = `Text` 표. 숫자는 '1,000'(`Util.FormatInt`). 시험 `tools/test_village_fund.py`.

## 1. 무엇
- 빛(Halo) 아이는 빛 마을 분수에, 뿔(Horns) 아이는 뿔 마을 분수에 골드를 **1,000씩** 넣어요.
- 넣을 때마다 자기 점수 +1: 빛 = Honor, 뿔 = Mischief(속 이름 `Infamy`). **하루 3번까지**(KST 날짜, `Config.DayIndex`).
- 진영 **주간 합계**(모든 서버 합)가 단계에 닿으면 그 마을에 등불 → 불꽃(꾸미기만, 힘 0). 월요일 00:00 KST에 새 주(`Config.WeekIndex`).
- 장인(Neutral)·진영 없음: 분수 기금 없음(안내 없이 그냥 안 보임). 남의 마을 분수: 안 됨.
- 글만 다름: 빛 = '나누기'(Share), 뿔 = '자랑하기'(Show off). 숫자·규칙은 같음.

## 2. 설정 `Config.VillageFund` (새 표, 숫자는 시작값)
```
Enabled = true, Step = 1000, PerDay = 3, Points = 1,
Spots = { Halo = { Pos = Vector3.new(22, 10, -590), Radius = 16, Zone = "HaloTown" } },  -- Horns = nil (아래)
Goals = { Lanterns = 30000, Fireworks = 100000 },   -- 진영 주간 합계(골드)
Store = "HaloHorns_VillageFund_v1", FlushSeconds = 60, ReadSeconds = 60, Rate = 1.0,
Text = { Halo = { Prompt = "Share 1,000 gold", Done = "You shared 1,000 gold! Honor +1", ... },
         Horns = { Prompt = "Show off 1,000 gold", Done = "You showed off 1,000 gold! Mischief +1", ... },
         Poor = "You need 1,000 gold.", Full = "That's 3 for today. Come back tomorrow!" }
```
- 뿔 마을 분수 자리는 뿔 마을 다시 짓기(A23-155, 빛 다음) 때 정함. 그 전엔 `Horns = nil` → 뿔은 기금 없음(오류 아님).
- 글은 전부 이 표(가운데 글 표 규칙). 쉬운 영어(glossary). 설교 없음(A23-55).
- 실시간 스위치 `Config.Switches.Defs.VillageFund = { Type = "Bool", Default = true }`: 끄면 새로 넣기만 멈춤(합계·꾸미기는 그대로).

## 3. 상호작용과 원격 검증
- 서버가 `Workspace.VillageFund.FundSpot_<진영>`(보이지 않는 고정 파트, `Pos` = 풀 중심; 분수 모델과 떨어져 있어 모델이 바뀌어도 그대로) 안에 `ProximityPrompt "FundPrompt"`를 만듦(CraftService 방식: `ActionText` "" + 속성 `ActionKey` / `ObjectKey` / `Faction`, MaxActivationDistance = Radius, 누르기만).
  프롬프트는 **그 진영 아이에게만** 보이게 클라가 `Enabled`를 끔(서버는 어차피 다시 검사).
- `PromptTriggered`(서버) → `Net.FundOpen:FireClient(player, state)` — state = `{ Faction, Today, PerDay, Step, Gold(가진 합), Week, Goals, Level(0/1/2) }`.
- 클라가 확인 카드에서 [Give] → 원격 `Net.FundGive:FireServer()` (**인자 없음**: 금액·진영·횟수는 서버가 정함; 인자가 오면 무시).
- 서버 검사(하나라도 아니면 아무것도 바꾸지 않고 짧은 알림 한 줄 또는 조용히 끝):
  1. `Enabled` + 스위치 켬, 플레이어 데이터 로드됨·직업/진영 고름(Ready)·살아 있음.
  2. 진영 = Halo 또는 Horns이고 `Spots[진영]`이 있음.
  3. 캐릭터 뿌리가 `Spots[진영].Pos`에서 Radius 안(높이 무시, 수평 거리) — 원격만 쏘는 것 차단.
  4. 호출 간격 `Rate`초(플레이어별, `os.clock`).
  5. 오늘 횟수 < PerDay (`data.FundDay ~= 오늘`이면 0으로 봄).
  6. `ProgressionService.SpendGold(player, Step, "Fund")` = true (주머니 먼저, 그다음 은행; 모자라면 `Poor`).
- 성공 순서(한 줄씩, 중간 yield 없음): SpendGold → `data.FundDay = 오늘`, `data.FundToday += 1`, `data.FundGiven += Step`
  → `PlayerService.GrantFame(player, stat, Points, { Fund = true })` (ctx에 PvP·RankPoints 없음 = 점수만, 주간 판 아님)
  → 서버 합계 `pending[진영] += Step` → `Net.Notify(player, Done, "reward", nil, "RankUp")` → 새 state로 `FundOpen` 다시(카드 숫자 갱신).
- 원격 처리 전체를 `pcall`; 실패는 `Util.Warn`(TAG "VillageFundService"), 골드가 빠졌는데 뒤가 실패하면 점수만 빠질 수 있음
  → 이 순서상 SpendGold 뒤 단계는 throw 하지 않는 것만 둠(GrantFame도 pcall 안의 랭킹 부분만 실패 가능).

## 4. 저장 (더하기만)
- 플레이어: `Config.Data.Defaults`에 새 칸 3개 `FundDay = 0`, `FundToday = 0`, `FundGiven = 0`. 옛 칸 이름·뜻 바꾸지 않음. 다른 시험 세계에서
  경고 없게 '부드럽게' 읽기(`num(data.FundToday, 0)`).
- 진영 주간 합계: DataStore `Store`, 키 `"W" .. WeekIndex`, 값 `{ Halo = n, Horns = n }`. 서버마다 `pending`을 `FlushSeconds`(×0.5~1.5)마다와
  BindToClose 때 `UpdateAsync`로 **더하기**(HealthService·TestMetricsService 방식; 실패하면 pending 유지 후 다음에). 주가 바뀐 뒤 남은
  pending은 그 주 키에 씀(합계가 다음 주로 넘어가지 않게 pending도 주별 표).
- 읽기: `ReadSeconds`마다 `GetAsync` → 보이는 합계 = 저장값 + 아직 안 쓴 이 서버 pending. Studio·메모리 모드 = 이 서버 것만.

## 5. 신호 (꾸미기, 힘 0)
- 서버가 `Net.GameState()`(ReplicatedStorage 안 GameState 폴더) 속성으로 알림: `FundWeek`, `FundHalo`, `FundHorns`(보이는 주간 합계), `FundLevelHalo`, `FundLevelHorns`
  (0 = 없음, 1 = 합계 ≥ Goals.Lanterns → 등불, 2 = ≥ Goals.Fireworks → 등불 + 불꽃). 새 주 = 0부터.
- 등불·불꽃은 클라가 그림(기존 Roblox 효과·승인 부품만). **불꽃은 둥근 반짝임·별·색종이만, 가운데서 퍼지는 빛줄기 금지**(10/07 규칙).
  밤(DayCycle)에만 불꽃, 등불은 늘 켜짐. 폰은 입자 적게(FountainFx 방식).
- 단계가 처음 오를 때(이 서버 기준) 그 마을 안 아이들에게 알림 한 줄(`Text.Lanterns`/`Text.Fireworks`), 한 주에 단계마다 한 번.

## 6. 숫자판·공정
- `GoldSpent` 이유 `"Fund"` → HealthService·TestMetrics 골드 나감 표에 그대로 잡힘.
- 하루 3,000골드 상한이라 2배 골드 패스가 있어도 더 얻지 못함(빨리 모을 뿐) → 계획 §4 결정 4: 이 기금이 들어간 뒤 2배 골드 판매.
- GW8 '마을 기금' 고르기는 이야기만(그대로). 나중에 이어 줄지는 최종 검수가 정함.

## 7. 시험 (`tools/test_village_fund.py`, 오프라인 Luau 고정판 + 변이)
- 1,000 넣기 → 골드 −1,000(주머니 먼저·은행), 점수 +1, 오늘 1, 합계 pending +1,000. 4번째 = Full, 바뀐 것 없음.
- 999골드 = Poor, 바뀐 것 없음. 반경 밖·남의 마을·Neutral·안 고름·죽음·스위치 끔 = 바뀐 것 없음. 1초 안 두 번 = 한 번.
- 인자 넣은 원격(금액 10^9, 진영 "Horns")도 서버 값만. 날짜 넘어가면 오늘 0. 주 넘어가면 pending은 옛 주 키로.
- UpdateAsync 실패 → pending 유지, 다음 성공 때 합침. 랭킹 판에 안 올라감(GrantFame ctx Fund).
- 변이: 횟수 상한·거리 검사·SpendGold 결과 무시·저장 더하기 대신 덮어쓰기·주 키 — 다 잡혀야 함.

## 8. 화면 몫 (개발 1, 4줄)
1. 자기 마을 분수에 G(폰은 프롬프트 버튼) → 작은 확인 카드: 글(나누기/자랑하기) · "Today 1/3" · 가진 골드 · [Give 1,000] / [Close]. 기존 승인 부품 + UIKit.
2. 골드가 모자라거나 오늘 3번 다 했으면 [Give]를 흐리게 하고 이유 한 줄(서버 글 키 그대로).
3. 카드 아래 진영 주간 합계 막대 하나(등불·불꽃 두 눈금), 숫자는 서버 속성 `FundHalo/FundHorns`.
4. 마을 등불(1단계)·밤 불꽃(2단계): 둥근 반짝임만, 폰 입자 적게; 남의 진영 아이도 그 마을에 가면 보임.
