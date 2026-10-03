"""Render prepared GLB with an expression PNG referenced by FaceExpressionMat.

No UV changes, geometry changes, PNG edits, or source file writes.
"""
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy

args=sys.argv[sys.argv.index('--')+1:]
pose_file=None
if '--pose-json' in args:
    pose_index=args.index('--pose-json')
    if pose_index!=len(args)-2:raise RuntimeError('Pose option must be the final two arguments')
    pose_file=Path(args[pose_index+1]).resolve();args=args[:pose_index]
source=Path(args[0]).resolve();output=Path(args[1]).resolve()
override=Path(args[2]).resolve() if len(args)>2 and args[2]!='-' else None
view_selector=args[3] if len(args)>3 else '0'
angle=float(view_selector) if not view_selector.startswith('source-') else None
bpy.ops.wm.read_factory_settings(use_empty=True)
context_report={}
if len(args)>5:
    sys.path.insert(0,str(Path(__file__).resolve().parent))
    from r15_render_context import load_context
    context_report=load_context(args[5])
bpy.ops.import_scene.gltf(filepath=str(source))
pose_report={}
if pose_file:
    requested=json.loads(pose_file.read_text(encoding='utf-8'))
    if requested.get('source_sha256')!=hashlib.sha256(source.read_bytes()).hexdigest():
        raise RuntimeError('Pose QA source checksum differs')
    skeletons=[o for o in bpy.context.scene.objects if o.type=='ARMATURE']
    if len(skeletons)!=1:raise RuntimeError('Exactly the preserved shared skin skeleton is required')
    skeleton=skeletons[0]
    pose_data=requested.get('bone_local_euler_degrees',{})
    if set(pose_data)!={'Head'}:raise RuntimeError('This diagnostic only poses the original Head bone')
    for name,values in pose_data.items():
        if len(values)!=3 or any(abs(v)>35 for v in values):raise RuntimeError('Small explicit Head pose required')
        bone=skeleton.pose.bones.get(name)
        if not bone:raise RuntimeError('Preserved Head bone missing')
        bone.rotation_mode='XYZ';bone.rotation_euler=tuple(math.radians(v) for v in values)
    bpy.context.view_layer.update()
    pose_report={'skin_pose':pose_data,'skin_pose_policy':'temporary offline original shared Head bone rotation; no source writes'}
face_mat=next((mat for mat in bpy.data.materials if mat.name.startswith('FaceExpressionMat')),None)
face_tex=next((node for node in face_mat.node_tree.nodes if node.type=='TEX_IMAGE' and node.image),None) if face_mat else None
if override:
    if not face_tex:raise RuntimeError('Expression material missing')
    face_tex.image=bpy.data.images.load(str(override),check_existing=False)
    face_tex.image.colorspace_settings.name='sRGB'

# Flat emission preserves the original texture colors while supporting separate
# material UV maps, unlike workbench's single active UV selection.
for material in bpy.data.materials:
    if not material.use_nodes:continue
    nodes=material.node_tree.nodes;links=material.node_tree.links
    bsdf=next((node for node in nodes if node.type=='BSDF_PRINCIPLED'),None)
    out=next((node for node in nodes if node.type=='OUTPUT_MATERIAL'),None)
    if not bsdf or not out:continue
    emit=nodes.new('ShaderNodeEmission')
    base_links=list(bsdf.inputs['Base Color'].links)
    if base_links:links.new(base_links[0].from_socket,emit.inputs['Color'])
    else:emit.inputs['Color'].default_value=bsdf.inputs['Base Color'].default_value
    links.new(emit.outputs['Emission'],out.inputs['Surface'])

pts=[o.matrix_world@v.co for o in bpy.context.scene.objects if o.type=='MESH' for v in o.data.vertices]
zmin,zmax=min(p.z for p in pts),max(p.z for p in pts)
xmin,xmax=min(p.x for p in pts),max(p.x for p in pts)
z0=zmin+.58*(zmax-zmin)
cx,cz=(xmin+xmax)/2,(z0+zmax)/2
ortho_scale=(zmax-z0)*1.15
if len(args)>4:
    camera_report=json.loads(Path(args[4]).read_text(encoding='utf-8'))
    cx,cz=camera_report['camera_center'];ortho_scale=camera_report['camera_scale']
scene=bpy.context.scene;scene.render.engine='CYCLES'
scene.cycles.samples=8;scene.cycles.device='CPU'
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.view_settings.exposure=0;scene.view_settings.gamma=1
world=bpy.data.worlds.new('Background');world.use_nodes=True
world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.82,.82,.82,1)
scene.world=world
cam_data=bpy.data.cameras.new('Cam');cam_data.type='ORTHO'
cam=bpy.data.objects.new('Cam',cam_data);scene.collection.objects.link(cam)
cam_data.ortho_scale=ortho_scale
from mathutils import Vector
center=Vector((cx,0,cz))
if view_selector.startswith('source-'):
    from mathutils import Quaternion,Matrix
    center=Vector(camera_report['camera_target'])
    cam_data.ortho_scale=camera_report['source_front_camera_scale']
    direction=Vector(camera_report['camera_front_direction'])
    up=Vector(camera_report['camera_front_up'])
    if view_selector=='source-quarter':direction=Quaternion(up,math.radians(-30))@direction
    elif view_selector!='source-front':raise RuntimeError('Unknown source camera view')
    backward=direction.normalized();right=up.cross(backward).normalized();true_up=backward.cross(right).normalized()
    cam.location=center+10*backward
    cam.rotation_euler=Matrix((right,true_up,backward)).transposed().to_euler()
else:
    cam.location=(cx+10*math.sin(math.radians(angle)),-10*math.cos(math.radians(angle)),cz)
    cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
scene.camera=cam;scene.render.resolution_x=scene.render.resolution_y=768
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(output)
bpy.ops.render.render(write_still=True)
report={'source':str(source),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'expression':str(override) if override else None,'render':str(output),'angle':angle,'view_selector':view_selector,'camera_location':list(cam.location),'camera_rotation':list(cam.rotation_euler),'face_texture_size':list(face_tex.image.size) if face_tex else None,'source_unchanged':True}
report.update(context_report)
report.update(pose_report)
output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('[render_expression] '+json.dumps(report),flush=True)
