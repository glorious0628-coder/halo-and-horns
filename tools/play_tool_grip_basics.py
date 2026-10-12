"""(tools/play_tool_grip_basics.py) A23-150 #7 (user 10/12 "칼부터 모든 무기 다 로블록스 기본 모델이 … 어케 드는지 확인하고나서
부위 조절하기로"): Roblox's OWN Tool hold for each of our 7 weapon kinds, on the user's avatar and on a default R15 body, in
the main Studio test Play (메인 반영 1, own Play). Our pose values are NOT touched: for each kind the WeaponModel is taken
off the character (WeaponPose lets go) and turned into a Tool - Handle = the weapon's long part (Handle / Shaft / the
biggest part), the other parts welded on as they were, Tool.Grip = only the grip point's place on that part (Roblox's own
orientation) - equipped with Humanoid:EquipTool: the default Animate plays its tool hold (toolnone) and, for the attack
shot, its slash (a "toolanim" StringValue "Slash" in the Tool, the way ClassicSword asks for it). A Tool always goes in
the RIGHT hand. Shots per kind: front, side, 3/4 standing, side walking, side mid-slash.
Kinds (class x side): one-hand sword (Warrior Halo), dark sword (Warrior Horns), bow (Archer Halo), staff (Mage Halo),
hammer (Warrior Neutral), tamer baton (Archer Neutral), flask staff (Mage Neutral).
Pass 1 = the user's avatar; pass 2 = a default R15 body (Humanoid:ApplyDescription(HumanoidDescription.new())).
Usage: HH_MAIN_STUDIO=1 py tools/play_tool_grip_basics.py [outdir-name]
Out: docs/art/verification_2026-10-12/main_apply/<outdir>/ (default tool_basics): <avatar>_<kind>_<shot>.png,
_sheet_<kind>.png (row user / row default R15, 5 shots each), log.txt"""
import base64
import io
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-12", "main_apply", sys.argv[1] if len(sys.argv) > 1 else "tool_basics")
os.makedirs(OUT, exist_ok=True)
LOG = []
KINDS = [("sword", "Halo", "Warrior"), ("darksword", "Horns", "Warrior"), ("bow", "Halo", "Archer"), ("staff", "Halo", "Mage"),
         ("hammer", "Neutral", "Warrior"), ("baton", "Neutral", "Archer"), ("flaskstaff", "Neutral", "Mage")]
ONLY = [k for k in os.environ.get("HH_KINDS", "").split(",") if k]  # e.g. HH_KINDS=baton,staff (+ HH_SKIP_USER=1 = default R15 pass only)
if ONLY:
    KINDS = [k for k in KINDS if k[0] in ONLY]
SHOTS = ["front", "side", "quarter", "walk", "slash"]


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def lua(c, code, dm):
    try:
        return text_of(c.call("execute_luau", {"code": code, "datamodel_type": dm}))
    except Exception as e:  # noqa: BLE001
        return "ERR " + str(e)[:200]


def note(m):
    print(m, flush=True)
    LOG.append(m)


def save(c, name, cam=None):
    args = {"capture_id": name}
    if cam and "|" in cam:
        a, b = cam.strip().split("|")
        args["camera_position"] = [float(v) for v in a.split(",")]
        args["look_at_position"] = [float(v) for v in b.split(",")]
    res = c.call("screen_capture", args)
    for part in res.get("content", []):
        if part.get("type") == "image":
            p = os.path.join(OUT, name + ".png")
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB").save(p)
            note("saved " + name)
            return p
    note("capture failed " + name)
    return None


