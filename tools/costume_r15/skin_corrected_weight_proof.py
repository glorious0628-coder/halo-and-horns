# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
# Still importable as a library ONLY because live tools import it (tools/monster_import_preflight.py,
# tools/test_weapon_motion.py, GLB audit tools). Never run it directly.
"""Read-only proof for the two explicitly selected cape/braid corrections.

Original skin/bind/geometry gates stay exact. Only the sealed reviewed vertex
JOINTS/WEIGHTS rows may differ; this is not a gameplay or native QA approval.
"""
if __name__ == "__main__":
    raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
from pathlib import Path
import json

import numpy as np

from constraints import RigError
from glb_io import read_glb, accessor_values, image_bytes
import correct_skin_weights as correction

ROOT=Path(__file__).resolve().parents[2]
ORIGIN='corrected_preserved_source_skin_proxy_candidate'
RULES={
 'Costume_NeutralArcherF':{
  'folder':'Costume_NeutralArcherF_weights_v7','output':'0fb94b04e5eb38102c547b58a2a8002917a874a2ca6d6c8bea7fb6221bfd5029',
  'baseline':'e9008293bc893ea12bbeb69475db05c900eb829e28a61b3147a39b1f43811f7c',
  'plan':'67159d77a7661e7f23d83ff7ececb12b7f9cecb976ecd98ee78396c047682203',
  'proxy':'c3e765a61dfd966235eb90bbec15c7e3356cf2ad75919197688d236139ceb8b0',
  'runtime':'f8c254effc043b17b4cb41dde0de2e39e7361101d6e433a32bc6c8022d2f59e3','vertices':794},
 'Costume_HornsArcherM':{
  'folder':'Costume_HornsArcherM_weights_v4','output':'6ab861994ce9740468837560a21b8d7e8fe1ac6223c61bb79227db73eb5791d8',
  'baseline':'c793d05d57116691d53e78489f073e53b269af3dd74d61f34fb0f9dd0251fc8c',
  'plan':'42bbf448a379d7ff3cae10c71a071334cde553597a726de8e480d349a12d67d3',
  'proxy':'a928be6856d04791401f59979bf813ea4995fde5520b939093c9e39eed8ce9dc',
  'runtime':'8a34de630e43e9884c0520a5141ea42948cda6c076be8349d0bc35edd43a9e35','vertices':1118},
}

def local_file(value,base=ROOT):
    p=Path(value);p=(base/p).resolve() if not p.is_absolute() else p.resolve()
    p.relative_to(ROOT)
    if p.is_relative_to(ROOT/'art/out/v1') or not p.is_file(): raise RigError('Missing exact local corrected source')
    return p

def seal(path,expected,label):
    if correction.sha(path)!=expected: raise RigError('Exact reviewed correction '+label+' SHA changed')

