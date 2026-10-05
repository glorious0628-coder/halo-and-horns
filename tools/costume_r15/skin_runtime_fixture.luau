-- RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it errors immediately if run.
error("RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.")
-- Offline engine doubles: no Studio, network, persistence or actual promotion.
local checks,failed=0,0
local function check(value,label) checks+=1;if not value then failed+=1;print("FAIL "..label) end end
local deferred={}
local taskMock={defer=function(callback) table.insert(deferred,callback) end}
local function flush() local pending=deferred;deferred={};for _,callback in pending do callback() end end
local function signal()
    local listeners={};local result={}
    function result:Connect(callback)
        local conn={Connected=true};listeners[conn]=callback
        function conn:Disconnect() self.Connected=false;listeners[self]=nil end
        return conn
    end
    function result:Fire(...) for conn,callback in listeners do if conn.Connected then callback(...) end end end
    function result:Count() local count=0;for _ in listeners do count+=1 end;return count end
    return result
end
local Vec={};local VM={}
VM.__index=function(v,key) if key=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end;return Vec[key] end
VM.__add=function(a,b) return Vec.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
VM.__sub=function(a,b) return Vec.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
VM.__mul=function(a,b) if type(a)=="number" then a,b=b,a end;return Vec.new(a.X*b,a.Y*b,a.Z*b) end
function Vec.new(x,y,z) return setmetatable({_tag="Vector3",X=x or 0,Y=y or 0,Z=z or 0},VM) end
local CF={};local CM={};local ID={1,0,0,0,1,0,0,0,1}
local function rotate(r,v) return Vec.new(r[1]*v.X+r[2]*v.Y+r[3]*v.Z,r[4]*v.X+r[5]*v.Y+r[6]*v.Z,r[7]*v.X+r[8]*v.Y+r[9]*v.Z) end
function CF.new(...)
    local args={...};local p=type(args[1])=="table" and args[1] or Vec.new(args[1],args[2],args[3]);local r={}
    for i=1,9 do r[i]=args[i+3] or ID[i] end
    return setmetatable({_tag="CFrame",P=p,R=r},CM)
end
CM.__index=function(cf,key) if key=="Position" then return cf.P elseif key=="Rotation" then return CF.new(0,0,0,table.unpack(cf.R)) end;return CF[key] end
CM.__mul=function(a,b)
    if b._tag=="Vector3" then return a.P+rotate(a.R,b) end
    local r={};for i=1,3 do for j=1,3 do local value=0;for k=1,3 do value+=a.R[(i-1)*3+k]*b.R[(k-1)*3+j] end;r[(i-1)*3+j]=value end end
    local p=a.P+rotate(a.R,b.P);return CF.new(p.X,p.Y,p.Z,table.unpack(r))
end
function CF:GetComponents() return self.P.X,self.P.Y,self.P.Z,table.unpack(self.R) end
function CF:Inverse() local r={};for i=1,3 do for j=1,3 do r[(i-1)*3+j]=self.R[(j-1)*3+i] end end;local p=rotate(r,self.P*-1);return CF.new(p.X,p.Y,p.Z,table.unpack(r)) end
function CF:ToObjectSpace(other) return self:Inverse()*other end
local function scaleCF(cf,q) return CF.new(cf.Position*q)*cf.Rotation end
local function rotateX(a) return CF.new(0,0,0,1,0,0,0,math.cos(a),-math.sin(a),0,math.sin(a),math.cos(a)) end
local function rotateY(a) return CF.new(0,0,0,math.cos(a),0,math.sin(a),0,1,0,-math.sin(a),0,math.cos(a)) end
local function cfError(a,b) local aa,bb={a:GetComponents()},{b:GetComponents()};local e=0;for i=1,12 do e=math.max(e,math.abs(aa[i]-bb[i])) end;return e end
local Obj={};local OM={}
OM.__index=function(self,key)
    if key=="WorldCFrame" or key=="TransformedWorldCFrame" then
        local parent=self.Parent;local base=parent:IsA("Bone") and parent[key] or parent.CFrame
        return base*self.CFrame*(key=="TransformedWorldCFrame" and self.Transform or CF.new())
    end
    return Obj[key]
