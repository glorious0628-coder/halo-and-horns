# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
# Still importable as a library ONLY because live tools import it (tools/monster_import_preflight.py,
# tools/test_weapon_motion.py, GLB audit tools). Never run it directly.
"""Explicit inferred elbow/wrist rebind on a reviewed, unregistered skin copy.

No generation, API, Studio, source geometry or image writes. The original byte
buffer survives as a prefix. Only two local bind translations, their inverse
binds, reviewed arm weights and matching proxy hinges may change on the copy.
This intentionally uses a new origin kind and cannot masquerade as exact bones.
"""
from __future__ import annotations
if __name__ == "__main__":
    raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse,copy,json,struct,tempfile
from pathlib import Path
import numpy as np
from constraints import RigError
from correct_skin_weights import append_array,rows,sha
from glb_io import accessor_values,image_bytes,read_glb,write_glb
from preserve_skin import ROOT,node_matrices,inverse_binds

ARM=('LeftUpperArm','LeftLowerArm','LeftHand')
IDENTITY=[1,0,0,0,1,0,0,0,1]

def load(path):return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def dump(path,value):Path(path).write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
def destination(path):
    path=Path(path).resolve()
    if path.exists() or ROOT/'build' not in path.parents:raise RigError('New build output only')
    return path

def smooth(value):
    value=float(np.clip(value,0,1));return value*value*(3-2*value)

def arm_weights(joints,weights,names,point,shoulder,elbow,wrist):
    if any(np.asarray(x).shape!=(3,) or not np.isfinite(x).all() for x in (point,shoulder,elbow,wrist)):
        raise RigError('Finite measured arm vectors required')
    if len(joints)!=4 or len(weights)!=4 or any(not np.isfinite(w) or w<0 for w in weights):
        raise RigError('Finite original four-slot weights required')
    if any(not isinstance(j,(int,np.integer)) or isinstance(j,bool) or not 0<=j<len(names) for j in joints):
        raise RigError('Invalid original joint slot')
    original={}
    for j,w in zip(joints,weights):
        if w>0:original[int(j)]=original.get(int(j),0.)+float(w)
    if abs(sum(original.values())-1)>1e-4:raise RigError('Original weights must be normalized')
    arm_indices=[names.index(n) for n in ARM]
    mass=sum(w for j,w in original.items() if j in arm_indices)
    if mass<.6:return None
    first,second=elbow-shoulder,wrist-elbow
    l1,l2=np.linalg.norm(first),np.linalg.norm(second)
    if min(l1,l2)<.02:raise RigError('Measured inferred arm segments must be nondegenerate')
    t1=float(np.clip(np.dot(point-shoulder,first)/l1**2,0,1))
    t2=float(np.clip(np.dot(point-elbow,second)/l2**2,0,2.5))
    d1=np.linalg.norm(point-(shoulder+t1*first));d2=np.linalg.norm(point-(elbow+t2*second))
    arc=t1*l1 if d1<=d2 else l1+t2*l2
    upper_lower=smooth((arc-l1+.018)/.036)
    lower_hand=smooth((arc-l1-l2+.012)/.024)
    target=[1-upper_lower,upper_lower*(1-lower_hand),upper_lower*lower_hand]
    result={j:w for j,w in original.items() if j not in arm_indices}
    for j,w in zip(arm_indices,target):
        if w>1e-8:result[j]=w*mass
    if len(result)>4:raise RigError('No unrelated influence may be discarded')
    pairs=sorted(result.items());pairs += [(0,0.)]*(4-len(pairs))
    new_joints=[j for j,w in pairs]
    new_weights=list(struct.unpack('<4f',struct.pack('<4f',*(w for j,w in pairs))))
    if abs(sum(new_weights)-sum(weights))>1e-6:raise RigError('Weight mass changed')
    if {j:w for j,w in zip(new_joints,new_weights) if w>0}==original:return None
    return {'new_joints':new_joints,'new_weights':new_weights,'arc_from_shoulder':float(arc),
            'unrelated_original_weight_preserved':True}

