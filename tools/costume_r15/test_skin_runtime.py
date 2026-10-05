# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Compile/run the actual draft module offline; Roblox objects are test doubles.

Never calls Studio, network, upload, API, src editing or a playable registry.
Uses preserved actual 15/23-bone source sidecars for test hierarchy/matrices.
"""
from __future__ import annotations

raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

import numpy as np
import skin_runtime as runtime
from constraints import JOINTS, PRIMARY

ROOT=Path(__file__).resolve().parents[2]


def lua(value):
    if value is None: return "nil"
    if value is True: return "true"
    if value is False: return "false"
    if isinstance(value,str): return json.dumps(value,ensure_ascii=False)
    if isinstance(value,(int,float)): return repr(value)
    if isinstance(value,list): return "{"+",".join(lua(v) for v in value)+"}"
    if isinstance(value,dict): return "{"+",".join("["+lua(k)+"]="+lua(v) for k,v in value.items())+"}"
    raise TypeError(type(value))


def fixture(path):
    d=json.loads(path.read_text(encoding="utf-8"));manual=d.get("rig_origin")=="inferred_manual_candidate"
    name=d.get("name") or Path(d["proxy_plan"]).parent.name
    result=[]
    for b in d["bones"]:
        matrix=np.array(b["gltf_bind_game_world_column_major"] if manual else b["game_bind_world"]).reshape(4,4).T
        rotation=matrix[:3,:3]/np.linalg.norm(matrix[:3,:3],axis=0)
        if not np.allclose(rotation.T@rotation,np.eye(3),atol=1e-5) or np.linalg.det(rotation)<0: raise ValueError("Source fixture has invalid unit axes")
        result.append({"name":b["name"],"parent":None if manual and b["parent"]=="HumanoidRootPart" else b["parent"] if manual else b["parent_name"],
                       "part":b["name"] if manual else b["proxy_part"],"principal":True if manual else b["principal"],
                       "world":matrix[:3,3].tolist()+rotation.reshape(9).tolist()})
    assert len(result)==(15 if manual else 23)
    assert sum(b["principal"] for b in result)==15
    return {"name":name,"bones":result}


def main():
    ast.parse(Path(runtime.__file__).read_text(encoding="utf-8"))
    out=ROOT/"build/skin_runtime_v2";out.mkdir(exist_ok=True)
    module=out/"SkinRetargetClient_tested.luau"
    module.write_text(runtime.CLIENT_MODULE,encoding="utf-8")
    manual=ROOT/"build/manual_partition_candidates/NeutralWarriorF_skin_v3/runtime_contract.json"
    paid=ROOT/"build/costume_r15/skin_candidates/Costume_HaloArcherM_v2/Costume_HaloArcherM_skin.skin.json"
    prefix="local CLIENT_MODULE_SOURCE=[====["+runtime.CLIENT_MODULE+"]====]\n"
    prefix+="local MANUAL_FIXTURE="+lua(fixture(manual))+"\nlocal PAID_FIXTURE="+lua(fixture(paid))+"\n"
    prefix+="local FIXTURE_EDGES="+lua({name:[p0,p1] for name,p0,p1,_ in JOINTS})+"\n"
    harness=out/"skin_runtime_offline.luau"
    harness.write_text(prefix+Path(__file__).with_name("skin_runtime_fixture.luau").read_text(encoding="utf-8"),encoding="utf-8")
    directory=ROOT/"build/luau_cli_0_741"
    compiler=directory/"luau-compile.exe";interpreter=directory/"luau.exe"
    if not compiler.is_file() or not interpreter.is_file(): raise SystemExit("Installed Luau CLI is required; no download is attempted")
    syntax=subprocess.run([str(compiler),str(module),str(harness)],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,text=True,encoding="utf-8",timeout=60)
    execution=subprocess.run([str(interpreter),str(harness)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,encoding="utf-8",timeout=60) if syntax.returncode==0 else None
    if execution: print(execution.stdout,end="");print(execution.stderr,end="")
    if syntax.stderr: print(syntax.stderr,end="")
    match=re.search(r"SKIN_RUNTIME_SUMMARY checks=(\d+) failed=(\d+) Studio/API calls=0",execution.stdout if execution else "")
    report={"source_sha256":hashlib.sha256(runtime.CLIENT_MODULE.encode()).hexdigest(),"compiler_exit":syntax.returncode,
            "execution_exit":execution.returncode if execution else None,"checks":int(match[1]) if match else 0,"failed":int(match[2]) if match else None,
            "fixture_sources":{"manual":str(manual),"paid":str(paid)},"module_path":str(module),"studio_calls":0,"api_calls":0,
            "original_source_modified":False,"live_multiplayer_pass_claimed":False,"production_registered":False}
    (out/"client_module_offline_qa.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report))
    return 0 if syntax.returncode==0 and execution and execution.returncode==0 and match and int(match[2])==0 else 1


if __name__=="__main__": raise SystemExit(main())
