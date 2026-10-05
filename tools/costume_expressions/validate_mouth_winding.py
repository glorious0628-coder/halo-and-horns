# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
# Still importable as a library ONLY because live tools import it (tools/monster_import_preflight.py,
# tools/test_weapon_motion.py, GLB audit tools). Never run it directly.
"""Validate a separate original-mouth-only winding exception after strict P/N QA."""
if __name__ == "__main__":
    raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import copy
import json
from pathlib import Path
import sys

import numpy as np

from validate_mouth_restoration import check as check_parent,sha
from glb_io import read_glb,accessor_values


def check(glb):
    glb=Path(glb).resolve();report=json.loads(glb.with_suffix('.json').read_text(encoding='utf-8'))
    ledger_path=Path(report['mouth_winding_ledger'])
    if sha(glb)!=report['sha256'] or sha(ledger_path)!=report['mouth_winding_ledger_sha256']:
        raise ValueError('Current exact winding candidate and ledger required')
    ledger=json.loads(ledger_path.read_text(encoding='utf-8'))
    parent=Path(ledger['input_mouth_glb'])
    if ledger['kind']!='original_mouth_wall_winding_only_v1' or sha(parent)!=ledger['input_mouth_glb_sha256']:
        raise ValueError('Exact original P/N candidate required')
    parent_validation=check_parent(parent)
    if sha(ledger['mouth_geometry_ledger'])!=ledger['mouth_geometry_ledger_sha256'] or report['mouth_geometry_restoration_ledger_sha256']!=ledger['mouth_geometry_ledger_sha256']:
        raise ValueError('Original bounded P/N proof changed')
    mouth=json.loads(Path(ledger['mouth_geometry_ledger']).read_text(encoding='utf-8'))
    if sha(ledger['source_skin'])!=ledger['source_skin_sha256'] or mouth['source_skin_sha256']!=ledger['source_skin_sha256']:
        raise ValueError('Exact source skin required')
    doc,binary,_=read_glb(glb);old,old_binary,_=read_glb(parent)
    if binary[:len(old_binary)]!=old_binary or len(doc['accessors'])!=len(old['accessors'])+1 or len(doc['bufferViews'])!=len(old['bufferViews'])+1:
        raise ValueError('Only one appended triangle-index array is allowed')
    if doc['accessors'][:-1]!=old['accessors'] or doc['bufferViews'][:-1]!=old['bufferViews']:
        raise ValueError('Existing geometry/UV/JW/image storage changed')
    cleaned=copy.deepcopy(doc);cleaned.update(accessors=old['accessors'],bufferViews=old['bufferViews'],buffers=old['buffers'])
    cleaned['meshes'][2]['primitives'][0]['indices']=old['meshes'][2]['primitives'][0]['indices']
    if cleaned!=old:raise ValueError('Only original Face triangle index reference may change')
    primitive=doc['meshes'][2]['primitives'][0];op=old['meshes'][2]['primitives'][0]
    current=np.asarray(accessor_values(doc,binary,primitive['indices']),int).reshape(-1,3)
    previous=np.asarray(accessor_values(old,old_binary,op['indices']),int).reshape(-1,3)
    if current.shape!=previous.shape or ledger['new_vertices'] or ledger['new_triangles']:
        raise ValueError('Original face and vertex counts must stay unchanged')
    points=np.asarray(accessor_values(old,old_binary,op['attributes']['POSITION']))
    fixed=(np.column_stack((points,np.ones(len(points))))@np.linalg.inv(np.asarray(mouth['fixed_to_skin_affine'])).T)[:,:3]
    eligible={r['vertex'] for r in mouth['changed_vertices']};sign=mouth.get('normal_orientation_sign',1)
    expected=[]
    for index,tri in enumerate(previous):
        if set(tri).issubset(eligible) and sign*np.cross(fixed[tri[1]]-fixed[tri[0]],fixed[tri[2]]-fixed[tri[0]])[2]<-1e-12:
            expected.append(index)
    rows={r['expression_face_index']:r for r in ledger['changed_triangles']}
    if not expected or sorted(rows)!=expected or len(rows)!=len(ledger['changed_triangles']) or sign!=ledger['desired_original_surface_normal_sign']:
        raise ValueError('Only and all originally inverted, bounded mouth-wall triangles may reverse')
    source,source_binary,_=read_glb(ledger['source_skin'])
    source_tri=np.asarray(accessor_values(source,source_binary,source['meshes'][1]['primitives'][0]['indices']),int).reshape(-1,3)
    for index,(before,after) in enumerate(zip(previous,current)):
        if index not in rows:
            if not np.array_equal(before,after):raise ValueError('Non-mouth triangle indices changed')
            continue
        row=rows[index]
        normal=np.cross(fixed[before[1]]-fixed[before[0]],fixed[before[2]]-fixed[before[0]])
        if not np.array_equal(before,row['old_original_vertex_indices']) or not np.array_equal(after,before[[0,2,1]]) or not np.array_equal(after,row['new_vertex_indices']):
            raise ValueError('Only exact winding reversal of original three vertices allowed')
        if not np.array_equal(source_tri[row['original_head_face_index']],before) or not np.allclose(normal,row['original_fixed_cross_normal'],atol=1e-12):
            raise ValueError('Winding ledger does not match the exact original triangle')
    if any(report.get(k) or ledger.get(k) for k in ['ready','runtime_validated','roblox_uploaded']):raise ValueError('Offline candidate may not claim engine promotion')
    return {'schema':1,'kind':ledger['kind'],'glb':str(glb),'sha256':sha(glb),'ledger':str(ledger_path),'ledger_sha256':sha(ledger_path),
        'parent_mouth_glb_sha256':sha(parent),'source_skin_sha256':ledger['source_skin_sha256'],
        'parent_mouth_changed_original_vertices':parent_validation['changed_original_mouth_vertices'],
        'changed_original_mouth_triangles':len(rows),'changed_expression_face_indices':expected,
        'original_triangle_vertex_sets_exact':True,'new_vertices':0,'new_triangles':0,
        'parent_position_normal_uv_joint_weight_bones_images_exact':True,'body_headbase_indices_exact':True,
        'ready':False,'runtime_validated':False,'roblox_uploaded':False}


if __name__=='__main__':
    result=check(sys.argv[1]);print(json.dumps(result),flush=True)
    if len(sys.argv)>2:
        output=Path(sys.argv[2])
        if output.exists():raise ValueError('Use a fresh winding validation record')
        output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
