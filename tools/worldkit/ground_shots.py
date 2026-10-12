"""ground_shots.py (이미지 생성 1, 2026-10-11): WorldKit photos of the walking-ground skeleton (plaza, roads, stairs, yards, bridges)
and of the floating island's underside, in the C2c day light (tools/halo_light_sim.luau; restored in a finally block).
Window restore = a screen step: only after 검수 "전달함, 시작".
usage: py tools/worldkit/ground_shots.py [name-prefix ...] [--prep] [--nolight] [--nobloom]      (--prep: only print the shot list)
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
    out.append(("ground_main_cathedral_stairs", g(29.0, -637.0, 14), g(74, -675, 8)))     # Stair_main_83..87 climb (2차: back + up, was in the cliff)
    out.append(("ground_castle_stairs", g(-140.2, -475.3, 5), g(-147, -510, 6)))           # Stair_to_castle_2..5
    out.append(("ground_castle_court", g(-160 + 26, -522 + 26, 10), g(-160, -522, 1)))
    out.append(("ground_bridge_B1", g(bridge["B1"]["at"][0] + 20, bridge["B1"]["at"][1] + 20, 7), g(bridge["B1"]["at"][0], bridge["B1"]["at"][1], 1)))
    out.append(("ground_bridge_B3_stairs", g(-30, -556, 12), g(-66, -572, 8)))
    out.append(("ground_stones_cliff", g(150, -615, 7), g(140, -628, 0)))
    hx, hz = yard["hill_yard"]["at"]
    cx_, cz_ = toward(hx, hz, fx, fz, 30)  # 2차: from the plaza side (was inside a house box)
    out.append(("ground_hill_yard", g(cx_, cz_, 16), g(hx, hz, 0)))
    out.append(("ground_top", ab(CX, 540, CZ + 2), ab(CX, 0, CZ)))
    out.append(("under_south", ab(CX - 20, -50, LZ0 - 340), ab(CX, -45, CZ)))
    out.append(("under_east", ab(LX1 + 420, -50, CZ), ab(CX, -45, CZ)))
    out.append(("under_diag", ab(LX1 + 280, -25, LZ0 - 260), ab(CX, -45, CZ)))
    out.append(("under_below", ab(CX, -330, CZ), ab(CX, -45, CZ)))
    out.append(("under_side_close", ab(LX1 + 110, -40, CZ + 80), ab(LX1 - 40, -50, CZ + 80)))
    pull = ("ground_main_cathedral_stairs", "ground_hill_yard")  # only these get the in-front-of-the-wall pull
    return [dict(name=n, cam=c, look=l, clear=n in pull) for n, c, l in out]


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
-- 2차 10/11: a camera behind a wall / inside the cliff is pulled toward the look point, in front of the first hit
local all = RaycastParams.new()
all.FilterType = Enum.RaycastFilterType.Exclude
local mk = workspace:FindFirstChild("HaloV2") and workspace.HaloV2:FindFirstChild("Markers")
-- 10/12: the retaining walls' parapets (5단계) pulled the cameras onto the wall tops -> the same spots as before the walls
local wl = workspace:FindFirstChild("HaloV2") and workspace.HaloV2:FindFirstChild("Ground") and workspace.HaloV2.Ground:FindFirstChild("Walls")
local ex = {}
if mk then table.insert(ex, mk) end
if wl then table.insert(ex, wl) end
all.FilterDescendantsInstances = ex
all.IgnoreWater = true
local function clear(cam, look)
	local a = Vector3.new(look[1], look[2] + 1.5, look[3])
	local d = Vector3.new(cam[1], cam[2], cam[3]) - a
	local h = workspace:Raycast(a, d, all)
	if not h then return cam end
	local p = h.Position - d.Unit * 2
	return { p.X, p.Y, p.Z }
end
local shots = {}
for _, sp in SPEC do
	local c, l = pt(sp.cam), pt(sp.look)
	if sp.clear then c = clear(c, l) end
	table.insert(shots, { name = sp.name, cam = c, look = l })
end
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


def door_spec():
    """--doors (골격 다듬기 10/11): doorsteps in the sloped districts (market 4->8, garden 12->16, cliff 18->22) after the level
    aprons, plus one overview of each sloped district"""
    B = {b["id"]: b for b in PLAN["buildings"]}
    out = []
    for bid in ("Shop_Juice", "Shop_Bakery", "House_Garden3", "House_Garden7", "House_Cliff4", "House_Cliff8"):
        b = B[bid]
        (ax, az), (ux, uz) = b["door_at"], b["door_dir"]
        out.append(("door_" + bid, ab(ax + ux * 16 + uz * 5, b["ground_y"] + 7, az + uz * 16 - ux * 5), ab(ax, b["ground_y"] + 3, az)))
    for did in ("market", "garden_homes", "cliff_homes"):
        d = next(x for x in PLAN["districts"] if x["id"] == did)
        xs, zs = [p[0] for p in d["poly"]], [p[1] for p in d["poly"]]
        cx, cz = sum(xs) / len(xs), sum(zs) / len(zs)
        out.append(("district_" + did, ab(cx + 40, d["y"] + 70, cz + 70), ab(cx, d["y"], cz)))
    return [dict(name=n, cam=c, look=l, clear=False) for n, c, l in out]


def review2_spec():
    """--review2 (검수 10/11 밤, plan v2 고침 뒤): ground, roads and heights of the fixed plan"""
    B = {b["id"]: b for b in PLAN["buildings"]}
    cat, look = B["Cathedral"], B["Tower_Lookout"]
    b4 = bridge["B4"]["at"]
    out = [
        ("r2_01_gate_eye", ab(0, 6, -343), ab(cat["x"], 40, cat["z"])),
        ("r2_02_plaza_eye", g(*toward(fx, fz, 0, -420, 50), 4.5), g(fx, fz, 3.0)),
        ("r2_03_plaza_high", g(fx + 46, fz + 46, 58), g(fx, fz, 0)),
        ("r2_04_stairs_low", g(30, -625, 8), g(80, -675, 4)),
        ("r2_05_stairs_mid", g(112, -668, 6), g(40, -686, 4)),
        ("r2_17_cliffwall_high", g(118, -585, 6), g(88, -585, 2)),   # 10/12 디자인 검수: the plaza|cliff wall from its high side
        ("r2_18_stairfoot_top", g(36, -626, 25), g(56, -650, 0)),     # 10/12 디자인 검수: r2_04's road from above (plates over the grass?)
        ("r2_06_stairs_top", g(70, -724, 8), g(40, -640, 0)),
        ("r2_07_stairs_side", g(10, -630, 40), g(72, -680, 0)),  # 3차: was inside a gray box (150,-640)
        ("r2_08_cliff_tiers", g(160, -606, 6), g(185, -628, 2)),  # 3차: from the lower tier at the to_cliff flight
        ("r2_09_cliff_lookout_lane", g(198, -700, 8), g(218, -772, 4)),
        ("r2_10_lookout_to_cathedral", ab(look["x"] - 9, look["ground_y"] + 46, look["z"]), ab(cat["x"], cat["ground_y"] + 20, cat["z"])),
        ("r2_11_lookout_yard", g(205, -800, 6), ab(cat["x"], cat["ground_y"] + 30, cat["z"])),
        ("r2_12_garden_B4", g(b4[0] + 22, b4[1] + 16, 8), g(b4[0], b4[1], 0)),
        ("r2_13_pads", ab(0, 34, -398), ab(0, 0, -357)),
        ("r2_14_top", ab(CX, 380, CZ + 150), ab(CX, 0, CZ)),  # 3차: 540 straight down was hazy
        ("r2_15_bridge_B4_close", g(b4[0] - 6, b4[1] + 14, 5), g(b4[0], b4[1], 1)),
        ("r2_16_cliff_flight", g(196, -606, 8), g(176, -622, 2)),
    ]
    return [dict(name=n, cam=c, look=l, clear=False) for n, c, l in out]


def houses_spec():
    """--houses (10/11 밤): 이미지 생성 3's house / shop skeletons at their plan spots, one shot per group, from the door side"""
    B = {b["id"]: b for b in PLAN["buildings"]}
    out = []
    for name, ids, dist, hgt in (("h_01_market", ("Shop_Potion", "Shop_Flower", "Shop_Bakery", "Shop_Juice"), 34, 22),
                                  ("h_02_hill", ("House_Hill1", "House_Hill2", "House_Hill3"), 40, 26),
                                  ("h_03_cliff_lower", ("House_Cliff1", "House_Cliff2"), 34, 18),
                                  ("h_04_cliff_upper", ("House_Cliff3", "House_Cliff4", "House_Cliff5"), 44, 26),
                                  ("h_05_garden", ("House_Garden1", "House_Garden2", "House_Garden3", "House_Garden4"), 50, 30)):
        bs = [B[i] for i in ids]
        cx, cz = sum(b["x"] for b in bs) / len(bs), sum(b["z"] for b in bs) / len(bs)
        ux, uz = sum(b["door_dir"][0] for b in bs), sum(b["door_dir"][1] for b in bs)
        n = math.hypot(ux, uz) or 1.0
        out.append((name, g(cx + ux / n * dist, cz + uz / n * dist, hgt), g(cx, cz, 4)))
    for bid in ("House_Hill1", "Shop_Bakery", "House_Garden3"):  # close door shots (05 the widest, a shop with an off-centre door, 07)
        b = B[bid]
        (ax, az), (ux, uz) = b["door_at"], b["door_dir"]
        out.append(("h_door_" + bid, ab(ax + ux * 14 + uz * 4, b["ground_y"] + 6, az + uz * 14 - ux * 4), ab(ax, b["ground_y"] + 3, az)))
    return [dict(name=n, cam=c, look=l, clear=False) for n, c, l in out]


