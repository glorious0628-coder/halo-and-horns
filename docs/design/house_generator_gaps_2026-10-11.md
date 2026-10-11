# generator_gaps.md — what tools/skeleton_house.py cannot make yet (11 specs, 이미지 생성 3, 10/11)

Source note: the 2D PNGs (art/out/s2/halo/houses, roofs, shops, houses_mv) are NOT in the worktree (untracked). All specs were fitted
to the first panel ("2D") of art/review/img3/<name>_check.jpg. Side/back views were read from the 3D panels of the same board.
Specs were not run through the generator (no runner for it here); the reviewer should run `py tools/skeleton_house.py <spec>`.

| building | 2D feature the generator cannot make yet | how often | proposal (spec keys + what to build) |
|---|---|---|---|
| Bakery, Potion, Juice (door off-centre; shop window on one side) | door is always centred on the front; 2D shops have the door at one side and ONE big shop window | 3 of 4 shops | `door.u` (0..1 along the front, default 0.5) + `shopwin {u, w, h, shelves}` (a wide arched/rect display opening with gold frame, counter below). Parts: wall holes via the existing group logic (door hole already takes a u), pedestal/awning/steps follow `CXD` of the door. |
| 01, 04, 06, 08, 10, 12, Flower, Potion, Bakery, Juice | gold sign plaque / cartouche over the awning (Bakery, Potion, Juice) | 3 shops + several houses' medals | `sign {u, z, w, h}`: a gold scalloped plaque (Cylinder rim + block) like the quatrefoil medal; or a Blender ornament `sign_cartouche` in tools/metal_ornaments.py. |
| 04, 06, 08, 10, 12 (and Bakery, Flower, Juice, Potion corner planters) | window boxes with flowers under windows; flower/topiary beside pots; ivy on walls | 5 houses + 4 shops | `window_boxes: [[wall, u, storey]]` (marble box + gold rim; plants = 4-view Tripo later, A23-122); `pots[].plant`. Ivy: Tripo plant parts, not generator. |
| 06, 08, 10, 12 | balcony / balustrade ring on an UPPER storey line (between storeys) with gold balusters | 4 houses | `balconies: [{storey, wall, u0, u1, depth}]` or a `balustrade_ring` at a storey line: Rail + RailBase + Baluster posts like the flat-top code, but at Z_LINES[si], projecting 1.1 from the wall; plus a slab floor under it. |
| 11 | blue tiled HIP roof (pyramid) with gold ridge, finial, chimney | 1 house (also seen on the Bakery brick dome) | `top {type: "hip", h, tile: "blue", chimney: [x, y, w, h]}`: four sloped slabs (Plastic/Slate + gold hips), gold finial ball; tile courses by a tile MaterialVariant. |
| 12 | rooftop pergola with gold columns, white beams, hanging ivy | 1 house | `top.pergola {w, d, h, columns: 4}` on the flat roof: 4 Cylinder columns (gold caps) + 4 marble beams + cross rafters. |
| 01 | rooftop cupola (gold domed lantern tower with arches) on a round roof | 1 house | `top.cupola {x, y, r, h}`: 4 small posts + ring + gold `dome` ornament (reuse the existing dome ornament, small R). |
| Flower | greenhouse roof: pitched gold glass frame with finial balls (skylight is only a glass box + ridge) | 1 shop | `skylight` variant `"gable": true`: sloped glass panes (two Wedge/tilted blocks) + gold frame bars + corner ball finials. |
| Juice | rooftop parasol pavilion (4 gold posts, striped canopy, fruit crates) | 1 shop | `top.pavilion {colors, posts: 4}`: 4 posts + striped cone/tilted cloth slabs (reuse awning cloth colours) on a balustrade roof. |
| Bakery, Potion | brick-red dome + chimney lantern tower (Bakery); dome sits on a SQUARE body | 1 + 1 | `dome` on a rect plan currently uses the full plan width; add `dome {R}` for rect plans, and `top.chimney`. Potion used `drum_dome R 5.8, windows 0` as a workaround. |
| Bakery, Juice, Potion, 08 | raised central gable / arched parapet (round-top window in a gable above the sign) | 2 shops + 08 | `top.gable {u, w, h, window}` on the front parapet: arch ring + marble fill. |
| 08 | small gold dome canopy over the door (porch), wide front stairs | 1 house | `porch {type: "dome_canopy", w}`: two posts + `dome` ornament at the door; `steps: "wide"`. |
| 04, 10 | onion-dome base: stepped square base with arcade frieze under the cornice, ball finials on the corner posts | 2 houses | `towers.finial` exists only for `towers`; add `pilaster_finials: true` (ball on each PilasterCap) and `frieze: "arcade"` (row of small arches under the cornice, Blender ornament or repeated `arc`). |
| 11, 12 (houses with low planters) | long curved low planter walls beside the door | 1 house | `planter_walls: [{x0, x1, h}]` marble blocks + gold rim (like Pot but rectangular). |
| 12, 06 | awning with a third colour (yellow scallop trim on a navy/white awning) | 2 | `awning.colors` accepts 3 entries: stripe A, stripe B, valance. |
| all houses | lantern without pedestals (Juice) | 1 | `lanterns: true` independent of `pedestals`. |
| all | upper-storey window height / bottom is fixed by the generator (bottom 4.6 under the storey line); 2D sometimes sits lower | many | `storeys[].win.bottom` / `h` override. |

Biggest three for 이미지 생성 3 to build first: (1) off-centre door + shopfront display window (3 of 4 shops), (2) upper balcony/balustrade ring + window boxes (4 houses, 5 houses), (3) roof extras: hip roof / pergola / cupola / parasol pavilion (each once, but they define the skyline).
