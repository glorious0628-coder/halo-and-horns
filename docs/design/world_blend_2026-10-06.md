# 배경·몬스터 어울림 시안 (이미지 개발, 2026-10-06)

사용자 신고: "배경이랑 몹들이 융화가 안 돼요." 검수 요청으로 연습 Studio(UiSandbox)에서만 시안을 찍었다.
코드·장소 파일은 바꾸지 않았다(Play 중에만 속성을 바꾸고 Play를 멈추면 원래대로). 고른 값은 게임성 개발이 WarService·Config.Sky에 넣는다(코드 소유).

- 시트: `art/review/world_blend_2026-10-06_sheet.png` (말랑 초원·고블린 숲·해골 폐허 × A~E, 밤 2장).
- 다시 찍기: `py tools/world_blend_view.py` → `build/world_blend/<자리>_<A~E>.jpeg`, `night_A/new.jpeg`, `values.json`.
- 카메라: 각 자리에서 몬스터가 가장 많이 모인 무리(22스터드 안)를 고르고, 해가 비추는 쪽에서 35° 돌아 21스터드 뒤·8.5스터드 위(벽·기둥이 가리면 다른 각도). A~E는 같은 카메라, 1280×720 PC 흉내, HUD 숨김.
- 안개(Atmosphere)·지역별 ColorCorrection은 쓰지 않았다(A9-3). WarTint는 원래 있는 전역 1개만 썼다.

## 조명 (Lighting + 효과)

| 속성 | A 지금 (Neutral) | B 밝은 장난감 (C·D·E도 같음) | 밤 지금 (Eclipse) | 밤 제안 |
|---|---|---|---|---|
| Brightness | 1.8 | **2.0** | 0.78 | 1.2 |
| ClockTime | 16.8 | **14.2** | 0.5 | 0.5 |
| Ambient | 70,60,55 | **110,108,106** | 75,5,5 | 95,55,70 |
| OutdoorAmbient | 120,105,90 | **128,126,124** | 85,5,5 | 110,70,85 |
| EnvironmentDiffuseScale | 0.3 | **1.0** | 0.3 | 1.0 |
| EnvironmentSpecularScale | 0.3 | **0.6** | 0.3 | 0.6 |
| ShadowSoftness | 0.2 | **0.5** | 0.2 | 0.5 |
| ExposureCompensation | -0.1 | **-0.2** | 0.35 | 0.35 |
| FogColor / Start / End | 190,170,140 / 120 / 650 | **205,215,230 / 250 / 1100** | 90,10,20 / 120 / 650 | 90,10,20 / 120 / 650 |
| Bloom Intensity / Size / Threshold | 0.4 / 24 / 1.4 | **0.2 / 24 / 2.2** | 0.7 / 24 / 1.4 | 0.5 / 24 / 1.6 |
| SunRays Intensity | 0.08 | **0.04** | 0 | 0 |
| WarTint Brightness / Contrast / Saturation | 0.02 / 0.1 / 0.2 | **0 / 0.05 / 0.1** | 같음 (Tint 255,185,185) | 0 / 0.05 / 0.1 (Tint 255,200,200) |

- B를 고른 과정: 처음 값(Brightness 2.4, Exposure 0, Ambient 128)은 마을의 흰 길·석회암이 하얗게 날아가서 한 단계 낮췄다(B2 = 위 표).
- 밤 지금은 화면이 빨강·검정이라 슬라임이 거의 안 보이고, 밤 제안은 빨간 하늘·안개는 그대로 두고 몬스터가 보인다.

## 땅 (MaterialService · Terrain 색)

| 항목 | A 지금 | C | D | E |
|---|---|---|---|---|
| 잔디 Grass | GE_Grass(옛 그림), StudsPerTile 14, 색 106,150,72 | 타일 28, 색 112,168,82 | **무늬 없는 새 재질(색만)**, 색 106,148,86 | **새 그림 Tex_Grass_FF**, 타일 16, 색 235,235,235 |
| 숲 바닥 LeafyGrass | GE_LeafyGrass, 14, 70,110,55 | 28, 92,140,70 | 무늬 없음, 88,122,72 | **Tex_LeafyGrass_FF**, 16, 235 |
| 흙길(길 파트) | GE_DirtPath, 14 | 28 | 28 | **Tex_DirtPath_FF**, 16 |
| 돌바닥 Cobblestone | GE_Cobblestone, 14, 170,160,140 | 24, 178,168,148 | 24, 178,168,148 | **Tex_Cobblestone_FF**, 14, 235 |
| 폐허 Slate | GE_Slate, 14, 63,127,107 | 28, 104,138,124 | 28, 104,138,124 | 그대로(A) |