shots = (door_spec() if "--doors" in sys.argv else review2_spec() if "--review2" in sys.argv else
         houses_spec() if "--houses" in sys.argv else spec())
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
        if "--nobloom" in sys.argv:  # 2차: check whether a white blur is the C2c bloom (restore puts the bloom back)
            print(run_luau('local b = game.Lighting:FindFirstChild("ImgDevBloom") if b then b.Enabled = false end return "bloom off"'))
    u.ShowWindow(h, 4)
    time.sleep(1.5)
    for i, s in enumerate(shots):
        src = os.path.join(TEMP, "studio_capture_0.jpeg")
        if os.path.exists(src):
            os.remove(src)
        top = s["name"].endswith("_top")
        if top:  # 디자인 검수 10/11: the WorldKit fog (190,170,140, 120..650) hazes the view from above -> off for this shot only
            run_luau('local L = game.Lighting shared.GS_FOG = { L.FogStart, L.FogEnd } L.FogStart, L.FogEnd = 100000, 100001 return "fog off"')
        r = mcp("screen_capture", {"capture_id": s["name"], "camera_position": s["cam"], "look_at_position": s["look"]})
        if top:
            run_luau('local L = game.Lighting local f = shared.GS_FOG if f then L.FogStart, L.FogEnd = f[1], f[2] end return "fog back"')
        dst = os.path.join(OUT, s["name"] + ("_nobloom" if "--nobloom" in sys.argv else "") + ".jpg")
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
