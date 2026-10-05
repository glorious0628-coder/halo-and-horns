# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Exercise the HWF-only winding adapter without editing any source asset."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
from pathlib import Path
import copy
import json
import subprocess
import tempfile
import sys

import skin_schema
import skin_expression_schema as schema
import skin_mouth_winding_proof as proof
import skin_runtime_v2 as runtime
from constraints import RigError

ROOT=Path(__file__).resolve().parents[2]


def main():
    folder=proof.FOLDER;path=folder/"face_union_mouth_winding_manifest_v1.json"
    manifest=json.loads(path.read_text(encoding="utf-8"));glb=ROOT/manifest["skin_asset"]
    sidecar_path=glb.with_suffix(".skin.json");sidecar=json.loads(sidecar_path.read_text(encoding="utf-8"))
    output=ROOT/"build/remaining_16_winding_gate_20261004";output.mkdir(exist_ok=True)
    inputs=[p for p in folder.iterdir() if p.is_file() and (p.suffix in (".glb",".json",".png"))]
    before={str(p):skin_schema.sha(p) for p in inputs}
    checks=0;failures=[];rejected=[]
    def check(value,label):
        nonlocal checks
        checks+=1
        if not value:failures.append(label)
    def reject(label,operation):
        try:operation()
        except (RigError,ValueError,KeyError,TypeError,IndexError,OSError) as error:
            check(True,label);rejected.append({"case":label,"reason":str(error)})
        else:check(False,"accepted "+label)
    blueprint=skin_schema.load(sidecar_path);result=schema.load(path,blueprint)
    for value,label in ((result["validation_kind"]==proof.KIND,"separate winding kind"),
        (result["mouth_changed_original_vertices"]==108,"exact 108 mouth vertices"),
        (result["mouth_winding_original_triangles"]==21,"exact 21 mouth triangle orders"),
        (result["selected_original_triangles"]==300 and result["added_face_vertices"]==0,"same 300 original face triangles"),
        (blueprint["unique_bones"]==23 and blueprint["original_bones_claimed"] is True,"original 23 bones with unchanged binds"),
        (result["original_position_normal_values_preserved"] is False and result["original_joint_weight_values_preserved"] is True,"limited exception accurate"),
        (result["original_oriented_triangle_indices_preserved"] is False and result["original_triangle_vertex_sets_preserved"] is True,"same original three vertices"),
        (result["runtime_validated"] is False and blueprint["rig_ready_for_game"] is False,"offline proof cannot promote")):
        check(value,label)
    for key,value in (("avatar","Costume_HornsWarriorF"),("validation_kind",skin_schema.MOUTH_KIND),
        ("candidate_variant","original_triangle_union_v1"),("skin_sha256","0"*64),
        ("selected_original_face_triangles",299),("new_mouth_cap_vertices",1),("changed_original_mouth_triangles",20),
        ("original_geometry_preserved",True),("original_position_normal_values_preserved",True),
        ("original_joint_weight_values_preserved",False),("original_oriented_triangle_indices_preserved",True),
        ("original_triangle_vertex_sets_preserved",False),("mouth_restoration_ledger_sha256","0"*64),
        ("mouth_winding_ledger_sha256","0"*64),("parent_mouth_sha256","0"*64),("ready",True),("roblox_uploaded",True)):
        bad=copy.deepcopy(manifest);bad[key]=value
        reject("semantic manifest "+key,lambda bad=bad:proof.selection(bad,glb,sidecar_path,sidecar))
    for key,value in (("expression_validation_kind",skin_schema.MOUTH_KIND),("expression_original_mouth_pn_restored",False),
        ("expression_original_mouth_winding_corrected",False),("expression_mouth_ledger_sha256","0"*64),
        ("expression_mouth_winding_ledger_sha256","0"*64)):
        bad=copy.deepcopy(sidecar);bad[key]=value
        reject("semantic sidecar "+key,lambda bad=bad:proof.selection(manifest,glb,sidecar_path,bad))
        bad=copy.deepcopy(blueprint);bad[key]=value
        reject("blueprint "+key,lambda bad=bad:schema.load(path,bad))
    sys.path.insert(0,str(ROOT/"tools/costume_expressions"))
    from finalize_skin_assets import inspect
    from validate_mouth_restoration import check as pn_check
    reject("canonical P/N and oriented-index gate stays exact",lambda:inspect(glb,ROOT/manifest["prepare_report"]))
    reject("PN-only validator cannot grant index winding",lambda:pn_check(glb))
    parent=ROOT/manifest["parent_mouth_asset"]
    reject("PN-only HWF parent not independently selected",lambda:skin_schema.load(parent.with_suffix(".skin.json")))
    old=folder/"face_union_manifest.json";old_glb=ROOT/json.loads(old.read_text(encoding="utf-8"))["skin_asset"]
    reject("geometry-only baseline never becomes a playable expression",lambda:schema.load(old,skin_schema.load(old_glb.with_suffix(".skin.json"))))
    with tempfile.TemporaryDirectory(prefix="winding_adapter_",dir=output) as temporary:
        temporary=Path(temporary)
        data,_=runtime.prepare(sidecar_path,"ServerStorage/CostumeExpressionSkinImports_FaceUnionMouthWinding_v1/"+proof.AVATAR,
            pending_name=proof.AVATAR+"_FaceUnionMouthWindingBindingSkinSchema2Candidate",binding_schema=1,
            source_contract=ROOT/"art/models/costume/prepared/skin/Costume_HaloWarriorF_preserved_v1/package.json")
        check(data["binding_schema"]==1 and len(data["meshes"])==3 and data["ready"] is False,"actual binding inspection still required")
        payload=temporary/"inspect.json";runtime.write_payload(data,"inspect",payload)
        code=json.loads(payload.read_text(encoding="utf-8"))["code"]
        # Compile templates as syntax only; empty inventories are never sent
        # to Studio and are not claimed as an actual assembly validation.
        snippets=[code,runtime.base.COMMON.replace("__DATA__","{}")+runtime.assembly().replace("__SNAP__","{}").replace("__FIT__","{}"),
            runtime.base.COMMON.replace("__DATA__","{}")+runtime.skin_expression_schema.VERIFY]
        for index,text in enumerate(snippets):
            luau=temporary/(str(index)+".luau");luau.write_text(text,encoding="utf-8")
            done=subprocess.run([str(ROOT/"build/luau_cli_0_741/luau-compile.exe"),str(luau)],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
            check(done.returncode==0,"local Luau syntax "+str(index)+": "+done.stderr.decode("utf-8","replace"))
    for file,expected in before.items():check(skin_schema.sha(file)==expected,"source/evidence preserved "+file)
    record={"checks":checks,"failures":failures,"rejected":rejected,"glb_sha256":proof.RULE["glb_sha"],"mouth_vertices":108,
        "winding_original_triangles":21,"source_unchanged":True,"canonical_exact_gate_preserved":True,
        "actual_engine_claimed":False,"ready":False,"studio_calls":0,"api_calls":0}
    (output/"mouth_winding_adapter_offline_qa.json").write_text(json.dumps(record,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({k:v for k,v in record.items() if k!="rejected"}));return int(bool(failures))


if __name__=="__main__":raise SystemExit(main())
