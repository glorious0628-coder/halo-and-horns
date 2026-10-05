# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
# Still importable as a library ONLY because live tools import it (tools/monster_import_preflight.py,
# tools/test_weapon_motion.py, GLB audit tools). Never run it directly.
"""Read-only proof for the reviewed three-surface expression skin contract."""
from __future__ import annotations

if __name__ == "__main__":
    raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import json
import hashlib
from pathlib import Path
import struct
import sys

import skin_schema
from constraints import RigError
from glb_io import image_bytes

ROOT=Path(__file__).resolve().parents[2]


def workspace_file(value):
    path=Path(value)
    path=(path if path.is_absolute() else ROOT/path).resolve();path.relative_to(ROOT)
    if path.is_relative_to(ROOT/"art/out/v1"): raise RigError("Rejected v1 assets are never inputs")
    if not path.is_file(): raise RigError("The exact declared local evidence file is missing")
    return path


def load(path,blueprint):
    path=Path(path).resolve();manifest=json.loads(path.read_text(encoding="utf-8"))
    if manifest.get("schema")!=1 or manifest.get("pipeline")!="preserved_continuous_skin_expression" or manifest.get("avatar")!=blueprint["name"]:
        raise RigError("The exact reviewed skin-expression manifest is required")
    glb=(ROOT/manifest["skin_asset"]).resolve();glb.relative_to(ROOT)
    if glb!=Path(blueprint["skin_glb"]).resolve() or skin_schema.sha(glb)!=manifest["skin_sha256"] or manifest["skin_sha256"]!=blueprint["skin_sha256"]:
        raise RigError("Expression manifest and exact inspected skin differ")
    if manifest.get("ready") is not False or manifest.get("runtime_validated") is not False or manifest.get("original_bones_claimed")!=blueprint["original_bones_claimed"] or manifest.get("source_skin_bones",blueprint["unique_bones"])!=blueprint["unique_bones"]:
        raise RigError("Only explicitly unvalidated original fifteen/twenty-three-bone expression candidates are supported")
    if set(manifest["meshes"])!={"CostumeSkinBody","HeadBase","FaceExpression"} or len(manifest["meshes"])!=3 or set(blueprint["visual_surfaces"])!=set(manifest["meshes"]):
        raise RigError("Exact Body/HeadBase/FaceExpression surfaces are required")
    if blueprint.get("expression_manifest_sha256") and skin_schema.sha(path)!=blueprint["expression_manifest_sha256"]:
        raise RigError("The selected expression manifest differs from its exact sidecar")
    validation_path=workspace_file(manifest["validation_report"]) if manifest.get("validation_report") else path.with_name("skin_validation.json")
    mouth=manifest.get("validation_kind")=="original_connected_mouth_pn_exception_v1"
    winding=manifest.get("validation_kind")=="original_connected_mouth_pn_winding_exception_v1"
    if manifest.get("validation_kind") is not None and not (mouth or winding): raise RigError("Unknown geometry exceptions are not expression validation")
    if mouth:
        if path.name!="face_union_mouth_manifest_v1.json" or blueprint.get("expression_validation_kind")!=manifest["validation_kind"]:
            raise RigError("Only the explicitly selected mouth manifest may use its separate validator")
    elif winding:
        if path.name!="face_union_mouth_winding_manifest_v1.json" or blueprint.get("expression_validation_kind")!=manifest["validation_kind"]:
            raise RigError("Only the exact selected winding manifest may use its separate validator")
    elif not validation_path.name.endswith("_validation.json"): raise RigError("A specifically named local validation report is required")
    if blueprint.get("expression_validation") and (workspace_file(blueprint["expression_validation"])!=validation_path or skin_schema.sha(validation_path)!=blueprint.get("expression_validation_sha256")):
        raise RigError("The declared validation report differs from its exact sidecar")
    validation=json.loads(validation_path.read_text(encoding="utf-8"))
    required=("validated","source_models_unchanged","original_non_facial_png_bytes_exact","original_body_primitive_exact","original_headbase_uv_exact",
              "original_face_position_normal_joint_weight_values_exact","original_skin_inverse_bind_and_bone_hierarchy_exact","original_oriented_triangles_partition_exact","reviewed_face_uv_signatures_exact")
    if not (mouth or winding) and (any(validation.get(key) is not True for key in required) or validation.get("skin_sha256")!=blueprint["skin_sha256"]):
        raise RigError("Current exact geometry/UV/image/shared-skeleton expression proof is required")
    prep=(ROOT/manifest["prepare_report"]).resolve() if manifest.get("prepare_report") else path.with_name("prepare_report.json")
    prep.relative_to(ROOT)
    # Re-run the owning producer's read-only byte/triangle/skin validation,
    # rather than accepting a stale `validated=true` JSON assertion.
    directory=ROOT/"tools/costume_expressions"
    if str(directory) not in sys.path: sys.path.insert(0,str(directory))
    from finalize_skin_assets import inspect
    mouth_result=None
    if mouth:
        from skin_face_union_proof import verify_mouth
        mouth_result,checked,report,doc,binary=verify_mouth(manifest,path,blueprint,validation_path,workspace_file)
    elif winding:
        from skin_mouth_winding_proof import verify
        mouth_result,checked,report,doc,binary=verify(manifest,path,blueprint,validation_path,workspace_file)
    else:
        # The existing canonical cap/original-union exact P/N check remains
        # unconditional on every non-mouth path, even if JSON says otherwise.
        checked,report,doc,binary=inspect(glb,prep)
    if checked["source_skin_bones"]!=blueprint["unique_bones"] or checked["skin_sha256"]!=manifest["skin_sha256"] or report["source_skin_sha256"]!=manifest["source_skin_sha256"] or report["source_fixed_sha256"]!=manifest["source_fixed_sha256"]:
        raise RigError("Current source/reference proof disagrees with expression manifest")
    if checked["original_triangles_only"]!=manifest.get("original_triangles_only",False):
        raise RigError("Original-only versus mouth-cover geometry policy changed")
    states={};records=manifest.get("records",[])
    if len(records)!=3 or set(manifest.get("approved_states",[]))!={"Neutral","SoftSmile","Serious"}:
        raise RigError("Exactly three approved expression states are required")
    for record in records:
        state=record["state"];png=(ROOT/record["png"]).resolve();png.relative_to(ROOT)
        raw=png.read_bytes()
        if state in states or state not in ("Neutral","SoftSmile","Serious") or record.get("builtin_gpt_generated") is not True or record.get("closed_mouth_offline_render_verified") is not True:
            raise RigError("Exact reviewed GPT expression provenance is required")
        if raw[:8]!=b"\x89PNG\r\n\x1a\n" or list(struct.unpack_from(">II",raw,16))!=record["size"] or skin_schema.sha(png)!=record["sha256"]:
            raise RigError("Expression image bytes or size changed")
        states[state]={"png":png.relative_to(ROOT).as_posix(),"sha256":record["sha256"]}
    if hashlib.sha256(image_bytes(doc,binary,doc["images"][2])).hexdigest()!=states["Neutral"]["sha256"]:
        raise RigError("The actual embedded face image is not the reviewed Neutral PNG")
    result={"schema":1,"manifest_sha256":skin_schema.sha(path),"validation_sha256":skin_schema.sha(validation_path),
            "original_skin_sha256":manifest["source_skin_sha256"],"source_fixed_sha256":manifest["source_fixed_sha256"],"states":states,
            "face_mesh_name":"FaceExpression","head_bone_name":"Head","runtime_validated":False,"expression_validated":False}
    if mouth_result is not None:
        result.update(mouth_result)
    elif checked["original_triangles_only"]:
        from skin_face_union_proof import verify
        result.update(verify(manifest,blueprint,checked,report,doc,binary,prep,workspace_file))
    return result


