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

## 고른 뒤 할 일
- 조명: 게임성 개발이 WarService LIGHTING_FIXED·SKY_EXTRAS와 Config.Sky(Neutral·Dawn·Eclipse)에 표 값을 넣는다. Dawn은 B와 같은 원칙(EnvironmentDiffuse 1.0·Specular 0.6·밝은 중립 Ambient)으로 맞춘다.
- 땅 E를 고르면: 이미지 개발이 Config Tex_ 키 4개를 새 ID로 바꾸고 `tools/apply_surface_materials.lua`로 MaterialVariant를 새로 만들고(지형 색 235), terrain_view로 확인한 뒤 옛 Tex_ 파일·기록을 지운다. 나머지 11장(Slate·Basalt 등)은 다음 묶음.
- 땅 D를 고르면: 잔디·숲 바닥만 색 전용 재질로 바꾸고 나머지는 새 그림을 기다린다.
