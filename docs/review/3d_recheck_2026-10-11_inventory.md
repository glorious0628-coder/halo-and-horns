# 3D 다시 검수 — 1단계 목록 (2026-10-11, SPEC A23-122)

검수가 하나씩 판정할 수 있게, 지금 쓰거나 쓸 3D를 모았다. 판정(통과/다시)은 아직 안 했다. 자세한 값은 `docs/review/3d_recheck_2026-10-11_inventory.json`(287개, 필드 설명은 맨 아래).

- 기준 파일: `art/models/tripo/records.json`, 메인 `place/GoodEvil.rbxlx`(10/10 20:12 저장), `build/WorldKit.rbxlx`(10/11 10:52 저장), 메시 id 장부 `art/models/worldkit/import*_assets*.json`·`art/models/new_asset_ids.json`, `art/models/tripo/import_now/`, `tools/halo_props_list.txt`, `docs/design/halo_restart_2026-10-11.md`, `docs/handoff/state/img1.md`·`img3.md`, `art/review/**`.
- **모두 287개**: 메인에 쓰임 106, 메인엔 없고 빛 마을 v2 재료 98, 나머지 83. (records 키 기준 + 기록 없는 GoldenGoose 1 + 색만 바꾼 복사본 3: Kit_X_StallBlue·StallGreen·X_SupporterBoard.)
- **메인에 쓰이는 106개**: 앞면 한 장 89 · 여러 장 13(그중 앞·뒤·좌·우 4장은 6) · 모름 4.
- **빛 마을 v2에 쓸 100개**(메인과 겹치는 2개 포함: Halo_Statue, Town_Halo_Fountain3): 앞면 한 장 56 · 여러 장 44(그중 4장 36) · 모름 0.
- **A23-120 골격 후보**(Tripo 대신 Studio 파트로): 98개 + 화분 몸통만 골격 15개. 메인에 있는 것 14개, v2 재료 45개.

표기: `앞1` 앞면 한 장 · `옆1` 옆 한 장 · `3/4 1장` 비스듬한 한 장 · `4면` 앞·뒤·좌·우(A23-122 규칙에 맞음) · `4면(추정)` records에 장수가 없어 2D 파일 4장이 있는 것으로 추정 · `앞뒤`/`앞옆뒤` 여러 장이지만 4장 아님 · `모름` 생성 기록 없음 · `[골격]` A23-120 골격 후보 · `[몸통만 골격]` 화분·상자 몸통만 골격, 식물은 Tripo.

## 1. 구역 × 쓰임 × 입력 장수

| 구역 | 메인: 앞1장 | 메인: 여러 장 | 메인: 모름 | v2 재료: 앞1장 | v2 재료: 여러 장 | 나머지: 앞1장 | 나머지: 여러 장 | 합계 |
|---|---|---|---|---|---|---|---|---|
| 빛 마을 | 12 | 8 | 0 | 55 | 43 | 17 | 0 | 135 |
| 뿔 마을 | 0 | 1 | 0 | 0 | 0 | 17 | 0 | 18 |
| 교차로 | 20 | 0 | 0 | 0 | 0 | 14 | 0 | 34 |
| 초원 | 15 | 1 | 0 | 0 | 0 | 3 | 0 | 19 |
| 고블린 숲 | 25 | 0 | 0 | 0 | 0 | 4 | 1 | 30 |
| 할로윈(호박밭·유령 숲) | 0 | 0 | 0 | 0 | 0 | 16 | 0 | 16 |
| 폐허 | 0 | 0 | 0 | 0 | 0 | 8 | 0 | 8 |
| 왕관 | 2 | 0 | 0 | 0 | 0 | 0 | 2 | 4 |
| 몬스터·펫 | 9 | 3 | 4 | 0 | 0 | 1 | 0 | 17 |
| 기타(계급 장식) | 6 | 0 | 0 | 0 | 0 | 0 | 0 | 6 |
| **합계** | 89 | 13 | 4 | 55 | 43 | 80 | 3 | 287 |