- C(무늬만 크게)는 잡무늬가 커질 뿐 덜 시끄러워지지 않았다.
- D는 새 그림 없이 가장 장난감 같고 몬스터가 또렷하지만, 언덕·숲 바닥의 결이 사라져 단조롭고 고블린 숲이 초원처럼 밝아진다.
- E는 이미지 생성의 새 땅 그림 4장(커밋 c2e9800, 1024 이음새 없음). 연습용으로 올린 ID: Tex_Grass_FF 104463174886181, Tex_LeafyGrass_FF 92129043469297, Tex_DirtPath_FF 85612652410118, Tex_Cobblestone_FF 72599078474763 (`art/ui/asset_ids.json`에 sandbox-test로 표시, Config·메인 장소에는 아직 안 넣음).
  - 새 그림은 자기 색을 가지고 있어 지형 색을 235,235,235(거의 흰색)로 둬야 두 번 어두워지지 않는다. 옛 색 그대로면 진한 초록이 된다.
  - 맵 없는 새 MaterialVariant를 만들어 씌웠다(옛 변형을 복제하면 옛 TexturePack이 남는다: apply_surface_materials.lua 주석).
  - 막 올린 그림은 처음 한 번 하얗게 보이다가 불러온 뒤 바뀐다(도구가 미리 한 번 불러온다).

### 시트 바로잡기 (검수 2-5·2-6, 2026-10-06)
- 시트의 '밤 제안(E 땅)' 사진(`build/world_blend/night_new.jpeg`)은 실제로 **D 땅**(잔디·숲 바닥이 무늬 없는 색만)으로 찍혔다. 도구가 밤 제안의 땅을 E로 넣은 뒤 D(FLAT)로 다시 덮어썼다(`build/world_blend/values.json`의 night_new.Ground에 그대로 남아 있음). 지금 도구는 E 땅 하나만 넣는다. 밤 모습은 나중 시트 `art/review/zone_look_2026-10-06_sheet.png`(밤 초원·밤 폐허, 최종 땅 그림 + ZoneLook)가 대신한다.
- 해골 폐허 줄의 E 칸에는 C·D의 판석(Slate) 값(GE_Slate 타일 28, 지형 색 104,138,124)이 남아 있다. 도구가 A~E를 차례로 바꾸면서 그 사이에 A로 되돌리지 않았고, E는 Slate를 건드리지 않기 때문이다(위 표의 'Slate 그대로(A)'와 다름). 지금 도구는 설정마다 먼저 A로 되돌린다. 실제 E 모습은 ZoneLook 시트를 본다.

## 고른 뒤 할 일
- 조명: 게임성 개발이 WarService LIGHTING_FIXED·SKY_EXTRAS와 Config.Sky(Neutral·Dawn·Eclipse)에 표 값을 넣는다. Dawn은 B와 같은 원칙(EnvironmentDiffuse 1.0·Specular 0.6·밝은 중립 Ambient)으로 맞춘다.
- 땅 E를 고르면: 이미지 개발이 Config Tex_ 키 4개를 새 ID로 바꾸고 `tools/apply_surface_materials.lua`로 MaterialVariant를 새로 만들고(지형 색 235), terrain_view로 확인한 뒤 옛 Tex_ 파일·기록을 지운다. 나머지 11장(Slate·Basalt 등)은 다음 묶음.
- 땅 D를 고르면: 잔디·숲 바닥만 색 전용 재질로 바꾸고 나머지는 새 그림을 기다린다.

## 사냥터별 바닥 재질 (A23-30, 2026-10-06 UiSandbox 실측)

재질 하나 = 그림 하나(MaterialService 덮어쓰기는 재질마다 1개, 지형과 같은 재질의 파트에도 똑같이 씌워진다). 측정: 각 지역 사각형을 6스터드 격자로 위에서 쏴서 지형 윗면 재질을 셌다(`mat_survey`, Edit 모드).

