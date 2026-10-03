"""Reuse an approved rigid face UV/cover on the exact original paid skin.

Read-only original models. Exact original Head UV triangles prove fixed-to-skin
coordinates; the approved rigid face's normalized UV triangles select the same
facial region. Only its new 129-vertex cover is reconstructed. No image edits.
"""
import argparse
import hashlib
import itertools
import json
from pathlib import Path
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/costume_r15'))
from glb_io import accessor_values, read_glb


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def values(doc, binary, primitive, attribute):
    return np.asarray(accessor_values(doc, binary, primitive['attributes'][attribute]))


def primitive_named(doc, name):
    node = next(n for n in doc['nodes'] if n.get('name') == name)
    if any(k in node for k in ['matrix', 'rotation', 'scale']):
        raise ValueError('Unproved mesh transform: ' + name)
    mesh = doc['meshes'][node['mesh']]
    if len(mesh['primitives']) != 1:
        raise ValueError('Single exact material primitive required: ' + name)
    return mesh['primitives'][0], node


def uv_key(corners):
    return tuple(sorted((round(float(u), 6), round(float(v), 6)) for u, v in corners))


def prove_baseline_frame(doc, binary, fpos, fuv, original_by_uv):
    primitive, node = primitive_named(doc, 'HeadBase')
    positions = values(doc, binary, primitive, 'POSITION') + node.get('translation', [0, 0, 0])
    uv = values(doc, binary, primitive, 'TEXCOORD_0')
    triangles = np.asarray(accessor_values(doc, binary, primitive['indices']), int).reshape(-1, 3)
    xs, ys = [], []
    for tri in triangles:
        original_tri = original_by_uv[uv_key(uv[tri])]
        corners = {(round(float(fuv[i, 0]), 6), round(float(fuv[i, 1]), 6)): fpos[i] for i in original_tri}
        for i in tri:
            xs.append([*corners[(round(float(uv[i, 0]), 6), round(float(uv[i, 1]), 6))], 1]); ys.append(positions[i])
    xs, ys = np.asarray(xs), np.asarray(ys)
    mask = np.ones(len(xs), dtype=bool)
    for _ in range(4):
        coefficients = np.linalg.lstsq(xs[mask], ys[mask], rcond=None)[0]
        residual = np.linalg.norm(xs @ coefficients-ys, axis=1)
        if residual[mask].max() <= 1e-5:
            break
        mask = residual <= float(np.quantile(residual, .9))
    mask = residual <= 1e-5
    if mask.sum() < len(mask)*.95:
        raise ValueError('Rigid HeadBase lacks enough unchanged original geometry to prove its frame')
    coefficients = np.linalg.lstsq(xs[mask], ys[mask], rcond=None)[0]
    residual = np.linalg.norm(xs @ coefficients-ys, axis=1)
    if residual[mask].max() > 1e-5:
        raise ValueError('Unchanged rigid HeadBase coordinate proof failed')
    return np.vstack((coefficients.T, [0, 0, 0, 1])), residual, mask


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('skin', type=Path)
    parser.add_argument('baseline_manifest', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError('Use a new output report')
    skin = args.skin.resolve(); manifest_path = args.baseline_manifest.resolve()
    manifest = load(manifest_path); avatar = manifest['avatar']
    validation = load(manifest_path.with_name('validation.json'))
    baseline = ROOT / manifest['head_asset']; baseline_report = load(baseline.with_suffix('.json'))
    if not validation['validated'] or sha(baseline) != manifest['head_sha256'] or manifest['head_sha256'] != validation['head_sha256']:
        raise ValueError('Current approved rigid reference required')
    if baseline_report['source_rig_sha256'] != load(skin.with_suffix('.skin.json'))['source_sha256']:
        raise ValueError('Skin and rigid baseline are from different actual source rigs')
    old_prep = load(manifest_path.with_name('prepare_report.json'))
    fixed = ROOT / 'art/models/costume/fixed' / (avatar + '.glb')
    if sha(fixed) != old_prep['source_sha256']:
        raise ValueError('Original fixed texture/shape reference changed')
    sd, sb, _ = read_glb(skin); fd, fb, _ = read_glb(fixed)
    sidecar = load(skin.with_suffix('.skin.json'))
    if sidecar['output_sha256'] != sha(skin) or sidecar.get('source_skin_bones') != 23:
        raise ValueError('Exact original 23-bone paid skin required')
    fp, fixed_node = primitive_named(fd, 'Head')
    sp, skin_node = primitive_named(sd, 'CostumeSkinHead')
    if fixed_node.get('translation') or skin_node.get('translation'):
        raise ValueError('Identity original mesh frames required')
    fpos = values(fd, fb, fp, 'POSITION'); fuv = values(fd, fb, fp, 'TEXCOORD_0')
    spos = values(sd, sb, sp, 'POSITION'); suv = values(sd, sb, sp, 'TEXCOORD_0')
    ft = np.asarray(accessor_values(fd, fb, fp['indices']), int).reshape(-1, 3)
    st = np.asarray(accessor_values(sd, sb, sp['indices']), int).reshape(-1, 3)
    original_by_uv = {}
    for i, tri in enumerate(ft):
        key = uv_key(fuv[tri])
        if key in original_by_uv:
            raise ValueError('Ambiguous original Head UV triangles')
        original_by_uv[key] = tri
    xs, ys, matched = [], [], set()
    for tri in st:
        key = uv_key(suv[tri])
        if key not in original_by_uv or key in matched:
            raise ValueError('Paid skin original Head UV triangle changed')
        matched.add(key)
        fixed_tri = original_by_uv[key]
        corners = {(round(float(fuv[i, 0]), 6), round(float(fuv[i, 1]), 6)): fpos[i] for i in fixed_tri}
        if len(corners) != 3:
            raise ValueError('Degenerate original Head UV triangle')
        for i in tri:
            key_corner = (round(float(suv[i, 0]), 6), round(float(suv[i, 1]), 6))
            xs.append([*corners[key_corner], 1]); ys.append(spos[i])
    if matched != set(original_by_uv):
        raise ValueError('Paid Head surface does not preserve every original triangle')
    xs = np.asarray(xs); ys = np.asarray(ys)
    coefficients = np.linalg.lstsq(xs, ys, rcond=None)[0]
    residual = np.linalg.norm(xs @ coefficients - ys, axis=1)
    if residual.max() > 1e-5:
        raise ValueError('Original fixed-to-paid-skin coordinate proof failed')
    fixed_to_skin = np.vstack((coefficients.T, [0, 0, 0, 1]))
    if np.linalg.det(fixed_to_skin[:3, :3]) <= 0:
        raise ValueError('Mirrored fixed-to-skin mapping forbidden')
    cx, cy = old_prep['camera_center']; scale = old_prep['camera_scale']
    projected = np.column_stack(((fpos[:, 0]-cx)/scale+.5, 1-((fpos[:, 1]-cy)/scale+.5)))
    bd, bb, _ = read_glb(baseline); bp, bnode = primitive_named(bd, 'FaceExpression')
    buv = values(bd, bb, bp, 'TEXCOORD_0'); bpos = values(bd, bb, bp, 'POSITION')
    bnorm = values(bd, bb, bp, 'NORMAL')
    bt = np.asarray(accessor_values(bd, bb, bp['indices']), int).reshape(-1, 3)
    fixed_to_old_game, old_residual, old_mask = prove_baseline_frame(bd, bb, fpos, fuv, original_by_uv)
    source_uv_triangles = projected[ft]
    selected, cap_faces, errors, coincident_uv_groups = [], [], [], {}
    for i, tri in enumerate(bt):
        error = np.full(len(ft), np.inf)
        for permutation in itertools.permutations(range(3)):
            error = np.minimum(error, np.max(np.abs(source_uv_triangles-buv[tri[list(permutation)]]), axis=(1, 2)))
        candidates = np.flatnonzero(error < 2e-6)
        if len(candidates) == 1:
            selected.append(int(candidates[0])); errors.append(float(error[candidates[0]]))
        elif not len(candidates):
            cap_faces.append(tri)
        else:
            group = tuple(int(v) for v in candidates)
            coincident_uv_groups.setdefault(group, []).append({'baseline_face': i, 'uv_error': float(error[candidates].max())})
    for group, rows in coincident_uv_groups.items():
        # Some original nose triangles have exactly the same projected X/Y
        # while different depths and original atlas UV remain unique. Reuse
        # only a complete approved group; never choose one depth arbitrarily.
        if len(rows) == len(group) and not set(group).intersection(selected):
            selected.extend(group); errors.extend(row['uv_error'] for row in rows)
            continue
        predicted = (np.column_stack((fpos, np.ones(len(fpos)))) @ fixed_to_old_game.T)[:, :3]
        spatial_matches = []
        for row in rows:
            actual = bpos[bt[row['baseline_face']]] + bnode.get('translation', [0, 0, 0])
            distances = []
            for candidate in group:
                distance = min(float(np.max(np.linalg.norm(predicted[ft[candidate]]-actual[list(perm)], axis=1))) for perm in itertools.permutations(range(3)))
                distances.append((candidate, distance))
            exact = [candidate for candidate, distance in distances if distance < 1e-5]
            if len(exact) != 1:
                raise ValueError('Incomplete facial UV group lacks unique original 3D correspondence')
            spatial_matches.append(exact[0]); row['fixed_face_exact_3d'] = exact[0]
        if len(spatial_matches) != len(set(spatial_matches)) or set(spatial_matches).intersection(selected):
            raise ValueError('Approved original 3D facial matching is not one-to-one')
        selected.extend(spatial_matches); errors.extend(row['uv_error'] for row in rows)
    if len(selected) != len(set(selected)) or len(cap_faces) != 224:
        raise ValueError('Exact approved original face and 224-triangle cover required')
    # Prove the old canonical rigid frame independently from its unchanged
    # HeadBase UV/geometry. This also supports a mechanically corrected new
    # wrapper frame without rotating the mouth by an old guessed basis.
    old_game_to_fixed = np.linalg.inv(fixed_to_old_game)
    source_to_game = np.asarray(sidecar['source_to_game_affine']).reshape(4, 4, order='F')
    cap_positions, cap_normals, cap_uv, cap_indices, keys = [], [], [], [], {}
    for tri in cap_faces:
        indices = []
        for index in tri:
            key = tuple(bpos[index]) + tuple(buv[index])
            if key not in keys:
                keys[key] = len(cap_positions)
                world = bpos[index] + bnode.get('translation', [0, 0, 0])
                fixed_point = old_game_to_fixed @ np.array([*world, 1])
                fixed_normal = fixed_to_old_game[:3, :3].T @ bnorm[index]
                fixed_normal /= np.linalg.norm(fixed_normal)
                cap_positions.append(fixed_point[:3].tolist()); cap_normals.append(fixed_normal.tolist())
                cap_uv.append([float(buv[index, 0]), 1-float(buv[index, 1])])
            indices.append(keys[key])
        cap_indices.append(indices)
    if len(cap_positions) != 129:
        raise ValueError('Exact approved 129-vertex mouth cover required')
    signatures = [uv_key(np.column_stack((fuv[ft[i], 0], 1-fuv[ft[i], 1]))) for i in selected]
    fixed_to_game = source_to_game @ fixed_to_skin
    to_blender = np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]])
    center_fixed = np.array([cx, cy, float((fpos[:, 2].min()+fpos[:, 2].max())/2), 1])
    target = to_blender @ (fixed_to_game @ center_fixed)[:3]
    front = to_blender @ fixed_to_game[:3, :3] @ np.array([0, 0, 1.]); front /= np.linalg.norm(front)
    up = to_blender @ fixed_to_game[:3, :3] @ np.array([0, 1., 0]); up /= np.linalg.norm(up)
    factor = np.linalg.norm(fixed_to_game[:3, 1])
    report = {'source': str(fixed), 'source_sha256': sha(fixed), 'camera_scale': scale,
              'camera_center': [cx, cy], 'reviewed_profile': {'reviewed': True,
              'approved_rigid_face_scope': True, 'baseline_manifest': str(manifest_path),
              'baseline_manifest_sha256': sha(manifest_path)},
              'original_facial_uv_signatures': signatures,
              'mouth_cap_source_gltf_positions': cap_positions, 'mouth_cap_source_normals': cap_normals,
              'mouth_cap_face_uv': cap_uv, 'mouth_cap_source_indices': cap_indices,
              'preserved_skin_coordinate_proof': {'skin': str(skin), 'skin_sha256': sha(skin),
                'source_sidecar_sha256': sha(skin.with_suffix('.skin.json')),
                'fixed_to_skin_affine': fixed_to_skin.tolist(), 'matched_original_head_triangles': len(matched),
                'matched_original_corners': len(xs), 'maximum_coordinate_error': float(residual.max()),
                'approved_unchanged_headbase_coordinate_error': float(old_residual[old_mask].max()),
                'approved_unchanged_headbase_corners': int(old_mask.sum()),
                'old_mouth_geometry_modified_headbase_corners_excluded': int((~old_mask).sum()),
                'approved_baseline_head': str(baseline), 'approved_baseline_head_sha256': sha(baseline),
                'approved_face_uv_maximum_error': max(errors), 'approved_face_original_triangles': len(selected),
                'complete_coincident_projected_uv_groups': [{'fixed_faces': list(group), 'approved_baseline_faces': [r['baseline_face'] for r in rows]} for group, rows in coincident_uv_groups.items()],
                'source_front_camera_scale': float(scale*factor), 'camera_target': target.tolist(),
                'camera_front_direction': front.tolist(), 'camera_front_up': up.tolist(),
                'original_bones_claimed': True, 'source_skin_bones': 23,
                'runtime_validated': False}, 'original_sources_unchanged': True,
              'semantic_images_edited': False, 'ready': False}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'avatar': avatar, 'output': str(args.output), 'selected_face_triangles': len(selected),
                      'original_head_triangles': len(matched), 'coordinate_error': float(residual.max()),
                      'uv_error': max(errors), 'source_skin_bones': 23, 'studio_called': False}))


if __name__ == '__main__':
    main()