쓰임 뜻: 메인 = 메인 Workspace에 놓였거나 게임이 읽는 폴더(ServerStorage/CustomModels·MarkModels)에 있음. v2 재료 = 빛 마을 다시 짓기 5단계에서 다시 쓸 Tripo 조각(집·가게 parts, 대성당·성문·탑 부품, 소품 57종, NPC 5) + 고정점(분수·영웅상). 나머지 = WorldKit에만, 메인 ServerStorage 창고에만, 또는 GLB만.

## 2. 메인에 쓰이는 것 (먼저 볼 것)

- **빛 마을 (20)**: Halo_ArchBridge 앞뒤 [골격], Halo_Balustrade 앞1 [골격], Halo_BannerPole 앞1 [골격], Halo_Cathedral 4면 [골격], Halo_CloudBush 앞1, Halo_DomeHouseA 4면 [골격], Halo_DomeHouseB 4면 [골격], Halo_FarArch 앞1, Halo_Gate 4면 [골격], Halo_Islet 앞1, Halo_Lantern 앞1, Halo_Planter 앞1 [몸통만 골격], Halo_PotFlowers 앞1 [몸통만 골격], Halo_RoundTree 앞1, Halo_Shop 4면 [골격], Halo_Stairs 앞1 [골격], Halo_Statue 앞뒤, Halo_Topiary 앞1, Halo_Tower 4면 [골격], Town_Halo_Fountain3 앞1
- **뿔 마을 (1)**: Town_Horns_Castle_v6mv 앞뒤 [골격]
- **교차로 (20)**: Kit_X_Anvil 앞1, Kit_X_BannerHalo 앞1, Kit_X_BannerHorns 앞1, Kit_X_Bench 앞1, Kit_X_Brazier 앞1, Kit_X_Curb 앞1 [골격], Kit_X_Forge 앞1, Kit_X_Lamp 앞1, Kit_X_PotionCart 앞1, Kit_X_StallBlue 앞1, Kit_X_StallGreen 앞1, Kit_X_StallRed 앞1, Town_Halo_Fountain 앞1, X_Altar 앞1, X_GooseNest 앞1, X_GuildHall 앞1 [골격], X_MarketArch 앞1, X_NoticeBoard 앞1, X_PadBase 앞1 [골격], X_SupporterBoard 앞1
- **초원 (16)**: Kit_M_BushA 앞1, Kit_M_BushB 앞1, Kit_M_CrownShrine 앞옆뒤, Kit_M_CrystalPile 앞1, Kit_M_Fence 앞1, Kit_M_FlowerCart 앞1, Kit_M_FlowersA 앞1, Kit_M_FlowersB 앞1, Kit_M_JellyRock 앞1, Kit_M_LogBench 앞1, Kit_M_Mushrooms 앞1, Kit_M_PicnicBasket 앞1, Kit_M_Pinwheel 앞1, Kit_M_PuddleRim 앞1, Kit_M_SignPost 앞1, Kit_M_Stump 앞1
- **고블린 숲 (25)**: Kit_W_Banner 앞1, Kit_W_BushA 앞1, Kit_W_BushB 앞1, Kit_W_CampFence 앞1, Kit_W_Campfire_Fire 앞1, Kit_W_Crates 앞1, Kit_W_FallenLog 앞1, Kit_W_Fern 앞1, Kit_W_LanternPost 앞1, Kit_W_LogStool 앞1, Kit_W_LootSack 앞1, Kit_W_MossRock 앞1, Kit_W_Mushrooms 앞1, Kit_W_SignPost 앞1, Kit_W_StepStones 앞1, Kit_W_Stump 앞1, W_Boulder_A 앞1, W_Boulder_B 앞1, W_GiantTree 앞1, W_Tent_A 앞1, W_Tent_B 앞1, W_Totem 앞1, W_Tree_A 앞1, W_Tree_B 앞1, W_Tree_C 앞1
- **왕관 (2)**: Crown_Broken_B 앞1, K_CrownShard_v2 앞1
- **몬스터·펫 (16)**: BatGoblin 앞1, GhostKing 앞1, GhostMinion 앞1, Goblin 모름, GoblinBrute 모름, GoldenGoose 모름, LittleGhost 앞1, PetBabySlime 앞1, PumpkinKing 앞1, PumpkinSlime 앞1, Skeleton 앞1, SkeletonArcher 앞뒤, SkeletonKnight 모름, Slime / BigSlime (SlimeCube) 앞1, SlimeKing (King Slime) 앞옆뒤, SlingshotGoblin 앞뒤
- **기타(계급 장식) (6)**: Acc_HaloR3 3/4 1장, Acc_HaloR4 3/4 1장, Acc_HaloR5 3/4 1장, Acc_HornsR3 3/4 1장, Acc_HornsR4 3/4 1장, Acc_HornsR5 3/4 1장

