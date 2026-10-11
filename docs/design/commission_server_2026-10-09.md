# 오토의 의뢰 (황금·수정·정령 무기 T4~T6) — 서버 계약 (게임성 개발 3, 2026-10-09)

**⚠ 2026-10-11 A23-127 §2: 제작은 장인 직업만 하므로 오토의 무기 판매·이 의뢰(T4~T6)는 새 규칙과 어긋나 베타 전에 다시 설계한다(오토 = 재료 팔기·장인 안내 자리). 이 문서는 구현 기록이고, 망치 미니게임이 이어받는다는 계승 방식은 정해지지 않았다.**

SPEC A23-86 결정 2 = A, `content_beyond_10min_2026-10-08.md` H. 대장간 [Commission] 줄은 **개발 1(화면)** 몫이에요. 서버는 끝났고, 스위치 `Config.Features.Commission`이 **꺼져 있어요**(화면이 생기면 켜요).

## 1. 무엇이 되나
- 대장간(오토)에서 T4 황금 무기(Lv12)·T5 수정 무기(Lv20)·T6 정령 무기(Lv30)를 **골드 + 재료 + 레벨**로 주문해요. 미니게임 없음(~~11/25 장인 업데이트~~). 드롭 T4/T5/T6은 그대로 운 좋은 지름길이에요.
- 값(`Config.Commission.Orders`): **T4 3,000 + Brute Horn 10 + Goblin Tooth 20**(설계 그대로), T5 10,000 + Rusty Knight Crest 12 + Bone 30, T6 30,000 + Rusty Knight Crest 30 + Bone 60 + Captain's Badge 1 (검수 2026-10-09). **T5·T6 재료 수는 내 제안**(Ruins 드롭률 Bone 0.4 · Crest 0.5, 분당 약 12킬 기준 T5 약 8분·T6 약 18분어치) — 값은 결정 2-2(검수).
- 골드는 무기 자체 `Price`와 같아요(Orders의 `Gold`). 상점 상한(`WeaponShop.MaxSoldTier`)은 3 그대로라 골드만으로는 못 사요.
- Robux·2배 패스 버튼, 권유는 이 창 근처에 없어요(A23-79).

## 2. 주고받기
- c→s `"Commission"`(tier: 정수) — 인자 하나, 1초 속도 제한, 준비됨·살아 있음·대장간 앞(`ShopService.CanBuyWeapon`)·전투 중 아님. 서버가 **전부 먼저 확인**(tier가 Orders에 있음 / 이미 안 가짐 / `Level >= Weapons[tier].MinLevel` / 재료 전부 / 골드)하고 **한 번에 뺀다**(중간에 yield 없음): 골드 `SpendGold(…, "Commission")`(들고 있는 골드 먼저, 부족하면 금고), 재료 `LootService.TakeItem`. 무기는 산 것처럼 얻고 **바로 장착**(`WeaponOwnedMask` 비트, `WeaponTier`, `BlacksmithVisited`).
- 거절 글(알림): 대장간에서 멀다 / "Otto says: come back at Lv N!" / "Otto needs more materials for this one." / "Not enough gold." / "You already have this weapon." / 전투 중. 거절하면 아무것도 빠지지 않아요.
- 성공: 알림 "Otto made your Goblin Thief's Golden Sword!", s→c `Fx "Upgrade" { Tier }`(기존 '전투력 A → B' 연출) + `Fx "Commission" { Tier, Name }`, 신호 `CommissionService.Made(player, tier)`, 지표 `Commission`(T4/T5/T6).
- **견습생 카드**(1.5초 뒤, 공용 선택 카드 `ChoiceCard` 종류 `ApprenticeScratch`, 저장 카드·시간 제한 없음): "The apprentice scratched the hilt a little." [It's fine. Thank you!] = 강화 주문서 70% 1장 / [Fix it AND give me a discount!] = 사냥 2분어치 골드(`Reward.GoldMin = 2`, 레벨로 계산). 보상 크기 같고 고정, 점수 1점(A23-58, 하루 장부 6점 안).
- 데이터: 화면은 `Config.Commission.Orders`(공유 Config)와 가진 재료 수(`data.Items`)로 줄을 그려요(재료 n/m 막대). 별도 리모트 없음.

## 3. 다음 목표 사다리
- `CommissionService.NextGoal(player, data)` → 줄 글, 종류 `"Commission4"|"Commission5"|"Commission6"`. 예: `Next goal · Golden weapon: Brute Horn 6/10 · 2.1K/3K gold`(가장 모자란 재료 → 골드 → 레벨 → "ready at the Forge!"). 이야기 줄이 없고 초반 목표가 끝난 뒤에만 보여요(M3_8 뒤, `Config.Tutorial.Ladder`의 첫 칸). T4는 Lv10부터, T5·T6은 Lv25부터(`ShowLevel`).
- 짧은 이름: Golden weapon / Crystal weapon / Spirit weapon. 누르면 갈 곳 = 교차로 대장간(`Config.Return.GoalZones`).

## 4. 켜기 전에 (개발 1 + 검수)
1. 대장간 창 [Commission] 줄(재료 막대·버튼 → `Commission` 리모트·거절 글·성공 연출).
2. `Config.Features.Commission = true`.
3. 결정 2-2: T5·T6 값 확인.
- A23-127 재설계 전에는 켜지 않는다.

## 5. 시험
`py tools/test_commission.py` — 검사 73개 + 정적 11개, 변이 46/46 (`docs/art/verification_2026-10-09/offline_dev3_commission_2026-10-09.json`).
