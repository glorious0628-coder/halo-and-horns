# Final-look preview of the Slime Prince / small Slime: blender --background --factory-startup --python tools/blender_slime_final_preview.py -- <body.glb> <texture.png> <crown.glb|-> <crown scale> <out.png> (front / side / back / top; 0.7x crown centred on the head).
import sys, math, bpy
from mathutils import Vector
argv=sys.argv[sys.argv.index("--")+1:]
BODY,TEX,CROWN,SCALE,OUT=argv[0],argv[1],argv[2],float(argv[3]),argv[4]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BODY)
body=[x for x in bpy.context.scene.objects if x.type=="MESH"][0]
im=bpy.data.images.load(TEX); im.colorspace_settings.name="sRGB"
for m in body.data.materials:
    for n in m.node_tree.nodes:
        if n.type=="TEX_IMAGE": n.image=im
if CROWN!="-":
    before=set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=CROWN)
    cr=[x for x in bpy.context.scene.objects if x not in before and x.type=="MESH"][0]
    # the crown mesh is already in the body's frame (bbox x -0.27..0.19, y -0.08..0.38, z 0.19..0.57): scale it about the
    # bottom centre of its footprint so it keeps sitting where it sits now
    vs=[cr.matrix_world@v.co for v in cr.data.vertices]
    cx=(min(v.x for v in vs)+max(v.x for v in vs))/2; cy=(min(v.y for v in vs)+max(v.y for v in vs))/2; cz=min(v.z for v in vs)
    for v in cr.data.vertices:
        v.co.x=(v.co.x-cx)*SCALE; v.co.y=(v.co.y-cy)*SCALE; v.co.z=cz+(v.co.z-cz)*SCALE  # centred on the body (x, y = 0)
    mat=bpy.data.materials.new("gold"); mat.use_nodes=False; mat.diffuse_color=(1.0,0.6,0.06,1)
    cr.data.materials.clear(); cr.data.materials.append(mat)
pts=[body.matrix_world@v.co for v in body.data.vertices]
c=[0,0,0.05]
sc=bpy.context.scene; sc.render.engine="BLENDER_WORKBENCH"
sc.display.shading.light="STUDIO"; sc.display.shading.color_type="TEXTURE"; sc.display.shading.background_type="VIEWPORT"; sc.display.shading.background_color=(0.85,0.85,0.85)
# crown uses material colour
cd=bpy.data.cameras.new("C"); cd.type="ORTHO"; cd.ortho_scale=1.45
cam=bpy.data.objects.new("C",cd); sc.collection.objects.link(cam); sc.camera=cam
sc.render.resolution_x=sc.render.resolution_y=560
for name,az,el in [("front",90,10),("side",0,10),("back",270,10),("top",90,50)]:
    a=math.radians(az-90); e=math.radians(el); d=3
    cam.location=(c[0]+d*math.cos(e)*math.cos(a),c[1]+d*math.cos(e)*math.sin(a),c[2]+d*math.sin(e))
    cam.rotation_euler=(Vector(c)-cam.location).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=OUT.replace(".png",f"_{name}.png"); bpy.ops.render.render(write_still=True)
