#!/bin/bash
# usage: tools/house_build.sh <Name> [front_2d.png]   (이미지 생성 3, 2026-10-10)
# Tripo HD src (art/models/tripo/web/<Name>_HD_src.glb) -> parts + 4 maps each -> art/models/tripo/halo_houses/<Name>/<Name>_parts.glb
# -> check sheet art/review/img3/<Name>_check.jpg. One Blender at a time (shared PC).
set -eo pipefail
B="C:/Users/glori/Tools/blender-5.2.2-windows-x64/blender.exe"
cd /c/Users/glori/Documents/Roblox/Game
n=$1
f=${2:-$(py -c "import json;print(json.load(open('art/models/tripo/web/halo_house_regions.json',encoding='utf-8'))['$n'].get('front2d',''))")}
W=art/models/tripo/halo_houses/$n
rm -rf $W
"$B" --background --factory-startup --python-exit-code 1 --python tools/house_parts.py -- art/models/tripo/web/${n}_HD_src.glb $n art/models/tripo/web/halo_house_regions.json art/models/tripo/halo_houses 2>&1 | grep -E "\[parts\] (faces|scale|ok)|Error|Traceback" | cut -c1-260
py tools/house_maps.py $W | grep -v "^\[pbr" || true
"$B" --background --factory-startup --python-exit-code 1 --python tools/house_parts.py -- --assemble $W/${n}_A.blend $W/${n}_parts.glb 2>&1 | grep -E "\[parts\]|Error|Traceback"
timeout 600 "$B" --background --factory-startup --python tools/house_sheet_render.py -- $W/${n}_parts.glb $W/sheet 2>&1 | grep -E "sheet_render\]|Error"
mkdir -p art/review/img3
py tools/house_sheet.py $n "$f" $W art/review/img3/${n}_check.jpg
