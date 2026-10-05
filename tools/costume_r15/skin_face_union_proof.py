# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
# Still importable as a library ONLY because live tools import it (tools/monster_import_preflight.py,
# tools/test_weapon_motion.py, GLB audit tools). Never run it directly.
"""Independently compare original-only face provenance to real GLB accessors.

No metadata flag grants trust. Every declared original triangle/corner/vertex,
skin influence, approved UV mask and reusable PNG is re-read from actual files.
"""
from __future__ import annotations

if __name__ == "__main__":
    raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import hashlib
import json
from pathlib import Path

import numpy as np

from constraints import RigError
from glb_io import accessor_values,read_glb
import skin_schema

# This exception is a separately selected, explicitly reviewed candidate. It
# cannot grant arbitrary P/N edits to canonical cap/original-union manifests.
MOUTH_KIND="original_connected_mouth_pn_exception_v1"
MOUTH_VARIANT="original_triangle_union_mouth_restored_v1"
MOUTH_GLB_SHA="17972af93f7ecd176f96af8db81fdff00c04e055a1d340b9dd9f288196d54584"
MOUTH_LEDGER_SHA="3c6f732b488e7635cfe43f5568661a03c0f74829f448208c9e917ffbe0d36419"
UNION_GLB_SHA="77a99d609d0d7264b2931587ce040bc64d27beca262fd33444bbf8fd31c2734e"
MOUTH_AVATAR="Costume_HaloArcherM"
MOUTH_FOLDER=skin_schema.ROOT/"art/models/costume/expressions"/MOUTH_AVATAR
MOUTH_RULES={
    MOUTH_AVATAR:{"glb_sha":MOUTH_GLB_SHA,"ledger_sha":MOUTH_LEDGER_SHA,"union_sha":UNION_GLB_SHA,
                  "faces":438,"vertices":71,"maximum_delta":0.0062,"reference_kind":"original_union"},
    "Costume_HaloMageF":{"glb_sha":"4d5fe892fc32a9c8a5135d72a1a819edbbe764617d2b993e3e58e897501233f3",
                         "ledger_sha":"7e6332a62564ca9741a13b684f2c82109908d23b5acf007bf3a645cff6843700",
                         "union_sha":"c12e13cb6479e91a443c2cc4655515108f78574794c5973cef16129926025d9d",
                         "faces":347,"vertices":75,"maximum_delta":0.021164,"reference_kind":"geometry_comparison_only"},
    "Costume_NeutralArcherM":{"glb_sha":"407691c8b31de0d3d163ceb2866f94b4027d8d7a94adc520c80ad815fa0dcf75",
                         "ledger_sha":"84427c9b85e406adfa35a301f941f5c9676a1a63b7050595a090bedb73ca4a29",
                         "union_sha":"4eaebb39192f1f3b24f7bfe212f953c026018da3459d1925d911c25e4357d3ce",
                         "faces":357,"vertices":41,"maximum_delta":0.006936,"reference_kind":"geometry_comparison_only"},
}
GEOMETRY_RULES={**MOUTH_RULES,
    "Costume_HaloWarriorF":{"union_sha":"a81ba5413010532d8bb20627cbd19b75e7f19601901896b3967ef412eeda7a6f",
        "faces":300,"reference_kind":"geometry_comparison_only"},
}


def array(doc,binary,primitive,key):
    return np.asarray(accessor_values(doc,binary,primitive["attributes"][key]))


def digest(values,dtype): return hashlib.sha256(np.asarray(values,dtype=dtype).tobytes()).hexdigest()


def mouth_file(value,avatar=MOUTH_AVATAR):
    path=Path(value)
    if not path.is_absolute(): path=skin_schema.ROOT/path
    if avatar not in MOUTH_RULES: raise RigError("An unselected avatar cannot use a mouth exception")
    folder=skin_schema.ROOT/"art/models/costume/expressions"/avatar
    path=path.resolve();path.relative_to(folder.resolve())
    if not path.is_file(): raise RigError("The selected mouth exception evidence is missing")
    return path


