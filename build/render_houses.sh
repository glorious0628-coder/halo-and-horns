#!/bin/bash
# render every house spec: ornaments GLB + Blender preview (이미지 생성 3)
B="C:/Users/glori/Tools/blender-5.2.2-windows-x64/blender.exe"
cd /c/Users/glori/Documents/Roblox/Game
R=C:/Users/glori/Documents/Roblox/Game/art/review/img3/houses
for s in tools/house_specs/*.json; do
  n=$(basename $s .json)
  py tools/skeleton_house.py $s > /dev/null 2>&1
  CL=$(py -c "import json,sys; a=json.load(open(sys.argv[1],encoding='utf-8')).get('awning') or {}; c=a.get('colors',[[250,205,72],[255,243,212]]); print(';'.join(','.join(str(v) for v in x) for x in c[:2]))" $s)
  "$B" --background --factory-startup --python tools/metal_ornaments.py -- build/skel_${n}_ornaments.json art/models/tripo/skeleton_test/${n}_ornaments.glb 2>&1 | grep -E "\[orn\] ok|Error|Traceback" | sed "s/^/$n /"
  "$B" --background --factory-startup --python tools/skeleton_preview.py -- $R/$n --marble cream --cx 0 --ortho 36 --cz 14 --cloth "$CL" --parts build/skel_${n}.json --glb art/models/tripo/skeleton_test/${n}_ornaments.glb --cams build/skel_${n}_cams.json 2>&1 | grep -cE "Saved" | sed "s/^/$n renders /"
done
echo ALLDONE
