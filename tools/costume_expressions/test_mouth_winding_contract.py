"""Reject self-consistent GLB/ledger mutations outside original-mouth winding."""
import copy
import json
from pathlib import Path
import struct
import sys
import tempfile

from validate_mouth_winding import check
from validate_mouth_restoration import ROOT, sha
from glb_io import read_glb, write_glb


def main():
    source = Path(sys.argv[1]).resolve()
    report = json.loads(source.with_suffix('.json').read_text(encoding='utf-8'))
    ledger = json.loads(Path(report['mouth_winding_ledger']).read_text(encoding='utf-8'))
    document, binary, _ = read_glb(source)
    check(source)
    workspace = (ROOT / 'build/expr_qa/mouth_contract_tests').resolve()
    workspace.mkdir(parents=True, exist_ok=True)
    results = []
    with tempfile.TemporaryDirectory(prefix='winding_', dir=workspace) as temporary:
        directory = Path(temporary).resolve()
        if workspace not in directory.parents:
            raise ValueError('Test directory escaped workspace')

        def attempt(name, mutate):
            doc, data = copy.deepcopy(document), bytearray(binary)
            record, proof = copy.deepcopy(report), copy.deepcopy(ledger)
            mutate(doc, data, record, proof)
            candidate = directory / 'candidate.glb'
            proof_path = directory / 'candidate.winding.json'
            write_glb(candidate, doc, bytes(data))
            proof_path.write_text(json.dumps(proof, indent=2) + '\n', encoding='utf-8')
            record.update(glb=str(candidate), sha256=sha(candidate),
                          mouth_winding_ledger=str(proof_path), mouth_winding_ledger_sha256=sha(proof_path))
            candidate.with_suffix('.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
            try:
                check(candidate)
            except (ValueError, IndexError, KeyError) as error:
                results.append({'mutation': name, 'rejected': True, 'reason': str(error)})
            else:
                raise AssertionError('Unauthorized winding mutation accepted: ' + name)

        def index_offset(doc, mesh, face):
            accessor = doc['accessors'][doc['meshes'][mesh]['primitives'][0]['indices']]
            view = doc['bufferViews'][accessor['bufferView']]
            size = 4 if accessor['componentType'] == 5125 else 2
            return view.get('byteOffset', 0) + accessor.get('byteOffset', 0) + face * 3 * size

        corrected = {row['expression_face_index'] for row in ledger['changed_triangles']}
        count = document['accessors'][document['meshes'][2]['primitives'][0]['indices']]['count'] // 3
        outside = next(index for index in range(count) if index not in corrected)

        def reverse_unlisted(doc, data, record, proof):
            offset = index_offset(doc, 2, outside)
            row = struct.unpack_from('<III', data, offset)
            struct.pack_into('<III', data, offset, row[0], row[2], row[1])

        def different_vertex_set(doc, data, record, proof):
            face = proof['changed_triangles'][0]['expression_face_index']
            offset = index_offset(doc, 2, face)
            value = struct.unpack_from('<I', data, offset)[0]
            struct.pack_into('<I', data, offset, value + 1)

        def original_storage(doc, data, mesh, attribute):
            accessor = doc['accessors'][doc['meshes'][mesh]['primitives'][0]['attributes'][attribute]]
            view = doc['bufferViews'][accessor['bufferView']]
            offset = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
            data[offset] ^= 1

        attempt('unlisted original triangle reversal', reverse_unlisted)
        attempt('replacement original vertex set', different_vertex_set)
        attempt('missing corrected original face', lambda d, b, r, p: p['changed_triangles'].pop())
        attempt('false original face provenance', lambda d, b, r, p: p['changed_triangles'][0].update(original_head_face_index=0))
        attempt('wrong original surface orientation', lambda d, b, r, p: p.update(desired_original_surface_normal_sign=-p['desired_original_surface_normal_sign']))
        attempt('Body original position', lambda d, b, r, p: original_storage(d, b, 0, 'POSITION'))
        attempt('Head restored position', lambda d, b, r, p: original_storage(d, b, 1, 'POSITION'))
        attempt('Head restored normal', lambda d, b, r, p: original_storage(d, b, 1, 'NORMAL'))
        attempt('Face approved UV', lambda d, b, r, p: original_storage(d, b, 2, 'TEXCOORD_0'))
        attempt('Head skin weights', lambda d, b, r, p: original_storage(d, b, 1, 'WEIGHTS_0'))
        attempt('Head skin joints', lambda d, b, r, p: original_storage(d, b, 1, 'JOINTS_0'))
        attempt('original Bone hierarchy', lambda d, b, r, p: d['nodes'][d['skins'][0]['joints'][0]].update(name='UnexpectedBone'))

        def png_change(doc, data, record, proof):
            offset = doc['bufferViews'][doc['images'][0]['bufferView']].get('byteOffset', 0)
            data[offset + 20] ^= 1

        attempt('original PNG byte', png_change)
        attempt('false new triangle count', lambda d, b, r, p: p.update(new_triangles=1))
        attempt('false engine promotion', lambda d, b, r, p: r.update(runtime_validated=True))
    if sha(source) != report['sha256']:
        raise AssertionError('Winding candidate changed during mutation tests')
    output = workspace / (source.stem + '_tests.json')
    if output.exists():
        raise ValueError('Use a fresh test record')
    output.write_text(json.dumps({'positive': True, 'glb': str(source), 'sha256': sha(source),
                                 'mutations': results, 'all_rejected': True,
                                 'source_unchanged': True, 'ready': False}, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'positive': True, 'negative_mutations_rejected': len(results), 'output': str(output)}), flush=True)


if __name__ == '__main__':
    main()