def proposal(manifest_path,landmarks_path):
    manifest_path,landmarks_path=Path(manifest_path).resolve(),Path(landmarks_path).resolve()
    manifest,landmarks=load(manifest_path),load(landmarks_path)
    source=Path(manifest['output']).resolve()
    if not Path(manifest['source']).name.startswith('Costume_HornsMageM_rig_'):
        raise RigError('Only the identified original HornsMageM source is supported')
    if not source.is_file() or sha(source)!=manifest['output_sha256']:raise RigError('Skin SHA changed')
    if landmarks.get('schema')!=1 or landmarks.get('name')!='Costume_HornsMageM' or landmarks.get('inferred_original_anatomy') is not True:
        raise RigError('Explicit reviewed HornsMageM inferred landmarks required')
    if landmarks['source_skin_sha256']!=sha(source):raise RigError('Landmark source changed')
    for evidence in landmarks['evidence_files']:
        if sha(evidence['path'])!=evidence['sha256']:raise RigError('Measured geometry evidence changed')
    A=np.array(manifest['source_to_game_affine']).reshape(4,4,order='F');Ai=np.linalg.inv(A)
    gltf,binary,_=read_glb(source)
    if len(gltf.get('skins',[]))!=1 or len(gltf['skins'][0]['joints'])!=23:raise RigError('Exact original 23-bone hierarchy required')
    indices=gltf['skins'][0]['joints'];names=[gltf['nodes'][i]['name'] for i in indices]
    if set(ARM)-set(names):raise RigError('Exact principal left arm absent')
    parents,local,world=node_matrices(gltf)
    shoulder=Ai@world[indices[names.index(ARM[0])]][:,3]
    elbow,wrist=(np.array(landmarks[key],float) for key in ('elbow_source','wrist_source'))
    if any(x.shape!=(3,) or not np.isfinite(x).all() for x in (elbow,wrist)) or not (.4<elbow[1]<.5 and .38<wrist[1]<.43):
        raise RigError('Finite measured sleeve/cuff centers required')
    if not elbow[1]>wrist[1] or not min(elbow[0],wrist[0])>.1:raise RigError('Measured left arm anatomical order changed')
    limits=landmarks['reviewed_source_region'];low,high=np.array(limits['min']),np.array(limits['max'])
    if low.shape!=(3,) or high.shape!=(3,) or not np.isfinite(np.r_[low,high]).all() or any(high<=low):raise RigError('Finite bounded source region required')
    changes=[];refused=[]
    for row in rows(gltf,binary):
        if row['mesh_name']!='CostumeSkinBody':continue
        points=np.c_[row['game_points'],np.ones(len(row['game_points']))]@Ai.T
        for vertex,point in enumerate(points[:,:3]):
            if any(point<low) or any(point>high):continue
            joints=list(row['values']['JOINTS_0'][vertex]);weights=list(row['values']['WEIGHTS_0'][vertex])
            try:new=arm_weights(joints,weights,names,point,shoulder[:3],elbow,wrist)
            except RigError as exc:
                if 'unrelated influence' in str(exc):refused.append(vertex);continue
                raise
            if new:
                changes.append({'mesh':row['mesh'],'primitive':row['primitive'],'mesh_name':row['mesh_name'],'vertex':vertex,
                     'source_position':point.tolist(),'game_position':row['game_points'][vertex].tolist(),
                     'uv':list(row['values']['TEXCOORD_0'][vertex]),'old_joints':joints,'old_weights':weights,**new})
    if not changes:raise RigError('No reviewed arm weights selected')
    old_binds={name:world[indices[names.index(name)]].flatten(order='F').tolist() for name in ARM}
    return {'schema':1,'name':'Costume_HornsMageM','source_manifest':str(manifest_path),'source_manifest_sha256':sha(manifest_path),
       'landmarks':str(landmarks_path),'landmarks_sha256':sha(landmarks_path),'source_skin':str(source),'source_skin_sha256':sha(source),
       'source_to_game_affine':manifest['source_to_game_affine'],'source_old_binds':old_binds,
       'shoulder_source':shoulder[:3].tolist(),'elbow_source':elbow.tolist(),'wrist_source':wrist.tolist(),
       'changes':changes,'capacity_refused_vertices':refused,'changed_skin_vertices':len(changes),
       'original_bones_claimed':False,'region_review_complete':False,'inferred_positions_not_original_bones':True,
       'ready':False,'paid_api_calls':0,'studio_calls':0}

