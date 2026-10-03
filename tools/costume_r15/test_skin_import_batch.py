"""Exercise reviewed batch preparation with saved native evidence, offline only.

The real HaloArcherM inventory is copied into a temporary local fixture. Other
costumes have no native evidence in this fixture and must receive inspect-only
payloads. Altered inventories must never authorize assembly or Ready promotion.
"""
from __future__ import annotations

import ast
import contextlib
import copy
import io
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

import skin_import_batch as batch
import skin_runtime as base
from constraints import RigError

ROOT=Path(__file__).resolve().parents[2]
NAMES=["HaloArcherM","HaloWarriorM","NeutralWarriorF","NeutralArcherM","HaloArcherF","HornsArcherF"]


def main():
    output=ROOT/"build/skin_runtime_v2";output.mkdir(parents=True,exist_ok=True)
    ast.parse(Path(batch.__file__).read_text(encoding="utf-8"))
    checks=0;failures=[]

    def check(value,label):
        nonlocal checks
        checks+=1
        if not value: failures.append(label)

    def refused(callback,label):
        nonlocal checks
        try: callback()
        except (RigError,ValueError,OSError,KeyError,TypeError): checks+=1
        else: failures.append(label)

    with tempfile.TemporaryDirectory(prefix="safe_batch_offline_",dir=output) as folder:
        folder=Path(folder);native=folder/"native";source=ROOT/"build/costume_skin_expression_imports/Costume_HaloArcherM/actual_imports.json"
        inventory=native/"Costume_HaloArcherM/actual_imports.json";inventory.parent.mkdir(parents=True)
        shutil.copyfile(source,inventory)
        recorded=json.loads(inventory.read_text(encoding="utf-8"))
        fresh=folder/"batch"
        with contextlib.redirect_stdout(io.StringIO()):
            exit_code=batch.main(["--names",*NAMES,"--actual-dir",str(native),"--output-dir",str(fresh)])
        result=json.loads((fresh/"index.json").read_text(encoding="utf-8"))
        check(exit_code==0 and result["count"]==6,"six reviewed inputs prepare successfully")
        check(result["studio_calls"]==result["api_calls"]==result["uploads"]==result["ledger_writes"]==0,"preparation has no external side effects")
        check(result["source_modified"] is False and result["promotion"] is False,"no promotion or source edit claims")
        for row in result["costumes"]:
            name=row["name"];destination=fresh/name
            check(row["bone_count"]==(15 if name in batch.MANUAL else 23) and row["surface_count"]==3,"exact whole skeleton and surface count "+name)
            check(row["maximum_assets"]<=10 and row["ready"] is False and row["runtime_validated"] is False,"unpromoted bounded import "+name)
            check(row["planned_storage_path"]=="ServerStorage/CostumeExpressionSkinImports/"+name and row["pending_name"]==name+"_ExpressionsSkinSchema2Candidate","exact source and separate Pending path "+name)
            check((destination/"inspect.json").is_file(),"inspector exists "+name)
            if name=="Costume_HaloArcherM":
                check(row["status"]=="exact_actual_prepared" and row["actual_inventory_sha256"]==base.sha(inventory),"only real evidence authorizes payload creation")
                check(row["actual_fit"]["native_bounds_policies"]["FaceExpression"]==["referenced_triangles"],"actual native face bounds select the measured triangle policy")
                check((destination/"assemble.json").is_file() and (destination/"verify.json").is_file(),"real native evidence creates guarded assembly and matcher")
            else:
                check(row["status"]=="waiting_actual" and not (destination/"assemble.json").exists() and not (destination/"verify.json").exists(),"missing native evidence never creates assembly "+name)

        before={p.relative_to(fresh).as_posix():base.sha(p) for p in fresh.rglob("*.json")}
        refused(lambda:batch.main(["--names",*NAMES,"--output-dir",str(fresh)]),"historical output overwrite refusal")
        check(before=={p.relative_to(fresh).as_posix():base.sha(p) for p in fresh.rglob("*.json")},"refused historical output remains exact")
        refused(lambda:batch.main(["--names","HaloArcherM","HaloArcherM","--output-dir",str(folder/"duplicate")]),"duplicate costumes refusal")
        check(not (folder/"duplicate").exists(),"duplicate refusal writes no directory")
        refused(lambda:batch.main(["--names","../HaloArcherM","--output-dir",str(folder/"foreign_name")]),"unknown/path-shaped costume refusal")
        refused(lambda:batch.main(["--names","HaloArcherM","--output-dir",str(ROOT/"art/forbidden_batch_output")]),"output outside build refusal")
        refused(lambda:batch.main(["--names","HaloArcherM","--actual-dir",str(ROOT/"art"),"--output-dir",str(folder/"foreign_actual")]),"inventory directory outside build refusal")
        refused(lambda:batch.source_inputs(folder/"skin_expressions_manifest.json"),"manifest outside reviewed avatar folder refusal")

        manifest=ROOT/"art/models/costume/expressions/Costume_HaloArcherM/skin_expressions_manifest.json"
        negatives={
            "synthetic":lambda d:d.update(synthetic_fixture=True),
            "wrong_source_hash":lambda d:d.update(source_sha256="0"*64),
            "wrong_storage_path":lambda d:d.update(path="ServerStorage.Other.Costume_HaloArcherM"),
            "unknown_asset_id":lambda d:d["meshes"][0].update(mesh_id="rbxassetid://0"),
            "changed_bone_bind":lambda d:d["bones"][0]["world"].__setitem__(0,d["bones"][0]["world"][0]+.5),
            "untrusted_script":lambda d:d["nodes"].append({"class":"LocalScript"}),
        }
        for label,change in negatives.items():
            poison=copy.deepcopy(recorded);change(poison);inventory.write_text(json.dumps(poison),encoding="utf-8")
            destination=folder/label
            refused(lambda:batch.prepare_manifest(manifest,destination,native),"invalid native evidence refusal "+label)
            check(not (destination/"Costume_HaloArcherM/assemble.json").exists() and not (destination/"Costume_HaloArcherM/verify.json").exists(),"invalid evidence cannot create execution payload "+label)

        # A bad costume must be recorded as refused while independent reviewed
        # inputs still receive only their permitted read-only inspectors.
        poison=copy.deepcopy(recorded);poison["synthetic_fixture"]=True;inventory.write_text(json.dumps(poison),encoding="utf-8")
        mixed=folder/"mixed"
        with contextlib.redirect_stdout(io.StringIO()):
            code=batch.main(["--names","HaloArcherM","HaloWarriorM","--actual-dir",str(native),"--output-dir",str(mixed)])
        rows=json.loads((mixed/"index.json").read_text(encoding="utf-8"))["costumes"]
        check(code==1 and [row["status"] for row in rows]==["refused","waiting_actual"],"refused native evidence does not block independent safe inputs")
        check(not (mixed/"Costume_HaloArcherM/assemble.json").exists(),"refused batch has no actual assembly")

        compiled_files=[]
        for payload in fresh.rglob("*.json"):
            data=json.loads(payload.read_text(encoding="utf-8"))
            if "code" not in data: continue
            check(data.get("datamodel_type")=="Edit","all generated payloads require Edit mode")
            target=payload.with_suffix(".luau");target.write_text(data["code"],encoding="utf-8");compiled_files.append(str(target))
        compiler=ROOT/"build/luau_cli_0_741/luau-compile.exe"
        if not compiler.is_file(): raise RigError("Installed Luau compiler is required; no download is attempted")
        compile_result=subprocess.run([str(compiler),*compiled_files],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,timeout=60)
        check(len(compiled_files)==8 and compile_result.returncode==0,"all six inspectors plus real assembly and matcher compile")
        if compile_result.returncode: failures.append(compile_result.stderr.decode("utf-8",errors="replace"))

    report={"schema":1,"checks":checks,"failed":len(failures),"failures":failures,"compiler_exit":compile_result.returncode,
            "compiled_payloads":len(compiled_files),"saved_actual_cases":1,"waiting_actual_cases":5,"studio_calls":0,"api_calls":0,
            "uploads":0,"ledger_writes":0,"promotion":False,"live_assembly_claimed":False}
    (output/"skin_import_batch_offline_qa.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report,ensure_ascii=False))
    return int(bool(failures))


if __name__=="__main__": raise SystemExit(main())
