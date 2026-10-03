"""Summarize offline continuous faces separately from actual Roblox records."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

from finalize_skin_assets import inspect

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / 'art/models/costume/expressions'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path):
    return json.loads(path.read_text(encoding='utf-8'))


def main():
    records = []
    for path in sorted(FOLDER.glob('*/skin_expressions_manifest.json')):
        manifest = load(path)
        asset = ROOT / manifest['skin_asset']
        prepare_path = ROOT / manifest['prepare_report'] if manifest.get('prepare_report') else path.with_name('prepare_report.json')
        validation, report, _, _ = inspect(asset, prepare_path)
        saved = load(path.with_name('skin_validation.json'))
        if not saved['validated'] or saved['skin_sha256'] != manifest['skin_sha256'] or manifest['skin_sha256'] != sha(asset):
            raise ValueError('Stale skin validation: ' + str(path))
        if validation['skin_sha256'] != manifest['skin_sha256']:
            raise ValueError('Skin asset differs from final manifest: ' + str(path))
        previews = []
        for row in manifest['records']:
            if sha(ROOT / row['png']) != row['sha256']:
                raise ValueError('Current GPT PNG differs: ' + row['png'])
            if len(row['offline_previews']) != 2:
                raise ValueError('Both baseline views required')
            for image in row['offline_previews']:
                report = load((ROOT / image).with_suffix('.json'))
                if report['source_sha256'] != sha(asset) or Path(report['expression']).resolve() != (ROOT / row['png']).resolve() or report.get('skin_pose'):
                    raise ValueError('Baseline preview belongs to another asset/state')
                previews.append(image)
        if len(manifest['records']) != 3 or len(set(previews)) != 6:
            raise ValueError('Exactly three states and six current baseline views required')
        records.append({'avatar': manifest['avatar'], 'manifest': path.relative_to(ROOT).as_posix(),
                        'skin_asset': manifest['skin_asset'], 'skin_sha256': sha(asset),
                        'rig_origin': manifest['rig_origin'], 'original_bones_claimed': manifest['original_bones_claimed'],
                        'expression_pngs': 3, 'offline_previews': 6,
                        'ready': False, 'runtime_validated': False, 'roblox_uploaded': False})
    timestamp = datetime.now(timezone.utc).isoformat()
    local = {'schema': 1, 'generated_at_utc': timestamp,
             'pipeline': 'preserved_continuous_skin_expression',
             'offline_validated_avatars': len(records),
             'offline_expression_pngs': 3 * len(records), 'offline_baseline_previews': 6 * len(records),
             'candidate_engine_ready_avatars': 0,
             'local_validation_is_not_runtime_registration': True, 'records': records}
    (FOLDER / 'skin_local_index.json').write_text(json.dumps(local, indent=2) + '\n', encoding='utf-8')

    rigid = load(FOLDER / 'local_index.json')
    for row in rigid['records']:
        manifest = load(ROOT / row['manifest'])
        validation = load((ROOT / row['manifest']).with_name('validation.json'))
        if sha(ROOT / row['head_asset']) != row['head_sha256'] or manifest['head_sha256'] != row['head_sha256'] or not validation['validated']:
            raise ValueError('Rigid comparison reference changed: ' + row['avatar'])
    all_rows = {r['avatar']: dict(r, pipeline='rigid_head_expression') for r in rigid['records']}
    for row in records:
        all_rows[row['avatar']] = dict(row, pipeline='preserved_continuous_skin_expression')
    actual = []
    for path in sorted((FOLDER / 'roblox_registrations').glob('*.json')):
        row = load(path)
        avatar = row['avatar']
        if not row.get('runtime_validated') or not row.get('source_registered'):
            raise ValueError('Registration folder must contain only actually validated records')
        # A rigid registration remains a valid historical proof while an offline
        # continuous replacement is being prepared; never mark that replacement ready.
        if sha(ROOT / row['head_asset']) != row['head_sha256']:
            raise ValueError('Registered Head evidence asset changed')
        if avatar not in all_rows:
            raise ValueError('Actual avatar is outside the local approved inventory')
        actual.append({'avatar': avatar, 'record': path.relative_to(ROOT).as_posix(),
                       'record_sha256': sha(path), 'head_sha256': row['head_sha256'],
                       'face_mesh_id': row['face_mesh_id'], 'textures': row['textures'],
                       'pipeline': row['pipeline'], 'source_registered': True,
                       'runtime_validated': True, 'scope': 'recorded actual QA snapshot'})
    total = {'schema': 1, 'generated_at_utc': timestamp, 'approved_avatars': 18,
             'approved_states': ['Neutral', 'SoftSmile', 'Serious'], 'target_expression_pngs': 54,
             'offline_validated_unique_avatars': len(all_rows),
             'offline_expression_pngs': sum(r['expression_pngs'] for r in all_rows.values()),
             'offline_baseline_previews': sum(r['offline_previews'] for r in all_rows.values()),
             'rigid_comparison_reference_avatars': len(rigid['records']),
             'continuous_skin_candidate_avatars': len(records),
             'recorded_actual_registered_avatars': len(actual),
             'recorded_actual_runtime_validated_avatars': len(actual),
             'local_validation_is_not_runtime_registration': True,
             'candidate_ready_is_not_inherited_from_registered_rigid_reference': True,
             'records': list(all_rows.values()), 'actual_registrations': actual}
    (FOLDER / 'expression_inventory.json').write_text(json.dumps(total, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in total.items() if k not in ['records', 'actual_registrations']}))


if __name__ == '__main__':
    main()
