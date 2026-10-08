# A23-74 '무기 먼저' 서버 계약 (게임성 개발 2, 2026-10-07 밤)

근거: `docs/SPEC_ADDENDUM.md` A23-74 (사용자 직접 플레이 2026-10-07: "맨 손이니까 무기를 제일 먼저 줘야지 / 무기도 없는데 어케 싸우라고"),
검수 지시 2026-10-07 (진영·직업 → 대장간 → 직업 기본 무기 T1 → 슬라임 첫 임무, A23-34 GiveWeapon 재사용, 옛 저장도 맨손으로 남지 않게,
150골드 다시 설계, 가지 `dev2-weapon` = origin/main 위, Data v4·스탯 없음).
가지: `dev2-weapon`. 시험: `tools/test_weapon_first.py`(새로 만듦, 변이 포함) + onboarding / unarmed_start / metrics / english 맞춤.

## 1. 새 순서

| TutorialStep | 뜻 | 다음으로 넘어가는 때 |
|---|---|---|
| 0 (Kill = Welcome) | 안내자 대화 기다림 | [Accept] |
| **3 (Forge, 새로 넣음)** | 대장간에서 첫 무기 받기 | 모루 프롬프트 (`QuestService.ForgeGift`) |
| 1 (Guide) | 초원으로 가기 | 초원 도착 |
| 2 (Quest) | 슬라임 5마리 | [Claim] |
| 99 (Done) | 끝 | — |

- [Accept]를 누른 사람이 **맨손이고 첫 무기(T1)도 없으면** 단계 3으로 가요.
  - 무기를 이미 든 사람은 예전처럼 단계 1로 가요. 첫 무기를 가진 옛 저장(A23-34 전)이나 T2를 산 사람 같은 경우예요.
  - 검수 2026-10-07 minor 6: 수락과 접속 때 주는 무기(옛 저장)가 같은 규칙 `needsFirstWeapon`을 써요. T2만 든 사람은 첫 무기를 나중에 M1_1에서 가방으로 받아요.
- **모루가 없으면(무기 상점이 닫힘) 단계 3에 갇히지 않아요** (검수 2026-10-07 minor 2).
  - 수락할 때 모루가 없으면 바로 첫 무기를 주고 단계 1(초원 이동)로 가요.
  - 단계 3인데 모루가 사라졌으면, 다음 확인(접속·1초 점검) 때 바로 첫 무기를 주고 단계 1로 가요.
- 단계 3에서는 초원에서 슬라임을 잡아도 첫 임무 수가 오르지 않아요(단계 2에서만 세요).
- 단계 3은 저장했다가 다시 불러와도 그대로예요(`DataService.fillDefaults`가 받아들임). 4처럼 모르는 값은 예전처럼 99가 돼요.
- 단계 3에서 쓰러지면 집에서 다시 시작해요(초원 부활은 단계 1·2만).

## 2. 서버가 하는 일 (원격·Fx·줄·알림)

**[Accept] (`AcceptTutorial`, 인자 없음)**
- 단계 3 + 대장간 이동을 해요. 이동 방식은 A23-68 #1과 같아요.
- Fx `"Travel"` `{ UserId, To = "Crossroads", Spot = "Forge", T = 3 }`를 보내고, `MoveLockUntil = 지금 + 4.5`예요.
- 3초 뒤 순서
  1. `ZoneService.Travel("Crossroads", instant)`
  2. `Forge.Landing == "Anvil"`이고 모루가 있으면 `ZoneService.MarkTeleported` 뒤에 캐릭터를 옮겨요.
     - 자리: 모루 앞 `Forge.Back` 8 stud(교차로 스폰 쪽), 모루 바닥보다 `Forge.Lift` 4 stud 위, 모루를 바라봄
     - 8 stud는 프롬프트 거리 12 안이에요. 그래서 도착하자마자 E/탭이 떠요.
  3. Fx `"TravelDone"` `{ UserId }`, 잠금 0
- 이동하지 않는 경우
  - 이미 모루에서 `Forge.Near` 24 stud 안이면 처음부터 이동하지 않아요.
  - 이동 전에 캐릭터가 바뀌었거나(쓰러짐), 구역 규칙이 이동을 거절하면 옮기지 않아요. 이때도 TravelDone은 보내요.

**단계 3 퀘스트 줄** (`Quests` 원격의 첫 줄)
- `{ Id = "tutorial", Kind = "Tutorial", Pinned = true, TutorialStep = 3, Text = "Get your first weapon · Crossroads Forge", ShortName = "To the Forge", CanClaim = false, ShowProgress = false }`
- 다른 줄은 첫 [Claim] 전까지 `Folded`예요(지금과 같음).

**줄 탭 = `RequestTutorial` (인자 없음)**
- 단계 3이면 대장간 이동을 다시 해요. 다시 접속해서 집에 있을 때 쓰는 길이에요.
- 이동 중(잠금이 앞)이거나 모루 근처면 무시해요. 다른 단계에서는 예전 그대로(단계 0 = 안내자 창)예요.

