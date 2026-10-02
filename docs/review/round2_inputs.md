# Round 2 inputs (collected while round 1 ran)
- build/review/reviewer_spec_v2.md (peer review, HIGH 5 / MED 27 / LOW 19, group checklist, A13 block)
- SPEC_ADDENDUM A12 (camera zoom 40, MaxSlopeAngle 46, fog 120/650, WorldMap wiring)
- A12-R1 [G1,G3]: Config.Sky Neutral/Dawn/Eclipse ALL use FogStart 120, FogEnd 650 (only colours differ); WarService keeps any value a preset omits.
- A12-R3 [G1,G3,WorldMap]: Config.Map Lands/Bridges/Gates/PassX must match preview_map v4 and WorldMap/MapBuilder read only Config (no hard-coded copies).
- IMG-R4 [all]: Config.Assets = { Icons = {}, Emblems = {}, Textures = {} } hooks (empty = current shapes/text). UI uses ImageLabel when Config.Assets.Icons[id] exists. Terrain textures: MaterialService MaterialVariants named "GE_<Material>"; MapBuilder applies them if present.
- A12-R2: NOT needed — verified in Studio that fully fogged parts render as FogColor silhouettes against the unfogged sky, so the crown stays visible from the ruins (build/v4_far_crown2.jpeg). Optional billboard exists disabled.
