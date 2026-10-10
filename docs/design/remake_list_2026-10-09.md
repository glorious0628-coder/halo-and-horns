# Remake list — every reused / recoloured / placeholder asset gets its own (2026-10-09)

User 2026-10-09: "기존 것 재활용하지 말구 TRIPO 써도 돼! 왜 아끼니" → "지금있는 것들 중에서 재활용한 것 있으면 싹 다 새로 만들어!" → "우리는 퀄리티가 중요해. 없는 살림이지만 ㅋㅋ" (SPEC A23-96).
Inventory: 검수 sweep of `src/` + `build/GoodEvil.rbxlx` (saved 10/09 12:56). Line numbers drift; search by name.

Pipeline for every 3D item: Firefly **High** multiview (front + side + back; back has no face) by 이미지 생성 2 (world props: the zone plan says who draws — the Halo and Meadow plans give their 2D to 이미지 생성 2 too, `halo_town_plan_2026-10-09.md`, `meadow_props_list_2026-10-09.md`) → Tripo web 25,000-pt account HD by 이미지 생성 1 → Blender front/back render vs the 2D → WorldKit / CustomModels → main Studio photo PC + phone. Old asset stays until the new one is in the game (screen never blank), then delete the old file + record.
**Sharpness rule (user 10/10, photo of a blurry gate banner: "이거 다 따로따로 만들어야지"):** one big model = one texture (max 1024) → small details blur. So big buildings are split into 2–4 pieces with their own baked 1024 texture each (gate and cathedral first), and flat decorations (banners, crests, emblems, signs) are separate thin parts with their own High Firefly image (SurfaceGui/Decal front + back), not baked into the mesh. Every new 3D item follows this.
Credits: no per-batch report to the user; 검수 tells the user only when a balance is down to ~500 (user 10/09).

## P1 — monsters and bosses (2D: 이미지 생성 2 · 3D: 이미지 생성 1 · code: 개발 2)
| # | In game now | Reuses | New |
|---|---|---|---|
| 1 | Slime Prince (BigSlime) | Shard Slime body mesh + blue recolour + Blender crown at 0.7× | own blue square jelly + small gold crown, no crystals |
| 2 | Flower Slime (~~dev2 branch~~ in main) | Shard Slime model ×0.9 purple | own purple slime + flower bouquet |
| 3 | Shard Slime | 10/05 mesh with a Blender-flattened back | fresh Tripo of the same design, smooth, yellow shard |
| 4 | Captain Clatter (field boss) | Skeleton Knight mesh + rig ×2.2 | own captain skeleton (hat/coat, modest, not scary-gory), rigged |
| 5 | King Slime | own E6 mesh, pink by recolour script; bubble bumps on the body are in the mesh (user 10/09 photo: "이런 거 나중에 없애줘야 돼", fix at the Slime Meadow turn) | fresh Tripo from a pink 2D multiview: smooth body, **no bumps/bubbles/blisters**, bigger readable face |
| 6 | Slingshot Goblin, Skeleton Archer | own static meshes, borrow Goblin/Skeleton clips | Tripo rig (+ animation) so they move with their own body |
| 7 | Goblin, Goblin Brute, Skeleton, Skeleton Knight | own 10/05 meshes with tone-fix scripts | regenerate from the user-picked 2D at today's HD settings |
| 8 | E8 SlimePrinceBody, E10 SlimeBodySmooth | edited old GLBs | **cancelled** — replaced by #1 and #3 (do not import) |
| 9 | Config fallbacks | King `ModelFrom="BigSlime"`, Ghost Minion/King `ModelFrom="LittleGhost"`, Slingshot/Archer `ModelFrom/AnimFrom` | 개발 2 removes stale fallbacks once each own model is in |
| 10 | Golden variant of every monster | same model + gold Highlight rim | later: own gold texture per monster (after P1–P3) |

