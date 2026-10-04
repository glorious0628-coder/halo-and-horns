"""Trace actual visible diagnostic feature pixels to the original triangle and image."""
import bpy,json,sys
from pathlib import Path
from mathutils import Matrix,Vector,geometry
source,out=map(Path,sys.argv[sys.argv.index('--')+1:]);meta=json.loads(source.with_suffix('.json').read_text())
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(source.resolve()))
back=Vector(meta['camera_front_direction']).normalized();up=Vector(meta['camera_front_up']).normalized();right=up.cross(back).normalized();up=back.cross(right).normalized();rotation=Matrix((right,up,back)).transposed();location=Vector(meta['camera_target'])+10*back;scale=meta['source_front_camera_scale'];deps=bpy.context.evaluated_depsgraph_get();rows=[]
points=[[285,562],[325,587],[338,548],[350,562],[436,488],[301,515],[288,510],[289,550],[289,579],[482,550],[482,578],[383,650],[245,547],[319,571],[521,540],[440,500]]
for sx,sy in points:
 origin=location+rotation@Vector(((sx/768-.5)*scale,(.5-sy/768)*scale,0));hit,point,normal,index,obj,_=bpy.context.scene.ray_cast(deps,origin,rotation@Vector((0,0,-1)))
 if not hit:continue
 face=obj.data.polygons[index];mat=obj.data.materials[face.material_index];tex=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image);layer=obj.data.uv_layers.active;uv=geometry.barycentric_transform(point,*(obj.matrix_world@obj.data.vertices[i].co for i in face.vertices),*(Vector((*layer.data[i].uv,0)) for i in face.loop_indices))
 rows.append({'pixel':[sx,sy],'mesh':obj.name,'polygon':index,'texture_name':tex.image.name,'texture_pixel':[uv.x*tex.image.size[0],(1-uv.y)*tex.image.size[1]],'material':mat.name})
out.write_text(json.dumps({'source':str(source),'records':rows},indent=2)+'\n');print(json.dumps(rows))
