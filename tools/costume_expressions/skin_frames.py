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
    return frame, 'preserved_original_paid_skin_candidate', True


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
