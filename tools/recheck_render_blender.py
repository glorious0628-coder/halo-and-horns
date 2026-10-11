"""3D re-check renders (SPEC A23-122, 2026-10-11): one Blender process renders many GLBs for the comparison sheets.

  blender --background --factory-startup --python tools/recheck_render_blender.py -- <list.json> <outdir>
          [--res 900] [--only Name1,Name2] [--skip-existing] [--start N] [--count N]

<list.json>: a list of items, or a dict with key "render" (docs/review/3d_recheck_2026-10-11_items.json).
             Each item: {name, glb, image_2d, ...}; paths relative to the repo root (or absolute).
Per model (try/except, one status line per model in <outdir>/render_log.txt):
  <outdir>/<safe name>/front.png right.png back.png left.png q34.png detail.png   (900x900, gray background)
  <outdir>/<safe name>/front_mask.png   (alpha of the front render, for the sheet crops)
  <outdir>/<safe name>/meta.json        (front axis + why, match scores vs the 2D, framing, tris, materials, timings)
Look: EEVEE (Cycles 24 spp + denoise if EEVEE fails), the model's own glTF PBR materials (base colour, metal/rough,
normal), Standard view transform, 3 sun lights placed relative to each camera (key / fill / rim) + light-gray gradient
world. Orthographic cameras, framed on the real vertices.
Front axis: the 4 side views are rendered by axis first (+Y, +X, -Y, -X = the side of the model that faces that axis),
then compared with the 2D source (silhouette IoU + colour-pattern correlation). The file-name rule decides unless the
best 2D match beats it by >= --auto-margin (0.08; smaller margins were wrong on 3/4-view 2Ds in the first run):
  *_parts.glb (tools/house_parts.py) -> +Y; web/*_LOD.glb, web/*_HD_plain.glb (glb_decimate --rotz -90) -> -Y;
  web/X_*_HD.glb -> -Y; API *_LOD.glb (decimated, not turned) -> +X;
  *_raw / *_HD_src / *_backfix / *_capped / *_fill / *_vines (raw Tripo) -> +X; anything else -> -Y.
  --front Name=+Y,... overrides after a human look; meta.front_uncertain marks close calls (check all 4 sides).
right = the camera on the viewer's right of the front camera (Blender numpad 3 when front = -Y).
"""
import json
import math
import os
import re
import sys
import time
import traceback

import bpy
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
LIST, OUT = argv[0], os.path.abspath(argv[1])


def opt(flag, default=None, cast=str):
    return cast(argv[argv.index(flag) + 1]) if flag in argv else default


RES = opt("--res", 900, int)
ONLY = set(opt("--only", "").split(",")) - {""}
SKIP = "--skip-existing" in argv
START = opt("--start", 0, int)
COUNT = opt("--count", 0, int)
AUTO_MARGIN = opt("--auto-margin", 0.08, float)  # 2D match must beat the name rule by this much (smaller = wrong on 3/4 2Ds)
MANUAL = dict(kv.split("=", 1) for kv in opt("--front", "").split(",") if "=" in kv)  # --front Name=+Y,Name2=-X
try:
    ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
except NameError:
    ROOT = os.getcwd()
os.makedirs(OUT, exist_ok=True)
LOG = os.path.join(OUT, "render_log.txt")
BG = 0.55  # neutral gray background (display value)
VIEWS = ("front", "right", "back", "left", "q34", "detail")
AXES = {"+Y": 90.0, "+X": 0.0, "-Y": 270.0, "-X": 180.0}  # azimuth of the camera direction (from +X, CCW)
EL_SIDE = 5.0   # small elevation for the 4 side views
EL_Q34 = 20.0


def log(msg):
    line = time.strftime("%H:%M:%S ") + msg
    print("[recheck] " + line, flush=True)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def safe_name(n):
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", n).strip("_")


