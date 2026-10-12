# 빛 마을 낮 OutdoorAmbient (그늘 쪽 빛) — 계산 근거 (이미지 생성 3, 2026-10-13)

최종 검수 판정 10/12 밤: **위도 35 그대로 + 낮 OutdoorAmbient 따뜻하게 188,185,183** (그늘 벽이 푸른 회색 → 크림, 해 받는 면 최대 215로 날아가지 않음).

| | 값 | 어디서 |
|---|---|---|
| 지금 기본(낮) | OutdoorAmbient 95,104,118 | `Config.luau` Sky.Neutral (모든 구역이 같이 씀) |
| 빛 마을 존 배율 | Amb {1.45, 1.36, 1.32} (Ambient·OutdoorAmbient 둘 다) | `ZoneLook.luau` HaloTown |
| 지금 결과 | 95,104,118 × 배율 = **138,141,156** | |
| 새 결과(통과) | **188,185,183** = 지금 결과 × 1.36 × 크림 색조 (1.00, 0.96, 0.86) | `tools/ambient_test.py`, Cliff6 그늘 벽 중앙값 ≈ 190이 되게 맞춤 |
| 기본값으로 바꿀 때 | 188/1.45, 185/1.36, 183/1.32 ≈ **130,136,139** | 계산값 |
| 빛 마을 OA만 바꿀 때 | OutdoorAmbient 배율 **{1.979, 1.779, 1.551}** (Ambient 배율은 그대로) | WorldKit 판정 빛 `tools/halo_light_sim.luau` C2c `OutAmbDay`가 이 방식 |

- 주의: Sky.Neutral은 모든 구역 공용이라 130,136,139로 바꾸면 다른 구역 그늘도 같이 밝아짐. 빛 마을만이면 ZoneLook HaloTown에 낮 OutdoorAmbient 배율을 따로 두는 방식(위 마지막 줄)이 맞음 — 6단계(빛 마을 메인 교체) 때 코드 세션이 고름.
- 밤 값은 안 바꿈(10/12 밤 결정 그대로). 위도 35, 시각 15.3 그대로.
- 시트: `art/review/img3/houses/ambient_test/ambient_test.jpg` (위도 35/65 × OA 지금/따뜻, 성·빵집·주스·Cliff6, 숫자 `result.json`), 앞 시험 `art/review/img3/houses/latitude_test/latitude_test.jpg` (남반구 버림).
- 벽 밝기 중앙값(0~255) 위도 35: 성 160 → 188, 빵집 182 → 201, 주스 200 → 215, Cliff6 164 → 190.
