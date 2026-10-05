# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Prepare a reviewed expression-skin import ledger; no uploads or Studio calls."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse,datetime,hashlib,json,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/costume_r15'))
from glb_io import read_glb,image_bytes

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('name');p.add_argument('--reviewed',action='store_true')
 p.add_argument('--tag',default='');p.add_argument('--manifest',choices=['skin_expressions_manifest.json','face_union_manifest.json','face_union_mouth_manifest_v1.json','face_union_mouth_winding_manifest_v1.json'],default='skin_expressions_manifest.json')
 p.add_argument('--reuse-textures',action='store_true');a=p.parse_args()
 name=a.name
 assert name in {'Costume_'+f+c+g for f in ['Halo','Horns','Neutral'] for c in ['Warrior','Archer','Mage'] for g in ['M','F']}
 assert a.reviewed,'Root must inspect and show the exact images before preparing upload'
 assert not a.tag or re.fullmatch(r'[A-Za-z][A-Za-z0-9_]{0,40}',a.tag)
 required_tags={'face_union_manifest.json':'FaceUnion_v1','face_union_mouth_manifest_v1.json':'FaceUnionMouth_v1','face_union_mouth_winding_manifest_v1.json':'FaceUnionMouthWinding_v1'}
 assert a.manifest=='skin_expressions_manifest.json' or a.tag==required_tags[a.manifest]
 source=ROOT/'art/models/costume/expressions'/name
 manifest_path=source/a.manifest;manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
 assert manifest['avatar']==name and manifest['ready'] is False and manifest['runtime_validated'] is False
 glb=(ROOT/manifest['skin_asset']).resolve();glb.relative_to(source.resolve())
 assert sha(glb)==manifest['skin_sha256']
 validation_path=(ROOT/manifest['validation_report']).resolve() if a.manifest in required_tags else source/'skin_validation.json'
 validation_path.relative_to(source.resolve())
 validation=json.loads(validation_path.read_text(encoding='utf-8'))
 if a.manifest=='face_union_mouth_manifest_v1.json':
  from validate_mouth_restoration import check
  assert manifest['validation_kind']=='original_connected_mouth_pn_exception_v1'
  assert manifest['original_triangles_only'] and manifest['new_mouth_cap_vertices']==0
  current=check(glb)
  assert current['sha256']==validation['sha256']==manifest['skin_sha256']
  expected_mouth_vertices={'Costume_HaloArcherM':71,'Costume_HaloMageF':75,'Costume_NeutralArcherM':41}.get(a.name)
  assert expected_mouth_vertices is not None,'Unreviewed mouth-restoration model'
  assert current['changed_original_mouth_vertices']==validation['changed_original_mouth_vertices']==expected_mouth_vertices
  assert current['new_vertices']==current['new_triangles']==0
  for key in ['body_topology_uv_joints_weights_bones_images_exact','non_mouth_position_normal_exact','headbase_face_shared_position_normal_exact','original_source_and_baseline_unchanged']:
   assert current[key] is validation[key] is True,key
  motion_review_key='game_fx_offline_review'
  if a.name=='Costume_NeutralArcherM':
   assert manifest['game_fx_offline_verified'] is False and manifest['stock_animate_verified'] is False
   assert manifest['modest_outfit_offline_verified'] is True
   motion_review_key='basic_motion_offline_review'
  for file_key in ['mouth_restoration_ledger','original_union_baseline','mouth_negative_tests','original_face_provenance','uv_texture_compatibility',motion_review_key]:
   file=(ROOT/manifest[file_key]).resolve();file.relative_to(source.resolve());assert sha(file)==manifest[file_key+'_sha256']
 elif a.manifest=='face_union_mouth_winding_manifest_v1.json':
  from validate_mouth_winding import check
  assert a.name=='Costume_HaloWarriorF','Unreviewed original-mouth winding model'
  assert manifest['validation_kind']=='original_connected_mouth_pn_winding_exception_v1'
  assert manifest['skin_sha256']=='1364e95a2c33145313a9c5c80b550f8668b66f9d01f4a850f933d6001e451d38'
  assert manifest['original_triangles_only'] and manifest['new_mouth_cap_vertices']==0
  current=check(glb)
  assert current==validation and current['sha256']==manifest['skin_sha256']
  assert current['parent_mouth_changed_original_vertices']==108 and current['changed_original_mouth_triangles']==21
  assert current['new_vertices']==current['new_triangles']==0
  for key in ['original_triangle_vertex_sets_exact','parent_position_normal_uv_joint_weight_bones_images_exact','body_headbase_indices_exact']:
   assert current[key] is True,key
  for file_key in ['mouth_restoration_ledger','mouth_winding_ledger','original_union_baseline','mouth_negative_tests','original_face_provenance','uv_texture_compatibility','game_fx_offline_review']:
   file=(ROOT/manifest[file_key]).resolve();file.relative_to(source.resolve());assert sha(file)==manifest[file_key+'_sha256']
 else:
  assert validation.get('validated') is True
  assert validation['skin_sha256']==manifest['skin_sha256']
 if a.manifest=='face_union_manifest.json':
  assert manifest['original_triangles_only'] and manifest['new_mouth_cap_vertices']==0
  for key in ['original_face_position_normal_joint_weight_values_exact','original_skin_inverse_bind_and_bone_hierarchy_exact','original_oriented_triangles_partition_exact','original_triangles_only']:
   assert validation[key] is True,key
  for file_key in ['original_face_provenance','uv_texture_compatibility','game_fx_offline_review']:
   file=(ROOT/manifest[file_key]).resolve();file.relative_to(source.resolve());assert sha(file)==manifest[file_key+'_sha256']
 gltf,binary,_=read_glb(glb)
 assert len(gltf['meshes'])==len(gltf['images'])==3 and len(gltf['skins'])==1
 assert [m['name'] for m in gltf['meshes']]==manifest['meshes']
 bones=len(gltf['skins'][0]['joints']);assert bones in [15,23]
 assert manifest['original_bones_claimed']==(bones==23)
 rows={r['state']:r for r in manifest['records']};assert set(rows)=={'Neutral','Serious','SoftSmile'}
 for state,row in rows.items():
  file=(ROOT/row['png']).resolve();file.relative_to(ROOT.resolve())
  assert 'v1' not in file.relative_to(ROOT/'art').parts,'Forbidden art/out/v1 input'
  assert sha(file)==row['sha256']
 assert hashlib.sha256(image_bytes(gltf,binary,gltf['images'][2])).hexdigest()==rows['Neutral']['sha256']
 reused=None;reused_path=None
 if a.reuse_textures:
  assert a.tag,'Reuse must be recorded in a distinct batch'
  reused_path=ROOT/'build/costume_skin_expression_imports'/name/'texture_upload_ledger.json'
  reused=json.loads(reused_path.read_text(encoding='utf-8'));assert reused['stage']=='Complete' and reused['actual'].get('isError') is False
  ids=json.loads(next(c['text'] for c in reused['actual']['content'] if c['type']=='text'))
  for state in ['Serious','SoftSmile']:
   assert reused['source_sha256'][state]==rows[state]['sha256']
   assert re.fullmatch(r'rbxassetid://[1-9][0-9]*',ids['http://127.0.0.1:8766/'+state+'.png'])
 out=ROOT/'build/costume_skin_expression_imports'/(name+('_'+a.tag if a.tag else ''));out.mkdir(parents=True,exist_ok=True)
 ledger=out/'importer_ledger.json';assert not ledger.exists(),'Existing/unknown import must not be retried'
 texture_dir=out/'preflight';texture_dir.mkdir()
 embedded=[]
 for i,item in enumerate(gltf['images']):
  data=image_bytes(gltf,binary,item);file=texture_dir/f'texture_{i+1}.png';file.write_bytes(data)
  embedded.append({'file':str(file.relative_to(ROOT)),'sha256':sha(file)})
 record={'schema':1,'model':name,'stage':'Prepared','file':str(glb),'sha256':sha(glb),
  'manifest':str(manifest_path.relative_to(ROOT)),'manifest_sha256':sha(manifest_path),'mesh_names':manifest['meshes'],
  'embedded_images':embedded,'maximum_importer_assets':7,'maximum_full_set_assets':7 if reused else 9,
  'wrapper_name':'Scene','rig_type':'Custom','bone_count':bones,'keep_uninfluential_bones':True,
  'storage_folder':'CostumeExpressionSkinImports'+('_'+a.tag if a.tag else ''),'studio':'build/GoodEvil.rbxlx','batch_tag':a.tag,
  'root_reviewed':True,'root_reviewed_states':list(rows),'prepared_at':datetime.datetime.now(datetime.timezone.utc).isoformat()}
 ledger.write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 textures={'schema':1,'stage':'Prepared','maximum_assets':2,'states':['Serious','SoftSmile'],
  'files':{s:rows[s]['png'] for s in ['Serious','SoftSmile']},'source_sha256':{s:rows[s]['sha256'] for s in ['Serious','SoftSmile']},
  'root_reviewed':True,'whole_batch_maximum_assets':7 if reused else 9}
 if reused:
  textures.update(stage='Reused',maximum_assets=0,actual=reused['actual'],reuse_source_ledger=str(reused_path.relative_to(ROOT)),reuse_source_sha256=sha(reused_path))
 (out/'texture_upload_ledger.json').write_text(json.dumps(textures,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(json.dumps({'name':name,'ledger':str(ledger.relative_to(ROOT)),'bones':bones,'maximum_full_set_assets':7 if reused else 9,'studio_calls':0,'uploads':0}))

if __name__=='__main__':main()