def mouth_selection(manifest,glb,sidecar_path,sidecar):
    """Seal the selection before an inspector is generated; never import here."""
    glb=Path(glb).resolve();sidecar_path=Path(sidecar_path).resolve()
    avatar=manifest.get("avatar");rule=MOUTH_RULES.get(avatar)
    if not rule or manifest.get("validation_kind")!=MOUTH_KIND or manifest.get("candidate_variant")!=MOUTH_VARIANT:
        raise RigError("Only the explicitly selected mouth v1 variant may use its P/N exception")
    current_file=lambda value:mouth_file(value,avatar)
    if glb!=current_file(manifest["skin_asset"]) or skin_schema.sha(glb)!=rule["glb_sha"] or manifest.get("skin_sha256")!=rule["glb_sha"]:
        raise RigError("The reviewed mouth candidate GLB must match its exact approved SHA")
    if sidecar_path!=glb.with_suffix(".skin.json"):
        raise RigError("An unrelated copied sidecar cannot grant a geometry exception")
    if manifest.get("original_triangles_only") is not True or manifest.get("selected_original_face_triangles")!=rule["faces"] or manifest.get("new_mouth_cap_vertices")!=0:
        raise RigError("Mouth restoration must keep every selected original face and add no geometry")
    if manifest.get("original_geometry_preserved") is not False or manifest.get("original_position_normal_values_preserved") is not False or manifest.get("original_joint_weight_values_preserved") is not True:
        raise RigError("The local P/N exception must not claim exact original P/N")
    ledger=current_file(manifest["mouth_restoration_ledger"])
    if skin_schema.sha(ledger)!=rule["ledger_sha"] or manifest.get("mouth_restoration_ledger_sha256")!=rule["ledger_sha"] or sidecar.get("expression_mouth_ledger_sha256")!=rule["ledger_sha"] or current_file(sidecar["expression_mouth_ledger"])!=ledger:
        raise RigError("Only this avatar's explicitly reviewed exact mouth ledger is allowed")
    runtime_path=skin_schema.ROOT/"art/models/costume/expressions"/avatar/"face_union_mouth_runtime_contract_v1.json"
    runtime=json.loads(runtime_path.read_text(encoding="utf-8"))
    selected=current_file(sidecar["expression_manifest"])
    if selected.name!="face_union_mouth_manifest_v1.json" or runtime.get("schema")!=1 or runtime.get("avatar")!=avatar or runtime.get("candidate_variant")!=MOUTH_VARIANT or runtime.get("strict_validation_kind")!=MOUTH_KIND:
        raise RigError("The separate exact mouth manifest/runtime contract is required")
    for path_key,sha_key,actual in (("glb","glb_sha256",glb),("sidecar","sidecar_sha256",sidecar_path),("manifest","manifest_sha256",selected)):
        if current_file(runtime[path_key])!=actual or runtime.get(sha_key)!=skin_schema.sha(actual): raise RigError("Mouth runtime contract path/SHA changed")
    if runtime.get("mouth_changed_original_vertices")!=rule["vertices"] or runtime.get("original_face_triangle_count")!=rule["faces"] or runtime.get("new_vertices")!=0 or runtime.get("new_triangles")!=0 or runtime.get("body_uv_jw_original_bones_png_exact") is not True:
        raise RigError("Mouth exception scope/count/preservation contract changed")
    if runtime.get("required_skin_runtime_schema")!=2 or runtime.get("required_expression_skin_runtime_schema")!=1 or runtime.get("root_weld_and_actual_shared_bone_host_required") is not True or runtime.get("actual_import_mesh_ids_required") is not True:
        raise RigError("Mouth candidate cannot bypass actual schema-2 host/binding verification")
    if any(runtime.get(key) is not False for key in ("ready","runtime_validated","roblox_uploaded")):
        raise RigError("Offline mouth runtime contract was prematurely promoted")
    return ledger,runtime_path


