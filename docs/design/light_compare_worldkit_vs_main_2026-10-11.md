# 빛 값 표: WorldKit vs 메인(빛 마을 C2c) + 굽기 조언 — 이미지 개발 2026-10-11

용도: 파트 소품이 "그림자 없어 보임 / 선이 없어 보임" 비교 시험(이미지 생성 4, B칸). 메인 Studio는 안 열고 코드(`Config.Sky.Neutral`, `WarService.luau`, `ZoneLook.luau` HaloTown)와 `tools/halo_light_sim.luau`에서 읽음. WorldKit은 execute_luau 읽기만(바꾼 것 없음).

## 1. 빛 값 (낮) — 다른 칸은 ★

| 항목 | WorldKit 지금(원래) | 메인 빛 마을 C2c (낮) | 다름 |
|---|---|---|---|
| ClockTime | 14.0 | 15.3 (Neutral) | ★ |
| Brightness | 1.8 | 2.0 (Neutral 2 × HaloTown 1.0) | ★ |
| Ambient | rgb(70,60,55) 따뜻한 갈색 | rgb(104,103,114) = (72,76,86)×(1.45,1.36,1.32) 푸르스름 회색 | ★ 크게 |
| OutdoorAmbient | rgb(120,105,90) | rgb(138,141,156) = (95,104,118)×같은 비율 | ★ 크게 |
| ExposureCompensation | -0.10 | -0.10 (= -0.25 + HaloTown 0.15) | 같음 |
| EnvironmentDiffuseScale | 0.30 | 0.50 (WarService 고정) | ★ |
| EnvironmentSpecularScale | 0.80 | 0.80 (HaloTown, 기본 0.6) | 같음 |
| ShadowSoftness | 0.20 | 0.15 | ★ 작게 |
| GlobalShadows / GeographicLatitude | true / 35 | true / 35 | 같음 |
| Fog | (190,170,140) 120~650 | Neutral (150,205,228) 150~950 (구역 안개는 ZoneLook가 섞음) | ★ |
| Atmosphere | 없음 | 없음(A9-3 금지) | 같음 |
| Bloom | 켬, 강도 0.4, 크기 24, 문턱 1.4 | 강도 0.2, 크기 24, 문턱 2.2 | ★ |
| SunRays | 켬 (0.08) | 끔(광선 금지) | ★ |
| ColorGrading | 켬 | 코드엔 없음 | ★ |
| ColorCorrection | 없음 | WarTint (255,245,230) 대비 +0.12 채도 -0.05 + ZoneTint (255,248,236) 채도 +0.08 대비 +0.04 밝기 +0.02 | ★ 크게 |
| LightingStyle / Technology | 스크립트로 못 읽음(파일 속성 RBX_OriginalTechnologyOnFileLoad=1, Unified로 옮긴 표시) | 장소 설정(메인 = Soft, WarService 주석) | 확인 필요: 속성창에서 직접 |

밤(C2c): ClockTime 21, Brightness 1.4, Ambient rgb(102,106,140), OutdoorAmbient rgb(142,150,195), Exposure +0.50, 나머지 낮과 같음.

**한 줄 요약:** WorldKit 원래 빛은 메인 C2c보다 주변광이 어둡고 갈색(0.67배), 하늘 확산이 0.3 (메인 0.5), 블룸·햇살·색보정이 달라서 "그림자·선" 보이는 방식이 다름. 같은 빛에서 비교하려면 `tools/halo_light_sim.luau` (C2c 낮/밤을 WorldKit에 입힘, 원래 값 저장) → 사진 → `tools/halo_light_restore.luau`. 쓰는 방법은 `tools/marble_smooth_capture.py` 참고(UiSandbox에서 썼음).

주의: 사용자가 말한 "그림자가 없어 보임"에서 A(지금)와 B(빛 점검)를 가를 때, 위 ★ 중 Ambient·Diffuse(그늘면이 얼마나 밝은지)·ShadowSoftness(그림자 가장자리)·Bloom/ColorCorrection이 눈에 보이는 차이를 만듦. 빛만 메인으로 맞추면 A와 B가 같아질 수 있음 → B 칸은 "빛을 메인 C2c로 맞춘 뒤 + 추가로 한 가지만"(예: Diffuse 0.5→0.3, ShadowSoftness 0.15→0.1)으로 하는 게 비교가 깨끗함(제안).

## 2. C칸(굽기 SurfaceAppearance) 조언 — 이미지 생성 4와 맞출 것

2D 그림처럼 "칠한 듯한 가장자리 어둠 + 모서리 살짝 밝음"을 색 한 장에 구움. 눈으로 정한 시작값(사진 보고 조정; 숫자는 힌트):
- **색 맵 = (대리석 크림 색 + 아주 옅은 결) × AO × 곡률.** SurfaceAppearance를 쓴 메시는 MaterialVariant(HH_HaloMarbleSmooth_Cream)를 무시하니 바탕 색(237,231,220 근처)을 맵 안에 같이 구워야 함. 금 부분은 따로 파트(HH_HaloGoldTrim) 유지.
- **AO:** 거리 = 소품 키의 약 4~6 % (3 stud짜리면 0.12~0.18 stud), 표본 128, 어두워지는 정도 최대 20~25 %(곱하기 최저 0.78). 그림자 색은 검정 말고 따뜻한 회갈색(곱할 색 (0.80,0.76,0.74)쯤).
- **곡률:** 오목(홈·접히는 곳) -10~12 %, 볼록(모서리) +5~6 % 밝게(따뜻한 흰색). 모서리 폭 = 베벨 한 칸(약 0.03~0.05 stud). 2D의 "선"은 이 볼록 하이라이트 + 오목 어둠의 쌍.
- **선형 색공간에서 곱하고** 마지막에 sRGB로. 1024 이하, 파트마다, 가장자리 여백 8 px 이상.
- **색 한 장만 vs 노멀까지:** **색만 먼저**. 곡률 노멀은 작은 소품에서 반짝임 줄이 지저분해지고(Specular 0.8), 올릴 장수도 2배. 색 한 장으로 2D와 가까워지는지 사진 보고, 모자라면 베벨 노멀(Blender에서 실제 베벨 1칸)만 추가. 거칠기·금속은 상수(거칠기 ~0.6 맵 한 장 재사용 가능: rough 76093268063395, 금속 0 87489921567476 이미 올라가 있음).
- 추측(확인 안 함): MeshPart 꼭짓점 색(vertex color)도 AO를 담을 수 있고 SurfaceAppearance 장수를 줄이지만, MaterialVariant와 같이 곱해지는지는 시험해 봐야 앎. 시험 한 판 가치 있음.
