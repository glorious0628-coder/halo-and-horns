"""Inventory unchanged GLB images and existing verified front renders for eye review."""
from pathlib import Path
import hashlib
import io
import json
import sys
import numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/art/verification_2026-10-04/all_3d_eye_audit'
sys.path.insert(0,str(ROOT/'tools/costume_r15'))
from glb_io import read_glb,image_bytes

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def inspect(path):
    doc,blob,data=read_glb(path)
    images=[]
    for index,row in enumerate(doc.get('images',[])):
        payload=image_bytes(doc,blob,row)
        image=Image.open(io.BytesIO(payload))
        images.append({'index':index,'name':row.get('name'),'size':list(image.size),'format':image.format,
                       'sha256':hashlib.sha256(payload).hexdigest(),'bytes':len(payload)})
    return {'path':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),
            'embedded_images':images,'mesh_count':len(doc.get('meshes',[])),
            'joint_count':sum(len(s.get('joints',[])) for s in doc.get('skins',[])),
            'materials':[{'name':m.get('name'),'metallic':m.get('pbrMetallicRoughness',{}).get('metallicFactor',1),
                          'roughness':m.get('pbrMetallicRoughness',{}).get('roughnessFactor',1),
                          'has_metallic_roughness_texture':'metallicRoughnessTexture' in m.get('pbrMetallicRoughness',{})}
                         for m in doc.get('materials',[])]}

