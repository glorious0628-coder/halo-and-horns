# 메인 게임에 넣을 3D 표 (이미지 생성 1, 2026-10-07)

검수 요청(사용자 화남: 초원 장식·성·교차로 분수). **메인 Studio는 안 건드림** — 아래 id로 검수가 `tools/place_kit_main.lua`로 넣는다.
모든 '업로드됨'은 새 계정, WorldKit 3D 가져오기로 올린 MeshPart 1개(+텍스처 1장, TextureID = 색만). 크기 = 스터드(X 폭, Y 높이, Z 깊이), 앞 = Roblox -Z, 피벗 = 밑면 가운데.
배치 묶음은 기존 장부 `art/models/worldkit/import*_assets_*.json` + `py tools/build_kit_from_ids.py --list <장부>`(ServerStorage/WorldKit3D에 Model 생성).

## 0. 교차로 분수 (맨 위 — 사용자 '더 화려하게')
| 이름 | 상태 | 파일 | 크기(스터드) | 바닥 | 물·빛 자리(FountainFx) |
|---|---|---|---|---|---|
| Town_Halo_Fountain ②(Tripo 웹 HD + 2D 참조 텍스처 다시 입히기, 검수가 고름) | **아직 업로드 안 됨** — 다음 가져오기 1번 | `art/models/tripo/web_fixed/Town_Halo_Fountain_R2_fixed.glb`(색+노멀+금속·거칠기 맵, 금속 0.15) | 폭 21(옛 K_Fountain과 같게) × 높이 16.3 | 피벗 = 밑면 가운데 → Landmarks.Fountain 자리 y 0 | 물 높이(밑면 기준): 아래 큰 물웅덩이 3.8~4.2, 가운데 층 8.6~9.0, 맨 위 그릇 11.6, 맨 위 후광 고리 꼭대기 16.3. 물줄기는 가운데 층·위 그릇 가장자리 4곳에서 아래로 |

## 1. 초원(Kit_M_*) — 16개 모두 업로드됨, 메인엔 아직 없음
| 이름 | 구역 | MeshId | TextureID | 크기 | 승인 | 질감 고침(A23-73) | 비고 |
|---|---|---|---|---|---|---|---|
| Kit_M_Bridge | 초원 | 139572118820642 | 88150140266465 | 12×5.112×11.999 | 통과(가져오기됨) | 안 함(Tripo 원본 색) |  |
| Kit_M_BushA | 초원 | 106307848111648 | 79838662013537 | 3.5×3.028×3.46 | 통과(가져오기됨) | 안 함(Tripo 원본 색) |  |
| Kit_M_BushB | 초원 | 88153646213867 | 109252929624932 | 3.5×1.624×3.127 | 통과(가져오기됨) | 안 함(Tripo 원본 색) |  |
| Kit_M_CrystalPile | 초원 | 86308078328117 | 125534770059488 | 2.5×2.356×2.498 | 통과(가져오기됨) | 안 함(Tripo 원본 색) |  |
| Kit_M_Fence | 초원 | 105546814712079 | 99194569804092 | 6×2.346×0.939 | 통과(가져오기됨) | 안 함(Tripo 원본 색) |  |
| Kit_M_FlowerCart | 초원 | 113895856616873 | 111109638681586 | 5×3.826×4.355 | 통과(가져오기됨) | 안 함(Tripo 원본 색) |  |
| Kit_M_FlowersA | 초원 | 92243781258407 | 100182473783222 | 1.929×2×1.828 | 통과(가져오기됨) | 안 함(Tripo 원본 색) |  |
| Kit_M_FlowersB | 초원 | 97941848592289 | 123560007035785 | 1.435×2×1.305 | 통과(가져오기됨) | 안 함(Tripo 원본 색) |  |
| Kit_M_JellyRock | 초원 | 95456156173502 | 74728552222072 | 4×1.863×3.61 | 통과(가져오기됨) | 안 함(Tripo 원본 색) |  |
| Kit_M_LogBench | 초원 | 112862685818521 | 138917858401190 | 6×2.415×2.157 | 통과(가져오기됨) | 안 함(Tripo 원본 색) |  |
| Kit_M_Mushrooms | 초원 | 103261493871232 | 127783072739336 | 2.936×3×2.788 | 통과(가져오기됨) | 안 함(Tripo 원본 색) |  |
| Kit_M_PicnicBasket | 초원 | 86719944722296 | 83299168420680 | 1.397×1.5×1.443 | 통과(가져오기됨) | 안 함(Tripo 원본 색) |  |
| Kit_M_Pinwheel | 초원 | 88060481559698 | 93537863159632 | 2.087×3×1.327 | 통과(가져오기됨) | 안 함(Tripo 원본 색) |  |
| Kit_M_PuddleRim | 초원 | 73609253496482 | 76585247279422 | 6×1.854×5.99 | 통과(가져오기됨) | 안 함(Tripo 원본 색) |  |
| Kit_M_SignPost | 초원 | 79697505761320 | 95415258888849 | 4.556×6×1.192 | 통과(가져오기됨) | 안 함(Tripo 원본 색) |  |
| Kit_M_Stump | 초원 | 129098593877306 | 90134374690550 | 2.5×1.582×2.469 | 통과(가져오기됨) | 안 함(Tripo 원본 색) |  |

