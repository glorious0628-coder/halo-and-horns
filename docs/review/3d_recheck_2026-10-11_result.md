# 3D 다시 검수 결과 (A23-122, 2026-10-11)

- 대상: 지금 게임에 있거나 새 빛 마을에 쓸 3D 204개. 그중 25개는 Studio 골격 후보(A23-120)라 자동으로 '골격으로 다시', 나머지 179개를 판정했다.
- 방법: Blender로 앞·옆·뒤·3/4·근접 렌더 + 2D 비교 시트(art/review/recheck_2026-10-11/sheets/, 디스크에만) → API Sonnet 1차(179개, 약 $6) → 1차 '통과' 43개를 API Opus가 반박 검수(약 $2.3).
- **결과: 178개 다시, 1개 판정 불가(X_SupporterBoard, GLB 없음).** 통과 0개.
- 가장 많은 실패: 13번 세 단계(records.json에 Blender 손보기 기록 0건) · 4번 형태(둥근 부품이 둥글지 않음, 구멍, 떠 있는 조각) · 3번 2D와 다름 · 1번 뭉개짐 · 12번 면 수(몬스터 1.1만~2만 면).
- 앞면 한 장으로 만든 모델은 뒤·옆이 뭉개진 것이 많다. 그래서 거의 모두 4면으로 다시 만든다.

## 다시 만드는 순서 (구역 차례 A23-97 + 빛 마을 다시 짓기 A23-121)

