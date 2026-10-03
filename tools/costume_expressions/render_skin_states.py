"""Render all already approved skin expression PNGs for offline visual QA."""
import argparse
import json
from pathlib import Path

from build_local_candidate import run,ROOT


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('glb',type=Path)
    parser.add_argument('output_directory',type=Path)
    parser.add_argument('--lit',action='store_true')
    args=parser.parse_args()
    glb=args.glb.resolve();output=args.output_directory.resolve()
    if output.exists():raise ValueError('Use a fresh visual QA directory')
    manifest=json.loads((glb.parent/'expressions_manifest.json').read_text(encoding='utf-8'))
    output.mkdir(parents=True)
    for row in manifest['records']:
        for view in ['front','quarter']:
            image=output/(row['state']+'_'+view+'.png')
            options=[glb,image,ROOT/row['png'],'source-'+view,glb.with_suffix('.json')]
            if args.lit:options.append('--lit')
            run('render_prepared_expression.py',*options)
    print(json.dumps({'output_directory':str(output),'renders':6,'lit':args.lit,'ready':False,'source_unchanged':True}),flush=True)


if __name__=='__main__':main()