def validate_surface(baseline,output,plan):
    old,binary,_=read_glb(baseline);new,changed,_=read_glb(output)
    if changed[:len(binary)]!=binary: raise RigError('Original binary prefix changed')
    for key in ('nodes','skins','materials','textures','images','animations','samplers','scenes','scene'):
        if old.get(key)!=new.get(key): raise RigError('Original rest/bind/texture/scene changed: '+key)
    if len(old['skins'])!=1 or len(old['skins'][0]['joints'])!=23 or len(old['meshes'])!=len(new['meshes']):
        raise RigError('Whole original twenty-three-bone/two-mesh source required')
    if new['accessors'][:len(old['accessors'])]!=old['accessors'] or new['bufferViews'][:len(old['bufferViews'])]!=old['bufferViews']:
        raise RigError('Original accessor or buffer view changed')
    if plan.get('region_review_complete') is not True or plan.get('rig_ready_for_game') is not False or not plan.get('reviewed_overlay_images'):
        raise RigError('Reviewed Pending region plan is required')
    names=[old['nodes'][i]['name'] for i in old['skins'][0]['joints']]
    if plan['bone_names']!=names: raise RigError('Correction changed original bone names')
    source_rows={(r['mesh'],r['primitive']):r for r in correction.rows(old,binary)}
    changes={};counts={}
    for row in plan['changes']:
        identity=(row['mesh'],row['primitive'],row['vertex'])
        if identity in changes: raise RigError('Duplicate corrected vertex')
        geometry=source_rows.get(identity[:2]);vertex=identity[2]
        if geometry is None or type(vertex) is not int or not 0<=vertex<len(geometry['values']['POSITION']): raise RigError('Foreign corrected vertex')
        if list(geometry['values']['JOINTS_0'][vertex])!=row['old_joints'] or list(geometry['values']['WEIGHTS_0'][vertex])!=row['old_weights']:
            raise RigError('Old skin weights differ from exact original vertex')
        if list(geometry['values']['TEXCOORD_0'][vertex])!=row['uv'] or not np.allclose(geometry['game_points'][vertex],row['game_position'],atol=1e-10,rtol=0):
            raise RigError('Correction vertex position or UV differs')
        regions=[r for r in plan['regions'] if r['mesh']==geometry['mesh_name'] and correction.region_amount(geometry['game_points'][vertex],r)>1e-4]
        if len(regions)!=1 or row['mesh_name']!=geometry['mesh_name'] or row['region']!=regions[0]['name'] or row['target']!=regions[0]['target']:
            raise RigError('Correction escaped its reviewed geometry region')
        expected=correction.vertex_proposal(row['old_joints'],row['old_weights'],names,geometry['game_points'][vertex],regions[0])
        if expected is None or any(row.get(k,'arms' if k=='transfer' else None)!=v for k,v in expected.items()): raise RigError('Nonmatching reviewed skin redistribution')
        changes[identity]=row;counts[row['region']]=counts.get(row['region'],0)+1
    if counts!=plan['region_counts']: raise RigError('Correction region counts changed')
    observed=set()
    for mi,(om,nm) in enumerate(zip(old['meshes'],new['meshes'])):
        if {k:v for k,v in om.items() if k!='primitives'}!={k:v for k,v in nm.items() if k!='primitives'} or len(om['primitives'])!=len(nm['primitives']):
            raise RigError('Original mesh metadata changed')
        for pi,(op,np_) in enumerate(zip(om['primitives'],nm['primitives'])):
            if {k:v for k,v in op.items() if k!='attributes'}!={k:v for k,v in np_.items() if k!='attributes'} or set(op['attributes'])!=set(np_['attributes']):
                raise RigError('Original triangle/material/primitive changed')
            for attribute,index in op['attributes'].items():
                if attribute not in ('JOINTS_0','WEIGHTS_0') and np_['attributes'][attribute]!=index: raise RigError('Original static P/N/UV changed')
            oj=np.asarray(accessor_values(old,binary,op['attributes']['JOINTS_0']));ow=np.asarray(accessor_values(old,binary,op['attributes']['WEIGHTS_0']))
            nj=np.asarray(accessor_values(new,changed,np_['attributes']['JOINTS_0']));nw=np.asarray(accessor_values(new,changed,np_['attributes']['WEIGHTS_0']))
            if oj.shape!=nj.shape or ow.shape!=nw.shape: raise RigError('Original skin vertex count changed')
            for vi in range(len(oj)):
                identity=(mi,pi,vi);row=changes.get(identity)
                if row is None:
                    if not np.array_equal(oj[vi],nj[vi]) or not np.array_equal(ow[vi],nw[vi]): raise RigError('An unselected original influence changed')
                else:
                    if not np.array_equal(nj[vi],row['new_joints']) or not np.allclose(nw[vi],np.asarray(row['new_weights'],dtype=np.float32),atol=0,rtol=0): raise RigError('Output differs from exact reviewed JW ledger')
                    if np.array_equal(oj[vi],nj[vi]) and np.array_equal(ow[vi],nw[vi]): raise RigError('Listed correction has no actual skin change')
                    observed.add(identity)
    if observed!=set(changes): raise RigError('Ledger contains unused changes')
    for oi,ni in zip(old['images'],new['images']):
        if image_bytes(old,binary,oi)!=image_bytes(new,changed,ni): raise RigError('Original embedded image bytes changed')
    return len(observed)

