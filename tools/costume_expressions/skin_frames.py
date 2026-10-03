"""Read-only coordinate and approved-face proof for continuous expression copies."""
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/costume_r15'))
from glb_io import read_glb, accessor_values


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def resolve(prep, source, sidecar):
    proof = prep.get('preserved_skin_coordinate_proof')
    if not proof:
        if sha(sidecar['source']) != prep['source_sha256'] or not prep['reviewed_profile'].get('facial_boundary_polygon'):
            raise ValueError('Exact original manual skin and reviewed face boundary required')
        return np.eye(4), 'inferred_manual_candidate', False
    if proof['skin_sha256'] != sha(source) or proof['source_sidecar_sha256'] != sha(source.with_suffix('.skin.json')):
        raise ValueError('Paid skin coordinate proof belongs to another source')
    profile = prep['reviewed_profile']
    baseline_path = Path(profile['baseline_manifest'])
    manifest = json.loads(baseline_path.read_text(encoding='utf-8'))
    baseline = ROOT / manifest['head_asset']
    if not profile.get('approved_rigid_face_scope') or sha(baseline_path) != profile['baseline_manifest_sha256'] or sha(baseline) != proof['approved_baseline_head_sha256'] or manifest['head_sha256'] != sha(baseline):
        raise ValueError('Approved rigid face scope changed')
    if sidecar.get('source_skin_bones') != 23 or sha(prep['source']) != prep['source_sha256']:
        raise ValueError('Original paid bones or fixed source changed')
    frame = np.asarray(proof['fixed_to_skin_affine'], dtype=float)
    if frame.shape != (4, 4) or not np.isfinite(frame).all() or not np.allclose(frame[3], [0, 0, 0, 1], atol=1e-12) or np.linalg.det(frame[:3, :3]) <= 0:
        raise ValueError('Invalid proved fixed-to-skin affine')
    fixed, fixed_bin, _ = read_glb(prep['source'])
    skin, skin_bin, _ = read_glb(source)
    def read_head(doc, binary, name):
        node = next(n for n in doc['nodes'] if n.get('name') == name)
        if any(k in node for k in ['matrix', 'translation', 'rotation', 'scale']):
            raise ValueError('Original Head frame must remain identity')
        primitive = doc['meshes'][node['mesh']]['primitives'][0]
        attrs = primitive['attributes']
        return (np.asarray(accessor_values(doc, binary, attrs['POSITION'])),
                np.asarray(accessor_values(doc, binary, attrs['TEXCOORD_0'])),
                np.asarray(accessor_values(doc, binary, primitive['indices']), int).reshape(-1, 3))
    fp, fu, ft = read_head(fixed, fixed_bin, 'Head')
    sp, su, st = read_head(skin, skin_bin, 'CostumeSkinHead')
    key = lambda uv: tuple(sorted((round(float(u), 6), round(float(v), 6)) for u, v in uv))
    table = {key(fu[t]): t for t in ft}
    if len(table) != len(ft) or len(st) != len(ft):
        raise ValueError('Original complete Head UV correspondence required')
    seen = set(); max_error = 0.
    for tri in st:
        signature = key(su[tri])
        if signature in seen or signature not in table:
            raise ValueError('Original paid Head UV correspondence changed')
        seen.add(signature)
        corners = {(round(float(fu[i, 0]), 6), round(float(fu[i, 1]), 6)): fp[i] for i in table[signature]}
        for i in tri:
            point = corners[(round(float(su[i, 0]), 6), round(float(su[i, 1]), 6))]
            error = np.linalg.norm((frame @ np.array([*point, 1]))[:3]-sp[i])
            max_error = max(max_error, float(error))
    if max_error > 1e-5 or seen != set(table):
        raise ValueError('Paid fixed-to-skin full original corner proof failed')
    verify_union_extension(prep, source, sp, su, st, frame)
    return frame, 'preserved_original_paid_skin_candidate', True


