"""Clay renders of Tripo Smart Mesh white models for 디자인 검수 to pick from (user 10/12: all 4 go to 디자인 검수).
Each model: 8 turns around (every 45 deg, slightly from above) + straight top, studio light + cavity so broken faces,
dents and slanted panels show. Then a sheet: one row per model.

  blender --background --factory-startup --python tools/white_model_sheet.py -- <out_dir> <label>=<model.fbx|glb> ...
  py -c "..." (the sheet is assembled by this script when PIL is importable from Blender's Python, else run
             py tools/white_model_sheet.py --sheet <out_dir> <out.jpg>)

The front in the 2D = the model's +X for Tripo Studio fbx downloads (model_url); pass --front -y for Studio GLB exports.
"""
import math
import os
import sys


def render(out_dir, items, front_y=False, px=640):
    import bpy
    from mathutils import Vector
    for label, path in items:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        if path.lower().endswith(".fbx"):
            bpy.ops.import_scene.fbx(filepath=os.path.abspath(path))
        else:
            bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
        obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        pts = [o.matrix_world @ Vector(c) for o in obs for c in o.bound_box]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        ctr, size = (lo + hi) / 2, max(hi - lo)
        sc = bpy.context.scene
        sc.render.engine = "BLENDER_WORKBENCH"
        sh = sc.display.shading
        sh.light = "STUDIO"
        sh.color_type = "SINGLE"
        sh.single_color = (0.85, 0.85, 0.85)
        sh.show_cavity = True
        sh.cavity_type = "BOTH"
        sh.show_object_outline = False
        sh.background_type = "VIEWPORT"
        sh.background_color = (0.30, 0.31, 0.33)
        sc.view_settings.view_transform = "Standard"
        sc.render.resolution_x = sc.render.resolution_y = px
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        sc.collection.objects.link(cam)
        sc.camera = cam
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = size * 1.12
        base = -90.0 if front_y else 0.0  # azimuth of the front
        views = [(f"az{a:03d}", base + a, 0.25) for a in range(0, 360, 45)] + [("top", base, 6.0)]
        for name, az, el in views:
            d = Vector((math.cos(math.radians(az)), math.sin(math.radians(az)), el)).normalized()
            cam.location = ctr + d * size * 3
            cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
            sc.render.filepath = os.path.abspath(os.path.join(out_dir, f"{label}_{name}.png"))
            bpy.ops.render.render(write_still=True)
        tris = sum(len(o.data.polygons) for o in obs)
        print("RENDERED", label, "faces", tris)


def sheet(out_dir, out_jpg, cell=300):
    from PIL import Image, ImageDraw
    files = sorted(f for f in os.listdir(out_dir) if f.endswith(".png"))
    labels = sorted({f.rsplit("_", 1)[0] for f in files})
    names = [f"az{a:03d}" for a in range(0, 360, 45)] + ["top"]
    heads = ["front", "45", "side 90", "135", "back", "225", "side 270", "315", "top"]
    s = Image.new("RGB", (cell * len(names) + 90, (cell + 4) * len(labels) + 22), (40, 40, 40))
    dr = ImageDraw.Draw(s)
    for i, h in enumerate(heads):
        dr.text((90 + i * cell + 6, 5), h, fill=(255, 255, 255))
    for r, lab in enumerate(labels):
        dr.text((6, 22 + r * (cell + 4) + cell // 2), lab, fill=(255, 255, 255))
        for c, n in enumerate(names):
            p = os.path.join(out_dir, f"{lab}_{n}.png")
            if os.path.exists(p):
                im = Image.open(p).convert("RGB").resize((cell, cell))
                s.paste(im, (90 + c * cell, 22 + r * (cell + 4)))
    s.save(out_jpg, quality=90)
    print("SHEET", out_jpg, s.size)


if __name__ == "__main__":
    if "--sheet" in sys.argv:
        i = sys.argv.index("--sheet")
        sheet(sys.argv[i + 1], sys.argv[i + 2])
    else:
        a = sys.argv[sys.argv.index("--") + 1:]
        fy = "--front" in a and a[a.index("--front") + 1] == "-y"
        a = [x for j, x in enumerate(a) if x != "--front" and not (j > 0 and a[j - 1] == "--front")]
        out = a[0]
        os.makedirs(out, exist_ok=True)
        render(out, [tuple(x.split("=", 1)) for x in a[1:]], fy)