메모
- 빛 마을 메인 키트(Halo_* 20개, 10/10)는 새 빛 마을이 들어가면(A23-121 6단계) 바뀐다. 그래도 지금 화면에 보이므로 목록에 넣었다.
- 몬스터: Slime·BigSlime·Flower Slime은 같은 SlimeCube 메시 하나를 쓴다(한 줄로 셈). 호박밭·유령 숲 몬스터 5종은 구역이 숨겨져 있다(A23-119).
- Kit_X_StallBlue·StallGreen·X_SupporterBoard는 원본(StallRed·NoticeBoard)의 색만 바꾼 것 → A23-96에 따라 자기 모델이 필요.
- 손으로 고친 모델(remake_list P2): Kit_M_SignPost(속 채움), Kit_W_JobBoard(구멍 메움), Kit_M_CrownShrine(윗면 덮음), Crown_Broken_B(뒷면 다시 칠함), Kit_W_CampFence(끝 칠함).

## 3. 빛 마을 v2 재료 (메인엔 아직 없음)

- **집 12·가게 4 (멀티뷰 parts, import_now) — 16개**: HaloDomeHouse_01 4면 [골격], HaloDomeHouse_02 4면 [골격], HaloDomeHouse_03 4면 [골격], HaloDomeHouse_04 4면 [골격], HaloDomeHouse_05 4면 [골격], HaloDomeHouse_06 4면 [골격], HaloDomeHouse_07 4면 [골격], HaloDomeHouse_08 4면 [골격], HaloDomeHouse_09 4면 [골격], HaloDomeHouse_10 4면 [골격], HaloDomeHouse_11 4면 [골격], HaloDomeHouse_12 4면 [골격], HaloShop_Bakery 4면 [골격], HaloShop_Flower 4면 [골격], HaloShop_Juice 4면 [골격], HaloShop_Potion 4면 [골격]
- **대성당·성문·탑 부품 (HaloPart, 조립본 Cath_Assembled_v2·Gate_Assembled_v3·TowerA/B/C_Assembled가 import_now에 있음) — 21개**: HaloPart_CathBody 4면 [골격], HaloPart_CathDome 4면, HaloPart_CathDoorFrame 4면(추정) [골격], HaloPart_CathDoorLeaf 앞뒤, HaloPart_CathStairs 4면(추정) [골격], HaloPart_CathTowerA 4면 [골격], HaloPart_CathTowerB 4면 [골격], HaloPart_CathWindow 앞뒤, HaloPart_GateArch 4면(추정) [골격], HaloPart_GateDomeL 4면(추정), HaloPart_GateDomeR 4면(추정), HaloPart_GateDoorLeafL 앞뒤, HaloPart_GateDoorLeafR 앞뒤, HaloPart_GateLantern 4면, HaloPart_GateTowerL 4칸(잘못 넣음) [골격], HaloPart_GateTowerR 4면(추정) [골격], HaloPart_TowerBody 4면(추정) [골격], HaloPart_TowerDome 4면, HaloPart_TowerDoorFrame 4면 [골격], HaloPart_TowerDoorLeaf 앞뒤, HaloPart_TowerWindow 앞뒤
- **NPC 5 (WorldKit HaloNPCTest) — 5개**: NPC_HaloBakerGranny 4면, NPC_HaloBright 4면, NPC_HaloFlowerGirl 4면, NPC_HaloJuiceMan 4면, NPC_HaloSirGleam 4면
- **소품 57종 중 계획에 남은 것 (prop_build parts, 디스크만; img3 시트 아직 검수에 안 보냄) — 55개**: HaloBridge_1 옆1 [골격], HaloBridge_2 옆1 [골격], HaloBridge_3 옆1 [골격], HaloFlagpole_1 앞1 [골격], HaloFlagpole_2 앞1 [골격], HaloFlagpole_3 앞1 [골격], HaloFlowerPotHQ_Daisy 앞1 [몸통만 골격], HaloFlowerPotHQ_Lavender 앞1 [몸통만 골격], HaloFlowerPotHQ_Rose 앞1 [몸통만 골격], HaloFlowerPotHQ_Sunflower 앞1 [몸통만 골격], HaloFlowerPotHQ_Tulip 앞1 [몸통만 골격], HaloReasonHQ_BenchA 앞1, HaloReasonHQ_BenchB 앞1, HaloReasonHQ_BenchC 앞1, HaloReasonHQ_BreadStand 앞1, HaloReasonHQ_Clothesline 앞1, HaloReasonHQ_FlowerCart 앞1, HaloReasonHQ_FruitStall 앞1, HaloReasonHQ_GuardPost 앞1, HaloReasonHQ_PhotoDisc 앞1 [골격], HaloReasonHQ_PotionCrate 앞1, HaloReasonHQ_RackShieldSword 앞1, HaloReasonHQ_Scarecrow 앞1, HaloReasonHQ_VegGarden 앞1, HaloReasonHQ_Woodpile 앞1, HaloStairs_1 앞1 [골격], HaloStairs_2 앞1 [골격], HaloStairs_3 앞1 [골격], HaloStairs_4 앞1 [골격], HaloStairs_5 앞1 [골격], HaloVar3_Balustrade_E 앞1 [골격], HaloVar3_Balustrade_F 앞1 [골격], HaloVar3_Lantern_E 앞1, HaloVar3_Planter_E 앞1 [몸통만 골격], HaloVar3_PotFlowers_E 앞1 [몸통만 골격], HaloVar3_PotFlowers_F 앞1 [몸통만 골격], HaloVar3_RoundTree_E 앞1, HaloVar3_RoundTree_F 앞1, HaloVar3_RoundTree_G 앞1, HaloVar3_Topiary_C 앞1, HaloVar3_Topiary_D 앞1, HaloVar3_Topiary_E 앞1, HaloVar4_Balustrade_A 앞1 [골격], HaloVar4_Balustrade_B 앞1 [골격], HaloVar4_Balustrade_C 앞1 [골격], HaloVar4_Balustrade_D 앞1 [골격], HaloVar4_Lantern_A 앞1, HaloVar4_Lantern_B 앞1, HaloVar4_Lantern_C 앞1, HaloVar4_Lantern_D 앞1, HaloVar4_Planter_A 앞1 [몸통만 골격], HaloVar4_Planter_D 앞1 [몸통만 골격], HaloVar4_PotFlowers_A 앞1 [몸통만 골격], HaloVar4_PotFlowers_C 앞1 [몸통만 골격], HaloVar4_PotFlowers_D 앞1 [몸통만 골격]
- **그 밖 — 1개**: Halo_Tower_v2 4면(추정) [골격]
- 구름 덤불 HaloVar3_CloudBush_E·F는 사용자 "뭉탱이"(10/11)로 계획에서 빠짐(보류). 나머지 칸에 셈.

