"""Compare fixed/rigged head coordinates by unchanged original UV triangles."""
import hashlib
import json
import sys
from pathlib import Path
import bpy
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/costume_r15'))
import convert
sys.path.insert(0,str(Path(__file__).resolve().parent))
from r15_render_context import analyze_verified_partition

def signature(layer,face):
    return tuple(sorted((round(layer.data[i].uv.x,6),round(layer.data[i].uv.y,6)) for i in face.loop_indices))

def samples(obj,face):
    uv=obj.data.uv_layers.active
    return {(round(uv.data[i].uv.x,6),round(uv.data[i].uv.y,6)):list(obj.matrix_world@obj.data.vertices[obj.data.loops[i].vertex_index].co) for i in face.loop_indices}

args=sys.argv[sys.argv.index('--')+1:]
fixed,joints_file,output=map(Path,args)
joints=json.loads(joints_file.read_text(encoding='utf-8'));rig=Path(joints['source'])
if hashlib.sha256(rig.read_bytes()).hexdigest()!=joints['source_sha256']:
 raise RuntimeError('Rig source checksum changed')
fixed_sha=hashlib.sha256(fixed.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(rig.resolve()))
analysis=analyze_verified_partition(joints,rig)
rig_faces={}
for obj,index in analysis['faces']['Head']:
 face=obj.data.polygons[index]
 if obj.data.materials[face.material_index].name.startswith('HeadMat'):
  rig_faces[signature(obj.data.uv_layers.active,face)]=samples(obj,face)
for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(fixed.resolve()))
x=[];y=[];matched=set()
for obj in bpy.context.scene.objects:
 if obj.type!='MESH':continue
 for face in obj.data.polygons:
  if not obj.data.materials[face.material_index].name.startswith('HeadMat'):continue
  key=signature(obj.data.uv_layers.active,face)
  if key not in rig_faces:continue
  matched.add(key)
  for uv,point in samples(obj,face).items():
   x.append(point+[1]);y.append(rig_faces[key][uv])
x=np.array(x);y=np.array(y)
if not len(x):raise RuntimeError('No matching original HeadMat UV triangles')
affine=np.linalg.lstsq(x,y,rcond=None)[0]
residual=np.linalg.norm(x@affine-y,axis=1)
identity_error=np.linalg.norm(x[:,:3]-y,axis=1)
unchanged=hashlib.sha256(fixed.read_bytes()).hexdigest()==fixed_sha and hashlib.sha256(rig.read_bytes()).hexdigest()==joints['source_sha256']
report={'fixed':str(fixed),'rig':str(rig),'fixed_sha256':fixed_sha,'rig_sha256':joints['source_sha256'],'matched_corners':len(x),'rig_headmat_triangles':len(rig_faces),'matched_original_head_triangles':len(matched),'missing_rig_head_uv_signatures':len(set(rig_faces)-matched),'head_mapping_complete':len(x)==len(rig_faces)*3 and set(rig_faces)==matched,'fixed_to_rig_affine':affine.T.tolist(),'affine_residual_max':float(residual.max()),'affine_residual_mean':float(residual.mean()),'unmapped_identity_error_max':float(identity_error.max()),'unmapped_identity_error_mean':float(identity_error.mean()),'source_files_unchanged':unchanged}
if not unchanged:raise RuntimeError('Original model changed')
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report))
