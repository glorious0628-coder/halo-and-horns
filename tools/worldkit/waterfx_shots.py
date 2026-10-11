import ctypes, json, os, shutil, subprocess, sys, time
u = ctypes.windll.user32
TEMP = os.environ["TEMP"]
OUT = "art/review/world/halo_new/waterfx"
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
    p = os.path.join(TEMP, "wk_arg.json"); json.dump(arg, open(p, "w"))
    return subprocess.run([sys.executable, "tools/studio_mcp.py", "call", tool, "@" + p], env=env, capture_output=True, text=True, encoding="utf-8").stdout
cam = 'workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable workspace.CurrentCamera.CFrame=CFrame.lookAt(Vector3.new(%s),Vector3.new(%s)) workspace.CurrentCamera.FieldOfView=60 return "cam"'
try:
    u.ShowWindow(h, 4); time.sleep(1.5)
    shots = [("EC", "190,22,-700", "172,14,-638"), ("EC", "190,22,-700", "172,14,-638"), ("EC", "190,22,-700", "172,14,-638")]
    for i, (n, a, b) in enumerate(shots):
        if i == 0:
            print(mcp("execute_luau", {"code": cam % (a, b), "datamodel_type": "Edit"}).strip()); time.sleep(1.0)
        r = mcp("screen_capture", {"capture_id": f"waterfx_{i + 1}", "camera_position": [float(v) for v in a.split(",")], "look_at_position": [float(v) for v in b.split(",")]})
        src = os.path.join(TEMP, "studio_capture_0.jpeg")
        dst = os.path.join(OUT, f"waterfx_{n}_{i + 1}.jpg")
        if os.path.exists(src): shutil.copy(src, dst); os.remove(src)
        print(i, r.strip()[:80], dst, time.strftime("%T"))
        time.sleep(1.2)
finally:
    if was_min or True:
        u.ShowWindow(h, 7)
print("minimized")
