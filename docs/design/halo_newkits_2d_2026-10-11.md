# 빛 마을 새 소품 키트 18종 — 2D 앞면 Medium 후보 (이미지 생성 2, 2026-10-11)
- 목록 `docs/design/halo_new_prop_kits_2026-10-11.md`(26a27b25). 후보 21장(WhiteRock 3종·Hedge 2종 포함) Medium 0크레딧, 스타일 참조 = `HaloProp_Planter_front_HQ_src.png`(모양은 베끼지 않게 문구). 프롬프트 `art/prompts/HaloKit_<키>_front.txt`, 생성기 `tools/_halo_newkit_prompts.py`, 시트 `tools/_halo_newkit_sheet.py`.
- 원본 `art/out/s2/halo/kits_new/HaloKit_<키>_front.png`, 시트 `art/review/s2/halo_newkits_front_cands.jpg`.
- 내 눈 판정: 21장 모두 조각 깨짐·떠 있는 조각·얼굴 무늬·글자·레이 없음, 벌·동물 없음.
- 주의: **Hedge a/b**는 대리석 화단 받침 위에 울타리가 얹힌 모양(목록은 '꽃 핀 낮은 생울타리', 받침 없음) → 필요하면 받침 없이 다시. **BellFrame**은 나무 틀 대신 대리석 기둥(스타일은 마을과 맞음). 나머지는 목록 설명대로.
- 다음: 검수가 칸을 고르면 같은 칸을 High(5)로 앞면 확정 → 뒤·왼·오른 3장씩(앞면 참조, A23-122) → 이미지 생성 3(Tripo).

## 4면 High 1차: 모양 복잡한 7종 (10/11 밤, 검수 지시)
- 대상: FlowerBush·GatherBush·WallLamp·Beehive·Telescope·Easel·BellFrame. 앞면 Medium을 참조로 High 재생성(`HaloKit_<키>_front_HQ_src.png`) → 그 HQ 앞면을 참조로 뒤·왼·오른 High(`HaloKit_<키>_{back,left,right}.png`), 폴더 `art/out/s2/halo/kits_mv/`. 28장 High = 140크레딧.
- 프롬프트 `art/prompts/HaloKit_<키>_{back,left,right}.txt`, 생성기 `tools/_halo_kit_mv_prompts.py`, 시트 `tools/_halo_kit_mv_sheet.py` → `art/review/s2/halo_kits_mv_{1,2}.jpg`(앞|뒤|왼|오른), 앞면만 `halo_kits_front_HQ.jpg`.
- 내 판정: 6종 통과(형태·색·금 장식 4면 일치, 깨짐·떠 있는 조각·얼굴 무늬·글자·레이 없음). **Beehive는 주의**: 앞면은 박공(문구멍이 있는 삼각 면)인데 옆·뒤는 한쪽으로 기운 외쪽지붕처럼 나옴(지붕 모양 불일치) → Tripo 전에 지붕을 박공으로 맞춰 다시(옆면 2~3장 재생성) 권함.

## 4면 High 2차: Tripo 몫 6종 (10/11 밤, 검수 지시 순서 ① 흰 바위 3종 ② 빵 바구니 ③ 물뿌리개 ④ 생울타리)
- WhiteRock_a/b/c·BreadBasket·WateringCan·Hedge. 앞면 Medium(`kits_new`) → High 앞면(`HaloKit_<키>_front_HQ_src.png`) → 뒤·왼·오른 High. 폴더 `art/out/s2/halo/kits_mv2/`, 시트 `art/review/s2/halo_kits2_mv_{1,2}.jpg`, 앞면만 `halo_kits2_front_HQ.jpg`. 24장 High = 120크레딧.
- Hedge는 받침 없이 앞면 Medium 2장(`HaloKit_Hedge_nb_a/b_front.png`)을 새로 뽑아 긴 블록형 a 채택(b는 둥근 덤불이라 제외, 길이 2종은 배율로). 프롬프트 `art/prompts/HaloKit_Hedge_nb_*_front.txt`는 생성기에 없음(브라우저에서 직접, 위 설명 참고).
- 내 판정: 6종 4면 모양·색·이끼·금 장식 일치, 깨짐·떠 있는 조각·얼굴 무늬·글자·레이 없음 → 통과. **주의**: WateringCan 오른쪽(주둥이가 카메라 반대쪽) 면은 샤워기 머리가 뚜껑 위에 뜬 원통처럼 읽혀 약함 → Tripo에는 앞·뒤·왼쪽 3면 우선, 필요하면 오른쪽만 다시.
- 파트 몫(카페 탁자·초 상자·무기고 통·알림판·디딤돌·물통)은 앞면 Medium 1장(`kits_new`)만 참고용으로 유지. Cauldron은 검수 말대로 CSG가 안 될 때만.

## 4면 High 3차: 화분·화단·난간 덤불 + 종 + 벽등 머리 (10/11 밤, 최종 검수/디자인 검수 순서 ②→①→③)
- 폴더 `art/out/s2/halo/kits_mv3/`, 시트 `art/review/s2/halo_kits3_mv_{1,2,3}.jpg`(앞|뒤|왼|오른), 후보 `halo_kits3_med.jpg`, 벽등 머리 `halo_walllamp_head_4views.jpg`, 물뿌리개 오른쪽 수정 `halo_wateringcan_right_fix.jpg`(앞|전|후).
- ② 종만 따로: Medium 후보 3(m1~m3) 중 m3(넓게 퍼진 고전 종, 추 보임) 채택 → High 앞면(`HaloKit_BellOnly_front_HQ_src.png`) + 뒤·왼·오른 High. 4면 높이·모양·추·고리 일치.
- ① 뒤·왼·오른 High 27장: PotFlowers A·C·D·E·F, Planter A·D·E, Balustrade_F(위 덤불). 앞면은 기존 HQ(`variants/`,`variants4/`). 모두 앞면과 모양·색·꽃 자리 일치, 깨짐·떠 있는 조각·얼굴 무늬·글자·레이 없음(내 눈).
- ③ 벽등: 받침 앞·뒤 Medium(`HaloKit_WallLampBase_{front,back}_m.png`, Studio 참고, 뒤는 앞과 거의 같은 면이라 약함) + 머리(랜턴+고리)만 기존 High 4면에서 잘라 회색 1024에 가운데 놓은 4장(`HaloKit_WallLampHead_*.png`, 0크레딧).
- 물뿌리개 오른쪽(디자인 검수 지시) High 다시: 손잡이가 앞, 리본은 손잡이 꼭대기, 주둥이는 몸통 뒤에 가려 끝만 보임 → 앞면 높이와 맞음(`kits_mv3/HaloKit_WateringCan_right_v2.png`, kits_mv2의 옛 right 대신 이것 사용).
- 크레딧: 종 앞 5 + 종 3면 15 + 물뿌리개 5 + 27장 135 = 160. 오늘 밤 합계 약 575(무기 28+소품 4면 7종 140+6종 120+이번 160+사고 15), 표시 잔액 약 4,190.
