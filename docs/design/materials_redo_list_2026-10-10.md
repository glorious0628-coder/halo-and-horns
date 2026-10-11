> 10/11 갱신(기록용 점검 결과, 재질 레시피 §10은 유효): 구역 순서는 빛 → 뿔 → 교차로 → 초원 → 새 구역(수정 동굴·산호 해안) → 숲 → (유적)(A23-119) — 아래 'Halloween(호박밭·유령 숲)' 칸은 내년 10월까지 숨김이라 하지 않는다. §1의 'halo_apply_main(옛 키트 적용)'은 멈춤(빛 마을 처음부터 다시, A23-121, `halo_restart_2026-10-11.md`). 'Tripo'는 HD H3.1 4면 → Blender 손보기(필수) → Roblox 재질(A23-122·125)이고 건물 큰 덩어리는 Studio 골격(A23-120).
> 검수 재질 점검 워크플로 wf_b7b2ec77-5ee(2026-10-10) 결과. 맨 아래 '비판자 고침'이 본문보다 새것. 선명도 목록은 docs/design/sharpness_redo_list_2026-10-10.md.

# Materials redo list (SPEC A23-107), 2026-10-10

This is a read-only audit. Sources:
- `place/GoodEvil.rbxlx` (saved 10/09 16:11, byte-identical to `build/`)
- the GLB bundles and import ledgers
- main-Studio photos from 10/09 and 10/10
- Blender renders and map stats made in this scratch folder (`audit3d/`)

Live Studio was not opened. Nothing tracked was changed.

## 사용자 질문에 대한 답 (빛 마을도 재질이 안 들어갔는지)
맞아요, 빛 마을도 재질이 안 들어갔어요.
- **본 게임:** 지금 보이는 빛 마을(성, 기사 석상 6개, 떠 있는 탑 4개, 금빛 나무 5그루, 문, 분홍 꽃)은 옛 모델 그대로예요. 색 그림만 있거나, 금속 맵이 없거나, 매끈한 플라스틱 블록이에요. 마을 NPC도 색만 칠한 기본 몸이에요.
- **새 빛 마을 세트:** 연습 장소(WorldKit)에만 있고 본 게임에는 아직 안 들어갔어요. 재질 맵 4장은 붙어 있지만 값을 색으로 추정해서, 돌·나무·천이 무광과 거의 같아 보여요(평균 차이 0.26~1.95/255). 아래 목록대로 다시 구워야 해요.

## Legend
**now** column:
- `TexID`: MeshPart.TextureID only. Colour only, Material Plastic, Reflectance 0.
- `SA C+N+R`: SurfaceAppearance with ColorMap, NormalMap and RoughnessMap, but MetalnessMap empty. All 298 SurfaceAppearances in the place file look like this, because 0e160929 (10/08) removed metal.
- `SA 4 mask`: all four maps, but metal and roughness come from the `tools/pbr_from_color.py` colour masks (stone 0.62, wood 0.78, cloth 0.85, leaf 0.80, gold metal 1 / rough 0.18). The Tripo normals have only 2-5 deg mean tilt. In Studio these pieces differ from the matte version by 0.26-1.95/255.
- `parts:` primitive Parts and the Roblox Materials they use.
- `GLB only`: not in the game yet.

**fix** column:
- `remake`: a new model; it must arrive with all 4 maps.
- `bake`: bake_maps_blender, using the recipe in section 10.
- `connect`: connect_existing_maps, attaching maps that already exist.
- `parts`: roblox_material_parts, separate Glass/Neon/Metal/Fabric parts or a Material swap.
- `ok`: no work.

**priority** follows the zone order Halo, Horns, Crossroads, Meadow, Halloween, Woods, Ruins (A23-97/102):
- `P0`: Halo town pass (now).
- `P1`: Horns town pass.
- `P2`: Crossroads, then Slime Meadow.
- `P3`: Halloween, then Goblin Woods, then Skeleton Ruins.
- `P4`: kit not placed; do it when it gets placed.
- `gap`: zone-free gear, done in the gaps.
- `—`: no work.
- `(quick)`: an interim fix of a few minutes on a live model, which 검수 may pull forward.

---

## 1. Halo town

The main game still shows the old Halo set. `halo_apply_main` (kit, then halo_materials, terrain and props) has not run in main. The new `Halo_*` kit exists only in `build/WorldKit.rbxlx`. Neither half meets A23-107.

### 1a. Live in main now
| model | regions | now | fix | priority |
|---|---|---|---|---|
| HaloCastle (Landmarks, 9 tiles) | white stone walls, blue spire roofs, gold trim/halo/finials, glass windows, wooden gate, cloud base | TexID; source GLB has no MR or normal map | **remake**: halo_props archives it and Halo_Cathedral replaces it (stage 2, part by part). No bake. | P0 |
| Town_Halo_KnightStatue (×6, ZoneSwap_halo) | silver armour, blue cape, gold trim, white stone plinth, steel sword | SA C+N+R; the Tripo MR covers only 11% of the silver with metal | **remake** → Halo_Statue. Only if the swap slips: connect the Tripo metal map. | P0 |
| Town_Halo_WallTower (×4, floating) | cream stone tower, gold cone roof + halo, round glass windows, cloud base | SA C+N+R (the Tripo MR, 10% metal, is unused) | **remake** → Halo_Tower | P0 |
| Town_Halo_Tree (×5, HaloTownTrees) | gold-leaf canopy, trunk, stone/cloud base | TexID; GLB has baseColor only | **remake** → Halo_RoundTree / Halo_Topiary | P0 |
| Gate_HaloTown | white pillars, gold dome caps, lintel, neon trim | parts: 5 SmoothPlastic + 8 Neon | **remake** → Halo_Gate (halo_props rebuilds Map.Gates.Gate_HaloTown) | P0 |
| Bridge_Halo (stays; it is the only walkway out of town) | marble deck, gold rails/posts, neon lamps, slate supports | parts: SmoothPlastic 28, Slate 14, Neon 12, Marble 1 | **parts**: deck → Marble; rails/posts → Metal or Foil, Reflectance 0.3-0.5; supports → Slate/Cobblestone; keep the Neon lamps (quick) | P0 |
| Flower (×8) | pink petal discs | parts: SmoothPlastic | **remake** → Halo_PotFlowers / Halo_Planter | P0 |
| Halo NPC bodies: Npc_Bright, Npc_Gleam, Npc_Folk1-4, PotionMerchant_Halo | stock R15 head and hands, one-colour torso, one-colour legs | HumanoidDescription in plain colours, no texture at all (`TownNpcs.luau:96-110`) | **remake** → the 5 H6 Tripo NPCs in 1c. Folk4 and PotionMerchant_Halo still have no model (remake_list P4). | P0 |

### 1b. New Halo_* kit (WorldKit only; goes into main with halo_apply_main)
| model | regions | now | fix | priority |
|---|---|---|---|---|
| Halo_Gate [9 split tiles] | white marble towers/walls, gold domes, gold halo ring, blue banners, shield crest, wooden doors, glass lanterns | SA 4 mask; PBR vs matte 1.95/255 (only 6% of pixels change by more than 10); normal tilt 2-3 deg | **remake** part by part (first in stage 2): Tripo PBR on, halo ring as a Neon/Metal part, banners as Fabric plates, doors as wood parts, then the section 10 bake | P0 |
| Halo_Cathedral [9 tiles] (+ single mesh, _r2) | white marble walls, big gold dome, blue stained-glass windows, rose window, gold finials, stone stairs, green topiary | SA 4 mask, 0.73/255; the blue glass is classed as cloth (0.85). The single mesh is TexID only (grey-SA bug). _r2 is in no ledger. | **remake** part by part (stage 2), with the windows and rose window as separate Glass parts | P0 |
| Halo_Tower [4 tiles] | white stone shaft, gold dome, glass windows, gold bands | SA 4 mask; stone is a flat 0.62, normal tilt 4-5 deg | **remake** (stage 2, 4th; the door is also too small) | P0 |
| Halo_DomeHouseA [4 tiles] (+ single, _r2) | white stone walls, gold dome, blue-white striped awning, wooden door, glass lanterns, ivy | **broken**: every SA variant renders solid grey in WorldKit; only TexID shows colour, so it has no materials at all | **bake** the region maps, re-upload under new asset names (asset review is suspected), recheck in Studio | P0 |
| Halo_DomeHouseB [4 tiles] | white stone walls, gold dome, balcony balustrade, blue awnings/banners, glass windows, flower boxes | SA 4 mask; only the gold reads; normal tilt 3-3.5 deg | **bake**: stone-block and fabric-weave detail normals, a wider roughness spread, windows as Glass | P0 |
| Halo_Shop [4 tiles] | white stone walls, gold dome, wooden arched door, blue awning, shop window, ivy/flowers, hanging sign | SA 4 mask, 0.26/255; the door looks the same as the stone | **bake**: wood grain and rough 0.85 on the door mask, stone-block normal on the walls, a separate Glass shop window | P0 |
| Town_Halo_Fountain3 [4 tiles] | white marble basin, gold bands/finials, water, stone tiers | SA 4 mask, 1.29/255; the water is split into 'glass' 0.12 (about 10%) and 'cloth' 0.85, and it is opaque | **bake** with a water mask at rough 0.05; add a transparent Glass water surface part over FountainFx | P0 |
| Halo_Statue [4 tiles] | white marble knight, gold trim/shield boss, steel spear tip, stone plinth | SA 4 mask; the marble is a flat 0.62 and reads like plaster; the 'silver = stone' rule keeps the spear tip non-metal | **bake**: marble 0.45 with a vein/bump normal; steel mask metal 1 / rough 0.3 | P0 |
| Halo_ArchBridge [4 tiles] | white stone deck and arch, gold rail stripes/finials, blue insets | SA 4 mask; 91-93% of texels are stone at one roughness; normal tilt 2-3 deg | **bake**: paving/block normal and roughness variation | P0 |
| Halo_Stairs | white stone steps, gold edge stripes, blue post insets | SA 4 mask (from an uncommitted ledger edit); 87% stone at 0.62 | **bake**: stone normal | P0 |
| Halo_Balustrade | white stone balusters/rail, gold dome caps, blue cloth inset | SA 4 mask; 83% stone at one roughness | **bake**: stone normal | P0 |
| Halo_Lantern | gold frame, glowing glass panes, white stone post, blue banner strip | SA 4 mask; the gold rule catches the lit yellow glass, so it renders as gold metal (1 / 0.18) | **parts**: a separate Glass/Neon pane part with a PointLight for night (A23-105); keep the frame metal | P0 |
| Halo_BannerPole | gold pole/finial, blue banner, white stone base | SA 4 mask | **parts**: the banner becomes a thin plate with a High Firefly image and Fabric material, front and back (A23-107 rule 2); the pole stays metal | P0 |
| Halo_Planter | white stone box, gold corner caps, blue insets, leafy shrub, flowers | SA 4 mask; the leaves are fine, the stone box looks like clay | **bake** at 512 with a stone normal | P0 |
| Halo_PotFlowers | white stone pot, gold rim, blue insets, flowers/leaves | SA 4 mask; the pot looks like clay | **bake** (same as Planter) | P0 |
| Halo_Topiary | clipped cone foliage, white stone pot, gold bands, blue insets | SA 4 mask; the foliage reads, the pot is plastic | **bake**: stone normal on the pot | P0 |
| Halo_Islet | white rock cliffs, green moss, sea water, small tower | SA 4 mask; the saturated blue water (35% of texels) is classed as cloth, so it gets 0.85 | **bake**: water 0.05, rock bump; fix the water rule | P0 |
| Halo_FarArch | rock arch, moss, sea water | SA 4 mask; the water (38%) is classed as cloth | **bake** (same as Islet) | P0 |
| Halo_RoundTree | leaf canopy, bark trunk, grass base | SA 4 mask; 74% leaves at 0.8 is the right look | **ok** | — |
| Halo_CloudBush | cloud puffs, grass ring | SA 4 mask; matte is the intended look | **ok** | — |

