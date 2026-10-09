import sys
from PIL import Image
# usage: place_sheet.py <prefix> <out.jpg> [part-names] ; whole + 5 parts in a 3x2 grid
pre,out=sys.argv[1],sys.argv[2]
names=['whole','p1_entrance','p2_landmark','p3_plaza','p4_edge','p5_road']
if len(sys.argv)>3: names=['whole']+sys.argv[3].split(',')
C=620
sh=Image.new('RGB',(C*3+20,C*2+10),(255,255,255))
for i,n in enumerate(names):
    im=Image.open(f'art/out/s2/places/{pre}_{n}_src.png').convert('RGB'); im.thumbnail((C,C))
    sh.paste(im,((i%3)*(C+10)+(C-im.width)//2,(i//3)*(C+10)+(C-im.height)//2))
sh.save(out,quality=88)