## 2. 교차로·마을(Tripo 3a) — 업로드됨
| 이름 | 구역 | MeshId | TextureID | 크기 | 승인 | 질감 고침 | 비고 |
|---|---|---|---|---|---|---|---|
| X_Fountain | 교차로 | 73942540446684 | 98933630455219 | 21×17.701×20.899 | 통과(가져오기됨) | 안 함 | 옛 교차로 분수(웹 HD 아님) — 0번 ②로 바꾸길 추천 |
| X_GuildHall | 교차로 | 138481942116141 | 82264529957588 | 24×22.482×23.912 | 통과(가져오기됨) | 안 함 |  |
| X_PadBase | 교차로 | 76623876473099 | 75972090020120 | 12×5.191×12.089 | 통과(가져오기됨) | 안 함 |  |
| X_SpawnPlaza | 교차로 | 127606624492271 | 135478238767068 | 16×8.231×15.44 | 통과(가져오기됨) | 안 함 |  |
| X_TreeA | 교차로 | 109261586232949 | 118159526635991 | 11.197×14×8.513 | 통과(가져오기됨) | 안 함 |  |
| Town_Halo_Gate | 빛 마을 | 130670908561947 | 140056399190129 | 30×27.037×11.161 | 통과(가져오기됨) | 안 함 |  |
| Town_Halo_Wall | 빛 마을 | 110962046093465 | 104077987799099 | 18×9.887×5.354 | 통과(가져오기됨) | 안 함 |  |
| Town_Halo_Spawn | 빛 마을 | 140470780543237 | 77490594657862 | 16×11.206×16.064 | 통과(가져오기됨) | 안 함 |  |
| Town_Halo_Tree | 빛 마을 | 74593604556742 | 84749844457355 | 11.811×14×9.595 | 통과(가져오기됨) | 안 함 |  |
| Town_Horns_Gate | 뿔 마을 | 89412131204970 | 81967954267598 | 30×26.684×12.112 | 통과(가져오기됨) | 안 함 |  |
| Town_Horns_Wall | 뿔 마을 | 83921887923846 | 80520280655099 | 18×10.304×3.617 | 통과(가져오기됨) | 안 함 |  |
| Town_Horns_Spawn | 뿔 마을 | 92102181025436 | 124228457142875 | 16×7.705×15.403 | 통과(가져오기됨) | 안 함 |  |
| Town_Horns_Tree | 뿔 마을 | 126631875577995 | 126041599098819 | 12.349×14×9.087 | 통과(가져오기됨) | 안 함 |  |
| W_BridgeWood | 숲 다리 | 106332250128014 | 136671378063455 | 33.644×13.013×22.001 | 통과(가져오기됨) | 안 함 |  |

## 3. 성·왕관 — 업로드됨(메인에 있음), 성은 고친 판 만드는 중
| 이름 | 구역 | MeshId | TextureID | 크기 | 승인 | 질감 고침 | 비고 |
|---|---|---|---|---|---|---|---|
| Town_Halo_Castle | 빛 마을 | 123075840109987 | 81624750351092 | 70.0×65.71×55.38 | 통과(가져오기됨) | 색 고침만(84ae50a, 1024) | 텍스처 1024 한 장이 성 전체(70스터드)에 → 가까이서 흐림. 고친 판 준비 중 |
| Town_Horns_Castle_v4 | 뿔 마을 | 115349247467412 | 121003399614369 | 83.53×65.62×84.0 | 통과(가져오기됨) | 안 함(Tripo 원본) | 같은 문제. 고친 판 준비 중. 옛 Town_Horns_Castle(v3)는 안 씀 |
| Crown_Broken_B | 하늘 왕관 | 92557402817319 | 115747495711677 | 40.0×29.5×36.38 | 통과(가져오기됨) | 뒤쪽 고침(98c0d07) |  |