## 4. 나머지 (메인에도 v2 계획에도 없음)

### WorldKit에 있음(메인 ServerStorage/WorldKit3D 창고에도 있는 것 포함) — 62개
- 빛 마을: Town_Halo_Bakery 앞1 [골격], Town_Halo_Bridge 앞1 [골격], Town_Halo_Castle 앞1 [골격], Town_Halo_HouseA 앞1 [골격], Town_Halo_HouseB 앞1 [골격], Town_Halo_HouseC 앞1 [골격], Town_Halo_JuiceBar 앞1 [골격], Town_Halo_KnightStatue 앞1, Town_Halo_Potion 앞1 [골격], Town_Halo_Smithy 앞1 [골격], Town_Halo_WallTower 앞1 [골격]
- 뿔 마을: Town_Horns_Bakery 앞1 [골격], Town_Horns_Brazier 앞1, Town_Horns_Bridge 앞1 [골격], Town_Horns_Castle (v3) 앞1 [골격], Town_Horns_HouseA 앞1 [골격], Town_Horns_HouseB 앞1 [골격], Town_Horns_HouseC 앞1 [골격], Town_Horns_JuiceBar 앞1 [골격], Town_Horns_Potion 앞1 [골격], Town_Horns_Smithy 앞1 [골격], Town_Horns_SpikeRock 앞1, Town_Horns_WallTower 앞1 [골격]
- 교차로: Kit_X_Barrel 앞1, Kit_X_Bush 앞1, Kit_X_Crate 앞1, Kit_X_Fence 앞1, Kit_X_FlowerPot 앞1, Kit_X_FruitCart 앞1, Kit_X_PlazaStairs 앞1 [골격], Kit_X_PlazaWall 앞1 [골격], X_HouseA 앞1 [골격], X_HouseB 앞1 [골격], X_TreeB 앞1
- 초원: Kit_M_JobBoard 앞1, Kit_M_MeadowArch 앞1
- 고블린 숲: Kit_W_Awning 앞1, Kit_W_JobBoard 앞1
- 할로윈(호박밭·유령 숲): H_TreeArch 앞1, H_TreeTwisted 앞1, H_Willow 앞1, Kit_H_GlowShrooms 앞1, Kit_H_LanternPost 앞1, Kit_H_StumpTable 앞1, Kit_P_EntranceSign 앞1, Kit_P_HayBales 앞1, Kit_P_PumpkinCart 앞1, Kit_P_PumpkinCluster 앞1, Kit_P_Sunflowers 앞1, P_Cliff_A 앞1, P_Cliff_B 앞1, P_Pine 앞1, P_TreeAutumn_A 앞1, P_TreeAutumn_B 앞1
- 폐허: Kit_R_Banner 앞1, Kit_R_PillarA 앞1 [골격], Kit_R_PillarB 앞1 [골격], Kit_R_SpiritBowl 앞1, Kit_R_StoneMarker 앞1, R_Arch_A 앞1, R_Arch_B 앞1, R_Gate 앞1 [골격]

