"""Local UV skin anchors; approved F raster pixels are never changed."""
from pathlib import Path
import sys,json,hashlib,copy
import numpy as np
from scipy.interpolate import RBFInterpolator
ROOT=Path(__file__).resolve().parents[4];sys.path.insert(0,str(ROOT/'tools/costume_r15'))
from glb_io import read_glb,write_glb,accessor_values
SOURCE=ROOT/'build/face_sharp_d_direct/f2/Costume_HaloArcherM_ApprovedF_Neutral_DirectFaceUV_f2.glb'
OUT=ROOT/'build/face_sharp_d_direct/f3';OUT.mkdir(parents=True,exist_ok=False)
doc,binary,_=read_glb(SOURCE);uv_accessor=doc['meshes'][2]['primitives'][0]['attributes']['TEXCOORD_0'];base=np.asarray(accessor_values(doc,binary,uv_accessor))*[1024,512]+[128,384]
# F source-space anchors retarget skin samples away from differing old hairline.
# Facial feature rectangles remain locked to the exact prior affine mapping.
anchors=np.array([[675,515],[518,562],[692,544],[622,610],[480,571],[581,588],[846,692],[407,688],[625,785],[335,708],[906,708]],float)
target=np.array([[680,462],[493,532],[720,514],[624,647],[465,555],[580,635],[826,703],[422,698],[625,785],[355,708],[886,708]],float)
field=RBFInterpolator(anchors,target-anchors,kernel='thin_plate_spline',smoothing=0)
delta=field(base)
lock=np.ones(len(base))
feature_boxes=[(401,564,566,697),(686,558,851,697),(575,695,680,739)]
for left,top,right,bottom in feature_boxes:
 dx=np.maximum(np.maximum(left-base[:,0],base[:,0]-right),0)
 dy=np.maximum(np.maximum(top-base[:,1],base[:,1]-bottom),0)
 distance=np.hypot(dx,dy);t=np.clip(distance/35,0,1);smooth=t*t*(3-2*t);lock=np.minimum(lock,smooth)
# Do not retarget lower cheeks or sample outside the approved face crop.
t=np.clip((785-base[:,1])/50,0,1);lock*=t*t*(3-2*t)
delta*=lock[:,None];mapped=(base+delta-[128,384])/[1024,512]
payload=np.asarray(mapped,dtype='<f4').tobytes();binary+=b'\0'*(-len(binary)%4);offset=len(binary);binary+=payload
doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(payload),'target':34962});doc['accessors'].append({'bufferView':len(doc['bufferViews'])-1,'componentType':5126,'count':len(base),'type':'VEC2'});doc['meshes'][2]['primitives'][0]['attributes']['TEXCOORD_0']=len(doc['accessors'])-1;doc['buffers'][0]['byteLength']=len(binary)
glb=OUT/'Costume_HaloArcherM_ApprovedF_Neutral_DirectFaceUV_f3.glb';write_glb(glb,doc,binary)
meta=json.loads(SOURCE.with_suffix('.json').read_text());meta.update({'glb':str(glb),'sha256':hashlib.sha256(glb.read_bytes()).hexdigest()});glb.with_suffix('.json').write_text(json.dumps(meta,indent=2)+'\n')
indices={v[0] for v in accessor_values(doc,binary,doc['meshes'][2]['primitives'][0]['indices'])};active=np.asarray(sorted(indices));assert mapped[active].min()>=0 and mapped[active].max()<=1
report={'candidate':str(glb),'candidate_sha256':meta['sha256'],'source':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'anchors_F_source_xy':anchors.tolist(),'target_F_source_xy':target.tolist(),'feature_lock_boxes_F_xyxy':feature_boxes,'method':'thin-plate-spline skin UV offsets; zero offset inside explicit eye/mouth boxes; smooth 35 px ramp outside','source_raster_pixels_changed':False,'positions_normals_joints_weights_changed':False,'active_face_uv_vertices':len(active),'maximum_active_UV_shift_in_source_pixels':float(np.linalg.norm(delta[active],axis=1).max()),'ready':False,'uploads':0}
(OUT/'uv_anchor_ledger.json').write_text(json.dumps(report,indent=2)+'\n');(Path(__file__).parent/'uv_anchor_ledger_f3.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
