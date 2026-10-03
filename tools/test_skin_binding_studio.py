"""Check actual imported skin joint guards in Edit; temporary clones are always removed."""
import json
from pathlib import Path

from studio_mcp import Client

CODE = r'''
assert(not game:GetService('RunService'):IsRunning(), 'Edit required')
local binding=require(game.ReplicatedStorage.Shared.SkinBindingContract)
local source=game.ServerStorage.CostumePendingRigs.Costume_HaloArcherM_FaceUnionBindingSkinSchema2Candidate
local checks={}
local function run(label,mutation,expected,scale)
 local m=source:Clone();m.Name='QASkinBindingTemporary';m.Parent=game.ServerStorage
 local ok,result=pcall(function()
  if scale then m:ScaleTo(scale) end
  if mutation then mutation(m) end
  local valid=binding.Validate(m,scale or 1)
  assert(valid==expected,label..': wrong acceptance')
  return {label=label,accepted=valid,scale=scale or 1}
 end)
 m:Destroy()
 assert(ok,result);table.insert(checks,result)
end
local function mesh(m) return m.CostumeSkin.FaceExpression end
run('real imported internal graph',nil,true)
run('real ScaleTo 2',nil,true,2)
run('scale restored 1',function(m)m:ScaleTo(2);m:ScaleTo(1)end,true)
run('missing binding schema',function(m)m:SetAttribute('HHC_SkinBindingSchema',nil)end,false)
run('unknown binding schema',function(m)m:SetAttribute('HHC_SkinBindingSchema',2)end,false)
run('missing host ref',function(m)m.CostumeSkin.HHC_SkinBindingHost:Destroy()end,false)
run('wrong host ref',function(m)m.CostumeSkin.HHC_SkinBindingHost.Value=mesh(m)end,false)
run('disabled internal Weld',function(m)mesh(m).CostumeSkinInternalWeld.Enabled=false end,false)
run('disabled root WeldConstraint',function(m)m.CostumeSkin.RootPart.CostumeSkinRootWeld.Enabled=false end,false)
run('old outside HRP graph',function(m)local w=mesh(m).CostumeSkinInternalWeld;w.Part0=m.HumanoidRootPart end,false)
run('wrong internal bind translation',function(m)local w=mesh(m).CostumeSkinInternalWeld;w.C0*=CFrame.new(.05,0,0)end,false)
run('wrong internal bind rotation',function(m)local w=mesh(m).CostumeSkinInternalWeld;w.C1=CFrame.Angles(.1,0,0)end,false)
run('nonuniform root scale',function(m)m.HumanoidRootPart.Size*=Vector3.new(1,2,1)end,false)
run('child Model breaks skin namespace',function(m)local n=Instance.new('Model');n.Parent=m.CostumeSkin;mesh(m).Parent=n end,false)
run('anchored mesh',function(m)mesh(m).Anchored=true end,false)
run('massful mesh',function(m)mesh(m).Massless=false end,false)
run('colliding mesh',function(m)mesh(m).CanCollide=true end,false)
run('second moving Head attachment',function(m)local w=Instance.new('Weld');w.Part0=m.Head;w.Part1=mesh(m);w.Parent=mesh(m)end,false)
run('extra internal constraint',function(m)local w=Instance.new('WeldConstraint');w.Part0=m.CostumeSkin.RootPart;w.Part1=mesh(m);w.Parent=mesh(m)end,false)
local costume=require(game.ServerScriptService.CostumeService:Clone())
local function serverGate(label,mutation,expected)
 local m=source:Clone();m.Name='QASkinTemplateTemporary'
 for _,key in {'HHC_RigReady','HHC_AnimationValidated','HHC_SkinRuntimeValidated'} do m:SetAttribute(key,true) end
 local ok,result=pcall(function()
  if mutation then mutation(m) end
  local valid=costume.ValidateTemplate(m)
  assert(valid==expected,label..': wrong server acceptance')
  return {label=label,accepted=valid,server_template=true}
 end)
 m:Destroy();assert(ok,result);table.insert(checks,result)
end
serverGate('valid actual skin template',nil,true)
serverGate('disabled duplicate Neck',function(m)local w=Instance.new('Motor6D');w.Name='Neck';w.Part0=m.UpperTorso;w.Part1=m.Head;w.Enabled=false;w.Parent=m.UpperTorso end,false)
serverGate('renamed required Neck',function(m)for _,v in m:GetDescendants() do if v:IsA('Motor6D') and v.Name=='Neck' then v.Name='WrongNeck';return end end;error('actual Neck missing')end,false)
local rigid=game.ServerStorage.CostumeRigs.Costume_HaloWarriorM
assert(costume.ValidateTemplate(rigid),'existing production rigid regression')
table.insert(checks,{label='existing production rigid template',accepted=true,server_template=true})
return game.HttpService:JSONEncode({schema=1,checks=checks,passed=true,source_unchanged=true,temporary_clones_removed=true})
'''


def main():
    client = Client()
    client.start()
    try:
        result = client.call('execute_luau', {'datamodel_type': 'Edit', 'code': CODE})
        text = ''.join(block.get('text', '') for block in result.get('content', []))
        if result.get('isError'):
            raise RuntimeError(text)
        actual = json.loads(text)
        assert actual['passed'] and actual['temporary_clones_removed']
        output = Path('build/skin_binding_contract_actual.json')
        output.write_text(json.dumps(actual, indent=2) + '\n', encoding='utf-8')
        print(f"Skin binding: {len(actual['checks'])} actual Edit checks passed")
    finally:
        client.close()


if __name__ == '__main__':
    main()
