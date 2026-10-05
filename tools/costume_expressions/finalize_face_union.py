# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Finalize a separate original-triangle face candidate without replacing baselines.

Original geometry, joints, weights and the approved GPT PNGs remain untouched.
The caller must personally review six rest and six actual-Fx comparison renders.
No Studio, registry, upload or paid API operations occur here.
"""
from __future__ import annotations

raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import subprocess
import sys

import numpy as np

from finalize_skin_assets import inspect, relative, sha

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/costume_r15'))
from glb_io import accessor_values, read_glb
from skin_frames import resolve, original_projection


def values(doc, binary, primitive, key):
    return np.asarray(accessor_values(doc, binary, primitive['attributes'][key]))


def triangles(doc, binary, primitive):
    return np.asarray(accessor_values(doc, binary, primitive['indices']), int).reshape(-1, 3)


def array_sha(value, dtype):
    return hashlib.sha256(np.asarray(value, dtype=dtype).tobytes(order='C')).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('glb', type=Path)
    parser.add_argument('--prepare-report', type=Path, required=True)
    parser.add_argument('--baseline-manifest', type=Path, required=True)
    parser.add_argument('--preview-directory', required=True)
    parser.add_argument('--game-fx-report', type=Path, required=True)
    parser.add_argument('--reviewed', action='store_true')
    parser.add_argument('--diagnostic-only', action='store_true', help='Save provenance and failure evidence without any final manifest or runtime sidecar')
    parser.add_argument('--visual-notes', default='Original-only surface avoids the cap interpolation boundary. Original source skin deformation and mouth recess remain; actual game Animator/physics and three-state quality must still be checked.')
    args = parser.parse_args()
    glb = args.glb.resolve(); folder = glb.parent
    manifest_path = folder / 'face_union_manifest.json'
    provenance_path = folder / 'face_union_provenance.json'
    compatibility_path = folder / 'face_union_uv_compatibility.json'
    fx_review_path = folder / 'face_union_game_fx_review.json'
    if not args.reviewed:
        raise ValueError('Personally review all six rest and six Fx comparison images first')
    for path in [manifest_path, provenance_path, compatibility_path, fx_review_path,
                 folder / 'face_union_validation.json', folder / 'face_union_prepare_report.json',
                 glb.with_suffix('.skin.json')]:
        if path.exists():
            raise ValueError('Refuse candidate replacement: ' + str(path))
    validation, report, doc, binary = inspect(glb, args.prepare_report)
    if not validation['original_triangles_only'] or validation['new_mouth_cap_vertices'] != 0:
        raise ValueError('This finalizer accepts only the exact original facial triangle union')
    source_path = Path(report['source_skin'])
    source_doc, source_binary, _ = read_glb(source_path)
    source_primitive = source_doc['meshes'][1]['primitives'][0]
    face_primitive = doc['meshes'][2]['primitives'][0]
    original = triangles(source_doc, source_binary, source_primitive)
    selected = triangles(doc, binary, face_primitive)
    rows_by_triangle = defaultdict(list)
    for index, tri in enumerate(original):
        rows_by_triangle[tuple(tri)].append(index)
    positions = values(source_doc, source_binary, source_primitive, 'POSITION')
    normals = values(source_doc, source_binary, source_primitive, 'NORMAL')
    uv = values(source_doc, source_binary, source_primitive, 'TEXCOORD_0')
    joints = values(source_doc, source_binary, source_primitive, 'JOINTS_0')
    weights = values(source_doc, source_binary, source_primitive, 'WEIGHTS_0')
    triangle_rows = []
    for face_index, tri in enumerate(selected):
        source_indices = rows_by_triangle[tuple(tri)]
        if len(source_indices) != 1:
            raise ValueError('Source oriented facial triangle must map uniquely')
        triangle_rows.append({'expression_face_index': face_index,
                              'original_head_face_index': source_indices[0],
                              'original_vertex_indices': tri.tolist(),
                              'original_uv': uv[tri].tolist()})
    active_vertices = np.unique(selected)
    provenance = {'schema': 1, 'avatar': folder.name, 'source_skin': relative(source_path),
                  'source_skin_sha256': sha(source_path), 'expression_skin_sha256': sha(glb),
                  'original_head_triangles': len(original), 'selected_original_triangles': len(selected),
                  'selected_unique_vertices': len(active_vertices), 'new_vertices': 0,
                  'source_face_indices': [r['original_head_face_index'] for r in triangle_rows],
                  'triangles': triangle_rows,
                  'vertices': [{'original_vertex_index': int(i), 'position': positions[i].tolist(),
                                'normal': normals[i].tolist(), 'original_uv': uv[i].tolist(),
                                'joints': joints[i].tolist(), 'weights': weights[i].tolist()}
                               for i in active_vertices],
                  'oriented_original_indices_sha256': array_sha(selected, '<u4'),
                  'joint_slot_order': [source_doc['nodes'][i]['name'] for i in source_doc['skins'][0]['joints']],
                  'geometry_normal_joint_weight_values_exact': True,
                  'new_interpolated_vertices': 0, 'source_unchanged': True, 'ready': False}
    baseline = json.loads(args.baseline_manifest.read_text(encoding='utf-8'))
    projected_uv = values(doc, binary, face_primitive, 'TEXCOORD_0')
    canonical_skin_comparison = 'skin_asset' in baseline
    if canonical_skin_comparison:
        baseline_glb = ROOT / baseline['skin_asset']
        if sha(baseline_glb) != baseline['skin_sha256']:
            raise ValueError('Canonical comparison baseline SHA changed')
        if baseline['source_skin_sha256'] != sha(source_path):
            raise ValueError('Canonical UV comparison must use the same original source')
        baseline_doc, baseline_binary, _ = read_glb(baseline_glb)
        baseline_face = baseline_doc['meshes'][2]['primitives'][0]
        previous_uv = values(baseline_doc, baseline_binary, baseline_face, 'TEXCOORD_0')[:len(positions)]
    else:
        baseline_glb = ROOT / baseline['head_asset']
        if sha(baseline_glb) != baseline['head_sha256']:
            raise ValueError('Approved rigid comparison head SHA changed')
        prepared = json.loads(args.prepare_report.read_text(encoding='utf-8'))
        source_sidecar = json.loads(source_path.with_suffix('.skin.json').read_text(encoding='utf-8'))
        frame, _, _ = resolve(prepared, source_path, source_sidecar)
        previous_uv = np.asarray(original_projection(positions, prepared, frame), dtype=np.float32)
    if not np.array_equal(projected_uv, previous_uv):
        raise ValueError('Existing approved PNG UV mapping is not byte-identical')
    png_rows = []
    for row in baseline['records']:
        png = ROOT / row['png']
        if sha(png) != row['sha256']:
            raise ValueError('Existing approved GPT PNG bytes changed')
        png_rows.append({'state': row['state'], 'png': row['png'], 'sha256': row['sha256'],
                         'existing_uploaded_texture_reusable_if_asset_sha_matches': True})
    compatibility = {'schema': 1, 'avatar': folder.name, 'expression_skin_sha256': sha(glb),
                     'comparison_manifest': relative(args.baseline_manifest),
                     'comparison_manifest_sha256': sha(args.baseline_manifest),
                     'comparison_skin_sha256': sha(baseline_glb),
                     'original_head_vertices_compared': len(positions),
                     'normalized_original_face_uv_sha256': array_sha(projected_uv, '<f4'),
                     'canonical_normalized_original_face_uv_sha256': array_sha(previous_uv, '<f4'),
                     'canonical_skin_comparison_available': canonical_skin_comparison,
                     'comparison_uv_basis': 'original-vertex UV bytes from canonical skin Face primitive' if canonical_skin_comparison else 'normalized projection rederived from approved rigid-head original-face correspondence',
                     'normalized_original_face_uv_float32_exact': True,
                     'approved_png_bytes_unchanged': True, 'expression_pngs': png_rows,
                     'mesh_asset_reimport_required': True,
                     'texture_reuse_policy': 'Reuse an actual texture ID only after matching its upload ledger PNG SHA; never reuse the old Face mesh ID.',
                     'ready': False}
    fx = json.loads(args.game_fx_report.read_text(encoding='utf-8'))
    if fx['expression_sha256'] != sha(glb) or fx['original_skin_sha256'] != sha(source_path):
        raise ValueError('Actual-Fx CG report does not belong to this exact union/source')
    fx_source = ROOT / 'src/StarterPlayer/StarterPlayerScripts/Fx.luau'
    if fx['fx_sha256'] != sha(fx_source) or len(fx['records']) != 3:
        raise ValueError('Actual-Fx CG source changed or pose comparisons are incomplete')
    for row in fx['records']:
        for key in ['original_render', 'expression_render']:
            image = Path(row[key])
            if not image.exists():
                raise ValueError('Missing reviewed Fx CG render')
            row[key] = relative(image)
            row[key + '_sha256'] = sha(image)
    fx.update(personally_reviewed=True, report_source=relative(args.game_fx_report),
              report_source_sha256=sha(args.game_fx_report), ready=False, runtime_validated=False,
              visual_quality_hold=args.diagnostic_only, review_notes=args.visual_notes)
    for path, content in [(provenance_path, provenance), (compatibility_path, compatibility), (fx_review_path, fx)]:
        path.write_text(json.dumps(content, indent=2) + '\n', encoding='utf-8')
    if args.diagnostic_only:
        print(json.dumps({'diagnostic_provenance': relative(provenance_path),
                          'game_fx_review': relative(fx_review_path), 'skin_sha256': sha(glb),
                          'visual_quality_hold': True, 'ready': False, 'studio_called': False}))
        return
    subprocess.run([sys.executable, str(Path(__file__).with_name('finalize_skin_assets.py')), str(glb),
                    '--prepare-report', str(args.prepare_report), '--reviewed',
                    '--preview-directory', args.preview_directory,
                    '--manifest-name', manifest_path.name,
                    '--validation-name', 'face_union_validation.json',
                    '--prepare-name', 'face_union_prepare_report.json'], check=True)
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    manifest.update(candidate_variant='original_triangle_union_v1',
                    original_face_provenance=relative(provenance_path),
                    original_face_provenance_sha256=sha(provenance_path),
                    uv_texture_compatibility=relative(compatibility_path),
                    uv_texture_compatibility_sha256=sha(compatibility_path),
                    game_fx_offline_review=relative(fx_review_path),
                    game_fx_offline_review_sha256=sha(fx_review_path),
                    canonical_skin_candidate_preserved=True,
                    offline_visual_notes='No new mouth-cap vertices. Original mouth recess/weights remain unchanged; actual full Animator/physics and imported mesh quality remain pending.')
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    subprocess.run([sys.executable, str(Path(__file__).with_name('write_skin_runtime_sidecar.py')), str(manifest_path)], check=True)
    print(json.dumps({'manifest': relative(manifest_path), 'skin_sha256': sha(glb),
                      'original_face_triangles': len(selected), 'png_bytes_unchanged': True,
                      'ready': False, 'studio_called': False}))


if __name__ == '__main__':
    main()
