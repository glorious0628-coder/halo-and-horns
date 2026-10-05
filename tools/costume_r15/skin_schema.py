# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
# Still importable as a library ONLY because live tools import it (tools/monster_import_preflight.py,
# tools/test_weapon_motion.py, GLB audit tools). Never run it directly.
"""Read preserved skin/package provenance and emit an unregistered schema-2 plan.

All inputs are read only. No Studio, source-module changes, upload or API calls.
The plan deliberately contains unitized source reference axes, not invented
Roblox CFrames; the real imported Bone/host bind inventory is still required.
"""
from __future__ import annotations

if __name__ == "__main__":
    raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import hashlib
import json
from pathlib import Path
import re

import numpy as np

from constraints import PRIMARY, RigError
from glb_io import read_glb
from preserve_skin import node_matrices

ROOT=Path(__file__).resolve().parents[2]
NAMES={"Costume_"+f+c+g for f in ("Halo","Horns","Neutral") for c in ("Warrior","Archer","Mage") for g in ("M","F")}
MOUTH_KIND="original_connected_mouth_pn_exception_v1"
WINDING_KIND="original_connected_mouth_pn_winding_exception_v1"
INFERRED_BIND_ORIGIN="corrected_preserved_bind_skin_proxy_candidate"
ORIGINS=("preserved_source_skin_proxy_candidate","inferred_manual_candidate","corrected_preserved_source_skin_proxy_candidate",INFERRED_BIND_ORIGIN)


def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def local_input(base,value):
    path=Path(value)
    if path.is_absolute() or ".." in path.parts: raise RigError("Package inputs must remain below their package directory")
    result=(base/path).resolve();result.relative_to(base.resolve())
    return result


