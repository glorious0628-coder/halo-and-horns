import numpy as np, sys
from PIL import Image
from scipy import ndimage
src,out=sys.argv[1],sys.argv[2]
im=Image.open(src).convert('RGB')
hsv=np.asarray(im.convert('HSV')).astype(np.float32)
H=hsv[...,0]*360/255; S=hsv[...,1]/255; V=hsv[...,2]/255
def band(h,lo,hi,soft): return np.clip((h-(lo-soft))/soft,0,1)*np.clip(((hi+soft)-h)/soft,0,1)
wb=band(H,200,260,20)*np.clip((S-0.07)/0.12,0,1)*np.clip((V-0.08)/0.1,0,1)
Hr=np.where(H>180,H-360,H)
wr=band(Hr,-25,15,12)*np.clip((S-0.55)/0.15,0,1)*np.clip((V-0.25)/0.15,0,1)
# gem detection: red components whose surroundings are mostly gold
red=wr>0.3
gold=(H>30)&(H<65)&(S>0.45)&(V>0.4)
red_d=ndimage.binary_closing(red,iterations=3)
lab,n=ndimage.label(red_d)
sizes=ndimage.sum(np.ones_like(lab),lab,range(1,n+1))
ring_gold=np.zeros(n+1)
dil=ndimage.maximum_filter  # placeholder
gem=np.zeros(red.shape,bool)
objs=ndimage.find_objects(lab)
for i,sl in enumerate(objs,1):
    if sl is None: continue
    y0,y1=max(sl[0].start-40,0),min(sl[0].stop+40,lab.shape[0]); x0,x1=max(sl[1].start-40,0),min(sl[1].stop+40,lab.shape[1])
    m=lab[y0:y1,x0:x1]==i
    ring=ndimage.binary_dilation(m,iterations=25)&~ndimage.binary_dilation(m,iterations=4)
    g=gold[y0:y1,x0:x1][ring].mean() if ring.any() else 0
    if g>0.30 and sizes[i-1]<250000: gem[sl][m[sl[0].start-y0:sl[0].stop-y0, sl[1].start-x0:sl[1].stop-x0]]=True
gem=ndimage.binary_dilation(gem,iterations=6)
wr_c=wr*(~gem)   # cape-only red
sat=float(sys.argv[3]) if len(sys.argv)>3 else 1.0
def circ(h,t,w): return (h+((t-h+540)%360-180)*w)%360
Hn=circ(H,340.0,wb); Hn=circ(Hn,338.0,wr_c)
Sb=np.clip(S*0.55*1.0+0.0,0,1); Sb=np.clip(Sb*1.22,0,1)   # +22% more saturated pink body
Vb=np.clip(0.66+0.34*V,0,1)
Sn=S*(1-wb)+Sb*wb; Vn=V*(1-wb)+Vb*wb
Sn=Sn*(1-wr_c)+np.clip(S*0.85,0,1)*wr_c; Vn=Vn*(1-wr_c)+np.clip(V*0.74,0,1)*wr_c
o=np.stack([Hn*255/360,Sn*255,Vn*255],-1).clip(0,255).astype(np.uint8)
res=Image.fromarray(o,'HSV').convert('RGB')
res.save(out,quality=94)
Image.fromarray((gem*255).astype(np.uint8)).resize((1024,1024)).save(out.replace('.jpg','_gemmask.png'))
print('gem px %.2f%% comps %d'%(100*gem.mean(),n))
