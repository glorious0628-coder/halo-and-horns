# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Render the untouched two-surface source at the expression Head QA pose."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import hashlib
import json
from pathlib import Path

from build_local_candidate import run

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('expression_glb', type=Path)
    parser.add_argument('--pose', choices=['head_a', 'head_b'], default='head_b')
    args = parser.parse_args()
    expression = args.expression_glb.resolve()
    report = json.loads(expression.with_suffix('.json').read_text(encoding='utf-8'))
    source = Path(report['source_skin']).resolve()
    if hashlib.sha256(source.read_bytes()).hexdigest() != report['source_skin_sha256']:
        raise ValueError('The original two-surface source changed')
    folder = ROOT / 'build/expr_qa' / expression.parent.name / expression.stem
    folder.mkdir(parents=True, exist_ok=True)
    pose = folder / ('original_' + args.pose + '.json')
    angles = [8, 0, 25] if args.pose == 'head_a' else [-8, 0, -25]
    pose.write_text(json.dumps({'source_sha256': report['source_skin_sha256'],
                               'bone_local_euler_degrees': {'Head': angles}}), encoding='utf-8')
    output = expression.parent / (expression.stem + '_source_pose_comparison') / (args.pose + '.png')
    output.parent.mkdir(parents=True, exist_ok=True)
    run('render_prepared_expression.py', source, output, '-', 'source-front',
        expression.with_suffix('.json'), '--pose-json', pose)
    print(json.dumps({'original_source_pose': str(output), 'source_unchanged': True,
                      'expression_ready': False, 'studio_called': False}))


if __name__ == '__main__':
    main()
