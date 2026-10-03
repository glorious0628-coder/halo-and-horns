"""Audit approved original monster GLBs and prepare an offline import ledger.

Original GLB bytes and embedded image bytes are copied unchanged. PNGs are local
review exports with decoded pixels preserved; packed rough/metal maps use their
declared glTF G/B channels. No Studio, API, upload, asset ID allocation or source
model changes. BigSlime remains held when its approved GLB cannot be found.
"""
from __future__ import annotations

import argparse
import hashlib
from io import BytesIO
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools/costume_r15"))
from constraints import RigError
from glb_io import accessor_values as accessor, read_glb
from preserve_skin import node_matrices

SOURCES={
    "Slime":"art/models/Slime.glb",
    "BigSlime":None,
    "Goblin":"art/models/Goblin.glb",
    "GoblinBrute":"art/models/GoblinBrute.glb",
    "Skeleton":"art/models/tripo/SkeletonClothed_raw.glb",
    "SkeletonKing":"art/models/tripo/SkeletonKingClothed_raw.glb",
    "GoldenGoose":"art/models/GoldenGoose.glb",
}
ROLE_PROPERTIES={"MeshId","TextureID","TextureId","ColorMap","NormalMap","MetalnessMap","RoughnessMap","Transparency","Material","MaterialVariant","AlphaMode","Color","Color3uint8","Reflectance","TexturePack"}


def sha(value): return hashlib.sha256(value if isinstance(value,bytes) else Path(value).read_bytes()).hexdigest()


def approved_path(value):
    path=(ROOT/Path(value)).resolve();path.relative_to(ROOT)
    if path.is_relative_to(ROOT/"art/out/v1"): raise RigError("art/out/v1 is never an import/review input")
    if not path.is_file(): raise RigError("The exact local input is missing: "+str(path))
    return path


def item_name(item):
    properties=item.find("Properties")
    if properties is None: return ""
    value=next((p for p in properties if p.get("name")=="Name"),None)
    return value.text or "" if value is not None else ""


def property_value(prop):
    if prop.get("name")=="TexturePack": return {"nonempty":bool(prop.text),"serialized_characters":len(prop.text or "")}
    if list(prop): return {p.tag:p.text for p in prop}
    return prop.text


def saved_models(place):
    tree=ET.parse(place).getroot()
    servers=[i for i in tree.findall("Item") if i.get("class")=="ServerStorage"]
    if len(servers)!=1: raise RigError("One saved ServerStorage is required")
    folders=[i for i in servers[0].findall("Item") if item_name(i)=="CustomModels"]
    if len(folders)!=1: raise RigError("One saved CustomModels folder is required")
    models={}
    for model in folders[0].findall("Item"):
        name=item_name(model)
        if name in models: raise RigError("Duplicate saved CustomModels name")
        entries=[]
        for item in model.iter("Item"):
            if item.get("class") not in ("MeshPart","Part","SurfaceAppearance","SpecialMesh"): continue
            properties=item.find("Properties")
            values={p.get("name"):property_value(p) for p in properties if p.get("name") in ROLE_PROPERTIES}
            entries.append({"name":item_name(item),"class":item.get("class"),"properties":values})
        models[name]={"name":name,"class":model.get("class"),"parts":entries}
    return models


def source_images(doc,binary):
    result=[]
    for index,image in enumerate(doc.get("images",[])):
        if "uri" in image or image.get("mimeType") not in ("image/png","image/jpeg") or "bufferView" not in image:
            raise RigError("Only exact embedded PNG/JPEG images are supported")
        view=doc["bufferViews"][image["bufferView"]]
        start=view.get("byteOffset",0);length=view["byteLength"]
        if view.get("buffer",0)!=0 or start<0 or length<=0 or start+length>len(binary): raise RigError("Invalid embedded image byte range")
        raw=binary[start:start+length]
        decoded=Image.open(BytesIO(raw));decoded.load()
        rgba=decoded.convert("RGBA")
        result.append({"index":index,"name":image.get("name",str(index)),"mime":image["mimeType"],"raw":raw,"image":decoded,
                       "size":list(decoded.size),"alpha_range":list(rgba.getextrema()[3]),"sha256":sha(raw)})
    return result


