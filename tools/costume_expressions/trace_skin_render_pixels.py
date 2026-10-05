# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Read exact GLB material/UV provenance of selected actual CG pixels; no edits."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import json
from pathlib import Path
import sys
import bpy
from mathutils import Euler, Vector, geometry

args = sys.argv[sys.argv.index('--')+1:]
source, render_report, output = map(Path, args[:3])
points = json.loads(args[3])
camera = json.loads(render_report.read_text(encoding='utf-8'))
meta = json.loads(source.with_suffix('.json').read_text(encoding='utf-8'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source.resolve()))
for mat in bpy.data.materials:
    if mat.name.startswith('FaceExpressionMat'):
        tex = next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
        tex.image = bpy.data.images.load(camera['expression'],check_existing=False)
rotation = Euler(camera['camera_rotation']).to_matrix()
location = Vector(camera['camera_location']);scale=meta['source_front_camera_scale']
deps=bpy.context.evaluated_depsgraph_get();traces=[]
for sx,sy in points:
    origin=location+rotation@Vector(((sx/768-.5)*scale,(.5-sy/768)*scale,0))
    hit,point,normal,index,obj,_=bpy.context.scene.ray_cast(deps,origin,rotation@Vector((0,0,-1)))
    if not hit:traces.append({'pixel':[sx,sy],'hit':False});continue
    face=obj.data.polygons[index];mat=obj.data.materials[face.material_index]
    tex=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
    links=list(tex.inputs['Vector'].links)
    name=links[0].from_node.uv_map if links and links[0].from_node.type=='UVMAP' else obj.data.uv_layers.active.name
    layer=obj.data.uv_layers[name]
    uv=geometry.barycentric_transform(point,*(obj.matrix_world@obj.data.vertices[i].co for i in face.vertices),*(Vector((*layer.data[i].uv,0)) for i in face.loop_indices))
    image=tex.image;w,h=image.size;x=max(0,min(w-1,int(uv.x*w)));y=max(0,min(h-1,int(uv.y*h)))
    row={'pixel':[sx,sy],'object':obj.name,'face':index,'material':mat.name,'uv':list(uv[:2]),'texture_pixel':[x,h-1-y],'texture_rgb':list(image.pixels[(y*w+x)*4:(y*w+x)*4+3]),'point':list(point)}
    if mat.name.startswith('HeadMat'):
        row['original_signature']=tuple(sorted((round(layer.data[i].uv.x,6),round(layer.data[i].uv.y,6)) for i in face.loop_indices))
    traces.append(row)
for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=meta['source_fixed'])
for obj in bpy.context.scene.objects:
    if obj.type!='MESH':continue
    for face in obj.data.polygons:
        if not obj.data.materials[face.material_index].name.startswith('HeadMat'):continue
        uv=obj.data.uv_layers.active
        key=tuple(sorted((round(uv.data[i].uv.x,6),round(uv.data[i].uv.y,6)) for i in face.loop_indices))
        for row in traces:
            if row.get('original_signature')==key:row['original_fixed_face']=face.index
output.write_text(json.dumps({'source':str(source),'render_report':str(render_report),'records':traces,'read_only':True},indent=2)+'\n')
print(json.dumps(traces))