def verify_union_extension(prep, source, positions, uv, triangles, frame):
    extension = prep.get('verified_original_face_union_extension')
    if not extension:
        return
    history = [*prep.get('previous_verified_union_extensions', []), extension]
    first = history[0]
    initial_path = Path(first['original_prepare_report'])
    if sha(initial_path) != first['original_prepare_report_sha256']:
        raise ValueError('Original union face preparation changed')
    initial = json.loads(initial_path.read_text(encoding='utf-8'))
    key = lambda row: tuple(sorted(tuple(v) for v in row))
    requested = {key(row) for row in initial['original_facial_uv_signatures']}
    cap, _ = transform_cap(prep, frame)
    cap_uv = original_projection(cap, prep, frame)
    lower, upper = cap_uv.min(axis=0), cap_uv.max(axis=0)
    for event in history:
        prior_path, trace_path = Path(event['original_prepare_report']), Path(event['ray_report'])
        if sha(prior_path) != event['original_prepare_report_sha256'] or sha(trace_path) != event['ray_report_sha256']:
            raise ValueError('Verified mouth extension source or ray report changed')
        if event['original_scope_triangles'] != len(requested):
            raise ValueError('Verified mouth extension chain is discontinuous')
        trace = json.loads(trace_path.read_text(encoding='utf-8'))
        candidate = Path(trace['source'])
        camera = Path(trace['camera'])
        if sha(candidate) != trace['source_sha256'] or sha(camera) != trace['camera_sha256']:
            raise ValueError('Original pixel-to-triangle evidence changed')
        ray_export = json.loads(candidate.with_suffix('.json').read_text(encoding='utf-8'))
        ray_skin = Path(ray_export['source_skin'])
        if sha(ray_skin) != trace['original_skin_sha256'] or not ray_export['original_triangles_only']:
            raise ValueError('Original ray skin source changed')
        ray_doc, ray_binary, _ = read_glb(ray_skin)
        ray_primitive = ray_doc['meshes'][1]['primitives'][0]
        ray_position = np.asarray(accessor_values(ray_doc, ray_binary, ray_primitive['attributes']['POSITION']))
        ray_uv = np.asarray(accessor_values(ray_doc, ray_binary, ray_primitive['attributes']['TEXCOORD_0']))
        ray_indices = np.asarray(accessor_values(ray_doc, ray_binary, ray_primitive['indices']), int).reshape(-1, 3)
        if not np.array_equal(ray_position, positions) or not np.array_equal(ray_uv, uv) or not np.array_equal(ray_indices, triangles):
            raise ValueError('Pixel-proven mouth does not match the current exact original geometry/UV')
        for added in event['added_original_mouth_triangles']:
            index = added['original_head_face_index']; tri = triangles[index]
            evidence = [p for p in trace['points'] if p.get('original_head_face_matches') == [index]
                        and p.get('mesh', '').startswith('HeadBase') and p.get('material', '').startswith('HeadMat')]
            if not evidence or added['original_vertex_indices'] != tri.tolist() or any(p['original_vertex_indices'] != tri.tolist() for p in evidence):
                raise ValueError('Missing uniquely traced exact original mouth triangle')
            projected = original_projection(positions[tri], prep, frame)
            if np.any(projected.mean(axis=0) < lower) or np.any(projected.mean(axis=0) > upper):
                raise ValueError('Extended triangle left the approved mouth footprint')
            signature = tuple(sorted((round(float(uv[i, 0]), 6), round(1-float(uv[i, 1]), 6)) for i in tri))
            if signature in requested:
                raise ValueError('Duplicate mouth scope extension')
            requested.add(signature)
    current = [key(row) for row in prep['original_facial_uv_signatures']]
    if len(current) != len(requested) or set(current) != requested:
        raise ValueError('Union face scope differs from approved scope plus verified mouth triangles')


def transform_cap(prep, frame):
    positions = np.asarray(prep['mouth_cap_source_gltf_positions'], float)
    normals = np.asarray(prep['mouth_cap_source_normals'], float)
    if prep.get('preserved_skin_coordinate_proof'):
        positions = (np.column_stack((positions, np.ones(len(positions)))) @ frame.T)[:, :3]
        normals = normals @ np.linalg.inv(frame[:3, :3])
        normals /= np.linalg.norm(normals, axis=1)[:, None]
    return positions, normals


def original_projection(positions, prep, frame):
    if prep.get('preserved_skin_coordinate_proof'):
        positions = (np.column_stack((positions, np.ones(len(positions)))) @ np.linalg.inv(frame).T)[:, :3]
    cx, cy = prep['camera_center']; scale = prep['camera_scale']
    return np.column_stack(((positions[:, 0]-cx)/scale+.5, 1-((positions[:, 1]-cy)/scale+.5)))
