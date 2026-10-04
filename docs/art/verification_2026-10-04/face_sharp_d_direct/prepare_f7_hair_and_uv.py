"""Return actual golden forelock triangles to original Head UV; prevent UV foldovers."""
from pathlib import Path
import sys,json,hashlib,io,colorsys
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[4];sys.path.insert(0,str(ROOT/'tools/costume_r15'))
from glb_io import read_glb,write_glb,accessor_values,image_bytes
SOURCE=ROOT/'build/face_sharp_d_direct/f6/Costume_HaloArcherM_ApprovedF_Neutral_DirectFaceUV_f6.glb'
AFFINE=ROOT/'build/face_sharp_d_direct/f2/Costume_HaloArcherM_ApprovedF_Neutral_DirectFaceUV_f2.glb'
OUT=ROOT/'build/face_sharp_d_direct/f7';repair='--repair-ledger' in sys.argv;OUT.mkdir(parents=True,exist_ok=repair)
doc,binary,_=read_glb(SOURCE);ad,ab,_=read_glb(AFFINE);head=np.asarray(accessor_values(doc,binary,doc['meshes'][1]['primitives'][0]['indices'])).reshape(-1,3);face=np.asarray(accessor_values(doc,binary,doc['meshes'][2]['primitives'][0]['indices'])).reshape(-1,3)
old_uv=np.asarray(accessor_values(doc,binary,16));head_uv=np.asarray(accessor_values(doc,binary,9));pixels=np.asarray(Image.open(io.BytesIO(image_bytes(doc,binary,doc['images'][1]))).convert('RGB'))
restored=[];rows=[]
for i,t in enumerate(face):
 center=old_uv[t].mean(axis=0)*1254
 if not (555<=center[0]<=718 and 730<=center[1]<=948):continue
 samples=[]
 for weight in [[1/3]*3,[.6,.2,.2],[.2,.6,.2],[.2,.2,.6]]:
  u=np.asarray(weight)@head_uv[t];rgb=pixels[int(u[1]*1024),int(u[0]*1024)]/255;hsv=colorsys.rgb_to_hsv(*rgb);samples.append({'rgb':rgb.tolist(),'hsv':list(hsv)})
 golden=sum(.087<s['hsv'][0]<.17 and s['hsv'][1]>.12 and s['hsv'][2]>.5 for s in samples)
 if golden>=3:
  restored.append(i);rows.append({'f6_face_polygon':i,'triangle_vertices':t.tolist(),'old_chart_centroid':center.tolist(),'original_head_texture_samples':samples,'golden_samples':int(golden)})
restore_set=set(restored);new_face=np.asarray([t for i,t in enumerate(face) if i not in restore_set]);new_head=np.concatenate([head,face[restored]])
def add(values,components,ctype,target):
 global binary
 payload=np.asarray(values,dtype='<f4' if ctype==5126 else '<u2').tobytes();binary+=b'\0'*(-len(binary)%4);offset=len(binary);binary+=payload;doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(payload),'target':target});doc['accessors'].append({'bufferView':len(doc['bufferViews'])-1,'componentType':ctype,'count':int(values.size) if components=='SCALAR' else len(values),'type':components});return len(doc['accessors'])-1
doc['meshes'][1]['primitives'][0]['indices']=add(new_head,'SCALAR',5123,34963);doc['meshes'][2]['primitives'][0]['indices']=add(new_face,'SCALAR',5123,34963)
uv=np.asarray(accessor_values(doc,binary,doc['meshes'][2]['primitives'][0]['attributes']['TEXCOORD_0']));base=np.asarray(accessor_values(ad,ab,ad['meshes'][2]['primitives'][0]['attributes']['TEXCOORD_0']))
def area(values):
 p=values[new_face];a=p[:,1]-p[:,0];b=p[:,2]-p[:,0];return a[:,0]*b[:,1]-a[:,1]*b[:,0]
reference=area(base);valid=np.abs(reference)>1e-9
def good(alpha):
 a=area(base+alpha*(uv-base));return bool(np.all(a[valid]*np.sign(reference[valid])>=np.abs(reference[valid])*.08))
lo,hi=0.,1.
for _ in range(45):
 mid=(lo+hi)/2
 if good(mid):lo=mid
 else:hi=mid
alpha=float(np.floor(lo*10000)/10000);final_uv=base+alpha*(uv-base);assert good(alpha)
doc['meshes'][2]['primitives'][0]['attributes']['TEXCOORD_0']=add(final_uv,'VEC2',5126,34962);doc['buffers'][0]['byteLength']=len(binary)
glb=OUT/'Costume_HaloArcherM_ApprovedF_Neutral_DirectFaceUV_f7.glb'
if repair:
 existing,existing_binary,_=read_glb(glb);assert existing==doc and existing_binary[:len(binary)]==binary
else:write_glb(glb,doc,binary)
meta=json.loads(SOURCE.with_suffix('.json').read_text());meta.update({'glb':str(glb),'sha256':hashlib.sha256(glb.read_bytes()).hexdigest()});glb.with_suffix('.json').write_text(json.dumps(meta,indent=2)+'\n')
report={'source':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'candidate':str(glb),'candidate_sha256':meta['sha256'],'restored_actual_forelock_triangles':len(restored),'forelock_ledger':rows,'head_and_face_original_triangle_union_preserved':True,'positions_normals_JW_preserved_from_f6':True,'original_head_uv_png_unchanged':True,'F_texture_pixel_bytes_unchanged':True,'skin_uv_anchor_blend_factor':alpha,'original_folded_triangles':int(np.sum(area(uv)*reference<0)),'final_folded_triangles':int(np.sum(area(final_uv)*reference<0)),'minimum_signed_uv_area_ratio':float(np.min((area(final_uv)[valid]*np.sign(reference[valid]))/np.abs(reference[valid]))),'ready':False,'uploads':0}
(OUT/'hair_uv_ledger.json').write_text(json.dumps(report,indent=2)+'\n');(Path(__file__).parent/'hair_uv_ledger_f7.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='forelock_ledger'}))
