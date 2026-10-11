# 빛 마을 plan v2 검수 결과 (2026-10-11, 검수 워크플로 halo-plan-v2-review, 247ff892 기준)

검사관 3명(지형·이유 문장·코드) + 찾은 것마다 반박 검증 1명. 아래 "진짜" = 반박 검증에서도 살아남은 것. "확인 안 함" = 낮은 순위라 반박 검증을 안 돌린 것(고칠 때 같이 확인).

## 검수 결정 (먼저 읽기)
1. **걷는 속도 = 20**(게임 기본 WalkSpeed). 걷는 시간 다시 재기. 성문→대성당이 약 21초면 A23-124 목표(약 30초)에 모자람 → 섬을 더 키우지 말고 대성당 언덕 길을 굽은 계단·갈지자 길로 늘려 25~30초.
2. **대성당이 마을에서 가장 높은 곳**(이야기 그대로). 전망대 구역을 낮춤(예 y 28), 전망대 why는 "가장 넓게 보이는 곳".
3. **절벽 마을 = 진짜 2층 단**(18/22, 계단 길로 연결). 글만 고치는 쪽 아님(층층 지형 규칙).
4. **첫 10분 글 = 실제 게임 흐름**: 스폰 → Hallie 카드 → 성문 → 교차로 대장간 → 초원, 가게·훈련장은 M1_4 "Go to your town" 때 돌아와 들르는 곳. 구역 자리는 그대로, first_10_minutes·story·market/training why만 고침.
5. **이동 발판 2개(SlimeMeadow·GoblinWoods) 둘레 12×12 + 2칸 = 아무것도 없음**(길·등불·문 길 포함). checks()에 발판 검사 추가.
6. B3/plaza_castle은 글을 "광장 → 성 앞 마당(동쪽)"으로 고치고 castle_court에서 끝냄. 정원 길 물 건넘엔 다리 B4(이유 포함).
7. 건물은 **네 모서리(+받침 5칸)가 모두 자기 구역 안**이어야 함 — checks() 고치고 Shop_Flower·House_Garden7·House_Hill4·Tower_Lookout 옮김.

## 지형·자리
- **[진짜 · medium]** Loop road and a gate fill light sit on the Slime Meadow travel pad — Pad_Halo_SlimeMeadow (-24,-357); roads[loop]; dressing.fill_lights; tools/halo_plan_v2.py:104,690
  - 고칠 것: Add a pad keep-out box to checks() and to lamp ok(): the 10x10 pad plus about 2 studs, compared against each road's half-width and each prop's radius. Then move the loop road's last points south (for example, keep z <= -371 until x > -17) or move the pad. Move the "inner west second" fill light off (-21,-353), and send door_Tower_GateEast south of z -362 or move the GoblinWoods pad.
- **[진짜 · medium]** Garden road crosses the stream at the W2 waterfall with no bridge — roads[to_garden] segment 0 (-30,-629)->(-64,-665); tools/halo_plan_v2.py:110
  - 고칠 것: Add a bridge B4 at about (-60,-661), len 12-14, along to_garden segment 0 with a why (plaza -> garden rest), or reroute to_garden so it crosses at B3. Then add a check to checks() that every road/stream crossing has a bridge within len/2.
- **[진짜 · medium]** House_Cliff3 door faces the coast and its only path is behind the house — buildings[House_Cliff3] (244,-614) yaw 90; tools/halo_plan_v2.py:160
  - 고칠 것: Either face House_Cliff3's door toward cliff_upper/cliff_yard (south-west) and keep the sea on the window side, or have door_spurs() route around the building corner. Also remove the own-spur skip in checks() (line 540) for every point after the door, so a spur that cuts through its own house gets flagged.
