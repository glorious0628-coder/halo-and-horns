"""halo_blockout_shots.py (이미지 생성 1, 2026-10-11): WorldKit grey-box photos. Window restore = screen step: only after 검수 "전달함, 시작".
usage: py tools/worldkit/halo_blockout_shots.py [name-prefix ...]"""
import ctypes, json, os, shutil, subprocess, sys, time
u = ctypes.windll.user32
TEMP = os.environ["TEMP"]
S = TEMP
OUT = "art/review/world/halo_v2/blockout"
os.makedirs(OUT, exist_ok=True)
env0 = dict(os.environ, STUDIO_NAME="WorldKit")
code = open("tools/worldkit/halo_blockout_shots.luau", encoding="utf-8").read()
jp = os.path.join(TEMP, "hb_shots.json"); json.dump({"code": code, "datamodel_type": "Edit"}, open(jp, "w", encoding="utf-8"), ensure_ascii=False)
raw = subprocess.run([sys.executable, "tools/studio_mcp.py", "call", "execute_luau", "@" + jp], env=env0, capture_output=True, text=True, encoding="utf-8").stdout.strip()
shots = json.loads(raw[raw.index("["):raw.rindex("]") + 1])
only = sys.argv[1:]
if only: shots = [s for s in shots if any(s["name"].startswith(o) for o in only)]
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
