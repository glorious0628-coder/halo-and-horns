"""Explicit HornsMageM sleeve/cuff bind exception; never an original-bone claim.

Read-only validation of the identified original, the reviewed two-bind/843-arm
ledger, and optionally the identified Head v3 ledger. This does not enable an
arbitrary schema/origin exception, promote Ready, call Studio, or upload assets.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import subprocess
import struct
import tempfile
import zlib
from pathlib import Path

import numpy as np

from constraints import JOINTS, PRIMARY, RigError
from glb_io import accessor_values, read_glb, write_glb

ROOT=Path(__file__).resolve().parents[2]


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def backend():
    # Blender bundles numpy but not scipy, pulled transitively by the original
    # preservation tools. Import these only in the normal local proof worker.
    global arm,face,node_matrices,inverse_binds
    import correct_arm_bind as arm
    import correct_face_weights as face
    from preserve_skin import node_matrices,inverse_binds

ORIGIN = "corrected_preserved_bind_skin_proxy_candidate"
NAME = "Costume_HornsMageM"
# Explicit whole-file provenance, not an inferred match by filename.
RAW_SHA = "d93eebfa6f4a2bac20a1f4802bd565d23a3b85b36c82081c3f907493ec113f08"
BASE_SHA = "0adfc9fa8827cd02229db055afd4cd68afde342cac1af16cb6437ec2545ad477"
FACE_SHA = "bd58cab1a05791da0419c996e9a3233dd415fac4d7ebd9bcefc72eda1592f2c5"
FACE_PLAN_SHA = "e6ed8a0d5e325c4c0c5db00240b5f3d494c0f61dffa8758e4196f5ccfbcba97b"
BASE = ROOT / "art/models/costume/prepared/skin/Costume_HornsMageM_preserved_v1"
BASE_MANIFEST_SHA = "44d4fb7f8746bb777a1d0931ce73cf4cb908e8b5ee8281a4a1fa7291bc1576b8"
BASE_RUNTIME_SHA = "9d367a0338e50657793a71ef3e790b5921633127fc32fab128acccc27803cd59"
BASE_PROXY_SHA = "5d68ca4ad627cb3e34b8daed3b4a3b91783db49ada6d76bb82a2727ed0ec655e"
ELBOW = [.18336556408261453, .455, .07986366358973386]
WRIST = [.24618667500439156, .40571, .09736842013391858]
REGION = {"min": [.1, .33, .023], "max": [.335, .535, .175]}
EVIDENCE_SHAS = {
    "6552035cb09a89552365303b3d4d9bd7186752f424d831d4566756937bb39678",
    "4dfe6443fca0e82ec61b74d40562bceff9e915e21f4af4679a3f69021e5d8149",
    "7e8c23908a6908b92a3bb03708490dd7d967e50378e19baa5e9cc8693158be19",
}


def require(condition, message):
    if not condition:
        raise RigError(message)


def read_png(path):
    """Read exact 8-bit, noninterlaced Blender PNG pixels without Pillow.

    This is also usable inside Blender's isolated Python. It never writes or
    resizes pixels; unsupported encodings fail closed.
    """
    content=Path(path).read_bytes();require(content[:8]==b"\x89PNG\r\n\x1a\n","Expected a complete PNG")
    offset=8;compressed=[];header=None;ended=False
    while offset<len(content):
        require(offset+12<=len(content),"Truncated PNG chunk")
        count=struct.unpack_from(">I",content,offset)[0];kind=content[offset+4:offset+8]
        require(offset+12+count<=len(content),"Truncated PNG content")
        data=content[offset+8:offset+8+count];crc=struct.unpack_from(">I",content,offset+8+count)[0]
        require(zlib.crc32(kind+data)&0xffffffff==crc,"PNG checksum changed")
        if kind==b"IHDR":
            require(header is None and count==13,"Invalid PNG header");header=struct.unpack(">IIBBBBB",data)
        elif kind==b"IDAT":compressed.append(data)
        elif kind==b"IEND":ended=True;break
        offset+=12+count
    require(header is not None and ended and compressed,"Incomplete PNG")
    width,height,depth,color,compression,filter_method,interlace=header
    require(0<width<=4096 and 0<height<=4096 and depth==8 and color in (2,6) and
            compression==filter_method==interlace==0,"Unsupported raster evidence encoding")
    channels=3 if color==2 else 4;stride=width*channels
    payload=zlib.decompress(b"".join(compressed));require(len(payload)==height*(stride+1),"PNG raster size changed")
    result=np.empty((height,stride),dtype=np.uint8);previous=bytearray(stride)
    for y in range(height):
        start=y*(stride+1);mode=payload[start];row=bytearray(payload[start+1:start+1+stride])
        require(mode in range(5),"Unsupported PNG filter")
        for x in range(stride):
            a=row[x-channels] if x>=channels else 0;b=previous[x];c=previous[x-channels] if x>=channels else 0
            if mode==1:predict=a
            elif mode==2:predict=b
            elif mode==3:predict=(a+b)//2
            elif mode==4:
                p=a+b-c;da,db,dc=abs(p-a),abs(p-b),abs(p-c)
                predict=a if da<=db and da<=dc else b if db<=dc else c
            else:predict=0
            row[x]=(row[x]+predict)&255
        result[y]=np.frombuffer(row,dtype=np.uint8);previous=row
    pixels=result.reshape(height,width,channels)
    if channels==3:pixels=np.concatenate((pixels,np.full((height,width,1),255,np.uint8)),axis=2)
    return pixels


def read(path):
    path = Path(path).resolve()
    require(ROOT in path.parents, "Inferred bind inputs must stay in this workspace")
    return json.loads(path.read_text(encoding="utf-8-sig"))


def exact_file(path, expected):
    path = Path(path).resolve()
    require(ROOT in path.parents and path.is_file() and sha(path) == expected, "Identified local evidence/source SHA changed")
    return path


def reviewed(plan):
    require(plan.get("region_review_complete") is True and plan.get("reviewed_overlay_images"), "Exact correction region was not reviewed")
    for image in plan["reviewed_overlay_images"]:
        exact_file(image["path"], image["sha256"])


def face_parent(path, manifest):
    """Only the already reviewed Head v3 source may precede the arm stage."""
    exact_file(path, FACE_SHA)
    plan_path = exact_file(manifest["weight_correction_plan"], FACE_PLAN_SHA)
    require(manifest["weight_correction_plan_sha256"] == FACE_PLAN_SHA, "Head v3 plan identity changed")
    plan = read(plan_path)
    reviewed(plan)
    expected = face.proposal(plan["source_manifest"], plan["facial_scope_report"], "head-surface-connected")
    for key, value in expected.items():
        if key != "region_review_complete":
            require(plan.get(key) == json.loads(json.dumps(value)), "Head v3 reviewed proposal changed: " + key)
    require(len(plan["changes"]) == 5596 and plan["source_skin_sha256"] == BASE_SHA, "Only identified Head v3 is allowed")
    before, binary, _ = read_glb(exact_file(plan["source_skin"], BASE_SHA))
    after, actual, _ = read_glb(path)
    require(actual[:len(binary)] == binary, "Head v3 original binary prefix changed")
    for key in ("nodes", "skins", "materials", "images", "textures", "animations"):
        require(before.get(key) == after.get(key), "Head v3 original bind/appearance changed")
    verify_active(before, binary, after, actual, plan["changes"])
    return plan


def verify_active(before, binary, after, actual, changes):
    selected = {(c["mesh"], c["primitive"], c["vertex"]): c for c in changes}
    require(len(selected) == len(changes), "Duplicate correction vertex")
    require(len(before["meshes"]) == len(after["meshes"]), "Surface count changed")
    require(after["accessors"][:len(before["accessors"])] == before["accessors"], "Original accessor definition changed")
    require(after["bufferViews"][:len(before["bufferViews"])] == before["bufferViews"], "Original buffer-view definition changed")
    for mi, mesh in enumerate(before["meshes"]):
        actual_mesh = after["meshes"][mi]
        require(len(mesh["primitives"]) == len(actual_mesh["primitives"]), "Primitive count changed")
        require({k:v for k,v in mesh.items() if k != "primitives"} == {k:v for k,v in actual_mesh.items() if k != "primitives"}, "Surface identity changed")
        for pi, primitive in enumerate(mesh["primitives"]):
            current = actual_mesh["primitives"][pi]
            a, b = copy.deepcopy(primitive), copy.deepcopy(current)
            for field in ("JOINTS_0", "WEIGHTS_0"):
                a["attributes"].pop(field); b["attributes"].pop(field)
            require(a == b, "P/N/UV/topology/material definition changed")
            for field, output_field in (("JOINTS_0", "new_joints"), ("WEIGHTS_0", "new_weights")):
                old = accessor_values(before, binary, primitive["attributes"][field])
                new = accessor_values(after, actual, current["attributes"][field])
                require(len(old) == len(new), "Skin vertex count changed")
                for vi, (x, y) in enumerate(zip(old, new)):
                    change = selected.get((mi, pi, vi))
                    if change:
                        require(list(x) == change["old_joints" if field == "JOINTS_0" else "old_weights"], "Ledger original skin value changed")
                    require(list(y) == (change[output_field] if change else list(x)), "Unreviewed skin value changed")


def visual_proof(data, skin, parent):
    ledger_path = exact_file(data["inferred_bind_validation"], data["inferred_bind_validation_sha256"])
    ledger = read(ledger_path)
    require(ledger.get("schema") == 1 and ledger.get("name") == NAME and ledger.get("personally_reviewed") is True and
            ledger.get("source_modesty_reviewed") is True and ledger.get("ready") is False and ledger.get("actual_studio") is False,
            "Reviewed modest source and offline-only visual evidence required")
    require(ledger.get("skin_sha256") == sha(skin) and ledger.get("bind_parent_sha256") == sha(parent) and
            ledger.get("bind_plan_sha256") == data["bind_correction_plan_sha256"], "Visual evidence belongs to a different source")
    report = read(exact_file(ledger["render_report"], ledger["render_report_sha256"]))
    images = {str(exact_file(i["path"], i["sha256"])) for i in ledger["images"]}
    records = report["records"]
    required = {"Rest", "MageSwing", "MageRelease", "WalkSample", "JumpSample", "HurtBig"}
    if sha(parent) == FACE_SHA:
        required |= {"MageSwingWindup", "MageReleaseWindup", "Hurt"}
    for variant, expected_sha in (("Original", BASE_SHA), ("Candidate", sha(skin))):
        found = {r["pose"]:r for r in records if r["variant"] == variant}
        require(required <= set(found), "Missing reviewed actual clip/base pose evidence")
        for r in found.values():
            require(r["source_sha256"] == expected_sha and r.get("ready") is False and r.get("walk_jump_actual_animator_captured") is False, "Visual source/actual Animator claim changed")
            for field, limit in (("actual_armature_lbs_error", 1e-5), ("target_fk_projection_error", 1e-4)):
                value = r[field]
                require(type(value) in (float, int) and np.isfinite(value) and 0 <= value < limit, "Imported Armature LBS/FK evidence failed")
            require(len(r["images"]) >= 2 and all(str(Path(p).resolve()) in images for p in r["images"]), "Unhashed visual evidence")
    require(report.get("walk_jump_are_representative_offline_keyposes") is True, "Offline walk/jump claim changed")
    stats = {}
    for view in ("front", "left_side"):
        paths = [next(p for r in records if r["variant"] == label and r["pose"] == "Rest" for p in r["images"] if p.endswith("_"+view+".png")) for label in ("Original", "Candidate")]
        a, b = [read_png(p).astype(np.int16) for p in paths]
        require(a.shape == b.shape, "Rest render shape changed")
        delta = np.abs(a-b); pixels = np.count_nonzero(delta.max(axis=2))
        # Source float skin sums can change a handful of anti-aliased edge pixels.
        # Record the bounded residual; never claim bit-identical pixels for it.
        require(delta.max() <= 8 and pixels/a.shape[0]/a.shape[1] < .001, "Rest raster appearance differs beyond float/AA residual")
        stats[view] = {"maximum_channel_error": int(delta.max()), "changed_pixels": int(pixels), "identical_pixels": bool(pixels == 0)}
    return {"ledger_sha256": sha(ledger_path), "rest_pixel_comparison": stats,
            "maximum_actual_armature_lbs_error": max(r["actual_armature_lbs_error"] for r in records),
            "actual_studio_validated": False}


def validate(sidecar_path):
    path = Path(sidecar_path).resolve(); data = read(path)
    if importlib.util.find_spec("scipy") is None:
        # No package installation, source alteration, or validation bypass.
        # The same strict validator runs in the existing local `py` runtime.
        manifest_sha=sha(path);skin_path=Path(data["output"]);skin_sha=sha(skin_path)
        result=subprocess.run(["py","-B",str(Path(__file__).resolve()),str(path),"--metadata"],
            capture_output=True,text=True,encoding="utf-8",check=False)
        require(result.returncode==0,"Local strict proof worker refused: "+result.stderr[-1500:])
        checked=json.loads(result.stdout)
        require(sha(path)==manifest_sha and sha(skin_path)==skin_sha,"Proof source changed during local validation")
        require(checked.get("inferred_bind_proof",{}).get("original_bones_claimed") is False,"Local inferred proof was not returned")
        return checked
    backend()
    require(data.get("schema") == 2 and data.get("rig_origin") == ORIGIN and data.get("name", NAME) == NAME and
            data.get("bind_correction_schema") == 1 and data.get("original_bones_claimed") is False and
            data.get("rig_ready_for_game") is False and data.get("studio_motion_validated") is False,
            "Only explicit unregistered HornsMageM inferred bind metadata is allowed")
    exact_file(data["source"], RAW_SHA); require(data["source_sha256"] == RAW_SHA, "Identified Tripo provenance changed")
    original_path = exact_file(BASE / "Costume_HornsMageM_skin.glb", BASE_SHA)
    original = read(exact_file(BASE / "Costume_HornsMageM_skin.skin.json", BASE_MANIFEST_SHA))
    skin = exact_file(data["output"], data["output_sha256"])
    plan_path = exact_file(data["bind_correction_plan"], data["bind_correction_plan_sha256"])
    plan = read(plan_path); reviewed(plan)
    parent = exact_file(plan["source_skin"], plan["source_skin_sha256"])
    require(sha(parent) in (BASE_SHA, FACE_SHA), "An arbitrary correction ancestor is not allowed")
    exact_file(data["original_benchmark_skin"], BASE_SHA)
    require(data["original_benchmark_skin_sha256"] == BASE_SHA and
            data.get("original_binary_prefix_preserved") is True and
            data.get("original_geometry_uv_normals_material_images_preserved") is True and
            data.get("original_source_weights_exact") is False and
            data.get("original_rest_shape_preserved") is True and
            data.get("existing_original_skin_producer_compatible") is False,
            "Exact baseline/rest preservation and inferred producer claims required")
    if "bind_parent_skin" in data:
        exact_file(data["bind_parent_skin"], sha(parent))
        require(data["bind_parent_skin_sha256"] == sha(parent), "Bind parent provenance changed")
    source_manifest = read(exact_file(plan["source_manifest"], plan["source_manifest_sha256"]))
    landmarks = read(exact_file(plan["landmarks"], plan["landmarks_sha256"]))
    require(landmarks.get("elbow_source") == ELBOW and landmarks.get("wrist_source") == WRIST and
            landmarks.get("reviewed_source_region") == REGION and landmarks.get("ready") is False and
            landmarks.get("synthetic_ik_target_used_to_choose_position") is False and
            {e["sha256"] for e in landmarks["evidence_files"]} == EVIDENCE_SHAS,
            "Only the measured original sleeve/cuff landmarks are allowed")
    expected = arm.proposal(plan["source_manifest"], plan["landmarks"])
    for key, value in expected.items():
        if key != "region_review_complete":
            require(plan.get(key) == json.loads(json.dumps(value)), "Reviewed arm proposal changed: " + key)
    require(len(plan["changes"]) == 843 and not plan["capacity_refused_vertices"], "Exact 843-arm scope required")
    require(all(c["mesh_name"] == "CostumeSkinBody" for c in plan["changes"]), "Arm edit escaped Body surface")
    head = face_parent(parent, source_manifest) if sha(parent) == FACE_SHA else None
    if head:
        require(data.get("weight_correction_chain") == source_manifest.get("weight_correction_chain") and
                data.get("weight_correction_plan_sha256") == FACE_PLAN_SHA and data.get("changed_facial_vertices") == 5596,
                "Head v3 provenance chain changed")
    else:
        require(not data.get("weight_correction_chain") and not data.get("changed_facial_vertices"), "Undeclared Head correction chain")
    arm.verify(parent, skin, plan)
    old, binary, _ = read_glb(parent); new, actual, _ = read_glb(skin)
    verify_active(old, binary, new, actual, plan["changes"])
    require(len(new["accessors"])==len(old["accessors"])+3 and len(new["bufferViews"])==len(old["bufferViews"])+3,
            "Exactly one IBM and two arm JW arrays may be appended")
    ibm_accessor=new["accessors"][new["skins"][0]["inverseBindMatrices"]]
    require(ibm_accessor.get("count")==23 and ibm_accessor.get("type")=="MAT4" and ibm_accessor.get("componentType")==5126,
            "Every one of the 23 inverse binds must be present")
    for key in set(old)|set(new):
        if key not in ("accessors","bufferViews","buffers","skins","nodes","meshes","extras"):
            require(old.get(key)==new.get(key),"Original scene/import metadata changed: "+key)
    expected_extras={**old.get("extras",{}),"HHC_InferredArmBindCandidate":{
        "plan_sha256":data["bind_correction_plan_sha256"],"ready":False,"original_bones_claimed":False}}
    require(new.get("extras")==expected_extras,"Inferred candidate marker or original metadata changed")
    require(len(new["buffers"])==1 and
            {k:v for k,v in new["buffers"][0].items() if k!="byteLength"}==
            {k:v for k,v in old["buffers"][0].items() if k!="byteLength"},"Original buffer metadata changed")
    require(len(old["nodes"]) == len(new["nodes"]) and old["scenes"] == new["scenes"], "Extra source node or scene changed")
    old_skin, new_skin = copy.deepcopy(old["skins"]), copy.deepcopy(new["skins"])
    old_skin[0].pop("inverseBindMatrices");new_skin[0].pop("inverseBindMatrices")
    require(old_skin == new_skin, "Skin hierarchy/identity changed")
    _, _, world = node_matrices(new)
    A = np.asarray(original["source_to_game_affine"]).reshape(4,4,order="F")
    require(data["source_to_game_affine"] == original["source_to_game_affine"] and data["affine_layout"] == "gltf_column_major_16", "Canonical source frame changed")
    indices = new["skins"][0]["joints"];names = [new["nodes"][i]["name"] for i in indices]
    require(len(names) == 23 and len(set(names)) == 23 and len(data["bones"]) == 23, "Whole original 23-bone hierarchy required")
    for b, baseline in zip(data["bones"], original["bones"]):
        require(b["name"] == baseline["name"], "Original bone order changed")
        wanted = copy.deepcopy(baseline)
        if b["name"] in ("LeftLowerArm", "LeftHand"):
            index = indices[names.index(b["name"])]
            wanted["game_bind_world"] = world[index].flatten(order="F").tolist()
            wanted["source_bind_world"] = (np.linalg.inv(A)@world[index]).flatten(order="F").tolist()
            point = ELBOW if b["name"] == "LeftLowerArm" else WRIST
            require(np.max(np.abs(world[index][:3,3] - (A@np.r_[point,1])[:3])) < 1e-9, "Inferred bind position changed")
        require(b == wanted, "Sidecar bone matrix/parent/proxy contract changed")
    runtime = read(exact_file(data["proxy_runtime"], data["proxy_runtime_sha256"]))
    proxy = read(exact_file(data["proxy_plan"], data["proxy_plan_sha256"]))
    base_runtime = read(exact_file(BASE / "proxy_runtime.json", BASE_RUNTIME_SHA))
    base_proxy = read(exact_file(BASE / "proxy_joints.json", BASE_PROXY_SHA))
    require(runtime["parts"] == base_runtime["parts"] and runtime["root"] == base_runtime["root"] and runtime["hip_height"] == base_runtime["hip_height"], "Unreviewed proxy geometry/height changed")
    require(runtime["source_skin_sha256"] == sha(skin) and runtime["source_sha256"] == RAW_SHA and runtime["proxy_plan_sha256"] == data["proxy_plan_sha256"] and
            runtime.get("rig_ready_for_game") is False and runtime.get("original_bones_claimed") is False,
            "Proxy source SHA or inferred/Ready claim changed")
    require(len(runtime["joints"]) == len(proxy["joints"]) == 15 and {p["name"] for p in runtime["parts"]} == set(PRIMARY), "Complete R15 proxy required")
    centers = {p["name"]:np.asarray(p["center"]) for p in runtime["parts"]}; centers["HumanoidRootPart"] = np.asarray(runtime["root"]["center"])
    for rows, originals, point_key in ((runtime["joints"],base_runtime["joints"],"world"), (proxy["joints"],base_proxy["joints"],"joint_position")):
        require(len({j["name"] for j in rows}) == 15, "Duplicate proxy joint")
        for joint, baseline in zip(rows, originals):
            wanted = copy.deepcopy(baseline)
            if joint["name"] in ("LeftElbow", "LeftWrist"):
                target = world[indices[names.index(joint["part1"])]][:3,3]
                wanted[point_key] = target.tolist()
                wanted["C0"] = (target-centers[joint["part0"]]).tolist()+arm.IDENTITY
                wanted["C1"] = (target-centers[joint["part1"]]).tolist()+arm.IDENTITY
            require(joint == wanted, "Unreviewed or inconsistent proxy hinge changed")
    expected_runtime = copy.deepcopy(base_runtime)
    expected_runtime.update(source_skin_sha256=sha(skin), proxy_plan_sha256=data["proxy_plan_sha256"],
        inferred_bind_joints=["LeftLowerArm","LeftHand"],original_bones_claimed=False,rig_ready_for_game=False,
        joints=runtime["joints"])
    require(runtime == expected_runtime, "Unreviewed proxy runtime metadata changed")
    expected_proxy = copy.deepcopy(base_proxy)
    expected_proxy.update(rig_origin="inferred_arm_bind_correction_candidate", original_bones_claimed=False,
        rig_ready_for_game=False, source_rest_positions_preserved=True, joints=proxy["joints"])
    require(proxy == expected_proxy, "Unreviewed proxy plan metadata changed")
    total = 843 + (5596 if head else 0)
    require(data["changed_skin_vertices"] == total and data["inferred_bind_joints"] == ["LeftLowerArm","LeftHand"], "Correction count/claim changed")
    # Bind residuals are recomputed, not accepted from a report boolean.
    _,_,wo = node_matrices(old); ibo = inverse_binds(old,binary,old["skins"][0]); ibn = inverse_binds(new,actual,new["skins"][0])
    residual = max(float(np.max(np.abs(wo[i]@a-world[i]@b))) for i,a,b in zip(indices,ibo,ibn))
    require(residual < 2e-6, "Original rest bind product failed")
    visual = visual_proof(data,skin,parent)
    data["name"] = NAME
    data["inferred_bind_proof"] = {"schema":1,"source_sha256":RAW_SHA,"baseline_skin_sha256":BASE_SHA,
        "changed_bind_joints":["LeftLowerArm","LeftHand"],"changed_arm_vertices":843,"changed_head_vertices":5596 if head else 0,
        "original_bones_claimed":False,"rest_bind_maximum_error":residual,"geometry_uv_topology_normal_png_exact":True,
        "ready":False,**visual}
    return data


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("sidecar",type=Path)
    parser.add_argument("--self-test",action="store_true")
    parser.add_argument("--metadata",action="store_true",help="Emit validated metadata for the local Blender proof worker")
    args=parser.parse_args()
    if args.self_test:
        print(json.dumps(self_test(args.sidecar)));return
    data=validate(args.sidecar)
    if args.metadata:print(json.dumps(data));return
    print(json.dumps({"name":data["name"],"proof":data["inferred_bind_proof"],"ready":False,"api_calls":0,"studio_calls":0}))


def self_test(sidecar):
    """Recomputed-SHA attacks must fail too; tests do not alter real candidates."""
    original=read(sidecar);good=validate(sidecar);rejections=[]
    before_sha=sha(original["output"])
    with tempfile.TemporaryDirectory(prefix="inferred_bind_negative_",dir=ROOT/"build") as temp:
        temp=Path(temp)
        def rejected(label,data):
            p=temp/"negative.skin.json";arm.dump(p,data)
            try: validate(p)
            except (RigError,KeyError,ValueError,OSError,IndexError):rejections.append(label)
            else:raise AssertionError("Negative mutation accepted: "+label)
        for key,value in (("schema",1),("name","Costume_HaloMageM"),("rig_origin","preserved_source_skin_proxy_candidate"),
            ("original_bones_claimed",True),("rig_ready_for_game",True),("studio_motion_validated",True),
            ("source_sha256","0"*64),("original_benchmark_skin_sha256","0"*64),
            ("original_binary_prefix_preserved",False),("original_geometry_uv_normals_material_images_preserved",False),
            ("original_rest_shape_preserved",False),("original_source_weights_exact",True),
            ("existing_original_skin_producer_compatible",True),("bind_correction_plan_sha256","0"*64)):
            changed=copy.deepcopy(original);changed[key]=value;rejected("sidecar_"+key,changed)
        gltf,binary,_=read_glb(original["output"])
        def glb_mutation(label,modify):
            changed_gltf=copy.deepcopy(gltf);changed_binary=bytearray(binary);modify(changed_gltf,changed_binary)
            path=temp/(label+".glb");write_glb(path,changed_gltf,bytes(changed_binary))
            changed=copy.deepcopy(original);changed["output"]=str(path);changed["output_sha256"]=sha(path)
            rejected(label,changed)
        def accessor_metadata(g,b):
            index=g["meshes"][0]["primitives"][0]["attributes"]["TEXCOORD_0"]
            g["accessors"][index]["count"]-=1
        def original_uv_byte(g,b):
            index=g["meshes"][0]["primitives"][0]["attributes"]["TEXCOORD_0"]
            a=g["accessors"][index];view=g["bufferViews"][a["bufferView"]]
            b[view.get("byteOffset",0)+a.get("byteOffset",0)]^=1
        def active_weight(g,b):
            index=g["meshes"][0]["primitives"][0]["attributes"]["WEIGHTS_0"]
            a=g["accessors"][index];view=g["bufferViews"][a["bufferView"]]
            struct.pack_into("<f",b,view.get("byteOffset",0)+a.get("byteOffset",0),.123456)
        def inverse_bind(g,b):
            a=g["accessors"][g["skins"][0]["inverseBindMatrices"]];view=g["bufferViews"][a["bufferView"]]
            struct.pack_into("<f",b,view.get("byteOffset",0)+a.get("byteOffset",0),.123456)
        def extra_mesh(g,b):g["meshes"].append(copy.deepcopy(g["meshes"][0]))
        def auxiliary_loss(g,b):g["skins"][0]["joints"].pop(0)
        def foreign_rotation(g,b):g["nodes"][g["skins"][0]["joints"][0]]["rotation"]=[.1,0,0,1]
        for label,modify in (("static_accessor_metadata",accessor_metadata),("original_uv_byte",original_uv_byte),
            ("active_weight_updated_SHA",active_weight),("inverse_bind_updated_SHA",inverse_bind),
            ("extra_mesh",extra_mesh),("lost_auxiliary",auxiliary_loss),("unreviewed_rotation",foreign_rotation)):
            glb_mutation(label,modify)
        changed=copy.deepcopy(original);changed["bones"][0]["proxy_part"]="Head";rejected("sidecar_bone_proxy",changed)
        changed=copy.deepcopy(original);changed["changed_skin_vertices"]+=1;rejected("changed_vertex_count",changed)
        for field,modifier in (("proxy_runtime",lambda p:p.update(hip_height=p["hip_height"]+.1)),
            ("proxy_plan",lambda p:p["joints"][0]["C0"].__setitem__(0,.1234))):
            p=read(original[field]);modifier(p);bad=temp/(field+".json");arm.dump(bad,p)
            changed=copy.deepcopy(original);changed[field]=str(bad);changed[field+"_sha256"]=sha(bad);rejected(field+"_updated_SHA",changed)
        p=read(original["inferred_bind_validation"]);p["actual_studio"]=True;bad=temp/"visual.json";arm.dump(bad,p)
        changed=copy.deepcopy(original);changed.update(inferred_bind_validation=str(bad),inferred_bind_validation_sha256=sha(bad));rejected("false_actual_visual_claim",changed)
        p=read(original["bind_correction_plan"]);p["region_review_complete"]=False;bad=temp/"plan.json";arm.dump(bad,p)
        changed=copy.deepcopy(original);changed.update(bind_correction_plan=str(bad),bind_correction_plan_sha256=sha(bad));rejected("unreviewed_plan_updated_SHA",changed)
    require(sha(original["output"])==before_sha,"Self-test changed the candidate")
    return {"meaningful_negative_checks":len(rejections),"rejections":rejections,
        "candidate_unchanged":True,"strict_positive_proof":good["inferred_bind_proof"],"ready":False,"api_calls":0,"studio_calls":0}


if __name__ == "__main__":
    try: main()
    except (RigError,KeyError,ValueError,OSError,IndexError) as error: raise SystemExit("inferred bind proof refused: "+str(error))
