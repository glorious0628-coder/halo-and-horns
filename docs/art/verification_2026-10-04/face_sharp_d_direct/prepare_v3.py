"""Candidate v3: visible dark/neutral eye triangles only, with ray ledger."""
from pathlib import Path
import copy,hashlib,json,sys,collections
import numpy as np
ROOT=Path(__file__).resolve().parents[4];sys.path.insert(0,str(ROOT/'tools/costume_r15'))
from glb_io import read_glb,write_glb,accessor_values,image_bytes,view_bytes
OUT=ROOT/'build/face_sharp_d_direct/v3';OUT.mkdir(parents=True,exist_ok=False)
SOURCE=ROOT/'art/models/costume/expressions/Costume_HaloArcherM/Costume_HaloArcherM_FaceUnionMouthRestored_v1.glb'
V1=ROOT/'build/face_sharp_d_direct/v1/Costume_HaloArcherM_ApprovedD_DirectFaceUV_v1.glb'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(p,obj):p.write_text(json.dumps(obj,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
original,ob,source_bytes=read_glb(SOURCE);doc,binary,_=read_glb(V1)
uv=np.asarray(accessor_values(original,ob,16))*1254
head=np.array(accessor_values(original,ob,13)).reshape(-1,3)
face=np.array(accessor_values(original,ob,19)).reshape(-1,3)
pos=np.array(accessor_values(original,ob,20));normal=np.array(accessor_values(original,ob,21))
# Feature rectangles are inherited from the pre-existing reviewed facial profile,
# extended by 3 old-chart pixels to avoid cracks at original eyelash borders.
regions={'closed_eye':[338,890,565,1012],'open_eye':[694,832,913,1026]}
centroid=uv[head].mean(axis=1)
selected=json.loads((Path(__file__).parent/'missing_front_rays.json').read_text())['selected']
selected_set=set(selected)
new_head=np.array([t for i,t in enumerate(head) if i not in selected_set],dtype=np.uint16)
new_face=np.concatenate([face,head[selected]],axis=0).astype(np.uint16)
def append_accessor(values):
    global binary
    payload=values.astype('<u2').tobytes();binary+=b'\0'*(-len(binary)%4);offset=len(binary);binary+=payload
    doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(payload),'target':34963})
    doc['accessors'].append({'bufferView':len(doc['bufferViews'])-1,'componentType':5123,'count':int(values.size),'type':'SCALAR'})
    return len(doc['accessors'])-1
doc['meshes'][1]['primitives'][0]['indices']=append_accessor(new_head)
doc['meshes'][2]['primitives'][0]['indices']=append_accessor(new_face)
doc['buffers'][0]['byteLength']=len(binary)
glb=OUT/'Costume_HaloArcherM_ApprovedD_DirectFaceUV_v3.glb';write_glb(glb,doc,binary)
actual,ab,_=read_glb(glb)
checks={}
for key in ['nodes','skins','animations','materials','textures','samplers','scenes','scene']:
    checks[key+'_exact']=original.get(key)==actual.get(key)
checks['body_primitive_exact']=original['meshes'][0]==actual['meshes'][0]
checks['head_attributes_exact']=original['meshes'][1]['primitives'][0]['attributes']==actual['meshes'][1]['primitives'][0]['attributes']
checks['face_position_normal_joint_weight_exact']=all(original['meshes'][2]['primitives'][0]['attributes'][k]==actual['meshes'][2]['primitives'][0]['attributes'][k] for k in ['POSITION','NORMAL','JOINTS_0','WEIGHTS_0'])
checks['source_face_head_JW_equal']=accessor_values(original,ob,10)==accessor_values(original,ob,17) and accessor_values(original,ob,11)==accessor_values(original,ob,18)
checks['exact_original_triangle_multiset']=collections.Counter(map(tuple,np.concatenate([head,face])))==collections.Counter(map(tuple,np.concatenate([new_head,new_face])))
checks['all_original_buffer_views_bytes_exact']=all(view_bytes(original,ob,i)[1]==view_bytes(actual,ab,i)[1] for i in range(len(original['bufferViews'])))
checks['body_head_png_exact']=all(image_bytes(original,ob,original['images'][i])==image_bytes(actual,ab,actual['images'][i]) for i in [0,1])
checks['face_png_v1_exact']=image_bytes(read_glb(V1)[0],read_glb(V1)[1],read_glb(V1)[0]['images'][2])==image_bytes(actual,ab,actual['images'][2])
checks['source_unchanged']=SOURCE.read_bytes()==source_bytes
assert all(checks.values()), checks
camera_source=json.loads(V1.with_suffix('.json').read_text());camera={k:camera_source[k] for k in ['camera_scale','camera_center','camera_target','source_front_camera_scale','camera_front_direction','camera_front_up','source_fixed','source_skin']};camera['scope']='camera_reference_only';camera.update({'glb':str(glb),'sha256':sha(glb),'original_headbase_uv_unchanged':True,'original_body_primitive_unchanged':True,'face_uv_changed':True,'original_face_triangles':len(new_face),'headbase_triangles':len(new_head),'partition_changed':True,'ready':False,'roblox_uploaded':False,'runtime_validated':False})
save(glb.with_suffix('.json'),camera)
ledger={'source_sha256':sha(SOURCE),'v1_sha256':sha(V1),'candidate_sha256':sha(glb),'candidate':str(glb),'regions_old_1254_chart':regions,'selection':'original visible raycast hits in eye boxes, dark/neutral original source pixels, explicit missing_front_rays.json ledger; visual review required',
        'moved_head_triangle_indices':selected,'moved_head_triangles':[{'head_index':i,'vertices':head[i].tolist(),'old_chart_centroid':centroid[i].tolist()} for i in selected],
        'original_head_triangles':len(head),'original_face_triangles':len(face),'candidate_head_triangles':len(new_head),'candidate_face_triangles':len(new_face),'checks':checks,'ready':False,'uploads':0,'credits_used':0}
save(OUT/'partition_ledger.json',ledger);save(Path(__file__).parent/'partition_ledger_v3.json',ledger)
print(json.dumps({'candidate':str(glb),'moved_triangles':len(selected),'checks':checks}))
