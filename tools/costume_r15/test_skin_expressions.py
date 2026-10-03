"""Read-only final-expression byte proof and poisoned-manifest checks.

These checks do not claim native importer or engine motion success.
"""
from __future__ import annotations

import copy
import json
from pathlib import Path
import shutil
import tempfile

import skin_expression_schema as expressions
import skin_runtime as base
import skin_runtime_v2 as runtime

ROOT=Path(__file__).resolve().parents[2]
NAMES=("HaloArcherM","HaloWarriorM","NeutralWarriorF","NeutralArcherM","HaloArcherF","HornsArcherF")


def main():
    out=ROOT/"build/skin_runtime_v2";out.mkdir(exist_ok=True)
    passed=0;failures=[];rows=[]
    with tempfile.TemporaryDirectory(prefix="expression_proof_",dir=out) as temp:
        temp=Path(temp)
        for name in NAMES:
            folder=ROOT/"art/models/costume/expressions"/("Costume_"+name)
            manifest_path=folder/"skin_expressions_manifest.json"
            manifest=json.loads(manifest_path.read_text(encoding="utf-8"))
            sidecar=ROOT/Path(manifest["skin_asset"]).with_suffix(".skin.json")
            proxy=ROOT/"build/manual_partition_candidates"/(name+"_v3")/("r15_front" if name in ("NeutralWarriorF","NeutralArcherM") else "r15")/"joints.json" if not manifest["original_bones_claimed"] else None
            original=ROOT/"art/models/costume/prepared/skin"/("Costume_"+name+"_preserved_"+("v2" if name=="HaloArcherM" else "v1"))/"package.json" if manifest["original_bones_claimed"] else ROOT/"build/manual_partition_candidates"/(name+"_skin_"+("v3" if name in ("NeutralWarriorF","NeutralArcherM") else "v1"))/("Costume_"+name+"_skin.skin.json")
            source_hash=base.sha(sidecar)
            data,points=runtime.prepare(sidecar,"ServerStorage/CostumeExpressionSkinImports/Costume_"+name,proxy,expression_manifest=manifest_path,source_contract=original)
            if len(data["meshes"])!=3 or len(data["bones"])!=(23 if manifest["original_bones_claimed"] else 15): raise AssertionError("lost exact shared skin")
            passed+=1
            blueprint=runtime.skin_schema.load(sidecar,proxy)
            test_folder=temp/name;test_folder.mkdir()
            poisoned=test_folder/"skin_expressions_manifest.json"
            original_validation=json.loads((folder/"skin_validation.json").read_text(encoding="utf-8"))
            if not manifest.get("prepare_report"): shutil.copyfile(folder/"prepare_report.json",test_folder/"prepare_report.json")
            def refuse(label,edit=None,validation_edit=None):
                nonlocal passed
                changed=copy.deepcopy(manifest);validation=copy.deepcopy(original_validation)
                if edit: edit(changed)
                if validation_edit: validation_edit(validation)
                validation_path=poisoned.with_name("skin_validation.json")
                if changed.get("validation_report"):
                    changed["validation_report"]=validation_path.relative_to(ROOT).as_posix()
                poisoned.write_text(json.dumps(changed),encoding="utf-8")
                validation_path.write_text(json.dumps(validation),encoding="utf-8")
                # Hash/path guards are tested separately; re-seal these local
                # fixtures to exercise each underlying semantic rejection.
                fixture=copy.deepcopy(blueprint)
                fixture["expression_manifest_sha256"]=base.sha(poisoned)
                if fixture.get("expression_validation"):
                    fixture["expression_validation"]=str(validation_path)
                    fixture["expression_validation_sha256"]=base.sha(validation_path)
                try: expressions.load(poisoned,fixture)
                except (base.RigError,ValueError,KeyError,TypeError): passed+=1
                else: failures.append(name+" "+label)
            refuse("wrong costume",lambda d:d.update(avatar="Costume_Other"))
            refuse("wrong final GLB",lambda d:d.update(skin_sha256="0"*64))
            refuse("wrong original skin",lambda d:d.update(source_skin_sha256="0"*64))
            refuse("wrong fixed reference",lambda d:d.update(source_fixed_sha256="0"*64))
            refuse("false original bone claim",lambda d:d.update(original_bones_claimed=not d["original_bones_claimed"]))
            refuse("wrong joint count",lambda d:d.update(source_skin_bones=24))
            refuse("premature ready",lambda d:d.update(ready=True))
            refuse("premature runtime QA",lambda d:d.update(runtime_validated=True))
            refuse("wrong face surface",lambda d:d["meshes"].__setitem__(2,"Wrong"))
            refuse("missing expression",lambda d:d["records"].pop())
            refuse("unapproved state",lambda d:d["approved_states"].pop())
            refuse("altered PNG digest",lambda d:d["records"][0].update(sha256="0"*64))
            refuse("unproved GPT provenance",lambda d:d["records"][0].update(builtin_gpt_generated=False))
            refuse("unreviewed mouth",lambda d:d["records"][0].update(closed_mouth_offline_render_verified=False))
            refuse("false geometry proof",validation_edit=lambda d:d.update(original_body_primitive_exact=False))
            refuse("false joint proof",validation_edit=lambda d:d.update(original_skin_inverse_bind_and_bone_hierarchy_exact=False))
            refuse("stale validation",validation_edit=lambda d:d.update(skin_sha256="0"*64))
            if base.sha(sidecar)!=source_hash: failures.append(name+" source sidecar modified")
            face=points["FaceExpression"]
            rows.append({"name":data["name"],"bones":len(data["bones"]),"surfaces":3,"full_accessor_points":len(face["full_accessor"]),"referenced_points":len(face["referenced_triangles"]),"ready":False,"skin_sha256":data["skin_sha256"]})
    report={"checks":passed,"failures":failures,"costumes":rows,"studio_calls":0,"api_calls":0,"source_modified":False,"native_match_claimed":False,"promotion":False}
    (out/"expression_schema_offline_qa.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report));return int(bool(failures))


if __name__=="__main__": raise SystemExit(main())
