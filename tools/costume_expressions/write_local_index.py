# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Summarize validated local expression assets without claiming Roblox readiness."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / 'art/models/costume/expressions'


def main():
    records = []
    for manifest_path in sorted(FOLDER.glob('*/expressions_manifest.json')):
        manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
        validation = json.loads(manifest_path.with_name('validation.json').read_text(encoding='utf-8'))
        if not validation.get('validated') or validation['head_sha256'] != manifest['head_sha256']:
            raise RuntimeError(f'Stale or failed validation: {manifest_path}')
        report = json.loads((ROOT / manifest['head_asset']).with_suffix('.json').read_text(encoding='utf-8'))
        records.append({
            'avatar': manifest['avatar'],
            'manifest': manifest_path.relative_to(ROOT).as_posix(),
            'head_asset': manifest['head_asset'],
            'head_sha256': manifest['head_sha256'],
            'existing_joints': Path(report['existing_joints']).relative_to(ROOT).as_posix(),
            'expression_pngs': validation['expression_pngs'],
            'offline_previews': validation['offline_previews_checked'],
            'body_reimport_required': manifest.get('body_reimport_required', False),
            'body_parts_reimport_required': manifest.get('body_parts_reimport_required', []),
            'assembly_requirements': manifest.get('assembly_requirements', {}),
            'runtime_validated': manifest.get('runtime_validated', False),
            'roblox_uploaded': all(r.get('roblox_uploaded', False) for r in manifest['records']),
        })
    result = {
        'generated_at_utc': datetime.now(timezone.utc).isoformat(),
        'approved_human_avatar_scope': 18,
        'target_expression_pngs': 54,
        'approved_states': ['Neutral', 'SoftSmile', 'Serious'],
        'offline_validated_avatars': len(records),
        'offline_expression_pngs': sum(r['expression_pngs'] for r in records),
        'offline_previews': sum(r['offline_previews'] for r in records),
        'runtime_validated_avatars': sum(r['runtime_validated'] for r in records),
        'roblox_uploaded_avatars': sum(r['roblox_uploaded'] for r in records),
        'local_validation_is_not_runtime_registration': True,
        'records': records,
    }
    output = FOLDER / 'local_index.json'
    output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in result.items() if k != 'records'}, ensure_ascii=False))


if __name__ == '__main__':
    main()
