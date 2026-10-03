"""Prepare offline read-only import inspection and guarded Pending skin assembly.

Never calls Studio, an API, an uploader or a playable registry. The assembly
payload is available only after strict validation of an actual inspect response.
Original skin GLBs are read only; inferred joints remain explicitly unvalidated.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re

import numpy as np

from assemble import manifest as proxy_manifest
from constraints import PRIMARY, PARENTS, RigError
from glb_io import read_glb, accessor_values

ROOT = Path(__file__).resolve().parents[2]

# Authoritative creation still belongs to the server/assembly tool. This client
# consumes only a complete, QA-promoted schema; it never creates/mutates Parts,
# Motors, Humanoids, meshes, hitboxes, stats or registry entries.
SCHEMA2={
    "schema":2,"draft":True,"promotion_automatic":False,
    "model_attributes":{
        "HHC_SkinRuntimeSchema":2,"HHC_SkinRetargetRequired":True,
        "HHC_SkinRuntimeValidated":"false until actual imported bind and live runtime QA",
        "HHC_RigReady":"false until server QA promotion","HHC_AnimationValidated":"false until live QA",
        "HHC_SkinSourceSHA256":"exact preserved/imported GLB sha256",
        "HHC_SourceSHA256":"preserved original GLB sha256","HHC_JointsSHA256":"proxy plan sha256",
        "HHC_SkinContractSHA256":"sidecar sha256","HHC_SkinInspectionSHA256":"actual imported bind inventory sha256",
        "HHC_SkinManifest":"JSON {schema=2,name,skin_sha256,joints_sha256,contract_sha256,inspection_sha256,unique_bones,bone_instances,mesh_instances,bones:[{name,parent,part,principal}],meshes:[{path:[relative names],mesh_id}]}",
        "HHC_SkinRootBindSize":"Vector3 at unposed bind","HHC_SkinBindScale":"Model:GetScale() at bind; diagnostic/server anchor only",
    },
    "proxy_attributes":{"HHC_ProxyBindRoot":"actual root-relative CFrame at bind","HHC_ProxyBindSize":"actual Vector3 Size at bind"},
    "bone_attributes":{"HHC_SkinBonePart":"exact principal/ancestor proxy part, or HumanoidRootPart for Aux_root",
        "HHC_SkinBindRoot":"actual unit-rotation root-relative Bone.WorldCFrame; never scaled glTF mat4",
        "HHC_SkinBindLocal":"actual Bone.CFrame at unposed bind","HHC_SkinParentBone":"true parent Bone.Name or empty string for BasePart host",
        "HHC_SkinPrincipal":"true only for exact 15 R15 principal names","HHC_SkinSourceSHA256":"same GLB source sha256"},
    "host_attributes":{"HHC_SkinHostBindRoot":"actual root-relative imported BasePart.CFrame; preserved shared RootPart allowed"},
    "scale_policy":"q=replicated Root.Size/bind Root.Size; require every proxy and Bone local frame to agree. SizeMult/VisualScale are targets, not physical truth; Model.Scale is Not Replicated.",
    "retarget":"desiredBoneWorld=liveProxyCFrame*scaledProxyBindRoot^-1*scaledBoneBindRoot; Transform=actualBone.CFrame^-1*desiredParentWorld^-1*desiredBoneWorld, true parent-first order",
    "sources":["inferred manual four: 15 principal bones; no original bones claimed","preserved paid fourteen: original 15 principal + 8 auxiliary; preserve full 23-bone hierarchy"],
    "surfaces":"actual manifest accepts 2 or 3 reviewed material surfaces; never assume Bone hierarchy is inside each MeshPart",
    "server_contract":"CostumeService validated direct 15 proxy Parts + Root/Humanoid/15 Motor6D; verified Animate/server Animator; original OFF/restore untouched",
    "runtime":"all clients update all current Player.Character models after Animator/Fx simulation; streaming/partial scale waits/rebinds; OFF/death/leave removes owned transforms/connections",
}

CLIENT_MODULE=r'''
-- SkinRetargetClient candidate: schema 2 only, QA-promoted server models only.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
local M={}
local ST={Started=false,Watch={},Records={},Connections={},BindName=nil,RetryAt=0,Frames=0,Faults=0}
local PRIMARY={"LowerTorso","UpperTorso","Head","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"}
local EDGES={Root={"HumanoidRootPart","LowerTorso"},Waist={"LowerTorso","UpperTorso"},Neck={"UpperTorso","Head"},LeftShoulder={"UpperTorso","LeftUpperArm"},LeftElbow={"LeftUpperArm","LeftLowerArm"},LeftWrist={"LeftLowerArm","LeftHand"},RightShoulder={"UpperTorso","RightUpperArm"},RightElbow={"RightUpperArm","RightLowerArm"},RightWrist={"RightLowerArm","RightHand"},LeftHip={"LowerTorso","LeftUpperLeg"},LeftKnee={"LeftUpperLeg","LeftLowerLeg"},LeftAnkle={"LeftLowerLeg","LeftFoot"},RightHip={"LowerTorso","RightUpperLeg"},RightKnee={"RightUpperLeg","RightLowerLeg"},RightAnkle={"RightLowerLeg","RightFoot"}}
local ALLOWED={}
for _,f in {"Halo","Horns","Neutral"} do for _,c in {"Warrior","Archer","Mage"} do for _,g in {"M","F"} do ALLOWED["Costume_"..f..c..g]=true end end end
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function hash(v) return type(v)=="string" and #v==64 and string.match(v,"^[0-9a-fA-F]+$")~=nil end
local function scaled(cf,q) return CFrame.new(cf.Position*q)*cf.Rotation end
local function close(a,b,tolerance)
    if typeof(a)~="CFrame" or typeof(b)~="CFrame" then return false end
    local aa,bb={a:GetComponents()},{b:GetComponents()}
    for i=1,12 do if not finite(aa[i]) or not finite(bb[i]) or math.abs(aa[i]-bb[i])>tolerance then return false end end
    return true
end
local function positive(v) return typeof(v)=="Vector3" and finite(v.X) and finite(v.Y) and finite(v.Z) and math.min(v.X,v.Y,v.Z)>0 end
local function equalSize(a,b) return positive(a) and positive(b) and (a-b).Magnitude<math.max(0.001,b.Magnitude*0.001) end
local function pathFrom(root,path)
    if type(path)~="table" or #path<1 or #path>32 then return nil end
    local object=root
    for _,name in path do
        if type(name)~="string" or name=="" then return nil end
        local found=nil
        for _,child in object:GetChildren() do if child.Name==name then if found then return nil end;found=child end end
        object=found;if not object then return nil end
    end
    return object
end
local function gate(character)
    return character and character.Parent and ALLOWED[character:GetAttribute("HHC_CostumeId")]
        and character:GetAttribute("HHC_SkinRuntimeSchema")==2
        and character:GetAttribute("HHC_SkinRetargetRequired")==true
        and character:GetAttribute("HHC_SkinRuntimeValidated")==true
        and character:GetAttribute("HHC_RigReady")==true
        and character:GetAttribute("HHC_AnimationValidated")==true
end
local function remove(player)
    local record=ST.Records[player];ST.Records[player]=nil
    if record then
        for _,row in record.Rows do
            if row.Bone.Parent and row.Bone:IsDescendantOf(record.Character) then row.Bone.Transform=CFrame.new() end
        end
    end
end
local function physicalScale(root)
    local bind=root.Parent:GetAttribute("HHC_SkinRootBindSize")
    if not positive(bind) or not positive(root.Size) then return nil end
    local ratios={root.Size.X/bind.X,root.Size.Y/bind.Y,root.Size.Z/bind.Z}
    local q=(ratios[1]+ratios[2]+ratios[3])/3
    if not finite(q) or q<0.01 or q>100 then return nil end
    for _,v in ratios do if math.abs(v-q)>math.max(0.001,q*0.001) then return nil end end
    return q
end
local function build(player,character)
    if player.Character~=character or not gate(character) then return nil end
    for _,key in {"HHC_SkinSourceSHA256","HHC_SourceSHA256","HHC_JointsSHA256","HHC_SkinContractSHA256","HHC_SkinInspectionSHA256"} do if not hash(character:GetAttribute(key)) then return nil end end
    local bindScale=character:GetAttribute("HHC_SkinBindScale")
    if not finite(bindScale) or bindScale<=0 then return nil end
    local encoded=character:GetAttribute("HHC_SkinManifest")
    if type(encoded)~="string" or #encoded>64000 then return nil end
    local manifest=HttpService:JSONDecode(encoded)
    if type(manifest)~="table" or manifest.schema~=2 or manifest.name~=character:GetAttribute("HHC_CostumeId") then return nil end
    for key,attribute in {skin_sha256="HHC_SkinSourceSHA256",joints_sha256="HHC_JointsSHA256",contract_sha256="HHC_SkinContractSHA256",inspection_sha256="HHC_SkinInspectionSHA256"} do if manifest[key]~=character:GetAttribute(attribute) then return nil end end
    if manifest.unique_bones~=15 and manifest.unique_bones~=23 then return nil end
    if manifest.unique_bones==15 then
        if character:GetAttribute("HHC_RigOrigin")~="inferred_manual_candidate" or character:GetAttribute("HHC_OriginalBonesClaimed")~=false then return nil end
    elseif character:GetAttribute("HHC_RigOrigin")~="preserved_source_skin_proxy_candidate" or character:GetAttribute("HHC_OriginalBonesClaimed")~=true then return nil end
    if manifest.mesh_instances~=2 and manifest.mesh_instances~=3 then return nil end
    if type(manifest.bones)~="table" or #manifest.bones~=manifest.unique_bones or type(manifest.meshes)~="table" or #manifest.meshes~=manifest.mesh_instances then return nil end
    if not finite(manifest.bone_instances) or manifest.bone_instances%1~=0 or manifest.bone_instances<manifest.unique_bones or manifest.bone_instances>manifest.unique_bones*manifest.mesh_instances then return nil end
    local root=character:FindFirstChild("HumanoidRootPart")
    local hum=character:FindFirstChildOfClass("Humanoid")
    local skin=character:FindFirstChild("CostumeSkin")
    if not root or not root:IsA("BasePart") or root.Anchored or not hum or hum.RigType~=Enum.HumanoidRigType.R15 or hum.Health<=0 or not skin or not skin:IsA("Model") then return nil end
    local q=physicalScale(root);if not q then return nil end
    local proxies={HumanoidRootPart=root};local proxyRows={}
    if not close(root:GetAttribute("HHC_ProxyBindRoot"),CFrame.new(),0.0001) then return nil end
    for _,name in PRIMARY do
        local part=character:FindFirstChild(name)
        if not part or not part:IsA("BasePart") or part.Anchored or part.Transparency~=1 then return nil end
        local bind,size=part:GetAttribute("HHC_ProxyBindRoot"),part:GetAttribute("HHC_ProxyBindSize")
        if typeof(bind)~="CFrame" or not positive(size) or not equalSize(part.Size,size*q) then return nil end
        proxies[name]=part;table.insert(proxyRows,{Part=part,Bind=bind,Size=size})
    end
    local graph={}
    for _,object in character:GetDescendants() do
        if object:IsA("Motor6D") and EDGES[object.Name] then
            if graph[object.Name] then return nil end
            local edge=EDGES[object.Name]
            if not object.Enabled or object.Part0~=proxies[edge[1]] or object.Part1~=proxies[edge[2]] then return nil end
            graph[object.Name]=object
        end
    end
    for name in EDGES do if not graph[name] then return nil end end
    local declared={};local principal=0
    for _,entry in manifest.bones do
        if type(entry.name)~="string" or declared[entry.name] or not proxies[entry.part] or type(entry.principal)~="boolean" or (entry.parent~=nil and type(entry.parent)~="string") then return nil end
        if entry.principal then if entry.name~=entry.part or entry.part=="HumanoidRootPart" then return nil end;principal+=1
        elseif not string.match(entry.name,"^Aux_[%w_]+$") then return nil end
        declared[entry.name]=entry
    end
    if principal~=15 then return nil end
    for _,name in PRIMARY do if not declared[name] or not declared[name].principal then return nil end end
    for _,entry in manifest.bones do
        local current=entry;local seen={}
        while current do
            if seen[current.name] then return nil end;seen[current.name]=true
            if current.parent~=nil then current=declared[current.parent];if not current then return nil end else current=nil end
        end
    end
    local meshMap={}
    for _,entry in manifest.meshes do
        local object=pathFrom(skin,entry.path)
        if not object or not object:IsA("MeshPart") or meshMap[object] or object.MeshId~=entry.mesh_id or not string.match(entry.mesh_id or "","^rbxassetid://[1-9]%d*$") or object.CanCollide or not object.Massless then return nil end
        meshMap[object]=entry
    end
    local rows,byBone,counts={}, {}, {};local meshCount=0
    for _,object in skin:GetDescendants() do
        if object:IsA("MeshPart") then meshCount+=1;if not meshMap[object] then return nil end
        elseif object:IsA("LuaSourceContainer") or object:IsA("Animator") or object:IsA("AnimationController") then return nil
        elseif object:IsA("Bone") then
            local entry=declared[object.Name]
            local bind=object:GetAttribute("HHC_SkinBindRoot");local localBind=object:GetAttribute("HHC_SkinBindLocal")
            local parent=object.Parent;local parentName=parent:IsA("Bone") and parent.Name or ""
            if not entry or object:GetAttribute("HHC_SkinBonePart")~=entry.part or object:GetAttribute("HHC_SkinPrincipal")~=entry.principal or object:GetAttribute("HHC_SkinSourceSHA256")~=character:GetAttribute("HHC_SkinSourceSHA256")
                or parentName~=(entry.parent or "") or parentName~=object:GetAttribute("HHC_SkinParentBone") or typeof(bind)~="CFrame" or typeof(localBind)~="CFrame" or not close(object.CFrame,scaled(localBind,q),math.max(0.001,q*0.001)) then return nil end
            local host=parent;local depth=0;local ancestor=parent
            while host and host~=skin and not host:IsA("BasePart") do host=host.Parent end
            while ancestor and ancestor~=skin do depth+=1;ancestor=ancestor.Parent end
            if not host or not host:IsA("BasePart") or host.CanCollide or not host.Massless or not close(root.CFrame:ToObjectSpace(host.CFrame),scaled(host:GetAttribute("HHC_SkinHostBindRoot"),q),math.max(0.001,q*0.001)) then return nil end
            local row={Bone=object,Part=proxies[entry.part],Bind=bind,LocalBind=localBind,PartBind=proxies[entry.part]:GetAttribute("HHC_ProxyBindRoot"),Host=host,HostBind=host:GetAttribute("HHC_SkinHostBindRoot"),Parent=parent,Depth=depth}
            table.insert(rows,row);byBone[object]=row;counts[object.Name]=(counts[object.Name] or 0)+1
        end
    end
    if meshCount~=manifest.mesh_instances or #rows~=manifest.bone_instances then return nil end
    for name in declared do if not counts[name] or counts[name]>manifest.mesh_instances then return nil end end
    table.sort(rows,function(a,b) return a.Depth<b.Depth end)
    for _,row in rows do row.ParentRow=row.Parent:IsA("Bone") and byBone[row.Parent] or nil;if row.Parent:IsA("Bone") and not row.ParentRow then return nil end end
    return {Character=character,Root=root,Humanoid=hum,Rows=rows,ProxyRows=proxyRows,Graph=graph,MeshMap=meshMap,Manifest=encoded,Frames=0,MaxError=0,Scale=q}
end
local function refresh(player)
    remove(player)
    local watcher=ST.Watch[player]
    if not watcher or not watcher.Character or watcher.Dead then return end
    local ok,record=pcall(build,player,watcher.Character)
    if ok then ST.Records[player]=record else ST.Faults+=1 end
end
local function queue(player)
    local watcher=ST.Watch[player]
    if not watcher or watcher.Queued then return end
    watcher.Queued=true
    task.defer(function() if ST.Started and ST.Watch[player]==watcher then watcher.Queued=false;refresh(player) end end)
end
local function characterWatch(player,character)
    remove(player)
    local watcher=ST.Watch[player];if not watcher then return end
    for _,connection in watcher.CharacterConnections do connection:Disconnect() end
    watcher.CharacterConnections={};watcher.Character=character;watcher.Dead=false
    if character then
        table.insert(watcher.CharacterConnections,character.AttributeChanged:Connect(function(name) if string.sub(name,1,4)=="HHC_" then queue(player) end end))
        table.insert(watcher.CharacterConnections,character.DescendantAdded:Connect(function(object) if object:IsA("Bone") or object:IsA("BasePart") or object:IsA("Humanoid") or object.Name=="CostumeSkin" then queue(player) end end))
        table.insert(watcher.CharacterConnections,character.DescendantRemoving:Connect(function(object) if object:IsA("Bone") or object:IsA("BasePart") or object:IsA("Humanoid") then queue(player) end end))
        table.insert(watcher.CharacterConnections,character.AncestryChanged:Connect(function(_,parent) if not parent then remove(player) end end))
    end
    queue(player)
end
local function addPlayer(player)
    if ST.Watch[player] then return end
    local watcher={CharacterConnections={},PlayerConnections={},Character=nil,Queued=false,Dead=false};ST.Watch[player]=watcher
    table.insert(watcher.PlayerConnections,player.CharacterAdded:Connect(function(character) characterWatch(player,character) end))
    table.insert(watcher.PlayerConnections,player.CharacterRemoving:Connect(function(character) if watcher.Character==character then characterWatch(player,nil) end end))
    characterWatch(player,player.Character)
end
local function removePlayer(player)
    remove(player);local watcher=ST.Watch[player];ST.Watch[player]=nil
    if not watcher then return end
    for _,connection in watcher.CharacterConnections do connection:Disconnect() end
    for _,connection in watcher.PlayerConnections do connection:Disconnect() end
end
local function apply(player,record)
    local character=record.Character
    if player.Character~=character or not gate(character) or not record.Humanoid.Parent or record.Humanoid.Health<=0 or character:GetAttribute("HHC_SkinManifest")~=record.Manifest then
        if record.Humanoid.Health<=0 and ST.Watch[player] then ST.Watch[player].Dead=true end
        remove(player);return
    end
    local q=physicalScale(record.Root);if not q then return end
    -- ScaleTo replicates properties piecemeal. Wait until sizes and every local
    -- bind agree; never permanently discard a valid character for that frame.
    for _,row in record.ProxyRows do if row.Part.Parent~=character or not equalSize(row.Part.Size,row.Size*q) then return end end
    for _,row in record.Rows do
        if not row.Bone.Parent or row.Bone.Parent~=row.Parent or not row.Bone:IsDescendantOf(character) or row.Part.Parent~=character then remove(player);return end
        if not close(row.Bone.CFrame,scaled(row.LocalBind,q),math.max(0.001,q*0.001)) or not close(record.Root.CFrame:ToObjectSpace(row.Host.CFrame),scaled(row.HostBind,q),math.max(0.001,q*0.001)) then return end
    end
    for _,row in record.Rows do
        row.Desired=row.Part.CFrame*scaled(row.PartBind,q):Inverse()*scaled(row.Bind,q)
        local parentWorld=row.ParentRow and row.ParentRow.Desired or row.Parent.CFrame
        row.Bone.Transform=row.Bone.CFrame:Inverse()*parentWorld:Inverse()*row.Desired
    end
    record.Scale=q;record.Frames+=1;ST.Frames+=1
    for _,row in record.Rows do record.MaxError=math.max(record.MaxError,(row.Bone.TransformedWorldCFrame.Position-row.Desired.Position).Magnitude) end
end
local function step(dt)
    ST.RetryAt+=math.max(0,dt or 0)
    if ST.RetryAt>=0.25 then
        ST.RetryAt=0
        for player,watcher in ST.Watch do if not ST.Records[player] and not watcher.Dead and gate(watcher.Character) then queue(player) end end
    end
    for player,record in ST.Records do
        local ok=pcall(apply,player,record)
        if not ok then ST.Faults+=1;remove(player) end
    end
end
function M.Init(_registry) end
function M.Start()
    if ST.Started then return end
    if not RunService:IsClient() or not RunService:IsRunning() then return end
    ST.Started=true;ST.BindName="HHC_SkinRetargetClient_"..HttpService:GenerateGUID(false)
    for _,player in Players:GetPlayers() do addPlayer(player) end
    table.insert(ST.Connections,Players.PlayerAdded:Connect(addPlayer))
    table.insert(ST.Connections,Players.PlayerRemoving:Connect(removePlayer))
    RunService:BindToRenderStep(ST.BindName,Enum.RenderPriority.Character.Value+1,step)
end
function M.Stop()
    if not ST.Started then return end
    ST.Started=false;RunService:UnbindFromRenderStep(ST.BindName)
    for player in ST.Watch do removePlayer(player) end
    for _,connection in ST.Connections do connection:Disconnect() end
    ST.Connections={};ST.RetryAt=0
end
function M.GetDebugSnapshot()
    local result={players=0,active=0,frames=ST.Frames,faults=ST.Faults,characters={}}
    for _ in ST.Watch do result.players+=1 end
    for player,record in ST.Records do result.active+=1;table.insert(result.characters,{user_id=player.UserId,frames=record.Frames,scale=record.Scale,max_error=record.MaxError}) end
    return result
end
return M
'''


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def finite(values, count):
    if not isinstance(values,list) or len(values)!=count or any(isinstance(v,bool) or not isinstance(v,(int,float)) or not math.isfinite(v) for v in values):
        raise RigError("A finite numeric frame/vector is required")
    return np.array(values,dtype=float)


def frame(values):
    v=finite(values,12); result=np.eye(4);result[:3,3]=v[:3];result[:3,:3]=v[3:].reshape(3,3)
    if np.max(np.abs(result[:3,:3].T@result[:3,:3]-np.eye(3)))>1e-4 or abs(np.linalg.det(result[:3,:3])-1)>1e-4:
        raise RigError("An actual imported CFrame is not a proper rigid frame")
    return result


def cf(matrix):
    return matrix[:3,3].tolist()+matrix[:3,:3].reshape(9).tolist()


def model_path(value):
    parts=value.split("/")
    if parts[0] not in ("Workspace","ServerStorage") or len(parts)<2 or any(not p or p in (".","..") or len(p)>150 for p in parts):
        raise RigError("Use an exact Workspace/... or ServerStorage/... model path")
    return parts


def prepare(contract_path, path):
    contract_path=Path(contract_path).resolve()
    contract=json.loads(contract_path.read_text(encoding="utf-8"))
    if contract.get("schema")!=1 or contract.get("rig_ready_for_game") is not False or contract.get("rig_origin")!="inferred_manual_candidate" or contract.get("original_bones_claimed") is not False:
        raise RigError("This version supports explicit unregistered inferred skin contracts")
    name=contract.get("name","")
    if name not in ("Costume_NeutralWarriorF","Costume_NeutralArcherM"):
        raise RigError("Only the two prepared Neutral skins are authorized here")
    source=Path(contract["skin_source"]).resolve()
    if sha(source)!=contract["skin_sha256"] or sha(contract["original_static_source"])!=contract["original_source_sha256"]:
        raise RigError("The preserved skin or original static source changed")
    proxy=proxy_manifest(contract["proxy_plan"],name,root_reference="lower-torso-y")
    gltf,binary,_=read_glb(source)
    metadata=gltf.get("extras",{}).get("HHC_ManualBind",{})
    if metadata.get("rig_ready_for_game") is not False or metadata.get("original_bones_claimed") is not False or len(gltf.get("skins",[]))!=1:
        raise RigError("The candidate skin lacks inferred provenance")
    affine=finite(contract["source_to_game_affine"],16).reshape(4,4).T
    if not np.allclose(affine[3],[0,0,0,1],atol=1e-9): raise RigError("Invalid skin wrapper affine")
    if len(gltf["meshes"])!=2 or len(gltf.get("images",[]))!=2:
        raise RigError("Exactly the preserved two surfaces/textures are required")
    meshes=[];points_by_mesh={}
    for mesh in gltf["meshes"]:
        mesh_name=mesh.get("name")
        if mesh_name not in contract["visual_mesh_names"]: raise RigError("Unexpected visual skin name")
        points=[]
        for primitive in mesh["primitives"]:
            if not {"POSITION","NORMAL","TEXCOORD_0","JOINTS_0","WEIGHTS_0"}<=set(primitive["attributes"]):
                raise RigError("A preserved skinned surface attribute is missing")
            points.extend(accessor_values(gltf,binary,primitive["attributes"]["POSITION"]))
        native=np.array(points);game=native@affine[:3,:3].T+affine[:3,3]
        low,high=game.min(0),game.max(0)
        meshes.append({"name":mesh_name,"center":((low+high)/2).tolist(),"size":(high-low).tolist()})
        points_by_mesh[mesh_name]=game
    bones={item["name"]:item for item in contract["bones"]}
    if set(bones)!=set(PRIMARY) or len(bones)!=len(contract["bones"]): raise RigError("Exactly 15 inferred principal joints are required")
    for part,item in bones.items():
        if item["parent"]!=PARENTS[part]: raise RigError("The inferred R15 hierarchy changed")
        finite(item["game_joint"],3)
        bind=finite(item["gltf_bind_game_world_column_major"],16).reshape(4,4).T
        lengths=np.linalg.norm(bind[:3,:3],axis=0)
        unit=bind[:3,:3]/lengths
        if min(lengths)<=0 or not np.allclose(lengths,lengths[0],atol=1e-6) or not np.allclose(unit.T@unit,np.eye(3),atol=1e-6) or np.linalg.det(unit)<0:
            raise RigError("The declared bind axes contain nonuniform scale or reflection")
        item["unit_rotation"]=unit.reshape(9).tolist()
    proxy_parts=[]
    for part in PRIMARY:
        geometry=next(item for item in proxy["meshes"] if item["name"]==part)
        proxy_parts.append({"name":part,"size":geometry["size"],"center":geometry["center"]})
    data={"schema":1,"name":name,"model_path":model_path(path),"skin_sha256":sha(source),
          "original_sha256":contract["original_source_sha256"],"contract_sha256":sha(contract_path),
          "joints_sha256":sha(contract["proxy_plan"]),"rig_origin":contract["rig_origin"],
          "meshes":meshes,"bones":[{"name":part,"parent":PARENTS[part],"position":bones[part]["game_joint"],"unit_rotation":bones[part]["unit_rotation"],"proxy_part":part} for part in PRIMARY],
          "proxy_parts":proxy_parts,"root":proxy["root"],"joints":proxy["joints"],"hip_height":proxy["hip_height"],
          "target_height":contract["target_height_studs"],"ready":False}
    return data,points_by_mesh


def load_inspection(path):
    data=json.loads(Path(path).read_text(encoding="utf-8"))
    if "result" in data and isinstance(data["result"],str): data=json.loads(data["result"])
    if not isinstance(data,dict) or data.get("schema")!=1:
        raise RigError("An actual read-only skin inspection JSON is required")
    return data


def normalize_root_import(inspection,data):
    """Support the parent's actual native Importer inventory, with old path prefix.

    The exact new storage target and source marker are required. Live assembly
    rechecks every supplied field and captures missing appearance/pivot fields
    before cloning. No claim that a MeshPart contains its own skeleton is made.
    """
    if inspection.get("path")!=".".join(data["model_path"]) or inspection.get("source_sha256")!=data["skin_sha256"] or inspection.get("name")!=data["name"]:
        raise RigError("The actual root import targets another exact model/source")
    nodes=inspection.get("nodes",[])
    if not nodes: raise RigError("Actual native import hierarchy is required")
    scripts=sum(n["class"] in ("Script","LocalScript","ModuleScript") for n in nodes)
    mesh_rows=inspection.get("meshes",[])
    prefixes={m["path"].rsplit(".",1)[0] for m in mesh_rows}
    if len(prefixes)!=1: raise RigError("Ambiguous actual source hierarchy root")
    prefix=prefixes.pop()+"."
    def relative(path):
        if not path.startswith(prefix): raise RigError("Actual imported reference is outside the inspected root")
        return path[len(prefix):].split(".")
    parts=[{"name":p["name"],"path":relative(p["path"]),"class":"Part","size":p["size"],"cframe":p["cframe"]} for p in inspection.get("base_parts",[])]
    meshes=[]
    for m in mesh_rows:
        path=relative(m["path"])
        parts.append({"name":m["name"],"path":path,"class":"MeshPart","size":m["size"],"cframe":m["cframe"]})
        meshes.append({"name":m["name"],"path":path,"mesh_id":m["mesh_id"],"size":m["size"],"mesh_size":m["mesh_size"],
                       "cframe":m["cframe"],"pivot_offset":m["pivot_offset"],"appearance":{"texture_id":m["texture_id"],"surfaces":m["surface"]}})
    partpaths={tuple(p["path"]) for p in parts}
    bones=[]
    for b in inspection.get("bones",[]):
        path=relative(b["path"]);hosts=[p for p in partpaths if tuple(path[:len(p)])==p]
        if len(hosts)!=1: raise RigError("Actual Bone does not have exactly one preserved BasePart host")
        parent=path[:-1]
        bones.append({"name":b["name"],"path":path,"parent_path":parent,"parent_bone":b["parent"] if tuple(parent) not in partpaths else None,
                      "host_path":list(hosts[0]),"cframe":b["cframe"],"world_cframe":b["world"],"transform":b["transform"]})
    result={"schema":1,"name":data["name"],"skin_sha256":data["skin_sha256"],"contract_sha256":data["contract_sha256"],"joints_sha256":data["joints_sha256"],
            "model_path":data["model_path"],"read_only":True,"edit_mode":True,"source_file_sha256":inspection["source_sha256"],
            "parts":parts,"meshes":meshes,"bones":bones,"scripts":scripts}
    for key in ("parts","meshes","bones"): result[key].sort(key=lambda row:tuple(row["path"]))
    return result


def validate_inspection(path,data,points_by_mesh):
    inspection=load_inspection(path)
    if inspection.get("synthetic_fixture"): raise RigError("Synthetic test data cannot authorize Pending assembly")
    if inspection.get("path") is not None: inspection=normalize_root_import(inspection,data)
    if inspection.get("read_only") is not True: raise RigError("An actual read-only skin inspection JSON is required")
    for key in ("name","skin_sha256","contract_sha256","joints_sha256","model_path"):
        if inspection.get(key)!=data[key]: raise RigError("The inspection targets another source/contract: "+key)
    if not inspection.get("edit_mode") or inspection.get("scripts",0)!=0: raise RigError("Only an inert Edit-mode imported model is supported")
    if inspection.get("source_file_sha256")!=data["skin_sha256"]: raise RigError("The imported source file SHA marker is missing or differs")
    meshes=inspection.get("meshes",[]);bones=inspection.get("bones",[])
    if len(meshes)!=len(data["meshes"]) or {m["name"] for m in meshes}!={m["name"] for m in data["meshes"]}: raise RigError("Actual imported surface count/names changed")
    expected={b["name"]:b for b in data["bones"]};byname={name:[] for name in expected};paths=set()
    for bone in bones:
        key=tuple(bone["path"])
        if key in paths or bone["name"] not in expected: raise RigError("Unknown/duplicate actual bone path")
        paths.add(key);byname[bone["name"]].append(bone)
        frame(bone["cframe"]);frame(bone["world_cframe"])
        if not np.allclose(frame(bone["transform"]),np.eye(4),atol=1e-5): raise RigError("An imported bone already has a posed Transform")
        parent=bone.get("parent_bone")
        if parent is not None and parent!=expected[bone["name"]]["parent"]: raise RigError("Actual Bone parent differs from the preserved hierarchy")
        if parent is None and expected[bone["name"]]["parent"] not in (None,"HumanoidRootPart"): raise RigError("An actual bone hierarchy link is missing")
        if tuple(bone["host_path"]) not in {tuple(p["path"]) for p in inspection["parts"]}: raise RigError("Bone host is not an inspected physical part")
    if any(not 1<=len(items)<=len(data["meshes"]) for items in byname.values()): raise RigError("The importer lost or duplicated a declared source bone")
    x=np.array([expected[name]["position"] for name in PRIMARY]);y=np.array([byname[name][0]["world_cframe"][:3] for name in PRIMARY])
    xc,yc=x-x.mean(0),y-y.mean(0)
    u,s,vh=np.linalg.svd(xc.T@yc)
    rotation=vh.T@u.T
    if np.linalg.det(rotation)<0 or np.linalg.matrix_rank(xc,tol=1e-7)<3: raise RigError("Mirrored/degenerate actual importer axes")
    scale=float(s.sum()/np.sum(xc*xc));offset=y.mean(0)-scale*rotation@x.mean(0)
    if not .01<scale<100: raise RigError("Unsupported actual uniform import scale")
    tolerance=max(.0005,data["target_height"]*scale*.0005)
    maximum_bone_error=0.
    maximum_axis_error=0.
    bonepaths={tuple(b["path"]):b for b in bones};partpaths={tuple(p["path"]):p for p in inspection["parts"]}
    for name,items in byname.items():
        target=scale*rotation@np.array(expected[name]["position"])+offset
        for bone in items:
            error=float(np.linalg.norm(np.array(bone["world_cframe"][:3])-target));maximum_bone_error=max(maximum_bone_error,error)
            if error>tolerance: raise RigError("Actual bone position violates common rigid/uniform import: "+name)
            actual_world=frame(bone["world_cframe"])
            expected_rotation=rotation@np.array(expected[name]["unit_rotation"]).reshape(3,3)
            axis_error=float(np.max(np.abs(actual_world[:3,:3]-expected_rotation)));maximum_axis_error=max(maximum_axis_error,axis_error)
            if axis_error>1e-4: raise RigError("Actual Bone bind axes differ from the unitized source axes: "+name)
            parent_key=tuple(bone["parent_path"])
            parent=bonepaths.get(parent_key) or partpaths.get(parent_key)
            if parent is None: raise RigError("Actual Bone parent path is not an inspected parent")
            parent_world=frame(parent.get("world_cframe",parent.get("cframe")))
            if not np.allclose(parent_world@frame(bone["cframe"]),actual_world,atol=.0001): raise RigError("Actual Bone local/world frame hierarchy is inconsistent: "+name)
    maximum_size_error=0.;native_bounds_policies={}
    for mesh in meshes:
        if not re.fullmatch(r"rbxassetid://[1-9][0-9]*",mesh.get("mesh_id","")): raise RigError("Actual imported mesh ID is missing")
        size=finite(mesh["size"],3);actual_cf=frame(mesh["cframe"]);frame(mesh["pivot_offset"])
        if min(size)<=0: raise RigError("Invalid imported mesh size")
        points=points_by_mesh[mesh["name"]]
        candidates=points if isinstance(points,dict) else {"full_accessor":points}
        matches=[]
        for policy,source_points in candidates.items():
            world=scale*(source_points@rotation.T)+offset
            local=(world-actual_cf[:3,3])@actual_cf[:3,:3]
            expected_size=local.max(0)-local.min(0);center=(local.max(0)+local.min(0))/2
            error=float(np.max(np.abs(expected_size-size)))
            if error<=max(.002,scale*.005) and np.max(np.abs(center))<=max(.002,scale*.005): matches.append((policy,error))
        if not matches:
            raise RigError("Actual imported surface Size/pivot/axes do not match the original skin: "+mesh["name"])
        maximum_size_error=max(maximum_size_error,min(error for _,error in matches))
        native_bounds_policies[mesh["name"]]=[policy for policy,_ in matches]
    # Translation of the new pivot is R^-1*(P-offset)/scale. Lua scales about
    # the old pivot first, then applies this rigid orientation/new pivot.
    return inspection,{"scale":scale,"rotation":rotation.reshape(9).tolist(),"offset":offset.tolist(),
                       "maximum_bone_error":maximum_bone_error,"maximum_size_error":maximum_size_error,"maximum_axis_error":maximum_axis_error,
                       "inspection_sha256":sha(path),"native_bounds_policies":native_bounds_policies}


COMMON=r'''
local HttpService=game:GetService("HttpService")
local RunService=game:GetService("RunService")
if RunService:IsRunning() then error("스킨 검증/조립은 Edit 모드에서만 실행합니다.") end
local DATA=HttpService:JSONDecode(__DATA__)
local source=DATA.model_path[1]=="Workspace" and workspace or game:GetService("ServerStorage")
for index=2,#DATA.model_path do
    source=source:FindFirstChild(DATA.model_path[index])
    if not source then error("정확한 가져온 모델 경로를 찾을 수 없습니다.") end
end
if not source:IsA("Model") then error("가져온 대상이 Model이 아닙니다.") end
local function relative(object)
    local names={}
    while object and object~=source do table.insert(names,1,object.Name);object=object.Parent end
    if object~=source then error("가져온 모델 밖의 참조입니다.") end
    return names
end
local function frame(value) return {value:GetComponents()} end
local function vec(value) return {value.X,value.Y,value.Z} end
local function appearance(part)
    local result={texture_id=part.TextureID,color={part.Color.R,part.Color.G,part.Color.B},material=part.Material.Name,transparency=part.Transparency,double_sided=part.DoubleSided,surfaces={}}
    for _,child in part:GetChildren() do
        if child:IsA("SurfaceAppearance") then
            table.insert(result.surfaces,{name=child.Name,color=child.ColorMap,normal=child.NormalMap,metal=child.MetalnessMap,rough=child.RoughnessMap,alpha=child.AlphaMode.Name})
        end
    end
    return result
end
local function snapshot()
    local result={schema=1,name=DATA.name,skin_sha256=DATA.skin_sha256,contract_sha256=DATA.contract_sha256,joints_sha256=DATA.joints_sha256,
        model_path=DATA.model_path,read_only=true,edit_mode=true,source_file_sha256=source:GetAttribute("HHC_SourceFileSHA256"),pivot=frame(source:GetPivot()),scale=source:GetScale(),meshes={},parts={},bones={},scripts=0}
    for _,child in source:GetDescendants() do
        if child:IsA("LuaSourceContainer") then result.scripts+=1 end
        if child:IsA("BasePart") then
            table.insert(result.parts,{name=child.Name,path=relative(child),class=child.ClassName,size=vec(child.Size),cframe=frame(child.CFrame)})
            if child:IsA("MeshPart") then
                local meshSize=nil;pcall(function() meshSize=vec(child.MeshSize) end)
                table.insert(result.meshes,{name=child.Name,path=relative(child),mesh_id=child.MeshId,size=vec(child.Size),mesh_size=meshSize,
                    cframe=frame(child.CFrame),pivot_offset=frame(child.PivotOffset),appearance=appearance(child)})
            end
        elseif child:IsA("Bone") then
            local host=child.Parent
            while host and host~=source and not host:IsA("BasePart") do host=host.Parent end
            if not host or not host:IsA("BasePart") then error("Bone의 실제 BasePart 호스트가 없습니다.") end
            table.insert(result.bones,{name=child.Name,path=relative(child),parent_bone=child.Parent:IsA("Bone") and child.Parent.Name or nil,
                parent_path=relative(child.Parent),host_path=relative(host),cframe=frame(child.CFrame),world_cframe=frame(child.WorldCFrame),transform=frame(child.Transform)})
        end
    end
    for _,rows in {result.parts,result.meshes,result.bones} do
        table.sort(rows,function(a,b) return table.concat(a.path,"\0")<table.concat(b.path,"\0") end)
    end
    return result
end
'''

INSPECT='return HttpService:JSONEncode(snapshot())\n'

ASSEMBLE=r'''
local SNAP=HttpService:JSONDecode(__SNAP__)
local FIT=HttpService:JSONDecode(__FIT__)
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)=="number" then return math.abs(a-b)<0.00001 end
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
    for key,value in expected do if not contains(actual[key],value) then return false end end
    return true
end
local ACTUAL=snapshot()
if not contains(ACTUAL,SNAP) then error("검사 이후 가져온 모델/뼈/자산/표면이 변경됐습니다.") end
if ACTUAL.source_file_sha256~=DATA.skin_sha256 then error("가져온 원본 파일 해시 표식 불일치") end
local storage=game:GetService("ServerStorage")
local pending=storage:FindFirstChild("CostumePendingRigs")
if pending and (not pending:IsA("Folder") or pending:FindFirstChild(DATA.name)) then error("대기 폴더 충돌/기존 모델: 덮어쓰지 않습니다.") end
local model=Instance.new("Model");model.Name=DATA.name
local ok,result=pcall(function()
    local skin=source:Clone()
    if not skin then error("원본 스킨 복제 실패") end
    skin.Name="CostumeSkin";skin.Parent=model
    for _,child in skin:GetDescendants() do
        if child:IsA("LuaSourceContainer") or child:IsA("JointInstance") or child:IsA("Constraint") or child:IsA("Humanoid") or child:IsA("Animator") or child:IsA("AnimationController") then child:Destroy() end
    end
    local oldPivot=skin:GetPivot()
    skin:ScaleTo(skin:GetScale()/FIT.scale)
    local r=FIT.rotation
    local importRotation=CFrame.new(0,0,0,table.unpack(r))
    local offset=Vector3.new(table.unpack(FIT.offset))
    local normalizedPosition=importRotation:VectorToObjectSpace(oldPivot.Position-offset)/FIT.scale
    skin:PivotTo(CFrame.new(normalizedPosition)*importRotation:Inverse().Rotation*oldPivot.Rotation)
    local parts={}
    local root=Instance.new("Part");root.Name="HumanoidRootPart"
    root.Size=Vector3.new(table.unpack(DATA.root.size));root.CFrame=CFrame.new(table.unpack(DATA.root.center))
    root.Transparency=1;root.Anchored=false;root.Massless=false;root.RootPriority=127
    root.CanCollide=false;root.CanTouch=false;root.CanQuery=false;root.Parent=model
    parts.HumanoidRootPart=root
    for _,entry in DATA.proxy_parts do
        local part=Instance.new("Part");part.Name=entry.name;part.Size=Vector3.new(table.unpack(entry.size));part.CFrame=CFrame.new(table.unpack(entry.center))
        part.Transparency=1;part.Massless=true;part.Anchored=false;part.CanTouch=false
        part.CanCollide=entry.name=="Head" or entry.name=="UpperTorso" or entry.name=="LowerTorso"
        part.CanQuery=true;part.Parent=model;parts[entry.name]=part
        part:SetAttribute("HHC_ProxyBindRoot",root.CFrame:ToObjectSpace(part.CFrame))
    end
    root:SetAttribute("HHC_ProxyBindRoot",CFrame.new())
    for _,entry in DATA.joints do
        local motor=Instance.new("Motor6D");motor.Name=entry.name;motor.Part0=parts[entry.part0];motor.Part1=parts[entry.part1]
        motor.C0=CFrame.new(table.unpack(entry.C0));motor.C1=CFrame.new(table.unpack(entry.C1));motor.Transform=CFrame.new();motor.Parent=motor.Part1
        if ((motor.Part0.CFrame*motor.C0).Position-(motor.Part1.CFrame*motor.C1).Position).Magnitude>0.0001 then error("R15 관절 접점 불일치") end
        for _,side in {{entry.part0,entry.C0},{entry.part1,entry.C1}} do
            local attachment=Instance.new("Attachment");attachment.Name=entry.name.."RigAttachment";attachment.CFrame=CFrame.new(table.unpack(side[2]));attachment.Parent=parts[side[1]]
        end
    end
    local expectedBones={}
    for _,entry in DATA.bones do expectedBones[entry.name]=entry end
    local boneCount,meshCount,hostCount=0,0,0
    for _,child in skin:GetDescendants() do
        if child:IsA("BasePart") then
            child.Anchored=false;child.Massless=true;child.CanCollide=false;child.CanTouch=false;child.CanQuery=false
            if child:IsA("MeshPart") then
                meshCount+=1
                local before=nil
                for _,entry in ACTUAL.meshes do if entry.name==child.Name then before=entry;break end end
                if not before or child.MeshId~=before.mesh_id or not equal(appearance(child),before.appearance) then error("원본 스킨 외형/에셋이 변경됐습니다.") end
            else child.Transparency=1 end
            child:SetAttribute("HHC_SkinHostBindRoot",root.CFrame:ToObjectSpace(child.CFrame))
            local weld=Instance.new("WeldConstraint");weld.Name="CostumeSkinRootWeld";weld.Part0=root;weld.Part1=child;weld.Parent=child;hostCount+=1
        elseif child:IsA("Bone") then
            boneCount+=1
            local expected=expectedBones[child.Name]
            if not expected then error("미검증 Bone이 복제됐습니다.") end
            local target=Vector3.new(table.unpack(expected.position))
            if (child.WorldCFrame.Position-target).Magnitude>0.002 then error("정규화 후 Bone 위치 불일치: "..child.Name) end
            if not equal(frame(child.Transform),frame(CFrame.new())) then error("원본 Bone이 이미 움직였습니다.") end
            child:SetAttribute("HHC_SkinBonePart",expected.proxy_part)
            child:SetAttribute("HHC_SkinBoneName",child.Name)
            child:SetAttribute("HHC_SkinBindRoot",root.CFrame:ToObjectSpace(child.WorldCFrame))
            child:SetAttribute("HHC_SkinBindLocal",child.CFrame)
            child:SetAttribute("HHC_SkinParentBone",child.Parent:IsA("Bone") and child.Parent.Name or "")
            child:SetAttribute("HHC_SkinSourceSHA256",DATA.skin_sha256)
            child:SetAttribute("HHC_SkinPrincipal",true)
        end
    end
    if meshCount~=2 or boneCount~=#SNAP.bones then error("원본 스킨의 메시/뼈 수가 변경됐습니다.") end
    local humanoid=Instance.new("Humanoid");humanoid.Name="Humanoid";humanoid.RigType=Enum.HumanoidRigType.R15
    humanoid.AutomaticScalingEnabled=false;humanoid.HipHeight=DATA.hip_height;humanoid.BreakJointsOnDeath=false;humanoid.RequiresNeck=true;humanoid.Parent=model
    Instance.new("Animator").Parent=humanoid;model.PrimaryPart=root
    model:SetAttribute("HHC_SourceSHA256",DATA.original_sha256);model:SetAttribute("HHC_SkinSourceSHA256",DATA.skin_sha256)
    model:SetAttribute("HHC_JointsSHA256",DATA.joints_sha256);model:SetAttribute("HHC_SkinContractSHA256",DATA.contract_sha256)
    model:SetAttribute("HHC_SkinInspectionSHA256",FIT.inspection_sha256)
    model:SetAttribute("HHC_RigOrigin",DATA.rig_origin);model:SetAttribute("HHC_InferredManualCandidate",true);model:SetAttribute("HHC_OriginalBonesClaimed",false)
    model:SetAttribute("HHC_OriginalUVPreserved",true);model:SetAttribute("HHC_OriginalTextureBytesPreserved",true)
    model:SetAttribute("HHC_SkinRuntimeSchema",1);model:SetAttribute("HHC_SkinRetargetRequired",true)
    model:SetAttribute("HHC_PendingAnimationQA",true);model:SetAttribute("HHC_AnimationValidated",false);model:SetAttribute("HHC_RigReady",false)
    return {schema=1,name=DATA.name,mesh_parts=meshCount,bones=boneCount,body_parts=15,motors=#DATA.joints,host_welds=hostCount,
        skin_sha256=DATA.skin_sha256,inspection_sha256=FIT.inspection_sha256,animation_validated=false,ready=false,
        rig_origin=DATA.rig_origin,destination="ServerStorage.CostumePendingRigs."..DATA.name}
end)
if not ok then model:Destroy();error(result) end
if not pending then pending=Instance.new("Folder");pending.Name="CostumePendingRigs";pending.Parent=storage end
model.Parent=pending
return HttpService:JSONEncode(result)
'''

# Trial only. Fx writes Motor6D in PreSimulation; final physical proxy frames
# are available after that simulation batch. Character+1 follows Animator and
# the default Camera update and reads CFrames, rather than stale motor values.
DRIVER=r'''
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
if not RunService:IsRunning() then error("스킨 시험 동작은 Play 클라이언트에서만 실행합니다.") end
local player=Players.LocalPlayer
if not player then error("스킨 시험은 로컬 클라이언트 전용입니다.") end
local DATA=HttpService:JSONDecode(__DATA__)
local TRIAL=HttpService:JSONDecode(__TRIAL__)
local bindName="HHC_SkinRetargetTrial_"..player.UserId.."_"..HttpService:GenerateGUID(false)
local state={character=nil,root=nil,humanoid=nil,rows={},watch={},global={},frames=0,maxError=0,closed=false,queued=false}
local function closeFrame(a,b)
    if typeof(a)~="CFrame" or typeof(b)~="CFrame" then return false end
    local aa,bb={a:GetComponents()},{b:GetComponents()}
    for i=1,12 do if math.abs(aa[i]-bb[i])>0.0001 then return false end end
    return true
end
local function unbind()
    RunService:UnbindFromRenderStep(bindName)
    for _,row in state.rows do
        if row.bone.Parent and state.character and row.bone:IsDescendantOf(state.character) then row.bone.Transform=row.previous end
    end
    state.rows={};state.root=nil;state.humanoid=nil
end
local function metadata(model)
    return model:GetAttribute("HHC_CostumeId")==DATA.name
        and model:GetAttribute("HHC_SkinRuntimeSchema")==1
        and model:GetAttribute("HHC_SkinSourceSHA256")==DATA.skin_sha256
        and model:GetAttribute("HHC_SourceSHA256")==DATA.original_sha256
        and model:GetAttribute("HHC_JointsSHA256")==DATA.joints_sha256
        and model:GetAttribute("HHC_SkinContractSHA256")==DATA.contract_sha256
        and model:GetAttribute("HHC_SkinInspectionSHA256")==TRIAL.inspection_sha256
        and model:GetAttribute("HHC_RigOrigin")=="inferred_manual_candidate"
        and model:GetAttribute("HHC_OriginalBonesClaimed")==false
        and model:GetAttribute("HHC_InferredManualCandidate")==true
        and model:GetAttribute("HHC_OriginalUVPreserved")==true
        and model:GetAttribute("HHC_OriginalTextureBytesPreserved")==true
        and model:GetAttribute("HHC_PendingAnimationQA")==true
        and model:GetAttribute("HHC_SkinRetargetRequired")==true
        and model:GetAttribute("HHC_RigReady")==false
end
local function validate(character)
    if character~=player.Character or not metadata(character) then return nil end
    local root=character:FindFirstChild("HumanoidRootPart")
    local humanoid=character:FindFirstChildOfClass("Humanoid")
    local skin=character:FindFirstChild("CostumeSkin")
    if not root or not root:IsA("BasePart") or root.Anchored or not humanoid or humanoid.RigType~=Enum.HumanoidRigType.R15 or humanoid.Health<=0 or not skin or not skin:IsA("Model") then return nil end
    local expected={};for _,entry in DATA.bones do expected[entry.name]=entry end
    local proxies={}
    for _,entry in DATA.proxy_parts do
        local part=character:FindFirstChild(entry.name)
        if not part or not part:IsA("BasePart") or part.Anchored or part.Transparency~=1 or typeof(part:GetAttribute("HHC_ProxyBindRoot"))~="CFrame" then return nil end
        if not closeFrame(part:GetAttribute("HHC_ProxyBindRoot"),CFrame.new(table.unpack(entry.center))-Vector3.new(table.unpack(DATA.root.center))) then return nil end
        proxies[entry.name]=part
    end
    local motors={};local motorCount=0
    for _,object in character:GetDescendants() do
        if object:IsA("Motor6D") then
            motorCount+=1
            if motors[object.Name] then return nil end
            motors[object.Name]=object
        end
    end
    if motorCount~=#DATA.joints then return nil end
    for _,entry in DATA.joints do
        local motor=motors[entry.name]
        local p0=entry.part0=="HumanoidRootPart" and root or proxies[entry.part0]
        if not motor or not motor.Enabled or motor.Part0~=p0 or motor.Part1~=proxies[entry.part1] then return nil end
        if not closeFrame(motor.C0,CFrame.new(table.unpack(entry.C0))) or not closeFrame(motor.C1,CFrame.new(table.unpack(entry.C1))) then return nil end
    end
    local rows,byBone,counts={}, {}, {};local meshCount=0
    for _,object in skin:GetDescendants() do
        if object:IsA("MeshPart") then
            meshCount+=1
            if object.MeshId~=TRIAL.mesh_ids[object.Name] or object.CanCollide or not object.Massless then return nil end
        elseif object:IsA("LuaSourceContainer") or object:IsA("AnimationController") or object:IsA("Animator") then return nil
        elseif object:IsA("Bone") then
            local entry=expected[object.Name]
            local boneBind=object:GetAttribute("HHC_SkinBindRoot")
            local localBind=object:GetAttribute("HHC_SkinBindLocal")
            local partName=object:GetAttribute("HHC_SkinBonePart")
            if not entry or partName~=entry.proxy_part or typeof(boneBind)~="CFrame" or not closeFrame(localBind,object.CFrame)
                or object:GetAttribute("HHC_SkinSourceSHA256")~=DATA.skin_sha256 or object:GetAttribute("HHC_SkinPrincipal")~=true then return nil end
            local expectedPosition=Vector3.new(table.unpack(entry.position))-Vector3.new(table.unpack(DATA.root.center))
            local expectedBind=CFrame.new(expectedPosition)*CFrame.new(0,0,0,table.unpack(entry.unit_rotation))
            if not closeFrame(boneBind,expectedBind) then return nil end
            local parent=object.Parent
            local parentName=parent:IsA("Bone") and parent.Name or ""
            if parentName~=object:GetAttribute("HHC_SkinParentBone") or (parentName~="" and parentName~=entry.parent) then return nil end
            local host=parent
            while host and host~=skin and not host:IsA("BasePart") do host=host.Parent end
            if not host or not host:IsA("BasePart") or host.CanCollide or not host.Massless or not closeFrame(host:GetAttribute("HHC_SkinHostBindRoot"),root.CFrame:ToObjectSpace(host.CFrame)) then return nil end
            local depth=0;local ancestor=parent
            while ancestor and ancestor~=skin do depth+=1;ancestor=ancestor.Parent end
            local row={bone=object,part=proxies[partName],boneBind=boneBind,partBind=proxies[partName]:GetAttribute("HHC_ProxyBindRoot"),localBind=localBind,parent=parent,host=host,depth=depth,previous=object.Transform}
            table.insert(rows,row);byBone[object]=row;counts[object.Name]=(counts[object.Name] or 0)+1
        end
    end
    if meshCount~=#DATA.meshes or #rows~=TRIAL.bone_count then return nil end
    for name in expected do if not counts[name] or counts[name]>2 then return nil end end
    table.sort(rows,function(a,b) return a.depth<b.depth end)
    for _,row in rows do
        row.parentRow=row.parent:IsA("Bone") and byBone[row.parent] or nil
        if row.parent:IsA("Bone") and not row.parentRow then return nil end
    end
    return {root=root,humanoid=humanoid,rows=rows}
end
local function step()
    local character=state.character
    if character~=player.Character or not character.Parent or not metadata(character) or not state.humanoid.Parent or state.humanoid.Health<=0 then unbind();return end
    local maximum=0
    for _,row in state.rows do
        if not row.bone.Parent or row.part.Parent~=character or row.bone.Parent~=row.parent or not closeFrame(row.bone.CFrame,row.localBind) then unbind();return end
        -- LivePart * RestPart^-1 * ActualBoneBind. The true Bone parent may be
        -- another Bone or the Importer's shared RootPart, never an assumed mesh.
        row.desired=row.part.CFrame*row.partBind:Inverse()*row.boneBind
        local parentWorld=row.parentRow and row.parentRow.desired or row.parent.CFrame
        row.bone.Transform=row.localBind:Inverse()*parentWorld:Inverse()*row.desired
    end
    for _,row in state.rows do maximum=math.max(maximum,(row.bone.TransformedWorldCFrame.Position-row.desired.Position).Magnitude) end
    state.frames+=1;state.maxError=math.max(state.maxError,maximum)
    character:SetAttribute("HHC_SkinTrialFrames",state.frames)
    character:SetAttribute("HHC_SkinTrialMaxError",state.maxError)
    character:SetAttribute("HHC_SkinTrialOnly",true)
end
local function refresh()
    if state.closed then return end
    unbind()
    if not state.character then return end
    local ok,result=pcall(validate,state.character)
    if not ok then warn("스킨 시험 검증 실패: "..tostring(result));return end
    if not result then return end
    state.root=result.root;state.humanoid=result.humanoid;state.rows=result.rows;state.frames=0;state.maxError=0
    RunService:BindToRenderStep(bindName,Enum.RenderPriority.Character.Value+1,function()
        local success,message=pcall(step)
        if not success then unbind();warn("스킨 시험 동작 중단: "..tostring(message)) end
    end)
end
local function queue()
    if state.queued or state.closed then return end
    state.queued=true;task.defer(function() state.queued=false;refresh() end)
end
local function watch(character)
    unbind();for _,connection in state.watch do connection:Disconnect() end;state.watch={};state.character=character
    if character then
        table.insert(state.watch,character.AttributeChanged:Connect(function(name) if name=="HHC_CostumeId" or name=="HHC_SkinRuntimeSchema" then queue() end end))
        table.insert(state.watch,character.DescendantAdded:Connect(queue))
        table.insert(state.watch,character.AncestryChanged:Connect(function(_,parent) if not parent then unbind() end end))
    end
    queue()
end
table.insert(state.global,player.CharacterAdded:Connect(watch))
table.insert(state.global,player.CharacterRemoving:Connect(function(character) if character==state.character then watch(nil) end end))
script.Destroying:Connect(function()
    state.closed=true;unbind()
    for _,connection in state.watch do connection:Disconnect() end
    for _,connection in state.global do connection:Disconnect() end
end)
watch(player.Character)
'''


def literal(data):
    return json.dumps(json.dumps(data,ensure_ascii=False,separators=(",",":")),ensure_ascii=False)


def write_payload(data,mode,output,inspection=None,fit=None):
    output=Path(output).resolve();output.relative_to((ROOT/"build").resolve())
    if output.exists(): raise RigError("Existing payloads are never overwritten")
    code=COMMON.replace("__DATA__",literal(data))
    if mode=="inspect": code+=INSPECT
    elif mode=="assemble":
        if inspection is None or fit is None: raise RigError("Actual validated inspection is required before assembly")
        code+=ASSEMBLE.replace("__SNAP__",literal(inspection)).replace("__FIT__",literal(fit))
    elif mode=="driver":
        if inspection is None or fit is None: raise RigError("Actual validated inspection is required before a trial driver")
        trial={"inspection_sha256":fit["inspection_sha256"],"bone_count":len(inspection["bones"]),"mesh_ids":{m["name"]:m["mesh_id"] for m in inspection["meshes"]}}
        code=DRIVER.replace("__DATA__",literal(data)).replace("__TRIAL__",literal(trial))
    output.parent.mkdir(parents=True,exist_ok=True)
    payload={"code":code,"datamodel_type":"Edit"}
    if mode=="driver": payload={"source":code,"class_name":"LocalScript","name":"HHC_SkinRetargetTrial","recommended_parent":"StarterPlayer.StarterPlayerScripts","trial_only":True,"ready":False}
    output.write_text(json.dumps(payload,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return {"mode":mode,"payload":str(output),"name":data["name"],"studio_calls":0,"api_calls":0,"promotion":False,"ready":False}


def write_draft(output,value):
    output=Path(output).resolve();output.relative_to((ROOT/"build").resolve())
    if output.exists(): raise RigError("Existing drafts are never overwritten")
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(value if isinstance(value,str) else json.dumps(value,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return {"draft":str(output),"studio_calls":0,"api_calls":0,"production_registered":False,"promotion":False}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("contract",type=Path,nargs="?");parser.add_argument("--model-path")
    parser.add_argument("--mode",choices=("inspect","assemble","driver","module","schema"),default="inspect")
    parser.add_argument("--inspection",type=Path);parser.add_argument("--output",required=True,type=Path)
    args=parser.parse_args()
    if args.mode in ("module","schema"):
        print(json.dumps(write_draft(args.output,CLIENT_MODULE if args.mode=="module" else SCHEMA2),ensure_ascii=False));return
    if not args.contract or not args.model_path: parser.error("An exact contract and --model-path are required for actual import work")
    data,points=prepare(args.contract,args.model_path)
    actual,fit=None,None
    if args.mode in ("assemble","driver"):
        if not args.inspection: parser.error("--inspection is required before assembly")
        actual,fit=validate_inspection(args.inspection,data,points)
    print(json.dumps(write_payload(data,args.mode,args.output,actual,fit),ensure_ascii=False))


if __name__=="__main__":
    try: main()
    except (RigError,KeyError,ValueError,OSError) as error:
        raise SystemExit("skin_runtime refused: "+str(error))
