"""R2 repeatable image-space measurements. No API, Studio or image generation calls."""
import argparse
import colorsys
import hashlib
import json
from pathlib import Path
import sys
import io

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage
from scipy.stats import theilslopes

ROOT = Path(__file__).resolve().parents[1]
R2 = ROOT / 'art/models/costume/redraw/r2'
SOURCE = ROOT / 'art/out/APose_HaloArcherM_Sharp_D.png'
sys.path.insert(0, str(ROOT / 'tools/costume_r15'))
from glb_io import read_glb, accessor_values, image_bytes


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


def mask(rgb): return np.abs(rgb.astype(np.int16)-255).sum(2)>30


def hsv(rgb):
    a=rgb.astype(float)/255
    maximum=a.max(2); minimum=a.min(2);delta=maximum-minimum
    s=np.divide(delta,maximum,out=np.zeros_like(delta),where=maximum!=0)
    h=np.zeros_like(delta)
    for ch,offset in [(0,0),(1,2),(2,4)]:
        selected=(a.argmax(2)==ch)&(delta>0)
        diff=(a[:,:,(ch+1)%3]-a[:,:,(ch+2)%3])
        h[selected]=(diff[selected]/delta[selected]+offset)*60
    h%=360
    return h,s,maximum


def gold(rgb):
    h,s,v=hsv(rgb); return (h>=25)&(h<=50)&(s>=.5)&(v>=.5)


def runs(values):
    ids=np.flatnonzero(values)
    if not len(ids):return []
    groups=np.split(ids,np.where(np.diff(ids)>1)[0]+1)
    return [(int(g[0]),int(g[-1])+1) for g in groups]


def source_setup():
    im=Image.open(SOURCE).convert('RGB');rgb=np.asarray(im)
    assert im.size==(1254,1254)
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()=='649ce86f007b2762e70bb1fc8d494351520de4f024d1a876c9225b94e6160b0a'
    goldmask=gold(rgb);goldmask[125:]=False
    yy,xx=np.where(goldmask)
    # User-specified anatomical landmarks, marked for independent review.
    regions={'hair':[450,180,560,285],'skin':[568,403,669,450],
             'sleeve':[367,507,426,561],'boot_toe':[470,995,516,1041],
             'leggings':[513,840,550,890],'gold':[462,0,777,120],
             'open_eye':[654,326,744,409],'halo':[450,0,790,125]}
    thickness=[]
    for x in list(range(465,473))+list(range(768,776)):
        rr=runs(goldmask[:,x]);thickness += [max(b-a for a,b in rr)] if rr else []
    tube=float(np.median(thickness))
    data={'source':str(SOURCE.relative_to(ROOT)),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
          'landmarks':{'ahoge_y':71,'sole_y':1203,'body_center_x':620,'chin_seed_y':471},
          'landmark_method':'Anatomical ahoge/sole annotations supplied in R2 brief; source and candidate use the same measurement functions after this common alignment.',
          'regions':regions,'open_eye_search_margin_px':20,
          'halo_geometry_pixels':{'outer_width':314,'tube_diameter':tube,'center_y':76,
                'star_top_y':0,'star_height':98,'star_width':78,'ring_tilt_degrees':0},
          'halo_geometry_method':'Source reference outer ring x462..776, star x581..658/y0..98; tube median longest gold run in columns465..472 and768..775. Ring circular in depth; source supplies no orthographic depth view.',
          'gold_mean_rgb':rgb[goldmask].mean(0).tolist(),
          'gold_mask_definition':{'hue_degrees':[25,50],'saturation_min':.5,'value_min':.5},
          'silhouette_mask':'sum(abs(RGB-255)) > 30'}
    save(R2/'eval/source_regions.json',data)
    overlay=im.copy();d=ImageDraw.Draw(overlay)
    for name,box in regions.items():d.rectangle(box,outline='red',width=3);d.text((box[0],box[1]+3),name,fill='blue')
    for name,xy in [('ahoge',(620,71)),('sole',(620,1203)),('chin seed',(620,471))]:
        x,y=xy;d.line((x-15,y,x+15,y),fill='blue',width=3);d.text((x+17,y),name,fill='blue')
    overlay.save(R2/'eval/regions_on_source.png')
    print(json.dumps({'gold_mean_rgb':data['gold_mean_rgb'],'tube_diameter_px':tube}))


