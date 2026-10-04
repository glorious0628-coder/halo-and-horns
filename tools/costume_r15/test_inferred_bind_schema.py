"""Real two-source inferred bind adapters and their source-claim boundaries."""
from pathlib import Path
import copy
import json
import subprocess
import tempfile

import skin_schema
import skin_runtime_v2 as runtime
import skin_inferred_bind_proof as proof
from constraints import RigError

ROOT=Path(__file__).resolve().parents[2]
SOURCES=("rebind_candidate_v1/Costume_HornsMageM_skin_rebind.skin.json",
         "combined_head_arm_v1/Costume_HornsMageM_head_arm_skin.skin.json")


def main():
    checks=0;failures=[];preserved={}
    def check(value,label):
        nonlocal checks
        checks+=1
        if not value: failures.append(label)
    output=ROOT/"build/remaining_16_inferred_gate_20261004";output.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="inferred_adapter_",dir=output) as temporary:
        temporary=Path(temporary)
        for index,relative in enumerate(SOURCES):
            sidecar=ROOT/"build/horns_mage_arm_anatomy"/relative
            original=json.loads(sidecar.read_text(encoding="utf-8"))
            for file in (sidecar,Path(original["output"]),Path(original["proxy_runtime"]),Path(original["proxy_plan"])):
                preserved[file]=proof.sha(file)
            data,_=runtime.prepare(sidecar,"ServerStorage/CostumeExpressionSkinImports_Remaining16_v1/Costume_HornsMageM",
                pending_name="Costume_HornsMageM_InferredBindAdapterCandidate",binding_schema=1)
            check(len(data["bones"])==23 and len(data["meshes"])==2,"source "+str(index)+" retained hierarchy")
            check(data["original_bones_claimed"] is False,"inferred bind cannot claim genuine original bones")
            selected=data["inferred_bind_proof"]
            check(selected["changed_bind_joints"]==["LeftLowerArm","LeftHand"] and selected["changed_arm_vertices"]==843,"exact two inferred binds and selected arm vertices")
            check(selected["changed_head_vertices"]==(0 if index==0 else 5596),"head correction stage is explicit")
            check(data["ready"] is False and data["binding_schema"]==1,"new candidates remain unregistered")
            inspector=temporary/("inspect_"+str(index)+".json");runtime.write_payload(data,"inspect",inspector)
            luau=inspector.with_suffix(".luau");luau.write_text(json.loads(inspector.read_text(encoding="utf-8"))["code"],encoding="utf-8")
            compiled=subprocess.run([str(ROOT/"build/luau_cli_0_741/luau-compile.exe"),str(luau)],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
            check(compiled.returncode==0,"inferred bind inspector local compile")
            for key,value in (("rig_origin","unknown"),("rig_origin","preserved_source_skin_proxy_candidate"),
                ("original_bones_claimed",True),("rig_ready_for_game",True),("schema",1),
                ("expression_manifest","unreviewed.json"),("proxy_runtime_sha256","0"*64)):
                changed=copy.deepcopy(original);changed[key]=value
                bad=temporary/"bad.skin.json";bad.write_text(json.dumps(changed),encoding="utf-8")
                try:skin_schema.load(bad)
                except (RigError,KeyError,ValueError,OSError,TypeError): check(True,"adapter rejects "+key+"="+str(value))
                else:check(False,"adapter rejects "+key+"="+str(value))
            check("HHC_InferredBindProofSchema" in runtime.assembly() and "HHC_OriginalBonesClaimed\",false" in runtime.assembly(),"assembly stores explicit inferred metadata")
        for file,before in preserved.items():check(proof.sha(file)==before,"preserved "+file.name)
    result={"checks":checks,"failures":failures,"actual_sources":2,"source_modified":False,
        "original_source_gate_preserved":True,"actual_engine_claimed":False,"ready":False,"studio_calls":0,"api_calls":0}
    (output/"inferred_bind_adapter_offline_qa.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(result));return int(bool(failures))


if __name__=="__main__":raise SystemExit(main())