STATE = r"""
local p = game:GetService("Players"):GetPlayers()[1]
if not p then return "no player" end
local out = {}
for _, k in { "DataLoaded", "Faction", "Class", "ClassChosen", "Level", "WeaponTier" } do table.insert(out, k .. "=" .. tostring(p:GetAttribute(k))) end
return table.concat(out, " ")
"""
FIRE = r"""
game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("%s"):FireServer(%s)
return "fired %s"
"""
DEBUG = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local fn = game:GetService("ServerScriptService"):FindFirstChild("DebugCommand")
if not (p and fn) then return "no player / DebugCommand" end
local out = {}
for _, kv in { %s } do
	local ok, r = pcall(function() return fn:Invoke(p.Name, kv[1], kv[2]) end)
	table.insert(out, kv[1] .. "=" .. tostring(ok and r or ("ERR " .. tostring(r))))
end
return table.concat(out, " ")
"""
TO_TOOL = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local ch = p.Character
local hum = ch and ch:FindFirstChildOfClass("Humanoid")
local wm = ch and ch:FindFirstChild("WeaponModel")
if not (hum and wm) then return "no weapon" end
local holdName = wm:GetAttribute("GripHand") or "RightHand"
local hand = ch:FindFirstChild(holdName)
local att = hand and hand:FindFirstChild((holdName == "LeftHand" and "Left" or "Right") .. "GripAttachment")
if not att then return "no grip attachment" end
local long = wm:FindFirstChild("Handle") or wm:FindFirstChild("Shaft")
if not long then
	for _, d in wm:GetChildren() do
		if d:IsA("BasePart") and (long == nil or d.Size.Magnitude > long.Size.Magnitude) then long = d end
	end
end
if not long then return "no long part" end
local gripWorld = att.WorldCFrame.Position
local tool = Instance.new("Tool")
tool.Name = "DefaultGripTest"
tool.CanBeDropped = false
tool.RequiresHandle = true
local handle = long:Clone()
handle.Name = "Handle"
for _, d in handle:GetChildren() do if d:IsA("WeldConstraint") or d:IsA("Weld") then d:Destroy() end end
handle.Anchored = false
handle.CanCollide = false
handle.Massless = true
handle.Parent = tool
local rel = long.CFrame:PointToObjectSpace(gripWorld)
tool.Grip = CFrame.new(rel)
local n = 0
for _, d in wm:GetChildren() do
	if d:IsA("BasePart") and d ~= long then
		local c = d:Clone()
		for _, w in c:GetChildren() do if w:IsA("WeldConstraint") or w:IsA("Weld") then w:Destroy() end end
		c.Anchored = false
		c.CanCollide = false
		c.Massless = true
		c.CFrame = handle.CFrame * long.CFrame:ToObjectSpace(d.CFrame)
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = handle, c
		w.Parent = c
		c.Parent = tool
		n += 1
	end
end
wm.Parent = game:GetService("ServerStorage")
tool.Parent = p:FindFirstChildOfClass("Backpack") or ch
hum:EquipTool(tool)
return string.format("tool on: handle=%s size=(%.2f,%.2f,%.2f) parts=%d grip=(%.2f,%.2f,%.2f) was=%s", long.Name, long.Size.X,
	long.Size.Y, long.Size.Z, n, rel.X, rel.Y, rel.Z, holdName)
"""
SLASH = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local tool = p.Character and p.Character:FindFirstChild("DefaultGripTest")
if not tool then return "no tool" end
local v = Instance.new("StringValue")
v.Name = "toolanim"
v.Value = "Slash"
v.Parent = tool
return "slash asked"
"""
DROP = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local ch = p.Character
local hum = ch and ch:FindFirstChildOfClass("Humanoid")
if hum then hum:UnequipTools() end
for _, holder in { ch, p:FindFirstChildOfClass("Backpack") } do
	local t = holder and holder:FindFirstChild("DefaultGripTest")
	if t then t:Destroy() end
end
local wm = game:GetService("ServerStorage"):FindFirstChild("WeaponModel")
if wm then wm:Destroy() end
return "tool off"
"""
DEFAULT_BODY = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
if not hum then return "no humanoid" end
local ok, err = pcall(function() hum:ApplyDescription(Instance.new("HumanoidDescription")) end)
return "default R15 body: " .. tostring(ok) .. " " .. tostring(err or "")
"""
ARMS = r"""
local ch = game:GetService("Players").LocalPlayer.Character
if not ch then return "no char" end
local ut = ch:FindFirstChild("UpperTorso")
local out = { "tool=" .. tostring(ch:FindFirstChildOfClass("Tool") ~= nil) }
if ut then table.insert(out, string.format("torso=(%.2f,%.2f,%.2f)", ut.Size.X, ut.Size.Y, ut.Size.Z)) end
local hand, upper, lower = ch:FindFirstChild("RightHand"), ch:FindFirstChild("RightUpperArm"), ch:FindFirstChild("RightLowerArm")
if hand and ut then
	local r = ut.CFrame:PointToObjectSpace(hand.Position)
	table.insert(out, string.format("RightHand@torso=(%.2f,%.2f,%.2f)", r.X, r.Y, r.Z))
