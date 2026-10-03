"""Reverse only inverted original mouth-wall triangles in a new P/N copy.

No vertices, UV, normals, weights, bones or images are changed. Each corrected
triangle keeps its same three original vertex indices; only its order reverses.
"""
import copy
import json
from pathlib import Path
import sys

import numpy as np

from validate_mouth_restoration import check,sha
from glb_io import read_glb,write_glb,accessor_values


def main():
    parent,output=[Path(p).resolve() for p in sys.argv[1:]]
    if output.exists() or output.with_suffix('.json').exists():raise ValueError('Use a new winding-only candidate')
    check(parent)
    report=json.loads(parent.with_suffix('.json').read_text(encoding='utf-8'))
    mouth=json.loads(Path(report['mouth_geometry_restoration_ledger']).read_text(encoding='utf-8'))
    document,binary,_=read_glb(parent)
    source,source_binary,_=read_glb(mouth['source_skin'])
    primitive=document['meshes'][2]['primitives'][0]
    points=np.asarray(accessor_values(document,binary,primitive['attributes']['POSITION']))
    triangles=np.asarray(accessor_values(document,binary,primitive['indices']),dtype='<u4').reshape(-1,3)
    original=source['meshes'][1]['primitives'][0]
    source_triangles=np.asarray(accessor_values(source,source_binary,original['indices']),int).reshape(-1,3)
    source_rows={tuple(tri):i for i,tri in enumerate(source_triangles)}
    frame=np.asarray(mouth['fixed_to_skin_affine'])
    fixed=(np.column_stack((points,np.ones(len(points))))@np.linalg.inv(frame).T)[:,:3]
    changed={r['vertex'] for r in mouth['changed_vertices']}
    desired_sign=mouth.get('normal_orientation_sign',1)
    corrected=triangles.copy();rows=[]
    for index,tri in enumerate(triangles):
        if not set(tri.tolist()).issubset(changed):continue
        normal=np.cross(fixed[tri[1]]-fixed[tri[0]],fixed[tri[2]]-fixed[tri[0]])
        if desired_sign*normal[2]>=-1e-12:continue
        corrected[index]=tri[[0,2,1]]
        rows.append({'expression_face_index':index,'original_head_face_index':source_rows[tuple(tri)],
                     'old_original_vertex_indices':tri.tolist(),'new_vertex_indices':corrected[index].tolist(),
                     'original_fixed_cross_normal':normal.tolist(),
                     'reason':'Original inward mouth-wall projected winding opposes the approved adjacent skin normal after depression restoration'})
    if not rows:raise ValueError('No inverted restored original-mouth wall triangles found')
    appended=bytearray(binary);appended.extend(b'\0'*(-len(appended)%4));offset=len(appended)
    content=corrected.reshape(-1).tobytes();appended.extend(content)
    document['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(content),'target':34963})
    document['accessors'].append({'bufferView':len(document['bufferViews'])-1,'componentType':5125,
                                  'count':corrected.size,'type':'SCALAR','min':[int(corrected.min())],'max':[int(corrected.max())]})
    primitive['indices']=len(document['accessors'])-1
    document['buffers'][0]['byteLength']=len(appended)
    write_glb(output,document,bytes(appended))
    ledger={'schema':1,'kind':'original_mouth_wall_winding_only_v1','input_mouth_glb':str(parent),
        'input_mouth_glb_sha256':sha(parent),'mouth_geometry_ledger':report['mouth_geometry_restoration_ledger'],
        'mouth_geometry_ledger_sha256':report['mouth_geometry_restoration_ledger_sha256'],
        'source_skin':mouth['source_skin'],'source_skin_sha256':mouth['source_skin_sha256'],
        'desired_original_surface_normal_sign':desired_sign,'changed_triangles':rows,
        'triangle_vertex_sets_preserved':True,'position_normal_uv_joint_weight_bones_images_unchanged_from_parent':True,
        'new_vertices':0,'new_triangles':0,'ready':False,'runtime_validated':False}
    ledger_path=output.with_suffix('.winding.json');ledger_path.write_text(json.dumps(ledger,indent=2)+'\n',encoding='utf-8')
    report.update(glb=str(output),sha256=sha(output),mouth_winding_ledger=str(ledger_path),mouth_winding_ledger_sha256=sha(ledger_path),
        original_oriented_triangle_indices_preserved=False,original_triangle_vertex_sets_preserved=True,
        ready=False,runtime_validated=False,roblox_uploaded=False,
        limitations=['Original mouth P/N exception inherited; only listed original inward mouth-wall index orders are reversed.',
                     'No vertex, UV, weight, image or mesh-count changes; lit rest/Fx and native game QA pending.'])
    output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'output':str(output),'sha256':sha(output),'reversed_original_mouth_triangles':len(rows),
                      'new_triangles':0,'new_vertices':0,'ready':False}),flush=True)


if __name__=='__main__':main()
