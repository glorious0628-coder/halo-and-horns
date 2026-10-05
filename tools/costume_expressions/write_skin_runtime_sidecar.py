# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Write a false-ready expression skin sidecar from a verified original contract."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

from finalize_skin_assets import inspect

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/costume_r15'))
from glb_io import read_glb, accessor_values


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding='utf-8'))
    glb = ROOT / manifest['skin_asset']
    prepared = ROOT / manifest['prepare_report'] if manifest.get('prepare_report') else args.manifest.with_name('prepare_report.json')
    validation_path = ROOT / manifest['validation_report'] if manifest.get('validation_report') else args.manifest.with_name('skin_validation.json')
    validation, report, doc, binary = inspect(glb, prepared)
    if sha(glb) != manifest['skin_sha256']:
        raise ValueError('Current manifest does not match the validated GLB')
    output = glb.with_suffix('.skin.json')
    if output.exists():
        raise ValueError('Refuse silent expression sidecar replacement')
    source = Path(report['source_skin'])
    original = json.loads(source.with_suffix('.skin.json').read_text(encoding='utf-8'))
    contract = copy.deepcopy(original)
    surface_rows = []
    frame = np.asarray(original['source_to_game_affine']).reshape(4, 4, order='F')
    for node_index, node in enumerate(doc['nodes']):
        if 'mesh' not in node:
            continue
        primitive = doc['meshes'][node['mesh']]['primitives'][0]
        positions = np.asarray(accessor_values(doc, binary, primitive['attributes']['POSITION']))
        indices = np.asarray(accessor_values(doc, binary, primitive['indices']), int).reshape(-1)
        active = positions[indices]
        def bbox(values):
            lo, hi = values.min(axis=0), values.max(axis=0)
            return {'minimum': lo.tolist(), 'maximum': hi.tolist(), 'center': ((lo+hi)/2).tolist(), 'size': (hi-lo).tolist()}
        game = (np.column_stack((active, np.ones(len(active)))) @ frame.T)[:, :3]
        row = {'name': node['name'], 'mesh': node['mesh'], 'node': node_index,
               'skin': node['skin'], 'source_world': np.eye(4).flatten(order='F').tolist(),
               'referenced_triangles': len(indices)//3, 'accessor_vertices': len(positions),
               'referenced_unique_vertices': len(np.unique(indices)),
               'unused_accessor_vertices': len(positions)-len(np.unique(indices)),
               'referenced_source_bounds': bbox(active), 'full_accessor_source_bounds': bbox(positions),
               'referenced_game_bounds': bbox(game)}
        if isinstance(original.get('meshes'), list):
            old_name = 'CostumeSkinHead' if node['name'] in ['HeadBase', 'FaceExpression'] else node['name']
            old = next(r for r in original['meshes'] if r['name'] == old_name)
            row.update(source_node=old['source_node'], source_name=old['source_name'])
        surface_rows.append(row)
    if {r['name'] for r in surface_rows} != {'CostumeSkinBody', 'HeadBase', 'FaceExpression'}:
        raise ValueError('Exactly three expected skin surfaces required')
    contract.update(output=str(glb.resolve()), output_sha256=sha(glb),
                    rig_ready_for_game=False, studio_motion_validated=False,
                    original_bones_claimed=manifest['original_bones_claimed'],
                    expression_origin=manifest['rig_origin'],
                    original_two_surface_skin=str(source), original_two_surface_skin_sha256=sha(source),
                    original_sidecar_sha256=sha(source.with_suffix('.skin.json')),
                    original_triangles=sum(r['referenced_triangles'] for r in surface_rows),
                    estimated_assets=7, active_original_images=2,
                    expression_surfaces=surface_rows,
                    expression_face_unused_original_head_positions_preserved=True,
                    native_bounds_policy='Compare actual Importer observations to both referenced and full-accessor bounds; never guess a basis, pad extents, or claim a successful import offline.',
                    expression_manifest=args.manifest.resolve().relative_to(ROOT).as_posix(),
                    expression_manifest_sha256=sha(args.manifest),
                    expression_validation=validation_path.resolve().relative_to(ROOT).as_posix(),
                    expression_validation_sha256=sha(validation_path),
                    expression_meshes_validated_offline=True, expression_runtime_validated=False,
                    api_called=False, uploads=0,
                    expression_states={r['state']: {'png': r['png'], 'sha256': r['sha256']} for r in manifest['records']},
                    requires_expression_root_weld_and_shared_actual_bone_host=True)
    contract['meshes'] = surface_rows if isinstance(original.get('meshes'), list) else 3
    if 'images' in contract:
        contract['images'] = 3
    output.write_text(json.dumps(contract, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'output': str(output), 'avatar': manifest['avatar'], 'skin_sha256': sha(glb),
                      'source_skin_bones': len(doc['skins'][0]['joints']), 'ready': False,
                      'face_unused_vertices': next(r['unused_accessor_vertices'] for r in surface_rows if r['name'] == 'FaceExpression'),
                      'studio_called': False}))


if __name__ == '__main__':
    main()
