"""Render all already approved skin expression PNGs for offline visual QA."""
import argparse
import json
from pathlib import Path
import hashlib

from build_local_candidate import run,ROOT


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('glb',type=Path)
    parser.add_argument('output_directory',type=Path)
    parser.add_argument('--lit',action='store_true')
    parser.add_argument('--manifest',type=Path,help='Explicit approved PNG manifest for inferred manual skins')
    args=parser.parse_args()
    glb=args.glb.resolve();output=args.output_directory.resolve()
    if output.exists():raise ValueError('Use a fresh visual QA directory')
    manifest_path=args.manifest.resolve() if args.manifest else glb.parent/'expressions_manifest.json'
    manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
    if {row['state'] for row in manifest['records']}!={'Neutral','SoftSmile','Serious'} or len(manifest['records'])!=3:
        raise ValueError('Exactly the three approved states are required')
    for row in manifest['records']:
        if hashlib.sha256((ROOT/row['png']).read_bytes()).hexdigest()!=row['sha256']:
            raise ValueError('Approved expression PNG changed')
    output.mkdir(parents=True)
    for row in manifest['records']:
        for view in ['front','quarter']:
            image=output/(row['state']+'_'+view+'.png')
            options=[glb,image,ROOT/row['png'],'source-'+view,glb.with_suffix('.json')]
            if args.lit:options.append('--lit')
            run('render_prepared_expression.py',*options)
    print(json.dumps({'output_directory':str(output),'renders':6,'lit':args.lit,'ready':False,'source_unchanged':True}),flush=True)


if __name__=='__main__':main()