def texture_image(doc,entry):
    texture=doc["textures"][entry["index"]]
    if "source" not in texture or texture.get("extensions"): raise RigError("An ordinary embedded texture source is required")
    if entry.get("texCoord",0)!=0 or entry.get("extensions"): raise RigError("Texture UV transform needs separate inspection")
    return texture["source"]


def material_roles(doc):
    rows=[];native=set()
    for index,material in enumerate(doc.get("materials",[])):
        if material.get("extensions"): raise RigError("Material extensions need a separate exact native import review")
        pbr=material.get("pbrMetallicRoughness",{});roles={}
        for key,entry in (("basecolor",pbr.get("baseColorTexture")),("normal",material.get("normalTexture")),
                          ("packed_metallic_roughness",pbr.get("metallicRoughnessTexture")),("emissive",material.get("emissiveTexture")),("occlusion",material.get("occlusionTexture"))):
            if entry is not None:
                image=texture_image(doc,entry);roles[key]=image
                if key=="packed_metallic_roughness": native.update((("roughness",image),("metalness",image)))
                else: native.add((key,image))
        factor=pbr.get("baseColorFactor",[1,1,1,1])
        if len(factor)!=4 or not np.isfinite(factor).all(): raise RigError("Finite RGBA base-color factor is required")
        rows.append({"index":index,"name":material.get("name",str(index)),"roles":roles,"basecolor_factor":factor,
                     "metallic_factor":pbr.get("metallicFactor",1),"roughness_factor":pbr.get("roughnessFactor",1),
                     "alpha_mode":material.get("alphaMode","OPAQUE"),"alpha_cutoff":material.get("alphaCutoff",.5),"double_sided":material.get("doubleSided",False)})
    return rows,native


def mesh_inventory(doc,binary):
    if doc.get("skins") or doc.get("animations"): raise RigError("Static monster inputs must not silently discard a rig/animation")
    _,_,world=node_matrices(doc);parts=[]
    for node_index,node in enumerate(doc.get("nodes",[])):
        if "mesh" not in node: continue
        mesh=doc["meshes"][node["mesh"]]
        for primitive_index,primitive in enumerate(mesh["primitives"]):
            if primitive.get("mode",4)!=4 or primitive.get("extensions"): raise RigError("Only ordinary triangle primitives are supported")
            attributes=primitive["attributes"]
            if not all(key in attributes for key in ("POSITION","NORMAL","TEXCOORD_0")): raise RigError("Exact source position/normal/UV are required")
            vertices=np.array(accessor(doc,binary,attributes["POSITION"]),dtype=float)
            indices=np.array(accessor(doc,binary,primitive["indices"]),dtype=int).reshape(-1)
            if len(indices)%3 or not len(indices) or indices.min()<0 or indices.max()>=len(vertices) or not np.isfinite(vertices).all(): raise RigError("Invalid triangle surface")
            used=vertices[np.unique(indices)];points=(np.c_[used,np.ones(len(used))]@world[node_index].T)[:,:3]
            minimum=points.min(axis=0);maximum=points.max(axis=0)
            parts.append({"node":node_index,"mesh":node["mesh"],"primitive":primitive_index,"name":mesh.get("name",str(node["mesh"])),
                          "material":primitive.get("material"),"vertices":len(vertices),"triangles":len(indices)//3,
                          "referenced_world_bounds":{"min":minimum.tolist(),"max":maximum.tolist(),"size":(maximum-minimum).tolist()}})
    if not parts: raise RigError("At least one actual source triangle surface is required")
    return parts


def write_new(path,raw):
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open("xb") as handle: handle.write(raw)


