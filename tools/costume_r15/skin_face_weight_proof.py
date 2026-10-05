# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
# Still importable as a library ONLY because live tools import it (tools/monster_import_preflight.py,
# tools/test_weapon_motion.py, GLB audit tools). Never run it directly.
"""Read-only, exact allowlist for nine reviewed Head/neck JW-only candidates.

Every candidate is a new source copy. All P/N/UV/topology/material/image/bind
bytes and unselected weights stay exact. This does not claim motion quality,
permit an arbitrary corrected origin, promote a costume, or call Studio/API.
"""
from __future__ import annotations

if __name__ == "__main__":
    raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile

from constraints import RigError
from glb_io import read_glb
from skin_inferred_bind_proof import ROOT, exact_file, read, require, reviewed, sha, verify_active

ORIGIN="corrected_preserved_source_skin_proxy_candidate"
# name: (identified parent skin, exact reviewed plan, exact output, raw rig, count)
RULES={
 "HaloWarriorM":("4a4448f556a9c0b8eaf10631ff73f21e28235a35af7944f60dbf99ff03899268","91a7b75cbd91735525f0e0a3807c235cb145fc457e1a88f22a919b819dce9fad","8f131c49bdc6035db43b67c734bf01c0b336353e040288f133bc8ee46fc6707d","9e15d92825b0eb919055ccb24a5eaf38ed3e29e6f7bf35f1684bbb459c08cca0",410),
 "HaloArcherM":("7d09b5aec17a52f0a161835bdab5db2a81dcd035baa1f2f8f64a226cb6977756","faf92ec081337b5310f35359748f9df7a7bae88df3f787e2a5271fed9c5f6e77","3043ecdb3bfd21fde28a5a7795c7958646fa2df96b708d2781f4cee7a8286b2d","48b60fffa4d6c348f364f5f85dfef4ceaf31eceacb3477a015cae99dfaea4d37",1544),
 "HornsWarriorM":("e5537e521fd98af7c8e248ec5bc215af4b5544ceb6e1c49cb94378b33713359e","e20f8e74cefd87c42d3d94d17a453384dca82f5bcd6dd1ddede3fc9871a6a6da","cd8d72f28757467470f7a492f4c4c914eceafa5c03c79a229eb2a2e9f772a036","57bfeed4f0b747984d7807e0f691794014c53c5ddd69f92edfedfe579e100235",4843),
 "HornsWarriorF":("5c0ce4d7a2c8b8a2a241a157b715ab812ff2f1860844ee2da6c7d8ed1fb312b7","14ab6d962221d6782d22bd52ae59a993ace7566adfb9297bae56bbdbae65b75b","826d6fcf314e2c763667429ff9b8cf739b4e2e93f9a755b5b9c6685c02131e88","881af71342a5386ed7248b8b2c3a39414112954b2b57cc94636c70ae47f01050",4091),
 "HornsMageM":("0adfc9fa8827cd02229db055afd4cd68afde342cac1af16cb6437ec2545ad477","e6ed8a0d5e325c4c0c5db00240b5f3d494c0f61dffa8758e4196f5ccfbcba97b","bd58cab1a05791da0419c996e9a3233dd415fac4d7ebd9bcefc72eda1592f2c5","d93eebfa6f4a2bac20a1f4802bd565d23a3b85b36c82081c3f907493ec113f08",5596),
 "HornsArcherM":("6ab861994ce9740468837560a21b8d7e8fe1ac6223c61bb79227db73eb5791d8","b81c357da647be258e75ed89f913a8656ca0ebc5152696ef11d68f49c2dd1be9","45682297d43b8b6d817faa439e08156e3be83637f2e975a11eaa3db1ee7380e4","192bebb4f66ca9573ebc18c1021f6b30632e95dcdd276e05d16cf053e4117691",7182),
 "NeutralWarriorM":("b54e953b68d793d886ee68ac14c9ad0e797cb31054fc07519a2d1d8a297c7f34","2b8544a7ad40445ad55b7c1f4dd4991d4131e4f31fd3ed35367eaa7e22bd902c","4d45bd23b89f9e83549b8488edaf8d254655db794cc9a2d0eb8cce38f7c02bc3","739d6fb97ee49abce14e23ba481dc13c7836392051e134c3cc2fbedc4ce0b07c",1996),
 "NeutralMageM":("62abccef62b87a9eaffece53c2ef664bd7f1f4bf9de773936570ad43c38a16ef","3d6279723a4ae3fe60325d8bdb60f6bfbc506ccaa806227578eca4c445ebc61a","d2a7b25d22dd66ff08aba3fa84e794e041b93a8686422549be50dc7fb42aeaac","eb751abcafcd88626f8302dc33ba005752b39b105589d3439396463608a26d06",810),
 "NeutralMageF":("f8045886143d1973d00d68d67f96dbde6ffbbf36f2585beb0410b37368498f1e","51dd298157a2e1bfc52422b7eb19e2ecc8a4cbf7f030b87dda66b3a39674e30f","2a1b6b1db2bcdfd81962e65262c6f79559a1b458f52449d30a27d5df8713fb8d","cfa23bd0075b4dd73cd6982261c9debcdbacf8777dd0967b5404180a86490f57",1808),
}