def anatomy(rgb, params):
    silhouette=mask(rgb);h,s,v=hsv(rgb)
    # Stable, disclosed source-space search windows after ahoge/sole alignment.
    skin=(rgb[:,:,0].astype(int)-rgb[:,:,1]>8)&(rgb[:,:,1].astype(int)-rgb[:,:,2]>3)&(h<28)&(s>.06)&(s<.4)&(v>.8)
    # Face-to-collar boundary: at least half the central 60px must remain skin.
    # This excludes the gold brooch below the jaw (the earlier percentile included it).
    y=np.flatnonzero(skin[430:485,590:650].sum(1)>=30)+430
    chin=float(y[-1]) if len(y) else None
    eye_mask=(v<.49); roi=params['regions']['open_eye'];margin=20
    allowed=np.zeros(eye_mask.shape,bool);allowed[roi[1]-margin:roi[3]+margin,roi[0]-margin:roi[2]+margin]=True
    labels,n=ndimage.label(eye_mask&allowed);sizes=np.bincount(labels.ravel());sizes[0]=0
    if n:
        eye=labels==sizes.argmax();ey,ex=np.where(eye);eye_box=[int(ex.min()),int(ey.min()),int(ex.max()+1),int(ey.max()+1)]
    else:eye_box=None
    def width(y0,y1):
        crop=silhouette[y0:y1,330:910]; ys,xs=np.where(crop)
        return int(xs.max()-xs.min()+1) if len(xs) else None
    # Open gap between the two legs; require five contiguous white pixels in the central axis.
    white=~silhouette
    leg_top=next((y for y in range(810,960) if white[y:y+5,617:623].all()),None)
    total=params['landmarks']['sole_y']-params['landmarks']['ahoge_y']
    height=chin-params['landmarks']['ahoge_y'] if chin is not None else None
    return {'chin_y':chin,'head_height':height,'head_total_ratio':height/total if height else None,
            'open_eye_box':eye_box,'eye_head_ratio':(eye_box[3]-eye_box[1])/height if eye_box and height else None,
            'head_shoulder_ratio':width(160,410)/width(423,486), 'leg_top_y':leg_top,
            'leg_total_ratio':(1203-leg_top)/total if leg_top else None,
            'hand_span_px':int(np.where(silhouette[495:580])[1].max()-np.where(silhouette[495:580])[1].min()+1)}


def star_measure(rgb):
    g=gold(rgb);g[130:]=False
    # The star axis is found in the approved central band; same function for source and candidate.
    positions=np.argwhere(g[:38,585:656]);axis=int(np.median(positions[:,1])+585) if len(positions) else 620
    stripe=g[:130,max(0,axis-12):axis+13].any(1);segments=runs(stripe)
    top=segments[0][0] if segments else None
    length=segments[0][1]-top if segments else 0
    ring=[]
    for x in list(range(axis-150,axis-79))+list(range(axis+80,axis+151)):
        ys=np.flatnonzero(g[:130,x]);
        if len(ys):ring.append(int(ys[0]))
    ring_top=float(np.median(ring)) if ring else None
    return {'axis_x':axis,'top_y':top,'ring_top_y':ring_top,
            'protrusion_px':ring_top-top if top is not None and ring_top is not None else None,
            'contiguous_gold_px':length}


def mean_regions(rgb,params):
    out={}
    for name in ('hair','skin','sleeve','boot_toe','leggings'):
        x0,y0,x1,y1=params['regions'][name];crop=rgb[y0:y1,x0:x1]
        out[name]={'mean_rgb':crop.mean((0,1)).tolist(),'mean_hsv_saturation':float(hsv(crop)[1].mean())}
    return out


def inspect_model(path):
    """Read exported GLB, independently of builder claims. glTF metallic default is 1."""
    g,b,raw=read_glb(path)
    materials=[]
    for i,mat in enumerate(g.get('materials',[])):
        p=mat.get('pbrMetallicRoughness',{});factor=p.get('metallicFactor',1.0)
        tex=p.get('metallicRoughnessTexture');effective=np.asarray([factor],float)
        if tex is not None:
            im=g['images'][g['textures'][tex['index']]['source']]
            channel=np.asarray(Image.open(io.BytesIO(image_bytes(g,b,im))).convert('RGB'))[:,:,2]
            effective=factor*channel.astype(float)/255
        materials.append({'index':i,'name':mat.get('name'),'factor':factor,
                          'factor_explicit':'metallicFactor' in p,'has_mr_texture':tex is not None,
                          'roughness_factor':p.get('roughnessFactor',1),
                          'effective_max':float(effective.max()),
                          'all_texel_fraction_over_0_1':float((effective>.1).mean())})
    meshes=[]
    for i,mesh in enumerate(g['meshes']):
        count=0
        for p in mesh['primitives']:
            assert p.get('mode',4)==4
            count+=g['accessors'][p.get('indices',p['attributes']['POSITION'])]['count']//3
        meshes.append({'index':i,'name':mesh.get('name'),'triangles':count,'within_20000':count<=20000})
    all_zero=bool(materials) and all(m['effective_max']==0 for m in materials)
    return {'sha256':hashlib.sha256(raw).hexdigest(),'materials':materials,'meshes':meshes,
            'T8':{'required':True,'pass':True if all_zero else None,
                  'effective_metallic_max':max((m['effective_max'] for m in materials),default=1),
                  'non_gold_fraction_over_0_1':0 if all_zero else None,
                  'method':'Independent GLB factors and embedded MR B channels. All materials have zero effective metallic, which also proves zero for every non-gold region.' if all_zero else 'Non-gold UV-region classification required; do not infer a pass from missing keys.'}}


