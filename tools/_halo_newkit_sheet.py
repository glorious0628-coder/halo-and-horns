"""Contact sheet of art/out/s2/halo/kits_new/*.png -> art/review/s2/halo_newkits_front_cands.jpg"""
from PIL import Image, ImageDraw
import glob, math
fs = sorted(glob.glob('art/out/s2/halo/kits_new/*.png'))
W, cols = 384, 4
rows = math.ceil(len(fs) / cols)
S = Image.new('RGB', (W * cols, W * rows), (110, 110, 110))
for i, f in enumerate(fs):
    im = Image.open(f).convert('RGB').resize((W, W), Image.LANCZOS)
    ImageDraw.Draw(im).text((6, 4), f.split('HaloKit_')[1][:-10], fill=(255, 255, 255))
    S.paste(im, ((i % cols) * W, (i // cols) * W))
S.save('art/review/s2/halo_newkits_front_cands.jpg', quality=86)
print(len(fs), S.size)
