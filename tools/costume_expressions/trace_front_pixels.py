# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Read geometric/material provenance of CG front-view pixels."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import json,sys
from pathlib import Path
import bpy
from mathutils import Vector,geometry
args=sys.argv[sys.argv.index('--')+1:]
head=Path(args[0]);camera=json.loads(head.with_suffix('.json').read_text(encoding='utf-8'));points=json.loads(args[1])
bpy.ops.wm.read_factory_settings(use_empty=True)
if len(args)>2:
 sys.path.insert(0,str(Path(__file__).resolve().parent))
 from r15_render_context import load_context
 load_context(args[2])
bpy.ops.import_scene.gltf(filepath=str(head.resolve()))
deps=bpy.context.evaluated_depsgraph_get();cx,cz=camera['camera_center'];scale=camera['camera_scale']
traces=[]
for sx,sy in points:
 origin=Vector((cx-(sx/768-.5)*scale,10,cz+(.5-sy/768)*scale))
 hit,point,normal,index,obj,_=bpy.context.scene.ray_cast(deps,origin,Vector((0,-1,0)))
 if not hit:print(json.dumps({'pixel':[sx,sy],'hit':False}));continue
 face=obj.data.polygons[index];mat=obj.data.materials[face.material_index];tex=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
 links=list(tex.inputs['Vector'].links);uvname=links[0].from_node.uv_map if links and links[0].from_node.type=='UVMAP' else obj.data.uv_layers.active.name
 layer=obj.data.uv_layers[uvname];uv=geometry.barycentric_transform(point,*(obj.matrix_world@obj.data.vertices[i].co for i in face.vertices),*(Vector((*layer.data[i].uv,0)) for i in face.loop_indices))
 image=tex.image;w,h=image.size;x=max(0,min(w-1,int(uv.x*w)));y=max(0,min(h-1,int(uv.y*h)))
 rgb=list(image.pixels[(y*w+x)*4:(y*w+x)*4+3])
 trace={'pixel':[sx,sy],'object':obj.name,'face':index,'material':mat.name,'uv':[uv.x,uv.y],'texture_pixel':[x,h-1-y],'texture_rgb':rgb}
 if mat.name.startswith('HeadMat'):trace['original_signature']=tuple(sorted((round(layer.data[i].uv.x,6),round(layer.data[i].uv.y,6)) for i in face.loop_indices))
 traces.append(trace)
meta=json.loads(head.with_name('prepare_report.json').read_text(encoding='utf-8'))
for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=meta['source'])
for obj in bpy.context.scene.objects:
 if obj.type!='MESH':continue
 for face in obj.data.polygons:
  if not obj.data.materials[face.material_index].name.startswith('HeadMat'):continue
  layer=obj.data.uv_layers.active
  key=tuple(sorted((round(layer.data[i].uv.x,6),round(layer.data[i].uv.y,6)) for i in face.loop_indices))
  for trace in traces:
   if trace.get('original_signature')==key:trace['original_fixed_face']=face.index
for trace in traces:print(json.dumps(trace),flush=True)
