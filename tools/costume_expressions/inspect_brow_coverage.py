"""Inspect source brow rays and prepared UV coverage without image mutations."""
import colorsys
import json
import sys
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector, geometry

args=sys.argv[sys.argv.index('--')+1:]
source,prepared,profile_file,output=map(Path,args)
meta=json.loads(prepared.with_name('prepare_report.json').read_text(encoding='utf-8'))
profile=json.loads(profile_file.read_text(encoding='utf-8'))
def sig(layer,face):
    return tuple(sorted((round(layer.data[i].uv.x,6),round(layer.data[i].uv.y,6)) for i in face.loop_indices))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(prepared.resolve()))
selected=set()
for obj in bpy.context.scene.objects:
    if obj.type!='MESH':continue
    headmat=next((m for m in obj.data.materials if m.name.startswith('HeadMat')),None)
    if not headmat:continue
    tex=next(n for n in headmat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
    links=list(tex.inputs['Vector'].links)
    original_uv_name=links[0].from_node.uv_map if links and links[0].from_node.type=='UVMAP' else obj.data.uv_layers.active.name
    layer=obj.data.uv_layers[original_uv_name]
    for face in obj.data.polygons:
        if obj.data.materials[face.material_index].name.startswith('FaceExpressionMat'):selected.add(sig(layer,face))
for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(source.resolve()))
head=next(o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.name.startswith('HeadMat') for m in o.data.materials))
mesh=head.data;layer=mesh.uv_layers.active
image=next(n.image for m in mesh.materials if m.name.startswith('HeadMat') for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
w,h=image.size;pixels=np.empty(w*h*4,dtype=np.float32);image.pixels.foreach_get(pixels);pixels=pixels.reshape(h,w,4)
scale=meta['camera_scale'];cx,cz=meta['camera_center'];deps=bpy.context.evaluated_depsgraph_get()
hits={}
for left,top,right,bottom in profile['brow_boxes']:
 for sy in range(top,bottom):
  for sx in range(left,right):
   result=bpy.context.scene.ray_cast(deps,Vector((cx+(sx/768-.5)*scale,-10,cz+(.5-sy/768)*scale)),Vector((0,1,0)))
   hit,point,normal,index,obj,_=result
   if not hit or obj!=head:continue
   face=mesh.polygons[index];points=[head.matrix_world@mesh.vertices[i].co for i in face.vertices]
   uv=geometry.barycentric_transform(point,*points,*(Vector((*layer.data[i].uv,0)) for i in face.loop_indices))
   xx=max(0,min(w-1,int(uv.x*w)));yy=max(0,min(h-1,int(uv.y*h)))
   rgb=pixels[yy,xx,:3];hh,ss,vv=colorsys.rgb_to_hsv(*rgb)
   if (.13<hh<.95) or vv>profile.get('brow_inspect_max_value',.65):continue
   key=sig(layer,face)
   if key in selected:continue
   if index not in hits:
    centroid=sum(points,Vector())/3
    hits[index]={'source_face':index,'original_uv_signature':key,'sample_screen':[sx,sy],'sample_hsv':[float(hh),float(ss),float(vv)],'normal_y':float(normal.y),'centroid_screen':[(centroid.x-cx)/scale*768+384,384-(centroid.z-cz)/scale*768],'ray_hits':0}
   hits[index]['ray_hits']+=1
report={'avatar':source.stem,'unselected_dark_brow_candidates':list(hits.values()),'candidate_faces':len(hits)}
output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report),flush=True)
