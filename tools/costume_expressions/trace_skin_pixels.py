"""Read-only exact CG pixel-to-original-skin-triangle provenance.

Uses the recorded orthographic camera and current source SHA, without changing
textures, UVs, geometry, skin weights or either original/candidate model.
Run with Blender --background --python ... -- candidate.glb render.json
'[[x,y],...]' new_report.json.
"""
import hashlib
import json
from pathlib import Path
import sys
import struct

import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector, geometry

args = sys.argv[sys.argv.index('--') + 1:]
source, camera_path, output = Path(args[0]).resolve(), Path(args[1]).resolve(), Path(args[3]).resolve()
points = json.loads(args[2])
camera = json.loads(camera_path.read_text(encoding='utf-8'))
source_sha = hashlib.sha256(source.read_bytes()).hexdigest()
if output.exists() or camera['source_sha256'] != source_sha or camera.get('skin_pose') or camera.get('proxy_rotation_degrees'):
    raise RuntimeError('New report and exact baseline camera/source are required')
export = json.loads(source.with_suffix('.json').read_text(encoding='utf-8'))
original_path = Path(export['source_skin'])
if hashlib.sha256(original_path.read_bytes()).hexdigest() != export['source_skin_sha256']:
    raise RuntimeError('Original skin changed')
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'costume_r15'))
from glb_io import read_glb, accessor_values
original, binary, _ = read_glb(original_path)
primitive = original['meshes'][1]['primitives'][0]
original_uv = np.asarray(accessor_values(original, binary, primitive['attributes']['TEXCOORD_0']))
original_indices = np.asarray(accessor_values(original, binary, primitive['indices']), int).reshape(-1, 3)
def signature(row):
    return tuple(sorted((round(float(x), 6), round(float(y), 6)) for x, y in row))
source_by_uv = {}
for index, tri in enumerate(original_indices):
    source_by_uv.setdefault(signature(original_uv[tri]), []).append(index)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
bpy.context.view_layer.update()
deps = bpy.context.evaluated_depsgraph_get()
rotation = Euler(camera['camera_rotation'], 'XYZ').to_matrix()
location = Vector(camera['camera_location'])
scale = camera.get('camera_scale', export['source_front_camera_scale'])
render=Path(camera['render'])
with render.open('rb') as stream:
    header=stream.read(24)
if header[:8]!=b'\x89PNG\r\n\x1a\n':raise RuntimeError('Exact PNG camera frame required')
frame_width,frame_height=struct.unpack('>II',header[16:24])
traces = []
for x, y in points:
    origin = location + rotation @ Vector(((x/frame_width-.5)*scale*frame_width/frame_height, (.5-y/frame_height)*scale, 0))
    direction = rotation @ Vector((0, 0, -1))
    hit, point, normal, face_index, obj, _ = bpy.context.scene.ray_cast(deps, origin, direction)
    trace = {'pixel': [x, y], 'hit': hit}
    if hit:
        face = obj.data.polygons[face_index]
        if len(face.vertices) != 3:
            raise RuntimeError('Exact original triangle required')
        material = obj.data.materials[face.material_index]
        texture = next(n for n in material.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image)
        uv_layer = obj.data.uv_layers.active
        corners = [uv_layer.data[i].uv for i in face.loop_indices]
        tex_uv = geometry.barycentric_transform(point,
                    *(obj.matrix_world @ obj.data.vertices[i].co for i in face.vertices),
                    *(Vector((*uv, 0)) for uv in corners))
        width, height = texture.image.size
        tx, ty = max(0, min(width-1, int(tex_uv.x*width))), max(0, min(height-1, int(tex_uv.y*height)))
        rgba = list(texture.image.pixels[(ty*width+tx)*4:(ty*width+tx)*4+4])
        trace.update(mesh=obj.name, polygon_index=face_index, material=material.name,
                     world_point=list(point), uv=list(tex_uv[:2]), texture_rgba=rgba)
        if obj.name.startswith('HeadBase'):
            key = signature([(uv.x, 1-uv.y) for uv in corners])
            matches = source_by_uv.get(key, [])
            trace['original_head_face_matches'] = matches
            trace['original_gltf_uv'] = key
            if len(matches) == 1:
                trace['original_vertex_indices'] = original_indices[matches[0]].tolist()
    traces.append(trace)
if hashlib.sha256(source.read_bytes()).hexdigest() != source_sha:
    raise RuntimeError('Candidate source changed')
output.parent.mkdir(parents=True, exist_ok=True)
result = {'schema': 1, 'source': str(source), 'source_sha256': source_sha,
          'original_skin_sha256': export['source_skin_sha256'], 'camera': str(camera_path),
          'camera_sha256': hashlib.sha256(camera_path.read_bytes()).hexdigest(),
          'points': traces, 'source_unchanged': True, 'studio_called': False}
output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result), flush=True)
