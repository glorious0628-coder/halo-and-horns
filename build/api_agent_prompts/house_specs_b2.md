# Job: write Studio-skeleton spec JSONs for 11 Halo buildings (이미지 생성 3, 2026-10-11)

You write JSON files only. Read `tools/skeleton_house.py` (its top docstring is the spec schema; read the code where the
docstring is unclear: plan shapes, wall names, storeys/windows, towers, pedestals, awning, pots, medals, top types).
Read the four finished example specs `tools/house_specs/HaloDomeHouse_02.json`, `_05.json`, `_09.json`, `_03.json` and
compare each with its 2D (`src2d` in the spec) with read_image, so you learn how a 2D front maps to numbers.
Then, for each target below, look at its 2D front (and the side/back images if listed) and write
`tools/house_specs/<name>.json` in the same format. Commit all 11 files in one commit with a short message.

## Targets (2D front; side/back views help with depth and shape)
- HaloDomeHouse_01 — art/out/s2/halo/roofs/HaloDomeHouse_01_roof_v2.png (side: art/out/s2/halo/houses_mv/HaloDomeHouse_01_left.png)
- HaloDomeHouse_04 — art/out/s2/halo/houses/HaloDomeHouse_04_front_HQ_src.png (houses_mv/HaloDomeHouse_04_left.png)
- HaloDomeHouse_06 — art/out/s2/halo/houses/HaloDomeHouse_06_front_HQ_recolor.png (houses_mv/HaloDomeHouse_06_left.png)
- HaloDomeHouse_08 — art/out/s2/halo/houses/HaloDomeHouse_08_front_HQ_src.png (houses_mv/HaloDomeHouse_08_left.png)
- HaloDomeHouse_10 — art/out/s2/halo/houses/HaloDomeHouse_10_front_HQ_recolor.png (houses_mv/HaloDomeHouse_10_left.png)
- HaloDomeHouse_11 — art/out/s2/halo/roofs/HaloDomeHouse_11_roof_v2.png (houses_mv/HaloDomeHouse_11_left.png)
- HaloDomeHouse_12 — art/out/s2/halo/roofs/HaloDomeHouse_12_roof_v2.png (houses_mv/HaloDomeHouse_12_left.png)
- HaloShop_Bakery — art/out/s2/halo/shops/HaloShop_Bakery_front_HQ_src.png
- HaloShop_Flower — art/out/s2/halo/roofs/HaloShop_Flower_roof_v2.png
- HaloShop_Juice — art/out/s2/halo/roofs/HaloShop_Juice_roof_v2.png
- HaloShop_Potion — art/out/s2/halo/shops/HaloShop_Potion_front_HQ_src.png

## Rules
- Plan sizes (docs/design/halo_plan_v2_2026-10-11.json `buildings`): houses are HouseA (24 x 22 footprint, 26 high incl. roof,
  for deep/tall towers) or HouseB (26 x 18, 28 high, wide/low); shops 24 x 15 x 18. The body (walls, without pilasters /
  towers / pots) is a bit smaller than the footprint, like the examples (02 = 19 x 17, 05 = 26 x 16, 09 = R 8, 03 = 16 x 15).
  Say in "note" which type (HouseA / HouseB / Shop) you chose.
- Keep the 2D proportions: measure the 2D front in pixels (body width vs wall height vs roof/dome height, door size vs width)
  and fit them. The door stays 5.0 x 8.15 (A23-106: bigger than an avatar); "double": true when the 2D door has two leaves.
- Storeys: one entry per floor the 2D shows; a window above the awning/door is a storey-2 window on "front".
  Windows "arch" or "rect" as drawn; `walls` u fractions where the windows sit (0..1 along that wall). The front edge
  runs from x = +W/2 to x = -W/2, and a front view (camera on +y looking -y) shows +x on the image LEFT, so u = 0.2 is on
  the image left. Most 2D fronts are symmetric: use pairs like [0.2, 0.8].
- Awning colours: copy the 2D stripes (yellow 250,205,72 / cream 255,243,212; blue 110,165,232 / white 255,255,252;
  mint, navy etc. as RGB pairs). No awning key if the 2D has none.
- Top: gold dome -> "dome" (round/oct plans) or "drum_dome" (a round drum with windows under the dome); flat roof with a
  railing -> "flat" with "parapet" "balustrade" or "solid", "skylight" / "topiary" if drawn. If the 2D has a roof the
  generator cannot make (tiled hip or pyramid roof, rooftop pavilion/pergola, small chimney, balcony, window boxes,
  ivy), pick the closest supported top AND list the missing feature in the note file (below) — do not invent keys.
- Medals only where the 2D shows gold quatrefoil plaques. Pots where the 2D shows planters (x, y, d, h; y just in front
  of the front wall: D/2 + 1 .. 2).
- Gold, marble and materials are fixed by the generator; never add colour keys except awning colours.

## Also write (write_note) `generator_gaps.md`
One table: building | 2D feature the generator cannot make yet | how often it appears | a short proposal (spec keys +
what to build: parts or a Blender ornament). This tells 이미지 생성 3 what to add next.

## Final answer
List the 11 files with plan type, body size, storeys, top type, and the 3 biggest gaps.

## How to write (important)
Write ONE spec file per write_file call (11 separate calls), each right after you studied that 2D; keep your own
messages short. Write generator_gaps.md with write_note at the end, then git_commit the 11 paths, then the final answer.
