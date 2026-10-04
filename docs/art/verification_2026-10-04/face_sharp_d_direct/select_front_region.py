"""Read-only raycast selection: visible original HeadBase faces in eye regions."""
import bpy,json,sys,colorsys
from pathlib import Path
from collections import defaultdict
from mathutils import Matrix,Vector,geometry
source,out=map(Path,sys.argv[sys.argv.index('--')+1:])
meta=json.loads(source.with_suffix('.json').read_text());bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(source.resolve()))
back=Vector(meta['camera_front_direction']).normalized();up=Vector(meta['camera_front_up']).normalized();right=up.cross(back).normalized();up=back.cross(right).normalized()
rotation=Matrix((right,up,back)).transposed();location=Vector(meta['camera_target'])+10*back;scale=meta['source_front_camera_scale']
deps=bpy.context.evaluated_depsgraph_get();samples=defaultdict(list)
for left,top,rightp,bottom in [[208,440,565,703]]:
 for sy in range(top,bottom,2):
  for sx in range(left,rightp,2):
   origin=location+rotation@Vector(((sx/768-.5)*scale,(.5-sy/768)*scale,0))
   hit,point,normal,index,obj,_=bpy.context.scene.ray_cast(deps,origin,rotation@Vector((0,0,-1)))
   if not hit or obj.name!='HeadBase':continue
   face=obj.data.polygons[index];mat=obj.data.materials[face.material_index];tex=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image);layer=obj.data.uv_layers.active
   uv=geometry.barycentric_transform(point,*(obj.matrix_world@obj.data.vertices[i].co for i in face.vertices),*(Vector((*layer.data[i].uv,0)) for i in face.loop_indices))
   w,h=tex.image.size;x=max(0,min(w-1,int(uv.x*w)));y=max(0,min(h-1,int(uv.y*h)));rgb=list(tex.image.pixels[(y*w+x)*4:(y*w+x)*4+3]);hsv=colorsys.rgb_to_hsv(*rgb)
   samples[index].append({'pixel':[sx,sy],'rgb':rgb,'hsv':hsv,'normal_dot_front':normal.dot(back)})
records=[]
for index,rows in samples.items():
 # RGB values are Blender's linear image samples. Golden hair is not selected.
 dark=sum(row['hsv'][2]<.42 for row in rows)
 neutral=sum(row['hsv'][1]<.23 for row in rows)
 records.append({'head_triangle_index':index,'sample_count':len(rows),'dark_count':dark,'neutral_count':neutral,'selected':(dark+neutral)/len(rows)>=.40,'samples':rows})
out.write_text(json.dumps({'source':str(source),'method':'visible ray hits only; dark/neutral source pixels identify old lash/eye triangles; conservative visual review required','records':records,'selected':sorted(r['head_triangle_index'] for r in records if r['selected'])},indent=2)+'\n')
print(json.dumps({'observed':len(records),'selected':sum(r['selected'] for r in records),'out':str(out)}))
