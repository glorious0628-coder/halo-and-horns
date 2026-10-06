"""
이미지 개발용 화면 확인: 연습 Studio(UiSandbox)에서 기기 크기를 바꿔 Play → 진영·직업 선택 상태 → 캡처·배치 측정 → 원복.

  py tools/device_view.py pc            -> 1280x720 (HD 720, 마우스)
  py tools/device_view.py phone         -> 749x361 (폰, 터치)
  py tools/device_view.py 844           -> 844x390 (iPhone 13, 터치)
  py tools/device_view.py pc phone      -> 차례로 둘 다
  옵션: --faction Halo|Horns|Neutral (기본 Halo)  --out <폴더> (기본 build/device_view)  --keep (Play 유지)
  py tools/device_view.py restore       -> 기기 흉내 끄기(default)

결과: <out>/<name>.jpeg (화면), <out>/<name>.json (MainGui 아래 보이는 판들의 실제 px 사각형, UIScale, inset).
연습 Studio 전용이다: STUDIO_NAME은 UiSandbox로 고정하고, 무엇이든 바꾸기 전에 ensure_sandbox가 지금 데이터모델을 확인한다
(Edit: game.Name에 'UiSandbox', Play: Server의 PlaceId가 메인 게임 81671223175574가 아님). 오류가 나도 Play 멈춤·기기 흉내 끄기를 한다.
"""

import contextlib
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ["STUDIO_NAME"] = "UiSandbox"  # practice Studio only: forced (not a default) before studio_mcp is imported
from studio_mcp import Client  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SANDBOX_NAME = "UiSandbox"
MAIN_PLACE_ID = 81671223175574  # the published game place: these tools never change anything there
EDIT_MARK = "Current Studio Mode: Edit"
# execute_luau failures come back as text starting with the Assistant plugin's stack (isError is not always set)
LUAU_ERROR_PREFIX = "sabuiltin_Assistant.rbxm"
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


# where the tool is: read-only, no % formatting (the main place id is put in with str.replace)
WHERE = r'''
return game:GetService("HttpService"):JSONEncode({ Name = game.Name, PlaceId = tostring(game.PlaceId),
    Main = game.PlaceId == __MAIN_PLACE_ID__ })
'''


class LuauError(RuntimeError):
    """execute_luau failed (a Lua error or assert). .text keeps the raw tool text."""

    def __init__(self, text, dm):
        super().__init__(f"execute_luau failed in {dm}: {text.strip()[:500]}")
        self.text = text


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def luau(c, code, dm, check=True):
    """Run code in datamodel dm and return its text. Raises LuauError when the tool reports an error
    (isError or the Assistant error text); check=False returns the text as it is, error or not."""
    res = c.call("execute_luau", {"code": code, "datamodel_type": dm})
    text = text_of(res)
    if check and (res.get("isError") or text.lstrip().startswith(LUAU_ERROR_PREFIX)):
        raise LuauError(text, dm)
    return text


def state(c):
    return text_of(c.call("get_studio_state", {}))


def ensure_sandbox(c):
    """Raise unless the Studio this client talks to is the practice place. Call before ANY state change
    (stop_play, SET_DEVICE, start_stop_play). Edit: game.Name has 'UiSandbox' and PlaceId is not the main place;
    Play: the Server datamodel's PlaceId is not the main place. Returns a short description."""
    if os.environ.get("STUDIO_NAME") != SANDBOX_NAME:
        raise RuntimeError(f"refused: STUDIO_NAME is {os.environ.get('STUDIO_NAME')!r}, not {SANDBOX_NAME!r}")
    st = state(c)
    dm = "Edit" if EDIT_MARK in st else "Server"
    raw = luau(c, WHERE.replace("__MAIN_PLACE_ID__", str(MAIN_PLACE_ID)), dm).strip()
    try:
        info = json.loads(raw)
    except json.JSONDecodeError:
        raise RuntimeError(f"refused: unreadable sandbox check from {dm}: {raw[:200]}") from None
    name, place = str(info.get("Name")), str(info.get("PlaceId"))
    if info.get("Main") is not False or place == str(MAIN_PLACE_ID):
        raise RuntimeError(f"refused: the {dm} datamodel is the main game place ({place}); nothing was changed")
    if dm == "Edit" and SANDBOX_NAME not in name:
        raise RuntimeError(f"refused: the Studio place is {name!r}, not {SANDBOX_NAME}; nothing was changed")
    return f"{dm} {name} PlaceId {place}"


def stop_play(c):
    if EDIT_MARK in state(c):
        return
    c.call("start_stop_play", {"is_start": False})
    for _ in range(30):
        time.sleep(0.5)
        if EDIT_MARK in state(c):
            return
    raise RuntimeError("Play did not stop within 15 s")


def restore(c):
    """Stop Play and switch device emulation off. Never raises (it runs in finally blocks, after errors too)."""
    ok = True
    try:
        stop_play(c)
    except Exception as e:  # noqa: BLE001 - report and still try the device reset
        print("restore: stop Play failed:", e)
        ok = False
    try:
        print("restore:", luau(c, RESTORE, "Edit").strip())
    except Exception as e:  # noqa: BLE001
        print("restore: device emulation reset failed:", e)
        ok = False
    return ok


@contextlib.contextmanager
def sandbox(keep=False):
    """A started Client on the practice Studio. Checks the sandbox before the caller changes anything, and on the way
    out (also after an exception) stops Play and switches device emulation off; keep=True leaves Play running, but
    only after a clean run. Nothing is restored when the sandbox check itself refuses."""
    c = Client()
    try:
        c.start()
        print("sandbox:", ensure_sandbox(c))
        done = False
        try:
            yield c
            done = True
        finally:
            if not (keep and done):
                restore(c)
    finally:
        c.close()


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
    # sandbox() restores at the end (also after an error); 'restore' alone just does that
    with sandbox(keep=keep and "restore" not in names) as c:
        for name in names:
            if name != "restore":
                view(c, name, faction, out, keep)


if __name__ == "__main__":
    main()