**모루 프롬프트 (`HHC_BlacksmithPrompt`)**
- 단계 3이면 `ShopService` → `QuestService.ForgeGift(player)` 순서로 가요.
  1. Notify(info) `"Otto: Clang, clang… done. Here's your first weapon! Now go free the supply road."`
  2. `LootService.GrantFirstWeapon(player, 1)`: T1을 가지고 들어요. "You got your first weapon, [X]! Power 0 → N" 알림이 떠요. WeaponTier가 0 → 1이 되니 클라 Stronger! 순간도 그대로 떠요.
  3. 단계 1로 가요. 초원에 서 있으면 바로 2예요.
- 이때는 WeaponShop 창을 **열지 않아요**.
- `Forge.TravelDelay` 3초 뒤 초원 이동이에요. A23-68과 같은 Fx로 `To = "SlimeMeadow"`예요.
  - 그사이 초원에 걸어 들어갔거나(사냥 시작), 다른 이동이 진행 중이거나, 나갔으면 이동하지 않아요.
- 단계 3이 아닐 때(0·1·2·99)는 예전 그대로예요: 방문 기록 → M1_1 확인 → 상점 창.

**[Claim] (첫 임무 받기)**
- 150골드를 줘요. 그리고 **언제나** `BlacksmithVisited = false`로 바꿔요. M1_1 '젤리 보여 주기'에는 받은 뒤의 새 방문이 필요해서예요.
- 받기 문구는 소유한 무기에 따라 달라요.
  - T1만 가졌으면 `Claimed` "+%s gold. That buys a new weapon at the Forge!"(자동 받기는 `AutoClaimed`)
  - T2 이상(전설 포함)을 이미 가졌으면 `ClaimedArmed` "Check the gear at the Crossroads Forge."

**M1_1 '반짝이는 젤리'**
- 단계·안내(Blacksmith)는 그대로예요. 보상 `Reward = { Gold = 1 }`을 더했어요. 다른 1장 퀘스트와 같아요.
- 대사(Otto 말버릇 + 왕관 가루)도 그대로예요.
- `GiveWeapon = 1`은 안전망으로만 남겨요. T1을 가지고 있으면 아무 일도 없어요.
- 방문하면 대사 → 보상 → 상점 창 순서예요. 여기서 150골드로 T2(나무 무기)를 바로 살 수 있어요.

**옛 저장 (접속할 때, 한 세션에 한 번)**
- 단계 1·2·99 + 직업 고름 + 맨손(WeaponTier 0) + T1 없음이면 접속할 때 `GrantFirstWeapon`을 줘요. 실패하면 경고 1번 남기고, 그 세션에는 다시 시도하지 않아요.
- 주지 않는 경우
  - 단계 0·3: 대장간에서 받아요
  - T2 등으로 무장함: M1_1에서 가방으로 받아요
  - 직업을 안 고름

**기록(퍼널, `Config.Analytics.Steps`)**
- 새 순서: IntroDone, Faction, Class, FirstMissionAccept, **ForgeArrive, FirstWeapon**, MeadowArrive, FirstHit, FirstKill, FirstMissionDone, FirstSkillHit, AutoUnlocked, Level10
- `MeadowArrive`는 단계 2·99일 때만 세요. 예전 '≥ 2' 규칙이면 단계 3이 초원 도착으로 잘못 세졌어요.
- 옛 저장도 이 순서대로 따라잡아요.

**설정 (`Config.Tutorial`)**
- `Steps.Forge = 3`
- `Forge = { Landing = "Anvil", Back = 8, Lift = 4, Near = 24, TravelDelay = 3 }`
- 안내자 1쪽 `"First, get a weapon from Otto the Blacksmith!\nThen beat 5 slimes to free the supply road."`(세 진영)
- `Text.Forge`, `Text.ForgeGift`, `Claimed` / `AutoClaimed`(+ En)
- 함께 고친 문구
  - `Config.Text.WeaponFromQuest`: T1을 사려 할 때 나오는 문구. "The Blacksmith gives you your first weapon for free. Take the Guide's first quest!"
  - 소식(News) 한 줄

## 3. 150골드 제안 (숫자는 개발 2, 검토는 검수)

**제안: 숫자는 150 그대로 두고, '다음 무기 값'으로 뜻을 바꿔요.**
- 이유
  - T2 나무 무기는 150골드, Lv1부터 써요. 첫 임무 보상과 정확히 같아요.
  - 첫 무기(T1, 피해 8)는 대장간에서 공짜로 받아요. 그러니 150골드는 그다음 무기(T2, 피해 15)를 사는 돈이 돼요.
  - 그래서 처음 5분에 '팡!'이 두 번 와요.
    1. 대장간에서 공짜 첫 무기: Power 0 → 283 (Lv1)
    2. M1_1로 다시 대장간에 가서 150골드로 나무 무기: Power 283 → 387 (Lv1 기준)
  - 사는 건 강요하지 않아요. 상점 창이 열릴 뿐이에요.
