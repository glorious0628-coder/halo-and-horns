# Kit_W_CampFence orange tips (2026-10-09): blender --background --factory-startup --python tools/blender_fence_tips.py -- art/models/tripo/Kit_W_CampFence_raw.glb build/retex/fence_tex.png build/retex/fence_tips.json
# writes the 4K base colour + the UV triangles of the post tips (top 0.15 of each log); then tint those texels orange with PIL (see art/models/worldkit/Kit_W_CampFence_orange_tex_1k.png = result, uploaded as rbxassetid://110674198235051, TextureID of the fence MeshParts in woods_dress.luau).
import sys, json, bpy
argv=sys.argv[sys.argv.index("--")+1:]
IN,OUT_PNG,OUT_JSON=argv
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
o=[x for x in bpy.context.scene.objects if x.type=="MESH"][0]
me=o.data; uv=me.uv_layers.active
img=None
for m in me.materials:
    for n in m.node_tree.nodes:
        if n.type=="TEX_IMAGE" and n.image: img=n.image
img.filepath_raw=OUT_PNG; img.file_format="PNG"; img.save()
# posts: bin faces by Y (4 logs along Y)
ys=sorted(set(round(p.center.y,3) for p in me.polygons))
import math
# cluster: split the Y range into 4 equal bins
y0=min(v.co.y for v in me.vertices); y1=max(v.co.y for v in me.vertices)
def post(y): return min(3,int((y-y0)/(y1-y0)*4))
ztop=[ -9 ]*4
for p in me.polygons:
    k=post(p.center.y); ztop[k]=max(ztop[k],p.center.z)
print("ztop",ztop)
tris=[]
for p in me.polygons:
    k=post(p.center.y)
    if p.center.z > ztop[k]-0.15:
        loops=list(p.loop_indices)
        pts=[(uv.data[l].uv.x,uv.data[l].uv.y) for l in loops]
        tris.append(pts)
print("tip faces",len(tris),"of",len(me.polygons))
json.dump(tris,open(OUT_JSON,"w"))