end
for _, part in { upper, lower } do
	if part and ut then
		local d = ut.CFrame:VectorToObjectSpace(-part.CFrame.UpVector)
		table.insert(out, string.format("%s dir=(%.2f,%.2f,%.2f)", part.Name, d.X, d.Y, d.Z))
	end
end
local tool = ch:FindFirstChildOfClass("Tool")
local h = tool and tool:FindFirstChild("Handle")
if h and ut then
	local d = ut.CFrame:VectorToObjectSpace(h.CFrame.UpVector)
	table.insert(out, string.format("handleAxis@torso=(%.2f,%.2f,%.2f)", d.X, d.Y, d.Z))
end
return table.concat(out, " ")
"""
CAM = r"""
local p = game:GetService("Players").LocalPlayer
local ch = p.Character
local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
if not hrp then return "no char" end
for _, g in p:FindFirstChildOfClass("PlayerGui"):GetChildren() do
	if g:IsA("ScreenGui") then g.Enabled = false end
end
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
cam.FieldOfView = 40
local mode = "%s"
local f, r = hrp.CFrame.LookVector, hrp.CFrame.RightVector
local dir = mode == "side" and r or (mode == "quarter" and (f + r).Unit or f)
local target = hrp.Position + Vector3.new(0, 0.6, 0)
local camPos = target + dir * 11 + Vector3.new(0, 0.6, 0)
cam.CFrame = CFrame.lookAt(camPos, target)
return string.format("%%f,%%f,%%f|%%f,%%f,%%f", camPos.X, camPos.Y, camPos.Z, target.X, target.Y, target.Z)
"""
RESET = r"""
local p = game:GetService("Players").LocalPlayer
for _, g in p:FindFirstChildOfClass("PlayerGui"):GetChildren() do
	if g:IsA("ScreenGui") then g.Enabled = true end
