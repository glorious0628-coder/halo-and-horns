# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Actual native 15/23-bone inventory and read-only schema-2 matcher tests.

Python validation reads the real saved importer responses. Engine matcher tests
execute the unchanged Luau payload with CFrame/object doubles, never Studio.
"""
from __future__ import annotations

raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import ast
import copy
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

import skin_runtime as base
import skin_runtime_v2 as runtime
import skin_expression_schema
import skin_binding_schema
from skin_verify import VERIFY
from test_skin_runtime import lua

ROOT=Path(__file__).resolve().parents[2]
CASES=[
    ("art/models/costume/prepared/skin/Costume_HaloArcherM_preserved_v2/package.json", "ServerStorage/CostumeSkinImports/Costume_HaloArcherM", "build/halo_archer_m_skin_import/actual_imports.json"),
    ("build/manual_partition_candidates/NeutralWarriorF_skin_v3/runtime_contract.json", "ServerStorage/CostumeSkinImports/Costume_NeutralWarriorF", "build/manual_partition_candidates/NeutralWarriorF_skin_v3/actual_imports.json"),
    ("art/models/costume/expressions/Costume_HaloArcherM/Costume_HaloArcherM_PreservedSkinExpressions_v1.skin.json", "ServerStorage/CostumeExpressionSkinImports/Costume_HaloArcherM", "build/costume_skin_expression_imports/Costume_HaloArcherM/actual_imports.json"),
    ("art/models/costume/expressions/Costume_HaloArcherM/Costume_HaloArcherM_FaceUnionSkin_v1.skin.json", "ServerStorage/CostumeExpressionSkinImports_FaceUnion_v1/Costume_HaloArcherM", "build/skin_runtime_v2/face_union_v1/actual_inspection.json"),
    ("art/models/costume/expressions/Costume_HaloArcherM/Costume_HaloArcherM_FaceUnionSkin_v1.skin.json", "ServerStorage/CostumeExpressionSkinImports_FaceUnion_v1/Costume_HaloArcherM", "build/skin_runtime_v2/face_union_v1/actual_inspection.json", 1),
    ("build/manual_partition_candidates/NeutralWarriorF_skin_v3/runtime_contract.json", "ServerStorage/CostumeSkinImports/Costume_NeutralWarriorF", "build/manual_partition_candidates/NeutralWarriorF_skin_v3/actual_imports.json", 1),
    ("art/models/costume/expressions/Costume_HaloArcherM/Costume_HaloArcherM_FaceUnionMouthRestored_v1.skin.json", "ServerStorage/CostumeExpressionSkinImports_FaceUnionMouth_v1/Costume_HaloArcherM", "build/skin_runtime_v2/face_union_mouth_binding_v1/actual_inspection.json", 1),
]


def main():
    for path in (Path(base.__file__),Path(runtime.__file__),Path(__file__).with_name("skin_verify.py")):
        ast.parse(path.read_text(encoding="utf-8"))
    out=ROOT/"build/skin_runtime_v2";out.mkdir(exist_ok=True)
    checks=0;failures=[];cases=[]
    with tempfile.TemporaryDirectory(prefix="assembly_negative_",dir=out) as temp:
        temp=Path(temp)
        for case in CASES:
            contract,model_path,inventory=case[:3]
            binding=case[3] if len(case)>3 else 0
            extra={"source_contract":ROOT/CASES[0][0]} if "PreservedSkinExpressions" in contract or "FaceUnion" in contract else {}
            if "FaceUnionMouthRestored" in contract:
                extra["pending_name"]="Costume_HaloArcherM_FaceUnionMouthBindingSkinSchema2Candidate"
            if "FaceUnionSkin" in contract:
                extra["pending_name"]="Costume_HaloArcherM_FaceUnion"+("Binding" if binding else "")+"SkinSchema2Candidate"
            if binding:
                extra["binding_schema"]=binding
                if "FaceUnion" not in contract: extra["pending_name"]="Costume_NeutralWarriorF_BindingSkinSchema2Candidate"
            data,points=runtime.prepare(ROOT/contract,model_path,**extra)
            snapshot,fit=base.validate_inspection(ROOT/inventory,data,points)
            data=skin_binding_schema.configure(data,snapshot)
            actual=json.loads((ROOT/inventory).read_text(encoding="utf-8"));checks+=1
            raw_import="path" in actual
            world_key="world" if raw_import else "world_cframe"
            cases.append({"data":data,"snap":snapshot,"fit":fit})
            def refuse(label,edit):
                nonlocal checks
                changed=copy.deepcopy(actual);edit(changed)
                path=temp/"inventory.json";path.write_text(json.dumps(changed),encoding="utf-8")
                try: base.validate_inspection(path,data,points)
                except (base.RigError,ValueError,KeyError,TypeError): checks+=1
                else: failures.append(data["name"]+" "+label)
            refuse("wrong source hash",lambda d:d.update(**{("source_sha256" if raw_import else "source_file_sha256"):"0"*64}))
            refuse("foreign source path",lambda d:d.update(**({"path":"ServerStorage.Other."+data["name"]} if raw_import else {"model_path":["ServerStorage","Other",data["name"]]})))
            refuse("wrong name",lambda d:d.update(name="Costume_Other"))
            refuse("synthetic inventory",lambda d:d.update(synthetic_fixture=True))
            refuse("untrusted script",lambda d:d["nodes"].append({"class":"LocalScript"}) if raw_import else d.update(scripts=1))
            refuse("missing mesh",lambda d:d["meshes"].pop())
            refuse("duplicate mesh",lambda d:d["meshes"].append(copy.deepcopy(d["meshes"][0])))
            for i in range(len(data["bones"])):
                refuse(f"bone {i} displaced",lambda d,i=i:d["bones"][i][world_key].__setitem__(0,d["bones"][i][world_key][0]+.1))
                refuse(f"bone {i} posed",lambda d,i=i:d["bones"][i]["transform"].__setitem__(1,.1))
                refuse(f"bone {i} wrong axes",lambda d,i=i:d["bones"][i][world_key].__setitem__(3,d["bones"][i][world_key][3]+.5))
                refuse(f"bone {i} local mismatch",lambda d,i=i:d["bones"][i]["cframe"].__setitem__(1,d["bones"][i]["cframe"][1]+.1))
                refuse(f"bone {i} lost",lambda d,i=i:d["bones"].pop(i))
                refuse(f"bone {i} foreign path",lambda d,i=i:d["bones"][i].update(path="Workspace.Other."+d["bones"][i]["name"]))
                refuse(f"bone {i} nonfinite",lambda d,i=i:d["bones"][i][world_key].__setitem__(0,float("nan")))
            for i in range(len(data["meshes"])):
                refuse(f"mesh {i} unknown id",lambda d,i=i:d["meshes"][i].update(mesh_id="rbxassetid://0"))
                refuse(f"mesh {i} changed size",lambda d,i=i:d["meshes"][i]["size"].__setitem__(0,d["meshes"][i]["size"][0]*1.1))
                refuse(f"mesh {i} changed pivot",lambda d,i=i:d["meshes"][i]["pivot_offset"].__setitem__(3,.5))
            before=base.sha(ROOT/contract)
            for mode in ("assemble","verify"):
                path=temp/(data["pending_name"]+"_"+mode+".json")
                runtime.write_payload(data,mode,path,snapshot,fit)
                prior=base.sha(path)
                try: runtime.write_payload(data,mode,path,snapshot,fit)
                except base.RigError: checks+=1
                else: failures.append("existing draft overwrite "+mode)
                if base.sha(path)!=prior: failures.append("changed refused output "+mode)
                code=json.loads(path.read_text(encoding="utf-8"))["code"]
                path.with_suffix(".luau").write_text(code,encoding="utf-8")
            if base.sha(ROOT/contract)!=before: failures.append("original contract changed")
        # A package-relative copy proves fresh-checkout preparation uses exact
        # saved runtime bytes instead of stale absolute batch locations.
        package_source=ROOT/CASES[0][0];package=json.loads(package_source.read_text(encoding="utf-8"))
        package_dir=temp/"fresh_package";package_dir.mkdir()
        for key in ("skin_glb","skin_manifest","proxy_plan","proxy_runtime"):
            shutil.copyfile(package_source.parent/package[key],package_dir/package[key])
        copied=package_dir/"package.json";copied.write_text(json.dumps(package),encoding="utf-8")
        runtime.prepare(copied,CASES[0][1]);checks+=1
        original_runtime=json.loads((package_dir/package["proxy_runtime"]).read_text(encoding="utf-8"))
        def refuse_package(label,edit_package=None,edit_runtime=None):
            nonlocal checks
            p=copy.deepcopy(package);r=copy.deepcopy(original_runtime)
            if edit_runtime:
                edit_runtime(r)
                (package_dir/package["proxy_runtime"]).write_text(json.dumps(r),encoding="utf-8")
                p["sha256"]["proxy_runtime"]=base.sha(package_dir/package["proxy_runtime"])
            else:
                shutil.copyfile(package_source.parent/package["proxy_runtime"],package_dir/package["proxy_runtime"])
            if edit_package: edit_package(p)
            copied.write_text(json.dumps(p),encoding="utf-8")
            try: runtime.prepare(copied,CASES[0][1])
            except (base.RigError,ValueError,KeyError,TypeError): checks+=1
            else: failures.append("package "+label)
        refuse_package("outside relative directory",edit_package=lambda p:p.update(proxy_runtime="../outside.json"))
        refuse_package("missing declared runtime",edit_package=lambda p:p.update(proxy_runtime="missing.json"))
        refuse_package("runtime digest mismatch",edit_package=lambda p:p["sha256"].update(proxy_runtime="0"*64))
        refuse_package("different proxy plan",edit_runtime=lambda r:r.update(proxy_plan_sha256="0"*64))
        refuse_package("different original skin",edit_runtime=lambda r:r.update(source_skin_sha256="0"*64))
        refuse_package("lost provenance",edit_runtime=lambda r:r.update(source_rigid_batches_sha_verified=False))
        refuse_package("invalid hip height",edit_runtime=lambda r:r.update(hip_height=float("nan")))
        refuse_package("unknown source frame",edit_runtime=lambda r:r.update(source_frame_policy="guessed"))
        refuse_package("invalid root bounds",edit_runtime=lambda r:r["root"]["size"].__setitem__(0,0))
        refuse_package("invalid proxy bounds",edit_runtime=lambda r:r["parts"][0]["size"].__setitem__(0,0))
        refuse_package("proxy frame mismatch",edit_runtime=lambda r:r["parts"][0]["cframe"].__setitem__(0,1))
        refuse_package("duplicate motor",edit_runtime=lambda r:r["joints"].__setitem__(0,copy.deepcopy(r["joints"][1])))
        refuse_package("misplaced hinge",edit_runtime=lambda r:r["joints"][0]["C0"].__setitem__(0,1))
        # Policy-only counterfactual: each material mesh hosts its own Bone
        # tree. This is not a native inventory and is never sent to the
        # assembly writer. All local hosts remain connected inside one Model.
        policy_data={"binding_schema":1,"ready":False}
        policy_inventory={"parts":[{"path":["Body"],"name":"Body","class":"MeshPart"},
                                   {"path":["HeadSurface"],"name":"HeadSurface","class":"MeshPart"}],
                          "bones":[{"host_path":["Body"]},{"host_path":["HeadSurface"]}],"synthetic_fixture":True}
        policy=skin_binding_schema.configure(policy_data,policy_inventory)
        if policy["binding"]["anchor_path"]==["Body"] and policy["binding"]["internal_welds"]==1 and policy["binding"]["root_welds"]==1 and len(policy["binding"]["bone_host_paths"])==2:
            checks+=1
        else: failures.append("per-mesh Bone-host internal binding policy")
        if policy_data=={"binding_schema":1,"ready":False} and policy_inventory["synthetic_fixture"] is True:
            checks+=1
        else: failures.append("policy fixture inputs modified")
        def refuse_binding(label,edit):
            nonlocal checks
            changed=copy.deepcopy(policy_inventory);edit(changed)
            try: skin_binding_schema.configure(policy_data,changed)
            except (base.RigError,ValueError,KeyError,TypeError): checks+=1
            else: failures.append("binding policy "+label)
        refuse_binding("missing actual Bone host",lambda d:d["bones"][0].update(host_path=["ForeignHost"]))
        refuse_binding("duplicate physical path",lambda d:d["parts"].append(copy.deepcopy(d["parts"][0])))
        refuse_binding("non-array physical path",lambda d:d["parts"][0].update(path="Body"))
        refuse_binding("wrong actual path leaf",lambda d:d["parts"][0].update(path=["ForeignBody"]))
        refuse_binding("unexpected physical class",lambda d:d["parts"][0].update(**{"class":"Model"}))
        refuse_binding("no actual Bone tree",lambda d:d.update(bones=[]))
        # Execute the same matcher code, with only JSON transport substituted.
        prefix=Path(__file__).with_name("skin_runtime_fixture.luau").read_text(encoding="utf-8").split("local jsonMap={}",1)[0]
        matcher=skin_binding_schema.verify(VERIFY).replace('return HttpService:JSONEncode({schema=2',skin_expression_schema.VERIFY+'\nreturn HttpService:JSONEncode({schema=2')
        # Counterfactual three-surface fixtures exercise references and false
        # markers only. They are never passed to the actual-inspection writer.
        for case in list(cases):
            if case["data"].get("expression") or case["data"].get("binding"): continue
            altered=copy.deepcopy(case);data,snap=altered["data"],altered["snap"]
            name=data["name"];folder=ROOT/"art/models/costume/expressions"/name;manifest_path=folder/"skin_expressions_manifest.json"
            manifest=json.loads(manifest_path.read_text(encoding="utf-8"));sidecar=ROOT/Path(manifest["skin_asset"]).with_suffix(".skin.json")
            proxy=ROOT/"build/manual_partition_candidates/NeutralWarriorF_v3/r15_front/joints.json" if name=="Costume_NeutralWarriorF" else None
            blueprint=runtime.skin_schema.load(sidecar,proxy)
            data["expression"]=skin_expression_schema.load(manifest_path,blueprint)
            data["skin_sha256"]=manifest["skin_sha256"];snap["source_file_sha256"]=data["skin_sha256"];snap["skin_sha256"]=data["skin_sha256"]
            data["pending_name"]=name+"_ExpressionsSkinSchema2Candidate"
            for entry in snap["parts"]+snap["meshes"]:
                if entry["name"]=="CostumeSkinHead": entry["name"]="HeadBase";entry["path"][-1]="HeadBase"
            for entry in data["meshes"]:
                if entry["name"]=="CostumeSkinHead": entry["name"]="HeadBase"
            part=copy.deepcopy(next(p for p in snap["parts"] if p["name"]=="HeadBase"));part["name"]="FaceExpression";part["path"][-1]="FaceExpression";snap["parts"].append(part)
            mesh=copy.deepcopy(next(p for p in snap["meshes"] if p["name"]=="HeadBase"));mesh["name"]="FaceExpression";mesh["path"][-1]="FaceExpression";mesh["mesh_id"]="rbxassetid://123456";snap["meshes"].append(mesh)
            geometry=copy.deepcopy(next(p for p in data["meshes"] if p["name"]=="HeadBase"));geometry["name"]="FaceExpression";data["meshes"].append(geometry)
            for entries in (snap["parts"],snap["meshes"],snap["bones"]): entries.sort(key=lambda p:"\0".join(p["path"]))
            altered["counterfactual_expression_fixture"]=True;cases.append(altered)
        code=base.COMMON.replace("__DATA__",'"DATA"')+matcher.replace("__SNAP__",'"SNAP"').replace("__FIT__",'"FIT"')
        harness=out/"schema2_matcher_offline.luau"
        harness.write_text("local ACTUAL_CASES="+lua(cases)+"\nlocal VERIFY_SOURCE=[====["+code+"]====]\n"+prefix+Path(__file__).with_name("skin_verify_fixture.luau").read_text(encoding="utf-8"),encoding="utf-8")
        cli=ROOT/"build/luau_cli_0_741"
        if not (cli/"luau.exe").is_file(): raise SystemExit("Installed Luau CLI is required; no download is attempted")
        compile_files=[str(p) for p in temp.glob("*.luau")]+[str(harness)]
        compiled=subprocess.run([str(cli/"luau-compile.exe"),*compile_files],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,timeout=60)
        executed=subprocess.run([str(cli/"luau.exe"),str(harness)],capture_output=True,timeout=60) if not compiled.returncode else None
        stdout=executed.stdout.decode("utf-8",errors="replace") if executed else ""
        stderr=compiled.stderr.decode("utf-8",errors="replace")+(executed.stderr.decode("utf-8",errors="replace") if executed else "")
        print(stdout,end="");print(stderr,end="")
        match=re.search(r"SKIN_VERIFY_SUMMARY checks=(\d+) failed=(\d+) Studio/API calls=0",stdout)
        report={"python_checks":checks,"python_failures":failures,"matcher_checks":int(match[1]) if match else 0,"matcher_failed":int(match[2]) if match else None,
                "compiler_exit":compiled.returncode,"matcher_exit":executed.returncode if executed else None,
                "real_import_cases":[{"name":c["data"]["name"],"bones":len(c["data"]["bones"]),"fit":c["fit"]} for c in cases if not c.get("counterfactual_expression_fixture")],
                "counterfactual_expression_fixtures":sum(bool(c.get("counterfactual_expression_fixture")) for c in cases),
                "matcher_source_sha256":base.sha(Path(__file__).with_name("skin_verify.py")),"studio_calls":0,"api_calls":0,
                "source_modified":False,"live_matcher_pass_claimed":False,"promotion":False}
        (out/"assembly_offline_qa.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
        print(json.dumps(report))
        return int(bool(failures) or compiled.returncode!=0 or not executed or executed.returncode!=0 or not match or int(match[2])!=0)


if __name__=="__main__": raise SystemExit(main())
