"""Restore the original connected mouth depression in a new union copy.

Run with Blender --background --python this_file -- union.glb prepare.json
profile.json new.glb. No new cap, triangles, UV, skin weights or image changes.
Only the approved mouth ellipse's original connected positions/normals change.
"""
import copy
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools/costume_r15'))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from glb_io import read_glb, write_glb, accessor_values
from skin_frames import resolve


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    args = sys.argv[sys.argv.index('--')+1:]
    union, prepared, profile_path, output = [Path(p).resolve() for p in args]
    if output.exists() or output.with_suffix('.json').exists():
        raise ValueError('Use a new mouth-restoration copy')
    report = json.loads(union.with_suffix('.json').read_text(encoding='utf-8'))
    if not report['original_triangles_only'] or report['sha256'] != sha(union):
        raise ValueError('Verified original-triangle union required')
    source = Path(report['source_skin'])
    if sha(source) != report['source_skin_sha256']:
        raise ValueError('Original skin changed')
    prep = json.loads(prepared.read_text(encoding='utf-8'))
    profile = json.loads(profile_path.read_text(encoding='utf-8'))
    if not profile['reviewed'] or profile['source_sha256'] != prep['source_sha256']:
        raise ValueError('Exact previously reviewed original mouth profile required')
    sidecar = json.loads(source.with_suffix('.skin.json').read_text(encoding='utf-8'))
    frame, _, _ = resolve(prep, source, sidecar)
    document, old_binary, _ = read_glb(union)
    source_doc, source_binary, _ = read_glb(source)
    head = source_doc['meshes'][1]['primitives'][0]
    positions = np.asarray(accessor_values(source_doc, source_binary, head['attributes']['POSITION']), dtype=float)
    normals = np.asarray(accessor_values(source_doc, source_binary, head['attributes']['NORMAL']), dtype=float)
    triangles = np.asarray(accessor_values(source_doc, source_binary, head['indices']), int).reshape(-1,3)
    face = document['meshes'][2]['primitives'][0]
    face_indices = np.asarray(accessor_values(document, old_binary, face['indices']), int).reshape(-1,3)
    if np.max(face_indices) >= len(positions):
        raise ValueError('No new mouth cap vertices are permitted')
    fixed = (np.column_stack((positions, np.ones(len(positions)))) @ np.linalg.inv(frame).T)[:,:3]
    cx,cy = prep['camera_center']; scale = prep['camera_scale']
    center = np.asarray(profile['mouth_center_screen'], float)
    radii = np.asarray(profile.get('mouth_flatten_radius',[48,40]), float)*np.asarray(profile.get('screen_scale',[1,1]), float)
    pixels = np.column_stack(((fixed[:,0]-cx)/scale*768+384, 384-(fixed[:,1]-cy)/scale*768))
    radius = np.linalg.norm((pixels-center)/radii, axis=1)
    bvh = BVHTree.FromPolygons([Vector(p) for p in fixed], triangles.tolist(), all_triangles=True)
    selected_original_triangles={tuple(t) for t in face_indices}
    samples=[]
    z_start=float(fixed[:,2].max()+1)
    for sy in range(int(center[1]-1.7*radii[1]),int(center[1]+1.7*radii[1])+1,3):
        for sx in range(int(center[0]-1.7*radii[0]),int(center[0]+1.7*radii[0])+1,3):
            r=float(np.linalg.norm((np.asarray([sx,sy])-center)/radii))
            if not 1.12 <= r <= 1.7:
                continue
            x=cx+(sx-384)/768*scale; y=cy+(384-sy)/768*scale
            hit,n,triangle_index,_=bvh.ray_cast(Vector((x,y,z_start)),Vector((0,0,-1)))
            if hit is not None and n.z*profile.get('surface_normal_sign',1) > .35 and tuple(triangles[triangle_index]) in selected_original_triangles:
                samples.append(list(hit))
    if len(samples)<50:
        raise ValueError('Insufficient original front skin surrounding the mouth')
    samples=np.asarray(samples)
    center_xy=np.asarray([cx+(center[0]-384)/768*scale,cy+(384-center[1])/768*scale])
    local=samples[:,:2]-center_xy
    design=np.column_stack((np.ones(len(local)),local[:,0],local[:,1],local[:,0]**2,local[:,0]*local[:,1],local[:,1]**2))
    retained=np.ones(len(samples),dtype=bool)
    for _ in range(3):
        coefficients=np.linalg.lstsq(design[retained],samples[retained,2],rcond=None)[0]
        residual=np.abs(design@coefficients-samples[:,2])
        retained=residual<=float(np.quantile(residual,.85))
    coefficients=np.linalg.lstsq(design[retained],samples[retained,2],rcond=None)[0]
    residual=np.abs(design[retained]@coefficients-samples[retained,2])
    if float(np.quantile(residual,.95)) > .004:
        raise ValueError('Surrounding original skin is not a stable narrow-mouth curve')
    active=set(np.unique(face_indices).tolist())
    keys=lambda values: [tuple(round(float(x),7) for x in p) for p in values]
    groups={}
    for i,key in enumerate(keys(positions)):
        groups.setdefault(key,[]).append(i)
    body=source_doc['meshes'][0]['primitives'][0]
    body_positions=np.asarray(accessor_values(source_doc,source_binary,body['attributes']['POSITION']))
    body_keys=set(keys(body_positions))
    new_fixed=fixed.copy();new_normals=normals.copy(); changes=[]
    for key,indices in groups.items():
        selected=[i for i in indices if i in active and radius[i] < 1.12]
        if not selected:
            continue
        i=selected[0];x,y=fixed[i,:2]-center_xy
        z=float(coefficients@[1,x,y,x*x,x*y,y*y])
        delta=z-fixed[i,2]
        if abs(delta) > .045:
            continue # Back-of-head and unrelated hidden surfaces are excluded.
        r=float(radius[i])
        blend=1. if r<=.82 else 1-(3*((r-.82)/.30)**2-2*((r-.82)/.30)**3)
        dzdx=coefficients[1]+2*coefficients[3]*x+coefficients[4]*y
        dzdy=coefficients[2]+coefficients[4]*x+2*coefficients[5]*y
        fitted_normal=np.asarray([-dzdx,-dzdy,1.])
        fitted_normal/=np.linalg.norm(fitted_normal)
        fitted_normal*=profile.get('surface_normal_sign',1)
        fitted_skin_normal=fitted_normal@np.linalg.inv(frame[:3,:3])
        fitted_skin_normal/=np.linalg.norm(fitted_skin_normal)
        restored=fixed[i].copy();restored[2]+=blend*delta
        if np.linalg.norm(restored-fixed[i])<1e-7 and blend<.99:
            continue
        if key in body_keys:
            raise ValueError('Mouth restoration would alter an original Body boundary')
        # All coincident original Head copies get one position and normal;
        # actual original JOINTS/WEIGHTS are left completely unchanged.
        reference_normal=normals[i]
        normal=(1-blend)*reference_normal+blend*fitted_skin_normal
        if np.linalg.norm(normal)<1e-8:
            raise ValueError('Degenerate restored mouth normal')
        normal/=np.linalg.norm(normal)
        for index in indices:
            new_fixed[index]=restored;new_normals[index]=normal
            changes.append({'vertex':index,'old_position':positions[index].tolist(),
                            'old_normal':normals[index].tolist(),'radius':float(radius[index]),'blend':blend})
    if not changes:
        raise ValueError('No original mouth depression was selected')
    new_positions=(np.column_stack((new_fixed,np.ones(len(new_fixed))))@frame.T)[:,:3].astype('<f4')
    new_normals=new_normals.astype('<f4')
    # Preserve every unchanged source position/normal byte, including rounding.
    changed_set={row['vertex'] for row in changes}
    for index in range(len(positions)):
        if index not in changed_set:
            new_positions[index]=positions[index];new_normals[index]=normals[index]
    binary=bytearray(old_binary)
    def append_accessor(values):
        binary.extend(b'\0'*(-len(binary)%4));offset=len(binary);content=values.tobytes();binary.extend(content)
        document['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(content),'target':34962})
        document['accessors'].append({'bufferView':len(document['bufferViews'])-1,'componentType':5126,
                                      'count':len(values),'type':'VEC3','min':values.min(axis=0).tolist(),'max':values.max(axis=0).tolist()})
        return len(document['accessors'])-1
    p_accessor,n_accessor=append_accessor(new_positions),append_accessor(new_normals)
    for mesh in document['meshes'][1:]:
        mesh['primitives'][0]['attributes'].update(POSITION=p_accessor,NORMAL=n_accessor)
    document['buffers'][0]['byteLength']=len(binary)
    output.parent.mkdir(parents=True,exist_ok=True)
    write_glb(output,document,bytes(binary))
    for row in changes:
        i=row['vertex'];row.update(new_position=new_positions[i].tolist(),new_normal=new_normals[i].tolist())
    ledger={'schema':1,'kind':'approved_original_connected_mouth_depression_restore',
            'input_union':str(union),'input_union_sha256':sha(union),
            'source_skin':str(source),'source_skin_sha256':sha(source),
            'prepare_report':str(prepared),'prepare_report_sha256':sha(prepared),
            'profile':str(profile_path),'profile_sha256':sha(profile_path),
            'mouth_center_screen':center.tolist(),'mouth_radii_screen':radii.tolist(),
            'normal_orientation_sign':profile.get('surface_normal_sign',1),
            'fixed_to_skin_affine':frame.tolist(),'surface_center_xy':center_xy.tolist(),
            'surface_coefficients':coefficients.tolist(),'surface_samples':len(samples),
            'surface_fit_retained_samples':int(retained.sum()),
            'surface_fit_95percentile_error':float(np.quantile(residual,.95)),
            'changed_vertices':changes,'new_vertices':0,'new_triangles':0,
            'original_weights_uv_png_bones_unchanged':True,'body_unchanged':True,
            'maximum_source_position_delta':float(np.max(np.linalg.norm(new_positions-positions,axis=1))),
            'headbase_face_share_exact_position_normal_accessors':True,
            'ready':False,'runtime_validated':False}
    ledger_path=output.with_suffix('.mouth.json')
    ledger_path.write_text(json.dumps(ledger,indent=2)+'\n',encoding='utf-8')
    report.update(glb=str(output),sha256=sha(output),
                  original_position_normal_joint_weight_values_preserved=False,
                  original_joint_weight_values_preserved=True,
                  mouth_geometry_restoration_ledger=str(ledger_path),
                  mouth_geometry_restoration_ledger_sha256=sha(ledger_path),
                  source_models_unchanged=True,ready=False,runtime_validated=False,roblox_uploaded=False,
                  limitations=['Only original connected mouth P/N restored in a new copy; exact original UV/JW/source bones/images remain.',
                               'Lit three-state and exact-Fx plus native game QA still required.'])
    output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    if sha(union)!=ledger['input_union_sha256'] or sha(source)!=ledger['source_skin_sha256']:
        raise ValueError('Original source changed')
    print(json.dumps({'output':str(output),'sha256':sha(output),'changed_mouth_vertices':len(changes),
                      'new_vertices':0,'position_delta_max':ledger['maximum_source_position_delta'],'ready':False}),flush=True)


if __name__=='__main__':main()
