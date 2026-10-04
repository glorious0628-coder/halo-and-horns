"""Explicit HornsMageM two-bind exception, never an original-skeleton claim.

The independent proof recomputes geometry, weights, inverse binds, proxy hinges
and local visual evidence. This adapter does not loosen any ordinary source
gate or promote a candidate, and never calls Studio or an upload API.
"""
from pathlib import Path
import json

from constraints import RigError
import skin_inferred_bind_proof as proof

ORIGIN="corrected_preserved_bind_skin_proxy_candidate"


def validate_sidecar(path):
    path=Path(path).resolve()
    data=json.loads(path.read_text(encoding="utf-8"))
    # Expression copies must be introduced through their own exact-source
    # proof later. A sidecar boolean or arbitrary third mesh never inherits
    # the reviewed two-surface anatomical exception.
    if data.get("expression_manifest"):
        raise RigError("An inferred-bind expression requires a separately reviewed exact surface proof")
    verified=proof.validate(path)
    if verified.get("name")!="Costume_HornsMageM" or verified.get("rig_origin")!=ORIGIN:
        raise RigError("The reviewed HornsMageM bind exception is required")
    selected=verified["inferred_bind_proof"]
    selected.update(skin_sha256=verified["output_sha256"],
        bind_plan_sha256=verified["bind_correction_plan_sha256"],
        proxy_plan_sha256=verified["proxy_plan_sha256"],
        proxy_runtime_sha256=verified["proxy_runtime_sha256"],
        proxy_runtime=verified["proxy_runtime"],
        source_contract_sha256=proof.sha(path))
    return verified


ASSEMBLE=r'''
    if DATA.inferred_bind_proof then
        local proof=DATA.inferred_bind_proof
        model:SetAttribute("HHC_InferredBindProofSchema",1)
        model:SetAttribute("HHC_InferredBindBaselineSHA256",proof.baseline_skin_sha256)
        model:SetAttribute("HHC_InferredBindSkinSHA256",proof.skin_sha256)
        model:SetAttribute("HHC_InferredBindPlanSHA256",proof.bind_plan_sha256)
        model:SetAttribute("HHC_InferredBindProxyRuntimeSHA256",proof.proxy_runtime_sha256)
        model:SetAttribute("HHC_InferredBindArmVertices",proof.changed_arm_vertices)
        model:SetAttribute("HHC_InferredBindHeadVertices",proof.changed_head_vertices)
        model:SetAttribute("HHC_OriginalBonesClaimed",false)
    end
'''

VERIFY=r'''
if DATA.inferred_bind_proof then
    local proof=DATA.inferred_bind_proof
    requireCheck(model:GetAttribute("HHC_InferredBindProofSchema")==1
        and model:GetAttribute("HHC_InferredBindBaselineSHA256")==proof.baseline_skin_sha256
        and model:GetAttribute("HHC_InferredBindSkinSHA256")==proof.skin_sha256
        and model:GetAttribute("HHC_InferredBindPlanSHA256")==proof.bind_plan_sha256
        and model:GetAttribute("HHC_InferredBindProxyRuntimeSHA256")==proof.proxy_runtime_sha256
        and model:GetAttribute("HHC_InferredBindArmVertices")==proof.changed_arm_vertices
        and model:GetAttribute("HHC_InferredBindHeadVertices")==proof.changed_head_vertices
        and model:GetAttribute("HHC_OriginalBonesClaimed")==false,"추정한 두 관절의 원본/계획/정점 범위")
end
'''
