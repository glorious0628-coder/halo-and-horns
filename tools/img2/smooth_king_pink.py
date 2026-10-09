import numpy as np, sys, time
from PIL import Image
from scipy import ndimage as ndi
t0=time.time()
srcC,srcN,outC,outN,srcP=sys.argv[1:6]
im=Image.open(srcC).convert('RGB')
hsv=np.asarray(im.convert('HSV')).astype(np.float32)
H=hsv[...,0]*360/255; S=hsv[...,1]/255; V=hsv[...,2]/255
def band(h,lo,hi,soft): return np.clip((h-(lo-soft))/soft,0,1)*np.clip(((hi+soft)-h)/soft,0,1)
# original BLUE body weight (from original color map)
wb=band(H,200,260,20)*np.clip((S-0.07)/0.12,0,1)*np.clip((V-0.08)/0.1,0,1)
core=wb>0.5
# fill small enclosed speckles (bubbles/highlights) that are not dark and have a mostly-body ring
non=~core
lab,n=ndi.label(non)
sizes=ndi.sum(np.ones_like(lab),lab,range(1,n+1))
objs=ndi.find_objects(lab)
fill=np.zeros_like(core)
dark=(V<0.25)
dark_near=ndi.binary_dilation(dark,iterations=45)
for i,sl in enumerate(objs,1):
    if sizes[i-1]>60000 or sizes[i-1]<1: continue
    y0,y1=max(sl[0].start-6,0),min(sl[0].stop+6,lab.shape[0]); x0,x1=max(sl[1].start-6,0),min(sl[1].stop+6,lab.shape[1])
    m=lab[y0:y1,x0:x1]==i
    ring=ndi.binary_dilation(m,iterations=5)&~m
    if ring.sum()==0: continue
    if core[y0:y1,x0:x1][ring].mean()>0.85 and not dark_near[y0:y1,x0:x1][m].any():
        fill[y0:y1,x0:x1]|=m
body=core|fill
body=ndi.binary_dilation(body,iterations=2)&(wb>0.02)|fill|core
near_dark=ndi.binary_dilation(dark,iterations=8)
body&=~(near_dark&(wb<0.6))
print('body %.1f%% fill %.2f%%'%(100*body.mean(),100*fill.mean()),time.time()-t0)
P=np.asarray(Image.open(srcP).convert('RGB').convert('HSV')).astype(np.float32)
H=P[...,0]*360/255; S=P[...,1]/255; V=P[...,2]/255
# smooth body: masked gaussian of V with large sigma, constant hue/sat
bf=body.astype(np.float32)
def mg(x,s):
    num=ndi.gaussian_filter(x*bf,s); den=ndi.gaussian_filter(bf,s); return num/np.maximum(den,1e-4)
Vs=mg(np.where(body,V,0).astype(np.float32),28)
Vs=np.clip(0.90+ (Vs-np.median(Vs[body]))*0.9,0,1)   # soft variation around a bright pink
Hb,Sb=340.0,0.60
# soft edge weight so UV-island borders blend
w=ndi.gaussian_filter(bf,0.8)
Hn=H*(1-w)+Hb*w; Sn=S*(1-w)+Sb*w; Vn=V*(1-w)+Vs*w
# hue circular blend fix: just overwrite where w>0.5
Hn=np.where(w>0.5,Hb,Hn)
o=np.stack([Hn*255/360,Sn*255,Vn*255],-1).clip(0,255).astype(np.uint8)
Image.fromarray(o,'HSV').convert('RGB').save(outC,quality=94)
print('color done',time.time()-t0)
# normal map: flatten body region by 75%
nm=np.asarray(Image.open(srcN).convert('RGB')).astype(np.float32)
flat=np.array([128,128,255],np.float32)
wn=ndi.gaussian_filter(bf,3)[...,None]*0.75
nn=nm*(1-wn)+flat*wn
Image.fromarray(nn.clip(0,255).astype(np.uint8)).save(outN)
Image.fromarray((w*255).astype(np.uint8)).resize((1024,1024)).save(outC.replace('.jpg','_mask.png'))
print('normal done',time.time()-t0)