def side_halo(rgb, out):
    g=gold(rgb);g[140:]=False
    xs=[];centers=[];tops=[]
    for x in range(350,900):
        rr=[(a,b) for a,b in runs(g[:,x]) if b-a>=3]
        if rr:
            a,b=max(rr,key=lambda item:item[1]-item[0])
            xs.append(x);centers.append((a+b-1)/2);tops.append(a)
    if len(xs)<20:return {'required':True,'pass':None,'status':'insufficient side gold pixels'}
    x=np.asarray(xs);y=np.asarray(centers);slope,inter,_,_=theilslopes(y,x)
    inlier=abs(y-(slope*x+inter))<12
    slope,inter=np.polyfit(x[inlier],y[inlier],1)
    tilt=float(np.degrees(np.arctan(abs(slope))))
    top=int(np.where(g)[0].min());ring_top=float(np.median(np.asarray(tops)[inlier]))
    protrusion=ring_top-top;ratio=protrusion/(1203-71)
    marked=Image.fromarray(rgb.copy());d=ImageDraw.Draw(marked)
    d.line((int(x.min()),float(slope*x.min()+inter),int(x.max()),float(slope*x.max()+inter)),fill='blue',width=2)
    marked.crop((350,0,900,145)).resize((1100,290)).save(out/'side_halo_measurement.png')
    return {'required':True,'ring_tilt_degrees':tilt,'star_protrusion_px':protrusion,
            'star_protrusion_body_height_ratio':ratio,'pass':tilt<=5 and ratio>=.015,
            'method':'Side ortho gold mask; robust median slope, 12px inliers, refit column-run centres; ring top median minus top gold row.',
            'fit_slope':float(slope),'fit_intercept':float(inter),'inlier_columns':int(inlier.sum()),'all_columns':len(xs)}


