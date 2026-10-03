"""Prepare a reviewed expression-skin import ledger; no uploads or Studio calls."""
import argparse,datetime,hashlib,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/costume_r15'))
from glb_io import read_glb,image_bytes

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('name');p.add_argument('--reviewed',action='store_true');a=p.parse_args()
 name=a.name
 assert name in {'Costume_'+f+c+g for f in ['Halo','Horns','Neutral'] for c in ['Warrior','Archer','Mage'] for g in ['M','F']}
 assert a.reviewed,'Root must inspect and show the exact images before preparing upload'
 source=ROOT/'art/models/costume/expressions'/name
 manifest_path=source/'skin_expressions_manifest.json';manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
 assert manifest['avatar']==name and manifest['ready'] is False and manifest['runtime_validated'] is False
 glb=(ROOT/manifest['skin_asset']).resolve();glb.relative_to(source.resolve())
 assert sha(glb)==manifest['skin_sha256']
 validation=json.loads((source/'skin_validation.json').read_text(encoding='utf-8'))
 assert validation.get('validated') is True
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
 out=ROOT/'build/costume_skin_expression_imports'/name;out.mkdir(parents=True,exist_ok=True)
 ledger=out/'importer_ledger.json';assert not ledger.exists(),'Existing/unknown import must not be retried'
 texture_dir=out/'preflight';texture_dir.mkdir()
 embedded=[]
 for i,item in enumerate(gltf['images']):
  data=image_bytes(gltf,binary,item);file=texture_dir/f'texture_{i+1}.png';file.write_bytes(data)
  embedded.append({'file':str(file.relative_to(ROOT)),'sha256':sha(file)})
 record={'schema':1,'model':name,'stage':'Prepared','file':str(glb),'sha256':sha(glb),
  'manifest':str(manifest_path.relative_to(ROOT)),'manifest_sha256':sha(manifest_path),'mesh_names':manifest['meshes'],
  'embedded_images':embedded,'maximum_importer_assets':7,'maximum_full_set_assets':9,
  'wrapper_name':'Scene','rig_type':'Custom','bone_count':bones,'keep_uninfluential_bones':True,
  'storage_folder':'CostumeExpressionSkinImports','studio':'build/GoodEvil.rbxlx',
  'root_reviewed':True,'root_reviewed_states':list(rows),'prepared_at':datetime.datetime.now(datetime.timezone.utc).isoformat()}
 ledger.write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 textures={'schema':1,'stage':'Prepared','maximum_assets':2,'states':['Serious','SoftSmile'],
  'files':{s:rows[s]['png'] for s in ['Serious','SoftSmile']},'source_sha256':{s:rows[s]['sha256'] for s in ['Serious','SoftSmile']},
  'root_reviewed':True,'whole_batch_maximum_assets':9}
 (out/'texture_upload_ledger.json').write_text(json.dumps(textures,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(json.dumps({'name':name,'ledger':str(ledger.relative_to(ROOT)),'bones':bones,'maximum_full_set_assets':9,'studio_calls':0,'uploads':0}))

if __name__=='__main__':main()
