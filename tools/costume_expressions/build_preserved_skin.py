# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Prepare original paid-skin expressions and CG only; personal review is separate."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

from build_local_candidate import run

ROOT = Path(__file__).resolve().parents[2]


def command(script, *args):
    result = subprocess.run([sys.executable, str(Path(__file__).parent / script), *map(str, args)],
                            cwd=ROOT, capture_output=True, text=True, encoding='utf-8', errors='replace')
    if result.returncode:
        raise RuntimeError(result.stdout + '\n' + result.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('avatar', help='Costume_<Faction><Class><M|F>')
    parser.add_argument('--skin', type=Path, help='Explicit approved correction copy; never mutate it')
    parser.add_argument('--version', default='v1')
    args = parser.parse_args()
    folder = ROOT / 'art/models/costume/expressions' / args.avatar
    manifest = folder / 'expressions_manifest.json'
    baseline = json.loads(manifest.read_text(encoding='utf-8'))
    states = {r['state']: ROOT / r['png'] for r in baseline['records']}
    skin = args.skin.resolve() if args.skin else None
    if skin is None:
        records = json.loads((ROOT / 'art/models/costume/prepared/source_records.json').read_text(encoding='utf-8'))
        paths = [f for p in records['packages'] if p['kind'] == 'preserved_original_skin_pending' and
                 p['name'].startswith(args.avatar + '_preserved_') for f in p['files'] if f['path'].endswith('.glb')]
        if len(paths) != 1:
            raise ValueError('Exactly one selected paid source package required')
        skin = ROOT / paths[0]['path']
        if hashlib.sha256(skin.read_bytes()).hexdigest() != paths[0]['sha256']:
            raise ValueError('Selected original source skin package changed')
    prepared = ROOT / 'build/expr_qa' / args.avatar / ('paid_skin_' + args.version)
    prepare = prepared / 'prepare_report.json'
    glb = folder / (args.avatar + '_PreservedSkinExpressions_' + args.version + '.glb')
    command('prepare_preserved_skin.py', skin, manifest, prepare)
    command('skin_export.py', skin, prepare, states['Neutral'], glb)
    for state, png in states.items():
        for view in ['front', 'quarter']:
            run('render_prepared_expression.py', glb, folder / ('paid_skin_' + args.version + '_previews') / (state + '_' + view + '.png'), png, 'source-' + view, glb.with_suffix('.json'))
    report = json.loads(glb.with_suffix('.json').read_text(encoding='utf-8'))
    for label, angles in [('head_a', [8, 0, 25]), ('head_b', [-8, 0, -25])]:
        pose = prepared / (label + '.json')
        pose.write_text(json.dumps({'source_sha256': report['sha256'], 'bone_local_euler_degrees': {'Head': angles}}), encoding='utf-8')
        run('render_prepared_expression.py', glb, folder / ('paid_skin_' + args.version + '_pose_previews') / (label + '.png'), states['Neutral'], 'source-front', glb.with_suffix('.json'), '--pose-json', pose)
    command('finalize_skin_assets.py', glb, '--prepare-report', prepare, '--validate-only')
    print(json.dumps({'avatar': args.avatar, 'skin': str(glb), 'sha256': report['sha256'],
                      'baseline_previews': 6, 'head_pose_previews': 2, 'personally_reviewed': False,
                      'ready': False, 'original_bones_claimed': True, 'studio_called': False}), flush=True)


if __name__ == '__main__':
    main()
