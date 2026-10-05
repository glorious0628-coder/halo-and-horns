# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Compare original/expression shared skins at existing game Fx keyframes.

Uses actual proxy Part bind CFrames and Motor C0/C1 FK, not original Bone Euler
angles. The stock Animator layer is identity here; native gameplay remains QA.
"""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

from build_local_candidate import run

ROOT = Path(__file__).resolve().parents[2]
PARTS = {'Waist':'UpperTorso','Neck':'Head','RightShoulder':'RightUpperArm',
         'RightElbow':'RightLowerArm','RightWrist':'RightHand','LeftShoulder':'LeftUpperArm',
         'LeftElbow':'LeftLowerArm','LeftWrist':'LeftHand'}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def sample(text, clip, time):
    block = text.split('\t\t' + clip + ' = {', 1)[1].split('\n\t\t} },', 1)[0]
    lines = [line for line in block.splitlines()
             if re.match(r'\s*\{\s*' + re.escape(str(time)) + r'\s*,', line)]
    if len(lines) != 1:
        raise ValueError('Existing Fx clip must have exactly the selected keyframe')
    result = {}
    for joint, values in re.findall(r'(\w+)\s*=\s*\{\s*([^{}]+)\s*\}', lines[0]):
        if joint not in PARTS:
            raise ValueError('Unexpected Fx upper-body joint')
        result[PARTS[joint]] = [float(x.strip()) for x in values.split(',')]
    if 'Head' not in result or any(len(v)!=3 for v in result.values()):
        raise ValueError('Explicit game Neck XYZ sample required')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('expression_glb', type=Path)
    parser.add_argument('--version', default='v1')
    parser.add_argument('--source-contract', type=Path, help='Original parent package for an explicitly identified weight-only correction candidate')
    parser.add_argument('--lit', action='store_true', help='Use original shaded materials to expose physical mouth recesses')
    args = parser.parse_args()
    expression = args.expression_glb.resolve()
    report = json.loads(expression.with_suffix('.json').read_text(encoding='utf-8'))
    original = Path(report['source_skin']).resolve()
    original_sidecar = original.with_suffix('.skin.json')
    package_path = args.source_contract.resolve() if args.source_contract else original.parent/'package.json'
    package = json.loads(package_path.read_text(encoding='utf-8'))
    runtime = package_path.parent/package['proxy_runtime']
    if sha(original) != report['source_skin_sha256'] or sha(runtime) != package['sha256']['proxy_runtime']:
        raise ValueError('Exact original skin and portable runtime package required')
    if sha(original) != package['sha256']['skin_glb']:
        if not args.source_contract:
            raise ValueError('Explicit parent package required for a corrected skin candidate')
        sidecar = json.loads(original_sidecar.read_text(encoding='utf-8'))
        if sidecar.get('parent_correction_skin_sha256') != package['sha256']['skin_glb'] or not sidecar.get('weight_correction_chain'):
            raise ValueError('Weight-only candidate does not identify this exact parent skin')
        parent = Path(sidecar['parent_correction_skin'])
        if sha(parent) != package['sha256']['skin_glb']:
            raise ValueError('Original parent corrected skin changed')
        sys.path.insert(0, str(ROOT/'tools/costume_r15'))
        import numpy as np
        from glb_io import read_glb, accessor_values, image_bytes
        pdoc,pbinary,_ = read_glb(parent)
        cdoc,cbinary,_ = read_glb(original)
        if cdoc['skins'] != pdoc['skins'] or len(cdoc['meshes']) != 2:
            raise ValueError('Weight correction changed original skin/bone structure')
        for cp,pp in zip(cdoc['meshes'],pdoc['meshes']):
            cp,pp = cp['primitives'][0],pp['primitives'][0]
            for key in ['POSITION','NORMAL','TEXCOORD_0']:
                if not np.array_equal(accessor_values(cdoc,cbinary,cp['attributes'][key]),accessor_values(pdoc,pbinary,pp['attributes'][key])):
                    raise ValueError('Weight correction changed original geometry or UV')
            if not np.array_equal(accessor_values(cdoc,cbinary,cp['indices']),accessor_values(pdoc,pbinary,pp['indices'])):
                raise ValueError('Weight correction changed original triangles')
        if cdoc['materials'] != pdoc['materials'] or [image_bytes(cdoc,cbinary,i) for i in cdoc['images']] != [image_bytes(pdoc,pbinary,i) for i in pdoc['images']]:
            raise ValueError('Weight correction changed original material or PNG')
        for correction in sidecar['weight_correction_chain']:
            if sha(correction['path']) != correction['sha256']:
                raise ValueError('Recorded explicit weight correction ledger changed')
    baseline = json.loads((expression.parent/'expressions_manifest.json').read_text(encoding='utf-8'))
    serious = ROOT/next(record['png'] for record in baseline['records'] if record['state']=='Serious')
    fx = ROOT/'src/StarterPlayer/StarterPlayerScripts/Fx.luau'
    fx_text = fx.read_text(encoding='utf-8')
    name = expression.parent.name
    clip_samples = [('WarriorSwing',0.17),('WarriorRelease',0.24)] if 'Warrior' in name else [('MageSwing',0.19),('MageRelease',0.33)] if 'Mage' in name else [('ArcherSwing',0.19),('ArcherRelease',0.16)]
    clip_samples.append(('HurtBig',0.06))
    output = ROOT/'build/expr_qa'/name/('game_fx_neck_'+args.version)
    if output.exists():
        raise ValueError('Use a new diagnostic version')
    output.mkdir(parents=True)
    records = []
    for clip,time in clip_samples:
        degrees = sample(fx_text,clip,time)
        label = clip + '_' + str(time).replace('.','_')
        record = {'clip':clip,'time_seconds':time,'proxy_rotation_degrees':degrees,
                  'animator_base_layer':'identity; stock Animate not captured offline',
                  'fx_sha256':sha(fx)}
        for variant,source,png in [('original',original,'-'),('expression',expression,serious)]:
            pose = {'source_sha256':sha(source),'original_skin_sidecar':str(original_sidecar),
                    'original_skin_sidecar_sha256':sha(original_sidecar),'proxy_runtime':str(runtime),
                    'proxy_runtime_sha256':sha(runtime),'proxy_rotation_degrees':degrees,
                    'pose_source':{'file':str(fx),'sha256':sha(fx),'clip':clip,'time_seconds':time}}
            pose_path = output/(label+'_'+variant+'_pose.json')
            pose_path.write_text(json.dumps(pose,indent=2)+'\n',encoding='utf-8')
            image = output/(label+'_'+variant+'.png')
            render_args = [source,image,png,'source-front',expression.with_suffix('.json')]
            if args.lit:
                render_args.append('--lit')
            run('render_prepared_expression.py',*render_args,'--pose-json',pose_path)
            record[variant+'_render'] = str(image)
        records.append(record)
    result = {'schema':1,'avatar':name,'expression_sha256':sha(expression),
              'original_skin_sha256':sha(original),'fx_sha256':sha(fx),
              'original_proxy_package':str(package_path),'original_proxy_package_sha256':sha(package_path),
              'pose_basis':'actual proxy parts[].cframe and joints[].C0/C1 FK into all original shared Bone matrices',
              'shading_policy':'original imported shaded materials' if args.lit else 'flat emission texture colors',
              'records':records,'personally_reviewed':False,'runtime_validated':False,
              'ready':False,'studio_called':False,'paid_api_calls':0}
    (output/'game_fx_neck_qa.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'output':str(output),'game_pose_comparisons':3,'images':6,'ready':False}))


if __name__ == '__main__':
    main()
