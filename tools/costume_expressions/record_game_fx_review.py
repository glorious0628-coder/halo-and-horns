"""Save personally reviewed Fx CG evidence without changing any asset manifest."""
import argparse
import copy
import json
from pathlib import Path

from finalize_skin_assets import ROOT, relative, sha


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--reviewed', action='store_true')
    parser.add_argument('--quality-hold', action='store_true')
    parser.add_argument('--notes', required=True)
    args = parser.parse_args()
    if not args.reviewed or args.output.exists():
        raise ValueError('New review file and personal review of all six CGs required')
    report = copy.deepcopy(json.loads(args.report.read_text(encoding='utf-8')))
    fx = ROOT / 'src/StarterPlayer/StarterPlayerScripts/Fx.luau'
    if report['fx_sha256'] != sha(fx) or len(report['records']) != 3:
        raise ValueError('Current actual Fx source and three exact pose pairs required')
    for row in report['records']:
        for kind in ['original', 'expression']:
            path = Path(row[kind + '_render'])
            camera_path = path.with_suffix('.json')
            camera = json.loads(camera_path.read_text(encoding='utf-8'))
            expected = report['original_skin_sha256'] if kind == 'original' else report['expression_sha256']
            if camera['source_sha256'] != expected or sha(camera['source']) != expected:
                raise ValueError('Reviewed CG belongs to another original or expression skin')
            if camera['maximum_proxy_part_bind_reproduction_error'] > 1e-5 or camera['maximum_desired_bone_matrix_error'] > 1e-4:
                raise ValueError('Proxy part C0/C1 FK and original shared Bone pose differ')
            row[kind + '_render'] = relative(path)
            row[kind + '_render_sha256'] = sha(path)
            row[kind + '_render_metadata'] = relative(camera_path)
            row[kind + '_render_metadata_sha256'] = sha(camera_path)
    report.update(report_source=relative(args.report), report_source_sha256=sha(args.report),
                  personally_reviewed=True, visual_quality_hold=args.quality_hold,
                  review_notes=args.notes, offline_only=True, ready=False, runtime_validated=False,
                  limitations=['Stock Animate base layer is identity offline.',
                               'Actual importer, Animator, physics, growth and three-state switching remain separate engine QA.'])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'output': str(args.output), 'avatar': report['avatar'],
                      'personally_reviewed': True, 'visual_quality_hold': args.quality_hold,
                      'ready': False, 'studio_called': False}))


if __name__ == '__main__':
    main()
