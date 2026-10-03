"""Save a separate, unpromoted mouth-restored manifest and shared-skin contract.

The strict P/N exception validator must pass; normal skin validators stay exact.
Existing original union, canonical cap and rigid baselines are never replaced.
"""
import argparse
import copy
import json
from pathlib import Path
import shutil

import numpy as np

from validate_mouth_restoration import check,ROOT,sha
from finalize_skin_assets import relative
from glb_io import read_glb,accessor_values


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('glb',type=Path)
    parser.add_argument('--rest-directory',type=Path,required=True)
    parser.add_argument('--fx-review',type=Path,required=True)
    parser.add_argument('--negative-tests',type=Path,required=True)
    parser.add_argument('--reviewed',action='store_true')
    args=parser.parse_args()
    if not args.reviewed:raise ValueError('Personally review all six lit rest and six exact-Fx comparisons first')
    glb=args.glb.resolve();folder=glb.parent
    validation=check(glb)
    report=json.loads(glb.with_suffix('.json').read_text(encoding='utf-8'))
    ledger=Path(report['mouth_geometry_restoration_ledger'])
    original_union=Path(json.loads(ledger.read_text(encoding='utf-8'))['input_union'])
    baseline_path=folder/'face_union_manifest.json'
    baseline=json.loads(baseline_path.read_text(encoding='utf-8'))
    if sha(original_union)!=baseline['skin_sha256']:raise ValueError('Exact original union baseline required')
    tests=json.loads(args.negative_tests.read_text(encoding='utf-8'))
    if tests['sha256']!=sha(glb) or not tests['positive'] or not tests['all_rejected'] or len(tests['mutations'])<14:
        raise ValueError('Current strict positive and all negative mutation tests required')
    fx_review=json.loads(args.fx_review.read_text(encoding='utf-8'))
    if fx_review['expression_sha256']!=sha(glb) or not fx_review['personally_reviewed'] or len(fx_review['records'])!=3 or fx_review.get('shading_policy')!='original imported shaded materials':
        raise ValueError('Current personally reviewed lit actual Fx report required')
    fx_path=ROOT/'src/StarterPlayer/StarterPlayerScripts/Fx.luau'
    if fx_review['fx_sha256']!=sha(fx_path):raise ValueError('Reviewed game Fx changed')
    paths={key:folder/filename for key,filename in {
        'manifest':'face_union_mouth_manifest_v1.json',
        'tests':'face_union_mouth_contract_tests_v1.json',
        'compatibility':'face_union_mouth_uv_compatibility_v1.json',
        'review':'face_union_mouth_visual_review_v1.json',
        'runtime':'face_union_mouth_runtime_contract_v1.json'}.items()}
    paths['sidecar']=glb.with_suffix('.skin.json')
    rest_out=folder/'face_union_mouth_v1_previews'
    fx_out=folder/'face_union_mouth_v1_fx_previews'
    if any(p.exists() for p in [*paths.values(),rest_out,fx_out]):raise ValueError('Use a fresh finalized mouth candidate; never replace old evidence')
    validation_path=folder/'face_union_mouth_restoration_validation_v1.json'
    if json.loads(validation_path.read_text(encoding='utf-8'))!=validation:raise ValueError('Saved strict validation differs from current recomputation')
    rest_rows=[]
    for record in baseline['records']:
        if sha(ROOT/record['png'])!=record['sha256']:raise ValueError('Approved GPT PNG changed')
        for view in ['front','quarter']:
            image=args.rest_directory/(record['state']+'_'+view+'.png')
            camera=json.loads(image.with_suffix('.json').read_text(encoding='utf-8'))
            if camera['source_sha256']!=sha(glb) or camera['shading_policy']!='original imported material with geometry QA area lights':
                raise ValueError('Current lit rest view required')
            if camera['expression'] is None or sha(camera['expression'])!=record['sha256']:
                raise ValueError('Lit rest view uses another approved PNG')
            rest_rows.append((record['state'],view,image,camera))
    # Copy finished evidence byte-for-byte; no raster editing.
    rest_out.mkdir();fx_out.mkdir()
    for state,view,image,camera in rest_rows:
        target=rest_out/(state+'_'+view+'.png');shutil.copyfile(image,target)
        camera['render']=str(target)
        target.with_suffix('.json').write_text(json.dumps(camera,indent=2)+'\n',encoding='utf-8')
    reviewed_fx=copy.deepcopy(fx_review)
    for row in reviewed_fx['records']:
        for kind in ['original','expression']:
            image=ROOT/row[kind+'_render'];camera_path=ROOT/row[kind+'_render_metadata']
            if sha(image)!=row[kind+'_render_sha256'] or sha(camera_path)!=row[kind+'_render_metadata_sha256']:
                raise ValueError('Reviewed Fx image or exact pose metadata changed')
            target=fx_out/image.name;shutil.copyfile(image,target)
            camera=json.loads(camera_path.read_text(encoding='utf-8'));camera['render']=str(target)
            target.with_suffix('.json').write_text(json.dumps(camera,indent=2)+'\n',encoding='utf-8')
            row[kind+'_render']=relative(target);row[kind+'_render_sha256']=sha(target)
            row[kind+'_render_metadata']=relative(target.with_suffix('.json'));row[kind+'_render_metadata_sha256']=sha(target.with_suffix('.json'))
    reviewed_fx.update(rest_previews_personally_reviewed=True,rest_shading_policy='original imported material with geometry QA area lights',
                       ready=False,runtime_validated=False,roblox_uploaded=False)
    paths['review'].write_text(json.dumps(reviewed_fx,indent=2)+'\n',encoding='utf-8')
    paths['tests'].write_text(json.dumps(tests,indent=2)+'\n',encoding='utf-8')
    compatibility=json.loads((folder/'face_union_uv_compatibility.json').read_text(encoding='utf-8'))
    compatibility.update(expression_skin_sha256=sha(glb),comparison_union=relative(original_union),comparison_union_sha256=sha(original_union),
                         original_geometry_preserved=False,geometry_exception='recorded original mouth P/N only',
                         mouth_restoration_ledger=relative(ledger),mouth_restoration_ledger_sha256=sha(ledger))
    paths['compatibility'].write_text(json.dumps(compatibility,indent=2)+'\n',encoding='utf-8')
    manifest=copy.deepcopy(baseline)
    manifest.update(skin_asset=relative(glb),skin_sha256=sha(glb),validation_report=relative(validation_path),
                    geometry_comparison_only=False,visual_quality_hold=fx_review.get('visual_quality_hold',False),
                    validation_kind='original_connected_mouth_pn_exception_v1',candidate_variant='original_triangle_union_mouth_restored_v1',
                    original_geometry_preserved=False,original_position_normal_values_preserved=False,
                    original_joint_weight_values_preserved=True,
                    mouth_restoration_ledger=relative(ledger),mouth_restoration_ledger_sha256=sha(ledger),
                    strict_validation_tool='tools/costume_expressions/validate_mouth_restoration.py',
                    original_face_provenance_role='baseline source vertices/UV/JW; P/N exception is the separate mouth ledger',
                    original_union_baseline=relative(baseline_path),original_union_baseline_sha256=sha(baseline_path),
                    uv_texture_compatibility=relative(paths['compatibility']),uv_texture_compatibility_sha256=sha(paths['compatibility']),
                    game_fx_offline_review=relative(paths['review']),game_fx_offline_review_sha256=sha(paths['review']),
                    mouth_negative_tests=relative(paths['tests']),mouth_negative_tests_sha256=sha(paths['tests']),
                    offline_visual_review='All six shaded front/quarter states and six exact Fx original/expression comparisons personally reviewed.',
                    offline_visual_notes=fx_review['review_notes'],
                    limitations=['Only original mouth P/N restored in bounded ledger; body, UV, JW, all original bones and PNG remain exact.',
                                 'Original mixed-weight shallow wrinkle remains at Swing/Release; actual imported mesh and full Animator quality are pending.'],
                    ready=False,runtime_validated=False,roblox_uploaded=False)
    for record in manifest['records']:
        record['offline_previews']=[relative(rest_out/(record['state']+'_'+view+'.png')) for view in ['front','quarter']]
        record['quality_status']='lit rest states and exact game Fx personally reviewed; native game quality pending'
        record['closed_mouth_offline_render_verified']=True
    paths['manifest'].write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    contract=json.loads(original_union.with_suffix('.skin.json').read_text(encoding='utf-8'))
    doc,binary,_=read_glb(glb)
    frame=np.asarray(contract['source_to_game_affine']).reshape(4,4,order='F')
    rows=copy.deepcopy(contract['expression_surfaces'])
    def bbox(points):
        lo,hi=points.min(axis=0),points.max(axis=0)
        return dict(minimum=lo.tolist(),maximum=hi.tolist(),center=((lo+hi)/2).tolist(),size=(hi-lo).tolist())
    for row in rows:
        primitive=doc['meshes'][row['mesh']]['primitives'][0]
        points=np.asarray(accessor_values(doc,binary,primitive['attributes']['POSITION']))
        indices=np.asarray(accessor_values(doc,binary,primitive['indices']),int).reshape(-1)
        active=points[indices]
        row.update(referenced_source_bounds=bbox(active),full_accessor_source_bounds=bbox(points),
                   referenced_game_bounds=bbox((np.column_stack((active,np.ones(len(active))))@frame.T)[:,:3]))
    contract.update(output=str(glb),output_sha256=sha(glb),expression_manifest=relative(paths['manifest']),expression_manifest_sha256=sha(paths['manifest']),
                    expression_validation=relative(validation_path),expression_validation_sha256=sha(validation_path),
                    expression_validation_kind=manifest['validation_kind'],expression_original_mouth_pn_restored=True,
                    expression_mouth_ledger=relative(ledger),expression_mouth_ledger_sha256=sha(ledger),
                    expression_surfaces=rows,rig_ready_for_game=False,studio_motion_validated=False,expression_runtime_validated=False,
                    expression_face_unused_original_head_positions_preserved=True,
                    expression_unused_positions_policy='Unused original vertices exact; recorded P/N exception applies only to original Face-active or coincident boundary copies.',
                    api_called=False,uploads=0)
    contract['meshes']=rows if isinstance(contract['meshes'],list) else 3
    paths['sidecar'].write_text(json.dumps(contract,indent=2)+'\n',encoding='utf-8')
    runtime={'schema':1,'avatar':folder.name,'candidate_variant':manifest['candidate_variant'],
             'glb':relative(glb),'glb_sha256':sha(glb),'sidecar':relative(paths['sidecar']),'sidecar_sha256':sha(paths['sidecar']),
             'manifest':relative(paths['manifest']),'manifest_sha256':sha(paths['manifest']),
             'strict_validator':manifest['strict_validation_tool'],'strict_validation_kind':manifest['validation_kind'],
             'shared_skin_runtime_contract':'tools/costume_expressions/skin_runtime_contract.json',
             'required_skin_runtime_schema':2,'required_expression_skin_runtime_schema':1,
             'root_weld_and_actual_shared_bone_host_required':True,
             'original_face_triangle_count':baseline['selected_original_face_triangles'],'mouth_changed_original_vertices':validation['changed_original_mouth_vertices'],
             'geometry_scope':'Only ledger-listed original connected mouth P/N; HeadBase and Face share exact P/N accessors.',
             'new_vertices':0,'new_triangles':0,'body_uv_jw_original_bones_png_exact':True,
             'ready':False,'runtime_validated':False,'roblox_uploaded':False,
             'actual_import_mesh_ids_required':True,'existing_png_texture_ids_reusable_only_after_upload_ledger_sha_match':True}
    paths['runtime'].write_text(json.dumps(runtime,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'manifest':str(paths['manifest']),'sidecar':str(paths['sidecar']),'glb_sha256':sha(glb),'ready':False}),flush=True)


if __name__=='__main__':main()
