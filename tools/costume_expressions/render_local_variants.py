"""Render existing local expression candidates with original full-body context."""
import json
import sys
from build_local_candidate import ROOT, run, joints_for

for name in sys.argv[1:]:
    avatar='Costume_'+name
    folder=ROOT/'art/models/costume/expressions'/avatar
    prepared=ROOT/'build/expr_qa'/avatar/'prepared'
    if name=='HaloWarriorM':prepared=ROOT/'build/expr_qa/prepared'
    head=prepared/(avatar+'_HeadExpressions_R15.glb')
    joints=joints_for(avatar)
    for state in ['SoftSmile','Serious']:
        texture=folder/(avatar+'_Expression_'+state+'_face.png')
        if name=='HaloWarriorM':texture=ROOT/'art/out'/(avatar+'_Expression_'+state+'_face.png')
        for view,angle in [('front','source-front'),('quarter','source-quarter')]:
            run('render_prepared_expression.py',head,prepared/(f'R15_{state}_full_{view}.png'),texture,angle,head.with_suffix('.json'),joints)
    print(json.dumps({'avatar':avatar,'variants_rendered':['SoftSmile','Serious']}),flush=True)
