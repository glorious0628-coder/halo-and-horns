# 게임성 개발 3 — 상태 (2026-10-11 밤)

역할: 장인 길드 서버(`role_prompts/04_dev3.md`). 서버만, Studio 안 열고 main에 직접 push 안 함. 보고처 = **'게임성 검수'**(가지 push 보고), 사용자 질문·화면 조작 = '최종 검수'(모든 것 검수). 세션 id는 list_sessions로.
작업 폴더: `C:/Users/glori/Documents/Roblox/Game-dev3w`(sparse: src·tools·docs·AGENTS.md, `build/luau_cli_0_741` 있음).

## 끝난 것 (가지, 병합 대기)
1. **`dev3-v4-tables` e5c8bb08** — 저장 v4 표 합의(개발 2와, `docs/design/save_v4_tables_2026-10-11.md` '합의') + 모양·고치기 코드(Craft·Research·Gather·Gear·Buffs·Shop·EggHonorAt, Config.SanitizeSaveV4, PetService Roll). Version 3 그대로. 시험 test_save_v4_tables(96 named, 변이 53/53). 게임성 검수에 병합 요청 보냄.
2. **`dev3-gather`**(dev3-v4-tables 위) — 채집 서버: `GatherService.luau`, `LootService.GrantItems`, Config(재료 8종·노드 7종·자리 54·Shard Bloom 카드, 스위치 `Config.Features.Gathering = false`), Net `GatherState`, Main 두 목록. 시험 test_gather(113 named, 변이 74/74). 화면은 개발 4 `dev4-gather`(GatherView) — 모양 맞춤 확인함(GatherState, GatherPrompt, ActionKey/ObjectKey, Enabled 안 건드림, FirstHint 없음).
- API 작업 `dev3_gather`(opus)는 PC가 꺼지며 47턴 $4.11에서 멈춤(Config만 씀, 커밋 없음) → 그 Config를 가져와 나머지는 직접 씀. api 작업 상태는 'running'으로 남아 있지만 죽은 작업. 임시 worktree는 지움.

## 지금 (10/12 새벽)
- **`dev3-craft`**(dev3-gather 520e8cb7 위) 37113fa4: ③ 제작 서버 설계 `docs/design/craft_server_2026-10-12.md` — 게임성 검수 판단 대기(숫자·펫 장비 역할·Spares 의존). 개발 4 망치질 계약 그대로 받음(false = +200ms 확인 요청). 개발 2에 AddSpare/SpareRoom·KingJelly/ClatterGem 부탁.
- 코드 끝: CraftService(dev3-craft). 망치질은 개발 4의 공용 `Shared/CraftMini.luau`(고정 일정, CraftStrike(id, i, ms), CraftFinish(id), Accept) — 같은 파일을 이 가지에도 넣음. test_craft 101·56/56, test_craft_mini 45·16/16(dev4-craft 44dba035와 동일). 무기 결과는 개발 2 AddSpare/SpareRoom 뒤.
- **켜는 가지에서 할 것:** 2배 XP 패스 설명 문구 바꾸기 + 정적 검사(설계 §8, 최종 검수 10/12). TolMs 질문은 CraftMini.T(Early/Late/JitterMul)로 옮겨감.
- 게임성 검수 10/12 후속(dev3-craft에): 채집 켜기 전 고칠 것 5개(gather_server §9-2) + 제작 지표 CraftStrikeD. **채집 켜는 조건 남음: SellItem 또는 거래소.**
- 제작 켜기 전 고칠 것 6개 반영(craft_server §8): Pend = { Id, Plus, Gold, Mats } 등. **제작 켜는 조건 남음: 개발 2 AddSpare/SpareRoom(+ W7·W9는 새 재료·T9) + 패스 문구.**
- 다음: ④ 연금 버프 물약(같은 레시피 표에 Kind Item 줄 + Buffs).

## 다음 (04_dev3.md 순서)
③ CraftService(대장장이 T1~T7·T9, 장인만, 망치질 서버 간격 검사) — 레시피에 채집 재료 넣기(gather_server §1 방향: 구리 T1~3, 철 T4~5, 은 T6~7, 달 수정 T9, 참나무 손잡이·방어구, 약초·빛버섯 물약). Craft 저장은 역할마다 Lv/XP.
④ 연금 버프 물약(Buffs 저장 있음) ⑤ 조련사 연구(Research, Pets Roll) ⑥ 방어구·반지·펫 장비(Gear, 전투력 반영 A23-133) ⑦ 장인 명성·계급(Craft.Rep) ⑧ 장인 첫 10분.

## 게임성 검수 후속 (dev3-gather에 넣음)
- EggHonorAt 미래 값 → now로 자름(0 아님). 오토 한 번에 팔기 = 몬스터 재료만(`Source` 있는 물건 제외), 채집 재료는 나중에 SellItem. 개발 2에 알림.
- test_new_zones의 'Loot 새 물건 없음' 검사가 채집 재료(Source "Gather")를 나중 묶음으로 보게 고침. test_skills STATIC 실패(CombatService.Release)는 main 그대로 = 이 가지와 무관.

## 열린 것
- 새 구역 노드(9번째 재료)는 E-1 구역 정해진 뒤. 노드 3D는 이미지 쪽(그 전엔 임시 파트, 스위치 꺼짐).

## 주의
- 시험 파일을 import 하면 일부는 바로 실행된다(test_beta_basics 등) → 변이 패턴 비교는 AST로만(스크래치 mut_hits.py 방식).
- `Config.Features = {…}` 줄은 바꾸지 말 것(test_stats·test_next_goal 변이가 그 줄을 씀) → 새 스위치는 따로 한 줄.
- 기계가 바쁘면 다른 시험 변이 전체 실행은 몇 시간 → 회귀는 --no-mutations + 변이 패턴 적중 비교.
