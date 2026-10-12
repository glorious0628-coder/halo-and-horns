# 그림자 점검 — 이미지 생성 4 (2026-10-12)

요청: 최종 검수(사용자 지시 "그림자 있나 없나 살펴보라"). 기준 A23-150: 바닥·드리운·닿는 그림자, AO, 어두운 면 없이 고르게 밝아야 함.
방법: 내가 Tripo에 넣은 2D 4면 87세트(348장)를 직접 봄 — 4면 모아 보기 + 앞면 바닥 가장자리 확대 + 차양·모자 챙·나무 그늘 확대. 바닥 주변 어두워짐 수치(배경 대비)는 참고만. WorldKit은 저장 파일 build/WorldKit.rbxlx(10/12 17:12)에서 색 맵을 셈(창이 닫혀 있어 실시간 조회 못 함).

## 요약
- 2D 입력 87세트: **있음 0 / 약간(진함) 27 / 약간 60 / 없음 0**.
- 87세트 모두 바닥 그림자·닿는 그림자는 **없음**(배경 회색이 물체 아래까지 고름). 하지만 전부 3D 조명 렌더라서 한쪽이 밝고 아랫면·틈이 어두운 **입체 음영과 AO가 있음** → A23-150 기준으로는 전부 '약간' (그림자 없는 판이 아님).
- 진한 것: 차양·선반 아래, 나무 잎 아래, 모자 챙 아래 얼굴/머리, 쇠 무기 한쪽 면.
- 분류별: NPC 약간 6, NPC 약간(진함) 9, 무기 약간 21, 무기 약간(진함) 7, 밈 약간 4, 소품 약간 29, 소품 약간(진함) 11
- 이 87세트로 만든 Tripo GLB(art/models/tripo/web/*_MV4_HD_src.glb 등)는 **WorldKit·게임에 하나도 안 들어감**. 다만 Tripo 색 맵에 이 음영이 같이 구워졌을 것 → A23-150대로 다시 만들 대상.

## WorldKit 안의 색 맵 (build/WorldKit.rbxlx)
- ServerStorage.HaloPropKits (내 파트 키트 58개): 색 맵 **0**, 전부 단색 파트 → **없음**.
- ServerStorage.Parked_Outlines (치운 바깥선 껍데기 6개): 색 맵 0 → 해당 없음.
- Workspace …Props/StandIn 아래 Tripo 대역 4종 (10/10 import, 내 것 아님 — art/models/worldkit/import_halo_town_assets_2026-10-10.json, build/import_all/6_sixth/H3_HaloTown_C.glb): SurfaceAppearance 색 맵 4개, 47곳에서 씀. 색 맵을 직접 열어 봄:
  - Halo_PotFlowers (rbxassetid://79990736574148, 18곳): **있음** — 잎 사이 아주 어두운 구멍·진한 그늘이 구워짐.
  - Halo_RoundTree (127211722211421, 16곳): 약간(진함) — 잎 틈 어두움.
  - Halo_Planter (133399959402080, 7곳): 약간(진함) — 잎 틈·금 테 어두운 면.
  - Halo_Topiary (79548513788959, 6곳): 약간 — 잎 틈 어두움.

## 세트별 (2D 입력)

| 분류 | 이름 | 판정 | 메모 | 앞면 파일 |
|---|---|---|---|---|
| 소품 | HaloVar4_Lantern_C | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/props4/HaloProp4_LanternC_front.png |
| 소품 | HaloVar4_Lantern_A | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/props4/HaloProp4_LanternA_front2.png |
| 소품 | HaloVar4_Lantern_B | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/props4/HaloProp4_LanternB_front2.png |
| 소품 | HaloVar4_Lantern_D | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/props4/HaloProp4_LanternD_front.png |
| 소품 | HaloVar3_Lantern_E | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/props4/HaloProp4_LanternE_front2.png |
| 소품 | HaloFlowerPotHQ_Daisy | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/props4/HaloProp4_PotDaisy_front.png |
| 소품 | HaloFlowerPotHQ_Lavender | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/props4/HaloProp4_PotLavender_front.png |
| 소품 | HaloFlowerPotHQ_Rose | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/props4/HaloProp4_PotRose_front.png |
| 소품 | HaloFlowerPotHQ_Sunflower | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/props4/HaloProp4_PotSunflower_front.png |
| 소품 | HaloFlowerPotHQ_Tulip | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/props4/HaloProp4_PotTulip_front.png |
| 소품 | HaloVar3_Topiary_C | 약간(진함) | 잎 덩이 아래쪽 어두움 | art/out/s2/halo/props4/HaloProp4_TopC_front.png |
| 소품 | HaloVar3_Topiary_D | 약간(진함) | 나선 잎 사이 어두움 | art/out/s2/halo/props4/HaloProp4_TopD_front.png |
| 소품 | HaloVar3_Topiary_E | 약간(진함) | 잎 상자 아랫단 어두움 | art/out/s2/halo/props4/HaloProp4_TopE_front.png |
| 소품 | HaloVar3_RoundTree_E | 약간(진함) | 잎 아래 풀 그늘 | art/out/s2/halo/props4/HaloProp4_TreeE_front.png |
| 소품 | HaloVar3_RoundTree_F | 약간(진함) | 늘어진 잎 안쪽·줄기 둘레 그늘 | art/out/s2/halo/props4/HaloProp4_TreeF_front.png |
| 소품 | HaloVar3_RoundTree_G | 약간(진함) | 잎 아래 풀 그늘 | art/out/s2/halo/props4/HaloProp4_TreeG_front.png |
| 소품 | HaloReasonHQ_BenchB | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/props4/HaloProp4_BenchB_front.png |
| 소품 | HaloReasonHQ_VegGarden | 약간(진함) | 흙·양배추 사이 어두움 | art/out/s2/halo/props4/HaloProp4_ReasonVeg_front.png |
| 소품 | HaloReasonHQ_BreadStand | 약간(진함) | 선반 아래 어두움 | art/out/s2/halo/props4/HaloProp4_ReasonBread_front.png |
| 소품 | HaloReasonHQ_FruitStall | 약간(진함) | 차양 아래 과일 상자 어두움 | art/out/s2/halo/props4/HaloProp4_ReasonFruit_front.png |
| 소품 | HaloReasonHQ_FlowerCart | 약간(진함) | 차양 아래·바퀴 안쪽 어두움 | art/out/s2/halo/props4/HaloProp4_ReasonFlowerCart_front.png |
| 소품 | HaloReasonHQ_PotionCrate | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/props4/HaloProp4_ReasonPotion_front.png |
| 소품 | HaloReasonHQ_Scarecrow | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/props4/HaloProp4_ReasonScare_front.png |
| 소품 | NEW_FlowerBush | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/kits_mv/HaloKit_FlowerBush_front_HQ_src.png |
| 소품 | NEW_GatherBush | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/kits_mv/HaloKit_GatherBush_front_HQ_src.png |
| 소품 | NEW_WallLamp | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/kits_mv/HaloKit_WallLamp_front_HQ_src.png |
| 소품 | NEW_BellFrame_Bell | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo\kits_mv3\HaloKit_BellOnly_front_HQ_src.png |
| 소품 | NEW_WallLamp_Head | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo\kits_mv3\HaloKit_WallLampHead_front.png |
| 소품 | NEW_WateringCan | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo\kits_mv2\HaloKit_WateringCan_front_HQ_src.png |
| 소품 | NEW_BreadBasket | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo\kits_mv2\HaloKit_BreadBasket_front_HQ_src.png |
| 소품 | NEW_Hedge | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo\kits_mv2\HaloKit_Hedge_front_HQ_src.png |
| 소품 | NEW_WhiteRock_a | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo\kits_mv2\HaloKit_WhiteRock_a_front_HQ_src.png |
| 소품 | NEW_WhiteRock_b | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo\kits_mv2\HaloKit_WhiteRock_b_front_HQ_src.png |
| 소품 | NEW_WhiteRock_c | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo\kits_mv2\HaloKit_WhiteRock_c_front_HQ_src.png |
| 소품 | HaloVar4_PotFlowers_A | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/variants4/HaloVar4_PotFlowers_A_HQ_src.png |
| 소품 | HaloVar4_PotFlowers_C | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/variants4/HaloVar4_PotFlowers_C_HQ_src.png |
| 소품 | HaloVar4_PotFlowers_D | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/variants4/HaloVar4_PotFlowers_D_HQ_src.png |
| 소품 | HaloVar3_PotFlowers_E | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/variants/HaloVar3_PotFlowers_E_HQ_src.png |
| 소품 | HaloVar3_PotFlowers_F | 약간(진함) | 늘어진 덩굴 안쪽 어두움 | art/out/s2/halo/variants/HaloVar3_PotFlowers_F_HQ_src.png |
| 소품 | HaloVar4_Planter_D | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/halo/variants4/HaloVar4_Planter_D_HQ_src.png |
| 무기 | Weapon_Halo_Paladin_T1 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Halo_Paladin_T1_front.png |
| 무기 | Weapon_Halo_Paladin_T2 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Halo_Paladin_T2_front.png |
| 무기 | Weapon_Halo_Paladin_T3 | 약간(진함) | 칼날 한쪽 면 진함 | art/out/s2/weapons_t13_4v/Weapon_Halo_Paladin_T3_front.png |
| 무기 | Weapon_Halo_LightMage_T1 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Halo_LightMage_T1_front.png |
| 무기 | Weapon_Halo_LightMage_T2 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Halo_LightMage_T2_front.png |
| 무기 | Weapon_Halo_LightMage_T3 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Halo_LightMage_T3_front.png |
| 무기 | Weapon_Halo_Ranger_T1 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Halo_Ranger_T1_front.png |
| 무기 | Weapon_Halo_Ranger_T2 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Halo_Ranger_T2_front.png |
| 무기 | Weapon_Halo_Ranger_T3 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Halo_Ranger_T3_front.png |
| 무기 | Weapon_Horns_Berserker_T1 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Horns_Berserker_T1_front.png |
| 무기 | Weapon_Horns_Berserker_T2 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Horns_Berserker_T2_front.png |
| 무기 | Weapon_Horns_Berserker_T3 | 약간(진함) | 칼날 한쪽 면 진함 | art/out/s2/weapons_t13_4v/Weapon_Horns_Berserker_T3_front.png |
| 무기 | Weapon_Horns_DarkMage_T1 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Horns_DarkMage_T1_front.png |
| 무기 | Weapon_Horns_DarkMage_T2 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Horns_DarkMage_T2_front.png |
| 무기 | Weapon_Horns_DarkMage_T3 | 약간(진함) | 쇠 장식 한쪽 진함 | art/out/s2/weapons_t13_4v/Weapon_Horns_DarkMage_T3_front.png |
| 무기 | Weapon_Horns_ShadowHunter_T1 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Horns_ShadowHunter_T1_front.png |
| 무기 | Weapon_Horns_ShadowHunter_T2 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Horns_ShadowHunter_T2_front.png |
| 무기 | Weapon_Horns_ShadowHunter_T3 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Horns_ShadowHunter_T3_front.png |
| 무기 | Weapon_Neutral_Blacksmith_T1 | 약간(진함) | 돌 망치 머리 아랫면 진함 | art/out/s2/weapons_t13_4v/Weapon_Neutral_Blacksmith_T1_front.png |
| 무기 | Weapon_Neutral_Blacksmith_T2 | 약간(진함) | 쇠 머리 옆면 진함 | art/out/s2/weapons_t13_4v/Weapon_Neutral_Blacksmith_T2_front.png |
| 무기 | Weapon_Neutral_Blacksmith_T3 | 약간(진함) | 쇠 머리 옆면 진함 | art/out/s2/weapons_t13_4v/Weapon_Neutral_Blacksmith_T3_front.png |
| 무기 | Weapon_Neutral_Alchemist_T1 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Neutral_Alchemist_T1_front.png |
| 무기 | Weapon_Neutral_Alchemist_T2 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Neutral_Alchemist_T2_front.png |
| 무기 | Weapon_Neutral_Alchemist_T3 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Neutral_Alchemist_T3_front.png |
| 무기 | Weapon_Neutral_PetTamer_T1 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Neutral_PetTamer_T1_front.png |
| 무기 | Weapon_Neutral_PetTamer_T2 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Neutral_PetTamer_T2_front.png |
| 무기 | Weapon_Neutral_PetTamer_T3 | 약간(진함) | 쇠 공 아랫면 진함 | art/out/s2/weapons_t13_4v/Weapon_Neutral_PetTamer_T3_front.png |
| 무기 | Weapon_Horns_Berserker_final_b | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/weapons_t13_4v/Weapon_Horns_Berserker_final_b_front.png |
| NPC | NPC_HaloBright | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/npc/NPC_HaloBright_A_src.png |
| NPC | NPC_HaloSirGleam | 약간(진함) | 투구 안 얼굴 그늘·망토 안쪽 | art/out/s2/npc/NPC_HaloSirGleam_A_src.png |
| NPC | NPC_HaloBakerGranny | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/npc/NPC_HaloBakerGranny_A_src.png |
| NPC | NPC_HaloFlowerGirl | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/npc/NPC_HaloFlowerGirl_C_src.png |
| NPC | NPC_HaloJuiceMan | 약간(진함) | 모자 챙 아래 머리카락 그늘 | art/out/s2/npc/NPC_HaloJuiceMan_A_src.png |
| NPC | NPC_HaloPotionMerchant | 약간(진함) | 가방 아래·코트 주름 그늘 | art/out/s2/npc/NPC_HaloPotionMerchant_front_HQ_src.png |
| NPC | NPC_HaloBellElder | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/npc2_hq/NPC_HaloBellElder_front_HQ_src.png |
| NPC | NPC_HaloFlowerFarmer | 약간(진함) | 모자 챙 아래 그늘 | art/out/s2/npc2_hq/NPC_HaloFlowerFarmer_front_HQ_src.png |
| NPC | NPC_HaloFolk4 | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/npc2_hq/NPC_HaloFolk4_front_HQ_src.png |
| NPC | NPC_HaloHerbHusband | 약간(진함) | 모자 챙 아래 그늘 | art/out/s2/npc2_hq/NPC_HaloHerbHusband_front_HQ_src.png |
| NPC | NPC_HaloHerbWife | 약간(진함) | 바구니 안 그늘 | art/out/s2/npc2_hq/NPC_HaloHerbWife_front_HQ_src.png |
| NPC | NPC_HaloMailBoy | 약간(진함) | 모자 챙 아래 그늘 | art/out/s2/npc2_hq/NPC_HaloMailBoy_front_HQ_src.png |
| NPC | NPC_HaloOldSailor | 약간(진함) | 모자 챙 아래 그늘 | art/out/s2/npc2_hq/NPC_HaloOldSailor_front_HQ_src.png |
| NPC | NPC_HaloPondAngler | 약간(진함) | 모자 챙 아래 진한 띠 | art/out/s2/npc2_hq/NPC_HaloPondAngler_front_HQ_src.png |
| NPC | NPC_HaloStarScholar | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/npc2_hq/NPC_HaloStarScholar_front_HQ_src.png |
| 밈 | Meme_PixelHalo | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/memes_4v/Meme_PixelHalo_front_HQ.png |
| 밈 | Meme_PixelHorns | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/memes_4v/Meme_PixelHorns_front_HQ.png |
| 밈 | Meme_DonutHalo | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/memes_4v/Meme_DonutHalo_front_HQ.png |
| 밈 | Meme_TwistHorns | 약간 | 바닥 그림자 없음, 입체 음영·틈 어두움만 | art/out/s2/memes_4v/Meme_TwistHorns_front_HQ.png |
