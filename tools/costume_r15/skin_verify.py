# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
# Still importable as a library ONLY because live tools import it (tools/monster_import_preflight.py,
# tools/test_weapon_motion.py, GLB audit tools). Never run it directly.
"""Read-only engine matcher for an exact schema-2 Pending assembly.

The payload compares the actual native import and its checked clone. It never
repairs metadata, sets QA flags, overwrites a Pending or promotes a registry.
"""

if __name__ == "__main__":
    raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
VERIFY = r'''
local SNAP=HttpService:JSONDecode(__SNAP__)
local FIT=HttpService:JSONDecode(__FIT__)
local checks=0
local function requireCheck(value,message)
    checks+=1
    if not value then error("스킨 조립 검증: "..message) end
end
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)=="number" then return a==a and b==b and math.abs(a-b)<0.00001 end
    if type(a)~="table" then return a==b end
    for k,v in a do if not equal(v,b[k]) then return false end end
    for k in b do if a[k]==nil then return false end end
    return true
end
local function contains(actual,expected)
    if type(actual)~=type(expected) then return false end
    if type(expected)~="table" then return equal(actual,expected) end
    if next(expected)==nil then return next(actual)==nil end
    if #expected>0 and #actual~=#expected then return false end
    for k,v in expected do if not contains(actual[k],v) then return false end end
    return true
end
local function close(a,b,tolerance)
    if typeof(a)~=typeof(b) then return false end
    if typeof(a)=="Vector3" then return (a-b).Magnitude<=tolerance end
    if typeof(a)=="CFrame" then
        local av,bv={a:GetComponents()},{b:GetComponents()}
        for k,v in av do if v~=v or math.abs(v-bv[k])>tolerance then return false end end
        return true
    end
    return false
end
local function unique(parent,name)
    local found=nil
    for _,child in parent:GetChildren() do
        if child.Name==name then requireCheck(not found,"중복 이름: "..name);found=child end
    end
    return found
end
local function at(parent,path)
    for _,name in path do parent=unique(parent,name);if not parent then return nil end end
    return parent
end
local function arrayFrame(value) return CFrame.new(table.unpack(value)) end
local rotation=CFrame.new(0,0,0,table.unpack(FIT.rotation))
local offset=Vector3.new(table.unpack(FIT.offset))
local function normalized(value)
    local cf=arrayFrame(value)
    return CFrame.new(rotation:VectorToObjectSpace(cf.Position-offset)/FIT.scale)*rotation:Inverse().Rotation*cf.Rotation
end
local function scaledLocal(value)
    local cf=arrayFrame(value)
    return CFrame.new(cf.Position/FIT.scale)*cf.Rotation
end
local ACTUAL=snapshot()
requireCheck(contains(ACTUAL,SNAP),"검사 이후 원본 모델이 변경됨")
requireCheck(ACTUAL.source_file_sha256==DATA.skin_sha256,"원본 SHA 불일치")
local folder=unique(game:GetService("ServerStorage"),"CostumePendingRigs")
requireCheck(folder and folder:IsA("Folder"),"대기 폴더 없음")
local model=unique(folder,DATA.pending_name)
requireCheck(model and model:IsA("Model"),"정확한 대기 모델 없음")
local expectedAttributes={HHC_SourceSHA256=DATA.original_sha256,HHC_SourceFileSHA256=DATA.skin_sha256,HHC_SkinSourceSHA256=DATA.skin_sha256,
    HHC_JointsSHA256=DATA.joints_sha256,HHC_SkinContractSHA256=DATA.contract_sha256,HHC_SkinInspectionSHA256=FIT.inspection_sha256,
    HHC_RigOrigin=DATA.rig_origin,HHC_InferredManualCandidate=DATA.original_bones_claimed==false,HHC_OriginalBonesClaimed=DATA.original_bones_claimed,
    HHC_OriginalUVPreserved=true,HHC_OriginalTextureBytesPreserved=true,HHC_SkinRuntimeSchema=2,HHC_SkinRetargetRequired=true,
    HHC_SkinRuntimeValidated=false,HHC_PendingAnimationQA=true,HHC_AnimationValidated=false,HHC_RigReady=false}
for key,value in expectedAttributes do requireCheck(model:GetAttribute(key)==value,"모델 표식: "..key) end
local root=unique(model,"HumanoidRootPart")
requireCheck(root and root:IsA("Part") and model.PrimaryPart==root,"Root/PrimaryPart 불일치")
requireCheck(close(root.CFrame,CFrame.new(table.unpack(DATA.root.center)),0.0001),"Root 위치")
requireCheck(close(root.Size,Vector3.new(table.unpack(DATA.root.size)),0.0001),"Root 크기")
requireCheck(root.Transparency==1 and not root.Anchored and not root.Massless and root.RootPriority==127 and not root.CanCollide and not root.CanTouch and not root.CanQuery,"Root 물리 설정")
requireCheck(close(model:GetAttribute("HHC_SkinRootBindSize"),root.Size,0.0001),"Root bind 크기")
requireCheck(type(model:GetAttribute("HHC_SkinBindScale"))=="number" and math.abs(model:GetAttribute("HHC_SkinBindScale")-model:GetScale())<0.0001,"정지 상태 scale")
local skin=unique(model,"CostumeSkin")
requireCheck(skin and skin:IsA("Model"),"원래 전체 스킨 모델 없음")
local hum=unique(model,"Humanoid")
requireCheck(hum and hum:IsA("Humanoid") and hum.RigType==Enum.HumanoidRigType.R15 and hum.Health>0,"R15 Humanoid")
requireCheck(not hum.AutomaticScalingEnabled and not hum.BreakJointsOnDeath and hum.RequiresNeck and math.abs(hum.HipHeight-DATA.hip_height)<0.0001,"Humanoid 계약")
local animator=unique(hum,"Animator")
requireCheck(animator and animator:IsA("Animator"),"서버 Animator 없음")
local parts={HumanoidRootPart=root}
local attachments=0
for _,entry in DATA.proxy_parts do
    local part=unique(model,entry.name);parts[entry.name]=part
    requireCheck(part and part:IsA("Part"),"R15 proxy 없음: "..entry.name)
    requireCheck(close(part.CFrame,CFrame.new(table.unpack(entry.center)),0.0001) and close(part.Size,Vector3.new(table.unpack(entry.size)),0.0001),"proxy 위치/크기: "..entry.name)
    requireCheck(part.Transparency==1 and part.Massless and not part.Anchored and not part.CanTouch and part.CanQuery,"proxy 물리 설정: "..entry.name)
    requireCheck(part.CanCollide==(entry.name=="Head" or entry.name=="UpperTorso" or entry.name=="LowerTorso"),"proxy 충돌: "..entry.name)
    requireCheck(close(part:GetAttribute("HHC_ProxyBindRoot"),root.CFrame:ToObjectSpace(part.CFrame),0.0001) and close(part:GetAttribute("HHC_ProxyBindSize"),part.Size,0.0001),"proxy bind: "..entry.name)
end
requireCheck(close(root:GetAttribute("HHC_ProxyBindRoot"),CFrame.new(),0.0001) and close(root:GetAttribute("HHC_ProxyBindSize"),root.Size,0.0001),"Root proxy bind")
local motorCount,directParts=0,0
for _,object in model:GetDescendants() do
    if object:IsA("LuaSourceContainer") then requireCheck(false,"조립에 Script 포함") end
    if object:IsA("Motor6D") then motorCount+=1 end
end
for _,object in model:GetChildren() do if object:IsA("BasePart") then directParts+=1;requireCheck(parts[object.Name]==object,"미검증 direct part") end end
requireCheck(directParts==16 and motorCount==15,"15 proxy/15 motor 수")
for _,entry in DATA.joints do
    local motor=unique(parts[entry.part1],entry.name)
    requireCheck(motor and motor:IsA("Motor6D") and motor.Enabled and motor.Part0==parts[entry.part0] and motor.Part1==parts[entry.part1],"관절 연결: "..entry.name)
    requireCheck(close(motor.C0,arrayFrame(entry.C0),0.0001) and close(motor.C1,arrayFrame(entry.C1),0.0001) and close(motor.Transform,CFrame.new(),0.0001),"관절 정지 bind: "..entry.name)
    for _,side in {{entry.part0,entry.C0},{entry.part1,entry.C1}} do
        local attachment=unique(parts[side[1]],entry.name.."RigAttachment")
        requireCheck(attachment and attachment:IsA("Attachment") and close(attachment.CFrame,arrayFrame(side[2]),0.0001),"RigAttachment: "..entry.name)
        attachments+=1
    end
end
requireCheck(attachments==30,"RigAttachment 수")
local meshes,bones,hosts,welds=0,0,0,0
local boneExpected={};for _,entry in DATA.bones do boneExpected[entry.name]=entry end
local nativeParts={};for _,entry in ACTUAL.parts do nativeParts[table.concat(entry.path,"\0")]=entry end
local nativeMeshes={};for _,entry in ACTUAL.meshes do nativeMeshes[table.concat(entry.path,"\0")]=entry end
local nativeBones={};for _,entry in ACTUAL.bones do nativeBones[table.concat(entry.path,"\0")]=entry end
local function skinPath(object)
    local names={};while object and object~=skin do table.insert(names,1,object.Name);object=object.Parent end
    requireCheck(object==skin,"스킨 밖 경로");return names
end
local maximumBoneError,maximumAxisError=0,0
for _,object in skin:GetDescendants() do
    if object:IsA("BasePart") then
        hosts+=1
        local key=table.concat(skinPath(object),"\0");local original=nativeParts[key]
        requireCheck(original~=nil,"기존 계층 밖 BasePart")
        requireCheck(close(object.Size,Vector3.new(table.unpack(original.size))/FIT.scale,0.002) and close(object.CFrame,normalized(original.cframe),0.002),"원본 전체 표면 정규화: "..object.Name)
        requireCheck(not object.Anchored and object.Massless and not object.CanCollide and not object.CanTouch and not object.CanQuery,"스킨 물리 설정")
        requireCheck(close(object:GetAttribute("HHC_SkinHostBindRoot"),root.CFrame:ToObjectSpace(object.CFrame),0.0001),"실제 shared host bind")
        local weld=unique(object,"CostumeSkinRootWeld")
        requireCheck(weld and weld:IsA("WeldConstraint") and weld.Enabled and weld.Part0==root and weld.Part1==object,"원래 shared host Root weld")
        if object:IsA("MeshPart") then
            meshes+=1;local originalMesh=nativeMeshes[key]
            requireCheck(originalMesh and object.MeshId==originalMesh.mesh_id and equal(appearance(object),originalMesh.appearance),"원본 메시/텍스처/재질 보존")
            requireCheck(close(object.PivotOffset,scaledLocal(originalMesh.pivot_offset),0.002),"원본 mesh pivot")
        else requireCheck(object.Transparency==1,"호스트 투명 설정") end
    elseif object:IsA("Bone") then
        bones+=1
        local path=skinPath(object);local original=nativeBones[table.concat(path,"\0")];local entry=boneExpected[object.Name]
        requireCheck(original and entry and at(skin,original.parent_path)==object.Parent,"원래 Bone 계층")
        requireCheck(close(object.CFrame,scaledLocal(original.cframe),0.0001) and close(object.Transform,CFrame.new(),0.0001),"원래 Bone local bind/정지 Transform")
        local expectedWorld=CFrame.new(table.unpack(entry.position))*CFrame.new(0,0,0,table.unpack(entry.unit_rotation))
        local error=(object.WorldCFrame.Position-expectedWorld.Position).Magnitude;maximumBoneError=math.max(maximumBoneError,error)
        local av,bv=frame(object.WorldCFrame),frame(expectedWorld)
        for k=4,12 do maximumAxisError=math.max(maximumAxisError,math.abs(av[k]-bv[k])) end
        requireCheck(error<=0.003 and close(object.WorldCFrame.Rotation,expectedWorld.Rotation,0.0001),"실제 단위 회전/위치: "..object.Name)
        requireCheck(object:GetAttribute("HHC_SkinBonePart")==entry.proxy_part and object:GetAttribute("HHC_SkinPrincipal")==entry.principal and object:GetAttribute("HHC_SkinSourceSHA256")==DATA.skin_sha256,"Bone 표식")
        requireCheck(object:GetAttribute("HHC_SkinParentBone")== (original.parent_bone or "") and object:GetAttribute("HHC_SkinBoneName")==object.Name,"Bone 실제 parent 표식")
        requireCheck(close(object:GetAttribute("HHC_SkinBindRoot"),root.CFrame:ToObjectSpace(object.WorldCFrame),0.0001) and close(object:GetAttribute("HHC_SkinBindLocal"),object.CFrame,0.0001),"Bone 실제 bind 표식")
    elseif object:IsA("WeldConstraint") then
        requireCheck(object.Name=="CostumeSkinRootWeld","미검증 skin weld");welds+=1
    elseif object:IsA("Constraint") then requireCheck(false,"미검증 skin constraint")
    elseif object:IsA("JointInstance") or object:IsA("Humanoid") or object:IsA("Animator") or object:IsA("AnimationController") then requireCheck(false,"미검증 skin controller") end
end
requireCheck(hosts==#ACTUAL.parts and welds==hosts and meshes==#DATA.meshes and bones==#ACTUAL.bones,"원본 전체 계층/메시/뼈/Root weld 수")
local manifest=HttpService:JSONDecode(model:GetAttribute("HHC_SkinManifest"))
requireCheck(manifest.schema==2 and manifest.name==DATA.name and manifest.skin_sha256==DATA.skin_sha256 and manifest.joints_sha256==DATA.joints_sha256 and manifest.contract_sha256==DATA.contract_sha256 and manifest.inspection_sha256==FIT.inspection_sha256,"manifest 출처")
requireCheck(manifest.unique_bones==#DATA.bones and manifest.bone_instances==bones and manifest.mesh_instances==meshes and #manifest.bones==#DATA.bones and #manifest.meshes==meshes,"manifest 수")
local seen={}
for _,entry in manifest.bones do
    local expected=boneExpected[entry.name]
    requireCheck(expected and not seen[entry.name] and entry.part==expected.proxy_part and entry.parent==expected.parent and entry.principal==expected.principal,"manifest 뼈 대응")
    seen[entry.name]=true
end
seen={}
for _,entry in manifest.meshes do
    local key=table.concat(entry.path,"\0");local object=at(skin,entry.path)
    requireCheck(not seen[key] and object and object:IsA("MeshPart") and object.MeshId==entry.mesh_id,"manifest 실제 mesh 대응");seen[key]=true
end
return HttpService:JSONEncode({schema=2,name=DATA.name,pending_name=DATA.pending_name,checks=checks,passed=true,read_only=true,
    unique_bones=#DATA.bones,bone_instances=bones,mesh_instances=meshes,proxy_parts=15,motors=motorCount,host_welds=welds,
    maximum_bone_error=maximumBoneError,maximum_axis_error=maximumAxisError,skin_sha256=DATA.skin_sha256,inspection_sha256=FIT.inspection_sha256,
    runtime_validated=false,animation_validated=false,ready=false,promotion=false})
'''