### 메인 ServerStorage 창고에만 — 15개
- 빛 마을: Town_Halo_Gate 앞1 [골격], Town_Halo_Spawn 앞1 [골격], Town_Halo_Tree 앞1, Town_Halo_Wall 앞1 [골격]
- 뿔 마을: Town_Horns_Castle_v4 앞1 [골격], Town_Horns_Gate 앞1 [골격], Town_Horns_Spawn 앞1 [골격], Town_Horns_Tree 앞1, Town_Horns_Wall 앞1 [골격]
- 교차로: X_Fountain 앞1, X_SpawnPlaza 앞1 [골격], X_TreeA 앞1
- 초원: Kit_M_Bridge 앞1 [골격]
- 고블린 숲: W_BridgeWood 앞1 [골격], W_Gate 앞1 [골격]

### GLB만(어느 place에도 없음) — 4개
- 고블린 숲: W_GateOpen 앞뒤 [골격]
- 왕관: Crown_GoldHalf 4면(추정), Crown_RedHalf 4면(추정)
- 몬스터·펫: SkeletonKing 앞1

### 보류(parts만 디스크) — 2개
- 빛 마을: HaloVar3_CloudBush_E 앞1, HaloVar3_CloudBush_F 앞1

## 5. 은퇴·건너뜀 (JSON에 안 넣음)

