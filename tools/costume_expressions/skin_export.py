"""Add an expression skin primitive while retaining original skin bytes.

No Blender skin re-export, original vertex movement, raster edits, or uploads.
Only original front-face index membership, its projected UV, and new mouth-cover
vertices are added. All original skin/geometry/image buffer data stay intact.
"""
import argparse
import copy
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/costume_r15'))
from glb_io import read_glb, write_glb, accessor_values, image_bytes


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def closest_barycentric(p, a, b, c):
    ab, ac, ap = b-a, c-a, p-a
    d1, d2 = np.dot(ab, ap), np.dot(ac, ap)
    if d1 <= 0 and d2 <= 0: return np.array([1., 0, 0])
    bp = p-b
    d3, d4 = np.dot(ab, bp), np.dot(ac, bp)
    if d3 >= 0 and d4 <= d3: return np.array([0., 1, 0])
    vc = d1*d4-d3*d2
    if vc <= 0 and d1 >= 0 and d3 <= 0:
        v = d1/(d1-d3)
        return np.array([1-v, v, 0])
    cp = p-c
    d5, d6 = np.dot(ab, cp), np.dot(ac, cp)
    if d6 >= 0 and d5 <= d6: return np.array([0., 0, 1])
    vb = d5*d2-d1*d6
    if vb <= 0 and d2 >= 0 and d6 <= 0:
        w = d2/(d2-d6)
        return np.array([1-w, 0, w])
    va = d3*d6-d5*d4
    if va <= 0 and d4-d3 >= 0 and d5-d6 >= 0:
        w = (d4-d3)/((d4-d3)+(d5-d6))
        return np.array([0., 1-w, w])
    total = va+vb+vc
    if abs(total) < 1e-20: raise ValueError('Degenerate source facial skin triangle')
    v, w = vb/total, vc/total
    return np.array([1-v-w, v, w])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('prepare_report', type=Path)
    parser.add_argument('neutral_png', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    source, output = args.source.resolve(), args.output.resolve()
    if output.exists() or output.with_suffix('.json').exists():
        raise ValueError('Use a new versioned skin expression output')
    source_sha = sha(source)
    sidecar = json.loads(source.with_suffix('.skin.json').read_text(encoding='utf-8'))
    prep = json.loads(args.prepare_report.read_text(encoding='utf-8'))
    if sidecar['output_sha256'] != source_sha or sha(Path(sidecar['source'])) != prep['source_sha256']:
        raise ValueError('Original skin/fixed model checksums differ')
    if not prep['reviewed_profile'].get('facial_boundary_polygon'):
        raise ValueError('Skin expressions require a reviewed inner-face boundary')
    doc, original_binary, _ = read_glb(source)
    doc = copy.deepcopy(doc)
    if len(doc['meshes']) != 2 or len(doc['skins']) != 1 or len(doc['images']) != 2:
        raise ValueError('Original two-mesh, two-image continuous skin required')
    head_node_index = next(i for i, n in enumerate(doc['nodes']) if n.get('name') == 'CostumeSkinHead')
    head_node = doc['nodes'][head_node_index]
    if head_node.get('skin') != 0 or any(k in head_node for k in ['matrix', 'translation', 'rotation', 'scale']):
        raise ValueError('Identity original Head mesh node and common skin required')
    head_mesh = doc['meshes'][head_node['mesh']]
    if len(head_mesh['primitives']) != 1: raise ValueError('Single original Head material required')
    primitive = head_mesh['primitives'][0]
    attrs = primitive['attributes']
    if set(attrs) != {'POSITION', 'NORMAL', 'TEXCOORD_0', 'JOINTS_0', 'WEIGHTS_0'}:
        raise ValueError('Unexpected original skin attribute format')
    arrays = {k: np.asarray(accessor_values(doc, original_binary, v)) for k, v in attrs.items()}
    p, n, uv = arrays['POSITION'], arrays['NORMAL'], arrays['TEXCOORD_0']
    joints, weights = arrays['JOINTS_0'], arrays['WEIGHTS_0']
    triangles = np.asarray(accessor_values(doc, original_binary, primitive['indices']), dtype=np.uint32).reshape(-1, 3)
    requested = {tuple(sorted(tuple(value) for value in key)) for key in prep['original_facial_uv_signatures']}
    selected, retained, found = [], [], {}
    for triangle in triangles:
        # prepare_face_uv records Blender's bottom-origin V, while the untouched
        # source GLB uses glTF's top-origin V. Match only this exact convention.
        key = tuple(sorted((round(float(uv[i, 0]), 6), round(1-float(uv[i, 1]), 6)) for i in triangle))
        if key in requested:
            selected.append(triangle)
            found[key] = found.get(key, 0)+1
        else:
            retained.append(triangle)
    if set(found) != requested or any(v != 1 for v in found.values()):
        raise ValueError('Reviewed original facial UV triangles must match exactly once')
    selected, retained = np.asarray(selected, dtype=np.uint32), np.asarray(retained, dtype=np.uint32)
    if not len(selected) or not len(retained): raise ValueError('Original HeadBase/face partition is empty')
    cap_p = np.asarray(prep['mouth_cap_source_gltf_positions'], dtype=float)
    cap_n = np.asarray(prep['mouth_cap_source_normals'], dtype=float)
    cap_uv = np.asarray(prep['mouth_cap_face_uv'], dtype=float)
    cap_tri = np.asarray(prep['mouth_cap_source_indices'], dtype=np.uint32)
    cap_j, cap_w, cap_distance = [], [], []
    for point in cap_p:
        choices = []
        for triangle in selected:
            vertices = p[triangle]
            bary = closest_barycentric(point, *vertices)
            distance = np.linalg.norm(point-bary@vertices)
            choices.append((distance, triangle, bary))
        distance, triangle, bary = min(choices, key=lambda row: row[0])
        combined = {}
        for index, fraction in zip(triangle, bary):
            for joint, weight in zip(joints[index], weights[index]):
                combined[int(joint)] = combined.get(int(joint), 0)+float(fraction*weight)
        active = sorted(((j, w) for j, w in combined.items() if w > 1e-10), key=lambda row: -row[1])
        if len(active) > 4: raise ValueError('Mouth cover requires more than four interpolated bone weights')
        active += [(0, 0)]*(4-len(active))
        total = sum(w for j, w in active)
        if total <= 0: raise ValueError('Mouth cover has no source skin influence')
        cap_j.append([j for j, w in active]);cap_w.append([w/total for j, w in active]);cap_distance.append(float(distance))
    cx, cy = prep['camera_center'];scale = prep['camera_scale']
    projected_uv = np.column_stack(((p[:, 0]-cx)/scale+.5, 1-((p[:, 1]-cy)/scale+.5)))
    cap_uv[:, 1] = 1-cap_uv[:, 1]
    face_arrays = {'POSITION': np.vstack((p, cap_p)), 'NORMAL': np.vstack((n, cap_n)),
        'TEXCOORD_0': np.vstack((projected_uv, cap_uv)), 'JOINTS_0': np.vstack((joints, cap_j)),
        'WEIGHTS_0': np.vstack((weights, cap_w))}
    binary = bytearray(original_binary)
    def append_view(content, target=None):
        binary.extend(b'\0'*(-len(binary)%4));offset=len(binary);binary.extend(content)
        view={'buffer':0,'byteOffset':offset,'byteLength':len(content)}
        if target:view['target']=target
        doc['bufferViews'].append(view);return len(doc['bufferViews'])-1
    def append_accessor(values, component, kind, target, bounds=False):
        dtype={5121:np.uint8,5123:np.dtype('<u2'),5125:np.dtype('<u4'),5126:np.dtype('<f4')}[component]
        values=np.asarray(values,dtype=dtype)
        count=values.size if kind=='SCALAR' else len(values)
        accessor={'bufferView':append_view(values.tobytes(),target),'componentType':component,'count':count,'type':kind}
        if bounds:accessor.update(min=values.min(axis=0).tolist(),max=values.max(axis=0).tolist())
        doc['accessors'].append(accessor);return len(doc['accessors'])-1
    primitive['indices']=append_accessor(retained.flatten(),5125,'SCALAR',34963)
    head_mesh['name']='HeadBase';head_node['name']='HeadBase'
    original_image_data=[image_bytes(doc,original_binary,image) for image in doc['images']]
    png=args.neutral_png.read_bytes()
    image_index=len(doc['images']);doc['images'].append({'bufferView':append_view(png),'mimeType':'image/png','name':'FaceExpression_Neutral'})
    texture_index=len(doc['textures']);doc['textures'].append({'source':image_index})
    material=copy.deepcopy(doc['materials'][primitive['material']]);material['name']='FaceExpressionMat'
    material['pbrMetallicRoughness']['baseColorTexture']={'index':texture_index,'texCoord':0}
    doc['materials'].append(material)
    face_attrs={}
    for key, values in face_arrays.items():
        old=doc['accessors'][attrs[key]];kind=old['type'];component=old['componentType']
        face_attrs[key]=append_accessor(values,component,kind,34962,key=='POSITION')
    face_indices=np.vstack((selected,cap_tri+len(p)))
    doc['meshes'].append({'name':'FaceExpression','primitives':[{'attributes':face_attrs,'indices':append_accessor(face_indices.flatten(),5125,'SCALAR',34963),'material':len(doc['materials'])-1,'mode':4}]})
    new_node=copy.deepcopy(head_node);new_node.update(name='FaceExpression',mesh=len(doc['meshes'])-1)
    face_node=len(doc['nodes']);doc['nodes'].append(new_node)
    parents=[node for node in doc['nodes'][:-1] if head_node_index in node.get('children',[])]
    if len(parents)!=1:raise ValueError('Original Head wrapper parent is not unique')
    parents[0]['children'].append(face_node)
    doc['buffers'][0]['byteLength']=len(binary)
    output.parent.mkdir(parents=True,exist_ok=True);write_glb(output,doc,bytes(binary))
    check,check_binary,_=read_glb(output)
    if check_binary[:len(original_binary)]!=original_binary or check['skins']!=read_glb(source)[0]['skins']:
        raise ValueError('Original geometry/skin buffer changed')
    if [image_bytes(check,check_binary,image) for image in check['images'][:2]]!=original_image_data:
        raise ValueError('Original non-facial texture bytes changed')
    for key in ['POSITION','NORMAL','JOINTS_0','WEIGHTS_0']:
        values=np.asarray(accessor_values(check,check_binary,face_attrs[key]))[:len(p)]
        if not np.array_equal(values,arrays[key]):raise ValueError('Original face attribute changed: '+key)
    if sha(source)!=source_sha:raise ValueError('Original skin candidate changed')
    frame=np.asarray(sidecar['source_to_game_affine'],float).reshape(4,4,order='F')
    target=frame@np.array([cx,cy,0,1])
    factor=float(np.linalg.norm(frame[:3,1]))
    report={'glb':str(output),'sha256':sha(output),'source_skin':str(source),'source_skin_sha256':source_sha,
        'source_fixed':sidecar['source'],'source_fixed_sha256':prep['source_sha256'],'rig_origin':'inferred_manual_candidate',
        'skin_joints_inverse_binds_preserved':True,'original_position_normal_joint_weight_values_preserved':True,
        'original_binary_prefix_preserved':True,'original_non_facial_texture_bytes_preserved':True,
        'original_body_primitive_unchanged':True,'original_headbase_uv_unchanged':True,
        'facial_signature_uv_convention':'Blender V = 1 - original glTF V; original UV bytes unchanged',
        'original_head_triangles':len(triangles),'original_face_triangles':len(selected),'headbase_triangles':len(retained),
        'new_mouth_cap_triangles':len(cap_tri),'new_mouth_cap_vertices':len(cap_p),'mouth_cap_weight_method':'closest original facial triangle barycentric interpolation, no original vertex edits',
        'mouth_cap_source_surface_distance_max':max(cap_distance),'source_to_game_affine':sidecar['source_to_game_affine'],
        'expected_glb_import_assets':7,'full_set_maximum_import_assets':9,'camera_scale':scale*factor,
        'camera_center':[float(target[0]),float(target[1])],'camera_target':[float(target[0]),float(-target[2]),float(target[1])],
        'source_front_camera_scale':scale*factor,'camera_front_direction':[0,1,0],'camera_front_up':[0,0,1],
        'ready':False,'runtime_validated':False,'roblox_uploaded':False,
        'limitations':['Inferred manual skeleton is not a genuine Tripo rig.','New mouth cover and 3-state face need actual engine pose/texture switching QA.','Original mouth recess is retained under the new skinned cover; original vertices are not flattened.']}
    output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k not in ['source_to_game_affine','limitations']}))


if __name__=='__main__':main()