### 1c. New Halo NPCs
Source: Tripo HD, `build/import_all/6_sixth/H6_HaloNPC.glb`. None of them are in a ledger yet.

| model | regions | now | fix | priority |
|---|---|---|---|---|
| NPC_HaloSirGleam | silver plate armour, gold trim/buckle/knee discs, halo ring, blue cape and tabard, leather belt and scabbard, skin, white moustache, blue plume | GLB only: Tripo HD C+MR+N. Metal covers 97.5% of the silver texels; roughness 0.3-0.6 by region | **connect** the Tripo MR and normal as a 4-map SA; override cape/tabard roughness to about 0.9; make the halo ring a separate Metal/Neon part | P0 |
| NPC_HaloBright | silver helmet, gold shoulder plates/trim/boot caps, halo, blue tunic, white sleeves/leggings, blue boots, blonde braids, cyan brooch gem, plume | GLB only. The Tripo metal is right (about 35%: gold and helmet), but roughness is about 0.27 on every region, so the cloth shines like vinyl | **bake** roughness only, keeping the Tripo normal and metal: cloth 0.85-0.9, leather 0.55, skin 0.55, hair 0.5, metal 0.25. Brooch as a Glass/Neon part | P0 |
| NPC_HaloBakerGranny | blue dress, white apron and chef hat, grey hair, skin, gold buttons, halo, leather shoes | GLB only. Roughness is about 0.25 everywhere, so the cotton looks like lacquer; metal (3%, buttons and halo) is right | **bake** roughness and a weave normal on the cloth (keep normal + metal) | P0 |
| NPC_HaloJuiceMan | straw hat, blue hat ribbon, orange tunic, leather apron/straps/boots, cream trousers, ginger hair, skin, gold halo/buckles | GLB only; roughness about 0.34 everywhere | **bake** (keep normal + metal): straw 0.85-0.9 with weave, cloth 0.85-0.9, leather 0.5-0.55 with grain | P0 |
| NPC_HaloFlowerGirl | green pinafore, white blouse/tights, brown hair, flower crown, blue leather satchel, boots, gold halo | GLB only; roughness 0.47 everywhere and metal 0 everywhere, even on the halo | **bake** region roughness and halo metal 1 / rough 0.2 (keep the normal) | P0 |

### 1d. Old interim Halo kit (ServerStorage/WorldKit3D, not placed)
| model | regions | now | fix | priority |
|---|---|---|---|---|
| Town_Halo_Castle/_T9, Gate, Spawn, Wall, Bakery, HouseA, HouseB, JuiceBar, Potion, Smithy; Town_Halo_Bridge, HouseC, KnightStatue_LOD | stone, gold, blue roofs, walls, doors, awnings, cloth | TexID (GLBs have baseColor only); Bridge/HouseC/KnightStatue_LOD are SA C+N+R | **remake**: the Halo_* kit supersedes them (A23-96). No material work. | P4 |

**Halo notes**
- Builder dependency: the split-tile metal maps rely on two things that are not committed. One is the change to `tools/build_kit_from_ids.py`. The other is the untracked ledger `art/models/worldkit/import_halo_split_assets_2026-10-10.json`. The 18 whole-model ledger entries have no `metal=true`.
- `pbr_from_color.py` needs these rule fixes before any re-bake:
  - saturated blue water → water
  - blue stained glass → glass
  - lit yellow glass → glass/Neon, not gold
  - silver → metal on characters and steel tips, but stone on buildings and statues (per-model override)
- Evidence:
  - `docs/art/verification_2026-10-10/main_apply_morning/newstart2/02_halo_shadow.png` and `.../shadow_after_toggle/halo_0.png`
  - `art/review/world/halo_new/split/material_2d_matte_pbr.jpg` and the `*_pbr.png` vs `*_matte.png` pairs
  - `art/review/world/halo_new/npc/*_compare.jpg`
  - `audit3d/hh_mapstats.json`, `hh_maps_color_rough_metal.jpg`, `hh_npc_sheet.jpg`, `hh_split_tests.jpg`
  - `docs/design/halo_parts_plan_2026-10-10.md`

---

## 2. Horns town
Almost everything here is a placeholder: Basalt, Neon and SmoothPlastic parts, plus a colour-only castle. The new Horns_* kit from `horns_town_plan_2026-10-09.md` must be made with per-region maps from the start, not with colour masks only. That kit is Gate, WatchTower, WarTent, Stall, House, RockColumn, SpikeFence, Brazier and StoneBridge.

| model | regions | now | fix | priority |
|---|---|---|---|---|
| HornsCastle (Landmarks, 9 tiles) | dark basalt walls, red roofs/banners, gold trim/spikes, lava falls, horns, red wooden gate | TexID. An unused PBR bundle exists (`build/import_H/H_HornsCastle_v6mv_pbr.glb`), but it is rough 0.86 almost everywhere with 8% metal, so it gains little | **remake** part by part from its own 2D in the Horns pass, with the lava as Neon parts. Stopgap: connect the v6mv_pbr bundle (quick). | P1 |
| Gate_HornsTown | basalt pillars, bull banner, horn tips | parts: 8 Basalt + 1 Fabric; the Basalt renders nearly black | **remake** → Horns_Gate (Tripo, multiview) | P1 |
| Bridge_Horns (stays, walkway) | basalt deck, red rails, lava neon blocks | parts: SmoothPlastic 28, Slate 14, Neon 12, Basalt 1 | **parts**: rails → Wood/WoodPlanks in dark red; deck → Basalt/Slate with a lighter colour so the texture shows; keep the Neon lava (quick) | P1 |
| Spike (×14) | basalt rock spikes | parts: 14 Basalt wedges | **remake** → Horns_RockColumn A/B/C + SpikeFence | P1 |
| HornTower (×2) | basalt block, neon lava slits | parts: Basalt + Neon | **remake** → Horns_WatchTower (wood, red cloth roof, horns, torch) | P1 |
| Town_Horns_Gate, Spawn, Tree, Wall, Bakery, HouseA, HouseB, JuiceBar, Potion, Smithy (WorldKit3D interim) | basalt, red cloth, wood, gold | TexID; GLBs have baseColor only | **remake** → the new Horns_* kit | P1 |
| Town_Horns_Brazier, Bridge, HouseC, SpikeRock (+_LOD), WallTower | basalt, iron bowl, fire, wood, red cloth | SA C+N+R; a Tripo MR exists | **remake** (horns_town_plan). If 검수 keeps any: connect the Tripo metal and check by eye for chrome-grey. | P1 |
| Town_Horns_Castle, Castle_v4, Castle_v6mv (WorldKit3D copies) | basalt, red roofs, gold, lava | TexID (v6mv has the unused PBR bundle) | **remake** together with HornsCastle; it still needs its own concept | P4 |

Evidence:
- `docs/art/verification_2026-10-09/main_photos_after/pc/10_horns_bridge.png`
- `docs/art/verification_2026-10-10/main_apply_morning/horns_music/04_horns_town.png`
- `art/review/town5/horns_castle_v6_gloss.jpg`

---

## 3. Crossroads
Nothing placed here has a MetalnessMap. The imported X_* pieces are "web_fixed" GLBs: they replaced Tripo's metal with a flat ~0.15 and made roughness glossy, so they read as shiny plastic. The original `art/models/tripo/web/X_*_HD.glb` files have identical UVs (`cm2/uvmatch.txt`). Kit_X gold/brass is dark ochre: lift it to bright gold wherever metal = 1, or it turns olive.