| 재질 | 지금 쓰는 곳 (지형 칸 수 / 파트) | 지금 그림 | 새 그림(계획) |
|---|---|---|---|
| Grass | 말랑 초원 바닥 1849/1849, 초원 언덕, 바깥 들판 언덕 | GE_Grass (Tex_Grass) | **Tex_Grass_FF (E 확정)** |
| LeafyGrass | 고블린 숲 바닥 2116/2500, 숲 언덕 윗면 | GE_LeafyGrass | **Tex_LeafyGrass_FF (E 확정)** |
| Cobblestone | 교차로 마을 바닥 613/676 | GE_Cobblestone | **Tex_Cobblestone_FF (E 확정)** |
| Ground | 해골 폐허 흙 바닥 1720/2809, 바깥 들판 흙, 길 파트(재질 Ground) | GE_Ground | 폐허 흙(새) |
| (변형) GE_DirtPath | 길 파트 3개(Map.Decor.Roads, MaterialVariant 지정) | Tex_DirtPath | **Tex_DirtPath_FF (E 확정)** |
| Slate | 해골 폐허 판석 1043/2809, 폐허 언덕 아래, **길 파트 RoadPass·RoadRuins·RoadSouth(뿔 쪽)·다리 받침·MapBuilder 판석 파트** | GE_Slate | Tex_RuinsFlagstone(새) — 겹침 주의 ① |
| Limestone | 빛의 성채 바닥 675/676, **폐허 언덕 윗면**, 빛 언덕 | GE_Limestone | 빛 마을 바닥(새) — 겹침 주의 ② |
| Basalt | 뿔 소굴 바닥 668/676, 뿔 언덕, 뿔 문 기둥·다리 파트 | GE_Basalt | 뿔 바닥(새) |
| CrackedLava | 뿔 언덕 윗면·틈, 극한 경계 파트 | GE_CrackedLava | 용암 틈(새) |
| Rock | 모든 절벽(초원 언덕 윗면, 숲 언덕 아래, 교차로 가장자리 60) | GE_Rock | 절벽 바위(새) |
| Sand | 바닷가 | GE_Sand | 모래(새) |
| Water | 바다 | (Roblox 물) | 그림 없음 |
| Marble | 파트만: 분수·빛 다리·빛 건물 | GE_Marble | 대리석(새) |
| WoodPlanks | 파트만: 다리·벤치·판자 | GE_WoodPlanks | 나무 판(새) |
| **Mud (빈 칸)** | 아무 데도 안 씀 | — | **호박밭 흙 Tex_PumpkinSoil(새)** |
| 그 밖의 빈 칸 | Salt, Sandstone, Asphalt, Pavement, Concrete, Brick, Snow, Glacier, Ice | — | 앞으로 새 사냥터용 |

- 안 쓰는 변형 2개: GE_HaloTiles(Limestone 기반, 덮어쓰기·파트 사용 없음), GE_CrownShardGround(Ground 기반, 사용 없음). 새 그림 적용 때 정리.
- 겹침 주의 ① Slate: 폐허 판석 그림을 씌우면 뿔 소굴로 가는 길(RoadSouth·RoadSouthIsland)과 다리 받침도 폐허 판석이 된다. 길 파트는 Ground+GE_DirtPath로 바꾸는 것을 추천(MapBuilder·preview_map, 게임성 개발).
- 겹침 주의 ② Limestone: 빛 마을 바닥 그림이 해골 폐허 언덕 윗면에도 나온다. 폐허 언덕 윗면은 Slate나 Rock으로 바꾸는 것을 추천(preview_map ridge, 지형 다시 만들 때).
- 호박밭 바닥은 Mud(지금 0칸)를 쓰면 다른 곳과 안 겹친다. 호박밭 위치·지형은 게임성 개발이 정한다(A23-30).

## 사냥터별 분위기 ZoneLook (A23-30, 이미지 개발 2026-10-06)

`src/StarterPlayer/StarterPlayerScripts/ZoneLook.luau` (클라이언트). 전쟁 하늘(GameState WarBlessing: 없음 = Neutral, 빛 = Dawn, 뿔 = Eclipse)이 기본 빛을 정하고, 내가 선 지역(플레이어 속성 ZoneId)이 색을 덧칠한다. 내 화면에서만 1.5초 동안 부드럽게 바뀐다. 서버 조명이 하늘을 바꾸면(라운드 끝 3초) 쓰기가 멈춘 뒤 다시 지역 값으로 돌아간다. ClockTime·안개·Bloom·SunRays·하늘 상자·WarTint는 서버 것 그대로. 지역 색은 클라이언트가 만든 ColorCorrection "ZoneTint" 하나. Atmosphere 없음.

기본 빛(모든 지역 공통: EnvironmentDiffuseScale 1.0 · EnvironmentSpecularScale 0.6 · ShadowSoftness 0.5)

| 하늘 | Brightness | Ambient | OutdoorAmbient | Exposure |
|---|---|---|---|---|
| Neutral | 2.0 | 110,108,106 | 128,126,124 | -0.2 |
| Dawn | 2.1 | 128,112,92 | 150,130,104 | -0.15 |
| Eclipse | 1.4 | 100,62,78 | 115,76,92 | +0.45 |

