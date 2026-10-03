"""Check the bounded original-mouth P/N exception without weakening skin checks.

The original-triangle union remains the exact-preservation baseline. This
separate validator accepts only its recorded mouth depression restoration;
body, topology, UV, joint/weight arrays, bones and embedded images stay exact.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/costume_r15'))
from glb_io import read_glb,accessor_values
from finalize_skin_assets import inspect


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def values(document,binary,primitive,key):
    return np.asarray(accessor_values(document,binary,primitive['attributes'][key]))


def check(glb):
    glb=Path(glb).resolve()
    report=json.loads(glb.with_suffix('.json').read_text(encoding='utf-8'))
    ledger_path=Path(report['mouth_geometry_restoration_ledger'])
    if report['sha256']!=sha(glb) or sha(ledger_path)!=report['mouth_geometry_restoration_ledger_sha256']:
        raise ValueError('Current candidate and exact P/N restoration ledger required')
    ledger=json.loads(ledger_path.read_text(encoding='utf-8'))
    if ledger['kind']!='approved_original_connected_mouth_depression_restore' or ledger['new_vertices'] or ledger['new_triangles']:
        raise ValueError('Only original connected mouth depression restoration is allowed')
    for key in ['input_union','source_skin','prepare_report','profile']:
        if sha(ledger[key])!=ledger[key+'_sha256']:
            raise ValueError('Original baseline or reviewed profile changed: '+key)
    union=Path(ledger['input_union'])
    prep_path=Path(ledger['prepare_report'])
    baseline_check=inspect(union,prep_path)[0]
    doc,binary,_=read_glb(glb)
    original,old_binary,_=read_glb(union)
    if binary[:len(old_binary)]!=old_binary:
        raise ValueError('Original union binary prefix changed')
    if len(doc['accessors'])!=len(original['accessors'])+2 or len(doc['bufferViews'])!=len(original['bufferViews'])+2:
        raise ValueError('Exactly two new P/N arrays required')
    if doc['accessors'][:len(original['accessors'])]!=original['accessors'] or doc['bufferViews'][:len(original['bufferViews'])]!=original['bufferViews']:
        raise ValueError('Existing skin, UV or image storage changed')
    cleaned=copy.deepcopy(doc)
    cleaned['accessors']=original['accessors'];cleaned['bufferViews']=original['bufferViews'];cleaned['buffers']=original['buffers']
    for target,old_mesh in zip(cleaned['meshes'][1:],original['meshes'][1:]):
        for key in ['POSITION','NORMAL']:
            target['primitives'][0]['attributes'][key]=old_mesh['primitives'][0]['attributes'][key]
    if cleaned!=original:
        raise ValueError('Only HeadBase/Face P/N accessor references may change')
    hp,fp=[mesh['primitives'][0] for mesh in doc['meshes'][1:]]
    if any(hp['attributes'][k]!=fp['attributes'][k] for k in ['POSITION','NORMAL']):
        raise ValueError('HeadBase and Face must share the exact restored P/N arrays')
    op=original['meshes'][1]['primitives'][0]
    positions=values(original,old_binary,op,'POSITION')
    normals=values(original,old_binary,op,'NORMAL')
    new_p=values(doc,binary,hp,'POSITION');new_n=values(doc,binary,hp,'NORMAL')
    if new_p.shape!=positions.shape or new_n.shape!=normals.shape or not np.isfinite(new_p).all() or not np.isfinite(new_n).all():
        raise ValueError('Original finite vertex count required')
    changed={row['vertex']:row for row in ledger['changed_vertices']}
    if not changed or len(changed)!=len(ledger['changed_vertices']) or min(changed)<0 or max(changed)>=len(positions):
        raise ValueError('Unique, bounded original mouth vertices required')
    outside=[i for i in range(len(positions)) if i not in changed]
    if not np.array_equal(new_p[outside],positions[outside]) or not np.array_equal(new_n[outside],normals[outside]):
        raise ValueError('Non-mouth original P/N changed')
    for index,row in changed.items():
        if not np.array_equal(positions[index],row['old_position']) or not np.array_equal(normals[index],row['old_normal']):
            raise ValueError('Ledger is not the exact original vertex')
        if not np.array_equal(new_p[index],row['new_position']) or not np.array_equal(new_n[index],row['new_normal']):
            raise ValueError('Candidate P/N differ from the exact ledger')
    prep=json.loads(prep_path.read_text(encoding='utf-8'))
    profile=json.loads(Path(ledger['profile']).read_text(encoding='utf-8'))
    if not profile['reviewed'] or profile['source_sha256']!=prep['source_sha256']:
        raise ValueError('Previously approved original facial profile required')
    center=np.asarray(profile['mouth_center_screen'])
    radii=np.asarray(profile.get('mouth_flatten_radius',[48,40]))*np.asarray(profile.get('screen_scale',[1,1]))
    if not np.allclose(center,ledger['mouth_center_screen'],atol=1e-9) or not np.allclose(radii,ledger['mouth_radii_screen'],atol=1e-9):
        raise ValueError('Mouth region differs from the approved profile')
    frame=np.asarray(ledger['fixed_to_skin_affine'])
    if not np.allclose(frame,report['preserved_skin_coordinate_proof']['fixed_to_skin_affine'],atol=1e-12):
        raise ValueError('Exact original coordinate proof required')
    fixed=(np.column_stack((positions,np.ones(len(positions))))@np.linalg.inv(frame).T)[:,:3]
    restored=(np.column_stack((new_p,np.ones(len(new_p))))@np.linalg.inv(frame).T)[:,:3]
    cx,cy=prep['camera_center'];scale=prep['camera_scale']
    pixels=np.column_stack(((fixed[:,0]-cx)/scale*768+384,384-(fixed[:,1]-cy)/scale*768))
    radius=np.linalg.norm((pixels-center)/radii,axis=1)
    active=set(np.unique(np.asarray(accessor_values(original,old_binary,original['meshes'][2]['primitives'][0]['indices']))).tolist())
    key=lambda p:tuple(round(float(x),7) for x in p)
    groups={}
    for index,p in enumerate(positions):groups.setdefault(key(p),[]).append(index)
    body=original['meshes'][0]['primitives'][0]
    body_keys={key(p) for p in values(original,old_binary,body,'POSITION')}
    coefficients=np.asarray(ledger['surface_coefficients'])
    center_xy=np.asarray(ledger['surface_center_xy'])
    delta_max=0.;normal_error=0.
    for vertex,row in changed.items():
        indices=groups[key(positions[vertex])]
        if not set(indices).issubset(changed) or key(positions[vertex]) in body_keys:
            raise ValueError('Shared mouth boundary copy missing, or Body vertex selected')
        selected=[i for i in indices if i in active and radius[i]<1.12]
        if not selected:raise ValueError('Changed vertex is not an original facial-mouth surface')
        index=selected[0];r=float(radius[index])
        blend=1. if r<=.82 else 1-(3*((r-.82)/.30)**2-2*((r-.82)/.30)**3)
        x,y=fixed[index,:2]-center_xy
        z=float(coefficients@[1,x,y,x*x,x*y,y*y])
        if abs(z-fixed[index,2])>.045 or abs(row['radius']-radius[vertex])>1e-8 or abs(row['blend']-blend)>1e-10:
            raise ValueError('Mouth depth or smooth boundary exceeds the bounded restoration')
        wanted=fixed[index].copy();wanted[2]+=blend*(z-fixed[index,2])
        expected=(frame@np.append(wanted,1))[:3].astype('<f4')
        dzdx=coefficients[1]+2*coefficients[3]*x+coefficients[4]*y
        dzdy=coefficients[2]+coefficients[4]*x+2*coefficients[5]*y
        normal=np.asarray([-dzdx,-dzdy,1.]);normal/=np.linalg.norm(normal)
        normal*=profile.get('surface_normal_sign',1)
        normal=normal@np.linalg.inv(frame[:3,:3]);normal/=np.linalg.norm(normal)
        normal=(1-blend)*normals[index]+blend*normal;normal/=np.linalg.norm(normal)
        if not np.array_equal(new_p[vertex],expected) or not np.array_equal(new_n[vertex],normal.astype('<f4')):
            raise ValueError('Original mouth P/N are not the documented smooth curve')
        if not all(np.array_equal(new_p[j],new_p[index]) and np.array_equal(new_n[j],new_n[index]) for j in indices):
            raise ValueError('Coincident original HeadBase/Face vertices lost P/N continuity')
        delta_max=max(delta_max,float(np.linalg.norm(new_p[vertex]-positions[vertex])))
        normal_error=max(normal_error,abs(float(np.linalg.norm(new_n[vertex]))-1))
    if delta_max>.046*np.linalg.norm(frame[:3,:3],ord=2) or normal_error>1e-6 or np.max(np.abs(restored[list(changed),:2]-fixed[list(changed),:2]))>1e-7:
        raise ValueError('Mouth restoration moved outside depth-only bounded curve')
    if ledger['surface_fit_95percentile_error']>.004 or ledger['surface_samples']<50:
        raise ValueError('Recorded original skin fit is insufficient')
    if any(report.get(k) or ledger.get(k) for k in ['ready','runtime_validated','roblox_uploaded']):
        raise ValueError('Offline mouth candidate must remain unpromoted')
    return {'schema':1,'kind':ledger['kind'],'glb':str(glb),'sha256':sha(glb),
            'input_union_sha256':sha(union),'restoration_ledger':str(ledger_path),'restoration_ledger_sha256':sha(ledger_path),
            'changed_original_mouth_vertices':len(changed),'new_vertices':0,'new_triangles':0,
            'maximum_source_position_delta':delta_max,'maximum_normal_length_error':normal_error,
            'body_topology_uv_joints_weights_bones_images_exact':True,'non_mouth_position_normal_exact':True,
            'headbase_face_shared_position_normal_exact':True,'original_source_and_baseline_unchanged':True,
            'baseline_validation':baseline_check,'ready':False,'runtime_validated':False,
            'limitations':['P/N exception is local mouth geometry restoration, not exact original geometry.',
                           'Lit selected expressions, actual Fx and native gameplay require separate visual review.']}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('glb',type=Path)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    result=check(args.glb)
    if args.output:
        if args.output.exists():raise ValueError('Use a new validation report')
        args.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k not in ['baseline_validation','limitations']}),flush=True)


if __name__=='__main__':main()
