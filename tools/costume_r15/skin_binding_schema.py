# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
# Still importable as a library ONLY because live tools import it (tools/monster_import_preflight.py,
# tools/test_weapon_motion.py, GLB audit tools). Never run it directly.
"""Exact same-Model skin binding graph for actual inspected Pending clones.

The shared Bone host is connected once to the invisible R15 root; every other
imported BasePart joins the host inside CostumeSkin with a bind-preserving Weld.
This prepares payloads only. It never claims rendered deformation or Ready.
"""
from __future__ import annotations

if __name__ == "__main__":
    raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import copy

from constraints import RigError


def configure(data,inspection):
    data=copy.deepcopy(data)
    if data.get("binding_schema")!=1: return data
    for row in inspection["parts"]:
        path=row.get("path")
        if not isinstance(path,list) or not path or any(not isinstance(name,str) or not name or "\0" in name for name in path) or path[-1]!=row.get("name") or row.get("class") not in ("Part","MeshPart"):
            raise RigError("The binding graph requires exact inspected Part/MeshPart path arrays")
    by_path={tuple(row["path"]):row for row in inspection["parts"]}
    if len(by_path)!=len(inspection["parts"]): raise RigError("Duplicate actual imported BasePart path")
    hosts={tuple(row["host_path"]) for row in inspection["bones"]}
    if not hosts or not hosts<=by_path.keys(): raise RigError("The actual Bone host is not an imported physical part")
    allowed=[key for key in hosts if not data.get("expression") or by_path[key]["name"]!="FaceExpression"]
    if not allowed: raise RigError("Expression surfaces require a distinct actual skeleton binding host")
    anchor=min(allowed,key=lambda key:(by_path[key]["class"]=="MeshPart",key))
    data["binding"]={"schema":1,"anchor_path":list(anchor),"bone_host_paths":[list(path) for path in sorted(hosts)],
                     "part_paths":[list(path) for path in sorted(by_path)],"root_welds":1,"internal_welds":len(by_path)-1}
    return data


ASSEMBLE=r'''
    if DATA.binding then
        local function skinAt(path)
            local current=skin
            for _,name in path do
                local found=nil
                for _,child in current:GetChildren() do
                    if child.Name==name then if found then error("내부 스킨 경로 이름 중복") end;found=child end
                end
                if not found then error("실제 내부 스킨 경로 누락") end
                current=found
            end
            return current
        end
        local function closestModel(object)
            while object do if object:IsA("Model") then return object end;object=object.Parent end
            return nil
        end
        local anchor=skinAt(DATA.binding.anchor_path)
        if not anchor:IsA("BasePart") or closestModel(anchor)~=skin then error("같은 CostumeSkin Model 내부 실제 Bone host가 필요합니다.") end
        local isBoneHost=false
        for _,object in skin:GetDescendants() do
            if object:IsA("Bone") then
                local host=object.Parent
                while host and not host:IsA("BasePart") do host=host.Parent end
                if host==anchor then isBoneHost=true end
                if not host or closestModel(host)~=skin then error("Bone host가 다른 Model에 있습니다.") end
            end
        end
        if not isBoneHost then error("실제 뼈를 소유하지 않는 스킨 anchor") end
        if skin:FindFirstChild("HHC_SkinBindingHost") then error("원본 스킨에 미검증 binding host 참조가 있습니다.") end
        local value=Instance.new("ObjectValue");value.Name="HHC_SkinBindingHost";value.Value=anchor;value.Parent=skin
        local rootWeld=Instance.new("WeldConstraint");rootWeld.Name="CostumeSkinRootWeld";rootWeld.Part0=root;rootWeld.Part1=anchor;rootWeld.Parent=anchor
        local internalCount=0
        for _,path in DATA.binding.part_paths do
            local part=skinAt(path)
            if not part:IsA("BasePart") or closestModel(part)~=skin then error("스킨의 물리 부품이 다른 Model에 있습니다.") end
            if part~=anchor then
                local weld=Instance.new("Weld");weld.Name="CostumeSkinInternalWeld";weld.Part0=anchor;weld.Part1=part
                weld.C0=anchor:GetAttribute("HHC_SkinHostBindRoot"):Inverse()*part:GetAttribute("HHC_SkinHostBindRoot")
                weld.C1=CFrame.new();weld.Parent=part;internalCount+=1
                if not equal(frame(anchor.CFrame*weld.C0),frame(part.CFrame*weld.C1)) then error("스킨 내부 Weld가 원본 정지 표면을 이동시킵니다.") end
            end
        end
        if internalCount~=DATA.binding.internal_welds then error("스킨 내부 Weld 수 불일치") end
        model:SetAttribute("HHC_SkinBindingSchema",1)
    end
'''


VERIFY_START=r'''
local bindingAnchor=nil
local function closestModel(object)
    while object do if object:IsA("Model") then return object end;object=object.Parent end
    return nil
end
if DATA.binding then
    requireCheck(DATA.binding.schema==1 and model:GetAttribute("HHC_SkinBindingSchema")==1,"내부 스킨 binding schema")
    local value=unique(skin,"HHC_SkinBindingHost")
    bindingAnchor=at(skin,DATA.binding.anchor_path)
    requireCheck(value and value:IsA("ObjectValue") and value.Value==bindingAnchor and bindingAnchor and bindingAnchor:IsA("BasePart")
        and closestModel(bindingAnchor)==skin,"같은 Model 실제 binding host 참조")
    local boneHost=false
    for _,bone in skin:GetDescendants() do
        if bone:IsA("Bone") then
            local host=bone.Parent;while host and not host:IsA("BasePart") do host=host.Parent end
            requireCheck(host and closestModel(host)==skin,"Bone의 실제 같은 Model host")
            if host==bindingAnchor then boneHost=true end
        end
    end
    requireCheck(boneHost,"binding anchor의 실제 Bone 소유")
end
local rootBindingWelds,internalBindingWelds=0,0
'''


