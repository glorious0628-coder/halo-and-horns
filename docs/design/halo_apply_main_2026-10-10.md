# 빛 마을 메인 적용 순서 (이미지 생성 1 → 메인 반영 1, 2026-10-10)

연습장(`build/WorldKit.rbxlx`)에서 시험한 결과를 메인에 옮기는 순서. 메인에서는 **지형 → 키트 → 소품** 순서가 중요해요(앞 단계가 없으면 다음이 멈춰요).

## 준비물 (전부 origin/main)
- id 장부: `art/models/worldkit/import_halo_town_assets_2026-10-10.json` (20개, 이미 Roblox에 올라가 있음 — 메인에서는 올릴 필요 없이 id로 키트만 만들면 돼요)
- 도구: `tools/build_kit_from_ids.py`, `tools/worldkit/halo_materials.luau`, `tools/worldkit/halo_terrain.luau`, `tools/worldkit/halo_props.luau`(배치 계획 `docs/design/halo_layout_plan_2026-10-10.json`이 안에 들어 있음, 다시 만들기: `py tools/halo_layout.py` → `py tools/halo_embed_plan.py`)

## 순서 (메인 Studio = GoodEvil, Edit 모드)
1. **키트:** `py tools/build_kit_from_ids.py --list art/models/worldkit/import_halo_town_assets_2026-10-10.json --out build/kit_args_halo.json` → `py tools/studio_mcp.py call execute_luau @build/kit_args_halo.json` (ServerStorage.WorldKit3D에 Halo_* 19개 + `Town_Halo_Fountain3` 만듦. `Town_Halo_Fountain`(교차로 구름 분수)은 건드리지 않음. 충돌: 문·다리·분수·대성당·집·가게는 PreciseConvexDecomposition).
2. **재질:** `py tools/run_worldkit_tool.py tools/worldkit/halo_materials.luau apply` (Concrete → 정원 타일).
3. **지형:** `py tools/run_worldkit_tool.py tools/worldkit/halo_terrain.luau apply` (첫 실행은 평평한 기준 저장, 문 끝·스폰 길은 Y 0.2 그대로).
4. **소품:** `py tools/run_worldkit_tool.py tools/worldkit/halo_props.luau plan` → 숫자 확인(274개, `missing kit: none`) → `... apply`. 한 번 더 `apply`해도 같은 결과(먼저 자기 것을 지우고 옛것을 되돌린 뒤 다시 보관). 되돌리기 = `restore`.
   - 하는 일: 낡은 HaloTower·HeroStatue·Cathedral(옛 랜드마크 돔)·Cloud·Town_Halo_* 복사본·옛 Gate_HaloTown·갈색 길 RoadNorthIsland를 `ServerStorage.HaloPropsOld`로 보관(지우지 않음). **`Bridge_*`·`Roads`·`Gate_*`(새 것 제외)·Pads는 절대 안 건드림.**
   - 문: `Map.Gates.Gate_HaloTown` = 모델, PrimaryPart `Lintel`(보이지 않음, 충돌 없음, 앞 가장자리 (0,19,-330)), 문 메시(조각 9개) 자체가 정밀 충돌(PreciseConvexDecomposition) — 통로 바닥 언덕(최고 7.6)·등불 받침·낮은 벽이 막히고 아치 통로(높이 9~18)는 열림(10/10 실측), 보이지 않는 탑 블록은 없앰. 서버 시작 때 `MapBuilder.placeGate`가 안 밀게 이 구조 유지(Play 두 번 재시작해서 문이 안 움직이는지 확인).
   - 충돌 그룹 `DecorPlayerOnly`가 등록돼 있어야 해요(없으면 요약 끝에 `NOT registered`가 찍힘 → 등록 후 다시 apply).
   - **`decor_collision.luau`를 이 뒤에 돌리지 마세요**(HaloProps는 종류별로 이미 충돌을 정했어요).
5. **이동 판 2개(점검표 #52):** `Map.Pads.Pad_Halo_SlimeMeadow`·`Pad_Halo_GoblinWoods`(속성 `TravelTo` = SlimeMeadow / GoblinWoods), 자리 (-24, 0.2, -357)·(24, 0.2, -357) — 1단 잔디, 문 바로 안쪽 양옆, 평평(±5스터드 높이차 0.3 이하)하고 배치 도구가 이 12×12 칸을 비워 둠(halo_layout.py PADS, 10/10 검수 ③: 옛 제안 ±26,-372는 풀 둔덕 + 깃대). 스폰 길 |x|≤12 밖. 모양은 MapBuilder `ensurePads`와 같은 파랑 판. 개발 1이 빛 표시·미니맵.
6. **확인(PC 사진 + 걷기):** 스폰(0,-420) → 큰길 → 문 → 다리(Bridge_Halo) → 교차로 걸어서 되는지 / 문 통로를 지나가는지 / 계단 3곳 오르기 / 다리 14개 중 4개 건너기 / 분수 FountainFx 물줄기(개발 1이 SPECS `Town_Halo_Fountain3` 숫자 맞춤) / 가게 간판 4종 위치 / 밤 등불(`LampLight`) / 그림자. 시안과 같은 각도: 문 앞, 큰길, 광장, 날개 정원, 폭포, 다리(`art/review/s2/place_HaloTown_sheet.jpg`).
7. **알려진 것:**
   - 대성당·돔집 A 질감이 에셋 심사로 회색일 수 있음(10~30분, 새로 올린 직후 흔함). 계속 회색이면 이미지 생성 1이 새 이름으로 다시 올림.
   - **탑은 문이 너무 작아**(1.6스터드) 속성 `DoorTooSmall = true`. 탑 입장이 필요하면 새 그림 + Tripo 다시(검수 결정 대기). 집 A·B·가게는 ×1.9/2.0으로 키워 문 키 5.4~6.5, 대성당 문은 계단 위 10스터드.
   - 문 속성: 모델 `Door`=true, `DoorSize`(Vector2), `DoorFront`(모델 로컬 Vector3: 문 1.5스터드 앞·문턱 높이; 피벗 = 밑면 가운데, 앞 = -Z).
   - 가게 간판: 가게 모델 안 `SignBoard`(벽에 수직, 앞·뒤 SurfaceGui), `ShopKind` = Bakery/Juice/Flower/Potion(**Potion = 진짜 물약 상인 가게 = 동남쪽(+x, z -584)**). 위치는 메인 Play에서 한 번 보고 다듬기(연습장 Edit 사진엔 SurfaceGui가 안 보임).
   - 가장자리 투명 벽은 안 넣음(부품 416개) → 서버 '물에 8초 이상 → 가까운 땅' 규칙(개발 2, 점검표 #11·#62·#63).
   - 면 수: 큰 것 합 약 65k, 소품 포함 약 0.8M(예상). 실측·줄이기는 10/17 PerfMem. 줄일 때 쓰는 스위치: 소품 속성 `DecorTier = "lite"`(Planter·CloudBush·Topiary·RoundTree·PotFlowers·Balustrade·Lantern·BannerPole·Islet·FarArch) 를 폰에서 숨김(점검표 #33).
