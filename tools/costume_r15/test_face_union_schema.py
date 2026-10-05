# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Read-only original-face proof, semantic tampering and real GLB byte tests.

Only disposable build fixtures are modified. No Studio/API/registry calls.
"""
from __future__ import annotations

raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import copy
import json
from pathlib import Path
import struct
import tempfile

import skin_expression_schema as schema
import skin_face_union_proof as proof
import skin_schema
from glb_io import read_glb, write_glb


ROOT=Path(__file__).resolve().parents[2]
FOLDER=ROOT/"art/models/costume/expressions/Costume_HaloArcherM"


def main():
    manifest_path=FOLDER/"face_union_manifest.json"
    manifest=json.loads(manifest_path.read_text(encoding="utf-8"))
    glb=ROOT/manifest["skin_asset"]
    sidecar=glb.with_suffix(".skin.json")
    blueprint=skin_schema.load(sidecar)
    result=schema.load(manifest_path,blueprint)
    from finalize_skin_assets import inspect
    prep=ROOT/manifest["prepare_report"]
    checked,report,doc,binary=inspect(glb,prep)
    evidence_keys=("original_face_provenance","uv_texture_compatibility")
    evidence={key:json.loads((ROOT/manifest[key]).read_text(encoding="utf-8")) for key in evidence_keys}
    source_paths={manifest_path,glb,sidecar,prep,ROOT/manifest["validation_report"],*(ROOT/manifest[key] for key in evidence_keys)}
    before={str(path):skin_schema.sha(path) for path in source_paths}
    passed=0;failures=[];rejections=[]
    def check(condition,label):
        nonlocal passed
        if condition: passed+=1
        else: failures.append(label)
    check(result["selected_original_triangles"]==438,"all reviewed 438 original triangles")
    check(result["added_face_vertices"]==0,"no added geometry")
    check(result["actual_texture_ids_reused"] is False,"no actual asset ID inferred from a byte proof")
    check(result["original_triangles_only"] is True,"exact original-only policy")
    out=ROOT/"build/skin_runtime_v2/face_union_v1";out.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="union_negative_",dir=out) as temp:
        temp=Path(temp)
        def refuse(label,manifest_edit=None,evidence_key=None,evidence_edit=None,doc_edit=None,binary_edit=None):
            nonlocal passed
            changed=copy.deepcopy(manifest)
            if manifest_edit: manifest_edit(changed)
            if evidence_key:
                row=copy.deepcopy(evidence[evidence_key]);evidence_edit(row)
                path=temp/(evidence_key+".json");path.write_text(json.dumps(row),encoding="utf-8")
                changed[evidence_key]=path.relative_to(ROOT).as_posix()
                # Reseal deliberately so content errors are not masked by a
                # generic SHA failure. Production evidence is never rewritten.
                changed[evidence_key+"_sha256"]=skin_schema.sha(path)
            current=copy.deepcopy(doc)
            if doc_edit: doc_edit(current)
            current_binary=bytearray(binary)
            if binary_edit: binary_edit(current,current_binary)
            try: proof.verify(changed,blueprint,checked,report,current,bytes(current_binary),prep,schema.workspace_file)
            except (skin_schema.RigError,ValueError,KeyError,TypeError,IndexError):
                passed+=1;rejections.append(label)
            else: failures.append("accepted "+label)
        refuse("wrong union variant",manifest_edit=lambda d:d.update(candidate_variant="cap"))
        refuse("missing original-only flag",manifest_edit=lambda d:d.update(original_triangles_only=False))
        refuse("wrong original face count",manifest_edit=lambda d:d.update(selected_original_face_triangles=437))
        refuse("declared added vertex",manifest_edit=lambda d:d.update(new_mouth_cap_vertices=1))
        refuse("unmatched provenance SHA",manifest_edit=lambda d:d.update(original_face_provenance_sha256="0"*64))
        p="original_face_provenance"
        refuse("foreign provenance avatar",evidence_key=p,evidence_edit=lambda d:d.update(avatar="Costume_Other"))
        refuse("foreign provenance GLB",evidence_key=p,evidence_edit=lambda d:d.update(expression_skin_sha256="0"*64))
        refuse("premature provenance promotion",evidence_key=p,evidence_edit=lambda d:d.update(ready=True))
        refuse("wrong source skin digest",evidence_key=p,evidence_edit=lambda d:d.update(source_skin_sha256="0"*64))
        refuse("invented original head count",evidence_key=p,evidence_edit=lambda d:d.update(original_head_triangles=5013))
        refuse("invented new vertex",evidence_key=p,evidence_edit=lambda d:d.update(new_vertices=1))
        refuse("missing exact face row",evidence_key=p,evidence_edit=lambda d:d["triangles"].pop())
        refuse("wrong source face index",evidence_key=p,evidence_edit=lambda d:d["triangles"][0].update(original_head_face_index=-1))
        refuse("wrong expression triangle order",evidence_key=p,evidence_edit=lambda d:d["triangles"][0].update(expression_face_index=1))
        refuse("reversed oriented triangle",evidence_key=p,evidence_edit=lambda d:d["triangles"][0]["original_vertex_indices"].reverse())
        refuse("altered original triangle UV",evidence_key=p,evidence_edit=lambda d:d["triangles"][0]["original_uv"][0].__setitem__(0,0))
        refuse("reordered source face index list",evidence_key=p,evidence_edit=lambda d:d["source_face_indices"].reverse())
        refuse("wrong actual index digest",evidence_key=p,evidence_edit=lambda d:d.update(oriented_original_indices_sha256="0"*64))
        refuse("missing facial vertex row",evidence_key=p,evidence_edit=lambda d:d["vertices"].pop())
        refuse("duplicated vertex row",evidence_key=p,evidence_edit=lambda d:d["vertices"].__setitem__(0,copy.deepcopy(d["vertices"][1])))
        for field in ("position","normal","original_uv","joints","weights"):
            refuse("altered original vertex "+field,evidence_key=p,evidence_edit=lambda d,field=field:d["vertices"][0][field].__setitem__(0,d["vertices"][0][field][0]+1))
        refuse("wrong skin influence slot order",evidence_key=p,evidence_edit=lambda d:d["joint_slot_order"].reverse())
        c="uv_texture_compatibility"
        refuse("foreign previous manifest SHA",evidence_key=c,evidence_edit=lambda d:d.update(comparison_manifest_sha256="0"*64))
        refuse("foreign previous skin SHA",evidence_key=c,evidence_edit=lambda d:d.update(comparison_skin_sha256="0"*64))
        refuse("wrong full accessor vertex count",evidence_key=c,evidence_edit=lambda d:d.update(original_head_vertices_compared=1))
        refuse("false full accessor UV proof",evidence_key=c,evidence_edit=lambda d:d.update(normalized_original_face_uv_float32_exact=False))
        refuse("new mesh reuse claim",evidence_key=c,evidence_edit=lambda d:d.update(mesh_asset_reimport_required=False))
        refuse("incorrect current UV float32 digest",evidence_key=c,evidence_edit=lambda d:d.update(normalized_original_face_uv_sha256="0"*64))
        refuse("incorrect previous UV float32 digest",evidence_key=c,evidence_edit=lambda d:d.update(canonical_normalized_original_face_uv_sha256="0"*64))
        refuse("missing previous expression correspondence",evidence_key=c,evidence_edit=lambda d:d["expression_pngs"].pop())
        refuse("altered approved PNG digest",evidence_key=c,evidence_edit=lambda d:d["expression_pngs"][0].update(sha256="0"*64))
        refuse("altered approved PNG path",evidence_key=c,evidence_edit=lambda d:d["expression_pngs"][0].update(png="art/out/v1/rejected.png"))
        refuse("changed face material color",doc_edit=lambda d:d["materials"][2]["pbrMetallicRoughness"].update(baseColorFactor=[.5,.5,.5,1]))
        def perturb(doc,content,accessor):
            row=doc["accessors"][accessor];view=doc["bufferViews"][row["bufferView"]]
            offset=view.get("byteOffset",0)+row.get("byteOffset",0)
            fmt={5121:"B",5123:"H",5125:"I",5126:"f"}[row["componentType"]]
            value=struct.unpack_from("<"+fmt,content,offset)[0]
            struct.pack_into("<"+fmt,content,offset,value+1)
        face=doc["meshes"][2]["primitives"][0]
        refuse("changed actual entire normalized face UV",binary_edit=lambda d,b:perturb(d,b,face["attributes"]["TEXCOORD_0"]))
        # Re-write adversarial GLBs and reseal the producer report, then run
        # the real producer inspector. A `validated=true` report cannot grant
        # trust to changed bytes or bone hierarchy.
        def refuse_glb(label,doc_edit=None,accessor=None):
            nonlocal passed
            changed=copy.deepcopy(doc);content=bytearray(binary)
            if doc_edit: doc_edit(changed)
            if accessor is not None: perturb(changed,content,accessor)
            path=temp/"tampered.glb";write_glb(path,changed,bytes(content))
            resealed=copy.deepcopy(report);resealed["sha256"]=skin_schema.sha(path)
            path.with_suffix(".json").write_text(json.dumps(resealed),encoding="utf-8")
            try: inspect(path,prep)
            except (skin_schema.RigError,ValueError,KeyError,TypeError,IndexError):
                passed+=1;rejections.append(label)
            else: failures.append("accepted actual GLB "+label)
        for field in ("POSITION","NORMAL","TEXCOORD_0","JOINTS_0","WEIGHTS_0"):
            refuse_glb("altered actual face "+field,accessor=face["attributes"][field])
        refuse_glb("altered actual oriented index",accessor=face["indices"])
        bone=doc["skins"][0]["joints"][0]
        refuse_glb("altered actual bone hierarchy",doc_edit=lambda d:d["nodes"][bone].update(name="ForeignBone"))
        # Separate path/SHA boundary checks; unlike the semantic tests above,
        # these intentionally do not reseal the sidecar's trusted pointers.
        for label,edit in (("wrong manifest SHA",lambda d:d.update(expression_manifest_sha256="0"*64)),
                           ("wrong validation SHA",lambda d:d.update(expression_validation_sha256="0"*64)),
                           ("wrong validation path",lambda d:d.update(expression_validation=str(FOLDER/"skin_validation.json")))):
            changed=copy.deepcopy(blueprint);edit(changed)
            try: schema.load(manifest_path,changed)
            except (skin_schema.RigError,ValueError,KeyError,TypeError):
                passed+=1;rejections.append(label)
            else: failures.append("accepted "+label)
    for path,digest in before.items(): check(skin_schema.sha(Path(path))==digest,"source bytes unchanged: "+path)
    summary={"checks":passed,"failures":failures,"negative_cases":rejections,"original_triangles":438,
             "original_vertices":len(evidence["original_face_provenance"]["vertices"]),"added_vertices":0,
             "skin_sha256":blueprint["skin_sha256"],"studio_calls":0,"api_calls":0,
             "source_changed":False,"actual_importer_or_animation_claimed":False,"promotion":False}
    (out/"face_union_offline_qa.json").write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({key:value for key,value in summary.items() if key!="negative_cases"}))
    return int(bool(failures))


if __name__=="__main__": raise SystemExit(main())