def assembly(code):
    old='            local weld=Instance.new("WeldConstraint");weld.Name="CostumeSkinRootWeld";weld.Part0=root;weld.Part1=child;weld.Parent=child;hostCount+=1'
    replacement='            hostCount+=1\n            if not DATA.binding then\n'+old.replace(';hostCount+=1','')+'\n            end'
    boundary='    if meshCount~=#DATA.meshes or boneCount~=#SNAP.bones'
    if old not in code or boundary not in code: raise RigError("The guarded binding assembly boundary changed")
    return code.replace(old,replacement).replace(boundary,ASSEMBLE+boundary)


def verify(code):
    before='local maximumBoneError,maximumAxisError=0,0'
    if before not in code: raise RigError("The guarded binding matcher boundary changed")
    code=code.replace(before,VERIFY_START+before)
    old='''        local weld=unique(object,"CostumeSkinRootWeld")
        requireCheck(weld and weld:IsA("WeldConstraint") and weld.Enabled and weld.Part0==root and weld.Part1==object,"원래 shared host Root weld")'''
    new=r'''        if DATA.binding then
            requireCheck(closestModel(object)==skin,"스킨 부품의 같은 Model 연결")
            if object==bindingAnchor then
                local weld=unique(object,"CostumeSkinRootWeld")
                requireCheck(weld and weld:IsA("WeldConstraint") and weld.Enabled and weld.Part0==root and weld.Part1==object,"유일한 binding host Root weld")
                requireCheck(not unique(object,"CostumeSkinInternalWeld"),"anchor 자기 내부 Weld 금지")
            else
                local weld=unique(object,"CostumeSkinInternalWeld")
                requireCheck(weld and weld:IsA("Weld") and weld.Enabled and weld.Part0==bindingAnchor and weld.Part1==object,"같은 Model 내부 skin Weld")
                requireCheck(not unique(object,"CostumeSkinRootWeld"),"메시 외부 Root 직접결합 금지")
                local expected=bindingAnchor:GetAttribute("HHC_SkinHostBindRoot"):Inverse()*object:GetAttribute("HHC_SkinHostBindRoot")
                requireCheck(close(weld.C0,expected,0.0001) and close(weld.C1,CFrame.new(),0.0001)
                    and close(bindingAnchor.CFrame*weld.C0,object.CFrame*weld.C1,0.0001),"원본 위치를 보존하는 내부 skin Weld C0/C1")
            end
        else
'''+old+'''
        end'''
    if old not in code: raise RigError("The guarded binding per-part matcher changed")
    code=code.replace(old,new)
    old='''    elseif object:IsA("WeldConstraint") then
        requireCheck(object.Name=="CostumeSkinRootWeld","미검증 skin weld");welds+=1'''
    new=r'''    elseif object:IsA("WeldConstraint") then
        requireCheck(object.Name=="CostumeSkinRootWeld","미검증 skin weld");welds+=1
        if DATA.binding then requireCheck(object.Parent==bindingAnchor and object.Part0==root and object.Part1==bindingAnchor and object.Enabled,"추가/외부 root weld 금지");rootBindingWelds+=1 end
    elseif DATA.binding and object:IsA("Weld") then
        welds+=1;internalBindingWelds+=1
        requireCheck(object.Name=="CostumeSkinInternalWeld" and object.Enabled and object.Part0==bindingAnchor and object.Part1
            and object.Part1~=bindingAnchor and object.Parent==object.Part1 and closestModel(object.Part1)==skin,"미검증/다른 Model 내부 Weld 금지")'''
    if old not in code: raise RigError("The guarded binding descendant matcher changed")
    code=code.replace(old,new)
    boundary='local manifest=HttpService:JSONDecode(model:GetAttribute("HHC_SkinManifest"))'
    global_guard=r'''
if DATA.binding then
    requireCheck(rootBindingWelds==1 and internalBindingWelds==DATA.binding.internal_welds,"유일한 root 연결/모든 내부 skin 연결 수")
    for _,joint in model:GetDescendants() do
        if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then
            if joint:IsA("Motor6D") then requireCheck(not joint:IsDescendantOf(skin),"스킨 내부 추가 Motor6D 금지")
            else requireCheck(joint:IsDescendantOf(skin) and (joint:IsA("Weld") and joint.Name=="CostumeSkinInternalWeld"
                    or joint:IsA("WeldConstraint") and joint.Name=="CostumeSkinRootWeld"),"스킨 외부 중복/추가 결합 금지") end
        end
    end
end
'''
    code=code.replace(boundary,global_guard+boundary)
    boundary='requireCheck(manifest.unique_bones=='
    code=code.replace(boundary,'if DATA.binding then requireCheck(manifest.binding_schema==1 and equal(manifest.binding_host_path,DATA.binding.anchor_path),"manifest 실제 skin binding host") end\n'+boundary)
    code=code.replace('    runtime_validated=false,animation_validated=false,ready=false,promotion=false})',
                      '    binding_schema=DATA.binding and 1 or 0,root_binding_welds=rootBindingWelds,internal_binding_welds=internalBindingWelds,\n    runtime_validated=false,animation_validated=false,ready=false,promotion=false})')
    return code
