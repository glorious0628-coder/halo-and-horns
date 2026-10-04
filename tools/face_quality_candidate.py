"""Prepare unapproved, offline image-only GLB quality candidates and CG proof.

Original files, skin bytes and production registration remain unchanged. No
Studio, upload or paid API calls. Existing runtime poses are copied only for
diagnostic renders; the copied source hash identifies the exact local candidate.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import copy
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import sys

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, sobel, zoom

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/costume_r15"))
from glb_io import image_bytes, read_glb, view_bytes, write_glb

SOURCE = ROOT / "art/models/costume/expressions/Costume_HaloArcherM/Costume_HaloArcherM_FaceUnionMouthRestored_v1.glb"
SOURCE_SHA = "17972af93f7ecd176f96af8db81fdff00c04e055a1d340b9dd9f288196d54584"
CAMERA = SOURCE.with_suffix(".json")
POSE = ROOT / "build/expr_qa/Costume_HaloArcherM/game_fx_neck_mouth_restored_v1_lit/HurtBig_0_06_expression_pose.json"
HEAD_2048 = ROOT / "build/face_quality_audit_20261004/HaloArcherM_rebake2048_v1/HeadTex2048_direct_raw_same_uv.png"
PROTECTED_FIELDS = ("accessors", "meshes", "nodes", "skins", "animations", "materials", "textures", "samplers", "scenes", "scene")


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save_json(path, value):
    if path.exists():
        raise ValueError("Refuse to overwrite existing output: "+str(path))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")


def image_report(payload):
    image = Image.open(io.BytesIO(payload))
    return {"sha256":hashlib.sha256(payload).hexdigest(), "size":list(image.size), "mode":image.mode, "bytes":len(payload)}


def replace_images(source, output, replacements):
    original, original_binary, original_bytes = read_glb(source)
    document = copy.deepcopy(original)
    binary = original_binary
    changes = []
    for image_index, png in replacements.items():
        payload = Path(png).read_bytes()
        binary += b"\0" * (-len(binary) % 4)
        offset = len(binary)
        binary += payload
        document["bufferViews"].append({"buffer":0, "byteOffset":offset, "byteLength":len(payload)})
        document["images"][image_index]["bufferView"] = len(document["bufferViews"])-1
        changes.append({"image_index":image_index,"png":str(png),"original":image_report(image_bytes(original, original_binary, original["images"][image_index])),
                        "candidate":image_report(payload)})
    document["buffers"][0]["byteLength"] = len(binary)
    if output.exists():
        raise ValueError("Refuse to overwrite candidate")
    write_glb(output, document, binary)
    actual, actual_binary, actual_bytes = read_glb(output)
    fields = {key:original.get(key)==actual.get(key) for key in PROTECTED_FIELDS}
    original_views = all(view_bytes(original, original_binary, index)[1] == view_bytes(actual, actual_binary, index)[1]
                         for index in range(len(original["bufferViews"])))
    preserved_images = {str(index):image_bytes(original, original_binary, row)==image_bytes(actual, actual_binary, actual["images"][index])
                        for index, row in enumerate(original["images"]) if index not in replacements}
    updated_images = {str(index):Path(png).read_bytes()==image_bytes(actual, actual_binary, actual["images"][index])
                      for index,png in replacements.items()}
    normalized = copy.deepcopy(actual)
    normalized["bufferViews"] = normalized["bufferViews"][:len(original["bufferViews"])]
    normalized["buffers"] = original["buffers"]
    normalized["images"] = original["images"]
    if not all(fields.values()) or not original_views or not all(preserved_images.values()) or not all(updated_images.values()) or normalized != original:
        raise ValueError("Image-only candidate exact byte proof failed")
    if source.read_bytes() != original_bytes:
        raise ValueError("Original source changed")
    return {"source":str(source),"source_sha256":hashlib.sha256(original_bytes).hexdigest(),"candidate":str(output),
            "candidate_sha256":hashlib.sha256(actual_bytes).hexdigest(),"image_changes":changes,
            "geometry_uv_bones_weights_materials_json_exact":fields,"all_original_buffer_views_bytes_exact":original_views,
            "preserved_image_bytes_exact":preserved_images,"new_image_png_bytes_exact":updated_images,
            "normalized_document_identical_except_explicit_images":normalized==original,
            "source_bytes_unchanged":True,"design_approved":False,"uploads":0,"native_qa_done":False,"ready_for_game":False}


def drift(original_payload, candidate_payload):
    reference = np.asarray(Image.open(io.BytesIO(original_payload)).convert("RGB"), dtype=np.float64)/255.
    candidate = np.asarray(Image.open(io.BytesIO(candidate_payload)).convert("RGB"), dtype=np.float64)/255.
    original_candidate_shape = candidate.shape
    normalized_analysis_only = False
    if reference.shape != candidate.shape:
        if candidate.shape[0] != candidate.shape[1] or reference.shape[0] != reference.shape[1]:
            return {"status":"non-square canvas; aligned chart drift not asserted"}
        ratio = reference.shape[0]/candidate.shape[0]
        candidate = zoom(candidate,(ratio,ratio,1),order=1)
        normalized_analysis_only = True
    weights = np.asarray([.2126,.7152,.0722])
    a, b = reference@weights, candidate@weights
    smooth_a, smooth_b = gaussian_filter(a,3), gaussian_filter(b,3)
    profile_path = SOURCE.parent/"facial_profile.json"
    profile = json.loads(profile_path.read_text(encoding="utf-8"))
    result = []
    scale = reference.shape[0]/768
    for eye, box in enumerate(profile["eye_boxes"]):
        left,top,right,bottom = [int(round(value*scale)) for value in box]
        template = smooth_a[top:bottom,left:right]
        centered = template-template.mean()
        best = (-np.inf, 0, 0)
        for dy in range(-12,13):
            for dx in range(-12,13):
                region = smooth_b[top+dy:bottom+dy,left+dx:right+dx]
                if region.shape != centered.shape:
                    continue
                target = region-region.mean()
                denominator = np.sqrt((centered*centered).sum()*(target*target).sum())
                score = float((centered*target).sum()/denominator) if denominator else 0.
                if score > best[0]:
                    best = (score,dx,dy)
        original_edge = np.hypot(sobel(a[top:bottom,left:right],axis=0),sobel(a[top:bottom,left:right],axis=1))
        candidate_edge = np.hypot(sobel(b[top:bottom,left:right],axis=0),sobel(b[top:bottom,left:right],axis=1))
        result.append({"eye":"closed_left" if eye==0 else "open_right","pixel_box":[left,top,right,bottom],
                       "best_candidate_relative_translation_px":[best[1],best[2]],"normalized_low_frequency_correlation":best[0],
                       "candidate_to_original_mean_sobel_magnitude_ratio":float(candidate_edge.mean()/original_edge.mean()),
                       "search_limit_px":12,"gaussian_sigma_for_alignment":3})
    return {"status":"local translation estimates only; visual approval required","eyes":result,
            "shape_or_style_equivalence_asserted":False,"automatic_visual_approval":False,
            "original_candidate_canvas":list(original_candidate_shape[:2]),"alignment_reference_canvas":list(reference.shape[:2]),
            "analysis_array_only_normalized_to_reference_canvas":normalized_analysis_only,"candidate_png_pixels_rewritten":False,
            "method":"reference1254 canvas; low-frequency normalized patch correlation in existing reviewed eye boxes; +/-12px translation; edge ratio is not a universal quality score"}


def copy_pose(source_glb, output, source_pose=POSE):
    pose = json.loads(source_pose.read_text(encoding="utf-8"))
    if pose["source_sha256"] != SOURCE_SHA:
        raise ValueError("Existing runtime pose does not identify exact production source")
    original = copy.deepcopy(pose)
    pose["source_sha256"] = sha(source_glb)
    save_json(output,pose)
    normalized = copy.deepcopy(pose)
    normalized["source_sha256"] = original["source_sha256"]
    if normalized != original:
        raise ValueError("Runtime pose angles or provenance changed")
    return {"original_pose":str(source_pose),"original_pose_sha256":sha(source_pose),"candidate_pose":str(output),
            "candidate_pose_sha256":sha(output),"all_pose_fields_exact_except_glb_hash":True,
            "pose_source":pose["pose_source"],"native_motion_validation_claimed":False}


def render_task(blender, source, output, view, pose=None):
    command = [str(blender),"--background","--factory-startup","--python-exit-code","2","--python",
               str(ROOT/"tools/costume_expressions/render_prepared_expression.py"),"--",str(source),str(output),"-",view,str(CAMERA),"--lit"]
    if pose:
        command.extend(["--pose-json",str(pose)])
    result = subprocess.run(command,capture_output=True,text=True,encoding="utf-8",errors="replace")
    log = output.with_suffix(".render.log")
    if log.exists():
        raise ValueError("Refuse to overwrite render log")
    log.write_text(result.stdout+result.stderr,encoding="utf-8")
    if result.returncode:
        raise RuntimeError("Offline Blender render failed: "+str(log))
    metadata = json.loads(output.with_suffix(".json").read_text(encoding="utf-8"))
    doc,binary,_ = read_glb(source)
    expected_size = image_report(image_bytes(doc,binary,doc["images"][2]))["size"]
    if metadata["source_sha256"] != sha(source) or metadata["face_texture_size"] != expected_size:
        raise ValueError("Rendered source/image dimensions changed")
    return {"source":str(source),"png":str(output),"png_sha256":sha(output),"view":view,"pose":str(pose) if pose else None,
            "size":list(Image.open(output).size),"camera_location":metadata["camera_location"],"camera_rotation":metadata["camera_rotation"],
            "maximum_desired_bone_matrix_error":metadata.get("maximum_desired_bone_matrix_error"),"native_qa_done":False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--png",type=Path,default=ROOT/"art/out/Avatar_HaloArcherM_EyesSharp_A.png")
    parser.add_argument("--output",type=Path)
    parser.add_argument("--label",default="A")
    parser.add_argument("--design-state",choices=("awaiting_selection","rejected"),default="awaiting_selection")
    parser.add_argument("--render",action="store_true")
    parser.add_argument("--blender",type=Path,default=Path("C:/Users/glori/Tools/blender-5.2.2/blender.exe"))
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_]{1,24}",args.label):
        raise ValueError("Candidate label must be a short safe identifier")
    output = (args.output or ROOT/("build/face_quality_audit_20261004/HaloArcherM_eyes_sharp_"+args.label+"_v1")).resolve()
    png = args.png.resolve()
    output.relative_to((ROOT/"build/face_quality_audit_20261004").resolve())
    if output.exists():
        raise ValueError("Use a new candidate folder; existing outputs are preserved")
    if sha(SOURCE) != SOURCE_SHA:
        raise ValueError("Original production MouthRestored GLB hash changed")
    original, original_binary, _ = read_glb(SOURCE)
    if len(original["images"]) != 3 or original["images"][2].get("name") != "FaceExpression_Neutral":
        raise ValueError("Exact original three-image identity is required")
    before_face = image_bytes(original,original_binary,original["images"][2])
    size = Image.open(png).size
    if size[0] != size[1] or size[0] not in (1024,1254,2048):
        raise ValueError("Use a square1024,1254,or2048 GPT source canvas; no file resampling is performed")
    output.mkdir(parents=True)
    candidate = output/("Costume_HaloArcherM_MouthRestored_EyesSharp_"+args.label+".glb")
    packages = [replace_images(SOURCE,candidate,{2:png})]
    if HEAD_2048.is_file():
        packages.append(replace_images(SOURCE,output/("Costume_HaloArcherM_MouthRestored_Head2048_EyesSharp_"+args.label+".glb"),{1:HEAD_2048,2:png}))
    baseline_pose = output/"poses/baseline_hurtbig.json"
    candidate_pose = output/"poses/eyes_sharp_hurtbig.json"
    pose_proofs = [copy_pose(SOURCE,baseline_pose),copy_pose(candidate,candidate_pose)]
    report = {"schema":1,"candidate_png":str(png),"candidate_png_sha256":sha(png),"candidate_png_size":list(size),
              "original_face_png":image_report(before_face),"packages":packages,"eye_alignment":drift(before_face,png.read_bytes()),
              "pose_proofs":pose_proofs,"design_approved":False,"uploads":0,"native_qa_done":False,"ready_for_game":False,
              "serious_and_softsmile_quality_candidates_prepared":False,"production_registry_mutated":False,
              "user_selection":args.design_state,
              "limitations":["The candidate changes only Neutral. Existing Serious/SoftSmile textures are not regenerated or approved.",
                              "Eye drift metrics are local estimates, not shape/style or Native motion proof.",
                              "Image-only byte proofs do not automatically authorize production gate bypass or registration."]}
    save_json(output/"candidate_proof.json",report)
    print(json.dumps({"output":str(output),"packages":len(packages),"candidate_png_size":list(size),"image_only_exact_proof":"PASS","design_approved":False,"uploads":0},ensure_ascii=False),flush=True)
    if args.render:
        tasks = []
        for label,source,pose in (("baseline",SOURCE,baseline_pose),("eyes_sharp_"+args.label,candidate,candidate_pose)):
            tasks.extend([(args.blender,source,output/(label+"_front.png"),"source-front",None),
                          (args.blender,source,output/(label+"_quarter.png"),"source-quarter",None),
                          (args.blender,source,output/(label+"_hurtbig.png"),"source-front",pose)])
        with ThreadPoolExecutor(max_workers=2) as pool:
            renders = list(pool.map(lambda task:render_task(*task),tasks))
        for offset in range(3):
            if renders[offset]["camera_location"] != renders[offset+3]["camera_location"] or renders[offset]["camera_rotation"] != renders[offset+3]["camera_rotation"]:
                raise ValueError("Baseline/candidate cameras differ")
        save_json(output/"render_proof.json",{"schema":1,"renders":renders,"same_camera_pairs_exact":True,"native_qa_done":False,"design_approved":False,"user_selection":args.design_state,"uploads":0})
        print(json.dumps({"renders":len(renders),"same_camera_pairs_exact":True,"native_qa_done":False},ensure_ascii=False),flush=True)


if __name__ == "__main__":
    main()
