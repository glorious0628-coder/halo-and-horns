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

## 4. 2단계 (10/16–17 예정)

StatService(원격 `StatAction`: add/add5/reset/auto, 막기 3종, 레벨업 자동 배치, 속성 StatAtk·StatHp·StatFree·AutoStat), 피해(`ComputeMonsterHit` × atkMult), PvP(비율 안에서, 0.8–1.5 상한 그대로), 최대 HP(`Config.StatMaxHealth`), 미끼 기준, 처음 한 줄 안내. 그다음 10/20 점검에서 스위치 켜기.
