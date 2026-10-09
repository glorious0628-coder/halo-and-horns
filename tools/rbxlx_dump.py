"""List instances of a saved .rbxlx under a path (name, class, position, size, yaw): py tools/rbxlx_dump.py build/GoodEvil.rbxlx Map/Decor [--depth 2] [--name REGEX]"""
import math
import re
import sys
import xml.etree.ElementTree as ET


def nm(it):
    p = it.find("Properties")
    if p is not None:
        for e in p.findall("string"):
            if e.get("name") == "Name":
                return e.text or ""
    return ""


def cf(it):
    p = it.find("Properties")
    if p is None:
        return None
    for e in p.findall("CoordinateFrame"):
        if e.get("name") == "CFrame":
            g = lambda k: float(e.find(k).text)
            return g("X"), g("Y"), g("Z"), g("R00"), g("R02")
    return None


def size(it):
    p = it.find("Properties")
    if p is None:
        return None
    for e in p.findall("Vector3"):
        if e.get("name") in ("size", "Size"):
            return float(e.find("X").text), float(e.find("Y").text), float(e.find("Z").text)
    return None


def bbox(it):
    """axis-aligned bbox of every descendant part (position +- half the size, rotation ignored): centre, size, yaw of the first part"""
    lo, hi, yaw = [1e9] * 3, [-1e9] * 3, None
    n = 0
    for d in it.iter("Item"):
        p, s = cf(d), size(d)
        if p and s:
            n += 1
            if yaw is None:
                yaw = math.degrees(math.atan2(-p[4], p[3]))
            for i in range(3):
                h = max(s) / 2 if False else s[i] / 2
                lo[i] = min(lo[i], p[i] - h)
                hi[i] = max(hi[i], p[i] + h)
    if not n:
        return None
    return [(lo[i] + hi[i]) / 2 for i in range(3)], [hi[i] - lo[i] for i in range(3)], yaw or 0, n


def find(parent, path):
    for part in path:
        parent = next((c for c in parent.findall("Item") if nm(c) == part), None)
        if parent is None:
            raise SystemExit("not found: " + part)
    return parent


def main():
    a = sys.argv[1:]
    f, path = a[0], [p for p in a[1].split("/") if p]
    depth = int(a[a.index("--depth") + 1]) if "--depth" in a else 1
    rx = re.compile(a[a.index("--name") + 1]) if "--name" in a else None
    root = ET.parse(f).getroot()
    ws = next(i for i in root.findall("Item") if i.get("class") == "Workspace")
    node = find(ws, path)

    def walk(it, d, pre):
        for c in it.findall("Item"):
            n = nm(c)
            if rx is None or rx.search(n):
                p, s = cf(c), size(c)
                yaw = math.degrees(math.atan2(-p[4], p[3])) if p else 0
                if p is None and c.get("class") == "Model":
                    b = bbox(c)
                    if b:
                        print(f"{pre}{n} [Model] centre=({b[0][0]:.1f},{b[0][1]:.1f},{b[0][2]:.1f}) size=({b[1][0]:.1f},{b[1][1]:.1f},{b[1][2]:.1f}) yaw0={b[2]:.0f} parts={b[3]}")
                        if d < depth:
                            walk(c, d + 1, pre + "  ")
                        continue
                print(f"{pre}{n} [{c.get('class')}]" + (f" pos=({p[0]:.1f},{p[1]:.1f},{p[2]:.1f}) yaw={yaw:.0f}" if p else "") + (f" size=({s[0]:.1f},{s[1]:.1f},{s[2]:.1f})" if s else ""))
            if d < depth:
                walk(c, d + 1, pre + "  ")

    walk(node, 1, "")


main()
