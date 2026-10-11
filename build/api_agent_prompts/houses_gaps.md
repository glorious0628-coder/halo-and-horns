# Job: add the missing house features to the skeleton generator (이미지 생성 3, 2026-10-11)

Edit `tools/skeleton_house.py` (and `tools/metal_ornaments.py` only if a Blender ornament is the right tool), plus the
specs in `tools/house_specs/` that use the new keys. Read first: the generator (docstring = schema), the gap table
`docs/design/house_generator_gaps_2026-10-11.md`, and each affected spec's review board `art/review/img3/<name>_check.jpg`
(first panel = the 2D; the 2D PNGs themselves are not in the repo). You cannot run Python/Blender: keep code simple,
re-read every edit, keep the existing behaviour when a new key is absent (old specs must give the same parts).

## How to edit (important)
Never rewrite a whole file. Use edit_file with small exact replacements (one function / block per call). write_file only
for spec JSONs. Short messages. At the end re-read the changed regions, git_commit the changed paths, final answer.

## Build these (in this order; stop early rather than half-finish one)
1. `door.u` (0..1 along the front, default 0.5) — the door hole, reveal/frame/arch, leaf/knocker/hinges, pedestals,
   lanterns, awning, steps and DoorFront all follow the door centre (CXD / DU). Plus `shopwin {u, w, h, type}`: one wide
   display opening on the front (arched or rect) with a gold frame like a window but wider, a marble sill/counter under
   it, glass, 2-3 gold mullions; it must not overlap the door hole (warn and skip if it does). Use them in HaloShop_Bakery,
   HaloShop_Potion, HaloShop_Juice as the 2D shows (door at one side, one big display window), replacing the symmetric
   workaround.
2. `balconies: [{storey, walls: [...], depth}]` — a balcony at the bottom line of an upper storey on the listed walls:
   a slab floor (WalkGround floor material) projecting `depth` (default 1.4) from the wall, a gold-capped marble rail
   with round balusters (reuse the flat-top balustrade code), a gold band under the slab. And `window_boxes:
   [[wall, storey]]` (or all windows of a storey with "all"): a marble box (w = window w + 0.6, h 0.6, depth 0.7) with a
   gold rim and soil under each window of that storey (plants later, Tripo). Use them in 06, 08, 10, 12 (balconies) and
   04, 06, 08, 10, 12 (window boxes) as their 2D shows.
3. Roof extras, each a `top` sub-key on the existing types: `top.hip {h, chimney: [x, y, w, h]}` for house 11 (four
   sloped blocks meeting at a ridge — for a rect plan: two trapezoids as tilted slabs + two triangles approximated by
   tilted slabs is fine; material: a blue roof slate = SmoothPlastic (90, 140, 210) with gold hip lines and a gold ball
   finial), `top.pergola {w, d, h, columns}` on flat roofs (house 12), `top.cupola {r, h}` (house 01: 6 marble posts +
   gold ring + a small "dome" ornament). If time is short, do hip only.
Gold = existing "gold" material, marble = "marble"; never add new colours except the roof slate above.

## Final answer
What you built (keys, functions), which specs use them, and what is left.
