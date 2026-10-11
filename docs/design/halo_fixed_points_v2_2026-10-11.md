# 빛 마을 v2 — 6단계 고정점 표 (새 섬에서 어디로 가나)

> 이미지 생성 1, 2026-10-11. `py -X utf8 tools/halo_fixed_points.py`로 계획 JSON에서 다시 만든다(손으로 고치지 말 것). 계획의 좌표는 3단계 3차(1.5배 키움)가 이미 반영된 최종 값이다. **6단계(메인에 한 번에) 직전에 이 표대로 Config·시험을 일괄로 고친다.**
> 코드는 plan JSON을 읽지 않는다. 고정점은 Config 값·이름·태그다. 줄 번호는 이 표를 만들 때(origin/main) 기준이라 조금 어긋날 수 있으니 이름으로 찾는다.

## A. 그대로 (건드리지 않음)

| 무엇 | 값 | 어디 |
|---|---|---|
| 다리 Bridge_Halo | (0,0,-150) → (0,0,-330), 폭 22, 갑판 Y ~0.2 | `Config.Map` Bridges `Halo` (Config 1810) |
| 성문 Gate_HaloTown | 위치 (0,0,-330), PrimaryPart `Lintel` (새 골격의 Lintel 앞 반쪽 금 코니스가 (0,-330)에 앵커) | `Config.Map` Gates (1784), MapBuilder `placeGate`가 매번 맞춤 |
| 스폰 / 보는 쪽 | Spawn (0,0,-420), SpawnLook (0,0,-330) | `Config.Zones.HaloTown` (1640~1641) |
| 스폰-문 통로 | 가운데 x ±12 안, z -330..-432와 (0,-420) 반경 12는 비움 | plan 검사 `스폰-문 통로 막음` 0건 |
| 길잡이 Bright | At (18,0,-424), Look (18,0,-380) | `Config.TownNpcs` (3722) |
| 이동 발판 | Pad_Halo_SlimeMeadow (-24,0.7,-357), Pad_Halo_GoblinWoods (24,0.7,-357) | `Map.Pads`, 가운데(x ±40 안) 안 |
| 오프닝 조각 착지 | SPOT.Halo (0,16,-410) | `Intro.luau` 40 |
| 큰 지도 라벨 | HaloTown (0,0,-400) | `WorldMap.luau` 77 |
| 분수 이름 | `Town_Halo_Fountain3` (FountainFx), 등불 `LampLight`, 충돌 그룹 `DecorPlayerOnly` | 이름 규칙 |

## B. 옮김 (Config 줄 → 새 값)

| 무엇 | 지금 | 새 값 | 어디 |
|---|---|---|---|
| 영웅상 HeroStatue | (0,0,-370) | `Vector3.new(-34, 0, -388)` (큰 길 통로 x ±12 안 밖; 높은 층이면 `StoryLandmark` 태그 + `Spot="HeroStatue"`) | `Config.StoryQuests.Landmarks.HeroStatue` (3538); H6 Near 16 |
| Sir Gleam | At (-10,0,-372) Look (0,0,-372) | At `Vector3.new(-20, 0, -390)`, Look 큰 길 쪽 `Vector3.new(0, 0, -390)` (영웅상 옆, 고리길 밖) | `Config.TownNpcs` Gleam (3724) |
| 물약 상인 PotionHalo | At (20.07,0,-468.17) | At `Vector3.new(32.5, 0, -483.5)` (Y 5; 12칸 안에서 팜/말함), Look `Vector3.new(31.7, 0, -472.3)` | `Config.TownNpcs` PotionHalo (3735) |
| Folk3 빵집 | At (-6.35,0,-476.52) | At `Vector3.new(101.9, 0, -452.8)` (Y 6; 12칸 안에서 팜/말함), Look `Vector3.new(93.2, 0, -459.9)` | `Config.TownNpcs` Folk3 (3730) |
| Folk1 주스 | At (38.42,0,-499.19) | At `Vector3.new(130, 0, -507)` (Y 8; 12칸 안에서 팜/말함), Look `Vector3.new(119.5, 0, -503)` | `Config.TownNpcs` Folk1 (3726) |
| Folk2 꽃 | At (6.6,0,-489.63) | At `Vector3.new(66.4, 0, -514)` (Y 6; 12칸 안에서 팜/말함), Look `Vector3.new(69.2, 0, -503.1)` | `Config.TownNpcs` Folk2 (3728) |
| Folk4 분수 | At (46,0,-556) | At `Vector3.new(36, 0, -596)` (Y 10; 12칸 안에서 팜/말함), Look `Vector3.new(22, 0, -590)` | `Config.TownNpcs` Folk4 (3732) |
| 훈련장 표시 (새) | 없음 | `Vector3.new(-130, 2, -446)` (Landmark `TrainingYard` + 허수아비 표적; M1_4 귀환 뒤 들르는 곳 — 퀘스트가 가리키게 할지는 코드 변경 요청, 검수 결정) | 새 Landmark, 게임성 개발 |
| 폭포 소리 | 6곳 (±188,3,-493) (±190,7,-582) (±190,11,-660) | 3곳 `Vector3.new(-85, 1, -340), Vector3.new(-38, 21, -699), Vector3.new(288, 12, -641)` (W1 성문 서쪽 1단 → 바다, W2 계단 폭포 3단, W3 동쪽 절벽 2단) — 또는 `Map.Decor` 바로 아래 이름이 `…Waterfall`인 것 | `Config.Audio.Ambient.Waterfall.Spots` (5576) |
| 분수 | (22,..) 옛 | 풀 중심 `Vector3.new(22, 10, -590)`, 반지름 9 (2단, 이름 `Town_Halo_Fountain3`) | 새 분수 모델(5단계) |