def resolve(p):
    if not p or p in ("unknown", "None"):
        return None
    for base in (os.getcwd(), ROOT):
        q = p if os.path.isabs(p) else os.path.join(base, p)
        if os.path.exists(q):
            return q
    return None


def prior_axis(glb):
    b = os.path.basename(glb).lower()
    web = "/web/" in glb.replace("\\", "/").lower()
    if b.endswith("_parts.glb"):
        return "+Y", "name rule: *_parts.glb (house_parts.py) faces +Y"
    if web and (b.endswith("_lod.glb") or b.endswith("_hd_plain.glb")):
        return "-Y", "name rule: web *_LOD / *_HD_plain (glb_decimate --rotz -90) faces -Y"
    if web and b.endswith("_hd.glb"):
        return "-Y", "name rule: web X_*_HD.glb faces -Y (2D match 3/3 in the 10/11 run)"
    if b.endswith("_lod.glb"):
        return "+X", "name rule: API *_LOD.glb (decimated, not turned) faces +X"
    if re.search(r"_(raw|hd_src|backfix|capped|fill|vines)\.glb$", b):
        return "+X", "name rule: raw Tripo GLB faces +X"
    return "-Y", "name rule: default glTF front -Y"


def dirvec(az, el):
    a, e = math.radians(az), math.radians(el)
    return Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e)))


