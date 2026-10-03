"""Record a completed native import without resubmitting any assets."""
import argparse
import datetime
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio_mcp import Client

CODE = r'''
assert(not game:GetService('RunService'):IsRunning(),'Edit required')
local DATA=game.HttpService:JSONDecode(__DATA__)
local ss=game:GetService('ServerStorage')
local f=ss:FindFirstChild(DATA.folder)
local existing=f and f:FindFirstChild(DATA.name)
local scene=workspace:FindFirstChild(DATA.wrapper)
assert(not (scene and existing),'duplicate actual imports')
local model=scene or existing
assert(model and model:IsA('Model'),'import not completed')
if existing then assert(model:GetAttribute('HHC_SourceFileSHA256')==DATA.sha,'hash mismatch') end
local rows,refs,seen,nodes,allBones,baseParts,expected={},{},{},{},{},{},{}
for _,n in DATA.meshes do expected[n]=true end
local function cf(v) return {v:GetComponents()} end
local function vec(v) return {v.X,v.Y,v.Z} end
for _,v in model:GetDescendants() do
 if v:IsA('LuaSourceContainer') then error('unexpected imported script') end
 table.insert(nodes,{name=v.Name,class=v.ClassName,path=v:GetFullName(),parent=v.Parent.Name})
 if v:IsA('Bone') then table.insert(allBones,{name=v.Name,parent=v.Parent.Name,path=v:GetFullName(),cframe=cf(v.CFrame),world=cf(v.WorldCFrame),transform=cf(v.Transform)}) end
 if v:IsA('BasePart') and not v:IsA('MeshPart') then table.insert(baseParts,{name=v.Name,path=v:GetFullName(),size=vec(v.Size),cframe=cf(v.CFrame),pivot_offset=cf(v.PivotOffset)}) end
 if v:IsA('MeshPart') then
  local n=v.Name
  if not expected[n] then n=string.gsub(n,'Mesh$','') end
  assert(expected[n] and not seen[n],'unexpected or duplicate mesh');seen[n]=true
  assert(v.MeshId:match('^rbxassetid://%d+$'),'missing real MeshId');refs[v.MeshId]=true
  local maps={}
  local a=v:FindFirstChildOfClass('SurfaceAppearance')
  if a then for _,k in {'ColorMap','NormalMap','MetalnessMap','RoughnessMap'} do maps[k]=a[k];if a[k]~='' then refs[a[k]]=true end end end
  if v.TextureID~='' then refs[v.TextureID]=true end
  assert(v.TextureID~='' or maps.ColorMap and maps.ColorMap~='','missing texture')
  local bones={}
  for _,b in v:GetDescendants() do if b:IsA('Bone') then table.insert(bones,{name=b.Name,parent=b.Parent.Name,path=b:GetFullName(),cframe=cf(b.CFrame),world=cf(b.WorldCFrame),transform=cf(b.Transform)}) end end
  local meshSize;pcall(function()meshSize=vec(v.MeshSize) end)
  table.insert(rows,{name=n,imported_name=v.Name,path=v:GetFullName(),size=vec(v.Size),mesh_size=meshSize,cframe=cf(v.CFrame),pivot_offset=cf(v.PivotOffset),mesh_id=v.MeshId,texture_id=v.TextureID,surface=maps,bones=bones})
 end
end
assert(#rows==#DATA.meshes,'incomplete mesh count')
assert(#allBones==DATA.bones,'exact original imported skin bones required')
if not f then f=Instance.new('Folder');f.Name=DATA.folder;f.Parent=ss end
model.Name=DATA.name;model:SetAttribute('HHC_SourceFileSHA256',DATA.sha);model.Parent=f
local list={};for id in refs do table.insert(list,id) end;table.sort(list)
return game.HttpService:JSONEncode({schema=1,name=model.Name,path=model:GetFullName(),source_sha256=DATA.sha,meshes=rows,bones=allBones,base_parts=baseParts,nodes=nodes,assetReferences=list})
'''

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name')
    args=parser.parse_args()
    assert args.name.startswith('Costume_') and args.name.replace('_','').isalnum()
    folder=Path('build/costume_skin_expression_imports')/args.name
    p=folder/'importer_ledger.json'
    d=json.loads(p.read_text(encoding='utf-8'))
    assert d['model']==args.name and d['stage']=='Submitting'
    assert d['root_reviewed'] and d['maximum_full_set_assets']<=10
    data={'name':args.name,'sha':d['sha256'],'wrapper':d['wrapper_name'],
          'meshes':d['mesh_names'],'bones':d['bone_count'],'folder':d['storage_folder']}
    code=CODE.replace('__DATA__',json.dumps(json.dumps(data)))
    c=Client();c.start()
    try:
        r=c.call('execute_luau',{'datamodel_type':'Edit','code':code})
        value=''.join(x.get('text','') for x in r.get('content',[]))
        if r.get('isError'):raise RuntimeError(value)
        actual=json.loads(value)
        (folder/'actual_imports.json').write_text(json.dumps(actual,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        d.update(stage='Complete',completed_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),actual=actual)
        p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(json.dumps({'name':actual['name'],'meshes':len(actual['meshes']),
                          'bones':len(actual['bones']),'refs':len(actual['assetReferences']),'path':actual['path']}))
    finally:c.close()

if __name__=='__main__':main()