def export_review(images,materials,destination):
    entries=[]
    for image in images:
        suffix=".png" if image["mime"]=="image/png" else ".jpg"
        original=destination/f"image_{image['index']:02}_original{suffix}"
        write_new(original,image["raw"])
        entries.append({"role":"original_embedded_bytes","image":image["index"],"file":original.relative_to(ROOT).as_posix(),"sha256":sha(original),
                        "embedded_sha256":image["sha256"],"byte_exact":original.read_bytes()==image["raw"],"inspection_only":True})
    requested=set()
    for material in materials:
        for role,index in material["roles"].items():
            if role=="packed_metallic_roughness": requested.update((("roughness",index),("metalness",index)))
            else: requested.add((role,index))
    for role,index in sorted(requested):
        source=images[index]["image"]
        channel={"roughness":1,"metalness":2,"occlusion":0}.get(role)
        decoded=source.convert("RGB").getchannel(channel) if channel is not None else source.convert("RGBA")
        png=destination/f"image_{index:02}_{role}.png";buffer=BytesIO();decoded.save(buffer,format="PNG");write_new(png,buffer.getvalue())
        verified=Image.open(png);verified.load()
        if verified.mode!=decoded.mode or verified.size!=decoded.size or verified.tobytes()!=decoded.tobytes(): raise RigError("PNG review export altered decoded pixels")
        entries.append({"role":role,"image":index,"file":png.relative_to(ROOT).as_posix(),"sha256":sha(png),"size":list(decoded.size),
                        "source_channel":channel,"mode":decoded.mode,"decoded_pixels_exact":True,"inspection_only":True})
    return entries


