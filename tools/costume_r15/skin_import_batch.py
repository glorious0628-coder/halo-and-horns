# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Prepare reviewed skin-expression inspectors and exact actual-match payloads.

No Studio, upload, remote API, ledger writes or Ready promotion. Missing native
inventories are recorded as waiting_actual; no asset ID or Bone frame is guessed.
The root's existing importer/recorder/uploader tools are deliberately untouched.
"""
from __future__ import annotations

raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import json
from pathlib import Path

import skin_runtime as base
import skin_runtime_v2 as runtime
import skin_schema
from constraints import RigError

ROOT=Path(__file__).resolve().parents[2]
MANUAL={"Costume_NeutralWarriorF","Costume_NeutralArcherM","Costume_HaloArcherF","Costume_HornsArcherF"}


def canonical(value):
    name=value if value.startswith("Costume_") else "Costume_"+value
    if name not in skin_schema.NAMES: raise RigError("Only the eighteen approved costume names are permitted")
    return name


def source_inputs(manifest_path):
    manifest_path=Path(manifest_path).resolve()
    manifest_path.relative_to(ROOT/"art/models/costume/expressions")
    manifest=json.loads(manifest_path.read_text(encoding="utf-8"))
    name=canonical(manifest["avatar"])
    if manifest_path.parent.name!=name or manifest_path.name!="skin_expressions_manifest.json": raise RigError("Exact per-costume manifest path is required")
    glb=(ROOT/manifest["skin_asset"]).resolve();glb.relative_to(manifest_path.parent)
    sidecar=glb.with_suffix(".skin.json")
    if type(manifest.get("full_set_maximum_import_assets")) is not int or manifest["full_set_maximum_import_assets"] not in range(1,11): raise RigError("Declared whole-set native import must remain at most ten assets")
    max_assets=manifest["full_set_maximum_import_assets"]
    if name in MANUAL:
        short=name.removeprefix("Costume_")
        proxy=ROOT/"build/manual_partition_candidates"/(short+"_v3")/("r15_front" if "Neutral" in short else "r15")/"joints.json"
        data=json.loads(sidecar.read_text(encoding="utf-8"))
        original=Path(data["original_two_surface_skin"]).with_suffix(".skin.json").resolve()
        original.relative_to(ROOT)
    else:
        proxy=None;matches=[]
        for path in sorted((ROOT/"art/models/costume/prepared/skin").glob(name+"_preserved_*/package.json")):
            package=json.loads(path.read_text(encoding="utf-8"))
            if package.get("sha256",{}).get("skin_glb")==manifest["source_skin_sha256"]: matches.append(path)
        if len(matches)!=1: raise RigError("One exact original two-surface package is required; corrected candidates need their explicit separate contract")
        original=matches[0]
    return name,sidecar,proxy,original,max_assets


def prepare_manifest(manifest_path,output,actual_dir=None):
    name,sidecar,proxy,original,max_assets=source_inputs(manifest_path)
    model_path="ServerStorage/CostumeExpressionSkinImports/"+name
    pending_name=name+"_ExpressionsSkinSchema2Candidate"
    data,points=runtime.prepare(sidecar,model_path,proxy,pending_name,manifest_path,original)
    destination=output/name
    inspector=destination/"inspect.json"
    runtime.write_payload(data,"inspect",inspector)
    result={"name":name,"status":"waiting_actual","skin_sha256":data["skin_sha256"],"original_skin_sha256":data["expression"]["original_skin_sha256"],
            "source_contract":original.relative_to(ROOT).as_posix(),"sidecar":sidecar.relative_to(ROOT).as_posix(),
            "expression_manifest":Path(manifest_path).resolve().relative_to(ROOT).as_posix(),"proxy_override":proxy.relative_to(ROOT).as_posix() if proxy else None,
            "planned_storage_path":model_path,"pending_name":pending_name,"bone_count":len(data["bones"]),"surface_count":len(data["meshes"]),
            "maximum_assets":max_assets,"inspect_payload":inspector.relative_to(ROOT).as_posix(),"runtime_validated":False,"ready":False,"promotion":False}
    actual=actual_dir/name/"actual_imports.json" if actual_dir else None
    if actual and actual.exists() and not actual.is_file(): raise RigError("A recorded native inventory must be a JSON file")
    if actual and actual.is_file():
        snapshot,fit=base.validate_inspection(actual,data,points)
        for mode in ("assemble","verify"):
            target=destination/(mode+".json");runtime.write_payload(data,mode,target,snapshot,fit)
            result[mode+"_payload"]=target.relative_to(ROOT).as_posix()
        result.update(status="exact_actual_prepared",actual_inventory=actual.relative_to(ROOT).as_posix(),actual_inventory_sha256=base.sha(actual),actual_fit=fit)
    return result


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--names",nargs="+",help="Approved exact names; omission discovers current final expression manifests")
    parser.add_argument("--output-dir",required=True,type=Path,help="A new directory below build; never overwrite historical payloads")
    parser.add_argument("--actual-dir",type=Path,help="Root-recorded native import directory; absent inventories remain waiting")
    args=parser.parse_args(argv)
    output=args.output_dir.resolve();output.relative_to(ROOT/"build")
    if output.exists(): raise RigError("Use a fresh output directory; historical/unknown results are never overwritten")
    actual_dir=args.actual_dir.resolve() if args.actual_dir else None
    if actual_dir: actual_dir.relative_to(ROOT/"build")
    if args.names:
        names=[canonical(value) for value in args.names]
        if len(set(names))!=len(names): raise RigError("Duplicate costumes are not permitted")
        manifests=[ROOT/"art/models/costume/expressions"/name/"skin_expressions_manifest.json" for name in names]
    else:
        manifests=sorted((ROOT/"art/models/costume/expressions").glob("Costume_*/skin_expressions_manifest.json"))
    if not manifests: raise RigError("No reviewed final skin-expression manifests exist")
    # Reserve the batch before writing any per-costume payload. Two independent
    # runs cannot silently share a historical batch directory.
    output.mkdir(parents=True,exist_ok=False)
    results=[]
    for manifest in manifests:
        if not manifest.is_file(): results.append({"name":manifest.parent.name,"status":"waiting_local_manifest","ready":False});continue
        try: results.append(prepare_manifest(manifest,output,actual_dir))
        except (RigError,KeyError,ValueError,TypeError,OSError) as error:
            results.append({"name":manifest.parent.name,"status":"refused","reason":str(error),"ready":False,"promotion":False})
    report={"schema":2,"costumes":results,"count":len(results),"studio_calls":0,"api_calls":0,"uploads":0,"ledger_writes":0,"source_modified":False,"promotion":False,
            "policy":"Actual inventory and exact live source are both required; the assembly payload re-checks live source and refuses existing Pending siblings."}
    (output/"index.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    summary={"count":len(results),"actual_prepared":sum(row["status"]=="exact_actual_prepared" for row in results),"waiting_actual":sum(row["status"]=="waiting_actual" for row in results),
             "waiting_local":sum(row["status"]=="waiting_local_manifest" for row in results),"refused":sum(row["status"]=="refused" for row in results),"index":str(output/"index.json"),"studio_calls":0,"api_calls":0,"uploads":0}
    print(json.dumps(summary,ensure_ascii=False))
    return int(summary["refused"]>0)


if __name__=="__main__":
    try: raise SystemExit(main())
    except (RigError,ValueError,OSError) as error: raise SystemExit("skin_import_batch refused: "+str(error))
