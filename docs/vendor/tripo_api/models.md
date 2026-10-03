# Tripo API Models (captured 2026-10-03 from https://developers.tripo3d.ai/en/models*)

4 models · updated 2026-05

## Tripo H3.1 — v3.1-20260211 (Default) — flagship text & image to 3D
Quality Highest · ~40 s no texture / ~120 s with texture · face limit up to 2,000,000 · input Text, Image, Multiview · output Mesh + PBR.
Best-in-class geometry and PBR textures; quad mesh output (FBX); smart low-poly topology.
Pricing: Text 10 / 20 / 30 (no tex / standard / detailed) · Image 20 / 30 / 40 · Multiview 20 / 30 / 40.
Detailed geometry quality +20 · Quad mesh +5 · Smart low-poly +10 · Generate in parts +20.
Parameters: texture (default true) · pbr (default true) · texture_quality standard|detailed (HD) · geometry_quality standard|detailed (Ultra) · face_limit (adaptive limit) · quad (forces FBX).
Concurrency: 3D Generation — H Series 3 parallel tasks. Snapshot v3.1-20260211 current stable.

## Tripo P1 — P1-20260311 — low-poly specialist
Topology Cleanest · ~10 s no texture / ~60 s with texture · face limit 48–20,000 · input Text, Image, Multiview · output clean low-poly mesh.
Pricing: Text 30 / 40 / 50 · Image 40 / 50 / 60 · Multiview 40 / 50 / 60 (no tex / standard / detailed).
Does NOT support quad, smart_low_poly, generate_parts, geometry_quality.
Parameters: face_limit 48–20,000 (recommended ≥150 simple, ≥250 complex) · texture · pbr · export_uv.
Concurrency: P Series 3 parallel tasks. Snapshot P1-20260311.
(P2 per pricing page: base 100, standard texture 110, face_limit triangle 48–50,000 / quad 48–25,000, supports quad.)

## Tripo Rigging — rig-v2.0
7 creature types · ~30 s · input 3D model · output rigged GLB/FBX. Run free Rig Check first.
Types: biped, quadruped, hexapod, octopod, avian, serpentine, aquatic. Bone naming spec: tripo (default) or mixamo. out_format glb (default) or fbx.
Pricing: Rig Check 0 · Auto Rigging 25. Concurrency: Animation (shared with retarget) 3 parallel tasks.
Snapshots: v1.0-20240301 biped only, recommended for humanoids · v2.5-20260210 non-humanoid creatures.

## Tripo Animation — retarget-v1.0
100+ presets (90+ biped-exclusive) · ~5 s · input rigged model · output animated GLB/FBX. Batch up to 5 animations.
Pricing: 10 per animation. Parameters: animation (idle, walk, run, dive, climb, jump, slash, shoot, hurt, fall, turn) · animations (batch ≤5) · out_format glb|fbx · bake_animation (default true, glb only) · animate_in_place.
Snapshots: v1.0-20240301 (rig) 90+ biped presets · v2.5-20260210 (rig) 16 universal presets.