def verify_mouth(manifest,path,blueprint,validation_path,workspace_file):
    """Recheck the entire original union, then the separate bounded P/N proof."""
    from pathlib import Path
    sidecar_path=Path(blueprint["skin_glb"]).with_suffix(".skin.json")
    sidecar=json.loads(sidecar_path.read_text(encoding="utf-8"))
    ledger,runtime_path=mouth_selection(manifest,blueprint["skin_glb"],sidecar_path,sidecar)
    avatar=blueprint["name"];rule=MOUTH_RULES[avatar];folder=skin_schema.ROOT/"art/models/costume/expressions"/avatar
    if manifest.get("avatar")!=avatar or Path(path).resolve()!=mouth_file(sidecar["expression_manifest"],avatar) or blueprint.get("expression_validation_kind")!=MOUTH_KIND or blueprint.get("expression_original_mouth_pn_restored") is not True:
        raise RigError("A canonical expression loader cannot silently enable the mouth exception")
    if blueprint.get("expression_mouth_ledger_sha256")!=rule["ledger_sha"] or workspace_file(blueprint["expression_mouth_ledger"])!=ledger:
        raise RigError("Blueprint mouth ledger differs from its explicitly reviewed sidecar")
    if Path(validation_path).name!="face_union_mouth_restoration_validation_v1.json":
        raise RigError("The separate bounded mouth validation report is required")
    baseline_path=workspace_file(manifest["original_union_baseline"])
    if baseline_path!=folder/"face_union_manifest.json" or skin_schema.sha(baseline_path)!=manifest["original_union_baseline_sha256"]:
        raise RigError("The preserved exact original-union baseline changed")
    baseline=json.loads(baseline_path.read_text(encoding="utf-8"));baseline_glb=workspace_file(baseline["skin_asset"])
    if baseline.get("skin_sha256")!=rule["union_sha"] or skin_schema.sha(baseline_glb)!=rule["union_sha"]:
        raise RigError("Mouth exception original-union baseline is not the reviewed source")
    # Its independent 438-triangle / complete provenance / UV / PNG checks run
    # normally, including the canonical cap reference. Nothing is inherited
    # from a 'validated' boolean or exempted on that original path.
    from skin_expression_schema import load as original_load
    original_blueprint=skin_schema.load(baseline_glb.with_suffix(".skin.json"),blueprint["proxy_plan"] if blueprint["rig_origin"]=="inferred_manual_candidate" else None)
    if rule["reference_kind"]=="geometry_comparison_only":
        from finalize_skin_assets import inspect
        old_checked,old_report,old_doc,old_binary=inspect(baseline_glb,workspace_file(baseline["prepare_report"]))
        if old_checked!=json.loads(workspace_file(baseline["validation_report"]).read_text(encoding="utf-8")):
            raise RigError("Geometry-only baseline validation is not current actual byte proof")
        original_result=verify(baseline,original_blueprint,old_checked,old_report,old_doc,old_binary,
                               workspace_file(baseline["prepare_report"]),workspace_file,geometry_reference_only=True)
    else: original_result=original_load(baseline_path,original_blueprint)
    for key in ("source_skin_sha256","source_fixed_sha256","prepare_report","original_face_provenance","original_face_provenance_sha256"):
        if manifest.get(key)!=baseline.get(key): raise RigError("Mouth exception changed the original provenance/reference")
    from validate_mouth_restoration import check
    checked_mouth=check(blueprint["skin_glb"])
    stored=json.loads(Path(validation_path).read_text(encoding="utf-8"))
    if checked_mouth!=stored: raise RigError("Bounded mouth validation differs from actual byte/curve recomputation")
    if checked_mouth.get("sha256")!=rule["glb_sha"] or checked_mouth.get("restoration_ledger_sha256")!=rule["ledger_sha"] or checked_mouth.get("input_union_sha256")!=rule["union_sha"] or checked_mouth.get("changed_original_mouth_vertices")!=rule["vertices"]:
        raise RigError("Current mouth validation targets a different geometry/scope")
    if any(checked_mouth.get(key) is not True for key in ("body_topology_uv_joints_weights_bones_images_exact","non_mouth_position_normal_exact","headbase_face_shared_position_normal_exact","original_source_and_baseline_unchanged")) or checked_mouth.get("new_vertices")!=0 or checked_mouth.get("new_triangles")!=0:
        raise RigError("The exact original geometry outside the mouth exception changed")
    if checked_mouth["maximum_source_position_delta"]>rule["maximum_delta"] or checked_mouth["maximum_normal_length_error"]>1e-6:
        raise RigError("The reviewed mouth displacement/normal bound changed")
    compatibility_path=workspace_file(manifest["uv_texture_compatibility"])
    if skin_schema.sha(compatibility_path)!=manifest["uv_texture_compatibility_sha256"]: raise RigError("Mouth UV/image compatibility SHA changed")
    compatibility=json.loads(compatibility_path.read_text(encoding="utf-8"))
    previous=json.loads(workspace_file(baseline["uv_texture_compatibility"]).read_text(encoding="utf-8"))
    additions={"comparison_union","comparison_union_sha256","original_geometry_preserved","geometry_exception","mouth_restoration_ledger","mouth_restoration_ledger_sha256"}
    for key,value in previous.items():
        if key!="expression_skin_sha256" and compatibility.get(key)!=value: raise RigError("Mouth exception changed the reviewed complete original UV/PNG correspondence")
    if set(compatibility)!=set(previous)|additions or compatibility.get("expression_skin_sha256")!=rule["glb_sha"] or compatibility.get("comparison_union_sha256")!=rule["union_sha"] or workspace_file(compatibility["comparison_union"])!=baseline_glb or workspace_file(compatibility["mouth_restoration_ledger"])!=ledger or compatibility.get("mouth_restoration_ledger_sha256")!=rule["ledger_sha"] or compatibility.get("original_geometry_preserved") is not False or compatibility.get("geometry_exception")!="recorded original mouth P/N only":
        raise RigError("Mouth UV compatibility cannot grant an additional geometry exception")
    doc,binary,_=read_glb(blueprint["skin_glb"])
    report=json.loads(Path(blueprint["skin_glb"]).with_suffix(".json").read_text(encoding="utf-8"))
    checked=dict(checked_mouth["baseline_validation"])
    checked.update(skin_sha256=rule["glb_sha"],original_face_position_normal_joint_weight_values_exact=False)
    result={key:original_result[key] for key in ("original_triangles_only","selected_original_triangles","added_face_vertices",
            "face_provenance_sha256","original_face_uv_sha256","previous_expression_skin_sha256")}
    result.update(candidate_variant=MOUTH_VARIANT,validation_kind=MOUTH_KIND,original_position_normal_values_preserved=False,
                  original_joint_weight_values_preserved=True,mouth_restoration_schema=1,mouth_restoration_ledger_sha256=rule["ledger_sha"],
                  uv_compatibility_sha256=manifest["uv_texture_compatibility_sha256"],
                  original_union_sha256=rule["union_sha"],mouth_changed_original_vertices=rule["vertices"],mouth_runtime_contract_sha256=skin_schema.sha(runtime_path),
                  original_union_baseline_visual_quality_approved=False,
                  original_union_baseline_reference_kind=rule["reference_kind"],
                  maximum_source_position_delta=checked_mouth["maximum_source_position_delta"],actual_texture_ids_reused=False)
    return result,checked,report,doc,binary


