import numpy as np, sys
from PIL import Image
src,out=sys.argv[1],sys.argv[2]
im=Image.open(src).convert('RGB')
hsv=np.asarray(im.convert('HSV')).astype(np.float32)
H=hsv[...,0]*360/255; S=hsv[...,1]/255; V=hsv[...,2]/255
def band(h,lo,hi,soft):
    return np.clip((h-(lo-soft))/soft,0,1)*np.clip(((hi+soft)-h)/soft,0,1)
wb=band(H,200,260,20)*np.clip((S-0.07)/0.12,0,1)*np.clip((V-0.08)/0.1,0,1)
Hr=np.where(H>180,H-360,H)
wr=band(Hr,-25,15,12)*np.clip((S-0.55)/0.15,0,1)*np.clip((V-0.25)/0.15,0,1)
def circ(h,target,w): return (h+((target-h+540)%360-180)*w)%360
Hn=circ(H,340.0,wb); Hn=circ(Hn,338.0,wr)
Sn=S*(1-wb)+np.clip(S*0.55,0,1)*wb
Vn=V*(1-wb)+np.clip(0.62+0.38*V,0,1)*wb
Sn=Sn*(1-wr)+np.clip(S*0.85,0,1)*wr
Vn=Vn*(1-wr)+np.clip(V*0.74,0,1)*wr
o=np.stack([Hn*255/360,Sn*255,Vn*255],-1).clip(0,255).astype(np.uint8)
Image.fromarray(o,'HSV').convert('RGB').save(out,quality=94)
print('ok',out,'blue px %.1f%% red px %.1f%%'%(100*(wb>0.5).mean(),100*(wr>0.5).mean()))
