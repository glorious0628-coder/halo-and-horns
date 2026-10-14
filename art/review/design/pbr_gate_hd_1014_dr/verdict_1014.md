# Tripo HD PBR 첫 판정 — 33개 (디자인 검수, 2026-10-14)
방법: 원래 통짜 2D | 부품 2D | PBR 앞 (`_orig_part2d_pbr_33.jpg`), 비침 14면(build/dr_seethru_1014), 그릇류는 2D와 같은 카메라 높이(윗면 타원 비율로 맞춤, Blender workbench)에서 높이/폭 비교.

| 이름 | 판정 | 이유 |
|---|---|---|
| HaloFlowerPotHQ_Daisy_Pot | 떨어짐 | 옆(s90) 패널 틀 왼쪽 아래에 비침 틈(`Daisy_Pot__hole_s90_zoom.png`) + 기둥 5개 비대칭(2D부터, 이미지 생성 2 다시 그림) |
| HaloFlowerPotHQ_Rose_Bowl | 떨어짐 | 2D 다시 그림 대상(너무 깊음·아래 뜯김) |
| HaloVar4_PotFlowers_A_Bowl | 떨어짐 | 아래 옆 회색 뜯김 무늬가 4면 눈높이에서 보임(구멍은 아님, 2D 가장자리 조각에서 옴) |
| Town_Halo_Fountain3_Top | 떨어짐 | 꼭지 공이 원래보다 ≈1.4배(2D부터) |
| 나머지 29 | 통과 | 비침 0~몇 px 잡음, 조각 1개, 모양·비율 맞음(그릇류 같은 각도 차 -3~+7%) |

⑤ Roblox 재질 메모: SilverBucket 금속이 하늘을 비춰 옅게 보임(구멍·투명 아님, OPAQUE) · RoseBud 진분홍(2D 연분홍) · TreeFruit 밝은 노랑(원래 주황빛) · G_Canopy 연두(원래 짙은 초록) · 금색 전반 평평한 노랑 → 금속감. Basin 바닥 = 막힘, 바닥 면에 물 색(안 보임). ArmoryBarrel 뚜껑 = 네모 판 무늬(2D에 윗면 없음, 그대로 둠). G_Trunk 위 두 갈래 없음 = 덮개 안이라 안 보임.