- **[진짜 · medium]** Tower_GateEast door path crosses the Goblin Woods travel pad — buildings[Tower_GateEast] (40,-350) yaw -145; roads[door_Tower_GateEast]; Pad_Halo_GoblinWoods (24,-357)
  - 고칠 것: Treat the two pad boxes (12x12 keep-clear) as obstacles in door_spurs and add a road-vs-pad check to checks(). Then route the Tower_GateEast spur south of the pad, e.g. (33.7,-359) -> (30,-366) -> (10,-366). Another option is to move Pad_Halo_GoblinWoods; the restart doc says it may be moved.
- **[진짜 · medium]** Four footprints stick out of their district; Shop_Flower cuts 6 studs into the plaza — Shop_Flower, House_Garden7, House_Hill4, Tower_Lookout; tools/halo_plan_v2.py:525-526
  - 고칠 것: In checks(), require all 4 footprint corners (ideally the footprint plus the 5-stud pad margin) to be inside the own district polygon. Then move or turn Shop_Flower about 9 studs north so corner (51.5,-543.0) leaves the plaza. Either nudge House_Garden7, House_Hill4 and Tower_Lookout inward, or widen their district polygons.
- **[진짜 · medium]** Walk times assume speed 16, but the game's base WalkSpeed is 20, so Gate->Cathedral is about 21 s, not about 30 s — tools/halo_blockout.py:445-514; art/review/world/halo_v2/walk_times.json; src/ReplicatedStorage/Shared/Config.luau:57
  - 고칠 것: In halo_blockout.py, replace the hard-coded 16 (line 499 divisor and line 514 speed field) with 20, read from Config.Player.WalkSpeed. Regenerate walk_times.json outside the shared tree and send 검수 the true gate->Cathedral time (about 21 s) so they can decide whether to lengthen the route or change the target.
- 확인 안 함(고칠 때 같이 확인):
  - [medium] Plan checker blind spots explain why issues=[] despite the problems above — tools/halo_plan_v2.py:6,506-621
  - [low] Spring, W2 and W3 positions do not match the heights they claim to drop between — water.pools[spring], water.falls[W2,W3]; tools/halo_plan_v2.py:119-123,299
  - [low] Bridge B2 is 2.75 studs off the stream crossing, so its west end lands over water — bridges[B2] (-64,-376) len 12; tools/halo_plan_v2.py:128
  - [low] Some fixed-point text in the plan JSON still has pre-1.5x coordinates — fixed_points.move[*].code, first_10_minutes[2].fixed; tools/halo_plan_v2.py:174,196-201
  - [low] Houses on sloped districts sit up to 3.9 studs below the ground around them — build_list ground_y = district y; tools/halo_plan_v2.py:465

## 이유 문장
- **[진짜 · medium]** The first-10-minutes story (Bright -> buy potion -> first skill test at the training ground -> exit) can't happen for a new player — plan first_10_minutes (json l.53-61), story[2], district market why (l.685), training why/job (l.765/771), P041-P043 scarecrows (l.3592); src/ReplicatedStorage/Shared/Config.luau
  - 고칠 것: Keep the districts where they are. Rewrite first_10_minutes, story[2] and the market/training 'why' to the real flow: spawn → Hallie card → gate (84 studs) → Crossroads Forge → meadow, with the shops and training yard as the return visit at M1_4 "Go to your town". Drop "첫 기술 퀘스트가 여기를 가리키게" from fixed_points.move and md table B, or send it to 검수 as a code-change request (starter gold, a practice dummy outside the quest).
- **[진짜 · low]** Market why 'potion shop within 40 studs of spawn' is false; the shop is also behind the spawn's look direction — districts.market why (json l.685); Shop_Potion why 'first shop visible from spawn'
  - 고칠 것: In tools/halo_plan_v2.py l.61, rewrite the market 'why' to state the real distance, for example "스폰에서 문까지 약 66스터드(걸어서 약 4초), 문이 스폰을 정면으로 봄". Also update the stale (24,-458) text in FIRST10 and the Shop_Potion 'why' to say the shop is visible once the player turns toward Bright. Only if 40 studs is a real target, move the shop closer instead. Either way, the session that owns the tool should regenerate the plan (do not run the tool in this review).
