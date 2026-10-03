"""Reject mutations outside the exact original-mouth P/N exception."""
import copy
import hashlib
import json
from pathlib import Path
import struct
import sys
import tempfile

from validate_mouth_restoration import check,ROOT,sha
from glb_io import read_glb,write_glb


def main():
    source=Path(sys.argv[1]).resolve()
    original_report=json.loads(source.with_suffix('.json').read_text(encoding='utf-8'))
    original_ledger=json.loads(Path(original_report['mouth_geometry_restoration_ledger']).read_text(encoding='utf-8'))
    document,binary,_=read_glb(source)
    positive=check(source)
    results=[]
    workspace=(ROOT/'build/expr_qa/mouth_contract_tests').resolve();workspace.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='mutation_',dir=workspace) as temporary:
        directory=Path(temporary).resolve()
        if workspace not in directory.parents:raise ValueError('Test output escaped workspace')
        def attempt(name,mutate):
            doc=copy.deepcopy(document);data=bytearray(binary);ledger=copy.deepcopy(original_ledger);report=copy.deepcopy(original_report)
            mutate(doc,data,ledger,report)
            candidate=directory/'candidate.glb';ledger_path=directory/'candidate.mouth.json'
            write_glb(candidate,doc,bytes(data))
            ledger_path.write_text(json.dumps(ledger,indent=2)+'\n',encoding='utf-8')
            report.update(glb=str(candidate),sha256=sha(candidate),mouth_geometry_restoration_ledger=str(ledger_path),mouth_geometry_restoration_ledger_sha256=sha(ledger_path))
            candidate.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
            try:check(candidate)
            except ValueError as error:results.append({'mutation':name,'rejected':True,'reason':str(error)})
            else:raise AssertionError('Unauthorized mutation accepted: '+name)
        def alter(doc,data,mesh,key,vertex=0):
            accessor=doc['accessors'][doc['meshes'][mesh]['primitives'][0]['attributes'][key]]
            view=doc['bufferViews'][accessor['bufferView']]
            dimensions={'VEC2':2,'VEC3':3,'VEC4':4}[accessor['type']]
            component=accessor['componentType'];size=4 if component==5126 else 2 if component==5123 else 1
            offset=view.get('byteOffset',0)+accessor.get('byteOffset',0)+vertex*view.get('byteStride',size*dimensions)
            if component==5126:
                old=struct.unpack_from('<f',data,offset)[0];struct.pack_into('<f',data,offset,old+.01)
            elif component==5123:
                old=struct.unpack_from('<H',data,offset)[0];struct.pack_into('<H',data,offset,(old+1)%23)
            else:data[offset]=(data[offset]+1)%23
        outside=next(i for i in range(doc_count(document)) if i not in {r['vertex'] for r in original_ledger['changed_vertices']})
        attempt('non-mouth position',lambda d,b,l,r:alter(d,b,1,'POSITION',outside))
        attempt('non-mouth normal',lambda d,b,l,r:alter(d,b,1,'NORMAL',outside))
        attempt('Body position',lambda d,b,l,r:alter(d,b,0,'POSITION'))
        attempt('Face normalized UV',lambda d,b,l,r:alter(d,b,2,'TEXCOORD_0'))
        attempt('Head skin weight',lambda d,b,l,r:alter(d,b,1,'WEIGHTS_0'))
        attempt('Head skin joint',lambda d,b,l,r:alter(d,b,1,'JOINTS_0'))
        def change_index(d,b,l,r):
            a=d['accessors'][d['meshes'][2]['primitives'][0]['indices']];v=d['bufferViews'][a['bufferView']];offset=v.get('byteOffset',0)+a.get('byteOffset',0)
            b[offset]^=1
        attempt('original facial triangle index',change_index)
        attempt('original Bone hierarchy',lambda d,b,l,r:d['nodes'][d['skins'][0]['joints'][0]].update(name='UnexpectedBone'))
        def change_png(d,b,l,r):b[d['bufferViews'][d['images'][0]['bufferView']].get('byteOffset',0)+20]^=1
        attempt('original PNG byte',change_png)
        attempt('false original vertex provenance',lambda d,b,l,r:l['changed_vertices'][0]['old_position'].__setitem__(0,l['changed_vertices'][0]['old_position'][0]+.01))
        attempt('mouth radius outside approved profile',lambda d,b,l,r:l['mouth_radii_screen'].__setitem__(0,l['mouth_radii_screen'][0]+100))
        attempt('missing shared boundary ledger vertex',lambda d,b,l,r:l['changed_vertices'].pop())
        def coherent_wrong_curve(d,b,l,r):
            row=l['changed_vertices'][0];alter(d,b,1,'POSITION',row['vertex'])
            from glb_io import accessor_values
            row['new_position']=list(accessor_values(d,b,d['meshes'][1]['primitives'][0]['attributes']['POSITION'])[row['vertex']])
        attempt('self-consistent out-of-curve P/N ledger',coherent_wrong_curve)
        attempt('false runtime promotion',lambda d,b,l,r:r.update(runtime_validated=True))
    if sha(source)!=original_report['sha256']:raise AssertionError('Candidate changed during negative tests')
    result={'positive':True,'glb':str(source),'sha256':sha(source),'mutations':results,'all_rejected':True,'source_unchanged':True,'ready':False}
    output=ROOT/'build/expr_qa/mouth_contract_tests'/(source.stem+'_tests.json')
    if output.exists():raise ValueError('Use a fresh candidate for a new test record')
    output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'positive':True,'negative_mutations_rejected':len(results),'output':str(output),'source_unchanged':True}),flush=True)


def doc_count(document):
    return document['accessors'][document['meshes'][1]['primitives'][0]['attributes']['POSITION']]['count']


if __name__=='__main__':main()