def apply(plan_path,output,reviewed):
    plan_path=Path(plan_path).resolve();output=destination(output);document=load(plan_path)
    if not reviewed or document.get('region_review_complete') is not True or not document.get('reviewed_overlay_images'):
        raise RigError('Review the exact original region and both inferred joint markers first')
    for image in document['reviewed_overlay_images']:
        if sha(image['path'])!=image['sha256']:raise RigError('Reviewed overlay changed')
    expected=proposal(document['source_manifest'],document['landmarks'])
    for key,value in expected.items():
        if key!='region_review_complete' and document.get(key)!=json.loads(json.dumps(value)):raise RigError('Reviewed plan changed: '+key)
    source=Path(document['source_skin']);old,binary,original=read_glb(source);old_binary=binary
    gltf=copy.deepcopy(old);parents,local,world=node_matrices(old);skin=gltf['skins'][0]
    names=[gltf['nodes'][i]['name'] for i in skin['joints']]
    A=np.array(document['source_to_game_affine']).reshape(4,4,order='F');targets={}
    for name,key in [('LeftLowerArm','elbow_source'),('LeftHand','wrist_source')]:
        index=skin['joints'][names.index(name)];wanted=world[index].copy();wanted[:3,3]=(A@np.r_[document[key],1])[:3]
        parent=parents[index];parent_world=targets.get(parent,world[parent]);wanted_local=np.linalg.inv(parent_world)@wanted
        if not np.allclose(wanted_local[:3,:3],local[index][:3,:3],rtol=0,atol=1e-10):raise RigError('A bind rotation would change')
        node=gltf['nodes'][index]
        if 'matrix' in node:
            values=np.array(node['matrix']).reshape(4,4,order='F');values[:3,3]=wanted_local[:3,3];node['matrix']=values.flatten(order='F').tolist()
        else:node['translation']=wanted_local[:3,3].tolist()
        targets[index]=wanted
    _,_,new_world=node_matrices(gltf)
    binds=inverse_binds(old,old_binary,old['skins'][0]);new_binds=[]
    for index,ibm in zip(skin['joints'],binds):
        value=np.linalg.inv(new_world[index])@world[index]@ibm if index in targets else ibm
        new_binds.append(value.flatten(order='F').tolist())
    payload=b''.join(struct.pack('<16f',*v) for v in new_binds)
    binary+=b'\0'*(-len(binary)%4);view=len(gltf['bufferViews'])
    gltf['bufferViews'].append({'buffer':0,'byteOffset':len(binary),'byteLength':len(payload)});binary+=payload
    accessor=len(gltf['accessors']);gltf['accessors'].append({'bufferView':view,'componentType':5126,'count':23,'type':'MAT4'})
    skin['inverseBindMatrices']=accessor
    by_primitive={}
    for change in document['changes']:
        key=(change['mesh'],change['primitive'])
        if key not in by_primitive:
            attrs=old['meshes'][key[0]]['primitives'][key[1]]['attributes']
            by_primitive[key]={a:list(accessor_values(old,old_binary,attrs[a])) for a in ('JOINTS_0','WEIGHTS_0')}
        for attr,new in [('JOINTS_0','new_joints'),('WEIGHTS_0','new_weights')]:by_primitive[key][attr][change['vertex']]=change[new]
    for key,attrs in by_primitive.items():
        for attr,component,fmt in [('JOINTS_0',5123,'H'),('WEIGHTS_0',5126,'f')]:
            index,binary=append_array(gltf,binary,attrs[attr],fmt,component,'VEC4');gltf['meshes'][key[0]]['primitives'][key[1]]['attributes'][attr]=index
    gltf['buffers'][0]['byteLength']=len(binary)
    manifest=load(document['source_manifest']);runtime_path=Path(manifest['proxy_runtime']) if manifest.get('proxy_runtime') else Path(document['source_manifest']).parent/'proxy_runtime.json'
    runtime=load(runtime_path);parts={p['name']:p for p in runtime['parts']};centers={n:np.array(p['center']) for n,p in parts.items()};centers['HumanoidRootPart']=np.array(runtime['root']['center'])
    for b in manifest['bones']:
        index=skin['joints'][names.index(b['name'])]
        if index not in targets:continue
        b['game_bind_world']=new_world[index].flatten(order='F').tolist();b['source_bind_world']=(np.linalg.inv(A)@new_world[index]).flatten(order='F').tolist()
    proxy=load(Path(document['source_manifest']).parent/'proxy_joints.json')
    for name,part in [('LeftElbow','LeftLowerArm'),('LeftWrist','LeftHand')]:
        position=new_world[skin['joints'][names.index(part)]][:3,3]
        for collection in (runtime['joints'],proxy['joints']):
            joint=next(j for j in collection if j['name']==name)
            joint['world' if collection is runtime['joints'] else 'joint_position']=position.tolist()
            joint['C0']=(position-centers[joint['part0']]).tolist()+IDENTITY
            joint['C1']=(position-centers[joint['part1']]).tolist()+IDENTITY
    output.parent.mkdir(parents=True,exist_ok=True)
    proxy_path=output.parent/'proxy_joints.json';runtime_out=output.parent/'proxy_runtime.json'
    proxy.update(rig_origin='inferred_arm_bind_correction_candidate',original_bones_claimed=False,rig_ready_for_game=False,source_rest_positions_preserved=True)
    dump(proxy_path,proxy)
    # Schema 2 is deliberate: the separate inferred-bind proof is required;
    # the preserved-original gate cannot claim these corrected binds as exact.
    # A corrected bind needs its explicit contract before any assembly.
    benchmark=manifest.get('original_benchmark_skin',str(source))
    benchmark_sha=manifest.get('original_benchmark_skin_sha256',sha(source))
    previous_count=manifest.get('changed_skin_vertices',0)
    manifest.update(schema=2,name='Costume_HornsMageM',bind_correction_schema=1,rig_origin='corrected_preserved_bind_skin_proxy_candidate',original_bones_claimed=False,
        inferred_bind_joints=['LeftLowerArm','LeftHand'],bind_correction_plan=str(plan_path),bind_correction_plan_sha256=sha(plan_path),
        original_benchmark_skin=benchmark,original_benchmark_skin_sha256=benchmark_sha,
        bind_parent_skin=str(source),bind_parent_skin_sha256=sha(source),
        original_binary_prefix_preserved=True,original_geometry_uv_normals_material_images_preserved=True,
        original_mesh_skin_accessors_binary_images_materials_preserved=False,original_source_weights_exact=False,
        proxy_plan=str(proxy_path),proxy_plan_sha256=sha(proxy_path),proxy_runtime=str(runtime_out),
        changed_skin_vertices=previous_count+len(document['changes']),changed_arm_vertices= len(document['changes']),
        changed_skin_vertices_this_bind_stage=len(document['changes']),output=str(output),rig_ready_for_game=False,studio_motion_validated=False,
        original_rest_shape_preserved=True,requires_inferred_bind_contract_review=True,
        existing_original_skin_producer_compatible=False)
    manifest.pop('output_sha256',None)
    gltf.setdefault('extras',{})['HHC_InferredArmBindCandidate']={'plan_sha256':sha(plan_path),'ready':False,'original_bones_claimed':False}
    write_glb(output,gltf,binary)
    manifest['output_sha256']=sha(output);runtime.update(source_skin_sha256=sha(output),proxy_plan_sha256=sha(proxy_path),
        inferred_bind_joints=manifest['inferred_bind_joints'],original_bones_claimed=False,rig_ready_for_game=False)
    dump(runtime_out,runtime);dump(output.with_suffix('.skin.json'),manifest)
    proof=verify(source,output,document);dump(output.parent/'preservation_proof.json',proof)
    return {'output':str(output),'changed_skin_vertices':len(document['changes']),'changed_bind_joints':2,'proof':proof,'ready':False}

