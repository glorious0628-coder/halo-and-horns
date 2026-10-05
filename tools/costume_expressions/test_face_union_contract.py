# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Exercise union preservation failures using new ignored temporary copies only."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import copy
import json
from pathlib import Path
import struct
import sys
import tempfile

from finalize_skin_assets import inspect, sha, ROOT

sys.path.insert(0, str(ROOT/'tools/costume_r15'))
from glb_io import read_glb, write_glb


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('glb', type=Path)
    parser.add_argument('prepare_report', type=Path)
    args = parser.parse_args()
    source = args.glb.resolve()
    before = sha(source)
    result, report, doc, binary = inspect(source, args.prepare_report)
    if not result['original_triangles_only']:
        raise ValueError('Exact original-only union required')
    temporary_root = ROOT/'build/expr_qa'
    directory = Path(tempfile.mkdtemp(prefix='union_contract_', dir=temporary_root)).resolve()
    if temporary_root.resolve() not in directory.parents:
        raise ValueError('Temporary test path escaped the intended workspace')
    created = []
    passed = []
    def offset(document, accessor_index):
        accessor = document['accessors'][accessor_index]
        return document['bufferViews'][accessor['bufferView']].get('byteOffset', 0) + accessor.get('byteOffset', 0)
    try:
        for name in ['face_position', 'face_uv', 'face_weights', 'triangle_winding', 'false_cap_flag']:
            changed_doc = copy.deepcopy(doc)
            changed_binary = bytearray(binary)
            changed_report = copy.deepcopy(report)
            face = changed_doc['meshes'][2]['primitives'][0]
            if name in ['face_position', 'face_uv', 'face_weights']:
                key = {'face_position':'POSITION', 'face_uv':'TEXCOORD_0', 'face_weights':'WEIGHTS_0'}[name]
                index = offset(changed_doc, face['attributes'][key])
                old = struct.unpack_from('<f', changed_binary, index)[0]
                struct.pack_into('<f', changed_binary, index, old + .02)
            elif name == 'triangle_winding':
                index = offset(changed_doc, face['indices'])
                first, second = struct.unpack_from('<II', changed_binary, index)
                struct.pack_into('<II', changed_binary, index, second, first)
            else:
                changed_report['original_triangles_only'] = False
            output = directory/(name + '.glb')
            metadata = output.with_suffix('.json')
            created.extend([output, metadata])
            write_glb(output, changed_doc, bytes(changed_binary))
            changed_report['sha256'] = sha(output)
            metadata.write_text(json.dumps(changed_report), encoding='utf-8')
            try:
                inspect(output, args.prepare_report)
            except ValueError as error:
                passed.append({'case': name, 'rejected': True, 'reason': str(error)})
            else:
                raise AssertionError('Preservation mutation accepted: ' + name)
        prep = json.loads(args.prepare_report.read_text(encoding='utf-8'))
        if prep.get('verified_original_face_union_extension'):
            corrupted = copy.deepcopy(prep)
            corrupted['verified_original_face_union_extension']['added_original_mouth_triangles'][0]['original_vertex_indices'][0] += 1
            bad_prepare = directory/'wrong_mouth_provenance.json'
            created.append(bad_prepare)
            bad_prepare.write_text(json.dumps(corrupted), encoding='utf-8')
            try:
                inspect(source, bad_prepare)
            except ValueError as error:
                passed.append({'case':'wrong_mouth_provenance', 'rejected':True, 'reason':str(error)})
            else:
                raise AssertionError('Incorrect original mouth provenance accepted')
        if sha(source) != before:
            raise AssertionError('Source candidate changed')
        print(json.dumps({'positive_union_preservation_pass':True, 'negative_cases':passed,
                          'source_unchanged':True, 'studio_called':False}))
    finally:
        for path in created:
            if path.parent.resolve() != directory:
                raise ValueError('Unexpected test cleanup target')
            if path.exists():
                path.unlink()
        directory.rmdir()


if __name__ == '__main__':
    main()
