# 조련사 연구·소환·간식 서버 (게임성 개발 3, 2026-10-12, 설계 — 합의 전)

근거: `crafting_market_2026-10-11.md` §4 조련사(연구력 = 조련사가 잡은 몬스터 가족마다 1점, 단계 50/150/400/1000/2500, 소환 = 연구 2단계 + 재료 → 그 가족 펫·능력치 게임 안 랜덤·로벅스 없음, 베타는 3D가 있는 슬라임 가족만, Pet Treat = 펫 XP +20·거래 가능·펫은 못 팖), A23-115·A23-127(조련사 = 펫 쪽)·A23-133(펫 장비도 장인 — ⑥)·A23-139(제작 XP 패스 2배·장인만), `save_v4_tables`(Research {Pts, Sum}, Pets.List[uid].Roll {Spd 5..10}), `craft_server_2026-10-12.md`(레시피 표·망치질). 스위치: Config.Features.Crafting(소환·간식 레시피)·새 `Config.Features.Research`(연구 세기, 장인 길드와 같이 켬).

## 1. 연구력 (TamerService, 새 서버 모듈 — 개발 3)
- 조련사(`Config.IsTamer(class, faction)`)가 돈 받는 처치(`MonsterKilled`, MinorShare 아님)마다 `Research.Pts[가족] += 1`, 가족 = `Config.QuestKind(kind)`(슬라임·왕자·꽃슬라임·킹 = Slime 가족). 자동 전투 처치도 셈(펫이 대신 싸우는 직업, A23-39).
- 단계 = `Config.Tamer.Research.Stages = { 50, 150, 400, 1000, 2500 }`. s->c `TamerInfo { Pts, Stage, Sum }`(들어올 때·바뀔 때 1초에 1번까지).

## 2. 소환 = 제작 레시피 `Kind = "Pet"` (CraftService — 개발 3)
- `S1 = { Role = "Tame", Kind = "Pet", Family = "Slime", Species = "BabySlime", Research = 150, Lv = 1, Gold = 100, Mats = { Jelly = 30, SlimeCore = 5 }, XP = 40 }`.
- 시작 검사에 더함: `Research.Pts[Family] ≥ Research`(아니면 알림 키 `NeedResearch`), 펫 칸 여유(PetService 상한 64).
- 끝: 능력치 `Spd = 서버 무작위 5..8 + 망치질 +N`(최대 10, 로벅스·뽑기 없음 — 실력이 조금 올려 줌) → **PetService.SummonPet(player, species, { Spd })** → `Research.Sum[Family] += 1`.

## 3. 펫 간식 Pet Treat
- 레시피 `T1 = { Role = "Tame", Kind = "Item", Item = "PetTreat", N = 3, Lv = 1, Gold = 10, Mats = { Jelly = 5, Petal = 2 }, XP = 10 }`(3 + 망치질 +N개). 아이템 `PetTreat`: Kind "Treat", Source "Craft"(오토 한 번에 팔기 제외, 거래소 대상).
- 먹이기: c->s `FeedPet(uid)` — 펫 주인 누구나(조련사만 아님), 간식 1개 → **PetService.AddPetXP(player, uid, 20)**(처치 XP와 같은 레벨업), 최대 레벨 펫은 거절(`PetMax`), 0.5초에 1번.

## 4. 개발 2 파일에 필요한 것 (질문 — 내가 넣을지, 네가 넣을지)
1. `PetService.SummonPet(player, species, roll) -> uid | nil` — **같은 종이 있어도 새 펫**(지금 grant는 종마다 하나), Bound, Roll 저장, 상한 64. 펫 없으면 바로 데리고 다님.
2. `PetService.AddPetXP(player, uid, n) -> lv | nil` — onKilled의 레벨업 고리를 함수로(같은 숫자).
3. **속도:** Roll이 있는 펫 = Lv1에 Spd%, MaxLv에 Spd+3%(아기 슬라임 7→10%와 같은 기울기). → PetService publish가 속성 `PetRoll`(Spd, 없으면 0)을 달고, `PlayerService.ComputeWalkSpeed` → `Config.WalkSpeed(class, species, lv, kaiju, roll)` → `Config.PetSpeedBonus(species, lv, roll)`. 상한 `Config.Speed.Cap` 그대로.
4. PetList 줄에 `Roll`(창이 능력치 표시) 더하기.
- 제안: 네가 C1/C2로 바쁘면 내가 dev3-tamer 가지에 1~4를 작게 넣고 네가 읽어 확인. 네가 넣고 싶으면 이름·모양만 이대로.

## 5. 시험 `tools/test_tamer_research.py`(새) + test_craft 늘림
연구(조련사만·MinorShare 제외·가족·단계·꺼짐), 소환(연구 부족·재료·칸 상한·같은 종 두 번째·Roll 5..10·+N 반영·Sum), 간식(만들기 3+N·먹이기·주인 아님·최대 레벨·속도), 속도(Roll 기울기·상한), 정적: PetService/PlayerService 줄.

## 6. 검수에게
- 소환 능력치 = 무작위 5..8 + 망치질 +N(최대 10): '실력이 조금 올려 줌'으로 제안(설계 §4는 5~10 무작위만). 숫자 판단 부탁.
- 간식 XP +20, 소환 재료·골드·연구 150(2단계)은 설계 §4 그대로.
