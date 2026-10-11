"""halo_blockout_shots.py (이미지 생성 1, 2026-10-11): WorldKit grey-box photos. Window restore = screen step: only after 검수 "전달함, 시작".
usage: py tools/worldkit/halo_blockout_shots.py [name-prefix ...] [--bench] [--prep]
  --prep: only place the avatar blocks / bench and print the shot list (no window, no capture)"""
import ctypes, json, os, shutil, subprocess, sys, time


def plan_shots():
    """town shots from docs/design/halo_plan_v2_2026-10-11.json (they follow the plan when it changes)"""
    import math
    P = json.load(open("docs/design/halo_plan_v2_2026-10-11.json", encoding="utf-8"))
    D = {d["id"]: d for d in P["districts"]}
    B = {b["id"]: b for b in P["buildings"]}
    R = {r["id"]: r for r in P["roads"]}
    pool = {w["id"]: w for w in P["water"]["pools"]}

    def cen(did):
        xs = [p[0] for p in D[did]["poly"]]
        zs = [p[1] for p in D[did]["poly"]]
        return sum(xs) / len(xs), sum(zs) / len(zs)

    def g(x, z, h):
        return dict(x=round(x, 1), z=round(z, 1), h=h)

    def ab(x, y, z):
        return dict(x=round(x, 1), y=round(y, 1), z=round(z, 1), abs=True)

    fx, fz = pool["fountain"]["at"]
    to_sp = (0 - fx, -416 - fz)
    n = math.hypot(*to_sp)
    ux, uz = to_sp[0] / n, to_sp[1] / n
    xs = [p[0] for p in P["land"]]
    zs = [p[1] for p in P["land"]]
    cx, cz = (min(xs) + max(xs)) / 2, (min(zs) + max(zs)) / 2
    out = [
        ("00_bridge_approach", ab(0, 6, -280), ab(0, 10, -400)),
        ("01_gate_in_eye", ab(0, 5, -316), ab(6, 6, -460)),
        ("02_spawn_eye", g(0, -416, 4.5), g(fx, fz, 6)),
        # opening camera v2 (검수 10/11): SPOT.Halo (0,16,-410) + (0,-4,140) -> (0,-2,58)
        ("03_opening_start", ab(0, 12, -270), ab(0, 16, -410)),
        ("03b_opening_mid", ab(0, 13, -320), ab(0, 16, -410)),
        ("04_opening_end", ab(0, 14, -352), ab(0, 16, -410)),
        ("05_plaza_eye", g(fx + ux * 55, fz + uz * 55, 4.5), g(fx, fz, 4)),
        ("06_plaza_high", g(fx + ux * 80 - uz * 40, fz + uz * 80 + ux * 40, 40), g(fx, fz, 0)),
        ("07_market_eye", g(B["Shop_Potion"]["door_at"][0] - 6, B["Shop_Potion"]["door_at"][1] + 10, 4.5), g(*cen("market"), 4)),
        ("08_market_hill", g(*R["to_hill"]["pts"][1], 4.5), g(*cen("market_hill"), 6)),
        ("09_training", g(-36, -416, 4.5), g(*cen("training"), 3)),
        ("10_castle", g(*R["to_castle"]["pts"][0], 5), g(B["Castle"]["x"], B["Castle"]["z"], 14)),
        ("11_garden", g(*cen("garden"), 4.5), g(*cen("garden_homes"), 4)),
        ("12_cathedral", g(*R["main"]["pts"][-3], 5), g(B["Cathedral"]["x"], B["Cathedral"]["z"], 20)),
        ("13_cliff_homes", g(*R["to_cliff"]["pts"][1], 5), g(*cen("cliff_homes"), 6)),
        ("15_top", ab(cx, 470, cz + 2), ab(cx, 0, cz)),
        ("16_aerial_south", ab(cx - 70, 360, max(zs) + 130), ab(cx, 0, cz)),
        ("17_aerial_north", ab(cx + 90, 360, min(zs) - 200), ab(cx, 0, cz)),
    ]
    tw = B["Tower_Lookout"]
    dist = math.hypot(fx - tw["x"], fz - tw["z"])
    tilt = round(math.degrees(math.atan2(tw["ground_y"] + tw["h"] + 5 - 10, dist)), 1)
    towers = [dict(name="14_lookout_view", tower=True, aim=[fx, fz], tilt=tilt),  # the fountain square in the middle, cathedral left
              dict(name="14b_lookout_sea", tower=True, aim=[tw["x"] + 80, tw["z"] - 70], tilt=30)]  # island edge + sea + clouds
    if "--bench" in sys.argv:
        out += [("90_beamtest_high", ab(-3000, 90, 45), ab(-3000, 50, 0)), ("91_beamtest_low", ab(-3000, 58, 40), ab(-3000, 50, 0))]
    return [dict(name=n, cam=c, look=l) for n, c, l in out] + towers


