#!/bin/bash
# usage: tools/prop_build.sh <Name> <front_2d.png> <fit: h=<studs>|w=<studs>> <decimate tris> [lamp] [grid]   (이미지 생성 3, 2026-10-10)
# Tripo HD single-image prop -> parts (Body tiles, glass panes, lamp glow) + 4 maps each -> art/models/tripo/halo_props/<Name>/<Name>_parts.glb
# -> check sheet art/review/img3/<Name>_check.jpg. One Blender at a time (shared PC).
set -eo pipefail
B="C:/Users/glori/Tools/blender-5.2.2-windows-x64/blender.exe"
cd /c/Users/glori/Documents/Roblox/Game
n=$1; f=$2; fit=$3; dec=$4; lamp=${5:-0}; grid=${6:-1}
W=art/models/tripo/halo_props/$n
rm -rf $W
FIT="--fit-${fit%%=*} ${fit#*=}"
L=""; [ "$lamp" = "1" ] && L="--lamp 1"
"$B" --background --factory-startup --python-exit-code 1 --python tools/house_parts.py -- art/models/tripo/web/${n}_HD_src.glb $n art/models/tripo/web/halo_house_regions.json art/models/tripo/halo_props $FIT --decimate $dec --grid $grid $L 2>&1 | grep -E "\[parts\] (faces|scale|ok|decimate)|Error|Traceback" | cut -c1-260
py tools/house_maps.py $W | grep -v "^\[pbr" || true
"$B" --background --factory-startup --python-exit-code 1 --python tools/house_parts.py -- --assemble $W/${n}_A.blend $W/${n}_parts.glb 2>&1 | grep -E "\[parts\]|Error|Traceback"
timeout 600 "$B" --background --factory-startup --python tools/house_sheet_render.py -- $W/${n}_parts.glb $W/sheet --ppstud 96 2>&1 | grep -E "sheet_render\]|Error"
mkdir -p art/review/img3
py tools/house_sheet.py $n "$f" $W art/review/img3/${n}_check.jpg
