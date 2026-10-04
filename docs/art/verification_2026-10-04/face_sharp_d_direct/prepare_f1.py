"""Approved both-eyes-open F: exact crop and original-triangle partition candidate."""
from pathlib import Path
import copy,json,sys,hashlib
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[4];sys.path.insert(0,str(ROOT/'tools/costume_r15'))
from glb_io import read_glb,write_glb,accessor_values,image_bytes,view_bytes
OUT=ROOT/'build/face_sharp_d_direct/f1';OUT.mkdir(parents=True,exist_ok=False)
SOURCE=ROOT/'art/models/costume/expressions/Costume_HaloArcherM/Costume_HaloArcherM_FaceUnionMouthRestored_v1.glb'
BASE=ROOT/'build/face_sharp_d_direct/v5/Costume_HaloArcherM_ApprovedD_DirectFaceUV_v5.glb'
ART=ROOT/'art/out/Avatar_HaloArcherM_Neutral_Balanced_F.png'
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def save(path,obj):path.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
original,ob,_=read_glb(SOURCE);doc,binary,_=read_glb(BASE)
crop_box=(128,384,1152,896);src=Image.open(ART);texture=src.crop(crop_box);png=OUT/'HaloArcherM_ApprovedF_Neutral_Face_1024x512.png';texture.save(png)
assert np.array_equal(np.asarray(src)[384:896,128:1152],np.asarray(texture))
old=np.array([[468.,942.,1.],[783.,942.,1.],[624.,1056.,1.]])
new=np.array([[509.,639.],[743.,639.],[625.,715.]])
affine=np.linalg.solve(old,new)
uv=np.array(accessor_values(original,ob,16));pixels=np.column_stack([uv*1254,np.ones(len(uv))])@affine
mapped=(pixels-np.array(crop_box[:2]))/np.array(texture.size)
def append_view(data,target=None):
 global binary
 binary+=b'\0'*(-len(binary)%4);offset=len(binary);binary+=data;v={'buffer':0,'byteOffset':offset,'byteLength':len(data)}
 if target:v['target']=target
 doc['bufferViews'].append(v);return len(doc['bufferViews'])-1
view=append_view(np.asarray(mapped,dtype='<f4').tobytes(),34962);doc['accessors'].append({'bufferView':view,'componentType':5126,'count':len(uv),'type':'VEC2'})
doc['meshes'][2]['primitives'][0]['attributes']['TEXCOORD_0']=len(doc['accessors'])-1
doc['images'][2]['bufferView']=append_view(png.read_bytes());doc['buffers'][0]['byteLength']=len(binary)
glb=OUT/'Costume_HaloArcherM_ApprovedF_Neutral_DirectFaceUV_f1.glb';write_glb(glb,doc,binary)
camera=json.loads(BASE.with_suffix('.json').read_text());camera.update({'glb':str(glb),'sha256':sha(glb),'new_default_eyes_open_required':False,'ready':False,'roblox_uploaded':False,'runtime_validated':False})
save(glb.with_suffix('.json'),camera)
report={'source_glb_sha256':sha(SOURCE),'partition_base_sha256':sha(BASE),'candidate':str(glb),'candidate_sha256':sha(glb),'approved_art':str(ART),'approved_art_sha256':sha(ART),'approval_quote':'좋아, 이걸로 해줘','approval_source':'root directly relayed latest explicit user selection; art/approved.json registration pending at preparation','crop_box':crop_box,'texture_size':list(texture.size),'crop_pixels_exact':True,'texture_pixels_resampled_or_painted':False,'old_feature_centres':old[:,:2].tolist(),'approved_feature_centres':new.tolist(),'feature_order':['left_open_eye','right_open_eye','mouth'],'old_pixels_to_F_pixels_affine':affine.tolist(),'ready_for_game':False,'credits_used':0,'uploads':0,'studio_called':False,'production_changed':False}
save(OUT/'candidate_proof.json',report);save(Path(__file__).parent/'candidate_proof_f1.json',report)
print(json.dumps({'candidate':str(glb),'sha256':sha(glb)}))
