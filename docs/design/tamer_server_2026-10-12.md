# 조련사 연구·소환·간식 서버 (게임성 개발 3, 2026-10-12, 설계 + 구현(합의됨, §7))

근거: `crafting_market_2026-10-11.md` §4 조련사(연구력 = 조련사가 잡은 몬스터 가족마다 1점, 단계 50/150/400/1000/2500, 소환 = 연구 2단계 + 재료 → 그 가족 펫·능력치 게임 안 랜덤·로벅스 없음, 베타는 3D가 있는 슬라임 가족만, Pet Treat = 펫 XP +20·거래 가능·펫은 못 팖), A23-115·A23-127(조련사 = 펫 쪽)·A23-133(펫 장비도 장인 — ⑥)·A23-139(제작 XP 패스 2배·장인만), `save_v4_tables`(Research {Pts, Sum}, Pets.List[uid].Roll {Spd 5..10}), `craft_server_2026-10-12.md`(레시피 표·망치질). 스위치: Config.Features.Crafting(소환·간식 레시피)·새 `Config.Features.Research`(연구 세기, 장인 길드와 같이 켬).

## 1. 연구력 (TamerService, 새 서버 모듈 — 개발 3)
- 조련사(`Config.IsTamer(class, faction)`, 직업 고른 뒤)가 돈 받는 처치(`MonsterKilled`, MinorShare 아님)마다 `Research.Pts[가족] += 1`. 가족 = `Config.MonsterFamily(kind)` = `Config.Research.Family` 표(왕자·꽃슬라임·킹 → Slime, 고블린 3종 → Goblin, 해골 4종 → Skeleton, 유령 3종 → Ghost), 없으면 `Config.QuestKind`(호박 슬라임 = Slime, 소라게 = CoralCrab). QuestKind만 쓰면 왕자·킹이 따로 세져서 표를 더함. 자동 전투 처치도 셈(펫이 대신 싸우는 직업, A23-39). 가족 64개·점수 1e7 상한(save v4).
- 단계 = `Config.Research.Stages = { 50, 150, 400, 1000, 2500 }`(`Config.ResearchStage(pts)`). 새 단계 = 알림 키 `Config.Research.Text.Stage`(args: 가족 이름 키, 단계) 한 번 + 신호 `StageUp(player, family, stage)`. s->c `TamerInfo { Pts, Stage, Sum, Stages }`(들어올 때·바뀔 때 1초에 1번까지, 새 단계·소환은 바로).
- **됨(2026-10-12, 이 가지):** `TamerService.luau`, `tools/test_tamer_research.py`(52 확인·변이 26/26).

## 2. 소환 = 제작 레시피 `Kind = "Pet"` (CraftService — 개발 3)
- `S1 = { Role = "Tame", Kind = "Pet", Family = "Slime", Species = "BabySlime", Research = 150, Lv = 1, Gold = 100, Mats = { Jelly = 30, SlimeCore = 5 }, XP = 40 }`.
- 시작 검사에 더함: `Research.Pts[Family] ≥ Research`(아니면 알림 키 `NeedResearch`), 펫 칸 여유(PetService 상한 64).
- 끝: 능력치 `Spd = 서버 무작위 5..8 + 망치질 +N`(최대 10, 로벅스·뽑기 없음 — 실력이 조금 올려 줌) → **PetService.SummonPet(player, species, { Spd })** → `Research.Sum[Family] += 1`.

## 3. 펫 간식 Pet Treat
- 레시피 `T1 = { Role = "Tame", Kind = "Item", Item = "PetTreat", N = 3, Lv = 1, Gold = 10, Mats = { Jelly = 5, Petal = 2 }, XP = 10 }`(crafting_market §4 그대로; 채집 설계 §1은 '간식 = 약초' 방향이라 Petal 대신 Herb 2도 가능 — 검수 판단)(3 + 망치질 +N개). 아이템 `PetTreat`: Kind "Treat", Source "Craft"(오토 한 번에 팔기 제외, 거래소 대상).
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
- 간식 재료: Jelly 5 + Petal 2(설계 §4) 또는 Jelly 5 + Herb 2(채집 설계 방향). 답 없으면 설계 §4대로.

## 7. 합의·결정 (2026-10-12) — 됨
- **게임성 검수:** 소환 속도 = 무작위 5~8%(정수) + 망치질 +0/+1/+2, 최대 10% — 그대로 넣음(`S1.Spd = { 5, 8 }`, `Config.SaveV4.PetRollSpd[2]` 상한). 행운 물약 = Source 없는 몬스터 재료 줄만(보스·채집·제작 제외).
- **게임성 개발 2:** PetService 4개는 개발 3이 넣고 개발 2가 읽어 확인. 맞춘 모양: 새 펫 줄은 `addPet` 한 곳(grant·SummonPet 같이 씀), 64마리는 넣기 **전에** 막음(HasRoom), 거절 = nil(모르는 종·`sanitizeRoll` 실패·64), XP 고리는 `giveXP(p, n)`(onKilled는 거르기만), `AddPetXP(uid, n)` = 내 펫 + 정수 > 0만, 최대 레벨이면 그대로 레벨 반환, `PetRoll` 속성 → `Config.WalkSpeed(..., petRoll)` → `PetSpeedBonus(sp, lv, roll)`(Lv1 roll%, MaxLv roll% + `Config.Pets.RollGrow` 0.03, roll 0/nil = 옛 줄), `PetList` 줄에 `Roll`.
- 간식 재료 = **Jelly 5 + Herb 2**(게임성 검수 10/12: 채집 → 제작 고리, Petal은 사냥만으로 다 되는 걸 피함). Herb가 없으면 레시피 꺼짐 규칙 그대로.
- **남은 클라 몫(개발 4·1):** PetWindow 82·101줄 `Config.PetSpeedBonus(sp, lv)`에 Roll(`p.Roll and p.Roll.Spd`, 따라오는 펫은 `PetRoll` 속성)을 넘겨야 창 숫자가 맞음. 연구 창(TamerInfo), 소환 결과(CraftResult.Pet), 간식 주기 버튼(FeedPet).
- 시험: test_tamer_research(연구·소환 펫·펫 XP·간식) / test_craft(S1·T1, 대역) / test_pet_speed(roll) / test_alchemy(보스 재료) / test_tamer·test_gamepass 패턴 맞춤.
