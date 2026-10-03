"""Build/preview reviewed expression copies, without Studio, uploads or APIs."""
import json
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
BLENDER=Path('C:/Users/glori/Tools/blender-5.2.2/blender.exe')
TOOLS=Path(__file__).resolve().parent

def run(script,*args):
    result=subprocess.run([str(BLENDER),'--background','--factory-startup','--python',str(TOOLS/script),'--',*map(str,args)],cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace')
    if result.returncode or 'Traceback (most recent call last)' in result.stdout+result.stderr:
        raise RuntimeError(result.stdout+'\n'+result.stderr)

def joints_for(avatar):
    profile=ROOT/'art/models/costume/expressions'/avatar/'facial_profile.json'
    override=json.loads(profile.read_text(encoding='utf-8')).get('existing_joints_override') if profile.exists() else None
    return ROOT/override if override else ROOT/'build/costume_r15'/avatar/'joints.json'

if __name__ == '__main__':
    for name in sys.argv[1:]:
        avatar='Costume_'+name
        folder=ROOT/'art/models/costume/expressions'/avatar
        prepared=ROOT/'build/expr_qa'/avatar/'prepared'
        if name=='HaloWarriorM':
            prepared=ROOT/'build/expr_qa/prepared'
            neutral=ROOT/'art/out/Costume_HaloWarriorM_Expression_Neutral_face.png'
        else:
            neutral=folder/(avatar+'_Expression_Neutral_face.png')
            run('prepare_face_uv.py',ROOT/'art/models/costume/fixed'/(avatar+'.glb'),prepared,folder/'facial_profile.json')
        joints=joints_for(avatar)
        head=prepared/(avatar+'_HeadExpressions_R15.glb')
        run('align_head_r15.py',prepared/(avatar+'_FaceExpression_prepared.glb'),neutral,joints,head)
        report=json.loads(head.with_suffix('.json').read_text(encoding='utf-8'))
        for state in ['Neutral']:
            for view,angle in [('front','source-front'),('quarter','source-quarter')]:
                output=prepared/(f'R15_{state}_full_{view}.png')
                run('render_prepared_expression.py',head,output,neutral,angle,head.with_suffix('.json'),joints)
        print(json.dumps({'avatar':avatar,'head':str(head),'affine_residual_max':report['coordinate_mapping_residual_max'],'triangles':report['triangles'],'previews':[str(prepared/'R15_Neutral_full_front.png'),str(prepared/'R15_Neutral_full_quarter.png')]}),flush=True)
