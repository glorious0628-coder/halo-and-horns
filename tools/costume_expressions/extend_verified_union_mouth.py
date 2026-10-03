"""Add only ray-proven original mouth triangles to a new no-cap preparation.

No vertex, normal, skin weight, source texture or approved PNG modifications.
The ray report must prove a visible original HeadBase triangle within the
existing approved mouth-cover footprint. Ambiguous/outside matches are refused.
"""
import argparse
import copy
import json
from pathlib import Path
import sys

import numpy as np

from finalize_skin_assets import sha
from skin_frames import resolve, original_projection, transform_cap

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/costume_r15'))
from glb_io import accessor_values, read_glb


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('prepare_report', type=Path)
    parser.add_argument('ray_report', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError('Refuse original preparation or candidate replacement')
    original_prepared = json.loads(args.prepare_report.read_text(encoding='utf-8'))
    prep = copy.deepcopy(original_prepared)
    trace = json.loads(args.ray_report.read_text(encoding='utf-8'))
    candidate = Path(trace['source'])
    camera = Path(trace['camera'])
    if sha(candidate) != trace['source_sha256'] or sha(camera) != trace['camera_sha256']:
        raise ValueError('Exact observed candidate or rest camera changed')
    export = json.loads(candidate.with_suffix('.json').read_text(encoding='utf-8'))
    source = Path(export['source_skin'])
    if trace['original_skin_sha256'] != sha(source) or not export['original_triangles_only']:
        raise ValueError('Ray evidence must use the original-triangle-only candidate')
    sidecar = json.loads(source.with_suffix('.skin.json').read_text(encoding='utf-8'))
    frame, _, _ = resolve(prep, source, sidecar)
    doc, binary, _ = read_glb(source)
    primitive = doc['meshes'][1]['primitives'][0]
    attrs = primitive['attributes']
    uv = np.asarray(accessor_values(doc, binary, attrs['TEXCOORD_0']))
    positions = np.asarray(accessor_values(doc, binary, attrs['POSITION']))
    triangles = np.asarray(accessor_values(doc, binary, primitive['indices']), int).reshape(-1, 3)
    cap_positions, _ = transform_cap(prep, frame)
    cap_uv = original_projection(cap_positions, prep, frame)
    lower, upper = cap_uv.min(axis=0), cap_uv.max(axis=0)
    indices = sorted({int(p['original_head_face_matches'][0]) for p in trace['points']
                      if p.get('mesh', '').startswith('HeadBase') and p.get('material', '').startswith('HeadMat')
                      and len(p.get('original_head_face_matches', [])) == 1})
    if not indices:
        raise ValueError('No uniquely ray-proven original mouth triangles')
    existing = {tuple(sorted(tuple(v) for v in row)) for row in prep['original_facial_uv_signatures']}
    additions = []
    for index in indices:
        tri = triangles[index]
        projected = original_projection(positions[tri], prep, frame)
        if np.any(projected.mean(axis=0) < lower) or np.any(projected.mean(axis=0) > upper):
            raise ValueError('Observed triangle is outside the approved mouth footprint')
        signature = tuple(sorted((round(float(uv[i, 0]), 6), round(1-float(uv[i, 1]), 6)) for i in tri))
        if signature in existing:
            raise ValueError('Observed mouth triangle is already in the original face scope')
        evidence = [p for p in trace['points'] if p.get('original_head_face_matches') == [index]]
        if any(p.get('original_vertex_indices') != tri.tolist() for p in evidence):
            raise ValueError('Observed vertex provenance differs from current source')
        existing.add(signature)
        prep['original_facial_uv_signatures'].append(signature)
        additions.append({'original_head_face_index': index, 'original_vertex_indices': tri.tolist(),
                          'original_gltf_uv': uv[tri].tolist(), 'normalized_expression_uv': projected.tolist(),
                          'ray_pixels': [p['pixel'] for p in evidence]})
    if prep.get('verified_original_face_union_extension'):
        prep.setdefault('previous_verified_union_extensions', []).append(copy.deepcopy(prep['verified_original_face_union_extension']))
    prep['verified_original_face_union_extension'] = {
        'method': 'Exact original mouth HeadBase triangle uniquely traced from recorded rest CG pixel and original UV',
        'original_prepare_report': str(args.prepare_report.resolve()),
        'original_prepare_report_sha256': sha(args.prepare_report),
        'ray_report': str(args.ray_report.resolve()), 'ray_report_sha256': sha(args.ray_report),
        'source_skin_sha256': sha(source), 'original_scope_triangles': len(original_prepared['original_facial_uv_signatures']),
        'added_original_mouth_triangles': additions, 'new_geometry_vertices': 0,
        'approved_png_changes': 0, 'ready': False}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(prep, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'prepare_report': str(args.output), 'added_original_mouth_triangles': indices,
                      'new_scope_triangles': len(prep['original_facial_uv_signatures']), 'source_unchanged': True}))


if __name__ == '__main__':
    main()
