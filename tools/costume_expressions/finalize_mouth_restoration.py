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
    mode=parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--fx-review',type=Path)
    mode.add_argument('--basic-motion-directory',type=Path)
    parser.add_argument('--full-body-directory',type=Path)
    parser.add_argument('--negative-tests',type=Path,required=True)
    parser.add_argument('--winding',action='store_true',help='Require the separate strict original-mouth winding exception')
    parser.add_argument('--version',default='v1',help='Alphanumeric new finalized evidence version')
    parser.add_argument('--union-manifest',type=Path,help='Exact explicit parent union manifest; source SHA remains strict')
    parser.add_argument('--reviewed',action='store_true')
    args=parser.parse_args()
    if not args.reviewed:raise ValueError('Personally review all six lit rest and requested motion/body views first')
    if not args.version.isalnum():raise ValueError('Use an alphanumeric new version')
    glb=args.glb.resolve();folder=glb.parent
    if args.winding:
        from validate_mouth_winding import check as winding_check
        validation=winding_check(glb)
    else:
        validation=check(glb)
    report=json.loads(glb.with_suffix('.json').read_text(encoding='utf-8'))
    ledger=Path(report['mouth_geometry_restoration_ledger'])
    original_union=Path(json.loads(ledger.read_text(encoding='utf-8'))['input_union'])
    baseline_path=args.union_manifest.resolve() if args.union_manifest else folder/'face_union_manifest.json'
    baseline=json.loads(baseline_path.read_text(encoding='utf-8'))
    if sha(original_union)!=baseline['skin_sha256']:raise ValueError('Exact original union baseline required')
    tests=json.loads(args.negative_tests.read_text(encoding='utf-8'))
    if tests['sha256']!=sha(glb) or not tests['positive'] or not tests['all_rejected'] or len(tests['mutations'])<(15 if args.winding else 14):
        raise ValueError('Current strict positive and all negative mutation tests required')
    basic=args.basic_motion_directory is not None
    body=None
    if basic:
        if not args.full_body_directory or baseline['rig_origin']!='inferred_manual_candidate' or baseline['original_bones_claimed'] or baseline['source_skin_bones']!=15:
            raise ValueError('Basic review mode requires exact inferred 15-bone source and full-body review')
        motion=json.loads((args.basic_motion_directory/'skin_motion_qa.json').read_text(encoding='utf-8'))
        if motion['skin_sha256']!=sha(glb) or motion['rig_origin']!='inferred_manual_candidate' or not motion['actual_imported_armature_rendered'] or not motion['offline_linear_blend_skinning'] or motion['source_or_texture_edits']!=0 or motion['rig_ready_for_game'] or motion['studio_motion_validated']:
            raise ValueError('Current unpromoted actual Armature/LBS basic-motion evidence required')
        for pose in ['rest','walk_left','walk_right','head_turn']:
            row=motion['poses'][pose]
            if max(row['maximum_shared_position_gap'],row['maximum_actual_armature_vs_lbs_error'])>1e-5:
                raise ValueError('Basic skin continuity or actual Armature/LBS comparison failed')
            for view in ['front','side']:
                if not (args.basic_motion_directory/(pose+'_'+view+'.png')).is_file():raise ValueError('Required basic motion image missing')
        fx_review={'schema':1,'expression_sha256':sha(glb),'personally_reviewed':True,'review_scope':'inferred-15 actual Armature rest, walk-left/right and head-turn; not game Fx/Animate',
                   'game_fx_verified':False,'stock_animate_verified':False,'visual_quality_hold':False,'records':[],
                   'review_notes':['Six lit expression closeups and three full-body views have natural closed-mouth lines without a raised round cap.',
                                  'Eight actual Armature rest/walk/head-turn views preserve the face/neck surface and modest full outfit. Native idle/walk/FQ/ONOFF remain pending.']}
    else:
        fx_review=json.loads(args.fx_review.read_text(encoding='utf-8'))
        if fx_review['expression_sha256']!=sha(glb) or not fx_review['personally_reviewed'] or len(fx_review['records'])!=3 or fx_review.get('shading_policy')!='original imported shaded materials':
            raise ValueError('Current personally reviewed lit actual Fx report required')
        fx_path=ROOT/'src/StarterPlayer/StarterPlayerScripts/Fx.luau'
        if fx_review['fx_sha256']!=sha(fx_path):raise ValueError('Reviewed game Fx changed')
    if args.full_body_directory:
        body=json.loads((args.full_body_directory/'full_body_qa.json').read_text(encoding='utf-8'))
        if {row['view'] for row in body['records']}!={'front','back','side'} or body['ready'] or not body['source_unchanged']:
            raise ValueError('Unpromoted exact full-body views required')
        for row in body['records']:
            if row['source_sha256']!=sha(glb) or sha(Path(row['render']))!=row['render_sha256'] or row['shading_policy']!='original imported material; full-body lit QA':raise ValueError('Full-body candidate or image changed')
    paths={key:folder/((filename.replace('face_union_mouth_','face_union_mouth_winding_') if args.winding else filename).replace('_v1.json','_'+args.version+'.json')) for key,filename in {
        'manifest':'face_union_mouth_manifest_v1.json',
        'tests':'face_union_mouth_contract_tests_v1.json',
        'compatibility':'face_union_mouth_uv_compatibility_v1.json',
        'review':'face_union_mouth_visual_review_v1.json',
        'runtime':'face_union_mouth_runtime_contract_v1.json'}.items()}
    paths['sidecar']=glb.with_suffix('.skin.json')
    stem=('face_union_mouth_winding_' if args.winding else 'face_union_mouth_')+args.version
    rest_out=folder/(stem+'_previews')
    fx_out=folder/(stem+('_basic_previews' if basic else '_fx_previews'))
    body_out=folder/(stem+'_full_body_previews') if body else None
    if any(p.exists() for p in [*paths.values(),rest_out,fx_out,*([body_out] if body else [])]):raise ValueError('Use a fresh finalized mouth candidate; never replace old evidence')
    validation_path=folder/(('face_union_mouth_winding_validation_' if args.winding else 'face_union_mouth_restoration_validation_')+args.version+'.json')
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
    if basic:
        reviewed_fx['motion_numeric_report']=motion
        reviewed_fx['basic_motion_images']=[]
        for pose in ['rest','walk_left','walk_right','head_turn']:
            for view in ['front','side']:
                image=args.basic_motion_directory/(pose+'_'+view+'.png');target=fx_out/image.name
                shutil.copyfile(image,target)
                reviewed_fx['basic_motion_images'].append({'pose':pose,'view':view,'render':relative(target),'sha256':sha(target)})
    if body:
        body_out.mkdir()
        reviewed_fx['full_body_images']=[]
        for row in body['records']:
            target=body_out/(row['view']+'.png');shutil.copyfile(row['render'],target)
            camera=copy.deepcopy(row);camera['render']=str(target)
            target.with_suffix('.json').write_text(json.dumps(camera,indent=2)+'\n',encoding='utf-8')
            reviewed_fx['full_body_images'].append({'view':row['view'],'render':relative(target),'sha256':sha(target),'metadata':relative(target.with_suffix('.json')),'metadata_sha256':sha(target.with_suffix('.json'))})
        reviewed_fx.update(full_body_personally_reviewed=True,modest_outfit_offline_verified=True)
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
    compatibility=json.loads((ROOT/baseline['uv_texture_compatibility']).read_text(encoding='utf-8'))
    if sha(ROOT/baseline['uv_texture_compatibility'])!=baseline['uv_texture_compatibility_sha256']:raise ValueError('Exact parent union UV compatibility changed')
    compatibility.update(expression_skin_sha256=sha(glb),comparison_union=relative(original_union),comparison_union_sha256=sha(original_union),
                         original_geometry_preserved=False,geometry_exception='recorded original mouth P/N only',
                         mouth_restoration_ledger=relative(ledger),mouth_restoration_ledger_sha256=sha(ledger))
    if args.winding:
        compatibility.update(geometry_exception='recorded original mouth P/N and listed inward mouth-wall index order only',
                             mouth_winding_ledger=relative(report['mouth_winding_ledger']),mouth_winding_ledger_sha256=report['mouth_winding_ledger_sha256'])
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
    if args.winding:
        winding=json.loads(Path(report['mouth_winding_ledger']).read_text(encoding='utf-8'))
        manifest.update(validation_kind='original_connected_mouth_pn_winding_exception_v1',candidate_variant='original_triangle_union_mouth_winding_v1',
                        strict_validation_tool='tools/costume_expressions/validate_mouth_winding.py',
                        mouth_winding_ledger=relative(report['mouth_winding_ledger']),mouth_winding_ledger_sha256=report['mouth_winding_ledger_sha256'],
                        parent_mouth_asset=relative(winding['input_mouth_glb']),parent_mouth_sha256=winding['input_mouth_glb_sha256'],
                        original_oriented_triangle_indices_preserved=False,original_triangle_vertex_sets_preserved=True,
                        changed_original_mouth_triangles=validation['changed_original_mouth_triangles'])
    if basic:
        manifest.pop('game_fx_offline_review',None);manifest.pop('game_fx_offline_review_sha256',None)
        manifest.update(basic_motion_offline_review=relative(paths['review']),basic_motion_offline_review_sha256=sha(paths['review']),
                        game_fx_offline_verified=False,stock_animate_verified=False,modest_outfit_offline_verified=True,
                        offline_visual_review='Six shaded front/quarter expressions, three full-body views and eight actual Armature rest/walk/head-turn views personally reviewed.',
                        limitations=['15 bones are inferred from reviewed landmarks; original Tripo bones are not claimed.',
                                     'Only exact ledger-listed mouth P/N changes; no new vertices/triangles/cap and source Body/UV/JW/PNG remain exact.',
                                     'Offline Armature walk/head-turn is not stock Animate, exact game Fx or Native approval. Actual Importer and idle/walk/FQ/ONOFF QA remain pending.'])
    if body:
        manifest.update(modest_outfit_offline_verified=True,full_body_offline_previews=[relative(body_out/(view+'.png')) for view in ['front','back','side']])
    for record in manifest['records']:
        record['offline_previews']=[relative(rest_out/(record['state']+'_'+view+'.png')) for view in ['front','quarter']]
        record['quality_status']=('lit expressions/full-body/basic Armature walk personally reviewed; native game quality pending' if basic else 'lit rest states and exact game Fx personally reviewed; native game quality pending')
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
    if args.winding:
        contract.update(expression_original_mouth_winding_corrected=True,
                        expression_mouth_winding_ledger=manifest['mouth_winding_ledger'],expression_mouth_winding_ledger_sha256=manifest['mouth_winding_ledger_sha256'])
    contract['meshes']=rows if isinstance(contract['meshes'],list) else 3
    paths['sidecar'].write_text(json.dumps(contract,indent=2)+'\n',encoding='utf-8')
    runtime={'schema':1,'avatar':folder.name,'candidate_variant':manifest['candidate_variant'],
             'glb':relative(glb),'glb_sha256':sha(glb),'sidecar':relative(paths['sidecar']),'sidecar_sha256':sha(paths['sidecar']),
             'manifest':relative(paths['manifest']),'manifest_sha256':sha(paths['manifest']),
             'strict_validator':manifest['strict_validation_tool'],'strict_validation_kind':manifest['validation_kind'],
             'shared_skin_runtime_contract':'tools/costume_expressions/skin_runtime_contract.json',
             'required_skin_runtime_schema':2,'required_expression_skin_runtime_schema':1,
             'root_weld_and_actual_shared_bone_host_required':True,
             'original_face_triangle_count':baseline['selected_original_face_triangles'],'mouth_changed_original_vertices':validation['parent_mouth_changed_original_vertices'] if args.winding else validation['changed_original_mouth_vertices'],
             'geometry_scope':'Only ledger-listed original connected mouth P/N; HeadBase and Face share exact P/N accessors.',
             'new_vertices':0,'new_triangles':0,'body_uv_jw_original_bones_png_exact':True,
             'ready':False,'runtime_validated':False,'roblox_uploaded':False,
             'actual_import_mesh_ids_required':True,'existing_png_texture_ids_reusable_only_after_upload_ledger_sha_match':True}
    if args.winding:
        runtime.update(geometry_scope='Exact original mouth P/N ledger and listed inward original-mouth index orders only; same original vertex sets/UV/JW/bones/PNG.',
                       changed_original_mouth_triangles=validation['changed_original_mouth_triangles'],mouth_winding_ledger=manifest['mouth_winding_ledger'],mouth_winding_ledger_sha256=manifest['mouth_winding_ledger_sha256'])
    paths['runtime'].write_text(json.dumps(runtime,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'manifest':str(paths['manifest']),'sidecar':str(paths['sidecar']),'glb_sha256':sha(glb),'ready':False}),flush=True)


if __name__=='__main__':main()