## 4. 숲 — 업로드됨
| 이름 | 구역 | MeshId | TextureID | 크기 | 승인 | 질감 고침 | 비고 |
|---|---|---|---|---|---|---|---|
| Kit_W_CampFence | 숲 | 79119036174525 | 99371547652013 | 6.0×5.99×2.03 | 통과(가져오기됨) | 안 함 |  |
| Kit_W_Crates | 숲 | 138332417672184 | 135854095349820 | 4.0×3.39×2.58 | 통과(가져오기됨) | 안 함 |  |
| Kit_W_LootSack | 숲 | 121683216005196 | 134921517402760 | 2.08×2.07×2.2 | 통과(가져오기됨) | 안 함 |  |
| Kit_W_LanternPost | 숲 | 103007560611135 | 90546442367341 | 3.76×7.0×2.58 | 통과(가져오기됨) | 안 함 |  |
| Kit_W_SignPost | 숲 | 87319370167767 | 115647470437962 | 4.47×6.0×1.9 | 통과(가져오기됨) | 안 함 |  |
| Kit_W_FallenLog | 숲 | 124007846852047 | 89978127844533 | 10.0×5.64×7.03 | 통과(가져오기됨) | 안 함 |  |
| Kit_W_Stump | 숲 | 94180057479156 | 92014656910584 | 3.2×1.76×3.2 | 통과(가져오기됨) | 안 함 |  |
| W_GiantTree | 숲 | 98906136960678 | 111797540482847 | 62.16×80.0×46.27 | 통과(가져오기됨) | 안 함 |  |
| W_Gate | 숲 | 92354414518103 | 91807211573167 | 24.0×21.1×7.94 | 통과(가져오기됨) | 안 함 |  |
| W_Totem | 숲 | 85874937331352 | 108120754036226 | 4.76×8.0×2.07 | 통과(가져오기됨) | 안 함 |  |
| W_Tent_A | 숲 | 75491787574805 | 71832245558560 | 14.0×11.74×11.92 | 통과(가져오기됨) | 안 함 |  |
| W_Tent_B | 숲 | 110182929629557 | 102167637409277 | 14.0×11.99×13.96 | 통과(가져오기됨) | 안 함 |  |
| W_Tree_A | 숲 | 89362965968405 | 121465946798694 | 30.72×50.0×28.62 | 통과(가져오기됨) | 안 함 |  |
| W_Tree_B | 숲 | 119752494377465 | 128194951234486 | 36.07×44.0×27.2 | 통과(가져오기됨) | 안 함 |  |
| W_Tree_C | 숲 | 101305312737894 | 124382017201104 | 37.63×48.0×23.98 | 통과(가져오기됨) | 안 함 |  |
| W_Boulder_A | 숲 | 99362269271907 | 77504709570662 | 12.0×10.95×11.31 | 통과(가져오기됨) | 안 함 |  |
| W_Boulder_B | 숲 | 79139351840427 | 104486542265201 | 14.0×11.61×12.17 | 통과(가져오기됨) | 안 함 |  |

## 5. 아직 업로드 안 된 것 — 가져오기 묶음(≤10개씩, 가져오기 버튼은 사용자)
| 묶음 | 내용 | 파일 | 승인 | 질감 |
|---|---|---|---|---|
| A (가장 급함) | 교차로 분수 ② 1 + 빛 성·뿔 성 고친 판 2 | 위 0번 + `build/castle/*`(준비 중) | ② 검수 고름 / 성은 시트 뒤 | ② 다시 입힘, 성 고친 판 |
| B | 마을 가게 12: Town_Halo/Horns_Bakery·Potion·Smithy·JuiceBar·HouseA·HouseB (Tripo 묶음 2, 10/06) | `art/models/tripo/town/*_raw.glb` | 생성은 사용자 승인(1040), 결과 시트 `art/review/tripo_batch2/` — 검수 확인 필요 | 안 함 |
| C | 교차로 작은 소품 16: Kit_X_Anvil·BannerHalo·BannerHorns·Barrel·Bench·Brazier·Bush·Crate·Curb·Fence·FlowerPot·Forge·FruitCart·Lamp·PotionCart·StallRed (묶음 2) | `art/models/tripo/kit_crossroads/*_raw.glb` | 위와 같음 | 안 함 |
| D | 3b 웹 HD 13: Halo/Horns WallTower·HouseC·Bridge, X_Altar·MarketArch·NoticeBoard·GooseNest·TreeB·HouseA·HouseB + 뿔 화로 | `art/models/tripo/web_fixed/<이름>_fixed.glb` | 시트 `art/review/3b_hd/`(검수 확인 중) | ④' 짝 색 + AO + 금속 0.15(③ 없음) |
| E | 게시판 2(Kit_M_JobBoard, Kit_W_JobBoard) + 모닥불 불꽃판(Kit_W_Campfire_Fire) | `art/models/tripo/Kit_M_JobBoard_raw.glb`, `Kit_W_JobBoard_fix.glb`, `Kit_W_Campfire_Fire_raw.glb` | 통과 | 안 함 |

