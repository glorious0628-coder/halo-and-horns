# 빛 마을 소품 바깥선(얇은 껍데기 0.035) 표 — 이미지 생성 4, 2026-10-12

사용자 결정 SPEC A23-139: 소품 바깥선 = 얇은 선(0.035칸), 기본 B(모든 파트 그림자) 위에 뒤집힌 껍데기 메시. 디자인 검수 10/12: 껍데기는 바깥 실루엣 + 큰 덩어리만(가장 작은 변 0.12칸 미만·가장 큰 변 0.3칸 미만 파트 = 판 줄·작은 띠·창 테·작은 공 빼기), 거리 끄기는 아직 안 함.

- 만드는 법: `blender --background --factory-startup --python tools/prop_kit_bake.py -- build/prop_kit_hull035 build/prop_kit/<키>.json --hull-only --hull-t 0.035 --hull-min 0.12 --hull-big 0.3 [--preview]`
- 파일: `build/prop_kit_hull035/<키>_D2_035.obj` (삼각형만, Roblox 축 = Y 위·앞 -Z, 1 = 1칸, 키트 원점 기준, 법선은 일부러 안쪽) + `<키>_D2_035.json`(D2_center_roblox = 상자 중심). 놓기: MeshPart.CFrame = 키트 피벗 × CFrame.new(상자 중심) × **CFrame.Angles(0, math.pi, 0)** (Studio 3D 가져오기가 OBJ를 세로축 180° 돌림 — 10/12 Lantern_C·BenchB 실측, 안 돌리면 비대칭 키트는 반대쪽에 검은 복사본), SmoothPlastic (74,50,36), CastShadow·CanCollide·CanQuery 끔, DoubleSided 끔. 모델 안에 넣으면 ScaleTo로 같이 커짐.
- 같은 키트를 여러 군데 놓아도 메시 1개를 같이 씀(마을 놓인 수와 상관없이 키트당 1개). 등불 56개 = 기둥 종류 A~E 5개.
- 빼는 키트 2: HaloReasonHQ_PhotoDisc(바닥 원판), NEW_SteppingStones(납작한 돌) — 선이 의미 없음.
- Tripo 메시(식물·등불 머리·종·벽등 머리·바위 등)는 tools/tripo_touchup.py에서 같은 0.035 껍데기를 붙여 한 GLB로(다음 일).

