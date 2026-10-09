# Remake list — every reused / recoloured / placeholder asset gets its own (2026-10-09)

User 2026-10-09: "기존 것 재활용하지 말구 TRIPO 써도 돼! 왜 아끼니" → "지금있는 것들 중에서 재활용한 것 있으면 싹 다 새로 만들어!" → "우리는 퀄리티가 중요해. 없는 살림이지만 ㅋㅋ" (SPEC A23-96).
Inventory: 검수 sweep of `src/` + `build/GoodEvil.rbxlx` (saved 10/09 12:56). Line numbers drift; search by name.

Pipeline for every 3D item: Firefly **High** multiview (front + side + back; back has no face) by 이미지 생성 2 (world props: 이미지 생성 1) → Tripo web 25,000-pt account HD by 이미지 생성 1 → Blender front/back render vs the 2D → WorldKit / CustomModels → main Studio photo PC + phone. Old asset stays until the new one is in the game (screen never blank), then delete the old file + record.
Credits: no per-batch report to the user; 검수 tells the user only when a balance is down to ~500 (user 10/09).

## P1 — monsters and bosses (2D: 이미지 생성 2 · 3D: 이미지 생성 1 · code: 개발 2)
| # | In game now | Reuses | New |
|---|---|---|---|
| 1 | Slime Prince (BigSlime) | Shard Slime body mesh + blue recolour + Blender crown at 0.7× | own blue square jelly + small gold crown, no crystals |
| 2 | Flower Slime (dev2 branch) | Shard Slime model ×0.9 purple | own purple slime + flower bouquet |
| 3 | Shard Slime | 10/05 mesh with a Blender-flattened back | fresh Tripo of the same design, smooth, yellow shard |
| 4 | Captain Clatter (field boss) | Skeleton Knight mesh + rig ×2.2 | own captain skeleton (hat/coat, modest, not scary-gory), rigged |
| 5 | King Slime | own E6 mesh, pink by recolour script | fresh Tripo from a pink 2D multiview (bigger readable face) |
| 6 | Slingshot Goblin, Skeleton Archer | own static meshes, borrow Goblin/Skeleton clips | Tripo rig (+ animation) so they move with their own body |
| 7 | Goblin, Goblin Brute, Skeleton, Skeleton Knight | own 10/05 meshes with tone-fix scripts | regenerate from the user-picked 2D at today's HD settings |
| 8 | E8 SlimePrinceBody, E10 SlimeBodySmooth | edited old GLBs | **cancelled** — replaced by #1 and #3 (do not import) |
| 9 | Config fallbacks | King `ModelFrom="BigSlime"`, Ghost Minion/King `ModelFrom="LittleGhost"`, Slingshot/Archer `ModelFrom/AnimFrom` | 개발 2 removes stale fallbacks once each own model is in |
| 10 | Golden variant of every monster | same model + gold Highlight rim | later: own gold texture per monster (after P1–P3) |