- **Costume_* 30개 키**(치비 의상, 2026-10-05 게임에서 뺌; 기본 18 + 합치기·2k 시험 키 12). 파일은 디스크에 그대로.
- `art/out/v1` 아래 것만으로 된 3D: 0개(records에 없음).
- **건너뛴 records 키 24개**
  - `MonsterGoblin_src` — 가져오기 기록만 → Goblin 줄에 합침
  - `MonsterGoblinBrute_src` — 가져오기 기록만 → GoblinBrute 줄에 합침
  - `MonsterSkeleton_src` — 가져오기 기록만 → Skeleton(SkeletonClothed) 줄에 합침
  - `MonsterSkeleton` — 리그·애니메이션 기록 → Skeleton 줄에 합침
  - `MonsterSkeletonKnight_src` — 가져오기 기록만 → SkeletonKnight 줄에 합침
  - `MonsterBatGoblin_src` — 가져오기 기록만 → BatGoblin 줄에 합침
  - `Bakery_tripoP1` — 도구 비교용 P1 모델, 안 씀
  - `Town_Horns_Castle` — API 묶음 2 뿔 성, v3/v4/v6mv로 바뀜
  - `_balance_log` — 크레딧 잔액 메모(모델 아님)
  - `Kit_W_Campfire` — Kit_W_Campfire_Fire로 바뀜
  - `W_Tree_C3k` — W_Tree_C 3천 면 재시도, 안 씀
  - `Town_Halo_Fountain_web_smart` — Smart Mesh 시험, GLB 안 받음
  - `Town_Horns_Brazier_web_smart` — Smart Mesh 시험, GLB 안 받음
  - `web_account1_unrecorded_2026-10-07` — 사용 내역 메모(실패한 글→3D 시도), 모델 아님
  - `Town_Horns_Castle_nowin_web_hd` — 뿔 성 HD 시험, v6mv로 바뀜(GLB만)
  - `Town_Horns_Castle_v4_web_hd` — 뿔 성 v4 HD(189만 면), v6mv로 바뀜(GLB만)
  - `Kit_W_Banner_web_hd` — 숲 깃발 v1 '+' 모양, Kit_W_Banner_T로 바뀜
  - `Halo_Statue_web_hd` — 4면 v1(창이 하나 더 생김), Halo_Statue_v2로 바뀜
  - `Halo_CloudBush_web_hd` — v1 → v2로 바뀜
  - `Halo_Planter_web_hd` — poly 3000 v1이 부서져 v2로 바뀜
  - `Halo_PotFlowers_web_hd` — v1 → v2로 바뀜
  - `Halo_Topiary_web_hd` — v1 → v2로 바뀜
  - `Halo_RoundTree_web_hd` — v1 → v2로 바뀜
  - `HaloDomeHouse_01_web_hd_try1` — 옆 칸을 바꿔 넣은 첫 시험, 버림(파일 없음)

## 6. Tripo가 아닌 3D (메인에 있지만 이 목록 밖)

- Acc_HaloR1·R2, Acc_HornsR1·R2: Blender로 만든 계급 장식(remake_list P3에서 Tripo로 다시).
- KingCrown(BigSlime 머리 왕관): Blender `tools/img2/slime_crown.py`.
- HauntedHollow GF_* 6종 20개(GF_Tree 7·Mushrooms 4·Lantern 3·Rock 3·Willow 2·Arch 1): Studio generate_mesh 임시 모델, 원본 GLB 없음 → H_*·Kit_H_* Tripo로 바꿀 예정.
- PotionMerchant(Fizzby) 등 마을 NPC: HumanoidDescription R15(remake_list P4).
- 메인 ServerStorage KitStage·CrossroadsKOld의 K_* (generate_mesh 옛 교차로 키트, 창고만).

## 7. 알 수 없었던 것

