"""Fill tools/worldkit/tripo_parts_kit.luau for one multi-material kit -> build/wk/tripo_parts_kit_<NAME>.luau (이미지 생성 3, 10/14).
  py tools/worldkit/tripo_parts_kit_gen.py <NAME> <height_studs> [--two 0,1]
SA ids = art/ui/asset_ids.json SA_<NAME>_m<k>_{C,N,M,R}."""
import json, os, re, sys
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
a = sys.argv[1:]
two = set()
if "--two" in a:
    i = a.index("--two"); two = {int(x) for x in a[i + 1].split(",")}; del a[i:i + 2]
name, h = a[0], a[1]
ids = json.load(open(os.path.join(ROOT, "art", "ui", "asset_ids.json"), encoding="utf-8"))
ks = sorted({int(m.group(1)) for k in ids for m in [re.match(r"SA_%s_m(\d+)_C$" % re.escape(name), k)] if m})
sa = ",\n  ".join('[%d] = {"%s", "%s", "%s", "%s"}' % (k, *[ids["SA_%s_m%d_%s" % (name, k, t)] for t in "CNMR"]) for k in ks)
src = open(os.path.join(ROOT, "tools", "worldkit", "tripo_parts_kit.luau"), encoding="utf-8").read()
src = src.replace("@NAME@", name).replace("@H@", h).replace("@SA@", "{\n  " + sa + "\n}")
src = src.replace("@TWO@", "{" + ", ".join("[%d] = true" % k for k in sorted(two)) + "}")
out = os.path.join(ROOT, "build", "wk", "tripo_parts_kit_%s.luau" % name)
open(out, "w", encoding="utf-8", newline="\n").write(src)
print("materials", ks, "->", out)
