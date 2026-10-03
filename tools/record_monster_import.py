"""Record one reviewed native monster import without uploading or promoting it."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path

from studio_mcp import Client

ROOT = Path(__file__).resolve().parents[1]
CODE = r'''
assert(not game:GetService('RunService'):IsRunning(),'Edit required')
local D=game.HttpService:JSONDecode(__DATA__)
local ss=game.ServerStorage
local folder=ss:FindFirstChild('MonsterNewAccountImports')
local existing=folder and folder:FindFirstChild(D.name)
local scene=workspace:FindFirstChild('Scene')
assert(not (scene and existing),'ambiguous duplicate import')
local model=scene or existing
assert(model and model:IsA('Model'),'native import not completed')
if existing then assert(model:GetAttribute('HHC_SourceFileSHA256')==D.sha,'source hash mismatch') end
local meshes,refs={},{}
local function cf(v)return {v:GetComponents()}end
local function vec(v)return {v.X,v.Y,v.Z}end
for _,v in model:GetDescendants() do
 assert(not v:IsA('LuaSourceContainer') and not v:IsA('Humanoid') and not v:IsA('Bone'),'unexpected active rig content')
 if v:IsA('BasePart') then
  assert(v:IsA('MeshPart'),'unexpected non-mesh body')
  assert(v.MeshId:match('^rbxassetid://[1-9]%d*$'),'missing actual mesh id');refs[v.MeshId]=true
  local surface=v:FindFirstChildOfClass('SurfaceAppearance');local maps={}
  if surface then
   for _,k in {'ColorMap','NormalMap','MetalnessMap','RoughnessMap'} do
    maps[k]=surface[k];if maps[k]~='' then assert(maps[k]:match('^rbxassetid://[1-9]%d*$'),'missing actual map id');refs[maps[k]]=true end
   end
  end
  if v.TextureID~='' then assert(v.TextureID:match('^rbxassetid://[1-9]%d*$'));refs[v.TextureID]=true end
  assert(v.TextureID~='' or maps.ColorMap and maps.ColorMap~='','missing color texture')
  if D.pbr then assert(surface and maps.NormalMap~='' and maps.MetalnessMap~='' and maps.RoughnessMap~='','incomplete PBR maps') end
  table.insert(meshes,{name=v.Name,mesh_id=v.MeshId,texture_id=v.TextureID,maps=maps,size=vec(v.Size),cframe=cf(v.CFrame),pivot_offset=cf(v.PivotOffset),transparency=v.Transparency,color=vec(Vector3.new(v.Color.R,v.Color.G,v.Color.B)),material=v.Material.Name})
 end
end
assert(#meshes==D.meshes,'incomplete actual mesh count')
local list={};for id in refs do table.insert(list,id) end;table.sort(list)
assert(#list+1<=D.maximum,'actual references exceed reviewed batch')
if not folder then folder=Instance.new('Folder');folder.Name='MonsterNewAccountImports';folder.Parent=ss end
model.Name=D.name;model:SetAttribute('HHC_SourceFileSHA256',D.sha);model:SetAttribute('HHC_VisualValidated',false);model.Parent=folder
return game.HttpService:JSONEncode({schema=1,name=D.name,path=model:GetFullName(),source_sha256=D.sha,pivot=cf(model:GetPivot()),meshes=meshes,assetReferences=list,production_promoted=false})
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name', choices=['Goblin', 'GoblinBrute', 'Skeleton', 'SkeletonKing'])
    args = parser.parse_args()
    folder = ROOT / 'build/monster_import_preflight_20261004'
    path = folder / 'ledger_prepared.json'
    ledger = json.loads(path.read_text(encoding='utf-8'))
    item = next(row for row in ledger['requested'] if row['name'] == args.name)
    assert item['stage'] == 'Submitting' and item['reviewed_by_root'] and item['shown_to_user']
    assert item['batch']['total_assets_maximum'] <= 10
    source = (ROOT / item['exact_import_file']).resolve()
    source.relative_to(folder)
    assert hashlib.sha256(source.read_bytes()).hexdigest() == item['exact_import_sha256'] == item['source_sha256']
    data = {'name': args.name, 'sha': item['source_sha256'], 'meshes': len(item['source_meshes']),
            'maximum': item['batch']['total_assets_maximum'], 'pbr': item['material_findings']['source_normal_and_packed_mr_maps']}
    client = Client()
    client.start()
    try:
        response = client.call('execute_luau', {'datamodel_type': 'Edit', 'code': CODE.replace('__DATA__', json.dumps(json.dumps(data)))})
        text = ''.join(block.get('text', '') for block in response.get('content', []))
        if response.get('isError'):
            raise RuntimeError(text)
        actual = json.loads(text)
        (folder / args.name / 'actual_imports.json').write_text(json.dumps(actual, indent=2) + '\n', encoding='utf-8')
        item.update(stage='ImportedPendingVisualQA', actual_ids=actual, completed_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
        path.write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(json.dumps({'name': args.name, 'meshes': len(actual['meshes']), 'references': len(actual['assetReferences']), 'production_promoted': False}))
    finally:
        client.close()


if __name__ == '__main__':
    main()
