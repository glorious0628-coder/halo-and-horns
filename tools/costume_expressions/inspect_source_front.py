# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Render an unchanged fixed GLB in the face UV chart's exact source frame."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import hashlib
import json
import math
import sys
from pathlib import Path
import bpy

args=sys.argv[sys.argv.index('--')+1:]
source=Path(args[0]).resolve();output=Path(args[1]).resolve()
crop=float(args[2]) if len(args)>2 else .58
source_sha=hashlib.sha256(source.read_bytes()).hexdigest()
output.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
points=[obj.matrix_world@vertex.co for obj in bpy.context.scene.objects if obj.type=='MESH' for vertex in obj.data.vertices]
lo=min(p.z for p in points);hi=max(p.z for p in points)
z0=lo+crop*(hi-lo);scale=(hi-z0)*1.15
cx=(min(p.x for p in points)+max(p.x for p in points))/2;cz=(z0+hi)/2
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH'
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.display.shading.light='FLAT';scene.display.shading.color_type='TEXTURE'
scene.display.shading.background_type='VIEWPORT';scene.display.shading.background_color=(.82,.82,.82)
scene.display.shading.show_shadows=False
camera_data=bpy.data.cameras.new('SourceInspection');camera_data.type='ORTHO';camera_data.ortho_scale=scale
camera=bpy.data.objects.new('SourceInspection',camera_data);scene.collection.objects.link(camera)
camera.location=(cx,-10,cz);camera.rotation_euler=(math.radians(90),0,0);scene.camera=camera
scene.render.resolution_x=scene.render.resolution_y=768;scene.render.resolution_percentage=100
scene.render.filepath=str(output);bpy.ops.render.render(write_still=True)
if hashlib.sha256(source.read_bytes()).hexdigest()!=source_sha:raise RuntimeError('Source changed')
meta={'source':str(source),'source_sha256':source_sha,'render':str(output),'camera_center':[cx,cz],'camera_scale':scale,'crop_start_fraction':crop,'source_unchanged':True,'geometry_uv_texture_unchanged':True,'pixel_editing':False}
output.with_suffix('.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8')
print(json.dumps(meta),flush=True)
