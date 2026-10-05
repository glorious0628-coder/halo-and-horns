"""
Convert a Tripo retarget GLB clip into a Luau data module for the client bone player (no Roblox animation upload).

  py tools/glb_anim_to_luau.py <clip.glb> <Monster> <Clip> [--fps 15] [--loop] [--from SEC] [--to SEC]
  (--from/--to keep only the useful part: Tripo presets are long, e.g. hurt 14 s, slash 6.6 s)

Writes src/ReplicatedStorage/MonsterAnims/<Monster>_<Clip>.luau returning
  { Fps = n, Frames = n, Loop = bool, Bones = { [boneName] = { r = {qx,qy,qz,qw, ...}, p = {x,y,z, ...}? } } }
Each frame holds Bone.Transform = restLocal^-1 * animLocal (glTF local TRS; the Studio importer keeps the same
local values, checked 2026-10-06 on the goblin). Only bones that actually move are written; translation only where
it moves (hips bob). Scale channels are ignored (Roblox bones ignore scale).
"""
import json
import math
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "src", "ReplicatedStorage", "MonsterAnims")
COMP = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def load_glb(path):
    data = open(path, "rb").read()
    length = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20:20 + length])
    off = 20 + length
    blen = struct.unpack("<I", data[off:off + 4])[0]
    binary = data[off + 8:off + 8 + blen]
    return gltf, binary


def accessor(gltf, binary, index):
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    fmt, size = COMP[acc["componentType"]]
    n = NCOMP[acc["type"]]
    stride = view.get("byteStride") or size * n
    base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    out = []
    for i in range(acc["count"]):
        start = base + i * stride
        vals = struct.unpack("<" + fmt * n, binary[start:start + size * n])
        if acc.get("normalized") and fmt != "f":
            vals = tuple(v / float((1 << (8 * size - (1 if fmt.islower() else 0))) - 1) for v in vals)
        out.append(vals if n > 1 else vals[0])
    return out


def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw,
            aw * bw - ax * bx - ay * by - az * bz)


def qinv(q):
    x, y, z, w = q
    return (-x, -y, -z, w)


def qrot(q, v):
    x, y, z = qmul(qmul(q, (v[0], v[1], v[2], 0.0)), qinv(q))[:3]
    return (x, y, z)


def slerp(a, b, t):
    dot = sum(x * y for x, y in zip(a, b))
    if dot < 0:
        b = tuple(-x for x in b)
        dot = -dot
    if dot > 0.9995:
        r = tuple(x + (y - x) * t for x, y in zip(a, b))
    else:
        th = math.acos(dot)
        s = math.sin(th)
        r = tuple((math.sin((1 - t) * th) * x + math.sin(t * th) * y) / s for x, y in zip(a, b))
    n = math.sqrt(sum(x * x for x in r)) or 1.0
    return tuple(x / n for x in r)


def sample(times, values, interp, t, is_quat):
    if t <= times[0]:
        return values[0]
    if t >= times[-1]:
        return values[-1]
    for i in range(len(times) - 1):
        if times[i] <= t <= times[i + 1]:
            if interp == "STEP":
                return values[i]
            u = (t - times[i]) / max(1e-9, times[i + 1] - times[i])
            if is_quat:
                return slerp(values[i], values[i + 1], u)
            return tuple(a + (b - a) * u for a, b in zip(values[i], values[i + 1]))
    return values[-1]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    path, monster, clip = args[0], args[1], args[2]
    fps = 15
    if "--fps" in sys.argv:
        fps = int(sys.argv[sys.argv.index("--fps") + 1])
        args = [a for a in args if a != str(fps)]
    loop = "--loop" in sys.argv

    def secs(flag):
        return float(sys.argv[sys.argv.index(flag) + 1]) if flag in sys.argv else None
    t_from, t_to = secs("--from"), secs("--to")
    args = [a for a in args if a not in {sys.argv[sys.argv.index(f) + 1] for f in ("--from", "--to") if f in sys.argv}]
    gltf, binary = load_glb(path)
    nodes = gltf["nodes"]
    skin = gltf["skins"][0]
    joint_set = set(skin["joints"])
    anim = gltf["animations"][0]
    tracks = {}  # node -> {"rotation": (times, vals, interp), "translation": ...}
    length = 0.0
    for ch in anim["channels"]:
        node, prop = ch["target"]["node"], ch["target"]["path"]
        if node not in joint_set or prop not in ("rotation", "translation"):
            continue
        smp = anim["samplers"][ch["sampler"]]
        times = accessor(gltf, binary, smp["input"])
        vals = accessor(gltf, binary, smp["output"])
        tracks.setdefault(node, {})[prop] = (times, vals, smp.get("interpolation", "LINEAR"))
        length = max(length, times[-1])
    start = max(0.0, t_from or 0.0)
    stop = min(length, t_to) if t_to else length
    length = max(0.1, stop - start)
    frames = max(2, int(round(length * fps)) + 1)
    bones = {}
    for node, tr in tracks.items():
        name = nodes[node].get("name")
        if not name or name == "Root":  # the importer re-bases the armature root
            continue
        rest_r = tuple(nodes[node].get("rotation", (0, 0, 0, 1)))
        rest_t = tuple(nodes[node].get("translation", (0, 0, 0)))
        inv = qinv(rest_r)
        rs, ps, moved_r, moved_p = [], [], False, False
        for f in range(frames):
            t = start + min(length, f / fps)
            r = sample(*tr["rotation"], t, True) if "rotation" in tr else rest_r
            p = sample(*tr["translation"], t, False) if "translation" in tr else rest_t
            dq = qmul(inv, r)  # Transform rotation
            if dq[3] < 0:
                dq = tuple(-x for x in dq)
            dp = qrot(inv, tuple(a - b for a, b in zip(p, rest_t)))  # Transform position (rest space)
            if abs(dq[3]) < 0.99995:
                moved_r = True
            if math.sqrt(sum(x * x for x in dp)) > 1e-4:
                moved_p = True
            rs.extend(dq)
            ps.extend(dp)
        if moved_r or moved_p:
            entry = {"r": rs}
            if moved_p:
                entry["p"] = ps
            bones[name] = entry

    def nums(values):
        return ",".join(("%.4f" % v).rstrip("0").rstrip(".").replace("-0", "-0") if v != 0 else "0" for v in values)

    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, f"{monster}_{clip}.luau")
    lines = [f"-- generated by tools/glb_anim_to_luau.py from {os.path.relpath(path, ROOT).replace(os.sep, '/')} -- do not edit",
             f"return {{ Fps = {fps}, Frames = {frames}, Loop = {'true' if loop else 'false'}, Bones = {{"]
    for name in sorted(bones):
        e = bones[name]
        part = f'\t["{name}"] = {{ r = {{ {nums(e["r"])} }}'
        if "p" in e:
            part += f', p = {{ {nums(e["p"])} }}'
        lines.append(part + " },")
    lines.append("} }")
    open(out, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    print(f"{os.path.relpath(out, ROOT)}: {len(bones)} bones, {frames} frames @ {fps}fps, {os.path.getsize(out) // 1024}KB")


if __name__ == "__main__":
    main()
