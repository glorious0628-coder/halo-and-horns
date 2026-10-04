"""Blender: preserve R1 GLB bytes, make B0 material fix and measured B0+H geometry."""
import copy
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/costume_r15'))
from glb_io import read_glb, write_glb, accessor_values

R2 = ROOT / 'art/models/costume/redraw/r2'
RAW = ROOT / 'art/models/costume/raw/r2'
SOURCE = ROOT / 'art/models/costume/redraw/generation-c22df695/model.glb'


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')


def add_accessor(g, binary, values, kind, component=5126, target=34962):
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[kind]
    array = np.asarray(values, dtype='<f4' if component == 5126 else '<u4').reshape(-1, width)
    binary += b'\0' * (-len(binary) % 4)
    offset = len(binary)
    binary += array.tobytes()
    view = len(g['bufferViews'])
    g['bufferViews'].append({'buffer': 0, 'byteOffset': offset, 'byteLength': array.nbytes, 'target': target})
    index = len(g['accessors'])
    ac = {'bufferView': view, 'componentType': component, 'count': len(array), 'type': kind}
    if kind == 'VEC3':
        ac['min'], ac['max'] = array.min(0).tolist(), array.max(0).tolist()
    g['accessors'].append(ac)
    g['buffers'][0]['byteLength'] = len(binary)
    return index, binary


def srgb_linear(value):
    value /= 255
    return value / 12.92 if value <= .04045 else ((value + .055) / 1.055) ** 2.4


