"""tripo_kits_gen.py (이미지 생성 3, 10/13): write build/wk/tripo_kits_build_<tag>.luau = tools/worldkit/tripo_kits_build.luau with
its kit table K replaced by the given models (SA ids from art/ui/asset_ids.json SA_<name>_C/N/M/R, DoubleSided from the
source GLB material, `--two` forces it on). Run the result in WorldKit (STUDIO_NAME=WorldKit, Edit) after the user's 3D import
(Workspace.<name>_TU).

  py tools/worldkit/tripo_kits_gen.py <tag> <name> [<name> ...] [--two A,B] [--sa-from NAME=OTHER,...]
--sa-from: use another model's SA ids (e.g. a mirrored twin). Missing ids -> the kit is left out and listed.
"""
import json
import os
import re
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEMPLATE = os.path.join(ROOT, "tools", "worldkit", "tripo_kits_build.luau")


def glb_double_sided(name):
    p = os.path.join(ROOT, "art", "models", "tripo", "touchup", name, name + "_TU.glb")
    if not os.path.exists(p):
        return False
    f = open(p, "rb").read(1 << 22)
    jl = struct.unpack("<I", f[12:16])[0]
    g = json.loads(f[20:20 + jl])
    return any(m.get("doubleSided") for m in g.get("materials", []))


def main():
    args = [a for a in sys.argv[1:]]
    two, sa_from = set(), {}
    if "--two" in args:
        i = args.index("--two"); two = set(args[i + 1].split(",")); del args[i:i + 2]
    if "--sa-from" in args:
        i = args.index("--sa-from")
        sa_from = dict(kv.split("=") for kv in args[i + 1].split(",")); del args[i:i + 2]
    tag, names = args[0], args[1:]
    ids = json.load(open(os.path.join(ROOT, "art", "ui", "asset_ids.json"), encoding="utf-8"))
    rows, missing = [], []
    for n in names:
        src = sa_from.get(n, n)
        v = [ids.get("SA_%s_%s" % (src, t)) for t in "CNMR"]
        if not all(v):
            missing.append(n)
            continue
        ds = n in two or glb_double_sided(src)
        rows.append('  {"%s", "%s", "%s", "%s", "%s", %s},' % (n, *v, "true" if ds else "false"))
    src = open(TEMPLATE, encoding="utf-8").read()
    src = re.sub(r"local K = \{\n.*?\n\}\n", "local K = {\n" + "\n".join(rows) + "\n}\n", src, count=1, flags=re.S)
    out = os.path.join(ROOT, "build", "wk", "tripo_kits_build_%s.luau" % tag)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    open(out, "w", encoding="utf-8", newline="\n").write(src)
    print("%d kits -> %s" % (len(rows), out))
    if missing:
        print("missing SA ids:", ", ".join(missing))


if __name__ == "__main__":
    main()