괴물·옷·애완(Monster*, Costume*, PetBabySlime)은 장식이 아니라 이 표에서 뺐다(개발 1 몫).

## 6. 가져오기 파일(준비 끝, `build/import_*/`, 사용자가 WorldKit '3D 가져오기'로 한 번씩)
| 묶음 | 파일 | 개수 | 크기 | 안에 든 것(스터드 폭×깊이×높이) |
|---|---|---|---|---|
| A | `build/import_A/WorldKit_ImportA.glb` | 2 | 17.5MB | Town_Halo_Fountain 21.0×20.89×16.3; Town_Halo_Castle 70.0×55.38×65.71 (9조각) — **10/07 밤 다시 만듦: 덩어리 뿔 성 v4를 파일에서도 뺌**(옛 spec `build/import_A/spec_with_horns_v4.json`). 새 뿔 성(묶음2 2D 창문 지운 판 / v4, Tripo 웹 HD 둘 비교, 검수 OK 110) → 고른 것 9조각을 다음 가져오기에 |
| H (10/07 밤) | `build/import_all/1_first/H_HornsCastle_v6mv.glb` (원본 `build/import_H/`) | 1 | 16.3MB | Town_Horns_Castle — ③ 섞은 판(앞 v4 2D + 새 뒷모습 2D, Tripo 웹 멀티뷰 HD 38,432면) 83.84×84.0×65.76 (9조각, 조각마다 1024) — **사용자 확정 10/08 "섞은 판 하자"(SPEC A23-74, c605010)**, 조각 원본 `art/models/tripo/web_fixed/Town_Horns_Castle_v6mv_tiles.glb`. ①·② HD는 안 씀(파일만 보관) |
| B1 | `build/import_B1/WorldKit_ImportB1.glb` | 6 | 2.6MB | Town_Halo_Bakery 14.0×12.03×14.21; Town_Halo_Potion 13.41×13.51×16.0; Town_Halo_Smithy 14.0×12.53×14.0; Town_Halo_JuiceBar 12.0×11.79×13.08; Town_Halo_HouseA 12.0×9.98×11.92; Town_Halo_HouseB 11.85×10.62×16.0 |
| B2 | `build/import_B2/WorldKit_ImportB2.glb` | 6 | 2.6MB | Town_Horns_Bakery 14.0×12.72×13.93; Town_Horns_Potion 14.31×12.44×16.0; Town_Horns_Smithy 14.0×12.14×13.27; Town_Horns_JuiceBar 12.0×11.12×11.17; Town_Horns_HouseA 12.0×9.81×10.55; Town_Horns_HouseB 13.16×11.76×16.0 |
| C1 | `build/import_C1/WorldKit_ImportC1.glb` | 10 | 2.1MB | Kit_X_StallRed 10.0×7.48×12.91; Kit_X_PotionCart 5.73×4.25×7.5; Kit_X_Bench 6.5×3.12×4.31; Kit_X_Lamp 5.1×2.81×11.0; Kit_X_Barrel 2.82×2.98×3.0; Kit_X_Crate 3.04×2.94×2.5; Kit_X_FruitCart 5.0×4.29×3.65; Kit_X_FlowerPot 2.44×2.1×2.5; Kit_X_BannerHalo 5.54×2.14×14.0; Kit_X_BannerHorns 5.66×1.79×14.0 |
| C2 | `build/import_C2/WorldKit_ImportC2.glb` | 8 | 4.1MB | Kit_X_Brazier 3.8×3.8×4.0; Kit_X_Anvil 4.5×3.61×4.15; Kit_X_Forge 6.0×5.88×6.92; Kit_X_Curb 6.0×2.78×1.48; Kit_X_Fence 6.0×1.17×2.23; Kit_X_Bush 3.45×3.32×3.0; **Kit_X_StallBlue 10.0×7.48×12.91; Kit_X_StallGreen 10.0×7.48×12.91 (10/08: 빨강 가판대 차양만 색 바꿈, 0포인트, 검수 OK 안 A)** |
| D1 | `build/import_D1/WorldKit_ImportD1.glb` | 7 | 21.8MB | Town_Halo_WallTower 12.91×12.63×24.0; Town_Horns_WallTower 15.05×14.39×24.0; Town_Halo_HouseC 16.0×8.13×12.48; Town_Horns_HouseC 16.0×12.35×18.16; Town_Halo_Bridge 22.0×11.93×14.13; Town_Horns_Bridge 13.93×22.0×8.45; X_Altar 9.0×8.55×7.83 |
| D2 | `build/import_D2/WorldKit_ImportD2.glb` | 7 | 23.1MB | X_MarketArch 12.0×2.91×10.36; X_NoticeBoard 16.0×7.04×15.44; X_GooseNest 12.0×11.11×7.57; X_TreeB 9.13×7.49×16.0; X_HouseA 14.0×11.35×14.1; X_HouseB 12.0×9.11×14.39; Town_Horns_Brazier 11.0×10.16×10.35 |
| E | `build/import_E/WorldKit_ImportE.glb` | 3 | 0.7MB | Kit_M_JobBoard 16.0×7.35×14.94; Kit_W_JobBoard 16.0×7.38×15.69; Kit_W_Campfire_Fire 4.0×3.9×3.31 |
| D3 (10/08) | `build/import_all/3_third/D3_PlazaWallStairs.glb` (원본 `build/import_D3/`) | 2 | 2.5MB | Kit_X_PlazaWall 9.73×2.81×3.0 (되풀이 — 끝 기둥 1.46 겹쳐 이음); Kit_X_PlazaStairs 7.64×6.36×3.5 (Firefly 고급 + Tripo 웹 HD 각 55, 검수 OK, 시트 `art/review/town5/plaza_wall_stairs_3d.jpg`) |
| D4 (10/08) | `build/import_all/3_third/D4_TownStatueRock.glb` (원본 `build/import_D4/`) | 2 | | Town_Halo_KnightStatue 6.14×5.34×10.0 (빛 마을 HeroStatue 6자리); Town_Horns_SpikeRock 12.23×11.78×16.0 (뿔 마을 Spike 14자리, ScaleTo 0.8~1.35로 높이 섞기) — Firefly 고급 + Tripo 웹 HD 각 55, 검수 OK, 시트 `art/review/town5/statue_rock_3d.jpg` |

