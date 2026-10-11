# 이미지 생성 4 — 상태 (2026-10-11 밤)

## 지금 상태 한 줄
**(가) 파트 생성기 1·2묶음 26종 끝, WorldKit 반영(HaloV2.Props.Real 93개, 저장 안 함), 검수에 보고 + 사진 화면 신청함 → "전달함, 시작" 기다림. 다음 = 3묶음.**

## 한 것
- 나누기 표 `docs/design/halo_props_split_2026-10-11.md`(640e126): (가) 31종 102개 / (가+나) 27종 61개 / (나) 6종 22개.
- `tools/prop_kit.py` (cef79c5, a04e904): 키마다 파트 목록(Blender 틀: y = 앞, 앞에서 보면 +x가 왼쪽 → 2D 오른쪽 = -x, `mirror=True`로 뒤집기). 원·고리·아치·반구 = 원통·공 + CSG(GeometryService Subtract/Intersect, Studio에서 됨). `--apply` = WorldKit ServerStorage.HaloPropKits.<키>.
- 재질: 금 = Metal + HH_HaloGoldTrim (255,168,36); 대리석 = Marble 크림 변형 없음(plain, `--marble block` 가능), 줄눈 보이는 바닥만 `mblock`; 천 = HH_Fabric; 등 유리 = Glass + LampLight 속성 + 꺼진 PointLight + 네온 심지. 이미지 개발이 매끈한 크림 대리석 MV를 만드는 중(`tools/marble_smooth_*`) → 승인되면 MAT_LUA "marble" 한 줄만 바꿈.
- `tools/worldkit/halo_props_place.py`: ServerStorage.HaloPropKits에 키가 있으면 그걸 복제(ScaleTo 소품 배율, PivotTo 땅 + yaw) → Props.Real.
- 미리보기 `tools/prop_kit_preview.py`(Cycles CPU — EEVEE는 이 PC 백그라운드에서 멈춤; 상대 경로는 C:\build로 가니 절대 경로), 시트 `tools/prop_kit_sheet.py`, Studio 사진 `tools/prop_kit_shots.py`(화면 허락 뒤에만).
- 시트: `art/review/img4/propkit_c1_*_blender.jpg`, `propkit_c2_lamps_blender.jpg`.

## 다음
1. 검수 "전달함, 시작" → `STUDIO_NAME=WorldKit py tools/prop_kit_shots.py art/review/img4/studio_c12 --night` → 2D 옆 시트(`prop_kit_sheet.py --renders art/review/img4/studio_c12 --label Studio`) → 검수 보고 → "끝".
2. 3묶음 (가): GuardPost·Woodpile·Clothesline·RackShieldSword·Fountain3.
3. (가+나) 몸통: 화분 10종·Planter 3·RoundTree 3 화단·Topiary 3 화분·BenchB·VegGarden·BreadStand·FruitStall·FlowerCart·PotionCrate·Hedge 받침·Cauldron.
4. (나) Tripo: 식물은 이미 있는 4면 2D로 통째 → Blender에서 식물만 남김. 유료 묶음은 범위·개수 검수 승인 뒤.
5. 승인 뒤: 재질별 CSG 합치기로 파트 수 줄이기(등불 56개 ≈ 4천 파트).
