-- Actual native import inventories drive these offline object doubles.
-- No imported file, asset, Studio model or game registry is changed.
VM.__div=function(a,b) return Vec.new(a.X/b,a.Y/b,a.Z/b) end
function CF:VectorToObjectSpace(value) return rotate(self:Inverse().R,value) end
local originalIsA=Obj.IsA
function Obj:IsA(class)
    return originalIsA(self,class) or (class=="JointInstance" and (self.ClassName=="Motor6D" or self.ClassName=="Weld"))
        or (class=="Attachment" and self.ClassName=="Bone")
end
function Obj:GetPivot() return self.Pivot or CF.new() end
local function vector(row) return Vec.new(table.unpack(row)) end
local function arrayCF(row) return CF.new(table.unpack(row)) end
local function pathKey(path) return table.concat(path,"\0") end
local function locate(parent,path)
    for _,name in path do parent=parent:FindFirstChild(name);if not parent then return nil end end
    return parent
end
local function removeObject(item)
    local children=item.Parent.Children
    for i,child in children do if child==item then table.remove(children,i);break end end
    item.Parent=nil
end
local function makeCase(data,snap,fit)
    local storage=object("Folder","ServerStorage")
    local sourceFolder=storage:Add(object("Folder",data.model_path[2]))
    local source=sourceFolder:Add(object("Model",data.name));source.Attrs.HHC_SourceFileSHA256=data.skin_sha256
    if snap.pivot then source.Pivot=arrayCF(snap.pivot) end
    if snap.scale then source.Scale=snap.scale end
    local function construct(parent,path,class)
        for i=1,#path-1 do local nextParent=parent:FindFirstChild(path[i]);if not nextParent then nextParent=parent:Add(object("Model",path[i])) end;parent=nextParent end
        return parent:Add(object(class,path[#path]))
    end
    local sourceParts={};local sourceMeshes={}
    for _,entry in snap.parts do
        local part=construct(source,entry.path,entry.class);part.Size=vector(entry.size);part.CFrame=arrayCF(entry.cframe);sourceParts[pathKey(entry.path)]=part
    end
    for _,entry in snap.meshes do
        local part=sourceParts[pathKey(entry.path)];local a=entry.appearance
        part.MeshId=entry.mesh_id;part.MeshSize=vector(entry.mesh_size);part.PivotOffset=arrayCF(entry.pivot_offset)
        part.TextureID=a.texture_id;part.Color={R=a.color and a.color[1] or .5,G=a.color and a.color[2] or .5,B=a.color and a.color[3] or .5}
        part.Material={Name=a.material or "Plastic"};part.Transparency=a.transparency or 0;part.DoubleSided=a.double_sided or false
        sourceMeshes[pathKey(entry.path)]=part
    end
    local sorted=table.clone(snap.bones);table.sort(sorted,function(a,b) return #a.path<#b.path end)
    for _,entry in sorted do
        local bone=construct(source,entry.path,"Bone");bone.CFrame=arrayCF(entry.cframe);bone.Transform=arrayCF(entry.transform)
    end
    local pending=storage:Add(object("Folder","CostumePendingRigs"))
    local model=pending:Add(object("Model",data.pending_name));local skin=model:Add(object("Model","CostumeSkin"))
    local r=CF.new(0,0,0,table.unpack(fit.rotation));local offset=vector(fit.offset)
    local function normalized(value)
        local cf=arrayCF(value)
        return CF.new(r:VectorToObjectSpace(cf.Position-offset)/fit.scale)*r:Inverse().Rotation*cf.Rotation
    end
    local function localScale(value) local cf=arrayCF(value);return CF.new(cf.Position/fit.scale)*cf.Rotation end
    local root=model:Add(object("Part","HumanoidRootPart"));root.Size=vector(data.root.size);root.CFrame=CF.new(table.unpack(data.root.center));model.PrimaryPart=root
    root.Massless=false;root.RootPriority=127;root.CanTouch=false;root.CanQuery=false
    root.Attrs={HHC_ProxyBindRoot=CF.new(),HHC_ProxyBindSize=root.Size}
    local parts={HumanoidRootPart=root}
    for _,entry in data.proxy_parts do
        local part=model:Add(object("Part",entry.name));part.Size=vector(entry.size);part.CFrame=CF.new(table.unpack(entry.center));part.CanTouch=false;part.CanQuery=true
        part.CanCollide=entry.name=="Head" or entry.name=="UpperTorso" or entry.name=="LowerTorso"
        part.Attrs={HHC_ProxyBindRoot=root.CFrame:ToObjectSpace(part.CFrame),HHC_ProxyBindSize=part.Size};parts[entry.name]=part
    end
    local motors={}
    for _,entry in data.joints do
        local motor=parts[entry.part1]:Add(object("Motor6D",entry.name));motor.Part0=parts[entry.part0];motor.Part1=parts[entry.part1];motor.C0=arrayCF(entry.C0);motor.C1=arrayCF(entry.C1);motors[entry.name]=motor
        for _,side in {{entry.part0,entry.C0},{entry.part1,entry.C1}} do local a=parts[side[1]]:Add(object("Attachment",entry.name.."RigAttachment"));a.CFrame=arrayCF(side[2]) end
    end
    local skinParts={};local skinMeshes={};local skinBones={}
    for _,entry in snap.parts do
        local part=construct(skin,entry.path,entry.class);part.Size=vector(entry.size)/fit.scale;part.CFrame=normalized(entry.cframe);part.CanTouch=false;part.CanQuery=false
        part.Attrs.HHC_SkinHostBindRoot=root.CFrame:ToObjectSpace(part.CFrame);skinParts[pathKey(entry.path)]=part
        if not data.binding then local w=part:Add(object("WeldConstraint","CostumeSkinRootWeld"));w.Part0=root;w.Part1=part end
    end
    for _,entry in snap.meshes do
        local part=skinParts[pathKey(entry.path)];local before=sourceMeshes[pathKey(entry.path)]
        part.MeshId=before.MeshId;part.MeshSize=before.MeshSize;part.PivotOffset=localScale(entry.pivot_offset)
        part.TextureID=before.TextureID;part.Color=before.Color;part.Material=before.Material;part.Transparency=before.Transparency;part.DoubleSided=before.DoubleSided
        skinMeshes[pathKey(entry.path)]=part
    end
    local expected={};for _,entry in data.bones do expected[entry.name]=entry end
    for _,entry in sorted do
        local bone=construct(skin,entry.path,"Bone");bone.CFrame=localScale(entry.cframe);skinBones[entry.name]=bone
        bone.Attrs={HHC_SkinBonePart=expected[entry.name].proxy_part,HHC_SkinPrincipal=expected[entry.name].principal,HHC_SkinSourceSHA256=data.skin_sha256,
            HHC_SkinParentBone=entry.parent_bone or "",HHC_SkinBoneName=entry.name,HHC_SkinBindRoot=root.CFrame:ToObjectSpace(bone.WorldCFrame),HHC_SkinBindLocal=bone.CFrame}
    end
    if data.binding then
        local anchor=locate(skin,data.binding.anchor_path)
        local value=skin:Add(object("ObjectValue","HHC_SkinBindingHost"));value.Value=anchor
        local rootWeld=anchor:Add(object("WeldConstraint","CostumeSkinRootWeld"));rootWeld.Part0=root;rootWeld.Part1=anchor
        for _,part in skinParts do
            if part~=anchor then
                local w=part:Add(object("Weld","CostumeSkinInternalWeld"));w.Part0=anchor;w.Part1=part
                w.C0=anchor.Attrs.HHC_SkinHostBindRoot:Inverse()*part.Attrs.HHC_SkinHostBindRoot;w.C1=CF.new()
            end
        end
    end
    local hum=model:Add(object("Humanoid","Humanoid"));hum.RigType="R15";hum.Health=100;hum.AutomaticScalingEnabled=false;hum.BreakJointsOnDeath=false;hum.RequiresNeck=true;hum.HipHeight=data.hip_height;hum:Add(object("Animator","Animator"))
    model.Attrs={HHC_SourceSHA256=data.original_sha256,HHC_SourceFileSHA256=data.skin_sha256,HHC_SkinSourceSHA256=data.skin_sha256,HHC_JointsSHA256=data.joints_sha256,HHC_SkinContractSHA256=data.contract_sha256,HHC_SkinInspectionSHA256=fit.inspection_sha256,
        HHC_RigOrigin=data.rig_origin,HHC_InferredManualCandidate=data.original_bones_claimed==false,HHC_OriginalBonesClaimed=data.original_bones_claimed,HHC_OriginalUVPreserved=true,HHC_OriginalTextureBytesPreserved=true,
        HHC_SkinRuntimeSchema=2,HHC_SkinRetargetRequired=true,HHC_SkinRuntimeValidated=false,HHC_PendingAnimationQA=true,HHC_AnimationValidated=false,HHC_RigReady=false,HHC_SkinRootBindSize=root.Size,HHC_SkinBindScale=1,HHC_SkinManifest="MANIFEST"}
    local manifest={schema=2,name=data.name,skin_sha256=data.skin_sha256,joints_sha256=data.joints_sha256,contract_sha256=data.contract_sha256,inspection_sha256=fit.inspection_sha256,
        unique_bones=#data.bones,bone_instances=#snap.bones,mesh_instances=#snap.meshes,bones={},meshes={}}
    for _,entry in data.bones do table.insert(manifest.bones,{name=entry.name,parent=entry.parent,part=entry.proxy_part,principal=entry.principal}) end
    for _,entry in snap.meshes do table.insert(manifest.meshes,{path=entry.path,mesh_id=entry.mesh_id}) end
    local maps={DATA=data,SNAP=snap,FIT=fit,MANIFEST=manifest}
    if data.binding then
        model.Attrs.HHC_SkinBindingSchema=1;manifest.binding_schema=1;manifest.binding_host_path=data.binding.anchor_path
    end
    if data.expression then
        local face=nil;for _,mesh in skinMeshes do if mesh.Name=="FaceExpression" then face=mesh end end
        assert(face,"counterfactual expression fixture has no face")
        local headBone=skinBones.Head;local host=headBone.Parent
        while not host:IsA("BasePart") do host=host.Parent end
        for name,target in {HHC_ExpressionSkinBoneHost=host,HHC_ExpressionSkinHeadBone=headBone,HHC_ExpressionSkinRootWeld=face:FindFirstChild(data.binding and "CostumeSkinInternalWeld" or "CostumeSkinRootWeld")} do
            local value=face:Add(object("ObjectValue",name));value.Value=target
        end
        model.Attrs.HHC_OriginalSkinSHA256=data.expression.original_skin_sha256;model.Attrs.HHC_ExpressionManifestSHA256=data.expression.manifest_sha256
        model.Attrs.HHC_ExpressionValidationSHA256=data.expression.validation_sha256;model.Attrs.HHC_ExpressionInspectionSHA256=fit.inspection_sha256
        model.Attrs.HHC_ExpressionSkinRuntimeSchema=1;model.Attrs.HHC_ExpressionSkinValidated=false;model.Attrs.HHC_ExpressionRuntimeValidated=false
        if data.expression.original_triangles_only then
            model.Attrs.HHC_ExpressionOriginalTrianglesOnly=true
            model.Attrs.HHC_ExpressionFaceProvenanceSHA256=data.expression.face_provenance_sha256
            model.Attrs.HHC_ExpressionUVCompatibilitySHA256=data.expression.uv_compatibility_sha256
        end
        if data.expression.mouth_restoration_schema then
            model.Attrs.HHC_ExpressionMouthRestorationSchema=data.expression.mouth_restoration_schema
            model.Attrs.HHC_ExpressionMouthRestorationLedgerSHA256=data.expression.mouth_restoration_ledger_sha256
            model.Attrs.HHC_ExpressionMouthOriginalUnionSHA256=data.expression.original_union_sha256
            model.Attrs.HHC_ExpressionMouthChangedVertices=data.expression.mouth_changed_original_vertices
            model.Attrs.HHC_ExpressionMouthRuntimeContractSHA256=data.expression.mouth_runtime_contract_sha256
            model.Attrs.HHC_ExpressionMouthPNExceptionKind=data.expression.validation_kind
        end
        face.Attrs.HHC_ExpressionMeshValidated=false;face.Attrs.HHC_ExpressionSkinValidated=false;face.Attrs.HHC_SkinSourceSHA256=data.skin_sha256;face.Attrs.HHC_ExpressionSkinMeshId=face.MeshId
    end
    local http={JSONDecode=function(_,value) assert(maps[value],"missing test JSON");return maps[value] end,JSONEncode=function(_,value) return value end}
    local env=setmetatable({game={GetService=function(_,name) return name=="ServerStorage" and storage or name=="RunService" and {IsRunning=function() return false end} or http end},CFrame=CF,Vector3=Vec,
        typeof=function(value) return type(value)=="table" and value._tag or type(value) end,Enum={HumanoidRigType={R15="R15"}}},{__index=getfenv()})
    return {Source=source,Model=model,Root=root,Skin=skin,Parts=parts,Bones=skinBones,Meshes=skinMeshes,SourceMeshes=sourceMeshes,Motors=motors,Manifest=manifest,Environment=env}
end
for _,fixture in ACTUAL_CASES do
    local function run(edit)
        local c=makeCase(fixture.data,fixture.snap,fixture.fit)
        if edit then edit(c) end
        local chunk=assert(loadstring(VERIFY_SOURCE));setfenv(chunk,c.Environment)
        return pcall(chunk)
    end
    local ok,result=run();check(ok and result.passed and result.unique_bones==#fixture.data.bones,"actual "..fixture.data.name.." positive: "..tostring(result))
    local failures={
        function(c) c.Model.Attrs.HHC_RigReady=true end,
        function(c) c.Model.Attrs.HHC_SkinRuntimeValidated=true end,
        function(c) c.Model.Attrs.HHC_JointsSHA256=string.rep("f",64) end,
        function(c) c.Root.Size=Vec.new(3,2,1) end,
        function(c) c.Parts.Head.CFrame=c.Parts.Head.CFrame*CF.new(.1,0,0) end,
        function(c) c.Parts.Head.Attrs.HHC_ProxyBindSize=nil end,
        function(c) c.Motors.Neck.Enabled=false end,
        function(c) c.Motors.Neck.Part1=c.Parts.UpperTorso end,
        function(c) c.Motors.Neck.C0=CF.new(.5,0,0) end,
        function(c) c.Bones.Head.CFrame=c.Bones.Head.CFrame*CF.new(.1,0,0) end,
        function(c) c.Bones.Head.Transform=rotateX(.1) end,
        function(c) c.Bones.Head.Attrs.HHC_SkinParentBone="Wrong" end,
        function(c) c.Bones.Head.Attrs.HHC_SkinPrincipal=false end,
        function(c) c.Bones.Head.Attrs.HHC_SkinBindRoot=CF.new() end,
        function(c) removeObject(c.Bones.Head) end,
        function(c) for _,mesh in c.Meshes do mesh.TextureID="rbxassetid://1";break end end,
        function(c) for _,mesh in c.Meshes do mesh.MeshId="rbxassetid://1";break end end,
        function(c) for _,mesh in c.Meshes do mesh.CanCollide=true;break end end,
        function(c) for _,mesh in c.Meshes do mesh:FindFirstChild(fixture.data.binding and "CostumeSkinInternalWeld" or "CostumeSkinRootWeld").Part0=c.Parts.Head;break end end,
        function(c) c.Skin:Add(object("LocalScript","Untrusted")) end,
        function(c) c.Manifest.bones[1].part="Wrong" end,
        function(c) c.Manifest.meshes[1].mesh_id="rbxassetid://1" end,
        function(c) for _,mesh in c.SourceMeshes do mesh.TextureID="rbxassetid://1";break end end,
    }
    if #fixture.data.bones==23 then table.insert(failures,function(c) removeObject(c.Bones.Aux_root) end) end
    if fixture.data.expression then
        local function face(c) return c.Skin:FindFirstChild("FaceExpression") end
        local extra={
            function(c) c.Model.Attrs.HHC_OriginalSkinSHA256=string.rep("f",64) end,
            function(c) c.Model.Attrs.HHC_ExpressionInspectionSHA256=nil end,
            function(c) c.Model.Attrs.HHC_ExpressionSkinValidated=true end,
            function(c) face(c).Attrs.HHC_ExpressionMeshValidated=true end,
            function(c) face(c).Attrs.HHC_ExpressionSkinMeshId="rbxassetid://1" end,
            function(c) face(c):FindFirstChild("HHC_ExpressionSkinBoneHost").Value=c.Root end,
            function(c) face(c):FindFirstChild("HHC_ExpressionSkinHeadBone").Value=c.Bones.UpperTorso end,
            function(c) face(c):FindFirstChild("HHC_ExpressionSkinRootWeld").Value=nil end,
            function(c) face(c):FindFirstChild(fixture.data.binding and "CostumeSkinInternalWeld" or "CostumeSkinRootWeld").Part0=c.Parts.Head end,
            function(c) local w=c.Parts.Head:Add(object("WeldConstraint","DuplicateFaceTransform"));w.Part0=c.Parts.Head;w.Part1=face(c) end,
            function(c) face(c):Add(object("SurfaceAppearance","WrongAtlas")) end,
        }
        for _,edit in extra do table.insert(failures,edit) end
        if fixture.data.expression.original_triangles_only then
            table.insert(failures,function(c) c.Model.Attrs.HHC_ExpressionOriginalTrianglesOnly=nil end)
            table.insert(failures,function(c) c.Model.Attrs.HHC_ExpressionFaceProvenanceSHA256=string.rep("f",64) end)
            table.insert(failures,function(c) c.Model.Attrs.HHC_ExpressionUVCompatibilitySHA256=nil end)
        end
        if fixture.data.expression.mouth_restoration_schema then
            table.insert(failures,function(c) c.Model.Attrs.HHC_ExpressionMouthRestorationSchema=0 end)
            table.insert(failures,function(c) c.Model.Attrs.HHC_ExpressionMouthRestorationLedgerSHA256=string.rep("f",64) end)
            table.insert(failures,function(c) c.Model.Attrs.HHC_ExpressionMouthOriginalUnionSHA256=nil end)
            table.insert(failures,function(c) c.Model.Attrs.HHC_ExpressionMouthChangedVertices=75 end)
            table.insert(failures,function(c) c.Model.Attrs.HHC_ExpressionMouthRuntimeContractSHA256=string.rep("f",64) end)
            table.insert(failures,function(c) c.Model.Attrs.HHC_ExpressionMouthPNExceptionKind="original_triangle_union_v1" end)
        end
    end
    if fixture.data.binding then
        local function anchor(c) return c.Skin:FindFirstChild("HHC_SkinBindingHost").Value end
        local function boundPart(c)
            local face=c.Skin:FindFirstChild("FaceExpression");if face then return face end
            for _,part in c.Meshes do if part~=anchor(c) then return part end end
            error("fixture has no non-anchor mesh")
        end
        local function internal(c) return boundPart(c):FindFirstChild("CostumeSkinInternalWeld") end
        local extra={
            function(c) c.Model.Attrs.HHC_SkinBindingSchema=nil end,
            function(c) c.Skin:FindFirstChild("HHC_SkinBindingHost").Value=c.Root end,
            function(c) anchor(c):FindFirstChild("CostumeSkinRootWeld").Part0=c.Parts.Head end,
            function(c) anchor(c):FindFirstChild("CostumeSkinRootWeld").Enabled=false end,
            function(c) internal(c).Part0=c.Root end,
            function(c) internal(c).Part1=c.Parts.Head end,
            function(c) internal(c).Enabled=false end,
            function(c) internal(c).Name="WrongInternalWeld" end,
            function(c) internal(c).C0=internal(c).C0*CF.new(.1,0,0) end,
            function(c) internal(c).C1=rotateX(.2) end,
            function(c) removeObject(internal(c)) end,
            function(c) local old=internal(c);local extra=old.Parent:Add(object("Weld",old.Name));extra.Part0=old.Part0;extra.Part1=old.Part1;extra.C0=old.C0;extra.C1=old.C1 end,
            function(c) local part=boundPart(c);local w=part:Add(object("WeldConstraint","CostumeSkinRootWeld"));w.Part0=c.Root;w.Part1=part end,
            function(c) c.Manifest.binding_schema=0 end,
            function(c) c.Manifest.binding_host_path={"ForeignHost"} end,
            function(c) local part=boundPart(c);local w=c.Root:Add(object("WeldConstraint","OutsideSkinDuplicate"));w.Part0=c.Root;w.Part1=part end,
            function(c) local part=boundPart(c);local w=c.Root:Add(object("Weld","OutsideSkinDuplicate"));w.Part0=c.Root;w.Part1=part;w.C0=CF.new();w.C1=CF.new() end,
        }
        for _,edit in extra do table.insert(failures,edit) end
    end
    for i,edit in failures do local passed=run(edit);check(not passed,"actual "..fixture.data.name.." rejects mutation "..i) end
end
print("SKIN_VERIFY_SUMMARY checks="..checks.." failed="..failed.." Studio/API calls=0")
assert(failed==0,"offline schema2 matcher failures")