def validate_package(path):
    path=local_file(path);package=json.loads(path.read_text(encoding='utf-8'))
    name=package.get('name','');name=name if name.startswith('Costume_') else 'Costume_'+name
    rule=RULES.get(name)
    if rule is None or path.parent!=ROOT/'art/models/costume/prepared/skin_corrected'/rule['folder'] or path.name!='package.json':
        raise RigError('Only the two explicit reviewed corrected packages are allowed')
    if package.get('schema')!=1 or package.get('kind')!='corrected_preserved_skin_pending' or package.get('rig_ready_for_game') is not False:
        raise RigError('Explicit corrected Pending package kind is required')
    inputs={}
    for key in ('skin_glb','skin_manifest','proxy_plan','proxy_runtime','weight_correction_plan'):
        value=Path(package[key])
        if value.is_absolute() or '..' in value.parts: raise RigError('Correction package files must be local relative paths')
        inputs[key]=local_file(value,path.parent);inputs[key].relative_to(path.parent)
        seal(inputs[key],package['sha256'][key],key)
    for key,rule_key in (('skin_glb','output'),('proxy_plan','proxy'),('proxy_runtime','runtime'),('weight_correction_plan','plan')):
        seal(inputs[key],rule[rule_key],key)
    baseline=local_file(package['original_benchmark']['workspace_relative_path'])
    seal(baseline,rule['baseline'],'original benchmark')
    if package['original_benchmark']['sha256']!=rule['baseline']: raise RigError('Wrong original benchmark provenance')
    data=json.loads(inputs['skin_manifest'].read_text(encoding='utf-8'));plan=json.loads(inputs['weight_correction_plan'].read_text(encoding='utf-8'))
    if data.get('rig_origin')!=ORIGIN or data.get('schema')!=1 or data.get('rig_ready_for_game') is not False or data.get('output_sha256')!=rule['output']:
        raise RigError('Exact corrected skin sidecar/Pending state is required')
    for key,value in (('original_geometry_uv_normals_material_images_preserved',True),('original_binary_prefix_preserved',True),('original_source_weights_exact',False)):
        if data.get(key) is not value or package.get(key) is not value: raise RigError('Correction preservation claim mismatch: '+key)
    if data.get('original_benchmark_skin_sha256')!=rule['baseline'] or data.get('weight_correction_plan_sha256')!=rule['plan'] or plan['source_skin_sha256']!=rule['baseline']:
        raise RigError('Correction benchmark/plan is not the exact reviewed pair')
    for overlay in plan['reviewed_overlay_images']: seal(local_file(overlay['path']),overlay['sha256'],'reviewed overlay')
    changed=validate_surface(baseline,inputs['skin_glb'],plan)
    if changed!=rule['vertices'] or data.get('changed_skin_vertices')!=changed or package.get('changed_skin_vertices')!=changed:
        raise RigError('Explicit corrected vertex count differs')
    result=dict(data)
    result['corrected_weight_proof']={'schema':1,'name':name,'original_benchmark_skin_sha256':rule['baseline'],'weight_correction_plan_sha256':rule['plan'],
        'corrected_skin_sha256':rule['output'],'changed_skin_vertices':changed,'source_weights_exact':False,'original_geometry_uv_normals_images_bind_preserved':True,
        'package_sha256':correction.sha(path),'proxy_runtime_file':str(inputs['proxy_runtime']),'proxy_runtime_sha256':rule['runtime'],
        'actual_native_validation_claimed':False,'ready':False}
    return result,inputs,package

def validate_sidecar(path):
    path=local_file(path);data=json.loads(path.read_text(encoding='utf-8'))
    for name,rule in RULES.items():
        package_path=ROOT/'art/models/costume/prepared/skin_corrected'/rule['folder']/'package.json'
        if data.get('original_benchmark_skin_sha256')!=rule['baseline'] or data.get('weight_correction_plan_sha256')!=rule['plan']: continue
        verified,inputs,package=validate_package(package_path)
        if path==inputs['skin_manifest']: return verified,inputs,package
        if path.parent!=ROOT/'art/models/costume/expressions'/name or not data.get('expression_manifest') or data.get('rig_origin')!=ORIGIN:
            raise RigError('Corrected expression sidecar is not an exact same-costume expression')
        if data.get('source_sha256')!=verified['source_sha256'] or data.get('proxy_plan_sha256')!=verified['proxy_plan_sha256'] or data.get('bones')!=verified['bones']:
            raise RigError('Corrected expression changed source/bind/proxy metadata')
        original=local_file(data['original_two_surface_skin'])
        seal(original,rule['output'],'expression original corrected skin')
        if original!=inputs['skin_glb'] or data.get('rig_ready_for_game') is not False or data.get('original_source_weights_exact') is not False:
            raise RigError('Wrong corrected expression provenance/Pending claim')
        result=dict(data);result['corrected_weight_proof']=verified['corrected_weight_proof'];return result,inputs,package
    raise RigError('Unknown corrected weight candidate is never inferred')


ASSEMBLE = r'''
    if DATA.corrected_weight_proof then
        local proof=DATA.corrected_weight_proof
        model:SetAttribute("HHC_CorrectedWeightProofSchema",1)
        model:SetAttribute("HHC_CorrectedWeightBenchmarkSHA256",proof.original_benchmark_skin_sha256)
        model:SetAttribute("HHC_CorrectedWeightPlanSHA256",proof.weight_correction_plan_sha256)
        model:SetAttribute("HHC_CorrectedWeightSkinSHA256",proof.corrected_skin_sha256)
        model:SetAttribute("HHC_CorrectedWeightVertexCount",proof.changed_skin_vertices)
        model:SetAttribute("HHC_OriginalSkinWeightsPreserved",false)
    end
'''

VERIFY = r'''
if DATA.corrected_weight_proof then
    local proof=DATA.corrected_weight_proof
    requireCheck(model:GetAttribute("HHC_CorrectedWeightProofSchema")==1
        and model:GetAttribute("HHC_CorrectedWeightBenchmarkSHA256")==proof.original_benchmark_skin_sha256
        and model:GetAttribute("HHC_CorrectedWeightPlanSHA256")==proof.weight_correction_plan_sha256
        and model:GetAttribute("HHC_CorrectedWeightSkinSHA256")==proof.corrected_skin_sha256
        and model:GetAttribute("HHC_CorrectedWeightVertexCount")==proof.changed_skin_vertices
        and model:GetAttribute("HHC_OriginalSkinWeightsPreserved")==false,"명시된 가중치 교정 원본/계획/선택정점")
end
'''