| # | 키트 | 마을에 놓인 수 | 파트 수 | 껍데기 삼각형 | 묶음 |
|---|---|---|---|---|---|
| 1 | HaloFlagpole_1 | 2 | 47 | 1516 | 2 |
| 2 | HaloFlagpole_2 | 1 | 52 | 1132 | 4 |
| 3 | HaloFlagpole_3 | 1 | 61 | 1912 | 4 |
| 4 | HaloFlowerPotHQ_Daisy__Body | 2 | 45 | 120 | 2 |
| 5 | HaloFlowerPotHQ_Lavender__Body | 2 | 10 | 920 | 2 |
| 6 | HaloFlowerPotHQ_Rose__Body | 2 | 7 | 610 | 3 |
| 7 | HaloFlowerPotHQ_Sunflower__Body | 2 | 6 | 568 | 3 |
| 8 | HaloFlowerPotHQ_Tulip__Body | 3 | 36 | 72 | 2 |
| 9 | HaloReasonHQ_BenchA | 6 | 53 | 1192 | 1 ★ |
| 10 | HaloReasonHQ_BenchB__Body | 5 | 52 | 1368 | 1 ★ |
| 11 | HaloReasonHQ_BenchC | 4 | 43 | 1036 | 2 |
| 12 | HaloReasonHQ_BreadStand__Body | 1 | 29 | 84 | 4 |
| 13 | HaloReasonHQ_Clothesline | 3 | 50 | 1036 | 2 |
| 14 | HaloReasonHQ_FlowerCart__Body | 1 | 59 | 1336 | 4 |
| 15 | HaloReasonHQ_FruitStall__Body | 1 | 69 | 11352 | 4 |
| 16 | HaloReasonHQ_GuardPost | 1 | 104 | 2582 | 4 |
| 17 | HaloReasonHQ_PotionCrate__Body | 1 | 46 | 456 | 5 |
| 18 | HaloReasonHQ_RackShieldSword | 2 | 84 | 3644 | 3 |
| 19 | HaloReasonHQ_VegGarden__Body | 2 | 25 | 108 | 3 |
| 20 | HaloReasonHQ_Woodpile | 2 | 190 | 3080 | 3 |
| 21 | HaloVar3_Balustrade_E | 1 | 46 | 1318 | 5 |
| 22 | HaloVar3_Balustrade_F | 1 | 108 | 7508 | 5 |
| 23 | HaloVar3_Lantern_E | 11 | 35 | 1106 | 1 ★ |
| 24 | HaloVar3_Planter_E__Body | 2 | 81 | 2852 | 3 |
| 25 | HaloVar3_PotFlowers_E__Body | 1 | 32 | 702 | 5 |
| 26 | HaloVar3_PotFlowers_F__Body | 1 | 25 | 1058 | 5 |
| 27 | HaloVar3_RoundTree_E__Body | 6 | 28 | 376 | 1 ★ |
| 28 | HaloVar3_RoundTree_F__Body | 5 | 28 | 376 | 2 |
| 29 | HaloVar3_RoundTree_G__Body | 5 | 28 | 376 | 2 |
| 30 | HaloVar3_Topiary_C__Body | 2 | 24 | 702 | 3 |
| 31 | HaloVar3_Topiary_D__Body | 2 | 36 | 120 | 3 |
| 32 | HaloVar3_Topiary_E__Body | 2 | 49 | 2766 | 3 |
| 33 | HaloVar4_Balustrade_A | 1 | 80 | 6568 | 5 |
| 34 | HaloVar4_Balustrade_C | 1 | 103 | 8936 | 5 |
| 35 | HaloVar4_Lantern_A | 12 | 71 | 644 | 1 ★ |
| 36 | HaloVar4_Lantern_B | 11 | 36 | 2700 | 1 ★ |
| 37 | HaloVar4_Lantern_C | 11 | 76 | 984 | 1 ★ |
| 38 | HaloVar4_Lantern_D | 11 | 118 | 720 | 1 ★ |
| 39 | HaloVar4_Planter_A__Body | 3 | 32 | 1592 | 2 |
| 40 | HaloVar4_Planter_D__Body | 2 | 36 | 120 | 1 ★ |
| 41 | HaloVar4_PotFlowers_A__Body | 2 | 7 | 698 | 3 |
| 42 | HaloVar4_PotFlowers_C__Body | 2 | 15 | 1030 | 4 |
| 43 | HaloVar4_PotFlowers_D__Body | 1 | 6 | 502 | 5 |
| 44 | NEW_ArmoryBarrels | 1 | 84 | 1372 | 5 |
| 45 | NEW_Beehive | 1 | 45 | 312 | 1 ★ |
| 46 | NEW_BellFrame | 1 | 49 | 1626 | 5 |
| 47 | NEW_CafeTable | 3 | 36 | 1272 | 2 |
| 48 | NEW_CandleCrate | 2 | 40 | 660 | 4 |
| 49 | NEW_Cauldron | 1 | 31 | 1608 | 6 |
| 50 | NEW_Easel | 1 | 24 | 360 | 6 |
| 51 | NEW_Hedge__Body | 2 | 40 | 1008 | 4 |
| 52 | NEW_NoticeBoard | 1 | 42 | 924 | 6 |
| 53 | NEW_Telescope | 1 | 22 | 1392 | 6 |
| 54 | NEW_WallLamp | 2 | 38 | 132 | 4 |
| 55 | NEW_WaterBuckets | 1 | 25 | 656 | 6 |
| 56 | Town_Halo_Fountain3 | 1 | 51 | 4988 | 6 |

합계: 메시 56개, 삼각형 94188 (평균 1681). 큰 것: FruitStall 몸통 11,352·Balustrade C 8,936·F 7,508·A 6,568·Fountain3 4,988 — 모두 2만 아래.
올리기: 최종 검수 승인 뒤 이미지 개발이 ≤10개씩 직접 보고 올림 → 6묶음(표 '묶음' 열; 최종 검수 10/12 2~6묶음 승인, 사용자 Import 3D → 이미지 개발 ID). ★ 첫 묶음 10 = 디자인 검수가 고른 4(BenchA·Lantern_A·Beehive·Planter_D) + 많이 놓인 등불 B~E·벤치 B·둥근 나무 E 몸통.
미리보기 한 장: `art/review/img4/outline_hulls_1012.jpg` (Blender, 껍데기 붙인 모습).
