"""Side-by-side sheet: 2D concept views (front/left/back) | Blender renders (front34, back34, game). 이미지 생성 1, 2026-10-09.
  py tools/halo_compare_sheet.py <ConceptName> <RenderLabel>   e.g. Gate Gate
Reads art/out/s2/halo/HaloProp_<ConceptName>_{front,left,back}_HQ_src.png and art/review/world/halo_new/<RenderLabel>_{front34,back34,game}.png
Writes art/review/world/halo_new/<RenderLabel>_compare.jpg"""
import sys
from PIL import Image
c, lab = sys.argv[1], sys.argv[2]
R = 'art/review/world/halo_new/'
srcs = [f'art/out/s2/halo/HaloProp_{c}_{v}_HQ_src.png' for v in ('front', 'left', 'back')] + [f'{R}{lab}_{v}.png' for v in ('front34', 'back34', 'game')]
T = 480
sh = Image.new('RGB', (T * 3, T * 2), (110, 110, 110))
for i, p in enumerate(srcs):
    im = Image.open(p)
    if im.mode == 'RGBA':
        bg = Image.new('RGB', im.size, (90, 90, 90)); bg.paste(im, mask=im.split()[3]); im = bg
    im = im.convert('RGB'); im.thumbnail((T, T))
    sh.paste(im, ((i % 3) * T + (T - im.width) // 2, (i // 3) * T + (T - im.height) // 2))
sh.save(f'{R}{lab}_compare.jpg', quality=86)
print('ok')
