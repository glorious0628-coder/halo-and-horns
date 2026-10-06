"""
Build the rank accessories (A23-54: horns A row R1-R5, halo B row R1-R5) as simple toy meshes in Blender, 0 credits.
The approved 2D (art/out/acc/<Name>.png, image gen 2, user OK) is the reference; Roblox free generation failed
(extra heads, wrong colours), so the shapes are modelled directly from rings, cones, discs and feather blobs.

  blender --background --factory-startup --python tools/acc_build.py -- <out_dir> [names...]

- Units: studs (R15 head is about 1.2 wide). Origin = centre of the ring / middle between the horn bases.
- Front faces -Y in Blender = +Z in the exported glTF (what CharacterVisuals expects, review 2026-10-06).
- One mesh + one 64x64 palette texture per accessory (each part's UVs sit in its colour cell), so Roblox gets
  one MeshPart; glow and embers are left to effects in the game (image gen 2 note).
- Writes <out_dir>/<Name>.glb, <out_dir>/<Name>_front34.png (render) and <out_dir>/stats.json (tris).
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = os.path.abspath(argv[0])
NAMES = argv[1:] or ["HornsR1", "HornsR2", "HornsR3", "HornsR4", "HornsR5", "HaloR1", "HaloR2", "HaloR3", "HaloR4", "HaloR5"]
os.makedirs(OUT, exist_ok=True)

PALETTE = {  # cell index -> sRGB colour
    "silver": (0.85, 0.87, 0.90), "gold": (1.0, 0.78, 0.22), "gold_d": (0.86, 0.58, 0.12), "white": (0.97, 0.97, 0.96),
    "red": (0.88, 0.12, 0.14), "red_d": (0.55, 0.06, 0.08), "crimson": (0.62, 0.10, 0.14), "crimson_d": (0.36, 0.05, 0.07),
    "gem": (1.0, 0.45, 0.08), "diamond": (0.92, 0.97, 1.0), "feather_s": (0.86, 0.88, 0.92),
}
CELLS = list(PALETTE)


def palette_image():
    n = 8
    img = bpy.data.images.new("Palette", 64, 64, alpha=False)
    # set the colour space first: changing it later regenerates a generated image and wipes the pixels
    img.colorspace_settings.name = "sRGB"
    px = [0.0] * (64 * 64 * 4)
    for i, key in enumerate(CELLS):
        cx, cy = i % n, i // n
        r, g, b = PALETTE[key]
        for y in range(cy * 8, cy * 8 + 8):
            for x in range(cx * 8, cx * 8 + 8):
                k = (y * 64 + x) * 4
                px[k:k + 4] = [r, g, b, 1.0]
    img.pixels = px
    img.pack()
    return img


def cell_uv(key):
    i = CELLS.index(key)
    return ((i % 8) * 8 + 4) / 64, ((i // 8) * 8 + 4) / 64


class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def add(self, other_bm, key):
        u, v = cell_uv(key)
        vmap = {}
        for vert in other_bm.verts:
            vmap[vert] = self.bm.verts.new(vert.co)
        for f in other_bm.faces:
            try:
                nf = self.bm.faces.new([vmap[x] for x in f.verts])
            except ValueError:
                continue
            nf.smooth = True
            for loop in nf.loops:
                loop[self.uv].uv = (u, v)  # Blender UV origin = bottom-left = image row 0
        other_bm.free()

    def add_colored(self, other_bm, key_of_face):
        vmap = {}
        for vert in other_bm.verts:
            vmap[vert] = self.bm.verts.new(vert.co)
        for f in other_bm.faces:
            key = key_of_face(f)
            u, v = cell_uv(key)
            try:
                nf = self.bm.faces.new([vmap[x] for x in f.verts])
            except ValueError:
                continue
            nf.smooth = True
            for loop in nf.loops:
                loop[self.uv].uv = (u, v)  # Blender UV origin = bottom-left = image row 0
        other_bm.free()


def torus(R, r, z=0.0, seg=48, rseg=10, flat=1.0):
    bm = bmesh.new()
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        ring = []
        for j in range(rseg):
            b = 2 * math.pi * j / rseg
            x = (R + r * math.cos(b)) * math.cos(a)
            y = (R + r * math.cos(b)) * math.sin(a)
            zz = z + r * math.sin(b) * flat
            ring.append(bm.verts.new((x, y, zz)))
        rings.append(ring)
    for i in range(seg):
        for j in range(rseg):
            a, b = rings[i][j], rings[(i + 1) % seg][j]
            c, d = rings[(i + 1) % seg][(j + 1) % rseg], rings[i][(j + 1) % rseg]
            bm.faces.new((a, b, c, d))
    return bm


def star(center, outer, inner, depth, points=5, facing=Vector((0, -1, 0)), up=Vector((0, 0, 1))):
    bm = bmesh.new()
    right = up.cross(facing).normalized()
    front, back = [], []
    for k in range(points * 2):
        a = math.pi / 2 + math.pi * k / points
        rr = outer if k % 2 == 0 else inner
        p = center + right * (math.cos(a) * rr) + up * (math.sin(a) * rr)
        front.append(bm.verts.new(p + facing * depth / 2))
        back.append(bm.verts.new(p - facing * depth / 2))
    cf = bm.verts.new(center + facing * depth * 0.9)
    cb = bm.verts.new(center - facing * depth * 0.9)
    n = len(front)
    for k in range(n):
        bm.faces.new((cf, front[k], front[(k + 1) % n]))
        bm.faces.new((cb, back[(k + 1) % n], back[k]))
        bm.faces.new((front[k], back[k], back[(k + 1) % n], front[(k + 1) % n]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def sun(center, radius, depth, rays=8, facing=Vector((0, -1, 0)), up=Vector((0, 0, 1))):
    bm = bmesh.new()
    right = up.cross(facing).normalized()
    pts = []
    for k in range(rays * 2):
        a = math.pi / 2 + math.pi * k / rays
        rr = radius if k % 2 == 0 else radius * 0.62
        pts.append(center + right * (math.cos(a) * rr) + up * (math.sin(a) * rr))
    f = [bm.verts.new(p + facing * depth / 2) for p in pts]
    b = [bm.verts.new(p - facing * depth / 2) for p in pts]
    cf = bm.verts.new(center + facing * depth * 1.4)
    cb = bm.verts.new(center - facing * depth * 0.6)
    n = len(f)
    for k in range(n):
        bm.faces.new((cf, f[k], f[(k + 1) % n]))
        bm.faces.new((cb, b[(k + 1) % n], b[k]))
        bm.faces.new((f[k], b[k], b[(k + 1) % n], f[(k + 1) % n]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def blob(center, sx, sy, sz, rot=None, seg=12, rings=6):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    m = Matrix.Diagonal((sx, sy, sz, 1.0))
    if rot is not None:
        m = rot.to_4x4() @ m
    bmesh.ops.transform(bm, matrix=Matrix.Translation(center) @ m, verts=bm.verts)
    return bm


def octa(center, s):
    bm = bmesh.new()
    pts = [center + Vector(v) * s for v in ((1, 0, 0), (-1, 0, 0), (0, 0.6, 0), (0, -0.6, 0), (0, 0, 1.4), (0, 0, -1.4))]
    v = [bm.verts.new(p) for p in pts]
    for a, b in ((0, 2), (2, 1), (1, 3), (3, 0)):
        bm.faces.new((v[a], v[b], v[4]))
        bm.faces.new((v[b], v[a], v[5]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def wing(side, base, span, height, feathers=4):
    """Fan of slim rounded feathers pointing outward and up (upper ones longer). side = +1 right, -1 left."""
    out = []
    feathers = max(feathers, 4)
    for k in range(feathers):
        t = k / (feathers - 1)
        ang = math.radians(8 + 62 * t)
        length = span * (0.62 + 0.38 * t)
        d = Vector((side * math.cos(ang), 0.12, math.sin(ang))).normalized()
        c = base + d * (length * 0.5)
        x = d
        z = Vector((0, -1, 0)).cross(x).normalized()
        y = z.cross(x).normalized()
        rot = Matrix((x, y, z)).transposed()
        out.append(blob(c, length * 0.5, height * 0.05, height * 0.085, rot=rot, seg=10, rings=5))
    return out


def horn_path(height, out_bend, back_bend, curl=0.0, steps=18):
    """Crescent devil horn (right side; mirrored for the left): rises outward, the tip curls back in and up.
    Cubic Bezier base -> out -> high out -> tip pulled toward the centre (curl adds more hook)."""
    p0 = Vector((0, 0, 0))
    p1 = Vector((out_bend * 1.05, -back_bend * 0.3, height * 0.30))
    p2 = Vector((out_bend * (1.0 + 0.2 * curl), -back_bend * 0.7, height * 0.85))
    p3 = Vector((out_bend * (0.45 - 0.35 * curl), -back_bend, height))
    pts = []
    for i in range(steps + 1):
        t = i / steps
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t ** 2, t ** 3
        pts.append(p0 * a + p1 * b + p2 * c + p3 * d)
    return pts


def tube(path, r0, r1, seg=12, key_of_t=None):
    bm = bmesh.new()
    tl = bm.faces.layers.int.new("t")  # create the layer before any face (adding it later invalidates faces)
    rings = []
    n = len(path)
    for i, p in enumerate(path):
        t = i / (n - 1)
        tang = (path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized()
        a = Vector((0, 0, 1)) if abs(tang.z) < 0.9 else Vector((1, 0, 0))
        u = tang.cross(a).normalized()
        v = tang.cross(u).normalized()
        rr = r1 + (r0 - r1) * (1 - t ** 1.15)  # fat base thinning steadily to a soft tip
        ring = [bm.verts.new(p + (u * math.cos(2 * math.pi * j / seg) + v * math.sin(2 * math.pi * j / seg)) * rr) for j in range(seg)]
        rings.append((t, ring))
    tip = bm.verts.new(path[-1] + (path[-1] - path[-2]).normalized() * r1 * 1.5)
    cap = bm.verts.new(path[0])
    faces = []
    for i in range(n - 1):
        t, ra = rings[i]
        _, rb = rings[i + 1]
        for j in range(seg):
            f = bm.faces.new((ra[j], ra[(j + 1) % seg], rb[(j + 1) % seg], rb[j]))
            f[tl] = int(((i + 0.5) / (n - 1)) * 1000)
    last = rings[-1][1]
    for j in range(seg):
        f = bm.faces.new((last[j], last[(j + 1) % seg], tip))
        f[tl] = 1000
    first = rings[0][1]
    for j in range(seg):
        f = bm.faces.new((first[(j + 1) % seg], first[j], cap))
        f[tl] = 0
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def ring_band(path, t_at, r, width, seg=12):
    """A short slightly bigger tube around the horn at fraction t (gold band)."""
    n = len(path)
    i = min(n - 2, int(t_at * (n - 1)))
    p0, p1 = path[i], path[i + 1]
    mid = (p0 + p1) / 2
    tang = (p1 - p0).normalized()
    a = Vector((0, 0, 1)) if abs(tang.z) < 0.9 else Vector((1, 0, 0))
    u = tang.cross(a).normalized()
    v = tang.cross(u).normalized()
    bm = bmesh.new()
    top, bot = [], []
    for j in range(seg):
        d = u * math.cos(2 * math.pi * j / seg) + v * math.sin(2 * math.pi * j / seg)
        top.append(bm.verts.new(mid + tang * width / 2 + d * r))
        bot.append(bm.verts.new(mid - tang * width / 2 + d * r))
    for j in range(seg):
        bm.faces.new((bot[j], bot[(j + 1) % seg], top[(j + 1) % seg], top[j]))
    return bm


def horns(B, height, r0, out_bend, back_bend, spacing, colors, stripes=0, bands=(), gems=False, curl=0.0):
    for side in (-1, 1):
        path = [Vector((side * spacing / 2 + side * p.x, p.y, p.z)) for p in horn_path(height, out_bend, back_bend, curl)]
        bm = tube(path, r0, max(0.012, r0 * 0.12))
        layer = bm.faces.layers.int.get("t")

        def key(f):
            t = f[layer] / 1000.0
            if stripes:
                return colors[0] if int(t * stripes * 2) % 2 == 0 else colors[1]
            return colors[1] if t < 0.35 else colors[0]
        B.add_colored(bm, key)
        for tb in bands:
            rr = max(0.012, r0 * 0.12) + (r0 - max(0.012, r0 * 0.12)) * (1 - tb ** 1.15)
            B.add(ring_band(path, tb, rr * 1.12, height * 0.07), "gold")
            if gems:
                n = len(path)
                i = min(n - 2, int(tb * (n - 1)))
                c = (path[i] + path[i + 1]) / 2 + Vector((0, -1, 0)) * rr * 1.15
                B.add(blob(c, rr * 0.35, rr * 0.25, rr * 0.35, seg=8, rings=4), "gem")


def build(name):
    B = Builder()
    if name == "HaloR1":
        B.add(torus(0.62, 0.05, flat=0.9), "silver")
    elif name == "HaloR2":
        B.add(torus(0.62, 0.065), "gold")
        B.add(star(Vector((0, -0.64, 0.02)), 0.17, 0.075, 0.07), "gold")
    elif name == "HaloR3":
        B.add(torus(0.62, 0.065), "gold")
        for k, dx in enumerate((-0.12, 0, 0.12)):
            B.add(octa(Vector((dx, -0.66, 0.0)), 0.035 if k != 1 else 0.045), "diamond")
        for side in (-1, 1):
            for bm in wing(side, Vector((side * 0.66, 0.05, 0.02)), 0.42, 0.5, feathers=3):
                B.add(bm, "white")
    elif name == "HaloR4":
        B.add(torus(0.62, 0.07), "gold")
        B.add(sun(Vector((0, -0.66, 0.03)), 0.16, 0.06), "gold_d")
        for side in (-1, 1):
            for bm in wing(side, Vector((side * 0.66, 0.05, 0.03)), 0.55, 0.62, feathers=4):
                B.add(bm, "white")
    elif name == "HaloR5":
        B.add(torus(0.62, 0.07, z=0.0, seg=36, rseg=8), "gold")
        B.add(torus(0.70, 0.05, z=0.10, seg=36, rseg=6), "gold_d")
        for k in range(8):
            a = 2 * math.pi * k / 8 + math.pi / 8
            p = Vector((0.70 * math.cos(a), 0.70 * math.sin(a), 0.16))
            B.add(blob(p + Vector((0, 0, 0.06)), 0.035, 0.035, 0.07, seg=8, rings=4), "gold")
        B.add(sun(Vector((0, -0.76, 0.07)), 0.2, 0.07, rays=10), "gold")
        for side in (-1, 1):
            for bm in wing(side, Vector((side * 0.74, 0.06, 0.06)), 0.8, 0.9, feathers=5):
                B.add(bm, "white")
    elif name == "HornsR1":
        horns(B, 0.30, 0.15, 0.10, 0.02, 0.62, ("red", "red_d"))
    elif name == "HornsR2":
        horns(B, 0.46, 0.15, 0.24, 0.04, 0.62, ("red", "red_d"))
    elif name == "HornsR3":
        horns(B, 0.58, 0.18, 0.34, 0.05, 0.64, ("red", "red_d"), stripes=3)
    elif name == "HornsR4":
        horns(B, 0.70, 0.17, 0.30, 0.06, 0.64, ("crimson", "crimson_d"), bands=(0.3, 0.62))
    elif name == "HornsR5":
        horns(B, 0.86, 0.20, 0.34, 0.08, 0.66, ("crimson", "crimson_d"), bands=(0.2, 0.47, 0.72), gems=True, curl=0.8)
    me = bpy.data.meshes.new(name)
    B.bm.to_mesh(me)
    B.bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    for p in me.polygons:
        p.use_smooth = True
    return obj


bpy.ops.wm.read_factory_settings(use_empty=True)
pal = palette_image()
mat = bpy.data.materials.new("AccPalette")
mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Roughness"].default_value = 0.28
bsdf.inputs["Metallic"].default_value = 0.15
tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = pal
tex.interpolation = "Closest"
mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

scene = bpy.context.scene
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
scene.view_settings.view_transform = "Standard"
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 512
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.35
scene.world = world
sun_d = bpy.data.lights.new("Sun", "SUN")
sun_d.energy = 3.4
sun_o = bpy.data.objects.new("Sun", sun_d)
scene.collection.objects.link(sun_o)
sun_o.rotation_euler = (math.radians(50), 0, math.radians(-25))
cam_d = bpy.data.cameras.new("Cam")
cam_d.lens = 60
cam = bpy.data.objects.new("Cam", cam_d)
scene.collection.objects.link(cam)
scene.camera = cam

stats = {}
for name in NAMES:
    for o in list(scene.objects):
        if o.type == "MESH":
            bpy.data.objects.remove(o)
    obj = build(name)
    obj.data.materials.append(mat)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    dims = [round(v, 3) for v in obj.dimensions]
    stats[name] = {"tris": tris, "size_studs": dims}
    # 3/4 front view from slightly above (front = -Y)
    c = Vector(obj.location) + Vector((0, 0, obj.dimensions.z * 0.35))
    dist = max(obj.dimensions) * 2.3 + 0.5
    a, e = math.radians(-20), math.radians(14)
    cam.location = c + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, f"{name}_front34.png")
    bpy.ops.render.render(write_still=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, f"{name}.glb"), export_format="GLB", use_selection=True)
    print("[acc_build]", name, json.dumps(stats[name]), flush=True)
json.dump(stats, open(os.path.join(OUT, "stats.json"), "w"), indent=1)