def verify(source,output,document):
    old,binary,_=read_glb(source);new,actual,_=read_glb(output)
    if actual[:len(binary)]!=binary or sha(source)!=document['source_skin_sha256']:raise RigError('Original binary or source changed')
    selected={(c['mesh'],c['primitive'],c['vertex']):c for c in document['changes']}
    for key in ('materials','textures','images','animations'):
        if old.get(key)!=new.get(key):raise RigError('Original appearance metadata changed')
    for oi,ni in zip(old['images'],new['images']):
        if image_bytes(old,binary,oi)!=image_bytes(new,actual,ni):raise RigError('Original PNG changed')
    for mi,mesh in enumerate(old['meshes']):
        for pi,p in enumerate(mesh['primitives']):
            q=new['meshes'][mi]['primitives'][pi]
            if p['indices']!=q['indices'] or p['material']!=q['material']:raise RigError('Original topology or material changed')
            for a,i in p['attributes'].items():
                if a not in ('JOINTS_0','WEIGHTS_0') and q['attributes'][a]!=i:raise RigError('Original static accessor changed')
            for a,field in [('JOINTS_0','new_joints'),('WEIGHTS_0','new_weights')]:
                before=accessor_values(old,binary,p['attributes'][a]);after=accessor_values(new,actual,q['attributes'][a])
                for vi,(v,w) in enumerate(zip(before,after)):
                    expected=selected.get((mi,pi,vi),{}).get(field,list(v))
                    if list(w)!=expected:raise RigError('Unreviewed active skin value changed')
    old_parents,_,wo=node_matrices(old);new_parents,_,wn=node_matrices(new)
    if old_parents!=new_parents:raise RigError('Original bone hierarchy changed')
    indices=old['skins'][0]['joints'];names=[old['nodes'][i]['name'] for i in indices]
    altered={indices[names.index(n)] for n in ('LeftLowerArm','LeftHand')}
    for i,(a,b) in enumerate(zip(old['nodes'],new['nodes'])):
        aa,bb=copy.deepcopy(a),copy.deepcopy(b)
        if i in altered:
            aa.pop('translation',None);bb.pop('translation',None)
            if 'matrix' in aa:
                aa['matrix'][12:15]=[0,0,0];bb['matrix'][12:15]=[0,0,0]
        if aa!=bb:raise RigError('Unreviewed node/bind/rotation changed')
    ibo=inverse_binds(old,binary,old['skins'][0]);ibn=inverse_binds(new,actual,new['skins'][0])
    rest=max(float(np.max(np.abs(wo[i]@a-wn[i]@b))) for i,a,b in zip(indices,ibo,ibn))
    if rest>2e-6:raise RigError('Original static bind-deformed shape changed')
    if any(not np.array_equal(a,b) for i,a,b in zip(indices,ibo,ibn) if i not in altered):raise RigError('Unrelated inverse bind changed')
    return {'original_source_unchanged':True,'original_binary_prefix_unchanged':True,
       'position_normal_uv_indices_material_png_exact':True,'unselected_active_weights_exact':True,
       'only_two_bind_translations_changed':True,'unrelated_inverse_binds_exact':True,
       'original_rest_bind_product_maximum_error':rest,'ready':False,'actual_studio_validation':False}