def geometry_reference_uv(manifest,blueprint,checked,report,doc,binary,compatibility,workspace_file):
    """Unapproved MageF union is a geometry/UV baseline, never a ready asset."""
    rule=GEOMETRY_RULES[blueprint["name"]]
    if rule["reference_kind"]!="geometry_comparison_only" or manifest.get("original_triangles_only") is not True or checked["selected_original_face_triangles"]!=rule["faces"]:
        raise RigError("The exact geometry-only facial scope changed")
    if compatibility.get("geometry_comparison_only") is not True or compatibility.get("ready") is not False:
        raise RigError("Geometry-reference image proof must not claim quality approval")
    baseline_path=workspace_file(compatibility["comparison_manifest"])
    if skin_schema.sha(baseline_path)!=compatibility["comparison_manifest_sha256"]: raise RigError("Original reviewed rigid PNG comparison changed")
    baseline=json.loads(baseline_path.read_text(encoding="utf-8"))
    if baseline.get("avatar")!=blueprint["name"] or set(baseline.get("approved_states",[]))!={"Neutral","SoftSmile","Serious"}:
        raise RigError("Geometry-only comparison uses a foreign facial image scope")
    if blueprint["name"]=="Costume_NeutralArcherM" and blueprint["rig_origin"]=="inferred_manual_candidate":
        prepare=json.loads(workspace_file(manifest["prepare_report"]).read_text(encoding="utf-8"))
        # The pinned manual union was checked against its unchanged fixed
        # GLB and explicit normalized projection by inspect(), not a paid
        # affine proof or a claimed genuine source skeleton.
        if blueprint["unique_bones"]!=15 or blueprint["original_bones_claimed"] is not False or report.get("original_bones_claimed") is not False or report.get("source_skin_bones")!=15:
            raise RigError("The manual reference must retain its explicit fifteen inferred bones")
        if skin_schema.sha(workspace_file(prepare["source"]))!=prepare["source_sha256"] or prepare["source_sha256"]!=report["source_fixed_sha256"] or not prepare["reviewed_profile"].get("facial_boundary_polygon") or prepare.get("preserved_skin_coordinate_proof"):
            raise RigError("Exact original manual fixed source and reviewed boundary are required")
        if checked["normalized_face_uv_max_error"]>1e-6 or checked.get("reviewed_face_uv_signatures_exact") is not True:
            raise RigError("Manual original-face projection was not independently checked")
        prior_glb=workspace_file(baseline["skin_asset"])
        if skin_schema.sha(prior_glb)!=baseline["skin_sha256"] or baseline["source_skin_sha256"]!=manifest["source_skin_sha256"] or baseline["source_fixed_sha256"]!=report["source_fixed_sha256"]:
            raise RigError("Manual canonical facial comparison/source changed")
        from finalize_skin_assets import inspect
        _,_,prior_doc,prior_binary=inspect(prior_glb,workspace_file(manifest["prepare_report"]))
        prior_uv=array(prior_doc,prior_binary,prior_doc["meshes"][2]["primitives"][0],"TEXCOORD_0")
        face=doc["meshes"][2]["primitives"][0]
        current_uv=array(doc,binary,face,"TEXCOORD_0")
        if not np.array_equal(current_uv,prior_uv[:len(current_uv)]):
            raise RigError("Manual whole original normalized facial UV no longer matches the actual canonical comparison")
    else:
        rigid=workspace_file(baseline["head_asset"])
        if skin_schema.sha(rigid)!=baseline["head_sha256"]:
            raise RigError("Original exact normalized-UV projection references a different rigid head")
        coordinate=report["preserved_skin_coordinate_proof"]
        if coordinate["approved_baseline_head_sha256"]!=baseline["head_sha256"] or Path(coordinate["approved_baseline_head"]).resolve()!=rigid:
            raise RigError("Original rigid affine comparison changed")
        if coordinate["approved_face_original_triangles"]!=rule["faces"] or coordinate["approved_face_uv_maximum_error"]>1e-6:
            raise RigError("Original fixed/skin/rigid facial UV projection was not verified")
    face=doc["meshes"][2]["primitives"][0];uv=array(doc,binary,face,"TEXCOORD_0")
    current=digest(uv,"<f4")
    if current!=compatibility["normalized_original_face_uv_sha256"] or current!=compatibility["canonical_normalized_original_face_uv_sha256"] or compatibility.get("normalized_original_face_uv_float32_exact") is not True or compatibility.get("approved_png_bytes_unchanged") is not True or compatibility.get("mesh_asset_reimport_required") is not True:
        raise RigError("Actual full normalized facial UV/PNG preservation changed")
    states={row["state"]:row for row in manifest["records"]};previous={row["state"]:row for row in baseline["records"]}
    rows=compatibility["expression_pngs"]
    if len(rows)!=3 or len(states)!=3 or len(previous)!=3 or {row["state"] for row in rows}!=set(states):
        raise RigError("Exactly three original reviewed PNG correspondences are required")
    for row in rows:
        state=row["state"]
        if row["png"]!=states[state]["png"] or row["sha256"]!=states[state]["sha256"] or any(states[state][key]!=previous[state][key] for key in ("png","size","sha256")):
            raise RigError("Geometry-reference image differs from its actual approved GPT PNG")
        if states[state].get("closed_mouth_offline_render_verified") is not False or skin_schema.sha(workspace_file(row["png"]))!=row["sha256"]:
            raise RigError("An unapproved original mouth was incorrectly reported as quality complete")
    return {"original_triangles_only":True,"selected_original_triangles":rule["faces"],"added_face_vertices":0,
            "face_provenance_sha256":manifest["original_face_provenance_sha256"],"uv_compatibility_sha256":manifest["uv_texture_compatibility_sha256"],
            "original_face_uv_sha256":current,"previous_expression_skin_sha256":manifest["source_skin_sha256"],
            "geometry_comparison_only":True,"visual_quality_hold":True,"actual_texture_ids_reused":False}


