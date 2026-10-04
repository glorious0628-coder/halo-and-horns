"""Adapt exact reviewed Head-weight sources to separate expression copies."""
from pathlib import Path
import json

from constraints import RigError
import skin_face_weight_proof as proof


def matches(data):
    return any(data.get("weight_correction_plan_sha256")==row[1] for row in proof.RULES.values())


def validate_sidecar(path):
    path=Path(path).resolve();data=json.loads(path.read_text(encoding="utf-8"))
    if not matches(data):raise RigError("An unknown Head correction cannot use the reviewed source exception")
    if not data.get("expression_manifest"):
        return proof.validate(path)
    original=Path(data["original_two_surface_skin"]).resolve()
    verified=proof.validate(original.with_suffix(".skin.json"))
    if proof.sha(original)!=data.get("original_two_surface_skin_sha256") or proof.sha(original)!=verified["output_sha256"]:
        raise RigError("Head expression references a different corrected source")
    if path.parent!=proof.ROOT/"art/models/costume/expressions"/verified["name"]:
        raise RigError("Head expression evidence must be stored under its exact costume")
    for key in ("schema","rig_origin","source","source_sha256","source_to_game_affine","affine_layout","source_frame_policy",
        "bones","proxy_plan","proxy_plan_sha256","weight_correction_plan_sha256","original_benchmark_skin_sha256",
        "weight_correction_chain","changed_skin_vertices","changed_facial_vertices","original_source_weights_exact"):
        if data.get(key)!=verified.get(key):raise RigError("Head expression changed its verified source metadata: "+key)
    if data.get("rig_ready_for_game") is not False or data.get("original_bones_claimed",True) is not True or data.get("inferred_bind_joints"):
        raise RigError("An exact original twenty-three-bone Head-weight source is required")
    data["name"]=verified["name"];data["face_weight_proof"]=verified["face_weight_proof"]
    return data


ASSEMBLE=r'''
    if DATA.face_weight_proof then
        local proof=DATA.face_weight_proof
        model:SetAttribute("HHC_FaceWeightProofSchema",1)
        model:SetAttribute("HHC_FaceWeightSourceSHA256",proof.source_skin_sha256)
        model:SetAttribute("HHC_FaceWeightSkinSHA256",proof.output_sha256)
        model:SetAttribute("HHC_FaceWeightPlanSHA256",proof.plan_sha256)
        model:SetAttribute("HHC_FaceWeightVertexCount",proof.changed_head_scope_vertices)
        model:SetAttribute("HHC_FaceWeightSourceBindsPreserved",true)
        model:SetAttribute("HHC_OriginalSkinWeightsPreserved",false)
    end
'''

VERIFY=r'''
if DATA.face_weight_proof then
    local proof=DATA.face_weight_proof
    requireCheck(model:GetAttribute("HHC_FaceWeightProofSchema")==1
        and model:GetAttribute("HHC_FaceWeightSourceSHA256")==proof.source_skin_sha256
        and model:GetAttribute("HHC_FaceWeightSkinSHA256")==proof.output_sha256
        and model:GetAttribute("HHC_FaceWeightPlanSHA256")==proof.plan_sha256
        and model:GetAttribute("HHC_FaceWeightVertexCount")==proof.changed_head_scope_vertices
        and model:GetAttribute("HHC_FaceWeightSourceBindsPreserved")==true
        and model:GetAttribute("HHC_OriginalSkinWeightsPreserved")==false,"얼굴 가중치의 정확한 원본/계획/선택정점")
end
'''