def prepare(name,approved,models,new_accounts,output):
    source_value=SOURCES[name];approval=approved.get(name,{})
    previous=models.get(name)
    initial={"name":name,"target_storage_path":"ServerStorage.CustomModels."+name,"approval":approval,"existing_saved_mapping":previous,
             "new_account_record_present":name in new_accounts,"reviewed_by_root":False,"shown_to_user":False,"upload_submitted":False,"actual_ids":None,
             "ready_for_upload":False,"game_spawn_contract":"configured" if name not in ("SkeletonKing",) else "boss gameplay not configured"}
    if source_value is None:
        initial.update(stage="HeldMissingApprovedGLB",reason="No BigSlime GLB exists in the allowlisted source collection; approved.json status is redo. Never substitute Slime or use art/out/v1 automatically.",
                       available_unapproved_image="art/out/BigSlime.png",batch=None)
        return initial
    if approval.get("status")!="approved": raise RigError("The selected design is not approved")
    approved_image=approved_path(approval["file"]);source=approved_path(source_value)
    before=source.read_bytes();doc,binary,_=read_glb(source)
    meshes=mesh_inventory(doc,binary);materials,native=material_roles(doc);images=source_images(doc,binary)
    maximum=len(meshes)+len(native)+1
    if maximum>10: raise RigError("Model/texture/wrapper count exceeds ten; splitting needs separate preparation")
    if any(index not in range(len(images)) for _,index in native): raise RigError("A material references an absent embedded image")
    destination=output/name;exact=destination/"import_original.glb";write_new(exact,before)
    review=export_review(images,materials,destination/"review_textures")
    if source.read_bytes()!=before or exact.read_bytes()!=before: raise RigError("Original GLB source/copy changed")
    has_pbr=any(role in ("normal","packed_metallic_roughness") for m in materials for role in m["roles"])
    initial.update(stage="PreparedOfflineAwaitingRootReview",source_file=source.relative_to(ROOT).as_posix(),source_sha256=sha(before),original_source_unchanged=True,
                   exact_import_file=exact.relative_to(ROOT).as_posix(),exact_import_sha256=sha(exact),source_image=approved_image.relative_to(ROOT).as_posix(),source_image_sha256=sha(approved_image),
                   source_meshes=meshes,source_materials=materials,embedded_images=[{k:v for k,v in image.items() if k not in ("raw","image")} for image in images],review_exports=review,
                   batch={"models":1,"mesh_assets_maximum":len(meshes),"texture_assets_maximum":len(native),"model_wrapper_assets_maximum":1,"total_assets_maximum":maximum,
                          "policy":"one approved monster per native Import; verify actual count before submission; never combine batches automatically"},
                   material_findings={"source_opaque":all(m["alpha_mode"]=="OPAQUE" and m["basecolor_factor"][3]==1 for m in materials) and all(image["alpha_range"]==[255,255] for image in images),
                                      "source_normal_and_packed_mr_maps":has_pbr,"source_basecolor_pixels_preserved":True,"pbr_and_color_appearance_need_native_review":True,
                                      "transparency_change_prepared":False,"color_only_glb_generated":False,
                                      "color_only_option":"Keep the source and old PBR mapping as rollback. If root selects a color-only input, prepare an explicit new GLB retaining exact geometry/UV/normals/color JPEG bytes; no map removal is applied by this preflight."})
    return initial


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir",type=Path,required=True)
    parser.add_argument("--place",type=Path,default=ROOT/"place/GoodEvil.rbxlx")
    args=parser.parse_args(argv)
    output=args.output_dir.resolve();output.relative_to(ROOT/"build")
    if output.exists(): raise RigError("Use a fresh local ledger directory; no previous/unknown result is overwritten")
    place=args.place.resolve()
    if place not in (ROOT/"build/GoodEvil.rbxlx",ROOT/"place/GoodEvil.rbxlx"): raise RigError("Only the saved GoodEvil place may be read")
    approved=json.loads((ROOT/"art/approved.json").read_text(encoding="utf-8"))
    models=saved_models(place);accounts=json.loads((ROOT/"art/models/new_asset_ids.json").read_text(encoding="utf-8")).get("models",{})
    output.mkdir(parents=True,exist_ok=False)
    entries=[]
    for name in SOURCES:
        try: entries.append(prepare(name,approved,models,accounts,output))
        except (RigError,OSError,ValueError,KeyError,TypeError) as error:
            entries.append({"name":name,"stage":"HeldValidationFailure","reason":str(error),"ready_for_upload":False,"upload_submitted":False})
    report={"schema":1,"place":place.relative_to(ROOT).as_posix(),"place_sha256":sha(place),"place_bytes":place.stat().st_size,
            "approval_sha256":sha(ROOT/"art/approved.json"),"new_account_mapping_sha256":sha(ROOT/"art/models/new_asset_ids.json"),
            "requested":entries,"saved_custom_models":models,"excluded_inputs":["art/out/v1/**","art/models/Skeleton.glb (replaced by selected clothed Skeleton)","art/models/SkeletonKing.glb (replaced by selected clothed SkeletonKing)","unselected clothed Goblin/GoblinBrute revisions"],
            "saved_snapshot_only":True,"root_direct_visual_review_required":True,"automatic_upload":False,"source_modified":False,
            "studio_calls":0,"api_calls":0,"uploads":0,"promotion":False}
    target=output/"ledger_prepared.json";write_new(target,(json.dumps(report,ensure_ascii=False,indent=2)+"\n").encode("utf-8"))
    summary={"requested":len(entries),"prepared":sum(e["stage"]=="PreparedOfflineAwaitingRootReview" for e in entries),"held":sum(e["stage"].startswith("Held") for e in entries),
             "maximum_assets_each":max((e.get("batch") or {}).get("total_assets_maximum",0) for e in entries),"ledger":str(target),"studio_calls":0,"api_calls":0,"uploads":0}
    print(json.dumps(summary,ensure_ascii=False))
    return int(any(e["stage"]=="HeldValidationFailure" for e in entries))


if __name__=="__main__":
    try: raise SystemExit(main())
    except (RigError,ValueError,OSError) as error: raise SystemExit("monster_import_preflight refused: "+str(error))
