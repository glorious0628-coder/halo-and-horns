"""Run the actual costume preparation function against native/custom physics profiles.

Requires an installed official Luau CLI; no Studio/API calls or simulated physics claims.
The engine still needs an ON/OFF standing, walking and jump playtest.
"""
from pathlib import Path
import argparse
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
HARNESS = r'''
local checks = 0
local function check(condition, message)
    assert(condition, message)
    checks += 1
end
local function node(kind, name, props, children, attrs)
    local value = props or {}
    value.ClassName, value.Name = kind, name
    value.Children, value.Attributes = children or {}, attrs or {}
    function value:IsA(want)
        return want == kind or (want == "BasePart" and (kind == "Part" or kind == "MeshPart"))
            or (want == "LuaSourceContainer" and (kind == "LocalScript" or kind == "Script" or kind == "ModuleScript"))
    end
    function value:GetAttribute(key) return self.Attributes[key] end
    function value:GetChildren()
        local out = {}
        for _, child in self.Children do if not child.Destroyed then out[#out+1] = child end end
        return out
    end
    function value:GetDescendants()
        local out = {}
        for _, child in self:GetChildren() do
            out[#out+1] = child
            for _, nested in child:GetDescendants() do out[#out+1] = nested end
        end
        return out
    end
    function value:FindFirstChild(childName)
        for _, child in self:GetChildren() do if child.Name == childName then return child end end
    end
    function value:FindFirstChildOfClass(childKind)
        for _, child in self:GetChildren() do if child.ClassName == childKind then return child end end
    end
    function value:Destroy() self.Destroyed = true end
    function value:Clone()
        local copy = {}
        for key,item in self do
            if type(item) ~= "function" and key ~= "Children" and key ~= "Attributes" then copy[key] = item end
        end
        self.LastClone = node(kind,self.Name,copy,{},table.clone(self.Attributes))
        return self.LastClone
    end
    return value
end
local rigTypes = { R15={Name="R15"}, R6={Name="R6"} }
local function fixture(custom, rootCollide, rigName, cached, missingController)
    local controller = node("LocalScript", rigName, {Disabled=true}, {}, {
        CaptureSourceSHA256=string.rep("a",64), CaptureRigType=rigName, CaptureOrigin="RobloxDefaultCharacter",
    })
    local controllers = node("Folder", "CostumeAnimationControllers", {}, {controller})
    local storage = node("Folder", "ServerStorage", {}, missingController and {} or {controllers})
    local starterScript = node("LocalScript", "GameOwnedCamera", {Disabled=false})
    local starter = { StarterCharacterScripts=node("Folder","StarterCharacterScripts",{}, {starterScript}) }
    local root = node("Part","HumanoidRootPart", {
        Anchored=true,CanCollide=rootCollide,CanTouch=true,CanQuery=true,Massless=false,CustomPhysicalProperties="native-root",
    })
    local joint = node(custom and "Motor6D" or "AnimationConstraint","Root",{
        Enabled=true,IsKinematic=false,MaxForce=12000,Transform="native-transform",Attachment0="native-attachment0",Attachment1="native-attachment1",
    })
    local torso = node("MeshPart","LowerTorso", {Anchored=false,CanCollide=true,Massless=false,CustomPhysicalProperties="native-torso"}, {joint})
    local foot = node("MeshPart","LeftFoot", {Anchored=false,CanCollide=false,Massless=false,CustomPhysicalProperties="native-foot"})
    local accessory = node("Part","Handle", {Anchored=false,CanCollide=false,Massless=true})
    local oldScript = node("LocalScript","Animate",{Disabled=false})
    local injectedScript = node("ModuleScript","UntrustedModule",{}, {node("Script","NestedScript")})
    local humanoid = node("Humanoid","Humanoid", {RigType=rigTypes[rigName],PlatformStand=true,Health=38,MaxHealth=100,HipHeight=2.2248})
    local character = node("Model","Owner",{}, {root,torso,foot,accessory,oldScript,injectedScript,humanoid}, {
        HHC_CostumeId=custom and "Costume_HaloWarriorM" or nil,HHC_OriginalRestore=not custom,
    })
    local player, states = {}, {}
    states[player] = {Animations={}}
    if cached then states[player].Animations[rigTypes[rigName]] = controller end
    local created = {}
    local instance = {new=function(kind)
        local object = node(kind,kind); created[#created+1] = object; return object
    end}
    local fn = assert(loadstring("local states, ServerStorage, StarterPlayer, Instance, ATTR = ...\n" .. PREPARE_SOURCE .. "\nreturn prepareCharacter"))
    local prepare = fn(states,storage,starter,instance,{Costume="HHC_CostumeId"})
    return {
        Prepare=function() return prepare(player,character) end, Character=character, Root=root, Torso=torso,
        Foot=foot, Accessory=accessory, Joint=joint, Humanoid=humanoid, OldScript=oldScript,
        Untrusted=injectedScript, Controller=controller, StarterScript=starterScript, Created=created,
    }
end

-- Preserve both native collision profiles (old Motor6D/R6 and current AnimationConstraint R15).
-- Costume root behavior remains exactly the verified custom-template behavior.
for _, spec in {
    {false,true,"R15",true}, {false,true,"R15",false}, {false,false,"R15",true},
    {false,false,"R6",true}, {false,true,"R6",false}, {true,true,"R15",true}, {true,false,"R15",false},
} do
    local f = fixture(spec[1],spec[2],spec[3],spec[4],false)
    check(f.Prepare(), "valid controller/profile could not prepare")
    check(f.Root.CanCollide == (not spec[1] and spec[2]), "native root collision was overridden")
    check(f.Torso.CanCollide and not f.Foot.CanCollide and not f.Accessory.CanCollide, "native body/accessory collision changed")
    check(not f.Root.Massless and not f.Torso.Massless and f.Accessory.Massless, "body/accessory mass profile changed")
    check(f.Root.CanTouch and f.Root.CanQuery and f.Root.CustomPhysicalProperties=="native-root"
        and f.Torso.CustomPhysicalProperties=="native-torso" and f.Foot.CustomPhysicalProperties=="native-foot",
        "touch/query/material physics profile changed")
    check(f.Joint.Enabled and f.Joint.IsKinematic==false and f.Joint.MaxForce==12000
        and f.Joint.Transform=="native-transform" and f.Joint.Attachment0=="native-attachment0"
        and f.Joint.Attachment1=="native-attachment1", "engine joint/attachments changed")
    check(f.Humanoid.Health==38 and f.Humanoid.MaxHealth==100 and f.Humanoid.HipHeight==2.2248,
        "preparation reset HP or standing height")
    check(not f.Root.Anchored and not f.Humanoid.PlatformStand and f.Character.PrimaryPart==f.Root,
        "character not prepared for player control")
    check(f.OldScript.Destroyed and f.Untrusted.Destroyed, "untrusted template scripts survived")
    check(f.Controller.LastClone.Parent==f.Character and f.Controller.LastClone.Name=="Animate"
        and f.Controller.LastClone.Disabled==false and f.Controller.Disabled==true, "trusted animate clone was not installed")
    check(f.StarterScript.LastClone.Parent==f.Character and not f.StarterScript.Destroyed,
        "game-owned StarterCharacterScript was lost")
    check(#f.Created==1 and f.Created[1].ClassName=="Animator" and f.Created[1].Parent==f.Humanoid,
        "server Animator not attached to restored Humanoid")
end
-- A missing verified animation controller refuses installation without changing the native rig.
do
    local f=fixture(false,true,"R15",false,true)
    check(not f.Prepare(), "missing controller accepted")
    check(f.Root.CanCollide and f.Root.Anchored and not f.OldScript.Destroyed
        and not f.Untrusted.Destroyed and #f.Created==0, "refused preparation modified native avatar")
end
print("COSTUME_PHYSICS_OFFLINE_OK checks=" .. checks .. " Studio/API calls=0")
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--luau', type=Path, default=ROOT / 'build/luau_cli_0_741/luau.exe')
    args = parser.parse_args()
    if not args.luau.is_file():
        parser.error('Pass --luau with an installed official Luau CLI; this test never downloads tools.')
    source = (ROOT / 'src/ServerScriptService/CostumeService.luau').read_text(encoding='utf-8')
    # Exercise the current source function, rather than a rewritten copy of the implementation.
    source = source[source.index('local function clone('):source.index('local function captureOriginal(')]
    out = ROOT / 'build/costume_physics_offline_test.luau'
    out.parent.mkdir(exist_ok=True)
    out.write_text('local PREPARE_SOURCE = ' + json.dumps(source, ensure_ascii=False) + '\n' + HARNESS, encoding='utf-8')
    result = subprocess.run([str(args.luau.resolve()), str(out)], cwd=ROOT, capture_output=True,
                            text=True, encoding='utf-8', errors='replace')
    print(result.stdout, end='')
    print(result.stderr, end='')
    return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
