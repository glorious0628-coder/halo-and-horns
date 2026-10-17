# 제작 도구 ② 제작품 옵션 — 서버 계약 (게임성 개발 2, 2026-10-17)

근거: SPEC A23-219, 최종 검수 결정 10/17(저장 형식 OK: 키 셋째 칸 `T:P:O`, 옛 `T:P` = O0, 저장 판 올림), `build/codex/craft_tools_r1.md` §2.
덩어리 A = 무기·장비(이 문서). 덩어리 B = 물약·강장제·펫 간식(특제품 id) — 뒤에.

## 무엇
- 무기·장비 제작 시작 때 **한 번만** 굴림: 그 직업 도구 +N의 확률 `Config.Craft.Tools.Opt.P[+N]`(+0 10% … +10 60%), 붙으면 크기 `R[+N]`(1~5: +0~2 = 1, +3~5 = 2, +6~8 = 3, +9 = 4, +10 = 5). `Craft.Pend.Opt`에 저장 → 끊김·재접속·가방 가득 뒤에도 같은 결과. 다시 굴림 없음.
- 크기 하나당(`Opt.Size`): 무기 피해 ×(1 + 0.8%×R) (최대 +4%), 갑옷 HP +0.4%p×R (최대 2%p), 반지 공격 +0.2%p×R (최대 1%p), 펫 갑옷 펫 XP +4%p×R (최대 20%p), 펫 장신구 펫 XP +2%p×R (최대 10%p; 이동 보너스·PetAccMax 그대로).
- 역전 검산: +9 무기 최대 옵션 + 반지 최대 옵션 1.9×1.04×1.01 = 1.996 < +10 무옵션 2. 갑옷/반지 낮은 T +2 + 최대 옵션 = 다음 T +0 이하.
- 옵션은 그 물건에 영원히: 주문서·이전서(+N만 옮김)·포장·거래소로 바뀌거나 다시 뽑히지 않음.

## 저장 (판 7)
- `Config.Data.Version = 7` (옛 v6 서버는 v7 기록을 거절 = 옵션 키를 버리지 않음). v6 기록은 그대로(옛 키 = O0).
- 무기(가진 것): `data.WeaponOpt[tier]` = 0~5 (안 가진 T = 0; 팔기·포장 때 0). 손에 든 무기 옵션 = 속성 `WeaponOpt`.
- 예비 무기 `Spares["T:P"]`(O0) / `Spares["T:P:O"]`(O1~5). `"T:P:0"`은 저장 수리에서 `"T:P"`로.
- 장비 `Gear.Own["<Slot>:T:P[:O]"]`, `Gear.On.<Slot>` / `Gear.Pet[uid].<Slot>` = `"T:P[:O]"`.
- 거래소 `Market.Out[id].K = "W:T:P[:O]"`.

## 원격 / 화면 (개발 1 몫)
- `Inventory.Opt[tier]` = 가진 무기의 옵션 크기(0 = 없음). `Inventory.Spares` 키에 `:O`가 붙을 수 있음 (`Config.SpareParse(key)` → tier, plus, o).
- `GearInfo`의 키도 `"T:P:O"`일 수 있음 (`Config.GearParse(key)` → tier, plus, o; `Config.GearBonusOf(slot, key)`가 옵션 포함 값).
- `CraftResult.Opt` = 이번에 붙은 크기(없으면 nil). `MarketMine/MarketPage` 행에 `Opt`.
- 옵션 값: `Config.CraftOptBonus(kind, o)` (kind = Weapon / Armor / Ring / PetArmor / PetAcc), 무기는 `Config.GearMultsOf`의 atk에 이미 곱해짐(전투력·피해 같은 식).

## 규칙
- 같은 T를 가졌을 때 예비 꺼내기·거래소 사기: **피해가 더 큰 것**(+N 배율 × 옵션)일 때만 바꿈/삼. 같은 +N이라도 옵션이 더 좋으면 됨.
- 손에 든 무기 옵션은 `Config.GearMultsOf` atk에 곱함(장비 스위치와 상관없이). 피해·PvP 비율·전투력 모두 같은 값.
- 펫 XP: `Config.PetGearBonus(gear, uid, "PetXP")` = 펫 갑옷(옵션 포함) + 펫 장신구 옵션.

## 시험
`py tools/test_craft.py` 묶음 'opts'·`test_save_v4_tables`·`test_loot`·`test_market`·`test_gear_slots` (+ 변이).
