"""Read-only diagnostic mask of existing face partition and pixel ray provenance."""
import bpy,json,sys,hashlib
from pathlib import Path
from mathutils import Matrix,Vector,Euler,geometry
args=sys.argv[sys.argv.index('--')+1:]
source,out=map(Path,args[:2]);meta=json.loads(source.with_suffix('.json').read_text())
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(source.resolve()))
scene=bpy.context.scene
camdata=bpy.data.cameras.new('mask');camdata.type='ORTHO';camdata.ortho_scale=meta['source_front_camera_scale']
cam=bpy.data.objects.new('mask',camdata);scene.collection.objects.link(cam)
backward=Vector(meta['camera_front_direction']).normalized();up=Vector(meta['camera_front_up']).normalized();right=up.cross(backward).normalized();up=backward.cross(right).normalized()
cam.location=Vector(meta['camera_target'])+10*backward;cam.rotation_euler=Matrix((right,up,backward)).transposed().to_euler();scene.camera=cam
rotation=cam.rotation_euler.to_matrix();deps=bpy.context.evaluated_depsgraph_get()
traces=[]
for sx,sy in [[473,547],[490,559],[507,588],[480,606],[536,572],[458,533],[533,534],[317,578],[246,589],[407,552],[544,625],[220,610]]:
    origin=cam.location+rotation@Vector(((sx/768-.5)*camdata.ortho_scale,(.5-sy/768)*camdata.ortho_scale,0))
    hit,point,normal,index,obj,_=scene.ray_cast(deps,origin,rotation@Vector((0,0,-1)))
    if not hit:continue
    face=obj.data.polygons[index];mat=obj.data.materials[face.material_index];tex=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
    layer=obj.data.uv_layers.active
    uv=geometry.barycentric_transform(point,*(obj.matrix_world@obj.data.vertices[i].co for i in face.vertices),*(Vector((*layer.data[i].uv,0)) for i in face.loop_indices))
    traces.append({'render_pixel':[sx,sy],'material':mat.name,'mesh':obj.name,'face':index,'texture_pixel':[uv.x*tex.image.size[0],(1-uv.y)*tex.image.size[1]]})
for mat in bpy.data.materials:
    nodes=mat.node_tree.nodes;links=mat.node_tree.links;output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
    emission=nodes.new('ShaderNodeEmission');emission.inputs['Color'].default_value=((1,1,1,1) if mat.name.startswith('FaceExpression') else ((0,.3,0,1) if mat.name.startswith('HeadMat') else (.15,.15,.15,1)))
    links.new(emission.outputs[0],output.inputs['Surface'])
scene.render.engine='CYCLES';scene.cycles.samples=1;scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.render.resolution_x=scene.render.resolution_y=768;scene.render.resolution_percentage=100
scene.render.filepath=str(out.resolve());bpy.ops.render.render(write_still=True)
out.with_suffix('.json').write_text(json.dumps({'source':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'white':'FaceExpression','green':'HeadBase','traces':traces},indent=2)+'\n')
