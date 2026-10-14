# 무기 운 보정 — 서버 (게임성 개발 2, 2026-10-15; gameplay_plan 10/14 §2-A ⑤)

가지 `dev2-weapon-luck`(origin/main 위). 화면 일 없음(드롭 줄·Loot Fx는 원래 것 그대로).

## 첫 처치 확정 (첫 Prince T2·첫 King T3와 같은 방식)
- 첫 **Goblin Brute** = T4, 첫 **Skeleton Knight 또는 Captain Clatter** = T5(둘이 깃발 하나: 먼저 잡은 쪽이 줌). `Config.Loot.FirstTierDrops`.
- 깃발 `LootFlags.FirstBruteWeapon` / `FirstKnightWeapon`, 한 번만. 이미 가진 단계면 기회만 쓰고 아무것도 안 줌.
- 무임승차 몫(Minor)·연습 보스(Practice)는 안 셈. 레벨이 모자라면 가방에(장착 안 함), 손에 든 것보다 세면 바로 장착.
- 글: "The Goblin Brute dropped [%s]!" / "The Skeleton Knight dropped [%s]!" / "Captain Clatter dropped [%s]!" (+ " Equipped.").

## 단계별 운 카운터 (`Config.Loot.WeaponPity`)
- 처치마다, **아직 없는 단계**의 무기 줄이 굴려지면 그 줄 확률(황금 몹 x3, 최대 1)을 `data.WeaponPity["T<단계>"]`에 더해요(저장 칸 새로, **더하기만**, 버전 올림 없음).
- 합이 `At`(지금 모두 1.5 = '드롭 1.5번 몫')에 닿으면 그 단계 확정: "Your hunting paid off! [%s]!".
- 몇 마리쯤: T4 = 브루트 300 또는 고블린 750, T5 = 기사 375, T6 = 기사 1500 또는 Clatter 150(Lv30부터), T3 = Prince 100. 잭팟 T8은 없음.
- 레벨 아래라 안 굴리는 BelowLevel 줄(Clatter T5·T6)은 안 셈. 괴롭힘 벌·랭킹 보너스·구덩이 배수는 안 섞음. `Enabled = false`면 끔.
- 숫자 조정은 `At` 하나(단계별). 10/17·11/7 시험 기록으로 다시 봐요.

## 숲 서브 2개 (모두에게, 장인 포함)
- **GW9 "Otto's Lost Blades"**(Lv12, M2_7 뒤): 숲 브루트 2 → 고르기 → Gold 2·XP 2 + 30% 주문서 1.
- **GW10 "Ready for the Ruins"**(Lv20): 숲 고블린 15 + 브루트 3 → 고르기 → 같은 보상.
- 고르기 보상은 다른 숲 서브와 같음(선 = 70% 주문서, 악 = HP 물약 3 + 220). 글은 무기를 약속하지 않음.
- 영·한 대본(`docs/script/`)에는 아직 없음 → 2-A ⑬(말투 81줄·대본 다시) 때 같이.

## 시험
- `tools/test_loot.py`: 새 묶음 'first tier drops'·'weapon pity'(37개) + 확률 통계 묶음은 새 깃발·카운터를 꺼 두고 셈. `tools/test_commission.py` 변이 글 하나 고침(T4 출처 글이 바뀜).
