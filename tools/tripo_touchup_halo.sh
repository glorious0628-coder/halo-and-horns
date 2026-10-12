#!/bin/bash
# Run tools/tripo_touchup.py over the Halo-town Tripo 4-view jobs (이미지 생성 4, 10/12). usage: tools/tripo_touchup_halo.sh [job ...]
B="C:/Users/glori/Tools/blender-5.2.2-windows-x64/blender.exe"
cd "$(dirname "$0")/.."
K=build/prop_kit
JOBS=(
  "HaloFlowerPotHQ_Daisy --delight 0.75 --kind plant --keep-green --drop-low 0.1 --fit h=3.5 --tris 8000 --tol 0.25 --body $K/HaloFlowerPotHQ_Daisy__Body.json"
  "HaloFlowerPotHQ_Lavender --delight 0.75 --kind plant --keep-green --drop-low 0.1 --fit h=3.5 --tris 8000 --body $K/HaloFlowerPotHQ_Lavender__Body.json"
  "HaloFlowerPotHQ_Rose --delight 0.75 --kind plant --keep-green --drop-low 0.1 --fit h=3.5 --tris 8000 --body $K/HaloFlowerPotHQ_Rose__Body.json"
  "HaloFlowerPotHQ_Sunflower --delight 0.75 --kind plant --keep-green --drop-low 0.1 --fit h=3.5 --tris 8000 --body $K/HaloFlowerPotHQ_Sunflower__Body.json"
  "HaloFlowerPotHQ_Tulip --delight 0.75 --kind plant --keep-green --drop-low 0.1 --fit h=3.5 --tris 8000 --body $K/HaloFlowerPotHQ_Tulip__Body.json"
  "HaloVar4_PotFlowers_A --delight 0.75 --kind plant --keep-green --drop-low 0.1 --fit h=3 --tris 7000 --body $K/HaloVar4_PotFlowers_A__Body.json"
  "HaloVar4_PotFlowers_C --delight 0.75 --kind plant --keep-green --drop-low 0.1 --fit h=3 --tris 7000 --body $K/HaloVar4_PotFlowers_C__Body.json"
  "HaloVar4_PotFlowers_D --delight 0.75 --kind plant --keep-green --drop-low 0.1 --fit h=3 --tris 7000 --rim-frac 0.626 --below-all --tolz 0.1 --body $K/HaloVar4_PotFlowers_D__Body.json"
  "HaloVar3_PotFlowers_E --delight 0.75 --kind plant --keep-green --drop-low 0.1 --fit h=3 --tris 7000 --body $K/HaloVar3_PotFlowers_E__Body.json"
  "HaloVar3_PotFlowers_F --delight 0.75 --kind plant --keep-green --drop-low 0.1 --fit h=3 --tris 7000 --body $K/HaloVar3_PotFlowers_F__Body.json"
  "HaloVar3_Topiary_C --delight 0.75 --kind plant --keep-green --drop-low 0.1 --fit h=8 --tris 8000 --body $K/HaloVar3_Topiary_C__Body.json"
  "HaloVar3_Topiary_D --delight 0.75 --kind plant --keep-green --drop-low 0.1 --fit h=8 --tris 8000 --body $K/HaloVar3_Topiary_D__Body.json"
  "HaloVar3_Topiary_E --delight 0.75 --kind plant --keep-green --drop-low 0.1 --fit h=8 --tris 8000 --rim-frac 0.663 --below-all --tolz 0.1 --body $K/HaloVar3_Topiary_E__Body.json"
  "HaloVar3_RoundTree_E --delight 0.75 --kind plant --keep-green --drop-low 0.1 --fit h=10 --tris 10000 --body $K/HaloVar3_RoundTree_E__Body.json"
  "HaloVar3_RoundTree_F --delight 0.75 --kind plant --keep-green --drop-low 0.1 --fit h=10 --tris 10000 --body $K/HaloVar3_RoundTree_F__Body.json"
  "HaloVar3_RoundTree_G --delight 0.75 --kind plant --keep-green --drop-low 0.1 --fit h=10 --tris 10000 --body $K/HaloVar3_RoundTree_G__Body.json"
  "HaloVar4_Planter_D --delight 0.75 --kind plant --keep-green --drop-low 0.1 --fit h=5.8 --tris 8000 --body $K/HaloVar4_Planter_D__Body.json"
  "HaloReasonHQ_BenchB --delight 0.75 --kind goods --fit w=6.5 --tris 8000 --body $K/HaloReasonHQ_BenchB__Body.json"
  "HaloReasonHQ_VegGarden --delight 0.75 --kind goods --fit w=8 --tris 10000 --body $K/HaloReasonHQ_VegGarden__Body.json"
  "HaloReasonHQ_BreadStand --delight 0.75 --kind goods --fit w=7 --tris 10000 --body $K/HaloReasonHQ_BreadStand__Body.json"
  "HaloReasonHQ_FruitStall --delight 0.75 --kind goods --fit h=9 --tris 10000 --body $K/HaloReasonHQ_FruitStall__Body.json"
  "HaloReasonHQ_FlowerCart --delight 0.75 --kind goods --fit w=7 --tris 10000 --body $K/HaloReasonHQ_FlowerCart__Body.json"
  "HaloReasonHQ_PotionCrate --delight 0.75 --kind goods --fit w=5 --tris 8000 --body $K/HaloReasonHQ_PotionCrate__Body.json"
  "HaloVar4_Lantern_A --delight 0.75 --kind head --fit h=7 --head-from 0.68 --tris 5000 --body $K/HaloVar4_Lantern_A.json"
  "HaloVar4_Lantern_B --delight 0.75 --kind head --part Globe,Core,Equator,Meridian,TopCap,TopBall --fit h=7 --tris 5000 --body $K/HaloVar4_Lantern_B.json"
  "HaloVar4_Lantern_C --delight 0.75 --kind head --head-footprint --fit h=7 --tris 5000 --body $K/HaloVar4_Lantern_C.json"
  "HaloVar4_Lantern_D --delight 0.75 --kind head --head-footprint --fit h=7 --tris 5000 --body $K/HaloVar4_Lantern_D.json"
  "HaloVar3_Lantern_E --delight 0.75 --kind head --fit h=7 --tris 5000 --body $K/HaloVar3_Lantern_E.json"
  "NEW_WallLamp_Head --delight 0.75 --kind part --part Head --tris 4000 --body $K/NEW_WallLamp.json"
  "NEW_BellFrame_Bell --delight 0.75 --kind part --part Bell,Rope --tris 5000 --body $K/NEW_BellFrame.json"
  "NEW_Hedge --delight 0.75 --kind ontop --fit w=0.82 --tris 8000 --body $K/NEW_Hedge__Body.json"
  "HaloReasonHQ_Scarecrow --delight 0.75 --kind whole --fit h=6.5 --tris 6000"
  "NEW_FlowerBush --delight 0.75 --kind whole --organic --fit h=3 --tris 8000"
  "NEW_GatherBush --delight 0.75 --kind whole --organic --fit h=3 --tris 8000"
  "NEW_WhiteRock_a --delight 0.75 --kind whole --fit h=2.5 --tris 5000"
  "NEW_WhiteRock_b --delight 0.75 --kind whole --fit h=2.5 --tris 5000"
  "NEW_WhiteRock_c --delight 0.75 --kind whole --fit h=2.5 --tris 5000"
  "NEW_BreadBasket --delight 0.75 --kind whole --fit h=1.6 --tris 5000"
  "NEW_WateringCan --delight 0.75 --kind whole --fit h=1.2 --tris 4000"
)
for spec in "${JOBS[@]}"; do
  job=${spec%% *}
  if [ $# -gt 0 ] && ! printf '%s\n' "$@" | grep -qx "$job"; then continue; fi
  "$B" --background --factory-startup --python tools/tripo_touchup.py -- $spec --preview 2>&1 | grep -E "^\[touchup\] (done|cut)|Error|Traceback" | cut -c1-260
done
echo ALLDONE
