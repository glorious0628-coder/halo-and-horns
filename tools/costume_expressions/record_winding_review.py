# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Archive a strictly validated, unpromoted winding diagnostic and twelve CGs."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import copy
import json
from pathlib import Path
import shutil

from validate_mouth_winding import check
from validate_mouth_restoration import ROOT, sha
from finalize_skin_assets import relative


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('glb', type=Path)
    parser.add_argument('--rest-directory', type=Path, required=True)
    parser.add_argument('--fx-review', type=Path, required=True)
    parser.add_argument('--negative-tests', type=Path, required=True)
    parser.add_argument('--reviewed', action='store_true')
    args = parser.parse_args()
    if not args.reviewed:
        raise ValueError('Personally review all six rest and six actual Fx CGs')
    glb = args.glb.resolve()
    validation = check(glb)
    folder = glb.parent
    records = json.loads((folder / 'expressions_manifest.json').read_text(encoding='utf-8'))['records']
    tests = json.loads(args.negative_tests.read_text(encoding='utf-8'))
    if tests['sha256'] != sha(glb) or not tests['positive'] or not tests['all_rejected'] or len(tests['mutations']) < 15:
        raise ValueError('Current strict winding positive and all fifteen negative tests required')
    review = copy.deepcopy(json.loads(args.fx_review.read_text(encoding='utf-8')))
    if review['expression_sha256'] != sha(glb) or not review['personally_reviewed'] or len(review['records']) != 3:
        raise ValueError('Current personally reviewed original/expression Fx comparisons required')
    if review.get('shading_policy') != 'original imported shaded materials' or review['fx_sha256'] != sha(ROOT / 'src/StarterPlayer/StarterPlayerScripts/Fx.luau'):
        raise ValueError('Current actual Fx source and lit shading policy required')
    destinations = {
        'manifest': folder / 'face_union_mouth_winding_diagnostic_v1.json',
        'validation': folder / 'face_union_mouth_winding_validation_v1.json',
        'tests': folder / 'face_union_mouth_winding_tests_v1.json',
        'review': folder / 'face_union_mouth_winding_visual_review_v1.json',
    }
    rest_directory = folder / 'face_union_mouth_winding_v1_previews'
    fx_directory = folder / 'face_union_mouth_winding_v1_fx_previews'
    if any(path.exists() for path in [*destinations.values(), rest_directory, fx_directory]):
        raise ValueError('Never replace an existing candidate or diagnostic')
    rest_rows = []
    for record in records:
        if sha(ROOT / record['png']) != record['sha256']:
            raise ValueError('Approved GPT PNG changed')
        for view in ['front', 'quarter']:
            path = args.rest_directory / (record['state'] + '_' + view + '.png')
            metadata = json.loads(path.with_suffix('.json').read_text(encoding='utf-8'))
            if metadata['source_sha256'] != sha(glb) or metadata.get('shading_policy') != 'original imported material with geometry QA area lights':
                raise ValueError('Exact lit rest CG required')
            if not metadata.get('expression') or sha(metadata['expression']) != record['sha256']:
                raise ValueError('Rest CG must use the exact approved PNG')
            rest_rows.append((path, metadata))
    for record in review['records']:
        for kind in ['original', 'expression']:
            path, metadata = ROOT / record[kind + '_render'], ROOT / record[kind + '_render_metadata']
            if sha(path) != record[kind + '_render_sha256'] or sha(metadata) != record[kind + '_render_metadata_sha256']:
                raise ValueError('Reviewed Fx CG changed')
    # File copies only. The original images and every raster pixel are unchanged.
    rest_directory.mkdir()
    fx_directory.mkdir()
    rest_evidence = []
    for path, metadata in rest_rows:
        target = rest_directory / path.name
        shutil.copyfile(path, target)
        metadata['render'] = str(target)
        target.with_suffix('.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
        rest_evidence.append({'image': relative(target), 'sha256': sha(target),
                              'metadata': relative(target.with_suffix('.json')), 'metadata_sha256': sha(target.with_suffix('.json'))})
    for record in review['records']:
        for kind in ['original', 'expression']:
            path = ROOT / record[kind + '_render']
            target = fx_directory / path.name
            shutil.copyfile(path, target)
            metadata = json.loads((ROOT / record[kind + '_render_metadata']).read_text(encoding='utf-8'))
            metadata['render'] = str(target)
            target.with_suffix('.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
            record[kind + '_render'] = relative(target)
            record[kind + '_render_sha256'] = sha(target)
            record[kind + '_render_metadata'] = relative(target.with_suffix('.json'))
            record[kind + '_render_metadata_sha256'] = sha(target.with_suffix('.json'))
    review.update(rest_previews_personally_reviewed=True, rest_evidence=rest_evidence, ready=False,
                  runtime_validated=False, roblox_uploaded=False)
    for key, value in [('validation', validation), ('tests', tests), ('review', review)]:
        destinations[key].write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')
    report = json.loads(glb.with_suffix('.json').read_text(encoding='utf-8'))
    manifest = {
        'schema': 1, 'kind': 'offline_original_mouth_winding_diagnostic_v1', 'avatar': folder.name,
        'glb': relative(glb), 'glb_sha256': sha(glb),
        'winding_ledger': relative(report['mouth_winding_ledger']), 'winding_ledger_sha256': report['mouth_winding_ledger_sha256'],
        'mouth_pn_ledger': relative(report['mouth_geometry_restoration_ledger']),
        'mouth_pn_ledger_sha256': report['mouth_geometry_restoration_ledger_sha256'],
        'source_skin': relative(report['source_skin']), 'source_skin_sha256': report['source_skin_sha256'],
        'strict_validator': 'tools/costume_expressions/validate_mouth_winding.py',
        'strict_validation': relative(destinations['validation']), 'strict_validation_sha256': sha(destinations['validation']),
        'negative_tests': relative(destinations['tests']), 'negative_tests_sha256': sha(destinations['tests']),
        'visual_review': relative(destinations['review']), 'visual_review_sha256': sha(destinations['review']),
        'changed_original_mouth_triangles': validation['changed_original_mouth_triangles'],
        'original_triangle_vertex_sets_exact': True, 'parent_pn_uv_jw_bones_png_exact': True,
        'new_vertices': 0, 'new_triangles': 0, 'visual_quality_hold': review.get('visual_quality_hold', True),
        'production_import_contract_finalized': False, 'ready': False, 'runtime_validated': False,
        'roblox_uploaded': False, 'studio_called': False, 'paid_api_calls': 0,
        'limitations': ['This diagnostic is separate from ordinary P/N and oriented-index exact production contracts.',
                        'Actual import identity, shared-skin binding and native motion/three-state quality remain root QA.'],
    }
    destinations['manifest'].write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'diagnostic_manifest': str(destinations['manifest']), 'glb_sha256': sha(glb),
                      'quality_hold': manifest['visual_quality_hold'], 'ready': False}), flush=True)


if __name__ == '__main__':
    main()
