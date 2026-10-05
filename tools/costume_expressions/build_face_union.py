# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Build a new no-cap face-skin candidate and read-only rest/actual-Fx CGs.

Reuses only the previously approved GPT PNGs and original facial triangle scope.
Does not finalize visual review, upload assets or modify the canonical package.
"""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import json
from pathlib import Path
import subprocess
import sys

from build_local_candidate import run

ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source_skin', type=Path)
    parser.add_argument('prepare_report', type=Path)
    parser.add_argument('--version', default='v1')
    parser.add_argument('--source-contract', type=Path, help='Parent portable package for an explicitly identified weight-only corrected source')
    args = parser.parse_args()
    if not args.version.isalnum():
        raise ValueError('Use an alphanumeric new candidate version')
    source = args.source_skin.resolve()
    prep = json.loads(args.prepare_report.read_text(encoding='utf-8'))
    baseline = Path(prep['reviewed_profile']['baseline_manifest'])
    approved = json.loads(baseline.read_text(encoding='utf-8'))
    avatar = approved['avatar']
    folder = ROOT / 'art/models/costume/expressions' / avatar
    output = folder / (avatar + '_FaceUnionSkin_' + args.version + '.glb')
    previews = folder / ('face_union_' + args.version + '_previews')
    neutral = next(r for r in approved['records'] if r['state'] == 'Neutral')
    subprocess.run([sys.executable, str(TOOLS / 'skin_export.py'), str(source),
                    str(args.prepare_report), str(ROOT / neutral['png']), str(output),
                    '--original-triangles-only'], cwd=ROOT, check=True)
    for record in approved['records']:
        for view in ['front', 'quarter']:
            run('render_prepared_expression.py', output,
                previews / (record['state'] + '_' + view + '.png'),
                ROOT / record['png'], 'source-' + view, output.with_suffix('.json'))
    pose_command = [sys.executable, str(TOOLS / 'render_game_neck_qa.py'), str(output),
                    '--version', 'union_' + args.version]
    if args.source_contract:
        pose_command.extend(['--source-contract', str(args.source_contract)])
    subprocess.run(pose_command, cwd=ROOT, check=True)
    subprocess.run([sys.executable, str(TOOLS / 'finalize_skin_assets.py'), str(output),
                    '--prepare-report', str(args.prepare_report), '--validate-only'], cwd=ROOT, check=True)
    print(json.dumps({'glb': str(output), 'rest_previews': str(previews),
                      'game_fx_report': str(ROOT / 'build/expr_qa' / avatar / ('game_fx_neck_union_' + args.version) / 'game_fx_neck_qa.json'),
                      'visual_review_pending': True, 'ready': False, 'studio_called': False}))


if __name__ == '__main__':
    main()
