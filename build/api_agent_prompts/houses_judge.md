# Job: judge 15 house skeletons against their 2D (read-only; 이미지 생성 3, 2026-10-11)

For each spec in `tools/house_specs/*.json` (HaloDomeHouse_01..12 without 07, HaloShop_Bakery/Flower/Juice/Potion):
read_image the 2D (`src2d` in the spec) and the Blender renders `art/review/img3/houses/<name>/front.png` and `q34.png`
(skeleton parts + Blender metal ornaments; no plants yet — plants/ivy/window flowers come later from Tripo, ignore them).
Read `tools/skeleton_house.py` (docstring = spec keys) so your fixes use real keys.

Judge like the 3D checklist (`docs/design/3d_quality_check_2026-10-10.md`, items 1-4 mainly): silhouette and proportions
(width : wall height : roof/dome height), number/size/placement of windows and doors, roof/dome shape, awning colour and
size, gold trim amount, balconies/parapets, anything missing or extra. Be concrete and numeric.

Write ONE note `houses_judge.md` (write_note): for each building a short verdict (close / needs fixes / far) and a list
of fixes as exact spec edits (key path -> new value, e.g. `storeys[1].h: 6.0 -> 7.5`, `top.dome_h: 6.4 -> 8.0`,
`awning.w: 6.8 -> 8.4`), plus "generator needed" items when no key can do it. Order buildings worst first. Keep each
building under ~12 lines. End with the 5 most common problems across all houses.
Final answer: the worst 5 buildings and the 5 common problems.
