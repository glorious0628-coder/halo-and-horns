"""List PBR images in a Tripo FBX and save small previews of each map.
blender --background --factory-startup --python pbr_maps.py -- <out_dir> <file.fbx> ...
"""
import os
import sys

import bpy

a = sys.argv[sys.argv.index("--") + 1:]
out = a[0]
os.makedirs(out, exist_ok=True)
for path in a[1:]:
    label = os.path.splitext(os.path.basename(path))[0]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.abspath(path))
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        for n in mat.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                for sock in ("Base Color", "Metallic", "Roughness", "Normal"):
                    s = n.inputs.get(sock)
                    if s and s.is_linked:
                        src = s.links[0].from_node
                        while src.type != "TEX_IMAGE" and src.inputs and any(i.is_linked for i in src.inputs):
                            src = [i for i in src.inputs if i.is_linked][0].links[0].from_node
                        if src.type == "TEX_IMAGE" and src.image:
                            img = src.image
                            print("MAP", label, sock, img.name, tuple(img.size))
                            cp = img.copy()
                            cp.scale(512, 512)
                            cp.filepath_raw = os.path.join(out, f"{label}__{sock.replace(' ', '')}.png")
                            cp.file_format = "PNG"
                            cp.save()
                    elif s:
                        print("VAL", label, sock, getattr(s, "default_value", None) if sock != "Base Color" else tuple(s.default_value))
