# 빛 마을 apply 계획 — 메인 반영 1 (2026-10-10)

> 기록용(낡음) 10/11: 이 apply 계획은 **멈춤** — 빛 마을 처음부터 다시(A23-121), 메인 중간 적용 없음, 새 마을은 6단계에서 한 번에(`halo_restart_2026-10-11.md`, 고정점은 `halo_fixed_points_v2_2026-10-11.md`). 옛 plan 기준 점검·되돌리기 메모로만 본다. 규칙(공유 트리는 `py tools/push_paths.py`, Save to File As → 해시 → `place/` 복사, Publish 금지)은 AGENTS.md 그대로.

근거: `docs/design/halo_town_plan_2026-10-09.md`, 점검표 `docs/design/zone_check_halo_2026-10-10.md`(mainapply 줄: #13 #14 #15 #29 #48 #52 #66 #67 #68 #69, 그리고 #3·#8 Bridge_Halo). 시작 조건 = 이미지 생성 1의 가져오기 묶음(새 Tripo 모델이 WorldKit3D에 들어오고 kit_args가 준비됨). 그 전에는 메인 Studio 땅·모델을 안 건드린다.

## 0. 앞 점검 (Edit, 저장 전 상태 기록)
1. HEAD = origin/main(`git rev-list --left-right --count HEAD...origin/main` = `0 0`) → `py tools/sync_to_studio.py`.
2. #68: `ServerStorage.WorldKit3D.Town_Halo_KnightStatue`의 MeshId·삼각형 수 확인. 18k HD 메시면 새 동상이 올 때까지 `zone_swap halo`를 `new="Town_Halo_KnightStatue_LOD"`로 다시.
3. 되돌리기 준비: `halo_terrain`은 baseline을 `ServerStorage.HaloTerrainStore`에 저장(restore 가능). `halo_materials`는 `restore` 모드 있음. 옛 부품은 `ServerStorage.ZoneSwapOld`.
4. 시작 전 `halo_terrain` MODE "plan"으로 숫자만 확인(땅 안 바뀜).

## 1. Apply 순서 (한 번에, 검수 결정)
1. `halo_materials.luau` (apply) — GE_HaloPave Concrete.
2. `halo_terrain.luau` (apply) — 척추 단 Y 0.2·5·11·19, 날개 단 4쌍, 운하, 폭포 6곳.
3. 새 모델 배치(이미지 생성 1의 props 도구) — 아래 규칙 지키며.
4. 이동 판 2개 (#52): 광장(문 안쪽)에 `Map.Pads.Pad_Halo_SlimeMeadow`, `Pad_Halo_GoblinWoods`, 속성 `TravelTo` = SlimeMeadow / GoblinWoods, 지형 단 높이에 맞춤. `Config.Map.Pads`에는 안 넣음(개발 1이 빛 표시·미니맵). **판은 Model이 아니라 Part(BasePart, CanTouch 켬)로** 만든다 — 서버 ZoneService가 BasePart만 연결한다(검수 확인 10/10). 속성 `TravelTo`만 달면 안내·반짝임·지도 ▣는 개발 1 클라가 붙인다.
5. 충돌 (#48): `decor_collision` 다시 실행(또는 T.Tree에 Topiary 추가). 종류별: Gate·Cathedral·Towers·Houses·Shops·Stairs·ArchBridges = 보통 충돌 + CanQuery; Balustrade·Lantern·Planter·BannerPole·KnightStatue = DecorPlayerOnly; Topiary·RoundTree = 줄기 기둥; CloudBush = BlockPost; PotFlowers = 통과.
6. 동상 줄 가운데에 `Config.StoryQuests.Landmarks.HeroStatue` 맞추기(#29, 평면 거리라 단 높이 무관; 개발 1이 코드 쪽 먼저).

6. 가게 간판(#49·#51): 이미지 개발이 올린 4종 — HaloSignBakery `rbxassetid://77116902671887`, HaloSignJuice `133684891699718`, HaloSignFlower `93642542767036`, HaloSignPotion `122788599616130`(빛 마을 진짜 물약 상인 자리에만). 1024×1024 투명, 글자 없음. 가게 모델 간판 SurfaceGui의 ImageLabel(ScaleType Fit, 배경 투명)에 넣고, 대장간·모루 간판은 안 넣는다(`Config.UIArt.Parts` id와 같은지 확인).

## 2. 절대 규칙
- **`Map.Decor.Bridge_Halo`는 치우지 않는다** (#3·#8): zone_swap에 Bridge_* 건너뛰기 규칙이 들어가기 전에는 `zone_swap`을 빛 마을에 다시 돌리지 않는다. 새 다리 모양은 같은 모델 안에 넣거나 손으로 교체(상판 Y 0.2, 폭 22, z -150..-330, Precise 충돌, 이름 Bridge_Halo 그대로, 교차로 쪽 끝 (0,0,-150) 근처).
- 문: 새 Gate는 `Map.Gates.Gate_HaloTown`, 피벗 = 바닥 가운데 (0,0.2,-330), PrimaryPart = 메시 또는 아치 꼭대기 보이지 않는 `Lintel` 파트(#14). 옛 파트는 같은 편집에서 치움. PreciseConvexDecomposition 충돌 유지(아치 걸어 지남).
- 길: x -10..10, z -426..-330은 비워 둠(화단·동상·난간 금지, #15). 스폰 (0,0,-420), 문 끝·스폰 길 Y 0.2 그대로.
- 소품은 `Map.Decor` 아래.

## 3. apply 뒤 확인 (메인 Play, PC 먼저 → 폰)
- #66·#15: 신규 Halo 저장으로 스폰 → 대장간(오토) 걷기 시간(ForgeWalk 초)과 막힌 곳 기록 (`character_navigation`; 전·후 비교).
- 걸어서 스폰 → 다리 → 교차로, 반대로 마을로 돌아오기.
- #67: M1_4 → S6 → H1 퀘스트 흐름(행이 보이는지, 마커가 브라이트로, 선택은 마을에서), M2_3+ 저장으로 서브 4개 이상. 오류 0.
- #69: 분수 광장에서 운하·폭포 쪽을 보는 카메라로 PC·폰 FPS/프리미티브 수.
- #13: 위에서 본 타일(`tools/minimap_capture.py`) 찍어 올려 MapTiles에 넣기(이미지 개발과), 그 전엔 운하 물 사각형을 그림 모양에 추가.
- 시안 `art/review/s2/place_HaloTown_sheet.jpg` 6장과 같은 각도 사진 PC+폰 → 검수.
- 사용자 저장 부탁 → build 확인(시간·해시·내용) → `place/` 복사 → `py tools/push_paths.py` → `test_place_english`.
