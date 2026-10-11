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
