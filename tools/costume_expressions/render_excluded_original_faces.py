# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Color exact excluded original triangles in temporary CG inspection renders.

Diagnostic materials only; no source, UV, geometry, or raster edits.
"""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:]
source, excluded_file, camera_file, output_dir = map(lambda s: Path(s).resolve(), args)
source_sha = hashlib.sha256(source.read_bytes()).hexdigest()
excluded = json.loads(excluded_file.read_text(encoding='utf-8'))
camera_frame = json.loads(camera_file.read_text(encoding='utf-8'))
if camera_frame['source_sha256'] != source_sha:
    raise RuntimeError('Original source camera checksum differs')
keys = {tuple(sorted(tuple(uv) for uv in row['original_uv_signature'])) for row in excluded['records']}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
debug = bpy.data.materials.new('QA_Exact_Original_Triangles')
debug.use_nodes = True
bsdf = debug.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Base Color'].default_value = (1, 0, 1, 1)
matched = []
for obj in bpy.context.scene.objects:
    if obj.type != 'MESH':
        continue
    uv = obj.data.uv_layers.active
    faces = []
    for face in obj.data.polygons:
        material = obj.data.materials[face.material_index]
        if not material.name.startswith('HeadMat'):
            continue
        key = tuple(sorted((round(uv.data[i].uv.x, 6), round(uv.data[i].uv.y, 6)) for i in face.loop_indices))
        if key in keys:
            faces.append(face)
            matched.append({'fixed_face': face.index, 'original_material': material.name, 'original_uv_signature': key, 'original_world_corners': [list(obj.matrix_world @ obj.data.vertices[i].co) for i in face.vertices]})
    if faces:
        obj.data.materials.append(debug)
        for face in faces:
            face.material_index = len(obj.data.materials) - 1
if len(matched) != len(keys):
    raise RuntimeError('Original fixed triangles did not match exactly once')
for material in bpy.data.materials:
    if not material.use_nodes:
        continue
    nodes, links = material.node_tree.nodes, material.node_tree.links
    shader = next((n for n in nodes if n.type == 'BSDF_PRINCIPLED'), None)
    output = next((n for n in nodes if n.type == 'OUTPUT_MATERIAL'), None)
    if not shader or not output:
        continue
    emission = nodes.new('ShaderNodeEmission')
    base = list(shader.inputs['Base Color'].links)
    if base:
        links.new(base[0].from_socket, emission.inputs['Color'])
    else:
        emission.inputs['Color'].default_value = shader.inputs['Base Color'].default_value
    links.new(emission.outputs['Emission'], output.inputs['Surface'])
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 8
scene.cycles.device = 'CPU'
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.world = bpy.data.worlds.new('QA_Background')
scene.world.use_nodes = True
scene.world.node_tree.nodes.get('Background').inputs['Color'].default_value = (.82, .82, .82, 1)
camera = bpy.data.objects.new('QA_Camera', bpy.data.cameras.new('QA_Camera'))
scene.collection.objects.link(camera)
camera.data.type = 'ORTHO'
camera.data.ortho_scale = camera_frame['camera_scale']
cx, cz = camera_frame['camera_center']
center = Vector((cx, 0, cz))
scene.camera = camera
scene.render.resolution_x = scene.render.resolution_y = 768
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
output_dir.mkdir(parents=True, exist_ok=True)
renders = []
for label, angle in [('front', 0), ('right_quarter', 45), ('right_side', 90), ('left_quarter', -45)]:
    camera.location = (cx + 10 * math.sin(math.radians(angle)), -10 * math.cos(math.radians(angle)), cz)
    camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
    target = output_dir / (label + '.png')
    scene.render.filepath = str(target)
    bpy.ops.render.render(write_still=True)
    renders.append(str(target))
if hashlib.sha256(source.read_bytes()).hexdigest() != source_sha:
    raise RuntimeError('Original model changed')
result = {'source': str(source), 'source_sha256': source_sha, 'excluded_report': str(excluded_file), 'matched_original_faces': matched, 'renders': renders, 'marker_color': 'magenta diagnostic face materials', 'original_source_unchanged': True, 'original_geometry_uv_unchanged': True, 'raster_editing': False, 'product_asset': False}
(output_dir / 'inspection.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result))
