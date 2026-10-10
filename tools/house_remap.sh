#!/bin/bash
# usage: tools/house_remap.sh <Name> <folder: halo_houses|halo_props> <front_2d>  — maps + GLB + sheet again, keeps the parts (pass A)
set -eo pipefail
B="C:/Users/glori/Tools/blender-5.2.2-windows-x64/blender.exe"
cd /c/Users/glori/Documents/Roblox/Game
n=$1; W=art/models/tripo/$2/$n; f=$3
py tools/house_maps.py $W | grep -v "^\[pbr" || true
"$B" --background --factory-startup --python-exit-code 1 --python tools/house_parts.py -- --assemble $W/${n}_A.blend $W/${n}_parts.glb 2>&1 | grep -E "\[parts\]|Error|Traceback"
PPS=32; [ "$2" = "halo_props" ] && PPS=96
timeout 600 "$B" --background --factory-startup --python tools/house_sheet_render.py -- $W/${n}_parts.glb $W/sheet --ppstud $PPS 2>&1 | grep -E "sheet_render\]|Error"
py tools/house_sheet.py $n "$f" $W art/review/img3/${n}_check.jpg