- **[진짜 · medium]** Cathedral 'highest place in town' contradicts lookout y 34 — districts.cathedral why (l.977), Cathedral why (l.6813) 'highest hill' vs districts.lookout why (l.1062) 'highest place'
  - 고칠 것: Put the cathedral back on the highest ground. Either lower the lookout district (for example y=28, which gives a tower top of 78, below 84, and adjust the to_lookout road grade), or raise the cathedral to at least 36, staying under MaxRise 42. Then fix the lookout why text so it says "highest view" rather than "highest place". Check that the lookout top still sees the plaza.
- **[진짜 · medium]** Cliff village: 'two tiers 18/22', 'upper tier' and 'close to the cathedral/lookout' are not true in the coordinates — districts.cliff_homes why/job; House_Cliff4 (l.7008), Cliff5 (l.7057), Cliff6 (l.7401), Cliff7, Cliff1 (l.6862)
  - 고칠 것: Pick one: either give the upper-tier houses (Cliff4/5/8, Cliff6 if kept as upper) ground_y 22 on a real terrace with a step, and add a short stair road from cliff_south (196,-698) up to the to_lookout start (136,-722) (18→30), or rewrite the cliff district/house why and note texts to match the coordinates (no tiers, Cliff1 on the cliff slope, which houses are actually near). Also trim the cathedral or cliff polygon at x 126-143 so they no longer overlap, and make Cliff6-8 residents match halo_new_houses_2026-10-11.md.
- **[진짜 · medium]** first_10_route and loop road pass 2.7 studs from the Slime Meadow travel pad (touching it = instant travel) — first_10_route leg (-64,-376)->(-24,-366)->(-8,-362); roads.loop (w 14); fixed pad Pad_Halo_SlimeMeadow (-24,0.7,-357)
  - 고칠 것: Move the loop road's east end south so its edge stays at least 2 studs off the pad, which needs the centerline at z <= -371 for x -29..-19 (for example (-55,-374), (-24,-373), (-8,-370)). Re-route door_Tower_GateEast so it goes around the GoblinWoods pad. Add a check to halo_plan_v2.py that no road band (w/2 + 2) may overlap a pad square.
- **[진짜 · low]** B3 / plaza_castle 'shortcut to the castle back yard' ends at the castle's front side — bridges B3 note/why (l.2388-2389); roads.plaza_castle end (-124,-548); dressing castle 'empty: 성 뒤 잔디 (성 뒤 마당)'
  - 고칠 것: In tools/halo_plan_v2.py, pick one of two fixes. Either extend plaza_castle around the castle's east face to the back, for example (-124,-548) -> (-129.5,-594.8) -> (-161.8,-631) -> (-212,-636), so it joins the castle_wall start. Or relabel the B3/plaza_castle note and why as "광장 → 성 앞 마당 (동쪽)" and end the road at castle_court (-160,-522).