## P2 — world props (이미지 생성 1; placement via kit_args by 메인 반영)
- **Own Tripo models already exist but Parts are placed** — swap now: Halo Citadel (Town_Halo_WallTower, KnightStatue, HouseA–C; tower + statue swap applied 10/09 as interim only, d82722bc — final = new Halo_* set, Order ①), Horns Den (Town_Horns_WallTower, SpikeRock), Skeleton Ruins (R_Arch_A/B, Kit_R_PillarA/B, StoneMarker, Banner, SpiritBowl, R_Gate), Pumpkin Patch (Kit_P_PumpkinCluster, HayBales, PumpkinCart, Sunflowers, EntranceSign, P_TreeAutumn_A/B, P_Pine), Haunted Hollow (H_TreeTwisted, H_Willow, H_TreeArch, Kit_H_* replacing the free generate_mesh GF_* set), zone gates (Kit_M_MeadowArch, W_Gate, R_Gate, Town_Halo_Gate, Town_Horns_Gate), bridges (Town_Halo_Bridge, Town_Horns_Bridge, Kit_M_Bridge, W_BridgeWood), Goblin Woods DarkBush/RedEye.
- **Same asset in several zones** — each zone gets its own from its A23-93 concept set: meadow trees (now woods W_Tree_A/B/C), boulders (W_Boulder_A/B in meadow, sea/pass, ruins), woods flowers (now meadow Kit_M_Flowers), meadow stepping stones (now woods), Crossroads signposts (now meadow sign), Crossroads fountain (now Halo town's; X_Fountain exists unused), Supporter board (recoloured notice board).
- **Crown of Balance** (Crossroads centre, Landmarks/CrownOfBalance, also in the opening Intro.luau): user 10/10 (photo) "이것도 뭔가 이상해 ㅋㅋ 다시 만드는 게 나을듯" — today two flat halves (red | gold) that read as cardboard. New: ONE broken crown, gold Halo half (small halo ring) and red Horns half (small horns) joined by a glowing crack, chunky toy style, readable from the spawn plaza; round glow + sparkles only (no rays). 2D: 이미지 생성 2 (candidates Medium → 검수 picks → multiview High) in the gaps; 3D: 이미지 생성 1 Tripo HD; swap at zone ③ Crossroads (or earlier if the gap allows — new players meet it in the first minute). Same look family as the opening's broken crown (A23-44 Crown_Broken_B).
- **Hack-fixed own models** → fresh Tripo: Kit_M_SignPost (hollow filled), Kit_W_JobBoard (hole filled), Kit_M_CrownShrine (top capped), Crown_Broken_B (back repainted), Kit_W_CampFence (tips painted).
- Market stall roofs and any parasol: solid colour, no stripes/wedges (no ray-burst rule). A flat shop awning with straight parallel stripes (e.g. Halo_Shop, `docs/design/halo_town_plan_2026-10-09.md`) is not a ray burst and may stay; round or cone roofs (parasols, stall tops) never get alternating colour wedges that meet at a point; same-colour architectural ribs on a dome (e.g. Halo_Cathedral) are fine (검수 2026-10-09).

## P3 — character gear (2D: 이미지 생성 2 · 3D: 이미지 생성 1 · code: 개발 1)
- Held weapons: today one code-built Part shape per class, recoloured per tier (CharacterVisuals) → own Tripo model per class × tier (4 × 8). Order: tier 1–2 of each class first, then up.
- Gold sack, grudge sack, grudge ghost: Part balls → own Tripo props.
- Rank marks: R1/R2 Blender-made with one shared texture → the R1–R5 ladder Tripo set (approved). Shop/attendance Looks: same rank meshes with a new texture → own model per Look (after the ladder).
- Kaiju form (own avatar ×3 + fire) stays — it is the player.

## P4 — NPCs (human characters: 검수 review → user approval before 3D)
- Potion seller Fizzby: stock R15 from a HumanoidDescription → own Roblox-style NPC (modest clothing).
- Otto (blacksmith): old chibi portrait PortraitMerchantC, no 3D → new portrait + own NPC.
- Fountain Shard speaker uses the Crown Shard portrait → own portrait.
- Halo town (current zone, 검수 2026-10-10, zone_check_halo #50): Bright (girl, A23-59; style anchor PTR_TownBright), Sir Gleam, 2-3 Halo townsfolk → own Roblox-style NPCs (covered shoulders/torso/legs). 이미지 생성 2 draws multiviews right after the Halo props, before Horns. Horns town NPCs (Smokey, Tiny, …) when the Horns zone starts.

## P5 — images (이미지 생성 2 draws · 이미지 개발 uploads + Config.UIArt)
- Head icons missing: SlimeKing, CaptainClatter, FlowerSlime, SlingshotGoblin, SkeletonArcher (quest rows, minimap, boss toasts — King toasts now show the Prince head, Clatter toasts the Knight head).
- IconCaptainBadge (item icon) missing.
- IconDiary = IconKingDiary (same image) → two icons.
- Scroll grades: one icon per grade (Enh 70/30/10, Move 70/30/10) instead of one tinted icon.
- Attendance ribbons Days 7/14/28/50/100: own ribbon each instead of hue shifts.
- Pet menu button (now the Baby Slime pet icon) and the 2x XP pass tile (now the faction XP +30% icon): own icons.
- Top bar (A23-81, fdb3b7c8) reuses old approved parts (PanelCard, LevelBadgeHalo/Horns, WarCrownPip) → its own plate + Halo badge + Horns badge, no lettering (검수 2026-10-10). 이미지 생성 2 after the Halo NPCs; 이미지 개발 uploads and swaps.
- Speech bubbles: Captain Clatter, Flower Slime, Slingshot Goblin, Skeleton Archer get their own (now family bubbles).
- World map pond slimes are pasted concept cutouts → goes away with the minimap/big-map tile set (A23-95, MapTilesFull).

## P6 — sharpness redo (SPEC A23-107, user 10/10: "지금까지 그렇게 한 것들 없으면 싹 다 다시 해. 크레딧 많이 들어도 상관 없음")
Every existing 3D world model that is big (gate, cathedral, towers, houses, shops, bridges, castles, arches) or has baked flat decorations (banners, crests, signs) is redone: split into 2–4 pieces with their own baked texture, decorations as separate thin parts with High Firefly images. Zone order: ① Halo town now (gate first, then cathedral, towers, dome houses, shops, bridges) → ② Horns town (castle, gate, tower, tents — red banners / bull crest as separate images) → ③ Crossroads … in the A23-102 order. 검수 runs a full model audit (size × texture → texel density, baked-decoration check) after the usage reset and fills the per-zone list here.

## Order — one zone at a time (A23-97, user 10/09)
Zone by zone (user order 10/09), each finished like its concept before the next: ① Halo town (concept set 2375b76; Town_Halo_* Tripo models instead of HaloTower/HeroStatue/Flower Parts, Town_Halo_Gate/Bridge, its own fountain — 검수 10/09: the old Town_Halo_* are interim only (zone_swap applied); they do not match the concept, so the final is the 20 new Tripo models in `docs/design/halo_town_plan_2026-10-09.md`) → ② Horns town (set c1772f5; Town_Horns_WallTower/SpikeRock/Gate/Bridge instead of Parts) → ③ Crossroads (own signposts, X_Fountain or fresh, supporter board, stalls solid roofs) → ④ Slime Meadow (P1 #1–3, #5 slimes; meadow's own trees/boulders/stepping stones/sign/bridge/gate; Kit_M_SignPost fresh) → ⑤ Goblin Woods (P1 #6–7 goblins, woods flowers, DarkBush/RedEye, Kit_W_JobBoard/CampFence fresh) → ⑤-2 Skeleton Ruins (not in the user's list; 검수 put it here: #4 Clatter, #7 skeletons, R_* swaps) → ⑥ Pumpkin Patch (set b522bbd) → ⑦ Haunted Hollow. Minimap tiles re-shot at the end of each zone.
Zone-free items run in the gaps by 이미지 생성 2 / 이미지 개발: P5 icons, P3 weapons, P4 NPCs (after approval). P1 #10 last.
