import sys,bpy
IN,OUT,NAME=sys.argv[sys.argv.index("--")+1:][:3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
for o in bpy.context.scene.objects:
    if o.type=="MESH": o.name=NAME; o.data.name=NAME
    elif o.type=="EMPTY": bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_image_format="AUTO", export_apply=True)
print("ok",OUT)