ASSEMBLE = r'''
    if DATA.expression then
        local face,headBone=nil,nil
        for _,object in skin:GetDescendants() do
            if object:IsA("MeshPart") and object.Name=="FaceExpression" then if face then error("표정 메시 중복") end;face=object end
            if object:IsA("Bone") and object.Name=="Head" then if headBone then error("표정의 실제 공유 Head 뼈가 불명확합니다.") end;headBone=object end
        end
        if not face or not headBone or headBone:GetAttribute("HHC_SkinPrincipal")~=true or headBone:GetAttribute("HHC_SkinBonePart")~="Head" then error("정확한 표정 메시/공유 Head 뼈가 없습니다.") end
        for _,object in face:GetChildren() do if object:IsA("SurfaceAppearance") then error("표정 텍스처 전환을 가리는 SurfaceAppearance") end end
        local host=headBone.Parent
        while host and host~=skin and not host:IsA("BasePart") do host=host.Parent end
        if not host or not host:IsA("BasePart") then error("표정의 실제 Bone host 없음") end
        local weld=face:FindFirstChild(DATA.binding and "CostumeSkinInternalWeld" or "CostumeSkinRootWeld")
        if DATA.binding then
            local value=skin:FindFirstChild("HHC_SkinBindingHost")
            if not value or not value:IsA("ObjectValue") or not value.Value or not weld or not weld:IsA("Weld") or not weld.Enabled
                or weld.Part0~=value.Value or weld.Part1~=face then error("정확한 표정 내부 skin Weld 없음") end
        elseif not weld or not weld:IsA("WeldConstraint") or not weld.Enabled or weld.Part0~=root or weld.Part1~=face then error("정확한 표정 Root weld 없음") end
        for name,target in {HHC_ExpressionSkinBoneHost=host,HHC_ExpressionSkinHeadBone=headBone,HHC_ExpressionSkinRootWeld=weld} do
            if face:FindFirstChild(name) then error("원본에 미검증 표정 참조가 있습니다.") end
            local value=Instance.new("ObjectValue");value.Name=name;value.Value=target;value.Parent=face
        end
        model:SetAttribute("HHC_OriginalSkinSHA256",DATA.expression.original_skin_sha256)
        model:SetAttribute("HHC_ExpressionManifestSHA256",DATA.expression.manifest_sha256)
        model:SetAttribute("HHC_ExpressionValidationSHA256",DATA.expression.validation_sha256)
        model:SetAttribute("HHC_ExpressionInspectionSHA256",FIT.inspection_sha256)
        model:SetAttribute("HHC_ExpressionSkinRuntimeSchema",1)
        if DATA.expression.original_triangles_only then
            model:SetAttribute("HHC_ExpressionOriginalTrianglesOnly",true)
            model:SetAttribute("HHC_ExpressionFaceProvenanceSHA256",DATA.expression.face_provenance_sha256)
            model:SetAttribute("HHC_ExpressionUVCompatibilitySHA256",DATA.expression.uv_compatibility_sha256)
        end
        if DATA.expression.mouth_restoration_schema then
            model:SetAttribute("HHC_ExpressionMouthRestorationSchema",DATA.expression.mouth_restoration_schema)
            model:SetAttribute("HHC_ExpressionMouthRestorationLedgerSHA256",DATA.expression.mouth_restoration_ledger_sha256)
            model:SetAttribute("HHC_ExpressionMouthOriginalUnionSHA256",DATA.expression.original_union_sha256)
            model:SetAttribute("HHC_ExpressionMouthChangedVertices",DATA.expression.mouth_changed_original_vertices)
            model:SetAttribute("HHC_ExpressionMouthRuntimeContractSHA256",DATA.expression.mouth_runtime_contract_sha256)
            model:SetAttribute("HHC_ExpressionMouthPNExceptionKind",DATA.expression.validation_kind)
        end
        if DATA.expression.mouth_winding_schema then
            model:SetAttribute("HHC_ExpressionMouthWindingSchema",DATA.expression.mouth_winding_schema)
            model:SetAttribute("HHC_ExpressionMouthWindingLedgerSHA256",DATA.expression.mouth_winding_ledger_sha256)
            model:SetAttribute("HHC_ExpressionMouthWindingOriginalTriangles",DATA.expression.mouth_winding_original_triangles)
            model:SetAttribute("HHC_ExpressionMouthWindingParentSHA256",DATA.expression.mouth_winding_parent_sha256)
        end
        model:SetAttribute("HHC_ExpressionSkinValidated",false);model:SetAttribute("HHC_ExpressionRuntimeValidated",false)
        face:SetAttribute("HHC_ExpressionMeshValidated",false);face:SetAttribute("HHC_ExpressionSkinValidated",false)
        face:SetAttribute("HHC_SkinSourceSHA256",DATA.skin_sha256)
        face:SetAttribute("HHC_ExpressionSkinMeshId",face.MeshId)
    end
'''


