#!/bin/bash
# usage: npc_lod.sh <Name> <target_tris> <front_suffix>  (이미지 생성 1, 2026-10-10: Halo town NPC decor models)
# art/models/tripo/web/NPC_Halo<Name>_HD_src.glb -> _HD_LOD.glb (weld + decimate + --rotz -90), renders, sheet vs art/out/s2/npc 2D
B="C:/Users/glori/Tools/blender-5.2.2-windows-x64/blender.exe"
cd /c/Users/glori/Documents/Roblox/Game
n=$1; t=$2; f=${3:-A}
W=art/models/tripo/web; R=art/review/world/halo_new/npc
mkdir -p $R
"$B" --background --factory-startup --python-exit-code 1 --python tools/glb_decimate.py -- $W/NPC_Halo${n}_HD_src.glb $W/NPC_Halo${n}_HD_LOD.glb $t --weld 1e-5 --rotz -90 2>&1 | grep -E "decimate\] (in|ratio)|Error"
"$B" --background --factory-startup --python tools/tex_compare_render.py -- $W/NPC_Halo${n}_HD_LOD.glb $R NPC_$n --views front34,back34,game --front -y 2>&1 | grep -c "tex_compare_render\] ok"
py - "$n" "$f" <<'P'
import sys
from PIL import Image
n, f = sys.argv[1], sys.argv[2]
S = 'art/out/s2/npc/NPC_Halo%s_' % n
R = 'art/review/world/halo_new/npc/NPC_%s_' % n
srcs = [S + f + '_src.png', S + 'left_HQ_src.png', S + 'back_HQ_src.png', R + 'front34.png', R + 'back34.png', R + 'game.png']
T = 480
sh = Image.new('RGB', (T * 3, T * 2), (110, 110, 110))
for i, p in enumerate(srcs):
    im = Image.open(p)
    if im.mode == 'RGBA':
        bg = Image.new('RGB', im.size, (90, 90, 90)); bg.paste(im, mask=im.split()[3]); im = bg
    im = im.convert('RGB'); im.thumbnail((T, T))
    sh.paste(im, ((i % 3) * T + (T - im.width) // 2, (i // 3) * T + (T - im.height) // 2))
sh.save(R + 'compare.jpg', quality=86)
print('sheet', R + 'compare.jpg')
P
