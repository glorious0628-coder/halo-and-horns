"""Studio skeletons for the Halo civic buildings (이미지 생성 1, 2026-10-11, SPEC A23-120/121 stage ④): gate, the two towers, the armory.

  py tools/skeleton_civic.py [--only Gate,Tower_GateEast,...] [--mode build|remove] [--out build/skeleton_civic.luau]

Reads docs/design/halo_plan_v2_2026-10-11.json (position, yaw, ground_y of each building) and writes one WorldKit Luau script
(run it with tools/worldkit/skeleton_civic_run.py or studio_mcp execute_luau, Edit mode, WorldKit only):
  * every piece is a Part or a CSG result (SubtractAsync / UnionAsync: arches, doors, windows and the hollow insides are real
    holes; collision PreciseConvexDecomposition so the 16 x 30 gate passage and the doors can be walked through);
  * marble = Marble + MaterialVariant HH_HaloMarbleBlock_Cream + (255,244,222), gold = Metal + HH_HaloGoldTrim + GOLD_RGB
    (house 07 method, 이미지 개발); the blue tile roof of the armory is a plain blue stand-in (the roof piece comes in stage 5);
  * building-local frame as in tools/skeleton_house07.py: x right, y = the door side (front), z up; the model is placed with
    CFrame.new(x, ground_y, z) * Angles(0, yaw + pi, 0) like the grey boxes of tools/halo_blockout.py;
  * the models replace the grey boxes in Workspace.HaloV2.Buildings (the grey ones go to ServerStorage.HaloGrayHold) and a master
    copy stays in ServerStorage.HaloSkeletons, which tools/worldkit/halo_blockout.luau clones on a rebuild (same plan pose only).
Proportions: art/out/s2/halo/HaloProp_Gate_front_HQ_src.png / HaloProp_Tower_v2_front_HQ_src.png measured row by row (10/11).
The armory has no 2D yet: it follows the house / shop language (cream marble, gold bands, blue tile roof, arched door).
"""
import argparse
import json
import math
import os

ap = argparse.ArgumentParser()
ap.add_argument("--only", default="")
ap.add_argument("--mode", default="build", choices=["build", "remove"])
ap.add_argument("--out", default="build/skeleton_civic.luau")
args = ap.parse_args()
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLAN = json.load(open(os.path.join(ROOT, "docs", "design", "halo_plan_v2_2026-10-11.json"), encoding="utf-8"))
BLD = {b["id"]: b for b in PLAN["buildings"]}
MARBLE_VARIANT = "HH_HaloMarbleBlock_Cream"
MARBLE_RGB = (255, 244, 222)
GOLD_RGB = (255, 175, 25)       # 검수 10/11 (house 07 used 240,186,56)
ROOF_RGB = (90, 163, 250)       # the blue of HaloDomeHouse_07_roof_v2 (median of its roof pixels)
UP = (0.0, 0.0, 1.0)