- 바꾼 것
  - 받기 문구: "That buys a new weapon at the Forge!"
  - M1_1: Gold 1을 더함(1분 사냥 값). 무기 보상이 빠져서 빈손 퀘스트가 되지 않게 했어요.
- 물약 쪽은 손대지 않았어요.
  - 도시락의 착한 선택이 이미 HP 물약 1개를 줘요.
  - 첫 임무까지 물약을 주면 그 선택이 덜 특별해져요.
  - 슬라임 첫 사냥은 무기를 들면 위험이 낮아요.
- 다른 안(검수가 고르면 바꿈): 100골드 + HP 물약 2개. 이 안이면 나무 무기를 바로 못 사서 두 번째 '팡!'이 늦어져요. 그래서 추천하지 않아요.

## 4. 클라 계약 (게임성 개발 1 몫, 2026-10-07 메시지로 보냄)

a. `HUD L.PinnedTap`: step 3이면 `fire("RequestTutorial")`(step 0과 같게)
b. `HUD refreshGuides`: step 3이면 교차로에서는 모루(`L.BlacksmithTarget`)로 빔, 교차로 밖에서는 교차로 쪽 안내
   - 정할 때 `BlacksmithVisited`가 아니라 `TutorialStep`으로 정해요. 수락 전에 모루를 눌러 본 사람은 이미 true예요.
c. `QuestTarget.placeFor`: step 3이면 모루가 목표(step 99 대장간 줄과 같은 표시)
d. `FirstSteps` 이동 화면: `Spot == "Forge"`면 "the Forge"라고 보여 주면 좋아요(선택). 지금은 Zones.Crossroads.Name이 나와요.
e. `Panels` NoWeapons 문구 "...after your first mission."은 이제 틀려요. 예: "Bare hands for now. Accept the Guide's first quest and Otto gives you your first weapon."
f. 첫 쪽 임무 카드에 주먹·첫 무기 약속 같은 따로 그린 표시가 있으면 '무기 먼저'로 맞춰요.
g. `HUD L.RookieFold`의 예전 서버 대비 목록(0/1/2)에 3을 더해요(선택).
h. **Studio 확인**: 모루 앞 착지 자리가 실제 지도에서 이상하면(벽 안, 소품 위) `Config.Tutorial.Forge.Landing = "Spawn"`으로 바꿔요. 그러면 교차로 스폰에 내리고 빔을 따라 걸어요. 개발 2에 말하면 개발 2가 바꿔요.
- Stronger! 순간(HUD `L.First`)은 손대지 않아요. WeaponTier 0 → 1이 대장간에서 일어나요.

## 5. 시험 (오프라인, Studio 없음)

- `tools/test_weapon_first.py`(새로 만듦): 105개 검사, 변이 41/41
  - 처음 3분 전체: 수락 → 대장간 이동·착지 자리·잠금 → 선물·알림 순서·상점 창 없음 → 3초 뒤 초원 → 5마리 → 받기 → M1_1 → T2 구매
  - 착지 자리: Spawn / 모루 없음 / 이미 근처 / 캐릭터 바뀜 / 거절 / 단계가 넘어감
  - 줄 탭, 선물은 단계 3에서만, 옛 저장, 받기 문구 3가지, 저장 유지
  - 검수 2026-10-07 추가: 모루 없을 때(수락·단계 3), T2만 든 사람의 수락(단계 1, 아무것도 안 줌), 그 변이들
- 맞춘 시험
  - `test_onboarding`: 818개, 실제 QuestService·DataService
  - `test_unarmed_start`: 문구·정적 검사
  - `test_metrics`: 순서·MeadowArrive, 변이 51/51
  - `test_english`: 1쪽 문구, 체계 문구 역할 이름
- 한계: 실제 지도의 착지 자리, 클라 빔·탭·이동 화면은 개발 1이 Studio에서 PC와 폰으로 확인해요(A23-74 검사 규칙).

## 6. 게시 때 주의 (공개 체크리스트에 넣을 줄, 검수 2026-10-07 minor 1)

- 이 묶음(TutorialStep 3)을 게시할 때는 **모든 서버 종료(Shut Down All Servers)**를 같이 해요.
  - 옛 빌드(지금 공개 서버)는 단계 3을 모르는 값으로 보고 99로 바꿔 저장해요. 그러면 그 사람은 첫 임무를 영영 건너뛰어요.
  - 저장 버전은 3 그대로예요(검수 결정). 옛 빌드 서버가 하나도 남지 않게 하는 게 이 대신이에요.
- 대장간 단계를 다루는 클라(`wtc-weapon-client`)와 같은 라운드에 넣어요. 서버만 따로 병합·동기화하면 단계 3에서 탭·빔·마커가 없어 막혀요(검수 병합 검토 major).
- 게시는 사용자 OK 뒤에만 해요.
