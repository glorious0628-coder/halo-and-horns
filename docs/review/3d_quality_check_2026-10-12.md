# 3D 품질 검수 (최종 검수, 2026-10-12 오후)

사용자 요청: "3D 모델링 한 것 중에서 ① 퀄리티 떨어지는 것 ② 2D 입혀서 이상해진 것 ③ 그 외 이상한 것 찾기." 같은 날 결정: A23-148(바깥선 취소, 기준 = 2D 시안), A23-149(모든 3D 골격 먼저).

본 자료(모두 이 저장소): `art/review/img4/tripo_tu_organic_1/2_1012.jpg`, `tripo_tu_goods_1012.jpg`, `tripo_tu_heads_1012.jpg`, `tripo_tu_keepgreen_1_1012.jpg`, `tripo_b2_raw.jpg`(Tripo 원본), `npc_touchup_delight_1012.jpg`, `meme_touchup_1012.jpg`, `weapons_tu_halo/horns/neutral_1012.jpg`, `outline_hull1_fix_c2c_1012.jpg`, `art/review/img3/house_deco/houses_deco_fix1.jpg`. 앞서 전수 검사 `docs/review/3d_recheck_2026-10-11_result.md`(179개 중 178개 다시).

**한 줄 결론:** 망가진 원인은 대부분 Tripo가 아니라 그 뒤 손보기다. Tripo 원본(`tripo_b2_raw.jpg`)은 꽃송이가 또렷한데, Blender에서 면을 1.8~1.9만 → 7~8천으로 줄이고 1024로 다시 굽고 de-light·바깥선을 넣은 판이 뭉개지고 바래고 검은 테두리가 생겼다. 그래서 A23-147(원본 지키기) + A23-148(선 없음) + A23-149(골격 먼저, 세부만 Tripo 조각)로 바꾼다.

## ① 퀄리티가 떨어진 것 (원본·2D보다 나빠짐)

| 무엇 | 보이는 것 | 원인(추정 포함) | 고치는 길 |
|---|---|---|---|
| 꽃 화분·꽃 덤불 14개: PotFlowers_A·C·D·E·F, FlowerPotHQ Daisy·Lavender·Rose·Sunflower·Tulip, Topiary_E, Planter_D, FlowerBush, GatherBush, Hedge | 꽃잎이 초록·노랑 얼룩 덩어리로 뭉개짐(특히 PotFlowers_E: 원본은 노란 꽃 하나하나 보임 → 판은 얼룩). keep-green 판은 잎이 더 어두움 | 면 줄이기 18~19k → 7~8k + 1024 다시 굽기 (관찰: 두 판 비교) | 화분 = 골격(선반 몸통·금 띠), 꽃 = Tripo 덩어리 원본 그대로(A23-149) |
| 무기 28개 | 색이 바래 회색빛(성기사 T2 나무 검 → 거의 흰 회색, 빛 마법사 T1·T2, 레인저 T1·T2 나무 색 빠짐, 빛 마법사 T3 구슬 회색). 대장장이 T2 망치 머리에 2D에 없는 구리 원판 | de-light + 3,500면 (A23-147에 이미 적음) | Tripo 원본 + 최소 손보기, 망가진 곳만 골격 |
| 사람 NPC 6명(Bright·SirGleam·BakerGranny·FlowerGirl·JuiceMan·PotionMerchant) | 갑옷이 유리처럼 비쳐 보임(SirGleam·Bright), 얼굴 흐림(FlowerGirl·JuiceMan 눈·입 번짐), 꽃 화관 뭉개짐, 몸 전체 번들거림 + 검은 테두리 | de-light·바깥선, Tripo 통짜 몸의 한계 | 사람 = 블록 몸 골격 + 옷·Tripo 조각(A23-149), 1명 시험 먼저 |
| 소품 몸통 옆·뒤: BenchB, FruitStall, FlowerCart, VegGarden | 옆·뒤에서 흰 조각이 찢어진 듯 튀어나옴, 천막이 녹은 듯 기울어짐, 화단 벽 찢김 | 앞면 위주 Tripo + 면 줄이기 | 몸통 = 파트 골격, 천막 줄무늬 = 타일, 빵·과일·꽃 = Tripo 조각 |

## ② 2D를 입혀서(또는 2D 흉내로 다시 만들어서) 이상해진 것

| 무엇 | 보이는 것 | 고치는 길 |
|---|---|---|
| 바깥선 껍데기(Hull_* 50개 ID) + Tripo 조각 검은 테두리(바위·등불 머리·NPC·밈) | 2D 시안에 없는 검은 만화 선. 벤치 판자 사이·등불 기둥 모서리에 굵은 검은 줄(`outline_hull1_fix_c2c_1012.jpg` 2열) | **전부 뺌**(A23-148), WorldKit `Parked_Outlines`로 숨김 |
| 집 벽 등불(09·Potion·02·08·12) | 2D 실루엣으로 다시 짠 판이 **납작한 금색 판때기**(입체 없음). Tripo 등불은 멀쩡했음(`houses_deco_fix1.jpg` 오른쪽 칸) | 등불 = 골격(파트 상자·유리·지붕) + Tripo 등불 장식, 납작판 폐기 |
| 밈 DonutHalo | 위에서 보면 도넛 구멍 안쪽이 주황·빨강으로 칠해짐 | Tripo 원본에서 구멍 안쪽 색만 고침 |
| 밈 TwistHorns | 흰 점이 고르지 않은 얼룩, 옆에서 검은 테두리 | 원본 + 선 빼기 |
| 사람 얼굴 2D 데칼(이미 취소, A23-147) | — | 얼굴 방식은 사용자 답 뒤(A23-149) |

## ③ 그 밖에 이상한 것

- **집 골격 + 장식이 2D보다 많이 비어 보임:** 2D의 담쟁이·꽃 상자·화분이 아직 없음(5단계 식물 차례). 09 돔은 갈빗대 없이 매끈한 금 덩어리, Potion 돔은 얼룩덜룩 → 이미지 생성 3 금 돔 새 판(19056fdd) 확인 필요.
- **WallLamp_Head:** 등불 머리는 괜찮음. 다만 검은 테두리가 두껍고, 벽판·팔(파트 키트)이 2D에 없는 큰 판이라 뒤에서 보면 빈 베이지 판.
- **PotionCrate:** 2D의 걸린 간판이 3D에서는 빈 네모 판.
- 다시 본 뒤 괜찮았던 것: Scarecrow 팔(작은 칸에서 없어 보였으나 100%로 보면 있음), 흰 바위 3개(선만 빼면 됨), 물뿌리개·빵 바구니(빵이 조금 흐림).

## 다음 (담당)
1. 이미지 생성 4: WorldKit 바깥선 전부 `Parked_Outlines`로 → 사람 몸 골격 시험 1명(BakerGranny) 시트.
2. Blender 손보기: 사람 얼굴 정리 멈춤 → PotFlowers_E 골격 화분 + Tripo 꽃 원본 시험 1개 → 무기 원본 최소 손보기(선 없음) → 소품.
3. 이미지 개발: 바깥선 묶음 6 취소, ID 기록만 유지.
4. 이미지 생성 3: 집 등불 납작판 폐기, 집 식물·담쟁이 = Tripo 원본 덩어리.
5. 최종 검수: 시험 시트마다 2D | 새 판 판정 → 사용자에게 보여 줌.
