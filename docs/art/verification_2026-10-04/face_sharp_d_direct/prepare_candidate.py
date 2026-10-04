"""Offline candidate: exact approved D crop + explicit face-UV affine alignment.

Only the face UV accessor and face image reference differ. All original binary
views are retained unchanged. No Studio, paid API, upload, or production edits.
"""
from pathlib import Path
import copy
import hashlib
import json
import struct
import sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT/'tools/costume_r15'))
from glb_io import read_glb, write_glb, image_bytes, accessor_values, view_bytes

OUT = ROOT/'build/face_sharp_d_direct/v1'
SOURCE = ROOT/'art/models/costume/expressions/Costume_HaloArcherM/Costume_HaloArcherM_FaceUnionMouthRestored_v1.glb'
ART = ROOT/'art/out/Avatar_HaloArcherM_FullRedraw_D.png'
SOURCE_SHA = '17972af93f7ecd176f96af8db81fdff00c04e055a1d340b9dd9f288196d54584'
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def save(path, obj): path.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

if OUT.exists(): raise ValueError('Never overwrite candidate directory')
if sha(SOURCE)!=SOURCE_SHA: raise ValueError('Production source changed')
approval=json.loads((ROOT/'art/approved.json').read_text(encoding='utf-8'))['Avatar_HaloArcherM_FullRedraw_D']
if approval['status']!='approved' or (ROOT/approval['file']).resolve()!=ART.resolve(): raise ValueError('Approval identity missing')
OUT.mkdir(parents=True)
crop_box=(128,384,1152,896)
source_image=Image.open(ART)
texture=source_image.crop(crop_box)
texture_path=OUT/'HaloArcherM_ApprovedD_Face_1024x512.png'
texture.save(texture_path)
assert np.array_equal(np.array(texture),np.array(source_image)[384:896,128:1152])