def sheet(rows,target):
    width=1024;height=((len(rows)+1)//2)*548
    output=Image.new('RGB',(width,height),'#cccccc');draw=ImageDraw.Draw(output)
    font=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',20)
    for i,(name,path) in enumerate(rows):
        image=Image.open(path).convert('RGB');image.thumbnail((512,512))
        x=(i%2)*512;y=(i//2)*548
        draw.text((x+10,y+8),name,font=font,fill='black')
        output.paste(image,(x+(512-image.width)//2,y+36))
    output.save(target)

def orm_audit():
    path=ROOT/'art/models/costume/redraw/generation-c22df695/model.glb'
    doc,blob,_=read_glb(path);material=doc['materials'][0]['pbrMetallicRoughness']
    base_index=doc['textures'][material['baseColorTexture']['index']]['source']
    orm_index=doc['textures'][material['metallicRoughnessTexture']['index']]['source']
    orm=np.asarray(Image.open(io.BytesIO(image_bytes(doc,blob,doc['images'][orm_index]))).convert('RGB'))
    base=np.asarray(Image.open(io.BytesIO(image_bytes(doc,blob,doc['images'][base_index]))).convert('RGB').resize((orm.shape[1],orm.shape[0]),Image.Resampling.NEAREST))
    mask=(base.min(2)>=180)&((base.max(2).astype(int)-base.min(2))<25)
    blue=orm[:,:,2][mask];green=orm[:,:,1][mask]
    result={'source':str(path.relative_to(ROOT)),'source_sha256':digest(path),
        'method':'Atlas diagnostic only. BaseColor resized nearest to ORM dimensions; bright-neutral mask min RGB>=180 and max-min<25.',
        'bright_neutral_atlas_samples':int(mask.sum()),
        'metallic_blue_percentiles':{str(q):float(np.percentile(blue,q)) for q in [0,10,50,90,100]},
        'sample_fraction_metallic_at_least_128':float(np.mean(blue>=128)),
        'roughness_green_percentiles':{str(q):float(np.percentile(green,q)) for q in [0,10,50,90,100]},
        'limitation':'Not white-clothing segmentation. Includes unused atlas space, pale skin and accessories; no claim that all white clothing is metallic.',
        'source_modified':False}
    (OUT/'sharpd_orm_white_sample_audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    base=ROOT/'docs/art/verification_2026-10-04/avatar_visual_review'
    rows=[]
    for faction in ('halo','horns','neutral'):
        prior=json.loads((base/f'{faction}_review.json').read_text(encoding='utf-8'))
        fixed_sheet=[];candidate_sheet=[]
        for old in prior.get('rows',prior.get('avatars',[])):
            name=old.get('avatar',old.get('name'))
            fixed=ROOT/'art/models/costume/fixed'/f'{name}.glb'
            imgs=old.get('directly_reviewed_images',old.get('observed_images',old.get('images',[])))
            latest=[im for im in imgs if im.get('role')=='latest_local_front_cg']
            if not latest: latest=[im for im in imgs if im['path'].endswith('Neutral_front.png')]
            assert latest,name
            path=Path(latest[0]['path'])
            refreshed=OUT/f'{name.removeprefix("Costume_")}_newest_face_front.png'
            if refreshed.exists():path=refreshed
            metadata=json.loads(path.with_suffix('.json').read_text(encoding='utf-8'))
            candidate=Path(metadata['source'])
            assert digest(candidate)==metadata['source_sha256']
            fixed_png=base/'fixed_front'/f'{name.removeprefix("Costume_")}_fixed_unlit.png'
            row={'avatar':name,'fixed':inspect(fixed),'face_candidate':inspect(candidate),
                 'candidate_scope':'Newest expression GLB by filesystem time, verified against selected old or newly rendered front. Timestamp is not approval.',
                 'fixed_render':{'path':str(fixed_png.relative_to(ROOT)),'sha256':digest(fixed_png)},
                 'candidate_render':{'path':str(path.relative_to(ROOT)),'sha256':digest(path),'source_sha_verified':True},
                 'other_reviewed_geometry_renders':[],'review_status':'metadata only; separately signed direct review is in visual_findings.json'}
            newest=max((ROOT/'art/models/costume/expressions'/name).glob('*.glb'),key=lambda p:p.stat().st_mtime_ns)
            row['newest_expression_glb_by_filesystem_mtime']=inspect(newest)
            row['newest_file_is_approved_or_production']=False
            reviewed_faces={im['sha256'] for im in row['face_candidate']['embedded_images'] if im['size']==[1254,1254]}
            newest_faces={im['sha256'] for im in row['newest_expression_glb_by_filesystem_mtime']['embedded_images'] if im['size']==[1254,1254]}
            row['newest_1254_face_bytes_match_reviewed_candidate']=bool(reviewed_faces) and reviewed_faces==newest_faces
            row['newest_source_geometry_has_this_review_render']=row['face_candidate']['sha256']==row['newest_expression_glb_by_filesystem_mtime']['sha256']
            for im in imgs:
                p=Path(im['path']); meta=p.with_suffix('.json')
                if p==path or not meta.exists():continue
                m=json.loads(meta.read_text(encoding='utf-8'))
                source=m.get('source')
                if source and str(source).endswith('.glb') and Path(source).exists():
                    row['other_reviewed_geometry_renders'].append({'render':str(p.relative_to(ROOT)),
                      'source':str(Path(source).relative_to(ROOT)),'source_sha256':digest(Path(source)),
                      'scope':'Historical QA render; not asserted as current production.'})
            rows.append(row);fixed_sheet.append((name,fixed_png));candidate_sheet.append((name,path))
        sheet(fixed_sheet,OUT/f'{faction}_fixed_contact.png')
        sheet(candidate_sheet,OUT/f'{faction}_face_candidate_contact.png')
    extra=json.loads((OUT/'monster_sharpd_render_manifest_v2.json').read_text(encoding='utf-8'))['rows']
    for r in extra:r['inventory']=inspect(ROOT/r['source']);r['review_status']='metadata only; direct review is in visual_findings.json'
    for i in range(0,len(extra),4):
        group=extra[i:i+4]
        sheet([(r['name'],ROOT/r['renders'][1]['path']) for r in group],OUT/f'monster_sharpd_contact_{i//4+1}.png')
    report={'schema':1,'avatars':rows,'monster_and_sharpd':extra,
        'scope_counts':{'fixed_avatars':18,'front_expression_candidates':18,'monsters_existing':7,'monsters_clothed':2,'sharpd_existing_models':2},
        'candidate_choice_is_user_approval':False,'all_native_qa_completed':False,'paid_calls':0,'uploads':0,'source_mutations':0}
    (OUT/'inventory.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    orm_audit()
    print(json.dumps(report['scope_counts']))

if __name__=='__main__':main()
