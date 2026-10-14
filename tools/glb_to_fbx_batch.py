"""glb_to_fbx_batch.py : Blender background script. Converts every GLB in a manifest to FBX next to it (<name>_HD_fit.fbx)
for the Open Cloud Assets API (Model asset = .fbx). Geometry/materials untouched; textures embedded (path mode COPY, embed).

  blender.exe --background --factory-startup --python tools/glb_to_fbx_batch.py -- <manifest.json> [--only NAME,NAME]
"""
import bpy, json, os, sys

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
manifest = argv[0]
only = None
if "--only" in argv:
    only = set(argv[argv.index("--only") + 1].split(","))
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
m = json.load(open(manifest, encoding="utf-8"))
done = []
for w in m["weapons"]:
    if only and w["name"] not in only:
        continue
    glb = os.path.join(root, w["glb"])
    fbx = glb[:-4] + ".fbx"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    bpy.ops.export_scene.fbx(filepath=fbx, path_mode="COPY", embed_textures=True, use_selection=False,
                             apply_unit_scale=True, global_scale=1.0, axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE")
    done.append((w["name"], os.path.getsize(fbx)))
    print("FBX", w["name"], os.path.getsize(fbx))
print("DONE", len(done))
