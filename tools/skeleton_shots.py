"""Photos of Workspace.SkeletonTest in WorldKit (이미지 생성 3, 10/11, A23-120).

  STUDIO_NAME=WorldKit py tools/skeleton_shots.py <out_dir> [name=x,y,z,lx,ly,lz ...]

Default shots look at the house 07 skeleton (origin 3000,0,0; front = -Z) from 5, 15 and 40 studs and a 3/4 view,
plus a window, the base / planter bed and the pot at x 3026 (skeleton v3). Each extra arg is a named camera position + look-at point. Saves <out_dir>/<name>.png.
"""
import base64
import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio_mcp import Client  # noqa: E402
from PIL import Image  # noqa: E402

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
SHOTS = {
    "front_40": ([3000, 10, -40], [3000, 8, 0]),
    "front_15": ([3000, 7, -21], [3000, 7, 0]),
    "door_5": ([2999.2, 5.5, -11], [2999.2, 5.2, 0]),
    "q34_25": ([3018, 12, -22], [3000, 8, 0]),
    "win_8": ([3012.1, 8.5, -8.35], [3005.55, 7.6, -3.75]),
    "base_10": ([3011, 3.5, -15], [3004, 1.5, -5]),
    "pot_8": ([3026, 4, -7], [3026, 1.5, 0]),
}
for a in sys.argv[2:]:
    n, v = a.split("=")
    f = [float(x) for x in v.split(",")]
    SHOTS[n] = (f[:3], f[3:])
c = Client()
c.start()
for name, (cam, look) in SHOTS.items():
    res = c.call("screen_capture", {"capture_id": "skel_" + name, "camera_position": cam, "look_at_position": look})
    ok = False
    for part in res.get("content", []):
        if part.get("type") == "image":
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).save(os.path.join(OUT, name + ".png"))
            ok = True
    print(name, "saved" if ok else "NO IMAGE " + str(res)[:200], flush=True)
