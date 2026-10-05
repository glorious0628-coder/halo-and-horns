# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Reprove a weight-only source and retain the exact ray-proven mouth scope."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import copy
import json
from pathlib import Path
import subprocess
import sys

from skin_frames import resolve

TOOLS = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source_skin', type=Path)
    parser.add_argument('extended_prepare', type=Path)
    parser.add_argument('output_directory', type=Path)
    args = parser.parse_args()
    old = json.loads(args.extended_prepare.read_text(encoding='utf-8'))
    if args.output_directory.exists():
        raise ValueError('Use a new source preparation directory')
    args.output_directory.mkdir(parents=True)
    output = args.output_directory/'prepare_report.json'
    baseline = old['reviewed_profile']['baseline_manifest']
    subprocess.run([sys.executable, str(TOOLS/'prepare_preserved_skin.py'),
                    str(args.source_skin), baseline, str(output)], check=True)
    current = json.loads(output.read_text(encoding='utf-8'))
    if old.get('verified_original_face_union_extension'):
        current['original_facial_uv_signatures'] = copy.deepcopy(old['original_facial_uv_signatures'])
        current['verified_original_face_union_extension'] = copy.deepcopy(old['verified_original_face_union_extension'])
        current['previous_verified_union_extensions'] = copy.deepcopy(old.get('previous_verified_union_extensions', []))
        sidecar = json.loads(args.source_skin.with_suffix('.skin.json').read_text(encoding='utf-8'))
        resolve(current, args.source_skin, sidecar)
        output.write_text(json.dumps(current, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'prepare_report': str(output), 'face_scope_triangles': len(current['original_facial_uv_signatures']),
                      'reused_exact_ray_proven_mouth_scope': bool(old.get('verified_original_face_union_extension')),
                      'ready': False, 'studio_called': False}))


if __name__ == '__main__':
    main()
