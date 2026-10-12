import sys,os,glob
from PIL import Image, ImageDraw
S,d,prefix=sys.argv[1],sys.argv[2],sys.argv[3]
kinds=sys.argv[4:]
views=['f','r45','s90','b','s270','top','low']
for kind in kinds:
  ls=sorted({os.path.basename(p).split('__')[0] for p in glob.glob(f'{S}/{d}/{kind}_*.png')})
  c=280
  o=Image.new('RGB',(c*len(views),(c+18)*len(ls)),(30,30,30)); dr=ImageDraw.Draw(o)
  for r,l in enumerate(ls):
    for k,v in enumerate(views):
      o.paste(Image.open(f'{S}/{d}/{l}__{v}.png').convert('RGB').resize((c,c)),(k*c,r*(c+18)+18))
    dr.text((4,r*(c+18)+3),l+'  '+' '.join(views),fill=(255,255,0))
  o.save(f'{S}/{prefix}_{kind}.jpg',quality=92)
