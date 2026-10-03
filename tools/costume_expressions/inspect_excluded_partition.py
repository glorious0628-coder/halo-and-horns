"""Prove that excluded projected skin triangles belong to the original neck."""
import json
import hashlib
import sys
from pathlib import Path
import bpy
from mathutils import Matrix,Vector

root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent))
sys.path.insert(0,str(root/'tools/costume_r15'))
from r15_render_context import analyze_verified_partition
from surface_partition import entire_face_beyond_joint

args=sys.argv[sys.argv.index('--')+1:]
head=Path(args[0]).resolve();output=Path(args[1]).resolve()
report=json.loads(head.with_suffix('.json').read_text(encoding='utf-8'))
prepare=json.loads(head.with_name('prepare_report.json').read_text(encoding='utf-8'))
joints=json.loads(Path(report['existing_joints']).read_text(encoding='utf-8'))
avatar=Path(prepare['source']).stem
profile_file=root/'art/models/costume/expressions'/avatar/'facial_profile.json'
profile=json.loads(profile_file.read_text(encoding='utf-8')) if profile_file.exists() else {}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=report['source_rig'])
analysis=analyze_verified_partition(joints,Path(report['source_rig']))
arm=analysis['armature'];primary=analysis['primary_bones']
torso=arm.matrix_world@arm.data.bones[primary['UpperTorso']].head_local
head_joint=arm.matrix_world@arm.data.bones[primary['Head']].head_local
inverse=Matrix(report['fixed_to_rig_affine']).inverted()
cx,cz=prepare['camera_center'];scale=prepare['camera_scale']
regions={}
for part,refs in analysis['faces'].items():
 for obj,index in refs:
  face=obj.data.polygons[index];mat=obj.data.materials[face.material_index]
  if not mat.name.startswith('HeadMat'):continue
  layer=obj.data.uv_layers.active
  key=tuple(sorted((round(layer.data[i].uv.x,6),round(layer.data[i].uv.y,6)) for i in face.loop_indices))
  regions.setdefault(key,[]).append((part,obj,face))
records=[]
reviewed_nonface={}
for region in profile.get('reviewed_non_facial_excluded_regions',[]):
 if region.get('classification')!='original_hood_trim_retained_on_upper_torso' or not region.get('visually_reviewed'):
  raise RuntimeError('Unsupported or unreviewed non-facial exclusion')
 evidence=root/region['inspection']
 if hashlib.sha256(evidence.read_bytes()).hexdigest()!=region['inspection_sha256']:
  raise RuntimeError('Non-facial visual evidence changed')
 marker=json.loads(evidence.read_text(encoding='utf-8'))
 if marker.get('source_sha256')!=prepare['source_sha256'] or not marker.get('original_source_unchanged') or not marker.get('original_geometry_uv_unchanged') or marker.get('product_asset'):
  raise RuntimeError('Non-facial original CG evidence differs')
 marker_keys={tuple(sorted(tuple(uv) for uv in f['original_uv_signature'])) for f in marker['matched_original_faces']}
 key=tuple(sorted(tuple(uv) for uv in region['original_uv_signature']))
 if key not in marker_keys:
  raise RuntimeError('Non-facial UV triangle absent from visual evidence')
 reviewed_nonface[key]=region
for row in report.get('excluded_expression_faces',[]):
 key=tuple(sorted(tuple(uv) for uv in row['original_uv_signature']))
 matches=regions.get(key,[])
 if len(matches)!=1:raise RuntimeError('Excluded original UV signature is not unique')
 part,obj,face=matches[0]
 points=[obj.matrix_world@obj.data.vertices[i].co for i in face.vertices]
 fixed=inverse@(sum(points,Vector())/len(points))
 pixel=[(fixed.x-cx)/scale*768+384,384-(fixed.z-cz)/scale*768]
 head_side=entire_face_beyond_joint(points,torso,head_joint)
 mouth_y=profile.get('mouth_center_screen',[385,614])[1]
 reviewed=part=='UpperTorso' and not head_side and pixel[1]>mouth_y+10
 nonface=reviewed_nonface.get(key) if part=='UpperTorso' else None
 classification=nonface['classification'] if nonface else ('original_neck_skin_retained_on_upper_torso' if reviewed else 'requires_individual_review')
 records.append({'original_uv_signature':key,'source_owner':part,'source_face':face.index,'fixed_frame_centroid':pixel,'fully_on_actual_head_side':head_side,'classification':classification,'visual_evidence':nonface['inspection'] if nonface else None})
result={'avatar':avatar,'source_rig_sha256':report['source_rig_sha256'],'head_sha256':report['sha256'],'reviewed':all(r['classification']!='requires_individual_review' for r in records),'excluded_original_skin_triangles':len(records),'records':records,'original_skin_uv_unchanged':True,'geometry_mutations':0}
output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result),flush=True)
