# ⑥ 방어구·반지·펫 장비 칸 (게임성 개발 3, 2026-10-12, 설계안 — 게임성 검수·개발 2 판단 전)

근거: SPEC **A23-133**(방어구·반지 = 베타에 넣음, **전투력 숫자에 반영**, '몬스터에게만' 안은 버림, 돈으로 파는 능력치 없음 / 펫도 방어구·액세서리를 끼고 **펫 장비도 장인이 만든다**), A23-127(제작은 장인만), `save_v4_tables_2026-10-11.md`(Gear = { Own["<kind>:T:P"] = n, On.<slot> = "T:P", Pet[uid].<slot> = "T:P" }, 한 물건은 한 곳에만, Own 60개·키당 20), `craft_server_2026-10-12.md`(Kind "Gear" 레시피·망치질 +N), crafting_market §4(Armor/Ring 각 3단: Iron Lv8 / Crystal Lv16 / Spirit Lv24). 스위치: 새 `Config.Features.Gear`(장인 길드와 같이 켬).

## 1. 사람 칸 2개: Armor · Ring
| 칸 | 효과 | T1 / T2 / T3 | 망치질 +N마다 | 끼는 레벨 |
|---|---|---|---|---|
| Armor | 최대 체력 × (1 + x) | +6% / +12% / +18% | +2% | Lv10 / 20 / 30 |
| Ring | 내 공격 피해 × (1 + x) | +4% / +8% / +12% | +1% | Lv10 / 20 / 30 |
- 꼭대기(T3 +2 둘 다): 체력 ×1.22, 피해 ×1.14 → 전투력 √(1.14×1.22) ≈ **+18%**. 무기 한 단계보다 작게.
- **어디에 듣나(모두 개발 2 파일, 한 줄씩):** `PlayerService.computeMaxHealth` × 체력 배수 · `CombatService.ComputeMonsterHit` × 피해 배수 · `ComputePvPHit`: 공격자 무기 피해 × 내 피해 배수 / 상대 무기 피해 × 상대 피해 배수 → 기존 0.8~1.5 비율 자르기 그대로, 맞는 쪽 기준 체력은 **기본** MaxHealth 그대로(그래서 방어구 = 더 많이 버팀) · `Config.CombatPower(level, tier, enhance, alloc, gear)` → `PowerOf`의 공격·체력 배수에 곱함 · `JusticeService` POWER.Watch 속성 목록에 `GearAtk`·`GearHp` · `Config.MaxCombatPower`는 가장 좋은 장비 포함.
- **속성(모두에게 보임):** `GearAtk`, `GearHp` = 배수(1 = 없음). `Config.GearMultsOf(player)` → (atk, hp), 스위치 꺼짐 = (1, 1). 서버·클라 같은 식.

## 2. 펫 칸 2개: PetArmor · PetAcc (따라오는 펫에만 들음, 전투력 밖 — BB4 '펫은 전투력에 안 셈' 그대로)
| 칸 | 효과 | T1 / T2 / T3 | +N마다 |
|---|---|---|---|
| PetAcc | 걷기 보너스 + x (Speed.Cap 그대로) | +1% / +2% / +3% | +0.5% |
| PetArmor | 펫 XP(처치·간식) × (1 + x) | +20% / +40% / +60% | +10% |
- 걷기: `Config.WalkSpeed(..., petRoll, petAcc)` + 속성 `PetAcc`(PetService publish가 따라오는 펫의 칸에서 읽음). 펫 XP: `PetService.giveXP` 앞에서 한 번 곱함(내림).

## 3. GearService (새, 개발 3)
- c->s `EquipGear(slot, key)` — slot ∈ {Armor, Ring}, key = "T:P"(Own에 있는 것) 또는 ""(벗기). 검사: 스위치, 준비됨·살아 있음, 끼는 레벨, Own[kind:T:P] ≥ 1. 바꿀 때 끼던 것은 Own으로(한 곳 규칙, Own 60·키 20 상한 넘으면 거절 `Full`). 0.5초에 1번.
- c->s `EquipPetGear(uid, slot, key)` — 내 펫 uid, slot ∈ {PetArmor, PetAcc}, 같은 규칙. 펫이 없어지면(나중 기능) 그 칸은 Own으로.
- s->c `GearInfo { Own, On, Pet }`(들어올 때·바뀔 때). 속성 GearAtk/GearHp는 들어올 때·바뀔 때.
- 저장 고치기는 v4 그대로(Config.SanitizeGear). 알림은 키만(Config.Gear.Text).

