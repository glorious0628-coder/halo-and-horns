# A23-69 스탯 찍기 서버 1단계 (게임성 개발 2, 2026-10-07 밤)

설계: `docs/design/stat_points_2026-10-07.md`(§1–§3, §5-1, §7-3). 1단계 = **스위치 꺼진 채로** 표·저장·전투력 공식만 넣는다. 꺼져 있는 동안 게임 숫자는 지금과 똑같다.

## 1. 무엇이 생겼나

- **스위치:** `Config.Features.StatPoints = false`. 켜는 건 2단계(StatService·피해·HP)가 끝난 뒤 10/20 점검에서.
- **표 `Config.Stats`:** 최대 99점, 글자 A(Attack)·H(Health), 곡선 1%(20점까지)·0.5%(40점까지)·0.25%(그 뒤), 자동 패턴 전사·마법사 `HA`, 궁수 `AH`.
- **도우미(서버·클라 공용):**
  - `Config.StatBonus(r)` = f(r) (10점 +10%, 20점 +20%, 30점 +25%, 40점 +30%, 99점 +44.75%; 99점 넘으면 99점으로)
  - `Config.StatPoints(level)` = 레벨 − 1 (0~99, 환생으로는 안 늘어남)
  - `Config.StatAlloc(stats, level, class)` → (A, H, 남은 점수): 자동이면 직업 패턴, 직접이면 Order 앞 글자. **레벨이 내려가도 Order는 그대로** → 다시 크면 같은 순서로 다시 찍힘.
  - `Config.StatMults(a, h)` → 스위치 꺼짐이면 (1, 1)
  - `Config.StatAllocOf(player)` → 속성 `StatAtk`·`StatHp`(2단계 StatService가 씀)
  - `Config.SanitizeStats(t)` → Auto는 boolean만(아니면 켜짐), Order는 대문자 A–Z만 99자까지
    - 검수 2026-10-07: 다음 단계 스탯을 위해 A·H 말고도 대문자는 남긴다. 셀 때(`StatAlloc`)는 A·H만 세고, 나머지 글자의 점수는 남은 점수가 된다.
- **저장: 버전은 3 그대로, `Stats`는 더하기만 하는 필드** (검수 2026-10-07 결정. Settings·Rank·SkillsA71과 같은 방식)
  - 새 필드: `Stats = { Auto = true, Order = "" }`
  - 옛 저장은 불러올 때 기본값(자동 켜짐, 찍은 것 없음)이 붙고, 다른 값은 그대로예요. 잔액은 저장하지 않아요(레벨로 계산).
  - v3 서버도 이 필드를 그대로 보존해요. 그래서 1단계 게시에는 **모든 서버 종료가 필요 없어요.**
  - 처음에 버전 4로 했던 것은 되돌렸어요. Studio가 진짜 DataStore에 v4를 쓰면 v3 서버가 그 기록을 거부해서 되돌릴 수 없는 잠금이 생겨요.
  - 버전을 올릴지는 2단계(스위치 켬) 게시 때 다시 정해요.
- **전투력 한 공식 `Config.CombatPowerOf(player, tier?, +N?)`:** 속성 Level·WeaponTier·WeaponEnhance·StatAtk·StatHp로 계산. 서버 4곳이 모두 이걸 쓴다.
  - JusticeService: `GetCombatPower`(CombatPower 속성·괴롭힘·대담함), `GetPower`(진영 합계, 환생 보너스 포함 + 스탯), CombatPower 속성은 StatAtk·StatHp가 바뀌어도 다시 계산
  - PvPService 대체식, Tab 목록 Power 칸, LootService 첫 무기 "Power X → Y"(무기만 바꾼 값)
  - `Config.PowerOf / CombatPower`는 5번째·4번째 인자 `alloc = { A, H }`를 받는다(없으면 0점). `MaxCombatPower`: 꺼짐 25,488 / 켜짐 33,740(49/50 균형), 따로 저장.
- 예시(켜짐, 자동): Lv10 무기3 923 → 965, Lv20 무기5 2,829 → 3,098, Lv100 무기7 18,023 → 23,858. Lv100 한 스탯 몰빵 = 균형의 0.909, 아무것도 안 찍음 = 0.755.

## 2. 클라 (게임성 개발 1)

- HUD 전투력 칩의 대체식(`HUD.L.PowerValue`, 서버 속성이 오기 전)을 `Config.CombatPowerOf(Players.LocalPlayer)`로 바꿔 주세요. 지금은 스위치가 꺼져 있어서 값은 같지만, 켜지면 스탯이 빠진 숫자가 잠깐 보일 수 있다. (`tools/test_beta_basics.py`의 HUD 정적 검사 문구도 같이.)
- [Stats] 탭·빨간 점·레벨업 줄은 2단계와 함께(설계 §4, §6).

## 3. 검사

- 새 `py tools/test_stats.py`: 표·스위치·저장 모양, 곡선, 점수·자동·직접(레벨 하락·재성장), 꺼짐이면 모든 숫자 같음, 켜짐 예시 숫자, 최대치 두 개, `CombatPowerOf` = Justice·PvP 대체식·Tab 칸(60명 무작위, 켜짐/꺼짐), CombatPower 속성이 StatAtk·StatHp를 따라감, 첫 무기 "Power X → Y", Stats 없는 v3·v1 기록에 기본값만 붙음(버전 3 그대로), 깨진 Stats 고치기, A–Z 보존, 두 번 불러도 같음.
- 저장 쪽 기존 시험: onboarding(Stats는 기본값만 붙음, 찍은 빌드가 저장·복구됨, v4 기록은 v3 서버가 거부), keys_settings, ranking, tamer, unarmed_start, beta_basics(PvP 대체식 = CombatPowerOf), loot·names_columns 변이 문구.

