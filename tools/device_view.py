"""
이미지 개발용 화면 확인: 연습 Studio(UiSandbox)에서 기기 크기를 바꿔 Play → 진영·직업 선택 상태 → 캡처·배치 측정 → 원복.

  py tools/device_view.py pc            -> 1280x720 (HD 720, 마우스)
  py tools/device_view.py phone         -> 749x361 (폰, 터치)
  py tools/device_view.py 844           -> 844x390 (iPhone 13, 터치)
  py tools/device_view.py pc phone      -> 차례로 둘 다
  옵션: --faction Halo|Horns|Neutral (기본 Halo)  --out <폴더> (기본 build/device_view)  --keep (Play 유지)
  py tools/device_view.py restore       -> 기기 흉내 끄기(default)

결과: <out>/<name>.jpeg (화면), <out>/<name>.json (MainGui 아래 보이는 판들의 실제 px 사각형, UIScale, inset).
연습 Studio 전용이다: game.Name에 'UiSandbox'가 없으면 아무것도 바꾸지 않는다. STUDIO_NAME 기본값도 UiSandbox.
"""

import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault("STUDIO_NAME", "UiSandbox")
from studio_mcp import Client  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEVICES = {
    "pc": ("hd_720", 1280, 720),
    "phone": ("samsung_galaxy_s22_ultra", 749, 361),
    "844": ("iphone_13", 844, 390),
}

SET_DEVICE = r'''
assert(game.Name:find("UiSandbox", 1, true), "UiSandbox only: " .. game.Name)
local svc = game:GetService("StudioDeviceSimulatorService")
svc:SetDeviceAsync("%s")
task.wait(0.3)
svc:SetResolutionAsync(%d, %d)
task.wait(0.3)
svc:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.ActualResolution)
task.wait(0.3)
local r = svc:GetResolutionAsync()
return svc:GetDeviceAsync() .. " " .. r.X .. "x" .. r.Y
'''

RESTORE = r'''
assert(game.Name:find("UiSandbox", 1, true), "UiSandbox only: " .. game.Name)
local svc = game:GetService("StudioDeviceSimulatorService")
if svc:GetDeviceAsync() ~= "default" then
    pcall(function() svc:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.FitToWindow) end)
    svc:StopSimulationAsync()
    task.wait(0.3)
end
return svc:GetDeviceAsync()
'''

PICK = r'''
local p = game.Players:GetPlayers()[1]
if not p then return "no player" end
for _ = 1, 40 do
    if p:GetAttribute("DataLoaded") == true then break end
    task.wait(0.25)
end
if p:GetAttribute("Faction") == nil or p:GetAttribute("Faction") == "None" then p:SetAttribute("Faction", "%s") end
p:SetAttribute("ClassChosen", true)
p:SetAttribute("IntroSeen", true)
p:LoadCharacter() -- a respawn ends a running opening (Intro.Start: CharacterAdded -> Finish)
return tostring(p:GetAttribute("Faction"))
'''

RECTS = r'''
local HttpService = game:GetService("HttpService")
local lp = game.Players.LocalPlayer
local gui = lp:WaitForChild("PlayerGui"):WaitForChild("MainGui", 5)
if not gui then return "{}" end
local sc = gui:FindFirstChildOfClass("UIScale")
local inset = game:GetService("GuiService"):GetGuiInset()
local res = { Viewport = { workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y },
    Scale = sc and sc.Scale or 1, InsetY = inset.Y, Touch = game:GetService("UserInputService").TouchEnabled, Items = {} }
local origin = gui.AbsolutePosition
local function shown(o)
    while o and o ~= gui do
        if o:IsA("GuiObject") and not o.Visible then return false end
        o = o.Parent
    end
    return true
end
local function add(o, path)
    if not (o:IsA("GuiObject") and shown(o)) then return end
    local p = o.AbsolutePosition - origin
    table.insert(res.Items, { Path = path, X = math.floor(p.X + 0.5), Y = math.floor(p.Y + 0.5),
        W = math.floor(o.AbsoluteSize.X + 0.5), H = math.floor(o.AbsoluteSize.Y + 0.5) })
end
for _, c in gui:GetChildren() do
    add(c, c.Name)
    if c.Name == "HUD" then
        for _, d in c:GetChildren() do
            add(d, "HUD." .. d.Name)
            if d.Name == "Buttons" then
                for _, b in d:GetChildren() do add(b, "HUD.Buttons." .. b.Name) end
            end
        end
    end
end
return HttpService:JSONEncode(res)
'''


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def luau(c, code, dm):
    return text_of(c.call("execute_luau", {"code": code, "datamodel_type": dm}))


def state(c):
    return text_of(c.call("get_studio_state", {}))


def stop_play(c):
    if "Current Studio Mode: Edit" not in state(c):
        c.call("start_stop_play", {"is_start": False})
        for _ in range(30):
            time.sleep(0.5)
            if "Current Studio Mode: Edit" in state(c):
                return


def view(c, name, faction, out, keep):
    dev, w, h = DEVICES[name]
    stop_play(c)
    print(name, "device:", luau(c, SET_DEVICE % (dev, w, h), "Edit"))
    c.call("start_stop_play", {"is_start": True})
    for _ in range(60):
        time.sleep(0.5)
        if "Client" in state(c):
            break
    time.sleep(6)
    print(name, "faction:", luau(c, PICK % faction, "Server"))
    time.sleep(4)
    rects = luau(c, RECTS, "Client")
    with open(os.path.join(out, name + ".json"), "w", encoding="utf-8") as f:
        f.write(rects)
    res = c.call("screen_capture", {"capture_id": "device_" + name})
    import base64
    for part in res.get("content", []):
        if part.get("type") == "image":
            with open(os.path.join(out, name + ".jpeg"), "wb") as f:
                f.write(base64.b64decode(part["data"]))
    print(name, "saved:", os.path.join(out, name + ".jpeg"))
    if not keep:
        stop_play(c)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    faction = "Halo"
    out = os.path.join(ROOT, "build", "device_view")
    if "--faction" in args:
        faction = args[args.index("--faction") + 1]
    if "--out" in args:
        out = args[args.index("--out") + 1]
    keep = "--keep" in args
    names = [a for a in args if a in DEVICES or a == "restore"]
    if not names:
        sys.exit(__doc__)
    os.makedirs(out, exist_ok=True)
    c = Client()
    try:
        c.start()
        for name in names:
            if name == "restore":
                stop_play(c)
                print("restore:", luau(c, RESTORE, "Edit"))
            else:
                view(c, name, faction, out, keep)
        if not keep and "restore" not in names:
            stop_play(c)
            print("restore:", luau(c, RESTORE, "Edit"))
    finally:
        c.close()


if __name__ == "__main__":
    main()
