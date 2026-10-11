# Job: fix the house skeleton generator + 4 specs after the 검수 verdict on batch 1 (이미지 생성 3, 2026-10-11)

Files you may edit: `tools/skeleton_house.py`, `tools/metal_ornaments.py`, `tools/house_specs/HaloDomeHouse_02.json`,
`_05.json`, `_09.json`, `_03.json` (and the other `tools/house_specs/*.json` if a shared key changes). Keep the code style
(comments like the surrounding code, English identifiers). Commit once with a short message. You cannot run Blender or
Studio — the caller runs `py tools/skeleton_house.py <spec>` and Blender afterwards, so keep every change simple and
make sure the Python still parses (no syntax errors; re-read your edits).

Read first: `tools/skeleton_house.py` (generator; docstring = spec schema), `tools/metal_ornaments.py` (Blender ornaments:
dome, finial, arch_window, leaf, knocker, hinge, lantern), the four specs, their 2D fronts (`src2d`, read_image), and the
review sheet `art/review/img3/houses/houses_batch1_blender.jpg` (2D | skeleton front | 3/4 | back | door).

## 검수 verdict to fix
1. Windows are far too narrow on all four houses. Make them wide arched windows like the 2D: measure window width / wall
   width in each 2D and set `win.w` per storey in the specs; the window code must scale with the width — gold frame
   width `g` (now fixed 0.22), hood, keystone, sill, mullion/transom — e.g. g = 0.1 * w + 0.08, and two vertical bars
   when w > 2.4. The window height should follow the 2D too (taller windows, top ~1 stud under the storey line).
2. House 09 is a round tower but reads as a box: raise its `seg` (e.g. 32) and make sure plinth, foot ring, storey
   bands, cornice and parapet follow the circle (they use offset_poly per edge — check it still works for 32 short
   edges, and that window holes still fit: a window must not be wider than its wall edge minus 0.3; if it is, let the
   window span two edges or skip — simplest: choose the spec walls/edges so it fits). Only the front (door) stays flat.
3. House 02: the corner towers are low blocks. Make them taller (top well above the cornice, like the 2D), give each a
   small gold dome cap (a "dome" ornament item with R ~ tower half width + 0.2, ribs 6) instead of only the finial
   ball, and one small arched window on the tower's front face (an "arch_window" ornament item with "yaw" so it faces
   +y, W ~ 0.9). Also add a front stair option `"steps": "three"`: three straight steps (rectangular, each 0.37 high,
   0.9 deep, width = door + 3.0) as in the 2D of 02; keep "half" as it is.
4. Dome ribs are almost invisible: make the ribs of the "dome" ornament stand out (about 0.22 out of the surface, 0.3
   wide, a rounded top would be nice) and put them in their own object `<name>_Ribs` (same gold) so Studio can tune it;
   keep gold colour 255,175,25.
Houses 05 and 03 need only 1 and 4.

## Final answer
What you changed (functions, new keys), the new window widths per house with the 2D ratio you measured, and anything
you could not do.

## How to edit (important)
Never rewrite a whole file with write_file. Use edit_file with small exact replacements (one function or block per
call) for the .py files, and write_file only for the small spec JSONs. Keep your own messages short. After all edits,
re-read the changed regions, then git_commit the changed paths, then the final answer.
