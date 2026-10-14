# White-model pick sheet: row 1 = 2D 4 views, rows below = each candidate's 7 clay views.
# py wm_sheet.py <render_dir> <out_dir> <2d_prefix> <name> ...
#   renders: <render_dir>/<name>_wm_<id8>__<view>.png ; 2D: <2d_prefix><name>_<view>_ns.png
import glob, os, sys
from PIL import Image, ImageDraw

rd, od, pre = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(od, exist_ok=True)
VIEWS = ['f', 'r45', 's90', 'b', 's270', 'top', 'low', 'up', 'down']
C = 240
for name in sys.argv[4:]:
    labels = sorted({os.path.basename(p).split('__')[0] for p in glob.glob(os.path.join(rd, name + '_wm_*__f.png'))})
    rows = 1 + len(labels)
    o = Image.new('RGB', (C * len(VIEWS), (C + 20) * rows), (30, 30, 30))
    d = ImageDraw.Draw(o)
    for k, v in enumerate(['front', 'left', 'right', 'back']):
        p = pre + name + '_' + v + '_ns.png'
        if os.path.exists(p):
            o.paste(Image.open(p).convert('RGB').resize((C, C)), (k * C, 20))
    d.text((4, 3), name + '  2D: front left right back', fill=(255, 255, 0))
    for r, l in enumerate(labels, 1):
        y = r * (C + 20)
        for k, v in enumerate(VIEWS):
            p = os.path.join(rd, l + '__' + v + '.png')
            if os.path.exists(p):
                o.paste(Image.open(p).convert('RGB').resize((C, C)), (k * C, y + 20))
        d.text((4, y + 3), '%d  %s   %s' % (r, l.split('_wm_')[-1], ' '.join(VIEWS)), fill=(255, 255, 0))
    o.save(os.path.join(od, 'wm_' + name + '.jpg'), quality=90)
    print(name, len(labels))