VERIFY = r'''
if DATA.expression then
    if DATA.expression.mouth_winding_schema then
        requireCheck(model:GetAttribute("HHC_ExpressionMouthWindingSchema")==DATA.expression.mouth_winding_schema
            and model:GetAttribute("HHC_ExpressionMouthWindingLedgerSHA256")==DATA.expression.mouth_winding_ledger_sha256
            and model:GetAttribute("HHC_ExpressionMouthWindingOriginalTriangles")==DATA.expression.mouth_winding_original_triangles
            and model:GetAttribute("HHC_ExpressionMouthWindingParentSHA256")==DATA.expression.mouth_winding_parent_sha256,"제한된 원본 입 면 방향 교정 출처")
    end
    if DATA.expression.mouth_restoration_schema then
        requireCheck(model:GetAttribute("HHC_ExpressionMouthRestorationSchema")==DATA.expression.mouth_restoration_schema
            and model:GetAttribute("HHC_ExpressionMouthRestorationLedgerSHA256")==DATA.expression.mouth_restoration_ledger_sha256
            and model:GetAttribute("HHC_ExpressionMouthOriginalUnionSHA256")==DATA.expression.original_union_sha256
            and model:GetAttribute("HHC_ExpressionMouthChangedVertices")==DATA.expression.mouth_changed_original_vertices
            and model:GetAttribute("HHC_ExpressionMouthRuntimeContractSHA256")==DATA.expression.mouth_runtime_contract_sha256
            and model:GetAttribute("HHC_ExpressionMouthPNExceptionKind")==DATA.expression.validation_kind,"제한된 입 원본 P/N 예외 출처")
    end
    if DATA.expression.original_triangles_only then
        requireCheck(model:GetAttribute("HHC_ExpressionOriginalTrianglesOnly")==true and model:GetAttribute("HHC_ExpressionFaceProvenanceSHA256")==DATA.expression.face_provenance_sha256
            and model:GetAttribute("HHC_ExpressionUVCompatibilitySHA256")==DATA.expression.uv_compatibility_sha256,"원본 얼굴 면/UV 호환 출처")
    end
    requireCheck(model:GetAttribute("HHC_OriginalSkinSHA256")==DATA.expression.original_skin_sha256 and model:GetAttribute("HHC_ExpressionManifestSHA256")==DATA.expression.manifest_sha256
        and model:GetAttribute("HHC_ExpressionValidationSHA256")==DATA.expression.validation_sha256 and model:GetAttribute("HHC_ExpressionInspectionSHA256")==FIT.inspection_sha256,"표정 출처")
    requireCheck(model:GetAttribute("HHC_ExpressionSkinRuntimeSchema")==1 and model:GetAttribute("HHC_ExpressionSkinValidated")==false and model:GetAttribute("HHC_ExpressionRuntimeValidated")==false,"표정 QA 전 상태")
    local face,headBone=nil,nil
    for _,object in skin:GetDescendants() do
        if object:IsA("MeshPart") and object.Name=="FaceExpression" then requireCheck(not face,"표정 메시 중복");face=object end
        if object:IsA("Bone") and object.Name=="Head" then requireCheck(not headBone,"공유 Head 뼈 중복");headBone=object end
    end
    requireCheck(face and headBone,"정확한 FaceExpression/Head 뼈")
    local host=headBone.Parent
    while host and host~=skin and not host:IsA("BasePart") do host=host.Parent end
    requireCheck(host and host:IsA("BasePart") and host:IsDescendantOf(skin),"실제 표정 공유 Bone host")
    local weld=unique(face,DATA.binding and "CostumeSkinInternalWeld" or "CostumeSkinRootWeld")
    if DATA.binding then
        requireCheck(weld and weld:IsA("Weld") and weld.Enabled and weld.Part0==bindingAnchor and weld.Part1==face,"표정 같은 Model 내부 skin Weld")
    else requireCheck(weld and weld:IsA("WeldConstraint") and weld.Enabled and weld.Part0==root and weld.Part1==face,"표정 Root weld") end
    for name,target in {HHC_ExpressionSkinBoneHost=host,HHC_ExpressionSkinHeadBone=headBone,HHC_ExpressionSkinRootWeld=weld} do
        local value=unique(face,name)
        requireCheck(value and value:IsA("ObjectValue") and value.Value==target and target:IsDescendantOf(skin),"표정 실제 참조: "..name)
    end
    requireCheck(face:GetAttribute("HHC_ExpressionMeshValidated")==false and face:GetAttribute("HHC_ExpressionSkinValidated")==false
        and face:GetAttribute("HHC_SkinSourceSHA256")==DATA.skin_sha256 and face:GetAttribute("HHC_ExpressionSkinMeshId")==face.MeshId,"표정 메시 표식")
    requireCheck(headBone:GetAttribute("HHC_SkinPrincipal")==true and headBone:GetAttribute("HHC_SkinBonePart")=="Head","실제 표정 Head 본")
    for _,object in face:GetChildren() do requireCheck(not object:IsA("SurfaceAppearance"),"표정 SurfaceAppearance 거절") end
    for _,object in model:GetDescendants() do
        if object:IsA("JointInstance") or object:IsA("WeldConstraint") then
            if object.Part0==face or object.Part1==face then requireCheck(object==weld,"Head 직접결합/표정 중복 변환 거절") end
        end
    end
end
'''