def fm(v):
    s = ("%.4f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("", "-0") else s


def S(kind, size, pos, X, Y):
    return "S(%s)" % ",".join(['"%s"' % kind] + [fm(v) for v in (*size, *pos, *X, *Y)])


# ---- shape constructors (building-local frame: x, y = front, z up)
def box(cx, cy, zc, w, d, h, t=0.0):
    """axis-aligned block (w along x, d along y, h up); t = turn about z in radians"""
    return S("box", (w, d, h), (cx, cy, zc), (math.cos(t), math.sin(t), 0), (-math.sin(t), math.cos(t), 0))


def zbox(cx, cy, z0, z1, w, d, t=0.0):
    return box(cx, cy, (z0 + z1) / 2, w, d, z1 - z0, t)


def rbox(cx, cy, zc, w, d, h, phi):
    """block whose depth axis (d) points radially at angle phi (from +x, counter-clockwise; front = 90 deg)"""
    return S("box", (w, d, h), (cx, cy, zc), (math.sin(phi), -math.cos(phi), 0), (math.cos(phi), math.sin(phi), 0))


def cylz(cx, cy, z0, z1, dia):
    """upright cylinder"""
    return S("cyl", (z1 - z0, dia, dia), (cx, cy, (z0 + z1) / 2), UP, (1, 0, 0))


def cyld(cx, cy, zc, dia, length, dx, dy):
    """horizontal cylinder along (dx, dy)"""
    return S("cyl", (length, dia, dia), (cx, cy, zc), (dx, dy, 0), UP)


def ball(cx, cy, zc, dia):
    return S("ball", (dia, dia, dia), (cx, cy, zc), (1, 0, 0), (0, 1, 0))


def wedge(cx, cy, zc, thick, h, base, zdir):
    """right-triangle prism: tall edge at the +Z end (WorldKit test 10/11: slope rises toward local +Z); zdir = 'toward' (-y) / (+y)"""
    if zdir < 0:
        return S("wedge", (thick, h, base), (cx, cy, zc), (1, 0, 0), (0, 0, 1))
    return S("wedge", (thick, h, base), (cx, cy, zc), (-1, 0, 0), (0, 0, 1))


class Scene:
    def __init__(self, bid):
        self.bid = bid
        self.L = []
        self.n = 0

    def piece(self, name, style, base, adds=(), cuts=(), **flags):
        fl = ""
        if flags:
            fl = ",{%s}" % ",".join("%s=%s" % (k, ("true" if v is True else "false" if v is False else fm(v) if isinstance(v, (int, float)) else '"%s"' % v))
                                    for k, v in flags.items())
        self.L.append('piece("%s","%s",%s,{%s},{%s}%s)' % (name, style, base, ",".join(adds), ",".join(cuts), fl))
        self.n += 1


def tube(sc, name, style, cx, cy, z0, z1, d_out, d_in, cuts=(), adds=(), **fl):
    sc.piece(name, style, cylz(cx, cy, z0, z1, d_out), adds, [cylz(cx, cy, z0 - 0.1, z1 + 0.1, d_in), *cuts], **fl)


def ring_h(sc, name, style, cx, cy, zc, d_out, d_in, th, **fl):
    """flat horizontal ring"""
    sc.piece(name, style, cylz(cx, cy, zc - th / 2, zc + th / 2, d_out), (), [cylz(cx, cy, zc - th, zc + th, d_in)], **fl)


def arch_cut(cx, cy, phi, z0, w, hs, depth, rc):
    """arched opening (w wide, straight part hs, round top) through a wall whose normal is phi; rc = radial centre of the cutter"""
    px, py = cx + math.cos(phi) * rc, cy + math.sin(phi) * rc
    return [rbox(px, py, z0 + hs / 2, w, depth, hs, phi), cyld(px, py, z0 + hs, w, depth, math.cos(phi), math.sin(phi))]


def arch_frame(sc, name, style, cx, cy, phi, z0, w, hs, border, depth, rc, bottom=True):
    """arched frame ring: outer w + 2 border, hole w; centre radius rc, thickness depth"""
    px, py = cx + math.cos(phi) * rc, cy + math.sin(phi) * rc
    wo = w + 2 * border
    top = z0 + hs
    base = rbox(px, py, z0 + hs / 2, wo, depth, hs, phi)
    adds = [cyld(px, py, top, wo, depth, math.cos(phi), math.sin(phi))]
    cuts = [rbox(px, py, z0 + hs / 2 - (0.02 if bottom else -border), w, depth + 0.4, hs + (0.04 if bottom else 0), phi),
            cyld(px, py, top, w, depth + 0.4, math.cos(phi), math.sin(phi))]
    sc.piece(name, style, base, adds, cuts)


def pane(sc, name, style, cx, cy, phi, z0, w, hs, rc, th=0.15):
    px, py = cx + math.cos(phi) * rc, cy + math.sin(phi) * rc
    sc.piece(name, style, rbox(px, py, z0 + hs / 2, w, th, hs, phi), [cyld(px, py, z0 + hs, w, th, math.cos(phi), math.sin(phi))], ())


def dome(sc, pre, cx, cy, z_base, dia, finial_z):
    """gold dome (half ball, the lower half sits inside the cornice), neck, finial ball + spike"""
    sc.piece(pre + "Dome", "gold", ball(cx, cy, z_base, dia))
    sc.piece(pre + "Neck", "gold", cylz(cx, cy, finial_z - 0.55, finial_z + 0.25, 1.7))
    sc.piece(pre + "FinialBall", "gold", ball(cx, cy, finial_z + 0.65, 1.0))
    sc.piece(pre + "FinialSpike", "gold", cylz(cx, cy, finial_z + 0.9, finial_z + 2.2, 0.38))


def banner(sc, pre, cx, cy, phi, r_surface, w, z0, z1, rod_z):
    """hanging blue banner with a gold rod, gold side lines and a V of gold at the bottom, on the surface at radius r_surface"""
    rx, ry = cx + math.cos(phi) * (r_surface + 0.22), cy + math.sin(phi) * (r_surface + 0.22)
    tx, ty = math.sin(phi), -math.cos(phi)
    sc.piece(pre + "Cloth", "fabricB", rbox(rx, ry, (z0 + z1) / 2 + 0.3, w, 0.18, z1 - z0 - 0.6, phi), (), ())
    px, py = cx + math.cos(phi) * (r_surface + 0.4), cy + math.sin(phi) * (r_surface + 0.4)
    sc.piece(pre + "Rod", "gold", cyld(px, py, rod_z, 0.42, w + 1.6, tx, ty))
    for s, nm in ((-1, "End0"), (1, "End1")):
        sc.piece(pre + "Rod" + nm, "gold", ball(px + tx * s * (w + 1.6) / 2, py + ty * s * (w + 1.6) / 2, rod_z, 0.8))
    for s, nm in ((-1, "SideL"), (1, "SideR")):
        qx, qy = cx + math.cos(phi) * (r_surface + 0.34) + tx * s * (w / 2 - 0.12), cy + math.sin(phi) * (r_surface + 0.34) + ty * s * (w / 2 - 0.12)
        sc.piece(pre + nm, "gold", rbox(qx, qy, (z0 + z1) / 2 + 0.3, 0.26, 0.2, z1 - z0 - 0.6, phi))
    # swallow tail: two gold bars forming a V
    for s, nm in ((-1, "VL"), (1, "VR")):
        ang = math.radians(38 * s)
        bx, by = cx + math.cos(phi) * (r_surface + 0.36) + tx * s * (w / 4), cy + math.sin(phi) * (r_surface + 0.36) + ty * s * (w / 4)
        L = (w / 2) / math.cos(ang) * 0.98
        # the bar runs in the tangent-up plane: X = tangent * cos + up * sin
        X = (tx * math.cos(ang), ty * math.cos(ang), math.sin(ang))
        Y = (math.cos(phi), math.sin(phi), 0)
        sc.piece(pre + nm, "gold", S("box", (L, 0.2, 0.26), (bx, by, z0 + 0.15 + (w / 4) * math.tan(abs(ang))), X, Y))


def halo(sc, pre, cx, cy, zc, d_out):
    for k, (dd, dz) in enumerate(((d_out, 0.0), (d_out * 0.78, 0.32))):
        ring_h(sc, "%sHalo%d" % (pre, k), "gold", cx, cy, zc + dz, dd, dd - 0.9, 0.4, collide=False)


# =========================================================================================================== TOWER (prop)
def tower(sc, pre, cx, cy, door_phi, lookout=False):
    """HaloProp_Tower_v2 (art/out/s2/halo, measured: foot 12 wide, body 10.2, gallery ring, gold dome, halo). door_phi = the door side.
    lookout = the belvedere variant: the walled gallery becomes an open one (floor, parapet, 8 columns) so the top is a photo spot."""
    BORE = 8.4
    # sections: (name, z0, z1, d_out, style)
    tube(sc, pre + "Foot", "marble", cx, cy, -0.3, 1.0, 12.0, BORE, cuts=arch_cut(cx, cy, door_phi, -0.3, 4.0, 5.3, 4.0, 5.4))
    tube(sc, pre + "Base", "marble", cx, cy, 1.0, 8.2, 11.6, BORE, cuts=[
        *arch_cut(cx, cy, door_phi, -0.3, 4.0, 5.3, 4.0, 5.4),
        *[c for k in (-1, 1) for c in arch_cut(cx, cy, door_phi + k * math.radians(34), 1.5, 0.9, 2.6, 3.0, 5.0)]])
    tube(sc, pre + "PlinthGold", "gold", cx, cy, 8.2, 9.4, 12.2, BORE)
    tube(sc, pre + "Trans", "marble", cx, cy, 9.4, 11.5, 11.0, BORE)
    tube(sc, pre + "Body", "marble", cx, cy, 11.5, 29.9, 10.2, BORE)
    tube(sc, pre + "CorbelGold", "gold", cx, cy, 29.9, 31.6, 12.2, BORE)
    # door: gold frame, wood leaf (no collision), the gold blocks at the foot as in the 2D
    arch_frame(sc, pre + "DoorFrame", "gold", cx, cy, door_phi, 0.0, 4.0, 5.0, 0.7, 1.3, 5.45)
    sc.piece(pre + "DoorLeaf", "wood", rbox(cx + math.cos(door_phi) * 5.0, cy + math.sin(door_phi) * 5.0, 2.5, 3.7, 0.3, 5.0, door_phi),
             [cyld(cx + math.cos(door_phi) * 5.0, cy + math.sin(door_phi) * 5.0, 5.0, 3.7, 0.3, math.cos(door_phi), math.sin(door_phi))])
    for k in (-1, 1):
        a = door_phi + k * math.radians(21)
        sc.piece("%sDoorBlock%d" % (pre, k), "gold", rbox(cx + math.cos(a) * 5.85, cy + math.sin(a) * 5.85, 4.6, 1.5, 0.9, 3.6, a))
    for k in (-1, 1):  # slit frames
        a = door_phi + k * math.radians(34)
        arch_frame(sc, "%sSlitFrame%d" % (pre, k), "gold", cx, cy, a, 1.5, 0.9, 2.6, 0.3, 0.6, 5.9)
    if not lookout:
        tube(sc, pre + "Gallery", "marble", cx, cy, 31.6, 36.0, 11.6, BORE, cuts=[
            c for k in range(8) for c in arch_cut(cx, cy, math.radians(90 + 45 * k), 33.0, 1.2, 1.6, 3.2, 4.9)])
        for k in range(8):
            a = math.radians(90 + 45 * k)
            arch_frame(sc, "%sWinFrame%d" % (pre, k), "gold", cx, cy, a, 33.0, 1.2, 1.6, 0.28, 0.6, 5.95)
            pane(sc, "%sWinGlass%d" % (pre, k), "lamp", cx, cy, a, 33.0, 1.2, 1.6, 4.75)
        tube(sc, pre + "CorniceGold", "gold", cx, cy, 36.0, 36.9, 12.5, BORE)
        sc.piece(pre + "Ceiling", "marble", cylz(cx, cy, 35.6, 36.2, BORE + 0.2))
        dome(sc, pre, cx, cy, 36.9, 11.8, 42.7)
        halo(sc, pre, cx, cy, 45.7, 7.8)
    else:
        # open belvedere: floor on the corbel ring, parapet, eight columns, entablature, the same dome
        sc.piece(pre + "BalconyFloor", "marble", cylz(cx, cy, 31.6, 32.2, 12.4), tag="WalkGround")  # Config.Ground.Tag: the photo spot floor
        tube(sc, pre + "Parapet", "marble", cx, cy, 32.2, 34.4, 12.0, 11.0)
        tube(sc, pre + "ParapetRail", "gold", cx, cy, 34.4, 34.9, 12.4, 10.8)
        for k in range(8):
            a = math.radians(22.5 + 45 * k)
            px, py = cx + math.cos(a) * 5.3, cy + math.sin(a) * 5.3
            sc.piece("%sColumn%d" % (pre, k), "marble", cylz(px, py, 34.9, 39.6, 0.95))
            sc.piece("%sColumnFoot%d" % (pre, k), "gold", cylz(px, py, 34.9, 35.3, 1.35))
            sc.piece("%sColumnCap%d" % (pre, k), "gold", cylz(px, py, 39.2, 39.8, 1.4))
        tube(sc, pre + "Entablature", "marble", cx, cy, 39.8, 40.7, 12.2, 9.4)
        tube(sc, pre + "CorniceGold", "gold", cx, cy, 40.7, 41.6, 12.6, 9.0)
        dome(sc, pre, cx, cy, 41.6, 11.8, 47.4)
        halo(sc, pre, cx, cy, 50.4, 7.8)
    # banner above the door (front)
    banner(sc, pre + "Banner", cx, cy, door_phi, 5.1, 3.4, 16.2, 28.0, 28.4)


# =========================================================================================================== GATE
def gate(sc):
    W, D = 50.0, 16.0
    TX = 17.0                     # tower centres at +-17 (foot ring dia 16 reaches +-25)
    WALL_X, WALL_Y, WALL_T = 22.0, 10.0, 35.0
    # --- central wall with the 16 x 30 passage (box + half round top), through both faces
    sc.piece("Wall", "marble", zbox(0, 0, -0.3, WALL_T, WALL_X, WALL_Y), (), [
        zbox(0, 0, -1.0, 22.0, 16.0, 14.0), cyld(0, 0, 22.0, 16.0, 14.0, 0, 1)])
    # --- coping: gold cornice in three pieces; "Lintel" = the front half (centre y = +4 -> world z -330, MapBuilder anchor)
    sc.piece("Lintel", "gold", zbox(0, 4.0, WALL_T, WALL_T + 1.2, 23.6, 4.0))
    sc.piece("CorniceMid", "gold", zbox(0, 0, WALL_T, WALL_T + 1.2, 23.6, 4.0))
    sc.piece("LintelBack", "gold", zbox(0, -4.0, WALL_T, WALL_T + 1.2, 23.6, 4.0))
    # --- both faces: marble archivolt, gold arch ring, medallion with gold rim and boss, gold fret
    for s, nm in ((1, "F"), (-1, "B")):
        yc = s * 5.18
        # archivolt: marble ring r 9.2..10.6 (0.36 thick), gold ring r 8.0..9.2 (0.7 thick)
        sc.piece("Archivolt" + nm, "marble", zbox(0, yc, -0.3, 22.0, 21.2, 0.36), [cyld(0, yc, 22.0, 21.2, 0.36, 0, 1)],
                 [zbox(0, yc, -0.5, 22.0, 18.4, 0.8), cyld(0, yc, 22.0, 18.4, 0.8, 0, 1)])
        sc.piece("ArchGold" + nm, "gold", zbox(0, s * 5.3, -0.3, 22.0, 18.4, 0.7), [cyld(0, s * 5.3, 22.0, 18.4, 0.7, 0, 1)],
                 [zbox(0, s * 5.3, -0.5, 22.0, 16.0, 1.0), cyld(0, s * 5.3, 22.0, 16.0, 1.0, 0, 1)])
        sc.piece("MedalRim" + nm, "gold", cyld(0, s * 5.3, 33.0, 4.8, 0.8, 0, 1), (), [cyld(0, s * 5.3, 33.0, 4.0, 1.0, 0, 1)])
        sc.piece("MedalDisk" + nm, "marble", cyld(0, s * 5.2, 33.0, 4.1, 0.6, 0, 1))
        sc.piece("MedalBoss" + nm, "gold", cyld(0, s * 5.7, 33.0, 2.0, 0.7, 0, 1))
        for sx in (-1, 1):
            sc.piece("FretH%s%d" % (nm, sx), "gold", box(sx * 6.1, s * 5.2, 32.9, 3.4, 0.4, 0.4))
            sc.piece("FretV%s%d" % (nm, sx), "gold", box(sx * 7.9, s * 5.2, 33.7, 0.4, 0.4, 2.0))
    halo(sc, "Gate", 0, 0, WALL_T + 3.9, 9.6)
    # --- the two towers (diameter 14 body, 16 foot, gallery 15.4, gold domes), hollow, banners on both faces
    BORE = 12.2
    for sx, nm in ((-1, "L"), (1, "R")):
        cx = sx * TX
        pre = "T" + nm
        tube(sc, pre + "Foot", "marble", cx, 0, -0.3, 3.0, 16.0, BORE)
        tube(sc, pre + "Base", "marble", cx, 0, 3.0, 8.0, 15.0, BORE)
        tube(sc, pre + "PlinthGold", "gold", cx, 0, 8.0, 9.0, 15.6, BORE)
        tube(sc, pre + "Body", "marble", cx, 0, 9.0, 29.5, 14.0, BORE)
        tube(sc, pre + "CorbelGold", "gold", cx, 0, 29.5, 31.0, 15.6, BORE)
        # gallery with two square lit windows (front / back), gold frames
        wins = [(math.radians(90), "F"), (math.radians(270), "B")]
        tube(sc, pre + "Gallery", "marble", cx, 0, 31.0, 37.0, 15.4, BORE, cuts=[
            c for a, _ in wins for c in arch_cut(cx, 0, a, 32.6, 2.0, 1.9, 3.0, 7.0)])
        for a, wn in wins:
            arch_frame(sc, "%sWinFrame%s" % (pre, wn), "gold", cx, 0, a, 32.6, 2.0, 1.9, 0.34, 0.6, 7.75)
            pane(sc, "%sWinGlass%s" % (pre, wn), "lamp", cx, 0, a, 32.6, 2.0, 1.9, 6.4)
        tube(sc, pre + "CorniceGold", "gold", cx, 0, 37.0, 38.0, 16.2, BORE)
        sc.piece(pre + "Ceiling", "marble", cylz(cx, 0, 36.6, 37.2, BORE + 0.2))
        dome(sc, pre, cx, 0, 38.0, 15.4, 45.5)
        for a, wn in ((math.radians(90), "F"), (math.radians(270), "B")):
            banner(sc, "%sBanner%s" % (pre, wn), cx, 0, a, 7.0, 3.8, 14.0, 28.0, 28.5)


# =========================================================================================================== ARMORY
def armory(sc):
    W, D = 16.0, 12.0
    WH = 8.6                      # wall top (cornice top)
    # --- walls: hollow box, ceiling slab 0.6, door + windows through
    DOOR_W, DOOR_H = 5.0, 7.0
    cuts = [zbox(0, 0, -0.5, 8.0, W - 1.6, D - 1.6)]
    cuts += arch_cut(0, 0, math.radians(90), -0.3, DOOR_W, DOOR_H - DOOR_W / 2 + 0.3, 3.0, 5.9)
    wins = []
    for x in (-5.4, 5.4):
        wins.append((x, 6.0, math.radians(90)))
        wins.append((x * 0.8, -6.0, math.radians(270)))
    wins.append((8.0, 0.0, 0.0))
    wins.append((-8.0, 0.0, math.radians(180)))
    for x, y, phi in wins:
        # a point on the wall plane: cutter centre moved inward by 0.6 along the wall normal
        cuts += arch_cut(x - math.cos(phi) * 0.0, y - math.sin(phi) * 0.0, phi, 3.0, 2.0, 3.2, 3.0, -0.6)
    sc.piece("Walls", "marble", zbox(0, 0, -0.3, WH, W, D), (), cuts)
    # --- door: gold frame, wood leaf (no collision), threshold step
    arch_frame(sc, "DoorFrame", "gold", 0, 0, math.radians(90), 0.0, DOOR_W, DOOR_H - DOOR_W / 2, 0.7, 1.2, 6.15)
    dx, dy = 0, 5.55
    sc.piece("DoorLeaf", "wood", box(dx, dy, (DOOR_H - DOOR_W / 2) / 2, DOOR_W - 0.5, 0.3, DOOR_H - DOOR_W / 2),
             [cyld(dx, dy, DOOR_H - DOOR_W / 2, DOOR_W - 0.5, 0.3, 0, 1)])
    sc.piece("Threshold", "marble", zbox(0, 6.9, -0.3, 0.3, DOOR_W + 1.6, 1.8))
    # --- windows: gold frame + glass
    for k, (x, y, phi) in enumerate(wins):
        nx, ny = math.cos(phi), math.sin(phi)
        arch_frame(sc, "WinFrame%d" % k, "gold", x, y, phi, 3.0, 2.0, 3.2, 0.34, 0.5, 0.05)
        pane(sc, "WinGlass%d" % k, "lamp", x, y, phi, 3.0, 2.0, 3.2, -0.45)
        sc.piece("WinSill%d" % k, "gold", rbox(x + nx * 0.2, y + ny * 0.2, 2.85, 3.0, 0.7, 0.3, phi))
    # --- gold foot band and cornice band (rings around the walls)
    sc.piece("FootBand", "gold", zbox(0, 0, -0.3, 0.6, W + 0.5, D + 0.5), (),
             [zbox(0, 0, -0.5, 1.0, W - 1.0, D - 1.0), *arch_cut(0, 0, math.radians(90), -0.5, DOOR_W, 1.6, 4.0, 6.0)])
    sc.piece("CorniceBand", "gold", zbox(0, 0, WH - 0.7, WH, W + 0.6, D + 0.6), (), [zbox(0, 0, WH - 1.0, WH + 0.5, W - 0.6, D - 0.6)])
    # --- corner pilasters (marble, gold caps) at the four corners
    for sx in (-1, 1):
        for sy in (-1, 1):
            sc.piece("Pilaster%d%d" % (sx, sy), "marble", zbox(sx * (W / 2 + 0.1), sy * (D / 2 + 0.1), 0.6, WH - 0.7, 1.1, 1.1))
            sc.piece("PilasterCap%d%d" % (sx, sy), "gold", zbox(sx * (W / 2 + 0.1), sy * (D / 2 + 0.1), WH - 1.4, WH - 0.7, 1.5, 1.5))
    # --- roof: gable along x, blue tile stand-in slabs, gold ridge + finials, marble gable ends (two wedges each)
    RISE = 3.7
    EAVE_Y = D / 2 + 0.9
    th = math.atan2(RISE, EAVE_Y)
    sl = math.hypot(EAVE_Y, RISE) + 0.3
    for s, nm in ((1, "F"), (-1, "B")):
        ny, nz = s * math.sin(th), math.cos(th)
        yc = s * EAVE_Y / 2 + ny * 0.22
        zc = WH + RISE / 2 + nz * 0.22
        sc.piece("Roof" + nm, "roof", S("box", (W + 1.4, sl, 0.45), (0, yc, zc), (1, 0, 0), (0, -s * math.cos(th), math.sin(th))))
    sc.piece("Ridge", "gold", box(0, 0, WH + RISE + 0.12, W + 1.8, 0.8, 0.5))
    for sx in (-1, 1):
        sc.piece("RidgeBall%d" % sx, "gold", ball(sx * (W / 2 + 1.0), 0, WH + RISE + 0.2, 0.9))
        for s in (1, -1):
            sc.piece("Gable%d%s" % (sx, "F" if s > 0 else "B"), "marble", wedge(sx * (W / 2 - 0.45), s * (D / 2 - 0.1) / 2, WH + RISE / 2 - 0.1, 0.8, RISE + 0.2,
                                                                          D / 2 - 0.1, -s))
    # --- hanging blue pennant on a gold arm at the front-right corner (the shop signs of the 2D)
    sc.piece("SignArm", "gold", box(W / 2 + 1.2, D / 2 + 0.1, 7.2, 2.4, 0.3, 0.3))
    sc.piece("SignChain0", "gold", box(W / 2 + 1.9, D / 2 + 0.1, 6.7, 0.12, 0.12, 1.0))
    sc.piece("SignCloth", "fabricB", box(W / 2 + 1.9, D / 2 + 0.1, 4.9, 1.7, 0.14, 3.0))
    sc.piece("SignRim", "gold", box(W / 2 + 1.9, D / 2 + 0.16, 3.35, 1.9, 0.12, 0.2))
    sc.piece("SignShield", "gold", cyld(W / 2 + 1.9, D / 2 + 0.22, 5.1, 1.1, 0.18, 0, 1))


BUILDINGS = {"Gate": ("gate", gate), "Tower_GateEast": ("tower", None), "Tower_Lookout": ("tower", None), "Armory": ("armory", armory)}
only = [s for s in args.only.split(",") if s] or list(BUILDINGS)

# =========================================================================================================== Luau
HEAD = r'''-- skeleton_civic (generated by tools/skeleton_civic.py, 이미지 생성 1 10/11, SPEC A23-120/121 stage 4). WorldKit ONLY, Edit mode.
if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end
if game:GetService("RunService"):IsRunning() then error("Edit mode only") end
local MODE = "__MODE__"
local SS = game:GetService("ServerStorage")
local root = workspace:FindFirstChild("HaloV2")
if not root then error("Workspace.HaloV2 is missing: run tools/halo_blockout.py first") end
local bf = root:FindFirstChild("Buildings")
local gray = SS:FindFirstChild("HaloGrayHold")
local masters = SS:FindFirstChild("HaloSkeletons")
local IDS = {__IDS__}
if MODE == "remove" then
	local n = 0
	for _, id in IDS do
		local cur = bf:FindFirstChild(id)
		local g = gray and gray:FindFirstChild(id)
		if cur and cur:GetAttribute("Skeleton") then cur:Destroy() n += 1 end
		if g then g.Parent = bf end
		local m = masters and masters:FindFirstChild(id)
		if m then m:Destroy() end
	end
	return "skeleton_civic removed: " .. n .. " skeleton(s), the grey boxes are back"
end
if not gray then gray = Instance.new("Folder") gray.Name = "HaloGrayHold" gray.Parent = SS end
if not masters then masters = Instance.new("Folder") masters.Name = "HaloSkeletons" masters.Parent = SS end
local tmp = workspace:FindFirstChild("_csg_tmp")
if tmp then tmp:Destroy() end
tmp = Instance.new("Folder") tmp.Name = "_csg_tmp" tmp.Parent = workspace
local BASE, M = CFrame.new(), nil
local CF, RF = Enum.CollisionFidelity.PreciseConvexDecomposition, Enum.RenderFidelity.Precise
local KIND = { box = Enum.PartType.Block, cyl = Enum.PartType.Cylinder, ball = Enum.PartType.Ball }
-- building-local frame (x, y = front, z up) -> Roblox: (x, z, -y)
local function S(kind, sx, sy, sz, x, y, z, ax, ay, az, bx, by, bz)
	local p
	if kind == "wedge" then p = Instance.new("WedgePart") else p = Instance.new("Part") p.Shape = KIND[kind] end
	p.Anchored = true
	p.Size = Vector3.new(sx, sy, sz)
	p.CFrame = BASE * CFrame.fromMatrix(Vector3.new(x, z, -y), Vector3.new(ax, az, -ay), Vector3.new(bx, bz, -by))
	p.Parent = tmp
	return p
end
local GOLD, MARB = Color3.fromRGB(__GOLD__), Color3.fromRGB(__MARBLE__)
local STY = {
	marble = function(p) p.Material = Enum.Material.Marble p.MaterialVariant = "__VARIANT__" p.Color = MARB end,
	gold = function(p) p.Material = Enum.Material.Metal p.MaterialVariant = "HH_HaloGoldTrim" p.Color = GOLD end,
	roof = function(p) p.Material = Enum.Material.SmoothPlastic p.Color = Color3.fromRGB(__ROOF__) end,
	wood = function(p) p.Material = Enum.Material.Wood p.Color = Color3.fromRGB(176, 118, 68) p.CanCollide = false end,
	-- Fabric came out near-black in the WorldKit light (10/11 photos; img3 saw it on the awning): SmoothPlastic until the cause is known
	fabricB = function(p) p.Material = Enum.Material.SmoothPlastic p.Color = Color3.fromRGB(104, 170, 240) p.CanCollide = false end,
	lamp = function(p)
		p.Material = Enum.Material.SmoothPlastic p.Color = Color3.fromRGB(255, 220, 140) p.CastShadow = false
		p:SetAttribute("LampLight", true)
		local l = Instance.new("PointLight") l.Color = Color3.fromRGB(255, 214, 140) l.Brightness = 1.2 l.Range = 14 l.Enabled = false l.Parent = p
	end,
}
local fails = 0
local function piece(name, st, base, adds, cuts, flags)
	local r = base
	local ok, err = pcall(function()
		if #adds > 0 then r = r:UnionAsync(adds, CF, RF) end
		if #cuts > 0 then r = r:SubtractAsync(cuts, CF, RF) end
	end)
	if not ok then fails += 1 warn("csg " .. name .. ": " .. tostring(err)) r = base end
	r.Name = name
	r.Anchored = true
	if r:IsA("UnionOperation") then r.UsePartColor = true end
	STY[st](r)
	if flags then
		if flags.collide == false then r.CanCollide = false end
		if flags.tag then game:GetService("CollectionService"):AddTag(r, flags.tag) end
	end
	r.TopSurface = Enum.SurfaceType.Smooth r.BottomSurface = Enum.SurfaceType.Smooth
	r.Parent = M
	return r
end
local function begin(id, x, y, z, yawDeg)
	BASE = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg) + math.pi, 0)
	M = Instance.new("Model")
	M.Name = id
end
local function finish(id, plan)
	local old = bf:FindFirstChild(id)
	local n = 0
	for _, d in M:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
	if old and not old:GetAttribute("Skeleton") then
		for _, k in { "Kind", "District", "Floors", "FloorH", "Note", "DoorFront", "DoorSize" } do
			if old:GetAttribute(k) ~= nil then M:SetAttribute(k, old:GetAttribute(k)) end
		end
		old.Parent = gray
	elseif old then
		old:Destroy()
	end
	M:SetAttribute("Skeleton", 1)
	M:SetAttribute("PlanPose", plan)
	local pp = M:FindFirstChild("Lintel") or M:FindFirstChildWhichIsA("BasePart")
	M.PrimaryPart = pp
	local m = masters:FindFirstChild(id)
	if m then m:Destroy() end
	M:Clone().Parent = masters
	M.Parent = bf
	return n
end
local counts = {}
'''


def build_luau():
    out = [HEAD.replace("__MODE__", args.mode).replace("__IDS__", ",".join('"%s"' % i for i in BUILDINGS))
           .replace("__GOLD__", "%d, %d, %d" % GOLD_RGB).replace("__MARBLE__", "%d, %d, %d" % MARBLE_RGB)
           .replace("__VARIANT__", MARBLE_VARIANT).replace("__ROOF__", "%d, %d, %d" % ROOF_RGB)]
    total = 0
    for bid in only:
        b = BLD[bid]
        sc = Scene(bid)
        if bid == "Gate":
            gate(sc)
        elif bid == "Armory":
            armory(sc)
        elif bid == "Tower_GateEast":
            # front = the door side (plan yaw makes local +y the door direction): the tower's door at phi = 90
            tower(sc, "", 0.0, 0.0, math.radians(90))
        elif bid == "Tower_Lookout":
            tower(sc, "", 0.0, 0.0, math.radians(90), lookout=True)
        pose = "%s,%s,%s,%s" % (fm(b["x"]), fm(b["z"]), fm(b["yaw"]), fm(b["ground_y"]))
        out.append('begin("%s", %s, %s, %s, %s)' % (bid, fm(b["x"]), fm(b["ground_y"]), fm(b["z"]), fm(b["yaw"])))
        out += sc.L
        out.append('counts["%s"] = finish("%s", "%s")' % (bid, bid, pose))
        total += sc.n
    out.append("tmp:Destroy()")
    out.append('local parts = {} for id, n in counts do table.insert(parts, id .. "=" .. n) end')
    out.append('return "skeleton_civic built: " .. table.concat(parts, ", ") .. " (csg failures " .. fails .. ")"')
    return "\n".join(out) + "\n", total


if __name__ == "__main__":
    src, total = build_luau()
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    open(args.out, "w", encoding="utf-8", newline="\n").write(src)
    print("[skeleton_civic] %s: %d pieces, %d KB -> %s" % (",".join(only), total, len(src) // 1024, args.out))