## 4. 레시피 (CraftService 표에 줄만)
- 대장장이: Armor G1~G3(제작 Lv 8/16/24, 철·참나무 → 수정 → 은·달 수정 + 같은 구역 몬스터 재료), Ring R1~R3(같은 Lv, 은·빛버섯 → 달 수정).
- 조련사: PetArmor PA1~PA3, PetAcc PC1~PC3(제작 Lv 5/12/20, 젤리·꽃잎·약초 → 고블린 이빨 → 뼈·기사 문장).
- 골드·XP는 무기 사다리 사이 값(검수 판단). 정확한 재료 표는 구현 때 이 표 모양으로 Config에.

## 5. 시험
`tools/test_gear_slots.py`(새): 끼기·벗기·바꾸기(한 곳 규칙), 레벨·소유·상한·스위치, 속성·GearInfo, 배수 식(T·+N), 전투력·MaxCombatPower, 펫 칸(내 펫만, 걷기·XP), 원격 인자·속도. 정적: 개발 2 파일의 한 줄씩(computeMaxHealth·ComputeMonsterHit·ComputePvPHit·POWER.Watch). 회귀: beta_basics(MaxCombatPower)·pvp·pet_speed·tamer·craft·save_v4.

## 6. 진행
- 큰 코드라 **API 쓰기 모드**(`--make-worktree origin/dev3-tamer --write --branch api/dev3-gear --model opus`, 한도 $8, 자주 커밋)로 돌리고, 나는 지휘·확인. 게임성 검수가 api/dev3-gear를 시험.
- **판단 부탁(게임성 검수):** ① §1·§2 숫자 ② 끼는 레벨 10/20/30 ③ 펫 칸 효과(걷기·펫 XP) ④ PvP에서 반지가 비율 안에서만 듣는 것(0.8~1.5 자르기 그대로).
- **확인 부탁(게임성 개발 2):** CombatService·PlayerService·JusticeService·PetService에 한 줄씩 들어감(§1·§2). 모양 괜찮은지.

## 7. 결정·됨 (2026-10-12)
- **게임성 검수 OK:** 숫자·끼는 레벨 10/20/30·펫 칸·PvP(반지는 0.8~1.5 자르기 안, 방어구는 실제 MaxHealth만). 조건: 장비 +N = 망치질 +0~2만, 주문서는 장비에 안 됨(SanitizeGear P 0..2, UseItem은 무기 tier만 — 시험·변이).
- **게임성 개발 2 OK(4개 파일 한 줄씩) + 후속:** PetArmor 소수 나머지 보관(처치 1 XP × 1.2 다섯 번 = 6), 싸우는 중 끼기·벗기 거절(InCombat), 방어구 체력은 RefreshCharacter(false)로 비율 유지, 최고 장비 몫은 계산(MaxWeaponTier 9가 와도 맞음), ComputeWalkSpeed 맨 위는 황금 알 몫이라 안 건드림, 물약 MonsterDamage × 반지 = 곱(의도).
- 구현: API job dev3_gear(sonnet, $8.07, 97턴) → api/dev3-gear 59ecc2dc + 후속 847dcd31(개발 3). 펫 장비 저장 이름 = `Gear.Pet[uid].PetArmor / .PetAcc`(칸 이름 그대로), 펫 장비 끼는 레벨 없음, Gear 레시피는 Features.Gear 켜져야 켜짐.
- 클라 몫: 장비 창(사람 2칸·펫 2칸), GearInfo, EquipGear / EquipPetGear.
- **게임성 검수 시험 뒤(10/12):** Config 장비 함수는 지켜서 부름(test_owner_restore). 켜기 전 고침: ① 레벨이 끼는 레벨 아래로 내려가면(무료 직업 바꾸기·환생) 그 칸 효과는 멈춤(끼운 채로, 다시 그 레벨이 되면 돌아옴; Level 속성 지켜봄) ② PetAcc 속성은 있을 때만(꺼짐이면 없음) ③ 장비 제작 뒤 GearInfo ④ 진영 크기(JusticeService.GetPower)도 장비 포함 ⑤ **PetArmor는 그 펫이 끼고 있으면 따라오지 않아도 간식 XP에 들음**(처치 XP는 따라오는 펫만 받으니 처치에선 따라오는 펫의 것) ⑥ PvP에서 맞는 쪽 반지도 비율 분모에 들어감(무기 비율과 같은 방식).