# ---------------------------------------------------------------- image helpers (numpy, bottom-up rows)
def load_rgba(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    ch = img.channels
    bpy.data.images.remove(img)
    a = a.reshape(h, w, 4)
    if ch < 4:
        a[..., 3] = 1.0
    return a


def save_rgb(path, rgb):
    h, w = rgb.shape[:2]
    img = bpy.data.images.new("tmp_save", w, h, alpha=False)
    buf = np.ones((h, w, 4), dtype=np.float32)
    buf[..., :3] = np.clip(rgb, 0, 1)
    img.pixels.foreach_set(buf.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def save_gray(path, g):
    save_rgb(path, np.repeat(g[..., None], 3, axis=2))


def bg_mask_2d(a):
    """mask of the object in a 2D source: alpha if it has real transparency, else distance from the border colour."""
    if a[..., 3].min() < 0.5:
        return a[..., 3] > 0.5
    rgb = a[..., :3]
    border = np.concatenate([rgb[:4].reshape(-1, 3), rgb[-4:].reshape(-1, 3), rgb[:, :4].reshape(-1, 3),
                             rgb[:, -4:].reshape(-1, 3)])
    ref = np.median(border, axis=0)
    d = np.sqrt(((rgb - ref) ** 2).sum(axis=2))
    return d > 0.10


def signature(rgb, mask, n=24):
    ys, xs = np.nonzero(mask)
    if len(xs) < 50:
        return None
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    side = max(y1 - y0, x1 - x0)
    cy, cx = (y0 + y1) / 2.0, (x0 + x1) / 2.0
    g = n * 4
    idx = (np.arange(g) + 0.5) / g * side - side / 2.0
    yy = np.clip((cy + idx).astype(int), 0, mask.shape[0] - 1)
    xx = np.clip((cx + idx).astype(int), 0, mask.shape[1] - 1)
    inside_y = ((cy + idx) >= 0) & ((cy + idx) < mask.shape[0])
    inside_x = ((cx + idx) >= 0) & ((cx + idx) < mask.shape[1])
    m = mask[np.ix_(yy, xx)].astype(np.float32) * inside_y[:, None] * inside_x[None, :]
    c = rgb[np.ix_(yy, xx)] * m[..., None]
    m4 = m.reshape(n, 4, n, 4).mean(axis=(1, 3))
    c4 = c.reshape(n, 4, n, 4, 3).sum(axis=(1, 3)) / np.maximum(m.reshape(n, 4, n, 4).sum(axis=(1, 3)), 1e-6)[..., None]
    return m4, c4


def match(s2, sr):
    m2, c2 = s2
    mr, cr = sr
    iou = float(np.minimum(m2, mr).sum() / max(np.maximum(m2, mr).sum(), 1e-6))
    both = (m2 > 0.5) & (mr > 0.5)
    corr = 0.0
    if both.sum() >= 12:
        a = c2[both].ravel() - c2[both].mean()
        b = cr[both].ravel() - cr[both].mean()
        den = math.sqrt(float((a * a).sum() * (b * b).sum()))
        corr = float((a * b).sum() / den) if den > 1e-9 else 0.0
    return 0.5 * iou + 0.5 * (corr + 1) / 2, iou, corr


# ---------------------------------------------------------------- scene
def setup_scene(engine):
    scene = bpy.context.scene
    scene.render.engine = engine
    scene.render.resolution_x = scene.render.resolution_y = RES
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    if engine == "CYCLES":
        scene.cycles.samples = 24
        scene.cycles.use_denoising = True
        try:
            scene.cycles.device = "GPU"
        except Exception:
            pass
    else:
        ee = scene.eevee
        for k, v in (("taa_render_samples", 32), ("use_shadows", True), ("use_raytracing", True),
                     ("use_gtao", True), ("fast_gi_method", "GLOBAL_ILLUMINATION")):
            try:
                setattr(ee, k, v)
            except Exception:
                pass
    world = bpy.data.worlds.new("RecheckWorld")
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    bgn = nt.nodes["Background"]
    tco = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(tco.outputs["Generated"], sep.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -1.0
    mr.inputs["From Max"].default_value = 1.0
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], ramp.inputs["Fac"])
    ramp.color_ramp.elements[0].color = (0.30, 0.30, 0.30, 1)     # below: darker gray
    ramp.color_ramp.elements[1].color = (0.92, 0.92, 0.92, 1)     # above: light gray
    e = ramp.color_ramp.elements.new(0.5)
    e.color = (0.62, 0.62, 0.62, 1)                                 # horizon
    nt.links.new(ramp.outputs["Color"], bgn.inputs["Color"])
    bgn.inputs["Strength"].default_value = 0.75
    lights = {}
    for name, energy, angle, shadow in (("key", 2.6, 12.0, True), ("fill", 0.9, 40.0, False), ("rim", 1.6, 10.0, True)):
        ld = bpy.data.lights.new("L_" + name, "SUN")
        ld.energy = energy
        ld.angle = math.radians(angle)
        try:
            ld.use_shadow = shadow
        except Exception:
            pass
        lo = bpy.data.objects.new("L_" + name, ld)
        scene.collection.objects.link(lo)
        lights[name] = lo
    cd = bpy.data.cameras.new("RecheckCam")
    cd.type = "ORTHO"
    cam = bpy.data.objects.new("RecheckCam", cd)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene, cam, lights


def place_lights(lights, az):
    for name, (daz, el) in (("key", (40.0, 45.0)), ("fill", (-65.0, 15.0)), ("rim", (170.0, 40.0))):
        L = dirvec(az + daz, el)
        lights[name].rotation_euler = L.to_track_quat("Z", "Y").to_euler()


def frame(cam, verts, centre, radius, az, el, scale_mul=1.0, aim=None, fixed_scale=None):
    d = dirvec(az, el)
    q = (-d).to_track_quat("-Z", "Y")
    right = q @ Vector((1, 0, 0))
    up = q @ Vector((0, 1, 0))
    R = np.array(right[:], dtype=np.float64)
    U = np.array(up[:], dtype=np.float64)
    if aim is None:
        u = verts @ R
        v = verts @ U
        u0, u1, v0, v1 = u.min(), u.max(), v.min(), v.max()
        scale = max(u1 - u0, v1 - v0) * 1.08 * scale_mul
        mid = Vector(right * ((u0 + u1) / 2) + up * ((v0 + v1) / 2))
        c0 = Vector(centre)
        # keep the depth of the box centre, move only in the image plane
        cd = c0.dot(d)
        mid = mid + d * cd
    else:
        mid = Vector(aim)
        scale = fixed_scale
    if fixed_scale is not None:
        scale = fixed_scale
    dist = radius * 4.0 + 1.0
    cam.location = mid + d * dist
    cam.rotation_euler = q.to_euler()
    cam.data.ortho_scale = max(scale, 1e-4)
    cam.data.clip_start = max(dist - radius * 1.5, 0.001)
    cam.data.clip_end = dist + radius * 1.5 + 1.0
    return {"scale": scale, "mid": list(mid), "right": list(right), "up": list(up), "dir": list(d)}


def render_to(scene, path):
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def composite(path_rgba, path_out, keep_mask=None):
    a = load_rgba(path_rgba)
    al = a[..., 3:4]
    rgb = a[..., :3] * al + BG * (1 - al)
    save_rgb(path_out, rgb)
    if keep_mask:
        save_gray(keep_mask, a[..., 3])
    return a


def erode(m, r):
    out = m.copy()
    for dy in range(-r, r + 1, max(1, r // 2)):
        for dx in range(-r, r + 1, max(1, r // 2)):
            out &= np.roll(np.roll(m, dy, 0), dx, 1)
    return out


def busiest_window(a, win):
    """window (win x win px) of the front render with the most inner edges; slight preference for the upper part."""
    rgb = a[..., :3]
    lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    gy = np.abs(np.diff(lum, axis=0, prepend=lum[:1]))
    gx = np.abs(np.diff(lum, axis=1, prepend=lum[:, :1]))
    g = (gx + gy) * erode(a[..., 3] > 0.5, 4)
    h, w = g.shape
    ii = np.zeros((h + 1, w + 1), dtype=np.float64)
    ii[1:, 1:] = g.cumsum(0).cumsum(1)
    best, bxy = -1.0, None
    step = 25
    for y in range(0, h - win + 1, step):
        for x in range(0, w - win + 1, step):
            s = ii[y + win, x + win] - ii[y, x + win] - ii[y + win, x] + ii[y, x]
            s *= 1.0 + 0.4 * ((y + win / 2) / h)  # rows are bottom-up: larger y = higher in the picture
            if s > best:
                best, bxy = s, (x, y)
    if bxy is None or best <= 0:
        return None, 0.0
    return bxy, best


# ---------------------------------------------------------------- per model
def do_model(item, engine_state):
    name = item["name"]
    sname = safe_name(name)
    odir = os.path.join(OUT, sname)
    meta = {"name": name, "safe": sname, "glb": item.get("glb"), "image_2d": item.get("image_2d")}
    glb = resolve(item.get("glb"))
    if not glb:
        meta["status"] = "no_glb"
        os.makedirs(odir, exist_ok=True)
        json.dump(meta, open(os.path.join(odir, "meta.json"), "w", encoding="utf-8"), indent=1)
        return "no_glb", "glb missing: %r" % item.get("glb")
    if SKIP and all(os.path.exists(os.path.join(odir, v + ".png")) for v in VIEWS) and \
            os.path.exists(os.path.join(odir, "meta.json")):
        return "skip", "exists"
    os.makedirs(odir, exist_ok=True)
    t0 = time.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    t_imp = time.time() - t0
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise RuntimeError("no mesh objects after import")
    dg = bpy.context.evaluated_depsgraph_get()
    vs, tris = [], 0
    for o in meshes:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        n = len(me.vertices)
        co = np.empty(n * 3, dtype=np.float64)
        me.vertices.foreach_get("co", co)
        co = co.reshape(n, 3)
        mw = np.array(o.matrix_world, dtype=np.float64)
        co = co @ mw[:3, :3].T + mw[:3, 3]
        vs.append(co)
        me.calc_loop_triangles()
        tris += len(me.loop_triangles)
        ev.to_mesh_clear()
    verts = np.concatenate(vs)
    lo, hi = verts.min(0), verts.max(0)
    centre = (lo + hi) / 2
    radius = float(np.linalg.norm(hi - lo) / 2) or 1.0
    mats = sorted({m.name for o in meshes for m in o.data.materials if m})
    imgs = sorted({"%dx%d" % tuple(i.size) for i in bpy.data.images if i.size[0]})
    meta.update({"tris_render": tris, "objects": len(meshes), "materials": len(mats), "images": imgs,
                 "size_xyz": [round(float(x), 3) for x in (hi - lo)], "import_s": round(t_imp, 1)})
    # glass / blended materials: keep what the importer set (EEVEE blended / dithered)
    engine = engine_state["engine"]
    scene, cam, lights = setup_scene(engine)
    tmp = os.path.join(odir, "_tmp.png")

    def shoot(view_name, az, el, **kw):
        place_lights(lights, az)
        fr = frame(cam, verts, centre, radius, az, el, **kw)
        try:
            render_to(scene, tmp)
        except Exception:
            if engine_state["engine"] != "CYCLES":
                log("  EEVEE render failed -> Cycles: " + traceback.format_exc().splitlines()[-1])
                engine_state["engine"] = "CYCLES"
                setup_cycles = bpy.context.scene
                setup_cycles.render.engine = "CYCLES"
                setup_cycles.cycles.samples = 24
                setup_cycles.cycles.use_denoising = True
                render_to(scene, tmp)
            else:
                raise
        return fr

    # 1) the four sides by axis
    side = {}
    for ax, az in AXES.items():
        fr = shoot(ax, az, EL_SIDE)
        p = os.path.join(odir, "_axis_%s.png" % ax.replace("+", "p").replace("-", "n"))
        os.replace(tmp, p)
        side[ax] = (p, fr, az)
    # 2) which side is the front
    prior, why = prior_axis(glb)
    scores = {}
    img2 = resolve(item.get("image_2d"))
    if img2:
        try:
            a2 = load_rgba(img2)
            s2 = signature(a2[..., :3], bg_mask_2d(a2))
            if s2 is not None:
                for ax, (p, fr, az) in side.items():
                    ar = load_rgba(p)
                    sr = signature(ar[..., :3] * ar[..., 3:4] + BG * (1 - ar[..., 3:4]), ar[..., 3] > 0.5)
                    if sr is not None:
                        sc, iou, corr = match(s2, sr)
                        scores[ax] = {"score": round(sc, 4), "iou": round(iou, 3), "corr": round(corr, 3)}
        except Exception:
            meta["match_error"] = traceback.format_exc().splitlines()[-1]
    front = prior
    rule = why
    uncertain = True
    if scores:
        rank = sorted(scores, key=lambda k: -scores[k]["score"])
        best = rank[0]
        ps = scores.get(prior, {"score": -1})["score"]
        margin = scores[best]["score"] - scores[rank[1]]["score"] if len(rank) > 1 else 1.0
        if best != prior and scores[best]["score"] - ps >= AUTO_MARGIN:
            front = best
            rule = "auto: best match to the 2D (%s %.3f vs name rule %s %.3f)" % (best, scores[best]["score"], prior, ps)
            uncertain = False
        else:
            rule = why + ("; 2D match agrees" if best == prior else
                          "; 2D match prefers %s by only %.3f (kept)" % (best, scores[best]["score"] - ps))
            uncertain = best != prior  # the 2D prefers another side (by < AUTO_MARGIN)
        meta["match_margin_top2"] = round(margin, 4)
    else:
        rule = why + "; no 2D match available"
    if name in MANUAL or sname in MANUAL:
        front = MANUAL.get(name) or MANUAL.get(sname)
        rule = "manual: set after looking at all 4 sides vs the 2D (%s)" % rule
        uncertain = False
    meta["front_uncertain"] = uncertain
    faz = AXES[front]
    order = {"front": faz, "right": faz + 90.0, "back": faz + 180.0, "left": faz - 90.0}
    inv = {}
    for v, az in order.items():
        azn = az % 360.0
        ax = min(AXES, key=lambda k: abs(((AXES[k] - azn + 180) % 360) - 180))
        inv[v] = ax
    meta.update({"front_axis": front, "front_rule": rule, "prior_axis": prior, "match": scores,
                 "view_axes": inv})
    front_a = None
    for v, ax in inv.items():
        p, fr, az = side[ax]
        out = os.path.join(odir, v + ".png")
        a = composite(p, out, keep_mask=os.path.join(odir, "front_mask.png") if v == "front" else None)
        if v == "front":
            front_a = a
            meta["front_frame"] = fr
        os.remove(p)
    # 3) 3/4 view (front-right, from above)
    fr = shoot("q34", faz + 45.0, EL_Q34)
    composite(tmp, os.path.join(odir, "q34.png"))
    os.remove(tmp)
    # 4) detail: 2x zoom of the busiest half-frame window of the front render (default: upper third, centred)
    ff = meta["front_frame"]
    win = RES // 2
    bxy, bs = busiest_window(front_a, win)
    if bxy is None:
        cx_px, cy_px, how = RES / 2.0, RES * 0.70, "default upper third"
    else:
        cx_px, cy_px, how = bxy[0] + win / 2.0, bxy[1] + win / 2.0, "most inner edges"
    sc = ff["scale"]
    R, U, M = Vector(ff["right"]), Vector(ff["up"]), Vector(ff["mid"])
    aim = M + R * ((cx_px / RES - 0.5) * sc) + U * ((cy_px / RES - 0.5) * sc)
    fr = shoot("detail", faz, EL_SIDE, aim=aim, fixed_scale=sc / 2.0)
    composite(tmp, os.path.join(odir, "detail.png"))
    os.remove(tmp)
    # image rows are bottom-up in Blender: store the window in top-down pixel coords for the sheet
    meta["detail_window_px"] = [int(cx_px - win / 2), int(RES - (cy_px + win / 2)), win, win]
    meta["detail_how"] = how
    meta["engine"] = engine_state["engine"]
    meta["render_s"] = round(time.time() - t0, 1)
    meta["status"] = "ok"
    json.dump(meta, open(os.path.join(odir, "meta.json"), "w", encoding="utf-8"), indent=1)
    return "ok", "front %s (%s) tris %d mats %d %.1fs" % (front, rule.split(":")[0], tris, len(mats), meta["render_s"])


def main():
    data = json.load(open(LIST, encoding="utf-8"))
    items = data["render"] if isinstance(data, dict) else data
    if ONLY:
        items = [i for i in items if i["name"] in ONLY or safe_name(i["name"]) in ONLY]
    items = items[START:]
    if COUNT:
        items = items[:COUNT]
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    eng = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else ("BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines
                                                               else "CYCLES")
    state = {"engine": eng}
    log("start %d items, engine %s, res %d, blender %s" % (len(items), eng, RES, bpy.app.version_string))
    t_all = time.time()
    n_ok = n_fail = 0
    for k, it in enumerate(items):
        try:
            st, msg = do_model(it, state)
        except Exception:
            st, msg = "fail", traceback.format_exc().strip().splitlines()[-1]
            try:
                d = os.path.join(OUT, safe_name(it["name"]))
                os.makedirs(d, exist_ok=True)
                json.dump({"name": it["name"], "status": "fail", "error": traceback.format_exc()},
                          open(os.path.join(d, "meta.json"), "w", encoding="utf-8"), indent=1)
            except Exception:
                pass
        n_ok += st in ("ok", "skip")
        n_fail += st not in ("ok", "skip")
        log("%3d/%d %-5s %s | %s" % (k + 1, len(items), st, it["name"], msg))
    log("done ok %d fail %d in %.1f min" % (n_ok, n_fail, (time.time() - t_all) / 60))


main()