end
local function object(class,name)
    return setmetatable({ClassName=class,Name=name,Children={},Attrs={},Parent=nil,AttributeChanged=signal(),DescendantAdded=signal(),DescendantRemoving=signal(),AncestryChanged=signal(),Size=Vec.new(1,1,1),CFrame=CF.new(),Transform=CF.new(),Anchored=false,CanCollide=false,Massless=true,Transparency=1,Enabled=true},OM)
end
function Obj:IsA(class) return self.ClassName==class or (class=="BasePart" and (self.ClassName=="Part" or self.ClassName=="MeshPart")) or (class=="LuaSourceContainer" and self.ClassName=="LocalScript") end
function Obj:GetAttribute(name) return self.Attrs[name] end
function Obj:SetAttribute(name,value) self.Attrs[name]=value;self.AttributeChanged:Fire(name) end
function Obj:GetChildren() return self.Children end
function Obj:GetDescendants() local result={};local function visit(item) for _,child in item.Children do table.insert(result,child);visit(child) end end;visit(self);return result end
function Obj:FindFirstChild(name) for _,child in self.Children do if child.Name==name then return child end end;return nil end
function Obj:FindFirstChildOfClass(class) for _,child in self.Children do if child:IsA(class) then return child end end;return nil end
function Obj:IsDescendantOf(ancestor) local current=self.Parent;while current do if current==ancestor then return true end;current=current.Parent end;return false end
function Obj:GetScale() return 1 end -- deliberately stale to test non-replicated Scale.
function Obj:Add(child) child.Parent=self;table.insert(self.Children,child);self.DescendantAdded:Fire(child);return child end
local jsonMap={}
local http={GenerateGUID=function() return "offline-only" end,JSONDecode=function(_,value) if not jsonMap[value] then error("invalid fixture JSON") end;return jsonMap[value] end}
local players={PlayerAdded=signal(),PlayerRemoving=signal(),List={}}
function players:GetPlayers() return self.List end
local render={}
local run={IsClient=function() return true end,IsRunning=function() return true end,BindToRenderStep=function(_,name,priority,callback) render[name]={Priority=priority,Callback=callback} end,UnbindFromRenderStep=function(_,name) render[name]=nil end}
local function frame() flush();for _,binding in render do binding.Callback(0.26) end;flush() end
local world=object("Model","Workspace")
local function newPlayer(id) local p={UserId=id,Character=nil,CharacterAdded=signal(),CharacterRemoving=signal()};table.insert(players.List,p);return p end
local function swap(player,character) local old=player.Character;if old then player.CharacterRemoving:Fire(old) end;player.Character=character;if character then player.CharacterAdded:Fire(character) end;flush() end
local function makeCharacter(fixture,meshCount)
    local model=world:Add(object("Model",fixture.name));local root=model:Add(object("Part","HumanoidRootPart"));root.Size=Vec.new(2,2,1);root.Attrs.HHC_ProxyBindRoot=CF.new()
    local skin=model:Add(object("Model","CostumeSkin"));local host=skin:Add(object("Part","RootPart"));host.Attrs.HHC_SkinHostBindRoot=CF.new()
    local hum=model:Add(object("Humanoid","Humanoid"));hum.Health=100;hum.RigType="R15"
    local proxies={HumanoidRootPart=root};local binds={};local bones={};local definitions={};local principal=0
    for i,entry in fixture.bones do if entry.principal then
        principal+=1;local part=model:Add(object("Part",entry.name));part.CFrame=CF.new(i*.09,i*.11,i*.05);part.Attrs.HHC_ProxyBindRoot=part.CFrame;part.Attrs.HHC_ProxyBindSize=part.Size;proxies[entry.name]=part
    end end
    for name,edge in FIXTURE_EDGES do local motor=model:Add(object("Motor6D",name));motor.Part0=proxies[edge[1]];motor.Part1=proxies[edge[2]] end
    local remaining=table.clone(fixture.bones)
    while #remaining>0 do
        local progressed=false
        for i=#remaining,1,-1 do local entry=remaining[i];if not entry.parent or bones[entry.parent] then
            local bone=object("Bone",entry.name);local bind=CF.new(table.unpack(entry.world));binds[entry.name]=bind
            local parent=entry.parent and bones[entry.parent] or host;local parentBind=entry.parent and binds[entry.parent] or CF.new()
            bone.CFrame=parentBind:Inverse()*bind;parent:Add(bone);bones[entry.name]=bone
            bone.Attrs={HHC_SkinBonePart=entry.part,HHC_SkinBindRoot=bind,HHC_SkinBindLocal=bone.CFrame,HHC_SkinParentBone=entry.parent or "",HHC_SkinPrincipal=entry.principal,HHC_SkinSourceSHA256=string.rep("a",64)}
            table.insert(definitions,{name=entry.name,parent=entry.parent,part=entry.part,principal=entry.principal});table.remove(remaining,i);progressed=true
        end end
        assert(progressed,"fixture hierarchy cyclic")
    end
    local meshManifest={}
    for i=1,(meshCount or 2) do local mesh=skin:Add(object("MeshPart","Surface"..i));mesh.MeshId="rbxassetid://"..(100+i);table.insert(meshManifest,{path={mesh.Name},mesh_id=mesh.MeshId}) end
    local token=fixture.name.."_"..tostring(meshCount or 2)
    jsonMap[token]={schema=2,name=fixture.name,unique_bones=#fixture.bones,bone_instances=#fixture.bones,mesh_instances=meshCount or 2,bones=definitions,meshes=meshManifest,skin_sha256=string.rep("a",64),joints_sha256=string.rep("a",64),contract_sha256=string.rep("a",64),inspection_sha256=string.rep("a",64)}
    model.Attrs={HHC_CostumeId=fixture.name,HHC_SkinRuntimeSchema=2,HHC_SkinRetargetRequired=true,HHC_SkinRuntimeValidated=true,HHC_RigReady=true,HHC_AnimationValidated=true,HHC_SkinSourceSHA256=string.rep("a",64),HHC_SourceSHA256=string.rep("a",64),HHC_JointsSHA256=string.rep("a",64),HHC_SkinContractSHA256=string.rep("a",64),HHC_SkinInspectionSHA256=string.rep("a",64),HHC_SkinBindScale=1,HHC_SkinRootBindSize=root.Size,HHC_SkinManifest=token,HHC_RigOrigin=#fixture.bones==15 and "inferred_manual_candidate" or "preserved_source_skin_proxy_candidate",HHC_OriginalBonesClaimed=#fixture.bones~=15}
    return {Model=model,Root=root,Host=host,Humanoid=hum,Proxies=proxies,Bones=bones,Binds=binds,Definitions=definitions}
end
local function pose(character,q,partial)
    local global=CF.new(40,8,-70)*rotateY(.63);character.Root.CFrame=global;character.Root.Size=character.Model.Attrs.HHC_SkinRootBindSize*q;character.Host.CFrame=global
    for _,part in character.Proxies do if part~=character.Root then part.Size=part.Attrs.HHC_ProxyBindSize*q;part.CFrame=global*scaleCF(part.Attrs.HHC_ProxyBindRoot,q)*rotateX(.45) end end
    for name,bone in character.Bones do if not partial or name~=partial then bone.CFrame=scaleCF(bone.Attrs.HHC_SkinBindLocal,q) end end
end
local function checkPose(character,q,label)
    for _,entry in character.Definitions do local bone=character.Bones[entry.name];local part=character.Proxies[entry.part]
        local expected=part.CFrame*scaleCF(part.Attrs.HHC_ProxyBindRoot,q):Inverse()*scaleCF(character.Binds[entry.name],q)
        -- Source Tripo matrices contain float rounding and are unitized rather
        -- than invented as perfect rotations. Allow the same 1e-4 imported
        -- CFrame precision used by the actual import validator.
        check(cfError(bone.TransformedWorldCFrame,expected)<1e-4,label.." "..entry.name)
    end
end
local environment=setmetatable({game={GetService=function(_,name) return name=="Players" and players or name=="RunService" and run or http end},task=taskMock,CFrame=CF,Vector3=Vec,typeof=function(value) return type(value)=="table" and value._tag or type(value) end,Enum={HumanoidRigType={R15="R15"},RenderPriority={Character={Value=300}}}},{__index=getfenv()})
local chunk=assert(loadstring(CLIENT_MODULE_SOURCE));setfenv(chunk,environment);local module=chunk()
local p1,p2=newPlayer(1),newPlayer(2);local manual,paid=makeCharacter(MANUAL_FIXTURE),makeCharacter(PAID_FIXTURE)
p1.Character=manual.Model;p2.Character=paid.Model;module.Init({});module.Start();flush();frame()
check(module.GetDebugSnapshot().active==2,"local and other player bind")
for _,binding in render do check(binding.Priority==301,"post Animator/Fx render priority") end
for _,q in {.8,1,1.3,2.2,3} do pose(manual,q);pose(paid,q);frame();checkPose(manual,q,"manual scaled");checkPose(paid,q,"paid aux scaled") end
local before=module.GetDebugSnapshot().frames;pose(manual,1.4,"LeftLowerArm");frame();check(module.GetDebugSnapshot().frames==before+1,"partial scale skips only incomplete character")
pose(manual,1.4);frame();checkPose(manual,1.4,"scale replication completes")
before=module.GetDebugSnapshot().frames;manual.Root.Size=Vec.new(5,2,1);frame();check(module.GetDebugSnapshot().frames==before+1,"nonuniform root size is refused")
pose(manual,1.2);frame();checkPose(manual,1.2,"resumes valid uniform scale")
local p3=newPlayer(3);players.PlayerAdded:Fire(p3);local third=makeCharacter(PAID_FIXTURE,3);swap(p3,third.Model);pose(third,1.1);frame();check(module.GetDebugSnapshot().active==3,"late player plus 3 surfaces")
checkPose(third,1.1,"three surface 23 bones")
manual.Model:SetAttribute("HHC_CostumeId",nil);flush();frame();check(module.GetDebugSnapshot().active==2,"OFF unbind")
for _,bone in manual.Bones do check(cfError(bone.Transform,CF.new())<1e-9,"OFF owned pose cleared") end
local replacement=makeCharacter(MANUAL_FIXTURE);swap(p1,replacement.Model);pose(replacement,1.7);frame();check(module.GetDebugSnapshot().active==3,"ON rebind new character");checkPose(replacement,1.7,"ON fresh model")
paid.Humanoid.Health=0;frame();check(module.GetDebugSnapshot().active==2,"death unbind")
for _,bone in paid.Bones do check(cfError(bone.Transform,CF.new())<1e-9,"death owned pose cleared") end
local respawn=makeCharacter(PAID_FIXTURE);swap(p2,respawn.Model);pose(respawn,2);frame();check(module.GetDebugSnapshot().active==3,"death respawn rebind");checkPose(respawn,2,"respawn bone hierarchy")
respawn.Model:SetAttribute("HHC_RigReady",false);flush();frame();check(module.GetDebugSnapshot().active==2,"unvalidated Pending never binds")
respawn.Model:SetAttribute("HHC_RigReady",true);flush();frame();check(module.GetDebugSnapshot().active==3,"promotion rebind")
respawn.Model:SetAttribute("HHC_SkinRuntimeValidated",nil);flush();frame();check(module.GetDebugSnapshot().active==2,"missing runtime QA marker never binds")
respawn.Model:SetAttribute("HHC_SkinRuntimeValidated",false);flush();frame();check(module.GetDebugSnapshot().active==2,"runtime QA false never binds")
respawn.Model:SetAttribute("HHC_SkinRuntimeValidated",true);flush();frame();check(module.GetDebugSnapshot().active==3,"verified runtime marker rebinds")
respawn.Model:SetAttribute("HHC_SkinSourceSHA256",string.rep("b",64));flush();frame();check(module.GetDebugSnapshot().active==2,"hash/manifest disagreement refused")
respawn.Model:SetAttribute("HHC_SkinSourceSHA256",string.rep("a",64));flush();frame();check(module.GetDebugSnapshot().active==3,"known sealed metadata restores")
players.PlayerRemoving:Fire(p3);frame();check(module.GetDebugSnapshot().players==2 and module.GetDebugSnapshot().active==2,"leave removes player and record")
check(p3.CharacterAdded:Count()==0 and p3.CharacterRemoving:Count()==0,"leave disconnects player listeners")
module.Stop();check(module.GetDebugSnapshot().active==0 and module.GetDebugSnapshot().players==0,"Stop clears all records")
check(players.PlayerAdded:Count()==0 and players.PlayerRemoving:Count()==0,"Stop disconnects global listeners")
local renderCount=0;for _ in render do renderCount+=1 end;check(renderCount==0,"Stop unbinds render")
check(module.GetDebugSnapshot().faults==0,"actual module source runs without faults")
print("SKIN_RUNTIME_SUMMARY checks="..checks.." failed="..failed.." Studio/API calls=0")
assert(failed==0,"offline skin runtime failures")
