# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Read-only three-view lit full-body QA of the exact imported skin candidate.

Blender --background --python ... -- candidate.glb new-output-directory
Uses the recorded original source front; never edits GLB, UV or raster pixels.
"""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

args = sys.argv[sys.argv.index('--') + 1:]
source, output = [Path(value).resolve() for value in args[:2]]
if output.exists():
    raise ValueError('Use a new full-body QA directory')
source_sha = hashlib.sha256(source.read_bytes()).hexdigest()
if len(args)==4 and args[2]=='--frame-reference':
    description=json.loads(Path(args[3]).read_text(encoding='utf-8'))
    if description['source_skin_sha256']!=source_sha or Path(description['source_skin']).resolve()!=source:
        raise ValueError('Frame reference must identify this exact original skin source')
elif len(args)==2:
    description = json.loads(source.with_suffix('.json').read_text(encoding='utf-8'))
    if description['sha256'] != source_sha:
        raise ValueError('Current exact candidate description required')
else:
    raise ValueError('Use candidate.glb new-directory [--frame-reference exact-expression-report.json]')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
bpy.context.view_layer.update()
points = [obj.matrix_world @ obj.data.vertices[index].co
          for obj in bpy.context.scene.objects if obj.type == 'MESH'
          for index in {vertex for face in obj.data.polygons for vertex in face.vertices}]
if not points:
    raise ValueError('Actual rendered mesh triangles required')
lower = Vector([min(point[i] for point in points) for i in range(3)])
upper = Vector([max(point[i] for point in points) for i in range(3)])
center = (lower + upper) / 2
direction = Vector(description['camera_front_direction']).normalized()
source_up = Vector(description['camera_front_up']).normalized()
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 8
scene.cycles.device = 'CPU'
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
world = bpy.data.worlds.new('FullBodyBackground')
world.use_nodes = True
world.node_tree.nodes.get('Background').inputs['Color'].default_value = (.82, .82, .82, 1)
world.node_tree.nodes.get('Background').inputs['Strength'].default_value = .35
scene.world = world
camera_data = bpy.data.cameras.new('FullBodyCam')
camera_data.type = 'ORTHO'
camera = bpy.data.objects.new('FullBodyCam', camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
scene.render.resolution_x = 768
scene.render.resolution_y = 1024
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
lamps = []
for name, energy, size in [('FullBodyKey', 220, 4), ('FullBodyFill', 100, 4)]:
    data = bpy.data.lights.new(name, 'AREA')
    data.energy, data.size = energy, size
    lamp = bpy.data.objects.new(name, data)
    scene.collection.objects.link(lamp)
    lamps.append(lamp)
output.mkdir(parents=True)
records = []
for view, angle in [('front', 0), ('back', 180), ('side', -90)]:
    backward = Quaternion(source_up, math.radians(angle)) @ direction
    right = source_up.cross(backward).normalized()
    up = backward.cross(right).normalized()
    width = max(right.dot(p-center) for p in points) - min(right.dot(p-center) for p in points)
    height = max(up.dot(p-center) for p in points) - min(up.dot(p-center) for p in points)
    camera_data.ortho_scale = max(height, width / .75) * 1.12
    camera.location = center + 15 * backward
    camera.rotation_euler = Matrix((right, up, backward)).transposed().to_euler()
    for lamp, side, elevation in zip(lamps, [-3., 3.], [3., 1.]):
        lamp.location = center + 6 * backward + side * right + elevation * up
        lamp.rotation_euler = (center-lamp.location).to_track_quat('-Z', 'Y').to_euler()
    image = output / (view + '.png')
    scene.render.filepath = str(image)
    bpy.ops.render.render(write_still=True)
    record = {'source': str(source), 'source_sha256': source_sha, 'view': view,
              'source_unchanged': True, 'geometry_uv_weights_png_edits': False,
              'camera_location': list(camera.location), 'camera_rotation': list(camera.rotation_euler),
              'camera_scale': camera_data.ortho_scale, 'render': str(image),
              'render_sha256': hashlib.sha256(image.read_bytes()).hexdigest(),
              'shading_policy': 'original imported material; full-body lit QA',
              'ready': False, 'studio_called': False}
    image.with_suffix('.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    records.append(record)
if hashlib.sha256(source.read_bytes()).hexdigest() != source_sha:
    raise AssertionError('Candidate changed during read-only rendering')
(output / 'full_body_qa.json').write_text(json.dumps({'records': records, 'personally_reviewed': False,
                                                       'source_unchanged': True, 'ready': False}, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'output': str(output), 'glb_sha256': source_sha, 'full_body_views': 3, 'ready': False}), flush=True)