지역 덧칠(Ambient·OutdoorAmbient 채널 배수 R,G,B · 해 밝기 배수 · Exposure 더함 · ZoneTint 색/채도/대비/밝기)

| 지역 | Ambient 배수 | 밝기 | Exposure | ZoneTint | 채도 | 대비 | 비고 |
|---|---|---|---|---|---|---|---|
| 말랑 초원(기본·바깥 들판) | 1, 1, 1 | ×1 | 0 | 255,255,255 | 0.1 | 0.05 | E 그대로 밝은 한낮 |
| 교차로 마을 | 1.03, 1, 0.97 | ×1 | 0 | 255,252,246 | 0.08 | 0.05 | 초원과 비슷 |
| 고블린 숲 | 0.9, 1.08, 0.88 | ×0.78 | +0.1 | 228,246,220 | 0.12 | 0.08 | 초록 그늘, 몬스터는 하늘빛으로 밝게 |
| 해골 폐허 | 0.8, 0.95, 1.3 | ×0.65 | +0.15 | 198,212,255 | -0.12 | 0.1 | 푸른 달빛, Specular 0.8 |
| 호박밭(PumpkinPatch) | 1.15, 0.85, 1.25 | ×0.85 | +0.08 | 255,205,170 | 0.2 | 0.08 | 주황 해(틴트)·보라 그늘(Ambient) |
| 빛의 성채 | 1.06, 1.04, 0.95 | ×0.88 | -0.12 | 255,246,228 | 0.06 | 0.05 | 흰 석회암이 날아가지 않게 |
| 뿔 소굴 | 1.12, 0.86, 0.9 | ×0.88 | +0.08 | 255,218,214 | 0.1 | 0.08 | 붉은 진영 색 |

- 밤(Eclipse)에는 지역이 해 밝기를 ×0.95 아래로 깎지 않는다(어두운 갑옷 해골 기사가 안 보이던 문제).
- 서버 쪽(게임성 개발): WarService LIGHTING_FIXED·Config.Sky도 위 기본 빛(B)으로 맞추면 하늘이 바뀌는 3초 동안의 깜빡임이 없어진다. ZoneLook이 없어도(예: 오래된 클라이언트) 같은 기본 빛이 된다.
- 시트: `art/review/zone_look_2026-10-06_sheet.png`, 다시 찍기 `py tools/zone_look_view.py`(UiSandbox Play, 캐릭터를 각 지역 안에 세움, 레벨·진영 문은 시험 속성으로 통과).

## 새 땅·나무 적용 (2026-10-06)
- 땅 13종(E 4장 + 10장: 폐허 판석·호박밭 흙·폐허 흙·석회암·현무암·용암·바위·모래·대리석·나무판)을 `tools/apply_surface_materials.lua`가 새 재질로 만든다(옛 재질 복제 안 함, ColorMap만, 지형 색 235). StudsPerTile: 잔디·숲 바닥·길·폐허 흙·바위·모래 16, 돌바닥·판석·석회암·현무암·용암·호박밭 흙 14, 대리석·나무판 10.
- 나무 46그루: 잎(Leaves·Leaves2, SmoothPlastic) = 이름 붙인 변형 GE_TreeLeaves(타일 9), 줄기(Trunk, Wood) = GE_TreeBark(타일 8). 덮어쓰기 없음(Wood·SmoothPlastic을 쓰는 다른 파트 약 300개에 안 번짐). 무채색 그림이라 파트 Color가 잎·껍질 색이 된다.
- **나무 색 제안(MapBuilder·preview_map, 게임성 개발 1):** 숲 잎 Color를 ×1.35 밝게(지금 40,90,45 → 54,121,61; 시트 '숲 나무 한 단계 밝게'). 새 잎 그림이 평균 0.76배 어두워서 지금 색 그대로면 숲 나무가 거의 검게 보인다. 초원 나무도 같은 비율 추천.
- **하늘 해(Sky_Sun):** Roblox 해 렌더에서 흰 꽃(데이지) 모양으로 보인다(시트 '새 해 그림'). 색이 사라지고 빛살이 꽃잎처럼 보여 기본 해보다 낫지 않다. 제안: 해는 빛살 없는 둥근 원판 한 장으로 다시 그리기(이미지 생성 1), Dawn 해·Eclipse 달은 하늘 바뀔 때 WarService가 Sky.SunTextureId/MoonTextureId로 바꾼다(게임성 개발).
- 길·다리 파트(Slate·Ground·WoodPlanks·Marble)도 파트 Color가 그림에 곱해진다. 어둡게 보이는 파트는 Color를 235 쪽으로(MapBuilder, 게임성 개발).