def verify(manifest,blueprint,checked,report,doc,binary,prepare_path,workspace_file,geometry_reference_only=False):
    if geometry_reference_only:
        rule=GEOMETRY_RULES.get(blueprint["name"],{})
        if rule.get("reference_kind")!="geometry_comparison_only" or blueprint["skin_sha256"]!=rule.get("union_sha") or skin_schema.sha(blueprint["skin_glb"])!=rule["union_sha"] or manifest.get("candidate_variant")!="original_triangle_union_geometry_comparison_only" or manifest.get("geometry_comparison_only") is not True or manifest.get("visual_quality_hold") is not True or manifest.get("ready") is not False:
            raise RigError("Only the exact preserved unapproved geometry reference is allowed internally")
        raw_doc,raw_binary,_=read_glb(blueprint["skin_glb"])
        if raw_doc!=doc or raw_binary!=binary: raise RigError("Geometry-reference arguments are not the actual checked GLB")
    elif manifest.get("candidate_variant")!="original_triangle_union_v1" or manifest.get("original_triangles_only") is not True:
        raise RigError("An explicit original-triangle union candidate is required")
    if manifest.get("selected_original_face_triangles")!=checked["selected_original_face_triangles"] or manifest.get("new_mouth_cap_vertices")!=0 or checked["new_mouth_cap_vertices"]!=0 or checked["new_mouth_cap_triangles"]!=0:
        raise RigError("Declared original face count/zero added geometry disagrees with actual inspection")
    if blueprint["name"]=="Costume_HaloArcherM" and checked["selected_original_face_triangles"]!=438:
        raise RigError("The reviewed HaloArcherM union is exactly its 438 original facial triangles")
    evidence={}
    for key,sha_key in (("original_face_provenance","original_face_provenance_sha256"),("uv_texture_compatibility","uv_texture_compatibility_sha256")):
        path=workspace_file(manifest[key])
        if skin_schema.sha(path)!=manifest.get(sha_key): raise RigError("Declared original face evidence SHA changed")
        row=json.loads(path.read_text(encoding="utf-8"))
        if row.get("schema")!=1 or row.get("avatar")!=blueprint["name"] or row.get("expression_skin_sha256")!=blueprint["skin_sha256"] or row.get("ready") is not False:
            raise RigError("Evidence targets a different or promoted face candidate")
        evidence[key]=row
    provenance=evidence["original_face_provenance"];compatibility=evidence["uv_texture_compatibility"]
    source=workspace_file(report["source_skin"]);original,original_binary,_=read_glb(source)
    old=original["meshes"][1]["primitives"][0];face=doc["meshes"][2]["primitives"][0]
    values={key:array(original,original_binary,old,key) for key in ("POSITION","NORMAL","TEXCOORD_0","JOINTS_0","WEIGHTS_0")}
    original_tri=np.asarray(accessor_values(original,original_binary,old["indices"]),dtype=int).reshape(-1,3)
    selected=np.asarray(accessor_values(doc,binary,face["indices"]),dtype=int).reshape(-1,3)
    count=len(values["POSITION"]);unique=set(int(v) for v in selected.reshape(-1))
    if any(provenance.get(key)!=expected for key,expected in (("source_skin_sha256",manifest["source_skin_sha256"]),("original_head_triangles",len(original_tri)),
           ("selected_original_triangles",len(selected)),("selected_unique_vertices",len(unique)),("new_vertices",0),("new_interpolated_vertices",0))):
        raise RigError("Original union provenance counts/source are false")
    if provenance.get("geometry_normal_joint_weight_values_exact") is not True or provenance.get("source_unchanged") is not True:
        raise RigError("Original source preservation must be explicitly reported")
    if len(provenance["triangles"])!=len(selected) or len(provenance["vertices"])!=len(unique): raise RigError("An exact complete face provenance ledger is required")
    source_faces=[]
    for index,row in enumerate(provenance["triangles"]):
        old_index=row["original_head_face_index"]
        if type(old_index) is not int or not 0<=old_index<len(original_tri) or row["expression_face_index"]!=index:
            raise RigError("Invalid original triangle correspondence")
        triangle=selected[index]
        if not np.array_equal(triangle,original_tri[old_index]) or not np.array_equal(triangle,row["original_vertex_indices"]) or not np.array_equal(values["TEXCOORD_0"][triangle],row["original_uv"]):
            raise RigError("Original face orientation/corners/UV changed")
        source_faces.append(old_index)
    if len(set(source_faces))!=len(source_faces) or source_faces!=provenance["source_face_indices"] or digest(selected,"<u4")!=provenance["oriented_original_indices_sha256"]:
        raise RigError("Original face index ordering or digest changed")
    seen=set();fields={"position":"POSITION","normal":"NORMAL","original_uv":"TEXCOORD_0","joints":"JOINTS_0","weights":"WEIGHTS_0"}
    for row in provenance["vertices"]:
        index=row["original_vertex_index"]
        if type(index) is not int or index not in unique or index in seen: raise RigError("Original vertex is duplicate, absent or unrelated")
        seen.add(index)
        if any(not np.array_equal(values[key][index],row[field]) for field,key in fields.items()): raise RigError("Original position/normal/UV/joints/weights ledger differs")
    if seen!=unique: raise RigError("Original facial vertex evidence is incomplete")
    names=[original["nodes"][index]["name"] for index in original["skins"][0]["joints"]]
    if provenance["joint_slot_order"]!=names: raise RigError("Original bone influence slot order changed")

    if geometry_reference_only:
        return geometry_reference_uv(manifest,blueprint,checked,report,doc,binary,compatibility,workspace_file)

    baseline_path=workspace_file(compatibility["comparison_manifest"])
    if skin_schema.sha(baseline_path)!=compatibility["comparison_manifest_sha256"]: raise RigError("The preserved previous expression manifest changed")
    baseline=json.loads(baseline_path.read_text(encoding="utf-8"));baseline_glb=workspace_file(baseline["skin_asset"])
    if baseline.get("avatar")!=blueprint["name"] or baseline.get("source_skin_sha256")!=manifest["source_skin_sha256"] or baseline.get("skin_sha256")!=compatibility["comparison_skin_sha256"] or skin_schema.sha(baseline_glb)!=baseline["skin_sha256"]:
        raise RigError("The original expression comparison targets a different avatar/source")
    baseline_prepare=workspace_file(baseline["prepare_report"])
    if json.loads(prepare_path.read_text(encoding="utf-8"))!=json.loads(baseline_prepare.read_text(encoding="utf-8")):
        raise RigError("Union candidate changed the original reviewed UV scope or coordinate proof")
    # The previous candidate is also re-inspected; its claims are not inherited.
    from finalize_skin_assets import inspect
    inspect(baseline_glb,baseline_prepare)
    previous,previous_binary,_=read_glb(baseline_glb)
    prior_face=previous["meshes"][2]["primitives"][0]
    if doc["materials"][face["material"]]!=previous["materials"][prior_face["material"]]:
        raise RigError("Union candidate changed the reviewed face color/material policy")
    current_uv=array(doc,binary,face,"TEXCOORD_0");prior_uv=array(previous,previous_binary,prior_face,"TEXCOORD_0")[:count]
    if len(current_uv)!=count or not np.array_equal(current_uv,prior_uv) or compatibility.get("original_head_vertices_compared")!=count:
        raise RigError("The actual complete original facial UV accessor changed")
    if compatibility.get("normalized_original_face_uv_float32_exact") is not True or compatibility.get("approved_png_bytes_unchanged") is not True or compatibility.get("mesh_asset_reimport_required") is not True:
        raise RigError("Exact UV/PNG preservation and new mesh import must be explicit")
    if digest(current_uv,"<f4")!=compatibility["normalized_original_face_uv_sha256"] or digest(prior_uv,"<f4")!=compatibility["canonical_normalized_original_face_uv_sha256"]:
        raise RigError("Actual normalized face UV float32 digest changed")
    states={row["state"]:row for row in manifest["records"]};previous_states={row["state"]:row for row in baseline["records"]}
    rows=compatibility["expression_pngs"]
    if len(rows)!=3 or {row["state"] for row in rows}!=set(states): raise RigError("Three complete original expression PNG correspondences are required")
    for row in rows:
        state=row["state"]
        if row["png"]!=states[state]["png"] or row["sha256"]!=states[state]["sha256"] or any(states[state][key]!=previous_states[state][key] for key in ("png","sha256","size")):
            raise RigError("A reused expression image differs from the actual prior reviewed file")
        if skin_schema.sha(workspace_file(row["png"]))!=row["sha256"]: raise RigError("Original expression PNG bytes changed")
    return {"candidate_variant":"original_triangle_union_v1","original_triangles_only":True,"selected_original_triangles":len(selected),"added_face_vertices":0,
            "face_provenance_sha256":manifest["original_face_provenance_sha256"],"uv_compatibility_sha256":manifest["uv_texture_compatibility_sha256"],
            "original_face_uv_sha256":digest(current_uv,"<f4"),"previous_expression_skin_sha256":baseline["skin_sha256"],"actual_texture_ids_reused":False}