### ① 빛 마을 v2 재료 — 4면 Tripo(HD H3.1 멀티뷰)로 다시 → Blender 손보기 → Roblox 재질 (지금 구역, 이미지 생성 2가 4면 그림 → 이미지 생성 3) — 70개
- HaloDomeHouse_01: 3D has two gold cupolas and a wooden roof planter box (3/4 view); the 2D shows one cupola. The stone joints on the back and side walls are faint and soft (back view).
- HaloDomeHouse_02: 100% edge crop (row3 middle, right edge) and 2x close-up: the corner finials/pinecone spires are lumpy, uneven blobs and the wall lanterns beside the door are soft, melted frames; 
- HaloDomeHouse_03: The gold dome and the round tower body are faceted and lumpy: the rim is polygonal and the ribs are uneven (3/4 view and the dome 100% crop). The 2D has a smooth round dome.
- HaloDomeHouse_04: 100% edge crop (row3 middle): dome ribs wobble and are unevenly spaced, and in the 2x close-up (row3 left) the gold rosette medallion over the door and the door's twin knobs are lu
- HaloDomeHouse_06: The awning stripes are blotchy and smeared, with a mottled pale-mint stripe (2x close-up, bottom left, and centre crop). This is a texture seam or mush.
- HaloDomeHouse_08: 2x close-up (row3 left): the balcony balusters and the door's gold knobs are soft, fused blobs, and the whole close-up is blurry; the back view (row2 middle) upper drum is a blank 
- HaloDomeHouse_10: The awning stripes are blotchy and smeared, with a mottled mint stripe (2x close-up and the 100% crop of the edges). The tower body is polygonal and uneven (3/4 view).
- HaloDomeHouse_12: The back view lower wall is a large blank smeared panel with no clean stone joints. The rooftop pergola beams are thin flat white strips that look half floating (3/4 view and back 
- HaloFlowerPotHQ_Daisy: The pot gold frames and panels are smeared and jagged (100% crop, centre bottom). The pot is a lumpy, uneven octagon with warped panels (side and back views).
- HaloFlowerPotHQ_Lavender: The vase is faceted and lumpy, not round, and the gold rings are wobbly and orange-brown (100% crop, left; side views). The base is chipped and uneven.
- HaloFlowerPotHQ_Rose: The marble bowl is faceted and cracked-looking, and the gold foot and rim are lumpy and uneven (3/4 view and the 100% crop, left). The bowl is not truly round.
- HaloFlowerPotHQ_Sunflower: Jagged white triangle shards and texture breaks on the back and side stone panels of the pot (back view, lower left). The pot rim is wavy and slightly out of round.
- HaloFlowerPotHQ_Tulip: The pot side panels have torn, creased triangles and gray smudges (front view lower panel and the 100% crop, centre). The panels lack the clean gold frames the 2D shows.
- HaloPart_CathBody: The columns and walls have gray smears and creased stone patches (2x close-up, left; the 100% crop). The top slab edge is wobbly and lumpy (3/4 view, top).
- HaloPart_CathDome: The dome gold is olive and blotchy, with neon-yellow patches and brown spots on every view (2x close-up, left; front view dome).
- HaloPart_CathTowerA: The tower wall stone is streaky and smeared with gray, with no clean joints (100% crop, centre, and the right and left views).
- HaloPart_CathTowerB: The tower shaft stone is streaky and smeared, with no clean joints (100% crop, centre, and the back view). The shaft edges are wavy and the lobed base is lumpy.
- HaloPart_CathWindow: The back view is one flat blue glass pane with no mullions or star bar, while the front has them (back view versus front view). The arch frame is slightly uneven and the glass look
- HaloPart_GateArch: The stone blocks have crumpled triangle creases and warped joints across the whole wall (front, back and the 2x close-up). The gold arch band is wavy, and its left leg is crooked (
- HaloPart_GateDomeR: The gold is covered in angular hot-white shards and torn patches (2x close-up and the front 100% crop, with a visible notch near the centre). The ribs are uneven and the rim is wav
- HaloPart_GateDoorLeafL: The right/left views (row2 sides) show the leaf as a thick solid gold slab (size y 0.276 vs x 0.458, so more than half as deep as it is wide), not a door plank; the frame side is o
- HaloPart_GateLantern: The lantern glass (front/3/4, row1) is pale grey-white with no warm glow vs the 2D, the shaft stone in the 2x/centre crops (row3) is smudgy with blurred joints, and none of the cro
- HaloPart_GateTowerL: The tower wall stone is streaky, creased and smeared gray, with torn block joints (back and left views, and the 100% crops). The stone blocks have no clean joints.
- HaloPart_GateTowerR: The 3D does not match the 2D: the 2D has three tall blue arched windows with gold frames and two gold bands, but the 3D has small orange slits and no blue glass (front view versus 
- HaloPart_TowerBody: The windows are gold-filled blobs with no glass, and the white wall is streaky with no stone joints (2x close-up and the centre crop). The back view has an odd half-open arch niche
- HaloPart_TowerDoorFrame: The gold vertical strips on the piers are wavy and streaky, and the stone blocks beside them are uneven (100% crops, left and centre). The two piers are not mirror-perfect and look
- HaloPart_TowerDoorLeaf: The front has three hinge straps, but the 2D has two (front view, a third strap at the bottom). The back view has two straps. There is a brown fleck and a spike on the thick gold s
- HaloReasonHQ_BenchA: The wood is torn and shattered at the seat ends, and the stone legs have crease shards (right and left views, middle left and right). The side views show two stacked gold balls tha
- HaloReasonHQ_BenchB: There are black triangular holes in the planter wall and torn, twisted stone at the arm (front view lower left; right view). The planter and arm shapes are warped, and the sides do
- HaloReasonHQ_BenchC: The plank end face is a torn, shattered gold-brown patch (right and left views, upper right of the post). The post sides have crease shards.
- HaloReasonHQ_BreadStand: The striped cloths are shattered into blue and white shards instead of clean stripes, and the bread looks like shiny metal (100% crops, bottom). The side panels show a grey blank w
- HaloReasonHQ_Clothesline: The towel stripes are smeared and jagged, and the white towel's bottom band is a ragged zig-zag instead of a clean stripe (2x close-up, left; 100% crop). The towels are mushy.
- HaloReasonHQ_FlowerCart: The striped awning is shattered into big blue and white shards with a ragged hem instead of clean scalloped stripes (front view top; 100% crop, left). The flowers are faceted blobs
- HaloReasonHQ_FruitStall: The back view is a smeared, plain beige panel with black tear marks and melted crates (back view). The awning stripes are shattered and the wood is blurry (100% crops).
- HaloReasonHQ_GuardPost: 100% edge crop (row3 middle): the sign panel is a grey crumpled sheet with folds and its gold frame posts are bent, and the back view (row2 middle) wall has crease and dent marks a
- HaloReasonHQ_PotionCrate: front/crops: blue-white striped banner on crate is smeared into diagonal shards, 2D has clean vertical stripes; edges stair-stepped in crops
- HaloReasonHQ_RackShieldSword: shield faces (front crops) have smeared blue/white stripes with jagged shard breaks vs clean stripes in 2D; back view shows shields as hollow gold rings with a wooden X in front
- HaloReasonHQ_Scarecrow: front crops: blue/white tunic has glossy faceted light patches with brightness breaks (looks like glass shards, not soft cloth); 3/4 view base top has lumpy bright facets
- HaloReasonHQ_VegGarden: right view: one stone wall panel is a big crumpled, jointless slab; crops show blurry smeared watering can and faceted lumpy tomatoes/cabbages
- HaloReasonHQ_Woodpile: front crops: log ends are metallic gold blobs with no wood rings and with triangular facet breaks (2D shows pale wood with growth rings); gold posts too orange/streaky
- HaloShop_Bakery: Centre and 2x crops (row3 left/right): the gold sign plaque has a hard diagonal shading break across its face, the bread display behind the window is baked-in and blurry, and the d
- HaloShop_Flower: right/left/3-4 views: glass roof frame is lopsided, a gold bar slants across the roof and the roof has no glass panes (only a wire frame), unlike the 2D greenhouse
- HaloShop_Juice: front crops: shop interior (juice jars, fruit, shelves) is a blurry baked texture; roof canopy is a pointed umbrella without the 2D's scalloped edge and flatter shape
- HaloShop_Potion: 100% edge crop (row3 middle): the dome ribs that are crisp in the 2D are almost gone on a lumpy gold surface, and in the 2x close-up (row3 left) the potion shelf, cauldron and door
- HaloVar3_Lantern_E: crops: blue window panes have crumpled creases and bright smudges, the white stone steps and block are wavy/lumpy rather than straight-edged
- HaloVar3_Planter_E: right/left views: upper bush floats out to the side beyond the tower, creased torn stone faces on sides and back; crops show stair-stepped, smeared gold stripe and window ornaments
- HaloVar3_PotFlowers_E: crops: pot body is a lumpy faceted bowl with creased panels and black cracks, jagged blurry window ornaments; flowers are crumpled shards without the round golden centres from the 
- HaloVar3_PotFlowers_F: crops: urn body is faceted with crumpled triangle creases (not smooth marble), blue gems are bent shards and the base is torn/lumpy; ivy is clumpy and much sparser than the 2D
- HaloVar3_RoundTree_E: crops: fruit are faceted metallic-gold nuggets, not round oranges; planter wall has crooked panels with triangular creases and a wobbly gold rim; grass top is replaced by loose lea
- HaloVar3_RoundTree_F: all views and crops: planter wall is crumpled, dented stone with a wobbly smeared gold rim; willow leaves are sharp low-poly shards instead of the 2D's smooth rounded leaf clusters
- HaloVar3_RoundTree_G: crops: planter wall is dented and smeared, gold rim wobbly with brownish patches, grass top missing (muddy flat disc), windows blurry; same planter as RoundTree_E/F
- HaloVar3_Topiary_C: Right/left/back views (row2): the round white pot has crease dents and flat facets on its wall, and in the 100% edge crop (row3 middle) the gold rim is rough and the blue window ge
- HaloVar3_Topiary_D: 3/4 and side views: octagonal pot is uneven (sides different widths, corners wobbly) with creased wall panels and a bent gold base
- HaloVar3_Topiary_E: front/back/left crops: pot walls have big torn triangular smooth slabs with missing/ragged window gems; hedge is crumpled shards, not the neat leafy cube; base window ornaments sme
- HaloVar4_Lantern_A: centre crop: gold inlay lines on the shaft are wobbly and smeared into the marble; lantern glass is clear/grey-ish, not the warm glowing cream of the 2D
- HaloVar4_Lantern_B: 2x close-up (row3 left): the globe's gold ribs and equator band wobble and change thickness, and the gold base line at the bottom (100% crop, row3 middle) is wavy; the pedestal pan
- HaloVar4_Lantern_C: front crops: gold inlay lines on shaft and base panel are frayed/torn and uneven, baked into the marble instead of sharp separate trim
- HaloVar4_Lantern_D: centre crop: round shaft has grey streaks and dents, panel trim lines are frayed; lantern glass has smudged streaks and no glow
- HaloVar4_Planter_A: all views/crops: gold ball finials are melted orange crumpled blobs, stone wall and panels are smeared flat with torn triangular faces and black cracks; flowers are crushed paper s
- HaloVar4_Planter_D: front crop: panel frames on the octagon pot are smeared, with creased flat grey panels and uneven wobbly gold band; flowers are small crushed shards, 2D has clean round white flowe
- HaloVar4_PotFlowers_A: front crops: bowl is lumpy and faceted with creased panels, a black tear in the base, wobbly gold bands; flowers are bent star shards, not round-petal flowers with gold centres
- HaloVar4_PotFlowers_C: 100% crops (row3 middle/right): the urn's gold ribs wobble and the marble lobes are lumpy and blurry, and in the 2x close-up (row3 left) the flowers are faceted crystal-like shards
- HaloVar4_PotFlowers_D: crops: wide bowl has crumpled dented facets, gold rim is wobbly and bends in the front crop, base ring lumpy; flowers are smeared shard shapes instead of round-petal flowers
- Halo_Statue: front crop: helmet has no dark visor slit like the 2D (smooth blank face plate), and the plinth/top disc in the 3/4 view has a crumpled uneven edge
- Halo_Tower_v2: 100% edge crop (row3 middle): the door wood is smeared and soft and the white block courses bulge unevenly up the shaft; in the right/left views (row2) the banner is a flat strip w
- NPC_HaloBakerGranny: back view: a plain skin-coloured flat block shows under the hair at the back of the head (no hair there), and the chef hat/hair are lumpy blobs; face crop is a flat box with soft, 
- NPC_HaloBright: 3/4, right and back rows: a second halo ring floats beside the first one (2D has one), and the helmet looks grey translucent/glassy in side views; side-view match score only 0.51
- NPC_HaloFlowerGirl: front/close-up: face is a smeared wedge with melted eyes, no smile, no freckles (2D has a clear smiling face); a black stray mark on the skirt front
- NPC_HaloSirGleam: left/right/back views: helmet is a lumpy, glassy grey blob with a fused plume (3/4 view shows only a thin spike plume instead of the 2D swoosh); armour reads as dark smudged chrome
- Town_Halo_Fountain3: front/side rows: more gold-ball posts than the 2D (2D has 4 corner posts, model shows 6+ with doubled balls), and the water jets are flat ribbons that stop/fold oddly; 100% crops o

### ② 빛 마을 v2 재료 — 모양은 쓸 만함, Blender 손보기(둥근 부품·면 줄이기·4장 맵)만 — 11개
- HaloDomeHouse_05: 100% edge crop (row3 middle, door left) the door-knocker ring has uneven thickness and is not a clean circle (same defect as _07), and the gold bands on the corner columns change t
- HaloDomeHouse_07: 100% edge crop (row3 middle) and centre crop: the door-knocker ring is lumpy and not round, and in the 3/4 view the wall drum and roof rim are polygonal and uneven: raw Tripo shape
- HaloDomeHouse_09: 2x close-up (row3 left, door centre): the door-knocker ring is a bent, squarish lump, not a round ring (same defect as _07); no Blender touch-up in records.json.
- HaloDomeHouse_11: Pale, thin blue flaps stick out at the roof corners and edges (right and left views, front corners). They look like torn or unfinished tile strips.
- HaloPart_CathDoorFrame: The pier bases have creased triangle shards in the stone (front and back views, lower left and right). The piers and arch are slightly crooked and asymmetric (3/4 view).
- HaloPart_CathDoorLeaf: The 3/4 and right/left views (row1 right, row2 sides) show a boxy gold block sticking out at the top of the arch that is not in the 2D, and in the 100% crops (row3) the wood is the
- HaloPart_GateDomeL: The gold is blotchy, with brown stains and hot-white patches in the baked texture (2x close-up, left; front and 3/4 views). The ribs are unevenly spaced and the rim is wavy.
- HaloPart_GateDoorLeafR: A stray white triangle shard sits on the blue planks of the back view, and the planks have creased streaks (back view, middle left; front 2x close-up). The stone frame blocks are u
- HaloPart_TowerDome: 2x close-up and 100% crops (row3): the gold dome ribs wobble and are unevenly spaced, the dome surface has dented blotchy highlights instead of a smooth round shell, and the window
- HaloPart_TowerWindow: The window glass is shattered, with torn orange streaks and crease triangles (100% crop of the edges, centre-right; 2x close-up). The gold frame is dull brown-olive with dark spots
- NPC_HaloJuiceMan: detail 2x (top row left): blue hat band is torn/notched at the right end and the hat crown is lumpy; apron pocket and body show faceted crease lines

### ③ 지금 메인 빛 마을 키트 — 새 마을(6단계)이 들어가면 빠짐. 새 마을에 다시 쓸 것만 ①로 — 14개
- Halo_Cathedral: centre crop/close-up: gold dome is crumpled foil with wavy dents, door, windows, banners and stairs are melted and blurry baked into one 4096 texture; towers differ and lean
- Halo_CloudBush: all views: cloud puffs are low-poly faceted polyhedra with hard edges (1800 tris), 2D has smooth round balls; stray green grass specks float on the cloud in back/left views
- Halo_DomeHouseA: 3/4 and crop views: gold dome surface is dented/crumpled with wobbly ribs, wall course bulges wavy, small details (planter, door ring) soft in the 4096 single-atlas bake
- Halo_DomeHouseB: close-up/crops: balcony balusters, door and awning are blurry baked blobs; awning is twisted/crumpled; back view has a stray awning-like blue flap on a plain wall; gold dome dented
- Halo_FarArch: all views: model is a plain rock arch; the 2D's two gold-domed towers, blue banners and arched bridge on top are completely missing
- Halo_Gate: 3/4 view: inside of the arch passage shows a dark blue filled/inside-out surface instead of an open walkway; towers have wobbly uneven walls (right/left views) and banners/shield a
- Halo_Islet: 3/4, right and left views: green bush blobs float off the cliff edge in mid-air; lighthouse top, windows, door and small dome are blurry melted baked texture in the crops
- Halo_Lantern: front/3-4 crops: blue banner is a crumpled torn strip with the shaft skewed beside it, back and side faces of the shaft are creased flat slabs; lamp has only one window per side vs
- Halo_Planter: all views: planter box walls are crumpled, torn and bent (gold band broken, panels dented); bush is crushed sharp shards with spiky leaf spears poking through the wall; gold urn fi
- Halo_PotFlowers: front crops: pot wall is a lumpy faceted barrel with crooked gold window frames and blobby gold diamonds; flowers are angular paper-like polygons; top flowers stick out sideways in
- Halo_RoundTree: All three crops (row3): the leaves are spiky, faceted and smeared, not the 2D's smooth rounded leaves; the two daisies in the grass are missing, and the canopy lobes (front/back) d
- Halo_Shop: front crops: awning is crumpled and twisted (not a clean striped canopy) and the shop interior (shelves, goods) is a mushy brown blur; side views show the awning as flapping blue w
- Halo_Topiary: crops: cone leaves are over-glossy plastic with smeared specular streaks; pot blue swags and gold tassels are lumpy blobs and the gold rim is wavy
- Halo_Tower: back view: the blue banner is a ghostly smeared see-through blur on the tower wall; side views show wavy lumpy wall blocks and the banner as a thin sticker with uneven edges

### ④ 몬스터·펫(메인) — 4면 다시 + Blender(면 줄이기·눈 다듬기). 지금 쓰는 사냥터 몬스터(슬라임·고블린·해골) 먼저, 할로윈 몬스터는 숨김이라 나중 — 14개
- BatGoblin: Header: 17,224 tris in a raw Tripo glb (MonsterBatGoblin_raw.glb), above the 10k mobile risk line (docs/design/visual_direction_2026-10-05.json:1118) for a monster that spawns many
- GhostKing: Back view (row2 middle): the cloak is a stiff tablecloth dome with a uniform sausage fur hem, unlike the 2D's flowing cape, and the crown's inner face is brown, not gold (back/3/4)
- GhostMinion: Header: 17,102 tris for a plain teardrop minion in a raw Tripo glb (MonsterGhostMinion_raw.glb), far over the mobile prop guidance for a mob that spawns in groups; the face is clea
- Goblin: The header says 'NO 2D SOURCE (unknown)', so item 3 cannot be checked and the required 2D|3D side-by-side is missing; the 2x/100% crops (row3) show soft 1024 vest patches and stitc
- GoblinBrute: centre and 2x crops: the orange chest war-paint stripes are blurry smudges, and the dark green blotches on knees and arms look like dirty smears
- GoldenGoose: all views and crops: the 'golden' body is flat matte yellow clay with no gold shine, and the creature reads as a duck/chick rather than a goose
- LittleGhost: 100% edge crop (row3 middle): both hands and the striped lantern rope are fused into soft lumps with no separate fingers, and the lantern does not glow like the 2D's lit paper lant
- PetBabySlime: Header: 11,320 tris in a raw glb vs the pet target of 3,000 or fewer (docs/design/visual_direction_2026-10-05.json:1120); the body is a tall cube vs the 2D's wide flat cube (front 
- PumpkinKing: front view and forehead crop: a stray grey dot on the forehead; 3/4 view: the two small pumpkins float apart from the body; face is squeezed and turned compared with the 2D's wide 
- PumpkinSlime: Front view and centre crop (row1 middle, row3 right): the eye highlights do not match left vs right (the right eye's glint sits on its outer edge), the blush is a blurred smudge in
- Skeleton: Back and left views (row2 middle/right): the helmet has a torn slot and holes through its top/back (a mesh hole, not a design dent); there is no 2D source (header 'NO 2D SOURCE'), 
- SkeletonArcher: Front view and 2x close-up (row1 middle, row3 left): the helmet brim covers the skull's left eye entirely, where the 2D shows both purple eyes, and the left/3/4 views show a large 
- SkeletonKnight: There is no 2D source (header 'NO 2D SOURCE (unknown)'). The right/left views (row2) show a paper-thin body (y 0.285) and the cape hanging as a separate flat strip with an open gap
- SlingshotGoblin: The glb is the undecimated Tripo HD source (Mon_SlingshotGoblin_v2_HD_src.glb, 14,283 tris) for a mob; the 3/4 and left views (row1 right, row2 right) show two separate red feather

### ⑤ 교차로 키트 — 교차로 차례(A23-97)에 — 17개
- Kit_X_Anvil: all views: gold band and gear badges are mustard/ochre and matte, not glossy yellow gold; source is a raw Tripo GLB (header) so no Blender pass; anvil sits as a separate block on t
- Kit_X_BannerHalo: 3/4 view: top halo ring is an octagon, not round; banner emblem ring is an oval; back view: pole runs through the middle of the banner and the emblem is a mirrored copy; side views
- Kit_X_BannerHorns: bottom-right crops: horn emblem is baked into the cloth as a soft, dark, smudgy shape (low contrast); back view: pole runs in front of the banner and shows the emblem through it; s
- Kit_X_Bench: right/left views: seat is two separate blocks with a wide gap and the legs are lumpy fused barrels; ball finials on the back posts are uneven blobs (3/4 view, top)
- Kit_X_Brazier: right/left views: the flame is a flat paper-thin sheet (a thin spike from the side); the gold bowl is dull brown-olive, not shiny yellow; battlement blocks on the rim are uneven lu
- Kit_X_Forge: back view: a big blank plaster wall with a few smears (guessed back); right/left: the gold gear arch is cut in half and sticks out of the wall edge as a thin sliver; crop bottom-mi
- Kit_X_Lamp: back view and side views: lantern glass is a foggy grey-green blob and the green gem is only on the +X side (gone on the back, stuck to the glass edge in side views); the lantern i
- Kit_X_PotionCart: crops row 3: potion bottles are soft, smeared blobs with melted corks; left view: wheel gear is garbled (right wheel has a clean gear); back view: no potions at all, only a bare sh
- Kit_X_StallBlue: header: 2D source is X_StallRed_src.png and the 2D panel shows the RED stall, so this blue stall is a recolour of the red one; top gear finial is a lopsided flat chunk with a hole 
- Kit_X_StallGreen: geometry is identical to StallBlue (same tris 2840, same size, same fruit, same gear, only canopy colour changed); header 2D is X_StallRed_src.png; top gear finial is a lopsided ho
- Kit_X_StallRed: top gear finial is a lopsided lumpy chunk with a hole and a thin spike from the side (2D has a clean round gear); StallBlue and StallGreen are exact copies with only canopy colour 
- Town_Halo_Fountain: crop bottom-middle and front view: gold rim ring is broken into separate pieces with gaps and a floating plank; halo is a flat octagon; water jets are flat ribbons; whole thing is 
- X_Altar: right/left views: grey torn spikes hang under the top slab rim, the crystal bottom is a melted green smear (crop bottom-middle), the halo ring is an octagon; slab and pedestal are 
- X_GooseNest: all views: straw nest is a spiky, ragged mass instead of the neat woven strands in the 2D, and the nest height is lower than in the 2D; crops (1024px) are soft; flag poles are unev
- X_GuildHall: front view crop bottom-middle: the whole workshop interior (forge, tools, anvil, lamps, banners) is baked into a blurry brown smear on a flat back wall; the gold gear/emblem is pal
- X_MarketArch: back view: centre medallion is a plain wood hexagon with no gear/gem and the pillars lose their teal strips and gears (guessed back); the arch is lopsided (left and right pillar to
- X_NoticeBoard: back/left views: roof tiles are a wobbly uneven mess with a stray hole in the left-side roof corner; crystal bracket on top is lopsided; 1024px texture makes crops soft and the lan

### ⑥ 초원 키트 — 초원 차례에 — 16개
- Kit_M_BushA: back/left views: the back is a plain green lump with almost no leaves/flowers, and the top flower is a flat pancake; flower petals and leaves are faceted low-poly shards (crops); r
- Kit_M_BushB: Header shows glb = Kit_M_BushB_raw.glb (raw Tripo, no Blender stage); in the crops (row3) the yellow berries are faceted polyhedra instead of round spheres, and the back/left views
- Kit_M_CrownShrine: 3/4 view: crown is hollow/flat-capped with a grey disc inside and the crown points are uneven, faceted-ball tips; crops row 3: stone and moss are soft/blurry and the grass strip is
- Kit_M_CrystalPile: centre crop and all views: crystals are flat, washed-out opaque pale yellow with soft edges, not glossy glassy gems like the 2D (no facet highlights, no inner glow)
- Kit_M_Fence: Header glb = Kit_M_Fence_raw.glb (raw Tripo); the 100% crops (row3 middle/right) show the wood grain blurred almost away with smeared rail ends, and the posts and rails are uneven 
- Kit_M_FlowerCart: right/left/back views: the cart is a smeared, torn mess - handle is a twisted spike, wheels are wobbly polygons with olive-yellow smudges, side boards have sheared flat faces, flow
- Kit_M_FlowersA: all views and crops: only 596 tris so petals are hard faceted gems instead of the soft round balloon petals in the 2D, the flower discs tilt/fold sideways (right/left views), grass
- Kit_M_FlowersB: all views and crops: only 598 tris, tulips are faceted low-poly crystals instead of smooth round balloon tulips of the 2D; leaves and stems are angular shards; base is a lumpy poly
- Kit_M_JellyRock: all views: the glossy translucent jelly glaze of the 2D is a flat matte cream cap with no shine; colours are washed out and the back view is almost one flat cream colour with no pu
- Kit_M_LogBench: left view: log end is a lumpy blobby ring with a blank flat disc (no growth rings), while the right end has clear rings; the seat cut on top is an uneven, pale washed-out yellow pl
- Kit_M_Mushrooms: back view: big pink cap and cream cap have no or smudged spots (guessed back); caps are lumpy/squared, not round domes, and stems are wobbly
- Kit_M_PicnicBasket: Header glb = raw Tripo; the apple in the 100% crops (row3 middle/right) is a lumpy, boxy blob, the round handle pivot buttons are octagons (right/left views, row2), and the handle 
- Kit_M_Pinwheel: front vs right/left views: the 4 blades are different sizes and lumpy, the pink blade is clearly longer, and the hub axle pins are off-axis/tilted; stick leans slightly
- Kit_M_PuddleRim: 3/4 view: the water is a thin pale-blue sliver deep inside the ring (2D shows a wide glossy rippled pool); ring is not round (oval/lumpy) and stones are different sizes with pale m
- Kit_M_SignPost: In every view (row1/row2 top) the jelly cube is an opaque lime block with a pinched, crumpled front face instead of the 2D's glassy cube, and the sign board in the 100% crops (row3
- Kit_M_Stump: Header glb = Kit_M_Stump_raw.glb; the 100% crops (row3 middle/right) show smooth smeared orange bark with no wood grain, and the top rings in the right/back views are much fainter 

### ⑦ 고블린 숲 키트 — 숲 차례에 — 25개
- Kit_W_Banner: back and side views: banner cloth is a paper-thin sheet with the pole running in front of it, and the pole and finials look like glossy red plastic with no wood grain; the pole is 
- Kit_W_BushA: right/back views: the lower half of the 3 balls is a bare dark grey-green smooth sphere with no leaves (2D is covered in leaves all around); leaves look like hard glossy plastic wi
- Kit_W_BushB: All three crops (row3): the leaf edges are blurred, with dark smeared gaps and hard white plastic speculars along the leaf ridges, so foliage reads as wet plastic, not matte leaves
- Kit_W_CampFence: Header glb = Kit_W_CampFence_raw.glb; the 2D's round logs became faceted, squarish posts in a flat row (front/3/4 views, 100% crop row3 middle), and the back view (row2 middle) has
- Kit_W_Campfire_Fire: Header glb = Kit_W_Campfire_Fire_raw.glb; the right/left/back views (row2) show the flame as an angular faceted crystal and a thin tall spike instead of the 2D's soft round tongues
- Kit_W_Crates: right/back views: barrel bottom rim is ragged/jagged and barrel intersects the crate stack unevenly; rope knots and bolts look Tripo-raw
- Kit_W_FallenLog: left view: the splintered end is a torn flat shell showing its inside; right view: the open end ring is lumpy, not round
- Kit_W_Fern: crops and all views: leaves are crumpled, faceted and angular with ragged edges, where the 2D has smooth glossy fronds
- Kit_W_LanternPost: 2x close-up and 100% edge crop (row3 left/middle): the hanging chain links are fused and lumpy rather than clean round rings (the same type of defect as the _07 knocker); raw Tripo
- Kit_W_LogStool: top face (all views and 3/4): the 2D has tree-ring circles but the render top is a smooth blank orange disc with no rings; bark in the crops is soft and smeared
- Kit_W_LootSack: 100% edge crop (row3 middle): the gold coins are faceted polygons, not round discs, one coin pokes out as a flat bar at the bottom of the front view, and the left view (row2 right)
- Kit_W_MossRock: left view vs front view: moss turns bright yellow-lime and the rock turns beige, so there is a colour break between texture sides; the stone is glossy plastic with streaky highligh
- Kit_W_Mushrooms: stems and caps in all crops: heavy low-poly facets and white blown-out specular blotches baked on stems and caps, edges are polygonal instead of round
- Kit_W_SignPost: 2x close-up and 100% crops (row3): the round nail heads are faceted, pyramid-like polygons, and in the right/left views (row2) the boards are paper-thin stubs and the rope tail is 
- Kit_W_StepStones: all views and crops: stones are lumpy ovals with a noisy speckled wet-looking gloss, where the 2D has four round smooth flat discs; moss and grass bits are tiny
- Kit_W_Stump: In all three crops (row3) the moss is a blurred green smear without the 2D's crisp clumps, the back view (row2 middle) is plain bark with almost no moss and a lumpy root outline, a
- W_Boulder_A: back and right views: dark crease/spike artifacts and torn faces on the rock, and the ferns at the base are crumpled sharp shards instead of the 2D's neat fern leaves
- W_Boulder_B: back, right and left views: moss and rock are muddy, darker and olive-tinted compared with the vivid front, so there is a colour/brightness break; moss is a flat painted smear in t
- W_GiantTree: 3/4 and right views: the rope ladder hangs in the air away from the trunk and the bridge rails are wobbly; treehouse doors and windows are small dark soft blobs
- W_Tent_A: right view: a small dent/hole in the lower left corner of the red patch; left view: an orange smudge fades across the red patch (colour break)
- W_Tent_B: back and left views: the patches turn dull olive and muddy compared with the saturated front, and the door scroll and rope crops are soft
- W_Totem: top of all views: the crown reads dull olive-bronze and is ragged, not shiny yellow gold; leaf wings are angular thin plates (right/left views)
- W_Tree_A: Front/3/4/side views: the trunk is one flat smooth brown with no bark grain (it fails the 'wood shows grain' rule) and the root feet are angular cut wedges; none of the crops (row3
- W_Tree_B: 3/4 view and crops: the roots are blocky angular legs and the foliage and bark are soft, smeared paint in the 2x crops
- W_Tree_C: all views and crops: the hanging vines are flat green ribbon shards instead of the 2D's bead vines, the canopy is angular and the 1024 texture is soft

### ⑧ 왕관 — 오프닝 다시 만들기(A23-44)와 같이 — 2개
- Crown_Broken_B: 3/4 view: the inner back panel of the gold half has big blotchy yellow-white smudges (texture smear/burn) that are not in the 2D; the 1024px texture is soft on 9.7k tris
- K_CrownShard_v2: right and left views: the crown is a thick boxy slab, the red half is a rectangular block and the left side is a flat translucent amber panel; front view has a hazy grey shell arou

### ⑨ 계급 장식(후광·뿔 R3~R5) — 6개
- Acc_HaloR3: 3/4 view and crops: the gold ring is lumpy and dented with a dull pale matte surface, not smooth shiny gold; the ring is not an even circle
- Acc_HaloR4: 3/4, right and left views: lumpy dented ring, blobby uneven wings, and sun spikes of different lengths; gold looks dull and pale
- Acc_HaloR5: right/left/back views and crops: wings are crumpled angular chunks with grey-beige shading, double rings are wobbly, and the top spikes are uneven (two bunched at the left)
- Acc_HornsR3: right/left/back views: the base flange discs are faceted polygons and not round, the horns are slightly lumpy, and a small notch pinches the left horn in the 3/4 view
- Acc_HornsR4: front, right and back views: horns are fat conical stubs with lumpy faceted base flanges, where the 2D has slim, curved, glossy red horns with a soft glow; the left and right horns
- Acc_HornsR5: all views: horns are lumpy faceted twisted blobs with a floating loose spark triangle above them; the flame tips are flat glow patches, not the 2D's flames

### ⑩ 뿔 마을 성 — 뿔 마을 차례에 Studio 골격 + 장식 — 1개
- Town_Horns_Castle_v6mv: crops row 3: door, banners, stairs and battlements are soft/smeared (1024px tiles on an 84-unit building); red banners and lava are baked into the wall; gold trim looks dull ochre

### ⑪ 기타 — 2개
- Slime_BigSlime_SlimeCube: back view: a second smudged face (two eyes and blush, no mouth) is on the back of the cube; the right/left views show the front face wrapped round the sides
- SlimeKing_King_Slime: 3/4 and right views (row1 right, row2 left): the crown has a cluster of duplicated, extra ruby balls beyond the 2D's 5 tips plus the front gem, and in the back view (row2 middle) t

### ⑫ GLB 없음 — 1개
- X_SupporterBoard: whole sheet: NO GLB recorded, all render cells empty; the 2D source is the same HQ_X_NoticeBoard.png as X_NoticeBoard

### Studio 골격으로 다시 (A23-120) — 25개
Halo_ArchBridge, Halo_Balustrade, Halo_BannerPole, Halo_Stairs, Kit_X_Curb, X_PadBase, HaloBridge_1, HaloBridge_2, HaloBridge_3, HaloFlagpole_1, HaloFlagpole_2, HaloFlagpole_3, HaloPart_CathStairs, HaloReasonHQ_PhotoDisc, HaloStairs_1, HaloStairs_2, HaloStairs_3, HaloStairs_4, HaloStairs_5, HaloVar3_Balustrade_E, HaloVar3_Balustrade_F, HaloVar4_Balustrade_A, HaloVar4_Balustrade_B, HaloVar4_Balustrade_C, HaloVar4_Balustrade_D

## 같이 고칠 일
- 무기 모델(빛 전사 검·광전사 대검·대장장이 망치 등)은 Tripo 기록이 없는 임시 파트 모양이라 목록 밖이다. 세 단계로 새로 만들 목록에 더한다(이미지 생성 2 4면 → 이미지 생성 3).
- 시트에 2D가 없는 것(Goblin, GoblinBrute, GoldenGoose, Skeleton, SkeletonKnight)은 2D부터 다시 그린다.