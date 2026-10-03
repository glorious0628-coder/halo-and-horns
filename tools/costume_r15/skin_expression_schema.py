"""Read-only proof for the reviewed three-surface expression skin contract."""
from __future__ import annotations

import json
from pathlib import Path
import struct
import sys

import skin_schema
from constraints import RigError

ROOT=Path(__file__).resolve().parents[2]


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
    validation_path=path.with_name("skin_validation.json");validation=json.loads(validation_path.read_text(encoding="utf-8"))
    required=("validated","source_models_unchanged","original_non_facial_png_bytes_exact","original_body_primitive_exact","original_headbase_uv_exact",
              "original_face_position_normal_joint_weight_values_exact","original_skin_inverse_bind_and_bone_hierarchy_exact","original_oriented_triangles_partition_exact","reviewed_face_uv_signatures_exact")
    if any(validation.get(key) is not True for key in required) or validation.get("skin_sha256")!=blueprint["skin_sha256"]:
        raise RigError("Current exact geometry/UV/image/shared-skeleton expression proof is required")
    prep=(ROOT/manifest["prepare_report"]).resolve() if manifest.get("prepare_report") else path.with_name("prepare_report.json")
    prep.relative_to(ROOT)
    # Re-run the owning producer's read-only byte/triangle/skin validation,
    # rather than accepting a stale `validated=true` JSON assertion.
    directory=ROOT/"tools/costume_expressions"
    if str(directory) not in sys.path: sys.path.insert(0,str(directory))
    from finalize_skin_assets import inspect
    checked,report,doc,binary=inspect(glb,prep)
    if checked["source_skin_bones"]!=blueprint["unique_bones"] or checked["skin_sha256"]!=manifest["skin_sha256"] or report["source_skin_sha256"]!=manifest["source_skin_sha256"] or report["source_fixed_sha256"]!=manifest["source_fixed_sha256"]:
        raise RigError("Current source/reference proof disagrees with expression manifest")
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
    return {"schema":1,"manifest_sha256":skin_schema.sha(path),"validation_sha256":skin_schema.sha(validation_path),
            "original_skin_sha256":manifest["source_skin_sha256"],"source_fixed_sha256":manifest["source_fixed_sha256"],"states":states,
            "face_mesh_name":"FaceExpression","head_bone_name":"Head","runtime_validated":False,"expression_validated":False}


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
        local weld=face:FindFirstChild("CostumeSkinRootWeld")
        if not weld or not weld:IsA("WeldConstraint") or not weld.Enabled or weld.Part0~=root or weld.Part1~=face then error("정확한 표정 Root weld 없음") end
        for name,target in {HHC_ExpressionSkinBoneHost=host,HHC_ExpressionSkinHeadBone=headBone,HHC_ExpressionSkinRootWeld=weld} do
            if face:FindFirstChild(name) then error("원본에 미검증 표정 참조가 있습니다.") end
            local value=Instance.new("ObjectValue");value.Name=name;value.Value=target;value.Parent=face
        end
        model:SetAttribute("HHC_OriginalSkinSHA256",DATA.expression.original_skin_sha256)
        model:SetAttribute("HHC_ExpressionManifestSHA256",DATA.expression.manifest_sha256)
        model:SetAttribute("HHC_ExpressionValidationSHA256",DATA.expression.validation_sha256)
        model:SetAttribute("HHC_ExpressionInspectionSHA256",FIT.inspection_sha256)
        model:SetAttribute("HHC_ExpressionSkinRuntimeSchema",1)
        model:SetAttribute("HHC_ExpressionSkinValidated",false);model:SetAttribute("HHC_ExpressionRuntimeValidated",false)
        face:SetAttribute("HHC_ExpressionMeshValidated",false);face:SetAttribute("HHC_ExpressionSkinValidated",false)
        face:SetAttribute("HHC_SkinSourceSHA256",DATA.skin_sha256)
        face:SetAttribute("HHC_ExpressionSkinMeshId",face.MeshId)
    end
'''


VERIFY = r'''
if DATA.expression then
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
    local weld=unique(face,"CostumeSkinRootWeld")
    requireCheck(weld and weld:IsA("WeldConstraint") and weld.Enabled and weld.Part0==root and weld.Part1==face,"표정 Root weld")
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
