"""List the props / decorations placed under Workspace.HaloV2 in a saved WorldKit place (이미지 생성 3, 10/12), without Studio.

  py tools/wk_placed_props.py [build/WorldKit.rbxlx] [--out docs/design/halo_v2_placed_props_<date>.md]

Streams the .rbxlx XML (iterparse, elements cleared as they close - the file is ~230 MB) and keeps a light tree of every
Item under Workspace.HaloV2 (class, name, child count, BasePart count). Report: the folders under HaloV2; every Model /
MeshPart prop under the prop folders (name -> count, Tripo vs part kit guessed from MeshPart / SurfaceAppearance inside);
for HaloV2.Buildings: per building the decoration models (anything that is not the Studio part skeleton *_Skeleton /
House07_Fixed skeleton parts) with their part names. Skeleton parts are not listed.
"""
import collections
import os
import re
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
args = [x for x in sys.argv[1:] if not x.startswith("--")]
src = args[0] if args else os.path.join(ROOT, "build", "WorldKit.rbxlx")
out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else os.path.join(ROOT, "docs", "design", "halo_v2_placed_props_2026-10-12.md")


class N:
    __slots__ = ("cls", "name", "kids", "parent", "parts", "mesh", "sa")

    def __init__(self, cls, parent):
        self.cls, self.name, self.kids, self.parent = cls, "", [], parent
        self.parts = self.mesh = self.sa = 0


stack = []
roots = []
depth_items = 0
for ev, el in ET.iterparse(src, events=("start", "end")):
    tag = el.tag
    if ev == "start":
        if tag == "Item":
            n = N(el.get("class"), stack[-1] if stack else None)
            stack.append(n)
        continue
    if tag == "string" and el.get("name") == "Name" and stack:
        t_ = el.text or ""
        try:
            t_ = t_.encode("latin-1").decode("utf-8")      # Roblox's XML names come back as UTF-8 bytes read as latin-1
        except (UnicodeEncodeError, UnicodeDecodeError):
            pass
        stack[-1].name = t_
        el.clear()
    elif tag == "Item":
        n = stack.pop()
        # keep only what lies under Workspace > HaloV2 (decide when the chain is known)
        chain = []
        p = n
        while p is not None:
            chain.append((p.cls, p.name))
            p = p.parent
        chain.reverse()
        under = len(chain) >= 2 and chain[0][0] == "Workspace" and chain[1][1] == "HaloV2"
        if n.cls in ("Part", "MeshPart", "UnionOperation", "WedgePart", "CornerWedgePart", "TrussPart"):
            q = n.parent
            while q is not None:
                q.parts += 1
                if n.cls == "MeshPart":
                    q.mesh += 1
                q = q.parent
        if n.cls == "SurfaceAppearance":
            q = n.parent
            while q is not None:
                q.sa += 1
                q = q.parent
        if under and n.parent is not None:
            n.parent.kids.append(n)
        elif n.cls == "Workspace":
            roots.append(n)
        el.clear()
    elif tag in ("Properties",):
        el.clear()

ws = roots[0] if roots else None
hv = None
if ws:
    for k in ws.kids:
        if k.name == "HaloV2":
            hv = k
if hv is None:
    # HaloV2 itself is under Workspace: its node was appended to Workspace only if 'under' - look it up by parents
    sys.exit("[props] Workspace.HaloV2 not found in " + src)
L = ["# WorldKit HaloV2에 지금 놓인 소품·장식 (이미지 생성 3, 2026-10-12)", "",
     "출처: `%s` (저장 시각 %s), Studio 없이 파일 파싱(`py tools/wk_placed_props.py`). 골격 파트(Studio 파트 집·성 골격)는 빼고 소품·장식 모델만." % (
         os.path.relpath(src, ROOT).replace("\\", "/"), __import__("time").strftime("%Y-%m-%d %H:%M", __import__("time").localtime(os.path.getmtime(src)))),
     "", "## HaloV2 아래 폴더", "", "| 폴더 | 종류 | 바로 아래 개수 | 파트 수 |", "|---|---|---|---|"]
for k in hv.kids:
    L.append("| %s | %s | %d | %d |" % (k.name, k.cls, len(k.kids), k.parts))
SKEL = re.compile(r"(_Skeleton$|^House07_Fixed$|^House07_Skeleton$)")


def kind(n):
    if n.mesh and n.sa:
        return "Tripo/메시(맵 있음)"
    if n.mesh:
        return "메시"
    return "파트 키트"


for k in hv.kids:
    if k.name != "Props":                       # Ground / Bridges / Markers = world structure, not props (folder table above)
        continue
    cnt = collections.Counter()
    kinds = {}
    where = collections.defaultdict(set)

    def walk(n, path):
        for c in n.kids:
            if c.cls == "Folder":
                walk(c, path + [c.name])
            elif c.cls in ("Model", "MeshPart", "Part", "UnionOperation"):
                base = re.sub(r"_\d+$", "", re.sub(r"^[A-Z]\d+_", "", c.name))   # P001_ / L01_ = the placement number
                cnt[base] += 1
                kinds[base] = kind(c)
                where[base].add("/".join(path) or "-")
    walk(k, [])
    if not cnt:
        continue
    L += ["", "## %s (%d개, %d종)" % (k.name, sum(cnt.values()), len(cnt)), "", "| 이름 | 개수 | 만든 방식(추정) | 폴더 |", "|---|---|---|---|"]
    for nm, v in sorted(cnt.items(), key=lambda x: (-x[1], x[0])):
        L.append("| %s | %d | %s | %s |" % (nm, v, kinds[nm], ", ".join(sorted(where[nm]))))
B = next((k for k in hv.kids if k.name == "Buildings"), None)
if B:
    L += ["", "## Buildings — 건물마다 골격 말고 붙은 장식", "", "| 건물 | 골격 | 장식 모델 | 장식 부품(이름 · 개수) |", "|---|---|---|---|"]
    for b in sorted(B.kids, key=lambda x: x.name):
        sk = [c.name for c in b.kids if SKEL.search(c.name)]
        deco = [c for c in b.kids if not SKEL.search(c.name)]
        if not sk:                              # a whole-part building (tools/skeleton_civic.py) or a gray blockout: no decoration
            what = "회색 덩어리(아직 골격 전)" if b.parts <= 15 else "통째 파트 골격(skeleton_civic, 장식 따로 없음)"
            L.append("| %s | %s | - | 파트 %d개 |" % (b.name, what, b.parts))
            continue
        parts = collections.Counter()
        for d in deco:
            stackn = [d]
            while stackn:
                q = stackn.pop()
                if q.cls in ("Part", "MeshPart", "UnionOperation"):
                    parts[re.sub(r"\d+$", "", q.name.split("_", 2)[-1] if q.name.startswith(("HaloDomeHouse_", "HaloShop_", "HaloNewHouse_")) else q.name)] += 1
                stackn.extend(q.kids)
        L.append("| %s | %s | %s | %s |" % (b.name, ", ".join(sk) or "-", ", ".join(d.name for d in deco) or "-",
                                             ", ".join("%s %d" % kv for kv in sorted(parts.items())) or "-"))
open(out, "w", encoding="utf-8", newline="\n").write("\n".join(L) + "\n")
print("[props]", len(hv.kids), "folders ->", out)
