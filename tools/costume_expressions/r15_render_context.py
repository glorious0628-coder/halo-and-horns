# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Read-only reconstruction of original non-replaced R15 regions for CG QA."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import hashlib
import json
import sys
from pathlib import Path

import bpy


def analyze_verified_partition(joints, source):
    """Reproduce the saved original-face ownership policy before CG/export."""
    root=Path(__file__).resolve().parents[2]
    sys.path.insert(0,str(root/'tools/costume_r15'))
    import convert
    frame=joints.get('source_frame_policy','bones')
    if frame=='gltf-positive-z':
        proof=json.loads(Path(source).with_suffix('.recovery.json').read_text(encoding='utf-8'))
        if proof.get('output_sha256')!=hashlib.sha256(Path(source).read_bytes()).hexdigest() or not proof.get('oriented_original_triangles_matched_exactly_once') or not proof.get('exact_rig_geometry_skin_corner_attributes_verified'):
            raise RuntimeError('Original front frame recovery proof differs from actual source')
    partition=joints.get('mechanical_surface_partition') or {}
    overrides=None
    if partition.get('enabled'):
        import surface_partition
        signature_file=partition.get('projected_head_face_signature_file')
        if signature_file and hashlib.sha256(Path(signature_file).read_bytes()).hexdigest()!=partition['projected_head_face_signature_sha256']:
            raise RuntimeError('Reviewed projected face signature file changed')
        overrides,actual=surface_partition.prepare(
            split_ties=partition.get('split_weight_ties',False),
            recover_left_forearm=partition.get('recover_empty_left_forearm',False),
            recover_left_foot=partition.get('recover_empty_left_foot',False),
            head_faces=signature_file,source=source)
        for key in ['output_triangles','reassigned_original_faces','projected_head_faces_restored']:
            if actual.get(key,0)!=partition.get(key,0):
                raise RuntimeError('Saved mechanical partition count differs: '+key)
    return convert.analyze_scene(joints['target_height_studs'],joints.get('nonadjacent_ties','refuse'),surface_overrides=overrides,source_frame=frame)


def load_context(joints_path):
    root=Path(__file__).resolve().parents[2]
    sys.path.insert(0,str(root/'tools/costume_r15'))
    import convert
    joints=json.loads(Path(joints_path).read_text(encoding='utf-8'))
    source=Path(joints['source'])
    if hashlib.sha256(source.read_bytes()).hexdigest()!=joints['source_sha256']:
        raise RuntimeError('Original rig differs from existing R15 joints')
    bpy.ops.import_scene.gltf(filepath=str(source))
    analysis=analyze_verified_partition(joints,source)
    originals=list({obj for refs in analysis['faces'].values() for obj,_ in refs})
    regions={}
    for part,refs in analysis['faces'].items():
        for obj,index in refs:regions[(obj.name,index)]=part
    context=[]
    for original in originals:
        mesh=original.data
        kept=[face.index for face in mesh.polygons if not (regions[(original.name,face.index)]=='Head' and mesh.materials[face.material_index].name.startswith('HeadMat'))]
        if not kept:continue
        matrix=analysis['to_blender']@analysis['coordinate']@original.matrix_world
        normal_matrix=matrix.to_3x3().inverted().transposed()
        replacement=bpy.data.meshes.new('Original_R15_Context')
        replacement.from_pydata([matrix@vertex.co for vertex in mesh.vertices],[],[list(mesh.polygons[i].vertices) for i in kept]);replacement.update()
        for material in mesh.materials:replacement.materials.append(material)
        for layer in mesh.uv_layers:replacement.uv_layers.new(name=layer.name)
        cursor=0;normals=[]
        for new_face,old_index in zip(replacement.polygons,kept):
            old_face=mesh.polygons[old_index];new_face.material_index=old_face.material_index
            for loop_index in old_face.loop_indices:
                for old_layer in mesh.uv_layers:
                    replacement.uv_layers[old_layer.name].data[cursor].uv=old_layer.data[loop_index].uv
                normals.append((normal_matrix@mesh.corner_normals[loop_index].vector).normalized());cursor+=1
        replacement.normals_split_custom_set(normals)
        obj=bpy.data.objects.new('OriginalContext_'+original.name,replacement)
        bpy.context.scene.collection.objects.link(obj);context.append(obj)
    for original in list(bpy.context.scene.objects):
        if original not in context:bpy.data.objects.remove(original,do_unlink=True)
    return {'original_rig':str(source),'original_rig_sha256':joints['source_sha256'],'whole_avatar_original_nonhead_uv_preserved':True,'original_context_triangles':sum(len(obj.data.polygons) for obj in context),'context_exported':False}
