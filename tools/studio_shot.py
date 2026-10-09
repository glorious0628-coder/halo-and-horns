"""
Studio 화면 한 장을 파일로 저장한다(개발 일지 A23-42 전·후 사진, 확인 사진).

  py tools/studio_shot.py <out.png> [--cam x,y,z --look x,y,z] [--txt "한 줄 설명"]

- 대상 창: studio_mcp 규칙 그대로(STUDIO_NAME, 기본은 메인 Studio).
- --cam/--look: Edit 모드일 때만 카메라를 그 자리로 옮긴 뒤 찍는다(Play 중에는 지금 화면 그대로).
- 확장자가 .png면 PNG로, 아니면 받은 JPEG 그대로 저장한다. --txt를 주면 같은 이름 .txt에 한 줄을 쓴다.
- 사용자 플레이 중에는 쓰지 않는다(자기 테스트 Play나 Edit 화면만).
"""

import base64
import io
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio_mcp import Client  # noqa: E402

CAM_LUA = """
local cam = workspace.CurrentCamera
local from, to = Vector3.new(%s), Vector3.new(%s)
cam.CFrame = CFrame.lookAt(from, to)
cam.Focus = CFrame.new(to) -- the Studio edit camera orbits its Focus: without this it turns back to the old focus
return tostring(cam.CFrame.Position) .. " look " .. tostring(cam.CFrame.LookVector)
"""


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def arg(name):
    if name in sys.argv:
        i = sys.argv.index(name)
        if i + 1 < len(sys.argv):
            return sys.argv[i + 1]
    return None


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    pos = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags_with_value = {arg("--cam"), arg("--look"), arg("--txt")}
    pos = [a for a in pos if a not in flags_with_value]
    if not pos:
        sys.exit(__doc__)
    out = os.path.abspath(pos[0])
    os.makedirs(os.path.dirname(out), exist_ok=True)
    c = Client()
    try:
        c.start()
        state = text_of(c.call("get_studio_state", {}))
        cam, look = arg("--cam"), arg("--look")
        if cam and look and "Current Studio Mode: Edit" in state:
            res = c.call("execute_luau", {"code": CAM_LUA % (cam, look), "datamodel_type": "Edit"})
            print("camera:", text_of(res))
            time.sleep(1.5)  # let the viewport render the new camera before the capture
        res = c.call("screen_capture", {"capture_id": os.path.splitext(os.path.basename(out))[0]})
        raw = None
        for part in res.get("content", []):
            if part.get("type") == "image":
                raw = base64.b64decode(part["data"])
        if raw is None:
            sys.exit("캡처 실패: " + json.dumps(res, ensure_ascii=False)[:300])
        if out.lower().endswith(".png"):
            from PIL import Image
            Image.open(io.BytesIO(raw)).save(out)
        else:
            with open(out, "wb") as f:
                f.write(raw)
        txt = arg("--txt")
        if txt:
            with open(os.path.splitext(out)[0] + ".txt", "w", encoding="utf-8") as f:
                f.write(txt.strip() + "\n")
        print("saved:", out)
    finally:
        c.close()


if __name__ == "__main__":
    main()
