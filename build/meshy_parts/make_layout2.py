import json, math, sys, glob
L = float(sys.argv[1]) if len(sys.argv) > 1 else 1.25
out = sys.argv[2] if len(sys.argv) > 2 else 'build/meshy_parts/balustrade_layout2.json'
def glb(name):
    g = sorted(glob.glob('art/models/meshy/%s/%s_*.glb' % (name, name)))
    assert g, name; return g[-1]
parts = {"corner": glb('HaloVar4_CornerPost_p'), "end": glb('HaloVar4_EndPost_p'), "baluster": glb('HaloVar4_Baluster_p')}
A = math.radians(45)
def R(x, y): return [round(x*math.cos(A) - y*math.sin(A), 4), round(x*math.sin(A) + y*math.cos(A), 4)]
HP, HE, HB, BASE_H, RAIL_H, RAIL_T, BASE_T = 0.77, 0.60, 0.28, 0.13, 0.165, 0.16, 0.30
CREAM, GOLD = [0.96, 0.92, 0.86], [0.85, 0.62, 0.12]
place = [{"part": "corner", "at": [0, 0, 0], "height": HP, "rot": 45}]
boxes = []
for arm in (0, 1):
    P = (lambda t: R(t, 0)) if arm == 0 else (lambda t: R(0, t))
    end = P(L); place.append({"part": "end", "at": [end[0], end[1], 0], "height": HE, "rot": 45})
    x0, x1 = 0.124, L - 0.097
    for k in (1, 2, 3):
        q = P(x0 + (x1 - x0) * k / 4); place.append({"part": "baluster", "at": [q[0], q[1], BASE_H], "height": HB, "rot": 45})
    mid = P(L / 2); rot = 45 if arm == 0 else 135
    boxes.append({"name": "base%d" % arm, "centre": [mid[0], mid[1], BASE_H / 2], "size": [L, BASE_T, BASE_H], "rot": rot, "rgb": CREAM})
    boxes.append({"name": "baseband%d" % arm, "centre": [mid[0], mid[1], BASE_H * 0.35], "size": [L, BASE_T + 0.01, 0.025], "rot": rot, "rgb": GOLD})
    zr = BASE_H + HB + RAIL_H / 2
    boxes.append({"name": "rail%d" % arm, "centre": [mid[0], mid[1], zr], "size": [L, RAIL_T, RAIL_H], "rot": rot, "rgb": CREAM})
    boxes.append({"name": "railband%d" % arm, "centre": [mid[0], mid[1], zr - RAIL_H * 0.28], "size": [L, RAIL_T + 0.01, 0.022], "rot": rot, "rgb": GOLD})
json.dump({"parts": parts, "place": place, "boxes": boxes}, open(out, 'w'), indent=1)
print('layout2 L', L, 'placed', len(place), 'boxes', len(boxes), parts)