def self_test(plan_path,candidate):
    document=load(plan_path);source=Path(document['source_skin']);candidate=Path(candidate)
    verify(source,candidate,document);checks=1
    names=['LeftUpperArm','LeftLowerArm','LeftHand','Aux_leftshoulder','UpperTorso']
    s=np.array([0.,1.,0.]);e=np.array([0.,.6,0.]);w=np.array([0.,.2,0.])
    for point in (s,e,w,np.array([0.,0.,0.])):
        result=arm_weights([0,3,0,0],[.9,.1,0,0],names,point,s,e,w)
        if result:
            weights={j:q for j,q in zip(result['new_joints'],result['new_weights']) if q>0}
            assert abs(weights[3]-.1)<1e-6 and abs(sum(weights.values())-1)<1e-6;checks+=2
            if point is s:assert weights[0]>.89
            elif point is e:assert weights[0]>.44 and weights[1]>.44
            elif point is w:assert weights[1]>.44 and weights[2]>.44
            else:assert weights[2]>.89
            checks+=1
    assert arm_weights([4,0,0,0],[1.,0,0,0],names,e,s,e,w) is None;checks+=1
    invalid=[([0,3,0,0],[float('nan'),.1,0,0]),([0,3,0,0],[-.1,1.1,0,0]),
             ([False,3,0,0],[.9,.1,0,0]),([7,3,0,0],[.9,.1,0,0]),
             ([0,3,0,0],[.8,.1,0,0]),([0,3,0],[.9,.1,0])]
    for joints,weights in invalid:
        try:arm_weights(joints,weights,names,e,s,e,w)
        except RigError:checks+=1
        else:raise AssertionError('Invalid weights accepted')
    for point in (np.array([float('nan'),0,0]),np.array([0,0])):
        try:arm_weights([0,3,0,0],[.9,.1,0,0],names,point,s,e,w)
        except RigError:checks+=1
        else:raise AssertionError('Invalid measured point accepted')
    from skin_schema import load as production_load
    admitted=production_load(candidate.with_suffix('.skin.json'))
    assert admitted['rig_origin']=='corrected_preserved_bind_skin_proxy_candidate'
    assert admitted['original_bones_claimed'] is False
    assert admitted['inferred_bind_proof']['changed_bind_joints']==['LeftLowerArm','LeftHand']
    assert admitted['inferred_bind_proof']['changed_arm_vertices']==843
    checks+=4
    with tempfile.TemporaryDirectory(prefix='arm_bind_guards_',dir=ROOT/'build') as temp:
        temp=Path(temp);gltf,binary,_=read_glb(candidate)
        def static_attribute(g):g['meshes'][0]['primitives'][0]['attributes']['POSITION']=g['meshes'][0]['primitives'][0]['attributes']['NORMAL']
        def foreign_translation(g):g['nodes'][g['skins'][0]['joints'][0]]['translation']=[.001,0,0]
        def hierarchy(g):g['nodes'][g['skins'][0]['joints'][0]].pop('children',None)
        def material(g):g['materials'][0]['name']='unreviewed'
        def topology(g):g['meshes'][0]['primitives'][0]['indices']=g['meshes'][1]['primitives'][0]['indices']
        for mutate in (static_attribute,foreign_translation,hierarchy,material,topology):
            changed=copy.deepcopy(gltf);mutate(changed);bad=temp/'bad.glb';write_glb(bad,changed,binary)
            try:verify(source,bad,document)
            except RigError:checks+=1
            else:raise AssertionError('Unreviewed source metadata mutation accepted')
        bad_document=copy.deepcopy(document);bad_document['source_skin_sha256']='0'*64
        try:verify(source,candidate,bad_document)
        except RigError:checks+=1
        else:raise AssertionError('False benchmark SHA accepted')
        for mutate in (lambda p:p.update(region_review_complete=False),
                       lambda p:p['changes'][0]['new_weights'].__setitem__(0,.12345),
                       lambda p:p['reviewed_overlay_images'][0].update(sha256='0'*64)):
            changed=copy.deepcopy(document);mutate(changed);bad=temp/'bad_plan.json';dump(bad,changed)
            try:apply(bad,temp/'must_not_write.glb',True)
            except RigError:checks+=1
            else:raise AssertionError('Unreviewed/tampered application accepted')
    assert sha(source)==document['source_skin_sha256'];checks+=1
    return {'meaningful_guard_checks':checks,'original_unchanged':True,'ready':False,
            'separate_inferred_contract_compatible':True,'actual_studio_validated':False}

def main():
    parser=argparse.ArgumentParser(description=__doc__);sub=parser.add_subparsers(dest='command',required=True)
    p=sub.add_parser('plan');p.add_argument('manifest',type=Path);p.add_argument('landmarks',type=Path);p.add_argument('output',type=Path)
    p=sub.add_parser('apply');p.add_argument('plan',type=Path);p.add_argument('output',type=Path);p.add_argument('--reviewed',action='store_true')
    p=sub.add_parser('self-test');p.add_argument('plan',type=Path);p.add_argument('candidate',type=Path)
    args=parser.parse_args()
    if args.command=='plan':
        output=destination(args.output);output.parent.mkdir(parents=True,exist_ok=True);result=proposal(args.manifest,args.landmarks);dump(output,result)
        print(json.dumps({'plan':str(output),'changed_skin_vertices':result['changed_skin_vertices'],'ready':False}))
    elif args.command=='apply':print(json.dumps(apply(args.plan,args.output,args.reviewed)))
    else:print(json.dumps(self_test(args.plan,args.candidate)))

if __name__=='__main__':main()
