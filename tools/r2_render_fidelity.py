"""Blender-only orthographic Workbench and EEVEE R2 evaluation renders."""
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
R2=ROOT/'art/models/costume/redraw/r2'


def main():
    targets=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['B0','B0H']
    params=json.loads((R2/'eval/source_regions.json').read_text())
    for name in targets:
        spec=json.loads((R2/name/'build.json').read_text());path=ROOT/spec['model']
        out=R2/name/'eval';out.mkdir(parents=True,exist_ok=True)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(path))
        scene=bpy.context.scene
        scene.render.resolution_x=scene.render.resolution_y=1254
        scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
        scene.render.film_transparent=False
        scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
        scene.view_settings.exposure=0;scene.view_settings.gamma=1
        scene.world=bpy.data.worlds.new('R2 Studio Environment');scene.world.use_nodes=True
        nodes=scene.world.node_tree.nodes;nodes.clear();links=scene.world.node_tree.links
        output=nodes.new('ShaderNodeOutputWorld');env=nodes.new('ShaderNodeTexEnvironment')
        hdri=Path(bpy.app.binary_path).parent/'5.2/datafiles/studiolights/world/studio.exr'
        assert hdri.exists();env.image=bpy.data.images.load(str(hdri))
        light=nodes.new('ShaderNodeBackground');light.inputs['Strength'].default_value=1
        links.new(env.outputs['Color'],light.inputs['Color'])
        white=nodes.new('ShaderNodeBackground');white.inputs['Color'].default_value=(1,1,1,1)
        ray=nodes.new('ShaderNodeLightPath');mix=nodes.new('ShaderNodeMixShader')
        links.new(ray.outputs['Is Camera Ray'],mix.inputs[0]);links.new(light.outputs[0],mix.inputs[1]);links.new(white.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],output.inputs[0])
        for obj in scene.objects:
            if obj.type!='MESH':continue
            for mat in obj.data.materials:
                if not mat or not mat.use_nodes:continue
                shader=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
                if shader and shader.inputs['Base Color'].is_linked:
                    node=shader.inputs['Base Color'].links[0].from_node
                    if node.type=='TEX_IMAGE':mat.node_tree.nodes.active=node
                elif shader:
                    mat.diffuse_color=shader.inputs['Base Color'].default_value
        data=bpy.data.cameras.new('R2Ortho');data.type='ORTHO'
        cam=bpy.data.objects.new('R2Ortho',data);scene.collection.objects.link(cam);scene.camera=cam
        ppu=spec['pixels_per_unit'];scale=1254/ppu
        target=Vector((0,(627-params['landmarks']['body_center_x'])/ppu,
                       spec['sole_world_y']+(params['landmarks']['sole_y']-627)/ppu))
        rows=[]
        def render(label,yaw,engine,focus=None,ortho=None):
            scene.render.engine=engine
            focus=target if focus is None else focus
            data.ortho_scale=scale if ortho is None else ortho
            a=math.radians(yaw);cam.location=focus+Vector((3*math.cos(a),3*math.sin(a),0))
            cam.rotation_euler=(focus-cam.location).to_track_quat('-Z','Y').to_euler()
            if engine=='BLENDER_WORKBENCH':
                sh=scene.display.shading;sh.light='FLAT';sh.color_type='TEXTURE'
                sh.background_type='VIEWPORT';sh.background_color=(1,1,1)
                sh.show_shadows=False;sh.show_cavity=False;sh.show_specular_highlight=False
            dest=out/(label+'.png');scene.render.filepath=str(dest)
            bpy.ops.render.render(write_still=True)
            rows.append({'file':dest.name,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),
                         'engine':engine,'yaw_degrees':yaw,'orthographic_scale':data.ortho_scale,
                         'camera_position':list(cam.location),'focus':list(focus)})
        for yaw in (0,90,180,270):render(f'flat_yaw_{yaw}',yaw,'BLENDER_WORKBENCH')
        render('flat_quarter',30,'BLENDER_WORKBENCH')
        render('lit_front',0,'BLENDER_EEVEE')
        render('lit_quarter',30,'BLENDER_EEVEE')
        face_target=Vector((0,0,spec['sole_world_y']+(1203-305)/ppu))
        render('ear_plus60',60,'BLENDER_WORKBENCH',face_target,540/ppu)
        render('ear_minus60',-60,'BLENDER_WORKBENCH',face_target,540/ppu)
        report={'model':spec['model'],'source_sha256':spec['sha256'],'model_unchanged':hashlib.sha256(path.read_bytes()).hexdigest()==spec['sha256'],
          'alignment':{'method':'Same geometry scale from character-only ahoge/sole; no hand-width fitting',
                       'pixels_per_model_unit':ppu,'ahoge_source_y':71,'sole_source_y':1203,'body_axis_source_x':620,
                       'camera_target':list(target),'ortho_scale':scale,'resolution':[1254,1254]},
          'color_management':{'view':'Standard','look':'None','exposure':0,'gamma':1},
          'lit_environment':{'path':str(hdri),'strength':1,'sha256':hashlib.sha256(hdri.read_bytes()).hexdigest()},
          'material_changes_by_renderer':False,'renders':rows}
        (out/'render_manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
        print('R2 render completed',name,flush=True)


if __name__=='__main__':main()
