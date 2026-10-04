"""Blender-only read-only model renders for existing monster and SharpD assets."""
from pathlib import Path
import hashlib
import json
import math
import sys
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/art/verification_2026-10-04/all_3d_eye_audit'
OUT.mkdir(parents=True,exist_ok=True)
models=[(n,ROOT/'art/models'/f'{n}.glb',0 if n=='Slime' else .45)
        for n in ['Slime','Goblin','GoblinBrute','Skeleton','SkeletonKnight','SkeletonKing','GoldenGoose']]
models += [(n,ROOT/'art/models/tripo'/f'{n}_raw.glb',.5) for n in ['SkeletonClothed','SkeletonKingClothed']]
models += [('SharpD_generation',ROOT/'art/models/costume/redraw/generation-c22df695/model.glb',.5),
           ('SharpD_rig',ROOT/'art/models/costume/redraw/tripo-out/costume-haloarcherm-sharpd-rig-96aa4858/model.glb',.5)]
rows=[]
for name,path,fraction in models:
    before=hashlib.sha256(path.read_bytes()).hexdigest()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    bpy.context.view_layer.update()
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    points=[]
    depsgraph=bpy.context.evaluated_depsgraph_get()
    for obj in meshes:
        evaluated=obj.evaluated_get(depsgraph)
        mesh=evaluated.to_mesh()
        referenced={index for polygon in mesh.polygons for index in polygon.vertices}
        points.extend(evaluated.matrix_world@mesh.vertices[index].co for index in referenced)
        evaluated.to_mesh_clear()
    low=[min(p[i] for p in points) for i in range(3)]
    high=[max(p[i] for p in points) for i in range(3)]
    scene=bpy.context.scene
    scene.render.engine='BLENDER_WORKBENCH'
    scene.display.shading.light='FLAT'
    scene.display.shading.color_type='TEXTURE'
    scene.display.shading.background_type='VIEWPORT'
    scene.display.shading.background_color=(.5,.5,.5)
    for obj in meshes:
        for material in obj.data.materials:
            if not material or not material.use_nodes:
                continue
            shader=next((n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
            if shader and shader.inputs['Base Color'].is_linked:
                node=shader.inputs['Base Color'].links[0].from_node
                if node.type=='TEX_IMAGE':
                    material.node_tree.nodes.active=node
    data=bpy.data.cameras.new('AuditCamera');data.type='ORTHO'
    cam=bpy.data.objects.new('AuditCamera',data);scene.collection.objects.link(cam)
    cam.rotation_euler=(math.pi/2,0,0);scene.camera=cam
    render_rows=[]
    x_front=name.startswith('SharpD') or name in ('SkeletonClothed','SkeletonKingClothed')
    for view,frac,resolution in [('full',0,640),('face',fraction,768)]:
        if name=='SharpD_rig' and view=='face':
            bpy.context.view_layer.update()
            depsgraph=bpy.context.evaluated_depsgraph_get()
            points=[]
            for obj in meshes:
                evaluated=obj.evaluated_get(depsgraph);mesh=evaluated.to_mesh()
                referenced={index for polygon in mesh.polygons for index in polygon.vertices}
                points.extend(evaluated.matrix_world@mesh.vertices[index].co for index in referenced)
                evaluated.to_mesh_clear()
            low=[min(p[i] for p in points) for i in range(3)]
            high=[max(p[i] for p in points) for i in range(3)]
        z0=low[2]+frac*(high[2]-low[2]);z1=high[2]
        # This rig reports a larger bind-space box than its visibly deformed
        # surface. Use the observed rendered head region for the close camera;
        # preserve the full/bind-space render above as diagnostic evidence.
        if name=='SharpD_rig' and view=='face':
            z0,z1=.48,.99
        data.ortho_scale=max(z1-z0,(high[1 if x_front else 0]-low[1 if x_front else 0]) if frac==0 else 0)*1.12
        target_center=Vector(((low[0]+high[0])/2,(low[1]+high[1])/2,(z0+z1)/2))
        span=max(high[i]-low[i] for i in range(3))*4
        cam.location=target_center+Vector((span,0,0) if x_front else (0,-span,0))
        cam.rotation_euler=(target_center-cam.location).to_track_quat('-Z','Y').to_euler()
        scene.render.resolution_x=scene.render.resolution_y=resolution
        scene.render.resolution_percentage=100
        scene.render.image_settings.file_format='PNG'
        target=OUT/f'{name}_front_{view}_unlit.png'
        scene.render.filepath=str(target)
        bpy.ops.render.render(write_still=True)
        render_rows.append({'path':str(target.relative_to(ROOT)),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
                            'size':[resolution,resolution],'camera_location':list(cam.location),'orthographic_scale':data.ortho_scale,
                            'height_crop_fraction':frac,'z_frame_bounds':[z0,z1],
                            'framing_basis':'manually observed rendered head region; bind-space bounds differ' if name=='SharpD_rig' and view=='face' else 'evaluated referenced mesh bounds'})
    rows.append({'name':name,'source':str(path.relative_to(ROOT)),'source_sha256':before,
                 'source_unchanged':hashlib.sha256(path.read_bytes()).hexdigest()==before,
                 'bounds_blender':{'min':low,'max':high},'renders':render_rows})
    print('[eye_audit] completed '+name,flush=True)
(OUT/'monster_sharpd_render_manifest_v2.json').write_text(json.dumps({'rows':rows,'shading':'Workbench FLAT baseColor texture; no PBR reflection evaluation',
    'correction':'Initial axis-only renders are retained separately. v2 uses evaluated mesh bounds and visibly checked +X front for new Tripo sources.',
    'source_mutations':0,'studio_calls':0,'paid_calls':0},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