def identified(data):
    matches=[name for name,row in RULES.items() if data.get("weight_correction_plan_sha256")==row[1]]
    require(len(matches)==1,"Only one identified reviewed Head/neck plan is allowed")
    name=matches[0]
    require(data.get("name","Costume_"+name)=="Costume_"+name,"Head correction identity changed")
    return name,RULES[name]


def validate(sidecar_path):
    path=Path(sidecar_path).resolve();data=read(path);name,rule=identified(data)
    if importlib.util.find_spec("scipy") is None:
        before=sha(path);skin_before=sha(data["output"])
        done=subprocess.run(["py","-B",str(Path(__file__).resolve()),str(path),"--metadata"],capture_output=True,text=True,encoding="utf-8")
        require(done.returncode==0,"Local strict Head worker refused: "+done.stderr[-1500:])
        checked=json.loads(done.stdout)
        require(before==sha(path) and skin_before==sha(data["output"]),"Head source changed during proof")
        require(checked.get("face_weight_proof",{}).get("source_binds_exact") is True,"No strict Head proof returned")
        return checked
    import correct_face_weights as face
    source_sha,plan_sha,output_sha,raw_sha,count=rule
    require(data.get("schema")==1 and data.get("rig_origin")==ORIGIN and data.get("rig_ready_for_game") is False and
        data.get("studio_motion_validated") is False and data.get("original_source_weights_exact") is False and
        data.get("original_binary_prefix_preserved") is True and data.get("original_geometry_uv_normals_material_images_preserved") is True,
        "Exact unregistered JW-only Head metadata required")
    require(data.get("source_sha256")==raw_sha and data.get("output_sha256")==output_sha,"Head source/output provenance changed")
    exact_file(data["source"],raw_sha);skin=exact_file(data["output"],output_sha)
    plan=read(exact_file(data["weight_correction_plan"],plan_sha));reviewed(plan)
    require(plan.get("policy_name")=="head-surface-connected" and len(plan["changes"])==count and plan["source_skin_sha256"]==source_sha,
        "Exact reviewed connected Head scope required")
    parent=exact_file(plan["source_skin"],source_sha)
    original=read(exact_file(plan["source_manifest"],plan["source_manifest_sha256"]))
    require(original["source_sha256"]==raw_sha and original["output_sha256"]==source_sha,"Reviewed parent metadata changed")
    expected=face.proposal(plan["source_manifest"],plan["facial_scope_report"],"head-surface-connected")
    for key,value in expected.items():
        if key!="region_review_complete":require(plan.get(key)==json.loads(json.dumps(value)),"Reviewed Head proposal changed: "+key)
    before,binary,_=read_glb(parent);after,actual,_=read_glb(skin)
    require(actual[:len(binary)]==binary,"Original Head binary prefix changed")
    for key in ("nodes","skins","materials","textures","images","animations","scenes","scene"):
        require(before.get(key)==after.get(key),"Original source bind/appearance changed: "+key)
    require(len(before.get("skins",[]))==1 and len(before["skins"][0]["joints"])==23,"Whole source 23-bone hierarchy required")
    verify_active(before,binary,after,actual,plan["changes"])
    require(after["accessors"][:len(before["accessors"])]==before["accessors"] and
        after["bufferViews"][:len(before["bufferViews"])]==before["bufferViews"],"Original static/bind/PNG storage changed")
    for field in ("source_to_game_affine","affine_layout","source_frame_policy","bones","proxy_plan","proxy_plan_sha256"):
        require(data.get(field)==original.get(field),"Head-only correction changed proxy/bind metadata: "+field)
    exact_file(data["proxy_plan"],data["proxy_plan_sha256"])
    require(len(data["bones"])==23 and {b["name"] for b in data["bones"]}==set(plan["bone_names"]),"Lost original auxiliary/principal metadata")
    require(data.get("changed_facial_vertices")==count and data.get("changed_skin_vertices_this_stage")==count and
        data.get("changed_skin_vertices")==original.get("changed_skin_vertices",0)+count,"Head-stage change count changed")
    require(data.get("parent_correction_skin_sha256")==source_sha and sha(data["parent_correction_skin"])==source_sha,"Head parent chain changed")
    chain=copy.deepcopy(original.get("weight_correction_chain",[]))
    if original.get("weight_correction_plan") and not chain:
        chain=[{"path":original["weight_correction_plan"],"sha256":original["weight_correction_plan_sha256"],"output_skin_sha256":source_sha}]
    chain.append({"path":data["weight_correction_plan"],"sha256":plan_sha,"kind":"approved_face_head_neck_only"})
    require(data.get("weight_correction_chain")==chain,"Head correction chain changed")
    benchmark=original.get("original_benchmark_skin",str(parent));benchmark_sha=original.get("original_benchmark_skin_sha256",source_sha)
    require(data["original_benchmark_skin_sha256"]==benchmark_sha,"Original benchmark SHA changed")
    exact_file(data["original_benchmark_skin"],benchmark_sha);exact_file(benchmark,benchmark_sha)
    # No inferred bind is accepted here. The two-bind HornsMageM combination
    # uses skin_inferred_bind_proof, with original_bones_claimed=False.
    require(data.get("original_bones_claimed",True) is True and not data.get("inferred_bind_joints"),"Head-only path must not conceal inferred binds")
    data["name"]="Costume_"+name
    data["face_weight_proof"]={"schema":1,"name":data["name"],"source_skin_sha256":source_sha,"output_sha256":output_sha,
        "plan_sha256":plan_sha,"changed_head_scope_vertices":count,"source_binds_exact":True,"geometry_normal_uv_topology_png_exact":True,
        "unselected_active_weights_exact":True,"ready":False,"actual_studio_validated":False}
    return data