# Manually identified feature centres in the existing 1254 chart and approved D.
# The affine changes UV sampling coordinates; it does not redraw source pixels.
old=np.array([[461.,957.,1.],[783.,934.,1.],[624.,1056.,1.]])
new=np.array([[490.,651.],[744.,629.],[625.,715.]])
affine=np.linalg.solve(old,new)
doc,binary,original_bytes=read_glb(SOURCE)
candidate=copy.deepcopy(doc)
primitive=candidate['meshes'][2]['primitives'][0]
assert candidate['meshes'][2]['name']=='FaceExpression'
old_accessor=primitive['attributes']['TEXCOORD_0']
uv=np.asarray(accessor_values(doc,binary,old_accessor),dtype=np.float64)
pixel=np.column_stack([uv*1254.,np.ones(len(uv))])@affine
crop_uv=(pixel-np.array(crop_box[:2]))/np.array(texture.size)
payload=np.asarray(crop_uv,dtype='<f4').tobytes()
binary+=b'\0'*(-len(binary)%4)
offset=len(binary);binary+=payload
candidate['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(payload),'target':34962})
candidate['accessors'].append({'bufferView':len(candidate['bufferViews'])-1,'componentType':5126,'count':len(uv),'type':'VEC2'})
primitive['attributes']['TEXCOORD_0']=len(candidate['accessors'])-1
binary+=b'\0'*(-len(binary)%4)
offset=len(binary);png_bytes=texture_path.read_bytes();binary+=png_bytes
candidate['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(png_bytes)})
candidate['images'][2]['bufferView']=len(candidate['bufferViews'])-1
candidate['buffers'][0]['byteLength']=len(binary)
glb=OUT/'Costume_HaloArcherM_ApprovedD_DirectFaceUV_v1.glb'
write_glb(glb,candidate,binary)
actual,actual_binary,_=read_glb(glb)
checks={}
for key in ['nodes','skins','animations','materials','textures','samplers','scenes','scene']:
    checks[key+'_json_exact']=doc.get(key)==actual.get(key)
checks['body_and_head_primitives_exact']=doc['meshes'][:2]==actual['meshes'][:2]
for attribute in ['POSITION','NORMAL','JOINTS_0','WEIGHTS_0']:
    checks['face_'+attribute+'_exact']=doc['meshes'][2]['primitives'][0]['attributes'][attribute]==actual['meshes'][2]['primitives'][0]['attributes'][attribute]
checks['face_indices_exact']=doc['meshes'][2]['primitives'][0]['indices']==actual['meshes'][2]['primitives'][0]['indices']
checks['all_original_views_bytes_exact']=all(view_bytes(doc,read_glb(SOURCE)[1],i)[1]==view_bytes(actual,actual_binary,i)[1] for i in range(len(doc['bufferViews'])))
checks['body_head_image_bytes_exact']=all(image_bytes(doc,read_glb(SOURCE)[1],doc['images'][i])==image_bytes(actual,actual_binary,actual['images'][i]) for i in [0,1])
checks['face_png_embedded_exact']=image_bytes(actual,actual_binary,actual['images'][2])==png_bytes
normalized=copy.deepcopy(actual)
normalized['meshes'][2]['primitives'][0]['attributes']['TEXCOORD_0']=old_accessor
normalized['accessors']=normalized['accessors'][:len(doc['accessors'])]
normalized['bufferViews']=normalized['bufferViews'][:len(doc['bufferViews'])]
normalized['images']=doc['images'];normalized['buffers']=doc['buffers']
checks['only_explicit_uv_and_image_json_changes']=normalized==doc
checks['production_source_bytes_unchanged']=SOURCE.read_bytes()==original_bytes
assert all(checks.values()), checks
indices={row[0] for row in accessor_values(doc,read_glb(SOURCE)[1],doc['meshes'][2]['primitives'][0]['indices'])}
active=crop_uv[list(indices)]
assert active.min()>=0 and active.max()<=1
camera_source=json.loads(SOURCE.with_suffix('.json').read_text(encoding='utf-8'))
description={k:camera_source[k] for k in ['camera_scale','camera_center','camera_target','source_front_camera_scale','camera_front_direction','camera_front_up','source_fixed','source_skin']}
description['scope']='camera_reference_only'
description.update({'glb':str(glb),'sha256':sha(glb),'ready':False,'runtime_validated':False,'roblox_uploaded':False})
save(glb.with_suffix('.json'),description)
report={'schema':1,'status':'offline_candidate_requires_visual_review','source_glb':str(SOURCE),'source_glb_sha256':SOURCE_SHA,
        'candidate_glb':str(glb),'candidate_glb_sha256':sha(glb),'approved_art':str(ART),'approved_art_sha256':sha(ART),
        'approval':approval,'texture':str(texture_path),'texture_sha256':sha(texture_path),'texture_size':list(texture.size),
        'crop_xyxy':crop_box,'source_size':list(source_image.size),'crop_pixels_exact':True,'resampling_sharpening_painting':False,
        'old_chart_feature_centres':old[:,:2].tolist(),'approved_D_feature_centres':new.tolist(),
        'feature_order':['wink_centre','open_eye_iris_centre','mouth_centre'],'old_pixels_to_D_pixels_affine':affine.tolist(),
        'feature_alignment_method':'manual feature centre correspondences; exact affine solve; no automatic quality approval',
        'face_vertices_referenced':len(indices),'face_triangles':len(accessor_values(doc,read_glb(SOURCE)[1],doc['meshes'][2]['primitives'][0]['indices']))//3,
        'face_active_uv_min':active.min(axis=0).tolist(),'face_active_uv_max':active.max(axis=0).tolist(),
        'checks':checks,'credits_used':0,'uploads':0,'studio_called':False,'ready_for_game':False,
        'limitations':['Neutral only; existing Serious/SoftSmile cannot use changed UV without separate approved source alignment.',
                       'Original geometry/hair/body proportions are retained; new D character silhouette is not recreated.',
                       'Front affine registration can show colour seams or hair sampled into the existing face; inspect lit front and quarter render.',
                       'Offline renders do not prove actual Roblox texture compression, quality-level rendering, or gameplay.']}
save(OUT/'candidate_proof.json',report)
save(Path(__file__).parent/'candidate_proof_v1.json',report)
print(json.dumps({'candidate':str(glb),'texture':str(texture_path),'checks':checks},ensure_ascii=False))