def load(path,proxy_override=None):
    path=Path(path).resolve();data=json.loads(path.read_text(encoding="utf-8"));package=None;expression_data=None;corrected_proof=None;inferred_proof=None;face_proof=None
    corrected_package=data.get("kind")=="corrected_preserved_skin_pending"
    if corrected_package:
        from skin_corrected_weight_proof import validate_package
        verified,corrected_inputs,_=validate_package(path);corrected_proof=verified["corrected_weight_proof"]
    elif data.get("rig_origin")=="corrected_preserved_source_skin_proxy_candidate":
        import skin_face_weight_schema as face_adapter
        if face_adapter.matches(data):
            data=face_adapter.validate_sidecar(path);face_proof=data["face_weight_proof"]
        else:
            from skin_corrected_weight_proof import validate_sidecar
            data,_,_=validate_sidecar(path);corrected_proof=data["corrected_weight_proof"]
    elif data.get("rig_origin")==INFERRED_BIND_ORIGIN:
        from skin_inferred_bind_schema import validate_sidecar
        data=validate_sidecar(path);inferred_proof=data["inferred_bind_proof"]
    if data.get("kind") in ("preserved_original_skin_pending","corrected_preserved_skin_pending"):
        package=data
        if data.get("schema")!=1 or data.get("rig_ready_for_game") is not False: raise RigError("Only unpromoted preserved packages are supported")
        inputs={key:local_input(path.parent,data[key]) for key in ("skin_glb","skin_manifest","proxy_plan")}
        if any(sha(value)!=data["sha256"][key] for key,value in inputs.items()): raise RigError("Package file hashes changed")
        data=json.loads(inputs["skin_manifest"].read_text(encoding="utf-8"));manifest_path=inputs["skin_manifest"]
        if corrected_proof: data["corrected_weight_proof"]=corrected_proof
        skin,plan=inputs["skin_glb"],inputs["proxy_plan"]
        name=package["name"];name=name if name.startswith("Costume_") else "Costume_"+name
    else:
        manifest_path=path
        if data.get("rig_origin") not in ORIGINS:
            raise RigError("Unknown skin origins never inherit original-source validation")
        if data.get("rig_origin") not in ("corrected_preserved_source_skin_proxy_candidate",INFERRED_BIND_ORIGIN) and (data.get("weight_correction_plan") or data.get("original_source_weights_exact") is False):
            raise RigError("Corrected weights require their explicit independently verified source origin")
        manual=data.get("rig_origin")=="inferred_manual_candidate"
        legacy_manual=manual and "skin_source" not in data
        skin=Path(data["output"] if legacy_manual else data["skin_source"] if manual else data["output"]).resolve()
        plan=Path(proxy_override or data.get("proxy_plan","")).resolve()
        if legacy_manual and not proxy_override: raise RigError("An explicit --proxy-plan is required for a legacy inferred sidecar")
        name=data.get("name")
        if data.get("expression_manifest"):
            expression_path=Path(data["expression_manifest"])
            if not expression_path.is_absolute(): expression_path=ROOT/expression_path
            expression_path.resolve().relative_to(ROOT)
            if sha(expression_path)!=data.get("expression_manifest_sha256"): raise RigError("Expression sidecar manifest SHA changed")
            expression_data=json.loads(expression_path.read_text(encoding="utf-8"));expression_name=expression_data["avatar"]
            if name and name!=expression_name: raise RigError("Expression sidecar costume identity changed")
            name=expression_name
        name=name or re.sub(r"_skin$","",skin.stem)
    if data.get("rig_origin") not in ORIGINS:
        raise RigError("Unknown skin origins never inherit original-source validation")
    if data.get("rig_origin")=="corrected_preserved_source_skin_proxy_candidate" and not (corrected_proof or face_proof):
        raise RigError("A corrected origin requires its independently verified source proof")
    if data.get("rig_origin")==INFERRED_BIND_ORIGIN and not inferred_proof:
        raise RigError("An inferred bind requires its independently recomputed limited proof")
    if data.get("rig_origin") not in ("corrected_preserved_source_skin_proxy_candidate",INFERRED_BIND_ORIGIN) and (data.get("weight_correction_plan") or data.get("original_source_weights_exact") is False):
        raise RigError("Corrected weights cannot be relabeled as an exact original")
    expected_schema=2 if inferred_proof else 1
    if name not in NAMES or data.get("schema",1 if data.get("rig_origin")=="inferred_manual_candidate" else None)!=expected_schema or data.get("rig_ready_for_game") is not False: raise RigError("An exact unpromoted eighteen-way costume is required")
    kind=data.get("expression_validation_kind")
    mouth=bool(expression_data and expression_data.get("validation_kind")==MOUTH_KIND)
    winding=bool(expression_data and expression_data.get("validation_kind")==WINDING_KIND)
    if kind is not None and kind not in (MOUTH_KIND,WINDING_KIND): raise RigError("Unknown expression geometry exception is never inferred")
    if kind==MOUTH_KIND or mouth:
        from skin_face_union_proof import mouth_selection,MOUTH_RULES
        if not mouth or kind!=MOUTH_KIND or name not in MOUTH_RULES or data.get("expression_original_mouth_pn_restored") is not True:
            raise RigError("This explicitly selected avatar's mouth-only sidecar is required")
        mouth_selection(expression_data,skin,path,data)
    if kind==WINDING_KIND or winding:
        from skin_mouth_winding_proof import selection
        if not winding or kind!=WINDING_KIND:raise RigError("The separately selected winding sidecar is required")
        selection(expression_data,skin,path,data)
    manual=data.get("rig_origin")=="inferred_manual_candidate"
    legacy_manual=manual and "skin_source" not in data
    original=data["original_source_sha256"] if manual and not legacy_manual else data["source_sha256"]
    original_path=Path(data["original_static_source"] if manual and not legacy_manual else data["source"])
    if package:
        original_path=ROOT/package["original_source"]["workspace_relative_path"]
        if package["original_source"]["sha256"]!=original: raise RigError("Package original provenance disagrees")
    if original_path.is_file() and sha(original_path)!=original: raise RigError("Available original source changed")
    expected_skin=data["skin_sha256"] if manual and not legacy_manual else data["output_sha256"]
    if sha(skin)!=expected_skin: raise RigError("Exact preserved skin changed")
    if not manual and sha(plan)!=data["proxy_plan_sha256"]: raise RigError("Exact proxy plan changed")
    gltf,binary,_=read_glb(skin)
    if len(gltf.get("skins",[]))!=1: raise RigError("One complete source skin is required")
    count=15 if manual else 23
    if legacy_manual:
        if data.get("original_bones_claimed") is not False or data.get("original_geometry_accessors_reused") is not True: raise RigError("Inferred source preservation markers are required")
        parents,local,world=node_matrices(gltf);indices=gltf["skins"][0]["joints"];names={i:gltf["nodes"][i]["name"] for i in indices}
        data["bones"]=[{"name":names[i],"parent":names.get(parents.get(i),"HumanoidRootPart"),"gltf_bind_game_world_column_major":world[i].flatten(order="F").tolist()} for i in indices]
    if len(gltf["skins"][0]["joints"])!=count or len(data["bones"])!=count: raise RigError("The whole preserved fifteen/twenty-three bone hierarchy is required")
    bone_rows=[]
    for b in data["bones"]:
        values=np.array(b["gltf_bind_game_world_column_major"] if manual else b["game_bind_world"],dtype=float)
        if values.size!=16 or not np.isfinite(values).all(): raise RigError("Finite column-major source bind is required")
        matrix=values.reshape(4,4).T;lengths=np.linalg.norm(matrix[:3,:3],axis=0)
        # Some original Tripo limb matrices retain ~1.5e-5 scale rounding.
        # Keep their exact source matrices; unit reference axes are comparison
        # metadata only and must later be checked against actual Bone CFrames.
        if min(lengths)<=0 or not np.allclose(lengths,lengths[0],rtol=1e-4): raise RigError("Source bind has nonuniform scale beyond imported-frame precision")
        rotation=matrix[:3,:3]/lengths
        if not np.allclose(rotation.T@rotation,np.eye(3),atol=1e-4) or np.linalg.det(rotation)<0: raise RigError("Source bind axes are invalid")
        parent=b["parent"] if manual else b["parent_name"]
        parent=None if manual and parent=="HumanoidRootPart" else parent
        bone_rows.append({"name":b["name"],"parent":parent,"part":b["name"] if manual else b["proxy_part"],
                          "principal":True if manual else b["principal"],"reference_game_position":matrix[:3,3].tolist(),
                          "reference_unit_rotation":rotation.reshape(9).tolist(),"source_axis_scale_relative_error":float(max(lengths)/min(lengths)-1),"actual_imported_bind_required":True})
    lookup={b["name"]:b for b in bone_rows}
    if len(lookup)!=count or {b["name"] for b in bone_rows if b["principal"]}!=set(PRIMARY): raise RigError("Exactly fifteen uniquely named principal bones are required")
    for b in bone_rows:
        if b["part"] not in (*PRIMARY,"HumanoidRootPart"): raise RigError("Bone uses an unknown proxy")
        current=b;seen=set()
        while current:
            if current["name"] in seen: raise RigError("Cyclic source ancestry")
            seen.add(current["name"])
            if current["parent"] is not None and current["parent"] not in lookup: raise RigError("Lost auxiliary/principal parent")
            current=lookup.get(current["parent"])
    surfaces=[m.get("name","") for m in gltf["meshes"]]
    if len(surfaces) not in (2,3) or len(set(surfaces))!=len(surfaces): raise RigError("An exact two/three material surface package is required")
    source_claim=False if manual or inferred_proof else True
    return {"schema":2,"draft":True,"name":name,"skin_glb":str(skin),"proxy_plan":str(plan),
            "skin_sha256":expected_skin,"original_sha256":original,"original_local_file_verified":original_path.is_file(),
            "contract_sha256":sha(manifest_path),"proxy_plan_sha256":sha(plan),"unique_bones":count,"principal_bones":15,
            "bone_instance_count":"must be read from actual import, never inferred per mesh","bones":bone_rows,
            "visual_surfaces":surfaces,"rig_origin":data["rig_origin"],"original_bones_claimed":source_claim,
            "actual_inspection_required":True,"rig_ready_for_game":False,"animation_validated":False,
            "weighting_quality_hold":bool(package and package.get("weighting_quality_hold")),
            "expression_manifest":data.get("expression_manifest"),
            "expression_manifest_sha256":data.get("expression_manifest_sha256"),
            "expression_validation":data.get("expression_validation"),
            "expression_validation_sha256":data.get("expression_validation_sha256"),
            "expression_validation_kind":kind,
            "expression_original_mouth_pn_restored":bool(mouth or winding),
            "expression_original_mouth_winding_corrected":bool(winding),
            "expression_mouth_ledger":data.get("expression_mouth_ledger"),
            "expression_mouth_ledger_sha256":data.get("expression_mouth_ledger_sha256"),
            "expression_mouth_winding_ledger":data.get("expression_mouth_winding_ledger"),
            "expression_mouth_winding_ledger_sha256":data.get("expression_mouth_winding_ledger_sha256"),
            "corrected_weight_proof":corrected_proof,
            "inferred_bind_proof":inferred_proof,
            "face_weight_proof":face_proof,
            "path_policy":"package-local relative files override stale absolute sidecar paths" if package else "explicit current sidecar paths",
            "api_calls":0,"studio_calls":0}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("contract",type=Path);parser.add_argument("--output",type=Path);parser.add_argument("--proxy-plan",type=Path)
    args=parser.parse_args();result=load(args.contract,args.proxy_plan)
    if args.output:
        output=args.output.resolve();output.relative_to((ROOT/"build").resolve())
        if output.exists(): raise RigError("Existing plans are never overwritten")
        output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"name":result["name"],"bones":result["unique_bones"],"surfaces":len(result["visual_surfaces"]),"ready":False,"studio_calls":0,"api_calls":0}))


if __name__=="__main__":
    try: main()
    except (RigError,KeyError,ValueError,OSError) as error: raise SystemExit("skin_schema refused: "+str(error))