## 5. 2단계 (2026-10-08, 가지 dev2-stats2): 스위치는 여전히 꺼짐
- **새 `StatService.luau`**가 생겼어요. Main INIT/START에서 SkillService 다음이고, PlayerService는 계속 마지막이에요.
  - 원격 `StatAction`은 Net.Names 끝에 있고, `RateLimits.StatAction = 0.15`예요.
- **꺼져 있으면**(`Features.StatPoints = false`) 속성을 하나도 쓰지 않고 원격도 거절해요. 그래서 게임 숫자는 지금과 똑같아요.
- **켜지면:**
  - 속성 `StatAtk`·`StatHp`·`StatFree`·`AutoStat` = `Config.StatAlloc(data.Stats, 레벨, 직업)`이에요.
    - 다시 쓰는 때: PlayerReady, LeveledUp(자동이면 서버가 찍음), LevelReset, Rebirthed, ClassChanged, 행동 뒤.
  - `StatAction(op, arg)`(클라는 숫자를 보내지 않음):

    | op | arg | 하는 일 |
    |---|---|---|
    | "add" | "A" / "H" | 1점. 자동 꺼짐이고 남은 점수가 있을 때 |
    | "add5" | "A" / "H" | min(5, 남은 점수)점 |
    | "reset" | 없음 | Order 비우기. 자동 꺼짐, 3초에 한 번(`Stats.ResetCooldown`) |
    | "auto" | true / false | 끄면 자동이 찍은 글자를 Order로 옮겨요(숫자 그대로). 켜면 Order를 비워요(확인 창은 클라) |

  - 막기:
    - PvP 전투 태그·괴수·원한 자루면 알림 키 `TravelBlockedCombat`·`BlockedKaiju`·`BlockedSack`로 막아요.
    - 쓰러짐·준비 전·직업 미선택·속도 제한·잘못된 인자면 조용히 무시해요.
    - 레벨업 자동 배치는 늘 돼요.
  - 바뀐 뒤 `RefreshCharacter(p, false)`를 불러요(HP 비율 유지, 꽉 채우지 않음). 그다음 'Power X → Y' 한 줄을 보내요(소리 None).
  - 안내 줄은 첫 [Claim] 뒤에만 보내요:
    - 첫 점수 1번: "New Stat Point! Auto placed it. Tap Power to see."
    - 자동 레벨업: "+1 Health · Power X → Y". 여러 레벨이면 "+2 Attack +1 Health · …"
    - 직접 모드: "+N Stat Points! Tap Power."(Config.Plural)
    - 처음 자동을 끌 때 1번: "Tap + to pick. Reset is free!"
    - 기록: `data.Story.First.StatPoint` / `StatManual`
  - `Fx "Stat"` { Kind = "First" | "Level" | "Action", From, To, A, H, Free, Auto }을 보내요. 전투력 칩 빛남과 숫자 올라가기에 써요(개발 1).
- **전투 연결:**
  - 몬스터 피해: `ComputeMonsterHit` × (1 + f(Attack))
  - PvP: 비율 = (공격 무기 × 공격 배율) / (맞는 무기 × HP 배율)이에요. 기존 상한 0.8(맨손 0.4)~1.5 안에서 셈해요.
    - 기준 = `Config.StatMaxHealth(맞는 쪽 Health) × 0.1`이에요. 그래서 늘 6.67~12.5타예요. 맞는 쪽의 Health는 한 번만 들어가요.
  - 최대 HP: `PlayerService.computeMaxHealth` = StatMaxHealth × Justice 배율
  - 미끼 기준(PvPService)도 StatMaxHealth를 써요.
- **Config:** `Stats.ResetCooldown`, `Stats.Text`, `StatMaxHealth`, `Power.Text.FormulaStats`("Set by your level, weapon and stats", 켜졌을 때 클라가 고름), `PluralWords["Stat Points"]`.
- **클라(개발 1):** [Stats] 탭(StatUI), 빨간 점(직접 모드이고 StatFree ≥ 1), 칩 빛남, 확인 창 2개("Turn off Auto to pick yourself?", "Auto will replace your picks.")를 이 계약에 맞춰 붙여요.
- **시험:** `py tools/test_stat_service.py`, 70검사, 변이 37/37.
  - 꺼짐이면 그대로인지, 속성, add·add5·reset(3초)·auto, 거절 12가지와 막기 3종, 속도 제한을 봐요.
  - 레벨업 줄·첫 안내·직접 모드 줄, 레벨 하락 뒤 다시 자람, 환생, 직업 바꿈도 봐요.
  - 숫자: 피해 ×1.2, 최대 HP ×1.3 × Justice, PvP 무작위 300쌍이 6.67~12.5타인지 봐요. 맞는 쪽 Health가 버티는 타수를 늘리는지도 봐요.
- **켜기 전(10/20 점검):** 저장 버전(3 유지 / 4)을 정하고, 스위치를 켠 채 2클라 PvP와 폰으로 확인해요.

## 4. 2단계 (10/16–17 예정 → 위 §5에서 함)

StatService(원격 `StatAction`: add/add5/reset/auto, 막기 3종, 레벨업 자동 배치, 속성 StatAtk·StatHp·StatFree·AutoStat), 피해(`ComputeMonsterHit` × atkMult), PvP(비율 안에서, 0.8–1.5 상한 그대로), 최대 HP(`Config.StatMaxHealth`), 미끼 기준, 처음 한 줄 안내. 그다음 10/20 점검에서 스위치 켜기.