end
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
return "reset"
"""
ANCH = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if hrp then hrp.Anchored = %s end
return "anchored %s"
"""
WALK = r"""
local h = game:GetService("Players").LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
if h then h:Move(Vector3.new(0, 0, %s), true) end
return "move %s"
"""
TELE = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local ch = p.Character
if not ch then return "no char" end
ch:PivotTo(CFrame.new(0, 5, -25))
return "spot"
"""


def wait_state(c, cond, timeout, every=1.0):
    t0, last = time.time(), ""
    while time.time() - t0 < timeout:
        last = lua(c, STATE, "Server")
        if cond(last):
            return last
        time.sleep(every)
    return last


def shot(c, name, mode):
    cam = lua(c, CAM % mode, "Client")
    time.sleep(1.0)
    note(f"{name}: " + lua(c, ARMS, "Client"))
    return save(c, name, cam)


def kind_shots(c, tag):
    out = {}
    note(lua(c, ANCH % ("true", "on"), "Server"))
    time.sleep(1.2)
    for m in ("front", "side", "quarter"):
        out[m] = shot(c, f"{tag}_{m}", m)
    # one default slash, caught mid-swing
    cam = lua(c, CAM % "side", "Client")
    note(lua(c, SLASH, "Server"))
    time.sleep(0.18)
    note(f"{tag}_slash: " + lua(c, ARMS, "Client"))
    out["slash"] = save(c, f"{tag}_slash", cam)
    note(lua(c, RESET, "Client"))
    note(lua(c, ANCH % ("false", "off"), "Server"))
    time.sleep(0.8)
    note(lua(c, WALK % ("-1", "on"), "Client"))
    time.sleep(0.8)
    out["walk"] = shot(c, f"{tag}_walk", "side")
    note(lua(c, WALK % ("0", "off"), "Client"))
    note(lua(c, RESET, "Client"))
    note(lua(c, TELE, "Server"))
    time.sleep(0.8)
    return out


def sheet(kind, rows):
    imgs = []
    for label, shots in rows:
        imgs.append((label, [Image.open(shots[s]) if shots.get(s) else None for s in SHOTS]))
    first = next((im for _, r in imgs for im in r if im), None)
    if not first:
        return
    w, h = first.size
    cw, ch = w // 3, h // 3
    out = Image.new("RGB", (110 + cw * len(SHOTS), ch * len(imgs) + 24), (30, 30, 30))
    d = ImageDraw.Draw(out)
    for j, s in enumerate(SHOTS):
        d.text((110 + j * cw + 6, 4), s, fill=(255, 255, 255))
    for i, (label, r) in enumerate(imgs):
        d.text((8, 24 + i * ch + ch // 2), label, fill=(255, 255, 255))
        for j, im in enumerate(r):
            if im:
                out.paste(im.resize((cw, ch)), (110 + j * cw, 24 + i * ch))
    p = os.path.join(OUT, f"_sheet_{kind}.png")
    out.save(p)
    note("sheet " + p)


def pass_all(c, avatar):
    got = {}
    for kind, fac, cls in KINDS:
        note(f"== {avatar} {kind}: " + lua(c, DEBUG % f'{{ "Faction", "{fac}" }}, {{ "Class", "{cls}" }}', "Server"))
        time.sleep(3)
        note(lua(c, FIRE % ("EquipWeapon", "3", "EquipWeapon"), "Client"))
        time.sleep(2.5)
        note("state: " + lua(c, STATE, "Server"))
        note(lua(c, TO_TOOL, "Server"))
        time.sleep(2)
        got[kind] = kind_shots(c, f"{avatar}_{kind}")
        note(lua(c, DROP, "Server"))
        time.sleep(1)
    return got


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    c = Client()
    c.start()
    try:
        st = text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in st:
            sys.exit("not in Edit: " + st)
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
        c.call("start_stop_play", {"is_start": True})
        note("loaded: " + wait_state(c, lambda x: "DataLoaded=true" in x, 90, 2.0))
        time.sleep(26)
        note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        wait_state(c, lambda x: "Faction=Halo" in x, 20)
        note(lua(c, FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
        note("chosen: " + wait_state(c, lambda x: "ClassChosen=true" in x, 20))
        note(lua(c, FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
        time.sleep(1)
        note("gear: " + lua(c, DEBUG % '{ "Level", 30 }, { "WeaponOwnedMask", 511 }', "Server"))
        note(lua(c, TELE, "Server"))
        user = {} if os.environ.get("HH_SKIP_USER") else pass_all(c, "user")
        note(lua(c, DEFAULT_BODY, "Server"))
        time.sleep(4)
        note(lua(c, TELE, "Server"))
        default = pass_all(c, "r15")
        for kind, _, _ in KINDS:
            sheet(kind, [("user avatar", user.get(kind, {})), ("default R15", default.get(kind, {}))])
        con = text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "infinite yield"))]
        note("console: " + "\n".join(errs[-30:]))
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
            note("play stopped")
        except Exception as e:  # noqa: BLE001
            note("stop failed " + str(e))
        time.sleep(2)
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh kept on"', "Edit"))
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
