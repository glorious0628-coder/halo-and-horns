# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Render prepared GLB with an expression PNG referenced by FaceExpressionMat.

No UV changes, geometry changes, PNG edits, or source file writes.
"""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy

args=sys.argv[sys.argv.index('--')+1:]
lit='--lit' in args
if lit:args.remove('--lit')
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
    if 'proxy_rotation_degrees' in requested:
        import numpy as np
        from mathutils import Matrix
        sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'costume_r15'))
        from render_manual_motion import TO_BLENDER
        sidecar_path=Path(requested['original_skin_sidecar']).resolve()
        if hashlib.sha256(sidecar_path.read_bytes()).hexdigest()!=requested['original_skin_sidecar_sha256']:
            raise RuntimeError('Original shared-skin contract changed')
        skin_sidecar=json.loads(sidecar_path.read_text(encoding='utf-8'))
        plan_path=Path(skin_sidecar['proxy_plan']).resolve()
        if hashlib.sha256(plan_path.read_bytes()).hexdigest()!=skin_sidecar['proxy_plan_sha256']:
            raise RuntimeError('Exact original proxy joint plan changed')
        plan=json.loads(plan_path.read_text(encoding='utf-8'))
        degrees=requested['proxy_rotation_degrees']
        allowed={'UpperTorso','Head','LeftUpperArm','RightUpperArm','LeftLowerArm','RightLowerArm','LeftHand','RightHand'}
        if not set(degrees).issubset(allowed) or any(len(v)!=3 or any(not math.isfinite(x) or abs(x)>180 for x in v) for v in degrees.values()):
            raise RuntimeError('Explicit existing Fx joint-angle sample required')
        runtime_path=Path(requested['proxy_runtime']).resolve()
        if hashlib.sha256(runtime_path.read_bytes()).hexdigest()!=requested['proxy_runtime_sha256']:
            raise RuntimeError('Exact source proxy part-bind runtime changed')
        runtime=json.loads(runtime_path.read_text(encoding='utf-8'))
        if runtime['proxy_plan_sha256']!=skin_sidecar['proxy_plan_sha256']:
            raise RuntimeError('Proxy part-bind runtime belongs to another rig')
        def cf(values):
            result=np.eye(4);result[:3,3]=values[:3];result[:3,:3]=np.asarray(values[3:]).reshape(3,3)
            return result
        root_bind=np.eye(4)
        root_bind[:3,3]=runtime['root']['center']
        binds={'HumanoidRootPart':root_bind}
        binds.update({part['name']:cf(part['cframe']) for part in runtime['parts']})
        current={'HumanoidRootPart':root_bind.copy()}
        bind_error=0.
        for joint in runtime['joints']:
            part0,part1=joint['part0'],joint['part1']
            c0,c1=cf(joint['C0']),cf(joint['C1'])
            bind_error=max(bind_error,float(np.max(np.abs(binds[part0]@c0@np.linalg.inv(c1)-binds[part1]))))
            rotation=Matrix.Identity(4)
            for axis,angle in zip(('X','Y','Z'),degrees.get(part1,[0,0,0])):
                rotation=rotation@Matrix.Rotation(math.radians(angle),4,axis)
            current[part1]=current[part0]@c0@np.asarray(rotation,dtype=np.float64)@np.linalg.inv(c1)
        if bind_error>1e-5:raise RuntimeError('Exact proxy C0/C1 does not reproduce actual part bind frames')
        deltas={name:current[name]@np.linalg.inv(bind) for name,bind in binds.items()}
        mapping={bone['name']:bone['proxy_part'] for bone in skin_sidecar['bones']}
        if set(skeleton.data.bones.keys())!=set(mapping):raise RuntimeError('Original source bones changed')
        arm_to_game=np.asarray(TO_BLENDER.inverted()@skeleton.matrix_world,dtype=np.float64)
        game_to_arm=np.linalg.inv(arm_to_game)
        rest={bone.name:np.asarray(bone.matrix_local,dtype=np.float64) for bone in skeleton.data.bones}
        desired={name:game_to_arm@np.asarray(deltas[part],dtype=np.float64)@arm_to_game@rest[name] for name,part in mapping.items()}
        for bone in skeleton.data.bones:
            if bone.parent:
                local=np.linalg.inv(rest[bone.parent.name])@rest[bone.name]
                posed_local=np.linalg.inv(desired[bone.parent.name])@desired[bone.name]
                basis=np.linalg.inv(local)@posed_local
            else:basis=np.linalg.inv(rest[bone.name])@desired[bone.name]
            skeleton.pose.bones[bone.name].matrix_basis=Matrix(basis.tolist())
        bpy.context.view_layer.update()
        error=max(float(np.max(np.abs(np.asarray(skeleton.pose.bones[name].matrix)-wanted))) for name,wanted in desired.items())
        if error>1e-4:raise RuntimeError('Actual shared Bone channels disagree with proxy delta')
        pose_report={'proxy_rotation_degrees':degrees,'pose_source':requested.get('pose_source'),
                     'maximum_proxy_part_bind_reproduction_error':bind_error,
                     'maximum_desired_bone_matrix_error':error,
                     'skin_pose_policy':'existing game Fx joint angles through exact original proxy world delta and all original shared bones; offline only; no source writes'}
    else:
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
for material in ([] if lit else bpy.data.materials):
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
if lit:
    world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.25
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
if lit:
    # Original material shading reveals mouth recesses hidden by emission QA.
    rotation=cam.rotation_euler.to_quaternion()
    right=rotation@Vector((1,0,0));up=rotation@Vector((0,1,0));backward=rotation@Vector((0,0,1))
    for name,side,height,energy in [('GeometryKey',-1.8,2.5,80),('GeometryFill',2.,.7,30)]:
        lamp_data=bpy.data.lights.new(name,'AREA');lamp_data.energy=energy;lamp_data.size=2.
        lamp=bpy.data.objects.new(name,lamp_data);scene.collection.objects.link(lamp)
        lamp.location=center+4*backward+side*right+height*up
        lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(output)
bpy.ops.render.render(write_still=True)
report={'source':str(source),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'expression':str(override) if override else None,'render':str(output),'angle':angle,'view_selector':view_selector,'camera_location':list(cam.location),'camera_rotation':list(cam.rotation_euler),'face_texture_size':list(face_tex.image.size) if face_tex else None,'source_unchanged':True,'shading_policy':'original imported material with geometry QA area lights' if lit else 'flat emission texture colors'}
report.update(context_report)
report.update(pose_report)
output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('[render_expression] '+json.dumps(report),flush=True)