- 확인 안 함(고칠 때 같이 확인):
  - [medium] Cliff balcony scene and bench P122 cannot see W3: House_Cliff8 blocks the view — scenes '절벽 마을 발코니' (262,-680) view 'east sea + W3'; dressing P122 BenchC (270,-688)
  - [low] cliff_yard / P120 'in front of houses 3 and 8, next to the W3 pool' is false for house 3 and for the pool — yards.cliff_yard (226,-646) r8 (l.2421); dressing P120 Planter_D (223,-653) (l.5093)
  - [low] House_Hill3 'faces the market' but its door faces away — buildings.House_Hill3 why (l.6666)
  - [low] Shop_Flower 'corner going DOWN to the plaza' while the plaza is higher; footprint pokes into the plaza district — buildings.Shop_Flower note/why (l.6518-6519)
  - [low] Tower_Lookout 'watches what comes over the sky bridge' is 497 studs from the only bridge, and the tower breaks the lookout's own edge rule — buildings.Tower_Lookout why (l.7303); districts.lookout why 'within 8 of the edge only low things'
  - [low] Armory '(Sir Gleam starts training)' is not supported; Gleam stands in the loop road — buildings.Armory why (l.6715); fixed_points.move Sir Gleam new (-22,0,-368) '문 길 옆'
  - [low] first_10_minutes step 3 'fixed' gives the old target (24,-458) instead of (24,-467) — first_10_minutes[2].fixed (json l.53)
  - [low] Cathedral east offset text (70/72) is the pre-1.5x value; the plan has x = 88 — districts.cathedral why (l.977) '동쪽으로 70'; Cathedral note (l.6812) '동쪽으로 72'
  - [low] garden_yard / P092 'between houses 2 and 5' is not between them — yards.garden_yard (-214,-742) (l.2441); dressing P092 VegGarden (-222,-748) (l.4561)
  - [low] Garden village: '2 houses look at the sea' and 'seaside where the castle is visible' fail the geometry — districts.garden_homes why (l.931); House_Garden3 why (l.7205); House_Garden7 note; dressing P083 bench (-239.2,-789.4)
  - [low] 'From the gate you see W1 and the cathedral together' is just outside a normal screen width; cathedral bearing is S, not SE — districts.arrival why; story[4]
  - [low] P068 'tree across the stream, behind the water' is on the plaza side of the stream — dressing P068 RoundTree_F (-60,-600); by_district.plaza plants '서쪽 시냇물 건너 나무'
  - [low] market_corner / P024 'back-lane corner, flower shop's planter' is neither at a corner nor at the flower shop — yards.market_corner (112,-488); dressing P024 Planter_D (111,-489)
  - [low] Scene 'market-end flower table looking down on the lane' (and P025/P026) is outside every district — scenes 시장 끝 꽃 화분 탁자 (157,-530); dressing P025/P026
  - [low] Bakery 'right in front of the stairs from the hill' is 30 studs away and off to the side — buildings.Shop_Bakery why (l.6421)
  - [low] Cathedral spring straddles the cliff; P076 'rocks around the spring' sits in the y-12 garden — water.pools spring (-30,-689) r7 y30; dressing P076 WhiteRock (-37.7,-684.5)

## 코드
- **[진짜 · low]** Plaza sink test differs between the two tools: exact radius in G() vs 4-stud cell centre in the blockout — tools/skeleton_ground.py:147-149 vs tools/halo_blockout.py:368-375
  - 고칠 것: Use one rule in both tools: the blockout sinks every cell whose 4x4 square overlaps the disc (minimum distance < r), and G() adds plaza_sink only when the containing cell would pass that same test (compute it from x0/z0/cell, or pass a sunk-cell mask into D) instead of testing the exact point radius.
- **[진짜 · low]** Door apron is blended only along the door axis, so its sides are 3-4 stud steps — tools/halo_blockout.py:273-287
  - 고칠 것: Set ground_y in build_list from the local slope height at the door for y_to districts (rounded), so both the pad cut and the apron notch shrink to under 1 stud. As a minimum, also blend the apron sideways over a widened region, e.g. t=max(t_u, clamp((v-half)/8,0,1)).
- **[진짜 · medium]** Door spurs cut back through their own building and undo the new floor flatten; the plan check cannot catch it — tools/halo_blockout.py:294-321; tools/halo_plan_v2.py:497-502, 540, 548
  - 고칠 것: In door_spurs, pick the nearest road point measured from the step point and add a corner waypoint when step->target crosses the own footprint. In checks(), skip only segment 0 (i == 0) of the own spur instead of the whole road. In the blockout road pass, skip cells whose centre is inside a building footprint.
- **[진짜 · medium]** '구역 밖' check tests only the building centre, so buildings that stick into another district pass A23-117 — tools/halo_plan_v2.py:525
  - 고칠 것: In checks(), report '구역 밖' when any footprint corner (better: the footprint grown by the 5-stud pad margin) is outside the building's own district polygon, keeping the Gate exception. Then move or turn Shop_Flower so it and its pad stay out of the plaza, and pull House_Garden7, House_Hill4 and Tower_Lookout inside their districts.