1. **Goblin, GoblinBrute, SkeletonKnight, GoldenGoose**: 10/02~03 옛 계정 때 만들어 records에 생성 기록이 없다(가져오기·리그만). 입력 장수 = 모름(아마 한 장). 2D 원본도 10/06 정리 때 지워짐. Skeleton(SkeletonClothed)·SkeletonKing의 2D도 디스크에 없다.
2. **장수가 records에 안 적힌 멀티뷰**: HaloPart_GateTowerR·GateDomeL·GateDomeR·GateArch·CathStairs·CathDoorFrame·TowerBody, Halo_Tower_v2, Crown_GoldHalf·RedHalf → mode가 "HD multi-view"뿐이라 `art/out`에 있는 2D가 4장이어서 4면으로 **추정**했다(`views`에 "inferred" 표시).
3. **HaloPart_GateTowerL**: records 메모에 "4칸이 섞임(앞 칸에 왼쪽 그림, 뒤 칸 빔)". 사실상 4면이 아니다.
4. **WorldKit 저장 파일이 오래됨**: `build/WorldKit.rbxlx`(10/11 10:52)에 state 문서가 말하는 ServerStorage.ImportHold 22개와 Workspace.SkeletonTest가 없다. 그래서 집·가게·조립본은 `import_now` 폴더 + state/img1.md로 "import_hold"라고 적었다. 열려 있는 WorldKit Studio는 확인하지 않았다(이번 일은 Studio MCP 금지).
5. **메인은 저장 파일 기준**: `place/GoodEvil.rbxlx`(10/10 20:12). 그 뒤 메인 Studio에서 바뀐 것은 반영 안 됨.
6. **이름으로만 맞춘 것**: CustomModels의 BatGoblin·GhostKing·GhostMinion·LittleGhost·PetBabySlime·PumpkinKing·PumpkinSlime·Skeleton, X_SupporterBoard — 메시 id가 가져오기 장부에 없어서 이름으로만 맞췄다(`match: name`).
7. **X_SupporterBoard**: 따로 된 GLB가 없다(Studio에서 텍스처만 바꾼 NoticeBoard로 보임). tris 없음.
8. **Halo_Tower_v2, Crown_GoldHalf·RedHalf, W_GateOpen**: GLB와 가져오기 묶음(H7_CrownTower.glb, E9_GoblinGateOpen.glb)은 있지만 저장된 메인·WorldKit에 없다. TowerA/B/C_Assembled가 Tower_v2로 만든 것인지 HaloPart_Tower*로 만든 것인지 확인 못 함.
9. **v2 재료 판정**: `halo_plan_v2_2026-10-11.json`은 건물 자리·크기만 있고 모델 이름이 없다. `halo_restart` 문서의 규칙("Tripo 조각은 5단계 입히기에서 다시 씀", 고정점 분수·영웅상·NPC)으로 판단했다. 소품 하나하나를 실제로 쓸지는 아직 안 정해졌다.
10. **시트**: 옛 모델 대부분은 묶음 시트뿐이다(`(group sheet)` 표시). 몬스터 옛 모델은 뒷면 검사 시트뿐. SkeletonKing은 시트가 없다. 3b 묶음(WallTower·HouseC·Bridge·X_Altar 등)은 텍스처 시트 3장 중 어느 것인지 나누지 못했다.
11. **tris**: 게임에 들어간 판(LOD·parts·plain GLB)에서 센 숫자다. Tripo가 처음 만든 숫자가 다르면 notes에 적었다.

## JSON 필드

`name` 게임·키트 이름 · `records_key` records.json 키(없으면 null) · `zone` · `kind` · `inputs` single_front/multiview/unknown · `views` 실제 장수 · `inputs_evidence` 근거(records의 mode/image/images/inputs 원문) · `image_2d`(+`image_2d_exists`) · `glb`(+`glb_exists`, 게임에 들어간 판에 가까운 파일) · `tris`(+`tris_source`) · `used_in` main/main_storage/worldkit/import_hold/built_parts_only/planned_halo_v2/on_hold/glb_only · `where` 어느 폴더에 몇 개 · `match` asset_id(메시 id 일치)/name/none · `sheet`(+`sheets_all`) · `made_at` · `notes`(A23-120 골격 후보, 4장 아님, 손으로 고친 것 등).
