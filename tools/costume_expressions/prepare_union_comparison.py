"""Record an exact union as a geometry comparison, without visual promotion."""
import argparse
import copy
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import subprocess
import sys

import numpy as np

from finalize_skin_assets import inspect,relative,sha,ROOT
from glb_io import read_glb,accessor_values


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('glb',type=Path)
    parser.add_argument('prepare',type=Path)
    args=parser.parse_args()
    glb=args.glb.resolve();folder=glb.parent
    names={k:folder/n for k,n in {'manifest':'face_union_manifest.json','validation':'face_union_validation.json',
        'prepare':'face_union_prepare_report.json','provenance':'face_union_provenance.json',
        'compatibility':'face_union_uv_compatibility.json'}.items()}
    if any(p.exists() for p in names.values()) or glb.with_suffix('.skin.json').exists():
        raise ValueError('Use a union without previously finalized comparison records')
    validation,report,doc,binary=inspect(glb,args.prepare)
    if not validation['original_triangles_only']:raise ValueError('Exact no-cap original union required')
    source=Path(report['source_skin']);sd,sb,_=read_glb(source)
    primitive=sd['meshes'][1]['primitives'][0]
    face=doc['meshes'][2]['primitives'][0]
    triangles=np.asarray(accessor_values(sd,sb,primitive['indices']),int).reshape(-1,3)
    selected=np.asarray(accessor_values(doc,binary,face['indices']),int).reshape(-1,3)
    mapping=defaultdict(list)
    for index,t in enumerate(triangles):mapping[tuple(t)].append(index)
    fields={k:np.asarray(accessor_values(sd,sb,primitive['attributes'][k])) for k in ['POSITION','NORMAL','TEXCOORD_0','JOINTS_0','WEIGHTS_0']}
    rows=[]
    for index,t in enumerate(selected):
        if len(mapping[tuple(t)])!=1:raise ValueError('Unique original oriented face required')
        rows.append({'expression_face_index':index,'original_head_face_index':mapping[tuple(t)][0],
                     'original_vertex_indices':t.tolist(),'original_uv':fields['TEXCOORD_0'][t].tolist()})
    active=np.unique(selected)
    provenance={'schema':1,'avatar':folder.name,'source_skin':relative(source),'source_skin_sha256':sha(source),
        'expression_skin_sha256':sha(glb),'original_head_triangles':len(triangles),'selected_original_triangles':len(selected),
        'selected_unique_vertices':len(active),'new_vertices':0,'source_face_indices':[r['original_head_face_index'] for r in rows],
        'triangles':rows,'vertices':[{'original_vertex_index':int(i),'position':fields['POSITION'][i].tolist(),
            'normal':fields['NORMAL'][i].tolist(),'original_uv':fields['TEXCOORD_0'][i].tolist(),
            'joints':fields['JOINTS_0'][i].tolist(),'weights':fields['WEIGHTS_0'][i].tolist()} for i in active],
        'oriented_original_indices_sha256':hashlib.sha256(selected.astype('<u4').tobytes()).hexdigest(),
        'joint_slot_order':[sd['nodes'][i]['name'] for i in sd['skins'][0]['joints']],
        'geometry_normal_joint_weight_values_exact':True,'new_interpolated_vertices':0,'source_unchanged':True,
        'geometry_comparison_only':True,'visual_quality_hold':True,'ready':False}
    baseline_path=folder/'expressions_manifest.json'
    baseline=json.loads(baseline_path.read_text(encoding='utf-8'))
    for row in baseline['records']:
        if sha(ROOT/row['png'])!=row['sha256']:raise ValueError('Approved GPT PNG changed')
    projected=np.asarray(accessor_values(doc,binary,face['attributes']['TEXCOORD_0']),dtype='<f4')
    uv_sha=hashlib.sha256(projected.tobytes()).hexdigest()
    compatibility={'schema':1,'avatar':folder.name,'expression_skin_sha256':sha(glb),
        'comparison_manifest':relative(baseline_path),'comparison_manifest_sha256':sha(baseline_path),
        'normalized_original_face_uv_sha256':uv_sha,'canonical_normalized_original_face_uv_sha256':uv_sha,
        'normalized_original_face_uv_float32_exact':True,'approved_png_bytes_unchanged':True,
        'comparison_uv_basis':'Exact approved normalized projection checked by inspect against original fixed/skin corners',
        'expression_pngs':[{k:r[k] for k in ['state','png','sha256']} for r in baseline['records']],
        'mesh_asset_reimport_required':True,'texture_reuse_policy':'Actual upload-ledger PNG SHA must match.',
        'geometry_comparison_only':True,'ready':False}
    for key,value in [('validation',validation),('provenance',provenance),('compatibility',compatibility)]:
        names[key].write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
    names['prepare'].write_bytes(args.prepare.read_bytes())
    manifest={'schema':1,'avatar':folder.name,'pipeline':'preserved_continuous_skin_expression',
        'skin_asset':relative(glb),'skin_sha256':sha(glb),'source_skin_sha256':sha(source),
        'source_fixed_sha256':report['source_fixed_sha256'],'rig_origin':report['rig_origin'],
        'original_bones_claimed':report['original_bones_claimed'],'source_skin_bones':report['source_skin_bones'],
        'prepare_report':relative(names['prepare']),'validation_report':relative(names['validation']),
        'original_triangles_only':True,'selected_original_face_triangles':len(selected),'new_mouth_cap_vertices':0,
        'candidate_variant':'original_triangle_union_geometry_comparison_only','geometry_comparison_only':True,
        'visual_quality_hold':True,'ready':False,'runtime_validated':False,'roblox_uploaded':False,
        'approved_states':baseline['approved_states'],'approval_preview':baseline.get('approval_preview'),
        'records':copy.deepcopy(baseline['records']),'meshes':['CostumeSkinBody','HeadBase','FaceExpression'],
        'glb_expected_import_assets':7,'full_set_maximum_import_assets':9,
        'original_face_provenance':relative(names['provenance']),'original_face_provenance_sha256':sha(names['provenance']),
        'uv_texture_compatibility':relative(names['compatibility']),'uv_texture_compatibility_sha256':sha(names['compatibility']),
        'offline_visual_review':'Geometry comparison only; original mouth depression remains and is not visually approved.',
        'limitations':['Exact preservation comparison only; a separate mouth-restored copy requires strict exception and lit/native QA.']}
    for row in manifest['records']:
        row.update(quality_status='geometry comparison only; visual quality hold',closed_mouth_offline_render_verified=False,
                   offline_previews=[],runtime_validated=False,roblox_uploaded=False)
    names['manifest'].write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    subprocess.run([sys.executable,str(Path(__file__).with_name('write_skin_runtime_sidecar.py')),str(names['manifest'])],check=True)
    print(json.dumps({'manifest':str(names['manifest']),'comparison_only':True,'visual_quality_hold':True,'ready':False}),flush=True)


if __name__=='__main__':main()
