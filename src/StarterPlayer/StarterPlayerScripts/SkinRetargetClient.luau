
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
