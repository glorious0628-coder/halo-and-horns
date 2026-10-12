#!/bin/bash
# Blender touch-up of the Halo-town NPC Tripo models (이미지 생성 4, 10/12; 디자인 검수: halo = exact ring at the same
# height, symmetric armour, specks / holes checked, ~8,000 tris, C/N/R/M, thin outline). usage: tools/tripo_touchup_npc.sh [job ...]
# 10/10 models (4-view HD, 이미지 생성 1) = <job>_HD_src.glb; PotionMerchant (10/12) = _MV4_HD_src.glb. Height 5.2 studs (= H).
# Symmetry only below the asymmetric bits: Bright's braid ends ~0.45 H, SirGleam's sword scabbard ~0.21 H.
B="C:/Users/glori/Tools/blender-5.2.2-windows-x64/blender.exe"
cd "$(dirname "$0")/.."
JOBS=(
  "NPC_HaloBright --kind whole --fit h=5.2 --tris 8000 --uv-head 0.62:2.2 --src-suffix _HD_src --halo --halo-r 0.38 --halo-t 0.05 --sym-below 0.42"
  "NPC_HaloSirGleam --kind whole --fit h=5.2 --tris 8000 --uv-head 0.62:2.2 --src-suffix _HD_src --halo --halo-r 0.38 --halo-t 0.05 --sym-below 0.18"
  "NPC_HaloBakerGranny --kind whole --fit h=5.2 --tris 8000 --uv-head 0.62:2.2 --src-suffix _HD_src --halo --halo-r 0.38 --halo-t 0.05"
  "NPC_HaloFlowerGirl --kind whole --fit h=5.2 --tris 8000 --uv-head 0.62:2.2 --src-suffix _HD_src --halo --halo-r 0.38 --halo-t 0.05"
  "NPC_HaloJuiceMan --kind whole --fit h=5.2 --tris 8000 --uv-head 0.62:2.2 --src-suffix _HD_src --halo --halo-r 0.38 --halo-t 0.05"
  "NPC_HaloPotionMerchant --kind whole --fit h=5.2 --tris 8000 --uv-head 0.62:2.2"
)
for j in "${JOBS[@]}"; do
  set -- $j
  if [ -n "$ONLY" ] && [[ " $ONLY " != *" $1 "* ]]; then continue; fi
  "$B" --background --factory-startup --python tools/tripo_touchup.py -- $j --preview 2>&1 | grep -E "\[touchup\] done|Error|Traceback"
done
