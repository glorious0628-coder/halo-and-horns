# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
# Still importable as a library ONLY because live tools import it (tools/monster_import_preflight.py,
# tools/test_weapon_motion.py, GLB audit tools). Never run it directly.
"""Exact HWF-only P/N + original mouth-index winding selection.

Canonical P/N and oriented-index inspectors remain unchanged. This separate
path rechecks their exact original union before the bounded 108-vertex P/N
and 21-triangle winding proofs. No engine readiness or IDs are inferred.
"""
from __future__ import annotations

if __name__ == "__main__":
    raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import json
from pathlib import Path
import sys

from constraints import RigError
from glb_io import read_glb
import skin_schema

KIND="original_connected_mouth_pn_winding_exception_v1"
VARIANT="original_triangle_union_mouth_winding_v1"
AVATAR="Costume_HaloWarriorF"
RULE={
    "glb_sha":"1364e95a2c33145313a9c5c80b550f8668b66f9d01f4a850f933d6001e451d38",
    "sidecar_sha":"6364e4e6024f5b885ab536565490f37d34a720c21b195bdb87654d8c23af1502",
    "manifest_sha":"998101366be50697012e5e187b4e4e859d70a07034f975d863195e061ae8b862",
    "union_sha":"a81ba5413010532d8bb20627cbd19b75e7f19601901896b3967ef412eeda7a6f",
    "parent_sha":"7c5aa47e9b576c611d665422bf291a1b0e009f32742d70a3bd0a68b7efa2cd1a",
    "pn_ledger_sha":"f83fe81cdb7d280d71adee9dd762f459a9c985ab76315fa520352c99d1f9715e",
    "winding_ledger_sha":"7303de6e0c019e85017c128205a72d5ee3bb9080765f097cd257155d243e2abc",
    "faces":300,"vertices":108,"winding_faces":21,"maximum_delta":0.032575,
    "reference_kind":"geometry_comparison_only",
}
FOLDER=skin_schema.ROOT/"art/models/costume/expressions"/AVATAR


def file(value):
    path=Path(value)
    path=(path if path.is_absolute() else skin_schema.ROOT/path).resolve()
    path.relative_to(FOLDER.resolve())
    if not path.is_file():raise RigError("Exact HWF winding evidence is missing")
    return path


def require(value,message):
    if not value:raise RigError(message)


def selection(manifest,glb,sidecar_path,sidecar):
    glb=Path(glb).resolve();sidecar_path=Path(sidecar_path).resolve()
    require(manifest.get("avatar")==AVATAR and manifest.get("validation_kind")==KIND
        and manifest.get("candidate_variant")==VARIANT,"Only the exact reviewed HWF winding variant is selected")
    selected=FOLDER/"face_union_mouth_winding_manifest_v1.json"
    require(file(manifest["skin_asset"])==glb and skin_schema.sha(glb)==RULE["glb_sha"]
        and manifest.get("skin_sha256")==RULE["glb_sha"],"HWF winding GLB SHA changed")
    require(sidecar_path==glb.with_suffix(".skin.json") and skin_schema.sha(sidecar_path)==RULE["sidecar_sha"]
        and file(sidecar["expression_manifest"])==selected and skin_schema.sha(selected)==RULE["manifest_sha"],
        "The separate exact HWF sidecar/manifest is required")
    require(manifest.get("original_triangles_only") is True and manifest.get("selected_original_face_triangles")==RULE["faces"]
        and manifest.get("new_mouth_cap_vertices")==0 and manifest.get("changed_original_mouth_triangles")==RULE["winding_faces"],
        "HWF selected original triangles and zero geometry must stay exact")
    require(manifest.get("original_geometry_preserved") is False and manifest.get("original_position_normal_values_preserved") is False
        and manifest.get("original_joint_weight_values_preserved") is True and manifest.get("original_oriented_triangle_indices_preserved") is False
        and manifest.get("original_triangle_vertex_sets_preserved") is True,"The narrow P/N and winding exception must be stated accurately")
    require(sidecar.get("expression_validation_kind")==KIND and sidecar.get("expression_original_mouth_pn_restored") is True
        and sidecar.get("expression_original_mouth_winding_corrected") is True,"Both HWF exceptions must be explicitly selected")
    ledgers={}
    for prefix,sidekey,pin in (("mouth_restoration","expression_mouth",RULE["pn_ledger_sha"]),
        ("mouth_winding","expression_mouth_winding",RULE["winding_ledger_sha"])):
        ledger=file(manifest[prefix+"_ledger"])
        require(skin_schema.sha(ledger)==pin and manifest.get(prefix+"_ledger_sha256")==pin
            and file(sidecar[sidekey+"_ledger"])==ledger and sidecar.get(sidekey+"_ledger_sha256")==pin,
            "HWF exact "+prefix+" ledger changed")
        ledgers[prefix]=ledger
    require(file(manifest["parent_mouth_asset"])==FOLDER/(AVATAR+"_FaceUnionMouthRestored_v1.glb")
        and skin_schema.sha(file(manifest["parent_mouth_asset"]))==RULE["parent_sha"]
        and manifest.get("parent_mouth_sha256")==RULE["parent_sha"],"HWF bounded P/N parent changed")
    runtime_path=FOLDER/"face_union_mouth_winding_runtime_contract_v1.json"
    require(skin_schema.sha(runtime_path)=="8c1f24b8b3eacfe4ff681ee7e5750e1e62709d5b964d76685e0b48925ab412e3",
        "The sealed HWF winding runtime contract changed")
    runtime=json.loads(runtime_path.read_text(encoding="utf-8"))
    require(runtime.get("schema")==1 and runtime.get("avatar")==AVATAR and runtime.get("candidate_variant")==VARIANT
        and runtime.get("strict_validation_kind")==KIND,"Exact separate HWF winding runtime contract required")
    for key,sha_key,actual,pin in (("glb","glb_sha256",glb,RULE["glb_sha"]),
        ("sidecar","sidecar_sha256",sidecar_path,RULE["sidecar_sha"]),("manifest","manifest_sha256",selected,RULE["manifest_sha"])):
        require(file(runtime[key])==actual and runtime.get(sha_key)==pin and skin_schema.sha(actual)==pin,
            "HWF runtime reference changed: "+key)
    require(runtime.get("mouth_changed_original_vertices")==RULE["vertices"] and runtime.get("original_face_triangle_count")==RULE["faces"]
        and runtime.get("changed_original_mouth_triangles")==RULE["winding_faces"] and runtime.get("new_vertices")==0
        and runtime.get("new_triangles")==0 and runtime.get("body_uv_jw_original_bones_png_exact") is True,
        "HWF exact P/N/winding scope changed")
    require(file(runtime["mouth_winding_ledger"])==ledgers["mouth_winding"]
        and runtime.get("mouth_winding_ledger_sha256")==RULE["winding_ledger_sha"],"HWF runtime winding ledger changed")
    require(runtime.get("required_skin_runtime_schema")==2 and runtime.get("required_expression_skin_runtime_schema")==1
        and runtime.get("root_weld_and_actual_shared_bone_host_required") is True and runtime.get("actual_import_mesh_ids_required") is True,
        "Actual schema-2 skin/binding verification cannot be bypassed")
    require(all(runtime.get(k) is False and manifest.get(k) is False for k in ("ready","runtime_validated","roblox_uploaded")),
        "Offline HWF proof cannot claim engine promotion")
    return ledgers,runtime_path


