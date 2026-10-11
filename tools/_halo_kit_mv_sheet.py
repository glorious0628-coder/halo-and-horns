"""4-view sheets (front HQ | back | left | right) for kits in art/out/s2/halo/kits_mv -> art/review/s2/halo_kits_mv_<n>.jpg"""
from PIL import Image, ImageDraw
import sys
R = 'art/out/s2/halo/kits_mv/HaloKit_'
KS = sys.argv[1:] or ['FlowerBush', 'GatherBush', 'WallLamp', 'Beehive', 'Telescope', 'Easel', 'BellFrame']
W = 448
def sheet(ks, name):
    S = Image.new('RGB', (W * 4, W * len(ks)), (110, 110, 110))
    for r, k in enumerate(ks):
        for c, v in enumerate(['front_HQ_src', 'back', 'left', 'right']):
            im = Image.open(f'{R}{k}_{v}.png').convert('RGB').resize((W, W), Image.LANCZOS)
            ImageDraw.Draw(im).text((6, 4), f'{k} {v.split("_")[0]}', fill=(255, 255, 255))
            S.paste(im, (c * W, r * W))
    S.save(f'art/review/s2/{name}', quality=88)
for i in range(0, len(KS), 4):
    sheet(KS[i:i + 4], f'halo_kits_mv_{i // 4 + 1}.jpg')
