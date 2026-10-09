"""Edit-mode photos of a Studio window from given cameras via screen_capture camera args (no screen control).
The old single-shot tool is tools/studio_shot.py (kept as the default).


  py tools/studio_cam_shot.py <studio name part> <out.png> <camx,camy,camz> <lookx,looky,lookz> [more: out cam look ...]
e.g. STUDIO_NAME is set from the first argument (WorldKit | UiSandbox | GoodEvil); main Studio only for 메인 반영."""
import base64
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
os.environ["STUDIO_NAME"] = sys.argv[1]
from PIL import Image  # noqa: E402
from studio_mcp import Client  # noqa: E402

c = Client()
c.start()
args = sys.argv[2:]
for i in range(0, len(args), 3):
    out, cam, look = args[i], [float(v) for v in args[i + 1].split(",")], [float(v) for v in args[i + 2].split(",")]
    res = c.call("screen_capture", {"capture_id": os.path.basename(out), "camera_position": cam, "look_at_position": look})
    saved = False
    for part in res.get("content", []):
        if part.get("type") == "image":
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).save(out)
            saved = True
    print(("saved " if saved else "NO IMAGE ") + out)
c.close()