## P2 — world props (이미지 생성 1; placement via kit_args by 메인 반영)
- **Own Tripo models already exist but Parts are placed** — swap now: Halo Citadel (Town_Halo_WallTower, KnightStatue, HouseA–C), Horns Den (Town_Horns_WallTower, SpikeRock), Skeleton Ruins (R_Arch_A/B, Kit_R_PillarA/B, StoneMarker, Banner, SpiritBowl, R_Gate), Pumpkin Patch (Kit_P_PumpkinCluster, HayBales, PumpkinCart, Sunflowers, EntranceSign, P_TreeAutumn_A/B, P_Pine), Haunted Hollow (H_TreeTwisted, H_Willow, H_TreeArch, Kit_H_* replacing the free generate_mesh GF_* set), zone gates (Kit_M_MeadowArch, W_Gate, R_Gate, Town_Halo_Gate, Town_Horns_Gate), bridges (Town_Halo_Bridge, Town_Horns_Bridge, Kit_M_Bridge, W_BridgeWood), Goblin Woods DarkBush/RedEye.
- **Same asset in several zones** — each zone gets its own from its A23-93 concept set: meadow trees (now woods W_Tree_A/B/C), boulders (W_Boulder_A/B in meadow, sea/pass, ruins), woods flowers (now meadow Kit_M_Flowers), meadow stepping stones (now woods), Crossroads signposts (now meadow sign), Crossroads fountain (now Halo town's; X_Fountain exists unused), Supporter board (recoloured notice board).
- **Hack-fixed own models** → fresh Tripo: Kit_M_SignPost (hollow filled), Kit_W_JobBoard (hole filled), Kit_M_CrownShrine (top capped), Crown_Broken_B (back repainted), Kit_W_CampFence (tips painted).
- Market stall roofs and any parasol: solid colour, no stripes/wedges (no ray-burst rule).

## P3 — character gear (2D: 이미지 생성 2 · 3D: 이미지 생성 1 · code: 개발 1)
- Held weapons: today one code-built Part shape per class, recoloured per tier (CharacterVisuals) → own Tripo model per class × tier (4 × 8). Order: tier 1–2 of each class first, then up.
- Gold sack, grudge sack, grudge ghost: Part balls → own Tripo props.
- Rank marks: R1/R2 Blender-made with one shared texture → the R1–R5 ladder Tripo set (approved). Shop/attendance Looks: same rank meshes with a new texture → own model per Look (after the ladder).
- Kaiju form (own avatar ×3 + fire) stays — it is the player.

## P4 — NPCs (human characters: 검수 review → user approval before 3D)
- Potion seller Fizzby: stock R15 from a HumanoidDescription → own Roblox-style NPC (modest clothing).
- Otto (blacksmith): old chibi portrait PortraitMerchantC, no 3D → new portrait + own NPC.
- Fountain Shard speaker uses the Crown Shard portrait → own portrait.

## P5 — images (이미지 생성 2 draws · 이미지 개발 uploads + Config.UIArt)
- Head icons missing: SlimeKing, CaptainClatter, FlowerSlime, SlingshotGoblin, SkeletonArcher (quest rows, minimap, boss toasts — King toasts now show the Prince head, Clatter toasts the Knight head).
- IconCaptainBadge (item icon) missing.
- IconDiary = IconKingDiary (same image) → two icons.
- Scroll grades: one icon per grade (Enh 70/30/10, Move 70/30/10) instead of one tinted icon.
- Attendance ribbons Days 7/14/28/50/100: own ribbon each instead of hue shifts.
- Pet menu button (now the Baby Slime pet icon) and the 2x XP pass tile (now the faction XP +30% icon): own icons.
- Speech bubbles: Captain Clatter, Flower Slime, Slingshot Goblin, Skeleton Archer get their own (now family bubbles).
- World map pond slimes are pasted concept cutouts → goes away with the minimap/big-map tile set (A23-95, MapTilesFull).

## Order — one zone at a time (A23-97, user 10/09)
Zone by zone, each finished like its concept before the next: ① Slime Meadow (P1 #1–3, #5 slimes; meadow's own trees/boulders/stepping stones/sign/bridge/gate; Kit_M_SignPost fresh; minimap tiles) → ② Crossroads (own signposts, X_Fountain or fresh, supporter board, stalls solid roofs) → ③ Goblin Woods (P1 #6–7 goblins, woods flowers, DarkBush/RedEye, Kit_W_JobBoard/CampFence fresh) → ④ Halo / Horns towns (existing Town_* Tripo swaps) → ⑤ Skeleton Ruins (#4 Clatter, #7 skeletons, R_* swaps) → ⑥ Pumpkin Patch → ⑦ Haunted Hollow.
Zone-free items run in the gaps by 이미지 생성 2 / 이미지 개발: P5 icons, P3 weapons, P4 NPCs (after approval). P1 #10 last.
