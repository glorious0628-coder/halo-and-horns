# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Export only new head base + expression face meshes with default Neutral PNG."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import hashlib
import json
import sys
from pathlib import Path
import bpy

args=sys.argv[sys.argv.index('--')+1:]
source=Path(args[0]).resolve();neutral=Path(args[1]).resolve();output=Path(args[2]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
face_mat=next(mat for mat in bpy.data.materials if mat.name.startswith('FaceExpressionMat'))
tex=next(node for node in face_mat.node_tree.nodes if node.type=='TEX_IMAGE' and node.image)
tex.image=bpy.data.images.load(str(neutral),check_existing=False)
head=next(obj for obj in bpy.context.scene.objects if obj.type=='MESH' and face_mat in list(obj.data.materials))
bpy.ops.object.select_all(action='DESELECT');head.select_set(True)
bpy.context.view_layer.objects.active=head
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.separate(type='MATERIAL');bpy.ops.object.mode_set(mode='OBJECT')
selected=[]
for obj in bpy.context.scene.objects:
    if obj.type!='MESH':continue
    used={obj.data.materials[face.material_index].name for face in obj.data.polygons}
    if any(name.startswith('FaceExpressionMat') for name in used):
        obj.name='FaceExpression';selected.append(obj)
    elif any(name.startswith('HeadMat') for name in used):
        obj.name='HeadBase';selected.append(obj)
if len(selected)!=2:raise RuntimeError('Expected two head meshes, got '+str(len(selected)))
for obj in selected:
    used_index=obj.data.polygons[0].material_index
    material=obj.data.materials[used_index]
    image_node=next(node for node in material.node_tree.nodes if node.type=='TEX_IMAGE' and node.image)
    vector_links=list(image_node.inputs['Vector'].links)
    uv_name=vector_links[0].from_node.uv_map if vector_links and vector_links[0].from_node.type=='UVMAP' else obj.data.uv_layers.active.name
    used_layer=obj.data.uv_layers.get(uv_name)
    if not used_layer:raise RuntimeError('Missing used UV layer '+uv_name)
    obj.data.uv_layers.active=used_layer
    for layer in list(obj.data.uv_layers):
        if layer!=used_layer:obj.data.uv_layers.remove(layer)
    used_layer.name='UVMap'
    for node in material.node_tree.nodes:
        if node.type=='UVMAP':node.uv_map='UVMap'
bpy.ops.object.select_all(action='DESELECT')
for obj in selected:obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_yup=True)
report={'prepared_source':str(source),'prepared_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'default_neutral_texture':str(neutral),'head_glb':str(output),'head_glb_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'mesh_count':2,'material_count':2,'expected_import_asset_max':5,'runtime_expression_part':'FaceExpression','runtime_expression_switch':'MeshPart.TextureID or existing SurfaceAppearance.ColorMap; only expression face part','original_body_import_needed':False,'records':[]}
for obj in selected:
    bounds=[obj.matrix_world@vertex.co for vertex in obj.data.vertices]
    report['records'].append({'name':obj.name,'vertices':len(obj.data.vertices),'faces':len(obj.data.polygons),'uv_layers':[layer.name for layer in obj.data.uv_layers],'used_materials':sorted({obj.data.materials[face.material_index].name for face in obj.data.polygons}),'bounds_min':[min(p[i] for p in bounds) for i in range(3)],'bounds_max':[max(p[i] for p in bounds) for i in range(3)]})
output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('[export_head] '+json.dumps(report),flush=True)
