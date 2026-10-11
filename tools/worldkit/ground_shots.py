"""ground_shots.py (이미지 생성 1, 2026-10-11): WorldKit photos of the walking-ground skeleton (plaza, roads, stairs, yards, bridges)
and of the floating island's underside, in the C2c day light (tools/halo_light_sim.luau; restored in a finally block).
Window restore = a screen step: only after 검수 "전달함, 시작".
usage: py tools/worldkit/ground_shots.py [name-prefix ...] [--prep] [--nolight]      (--prep: only print the shot list)
Output: art/review/world/halo_v2/ground/<name>.jpg   (SK_OUT overrides the folder)"""
import ctypes, json, math, os, shutil, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.chdir(ROOT)
OUT = os.environ.get("SK_OUT", "art/review/world/halo_v2/ground")
os.makedirs(OUT, exist_ok=True)
PLAN = json.load(open("docs/design/halo_plan_v2_2026-10-11.json", encoding="utf-8"))
TEMP = os.environ["TEMP"]
env = dict(os.environ, STUDIO_NAME="WorldKit")
land = PLAN["land"]
LX0, LX1 = min(p[0] for p in land), max(p[0] for p in land)
LZ0, LZ1 = min(p[1] for p in land), max(p[1] for p in land)
CX, CZ = (LX0 + LX1) / 2, (LZ0 + LZ1) / 2
pool = {w["id"]: w for w in PLAN["water"]["pools"]}
yard = {y["id"]: y for y in PLAN["yards"]}
bridge = {b["id"]: b for b in PLAN["bridges"]}
fx, fz = pool["fountain"]["at"]


def g(x, z, h):
    return dict(x=round(x, 1), z=round(z, 1), h=h)


def ab(x, y, z):
    return dict(x=round(x, 1), y=round(y, 1), z=round(z, 1), abs=True)


def toward(ax, az, bx, bz, d):
    n = math.hypot(bx - ax, bz - az) or 1.0
    return ax + (bx - ax) / n * d, az + (bz - az) / n * d


def spec():
    out = []
    sx, sz = toward(fx, fz, 0, -420, 50)
    out.append(("ground_plaza_eye", g(sx, sz, 4.5), g(fx, fz, 3.0)))
    out.append(("ground_plaza_high", g(fx + 46, fz + 46, 58), g(fx, fz, 0)))
    out.append(("ground_main_arrival", ab(0, 6, -343), g(8, -440, 2)))
    out.append(("ground_main_cathedral_stairs", g(44.2, -650.0, 5), g(74, -675, 6)))      # Stair_main_83..87 climb
    out.append(("ground_castle_stairs", g(-140.2, -475.3, 5), g(-147, -510, 6)))           # Stair_to_castle_2..5
    out.append(("ground_castle_court", g(-160 + 26, -522 + 26, 10), g(-160, -522, 1)))
    out.append(("ground_bridge_B1", g(bridge["B1"]["at"][0] + 20, bridge["B1"]["at"][1] + 20, 7), g(bridge["B1"]["at"][0], bridge["B1"]["at"][1], 1)))
    out.append(("ground_bridge_B3_stairs", g(-30, -556, 12), g(-66, -572, 8)))
    out.append(("ground_stones_cliff", g(150, -615, 7), g(140, -628, 0)))
    out.append(("ground_hill_yard", g(yard["hill_yard"]["at"][0] + 16, yard["hill_yard"]["at"][1] + 14, 8), g(yard["hill_yard"]["at"][0], yard["hill_yard"]["at"][1], 0)))
    out.append(("ground_top", ab(CX, 540, CZ + 2), ab(CX, 0, CZ)))
    out.append(("under_south", ab(CX - 20, -50, LZ0 - 340), ab(CX, -45, CZ)))
    out.append(("under_east", ab(LX1 + 420, -50, CZ), ab(CX, -45, CZ)))
    out.append(("under_diag", ab(LX1 + 280, -25, LZ0 - 260), ab(CX, -45, CZ)))
    out.append(("under_below", ab(CX, -330, CZ), ab(CX, -45, CZ)))
    out.append(("under_side_close", ab(LX1 + 110, -40, CZ + 80), ab(LX1 - 40, -50, CZ + 80)))
    return [dict(name=n, cam=c, look=l) for n, c, l in out]


LUAU = r'''
if string.find(game.Name, "GoodEvil") or game.PlaceId == 81671223175574 then error("main Studio") end
local T = workspace.Terrain
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { T }
rp.IgnoreWater = true
local function gy(x, z)
	local h = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), rp)
	return h and h.Position.Y or 0
end
local SPEC = game:GetService("HttpService"):JSONDecode([==[__SHOTS__]==])
local function pt(q)
	if q.abs then return { q.x, q.y, q.z } end
	return { q.x, gy(q.x, q.z) + q.h, q.z }
end
local shots = {}
for _, sp in SPEC do table.insert(shots, { name = sp.name, cam = pt(sp.cam), look = pt(sp.look) }) end
return game:GetService("HttpService"):JSONEncode(shots)
'''


def mcp(tool, arg):
    p = os.path.join(TEMP, "wk_arg_ground.json")
    json.dump(arg, open(p, "w", encoding="utf-8"), ensure_ascii=False)
    return subprocess.run([sys.executable, "tools/studio_mcp.py", "call", tool, "@" + p], env=env, capture_output=True, text=True, encoding="utf-8").stdout


def run_luau(code):
    return mcp("execute_luau", {"code": code, "datamodel_type": "Edit"})


def resolve(shots):
    raw = run_luau(LUAU.replace("__SHOTS__", json.dumps(shots, ensure_ascii=False))).strip()
    return json.loads(raw[raw.index("["):raw.rindex("]") + 1])


shots = spec()
only = [a for a in sys.argv[1:] if not a.startswith("--")]
if only:
    shots = [s for s in shots if any(s["name"].startswith(o) for o in only)]
if "--prep" in sys.argv:
    for s in resolve(shots):
        print(s["name"], [round(v, 1) for v in s["cam"]], [round(v, 1) for v in s["look"]])
    sys.exit(0)
shots = resolve(shots)

u = ctypes.windll.user32
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
light = "--nolight" not in sys.argv
t0 = time.time()
try:
    if light:
        sim = open("tools/halo_light_sim.luau", encoding="utf-8").read()
        sim = sim.replace('"%s"', '"C2c"', 1).replace('"%s"', '"day"', 1)
        print(run_luau(sim).strip()[:200])
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
    if light:
        print(run_luau(open("tools/halo_light_restore.luau", encoding="utf-8").read()).strip()[:200])
    if was_min:
        u.ShowWindow(h, 7)
print("done", round(time.time() - t0), "s,", "minimized again" if was_min else "(was not minimized)")