| model | regions | now | fix | priority |
|---|---|---|---|---|
| CrownOfBalance (Landmarks, 160 studs) + Crown_Broken_B (kit / opening crown) | gold Halo half, red Horns half, ruby and sapphire gems, gold ball tips, small gold halo ring, inner band | TexID, Plastic, 1024 texture on a 160-stud landmark; `Crown_Broken_B_backfix.glb` is colour only. The user said "재질이 뭉툭" on 10/10. | **remake** (remake_list P2; the crown part 2D is in progress): Tripo HD per part, gold metal 1 / 0.15-0.25, red lacquer 0 / 0.2, gems as separate Glass parts | P2 |
| Town_Halo_Fountain (hub centre, borrowed from Halo) | white marble basins, gold trim/crown/wings, halo ring, cloud base, water pools/streams | SA C+N+R (water 0.08, marble 0.49); metal empty (the bundle metal is a flat 0.15); the water is opaque | **remake** as Crossroads' own fountain (remake_list #3) with 4 maps and transparent water parts. Interim: a MetalnessMap from the gold mask (15% of texels), keeping N/R (quick). | P2 |
| X_Altar (Altar of Fate) | grey stone base, white marble disc, teal inlay, gold gear medallion and trim, orange devil horn, white angel wing, cyan crystal | SA C+N+R (web_fixed): rough about 0.25 everywhere and metal a flat 0.15, so it reads as glossy plastic. The HD MR is uniform too. | **bake**, keeping the normal: stone 0.75, marble 0.55, wing 0.8, gold metal 1 / 0.3 with lifted colour, crystal 0.05 or a Glass/Neon part | P2 |
| X_GooseNest | golden egg, straw nest, wooden posts, teal band, cream stone, gold gears, teal pennants | SA C+N+R (web_fixed), metal a flat 0.15; the egg reads matte yellow. The HD metal spreads onto wood and teal. | **bake**, keeping the normal: metal on the egg and gears only; straw 0.9, wood 0.8, stone 0.75, egg 0.2 | P2 |
| X_MarketArch | wooden posts and beam, stone feet, teal bunting, brass bands/bolts, lanterns (metal + glass), wooden sign | SA (web_fixed) glossy (teal 0.09), no metal | **connect** the MR from `web/X_MarketArch_HD.glb` (same UVs): G → Roughness, B → Metalness; zero the metal on the cyan lantern glass (quick) | P2 |
| X_NoticeBoard | teal roof tiles, wood planks, teal posts, stone feet, gold brackets/gear crest, cyan crystal, lantern glass | SA (web_fixed): teal 0.09, crystal 0.06, wood 0.41, no metal | **connect** the MR from `web/X_NoticeBoard_HD.glb` (same UVs); gold rough about 0.35; crystal non-metal and glossy (quick) | P2 |
| X_SupporterBoard | gold-yellow roof tiles, wood board, posts, stone feet, crest with red gem, lantern | The X_NoticeBoard mesh with a recoloured texture and the same maps | **remake** as its own model (A23-96); interim: the same HD MR connect as NoticeBoard | P2 |
| X_GuildHall (forge house) | teal roof tiles, timber frame, plaster walls, stone base, brass gear emblem, chimney, warm window glass | TexID; only about 11 px/stud at 24 studs | **remake** (remake_list #55: split pieces, Tripo HD, then the section 10 bake) | P2 |
| X_PadBase (×3) | cream stone disc, teal band, bronze gears/rivets, cyan crystal centre | TexID; no PBR source | **bake**: stone 0.75, teal 0.5, bronze metal; the crystal as a Glass/Neon part | P2 |
| K_CrownShard_v2 (fountain shard) | gold half, red half, diamond gem insets | SA C+N+R, metal empty. The bundle/HD MR is metal ~1 / rough ~0.01 on 100% of texels | **bake**, keeping the normal: metal from the gold mask only, red lacquer 0 / 0.2, gems 0 / 0.05 or Glass insets. Do not connect the MR (§9). | P2 |
| Kit_X_Lamp (×8) | teal painted iron post, brass trims and bracket, chain, brass cage, glass globe with cyan crystal | TexID; the globes read as opaque frosted green-grey | **bake**: brass/iron metal (lift the ochre), paint 0.45. The globe becomes a Glass part (Transparency ~0.3, Reflectance 0.2) with a Neon crystal / PointLight | P2 |
| Kit_X_Curb (×16) | cream chiselled stone blocks, teal glazed tile strip, bronze medallions | TexID (4096 source) | **bake**: luminance-height normal, stone 0.8, glazed tile 0.35, bronze metal | P2 |
| Kit_X_Bench (×4) | teal painted wood back, wood seat/legs, brass gear and rivets | TexID | **bake**: grain normal, wood 0.8, paint 0.5, brass metal | P2 |
| Kit_X_StallRed (×2), Kit_X_StallBlue, Kit_X_StallGreen | cloth awning, wooden posts and counter, teal base, brass gear, fruit | TexID. The colour wedges meet at the roof top, which breaks the no-ray-burst rule; Blue and Green are recolours | **remake** each (Tripo HD, solid-colour roof), then bake | P2 |
| Kit_X_PotionCart | teal cloth canopy, wooden cart and wheels, brass hubs, glass potion bottles, cyan gem, pennant | TexID; the bottles are opaque | **bake**: cloth 0.9, wood 0.8, brass metal; bottles and gem as small Glass parts | P2 |
| Kit_X_BannerHalo (×2) | blue cloth banner with gold ring emblem, white pole, gold caps / halo ring, feather wings | TexID | **bake**: cloth 0.9, gold metal; consider the emblem as a separate thin plate | P2 |
| Kit_X_BannerHorns (×2) | red cloth banner with horn emblem, black iron pole and crest, orange glow cracks, gold tips | TexID | **bake**: cloth 0.9, iron metal / 0.45, gold metal; the glow cracks as Neon | P2 |
| Kit_X_Anvil | dark forged iron anvil, wooden stump, brass band and gear | TexID; the iron looks like grey plastic | **bake**: iron 1 / 0.4, wood 0.85, brass metal | P2 |
| Kit_X_Forge | teal roof tiles, plaster dome, stone base, brass chimney/frame, fire mouth | TexID | **bake** per region; the fire mouth as a Neon part | P2 |
| Kit_X_Brazier (×2) | gold bowl, teal legs, wood logs, flame | TexID; the flame is a painted solid | **bake**: gold metal (lift the colour), wood and paint roughness. The flame becomes Neon/Fire/ParticleEmitter | P2 |
| Kit_M_SignPost (Crossroads ×3) | wood frame, light wood panel, lime jelly cube | TexID; a meadow sign borrowed here, with the hollow hack-filled | **remake** as Crossroads' own signposts | P2 |
| Disc (plaza floor) | one flat cream disc | parts: SmoothPlastic | **parts**: Limestone/Sandstone or a cobble MaterialVariant (quick) | P2 |
| Roads | dirt paths, slate paths, 3 SmoothPlastic strips | parts: 7 of 10 already Ground/Slate | **parts**: the 3 SmoothPlastic strips → Slate/Cobblestone + a MaterialVariant (quick) | P2 |
| Pad_SlimeMeadow / Pad_GoblinWoods / Pad_SkeletonRuins | glowing ring segments | parts: Neon | **ok** | — |
| Kit_X_PlazaStairs / Kit_X_PlazaWall (+_LOD) | stone blocks, moss | SA C+N+R (0.56 / 0.82, normal present) | **ok** | — |
| X_HouseA, X_HouseB, X_TreeB (kit, not placed) | roof tiles, plaster, timber, stone base, brass, window glass / crystal lamp; for TreeB: leaves, bark, stone planter, brass rings | SA (web_fixed): metal a flat 0.15, glossier | **connect** the `web/X_*_HD.glb` MR (same UVs) before placing; check TreeB's metal by eye | P4 |
| X_Fountain (kit, unused) | stone basins, teal tiles, gold gears, water, cyan crystal | TexID; 9.6k tris in one opaque mesh | **remake**: folded into the new Crossroads fountain above | P4 |
| Unused colour-only kit: X_SpawnPlaza, X_TreeA, Kit_X_Barrel, Kit_X_Bush, Kit_X_Crate, Kit_X_Fence, Kit_X_FlowerPot, Kit_X_FruitCart | wood, brass, teal paint, ceramic pot, leaves/flowers, stone ring + crystals | TexID (4096 colour) | **bake**, but only when one gets placed | P4 |

The Golden Goose is listed under monsters (§8c).

Evidence:
- `docs/art/verification_2026-10-10/main_apply_morning/morning3/05_fountain_a.png`, `morning3b/05_fountain_0..2.png`, `shadow/crossroads_0.png`, `morning4/02_at_forge.png`
- `audit3d/cm2/region_rough.txt`, `metal_overlay.jpg`, `uvmatch.txt`, `bundle_mr.txt`

---

## 4. Slime Meadow
Every Kit_M_* here is a Tripo API GLB with baseColor only, so there is nothing to connect. Their 4096 colour textures have clean colour regions, so colour-mask bakes are practical.

| model | regions | now | fix | priority |
|---|---|---|---|---|
| Kit_M_BushA (×122) | lime leaf clumps, pink flowers | TexID; the big lime blobs read as smooth plastic | **bake**: leaf normal from colour, leaves 0.7, petals 0.6 | P2 |
| Kit_M_BushB (×85) | teal-green leaf clumps, yellow berries | TexID | **bake**: leaves 0.7, berries 0.3 | P2 |
| Kit_M_FlowersA (×62 here + 34 in Woods, 596-tri LOD) | pink/purple/yellow petals, leaves/stems, grass base | TexID; also faceted | **bake** petal/leaf roughness and normal (the LOD faceting is a separate issue) | P2 |
| Kit_M_FlowersB (×60 here + 36 in Woods) | blue/peach/mint tulip petals, stems and leaves, grass base | TexID | **bake** (same as FlowersA) | P2 |
| Kit_M_Fence (×31) | wooden rails/posts, green moss caps | TexID | **bake**: wood grain 0.8, moss 0.9 (the meadow plan may swap it for Kit_M_RopeFence) | P2 |
| Kit_M_Mushrooms (×24) | pink spotted caps, cream stems, grass base | TexID | **bake**: caps 0.4, stems 0.8, grass 0.9 | P2 |
| Kit_M_Stump (×11) | bark, cut top with rings, moss, tiny mushroom | TexID; a smooth clay blob with almost no bark relief | **bake**: bark normal from luminance, 0.85 | P2 |
| Kit_M_Pinwheel (×10) | pastel plastic/paper blades, wooden stick, hub, grass tuft | TexID; the stick and grass have the same sheen as the blades | **bake**: blades 0.35, stick 0.8, grass 0.9 | P2 |
| Kit_M_JellyRock (×7) | pastel jelly dome, drip top layer | TexID; the jelly reads as matte clay | **bake**: rough 0.12-0.2 with a soft normal | P2 |
| Kit_M_SignPost (Meadow ×5) | wood frame, light wood panel, lime jelly cube | TexID; hack-filled | **remake** (remake_list line 28) | P2 |
| Kit_M_CrystalPile (×3) | yellow crystals, grey pebbles, grass/moss top, stone base | TexID; the crystals are opaque yellow plastic | **parts**: the crystals as Glass/Neon parts; bake the base (stone 0.8, moss 0.9) | P2 |
| Kit_M_LogBench (×2) | log bark, cut-end rings, moss patches | TexID | **bake**: bark normal, 0.85 | P2 |
| Kit_M_FlowerCart (×2) | mint painted wood cart, yellow wheels, clay pots, flowers/leaves | TexID; the detail is somewhat smeared | **bake**: paint 0.5, wood 0.8, clay 0.85. Remake instead if it fails the 100% blur check | P2 |
| Kit_M_PuddleRim (×2) | pastel rim stones, water centre, grass sprouts | TexID; the water is barely visible and opaque | **bake**: water 0.05, stones 0.8; optionally a separate Glass water disc | P2 |
| Kit_M_PicnicBasket | wicker weave, pink gingham cloth, red apple | TexID | **bake**: wicker 0.85 with normal, cloth 0.95, apple 0.25 | P2 |
| CrownShrine (Kit_M_CrownShrine) | grey stone crown wall, stone balls, moss, grass base, pebbles | SA C+N+R, but one flat 0.36-0.49 for stone, moss and grass alike | **remake** (hack-fixed top; remake_list) with per-region roughness: stone 0.75, moss/grass 0.9. Interim: a roughness-only bake | P2 |
| W_Tree_A / W_Tree_B / W_Tree_C (meadow copies 20 / 60 / 10) | leaf canopy, bark trunk, vines (C) | TexID; borrowed from the woods kit | **remake** as the meadow's own Kit_M_TreeA/B (Tripo HD, then bake) | P2 |
| W_Boulder_A / W_Boulder_B (meadow copies 11 / 21) | mossy rock | TexID; borrowed | **remake** as Kit_M_Boulder A/B/C | P2 |
| LilyPads (14 parts) | flat leaf pads | parts: SmoothPlastic | **parts**: Grass or Fabric, Reflectance 0.05 (quick; a Kit_M_LilyPad model is planned) | P2 |
| MeadowWaterfall (8 parts) | water sheets (Transparency 0.15-0.3) | parts: SmoothPlastic | **parts**: Glass with Reflectance ~0.15, keep the transparency (quick) | P2 |
| Kit_W_StepStones (meadow ×6) | grey stone discs, grass tufts | SA C+N+R (0.2-0.67, normal present) | **ok** (the meadow plan later swaps in Kit_M_StepStone) | — |
| Gate_SlimeMeadow | 3 wood parts | parts: Wood | **ok** (swap to Kit_M_MeadowArch planned) | — |
| Bridge_Meadow | deck, rails, supports | parts: WoodPlanks, Wood, Slate | **ok** (swap to Kit_M_Bridge planned) | — |
| PumpkinPatchSign | 2 plank parts | parts: WoodPlanks | **ok** | — |
| Kit_M_MeadowArch (kit, not placed) | wooden posts and arch beam, ivy leaves, hanging wooden sign, lantern (metal frame + glass) | SA C+N+R, but roughness a flat 0.45-0.5; no metal or glass on the lantern | **bake** before it replaces Gate_SlimeMeadow: wood 0.8, leaves 0.75, lantern metal mask, glass 0.05 | P2 |
| Kit_M_Bridge (kit, not placed) | wooden deck and rails, mint painted posts/caps, mint arch beam | TexID | **bake** before the swap: wood 0.8, paint 0.5 | P4 |
| Kit_M_JobBoard (kit, not placed) | green tile roof, wood board, stone feet, lantern | TexID (2048) | **bake** only if it is used | P4 |

The slime family and the pet are listed under monsters (§8c).

Evidence:
- `docs/art/verification_2026-10-09/main_apply_night/pc/10_meadow_arrival.png`
- `art/review/pc_check/meadow_kit_after_2026-10-07.jpg`
- `art/review/kit_meadow/meadow8b_2d_vs_3d.jpg`
- `audit3d/cm2/contact_meadow_full.jpg`, `meadow_close4.jpg`

---

## 5. Halloween (Pumpkin Patch + Haunted Hollow)
The game still shows SmoothPlastic pumpkin balls and the colour-only GF_* generate_mesh set. The own Tripo kits (P_*, Kit_P_*, H_*, Kit_H_*) have SurfaceAppearances but have 0 copies placed. Most of them pass; the rows below say which ones do not.

| model | regions | now | fix | priority |
|---|---|---|---|---|
| PumpkinPatch (placed primitive field, 195 parts) | 96 pumpkin/vine balls, 99 fence parts | parts: SmoothPlastic pumpkins + WoodPlanks fence | **remake** → the Kit_P_* Tripo set (remake_list) | P3 |
| Kit_P_EntranceSign (kit) | wooden posts, beam and plank sign, iron brackets and chains, lantern (iron + glowing glass), pumpkins, grass | SA: roughness a uniform 0.72, metal 0, normal nearly flat; the iron reads as wood | **bake**: iron metal mask and wood grain; the lantern glass as a Neon part with a light | P3 |
| Kit_P_PumpkinCart (kit) | wooden planks, wheels and handles, iron hub caps and bolts, pumpkins with stems | SA: uniform 0.41, so the wood is as glossy as the pumpkins; renders the same as plastic | **bake**: wood 0.8 with grain, iron metal, pumpkins 0.4 | P3 |
| P_Pine (kit) | needle tiers, bark trunk | SA: roughness about 0.04 everywhere (looks wet and glazed) | **bake**: needles 0.8, bark 0.85 | P3 |
| P_Cliff_A, P_Cliff_B, Kit_P_HayBales, Kit_P_PumpkinCluster (+_LOD), Kit_P_Sunflowers, P_TreeAutumn_A, P_TreeAutumn_B (kit) | stone, grass/moss, autumn bushes, straw, rope, pumpkins, vines, soil, petals, bark, leaves | SA C+N+R with roughness that varies by region or suits all-matte material; no metal needed | **ok** | — |
| GF_Tree (×7), GF_Willow (×2), GF_Lantern (×3), GF_Mushrooms (×4), GF_Arch (×1), GF_Rock (×3) (placed) | purple/blue canopies, trunks, lanterns, blue mushrooms, arch, rock | TexID; Studio generate_mesh placeholders with no source GLB | **remake** → H_TreeTwisted, H_Willow, Kit_H_LanternPost, Kit_H_GlowShrooms, H_TreeArch and a new rock (remake_list) | P3 |
| H_TreeArch (kit) | twisted bark arch, vines/moss, purple flowers, 3 hanging glass lanterns that should glow | SA: a uniform 0.33 makes the bark shiny; the lanterns are flat pale-blue paint | **bake** the bark at ~0.8; add Neon/Glass lantern parts with lights, as in the concept | P3 |
| Kit_H_LanternPost (kit) | wooden post and arm, rope lashing, iron hook/chain, frosted glass globe with iron frame that should glow | SA: uniform 0.51, metal 0, flat normal; renders the same as plastic | **parts**: the globe as a Glass/Neon part with a PointLight; bake an iron metal mask | P3 |
| Kit_H_GlowShrooms (kit) | pale-blue caps/stems that should glow, moss, purple flowers, stone base | SA: roughness already separates the caps (0.21) from the moss; the glow is missing | **parts**: Neon caps or lights | P3 |
| H_TreeTwisted, H_Willow, Kit_H_StumpTable (kit) | bark, leaves/fronds, moss, flowers, stump wood | SA C+N+R, organic and matte, no metal | **ok** | — |

The Pumpkin and ghost monsters and the BatGoblin are listed under §8c.

Evidence:
- `audit3d/whh/pbr_out/*__game.png` vs `*__plastic.png`, and `pbr_pumpkin.jpg`, `pbr_haunted.jpg`
- `docs/art/verification_2026-10-06/pumpkin_patch_studio_2026-10-06.jpg`
- `docs/devlog/2026-10-06/12_dev1_haunted_hollow.png`

---

## 6. Goblin Woods
All 17 big placed models are colour-only, and their raw Tripo GLBs have no MR or normal maps, so they must be baked. In the main-Studio camp photos, the tent cloth, poles, rope, fence logs and trees all have the same smooth plastic sheen.

| model | regions | now | fix | priority |
|---|---|---|---|---|
| W_Tent_A (×2, camp centre) | red/green patchwork cloth, wooden poles, rope lashings, stake pegs | TexID | **bake**: cloth 0.9 with weave, wood 0.8 with grain, rope 0.85 (do this first in Woods) | P3 |
| W_Tent_B (×1) | patchwork cloth/leather panels, rolled door flap, wooden poles, rope | TexID | **bake** (same as Tent_A; leather 0.55) | P3 |
| W_GiantTree (×1, 80 studs) | bark trunk/roots, leaf canopy, wooden treehouse platforms and railings, rope ladder/bridge, leaf/thatch hut roofs, moss | TexID | **bake** per region with wood grain | P3 |
| W_Tree_A (×51) | bark trunk, pine-needle tiers | TexID; GLB is colour only | **bake**: bark grain normal 0.85, needles 0.8 | P3 |
| W_Tree_B (×93) | bark trunk/roots, leaf-clump canopy, moss | TexID | **bake**: bark 0.85, leaves 0.7, moss 0.9 | P3 |
| W_Tree_C (×45) | twisted bark, moss, leaf canopy, hanging vines | TexID; the vine strips are grey and untextured | **bake** bark, moss and vines separately; fix the vine texture | P3 |
| W_Boulder_A (×69) | grey faceted stone, moss cap, leaf tufts | TexID | **bake**: stone bump 0.75-0.8, moss 0.9 | P3 |
| W_Boulder_B (×88) | grey stone, moss, brown mushrooms | TexID | **bake** (same as Boulder_A; mushrooms 0.5) | P3 |
| W_Totem (×1) | carved painted wood, leaf-shaped wings, gold crown | TexID | **bake**: painted wood 0.55-0.8, crown gold metal | P3 |
| Kit_W_CampFence (×57) | log stakes with bark and cut tops, rope bindings | TexID | **remake** ("CampFence fresh" on remake_list), then bake, because HD maps come out flat | P3 |
| Kit_W_LanternPost (×15) | wooden post and arm, rope wrap, iron chain/hook and lantern frame, glowing glass panes, iron band, mossy foot | TexID | **bake** iron metal and wood; the panes as a Neon/Glass part with a light | P3 |
| Kit_W_Campfire_Fire (×3) | ring of mossy stones, charred logs, flames | TexID | **bake** stone and wood; the flame becomes a Neon part + particles | P3 |
| Kit_W_Crates (×6) | crate planks, iron corner brackets and rivets, rope, barrel, iron hoops | TexID; the iron looks like grey paint | **bake**: iron metal, wood 0.8 | P3 |
| Kit_W_LootSack (×6) | cloth/leather sack, rope tie, green patch, gold coins | TexID | **bake**: coins metal 1 / 0.2, sack 0.9 | P3 |
| Kit_W_Stump (×29) | bark, cut end grain, moss, small mushroom | TexID | **bake**: bark normal 0.85 | P3 |
| Kit_W_SignPost (×4) | wooden plank arrows, post, iron nails, rope, moss | TexID | **bake**: wood 0.8, nails metal | P3 |
| Kit_W_FallenLog (×6) | bark log, hollow end, moss/leaves | TexID | **bake**: bark normal 0.85 | P3 |
| Kit_W_Banner | wooden pole and crossbar, patchwork cloth banner, stitching, cord wrap, wooden foot | SA: the cloth is 0.4-0.46, the same as the wood, so it looks like satin; normal nearly flat | **bake**: cloth 0.85 with weave | P3 |
| Kit_W_Mushrooms | red-brown caps with cream spots, cream stems, grass tuft | SA: roughness about 0.04 everywhere (mirror-glazed ceramic) | **bake**: caps 0.4, stems 0.7, grass 0.85 | P3 |
| Kit_W_Fern | fern fronds, fiddlehead, root/soil base | SA C+N+R, 0.4-0.94 | **ok**. Keep MetalnessMap **empty**: the source MR has bogus metal on 9% of the leaf texels, and materials_table's 'add MetalnessMap' would turn the leaves chrome. | — |
| Kit_W_StepStones, Kit_W_LogStool, Kit_W_MossRock, Kit_W_BushA, Kit_W_BushB | stone, moss, end grain, bark, leaves (BushB also has 2 Neon parts) | SA C+N+R with roughness that varies by region; no metal needed | **ok** (optional: MossRock stone up to ~0.6) | — |
| Gate_GoblinWoods | 5 wood parts, 1 SmoothPlastic part | parts | **parts**: give the one SmoothPlastic part a fitting Material (quick); swap to W_Gate when the zone is redone | P3 |
| WoodsWaterfall (5 parts) | falling water sheets (Transparency 0.15 / 0.3) | parts: SmoothPlastic, no reflectance | **parts**: Glass (or terrain water), Reflectance 0.2-0.3, moving texture/particles | P3 |
| DarkBush (×6) | bush blobs | parts: SmoothPlastic | **remake** (remake_list) | P3 |
| Bridge_Goblin, CampfireTemp, BossBanner, RedEye, PvPBorder_710 | Wood/WoodPlanks/Slate bridge, logs + Neon fire, pole + Fabric banner, Neon eyes, posts + Neon + Ground | parts with fitting Materials | **ok** for materials (RedEye is still on remake_list for its own model; CampfireTemp stands in for Kit_W_Campfire) | — |
| W_Gate (kit, 0 placed) | bark log posts, rope, plank sign, metal charms, red and green gem pendants, small lantern, moss | TexID | **bake**: charms metal, gems 0.05 or Glass parts (needed before the gate swap) | P3 |
| W_GateOpen (GLB only) | pointed wooden stakes, orange painted tips, rope, carved goblin-face crest with horns | SA (HD): roughness a uniform 0.28, so the wood looks varnished; renders the same as plastic | **bake**: wood 0.8 with grain | P4 |
| W_BridgeWood, Kit_W_JobBoard (kit, 0 placed) | BridgeWood: teal rails, gold gears, crystals (not the woods style); JobBoard: planks, shingles, iron, lantern | TexID | **remake** (both are on remake_list), then bake | P4 |
| Kit_W_Awning (kit, 0 placed) | patchwork cloth canopy, wooden posts and counter, rope, burlap sacks | SA, uniform 0.89, all matte | **ok** | — |

Goblin monsters are listed in §8c.

Evidence:
- `docs/art/verification_2026-10-09/main_photos_woods4/pc/10_woods_camp1_cam_noui.png`
- `docs/art/verification_2026-10-09/woods/woods_camp3_ground.png`
- `audit3d/whh/pbr_woods.jpg`, `texstats_out_39.json`

---

## 7. Skeleton Ruins
The game still shows SmoothPlastic primitives. The own R_* / Kit_R_* kit has 0 copies placed.

| model | regions | now | fix | priority |
|---|---|---|---|---|
| BrokenPillar (×18) | stone pillar stubs | parts: SmoothPlastic | **remake** → Kit_R_PillarA/B | P3 |
| BrokenArch (3 models, 9 parts) | stone arch blocks | parts: SmoothPlastic | **remake** → R_Arch_A/B | P3 |
| Gate_SkeletonRuins | gate posts and beam (3 parts) | parts: SmoothPlastic | **remake** → R_Gate (which needs the bake below) | P3 |
| TornPole (×4) | flag poles | parts: SmoothPlastic | **parts**: Wood, or Metal if they are meant as iron (quick) | P3 |
| R_Gate (kit) | lilac stone towers, arch and blocks, ivy/moss, purple torn cloth banners, gold rod caps, stone sign plaque, dark windows | SA, but the maps are empty: roughness 0.82 uniform, normal flat, metal 0; renders the same as plastic | **bake**: cloth 0.85, gold metal 1 / 0.3, stone grain detail | P3 |
| Kit_R_StoneMarker (kit) | stone blocks, dome cap, moss, gold crown emblem inlay | SA, metal 0; the crown reads as matte tan stone | **bake** a gold metal mask; keep the stone semi-matte | P3 |
| Kit_R_Banner (kit) | wooden pole, purple cloth banner, cord wrap, metal spear tip and rings, stone base, moss | SA: cloth and wood are both 0.4-0.5; a stray 1% metal patch on pale areas | **bake**: tip and rings metal, cloth 0.85, wood 0.75 | P3 |
| Kit_R_SpiritBowl (kit) | carved stone bowl, moss, lilac spirit surface inside | SA; the stone is fine (0.81-0.91), but the spirit surface is matte paint | **parts**: a Neon/translucent spirit part with a light or particles | P3 |
| R_Arch_A, R_Arch_B, Kit_R_PillarA, Kit_R_PillarB (kit) | stone blocks, marble columns, moss, purple drape | SA C+N+R with plausible matte stone/marble/moss roughness | **ok** (optional: stone-grain detail normal) | — |
| Tombstone, TornFlag, SoulWisp, PvPBorder_1260 | Slate tombstones, Fabric flags, Neon wisps, Wood + Neon + CrackedLava border | parts with fitting Materials | **ok** | — |

Skeleton monsters are listed in §8c.

Evidence:
- `docs/art/verification_2026-10-09/main_photos_after/pc/10_ruins.png`
- `audit3d/whh/pbr_ruins.jpg`, `maps_a.jpg`

---

## 8. Characters, monsters, items

### 8a. NPCs outside Halo
| model | regions | now | fix | priority |
|---|---|---|---|---|
| PotionMerchant (Fizzby), Npc_Otto (Crossroads) | stock R15 head and hands, flat torso/arms, flat legs | HumanoidDescription; 14 of 15 MeshParts are untextured Plastic | **remake** (remake_list P4) as Tripo HD with 4 maps, checked like the H6 NPCs | P2 |

### 8b. Rank marks (worn by every player of that faction)
| model | regions | now | fix | priority |
|---|---|---|---|---|
| Acc_HaloR1, Acc_HaloR2 | R1: plain silver ring. R2: gold ring + gold star | TexID; shared Blender palette texture | **remake** (remake_list P3, to the Tripo ladder) with gold metal 1 / 0.2. Interim: a Metal/Foil ring with Reflectance ~0.4 (quick) | P0 |
| Acc_HaloR3 | gold ring, white feather wings, small white gems | TexID (Tripo API, colour only) | **bake**: gold 1 / 0.2, feathers 0.8, gems 0.05 | P0 |
| Acc_HaloR4 | gold ring, gold emblem, white feather wings | TexID | **bake** gold, feather and emblem masks | P0 |
| Acc_HaloR5 | double gold ring and emblems, gems, large white feather wings | TexID; in game the ring is a dull yellow strip | **bake** from masks; the R5 glow stays a particle effect | P0 |
| Acc_HornsR1, Acc_HornsR2 | small red horns / dark-red curved horns | TexID; shared Blender palette | **remake** (remake_list P3) | P1 |
| Acc_HornsR3 | red ram-curl horns, darker stripe bands | TexID | **bake**: horn 0.35 with a ridge normal, no metal | P1 |
| Acc_HornsR4 | red horns, gold bands, red glow aura | TexID | **bake**: gold 1 / 0.2, horns 0.35 | P1 |
| Acc_HornsR5 | dark-red horns, gold bands, orange gems, flame tips | TexID | **bake** gold, gem and horn masks; the flames stay an effect | P1 |

**Code dependency (게임성 개발 1):** paid Looks are applied by `CharacterVisuals.buildMarkModel` (`src/ServerScriptService/CharacterVisuals.luau:513-514`), which swaps MeshPart.TextureID. Once a mark has a SurfaceAppearance, its ColorMap wins and the Looks stop showing. Runtime code also cannot set SA maps, so each Look needs a prebuilt SurfaceAppearance for the code to clone. This code change must ship together with the mark SA swap.

### 8c. Monsters (zone order)
| model | regions | now | fix | priority |
|---|---|---|---|---|
| GoldenGoose (Crossroads) | golden-yellow feathers, orange beak and webbed feet, blue collar | SA C+N+R (rough 0.86, feather relief in the normal); the Tripo metal is only 4% scattered spots | **ok**. Design call for 검수: a light gold sheen (feather mask metal 0.3-0.5) if "golden" should read as gold. | — |
| Slime (Shard Slime) | green jelly cube body, yellow Crown Shard crystals, painted face | TexID (MonsterSlimeCube, job 6783fd35, colour only) | **remake** (P1 #3): jelly 0.1-0.15 / metal 0, crystal as a gem (low roughness or a separate Glass part) | P2 |
| FlowerSlime | purple jelly body, flower bouquet | No own model: it clones the Slime template, and def.Color is never applied | **remake** (P1 #2) | P2 |
| BigSlime (Slime Prince) | blue jelly cube, gold crown, yellow crystals, painted face | TexID body; the crown is an untextured SmoothPlastic MeshPart (KingSlimeCrown.glb has no maps) | **remake** (P1 #1). Interim: crown → Foil/Metal, Reflectance 0.3 (quick) | P2 |
| SlimeKing (boss) | pink jelly body, gold crown, red ball gems, white fur trim, face | SA C+N+R with roughness ~0.1 on every region, metal empty. The Tripo MR puts metal on 70% of the jelly, so do not connect it | **remake** (P1 #5) with mask-baked metal on the crown only: fur 0.9, jelly 0.12, gems 0.05 | P2 |
| PetBabySlime (follows the player everywhere) | pale mint jelly cube, green sprout leaves, painted face | TexID (colour only) | **bake**: jelly 0.12 / metal 0 with a soft normal, leaves 0.7. Seen up close, so do it early in P2 | P2 |
| PumpkinSlime | ribbed orange pumpkin-jelly body, green stem and curly leaves, small amber crystals, face | TexID | **bake**: skin 0.3-0.4, leaves 0.8, crystals 0.05 | P3 |
| PumpkinKing (boss) | pumpkin body, purple/maroon velvet robe, cream fur trim, gold crown with candles, purple gems, green stem, small jack-o'-lanterns | TexID; in game the crown is dull brown-yellow and the velvet has the same sheen as the pumpkin | **bake**: gold metal 1 / 0.2, velvet 0.85, fur 0.9, pumpkin 0.4, gems 0.05 (optionally Glass parts) | P3 |
| BatGoblin | green skin, purple hood with bat ears and wing cape, leather vest, cloth shorts, rope belt, wooden studded club, orange pumpkin candy bucket | TexID (the raw and the rigged _Idle GLBs are both colour only) | **bake** into the rigged mesh's UVs | P3 |
| LittleGhost | white ghost sheet body, purple striped knit nightcap with pom-pom, orange paper lantern with glowing core, pink cheeks | TexID | **bake**: body 0.4, knit 0.9, lantern 0.3; the glow as a PointLight or small Neon part | P3 |
| GhostMinion | white ghost blob body, face | TexID; a single material | **bake**: satin 0.3-0.4 with a smooth normal. Also clean up the stale `ModelFrom='LittleGhost'` (P1 #9) | P3 |
| GhostKing (boss) | ghost body, purple velvet cape, ermine fur, gold crown with amethysts, gold chain, gold sceptre with glass orb | TexID; the gold is flat yellow-tan | **bake**: gold 1 / 0.2, gems and orb 0.05 (orb as a Glass part), velvet 0.85, fur 0.9 | P3 |
| Goblin | green skin, leather vest, cloth shorts, rope belt, wooden club, small gold amulet | SA C+N+R (old 1024 maps, strong normal; roughness ~0.95 on 95% of texels), no metal | **remake** (P1 #7, already planned). Keep the current maps until then; the HD remake must be followed by a bake. | P3 |
| GoblinBrute | green skin, leather shoulder pads with metal studs, belt with round buckle, loincloth, club with iron spikes, war paint | SA C+N+R, metal empty; `art/models/GoblinBrute.glb` has believable metal (14%: studs, buckle, spikes) | **remake** (P1 #7). Interim: connect the existing metal map (quick) | P3 |
| SlingshotGoblin | green skin, felt hat with feather, leather vest/pouch, cloth shorts, rope belt, wooden slingshot | SA C+N+R (HD v2, 0.56-0.73 by region); no metal in the design | **ok**; keep these maps when rigging (P1 #6) | — |
| Skeleton | bone, rusty iron helmet, cloth tunic, leather belt, rusty sword, wooden round shield with iron rim | TexID (SkeletonClothed, colour only) | **remake** (P1 #7) | P3 |
| SkeletonKnight (also Captain Clatter's body) | dark iron plate armour, purple glowing rune lines, bone, purple cloth cape, sword, orange gem | SA C+N+R, metal empty; the GLB metal covers 29-31% (the armour) | **remake** (P1 #7). Interim: connect the metal map and check that the bones (metal ~0.24) do not turn chrome; runes as Neon trims (quick) | P3 |
| SkeletonArcher | bone, cloth hood and tunic, leather quiver and straps, wooden bow, metal arrowheads and buckles | SA C+N+R (HD v2), metal empty; the HD MR has 2.3% metal on arrowheads, helmet and buckles | **connect** the metal map; keep the maps when rigging (P1 #6) | P3 |
| CaptainClatter (field boss) | borrowed SkeletonKnight ×2.2 | inherits SkeletonKnight (no metal) | **remake** (P1 #4) with full maps from the start | P3 |

### 8d. Held gear and marks (code-built, `CharacterVisuals.luau`)
| model | regions | now | fix | priority |
|---|---|---|---|---|
| Weapon_Sword (Warrior) | wooden handle, dark metal guard, blade per tier | parts: T1 Wood, T2 WoodPlanks, T3 Metal, T4 gold-coloured Metal at Reflectance 0, T5 opaque Glass, T6-T8 flat Neon | **remake** (remake_list P3 / A23-108, Tripo per class × tier, tiers 1-2 first). Interim: T3/T4 Reflectance 0.25-0.4 (T4 Foil), T5 Transparency ~0.35 + Reflectance 0.3, Neon only on an inner core (quick) | gap |
| Weapon_Staff (Mage) | wooden shaft, collar, tip | parts: Wood shaft, Neon ball tip + PointLight at every tier | **remake** (P3 / A23-108). Interim: a Glass orb shell (Transparency 0.3) around a small Neon core (quick) | gap |
| Weapon_Bow (Archer) | 5 arc segments, strings (Beams) | parts by tier material; no grip wrap or metal tips | **remake**: wood limb, leather grip, metal tips | gap |
| Weapon_Baton (Pet Tamer) | wooden shaft, ball tip | parts: Wood + tier material | **remake** (own model per tier) | gap |
| GoldSack, GrudgeSack | burlap sack, knot (new model: gold coins) | parts: Fabric ball | **remake** (P3): burlap roughness, metal coins | gap |
| GrudgeGhost | semi-transparent body + ball head | parts: Neon blocks | **remake** (P3) | gap |
| NeutralGear (Artisan Guild mark) | gear disc and teeth | parts: 3 teal Neon blocks | **parts**: teal Metal gear (Reflectance 0.3) with Neon only on a small hub (quick). Whether Artisans get a modelled rank ladder like Halo/Horns is a design call for 검수 | gap |
| MarkHalo (Redeem cracked halo) | 4 cracked halo shards | parts: Neon | **parts**: Foil/Metal gold shards, Reflectance ~0.35, with a soft PointLight (quick) | gap |
| MarkCape (Fall torn black cape) | 3 black cloth strips | parts: Fabric | **ok** | — |

---

## 9. Where the four audits disagreed (decided here, 검수 to confirm)
- **K_CrownShard_v2:** one audit said to connect the import_D11 bundle metal. The bundle and HD MR are metal ~1 / rough ~0.01 on every texel, including the red half and the gems, so connecting would turn the whole shard chrome. Listed as **bake**.
- **Slime and Skeleton:** materials_table marks them `source_has_pbr_unused`. That is a false name match: `art/models/Slime.glb` and `Skeleton.glb` are older Tripo jobs. The in-game meshes are MonsterSlimeCube and SkeletonClothed, both colour only. Listed as **remake** (already P1 #3 / #7).
- **Goblin:** one audit called its maps fine (strong normal, no metal needed). The other measured roughness ~0.95 on 95% of texels, so every region reads as one clay. It is already in remake P1 #7, so it is listed as **remake**, keeping the current maps until then.
- **NPC_HaloBright:** "connect with a cloth override" and "bake roughness, keep Tripo normal + metal" amount to the same work. Listed as **bake** (roughness only).
- **GoldenGoose:** "ok" against "needs a gold bake". Listed as **ok** plus a design call.
- **Kit_W_Fern:** materials_table says 'add MetalnessMap', which is wrong (9% bogus metal on leaves). Keep it empty.
- **zone_check_halo #65 vs A23-107:** #65 wants colour-only 512 maps on small props for phone memory; A23-107 wants 4 maps everywhere. Suggested compromise: 4 maps at 512.

---

## 10. Material recipe (Blender bake values, reusable)

| material | metalness | roughness | normal detail (strength / target mean tilt) | Roblox note |
|---|---|---|---|---|
| Gold, polished (crowns, trims, coins, halo rings) | 1.0 | 0.15-0.25 | mesh normal only | Albedo must be bright gold (about sRGB 220-255 / 170-200 / 40-90). Dark ochre with metal 1 turns olive, so lift it. Part alternative: Foil/Metal, Reflectance 0.3-0.5 |
| Silver / polished steel (armour, blades, spear tips) | 1.0 | 0.2-0.35 | mesh only | Albedo light grey 170-220. Silver-coloured stone on buildings and statues stays non-metal |
| Iron, forged or dark (anvil, brackets, hoops, chains, bolts) | 1.0 (rust patches 0.6) | 0.4-0.55 (rust 0.7) | fine noise 0.3 / 3-5 deg | Albedo grey 90-130, not black |
| Brass / bronze (gears, rivets, bands) | 1.0 | 0.3-0.4 | mesh only | Lift the ochre like gold |
| Marble | 0 | 0.4-0.5 | faint veins + block seams 0.4 / 5-8 deg | |
| Cut stone, plaster, white town stone | 0 | 0.7-0.8 | stone-block/chisel 0.8-1.0 / 8-15 deg | On big buildings (~11 px/stud) use block seams, not fine grain |
| Rock, boulders, cliffs, basalt | 0 | 0.75-0.85 | height from luminance 1.0 / 10-15 deg | Basalt albedo at least ~50/255 so the texture reads |
| Raw wood, planks, logs | 0 | 0.8-0.9 | grain along the board 0.6-0.8 / 8-12 deg | |
| Bark | 0 | 0.85-0.9 | bark ridges 1.0 / 12-15 deg | |
| Painted wood / painted iron | 0 | 0.45-0.55 | grain 0.3 / 3-5 deg | |
| Lacquer, enamel (red Horns half) | 0 | 0.15-0.25 | mesh only | |
| Cloth, banners, cotton, tents | 0 | 0.85-0.95 | weave 0.3-0.5 / 4-8 deg | Use the weave only when one thread is at least 4 texels. Flat banners: a thin Part with Fabric material and the Firefly image on both sides |
| Velvet, felt, knit | 0 | 0.85-0.9 | knit 0.5 | |
| Fur, ermine, fluffy trim | 0 | 0.9-0.95 | strand noise 0.5 | |
| Leather | 0 | 0.5-0.6 | pebble grain 0.3-0.4 / 3-6 deg | |
| Straw, wicker, rope, hay | 0 | 0.85-0.9 | weave/twist 0.6-0.8 / 6-10 deg | |
| Leaves, grass, moss | 0 | 0.7-0.9 (moss 0.9, waxy leaves 0.55-0.65) | leaf noise 0.4 / 4-8 deg | |
| Petals | 0 | 0.55-0.65 | mesh only | |
| Skin | 0 | 0.5-0.6 | mesh only | |
| Hair | 0 | 0.45-0.6 | strand 0.3 | |
| Horn (keratin) / bone | 0 | 0.35 / 0.6-0.7 | ridges 0.4 | |
| Ceramic or glazed tiles | 0 | 0.3-0.4 | tile seams 0.5 | |
| Pumpkin skin, toy plastic, berries, apple | 0 | 0.25-0.45 | mesh ribs only | |
| Jelly / slime | 0 | 0.1-0.2 | soft low-frequency 0.2 / at most 3 deg | |
| Ghost body (satin) | 0 | 0.3-0.4 | mesh only | |
| Cloud fluff | 0 | 0.85-0.9 | soft noise 0.3 | |
| Glass (windows, bottles, lantern panes) | 0 | 0.03-0.08 | flat | One opaque mesh can never be see-through, so use a separate Part: Material Glass, Transparency 0.3-0.5, Reflectance 0.2-0.3. Lit panes: Neon + PointLight |
| Gems, crystals | 0 | 0.02-0.05 | flat | A separate Glass part (Transparency 0.2-0.4, Reflectance 0.3); for a glowing gem, a small Neon core inside |
| Water | 0 | 0.03-0.08 | soft ripple 0.2 | A separate Glass part (Transparency 0.3-0.5, Reflectance 0.15-0.3) or terrain water; waterfalls the same |
| Fire, lava, glowing runes, lamp cores | — | — | — | Neon part + PointLight / ParticleEmitter. Our SurfaceAppearance pipeline has no emissive channel |

**Bake steps**
1. **Masks.** Build region masks from the 4096 colour texture with `tools/pbr_from_color.py`, adding per-model overrides for these rules: water and stained glass are not cloth, lit glass is not gold, and silver depends on context. Hand-paint the masks where hues overlap.
2. **Roughness.**
   - Fill each mask with its table value, add ±0.05 low-frequency noise, and blur the mask edges by 1-2 px.
   - Roughness separates shiny from matte. Among the matte materials (stone, wood, cloth), the normal detail does the work, so do not expect 0.62 vs 0.78 vs 0.85 to show in Studio.
3. **Metalness.**
   - Set it to 0 or 1 by mask only, with edges feathered by 1-2 px.
   - Never put metal on cloth, wood, jelly, leaves or skin.
   - Lift the albedo of the metal regions (dark ochre → bright gold), then check by eye for chrome-grey or olive.
4. **Normal.**
   - Keep the Tripo/mesh normal and blend in a tileable detail normal per region at the table's strength (whiteout/UDN in numpy: add the XY, keep Z, renormalise).
   - Tripo HD normals measure 2-5 deg mean tilt, so stone, wood and bark need 3-5× more.
   - Detail scale: a stone block is about 1-2 studs, wood grain spacing about 0.25-0.5 stud.
   - Use OpenGL (+Y) tangent space, the same convention as glTF.
5. **Export.**
   - Write four PNGs per piece: Color (sRGB), Normal, Roughness (grey), Metalness (grey).
   - Use 1024 for large pieces and split tiles, and 512 for small repeated props.
   - glTF packs roughness in G and metalness in B of `metallicRoughnessTexture`, so split the channels before upload.
6. **Check a Tripo MR before you connect it.** Open its MR sheet first.
   - Do not connect when metal sits on non-metal regions: SlimeKing (70% of the jelly), K_CrownShard (metal 1 everywhere), Kit_W_Fern (9% of the leaves), X_GooseNest (wood and teal).
   - Do not connect when roughness is a single value: the H6 NPCs, X_Altar, W_GateOpen 0.28, R_Gate 0.82.
   - Tripo web HD exports usually have near-flat normals (mean deviation 0.01-0.04), uniform roughness and metal 0. Every Tripo HD remake therefore still goes through steps 1-5.
7. **Pass rule (A23-107).** Compare same-angle Studio crops at 100%, PBR vs matte:
   - The stone, wood and cloth crops differ by more than 5/255 on average and look different by eye.
   - Glass, water and gems read as see-through.
   - Gold reads as gold, not olive or grey.

---

## 11. Counts

**This list:** 183 table rows; some rows group several models. Counted by `audit3d/count_redo.py`.
- 87 bake
- 55 remake
- 17 parts
- 5 connect
- 19 ok

**By priority:**
- P0: 35 (Halo town; 8 of these rows are live in main now)
- P1: 11
- P2: 50
- P3: 51
- P4: 9
- gap: 8
- —: 19

**Per section (bake / remake / parts / connect / ok):**

| section | bake | remake | parts | connect | ok |
|---|---|---|---|---|---|
| Halo | 17 | 11 | 3 | 1 | 2 |
| Horns | 0 | 7 | 1 | 0 | 0 |
| Crossroads | 14 | 7 | 2 | 3 | 2 |
| Meadow | 16 | 4 | 3 | 0 | 4 |
| Halloween | 4 | 2 | 2 | 0 | 2 |
| Woods | 20 | 3 | 2 | 0 | 4 |
| Ruins | 3 | 3 | 2 | 0 | 2 |
| Characters / monsters / items | 13 | 18 | 2 | 1 | 3 |

**Committed place file** (10/09, 1310 MeshParts in Workspace):
- 229 have SA C+N+R, 1067 are TextureID only, 14 are untextured.
- 0 of 298 SurfaceAppearances have a MetalnessMap, so full 4-map PBR = 0.
- materials_table classes over 460 rows: 241 color_only, 88 pbr_no_metalness, 82 plain_parts, 43 unknown, 6 source_has_pbr_unused.
- The 122 rows placed in Workspace: 67 color_only, 34 plain_parts, 19 pbr_no_metalness, 1 source_has_pbr_unused (HornsCastle), 1 unknown.

Files: C:/Users/glori/AppData/Local/Temp/claude/C--Users-glori-Documents-Roblox-Game/b2930c75-ef84-4cbc-952a-619ee0ded1b8/scratchpad/audit3d/materials_redo_list.md (this list) and C:/Users/glori/AppData/Local/Temp/claude/C--Users-glori-Documents-Roblox-Game/b2930c75-ef84-4cbc-952a-619ee0ded1b8/scratchpad/audit3d/count_redo.py (counts the rows).

---
## 비판자 고침
The draft holds up overall. These corrections are needed before it goes out.

**A. The answer to the user's question: add one line**
Your answer says the new Halo set has four maps but they barely change the look. It never says that some new pieces render plain grey. Suggested line:
- "새 세트 일부 조각은 연습 장소에서 회색으로 나와요(돔집 A는 거의 전부)."

Evidence: `art/review/world/halo_new/split/house_after3.png` and `gate_after3.png` (11:51). The sharpness list (§0-1) also saw grey pieces on the Gate, Cathedral, Tower, Statue, bridge deck and fountain splits (10:47–10:57). Recheck those pieces; don't only flag DomeHouseA.

**B. "ok" verdicts that are wrong (stats from `whh/texstats_out_*.json`, renders looked at by eye)**
| model | placed | what the maps show | fix |
|---|---|---|---|
| Kit_W_MossRock | ×37 | Rock roughness is 0.19–0.27 and moss 0.52–0.58, so the stone is the shiniest part. Normal tilt is about 0.7°. The PBR render looks the same as the plastic one (`sk/ok_suspect.jpg`). | bake: stone 0.75–0.8 with bump, moss 0.9 (P3) |
| Kit_W_BushA / Kit_W_BushB | ×35 / ×45 | Leaves are 0.20–0.54 (BushA) and 0.23–0.32 (BushB). BushB visibly looks wet. Your own recipe says leaves 0.7–0.9. | roughness re-bake (P3) |
| Kit_W_StepStones | ×13 (6 meadow, 7 woods) | Grey stone tops are 0.22, a polished look | bake: stone 0.75 plus stone normal (meadow copies P2) |
| Kit_X_PlazaStairs / Kit_X_PlazaWall | not placed | 8% and 3.6% of texels are gold-coloured, with 0 metal (`cm2/mr_stats.json`) | bake a metal mask (P4) |

- **Fine to leave, but note it:** PillarB's moss is 0.47, the same as its marble. StumpTable is 0.6 everywhere and Willow 0.55 everywhere.
- **Random sample of four "ok" rows** (seeded): P_TreeAutumn_B, Kit_P_HayBales, Kit_W_Awning, Kit_R_PillarB.
  - By eye they read fine (`sk/ok_crops.jpg`), but only because the material is painted into the colour map.
  - Each has one roughness value (std ≤0.04) and a near-flat normal (0.6–1.9°).
  - Say this outright in the list: "ok = matte-only model, read comes from the paint."
- Split the woods row that groups StepStones/LogStool/MossRock/BushA/BushB. Then re-run `count_redo.py`.

**C. Models missing from the list (`sk_missing.py`, `sk_missing2.py`, `sk_glbmiss.py`)**
- **The 22 `GE_*` MaterialVariants have a colour map only** (no normal, no roughness). They replace Marble, Slate, Basalt, Cobblestone, Rock, Limestone, WoodPlanks, Grass, Sand, Ground, Mud, Asphalt, Salt, Sandstone, Pavement, LeafyGrass and CrackedLava everywhere: on terrain and on every Part that uses those materials.
  - Several "parts" fixes therefore go wrong:
    - Disc → Sandstone gives `GE_MeadowShade` (meadow grass).
    - LilyPads → Grass gives `GE_Grass` at 22 studs per tile.
    - Bridge_Halo deck → Marble, and Roads → Slate/Cobblestone, get flat colour tiles.
    - Weapon tier 2 (WoodPlanks) gets the terrain planks texture.
  - The "ok" part rows (Bridge_Meadow, PumpkinPatchSign, Bridge_Goblin, Tombstone, Roads) are only as good as these colour-only variants.
  - Also, `Use2022MaterialsXml=false`, so the materials without an override (Metal, Foil, Fabric, Glass, Wood) may draw in the old pre-2022 style (my reading of the flag). Check them by eye in Studio.
  - **Fix:**
    - Give props their own variants, set per part with `Part.MaterialVariant`: colour, normal, roughness (and metal where needed), StudsPerTile 2–6.
    - Add normal and roughness maps to the GE_* set.
    - Add this as its own row group, with GE_HaloTiles, GE_Limestone and GE_Marble at P0.
- **Unused copies (no work, but add one line so the 460-row table matches):** KitStage K_* ×20, CrossroadsKOld ×19, and the KitOld, MapV1Backup, ZoneSwapOld and primitive backups. `MapBuilder` takes only the GF_* models from KitStage.
- **Fold into existing rows:**
  - Town_Horns_Castle_B2 [9 tiles] (`build/import_H`, colour only) and Town_Horns_Castle_nowin (HD, has MR + normal) → the HornsCastle row.
  - SlimePrinceBody4, SlimeBodySmooth and Mon_SlimeCube_Backfix → the Slime/BigSlime remake.
  - SkeletonKing and SkeletonKingClothed: there is no such monster in Config, so ignore them.

**D. Recipes that would look wrong in Roblox**
1. **Gold at metal 1 / rough 0.15–0.25 reflects the sky and the green ground.** In `gate_spec_compare.jpg`, the underside of the halo ring turns olive at specular 1.0. The Ruins zone runs at 0.8. So olive comes from the reflection tint, not only from a dark ochre albedo.
   - Use roughness 0.3–0.4 on gold that faces down or out, and check it at each zone's specular value.
2. **The pass-rule measurements were taken in practice light, which hides differences.** WorldKit uses Spec 0.3 / Diff 0.3. Main uses Spec 0.6 / Diff 0.5 (WarService), all files still say Technology=1 (A23-105 Unified migration), and the LightingStyle is Soft. Measure 5/255 in main's light.
3. **Transparent Glass windows on solid buildings show the wall behind them.** A23-106 keeps buildings solid. For windows, use an opaque dark glass SurfaceAppearance (roughness 0.05–0.1) with a night glow. Keep transparent Glass for lantern cores, water over a basin and bottles.
4. **"No emissive channel" in §10 is wrong.** SurfaceAppearance has `EmissiveMaskContent` (set in Studio by a plugin) plus `EmissiveStrength` and `EmissiveTint`. The class reference lists no security tag on those two, so scripts can likely set them at runtime — check once in main Studio. That covers night lamps (A23-105), lava, runes and gem cores inside one mesh. PointLights are still needed to light the surroundings.
5. **`SurfaceAppearance.Color` can be set by script** (with TintMask alpha). That covers the FlowerSlime, SlimeKing and CaptainClatter tints without new maps.
   - The faction marks' Looks (Ice, Gold, Platinum, Lava, …) change material, not only colour. So the §8b note holds: plan about 40 prebuilt SAs (10 Looks × 4 rank textures).
6. **Gems and orbs as separate Glass parts are hard on rigged monsters and worn marks** (they must be attached to bones). On those, keep the gem in the mesh with low roughness plus an emissive mask.
7. **Banners as a Part with a Decal** probably lose the Fabric texture under the image (decals draw over the material). Use a thin double-sided MeshPart with a SurfaceAppearance instead: the Firefly image, a weave normal and roughness 0.9.
8. **Steps missing from the export recipe:**
   - Keep colour maps fully opaque. The default AlphaMode is Overlay, which shows MeshPart.Color through any alpha below 255.
   - Pad UV islands by 8–16 px so lower mip levels don't bleed the gutters.
   - Save roughness, metalness and normal maps as Non-Color with the Standard view transform, then check that a 0.85 mask reads 217 in the file.

**E. Roblox limits and phone memory**
- The texture page (updated 2026-10-08) says images can be up to 4096, but PBR maps top out at 1024. Its budget is 256 px per 2×2×2 studs.
- Check one asset in Studio before converting the 4096 colour-only models (Kit_M_*, Kit_X_Curb). If their texture really draws above 1024, moving it into a SurfaceAppearance at 1024 makes it blurrier.
- **Proposed sizes:**
  - Colour and normal by that budget.
  - Roughness and metalness at half size.
  - Single-value maps at 64 px.
  - Leave MetalnessMap empty where there is no metal, and split pieces by material so walls carry none.
  - Save roughness and metalness as 8-bit greyscale.
- **Rough estimate (my guess, depends on compression):** the P0 plan (46 split tiles × 4 maps at 1024, plus NPCs and props) is about 150–250 MB if everything is loaded at once. Roblox loads low quality first and may downsample when many textures are on screen, so on phones the cost shows up as blur, which works against the sharpness list. Half-size roughness/metalness and no metal map on stone pieces cut roughly 30–40%.

**F. Conflicts with `sharpness_redo_list.md` (same folder)**
- Halo_Planter: bake at 512 here, new Tripo model there → make it **remake**.
- DomeHouseA/B, Shop, Stairs, ArchBridge: bake here, split into 3–4 pieces with new UVs there. Split first and bake once, or the bake is done twice.
- Small props: the sharpness list wants 1024. The budget and the measured 64–85 px/stud support 512 colour/normal with 256 roughness/metal.
- The sharpness list asks for 3–5 variants of each repeated prop. If that stands, RoundTree, CloudBush, Topiary, PotFlowers, Balustrade and Lantern become remakes.
- Crossroads fountain: split and bake X_Fountain (sharpness list) or make a new one (this list)? 검수 picks.
- Sharpness §0-2 (small props stripped of maps) is out of date: `halo_props.luau` `clean()` no longer strips them after 5726f07b. WorldKit copies placed before that may still lack normal and roughness, so rebuild them before measuring.

Files are in `C:/Users/glori/AppData/Local/Temp/claude/C--Users-glori-Documents-Roblox-Game/b2930c75-ef84-4cbc-952a-619ee0ded1b8/scratchpad/audit3d/`:
- `sk/ok_sample_game.jpg`, `sk/ok_crops.jpg`, `sk/ok_suspect.jpg`, `sk/split_after3.jpg`, `sk/marketarch_metal_zoom.jpg`
- `sk_missing.py`, `sk_missing2.py`, `sk_glbmiss.py`, `sk_okstats.py`

Sources:
- [Texture specifications](https://create.roblox.com/docs/en-us/art/modeling/texture-specifications.md)
- [SurfaceAppearance (class reference)](https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance)
- [Surface appearance (guide)](https://create.roblox.com/docs/art/modeling/surface-appearance)
- [Lighting (class reference)](https://create.roblox.com/docs/reference/engine/classes/Lighting.md)
- [Enum.Technology](https://create.roblox.com/docs/reference/engine/enums/Technology)