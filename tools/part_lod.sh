#!/bin/bash
# usage: part_lod.sh <Part> <target_tris>   (이미지 생성 1, 2026-10-10: building parts, A23-107 부품별 새로 만들기)
# art/models/tripo/web/HaloPart_<Part>_HD_src.glb -> _HD_LOD.glb (weld + decimate + --rotz -90) + renders + sheet vs art/out/s2/halo/parts 2D
B="C:/Users/glori/Tools/blender-5.2.2-windows-x64/blender.exe"
cd /c/Users/glori/Documents/Roblox/Game
n=$1; t=$2
W=art/models/tripo/web; R=art/review/world/halo_new/parts
mkdir -p $R
"$B" --background --factory-startup --python-exit-code 1 --python tools/glb_decimate.py -- $W/HaloPart_${n}_HD_src.glb $W/HaloPart_${n}_HD_LOD.glb $t --weld 1e-5 --rotz -90 2>&1 | grep -E "decimate\] (in|ratio)|Error"
"$B" --background --factory-startup --python tools/tex_compare_render.py -- $W/HaloPart_${n}_HD_LOD.glb $R $n --views front34,back34,game --front -y --sky 2>&1 | grep -c "tex_compare_render\] ok"
py - "$n" <<'P'
import sys, os
from PIL import Image
n = sys.argv[1]
S = 'art/out/s2/halo/parts/HaloPart_%s_' % n
R = 'art/review/world/halo_new/parts/%s_' % n
srcs = [S + v + '_HQ_src.png' for v in ('front', 'left', 'back')] + [R + 'front34.png', R + 'back34.png', R + 'game.png']
T = 480
sh = Image.new('RGB', (T * 3, T * 2), (110, 110, 110))
for i, p in enumerate(srcs):
    if not os.path.exists(p):
        continue
    im = Image.open(p)
    if im.mode == 'RGBA':
        bg = Image.new('RGB', im.size, (90, 90, 90)); bg.paste(im, mask=im.split()[3]); im = bg
    im = im.convert('RGB'); im.thumbnail((T, T))
    sh.paste(im, ((i % 3) * T + (T - im.width) // 2, (i // 3) * T + (T - im.height) // 2))
sh.save(R + 'compare.jpg', quality=86)
print('sheet', R + 'compare.jpg')
P
