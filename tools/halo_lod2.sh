#!/bin/bash
# usage: halo_lod2.sh Name target_tris   -> art/models/tripo/web/Halo_<Name>_HD_LOD.glb (weld + decimate + --rotz -90) + render sheet vs the 2D
B="C:/Users/glori/Tools/blender-5.2.2-windows-x64/blender.exe"
cd /c/Users/glori/Documents/Roblox/Game
n=$1; t=$2
"$B" --background --factory-startup --python-exit-code 1 --python tools/glb_decimate.py -- art/models/tripo/web/Halo_${n}_HD_src.glb art/models/tripo/web/Halo_${n}_HD_LOD.glb $t --weld 1e-5 --rotz -90 2>&1 | grep -E "decimate\] (in|ratio)|Error"
"$B" --background --factory-startup --python tools/tex_compare_render.py -- art/models/tripo/web/Halo_${n}_HD_LOD.glb art/review/world/halo_new $n --views front34,back34,game --front -y 2>&1 | grep -c "tex_compare_render\] ok"
py tools/halo_compare_sheet.py $n $n
