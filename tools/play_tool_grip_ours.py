"""(tools/play_tool_grip_ours.py) A23-150 7 (user 10/12 night (가) "로블록스 기본 그대로"): OUR weapons now held the Roblox
way - each a Tool (Handle + RightGripAttachment, Tool.Grip from Config.WeaponGrips) in the right hand, the default Animate's
toolnone hold (the arm forward, the weapon upright) - photographed on the user's avatar in the main Studio test Play
(메인 반영 1, own Play; nothing is converted, the game's own WeaponModel is shot). For every class x side (9: the 7 kinds of
the user's sheet + the Dark Mage's crook staff + the Shadow Hunter's short bow): front, side, 3/4 standing, side walking
and side mid-attack (our own swing: the Swing remote - the class's clip, an archer's draw moves the bow to the left hand).
The GripProbe line (WeaponPose: dGrip = the grip to the Handle's axis, point = the grip's share up the Handle, axis = the
knuckle line against the Handle) is logged per kind, with the Tool's Grip and the arm / Handle directions.
Usage: HH_MAIN_STUDIO=1 py tools/play_tool_grip_ours.py [outdir-name]
Out: docs/art/verification_2026-10-12/main_apply/<outdir>/ (default tool_grip_ours): user_<kind>_<shot>.png,
_sheet.png (a row per kind: front / side / quarter / walk / attack), log.txt"""
import base64
import io
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-12", "main_apply", sys.argv[1] if len(sys.argv) > 1 else "tool_grip_ours")
os.makedirs(OUT, exist_ok=True)
LOG = []
KINDS = [("sword", "Halo", "Warrior"), ("darksword", "Horns", "Warrior"), ("hammer", "Neutral", "Warrior"),
         ("staff", "Halo", "Mage"), ("crookstaff", "Horns", "Mage"), ("flaskstaff", "Neutral", "Mage"),
         ("bow", "Halo", "Archer"), ("shortbow", "Horns", "Archer"), ("baton", "Neutral", "Archer")]
SHOTS = ["front", "side", "quarter", "walk", "attack"]


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
# the Tool as the server built it (class, kind, Grip, the RightGrip weld)
TOOL = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local ch = p.Character
local wm = ch and ch:FindFirstChild("WeaponModel")
if not wm then return "no WeaponModel" end
local h = wm:FindFirstChild("Handle")
local rg = ch:FindFirstChild("RightHand") and ch.RightHand:FindFirstChild("RightGrip")
local g = wm:IsA("Tool") and wm.Grip or CFrame.new()
return string.format("tool: class=%s isTool=%s kind=%s handle=%s len=%.2f grip=(%.2f,%.2f,%.2f) rightGrip=%s",
	wm.ClassName, tostring(wm:IsA("Tool")), tostring(wm:GetAttribute("Kind")), tostring(h ~= nil), h and h.Size.Y or 0,
	g.Position.X, g.Position.Y, g.Position.Z, tostring(rg ~= nil and rg.Part1 == h))
"""
ARMS = r"""
local ch = game:GetService("Players").LocalPlayer.Character
if not ch then return "no char" end
local ut = ch:FindFirstChild("UpperTorso")
local out = {}
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
local wm = ch:FindFirstChild("WeaponModel")
local h = wm and wm:FindFirstChild("Handle")
if h and ut then
	local d = ut.CFrame:VectorToObjectSpace(h.CFrame.UpVector)
	table.insert(out, string.format("handleAxis@torso=(%.2f,%.2f,%.2f) bowGrip=%s", d.X, d.Y, d.Z, tostring(h:FindFirstChild("BowGrip") ~= nil)))
end
return table.concat(out, " ")
"""
PROBE = r"""
game:GetService("Players").LocalPlayer:SetAttribute("GripProbe", %s)
return "probe %s"
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
    # our own swing (the class's clip; an archer's draw holds the bow in the left hand), caught mid-move
    cam = lua(c, CAM % "side", "Client")
    note(lua(c, FIRE % ("Swing", "", "Swing"), "Client"))
    time.sleep(0.2)
    note(f"{tag}_attack: " + lua(c, ARMS, "Client"))
    out["attack"] = save(c, f"{tag}_attack", cam)
    note(lua(c, RESET, "Client"))
    note(lua(c, ANCH % ("false", "off"), "Server"))
    time.sleep(1.0)
    note(lua(c, WALK % ("-1", "on"), "Client"))
    time.sleep(0.8)
    out["walk"] = shot(c, f"{tag}_walk", "side")
    note(lua(c, WALK % ("0", "off"), "Client"))
    note(lua(c, RESET, "Client"))
    note(lua(c, TELE, "Server"))
    time.sleep(0.8)
    return out


def sheet(rows):
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
    p = os.path.join(OUT, "_sheet.png")
    out.save(p)
    note("sheet " + p)


def probe_lines(c):
    con = text_of(c.call("get_console_output", {}))
    return [ln for ln in con.splitlines() if "[WeaponPose] probe" in ln][-2:]


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    c = Client()
    c.start()
    rows = []
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
        note(lua(c, PROBE % ("true", "on"), "Client"))
        note(lua(c, TELE, "Server"))
        for kind, fac, cls in KINDS:
            note(f"== {kind}: " + lua(c, DEBUG % f'{{ "Faction", "{fac}" }}, {{ "Class", "{cls}" }}', "Server"))
            time.sleep(3)
            note(lua(c, FIRE % ("EquipWeapon", "3", "EquipWeapon"), "Client"))
            time.sleep(2.5)
            note("state: " + lua(c, STATE, "Server"))
            note(lua(c, TOOL, "Server"))
            time.sleep(2.5)
            for ln in probe_lines(c):
                note("probe: " + ln)
            rows.append((kind, kind_shots(c, f"user_{kind}")))
        sheet(rows)
        con = text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "infinite yield"))]
        note("console: " + "\n".join(errs[-30:]))
    finally:
        try:
            lua(c, PROBE % ("nil", "off"), "Client")
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
