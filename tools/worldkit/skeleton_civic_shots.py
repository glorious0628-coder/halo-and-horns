"""skeleton_civic_shots.py (이미지 생성 1, 2026-10-11): WorldKit photos of the civic skeletons (gate, towers, armory).
Window restore = a screen step: only after 검수 "전달함, 시작" (the window is put back to minimized at the end).
usage: py tools/worldkit/skeleton_civic_shots.py [name-prefix ...] [--prep]     (--prep: only print the shot list)
Camera spots come from the plan pose (x, z, yaw, ground_y) of each building in docs/design/halo_plan_v2_2026-10-11.json.
Output: art/review/world/halo_v2/skeleton/<Building>_<view>.jpg"""
import ctypes, json, math, os, shutil, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.chdir(ROOT)
OUT = "art/review/world/halo_v2/skeleton"
os.makedirs(OUT, exist_ok=True)
PLAN = json.load(open("docs/design/halo_plan_v2_2026-10-11.json", encoding="utf-8"))
B = {b["id"]: b for b in PLAN["buildings"]}
HEIGHT = {"Gate": 48, "Tower_GateEast": 46, "Tower_Lookout": 50, "Armory": 13}


def spots():
    out = []

    def add(name, cam, look):
        out.append(dict(name=name, cam=[round(v, 1) for v in cam], look=[round(v, 1) for v in look]))

    for bid, b in B.items():
        if bid not in HEIGHT:
            continue
        h = HEIGHT[bid]
        yaw = math.radians(b["yaw"])
        f = (math.sin(yaw), math.cos(yaw))        # door side (world x, z)
        r = (f[1], -f[0])                         # to the right of the door side as seen from outside... any consistent side
        cx, gy, cz = b["x"], b["ground_y"], b["z"]

        def at(df, dr, y):
            return (cx + f[0] * df + r[0] * dr, gy + y, cz + f[1] * df + r[1] * dr)

        look = (cx, gy + h * 0.45, cz)
        big = bid == "Gate"
        d = {"Gate": 80, "Tower_GateEast": 62, "Tower_Lookout": 66, "Armory": 30}[bid]
        add(bid + "_front", at(d, 0, h * 0.42), look)
        add(bid + "_34", at(d * 0.8, d * 0.65, h * 0.45), look)
        add(bid + "_side", at(0, d, h * 0.42), look)
        add(bid + "_back", at(-d, 0, h * 0.42), look)
        if bid == "Gate":
            add("Gate_door_eye", at(26, 0, 5), at(0, 0, 8))                              # from the bridge at eye height into the passage
            add("Gate_inside_eye", at(-26, 0, 5), at(0, 0, 8))                           # from the town side back at the gate
            add("Gate_through", at(14, 0, 7), at(-60, 0, 14))                           # in the doorway looking through to the town
            add("Gate_crown_close", at(22, 14, 32), at(0, 0, 33))
        elif bid == "Armory":
            add("Armory_door_eye", at(11, 0, 4.6), at(0, 0, 4.2))
            add("Armory_roof", at(18, 12, 22), at(0, 0, 9))
        else:
            add(bid + "_door_eye", at(12, 0, 4.6), at(0, 0, 4.0))
            add(bid + "_top", at(26, 14, h * 0.92), at(0, 0, h * 0.8))
            if bid == "Tower_Lookout":
                # the photo spot: standing on the balcony edge (floor 32.2 + eye 4.5), looking at the fountain square / the sea
                fx, fz = next(w for w in PLAN["water"]["pools"] if w["id"] == "fountain")["at"]
                dx, dz = fx - cx, fz - cz
                n = math.hypot(dx, dz)
                add("Tower_Lookout_balcony_eye", (cx + dx / n * 5.0, gy + 36.9, cz + dz / n * 5.0), (fx, gy + 12.0, fz))
                sx, sz = -dx / n, -dz / n
                add("Tower_Lookout_balcony_sea", (cx + sx * 5.0, gy + 36.9, cz + sz * 5.0), (cx + sx * 90, gy + 20.0, cz + sz * 90))
    return out


shots = spots()
only = [a for a in sys.argv[1:] if not a.startswith("--")]
if only:
    shots = [s for s in shots if any(s["name"].startswith(o) for o in only)]
if "--prep" in sys.argv:
    for s in shots:
        print(s["name"], s["cam"], s["look"])
    sys.exit(0)

u = ctypes.windll.user32
TEMP = os.environ["TEMP"]
titles = []


def cb(h, _):
    n = u.GetWindowTextLengthW(h)
    if n:
        b = ctypes.create_unicode_buffer(n + 1)
        u.GetWindowTextW(h, b, n + 1)
        if "WorldKit" in b.value and "Roblox Studio" in b.value:
            titles.append((h, b.value))
    return True


u.EnumWindows(ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)(cb), 0)
print(titles)
h = titles[0][0]
was_min = u.IsIconic(h)
env = dict(os.environ, STUDIO_NAME="WorldKit")


def mcp(tool, arg):
    p = os.path.join(TEMP, "wk_arg_civic.json")
    json.dump(arg, open(p, "w"))
    return subprocess.run([sys.executable, "tools/studio_mcp.py", "call", tool, "@" + p], env=env, capture_output=True, text=True, encoding="utf-8").stdout


t0 = time.time()
try:
    u.ShowWindow(h, 4)
    time.sleep(1.5)
    for i, s in enumerate(shots):
        src = os.path.join(TEMP, "studio_capture_0.jpeg")
        if os.path.exists(src):
            os.remove(src)
        r = mcp("screen_capture", {"capture_id": s["name"], "camera_position": s["cam"], "look_at_position": s["look"]})
        dst = os.path.join(OUT, s["name"] + ".jpg")
        if os.path.exists(src):
            shutil.copy(src, dst)
            os.remove(src)
        else:
            print("NO FILE", r[:200])
        print(i, s["name"], time.strftime("%T"))
finally:
    if was_min:
        u.ShowWindow(h, 7)
print("done", round(time.time() - t0), "s,", "minimized again" if was_min else "(was not minimized)")