def verify(manifest,path,blueprint,validation_path,workspace_file):
    import skin_face_union_proof as union
    sidecar_path=Path(blueprint["skin_glb"]).with_suffix(".skin.json")
    sidecar=json.loads(sidecar_path.read_text(encoding="utf-8"))
    ledgers,runtime_path=selection(manifest,blueprint["skin_glb"],sidecar_path,sidecar)
    require(Path(path).resolve()==FOLDER/"face_union_mouth_winding_manifest_v1.json" and blueprint["name"]==AVATAR
        and blueprint.get("expression_validation_kind")==KIND and blueprint.get("expression_original_mouth_pn_restored") is True
        and blueprint.get("expression_original_mouth_winding_corrected") is True,"An ordinary expression cannot inherit the winding exception")
    require(blueprint.get("expression_mouth_ledger_sha256")==RULE["pn_ledger_sha"]
        and blueprint.get("expression_mouth_winding_ledger_sha256")==RULE["winding_ledger_sha"]
        and workspace_file(blueprint["expression_mouth_ledger"])==ledgers["mouth_restoration"]
        and workspace_file(blueprint["expression_mouth_winding_ledger"])==ledgers["mouth_winding"],
        "Blueprint winding/PN evidence differs from the sealed sidecar")
    require(Path(validation_path)==FOLDER/"face_union_mouth_winding_validation_v1.json","Separate current winding validation required")
    baseline_path=workspace_file(manifest["original_union_baseline"])
    require(baseline_path==FOLDER/"face_union_manifest.json" and skin_schema.sha(baseline_path)==manifest["original_union_baseline_sha256"],
        "Exact original HWF union manifest changed")
    baseline=json.loads(baseline_path.read_text(encoding="utf-8"));baseline_glb=workspace_file(baseline["skin_asset"])
    require(baseline.get("skin_sha256")==RULE["union_sha"] and skin_schema.sha(baseline_glb)==RULE["union_sha"],"Original HWF union SHA changed")
    from finalize_skin_assets import inspect
    original_blueprint=skin_schema.load(baseline_glb.with_suffix(".skin.json"))
    checked,report,doc,binary=inspect(baseline_glb,workspace_file(baseline["prepare_report"]))
    require(checked==json.loads(workspace_file(baseline["validation_report"]).read_text(encoding="utf-8")),"HWF baseline byte proof is stale")
    original_result=union.verify(baseline,original_blueprint,checked,report,doc,binary,
        workspace_file(baseline["prepare_report"]),workspace_file,geometry_reference_only=True)
    for key in ("source_skin_sha256","source_fixed_sha256","prepare_report","original_face_provenance","original_face_provenance_sha256"):
        require(manifest.get(key)==baseline.get(key),"HWF original provenance changed: "+key)
    from validate_mouth_winding import check
    from validate_mouth_restoration import check as parent_check
    current=check(blueprint["skin_glb"])
    require(current==json.loads(Path(validation_path).read_text(encoding="utf-8")),"Current HWF winding bytes/proof differ")
    require(current.get("sha256")==RULE["glb_sha"] and current.get("ledger_sha256")==RULE["winding_ledger_sha"]
        and current.get("parent_mouth_glb_sha256")==RULE["parent_sha"] and current.get("parent_mouth_changed_original_vertices")==RULE["vertices"]
        and current.get("changed_original_mouth_triangles")==RULE["winding_faces"],"HWF winding proof targets another scope")
    require(all(current.get(k) is True for k in ("original_triangle_vertex_sets_exact","parent_position_normal_uv_joint_weight_bones_images_exact","body_headbase_indices_exact"))
        and current.get("new_vertices")==0 and current.get("new_triangles")==0,"Non-mouth HWF geometry changed")
    pn=parent_check(file(manifest["parent_mouth_asset"]))
    require(pn["input_union_sha256"]==RULE["union_sha"] and pn["restoration_ledger_sha256"]==RULE["pn_ledger_sha"]
        and pn["changed_original_mouth_vertices"]==RULE["vertices"] and pn["maximum_source_position_delta"]<=RULE["maximum_delta"]
        and pn["maximum_normal_length_error"]<=1e-6,"HWF bounded P/N scope changed")
    cp=workspace_file(manifest["uv_texture_compatibility"])
    require(skin_schema.sha(cp)==manifest["uv_texture_compatibility_sha256"],"HWF UV compatibility SHA changed")
    compatibility=json.loads(cp.read_text(encoding="utf-8"));previous=json.loads(workspace_file(baseline["uv_texture_compatibility"]).read_text(encoding="utf-8"))
    additions={"comparison_union","comparison_union_sha256","original_geometry_preserved","geometry_exception","mouth_restoration_ledger",
        "mouth_restoration_ledger_sha256","mouth_winding_ledger","mouth_winding_ledger_sha256"}
    for key,value in previous.items():
        if key!="expression_skin_sha256":require(compatibility.get(key)==value,"HWF original complete UV/PNG correspondence changed")
    require(set(compatibility)==set(previous)|additions and compatibility.get("expression_skin_sha256")==RULE["glb_sha"]
        and compatibility.get("comparison_union_sha256")==RULE["union_sha"] and workspace_file(compatibility["comparison_union"])==baseline_glb
        and compatibility.get("original_geometry_preserved") is False
        and compatibility.get("geometry_exception")=="recorded original mouth P/N and listed inward mouth-wall index order only",
        "HWF UV compatibility cannot grant a wider exception")
    for prefix,pin in (("mouth_restoration",RULE["pn_ledger_sha"]),("mouth_winding",RULE["winding_ledger_sha"])):
        require(workspace_file(compatibility[prefix+"_ledger"])==ledgers[prefix] and compatibility.get(prefix+"_ledger_sha256")==pin,
            "HWF UV proof ledger changed")
    doc,binary,_=read_glb(blueprint["skin_glb"])
    report=json.loads(Path(blueprint["skin_glb"]).with_suffix(".json").read_text(encoding="utf-8"))
    checked=dict(pn["baseline_validation"]);checked.update(skin_sha256=RULE["glb_sha"],original_face_position_normal_joint_weight_values_exact=False,
        original_oriented_triangles_partition_exact=False)
    result={k:original_result[k] for k in ("original_triangles_only","selected_original_triangles","added_face_vertices",
        "face_provenance_sha256","original_face_uv_sha256","previous_expression_skin_sha256")}
    result.update(candidate_variant=VARIANT,validation_kind=KIND,original_position_normal_values_preserved=False,
        original_joint_weight_values_preserved=True,mouth_restoration_schema=1,mouth_restoration_ledger_sha256=RULE["pn_ledger_sha"],
        original_union_sha256=RULE["union_sha"],mouth_changed_original_vertices=RULE["vertices"],mouth_runtime_contract_sha256=skin_schema.sha(runtime_path),
        mouth_winding_schema=1,mouth_winding_ledger_sha256=RULE["winding_ledger_sha"],mouth_winding_original_triangles=RULE["winding_faces"],
        mouth_winding_parent_sha256=RULE["parent_sha"],original_oriented_triangle_indices_preserved=False,original_triangle_vertex_sets_preserved=True,
        uv_compatibility_sha256=manifest["uv_texture_compatibility_sha256"],original_union_baseline_visual_quality_approved=False,
        original_union_baseline_reference_kind=RULE["reference_kind"],maximum_source_position_delta=pn["maximum_source_position_delta"],actual_texture_ids_reused=False)
    return result,checked,report,doc,binary