u = ctypes.windll.user32
TEMP = os.environ["TEMP"]
S = TEMP
OUT = "art/review/world/halo_v2/blockout"
os.makedirs(OUT, exist_ok=True)
env0 = dict(os.environ, STUDIO_NAME="WorldKit")
code = open("tools/worldkit/halo_blockout_shots.luau", encoding="utf-8").read()
code = code.replace("__SHOTS__", json.dumps(plan_shots(), ensure_ascii=False))
jp = os.path.join(TEMP, "hb_shots.json"); json.dump({"code": code, "datamodel_type": "Edit"}, open(jp, "w", encoding="utf-8"), ensure_ascii=False)
raw = subprocess.run([sys.executable, "tools/studio_mcp.py", "call", "execute_luau", "@" + jp], env=env0, capture_output=True, text=True, encoding="utf-8").stdout.strip()
shots = json.loads(raw[raw.index("["):raw.rindex("]") + 1])
only = [a for a in sys.argv[1:] if not a.startswith("--")]
if only: shots = [s for s in shots if any(s["name"].startswith(o) for o in only)]
if "--prep" in sys.argv:
    for s_ in shots:
        print(s_["name"], [round(v, 1) for v in s_["cam"]], [round(v, 1) for v in s_["look"]])
    sys.exit(0)
titles = []
def cb(h, _):
    n = u.GetWindowTextLengthW(h)
    if n:
        b = ctypes.create_unicode_buffer(n + 1); u.GetWindowTextW(h, b, n + 1)
        if "WorldKit" in b.value and "Roblox Studio" in b.value: titles.append((h, b.value))
    return True
u.EnumWindows(ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)(cb), 0)
print(titles)
h = titles[0][0]
was_min = u.IsIconic(h)
env = dict(os.environ, STUDIO_NAME="WorldKit")
def mcp(tool, arg):
    p = os.path.join(S, "wk_arg.json"); json.dump(arg, open(p, "w"))
    return subprocess.run([sys.executable, "tools/studio_mcp.py", "call", tool, "@" + p], env=env, capture_output=True, text=True, encoding="utf-8").stdout
t0 = time.time()
try:
    u.ShowWindow(h, 4); time.sleep(1.5)
    for i, s in enumerate(shots):
        src = os.path.join(TEMP, "studio_capture_0.jpeg")
        if os.path.exists(src): os.remove(src)
        r = mcp("screen_capture", {"capture_id": s["name"], "camera_position": s["cam"], "look_at_position": s["look"]})
        dst = os.path.join(OUT, s["name"] + ".jpg")
        if os.path.exists(src): shutil.copy(src, dst); os.remove(src)
        else: print("NO FILE", r[:200])
        print(i, s["name"], r.strip()[:60], time.strftime("%T"))
finally:
    if was_min: u.ShowWindow(h, 7)
print("done", round(time.time() - t0), "s, minimized" if was_min else "s (was not minimized)")
