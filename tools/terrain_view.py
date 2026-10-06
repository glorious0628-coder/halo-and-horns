"""
지형 텍스처 확인용 캡처: 연습 Studio(UiSandbox)에서 Play(PC 1280x720) → 캐릭터를 재질마다 옮겨 한 장씩 찍는다(교체 전/후 비교).
Edit 화면 캡처는 3D가 하얗게 나와서(2026-10-06 확인) Play 화면을 쓴다.

  py tools/terrain_view.py before          -> build/terrain_view/before_<재질>.jpeg
  py tools/terrain_view.py after Grass Rock -> 지정한 재질만 (이름은 아래 SPOTS 키)

자리(SPOTS)는 2026-10-06 연습 Studio에서 지형 윗면을 10스터드 격자로 쏴서 재질마다 가운데에 가까운 점을 고른 것이다.
Roads(GE_DirtPath)는 Map.Decor.Roads 파트, Marble·WoodPlanks는 건물 파트라 마을 광장에서 본다.
STUDIO_NAME은 UiSandbox로 고정(dv.ensure_sandbox가 먼저 확인). 끝나면(오류가 나도) Play를 멈추고 기기 흉내를 끈다.
"""

import base64
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ["STUDIO_NAME"] = "UiSandbox"  # practice Studio only: forced before studio_mcp is imported (via device_view)
import device_view as dv  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPOTS = {  # material: (look-at point, camera offset)
    "Grass": ((310, 0, 100), (0, 30, 45)),
    "Rock": ((530, 43, -50), (0, 35, 50)),
    "LeafyGrass": ((730, 0, 30), (0, 30, 45)),
    "Basalt": ((0, 0, 370), (0, 30, 45)),
    "Limestone": ((10, 0, -400), (0, 30, 45)),
    "Cobblestone": ((10, 0, -40), (0, 25, 40)),
    "Slate": ((100, 44, -150), (0, 25, 40)),
    "CrackedLava": ((90, 40, 470), (0, 25, 40)),
    "Town": ((0, 4, 0), (0, 30, 60)),  # roads (GE_DirtPath), marble / wood planks parts around the fountain
}


def run(c, tag, names, out):
    dv.stop_play(c)
    print(dv.luau(c, dv.SET_DEVICE % dv.DEVICES["pc"], "Edit"))
    c.call("start_stop_play", {"is_start": True})
    for _ in range(60):
        time.sleep(0.5)
        if "Client" in dv.state(c):
            break
    time.sleep(6)
    print(dv.luau(c, dv.PICK % "Halo", "Server"))
    time.sleep(4)
    for name in names:
        (x, y, z), (dx, dy, dz) = SPOTS[name]
        dv.luau(c, f"""
local p = game.Players:GetPlayers()[1]
local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if hrp then hrp.CFrame = CFrame.lookAt(Vector3.new({x}, {y} + 5, {z}), Vector3.new({x}, {y} + 5, {z} - 10)) end
return "ok" """, "Server")
        time.sleep(2.5)
        res = c.call("screen_capture", {"capture_id": f"terrain_{tag}_{name}"})
        for part in res.get("content", []):
            if part.get("type") == "image":
                path = os.path.join(out, f"{tag}_{name}.jpeg")
                with open(path, "wb") as f:
                    f.write(base64.b64decode(part["data"]))
                print(path)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    tag = args[0]
    names = [a for a in args[1:] if a in SPOTS] or list(SPOTS)
    out = os.path.join(ROOT, "build", "terrain_view")
    os.makedirs(out, exist_ok=True)
    with dv.sandbox() as c:  # sandbox check first; Play stop + device reset at the end, also after an error
        run(c, tag, names, out)


if __name__ == "__main__":
    main()
