# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Actual selected source/skin rows and sealed correction rejection tests."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
from pathlib import Path
import copy
import json
import subprocess
import tempfile

import skin_corrected_weight_proof as proof
import skin_schema
import skin_runtime_v2 as runtime
from glb_io import read_glb, write_glb
from constraints import RigError

ROOT=Path(__file__).resolve().parents[2]

def main():
    output=ROOT/'build/remaining_16_corrected_gate_20261004';output.mkdir(exist_ok=True)
    checks=0;failures=[];sources={}
    def check(value,label):
        nonlocal checks
        checks+=1
        if not value: failures.append(label)
    with tempfile.TemporaryDirectory(prefix='weight_rejection_',dir=output) as directory:
        directory=Path(directory)
        for name,rule in proof.RULES.items():
            package=ROOT/'art/models/costume/prepared/skin_corrected'/rule['folder']/'package.json'
            metadata,inputs,pkg=proof.validate_package(package)
            for path in [package,*inputs.values()]: sources[path]=proof.correction.sha(path)
            blueprint=skin_schema.load(package)
            check(blueprint['unique_bones']==23 and blueprint['original_bones_claimed'] is True,name+' retained original bones')
            check(blueprint['corrected_weight_proof']['changed_skin_vertices']==rule['vertices'],name+' exact selected vertices')
            check(blueprint['rig_ready_for_game'] is False and blueprint['actual_inspection_required'] is True,name+' no native claim')
            check(blueprint['corrected_weight_proof']['source_weights_exact'] is False,name+' weights exception explicit')
            baseline=ROOT/pkg['original_benchmark']['workspace_relative_path'];sources[baseline]=proof.correction.sha(baseline)
            plan=json.loads(inputs['weight_correction_plan'].read_text(encoding='utf-8'))
            def refuse(label,alter):
                changed=copy.deepcopy(plan);alter(changed)
                try: proof.validate_surface(baseline,inputs['skin_glb'],changed)
                except (RigError,ValueError,KeyError,TypeError,IndexError): check(True,name+' '+label)
                else: check(False,name+' '+label)
            refuse('duplicate vertex',lambda d:d['changes'].append(copy.deepcopy(d['changes'][0])))
            refuse('foreign vertex',lambda d:d['changes'][0].update(vertex=10**9))
            refuse('wrong source influence',lambda d:d['changes'][0]['old_weights'].__setitem__(0,.31415))
            refuse('wrong redistribution',lambda d:d['changes'][0]['new_weights'].__setitem__(0,.31415))
            refuse('changed UV',lambda d:d['changes'][0]['uv'].__setitem__(0,.31415))
            refuse('changed vertex domain',lambda d:d['changes'][0]['game_position'].__setitem__(0,100))
            refuse('foreign mesh',lambda d:d['changes'][0].update(mesh=99))
            refuse('missing review',lambda d:d.update(region_review_complete=False))
            refuse('promoted region',lambda d:d.update(rig_ready_for_game=True))
            refuse('wrong target',lambda d:d['changes'][0].update(target='LeftHand'))
            refuse('wrong region counts',lambda d:d['region_counts'].update(unknown=1))
            doc,binary,_=read_glb(inputs['skin_glb'])
            def refuse_glb(label,mutate):
                changed=copy.deepcopy(doc);payload=bytearray(binary);mutate(changed,payload)
                file=directory/'changed.glb';write_glb(file,changed,bytes(payload))
                try: proof.validate_surface(baseline,file,plan)
                except (RigError,ValueError,KeyError,TypeError,IndexError): check(True,name+' '+label)
                else: check(False,name+' '+label)
            refuse_glb('original binary byte changed',lambda d,b:b.__setitem__(0,b[0]^1))
            refuse_glb('bone name changed',lambda d,b:d['nodes'][d['skins'][0]['joints'][0]].update(name='ForeignRoot'))
            refuse_glb('lost original bone',lambda d,b:d['skins'][0]['joints'].pop())
            refuse_glb('original material changed',lambda d,b:d['meshes'][0]['primitives'][0].update(material=99))
            refuse_glb('P accessor changed',lambda d,b:d['meshes'][0]['primitives'][0]['attributes'].update(POSITION=d['meshes'][0]['primitives'][0]['attributes']['WEIGHTS_0']))
            refuse_glb('extra surface',lambda d,b:d['meshes'].append(copy.deepcopy(d['meshes'][0])))
            check(proof.correction.sha(inputs['skin_glb'])==rule['output'],name+' exact output seal')
        path=ROOT/'art/models/costume/expressions/Costume_NeutralArcherF/Costume_NeutralArcherF_PreservedSkinExpressions_v1.skin.json'
        source=ROOT/'art/models/costume/prepared/skin_corrected/Costume_NeutralArcherF_weights_v7/package.json'
        sources[path]=proof.correction.sha(path)
        data,_=runtime.prepare(path,'ServerStorage/CostumeExpressionSkinImports_Remaining16_v1/Costume_NeutralArcherF',
            pending_name='Costume_NeutralArcherF_CorrectedBindingSkinSchema2Candidate',source_contract=source,binding_schema=1)
        check(len(data['bones'])==23 and len(data['meshes'])==3,'real corrected three-surface expression')
        check(data['corrected_weight_proof']['corrected_skin_sha256']==proof.RULES['Costume_NeutralArcherF']['output'],'expression exact corrected source seal')
        inspector=directory/'inspect.json';runtime.write_payload(data,'inspect',inspector)
        luau=inspector.with_suffix('.luau');luau.write_text(json.loads(inspector.read_text(encoding='utf-8'))['code'],encoding='utf-8')
        compiled=subprocess.run([str(ROOT/'build/luau_cli_0_741/luau-compile.exe'),str(luau)],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
        check(compiled.returncode==0,'corrected inspector local Luau compile')
        for field in ('weight_correction_plan_sha256','original_benchmark_skin_sha256','rig_origin'):
            altered=json.loads(path.read_text(encoding='utf-8'));altered[field]='unknown'
            foreign=directory/'expression.skin.json';foreign.write_text(json.dumps(altered),encoding='utf-8')
            try: skin_schema.load(foreign)
            except (RigError,ValueError,KeyError,TypeError): check(True,'untrusted corrected '+field)
            else: check(False,'untrusted corrected '+field)
        for file,old in sources.items(): check(proof.correction.sha(file)==old,'source preserved '+file.name)
    report={'checks':checks,'failures':failures,'selected_corrected_sources':len(proof.RULES),'actual_imports_claimed':False,
            'exact_original_gate_preserved':True,'source_modified':False,'ready':False,'studio_calls':0,'api_calls':0,'uploads':0}
    (output/'corrected_weight_offline_qa.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report));return int(bool(failures))

if __name__=='__main__': raise SystemExit(main())
