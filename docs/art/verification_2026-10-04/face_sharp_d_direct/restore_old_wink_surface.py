"""Explicit local P/N exception for old wink relief; no topology/JW/UV edits."""
from pathlib import Path
import sys,json,hashlib
import numpy as np
ROOT=Path(__file__).resolve().parents[4];sys.path.insert(0,str(ROOT/'tools/costume_r15'))
from glb_io import read_glb,write_glb,accessor_values
SOURCE=ROOT/'build/face_sharp_d_direct/f3/Costume_HaloArcherM_ApprovedF_Neutral_DirectFaceUV_f3.glb'
OUT=ROOT/'build/face_sharp_d_direct/f4';OUT.mkdir(parents=True,exist_ok=False)
doc,binary,_=read_glb(SOURCE);fp=doc['meshes'][2]['primitives'][0];pos_id=fp['attributes']['POSITION'];normal_id=fp['attributes']['NORMAL']
pos=np.asarray(accessor_values(doc,binary,pos_id));normals=np.asarray(accessor_values(doc,binary,normal_id));old=pos.copy();old_normals=normals.copy();uv=np.asarray(accessor_values(doc,binary,16))*1254
projection=np.linalg.lstsq(np.column_stack([pos,np.ones(len(pos))]),uv,rcond=None)[0]
error=np.abs(np.column_stack([pos,np.ones(len(pos))])@projection-uv).max()
assert error<.001,error
depth_axis=np.cross(projection[:3,0],projection[:3,1]);depth_axis/=np.linalg.norm(depth_axis)
face_ids=np.unique(np.asarray(accessor_values(doc,binary,fp['indices'])).reshape(-1))
center=np.array([461.,957.]);radii=np.array([116.,52.]);local=(uv-center)/radii;radius=np.linalg.norm(local,axis=1)
ring=np.asarray([i for i in face_ids if 1.08<radius[i]<1.85 and 305<uv[i,0]<625 and 835<uv[i,1]<1070])
def basis(x):return np.column_stack([np.ones(len(x)),x[:,0],x[:,1],x[:,0]**2,x[:,0]*x[:,1],x[:,1]**2])
coef=np.linalg.lstsq(basis(local[ring]),pos[ring]@depth_axis,rcond=None)[0]
target_depth=basis(local)@coef
weight=np.clip((1.16-radius)/.35,0,1);weight=weight*weight*(3-2*weight)
changed_keys={tuple(np.round(pos[i],7)) for i in face_ids if weight[i]>0}
changed=[i for i,p in enumerate(pos) if tuple(np.round(p,7)) in changed_keys and weight[i]>0]
for i in changed:
 delta=(target_depth[i]-pos[i]@depth_axis)*weight[i]
 pos[i]+=delta*depth_axis
 x,y=local[i];dx=(coef[1]+2*coef[3]*x+coef[4]*y)/radii[0];dy=(coef[2]+coef[4]*x+2*coef[5]*y)/radii[1]
 fitted=depth_axis-dx*projection[:3,0]-dy*projection[:3,1];fitted/=np.linalg.norm(fitted)
 if fitted@normals[i]<0:fitted=-fitted
 normals[i]=normals[i]*(1-weight[i])+fitted*weight[i];normals[i]/=np.linalg.norm(normals[i])
def add(values):
 global binary
 payload=np.asarray(values,dtype='<f4').tobytes();binary+=b'\0'*(-len(binary)%4);offset=len(binary);binary+=payload;doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(payload),'target':34962});doc['accessors'].append({'bufferView':len(doc['bufferViews'])-1,'componentType':5126,'count':len(values),'type':'VEC3','min':values.min(axis=0).tolist(),'max':values.max(axis=0).tolist()});return len(doc['accessors'])-1
newp,newn=add(pos),add(normals)
for mi in [1,2]:doc['meshes'][mi]['primitives'][0]['attributes'].update({'POSITION':newp,'NORMAL':newn})
doc['buffers'][0]['byteLength']=len(binary);glb=OUT/'Costume_HaloArcherM_ApprovedF_Neutral_DirectFaceUV_f4.glb';write_glb(glb,doc,binary)
meta=json.loads(SOURCE.with_suffix('.json').read_text());meta.update({'glb':str(glb),'sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'local_PN_exception':'old wink only; explicit ledger; not original exact P/N contract'});glb.with_suffix('.json').write_text(json.dumps(meta,indent=2)+'\n')
frame=np.asarray(next(n['matrix'] for n in doc['nodes'] if n.get('name')=='CostumeSkinFrame')).reshape(4,4).T
displacement=(pos-old)@frame[:3,:3].T
rows=[{'vertex':i,'old_chart_pixel':uv[i].tolist(),'weight':float(weight[i]),'old_position':old[i].tolist(),'new_position':pos[i].tolist(),'old_normal':old_normals[i].tolist(),'new_normal':normals[i].tolist(),'displacement_studs':float(np.linalg.norm(displacement[i]))} for i in changed]
report={'source':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'candidate':str(glb),'candidate_sha256':meta['sha256'],'exception':'old wink surface P/N only; approved root scope expansion','projection_residual_max_px':float(error),'old_chart_ellipse_center':center.tolist(),'ellipse_radii':radii.tolist(),'outer_radius_factor':1.16,'ring_sample_vertices':len(ring),'fit_coefficients':coef.tolist(),'changed_vertices':len(changed),'maximum_displacement_studs':float(np.linalg.norm(displacement,axis=1).max()),'all_triangle_indices_preserved':True,'joint_weight_values_preserved':True,'uv_images_preserved':True,'body_mesh_preserved':True,'ledger':rows,'ready':False,'uploads':0}
(OUT/'wink_PN_exception_ledger.json').write_text(json.dumps(report,indent=2)+'\n');(Path(__file__).parent/'wink_PN_exception_ledger_f4.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='ledger'}))
