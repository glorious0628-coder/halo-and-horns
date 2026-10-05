# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Exercise the explicit mouth-only exception and preserve every normal gate.

Only disposable build copies are changed. No art/source rewrites, Studio,
uploads, paid calls, production readiness or runtime motion claims.
"""
from __future__ import annotations

raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import copy
import argparse
import json
from pathlib import Path
import struct
import sys
import tempfile

import skin_schema
import skin_expression_schema as schema
import skin_face_union_proof as proof
from glb_io import read_glb,write_glb

ROOT=Path(__file__).resolve().parents[2]
FOLDER=ROOT/"art/models/costume/expressions/Costume_HaloArcherM"
OUTPUT=ROOT/"build/skin_runtime_v2/face_union_mouth_v1"


def main(avatar="Costume_HaloArcherM",proxy_plan=None):
    global FOLDER,OUTPUT
    rule=proof.MOUTH_RULES[avatar]
    FOLDER=ROOT/"art/models/costume/expressions"/avatar
    OUTPUT=ROOT/"build/skin_runtime_v2"/("face_union_mouth_v1" if avatar=="Costume_HaloArcherM" else "face_union_mouth_"+avatar+"_v1")
    OUTPUT.mkdir(parents=True,exist_ok=True)
    path=FOLDER/"face_union_mouth_manifest_v1.json"
    manifest=json.loads(path.read_text(encoding="utf-8"));glb=ROOT/manifest["skin_asset"]
    sidecar_path=glb.with_suffix(".skin.json")
    sidecar=json.loads(sidecar_path.read_text(encoding="utf-8"))
    blueprint=skin_schema.load(sidecar_path,proxy_plan)
    result=schema.load(path,blueprint)
    document,binary,_=read_glb(glb)
    report=json.loads(glb.with_suffix(".json").read_text(encoding="utf-8"))
    ledger_path=ROOT/manifest["mouth_restoration_ledger"]
    ledger=json.loads(ledger_path.read_text(encoding="utf-8"))
    source_paths={path,glb,sidecar_path,glb.with_suffix(".json"),ledger_path,
                  ROOT/manifest["validation_report"],ROOT/manifest["uv_texture_compatibility"],
                  ROOT/manifest["original_union_baseline"],FOLDER/"face_union_mouth_runtime_contract_v1.json",
                  FOLDER/"skin_expressions_manifest.json",FOLDER/"face_union_provenance.json",
                  FOLDER/(avatar+"_FaceUnionSkin_v1.glb")}
    before={str(p):skin_schema.sha(p) for p in source_paths}
    checks=0;failures=[];rejections=[]
    def check(value,label):
        nonlocal checks
        if value:checks+=1
        else:failures.append(label)
    for condition,label in (
        (result["validation_kind"]==proof.MOUTH_KIND,"separate kind only"),
        (result["mouth_changed_original_vertices"]==rule["vertices"],"exact selected original mouth vertices"),
        (result["selected_original_triangles"]==rule["faces"],"all selected original faces"),
        (result["added_face_vertices"]==0,"no new surface vertices"),
        (result["original_position_normal_values_preserved"] is False,"P/N exception not disguised as exact preservation"),
        (result["original_joint_weight_values_preserved"] is True,"weights and joint slots remain exact"),
        (result["actual_texture_ids_reused"] is False,"texture IDs never inferred"),
        (blueprint["unique_bones"]==(15 if blueprint["rig_origin"]=="inferred_manual_candidate" else 23),"all explicitly identified source bones retained"),
        (blueprint["rig_ready_for_game"] is False and result["runtime_validated"] is False,"not promoted by an offline proof"),
        (result["manifest_sha256"]==skin_schema.sha(path),"current mouth manifest SHA, not baseline SHA"),
        (result["validation_sha256"]==skin_schema.sha(ROOT/manifest["validation_report"]),"current mouth validation SHA"),
        (result["uv_compatibility_sha256"]==manifest["uv_texture_compatibility_sha256"],"current explicit UV correspondence SHA"),
    ):check(condition,label)
    sys.path.insert(0,str(ROOT/"tools/costume_expressions"))
    from validate_mouth_restoration import check as strict
    from finalize_skin_assets import inspect as original_inspect
    with tempfile.TemporaryDirectory(prefix="mouth_schema_negative_",dir=OUTPUT) as temporary:
        temp=Path(temporary).resolve();temp.relative_to(OUTPUT)
        def reject(label,operation):
            nonlocal checks
            try:operation()
            except (skin_schema.RigError,ValueError,KeyError,TypeError,IndexError) as error:
                checks+=1;rejections.append({"case":label,"reason":str(error)})
            else:failures.append("accepted "+label)
        def bad_manifest(label,edit):
            changed=copy.deepcopy(manifest);edit(changed)
            # Even resealed manifest metadata does not replace the approved
            # selection/runtime contract or permit global P/N changes.
            target=temp/"face_union_mouth_manifest_v1.json"
            target.write_text(json.dumps(changed),encoding="utf-8")
            b=copy.deepcopy(blueprint);b["expression_manifest_sha256"]=skin_schema.sha(target)
            reject(label,lambda:schema.load(target,b))
        for label,edit in (
            ("unknown exception kind",lambda d:d.update(validation_kind="arbitrary_PN_allowed")),
            ("canonical variant labeled as mouth",lambda d:d.update(candidate_variant="original_triangle_union_v1")),
            ("wrong selected GLB SHA",lambda d:d.update(skin_sha256="0"*64)),
            ("mouth exception falsely exact P/N",lambda d:d.update(original_position_normal_values_preserved=True)),
            ("geometry exception falsely exact geometry",lambda d:d.update(original_geometry_preserved=True)),
            ("changed weights allowed",lambda d:d.update(original_joint_weight_values_preserved=False)),
            ("unsealed mouth ledger",lambda d:d.update(mouth_restoration_ledger_sha256="0"*64)),
            ("missing original face",lambda d:d.update(selected_original_face_triangles=437)),
            ("new cap vertex",lambda d:d.update(new_mouth_cap_vertices=1)),
            ("foreign avatar",lambda d:d.update(avatar="Costume_HaloWarriorM")),
            ("premature offline ready",lambda d:d.update(ready=True)),
            ("premature runtime validated",lambda d:d.update(runtime_validated=True)),
            ("old canonical validation substituted",lambda d:d.update(validation_report=str(FOLDER/"skin_validation.json"))),
            ("original face proof skipped",lambda d:d.update(original_face_provenance_sha256="0"*64)),
        ):bad_manifest(label,edit)
        # Exercise semantic selection checks directly against the current
        # canonical path, independently of a copied-manifest path rejection.
        def semantic_manifest(label,edit):
            changed=copy.deepcopy(manifest);edit(changed)
            reject(label,lambda:proof.mouth_selection(changed,glb,sidecar_path,sidecar))
        for label,edit in (
            ("semantic wrong mouth kind",lambda d:d.update(validation_kind="other")),
            ("semantic wrong variant",lambda d:d.update(candidate_variant="original_triangle_union_v1")),
            ("semantic wrong avatar",lambda d:d.update(avatar="Costume_HornsArcherM")),
            ("semantic false exact geometry",lambda d:d.update(original_geometry_preserved=True)),
            ("semantic false exact P/N",lambda d:d.update(original_position_normal_values_preserved=True)),
            ("semantic wrong immutable ledger SHA",lambda d:d.update(mouth_restoration_ledger_sha256="0"*64)),
            ("semantic missing original face",lambda d:d.update(selected_original_face_triangles=437)),
            ("semantic invented new vertex",lambda d:d.update(new_mouth_cap_vertices=1)),
            ("semantic changed original weights",lambda d:d.update(original_joint_weight_values_preserved=False)),
        ):semantic_manifest(label,edit)
        for label,edit in (
            ("missing explicit blueprint exception",lambda d:d.update(expression_validation_kind=None)),
            ("unrelated exception blueprint",lambda d:d.update(expression_validation_kind="foreign")),
            ("wrong blueprint ledger SHA",lambda d:d.update(expression_mouth_ledger_sha256="0"*64)),
            ("unselected blueprint restoration",lambda d:d.update(expression_original_mouth_pn_restored=False)),
        ):
            changed=copy.deepcopy(blueprint);edit(changed)
            reject(label,lambda changed=changed:schema.load(path,changed))
        # Strict producer checks real bytes with a resealed copied report and
        # ledger. Their topology/UV/JW/P/N-scope rejection must remain real.
        def mutate_glb(label,edit):
            d=copy.deepcopy(document);b=bytearray(binary);l=copy.deepcopy(ledger);r=copy.deepcopy(report)
            edit(d,b,l,r)
            target=temp/"mutated.glb";lp=temp/"mutated.mouth.json"
            write_glb(target,d,bytes(b));lp.write_text(json.dumps(l),encoding="utf-8")
            r.update(glb=str(target),sha256=skin_schema.sha(target),mouth_geometry_restoration_ledger=str(lp),mouth_geometry_restoration_ledger_sha256=skin_schema.sha(lp))
            target.with_suffix(".json").write_text(json.dumps(r),encoding="utf-8")
            reject(label,lambda:strict(target))
        def alter(d,b,mesh,key,vertex=0):
            a=d["accessors"][d["meshes"][mesh]["primitives"][0]["attributes"][key]];v=d["bufferViews"][a["bufferView"]]
            dims={"VEC2":2,"VEC3":3,"VEC4":4}[a["type"]]
            fmt={5121:"B",5123:"H",5126:"f"}[a["componentType"]];size=struct.calcsize(fmt)
            offset=v.get("byteOffset",0)+a.get("byteOffset",0)+vertex*v.get("byteStride",size*dims)
            old=struct.unpack_from("<"+fmt,b,offset)[0]
            value=old+.01 if fmt=="f" else (old+1)%23
            struct.pack_into("<"+fmt,b,offset,value)
        changed_indices={r["vertex"] for r in ledger["changed_vertices"]}
        count=document["accessors"][document["meshes"][1]["primitives"][0]["attributes"]["POSITION"]]["count"]
        outside=next(i for i in range(count) if i not in changed_indices)
        for mesh,field,index,label in ((1,"POSITION",outside,"actual non-mouth P"),(1,"NORMAL",outside,"actual non-mouth N"),
                                     (0,"POSITION",0,"actual Body P"),(2,"TEXCOORD_0",0,"actual Face UV"),
                                     (1,"JOINTS_0",0,"actual original joint slot"),(1,"WEIGHTS_0",0,"actual original weights")):
            mutate_glb(label,lambda d,b,l,r,mesh=mesh,field=field,index=index:alter(d,b,mesh,field,index))
        mutate_glb("actual Bone rename",lambda d,b,l,r:d["nodes"][d["skins"][0]["joints"][0]].update(name="ForeignBone"))
        def index_edit(d,b,l,r):
            a=d["accessors"][d["meshes"][2]["primitives"][0]["indices"]];v=d["bufferViews"][a["bufferView"]]
            b[v.get("byteOffset",0)+a.get("byteOffset",0)]^=1
        mutate_glb("actual original oriented triangle index",index_edit)
        def image_edit(d,b,l,r):b[d["bufferViews"][d["images"][0]["bufferView"]].get("byteOffset",0)+20]^=1
        mutate_glb("actual Body PNG byte",image_edit)
        mutate_glb("missing shared mouth copy",lambda d,b,l,r:l["changed_vertices"].pop())
        mutate_glb("false mouth original vertex provenance",lambda d,b,l,r:l["changed_vertices"][0]["old_position"].__setitem__(0,l["changed_vertices"][0]["old_position"][0]+.01))
        mutate_glb("mouth region exceeds selected profile",lambda d,b,l,r:l["mouth_radii_screen"].__setitem__(0,1000))
        def coherent_bad_curve(d,b,l,r):
            from glb_io import accessor_values
            row=l["changed_vertices"][0];alter(d,b,1,"POSITION",row["vertex"])
            row["new_position"]=list(accessor_values(d,b,d["meshes"][1]["primitives"][0]["attributes"]["POSITION"])[row["vertex"]])
        mutate_glb("resealed out-of-curve mouth P",coherent_bad_curve)
        mutate_glb("false producer promotion",lambda d,b,l,r:r.update(runtime_validated=True))
        # A normal producer inspector still rejects even the valid mouth
        # candidate. A flag cannot enable the exception on that entry point.
        reject("normal exact P/N inspector still rejects valid exception",lambda:original_inspect(glb,ROOT/manifest["prepare_report"]))
        oldpath=FOLDER/"face_union_manifest.json"
        old=json.loads(oldpath.read_text(encoding="utf-8"));oldglb=ROOT/old["skin_asset"]
        oldblueprint=skin_schema.load(oldglb.with_suffix(".skin.json"),proxy_plan)
        if rule["reference_kind"]=="geometry_comparison_only":
            reject("unapproved geometry-only baseline is not a playable expression candidate",lambda:schema.load(oldpath,oldblueprint))
        else:
            oldresult=schema.load(oldpath,oldblueprint)
            check(oldresult["candidate_variant"]=="original_triangle_union_v1" and "mouth_restoration_schema" not in oldresult,"original exact union remains a separate valid path")
        bad=copy.deepcopy(oldblueprint);bad["expression_validation_kind"]=proof.MOUTH_KIND
        # Direct original provenance verifier remains exact and does not even
        # consume a mouth flag from a blueprint.
        from finalize_skin_assets import inspect
        checked,oldreport,olddoc,oldbin=inspect(oldglb,ROOT/old["prepare_report"])
        # Its ordinary provenance validator still rejects a foreign geometry
        # variant regardless of an unrelated blueprint mouth flag.
        altered=copy.deepcopy(old);altered["candidate_variant"]=proof.MOUTH_VARIANT
        reject("old union cannot inherit mouth flag",lambda:proof.verify(altered,bad,checked,oldreport,olddoc,oldbin,ROOT/old["prepare_report"],schema.workspace_file))
    for source,expected in before.items():check(skin_schema.sha(source)==expected,"original source/evidence changed: "+source)
    result={"checks":checks,"failures":failures,"rejected":rejections,"avatar":avatar,"skin_sha256":rule["glb_sha"],
            "original_triangles":rule["faces"],"mouth_changed_vertices":rule["vertices"],"new_vertices":0,"source_unchanged":True,
            "canonical_exact_pn_gate_preserved":True,"studio_calls":0,"api_calls":0,"ready":False,"runtime_motion_claimed":False}
    (OUTPUT/"mouth_expression_offline_qa.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({k:v for k,v in result.items() if k!="rejected"}))
    return int(bool(failures))


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--avatar",choices=tuple(proof.MOUTH_RULES),default="Costume_HaloArcherM")
    parser.add_argument("--proxy-plan",type=Path)
    args=parser.parse_args()
    raise SystemExit(main(args.avatar,args.proxy_plan))