**사용자가 고르기 쉽게(10/07 밤):** 같은 파일을 `build/import_all/1_first`(A·E) → `2_second`(B1·B2·C1·C2) → `3_third`(D1·D2) 폴더에 나눠 둠 — WorldKit 홈 '3D 가져오기'에서 폴더 안 파일을 모두 골라 한 번에 가져오기, 세 번에 나눠서.

가져온 뒤: 이미지 생성 1이 WorldKit에서 MCP로 MeshId·TextureID(성은 조각마다)를 읽어 `art/models/worldkit/import_<묶음>_assets_2026-10-07.json` 장부로 적고, 검수가 메인에 배치.

## 7. 후보(아직 안 만듦 — 검수가 정하면 2D 시안 → Tripo)
| 이름 | 어디 | 왜 | 출처 |
|---|---|---|---|
| 덩굴 나무 아치(초원 입구) | 초원 입구 문(지금은 갈색 막대 문틀, 옛 파트) | 시안 Concept_SlimeMeadow 왼쪽 위의 덩굴·랜턴 나무 아치 | 튀는 곳 시트 ⑭ `art/review/terrain/terrain_standout_2026-10-07.jpg`(e39ba95), 검수 10/07 "목록에만" |
| ~~파랑·초록 가판대(교차로)~~ → **10/08 만듦**: Kit_X_StallBlue/Green(빨강 차양만 색 바꿈, C2) | 교차로 북서쪽 K_StallBlue (-22.4, -42.7)·K_StallGreen (-36.6, -34.5) | — | `art/review/town5/crossroads_stalls_blue_green.jpg` |
| ~~광장 둘레 돌 난간 담 + 계단(교차로)~~ → **10/08 만듦**: Kit_X_PlazaWall·Kit_X_PlazaStairs(D3) | 튀는 곳 ⑨ 갈색 바위 더미 자리 | — | `art/review/town5/plaza_wall_stairs_3d.jpg` |