def evaluate():
    params=json.loads((R2/'eval/source_regions.json').read_text())
    reference=np.asarray(Image.open(SOURCE).convert('RGB'));ref_mask=mask(reference)
    ref={'anatomy':anatomy(reference,params),'star':star_measure(reference),'regions':mean_regions(reference,params)}
    save(R2/'eval/source_metrics.json',ref)
    results={}
    for name in ('B0','B0H'):
        out=R2/name/'eval';manifest=json.loads((out/'render_manifest.json').read_text())
        scores={}
        for yaw in (0,90,180,270):
            rgb=np.asarray(Image.open(out/f'flat_yaw_{yaw}.png').convert('RGB'));m=mask(rgb)
            scores[str(yaw)]=float((m&ref_mask).sum()/(m|ref_mask).sum())
        yaw=max(scores,key=scores.get);front=np.asarray(Image.open(out/f'flat_yaw_{yaw}.png').convert('RGB'))
        m=mask(front);a=anatomy(front,params);st=star_measure(front);colors=mean_regions(front,params)
        lit=np.asarray(Image.open(out/'lit_front.png').convert('RGB'));litcolors=mean_regions(lit,params)
        build=json.loads((R2/name/'build.json').read_text())
        independent=inspect_model(ROOT/build['model']);save(out/'independent_glb_check.json',independent)
        assert independent['sha256']==build['sha256']
        vals={}
        vals['T1']={'value':scores[yaw],'pass':scores[yaw]>=.87,'required':True,'yaw_scores':scores}
        for key,field,tolerance in [('T2','head_total_ratio',.015),('T3','eye_head_ratio',.015),('T4','head_shoulder_ratio',.04),('T5','leg_total_ratio',.015)]:
            x,y=a[field],ref['anatomy'][field];vals[key]={'value':x,'reference':y,'pass':None if x is None or y is None else abs(x-y)<=tolerance,'tolerance':tolerance}
        vals['T6']={'value':st,'reference':ref['star'],'required':True,
          'pass':st['protrusion_px'] is not None and st['protrusion_px']>=ref['star']['protrusion_px']*.65 and st['contiguous_gold_px']>=ref['star']['contiguous_gold_px']*.65}
        vals['T7']=side_halo(np.asarray(Image.open(out/'flat_yaw_90.png').convert('RGB')),out)
        vals['T8']=independent['T8']
        diffs={key:np.abs(np.asarray(row['mean_rgb'])-ref['regions'][key]['mean_rgb']).tolist() for key,row in colors.items()}
        vals['T9']={'value':colors,'reference':ref['regions'],'absolute_channel_deltas':diffs,
                    'pass':all(max(v)<=15 for v in diffs.values()) and .30<=colors['hair']['mean_hsv_saturation']<=.43 and colors['boot_toe']['mean_hsv_saturation']<=.08}
        vals['T10']={'hair_mean_saturation':litcolors['hair']['mean_hsv_saturation'],'pass':litcolors['hair']['mean_hsv_saturation']>=.25}
        vals['T11']={'required':True,'source_meshes':independent['meshes'],
                     'pass':None,'status':'G2 static source under20k; selected existing rig convert --dry is required at Step4, not yet run.'}
        vals['T12']={'pass':None,'status':'human review of side/back/ears/hands required'}
        vals['T13']={'pass':None,'status':'not applicable to B0/B0H; C1/C2 and G1 views do not exist'}
        vals['T14']={'mean_absolute_rgb_delta':float(np.abs(front[300:480,560:800].astype(float)-reference[300:480,560:800]).mean()),'pass':None,'ranking_only':True}
        overlay=np.full(reference.shape,255,np.uint8);overlay[m&ref_mask]=[200,200,200];overlay[ref_mask&~m]=[240,60,60];overlay[m&~ref_mask]=[45,95,235]
        Image.fromarray(overlay).save(out/'overlay_front.png')
        marked=Image.fromarray(front.copy());d=ImageDraw.Draw(marked)
        for yy,label in [(71,'ahoge'),(1203,'sole'),(a['chin_y'],'chin'),(a['leg_top_y'],'leg gap')]:
            if yy is not None:d.line((350,yy,900,yy),fill='red',width=2);d.text((900,yy),label,fill='blue')
        if a['open_eye_box']:d.rectangle(a['open_eye_box'],outline='blue',width=2)
        marked.save(out/'landmarks.png')
        for label,box in [('hand_left',(70,475,280,610)),('hand_right',(970,475,1190,610))]:
            Image.fromarray(front).crop(box).resize((660,405),Image.Resampling.NEAREST).save(out/(label+'.png'))
        results[name]={'model':build['model'],'sha256':build['sha256'],'alignment':manifest['alignment'],'selected_front_yaw':int(yaw),'metrics':vals,
                       'face_eye_texels':{'value':None,'pass':False,'required_minimum':200,'status':'Face not separated at G2; no Roblox texture delivered. Whole-atlas eye remains unresolved.'},
                       'final_acceptance':False,'paid_credits':0}
        # Exactly the requested six views, and no Tripo preview used for judging.
        tiles=[SOURCE,out/f'flat_yaw_{yaw}.png',out/'lit_front.png',out/'lit_quarter.png',out/'flat_yaw_90.png',out/'flat_yaw_180.png']
        names=['REFERENCE','FRONT FLAT','FRONT LIT','3/4 LIT','SIDE FLAT','BACK FLAT']
        sheet=Image.new('RGB',(1881,1314),'white');sd=ImageDraw.Draw(sheet)
        for i,(p,label) in enumerate(zip(tiles,names)):
            x=(i%3)*627;y=(i//3)*657;sd.text((x+12,y+8),name+' | '+label,fill='black')
            sheet.paste(Image.open(p).convert('RGB').resize((627,627),Image.Resampling.LANCZOS),(x,y+30))
        sheet.save(R2/'eval'/f'{name}_sheet.png')
    save(R2/'eval/metrics.json',{'source':params['source'],'source_sha256':params['source_sha256'],'status':'G2 baseline; unresolved tests are null, never counted as passes','candidates':results})
    board=Image.new('RGB',(1000,590),'white');d=ImageDraw.Draw(board)
    font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',22)
    d.text((20,15),'G2 FREE BASELINES | paid 0 | no Roblox upload',font=font,fill='black')
    d.text((20,50),'TEST      B0             B0H',font=font,fill='black')
    for i,key in enumerate([f'T{k}' for k in range(1,15)]):
        cells=[]
        for name in ['B0','B0H']:
            v=results[name]['metrics'][key];state=v['pass']
            cells.append('PASS' if state is True else 'FAIL' if state is False else 'PENDING/N/A')
        d.text((20,85+i*29),f'{key:<9} {cells[0]:<14} {cells[1]}',font=font,fill='black')
    d.text((20,515),'T11: delivery conversion pending. Face >=200 texels pending.',font=font,fill='red')
    d.text((20,550),'Not final acceptance. C1/C2/C3 do not exist before G2.',font=font,fill='black')
    board.save(R2/'eval/scoreboard.png')
    print(json.dumps({k:{t:v['metrics'][t].get('pass') for t in v['metrics']} for k,v in results.items()}))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--source-setup',action='store_true');args=parser.parse_args()
    source_setup() if args.source_setup else evaluate()