def main():
    params = json.loads((R2 / 'eval/source_regions.json').read_text(encoding='utf-8'))
    g, binary, original = read_glb(SOURCE)
    before = copy.deepcopy(g)
    for material in g['materials']:
        pbr = material.setdefault('pbrMetallicRoughness', {})
        pbr.pop('metallicRoughnessTexture', None)
        pbr.update(metallicFactor=0, roughnessFactor=.8)
    b0 = RAW / 'B0/model.glb'
    b0.parent.mkdir(parents=True, exist_ok=True)
    write_glb(b0, g, binary)
    assert read_glb(b0)[1] == binary
    p = g['meshes'][0]['primitives'][0]
    positions = np.asarray(accessor_values(g, binary, p['attributes']['POSITION']))
    faces = np.asarray(accessor_values(g, binary, p['indices'])).reshape(-1, 3)
    # Position-only connectivity joins UV seams for diagnosis; original vertices are untouched.
    keys, unique = {}, []
    inverse = []
    for v in positions:
        key = tuple(round(float(x), 6) for x in v)
        if key not in keys: keys[key] = len(unique); unique.append(v)
        inverse.append(keys[key])
    inverse = np.asarray(inverse)
    parent = list(range(len(unique)))
    def find(x):
        while parent[x] != x: parent[x] = parent[parent[x]]; x = parent[x]
        return x
    for a,b,c in inverse[faces]:
        parent[find(int(b))] = find(int(a)); parent[find(int(c))] = find(int(a))
    labels = np.asarray([find(int(x)) for x in inverse])
    components = []
    for label in sorted(set(labels)):
        points = positions[labels == label]
        ids = np.where(labels[faces[:,0]] == label)[0]
        components.append({'id': int(label), 'faces': ids, 'min': points.min(0), 'max': points.max(0)})
    # This source has exactly two connected surfaces: character and detached ring+star.
    assert len(components) == 2, 'Unexpected topology: manually review halo segmentation'
    halo = min(components, key=lambda x: len(x['faces']))
    body = max(components, key=lambda x: len(x['faces']))
    assert len(halo['faces']) == 288 and halo['min'][1] > .38
    keep = np.ones(len(faces), bool); keep[halo['faces']] = False
    assert len(body['faces']) == 17421
    ahoge, sole = float(body['max'][1]), float(body['min'][1])
    pixels_per_unit = (params['landmarks']['sole_y'] - params['landmarks']['ahoge_y']) / (ahoge - sole)
    def height(y): return sole + (params['landmarks']['sole_y'] - y) / pixels_per_unit
    ring = params['halo_geometry_pixels']
    tube = ring['tube_diameter'] / (2 * pixels_per_unit)
    radius = ring['outer_width'] / (2 * pixels_per_unit) - tube
    center_x = float((halo['min'][0] + halo['max'][0]) / 2)
    center_z = 0.0  # Source body axis, also used by the comparison renderer.
    ring_y = height(ring['center_y'])
    color = [srgb_linear(x) for x in params['gold_mean_rgb']]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.mesh.primitive_torus_add(major_segments=64, minor_segments=6,
        major_radius=radius, minor_radius=tube, location=(center_x,-center_z,ring_y))
    ring_object = bpy.context.object
    ring_object.name = 'HaloRing'
    for poly in ring_object.data.polygons: poly.use_smooth = True
    # Four pointed, upright star: eight outline vertices and a faceted centre on each side.
    star_x = center_x + radius
    half_w = ring['star_width'] / (2 * pixels_per_unit)
    half_h = ring['star_height'] / (2 * pixels_per_unit)
    mid_y = height(ring['star_top_y'] + ring['star_height']/2)
    depth = 5 / pixels_per_unit
    outline = [(0,half_h),(.24*half_w,.22*half_h),(half_w,0),(.24*half_w,-.22*half_h),
               (0,-half_h),(-.24*half_w,-.22*half_h),(-half_w,0),(-.24*half_w,.22*half_h)]
    # Blender world horizontal is Y, vertical Z; the face points +X.
    vertices = [(star_x,-x,mid_y+y) for x,y in outline]
    vertices += [(star_x+depth,0,mid_y),(star_x-depth,0,mid_y)]
    triangles = []
    for i in range(8): triangles.extend([(8,i,(i+1)%8),(9,(i+1)%8,i)])
    mesh=bpy.data.meshes.new('HaloStar');mesh.from_pydata(vertices,[],triangles);mesh.update()
    star=bpy.data.objects.new('HaloStar',mesh);bpy.context.collection.objects.link(star)
    bpy.ops.object.select_all(action='DESELECT');ring_object.select_set(True);star.select_set(True)
    bpy.context.view_layer.objects.active=ring_object;bpy.ops.object.join()
    h=bpy.context.object;h.name='Halo'
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    h.data.calc_loop_triangles()
    points=[];normals=[];indices=[]
    for tri in h.data.loop_triangles:
        for loop_index in tri.loops:
            loop=h.data.loops[loop_index];co=h.data.vertices[loop.vertex_index].co
            normal=h.data.corner_normals[loop_index].vector
            # Blender (x,y,z) -> glTF (x,z,-y).
            points.append((co.x,co.z,-co.y));normals.append((normal.x,normal.z,-normal.y));indices.append(len(indices))
    assert len(indices)//3 <= 1000
    p['indices'], binary = add_accessor(g,binary,faces[keep].reshape(-1),'SCALAR',5125,34963)
    pos, binary = add_accessor(g,binary,points,'VEC3')
    norm,binary = add_accessor(g,binary,normals,'VEC3')
    ind,binary = add_accessor(g,binary,indices,'SCALAR',5125,34963)
    material=len(g['materials']);g['materials'].append({'name':'Halo_Gold_SourceMean',
       'pbrMetallicRoughness':{'baseColorFactor':color+[1], 'metallicFactor':0, 'roughnessFactor':.8},'doubleSided':False})
    mi=len(g['meshes']);g['meshes'].append({'name':'Halo','primitives':[{'attributes':{'POSITION':pos,'NORMAL':norm},'indices':ind,'material':material}]})
    ni=len(g['nodes']);g['nodes'].append({'name':'Halo','mesh':mi})
    g['scenes'][g.get('scene',0)]['nodes'].append(ni)
    output=RAW/'B0H/model.glb';output.parent.mkdir(parents=True,exist_ok=True)
    write_glb(output,g,binary)
    assert binary[:len(read_glb(SOURCE)[1])]==read_glb(SOURCE)[1], 'Original buffer bytes changed'
    common={'source':str(SOURCE.relative_to(ROOT)),'source_sha256':hashlib.sha256(original).hexdigest(),
       'original_binary_prefix_preserved':True,'original_attribute_accessors_preserved':True,
       'original_images_preserved':True,'normal_texture_preserved':True,'metallic_factor':0,'roughness_factor':.8,
       'ahoge_world_y':ahoge,'sole_world_y':sole,'pixels_per_unit':pixels_per_unit,
       'alignment_body_axis_gltf_z':center_z,'paid_calls':0,'roblox_uploads':0}
    save(R2/'B0/build.json',{**common,'model':str(b0.relative_to(ROOT)), 'sha256':hashlib.sha256(b0.read_bytes()).hexdigest(), 'triangles':len(faces)})
    save(R2/'B0H/build.json',{**common,'model':str(output.relative_to(ROOT)), 'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),
       'removed_original_halo_faces':halo['faces'].tolist(),'retained_original_triangles':int(keep.sum()),
       'new_halo_triangles':len(indices)//3,'halo_ring_plane_tilt_degrees':0,
       'halo_star_top_y':mid_y+half_h,'halo_ring_top_y':ring_y+tube,
       'halo_star_protrusion_model_units':mid_y+half_h-(ring_y+tube),
       'halo_geometry_pixels':ring,'halo_color_mean_srgb':params['gold_mean_rgb'],
       'no_rig_added_at_G2':True,'rigged_variant_requires_existing_R1_rig_after_selection':True})
    print('R2 B0/B0H built: 288 old halo triangles removed; new Halo triangles',len(indices)//3)


if __name__=='__main__':main()
