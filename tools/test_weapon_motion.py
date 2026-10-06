"""Exercise the actual Fx pose functions offline; never opens Studio or calls an API.

The small CFrame/Vector3 harness implements rigid transform math, not Roblox physics.
Native bind/size/grip data is a sanitized actual AJU capture. Optional costumes use
the tracked manifest's fourteen preserved and four inferred continuous-skin sources,
with the exact source hierarchy and checked invisible R15 proxy bind geometry.
These checks do not establish game-ready rigs, physical collision safety, or visual approval.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
FX = ROOT / "src/StarterPlayer/StarterPlayerScripts/Fx.luau"
VISUALS = ROOT / "src/ServerScriptService/CharacterVisuals.luau"
FIXTURE = ROOT / "tools/fixtures/archer_native_aju.json"
MANIFEST = ROOT / "art/models/costume/prepared/source_records.json"
SKIN_KINDS = {"preserved_original_skin_pending": 23, "skin_R15_proxy_pending_source": 15}
EXPECTED_COSTUMES = {f + c + g for f in ("Halo", "Horns", "Neutral")
                     for c in ("Warrior", "Mage", "Archer") for g in "MF"}


def lua(value):
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        # JSON unicode output is a valid Luau quoted literal here (no unsupported escapes).
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list):
        return "{" + ",".join(lua(x) for x in value) + "}"
    return "{" + ",".join("[" + lua(k) + "]=" + lua(v) for k, v in value.items()) + "}"


def source_function(source, name):
    start = source.index("function Feel." + name + "(")
    end = source.find("\nfunction Feel.", start + 1)
    if end < 0:
        raise ValueError("Function boundary missing: " + name)
    return source[start:end]


def local_function(source, name):
    start = source.index("local function " + name + "(")
    end = source.find("\nlocal function ", start + 1)
    if end < 0:
        raise ValueError("Local function boundary missing: " + name)
    return source[start:end]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def manifest_input(value):
    path = Path(value)
    if path.is_absolute() or ".." in path.parts:
        raise ValueError("Manifest input must be workspace-relative")
    resolved = (ROOT / path).resolve()
    resolved.relative_to(ROOT)
    return resolved


def proxy_fixture(data):
    """Check every rest FK edge against source bone hinges before testing poses."""
    import numpy as np
    from constraints import JOINTS, PRIMARY
    from skin_runtime import frame

    parts = {p["name"]: {"size": p["size"], "cf": p["center"] + [1,0,0,0,1,0,0,0,1],
                          "source_part": p["name"]} for p in data["proxy_parts"]}
    if len(data["proxy_parts"]) != 15 or set(parts) != set(PRIMARY):
        raise ValueError("Exactly fifteen unique proxy parts are required")
    parts["HumanoidRootPart"] = {"size": data["root"]["size"],
        "cf": data["root"]["center"] + [1,0,0,0,1,0,0,0,1]}
    frames = {}
    for name, p in parts.items():
        size = np.asarray(p["size"], dtype=float)
        if size.shape != (3,) or not np.isfinite(size).all() or min(size) <= 0:
            raise ValueError("Invalid proxy bounds: " + name)
        frames[name] = frame(p["cf"])
    edges = {(name, p0, p1) for name, p0, p1, _ in JOINTS}
    actual = {(j["name"], j["part0"], j["part1"]) for j in data["joints"]}
    if len(data["joints"]) != 15 or actual != edges:
        raise ValueError("The exact fifteen standard R15 edges are required")
    bones = {b["name"]: b for b in data["bones"]}
    reached, pending = {"HumanoidRootPart"}, list(data["joints"])
    maximum_fk = maximum_hinge = 0.0
    joints = {}
    while pending:
        reachable = [j for j in pending if j["part0"] in reached]
        if not reachable:
            raise ValueError("Disconnected/cyclic R15 proxy hierarchy")
        for j in reachable:
            p0, p1 = j["part0"], j["part1"]
            if p1 in reached:
                raise ValueError("Duplicate R15 proxy parent: " + p1)
            c0, c1 = frame(j["C0"]), frame(j["C1"])
            for bind in (c0, c1):
                r = bind[:3, :3]
                if not np.isfinite(bind).all() or not np.allclose(r.T @ r, np.eye(3), atol=1e-6) or np.linalg.det(r) < .99999:
                    raise ValueError("Nonrigid proxy joint frame: " + j["name"])
            fk = frames[p0] @ c0 @ np.linalg.inv(c1)
            fk_error = float(np.max(np.abs(fk - frames[p1])))
            world = np.asarray(j["world"], dtype=float)
            hinge_error = max(float(np.linalg.norm((frames[p0] @ c0)[:3, 3] - world)),
                              float(np.linalg.norm((frames[p1] @ c1)[:3, 3] - world)),
                              float(np.linalg.norm(world - bones[p1]["position"])))
            if fk_error > 1e-5 or hinge_error > 1e-5:
                raise ValueError("Source/proxy rest FK mismatch: " + j["name"])
            maximum_fk, maximum_hinge = max(maximum_fk, fk_error), max(maximum_hinge, hinge_error)
            joints[j["name"]] = {"p0": p0, "p1": p1, "c0": j["C0"], "c1": j["C1"]}
            reached.add(p1)
            pending.remove(j)
    if reached != set(parts):
        raise ValueError("An R15 proxy part was not reached by FK")
    arms = {}
    for side in ("Left", "Right"):
        a, b, c = (np.asarray(bones[side + part]["position"], dtype=float)
                   for part in ("UpperArm", "LowerArm", "Hand"))
        upper, lower = float(np.linalg.norm(b - a)), float(np.linalg.norm(c - b))
        if min(upper, lower) <= 0:
            raise ValueError("A source arm has zero actual bone length: " + side)
        inner, outer = abs(upper - lower), upper + lower
        old_goal = .8 * outer
        epsilon = min(upper, lower) * .001
        arms[side] = {"upper_length": upper, "lower_length": lower,
                      "lower_to_upper_ratio": lower / upper,
                      "inner_reach_radius": inner, "outer_reach_radius": outer,
                      "original_synthetic_test_goal_distance": old_goal,
                      "original_synthetic_test_goal_reachable": inner + epsilon <= old_goal <= outer - epsilon,
                      "corrected_synthetic_test_goal_distance": inner + (outer - inner) * .8}
    return {"name": data["name"].removeprefix("Costume_"), "parts": parts, "joints": joints}, {
        "proxy_parts": 15, "r15_joints": 15, "rest_fk_maximum_error": maximum_fk,
        "source_hinge_maximum_error": maximum_hinge, "source_bones": len(bones),
        "source_auxiliary_bones": len(bones) - 15, "actual_imported_binds_checked": False,
        "measured_arm_reach": arms,
        "motion_visual_quality_inferred_from_ik_pass": False}


def contract_rejection_guards(data):
    """Invalid source/proxy data must fail rather than become a passing fixture."""
    mutations = (
        lambda d: d["proxy_parts"][0]["size"].__setitem__(0, 0),
        lambda d: d["proxy_parts"][0].__setitem__("name", d["proxy_parts"][1]["name"]),
        lambda d: d["joints"].pop(),
        lambda d: d["joints"][0]["C0"].__setitem__(0, d["joints"][0]["C0"][0] + .02),
        lambda d: d["joints"][0]["C0"].__setitem__(3, 2),
        lambda d: d["joints"][0]["world"].__setitem__(0, d["joints"][0]["world"][0] + .02),
        lambda d: next(b for b in d["bones"] if b["name"] == "Head")["position"].__setitem__(0, 100),
    )
    for mutate in mutations:
        invalid = copy.deepcopy(data)
        mutate(invalid)
        try:
            proxy_fixture(invalid)
        except ValueError:
            continue
        raise AssertionError("Invalid source/proxy data was accepted")
    return len(mutations)


def costume_fixtures(manifest_path=MANIFEST):
    sys.path.insert(0, str(ROOT / "tools/costume_r15"))
    from skin_runtime_v2 import prepare

    records = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    packages = [p for p in records["packages"] if p["kind"] in SKIN_KINDS]
    counts = {kind: sum(p["kind"] == kind for p in packages) for kind in SKIN_KINDS}
    if counts != {"preserved_original_skin_pending": 14, "skin_R15_proxy_pending_source": 4}:
        raise ValueError("Manifest must contain exactly fourteen preserved and four inferred skins")
    out, states = [], []
    for record in packages:
        row = {"name": record["name"].removeprefix("Costume_").split("_")[0],
               "kind": record["kind"], "state": "offline_contract_failed",
               "studio_validated_by_this_tool": False, "game_ready_claimed_by_this_tool": False}
        try:
            # Only declared files are considered; other pending/expression/corrected
            # siblings are neither promoted nor silently substituted for benchmarks.
            paths = {}
            for saved in record["files"]:
                path = manifest_input(saved["path"])
                if not path.is_file() or sha(path) != saved["sha256"]:
                    raise ValueError("Recorded source SHA mismatch: " + saved["path"])
                paths[path.name] = path
            if record["kind"] == "preserved_original_skin_pending":
                contract = paths["package.json"]
                proxy_override = None
            elif "runtime_contract.json" in paths:
                contract = paths["runtime_contract.json"]
                proxy_override = None
            else:
                # The two manually bound archer packages predate a portable
                # runtime contract. Resolve only a plan tied to their recorded
                # landmark bytes and source frame; never pick a latest filename.
                contract = next(p for p in paths.values() if p.name.endswith(".skin.json"))
                sidecar = json.loads(contract.read_text(encoding="utf-8-sig"))
                landmark_sha = sha(paths["manual_landmarks.json"])
                candidates = []
                for plan in (ROOT / "build/manual_partition_candidates").glob("*/r15*/joints.json"):
                    saved_plan = json.loads(plan.read_text(encoding="utf-8-sig"))
                    provenance = saved_plan.get("manual_binding_provenance", {})
                    if (provenance.get("landmark_config_sha256") == landmark_sha
                            and provenance.get("source_sha256") == record["source_sha256"]
                            and saved_plan.get("source_frame_policy") == sidecar["source_frame_policy"]):
                        candidates.append(plan)
                if len(candidates) != 1:
                    raise ValueError("Require one exact source-frame proxy plan for recorded manual landmarks")
                proxy_override = candidates[0]
            data, _ = prepare(contract, "ServerStorage/OfflineOnly", proxy_override=proxy_override)
            name = data["name"].removeprefix("Costume_")
            row["name"] = name
            expected = SKIN_KINDS[record["kind"]]
            if name not in EXPECTED_COSTUMES or len(data["bones"]) != expected or data["original_bones_claimed"] != (expected == 23):
                raise ValueError("Recorded source kind/bone provenance disagrees")
            recorded_skin = next(p for p in paths.values() if p.name.endswith(".glb"))
            if data["skin_sha256"] != sha(recorded_skin) or data["original_sha256"] != record["source_sha256"]:
                raise ValueError("Loaded contract differs from the recorded skin/original source")
            fixture, metrics = proxy_fixture(data)
            metrics["invalid_contract_rejection_checks"] = contract_rejection_guards(data)
            out.append(fixture)
            row.update(state="offline_contract_verified", contract=str(contract.relative_to(ROOT)),
                       contract_sha256=sha(contract), skin_sha256=data["skin_sha256"],
                       proxy_plan_sha256=data["joints_sha256"],
                       source_sha256=data["original_sha256"], rig_origin=data["rig_origin"],
                       original_bones_claimed=data["original_bones_claimed"],
                       contract_metrics=metrics, visual_surfaces=len(data["meshes"]))
        except Exception as exc:
            row["reason"] = str(exc)
        states.append(row)
    names = [r["name"] for r in states]
    # Never report partial/duplicate coverage as an eighteen-costume audit.
    if len(set(names)) != 18 or set(names) != EXPECTED_COSTUMES:
        raise ValueError("Manifest failed to cover each of the eighteen exact costumes once: " + repr(names))
    return out, states


MATH = r'''
local checks, metrics = 0, {}
local function check(value, message)
    assert(value, message)
    checks += 1
end
local V, VM = {}, {}
VM.__index = function(v,k)
    if k == "Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
    if k == "Unit" then return v / v.Magnitude end
    return V[k]
end
VM.__add=function(a,b) return V.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
VM.__sub=function(a,b) return V.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
VM.__unm=function(a) return V.new(-a.X,-a.Y,-a.Z) end
VM.__mul=function(a,b)
    if type(a)=="number" then return V.new(a*b.X,a*b.Y,a*b.Z) end
    return V.new(a.X*b,a.Y*b,a.Z*b)
end
VM.__div=function(a,b) return V.new(a.X/b,a.Y/b,a.Z/b) end
function V.new(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0,__type="Vector3"},VM) end
function V:Dot(b) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
function V:Cross(b) return V.new(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X) end
function V:Lerp(b,t) return self+(b-self)*t end
V.zero,V.xAxis,V.yAxis,V.zAxis=V.new(),V.new(1,0,0),V.new(0,1,0),V.new(0,0,1)
local Vector3=V
local CF, CM = {}, {}
local identity={1,0,0,0,1,0,0,0,1}
local function frame(p,r) return setmetatable({P=p,R=r,__type="CFrame"},CM) end
local function rotate(r,v)
    return V.new(r[1]*v.X+r[2]*v.Y+r[3]*v.Z,r[4]*v.X+r[5]*v.Y+r[6]*v.Z,r[7]*v.X+r[8]*v.Y+r[9]*v.Z)
end
local function product(a,b)
    local out={}
    for i=0,2 do for j=0,2 do out[i*3+j+1]=a[i*3+1]*b[j+1]+a[i*3+2]*b[j+4]+a[i*3+3]*b[j+7] end end
    return out
end
CM.__index=function(cf,k)
    if k=="Position" then return cf.P elseif k=="Rotation" then return frame(V.zero,cf.R) end
    if k=="RightVector" then return V.new(cf.R[1],cf.R[4],cf.R[7]) end
    if k=="UpVector" then return V.new(cf.R[2],cf.R[5],cf.R[8]) end
    if k=="LookVector" then return -V.new(cf.R[3],cf.R[6],cf.R[9]) end
    return CF[k]
end
CM.__mul=function(a,b)
    if b.__type=="Vector3" then return a.P+rotate(a.R,b) end
    return frame(a.P+rotate(a.R,b.P),product(a.R,b.R))
end
function CF.new(...)
    local a={...}
    if #a==0 then return frame(V.zero,identity) end
    if type(a[1])=="table" then return frame(a[1],identity) end
    if #a==3 then return frame(V.new(a[1],a[2],a[3]),identity) end
    assert(#a==12,"CFrame.new requires 0/Vector3/3/12 arguments")
    local r={};for i=1,9 do r[i]=a[i+3] end
    return frame(V.new(a[1],a[2],a[3]),r)
end
function CF.fromAxisAngle(axis,t)
    axis=axis.Unit
    local x,y,z,c,s=axis.X,axis.Y,axis.Z,math.cos(t),math.sin(t)
    local d=1-c
    return frame(V.zero,{c+x*x*d,x*y*d-z*s,x*z*d+y*s,y*x*d+z*s,c+y*y*d,y*z*d-x*s,z*x*d-y*s,z*y*d+x*s,c+z*z*d})
end
function CF.Angles(x,y,z) return CF.fromAxisAngle(V.xAxis,x)*CF.fromAxisAngle(V.yAxis,y)*CF.fromAxisAngle(V.zAxis,z) end
function CF.lookAt(p,q,up)
    local look=(q-p).Unit
    local right=look:Cross(up or V.yAxis).Unit
    local fixedUp=right:Cross(look)
    return frame(p,{right.X,fixedUp.X,-look.X,right.Y,fixedUp.Y,-look.Y,right.Z,fixedUp.Z,-look.Z})
end
function CF:Inverse()
    local r=self.R
    local t={r[1],r[4],r[7],r[2],r[5],r[8],r[3],r[6],r[9]}
    return frame(-rotate(t,self.P),t)
end
function CF:VectorToWorldSpace(v) return rotate(self.R,v) end
function CF:PointToObjectSpace(v) return self:Inverse()*v end
function CF:ToObjectSpace(cf) return self:Inverse()*cf end
local function quaternion(r)
    local trace=r[1]+r[5]+r[9]
    if trace>0 then
        local s=math.sqrt(1+trace)*2
        return {(r[8]-r[6])/s,(r[3]-r[7])/s,(r[4]-r[2])/s,s/4}
    elseif r[1]>r[5] and r[1]>r[9] then
        local s=math.sqrt(1+r[1]-r[5]-r[9])*2
        return {s/4,(r[2]+r[4])/s,(r[3]+r[7])/s,(r[8]-r[6])/s}
    elseif r[5]>r[9] then
        local s=math.sqrt(1+r[5]-r[1]-r[9])*2
        return {(r[2]+r[4])/s,s/4,(r[6]+r[8])/s,(r[3]-r[7])/s}
    else
        local s=math.sqrt(1+r[9]-r[1]-r[5])*2
        return {(r[3]+r[7])/s,(r[6]+r[8])/s,s/4,(r[4]-r[2])/s}
    end
end
function CF:Lerp(b,t)
    local a,q=quaternion(self.R),quaternion(b.R)
    local d=0;for i=1,4 do d+=a[i]*q[i] end
    if d<0 then for i=1,4 do q[i]=-q[i] end;d=-d end
    local u,v=1-t,t
    if d<.9995 then local theta=math.acos(math.clamp(d,-1,1));u=math.sin((1-t)*theta)/math.sin(theta);v=math.sin(t*theta)/math.sin(theta) end
    local o,n={},0;for i=1,4 do o[i]=a[i]*u+q[i]*v;n+=o[i]*o[i] end
    n=math.sqrt(n);for i=1,4 do o[i]/=n end
    local x,y,z,w=o[1],o[2],o[3],o[4]
    return frame(self.P:Lerp(b.P,t),{1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w),2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w),2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)})
end
CF.identity=CF.new()
local CFrame=CF
local function typeof(v) return type(v)=="table" and v.__type or type(v) end
local Color3={fromRGB=function()return {}end,new=function()return {}end}
local function asNum(x,fallback) return type(x)=="number" and x==x and x or fallback end
local function asVec(x) return typeof(x)=="Vector3" and x or nil end
local function asStr(x,fallback) return type(x)=="string" and x or fallback end
local function near(a,b,epsilon) return (a-b).Magnitude<(epsilon or 1e-5) end
local function same(a,b) return near(a.Position,b.Position) and a.LookVector:Dot(b.LookVector)>.99999 and a.UpVector:Dot(b.UpVector)>.99999 end
local function node(kind,name,props)
    local n=props or {}
    n.__type,n.ClassName,n.Name,n.Children,n.Attributes="Instance",kind,name,{},{}
    n.Parent=true
    function n:IsA(k) return k==kind or (k=="BasePart" and kind=="Part") end
    function n:FindFirstChild(key,recurse)
        for _,c in self.Children do if c.Name==key and not c.Destroyed then return c end end
        if recurse then for _,c in self.Children do local found=c:FindFirstChild(key,true);if found then return found end end end
    end
    function n:FindFirstChildOfClass(k) for _,c in self.Children do if c:IsA(k) then return c end end end
    function n:GetAttribute(k) return self.Attributes[k] end
    function n:SetAttribute(k,v) self.Attributes[k]=v end
    function n:GetDescendants()
        local out={};for _,c in self.Children do table.insert(out,c);for _,d in c:GetDescendants() do table.insert(out,d) end end;return out
    end
    function n:Destroy() self.Parent=nil;self.Destroyed=true end
    function n:GetScale() return 1 end
    return n
end
local function child(parent,n) n.Parent=parent;table.insert(parent.Children,n);return n end
local Feel={Clips={},Chars={},Active={},ActiveCount=0,Actors={},Guarded={}}
local function warnThrottled(message) metrics.Warnings=(metrics.Warnings or 0)+1 end
local scheduled={}
local function later(seconds,callback) table.insert(scheduled,{Time=seconds,Callback=callback}) end
local listeners={}
local heartbeatListeners={}
local RunService={RenderStepped={},Heartbeat={}}
function RunService.RenderStepped:Connect(callback)
    local connection={Connected=true}
    function connection:Disconnect() self.Connected=false end
    connection.Callback=callback;table.insert(listeners,connection);return connection
end
function RunService.Heartbeat:Connect(callback)
    local connection={Connected=true,Callback=callback}
    function connection:Disconnect() self.Connected=false end
    table.insert(heartbeatListeners,connection);return connection
end
local function render() for _,conn in table.clone(listeners) do if conn.Connected then conn.Callback() end end end
local function heartbeat() for _,conn in table.clone(heartbeatListeners) do if conn.Connected then conn.Callback() end end end
local function delays() local pending=scheduled;scheduled={};for _,d in pending do d.Callback() end end
local Enum={HumanoidRigType={R15="R15"}}
local LocalPlayer=nil
local Players={ById={}}
function Players:GetPlayerByUserId(id) return self.ById[id] end
local Util={FindPart=function(c,a,b)return c:FindFirstChild(a) or c:FindFirstChild(b) end}
local function makePart(props) return node("Part",props.Name,props) end
local function factionColor() return {} end
local function addLight() end
local Config={Classes={Warrior={SwingInterval=1,Weapon="Sword"},Archer={SwingInterval=.5,Weapon="Bow"},Mage={SwingInterval=1.25,Weapon="Staff"}}}
Config.WeaponColor=function()return {}end
local WOOD_COLOR,DARK_METAL={},{}
Enum.Material={Wood="Wood",WoodPlanks="WoodPlanks",Metal="Metal",Neon="Neon",SmoothPlastic="SmoothPlastic",Glass="Glass"}
Enum.PartType={Ball="Ball"};Enum.SurfaceType={Smooth="Smooth"}
local ColorSequence={new=function(...)return {...}end}
local Instance={new=function(kind)
    local n=node(kind,"");n.Parent=nil
    return setmetatable(n,{__index=function(obj,key)
        if kind=="Attachment" and key=="CFrame" then return CFrame.new(rawget(obj,"Position") or Vector3.zero) end
        if kind=="Attachment" and key=="Position" then return rawget(obj,"CFrame").Position end
    end,__newindex=function(obj,key,value)
        if key=="Parent" and type(value)=="table" then table.insert(value.Children,obj) end
        rawset(obj,key,value)
    end})
end}
local function newPiece(name) return node("Model",name) end
local function sparkle()end
local function mount(model,parts,char,hand)
    model.HandFrames={};model.HandPart=hand
    for _,p in parts do model.HandFrames[p]=hand.CFrame:ToObjectSpace(p.CFrame);child(model,p) end
    child(char,model)
end
'''


TESTS = r'''
-- Check the rigid-math harness against known bases before exercising the real source.
check(near((CFrame.Angles(0,math.pi/2,0)*Vector3.new(0,0,-1)),Vector3.new(-1,0,0)),"CFrame Y basis")
local rotated=CFrame.new(2,3,4)*CFrame.Angles(.3,-.7,1.1)
check(same(rotated:Inverse()*rotated,CFrame.identity),"CFrame inverse")
check(same(CFrame.identity:Lerp(CFrame.Angles(0,math.pi/2,0),.5),CFrame.Angles(0,math.pi/4,0)),"CFrame quaternion interpolation")
Feel.compileClips()
Feel.bind=function()end -- no frame loop or Studio dependency in the offline harness
local function fixture(data,kind)
    local char=node("Model",data.name)
    local hum=child(char,node("Humanoid","Humanoid",{Health=100,RigType="R15"}))
    local parts={}
    for name,p in data.parts do
        parts[name]=child(char,node("Part",name,{CFrame=CFrame.new(table.unpack(p.cf or {0,0,0,1,0,0,0,1,0,0,0,1})),Size=Vector3.new(table.unpack(p.size or {1,1,1}))}))
        if p.source_part then parts[name].Attributes.HHC_SourcePart=p.source_part end
        if p.grip then
            local att=child(parts[name],node("Attachment",name=="LeftHand" and "LeftGripAttachment" or "RightGripAttachment",{CFrame=CFrame.new(table.unpack(p.grip))}))
            att.Position=att.CFrame.Position
        end
    end
    parts.HumanoidRootPart=parts.HumanoidRootPart or child(char,node("Part","HumanoidRootPart",{CFrame=CFrame.identity,Size=Vector3.new(2,2,1)}))
    parts.LowerTorso=parts.LowerTorso or child(char,node("Part","LowerTorso",{CFrame=CFrame.identity,Size=Vector3.new(1,1,1)}))
    local joints={}
    for name,j in data.joints do
        if parts[j.p0] and parts[j.p1] then
            local c0,c1=CFrame.new(table.unpack(j.c0)),CFrame.new(table.unpack(j.c1))
            local m=child(parts[j.p1],node(kind,name,{Enabled=true,Transform=CFrame.identity,Part0=parts[j.p0],Part1=parts[j.p1],C0=c0,C1=c1}))
            if kind=="AnimationConstraint" then
                m.Attachment0=child(parts[j.p0],node("Attachment",name.."0",{CFrame=c0}))
                m.Attachment1=child(parts[j.p1],node("Attachment",name.."1",{CFrame=c1}))
                m.C0,m.C1,m.Part0,m.Part1=nil,nil,nil,nil -- alias-free engine variant
            end
            joints[name]=m
            if (name=="LeftWrist" or name=="RightWrist") and parts[j.p1]:GetAttribute("HHC_SourcePart") then
                child(parts[j.p1],node("Attachment",name.."RigAttachment",{CFrame=c1,Position=c1.Position}))
            end
        end
    end
    local weapon=child(char,node("Model","WeaponModel"))
    weapon.Attributes.Class="Archer"
    local lh=parts.LeftHand
    local grip=lh:FindFirstChild("LeftGripAttachment")
    local gripPos=grip and grip.Position or Vector3.new(0,-lh.Size.Y*.5,0)
    weapon.Attributes.HandMuzzle=CFrame.new(gripPos+Vector3.new(0,0,-.28))
    -- Tier1 sag comes from the same existing five-segment fallback bow.
    local sag=2.6/(2*math.sin(math.rad(50)))*(1-math.cos(math.rad(50)))
    weapon.Attributes.HandBowRest=CFrame.new(gripPos+Vector3.new(0,0,sag-.1))
    local main=child(weapon,node("Part","Arc3",{CFrame=CFrame.identity}))
    local muzzle=child(main,node("Attachment","AttackMuzzle",{CFrame=CFrame.new(0,0,-.18)}))
    local stringPart=child(weapon,node("Part","String",{CFrame=CFrame.identity}))
    local nock=child(stringPart,node("Attachment","BowNock",{CFrame=CFrame.identity,Position=Vector3.zero}))
    -- WeaponTier 1: the player holds the starter bow (A23-34: no WeaponTier attribute = bare hands, no WeaponModel)
    local p=node("Player","owner",{Character=char,UserId=1});p.Attributes.Class="Archer";p.Attributes.Faction="Halo";p.Attributes.WeaponTier=1
    Players.ById[1]=p
    local token={};Feel.Actors[p]={Token=token}
    local ctx={Player=p,Char=char,Class="Archer",Faction="Halo",Token=token}
    local st={Char=char,Joints=joints,Base={},Last={},Layers={},HoldUntil=0,ReleaseUntil=0,AttackContext=ctx,AttackSerial={}}
    Feel.Chars[char]=st
    local function fk(outputs)
        local touched={HumanoidRootPart=true,LowerTorso=true}
        for _=1,4 do
            for name,m in joints do
                local f=Feel.jointFrames(m)
                if touched[f.P0.Name] then f.P1.CFrame=f.P0.CFrame*f.C0*(outputs[name] or CFrame.identity)*f.C1:Inverse();touched[f.P1.Name]=true end
            end
        end
        main.CFrame=lh.CFrame*weapon.Attributes.HandMuzzle*muzzle.CFrame:Inverse()
        stringPart.CFrame=lh.CFrame*weapon.Attributes.HandBowRest
        muzzle.WorldPosition=(main.CFrame*muzzle.CFrame).Position
        nock.WorldPosition=stringPart.CFrame*nock.Position
        for _,hand in {parts.LeftHand,parts.RightHand} do
            local att=hand:FindFirstChild(hand.Name=="LeftHand" and "LeftGripAttachment" or "RightGripAttachment")
            if att then att.WorldPosition=hand.CFrame*att.Position end
        end
        local equipped=char:FindFirstChild("WeaponModel")
        if equipped.HandFrames then
            for part,relative in equipped.HandFrames do part.CFrame=equipped.HandPart.CFrame*relative end
            local actual=equipped:FindFirstChild("AttackMuzzle",true)
            if actual then actual.WorldPosition=actual.Parent.CFrame*actual.Position end
            local actualNock=equipped:FindFirstChild("BowNock",true)
            if actualNock then actualNock.WorldPosition=actualNock.Parent.CFrame*actualNock.Position end
        end
    end
    fk({})
    buildWeapon(p,char)
    weapon=char:FindFirstChild("WeaponModel")
    main=weapon:FindFirstChild("Arc3")
    muzzle=main:FindFirstChild("AttackMuzzle")
    stringPart=weapon:FindFirstChild("String")
    nock=stringPart:FindFirstChild("BowNock")
    -- Attachment frames are real builder output; the stub stores Position separately.
    muzzle.CFrame=CFrame.new(muzzle.Position)
    nock.CFrame=CFrame.new(nock.Position)
    fk({})
    return st,parts,weapon,muzzle,nock,fk
end
local function recovered(st)
    for name,m in st.Joints do check(same(m.Transform,CFrame.identity),st.Char.Name..": restore "..name) end
end
for _,data in FIXTURES do
    for _,kind in {"Motor6D","AnimationConstraint"} do
        local st,parts,weapon,muzzle,nock,fk=fixture(data,kind)
        check(Feel.findJoints(st),data.name..": actual R15 pairs")
        local arm=Feel.armGeometry(st,"Left")
        check(arm~=nil,data.name..": actual left bones")
        local torso=parts.UpperTorso.CFrame
        local shoulder=(torso*arm.Shoulder.C0).Position
        local far=CFrame.new(shoulder+Vector3.new(0,0,-(arm.L1+arm.L2)*3)-arm.Wrist.C1.Position)
        local limited=Feel.solveArm(arm,torso,far,Vector3.yAxis)
        check(limited and limited.Clamped,"unreachable wrist is explicitly clamped")
        check(limited.Shoulder.Position.Magnitude<1e-5 and limited.Elbow.Position.Magnitude<1e-5 and limited.Wrist.Position.Magnitude<1e-5,"unreachable goal never stretches bones")
        -- Unequal genuine source bones have an inner unreachable sphere too.
        -- A fraction of L1+L2 alone may fall inside abs(L1-L2).
        local inner,outer=math.abs(arm.L1-arm.L2),arm.L1+arm.L2
        local reachableDistance=inner+(outer-inner)*.8
        for _,direction in {Vector3.new(-1,1,-1).Unit,Vector3.new(0,-1,0),Vector3.new(0,1,0),Vector3.new(0,0,1)} do
            local torso=parts.UpperTorso.CFrame*CFrame.Angles(.13,-.21,.09)
            local start=(torso*arm.Shoulder.C0).Position
            local goalWrist=start+direction*reachableDistance
            local handRot=CFrame.Angles(.2,.3,-.6)
            local goal=CFrame.new(goalWrist-handRot:VectorToWorldSpace(arm.Wrist.C1.Position))*handRot
            local solved=Feel.solveArm(arm,torso,goal,Vector3.yAxis)
            check(solved and not solved.Clamped,data.name..": reachable exact solve")
            local upper=torso*arm.Shoulder.C0*solved.Shoulder*arm.Shoulder.C1:Inverse()
            local lower=upper*arm.Elbow.C0*solved.Elbow*arm.Elbow.C1:Inverse()
            local hand=lower*arm.Wrist.C0*solved.Wrist*arm.Wrist.C1:Inverse()
            check(same(hand,goal),data.name..": FK hand goal")
            check(solved.Shoulder.Position.Magnitude<1e-5 and solved.Elbow.Position.Magnitude<1e-5 and solved.Wrist.Position.Magnitude<1e-5,data.name..": bones not translated")
            check(math.abs((solved.ElbowPosition-start).Magnitude-arm.L1)<1e-5,data.name..": actual upper length")
            check(math.abs((solved.WristPosition-solved.ElbowPosition).Magnitude-arm.L2)<1e-5,data.name..": actual lower length")
        end
        -- Arbitrary bind rotations must satisfy the same Motor/attachment FK equation.
        local spun=table.clone(arm)
        for _,name in {"Shoulder","Elbow","Wrist"} do
            spun[name]=table.clone(arm[name])
            spun[name].C0=spun[name].C0*CFrame.Angles(.3,-.4,.2)
            spun[name].C1=spun[name].C1*CFrame.Angles(-.2,.5,-.1)
        end
        local torso=parts.UpperTorso.CFrame
        local start=(torso*spun.Shoulder.C0).Position
        local rotation=CFrame.Angles(-.2,.7,1.1)
        local spunReach=math.abs(spun.L1-spun.L2)+2*math.min(spun.L1,spun.L2)*.9
        local handGoal=CFrame.new(start+Vector3.new(-.5,.2,-1).Unit*spunReach-rotation:VectorToWorldSpace(spun.Wrist.C1.Position))*rotation
        local solved=Feel.solveArm(spun,torso,handGoal,Vector3.yAxis)
        local upper=torso*spun.Shoulder.C0*solved.Shoulder*spun.Shoulder.C1:Inverse()
        local lower=upper*spun.Elbow.C0*solved.Elbow*spun.Elbow.C1:Inverse()
        local hand=lower*spun.Wrist.C0*solved.Wrist*spun.Wrist.C1:Inverse()
        check(same(hand,handGoal),data.name..": nonidentity binds")
        local context=st.AttackContext
        for _,release in {false,true} do
            st.AttackContext=context
            st.BowReleased=false
            local name=release and "ArcherRelease" or "ArcherSwing"
            local launch=release and .18 or .22
            local attack={Clip=Feel.Clips[name],T=launch,Rate=1,LaunchT=launch}
            st.Layers.Attack=attack
            st.AttackTarget=Vector3.new(0,parts.Head.CFrame.Position.Y,-20)
            local base,out={},{}
            for joint in st.Joints do base[joint]=CFrame.identity end
            for joint,track in attack.Clip.Joints do out[joint]=Feel.sample(track,Feel.archerPhase(attack)) end
            Feel.archerPose(st,attack,base,out)
            check(out.LeftWrist and out.RightWrist,data.name..": both hands solved at launch")
            fk(out)
            local hand=Feel.handPoint(st.Char,false)
            local muzzleCF=parts.LeftHand.CFrame*weapon.Attributes.HandMuzzle
            local aim=(st.AttackTarget-muzzleCF.Position).Unit
            check(muzzleCF.LookVector:Dot(aim)>.999999,data.name..": target matches bow axis")
            check((muzzleCF.Position-hand):Cross(aim).Magnitude<1e-5,data.name..": string hand on arrow axis")
            Feel.weaponMotion(st,attack)
            check(near(nock.Position,weapon:FindFirstChild("String").CFrame:PointToObjectSpace(hand)),data.name..": hand/string exact contact")
            check(st.NockArrow~=nil,data.name..": nocked arrow exists before release")
            check(st.NockArrow.CFrame.LookVector:Dot(aim)>.999999,data.name..": visible shaft matches shot")
            -- Actual delayed function: a newer attack/death/class change cancels before render.
            local count=0
            Feel.launchArrow(st.AttackContext,launch,function()count+=1 end)
            delays();check(count==0,"launch waits for physics/render batch")
            render();check(count==1 and st.BowReleased and st.NockArrow==nil,"launch releases once and cleans arrow")
            render();check(count==1,"launch callback disconnected")
            st.BowReleased=false
            Feel.launchArrow(st.AttackContext,launch,function()count+=1 end)
            delays();st.AttackSerial={};render();check(count==1,"new attack cancels launch")
            Feel.launchArrow(st.AttackContext,launch,function()count+=1 end)
            delays();st.AttackContext.Player.Attributes.Class="Mage";render();check(count==1,"class change cancels pending render")
            st.AttackContext.Player.Attributes.Class="Archer"
            Feel.launchArrow(st.AttackContext,launch,function()count+=1 end)
            st.Char:FindFirstChildOfClass("Humanoid").Health=0;delays();render();check(count==1,"death cancels pending delay")
            st.Char:FindFirstChildOfClass("Humanoid").Health=100
            st.NockArrow=makePart({Name="TransientArrow"})
            Feel.launchArrow(st.AttackContext,launch,function()error("intentional offline launch failure")end)
            delays();render();check(st.BowReleased and st.NockArrow==nil,"failed callback still releases/cleans")
            st.BowReleased=false
            local attack2={Clip=Feel.Clips[name],T=.1,Rate=1,LaunchT=launch}
            st.Layers.Attack=attack2
            for key,m in st.Joints do m.Transform=CFrame.identity end
            st.Base,st.Last={},{}
            Feel.Active[st]=true;Feel.ActiveCount+=1
            Feel.stepChar(st,0,1000)
            local previous={};for key,m in st.Joints do previous[key]=m.Transform end
            Feel.stepChar(st,0,1000)
            for key,m in st.Joints do check(same(m.Transform,previous[key]),data.name..": no additive frame drift "..key) end
            Feel.drop(st);recovered(st)
            metrics[data.name.."/"..kind.."/"..name]={ForwardDot=muzzleCF.LookVector:Dot(aim),HandAxisError=(muzzleCF.Position-hand):Cross(aim).Magnitude}
        end
        for _,class in {"Warrior","Mage","Archer"} do
            context.Player.Attributes.Class=class
            context.Player.Attributes.WeaponTier=1
            buildWeapon(context.Player,st.Char)
            for _,which in {"Swing","Release"} do
                local delay=class=="Archer" and (which=="Release" and .18 or .22) or (class=="Mage" and (which=="Release" and .35 or .24) or .23)
                local target=Vector3.new(0,parts.Head.CFrame.Position.Y,-20)
                local packet={UserId=1,Class=class,Faction="Halo",Character=st.Char,LaunchDelay=delay,Targets={target},Pos=target}
                local fit=Feel.attackTime(class,which)
                check(Feel.playAttack(st.Char,class,which,fit,packet),data.name..": actual playAttack "..class..which)
                local l=st.Layers.Attack
                check(l.Clip.Len/l.Rate<Config.Classes[class].SwingInterval,data.name..": recovery before next swing "..class..which)
                if class=="Archer" then
                    check(math.abs(l.LaunchT/l.Rate-delay)<1e-8,"packet launch remains real seconds")
                    l.T=l.LaunchT
                    check(math.abs(Feel.archerPhase(l)-(which=="Release" and .18 or .22))<1e-8,"clip launch maps to packet time")
                    check(l.Clip.Len/l.Rate-delay>=MOTION.BOW.Settle,"draw preserves recovery")
                end
                l.T=delay*l.Rate
                Feel.stepChar(st,0,1000)
                local out={};for key,m in st.Joints do out[key]=m.Transform end
                fk(out)
                local equipped=st.Char:FindFirstChild("WeaponModel")
                if class=="Mage" then
                    local main=equipped:FindFirstChild("Tip")
                    local origin=equipped:FindFirstChild("AttackMuzzle",true).WorldPosition
                    local direction=(target-origin).Unit
                    check(main.CFrame.UpVector:Dot(direction)>.999999,data.name..": actual staff/cast target axis")
                    local shaft=equipped:FindFirstChild("Shaft")
                    local grip=shaft.CFrame:PointToObjectSpace(Feel.handPoint(st.Char,false))
                    check(math.sqrt(grip.X*grip.X+grip.Z*grip.Z)<1e-5,data.name..": actual staff grip centreline")
                    check(math.abs(grip.Y)<shaft.Size.Y*.5,data.name..": hand within actual shaft length")
                    check(out.RightWrist.Position.Magnitude<1e-5,data.name..": staff wrist joint not translated")
                elseif class=="Warrior" then
                    local handle=equipped:FindFirstChild("Handle")
                    local grip=handle.CFrame:PointToObjectSpace(Feel.handPoint(st.Char,false))
                    check(grip.Magnitude<1e-5,data.name..": actual sword handle held in right hand")
                end
                Feel.drop(st)
            end
        end
        -- A changed packet launch time, tier7 bow and elevated volley target keep one shooting line.
        context.Player.Attributes.Class="Archer"
        context.Player.Attributes.WeaponTier=7
        buildWeapon(context.Player,st.Char)
        local high=Vector3.new(8,parts.Head.CFrame.Position.Y+30,-20)
        local packet={UserId=1,Class="Archer",Faction="Halo",Character=st.Char,LaunchDelay=.27,Targets={high},Pos=high-Vector3.new(0,30,0)}
        check(Feel.playAttack(st.Char,"Archer","Release",Feel.attackTime("Archer","Release"),packet),"tier7 volley plays")
        local l=st.Layers.Attack;l.T=l.LaunchT
        Feel.stepChar(st,0,1000)
        local out={};for key,m in st.Joints do out[key]=m.Transform end
        fk(out)
        local equipped=st.Char:FindFirstChild("WeaponModel")
        local muzzle=equipped:FindFirstChild("AttackMuzzle",true)
        local frame=muzzle.Parent.CFrame*muzzle.CFrame
        local aim=(high-frame.Position).Unit
        check(frame.LookVector:Dot(aim)>.999999,data.name..": tier7 elevated target axis")
        check((frame.Position-Feel.handPoint(st.Char,false)):Cross(aim).Magnitude<1e-5,data.name..": tier7 string hand axis")
        check(math.abs(l.LaunchT/l.Rate-.27)<1e-8,"changed packet delay maps exactly")
        Feel.drop(st)
        context.Player.Attributes.Class="Mage";context.Class="Mage"
        local projectileCalls=0
        st.BowReleased=false
        Feel.launchWeapon(context,.24,function()projectileCalls+=1 end)
        delays();check(projectileCalls==0,"staff launch waits for actual Transform batch")
        render();check(projectileCalls==1 and not st.BowReleased,"staff launch does not release bow state")
        local cancelled=0
        local prepared=makePart({Name="PreparedMeteor"})
        local prepared2=makePart({Name="PreparedMeteor2"})
        Feel.guardEffect(context,prepared,1,{Cancel=function()cancelled+=1 end})
        local shared=Feel.GuardConn
        Feel.guardEffect(context,prepared2,1,{Cancel=function()error("intentional cancel failure")end})
        check(Feel.GuardConn==shared,"preparation guard shares one heartbeat")
        heartbeat();check(prepared.Parent and prepared2.Parent,"valid preparation stays")
        context.Player.Attributes.Class="Archer"
        heartbeat();check(prepared.Destroyed and prepared2.Destroyed and cancelled==1,"actor change removes prepared effects even if tween cancel fails")
        check(Feel.GuardConn==nil and next(Feel.Guarded)==nil,"empty preparation guard disconnects")
    end
end
print("WEAPON_MOTION_CHECKS "..checks)
for name,m in metrics do if type(m)=="table" then print("POSE "..name.." "..m.ForwardDot.." "..m.HandAxisError) end end
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", type=Path, default=ROOT / "build/luau_cli_0_741/luau.exe")
    parser.add_argument("--native-capture", type=Path)
    parser.add_argument("--costumes", action="store_true", help="Audit all fourteen preserved and four inferred manifest sources")
    parser.add_argument("--manifest", type=Path, default=MANIFEST, help="Tracked source inventory; no live status lookup")
    args = parser.parse_args()
    if args.native_capture:
        capture = json.loads(args.native_capture.read_text(encoding="utf-8-sig"))
        safe = {"name": "NativeAJU", "joints": {k: {x: v[x] for x in ("p0", "p1", "c0", "c1")}
                                                    for k, v in capture["joints"].items()}, "parts": {}}
        for name, p in capture["parts"].items():
            safe["parts"][name] = {"size": p["size"]}
            grip = p["attachments"].get("LeftGripAttachment" if name == "LeftHand" else "RightGripAttachment")
            if grip:
                safe["parts"][name]["grip"] = grip["cf"]
        FIXTURE.parent.mkdir(parents=True, exist_ok=True)
        FIXTURE.write_text(json.dumps(safe, indent=2) + "\n", encoding="utf-8")
    fixtures = [json.loads(FIXTURE.read_text(encoding="utf-8"))]
    states = []
    if args.costumes:
        extra, states = costume_fixtures(args.manifest.resolve())
        fixtures.extend(extra)
    source = FX.read_text(encoding="utf-8")
    motion = source[source.index("local MOTION = {"):source.index("-- A14-4 combat feel: functions")]
    names = ["same", "ease", "compileClips", "sample", "jointParts", "restoreJoint", "findJoints", "actorState", "attackContext", "validAttack",
             "after", "handPoint", "muzzle", "jointFrames", "rotationBetween", "armGeometry", "solveArm",
             "archerPhase", "archerPose", "staffPose", "launchWeapon", "launchArrow", "guardEffect", "clearWeaponMotion", "weaponMotion", "play", "stepChar", "drop", "attackTime", "playAttack"]
    # Additional geometry helpers are taken from source, rather than mirrored in the test.
    if "function Feel.bowAim(" in source:
        names.insert(names.index("archerPose"), "bowAim")
    if "function Feel.bowDrawDistance(" in source:
        names.insert(names.index("archerPose"), "bowDrawDistance")
    harness = MATH + motion + "\n" + "\n".join(source_function(source, n) for n in names)
    config = (ROOT / "src/ReplicatedStorage/Shared/Config.luau").read_text(encoding="utf-8")
    harness += "\n" + config[config.index("Config.Weapons = {"):config.index("-- display names per class")]
    visuals = VISUALS.read_text(encoding="utf-8")
    helper_names = ["attrNum", "attrStr", "getFaction", "getClass", "charScale", "clearChild", "accPart",
                    "gripCFrame", "buildSword", "buildStaff", "buildBow", "buildWeapon"]
    harness += "\n" + "\n".join(local_function(visuals, n) for n in helper_names)
    output = ROOT / "build/weapon_motion_offline_test.luau"
    output.parent.mkdir(parents=True, exist_ok=True)
    pose_rows, count, fixture_results = {}, 0, []
    # An assertion in one source must not silently prevent auditing the other
    # seventeen. Each process has fresh simulated actors, layers and callbacks.
    for fixture in fixtures:
        output.write_text(harness + "\nlocal FIXTURES=" + lua([fixture]) + "\n" + TESTS, encoding="utf-8")
        completed = subprocess.run([str(args.luau.resolve()), str(output)], capture_output=True, text=True, encoding="utf-8")
        checks = None
        for line in completed.stdout.splitlines():
            if line.startswith("WEAPON_MOTION_CHECKS "):
                checks = int(line.split()[1])
                count += checks
            elif line.startswith("POSE "):
                _, name, forward, axis_error = line.split()
                pose_rows[name] = {"forward_dot": float(forward), "string_hand_axis_error": float(axis_error)}
        passed = completed.returncode == 0 and checks is not None
        entry = {"name": fixture["name"], "passed": passed, "checks": checks,
                 "joint_variants": ["Motor6D", "AnimationConstraint"],
                 "pose_classes": ["Warrior", "Mage", "Archer"],
                 "actual_studio_motion_validated": False}
        if not passed:
            entry["error"] = completed.stderr or completed.stdout or "Missing completion marker"
            print(entry["error"], end="\n", file=sys.stderr)
        fixture_results.append(entry)
        print("WEAPON_MOTION_FIXTURE", fixture["name"], "PASS" if passed else "FAIL", checks)
        row = next((r for r in states if r["name"] == fixture["name"]), None)
        if row:
            row.update(state="offline_verified" if passed else "offline_motion_failed", motion_checks=checks)
            if not passed:
                row["reason"] = entry["error"]
    passed = (all(x["passed"] for x in fixture_results)
              and all(r["state"] == "offline_verified" for r in states)
              and (not args.costumes or len(states) == len(fixtures) - 1 == 18))
    print("WEAPON_MOTION_CHECKS", count)
    result = {"schema": 2, "offline_only": True, "physics_simulated": False, "passed": passed,
              "checks": count, "poses": pose_rows, "fixtures": [x["name"] for x in fixtures], "costumes": states,
              "fixture_results": fixture_results,
              "source_manifest": str(args.manifest.resolve()) if args.costumes else None,
              "source_manifest_sha256": sha(args.manifest.resolve()) if args.costumes else None,
              "offline_costume_contracts_passed": sum("contract_metrics" in r for r in states),
              "invalid_contract_rejection_checks": sum(r.get("contract_metrics", {}).get("invalid_contract_rejection_checks", 0) for r in states),
              "offline_costume_motion_fixtures_passed": sum(r["state"] == "offline_verified" for r in states),
              "actual_studio_costume_motion_validated_by_this_tool": 0,
              "actual_studio_costume_motion_status": "not_queried",
              "game_ready_claimed_by_this_tool": False, "live_status_queried": False,
              "state_counts": {state: sum(row["state"] == state for row in states)
                               for state in sorted({row["state"] for row in states})},
              "limitations": ["No Studio visual, collision, skin deformation, multiplayer, or game-ready approval",
                              "R15 proxy FK/weapon pose math does not animate or approve the whole source skin",
                              "Original twenty-three bones are preserved; fifteen manual bones remain inferred",
                              "Recorded manual runtime contracts currently require their exact local build proxy plans",
                              "Separate corrected/expression siblings are not substituted for original benchmark sources"]}
    (ROOT / "build/weapon_motion_offline_result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
