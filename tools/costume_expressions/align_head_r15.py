# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Align new facial head to the exact existing R15 bone-weight partition.

No source GLB changes or uploads. Match original per-face UV signatures rather
than guessing the neck height; preserve existing R15 coordinate and Head center.
"""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import hashlib
import json
import math
import sys
from pathlib import Path
from collections import Counter

import bpy
import numpy as np
from mathutils import Matrix

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'/'costume_r15'))
sys.path.insert(0,str(Path(__file__).resolve().parent))
import convert
from r15_render_context import analyze_verified_partition

args=sys.argv[sys.argv.index('--')+1:]
prepared=Path(args[0]).resolve();neutral=Path(args[1]).resolve();joints_path=Path(args[2]).resolve();output=Path(args[3]).resolve()
joints=json.loads(joints_path.read_text(encoding='utf-8'))
prepare_meta=json.loads(prepared.with_name('prepare_report.json').read_text(encoding='utf-8'))
fixed_source=Path(prepare_meta['source'])
fixed_sha=hashlib.sha256(fixed_source.read_bytes()).hexdigest()
if fixed_sha!=prepare_meta['source_sha256']:raise RuntimeError('Fixed source checksum changed')
rig_source=Path(joints['source']);rig_sha=hashlib.sha256(rig_source.read_bytes()).hexdigest()
if rig_sha!=joints['source_sha256']:raise RuntimeError('Rig source checksum changed')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(rig_source))
analysis=analyze_verified_partition(joints,rig_source)
coordinate=analysis['coordinate'].copy();to_blender=analysis['to_blender'].copy();center=analysis['centers']['Head'].copy()
expected=next(part['CFrame'][:3] for part in joints['parts'] if part['name']=='Head')
if max(abs(a-b) for a,b in zip(center,expected))>1e-6:raise RuntimeError('Existing Head center differs')


def signature(layer,face):
    return tuple(sorted((round(layer.data[index].uv.x,6),round(layer.data[index].uv.y,6)) for index in face.loop_indices))


regions={};region_counts=Counter();rig_points={}
for part,refs in analysis['faces'].items():
    for obj,index in refs:
        face=obj.data.polygons[index];material=obj.data.materials[face.material_index]
        if not material.name.startswith('HeadMat'):continue
        layer=obj.data.uv_layers.active
        key=signature(layer,face)
        if key in regions and regions[key]!=part:raise RuntimeError('Ambiguous UV signature across R15 regions')
        regions[key]=part;region_counts[part]+=1
        if part=='Head':
            rig_points[key]={(round(layer.data[i].uv.x,6),round(layer.data[i].uv.y,6)):list(obj.matrix_world@obj.data.vertices[obj.data.loops[i].vertex_index].co) for i in face.loop_indices}
expected_head_triangles=sum(mesh['triangles'] for mesh in joints['meshes'] if mesh['part']=='Head' and (mesh.get('material') or '').startswith('HeadMat'))
retained_head_auxiliary=[mesh for mesh in joints['meshes'] if mesh['part']=='Head' and not (mesh.get('material') or '').startswith('HeadMat')]
if region_counts['Head']!=expected_head_triangles or expected_head_triangles<=0:raise RuntimeError('Original HeadMat Head triangle count differs from existing joints')
for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
for material in list(bpy.data.materials):
    if material.users==0:bpy.data.materials.remove(material)
# The paid rig preserves UVs but rescales source coordinates. Recover the exact
# original coordinate mapping from unchanged UV triangle/corner correspondence.
bpy.ops.import_scene.gltf(filepath=str(fixed_source))
sample_x=[];sample_y=[]
for obj in bpy.context.scene.objects:
    if obj.type!='MESH':continue
    for face in obj.data.polygons:
        if not obj.data.materials[face.material_index].name.startswith('HeadMat'):continue
        layer=obj.data.uv_layers.active;key=signature(layer,face)
        if key not in rig_points:continue
        for i in face.loop_indices:
            uv=(round(layer.data[i].uv.x,6),round(layer.data[i].uv.y,6))
            point=obj.matrix_world@obj.data.vertices[obj.data.loops[i].vertex_index].co
            sample_x.append([*point,1]);sample_y.append(rig_points[key][uv])
sample_x=np.array(sample_x);sample_y=np.array(sample_y)
if len(sample_x)!=expected_head_triangles*3:raise RuntimeError('Incomplete original coordinate matching')
coefficients=np.linalg.lstsq(sample_x,sample_y,rcond=None)[0]
residual=np.linalg.norm(sample_x@coefficients-sample_y,axis=1)
if float(residual.max())>1e-5:raise RuntimeError('Fixed/rig coordinates do not have an exact affine correspondence')
fixed_to_rig=Matrix([*coefficients.T.tolist(),[0,0,0,1]])
for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
for material in list(bpy.data.materials):
    if material.users==0:bpy.data.materials.remove(material)
bpy.ops.import_scene.gltf(filepath=str(prepared))
head=next(obj for obj in bpy.context.scene.objects if obj.type=='MESH' and any(mat.name.startswith('FaceExpressionMat') for mat in obj.data.materials))
mesh=head.data
original_mat=next(mat for mat in mesh.materials if mat.name.startswith('HeadMat'))
original_tex=next(node for node in original_mat.node_tree.nodes if node.type=='TEX_IMAGE' and node.image)
uv_link=list(original_tex.inputs['Vector'].links)
source_uv_name=uv_link[0].from_node.uv_map if uv_link and uv_link[0].from_node.type=='UVMAP' else mesh.uv_layers.active.name
source_uv=mesh.uv_layers[source_uv_name]
face_mat=next(mat for mat in mesh.materials if mat.name.startswith('FaceExpressionMat'))
face_tex=next(node for node in face_mat.node_tree.nodes if node.type=='TEX_IMAGE' and node.image)
face_tex.image=bpy.data.images.load(str(neutral),check_existing=False)
kept=[];removed=Counter();cap_count=0;unmatched=[];excluded_expression_faces=[]
for face in mesh.polygons:
    key=signature(source_uv,face)
    if all(abs(u)<1e-9 and abs(v)<1e-9 for u,v in key) and mesh.materials[face.material_index]==face_mat:
        kept.append(face.index);cap_count+=1;continue
    if key not in regions:
        unmatched.append(face.index);continue
    part=regions[key]
    if part=='Head':kept.append(face.index)
    else:
        removed[part]+=1
        if mesh.materials[face.material_index]==face_mat:
            excluded_expression_faces.append({'part':part,'original_uv_signature':key,'prepared_face':face.index,'fixed_world_centroid':list(sum((head.matrix_world@mesh.vertices[i].co for i in face.vertices),__import__('mathutils').Vector())/len(face.vertices))})
if unmatched:raise RuntimeError('Original UV signatures not found: '+str(len(unmatched)))
if len(kept)!=expected_head_triangles+cap_count or cap_count!=224:raise RuntimeError('Unexpected head/cap triangle coverage')
old_uvs={layer.name:[point.uv.copy() for point in layer.data] for layer in mesh.uv_layers}
old_normals=[normal.vector.copy() for normal in mesh.corner_normals]
old_materials=list(mesh.materials)
world_matrix=head.matrix_world.copy()
local_matrix=to_blender@Matrix.Translation(-center)@coordinate@fixed_to_rig@world_matrix
transformed=[local_matrix@vertex.co for vertex in mesh.vertices]
new_mesh=bpy.data.meshes.new('R15_Head_Expressions')
new_mesh.from_pydata(transformed,[],[list(mesh.polygons[index].vertices) for index in kept]);new_mesh.update()
for material in old_materials:new_mesh.materials.append(material)
for layer_name in old_uvs:new_mesh.uv_layers.new(name=layer_name)
loop_cursor=0;normals=[]
normal_matrix=local_matrix.to_3x3().inverted().transposed()
for new_face,old_index in zip(new_mesh.polygons,kept):
    old_face=mesh.polygons[old_index];new_face.material_index=old_face.material_index
    for old_loop in old_face.loop_indices:
        for layer_name,values in old_uvs.items():new_mesh.uv_layers[layer_name].data[loop_cursor].uv=values[old_loop]
        normals.append((normal_matrix@old_normals[old_loop]).normalized());loop_cursor+=1
new_mesh.normals_split_custom_set(normals)
head.data=new_mesh;head.matrix_world=Matrix.Translation(to_blender@center)
bpy.ops.object.select_all(action='DESELECT');head.select_set(True);bpy.context.view_layer.objects.active=head
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.separate(type='MATERIAL');bpy.ops.object.mode_set(mode='OBJECT')
pieces=[]
for obj in bpy.context.scene.objects:
    if obj.type!='MESH':continue
    used={obj.data.materials[face.material_index].name for face in obj.data.polygons}
    if any(name.startswith('FaceExpressionMat') for name in used):obj.name='FaceExpression';pieces.append(obj)
    elif any(name.startswith('HeadMat') for name in used):obj.name='HeadBase';pieces.append(obj)
for obj in pieces:
    material=obj.data.materials[obj.data.polygons[0].material_index]
    texture=next(node for node in material.node_tree.nodes if node.type=='TEX_IMAGE' and node.image)
    links=list(texture.inputs['Vector'].links)
    uv_name=links[0].from_node.uv_map if links and links[0].from_node.type=='UVMAP' else obj.data.uv_layers.active.name
    used_layer=obj.data.uv_layers[uv_name];obj.data.uv_layers.active=used_layer
    for layer in list(obj.data.uv_layers):
        if layer!=used_layer:obj.data.uv_layers.remove(layer)
    used_layer.name='UVMap'
    for node in material.node_tree.nodes:
        if node.type=='UVMAP':node.uv_map='UVMap'
bpy.ops.object.select_all(action='DESELECT')
for obj in pieces:obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_yup=True)
fixed_gltf,fixed_binary,_=convert.read_glb(fixed_source)
fixed_head_material=next(material for material in fixed_gltf['materials'] if material['name']=='HeadMat')
fixed_image_index=fixed_gltf['textures'][fixed_head_material['pbrMetallicRoughness']['baseColorTexture']['index']]['source']
original_head_png=convert.image_bytes(fixed_gltf,fixed_binary,fixed_gltf['images'][fixed_image_index])
export_gltf,export_binary,_=convert.read_glb(output)
embedded={}
for material in export_gltf['materials']:
    image_index=export_gltf['textures'][material['pbrMetallicRoughness']['baseColorTexture']['index']]['source']
    image=export_gltf['images'][image_index]
    data=neutral.read_bytes() if material['name'].startswith('FaceExpressionMat') else original_head_png
    embedded[image['name']]=(data,'image/png')
texture_checks=convert.preserve_images(output,embedded)
if hashlib.sha256(rig_source.read_bytes()).hexdigest()!=rig_sha:raise RuntimeError('Rig source modified')
report={'source_rig':str(rig_source),'source_rig_sha256':rig_sha,'source_rig_unchanged':True,'existing_joints':str(joints_path),'existing_head_cframe':expected,'head_r15_partition_original_triangles':expected_head_triangles,'new_mouth_cap_triangles':cap_count,'excluded_original_non_head_triangles':dict(removed),'triangles':sum(len(obj.data.polygons) for obj in pieces),'pieces':[{'name':obj.name,'triangles':len(obj.data.polygons),'location':list(obj.location),'uv_layers':[layer.name for layer in obj.data.uv_layers]} for obj in pieces],'glb':str(output),'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'geometry_uv_verification':'original UV face signatures matched exact real bone-weight R15 partition; existing coordinate and head center reused','runtime_validated':False}
points=[obj.matrix_world@obj.data.vertices[index].co for obj in pieces for index in {i for face in obj.data.polygons for i in face.vertices}]
lo=[min(point[i] for point in points) for i in range(3)]
hi=[max(point[i] for point in points) for i in range(3)]
partition=joints.get('mechanical_surface_partition') or {}
corrected_body_parts=sorted({face['source_owner'] for face in partition.get('faces',[]) if face.get('reason')=='verified_projected_front_face_uv_geometry_signature'})
report.update({'camera_scale':(hi[2]-lo[2])*1.15,'camera_center':[(lo[0]+hi[0])/2,(lo[2]+hi[2])/2],'expected_import_assets':5,'body_reimport_required':bool(corrected_body_parts),'body_parts_reimport_required':corrected_body_parts,'restored_original_head_faces':partition.get('projected_head_faces_restored',0),'headbase_is_primary_part':'rename HeadBase to Head; preserve existing Head CFrame and Motor6D','expression_face_attachment':'FaceExpression welds to existing Head, with imported relative transform preserved'})
report.update({'embedded_source_texture_bytes_preserved':True,'embedded_texture_sha256':texture_checks,'front_preview_camera_angle':180})
report['retained_existing_head_auxiliary_meshes']=retained_head_auxiliary
report['assembly_requirements']=prepare_meta.get('reviewed_profile',{}).get('assembly_requirements',{})
report['excluded_expression_faces']=excluded_expression_faces
report.update({'fixed_to_rig_affine':[list(row) for row in fixed_to_rig], 'coordinate_mapping_matched_corners':len(sample_x), 'coordinate_mapping_residual_max':float(residual.max()), 'coordinate_mapping_residual_mean':float(residual.mean()), 'source_fixed_sha256':fixed_sha, 'source_fixed_unchanged':hashlib.sha256(fixed_source.read_bytes()).hexdigest()==fixed_sha})
report['head_replacement_scope']='Replace existing primary HeadMat Head only; retain all listed original Head auxiliary BodyMat pieces and their UV/material/head welds'
front_direction=(to_blender@coordinate@fixed_to_rig).to_3x3()@__import__('mathutils').Vector((0,-1,0))
front_up=(to_blender@coordinate@fixed_to_rig).to_3x3()@__import__('mathutils').Vector((0,0,1))
front_direction.normalize();front_up.normalize()
report['camera_front_direction']=list(front_direction)
report['camera_front_up']=list(front_up)
report['camera_target']=[(lo[i]+hi[i])/2 for i in range(3)]
projected_height=max(point.dot(front_up) for point in points)-min(point.dot(front_up) for point in points)
report['source_front_camera_scale']=projected_height*1.15
report['source_front_yaw_degrees']=math.degrees(math.atan2(front_direction.x,-front_direction.y))
report['source_up_tilt_degrees']=math.degrees(math.acos(max(-1,min(1,front_up.z))))
report['source_front_differs_from_standard_r15_view']=abs(((report['source_front_yaw_degrees']-180+180)%360)-180)>5 or report['source_up_tilt_degrees']>5
output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('[align_r15_head] '+json.dumps(report),flush=True)
