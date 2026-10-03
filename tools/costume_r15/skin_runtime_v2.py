"""Generic exact-import skin assembly schema 2; offline payload preparation only.

Supports fifteen inferred and twenty-three preserved source bones, two/three
material surfaces, package-relative provenance, and archived Pending siblings.
Never calls Studio, uploads, APIs, src edits, or playable registry promotion.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np

import skin_runtime as base
import skin_schema
import skin_expression_schema
import skin_binding_schema
from skin_verify import VERIFY
from assemble import manifest as proxy_manifest
from constraints import JOINTS, PRIMARY, RigError
from glb_io import accessor_values, read_glb
from preserve_skin import node_matrices


def proxy_data(blueprint,input_path):
    plan=Path(blueprint["proxy_plan"])
    package_path=Path(input_path)
    package=json.loads(package_path.read_text(encoding="utf-8"))
    if package.get("kind")=="preserved_original_skin_pending":
        runtime_path=skin_schema.local_input(package_path.parent,package.get("proxy_runtime", "proxy_runtime.json"))
        expected=package.get("sha256",{}).get("proxy_runtime")
        if "proxy_runtime" in package and (not expected or not runtime_path.is_file()):
            raise RigError("Declared package proxy runtime and exact SHA are required")
        if expected and runtime_path.is_file():
            if base.sha(runtime_path)!=expected: raise RigError("Saved proxy runtime SHA changed")
            runtime=json.loads(runtime_path.read_text(encoding="utf-8"))
            if runtime.get("schema")!=1 or runtime.get("name")!=blueprint["name"] or runtime.get("proxy_plan_sha256")!=blueprint["proxy_plan_sha256"]:
                raise RigError("Saved proxy runtime targets a different plan")
            if runtime.get("source_skin_sha256")!=blueprint.get("original_skin_sha256",blueprint["skin_sha256"]) or runtime.get("source_sha256")!=blueprint["original_sha256"]:
                raise RigError("Saved proxy runtime targets a different source")
            if runtime.get("source_rigid_batches_sha_verified") is not True or runtime.get("original_source_sha_verified") is not True or runtime.get("rig_ready_for_game") is not False:
                raise RigError("Saved proxy runtime provenance or Pending state was not verified")
            if runtime.get("target_height_studs")!=5.5 or set(p["name"] for p in runtime["parts"])!=set(PRIMARY) or len(runtime["parts"])!=15 or len(runtime["joints"])!=15:
                raise RigError("Saved proxy runtime is not the exact fifteen-part R15 contract")
            if not isinstance(runtime.get("hip_height"),(int,float)) or not np.isfinite(runtime["hip_height"]) or runtime["hip_height"]<=0:
                raise RigError("Saved proxy runtime requires a positive finite HipHeight")
            if runtime.get("source_frame_policy")!=package.get("source_frame_policy"):
                raise RigError("Saved proxy runtime source frame policy changed")
            root_size=base.finite(runtime["root"]["size"],3);root_center=base.finite(runtime["root"]["center"],3)
            if min(root_size)<=0: raise RigError("Saved proxy root requires positive finite bounds")
            centers={"HumanoidRootPart":root_center}
            for part in runtime["parts"]:
                size=base.finite(part["size"],3);center=base.finite(part["center"],3)
                frame=base.frame(part["cframe"])
                if min(size)<=0 or not np.allclose(frame[:3,3],center,atol=1e-6) or not np.allclose(frame[:3,:3],np.eye(3),atol=1e-6):
                    raise RigError("Saved proxy boxes must retain their declared position and identity axes")
                centers[part["name"]]=center
            if {(j["name"],j["part0"],j["part1"]) for j in runtime["joints"]}!={(name,p0,p1) for name,p0,p1,_ in JOINTS}:
                raise RigError("Saved proxy runtime R15 motor edges changed")
            for joint in runtime["joints"]:
                c0=base.frame(joint["C0"]);c1=base.frame(joint["C1"]);world=base.finite(joint["world"],3)
                if np.linalg.norm(centers[joint["part0"]]+c0[:3,3]-world)>1e-5 or np.linalg.norm(centers[joint["part1"]]+c1[:3,3]-world)>1e-5:
                    raise RigError("Saved proxy runtime motor hinge is inconsistent")
            # The package writer calls invisible region boxes `parts`; the
            # legacy assembler calls the same checked boxes `meshes`.
            return {**runtime,"meshes":runtime["parts"]}
        # Current-workspace fallback only: same exact plan bytes, complete
        # original source/batch/texture checks through the existing assembler.
        manifest_path=skin_schema.local_input(package_path.parent,package["skin_manifest"])
        sidecar=json.loads(manifest_path.read_text(encoding="utf-8"))
        original=Path(sidecar["proxy_plan"])
        if original.is_file() and base.sha(original)==blueprint["proxy_plan_sha256"]: plan=original
    return proxy_manifest(plan,blueprint["name"],root_reference="lower-torso-y")


def prepare(path,model_path,proxy_override=None,pending_name=None,expression_manifest=None,source_contract=None,binding_schema=0):
    if binding_schema not in (0,1): raise RigError("Only the exact explicit binding schema 1 is supported")
    blueprint=skin_schema.load(path,proxy_override)
    if not expression_manifest and blueprint.get("expression_manifest"):
        expression_manifest=Path(blueprint["expression_manifest"])
        if not expression_manifest.is_absolute(): expression_manifest=base.ROOT/expression_manifest
    expression=skin_expression_schema.load(expression_manifest,blueprint) if expression_manifest else None
    proxy_input=path
    if expression:
        blueprint["original_skin_sha256"]=expression["original_skin_sha256"]
        if source_contract:
            original=skin_schema.load(source_contract,proxy_override)
            if any(original[key]!=blueprint[key] for key in ("name","original_sha256","proxy_plan_sha256","rig_origin","original_bones_claimed")) or original["skin_sha256"]!=expression["original_skin_sha256"]:
                raise RigError("Expression skin must retain the exact source proxy/whole bind hierarchy")
            prior_bones={b["name"]:b for b in original["bones"]}
            if len(prior_bones)!=len(blueprint["bones"]): raise RigError("Expression skin lost source bones")
            for bone in blueprint["bones"]:
                prior=prior_bones.get(bone["name"])
                if not prior or any(prior[key]!=bone[key] for key in ("name","parent","part","principal")) or any(not np.allclose(prior[key],bone[key],atol=1e-7,rtol=0) for key in ("reference_game_position","reference_unit_rotation")):
                    raise RigError("Expression skin changed an original source bind")
            proxy_input=source_contract
    elif source_contract:
        raise RigError("--source-contract is only needed with an exact expression manifest")
    proxy=proxy_data(blueprint,proxy_input)
    name=blueprint["name"]
    pending_name=pending_name or name+("_ExpressionsSkinSchema2Candidate" if expression else "_SkinSchema2Candidate")
    if not pending_name.startswith(name+"_") or len(pending_name)>120 or not all(c.isascii() and (c.isalnum() or c=="_") for c in pending_name):
        raise RigError("Use a distinct same-costume Pending sibling; old Pending models are preserved")
    gltf,binary,_=read_glb(blueprint["skin_glb"])
    parents,local,world=node_matrices(gltf)
    indices=gltf["skins"][0]["joints"]
    references={b["name"]:b for b in blueprint["bones"]}
    bones=[]
    for index in indices:
        b=gltf["nodes"][index];reference=references.get(b["name"])
        if not reference: raise RigError("Source node names disagree with the preserved contract")
        matrix=world[index];lengths=np.linalg.norm(matrix[:3,:3],axis=0);unit=matrix[:3,:3]/lengths
        if np.max(np.abs(matrix[:3,3]-reference["reference_game_position"]))>1e-5 or np.max(np.abs(unit-np.array(reference["reference_unit_rotation"]).reshape(3,3)))>1e-4:
            raise RigError("Source scene wrapper/bind disagrees with sidecar provenance")
        bones.append({"name":b["name"],"parent":reference["parent"],"position":matrix[:3,3].tolist(),"unit_rotation":unit.reshape(9).tolist(),"proxy_part":reference["part"],"principal":reference["principal"]})
    meshes=[];points={};seen=set()
    for index,node in enumerate(gltf["nodes"]):
        if "mesh" not in node: continue
        mesh=gltf["meshes"][node["mesh"]];mesh_name=node.get("name")
        if mesh_name in seen or mesh_name!=mesh.get("name") or node.get("skin")!=0: raise RigError("A unique preserved skinned material surface is required")
        seen.add(mesh_name);native=[];referenced=[]
        for primitive in mesh["primitives"]:
            if not {"POSITION","NORMAL","TEXCOORD_0","JOINTS_0","WEIGHTS_0"}<=set(primitive["attributes"]): raise RigError("Skinned surface attributes were lost")
            vertices=np.asarray(accessor_values(gltf,binary,primitive["attributes"]["POSITION"]),dtype=float)
            native.extend(vertices)
            indices=np.asarray(accessor_values(gltf,binary,primitive["indices"]),dtype=int)
            if primitive.get("mode",4)!=4 or len(indices)%3 or min(indices)<0 or max(indices)>=len(vertices): raise RigError("Exact indexed triangle surface required")
            referenced.extend(vertices[indices])
        native=np.array(native);game=native@world[index][:3,:3].T+world[index][:3,3]
        used=np.asarray(referenced)@world[index][:3,:3].T+world[index][:3,3]
        low,high=game.min(0),game.max(0)
        points[mesh_name]={"full_accessor":game,"referenced_triangles":used} if expression else game
        meshes.append({"name":mesh_name,"center":((low+high)/2).tolist(),"size":(high-low).tolist()})
    if len(meshes) not in (2,3): raise RigError("Exactly the inspected two/three surfaces are required")
    lookup={b["name"]:b for b in bones}
    for joint in proxy["joints"]:
        if np.linalg.norm(np.array(joint["world"])-lookup[joint["part1"]]["position"])>.002:
            raise RigError("Preserved skin principal hinge does not match the exact R15 proxy: "+joint["part1"])
    parts=[]
    for name_part in PRIMARY:
        geometry=next(g for g in proxy["meshes"] if g["name"]==name_part)
        parts.append({"name":name_part,"size":geometry["size"],"center":geometry["center"]})
    data={"schema":1,"name":name,"pending_name":pending_name,"model_path":base.model_path(model_path),
          "skin_sha256":blueprint["skin_sha256"],"original_sha256":blueprint["original_sha256"],"contract_sha256":blueprint["contract_sha256"],
          "joints_sha256":blueprint["proxy_plan_sha256"],"rig_origin":blueprint["rig_origin"],"original_bones_claimed":blueprint["original_bones_claimed"],
          "meshes":meshes,"bones":bones,"proxy_parts":parts,"root":proxy["root"],"joints":proxy["joints"],"hip_height":proxy["hip_height"],"target_height":5.5,"ready":False}
    if expression: data["expression"]=expression
    if binding_schema: data["binding_schema"]=binding_schema
    return data,points


SCHEMA_METADATA=r'''
    local manifest={schema=2,name=DATA.name,skin_sha256=DATA.skin_sha256,joints_sha256=DATA.joints_sha256,contract_sha256=DATA.contract_sha256,inspection_sha256=FIT.inspection_sha256,
        unique_bones=#DATA.bones,bone_instances=boneCount,mesh_instances=meshCount,bones={},meshes={}}
    for _,entry in DATA.bones do table.insert(manifest.bones,{name=entry.name,parent=entry.parent,part=entry.proxy_part,principal=entry.principal}) end
    local function skinRelative(object)
        local names={}
        while object and object~=skin do table.insert(names,1,object.Name);object=object.Parent end
        if object~=skin then error("스킨 모델 밖의 참조입니다.") end
        return names
    end
    for _,object in skin:GetDescendants() do
        if object:IsA("MeshPart") then table.insert(manifest.meshes,{path=skinRelative(object),mesh_id=object.MeshId}) end
    end
    if DATA.binding then manifest.binding_schema=1;manifest.binding_host_path=DATA.binding.anchor_path end
    model:SetAttribute("HHC_SkinManifest",HttpService:JSONEncode(manifest))
    model:SetAttribute("HHC_SourceFileSHA256",DATA.skin_sha256)
    model:SetAttribute("HHC_SkinRootBindSize",root.Size)
    model:SetAttribute("HHC_SkinBindScale",model:GetScale())
    model:SetAttribute("HHC_SkinRuntimeValidated",false)
    for _,part in parts do part:SetAttribute("HHC_ProxyBindSize",part.Size) end
'''


def assembly():
    code=base.ASSEMBLE
    replacements={
        'pending:FindFirstChild(DATA.name)':'pending:FindFirstChild(DATA.pending_name)',
        'model.Name=DATA.name':'model.Name=DATA.pending_name',
        'meshCount~=2':'meshCount~=#DATA.meshes',
        'child:SetAttribute("HHC_SkinPrincipal",true)':'child:SetAttribute("HHC_SkinPrincipal",expected.principal)',
        'model:SetAttribute("HHC_InferredManualCandidate",true)':'model:SetAttribute("HHC_InferredManualCandidate",DATA.original_bones_claimed==false)',
        'model:SetAttribute("HHC_OriginalBonesClaimed",false)':'model:SetAttribute("HHC_OriginalBonesClaimed",DATA.original_bones_claimed)',
        'model:SetAttribute("HHC_SkinRuntimeSchema",1)':'model:SetAttribute("HHC_SkinRuntimeSchema",2)',
        'destination="ServerStorage.CostumePendingRigs."..DATA.name':'destination="ServerStorage.CostumePendingRigs."..DATA.pending_name',
        '    local humanoid=Instance.new("Humanoid")':SCHEMA_METADATA+skin_expression_schema.ASSEMBLE+'\n    local humanoid=Instance.new("Humanoid")',
    }
    for before,after in replacements.items():
        if before not in code: raise RigError("The guarded base assembler boundary changed: "+before)
        code=code.replace(before,after)
    return skin_binding_schema.assembly(code)


def write_payload(data,mode,output,inspection=None,fit=None):
    if mode in ("assemble","verify") and inspection is not None:
        data=skin_binding_schema.configure(data,inspection)
    code=base.COMMON.replace("__DATA__",base.literal(data))
    if mode=="inspect": code+=base.INSPECT
    elif mode=="assemble":
        if inspection is None or fit is None: raise RigError("A strictly validated actual imported inventory is required")
        code+=assembly().replace("__SNAP__",base.literal(inspection)).replace("__FIT__",base.literal(fit))
    elif mode=="verify":
        if inspection is None or fit is None: raise RigError("A strictly validated actual imported inventory is required")
        matcher=skin_binding_schema.verify(VERIFY).replace('return HttpService:JSONEncode({schema=2',skin_expression_schema.VERIFY+'\nreturn HttpService:JSONEncode({schema=2')
        code+=matcher.replace("__SNAP__",base.literal(inspection)).replace("__FIT__",base.literal(fit))
    else: raise RigError("Unknown generic mode")
    return base.write_draft(output,{"code":code,"datamodel_type":"Edit"})


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("contract",type=Path);parser.add_argument("--model-path",required=True)
    parser.add_argument("--proxy-plan",type=Path);parser.add_argument("--pending-name");parser.add_argument("--mode",choices=("inspect","assemble","verify"),default="inspect")
    parser.add_argument("--expression-manifest",type=Path);parser.add_argument("--source-contract",type=Path)
    parser.add_argument("--binding-schema",type=int,choices=(0,1),default=0)
    parser.add_argument("--inspection",type=Path);parser.add_argument("--output",required=True,type=Path)
    args=parser.parse_args();data,points=prepare(args.contract,args.model_path,args.proxy_plan,args.pending_name,args.expression_manifest,args.source_contract,args.binding_schema)
    inspection,fit=None,None
    if args.mode in ("assemble","verify"):
        if not args.inspection: parser.error("--inspection is required")
        inspection,fit=base.validate_inspection(args.inspection,data,points)
    print(json.dumps(write_payload(data,args.mode,args.output,inspection,fit),ensure_ascii=False))


if __name__=="__main__":
    try: main()
    except (RigError,KeyError,ValueError,OSError) as error: raise SystemExit("skin_runtime_v2 refused: "+str(error))
