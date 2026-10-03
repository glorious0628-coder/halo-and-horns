"""Save reviewed offline head assets and validate provenance (no raster edits)."""
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
TRIGGERS={'Neutral':'평소','SoftSmile':'NPC/유저 대화','Serious':'공격/피격'}
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

for name in sys.argv[1:]:
    avatar='Costume_'+name
    folder=ROOT/'art/models/costume/expressions'/avatar
    profile_path=folder/'facial_profile.json'
    profile=json.loads(profile_path.read_text(encoding='utf-8')) if profile_path.exists() else {}
    visual_notes=profile.get('offline_visual_notes',[])
    prepared=ROOT/'build/expr_qa'/avatar/'prepared'
    if name=='HaloWarriorM':prepared=ROOT/'build/expr_qa/prepared'
    head=prepared/(avatar+'_HeadExpressions_R15.glb')
    target=folder/head.name
    shutil.copy2(head,target)
    report=json.loads(head.with_suffix('.json').read_text(encoding='utf-8'))
    report['glb']=str(target);target.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    shutil.copy2(prepared/'prepare_report.json',folder/'prepare_report.json')
    previews=folder/'previews';previews.mkdir(exist_ok=True)
    records=[]
    pilot=None
    if name=='HaloWarriorM':pilot=json.loads((folder/'expressions_manifest.json').read_text(encoding='utf-8'))
    for state in TRIGGERS:
        if pilot:
            record=next(r.copy() for r in pilot['records'] if r['state']==state)
        else:
            texture=folder/(avatar+'_Expression_'+state+'_face.png')
            record=json.loads(texture.with_suffix('.json').read_text(encoding='utf-8'))
        record.update(trigger=TRIGGERS[state],closed_mouth_offline_render_verified=True,roblox_uploaded=False,runtime_validated=False,quality_status='offline front and quarter reviewed; Roblox runtime pending')
        record['offline_visual_notes']=visual_notes
        record['offline_previews']=[]
        for view in ['front','quarter']:
            preview=prepared/(f'R15_{state}_full_{view}.png')
            preview_report=json.loads(preview.with_suffix('.json').read_text(encoding='utf-8'))
            if preview_report['source_sha256']!=sha(head):raise ValueError('Stale preview '+str(preview))
            output=previews/(state+'_'+view+'.png');shutil.copy2(preview,output)
            preview_report.update(source=str(target),render=str(output))
            output.with_suffix('.json').write_text(json.dumps(preview_report,indent=2)+'\n',encoding='utf-8')
            record['offline_previews'].append(output.relative_to(ROOT).as_posix())
        records.append(record)
        if not pilot:
            (folder/(avatar+'_Expression_'+state+'_face.json')).write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    manifest={'avatar':avatar,'approval_preview':'art/out/Avatar_Expressions_Preview_A.png','approved_states':list(TRIGGERS),'approved_human_avatar_scope':18,'target_total_textures':54,'actual_preferred_textures':3,'head_asset':target.relative_to(ROOT).as_posix(),'head_sha256':sha(target),'import_asset_budget':5,'extra_expression_pngs_outside_glb':2,'full_set_maximum_import_assets':7,'needs_new_head_mesh_import':True,'body_reimport_required':report.get('body_reimport_required',False),'body_parts_reimport_required':report.get('body_parts_reimport_required',[]),'original_models_unchanged':True,'studio_untouched':True,'paid_api_calls':0,'uploads':0,'records':records,'runtime_validated':False,'offline_visual_review':'All three state front and 30-degree quarter renders reviewed with unchanged original body context; mouth closed and old duplicate brows checked','limitations':['Roblox head import, texture upload, automatic state switching and runtime QA remain.','Other human avatars require their own reviewed facial profiles and actual offline previews.']}
    manifest['assembly_requirements']=report.get('assembly_requirements',{})
    manifest['offline_visual_notes']=visual_notes
    manifest_path=folder/'expressions_manifest.json';manifest_path.write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    result=subprocess.run([sys.executable,str(Path(__file__).with_name('validate_expression_assets.py')),str(manifest_path),'--output',str(folder/'validation.json')],cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace')
    if result.returncode:raise RuntimeError(result.stdout+result.stderr)
    print(result.stdout.strip(),flush=True)