## C. 넓힘 (땅이 커졌다: x -300..295, z -853..-325)

섬이 이웃 땅과 안 겹침(초원 z -240..240, 십자로 ±150; 빛 마을은 z -330보다 남쪽). 가장 높은 땅 Y 30 < 물 구조 MaxRise 42 그대로.

| 무엇 | 지금 | 새 값 | 어디 |
|---|---|---|---|
| HaloTown 구역 상자 (PvP 안전·마을 음악·Enter 퀘스트·적 진영 튕겨내기·몬스터 추적 한계) | Center (0,0,-515) Size (400,0,370) | Center `Vector3.new(-2.5, 0, -596.5)` Size `Vector3.new(615, 0, 533)` (x -310..305, z -863..-330) | `Config.Zones.HaloTown` (1638) |
| 섬 땅 IslandHalo | MinX -200 MaxX 200 MinZ -700 MaxZ -330 | MinX -310 MaxX 305 MinZ -863 MaxZ -330 (실제 해안은 `plan.land` 다각형; Terrain은 5·6단계 블록아웃 지형) | `Config.Map.Lands` (1801) |
| 세계 경계 Bounds | MinX -260 MaxX 1840 MinZ -720 MaxZ 720 | MinX -320 MinZ -873 (MaxX·MaxZ 그대로: 뿔 마을은 그대로라 남북이 비대칭) | `Config.Map.Bounds` (1766) |
| Outskirts (그 밖 전부) | Center (790,0,0) Size (2100,0,1440) | Center `Vector3.new(760, 0, -76.5)` Size `Vector3.new(2160, 0, 1593)` (세계 전체를 덮어야 함) | `Config.Zones.Outskirts` (1674) |
| 미니맵 띠 RoadNorthIsland | x -8..8, z -600..-330 (곧은 띠) | 새 큰 길은 굽어 있어 곧은 띠로는 안 맞음 → 미니맵 타일을 새 지형에서 다시 찍고, 이 띠는 `plan.roads[main]` 꼭짓점을 따라 이은 여러 사각형으로 바꾸거나 지움(게임성 개발·메인 반영 1 확인) | `Config.Map` (1825, 1845) |
| 마을 음악 / 안전 구역 | 구역 상자를 따름 | 위 구역 상자로 자동 | |

## D. 다시 그림

- **큰 지도 그림**(WorldMapV2 94679214685541): 섬 모양·크기가 그림에 박혀 있어 새 섬으로 다시 그린다(이미지 생성 2). 라벨 위치는 위 A.
- **미니맵 Halo MapTiles**: 새 지형에서 다시 찍는다(메인 반영 1). 타일 범위는 구역 상자와 같게.

## E. 건물·장식이 들어가며 따라 바뀌는 것 (참고)

| 건물 | 새 자리 (x, z) | 지반 Y |
|---|---|---|
| Gate | (0, -334) | 0 |
| Tower_GateEast | (39, -346) | 0 |
| Shop_Potion | (40, -490) | 5 |
| Shop_Bakery | (103, -443) | 6 |
| Shop_Juice | (139, -503) | 8 |
| Shop_Flower | (58, -519) | 6 |
| Armory | (-175, -417) | 2 |
| Castle | (-176, -574) | 16 |
| Cathedral | (84, -772) | 30 |
| Tower_Lookout | (233, -777) | 28 |

## F. 6단계에서 다시 돌릴 시험 (옛 json 경로가 박힌 것은 v2 json으로)

- 지도·마을 퀘스트·NPC: `test_map_v2`, `test_town_quests`, `test_town_npcs` (옛 `halo_layout_plan_2026-10-10.json` 경로 → `halo_plan_v2_2026-10-11.json`)
- 스폰·분수: `test_spawn_look`, `test_fountain_fx`
- 땅·물: `test_ground_rays`, `water_rescue`
- 소리·퀘스트 표시·복귀·카이주: `audio_offline`(폭포 소리 3곳), `quest_target_offline`(Pad), `return_offline`, `kaiju_town_offline`

## G. 메모

- 걷는 바닥은 `WalkGround` 태그(Config.Ground.Tag) 또는 Terrain: 전망 탑 발코니 바닥(`BalconyFloor`)은 이미 태그가 달려 있고, 길·광장·마당·계단·다리 파트 골격은 새 생성기에서 전부 태그를 단다.
- 성문 모델 이름은 지금 `Gate`(회색 상자 자리). 6단계에서 `Gate_HaloTown`으로 바꾸고 `Map.Gates` 아래로 옮긴다(PrimaryPart `Lintel`).
- 떠 있는 섬: 둘레 20칸 물 띠 + 낮은 바위 테, 그 밖은 하늘. 메인에 넣을 때 하늘·구름이 같은 규칙인지(메인 반영 1과 확인).
