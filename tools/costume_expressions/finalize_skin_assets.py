"""Validate exact preserved skin expressions and save their separate offline manifest.

No image edits, API, Studio, upload, registry promotion or original model writes.
Run finalization only after personally viewing all six generated CG previews.
"""
from __future__ import annotations

import argparse
from collections import Counter
import copy
import hashlib
import json
from pathlib import Path
import shutil
import struct
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/costume_r15'))
from glb_io import accessor_values, image_bytes, read_glb
from skin_frames import resolve, transform_cap, original_projection


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def relative(path):
    return Path(path).resolve().relative_to(ROOT).as_posix()


def png_size(path):
    data = Path(path).read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('PNG required')
    return list(struct.unpack_from('>II', data, 16))


def inspect(glb, prepared):
    report = json.loads(glb.with_suffix('.json').read_text(encoding='utf-8'))
    if report['sha256'] != sha(glb) or report['rig_origin'] not in ['inferred_manual_candidate', 'preserved_original_paid_skin_candidate', 'corrected_preserved_bind_skin_proxy_candidate']:
        raise ValueError('Current explicitly identified skin candidate is required')
    source = Path(report['source_skin'])
    if sha(source) != report['source_skin_sha256'] or sha(report['source_fixed']) != report['source_fixed_sha256']:
        raise ValueError('Original skin or fixed model changed')
    prep = json.loads(prepared.read_text(encoding='utf-8'))
    if prep['source_sha256'] != report['source_fixed_sha256']:
        raise ValueError('Reviewed original fixed source differs')
    sidecar = json.loads(source.with_suffix('.skin.json').read_text(encoding='utf-8'))
    frame, rig_origin, original_bones_claimed = resolve(prep, source, sidecar)
    if rig_origin != report['rig_origin']:
        raise ValueError('Source rig origin differs')
    original, original_bin, _ = read_glb(source)
    doc, binary, _ = read_glb(glb)
    if len(doc['meshes']) != 3 or len(doc['images']) != 3 or len(doc['skins']) != 1:
        raise ValueError('Exactly Body, HeadBase, FaceExpression and three embedded images required')
    if binary[:len(original_bin)] != original_bin or doc['skins'] != original['skins']:
        raise ValueError('Original binary prefix, joints or inverse-bind skin changed')
    joint_nodes = original['skins'][0]['joints']
    for index in joint_nodes:
        if doc['nodes'][index] != original['nodes'][index]:
            raise ValueError('Original inferred bone or hierarchy changed')
    if doc['meshes'][0] != original['meshes'][0]:
        raise ValueError('Original body primitive changed')
    if doc['materials'][:2] != original['materials'] or doc['textures'][:2] != original['textures']:
        raise ValueError('Original non-face material/texture changed')
    for a, b in zip(doc['images'][:2], original['images']):
        if a != b or image_bytes(doc, binary, a) != image_bytes(original, original_bin, b):
            raise ValueError('Original non-face PNG bytes changed')
    old = original['meshes'][1]['primitives'][0]
    head = doc['meshes'][1]['primitives'][0]
    face = doc['meshes'][2]['primitives'][0]
    material = doc['materials'][face['material']]
    if len(doc['materials']) != 3 or len(doc['textures']) != 3 or material['name'] != 'FaceExpressionMat' or material['pbrMetallicRoughness']['baseColorTexture'] != {'index': 2, 'texCoord': 0} or doc['textures'][2]['source'] != 2:
        raise ValueError('Face material must use only the exact new normalized-UV texture')
    if head['attributes'] != old['attributes'] or head['material'] != old['material']:
        raise ValueError('Original HeadBase UV/vertices/weights changed')
    def arr(d, b, pr, key):
        return np.asarray(accessor_values(d, b, pr['attributes'][key]))
    old_values = {key: arr(original, original_bin, old, key) for key in old['attributes']}
    count = len(old_values['POSITION'])
    original_only = report.get('original_triangles_only') is True
    expected_cap_vertices = 0 if original_only else 129
    expected_cap_faces = 0 if original_only else 224
    for key in ['POSITION', 'NORMAL', 'JOINTS_0', 'WEIGHTS_0']:
        values = arr(doc, binary, face, key)
        if len(values) != count + expected_cap_vertices or not np.array_equal(values[:count], old_values[key]):
            raise ValueError('Original facial attribute changed: ' + key)
    triangles = lambda d, b, pr: np.asarray(accessor_values(d, b, pr['indices']), int).reshape(-1, 3)
    original_tri = triangles(original, original_bin, old)
    head_tri, face_tri = triangles(doc, binary, head), triangles(doc, binary, face)
    selected = face_tri[np.all(face_tri < count, axis=1)]
    cap = face_tri[np.all(face_tri >= count, axis=1)]
    if len(selected) + len(cap) != len(face_tri) or len(cap) != expected_cap_faces:
        raise ValueError('Original/cap triangles are mixed or cap count differs')
    expected_cap = np.empty((0,3),dtype=int) if original_only else np.asarray(prep['mouth_cap_source_indices'])
    if not np.array_equal(cap-count, expected_cap):
        raise ValueError('Reviewed mouth cover triangle indices changed')
    cap_positions, cap_normals = transform_cap(prep, frame)
    if original_only:
        cap_positions, cap_normals = np.empty((0,3)),np.empty((0,3))
    for key, source_values in [('POSITION', cap_positions), ('NORMAL', cap_normals)]:
        if not np.array_equal(arr(doc, binary, face, key)[count:], np.asarray(source_values, dtype=np.float32)):
            raise ValueError('Reviewed cover attribute changed: ' + key)
    if Counter(map(tuple, original_tri)) != Counter(map(tuple, np.vstack((head_tri, selected)))):
        raise ValueError('Original oriented face partition is not exactly preserved')
    requested = {tuple(sorted(tuple(v) for v in row)) for row in prep['original_facial_uv_signatures']}
    uv = old_values['TEXCOORD_0']
    matched = [tuple(sorted((round(float(uv[i, 0]), 6), round(1-float(uv[i, 1]), 6)) for i in tri)) for tri in selected]
    if set(matched) != requested or len(matched) != len(requested):
        raise ValueError('New face is not exactly the reviewed original UV region')
    p = old_values['POSITION']
    expected_uv = original_projection(p, prep, frame)
    uv_error = float(np.max(np.abs(arr(doc, binary, face, 'TEXCOORD_0')[:count] - expected_uv)))
    if uv_error > 1e-6:
        raise ValueError('Normalized face UV projection changed')
    weights = arr(doc, binary, face, 'WEIGHTS_0')
    joints = arr(doc, binary, face, 'JOINTS_0')
    if np.min(weights) < 0 or np.max(np.abs(weights.sum(axis=1)-1)) > 2e-6 or np.max(joints) >= len(joint_nodes):
        raise ValueError('Invalid preserved or interpolated skin influence')
    old_node = next(n for n in original['nodes'] if n.get('name') == 'CostumeSkinHead')
    new_nodes = {n['name']: n for n in doc['nodes'] if 'mesh' in n}
    if set(new_nodes) != {'CostumeSkinBody', 'HeadBase', 'FaceExpression'}:
        raise ValueError('Unexpected skin mesh node names')
    for name in ['HeadBase', 'FaceExpression']:
        node = new_nodes[name]
        if node.get('skin') != old_node['skin'] or any(k in node for k in ['translation', 'rotation', 'scale', 'matrix']):
            raise ValueError('Face must retain the original identity mesh node/shared skin')
    result = {'validated': True, 'skin_sha256': sha(glb), 'source_models_unchanged': True,
              'original_non_facial_png_bytes_exact': True, 'original_body_primitive_exact': True,
              'original_headbase_uv_exact': True, 'original_face_position_normal_joint_weight_values_exact': True,
              'original_skin_inverse_bind_and_bone_hierarchy_exact': True,
              'original_oriented_triangles_partition_exact': True, 'reviewed_face_uv_signatures_exact': True,
              'normalized_face_uv_max_error': uv_error, 'original_head_triangles': len(original_tri),
              'selected_original_face_triangles': len(selected), 'new_mouth_cap_triangles': len(cap),
              'new_mouth_cap_vertices': expected_cap_vertices, 'original_triangles_only': original_only,
              'meshes': 3, 'embedded_images': 3,
              'maximum_import_assets': 9, 'rig_origin': rig_origin,
              'original_bones_claimed': original_bones_claimed, 'source_skin_bones': len(joint_nodes),
              'ready': False, 'runtime_validated': False, 'studio_called': False, 'paid_api_calls': 0}
    return result, report, doc, binary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('glb', type=Path)
    parser.add_argument('--prepare-report', type=Path, required=True)
    parser.add_argument('--reviewed', action='store_true', help='All six CG previews personally viewed')
    parser.add_argument('--validate-only', action='store_true')
    parser.add_argument('--preview-directory', default='previews')
    parser.add_argument('--manifest-name', default='skin_expressions_manifest.json')
    parser.add_argument('--validation-name', default='skin_validation.json')
    parser.add_argument('--prepare-name', help='Separate candidate preparation filename')
    args = parser.parse_args()
    glb = args.glb.resolve(); folder = glb.parent
    avatar = folder.name
    result, report, doc, binary = inspect(glb, args.prepare_report)
    if args.validate_only:
        print(json.dumps(result)); return
    if not args.reviewed:
        raise ValueError('Personally view all six CG previews before finalization')
    output_names = [args.manifest_name, args.validation_name]
    if args.prepare_name:
        output_names.append(args.prepare_name)
    if any(Path(name).name != name or not name.endswith('.json') for name in output_names):
        raise ValueError('Candidate output names must be JSON basenames')
    if len(set(output_names)) != len(output_names):
        raise ValueError('Candidate output names must be distinct')
    if any(folder.joinpath(name).exists() for name in output_names):
        raise ValueError('Refuse silent final candidate file replacement')
    records = []
    prep = json.loads(args.prepare_report.read_text(encoding='utf-8'))
    paid = result['original_bones_claimed']
    baseline_records = {}
    if paid:
        baseline = json.loads(Path(prep['reviewed_profile']['baseline_manifest']).read_text(encoding='utf-8'))
        baseline_records = {r['state']: r for r in baseline['records']}
    for state in ['Neutral', 'SoftSmile', 'Serious']:
        png = ROOT / baseline_records[state]['png'] if paid else folder / (avatar + '_Expression_' + state + '_face.png')
        meta_path = png.with_suffix('.json')
        meta = copy.deepcopy(baseline_records[state]) if paid else json.loads(meta_path.read_text(encoding='utf-8'))
        if sha(png) != meta['sha256'] or png_size(png) != meta['size'] or not meta['builtin_gpt_generated']:
            raise ValueError('GPT expression provenance differs')
        if state == 'Neutral' and image_bytes(doc, binary, doc['images'][2]) != png.read_bytes():
            raise ValueError('Embedded neutral texture differs')
        previews = []
        for view in ['front', 'quarter']:
            image = folder / args.preview_directory / (state + '_' + view + '.png')
            camera = json.loads(image.with_suffix('.json').read_text(encoding='utf-8'))
            if png_size(image) != [768, 768] or camera['source_sha256'] != sha(glb) or Path(camera['expression']).resolve() != png:
                raise ValueError('Actual CG preview belongs to another skin or texture')
            if camera['view_selector'] != 'source-' + view or camera.get('skin_pose'):
                raise ValueError('Baseline front/quarter previews required')
            previews.append(relative(image))
        meta.update(quality_status='offline full-skin front/quarter reviewed; actual engine pending',
                    closed_mouth_offline_render_verified=True, offline_previews=previews,
                    roblox_uploaded=False, runtime_validated=False)
        if not paid:
            meta_path.write_text(json.dumps(meta, indent=2) + '\n', encoding='utf-8')
        records.append(meta)
    prepare_destination = folder / (args.prepare_name or ('skin_prepare_report.json' if paid else 'prepare_report.json'))
    shutil.copy2(args.prepare_report, prepare_destination)
    manifest = {'schema': 1, 'avatar': avatar, 'pipeline': 'preserved_continuous_skin_expression',
                'skin_asset': relative(glb), 'skin_sha256': sha(glb), 'source_skin_sha256': report['source_skin_sha256'],
                'source_fixed_sha256': report['source_fixed_sha256'], 'rig_origin': result['rig_origin'],
                'original_bones_claimed': result['original_bones_claimed'], 'source_skin_bones': result['source_skin_bones'],
                'prepare_report': relative(prepare_destination),
                'validation_report': relative(folder / args.validation_name),
                'original_triangles_only': result['original_triangles_only'],
                'selected_original_face_triangles': result['selected_original_face_triangles'],
                'new_mouth_cap_vertices': result['new_mouth_cap_vertices'],
                'rigid_comparison_reference_preserved': paid,
                'ready': False, 'runtime_validated': False, 'roblox_uploaded': False,
                'approved_states': ['Neutral', 'SoftSmile', 'Serious'], 'approval_preview': 'art/out/Avatar_Expressions_Preview_A.png',
                'records': records, 'meshes': ['CostumeSkinBody', 'HeadBase', 'FaceExpression'],
                'glb_expected_import_assets': 7, 'full_set_maximum_import_assets': 9,
                'offline_visual_review': 'All six actual full-skin baseline CG previews personally reviewed; closed mouth and original eyes/hair/body preserved.',
                'offline_visual_notes': 'A small amount of source/GPT skin color faceting can appear in very close views; actual normal-distance engine QA remains.',
                'runtime_attachment': 'Preserve the actual shared Bone host and root skin weld; never weld FaceExpression directly to the moving Head proxy.',
                'runtime_registration': 'Production marker/actual imported Bone host and mesh asset ID proof must be added by the root after engine QA.',
                'limitations': report['limitations']}
    result.update(avatar=avatar, expression_pngs=3, offline_baseline_previews_checked=6)
    folder.joinpath(args.manifest_name).write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    folder.joinpath(args.validation_name).write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