def self_test(path):
    data=read(path);positive=validate(path);cases=[]
    with tempfile.TemporaryDirectory(prefix="head_weight_negative_",dir=ROOT/"build") as temporary:
        folder=Path(temporary)
        for field,value in (("schema",2),("rig_origin","preserved_source_skin_proxy_candidate"),("rig_ready_for_game",True),
            ("studio_motion_validated",True),("original_bones_claimed",False),("source_sha256","0"*64),("output_sha256","0"*64),
            ("weight_correction_plan_sha256","0"*64),("original_geometry_uv_normals_material_images_preserved",False),
            ("changed_facial_vertices",0),("changed_skin_vertices_this_stage",0),("inferred_bind_joints",["LeftHand"]),
            ("source_to_game_affine",[1]*16),("weight_correction_chain",[])):
            mutated=copy.deepcopy(data);mutated[field]=value;p=folder/"negative.skin.json"
            p.write_text(json.dumps(mutated,indent=2)+"\n",encoding="utf-8")
            try:validate(p)
            except (RigError,KeyError,ValueError,OSError,IndexError):cases.append(field)
            else:raise AssertionError("Unauthorized Head metadata mutation accepted: "+field)
    return {"positive":True,"meaningful_negative_checks":len(cases),"rejected":cases,"proof":positive["face_weight_proof"],"ready":False}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("sidecar",type=Path);p.add_argument("--metadata",action="store_true");p.add_argument("--self-test",action="store_true")
    a=p.parse_args()
    if a.self_test:print(json.dumps(self_test(a.sidecar)));return
    data=validate(a.sidecar)
    print(json.dumps(data if a.metadata else data["face_weight_proof"]))


if __name__=="__main__":
    try:main()
    except (RigError,KeyError,ValueError,OSError,IndexError) as error:raise SystemExit("Head skin proof refused: "+str(error))
