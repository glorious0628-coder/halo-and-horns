"""Read-only checks of expression GLB, embedded textures and offline previews."""
import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_glb(path):
    data=path.read_bytes()
    magic,version,total=struct.unpack_from('<4sII',data)
    if magic!=b'glTF' or version!=2 or total!=len(data):
        raise ValueError('Invalid GLB header')
    offset=12;document=None;binary=None
    while offset<len(data):
        size,kind=struct.unpack_from('<I4s',data,offset);offset+=8
        payload=data[offset:offset+size];offset+=size
        if kind==b'JSON':document=json.loads(payload)
        elif kind==b'BIN\x00':binary=payload
    if document is None or binary is None or offset!=len(data):
        raise ValueError('Missing or invalid GLB chunks')
    return document,binary


def png_size(path):
    data=path.read_bytes()
    if data[:8]!=b'\x89PNG\r\n\x1a\n':raise ValueError('PNG required: '+str(path))
    return list(struct.unpack_from('>II',data,16))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest',type=Path)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    manifest=json.loads(args.manifest.read_text(encoding='utf-8'))
    head=ROOT/manifest['head_asset']
    if sha(head)!=manifest['head_sha256']:raise ValueError('Head checksum differs')
    doc,binary=read_glb(head)
    mesh_nodes={n['name']:n['mesh'] for n in doc['nodes'] if 'mesh' in n}
    if set(mesh_nodes)!={'HeadBase','FaceExpression'}:raise ValueError('Expected two head pieces')
    if len(doc['meshes'])!=2 or len(doc['materials'])!=2 or len(doc['images'])!=2:
        raise ValueError('Expected two meshes, two materials and two images')
    if doc.get('skins'):raise ValueError('Head pieces must use existing R15 Head weld/motor')
    triangles={}
    for name,index in mesh_nodes.items():
        primitives=doc['meshes'][index]['primitives']
        if len(primitives)!=1:raise ValueError('One material per Roblox mesh required')
        primitive=primitives[0]
        uv=[key for key in primitive['attributes'] if key.startswith('TEXCOORD')]
        if uv!=['TEXCOORD_0']:raise ValueError('Only primary UV allowed')
        triangles[name]=doc['accessors'][primitive['indices']]['count']//3
    report=json.loads(head.with_suffix('.json').read_text(encoding='utf-8'))
    if report.get('coordinate_mapping_residual_max',1)>1e-5:
        raise ValueError('Exact fixed-to-rig coordinate mapping not verified')
    excluded=report.get('excluded_expression_faces',[])
    if excluded:
        partition_review=json.loads(head.with_name('excluded_face_partition_review.json').read_text(encoding='utf-8'))
        if not partition_review.get('reviewed') or partition_review['head_sha256']!=manifest['head_sha256'] or partition_review['source_rig_sha256']!=report['source_rig_sha256'] or partition_review['excluded_original_skin_triangles']!=len(excluded):
            raise ValueError('Excluded projected facial triangles need exact original neck-ownership review')
    if manifest['body_reimport_required']!=report.get('body_reimport_required',False) or manifest.get('body_parts_reimport_required',[])!=report.get('body_parts_reimport_required',[]):
        raise ValueError('Corrected body partition import requirement differs')
    if sum(triangles.values())!=report['triangles']:raise ValueError('Triangle count differs')
    if sha(Path(report['source_rig']))!=report['source_rig_sha256']:raise ValueError('Original rig changed')
    prepared=json.loads(head.with_name('prepare_report.json').read_text(encoding='utf-8'))
    if sha(Path(prepared['source']))!=prepared['source_sha256']:raise ValueError('Original model changed')
    if not (prepared['body_unchanged'] and prepared['hair_rear_ear_original_uv_preserved']):
        raise ValueError('Original body/hair UV preservation missing')
    for image in doc['images']:
        view=doc['bufferViews'][image['bufferView']]
        offset=view.get('byteOffset',0)
        image_sha=hashlib.sha256(binary[offset:offset+view['byteLength']]).hexdigest()
        if image_sha!=report['embedded_texture_sha256'][image['name']]:
            raise ValueError('Embedded source texture bytes changed')
    expected_states={'Neutral','SoftSmile','Serious'}
    if {r['state'] for r in manifest['records']}!=expected_states:raise ValueError('Three expressions required')
    previews=[]
    for record in manifest['records']:
        png=ROOT/record['png']
        if sha(png)!=record['sha256'] or png_size(png)!=record['size']:
            raise ValueError('Expression PNG metadata differs: '+record['state'])
        if not record['builtin_gpt_generated']:raise ValueError('GPT source required')
        for preview in record.get('offline_previews',[]):
            preview_path=ROOT/preview
            if png_size(preview_path)!=[768,768]:raise ValueError('Expected 768 square CG preview')
            preview_report=json.loads(preview_path.with_suffix('.json').read_text(encoding='utf-8'))
            if preview_report['source_sha256']!=manifest['head_sha256']:
                raise ValueError('Preview belongs to an older head')
            if Path(preview_report['expression']).resolve()!=png.resolve():
                raise ValueError('Preview expression PNG differs')
            if not preview_report.get('whole_avatar_original_nonhead_uv_preserved'):
                raise ValueError('Original full-avatar context not checked')
            previews.append(preview)
    import_assets=len(doc['meshes'])+len(doc['images'])+1
    if import_assets!=manifest['import_asset_budget'] or import_assets>10:
        raise ValueError('Import asset budget differs or exceeds ten')
    result={'validated':True,'avatar':manifest['avatar'],'head_sha256':sha(head),'triangles':triangles,
        'primary_uv_only':True,'embedded_original_png_bytes_preserved':True,'source_models_unchanged':True,
        'expression_pngs':3,'offline_previews_checked':len(previews),'expected_import_assets':import_assets,
        'runtime_validated':False,'uploads_performed_by_validator':0}
    if args.output:args.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False))


if __name__=='__main__':main()
